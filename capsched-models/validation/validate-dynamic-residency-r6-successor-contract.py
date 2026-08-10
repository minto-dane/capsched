#!/usr/bin/env python3
"""Strict internal validator for the R6 successor semantic contract.

This is an architecture consistency gate. It is not an external verifier,
formal proof, model check, or protection result.
"""

from __future__ import annotations

import collections
import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ANALYSIS = ROOT / "analysis"

BASE = ANALYSIS / "dynamic-admission-recurring-residency-architecture-contract-v1.json"
OVERLAY = ANALYSIS / "dynamic-residency-r6-successor-semantic-overlay-v1.json"
CONTRACT = ANALYSIS / "dynamic-admission-recurring-residency-architecture-contract-v2.json"
HUMAN = ANALYSIS / "0200-dynamic-residency-r6-successor-semantic-architecture.md"
REJECTION = ANALYSIS / "dynamic-residency-sixth-fresh-hostile-review-rejection-v1.json"
ASSURANCE = ANALYSIS / "architecture-freeze-external-assurance-protocol-v3.json"
MATERIALIZER = HERE / "materialize-dynamic-residency-contract-v2.py"

EXPECTED_BASE_SHA256 = "015838a03f7967522d4998bf05b93fa70153bc14c3800a0fd300804574e5901f"
EXPECTED_R6_FINDINGS = [
    "R6-AUTH-01",
    "R6-AUTH-02",
    "R6-ACT-01",
    "R6-ACT-02",
    "R6-DELEG-01",
    "R6-ID-01",
    "R6-BOUNDARY-01",
    "R6-XFER-01",
    "R6-XFER-02",
    "R6-FAIL-01",
    "R6-LIVE-01",
    "R6-LIVE-02",
    "R6-CALENDAR-01",
    "R6-CONN-01",
    "R6-SVC-01",
    "R6-REFINE-01",
    "R6-FORMAL-01",
    "R6-ASSURE-01",
    "R6-ASSURE-02",
    "R6-ASSURE-03",
    "R6-ASSURE-04",
]


class ValidationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def require_true(value: Any, message: str) -> None:
    require(value is True, message)


def require_false(value: Any, message: str) -> None:
    require(value is False, message)


def require_nonempty_string(value: Any, message: str) -> str:
    require(isinstance(value, str) and bool(value), message)
    return value


def require_unique_strings(value: Any, message: str) -> list[str]:
    require(isinstance(value, list), f"{message}: expected array")
    require(all(isinstance(item, str) and item for item in value), f"{message}: expected nonempty strings")
    require(len(value) == len(set(value)), f"{message}: duplicate value")
    return value


def read_bytes(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise ValidationError(f"cannot read {path}: {exc}") from exc


def load_json(path: Path) -> tuple[bytes, dict[str, Any]]:
    data = read_bytes(path)
    try:
        value = json.loads(data)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"invalid JSON {path}: {exc}") from exc
    require(isinstance(value, dict), f"{path}: root must be object")
    return data, value


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_materializer() -> Any:
    spec = importlib.util.spec_from_file_location("capsched_r6_materializer", MATERIALIZER)
    require(spec is not None and spec.loader is not None, "cannot load materializer spec")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def walk_strings(value: Any, path: str = "$") -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    if isinstance(value, dict):
        for key, child in value.items():
            found.append((f"{path}.<key>", key))
            found.extend(walk_strings(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(walk_strings(child, f"{path}[{index}]"))
    elif isinstance(value, str):
        found.append((path, value))
    return found


def assert_dag(nodes: Any, edges: Any, label: str) -> dict[str, int]:
    node_list = require_unique_strings(nodes, f"{label}.nodes")
    require(isinstance(edges, list), f"{label}.edges must be array")
    parsed: list[tuple[str, str]] = []
    for index, edge in enumerate(edges):
        require(isinstance(edge, list) and len(edge) == 2, f"{label}.edges[{index}] malformed")
        source, target = edge
        require(source in node_list and target in node_list, f"{label}.edges[{index}] unknown node")
        require(source != target, f"{label}.edges[{index}] self edge")
        parsed.append((source, target))
    require(len(parsed) == len(set(parsed)), f"{label}: duplicate edge")

    outgoing: dict[str, list[str]] = {node: [] for node in node_list}
    indegree = {node: 0 for node in node_list}
    for source, target in parsed:
        outgoing[source].append(target)
        indegree[target] += 1
    queue = collections.deque(node for node in node_list if indegree[node] == 0)
    order: list[str] = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for target in outgoing[node]:
            indegree[target] -= 1
            if indegree[target] == 0:
                queue.append(target)
    require(len(order) == len(node_list), f"{label}: cycle detected")
    return {node: index for index, node in enumerate(order)}


def extract_parity(markdown: str) -> dict[str, Any]:
    begin = "<!-- R6-MACHINE-PARITY:BEGIN -->"
    end = "<!-- R6-MACHINE-PARITY:END -->"
    require(markdown.count(begin) == 1 and markdown.count(end) == 1, "human parity markers missing or duplicated")
    body = markdown.split(begin, 1)[1].split(end, 1)[0]
    match = re.fullmatch(r"\s*```json\s*\n(?P<json>.*)\n```\s*", body, re.DOTALL)
    require(match is not None, "human parity block is not one JSON fence")
    try:
        value = json.loads(match.group("json"))
    except json.JSONDecodeError as exc:
        raise ValidationError(f"invalid human parity JSON: {exc}") from exc
    require(isinstance(value, dict), "human parity JSON must be object")
    return value


def maximum_cyclic_gap(classes: list[str], target: str) -> int:
    positions = [index for index, value in enumerate(classes) if value == target]
    require(positions, f"work frame class missing: {target}")
    gaps = []
    for index, position in enumerate(positions):
        next_position = positions[(index + 1) % len(positions)]
        gap = (next_position - position) % len(classes)
        gaps.append(gap if gap else len(classes))
    return max(gaps)


def validate_materialization() -> tuple[dict[str, Any], dict[str, Any], str]:
    base_bytes, _ = load_json(BASE)
    overlay_bytes, overlay = load_json(OVERLAY)
    contract_bytes, contract = load_json(CONTRACT)
    require(sha256(base_bytes) == EXPECTED_BASE_SHA256, "base contract digest changed")
    require(overlay["base"]["raw_sha256"] == EXPECTED_BASE_SHA256, "overlay base pin mismatch")
    materializer = load_materializer()
    try:
        expected = materializer.materialize(BASE, OVERLAY)
    except Exception as exc:
        raise ValidationError(f"materializer rejected candidate: {exc}") from exc
    require(expected == contract_bytes, "materialized v2 bytes differ from checked-in contract")
    provenance = contract.get("successor_materialization")
    require(isinstance(provenance, dict), "materialization provenance missing")
    require(provenance.get("overlay_raw_sha256") == sha256(overlay_bytes), "overlay provenance digest mismatch")
    require_false(provenance.get("materialization_is_architecture_freeze_evidence"), "materialization overclaims freeze")
    return overlay, contract, sha256(contract_bytes)


def validate_rejection_and_nonclaims(contract: dict[str, Any]) -> None:
    _, rejection = load_json(REJECTION)
    require(rejection.get("verdict") == "FREEZE_NO", "source rejection verdict changed")
    require(rejection.get("finding_count") == len(EXPECTED_R6_FINDINGS), "R6 finding count mismatch")
    require(rejection.get("finding_ids") == EXPECTED_R6_FINDINGS, "R6 finding order or identity mismatch")
    disposition = contract.get("r6_fresh_review_disposition")
    require(isinstance(disposition, dict), "R6 disposition missing")
    require(disposition.get("finding_count") == len(EXPECTED_R6_FINDINGS), "contract R6 count mismatch")
    require_true(disposition.get("candidate_responses_encoded"), "R6 responses not encoded")
    require_false(disposition.get("responses_validated"), "unreviewed R6 responses marked validated")
    require_false(disposition.get("findings_closed"), "R6 findings marked closed")
    require_false(disposition.get("fresh_successor_review_complete"), "fresh successor review overclaimed")
    claims = contract.get("claims")
    require(isinstance(claims, dict), "contract claims missing")
    for key in (
        "r6_findings_closed",
        "adversarial_semantic_freeze_complete",
        "tla_authorized",
        "tla_written",
        "model_checked",
        "residency_dynamic_model_supported",
        "protection_evidenced",
        "performance_evidenced",
        "cost_efficiency_evidenced",
        "deployment_ready",
    ):
        require_false(claims.get(key), f"contract claim must remain false: {key}")


def validate_no_legacy_semantics(contract: dict[str, Any]) -> None:
    forbidden = (
        "DelegationScope",
        "RequiredQuiescenceReceiptSet",
        "CalendarTransferV1",
        "Undecided_to",
        "one_use_initial_RunToken",
    )
    hits = [(path, text) for path, text in walk_strings(contract) if any(term in text for term in forbidden)]
    require(not hits, f"legacy semantic terms remain: {hits[:5]}")
    object_types = require_unique_strings(contract.get("object_types"), "object_types")
    for required in (
        "OpportunityReservation",
        "ActivationAttemptID",
        "ExecutionCellLeaseCore",
        "ExecutionContextCore",
        "PreEntryPermit",
        "EntryCommitRecord",
        "RequiredActivationReceiptSet",
        "OpportunityTerminalCell",
    ):
        require(required in object_types, f"required R6 object type missing: {required}")


def validate_identity_and_authority_dag(contract: dict[str, Any]) -> None:
    identity = contract.get("canonical_identity_encoding")
    require(isinstance(identity, dict), "canonical identity section missing")
    require(identity.get("CID_text_encoding") == "lcid1_colon_base64url_without_padding_of_CanonicalKeyBytesV1", "CID encoding mismatch")
    require(identity.get("payload_digest_text_grammar") == "sha256_colon_exactly_64_lowercase_hex_digits", "digest grammar mismatch")
    require(identity.get("authority_equality") == "decoded_structural_CID_key_equality_plus_recomputed_payload_digest_equality", "authority equality collapsed")
    require_false(identity.get("hash_or_payload_digest_is_claimed_mathematically_injective"), "hash claimed injective")
    require(identity.get("ActivationAttemptID_fields") == ["CurrentOpportunityID", "AttemptOrdinal"], "attempt ID depends on future object")
    require("boot_fixed_ActivationShardMapGeneration" in identity.get("CurrentOpportunityID_fields", []), "stable shard map omitted")

    dag = contract.get("authority_construction_dag_v2")
    require(isinstance(dag, dict), "authority DAG missing")
    order = assert_dag(dag.get("nodes"), dag.get("edges"), "authority DAG")
    edge_set = {tuple(edge) for edge in dag["edges"]}
    for earlier, later in (
        ("ExecutionCellLeaseCore", "NormalizedAuthorityHorizonVector"),
        ("NormalizedAuthorityHorizonVector", "ExecutionCellLease"),
        ("ExecutionContextCore", "RequiredActivationReceiptSet"),
        ("RequiredActivationReceiptSet", "ExecutionContextKey"),
        ("PreEntryPermit", "EntryCommitRecord"),
        ("EntryCommitRecord", "ActivationCommitReceipt"),
        ("ActivationCommitReceipt", "DeliverySettlementCell"),
        ("DeliverySettlementCell", "RunToken"),
    ):
        require((earlier, later) in edge_set, f"required authority edge missing: {earlier} -> {later}")
        require(order[earlier] < order[later], f"authority construction order invalid: {earlier} -> {later}")
    require_true(dag.get("graph_must_be_acyclic"), "authority DAG acyclicity not required")
    require_false(dag.get("duplicate_mutable_owner_allowed"), "duplicate mutable owner allowed")
    owners = dag.get("mutable_state_owners")
    require(
        isinstance(owners, dict)
        and set(owners)
        == {"ActivationDecisionCell", "ExecutionCellUseCell", "DeliverySettlementCell", "OpportunityTerminalCell"},
        "mutable state owner inventory mismatch",
    )
    require(
        owners["ActivationDecisionCell"] == owners["ExecutionCellUseCell"] == "stable_OpportunityActivationShard",
        "opportunity decision/use ownership is not stable",
    )


def validate_activation(contract: dict[str, Any]) -> None:
    root = contract["root_execution_capacity"]
    lease_core_fields = require_unique_strings(root.get("ExecutionCellLeaseCore_fields"), "ExecutionCellLeaseCore_fields")
    require(
        {
            "LeaseCoreID_and_LeaseCoreGeneration",
            "CurrentOpportunityID_and_ActivationAttemptID",
            "HardwareCapacityRootCertificate_and_RootExecutionAllocationCertificate",
            "PhysicalOccurrenceID_exact_physical_context_and_CpuIncarnation",
            "half_open_cell_start_and_end",
        }
        <= set(lease_core_fields),
        "lease core schema missing required fields",
    )
    require_true(root.get("final_lease_and_horizon_vector_can_authenticate_each_other_recursively") is False, "lease/vector cycle allowed")
    require_false(root.get("valid_entry_can_nondeterministically_expire_same_due_cell"), "valid entry may expire")
    require("ExecutionCellLeaseCore" in contract["normalized_authority_horizons"]["required_source_classes"], "horizon lacks lease core")
    require_true(contract["normalized_authority_horizons"].get("final_ExecutionCellLease_is_not_a_vector_source"), "final lease is vector source")

    activation = contract["activation_composition_interface"]
    require(activation.get("ActivationDecisionCell_key") == "exact_complete_CurrentOpportunityID_only", "decision cell key mismatch")
    require("single_stable_ActivationShard_writer" in activation["ActivationDecisionCell_fields"][0], "stable decision writer missing")
    require_false(activation.get("retry_may_change_ActivationShard_writer_because_CPU_or_cell_changes"), "retry can change writer")
    require_true(activation.get("MaxActivationAttempts_is_positive_bounded_and_admission_charged"), "attempt bound not charged")
    require_true(activation.get("valid_due_entry_has_priority_over_expiry"), "valid due entry lacks priority")
    require(activation.get("attempt_exhaustion_without_authenticated_external_cause_result") == "InternalGuaranteeViolation", "attempt exhaustion misclassified")
    require(activation.get("PreEntryPermit_authorizes") == "protected_initial_entry_gate_only", "permit authority too broad")
    require_false(activation.get("PreEntryPermit_authorizes_ordinary_execution_interrupt_return_resume_or_migration"), "permit authorizes execution/resume")
    require_false(activation.get("ActivationCommitReceipt_binds_future_RunToken_digest"), "receipt/token cycle")
    require_false(activation.get("DeliverySettlementCell_binds_future_RunToken_digest"), "settlement/token cycle")
    require_true(activation.get("RunToken_binds_existing_ActivationCommitReceipt"), "RunToken omits receipt")
    require_true(activation.get("RunToken_binds_existing_DeliverySettlementCell"), "RunToken omits settlement cell")
    effects = activation.get("entry_atomic_effects")
    require(isinstance(effects, list), "entry effects missing")
    joined = " ".join(effects)
    require("create_one_ActivationCommitReceipt" in joined and "create_one_active_DeliverySettlementCell" in joined and "create_one_RunToken" in joined, "entry bundle incomplete")
    require(joined.index("create_one_ActivationCommitReceipt") < joined.index("create_one_active_DeliverySettlementCell") < joined.index("create_one_RunToken"), "entry bundle internal order invalid")

    receipt = contract["activation_receipt_contract"]
    require("no_receipt_or_final_ExecutionContextKey" in receipt["ExecutionContextCore_fields"][-1], "context core depends on final key")
    require("ExecutionContextCore_physical_context_and_CpuIncarnation" in receipt["common_envelope_fields"], "receipts do not bind context core")
    require(not any(field.startswith("ExecutionContextKey_") for field in receipt["common_envelope_fields"]), "receipts bind final context key")
    require_true(receipt.get("MemoryView_Code_Entry_MutableState_Device_and_Stop_classes_are_mandatory"), "core receipt classes optional")
    require_false(receipt.get("core_security_class_may_use_NotApplicableReceipt"), "core class may use NotApplicable")
    require("tagged_PRESENT" in receipt["required_classes"]["DeviceIsolationReceipt"] and "ABSENT" in receipt["required_classes"]["DeviceIsolationReceipt"], "device absence not protected union")

    lifecycle = contract["opportunity_lifecycle"]
    require_true(lifecycle.get("decision_refinement_is_total"), "lifecycle refinement not total")
    require_true(lifecycle.get("PreparedInert_has_distinct_high_level_state"), "PreparedInert hidden")
    require_true(lifecycle.get("activated_and_served_are_orthogonal_monotonic_bits"), "served bit not monotonic")
    require_false(lifecycle.get("invalid_low_product_can_map_to_service_or_external_withdrawal"), "invalid lifecycle product receives credit")


def validate_delegation_failure_transfer(contract: dict[str, Any]) -> None:
    delegation = contract["delegation_authority_v2"]
    require_false(delegation.get("unbound_bearer_scope_allowed_on_hostile_Linux_transport"), "unbound delegation bearer allowed")
    require_true(delegation.get("holder_binding_survives_transport_copy"), "holder binding absent")
    control = contract["control_operation"]
    required_grant_fields = " ".join(control["DelegationGrant_fields"])
    for term in ("grantee", "audience", "attenuation", "revocation", "challenge"):
        require(term in required_grant_fields, f"DelegationGrant omits {term}")

    failure = contract["failure_publication_protocol_v2"]
    require_false(failure.get("executable_partial_reverse_link_publication_allowed"), "partial indexed authority executable")
    require_true(failure.get("disjoint_open_scope_may_continue"), "failure closure globally stalls disjoint scope")
    require_true(failure.get("overlapping_failures_serialize_at_first_common_scope_gate"), "overlapping failure ordering absent")
    require("complete_pass_adds_no_use_scope_or_topology_generation" in failure["closure_order"][-1], "failure fixed point lacks closed pass")

    connectivity = contract["connectivity_freshness_contract_v2"]
    require_true(connectivity.get("CONNECTED_ONLY_requires_current_unconsumed_certificate"), "CONNECTED_ONLY certificate not one-use/current")
    require_true(connectivity.get("certificate_expiry_is_normalized_authority_horizon_entry"), "connectivity expiry omitted from horizon")
    require_false(connectivity.get("replay_boolean_network_silence_or_transport_success_is_authority"), "connectivity observation grants authority")

    transfer = contract["calendar_boundary_transfer_v2"]
    require(transfer.get("variants") == ["SourceQuiesced", "QuorumSupersededStrongContinuity", "QuorumSupersededSafeGap", "ContinuityLost"], "transfer variants mismatch")
    require("no_inferred_or_transitive_chain" in transfer.get("cross_time_mapping", ""), "transitive clock conversion allowed")
    require_false(transfer.get("strong_continuity_from_settlement_prefix_alone"), "prefix alone grants strong continuity")
    require_true(transfer.get("strong_continuity_requires_no_unresolved_predecessor_ordinal_at_or_above_qCut"), "strong continuity leaves uncertain ordinal")
    require_true(transfer.get("ContinuityLost_requires_new_ServiceStreamIncarnation"), "continuity loss reuses incarnation")


def validate_frame_and_liveness(contract: dict[str, Any]) -> None:
    frame = contract["protected_work_frame_v2"]
    slots = frame.get("ordered_slots")
    require(isinstance(slots, list) and len(slots) == frame.get("frame_length") == 9, "protected work frame length mismatch")
    require([slot.get("slot_id") for slot in slots] == [f"PW{i}" for i in range(9)], "protected work slot IDs mismatch")
    classes = [require_nonempty_string(slot.get("class"), "work slot class missing") for slot in slots]
    counts = dict(collections.Counter(classes))
    require(counts == frame.get("class_counts"), "protected frame class counts mismatch")
    for target, expected in frame.get("maximum_cyclic_slot_gap", {}).items():
        require(maximum_cyclic_gap(classes, target) == expected, f"protected frame gap mismatch: {target}")
    require(maximum_cyclic_gap(classes, "GuaranteedResidency") == 5, "guaranteed residency frame not balanced to gap 5")
    require_true(frame.get("human_machine_structural_parity_required"), "frame parity not required")

    calendar = contract["guaranteed_calendar_v2"]
    require_true(calendar.get("occurrence_to_release_cell_is_injective"), "release calendar not injective")
    require_true(calendar.get("attempt_to_execution_cell_is_injective"), "attempt calendar not injective")
    require_false(calendar.get("same_lane_epoch_turn_and_cell_ordinal_multiowner_allowed"), "same-lane cell collision allowed")

    relies = require_unique_strings(contract.get("external_relies"), "external_relies")
    for rely in relies:
        require("ContractOperationalState" not in rely and "internal_Operational" not in rely, "external rely assumes internal operational state")
    liveness = contract["liveness_contract_v2"]
    require_false(liveness.get("ExogenousStableWindow_may_reference_internal_Operational_or_successful_failure_processing"), "stable window is vacuous")
    require_false(liveness.get("unexplained_internal_failstop_is_AuthorizedExternalWithdrawal"), "internal failstop treated as external")
    require_false(liveness.get("service_or_declared_failstop_is_valid_liveness_guarantee"), "failstop satisfies service")


def validate_proof_dag(contract: dict[str, Any]) -> None:
    formal = contract["formal_decomposition"]
    order = require_unique_strings(formal.get("proof_dependency_dag_order"), "proof DAG order")
    position = {node: index for index, node in enumerate(order)}
    ledger = formal.get("component_assume_guarantee_ledger")
    require(isinstance(ledger, dict), "component ledger missing")
    for node, row in ledger.items():
        require(node in position, f"component ledger node absent from proof order: {node}")
        require(isinstance(row, dict), f"component ledger row malformed: {node}")
        for predecessor in row.get("internal_predecessors", []):
            require(predecessor in position, f"unknown proof predecessor: {node} <- {predecessor}")
            require(position[predecessor] < position[node], f"proof dependency is cyclic or forward: {node} <- {predecessor}")
    admit_predecessors = set(ledger["DYN_ADMIT"]["internal_predecessors"])
    require({"ENV_CRYPTO_CANONICAL_SEAL", "ENV_HARDWARE_TIME_ROOT", "ENV_CLUSTER_ISSUER_QUORUM_TIME", "RESOURCE_HIERARCHY_SET_ALGEBRA"} <= admit_predecessors, "DYN_ADMIT predecessor set incomplete")
    operational = ledger["OPERATIONAL_PRESERVATION_THEOREM"]
    require(position["DYN_MULTILANE_COMPOSE"] < position["OPERATIONAL_PRESERVATION_THEOREM"] < position["PER_OPPORTUNITY_RANK_THEOREM"], "operational theorem order invalid")
    require(ledger["PER_OPPORTUNITY_RANK_THEOREM"]["internal_predecessors"] == ["OPERATIONAL_PRESERVATION_THEOREM"], "rank theorem bypasses operational preservation")
    require("service_or_declared_failstop" not in ledger["PER_OPPORTUNITY_RANK_THEOREM"]["guarantee"], "rank theorem still allows generic failstop")
    require(formal.get("temporal_not_stored_relies", [None])[0] == "ExogenousStableWindow", "legacy StableWindow remains")
    required_node_fields = set(formal.get("node_schema_required_fields", []))
    require("action_IDs_and_exact_read_write_sets" in required_node_fields, "proof node read/write schema missing")
    require("internal_predecessor_provider_component_formula_and_action_set_refs" in required_node_fields, "proof provider mapping missing")


def validate_assurance(assurance: dict[str, Any] | None = None) -> None:
    if assurance is None:
        _, assurance = load_json(ASSURANCE)
    objects = require_unique_strings(assurance["trust_chain"]["objects"], "assurance trust objects")
    nested = require_unique_strings(assurance["trust_chain"]["nested_value_types"], "assurance nested types")
    schemas = assurance.get("exact_object_schemas")
    nested_schemas = assurance.get("exact_nested_schemas")
    require(isinstance(schemas, dict) and set(schemas) == set(objects), "assurance object schema coverage mismatch")
    require(isinstance(nested_schemas, dict) and set(nested_schemas) == set(nested), "assurance nested schema coverage mismatch")
    for name, schema in {**schemas, **nested_schemas}.items():
        require(isinstance(schema, dict), f"assurance schema malformed: {name}")
        require_unique_strings(schema.get("exact_keys"), f"assurance schema {name}.exact_keys")
    require(len(objects) == 37 and len(nested) == 9, "assurance schema inventory changed without validator update")

    vote_keys = set(schemas["AdmissionVote"]["exact_keys"])
    require({"prior_state_digest", "prior_tree_size", "prior_tree_root", "prior_last_event_digest", "new_state_digest", "new_tree_size", "new_tree_root", "consistency_proof_digest", "persistence_receipt_digest"} <= vote_keys, "admission vote does not bind exact persisted extension")
    receipt_keys = set(schemas["SemanticValidationReceipt"]["exact_keys"])
    require({"exit_kind", "exit_code", "signal_number", "timed_out", "resource_limit_hit", "stdout_complete", "stderr_complete", "result_complete", "result_status", "check_catalog_digest", "executed_check_set_digest", "check_results"} <= receipt_keys, "semantic receipt success fields incomplete")
    review_keys = set(schemas["ReviewPayload"]["exact_keys"])
    require({"coverage_answers", "dispositions", "limitations", "required_finding_catalog_digest", "reviewer_finding_catalog_digest", "semantic_receipt_set_digest", "verdict"} <= review_keys, "ReviewPayload incomplete")
    require_false(assurance["semantic_validation_success"].get("matching_failure_timeout_signal_truncation_or_partial_inventory_is_success"), "failed receipts can pass")
    require_false(assurance["review_acceptance"].get("digest_only_accept_payload_allowed"), "vacuous review accept allowed")
    require_true(assurance["witness_persistence"].get("durably_persist_successor_and_external_anchor_before_sign"), "witness may sign before persistence")
    require_false(assurance["witness_persistence"].get("key_rotation_may_resume_old_campaign"), "witness rollback can resume by key rotation")
    for key in ("real_verifier_implemented", "measured_launcher_implemented", "durable_witness_service_implemented", "external_campaign_started", "architecture_frozen", "tla_authorized", "model_supported", "protection_evidenced"):
        require_false(assurance["claims"].get(key), f"assurance overclaim: {key}")


def validate_human_parity(contract: dict[str, Any], markdown: str | None = None) -> None:
    if markdown is None:
        markdown = read_bytes(HUMAN).decode("utf-8")
    parity = extract_parity(markdown)
    require(parity.get("contract_id") == contract.get("id"), "human contract ID mismatch")
    require(parity.get("authority_dag_nodes") == contract["authority_construction_dag_v2"]["nodes"], "human authority DAG mismatch")
    require(parity.get("activation_decision_key") == contract["activation_composition_interface"]["ActivationDecisionCell_key"], "human decision key mismatch")
    require(parity.get("activation_attempt_id_fields") == contract["canonical_identity_encoding"]["ActivationAttemptID_fields"], "human attempt identity mismatch")
    require(parity.get("receipt_subject") in contract["activation_receipt_contract"]["common_envelope_fields"], "human receipt subject mismatch")
    require(parity.get("execution_context_key_derivation") == contract["activation_receipt_contract"]["ExecutionContextKey_derivation"], "human context-key derivation mismatch")
    slots = [[slot["slot_id"], slot["class"]] for slot in contract["protected_work_frame_v2"]["ordered_slots"]]
    require(parity.get("protected_work_slots") == slots, "human work frame mismatch")
    require(parity.get("calendar_boundary_variants") == contract["calendar_boundary_transfer_v2"]["variants"], "human transfer variants mismatch")
    require(parity.get("proof_dependency_order") == contract["formal_decomposition"]["proof_dependency_dag_order"], "human proof order mismatch")
    require_false(parity.get("architecture_frozen"), "human parity overclaims freeze")
    require_false(parity.get("tla_authorized"), "human parity overclaims TLA authorization")
    require_false(parity.get("model_supported"), "human parity overclaims model support")
    require_false(parity.get("protection_evidenced"), "human parity overclaims protection")


def validate_finding_responses(contract: dict[str, Any]) -> None:
    gates: dict[str, Callable[[], bool]] = {
        "R6-AUTH-01": lambda: contract["trusted_lease_clock"]["initial_entry_uses_RunToken"] is False and contract["activation_composition_interface"]["RunToken_binds_existing_ActivationCommitReceipt"] is True,
        "R6-AUTH-02": lambda: contract["normalized_authority_horizons"]["final_ExecutionCellLease_is_not_a_vector_source"] is True,
        "R6-ACT-01": lambda: contract["activation_composition_interface"]["ActivationDecisionCell_key"] == "exact_complete_CurrentOpportunityID_only",
        "R6-ACT-02": lambda: contract["opportunity_lifecycle"]["decision_refinement_is_total"] is True,
        "R6-DELEG-01": lambda: contract["delegation_authority_v2"]["unbound_bearer_scope_allowed_on_hostile_Linux_transport"] is False,
        "R6-ID-01": lambda: contract["canonical_identity_encoding"]["hash_or_payload_digest_is_claimed_mathematically_injective"] is False,
        "R6-BOUNDARY-01": lambda: contract["activation_receipt_contract"]["claim_is_interface_conditional_until_physical_refinement"] is True,
        "R6-XFER-01": lambda: "one_direct_authenticated" in contract["calendar_boundary_transfer_v2"]["cross_time_mapping"],
        "R6-XFER-02": lambda: "QuorumSupersededStrongContinuity" in contract["calendar_boundary_transfer_v2"]["variants"],
        "R6-FAIL-01": lambda: contract["failure_publication_protocol_v2"]["executable_partial_reverse_link_publication_allowed"] is False,
        "R6-LIVE-01": lambda: contract["liveness_contract_v2"]["service_or_declared_failstop_is_valid_liveness_guarantee"] is False,
        "R6-LIVE-02": lambda: contract["activation_composition_interface"]["valid_due_entry_has_priority_over_expiry"] is True,
        "R6-CALENDAR-01": lambda: contract["guaranteed_calendar_v2"]["same_lane_epoch_turn_and_cell_ordinal_multiowner_allowed"] is False,
        "R6-CONN-01": lambda: contract["connectivity_freshness_contract_v2"]["CONNECTED_ONLY_requires_current_unconsumed_certificate"] is True,
        "R6-SVC-01": lambda: contract["protected_work_frame_v2"]["frame_length"] == 9,
        "R6-REFINE-01": lambda: contract["opportunity_lifecycle"]["invalid_low_product_can_map_to_service_or_external_withdrawal"] is False,
        "R6-FORMAL-01": lambda: "OPERATIONAL_PRESERVATION_THEOREM" in contract["formal_decomposition"]["proof_dependency_dag_order"],
        "R6-ASSURE-01": lambda: True,
        "R6-ASSURE-02": lambda: True,
        "R6-ASSURE-03": lambda: True,
        "R6-ASSURE-04": lambda: True,
    }
    require(list(gates) == EXPECTED_R6_FINDINGS, "finding gate inventory mismatch")
    for finding_id, gate in gates.items():
        require(gate(), f"candidate response gate failed: {finding_id}")


def main() -> int:
    try:
        _, contract, contract_digest = validate_materialization()
        validate_rejection_and_nonclaims(contract)
        validate_no_legacy_semantics(contract)
        validate_identity_and_authority_dag(contract)
        validate_activation(contract)
        validate_delegation_failure_transfer(contract)
        validate_frame_and_liveness(contract)
        validate_proof_dag(contract)
        validate_assurance()
        validate_human_parity(contract)
        validate_finding_responses(contract)
    except (ValidationError, KeyError, IndexError, TypeError, ValueError) as exc:
        print(f"R6 successor architecture candidate: FAIL: {exc}", file=sys.stderr)
        return 1
    print("R6 successor architecture candidate: PASS (internal consistency only)")
    print(f"materialized_contract_sha256={contract_digest}")
    print("r6_findings_closed=false; architecture_frozen=false; tla_authorized=false")
    print("model_supported=false; protection_evidenced=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
