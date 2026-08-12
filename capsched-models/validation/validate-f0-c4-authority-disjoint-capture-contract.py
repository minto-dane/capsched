#!/usr/bin/env python3
"""Strict validator for the Candidate-4 authority-disjoint capture contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Iterable


class ContractError(ValueError):
    """The contract is malformed or semantically weaker than version 1."""


CONTRACT_PATH = (
    Path(__file__).resolve().parents[1]
    / "analysis"
    / "f0-c4-authority-disjoint-capture-contract-v1.json"
)

TOP_LEVEL_KEYS = {
    "schema_version",
    "artifact_id",
    "status",
    "reasoning_profile",
    "claim_boundary",
    "trust_boundary",
    "platform_requirements",
    "roles",
    "object_authority",
    "input_snapshot",
    "component_plan",
    "containment",
    "observation",
    "finalization",
    "state_machines",
    "failure_taxonomy",
    "resource_policy",
    "invariants",
    "positive_eligibility",
    "performance_boundary",
    "implementation_gates",
    "authorization",
    "nonclaims",
}

SUPPORTED_CLAIMS = [
    "F0-C4-FAST-MUTATION-AND-STATIC-v1",
    "F0-C4-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1",
    "F0-C4-REACH-PARENT-EXACT-REPETITION-BOUNDED-v1",
    "F0-C4-DECLARED-LOCAL-EFFECT-COMMUTATION-v1",
]

OPEN_CLAIMS = [
    "F0-C4-INDEPENDENCE-RELATION-COMPLETE-v1",
    "F0-C4-EXTERNAL-AUTHENTICATION-v1",
    "F0-C4-ATTACK-CONTEXT-KEY-REFINEMENT-v1",
    "F0-C4-UNBOUNDED-REPEATED-ATTACK-HISTORY-v1",
    "F0-C4-DURABLE-STORE-LINEARIZATION-REFINEMENT-v1",
    "F0-C4-PARENT-CHILD-INDEPENDENCE-REFINEMENT-v1",
    "F0-LOCAL-ACCEPTANCE-v1",
]

PLATFORM_IDS = [
    "PLAT-CGROUP2-UNIFIED",
    "PLAT-CGROUP-KILL",
    "PLAT-CGROUP-EVENTS",
    "PLAT-PIDFD-WAITID",
    "PLAT-CLONE-INTO-CGROUP",
    "PLAT-DEDICATED-CAPTURE-VM",
    "PLAT-DEDICATED-UID",
    "PLAT-MOUNT-NAMESPACE",
    "PLAT-NETWORK-DISABLED",
    "PLAT-ROOT-OWNED-STORAGE",
    "PLAT-IMMUTABLE-TOOLCHAIN",
    "PLAT-MONOTONIC-DEADLINE",
    "PLAT-ATOMIC-DURABILITY",
    "PLAT-SUPERVISOR-GUARDIAN",
    "PLAT-BOOT-RECONCILIATION",
    "PLAT-PREEXEC-ATTESTATION",
    "PLAT-CAPACITY-RESERVE",
]

PLATFORM_SEMANTIC_ANCHORS = {
    "PLAT-CGROUP2-UNIFIED": ("unified cgroup v2", "mountinfo"),
    "PLAT-CGROUP-KILL": ("cgroup.kill", "post-kill receipt"),
    "PLAT-CGROUP-EVENTS": ("populated 0", "cgroup.events bytes"),
    "PLAT-PIDFD-WAITID": ("waitid P_PIDFD", "wait receipt"),
    "PLAT-CLONE-INTO-CGROUP": ("clone3 CLONE_INTO_CGROUP", "before exec release"),
    "PLAT-DEDICATED-CAPTURE-VM": ("pinned dedicated VM identity", "reserved-range receipt"),
    "PLAT-DEDICATED-UID": ("VM-policy-reserved", "allocation lock receipt"),
    "PLAT-MOUNT-NAMESPACE": ("private mount namespace", "pre-exec stub"),
    "PLAT-NETWORK-DISABLED": ("private network namespace", "interface inventory"),
    "PLAT-ROOT-OWNED-STORAGE": ("VM-native filesystem", "filesystem-type"),
    "PLAT-IMMUTABLE-TOOLCHAIN": ("content-addressed read-only", "image manifest"),
    "PLAT-MONOTONIC-DEADLINE": ("CLOCK_MONOTONIC", "timerfd"),
    "PLAT-ATOMIC-DURABILITY": ("durable commit marker", "parent-fsync receipt"),
    "PLAT-SUPERVISOR-GUARDIAN": ("root service manager", "fault-injection receipt"),
    "PLAT-BOOT-RECONCILIATION": ("boot reconciliation", "boot-id comparison"),
    "PLAT-PREEXEC-ATTESTATION": ("exact fd table", "pre-exec observation bytes"),
    "PLAT-CAPACITY-RESERVE": ("guardian reserve", "derived inequality receipt"),
}

ROLE_POLICY = {
    "CANDIDATE_SOURCE": (
        "untrusted_repository_source", False, False, False, False, False
    ),
    "CAPTURE_INSTALLER": (
        "root_offline_reviewed_commit_installer", True, False, False, False, False
    ),
    "ROOT_GUARDIAN": (
        "root_service_manager", True, False, False, True, False
    ),
    "CAPTURE_SUPERVISOR": (
        "root_locked_service", True, True, False, True, False
    ),
    "CANDIDATE_COMPONENT": (
        "dedicated_reserved_nonroot", False, False, False, False, False
    ),
    "REDUCTION_SUPERVISOR": (
        "root_locked_service_distinct_from_capture", True, False, True, False, False
    ),
    "POST_RUN_REDUCER": (
        "dedicated_nonroot_validator_distinct_from_candidate",
        True,
        False,
        False,
        False,
        False,
    ),
    "EXTERNAL_APPROVER": (
        "outside_local_capture_system", False, False, False, False, False
    ),
}

OBJECT_AUTHORITY_ACTIONS = ["read", "byte_produce", "create", "append", "finalize"]

OBJECT_AUTHORITY_POLICY = {
    "CANDIDATE_SOURCE_OBJECT": (
        ["CAPTURE_SUPERVISOR"],
        ["CANDIDATE_SOURCE"],
        ["CANDIDATE_SOURCE"],
        ["CANDIDATE_SOURCE"],
        [],
    ),
    "TRUSTED_CAPTURE_ARTIFACT": (
        ["CAPTURE_INSTALLER", "ROOT_GUARDIAN", "CAPTURE_SUPERVISOR", "REDUCTION_SUPERVISOR"],
        ["CAPTURE_INSTALLER"],
        ["CAPTURE_INSTALLER"],
        [],
        ["CAPTURE_INSTALLER"],
    ),
    "TOOLCHAIN_IMAGE": (
        ["CAPTURE_INSTALLER", "CAPTURE_SUPERVISOR", "CANDIDATE_COMPONENT", "REDUCTION_SUPERVISOR", "POST_RUN_REDUCER"],
        ["CAPTURE_INSTALLER"],
        ["CAPTURE_INSTALLER"],
        [],
        ["CAPTURE_INSTALLER"],
    ),
    "INPUT_SNAPSHOT": (
        ["CAPTURE_SUPERVISOR", "CANDIDATE_COMPONENT"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
    ),
    "RUN_INTENT": (
        ["ROOT_GUARDIAN", "CAPTURE_SUPERVISOR"],
        ["ROOT_GUARDIAN"],
        ["ROOT_GUARDIAN"],
        [],
        ["ROOT_GUARDIAN"],
    ),
    "RAW_STREAM": (
        ["CAPTURE_SUPERVISOR", "REDUCTION_SUPERVISOR"],
        ["CANDIDATE_COMPONENT"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
    ),
    "PREEXEC_OBSERVATION": (
        ["CAPTURE_SUPERVISOR", "REDUCTION_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
    ),
    "LIFECYCLE_RECEIPT": (
        ["CAPTURE_SUPERVISOR", "REDUCTION_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        [],
        ["CAPTURE_SUPERVISOR"],
    ),
    "GUARDIAN_FAILURE_RECEIPT": (
        ["ROOT_GUARDIAN", "REDUCTION_SUPERVISOR"],
        ["ROOT_GUARDIAN"],
        ["ROOT_GUARDIAN"],
        [],
        ["ROOT_GUARDIAN"],
    ),
    "RAW_MANIFEST": (
        ["CAPTURE_SUPERVISOR", "ROOT_GUARDIAN", "REDUCTION_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        ["CAPTURE_SUPERVISOR"],
        [],
        ["CAPTURE_SUPERVISOR"],
    ),
    "RAW_COMMIT_MARKER": (
        ["ROOT_GUARDIAN", "CAPTURE_SUPERVISOR", "REDUCTION_SUPERVISOR"],
        ["ROOT_GUARDIAN", "CAPTURE_SUPERVISOR"],
        ["ROOT_GUARDIAN", "CAPTURE_SUPERVISOR"],
        [],
        ["ROOT_GUARDIAN", "CAPTURE_SUPERVISOR"],
    ),
    "REDUCER_INPUT_VIEW": (
        ["REDUCTION_SUPERVISOR", "POST_RUN_REDUCER"],
        ["REDUCTION_SUPERVISOR"],
        ["REDUCTION_SUPERVISOR"],
        [],
        ["REDUCTION_SUPERVISOR"],
    ),
    "REDUCER_OUTPUT": (
        ["REDUCTION_SUPERVISOR"],
        ["POST_RUN_REDUCER"],
        ["REDUCTION_SUPERVISOR"],
        ["REDUCTION_SUPERVISOR"],
        ["REDUCTION_SUPERVISOR"],
    ),
}

EVIDENCE_OBJECT_IDS = set(OBJECT_AUTHORITY_POLICY) - {"CANDIDATE_SOURCE_OBJECT"}

REQUIRED_INPUTS = [
    "f0-supervisor-c4-claim-registry-v1.json",
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "test-run-f0-supervisor-v3-full.sh",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
]

COMPONENT_POLICY = [
    ("static-registries", "FAST_REGISTRY_CHECK", 1800),
    ("tests", "FAST_HOSTILE_REGRESSION", 3600),
    ("child-bundle-producer", "FULL_CHILD_PRODUCER", 43200),
    ("child-bundle-checker", "FULL_CHILD_CHECKER", 43200),
    ("orchestrator", "FULL_PARENT_ORCHESTRATOR", 43200),
]

RAW_RECEIPT_FIELDS = [
    "component_id",
    "sealed_plan_sha256",
    "input_root_sha256",
    "argv",
    "environment_sha256",
    "preexec_observation_size_sha256_and_bytes",
    "cgroup_path_and_id",
    "leader_pid_and_pidfd_identity",
    "started_monotonic_ns",
    "finished_monotonic_ns",
    "waitid_status",
    "deadline_classification",
    "stdout_size_sha256_and_bytes",
    "stderr_size_sha256_and_bytes",
    "result_payload_sha256",
    "resource_counters",
    "cgroup_kill_used",
    "populated_zero_observed",
    "toolchain_identity",
]

PREEXEC_OBSERVATION_FIELDS = [
    "fd_table",
    "uid_gid_groups",
    "capability_sets",
    "no_new_privileges",
    "seccomp_mode",
    "mountinfo",
    "namespace_ids",
    "cgroup_identity",
    "interface_inventory",
]

STATE_MACHINE_POLICY = {
    "raw_capture": {
        "initial": "RAW_DECLARED",
        "states": [
            "RAW_DECLARED",
            "SNAPSHOTTING",
            "SEALED",
            "LAUNCHING",
            "RUNNING",
            "DRAINING",
            "RAW_CAPTURED",
            "RAW_COMPLETE_FINALIZING",
            "RAW_INCOMPLETE_FINALIZING",
            "RAW_CAPTURE_COMPLETE",
            "RAW_CAPTURE_INCOMPLETE",
        ],
        "terminal": ["RAW_CAPTURE_COMPLETE", "RAW_CAPTURE_INCOMPLETE"],
        "transitions": [
            ("RAW-T01", "RAW_DECLARED", "SNAPSHOTTING", "CAPTURE_SUPERVISOR"),
            ("RAW-T02", "SNAPSHOTTING", "SEALED", "CAPTURE_SUPERVISOR"),
            ("RAW-T03", "SNAPSHOTTING", "RAW_INCOMPLETE_FINALIZING", "CAPTURE_SUPERVISOR"),
            ("RAW-T04", "SEALED", "LAUNCHING", "CAPTURE_SUPERVISOR"),
            ("RAW-T05", "LAUNCHING", "RUNNING", "CAPTURE_SUPERVISOR"),
            ("RAW-T06", "LAUNCHING", "DRAINING", "CAPTURE_SUPERVISOR"),
            ("RAW-T07", "RUNNING", "DRAINING", "CAPTURE_SUPERVISOR"),
            ("RAW-T08", "DRAINING", "RAW_CAPTURED", "CAPTURE_SUPERVISOR"),
            ("RAW-T09", "RAW_CAPTURED", "RAW_COMPLETE_FINALIZING", "CAPTURE_SUPERVISOR"),
            ("RAW-T10", "RAW_CAPTURED", "RAW_INCOMPLETE_FINALIZING", "CAPTURE_SUPERVISOR"),
            ("RAW-T11", "RAW_COMPLETE_FINALIZING", "RAW_CAPTURE_COMPLETE", "CAPTURE_SUPERVISOR"),
            ("RAW-T12", "RAW_INCOMPLETE_FINALIZING", "RAW_CAPTURE_INCOMPLETE", "CAPTURE_SUPERVISOR"),
            ("RAW-T13", "RAW_COMPLETE_FINALIZING", "RAW_INCOMPLETE_FINALIZING", "CAPTURE_SUPERVISOR"),
        ],
    },
    "guardian_recovery": {
        "initial": "GUARD_ARMED",
        "states": [
            "GUARD_ARMED",
            "GUARD_DRAINING",
            "GUARD_FINALIZING",
            "GUARDIAN_INCOMPLETE_PUBLISHED",
            "GUARD_DISARMED",
        ],
        "terminal": ["GUARDIAN_INCOMPLETE_PUBLISHED", "GUARD_DISARMED"],
        "transitions": [
            ("GUARD-T01", "GUARD_ARMED", "GUARD_DRAINING", "ROOT_GUARDIAN"),
            ("GUARD-T02", "GUARD_DRAINING", "GUARD_FINALIZING", "ROOT_GUARDIAN"),
            ("GUARD-T03", "GUARD_FINALIZING", "GUARDIAN_INCOMPLETE_PUBLISHED", "ROOT_GUARDIAN"),
            ("GUARD-T04", "GUARD_ARMED", "GUARD_DISARMED", "ROOT_GUARDIAN"),
        ],
    },
    "reduction": {
        "initial": "REDUCTION_DECLARED",
        "states": ["REDUCTION_DECLARED", "VERIFYING_RAW_COMMIT", "PARSING_STRICT_RESULTS", "REDUCING", "REDUCTION_PASS_FINALIZING", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_PASS", "REDUCTION_REJECT", "REDUCTION_INCOMPLETE"],
        "terminal": ["REDUCTION_PASS", "REDUCTION_REJECT", "REDUCTION_INCOMPLETE"],
        "transitions": [
            ("REDUCE-T01", "REDUCTION_DECLARED", "VERIFYING_RAW_COMMIT", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T02", "VERIFYING_RAW_COMMIT", "PARSING_STRICT_RESULTS", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T03", "VERIFYING_RAW_COMMIT", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T04", "PARSING_STRICT_RESULTS", "REDUCING", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T05", "PARSING_STRICT_RESULTS", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T06", "REDUCING", "REDUCTION_PASS_FINALIZING", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T07", "REDUCING", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T08", "REDUCTION_PASS_FINALIZING", "REDUCTION_PASS", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T09", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_REJECT", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T10", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_INCOMPLETE", "REDUCTION_SUPERVISOR"),
            ("REDUCE-T11", "REDUCTION_PASS_FINALIZING", "REDUCTION_NONPASS_FINALIZING", "REDUCTION_SUPERVISOR"),
        ],
    },
}

FAILURE_POLICY = [
    ("PRECONDITION_REJECTED", "INCOMPLETE", False, False),
    ("LAUNCH_FAILED", "INCOMPLETE", False, True),
    ("EXITED_NONZERO", "INCOMPLETE", False, True),
    ("DEADLINE_EXCEEDED", "INCOMPLETE", False, True),
    ("OUTPUT_LIMIT_EXCEEDED", "INCOMPLETE", False, True),
    ("SUPERVISOR_DIED", "INCOMPLETE", False, True),
    ("CONTAINMENT_DRAIN_FAILED", "INCOMPLETE", False, True),
    ("INPUT_STABILITY_FAILED", "INCOMPLETE", False, True),
    ("TOOLCHAIN_IDENTITY_FAILED", "INCOMPLETE", False, True),
    ("FINALIZATION_FAILED", "INCOMPLETE", False, False),
    ("BOOT_INTERRUPTED", "INCOMPLETE", False, False),
    ("RAW_CAPTURE_COMPLETE", "COMPLETE_RAW_ONLY", False, True),
    ("STRICT_RESULT_INVALID", "COMPLETE_REJECT", False, False),
    ("REDUCER_REJECTED", "COMPLETE_REJECT", False, False),
    ("COMPLETE_REDUCTION", "LOCAL_REDUCTION_ELIGIBLE", True, False),
]

RESOURCE_POLICY = {
    "policy_values_sealed_before_execution": True,
    "run_max_wall_seconds": 136800,
    "supervisor_overhead_max_seconds": 1650,
    "kill_to_drain_max_seconds": 30,
    "pids_max_per_component": 512,
    "memory_max_bytes_per_component": 8053063680,
    "supervisor_memory_low_bytes": 536870912,
    "guardian_and_host_reserve_min_bytes": 2147483648,
    "required_vm_memory_min_bytes": 10200547328,
    "memory_swap_max_bytes_per_component": 0,
    "candidate_component_oom_isolated_from_supervisor": True,
    "stdout_max_bytes_per_component": 268435456,
    "stderr_max_bytes_per_component": 16777216,
    "preexec_observation_max_bytes_per_component": 1048576,
    "receipt_max_bytes_per_component": 1048576,
    "finalization_metadata_max_bytes": 16777216,
    "raw_total_max_bytes": 1610612736,
    "evidence_free_space_reserve_bytes": 10737418240,
    "resource_exhaustion_is_positive": False,
    "audit_allocation_unbounded": False,
}

ELIGIBILITY_POLICY = {
    "required_terminal_class": "COMPLETE_REDUCTION",
    "raw_capture_terminal_is_never_positive": True,
    "durable_raw_commit_marker_valid": True,
    "all_platform_requirements_satisfied": True,
    "exact_input_snapshot_sealed": True,
    "exact_component_plan_completed": True,
    "all_components_exited_zero": True,
    "all_component_stderr_empty": True,
    "all_result_protocols_valid": True,
    "strict_result_json_parsed_after_capture": True,
    "strict_result_schema_and_component_semantics_validated": True,
    "all_cgroups_populated_zero": True,
    "no_output_or_resource_limit_hit": True,
    "input_and_toolchain_identity_stable": True,
    "raw_capture_finalized_before_reduction": True,
    "reducer_uses_only_finalized_capture": True,
    "claim_statuses_derived_from_fixed_registry_predicates": True,
    "candidate_summary_is_not_an_oracle": True,
    "external_authorization_change_allowed": False,
}

PERFORMANCE_POLICY = {
    "path_class": "offline_validation_control_plane_only",
    "production_linux_scheduler_hot_path_touched": False,
    "production_monitor_dispatch_hot_path_touched": False,
    "per_candidate_component_setup_cost_allowed": ["namespace_creation", "cgroup_creation", "seccomp_install", "preexec_attestation"],
    "post_component_cost_allowed": ["sha256", "canonical_json", "fsync", "atomic_publish", "bounded_terminal_receipts"],
    "forbidden_in_future_production_hot_path": ["cryptographic_hash", "json_parse_or_serialize", "global_process_or_domain_scan", "unbounded_iteration", "sleeping_allocation", "filesystem_io", "synchronous_verbose_trace"],
    "future_security_fast_path_rule": "precompute_at_admission_or_transition_then_consume_O1_cached_state",
    "zero_overhead_claim_from_architecture_only": False,
    "performance_claim_requires_measurement": True,
}

GATE_IDS = [f"C4CAP-G{i}-{suffix}" for i, suffix in enumerate(
    ["CONTRACT", "HOSTILE", "SUPERVISOR", "PLATFORM", "FAULTS", "CAPTURE", "REDUCTION"],
    start=1,
)]

AUTHORIZATION_KEYS = {
    "authority_disjoint_contract_accepted",
    "authority_disjoint_launcher_implemented",
    "full_campaign_authorized",
    "F0_local_acceptance",
    "external_R11_review",
    "G0_authorized",
    "semantic_freeze",
    "TLA_translation",
    "linux_behavior_change",
    "monitor_implementation",
    "protection_claim",
    "performance_or_cost_claim",
    "deployment_claim",
}


def _reject_constant(value: str) -> None:
    raise ContractError(f"non-finite JSON number: {value}")


def _unique_object(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_contract(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ContractError(f"cannot load strict JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError("contract root must be an object")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def require_exact_keys(value: Any, keys: set[str], label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    actual = set(value)
    require(actual == keys, f"{label} keys differ: missing={sorted(keys - actual)} extra={sorted(actual - keys)}")
    return value


def require_nonempty_text(value: Any, label: str) -> None:
    require(isinstance(value, str) and bool(value.strip()), f"{label} must be non-empty text")


def require_exact(value: Any, expected: Any, label: str) -> None:
    require(value == expected and type(value) is type(expected), f"{label} differs from the v1 policy")


def _path_exists_without(
    edges: dict[str, list[str]], start: str, terminals: set[str], forbidden: str
) -> bool:
    if start == forbidden:
        return False
    pending = [start]
    seen: set[str] = set()
    while pending:
        current = pending.pop()
        if current == forbidden or current in seen:
            continue
        if current in terminals:
            return True
        seen.add(current)
        pending.extend(edges.get(current, []))
    return False


def _validate_reasoning_and_claims(contract: dict[str, Any]) -> None:
    require_exact(
        contract["reasoning_profile"],
        {
            "engine": "gpt-5.6-sol",
            "effort": "max",
            "roles": [
                "architecture_synthesis",
                "hostile_contradiction_search",
                "minimality_analysis",
            ],
            "approval_authority": False,
            "tla_role": "terminal_post_freeze_validation_only",
        },
        "reasoning_profile",
    )
    require_exact(
        contract["claim_boundary"],
        {
            "capture_may_support_only": SUPPORTED_CLAIMS,
            "must_remain_open": OPEN_CLAIMS,
            "maximum_local_disposition": "AUTHORITY_DISJOINT_CAPTURED_LOCAL_CANDIDATE_ONLY",
            "product_hostile_kernel_boundary_proved": False,
            "external_review_performed": False,
        },
        "claim_boundary",
    )
    require(not set(SUPPORTED_CLAIMS) & set(OPEN_CLAIMS), "supported and open claims overlap")


def _validate_trust_and_platform(contract: dict[str, Any]) -> None:
    trust = require_exact_keys(
        contract["trust_boundary"],
        {
            "trusted",
            "untrusted",
            "outside_local_claim",
            "capture_host_kernel_compromise_in_scope",
            "same_uid_mode_bits_are_a_security_boundary",
        },
        "trust_boundary",
    )
    for key in ("trusted", "untrusted", "outside_local_claim"):
        values = trust[key]
        require(isinstance(values, list) and values, f"trust_boundary.{key} must be non-empty")
        require(all(isinstance(item, str) and item for item in values), f"trust_boundary.{key} entries invalid")
        require(len(values) == len(set(values)), f"trust_boundary.{key} contains duplicates")
    require("candidate_component_uid_and_all_descendants" in trust["untrusted"], "candidate must be untrusted")
    require("candidate_stdout_stderr_and_result_json" in trust["untrusted"], "candidate results must be untrusted")
    require("capture_host_linux_kernel" in trust["trusted"], "host-kernel trust assumption missing")
    require("malicious_root_or_service_manager" in trust["outside_local_claim"], "malicious-root nonclaim missing")
    require_exact(trust["capture_host_kernel_compromise_in_scope"], False, "kernel-compromise scope")
    require_exact(trust["same_uid_mode_bits_are_a_security_boundary"], False, "same-UID boundary")

    rows = contract["platform_requirements"]
    require(isinstance(rows, list), "platform_requirements must be a list")
    require([row.get("id") if isinstance(row, dict) else None for row in rows] == PLATFORM_IDS, "platform requirement IDs/order differ")
    for row in rows:
        require_exact_keys(row, {"id", "requirement", "evidence", "fail_closed"}, f"platform {row.get('id')}")
        require_nonempty_text(row["requirement"], f"platform {row['id']} requirement")
        require_nonempty_text(row["evidence"], f"platform {row['id']} evidence")
        requirement_anchor, evidence_anchor = PLATFORM_SEMANTIC_ANCHORS[row["id"]]
        require(
            requirement_anchor in row["requirement"],
            f"platform {row['id']} requirement semantic anchor missing",
        )
        require(
            evidence_anchor in row["evidence"],
            f"platform {row['id']} evidence semantic anchor missing",
        )
        require_exact(row["fail_closed"], True, f"platform {row['id']} fail_closed")


def _validate_roles(contract: dict[str, Any]) -> None:
    rows = contract["roles"]
    require(isinstance(rows, list), "roles must be a list")
    require([row.get("id") if isinstance(row, dict) else None for row in rows] == list(ROLE_POLICY), "role IDs/order differ")
    role_keys = {
        "id",
        "uid_class",
        "trusted",
        "may_launch_candidate",
        "may_launch_reducer",
        "may_write_cgroup",
        "may_issue_claim_decision",
    }
    for row in rows:
        require_exact_keys(row, role_keys, f"role {row.get('id')}")
        observed = (
            row["uid_class"],
            row["trusted"],
            row["may_launch_candidate"],
            row["may_launch_reducer"],
            row["may_write_cgroup"],
            row["may_issue_claim_decision"],
        )
        require_exact(observed, ROLE_POLICY[row["id"]], f"role {row['id']} authority")


def _validate_object_authority(contract: dict[str, Any]) -> None:
    authority = require_exact_keys(
        contract["object_authority"],
        {
            "actions",
            "objects",
            "candidate_roles_with_evidence_create_append_or_finalize",
            "local_roles_with_claim_decision_authority",
        },
        "object_authority",
    )
    require_exact(authority["actions"], OBJECT_AUTHORITY_ACTIONS, "object authority actions")
    rows = authority["objects"]
    require(isinstance(rows, list), "object_authority.objects must be a list")
    observed_ids = [row.get("id") if isinstance(row, dict) else None for row in rows]
    require_exact(observed_ids, list(OBJECT_AUTHORITY_POLICY), "object authority object IDs")
    role_ids = set(ROLE_POLICY)
    row_by_id: dict[str, dict[str, Any]] = {}
    for row in rows:
        require_exact_keys(
            row,
            {
                "id",
                "read_roles",
                "byte_producer_roles",
                "create_roles",
                "append_roles",
                "finalize_roles",
            },
            f"object authority {row.get('id') if isinstance(row, dict) else '?'}",
        )
        lists = (
            row["read_roles"],
            row["byte_producer_roles"],
            row["create_roles"],
            row["append_roles"],
            row["finalize_roles"],
        )
        require_exact(lists, OBJECT_AUTHORITY_POLICY[row["id"]], f"object authority {row['id']}")
        for action, values in zip(OBJECT_AUTHORITY_ACTIONS, lists, strict=True):
            require(isinstance(values, list), f"object {row['id']} {action} roles must be a list")
            require(len(values) == len(set(values)), f"object {row['id']} {action} roles duplicate")
            require(set(values) <= role_ids, f"object {row['id']} {action} references unknown role")
        row_by_id[row["id"]] = row

    candidate_roles = {"CANDIDATE_SOURCE", "CANDIDATE_COMPONENT"}
    derived_candidate_writers = sorted(
        role
        for role in candidate_roles
        if any(
            role in row_by_id[object_id][field]
            for object_id in EVIDENCE_OBJECT_IDS
            for field in ("create_roles", "append_roles", "finalize_roles")
        )
    )
    require_exact(
        authority["candidate_roles_with_evidence_create_append_or_finalize"],
        derived_candidate_writers,
        "derived candidate evidence writers",
    )
    require_exact(derived_candidate_writers, [], "candidate evidence authority separation")

    local_claim_roles = [
        row["id"] for row in contract["roles"] if row["may_issue_claim_decision"] is True
    ]
    require_exact(
        authority["local_roles_with_claim_decision_authority"],
        local_claim_roles,
        "derived local claim authority",
    )
    require_exact(local_claim_roles, [], "local claim decision authority")

    guardian_failure = row_by_id["GUARDIAN_FAILURE_RECEIPT"]
    require_exact(guardian_failure["create_roles"], ["ROOT_GUARDIAN"], "guardian failure writer")
    require_exact(guardian_failure["finalize_roles"], ["ROOT_GUARDIAN"], "guardian failure finalizer")
    require(
        "ROOT_GUARDIAN" in row_by_id["RAW_COMMIT_MARKER"]["finalize_roles"],
        "guardian cannot finalize an incomplete commit marker",
    )
    for object_id, row in row_by_id.items():
        if object_id == "REDUCER_OUTPUT":
            require_exact(
                row["byte_producer_roles"], ["POST_RUN_REDUCER"], "reducer output producer"
            )
        require(
            "POST_RUN_REDUCER" not in row["create_roles"] + row["append_roles"] + row["finalize_roles"],
            f"non-root reducer has storage authority over {object_id}",
        )


def _validate_inputs_and_plan(contract: dict[str, Any]) -> None:
    snapshot = require_exact_keys(
        contract["input_snapshot"],
        {
            "required_candidate_objects",
            "capture_authority",
            "source_resolution",
            "source_open_flags",
            "source_type_requirement",
            "reject_hardlink_aliases",
            "single_open_copy_and_hash",
            "root_owned_staging_mode",
            "sealed_directory_mode",
            "sealed_file_mode",
            "candidate_mount_access",
            "candidate_write_prevention",
            "toolchain_identity",
            "toolchain_externally_authenticated",
        },
        "input_snapshot",
    )
    require_exact(snapshot["required_candidate_objects"], REQUIRED_INPUTS, "required candidate inputs")
    require_exact(snapshot["capture_authority"], "CAPTURE_SUPERVISOR", "snapshot authority")
    require_exact(snapshot["source_resolution"], "descriptor_relative_beneath_no_symlink_no_magiclink", "snapshot resolution")
    require_exact(
        snapshot["source_open_flags"],
        "O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK",
        "snapshot hostile-source open flags",
    )
    require_exact(
        snapshot["source_type_requirement"],
        "regular_file_and_st_nlink_equals_1_before_read",
        "snapshot source type requirement",
    )
    require_exact(snapshot["reject_hardlink_aliases"], True, "hardlink rejection")
    require_exact(snapshot["single_open_copy_and_hash"], True, "single-open capture")
    require_exact(snapshot["root_owned_staging_mode"], "0700", "staging mode")
    require_exact(snapshot["sealed_directory_mode"], "0555", "sealed directory mode")
    require_exact(snapshot["sealed_file_mode"], "0444_or_0555_by_executable_policy", "sealed file mode")
    require_exact(snapshot["candidate_mount_access"], "read_only_bind_mount", "candidate snapshot access")
    require_exact(
        snapshot["candidate_write_prevention"],
        [
            "disjoint_uid_and_no_capabilities",
            "read_only_bind_mount",
            "no_writable_alias_or_open_descriptor",
            "root_owned_parent_not_traversable",
            "pre_and_post_descriptor_metadata_and_digest_check",
        ],
        "candidate write prevention",
    )
    require_exact(
        snapshot["toolchain_identity"],
        [
            "/usr/bin/python3",
            "/bin/bash",
            "/usr/bin/env",
            "/usr/bin/sha256sum",
            "dynamic_loader_and_loaded_shared_objects",
            "kernel_release_and_boot_identity",
            "complete_candidate_toolchain_image_sha256_and_manifest",
        ],
        "toolchain identity",
    )
    require_exact(snapshot["toolchain_externally_authenticated"], False, "toolchain authentication")

    plan = require_exact_keys(
        contract["component_plan"],
        {
            "plan_authority",
            "candidate_may_add_remove_or_reorder_components",
            "parallel_execution",
            "execution_order",
            "components",
            "argv_prefix",
            "environment",
            "result_protocol",
        },
        "component_plan",
    )
    require_exact(plan["plan_authority"], "root_owned_policy_selected_before_candidate_execution", "plan authority")
    require_exact(plan["candidate_may_add_remove_or_reorder_components"], False, "candidate plan mutation")
    require_exact(plan["parallel_execution"], False, "parallel execution")
    expected_ids = [row[0] for row in COMPONENT_POLICY]
    require_exact(plan["execution_order"], expected_ids, "component order")
    components = plan["components"]
    require(isinstance(components, list) and len(components) == len(COMPONENT_POLICY), "component set differs")
    for row, (component_id, role, deadline) in zip(components, COMPONENT_POLICY, strict=True):
        require_exact_keys(row, {"id", "role", "max_wall_seconds", "argv_suffix"}, f"component {component_id}")
        require_exact(row["id"], component_id, f"component {component_id} id")
        require_exact(row["role"], role, f"component {component_id} role")
        require_exact(row["max_wall_seconds"], deadline, f"component {component_id} deadline")
        require_exact(row["argv_suffix"], ["--component", component_id], f"component {component_id} argv")
    require_exact(
        plan["argv_prefix"],
        ["/usr/bin/python3", "-S", "-B", "INPUT/validate-f0-supervisor-lts-v3.py"],
        "component argv prefix",
    )
    require_exact(
        plan["environment"],
        {"PATH": "/usr/bin:/bin", "PYTHONPATH": "INPUT", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONHASHSEED": "0"},
        "component environment",
    )
    require_exact(
        plan["result_protocol"],
        {
            "stdout_lines": 1,
            "required_prefix": "RESULT_JSON=",
            "stderr_must_be_empty": True,
            "returncode_must_equal": 0,
            "strict_json_duplicate_keys_rejected": True,
            "nonfinite_numbers_rejected": True,
        },
        "result protocol",
    )


def _validate_containment_and_capture(contract: dict[str, Any]) -> None:
    require_exact(
        contract["containment"],
        {
            "hierarchy": "root_guardian_cgroup/capture_supervisor_cgroup/run_cgroup/component_cgroup",
            "delegated_to_supervisor": True,
            "delegated_to_candidate": False,
            "leader_placement": "clone3_CLONE_INTO_CGROUP_and_CLONE_PIDFD_before_exec",
            "attach_after_exec_allowed": False,
            "descendant_rule": "all descendants inherit the component cgroup and cannot write cgroupfs",
            "cleanup_signal": "cgroup.kill",
            "cleanup_complete_predicate": "cgroup.events populated equals 0",
            "process_group_is_containment_boundary": False,
            "namespaces": ["mount", "pid", "ipc", "uts", "network", "cgroup"],
            "capability_sets": "empty_effective_permitted_inheritable_ambient",
            "no_new_privileges": True,
            "seccomp_profile_selected_by_root_policy": True,
            "candidate_cannot_reuse_uid_until_drained": True,
            "supervisor_failure_action": "root_guardian_kills_complete_supervisor_subtree_and_marks_run_incomplete",
        },
        "containment",
    )
    observation = require_exact_keys(
        contract["observation"],
        {
            "lifecycle_authority",
            "leader_observation",
            "descendant_observation",
            "stdout_capture",
            "stderr_capture",
            "preexec_capture",
            "stdin_source",
            "candidate_output_file_access",
            "raw_receipt_fields",
            "preexec_observation_required_fields",
            "candidate_validator_receipts_authoritative",
            "root_receipts_externally_attested",
        },
        "observation",
    )
    require_exact(observation["lifecycle_authority"], "CAPTURE_SUPERVISOR", "lifecycle authority")
    require_exact(observation["leader_observation"], "pidfd_plus_waitid_P_PIDFD", "leader observation")
    require_exact(
        observation["descendant_observation"],
        "once_opened_component_cgroup_dirfd_events_and_resource_files",
        "descendant observation",
    )
    require_exact(observation["stdout_capture"], "root_opened_pipe_read_by_supervisor", "stdout capture")
    require_exact(observation["stderr_capture"], "root_opened_pipe_read_by_supervisor", "stderr capture")
    require_exact(
        observation["preexec_capture"],
        "trusted_stub_bytes_over_root_opened_status_pipe_before_candidate_release",
        "pre-exec capture",
    )
    require_exact(observation["stdin_source"], "read_only_dev_null", "candidate stdin")
    require_exact(observation["candidate_output_file_access"], "none", "candidate output access")
    require_exact(observation["raw_receipt_fields"], RAW_RECEIPT_FIELDS, "raw receipt fields")
    require_exact(
        observation["preexec_observation_required_fields"],
        PREEXEC_OBSERVATION_FIELDS,
        "pre-exec observation fields",
    )
    require(
        {
            "fd_table",
            "uid_gid_groups",
            "capability_sets",
            "no_new_privileges",
            "seccomp_mode",
            "mountinfo",
            "namespace_ids",
            "cgroup_identity",
            "interface_inventory",
        }
        <= set(observation["preexec_observation_required_fields"]),
        "pre-exec observation omits a platform identity or privilege field",
    )
    require(
        {
            "preexec_observation_size_sha256_and_bytes",
            "stdout_size_sha256_and_bytes",
            "stderr_size_sha256_and_bytes",
            "resource_counters",
            "cgroup_kill_used",
            "populated_zero_observed",
            "toolchain_identity",
        }
        <= set(observation["raw_receipt_fields"]),
        "raw receipt omits mandatory captured evidence",
    )
    require_exact(observation["candidate_validator_receipts_authoritative"], False, "candidate receipt authority")
    require_exact(observation["root_receipts_externally_attested"], False, "external receipt attestation")
    require_exact(
        contract["finalization"],
        {
            "fixed_native_root": "/var/lib/domainlease-f0-c4",
            "durable_intent_before_launch": True,
            "staging_owner": "root",
            "candidate_can_traverse_staging": False,
            "raw_bytes_hashed_while_reading": True,
            "files_fsynced_before_manifest": True,
            "manifest_canonical_json": True,
            "manifest_binds_all_raw_and_platform_receipts": True,
            "manifest_fsynced_before_publish": True,
            "publication": "renameat2_RENAME_NOREPLACE_then_parent_fsync",
            "commit_marker": "root_owned_no_replace_marker_after_parent_fsync",
            "uncommitted_published_directory_is_complete": False,
            "guardian_failure_record_distinct_from_raw_evidence": True,
            "boot_reconciler_required": True,
            "published_owner": "root",
            "published_file_mode": "0444",
            "published_directory_mode": "0555",
            "candidate_can_modify_published_bytes": False,
            "root_or_physical_storage_immutability_proved": False,
            "post_run_reducer_reads_only_published_bytes": True,
            "reduction_mutates_capture": False,
        },
        "finalization",
    )


def _validate_state_machines(contract: dict[str, Any]) -> None:
    machines = require_exact_keys(
        contract["state_machines"], set(STATE_MACHINE_POLICY), "state_machines"
    )
    roles = {row["id"]: row for row in contract["roles"]}
    all_transition_ids: set[str] = set()
    edges_by_machine: dict[str, dict[str, list[str]]] = {}

    for machine_id, expected in STATE_MACHINE_POLICY.items():
        machine = require_exact_keys(
            machines[machine_id],
            {"initial", "states", "terminal", "transitions"},
            f"state machine {machine_id}",
        )
        require_exact(machine["initial"], expected["initial"], f"{machine_id} initial")
        require_exact(machine["states"], expected["states"], f"{machine_id} states")
        require_exact(machine["terminal"], expected["terminal"], f"{machine_id} terminals")
        require(isinstance(machine["transitions"], list), f"{machine_id} transitions must be a list")
        observed: list[tuple[Any, Any, Any, Any]] = []
        for row in machine["transitions"]:
            require_exact_keys(
                row,
                {"id", "from", "to", "authority"},
                f"transition {row.get('id') if isinstance(row, dict) else '?'}",
            )
            observed.append((row["id"], row["from"], row["to"], row["authority"]))
        require_exact(observed, expected["transitions"], f"{machine_id} transition relation")
        transition_ids = {row[0] for row in observed}
        require(len(transition_ids) == len(observed), f"{machine_id} transition IDs duplicate")
        require(not all_transition_ids & transition_ids, "transition IDs collide across state machines")
        all_transition_ids.update(transition_ids)

        state_set = set(expected["states"])
        terminal_set = set(expected["terminal"])
        edges: dict[str, list[str]] = {state: [] for state in expected["states"]}
        for _, source, target, authority in observed:
            require(source in state_set and target in state_set, f"{machine_id} endpoint unknown")
            require(source not in terminal_set, f"{machine_id} terminal has an outgoing transition")
            require(authority in roles, f"{machine_id} transition authority unknown")
            require(roles[authority]["trusted"] is True, f"{machine_id} authority is untrusted")
            if machine_id == "raw_capture":
                require(
                    roles[authority]["may_launch_candidate"] is True
                    and roles[authority]["may_write_cgroup"] is True,
                    "raw-capture transition authority lacks launch/cgroup capability",
                )
            elif machine_id == "guardian_recovery":
                require(
                    roles[authority]["may_write_cgroup"] is True,
                    "guardian transition authority lacks cgroup capability",
                )
            else:
                require(
                    roles[authority]["may_launch_reducer"] is True,
                    "reduction transition authority lacks reducer-launch capability",
                )
            edges[source].append(target)

        reachable = {expected["initial"]}
        pending = [expected["initial"]]
        while pending:
            source = pending.pop()
            for target in edges[source]:
                if target not in reachable:
                    reachable.add(target)
                    pending.append(target)
        require(reachable == state_set, f"{machine_id} contains unreachable states")
        edges_by_machine[machine_id] = edges

    raw_edges = edges_by_machine["raw_capture"]
    raw_terminals = set(STATE_MACHINE_POLICY["raw_capture"]["terminal"])
    for mandatory in ("DRAINING", "RAW_CAPTURED"):
        require(
            not _path_exists_without(raw_edges, "LAUNCHING", raw_terminals, mandatory),
            f"launched raw capture can terminate without {mandatory}",
        )
    for mandatory in (
        "SNAPSHOTTING",
        "SEALED",
        "LAUNCHING",
        "DRAINING",
        "RAW_CAPTURED",
        "RAW_COMPLETE_FINALIZING",
    ):
        require(
            not _path_exists_without(
                raw_edges, "RAW_DECLARED", {"RAW_CAPTURE_COMPLETE"}, mandatory
            ),
            f"raw-complete path bypasses {mandatory}",
        )

    guard_edges = edges_by_machine["guardian_recovery"]
    for mandatory in ("GUARD_DRAINING", "GUARD_FINALIZING"):
        require(
            not _path_exists_without(
                guard_edges,
                "GUARD_ARMED",
                {"GUARDIAN_INCOMPLETE_PUBLISHED"},
                mandatory,
            ),
            f"guardian incomplete path bypasses {mandatory}",
        )

    reduction_edges = edges_by_machine["reduction"]
    for mandatory in (
        "VERIFYING_RAW_COMMIT",
        "PARSING_STRICT_RESULTS",
        "REDUCING",
        "REDUCTION_PASS_FINALIZING",
    ):
        require(
            not _path_exists_without(
                reduction_edges,
                "REDUCTION_DECLARED",
                {"REDUCTION_PASS"},
                mandatory,
            ),
            f"positive reduction path bypasses {mandatory}",
        )


def _validate_failures_resources_and_invariants(contract: dict[str, Any]) -> None:
    rows = contract["failure_taxonomy"]
    require(isinstance(rows, list), "failure_taxonomy must be a list")
    observed = []
    for row in rows:
        require_exact_keys(row, {"id", "class", "positive_eligible", "requires_drain_if_launched"}, f"failure {row.get('id') if isinstance(row, dict) else '?'}")
        observed.append((row["id"], row["class"], row["positive_eligible"], row["requires_drain_if_launched"]))
    require_exact(observed, FAILURE_POLICY, "failure taxonomy")
    require(sum(1 for row in rows if row["positive_eligible"] is True) == 1, "exactly one terminal class may be positive")

    resources = contract["resource_policy"]
    require_exact(resources, RESOURCE_POLICY, "resource policy")
    for key, value in resources.items():
        if key.endswith("seconds") or key.endswith("component") or key.endswith("bytes"):
            if key != "memory_swap_max_bytes_per_component":
                require(type(value) is int and value > 0, f"resource bound {key} must be finite and positive")
    require_exact(
        resources["memory_swap_max_bytes_per_component"], 0, "candidate swap maximum"
    )
    require(
        resources["candidate_component_oom_isolated_from_supervisor"] is True,
        "component-local OOM must not terminate the trusted supervisor",
    )

    components = contract["component_plan"]["components"]
    component_deadline_sum = sum(row["max_wall_seconds"] for row in components)
    required_run_seconds = (
        component_deadline_sum
        + len(components) * resources["kill_to_drain_max_seconds"]
        + resources["supervisor_overhead_max_seconds"]
    )
    require(
        resources["run_max_wall_seconds"] >= required_run_seconds,
        "run maximum is shorter than component deadlines plus drains and overhead",
    )

    required_vm_memory = (
        resources["memory_max_bytes_per_component"]
        + resources["guardian_and_host_reserve_min_bytes"]
    )
    require(
        resources["required_vm_memory_min_bytes"] >= required_vm_memory,
        "sealed VM minimum does not cover candidate memory plus guardian/host reserve",
    )
    require(
        resources["supervisor_memory_low_bytes"]
        <= resources["guardian_and_host_reserve_min_bytes"],
        "supervisor memory.low lies outside the guardian/host reserve",
    )

    per_component_raw = sum(
        resources[key]
        for key in (
            "stdout_max_bytes_per_component",
            "stderr_max_bytes_per_component",
            "preexec_observation_max_bytes_per_component",
            "receipt_max_bytes_per_component",
        )
    )
    required_raw_total = (
        len(components) * per_component_raw
        + resources["finalization_metadata_max_bytes"]
    )
    require(
        resources["raw_total_max_bytes"] >= required_raw_total,
        "raw total bound cannot contain all component bounds and finalization metadata",
    )

    invariants = contract["invariants"]
    require(isinstance(invariants, list) and len(invariants) == 30, "exactly 30 invariants are required")
    expected_ids = [f"CAP-INV-{index:03d}" for index in range(1, 31)]
    require([row.get("id") if isinstance(row, dict) else None for row in invariants] == expected_ids, "invariant IDs/order differ")
    for row in invariants:
        require_exact_keys(row, {"id", "statement", "enforced_by"}, f"invariant {row.get('id')}")
        require_nonempty_text(row["statement"], f"invariant {row['id']} statement")
        require(isinstance(row["enforced_by"], list) and row["enforced_by"], f"invariant {row['id']} enforcement missing")
        require(all(isinstance(item, str) and item for item in row["enforced_by"]), f"invariant {row['id']} enforcement invalid")
    required_phrases = {
        "CAP-INV-001": "UID is disjoint",
        "CAP-INV-002": "no writable path",
        "CAP-INV-003": "final cgroup before any candidate instruction",
        "CAP-INV-005": "never used as the descendant containment oracle",
        "CAP-INV-008": "populated equals zero",
        "CAP-INV-010": "untrusted data",
        "CAP-INV-012": "opened nonblocking and no-follow",
        "CAP-INV-013": "not inferred only from equal pre/post hashes",
        "CAP-INV-015": "cannot produce a positive local disposition",
        "CAP-INV-017": "only finalized root-captured bytes",
        "CAP-INV-021": "Only the four registered local bounded claims",
        "CAP-INV-022": "remain false or open",
        "CAP-INV-023": "post-freeze validation backend",
        "CAP-INV-024": "guardian disarms only after observing a valid durable raw commit marker",
        "CAP-INV-025": "never claims safety against a malicious capture-host kernel",
        "CAP-INV-026": "at least the sum of component deadlines",
        "CAP-INV-027": "guardian/host reserve never exceeds probed VM memory",
        "CAP-INV-028": "immutable toolchain image digest",
        "CAP-INV-029": "prior-boot durable run intent",
        "CAP-INV-030": "production Linux scheduler or Monitor hot path",
    }
    by_id = {row["id"]: row for row in invariants}
    for invariant_id, phrase in required_phrases.items():
        require(phrase in by_id[invariant_id]["statement"], f"{invariant_id} semantic anchor missing")


def _validate_eligibility_gates_and_nonclaims(contract: dict[str, Any]) -> None:
    require_exact(contract["positive_eligibility"], ELIGIBILITY_POLICY, "positive eligibility")
    positive_failure_ids = [
        row["id"] for row in contract["failure_taxonomy"] if row["positive_eligible"] is True
    ]
    require_exact(
        positive_failure_ids,
        [contract["positive_eligibility"]["required_terminal_class"]],
        "positive terminal class derivation",
    )
    raw_terminals = set(contract["state_machines"]["raw_capture"]["terminal"])
    require(
        not raw_terminals & set(positive_failure_ids),
        "raw capture terminal is directly positive eligible",
    )
    require_exact(contract["performance_boundary"], PERFORMANCE_POLICY, "performance boundary")
    gates = contract["implementation_gates"]
    require(isinstance(gates, list) and len(gates) == len(GATE_IDS), "implementation gate count differs")
    for index, (row, gate_id) in enumerate(zip(gates, GATE_IDS, strict=True), start=1):
        require_exact_keys(row, {"order", "id", "requirement", "status"}, f"gate {gate_id}")
        require_exact(row["order"], index, f"gate {gate_id} order")
        require_exact(row["id"], gate_id, f"gate {gate_id} id")
        require_nonempty_text(row["requirement"], f"gate {gate_id} requirement")
        require_exact(row["status"], "REQUIRED", f"gate {gate_id} status")

    authorization = require_exact_keys(contract["authorization"], AUTHORIZATION_KEYS, "authorization")
    for key, value in authorization.items():
        require_exact(value, False, f"authorization.{key}")

    nonclaims = contract["nonclaims"]
    require(isinstance(nonclaims, list) and len(nonclaims) == 5, "five explicit nonclaims are required")
    require(all(isinstance(item, str) and item for item in nonclaims), "nonclaims must be non-empty strings")
    required_nonclaim_terms = [
        "not a root supervisor implementation",
        "does not authenticate the toolchain",
        "does not protect evidence from a malicious root",
        "does not establish F0, R11, K0/G0",
    ]
    joined = "\n".join(nonclaims)
    for term in required_nonclaim_terms:
        require(term in joined, f"nonclaim missing: {term}")


def validate_contract(contract: dict[str, Any]) -> None:
    require_exact_keys(contract, TOP_LEVEL_KEYS, "contract")
    require_exact(contract["schema_version"], 1, "schema_version")
    require_exact(contract["artifact_id"], "f0-c4-authority-disjoint-capture-contract-v1", "artifact_id")
    require_exact(contract["status"], "ARCHITECTURE_CONTRACT_PRE_IMPLEMENTATION", "status")
    _validate_reasoning_and_claims(contract)
    _validate_trust_and_platform(contract)
    _validate_roles(contract)
    _validate_object_authority(contract)
    _validate_inputs_and_plan(contract)
    _validate_containment_and_capture(contract)
    _validate_state_machines(contract)
    _validate_failures_resources_and_invariants(contract)
    _validate_eligibility_gates_and_nonclaims(contract)


def canonical_bytes(contract: dict[str, Any]) -> bytes:
    return (json.dumps(contract, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def canonical_sha256(contract: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_bytes(contract)).hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", nargs="?", type=Path, default=CONTRACT_PATH)
    args = parser.parse_args(argv)
    try:
        contract = load_contract(args.contract)
        validate_contract(contract)
    except ContractError as exc:
        print(f"F0_C4_AUTHORITY_CAPTURE_CONTRACT_REJECT {exc}", file=sys.stderr)
        return 1
    print(
        "F0_C4_AUTHORITY_CAPTURE_CONTRACT_PASS "
        f"sha256={canonical_sha256(contract)} "
        f"platform_requirements={len(contract['platform_requirements'])} "
        f"invariants={len(contract['invariants'])} "
        f"gates={len(contract['implementation_gates'])}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
