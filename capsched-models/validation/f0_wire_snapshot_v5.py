"""Immutable canonical source snapshots for the DL-F0-5 model pipeline.

The snapshot deliberately stores bytes, not a parsed mutable object.  Every
pipeline stage must parse those bytes independently so a post-check mutation
cannot split source identity from the semantic projection.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Mapping, NoReturn


MAX_MODEL_BYTES = 4 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512


class SnapshotReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise SnapshotReject(reject_id, detail)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-SNAPSHOT-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-SNAPSHOT-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-SNAPSHOT-INTEGER", str(exc))


def _reject_float(token: str) -> NoReturn:
    reject("F05-SNAPSHOT-FLOAT", token)


def _reject_constant(token: str) -> NoReturn:
    reject("F05-SNAPSHOT-NON-JSON-NUMBER", token)


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def _validate_tree(value: Any) -> None:
    stack: list[tuple[Any, str, int]] = [(value, "$", 0)]
    nodes = 0
    while stack:
        current, path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-SNAPSHOT-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-SNAPSHOT-DEPTH", f"{path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-SNAPSHOT-UNSAFE-SCALAR", path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-SNAPSHOT-NEGATIVE-INTEGER", path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-SNAPSHOT-NON-ASCII", path)
            if any(ord(character) < 0x20 or ord(character) == 0x7F for character in current):
                reject("F05-SNAPSHOT-CONTROL-STRING", path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-SNAPSHOT-COLLECTION-LIMIT", path)
            for key, child in current.items():
                if not isinstance(key, str):
                    reject("F05-SNAPSHOT-NON-STRING-KEY", path)
                stack.append((child, _child_path(path, f".{key}"), depth + 1))
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-SNAPSHOT-COLLECTION-LIMIT", path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (current[index], _child_path(path, f"[{index}]"), depth + 1)
                )
            continue
        reject("F05-SNAPSHOT-UNSAFE-TYPE", f"{path}:{type(current).__name__}")


def canonical_bytes(value: Any) -> bytes:
    _validate_tree(value)
    try:
        return json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-SNAPSHOT-CANONICALIZE-RESOURCE", type(exc).__name__)


def parse_canonical_model(raw: bytes) -> dict[str, Any]:
    if type(raw) is not bytes or not raw or len(raw) > MAX_MODEL_BYTES:
        reject("F05-SNAPSHOT-SIZE", str(len(raw) if isinstance(raw, bytes) else -1))
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-SNAPSHOT-NON-ASCII", str(exc))
    try:
        value = json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_int=_parse_integer,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except SnapshotReject:
        raise
    except json.JSONDecodeError as exc:
        reject("F05-SNAPSHOT-JSON", str(exc))
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-SNAPSHOT-PARSE-RESOURCE", type(exc).__name__)
    _validate_tree(value)
    if not isinstance(value, dict):
        reject("F05-SNAPSHOT-TOPLEVEL", type(value).__name__)
    if raw != canonical_bytes(value):
        reject("F05-SNAPSHOT-NONCANONICAL", sha256(raw))
    return value


def _sha_field(value: Any, path: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
    ):
        reject("F05-SNAPSHOT-EVIDENCE-SHA256", path)
    return value


@dataclass(frozen=True)
class WireValidatedModelSnapshot:
    canonical_model_raw: bytes
    model_sha256: str
    model_bytes: int
    surface_sha256: str
    schema_sha256: str
    root_kind: str
    wire_validated: bool
    wire_authority: str

    @classmethod
    def from_wire_validation(
        cls,
        raw: bytes,
        evidence: Mapping[str, Any],
    ) -> "WireValidatedModelSnapshot":
        parse_canonical_model(raw)
        expected = {
            "status": "canonical_structural_instance_passed",
            "authority": "wire_shape_and_collection_canonicalization_only",
            "root_kind": "Model",
            "instance_sha256": sha256(raw),
            "instance_bytes": len(raw),
        }
        for key, value in expected.items():
            if type(evidence.get(key)) is not type(value) or evidence.get(key) != value:
                reject(
                    "F05-SNAPSHOT-WIRE-EVIDENCE",
                    f"{key}:actual={evidence.get(key)!r} expected={value!r}",
                )
        return cls(
            canonical_model_raw=bytes(raw),
            model_sha256=expected["instance_sha256"],
            model_bytes=len(raw),
            surface_sha256=_sha_field(evidence.get("surface_sha256"), "surface_sha256"),
            schema_sha256=_sha_field(evidence.get("schema_sha256"), "schema_sha256"),
            root_kind="Model",
            wire_validated=True,
            wire_authority=expected["authority"],
        )

    @classmethod
    def for_internal_test(cls, model: Mapping[str, Any]) -> "WireValidatedModelSnapshot":
        raw = canonical_bytes(model)
        parse_canonical_model(raw)
        return cls(
            canonical_model_raw=raw,
            model_sha256=sha256(raw),
            model_bytes=len(raw),
            surface_sha256="0" * 64,
            schema_sha256="0" * 64,
            root_kind="Model",
            wire_validated=False,
            wire_authority="internal_test_object_canonicalization_only",
        )

    def parse_model(self) -> dict[str, Any]:
        value = parse_canonical_model(self.canonical_model_raw)
        if sha256(self.canonical_model_raw) != self.model_sha256:
            reject("F05-SNAPSHOT-IDENTITY-DRIFT", self.model_sha256)
        if len(self.canonical_model_raw) != self.model_bytes:
            reject("F05-SNAPSHOT-SIZE-DRIFT", str(self.model_bytes))
        return value

    def require_wire_validated(self) -> None:
        if self.wire_validated is not True or self.root_kind != "Model":
            reject("F05-SNAPSHOT-NOT-WIRE-VALIDATED", self.wire_authority)
