#!/usr/bin/python3
"""Mechanism-only integration tests for the split Candidate-4 reducer."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
CONTRACT = HERE.parent.parent / "analysis" / "f0-c4-authority-disjoint-capture-contract-v1.json"
STATE_ROOT = Path("/var/lib/domainlease-f0-c4")
EVIDENCE_ROOT = STATE_ROOT / "evidence"
REDUCTION_ROOT = STATE_ROOT / "reductions"
TRUSTED_STAGE = Path(f"/run/f0-c4-reduction-test-{os.getpid()}")
SUPERVISOR = TRUSTED_STAGE / "f0-c4-reduction-supervisor.py"
REDUCER = TRUSTED_STAGE / "f0-c4-post-run-reducer.py"
STAGED_CONTRACT = TRUSTED_STAGE / "f0-c4-capture-contract-v1.json"
CONTRACT_SHA256 = "d5a1b44fc61d3f52542c1596dfe01ed510201486be8b2768ccb4a8901e72effe"
INPUT_DIGESTS = {
    "f0-supervisor-c4-claim-registry-v1.json": "c5496505a337c7c305115531b6a9169cb19f972024f8b3bd0805d4e2a7d2df7e",
    "f0_supervisor_lts_v3.py": "36493fe0ed88af4792111841492be31a37dd5c498c42e8dc86a2e8856fb6b192",
    "f0_supervisor_orchestrator_v3.py": "46a2788e5bdac5d96ad83204e57dda35582b5d6fdd878f9ba4e30854ab870bfb",
    "run-f0-supervisor-v3-full.sh": "2f27d0b6f57927f08186cf4635ed0474de084656385b2e0c1ae7a092cadd06ba",
    "test-f0-supervisor-lts-v3-mutations.py": "d9d97c511eb5c5a1103180a3d953df3f2e59448e86fc9d5a9faa744effa6205a",
    "test-f0-supervisor-orchestrator-v3-mutations.py": "a16f5392b963bbc37cd2c3b40d4bf8b4ad652f4b7073f74dbaa5af7ca61bf9cb",
    "test-run-f0-supervisor-v3-full.sh": "124947b2622811b60a20f753e6cfa6eae0a704afb11c95bb0fe1b80a11e78ec9",
    "validate-f0-supervisor-lts-v3.py": "83408bbcc7e1bf3abcf7165e7e32d2c34a1be55a8ddd78d212c77d6d95452e5c",
}
INPUT_ROOT_SHA256 = hashlib.sha256(
    json.dumps(INPUT_DIGESTS, sort_keys=True, separators=(",", ":")).encode()
).hexdigest()
COMPONENTS = (
    ("static-registries", "FAST_REGISTRY_CHECK", 1800),
    ("tests", "FAST_HOSTILE_REGRESSION", 3600),
    ("child-bundle-producer", "FULL_CHILD_PRODUCER", 43200),
    ("child-bundle-checker", "FULL_CHILD_CHECKER", 43200),
    ("orchestrator", "FULL_PARENT_ORCHESTRATOR", 43200),
)
AUTHORIZATION = {
    "authority_disjoint_contract_accepted": False,
    "authority_disjoint_launcher_implemented": False,
    "full_campaign_authorized": False,
    "F0_local_acceptance": False,
    "external_R11_review": False,
    "G0_authorized": False,
    "semantic_freeze": False,
    "TLA_translation": False,
    "linux_behavior_change": False,
    "monitor_implementation": False,
    "protection_claim": False,
    "performance_or_cost_claim": False,
    "deployment_claim": False,
}
ENVIRONMENT = {
    "F0_C4_EXACT_STORE_DIR": "/WORK",
    "PATH": "/usr/bin:/bin",
    "PYTHONPATH": "INPUT",
    "PYTHONDONTWRITEBYTECODE": "1",
    "PYTHONHASHSEED": "0",
}
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
    "external_memory_directory": "/WORK",
    "external_memory_host_root": "/var/lib/domainlease-f0-c4/work",
    "external_memory_filesystem": "vm_native_ext4",
    "external_memory_backing_mode": "per_component_sparse_loop_ext4",
    "external_memory_max_bytes_per_component": 137438953472,
    "external_memory_free_space_reserve_bytes": 10737418240,
    "external_memory_direct_io_required": True,
    "external_memory_unlinked_temporary_only": True,
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


def canonical(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode()


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def write(path: Path, raw: bytes, mode: int = 0o444) -> str:
    path.write_bytes(raw)
    path.chmod(mode)
    return digest(raw)


def provenance() -> dict[str, Any]:
    return {
        "bootstrap_input_hashes": INPUT_DIGESTS,
        "post_model_load_input_hashes": INPUT_DIGESTS,
        "input_hashes_before": INPUT_DIGESTS,
        "input_hashes_after": INPUT_DIGESTS,
        "input_root_sha256": INPUT_ROOT_SHA256,
        "executed_model_source_hashes": {
            "f0_supervisor_lts_v3.py": INPUT_DIGESTS["f0_supervisor_lts_v3.py"],
            "f0_supervisor_orchestrator_v3.py": INPUT_DIGESTS[
                "f0_supervisor_orchestrator_v3.py"
            ],
        },
        "bootstrap_source_execution_check": True,
        "runtime_input_write_prevention_enforced": False,
        "input_stability_during_execution_proved": False,
    }


def static_result() -> dict[str, Any]:
    def registry(count: int) -> dict[str, Any]:
        return {
            "declared_action_count": count,
            "write_policy_count": count,
            "write_policy_exact_registry_coverage": True,
            "required_write_policy_count": count,
            "required_write_policy_exact_registry_coverage": True,
            "required_writes_are_allowed": True,
        }

    return {
        "component": "static-registries",
        "claim_registry": {
            "artifact_id": "dynamic-residency-f0-v5-supervisor-v3-candidate4-claim-registry",
            "claim_count": 11,
            "sha256": INPUT_DIGESTS["f0-supervisor-c4-claim-registry-v1.json"],
            "candidate_authority_all_false": True,
        },
        "child": registry(56),
        "orchestrator": registry(46),
        "declared_independence_ids": [
            "IND-001-PRODUCER-A-NORMAL-EXIT",
            "IND-002-PRODUCER-B-NORMAL-EXIT",
            "IND-003-CHECKER-ACCEPT-NORMAL-EXIT",
            "IND-004-CHECKER-REJECT-NORMAL-EXIT",
            "IND-005-VALID-EOF-NORMAL-EXIT",
            "IND-006-FORK-ASYNC-ACQUIRE",
        ],
        "declared_independence_ids_unique": True,
        "semantic_registry_sha256": "be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789",
        "typed_store_attack_registry_exact": True,
        "reachability_checked": False,
        "passed": True,
        "worker_provenance": provenance(),
    }


def tests_result(passed: bool) -> dict[str, Any]:
    markers = (
        (
            "test-f0-supervisor-lts-v3-mutations.py",
            "LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=285",
        ),
        (
            "test-f0-supervisor-orchestrator-v3-mutations.py",
            "LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=739",
        ),
        (
            "test-run-f0-supervisor-v3-full.sh",
            "LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44",
        ),
    )
    return {
        "component": "tests",
        "tests": [
            {
                "path": path,
                "returncode": 0,
                "stdout": marker,
                "stderr": "",
                "expected_prefix": marker.rsplit("=", 1)[0] + "=",
                "exact_success_marker": True,
                "passed": True,
            }
            for path, marker in markers
        ],
        "passed": passed,
        "worker_provenance": provenance(),
    }


def exploration(role: str, actions: list[str]) -> dict[str, Any]:
    return {
        "role": role,
        "reachable_exact_state_count": 100,
        "unique_ordered_evidence_history_count": 50,
        "edge_count": 200,
        "reachable_action_count": len(actions),
        "reachable_action_ids": actions,
        "terminal_state_count": 10,
        "decision_counts": [["CANDIDATE", 5]],
        "nonterminal_deadlock_count": 0,
        "states_without_terminal_path": 0,
        "winner_overwrite_count": 0,
        "protection_breach_terminal_count": 1,
        "hostile_bypass_explicit": True,
        "coaccessibility_only": True,
        "universal_termination_proved": False,
        "infinite_stutter_counterexample_present": True,
        "management_domain_refinement_proved": False,
        "monitor_protection_refinement_proved": False,
        "external_assumptions_discharged": False,
        "linux_refinement_proved": False,
        "semantic_verdict_issued": False,
        "hostile_attempt_bound": 2,
        "reacquisition_bound": 2,
        "multiple_pending_arrival_state_count": 1,
        "exact_ordered_history_state_identity": True,
        "bounded_exact_ordered_history_graph_exhaustive": True,
        "frontier_empty": True,
        "all_reachable_states_wf": True,
        "all_edges_target_reachable": True,
        "exact_state_key_collision_count": 0,
    }


def commutation(role: str, independence_id: str) -> dict[str, Any]:
    pair = {
        "independence_id": independence_id,
        "actions": ["ACTION-LEFT", "ACTION-RIGHT"],
        "source_predicate_id": "SOURCE-FIXTURE",
        "minimum_source_count": 1,
        "expected_history_relation": "EXACT",
        "source_state_count": 1,
        "coenabled_state_count": 1,
        "both_orders_enabled_count": 1,
        "outcome_equal_count": 1,
        "exact_equal_count": 1,
        "ordered_history_distinct_count": 0,
        "preservation_failure_count": 0,
        "prefix_preservation_failure_count": 0,
        "audit_delta_failure_count": 0,
        "outcome_failure_count": 0,
        "history_relation_failure_count": 0,
        "preservation_counterexample_fingerprints": [],
        "prefix_counterexample_fingerprints": [],
        "audit_delta_counterexample_fingerprints": [],
        "outcome_counterexample_fingerprints": [],
        "history_counterexample_fingerprints": [],
        "passed": True,
    }
    return {
        "role": role,
        "reachable_exact_state_count": 100,
        "declared_independence_pair_count": 1,
        "declared_pair_results": [pair],
        "declared_pair_occurrences_exhaustive_over_reachable_states": True,
        "independence_relation_claimed_complete": False,
        "undeclared_pairs_assumed_independent": False,
        "reachability_uses_exact_state_identity": True,
        "ordered_history_quotiented_for_reachability": False,
        "check_scope": "LOCAL_TWO_STEP_EFFECT_COMMUTATION_ONLY",
        "outcome_projection_scope": "RECEIPT_CHAIN_ORDERING_METADATA_ONLY",
        "outcome_projection_retains_receipt_semantics_and_multiplicity": True,
        "outcome_projection_retains_causal_and_recovery_pointers": True,
        "outcome_projection_congruence_proved": False,
        "global_semantic_confluence_proved": False,
        "sealed_evidence_root_identity_proved": False,
        "passed": True,
    }


def child_result(component: str, role: str, actions: list[str], independence: str) -> dict[str, Any]:
    return {
        "component": component,
        "role": role,
        "exploration": exploration(role, actions),
        "commutation": commutation(role, independence),
        "single_graph_reused": True,
        "worker_provenance": provenance(),
    }


def orchestrator_result() -> dict[str, Any]:
    return {
        "component": "orchestrator",
        "result": {
            "exploration_semantics": "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL",
            "reachable_repetition_bounded_state_count": 100,
            "edge_count": 200,
            "terminal_counts": {"ASSURANCE_BREACHED": 1},
            "nonterminal_deadlock_count": 0,
            "states_without_terminal_path": 0,
            "declared_action_count": 46,
            "reachable_action_count": 46,
            "missing_actions": [],
            "undeclared_actions": [],
            "semantic_verdict_always_absent": True,
            "published_artifact_type": "LOCAL_DISPOSITION_CAPSULE",
            "external_assumptions_discharged": False,
            "durable_store_refinement_proved": False,
            "issuance_registry_refinement_proved": False,
            "global_nonce_uniqueness_proved": False,
            "symbolic_authentication_discharged": False,
            "exact_state_identity_within_repetition_bound": True,
            "attached_fixture_terminal_trace_replay_checked": True,
            "attached_fixture_scenarios": [
                "CANDIDATE",
                "CANDIDATE_B_PRODUCER_ONLY",
                "CHECKER_REJECT_CHECKER_ONLY",
                "RESOURCE",
                "INTERNAL",
                "ABANDONED",
            ],
            "all_child_terminal_traces_composed": False,
            "parent_child_product_exhaustive": False,
            "store_attack_repetition_policy": "FIRST_ATTEMPT_PER_TYPED_CONTEXT_REPETITION_BOUND",
            "max_store_attack_attempts_per_typed_context": 1,
            "repetition_bounded_state_space_exhaustive": True,
            "unbounded_attack_history_frontier_empty": False,
            "partial_order_reduction_applied": False,
            "partial_order_equivalence_proved": False,
            "unbounded_repeated_store_attack_history_exhaustive": False,
            "attack_context_key_refinement_proved": False,
            "multiple_store_attack_context_state_count": 1,
            "owner_failure_with_pending_attack_state_count": 1,
            "post_owner_publish_attack_state_count": 1,
            "guardian_generation_capsule_state_count": 1,
            "abandoned_terminal_requires_matching_ack": True,
            "typed_abandonment_conflict_withholds_assurance": True,
            "abandonment_conflict_breach_terminal_count": 1,
            "publication_fence_reauthorization_encoded": True,
            "publication_fence_store_refinement_proved": False,
            "coaccessibility_only": True,
            "universal_termination_proved": False,
            "infinite_stutter_counterexample_present": True,
            "assurance_breach_explicit": True,
            "assurance_breach_terminal_count": 1,
            "guardian_survivability_proved": False,
            "external_semantic_verdict_issued": False,
        },
        "worker_provenance": provenance(),
    }


def component_results(mutation: str) -> dict[str, bytes]:
    action_ids = [f"ACTION-{index:03d}" for index in range(56)]
    results: dict[str, Any] = {
        "static-registries": static_result(),
        "tests": tests_result(mutation != "semantic-reject"),
        "child-bundle-producer": child_result(
            "child-bundle-producer",
            "PRODUCER",
            action_ids[:28],
            "IND-001-PRODUCER-A-NORMAL-EXIT",
        ),
        "child-bundle-checker": child_result(
            "child-bundle-checker",
            "CHECKER",
            action_ids[28:],
            "IND-003-CHECKER-ACCEPT-NORMAL-EXIT",
        ),
        "orchestrator": orchestrator_result(),
    }
    payloads = {
        component: canonical(result).rstrip(b"\n") for component, result in results.items()
    }
    if mutation == "duplicate-json":
        payloads["static-registries"] = (
            b'{"component":"static-registries","component":"static-registries"}'
        )
    return payloads


def build_capture(run_id: str, mutation: str) -> Path:
    final = EVIDENCE_ROOT / run_id
    staging = EVIDENCE_ROOT / f".fixture-{run_id}"
    staging.mkdir(mode=0o700)
    input_dir = staging / "INPUT"
    raw_dir = staging / "raw"
    input_dir.mkdir(mode=0o700)
    raw_dir.mkdir(mode=0o700)
    source_root = HERE.parent
    for name, expected in INPUT_DIGESTS.items():
        raw = (source_root / name).read_bytes()
        if digest(raw) != expected:
            raise RuntimeError(f"fixture input digest drift: {name}")
        write(input_dir / name, raw)
    input_dir.chmod(0o555)
    plan = {
        "schema_version": 1,
        "contract_sha256": CONTRACT_SHA256,
        "input_root_sha256": INPUT_ROOT_SHA256,
        "parallel_execution": False,
        "environment": ENVIRONMENT,
        "components": [
            {
                "id": component,
                "role": role,
                "max_wall_seconds": deadline,
                "argv": [
                    "/usr/bin/python3",
                    "-S",
                    "-B",
                    "INPUT/validate-f0-supervisor-lts-v3.py",
                    "--component",
                    component,
                ],
            }
            for component, role, deadline in COMPONENTS
        ],
        "resource_policy": RESOURCE_POLICY,
    }
    plan_sha = write(staging / "sealed-plan.json", canonical(plan))
    contract_raw = canonical(json.loads(CONTRACT.read_text(encoding="utf-8")))
    if digest(contract_raw) != CONTRACT_SHA256:
        raise RuntimeError("contract digest drift")
    write(staging / "capture-contract.json", contract_raw)
    toolchain = {
        "mode": "content_addressed_immutable_image",
        "candidate4_admissible": True,
        "externally_authenticated": False,
        "manifest": {"image_format": "erofs"},
        "mount_identity": {"filesystem_type": "erofs", "mount_options": "ro,nodev,nosuid"},
    }
    toolchain_sha = write(staging / "toolchain-identity.json", canonical(toolchain))
    payloads = component_results(mutation)
    receipt_bindings: dict[str, str] = {}
    raw_total = 0
    environment_sha = digest(canonical(ENVIRONMENT))
    for component, role, deadline in COMPONENTS:
        stdout = b"RESULT_JSON=" + payloads[component] + b"\n"
        stderr = b""
        preexec = b"MECHANISM_ONLY_PREEXEC_FIXTURE\n"
        stdout_sha = write(raw_dir / f"{component}.stdout.raw", stdout)
        stderr_sha = write(raw_dir / f"{component}.stderr.raw", stderr)
        preexec_sha = write(raw_dir / f"{component}.preexec.raw", preexec)
        receipt = {
            "schema_version": 1,
            "component_id": component,
            "role": role,
            "sealed_plan_sha256": plan_sha,
            "input_root_sha256": INPUT_ROOT_SHA256,
            "argv": [
                "/usr/bin/python3",
                "-S",
                "-B",
                "INPUT/validate-f0-supervisor-lts-v3.py",
                "--component",
                component,
            ],
            "environment_sha256": environment_sha,
            "preexec_observation_size_sha256_and_bytes": {
                "path": f"{component}.preexec.raw",
                "size": len(preexec),
                "sha256": preexec_sha,
                "validated_fields": [
                    "fd_table",
                    "uid_gid_groups",
                    "capability_sets",
                    "no_new_privileges",
                    "seccomp_mode",
                    "mountinfo",
                    "namespace_ids",
                    "cgroup_identity",
                    "interface_inventory",
                ],
                "candidate_release_after_validation": True,
            },
            "cgroup_path_and_id": {"path": "/fixture", "inode": 1},
            "leader_pid_and_pidfd_identity": {"pid": 1, "pidfd_observed": True},
            "started_monotonic_ns": 1,
            "finished_monotonic_ns": 2,
            "waitid_status": {
                "code": 1,
                "status": 0,
                "termination": "EXITED_ZERO",
                "exit_code": 0,
                "signal": 0,
            },
            "deadline_classification": {
                "deadline_seconds": deadline,
                "exceeded": False,
                "clock": "CLOCK_MONOTONIC",
            },
            "stdout_size_sha256_and_bytes": {
                "path": f"{component}.stdout.raw",
                "size": len(stdout),
                "sha256": stdout_sha,
            },
            "stderr_size_sha256_and_bytes": {
                "path": f"{component}.stderr.raw",
                "size": 0,
                "sha256": stderr_sha,
            },
            "result_payload_sha256": digest(payloads[component]),
            "result_protocol_framing_valid": True,
            "result_protocol_semantics_validated": False,
            "resource_counters": {},
            "external_memory_boundary": {
                "host_root": "/var/lib/domainlease-f0-c4/work",
                "host_mount_identity": {
                    "device": "254:16",
                    "mount_point": "/",
                    "mount_options": "rw,relatime",
                    "filesystem_type": "ext4",
                    "source": "/dev/vdb",
                },
                "host_free_bytes_before_component": 200000000000,
                "host_required_free_bytes": 148176371712,
                "backing_mode": "per_component_sparse_loop_ext4",
                "logical_limit_bytes": 137438953472,
                "direct_io": True,
                "filesystem_type": "ext4",
                "mount_options": ["nodev", "noexec", "nosuid", "rw"],
                "candidate_path": "/WORK",
                "tool_sha256": {
                    "mke2fs": "0" * 64,
                    "losetup": "1" * 64,
                    "mount": "2" * 64,
                    "umount": "3" * 64,
                },
                "visible_entries_after_exit": 0,
                "unlinked_temporary_only_observed": True,
                "filesystem_free_bytes_after_exit": 137000000000,
                "backing_allocated_bytes_after_exit": 4096,
                "cleanup": {
                    "unmounted": True,
                    "loop_detached": True,
                    "backing_removed": True,
                },
            },
            "cgroup_kill_used": True,
            "populated_zero_observed": True,
            "toolchain_identity": {
                "sha256": toolchain_sha,
                "candidate4_admissible": True,
            },
            "launcher_returncode": 0,
            "complete_capture_component": True,
            "candidate_receipts_authoritative": False,
            "externally_attested": False,
        }
        receipt_raw = canonical(receipt)
        receipt_bindings[component] = write(
            raw_dir / f"{component}.receipt.json", receipt_raw
        )
        raw_total += len(stdout) + len(stderr) + len(preexec) + len(receipt_raw)
    raw_dir.chmod(0o555)
    manifest = {
        "schema_version": 1,
        "artifact_id": "f0-c4-authority-disjoint-root-capture-v1",
        "run_id": run_id,
        "campaign_class": "candidate4-exact",
        "capture_status": "RAW_CAPTURE_COMPLETE",
        "contract_sha256": CONTRACT_SHA256,
        "sealed_plan_sha256": plan_sha,
        "input_digests": INPUT_DIGESTS,
        "input_root_sha256": INPUT_ROOT_SHA256,
        "toolchain_identity_sha256": toolchain_sha,
        "platform_capacity": {},
        "evidence_storage": {},
        "systemd_guardian": {},
        "candidate_identity": {},
        "component_order": [row[0] for row in COMPONENTS],
        "component_receipt_sha256": receipt_bindings,
        "raw_total_bytes": raw_total,
        "started_and_finished_clock": "CLOCK_MONOTONIC",
        "finished_monotonic_ns": 2,
        "candidate_summary_is_an_oracle": False,
        "external_attestation": False,
        "authorization": AUTHORIZATION,
    }
    manifest_sha = write(staging / "capture-manifest.json", canonical(manifest))
    staging.rename(final)
    commit = {
        "schema_version": 1,
        "artifact_id": "f0-c4-raw-capture-commit-v1",
        "run_id": run_id,
        "capture_status": "RAW_CAPTURE_COMPLETE",
        "contract_sha256": CONTRACT_SHA256,
        "manifest_sha256": manifest_sha,
        "publication": "renameat2_RENAME_NOREPLACE_then_parent_fsync",
        "commit_authority": "CAPTURE_SUPERVISOR",
        "candidate_bytes_positive_eligible": False,
        "reduction_performed": False,
    }
    write(final / "RAW_COMMIT.json", canonical(commit))
    final.chmod(0o555)
    return final


def remove_tree(path: Path) -> None:
    if not path.exists():
        return
    for root, directories, files in os.walk(path, topdown=False):
        Path(root).chmod(0o700)
        for name in files:
            (Path(root) / name).chmod(0o600)
            (Path(root) / name).unlink()
        for name in directories:
            directory = Path(root) / name
            directory.chmod(0o700)
            directory.rmdir()
    path.rmdir()


def run_case(case: str, expected_status: str, expected_failure: str | None) -> None:
    run_id = f"reducer-{case}-{os.getpid()}"
    build_capture(run_id, case)
    unit = f"domainlease-f0-c4-reduction-{run_id}"
    command = [
        "/usr/bin/systemd-run",
        "--quiet",
        "--wait",
        "--pipe",
        "--collect",
        "--unit",
        unit,
        "--service-type",
        "exec",
        "--setenv",
        "F0_C4_REDUCTION_SUPERVISOR=systemd-v1",
        "--setenv",
        f"F0_C4_REDUCTION_UNIT={unit}.service",
        "--property",
        "StandardInput=null",
        "--",
        "/usr/bin/python3",
        "-I",
        "-S",
        "-B",
        str(SUPERVISOR),
        "--run-id",
        run_id,
        "--reducer",
        str(REDUCER),
        "--contract",
        str(STAGED_CONTRACT),
    ]
    completed = subprocess.run(command, check=False, capture_output=True)
    reduction = REDUCTION_ROOT / run_id
    if not reduction.is_dir():
        raise RuntimeError(
            f"{case}: reduction was not published rc={completed.returncode} "
            f"stdout={completed.stdout!r} stderr={completed.stderr!r}"
        )
    manifest = json.loads((reduction / "reduction-manifest.json").read_bytes())
    commit = json.loads((reduction / "REDUCTION_COMMIT.json").read_bytes())
    result_path = reduction / "reduction-result.json"
    if not result_path.is_file():
        reducer_stdout = (reduction / "reducer.stdout.raw").read_bytes()
        reducer_stderr = (reduction / "reducer.stderr.raw").read_bytes()
        execution = (reduction / "reducer-execution-receipt.json").read_bytes()
        raise RuntimeError(
            f"{case}: reducer result absent manifest={manifest!r} "
            f"supervisor_stdout={completed.stdout!r} "
            f"supervisor_stderr={completed.stderr!r} "
            f"reducer_stdout={reducer_stdout!r} "
            f"reducer_stderr={reducer_stderr!r} execution={execution!r}"
        )
    result = json.loads(result_path.read_bytes())
    if (
        manifest["reduction_status"] != expected_status
        or manifest["failure_class"] != expected_failure
        or commit["reduction_status"] != expected_status
        or result["reduction_status"] != expected_status
        or result["failure_class"] != expected_failure
        or result["positive_eligible"] is not (expected_status == "REDUCTION_PASS")
        or result["authorization"]["F0_local_acceptance"] is not False
        or result["authorization"]["external_R11_review"] is not False
        or result["authorization"]["G0_authorized"] is not False
        or result["runtime_identity"]["uid"] != 200011
        or result["runtime_identity"]["status"]["CapEff"] != "0000000000000000"
        or result["runtime_identity"]["status"]["NoNewPrivs"] != "1"
        or result["runtime_identity"]["status"]["Seccomp"] != "2"
        or result["runtime_identity"]["usr_mount"]["filesystem_type"] != "erofs"
    ):
        raise RuntimeError(f"{case}: reduction semantics differ")
    remove_tree(EVIDENCE_ROOT / run_id)
    remove_tree(reduction)


def main() -> int:
    if os.geteuid() != 0 or os.getegid() != 0:
        raise SystemExit("root is required")
    for path in (STATE_ROOT, EVIDENCE_ROOT, REDUCTION_ROOT):
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chown(path, 0, 0)
        path.chmod(0o700)
    TRUSTED_STAGE.mkdir(mode=0o755)
    for source, target, mode in (
        (HERE / "f0_c4_reduction_supervisor.py", SUPERVISOR, 0o755),
        (HERE / "f0_c4_post_run_reducer.py", REDUCER, 0o755),
        (CONTRACT, STAGED_CONTRACT, 0o444),
    ):
        shutil.copyfile(source, target)
        os.chown(target, 0, 0)
        target.chmod(mode)
    try:
        run_case("pass", "REDUCTION_PASS", None)
        run_case("semantic-reject", "REDUCTION_REJECT", "REDUCER_REJECTED")
        run_case("duplicate-json", "REDUCTION_REJECT", "STRICT_RESULT_INVALID")
    finally:
        for case in ("pass", "semantic-reject", "duplicate-json"):
            run_id = f"reducer-{case}-{os.getpid()}"
            remove_tree(EVIDENCE_ROOT / run_id)
            remove_tree(REDUCTION_ROOT / run_id)
        shutil.rmtree(TRUSTED_STAGE, ignore_errors=True)
    print("F0_C4_REDUCTION_BOUNDARY_PASS cases=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
