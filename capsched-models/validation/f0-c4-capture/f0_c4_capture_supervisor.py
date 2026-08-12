#!/usr/bin/python3
"""Root-owned Candidate-4 capture supervisor.

The Python control plane fixes the input snapshot, plan, cgroups, receipts, and
publication. The companion C launcher owns the clone3/pidfd/namespace/seccomp
boundary and captures candidate bytes directly from root-owned pipes.
"""

from __future__ import annotations

import argparse
import ctypes
import fcntl
import grp
import hashlib
import json
import os
import pwd
import re
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable


CONTRACT_SHA256 = "0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d"
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
CANDIDATE_UID = 200010
CANDIDATE_GID = 200010
FIXED_EVIDENCE_ROOT = Path("/var/lib/domainlease-f0-c4/evidence")
REQUIRED_INPUTS = (
    "f0-supervisor-c4-claim-registry-v1.json",
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "test-run-f0-supervisor-v3-full.sh",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
)
COMPONENTS = (
    ("static-registries", "FAST_REGISTRY_CHECK", 1800),
    ("tests", "FAST_HOSTILE_REGRESSION", 3600),
    ("child-bundle-producer", "FULL_CHILD_PRODUCER", 43200),
    ("child-bundle-checker", "FULL_CHILD_CHECKER", 43200),
    ("orchestrator", "FULL_PARENT_ORCHESTRATOR", 43200),
)
ENVIRONMENT = {
    "PATH": "/usr/bin:/bin",
    "PYTHONPATH": "INPUT",
    "PYTHONDONTWRITEBYTECODE": "1",
    "PYTHONHASHSEED": "0",
}
LAUNCHER_META_KEYS = {
    "schema_version",
    "component_id",
    "leader_pid",
    "pidfd_observed",
    "cgroup_inode",
    "preexec_observation_size",
    "preexec_observation_sha256",
    "preexec_limit_exceeded",
    "started_monotonic_ns",
    "finished_monotonic_ns",
    "termination",
    "exit_code",
    "signal",
    "waitid_code",
    "waitid_status",
    "deadline_exceeded",
    "stdout_size",
    "stdout_sha256",
    "stdout_limit_exceeded",
    "stderr_size",
    "stderr_sha256",
    "stderr_limit_exceeded",
    "preexec_stage",
    "preexec_errno",
    "preexec_detail",
    "cgroup_kill_used",
    "populated_zero_observed",
    "setup_ok",
    "capture_error",
}
AUTHORIZATION = {
    "authority_disjoint_contract_accepted": False,
    "authority_disjoint_launcher_implemented": False,
    "full_campaign_authorized": False,
    "F0_local_acceptance": False,
    "external_R11_review": False,
    "G0_authorized": False,
    "semantic_freeze": False,
    "TLA_translation": False,
    "linux_behavior_change": False,
    "monitor_implementation": False,
    "protection_claim": False,
    "performance_or_cost_claim": False,
    "deployment_claim": False,
}
RESULT_PROTOCOL = {
    "stdout_lines": 1,
    "required_prefix": "RESULT_JSON=",
    "stderr_must_be_empty": True,
    "returncode_must_equal": 0,
    "strict_json_duplicate_keys_rejected": True,
    "nonfinite_numbers_rejected": True,
}
RESOURCE_POLICY = {
    "policy_values_sealed_before_execution": True,
    "run_max_wall_seconds": 136800,
    "supervisor_overhead_max_seconds": 1650,
    "kill_to_drain_max_seconds": 30,
    "pids_max_per_component": 512,
    "memory_max_bytes_per_component": 8053063680,
    "supervisor_memory_low_bytes": 536870912,
    "guardian_and_host_reserve_min_bytes": 2147483648,
    "required_vm_memory_min_bytes": 10200547328,
    "memory_swap_max_bytes_per_component": 0,
    "candidate_component_oom_isolated_from_supervisor": True,
    "stdout_max_bytes_per_component": 268435456,
    "stderr_max_bytes_per_component": 16777216,
    "preexec_observation_max_bytes_per_component": 1048576,
    "receipt_max_bytes_per_component": 1048576,
    "finalization_metadata_max_bytes": 16777216,
    "raw_total_max_bytes": 1610612736,
    "evidence_free_space_reserve_bytes": 10737418240,
    "resource_exhaustion_is_positive": False,
    "audit_allocation_unbounded": False,
}


class CaptureError(RuntimeError):
    """A precondition or capture invariant failed closed."""


def reject_constant(value: str) -> None:
    raise CaptureError(f"non-finite JSON number: {value}")


def unique_object(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise CaptureError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json_bytes(raw: bytes, label: str) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise CaptureError(f"{label} is not strict UTF-8 JSON: {exc}") from exc


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def mount_identity(path: Path) -> dict[str, Any]:
    metadata = path.stat(follow_symlinks=False)
    device = f"{os.major(metadata.st_dev)}:{os.minor(metadata.st_dev)}"
    selected: tuple[str, str, str, str] | None = None
    for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
        left, separator, right = line.partition(" - ")
        if not separator:
            raise CaptureError("mountinfo row has no separator")
        left_fields = left.split()
        right_fields = right.split()
        if len(left_fields) < 6 or len(right_fields) < 3:
            raise CaptureError("mountinfo row is malformed")
        if left_fields[2] != device:
            continue
        mount_point = left_fields[4]
        path_text = str(path)
        if mount_point != "/" and not (
            path_text == mount_point or path_text.startswith(mount_point + "/")
        ):
            continue
        candidate = (
            mount_point,
            left_fields[5],
            right_fields[0],
            right_fields[1],
        )
        if selected is None or len(candidate[0]) > len(selected[0]):
            selected = candidate
    if selected is None:
        raise CaptureError(f"cannot identify mount for {path}")
    mount_point, mount_options, filesystem_type, source = selected
    return {
        "device": device,
        "mount_point": mount_point,
        "mount_options": mount_options,
        "filesystem_type": filesystem_type,
        "source": source,
    }


def require_fixed_native_evidence_root(path: Path) -> dict[str, Any]:
    if path != FIXED_EVIDENCE_ROOT:
        raise CaptureError(f"evidence root must be fixed at {FIXED_EVIDENCE_ROOT}")
    current = Path("/")
    for part in path.parts[1:]:
        current /= part
        try:
            metadata = current.stat(follow_symlinks=False)
        except FileNotFoundError:
            if current == path or current == path.parent:
                current.mkdir(mode=0o700)
                os.chown(current, 0, 0)
                metadata = current.stat(follow_symlinks=False)
            else:
                raise CaptureError(f"fixed evidence ancestry is absent: {current}")
        if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_gid != 0:
            raise CaptureError(f"fixed evidence ancestry is not a root directory: {current}")
        if stat.S_IMODE(metadata.st_mode) & 0o022:
            raise CaptureError(f"fixed evidence ancestry is group/world writable: {current}")
    if stat.S_IMODE(path.parent.stat(follow_symlinks=False).st_mode) != 0o700:
        os.chmod(path.parent, 0o700)
    if stat.S_IMODE(path.stat(follow_symlinks=False).st_mode) != 0o700:
        os.chmod(path, 0o700)
    identity = mount_identity(path)
    if identity["filesystem_type"] in {"9p", "virtiofs", "fuse", "fuseblk"}:
        raise CaptureError("evidence root is on a host-shared or FUSE filesystem")
    stats = os.statvfs(path)
    free_bytes = stats.f_bavail * stats.f_frsize
    required_free = (
        RESOURCE_POLICY["raw_total_max_bytes"]
        + RESOURCE_POLICY["evidence_free_space_reserve_bytes"]
    )
    if free_bytes < required_free:
        raise CaptureError(
            f"evidence free space is below raw bound plus reserve: {free_bytes} < {required_free}"
        )
    identity["free_bytes_before_capture"] = free_bytes
    identity["required_free_bytes"] = required_free
    return identity


def memory_capacity_receipt() -> dict[str, Any]:
    values: dict[str, int] = {}
    for line in Path("/proc/meminfo").read_text(encoding="ascii").splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[1].isdigit() and fields[2] == "kB":
            values[fields[0].rstrip(":")] = int(fields[1]) * 1024
    if "MemTotal" not in values:
        raise CaptureError("MemTotal is absent from /proc/meminfo")
    required = RESOURCE_POLICY["required_vm_memory_min_bytes"]
    if values["MemTotal"] < required:
        raise CaptureError(f"VM memory is below sealed minimum: {values['MemTotal']} < {required}")
    if (
        RESOURCE_POLICY["memory_max_bytes_per_component"]
        + RESOURCE_POLICY["guardian_and_host_reserve_min_bytes"]
        > values["MemTotal"]
    ):
        raise CaptureError("component memory plus guardian reserve exceeds VM memory")
    return {
        "mem_total_bytes": values["MemTotal"],
        "required_vm_memory_min_bytes": required,
        "memory_max_bytes_per_component": RESOURCE_POLICY[
            "memory_max_bytes_per_component"
        ],
        "guardian_and_host_reserve_min_bytes": RESOURCE_POLICY[
            "guardian_and_host_reserve_min_bytes"
        ],
        "supervisor_memory_low_bytes": RESOURCE_POLICY[
            "supervisor_memory_low_bytes"
        ],
        "derived_inequalities_satisfied": True,
    }


def monotonic_ns() -> int:
    return time.monotonic_ns()


def require_root() -> None:
    if os.geteuid() != 0 or os.getegid() != 0:
        raise CaptureError("capture supervisor requires effective root UID and GID")


def require_root_owned_regular(path: Path, label: str, executable: bool = False) -> None:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise CaptureError(f"cannot stat {label}: {path}: {exc}") from exc
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise CaptureError(f"{label} must be a single-link regular file: {path}")
    if metadata.st_uid != 0 or metadata.st_gid != 0:
        raise CaptureError(f"{label} must be root-owned: {path}")
    if metadata.st_mode & 0o022:
        raise CaptureError(f"{label} must not be group/world writable: {path}")
    if executable and not metadata.st_mode & stat.S_IXUSR:
        raise CaptureError(f"{label} must be root-executable: {path}")


def ensure_secure_directory(path: Path, create: bool = False) -> None:
    if create:
        path.mkdir(parents=True, mode=0o700, exist_ok=True)
    metadata = path.stat(follow_symlinks=False)
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_gid != 0:
        raise CaptureError(f"directory is not a root-owned directory: {path}")
    if stat.S_IMODE(metadata.st_mode) & 0o077:
        raise CaptureError(f"directory grants group/world access: {path}")


def load_contract(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    value = strict_json_bytes(raw, "capture contract")
    if not isinstance(value, dict):
        raise CaptureError("capture contract root must be an object")
    canonical = canonical_bytes(value)
    digest = sha256_bytes(canonical)
    if digest != CONTRACT_SHA256:
        raise CaptureError(f"capture contract digest differs: {digest}")
    if value.get("artifact_id") != "f0-c4-authority-disjoint-capture-contract-v1":
        raise CaptureError("capture contract identity differs")
    return value, canonical


def require_contract_binding(contract: dict[str, Any]) -> None:
    """Reject code/contract drift before touching candidate-controlled input."""
    expected_components = [
        {
            "id": component,
            "role": role,
            "max_wall_seconds": deadline,
            "argv_suffix": ["--component", component],
        }
        for component, role, deadline in COMPONENTS
    ]
    component_plan = contract.get("component_plan")
    if not isinstance(component_plan, dict):
        raise CaptureError("contract component plan is absent")
    checks = (
        (
            component_plan.get("execution_order"),
            [component for component, _role, _deadline in COMPONENTS],
            "component execution order",
        ),
        (component_plan.get("components"), expected_components, "component definitions"),
        (
            component_plan.get("argv_prefix"),
            [
                "/usr/bin/python3",
                "-S",
                "-B",
                "INPUT/validate-f0-supervisor-lts-v3.py",
            ],
            "component argv prefix",
        ),
        (component_plan.get("environment"), ENVIRONMENT, "component environment"),
        (component_plan.get("result_protocol"), RESULT_PROTOCOL, "result protocol"),
        (contract.get("resource_policy"), RESOURCE_POLICY, "resource policy"),
        (contract.get("authorization"), AUTHORIZATION, "authorization map"),
    )
    for actual, expected, label in checks:
        if actual != expected:
            raise CaptureError(f"contract and supervisor {label} differ")
    if component_plan.get("parallel_execution") is not False:
        raise CaptureError("contract permits parallel component execution")
    if component_plan.get("candidate_may_add_remove_or_reorder_components") is not False:
        raise CaptureError("contract permits candidate plan mutation")
    required_inputs = contract.get("input_snapshot", {}).get(
        "required_candidate_objects"
    )
    if tuple(required_inputs or ()) != REQUIRED_INPUTS:
        raise CaptureError("contract and supervisor input sets differ")


def copy_exact_snapshot(source: Path, destination: Path) -> tuple[dict[str, str], str]:
    destination.mkdir(mode=0o700)
    source_fd = os.open(source, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    destination_fd = os.open(
        destination, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    )
    digests: dict[str, str] = {}
    total_size = 0
    try:
        for name in REQUIRED_INPUTS:
            input_fd = os.open(
                name,
                os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK,
                dir_fd=source_fd,
            )
            try:
                before = os.fstat(input_fd)
                if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                    raise CaptureError(f"snapshot input is not a single-link file: {name}")
                if before.st_size < 0 or before.st_size > 64 * 1024 * 1024:
                    raise CaptureError(f"snapshot input size is outside policy: {name}")
                output_fd = os.open(
                    name,
                    os.O_WRONLY
                    | os.O_CREAT
                    | os.O_EXCL
                    | os.O_NOFOLLOW
                    | os.O_CLOEXEC,
                    0o400,
                    dir_fd=destination_fd,
                )
                digest = hashlib.sha256()
                copied = 0
                try:
                    while True:
                        block = os.read(input_fd, 1024 * 1024)
                        if not block:
                            break
                        copied += len(block)
                        total_size += len(block)
                        if total_size > 256 * 1024 * 1024:
                            raise CaptureError("snapshot exceeds the total input-size policy")
                        digest.update(block)
                        view = memoryview(block)
                        while view:
                            written = os.write(output_fd, view)
                            view = view[written:]
                    after = os.fstat(input_fd)
                    if (
                        before.st_dev,
                        before.st_ino,
                        before.st_size,
                        before.st_mtime_ns,
                        before.st_ctime_ns,
                        before.st_nlink,
                    ) != (
                        after.st_dev,
                        after.st_ino,
                        after.st_size,
                        after.st_mtime_ns,
                        after.st_ctime_ns,
                        after.st_nlink,
                    ) or copied != before.st_size:
                        raise CaptureError(f"snapshot input changed during copy: {name}")
                    os.fchmod(output_fd, 0o444)
                    os.fsync(output_fd)
                finally:
                    os.close(output_fd)
                digests[name] = digest.hexdigest()
            finally:
                os.close(input_fd)
        os.fchmod(destination_fd, 0o555)
        os.fsync(destination_fd)
    finally:
        os.close(destination_fd)
        os.close(source_fd)
    input_root = sha256_bytes(
        json.dumps(digests, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    return digests, input_root


def write_new_file(path: Path, raw: bytes, mode: int = 0o444) -> str:
    fd = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o400,
    )
    try:
        view = memoryview(raw)
        while view:
            written = os.write(fd, view)
            view = view[written:]
        os.fchmod(fd, mode)
        os.fsync(fd)
    finally:
        os.close(fd)
    return sha256_bytes(raw)


def fsync_directory(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def rename_noreplace(source: Path, destination: Path) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    renameat2 = getattr(libc, "renameat2", None)
    if renameat2 is None:
        raise CaptureError("renameat2 is unavailable")
    renameat2.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameat2.restype = ctypes.c_int
    result = renameat2(
        -100,
        os.fsencode(source),
        -100,
        os.fsencode(destination),
        1,
    )
    if result != 0:
        error = ctypes.get_errno()
        raise CaptureError(f"renameat2(RENAME_NOREPLACE) failed: {os.strerror(error)}")


def write_progress(path: Path | None, percent: int, text: str) -> None:
    if path is None:
        return
    raw = f"{percent}% {text}\n".encode("utf-8")
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    fd = os.open(
        temporary,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o644,
    )
    try:
        os.write(fd, raw)
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(temporary, path)
    fsync_directory(path.parent)


def subid_identity(path: Path, candidate_id: int) -> dict[str, Any]:
    raw = path.read_bytes()
    ranges: list[dict[str, Any]] = []
    for line_number, raw_line in enumerate(raw.decode("utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(":")
        if len(parts) != 3:
            raise CaptureError(f"malformed subordinate-ID row: {path}:{line_number}")
        name, start_text, count_text = parts
        try:
            start = int(start_text, 10)
            count = int(count_text, 10)
        except ValueError as exc:
            raise CaptureError(
                f"non-numeric subordinate-ID row: {path}:{line_number}"
            ) from exc
        if not name or start < 0 or count <= 0 or start + count > 2**32:
            raise CaptureError(f"invalid subordinate-ID row: {path}:{line_number}")
        if start <= candidate_id < start + count:
            raise CaptureError(
                f"reserved candidate identity overlaps {path.name}: {name}:{start}:{count}"
            )
        ranges.append({"name": name, "start": start, "count": count})
    return {"path": str(path), "sha256": sha256_bytes(raw), "ranges": ranges}


def check_candidate_identity(uid: int, gid: int) -> dict[str, Any]:
    if uid != CANDIDATE_UID or gid != CANDIDATE_GID:
        raise CaptureError(
            f"candidate UID/GID must equal the VM-reserved identity {CANDIDATE_UID}"
        )
    try:
        account = pwd.getpwuid(uid)
    except KeyError:
        account = None
    try:
        group = grp.getgrgid(gid)
    except KeyError:
        group = None
    if account is not None or group is not None:
        raise CaptureError("candidate UID/GID must not resolve to login or group entries")
    subuid = subid_identity(Path("/etc/subuid"), uid)
    subgid = subid_identity(Path("/etc/subgid"), gid)
    for status_path in Path("/proc").glob("[0-9]*/status"):
        try:
            lines = status_path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        for line in lines:
            if line.startswith("Uid:") and uid in {int(value) for value in line.split()[1:]}:
                raise CaptureError(f"candidate UID is already live: {uid}")
            if line.startswith("Gid:") and gid in {int(value) for value in line.split()[1:]}:
                raise CaptureError(f"candidate GID is already live: {gid}")
    return {
        "uid": uid,
        "gid": gid,
        "account_entry_absent": True,
        "group_entry_absent": True,
        "subuid": subuid,
        "subgid": subgid,
    }


def lock_candidate_identity(uid: int) -> Any:
    lock_root = Path("/run/domainlease-f0-c4/uid-locks")
    lock_root.mkdir(parents=True, mode=0o700, exist_ok=True)
    os.chown(lock_root, 0, 0)
    os.chmod(lock_root, 0o700)
    lock_path = lock_root / f"uid-{uid}.lock"
    handle = lock_path.open("a+b")
    os.fchmod(handle.fileno(), 0o600)
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as exc:
        handle.close()
        raise CaptureError(f"candidate UID is allocated to another run: {uid}") from exc
    return handle


def current_cgroup() -> Path:
    rows = Path("/proc/self/cgroup").read_text(encoding="ascii").splitlines()
    matches = [row.split("::", 1)[1] for row in rows if "::" in row]
    if len(matches) != 1:
        raise CaptureError("process is not in one unified cgroup-v2 identity")
    return Path("/sys/fs/cgroup") / matches[0].lstrip("/")


def write_cgroup(path: Path, value: str) -> None:
    with path.open("w", encoding="ascii") as handle:
        handle.write(value)


def enable_controllers(path: Path) -> None:
    available = set((path / "cgroup.controllers").read_text(encoding="ascii").split())
    required = {"memory", "pids"}
    if not required <= available:
        raise CaptureError(f"cgroup controllers unavailable at {path}: {sorted(required - available)}")
    write_cgroup(path / "cgroup.subtree_control", "+memory +pids")


def prepare_cgroup_tree(run_id: str) -> tuple[Path, Path]:
    if not os.environ.get("INVOCATION_ID") or os.environ.get("F0_C4_GUARDIAN") != "systemd-v1":
        raise CaptureError("supervisor must be launched by the pinned systemd guardian")
    unit = current_cgroup()
    if unit.name in {"", "init.scope", "system.slice", "user.slice"}:
        raise CaptureError(f"supervisor is not in a dedicated systemd unit: {unit}")
    capture = unit / "capture"
    capture.mkdir(mode=0o755)
    write_cgroup(capture / "cgroup.procs", str(os.getpid()))
    enable_controllers(unit)
    daemon = capture / "daemon"
    run = capture / f"run-{run_id}"
    daemon.mkdir(mode=0o755)
    write_cgroup(daemon / "cgroup.procs", str(os.getpid()))
    enable_controllers(capture)
    run.mkdir(mode=0o755)
    enable_controllers(run)
    return unit, run


def configure_component_cgroup(run_cgroup: Path, component: str) -> Path:
    path = run_cgroup / component
    path.mkdir(mode=0o755)
    write_cgroup(path / "pids.max", str(RESOURCE_POLICY["pids_max_per_component"]))
    write_cgroup(
        path / "memory.max",
        str(RESOURCE_POLICY["memory_max_bytes_per_component"]),
    )
    write_cgroup(
        path / "memory.swap.max",
        str(RESOURCE_POLICY["memory_swap_max_bytes_per_component"]),
    )
    write_cgroup(path / "memory.oom.group", "1")
    return path


def read_optional_at(directory_fd: int, name: str) -> str | None:
    try:
        fd = os.open(
            name,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
            dir_fd=directory_fd,
        )
    except OSError:
        return None
    try:
        raw = os.read(fd, 1024 * 1024 + 1)
        if len(raw) > 1024 * 1024:
            raise CaptureError(f"cgroup counter exceeds size policy: {name}")
        return raw.decode("ascii").strip()
    except UnicodeError as exc:
        raise CaptureError(f"cgroup counter is not ASCII: {name}") from exc
    finally:
        os.close(fd)


def resource_counters(cgroup_fd: int) -> dict[str, str | None]:
    return {
        name: read_optional_at(cgroup_fd, name)
        for name in (
            "cpu.stat",
            "memory.current",
            "memory.peak",
            "memory.events",
            "pids.current",
            "pids.peak",
            "cgroup.events",
        )
    }


def toolchain_identity(
    launcher: Path,
    toolchain_root: Path,
    toolchain_image: Path | None,
    toolchain_manifest: Path | None,
    campaign_class: str,
) -> dict[str, Any]:
    if not toolchain_root.is_absolute() or toolchain_root.is_symlink():
        raise CaptureError("toolchain root must be an absolute non-symlink directory")
    root_metadata = toolchain_root.stat(follow_symlinks=False)
    if (
        not stat.S_ISDIR(root_metadata.st_mode)
        or root_metadata.st_uid != 0
        or root_metadata.st_gid != 0
        or stat.S_IMODE(root_metadata.st_mode) & 0o022
    ):
        raise CaptureError("toolchain root must be a non-writable root-owned directory")
    mount = mount_identity(toolchain_root)

    if campaign_class == "candidate4-exact":
        if toolchain_image is None or toolchain_manifest is None:
            raise CaptureError("exact Candidate-4 capture requires image and manifest paths")
        require_root_owned_regular(toolchain_image, "toolchain image")
        require_root_owned_regular(toolchain_manifest, "toolchain image manifest")
        image_sha256 = sha256_file(toolchain_image)
        manifest_raw = toolchain_manifest.read_bytes()
        manifest = strict_json_bytes(manifest_raw, "toolchain image manifest")
        if canonical_bytes(manifest) != manifest_raw:
            raise CaptureError("toolchain image manifest is not canonical JSON")
        if not isinstance(manifest, dict) or set(manifest) != {
            "schema_version",
            "artifact_id",
            "image_format",
            "image_sha256",
            "file_manifest_sha256",
            "source_machine_id_sha256",
            "source_os_release_sha256",
            "externally_authenticated",
        }:
            raise CaptureError("toolchain image manifest fields differ")
        if (
            manifest["schema_version"] != 1
            or manifest["artifact_id"] != "f0-c4-candidate-toolchain-image-v1"
            or manifest["image_sha256"] != image_sha256
            or manifest["image_format"] not in {"squashfs", "erofs"}
            or manifest["externally_authenticated"] is not False
        ):
            raise CaptureError("toolchain image manifest identity differs")
        for key in (
            "image_sha256",
            "file_manifest_sha256",
            "source_machine_id_sha256",
            "source_os_release_sha256",
        ):
            if not isinstance(manifest[key], str) or not re.fullmatch(
                r"[0-9a-f]{64}", manifest[key]
            ):
                raise CaptureError(f"toolchain manifest digest is malformed: {key}")
        mount_options = set(str(mount["mount_options"]).split(","))
        if (
            mount["filesystem_type"] != manifest["image_format"]
            or "ro" not in mount_options
        ):
            raise CaptureError("toolchain root is not the sealed read-only image format")
        return {
            "mode": "content_addressed_immutable_image",
            "candidate4_admissible": True,
            "image_path": str(toolchain_image),
            "image_sha256": image_sha256,
            "manifest_path": str(toolchain_manifest),
            "manifest_sha256": sha256_bytes(canonical_bytes(manifest)),
            "manifest": manifest,
            "mount_identity": mount,
            "externally_authenticated": False,
        }

    paths = [Path("/usr/bin/python3"), Path("/bin/bash"), Path("/usr/bin/env"), Path("/usr/bin/sha256sum")]
    completed = subprocess.run(
        ["/usr/bin/ldd", "/usr/bin/python3"],
        check=False,
        capture_output=True,
        text=True,
        env={"PATH": "/usr/bin:/bin", "LANG": "C"},
    )
    if completed.returncode != 0 or completed.stderr:
        raise CaptureError("cannot capture Python dynamic-loader identity")
    for line in completed.stdout.splitlines():
        candidate = ""
        if "=> /" in line:
            candidate = "/" + line.split("=> /", 1)[1].split(" (", 1)[0]
        elif line.lstrip().startswith("/"):
            candidate = line.strip().split(" (", 1)[0]
        if candidate:
            paths.append(Path(candidate))
    paths.append(launcher)
    identities: dict[str, dict[str, Any]] = {}
    for path in sorted({item.resolve() for item in paths}, key=str):
        metadata = path.stat()
        identities[str(path)] = {
            "sha256": sha256_file(path),
            "size": metadata.st_size,
            "uid": metadata.st_uid,
            "gid": metadata.st_gid,
            "mode": f"{stat.S_IMODE(metadata.st_mode):04o}",
        }
    os_release = Path("/etc/os-release").read_bytes()
    boot_id = Path("/proc/sys/kernel/random/boot_id").read_text(encoding="ascii").strip()
    selected_identity = {
        "uname": list(os.uname()),
        "boot_id": boot_id,
        "os_release_sha256": sha256_bytes(os_release),
        "files": identities,
    }
    return {
        **selected_identity,
        "mode": "live_usr_mechanism_fixture_only",
        "candidate4_admissible": False,
        "mount_identity": mount,
        "selected_toolchain_manifest_sha256": sha256_bytes(
            canonical_bytes(selected_identity)
        ),
        "externally_authenticated": False,
    }


def fixed_plan(input_root: str) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "contract_sha256": CONTRACT_SHA256,
        "input_root_sha256": input_root,
        "parallel_execution": False,
        "environment": ENVIRONMENT,
        "components": [
            {
                "id": component,
                "role": role,
                "max_wall_seconds": deadline,
                "argv": [
                    "/usr/bin/python3",
                    "-S",
                    "-B",
                    "INPUT/validate-f0-supervisor-lts-v3.py",
                    "--component",
                    component,
                ],
            }
            for component, role, deadline in COMPONENTS
        ],
        "resource_policy": RESOURCE_POLICY,
    }


def validate_launcher_meta(meta: Any, component: str) -> dict[str, Any]:
    if not isinstance(meta, dict) or set(meta) != LAUNCHER_META_KEYS:
        raise CaptureError(f"launcher metadata fields differ: {component}")
    if meta["schema_version"] != 1 or meta["component_id"] != component:
        raise CaptureError(f"launcher metadata identity differs: {component}")
    if type(meta["leader_pid"]) is not int or meta["leader_pid"] <= 0:
        raise CaptureError(f"launcher leader identity invalid: {component}")
    for key in (
        "pidfd_observed",
        "deadline_exceeded",
        "stdout_limit_exceeded",
        "stderr_limit_exceeded",
        "preexec_limit_exceeded",
        "cgroup_kill_used",
        "populated_zero_observed",
        "setup_ok",
        "capture_error",
    ):
        if type(meta[key]) is not bool:
            raise CaptureError(f"launcher Boolean field invalid: {component}:{key}")
    if meta["pidfd_observed"] is not True or meta["cgroup_kill_used"] is not True:
        raise CaptureError(f"launcher lifecycle evidence missing: {component}")
    if (
        type(meta["preexec_observation_size"]) is not int
        or meta["preexec_observation_size"] < 0
        or not isinstance(meta["preexec_observation_sha256"], str)
        or re.fullmatch(r"[0-9a-f]{64}", meta["preexec_observation_sha256"])
        is None
    ):
        raise CaptureError(f"launcher pre-exec observation metadata differs: {component}")
    return meta


def frame_result_payload(path: Path) -> tuple[bool, str | None]:
    """Validate one-line framing and hash the payload without a large allocation."""
    marker = b"RESULT_JSON="
    size = path.stat().st_size
    if size <= len(marker):
        return False, None
    with path.open("rb") as handle:
        if handle.read(len(marker)) != marker:
            return False, None
        ending_size = 0
        if size > len(marker):
            handle.seek(-min(2, size), os.SEEK_END)
            tail = handle.read()
            if tail.endswith(b"\r\n"):
                ending_size = 2
            elif tail.endswith((b"\n", b"\r")):
                ending_size = 1
        payload_size = size - len(marker) - ending_size
        if payload_size <= 0:
            return False, None
        handle.seek(len(marker))
        remaining = payload_size
        digest = hashlib.sha256()
        while remaining:
            block = handle.read(min(1024 * 1024, remaining))
            if not block or b"\n" in block or b"\r" in block:
                return False, None
            digest.update(block)
            remaining -= len(block)
    return True, digest.hexdigest()


def preexec_sections(raw: bytes) -> dict[str, str]:
    try:
        text = raw.decode("utf-8")
    except UnicodeError as exc:
        raise CaptureError("pre-exec observation is not UTF-8") from exc
    prefix = "F0_C4_PREEXEC_ATTESTATION_V1\n"
    suffix = "F0_C4_PREEXEC_ATTESTATION_END\n"
    names = (
        "status",
        "mountinfo",
        "cgroup_identity",
        "namespace_ids",
        "fd_table",
        "interface_inventory",
    )
    if not text.startswith(prefix) or not text.endswith(suffix):
        raise CaptureError(
            "pre-exec observation framing differs: "
            f"size={len(raw)} head={raw[:48]!r} tail={raw[-48:]!r}"
        )
    cursor = len(prefix)
    sections: dict[str, str] = {}
    for index, name in enumerate(names):
        marker = f"[{name}]\n"
        if not text.startswith(marker, cursor):
            raise CaptureError(f"pre-exec observation section order differs: {name}")
        cursor += len(marker)
        next_marker = (
            f"[{names[index + 1]}]\n" if index + 1 < len(names) else suffix
        )
        end = text.find(next_marker, cursor)
        if end < 0:
            raise CaptureError(f"pre-exec observation section is unterminated: {name}")
        sections[name] = text[cursor:end]
        cursor = end
    if cursor != len(text) - len(suffix):
        raise CaptureError("pre-exec observation has trailing unframed bytes")
    return sections


def validate_preexec_observation(
    path: Path,
    meta: dict[str, Any],
    uid: int,
    gid: int,
) -> dict[str, Any]:
    raw = path.read_bytes()
    if len(raw) > RESOURCE_POLICY["preexec_observation_max_bytes_per_component"]:
        raise CaptureError("pre-exec observation exceeds the sealed size bound")
    digest = sha256_bytes(raw)
    if (
        meta["preexec_limit_exceeded"] is not False
        or meta["preexec_observation_size"] != len(raw)
        or meta["preexec_observation_sha256"] != digest
    ):
        raise CaptureError("pre-exec observation size/digest receipt differs")
    sections = preexec_sections(raw)

    status_values: dict[str, str] = {}
    for line in sections["status"].splitlines():
        key, separator, value = line.partition(":")
        if separator:
            status_values[key] = " ".join(value.split())
    expected_status = {
        "Uid": " ".join([str(uid)] * 4),
        "Gid": " ".join([str(gid)] * 4),
        "Groups": "",
        "CapInh": "0000000000000000",
        "CapPrm": "0000000000000000",
        "CapEff": "0000000000000000",
        "CapBnd": "0000000000000000",
        "CapAmb": "0000000000000000",
        "NoNewPrivs": "1",
        "Seccomp": "2",
    }
    for key, expected in expected_status.items():
        if status_values.get(key) != expected:
            raise CaptureError(
                f"pre-exec status differs: {key}={status_values.get(key)!r}"
            )

    fd_rows: dict[int, dict[str, Any]] = {}
    for line in sections["fd_table"].splitlines():
        match = re.fullmatch(r"fd=([0-9]+) cloexec=([01]) target=(.+)", line)
        if match is None:
            raise CaptureError(f"pre-exec fd row is malformed: {line!r}")
        descriptor = int(match.group(1))
        if descriptor in fd_rows:
            raise CaptureError("pre-exec fd table contains a duplicate descriptor")
        fd_rows[descriptor] = {
            "cloexec": match.group(2) == "1",
            "target": match.group(3),
        }
    if len(fd_rows) != 6 or not {0, 1, 2} <= set(fd_rows):
        raise CaptureError(f"pre-exec fd set differs: {sorted(fd_rows)}")
    if fd_rows[0] != {"cloexec": False, "target": "/dev/null"}:
        raise CaptureError("candidate stdin is not non-CLOEXEC read-only /dev/null")
    for descriptor in (1, 2):
        if fd_rows[descriptor]["cloexec"] or not fd_rows[descriptor]["target"].startswith(
            "pipe:["
        ):
            raise CaptureError(f"candidate stdio pipe differs: fd {descriptor}")
    for descriptor in sorted(set(fd_rows) - {0, 1, 2}):
        if not fd_rows[descriptor]["cloexec"] or not fd_rows[descriptor][
            "target"
        ].startswith("pipe:["):
            raise CaptureError(f"trusted pre-exec protocol fd differs: fd {descriptor}")

    namespace_rows = sections["namespace_ids"].splitlines()
    expected_namespaces = ("mnt", "pid", "ipc", "uts", "net", "cgroup")
    if len(namespace_rows) != len(expected_namespaces):
        raise CaptureError("pre-exec namespace inventory count differs")
    for line, name in zip(namespace_rows, expected_namespaces, strict=True):
        if re.fullmatch(rf"{name}={name}:\[[0-9]+\]", line) is None:
            raise CaptureError(f"pre-exec namespace identity differs: {name}")

    cgroup_rows = [line for line in sections["cgroup_identity"].splitlines() if line]
    if cgroup_rows != ["0::/"]:
        raise CaptureError(f"pre-exec cgroup namespace identity differs: {cgroup_rows}")

    mount_rows: dict[str, set[str]] = {}
    for line in sections["mountinfo"].splitlines():
        if not line:
            continue
        left, separator, _right = line.partition(" - ")
        fields = left.split()
        if not separator or len(fields) < 6:
            raise CaptureError("pre-exec mountinfo row is malformed")
        mount_rows[fields[4]] = set(fields[5].split(","))
    for mount_point in ("/usr", "/INPUT"):
        if "ro" not in mount_rows.get(mount_point, set()):
            raise CaptureError(f"pre-exec read-only mount is absent: {mount_point}")

    interfaces = sections["interface_inventory"].splitlines()
    if len(interfaces) != 1 or re.fullmatch(
        r"index=[0-9]+ name=lo flags=0x[0-9a-f]+ up=0 loopback=1",
        interfaces[0],
    ) is None:
        raise CaptureError(f"pre-exec network inventory differs: {interfaces}")

    return {
        "path": path.name,
        "size": len(raw),
        "sha256": digest,
        "validated_fields": [
            "fd_table",
            "uid_gid_groups",
            "capability_sets",
            "no_new_privileges",
            "seccomp_mode",
            "mountinfo",
            "namespace_ids",
            "cgroup_identity",
            "interface_inventory",
        ],
        "candidate_release_after_validation": True,
    }


def invoke_component(
    launcher: Path,
    input_path: Path,
    toolchain_root: Path,
    raw_path: Path,
    runtime_path: Path,
    run_cgroup: Path,
    plan_sha256: str,
    input_root: str,
    toolchain: dict[str, Any],
    uid: int,
    gid: int,
    component: str,
    role: str,
    deadline: int,
) -> tuple[dict[str, Any], bool, int]:
    component_cgroup = configure_component_cgroup(run_cgroup, component)
    component_cgroup_fd = os.open(
        component_cgroup,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
    )
    component_runtime = runtime_path / component
    component_runtime.mkdir(mode=0o700)
    sandbox = component_runtime / "sandbox"
    sandbox.mkdir(mode=0o755)
    stdout_path = raw_path / f"{component}.stdout.raw"
    stderr_path = raw_path / f"{component}.stderr.raw"
    preexec_path = raw_path / f"{component}.preexec.raw"
    argv = [
        "/usr/bin/python3",
        "-S",
        "-B",
        "INPUT/validate-f0-supervisor-lts-v3.py",
        "--component",
        component,
    ]
    command = [
        str(launcher),
        "--cgroup",
        str(component_cgroup),
        "--sandbox-root",
        str(sandbox),
        "--input",
        str(input_path),
        "--toolchain-root",
        str(toolchain_root),
        "--stdout-file",
        str(stdout_path),
        "--stderr-file",
        str(stderr_path),
        "--preexec-file",
        str(preexec_path),
        "--component",
        component,
        "--candidate-uid",
        str(uid),
        "--candidate-gid",
        str(gid),
        "--deadline-seconds",
        str(deadline),
        "--stdout-limit",
        str(RESOURCE_POLICY["stdout_max_bytes_per_component"]),
        "--stderr-limit",
        str(RESOURCE_POLICY["stderr_max_bytes_per_component"]),
        "--preexec-limit",
        str(RESOURCE_POLICY["preexec_observation_max_bytes_per_component"]),
        "--",
        *argv,
    ]
    completed = subprocess.run(
        command,
        check=False,
        capture_output=True,
        stdin=subprocess.DEVNULL,
        env={"PATH": "/usr/bin:/bin", "LANG": "C"},
    )
    if completed.stderr:
        raise CaptureError(f"trusted launcher wrote stderr for {component}: {completed.stderr!r}")
    lines = completed.stdout.splitlines()
    if len(lines) != 1:
        raise CaptureError(f"trusted launcher metadata framing differs: {component}")
    meta = validate_launcher_meta(strict_json_bytes(lines[0], f"launcher metadata {component}"), component)
    stdout_size = stdout_path.stat().st_size
    stderr_size = stderr_path.stat().st_size
    if sha256_file(stdout_path) != meta["stdout_sha256"] or stdout_size != meta["stdout_size"]:
        raise CaptureError(f"root stdout receipt mismatch: {component}")
    if sha256_file(stderr_path) != meta["stderr_sha256"] or stderr_size != meta["stderr_size"]:
        raise CaptureError(f"root stderr receipt mismatch: {component}")
    preexec_observation = validate_preexec_observation(
        preexec_path, meta, uid, gid
    )
    protocol_framing_valid, payload_sha256 = frame_result_payload(stdout_path)
    counters = resource_counters(component_cgroup_fd)
    complete = bool(
        completed.returncode == 0
        and meta["termination"] == "EXITED_ZERO"
        and meta["exit_code"] == 0
        and meta["stderr_size"] == 0
        and meta["populated_zero_observed"] is True
        and meta["setup_ok"] is True
        and meta["capture_error"] is False
        and meta["preexec_limit_exceeded"] is False
        and protocol_framing_valid
    )
    receipt = {
        "schema_version": 1,
        "component_id": component,
        "role": role,
        "sealed_plan_sha256": plan_sha256,
        "input_root_sha256": input_root,
        "argv": argv,
        "environment_sha256": sha256_bytes(canonical_bytes(ENVIRONMENT)),
        "preexec_observation_size_sha256_and_bytes": preexec_observation,
        "cgroup_path_and_id": {
            "path": str(component_cgroup),
            "inode": meta["cgroup_inode"],
        },
        "leader_pid_and_pidfd_identity": {
            "pid": meta["leader_pid"],
            "pidfd_observed": meta["pidfd_observed"],
        },
        "started_monotonic_ns": meta["started_monotonic_ns"],
        "finished_monotonic_ns": meta["finished_monotonic_ns"],
        "waitid_status": {
            "code": meta["waitid_code"],
            "status": meta["waitid_status"],
            "termination": meta["termination"],
            "exit_code": meta["exit_code"],
            "signal": meta["signal"],
        },
        "deadline_classification": {
            "deadline_seconds": deadline,
            "exceeded": meta["deadline_exceeded"],
            "clock": "CLOCK_MONOTONIC",
        },
        "stdout_size_sha256_and_bytes": {
            "path": stdout_path.name,
            "size": meta["stdout_size"],
            "sha256": meta["stdout_sha256"],
        },
        "stderr_size_sha256_and_bytes": {
            "path": stderr_path.name,
            "size": meta["stderr_size"],
            "sha256": meta["stderr_sha256"],
        },
        "result_payload_sha256": payload_sha256,
        "result_protocol_framing_valid": protocol_framing_valid,
        "result_protocol_semantics_validated": False,
        "resource_counters": counters,
        "cgroup_kill_used": meta["cgroup_kill_used"],
        "populated_zero_observed": meta["populated_zero_observed"],
        "toolchain_identity": {
            "sha256": sha256_bytes(canonical_bytes(toolchain)),
            "candidate4_admissible": toolchain["candidate4_admissible"],
        },
        "launcher_returncode": completed.returncode,
        "complete_capture_component": complete,
        "candidate_receipts_authoritative": False,
        "externally_attested": False,
    }
    receipt_path = raw_path / f"{component}.receipt.json"
    receipt_raw = canonical_bytes(receipt)
    if len(receipt_raw) > RESOURCE_POLICY["receipt_max_bytes_per_component"]:
        raise CaptureError(f"component receipt exceeds size policy: {component}")
    write_new_file(receipt_path, receipt_raw)
    raw_size = sum(
        path.stat().st_size
        for path in (stdout_path, stderr_path, preexec_path, receipt_path)
    )
    os.close(component_cgroup_fd)
    try:
        component_cgroup.rmdir()
    except OSError as exc:
        raise CaptureError(f"drained component cgroup could not be removed: {component}: {exc}") from exc
    return receipt, complete, raw_size


def capture(args: argparse.Namespace) -> int:
    require_root()
    if not RUN_ID_RE.fullmatch(args.run_id):
        raise CaptureError("run ID is outside the fixed safe grammar")
    require_root_owned_regular(args.contract, "capture contract")
    require_root_owned_regular(args.launcher, "capture launcher", executable=True)
    require_root_owned_regular(Path(__file__), "capture supervisor")
    contract, contract_canonical = load_contract(args.contract)
    require_contract_binding(contract)
    candidate_identity = check_candidate_identity(args.candidate_uid, args.candidate_gid)
    uid_lock = lock_candidate_identity(args.candidate_uid)
    evidence_storage = require_fixed_native_evidence_root(args.evidence_root)
    ensure_secure_directory(args.evidence_root)
    memory_capacity = memory_capacity_receipt()
    if args.progress is not None:
        ensure_secure_directory(args.progress.parent, create=True)
    final_path = args.evidence_root / args.run_id
    if final_path.exists():
        raise CaptureError(f"final run already exists: {final_path}")
    staging = args.evidence_root / f".staging-{args.run_id}-{os.getpid()}"
    staging.mkdir(mode=0o700)
    raw_path = staging / "raw"
    raw_path.mkdir(mode=0o700)
    input_path = staging / "INPUT"
    runtime_path = Path("/run/domainlease-f0-c4") / f"capture-{args.run_id}-{os.getpid()}"
    runtime_path.mkdir(parents=True, mode=0o700)
    os.chown(runtime_path, 0, 0)
    os.chmod(runtime_path, 0o700)

    write_progress(args.progress, 2, "strict contract and root authority preconditions")
    input_digests, input_root = copy_exact_snapshot(args.source_dir, input_path)
    write_progress(args.progress, 5, "exact eight-object snapshot sealed")
    plan = fixed_plan(input_root)
    plan_raw = canonical_bytes(plan)
    plan_sha256 = write_new_file(staging / "sealed-plan.json", plan_raw)
    contract_copy_sha256 = write_new_file(staging / "capture-contract.json", contract_canonical)
    if contract_copy_sha256 != CONTRACT_SHA256:
        raise CaptureError("copied contract digest differs")
    toolchain = toolchain_identity(
        args.launcher,
        args.toolchain_root,
        args.toolchain_image,
        args.toolchain_manifest,
        args.campaign_class,
    )
    toolchain_sha256 = write_new_file(
        staging / "toolchain-identity.json", canonical_bytes(toolchain)
    )
    unit_cgroup, run_cgroup = prepare_cgroup_tree(args.run_id)
    write_progress(args.progress, 8, "systemd guardian and delegated cgroup tree established")

    receipts: list[dict[str, Any]] = []
    receipt_bindings: dict[str, str] = {}
    raw_total = 0
    complete = True
    progress_points = [12, 20, 40, 62, 85]
    for index, (component, role, deadline) in enumerate(COMPONENTS):
        write_progress(args.progress, progress_points[index], f"capturing {component}")
        receipt, component_complete, component_raw_size = invoke_component(
            args.launcher,
            input_path,
            args.toolchain_root,
            raw_path,
            runtime_path,
            run_cgroup,
            plan_sha256,
            input_root,
            toolchain,
            args.candidate_uid,
            args.candidate_gid,
            component,
            role,
            deadline,
        )
        receipts.append(receipt)
        receipt_path = raw_path / f"{component}.receipt.json"
        receipt_bindings[component] = sha256_file(receipt_path)
        raw_total += component_raw_size
        if raw_total > RESOURCE_POLICY["raw_total_max_bytes"]:
            raise CaptureError("raw capture exceeds the sealed total-size bound")
        if not component_complete:
            complete = False
            break

    capture_status = (
        "RAW_CAPTURE_COMPLETE"
        if complete and len(receipts) == len(COMPONENTS)
        else "RAW_CAPTURE_INCOMPLETE"
    )
    write_progress(args.progress, 92, "finalizing root-owned raw capture")
    manifest = {
        "schema_version": 1,
        "artifact_id": "f0-c4-authority-disjoint-root-capture-v1",
        "run_id": args.run_id,
        "campaign_class": args.campaign_class,
        "capture_status": capture_status,
        "contract_sha256": CONTRACT_SHA256,
        "sealed_plan_sha256": plan_sha256,
        "input_digests": input_digests,
        "input_root_sha256": input_root,
        "toolchain_identity_sha256": toolchain_sha256,
        "platform_capacity": memory_capacity,
        "evidence_storage": evidence_storage,
        "systemd_guardian": {
            "invocation_id": os.environ["INVOCATION_ID"],
            "unit_cgroup": str(unit_cgroup),
            "run_cgroup": str(run_cgroup),
            "pinned_profile": os.environ["F0_C4_GUARDIAN"],
        },
        "candidate_identity": {
            **candidate_identity,
            "exclusive_lock_held_through_finalization": True,
        },
        "component_order": [receipt["component_id"] for receipt in receipts],
        "component_receipt_sha256": receipt_bindings,
        "raw_total_bytes": raw_total,
        "started_and_finished_clock": "CLOCK_MONOTONIC",
        "finished_monotonic_ns": monotonic_ns(),
        "candidate_summary_is_an_oracle": False,
        "external_attestation": False,
        "authorization": AUTHORIZATION,
    }
    manifest_raw = canonical_bytes(manifest)
    manifest_sha256 = write_new_file(staging / "capture-manifest.json", manifest_raw)
    fsync_directory(raw_path)
    os.chmod(raw_path, 0o555)
    fsync_directory(input_path)
    fsync_directory(staging)
    rename_noreplace(staging, final_path)
    fsync_directory(args.evidence_root)
    commit = {
        "schema_version": 1,
        "artifact_id": "f0-c4-raw-capture-commit-v1",
        "run_id": args.run_id,
        "capture_status": capture_status,
        "contract_sha256": CONTRACT_SHA256,
        "manifest_sha256": manifest_sha256,
        "publication": "renameat2_RENAME_NOREPLACE_then_parent_fsync",
        "commit_authority": "CAPTURE_SUPERVISOR",
        "candidate_bytes_positive_eligible": False,
        "reduction_performed": False,
    }
    commit_sha256 = write_new_file(final_path / "RAW_COMMIT.json", canonical_bytes(commit))
    os.chmod(final_path, 0o555)
    fsync_directory(final_path)
    fsync_directory(args.evidence_root)
    write_progress(
        args.progress,
        100,
        "root capture finalized; reduction remains separate"
        if capture_status == "RAW_CAPTURE_COMPLETE"
        else "incomplete capture finalized fail-closed",
    )
    uid_lock.close()
    shutil.rmtree(runtime_path, ignore_errors=True)
    summary = {
        "run_id": args.run_id,
        "capture_status": capture_status,
        "manifest_sha256": manifest_sha256,
        "commit_sha256": commit_sha256,
        "final_path": str(final_path),
        "component_count": len(receipts),
        "reduction_performed": False,
        "authorization_changed": False,
    }
    print(f"CAPTURE_JSON={json.dumps(summary, sort_keys=True, separators=(',', ':'))}")
    return 0 if capture_status == "RAW_CAPTURE_COMPLETE" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument(
        "--campaign-class",
        required=True,
        choices=("candidate4-exact", "mechanism-fixture"),
    )
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--evidence-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--launcher", required=True, type=Path)
    parser.add_argument("--toolchain-root", required=True, type=Path)
    parser.add_argument("--toolchain-image", type=Path)
    parser.add_argument("--toolchain-manifest", type=Path)
    parser.add_argument("--candidate-uid", required=True, type=int)
    parser.add_argument("--candidate-gid", required=True, type=int)
    parser.add_argument("--progress", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        return capture(args)
    except (CaptureError, OSError, KeyError, ValueError) as exc:
        print(f"F0_C4_CAPTURE_SUPERVISOR_REJECT {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
