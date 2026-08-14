#!/usr/bin/env python3
"""Cross-artifact semantic consistency checks for the compact current state.

The JSON schema checks shape.  This checker derives relationships across the
state ledger, claim register, Candidate-4 gate contract, current exact-input
record, G6 disposition, and the structured handoff projection.  It is invoked
by check-current-state.sh so there is one public state-validation entry point.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


EXIT_CLAIMS = (
    "ROOTSCHED-001",
    "RESIDENCY-001",
    "RESIDENCY-DYN-001",
    "ENTRY-001",
    "CODE-001",
    "STATE-001",
    "SVC-001",
    "MGMT-001",
    "CLUSTER-PART-001",
    "COMPOSE-001",
    "GRANULARITY-001",
    "EVIDENCE-001",
)

PROJECTION_BEGIN = "<!-- CURRENT-STATE-PROJECTION-BEGIN -->"
PROJECTION_END = "<!-- CURRENT-STATE-PROJECTION-END -->"


class ConsistencyError(ValueError):
    """A current-state relationship is internally inconsistent."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ConsistencyError(message)


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ConsistencyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle, object_pairs_hook=unique_object)
    except (OSError, json.JSONDecodeError) as error:
        raise ConsistencyError(f"cannot load {path}: {error}") from error
    require(isinstance(value, dict), f"top-level JSON object required: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def objects_by_id(items: list[dict[str, Any]], label: str) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in items:
        item_id = item.get("id")
        require(isinstance(item_id, str) and item_id, f"{label} has an invalid id")
        require(item_id not in result, f"duplicate {label} id: {item_id}")
        result[item_id] = item
    return result


def claim_statuses(claims: dict[str, Any]) -> dict[str, str]:
    indexed = objects_by_id(claims["claims"], "claim")
    missing = sorted(set(EXIT_CLAIMS) - set(indexed))
    require(not missing, f"missing final-plan claims: {missing}")
    return {claim_id: indexed[claim_id]["status"] for claim_id in EXIT_CLAIMS}


def current_projection(state: dict[str, Any], claims: dict[str, Any]) -> dict[str, Any]:
    current = state["evidence"]["current_candidate_inputs"]
    capture = state["evidence"]["authority_capture_contract"]
    g6 = capture["g6"]
    latest = next(
        attempt
        for attempt in g6["attempt_history"]
        if attempt["run_id"] == g6["latest_completed_attempt_run_id"]
    )
    return {
        "schema_version": 1,
        "updated": state["updated"],
        "project_phase": state["project"]["current_phase"],
        "completion": state["completion"],
        "claim_statuses": claim_statuses(claims),
        "candidate4": {
            "current_input_artifact": current["artifact_id"],
            "fast_validator_status": current["fast_validator_status"],
            "full_validator_status": current["full_validator_status"],
            "hostile_case_counts": current["hostile_case_counts"],
            "capture_contract_sha256": capture["canonical_sha256"],
            "closed_gates": capture["closed_gates"],
            "remaining_gates": capture["remaining_gates"],
            "clean_install": capture["clean_install"],
            "g6": {
                "gate_status": g6["gate_status"],
                "retry_eligible": g6["retry_eligible"],
                "complete_capture_available": g6["complete_capture_available"],
                "active_attempt": g6["active_attempt"],
                "latest_completed_attempt": latest,
            },
            "g7": capture["g7"],
        },
    }


def validate_semantics(
    state: dict[str, Any],
    claims: dict[str, Any],
    contract: dict[str, Any],
    current_input: dict[str, Any],
    observation: dict[str, Any],
    readiness: dict[str, Any],
) -> None:
    completion = state["completion"]
    for key in (
        "final_compositional_model_complete",
        "linux_implementation_complete",
        "monitor_implementation_complete",
        "protection_evidenced",
        "cost_efficiency_evidenced",
        "deployment_ready",
    ):
        require(completion[key] is False, f"unsupported completion flag: {key}")

    statuses = claim_statuses(claims)
    require(statuses["ROOTSCHED-001"] == "model_supported", "ROOTSCHED state drift")
    require(statuses["RESIDENCY-001"] == "model_supported", "RESIDENCY state drift")
    require(statuses["EVIDENCE-001"] == "contract_defined", "EVIDENCE state drift")
    for claim_id in EXIT_CLAIMS:
        if claim_id not in {"ROOTSCHED-001", "RESIDENCY-001", "EVIDENCE-001"}:
            require(statuses[claim_id] == "open", f"unexpected claim status: {claim_id}")

    evidence = state["evidence"]
    historical = evidence["local_candidate_checkpoint"]
    require(
        historical["full_validator_status_at_checkpoint"] == "NOT_RUN",
        "historical pre-full checkpoint was rewritten",
    )
    require(
        historical["authority_disjoint_capture_at_checkpoint"] is False,
        "historical checkpoint authority was rewritten",
    )
    historical_counts = historical["hostile_case_counts_at_checkpoint"]
    require(
        historical_counts["total"]
        == historical_counts["child"] + historical_counts["parent"] + historical_counts["runner"],
        "historical hostile-case total mismatch",
    )

    current = evidence["current_candidate_inputs"]
    require(current["artifact_id"] == current_input["artifact_id"], "current input artifact drift")
    require(
        current["artifact_sha256"] == current_input["artifact_sha256"],
        "current input artifact digest drift",
    )
    require(
        current["fast_validator_status"]
        == current_input["local_regression"]["fast_validator_status"],
        "current fast-validator status drift",
    )
    require(
        current["full_validator_status"]
        == current_input["local_regression"]["full_validator_status"],
        "current full-validator status drift",
    )
    for key in ("child", "parent", "runner", "total"):
        source_key = f"{key}_hostile_cases" if key != "total" else "total_hostile_cases"
        require(
            current["hostile_case_counts"][key]
            == current_input["local_regression"][source_key],
            f"current hostile-case count drift: {key}",
        )
    counts = current["hostile_case_counts"]
    require(
        counts["total"] == counts["child"] + counts["parent"] + counts["runner"],
        "current hostile-case total mismatch",
    )

    capture = evidence["authority_capture_contract"]
    short = capture["short_regression"]
    for key in (
        "launcher_idle_cases",
        "behavioral_quotient_boundary_cases",
        "model_memory_policy_cases",
        "model_storage_equivalence_cases",
        "capture_resource_policy_cases",
        "external_memory_recovery_cases",
        "reducer_current_input_binding_cases",
    ):
        require(
            current_input["local_regression"][key] == short[key],
            f"current input/short-regression count drift: {key}",
        )
    contract_gates = [item["id"] for item in contract["implementation_gates"]]
    closed = capture["closed_gates"]
    remaining = capture["remaining_gates"]
    require(len(closed) == len(set(closed)), "duplicate closed capture gate")
    require(len(remaining) == len(set(remaining)), "duplicate remaining capture gate")
    require(not set(closed) & set(remaining), "capture gate both closed and remaining")
    require(closed + remaining == contract_gates, "capture gate partition/order drift")
    require(closed == contract_gates[:5], "G1-G5 mechanism closure drift")
    require(remaining == contract_gates[5:], "G6/G7 remaining-gate drift")
    require(
        contract["resource_policy"][
            "candidate_component_oom_isolated_from_supervisor"
        ]
        is True,
        "capture contract does not isolate component OOM",
    )

    install = capture["clean_install"]
    g6 = capture["g6"]
    g7 = capture["g7"]
    attempts = objects_by_id(
        [{**attempt, "id": attempt["run_id"]} for attempt in g6["attempt_history"]],
        "G6 attempt",
    )
    require(g6["attempt_count"] == len(attempts), "G6 attempt count drift")
    latest_id = g6["latest_completed_attempt_run_id"]
    require(latest_id in attempts, "latest G6 attempt is absent from history")
    latest = attempts[latest_id]
    active = g6["active_attempt"]
    if active is not None:
        require(
            active["run_id"] not in attempts,
            "active G6 attempt is already completed",
        )
        require(active["status"] == "CAPTURE_RUNNING", "active G6 status drift")
        require(
            active["installed_source_commit"] == install["installed_source_commit"],
            "active G6 installed source drift",
        )
        require(
            active["installed_manifest_sha256"] == install["installed_manifest_sha256"],
            "active G6 installed manifest drift",
        )
        require(
            active["capture_contract_sha256"] == capture["canonical_sha256"],
            "active G6 capture contract drift",
        )
        require(
            active["evidence_commit_available"] is False,
            "running G6 attempt claims a finalized evidence commit",
        )
    frontier_repair_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-second-oom-incomplete-observation-v1"
    )
    state_store_repair_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-third-oom-incomplete-observation-v1"
    )
    packed_history_repair_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-fourth-oom-incomplete-observation-v1"
    )
    external_memory_repair_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-fifth-oom-incomplete-observation-v1"
    )
    pending_attack_closure_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-pending-attack-incomplete-observation-v1"
    )
    behavioral_quotient_observation = (
        observation.get("artifact_id")
        == "f0-c4-g6-exact-history-timeout-observation-v1"
    )
    require(
        latest["status"] in {"RAW_CAPTURE_INCOMPLETE", "GUARDIAN_INCOMPLETE_PUBLISHED"},
        "latest G6 result drift",
    )
    require(latest["observation_record"] == state["canonical_files"]["f0_c4_g6_incomplete_record"], "G6 observation path drift")
    require(latest["observation_sha256"] == observation["artifact_sha256"], "G6 observation digest drift")
    require(observation["run_id"] == latest_id, "G6 observation run-id drift")
    if (
        frontier_repair_observation
        or state_store_repair_observation
        or packed_history_repair_observation
        or external_memory_repair_observation
        or pending_attack_closure_observation
        or behavioral_quotient_observation
    ):
        durable = observation["durable_evidence"]
        conclusion = observation["conclusion"]
        require(durable["capture_status"] == latest["status"], "G6 capture status drift")
        require(durable["candidate_bytes_positive_eligible"] is False, "incomplete G6 became positive-eligible")
        require(durable["reduction_performed"] is False, "incomplete G6 was reduced")
        require(conclusion["g6_complete"] is False, "incomplete G6 closed its gate")
        require(conclusion["g7_allowed"] is False, "incomplete G6 enabled G7")
    else:
        require(observation["raw_commit"]["capture_status"] == latest["status"], "G6 capture status drift")
        require(observation["raw_commit"]["candidate_bytes_positive_eligible"] is False, "incomplete G6 became positive-eligible")
        require(observation["raw_commit"]["reduction_performed"] is False, "incomplete G6 was reduced")
        require(observation["disposition"]["g6_closed"] is False, "incomplete G6 closed its gate")
        require(observation["disposition"]["g7_eligible"] is False, "incomplete G6 enabled G7")
    if latest["status"] == "GUARDIAN_INCOMPLETE_PUBLISHED":
        require(
            observation["guardian_disposition"]["service_result"] == "oom-kill",
            "guardian OOM result drift",
        )
        require(
            observation["resource_observation"]["failed_component"]
            == "child-bundle-producer",
            "OOM component drift",
        )
        require(
            current_input["failed_capture"]["run_id"] == latest_id,
            "resource repair does not bind the failed run",
        )
        repair = current_input["repair"]
        require(
            repair["exact_state_identity_changed"] is False
            and repair["transition_relation_changed"] is False
            and repair["reachable_state_set_intentionally_changed"] is False,
            "resource repair changed Candidate-4 semantics",
        )
        require(
            repair["enumeration_representation_changed"] is True
            and repair["reachable_state_dataclasses_use_slots"] is True
            and repair["unbounded_transition_and_well_formedness_caches_removed"] is True
            and repair["remaining_pure_caches_have_positive_finite_bounds"] is True
            and repair["per_edge_python_object_retention_replaced_by_fixed_width_csr"] is True
            and repair["candidate_component_oom_isolated_from_trusted_supervisor"] is True,
            "resource-retention repair is incomplete",
        )
        require(
            repair["post_run_reducer_current_input_binding_repaired"] is True
            and repair[
                "future_reducer_input_and_semantic_registry_drift_mechanically_rejected"
            ]
            is True,
            "reducer current-input repair is incomplete",
        )
        require(
            contract["resource_policy"][
                "candidate_component_oom_isolated_from_supervisor"
            ]
            is True,
            "capture contract does not isolate component OOM",
        )
    elif behavioral_quotient_observation:
        failed = observation["failed_component"]
        diagnosis = observation["diagnosis"]
        conclusion = observation["conclusion"]
        require(
            failed["component_id"] == "child-bundle-producer"
            and failed["termination"] == "DEADLINE_EXCEEDED"
            and failed["deadline_seconds"] == 43200
            and failed["deadline_exceeded"] is True
            and failed["elapsed_monotonic_ns"] >= 43200 * 1_000_000_000
            and failed["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "behavioral-quotient timeout observation drift",
        )
        require(
            all(
                failed["memory_events"][key] == 0
                for key in ("oom", "oom_kill", "oom_group_kill")
            )
            and diagnosis["component_oom_observed"] is False
            and diagnosis["global_oom_observed"] is False
            and diagnosis["configured_deadline_reached"] is True
            and diagnosis["exact_ordered_audit_history_is_part_of_state_identity"]
            is True
            and conclusion["capacity_failure"] is True
            and conclusion["capacity_failure_class"]
            == "EXACT_AUDIT_REPRESENTATION_STATE_EXPLOSION",
            "exact-history timeout was misclassified as OOM or semantics",
        )
        require(
            failed["external_memory"]["mode"]
            == contract["resource_policy"]["external_memory_backing_mode"]
            and failed["external_memory"]["direct_io"] is True
            and failed["external_memory"]["visible_entries_after_exit"] == 0
            and failed["external_memory"]["unmounted"] is True
            and failed["external_memory"]["loop_detached"] is True
            and failed["external_memory"]["backing_removed"] is True,
            "timeout run did not retain the external-memory boundary",
        )
        require(
            observation["source"]["captured_child_model_sha256"]
            != current_input["exact_inputs"]["f0_supervisor_lts_v3.py"],
            "behavioral quotient did not change rejected child bytes",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id
            and current_input["failed_capture_observation"]["artifact_sha256"]
            == observation["artifact_sha256"],
            "behavioral quotient does not bind the timed-out run",
        )
        quotient = current_input["behavioral_quotient"]
        require(
            quotient["full_fixture_reachability_identity"]
            == "BEHAVIORAL_AUDIT_REPRESENTATION_QUOTIENT"
            and quotient["exact_ordered_identity_retained_for_bounded_regression"]
            is True
            and quotient["receipt_semantic_facts_and_multiplicity_retained"]
            is True
            and quotient["receipt_issuer_and_channel_retained"] is True
            and quotient["all_operational_state_fields_retained"] is True
            and quotient["recovery_and_decision_semantics_retained"] is True
            and quotient["projection_hash_matches_resolved_by_full_equality"]
            is True
            and quotient["bounded_projection_congruence_regression_passed"]
            is True
            and quotient["audit_chain_implementation_refinement_proved"]
            is False
            and quotient["weaker_authority_projection_rejected"] is True
            and quotient["weaker_projection_conflicts_observed"] > 0
            and quotient["production_linux_scheduler_hot_path_changed"] is False
            and quotient["production_monitor_dispatch_hot_path_changed"] is False,
            "behavioral quotient is weakened, overclaimed, or over-broad",
        )
        require(
            all(
                current_input["predecessor"][key] is True
                for key in (
                    "semantic_pending_attack_repair_retained",
                    "disk_backed_exact_store_retained",
                    "packed_exact_history_retained",
                    "component_oom_isolation_retained",
                )
            ),
            "behavioral quotient dropped predecessor repairs",
        )
    elif pending_attack_closure_observation:
        failed = observation["failed_component"]
        require(
            failed["component_id"] == "child-bundle-producer"
            and failed["termination"] == "EXITED_NONZERO"
            and failed["exit_code"] == 1
            and failed["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "pending-attack failure observation drift",
        )
        require(
            all(
                failed["memory_events"][key] == 0
                for key in ("oom", "oom_kill", "oom_group_kill")
            )
            and observation["conclusion"]["component_oom_observed"] is False
            and observation["conclusion"]["capacity_failure"] is False
            and observation["conclusion"]["semantic_counterexample"] is True,
            "pending-attack counterexample was misclassified as OOM or capacity",
        )
        require(
            failed["external_memory"]["mode"]
            == contract["resource_policy"]["external_memory_backing_mode"]
            and failed["external_memory"]["direct_io"] is True
            and failed["external_memory"]["visible_entries_after_exit"] == 0
            and failed["external_memory"]["unmounted"] is True
            and failed["external_memory"]["loop_detached"] is True
            and failed["external_memory"]["backing_removed"] is True,
            "pending-attack run did not retain the external-memory boundary",
        )
        require(
            observation["source"]["captured_child_model_sha256"]
            != current_input["exact_inputs"]["f0_supervisor_lts_v3.py"],
            "pending-attack repair did not change the rejected child bytes",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id
            and current_input["failed_capture_observation"][
                "artifact_sha256"
            ]
            == observation["artifact_sha256"],
            "pending-attack repair does not bind the failed run",
        )
        repair = current_input["semantic_repair"]
        require(
            repair["trigger_action_id"]
            == "ADV-023B-SUCCEED-HOSTILE-BYPASS"
            and repair["repaired_action_id"]
            == "MON-039C-PROTECTION-CLOSED"
            and repair["semantic_change"] is True
            and repair["child_transition_relation_changed"] is True
            and repair["parent_transition_relation_changed"] is False
            and repair["reachable_state_sets_intentionally_changed"] is True
            and repair["exact_state_identity_changed"] is False
            and repair["ordered_evidence_history_quotiented"] is False
            and repair["instance_wf_weakened"] is False
            and repair["closure_requires_pending_attack_none"] is True
            and repair["closure_requires_attack_attempts_equal_rejections"]
            is True
            and repair["explicit_hostile_rejection_retained"] is True
            and repair["explicit_hostile_bypass_terminal_retained"] is True
            and repair["unresolved_attempt_has_terminal_outcome"] is True
            and repair["closure_after_rejection_available"] is True
            and repair["counterexample_trace_added_to_fast_regression"] is True
            and repair["minimized_counterexample_trace_length"] == 17
            and repair["production_linux_scheduler_hot_path_changed"] is False
            and repair["production_monitor_dispatch_hot_path_changed"] is False,
            "pending-attack semantic repair is incomplete or over-broad",
        )
        require(
            all(current_input["predecessor"][key] is True for key in (
                "disk_backed_exact_store_retained",
                "packed_exact_history_retained",
                "compact_exact_state_store_retained",
                "owner_failure_snapshot_repair_retained",
                "component_oom_isolation_retained",
            )),
            "pending-attack successor dropped a predecessor repair",
        )
        retained = current_input["retained_storage_boundary"]
        require(
            contract["resource_policy"][
                "candidate_component_oom_isolated_from_supervisor"
            ]
            is True
            and retained["external_memory_sandbox_path"]
            == contract["resource_policy"]["external_memory_directory"]
            and retained["external_memory_host_root"]
            == contract["resource_policy"]["external_memory_host_root"]
            and retained["external_memory_backing_mode"]
            == contract["resource_policy"]["external_memory_backing_mode"]
            and retained["external_memory_limit_bytes_per_component"]
            == contract["resource_policy"]["external_memory_max_bytes_per_component"]
            and retained["host_free_space_reserve_bytes"]
            == contract["resource_policy"]["external_memory_free_space_reserve_bytes"]
            and retained["external_memory_direct_io_required"] is True
            and retained["guardian_same_boot_cleanup_implemented"] is True
            and retained["guardian_prior_boot_cleanup_implemented"] is True,
            "pending-attack successor drifted from the retained storage boundary",
        )
    elif external_memory_repair_observation:
        require(
            observation["failed_component"]["component_id"]
            == "child-bundle-producer"
            and observation["failed_component"]["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "external-memory failure observation drift",
        )
        require(
            observation["systemd_disposition"][
                "trusted_supervisor_survived_component_oom"
            ]
            is True
            and observation["systemd_disposition"][
                "incomplete_lifecycle_receipt_committed"
            ]
            is True
            and observation["systemd_disposition"][
                "guardian_preserved_final_commit"
            ]
            is True,
            "fifth OOM did not preserve trusted fail-closed finalization",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id,
            "external-memory repair does not bind the failed run",
        )
        repair = current_input["storage_repair"]
        require(
            repair["child_transition_relation_changed"] is False
            and repair["parent_transition_relation_changed"] is False
            and repair["reachable_state_sets_intentionally_changed"] is False
            and repair["exact_state_identity_changed"] is False
            and repair["ordered_evidence_history_quotiented"] is False
            and repair["python_transition_semantics_retained"] is True
            and repair["fixed_width_state_columns_disk_backed"] is True
            and repair["exact_state_index_disk_backed"] is True
            and repair["frontier_and_csr_disk_backed"] is True
            and repair["coaccessibility_reverse_graph_disk_backed"] is True
            and repair["spill_files_unlinked_immediately"] is True
            and repair["spill_files_reopenable_by_path"] is False
            and repair["state_hash_collision_uses_full_field_equality"] is True
            and repair[
                "state_index_zero_marker_encoded_without_sentinel_prefill"
            ]
            is True
            and repair["disk_allocation_failure_is_positive_eligible"] is False
            and repair["memory_swap_reenabled"] is False
            and repair["candidate_can_fill_host_filesystem_beyond_loop_limit"]
            is False
            and repair["guardian_same_boot_cleanup_implemented"] is True
            and repair["guardian_prior_boot_cleanup_implemented"] is True
            and repair["production_linux_scheduler_hot_path_changed"] is False
            and repair["production_monitor_dispatch_hot_path_changed"] is False,
            "disk-backed exact-store repair is incomplete or semantic",
        )
        resource_policy = contract["resource_policy"]
        require(
            resource_policy["candidate_component_oom_isolated_from_supervisor"]
            is True
            and repair["external_memory_sandbox_path"]
            == resource_policy["external_memory_directory"]
            and repair["external_memory_host_root"]
            == resource_policy["external_memory_host_root"]
            and repair["external_memory_filesystem"] == "ext4"
            and resource_policy["external_memory_filesystem"]
            == "vm_native_ext4"
            and repair["external_memory_backing_mode"]
            == resource_policy["external_memory_backing_mode"]
            and repair["external_memory_limit_bytes_per_component"]
            == resource_policy["external_memory_max_bytes_per_component"]
            and repair["host_free_space_reserve_bytes"]
            == resource_policy["external_memory_free_space_reserve_bytes"]
            and repair["external_memory_direct_io_required"]
            == resource_policy["external_memory_direct_io_required"]
            and resource_policy["external_memory_unlinked_temporary_only"]
            is True,
            "external-memory implementation/contract boundary drift",
        )
        equivalence = current_input["mechanical_equivalence"]
        require(
            equivalence["child_bfs_prefix_expanded_states"] == 2000
            and equivalence["retained_exact_states"] == 20510
            and equivalence["edge_count"] == 24920
            and all(
                equivalence[key] is True
                for key in (
                    "state_sequence_equal",
                    "frontier_sequence_equal",
                    "depth_sequence_equal",
                    "target_sequence_equal",
                    "full_collision_equality_retained",
                )
            )
            and equivalence["spill_paths_visible_after_open"] is False,
            "RAM/spill exact-prefix equivalence drift",
        )
        profile = current_input["bounded_storage_profile_non_authoritative"]
        require(
            profile["expanded_states"] == 6000
            and profile["retained_exact_states"] == 60763
            and profile["edges"] == 74443
            and profile["small_working_set_expected_to_remain_cached"] is True
            and profile["reclaimability_beyond_ram_requires_fresh_full_capture"]
            is True
            and profile["performance_claim"] is False
            and profile["full_capacity_guarantee"] is False,
            "bounded storage profile was promoted beyond its evidence",
        )
        require(
            all(current_input["capture_boundary"].values()),
            "external-memory capture boundary is incomplete",
        )
        require(
            current_input["predecessor"]["packed_exact_history_retained"] is True
            and current_input["predecessor"]["compact_exact_state_store_retained"]
            is True
            and current_input["predecessor"][
                "owner_failure_snapshot_semantic_repair_retained"
            ]
            is True
            and current_input["predecessor"]["component_oom_isolation_retained"]
            is True,
            "predecessor repairs were not retained",
        )
    elif packed_history_repair_observation:
        require(
            observation["failed_component"]["component_id"]
            == "child-bundle-producer"
            and observation["failed_component"]["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "packed-history failure observation drift",
        )
        require(
            observation["systemd_disposition"][
                "trusted_supervisor_survived_component_oom"
            ]
            is True
            and observation["systemd_disposition"][
                "incomplete_lifecycle_receipt_committed"
            ]
            is True,
            "fourth OOM did not preserve trusted fail-closed finalization",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id,
            "packed-history repair does not bind the failed run",
        )
        repair = current_input["representation_repair"]
        require(
            repair["child_transition_relation_changed"] is False
            and repair["parent_transition_relation_changed_from_predecessor"]
            is False
            and repair["reachable_state_sets_intentionally_changed"] is False
            and repair["ordered_evidence_history_quotiented"] is False
            and repair["python_transition_semantics_retained"] is True
            and repair["packed_exact_receipt_record_arena"] is True
            and repair["packed_exact_predecessor_history_arena"] is True
            and repair["history_hash_collision_uses_full_value_equality"] is True
            and repair["state_hash_collision_uses_full_field_equality"] is True
            and repair["bounded_direct_mapped_decode_cache_entries"] == 8192
            and repair["bounded_direct_mapped_exact_intern_cache_entries"]
            == 8192
            and repair["intern_cache_collision_or_eviction_changes_only_deduplication"]
            is True
            and repair["exact_state_index_max_load_fraction"] == "4/5"
            and repair["zero_swap_policy_retained"] is True,
            "packed exact history representation repair is incomplete",
        )
        equivalence = current_input["mechanical_equivalence"]
        require(
            equivalence["child_bfs_prefix_expanded_states"] == 2000
            and equivalence["parent_bfs_prefix_expanded_states"] == 1500
            and all(
                equivalence[key] is True
                for key in (
                    "state_order_equal",
                    "state_hashes_equal",
                    "frontier_indices_equal",
                    "target_indices_equal",
                    "action_indices_equal",
                    "ordered_receipt_values_equal",
                    "forced_hash_collision_values_remain_distinct",
                )
            ),
            "packed/list exact-prefix equivalence drift",
        )
        profiles = current_input["bounded_profiles"]
        require(
            profiles["child"]["retained_exact_states"] == 750007
            and profiles["child"]["edges"] == 920973
            and profiles["child"]["successor_max_rss_bytes"]
            < profiles["child"]["predecessor_max_rss_bytes"]
            and profiles["child"][
                "reachable_counters_equal_to_predecessor_profile"
            ]
            is True
            and profiles["parent"]["expanded_states"] == 250000
            and profiles["parent"]["retained_exact_states"] == 545925
            and profiles["parent"]["edges"] == 814132
            and profiles["parent"]["successor_max_rss_bytes"]
            < profiles["parent"]["predecessor_max_rss_bytes"]
            and profiles["parent"][
                "reachable_counters_equal_to_predecessor_profile"
            ]
            is True,
            "bounded packed-history profile drift",
        )
        require(
            current_input["capacity_projection_non_authoritative"]["guarantee"]
            is False
            and current_input["capacity_projection_non_authoritative"][
                "fresh_full_capture_required"
            ]
            is True,
            "capacity projection became authoritative",
        )
        require(
            contract["resource_policy"][
                "candidate_component_oom_isolated_from_supervisor"
            ]
            is True,
            "capture contract does not isolate component OOM",
        )
    elif state_store_repair_observation:
        require(
            observation["failed_component"]["component_id"]
            == "child-bundle-producer"
            and observation["failed_component"]["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "compact-state-store failure observation drift",
        )
        require(
            observation["systemd_disposition"][
                "trusted_supervisor_survived_component_oom"
            ]
            is True
            and observation["systemd_disposition"][
                "incomplete_lifecycle_receipt_committed"
            ]
            is True,
            "third OOM did not preserve trusted fail-closed finalization",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id,
            "state-store repair does not bind the failed run",
        )
        representation = current_input["representation_repair"]
        require(
            representation["child_transition_relation_changed"] is False
            and representation[
                "child_reachable_state_set_intentionally_changed"
            ]
            is False
            and representation["ordered_evidence_history_quotiented"] is False
            and representation["compact_exact_state_store"] is True
            and representation[
                "low_cardinality_fields_use_adaptive_exact_value_codes"
            ]
            is True
            and representation[
                "high_cardinality_fields_retain_direct_references"
            ]
            is True
            and representation["state_store_equality_checks_every_field"] is True
            and representation[
                "state_index_hash_collision_uses_full_state_equality"
            ]
            is True
            and representation["fixed_width_frontier_indices"] is True
            and representation["python_deque_frontier_removed"] is True
            and representation["python_tuple_canonical_state_vector_removed"]
            is True
            and representation["python_set_unique_history_counter_removed"]
            is True
            and representation["fixed_width_csr_retained"] is True
            and representation["zero_swap_policy_retained"] is True,
            "compact exact state-store repair is incomplete",
        )
        parent_repair = current_input["parent_semantic_repair"]
        require(
            parent_repair["semantic_change"] is True
            and parent_repair["exact_state_identity_schema_changed"] is True
            and parent_repair["parent_transition_relation_changed"] is True
            and parent_repair["parent_reachable_state_set_intentionally_changed"]
            is True
            and parent_repair[
                "store_fence_required_before_recovery_controller_publication_prepare"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_local_capsule_at_failure"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_publication_at_failure"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_store_controller_generation_at_failure"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_publication_commitment_at_failure"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_durable_ack_at_failure"
            ]
            is True
            and parent_repair[
                "owner_failure_notice_binds_store_fence_ack_at_failure"
            ]
            is True
            and parent_repair[
                "sealed_owner_failure_phase_uses_authenticated_snapshot"
            ]
            is True
            and parent_repair[
                "later_failover_fence_or_abandonment_cannot_rewrite_failure_phase"
            ]
            is True
            and parent_repair["external_semantic_verdict_authority_changed"]
            is False,
            "owner-failure snapshot semantic repair is incomplete",
        )
        profiles = current_input["bounded_profiles"]
        require(
            profiles["child"]["retained_exact_states"] == 750007
            and profiles["child"]["edges"] == 920973
            and profiles["child"]["successor_max_rss_bytes"]
            < profiles["child"]["predecessor_max_rss_bytes"]
            and profiles["child"][
                "reachable_counters_equal_to_predecessor_profile"
            ]
            is True
            and profiles["parent"]["expanded_states"] == 250000
            and profiles["parent"]["previous_failure_boundary_exceeded"] is True
            and profiles["parent"]["prefix_exhaustive_only"] is True,
            "bounded compact-state profile drift",
        )
        require(
            contract["resource_policy"][
                "candidate_component_oom_isolated_from_supervisor"
            ]
            is True,
            "capture contract does not isolate component OOM",
        )
    elif frontier_repair_observation:
        require(
            observation["failed_component"]["component_id"]
            == "child-bundle-producer"
            and observation["failed_component"]["memory_peak_bytes"]
            == contract["resource_policy"]["memory_max_bytes_per_component"],
            "persistent-frontier failure observation drift",
        )
        require(
            observation["systemd_disposition"][
                "trusted_supervisor_survived_component_oom"
            ]
            is True
            and observation["systemd_disposition"][
                "incomplete_lifecycle_receipt_committed"
            ]
            is True,
            "second OOM did not preserve trusted fail-closed finalization",
        )
        require(
            contract["resource_policy"][
                "candidate_component_oom_isolated_from_supervisor"
            ]
            is True,
            "capture contract does not isolate component OOM",
        )
        require(
            current_input["failed_capture_observation"]["run_id"] == latest_id,
            "frontier repair does not bind the failed run",
        )
        repair = current_input["repair"]
        require(
            repair["exact_state_identity_changed"] is False
            and repair["transition_relation_changed"] is False
            and repair["reachable_state_set_intentionally_changed"] is False
            and repair["ordered_evidence_history_quotiented"] is False,
            "frontier repair changed Candidate-4 semantics",
        )
        require(
            repair["persistent_child_receipt_history"] is True
            and repair["persistent_parent_receipt_history"] is True
            and repair["shared_child_parent_persistent_sequence_implementation"]
            is True
            and repair["persistent_history_collision_uses_full_sequence_equality"]
            is True
            and repair["compact_exact_state_index"] is True
            and repair["state_index_hash_width_bits"] == 64
            and repair["state_index_value_width_bits"] == 32
            and repair["state_index_collision_uses_full_state_equality"] is True
            and repair["python_dict_frontier_index_removed"] is True
            and repair["fixed_width_csr_retained"] is True
            and repair["post_run_reducer_current_input_binding_repaired"] is True
            and repair[
                "future_reducer_input_and_semantic_registry_drift_mechanically_rejected"
            ]
            is True
            and repair["zero_swap_policy_retained"] is True,
            "persistent exact frontier repair is incomplete",
        )
    else:
        require(
            observation["captured_child_model_sha256"]
            != current_input["exact_inputs"]["f0_supervisor_lts_v3.py"],
            "repaired input did not change the rejected child-model bytes",
        )
    if not (
        state_store_repair_observation
        or packed_history_repair_observation
        or external_memory_repair_observation
        or pending_attack_closure_observation
        or behavioral_quotient_observation
    ):
        require(
            current_input["repair"][
                "counterexample_trace_added_to_fast_regression"
            ]
            is True,
            "counterexample regression absent",
        )
        require(
            current_input["repair"]["semantic_change"] is False,
            "repair unexpectedly changed semantics",
        )

    require(g6["gate_status"] == "OPEN", "G6 closed without a complete capture")
    require(g6["complete_capture_available"] is False, "complete G6 bytes claimed absent evidence")
    require(g6["candidate_bytes_positive_eligible"] is False, "G6 raw bytes claimed positive")
    require(g7["gate_status"] == "BLOCKED", "G7 enabled before complete G6")
    require(g7["real_reduction_run"] is False, "G7 real reduction claimed before eligibility")
    require(g7["blocked_reason"] == "NO_COMPLETE_G6_CAPTURE", "G7 block reason drift")

    if install["status"] == "REINSTALL_REQUIRED_AFTER_INPUT_REPAIR":
        require(install["current_inputs_installed"] is False, "pending reinstall marked installed")
        require(g6["retry_eligible"] is False, "G6 retry enabled before clean reinstall")
        require(readiness["status"] == "REINSTALL_REQUIRED", "pending install has positive readiness")
        expected_input_status = "counterexample_repaired_locally_g6_retry_requires_clean_install"
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_reinstall_required_g7_blocked"
        expected_install_action = "counterexample_repaired_clean_install_pending"
        expected_full_action = "blocked_until_repaired_clean_install"
        expected_reducer_status = "PASS_PREDECESSOR_TCB_ONLY"
    elif install["status"] == "PASSED_FOR_REPAIRED_INPUTS":
        require(install["current_inputs_installed"] is True, "passed reinstall not marked installed")
        require(g6["retry_eligible"] is True, "G6 retry not enabled after clean reinstall")
        require(readiness["status"] == "G6_RETRY_ELIGIBLE", "passed install lacks readiness")
        expected_input_status = "counterexample_repaired_clean_installed_g6_retry_eligible"
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_retry_eligible_g7_blocked"
        expected_install_action = "completed_clean_reviewed_install_for_repaired_inputs"
        expected_full_action = "g6_retry_eligible"
        expected_reducer_status = "PASS"
    elif install["status"] == "REINSTALL_REQUIRED_AFTER_RESOURCE_REPAIR":
        require(install["current_inputs_installed"] is False, "pending resource reinstall marked installed")
        require(g6["retry_eligible"] is False, "G6 retry enabled before resource clean reinstall")
        require(readiness["status"] == "REINSTALL_REQUIRED", "pending resource install has positive readiness")
        expected_input_status = "resource_retention_repaired_g6_retry_requires_clean_install"
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_resource_reinstall_required_g7_blocked"
        expected_install_action = "resource_repair_clean_install_pending"
        expected_full_action = "blocked_until_resource_repair_clean_install"
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_RESOURCE_REPAIRED_INPUTS":
        require(install["current_inputs_installed"] is True, "passed resource reinstall not marked installed")
        require(g6["retry_eligible"] is True, "G6 retry not enabled after resource clean reinstall")
        require(readiness["status"] == "G6_RETRY_ELIGIBLE", "passed resource install lacks readiness")
        expected_input_status = "resource_retention_repaired_clean_installed_g6_retry_eligible"
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_resource_retry_eligible_g7_blocked"
        expected_install_action = "completed_clean_reviewed_install_for_resource_repaired_inputs"
        expected_full_action = "g6_resource_retry_eligible"
        expected_reducer_status = "PASS"
    elif install["status"] == "REINSTALL_REQUIRED_AFTER_FRONTIER_REPAIR":
        require(install["current_inputs_installed"] is False, "pending frontier reinstall marked installed")
        require(g6["retry_eligible"] is False, "G6 retry enabled before frontier clean reinstall")
        require(readiness["status"] == "REINSTALL_REQUIRED", "pending frontier install has positive readiness")
        expected_input_status = "persistent_frontier_repaired_g6_retry_requires_clean_install"
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_frontier_reinstall_required_g7_blocked"
        expected_install_action = "frontier_repair_clean_install_pending"
        expected_full_action = "blocked_until_frontier_repair_clean_install"
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_FRONTIER_REPAIRED_INPUTS":
        require(install["current_inputs_installed"] is True, "passed frontier reinstall not marked installed")
        require(g6["retry_eligible"] is True, "G6 retry not enabled after frontier clean reinstall")
        require(readiness["status"] == "G6_RETRY_ELIGIBLE", "passed frontier install lacks readiness")
        expected_input_status = "persistent_frontier_repaired_clean_installed_g6_retry_eligible"
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_frontier_retry_eligible_g7_blocked"
        expected_install_action = "completed_clean_reviewed_install_for_frontier_repaired_inputs"
        expected_full_action = "g6_frontier_retry_eligible"
        expected_reducer_status = "PASS"
    elif install["status"] == "REINSTALL_REQUIRED_AFTER_STATE_STORE_REPAIR":
        require(
            install["current_inputs_installed"] is False,
            "pending state-store reinstall marked installed",
        )
        require(
            g6["retry_eligible"] is False,
            "G6 retry enabled before state-store clean reinstall",
        )
        require(
            readiness["status"] == "REINSTALL_REQUIRED",
            "pending state-store install has positive readiness",
        )
        expected_input_status = (
            "compact_state_store_and_owner_failure_snapshot_repaired_"
            "g6_retry_requires_clean_install"
        )
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_state_store_reinstall_required_"
            "g7_blocked"
        )
        expected_install_action = "state_store_repair_clean_install_pending"
        expected_full_action = "blocked_until_state_store_repair_clean_install"
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_STATE_STORE_REPAIRED_INPUTS":
        require(
            install["current_inputs_installed"] is True,
            "passed state-store reinstall not marked installed",
        )
        require(
            g6["retry_eligible"] is True,
            "G6 retry not enabled after state-store clean reinstall",
        )
        require(
            readiness["status"] == "G6_RETRY_ELIGIBLE",
            "passed state-store install lacks readiness",
        )
        expected_input_status = (
            "compact_state_store_and_owner_failure_snapshot_repaired_clean_"
            "installed_g6_retry_eligible"
        )
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_state_store_retry_eligible_"
            "g7_blocked"
        )
        expected_install_action = (
            "completed_clean_reviewed_install_for_state_store_repaired_inputs"
        )
        expected_full_action = "g6_state_store_retry_eligible"
        expected_reducer_status = "PASS"
    elif install["status"] == "REINSTALL_REQUIRED_AFTER_PACKED_HISTORY_REPAIR":
        require(
            install["current_inputs_installed"] is False,
            "pending packed-history reinstall marked installed",
        )
        require(
            g6["retry_eligible"] is False,
            "G6 retry enabled before packed-history clean reinstall",
        )
        require(
            readiness["status"] == "REINSTALL_REQUIRED",
            "pending packed-history install has positive readiness",
        )
        expected_input_status = (
            "packed_exact_history_repaired_g6_retry_requires_clean_install"
        )
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_packed_history_reinstall_"
            "required_g7_blocked"
        )
        expected_install_action = "packed_history_repair_clean_install_pending"
        expected_full_action = "blocked_until_packed_history_repair_clean_install"
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_PACKED_HISTORY_REPAIRED_INPUTS":
        require(
            install["current_inputs_installed"] is True,
            "passed packed-history reinstall not marked installed",
        )
        require(
            g6["retry_eligible"] is True,
            "G6 retry not enabled after packed-history clean reinstall",
        )
        require(
            readiness["status"] == "G6_RETRY_ELIGIBLE",
            "passed packed-history install lacks readiness",
        )
        expected_input_status = (
            "packed_exact_history_repaired_clean_installed_g6_retry_eligible"
        )
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_packed_history_retry_eligible_"
            "g7_blocked"
        )
        expected_install_action = (
            "completed_clean_reviewed_install_for_packed_history_repaired_inputs"
        )
        expected_full_action = "g6_packed_history_retry_eligible"
        expected_reducer_status = "PASS"
    elif install["status"] == "REINSTALL_REQUIRED_AFTER_EXTERNAL_MEMORY_REPAIR":
        require(
            install["current_inputs_installed"] is False,
            "pending external-memory reinstall marked installed",
        )
        require(
            g6["retry_eligible"] is False,
            "G6 retry enabled before external-memory clean reinstall",
        )
        require(
            readiness["status"] == "REINSTALL_REQUIRED",
            "pending external-memory install has positive readiness",
        )
        expected_input_status = (
            "disk_backed_exact_store_repaired_g6_retry_requires_clean_install"
        )
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_external_memory_reinstall_"
            "required_g7_blocked"
        )
        expected_install_action = "external_memory_repair_clean_install_pending"
        expected_full_action = (
            "blocked_until_external_memory_repair_clean_install"
        )
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_EXTERNAL_MEMORY_REPAIRED_INPUTS":
        require(
            install["current_inputs_installed"] is True,
            "passed external-memory reinstall not marked installed",
        )
        require(
            g6["retry_eligible"] is True,
            "G6 retry not enabled after external-memory clean reinstall",
        )
        require(
            readiness["status"] == "G6_RETRY_ELIGIBLE",
            "passed external-memory install lacks readiness",
        )
        expected_input_status = (
            "disk_backed_exact_store_repaired_clean_installed_g6_retry_eligible"
        )
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_external_memory_retry_eligible_"
            "g7_blocked"
        )
        expected_install_action = (
            "completed_clean_reviewed_install_for_external_memory_repaired_inputs"
        )
        expected_full_action = "g6_external_memory_retry_eligible"
        expected_reducer_status = "PASS"
    elif (
        install["status"]
        == "REINSTALL_REQUIRED_AFTER_PENDING_ATTACK_CLOSURE_REPAIR"
    ):
        require(
            install["current_inputs_installed"] is False,
            "pending attack-closure reinstall marked installed",
        )
        require(
            g6["retry_eligible"] is False,
            "G6 retry enabled before pending attack-closure clean reinstall",
        )
        require(
            readiness["status"] == "REINSTALL_REQUIRED",
            "pending attack-closure install has positive readiness",
        )
        expected_input_status = (
            "pending_attack_closure_repaired_g6_retry_requires_clean_install"
        )
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_pending_attack_closure_"
            "reinstall_required_g7_blocked"
        )
        expected_install_action = (
            "pending_attack_closure_repair_clean_install_pending"
        )
        expected_full_action = (
            "blocked_until_pending_attack_closure_repair_clean_install"
        )
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif (
        install["status"]
        == "PASSED_FOR_PENDING_ATTACK_CLOSURE_REPAIRED_INPUTS"
    ):
        require(
            install["current_inputs_installed"] is True,
            "passed pending attack-closure reinstall not marked installed",
        )
        require(
            g6["retry_eligible"] is True,
            "G6 retry not enabled after pending attack-closure clean reinstall",
        )
        require(
            readiness["status"] == "G6_RETRY_ELIGIBLE",
            "passed pending attack-closure install lacks readiness",
        )
        expected_input_status = (
            "pending_attack_closure_repaired_clean_installed_g6_retry_eligible"
        )
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_pending_attack_closure_"
            "retry_eligible_g7_blocked"
        )
        expected_install_action = (
            "completed_clean_reviewed_install_for_pending_attack_closure_"
            "repaired_inputs"
        )
        expected_full_action = "g6_pending_attack_closure_retry_eligible"
        expected_reducer_status = "PASS"
    elif (
        install["status"]
        == "REINSTALL_REQUIRED_AFTER_BEHAVIORAL_AUDIT_QUOTIENT"
    ):
        require(
            install["current_inputs_installed"] is False,
            "pending behavioral-quotient reinstall marked installed",
        )
        require(
            g6["retry_eligible"] is False,
            "G6 retry enabled before behavioral-quotient clean reinstall",
        )
        require(
            readiness["status"] == "REINSTALL_REQUIRED",
            "pending behavioral-quotient install has positive readiness",
        )
        expected_input_status = (
            "behavioral_audit_quotient_validated_locally_"
            "g6_retry_requires_clean_install"
        )
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_behavioral_quotient_reinstall_"
            "required_g7_blocked"
        )
        expected_install_action = "behavioral_audit_quotient_clean_install_pending"
        expected_full_action = (
            "blocked_until_behavioral_audit_quotient_clean_install"
        )
        expected_reducer_status = "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
    elif install["status"] == "PASSED_FOR_BEHAVIORAL_AUDIT_QUOTIENT_INPUTS":
        require(
            install["current_inputs_installed"] is True,
            "passed behavioral-quotient reinstall not marked installed",
        )
        require(
            g6["retry_eligible"] is True,
            "G6 retry not enabled after behavioral-quotient clean reinstall",
        )
        require(
            readiness["status"] == "G6_RETRY_ELIGIBLE",
            "passed behavioral-quotient install lacks readiness",
        )
        expected_input_status = (
            "behavioral_audit_quotient_clean_installed_g6_retry_eligible"
        )
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = (
            "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        )
        expected_track_status = (
            "open_candidate4_g1_g5_closed_g6_behavioral_quotient_retry_"
            "eligible_g7_blocked"
        )
        expected_install_action = (
            "completed_clean_reviewed_install_for_behavioral_audit_quotient_inputs"
        )
        expected_full_action = "g6_behavioral_audit_quotient_retry_eligible"
        expected_reducer_status = "PASS"
    else:
        raise ConsistencyError(f"unknown clean-install status: {install['status']}")

    require(install["readiness_record"] == state["canonical_files"]["f0_c4_g6_retry_readiness"], "readiness path drift")
    require(install["readiness_sha256"] == readiness["artifact_sha256"], "readiness digest drift")
    require(readiness["current_inputs"]["artifact_id"] == current["artifact_id"], "readiness input id drift")
    require(readiness["current_inputs"]["artifact_sha256"] == current["artifact_sha256"], "readiness input digest drift")
    require(readiness["current_inputs"]["hostile_case_counts"] == current["hostile_case_counts"], "readiness hostile counts drift")
    require(readiness["current_inputs"]["fast_validator_status"] == current["fast_validator_status"], "readiness fast status drift")
    require(readiness["clean_install"]["source_commit"] == install["installed_source_commit"], "readiness install commit drift")
    require(readiness["clean_install"]["installed_manifest_sha256"] == install["installed_manifest_sha256"], "readiness install manifest drift")
    require(readiness["clean_install"]["source_worktree_clean"] is True, "readiness source was dirty")
    require(readiness["clean_install"]["committed_state_check"] == "PASS", "readiness committed state check absent")
    require(readiness["clean_install"]["current_inputs_installed"] == install["current_inputs_installed"], "readiness current-install flag drift")
    require(readiness["toolchain"]["format"] == capture["immutable_toolchain"]["format"], "readiness toolchain format drift")
    require(readiness["toolchain"]["image_sha256"] == capture["immutable_toolchain"]["sha256"], "readiness toolchain digest drift")
    require(readiness["toolchain"]["mounted_read_only"] is True, "readiness toolchain is writable")
    require(readiness["toolchain"]["reuse_regression_cases"] == capture["short_regression"]["toolchain_reuse_cases"], "readiness reuse regression drift")
    require(readiness["mechanism_recheck"]["capture_contract_sha256"] == capture["canonical_sha256"], "readiness contract drift")
    require(readiness["mechanism_recheck"]["capture_contract_hostile_cases"] == capture["hostile_mutation_cases"], "readiness hostile contract count drift")
    require(readiness["mechanism_recheck"]["capture_contract_derived_cases"] == capture["derived_semantic_cases"], "readiness derived contract count drift")
    require(readiness["mechanism_recheck"]["capture_resource_policy_cases"] == capture["short_regression"]["capture_resource_policy_cases"], "readiness resource-policy count drift")
    require(readiness["mechanism_recheck"]["launcher_idle_cases"] == capture["short_regression"]["launcher_idle_cases"], "readiness launcher-idle count drift")
    require(readiness["mechanism_recheck"]["reproducible_build_cases"] == capture["short_regression"]["reproducible_build_cases"], "readiness reproducible-build count drift")
    require(readiness["current_inputs"]["model_memory_policy_cases"] == capture["short_regression"]["model_memory_policy_cases"], "readiness model-memory count drift")
    require(readiness["current_inputs"]["model_storage_equivalence_cases"] == capture["short_regression"]["model_storage_equivalence_cases"], "readiness model-storage-equivalence count drift")
    require(readiness["current_inputs"]["behavioral_quotient_boundary_cases"] == capture["short_regression"]["behavioral_quotient_boundary_cases"], "readiness behavioral-quotient count drift")
    require(readiness["current_inputs"]["reducer_current_input_binding_cases"] == capture["short_regression"]["reducer_current_input_binding_cases"], "readiness reducer-input count drift")
    require(readiness["mechanism_recheck"]["external_memory_recovery_cases"] == capture["short_regression"]["external_memory_recovery_cases"], "readiness external-memory-recovery count drift")
    require(readiness["mechanism_recheck"]["reducer_current_input_binding_cases"] == capture["short_regression"]["reducer_current_input_binding_cases"], "readiness reducer-binding mechanism count drift")
    require(readiness["mechanism_recheck"]["reducer_boundary_status"] == expected_reducer_status, "readiness reducer boundary status drift")
    require(readiness["mechanism_recheck"]["reducer_boundary_cases"] == capture["short_regression"]["reducer_cases"], "readiness reducer cases drift")
    reproducible_install = readiness["clean_install"].get(
        "reproducible_build_repair_installed"
    )
    if reproducible_install is not None:
        require(
            isinstance(reproducible_install, bool),
            "reproducible-build install flag is not Boolean",
        )
        for key in (
            "installed_build_install_sha256",
            "current_build_install_sha256",
            "current_build_reproducibility_test_sha256",
        ):
            value = readiness["clean_install"].get(key)
            require(
                isinstance(value, str)
                and len(value) == 64
                and all(character in "0123456789abcdef" for character in value),
                f"reproducible-build digest malformed: {key}",
            )
        require(
            (
                readiness["clean_install"]["installed_build_install_sha256"]
                == readiness["clean_install"]["current_build_install_sha256"]
            )
            is reproducible_install,
            "reproducible-build install flag/source relation drift",
        )
        expected_reproducible_status = (
            "PASS"
            if reproducible_install
            else "PASS_SOURCE_REPAIRED_INSTALLED_TCB_STALE"
        )
        require(
            readiness["mechanism_recheck"]["reproducible_build_status"]
            == expected_reproducible_status,
            "reproducible-build mechanism status drift",
        )
    require(readiness["source_transfer"]["policy"] == "clean_git_archive_exact_eight_inputs_to_vm_native_root_owned_read_only_staging", "readiness source-transfer policy drift")
    require(readiness["source_transfer"]["macos_home_mount"] == "none", "readiness grants macOS home access")
    require(readiness["source_transfer"]["vm_source_root"] == "/var/lib/domainlease-f0-c4/sources", "readiness source root drift")
    require(readiness["source_transfer"]["raw_evidence_root"] == "/var/lib/domainlease-f0-c4/evidence", "readiness evidence root drift")
    require(readiness["source_transfer"]["separate_from_raw_evidence"] is True, "source and evidence roots are not separated")
    require(readiness["disposition"]["g6_gate_status"] == g6["gate_status"], "readiness G6 status drift")
    require(readiness["disposition"]["g6_retry_eligible"] == g6["retry_eligible"], "readiness G6 eligibility drift")
    require(readiness["disposition"]["g6_complete_capture_available"] == g6["complete_capture_available"], "readiness G6 completion drift")
    require(readiness["disposition"]["g7_gate_status"] == g7["gate_status"], "readiness G7 status drift")
    require(readiness["disposition"]["g7_blocked_reason"] == g7["blocked_reason"], "readiness G7 reason drift")
    for key, value in readiness["authorization"].items():
        require(value is False, f"readiness granted unsupported authority: {key}")

    require(current["status"] == expected_input_status, "current input/install status drift")
    require(state["project"]["current_phase"] == expected_phase, "project phase drift")
    require(capture["status"] == expected_capture_status, "capture status drift")

    tracks = objects_by_id(state["planned_tracks"], "planned track")
    require(tracks["ROOTSCHED-001"]["status"] == "model_supported_ec1", "ROOTSCHED track drift")
    require(tracks["RESIDENCY-001"]["status"] == "model_supported_ec1", "RESIDENCY track drift")
    require(tracks["EVIDENCE-001"]["status"].startswith("partial_"), "EVIDENCE track drift")
    require(tracks["RESIDENCY-DYN-001"]["status"] == expected_track_status, "RESIDENCY-DYN track drift")
    for track_id in (
        "ENTRY-001+CODE-001",
        "STATE-001+SVC-001+MGMT-001",
        "CLUSTER-PART-001",
        "COMPOSE-001",
        "GRANULARITY-001",
    ):
        require(tracks[track_id]["status"] == "open", f"open track drift: {track_id}")

    actions = objects_by_id(state["next_actions"], "next action")
    require(
        actions["F0-C4-AUTHORITY-DISJOINT-LAUNCHER"]["status"]
        == expected_install_action,
        "clean-install action drift",
    )
    require(
        actions["F0-C4-FULL-LOCAL"]["status"] == expected_full_action,
        "G6 next-action drift",
    )


def extract_handoff_projection(text: str) -> dict[str, Any]:
    require(text.count(PROJECTION_BEGIN) == 1, "handoff projection begin marker missing/duplicate")
    require(text.count(PROJECTION_END) == 1, "handoff projection end marker missing/duplicate")
    body = text.split(PROJECTION_BEGIN, 1)[1].split(PROJECTION_END, 1)[0].strip()
    match = re.fullmatch(r"```json\s*(\{.*\})\s*```", body, flags=re.DOTALL)
    require(match is not None, "handoff projection must be one JSON code block")
    try:
        value = json.loads(match.group(1), object_pairs_hook=unique_object)
    except json.JSONDecodeError as error:
        raise ConsistencyError(f"invalid handoff projection JSON: {error}") from error
    require(isinstance(value, dict), "handoff projection must be an object")
    return value


def validate_repo(repo_root: Path, *, self_test: bool) -> dict[str, Any]:
    state_path = repo_root / "capsched-ai/state/state.json"
    state = load_json(state_path)
    canonical = state["canonical_files"]

    def canonical_json(key: str) -> tuple[Path, dict[str, Any]]:
        path = repo_root / canonical[key]
        return path, load_json(path)

    claims_path, claims = canonical_json("assurance_register")
    contract_path, contract = canonical_json("f0_c4_capture_contract")
    current_path, current_input = canonical_json("f0_c4_current_input_contract")
    observation_path, observation = canonical_json("f0_c4_g6_incomplete_record")
    readiness_path, readiness = canonical_json("f0_c4_g6_retry_readiness")
    current_input["artifact_sha256"] = sha256_file(current_path)
    observation["artifact_sha256"] = sha256_file(observation_path)
    readiness["artifact_sha256"] = sha256_file(readiness_path)

    require(
        state["evidence"]["current_candidate_inputs"]["artifact_sha256"]
        == current_input["artifact_sha256"],
        "current-input record file digest mismatch",
    )
    latest = state["evidence"]["authority_capture_contract"]["g6"]["attempt_history"][-1]
    require(
        latest["observation_sha256"] == observation["artifact_sha256"],
        "G6 observation file digest mismatch",
    )
    for name, expected in current_input["exact_inputs"].items():
        path = repo_root / "capsched-models/validation" / name
        require(path.is_file(), f"current Candidate-4 input missing: {name}")
        require(sha256_file(path) == expected, f"current Candidate-4 input digest mismatch: {name}")

    installed_commit = state["evidence"]["authority_capture_contract"]["clean_install"][
        "installed_source_commit"
    ]
    ancestry = subprocess.run(
        ["git", "-C", str(repo_root), "merge-base", "--is-ancestor", installed_commit, "HEAD"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    require(ancestry.returncode == 0, "installed source commit is not in current lineage")
    installed_input_mismatches = 0
    for name, expected in current_input["exact_inputs"].items():
        relative = f"capsched-models/validation/{name}"
        blob = subprocess.run(
            ["git", "-C", str(repo_root), "show", f"{installed_commit}:{relative}"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        if blob.returncode != 0 or hashlib.sha256(blob.stdout).hexdigest() != expected:
            installed_input_mismatches += 1
    current_inputs_installed = state["evidence"]["authority_capture_contract"][
        "clean_install"
    ]["current_inputs_installed"]
    reproducible_build_repair_installed = readiness["clean_install"].get(
        "reproducible_build_repair_installed"
    )
    if current_inputs_installed:
        require(
            installed_input_mismatches == 0,
            "installed commit does not contain every current exact input",
        )
        if reproducible_build_repair_installed is not None:
            require(
                reproducible_build_repair_installed is True,
                "current install omits the reproducible-build repair",
            )
    else:
        require(
            installed_input_mismatches > 0
            or reproducible_build_repair_installed is False,
            "reinstall is required even though installed inputs already match",
        )
    if reproducible_build_repair_installed is not None:
        build_paths = {
            "current_build_install_sha256": (
                "capsched-models/validation/f0-c4-capture/build-install.sh"
            ),
            "current_build_reproducibility_test_sha256": (
                "capsched-models/validation/f0-c4-capture/"
                "test-build-reproducibility.sh"
            ),
        }
        for digest_key, relative in build_paths.items():
            require(
                hashlib.sha256((repo_root / relative).read_bytes()).hexdigest()
                == readiness["clean_install"][digest_key],
                f"reproducible-build source digest drift: {relative}",
            )
        installed_build = subprocess.run(
            [
                "git",
                "-C",
                str(repo_root),
                "show",
                f"{installed_commit}:capsched-models/validation/"
                "f0-c4-capture/build-install.sh",
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        require(
            installed_build.returncode == 0
            and hashlib.sha256(installed_build.stdout).hexdigest()
            == readiness["clean_install"]["installed_build_install_sha256"],
            "installed build script digest drift",
        )
        if reproducible_build_repair_installed:
            require(
                readiness["clean_install"]["installed_build_install_sha256"]
                == readiness["clean_install"]["current_build_install_sha256"],
                "installed reproducible-build source is stale",
            )
        else:
            require(
                readiness["clean_install"]["installed_build_install_sha256"]
                != readiness["clean_install"]["current_build_install_sha256"],
                "reproducible-build reinstall claimed pending without source drift",
            )

    active = state["evidence"]["authority_capture_contract"]["g6"][
        "active_attempt"
    ]
    if active is not None:
        active_commit = active["candidate_input_commit"]
        active_ancestry = subprocess.run(
            [
                "git",
                "-C",
                str(repo_root),
                "merge-base",
                "--is-ancestor",
                active_commit,
                "HEAD",
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        require(
            active_ancestry.returncode == 0,
            "active G6 input commit is not in current lineage",
        )
        for name, expected in current_input["exact_inputs"].items():
            relative = f"capsched-models/validation/{name}"
            blob = subprocess.run(
                ["git", "-C", str(repo_root), "show", f"{active_commit}:{relative}"],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            require(
                blob.returncode == 0
                and hashlib.sha256(blob.stdout).hexdigest() == expected,
                f"active G6 input commit differs: {name}",
            )

    validate_semantics(state, claims, contract, current_input, observation, readiness)

    handoff_path = repo_root / canonical["handoff"]
    projection = extract_handoff_projection(handoff_path.read_text(encoding="utf-8"))
    require(projection == current_projection(state, claims), "handoff/state projection drift")

    starter = (
        repo_root
        / "capsched-models/validation/f0-c4-capture/start-candidate4-full-capture.sh"
    ).read_text(encoding="utf-8")
    require(
        ".evidence.authority_capture_contract.g6.active_attempt == null" in starter,
        "G6 starter does not reject a concurrent active attempt",
    )
    require(
        "behavioral_audit_quotient_clean_installed_g6_retry_eligible"
        in starter
        and "PASSED_FOR_BEHAVIORAL_AUDIT_QUOTIENT_INPUTS" in starter,
        "G6 starter is not bound to the behavioral-quotient readiness state",
    )

    stable_pointer_requirements = {
        "capsched/README.md": "Volatile campaign status is intentionally not duplicated here",
        "capsched-models/index.md": "Volatile campaign status is intentionally not duplicated in this index",
        "capsched-models/plans/0006-final-compositional-model-completion-plan.md": "Volatile execution status is intentionally not duplicated in this plan",
    }
    for relative, sentence in stable_pointer_requirements.items():
        document = (repo_root / relative.removeprefix("capsched/")).read_text(
            encoding="utf-8"
        )
        normalized = " ".join(document.split())
        require(sentence in normalized, f"current-state pointer policy missing: {relative}")

    hostile_cases = 0
    if self_test:
        mutations: list[
            tuple[
                str,
                dict[str, Any],
                dict[str, Any],
                dict[str, Any],
                dict[str, Any],
                dict[str, Any],
                dict[str, Any],
            ]
        ] = []

        def add_state_mutation(label: str, mutate) -> None:
            changed = copy.deepcopy(state)
            mutate(changed)
            mutations.append(
                (label, changed, claims, contract, current_input, observation, readiness)
            )

        add_state_mutation(
            "stale planned-track status",
            lambda value: value["planned_tracks"][3].__setitem__(
                "status", "open_candidate4_capture_contract_g1_g2_closed_g3_g7_open"
            ),
        )
        add_state_mutation(
            "G7 enabled without complete G6",
            lambda value: value["evidence"]["authority_capture_contract"]["g7"].__setitem__(
                "gate_status", "OPEN"
            ),
        )
        add_state_mutation(
            "capture gate omitted",
            lambda value: value["evidence"]["authority_capture_contract"]["remaining_gates"].pop(),
        )
        add_state_mutation(
            "hostile count drift",
            lambda value: value["evidence"]["current_candidate_inputs"]["hostile_case_counts"].__setitem__(
                "total", 1
            ),
        )
        add_state_mutation(
            "retry/install relation drift",
            lambda value: value["evidence"]["authority_capture_contract"]["g6"].__setitem__(
                "retry_eligible",
                not value["evidence"]["authority_capture_contract"]["g6"]["retry_eligible"],
            ),
        )
        add_state_mutation(
            "observation identity drift",
            lambda value: value["evidence"]["authority_capture_contract"]["g6"]["attempt_history"][-1].__setitem__(
                "observation_sha256", "0" * 64
            ),
        )
        if (
            state["evidence"]["authority_capture_contract"]["g6"][
                "active_attempt"
            ]
            is not None
        ):
            add_state_mutation(
                "active G6 aliases a completed run",
                lambda value: value["evidence"]["authority_capture_contract"]["g6"][
                    "active_attempt"
                ].__setitem__(
                    "run_id",
                    value["evidence"]["authority_capture_contract"]["g6"][
                        "latest_completed_attempt_run_id"
                    ],
                ),
            )
            add_state_mutation(
                "active G6 claims finalized evidence",
                lambda value: value["evidence"]["authority_capture_contract"]["g6"][
                    "active_attempt"
                ].__setitem__("evidence_commit_available", True),
            )
        changed_claims = copy.deepcopy(claims)
        next(item for item in changed_claims["claims"] if item["id"] == "COMPOSE-001")["status"] = "model_supported"
        mutations.append(
            (
                "claim status drift",
                state,
                changed_claims,
                contract,
                current_input,
                observation,
                readiness,
            )
        )
        changed_observation = copy.deepcopy(observation)
        if "raw_commit" in changed_observation:
            changed_observation["raw_commit"]["candidate_bytes_positive_eligible"] = True
        else:
            changed_observation["durable_evidence"][
                "candidate_bytes_positive_eligible"
            ] = True
        mutations.append(
            (
                "incomplete bytes promoted",
                state,
                claims,
                contract,
                current_input,
                changed_observation,
                readiness,
            )
        )
        changed_readiness = copy.deepcopy(readiness)
        changed_readiness["clean_install"]["installed_manifest_sha256"] = "0" * 64
        mutations.append(
            (
                "readiness install identity drift",
                state,
                claims,
                contract,
                current_input,
                observation,
                changed_readiness,
            )
        )
        if "current_build_install_sha256" in readiness["clean_install"]:
            changed_readiness = copy.deepcopy(readiness)
            changed_readiness["clean_install"][
                "reproducible_build_repair_installed"
            ] = not changed_readiness["clean_install"][
                "reproducible_build_repair_installed"
            ]
            mutations.append(
                (
                    "reproducible-build source identity drift",
                    state,
                    claims,
                    contract,
                    current_input,
                    observation,
                    changed_readiness,
                )
            )
        changed_input = copy.deepcopy(current_input)
        if "behavioral_quotient" in changed_input:
            changed_input["behavioral_quotient"][
                "receipt_semantic_facts_and_multiplicity_retained"
            ] = False
        elif "storage_repair" in changed_input:
            changed_input["storage_repair"]["exact_state_identity_changed"] = True
        elif "repair" in changed_input:
            changed_input["repair"]["exact_state_identity_changed"] = True
        elif "semantic_repair" in changed_input:
            changed_input["semantic_repair"]["exact_state_identity_changed"] = True
        else:
            changed_input["representation_repair"][
                "ordered_evidence_history_quotiented"
            ] = True
        mutations.append(
            (
                "exact representation repair is weakened",
                state,
                claims,
                contract,
                changed_input,
                observation,
                readiness,
            )
        )
        changed_contract = copy.deepcopy(contract)
        changed_contract["resource_policy"][
            "candidate_component_oom_isolated_from_supervisor"
        ] = False
        mutations.append(
            (
                "component OOM isolation removed",
                state,
                claims,
                changed_contract,
                current_input,
                observation,
                readiness,
            )
        )
        changed_input = copy.deepcopy(current_input)
        if "behavioral_quotient" in changed_input:
            changed_input["behavioral_quotient"][
                "projection_hash_matches_resolved_by_full_equality"
            ] = False
        elif "storage_repair" in changed_input:
            changed_input["storage_repair"][
                "python_transition_semantics_retained"
            ] = False
        elif "repair" in changed_input:
            changed_input["repair"][
                "future_reducer_input_and_semantic_registry_drift_mechanically_rejected"
            ] = False
        elif "parent_semantic_repair" in changed_input:
            changed_input["parent_semantic_repair"][
                "sealed_owner_failure_phase_uses_authenticated_snapshot"
            ] = False
        elif "semantic_repair" in changed_input:
            changed_input["semantic_repair"][
                "closure_requires_pending_attack_none"
            ] = False
        else:
            changed_input["representation_repair"][
                "python_transition_semantics_retained"
            ] = False
        mutations.append(
            (
                "successor semantic drift prevention removed",
                state,
                claims,
                contract,
                changed_input,
                observation,
                readiness,
            )
        )

        for (
            label,
            mutated_state,
            mutated_claims,
            mutated_contract,
            mutated_input,
            mutated_observation,
            mutated_readiness,
        ) in mutations:
            try:
                validate_semantics(
                    mutated_state,
                    mutated_claims,
                    mutated_contract,
                    mutated_input,
                    mutated_observation,
                    mutated_readiness,
                )
            except ConsistencyError:
                hostile_cases += 1
            else:
                raise ConsistencyError(f"self-test mutation passed: {label}")

    return {
        "status": "pass",
        "state": str(state_path.relative_to(repo_root)),
        "claims": str(claims_path.relative_to(repo_root)),
        "contract": str(contract_path.relative_to(repo_root)),
        "current_input": str(current_path.relative_to(repo_root)),
        "g6_observation": str(observation_path.relative_to(repo_root)),
        "g6_retry_readiness": str(readiness_path.relative_to(repo_root)),
        "handoff_projection": "exact",
        "hostile_self_test_cases": hostile_cases,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        result = validate_repo(arguments.repo_root.resolve(), self_test=arguments.self_test)
    except (ConsistencyError, KeyError, TypeError, StopIteration) as error:
        print(f"error: current-state semantic inconsistency: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
