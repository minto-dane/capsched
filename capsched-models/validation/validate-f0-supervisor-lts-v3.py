#!/usr/bin/env python3
"""Validate supervisor v3 candidate-4 without granting F0, R11, or G0 credit."""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
from dataclasses import asdict
from hashlib import sha256
from pathlib import Path
from types import ModuleType

if sys.flags.optimize != 0 or not __debug__:
    raise RuntimeError("candidate-4 validation rejects optimized Python")

HERE = Path(__file__).resolve().parent
INPUT_FILES = (
    "f0-supervisor-c4-claim-registry-v1.json",
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "test-run-f0-supervisor-v3-full.sh",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
)
MODEL_SOURCE_FILES = (
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
)


def file_hash(path: Path) -> str:
    hasher = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def input_hashes() -> dict[str, str]:
    return {name: file_hash(HERE / name) for name in INPUT_FILES}


def capture_input_bytes() -> dict[str, bytes]:
    return {name: (HERE / name).read_bytes() for name in INPUT_FILES}


BOOTSTRAP_INPUT_BYTES = capture_input_bytes()
BOOTSTRAP_INPUT_HASHES = {
    name: sha256(content).hexdigest()
    for name, content in BOOTSTRAP_INPUT_BYTES.items()
}


def input_root(input_map: dict[str, str]) -> str:
    encoded = json.dumps(
        input_map,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return sha256(encoded).hexdigest()


BOOTSTRAP_INPUT_ROOT = input_root(BOOTSTRAP_INPUT_HASHES)


def load_hashed_source_module(name: str, filename: str) -> tuple[ModuleType, str]:
    path = HERE / filename
    source = BOOTSTRAP_INPUT_BYTES[filename]
    source_hash = sha256(source).hexdigest()
    if source_hash != BOOTSTRAP_INPUT_HASHES[filename]:
        raise RuntimeError(f"model source changed before compilation: {filename}")
    module = ModuleType(name)
    module.__file__ = str(path)
    module.__package__ = ""
    sys.modules[name] = module
    try:
        code = compile(source, str(path), "exec", dont_inherit=True)
        exec(code, module.__dict__)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module, source_hash


child, CHILD_EXECUTED_SOURCE_SHA256 = load_hashed_source_module(
    "f0_supervisor_lts_v3",
    "f0_supervisor_lts_v3.py",
)
orchestrator, ORCHESTRATOR_EXECUTED_SOURCE_SHA256 = load_hashed_source_module(
    "f0_supervisor_orchestrator_v3",
    "f0_supervisor_orchestrator_v3.py",
)
POST_MODEL_LOAD_INPUT_HASHES = input_hashes()
if POST_MODEL_LOAD_INPUT_HASHES != BOOTSTRAP_INPUT_HASHES:
    raise RuntimeError("candidate-4 inputs changed while model sources loaded")

CLAIM_STATUSES = {"PASS", "FAIL", "NOT_RUN", "INCOMPLETE", "OPEN_REFINEMENT"}
CLAIM_REGISTRY_PATH = HERE / "f0-supervisor-c4-claim-registry-v1.json"


def reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_nonfinite_constant(value: str) -> object:
    raise ValueError(f"non-standard JSON constant: {value}")


CLAIM_REGISTRY = json.loads(
    BOOTSTRAP_INPUT_BYTES[
        "f0-supervisor-c4-claim-registry-v1.json"
    ].decode("utf-8"),
    object_pairs_hook=reject_duplicate_keys,
    parse_constant=reject_nonfinite_constant,
)
if set(CLAIM_REGISTRY) != {
    "schema_version",
    "artifact_id",
    "authority",
    "claims",
    "authorization",
}:
    raise RuntimeError("candidate-4 claim registry top-level fields are not exact")
if (
    CLAIM_REGISTRY["schema_version"] != 1
    or CLAIM_REGISTRY["artifact_id"]
    != "dynamic-residency-f0-v5-supervisor-v3-candidate4-claim-registry"
    or CLAIM_REGISTRY["authority"]
    != "repository_claim_catalog_not_candidate_result"
):
    raise RuntimeError("candidate-4 claim registry identity mismatch")
if set(CLAIM_REGISTRY["authorization"]) != {
    "F0_local_acceptance",
    "external_R11_review",
    "G0_authorized",
    "self_authorization",
    "protection_claim",
} or any(CLAIM_REGISTRY["authorization"].values()):
    raise RuntimeError("candidate-4 claim registry grants forbidden authority")

CLAIM_REGISTRY_BY_ID: dict[str, dict[str, object]] = {}
for row in CLAIM_REGISTRY["claims"]:
    if set(row) != {"id", "class", "fast", "full"}:
        raise RuntimeError("candidate-4 claim registry row fields are not exact")
    claim_id = row["id"]
    if not isinstance(claim_id, str) or not claim_id or claim_id in CLAIM_REGISTRY_BY_ID:
        raise RuntimeError("candidate-4 claim registry ID is invalid or duplicated")
    if not isinstance(row["class"], str) or not row["class"]:
        raise RuntimeError(f"candidate-4 claim class is invalid: {claim_id}")
    for mode in ("fast", "full"):
        mode_spec = row[mode]
        if set(mode_spec) != {"allowed_statuses", "evidence", "status_rule"}:
            raise RuntimeError(f"candidate-4 claim mode fields differ: {claim_id}:{mode}")
        statuses = mode_spec["allowed_statuses"]
        evidence = mode_spec["evidence"]
        if (
            not isinstance(statuses, list)
            or not statuses
            or len(statuses) != len(set(statuses))
            or not set(statuses) <= CLAIM_STATUSES
            or not isinstance(evidence, list)
            or len(evidence) != len(set(evidence))
            or not all(isinstance(item, str) and item for item in evidence)
        ):
            raise RuntimeError(f"candidate-4 claim mode is invalid: {claim_id}:{mode}")
        rule = mode_spec["status_rule"]
        if not isinstance(rule, dict) or rule.get("kind") not in {
            "boolean",
            "fixed",
        }:
            raise RuntimeError(f"candidate-4 claim rule is invalid: {claim_id}:{mode}")
        if rule["kind"] == "fixed":
            if set(rule) != {"kind", "status"} or statuses != [rule["status"]]:
                raise RuntimeError(
                    f"candidate-4 fixed claim rule differs: {claim_id}:{mode}"
                )
        elif (
            set(rule)
            != {"kind", "predicate_id", "true_status", "false_status"}
            or not isinstance(rule["predicate_id"], str)
            or not rule["predicate_id"]
            or set(statuses) != {rule["true_status"], rule["false_status"]}
            or rule["true_status"] == rule["false_status"]
        ):
            raise RuntimeError(
                f"candidate-4 Boolean claim rule differs: {claim_id}:{mode}"
            )
    CLAIM_REGISTRY_BY_ID[claim_id] = row

CLAIM_IDS = frozenset(CLAIM_REGISTRY_BY_ID)
if len(CLAIM_IDS) != 11:
    raise RuntimeError("candidate-4 claim registry cardinality differs")
CLAIM_PREDICATE_IDS = {
    mode_spec["status_rule"]["predicate_id"]
    for row in CLAIM_REGISTRY_BY_ID.values()
    for mode_spec in (row["fast"], row["full"])
    if mode_spec["status_rule"]["kind"] == "boolean"
}
if CLAIM_PREDICATE_IDS != {
    "FAST_MUTATION_STATIC",
    "CHILD_EXACT_FIXTURE_BOUNDED",
    "PARENT_EXACT_REPETITION_BOUNDED",
    "DECLARED_LOCAL_EFFECT_COMMUTATION",
}:
    raise RuntimeError("candidate-4 claim predicate registry differs")
CLAIM_REGISTRY_SHA256 = BOOTSTRAP_INPUT_HASHES[
    "f0-supervisor-c4-claim-registry-v1.json"
]


def validate_emitted_claims(
    claims: dict[str, dict[str, object]],
    mode: str,
    predicates: dict[str, bool],
) -> None:
    if set(claims) != CLAIM_IDS:
        raise RuntimeError(f"{mode} candidate-4 claim registry is not exact")
    for claim_id, claim in claims.items():
        if set(claim) != {"status", "evidence"}:
            raise RuntimeError(f"claim fields are not exact: {claim_id}")
        specification = CLAIM_REGISTRY_BY_ID[claim_id][mode]
        if claim["status"] not in specification["allowed_statuses"]:
            raise RuntimeError(f"claim status violates registry: {claim_id}:{mode}")
        if claim["evidence"] != specification["evidence"]:
            raise RuntimeError(f"claim evidence violates registry: {claim_id}:{mode}")
        rule = specification["status_rule"]
        if rule["kind"] == "fixed":
            expected_status = rule["status"]
        else:
            predicate_id = rule["predicate_id"]
            if predicate_id not in predicates:
                raise RuntimeError(
                    f"claim predicate is unavailable: {claim_id}:{mode}"
                )
            expected_status = (
                rule["true_status"]
                if predicates[predicate_id]
                else rule["false_status"]
            )
        if claim["status"] != expected_status:
            raise RuntimeError(f"claim predicate differs: {claim_id}:{mode}")


def claim_status(status: str, evidence: list[str]) -> dict[str, object]:
    if status not in CLAIM_STATUSES:
        raise ValueError(status)
    return {"status": status, "evidence": evidence}


def validate_claim_evidence_references(result: dict[str, object]) -> None:
    obligations = result["open_refinement_obligations"]
    indexed: dict[str, frozenset[str]] = {}
    for role in ("child", "orchestrator"):
        rows = obligations[role]
        identifiers = [row.split(" ", 1)[0] for row in rows]
        if (
            any(not identifier or " " in identifier for identifier in identifiers)
            or len(identifiers) != len(set(identifiers))
        ):
            raise RuntimeError(f"open obligation IDs are invalid: {role}")
        indexed[f"open_refinement_obligations.{role}"] = frozenset(identifiers)

    for claim_id, claim in result["claims"].items():
        if claim["status"] != "OPEN_REFINEMENT":
            continue
        evidence = claim["evidence"]
        if not evidence:
            raise RuntimeError(f"open claim lacks evidence references: {claim_id}")
        for reference in evidence:
            if reference == "authorization.F0_local_acceptance=false":
                if result["authorization"]["F0_local_acceptance"] is not False:
                    raise RuntimeError(
                        f"open claim false authorization differs: {claim_id}"
                    )
                continue
            path, separator, obligation_id = reference.partition("#")
            if (
                separator != "#"
                or path not in indexed
                or obligation_id not in indexed[path]
            ):
                raise RuntimeError(
                    f"open claim obligation reference is unresolved: "
                    f"{claim_id}:{reference}"
                )


def run_test(path: Path) -> dict[str, object]:
    environment = {
        "PATH": "/usr/bin:/bin",
        "PYTHONPATH": str(HERE),
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONHASHSEED": "0",
    }
    command = (
        ["bash", str(path)]
        if path.suffix == ".sh"
        else [sys.executable, "-S", "-B", str(path)]
    )
    completed = subprocess.run(
        command,
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    expected_prefix = {
        "test-f0-supervisor-lts-v3-mutations.py": (
            "LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases="
        ),
        "test-f0-supervisor-orchestrator-v3-mutations.py": (
            "LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases="
        ),
        "test-run-f0-supervisor-v3-full.sh": (
            "LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases="
        ),
    }[path.name]
    stdout_lines = completed.stdout.strip().splitlines()
    marker_exact = bool(
        len(stdout_lines) == 1
        and stdout_lines[0].startswith(expected_prefix)
        and stdout_lines[0][len(expected_prefix) :].isdigit()
        and int(stdout_lines[0][len(expected_prefix) :]) > 0
    )
    return {
        "path": path.name,
        "returncode": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
        "expected_prefix": expected_prefix,
        "exact_success_marker": marker_exact,
        "passed": completed.returncode == 0 and marker_exact,
    }


def worker_provenance(
    before: dict[str, str],
    after: dict[str, str],
) -> dict[str, object]:
    bootstrap_integrity = bool(
        BOOTSTRAP_INPUT_HASHES == POST_MODEL_LOAD_INPUT_HASHES == before == after
        and CHILD_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_lts_v3.py"]
        and ORCHESTRATOR_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_orchestrator_v3.py"]
    )
    return {
        "bootstrap_input_hashes": BOOTSTRAP_INPUT_HASHES,
        "post_model_load_input_hashes": POST_MODEL_LOAD_INPUT_HASHES,
        "input_hashes_before": before,
        "input_hashes_after": after,
        "input_root_sha256": BOOTSTRAP_INPUT_ROOT,
        "executed_model_source_hashes": {
            "f0_supervisor_lts_v3.py": CHILD_EXECUTED_SOURCE_SHA256,
            "f0_supervisor_orchestrator_v3.py": (
                ORCHESTRATOR_EXECUTED_SOURCE_SHA256
            ),
        },
        "bootstrap_source_execution_check": bootstrap_integrity,
        "runtime_input_write_prevention_enforced": False,
        "input_stability_during_execution_proved": False,
    }


def worker_provenance_ok(provenance: object) -> bool:
    if not isinstance(provenance, dict) or set(provenance) != {
        "bootstrap_input_hashes",
        "post_model_load_input_hashes",
        "input_hashes_before",
        "input_hashes_after",
        "input_root_sha256",
        "executed_model_source_hashes",
        "bootstrap_source_execution_check",
        "runtime_input_write_prevention_enforced",
        "input_stability_during_execution_proved",
    }:
        return False
    hashes = (
        provenance["bootstrap_input_hashes"],
        provenance["post_model_load_input_hashes"],
        provenance["input_hashes_before"],
        provenance["input_hashes_after"],
    )
    return bool(
        all(item == BOOTSTRAP_INPUT_HASHES for item in hashes)
        and provenance["input_root_sha256"] == BOOTSTRAP_INPUT_ROOT
        and provenance["executed_model_source_hashes"]
        == {
            "f0_supervisor_lts_v3.py": CHILD_EXECUTED_SOURCE_SHA256,
            "f0_supervisor_orchestrator_v3.py": (
                ORCHESTRATOR_EXECUTED_SOURCE_SHA256
            ),
        }
        and provenance["bootstrap_source_execution_check"] is True
        and provenance["runtime_input_write_prevention_enforced"] is False
        and provenance["input_stability_during_execution_proved"] is False
    )


def static_registry_result() -> dict[str, object]:
    child_actions = set(child.ACTION_SPECS)
    child_writes = set(child.ACTION_WRITE_FIELDS)
    child_required_writes = set(child.ACTION_REQUIRED_WRITE_FIELDS)
    orchestrator_actions = set(orchestrator.ACTION_SPECS)
    orchestrator_writes = set(orchestrator.ACTION_WRITE_FIELDS)
    orchestrator_required_writes = set(
        orchestrator.ACTION_REQUIRED_WRITE_FIELDS
    )
    independence_ids = [
        spec.independence_id for spec in child.INDEPENDENCE_SPECS
    ]
    registry_material = {
        "child_actions": {
            action_id: {
                "actors": sorted(spec.actors),
                "category": spec.category,
                "write_fields": sorted(child.ACTION_WRITE_FIELDS[action_id]),
                "required_write_fields": sorted(
                    child.ACTION_REQUIRED_WRITE_FIELDS[action_id]
                ),
            }
            for action_id, spec in sorted(child.ACTION_SPECS.items())
        },
        "orchestrator_actions": {
            action_id: {
                "actors": sorted(spec.actors),
                "relation": spec.relation,
                "write_fields": sorted(orchestrator.ACTION_WRITE_FIELDS[action_id]),
                "required_write_fields": sorted(
                    orchestrator.ACTION_REQUIRED_WRITE_FIELDS[action_id]
                ),
            }
            for action_id, spec in sorted(orchestrator.ACTION_SPECS.items())
        },
        "typed_store_attacks": {
            attack: {
                "action_id": spec.action_id,
                "breach": spec.breach,
            }
            for attack, spec in sorted(
                orchestrator.STORE_ATTACK_SPECS.items()
            )
        },
        "declared_independence": [
            {
                "independence_id": spec.independence_id,
                "left_action": spec.left_action,
                "right_action": spec.right_action,
                "roles": sorted(spec.roles),
                "source_predicate_id": spec.source_predicate_id,
                "minimum_source_count": spec.minimum_source_count,
                "expected_history_relation": spec.expected_history_relation,
            }
            for spec in child.INDEPENDENCE_SPECS
        ],
    }
    registry_digest = sha256(
        json.dumps(
            registry_material,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    passed = bool(
        child_actions == child_writes
        and child_actions == child_required_writes
        and all(
            child.ACTION_REQUIRED_WRITE_FIELDS[action_id]
            <= child.ACTION_WRITE_FIELDS[action_id]
            for action_id in child_actions
        )
        and orchestrator_actions == orchestrator_writes
        and orchestrator_actions == orchestrator_required_writes
        and all(
            orchestrator.ACTION_REQUIRED_WRITE_FIELDS[action_id]
            <= orchestrator.ACTION_WRITE_FIELDS[action_id]
            for action_id in orchestrator_actions
        )
        and len(independence_ids) == len(set(independence_ids))
        and independence_ids
        and set(orchestrator.STORE_ATTACK_SPECS)
        == orchestrator.PENDING_ATTACKS - {"NONE"}
        and {
            spec.action_id
            for spec in orchestrator.STORE_ATTACK_SPECS.values()
        }
        <= orchestrator_actions
    )
    return {
        "component": "static-registries",
        "claim_registry": {
            "artifact_id": CLAIM_REGISTRY["artifact_id"],
            "claim_count": len(CLAIM_IDS),
            "sha256": CLAIM_REGISTRY_SHA256,
            "candidate_authority_all_false": not any(
                CLAIM_REGISTRY["authorization"].values()
            ),
        },
        "child": {
            "declared_action_count": len(child_actions),
            "write_policy_count": len(child_writes),
            "write_policy_exact_registry_coverage": child_actions == child_writes,
            "required_write_policy_count": len(child_required_writes),
            "required_write_policy_exact_registry_coverage": (
                child_actions == child_required_writes
            ),
            "required_writes_are_allowed": all(
                child.ACTION_REQUIRED_WRITE_FIELDS[action_id]
                <= child.ACTION_WRITE_FIELDS[action_id]
                for action_id in child_actions
            ),
        },
        "orchestrator": {
            "declared_action_count": len(orchestrator_actions),
            "write_policy_count": len(orchestrator_writes),
            "write_policy_exact_registry_coverage": (
                orchestrator_actions == orchestrator_writes
            ),
            "required_write_policy_count": len(orchestrator_required_writes),
            "required_write_policy_exact_registry_coverage": (
                orchestrator_actions == orchestrator_required_writes
            ),
            "required_writes_are_allowed": all(
                orchestrator.ACTION_REQUIRED_WRITE_FIELDS[action_id]
                <= orchestrator.ACTION_WRITE_FIELDS[action_id]
                for action_id in orchestrator_actions
            ),
        },
        "declared_independence_ids": independence_ids,
        "declared_independence_ids_unique": (
            len(independence_ids) == len(set(independence_ids))
        ),
        "semantic_registry_sha256": registry_digest,
        "typed_store_attack_registry_exact": bool(
            set(orchestrator.STORE_ATTACK_SPECS)
            == orchestrator.PENDING_ATTACKS - {"NONE"}
            and {
                spec.action_id
                for spec in orchestrator.STORE_ATTACK_SPECS.values()
            }
            <= orchestrator_actions
        ),
        "reachability_checked": False,
        "passed": passed,
    }


def component_result(component: str) -> dict[str, object]:
    if component == "static-registries":
        return static_registry_result()
    if component == "tests":
        tests = [
            run_test(HERE / "test-f0-supervisor-lts-v3-mutations.py"),
            run_test(HERE / "test-f0-supervisor-orchestrator-v3-mutations.py"),
            run_test(HERE / "test-run-f0-supervisor-v3-full.sh"),
        ]
        return {
            "component": component,
            "tests": tests,
            "passed": all(test["passed"] for test in tests),
        }
    if component in {"child-bundle-producer", "child-bundle-checker"}:
        role = "PRODUCER" if component.endswith("producer") else "CHECKER"
        graph = child.reachable_states(child.fixture_external_grant(role))
        return {
            "component": component,
            "role": role,
            "exploration": asdict(child.explore(role, graph)),
            "commutation": child.check_outcome_commutation(role, graph[0]),
            "single_graph_reused": True,
        }
    if component == "orchestrator":
        return {"component": component, "result": orchestrator.explore()}
    raise ValueError(component)


def invoke_component(
    component: str,
) -> tuple[dict[str, object], dict[str, object]]:
    environment = {
        "PATH": "/usr/bin:/bin",
        "PYTHONPATH": str(HERE),
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONHASHSEED": "0",
    }
    command = [
        sys.executable,
        "-S",
        "-B",
        str(Path(__file__).resolve()),
        "--component",
        component,
    ]
    completed = subprocess.run(
        command,
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"component {component} failed rc={completed.returncode}: "
            f"{completed.stderr.decode('utf-8', errors='replace').strip()}"
        )
    if completed.stderr:
        raise RuntimeError(
            f"component {component} produced unexpected stderr: "
            f"{completed.stderr.decode('utf-8', errors='replace').strip()}"
        )
    marker = b"RESULT_JSON="
    stdout_lines = completed.stdout.splitlines()
    if len(stdout_lines) != 1 or not stdout_lines[0].startswith(marker):
        raise RuntimeError(
            f"component {component} returned no exact unique JSON result"
        )
    result_payload = stdout_lines[0][len(marker) :]
    result = json.loads(
        result_payload.decode("utf-8"),
        object_pairs_hook=reject_duplicate_keys,
        parse_constant=reject_nonfinite_constant,
    )
    if result.get("component") != component:
        raise RuntimeError(f"component identity mismatch: {component}")
    if not worker_provenance_ok(result.get("worker_provenance")):
        raise RuntimeError(f"component worker provenance mismatch: {component}")
    if component == "child-bundle-producer" and result.get("role") != "PRODUCER":
        raise RuntimeError("producer component role mismatch")
    if component == "child-bundle-checker" and result.get("role") != "CHECKER":
        raise RuntimeError("checker component role mismatch")
    if component == "tests" and result.get("passed") not in {True, False}:
        raise RuntimeError("tests component has no Boolean disposition")
    if component == "static-registries" and result.get("passed") not in {True, False}:
        raise RuntimeError("static registry component has no Boolean disposition")
    receipt = {
        "schema_version": 1,
        "component": component,
        "argv": command,
        "returncode": completed.returncode,
        "termination": "EXITED_ZERO",
        "input_root_sha256": BOOTSTRAP_INPUT_ROOT,
        "stdout_base64": base64.b64encode(completed.stdout).decode("ascii"),
        "stdout_sha256": sha256(completed.stdout).hexdigest(),
        "stderr_base64": base64.b64encode(completed.stderr).decode("ascii"),
        "stderr_sha256": sha256(completed.stderr).hexdigest(),
        "result_payload_sha256": sha256(result_payload).hexdigest(),
        "capture_authority": "candidate_validator_local_process",
        "externally_attested": False,
        "descendant_containment_proved": False,
    }
    return result, receipt


def child_result_ok(result: dict[str, object]) -> bool:
    return bool(
        result["terminal_state_count"] > 0
        and 0 < result["unique_ordered_evidence_history_count"]
        <= result["reachable_exact_state_count"]
        and result["nonterminal_deadlock_count"] == 0
        and result["states_without_terminal_path"] == 0
        and result["winner_overwrite_count"] == 0
        and result["protection_breach_terminal_count"] > 0
        and result["hostile_bypass_explicit"] is True
        and result["coaccessibility_only"] is True
        and result["universal_termination_proved"] is False
        and result["infinite_stutter_counterexample_present"] is True
        and result["management_domain_refinement_proved"] is False
        and result["monitor_protection_refinement_proved"] is False
        and result["external_assumptions_discharged"] is False
        and result["linux_refinement_proved"] is False
        and result["semantic_verdict_issued"] is False
        and result["hostile_attempt_bound"] == child.MAX_HOSTILE_ATTEMPTS
        and result["reacquisition_bound"] == child.MAX_REACQUISITIONS
        and result["multiple_pending_arrival_state_count"] > 0
        and result["exact_ordered_history_state_identity"] is True
        and result["bounded_exact_ordered_history_graph_exhaustive"] is True
        and result["frontier_empty"] is True
        and result["all_reachable_states_wf"] is True
        and result["all_edges_target_reachable"] is True
        and result["exact_state_key_collision_count"] == 0
    )


def commutation_result_ok(result: dict[str, object]) -> bool:
    return bool(
        result["passed"] is True
        and result["declared_independence_pair_count"] > 0
        and result[
            "declared_pair_occurrences_exhaustive_over_reachable_states"
        ]
        is True
        and result["independence_relation_claimed_complete"] is False
        and result["undeclared_pairs_assumed_independent"] is False
        and result["reachability_uses_exact_state_identity"] is True
        and result["ordered_history_quotiented_for_reachability"] is False
        and result["check_scope"] == "LOCAL_TWO_STEP_EFFECT_COMMUTATION_ONLY"
        and result[
            "outcome_projection_retains_receipt_semantics_and_multiplicity"
        ]
        is True
        and result["outcome_projection_retains_causal_and_recovery_pointers"]
        is True
        and result["outcome_projection_congruence_proved"] is False
        and result["global_semantic_confluence_proved"] is False
        and result["sealed_evidence_root_identity_proved"] is False
    )


def full_result() -> dict[str, object]:
    before = input_hashes()
    bootstrap_integrity = bool(
        BOOTSTRAP_INPUT_HASHES == POST_MODEL_LOAD_INPUT_HASHES == before
        and CHILD_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_lts_v3.py"]
        and ORCHESTRATOR_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_orchestrator_v3.py"]
    )
    order = (
        "static-registries",
        "tests",
        "child-bundle-producer",
        "child-bundle-checker",
        "orchestrator",
    )
    invocations = {name: invoke_component(name) for name in order}
    components = {name: invocation[0] for name, invocation in invocations.items()}
    component_receipts = {
        name: invocation[1] for name, invocation in invocations.items()
    }
    component_capture_ok = bool(
        set(component_receipts) == set(order)
        and all(
            receipt["component"] == name
            and receipt["returncode"] == 0
            and receipt["termination"] == "EXITED_ZERO"
            and receipt["input_root_sha256"] == BOOTSTRAP_INPUT_ROOT
            and receipt["capture_authority"]
            == "candidate_validator_local_process"
            and receipt["externally_attested"] is False
            and receipt["descendant_containment_proved"] is False
            for name, receipt in component_receipts.items()
        )
    )
    after = input_hashes()

    producer_bundle = components["child-bundle-producer"]
    checker_bundle = components["child-bundle-checker"]
    producer = producer_bundle["exploration"]
    checker = checker_bundle["exploration"]
    producer_actions = set(producer["reachable_action_ids"])
    checker_actions = set(checker["reachable_action_ids"])
    combined_actions = producer_actions | checker_actions
    declared_actions = set(child.ACTION_IDS)
    child_registry = {
        "declared_action_count": len(declared_actions),
        "combined_reachable_action_count": len(combined_actions),
        "missing_actions": sorted(declared_actions - combined_actions),
        "undeclared_actions": sorted(combined_actions - declared_actions),
        "exact": combined_actions == declared_actions,
    }
    orch = components["orchestrator"]["result"]
    orch_ok = bool(
        orch["nonterminal_deadlock_count"] == 0
        and orch["states_without_terminal_path"] == 0
        and orch["missing_actions"] == []
        and orch["undeclared_actions"] == []
        and orch["semantic_verdict_always_absent"] is True
        and orch["published_artifact_type"] == "LOCAL_DISPOSITION_CAPSULE"
        and orch["external_assumptions_discharged"] is False
        and orch["durable_store_refinement_proved"] is False
        and orch["issuance_registry_refinement_proved"] is False
        and orch["global_nonce_uniqueness_proved"] is False
        and orch["symbolic_authentication_discharged"] is False
        and orch["exploration_semantics"]
        == "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL"
        and orch["exact_state_identity_within_repetition_bound"] is True
        and orch["attached_fixture_terminal_trace_replay_checked"] is True
        and orch["all_child_terminal_traces_composed"] is False
        and orch["parent_child_product_exhaustive"] is False
        and orch["store_attack_repetition_policy"]
        == "FIRST_ATTEMPT_PER_TYPED_CONTEXT_REPETITION_BOUND"
        and orch["max_store_attack_attempts_per_typed_context"] == 1
        and orch["repetition_bounded_state_space_exhaustive"] is True
        and orch["unbounded_attack_history_frontier_empty"] is False
        and orch["partial_order_reduction_applied"] is False
        and orch["partial_order_equivalence_proved"] is False
        and orch["unbounded_repeated_store_attack_history_exhaustive"] is False
        and orch["attack_context_key_refinement_proved"] is False
        and orch["multiple_store_attack_context_state_count"] > 0
        and orch["owner_failure_with_pending_attack_state_count"] > 0
        and orch["post_owner_publish_attack_state_count"] > 0
        and orch["guardian_generation_capsule_state_count"] > 0
        and orch["abandoned_terminal_requires_matching_ack"] is True
        and orch["typed_abandonment_conflict_withholds_assurance"] is True
        and orch["abandonment_conflict_breach_terminal_count"] > 0
        and orch["publication_fence_reauthorization_encoded"] is True
        and orch["publication_fence_store_refinement_proved"] is False
        and orch["coaccessibility_only"] is True
        and orch["universal_termination_proved"] is False
        and orch["infinite_stutter_counterexample_present"] is True
        and orch["assurance_breach_explicit"] is True
        and orch["assurance_breach_terminal_count"] > 0
        and orch["guardian_survivability_proved"] is False
        and orch["external_semantic_verdict_issued"] is False
    )
    child_graph_ok = child_result_ok(producer) and child_result_ok(checker)
    declared_commutation_ok = bool(
        commutation_result_ok(producer_bundle["commutation"])
        and commutation_result_ok(checker_bundle["commutation"])
    )
    fast_local_checks_ok = bool(
        bootstrap_integrity
        and before == after
        and components["static-registries"]["passed"]
        and components["tests"]["passed"]
    )
    fast_claim_ok = bool(fast_local_checks_ok and component_capture_ok)
    child_claim_ok = bool(child_graph_ok and component_capture_ok)
    parent_claim_ok = bool(orch_ok and component_capture_ok)
    commutation_claim_ok = bool(
        declared_commutation_ok and component_capture_ok
    )
    local_candidate = bool(
        fast_claim_ok
        and child_claim_ok
        and producer_bundle["single_graph_reused"] is True
        and checker_bundle["single_graph_reused"] is True
        and commutation_claim_ok
        and child_registry["exact"]
        and parent_claim_ok
        and component_capture_ok
    )
    result = {
        "schema_version": 4,
        "artifact_id": "dynamic-residency-f0-v5-supervisor-v3-candidate4-full-local-result",
        "claim_registry": {
            "artifact_id": CLAIM_REGISTRY["artifact_id"],
            "sha256": CLAIM_REGISTRY_SHA256,
        },
        "status": (
            "COMPLETE_LOCAL_C4_CANDIDATE_ONLY"
            if local_candidate
            else "COMPLETE_LOCAL_C4_REJECTED"
        ),
        "input_hashes_before": before,
        "input_hashes_after": after,
        "bootstrap_input_hashes": BOOTSTRAP_INPUT_HASHES,
        "post_model_load_input_hashes": POST_MODEL_LOAD_INPUT_HASHES,
        "executed_model_source_hashes": {
            "f0_supervisor_lts_v3.py": CHILD_EXECUTED_SOURCE_SHA256,
            "f0_supervisor_orchestrator_v3.py": (
                ORCHESTRATOR_EXECUTED_SOURCE_SHA256
            ),
        },
        "bootstrap_source_execution_check": bootstrap_integrity,
        "input_hashes_equal_before_after": before == after,
        "components": components,
        "component_execution_receipts": component_receipts,
        "child_action_registry": child_registry,
        "claims": {
            "F0-C4-FAST-MUTATION-AND-STATIC-v1": claim_status(
                (
                    "PASS"
                    if fast_claim_ok
                    else "FAIL"
                ),
                [
                    "bootstrap_source_execution_check",
                    "input_hashes_equal_before_after",
                    "components.tests",
                    "components.static-registries",
                    "component_execution_receipts.tests",
                    "component_execution_receipts.static-registries",
                ],
            ),
            "F0-C4-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "PASS" if child_claim_ok else "FAIL",
                [
                    "components.child-bundle-producer",
                    "components.child-bundle-checker",
                    "component_execution_receipts.child-bundle-producer",
                    "component_execution_receipts.child-bundle-checker",
                ],
            ),
            "F0-C4-REACH-PARENT-EXACT-REPETITION-BOUNDED-v1": claim_status(
                "PASS" if parent_claim_ok else "FAIL",
                [
                    "components.orchestrator",
                    "component_execution_receipts.orchestrator",
                ],
            ),
            "F0-C4-DECLARED-LOCAL-EFFECT-COMMUTATION-v1": claim_status(
                "PASS" if commutation_claim_ok else "FAIL",
                [
                    "components.child-bundle-producer.commutation",
                    "components.child-bundle-checker.commutation",
                    "component_execution_receipts.child-bundle-producer",
                    "component_execution_receipts.child-bundle-checker",
                ],
            ),
            "F0-C4-INDEPENDENCE-RELATION-COMPLETE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.child#INDEP-001"],
            ),
            "F0-C4-EXTERNAL-AUTHENTICATION-v1": claim_status(
                "OPEN_REFINEMENT",
                [
                    "open_refinement_obligations.child#EXT-AUTH-001",
                    "open_refinement_obligations.child#MONITOR-001",
                    "open_refinement_obligations.child#MGMT-001",
                    "open_refinement_obligations.orchestrator#ORCH-EXT-001",
                    "open_refinement_obligations.orchestrator#ORCH-REG-001",
                ],
            ),
            "F0-C4-ATTACK-CONTEXT-KEY-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-ATTACK-CTX-001"],
            ),
            "F0-C4-UNBOUNDED-REPEATED-ATTACK-HISTORY-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-ATTACK-CTX-001"],
            ),
            "F0-C4-DURABLE-STORE-LINEARIZATION-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-STORE-001"],
            ),
            "F0-C4-PARENT-CHILD-INDEPENDENCE-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                [
                    "open_refinement_obligations.orchestrator#ORCH-INDEP-001",
                    "open_refinement_obligations.orchestrator#ORCH-CHILD-001",
                ],
            ),
            "F0-LOCAL-ACCEPTANCE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["authorization.F0_local_acceptance=false"],
            ),
        },
        "open_refinement_obligations": {
            "child": list(child.OPEN_REFINEMENT_OBLIGATIONS),
            "orchestrator": list(orchestrator.OPEN_REFINEMENT_OBLIGATIONS),
        },
        "authorization": {
            "local_executable_candidate": local_candidate,
            "external_R11_review": False,
            "G0_authorized": False,
            "self_authorization": False,
            "standalone_child_bounded_exact_ordered_history_graph_exhaustive": bool(
                producer["bounded_exact_ordered_history_graph_exhaustive"]
                and checker["bounded_exact_ordered_history_graph_exhaustive"]
            ),
            "standalone_child_bounds": {
                "hostile_attempts": child.MAX_HOSTILE_ATTEMPTS,
                "reacquisitions": child.MAX_REACQUISITIONS,
            },
            "declared_local_effect_commutation_checked": bool(
                declared_commutation_ok
            ),
            "independence_relation_complete": False,
            "commutation_projection_congruence": False,
            "global_semantic_confluence": False,
            "unbounded_ordered_history_state_space_exhaustive": False,
            "unbounded_repeated_store_attack_history_exhaustive": False,
            "attack_context_key_refinement": False,
            "parent_child_product_exhaustive": False,
            "external_authentication_assumption_discharged": False,
            "linux_refinement": False,
            "monitor_refinement": False,
            "resource_causality_implemented": False,
            "durable_store_refinement": False,
            "checker_soundness": False,
            "external_review": False,
            "semantic_verdict_issued": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "candidate_IR": False,
            "TLA_translation": False,
            "model_supported": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
        "provenance_boundary": {
            "symbolic_model_workload_input": "input-root-a",
            "symbolic_model_workload_input_is_source_manifest": False,
            "source_files_bound_by_input_hashes": False,
            "source_file_bytes_hashed_before_and_after_local_checks": True,
            "model_modules_compiled_from_bootstrap_hashed_source_bytes": True,
            "validator_source_execution_bound_by_external_launcher": False,
            "raw_component_stdout_receipts_bound_to_components": (
                component_capture_ok
            ),
            "component_execution_receipts_externally_attested": False,
            "runtime_input_write_prevention_enforced": False,
            "input_stability_during_execution_proved": False,
            "external_R11_evidence_present": False,
            "G0_evidence_present": False,
        },
    }
    validate_claim_evidence_references(result)
    validate_emitted_claims(
        result["claims"],
        "full",
        {
            "FAST_MUTATION_STATIC": fast_claim_ok,
            "CHILD_EXACT_FIXTURE_BOUNDED": child_claim_ok,
            "PARENT_EXACT_REPETITION_BOUNDED": parent_claim_ok,
            "DECLARED_LOCAL_EFFECT_COMMUTATION": commutation_claim_ok,
        },
    )
    return result


def fast_result() -> dict[str, object]:
    before = input_hashes()
    bootstrap_integrity = bool(
        BOOTSTRAP_INPUT_HASHES == POST_MODEL_LOAD_INPUT_HASHES == before
        and CHILD_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_lts_v3.py"]
        and ORCHESTRATOR_EXECUTED_SOURCE_SHA256
        == BOOTSTRAP_INPUT_HASHES["f0_supervisor_orchestrator_v3.py"]
    )
    static = component_result("static-registries")
    tests = component_result("tests")
    after = input_hashes()
    passed = bool(
        bootstrap_integrity
        and before == after
        and static["passed"]
        and tests["passed"]
    )
    result = {
        "schema_version": 4,
        "artifact_id": (
            "dynamic-residency-f0-v5-supervisor-v3-candidate4-fast-local-result"
        ),
        "claim_registry": {
            "artifact_id": CLAIM_REGISTRY["artifact_id"],
            "sha256": CLAIM_REGISTRY_SHA256,
        },
        "status": (
            "COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY"
            if passed
            else "COMPLETE_LOCAL_C4_REJECTED"
        ),
        "input_hashes_before": before,
        "input_hashes_after": after,
        "bootstrap_input_hashes": BOOTSTRAP_INPUT_HASHES,
        "post_model_load_input_hashes": POST_MODEL_LOAD_INPUT_HASHES,
        "executed_model_source_hashes": {
            "f0_supervisor_lts_v3.py": CHILD_EXECUTED_SOURCE_SHA256,
            "f0_supervisor_orchestrator_v3.py": (
                ORCHESTRATOR_EXECUTED_SOURCE_SHA256
            ),
        },
        "bootstrap_source_execution_check": bootstrap_integrity,
        "input_hashes_equal_before_after": before == after,
        "scope": "MUTATION_AND_STATIC_REGISTRY_ONLY",
        "static_registries": static,
        "tests": tests,
        "claims": {
            "F0-C4-FAST-MUTATION-AND-STATIC-v1": claim_status(
                "PASS" if passed else "FAIL",
                [
                    "bootstrap_source_execution_check",
                    "input_hashes_equal_before_after",
                    "tests",
                    "static_registries",
                ],
            ),
            "F0-C4-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C4-REACH-PARENT-EXACT-REPETITION-BOUNDED-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C4-DECLARED-LOCAL-EFFECT-COMMUTATION-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C4-INDEPENDENCE-RELATION-COMPLETE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.child#INDEP-001"],
            ),
            "F0-C4-EXTERNAL-AUTHENTICATION-v1": claim_status(
                "OPEN_REFINEMENT",
                [
                    "open_refinement_obligations.child#EXT-AUTH-001",
                    "open_refinement_obligations.child#MONITOR-001",
                    "open_refinement_obligations.child#MGMT-001",
                    "open_refinement_obligations.orchestrator#ORCH-EXT-001",
                    "open_refinement_obligations.orchestrator#ORCH-REG-001",
                ],
            ),
            "F0-C4-ATTACK-CONTEXT-KEY-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-ATTACK-CTX-001"],
            ),
            "F0-C4-UNBOUNDED-REPEATED-ATTACK-HISTORY-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-ATTACK-CTX-001"],
            ),
            "F0-C4-DURABLE-STORE-LINEARIZATION-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator#ORCH-STORE-001"],
            ),
            "F0-C4-PARENT-CHILD-INDEPENDENCE-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                [
                    "open_refinement_obligations.orchestrator#ORCH-INDEP-001",
                    "open_refinement_obligations.orchestrator#ORCH-CHILD-001",
                ],
            ),
            "F0-LOCAL-ACCEPTANCE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["authorization.F0_local_acceptance=false"],
            ),
        },
        "open_refinement_obligations": {
            "child": list(child.OPEN_REFINEMENT_OBLIGATIONS),
            "orchestrator": list(orchestrator.OPEN_REFINEMENT_OBLIGATIONS),
        },
        "authorization": {
            "fast_local_regression": passed,
            "external_R11_review": False,
            "G0_authorized": False,
            "self_authorization": False,
            "full_child_reachability": False,
            "full_orchestrator_reachability": False,
            "declared_commutation_occurrences_exhaustive": False,
            "local_executable_candidate": False,
            "external_authentication_assumption_discharged": False,
            "durable_store_refinement": False,
            "attack_context_key_refinement": False,
            "unbounded_repeated_store_attack_history_exhaustive": False,
            "parent_child_product_exhaustive": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
        "provenance_boundary": {
            "symbolic_model_workload_input": "input-root-a",
            "symbolic_model_workload_input_is_source_manifest": False,
            "source_files_bound_by_input_hashes": False,
            "source_file_bytes_hashed_before_and_after_local_checks": True,
            "model_modules_compiled_from_bootstrap_hashed_source_bytes": True,
            "validator_source_execution_bound_by_external_launcher": False,
            "raw_component_stdout_receipts_bound_to_components": False,
            "component_execution_receipts_externally_attested": False,
            "runtime_input_write_prevention_enforced": False,
            "input_stability_during_execution_proved": False,
            "external_R11_evidence_present": False,
            "G0_evidence_present": False,
        },
    }
    validate_claim_evidence_references(result)
    validate_emitted_claims(
        result["claims"],
        "fast",
        {"FAST_MUTATION_STATIC": passed},
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--component",
        choices=(
            "static-registries",
            "tests",
            "child-bundle-producer",
            "child-bundle-checker",
            "orchestrator",
        ),
    )
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()

    if arguments.component:
        before = input_hashes()
        result = component_result(arguments.component)
        after = input_hashes()
        result["worker_provenance"] = worker_provenance(before, after)
        print("RESULT_JSON=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0

    result = full_result() if arguments.full else fast_result()
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    if arguments.full:
        return 0 if result["authorization"]["local_executable_candidate"] else 1
    return 0 if result["authorization"]["fast_local_regression"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
