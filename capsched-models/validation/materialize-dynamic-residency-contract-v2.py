#!/usr/bin/env python3
"""Materialize the R6 successor contract from an immutable v1 base and overlay."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ALLOWED_OVERLAY_KEYS = {
    "schema_version",
    "id",
    "date",
    "work_record",
    "analysis",
    "requirement",
    "base",
    "effective_contract",
    "composition",
    "remove_paths",
    "remove_list_items",
    "append_unique",
    "deep_merge",
}


class MaterializationError(Exception):
    pass


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_json_single(path: Path) -> tuple[bytes, Any]:
    data = path.read_bytes()
    try:
        value = json.loads(data)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MaterializationError(f"invalid JSON {path}: {exc}") from exc
    return data, value


def decode_pointer(path: str) -> list[str]:
    if not isinstance(path, str) or not path.startswith("/") or path == "/":
        raise MaterializationError(f"invalid JSON pointer: {path!r}")
    return [part.replace("~1", "/").replace("~0", "~") for part in path[1:].split("/")]


def remove_pointer(root: dict[str, Any], path: str) -> None:
    parts = decode_pointer(path)
    current: Any = root
    for part in parts[:-1]:
        if not isinstance(current, dict) or part not in current:
            raise MaterializationError(f"remove path does not exist: {path}")
        current = current[part]
    leaf = parts[-1]
    if not isinstance(current, dict) or leaf not in current:
        raise MaterializationError(f"remove path does not exist: {path}")
    del current[leaf]


def deep_merge(base: Any, update: Any, path: str = "") -> Any:
    if isinstance(update, dict):
        if not isinstance(base, dict):
            return copy.deepcopy(update)
        result = copy.deepcopy(base)
        for key, value in update.items():
            child = f"{path}/{key}"
            result[key] = deep_merge(result[key], value, child) if key in result else copy.deepcopy(value)
        return result
    return copy.deepcopy(update)


def require_string(obj: dict[str, Any], key: str, where: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value:
        raise MaterializationError(f"{where}.{key} must be a nonempty string")
    return value


def validate_overlay(overlay: Any) -> dict[str, Any]:
    if not isinstance(overlay, dict):
        raise MaterializationError("overlay root must be an object")
    extra = set(overlay) - ALLOWED_OVERLAY_KEYS
    if extra:
        raise MaterializationError(f"unknown overlay keys: {sorted(extra)}")
    if overlay.get("schema_version") != 1:
        raise MaterializationError("overlay schema_version must equal 1")
    for key in ALLOWED_OVERLAY_KEYS:
        if key not in overlay:
            raise MaterializationError(f"missing overlay key: {key}")
    for key in ("base", "effective_contract", "composition", "remove_list_items", "append_unique", "deep_merge"):
        if not isinstance(overlay[key], dict):
            raise MaterializationError(f"overlay.{key} must be an object")
    if not isinstance(overlay["remove_paths"], list) or not all(isinstance(v, str) for v in overlay["remove_paths"]):
        raise MaterializationError("overlay.remove_paths must be a string array")
    return overlay


def materialize(base_path: Path, overlay_path: Path) -> bytes:
    base_bytes, base = load_json_single(base_path)
    overlay_bytes, raw_overlay = load_json_single(overlay_path)
    overlay = validate_overlay(raw_overlay)
    if not isinstance(base, dict):
        raise MaterializationError("base contract root must be an object")

    expected_base_name = require_string(overlay["base"], "path", "overlay.base")
    expected_base_hash = require_string(overlay["base"], "raw_sha256", "overlay.base")
    if base_path.name != expected_base_name:
        raise MaterializationError(f"base path mismatch: {base_path.name} != {expected_base_name}")
    actual_base_hash = sha256_bytes(base_bytes)
    if actual_base_hash != expected_base_hash:
        raise MaterializationError(f"base hash mismatch: {actual_base_hash} != {expected_base_hash}")

    result = copy.deepcopy(base)
    for path in overlay["remove_paths"]:
        remove_pointer(result, path)

    for key, items in overlay["remove_list_items"].items():
        if key not in result or not isinstance(result[key], list):
            raise MaterializationError(f"remove_list_items target is not an existing list: {key}")
        if not isinstance(items, list):
            raise MaterializationError(f"remove_list_items.{key} must be an array")
        for item in items:
            count = result[key].count(item)
            if count != 1:
                raise MaterializationError(f"remove item {item!r} occurs {count} times in {key}")
            result[key].remove(item)

    result = deep_merge(result, overlay["deep_merge"])

    for key, items in overlay["append_unique"].items():
        if key not in result or not isinstance(result[key], list):
            raise MaterializationError(f"append_unique target is not an existing list: {key}")
        if not isinstance(items, list):
            raise MaterializationError(f"append_unique.{key} must be an array")
        for item in items:
            if item in result[key]:
                raise MaterializationError(f"append item already exists in {key}: {item!r}")
            result[key].append(copy.deepcopy(item))

    expected_id = require_string(overlay["effective_contract"], "id", "overlay.effective_contract")
    expected_status = require_string(overlay["effective_contract"], "status", "overlay.effective_contract")
    if result.get("id") != expected_id or result.get("status") != expected_status:
        raise MaterializationError("effective contract id/status mismatch after merge")
    if result.get("schema_version") != 2:
        raise MaterializationError("effective contract schema_version must equal 2")

    result["successor_materialization"] = {
        "algorithm": overlay["composition"].get("algorithm"),
        "base_path": base_path.name,
        "base_raw_sha256": actual_base_hash,
        "overlay_path": overlay_path.name,
        "overlay_raw_sha256": sha256_bytes(overlay_bytes),
        "base_is_rejected_regression_target": True,
        "materialization_is_architecture_freeze_evidence": False,
    }
    return (json.dumps(result, indent=2, ensure_ascii=True) + "\n").encode("ascii")


def main() -> int:
    here = Path(__file__).resolve().parent
    analysis = here.parent / "analysis"
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, default=analysis / "dynamic-admission-recurring-residency-architecture-contract-v1.json")
    parser.add_argument("--overlay", type=Path, default=analysis / "dynamic-residency-r6-successor-semantic-overlay-v1.json")
    parser.add_argument("--output", type=Path, default=analysis / "dynamic-admission-recurring-residency-architecture-contract-v2.json")
    parser.add_argument("--check", action="store_true", help="compare materialized bytes with --output without writing")
    args = parser.parse_args()
    try:
        output = materialize(args.base, args.overlay)
        if args.check:
            current = args.output.read_bytes()
            if current != output:
                raise MaterializationError(f"materialized output differs: {args.output}")
            print(f"PASS: materialized output matches {args.output}")
        else:
            args.output.write_bytes(output)
            print(f"WROTE: {args.output}")
            print(f"sha256: {sha256_bytes(output)}")
    except (MaterializationError, OSError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
