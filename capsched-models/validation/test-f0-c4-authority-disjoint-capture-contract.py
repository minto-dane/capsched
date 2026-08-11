#!/usr/bin/env python3
"""Hostile mutation corpus for the Candidate-4 capture contract validator."""

from __future__ import annotations

import argparse
import copy
import importlib.util
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
VALIDATOR_PATH = HERE / "validate-f0-c4-authority-disjoint-capture-contract.py"
DEFAULT_CONTRACT = (
    HERE.parent / "analysis" / "f0-c4-authority-disjoint-capture-contract-v1.json"
)


def load_validator() -> Any:
    spec = importlib.util.spec_from_file_location("f0_c4_capture_contract_validator", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise SystemExit("cannot load capture-contract validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PathPart = str | int
Mutator = Callable[[dict[str, Any]], None]
PolicyAligner = Callable[[dict[str, Any]], dict[str, Any]]


def parent_and_key(root: Any, path: tuple[PathPart, ...]) -> tuple[Any, PathPart]:
    current = root
    for part in path[:-1]:
        current = current[part]
    return current, path[-1]


def set_value(path: tuple[PathPart, ...], value: Any) -> Mutator:
    def mutate(root: dict[str, Any]) -> None:
        parent, key = parent_and_key(root, path)
        parent[key] = value

    return mutate


def delete_value(path: tuple[PathPart, ...]) -> Mutator:
    def mutate(root: dict[str, Any]) -> None:
        parent, key = parent_and_key(root, path)
        if isinstance(parent, list):
            del parent[key]
        else:
            del parent[key]

    return mutate


def append_value(path: tuple[PathPart, ...], value: Any) -> Mutator:
    def mutate(root: dict[str, Any]) -> None:
        current: Any = root
        for part in path:
            current = current[part]
        current.append(value)

    return mutate


def swap_values(path: tuple[PathPart, ...], left: int, right: int) -> Mutator:
    def mutate(root: dict[str, Any]) -> None:
        current: Any = root
        for part in path:
            current = current[part]
        current[left], current[right] = current[right], current[left]

    return mutate


def mutation_cases() -> list[tuple[str, Mutator]]:
    return [
        ("unknown-top-level-key", set_value(("forged_authority",), True)),
        ("object-authority-removed", delete_value(("object_authority",))),
        ("boolean-schema-version", set_value(("schema_version",), True)),
        ("reasoning-engine-drift", set_value(("reasoning_profile", "engine"), "tla+")),
        ("reasoning-effort-weakened", set_value(("reasoning_profile", "effort"), "low")),
        ("model-grants-itself-authority", set_value(("reasoning_profile", "approval_authority"), True)),
        ("tla-promoted-to-primary", set_value(("reasoning_profile", "tla_role"), "primary_design_oracle")),
        ("extra-supported-claim", append_value(("claim_boundary", "capture_may_support_only"), "F0-LOCAL-ACCEPTANCE-v1")),
        ("open-claim-removed", delete_value(("claim_boundary", "must_remain_open", 0))),
        ("local-disposition-overclaimed", set_value(("claim_boundary", "maximum_local_disposition"), "F0_ACCEPTED")),
        ("kernel-proof-overclaimed", set_value(("claim_boundary", "product_hostile_kernel_boundary_proved"), True)),
        ("external-review-forged", set_value(("claim_boundary", "external_review_performed"), True)),
        ("kernel-compromise-in-scope", set_value(("trust_boundary", "capture_host_kernel_compromise_in_scope"), True)),
        ("same-uid-called-boundary", set_value(("trust_boundary", "same_uid_mode_bits_are_a_security_boundary"), True)),
        ("candidate-removed-from-untrusted", delete_value(("trust_boundary", "untrusted", 1))),
        ("malicious-root-nonclaim-removed", delete_value(("trust_boundary", "outside_local_claim", 1))),
        ("platform-requirement-removed", delete_value(("platform_requirements", 0))),
        ("platform-fail-open", set_value(("platform_requirements", 1, "fail_closed"), False)),
        ("platform-evidence-empty", set_value(("platform_requirements", 2, "evidence"), "")),
        ("platform-requirement-weakened", set_value(("platform_requirements", 10, "requirement"), "Use /usr.")),
        ("candidate-marked-trusted", set_value(("roles", 4, "trusted"), True)),
        ("candidate-controls-cgroup", set_value(("roles", 4, "may_write_cgroup"), True)),
        ("candidate-decides-claim", set_value(("roles", 4, "may_issue_claim_decision"), True)),
        ("supervisor-decides-claim", set_value(("roles", 3, "may_issue_claim_decision"), True)),
        ("guardian-launches-candidate", set_value(("roles", 2, "may_launch_candidate"), True)),
        ("reducer-launches-candidate", set_value(("roles", 6, "may_launch_candidate"), True)),
        ("reduction-supervisor-cannot-launch", set_value(("roles", 5, "may_launch_reducer"), False)),
        ("object-action-removed", delete_value(("object_authority", "actions", 4))),
        ("evidence-object-removed", delete_value(("object_authority", "objects", 9))),
        ("candidate-creates-raw-stream", append_value(("object_authority", "objects", 5, "create_roles"), "CANDIDATE_COMPONENT")),
        ("candidate-source-appends-raw-stream", append_value(("object_authority", "objects", 5, "append_roles"), "CANDIDATE_SOURCE")),
        ("candidate-finalizes-manifest", append_value(("object_authority", "objects", 9, "finalize_roles"), "CANDIDATE_COMPONENT")),
        ("guardian-failure-writer-removed", delete_value(("object_authority", "objects", 8, "create_roles", 0))),
        ("guardian-finalizer-replaced", set_value(("object_authority", "objects", 8, "finalize_roles", 0), "CAPTURE_SUPERVISOR")),
        ("guardian-appends-raw-stream", append_value(("object_authority", "objects", 5, "append_roles"), "ROOT_GUARDIAN")),
        ("post-reducer-creates-output", append_value(("object_authority", "objects", 12, "create_roles"), "POST_RUN_REDUCER")),
        ("post-reducer-cannot-produce-output", delete_value(("object_authority", "objects", 12, "byte_producer_roles", 0))),
        ("post-reducer-writes-input-view", append_value(("object_authority", "objects", 11, "append_roles"), "POST_RUN_REDUCER")),
        ("object-authority-unknown-role", append_value(("object_authority", "objects", 7, "read_roles"), "UNKNOWN_ROLE")),
        ("candidate-writer-summary-forged", append_value(("object_authority", "candidate_roles_with_evidence_create_append_or_finalize"), "CANDIDATE_COMPONENT")),
        ("claim-authority-summary-forged", append_value(("object_authority", "local_roles_with_claim_decision_authority"), "CAPTURE_SUPERVISOR")),
        ("candidate-input-removed", delete_value(("input_snapshot", "required_candidate_objects", 0))),
        ("symlink-following-enabled", set_value(("input_snapshot", "source_resolution"), "path_based_follow")),
        ("blocking-hostile-source-open", set_value(("input_snapshot", "source_open_flags"), "O_RDONLY|O_CLOEXEC|O_NOFOLLOW")),
        ("fifo-source-accepted", set_value(("input_snapshot", "source_type_requirement"), "anything_readable")),
        ("hardlinks-accepted", set_value(("input_snapshot", "reject_hardlink_aliases"), False)),
        ("multi-open-capture", set_value(("input_snapshot", "single_open_copy_and_hash"), False)),
        ("snapshot-writable", set_value(("input_snapshot", "candidate_mount_access"), "read_write")),
        ("live-usr-called-toolchain", set_value(("input_snapshot", "toolchain_identity", 6), "live_usr_mount")),
        ("toolchain-self-authenticated", set_value(("input_snapshot", "toolchain_externally_authenticated"), True)),
        ("candidate-mutates-plan", set_value(("component_plan", "candidate_may_add_remove_or_reorder_components"), True)),
        ("components-run-in-parallel", set_value(("component_plan", "parallel_execution"), True)),
        ("component-order-swapped", swap_values(("component_plan", "execution_order"), 0, 1)),
        ("component-removed", delete_value(("component_plan", "components", 4))),
        ("deadline-unbounded", set_value(("component_plan", "components", 2, "max_wall_seconds"), None)),
        ("shell-prefix-injected", set_value(("component_plan", "argv_prefix", 0), "/bin/sh")),
        ("environment-expanded", set_value(("component_plan", "environment", "PATH"), "/usr/local/bin:/usr/bin:/bin")),
        ("stderr-allowed", set_value(("component_plan", "result_protocol", "stderr_must_be_empty"), False)),
        ("attach-after-exec", set_value(("containment", "attach_after_exec_allowed"), True)),
        ("clone-into-cgroup-removed", set_value(("containment", "leader_placement"), "fork_then_attach")),
        ("cgroup-delegated-to-candidate", set_value(("containment", "delegated_to_candidate"), True)),
        ("process-group-containment", set_value(("containment", "process_group_is_containment_boundary"), True)),
        ("kill-one-pid-only", set_value(("containment", "cleanup_signal"), "SIGKILL_leader")),
        ("drain-is-leader-exit", set_value(("containment", "cleanup_complete_predicate"), "leader_exited")),
        ("capabilities-retained", set_value(("containment", "capability_sets"), "CAP_SYS_ADMIN")),
        ("no-new-privileges-disabled", set_value(("containment", "no_new_privileges"), False)),
        ("candidate-selects-seccomp", set_value(("containment", "seccomp_profile_selected_by_root_policy"), False)),
        ("uid-reused-before-drain", set_value(("containment", "candidate_cannot_reuse_uid_until_drained"), False)),
        ("guardian-does-not-kill", set_value(("containment", "supervisor_failure_action"), "record_and_continue")),
        ("candidate-writes-output-file", set_value(("observation", "candidate_output_file_access"), "write")),
        ("candidate-inherits-stdin", set_value(("observation", "stdin_source"), "caller_stdin")),
        ("preexec-capture-after-release", set_value(("observation", "preexec_capture"), "candidate_self_report_after_exec")),
        ("cgroup-files-reopened-by-path", set_value(("observation", "descendant_observation"), "reopen_cgroup_path")),
        ("preexec-fd-table-removed", delete_value(("observation", "preexec_observation_required_fields", 0))),
        ("preexec-interface-inventory-removed", delete_value(("observation", "preexec_observation_required_fields", 8))),
        ("candidate-receipt-authoritative", set_value(("observation", "candidate_validator_receipts_authoritative"), True)),
        ("external-attestation-forged", set_value(("observation", "root_receipts_externally_attested"), True)),
        ("receipt-drain-field-removed", delete_value(("observation", "raw_receipt_fields", 18))),
        ("stdout-not-root-captured", set_value(("observation", "stdout_capture"), "candidate_file")),
        ("candidate-traverses-staging", set_value(("finalization", "candidate_can_traverse_staging"), True)),
        ("host-shared-evidence-root", set_value(("finalization", "fixed_native_root"), "/Users/shared/evidence")),
        ("intent-after-launch", set_value(("finalization", "durable_intent_before_launch"), False)),
        ("files-not-fsynced", set_value(("finalization", "files_fsynced_before_manifest"), False)),
        ("replace-publication", set_value(("finalization", "publication"), "rename_replace")),
        ("commit-marker-before-parent-fsync", set_value(("finalization", "commit_marker"), "marker_before_publish")),
        ("uncommitted-directory-complete", set_value(("finalization", "uncommitted_published_directory_is_complete"), True)),
        ("guardian-failure-mixed-with-raw", set_value(("finalization", "guardian_failure_record_distinct_from_raw_evidence"), False)),
        ("boot-reconciler-removed", set_value(("finalization", "boot_reconciler_required"), False)),
        ("candidate-mutates-published", set_value(("finalization", "candidate_can_modify_published_bytes"), True)),
        ("root-immutability-overclaim", set_value(("finalization", "root_or_physical_storage_immutability_proved"), True)),
        ("reducer-reopens-workspace", set_value(("finalization", "post_run_reducer_reads_only_published_bytes"), False)),
        ("reducer-mutates-capture", set_value(("finalization", "reduction_mutates_capture"), True)),
        ("raw-state-initial-drift", set_value(("state_machines", "raw_capture", "initial"), "SEALED")),
        ("raw-drain-transition-removed", delete_value(("state_machines", "raw_capture", "transitions", 6))),
        ("direct-declared-raw-complete", append_value(("state_machines", "raw_capture", "transitions"), {"id": "RAW-X", "from": "RAW_DECLARED", "to": "RAW_CAPTURE_COMPLETE", "authority": "CAPTURE_SUPERVISOR"})),
        ("raw-unknown-transition-endpoint", set_value(("state_machines", "raw_capture", "transitions", 0, "to"), "UNKNOWN")),
        ("raw-terminal-has-outgoing", append_value(("state_machines", "raw_capture", "transitions"), {"id": "RAW-X", "from": "RAW_CAPTURE_COMPLETE", "to": "RAW_DECLARED", "authority": "CAPTURE_SUPERVISOR"})),
        ("raw-transition-authority-drift", set_value(("state_machines", "raw_capture", "transitions", 8, "authority"), "CANDIDATE_COMPONENT")),
        ("guardian-drain-transition-removed", delete_value(("state_machines", "guardian_recovery", "transitions", 0))),
        ("guardian-direct-incomplete", append_value(("state_machines", "guardian_recovery", "transitions"), {"id": "GUARD-X", "from": "GUARD_ARMED", "to": "GUARDIAN_INCOMPLETE_PUBLISHED", "authority": "ROOT_GUARDIAN"})),
        ("reducer-owns-state-transition", set_value(("state_machines", "reduction", "transitions", 0, "authority"), "POST_RUN_REDUCER")),
        ("direct-reduction-pass", append_value(("state_machines", "reduction", "transitions"), {"id": "REDUCE-X", "from": "REDUCTION_DECLARED", "to": "REDUCTION_PASS", "authority": "REDUCTION_SUPERVISOR"})),
        ("strict-parse-bypassed", append_value(("state_machines", "reduction", "transitions"), {"id": "REDUCE-X", "from": "VERIFYING_RAW_COMMIT", "to": "REDUCING", "authority": "REDUCTION_SUPERVISOR"})),
        ("deadline-called-positive", set_value(("failure_taxonomy", 3, "positive_eligible"), True)),
        ("supervisor-death-skips-drain", set_value(("failure_taxonomy", 5, "requires_drain_if_launched"), False)),
        ("complete-capture-removed", delete_value(("failure_taxonomy", 11))),
        ("resource-policy-unsealed", set_value(("resource_policy", "policy_values_sealed_before_execution"), False)),
        ("run-bound-too-short", set_value(("resource_policy", "run_max_wall_seconds"), 135000)),
        ("unbounded-pids", set_value(("resource_policy", "pids_max_per_component"), 0)),
        ("component-memory-consumes-vm", set_value(("resource_policy", "memory_max_bytes_per_component"), 10737418240)),
        ("vm-minimum-below-reserve", set_value(("resource_policy", "required_vm_memory_min_bytes"), 8589934592)),
        ("supervisor-low-exceeds-reserve", set_value(("resource_policy", "supervisor_memory_low_bytes"), 3221225472)),
        ("raw-total-cannot-cover-streams", set_value(("resource_policy", "raw_total_max_bytes"), 1073741824)),
        ("resource-exhaustion-positive", set_value(("resource_policy", "resource_exhaustion_is_positive"), True)),
        ("audit-allocation-unbounded", set_value(("resource_policy", "audit_allocation_unbounded"), True)),
        ("invariant-removed", delete_value(("invariants", 29))),
        ("invariant-id-duplicated", set_value(("invariants", 1, "id"), "CAP-INV-001")),
        ("invariant-statement-empty", set_value(("invariants", 2, "statement"), "")),
        ("tla-semantic-anchor-removed", set_value(("invariants", 22, "statement"), "TLA is useful.")),
        ("invariant-enforcement-empty", set_value(("invariants", 7, "enforced_by"), [])),
        ("populated-zero-not-required", set_value(("positive_eligibility", "all_cgroups_populated_zero"), False)),
        ("raw-terminal-called-positive", set_value(("positive_eligibility", "raw_capture_terminal_is_never_positive"), False)),
        ("strict-json-not-required", set_value(("positive_eligibility", "strict_result_json_parsed_after_capture"), False)),
        ("external-authorization-change", set_value(("positive_eligibility", "external_authorization_change_allowed"), True)),
        ("wrong-positive-terminal", set_value(("positive_eligibility", "required_terminal_class"), "REDUCER_REJECTED")),
        ("scheduler-hot-path-touched", set_value(("performance_boundary", "production_linux_scheduler_hot_path_touched"), True)),
        ("monitor-hot-path-touched", set_value(("performance_boundary", "production_monitor_dispatch_hot_path_touched"), True)),
        ("architecture-claims-zero-overhead", set_value(("performance_boundary", "zero_overhead_claim_from_architecture_only"), True)),
        ("performance-measurement-not-required", set_value(("performance_boundary", "performance_claim_requires_measurement"), False)),
        ("global-scan-allowed-hot-path", delete_value(("performance_boundary", "forbidden_in_future_production_hot_path", 2))),
        ("gate-removed", delete_value(("implementation_gates", 6))),
        ("gates-reordered", swap_values(("implementation_gates",), 0, 1)),
        ("gate-self-completed", set_value(("implementation_gates", 0, "status"), "COMPLETE")),
        ("contract-self-accepted", set_value(("authorization", "authority_disjoint_contract_accepted"), True)),
        ("semantic-freeze-forged", set_value(("authorization", "semantic_freeze"), True)),
        ("deployment-claim-forged", set_value(("authorization", "deployment_claim"), True)),
        ("nonclaim-removed", delete_value(("nonclaims", 0))),
        ("malicious-root-nonclaim-weakened", set_value(("nonclaims", 3), "This contract is strong.")),
    ]


def expect_rejected(validator: Any, baseline: dict[str, Any], name: str, mutate: Mutator) -> None:
    candidate = copy.deepcopy(baseline)
    mutate(candidate)
    try:
        validator.validate_contract(candidate)
    except validator.ContractError:
        return
    raise SystemExit(f"hostile mutation accepted: {name}")


def state_policy_from_contract(candidate: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for machine_id, machine in candidate["state_machines"].items():
        result[machine_id] = {
            "initial": machine["initial"],
            "states": copy.deepcopy(machine["states"]),
            "terminal": copy.deepcopy(machine["terminal"]),
            "transitions": [
                (row["id"], row["from"], row["to"], row["authority"])
                for row in machine["transitions"]
            ],
        }
    return result


def object_policy_from_contract(candidate: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for row in candidate["object_authority"]["objects"]:
        result[row["id"]] = (
            copy.deepcopy(row["read_roles"]),
            copy.deepcopy(row["byte_producer_roles"]),
            copy.deepcopy(row["create_roles"]),
            copy.deepcopy(row["append_roles"]),
            copy.deepcopy(row["finalize_roles"]),
        )
    return result


def expect_derived_rejected(
    validator: Any,
    baseline: dict[str, Any],
    name: str,
    mutate: Mutator,
    align: PolicyAligner,
) -> None:
    candidate = copy.deepcopy(baseline)
    mutate(candidate)
    replacements = align(candidate)
    saved = {attribute: getattr(validator, attribute) for attribute in replacements}
    rejected = False
    try:
        for attribute, value in replacements.items():
            setattr(validator, attribute, value)
        validator.validate_contract(candidate)
    except validator.ContractError:
        rejected = True
    finally:
        for attribute, value in saved.items():
            setattr(validator, attribute, value)
    if not rejected:
        raise SystemExit(f"derived semantic mutation accepted: {name}")


def derived_mutation_cases() -> list[tuple[str, Mutator, PolicyAligner]]:
    align_resource = lambda candidate: {
        "RESOURCE_POLICY": copy.deepcopy(candidate["resource_policy"])
    }
    align_state = lambda candidate: {
        "STATE_MACHINE_POLICY": state_policy_from_contract(candidate)
    }
    align_object = lambda candidate: {
        "OBJECT_AUTHORITY_POLICY": object_policy_from_contract(candidate)
    }
    return [
        (
            "derived-run-deadline-sum",
            set_value(("resource_policy", "run_max_wall_seconds"), 135000),
            align_resource,
        ),
        (
            "derived-component-deadline-sum",
            set_value(("component_plan", "components", 2, "max_wall_seconds"), 45000),
            lambda candidate: {
                "COMPONENT_POLICY": [
                    (row["id"], row["role"], row["max_wall_seconds"])
                    for row in candidate["component_plan"]["components"]
                ]
            },
        ),
        (
            "derived-vm-memory-reserve",
            set_value(("resource_policy", "required_vm_memory_min_bytes"), 8589934592),
            align_resource,
        ),
        (
            "derived-supervisor-memory-reserve",
            set_value(("resource_policy", "supervisor_memory_low_bytes"), 3221225472),
            align_resource,
        ),
        (
            "derived-raw-total-bound",
            set_value(("resource_policy", "raw_total_max_bytes"), 1073741824),
            align_resource,
        ),
        (
            "derived-raw-complete-bypass",
            append_value(
                ("state_machines", "raw_capture", "transitions"),
                {
                    "id": "RAW-X",
                    "from": "RAW_DECLARED",
                    "to": "RAW_CAPTURE_COMPLETE",
                    "authority": "CAPTURE_SUPERVISOR",
                },
            ),
            align_state,
        ),
        (
            "derived-guardian-drain-bypass",
            append_value(
                ("state_machines", "guardian_recovery", "transitions"),
                {
                    "id": "GUARD-X",
                    "from": "GUARD_ARMED",
                    "to": "GUARDIAN_INCOMPLETE_PUBLISHED",
                    "authority": "ROOT_GUARDIAN",
                },
            ),
            align_state,
        ),
        (
            "derived-positive-reduction-bypass",
            append_value(
                ("state_machines", "reduction", "transitions"),
                {
                    "id": "REDUCE-X",
                    "from": "REDUCTION_DECLARED",
                    "to": "REDUCTION_PASS",
                    "authority": "REDUCTION_SUPERVISOR",
                },
            ),
            align_state,
        ),
        (
            "derived-transition-capability",
            set_value(
                ("state_machines", "raw_capture", "transitions", 0, "authority"),
                "ROOT_GUARDIAN",
            ),
            align_state,
        ),
        (
            "derived-candidate-evidence-writer",
            append_value(
                ("object_authority", "objects", 5, "create_roles"),
                "CANDIDATE_COMPONENT",
            ),
            align_object,
        ),
        (
            "derived-guardian-failure-writer",
            delete_value(("object_authority", "objects", 8, "create_roles", 0)),
            align_object,
        ),
        (
            "derived-reducer-storage-authority",
            append_value(
                ("object_authority", "objects", 12, "create_roles"),
                "POST_RUN_REDUCER",
            ),
            align_object,
        ),
        (
            "derived-preexec-interface-receipt",
            delete_value(("observation", "preexec_observation_required_fields", 8)),
            lambda candidate: {
                "PREEXEC_OBSERVATION_FIELDS": copy.deepcopy(
                    candidate["observation"]["preexec_observation_required_fields"]
                )
            },
        ),
    ]


def expect_raw_rejected(validator: Any, name: str, raw: str) -> None:
    with tempfile.TemporaryDirectory(prefix="f0-c4-contract-") as directory:
        path = Path(directory) / "candidate.json"
        path.write_text(raw, encoding="utf-8")
        try:
            value = validator.load_contract(path)
            validator.validate_contract(value)
        except validator.ContractError:
            return
    raise SystemExit(f"hostile raw JSON accepted: {name}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", nargs="?", type=Path, default=DEFAULT_CONTRACT)
    args = parser.parse_args()
    validator = load_validator()
    baseline = validator.load_contract(args.contract)
    validator.validate_contract(baseline)

    cases = mutation_cases()
    for name, mutate in cases:
        expect_rejected(validator, baseline, name, mutate)
    derived_cases = derived_mutation_cases()
    for name, mutate, align in derived_cases:
        expect_derived_rejected(validator, baseline, name, mutate, align)
    expect_raw_rejected(validator, "duplicate-key", '{"schema_version":1,"schema_version":1}')
    expect_raw_rejected(validator, "nonfinite-number", '{"schema_version":NaN}')
    count = len(cases) + len(derived_cases) + 2
    print(
        "F0_C4_AUTHORITY_CAPTURE_CONTRACT_MUTATIONS_PASS "
        f"hostile_cases={count} derived_cases={len(derived_cases)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
