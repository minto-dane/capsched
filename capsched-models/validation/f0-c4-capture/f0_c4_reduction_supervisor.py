#!/usr/bin/python3
"""Root reduction supervisor for one finalized Candidate-4 raw capture."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import grp
import pwd
import re
import stat
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable


CONTRACT_SHA256 = "0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d"
RUN_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")
STATE_ROOT = Path("/var/lib/domainlease-f0-c4")
EVIDENCE_ROOT = STATE_ROOT / "evidence"
REDUCTION_ROOT = STATE_ROOT / "reductions"
TOOLCHAIN_ROOT = STATE_ROOT / "toolchain" / "root"
REDUCER_UID = 200011
REDUCER_GID = 200011
MAX_REDUCER_OUTPUT = 1048576
MAX_REDUCER_STDERR = 1048576
MAX_METADATA = 16777216
RENAME_NOREPLACE = 1
AT_FDCWD = -100
libc = ctypes.CDLL(None, use_errno=True)


class ReductionSupervisorError(RuntimeError):
    """A reduction precondition or publication invariant failed closed."""


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON constant: {value}")


def unique_object(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json(raw: bytes, label: str) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeError, ValueError, json.JSONDecodeError) as exc:
        raise ReductionSupervisorError(f"{label} is not strict JSON") from exc


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        while True:
            block = os.read(fd, 1024 * 1024)
            if not block:
                break
            digest.update(block)
    finally:
        os.close(fd)
    return digest.hexdigest()


def require_root() -> None:
    if os.geteuid() != 0 or os.getegid() != 0:
        raise ReductionSupervisorError("reduction supervisor requires root UID/GID")


def require_root_regular(path: Path, label: str, executable: bool = False) -> None:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise ReductionSupervisorError(f"cannot stat {label}: {path}") from exc
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != 0
        or metadata.st_gid != 0
        or metadata.st_mode & 0o022
        or (executable and not metadata.st_mode & stat.S_IXUSR)
    ):
        raise ReductionSupervisorError(f"{label} metadata differs: {path}")


def require_directory(path: Path, label: str, mode: int | None = None) -> None:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise ReductionSupervisorError(f"cannot stat {label}: {path}") from exc
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != 0
        or metadata.st_gid != 0
        or metadata.st_mode & 0o022
        or (mode is not None and stat.S_IMODE(metadata.st_mode) != mode)
    ):
        raise ReductionSupervisorError(f"{label} metadata differs: {path}")


def mount_identity(path: Path) -> dict[str, str]:
    metadata = path.stat(follow_symlinks=False)
    device = f"{os.major(metadata.st_dev)}:{os.minor(metadata.st_dev)}"
    selected: tuple[str, str, str, str] | None = None
    for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
        left, separator, right = line.partition(" - ")
        left_fields = left.split()
        right_fields = right.split()
        if not separator or len(left_fields) < 6 or len(right_fields) < 3:
            raise ReductionSupervisorError("mountinfo row is malformed")
        mount_point = left_fields[4].replace("\\040", " ")
        path_text = str(path)
        if left_fields[2] != device or not (
            path_text == mount_point
            or (mount_point != "/" and path_text.startswith(mount_point + "/"))
            or mount_point == "/"
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
        raise ReductionSupervisorError(f"cannot identify mount: {path}")
    mount_point, options, filesystem, source = selected
    return {
        "device": device,
        "mount_point": mount_point,
        "mount_options": options,
        "filesystem_type": filesystem,
        "source": source,
    }


def ensure_reduction_root() -> dict[str, Any]:
    require_directory(STATE_ROOT, "state root", 0o700)
    if not REDUCTION_ROOT.exists():
        REDUCTION_ROOT.mkdir(mode=0o700)
        os.chown(REDUCTION_ROOT, 0, 0)
    require_directory(REDUCTION_ROOT, "reduction root", 0o700)
    identity = mount_identity(REDUCTION_ROOT)
    if identity["filesystem_type"] in {"9p", "virtiofs", "fuse", "fuseblk"}:
        raise ReductionSupervisorError("reduction root is on a host-shared filesystem")
    stats = os.statvfs(REDUCTION_ROOT)
    identity["free_bytes_before_reduction"] = stats.f_bavail * stats.f_frsize
    if identity["free_bytes_before_reduction"] < 10737418240:
        raise ReductionSupervisorError("reduction root free-space reserve is absent")
    return identity


def read_root_file(path: Path, label: str, maximum: int = MAX_METADATA) -> bytes:
    require_root_regular(path, label)
    metadata = path.stat(follow_symlinks=False)
    if metadata.st_size < 0 or metadata.st_size > maximum:
        raise ReductionSupervisorError(f"{label} exceeds size bound")
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(fd)
        blocks: list[bytes] = []
        remaining = before.st_size
        while remaining:
            block = os.read(fd, min(1024 * 1024, remaining))
            if not block:
                raise ReductionSupervisorError(f"{label} ended early")
            blocks.append(block)
            remaining -= len(block)
        if os.read(fd, 1):
            raise ReductionSupervisorError(f"{label} grew while read")
        after = os.fstat(fd)
        if (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        ) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        ):
            raise ReductionSupervisorError(f"{label} changed while read")
        return b"".join(blocks)
    finally:
        os.close(fd)


def validate_raw_commit(run_id: str) -> dict[str, Any]:
    capture = EVIDENCE_ROOT / run_id
    require_directory(capture, "published capture", 0o555)
    commit_raw = read_root_file(capture / "RAW_COMMIT.json", "raw commit")
    commit = strict_json(commit_raw, "raw commit")
    expected_commit_keys = {
        "schema_version",
        "artifact_id",
        "run_id",
        "capture_status",
        "contract_sha256",
        "manifest_sha256",
        "publication",
        "commit_authority",
        "candidate_bytes_positive_eligible",
        "reduction_performed",
    }
    if not isinstance(commit, dict) or set(commit) != expected_commit_keys:
        raise ReductionSupervisorError("raw commit fields differ")
    if canonical_bytes(commit) != commit_raw:
        raise ReductionSupervisorError("raw commit is not canonical")
    if (
        commit["schema_version"] != 1
        or commit["artifact_id"] != "f0-c4-raw-capture-commit-v1"
        or commit["run_id"] != run_id
        or commit["capture_status"] != "RAW_CAPTURE_COMPLETE"
        or commit["contract_sha256"] != CONTRACT_SHA256
        or commit["publication"] != "renameat2_RENAME_NOREPLACE_then_parent_fsync"
        or commit["commit_authority"] != "CAPTURE_SUPERVISOR"
        or commit["candidate_bytes_positive_eligible"] is not False
        or commit["reduction_performed"] is not False
    ):
        raise ReductionSupervisorError("raw commit identity differs")
    manifest_raw = read_root_file(capture / "capture-manifest.json", "raw manifest")
    manifest = strict_json(manifest_raw, "raw manifest")
    if (
        not isinstance(manifest, dict)
        or canonical_bytes(manifest) != manifest_raw
        or sha256_bytes(manifest_raw) != commit["manifest_sha256"]
        or manifest.get("run_id") != run_id
        or manifest.get("capture_status") != "RAW_CAPTURE_COMPLETE"
        or manifest.get("campaign_class") != "candidate4-exact"
        or manifest.get("contract_sha256") != CONTRACT_SHA256
    ):
        raise ReductionSupervisorError("raw manifest binding differs")
    return {
        "capture_path": str(capture),
        "raw_commit_sha256": sha256_bytes(commit_raw),
        "raw_manifest_sha256": sha256_bytes(manifest_raw),
    }


def validate_toolchain() -> dict[str, str]:
    require_directory(TOOLCHAIN_ROOT, "toolchain root")
    identity = mount_identity(TOOLCHAIN_ROOT)
    if (
        identity["filesystem_type"] != "erofs"
        or "ro" not in identity["mount_options"].split(",")
    ):
        raise ReductionSupervisorError("toolchain root is not read-only EROFS")
    return identity


def validate_reducer_identity_policy() -> dict[str, Any]:
    try:
        passwd = pwd.getpwnam("domainlease-reducer")
        group = grp.getgrnam("domainlease-reducer")
    except KeyError as exc:
        raise ReductionSupervisorError("dedicated reducer account is absent") from exc
    if (
        passwd.pw_uid != REDUCER_UID
        or passwd.pw_gid != REDUCER_GID
        or passwd.pw_dir != "/nonexistent"
        or passwd.pw_shell != "/usr/sbin/nologin"
        or group.gr_gid != REDUCER_GID
        or group.gr_mem
        or os.getgrouplist("domainlease-reducer", REDUCER_GID) != [REDUCER_GID]
    ):
        raise ReductionSupervisorError("dedicated reducer account identity differs")
    range_digests: dict[str, str] = {}
    for path in (Path("/etc/subuid"), Path("/etc/subgid")):
        if not path.is_file() or path.is_symlink():
            raise ReductionSupervisorError(f"subordinate range file differs: {path}")
        raw = path.read_bytes()
        range_digests[str(path)] = sha256_bytes(raw)
        for line in raw.decode("ascii").splitlines():
            fields = line.split(":")
            if len(fields) != 3 or not fields[1].isdigit() or not fields[2].isdigit():
                raise ReductionSupervisorError(f"subordinate range row differs: {path}")
            start = int(fields[1])
            count = int(fields[2])
            if count <= 0 or start <= REDUCER_UID < start + count:
                raise ReductionSupervisorError("reducer identity is subordinate-ID allocatable")
    return {
        "account": "domainlease-reducer",
        "uid": REDUCER_UID,
        "gid": REDUCER_GID,
        "home": passwd.pw_dir,
        "shell": passwd.pw_shell,
        "supplementary_groups": [],
        "subordinate_range_sha256": range_digests,
    }


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


def rename_noreplace(source: Path, target: Path) -> None:
    result = libc.renameat2(
        ctypes.c_int(AT_FDCWD),
        ctypes.c_char_p(os.fsencode(source)),
        ctypes.c_int(AT_FDCWD),
        ctypes.c_char_p(os.fsencode(target)),
        ctypes.c_uint(RENAME_NOREPLACE),
    )
    if result != 0:
        error = ctypes.get_errno()
        raise ReductionSupervisorError(f"reduction no-replace publication failed: errno={error}")


def reducer_command(
    run_id: str,
    reducer: Path,
    capture: Path,
    parent_unit: str,
) -> tuple[list[str], dict[str, Any]]:
    if reducer.name != "f0-c4-post-run-reducer.py":
        raise ReductionSupervisorError("post-run reducer filename differs")
    unit = f"domainlease-f0-c4-post-reducer-{run_id}-{os.getpid()}"
    properties = [
        "User=domainlease-reducer",
        "Group=domainlease-reducer",
        "SupplementaryGroups=",
        "UMask=0077",
        "StandardInput=null",
        "NoNewPrivileges=yes",
        "CapabilityBoundingSet=",
        "AmbientCapabilities=",
        "PrivateNetwork=yes",
        "PrivateTmp=yes",
        "PrivateDevices=yes",
        "ProtectSystem=strict",
        "ProtectHome=yes",
        "ProtectControlGroups=yes",
        "ProtectKernelTunables=yes",
        "ProtectKernelModules=yes",
        "ProtectKernelLogs=yes",
        "ProtectClock=yes",
        "LockPersonality=yes",
        "RestrictSUIDSGID=yes",
        "RestrictRealtime=yes",
        "RestrictNamespaces=yes",
        "RestrictAddressFamilies=AF_UNIX",
        "SystemCallArchitectures=native",
        "SystemCallFilter=@system-service",
        "SystemCallFilter=~@privileged @resources",
        "MemoryMax=4294967296",
        "MemorySwapMax=0",
        "TasksMax=32",
        "RuntimeMaxSec=900s",
        "TimeoutStopSec=30s",
        "KillMode=control-group",
        "OOMPolicy=kill",
        "WorkingDirectory=/",
        f"BindReadOnlyPaths={capture}:/INPUT",
        f"BindReadOnlyPaths={TOOLCHAIN_ROOT}:/usr",
        f"BindsTo={parent_unit}",
        f"After={parent_unit}",
    ]
    command = [
        "/usr/bin/systemd-run",
        "--quiet",
        "--wait",
        "--pipe",
        "--collect",
        "--unit",
        unit,
        "--service-type",
        "exec",
    ]
    for prop in properties:
        command.extend(("--property", prop))
    command.extend(
        (
            "--",
            "/usr/bin/python3",
            "-I",
            "-S",
            "-B",
            str(reducer),
            "--run-id",
            run_id,
        )
    )
    return command, {"unit": unit, "properties": properties}


RESULT_KEYS = {
    "schema_version",
    "artifact_id",
    "run_id",
    "reduction_status",
    "failure_class",
    "contract_sha256",
    "raw_commit_sha256",
    "raw_manifest_sha256",
    "component_result_sha256",
    "predicates",
    "claims",
    "maximum_local_disposition",
    "candidate_summary_is_an_oracle",
    "reducer_uses_only_finalized_capture",
    "strict_result_json_parsed_after_capture",
    "positive_eligible",
    "authorization",
    "runtime_identity",
}


def validate_reducer_result(raw: bytes, run_id: str) -> tuple[dict[str, Any], bytes]:
    marker = b"REDUCTION_JSON="
    lines = raw.splitlines()
    if len(lines) != 1 or not lines[0].startswith(marker):
        raise ReductionSupervisorError("reducer output framing differs")
    payload = lines[0][len(marker) :]
    result = strict_json(payload, "reducer result")
    if not isinstance(result, dict) or set(result) != RESULT_KEYS:
        raise ReductionSupervisorError("reducer result fields differ")
    canonical = canonical_bytes(result)
    if canonical.rstrip(b"\n") != payload:
        raise ReductionSupervisorError("reducer result is not canonical")
    if (
        result["schema_version"] != 1
        or result["artifact_id"] != "f0-c4-post-run-reduction-v1"
        or result["run_id"] != run_id
        or result["contract_sha256"] != CONTRACT_SHA256
        or result["reduction_status"]
        not in {"REDUCTION_PASS", "REDUCTION_REJECT", "REDUCTION_INCOMPLETE"}
        or result["candidate_summary_is_an_oracle"] is not False
        or result["reducer_uses_only_finalized_capture"] is not True
        or type(result["strict_result_json_parsed_after_capture"]) is not bool
        or type(result["positive_eligible"]) is not bool
    ):
        raise ReductionSupervisorError("reducer result fixed boundary differs")
    passed = result["reduction_status"] == "REDUCTION_PASS"
    if result["positive_eligible"] is not passed:
        raise ReductionSupervisorError("reducer positive eligibility differs")
    if passed and (
        result["failure_class"] is not None
        or result["maximum_local_disposition"]
        != "AUTHORITY_DISJOINT_CAPTURED_LOCAL_CANDIDATE_ONLY"
        or set(result["predicates"])
        != {
            "FAST_MUTATION_STATIC",
            "CHILD_EXACT_FIXTURE_BOUNDED",
            "PARENT_EXACT_REPETITION_BOUNDED",
            "DECLARED_LOCAL_EFFECT_COMMUTATION",
        }
        or any(value is not True for value in result["predicates"].values())
        or len(result["claims"]) != 11
    ):
        raise ReductionSupervisorError("positive reducer result differs")
    authorization = result["authorization"]
    if (
        not isinstance(authorization, dict)
        or authorization.get("local_bounded_candidate") is not passed
        or any(
            value is not False
            for key, value in authorization.items()
            if key != "local_bounded_candidate"
        )
    ):
        raise ReductionSupervisorError("reducer authorization differs")
    identity = result["runtime_identity"]
    if (
        not isinstance(identity, dict)
        or identity.get("uid") != REDUCER_UID
        or identity.get("euid") != REDUCER_UID
        or identity.get("gid") != REDUCER_GID
        or identity.get("egid") != REDUCER_GID
        or identity.get("groups") != [REDUCER_GID]
        or identity.get("status", {}).get("NoNewPrivs") != "1"
        or identity.get("status", {}).get("Seccomp") != "2"
        or any(
            identity.get("status", {}).get(key) != "0000000000000000"
            for key in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb")
        )
    ):
        raise ReductionSupervisorError("reducer runtime authority differs")
    descriptors = {
        row.get("fd")
        for row in identity.get("fd_table", [])
        if isinstance(row, dict)
    }
    if descriptors != {0, 1, 2}:
        raise ReductionSupervisorError("reducer inherited descriptor set differs")
    input_mount = identity.get("input_mount", {})
    usr_mount = identity.get("usr_mount", {})
    if (
        "ro" not in str(input_mount.get("mount_options", "")).split(",")
        or usr_mount.get("filesystem_type") != "erofs"
        or "ro" not in str(usr_mount.get("mount_options", "")).split(",")
    ):
        raise ReductionSupervisorError("reducer read-only mounts differ")
    return result, canonical


def publish_reduction(
    run_id: str,
    raw_binding: dict[str, Any],
    storage: dict[str, Any],
    toolchain: dict[str, Any],
    reducer: Path,
    execution_policy: dict[str, Any],
    completed: subprocess.CompletedProcess[bytes],
    parsed_result: dict[str, Any] | None,
    parsed_raw: bytes | None,
    failure: str | None,
) -> dict[str, Any]:
    final_path = REDUCTION_ROOT / run_id
    if final_path.exists():
        raise ReductionSupervisorError(f"reduction already exists: {final_path}")
    staging = REDUCTION_ROOT / f".staging-{run_id}-{os.getpid()}"
    staging.mkdir(mode=0o700)
    bindings: dict[str, str] = {}
    try:
        bindings["reducer.stdout.raw"] = write_new_file(
            staging / "reducer.stdout.raw", completed.stdout
        )
        bindings["reducer.stderr.raw"] = write_new_file(
            staging / "reducer.stderr.raw", completed.stderr
        )
        if parsed_result is not None and parsed_raw is not None:
            bindings["reduction-result.json"] = write_new_file(
                staging / "reduction-result.json", parsed_raw
            )
            reduction_status = parsed_result["reduction_status"]
            failure_class = parsed_result["failure_class"]
            positive = parsed_result["positive_eligible"]
        else:
            reduction_status = "REDUCTION_INCOMPLETE"
            failure_class = failure or "FINALIZATION_FAILED"
            positive = False
        execution_receipt = {
            "schema_version": 1,
            "artifact_id": "f0-c4-reducer-execution-receipt-v1",
            "run_id": run_id,
            "reducer_sha256": sha256_file(reducer),
            "reducer_uid": REDUCER_UID,
            "reducer_gid": REDUCER_GID,
            "systemd": execution_policy,
            "started_monotonic_ns": execution_policy["started_monotonic_ns"],
            "finished_monotonic_ns": time.monotonic_ns(),
            "returncode": completed.returncode,
            "stdout_size": len(completed.stdout),
            "stdout_sha256": sha256_bytes(completed.stdout),
            "stderr_size": len(completed.stderr),
            "stderr_sha256": sha256_bytes(completed.stderr),
            "toolchain_mount": toolchain,
            "candidate_source_reopened": False,
            "external_authorization_changed": False,
        }
        bindings["reducer-execution-receipt.json"] = write_new_file(
            staging / "reducer-execution-receipt.json",
            canonical_bytes(execution_receipt),
        )
        manifest = {
            "schema_version": 1,
            "artifact_id": "f0-c4-reduction-manifest-v1",
            "run_id": run_id,
            "reduction_status": reduction_status,
            "failure_class": failure_class,
            "contract_sha256": CONTRACT_SHA256,
            "raw_capture": raw_binding,
            "reduction_file_sha256": bindings,
            "reduction_storage": storage,
            "positive_eligible": positive,
            "maximum_local_disposition": (
                "AUTHORITY_DISJOINT_CAPTURED_LOCAL_CANDIDATE_ONLY"
                if positive
                else "NO_POSITIVE_LOCAL_DISPOSITION"
            ),
            "capture_mutated": False,
            "candidate_summary_is_an_oracle": False,
            "external_attestation": False,
            "authorization": {
                "F0_local_acceptance": False,
                "external_R11_review": False,
                "G0_authorized": False,
                "self_authorization": False,
                "linux_behavior_change": False,
                "monitor_implementation": False,
                "protection_claim": False,
                "performance_or_cost_claim": False,
                "deployment_claim": False,
            },
        }
        manifest_raw = canonical_bytes(manifest)
        manifest_sha = write_new_file(staging / "reduction-manifest.json", manifest_raw)
        fsync_directory(staging)
        rename_noreplace(staging, final_path)
        fsync_directory(REDUCTION_ROOT)
        commit = {
            "schema_version": 1,
            "artifact_id": "f0-c4-reduction-commit-v1",
            "run_id": run_id,
            "reduction_status": reduction_status,
            "contract_sha256": CONTRACT_SHA256,
            "raw_commit_sha256": raw_binding["raw_commit_sha256"],
            "raw_manifest_sha256": raw_binding["raw_manifest_sha256"],
            "reduction_manifest_sha256": manifest_sha,
            "publication": "renameat2_RENAME_NOREPLACE_then_parent_fsync",
            "commit_authority": "REDUCTION_SUPERVISOR",
            "positive_eligible": positive,
            "external_authorization_changed": False,
        }
        commit_sha = write_new_file(
            final_path / "REDUCTION_COMMIT.json", canonical_bytes(commit)
        )
        os.chmod(final_path, 0o555)
        fsync_directory(final_path)
        fsync_directory(REDUCTION_ROOT)
        return {
            "run_id": run_id,
            "reduction_status": reduction_status,
            "failure_class": failure_class,
            "positive_eligible": positive,
            "final_path": str(final_path),
            "manifest_sha256": manifest_sha,
            "commit_sha256": commit_sha,
            "external_authorization_changed": False,
        }
    except BaseException:
        if staging.exists():
            for path in staging.iterdir():
                path.unlink(missing_ok=True)
            staging.rmdir()
        raise


def reduce(args: argparse.Namespace) -> int:
    require_root()
    if RUN_ID_RE.fullmatch(args.run_id) is None:
        raise ReductionSupervisorError("run ID is outside the safe grammar")
    if os.environ.get("F0_C4_REDUCTION_SUPERVISOR") != "systemd-v1":
        raise ReductionSupervisorError("reduction supervisor is not in its pinned systemd unit")
    parent_unit = os.environ.get("F0_C4_REDUCTION_UNIT", "")
    if re.fullmatch(r"domainlease-f0-c4-reduction-[A-Za-z0-9._-]+\.service", parent_unit) is None:
        raise ReductionSupervisorError("reduction parent unit identity differs")
    require_root_regular(Path(__file__), "reduction supervisor", executable=True)
    require_root_regular(args.reducer, "post-run reducer", executable=True)
    require_root_regular(args.contract, "capture contract")
    contract_raw = read_root_file(args.contract, "capture contract")
    contract_value = strict_json(contract_raw, "capture contract")
    if sha256_bytes(canonical_bytes(contract_value)) != CONTRACT_SHA256:
        raise ReductionSupervisorError("installed capture contract digest differs")
    storage = ensure_reduction_root()
    require_directory(EVIDENCE_ROOT, "evidence root", 0o700)
    raw_binding = validate_raw_commit(args.run_id)
    toolchain = validate_toolchain()
    reducer_identity = validate_reducer_identity_policy()
    if (REDUCTION_ROOT / args.run_id).exists():
        raise ReductionSupervisorError("a reduction already exists for this run")
    command, execution_policy = reducer_command(
        args.run_id,
        args.reducer,
        Path(raw_binding["capture_path"]),
        parent_unit,
    )
    execution_policy["reducer_identity_policy"] = reducer_identity
    execution_policy["started_monotonic_ns"] = time.monotonic_ns()
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            stdin=subprocess.DEVNULL,
            timeout=930,
            env={"PATH": "/usr/bin:/bin", "LANG": "C"},
        )
    except subprocess.TimeoutExpired as exc:
        completed = subprocess.CompletedProcess(
            command,
            124,
            stdout=exc.stdout or b"",
            stderr=exc.stderr or b"",
        )
    parsed_result: dict[str, Any] | None = None
    parsed_raw: bytes | None = None
    failure: str | None = None
    if len(completed.stdout) > MAX_REDUCER_OUTPUT or len(completed.stderr) > MAX_REDUCER_STDERR:
        failure = "OUTPUT_LIMIT_EXCEEDED"
    elif completed.returncode != 0 or completed.stderr:
        failure = "FINALIZATION_FAILED"
    else:
        try:
            parsed_result, parsed_raw = validate_reducer_result(completed.stdout, args.run_id)
        except ReductionSupervisorError:
            failure = "FINALIZATION_FAILED"
    summary = publish_reduction(
        args.run_id,
        raw_binding,
        storage,
        toolchain,
        args.reducer,
        execution_policy,
        completed,
        parsed_result,
        parsed_raw,
        failure,
    )
    print(f"REDUCTION_SUPERVISOR_JSON={json.dumps(summary, sort_keys=True, separators=(',', ':'))}")
    return 0 if summary["reduction_status"] == "REDUCTION_PASS" else 1


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--run-id", required=True)
    value.add_argument(
        "--reducer",
        type=Path,
        default=Path("/usr/local/libexec/domainlease-f0-c4/f0-c4-post-run-reducer.py"),
    )
    value.add_argument(
        "--contract",
        type=Path,
        default=Path("/usr/local/share/domainlease-f0-c4/f0-c4-capture-contract-v1.json"),
    )
    return value


def main() -> int:
    try:
        return reduce(parser().parse_args())
    except ReductionSupervisorError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
