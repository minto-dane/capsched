#!/usr/bin/env python3
"""Targeted hostile mutations for the R6 successor semantic gates."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
ANALYSIS = HERE.parent / "analysis"
VALIDATOR_PATH = HERE / "validate-dynamic-residency-r6-successor-contract.py"
MATERIALIZER_PATH = HERE / "materialize-dynamic-residency-contract-v2.py"
CONTRACT_PATH = ANALYSIS / "dynamic-admission-recurring-residency-architecture-contract-v2.json"
ASSURANCE_PATH = ANALYSIS / "architecture-freeze-external-assurance-protocol-v3.json"
HUMAN_PATH = ANALYSIS / "0200-dynamic-residency-r6-successor-semantic-architecture.md"
BASE_PATH = ANALYSIS / "dynamic-admission-recurring-residency-architecture-contract-v1.json"
OVERLAY_PATH = ANALYSIS / "dynamic-residency-r6-successor-semantic-overlay-v1.json"


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_module("capsched_r6_validator", VALIDATOR_PATH)
materializer = load_module("capsched_r6_materializer_test", MATERIALIZER_PATH)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"not an object: {path}")
    return value


BASE_CONTRACT = load_json(CONTRACT_PATH)
BASE_ASSURANCE = load_json(ASSURANCE_PATH)
BASE_OVERLAY = load_json(OVERLAY_PATH)
BASE_HUMAN = HUMAN_PATH.read_text(encoding="utf-8")


class TestFailure(Exception):
    pass


def expect_validation_reject(label: str, action: Callable[[], None], expected: str) -> None:
    try:
        action()
    except validator.ValidationError as exc:
        if expected not in str(exc):
            raise TestFailure(f"{label}: wrong gate: {exc!s}; expected {expected!r}") from exc
    except Exception as exc:
        raise TestFailure(f"{label}: unhandled {type(exc).__name__}: {exc}") from exc
    else:
        raise TestFailure(f"{label}: mutation accepted")


def contract_case(
    label: str,
    check: Callable[[dict[str, Any]], None],
    mutate: Callable[[dict[str, Any]], None],
    expected: str,
) -> None:
    candidate = copy.deepcopy(BASE_CONTRACT)
    mutate(candidate)
    expect_validation_reject(label, lambda: check(candidate), expected)


def assurance_case(label: str, mutate: Callable[[dict[str, Any]], None], expected: str) -> None:
    candidate = copy.deepcopy(BASE_ASSURANCE)
    mutate(candidate)
    expect_validation_reject(label, lambda: validator.validate_assurance(candidate), expected)


def replace_parity(markdown: str, mutate: Callable[[dict[str, Any]], None]) -> str:
    begin = "<!-- R6-MACHINE-PARITY:BEGIN -->"
    end = "<!-- R6-MACHINE-PARITY:END -->"
    prefix, rest = markdown.split(begin, 1)
    body, suffix = rest.split(end, 1)
    raw = body.split("```json", 1)[1].rsplit("```", 1)[0]
    value = json.loads(raw)
    mutate(value)
    rendered = "\n```json\n" + json.dumps(value, indent=2, ensure_ascii=True) + "\n```\n"
    return prefix + begin + rendered + end + suffix


def parity_case(label: str, mutate: Callable[[dict[str, Any]], None], expected: str) -> None:
    markdown = replace_parity(BASE_HUMAN, mutate)
    expect_validation_reject(label, lambda: validator.validate_human_parity(BASE_CONTRACT, markdown), expected)


def materializer_case(
    label: str,
    mutate_overlay: Callable[[dict[str, Any]], None] | None,
    expected: str,
    mutate_base: bool = False,
) -> None:
    with tempfile.TemporaryDirectory(prefix="capsched-r6-materializer-") as temp:
        directory = Path(temp)
        base = directory / BASE_PATH.name
        overlay = directory / OVERLAY_PATH.name
        base_bytes = BASE_PATH.read_bytes()
        base.write_bytes(base_bytes + (b" " if mutate_base else b""))
        overlay_value = copy.deepcopy(BASE_OVERLAY)
        if mutate_overlay is not None:
            mutate_overlay(overlay_value)
        overlay.write_text(json.dumps(overlay_value, indent=2) + "\n", encoding="utf-8")
        try:
            materializer.materialize(base, overlay)
        except materializer.MaterializationError as exc:
            if expected not in str(exc):
                raise TestFailure(f"{label}: wrong materializer gate: {exc!s}; expected {expected!r}") from exc
        except Exception as exc:
            raise TestFailure(f"{label}: unhandled {type(exc).__name__}: {exc}") from exc
        else:
            raise TestFailure(f"{label}: mutation accepted")


def run_contract_mutations() -> int:
    count = 0

    cases: list[tuple[str, Callable[[dict[str, Any]], None], Callable[[dict[str, Any]], None], str]] = [
        ("identity-hash-injective", validator.validate_identity_and_authority_dag, lambda c: c["canonical_identity_encoding"].__setitem__("hash_or_payload_digest_is_claimed_mathematically_injective", True), "hash claimed injective"),
        ("identity-attempt-future-lease", validator.validate_identity_and_authority_dag, lambda c: c["canonical_identity_encoding"]["ActivationAttemptID_fields"].append("ExecutionCellLeaseID"), "attempt ID depends on future object"),
        ("identity-authority-digest-only", validator.validate_identity_and_authority_dag, lambda c: c["canonical_identity_encoding"].__setitem__("authority_equality", "payload_digest_only"), "authority equality collapsed"),
        ("authority-dag-cycle", validator.validate_identity_and_authority_dag, lambda c: c["authority_construction_dag_v2"]["edges"].append(["RunToken", "ActivationCommitReceipt"]), "cycle detected"),
        ("authority-dag-duplicate-node", validator.validate_identity_and_authority_dag, lambda c: c["authority_construction_dag_v2"]["nodes"].append("RunToken"), "duplicate value"),
        ("authority-dag-required-edge-missing", validator.validate_identity_and_authority_dag, lambda c: c["authority_construction_dag_v2"]["edges"].remove(["DeliverySettlementCell", "RunToken"]), "required authority edge missing"),
        ("authority-duplicate-owner-allowed", validator.validate_identity_and_authority_dag, lambda c: c["authority_construction_dag_v2"].__setitem__("duplicate_mutable_owner_allowed", True), "duplicate mutable owner allowed"),
        ("authority-stable-owner-changed", validator.validate_identity_and_authority_dag, lambda c: c["authority_construction_dag_v2"]["mutable_state_owners"].__setitem__("ExecutionCellUseCell", "selected_CPU_shard"), "ownership is not stable"),
        ("lease-vector-cycle", validator.validate_activation, lambda c: c["normalized_authority_horizons"].__setitem__("final_ExecutionCellLease_is_not_a_vector_source", False), "final lease is vector source"),
        ("valid-entry-expiry-choice", validator.validate_activation, lambda c: c["root_execution_capacity"].__setitem__("valid_entry_can_nondeterministically_expire_same_due_cell", True), "valid entry may expire"),
        ("decision-key-attempt-pair", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("ActivationDecisionCell_key", "intent_lease_pair"), "decision cell key mismatch"),
        ("retry-writer-change", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("retry_may_change_ActivationShard_writer_because_CPU_or_cell_changes", True), "retry can change writer"),
        ("attempt-bound-uncharged", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("MaxActivationAttempts_is_positive_bounded_and_admission_charged", False), "attempt bound not charged"),
        ("due-entry-no-priority", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("valid_due_entry_has_priority_over_expiry", False), "valid due entry lacks priority"),
        ("attempt-exhaustion-external", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("attempt_exhaustion_without_authenticated_external_cause_result", "AuthorizedExternalWithdrawal"), "attempt exhaustion misclassified"),
        ("permit-ordinary-execution", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("PreEntryPermit_authorizes_ordinary_execution_interrupt_return_resume_or_migration", True), "permit authorizes execution/resume"),
        ("receipt-binds-future-token", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("ActivationCommitReceipt_binds_future_RunToken_digest", True), "receipt/token cycle"),
        ("settlement-binds-future-token", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("DeliverySettlementCell_binds_future_RunToken_digest", True), "settlement/token cycle"),
        ("token-omits-receipt", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("RunToken_binds_existing_ActivationCommitReceipt", False), "RunToken omits receipt"),
        ("token-omits-settlement", validator.validate_activation, lambda c: c["activation_composition_interface"].__setitem__("RunToken_binds_existing_DeliverySettlementCell", False), "RunToken omits settlement cell"),
        ("entry-bundle-no-delivery-cell", validator.validate_activation, lambda c: c["activation_composition_interface"]["entry_atomic_effects"].__setitem__(6, "omit_delivery_cell"), "entry bundle incomplete"),
        ("entry-bundle-token-before-receipt", validator.validate_activation, lambda c: c["activation_composition_interface"]["entry_atomic_effects"].__setitem__(5, "create_one_RunToken create_one_ActivationCommitReceipt create_one_active_DeliverySettlementCell"), "entry bundle internal order invalid"),
        ("context-core-binds-final-key", validator.validate_activation, lambda c: c["activation_receipt_contract"]["ExecutionContextCore_fields"].__setitem__(-1, "final_ExecutionContextKey_digest"), "context core depends on final key"),
        ("receipt-binds-final-key", validator.validate_activation, lambda c: c["activation_receipt_contract"]["common_envelope_fields"].append("ExecutionContextKey_final"), "receipts bind final context key"),
        ("core-receipt-class-optional", validator.validate_activation, lambda c: c["activation_receipt_contract"].__setitem__("MemoryView_Code_Entry_MutableState_Device_and_Stop_classes_are_mandatory", False), "core receipt classes optional"),
        ("core-not-applicable", validator.validate_activation, lambda c: c["activation_receipt_contract"].__setitem__("core_security_class_may_use_NotApplicableReceipt", True), "core class may use NotApplicable"),
        ("device-absence-unprotected", validator.validate_activation, lambda c: c["activation_receipt_contract"]["required_classes"].__setitem__("DeviceIsolationReceipt", "caller_boolean"), "device absence not protected union"),
        ("lifecycle-not-total", validator.validate_activation, lambda c: c["opportunity_lifecycle"].__setitem__("decision_refinement_is_total", False), "lifecycle refinement not total"),
        ("lifecycle-prepared-hidden", validator.validate_activation, lambda c: c["opportunity_lifecycle"].__setitem__("PreparedInert_has_distinct_high_level_state", False), "PreparedInert hidden"),
        ("lifecycle-served-not-monotonic", validator.validate_activation, lambda c: c["opportunity_lifecycle"].__setitem__("activated_and_served_are_orthogonal_monotonic_bits", False), "served bit not monotonic"),
        ("lifecycle-invalid-counts-service", validator.validate_activation, lambda c: c["opportunity_lifecycle"].__setitem__("invalid_low_product_can_map_to_service_or_external_withdrawal", True), "invalid lifecycle product receives credit"),
        ("delegation-bearer", validator.validate_delegation_failure_transfer, lambda c: c["delegation_authority_v2"].__setitem__("unbound_bearer_scope_allowed_on_hostile_Linux_transport", True), "unbound delegation bearer allowed"),
        ("delegation-no-holder-copy-binding", validator.validate_delegation_failure_transfer, lambda c: c["delegation_authority_v2"].__setitem__("holder_binding_survives_transport_copy", False), "holder binding absent"),
        ("delegation-missing-grantee", validator.validate_delegation_failure_transfer, lambda c: c["control_operation"].__setitem__("DelegationGrant_fields", [v for v in c["control_operation"]["DelegationGrant_fields"] if "grantee" not in v]), "DelegationGrant omits grantee"),
        ("failure-partial-index-executable", validator.validate_delegation_failure_transfer, lambda c: c["failure_publication_protocol_v2"].__setitem__("executable_partial_reverse_link_publication_allowed", True), "partial indexed authority executable"),
        ("failure-global-stall", validator.validate_delegation_failure_transfer, lambda c: c["failure_publication_protocol_v2"].__setitem__("disjoint_open_scope_may_continue", False), "globally stalls disjoint scope"),
        ("failure-overlap-unordered", validator.validate_delegation_failure_transfer, lambda c: c["failure_publication_protocol_v2"].__setitem__("overlapping_failures_serialize_at_first_common_scope_gate", False), "overlapping failure ordering absent"),
        ("failure-no-closed-pass", validator.validate_delegation_failure_transfer, lambda c: c["failure_publication_protocol_v2"]["closure_order"].__setitem__(-1, "stop_when_frontier_empty"), "failure fixed point lacks closed pass"),
        ("connectivity-not-current", validator.validate_delegation_failure_transfer, lambda c: c["connectivity_freshness_contract_v2"].__setitem__("CONNECTED_ONLY_requires_current_unconsumed_certificate", False), "certificate not one-use/current"),
        ("connectivity-expiry-omitted", validator.validate_delegation_failure_transfer, lambda c: c["connectivity_freshness_contract_v2"].__setitem__("certificate_expiry_is_normalized_authority_horizon_entry", False), "connectivity expiry omitted"),
        ("connectivity-boolean-authority", validator.validate_delegation_failure_transfer, lambda c: c["connectivity_freshness_contract_v2"].__setitem__("replay_boolean_network_silence_or_transport_success_is_authority", True), "connectivity observation grants authority"),
        ("transfer-missing-supersession", validator.validate_delegation_failure_transfer, lambda c: c["calendar_boundary_transfer_v2"]["variants"].remove("QuorumSupersededStrongContinuity"), "transfer variants mismatch"),
        ("transfer-transitive-clock", validator.validate_delegation_failure_transfer, lambda c: c["calendar_boundary_transfer_v2"].__setitem__("cross_time_mapping", "transitive_chain_allowed"), "transitive clock conversion allowed"),
        ("transfer-prefix-alone-strong", validator.validate_delegation_failure_transfer, lambda c: c["calendar_boundary_transfer_v2"].__setitem__("strong_continuity_from_settlement_prefix_alone", True), "prefix alone grants strong continuity"),
        ("transfer-unresolved-ordinal", validator.validate_delegation_failure_transfer, lambda c: c["calendar_boundary_transfer_v2"].__setitem__("strong_continuity_requires_no_unresolved_predecessor_ordinal_at_or_above_qCut", False), "strong continuity leaves uncertain ordinal"),
        ("transfer-reuses-incarnation", validator.validate_delegation_failure_transfer, lambda c: c["calendar_boundary_transfer_v2"].__setitem__("ContinuityLost_requires_new_ServiceStreamIncarnation", False), "continuity loss reuses incarnation"),
        ("frame-duplicate-slot-id", validator.validate_frame_and_liveness, lambda c: c["protected_work_frame_v2"]["ordered_slots"][8].__setitem__("slot_id", "PW7"), "slot IDs mismatch"),
        ("frame-one-guaranteed-slot", validator.validate_frame_and_liveness, lambda c: c["protected_work_frame_v2"]["ordered_slots"][6].__setitem__("class", "AdmissionControl"), "class counts mismatch"),
        ("frame-forged-counts", validator.validate_frame_and_liveness, lambda c: c["protected_work_frame_v2"]["class_counts"].__setitem__("GuaranteedResidency", 3), "class counts mismatch"),
        ("frame-forged-gap", validator.validate_frame_and_liveness, lambda c: c["protected_work_frame_v2"]["maximum_cyclic_slot_gap"].__setitem__("GuaranteedResidency", 6), "frame gap mismatch"),
        ("calendar-release-multiowner", validator.validate_frame_and_liveness, lambda c: c["guaranteed_calendar_v2"].__setitem__("same_lane_epoch_turn_and_cell_ordinal_multiowner_allowed", True), "same-lane cell collision allowed"),
        ("calendar-release-noninjective", validator.validate_frame_and_liveness, lambda c: c["guaranteed_calendar_v2"].__setitem__("occurrence_to_release_cell_is_injective", False), "release calendar not injective"),
        ("liveness-external-operational", validator.validate_frame_and_liveness, lambda c: c["external_relies"].append("ContractOperationalState_is_Operational"), "external rely assumes internal operational state"),
        ("liveness-vacuous-window", validator.validate_frame_and_liveness, lambda c: c["liveness_contract_v2"].__setitem__("ExogenousStableWindow_may_reference_internal_Operational_or_successful_failure_processing", True), "stable window is vacuous"),
        ("liveness-internal-failstop-external", validator.validate_frame_and_liveness, lambda c: c["liveness_contract_v2"].__setitem__("unexplained_internal_failstop_is_AuthorizedExternalWithdrawal", True), "internal failstop treated as external"),
        ("liveness-failstop-is-service", validator.validate_frame_and_liveness, lambda c: c["liveness_contract_v2"].__setitem__("service_or_declared_failstop_is_valid_liveness_guarantee", True), "failstop satisfies service"),
        ("proof-admit-no-hardware", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["component_assume_guarantee_ledger"]["DYN_ADMIT"]["internal_predecessors"].remove("ENV_HARDWARE_TIME_ROOT"), "DYN_ADMIT predecessor set incomplete"),
        ("proof-operational-after-rank", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["proof_dependency_dag_order"].__setitem__(12, "PER_OPPORTUNITY_RANK_THEOREM"), "duplicate value"),
        ("proof-rank-bypasses-operational", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["component_assume_guarantee_ledger"]["PER_OPPORTUNITY_RANK_THEOREM"].__setitem__("internal_predecessors", ["DYN_MULTILANE_COMPOSE"]), "bypasses operational preservation"),
        ("proof-rank-allows-failstop", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["component_assume_guarantee_ledger"]["PER_OPPORTUNITY_RANK_THEOREM"].__setitem__("guarantee", "service_or_declared_failstop"), "still allows generic failstop"),
        ("proof-legacy-stable-window", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["temporal_not_stored_relies"].__setitem__(0, "StableWindow"), "legacy StableWindow remains"),
        ("proof-no-read-write-schema", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["node_schema_required_fields"].remove("action_IDs_and_exact_read_write_sets"), "read/write schema missing"),
        ("proof-no-provider-formula", validator.validate_proof_dag, lambda c: c["formal_decomposition"]["node_schema_required_fields"].remove("internal_predecessor_provider_component_formula_and_action_set_refs"), "provider mapping missing"),
    ]

    for label, check, mutate, expected in cases:
        contract_case(label, check, mutate, expected)
        count += 1
    return count


def run_assurance_mutations() -> int:
    cases: list[tuple[str, Callable[[dict[str, Any]], None], str]] = [
        ("assurance-missing-object-schema", lambda a: a["exact_object_schemas"].pop("ReviewPayload"), "object schema coverage mismatch"),
        ("assurance-extra-object-schema", lambda a: a["exact_object_schemas"].__setitem__("Extra", {"exact_keys": ["x"]}), "object schema coverage mismatch"),
        ("assurance-missing-nested-schema", lambda a: a["exact_nested_schemas"].pop("FindingDisposition"), "nested schema coverage mismatch"),
        ("assurance-duplicate-exact-key", lambda a: a["exact_object_schemas"]["ReviewPayload"]["exact_keys"].append("verdict"), "duplicate value"),
        ("assurance-admission-no-prior-root", lambda a: a["exact_object_schemas"]["AdmissionVote"]["exact_keys"].remove("prior_tree_root"), "admission vote does not bind exact persisted extension"),
        ("assurance-receipt-no-timeout", lambda a: a["exact_object_schemas"]["SemanticValidationReceipt"]["exact_keys"].remove("timed_out"), "semantic receipt success fields incomplete"),
        ("assurance-review-no-dispositions", lambda a: a["exact_object_schemas"]["ReviewPayload"]["exact_keys"].remove("dispositions"), "ReviewPayload incomplete"),
        ("assurance-failure-is-success", lambda a: a["semantic_validation_success"].__setitem__("matching_failure_timeout_signal_truncation_or_partial_inventory_is_success", True), "failed receipts can pass"),
        ("assurance-digest-only-accept", lambda a: a["review_acceptance"].__setitem__("digest_only_accept_payload_allowed", True), "vacuous review accept allowed"),
        ("assurance-sign-before-persist", lambda a: a["witness_persistence"].__setitem__("durably_persist_successor_and_external_anchor_before_sign", False), "sign before persistence"),
        ("assurance-key-rotation-resume", lambda a: a["witness_persistence"].__setitem__("key_rotation_may_resume_old_campaign", True), "rollback can resume"),
        ("assurance-real-verifier-overclaim", lambda a: a["claims"].__setitem__("real_verifier_implemented", True), "assurance overclaim"),
        ("assurance-freeze-overclaim", lambda a: a["claims"].__setitem__("architecture_frozen", True), "assurance overclaim"),
    ]
    for label, mutate, expected in cases:
        assurance_case(label, mutate, expected)
    return len(cases)


def run_parity_mutations() -> int:
    cases: list[tuple[str, Callable[[dict[str, Any]], None], str]] = [
        ("parity-contract-id", lambda p: p.__setitem__("contract_id", "wrong"), "human contract ID mismatch"),
        ("parity-authority-dag", lambda p: p["authority_dag_nodes"].pop(), "human authority DAG mismatch"),
        ("parity-decision-key", lambda p: p.__setitem__("activation_decision_key", "intent_lease_pair"), "human decision key mismatch"),
        ("parity-work-frame", lambda p: p["protected_work_slots"][6].__setitem__(1, "AdmissionControl"), "human work frame mismatch"),
        ("parity-transfer", lambda p: p["calendar_boundary_variants"].pop(), "human transfer variants mismatch"),
        ("parity-proof-order", lambda p: p["proof_dependency_order"].remove("OPERATIONAL_PRESERVATION_THEOREM"), "human proof order mismatch"),
        ("parity-freeze-overclaim", lambda p: p.__setitem__("architecture_frozen", True), "human parity overclaims freeze"),
    ]
    for label, mutate, expected in cases:
        parity_case(label, mutate, expected)
    return len(cases)


def run_materializer_mutations() -> int:
    materializer_case("materializer-base-bytes-changed", None, "base hash mismatch", mutate_base=True)
    materializer_case("materializer-wrong-base-pin", lambda o: o["base"].__setitem__("raw_sha256", "0" * 64), "base hash mismatch")
    materializer_case("materializer-extra-top-key", lambda o: o.__setitem__("extra", True), "unknown overlay keys")
    materializer_case("materializer-missing-remove-path", lambda o: o["remove_paths"].append("/does/not/exist"), "remove path does not exist")
    materializer_case("materializer-remove-missing-list-item", lambda o: o["remove_list_items"]["object_types"].append("NotInBase"), "occurs 0 times")
    materializer_case("materializer-append-existing-item", lambda o: o["append_unique"]["object_types"].append("DomainKey"), "append item already exists")
    return 6


def main() -> int:
    try:
        validator.validate_identity_and_authority_dag(BASE_CONTRACT)
        validator.validate_activation(BASE_CONTRACT)
        validator.validate_delegation_failure_transfer(BASE_CONTRACT)
        validator.validate_frame_and_liveness(BASE_CONTRACT)
        validator.validate_proof_dag(BASE_CONTRACT)
        validator.validate_assurance(BASE_ASSURANCE)
        validator.validate_human_parity(BASE_CONTRACT, BASE_HUMAN)
        total = 0
        total += run_contract_mutations()
        total += run_assurance_mutations()
        total += run_parity_mutations()
        total += run_materializer_mutations()
    except (TestFailure, validator.ValidationError, KeyError, IndexError, TypeError, ValueError) as exc:
        print(f"R6 successor hostile mutations: FAIL: {exc}")
        return 1
    print(f"R6 successor hostile mutations: PASS ({total} intended-gate rejections)")
    print("architecture_frozen=false; tla_authorized=false; protection_evidenced=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
