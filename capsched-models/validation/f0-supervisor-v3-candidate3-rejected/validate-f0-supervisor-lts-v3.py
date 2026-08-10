#!/usr/bin/env python3
"""Validate supervisor v3 candidate-3 without granting F0 or G0 credit."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import asdict
from hashlib import sha256
from pathlib import Path

import f0_supervisor_lts_v3 as child
import f0_supervisor_orchestrator_v3 as orchestrator


HERE = Path(__file__).resolve().parent
INPUT_FILES = (
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
)
CLAIM_STATUSES = {"PASS", "FAIL", "NOT_RUN", "INCOMPLETE", "OPEN_REFINEMENT"}


def claim_status(status: str, evidence: list[str]) -> dict[str, object]:
    if status not in CLAIM_STATUSES:
        raise ValueError(status)
    return {"status": status, "evidence": evidence}


def file_hash(path: Path) -> str:
    hasher = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def input_hashes() -> dict[str, str]:
    return {name: file_hash(HERE / name) for name in INPUT_FILES}


def run_test(path: Path) -> dict[str, object]:
    environment = dict(os.environ)
    environment["PYTHONPATH"] = str(HERE)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    completed = subprocess.run(
        [sys.executable, str(path)],
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    return {
        "path": path.name,
        "returncode": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
        "passed": completed.returncode == 0 and "PASS" in completed.stdout,
    }


def static_registry_result() -> dict[str, object]:
    child_actions = set(child.ACTION_SPECS)
    child_writes = set(child.ACTION_WRITE_FIELDS)
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
        and orchestrator_actions == orchestrator_writes
        and orchestrator_actions == orchestrator_required_writes
        and all(
            orchestrator.ACTION_REQUIRED_WRITE_FIELDS[action_id]
            <= orchestrator.ACTION_WRITE_FIELDS[action_id]
            for action_id in orchestrator_actions
        )
        and len(independence_ids) == len(set(independence_ids))
        and independence_ids
    )
    return {
        "component": "static-registries",
        "child": {
            "declared_action_count": len(child_actions),
            "write_policy_count": len(child_writes),
            "write_policy_exact_registry_coverage": child_actions == child_writes,
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


def invoke_component(component: str) -> dict[str, object]:
    environment = dict(os.environ)
    environment["PYTHONPATH"] = str(HERE)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    completed = subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), "--component", component],
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"component {component} failed rc={completed.returncode}: "
            f"{completed.stderr.strip()}"
        )
    marker = "RESULT_JSON="
    lines = [line for line in completed.stdout.splitlines() if line.startswith(marker)]
    if len(lines) != 1:
        raise RuntimeError(f"component {component} returned no unique JSON result")
    return json.loads(lines[0][len(marker) :])


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
    order = (
        "static-registries",
        "tests",
        "child-bundle-producer",
        "child-bundle-checker",
        "orchestrator",
    )
    components = {name: invoke_component(name) for name in order}
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
        and orch["exact_state_identity_explored"] is True
        and orch["attached_fixture_terminal_trace_replay_checked"] is True
        and orch["all_child_terminal_traces_composed"] is False
        and orch["parent_child_product_exhaustive"] is False
        and orch["store_attack_repetition_policy"]
        == "FIRST_ATTEMPT_PER_ABSTRACT_CONTEXT_PARTIAL_ORDER_REDUCTION"
        and orch["store_security_history_exact_within_context_por"] is True
        and orch["unbounded_repeated_store_attack_history_exhaustive"] is False
        and orch["attack_context_key_refinement_proved"] is False
        and orch["multiple_store_attack_context_state_count"] > 0
        and orch["owner_failure_with_pending_attack_state_count"] > 0
        and orch["post_owner_publish_attack_state_count"] > 0
        and orch["guardian_generation_capsule_state_count"] > 0
        and orch["abandoned_terminal_requires_matching_ack"] is True
        and orch["unattributed_abandonment_conflict_is_assurance_breach"] is True
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
    local_candidate = bool(
        before == after
        and components["static-registries"]["passed"]
        and components["tests"]["passed"]
        and child_graph_ok
        and producer_bundle["single_graph_reused"] is True
        and checker_bundle["single_graph_reused"] is True
        and declared_commutation_ok
        and child_registry["exact"]
        and orch_ok
    )
    return {
        "schema_version": 3,
        "artifact_id": "dynamic-residency-f0-v5-supervisor-v3-candidate3-full-local-result",
        "status": (
            "LOCAL_EXECUTABLE_CANDIDATE_ONLY"
            if local_candidate
            else "LOCAL_CANDIDATE_REJECTED"
        ),
        "input_hashes_before": before,
        "input_hashes_after": after,
        "immutable_input_check": before == after,
        "components": components,
        "child_action_registry": child_registry,
        "claims": {
            "F0-C3-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "PASS" if child_graph_ok else "FAIL",
                ["components.child-bundle-producer", "components.child-bundle-checker"],
            ),
            "F0-C3-REACH-PARENT-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "PASS" if orch_ok else "FAIL",
                ["components.orchestrator"],
            ),
            "F0-C3-DECLARED-LOCAL-EFFECT-COMMUTATION-v1": claim_status(
                "PASS" if declared_commutation_ok else "FAIL",
                [
                    "components.child-bundle-producer.commutation",
                    "components.child-bundle-checker.commutation",
                ],
            ),
            "F0-C3-INDEPENDENCE-RELATION-COMPLETE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.child"],
            ),
            "F0-C3-EXTERNAL-AUTHENTICATION-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.child", "open_refinement_obligations.orchestrator"],
            ),
            "F0-C3-ATTACK-CONTEXT-KEY-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                ["open_refinement_obligations.orchestrator"],
            ),
            "F0-C3-UNBOUNDED-REPEATED-ATTACK-HISTORY-v1": claim_status(
                "OPEN_REFINEMENT",
                ["components.orchestrator"],
            ),
            "F0-LOCAL-ACCEPTANCE-v1": claim_status(
                "OPEN_REFINEMENT",
                ["authorization.F0_local_acceptance"],
            ),
        },
        "open_refinement_obligations": {
            "child": list(child.OPEN_REFINEMENT_OBLIGATIONS),
            "orchestrator": list(orchestrator.OPEN_REFINEMENT_OBLIGATIONS),
        },
        "authorization": {
            "local_executable_candidate": local_candidate,
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
    }


def fast_result() -> dict[str, object]:
    before = input_hashes()
    static = component_result("static-registries")
    tests = component_result("tests")
    after = input_hashes()
    passed = bool(
        before == after
        and static["passed"]
        and tests["passed"]
    )
    return {
        "schema_version": 3,
        "artifact_id": (
            "dynamic-residency-f0-v5-supervisor-v3-candidate3-fast-local-result"
        ),
        "status": "FAST_LOCAL_REGRESSION_PASS" if passed else "FAST_LOCAL_REGRESSION_REJECT",
        "input_hashes_before": before,
        "input_hashes_after": after,
        "immutable_input_check": before == after,
        "scope": "MUTATION_AND_STATIC_REGISTRY_ONLY",
        "static_registries": static,
        "tests": tests,
        "claims": {
            "F0-C3-FAST-MUTATION-AND-STATIC-v1": claim_status(
                "PASS" if passed else "FAIL",
                ["tests", "static_registries", "immutable_input_check"],
            ),
            "F0-C3-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C3-REACH-PARENT-EXACT-FIXTURE-BOUNDED-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C3-DECLARED-LOCAL-EFFECT-COMMUTATION-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-C3-EXTERNAL-AUTHENTICATION-v1": claim_status(
                "OPEN_REFINEMENT",
                [],
            ),
            "F0-C3-ATTACK-CONTEXT-KEY-REFINEMENT-v1": claim_status(
                "OPEN_REFINEMENT",
                [],
            ),
            "F0-C3-UNBOUNDED-REPEATED-ATTACK-HISTORY-v1": claim_status(
                "NOT_RUN",
                [],
            ),
            "F0-LOCAL-ACCEPTANCE-v1": claim_status(
                "OPEN_REFINEMENT",
                [],
            ),
        },
        "authorization": {
            "fast_local_regression": passed,
            "full_child_reachability": False,
            "full_orchestrator_reachability": False,
            "declared_commutation_occurrences_exhaustive": False,
            "local_executable_candidate": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
    }


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
        result = component_result(arguments.component)
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
