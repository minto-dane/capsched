#!/usr/bin/env python3
"""Validate and implementation-bind the DL-F0-5 Eval/dependency rule table."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


rules = load_module("f0_eval_rules_v5_cli", HERE / "f0_eval_rules_v5.py")
evaluator = load_module("f0_eval_v5_cli", HERE / "f0_eval_v5.py")


def validate() -> dict[str, object]:
    contract = evaluator.rules_module.load_contract()
    evaluator.bind_rule_contract(contract)
    result = rules.result(contract)
    result.update(
        {
            "status": "construction_eval_dependency_rule_table_and_local_implementation_binding_passed",
            "authority": "local_construction_implementation_binding_only",
            "rule_table_digest_bound": True,
            "implementation_handler_domains_bound": True,
            "implementation_semantics_parity_proved": False,
            "implementation_expected_canonical_sha256": evaluator.EXPECTED_RULE_CANONICAL_SHA256,
            "handler_domain_count": len(evaluator.EXPECTED_TERM_TAGS),
            "metatheory_proved": False,
            "finite_refinement_proved": False,
            "evaluation_validated": False,
            "F0_local_acceptance": False,
            "protection_claim": False,
        }
    )
    return result


def main() -> int:
    print(json.dumps(validate(), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (rules.Reject, evaluator.RuleReject, evaluator.EvalReject) as exc:
        reject_id = getattr(exc, "reject_id", "F05-EVAL-RULE-REJECT")
        detail = getattr(exc, "detail", str(exc))
        print(
            json.dumps(
                {
                    "status": "rejected",
                    "reject_id": reject_id,
                    "detail": detail,
                    "F0_local_acceptance": False,
                    "protection_claim": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
