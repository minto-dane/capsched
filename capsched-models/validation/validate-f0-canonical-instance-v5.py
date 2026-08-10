#!/usr/bin/env python3
"""Validate canonical structural DL-F0-5 Model/Profile/Run wire instances."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
from typing import Any, NoReturn

from jsonschema import Draft202012Validator


HERE = Path(__file__).resolve().parent
MODELS = HERE.parent
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v5"
GENERATED = F0 / "generated"
GRAMMAR_PATH = F0 / "f0-machine-grammar-v5.json"
CHECKER_PATH = HERE / "validate-f0-machine-grammar-v5.py"
GENERATOR_PATH = HERE / "generate-f0-strict-schemas-v5.py"


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checker = load_module("validate_f0_machine_grammar_v5", CHECKER_PATH)
generator = load_module("generate_f0_strict_schemas_v5", GENERATOR_PATH)


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise Reject(reject_id, detail)


def render_path(parts: Any) -> str:
    rendered = "$"
    for part in parts:
        if isinstance(part, int):
            rendered += f"[{part}]"
        else:
            rendered += f".{part}"
    return rendered


def load_generation() -> tuple[dict[str, Any], dict[str, bytes]]:
    grammar, outputs, _ = generator.build_generation()
    generator.materialize(outputs, GENERATED, True)
    if not isinstance(grammar, dict):
        reject("F05-WIRE-GRAMMAR", "grammar is not an object")
    return grammar, outputs


def load_canonical_instance(path: Path) -> tuple[Any, bytes]:
    try:
        raw = checker.read_once(path)
        value = checker.parse_ascii_json(raw, path)
    except checker.Reject as exc:
        reject(f"F05-WIRE-{exc.reject_id.removeprefix('F05-MG-')}", exc.detail)
    canonical = checker.canonical_bytes(value)
    if raw != canonical:
        reject(
            "F05-WIRE-NONCANONICAL-JSON",
            f"actual={checker.digest(raw)} canonical={checker.digest(canonical)}",
        )
    return value, raw


def validate_schema(value: Any, schema_raw: bytes) -> None:
    schema = json.loads(schema_raw.decode("ascii"))
    validator = Draft202012Validator(schema)
    errors = sorted(
        validator.iter_errors(value),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        first = errors[0]
        reject(
            "F05-WIRE-SCHEMA",
            f"{render_path(first.absolute_path)}: {first.message}",
        )


def canonical_collection_key(item: Any, key_rule: str, path: str) -> bytes:
    if key_rule == "SELF_CANONICAL":
        return checker.canonical_bytes(item)
    if key_rule == "TAG_THEN_CANONICAL":
        if not isinstance(item, dict) or not isinstance(item.get("tag"), str):
            reject("F05-WIRE-COLLECTION-KEY", path)
        return item["tag"].encode("ascii") + b"\x00" + checker.canonical_bytes(item)
    if not isinstance(item, dict) or key_rule not in item:
        reject("F05-WIRE-COLLECTION-KEY", f"{path}.{key_rule}")
    return checker.canonical_bytes(item[key_rule])


def validate_collections(value: Any, grammar: dict[str, Any]) -> int:
    node_by_tag = {
        node["tag"]: node
        for section in checker.NODE_SECTIONS
        for node in grammar[section]
    }
    policies = {
        (entry["owner_tag"], entry["field"]): entry
        for entry in grammar["collection_field_policies"]
    }
    checked = 0

    def walk(current: Any, path: str) -> None:
        nonlocal checked
        if isinstance(current, list):
            for index, child in enumerate(current):
                walk(child, f"{path}[{index}]")
            return
        if not isinstance(current, dict):
            return
        tag = current.get("tag")
        if not isinstance(tag, str) or tag not in node_by_tag:
            return
        node = node_by_tag[tag]
        for field_name, kind in node["fields"]:
            child = current[field_name]
            match = checker.COLLECTION_RE.fullmatch(kind)
            if match is None:
                reject("F05-WIRE-GRAMMAR-KIND", f"{tag}.{field_name}:{kind}")
            suffix = match.group("suffix")
            if suffix is not None:
                policy = policies[(tag, field_name)]
                checked += 1
                if policy["mode"] != "ordered_sequence":
                    previous: bytes | None = None
                    for index, item in enumerate(child):
                        key = canonical_collection_key(
                            item,
                            policy["key"],
                            f"{path}.{field_name}[{index}]",
                        )
                        if previous is not None and previous >= key:
                            reject(
                                "F05-WIRE-COLLECTION-ORDER",
                                f"{path}.{field_name}[{index}]",
                            )
                        previous = key
                for index, item in enumerate(child):
                    walk(item, f"{path}.{field_name}[{index}]")
            else:
                walk(child, f"{path}.{field_name}")

    walk(value, "$")
    return checked


def validate_loaded(
    value: Any,
    raw: bytes,
    root_kind: str,
    grammar: dict[str, Any],
    outputs: dict[str, bytes],
) -> dict[str, Any]:
    try:
        parsed = checker.parse_ascii_json(raw, Path("<instance-snapshot>"))
    except checker.Reject as exc:
        reject(f"F05-WIRE-{exc.reject_id.removeprefix('F05-MG-')}", exc.detail)
    canonical = checker.canonical_bytes(parsed)
    if raw != canonical:
        reject(
            "F05-WIRE-NONCANONICAL-JSON",
            f"actual={checker.digest(raw)} canonical={checker.digest(canonical)}",
        )
    if checker.canonical_bytes(value) != canonical:
        reject("F05-WIRE-RAW-OBJECT-MISMATCH", checker.digest(raw))
    value = parsed
    if root_kind not in generator.ROOT_SCHEMAS:
        reject("F05-WIRE-ROOT", root_kind)
    schema_name = generator.ROOT_SCHEMAS[root_kind]
    validate_schema(value, outputs[schema_name])
    collection_count = validate_collections(value, grammar)
    return {
        "schema_version": 1,
        "status": "canonical_structural_instance_passed",
        "authority": "wire_shape_and_collection_canonicalization_only",
        "root_kind": root_kind,
        "instance_sha256": checker.digest(raw),
        "instance_bytes": len(raw),
        "schema_sha256": checker.digest(outputs[schema_name]),
        "surface_sha256": grammar["surface_digest"]["sha256"],
        "collections_checked": collection_count,
        "semantic_validation": False,
        "proof_validation": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }


def validate_and_load(path: Path, root_kind: str) -> tuple[dict[str, Any], Any, bytes]:
    grammar, outputs = load_generation()
    value, raw = load_canonical_instance(path)
    return validate_loaded(value, raw, root_kind, grammar, outputs), value, raw


def validate(path: Path, root_kind: str) -> dict[str, Any]:
    result, _, _ = validate_and_load(path, root_kind)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root-kind", choices=sorted(generator.ROOT_SCHEMAS), required=True)
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    print(
        json.dumps(
            validate(args.path, args.root_kind),
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Reject as exc:
        print(
            json.dumps(
                {"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail},
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
