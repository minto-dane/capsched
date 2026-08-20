#!/usr/bin/env python3
"""End-to-end structural and canonical-wire tests for generated DL-F0-5 schemas."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
WIRE_CHECKER_PATH = HERE / "validate-f0-canonical-instance-v5.py"

spec = importlib.util.spec_from_file_location("validate_f0_canonical_instance_v5", WIRE_CHECKER_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("cannot load canonical instance checker")
wire = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wire)


def qn(module: str, local: str) -> list[str]:
    return [module, local]


def sort_bool() -> dict[str, Any]:
    return {"tag": "SORT_BOOL"}


def sort_one() -> dict[str, Any]:
    return {"tag": "SORT_ONE"}


def bool_term(value: bool = True, result_sort: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "tag": "TYPED_TERM",
        "result_sort": result_sort if result_sort is not None else sort_bool(),
        "node": {"tag": "TERM_BOOL", "value": value},
    }


def module(local: str, declarations: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    return {
        "tag": "MODULE",
        "name": local,
        "imports": [],
        "declarations": declarations or [],
        "init_contribution": bool_term(),
    }


def model_fixture() -> dict[str, Any]:
    return {
        "tag": "MODEL",
        "modules": [module("a"), module("b")],
        "root_module": "a",
        "active_modules": ["a"],
    }


def action_declaration() -> dict[str, Any]:
    return {
        "tag": "DECL_ACTION",
        "name": qn("m", "Act"),
        "parameter_variable": "p",
        "parameter_sort": sort_bool(),
        "invoke": bool_term(),
        "branches": [
            {
                "tag": "ACTION_BRANCH",
                "branch": "ok",
                "guard": bool_term(),
                "updates": [],
                "emits": [],
            }
        ],
    }


def profile_fixture() -> dict[str, Any]:
    return {
        "tag": "FINITE_PROFILE",
        "interpretation_id": qn("evidence", "i0"),
        "model_sha256": "0" * 64,
        "atom_carriers": [
            {
                "tag": "ATOM_CARRIER",
                "atom": qn("m", "A"),
                "values": [
                    {"tag": "ATOM_VALUE", "atom": qn("m", "A"), "value": "a"},
                    {"tag": "ATOM_VALUE", "atom": qn("m", "A"), "value": "b"},
                ],
            },
            {
                "tag": "ATOM_CARRIER",
                "atom": qn("m", "B"),
                "values": [
                    {"tag": "ATOM_VALUE", "atom": qn("m", "B"), "value": "a"}
                ],
            },
        ],
        "limits": [],
        "constants": [],
    }


def location(key: bool) -> dict[str, Any]:
    return {
        "tag": "LOCATION_VALUE",
        "state_product": qn("m", "q"),
        "key": {"tag": "VALUE_BOOL", "value": key},
    }


def state_fixture() -> dict[str, Any]:
    return {
        "tag": "STATE_VALUE",
        "cells": [
            {
                "tag": "CELL_VALUE",
                "location": location(False),
                "value": {"tag": "VALUE_BOOL", "value": False},
            },
            {
                "tag": "CELL_VALUE",
                "location": location(True),
                "value": {"tag": "VALUE_BOOL", "value": True},
            },
        ],
    }


def run_fixture() -> dict[str, Any]:
    state = state_fixture()
    return {
        "tag": "FINITE_RUN_VALUE",
        "model_sha256": "0" * 64,
        "interpretation": qn("evidence", "i0"),
        "initial_state": state,
        "transitions": [
            {
                "tag": "TRANSITION_VALUE",
                "pre_state": copy.deepcopy(state),
                "label": {"tag": "LABEL_STUTTER"},
                "event_bundle": {"tag": "EVENT_BUNDLE_VALUE", "channels": []},
                "post_state": copy.deepcopy(state),
            }
        ],
    }


Mutation = Callable[[dict[str, Any]], None]


def add_unknown_root(value: dict[str, Any]) -> None:
    value["unknown"] = True


def remove_required(value: dict[str, Any]) -> None:
    del value["root_module"]


def empty_modules(value: dict[str, Any]) -> None:
    value["modules"] = []


def missing_active_modules(value: dict[str, Any]) -> None:
    del value["active_modules"]


def reverse_modules(value: dict[str, Any]) -> None:
    value["modules"].reverse()


def raw_term_bypasses_wrapper(value: dict[str, Any]) -> None:
    value["modules"][0]["init_contribution"] = {"tag": "TERM_BOOL", "value": True}


def missing_term_result(value: dict[str, Any]) -> None:
    del value["modules"][0]["init_contribution"]["result_sort"]


def malformed_qualified_name(value: dict[str, Any]) -> None:
    value["root_module"] += "\n"


def missing_action_binder(value: dict[str, Any]) -> None:
    value["modules"] = [module("a", [action_declaration()])]
    del value["modules"][0]["declarations"][0]["parameter_variable"]


def uppercase_sha(value: dict[str, Any]) -> None:
    value["model_sha256"] = "A" * 64


def reverse_atom_carriers(value: dict[str, Any]) -> None:
    value["atom_carriers"].reverse()


def duplicate_atom_carrier_key(value: dict[str, Any]) -> None:
    value["atom_carriers"][1]["atom"] = copy.deepcopy(value["atom_carriers"][0]["atom"])


def empty_atom_values(value: dict[str, Any]) -> None:
    value["atom_carriers"][0]["values"] = []


def boolean_nat(value: dict[str, Any]) -> None:
    value["limits"] = [{"tag": "LIMIT_VALUE", "limit": qn("m", "L"), "value": True}]


def negative_nat(value: dict[str, Any]) -> None:
    value["limits"] = [{"tag": "LIMIT_VALUE", "limit": qn("m", "L"), "value": -1}]


def reverse_state_cells(value: dict[str, Any]) -> None:
    value["initial_state"]["cells"].reverse()


def duplicate_state_location(value: dict[str, Any]) -> None:
    value["initial_state"]["cells"][1]["location"] = copy.deepcopy(
        value["initial_state"]["cells"][0]["location"]
    )


def wrong_label_tag(value: dict[str, Any]) -> None:
    value["transitions"][0]["label"] = {"tag": "LABEL_UNKNOWN"}


def do_label_without_parameter(value: dict[str, Any]) -> None:
    value["transitions"][0]["label"] = {
        "tag": "LABEL_DO",
        "action": qn("m", "Act"),
        "branch": "ok",
    }


CASES = [
    ("model_unknown_root", "Model", model_fixture, add_unknown_root, "F05-WIRE-SCHEMA"),
    ("model_missing_required", "Model", model_fixture, remove_required, "F05-WIRE-SCHEMA"),
    ("model_empty_modules", "Model", model_fixture, empty_modules, "F05-WIRE-SCHEMA"),
    ("model_missing_active_modules", "Model", model_fixture, missing_active_modules, "F05-WIRE-SCHEMA"),
    ("model_module_order", "Model", model_fixture, reverse_modules, "F05-WIRE-COLLECTION-ORDER"),
    ("model_raw_term", "Model", model_fixture, raw_term_bypasses_wrapper, "F05-WIRE-SCHEMA"),
    ("model_missing_term_result", "Model", model_fixture, missing_term_result, "F05-WIRE-SCHEMA"),
    ("model_qualified_name_newline", "Model", model_fixture, malformed_qualified_name, "F05-WIRE-CONTROL-STRING"),
    ("model_missing_action_binder", "Model", model_fixture, missing_action_binder, "F05-WIRE-SCHEMA"),
    ("profile_uppercase_sha", "FiniteProfile", profile_fixture, uppercase_sha, "F05-WIRE-SCHEMA"),
    ("profile_carrier_order", "FiniteProfile", profile_fixture, reverse_atom_carriers, "F05-WIRE-COLLECTION-ORDER"),
    ("profile_duplicate_carrier", "FiniteProfile", profile_fixture, duplicate_atom_carrier_key, "F05-WIRE-COLLECTION-ORDER"),
    ("profile_empty_atom_values", "FiniteProfile", profile_fixture, empty_atom_values, "F05-WIRE-SCHEMA"),
    ("profile_boolean_nat", "FiniteProfile", profile_fixture, boolean_nat, "F05-WIRE-SCHEMA"),
    ("profile_negative_nat", "FiniteProfile", profile_fixture, negative_nat, "F05-WIRE-NEGATIVE-INTEGER"),
    ("run_cell_order", "FiniteRun", run_fixture, reverse_state_cells, "F05-WIRE-COLLECTION-ORDER"),
    ("run_duplicate_location", "FiniteRun", run_fixture, duplicate_state_location, "F05-WIRE-COLLECTION-ORDER"),
    ("run_unknown_label", "FiniteRun", run_fixture, wrong_label_tag, "F05-WIRE-SCHEMA"),
    ("run_do_missing_parameter", "FiniteRun", run_fixture, do_label_without_parameter, "F05-WIRE-SCHEMA"),
]


def run_value(root_kind: str, value: dict[str, Any], raw_override: bytes | None = None) -> tuple[int, str]:
    with tempfile.TemporaryDirectory(prefix="f0-generated-schema-v5-") as temporary:
        path = Path(temporary) / "instance.json"
        raw = raw_override if raw_override is not None else wire.checker.canonical_bytes(value)
        path.write_bytes(raw)
        try:
            wire.validate(path, root_kind)
        except wire.Reject as exc:
            return 1, exc.reject_id
        return 0, "passed"


def main() -> int:
    foundation_checker = wire.generator.checker
    original_read_once = foundation_checker.read_once
    grammar_reads = 0

    def poison_second_grammar_read(path: Path) -> bytes:
        nonlocal grammar_reads
        raw = original_read_once(path)
        if path == foundation_checker.GRAMMAR:
            grammar_reads += 1
            if grammar_reads > 1:
                return b"{}"
        return raw

    foundation_checker.read_once = poison_second_grammar_read
    try:
        snapshot_grammar, snapshot_outputs, _ = wire.generator.build_generation()
    finally:
        foundation_checker.read_once = original_read_once
    if grammar_reads != 1:
        raise RuntimeError(f"foundation grammar was read {grammar_reads} times")

    raw_model = wire.checker.canonical_bytes(model_fixture())
    mismatched_model = model_fixture()
    mismatched_model["root_module"] = "b"
    try:
        wire.validate_loaded(
            mismatched_model,
            raw_model,
            "Model",
            snapshot_grammar,
            snapshot_outputs,
        )
    except wire.Reject as exc:
        if exc.reject_id != "F05-WIRE-RAW-OBJECT-MISMATCH":
            raise RuntimeError(f"unexpected raw/object mismatch reject: {exc.reject_id}")
    else:
        raise RuntimeError("raw/object mismatch was accepted")

    baselines = {
        "Model": model_fixture(),
        "FiniteProfile": profile_fixture(),
        "FiniteRun": run_fixture(),
    }
    for root_kind, value in baselines.items():
        code, result = run_value(root_kind, value)
        if code != 0:
            raise RuntimeError(f"baseline {root_kind} rejected: {result}")

    semantic_negative_model = model_fixture()
    semantic_negative_model["modules"][0]["init_contribution"] = bool_term(
        True,
        result_sort=sort_one(),
    )
    code, result = run_value("Model", semantic_negative_model)
    if code != 0:
        raise RuntimeError(f"semantic negative control should be wire-valid: {result}")

    semantic_negative_run = run_fixture()
    semantic_negative_run["transitions"][0]["pre_state"]["cells"] = []
    code, result = run_value("FiniteRun", semantic_negative_run)
    if code != 0:
        raise RuntimeError(f"run adjacency negative control should be wire-valid: {result}")

    results = []
    for case_id, root_kind, fixture, mutation, expected in CASES:
        value = fixture()
        mutation(value)
        code, actual = run_value(root_kind, value)
        if code == 0 or actual != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {actual}")
        results.append({"id": case_id, "reject_id": actual})

    noncanonical = wire.checker.canonical_bytes(model_fixture()) + b"\n"
    code, actual = run_value("Model", model_fixture(), noncanonical)
    if code == 0 or actual != "F05-WIRE-NONCANONICAL-JSON":
        raise RuntimeError(f"noncanonical_json: got {actual}")
    results.append({"id": "noncanonical_json", "reject_id": actual})

    duplicate = wire.checker.canonical_bytes(model_fixture()).replace(
        b'"tag":"MODEL"',
        b'"tag":"MODEL","tag":"MODEL"',
        1,
    )
    code, actual = run_value("Model", model_fixture(), duplicate)
    if code == 0 or actual != "F05-WIRE-DUPLICATE-KEY":
        raise RuntimeError(f"duplicate_key: got {actual}")
    results.append({"id": "duplicate_key", "reject_id": actual})

    deeply_nested = b'{"x":' * 1200 + b"0" + b"}" * 1200
    code, actual = run_value("Model", model_fixture(), deeply_nested)
    if code == 0 or actual != "F05-WIRE-DEPTH":
        raise RuntimeError(f"wire_depth_resource: got {actual}")
    results.append({"id": "wire_depth_resource", "reject_id": actual})

    oversized_integer = b'{"x":' + b"1" * 5000 + b"}"
    code, actual = run_value("Model", model_fixture(), oversized_integer)
    if code == 0 or actual != "F05-WIRE-INTEGER-DIGITS":
        raise RuntimeError(f"wire_integer_digit_resource: got {actual}")
    results.append({"id": "wire_integer_digit_resource", "reject_id": actual})

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "generated_schema_and_canonical_wire_regression_only",
                "baseline_roots_passed": sorted(baselines),
                "mutations_total": len(results),
                "mutations_rejected_at_expected_id": len(results),
                "semantic_negative_controls_wire_passed": 2,
                "foundation_grammar_reads": grammar_reads,
                "raw_object_mismatch_rejected": True,
                "results": results,
                "semantic_validation": False,
                "proof_validation": False,
                "F0_local_acceptance": False,
                "K0_G0_complete": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
