#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUNNER=${SCRIPT_DIR}/run-f0-supervisor-v3-full.sh
PYTHON_BIN=$(command -v python3)
TEST_ROOT=$(mktemp -d)
HOSTILE_CASES=0

cleanup() {
    chmod -R u+w "${TEST_ROOT}" 2>/dev/null || true
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

die() {
    printf 'runner regression failure: %s\n' "$1" >&2
    exit 1
}

[[ $(uname -s) == Linux && -r /proc/self/cmdline ]] ||
    die 'Linux with procfs is required for runner lifecycle regression'

prepare_fixture() {
    local scenario=$1
    local root=${TEST_ROOT}/${scenario}
    local source=${root}/source
    local scenario_json
    local parent_pid_file_json
    local child_pid_file_json

    FIXTURE_ROOT=${root}
    FIXTURE_SOURCE=${source}
    FIXTURE_RESULTS=${root}/results
    FIXTURE_RUN=${FIXTURE_RESULTS}/run
    FIXTURE_EXPECTED=${root}/expected.sha256
    SIGNAL_PARENT_PID_FILE=${root}/validator.pid
    SIGNAL_CHILD_PID_FILE=${root}/validator-child.pid
    scenario_json=$("${PYTHON_BIN}" -c \
        'import json,sys; print(json.dumps(sys.argv[1]))' "${scenario}")
    parent_pid_file_json=$("${PYTHON_BIN}" -c \
        'import json,sys; print(json.dumps(sys.argv[1]))' \
        "${SIGNAL_PARENT_PID_FILE}")
    child_pid_file_json=$("${PYTHON_BIN}" -c \
        'import json,sys; print(json.dumps(sys.argv[1]))' \
        "${SIGNAL_CHILD_PID_FILE}")

    mkdir -p -- "${source}"
    cp -- "${RUNNER}" "${source}/run-f0-supervisor-v3-full.sh"
    cp -- "${SCRIPT_DIR}/f0-supervisor-c4-claim-registry-v1.json" \
        "${source}/f0-supervisor-c4-claim-registry-v1.json"
    chmod 0755 "${source}/run-f0-supervisor-v3-full.sh"

    for name in \
        f0_supervisor_lts_v3.py \
        f0_supervisor_orchestrator_v3.py \
        test-f0-supervisor-lts-v3-mutations.py \
        test-f0-supervisor-orchestrator-v3-mutations.py \
        test-run-f0-supervisor-v3-full.sh; do
        printf '# isolated runner fixture: %s\n' "${name}" > "${source}/${name}"
    done

    cat > "${source}/validate-f0-supervisor-lts-v3.py" <<PY
#!/usr/bin/env python3
import base64
import json
import hashlib
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

SCENARIO = ${scenario_json}
PARENT_PID_FILE = Path(${parent_pid_file_json})
CHILD_PID_FILE = Path(${child_pid_file_json})

arguments = sys.argv[1:]
if "--output" not in arguments:
    raise SystemExit(65)
output = Path(arguments[arguments.index("--output") + 1])

if SCENARIO == "tool-error":
    raise SystemExit(7)
if SCENARIO == "voluntary-124":
    raise SystemExit(124)
if SCENARIO == "voluntary-143":
    raise SystemExit(143)
if SCENARIO == "timeout":
    time.sleep(60)
    raise SystemExit(71)
if SCENARIO == "timeout-ignore-term":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    child = subprocess.Popen(["/bin/sleep", "60"])
    PARENT_PID_FILE.write_text(str(os.getpid()) + "\n", encoding="ascii")
    CHILD_PID_FILE.write_text(str(child.pid) + "\n", encoding="ascii")
    child.wait()
    raise SystemExit(73)
if SCENARIO == "timeout-leader-exits-child-ignores":
    child = subprocess.Popen(
        [
            "/usr/bin/python3",
            "-S",
            "-B",
            "-c",
            "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)",
        ]
    )
    PARENT_PID_FILE.write_text(str(os.getpid()) + "\n", encoding="ascii")
    CHILD_PID_FILE.write_text(str(child.pid) + "\n", encoding="ascii")
    raise SystemExit(75)
if SCENARIO == "signal":
    child = subprocess.Popen(["/bin/sleep", "60"])
    PARENT_PID_FILE.write_text(str(os.getpid()) + "\n", encoding="ascii")
    CHILD_PID_FILE.write_text(str(child.pid) + "\n", encoding="ascii")
    child.wait()
    raise SystemExit(72)

authorization = {
    "local_executable_candidate": False,
    "external_R11_review": False,
    "G0_authorized": False,
    "self_authorization": SCENARIO == "invalid-authorization",
    "standalone_child_bounded_exact_ordered_history_graph_exhaustive": True,
    "standalone_child_bounds": {
        "hostile_attempts": 2,
        "reacquisitions": 2,
    },
    "declared_local_effect_commutation_checked": True,
    "independence_relation_complete": False,
    "commutation_projection_congruence": False,
    "global_semantic_confluence": False,
    "unbounded_ordered_history_state_space_exhaustive": False,
    "unbounded_repeated_store_attack_history_exhaustive": False,
    "attack_context_key_refinement": False,
    "parent_child_product_exhaustive": False,
    "external_authentication_assumption_discharged": False,
    "linux_refinement": SCENARIO == "forbidden-local-overclaim",
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
}
status = (
    "COMPLETE_LOCAL_C4_REJECTED"
    if SCENARIO == "rejected"
    else "COMPLETE_LOCAL_C4_CANDIDATE_ONLY"
)
claim_registry_path = Path(__file__).with_name(
    "f0-supervisor-c4-claim-registry-v1.json"
)
claim_registry = json.loads(claim_registry_path.read_text(encoding="utf-8"))
claims = {}
for row in claim_registry["claims"]:
    allowed = row["full"]["allowed_statuses"]
    if SCENARIO == "rejected" and "FAIL" in allowed:
        claim_status = "FAIL"
    elif "PASS" in allowed:
        claim_status = "PASS"
    else:
        claim_status = allowed[0]
    claims[row["id"]] = {
        "status": claim_status,
        "evidence": row["full"]["evidence"],
    }
if SCENARIO == "claim-evidence-mismatch":
    first_claim_id = claim_registry["claims"][0]["id"]
    claims[first_claim_id]["evidence"] = []
if SCENARIO == "claim-predicate-mismatch":
    first_claim_id = claim_registry["claims"][0]["id"]
    claims[first_claim_id]["status"] = "FAIL"
input_names = (
    "f0-supervisor-c4-claim-registry-v1.json",
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "test-run-f0-supervisor-v3-full.sh",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
)
fake_hashes = {
    name: hashlib.sha256((Path(__file__).parent / name).read_bytes()).hexdigest()
    for name in input_names
}
child_exploration = {
    "role": "FIXTURE",
    "edge_count": 5,
    "terminal_state_count": 2,
    "unique_ordered_evidence_history_count": 1,
    "reachable_exact_state_count": 5,
    "reachable_action_count": 4,
    "reachable_action_ids": [
        "FIXTURE-ACTION",
        "FIXTURE-LEFT",
        "FIXTURE-OTHER",
        "FIXTURE-RIGHT",
    ],
    "nonterminal_deadlock_count": 0,
    "states_without_terminal_path": 0,
    "winner_overwrite_count": 0,
    "decision_counts": [["LOCAL_SYNTACTIC_CANDIDATE", 1]],
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
commutation = {
    "role": "FIXTURE",
    "reachable_exact_state_count": 5,
    "passed": True,
    "declared_independence_pair_count": 1,
    "declared_pair_results": [
        {
            "independence_id": "FIXTURE-IND-001",
            "actions": ["FIXTURE-LEFT", "FIXTURE-RIGHT"],
            "source_predicate_id": "FIXTURE-SOURCE",
            "minimum_source_count": 1,
            "expected_history_relation": "ORDER_DISTINCT",
            "source_state_count": 1,
            "coenabled_state_count": 1,
            "both_orders_enabled_count": 1,
            "outcome_equal_count": 1,
            "exact_equal_count": 0,
            "ordered_history_distinct_count": 1,
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
    ],
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
}
parent_exploration = {
    "reachable_repetition_bounded_state_count": 3,
    "edge_count": 2,
    "terminal_counts": {"ASSURANCE_BREACHED": 1, "PUBLISHED": 1},
    "declared_action_count": 2,
    "reachable_action_count": 2,
    "nonterminal_deadlock_count": 0,
    "states_without_terminal_path": 0,
    "missing_actions": [],
    "undeclared_actions": [],
    "semantic_verdict_always_absent": True,
    "published_artifact_type": "LOCAL_DISPOSITION_CAPSULE",
    "external_assumptions_discharged": False,
    "durable_store_refinement_proved": False,
    "issuance_registry_refinement_proved": False,
    "global_nonce_uniqueness_proved": False,
    "symbolic_authentication_discharged": False,
    "exploration_semantics": "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL",
    "exact_state_identity_within_repetition_bound": True,
    "attached_fixture_terminal_trace_replay_checked": True,
    "attached_fixture_scenarios": ["CANDIDATE"],
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
}
local_component_pass = SCENARIO != "rejected"
if not local_component_pass:
    child_exploration["nonterminal_deadlock_count"] = 1
    child_exploration["reachable_exact_state_count"] = 4
    commutation["reachable_exact_state_count"] = 4
    commutation["passed"] = False
    parent_exploration["nonterminal_deadlock_count"] = 1
    parent_exploration["reachable_repetition_bounded_state_count"] = 4
    parent_exploration["edge_count"] = 3
test_specs = (
    (
        "test-f0-supervisor-lts-v3-mutations.py",
        "LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=",
    ),
    (
        "test-f0-supervisor-orchestrator-v3-mutations.py",
        "LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=",
    ),
    (
        "test-run-f0-supervisor-v3-full.sh",
        "LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=",
    ),
)
test_results = []
for index, (path, prefix) in enumerate(test_specs):
    returncode = 0 if local_component_pass or index > 0 else 1
    test_results.append(
        {
            "path": path,
            "returncode": returncode,
            "stdout": prefix + "1",
            "stderr": "",
            "expected_prefix": prefix,
            "exact_success_marker": True,
            "passed": returncode == 0,
        }
    )
result = {
    "schema_version": 4,
    "artifact_id": (
        "dynamic-residency-f0-v5-supervisor-v3-candidate4-full-local-result"
    ),
    "status": status,
    "claim_registry": {
        "artifact_id": claim_registry["artifact_id"],
        "sha256": hashlib.sha256(claim_registry_path.read_bytes()).hexdigest(),
    },
    "claims": claims,
    "authorization": authorization,
    "input_hashes_equal_before_after": True,
    "bootstrap_source_execution_check": True,
    "bootstrap_input_hashes": fake_hashes,
    "post_model_load_input_hashes": fake_hashes,
    "input_hashes_before": fake_hashes,
    "input_hashes_after": fake_hashes,
    "executed_model_source_hashes": {
        "f0_supervisor_lts_v3.py": fake_hashes["f0_supervisor_lts_v3.py"],
        "f0_supervisor_orchestrator_v3.py": fake_hashes[
            "f0_supervisor_orchestrator_v3.py"
        ],
    },
    "components": {
        "static-registries": {
            "component": "static-registries",
            "claim_registry": {
                "artifact_id": claim_registry["artifact_id"],
                "claim_count": len(claim_registry["claims"]),
                "sha256": hashlib.sha256(
                    claim_registry_path.read_bytes()
                ).hexdigest(),
                "candidate_authority_all_false": True,
            },
            "child": {
                "declared_action_count": 4,
                "write_policy_count": 4,
                "write_policy_exact_registry_coverage": True,
                "required_write_policy_count": 4,
                "required_write_policy_exact_registry_coverage": True,
                "required_writes_are_allowed": True,
            },
            "orchestrator": {
                "declared_action_count": 2,
                "write_policy_count": 2,
                "write_policy_exact_registry_coverage": True,
                "required_write_policy_count": 2,
                "required_write_policy_exact_registry_coverage": True,
                "required_writes_are_allowed": True,
            },
            "declared_independence_ids": ["FIXTURE-IND-001"],
            "declared_independence_ids_unique": True,
            "semantic_registry_sha256": hashlib.sha256(
                b"fixture-semantic-registry"
            ).hexdigest(),
            "typed_store_attack_registry_exact": True,
            "reachability_checked": False,
            "passed": local_component_pass,
        },
        "tests": {
            "component": "tests",
            "tests": test_results,
            "passed": local_component_pass,
        },
        "child-bundle-producer": {
            "component": "child-bundle-producer",
            "role": "PRODUCER",
            "exploration": {**child_exploration, "role": "PRODUCER"},
            "commutation": {**commutation, "role": "PRODUCER"},
            "single_graph_reused": True,
        },
        "child-bundle-checker": {
            "component": "child-bundle-checker",
            "role": "CHECKER",
            "exploration": {**child_exploration, "role": "CHECKER"},
            "commutation": {**commutation, "role": "CHECKER"},
            "single_graph_reused": True,
        },
        "orchestrator": {
            "component": "orchestrator",
            "result": parent_exploration,
        },
    },
    "component_execution_receipts": {},
    "child_action_registry": {
        "declared_action_count": 4,
        "combined_reachable_action_count": 4,
        "missing_actions": [],
        "undeclared_actions": [],
        "exact": True,
    },
    "open_refinement_obligations": {
        "child": [
            "INDEP-001 fixture declared independence refinement",
            "EXT-AUTH-001 fixture external authentication refinement",
            "MONITOR-001 fixture monitor authentication refinement",
            "MGMT-001 fixture management isolation refinement",
        ],
        "orchestrator": [
            "ORCH-EXT-001 fixture external grant refinement",
            "ORCH-REG-001 fixture issuance registry refinement",
            "ORCH-ATTACK-CTX-001 fixture attack context refinement",
            "ORCH-STORE-001 fixture durable store refinement",
            "ORCH-INDEP-001 fixture child independence refinement",
            "ORCH-CHILD-001 fixture child attachment refinement",
        ],
    },
    "provenance_boundary": {
        "symbolic_model_workload_input": "input-root-a",
        "symbolic_model_workload_input_is_source_manifest": False,
        "source_files_bound_by_input_hashes": False,
        "source_file_bytes_hashed_before_and_after_local_checks": True,
        "model_modules_compiled_from_bootstrap_hashed_source_bytes": True,
        "validator_source_execution_bound_by_external_launcher": False,
        "raw_component_stdout_receipts_bound_to_components": True,
        "component_execution_receipts_externally_attested": False,
        "runtime_input_write_prevention_enforced": False,
        "input_stability_during_execution_proved": False,
        "external_R11_evidence_present": False,
        "G0_evidence_present": False,
    },
}
if SCENARIO == "unknown-nested-field":
    result["components"]["static-registries"][
        "unexpected_authority_surface"
    ] = True
if SCENARIO == "type-confusion":
    result["components"]["static-registries"]["child"][
        "declared_action_count"
    ] = True
if SCENARIO == "test-returncode-bool":
    result["components"]["tests"]["tests"][0]["returncode"] = False
if SCENARIO == "commutation-unreachable-action":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        result["components"][role]["commutation"]["declared_pair_results"][0][
            "actions"
        ] = ["FIXTURE-UNKNOWN", "FIXTURE-RIGHT"]
if SCENARIO == "role-action-union-split":
    producer = result["components"]["child-bundle-producer"]["exploration"]
    checker = result["components"]["child-bundle-checker"]["exploration"]
    producer["reachable_action_ids"] = [
        "FIXTURE-ACTION",
        "FIXTURE-LEFT",
        "FIXTURE-RIGHT",
    ]
    producer["reachable_action_count"] = 3
    checker["reachable_action_ids"] = [
        "FIXTURE-LEFT",
        "FIXTURE-OTHER",
        "FIXTURE-RIGHT",
    ]
    checker["reachable_action_count"] = 3
if SCENARIO == "commutation-negative-state-count":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        result["components"][role]["commutation"][
            "reachable_exact_state_count"
        ] = -1
if SCENARIO == "commutation-impossible-counts":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        pair = result["components"][role]["commutation"][
            "declared_pair_results"
        ][0]
        pair["coenabled_state_count"] = 0
        pair["both_orders_enabled_count"] = 1
if SCENARIO == "commutation-impossible-edge-lower-bound":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        pair = result["components"][role]["commutation"][
            "declared_pair_results"
        ][0]
        pair["source_state_count"] = 3
        pair["coenabled_state_count"] = 3
        pair["both_orders_enabled_count"] = 3
        pair["outcome_equal_count"] = 3
        pair["ordered_history_distinct_count"] = 3
if SCENARIO == "child-impossible-cardinality":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        exploration = result["components"][role]["exploration"]
        exploration["terminal_state_count"] = 5
        exploration["protection_breach_terminal_count"] = 5
if SCENARIO == "child-impossible-edge-count":
    for role in ("child-bundle-producer", "child-bundle-checker"):
        result["components"][role]["exploration"]["edge_count"] = 13
if SCENARIO == "parent-impossible-cardinality":
    result["components"]["orchestrator"]["result"]["terminal_counts"] = {
        "ASSURANCE_BREACHED": 2,
        "PUBLISHED": 1,
    }
    result["components"]["orchestrator"]["result"][
        "assurance_breach_terminal_count"
    ] = 2
if SCENARIO == "parent-impossible-edge-count":
    result["components"]["orchestrator"]["result"]["edge_count"] = 3
if SCENARIO == "child-action-registry-number-type":
    result["child_action_registry"]["declared_action_count"] = 4.0
input_root_sha256 = hashlib.sha256(
    json.dumps(fake_hashes, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
worker_provenance = {
    "bootstrap_input_hashes": fake_hashes,
    "post_model_load_input_hashes": fake_hashes,
    "input_hashes_before": fake_hashes,
    "input_hashes_after": fake_hashes,
    "input_root_sha256": input_root_sha256,
    "executed_model_source_hashes": {
        "f0_supervisor_lts_v3.py": fake_hashes["f0_supervisor_lts_v3.py"],
        "f0_supervisor_orchestrator_v3.py": fake_hashes[
            "f0_supervisor_orchestrator_v3.py"
        ],
    },
    "bootstrap_source_execution_check": True,
    "runtime_input_write_prevention_enforced": False,
    "input_stability_during_execution_proved": False,
}
if SCENARIO == "worker-provenance-mismatch":
    worker_provenance["input_root_sha256"] = "0" * 64
for component_name, component_result in result["components"].items():
    component_result["worker_provenance"] = worker_provenance
    component_payload = json.dumps(
        component_result,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    stdout_payload = b"RESULT_JSON=" + component_payload + b"\n"
    result["component_execution_receipts"][component_name] = {
        "schema_version": 1,
        "component": component_name,
        "argv": [
            sys.executable,
            "-S",
            "-B",
            str(Path(__file__).resolve()),
            "--component",
            component_name,
        ],
        "returncode": 0,
        "termination": "EXITED_ZERO",
        "input_root_sha256": input_root_sha256,
        "stdout_base64": base64.b64encode(stdout_payload).decode("ascii"),
        "stdout_sha256": hashlib.sha256(stdout_payload).hexdigest(),
        "stderr_base64": "",
        "stderr_sha256": hashlib.sha256(b"").hexdigest(),
        "result_payload_sha256": hashlib.sha256(component_payload).hexdigest(),
        "capture_authority": "candidate_validator_local_process",
        "externally_attested": False,
        "descendant_containment_proved": False,
    }
if SCENARIO == "raw-receipt-mismatch":
    result["components"]["static-registries"]["passed"] = (
        not result["components"]["static-registries"]["passed"]
    )
if SCENARIO == "receipt-digest-mismatch":
    result["component_execution_receipts"]["static-registries"][
        "stdout_sha256"
    ] = "0" * 64
if SCENARIO == "component-argv-mismatch":
    result["component_execution_receipts"]["static-registries"]["argv"][-1] = (
        "tests"
    )
authorization["local_executable_candidate"] = (
    status == "COMPLETE_LOCAL_C4_CANDIDATE_ONLY"
)
if SCENARIO == "unknown-result-field":
    result["unexpected_authority_surface"] = True
if SCENARIO == "claim-obligation-missing":
    result["open_refinement_obligations"]["orchestrator"] = [
        row
        for row in result["open_refinement_obligations"]["orchestrator"]
        if not row.startswith("ORCH-STORE-001 ")
    ]

if SCENARIO in {"input-mutation", "manifest-rewrite"}:
    own_path = Path(__file__)
    own_path.chmod(0o644)
    with own_path.open("a", encoding="utf-8") as handle:
        handle.write("# hostile post-capture mutation\n")
if SCENARIO == "manifest-rewrite":
    names = (
        "f0-supervisor-c4-claim-registry-v1.json",
        "f0_supervisor_lts_v3.py",
        "f0_supervisor_orchestrator_v3.py",
        "test-f0-supervisor-lts-v3-mutations.py",
        "test-f0-supervisor-orchestrator-v3-mutations.py",
        "test-run-f0-supervisor-v3-full.sh",
        "validate-f0-supervisor-lts-v3.py",
        "run-f0-supervisor-v3-full.sh",
    )
    lines = []
    for name in names:
        digest = hashlib.sha256((own_path.parent / name).read_bytes()).hexdigest()
        lines.append(f"{digest}  {name}\n")
    rewritten = "".join(lines)
    for name in (
        "input-manifest.expected.sha256",
        "input-manifest.before.sha256",
    ):
        manifest = output.parent / name
        manifest.chmod(0o644)
        manifest.write_text(rewritten, encoding="ascii")

encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
if SCENARIO == "duplicate-result-key":
    encoded = '{"status":"COMPLETE_LOCAL_C4_REJECTED",' + encoded[1:]
if SCENARIO == "nonfinite-json":
    encoded = encoded.replace('"schema_version": 4', '"schema_version": NaN', 1)
output.write_text(encoded, encoding="utf-8")
if SCENARIO == "result-post-parse-mutation":
    mutator = r'''
from pathlib import Path
import sys
import time

result_path = Path(sys.argv[1])
after_manifest = result_path.parent / "input-manifest.after.sha256"
for _ in range(30000):
    if after_manifest.exists():
        with result_path.open("a", encoding="ascii") as handle:
            handle.write(" ")
        raise SystemExit(0)
    time.sleep(0.001)
raise SystemExit(1)
'''
    subprocess.Popen(
        ["/usr/bin/python3", "-S", "-c", mutator, str(output)],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
raise SystemExit(1 if SCENARIO == "rejected" else 0)
PY

    (
        cd "${source}"
        sha256sum -- \
            f0-supervisor-c4-claim-registry-v1.json \
            f0_supervisor_lts_v3.py \
            f0_supervisor_orchestrator_v3.py \
            test-f0-supervisor-lts-v3-mutations.py \
            test-f0-supervisor-orchestrator-v3-mutations.py \
            test-run-f0-supervisor-v3-full.sh \
            validate-f0-supervisor-lts-v3.py \
            run-f0-supervisor-v3-full.sh
    ) > "${FIXTURE_EXPECTED}"
}

assert_status() {
    local expected=$1
    local actual

    [[ -f "${FIXTURE_RUN}/status" ]] || die "${expected}: status missing"
    actual=$(< "${FIXTURE_RUN}/status")
    [[ "${actual}" == "${expected}" ]] ||
        die "expected status ${expected}, got ${actual}"
}

assert_rejection_contains() {
    local expected=$1

    if ! grep -Fq -- "${expected}" "${FIXTURE_ROOT}/stderr" &&
       ! grep -Fq -- "${expected}" "${FIXTURE_RUN}/run.log"; then
        sed -n '1,160p' "${FIXTURE_ROOT}/stderr" >&2 || true
        sed -n '1,160p' "${FIXTURE_RUN}/run.log" >&2 || true
        die "${FIXTURE_ROOT##*/}: missing targeted rejection: ${expected}"
    fi
}

assert_evidence() {
    local terminal=$1
    local requested=$2
    local hashes_equal=$3
    local result_present=$4
    local expected_manifest_match=${5:-true}
    local manifest_files_unchanged=${6:-true}

    "${PYTHON_BIN}" -B - \
        "${FIXTURE_RUN}/runner-evidence.json" \
        "${terminal}" \
        "${requested}" \
        "${hashes_equal}" \
        "${result_present}" \
        "${expected_manifest_match}" \
        "${manifest_files_unchanged}" <<'PY'
import json
import sys

(
    path,
    terminal,
    requested,
    hashes_equal,
    result_present,
    expected_manifest_match,
    manifest_files_unchanged,
) = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    evidence = json.load(handle)

if evidence["terminal_status"] != terminal:
    raise SystemExit("terminal status mismatch")
if evidence["requested_terminal_status"] != requested:
    raise SystemExit("requested terminal status mismatch")
if evidence["input_hashes_equal_before_after"] is not (hashes_equal == "true"):
    raise SystemExit("input hash equality flag mismatch")
if evidence["runtime_input_write_prevention_enforced"] is not False:
    raise SystemExit("runner overclaimed runtime write prevention")
if evidence["input_stability_during_execution_proved"] is not False:
    raise SystemExit("runner overclaimed continuous input stability")
if evidence["toolchain_authenticated_by_external_root"] is not False:
    raise SystemExit("runner overclaimed toolchain authentication")
if evidence["validator_descendant_containment_proved"] is not False:
    raise SystemExit("runner overclaimed descendant containment")
if evidence["post_finalization_storage_immutability_proved"] is not False:
    raise SystemExit("runner overclaimed post-finalization immutability")
if evidence["toolchain_runtime_closure_proved"] is not False:
    raise SystemExit("runner overclaimed toolchain runtime closure")
if evidence["term_to_kill_process_group_escalation_bounded"] is not True:
    raise SystemExit("runner omitted bounded process-group escalation")
if requested != "PRECONDITION_REJECTED" and evidence[
    "validator_process_group_empty_after_cleanup"
] is not True:
    raise SystemExit("validator process group did not become empty")
if terminal == "INCOMPLETE_TIMEOUT":
    if evidence["configured_deadline_reached"] is not True:
        raise SystemExit("timeout lacks a reached configured deadline")
    if evidence["configured_timeout_seconds"] is None:
        raise SystemExit("timeout lacks a configured duration")
elif evidence["configured_deadline_reached"] is not False:
    raise SystemExit("non-timeout run claims a reached deadline")
if terminal in {
    "COMPLETE_LOCAL_C4_CANDIDATE_ONLY",
    "COMPLETE_LOCAL_C4_REJECTED",
}:
    if evidence["parsed_and_final_result_bytes_match"] is not True:
        raise SystemExit("complete result lacks parse/final byte identity")
    if evidence["parsed_validator_result_sha256"] != evidence[
        "validator_result_sha256"
    ]:
        raise SystemExit("complete parsed/final result digests differ")
if evidence["validator_result_present"] is not (result_present == "true"):
    raise SystemExit("result-present flag mismatch")
if evidence["caller_expected_manifest_match"] is not (
    expected_manifest_match == "true"
):
    raise SystemExit("caller-expected-manifest flag mismatch")
if evidence["manifest_files_unchanged_since_capture"] is not (
    manifest_files_unchanged == "true"
):
    raise SystemExit("manifest-file immutability flag mismatch")
authorization = evidence["authorization"]
for field in (
    "external_R11_review",
    "G0_authorized",
    "self_authorization",
    "F0_local_acceptance",
    "protection_claim",
):
    if authorization[field] is not False:
        raise SystemExit(f"runner authorized forbidden field: {field}")
PY
}

run_fixture() {
    local scenario=$1
    local expected_status=$2
    local expected_rc=$3
    local timeout_seconds=${4:-}
    local kill_after_seconds=${5:-30}
    local rc

    prepare_fixture "${scenario}"
    set +e
    env \
        CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
        CAPSCHED_RUN_STAMP=run \
        CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
        CAPSCHED_TIMEOUT_SECONDS="${timeout_seconds}" \
        CAPSCHED_TIMEOUT_KILL_AFTER_SECONDS="${kill_after_seconds}" \
        "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
        > "${FIXTURE_ROOT}/stdout" \
        2> "${FIXTURE_ROOT}/stderr"
    rc=$?
    set -e

    if [[ ${rc} -ne ${expected_rc} ]]; then
        printf '%s\n' "--- ${scenario} stderr ---" >&2
        sed -n '1,240p' "${FIXTURE_ROOT}/stderr" >&2 || true
        printf '%s\n' "--- ${scenario} run log ---" >&2
        sed -n '1,240p' "${FIXTURE_RUN}/run.log" >&2 || true
        die "${scenario}: expected rc ${expected_rc}, got ${rc}"
    fi
    assert_status "${expected_status}"
    HOSTILE_CASES=$((HOSTILE_CASES + 1))
}

run_fixture candidate COMPLETE_LOCAL_C4_CANDIDATE_ONLY 0
assert_evidence COMPLETE_LOCAL_C4_CANDIDATE_ONLY \
    COMPLETE_LOCAL_C4_CANDIDATE_ONLY true true
[[ -f "${FIXTURE_RUN}/input-manifest.after.sha256" ]] ||
    die 'candidate: after manifest missing'
[[ -f "${FIXTURE_RUN}/result.sha256" ]] ||
    die 'candidate: result hash missing'

run_fixture rejected COMPLETE_LOCAL_C4_REJECTED 1
assert_evidence COMPLETE_LOCAL_C4_REJECTED \
    COMPLETE_LOCAL_C4_REJECTED true true
[[ -f "${FIXTURE_RUN}/input-manifest.after.sha256" ]] ||
    die 'rejected: after manifest missing'
[[ -f "${FIXTURE_RUN}/result.sha256" ]] ||
    die 'rejected: result hash missing'

run_fixture invalid-authorization TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture claim-evidence-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture claim-predicate-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture claim-obligation-missing TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture forbidden-local-overclaim TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture unknown-result-field TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture unknown-nested-field TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture raw-receipt-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture type-confusion TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested static registry side values differ: child'

run_fixture test-returncode-bool TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested component test values differ'

run_fixture commutation-unreachable-action TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested commutation pair values differ'

run_fixture role-action-union-split TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'validator child action registry values differ'

run_fixture commutation-negative-state-count TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested commutation reachability differs'

run_fixture commutation-impossible-counts TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested commutation pair values differ'

run_fixture commutation-impossible-edge-lower-bound TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested commutation edge lower bound differs'

run_fixture child-impossible-cardinality TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'nested exploration cardinality differs'

run_fixture child-impossible-edge-count TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'validator local candidate status differs from evidence'

run_fixture parent-impossible-cardinality TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'validator parent cardinality relations differ'

run_fixture parent-impossible-edge-count TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'validator parent cardinality relations differ'

run_fixture child-action-registry-number-type TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true
assert_rejection_contains 'validator child action registry values differ'

run_fixture receipt-digest-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture component-argv-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture worker-provenance-mismatch TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture duplicate-result-key TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture nonfinite-json TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true true

run_fixture tool-error TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true false

run_fixture voluntary-124 TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true false

run_fixture voluntary-143 TOOL_ERROR 70
assert_evidence TOOL_ERROR TOOL_ERROR true false

run_fixture timeout INCOMPLETE_TIMEOUT 124 1
assert_evidence INCOMPLETE_TIMEOUT INCOMPLETE_TIMEOUT true false

run_fixture timeout-ignore-term INCOMPLETE_TIMEOUT 124 1 1
assert_evidence INCOMPLETE_TIMEOUT INCOMPLETE_TIMEOUT true false
timeout_parent_pid=$(< "${SIGNAL_PARENT_PID_FILE}")
timeout_child_pid=$(< "${SIGNAL_CHILD_PID_FILE}")
kill -0 "${timeout_parent_pid}" 2>/dev/null &&
    die 'timeout-ignore-term: validator process survived KILL escalation'
kill -0 "${timeout_child_pid}" 2>/dev/null &&
    die 'timeout-ignore-term: validator child survived KILL escalation'

run_fixture timeout-leader-exits-child-ignores TOOL_ERROR 70 10 1
assert_evidence TOOL_ERROR TOOL_ERROR true false
timeout_parent_pid=$(< "${SIGNAL_PARENT_PID_FILE}")
timeout_child_pid=$(< "${SIGNAL_CHILD_PID_FILE}")
kill -0 "${timeout_parent_pid}" 2>/dev/null &&
    die 'timeout-leader-exits-child-ignores: validator survived cleanup'
kill -0 "${timeout_child_pid}" 2>/dev/null &&
    die 'timeout-leader-exits-child-ignores: validator child survived cleanup'

run_fixture input-mutation EVIDENCE_FINALIZATION_ERROR 74
assert_evidence EVIDENCE_FINALIZATION_ERROR \
    COMPLETE_LOCAL_C4_CANDIDATE_ONLY false true

run_fixture manifest-rewrite EVIDENCE_FINALIZATION_ERROR 74
assert_evidence EVIDENCE_FINALIZATION_ERROR \
    TOOL_ERROR true true true false

run_fixture result-post-parse-mutation EVIDENCE_FINALIZATION_ERROR 74
assert_evidence EVIDENCE_FINALIZATION_ERROR \
    COMPLETE_LOCAL_C4_CANDIDATE_ONLY true true

prepare_fixture missing-manifest
set +e
env \
    CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
    CAPSCHED_RUN_STAMP=run \
    CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_ROOT}/absent.sha256" \
    "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
    > "${FIXTURE_ROOT}/stdout" \
    2> "${FIXTURE_ROOT}/stderr"
rc=$?
set -e
[[ ${rc} -eq 64 ]] || die "missing manifest: expected rc 64, got ${rc}"
assert_status PRECONDITION_REJECTED
assert_evidence PRECONDITION_REJECTED PRECONDITION_REJECTED \
    false false false false
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture mismatched-manifest
printf 'not the reviewed manifest\n' > "${FIXTURE_EXPECTED}"
set +e
env \
    CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
    CAPSCHED_RUN_STAMP=run \
    CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
    "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
    > "${FIXTURE_ROOT}/stdout" \
    2> "${FIXTURE_ROOT}/stderr"
rc=$?
set -e
[[ ${rc} -eq 64 ]] || die "manifest mismatch: expected rc 64, got ${rc}"
assert_status PRECONDITION_REJECTED
assert_evidence PRECONDITION_REJECTED PRECONDITION_REJECTED \
    true false false true
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture signal
env \
    CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
    CAPSCHED_RUN_STAMP=run \
    CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
    "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
    > "${FIXTURE_ROOT}/stdout" \
    2> "${FIXTURE_ROOT}/stderr" &
runner_pid=$!
for _ in {1..200}; do
    if [[ -f "${SIGNAL_PARENT_PID_FILE}" &&
          -f "${SIGNAL_CHILD_PID_FILE}" ]]; then
        break
    fi
    sleep 0.01
done
[[ -f "${SIGNAL_PARENT_PID_FILE}" ]] || die 'signal: validator did not start'
[[ -f "${SIGNAL_CHILD_PID_FILE}" ]] || die 'signal: validator child did not start'
validator_pid=$(< "${SIGNAL_PARENT_PID_FILE}")
validator_child_pid=$(< "${SIGNAL_CHILD_PID_FILE}")
kill -TERM -- "${runner_pid}"
set +e
wait "${runner_pid}"
rc=$?
set -e
[[ ${rc} -eq 143 ]] || die "signal: expected rc 143, got ${rc}"
assert_status INCOMPLETE_SIGNAL
assert_evidence INCOMPLETE_SIGNAL INCOMPLETE_SIGNAL true false
for _ in {1..200}; do
    if ! kill -0 "${validator_pid}" 2>/dev/null &&
       ! kill -0 "${validator_child_pid}" 2>/dev/null; then
        break
    fi
    sleep 0.01
done
kill -0 "${validator_pid}" 2>/dev/null &&
    die 'signal: validator process survived runner termination'
kill -0 "${validator_child_pid}" 2>/dev/null &&
    die 'signal: validator child survived runner termination'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture bash-interpreter-bypass
BASH_ENV_MARKER=${FIXTURE_ROOT}/bash-interpreter-env-executed
printf 'printf injected > %q\nset -p\n' "${BASH_ENV_MARKER}" > \
    "${FIXTURE_ROOT}/bash-env"
set +e
{
    env \
        BASH_ENV="${FIXTURE_ROOT}/bash-env" \
        CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
        CAPSCHED_RUN_STAMP=run \
        CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
        /bin/bash "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
        -p \
        > "${FIXTURE_ROOT}/stdout" \
        2> "${FIXTURE_ROOT}/stderr"
} 2>/dev/null
rc=$?
set -e
[[ ${rc} -eq 137 ]] ||
    die "bash-interpreter-bypass: expected rc 137, got ${rc}"
[[ -f "${BASH_ENV_MARKER}" ]] ||
    die 'bash-interpreter-bypass: fixture did not exercise BASH_ENV startup'
[[ ! -e "${FIXTURE_RUN}/status" ]] ||
    die 'bash-interpreter-bypass: nonprivileged launch published a status'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture bash-mapfile-bypass
BASH_ENV_MARKER=${FIXTURE_ROOT}/bash-mapfile-env-executed
{
    printf 'printf injected > %q\n' "${BASH_ENV_MARKER}"
    printf '%s\n' 'set -p' 'mapfile() { CAPSCHED_LAUNCH_ARGV=(-p); }'
} > "${FIXTURE_ROOT}/bash-env"
set +e
{
    env \
        BASH_ENV="${FIXTURE_ROOT}/bash-env" \
        CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
        CAPSCHED_RUN_STAMP=run \
        CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
        /bin/bash "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
        > "${FIXTURE_ROOT}/stdout" \
        2> "${FIXTURE_ROOT}/stderr"
} 2>/dev/null
rc=$?
set -e
[[ ${rc} -eq 137 ]] ||
    die "bash-mapfile-bypass: expected rc 137, got ${rc}"
[[ -f "${BASH_ENV_MARKER}" ]] ||
    die 'bash-mapfile-bypass: fixture did not exercise BASH_ENV startup'
[[ ! -e "${FIXTURE_RUN}/status" ]] ||
    die 'bash-mapfile-bypass: nonprivileged launch published a status'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture bash-source-bypass
BASH_ENV_MARKER=${FIXTURE_ROOT}/bash-source-env-executed
printf 'printf injected > %q\nset -p\n' "${BASH_ENV_MARKER}" > \
    "${FIXTURE_ROOT}/bash-env"
set +e
{
    env \
        BASH_ENV="${FIXTURE_ROOT}/bash-env" \
        CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
        CAPSCHED_RUN_STAMP=run \
        CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
        /bin/bash -c 'source "$2"' marker -p \
        "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
        > "${FIXTURE_ROOT}/stdout" \
        2> "${FIXTURE_ROOT}/stderr"
} 2>/dev/null
rc=$?
set -e
[[ ${rc} -eq 137 ]] ||
    die "bash-source-bypass: expected rc 137, got ${rc}"
[[ -f "${BASH_ENV_MARKER}" ]] ||
    die 'bash-source-bypass: fixture did not exercise BASH_ENV startup'
[[ ! -e "${FIXTURE_RUN}/status" ]] ||
    die 'bash-source-bypass: sourced launch published a status'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture bash-exit-override
BASH_ENV_MARKER=${FIXTURE_ROOT}/bash-exit-env-executed
{
    printf 'printf injected > %q\n' "${BASH_ENV_MARKER}"
    printf '%s\n' 'set -p' 'exit() { return 0; }'
} > "${FIXTURE_ROOT}/bash-env"
set +e
{
    env \
        BASH_ENV="${FIXTURE_ROOT}/bash-env" \
        CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
        CAPSCHED_RUN_STAMP=run \
        CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
        /bin/bash "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
        > "${FIXTURE_ROOT}/stdout" \
        2> "${FIXTURE_ROOT}/stderr"
} 2>/dev/null
rc=$?
set -e
[[ ${rc} -eq 137 ]] ||
    die "bash-exit-override: expected rc 137, got ${rc}"
[[ -f "${BASH_ENV_MARKER}" ]] ||
    die 'bash-exit-override: fixture did not exercise BASH_ENV startup'
[[ ! -e "${FIXTURE_RUN}/status" ]] ||
    die 'bash-exit-override: invalid launch published a status'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

prepare_fixture bash-env
BASH_ENV_MARKER=${FIXTURE_ROOT}/bash-env-executed
printf 'printf injected > %q\n' "${BASH_ENV_MARKER}" > "${FIXTURE_ROOT}/bash-env"
set +e
env \
    BASH_ENV="${FIXTURE_ROOT}/bash-env" \
    CAPSCHED_RESULTS_ROOT="${FIXTURE_RESULTS}" \
    CAPSCHED_RUN_STAMP=run \
    CAPSCHED_EXPECTED_MANIFEST="${FIXTURE_EXPECTED}" \
    "${FIXTURE_SOURCE}/run-f0-supervisor-v3-full.sh" \
    > "${FIXTURE_ROOT}/stdout" \
    2> "${FIXTURE_ROOT}/stderr"
rc=$?
set -e
[[ ${rc} -eq 0 ]] || die "bash-env: expected rc 0, got ${rc}"
assert_status COMPLETE_LOCAL_C4_CANDIDATE_ONLY
assert_evidence COMPLETE_LOCAL_C4_CANDIDATE_ONLY \
    COMPLETE_LOCAL_C4_CANDIDATE_ONLY true true
[[ ! -e "${BASH_ENV_MARKER}" ]] || die 'bash-env: startup hook executed'
HOSTILE_CASES=$((HOSTILE_CASES + 1))

printf 'LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=%s\n' \
    "${HOSTILE_CASES}"
