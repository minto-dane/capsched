#!/usr/bin/env python3
"""Generate strict structural schemas from the pinned DL-F0-5 surface."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


HERE = Path(__file__).resolve().parent
MODELS = HERE.parent
ROOT = MODELS.parent
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v5"
GRAMMAR_PATH = F0 / "f0-machine-grammar-v5.json"
META_SCHEMA_PATH = F0 / "f0-machine-grammar-meta-schema-v5.json"
CHECKER_PATH = HERE / "validate-f0-machine-grammar-v5.py"
DEFAULT_OUTPUT = F0 / "generated"
ROOT_SCHEMAS = {
    "Model": "f0-model-schema-v5.json",
    "FiniteProfile": "f0-finite-profile-schema-v5.json",
    "FiniteRun": "f0-finite-run-schema-v5.json",
}

spec = importlib.util.spec_from_file_location("validate_f0_machine_grammar_v5", CHECKER_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("cannot load DL-F0-5 machine grammar checker")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def load_checked_foundation() -> tuple[
    dict[str, Any],
    Any,
    dict[str, Any],
]:
    snapshot = checker.capture_foundation_snapshot()
    result, grammar, _ = checker.validate_snapshot(snapshot)
    if result.get("status") != "construction_draft_shape_passed":
        raise RuntimeError("machine grammar did not pass its construction checker")
    if not isinstance(grammar, dict):
        raise RuntimeError("machine grammar is not an object")
    return grammar, snapshot, result


def load_checked_grammar() -> tuple[dict[str, Any], bytes, bytes]:
    grammar, snapshot, _ = load_checked_foundation()
    return grammar, snapshot.grammar_raw, snapshot.meta_schema_raw


def primitive_schema(wire: dict[str, Any]) -> dict[str, Any]:
    form = wire["form"]
    if form == "JSON_BOOLEAN":
        return {"type": "boolean"}
    if form == "JSON_INTEGER":
        return {"type": "integer", "minimum": wire["minimum"]}
    if form == "ASCII_FULLMATCH":
        pattern = wire["pattern"]
        return {
            "type": "string",
            "pattern": f"^(?![\\s\\S]*[\\r\\n])(?:{pattern})$",
        }
    if form == "PAIR":
        return {
            "type": "array",
            "prefixItems": [
                {"$ref": f"#/$defs/{component}"}
                for component in wire["components"]
            ],
            "items": False,
            "minItems": len(wire["components"]),
            "maxItems": len(wire["components"]),
        }
    if form == "CLOSED_ENUM":
        return {"type": "string", "enum": wire["values"]}
    raise RuntimeError(f"unknown primitive wire form: {form}")


def build_definitions(grammar: dict[str, Any]) -> dict[str, Any]:
    policies = {
        (entry["owner_tag"], entry["field"]): entry
        for entry in grammar["collection_field_policies"]
    }
    definitions: dict[str, Any] = {
        kind: primitive_schema(grammar["primitive_wire_types"][kind])
        for kind in grammar["primitive_kinds"]
    }

    def field_schema(owner_tag: str, field_name: str, kind: str) -> dict[str, Any]:
        match = checker.COLLECTION_RE.fullmatch(kind)
        if match is None:
            raise RuntimeError(f"invalid field kind after validation: {kind}")
        base = match.group("base")
        suffix = match.group("suffix")
        item = {"$ref": f"#/$defs/{base}"}
        if suffix is None:
            return item
        schema: dict[str, Any] = {"type": "array", "items": item}
        if suffix == "[1+]":
            schema["minItems"] = 1
        elif suffix == "[2+]":
            schema["minItems"] = 2
        policy = policies[(owner_tag, field_name)]
        if policy["mode"] == "canonical_set":
            schema["uniqueItems"] = True
        return schema

    for section in checker.NODE_SECTIONS:
        for node in grammar[section]:
            tag = node["tag"]
            required = ["tag"] + [field[0] for field in node["fields"]]
            properties: dict[str, Any] = {"tag": {"const": tag}}
            for field_name, kind in node["fields"]:
                properties[field_name] = field_schema(tag, field_name, kind)
            definitions[tag] = {
                "type": "object",
                "additionalProperties": False,
                "required": required,
                "properties": properties,
            }

    for kind, tags in grammar["kind_unions"].items():
        definitions[kind] = {
            "oneOf": [{"$ref": f"#/$defs/{tag}"} for tag in tags]
        }
    for kind, tag in grammar["kind_bindings"].items():
        definitions[kind] = {"$ref": f"#/$defs/{tag}"}
    for kind, tag in grammar["root_kinds"].items():
        definitions[kind] = {"$ref": f"#/$defs/{tag}"}
    return definitions


def build_schema(
    grammar: dict[str, Any],
    definitions: dict[str, Any],
    root_kind: str,
) -> dict[str, Any]:
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": f"https://domainlease.invalid/schema/{ROOT_SCHEMAS[root_kind]}",
        "title": f"DL-F0-5 strict {root_kind} construction schema",
        "$ref": f"#/$defs/{root_kind}",
        "$defs": definitions,
    }


def build_outputs_from_snapshot(
    grammar: dict[str, Any],
    snapshot: Any,
    *,
    generator_raw: bytes | None = None,
    grammar_checker_raw: bytes | None = None,
) -> dict[str, bytes]:
    grammar_raw = snapshot.grammar_raw
    meta_schema_raw = snapshot.meta_schema_raw
    definitions = build_definitions(grammar)
    outputs: dict[str, bytes] = {}
    schema_records = []
    for root_kind, filename in ROOT_SCHEMAS.items():
        schema = build_schema(grammar, definitions, root_kind)
        Draft202012Validator.check_schema(schema)
        raw = canonical_bytes(schema)
        outputs[filename] = raw
        schema_records.append(
            {
                "root_kind": root_kind,
                "path": f"capsched-models/policy/r11/epoch2/foundation-v5/generated/{filename}",
                "sha256": sha256(raw),
                "bytes": len(raw),
            }
        )

    source_parts = []
    for filename, raw in snapshot.normative_parts_raw:
        source_parts.append(
            {"path": filename, "sha256": sha256(raw), "bytes": len(raw)}
        )
    manifest = {
        "schema_version": 1,
        "artifact_id": "domainlease-r11-epoch2-f0-generated-structural-schemas-v5-construction-2",
        "status": "generated_structural_schemas_not_semantic_validation",
        "language_id": grammar["language_id"],
        "surface_sha256": grammar["surface_digest"]["sha256"],
        "grammar_sha256": sha256(grammar_raw),
        "meta_schema_sha256": sha256(meta_schema_raw),
        "generator_sha256": sha256(
            generator_raw
            if generator_raw is not None
            else checker.read_once(Path(__file__))
        ),
        "grammar_checker_sha256": sha256(
            grammar_checker_raw
            if grammar_checker_raw is not None
            else checker.read_once(CHECKER_PATH)
        ),
        "normative_parts": source_parts,
        "schemas": schema_records,
        "authorization": {
            "structural_schema_generation": True,
            "semantic_checker_complete": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "candidate_IR": False,
            "TLA_translation": False,
            "model_supported": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
        "nonclaims": [
            "Schema acceptance does not establish name resolution, typing, provenance, evaluation, transition, claim, morphism, or proof semantics.",
            "Finite profile and run schemas do not enumerate or redefine infinite denotational objects."
        ],
    }
    outputs["f0-generated-schema-manifest-v5.json"] = canonical_bytes(manifest)
    return outputs


def build_generation() -> tuple[dict[str, Any], dict[str, bytes], Any]:
    grammar, snapshot, _ = load_checked_foundation()
    return grammar, build_outputs_from_snapshot(grammar, snapshot), snapshot


def build_outputs() -> dict[str, bytes]:
    _, outputs, _ = build_generation()
    return outputs


def materialize(outputs: dict[str, bytes], output_dir: Path, check: bool) -> None:
    if check:
        for filename, expected in outputs.items():
            path = output_dir / filename
            try:
                actual = checker.read_once(path)
            except checker.Reject as exc:
                raise RuntimeError(f"missing or unsafe generated file: {path}") from exc
            if actual != expected:
                raise RuntimeError(
                    f"generated drift: {filename}: expected={sha256(expected)} actual={sha256(actual)}"
                )
        return
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, raw in outputs.items():
        (output_dir / filename).write_bytes(raw)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    outputs = build_outputs()
    materialize(outputs, args.output_dir, args.check)
    print(
        json.dumps(
            {
                "status": "passed",
                "mode": "check" if args.check else "materialize",
                "output_count": len(outputs),
                "output_sha256": {
                    filename: sha256(raw) for filename, raw in sorted(outputs.items())
                },
                "semantic_validation": False,
                "F0_local_acceptance": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
