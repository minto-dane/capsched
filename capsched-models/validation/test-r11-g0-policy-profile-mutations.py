#!/usr/bin/env python3
"""Development-only hostile mutations for the R11 G0 policy/profile checker."""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
POLICY_ROOT = ROOT / "policy" / "r11"
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
    "claims": ROOT / "assurance" / "claims.json",
}


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def run_validator(overrides: dict[str, Path]) -> tuple[int, dict[str, Any]]:
    paths = BASE_PATHS | overrides
    command = [sys.executable, str(VALIDATOR)]
    for name, path in paths.items():
        command.extend((f"--{name.replace('_', '-')}", str(path)))
    completed = subprocess.run(command, capture_output=True, text=True, timeout=15, check=False)
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"validator returned non-JSON: {completed.stdout!r} {completed.stderr!r}") from exc
    return completed.returncode, payload


def mutate_unknown_field(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    mutant["candidate_selected_truth"] = True
    return canonical_bytes(mutant)


def mutate_duplicate_key(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    raw = canonical_bytes(policy)
    return raw.replace(b"{", b'{"schema_version":1,', 1)


def mutate_self_authorize(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    mutant["authorization"]["g0_complete"] = True
    return canonical_bytes(mutant)


def mutate_delete_resource(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    mutant["resource_algebra"]["components"] = mutant["resource_algebra"]["components"][:-1]
    return canonical_bytes(mutant)


def mutate_unknown_writer(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    mutant["provider_contracts"][0]["writer_role"] = "ROLE-UNKNOWN"
    return canonical_bytes(mutant)


def mutate_linux_authority(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    linux = next(row for row in mutant["trust_roles"] if row["id"] == "ROLE-LINUX")
    state = next(row for row in mutant["state_classes"] if row["id"] == "provider_immutable_receipt")
    linux["may_write_state_classes"].append("provider_immutable_receipt")
    state["allowed_writer_roles"].append("ROLE-LINUX")
    return canonical_bytes(mutant)


def mutate_provider_genesis(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    mutant["provider_contracts"][0]["receipt_initial"] = "Present"
    return canonical_bytes(mutant)


def mutate_oracle(policy: dict[str, Any], _: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(policy)
    row = next(
        item
        for item in mutant["mutation_oracle"]["g0_policy_profile_templates"]
        if item["id"] == "MUT-G0-ORACLE-FORGERY"
    )
    row["expected_reject"] = "HM-G0-CHECK-COVERAGE"
    return canonical_bytes(mutant)


def mutate_profile_collapse(_: dict[str, Any], profile: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(profile)
    row = next(item for item in mutant["profiles"] if item["id"] == "PROFILE-W12-PARTITION-CONNECTED-ONLY")
    row["dimensions"]["clusters"] = 1
    return canonical_bytes(mutant)


def mutate_profile_skip(_: dict[str, Any], profile: dict[str, Any]) -> bytes:
    mutant = copy.deepcopy(profile)
    row = next(item for item in mutant["profiles"] if item["id"] == "PROFILE-W8-REVOKE-OFFLINE")
    row["cutpoints"].remove("CUT-PRE-CONTEXT")
    return canonical_bytes(mutant)


CASES: list[tuple[str, str, str, Callable[[dict[str, Any], dict[str, Any]], bytes]]] = [
    ("MUT-G0-UNKNOWN-FIELD", "policy", "CAT-G0-SCHEMA", mutate_unknown_field),
    ("MUT-G0-DUPLICATE-KEY", "policy", "CAT-G0-DUPLICATE-KEY", mutate_duplicate_key),
    ("MUT-G0-SELF-AUTHORIZE", "policy", "CAT-G0-SELF-AUTHORIZATION", mutate_self_authorize),
    ("MUT-G0-DELETE-CATALOG-ITEM", "policy", "CAT-G0-RESOURCE-ALGEBRA", mutate_delete_resource),
    ("MUT-G0-REFERENCE-UNKNOWN", "policy", "CAT-G0-REFERENCE", mutate_unknown_writer),
    ("MUT-G0-LINUX-AUTHORITY", "policy", "CAT-G0-TRUST", mutate_linux_authority),
    ("MUT-G0-PROVIDER-GENESIS", "policy", "CAT-G0-PROVIDER", mutate_provider_genesis),
    ("MUT-G0-PROFILE-COLLAPSE", "profile", "CAT-G0-PROFILE", mutate_profile_collapse),
    ("MUT-G0-PROFILE-SKIP", "profile", "CAT-G0-PROFILE-COVERAGE", mutate_profile_skip),
    ("MUT-G0-ORACLE-FORGERY", "policy", "HM-G0-ORACLE-DIGEST", mutate_oracle),
]


def main() -> int:
    policy = json.loads(BASE_PATHS["policy"].read_text())
    profile = json.loads(BASE_PATHS["profile"].read_text())
    baseline_code, baseline = run_validator({})
    if baseline_code != 0 or baseline.get("status") != "passed":
        raise RuntimeError(f"baseline failed: {baseline}")

    results: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="r11-g0-hostile-") as directory:
        temp_root = Path(directory)
        for ordinal, (case_id, target, expected, mutate) in enumerate(CASES):
            raw = mutate(policy, profile)
            path = temp_root / f"input-{ordinal:02d}.json"
            path.write_bytes(raw)
            code, payload = run_validator({target: path})
            actual = payload.get("reject_id")
            if code != 1 or payload.get("status") != "rejected" or actual != expected:
                raise RuntimeError(
                    f"{case_id}: expected {expected}, got code={code} payload={payload}"
                )
            results.append(
                {
                    "case_id": case_id,
                    "target": target,
                    "expected_reject": expected,
                    "actual_reject": actual,
                    "mutant_sha256": digest(raw),
                }
            )

    output = {
        "schema_version": 1,
        "authority": "development_mutation_regression_only",
        "status": "passed",
        "g0_complete": False,
        "executed_cases": len(results),
        "deferred_external_cases": ["MUT-G0-CHECKER-SKIP", "MUT-G0-STALE-REVIEW"],
        "validator_sha256": digest(VALIDATOR.read_bytes()),
        "baseline_input_sha256": {name: digest(path.read_bytes()) for name, path in BASE_PATHS.items()},
        "results": results,
        "nonclaims": [
            "The runner, validator, expectations, and inputs share one local change authority.",
            "This run does not authenticate an external reviewer, runtime, or promotion decision.",
            "Future candidate-IR mutation templates are not executable before R11 IR exists."
        ],
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
