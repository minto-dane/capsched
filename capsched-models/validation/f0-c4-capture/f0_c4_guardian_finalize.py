#!/usr/bin/python3
"""Register and fail-closed-finalize a Candidate-4 systemd capture run."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import time
from pathlib import Path
from typing import Any, Iterable


CONTRACT_SHA256 = "0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d"
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
STATE_ROOT = Path("/var/lib/domainlease-f0-c4")
EVIDENCE_ROOT = STATE_ROOT / "evidence"
GUARD_ROOT = STATE_ROOT / "intents"
RENAME_NOREPLACE = 1
AT_FDCWD = -100


class GuardianError(RuntimeError):
    """The guardian could not prove a safe incomplete disposition."""


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def reject_constant(value: str) -> None:
    raise GuardianError(f"non-finite JSON number: {value}")


def unique_object(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise GuardianError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def require_root() -> None:
    if os.geteuid() != 0 or os.getegid() != 0:
        raise GuardianError("guardian finalizer requires effective root UID and GID")


def require_run_id(run_id: str) -> None:
    if not RUN_ID_RE.fullmatch(run_id):
        raise GuardianError("run ID is outside the fixed safe grammar")


def ensure_root_directory(path: Path, create: bool = False) -> None:
    if create:
        path.mkdir(parents=True, mode=0o700, exist_ok=True)
    metadata = path.stat(follow_symlinks=False)
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_gid != 0:
        raise GuardianError(f"not a root-owned directory: {path}")
    if stat.S_IMODE(metadata.st_mode) & 0o077:
        raise GuardianError(f"directory grants group/world access: {path}")


def fsync_directory(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def write_new_file(path: Path, raw: bytes, mode: int) -> str:
    fd = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o600,
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
    return hashlib.sha256(raw).hexdigest()


def rename_noreplace(source: Path, destination: Path) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    renameat2 = getattr(libc, "renameat2", None)
    if renameat2 is None:
        raise GuardianError("renameat2 is unavailable")
    renameat2.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameat2.restype = ctypes.c_int
    if (
        renameat2(
            AT_FDCWD,
            os.fsencode(source),
            AT_FDCWD,
            os.fsencode(destination),
            RENAME_NOREPLACE,
        )
        != 0
    ):
        error = ctypes.get_errno()
        raise GuardianError(
            f"renameat2(RENAME_NOREPLACE) failed: {os.strerror(error)}"
        )


def guard_path(run_id: str) -> Path:
    return GUARD_ROOT / f"{run_id}.json"


def register(run_id: str, evidence_root: Path) -> int:
    require_root()
    require_run_id(run_id)
    if evidence_root != EVIDENCE_ROOT:
        raise GuardianError(f"evidence root must be fixed at {EVIDENCE_ROOT}")
    ensure_root_directory(evidence_root)
    ensure_root_directory(GUARD_ROOT, create=True)
    if (evidence_root / run_id).exists():
        raise GuardianError("final run path already exists")
    record = {
        "schema_version": 1,
        "run_id": run_id,
        "evidence_root": os.fspath(evidence_root),
        "contract_sha256": CONTRACT_SHA256,
        "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text(
            encoding="ascii"
        ).strip(),
        "registered_monotonic_ns": time.monotonic_ns(),
        "registration_authority": "ROOT_GUARDIAN",
        "candidate_may_modify": False,
    }
    path = guard_path(run_id)
    write_new_file(path, canonical_bytes(record), 0o600)
    fsync_directory(GUARD_ROOT)
    print(f"F0_C4_GUARDIAN_REGISTERED run_id={run_id}")
    return 0


def load_guard(run_id: str) -> tuple[Path, dict[str, Any]] | None:
    path = guard_path(run_id)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except FileNotFoundError:
        return None
    try:
        metadata = os.fstat(fd)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_nlink != 1
            or metadata.st_uid != 0
            or metadata.st_gid != 0
            or stat.S_IMODE(metadata.st_mode) & 0o077
        ):
            raise GuardianError("guardian registration is not a private root file")
        with os.fdopen(fd, "rb", closefd=False) as handle:
            raw = handle.read(64 * 1024 + 1)
        if len(raw) > 64 * 1024:
            raise GuardianError("guardian registration exceeds size policy")
    finally:
        os.close(fd)
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise GuardianError(f"guardian registration is not strict JSON: {exc}") from exc
    if not isinstance(value, dict) or set(value) != {
        "schema_version",
        "run_id",
        "evidence_root",
        "contract_sha256",
        "boot_id",
        "registered_monotonic_ns",
        "registration_authority",
        "candidate_may_modify",
    }:
        raise GuardianError("guardian registration fields differ")
    if (
        value["schema_version"] != 1
        or value["run_id"] != run_id
        or value["contract_sha256"] != CONTRACT_SHA256
        or not isinstance(value["boot_id"], str)
        or re.fullmatch(r"[0-9a-f-]{36}", value["boot_id"]) is None
        or value["registration_authority"] != "ROOT_GUARDIAN"
        or value["candidate_may_modify"] is not False
    ):
        raise GuardianError("guardian registration identity differs")
    return path, value


def current_unit_cgroup() -> Path:
    rows = Path("/proc/self/cgroup").read_text(encoding="ascii").splitlines()
    matches = [row.split("::", 1)[1] for row in rows if "::" in row]
    if len(matches) != 1:
        raise GuardianError("guardian is not in one unified cgroup-v2 identity")
    return Path("/sys/fs/cgroup") / matches[0].lstrip("/")


def cgroup_populated(events_fd: int) -> bool:
    os.lseek(events_fd, 0, os.SEEK_SET)
    rows = os.read(events_fd, 4096).decode("ascii").splitlines()
    values = [row.split() for row in rows]
    populated = [parts[1] for parts in values if len(parts) == 2 and parts[0] == "populated"]
    if populated not in (["0"], ["1"]):
        raise GuardianError("capture cgroup populated state is malformed")
    return populated[0] == "1"


def drain_capture_subtree() -> dict[str, Any]:
    unit = current_unit_cgroup()
    capture = unit / "capture"
    receipt: dict[str, Any] = {
        "unit_cgroup": os.fspath(unit),
        "capture_cgroup": os.fspath(capture),
        "capture_cgroup_present": capture.is_dir(),
        "cgroup_kill_written": False,
        "populated_zero_observed": False,
        "drain_clock": "CLOCK_MONOTONIC",
        "drain_max_seconds": 30,
    }
    if not capture.is_dir():
        receipt["populated_zero_observed"] = True
        receipt["absence_meaning"] = "supervisor_never_created_candidate_subtree"
        return receipt
    capture_fd = os.open(
        capture, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    events_fd = -1
    kill_fd = -1
    try:
        events_fd = os.open(
            "cgroup.events",
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=capture_fd,
        )
        kill_fd = os.open(
            "cgroup.kill",
            os.O_WRONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=capture_fd,
        )
        if os.write(kill_fd, b"1") != 1:
            raise GuardianError("short write to capture cgroup.kill")
        receipt["cgroup_kill_written"] = True
    except OSError as exc:
        raise GuardianError(f"cannot kill capture cgroup subtree: {exc}") from exc
    try:
        deadline = time.monotonic() + 30
        while cgroup_populated(events_fd):
            if time.monotonic() >= deadline:
                raise GuardianError("capture cgroup did not drain within 30 seconds")
            time.sleep(0.01)
        receipt["populated_zero_observed"] = True
        return receipt
    finally:
        if kill_fd >= 0:
            os.close(kill_fd)
        if events_fd >= 0:
            os.close(events_fd)
        os.close(capture_fd)


def partial_staging_summary(evidence_root: Path, run_id: str) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    prefix = f".staging-{run_id}-"
    for candidate in sorted(evidence_root.iterdir(), key=lambda item: item.name):
        if not candidate.name.startswith(prefix):
            continue
        metadata = candidate.stat(follow_symlinks=False)
        if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0:
            raise GuardianError("abandoned staging path is not a root-owned directory")
        file_count = 0
        byte_count = 0
        for root, directories, files in os.walk(candidate, followlinks=False):
            directories.sort()
            files.sort()
            file_count += len(files)
            if file_count > 128:
                raise GuardianError("abandoned staging exceeds file-count policy")
            for name in files:
                path = Path(root) / name
                item = path.stat(follow_symlinks=False)
                if not stat.S_ISREG(item.st_mode) or item.st_uid != 0:
                    raise GuardianError("abandoned staging contains a non-root regular object")
                byte_count += item.st_size
        summaries.append(
            {
                "name": candidate.name,
                "file_count": file_count,
                "byte_count": byte_count,
            }
        )
    return summaries


def remove_guard(path: Path) -> None:
    path.unlink()
    fsync_directory(GUARD_ROOT)


def load_canonical_file(path: Path, limit: int, label: str) -> tuple[dict[str, Any], bytes]:
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        metadata = os.fstat(fd)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_nlink != 1
            or metadata.st_uid != 0
            or metadata.st_gid != 0
            or stat.S_IMODE(metadata.st_mode) & 0o222
        ):
            raise GuardianError(f"{label} is not immutable root-owned regular data")
        raw = os.read(fd, limit + 1)
    finally:
        os.close(fd)
    if len(raw) > limit:
        raise GuardianError(f"{label} exceeds size policy")
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise GuardianError(f"{label} is not strict JSON: {exc}") from exc
    if not isinstance(value, dict) or canonical_bytes(value) != raw:
        raise GuardianError(f"{label} is not a canonical JSON object")
    return value, raw


def committed_run(path: Path, run_id: str) -> bool:
    try:
        metadata = path.stat(follow_symlinks=False)
    except FileNotFoundError:
        return False
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_gid != 0:
        raise GuardianError("published run is not an immutable root-owned directory")
    if stat.S_IMODE(metadata.st_mode) & 0o222:
        return False
    commit_path = path / "RAW_COMMIT.json"
    try:
        commit, _raw = load_canonical_file(commit_path, 64 * 1024, "raw commit")
    except FileNotFoundError:
        return False
    common = (
        commit.get("schema_version") == 1
        and commit.get("run_id") == run_id
        and commit.get("contract_sha256") == CONTRACT_SHA256
        and commit.get("candidate_bytes_positive_eligible") is False
        and commit.get("reduction_performed") is False
    )
    if not common:
        raise GuardianError("raw commit common identity differs")
    artifact = commit.get("artifact_id")
    if artifact == "f0-c4-raw-capture-commit-v1":
        if (
            commit.get("capture_status")
            not in {"RAW_CAPTURE_COMPLETE", "RAW_CAPTURE_INCOMPLETE"}
            or commit.get("commit_authority") != "CAPTURE_SUPERVISOR"
            or not isinstance(commit.get("manifest_sha256"), str)
        ):
            raise GuardianError("supervisor raw commit identity differs")
        manifest_path = path / "capture-manifest.json"
        if sha256_file(manifest_path) != commit["manifest_sha256"]:
            raise GuardianError("supervisor raw commit does not bind the manifest")
        return True
    if artifact == "f0-c4-guardian-incomplete-commit-v1":
        if (
            commit.get("capture_status") != "GUARDIAN_INCOMPLETE_PUBLISHED"
            or commit.get("commit_authority") != "ROOT_GUARDIAN"
            or not isinstance(commit.get("disposition_sha256"), str)
        ):
            raise GuardianError("guardian incomplete commit identity differs")
        disposition = path / "guardian-incomplete.json"
        if sha256_file(disposition) != commit["disposition_sha256"]:
            raise GuardianError("guardian commit does not bind its disposition")
        return True
    raise GuardianError("raw commit artifact identity differs")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def publish_incomplete(
    registration: dict[str, Any],
    failure_class: str,
    drain: dict[str, Any],
) -> Path:
    run_id = registration["run_id"]
    evidence_root = Path(registration["evidence_root"])
    final_path = evidence_root / run_id
    destination = final_path
    if final_path.exists():
        destination = evidence_root / f"{run_id}.guardian-incomplete"
    if destination.exists():
        if committed_run(destination, run_id):
            return destination
        raise GuardianError("guardian incomplete destination exists without a valid commit")

    partial = partial_staging_summary(evidence_root, run_id)
    for summary in partial:
        shutil.rmtree(evidence_root / summary["name"])
    staging = evidence_root / f".guardian-{run_id}-{os.getpid()}"
    staging.mkdir(mode=0o700)
    current_boot_id = Path("/proc/sys/kernel/random/boot_id").read_text(
        encoding="ascii"
    ).strip()
    record = {
        "schema_version": 1,
        "artifact_id": "f0-c4-guardian-incomplete-disposition-v1",
        "run_id": run_id,
        "capture_status": "GUARDIAN_INCOMPLETE_PUBLISHED",
        "failure_class": failure_class,
        "contract_sha256": CONTRACT_SHA256,
        "registered_boot_id": registration["boot_id"],
        "finalized_boot_id": current_boot_id,
        "registered_monotonic_ns": registration["registered_monotonic_ns"],
        "finalized_monotonic_ns": time.monotonic_ns(),
        "systemd_result": {
            "SERVICE_RESULT": os.environ.get("SERVICE_RESULT"),
            "EXIT_CODE": os.environ.get("EXIT_CODE"),
            "EXIT_STATUS": os.environ.get("EXIT_STATUS"),
            "INVOCATION_ID": os.environ.get("INVOCATION_ID"),
        },
        "drain_receipt": drain,
        "uncommitted_published_path_present": final_path.exists(),
        "abandoned_staging_removed": partial,
        "candidate_bytes_positive_eligible": False,
        "reduction_performed": False,
        "authorization_changed": False,
    }
    disposition_raw = canonical_bytes(record)
    disposition_sha256 = write_new_file(
        staging / "guardian-incomplete.json", disposition_raw, 0o444
    )
    fsync_directory(staging)
    rename_noreplace(staging, destination)
    fsync_directory(evidence_root)
    commit = {
        "schema_version": 1,
        "artifact_id": "f0-c4-guardian-incomplete-commit-v1",
        "run_id": run_id,
        "capture_status": "GUARDIAN_INCOMPLETE_PUBLISHED",
        "failure_class": failure_class,
        "contract_sha256": CONTRACT_SHA256,
        "disposition_sha256": disposition_sha256,
        "commit_authority": "ROOT_GUARDIAN",
        "candidate_bytes_positive_eligible": False,
        "reduction_performed": False,
    }
    write_new_file(destination / "RAW_COMMIT.json", canonical_bytes(commit), 0o444)
    os.chmod(destination, 0o555)
    fsync_directory(destination)
    fsync_directory(evidence_root)
    return destination


def finalize(run_id: str) -> int:
    require_root()
    require_run_id(run_id)
    loaded = load_guard(run_id)
    if loaded is None:
        print(f"F0_C4_GUARDIAN_NOOP run_id={run_id}")
        return 0
    registration_path, registration = loaded
    evidence_root = Path(registration["evidence_root"])
    if evidence_root != EVIDENCE_ROOT:
        raise GuardianError("registered evidence root is not the fixed native root")
    ensure_root_directory(evidence_root)
    drain = drain_capture_subtree()
    final_path = evidence_root / run_id
    if committed_run(final_path, run_id):
        fsync_directory(evidence_root)
        remove_guard(registration_path)
        print(f"F0_C4_GUARDIAN_PRESERVED_FINAL run_id={run_id}")
        return 0
    failure_class = (
        "FINALIZATION_FAILED"
        if os.environ.get("SERVICE_RESULT") == "success"
        else "SUPERVISOR_DIED"
    )
    disposition = publish_incomplete(registration, failure_class, drain)
    remove_guard(registration_path)
    print(
        f"F0_C4_GUARDIAN_FINAL_INCOMPLETE run_id={run_id} path={disposition}"
    )
    return 0


def reconcile() -> int:
    require_root()
    ensure_root_directory(EVIDENCE_ROOT)
    ensure_root_directory(GUARD_ROOT, create=True)
    current_boot_id = Path("/proc/sys/kernel/random/boot_id").read_text(
        encoding="ascii"
    ).strip()
    reconciled = 0
    preserved = 0
    active = 0
    for path in sorted(GUARD_ROOT.glob("*.json"), key=lambda item: item.name):
        run_id = path.stem
        require_run_id(run_id)
        loaded = load_guard(run_id)
        if loaded is None:
            continue
        registration_path, registration = loaded
        final_path = EVIDENCE_ROOT / run_id
        if committed_run(final_path, run_id):
            remove_guard(registration_path)
            preserved += 1
            continue
        if registration["boot_id"] == current_boot_id:
            active += 1
            continue
        drain = {
            "prior_boot_id": registration["boot_id"],
            "current_boot_id": current_boot_id,
            "prior_boot_process_survival_possible": False,
            "cgroup_kill_written": False,
            "populated_zero_observed": True,
            "absence_meaning": "Linux processes cannot survive a VM reboot",
        }
        publish_incomplete(registration, "BOOT_INTERRUPTED", drain)
        remove_guard(registration_path)
        reconciled += 1
    print(
        "F0_C4_GUARDIAN_RECONCILE_PASS "
        f"boot_interrupted={reconciled} preserved={preserved} active={active}"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    register_parser = subparsers.add_parser("register")
    register_parser.add_argument("--run-id", required=True)
    register_parser.add_argument("--evidence-root", required=True, type=Path)
    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("--run-id", required=True)
    subparsers.add_parser("reconcile")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "register":
            return register(args.run_id, args.evidence_root)
        if args.command == "finalize":
            return finalize(args.run_id)
        return reconcile()
    except (GuardianError, OSError, KeyError, TypeError, ValueError) as exc:
        print(f"F0_C4_GUARDIAN_REJECT {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
