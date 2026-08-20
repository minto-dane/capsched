#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="$ROOT/capsched-models/validation/validate-dynamic-residency-architecture-contract.py"
TYPE_BOUNDARY_TEST="$ROOT/capsched-models/validation/test-dynamic-residency-witness-type-boundary.py"
CONTRACT="capsched-models/analysis/dynamic-admission-recurring-residency-architecture-contract-v1.json"
HUMAN="capsched-models/analysis/0189-dynamic-admission-and-recurring-residency-architecture-contract.md"
R1="capsched-models/analysis/dynamic-admission-recurring-residency-pre-freeze-review-disposition-v1.json"
R1_HUMAN="capsched-models/analysis/0190-dynamic-residency-pre-freeze-hostile-review-disposition.md"
R2="capsched-models/analysis/dynamic-admission-recurring-residency-second-hostile-review-disposition-v1.json"
R2_HUMAN="capsched-models/analysis/0191-dynamic-residency-second-hostile-review-and-redesign.md"
WITNESS="capsched-models/analysis/dynamic-residency-preformal-two-lane-witness-v1.json"
WITNESS_HUMAN="capsched-models/analysis/0192-dynamic-residency-preformal-two-lane-witness.md"
R3="capsched-models/analysis/dynamic-residency-third-hostile-review-disposition-v1.json"
R3_HUMAN="capsched-models/analysis/0193-dynamic-residency-third-hostile-review-and-redesign.md"
ASSURANCE="capsched-models/analysis/architecture-freeze-external-assurance-protocol-v2.json"
ASSURANCE_HUMAN="capsched-models/analysis/0194-architecture-freeze-external-assurance-protocol-v2.md"
DC="capsched-models/analysis/dynamic-residency-datacenter-composition-boundary-review-v1.json"
DC_HUMAN="capsched-models/analysis/0195-dynamic-residency-datacenter-composition-boundary-review.md"
R4="capsched-models/analysis/dynamic-residency-fourth-hostile-counterexample-review-v1.json"
R4_HUMAN="capsched-models/analysis/0196-dynamic-residency-fourth-hostile-counterexample-review.md"
ASSURANCE_R4="capsched-models/analysis/architecture-freeze-assurance-v2-hostile-review-v1.json"
ASSURANCE_R4_HUMAN="capsched-models/analysis/0197-architecture-freeze-assurance-v2-hostile-review.md"
R5="capsched-models/analysis/dynamic-residency-fifth-hostile-architecture-and-proof-review-v1.json"
R5_HUMAN="capsched-models/analysis/0198-dynamic-residency-fifth-hostile-architecture-and-proof-review.md"
ASSURANCE_VERIFIER="capsched-models/validation/validate-architecture-freeze-assurance-v2.py"
ASSURANCE_REAL_STUB="capsched-models/validation/verify-architecture-freeze-assurance-v2-real.py"
PLAN="capsched-models/plans/0006-final-compositional-model-completion-plan.md"
ADR="capsched-ai/decisions/ADR-0015-architecture-first-executable-specification-order.md"

FILES=(
        "$CONTRACT" "$HUMAN"
        "$R1" "$R1_HUMAN" "$R2" "$R2_HUMAN"
        "$WITNESS" "$WITNESS_HUMAN"
        "$R3" "$R3_HUMAN" "$ASSURANCE" "$ASSURANCE_HUMAN"
        "$DC" "$DC_HUMAN" "$R4" "$R4_HUMAN"
        "$ASSURANCE_R4" "$ASSURANCE_R4_HUMAN" "$R5" "$R5_HUMAN"
        "$ASSURANCE_VERIFIER" "$ASSURANCE_REAL_STUB"
        "$PLAN" "$ADR"
)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
MUTATIONS=0
START_AT=${START_AT:-}
START_REACHED=0

restore_all() {
        local relative
        for relative in "${FILES[@]}"; do
                mkdir -p "$TMP/$(dirname "$relative")"
                rm -f "$TMP/$relative"
                cp "$ROOT/$relative" "$TMP/$relative"
        done
}

expect_reject() {
        local name=$1
        local expected=$2
        local output status

        if [[ -n "$START_AT" && $START_REACHED -eq 0 ]]; then
                if [[ "$name" == "$START_AT" ]]; then
                        START_REACHED=1
                else
                        restore_all
                        return
                fi
        fi

        set +e
        output=$(python3 "$VALIDATOR" --root "$TMP" 2>&1)
        status=$?
        set -e
        if (( status == 0 )); then
                printf 'FAIL: mutation accepted: %s\n' "$name" >&2
                exit 1
        fi
        if ! grep -Fq -- "$expected" <<<"$output"; then
                printf 'FAIL: mutation rejected by wrong gate: %s\n' "$name" >&2
                printf 'expected: %s\nactual: %s\n' "$expected" "$output" >&2
                exit 1
        fi
        MUTATIONS=$((MUTATIONS + 1))
        restore_all
}

json_mutation() {
        local relative=$1
        local filter=$2
        local name=$3
        local expected=$4
        jq "$filter" "$TMP/$relative" >"$TMP/mutated.json"
        mv "$TMP/mutated.json" "$TMP/$relative"
        expect_reject "$name" "$expected"
}

restore_all
PYTHONDONTWRITEBYTECODE=1 python3 "$TYPE_BOUNDARY_TEST"
python3 "$VALIDATOR" --root "$ROOT" >/dev/null
python3 "$VALIDATOR" --root "$TMP" >/dev/null

# Strict parsing, exact schema, claim boundary, and inventory.
perl -0pi -e 's/^\{\n/\{\n  "id": "duplicate",\n/' "$TMP/$CONTRACT"
expect_reject duplicate-json-key "duplicate JSON key"
perl -0pi -e 's/"schema_version": 1/"schema_version": NaN/' "$TMP/$CONTRACT"
expect_reject nonfinite-number "non-finite JSON constant"
perl -0pi -e 's/"schema_version": 1/"schema_version": 1.0/' "$TMP/$CONTRACT"
expect_reject floating-number "floating-point value is forbidden"
json_mutation "$CONTRACT" '.unexpected = true' unknown-top-key \
        "architecture contract has missing or unknown keys"
json_mutation "$CONTRACT" '.status = "architecture_frozen_pre_formal"' \
        stored-freeze-status "candidate status may not claim freeze"
json_mutation "$CONTRACT" '.claims.adversarial_semantic_freeze_complete = true' \
        stored-freeze-claim "candidate claims changed or overclaim"
json_mutation "$CONTRACT" '.implementation_selected = true' \
        implementation-selection "candidate selected implementation or Linux behavior"
json_mutation "$CONTRACT" '.linux_behavior_change_approved = true' \
        linux-behavior-approval "candidate selected implementation or Linux behavior"
json_mutation "$CONTRACT" '.object_types |= map(select(. != "NodeConfig"))' \
        object-inventory-deletion "object type inventory/order changed"
json_mutation "$CONTRACT" '.object_types[0:2] |= reverse' \
        object-inventory-reorder "object type inventory/order changed"
json_mutation "$CONTRACT" '.version_spaces |= map(select(. != "QuorumEpoch"))' \
        namespace-inventory-deletion "version-space inventory/order changed"
json_mutation "$CONTRACT" '.version_spaces[0:2] |= reverse' \
        namespace-inventory-reorder "version-space inventory/order changed"
json_mutation "$CONTRACT" '.formal_decomposition.models |= map(select(. != "DYN_SHARD"))' \
        formal-model-deletion "formal decomposition model inventory changed"
json_mutation "$CONTRACT" '.formal_decomposition.derived_not_stored_predicates |= map(select(. != "CanonicalFailureCover"))' \
        derived-predicate-deletion "derived predicate inventory changed"
json_mutation "$CONTRACT" '.formal_decomposition.proof_dependency_dag_order[4:6] |= reverse' \
        formal-dag-order "formal proof dependency order changed"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.DYN_ADMIT.internal_predecessors = ["DYN_REQUEST"]' \
        formal-forward-cycle "formal dependency is cyclic or forward: DYN_ADMIT -> DYN_REQUEST"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.DYN_REQUEST.internal_predecessors = ["UNKNOWN_PROOF_NODE"]' \
        formal-unknown-node "formal predecessor is unknown: DYN_REQUEST -> UNKNOWN_PROOF_NODE"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.PER_OPPORTUNITY_RANK_THEOREM.guarantee = "all_predecessor_guarantees"' \
        formal-implicit-predecessor "formal guarantee smuggles a rely or descendant claim"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.DYN_LIVENESS_THEOREM.conditional_omega_relies = []' \
        formal-omega-erasure "formal conditional omega rely set changed"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.DYN_CHURN.temporal_relies = ["StableWindow"]' \
        formal-temporal-rely-drift "formal temporal rely set changed"
json_mutation "$CONTRACT" '.formal_decomposition.component_assume_guarantee_ledger.ENV_ENTRY_CODE_STATE_INTERFACE.internal_predecessors = ["ENV_HARDWARE_TIME_ROOT"]' \
        formal-external-hidden-dependency "formal predecessor set changed: ENV_ENTRY_CODE_STATE_INTERFACE"
json_mutation "$CONTRACT" '.formalization_order[-1] = "premature_end"' \
        formal-order-terminal "formalization order no longer ends in claim decision"
json_mutation "$CONTRACT" '.linux_source_identity.work_commit = "0000000000000000000000000000000000000000"' \
        linux-source-drift "Linux source identity changed"
json_mutation "$CONTRACT" '.normative_term = "SecurityIncidentCell"' \
        obsolete-term "obsolete architecture term remains"

# Namespace ownership, parent graph, and exhaustion containment.
json_mutation "$CONTRACT" 'del(.namespace_renewal.namespace_type_registry.QuorumEpoch)' \
        registry-deletion "namespace registry order/inventory differs"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.Unregistered = .namespace_renewal.namespace_type_registry.QuorumEpoch' \
        registry-addition "namespace registry order/inventory differs"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.QuorumEpoch.unknown = true' \
        registry-unknown-field "registry.QuorumEpoch has missing or unknown keys"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.QuorumEpoch.kind = "ambient"' \
        registry-kind "unknown registry kind"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.QuorumEpoch.parents = ["UnknownEpoch"]' \
        registry-unknown-parent "invalid namespace parent"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.DomainEpoch.parents = ["LocalAuthorityGeneration"] | .namespace_renewal.namespace_type_registry.LocalAuthorityGeneration_and_LocalLeaseFenceGeneration = null' \
        registry-shape-drift "namespace registry order/inventory differs"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.DomainEpoch.parents = ["LocalAuthorityGeneration"] | .namespace_renewal.namespace_type_registry.LocalAuthorityGeneration.parents = ["DomainEpoch"]' \
        registry-cycle "namespace cycle reaches"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.NodeConfigGeneration.may_advance_boot = true' \
        local-boot-advance "local exhaustion may advance boot"
json_mutation "$CONTRACT" '.namespace_renewal.namespace_type_registry.NodeConfigGeneration.parents = []' \
        critical-parent-drift "critical namespace parent changed"
json_mutation "$CONTRACT" '.namespace_renewal.registry_is_the_single_parent_graph_source = false' \
        multiple-parent-sources "namespace registry is not the sole parent graph"

# Hierarchy, physical execution, target control, and partition imports.
json_mutation "$CONTRACT" '.node_config_and_hierarchy.NodeConfig_owner = "Linux"' \
        node-config-owner "critical architecture value changed"
json_mutation "$CONTRACT" '.node_config_and_hierarchy.per_admission_maximum_may_exceed_NodeConfig = true' \
        admission-raises-node-config "critical architecture value changed"
json_mutation "$CONTRACT" '.node_config_and_hierarchy.ancestor_capacity_equation = "Current_only"' \
        ancestor-capacity-equation "ancestor capacity equation changed"
json_mutation "$CONTRACT" '.node_config_and_hierarchy.every_authority_and_cleanup_use_binds_complete_ancestor_fence_vector = false' \
        missing-ancestor-vector "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.one_physical_opportunity_charges_at_most_one_descendant_lane = false' \
        root-cell-double-spend "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.one_physical_opportunity_creates_ActivationIntent = true' \
        root-cell-double-intent "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.ExecutionCellLease_is_immutable_after_allocator_publication = false' \
        mutable-cell-lease "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.ExecutionCellUseCell_is_the_only_mutable_one_use_state = false' \
        competing-cell-state "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.root_allocator_issues_only_cells_already_debited_to_the_lane_through_every_shared_parent = false' \
        undeclared-parent-debit "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.ActivationIntent_is_prepared_before_and_binds_one_already_allocator_issued_future_cell_without_consuming_it = false' \
        prepare-consumes-cell "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.cell_can_wait_carry_forward_or_be_reused_after_due_interval = true' \
        cell-carry-forward "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.token_budget_may_exceed_cell_end_or_any_bound_authority_horizon = true' \
        token-outlives-cell "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.remaining_cell_budget_can_roll_into_later_cell_or_other_lane = true' \
        cell-budget-rollover "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.one_physical_opportunity_issues_executable_RunToken_directly = true' \
        root-cell-direct-token "critical architecture value changed"
json_mutation "$CONTRACT" '.root_execution_capacity.parent_capacity_equation = "sum_virtual_lanes"' \
        root-capacity-equation "physical execution capacity equation changed"
json_mutation "$CONTRACT" '.protected_service_capacity.independent_certificates_can_overbook_shared_parent = true' \
        parent-overbooking "critical architecture value changed"
json_mutation "$CONTRACT" '.clock_bridge.shard_ControlTurn_can_be_reused_as_every_target_credit = true' \
        target-credit-reuse "critical architecture value changed"
json_mutation "$CONTRACT" '.clock_bridge.per_shard_turn_conservation = "each_target_may_advance"' \
        target-conservation "target-control conservation equation changed"
json_mutation "$CONTRACT" '.clock_bridge.target_microstep_can_block_while_holding_schedule_cell = true' \
        target-holds-cell "critical architecture value changed"
json_mutation "$CONTRACT" '.node_lease_import.clock_conversion_returns_interval_not_point = false' \
        lease-point-clock "critical architecture value changed"
json_mutation "$CONTRACT" '.node_lease_import.disconnect_can_change_partition_mode_extend_term_increase_rights_or_reset_offline_timer = true' \
        disconnect-amplifies-lease "critical architecture value changed"
json_mutation "$CONTRACT" '.node_lease_import.PartitionModes.CONNECTED_ONLY = "continue_without_connectivity"' \
        partition-mode-drift "partition-mode semantics changed"
json_mutation "$CONTRACT" '.node_lease_import.reconnection_reopens_predecessor_frozen_use = true' \
        reconnect-reopens-lease "critical architecture value changed"

# Global placement, total failure handling, cleanup, and audit/restart.
json_mutation "$CONTRACT" '.global_placement_authority.network_silence_is_source_quiescence = true' \
        silence-is-quiescence "critical architecture value changed"
json_mutation "$CONTRACT" '.global_placement_authority.local_PlacementGeneration_substitutes_for_global_fence = true' \
        local-placement-fence "critical architecture value changed"
json_mutation "$CONTRACT" '.global_placement_authority.reconnection_reopens_predecessor_ownership_epoch = true' \
        reconnect-reopens-placement "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.CanonicalFailureCover_is_total = false' \
        partial-failure-cover "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.real_failure_can_be_truncated_rejected_or_stutter_while_authority_continues = true' \
        truncating-real-failure "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.CanonicalFailureCover_results_in_order |= reverse' \
        failure-cover-precedence "failure cover precedence changed"
json_mutation "$CONTRACT" '.node_mode.each_live_authority_use_charges_one_reverse_edge_and_ScopeCleanupReservation_per_leaf_and_every_potential_cover_ancestor_before_publication = false' \
        uncharged-cleanup-edge "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.reverse_edge_overflow_or_conservation_mismatch_result = "truncate"' \
        cleanup-overflow-continues "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.source_health_is_derived_only_from_EffectiveScope_not_duplicated_in_SourceReplayCell = false' \
        duplicated-source-health "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.audit_retry_reuses_same_event_and_position = false' \
        audit-position-remint "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.Committed_decision_is_sole_multiscope_authority_linearization = false' \
        split-authority-linearization "critical architecture value changed"
json_mutation "$CONTRACT" '.node_mode.MaterializeScope_changes_effective_authority = true' \
        materialization-authority "critical architecture value changed"

# Apply ownership, migration state, and joint activation.
json_mutation "$CONTRACT" '.control_operation.ShardApplyOwner_is_exactly_one_per_entry_and_only_apply_status_writer = false' \
        multiple-apply-writers "critical architecture value changed"
json_mutation "$CONTRACT" '.control_operation.failure_transition_writes_apply_status = true' \
        failure-writes-apply "critical architecture value changed"
json_mutation "$CONTRACT" '.control_operation.local_apply_can_return_or_mint_escrow = true' \
        local-apply-mints-escrow "critical architecture value changed"
json_mutation "$CONTRACT" '.control_operation.stored_overwritable_TransferPhase_exists = true' \
        overwritable-transfer-phase "critical architecture value changed"
json_mutation "$CONTRACT" '.control_operation.network_silence_timeout_or_local_PlacementGeneration_is_authorizer = true' \
        migration-silence-authorizer "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.residency_output = "RunToken"' \
        residency-emits-token "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.ActivationIntent_is_execution_authority_or_service = true' \
        intent-is-authority "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.RequiredQuiescenceReceiptSet_rules.missing_class_is_NotApplicable = true' \
        missing-receipt-is-na "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.failed_joint_validation_can_leave_partial_executable_state = true' \
        partial-joint-activation "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.one_successful_ActivationSlotID_and_ActivationIntent_pair_can_have_more_than_one_ActivationID_or_initial_entry_RunToken = true' \
        activation-retry-remint "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.hardware_inert_staging_is_executable_before_final_valid_entry_gate = true' \
        pre-gate-execution "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.ActivationCommitReceipt_alone_counts_recurring_service = true' \
        commit-counts-service "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.only_qualifying_ExecutionDeliveryReceipt_sets_Served_and_counts_service = false' \
        delivery-not-required "critical architecture value changed"
json_mutation "$CONTRACT" '.activation_composition_interface.zero_delivered_ticks_without_authenticated_post_entry_voluntary_yield_counts_service = true' \
        zero-delivery-service "critical architecture value changed"

# Bootstrap, scale, and Linux authority boundary.
json_mutation "$CONTRACT" '.management_recovery_bootstrap.owner = "ordinary_domain"' \
        bootstrap-owner "critical architecture value changed"
json_mutation "$CONTRACT" '.management_recovery_bootstrap.bootstrap_execution_and_control_capacity_is_explicitly_conserved_not_free = false' \
        free-bootstrap-capacity "critical architecture value changed"
json_mutation "$CONTRACT" '.management_recovery_bootstrap.fallback_to_ordinary_Linux_or_unprotected_management = true' \
        unprotected-management-fallback "critical architecture value changed"
json_mutation "$CONTRACT" '.root_plan.every_lane_binds_parent_conserved_RootExecutionAllocationCertificate = false' \
        lane-without-parent-cell "critical architecture value changed"
json_mutation "$CONTRACT" '.root_plan.independent_lane_clocks_imply_disjoint_physical_capacity = true' \
        clocks-imply-capacity "critical architecture value changed"
json_mutation "$CONTRACT" '.scale_contract.all_certificate_vector_and_proof_widths_are_fixed_by_NodeConfig = false' \
        unbounded-certificate "critical architecture value changed"
json_mutation "$CONTRACT" '.scale_contract.admission_can_raise_NodeConfig_maximum = true' \
        admission-raises-scale-bound "critical architecture value changed"
json_mutation "$CONTRACT" '.scale_contract.hierarchy_semantics_mandatory = false' \
        optional-hierarchy "critical architecture value changed"
json_mutation "$CONTRACT" '.linux_projection_adapter.authority_role = true' \
        linux-authority-role "critical architecture value changed"
json_mutation "$CONTRACT" '.linux_projection_adapter.guaranteed_activation_requires_linux_call_or_LocalValidate = true' \
        linux-activation-dependency "critical architecture value changed"

# Review ledgers must remain open and provenance-limited.
json_mutation "$R3" '.findings[0].status = "closed"' \
        r3-premature-close "R3 finding was prematurely closed"
json_mutation "$R3" '.review_finding_count = 19' \
        r3-count-drift "R3 reviewer finding inventory changed"
json_mutation "$R3" '.claims.architecture_frozen = true' \
        r3-freeze-overclaim "R3 disposition overclaims"
json_mutation "$DC" '.source_verdict = "FREEZE_YES"' \
        dc-source-acceptance "source datacenter review was converted into acceptance"
json_mutation "$DC" '.reviewer_identity_authenticated = true' \
        dc-false-authentication "source datacenter review was converted into acceptance"
json_mutation "$DC" '.source_review_may_accept_revised_bytes = true' \
        dc-stale-review-accepts "source datacenter review was converted into acceptance"
json_mutation "$DC" '.findings[0].status = "closed"' \
        dc-premature-close "datacenter finding was prematurely closed"
json_mutation "$DC" '.claims.revised_bytes_reviewed = true' \
        dc-revised-review-overclaim "datacenter review overclaims"
json_mutation "$R4" '.source_verdict = "FREEZE_YES"' \
        r4-source-acceptance "R4 rejection was converted into authenticated acceptance"
json_mutation "$R4" '.review_provenance.raw_independent_session_transcripts_retained_as_immutable_artifacts = true' \
        r4-false-provenance "R4 review provenance was upgraded or obscured"
json_mutation "$R4" '.findings[0].status = "closed"' \
        r4-premature-close "R4 finding was prematurely closed"
json_mutation "$R4" '.claims.findings_closed = true' \
        r4-review-overclaim "R4 review overclaims"
json_mutation "$ASSURANCE_R4" '.source_verdict = "FREEZE_YES"' \
        assurance-r4-source-acceptance "assurance rejection was converted into acceptance"
json_mutation "$ASSURANCE_R4" '.finding_ids |= .[1:]' \
        assurance-r4-inventory "assurance R4 finding inventory changed"
json_mutation "$ASSURANCE_R4" '.findings[0].status = "closed"' \
        assurance-r4-premature-close "assurance finding was prematurely closed"
json_mutation "$ASSURANCE_R4" '.claims.real_mode_assurance_implemented = true' \
        assurance-r4-overclaim "assurance R4 review overclaims"
json_mutation "$R5" '.source_verdict = "FREEZE_YES"' \
        r5-source-acceptance "R5 review identity, rejection, or status changed"
json_mutation "$R5" '.review_provenance.raw_independent_session_transcripts_retained_as_immutable_artifacts = true' \
        r5-false-provenance "R5 review provenance was upgraded or obscured"
json_mutation "$R5" '.finding_ids |= .[1:]' \
        r5-finding-inventory "R5 finding inventory changed"
json_mutation "$R5" '.findings[0].status = "closed"' \
        r5-premature-close "R5 finding was prematurely closed"
json_mutation "$R5" '.claims.model_supported = true' \
        r5-overclaim "R5 review overclaims"

# Executable witness topology, ownership, and finding coverage.
json_mutation "$WITNESS" '.scenarios |= map(select(.id != "WIT-JOINT-ACTIVATION"))' \
        witness-scenario-deletion "witness scenario inventory/order changed"
json_mutation "$WITNESS" '.scenarios[0:2] |= reverse' \
        witness-scenario-reorder "witness scenario inventory/order changed"
json_mutation "$WITNESS" '.topology.control_targets = ["target_A"]' \
        witness-target-deletion "witness two-lane/two-target topology changed"
json_mutation "$WITNESS" '.topology.bounds.KDepth = 4' \
        witness-bound-drift "witness NodeConfig bounds changed"
json_mutation "$WITNESS" '.ownership |= map(select(.object != "ActivationIntent"))' \
        witness-owner-deletion "witness ownership inventory changed"
json_mutation "$WITNESS" '(.ownership[] | select(.object == "ActivationIntent") | .sole_writer) = "Linux"' \
        witness-owner-change "critical witness owner changed"
json_mutation "$WITNESS" '.scenarios[0].trace_right = .scenarios[0].trace_left' \
        witness-noop-pair "paired traces are a no-op duplicate"
json_mutation "$WITNESS" '.scenarios[0].required_observations = []' \
        witness-empty-observation "empty scenario field"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.required_checks) |= map(select(. != "positive_delivery_counts_service"))' \
        witness-joint-check-deletion "witness checks missing, reordered, or unexecuted: WIT-JOINT-ACTIVATION"
json_mutation "$WITNESS" '.coverage.third_round_trace_findings |= .[1:]' \
        witness-r3-coverage "witness R3 trace partition changed"
json_mutation "$WITNESS" '.coverage.datacenter_composition_boundary_findings |= .[1:]' \
        witness-dc-coverage "witness datacenter partition changed"
json_mutation "$WITNESS" '.coverage.fourth_round_architecture_findings_executed |= .[1:]' \
        witness-r4-coverage "witness R4 partition changed"
json_mutation "$WITNESS" '.coverage.fifth_round_architecture_findings_executed |= .[1:]' \
        witness-r5-coverage "witness R5 partition changed"
json_mutation "$WITNESS" '.coverage.no_finding_is_closed_by_this_witness = false' \
        witness-closes-finding "witness closes findings"
json_mutation "$WITNESS" '.claims.model_checked = true' \
        witness-proof-overclaim "witness overclaims"

# Each structured witness machine must reject concrete semantic counterexamples.
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-HIERARCHY-BOUNDS") | .executable.paths.A) += ["too_deep_1", "too_deep_2"]' \
        witness-hierarchy-depth "witness check failed: WIT-HIERARCHY-BOUNDS/all_paths_within_depth"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-HIERARCHY-BOUNDS") | .executable) |= (.proof_bytes = (.bounds.proof_bytes + 1))' \
        witness-hierarchy-proof-width "witness check failed: WIT-HIERARCHY-BOUNDS/all_serialized_bounds_hold"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-HIERARCHY-BOUNDS") | .executable.reservations.tenant_A.current) = 999' \
        witness-hierarchy-overcommit "witness check failed: WIT-HIERARCHY-BOUNDS/every_ancestor_capacity_conserved"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.hardware_frame.partitions.slack[0]) = "h13"' \
        witness-hardware-double-partition "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/shared_hardware_exact_partition"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.execution_frame.partitions.lane_A[0]) = "h7"' \
        witness-execution-double-partition "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/execution_is_exact_parent_subset_partition"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.leases[0].lane) = "lane_unknown"' \
        witness-unknown-lane "invalid execution lease: lease_A1"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.leases[1].occurrence) = "cpu0:100:110"' \
        witness-duplicate-occurrence "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/unique_schedule_occurrence"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.leases[0].issued_at) = 95' \
        witness-future-intent-cycle "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/allocator_slot_precedes_intent_binding"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.use_cells[0].states) = ["Settled"]' \
        witness-use-cell-skips-unbound "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/one_way_use_state_from_unbound"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.leases[0].unused) = 2' \
        witness-cell-budget-overrun "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/cell_budget_sum"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable) |= (.token_executions += [.token_executions[0]])' \
        witness-duplicate-token "duplicate token or lease execution"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].use_cell) = "unknown_use"' \
        witness-token-unknown-use "token execution references an unknown or mismatched use"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].activation_slot_id) = "slot_other"' \
        witness-token-slot-mismatch "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/token_lease_slot_bijection"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].entry_permit_uses) = 2' \
        witness-token-entry-reuse "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/one_use_entry_and_cumulative_budget"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].segments[0].end) = 111' \
        witness-token-outlives-cell "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/one_use_entry_and_cumulative_budget"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].segments[0].resume_sequence) = 1' \
        witness-resume-sequence-skip "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/resume_sequences_monotonic"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable) |= (.leases[1].start = 106 | .leases[1].end = 116 | .leases[1].occurrence = "cpu0:106:116" | .leases[1].normalized_not_after = 116 | .token_executions[1].segments[0].start = 107 | .token_executions[1].segments[0].end = 113)' \
        witness-context-overlap "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/no_context_overlap"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-ROOT-EXECUTION-CAPACITY") | .executable.token_executions[0].replay_after_settlement_executable) = true' \
        witness-stale-token-replay "witness check failed: WIT-ROOT-EXECUTION-CAPACITY/settled_token_replay_rejected"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-TARGET-CONTROL-CONSERVATION") | .executable.dispatches[0].after.control_turn) += 1' \
        witness-two-shard-turns "witness check failed: WIT-TARGET-CONTROL-CONSERVATION/one_shard_turn_per_dispatch"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-TARGET-CONTROL-CONSERVATION") | .executable) |= (.dispatches[0].after.target_B = 8 | .dispatches[1].after.target_B = 9)' \
        witness-two-target-credit "witness check failed: WIT-TARGET-CONTROL-CONSERVATION/exactly_one_target_advances"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-TARGET-CONTROL-CONSERVATION") | .executable.post_state_lane_turns.target_A) = 30' \
        witness-target-quota-deficit "witness check failed: WIT-TARGET-CONTROL-CONSERVATION/post_anchor_quota_holds"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.modes.CONTINUE_TO_CONSERVATIVE_EXPIRY.computed_deadline) += 1' \
        witness-partition-nonconservative-deadline "witness check failed: WIT-PARTITION-IMPORT/conservative_deadline_is_minimum"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.issuer_latest_possible_expiry) = 179' \
        witness-partition-inverted-expiry-interval "witness check failed: WIT-PARTITION-IMPORT/conservative_deadline_is_minimum"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.modes.CONNECTED_ONLY.ordinary_activation) = true' \
        witness-connected-only-reopens "witness check failed: WIT-PARTITION-IMPORT/connected_only_requires_evidence"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.modes.RECOVERY_ONLY.ordinary_activation_at_install) = true' \
        witness-recovery-only-activates "witness check failed: WIT-PARTITION-IMPORT/recovery_only_blocks_from_installation"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.modes.RECOVERY_ONLY.connectivity) = false' \
        witness-reconnect-reopens-recovery "witness check failed: WIT-PARTITION-IMPORT/connectivity_cannot_reopen_recovery_only"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARTITION-IMPORT") | .executable.modes.CONTINUE_TO_CONSERVATIVE_EXPIRY.deny_tick) += 1' \
        witness-expiry-not-half-open "witness check failed: WIT-PARTITION-IMPORT/expiry_is_half_open"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.deadline_entries[1].source_class) = "frozen_lease"' \
        witness-duplicate-horizon-source "duplicate normalized deadline source class"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.deadline_entries[0].target_epoch) += 1' \
        witness-horizon-target-epoch-mismatch "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/all_deadlines_normalized_to_exact_target_epoch"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.raw_cross_clock_minimum_allowed) = true' \
        witness-raw-cross-clock-minimum "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/raw_cross_clock_minimum_rejected"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.expected_effective_horizon) += 1' \
        witness-effective-horizon-not-minimum "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/effective_horizon_is_conservative_minimum"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.lease_only_extension.allowed) = true' \
        witness-lease-only-extension "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/lease_only_extension_rejected"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.fresh_global_placement.allowed) = false' \
        witness-fresh-placement-denied "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/fresh_placement_can_extend"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.activation_not_before) -= 1' \
        witness-residual-horizon-overlap "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/activation_strictly_after_all_residual_effects"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.time_supersession_allowed_for_unbounded) = true' \
        witness-unbounded-time-supersession "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/unbounded_effect_rejects_time_supersession"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-GLOBAL-PLACEMENT-SUPERSESSION") | .executable.fresh_global_placement.new_ownership_epoch) = 7' \
        witness-placement-epoch-not-advanced "witness check failed: WIT-GLOBAL-PLACEMENT-SUPERSESSION/successor_epoch_and_token_advance"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.cover_tree_parent.tenant_A) = "tenant_A"' \
        witness-failure-tree-cycle "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/cover_tree_is_rooted_unique_parent_acyclic"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.publication_snapshot.after_fence_published) = true' \
        witness-after-fence-use-published "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/publication_fence_snapshot_is_total"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.claimed_iterations) |= .[0:3]' \
        witness-failure-closure-early-stop "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/claimed_iterations_equal_monotonic_least_fixed_point"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.closure_bounds.iterations) = 2' \
        witness-failure-closure-bound "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/least_fixed_point_within_NodeConfig_bounds"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.expected_cover) = "node_root"' \
        witness-wrong-failure-lca "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/oversized_union_uses_unique_lca"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.root_case_result) = "continue"' \
        witness-root-cover-continues "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/root_lca_forces_node_failstop"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.capacity_after_commit.failure_escrow) = 5' \
        witness-failure-escrow-loss "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/commit_conserves_and_moves_to_escrow"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.capacity_after_terminal_cleanup.current) = 999' \
        witness-cleanup-before-terminal "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/cleanup_only_releases_after_terminal"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.cover_ancestor_cleanup_reservations.tenant_A) = 5' \
        witness-cover-ancestor-undercharge "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/cover_ancestor_cleanup_within_precharge"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-FAILURE-COVER-AND-CLEANUP") | .executable.unaffected_scope) = "child_A1"' \
        witness-affected-marked-unaffected "witness check failed: WIT-FAILURE-COVER-AND-CLEANUP/unaffected_is_outside_selected_cover"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.identity.activation_scoped_namespace_root.domain_key) = "other_domain"' \
        witness-activation-parent-mismatch "witness check failed: WIT-JOINT-ACTIVATION/activation_id_full_parent_derivation"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.lease.issued_at) = 95' \
        witness-activation-future-intent-cycle "witness check failed: WIT-JOINT-ACTIVATION/slot_intent_lease_binding_acyclic"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.use_cell.states) = ["Settled"]' \
        witness-activation-use-skips-unbound "witness check failed: WIT-JOINT-ACTIVATION/one_way_use_state_from_unbound"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.required_receipt_classes) |= map(select(. != "code"))' \
        witness-shrunk-receipt-class-set "witness check failed: WIT-JOINT-ACTIVATION/receipt_class_schema_fixed"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.receipt_policy.code) = "typed_optional"' \
        witness-required-receipt-downgraded "witness check failed: WIT-JOINT-ACTIVATION/required_receipts_cannot_be_not_applicable"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.receipts.device.reason) = ""' \
        witness-optional-receipt-without-reason "witness check failed: WIT-JOINT-ACTIVATION/typed_optional_receipt_has_reason_and_context"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.lease.budget) = 9' \
        witness-activation-budget-overrun "witness check failed: WIT-JOINT-ACTIVATION/budget_within_cell_and_normalized_horizon"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.cancel_race.distinct_shadow_decision_cell) = true' \
        witness-dual-cancel-decision "witness check failed: WIT-JOINT-ACTIVATION/canonical_cancel_activation_race"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.decision.key) = "arbitrary"' \
        witness-arbitrary-decision-key "witness check failed: WIT-JOINT-ACTIVATION/decision_key_staging_and_retry_bijection"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.decision.staging_generation) += 1' \
        witness-staging-generation-mismatch "witness check failed: WIT-JOINT-ACTIVATION/decision_key_staging_and_retry_bijection"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.decision.valid_gate_before_PreparedInert) = true' \
        witness-valid-gate-before-commit "witness check failed: WIT-JOINT-ACTIVATION/decision_key_staging_and_retry_bijection"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.pre_gate_crash.executable) = true' \
        witness-pre-gate-executable "witness check failed: WIT-JOINT-ACTIVATION/pre_gate_crash_nonexecutable"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.decision.entry_permit_uses) = 2' \
        witness-activation-entry-permit-reuse "witness check failed: WIT-JOINT-ACTIVATION/one_use_entry_permit"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.settlement.states) = ["Settled"]' \
        witness-settlement-skips-inert "witness check failed: WIT-JOINT-ACTIVATION/delivery_settlement_one_way_resume_and_budget"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.settlement.segments[0].resume_sequence) = 1' \
        witness-settlement-resume-skip "witness check failed: WIT-JOINT-ACTIVATION/delivery_settlement_one_way_resume_and_budget"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.delivery.state_after_commit) = "Served"' \
        witness-commit-directly-served "witness check failed: WIT-JOINT-ACTIVATION/commit_is_activated_unserved"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.delivery.remaining_budget) = 5' \
        witness-delivery-budget-mismatch "witness check failed: WIT-JOINT-ACTIVATION/positive_delivery_counts_service"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.delivery.authenticated_post_entry_yield) = true' \
        witness-positive-delivery-smuggles-yield "witness check failed: WIT-JOINT-ACTIVATION/positive_delivery_counts_service"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.settlement.duplicate_service_account_apply) = true' \
        witness-duplicate-settlement-service "witness check failed: WIT-JOINT-ACTIVATION/delivery_retry_and_service_accounting_idempotent"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.zero_delivery.counts_service) = true' \
        witness-zero-delivery-service "witness check failed: WIT-JOINT-ACTIVATION/zero_without_yield_not_service"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.voluntary_yield.hardware_entry_seen) = false' \
        witness-pre-entry-yield-service "witness check failed: WIT-JOINT-ACTIVATION/post_entry_yield_counts_service"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.token_replay.after_settlement_executable) = true' \
        witness-activation-stale-token-replay "witness check failed: WIT-JOINT-ACTIVATION/settled_or_expired_token_replay_rejected"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-JOINT-ACTIVATION") | .executable.failed_validation.failed_activation_slot_id) = "slot_A1"' \
        witness-failed-attempt-reuses-slot "witness check failed: WIT-JOINT-ACTIVATION/failed_validation_expires_attempt_only_without_partial_state"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MANAGEMENT-BOOTSTRAP") | .executable.reserved.execution_cells) = 0' \
        witness-zero-bootstrap-capacity "witness check failed: WIT-MANAGEMENT-BOOTSTRAP/all_bootstrap_resources_positive"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MANAGEMENT-BOOTSTRAP") | .executable.ordinary_borrow_attempt.accepted) = true' \
        witness-management-borrow "witness check failed: WIT-MANAGEMENT-BOOTSTRAP/ordinary_cannot_borrow"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MANAGEMENT-BOOTSTRAP") | .executable.recovery_action.uses_management_execution) = 2' \
        witness-management-overdraw "witness check failed: WIT-MANAGEMENT-BOOTSTRAP/recovery_debits_reserved_capacity"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MANAGEMENT-BOOTSTRAP") | .executable.recovery_action.ordinary_delta) = 1' \
        witness-management-mutates-ordinary "witness check failed: WIT-MANAGEMENT-BOOTSTRAP/ordinary_capacity_unchanged"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MANAGEMENT-BOOTSTRAP") | .executable.bootstrap_root_failure.ordinary_linux_fallback) = true' \
        witness-bootstrap-linux-fallback "witness check failed: WIT-MANAGEMENT-BOOTSTRAP/bootstrap_failure_failstops"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-DISJOINT-COMMIT") | .executable.operation_B.mutable_reads) += ["A"]' \
        witness-commutation-read-conflict "witness check failed: WIT-DISJOINT-COMMIT/write_read_footprints_disjoint"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-DISJOINT-COMMIT") | .executable.operation_A.mutable_reads) = []' \
        witness-commutation-erases-read-footprint "operation mutable-read footprint is empty: operation_A"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-DISJOINT-COMMIT") | .executable.expected_terminal.A) = 4' \
        witness-commutation-terminal-mismatch "witness check failed: WIT-DISJOINT-COMMIT/left_and_right_terminal_equal"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-DISJOINT-COMMIT") | .executable) |= (.operation_A.writes += ["escrow_A"] | .operation_A.set.escrow_A = 0 | .expected_terminal.escrow_A = 0)' \
        witness-commutation-mutates-escrow "witness check failed: WIT-DISJOINT-COMMIT/immutable_escrow_unchanged"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-DISJOINT-COMMIT") | .executable) |= (.initial.ancestor = 0 | .operation_A.writes += ["ancestor"] | .operation_A.set.ancestor = 1 | .expected_terminal.ancestor = 1)' \
        witness-shared-ancestor-write "witness check failed: WIT-DISJOINT-COMMIT/no_shared_ancestor_direct_write"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARENT-SERVICE-CAPACITY") | .executable.frame.slack) = 2' \
        witness-service-parent-overbook "witness check failed: WIT-PARENT-SERVICE-CAPACITY/frame_partition_sum"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARENT-SERVICE-CAPACITY") | .executable.literal_schedule[0]) = "B"' \
        witness-service-reservation-mismatch "witness check failed: WIT-PARENT-SERVICE-CAPACITY/literal_occurrences_equal_reservations"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARENT-SERVICE-CAPACITY") | .executable.dispatches[1].cell) = 0' \
        witness-service-cell-double-dispatch "witness check failed: WIT-PARENT-SERVICE-CAPACITY/one_cell_one_descendant"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-PARENT-SERVICE-CAPACITY") | .executable.dispatches[0].cell) = -1' \
        witness-negative-service-cell "service dispatch cell or child is invalid"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-INDEPENDENT-PROGRESS") | .executable.selected_failure_cover) = "tenant_B"' \
        witness-peer-inside-failure-cover "witness check failed: WIT-INDEPENDENT-PROGRESS/lane_B_outside_selected_cover"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-INDEPENDENT-PROGRESS") | .executable.node_failstop) = true' \
        witness-unnecessary-node-failstop "witness check failed: WIT-INDEPENDENT-PROGRESS/no_node_failstop"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-INDEPENDENT-PROGRESS") | .executable.lane_B.rank_trace[2]) = 3' \
        witness-peer-rank-stutter "witness check failed: WIT-INDEPENDENT-PROGRESS/lane_B_rank_strictly_decreases_on_owned_steps"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-INDEPENDENT-PROGRESS") | .executable.cross_lane_writes) = ["lane_B"]' \
        witness-cross-lane-write "witness check failed: WIT-INDEPENDENT-PROGRESS/no_cross_lane_write"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-INDEPENDENT-PROGRESS") | .executable.lane_A.owned_cells) = [0, 1]' \
        witness-overlapping-lane-cells "witness check failed: WIT-INDEPENDENT-PROGRESS/lane_A_hold_not_in_lane_B_rank"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.entries.A.demand) = 4' \
        witness-mixed-escrow-mismatch "witness check failed: WIT-MIXED-APPLY-FAILURE/each_demand_plus_residual_equals_escrow"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.capacity) = 15' \
        witness-mixed-capacity-loss "witness check failed: WIT-MIXED-APPLY-FAILURE/total_capacity_conserved"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.entries.B.status_writer) = "apply_A"' \
        witness-mixed-two-status-writers "witness check failed: WIT-MIXED-APPLY-FAILURE/one_status_writer_per_entry"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.security_fence_writer.A) = "apply_A"' \
        witness-failure-writes-apply-status "witness check failed: WIT-MIXED-APPLY-FAILURE/failure_scope_writer_distinct"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.expected_successors) = []' \
        witness-mixed-orders-differ "witness check failed: WIT-MIXED-APPLY-FAILURE/orders_have_same_terminal_projection"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-MIXED-APPLY-FAILURE") | .executable.entries.A.status) = "FailedFenced"' \
        witness-mixed-successor-status-erased "witness check failed: WIT-MIXED-APPLY-FAILURE/orders_have_same_terminal_projection"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.opportunities) += [{"id":"old_38","released_turn":38,"preserved":true}]' \
        witness-two-preserved-opportunities "witness check failed: WIT-RETIRING-OPPORTUNITY/at_most_one_preserved"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.opportunities[0].released_turn) = 40' \
        witness-postboundary-preserved "witness check failed: WIT-RETIRING-OPPORTUNITY/preserved_was_preboundary_released"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.token.fence_generation) = 7' \
        witness-token-old-retirement-fence "witness check failed: WIT-RETIRING-OPPORTUNITY/token_binds_current_fence"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.token.opportunity) = "old_38"' \
        witness-token-wrong-preserved-opportunity "witness check failed: WIT-RETIRING-OPPORTUNITY/token_binds_current_fence"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.retirement_fence.release_not_after) = 39' \
        witness-retirement-release-cutoff-drift "witness check failed: WIT-RETIRING-OPPORTUNITY/token_binds_current_fence"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.token.activation_turn) = 45' \
        witness-retiring-activation-after-cutoff "witness check failed: WIT-RETIRING-OPPORTUNITY/activation_within_cutoff"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.reservation.held_until_terminal) = false' \
        witness-retiring-early-release "witness check failed: WIT-RETIRING-OPPORTUNITY/reservation_has_owner_until_terminal"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-RETIRING-OPPORTUNITY") | .executable.old_membership_release_attempts[0].accepted) = true' \
        witness-old-membership-postcutover-release "witness check failed: WIT-RETIRING-OPPORTUNITY/no_post_cutover_old_release"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[0].writer) = "txn_A"' \
        witness-txn-before-source-pending "witness check failed: WIT-SCOPED-FAILURE-CRASH/source_pending_precedes_txn_link"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[3].writer) = "txn_A"' \
        witness-materialization-wrong-writer "witness check failed: WIT-SCOPED-FAILURE-CRASH/materialization_does_not_change_authority"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[1].effective_generation) = 5' \
        witness-generation-before-commit "witness check failed: WIT-SCOPED-FAILURE-CRASH/effective_generation_changes_only_at_commit"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[3].effective_generation) = 6' \
        witness-materialization-authority-change "witness check failed: WIT-SCOPED-FAILURE-CRASH/effective_generation_changes_only_at_commit"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[2].source_state) = "Terminal"' \
        witness-source-terminal-before-commit "witness check failed: WIT-SCOPED-FAILURE-CRASH/source_terminal_after_commit"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.events[-1].audit_positions) = 2' \
        witness-audit-position-remint "witness check failed: WIT-SCOPED-FAILURE-CRASH/one_audit_position"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.crash_recovery_prefixes) |= .[0:5]' \
        witness-missing-crash-prefix "witness check failed: WIT-SCOPED-FAILURE-CRASH/every_prefix_has_fail_closed_recovery"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SCOPED-FAILURE-CRASH") | .executable.lane_B.changed_by_failure_A) = true' \
        witness-scoped-failure-changes-peer "witness check failed: WIT-SCOPED-FAILURE-CRASH/disjoint_lane_unchanged"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.source_namespace.next) = 15' \
        witness-source-wrap-undetected "witness check failed: WIT-SOURCE-EXHAUSTION/exhaustion_detected_before_wrap"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.emergency_transaction.uses_exhausted_namespace) = true' \
        witness-emergency-reuses-exhausted-namespace "witness check failed: WIT-SOURCE-EXHAUSTION/emergency_identity_is_independent"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.emergency_transaction.namespace) = "ordinary_source_namespace"' \
        witness-emergency-namespace-not-independent "witness check failed: WIT-SOURCE-EXHAUSTION/emergency_identity_is_independent"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.dependent_uses.A.token_executable_after_fence) = true' \
        witness-dependent-use-survives-source-fence "witness check failed: WIT-SOURCE-EXHAUSTION/dependent_use_fenced"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.dependent_uses.B.alternate_coverage_preselected) = false' \
        witness-uncovered-peer-survives "witness check failed: WIT-SOURCE-EXHAUSTION/independent_preselected_coverage_survives"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SOURCE-EXHAUSTION") | .executable.alternate_selection_after_failure) = true' \
        witness-retroactive-alternate "witness check failed: WIT-SOURCE-EXHAUSTION/no_retroactive_alternate"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.expected.due_tick_q44) += 1' \
        witness-migration-calendar-arithmetic "witness check failed: WIT-EXCLUSIVE-TRANSFER/due_tick_checked_arithmetic"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.clock_relation.destination_epoch) = 4' \
        witness-migration-clock-epoch-mismatch "witness check failed: WIT-EXCLUSIVE-TRANSFER/clock_relation_binds_both_node_epochs_and_intervals"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.source.zero_active_contexts) = false' \
        witness-source-destination-overlap "witness check failed: WIT-EXCLUSIVE-TRANSFER/source_quiescence_write_close_and_zero_active"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.destination.activation_tick) = 1054' \
        witness-destination-before-source-stop "witness check failed: WIT-EXCLUSIVE-TRANSFER/destination_activation_strictly_after_converted_source_stop"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.destination.cell_for_q44) = 73' \
        witness-migration-wrong-future-cell "witness check failed: WIT-EXCLUSIVE-TRANSFER/destination_cell_is_exact_future_ordinal"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.envelope.not_before) = 1085' \
        witness-migration-before-envelope "witness check failed: WIT-EXCLUSIVE-TRANSFER/activation_after_due_and_envelope_start"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.destination.first_delivery_tick) = 1091' \
        witness-migration-delivery-outside-envelope "witness check failed: WIT-EXCLUSIVE-TRANSFER/first_delivery_inside_envelope_and_due_period"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.destination.terminal_tick) = 1101' \
        witness-migration-terminal-after-period "witness check failed: WIT-EXCLUSIVE-TRANSFER/terminal_before_due_end_and_authority_expiry"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.expected.worst_case_delivery_gap) = 47' \
        witness-migration-gap-not-earliest "witness check failed: WIT-EXCLUSIVE-TRANSFER/worst_case_gap_uses_earliest_converted_last_delivery"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.envelope.maximum_gap) = 47' \
        witness-migration-gap-over-bound "witness check failed: WIT-EXCLUSIVE-TRANSFER/worst_case_gap_within_bound"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.envelope.rank_upper) = 9' \
        witness-migration-rank-over-bound "witness check failed: WIT-EXCLUSIVE-TRANSFER/rank_within_bound"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-EXCLUSIVE-TRANSFER") | .executable.source.debt_after_skip) = 6' \
        witness-migration-debt-regresses "witness check failed: WIT-EXCLUSIVE-TRANSFER/debt_and_ordinal_preserved"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.ring.slots_inspected) = 2' \
        witness-sparse-control-scan "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/selection_cost_constant_not_slot_scan"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.new_insert.cursor_after) = 7' \
        witness-insert-reorders-cursor "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/cursor_stable_on_insert"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.new_insert.slot) = 5' \
        witness-insert-reuses-occupied-slot "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/cursor_stable_on_insert"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.wear.guaranteed_after) = 6' \
        witness-best-effort-spends-guaranteed "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/best_effort_cannot_spend_guaranteed"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.wear.best_effort_after_reject) = 3' \
        witness-best-effort-reject-mints-wear "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/best_effort_cannot_spend_guaranteed"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.wear.refund) = 1' \
        witness-wear-refund "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/wear_nonrefundable"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.wear.renewal_after) = 3' \
        witness-renewal-headroom-spent "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/renewal_headroom_unchanged"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL") | .executable.guaranteed_commit.peer_overtook) = true' \
        witness-guaranteed-overtaken "witness check failed: WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL/selected_guaranteed_not_overtaken"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.watchdog_clock.epoch) = -1' \
        witness-negative-watchdog-epoch "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/clock_sources_and_epochs_are_distinct"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.progress_branch.lease_ticks[1]) = -1' \
        witness-negative-clock-turn "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/all_clock_values_and_bounds_are_natural"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.progress_branch.lease_ticks[1]) = 100' \
        witness-lease-clock-stutter-progress-branch "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/progress_branch_lease_and_watchdog_advance"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.progress_branch.expiry_fired) = false' \
        witness-expiry-does-not-fire "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/expiry_fires_at_boundary"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.stutter_branch.watchdog_turns) = [700,700,700]' \
        witness-watchdog-stutters-with-lease "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/lease_stutter_reaches_independent_watchdog_bound"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.stutter_branch.node_failstop) = false' \
        witness-clock-stutter-continues "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/stutter_branch_fences_and_failstops"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-CLOCK-PROGRESS-OR-FAILSTOP") | .executable.stutter_branch.time_bounded_liveness_claimed_after_failstop) = true' \
        witness-liveness-after-failstop "witness check failed: WIT-CLOCK-PROGRESS-OR-FAILSTOP/liveness_withdrawn_after_failstop"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.successor.lease_clock_epoch) = 31' \
        witness-prefix-clock-epoch-alias "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/prefix_clock_relation_binds_epochs_and_interval"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.prefix_branch.certificate.prefix_position) = 89' \
        witness-prefix-before-write-close "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/prefix_follows_write_close_and_quorum_checkpoint"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.prefix_branch.certificate.quorum_replicated) = false' \
        witness-unreplicated-prefix "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/prefix_follows_write_close_and_quorum_checkpoint"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.prefix_branch.certificate.next_ordinal) = 45' \
        witness-prefix-state-gap "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/prefix_branch_preserves_exact_state"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.successor.maximum_gap) = 47' \
        witness-prefix-gap-over-bound "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/prefix_branch_gap_theorem_holds"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.loss_branch.successor_stream_incarnation) = 9' \
        witness-loss-without-incarnation-advance "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/missing_prefix_advances_incarnation"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.loss_branch.exactly_once_claim) = true' \
        witness-continuity-claim-after-loss "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/loss_branch_withdraws_continuity_claims"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS") | .executable.loss_branch.continuity_loss_record.uncertain_ordinal_range) = [44,43]' \
        witness-reversed-uncertain-range "witness check failed: WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS/uncertain_old_range_is_nonservice"

json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-LIFECYCLE-WRITER-REFINEMENT") | .executable.service_trace) = ["Released", "Served"]' \
        witness-lifecycle-released-direct-served "witness check failed: WIT-LIFECYCLE-WRITER-REFINEMENT/trace_edges_allowed"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-LIFECYCLE-WRITER-REFINEMENT") | .executable.human_to_machine.Released) = []' \
        witness-lifecycle-missing-preimage "witness check failed: WIT-LIFECYCLE-WRITER-REFINEMENT/every_machine_state_has_human_preimage"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-LIFECYCLE-WRITER-REFINEMENT") | .executable.human_to_machine.Cleanup) = []' \
        witness-lifecycle-empty-cleanup-refinement "witness check failed: WIT-LIFECYCLE-WRITER-REFINEMENT/every_machine_state_has_human_preimage"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-LIFECYCLE-WRITER-REFINEMENT") | .executable.human_to_machine) |= (.Preparing += ["ActivatedUnserved"] | .Activated = ["Served"])' \
        witness-lifecycle-erases-unserved "witness check failed: WIT-LIFECYCLE-WRITER-REFINEMENT/activated_unserved_distinct_from_served"
json_mutation "$WITNESS" '(.scenarios[] | select(.id == "WIT-LIFECYCLE-WRITER-REFINEMENT") | .executable.failure_writer_events) |= reverse' \
        witness-writer-order-reversed "witness check failed: WIT-LIFECYCLE-WRITER-REFINEMENT/source_pending_precedes_transaction_link"

# Human parity, protocol ordering, and immutable supporting artifacts.
perl -0pi -e 's/^FailureEventExceedsKFailureScopesWithoutCanonicalCover\n//m' "$TMP/$HUMAN"
expect_reject human-negative-parity "human/machine negative inventory or order differs"
perl -0pi -e 's/Network silence is never quiescence/Network delay is ambiguous/' "$TMP/$HUMAN"
expect_reject human-critical-phrase "human contract omits critical phrase"
perl -0pi -e 's/## Witness 17:/## Witness 18:/' "$TMP/$WITNESS_HUMAN"
expect_reject human-witness-numbering "witness Markdown numbering is incomplete"
json_mutation "$ASSURANCE" '.ordering[-1] = "premature_tla"' \
        assurance-order "assurance/TLA order changed"
json_mutation "$ASSURANCE" '.trust_chain.repository_trust_discovery_or_TOFU_allowed = true' \
        assurance-tofu "critical architecture value changed"
json_mutation "$ASSURANCE" '.campaign_log.policy_checkpoint_precedes_candidate_by_verified_tree_size_and_consistency_proof = false' \
        assurance-policy-after-candidate "critical architecture value changed"
json_mutation "$ASSURANCE" '.campaign_log.terminal_checkpoint_extends_policy_and_commitment_checkpoints_by_verified_consistency_proofs = false' \
        assurance-forked-terminal-checkpoint "critical architecture value changed"
json_mutation "$ASSURANCE" '.campaign_log.one_terminal_submission_per_assignment = false' \
        assurance-sibling-submission "critical architecture value changed"
json_mutation "$ASSURANCE" '.campaign_log.signed_rejection_is_absorbing = false' \
        assurance-rejection-not-absorbing "critical architecture value changed"
json_mutation "$ASSURANCE" '.candidate_storage.local_mode_bit_read_only_is_WORM_or_publication_evidence = true' \
        assurance-local-mode-is-worm "critical architecture value changed"
json_mutation "$ASSURANCE" '.candidate_storage.real_freeze_requires_external_retention_attestation = false' \
        assurance-no-retention-attestation "critical architecture value changed"
json_mutation "$ASSURANCE" '.semantic_validation.real_mode_executes_repository_or_candidate_supplied_program = true' \
        assurance-executes-candidate "critical architecture value changed"
json_mutation "$ASSURANCE" '.semantic_validation.startup_environment_network_clock_randomness_dynamic_loader_and_unpinned_plugins_available = true' \
        assurance-nondeterministic-runner "critical architecture value changed"
json_mutation "$ASSURANCE" '.semantic_validation.required_matching_receipts = "1_of_1"' \
        assurance-single-runner "semantic runner threshold changed"
json_mutation "$ASSURANCE" '.review_commit_reveal.all_four_commitments_checkpointed_before_any_reveal = false' \
        assurance-reveal-before-commitment-set "critical architecture value changed"
json_mutation "$ASSURANCE" '.predecessor_history.real_campaign_requires_every_claimed_predecessor_checkpointed = false' \
        assurance-unpublished-history "critical architecture value changed"
json_mutation "$ASSURANCE" '.result_provenance.downstream_consumer_must_exactly_pin_complete_tuple = false' \
        assurance-incomplete-provenance "critical architecture value changed"
json_mutation "$ASSURANCE" '.result_provenance.accepted_preformal_freeze_sets_tla_written_model_checked_or_tla_proved = true' \
        assurance-freeze-implies-proof "critical architecture value changed"
json_mutation "$ASSURANCE" '.fixture.exact_schema_and_signature_prefix = "linux-cap.archfreeze.v2"' \
        assurance-fixture-namespace-confusion "fixture namespace changed"
json_mutation "$ASSURANCE" '.fixture.valid_accept_result.architecture_frozen = true' \
        fixture-claims-freeze "fixture ACCEPT/REJECT result boundary changed"
json_mutation "$ASSURANCE" '.claims.real_candidate_sealed = true' \
        assurance-real-evidence-overclaim "assurance protocol claims real evidence"
perl -0pi -e 's/"architecture_frozen": False/"architecture_frozen": True/' "$TMP/$ASSURANCE_VERIFIER"
expect_reject assurance-fixture-claim-ceiling \
        "fixture verifier can emit architecture_frozen=true"
perl -0pi -e 's/start_new_session=True/start_new_session=False/' "$TMP/$ASSURANCE_VERIFIER"
expect_reject assurance-no-process-group \
        "assurance fixture hardening missing: start_new_session=True"
perl -0pi -e 's/import sys/import sys\nimport json/' "$TMP/$ASSURANCE_REAL_STUB"
expect_reject assurance-real-stub-parses-evidence \
        "real assurance stub can parse or fetch evidence"
perl -0pi -e 's/return EXIT_UNIMPLEMENTED/return 0/' "$TMP/$ASSURANCE_REAL_STUB"
expect_reject assurance-real-stub-authorizes-success \
        "real assurance stub did not reject before evidence parsing"
printf '\nmutated\n' >>"$TMP/$R1_HUMAN"
expect_reject pinned-r1-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$R2_HUMAN"
expect_reject pinned-r2-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$R3_HUMAN"
expect_reject pinned-r3-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$ASSURANCE_HUMAN"
expect_reject pinned-assurance-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$DC_HUMAN"
expect_reject pinned-dc-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$R4_HUMAN"
expect_reject pinned-r4-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$ASSURANCE_R4_HUMAN"
expect_reject pinned-assurance-r4-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$R5_HUMAN"
expect_reject pinned-r5-human "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$PLAN"
expect_reject pinned-plan "candidate artifact changed without validator review"
printf '\nmutated\n' >>"$TMP/$ADR"
expect_reject pinned-adr "candidate artifact changed without validator review"

rm "$TMP/$WITNESS"
ln -s "$ROOT/$WITNESS" "$TMP/$WITNESS"
expect_reject witness-symlink "must be a non-symlink regular file"
json_mutation "$CONTRACT" '.preformal_two_lane_witness = "../../etc/passwd"' \
        witness-path-traversal "witness path changed"

printf 'dynamic residency architecture candidate: PASS\n'
printf 'hostile mutations rejected by intended gates: %d\n' "$MUTATIONS"
if [[ -n "$START_AT" && $START_REACHED -eq 0 ]]; then
        printf 'FAIL: START_AT mutation was not found: %s\n' "$START_AT" >&2
        exit 1
fi
printf 'architecture_frozen=false; tla_written=false; protection_evidenced=false\n'
