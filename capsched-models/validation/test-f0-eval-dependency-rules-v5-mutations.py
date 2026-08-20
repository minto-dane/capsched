#!/usr/bin/env python3
"""Hostile mutation campaign for the F0 v5 Eval/dependency rule table."""

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


evaluator = load_module("f0_eval_v5_rule_mutations", HERE / "f0_eval_v5.py")
rules = evaluator.rules_module
RULES_RAW = rules.read_once(rules.RULES_PATH)
GRAMMAR_RAW = rules.read_once(rules.GRAMMAR_PATH)
STATIC_RAW = rules.read_once(rules.STATIC_RULES_PATH)
NORMATIVE_RAW = {part: rules.read_once(path) for part, path in rules.NORMATIVE_PATHS.items()}
BASELINE = rules.parse_ascii_json(RULES_RAW, rules.RULES_PATH)


def check_raw(raw: bytes) -> None:
    contract = rules.validate_loaded(
        raw,
        GRAMMAR_RAW,
        STATIC_RAW,
        NORMATIVE_RAW,
        Path("mutated-eval-rules.json"),
        rules.GRAMMAR_PATH,
        rules.STATIC_RULES_PATH,
    )
    evaluator.bind_rule_contract(contract)


def expect_reject(case_id: str, raw: bytes, expected: str) -> dict[str, str]:
    try:
        check_raw(raw)
    except (rules.Reject, evaluator.EvalReject) as exc:
        reject_id = exc.reject_id
        if reject_id != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {reject_id}: {exc}")
        return {"id": case_id, "reject_id": reject_id}
    raise RuntimeError(f"{case_id}: unexpectedly accepted")


def mutate_case(
    case_id: str,
    mutate: Callable[[dict[str, Any]], None],
    expected: str = "F05-EVAL-RULE-IMPLEMENTATION-DRIFT",
) -> dict[str, str]:
    candidate = copy.deepcopy(BASELINE)
    mutate(candidate)
    return expect_reject(case_id, rules.canonical_bytes(candidate), expected)


def changed_list(value: list[str]) -> list[str]:
    if value:
        result = list(value)
        result[0] = result[0] + "_MUTATED"
        return result
    return ["MUTATED_OPERAND"]


def main() -> int:
    baseline_contract = rules.validate_loaded(
        RULES_RAW,
        GRAMMAR_RAW,
        STATIC_RAW,
        NORMATIVE_RAW,
    )
    evaluator.bind_rule_contract(baseline_contract)
    failures: list[dict[str, str]] = []

    for index, row in enumerate(BASELINE["evaluation_rules"]):
        tag = row["tag"]
        for field in ("eval_rule", "dependency_rule", "trace_rule"):
            failures.append(
                mutate_case(
                    f"eval-{index:02d}-{tag}-{field}",
                    lambda candidate, index=index, field=field: candidate["evaluation_rules"][index].__setitem__(
                        field, candidate["evaluation_rules"][index][field] + "_MUTATED"
                    ),
                )
            )
        for field in ("eval_operands", "may_operands"):
            failures.append(
                mutate_case(
                    f"eval-{index:02d}-{tag}-{field}",
                    lambda candidate, index=index, field=field: candidate["evaluation_rules"][index].__setitem__(
                        field, changed_list(candidate["evaluation_rules"][index][field])
                    ),
                )
            )
        failures.append(
            mutate_case(
                f"may-{index:02d}-{tag}",
                lambda candidate, tag=tag: candidate["may_dependency_rules"].__setitem__(
                    tag, candidate["may_dependency_rules"][tag] + "_MUTATED"
                ),
            )
        )
        failures.append(
            mutate_case(
                f"interpretation-ref-{index:02d}-{tag}",
                lambda candidate, tag=tag: candidate["evaluation_reference_rules"].__setitem__(
                    tag, candidate["evaluation_reference_rules"][tag] + "_MUTATED"
                ),
            )
        )

    for index, row in enumerate(BASELINE["carrier_rules"]):
        for field in ("denotation_rule", "equality_rule", "finite_enumeration_rule"):
            failures.append(
                mutate_case(
                    f"carrier-{index:02d}-{row['sort_tag']}-{field}",
                    lambda candidate, index=index, field=field: candidate["carrier_rules"][index].__setitem__(
                        field, candidate["carrier_rules"][index][field] + "_MUTATED"
                    ),
                )
            )
        failures.append(
            mutate_case(
                f"carrier-ref-{index:02d}-{row['sort_tag']}",
                lambda candidate, tag=row["sort_tag"]: candidate["carrier_reference_rules"].__setitem__(
                    tag, candidate["carrier_reference_rules"][tag] + "_MUTATED"
                ),
            )
        )

    for index, row in enumerate(BASELINE["ground_value_rules"]):
        for field in ("sort_rule", "decode_rule", "canonical_rule"):
            failures.append(
                mutate_case(
                    f"ground-{index:02d}-{row['value_tag']}-{field}",
                    lambda candidate, index=index, field=field: candidate["ground_value_rules"][index].__setitem__(
                        field, candidate["ground_value_rules"][index][field] + "_MUTATED"
                    ),
                )
            )

    failures.extend(
        [
            mutate_case(
                "delete-eval-row",
                lambda candidate: candidate["evaluation_rules"].pop(),
                "F05-ER-EVAL-DOMAIN",
            ),
            mutate_case(
                "duplicate-eval-row",
                lambda candidate: candidate["evaluation_rules"].append(
                    copy.deepcopy(candidate["evaluation_rules"][0])
                ),
                "F05-ER-EVAL-DUPLICATE",
            ),
            mutate_case(
                "delete-may-row",
                lambda candidate: candidate["may_dependency_rules"].pop("TERM_BOOL"),
                "F05-ER-MAY-DOMAIN",
            ),
            mutate_case(
                "delete-evaluation-reference-row",
                lambda candidate: candidate["evaluation_reference_rules"].pop("TERM_BOOL"),
                "F05-ER-EVAL-REF-DOMAIN",
            ),
            mutate_case(
                "delete-carrier-row",
                lambda candidate: candidate["carrier_rules"].pop(),
                "F05-ER-CARRIER-DOMAIN",
            ),
            mutate_case(
                "delete-carrier-reference-row",
                lambda candidate: candidate["carrier_reference_rules"].pop("SORT_BOOL"),
                "F05-ER-CARRIER-REF-DOMAIN",
            ),
            mutate_case(
                "delete-ground-row",
                lambda candidate: candidate["ground_value_rules"].pop(),
                "F05-ER-GROUND-DOMAIN",
            ),
            mutate_case(
                "authorization-self-promotion",
                lambda candidate: candidate["authorization"].__setitem__("F0_local_acceptance", True),
                "F05-ER-AUTHORIZATION",
            ),
            mutate_case(
                "normative-part-digest",
                lambda candidate: candidate["bindings"]["normative_part_sha256"].__setitem__(
                    "F05-00", "0" * 64
                ),
                "F05-ER-NORMATIVE-BINDING",
            ),
            mutate_case(
                "semantic-domain-authority",
                lambda candidate: candidate["semantic_domains"].__setitem__(
                    "reads_alias", "AUTHORITY_GRANT"
                ),
            ),
        ]
    )

    duplicate_raw = RULES_RAW.replace(
        b'{\n  "schema_version": 1,',
        b'{\n  "schema_version": 1,\n  "schema_version": 1,',
        1,
    )
    failures.append(expect_reject("duplicate-json-key", duplicate_raw, "F05-ER-DUPLICATE-KEY"))

    deep_raw = RULES_RAW.replace(
        b'"observation": "PAIR_CARRIER_VALUE_AND_DYNDEPS"',
        b'"observation": ' + b"[" * 520 + b'"x"' + b"]" * 520,
        1,
    )
    failures.append(expect_reject("over-depth", deep_raw, "F05-ER-DEPTH"))

    missing_normative = dict(NORMATIVE_RAW)
    missing_normative.pop("F05-00")
    try:
        rules.validate_loaded(
            RULES_RAW,
            GRAMMAR_RAW,
            STATIC_RAW,
            missing_normative,
        )
    except rules.Reject as exc:
        if exc.reject_id != "F05-ER-NORMATIVE-DOMAIN":
            raise RuntimeError(
                f"missing-normative-part: expected F05-ER-NORMATIVE-DOMAIN, got {exc.reject_id}"
            )
        failures.append({"id": "missing-normative-part", "reject_id": exc.reject_id})
    else:
        raise RuntimeError("missing-normative-part: unexpectedly accepted")

    output = {
        "schema_version": 1,
        "status": "construction_eval_dependency_rule_hostile_mutations_passed",
        "baseline_rule_canonical_sha256": baseline_contract.rules_canonical_sha256,
        "case_count": len(failures),
        "cases": failures,
        "local_mutation_campaign": True,
        "independent_review": False,
        "metatheory_proved": False,
        "evaluation_validated": False,
        "F0_local_acceptance": False,
        "protection_claim": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
