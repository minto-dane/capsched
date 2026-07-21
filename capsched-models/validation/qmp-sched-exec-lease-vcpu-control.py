#!/usr/bin/env python3
"""Fail-closed QMP control for paused SchedExecLease timing guests."""

from __future__ import annotations

import argparse
import json
import re
import socket
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class QMPControlError(RuntimeError):
    """Raised when QMP state does not satisfy the timing harness contract."""


@dataclass(frozen=True)
class VCPU:
    index: int
    thread_id: int


class QMPClient:
    def __init__(self, socket_path: Path, timeout: int) -> None:
        self.socket_path = socket_path
        self.deadline = time.monotonic() + timeout
        self.connection: socket.socket | None = None
        self.reader: Any = None

    def __enter__(self) -> "QMPClient":
        while True:
            connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                connection.connect(str(self.socket_path))
                self.connection = connection
                self.reader = connection.makefile("rb")
                break
            except (FileNotFoundError, ConnectionRefusedError):
                connection.close()
                if time.monotonic() >= self.deadline:
                    raise QMPControlError("timed out connecting to QMP socket")
                time.sleep(0.05)

        try:
            greeting = self._read_response(allow_event=False)
            if not isinstance(greeting.get("QMP"), dict):
                raise QMPControlError("QMP greeting missing or malformed")
            self.command("qmp_capabilities")
        except Exception:
            self.__exit__()
            raise
        return self

    def __exit__(self, *_args: object) -> None:
        if self.reader is not None:
            self.reader.close()
        if self.connection is not None:
            self.connection.close()

    def _read_response(self, *, allow_event: bool = True) -> dict[str, Any]:
        if self.connection is None or self.reader is None:
            raise QMPControlError("QMP connection is not open")
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise QMPControlError("timed out waiting for QMP response")
        self.connection.settimeout(remaining)
        while True:
            try:
                raw = self.reader.readline()
            except TimeoutError as error:
                raise QMPControlError("timed out waiting for QMP response") from error
            if not raw:
                raise QMPControlError("QMP socket closed before a response")
            try:
                message = json.loads(raw)
            except json.JSONDecodeError as error:
                raise QMPControlError("QMP emitted malformed JSON") from error
            if not isinstance(message, dict):
                raise QMPControlError("QMP response is not an object")
            if "event" in message and allow_event:
                continue
            return message

    def command(self, execute: str) -> Any:
        if self.connection is None:
            raise QMPControlError("QMP connection is not open")
        request = json.dumps({"execute": execute}, separators=(",", ":"))
        self.connection.sendall(request.encode("ascii") + b"\r\n")
        response = self._read_response()
        if "error" in response:
            raise QMPControlError(f"QMP command {execute} failed: {response['error']!r}")
        if "return" not in response:
            raise QMPControlError(f"QMP command {execute} returned no result")
        return response["return"]


def _strict_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise QMPControlError(f"{label} is not an integer")
    return value


def validate_vcpus(raw_vcpus: Any, expected: int) -> list[VCPU]:
    if not isinstance(raw_vcpus, list):
        raise QMPControlError("query-cpus-fast result is not an array")
    if len(raw_vcpus) != expected:
        raise QMPControlError(
            f"query-cpus-fast returned {len(raw_vcpus)} vCPUs; expected {expected}"
        )

    result: list[VCPU] = []
    indexes: set[int] = set()
    thread_ids: set[int] = set()
    for entry in raw_vcpus:
        if not isinstance(entry, dict):
            raise QMPControlError("query-cpus-fast entry is not an object")
        index = _strict_int(entry.get("cpu-index"), "vCPU index")
        thread_id = _strict_int(entry.get("thread-id"), "vCPU thread-id")
        if index < 0 or index >= expected:
            raise QMPControlError(f"vCPU index {index} is outside 0..{expected - 1}")
        if thread_id <= 0:
            raise QMPControlError("vCPU thread-id is not positive")
        if index in indexes:
            raise QMPControlError(f"duplicate vCPU index {index}")
        if thread_id in thread_ids:
            raise QMPControlError(f"duplicate vCPU thread-id {thread_id}")
        indexes.add(index)
        thread_ids.add(thread_id)
        result.append(VCPU(index=index, thread_id=thread_id))

    if indexes != set(range(expected)):
        raise QMPControlError("vCPU index set is incomplete")
    return sorted(result, key=lambda item: item.index)


def query_snapshot(client: QMPClient, expected: int) -> tuple[str, list[VCPU]]:
    raw_status = client.command("query-status")
    if not isinstance(raw_status, dict) or not isinstance(raw_status.get("status"), str):
        raise QMPControlError("query-status result is malformed")
    status = raw_status["status"]
    if status not in {"prelaunch", "paused"}:
        raise QMPControlError(f"QEMU is not paused before pinning: {status}")
    vcpus = validate_vcpus(client.command("query-cpus-fast"), expected)
    return status, vcpus


MAPPING_RE = re.compile(r"^vcpu=([0-9]+) tid=([0-9]+)$")
AFFINITY_RE = re.compile(r"^vcpu=([0-9]+) tid=([0-9]+) host_cpu=([0-9]+)$")


def parse_mapping(path: Path, expected: int) -> dict[int, int]:
    try:
        lines = path.read_text(encoding="ascii").splitlines()
    except (OSError, UnicodeError) as error:
        raise QMPControlError("could not read the QMP vCPU mapping") from error
    mapping: dict[int, int] = {}
    thread_ids: set[int] = set()
    for line in lines:
        if line.startswith("qmp_status="):
            continue
        match = MAPPING_RE.fullmatch(line)
        if match is None:
            raise QMPControlError("QMP vCPU mapping contains an unknown line")
        index = int(match.group(1))
        thread_id = int(match.group(2))
        if index in mapping or thread_id in thread_ids:
            raise QMPControlError("QMP vCPU mapping contains a duplicate")
        mapping[index] = thread_id
        thread_ids.add(thread_id)
    if set(mapping) != set(range(expected)):
        raise QMPControlError("QMP vCPU mapping index set is incomplete")
    return mapping


def parse_affinity(path: Path, expected: int) -> dict[int, tuple[int, int]]:
    try:
        lines = path.read_text(encoding="ascii").splitlines()
    except (OSError, UnicodeError) as error:
        raise QMPControlError("could not read the pinned vCPU affinity mapping") from error
    affinity: dict[int, tuple[int, int]] = {}
    thread_ids: set[int] = set()
    host_cpus: set[int] = set()
    for line in lines:
        match = AFFINITY_RE.fullmatch(line)
        if match is None:
            raise QMPControlError("pinned vCPU affinity mapping contains an unknown line")
        index, thread_id, host_cpu = map(int, match.groups())
        if index in affinity or thread_id in thread_ids or host_cpu in host_cpus:
            raise QMPControlError("pinned vCPU affinity mapping contains a duplicate")
        affinity[index] = (thread_id, host_cpu)
        thread_ids.add(thread_id)
        host_cpus.add(host_cpu)
    if set(affinity) != set(range(expected)):
        raise QMPControlError("pinned vCPU affinity index set is incomplete")
    return affinity


def verify_singleton_affinity(
    qemu_pid: int,
    qmp_mapping: dict[int, int],
    affinity: dict[int, tuple[int, int]],
) -> None:
    if qemu_pid <= 0:
        raise QMPControlError("QEMU pid is not positive")
    for index, thread_id in qmp_mapping.items():
        pinned_thread_id, host_cpu = affinity[index]
        if pinned_thread_id != thread_id:
            raise QMPControlError(f"pinned thread id for vCPU {index} differs from QMP")
        status_path = Path(f"/proc/{qemu_pid}/task/{thread_id}/status")
        try:
            status_lines = status_path.read_text(encoding="ascii").splitlines()
        except (OSError, UnicodeError) as error:
            raise QMPControlError(f"vCPU {index} is not a thread of the active QEMU") from error
        fields: dict[str, str] = {}
        for line in status_lines:
            key, separator, value = line.partition(":")
            if separator:
                fields[key] = value.strip()
        if fields.get("Tgid") != str(qemu_pid):
            raise QMPControlError(f"vCPU {index} thread group differs from the active QEMU")
        if fields.get("Cpus_allowed_list") != str(host_cpu):
            raise QMPControlError(f"vCPU {index} does not have verified singleton affinity")


def command_query(args: argparse.Namespace) -> None:
    with QMPClient(args.socket, args.timeout) as client:
        status, vcpus = query_snapshot(client, args.expected_vcpus)
    print(f"qmp_status={status}")
    for vcpu in vcpus:
        print(f"vcpu={vcpu.index} tid={vcpu.thread_id}")


def command_resume(args: argparse.Namespace) -> None:
    expected_mapping = parse_mapping(args.mapping, args.expected_vcpus)
    expected_affinity = parse_affinity(args.affinity, args.expected_vcpus)
    with QMPClient(args.socket, args.timeout) as client:
        status_before, vcpus = query_snapshot(client, args.expected_vcpus)
        observed_mapping = {vcpu.index: vcpu.thread_id for vcpu in vcpus}
        if observed_mapping != expected_mapping:
            raise QMPControlError("QMP vCPU mapping changed before resume")
        verify_singleton_affinity(args.qemu_pid, expected_mapping, expected_affinity)
        client.command("cont")
        raw_status = client.command("query-status")
        if not isinstance(raw_status, dict) or raw_status.get("status") != "running":
            raise QMPControlError("QEMU did not enter running state after cont")
    print(f"qmp_status_before_resume={status_before}")
    print("qmp_mapping_reverified=true")
    print("singleton_affinity_reverified=true")
    print("qmp_status_after_resume=running")


def _expect_failure(function: Any, *args: Any, **kwargs: Any) -> None:
    try:
        function(*args, **kwargs)
    except QMPControlError:
        return
    raise AssertionError("invalid fixture was accepted")


def command_self_test(_args: argparse.Namespace) -> None:
    valid = [
        {"cpu-index": 0, "thread-id": 101, "halted": True},
        {"cpu-index": 1, "thread-id": 102, "halted": True},
    ]
    assert [item.index for item in validate_vcpus(valid, 2)] == [0, 1]
    fixtures = [
        valid[:1],
        [valid[0], {"cpu-index": 0, "thread-id": 102, "halted": True}],
        [valid[0], {"cpu-index": 1, "thread-id": 101, "halted": True}],
        [valid[0], {"cpu-index": 2, "thread-id": 102, "halted": True}],
        [valid[0], {"cpu-index": 1, "thread-id": True, "halted": True}],
        {"cpu-index": 0},
    ]
    for fixture in fixtures:
        _expect_failure(validate_vcpus, fixture, 2)

    mapping_fixtures = [
        "qmp_status=prelaunch\nvcpu=0 tid=101\n",
        "qmp_status=prelaunch\nvcpu=0 tid=101\nvcpu=0 tid=102\n",
        "qmp_status=prelaunch\nvcpu=0 tid=101\nvcpu=1 tid=101\n",
        "qmp_status=prelaunch\nvcpu=0 tid=101\nunknown=true\n",
    ]
    with tempfile.TemporaryDirectory() as temporary_directory:
        mapping_path = Path(temporary_directory) / "mapping.txt"
        affinity_path = Path(temporary_directory) / "affinity.txt"
        mapping_path.write_text(
            "qmp_status=prelaunch\n"
            "vcpu=0 tid=101\n"
            "vcpu=1 tid=102\n",
            encoding="ascii",
        )
        assert parse_mapping(mapping_path, 2) == {0: 101, 1: 102}
        for fixture in mapping_fixtures:
            mapping_path.write_text(fixture, encoding="ascii")
            _expect_failure(parse_mapping, mapping_path, 2)

        affinity_path.write_text(
            "vcpu=0 tid=101 host_cpu=2\nvcpu=1 tid=102 host_cpu=3\n",
            encoding="ascii",
        )
        assert parse_affinity(affinity_path, 2) == {0: (101, 2), 1: (102, 3)}
        affinity_fixtures = [
            "vcpu=0 tid=101 host_cpu=2\n",
            "vcpu=0 tid=101 host_cpu=2\nvcpu=0 tid=102 host_cpu=3\n",
            "vcpu=0 tid=101 host_cpu=2\nvcpu=1 tid=101 host_cpu=3\n",
            "vcpu=0 tid=101 host_cpu=2\nvcpu=1 tid=102 host_cpu=2\n",
            "vcpu=0 tid=101 host_cpu=2\nunknown=true\n",
        ]
        for fixture in affinity_fixtures:
            affinity_path.write_text(fixture, encoding="ascii")
            _expect_failure(parse_affinity, affinity_path, 2)
    negative_count = len(fixtures) + len(mapping_fixtures) + len(affinity_fixtures)
    print(f"qmp_vcpu_control_self_test=passed negative_fixtures={negative_count}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    query = subparsers.add_parser("query")
    query.add_argument("--socket", type=Path, required=True)
    query.add_argument("--expected-vcpus", type=int, required=True)
    query.add_argument("--timeout", type=int, default=300)
    query.set_defaults(function=command_query)

    resume = subparsers.add_parser("resume")
    resume.add_argument("--socket", type=Path, required=True)
    resume.add_argument("--expected-vcpus", type=int, required=True)
    resume.add_argument("--mapping", type=Path, required=True)
    resume.add_argument("--affinity", type=Path, required=True)
    resume.add_argument("--qemu-pid", type=int, required=True)
    resume.add_argument("--timeout", type=int, default=30)
    resume.set_defaults(function=command_resume)

    self_test = subparsers.add_parser("self-test")
    self_test.set_defaults(function=command_self_test)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if getattr(args, "expected_vcpus", 1) <= 0:
        parser.error("--expected-vcpus must be positive")
    if getattr(args, "timeout", 1) <= 0:
        parser.error("--timeout must be positive")
    try:
        args.function(args)
    except (QMPControlError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
