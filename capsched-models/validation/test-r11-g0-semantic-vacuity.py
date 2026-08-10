#!/usr/bin/env python3
"""Reproduce semantic-vacuity counterexamples accepted by the R11 G0 checker."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


MODEL_ROOT = Path(__file__).resolve().parents[1]
POLICY_ROOT = MODEL_ROOT / "policy" / "r11"
VALIDATOR = Path(__file__).with_name("validate-r11-g0-policy-profile.py")
BASE_PATHS = {
    "policy_schema": POLICY_ROOT / "semantic-policy-schema-v1.json",
    "policy": POLICY_ROOT / "semantic-policy-v1.json",
    "registry_schema": POLICY_ROOT / "semantic-rule-registry-schema-v1.json",
    "registry": POLICY_ROOT / "semantic-rule-registry-v1.json",
    "profile_schema": POLICY_ROOT / "scenario-profile-schema-v1.json",
    "profile": POLICY_ROOT / "scenario-profile-v1.json",
    "review_contract_schema": POLICY_ROOT / "g0-review-contract-schema-v1.json",
    "review_contract": POLICY_ROOT / "g0-review-contract-v1.json",
    "claims": MODEL_ROOT / "assurance" / "claims.json",
}
DocumentSet = dict[str, Any]
Mutator = Callable[[DocumentSet], set[str]]


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def load_documents() -> DocumentSet:
    return {
        role: json.loads(path.read_text(encoding="utf-8"))
        for role, path in BASE_PATHS.items()
        if path.suffix == ".json"
    }


def run_validator(overrides: dict[str, Path]) -> tuple[int, dict[str, Any]]:
    paths = BASE_PATHS | overrides
    command = [sys.executable, str(VALIDATOR)]
    for role, path in paths.items():
        command.extend((f"--{role.replace('_', '-')}", str(path)))
    completed = subprocess.run(
        command,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if completed.stderr:
        raise RuntimeError(f"validator wrote stderr: {completed.stderr}")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"validator returned non-JSON: {completed.stdout!r}") from exc
    return completed.returncode, payload


def genericize_registry(documents: DocumentSet) -> set[str]:
    rules = documents["registry"]["rules"]
    for index, rule in enumerate(rules, start=1):
        rule["applies_to"] = ["OpaqueObject"]
        rule["typed_parameters"] = ["OpaqueParameter"]
        rule["canonical_template"] = f"opaque_template_{index:03d}"
        rule["policy_pointers"] = ["/project"]
        rule["candidate_binding_schema"] = f"BIND-OPAQUE-{index:03d}"
        rule["generated_obligation_ids"] = ["INV-WELL-FORMED-BOUNDED"]
        rule["required_witnesses"] = ["W0"]
        rule["required_mutation_ids"] = ["MUT-POL-TRUE-INVARIANT"]
        rule["claim_ids"] = ["RESIDENCY-DYN-001"]
    return {"registry"}


def opaque_provider_contracts(documents: DocumentSet) -> set[str]:
    for provider in documents["policy"]["provider_contracts"]:
        provider["trigger"] = "x"
        provider["prestate"] = "x"
        provider["success_relation"] = "x"
        provider["fault_partition"] = "x"
        provider["failure_successor"] = "OpaqueSuccessor"
        provider["bound_class"] = "OpaqueBound"
        provider["fairness_class"] = "OpaqueFairness"
    return {"policy"}


def vacuous_progress_strings(documents: DocumentSet) -> set[str]:
    for progress in documents["policy"]["progress_obligations"]:
        progress["rely"] = "false"
        progress["success"] = "true"
    return {"policy"}


def arbitrary_unit_and_axis(documents: DocumentSet) -> set[str]:
    policy = documents["policy"]
    policy["resource_algebra"]["components"][0]["unit"] = "bananas"
    policy["consistency_domains"][0]["axes"].append("UncataloguedAxis")
    return {"policy"}


def zero_checker_unread_dimensions(documents: DocumentSet) -> set[str]:
    keys = {
        "domain_granularity_kinds",
        "subjects",
        "programs",
        "budget_contexts",
        "root_frames",
        "entry_bindings",
        "audit_slots",
    }
    for profile in documents["profile"]["profiles"]:
        for key in keys:
            profile["dimensions"][key] = 0
    return {"profile"}


def rename_actions_and_outcomes(documents: DocumentSet) -> set[str]:
    profile = documents["profile"]
    action_map = {
        old: f"ACTION-OPAQUE-{index:03d}"
        for index, old in enumerate(profile["action_class_catalog"])
    }
    outcome_map = {
        old: f"OUT-OPAQUE-{index:03d}"
        for index, old in enumerate(profile["outcome_catalog"])
    }
    profile["action_class_catalog"] = [
        action_map[value] for value in profile["action_class_catalog"]
    ]
    for row in profile["profile_action_contract"]:
        row["actions"] = [action_map[value] for value in row["actions"]]
    profile["outcome_catalog"] = [
        outcome_map[value] for value in profile["outcome_catalog"]
    ]
    for row in profile["profiles"]:
        row["outcomes"] = [outcome_map[value] for value in row["outcomes"]]
    profile["suite_coverage"]["required_outcomes"] = [
        outcome_map[value]
        for value in profile["suite_coverage"]["required_outcomes"]
    ]
    return {"profile"}


def swap_witness_labels(documents: DocumentSet) -> set[str]:
    profiles = documents["profile"]["profiles"]
    w0 = next(row for row in profiles if row["id"] == "PROFILE-W0-BOOTSTRAP")
    w9 = next(row for row in profiles if row["id"] == "PROFILE-W9-TWO-LANE")
    w0["witness"], w9["witness"] = w9["witness"], w0["witness"]
    return {"profile"}


def opaque_relation_meanings(documents: DocumentSet) -> set[str]:
    for relation in documents["profile"]["relation_catalog"]:
        relation["meaning"] = "x"
    return {"profile"}


def opaque_cut_generation_policy(documents: DocumentSet) -> set[str]:
    policy = documents["profile"]["cut_generation_policy"]
    policy["required_generated_cuts"] = [
        f"opaque_cut_{index}" for index in range(5)
    ]
    policy["second_crash_required_for"] = ["opaque_second_0", "opaque_second_1"]
    policy["offline_and_revoke_entry_cuts"] = [
        f"opaque_offline_{index}" for index in range(7)
    ]
    policy["acceptance"] = "x"
    return {"profile"}


def forge_profile_weakening_oracle(documents: DocumentSet) -> set[str]:
    for index, row in enumerate(
        documents["profile"]["forbidden_profile_weakening"], start=1
    ):
        row["id"] = f"MUT-PROFILE-OPAQUE-{index:03d}"
        row["expected_reject"] = f"CAT-PROFILE-OPAQUE-{index:03d}"
    return {"profile"}


def collapse_rule_claim_mapping(documents: DocumentSet) -> set[str]:
    for rule in documents["registry"]["rules"]:
        rule["claim_ids"] = ["RESIDENCY-DYN-001"]
    return {"registry"}


def rotate_profile_action_assignments(documents: DocumentSet) -> set[str]:
    rows = documents["profile"]["profile_action_contract"]
    actions = [copy.deepcopy(row["actions"]) for row in rows]
    for index, row in enumerate(rows):
        row["actions"] = actions[(index + 1) % len(actions)]
    return {"profile"}


CASES: list[tuple[str, Mutator]] = [
    ("VAC-R11-UNDEFINED-BINDING-TEMPLATES", genericize_registry),
    ("VAC-R11-OPAQUE-PROVIDER-CONTRACTS", opaque_provider_contracts),
    ("VAC-R11-VACUOUS-PROGRESS-STRINGS", vacuous_progress_strings),
    ("VAC-R11-ARBITRARY-UNIT-AND-CD-AXIS", arbitrary_unit_and_axis),
    ("VAC-R11-ZERO-UNREAD-PROFILE-DIMENSIONS", zero_checker_unread_dimensions),
    ("VAC-R11-RENAME-ACTIONS-AND-OUTCOMES", rename_actions_and_outcomes),
    ("VAC-R11-SWAP-WITNESS-LABELS", swap_witness_labels),
    ("VAC-R11-OPAQUE-RELATION-MEANINGS", opaque_relation_meanings),
    ("VAC-R11-OPAQUE-CUT-GENERATION", opaque_cut_generation_policy),
    ("VAC-R11-FORGE-PROFILE-WEAKENING-ORACLE", forge_profile_weakening_oracle),
    ("VAC-R11-COLLAPSE-RULE-CLAIM-MAPPING", collapse_rule_claim_mapping),
    ("VAC-R11-ROTATE-PROFILE-ACTION-MAPPING", rotate_profile_action_assignments),
]


def main() -> int:
    baseline_code, baseline = run_validator({})
    if baseline_code != 0 or baseline.get("status") != "passed":
        raise RuntimeError(f"baseline failed: {baseline}")

    results: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="r11-g0-vacuity-") as directory:
        root = Path(directory)
        for ordinal, (case_id, mutator) in enumerate(CASES):
            documents = load_documents()
            changed_roles = mutator(documents)
            overrides: dict[str, Path] = {}
            mutant_sha256: dict[str, str] = {}
            for role in sorted(changed_roles):
                raw = canonical_bytes(documents[role])
                path = root / f"{ordinal:02d}-{role}.json"
                path.write_bytes(raw)
                overrides[role] = path
                mutant_sha256[role] = sha256(raw)
            code, payload = run_validator(overrides)
            if code != 0 or payload.get("status") != "passed":
                raise RuntimeError(
                    f"{case_id}: expected accepted counterexample, "
                    f"got code={code} payload={payload}"
                )
            results.append(
                {
                    "case_id": case_id,
                    "changed_roles": sorted(changed_roles),
                    "mutant_sha256": mutant_sha256,
                    "checker_status": "accepted",
                }
            )

    output = {
        "schema_version": 1,
        "authority": "negative_semantic_counterexample_only",
        "status": "passed",
        "baseline_validator_sha256": sha256(VALIDATOR.read_bytes()),
        "accepted_counterexamples": len(results),
        "g0_complete": False,
        "r11_machine_source_construction": False,
        "semantic_freeze": False,
        "tla_translation": False,
        "model_supported": False,
        "results": results,
        "disposition": "reject_exact_R11_G0_candidate_before_external_review",
        "nonclaims": [
            "Acceptance means the checker failed to reject a semantic weakening.",
            "These counterexamples do not define the successor semantic policy.",
            "No external review, formal proof, TLA translation, Linux change, or protection claim is authorized.",
        ],
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
