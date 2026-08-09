#!/usr/bin/env python3
"""Capture and verify DomainLease-Linux Evidence Capsule v1 objects."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
DEFAULT_MAX_REQUEST_BYTES = 8 * 1024 * 1024
DEFAULT_MAX_OBJECTS = 4096
DEFAULT_MAX_OBJECT_BYTES = 4 * 1024 * 1024 * 1024
DEFAULT_MAX_TOTAL_BYTES = 16 * 1024 * 1024 * 1024
MAX_MANIFEST_BYTES = 64 * 1024 * 1024
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
GIT_OBJECT_RE = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
GIT_OBJECT_LENGTH = {"sha1": 40, "sha256": 64}
TOKEN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]*$")
COMPONENT_RE = re.compile(r"^[A-Za-z0-9._+-]+$")
CAPTURE_PREFIXES = ("inputs", "raw")
AUTOMATIC_PATHS = {
    "inputs/capture-request.json",
    "inputs/collector/evidence_capsule_v1.py",
}
REQUEST_KEYS = {
    "schema_version",
    "capsule_kind",
    "producer_identity",
    "experiment_contract",
    "target_claims",
    "source_identity",
    "declared_environment",
    "completeness_rule",
    "objects",
}
OBJECT_KEYS = {
    "source_path",
    "capsule_path",
    "role",
    "media_type",
    "required",
}
CAPSULE_KINDS = {
    "formal_validation",
    "linux_build",
    "qemu_kunit",
    "fault_matrix",
    "performance",
    "source_drift",
    "generic",
}


class CapsuleError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise CapsuleError(message)


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        allow_nan=False,
    ).encode("ascii")


def pretty_json(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            sort_keys=True,
            indent=2,
            ensure_ascii=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("ascii")


def strict_json_loads(value: bytes) -> Any:
    def reject_constant(constant: str) -> None:
        fail(f"non-finite JSON number is forbidden: {constant}")

    def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, item in pairs:
            if key in result:
                fail(f"duplicate JSON object key is forbidden: {key}")
            result[key] = item
        return result

    return json.loads(
        value,
        parse_constant=reject_constant,
        object_pairs_hook=reject_duplicate_keys,
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def require_exact_keys(value: dict[str, Any], allowed: set[str], context: str) -> None:
    unknown = sorted(set(value) - allowed)
    if unknown:
        fail(f"{context}: unknown keys: {', '.join(unknown)}")


def require_token(value: Any, context: str) -> str:
    if not isinstance(value, str) or not TOKEN_RE.fullmatch(value):
        fail(f"{context}: expected a non-empty safe token")
    return value


def require_positive_integer(value: Any, context: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        fail(f"{context}: expected a positive integer")
    return value


def require_git_object(value: Any, object_format: str, context: str) -> str:
    expected_length = GIT_OBJECT_LENGTH[object_format]
    if (
        not isinstance(value, str)
        or not GIT_OBJECT_RE.fullmatch(value)
        or len(value) != expected_length
    ):
        fail(f"{context}: expected a full lowercase {object_format} Git object id")
    return value


def argparse_positive_integer(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("expected a positive integer") from error
    if parsed <= 0:
        raise argparse.ArgumentTypeError("expected a positive integer")
    return parsed


def split_safe_relative_path(value: Any, context: str) -> list[str]:
    if not isinstance(value, str) or not value or value.startswith("/"):
        fail(f"{context}: expected a non-empty relative path")
    if "\\" in value or "//" in value:
        fail(f"{context}: backslash and empty path components are forbidden")
    parts = value.split("/")
    for part in parts:
        if part in {"", ".", ".."} or not COMPONENT_RE.fullmatch(part):
            fail(f"{context}: unsafe path component {part!r}")
    return parts


def validate_request(request: Any) -> dict[str, Any]:
    if not isinstance(request, dict):
        fail("capture request must be a JSON object")
    require_exact_keys(request, REQUEST_KEYS, "capture request")
    if request.get("schema_version") != SCHEMA_VERSION:
        fail("capture request schema_version must be 1")
    if request.get("capsule_kind") not in CAPSULE_KINDS:
        fail("capture request has unsupported capsule_kind")
    require_token(request.get("producer_identity"), "producer_identity")

    claims = request.get("target_claims")
    if not isinstance(claims, list) or not claims:
        fail("target_claims must be a non-empty array")
    for index, claim in enumerate(claims):
        require_token(claim, f"target_claims[{index}]")
    if len(claims) != len(set(claims)):
        fail("target_claims contains duplicates")

    contract = request.get("experiment_contract")
    if not isinstance(contract, dict):
        fail("experiment_contract must be an object")
    require_exact_keys(contract, {"id", "object_path", "sha256"}, "experiment_contract")
    require_token(contract.get("id"), "experiment_contract.id")
    split_safe_relative_path(
        contract.get("object_path"), "experiment_contract.object_path"
    )
    if not isinstance(contract.get("sha256"), str) or not HASH_RE.fullmatch(
        contract["sha256"]
    ):
        fail("experiment_contract.sha256 must be lowercase SHA-256")

    source_identity = request.get("source_identity")
    if not isinstance(source_identity, dict):
        fail("source_identity must be an object")
    kind = source_identity.get("kind")
    if kind == "git":
        require_exact_keys(
            source_identity,
            {
                "kind",
                "repository",
                "object_format",
                "commit",
                "tree",
                "parents",
                "dirty",
            },
            "source_identity",
        )
        require_token(source_identity.get("repository"), "source_identity.repository")
        object_format = source_identity.get("object_format")
        if object_format not in GIT_OBJECT_LENGTH:
            fail("source_identity.object_format must be sha1 or sha256")
        require_git_object(
            source_identity.get("commit"),
            object_format,
            "source_identity.commit",
        )
        require_git_object(
            source_identity.get("tree"),
            object_format,
            "source_identity.tree",
        )
        parents = source_identity.get("parents")
        if not isinstance(parents, list):
            fail("source_identity.parents must be an array")
        for index, parent in enumerate(parents):
            require_git_object(
                parent,
                object_format,
                f"source_identity.parents[{index}]",
            )
        if len(parents) != len(set(parents)):
            fail("source_identity.parents contains duplicates")
        if not isinstance(source_identity.get("dirty"), bool):
            fail("source_identity.dirty must be boolean")
    elif kind == "fixture":
        require_exact_keys(source_identity, {"kind", "id"}, "source_identity")
        require_token(source_identity.get("id"), "source_identity.id")
    else:
        fail("source_identity.kind must be git or fixture")

    environment = request.get("declared_environment")
    if not isinstance(environment, dict):
        fail("declared_environment must be an object")

    completeness = request.get("completeness_rule")
    if not isinstance(completeness, dict):
        fail("completeness_rule must be an object")
    require_exact_keys(
        completeness,
        {"allow_extra_files", "required_capsule_paths"},
        "completeness_rule",
    )
    if completeness.get("allow_extra_files") is not False:
        fail("Evidence Capsule v1 requires allow_extra_files=false")
    required_paths = completeness.get("required_capsule_paths")
    if not isinstance(required_paths, list):
        fail("required_capsule_paths must be an array")
    for index, path in enumerate(required_paths):
        split_safe_relative_path(path, f"required_capsule_paths[{index}]")
    if len(required_paths) != len(set(required_paths)):
        fail("required_capsule_paths contains duplicates")

    objects = request.get("objects")
    if not isinstance(objects, list) or not objects:
        fail("objects must be a non-empty array")
    source_paths: set[str] = set()
    capsule_paths: set[str] = set()
    required_from_objects: list[str] = []
    contract_matches = 0
    for index, row in enumerate(objects):
        context = f"objects[{index}]"
        if not isinstance(row, dict):
            fail(f"{context}: expected object")
        require_exact_keys(row, OBJECT_KEYS, context)
        source_parts = split_safe_relative_path(
            row.get("source_path"), f"{context}.source_path"
        )
        capsule_parts = split_safe_relative_path(
            row.get("capsule_path"), f"{context}.capsule_path"
        )
        source_path = "/".join(source_parts)
        capsule_path = "/".join(capsule_parts)
        if capsule_parts[0] not in CAPTURE_PREFIXES:
            fail(f"{context}.capsule_path must begin with inputs/ or raw/")
        if capsule_path in AUTOMATIC_PATHS:
            fail(f"{context}.capsule_path collides with an automatic object")
        if source_path in source_paths:
            fail(f"{context}.source_path duplicates another object")
        if capsule_path in capsule_paths:
            fail(f"{context}.capsule_path duplicates another object")
        source_paths.add(source_path)
        capsule_paths.add(capsule_path)
        require_token(row.get("role"), f"{context}.role")
        if not isinstance(row.get("media_type"), str) or not row["media_type"]:
            fail(f"{context}.media_type must be non-empty")
        if not isinstance(row.get("required"), bool):
            fail(f"{context}.required must be boolean")
        if row["required"]:
            required_from_objects.append(capsule_path)
        if capsule_path == contract["object_path"]:
            contract_matches += 1
            if row["role"] != "experiment_contract" or not row["required"]:
                fail(
                    "experiment contract object must be required with role "
                    "experiment_contract"
                )

    if sorted(required_paths) != sorted(required_from_objects):
        fail("required_capsule_paths must exactly match required object paths")
    if contract_matches != 1:
        fail("experiment_contract.object_path must identify exactly one object")
    return request


def open_directory_nofollow(path: str) -> int:
    absolute = os.path.abspath(path)
    parts = Path(absolute).parts
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    fd = os.open("/", flags)
    try:
        for part in parts[1:]:
            next_fd = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except Exception:
        os.close(fd)
        raise


def open_regular_path_nofollow(path: str) -> int:
    absolute = os.path.abspath(path)
    parent = os.path.dirname(absolute)
    name = os.path.basename(absolute)
    if not name:
        fail(f"regular file path has no final component: {path}")
    parent_fd = open_directory_nofollow(parent)
    try:
        fd = os.open(name, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW, dir_fd=parent_fd)
    finally:
        os.close(parent_fd)
    mode = os.fstat(fd).st_mode
    if not stat.S_ISREG(mode):
        os.close(fd)
        fail(f"not a regular file: {path}")
    return fd


def open_relative_regular(root_fd: int, relative: str) -> int:
    parts = split_safe_relative_path(relative, "source path")
    current = os.dup(root_fd)
    try:
        for part in parts[:-1]:
            next_fd = os.open(
                part,
                os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                dir_fd=current,
            )
            os.close(current)
            current = next_fd
        fd = os.open(
            parts[-1], os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW, dir_fd=current
        )
    finally:
        os.close(current)
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        os.close(fd)
        fail(f"source is not a regular file: {relative}")
    return fd


def open_capsule_directory(path: str) -> int:
    return open_directory_nofollow(path)


def same_directory(left_fd: int, right_fd: int) -> bool:
    left = os.fstat(left_fd)
    right = os.fstat(right_fd)
    return (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)


def directory_is_at_or_below(directory_fd: int, ancestor_fd: int) -> bool:
    current = os.dup(directory_fd)
    try:
        while True:
            if same_directory(current, ancestor_fd):
                return True
            parent = os.open(
                "..",
                os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                dir_fd=current,
            )
            if same_directory(parent, current):
                os.close(parent)
                return False
            os.close(current)
            current = parent
    finally:
        os.close(current)


def create_capsule_directory(path: str, source_root_fd: int) -> int:
    absolute = os.path.abspath(path)
    parent = os.path.dirname(absolute)
    name = os.path.basename(absolute)
    split_safe_relative_path(name, "output directory name")
    parent_fd = open_directory_nofollow(parent)
    try:
        if directory_is_at_or_below(parent_fd, source_root_fd):
            fail("output directory must be outside the producer source root")
        os.mkdir(name, 0o700, dir_fd=parent_fd)
        fd = os.open(
            name,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=parent_fd,
        )
    finally:
        os.close(parent_fd)
    return fd


def ensure_relative_directory(root_fd: int, parts: list[str]) -> int:
    current = os.dup(root_fd)
    try:
        for part in parts:
            try:
                os.mkdir(part, 0o700, dir_fd=current)
            except FileExistsError:
                pass
            next_fd = os.open(
                part,
                os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                dir_fd=current,
            )
            os.close(current)
            current = next_fd
        return current
    except Exception:
        os.close(current)
        raise


def write_all(fd: int, value: bytes) -> None:
    view = memoryview(value)
    while view:
        written = os.write(fd, view)
        if written <= 0:
            fail("short write while creating capsule")
        view = view[written:]


def create_bytes_object(root_fd: int, relative: str, value: bytes) -> tuple[int, str]:
    parts = split_safe_relative_path(relative, "capsule object path")
    parent_fd = ensure_relative_directory(root_fd, parts[:-1])
    try:
        fd = os.open(
            parts[-1],
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
            0o600,
            dir_fd=parent_fd,
        )
        try:
            write_all(fd, value)
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)
    return len(value), sha256_bytes(value)


def source_stat_key(info: os.stat_result) -> tuple[int, int, int, int, int]:
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def capture_fd_object(
    root_fd: int,
    relative: str,
    source_fd: int,
    max_bytes: int,
) -> tuple[int, str]:
    parts = split_safe_relative_path(relative, "capsule object path")
    before = os.fstat(source_fd)
    if before.st_size > max_bytes:
        fail(f"capture size limit exceeded before copy: {relative}")
    parent_fd = ensure_relative_directory(root_fd, parts[:-1])
    digest = hashlib.sha256()
    size = 0
    try:
        destination_fd = os.open(
            parts[-1],
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
            0o600,
            dir_fd=parent_fd,
        )
        try:
            while True:
                chunk = os.read(source_fd, 1024 * 1024)
                if not chunk:
                    break
                if size + len(chunk) > max_bytes:
                    fail(f"capture size limit exceeded during copy: {relative}")
                digest.update(chunk)
                size += len(chunk)
                write_all(destination_fd, chunk)
            os.fsync(destination_fd)
        finally:
            os.close(destination_fd)
    finally:
        os.close(parent_fd)
    after = os.fstat(source_fd)
    if source_stat_key(before) != source_stat_key(after) or size != before.st_size:
        fail("source changed while it was being captured")
    return size, digest.hexdigest()


def read_all_fd(
    fd: int,
    max_bytes: int | None = None,
    context: str = "file",
) -> bytes:
    chunks: list[bytes] = []
    size = 0
    while True:
        chunk = os.read(fd, 1024 * 1024)
        if not chunk:
            return b"".join(chunks)
        size += len(chunk)
        if max_bytes is not None and size > max_bytes:
            fail(f"{context} exceeds its read limit")
        chunks.append(chunk)


def git_output(source_root_fd: int, *args: str) -> str:
    source_root = f"/proc/self/fd/{source_root_fd}"
    environment = os.environ.copy()
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    completed = subprocess.run(
        [
            "git",
            "-c",
            "core.fsmonitor=false",
            "-c",
            "core.untrackedCache=false",
            "-C",
            source_root,
            *args,
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        pass_fds=(source_root_fd,),
        env=environment,
    )
    return completed.stdout.strip()


def verify_git_identity(source_root_fd: int, identity: dict[str, Any]) -> None:
    if identity["kind"] != "git":
        return
    try:
        commit = git_output(source_root_fd, "rev-parse", "HEAD^{commit}")
        tree = git_output(source_root_fd, "rev-parse", "HEAD^{tree}")
        object_format = git_output(
            source_root_fd, "rev-parse", "--show-object-format"
        )
        parents_output = git_output(
            source_root_fd, "show", "-s", "--format=%P", "HEAD"
        )
        parents = parents_output.split() if parents_output else []
        dirty = bool(
            git_output(
                source_root_fd,
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
            )
        )
    except subprocess.CalledProcessError as error:
        fail(f"cannot verify Git source identity: {error.stderr.strip()}")
    if commit != identity["commit"]:
        fail("source_identity.commit does not match source root HEAD")
    if tree != identity["tree"]:
        fail("source_identity.tree does not match source root HEAD tree")
    if object_format != identity["object_format"]:
        fail("source_identity.object_format does not match source root")
    if parents != identity["parents"]:
        fail("source_identity.parents does not match source root HEAD")
    if dirty != identity["dirty"]:
        fail("source_identity.dirty does not match source root")


def git_blob_snapshot(
    source_root_fd: int,
    commit: str,
    source_path: str,
    object_format: str,
    max_bytes: int,
) -> dict[str, Any]:
    entry = git_output(source_root_fd, "ls-tree", commit, "--", source_path)
    if not entry or "\n" in entry or "\t" not in entry:
        fail(f"clean Git source path is not one exact tree entry: {source_path}")
    metadata, returned_path = entry.split("\t", 1)
    fields = metadata.split()
    if returned_path != source_path or len(fields) != 3:
        fail(f"clean Git source tree entry is malformed: {source_path}")
    mode, object_type, object_id = fields
    if mode not in {"100644", "100755"} or object_type != "blob":
        fail(f"clean Git source is not a regular tracked blob: {source_path}")
    require_git_object(object_id, object_format, f"Git blob for {source_path}")

    source_root = f"/proc/self/fd/{source_root_fd}"
    environment = os.environ.copy()
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    process = subprocess.Popen(
        [
            "git",
            "-c",
            "core.fsmonitor=false",
            "-c",
            "core.untrackedCache=false",
            "-C",
            source_root,
            "cat-file",
            "blob",
            object_id,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        pass_fds=(source_root_fd,),
        env=environment,
    )
    if process.stdout is None or process.stderr is None:
        process.kill()
        fail("cannot open Git blob verification streams")
    digest = hashlib.sha256()
    size = 0
    while True:
        chunk = process.stdout.read(1024 * 1024)
        if not chunk:
            break
        size += len(chunk)
        if size > max_bytes:
            process.kill()
            process.wait()
            fail(f"Git blob exceeds capture limit: {source_path}")
        digest.update(chunk)
    stderr = process.stderr.read()
    returncode = process.wait()
    if returncode != 0:
        fail(
            f"cannot read Git blob for {source_path}: "
            f"{stderr.decode('utf-8', errors='replace').strip()}"
        )
    return {
        "mode": mode,
        "object_id": object_id,
        "size_bytes": size,
        "sha256": digest.hexdigest(),
    }


def automatic_object(
    capsule_path: str,
    role: str,
    media_type: str,
    size: int,
    digest: str,
    source: str,
) -> dict[str, Any]:
    return {
        "capsule_path": capsule_path,
        "role": role,
        "media_type": media_type,
        "required": True,
        "captured": True,
        "size_bytes": size,
        "sha256": digest,
        "producer_path_or_source": source,
        "capture_method": "single_open_fd_copy",
    }


def record_failure(capsule_fd: int, message: str, collector_id: str) -> None:
    receipt = {
        "schema_version": SCHEMA_VERSION,
        "status": "Incomplete",
        "created_at": utc_now(),
        "collector_identity": collector_id,
        "error": message,
    }
    try:
        create_bytes_object(capsule_fd, "capture-failure.json", pretty_json(receipt))
        os.fsync(capsule_fd)
    except Exception:
        pass


def collect(args: argparse.Namespace) -> dict[str, Any]:
    collector_id = require_token(args.collector_id, "collector-id")
    limits = {
        "max_request_bytes": require_positive_integer(
            args.max_request_bytes, "max-request-bytes"
        ),
        "max_objects": require_positive_integer(args.max_objects, "max-objects"),
        "max_object_bytes": require_positive_integer(
            args.max_object_bytes, "max-object-bytes"
        ),
        "max_total_bytes": require_positive_integer(
            args.max_total_bytes, "max-total-bytes"
        ),
    }
    source_root_fd = open_directory_nofollow(args.source_root)
    request_fd = open_regular_path_nofollow(args.request)
    capsule_fd: int | None = None
    try:
        request_info_before = os.fstat(request_fd)
        if request_info_before.st_size > limits["max_request_bytes"]:
            fail("capture request exceeds max-request-bytes")
        request_bytes = read_all_fd(
            request_fd,
            limits["max_request_bytes"],
            "capture request",
        )
        request_info_after = os.fstat(request_fd)
        if source_stat_key(request_info_before) != source_stat_key(request_info_after):
            fail("capture request changed while being read")
        try:
            request = validate_request(strict_json_loads(request_bytes))
        except json.JSONDecodeError as error:
            fail(f"capture request is invalid JSON: {error}")
        if len(request["objects"]) > limits["max_objects"]:
            fail("capture request exceeds max-objects")
        if len(request_bytes) > limits["max_total_bytes"]:
            fail("capture request exceeds max-total-bytes")
        verify_git_identity(source_root_fd, request["source_identity"])

        capsule_fd = create_capsule_directory(args.output, source_root_fd)
        object_rows: list[dict[str, Any]] = []
        source_inodes: dict[tuple[int, int], str] = {}
        captured_total = len(request_bytes)

        request_size, request_digest = create_bytes_object(
            capsule_fd, "inputs/capture-request.json", request_bytes
        )
        object_rows.append(
            automatic_object(
                "inputs/capture-request.json",
                "capture_request",
                "application/json",
                request_size,
                request_digest,
                "collector_request_argument",
            )
        )

        collector_fd = open_regular_path_nofollow(__file__)
        try:
            collector_size, collector_digest = capture_fd_object(
                capsule_fd,
                "inputs/collector/evidence_capsule_v1.py",
                collector_fd,
                limits["max_total_bytes"] - captured_total,
            )
        finally:
            os.close(collector_fd)
        captured_total += collector_size
        object_rows.append(
            automatic_object(
                "inputs/collector/evidence_capsule_v1.py",
                "collector_implementation",
                "text/x-python",
                collector_size,
                collector_digest,
                "collector_executable",
            )
        )

        for row in request["objects"]:
            source_fd: int | None = None
            try:
                source_fd = open_relative_regular(source_root_fd, row["source_path"])
            except FileNotFoundError:
                if row["required"]:
                    fail(f"required source object is missing: {row['source_path']}")
                object_rows.append(
                    {
                        "capsule_path": row["capsule_path"],
                        "role": row["role"],
                        "media_type": row["media_type"],
                        "required": False,
                        "captured": False,
                        "producer_path_or_source": row["source_path"],
                        "capture_method": "missing_optional",
                    }
                )
                continue
            try:
                source_info = os.fstat(source_fd)
                source_inode = (source_info.st_dev, source_info.st_ino)
                if source_inode in source_inodes:
                    fail(
                        f"source object aliases {source_inodes[source_inode]}: "
                        f"{row['source_path']}"
                    )
                source_inodes[source_inode] = row["source_path"]
                size, digest = capture_fd_object(
                    capsule_fd,
                    row["capsule_path"],
                    source_fd,
                    min(
                        limits["max_object_bytes"],
                        limits["max_total_bytes"] - captured_total,
                    ),
                )
            finally:
                if source_fd is not None:
                    os.close(source_fd)
            captured_total += size
            captured_row = {
                "capsule_path": row["capsule_path"],
                "role": row["role"],
                "media_type": row["media_type"],
                "required": row["required"],
                "captured": True,
                "size_bytes": size,
                "sha256": digest,
                "producer_path_or_source": row["source_path"],
                "capture_method": "single_open_fd_copy",
            }
            source_identity = request["source_identity"]
            if source_identity["kind"] == "git" and not source_identity["dirty"]:
                source_git = git_blob_snapshot(
                    source_root_fd,
                    source_identity["commit"],
                    row["source_path"],
                    source_identity["object_format"],
                    limits["max_object_bytes"],
                )
                if (
                    source_git["size_bytes"] != size
                    or source_git["sha256"] != digest
                ):
                    fail(
                        f"captured bytes do not match clean Git blob: "
                        f"{row['source_path']}"
                    )
                captured_row["source_git"] = source_git
            object_rows.append(captured_row)

        contract_path = request["experiment_contract"]["object_path"]
        contract_rows = [
            row for row in object_rows if row["capsule_path"] == contract_path
        ]
        if len(contract_rows) != 1 or not contract_rows[0]["captured"]:
            fail("experiment contract was not captured")
        if contract_rows[0]["sha256"] != request["experiment_contract"]["sha256"]:
            fail("captured experiment contract digest does not match request")

        # Recheck through the same directory descriptor so a clean Git identity
        # cannot become stale while mutable producer objects are captured.
        verify_git_identity(source_root_fd, request["source_identity"])

        object_rows.sort(key=lambda row: row["capsule_path"])
        expected_files = sorted(
            ["core-manifest.json"]
            + [row["capsule_path"] for row in object_rows if row["captured"]]
        )
        core = {
            "schema_version": SCHEMA_VERSION,
            "capsule_kind": request["capsule_kind"],
            "created_at": utc_now(),
            "collector_identity": collector_id,
            "collector_implementation_sha256": collector_digest,
            "producer_identity": request["producer_identity"],
            "capture_source_root_id": require_token(
                args.source_root_id, "source-root-id"
            ),
            "capture_limits": limits,
            "target_claims": request["target_claims"],
            "experiment_contract": request["experiment_contract"],
            "source_identity": request["source_identity"],
            "declared_environment": request["declared_environment"],
            "completeness_rule": {
                "allow_extra_files": False,
                "expected_files": expected_files,
            },
            "objects": object_rows,
        }
        capsule_id = sha256_bytes(canonical_json(core))
        manifest = {
            "schema_version": SCHEMA_VERSION,
            "hash_algorithm": "sha256",
            "capsule_id": capsule_id,
            "core": core,
        }
        create_bytes_object(capsule_fd, "core-manifest.json", pretty_json(manifest))
        os.fsync(capsule_fd)
        return {
            "status": "Captured",
            "capsule_id": capsule_id,
            "output": os.path.abspath(args.output),
            "captured_object_count": sum(1 for row in object_rows if row["captured"]),
            "missing_optional_count": sum(
                1 for row in object_rows if not row["captured"]
            ),
        }
    except Exception as error:
        if capsule_fd is not None:
            record_failure(capsule_fd, str(error), collector_id)
        raise
    finally:
        if capsule_fd is not None:
            os.close(capsule_fd)
        os.close(request_fd)
        os.close(source_root_fd)


def read_relative_regular(
    root_fd: int,
    relative: str,
    max_bytes: int | None = None,
) -> bytes:
    fd = open_relative_regular(root_fd, relative)
    try:
        before = os.fstat(fd)
        if max_bytes is not None and before.st_size > max_bytes:
            fail(f"capsule object exceeds its read limit: {relative}")
        value = read_all_fd(fd, max_bytes, f"capsule object {relative}")
        after = os.fstat(fd)
    finally:
        os.close(fd)
    if (
        source_stat_key(before) != source_stat_key(after)
        or len(value) != before.st_size
    ):
        fail(f"capsule object changed while verifying: {relative}")
    return value


def list_capsule_files(root_fd: int) -> list[str]:
    found: list[str] = []

    def walk(directory_fd: int, prefix: str) -> None:
        for name in sorted(os.listdir(directory_fd)):
            split_safe_relative_path(name, "capsule directory entry")
            relative = f"{prefix}/{name}" if prefix else name
            info = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
            if stat.S_ISREG(info.st_mode):
                found.append(relative)
                continue
            if not stat.S_ISDIR(info.st_mode):
                fail(f"capsule contains a non-regular object: {relative}")
            child_fd = os.open(
                name,
                os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                dir_fd=directory_fd,
            )
            try:
                walk(child_fd, relative)
            finally:
                os.close(child_fd)

    walk(root_fd, "")
    return sorted(found)


def validate_manifest_shape(manifest: Any) -> dict[str, Any]:
    if not isinstance(manifest, dict):
        fail("core manifest must be an object")
    require_exact_keys(
        manifest,
        {"schema_version", "hash_algorithm", "capsule_id", "core"},
        "core manifest",
    )
    if manifest.get("schema_version") != SCHEMA_VERSION:
        fail("core manifest schema_version must be 1")
    if manifest.get("hash_algorithm") != "sha256":
        fail("core manifest hash_algorithm must be sha256")
    if not isinstance(manifest.get("capsule_id"), str) or not HASH_RE.fullmatch(
        manifest["capsule_id"]
    ):
        fail("core manifest capsule_id must be lowercase SHA-256")
    core = manifest.get("core")
    if not isinstance(core, dict):
        fail("core manifest core must be an object")
    required_core = {
        "schema_version",
        "capsule_kind",
        "created_at",
        "collector_identity",
        "collector_implementation_sha256",
        "producer_identity",
        "capture_source_root_id",
        "capture_limits",
        "target_claims",
        "experiment_contract",
        "source_identity",
        "declared_environment",
        "completeness_rule",
        "objects",
    }
    require_exact_keys(core, required_core, "core manifest core")
    if set(core) != required_core:
        missing = sorted(required_core - set(core))
        fail(f"core manifest missing keys: {', '.join(missing)}")
    if core["schema_version"] != SCHEMA_VERSION:
        fail("core schema_version must be 1")
    if core.get("capsule_kind") not in CAPSULE_KINDS:
        fail("core capsule_kind is unsupported")
    require_token(core.get("collector_identity"), "core collector_identity")
    require_token(core.get("producer_identity"), "core producer_identity")
    require_token(
        core.get("capture_source_root_id"), "core capture_source_root_id"
    )
    capture_limits = core.get("capture_limits")
    if not isinstance(capture_limits, dict):
        fail("core capture_limits must be an object")
    limit_keys = {
        "max_request_bytes",
        "max_objects",
        "max_object_bytes",
        "max_total_bytes",
    }
    require_exact_keys(capture_limits, limit_keys, "core capture_limits")
    if set(capture_limits) != limit_keys:
        missing = sorted(limit_keys - set(capture_limits))
        fail(f"core capture_limits missing keys: {', '.join(missing)}")
    for key, value in capture_limits.items():
        require_positive_integer(value, f"core capture_limits.{key}")
    if (
        not isinstance(core.get("collector_implementation_sha256"), str)
        or not HASH_RE.fullmatch(core["collector_implementation_sha256"])
    ):
        fail("core collector implementation digest must be lowercase SHA-256")
    claims = core.get("target_claims")
    if not isinstance(claims, list) or not claims:
        fail("core target_claims must be a non-empty array")
    for index, claim in enumerate(claims):
        require_token(claim, f"core target_claims[{index}]")
    if len(claims) != len(set(claims)):
        fail("core target_claims contains duplicates")
    return manifest


def verify(args: argparse.Namespace) -> dict[str, Any]:
    root_fd = open_capsule_directory(args.capsule)
    try:
        try:
            manifest_bytes = read_relative_regular(
                root_fd,
                "core-manifest.json",
                MAX_MANIFEST_BYTES,
            )
        except FileNotFoundError:
            fail("capsule has no core-manifest.json")
        try:
            manifest = validate_manifest_shape(strict_json_loads(manifest_bytes))
        except json.JSONDecodeError as error:
            fail(f"core manifest is invalid JSON: {error}")
        core = manifest["core"]
        expected_id = sha256_bytes(canonical_json(core))
        if expected_id != manifest["capsule_id"]:
            fail("capsule_id does not match canonical core manifest")

        objects = core["objects"]
        if not isinstance(objects, list) or not objects:
            fail("core manifest objects must be non-empty")
        capture_limits = core["capture_limits"]
        if len(objects) > capture_limits["max_objects"] + len(AUTOMATIC_PATHS):
            fail("core manifest exceeds its captured object-count limit")
        paths: set[str] = set()
        rows_by_path: dict[str, dict[str, Any]] = {}
        captured_count = 0
        captured_total = 0
        missing_optional_count = 0
        captured_request_bytes: bytes | None = None
        for index, row in enumerate(objects):
            if not isinstance(row, dict):
                fail(f"core objects[{index}] must be an object")
            captured = row.get("captured")
            object_keys = {
                "capsule_path",
                "role",
                "media_type",
                "required",
                "captured",
                "producer_path_or_source",
                "capture_method",
            }
            if captured is True:
                object_keys.update({"size_bytes", "sha256"})
            if "source_git" in row:
                object_keys.add("source_git")
            require_exact_keys(row, object_keys, f"core objects[{index}]")
            if set(row) != object_keys:
                missing = sorted(object_keys - set(row))
                fail(
                    f"core objects[{index}] missing keys: {', '.join(missing)}"
                )
            path = row.get("capsule_path")
            path_parts = split_safe_relative_path(
                path, f"core objects[{index}].capsule_path"
            )
            if path_parts[0] not in CAPTURE_PREFIXES:
                fail(
                    f"core objects[{index}].capsule_path must begin with "
                    "inputs/ or raw/"
                )
            if path in paths:
                fail(f"duplicate core object path: {path}")
            paths.add(path)
            rows_by_path[path] = row
            require_token(row.get("role"), f"core objects[{index}].role")
            if not isinstance(row.get("media_type"), str) or not row["media_type"]:
                fail(f"core objects[{index}].media_type must be non-empty")
            if (
                not isinstance(row.get("producer_path_or_source"), str)
                or not row["producer_path_or_source"]
            ):
                fail(
                    f"core objects[{index}].producer_path_or_source must be non-empty"
                )
            required = row.get("required")
            if not isinstance(required, bool) or not isinstance(captured, bool):
                fail(f"core objects[{index}] required/captured must be boolean")
            if required and not captured:
                fail(f"required core object is not captured: {path}")
            if not captured:
                if row.get("capture_method") != "missing_optional":
                    fail(f"uncaptured object has invalid capture method: {path}")
                missing_optional_count += 1
                try:
                    open_fd = open_relative_regular(root_fd, path)
                except FileNotFoundError:
                    continue
                else:
                    os.close(open_fd)
                    fail(f"uncaptured optional object unexpectedly exists: {path}")
            if row.get("capture_method") != "single_open_fd_copy":
                fail(f"captured object has invalid capture method: {path}")
            declared_size = row.get("size_bytes")
            if (
                not isinstance(declared_size, int)
                or isinstance(declared_size, bool)
                or declared_size < 0
            ):
                fail(f"captured object has invalid size: {path}")
            declared_digest = row.get("sha256")
            if (
                not isinstance(declared_digest, str)
                or not HASH_RE.fullmatch(declared_digest)
            ):
                fail(f"captured object has invalid digest: {path}")
            if path == "inputs/capture-request.json":
                object_limit = capture_limits["max_request_bytes"]
            elif path in AUTOMATIC_PATHS:
                object_limit = capture_limits["max_total_bytes"]
            else:
                object_limit = capture_limits["max_object_bytes"]
            if declared_size > object_limit:
                fail(f"captured object exceeds its declared capture limit: {path}")
            if captured_total + declared_size > capture_limits["max_total_bytes"]:
                fail("captured objects exceed the declared total-byte limit")
            value = read_relative_regular(root_fd, path, object_limit)
            captured_count += 1
            captured_total += len(value)
            if declared_size != len(value):
                fail(f"size mismatch for capsule object: {path}")
            digest = sha256_bytes(value)
            if declared_digest != digest:
                fail(f"digest mismatch for capsule object: {path}")
            source_git = row.get("source_git")
            if source_git is not None:
                if not isinstance(source_git, dict):
                    fail(f"source_git must be an object: {path}")
                source_git_keys = {"mode", "object_id", "size_bytes", "sha256"}
                require_exact_keys(
                    source_git,
                    source_git_keys,
                    f"source_git for {path}",
                )
                if set(source_git) != source_git_keys:
                    missing = sorted(source_git_keys - set(source_git))
                    fail(f"source_git for {path} missing keys: {', '.join(missing)}")
                if source_git.get("mode") not in {"100644", "100755"}:
                    fail(f"source_git mode is invalid: {path}")
                if source_git.get("size_bytes") != declared_size:
                    fail(f"source_git size does not match captured object: {path}")
                if source_git.get("sha256") != declared_digest:
                    fail(f"source_git digest does not match captured object: {path}")
            if path == "inputs/capture-request.json":
                captured_request_bytes = value

        if captured_request_bytes is None:
            fail("capsule has no captured request object")
        try:
            request = validate_request(strict_json_loads(captured_request_bytes))
        except json.JSONDecodeError as error:
            fail(f"captured request is invalid JSON: {error}")

        request_bindings = {
            "capsule_kind": request["capsule_kind"],
            "producer_identity": request["producer_identity"],
            "target_claims": request["target_claims"],
            "experiment_contract": request["experiment_contract"],
            "source_identity": request["source_identity"],
            "declared_environment": request["declared_environment"],
        }
        for key, value in request_bindings.items():
            if core.get(key) != value:
                fail(f"core {key} does not match the captured request")

        automatic_rows = {
            "inputs/capture-request.json": {
                "role": "capture_request",
                "media_type": "application/json",
                "required": True,
                "captured": True,
                "producer_path_or_source": "collector_request_argument",
                "capture_method": "single_open_fd_copy",
            },
            "inputs/collector/evidence_capsule_v1.py": {
                "role": "collector_implementation",
                "media_type": "text/x-python",
                "required": True,
                "captured": True,
                "producer_path_or_source": "collector_executable",
                "capture_method": "single_open_fd_copy",
            },
        }
        request_rows = {row["capsule_path"]: row for row in request["objects"]}
        expected_object_paths = set(automatic_rows) | set(request_rows)
        if set(rows_by_path) != expected_object_paths:
            missing = sorted(expected_object_paths - set(rows_by_path))
            extra = sorted(set(rows_by_path) - expected_object_paths)
            fail(
                f"core object set does not match request; "
                f"missing={missing}, extra={extra}"
            )

        for path, expected in automatic_rows.items():
            row = rows_by_path[path]
            for key, value in expected.items():
                if row.get(key) != value:
                    fail(f"automatic object metadata mismatch for {path}: {key}")

        collector_row = rows_by_path["inputs/collector/evidence_capsule_v1.py"]
        if (
            core.get("collector_implementation_sha256")
            != collector_row.get("sha256")
        ):
            fail("collector implementation digest does not match its captured object")

        for path, requested in request_rows.items():
            row = rows_by_path[path]
            expected = {
                "role": requested["role"],
                "media_type": requested["media_type"],
                "required": requested["required"],
                "producer_path_or_source": requested["source_path"],
            }
            for key, value in expected.items():
                if row.get(key) != value:
                    fail(f"captured request metadata mismatch for {path}: {key}")
            clean_git = (
                request["source_identity"]["kind"] == "git"
                and not request["source_identity"]["dirty"]
            )
            if row["captured"] and clean_git:
                source_git = row.get("source_git")
                if not isinstance(source_git, dict):
                    fail(f"clean Git object lacks source_git binding: {path}")
                require_git_object(
                    source_git.get("object_id"),
                    request["source_identity"]["object_format"],
                    f"source_git.object_id for {path}",
                )
            elif "source_git" in row:
                fail(f"non-clean-Git object has unexpected source_git binding: {path}")

        contract = core.get("experiment_contract")
        if not isinstance(contract, dict):
            fail("core experiment_contract must be an object")
        contract_path = contract.get("object_path")
        contract_rows = [
            row for row in objects if row.get("capsule_path") == contract_path
        ]
        if len(contract_rows) != 1 or not contract_rows[0].get("captured"):
            fail("core experiment contract does not name one captured object")
        if contract_rows[0].get("sha256") != contract.get("sha256"):
            fail("core experiment contract digest mismatch")

        completeness = core.get("completeness_rule")
        if (
            not isinstance(completeness, dict)
            or completeness.get("allow_extra_files") is not False
        ):
            fail("core completeness rule must fail closed on extra files")
        expected_files = completeness.get("expected_files")
        if not isinstance(expected_files, list) or len(expected_files) != len(
            set(expected_files)
        ):
            fail("core expected_files must be a unique array")
        for index, path in enumerate(expected_files):
            split_safe_relative_path(path, f"expected_files[{index}]")
        derived_expected_files = sorted(
            ["core-manifest.json"]
            + [row["capsule_path"] for row in objects if row["captured"]]
        )
        if expected_files != derived_expected_files:
            fail("core expected_files is not the exact captured object set")
        actual_files = list_capsule_files(root_fd)
        if sorted(expected_files) != actual_files:
            missing = sorted(set(expected_files) - set(actual_files))
            extra = sorted(set(actual_files) - set(expected_files))
            fail(f"capsule file set mismatch; missing={missing}, extra={extra}")

        return {
            "status": "Valid",
            "capsule_id": manifest["capsule_id"],
            "captured_object_count": captured_count,
            "missing_optional_count": missing_optional_count,
            "file_count": len(actual_files),
        }
    finally:
        os.close(root_fd)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    subparsers = root.add_subparsers(dest="command", required=True)

    collect_parser = subparsers.add_parser("collect", help="capture and seal a capsule")
    collect_parser.add_argument("--request", required=True)
    collect_parser.add_argument("--source-root", required=True)
    collect_parser.add_argument("--source-root-id", required=True)
    collect_parser.add_argument("--output", required=True)
    collect_parser.add_argument("--collector-id", required=True)
    collect_parser.add_argument(
        "--max-request-bytes",
        type=argparse_positive_integer,
        default=DEFAULT_MAX_REQUEST_BYTES,
    )
    collect_parser.add_argument(
        "--max-objects",
        type=argparse_positive_integer,
        default=DEFAULT_MAX_OBJECTS,
    )
    collect_parser.add_argument(
        "--max-object-bytes",
        type=argparse_positive_integer,
        default=DEFAULT_MAX_OBJECT_BYTES,
    )
    collect_parser.add_argument(
        "--max-total-bytes",
        type=argparse_positive_integer,
        default=DEFAULT_MAX_TOTAL_BYTES,
    )
    collect_parser.set_defaults(handler=collect)

    verify_parser = subparsers.add_parser("verify", help="verify a sealed capsule")
    verify_parser.add_argument("--capsule", required=True)
    verify_parser.set_defaults(handler=verify)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        result = args.handler(args)
    except (CapsuleError, OSError, UnicodeError) as error:
        print(
            json.dumps({"status": "error", "error": str(error)}, sort_keys=True),
            file=sys.stderr,
        )
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
