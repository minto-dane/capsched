#!/usr/bin/env python3
"""Hostile regression for checked DL-F0-5 semantic-root occurrences."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


fixture = load_module("f0_occurrence_fixture", HERE / "test-f0-core-syntax-v5.py")
occurrence = load_module(
    "f0_checked_term_occurrences_v5_test",
    HERE / "f0_checked_term_occurrences_v5.py",
)
eval_rules = load_module("f0_occurrence_eval_rules", HERE / "f0_eval_rules_v5.py")


def checked_fixture() -> Any:
    checker = fixture.semantics.CoreSyntaxChecker.for_internal_test_model(
        fixture.model_fixture()
    )
    checker.check()
    return checker


def expect_reject(
    case_id: str,
    expected: str,
    function: Callable[[], Any],
) -> dict[str, str]:
    try:
        function()
    except occurrence.Reject as exc:
        if exc.reject_id != expected:
            raise RuntimeError(
                f"{case_id}: expected {expected}, got {exc.reject_id}: {exc.detail}"
            )
        return {"id": case_id, "reject_id": exc.reject_id}
    raise RuntimeError(f"{case_id}: unexpectedly accepted")


def main() -> int:
    contract = eval_rules.load_contract()
    first_checker = checked_fixture()
    second_checker = checked_fixture()
    first = occurrence.materialize(first_checker, contract)
    second = occurrence.materialize(second_checker, contract)
    if first.artifact_raw != second.artifact_raw:
        raise RuntimeError("independent construction runs produced different occurrence bytes")
    if first.index_construction_id != second.index_construction_id:
        raise RuntimeError("independent construction runs produced different index IDs")

    linked = first_checker.linked_model_snapshot.artifact()
    baseline = occurrence.validate_snapshot(
        first.artifact_raw,
        linked,
        first_checker.rule_contract,
        contract,
    )
    artifact = first.artifact()
    rows = artifact["occurrences"]
    if len(rows) != first.occurrence_count or not rows:
        raise RuntimeError("occurrence count drift")
    ids = [row["checked_term_occurrence_id"]["sha256"] for row in rows]
    if len(ids) != len(set(ids)):
        raise RuntimeError("occurrence IDs are not unique")
    for row in rows:
        context = row["root_context"]["tag"]
        if context == "CLOSED_ROOT":
            if row["gamma"] or row["delta"]:
                raise RuntimeError("closed occurrence carries ambient context")
        elif context == "ACTION_PARAM_ROOT":
            if len(row["gamma"]) != 1 or len(row["delta"]) != 1:
                raise RuntimeError("action occurrence lost exact parameter context")
            if row["gamma"][0]["parameter_slot"] != row["delta"][0]["dependencies"][0]["subject"]:
                raise RuntimeError("Gamma and Delta parameter slots differ")
        else:
            raise RuntimeError(f"unknown root context {context}")

    cases: list[dict[str, str]] = []

    def mutated(mutator: Callable[[dict[str, Any]], None]) -> bytes:
        candidate = copy.deepcopy(artifact)
        mutator(candidate)
        return occurrence.canonical_bytes(candidate)

    validate = lambda raw: occurrence.validate_snapshot(
        raw, linked, first_checker.rule_contract, contract
    )
    cases.append(
        expect_reject(
            "linked-term-substitution",
            "F05-OCC-LINKED-TERM-DRIFT",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"][0]["term"]["node"].__setitem__(
                        "forged", True
                    )
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "occurrence-id-substitution",
            "F05-OCC-ID",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"][0][
                        "checked_term_occurrence_id"
                    ].__setitem__("sha256", "0" * 64)
                )
            ),
        )
    )
    action_index = next(
        index
        for index, row in enumerate(rows)
        if row["root_context"]["tag"] == "ACTION_PARAM_ROOT"
    )
    cases.append(
        expect_reject(
            "gamma-delta-desynchronization",
            "F05-OCC-ROOT-CONTEXT",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"][action_index]["delta"].clear()
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "unknown-provenance-source",
            "F05-OCC-PROVENANCE",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"][0]["provenance"].append(
                        "AMBIENT"
                    )
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "linked-construction-id-substitution",
            "F05-OCC-LINKED-ID",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"][0][
                        "linked_model_construction_id"
                    ].__setitem__("sha256", "0" * 64)
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "index-id-substitution",
            "F05-OCC-INDEX-ID",
            lambda: validate(
                mutated(
                    lambda candidate: candidate[
                        "checked_term_occurrence_index_construction_id"
                    ].__setitem__("sha256", "0" * 64)
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "authorization-self-promotion",
            "F05-OCC-AUTHORIZATION",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["authorization"].__setitem__(
                        "F0_local_acceptance", True
                    )
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "premature-semantic-context",
            "F05-OCC-SEMANTIC-CONTEXT",
            lambda: validate(
                mutated(
                    lambda candidate: candidate.__setitem__(
                        "semantic_context_digest",
                        {"status": "ISSUED", "sha256": "0" * 64},
                    )
                )
            ),
        )
    )
    cases.append(
        expect_reject(
            "occurrence-order",
            "F05-OCC-PATH-ORDER",
            lambda: validate(
                mutated(
                    lambda candidate: candidate["occurrences"].__setitem__(
                        slice(0, 2), list(reversed(candidate["occurrences"][:2]))
                    )
                )
            ),
        )
    )
    duplicate_raw = first.artifact_raw.replace(
        b'{"artifact_id":',
        b'{"artifact_id":"duplicate","artifact_id":',
        1,
    )
    cases.append(
        expect_reject(
            "duplicate-json-key",
            "F05-OCC-DUPLICATE-KEY",
            lambda: occurrence.parse_canonical_artifact(duplicate_raw),
        )
    )
    cases.append(
        expect_reject(
            "integer-digit-limit",
            "F05-OCC-INTEGER-DIGITS",
            lambda: occurrence.parse_canonical_artifact(
                b'{"value":' + b"1" * (occurrence.MAX_INTEGER_DIGITS + 1) + b"}"
            ),
        )
    )
    deep_raw = (
        b'{"value":'
        + b"[" * (occurrence.MAX_JSON_DEPTH + 1)
        + b"0"
        + b"]" * (occurrence.MAX_JSON_DEPTH + 1)
        + b"}"
    )
    cases.append(
        expect_reject(
            "json-depth-limit",
            "F05-OCC-DEPTH",
            lambda: occurrence.parse_canonical_artifact(deep_raw),
        )
    )
    original_node_limit = occurrence.MAX_JSON_NODES
    try:
        occurrence.MAX_JSON_NODES = 3
        cases.append(
            expect_reject(
                "json-node-limit",
                "F05-OCC-NODE-LIMIT",
                lambda: occurrence.parse_canonical_artifact(b'{"a":1,"b":2,"c":3}'),
            )
        )
    finally:
        occurrence.MAX_JSON_NODES = original_node_limit
    cases.append(
        expect_reject(
            "control-character-string",
            "F05-OCC-CONTROL-STRING",
            lambda: occurrence.parse_canonical_artifact(b'{"value":"\\u0000"}'),
        )
    )

    postcheck_checker = checked_fixture()
    action = next(
        declaration
        for module in postcheck_checker.model["modules"]
        for declaration in module["declarations"]
        if declaration["tag"] == "DECL_ACTION"
    )
    action["invoke"]["node"]["forged"] = True
    cases.append(
        expect_reject(
            "postcheck-source-mutation",
            "F05-OCC-LINKED-TERM-DRIFT",
            lambda: occurrence.materialize(postcheck_checker, contract),
        )
    )

    output = {
        "schema_version": 1,
        "status": "checked_term_occurrence_construction_hostile_regression_passed",
        "occurrence_count": first.occurrence_count,
        "index_construction_id": dict(first.index_construction_id),
        "case_count": len(cases),
        "cases": cases,
        "local_revalidation": baseline["status"],
        "checked_term_occurrences_independently_validated": False,
        "semantic_context_bound": False,
        "evaluation_validated": False,
        "CoreSyntaxWF": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "protection_claim": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
