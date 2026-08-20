#!/usr/bin/env python3
"""Validate the exact pre-formal RESIDENCY-DYN architecture candidate.

This is an internal consistency and drift gate. It cannot authenticate review
identity, freeze the architecture, prove a TLA+ model, or evidence protection.
External freeze assurance is validated by the separate v2 assurance verifier.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from typing import Any


CONTRACT_REL = Path(
    "capsched-models/analysis/"
    "dynamic-admission-recurring-residency-architecture-contract-v1.json"
)
ANALYSIS_PREFIX = Path("capsched-models")
EXPECTED_ID = "dynamic-admission-recurring-residency-architecture-contract-v1"
EXPECTED_REQUIREMENT = "RESIDENCY-DYN-001"
EXPECTED_STATUS = "architecture_candidate_pending_adversarial_freeze"
EXPECTED_LINUX_COMMIT = "74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f"
EXPECTED_LINUX_TREE = "54f685aad94f28f0027cbba18cf5e29aadce234a"

EXPECTED_TOP_KEYS = set("""
activation_composition_interface admission admission_snapshot_excludes
admission_snapshot_fields alternative_analysis analysis
architecture_freeze_candidate assurance_v2_hostile_review
authoritative_generation_allocation
authority_stop_vs_cleanup binding_authority_key bound_units cancellation claims
clock_bridge coalescing commit_dependency_vector control_operation
control_work_conservation datacenter_composition_boundary_review date
deferred_choices domain_identity external_assurance_protocol external_relies
fairness_not_assumed feasibility_witness_requires finite_resources
first_reference_contract formal_decomposition formalization_order
formalization_rule fourth_hostile_counterexample_review
fifth_hostile_architecture_review
future_drift_watch_groups global_placement_authority normalized_authority_horizons
guaranteed_contract_minimum_fields hotplug_rollback id implementation_selected
impossibility_boundaries internal_liveness_obligations lease_horizon_rule
linux_behavior_change_approved linux_lifetime_boundary linux_projection_adapter
linux_source_constraints linux_source_identity linux_untrusted
logical_physical_identity maintenance management_recovery_bootstrap monitor_owned
monitor_restart namespace_renewal namespace_scope_and_allocator negative_cases
next_step node_config_and_hierarchy node_lease_identity node_lease_import
node_mode normative_term object_types opportunity_accounting opportunity_identity
opportunity_lifecycle overflow plan_membership pre_freeze_review_disposition
preformal_two_lane_witness projection_renewal protected_service_capacity
refinement_obligations request_identity_rules request_terminal_dispositions
requirement residency_transaction_state retiring_authority_use
root_execution_capacity root_plan safe_recurring_liveness_witness safety
scale_contract schema_version scope second_hostile_review_disposition
semantic_stability snapshot_identity_rule status stream_ledger stream_renewal
third_hostile_review_disposition threat_model trusted_lease_clock v1_work_frame
version_representation version_spaces work_isolation work_lanes work_record
""".split())

EXPECTED_OBJECT_TYPES = """
DomainKey NodeConfig DomainHierarchyCertificate NodeLeaseImportCertificate
GlobalPlacementUse QuorumSupersessionFence NodeLease LeaseAuthorityRecord
LeaseAttestation FrozenLeaseUse LeaseFence LocalRejectFence
SecurityDependencyCertificate SecurityScopeFence SecurityUseVector
SourceReplayCell ScopeTransitionTxn ScopeAuthorityCell AuthorityAuditOutbox
SecurityAuditShard AuditReceipt CheckpointAggregate SecurityLogRecord
ClockBridgeAuthorityRecord ClockBridgeCertificate HardwareCapacityRootCertificate
HardwareProgressCertificate ServiceAllocationCertificate TargetControlReservation
TargetLaneQuotaAnchor ControlServiceReservation RootExecutionAllocationCertificate
ControlOp ConflictIntentReservation CommitDeltaTemplate DelegationScope
MutationFootprint CommitDependencyVector AdmissionContract AdmissionSnapshot
StreamLedger StreamSuccessorRecord PlanMembership PlanTransitionRecord
PlanTransitionApplyLedger ApplyCell EntryFailClosedFence EscrowReclaimCell
RetiringOpportunityReservation PlacementTransferRecord ServiceCalendar
CalendarTransferRecord SourcePlacementQuiescenceReceipt
SettlementPrefixCertificate ContinuityLossRecord BindingAuthorityKey
AuthorityUseID BestEffortAuthorityUseID RetirementFence TrustedLeaseClock
CurrentOpportunity MaintenanceSkipRecord RootPlanShard ResidencyObligation
ResidencyRequest PhysicalResidencyTxn ResidencyWorkReservation
NamespacePublicationReservation ResidentBinding PhysicalOccurrenceID
ExecutionCellLease ExecutionCellUseCell ActivationSlotID ActivationIntent
ActivationDecisionCell DeliverySettlementCell NormalizedAuthorityHorizonVector
ClockRelationCertificate IndependentWatchdog ExecutionContextKey
ActivationCommitReceipt ExecutionDeliveryReceipt RequiredQuiescenceReceiptSet
ActivationID RunToken BootFreshnessRoot ReconciliationRoot
ReconciliationSnapshot IssuerReconciliationAck DirtyArmReceipt
ScopedNamespaceRoot FailureEvent FailureSourceIdentity FailureSourceEvidence
FailureScopeIdentity FailureClosureSnapshot FailureCoverCertificate
SourceFailureReceiptID
SourceFailureReceipt FailureReceipt AuthorityRetireReceipt RecoveryReceipt
QuiescenceReceipt ManagementRecoveryBootstrapContract NodeMode
ContractOperationalState ReplayAndRetirementState LinuxProjection
""".split()

EXPECTED_VERSION_SPACES = """
ClusterIssuerIncarnation GlobalAuthorityEpoch NodeConfigGeneration
DomainHierarchyGeneration DomainEpoch LocalAuthorityGeneration
LocalLeaseFenceGeneration NodeLeaseID NodeLeaseEpoch NodeLeaseImportGeneration
LeaseTermGeneration LeaseAttestationID AdmissionID AdmissionIncarnation
AdmissionGeneration ServiceStreamID ServiceStreamIncarnation
ServiceContractGeneration DescriptorIncarnation ResidencyDescriptorGeneration
PlanShardID PlanNamespaceEpoch RootPlanEpoch PlanMembershipGeneration
OpportunitySequence RequestNamespaceEpoch ControlNamespaceEpoch
CancelNamespaceEpoch WorkNamespaceEpoch ControlOpSequence CancelOpSequence
ResidencyRequestSequence WorkSequence SourceFailureNamespaceEpoch
SourceFailureSequence FailureEventSequence ScopeTransitionNamespaceEpoch
ScopeTransitionSequence ScopeTransitionGeneration SourceReplayGeneration
SourceHealthGeneration FailureScopeGeneration ControlOpID CancelOpID
ResidencyRequestID WorkID DirectoryLayoutEpoch ProjectionEpoch CpuIncarnation
SlotGeneration ActivationNamespaceEpoch MonitorBootEpoch NodeSecurityEpoch
ReconciledEpoch DirtyArmGeneration RetirementFenceGeneration
MembershipGeneration DispositionGeneration DrainGeneration
QuiescenceNamespaceEpoch FailureNamespaceEpoch ScopedNamespaceRootGeneration
ActivationGeneration ActivationIntentGeneration ExecutionContextGeneration
ActivationCommitGeneration PlacementIncarnation PlacementGeneration
QuorumEpoch GlobalPlacementOwnershipEpoch GlobalPlacementFencingToken
RootExecutionClockEpoch RootExecutionTurn RootExecutionAllocationGeneration
ServiceOpportunityClockEpoch ServiceOpportunityTurn HardwareProgressGeneration
ServiceAllocationGeneration LaneClockEpoch LaneTurn ControlClockEpoch ControlTurn
TargetControlReservationGeneration TargetControlTurn LeaseClockEpoch LeaseTick
WatchdogEpoch WatchdogTurn
BridgeCertificateGeneration SecurityLogNamespaceEpoch SecurityLogSequence
AuditReceiptGeneration CheckpointAggregateGeneration FailureCoverGeneration
ManagementBootstrapGeneration
""".split()

EXPECTED_MODELS = [
    "DYN_ADMIT", "DYN_REQUEST", "DYN_CHURN", "DYN_SHARD",
    "DYN_RENEW_RESTART", "DYN_COMPOSE", "DYN_MULTILANE_COMPOSE",
    "DYN_LIVENESS_THEOREM", "DYN_REGRESSION",
]
EXPECTED_PROOF_ORDER = [
    "ENV_HARDWARE_TIME_ROOT",
    "ENV_CLUSTER_ISSUER_QUORUM_TIME",
    "ENV_ENTRY_CODE_STATE_INTERFACE",
    "RESOURCE_HIERARCHY_SET_ALGEBRA",
    "DYN_ADMIT",
    "DYN_REQUEST",
    "DYN_CHURN",
    "DYN_RENEW_RESTART",
    "DYN_SHARD",
    "DYN_COMPOSE",
    "DYN_MULTILANE_COMPOSE",
    "PER_OPPORTUNITY_RANK_THEOREM",
    "DYN_LIVENESS_THEOREM",
    "DYN_REGRESSION",
]
EXPECTED_PROOF_PREDECESSORS = {
    "ENV_HARDWARE_TIME_ROOT": [],
    "ENV_CLUSTER_ISSUER_QUORUM_TIME": [],
    "ENV_ENTRY_CODE_STATE_INTERFACE": [],
    "RESOURCE_HIERARCHY_SET_ALGEBRA": [
        "ENV_CLUSTER_ISSUER_QUORUM_TIME",
    ],
    "DYN_ADMIT": [
        "ENV_CLUSTER_ISSUER_QUORUM_TIME",
        "RESOURCE_HIERARCHY_SET_ALGEBRA",
    ],
    "DYN_REQUEST": ["DYN_ADMIT"],
    "DYN_CHURN": ["ENV_HARDWARE_TIME_ROOT", "DYN_ADMIT"],
    "DYN_RENEW_RESTART": [
        "ENV_HARDWARE_TIME_ROOT",
        "ENV_CLUSTER_ISSUER_QUORUM_TIME",
        "DYN_CHURN",
    ],
    "DYN_SHARD": [
        "RESOURCE_HIERARCHY_SET_ALGEBRA",
        "DYN_CHURN",
        "DYN_RENEW_RESTART",
    ],
    "DYN_COMPOSE": [
        "ENV_ENTRY_CODE_STATE_INTERFACE",
        "RESOURCE_HIERARCHY_SET_ALGEBRA",
        "DYN_ADMIT",
        "DYN_REQUEST",
        "DYN_CHURN",
        "DYN_RENEW_RESTART",
        "DYN_SHARD",
    ],
    "DYN_MULTILANE_COMPOSE": ["DYN_SHARD", "DYN_COMPOSE"],
    "PER_OPPORTUNITY_RANK_THEOREM": ["DYN_MULTILANE_COMPOSE"],
    "DYN_LIVENESS_THEOREM": ["PER_OPPORTUNITY_RANK_THEOREM"],
    "DYN_REGRESSION": [
        "DYN_MULTILANE_COMPOSE",
        "DYN_LIVENESS_THEOREM",
    ],
}
EXPECTED_PROOF_CLASSES = {
    "ENV_HARDWARE_TIME_ROOT": "external_interface",
    "ENV_CLUSTER_ISSUER_QUORUM_TIME": "external_interface",
    "ENV_ENTRY_CODE_STATE_INTERFACE": "external_interface",
    "RESOURCE_HIERARCHY_SET_ALGEBRA": "structural_lemma",
    **{name: "executable_model" for name in EXPECTED_MODELS
       if name not in {"DYN_LIVENESS_THEOREM", "DYN_REGRESSION"}},
    "PER_OPPORTUNITY_RANK_THEOREM": "inductive_theorem",
    "DYN_LIVENESS_THEOREM": "inductive_theorem",
    "DYN_REGRESSION": "regression_gate",
}
EXPECTED_TEMPORAL_RELIES = {
    "ENV_HARDWARE_TIME_ROOT": [],
    "ENV_CLUSTER_ISSUER_QUORUM_TIME": [],
    "ENV_ENTRY_CODE_STATE_INTERFACE": [],
    "RESOURCE_HIERARCHY_SET_ALGEBRA": [],
    "DYN_ADMIT": [],
    "DYN_REQUEST": [],
    "DYN_CHURN": [
        "AuditHeadroomWindow",
        "ProtectedClockProgressOrFailStop",
    ],
    "DYN_RENEW_RESTART": ["ProtectedClockProgressOrFailStop"],
    "DYN_SHARD": [],
    "DYN_COMPOSE": [],
    "DYN_MULTILANE_COMPOSE": [],
    "PER_OPPORTUNITY_RANK_THEOREM": [
        "StableWindow",
        "AuditHeadroomWindow",
        "ProtectedClockProgressOrFailStop",
    ],
    "DYN_LIVENESS_THEOREM": [
        "StableWindow",
        "AuditHeadroomWindow",
        "ProtectedClockProgressOrFailStop",
    ],
    "DYN_REGRESSION": [],
}
EXPECTED_CONDITIONAL_OMEGA_RELIES = {
    **{name: [] for name in EXPECTED_PROOF_ORDER},
    "DYN_LIVENESS_THEOREM": ["InfiniteFreshnessSupply"],
}
EXPECTED_DISCHARGE_STATES = {
    "ENV_HARDWARE_TIME_ROOT":
        "pending_separate_hardware_time_root_refinement",
    "ENV_CLUSTER_ISSUER_QUORUM_TIME":
        "pending_separate_cluster_issuer_quorum_time_refinement",
    "ENV_ENTRY_CODE_STATE_INTERFACE":
        "pending_separate_entry_code_state_refinement",
    "RESOURCE_HIERARCHY_SET_ALGEBRA": "pending_formal_structural_proof",
    **{name: "pending_tla_and_refinement_validation" for name in EXPECTED_MODELS
       if name not in {"DYN_LIVENESS_THEOREM", "DYN_REGRESSION"}},
    "PER_OPPORTUNITY_RANK_THEOREM": "pending_inductive_rank_proof",
    "DYN_LIVENESS_THEOREM": "pending_infinite_induction_proof",
    "DYN_REGRESSION": "pending_negative_model_validation",
}
EXPECTED_DERIVED = [
    "Feasible", "LeaseValidForNewRelease", "LeaseValidForFrozenUse",
    "AdmissionUsable", "BindingAuthorityKeyOf", "CanonicalFailureCover",
    "RequiredQuiescenceReceiptSetOf", "ActivatedFromActivationCommitReceipt",
    "ServedFromExecutionDeliveryReceipt", "EffectiveAuthorityHorizon",
    "NormalizedAuthorityHorizonVectorValid", "ExecutionCellEligible",
    "TokenExecutable", "ActiveContextExecutable",
    "FailureImpactLeastFixedPoint", "CandidateDeltaConfinedToDelegation",
    "StableState", "NodeModeSummary",
    "FailureReceiptValid", "QuiescenceReceiptValid",
    "ReconciliationAckValid", "ClockBridgeInvariant", "RankEligible",
]
EXPECTED_SCENARIOS = [
    "WIT-HIERARCHY-BOUNDS", "WIT-ROOT-EXECUTION-CAPACITY",
    "WIT-TARGET-CONTROL-CONSERVATION", "WIT-PARTITION-IMPORT",
    "WIT-GLOBAL-PLACEMENT-SUPERSESSION",
    "WIT-FAILURE-COVER-AND-CLEANUP", "WIT-JOINT-ACTIVATION",
    "WIT-MANAGEMENT-BOOTSTRAP", "WIT-DISJOINT-COMMIT",
    "WIT-PARENT-SERVICE-CAPACITY", "WIT-INDEPENDENT-PROGRESS",
    "WIT-MIXED-APPLY-FAILURE", "WIT-RETIRING-OPPORTUNITY",
    "WIT-SCOPED-FAILURE-CRASH", "WIT-SOURCE-EXHAUSTION",
    "WIT-EXCLUSIVE-TRANSFER", "WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL",
    "WIT-CLOCK-PROGRESS-OR-FAILSTOP",
    "WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS",
    "WIT-LIFECYCLE-WRITER-REFINEMENT",
]
EXPECTED_OWNERS = {
    "NodeConfig": "protected_boot_root",
    "DomainHierarchyCertificate_A_or_B": "hierarchy_commit_owner",
    "HardwareCapacityRootSchedule_and_ExecutionCellLeases":
        "root_execution_capacity_owner",
    "ExecutionCellUseCell_A_or_B": "exact_physical_context_activation_shard",
    "TargetControlTurn_A_or_B": "exact_target_microstep_dispatch",
    "NodeLeaseImportCertificate_and_GlobalPlacementUse":
        "external_authenticated_issuer_or_quorum",
    "ClockRelationCertificate":
        "external_authenticated_clock_relation_producer",
    "NormalizedAuthorityHorizonVector": "protected_deadline_normalizer",
    "IndependentWatchdog": "independent_hardware_watchdog",
    "FailureClosureSnapshot": "protected_failure_cover_owner",
    "FailureCoverCertificate": "protected_failure_cover_owner",
    "ActivationIntent": "lane_prepare_owner",
    "ActivationDecisionCell": "exact_physical_context_activation_shard",
    "DeliverySettlementCell": "exact_physical_context_activation_shard",
    "ExecutionContextKey_and_ActivationCommitReceipt":
        "exact_physical_context_activation_shard",
    "ManagementRecoveryBootstrapContract": "protected_boot_root",
}

EXPECTED_CLAIMS = {
    "architecture_contract_written": True,
    "adversarial_semantic_freeze_complete": False,
    "tla_written": False,
    "model_checked": False,
    "claim_specific_capsule_validated": False,
    "residency_dynamic_model_supported": False,
    "linux_behavior_changed": False,
    "monitor_implemented": False,
    "protection_evidenced": False,
    "performance_evidenced": False,
    "cost_efficiency_evidenced": False,
    "multi_cluster_evidenced": False,
    "deployment_ready": False,
}

EXPECTED_R3_IDS = (
    [f"SEC-R3-{i:02d}" for i in range(1, 5)]
    + [f"FORM-R3-{i:02d}" for i in range(1, 8)]
    + [f"SCALE-R3-{i:02d}" for i in range(1, 4)]
    + [f"INT-R3-{i:02d}" for i in range(1, 7)]
)
EXPECTED_R3_SELF_IDS = [f"SELF-R3-{i:02d}" for i in range(1, 14)]
EXPECTED_DC_IDS = [f"DC-R3X-{i:02d}" for i in range(1, 9)]
EXPECTED_R4_IDS = [
    "R4-EXEC-01", "R4-EXEC-02", "R4-SVC-01", "R4-ACT-01",
    "R4-PLACE-01", "R4-PLACE-02", "R4-MIG-01", "R4-FAIL-01",
    "R4-FAIL-02", "R4-FAIL-03", "R4-MODE-01", "R4-CAP-01",
    "R4-ACT-02", "R4-CLOCK-01", "R4-LIFE-01", "R4-VAL-01",
]
EXPECTED_R5_IDS = [
    "R5-EXEC-01", "R5-CLOCK-01", "R5-ID-01", "R5-SLOT-01",
    "R5-ACT-01", "R5-ACT-02", "R5-FAIL-01", "R5-SVC-01",
    "R5-VAL-01", "R5-LIVE-01", "R5-FORMAL-01", "R5-CLOCK-02",
    "R5-LIVE-02", "R5-FAIL-02", "R5-PLACE-01", "R5-MIG-01",
    "R5-BOUNDARY-01", "R5-CAP-01", "R5-PLAN-01",
]
EXPECTED_ASSURANCE_R4_IDS = (
    [f"ASSURE-R4-{i:02d}" for i in range(1, 12)]
    + [f"ASSURE-R5-{i:02d}" for i in range(1, 10)]
)
INTEGRATED_OPEN_STATUS = (
    "open_redesign_integrated_validator_complete_pending_fresh_review_and_formal_refinement"
)

REGISTRY_FIELDS = {
    "kind", "allocator_class", "owner_scope_class", "parents",
    "exhaustion_action", "exhaustion_scope_class", "may_advance_boot",
}
REGISTRY_KINDS = {
    "external_root", "external_sequence", "fixed_slot",
    "scoped_incarnation", "publication_sequence", "derived_identity",
    "protected_sequence", "fence_sequence", "trusted_clock_epoch",
    "trusted_clock_counter", "boot_configuration_incarnation",
    "authenticated_import_sequence", "external_fence_sequence",
}

# Filled from the reviewed candidate. These are drift pins, not independent
# review or freeze evidence.
EXPECTED_SECTION_DIGESTS: dict[str, str] = {
    'activation_composition_interface': '329516fb0e5b16d3bf2e1099008211f7833974e1758ec10a2815c4f5300a81ee',
    'admission': '416ea546adb9546517a667fc6e96e41f0c65e1fe1236433224285912284143a3',
    'admission_snapshot_excludes': '6ea5cf54dd8352674e58d1c8af304d167b5ad7c5af5108705926c0032e41f2a2',
    'admission_snapshot_fields': '5a47878e7eeae4c015d0af3e6fe90bf64f112aadbb2ff3e682a69ab622acb3fc',
    'alternative_analysis': '2cd7170e06d072f286af3bb9a6ec6fd6f1de24cd7ae6290006259e8b95a8007d',
    'analysis': '7156e9644ba7b68eb39121019a8afb284ae54bb93334e38d2d96cd6e56e6c2da',
    'architecture_freeze_candidate': '05b96674c289bb99e0bdedc77b045289a097a14ccf32294e1b3e97d8360913ad',
    'assurance_v2_hostile_review': '2c59fa0fc9831095fa06ced86af32b78fe666463c9a15221dfb8a45ba4ef516d',
    'authoritative_generation_allocation': 'a6ca7b0eea798a44f496178012c45b37c1da6dba2c59619effcd88e279a6d90a',
    'authority_stop_vs_cleanup': '3f10c07da4fcc8fc7034c7ad3b1d98db758599ce37cf2d4016e144827c624ef8',
    'binding_authority_key': 'ace7c0b7c0e9dbc14b5004aca923fbf31e41f22e8f389a63e3eaaa3825733bab',
    'bound_units': '1ced11a0a6af229ea9960eb8aebd1bab1def7aa5470959dbf6b318c453c0affa',
    'cancellation': '0ddaa3303bd762a4a84200cef031fb767565131636cc58c228893fdf6e7bd2dd',
    'claims': '358354c32171ac9639e610a7af289aa4f84cf18d670798296ec89d313127215c',
    'clock_bridge': '2d523b28b77f534e15bd80d2548cf68291a7c59280cdf62f0bd45cfb1263b885',
    'coalescing': '6645df5ca8a2589c431a82ec562e17429ff4287305f6d45e0db917829c6102ba',
    'commit_dependency_vector': 'ce350e255ab1d2d63f588b33f27ad20258a236dcee5d682abd7029d302f25f34',
    'control_operation': '63dda13359961fff9e218e8d3fe39d91208e3b038dcab247caf207e4de8cdf0e',
    'control_work_conservation': '931eafb75ffee00c08b478ff051a6d6adcf190f41dfbd2ad8550cad755277ba3',
    'datacenter_composition_boundary_review': '693de778e01dda4c321f52926855c44d337d7bc4221654c882ff7f75d6bec2ac',
    'date': 'ccaa1ec850310ada8a84279df3d48c8880b6fc88bf48476123a32efc82bee215',
    'deferred_choices': '59456c6f203b89cecd2079fa5fe729b4d7975293e0f15658212781bffb3bf1ed',
    'domain_identity': '87bd23c710926bcc2ab8cc32f23d40a846fab5fe4479260faea03b7e344f9438',
    'external_assurance_protocol': '3782715b80baf321731e4bcc675c147adccdccf758014d861549a3a1a32181cb',
    'external_relies': '9b21e0263d502ba13ffd1e36cec845d1d71962a00f359ffdbb05293795493491',
    'fairness_not_assumed': '0e93920742ead8452b9e512a748874a1180835057c919e60a31323d88f0c9a22',
    'feasibility_witness_requires': '6eacf6f78dc55548886f925b90f00e3be048eda9f72af329318939178e420b05',
    'fifth_hostile_architecture_review': '410b1f1c4d894991fcceb83ebccd4c8c581d1574b7fe752b684b12bdd0bc33e8',
    'finite_resources': '3d6b18578c620ba65bc075bcf97093ef779592f63478b5e17b2a73ef5d48203a',
    'first_reference_contract': 'dca4fab383ce856db9302ad248a2606529d1675cb1da7891aec4893b722027fd',
    'formal_decomposition': '1d84f4959bcf10584db82fd93225853dd6839611e3807bb12d6d86f3e2df2bb2',
    'formalization_order': '60e90095c32cbbd7992dd8f53d387dc22e9d6b77a4d03ad9aae7013b91a0234d',
    'formalization_rule': 'e9064261823bd3d88dbd25a5c0409c15564e3461ff7ebca797051cf6b07b070d',
    'fourth_hostile_counterexample_review': '45bced141410b6f46f274797d0bea4f2688f39b0fb7ead60ab07aefe9c5c1044',
    'future_drift_watch_groups': '2a83d74a718777a77c96f22272edc5801f469a54271db9773a8558f24a409aa1',
    'global_placement_authority': '00644b573986faf71ee8bea605bcdaf971d286ef83228ff09422fed909751133',
    'guaranteed_contract_minimum_fields': '26ba826b93e8c42e97dcd5e453f87b6b3b3114bf06fe117661973d812d901146',
    'hotplug_rollback': '68d4aa266a3b6d74012b3690b6c008cf7d64dae8f3b4aeeda5a894c040c0f61b',
    'id': 'd5ced31ac9e6e95d198dc2066924bab21ae34c3a6e1a9e77ae2a007c05246f1b',
    'implementation_selected': 'fcbcf165908dd18a9e49f7ff27810176db8e9f63b4352213741664245224f8aa',
    'impossibility_boundaries': '2325e32dbe5d6940575b67d075ff7ed6d119c842ca66d81d04ff182209be046e',
    'internal_liveness_obligations': 'd687b2033edcb8fe6d6996ee5918dde45778aeb7e5489ccc70879b10f276b23d',
    'lease_horizon_rule': '82e302814d525bc445f34a0dc8519b6a6d11244d01ffc209a3dce4d88b81b877',
    'linux_behavior_change_approved': 'fcbcf165908dd18a9e49f7ff27810176db8e9f63b4352213741664245224f8aa',
    'linux_lifetime_boundary': 'e38371f230c3a42354128f7c12e369abd4a39b88c2782690a397204c64272285',
    'linux_projection_adapter': 'f6cee5ea3d4510f65a104f2f7570b5197e1a50c9c670e5f3b4741166ffe5b37f',
    'linux_source_constraints': '8367d1bb3dca27d5afc9a5ce6f103cb220cde11d5d0c5ddc5a268b94b4f21a8d',
    'linux_source_identity': '3316d9039008679a5c7efd29c6161f513884d3c3fbb3f7e9be6efb4183e92be6',
    'linux_untrusted': 'b1c5ab807acef8a9dcd77a43bf31b54f87a579dd4f399a556b7434bcdbcac590',
    'logical_physical_identity': 'cd3cdf2732b05e37cb18ec04d686afa96a689906208f7092e90e3ba14e61f472',
    'maintenance': '05e560ce7fde1a78746d689fd82fb090b6fe3c27a5c3ddf8599d6db5d91142e9',
    'management_recovery_bootstrap': 'f2636166bf00afd38efaa809b7aa20f1a27e352a7741de7fd68bf7663d82324a',
    'monitor_owned': 'dea01ca4eb29c1b950a1e16f04597fcaab775f5223d94cc3e561406cd7fe0bcb',
    'monitor_restart': '84feb0e3ad73e910f709e00cb4cfc794f9a54e47e8ea923a4fb97b92fb2f0b3d',
    'namespace_renewal': 'fb9f8da082e8a9199a2557d13b1b5d18afff0d72b38add2681184e63ac238f81',
    'namespace_scope_and_allocator': '8a171d71242c0ae36b79291375159712d951ac1199b48ea7f8137c34683dee79',
    'negative_cases': '5b6e5d0caedadb02494d3dd0e69f0b99ec177b8b28568347e64d3390922cea68',
    'next_step': '96e915b5efaac4ce92c772091fdd7ef3d59276208c9703fd08ee3c53f3c7913f',
    'node_config_and_hierarchy': '26b54b03288ffca03eeece0ec73c6a4a926295c34aa85902dcff85ce9cd66616',
    'node_lease_identity': '773d775564232d33e71fe6ba0a58aa07cc677534b71400b94990fadeafcc8ed9',
    'node_lease_import': '07d54549ccc19775c5902a39fe6f4d45d741bb4efbe3f82a6e6b2997a804447a',
    'node_mode': '2504053f76c8220e67bbfd8b2373e4054d6dfaa407b1d09cc0418c4a94bc2408',
    'normalized_authority_horizons': '33b7f94f31c28387851338ecd40ebb26436b0a7e7062b3ce502cace449045edb',
    'normative_term': 'c0c0e6e67a2bbcdce2f9d29307e1cae6a437ee65faa5c4dc3679b281ff698f84',
    'object_types': '2203b4085ca09a7d61ffb11210dd76419c6363d99aaf48c0bba39a9c6ef7523c',
    'opportunity_accounting': '6e0ee68e65ab8239509e6a9e442612cda812e83b67d0f916ac6d462f2a13a7c8',
    'opportunity_identity': '80c33370709721ec6401a8314a631d0f4473651c1823ff66a7a4e33de144a733',
    'opportunity_lifecycle': '45ef59844d0a9d6e8bdea5abc031fa0439787e5d4763ad42009ceff55e8a4422',
    'overflow': '2f620fd6b1556a8ae43a2b8f5c24545982d24ba12eed006743855de37eba5571',
    'plan_membership': 'eac88ba582f17c09795ddc15fbf8c445ec6009065629d0b14d9f187d764af9de',
    'pre_freeze_review_disposition': '7b67c8b41ccb193ba9ded3d3b0e8fd47c4002d525b41431c2425f636295293e4',
    'preformal_two_lane_witness': 'ad9c1f3a1e6492ecfa08d9ace1d4536227493ecf72f6ba5da08425b145f3f909',
    'projection_renewal': 'a443e99bff52634c98e2cd85b60ac640a56731d7b2c45e419a1694e56a0f56f0',
    'protected_service_capacity': 'bb13c5a9ec3c07ecba0f29e34bd725968af0e8ccc48fa960d474d84ad64444cc',
    'refinement_obligations': 'f158b1c05bf703051c046e1fc1c38b6417bc6c096f86223988c8a01d8f707c87',
    'request_identity_rules': 'd4a85e92e3047d13d51bb39222c3231b3ef4093e88ae01aa1a71387a0d1d858e',
    'request_terminal_dispositions': '9b585e0dea1110852cc366a497e22e131870987cbf2cf80bb835f5380994ab2f',
    'requirement': '939c7a7535aafc32494327cb0202ce1a766dc590151cdf941021c87b35506b53',
    'residency_transaction_state': '1b49f08d37d2d0df97586ce52eff01778665a7ccf7223a46907c171742e23b84',
    'retiring_authority_use': '0f033e5bc560b0178ac364b7098684754f5d3fdc0f4f19b18dc331d96a14edc7',
    'root_execution_capacity': '23b8cc893580f1a7e1471ec71675f73edd368c4bbb175d72c3673c08c56bc6b0',
    'root_plan': '49d8436add4434e5d2188a88c9ea7e93d81cb36af415ae1298493e46d5773f25',
    'safe_recurring_liveness_witness': 'aa1b8f64a5e87837da83ece1112e82fd64f45f7b49e6effec317d1c77c230bcd',
    'safety': '3538af3c4626fe69432b3b79c6aa0dc434021d22e8f90d48fb2d77b7f9f629b6',
    'scale_contract': '68175c956ffba58e5f4f226e0935bb8ce39082aef30b122a35dca2bb07cd54e5',
    'schema_version': '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
    'scope': '89bf04654714bc12c40bbc81059e6c434bf483d153dc23fc9b813ce0356e53b5',
    'second_hostile_review_disposition': '09ae88b17e897209d5dae3230f7978da5e5e455d22c0620059c77b9c028b0081',
    'semantic_stability': 'e38c15949df98f9182bcd59f14e714c3e0897c40c1236171981d19a31dd20623',
    'snapshot_identity_rule': '8dd85beec4b3b81198c44a124126e08445c6853f36a8ee74c208a87c9ec38079',
    'status': '2f5894c60811998b11d50a7ebee86be601493a66addaf0cca9aa573303e8d5e2',
    'stream_ledger': '1d3e008b302fe96aada916e3c8e42edff9e908a71f00f51b0899456bed69c550',
    'stream_renewal': 'e59fe7ea69ab32002466d4d8c31660365bba6edfdb0503b787d2bc539574e9a3',
    'third_hostile_review_disposition': 'c564584b858805439f31933d4696f3c8452f5c7589e26f6dc69b18a32f6976a4',
    'threat_model': '9aa2707b580172b522143480207cf4198a4cb53cf6f7a7322961e036721f06ef',
    'trusted_lease_clock': 'a4ad52724e195ae4bb49e49147bb0f5f7af5a376bfa5baddab9760d51c9d5928',
    'v1_work_frame': '37db4f251dacecfed1caaf88f786d333bc06842f6ce39ab526790a64f73aeb1f',
    'version_representation': 'e1efdc7e2cd25007b3f83a14d2cb945f36e7b7301342205adaf1013c509b72e3',
    'version_spaces': '67e7536bab6facb2f39111b9f632933b775a480681afe323341c43c97a17d348',
    'work_isolation': 'd68a75178f4d8ca4f44e22603339ed473a7ca3d042fc370d1ff8d2d18bc9df4d',
    'work_lanes': 'f62f6ed58c42c036d763a42ad13d8eb8a362efa54e4abcb9ee107e770b8c6e80',
    'work_record': '21be2e2063cafda42cbf46056918b98f279f0764ea9e83ecf259c0520772edeb',
}
EXPECTED_ARTIFACT_DIGESTS: dict[str, str] = {
    'capsched-models/analysis/dynamic-admission-recurring-residency-architecture-contract-v1.json': '015838a03f7967522d4998bf05b93fa70153bc14c3800a0fd300804574e5901f',
    'capsched-models/analysis/0189-dynamic-admission-and-recurring-residency-architecture-contract.md': '6dc76cefa80e138c8815f9269790b0ac58dfb6c5c3cafd442a6b09f3fc857382',
    'capsched-models/analysis/dynamic-admission-recurring-residency-pre-freeze-review-disposition-v1.json': '4de42dcf2029c81b928be9c7dbf5ef0214986bc5988d4c85581c31c68bd36901',
    'capsched-models/analysis/0190-dynamic-residency-pre-freeze-hostile-review-disposition.md': 'bb6c2cf8d5413933b3e9e8ea8c649040f2c24c565e12ef327e3d52f2990d5fe8',
    'capsched-models/analysis/dynamic-admission-recurring-residency-second-hostile-review-disposition-v1.json': 'ca29eaef4be617956fee30124da8901b4670bd9ccf9cbc6a10e415f300a2694f',
    'capsched-models/analysis/0191-dynamic-residency-second-hostile-review-and-redesign.md': '9aa314e0d29c563d0959267468adf40396bf02cc4661b4aa960e92699060a4c7',
    'capsched-models/analysis/dynamic-residency-preformal-two-lane-witness-v1.json': '0bce593650398bd117c4a9430bbac1e06590ef65536fd5f3e34dc9090d426ef8',
    'capsched-models/analysis/0192-dynamic-residency-preformal-two-lane-witness.md': '96994bd9d00db4067e37177aeb9441201c3b4094a36f774bb1acf230bc266a21',
    'capsched-models/analysis/dynamic-residency-third-hostile-review-disposition-v1.json': '5bd8d883d99ec32b921935919c0e8e3617e9539fe6f20d578fdc7e4a364c2d0b',
    'capsched-models/analysis/0193-dynamic-residency-third-hostile-review-and-redesign.md': 'b3e8f9258fa9ed3c3b3dc676f67e8ebc1bb6604ddfd24188fcb10d0b9372dd09',
    'capsched-models/analysis/architecture-freeze-external-assurance-protocol-v2.json': 'c580a42559e19e4efaedf7041c14b386ea3c843b2e0dec45576b6501f8b503e6',
    'capsched-models/analysis/0194-architecture-freeze-external-assurance-protocol-v2.md': '341102bf0c1c711c9f767114d333e1a5bc3fc8aec10f316c1e7a180289bcc4e0',
    'capsched-models/analysis/dynamic-residency-datacenter-composition-boundary-review-v1.json': 'a58ed3629d7dd07ca44975694496efec5199323bab9e5a3394270f3d87346e27',
    'capsched-models/analysis/0195-dynamic-residency-datacenter-composition-boundary-review.md': '7d98e946fffdb6dc402461cc29534640651a3c64a53634acf5e3618a56e6e76f',
    'capsched-models/analysis/dynamic-residency-fourth-hostile-counterexample-review-v1.json': 'c55b6ffc19fe97417b2c8e3fde2dc52ead7439770d18b519d38e9fd4ff6b4a45',
    'capsched-models/analysis/0196-dynamic-residency-fourth-hostile-counterexample-review.md': '3460da3cc44cba0436018f62d3e16badb8653923eabc02ee3fa1d5e7a29057b4',
    'capsched-models/analysis/architecture-freeze-assurance-v2-hostile-review-v1.json': '8b7bc3f3c40861ed57bf759e83d594ac96cb9a2d2d18acf3711c41b590660ef1',
    'capsched-models/analysis/0197-architecture-freeze-assurance-v2-hostile-review.md': '3dfef8dfd420006c00274dec62f328c11d2795ee7e6682c0f707b1d8a1be5d0d',
    'capsched-models/analysis/dynamic-residency-fifth-hostile-architecture-and-proof-review-v1.json': '426605b3df765f60525409d2248ffd131574123a8e074e64d477dcfffe06a8d9',
    'capsched-models/analysis/0198-dynamic-residency-fifth-hostile-architecture-and-proof-review.md': 'd241891e2ede88aeaec470825e2e895c3b61f6c48e7c5aa0b4096daf5163bcb6',
    'capsched-models/validation/validate-architecture-freeze-assurance-v2.py': 'b2f492ca8a503231089f7ae882eab5c7af725471801a63834922b9c275aaa996',
    'capsched-models/validation/verify-architecture-freeze-assurance-v2-real.py': '6a538d1c11de055d31fd348d0c862bccf768d6d01d6c885e898cda768245e8c7',
    'capsched-models/plans/0006-final-compositional-model-completion-plan.md': 'f01b01bf77c2e03618ff412afb6bdb94b884301025516901c171b7e4daabfa4b',
    'capsched-ai/decisions/ADR-0015-architecture-first-executable-specification-order.md': 'ede3c9f3c9cfcc3960ec31c3519b1571173d420c4c04ebee71cd88334ed69764',
}
EXPECTED_CANDIDATE_OBJECT_SET_DIGEST = "24bb1320d3f50a10195d18e899d7101d7f422ca6ed18c5bedfb088ff4bdc174f"

OBSOLETE_TERMS = {
    "SecurityIncidentCell", "SecurityIncidentSummary",
    "SecurityIncidentLatch", "anchorControlTurn",
    "monitor_internal_ActivateHeld", "shared_per_clock_pair",
    "MaxTransitionShards_is_fixed_per_admission",
    "MaxReplicasPerDomain_is_fixed_per_admission",
    "MaxFailureScopesPerEvent_is_fixed",
    "MaxSecurityScopesPerUse_is_fixed_per_admission",
}


class ValidationError(RuntimeError):
    pass


ARTIFACT_BYTES: dict[Path, bytes] = {}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON constant: {value}")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_strict_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            artifact_bytes(path).decode("utf-8", errors="strict"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (OSError, UnicodeError, ValueError) as error:
        raise ValidationError(f"strict JSON parse failed for {path}: {error}") \
            from error
    require(isinstance(value, dict), f"JSON root must be an object: {path}")
    reject_floats(value, str(path))
    return value


def artifact_bytes(path: Path) -> bytes:
    key = path.resolve()
    require(key in ARTIFACT_BYTES,
            f"artifact was not acquired through single-read gate: {path}")
    return ARTIFACT_BYTES[key]


def artifact_text(path: Path) -> str:
    return artifact_bytes(path).decode("utf-8", errors="strict")


def reject_floats(value: Any, label: str) -> None:
    if isinstance(value, float):
        raise ValidationError(f"floating-point value is forbidden: {label}")
    if isinstance(value, dict):
        for key, child in value.items():
            reject_floats(child, f"{label}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_floats(child, f"{label}[{index}]")


def reject_duplicate_string_arrays(value: Any, label: str) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            reject_duplicate_string_arrays(child, f"{label}.{key}")
    elif isinstance(value, list):
        if all(isinstance(item, str) for item in value):
            require(len(value) == len(set(value)),
                    f"duplicate string array member: {label}")
        for index, child in enumerate(value):
            reject_duplicate_string_arrays(child, f"{label}[{index}]")


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(artifact_bytes(path)).hexdigest()


def resolve_regular_file(root: Path, relative: str, label: str) -> Path:
    require(isinstance(relative, str) and relative,
            f"{label} path must be a nonempty string")
    candidate = Path(relative)
    require(not candidate.is_absolute() and ".." not in candidate.parts,
            f"{label} path escapes repository syntax")
    unresolved = root / candidate
    try:
        mode = unresolved.lstat().st_mode
    except OSError as error:
        raise ValidationError(f"{label} does not exist: {relative}") from error
    require(not stat.S_ISLNK(mode) and stat.S_ISREG(mode),
            f"{label} must be a non-symlink regular file")
    resolved_root = root.resolve()
    resolved = unresolved.resolve()
    try:
        resolved.relative_to(resolved_root)
    except ValueError as error:
        raise ValidationError(f"{label} path escapes repository") from error
    if resolved not in ARTIFACT_BYTES:
        flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) \
            | getattr(os, "O_NOFOLLOW", 0)
        try:
            descriptor = os.open(unresolved, flags)
        except OSError as error:
            raise ValidationError(
                f"{label} could not be opened without following symlinks: "
                f"{relative}") from error
        try:
            before = os.fstat(descriptor)
            require(stat.S_ISREG(before.st_mode),
                    f"{label} must remain a regular file while read")
            chunks: list[bytes] = []
            while True:
                chunk = os.read(descriptor, 1024 * 1024)
                if not chunk:
                    break
                chunks.append(chunk)
            after = os.fstat(descriptor)
        finally:
            os.close(descriptor)
        require((before.st_dev, before.st_ino, before.st_size,
                 before.st_mtime_ns)
                == (after.st_dev, after.st_ino, after.st_size,
                    after.st_mtime_ns),
                f"{label} changed during its single read")
        data = b"".join(chunks)
        require(len(data) == after.st_size,
                f"{label} size changed during its single read")
        ARTIFACT_BYTES[resolved] = data
    return resolved


def exact_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    require(set(value) == expected,
            f"{label} has missing or unknown keys: "
            f"missing={sorted(expected - set(value))} "
            f"extra={sorted(set(value) - expected)}")
    return value


def unique_strings(value: Any, label: str) -> list[str]:
    require(isinstance(value, list), f"{label} must be an array")
    require(all(isinstance(item, str) and item for item in value),
            f"{label} must contain nonempty strings")
    require(len(value) == len(set(value)), f"{label} contains duplicates")
    return value


def at(value: dict[str, Any], dotted: str) -> Any:
    current: Any = value
    for part in dotted.split("."):
        require(isinstance(current, dict) and part in current,
                f"missing critical path: {dotted}")
        current = current[part]
    return current


def expect(value: dict[str, Any], dotted: str, expected: Any) -> None:
    require(at(value, dotted) == expected,
            f"critical architecture value changed: {dotted}")


def fenced_block(markdown: str, heading: str) -> list[str]:
    marker = f"## {heading}\n"
    start = markdown.find(marker)
    require(start >= 0, f"missing Markdown heading: {heading}")
    fence = markdown.find("```text\n", start + len(marker))
    require(fence >= 0, f"missing text fence under {heading}")
    body = fence + len("```text\n")
    end = markdown.find("\n```", body)
    require(end >= 0, f"unterminated text fence under {heading}")
    return [line.strip() for line in markdown[body:end].splitlines()
            if re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", line.strip())]


def validate_parent_registry(contract: dict[str, Any]) -> None:
    renewal = exact_keys(contract["namespace_renewal"], {
        "wrap_allowed", "rules", "ScopedNamespaceRoot",
        "root_slots_preallocated_per_class", "root_generation_wrap_allowed",
        "inner_exhaustion_can_trigger_fresh_MonitorBootEpoch",
        "inner_exhaustion_action", "namespace_type_registry",
        "every_consumer_compares_complete_enclosing_tuple",
        "registry_must_cover_every_version_space_exactly_once",
        "registry_is_the_single_parent_graph_source",
        "parent_graph_must_be_total_acyclic_and_scope_confined",
        "local_exhaustion_may_advance_boot", "cpu_or_lane_exhaustion_result",
        "independently_authorized_reboot_is_outside_namespace_exhaustion_transition",
        "quiescence_receipt_has_independent_sequence",
        "quiescence_receipt_identity", "v1_live_directory_layout_renewal",
    }, "namespace_renewal")
    registry = renewal["namespace_type_registry"]
    require(isinstance(registry, dict), "namespace registry must be an object")
    require(list(registry) == EXPECTED_VERSION_SPACES,
            "namespace registry order/inventory differs from version_spaces")
    nodes = set(EXPECTED_VERSION_SPACES)
    graph: dict[str, list[str]] = {}
    for name, row in registry.items():
        exact_keys(row, REGISTRY_FIELDS, f"registry.{name}")
        require(row["kind"] in REGISTRY_KINDS,
                f"unknown registry kind: {name}")
        require(isinstance(row["allocator_class"], str)
                and row["allocator_class"],
                f"empty allocator class: {name}")
        require(isinstance(row["owner_scope_class"], str)
                and row["owner_scope_class"],
                f"empty owner scope: {name}")
        require(isinstance(row["exhaustion_action"], str)
                and row["exhaustion_action"],
                f"empty exhaustion action: {name}")
        require(isinstance(row["exhaustion_scope_class"], str)
                and row["exhaustion_scope_class"],
                f"empty exhaustion scope: {name}")
        parents = unique_strings(row["parents"], f"registry.{name}.parents")
        require(set(parents) <= nodes and name not in parents,
                f"invalid namespace parent: {name}")
        require(row["may_advance_boot"] is False,
                f"local exhaustion may advance boot: {name}")
        graph[name] = parents

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str) -> None:
        require(node not in visiting, f"namespace cycle reaches {node}")
        if node in visited:
            return
        visiting.add(node)
        for parent in graph[node]:
            visit(parent)
        visiting.remove(node)
        visited.add(node)

    for node in EXPECTED_VERSION_SPACES:
        visit(node)

    exact_parents = {
        "NodeConfigGeneration": ["MonitorBootEpoch"],
        "DomainEpoch": ["GlobalAuthorityEpoch"],
        "NodeLeaseImportGeneration": [
            "NodeLeaseEpoch", "LeaseClockEpoch", "MonitorBootEpoch",
        ],
        "GlobalPlacementOwnershipEpoch": [
            "GlobalAuthorityEpoch", "QuorumEpoch",
        ],
        "GlobalPlacementFencingToken": ["GlobalPlacementOwnershipEpoch"],
        "RootExecutionTurn": ["RootExecutionClockEpoch"],
        "TargetControlTurn": ["TargetControlReservationGeneration"],
        "WatchdogEpoch": ["MonitorBootEpoch"],
        "WatchdogTurn": ["WatchdogEpoch"],
        "ActivationCommitGeneration": [
            "ActivationIntentGeneration", "ExecutionContextGeneration",
        ],
        "FailureCoverGeneration": [
            "FailureNamespaceEpoch", "NodeConfigGeneration",
            "MonitorBootEpoch",
        ],
        "ManagementBootstrapGeneration": [
            "NodeConfigGeneration", "MonitorBootEpoch",
        ],
    }
    for name, parents in exact_parents.items():
        require(graph[name] == parents, f"critical namespace parent changed: {name}")
    require(renewal["registry_is_the_single_parent_graph_source"] is True,
            "namespace registry is not the sole parent graph")
    require(renewal["local_exhaustion_may_advance_boot"] is False,
            "namespace exhaustion can trigger a boot")


def validate_formal_dependency_dag(contract: dict[str, Any]) -> None:
    formal = contract["formal_decomposition"]
    order = unique_strings(formal.get("proof_dependency_dag_order"),
                           "formal proof dependency order")
    require(order == EXPECTED_PROOF_ORDER,
            "formal proof dependency order changed")

    ledger = exact_keys(formal.get("component_assume_guarantee_ledger"),
                        set(EXPECTED_PROOF_ORDER),
                        "formal assume/guarantee ledger")
    require(list(ledger) == EXPECTED_PROOF_ORDER,
            "formal ledger order differs from proof DAG")
    position = {name: index for index, name in enumerate(order)}
    external_nodes: set[str] = set()

    for name in order:
        node = exact_keys(ledger[name], {
            "node_class", "internal_predecessors", "temporal_relies",
            "conditional_omega_relies", "guarantee", "discharge_state",
        }, f"formal ledger node {name}")
        require(node["node_class"] == EXPECTED_PROOF_CLASSES[name],
                f"formal node class changed: {name}")
        predecessors = unique_strings(
            node["internal_predecessors"],
            f"formal predecessors for {name}",
        )
        for predecessor in predecessors:
            require(predecessor in position,
                    f"formal predecessor is unknown: {name} -> {predecessor}")
            require(position[predecessor] < position[name],
                    f"formal dependency is cyclic or forward: "
                    f"{name} -> {predecessor}")
        require(predecessors == EXPECTED_PROOF_PREDECESSORS[name],
                f"formal predecessor set changed: {name}")

        temporal = unique_strings(node["temporal_relies"],
                                  f"formal temporal relies for {name}")
        omega = unique_strings(node["conditional_omega_relies"],
                               f"formal omega relies for {name}")
        require(temporal == EXPECTED_TEMPORAL_RELIES[name],
                f"formal temporal rely set changed: {name}")
        require(omega == EXPECTED_CONDITIONAL_OMEGA_RELIES[name],
                f"formal conditional omega rely set changed: {name}")
        require(node["discharge_state"] == EXPECTED_DISCHARGE_STATES[name],
                f"formal discharge state changed: {name}")
        guarantee = node["guarantee"]
        require(isinstance(guarantee, str) and guarantee,
                f"formal guarantee is empty: {name}")
        require(not any(fragment in guarantee for fragment in (
            "assume_", "all_predecessor", "Operational",
        )), f"formal guarantee smuggles a rely or descendant claim: {name}")
        if node["node_class"] == "external_interface":
            external_nodes.add(name)
            require(not predecessors and not temporal and not omega,
                    f"external interface has hidden proof dependencies: {name}")

    require(external_nodes == {
        "ENV_HARDWARE_TIME_ROOT",
        "ENV_CLUSTER_ISSUER_QUORUM_TIME",
        "ENV_ENTRY_CODE_STATE_INTERFACE",
    }, "formal external interface boundary changed")
    require(formal.get("temporal_not_stored_relies") == [
        "StableWindow",
        "AuditHeadroomWindow",
        "ProtectedClockProgressOrFailStop",
        "InfiniteFreshnessSupply",
    ], "formal temporal rely inventory changed")

    def ancestors(name: str, active: set[str]) -> set[str]:
        require(name not in active,
                f"formal dependency cycle reaches: {name}")
        result: set[str] = set()
        for predecessor in ledger[name]["internal_predecessors"]:
            result.add(predecessor)
            result.update(ancestors(predecessor, active | {name}))
        return result

    require(ancestors("DYN_REGRESSION", set()) == set(order[:-1]),
            "final regression gate does not depend on every prior proof node")
    require(formal.get(
        "component_dependency_edges_are_acyclic_and_no_component_may_assume_its_own_or_descendant_guarantee"
    ) is True, "formal DAG safety declaration changed")


def validate_critical_contract(contract: dict[str, Any]) -> None:
    expected = {
        "node_config_and_hierarchy.NodeConfig_owner": "protected_boot_root",
        "node_config_and_hierarchy.per_admission_maximum_may_exceed_NodeConfig": False,
        "node_config_and_hierarchy.width_rejection_before_publication": "TooWide",
        "node_config_and_hierarchy.ancestor_capacity_rejection_before_publication": "NoParentCapacity",
        "node_config_and_hierarchy.all_ancestor_capacity_terms_are_disjoint_monitor_owned_naturals": True,
        "node_config_and_hierarchy.every_authority_and_cleanup_use_binds_complete_ancestor_fence_vector": True,
        "node_config_and_hierarchy.live_use_can_be_relabeled_to_new_parent": False,
        "root_execution_capacity.one_physical_opportunity_charges_at_most_one_descendant_lane": True,
        "root_execution_capacity.one_physical_opportunity_creates_ActivationIntent": False,
        "root_execution_capacity.one_physical_opportunity_issues_executable_RunToken_directly": False,
        "root_execution_capacity.control_and_execution_certificates_on_shared_hardware_bind_same_HardwareCapacityRootCertificate": True,
        "root_execution_capacity.independent_control_and_execution_capacity_requires_disjoint_hardware_context_identities": True,
        "root_execution_capacity.ExecutionCellLease_is_immutable_after_allocator_publication": True,
        "root_execution_capacity.ExecutionCellUseCell_is_the_only_mutable_one_use_state": True,
        "root_execution_capacity.root_allocator_issues_only_cells_already_debited_to_the_lane_through_every_shared_parent": True,
        "root_execution_capacity.every_child_schedule_is_a_subset_of_its_exact_parent_partition_and_siblings_are_pairwise_disjoint": True,
        "root_execution_capacity.scalar_capacity_equality_without_PhysicalOccurrenceID_set_equality_is_sufficient": False,
        "root_execution_capacity.ExecutionCellLease_can_reference_a_not_yet_published_ActivationIntent": False,
        "root_execution_capacity.lane_prepare_can_only_request_ActivationShard_CAS_Unbound_to_Reserved_binding_exact_intent_digest": True,
        "root_execution_capacity.root_allocator_lane_or_Linux_can_mutate_ExecutionCellUseCell_after_publication": False,
        "root_execution_capacity.ActivationIntent_is_prepared_before_and_binds_one_already_allocator_issued_future_cell_without_consuming_it": True,
        "root_execution_capacity.one_physical_opportunity_consumes_at_most_one_ExecutionCellLease_and_ActivationIntent": True,
        "root_execution_capacity.joint_activation_is_the_RootExecutionStep_for_a_due_cell": True,
        "root_execution_capacity.cell_can_wait_carry_forward_or_be_reused_after_due_interval": False,
        "root_execution_capacity.token_budget_may_exceed_cell_end_or_any_bound_authority_horizon": False,
        "root_execution_capacity.cell_end_forces_hardware_exit_budget_stop_and_handoff_before_next_owner": True,
        "root_execution_capacity.remaining_cell_budget_can_roll_into_later_cell_or_other_lane": False,
        "protected_service_capacity.virtual_turn_without_physical_entry_allowed": False,
        "protected_service_capacity.independent_certificates_can_overbook_shared_parent": False,
        "clock_bridge.one_target_microstep_can_advance_another_target_turn": False,
        "clock_bridge.target_microstep_can_block_while_holding_schedule_cell": False,
        "clock_bridge.shard_ControlTurn_can_be_reused_as_every_target_credit": False,
        "clock_bridge.TargetControlConservationInvariant_is_internal_monitor_guarantee": True,
        "clock_bridge.ClockBridgeInvariant_as_a_whole_is_external_rely": False,
        "node_lease_import.clock_conversion_returns_interval_not_point": True,
        "node_lease_import.new_authority_uses_stop_at_earliest_locally_possible_issuer_expiry": True,
        "node_lease_import.disconnect_can_change_partition_mode_extend_term_increase_rights_or_reset_offline_timer": False,
        "node_lease_import.reconnection_reopens_predecessor_frozen_use": False,
        "global_placement_authority.release_intent_joint_activation_and_token_must_end_by_effective_new_authority_horizon": True,
        "global_placement_authority.lease_or_security_extension_alone_can_extend_GlobalPlacementUse_horizon": False,
        "global_placement_authority.time_based_supersession_allowed_for_unbounded_or_irreversible_effect_class": False,
        "global_placement_authority.quorum_supersession_without_exact_settlement_prefix_preserves_recurring_or_exactly_once_continuity": False,
        "global_placement_authority.settlement_prefix_before_predecessor_write_close_can_preserve_continuity": False,
        "global_placement_authority.continuity_theorem_requires_first_successor_delivery_not_after_conservatively_converted_last_predecessor_delivery_plus_maximum_gap": True,
        "global_placement_authority.network_silence_is_source_quiescence": False,
        "global_placement_authority.local_PlacementGeneration_substitutes_for_global_fence": False,
        "global_placement_authority.reconnection_reopens_predecessor_ownership_epoch": False,
        "normalized_authority_horizons.raw_integer_deadlines_from_different_clock_domains_may_be_compared_or_minimized": False,
        "normalized_authority_horizons.all_finite_deadlines_are_half_open_and_use_earliest_possible_target_expiry": True,
        "normalized_authority_horizons.extension_of_one_source_recomputes_complete_vector_and_cannot_extend_another_source": True,
        "normalized_authority_horizons.active_context_never_depends_on_future_network_or_issuer_progress_to_stop": True,
        "activation_composition_interface.residency_output": "non_executable_ActivationIntent",
        "activation_composition_interface.ActivationIntent_is_execution_authority_or_service": False,
        "activation_composition_interface.ActivationIntent_creation_consumes_physical_execution_cell": False,
        "activation_composition_interface.RequiredQuiescenceReceiptSet_rules.missing_class_is_NotApplicable": False,
        "activation_composition_interface.failed_joint_validation_can_leave_partial_executable_state": False,
        "activation_composition_interface.ActivationDecisionCell_is_the_only_preactivation_cancel_activate_authority_linearization": True,
        "activation_composition_interface.failed_attempt_expires_only_its_ExecutionCellUseCell_and_leaves_ActivationDecisionCell_Undecided_for_fresh_slot_retry": True,
        "activation_composition_interface.cancel_after_PreparedInert_cannot_publish_SuppressedBeforeActivation_and_uses_StopPending": True,
        "activation_composition_interface.independent_shadow_ActivationDecision_or_entry_gate_winner_exists": False,
        "activation_composition_interface.ActivationID_omits_any_scoped_namespace_parent_or_physical_incarnation": False,
        "activation_composition_interface.one_successful_ActivationSlotID_and_ActivationIntent_pair_can_have_more_than_one_ActivationID_or_initial_entry_RunToken": False,
        "activation_composition_interface.retry_after_any_terminal_activation_or_settlement_returns_existing_deterministic_result_without_mint": True,
        "activation_composition_interface.PreparedInert_without_final_valid_entry_gate_counts_execution_activation_or_service": False,
        "activation_composition_interface.hardware_inert_staging_is_executable_before_final_valid_entry_gate": False,
        "activation_composition_interface.MonitorBootEpoch_change_invalidates_unsettled_predecessor_activation_without_reexecution": True,
        "activation_composition_interface.DeliverySettlementCell_is_the_only_mutable_execution_budget_resume_and_delivery_state": True,
        "activation_composition_interface.same_ActivationID_delivery_retry_can_emit_second_distinct_receipt_or_recount_stream_service": False,
        "activation_composition_interface.protected_interrupt_resume_requires_exact_next_monotonic_resume_sequence_and_cannot_increase_remaining_budget": True,
        "activation_composition_interface.duplicate_ExecutionDeliveryReceipt_is_idempotent_and_cannot_advance_debt_ordinal_or_service_count_twice": True,
        "activation_composition_interface.only_ActivationCommitReceipt_sets_ActivatedUnserved": True,
        "activation_composition_interface.ActivationCommitReceipt_alone_counts_recurring_service": False,
        "activation_composition_interface.only_qualifying_ExecutionDeliveryReceipt_sets_Served_and_counts_service": True,
        "activation_composition_interface.zero_delivered_ticks_without_authenticated_post_entry_voluntary_yield_counts_service": False,
        "management_recovery_bootstrap.owner": "protected_boot_root",
        "management_recovery_bootstrap.bootstrap_execution_and_control_capacity_is_explicitly_conserved_not_free": True,
        "management_recovery_bootstrap.fallback_to_ordinary_Linux_or_unprotected_management": False,
        "node_mode.CanonicalFailureCover_is_total": True,
        "node_mode.failure_closure_can_stop_after_one_pass_without_fixed_point": False,
        "node_mode.intermediate_live_topology_generation_can_be_omitted_from_failure_cover": False,
        "node_mode.real_failure_can_be_truncated_rejected_or_stutter_while_authority_continues": False,
        "node_mode.KFailureClosureIterations_scopes_and_edges_are_NodeConfig_fixed": True,
        "node_mode.each_live_authority_use_charges_one_reverse_edge_and_ScopeCleanupReservation_per_leaf_and_every_potential_cover_ancestor_before_publication": True,
        "node_mode.reverse_edge_overflow_or_conservation_mismatch_result": "node_failstop",
        "node_mode.failure_authority_point_materializes_dependent_contract_population": False,
        "node_mode.cleanup_traverses_all_dependent_artifacts_in_one_transition": False,
        "node_mode.source_health_is_derived_only_from_EffectiveScope_not_duplicated_in_SourceReplayCell": True,
        "node_mode.audit_retry_reuses_same_event_and_position": True,
        "node_mode.Committed_decision_is_sole_multiscope_authority_linearization": True,
        "node_mode.MaterializeScope_changes_effective_authority": False,
        "node_mode.failure_cleanup_releases_FailureEscrow_only_after_effect_terminal": True,
        "control_operation.ShardApplyOwner_is_exactly_one_per_entry_and_only_apply_status_writer": True,
        "control_operation.failure_transition_writes_apply_status": False,
        "control_operation.local_apply_can_return_or_mint_escrow": False,
        "control_operation.stored_overwritable_TransferPhase_exists": False,
        "control_operation.network_silence_timeout_or_local_PlacementGeneration_is_authorizer": False,
        "root_plan.every_lane_binds_parent_conserved_RootExecutionAllocationCertificate": True,
        "root_plan.independent_lane_clocks_imply_disjoint_physical_capacity": False,
        "trusted_lease_clock.untrusted_Linux_can_reenter_by_replaying_RunToken": False,
        "trusted_lease_clock.initial_entry_atomically_consumes_one_use_entry_permit": True,
        "trusted_lease_clock.protected_interrupt_return_uses_monotonic_DeliverySettlementCell_resume_sequence_not_untrusted_token_submission": True,
        "trusted_lease_clock.every_initial_entry_uses_only_TokenExecutable_and_every_continuation_or_resume_uses_only_ActiveContextExecutable": True,
        "trusted_lease_clock.watchdog_progress_is_not_derived_from_LeaseTick_lane_control_or_Linux": True,
        "trusted_lease_clock.protected_LeaseTick_eventually_advances_or_independent_watchdog_autonomously_fences_and_failstops_every_time_bounded_authority_scope": True,
        "trusted_lease_clock.both_LeaseTick_and_WatchdogTurn_may_stutter_forever_under_time_bounded_liveness_rely": False,
        "trusted_lease_clock.unbounded_LeaseTick_stutter_preserves_time_bounded_liveness_claim": False,
        "scale_contract.all_certificate_vector_and_proof_widths_are_fixed_by_NodeConfig": True,
        "scale_contract.admission_can_raise_NodeConfig_maximum": False,
        "scale_contract.hierarchy_semantics_mandatory": True,
        "scale_contract.depth_one_flat_specialization_allowed": True,
        "safe_recurring_liveness_witness.finite_production_words_claim_unconditional_infinite_recurrence": False,
        "formal_decomposition.component_dependency_edges_are_acyclic_and_no_component_may_assume_its_own_or_descendant_guarantee": True,
        "linux_projection_adapter.authority_role": False,
        "linux_projection_adapter.guaranteed_activation_requires_linux_call_or_LocalValidate": False,
    }
    for path, value in expected.items():
        expect(contract, path, value)

    require(at(contract, "clock_bridge.per_shard_turn_conservation") ==
            "sum_delta_TargetControlTurn_over_active_targets_less_than_or_equal_to_delta_ControlTurn_less_than_or_equal_to_one",
            "target-control conservation equation changed")
    require(at(contract, "node_config_and_hierarchy.ancestor_capacity_equation") ==
            "for_every_ancestor_and_resource_Current_plus_Pending_plus_Retiring_plus_FailureEscrow_less_than_or_equal_to_AncestorReservation",
            "ancestor capacity equation changed")
    require(at(contract, "root_execution_capacity.parent_capacity_equation") ==
            "RootExecutionFrameCapacity_equals_ManagementExecutionCells_plus_EmergencyStopExecutionCells_plus_sum_LaneExecutionCells_plus_SlackExecutionCells",
            "physical execution capacity equation changed")
    require(at(contract, "root_execution_capacity.shared_hardware_capacity_equation") ==
            "HardwareFrameCapacity_equals_ProtectedControlCells_plus_DomainExecutionCells_plus_ManagementCells_plus_EmergencyCells_plus_SlackCells",
            "shared hardware capacity equation changed")
    require(at(contract, "root_execution_capacity.per_cell_budget_equation") ==
            "CellDuration_equals_EntryExitGuardBudget_plus_ReservedTokenBudget_plus_UnusedCellBudget",
            "cell budget equation changed")
    require(at(contract, "root_execution_capacity.active_context_equation") ==
            "for_every_physical_context_cardinality_of_ActiveContextExecutable_ActivationID_owner_is_zero_or_one",
            "active context exclusion changed")
    require(at(contract, "node_mode.CanonicalFailureCover_results_in_order") == [
        "exact_canonical_closure_when_size_at_most_KFailureScopesPerEvent",
        "unique_lowest_common_ancestor_in_boot_fixed_FailureCoverTree_for_union_closure_when_nonroot",
        "pre_reserved_node_failstop_when_root_cover_or_no_bounded_sound_cover_is_required",
    ], "failure cover precedence changed")
    require(at(contract, "node_mode.failure_processing_closure") ==
            "least_fixed_point_of_failure_processing_monotonic_step_from_failure_processing_seed",
            "failure topology closure changed")
    require(at(contract, "node_mode.failure_commit_capacity_effect") ==
            "atomically_transfer_every_selected_cover_resource_charge_from_Current_Pending_or_Retiring_to_exact_FailureEscrow_without_duplication_then_make_successor_fence_effective",
            "failure escrow transfer changed")
    require(at(contract, "node_mode.failure_unaffected_definition") ==
            "scope_or_lane_outside_selected_FailureCoverCertificate_cover_and_outside_node_failstop",
            "failure unaffected definition changed")
    require(at(contract, "node_lease_import.PartitionModes") == {
        "CONNECTED_ONLY": "release_and_joint_activation_require_current_authenticated_connectivity_evidence_loss_blocks_both_and_stops_existing_authority_within_sealed_bound",
        "CONTINUE_TO_CONSERVATIVE_EXPIRY": "release_and_joint_activation_before_minimum_of_conservative_issuer_expiry_last_connected_plus_MaxOfflineDuration_and_all_narrower_horizons_only",
        "RECOVERY_ONLY": "from_certificate_installation_no_ordinary_release_or_activation_and_only_bootstrap_admitted_recovery_actions_run_connectivity_cannot_reopen_ordinary_authority",
    }, "partition-mode semantics changed")
    require(at(contract, "opportunity_lifecycle.machine_states") == [
        "Released", "Preparing", "HeldReady", "ActivationIntentPending",
        "ActivatedUnserved", "Served", "SuppressedBeforeActivation",
        "StopPending", "Settling", "Terminal",
    ], "machine lifecycle changed")
    require(at(contract, "opportunity_lifecycle.human_to_machine_refinement") == {
        "Released": "Released",
        "Preparing": "Preparing",
        "HeldReady": "HeldReady",
        "ActivationIntentPending": "ActivationIntentPending",
        "Activated": "ActivatedUnserved_or_Served",
        "WithdrawOrRevokePending":
            "SuppressedBeforeActivation_or_StopPending_selected_by_commit_receipt_presence",
        "Cleanup": "Settling",
        "Settling": "Settling",
        "Completed_Withdrawn_Revoked_LeaseExpired_or_ActivatedAndStopped":
            "Terminal",
    }, "human/machine lifecycle refinement changed")
    require(at(contract,
               "opportunity_lifecycle.source_pending_then_transaction_owner_order") ==
            "source_owner_publishes_DurablePending_then_transaction_owner_allocates_and_links_PhysicalResidencyTxn",
            "pending transaction writer order changed")
    require(at(contract, "root_plan.LaneBoundaryAdvance_staged_order.PrepareIntent_t") ==
            "use_post_apply_membership_fence_and_complete_normalized_deadline_state_create_nonexecutable_ActivationIntent_for_exact_allocator_ActivationSlotID_then_request_exact_physical_context_ActivationShard_CAS_ExecutionCellUseCell_Unbound_to_Reserved_binding_intent_digest_without_consuming_the_physical_cell",
            "prepare-intent ownership or cell semantics changed")
    require(at(contract, "root_execution_capacity.ExecutionCellLease_fields") == [
        "RootExecutionClockEpoch_RootExecutionTurn_and_cell_ordinal",
        "RootExecutionAllocationGeneration_and_exact_physical_context",
        "allocator_created_ActivationSlotID_exact_CurrentOpportunity_lane_and_eligibility_commitment_without_future_ActivationIntent_identity",
        "cell_start_cell_end_and_positive_max_token_budget",
        "exact_complete_NormalizedAuthorityHorizonVector_digest_and_local_not_after_tick",
        "immutable_allocator_issuance_identity_and_digest",
    ], "ExecutionCellLease schema changed")
    require(at(contract, "root_execution_capacity.ExecutionCellUseCell_fields") == [
        "exact_ExecutionCellLease_and_physical_schedule_occurrence",
        "single_writer_exact_physical_context_ActivationShard",
        "one_way_state_Unbound_Reserved_Consumed_Expired_orSettled",
        "None_or_exact_once_bound_ActivationIntent_digest_and_ActivationDecisionCell",
        "entry_exit_and_budget_settlement_receipts",
    ], "ExecutionCellUseCell schema changed")
    require(at(contract,
               "activation_composition_interface.ActivationDecisionCell_fields") == [
        "exact_CurrentOpportunity_and_single_writer_ActivationShard",
        "one_way_state_Undecided_SuppressedBeforeActivation_PreparedInert_Entered_StopPending_Settled_or_Expired",
        "None_or_exact_successful_ActivationSlotID_ActivationIntent_ExecutionCellLease_and_ExecutionCellUseCell",
        "None_or_exact_ActivationID_ExecutionContextKey_one_use_entry_permit_and_DeliverySettlementCell",
        "MonitorBootEpoch_due_cell_end_transition_generation_and_first_terminal_cause",
    ], "ActivationDecisionCell schema changed")
    require(at(contract,
               "activation_composition_interface.DeliverySettlementCell_fields") == [
        "exact_ActivationID_ActivationDecisionCell_ExecutionCellUseCell_and_ExecutionContextKey",
        "single_writer_exact_physical_context_ActivationShard",
        "one_way_state_Inert_Active_StopPending_or_Settled",
        "one_use_entry_consumed_flag_monotonic_resume_sequence_and_active_hardware_owner",
        "initial_consumable_budget_remaining_budget_and_checked_execution_intervals",
        "deterministic_ActivationCommitReceiptID_ExecutionDeliveryReceiptID_service_classification_and_terminal_disposition",
    ], "DeliverySettlementCell schema changed")
    require(at(contract,
               "activation_composition_interface.ExecutionDeliveryReceipt_fields") == [
        "exact_ActivationID_ActivationCommitReceipt_and_RunToken",
        "hardware_visible_entry_position_and_cell_start_end",
        "positive_delivered_execution_ticks_or_authenticated_post_entry_voluntary_yield",
        "forced_exit_stop_or_yield_reason",
        "exact_consumed_and_remaining_budget_settlement",
    ], "ExecutionDeliveryReceipt schema changed")


def validate_review_ledger(root: Path, contract: dict[str, Any]) -> None:
    r3_rel = contract["third_hostile_review_disposition"]
    require(r3_rel ==
            "analysis/dynamic-residency-third-hostile-review-disposition-v1.json",
            "R3 disposition path changed")
    r3 = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / r3_rel), "R3 disposition"))
    exact_keys(r3, {
        "schema_version", "id", "requirement", "date", "work_record",
        "analysis", "reviewed_contract", "status", "finding_status_policy",
        "source_reviews", "source_review_provenance", "review_finding_count",
        "findings",
        "self_audit_finding_count", "self_audit_findings",
        "aggregate_finding_count", "required_next_artifacts", "claims",
    }, "R3 disposition")
    require(r3["schema_version"] == 2
            and r3["requirement"] == EXPECTED_REQUIREMENT,
            "R3 identity changed")
    require(r3["status"] ==
            "third_round_rejected_freeze_redesign_integrated_pending_fresh_review_and_formal_refinement",
            "R3 redesign status changed")
    require(r3["source_review_provenance"] == {
        "raw_review_outputs_retained_as_immutable_signed_artifacts": False,
        "records_are_unattested_discovery_transcriptions": True,
        "may_count_as_external_freeze_evidence": False,
        "fresh_disposition_requires_v2_1_checkpointed_commit_and_reveal": True,
    }, "R3 source review provenance was upgraded or obscured")
    require(r3["review_finding_count"] == 20
            and [row.get("id") for row in r3["findings"]] == EXPECTED_R3_IDS,
            "R3 reviewer finding inventory changed")
    require(r3["self_audit_finding_count"] == 13
            and [row.get("id") for row in r3["self_audit_findings"]]
            == EXPECTED_R3_SELF_IDS,
            "R3 self-audit inventory changed")
    require(r3["aggregate_finding_count"] == 33,
            "R3 aggregate count changed")
    for row in r3["findings"] + r3["self_audit_findings"]:
        require(isinstance(row, dict)
                and row.get("status") ==
                "open_redesign_integrated_pending_fresh_review_and_formal_refinement",
                f"R3 finding was prematurely closed: {row.get('id')}")
    require(r3["claims"]["findings_closed"] is False
            and r3["claims"]["candidate_redesign_integrated"] is True
            and r3["claims"]["architecture_frozen"] is False
            and r3["claims"]["tla_written"] is False,
            "R3 disposition overclaims")

    dc_rel = contract["datacenter_composition_boundary_review"]
    require(dc_rel ==
            "analysis/dynamic-residency-datacenter-composition-boundary-review-v1.json",
            "datacenter review path changed")
    dc = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / dc_rel), "datacenter review"))
    exact_keys(dc, {
        "schema_version", "id", "date", "work_record", "requirement",
        "analysis", "reviewed_contract", "reviewer_id", "reviewer_role",
        "reviewer_identity_authenticated", "source_verdict",
        "source_review_predates_integrated_redesign",
        "source_review_may_accept_revised_bytes", "review_provenance",
        "status", "findings",
        "finding_count", "claims",
    }, "datacenter review")
    require(dc["schema_version"] == 2
            and dc["finding_count"] == 8
            and [row.get("id") for row in dc["findings"]] == EXPECTED_DC_IDS,
            "datacenter finding inventory changed")
    require(dc["source_verdict"] == "FREEZE_NO"
            and dc["reviewer_identity_authenticated"] is False
            and dc["source_review_may_accept_revised_bytes"] is False,
            "source datacenter review was converted into acceptance")
    require(dc["status"] ==
            "eight_blockers_open_redesign_integrated_pending_fresh_review_and_formal_refinement",
            "datacenter redesign status changed")
    require(dc["review_provenance"] == {
        "raw_review_output_retained_as_immutable_signed_artifact": False,
        "record_is_unattested_discovery_transcription": True,
        "may_count_as_external_freeze_evidence": False,
        "fresh_disposition_requires_v2_1_checkpointed_commit_and_reveal": True,
    }, "datacenter review provenance was upgraded or obscured")
    require(all(row.get("status") ==
                "open_redesign_integrated_pending_fresh_review_and_formal_refinement"
                for row in dc["findings"]),
            "datacenter finding was prematurely closed")
    require(dc["claims"]["findings_closed"] is False
            and dc["claims"]["revised_bytes_reviewed"] is False
            and dc["claims"]["architecture_frozen"] is False,
            "datacenter review overclaims")

    r4_rel = contract["fourth_hostile_counterexample_review"]
    require(r4_rel ==
            "analysis/dynamic-residency-fourth-hostile-counterexample-review-v1.json",
            "R4 counterexample review path changed")
    r4 = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / r4_rel), "R4 counterexample review"))
    exact_keys(r4, {
        "schema_version", "id", "date", "work_record", "requirement",
        "analysis", "reviewed_contract", "review_kind",
        "reviewer_identity_authenticated", "source_verdict",
        "review_provenance", "status",
        "finding_count", "findings", "claims",
    }, "R4 counterexample review")
    require(r4["schema_version"] == 2
            and r4["requirement"] == EXPECTED_REQUIREMENT
            and r4["reviewed_contract"] ==
            "dynamic-admission-recurring-residency-architecture-contract-v1.json",
            "R4 review identity changed")
    require(r4["source_verdict"] == "FREEZE_NO"
            and r4["reviewer_identity_authenticated"] is False,
            "R4 rejection was converted into authenticated acceptance")
    require(r4["status"] ==
            "redesign_integrated_pending_fresh_review_and_formal_refinement",
            "R4 redesign status changed")
    require(r4["review_provenance"] == {
        "raw_independent_session_transcripts_retained_as_immutable_artifacts":
            False,
        "this_record_is_an_unattested_internal_discovery_transcription": True,
        "may_count_as_external_freeze_acceptance_or_rejection_evidence": False,
        "future_disposition_requires_v2_1_checkpointed_signed_review_reveal":
            True,
    }, "R4 review provenance was upgraded or obscured")
    require(r4["finding_count"] == len(EXPECTED_R4_IDS)
            and [row.get("id") for row in r4["findings"]] == EXPECTED_R4_IDS,
            "R4 finding inventory changed")
    for row in r4["findings"]:
        exact_keys(row, {"id", "severity", "finding", "required_response",
                         "status"}, f"R4 finding {row.get('id')}")
        require(row["severity"] in {"blocker", "high", "medium"},
                f"invalid R4 severity: {row['id']}")
        require(row["status"] ==
                "open_redesign_integrated_pending_fresh_review_and_formal_refinement",
                f"R4 finding was prematurely closed: {row['id']}")
    require(r4["claims"] == {
        "findings_recorded": True,
        "candidate_redesign_integrated": True,
        "findings_closed": False,
        "architecture_frozen": False,
        "tla_authorized": False,
        "model_supported": False,
        "protection_evidenced": False,
    }, "R4 review overclaims")

    r5_rel = contract["fifth_hostile_architecture_review"]
    require(r5_rel ==
            "analysis/dynamic-residency-fifth-hostile-architecture-and-proof-review-v1.json",
            "R5 architecture review path changed")
    r5 = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / r5_rel), "R5 architecture review"))
    exact_keys(r5, {
        "schema_version", "id", "date", "work_record", "requirement",
        "analysis", "reviewed_contract", "reviewed_witness", "review_kind",
        "reviewer_identity_authenticated", "source_verdict",
        "review_provenance", "status", "finding_count", "finding_ids",
        "findings", "claims",
    }, "R5 architecture review")
    require(r5["schema_version"] == 1
            and r5["id"] ==
            "dynamic-residency-fifth-hostile-architecture-and-proof-review-v1"
            and r5["requirement"] == EXPECTED_REQUIREMENT
            and r5["reviewed_contract"] ==
            "dynamic-admission-recurring-residency-architecture-contract-v1.json"
            and r5["reviewed_witness"] ==
            "dynamic-residency-preformal-two-lane-witness-v1.json"
            and r5["reviewer_identity_authenticated"] is False
            and r5["source_verdict"] == "FREEZE_NO"
            and r5["status"] ==
            "redesign_integrated_strict_validator_mutations_complete_fresh_review_and_formal_refinement_pending",
            "R5 review identity, rejection, or status changed")
    require(r5["review_provenance"] == {
        "raw_independent_session_transcripts_retained_as_immutable_artifacts":
            False,
        "this_record_is_an_unattested_internal_discovery_synthesis": True,
        "may_count_as_external_freeze_acceptance_or_rejection_evidence": False,
        "future_disposition_requires_v2_1_2_checkpointed_signed_review_reveal":
            True,
    }, "R5 review provenance was upgraded or obscured")
    require(r5["finding_count"] == len(EXPECTED_R5_IDS)
            and r5["finding_ids"] == EXPECTED_R5_IDS
            and [row.get("id") for row in r5["findings"]]
            == EXPECTED_R5_IDS,
            "R5 finding inventory changed")
    for row in r5["findings"]:
        exact_keys(row, {
            "id", "severity", "finding", "required_response", "status",
        }, f"R5 finding {row.get('id')}")
        require(row["severity"] in {"blocker", "high", "medium"}
                and row["status"] == INTEGRATED_OPEN_STATUS,
                f"R5 finding was prematurely closed: {row['id']}")
    require(r5["claims"] == {
        "findings_recorded": True,
        "three_internal_discovery_passes_synthesized": True,
        "candidate_redesign_integrated": True,
        "strict_validator_and_mutation_suite_complete": True,
        "fresh_revised_bytes_reviewed": False,
        "findings_closed": False,
        "architecture_frozen": False,
        "tla_authorized": False,
        "model_supported": False,
        "protection_evidenced": False,
    }, "R5 review overclaims")

    assurance_rel = contract["assurance_v2_hostile_review"]
    require(assurance_rel ==
            "analysis/architecture-freeze-assurance-v2-hostile-review-v1.json",
            "assurance R4 review path changed")
    assurance = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / assurance_rel), "assurance R4 review"))
    exact_keys(assurance, {
        "schema_version", "id", "date", "work_record", "requirement",
        "analysis", "reviewed_protocol", "reviewed_fixture_verifier",
        "reviewed_real_stub", "review_provenance", "source_verdict",
        "status", "finding_count", "finding_ids", "findings", "claims",
    }, "assurance R4 review")
    require(assurance["schema_version"] == 3
            and assurance["status"] ==
            "redesign_integrated_fixture_hardened_real_implementation_and_fresh_external_review_pending"
            and assurance["source_verdict"] == "FREEZE_NO",
            "assurance rejection was converted into acceptance")
    provenance = exact_keys(assurance["review_provenance"], {
        "evidence_class", "reviewer_identity_authenticated", "source_locator",
        "source_material_retained_as_external_immutable_object",
        "source_snapshot_digests_complete_and_reproducible",
        "usable_as_external_freeze_evidence",
        "usable_as_finding_discovery_input",
    }, "assurance review provenance")
    require(provenance["evidence_class"] ==
            "unauthenticated_internal_discovery_only"
            and provenance["reviewer_identity_authenticated"] is False
            and provenance[
                "source_material_retained_as_external_immutable_object"] is False
            and provenance[
                "source_snapshot_digests_complete_and_reproducible"] is False
            and provenance["usable_as_external_freeze_evidence"] is False
            and provenance["usable_as_finding_discovery_input"] is True
            and isinstance(provenance["source_locator"], str)
            and bool(provenance["source_locator"]),
            "assurance review provenance was upgraded or obscured")
    require(assurance["reviewed_protocol"] ==
            "analysis/architecture-freeze-external-assurance-protocol-v2.json"
            and assurance["reviewed_fixture_verifier"] ==
            "validation/validate-architecture-freeze-assurance-v2.py"
            and assurance["reviewed_real_stub"] ==
            "validation/verify-architecture-freeze-assurance-v2-real.py",
            "assurance reviewed object set changed")
    require(assurance["finding_count"] == len(EXPECTED_ASSURANCE_R4_IDS)
            and assurance["finding_ids"] == EXPECTED_ASSURANCE_R4_IDS
            and [row.get("id") for row in assurance["findings"]]
            == EXPECTED_ASSURANCE_R4_IDS,
            "assurance R4 finding inventory changed")
    for row in assurance["findings"]:
        exact_keys(row, {
            "id", "severity", "finding", "candidate_response",
            "residual_obligation", "status",
        }, f"assurance R4 finding {row.get('id')}")
        require(row["severity"] in {"blocker", "high", "medium", "low"}
                and row["status"].startswith("open_"),
                f"assurance finding was prematurely closed: {row['id']}")
    require(assurance["claims"] == {
        "fresh_review_recorded_as_discovery_only": True,
        "fresh_review_is_external_freeze_evidence": False,
        "v2_1_2_protocol_redesign_integrated": True,
        "fixture_verifier_real_success_paths_removed": True,
        "separate_real_stub_unconditionally_rejects": True,
        "fixture_accept_and_reject_outputs_distinguished": True,
        "fixture_mutations_have_stable_rejection_contracts": True,
        "real_mode_assurance_implemented": False,
        "real_mode_assurance_validated": False,
        "findings_closed": False,
        "architecture_frozen": False,
        "tla_authorized": False,
    },
            "assurance R4 review overclaims")


def validate_assurance_protocol(root: Path, contract: dict[str, Any]) -> None:
    rel = contract["external_assurance_protocol"]
    require(rel == "analysis/architecture-freeze-external-assurance-protocol-v2.json",
            "external assurance protocol path changed")
    protocol = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / rel), "assurance protocol"))
    exact_keys(protocol, {
        "schema_version", "id", "protocol_revision", "requirement", "status",
        "evidence_state",
        "ordering", "canonicalization", "trust_chain", "campaign_log",
        "candidate_storage", "semantic_validation", "review_commit_reveal",
        "terminal_map_state_machine", "predecessor_history", "independence",
        "exact_object_schemas", "hash_transcripts", "machine_test_vectors",
        "validation_order", "result_provenance", "fixture", "claims",
        "residual_external_risks", "analysis",
    }, "assurance protocol")
    require(protocol["schema_version"] == 2
            and protocol["protocol_revision"] ==
            "2.1.2-noncyclic-terminal-map-redesign"
            and protocol["status"] ==
            "v2_1_architecture_selected_real_verifier_and_campaign_pending"
            and protocol["evidence_state"] ==
            "no_current_artifact_satisfies_real_mode",
            "assurance protocol status overclaims implementation")
    expected_order = [
        "externally_pinned_trust_root",
        "threshold_signed_campaign_policy",
        "externally_witnessed_policy_publication_checkpoint",
        "immutable_candidate_capsule_and_checkpointed_predecessor_chain",
        "externally_attested_object_retention",
        "author_and_independent_custodian_seal",
        "policy_pinned_hermetic_semantic_validation_quorum",
        "externally_signed_reviewer_roster",
        "one_signed_review_commitment_per_assignment",
        "all_commitments_external_checkpoint",
        "one_signed_review_reveal_per_assignment_bound_only_to_past_checkpoint_and_preallocated_map_key",
        "terminal_event_replay_and_authenticated_map_checkpoint_including_all_reveals",
        "deterministic_aggregate_decision",
        "threshold_signed_decision_authorization_bound_to_terminal_checkpoint",
        "derived_preformal_freeze_and_tla_start_authorization_without_candidate_mutation",
        "tla_plus_formalization",
    ]
    require(protocol["ordering"] == expected_order,
            "assurance/TLA order changed")
    expect(protocol, "canonicalization.floats_allowed", False)
    expect(protocol, "canonicalization.duplicate_or_unknown_keys_allowed", False)
    expect(protocol, "trust_chain.trust_root_digest_must_be_external_cli_input", True)
    expect(protocol, "trust_chain.policy_digest_must_be_external_cli_input", True)
    expect(protocol,
           "trust_chain.policy_checkpoint_digest_must_be_external_cli_input", True)
    expect(protocol,
           "trust_chain.terminal_checkpoint_digest_must_be_external_cli_input", True)
    expect(protocol, "trust_chain.repository_trust_discovery_or_TOFU_allowed",
           False)
    expect(protocol,
           "trust_chain.candidate_supplied_verifier_runtime_test_key_or_log_head_allowed_in_real_mode",
           False)
    expect(protocol, "trust_chain.candidate_bytes_change_after_capsule_seal", False)
    expect(protocol, "trust_chain.freeze_status_stored_in_candidate", False)
    expect(protocol,
           "campaign_log.policy_checkpoint_precedes_candidate_by_verified_tree_size_and_consistency_proof",
           True)
    expect(protocol,
           "campaign_log.terminal_checkpoint_extends_policy_and_commitment_checkpoints_by_verified_consistency_proofs",
           True)
    quorum = at(protocol, "campaign_log.checkpoint_witness_parameters")
    exact_keys(quorum, {
        "N", "t", "f", "minimum_two_quorum_intersection",
        "intersection_formula", "required_safety_inequality",
        "instantiated_safety_inequality", "honest_witness_rule",
        "claim_boundary",
    }, "checkpoint witness parameters")
    require(quorum["N"] == 4 and quorum["t"] == 3 and quorum["f"] == 1
            and quorum["minimum_two_quorum_intersection"] == 2
            and quorum["intersection_formula"] == "2*t-N"
            and quorum["required_safety_inequality"] == "2*t-N>f"
            and quorum["instantiated_safety_inequality"] == "2>1"
            and 2 * quorum["t"] - quorum["N"]
            == quorum["minimum_two_quorum_intersection"]
            and quorum["minimum_two_quorum_intersection"] > quorum["f"]
            and at(protocol,
                   "campaign_log.minimum_independent_checkpoint_witnesses")
            == quorum["t"],
            "checkpoint witness threshold or intersection safety changed")
    expect(protocol,
           "campaign_log.valid_campaign_submission_requires_object_signature_and_3_of_4_event_index_admission",
           True)
    expect(protocol,
           "campaign_log.all_event_indices_zero_through_terminal_tree_size_minus_one_are_supplied_and_replayed",
           True)
    expect(protocol, "campaign_log.one_terminal_submission_per_assignment", True)
    expect(protocol, "campaign_log.signed_rejection_is_absorbing", True)
    expect(protocol, "campaign_log.accept_sibling_can_hide_logged_rejection", False)
    expect(protocol,
           "candidate_storage.local_mode_bit_read_only_is_WORM_or_publication_evidence",
           False)
    expect(protocol,
           "candidate_storage.real_freeze_requires_external_retention_attestation",
           True)
    expect(protocol,
           "semantic_validation.real_mode_executes_repository_or_candidate_supplied_program",
           False)
    expect(protocol,
           "semantic_validation.validator_image_runtime_image_and_sandbox_policy_digests_fixed_at_policy_checkpoint",
           True)
    expect(protocol,
           "semantic_validation.startup_environment_network_clock_randomness_dynamic_loader_and_unpinned_plugins_available",
           False)
    require(at(protocol, "semantic_validation.required_matching_receipts") ==
            "2_of_3_independent_hermetic_runner_authorities",
            "semantic runner threshold changed")
    expect(protocol,
           "review_commit_reveal.all_four_commitments_checkpointed_before_any_reveal",
           True)
    expect(protocol,
           "review_commit_reveal.exactly_one_commitment_and_one_matching_reveal_per_assignment",
           True)
    expect(protocol,
           "review_commit_reveal.reveal_signature_binds_future_terminal_checkpoint",
           False)
    expect(protocol,
           "review_commit_reveal.terminal_checkpoint_later_includes_every_reveal",
           True)
    expect(protocol,
           "review_commit_reveal.decision_authorization_signs_terminal_checkpoint_digest",
           True)
    expect(protocol,
           "predecessor_history.real_campaign_requires_every_claimed_predecessor_checkpointed",
           True)
    expect(protocol,
           "predecessor_history.consistency_and_inclusion_proofs_form_bounded_nonforking_chain",
           True)
    expect(protocol,
           "result_provenance.downstream_consumer_must_exactly_pin_complete_tuple",
           True)
    expect(protocol,
           "result_provenance.accepted_preformal_freeze_sets_tla_authorized_for_exact_capsule_only",
           True)
    expect(protocol,
           "result_provenance.accepted_preformal_freeze_sets_tla_written_model_checked_or_tla_proved",
           False)
    terminal_machine = exact_keys(protocol["terminal_map_state_machine"], {
        "assignment_universe", "key_derivation", "initial_state",
        "transitions", "acceptance_predicate", "rejection_predicate",
        "completeness_proof", "hidden_sibling_result", "external_assumption",
    }, "terminal map state machine")
    transitions = unique_strings(terminal_machine["transitions"],
                                 "terminal map transitions")
    require(terminal_machine["initial_state"] == "UNSET"
            and len(transitions) == 8
            and any("REJECTED_or_REJECTED_INCOMPLETE_or_REJECTED_CONFLICT_remains_absorbing"
                    == item for item in transitions)
            and terminal_machine["acceptance_predicate"].startswith(
                "exactly_four_unique_roster_keys_each_ACCEPTED")
            and terminal_machine["rejection_predicate"].startswith(
                "any_non_ACCEPTED_entry"),
            "terminal map completeness or absorbing rejection changed")
    schemas = protocol["exact_object_schemas"]
    require(isinstance(schemas, dict), "assurance object schemas must be a map")
    reveal_schema = exact_keys(schemas["SignedReviewRevealPayload"], {
        "schema", "exact_keys", "forbidden_keys", "signed_by",
    }, "signed review reveal schema")
    reveal_keys = unique_strings(reveal_schema["exact_keys"],
                                 "signed review reveal exact keys")
    forbidden_reveal_keys = unique_strings(
        reveal_schema["forbidden_keys"], "signed review reveal forbidden keys")
    require(reveal_schema["schema"] ==
            "linux-cap.archfreeze.v2.signed-review-reveal"
            and set(forbidden_reveal_keys) == {
                "terminal_checkpoint_digest", "future_checkpoint_digest",
            }
            and set(reveal_keys).isdisjoint(forbidden_reveal_keys)
            and "commitment_checkpoint_digest" in reveal_keys
            and "terminal_map_key" in reveal_keys,
            "review reveal schema reintroduced a future-checkpoint cycle")
    terminal_map_schema = exact_keys(schemas["CampaignTerminalMap"], {
        "schema", "exact_keys", "fixed_values",
    }, "campaign terminal map schema")
    require(terminal_map_schema["fixed_values"] == {"entry_count": 4},
            "campaign terminal map is not an authenticated four-key map")
    replay_schema = exact_keys(schemas["CampaignEventReplay"], {
        "schema", "exact_keys", "exact_relations",
    }, "campaign event replay schema")
    replay_relations = set(unique_strings(
        replay_schema["exact_relations"], "campaign replay relations"))
    require({
        "events_are_contiguous_and_zero_based",
        "each_admission_matches_same_position_event_object_and_post_append_root",
        "replaying_all_events_produces_exact_terminal_map_digest_and_root",
    } <= replay_relations,
            "campaign replay no longer proves a complete terminal map")
    decision_schema = exact_keys(schemas["DecisionAuthorizationPayload"], {
        "schema", "exact_keys", "signed_by",
    }, "decision authorization schema")
    require("terminal_checkpoint_digest" in decision_schema["exact_keys"]
            and decision_schema["signed_by"] ==
            "exact_2_of_3_policy_pinned_independent_decision_authorities",
            "decision authorization does not bind the terminal checkpoint")
    require(protocol["fixture"]["exact_schema_and_signature_prefix"] ==
            "linux-cap.archfreeze.fixture.v2",
            "fixture namespace changed")
    fixture = protocol["fixture"]
    output_keys = unique_strings(fixture["output_exact_keys"],
                                 "assurance fixture output keys")
    accept_result = exact_keys(fixture["valid_accept_result"],
                               set(output_keys), "fixture accept result")
    reject_result = exact_keys(fixture["valid_reject_result"],
                               set(output_keys), "fixture reject result")
    require(accept_result["campaign_decision"] == "accept"
            and reject_result["campaign_decision"] == "reject"
            and accept_result != reject_result
            and accept_result["evidence_class"]
            == reject_result["evidence_class"] == "fixture"
            and accept_result["evidence_valid"] is True
            and reject_result["evidence_valid"] is True
            and all(result[name] is False
                    for result in (accept_result, reject_result)
                    for name in ("architecture_frozen", "freeze_authorized",
                                 "tla_authorized")),
            "fixture ACCEPT/REJECT result boundary changed")
    expect(protocol, "fixture.real_private_keys_in_repository_workspace_or_CI", False)
    claims = protocol["claims"]
    require(claims == {
        "protocol_written": True,
        "protocol_implemented": False,
        "fixture_verifier_implemented": True,
        "real_verifier_implemented": False,
        "real_trust_root_pinned": False,
        "real_policy_checkpoint_verified": False,
        "real_candidate_sealed": False,
        "real_retention_attested": False,
        "real_semantic_validation_quorum_verified": False,
        "real_independent_reviews_verified": False,
        "real_terminal_checkpoint_verified": False,
        "architecture_frozen": False,
        "tla_authorized": False,
        "protection_evidenced": False,
    },
            "assurance protocol claims real evidence")

    verifier_path = resolve_regular_file(
        root,
        "capsched-models/validation/validate-architecture-freeze-assurance-v2.py",
        "assurance fixture verifier")
    verifier_text = artifact_text(verifier_path)
    require(all(token not in verifier_text for token in (
        "REAL_ACCEPT_GRANTS", "verify-real", '"real-external"',
    )), "fixture verifier contains a real assurance path")
    verifier_tree = ast.parse(verifier_text, filename=str(verifier_path))
    frozen_fields = 0
    for node in ast.walk(verifier_tree):
        if not isinstance(node, ast.Dict):
            continue
        for key, value in zip(node.keys, node.values):
            if isinstance(key, ast.Constant) \
                    and key.value == "architecture_frozen":
                frozen_fields += 1
                require(isinstance(value, ast.Constant)
                        and value.value is False,
                        "fixture verifier can emit architecture_frozen=true")
    require(frozen_fields > 0,
            "fixture verifier does not explicitly encode its claim ceiling")
    for phrase in (
        "start_new_session=True",
        "preexec_fn=semantic_fixture_child_limits",
        "os.killpg(process.pid, signal.SIGKILL)",
        "require_finding_id",
        '"tla_authorized": False',
        '"campaign_decision": aggregate["decision"]',
    ):
        require(phrase in verifier_text,
                f"assurance fixture hardening missing: {phrase}")
    real_stub_rel = fixture["real_verifier_file"]
    require(real_stub_rel ==
            "validation/verify-architecture-freeze-assurance-v2-real.py"
            and fixture["real_verifier_behavior"] ==
            "unconditional_AFV2_REAL_UNIMPLEMENTED_before_argument_or_evidence_parsing",
            "real verifier stub boundary changed")
    real_stub_path = resolve_regular_file(
        root, str(ANALYSIS_PREFIX / real_stub_rel), "real assurance stub")
    real_stub_text = artifact_text(real_stub_path)
    real_stub_tree = ast.parse(real_stub_text, filename=str(real_stub_path))
    imported_modules: set[str] = set()
    for node in ast.walk(real_stub_tree):
        if isinstance(node, ast.Import):
            imported_modules.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module != "__future__":
            imported_modules.add(node.module or "")
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            require(node.func.id not in {
                "open", "exec", "eval", "compile", "input",
            }, "real assurance stub contains evidence I/O or code execution")
    require(imported_modules <= {"sys"}
            and all(token not in real_stub_text for token in (
                "argparse", "pathlib", "json", "subprocess", "socket",
            )), "real assurance stub can parse or fetch evidence")
    stub_result = subprocess.run(
        [sys.executable, str(real_stub_path), "--hostile-unused-argument",
         "/nonexistent/evidence"],
        cwd=root, capture_output=True, text=True, timeout=5, check=False,
        env={"PYTHONDONTWRITEBYTECODE": "1"},
    )
    require(stub_result.returncode == 78
            and stub_result.stdout == ""
            and stub_result.stderr.startswith("AFV2_REAL_UNIMPLEMENTED:")
            and "no evidence was parsed" in stub_result.stderr
            and "no claim was authorized" in stub_result.stderr,
            "real assurance stub did not reject before evidence parsing")


def natural(value: Any) -> bool:
    return type(value) is int and value >= 0


def nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value)


def require_natural_fields(value: dict[str, Any], names: tuple[str, ...],
                           label: str) -> None:
    require(all(natural(value[name]) for name in names),
            f"{label} fields must be naturals")


def require_boolean_fields(value: dict[str, Any], names: tuple[str, ...],
                           label: str) -> None:
    require(all(type(value[name]) is bool for name in names),
            f"{label} fields must be booleans")


def require_string_fields(value: dict[str, Any], names: tuple[str, ...],
                          label: str) -> None:
    require(all(nonempty_string(value[name]) for name in names),
            f"{label} fields must be nonempty strings")


def witness_check(condition: bool, scenario: str, check: str,
                  executed: list[str]) -> None:
    require(condition, f"witness check failed: {scenario}/{check}")
    executed.append(check)


def one_way_states(states: Any) -> bool:
    if not isinstance(states, list) or not states or states[0] != "Unbound":
        return False
    allowed = {
        "Unbound": {"Reserved", "Expired"},
        "Reserved": {"Consumed", "Expired"},
        "Consumed": {"Settled"},
        "Expired": set(),
        "Settled": set(),
    }
    return all(
        isinstance(left, str) and isinstance(right, str)
        and right in allowed.get(left, set())
        for left, right in zip(states, states[1:])
    ) and len(states) == len(set(states))


def exact_executable(value: Any, machine: str, keys: set[str]) -> dict[str, Any]:
    row = exact_keys(value, keys | {"machine", "required_checks"},
                     f"witness machine {machine}")
    require(row["machine"] == machine, f"witness machine mismatch: {machine}")
    unique_strings(row["required_checks"], f"{machine}.required_checks")
    return row


def finish_witness_checks(scenario: str, executable: dict[str, Any],
                          executed: list[str]) -> None:
    require(executed == executable["required_checks"],
            f"witness checks missing, reordered, or unexecuted: {scenario}; "
            f"declared={executable['required_checks']} executed={executed}")


def execute_hierarchy(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "hierarchy_capacity", {
        "paths", "max_depth", "proof_bytes", "vector_bytes",
        "mutation_footprint_entries", "bounds", "reservations",
    })
    done: list[str] = []
    paths = ex["paths"]
    require(natural(ex["max_depth"]) and ex["max_depth"] > 0,
            f"invalid hierarchy depth: {scenario}")
    witness_check(isinstance(paths, dict) and set(paths) == {"A", "B"}
                  and all(isinstance(path, list) and path
                          and len(path) <= ex["max_depth"]
                          and all(nonempty_string(node) for node in path)
                          for path in paths.values()),
                  scenario, "all_paths_within_depth", done)
    bounds = exact_keys(ex["bounds"], {
        "proof_bytes", "vector_bytes", "mutation_footprint_entries",
    }, f"{scenario}.bounds")
    witness_check(all(natural(ex[name]) and natural(bounds[name])
                      and ex[name] <= bounds[name] for name in bounds),
                  scenario, "all_serialized_bounds_hold", done)
    reservations = ex["reservations"]
    require(isinstance(reservations, dict) and reservations,
            f"invalid reservations: {scenario}")
    totals: list[tuple[int, int]] = []
    for name, reservation in reservations.items():
        row = exact_keys(reservation, {
            "capacity", "current", "pending", "retiring", "failure_escrow",
        }, f"{scenario}.reservations.{name}")
        require(all(natural(item) for item in row.values()),
                f"non-natural hierarchy capacity: {name}")
        totals.append((row["capacity"], row["current"] + row["pending"]
                       + row["retiring"] + row["failure_escrow"]))
    witness_check(all(total <= capacity for capacity, total in totals),
                  scenario, "every_ancestor_capacity_conserved", done)
    witness_check(any(total == capacity and total + 1 > capacity
                      for capacity, total in totals),
                  scenario, "over_capacity_demand_rejected", done)
    finish_witness_checks(scenario, ex, done)


def execute_hardware_cells(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "hardware_execution_cells", {
        "hardware_frame", "execution_frame", "leases", "use_cells",
        "token_executions",
    })
    done: list[str] = []
    hardware = exact_keys(ex["hardware_frame"], {
        "capacity", "occurrences", "partitions",
    }, f"{scenario}.hardware_frame")
    hardware_occurrences = unique_strings(
        hardware["occurrences"], f"{scenario}.hardware.occurrences")
    hardware_partitions = exact_keys(hardware["partitions"], {
        "protected_control", "domain_execution", "management",
        "emergency", "slack",
    }, f"{scenario}.hardware.partitions")
    hardware_parts = [
        unique_strings(hardware_partitions[name],
                       f"{scenario}.hardware.{name}")
        for name in hardware_partitions
    ]
    hardware_flat = [item for part in hardware_parts for item in part]
    witness_check(natural(hardware["capacity"])
                  and hardware["capacity"] > 0
                  and len(hardware_occurrences) == hardware["capacity"]
                  and len(hardware_flat) == len(set(hardware_flat))
                  and set(hardware_flat) == set(hardware_occurrences),
                  scenario, "shared_hardware_exact_partition", done)
    execution = exact_keys(ex["execution_frame"], {
        "capacity", "parent_partition", "occurrences", "partitions",
    }, f"{scenario}.execution_frame")
    execution_occurrences = unique_strings(
        execution["occurrences"], f"{scenario}.execution.occurrences")
    execution_partitions = exact_keys(execution["partitions"], {
        "management", "emergency", "lane_A", "lane_B", "slack",
    }, f"{scenario}.execution.partitions")
    execution_parts = [
        unique_strings(execution_partitions[name],
                       f"{scenario}.execution.{name}")
        for name in execution_partitions
    ]
    execution_flat = [item for part in execution_parts for item in part]
    witness_check(execution["parent_partition"] == "domain_execution"
                  and natural(execution["capacity"])
                  and execution["capacity"] == len(execution_occurrences)
                  and set(execution_occurrences)
                  == set(hardware_partitions["domain_execution"])
                  and len(execution_flat) == len(set(execution_flat))
                  and set(execution_flat) == set(execution_occurrences),
                  scenario, "execution_is_exact_parent_subset_partition", done)
    leases = ex["leases"]
    require(isinstance(leases, list) and len(leases) >= 4,
            "execution lease witness is too small")
    lease_keys = {
        "id", "physical_occurrence", "occurrence", "lane", "context",
        "activation_slot_id", "start", "end", "entry_exit_guard",
        "token_budget", "unused", "target_lease_clock_epoch",
        "normalized_not_after", "normalized_source_count", "issued_at",
    }
    for lease in leases:
        exact_keys(lease, lease_keys, f"{scenario}.lease")
        require(all(isinstance(lease[name], str) and lease[name]
                    for name in ("id", "physical_occurrence", "occurrence",
                                 "lane", "context", "activation_slot_id"))
                and lease["lane"] in {"lane_A", "lane_B"}
                and all(natural(lease[name]) for name in (
                    "start", "end", "entry_exit_guard", "token_budget",
                    "unused", "target_lease_clock_epoch",
                    "normalized_not_after", "normalized_source_count",
                    "issued_at",
                )), f"invalid execution lease: {lease.get('id')}")
    witness_check(all(
        row["physical_occurrence"] in execution_partitions[row["lane"]]
        for row in leases
    ), scenario, "lease_occurrence_matches_lane_partition", done)
    witness_check(len({row["occurrence"] for row in leases}) == len(leases)
                  and len({row["id"] for row in leases}) == len(leases)
                  and len({row["physical_occurrence"] for row in leases})
                  == len(leases)
                  and len({row["activation_slot_id"] for row in leases})
                  == len(leases)
                  and all(row["occurrence"]
                          == f"{row['context']}:{row['start']}:{row['end']}"
                          for row in leases),
                  scenario, "unique_schedule_occurrence", done)
    lease_by_id = {row["id"]: row for row in leases}
    use_cells = ex["use_cells"]
    require(isinstance(use_cells, list) and len(use_cells) == len(leases),
            "one use cell is required for every lease")
    use_keys = {
        "id", "lease", "physical_occurrence", "activation_slot_id",
        "intent_prepared_at", "bound_intent_digest", "decision_cell",
        "states",
    }
    use_by_id: dict[str, dict[str, Any]] = {}
    use_by_lease: dict[str, dict[str, Any]] = {}
    for use in use_cells:
        exact_keys(use, use_keys, f"{scenario}.use_cell")
        require(all(isinstance(use[name], str) and use[name]
                    for name in ("id", "lease", "physical_occurrence",
                                 "activation_slot_id", "bound_intent_digest",
                                 "decision_cell"))
                and natural(use["intent_prepared_at"])
                and use["id"] not in use_by_id
                and use["lease"] not in use_by_lease,
                "invalid or duplicate execution use cell")
        use_by_id[use["id"]] = use
        use_by_lease[use["lease"]] = use
    witness_check(set(use_by_lease) == set(lease_by_id)
                  and all(
                      use_by_lease[row["id"]]["physical_occurrence"]
                      == row["physical_occurrence"]
                      and use_by_lease[row["id"]]["activation_slot_id"]
                      == row["activation_slot_id"]
                      and row["issued_at"]
                      < use_by_lease[row["id"]]["intent_prepared_at"]
                      and use_by_lease[row["id"]]["bound_intent_digest"]
                      .startswith("sha256:")
                      and row["normalized_source_count"] == 7
                      and row["target_lease_clock_epoch"] > 0
                      for row in leases
                  )
                  and len({row["decision_cell"] for row in use_cells})
                  == len(use_cells),
                  scenario, "allocator_slot_precedes_intent_binding", done)
    witness_check(all(use_by_lease[row["id"]]["intent_prepared_at"]
                      < row["start"] < row["end"] for row in leases),
                  scenario, "prepare_precedes_due", done)
    witness_check(all(one_way_states(row["states"]) for row in use_cells),
                  scenario, "one_way_use_state_from_unbound", done)
    witness_check(all(row["end"] - row["start"] == row["entry_exit_guard"]
                      + row["token_budget"] + row["unused"]
                      and row["token_budget"] > 0 for row in leases),
                  scenario, "cell_budget_sum", done)
    tokens = ex["token_executions"]
    require(isinstance(tokens, list), "token_executions must be an array")
    token_keys = {
        "token", "lease", "use_cell", "activation_slot_id", "context",
        "entry_permit_uses", "decision_state", "settlement_state",
        "segments", "reported_consumed_budget",
        "replay_after_settlement_executable",
    }
    token_by_lease: dict[str, dict[str, Any]] = {}
    token_ids: set[str] = set()
    for token in tokens:
        exact_keys(token, token_keys, f"{scenario}.token_execution")
        require(all(isinstance(token[name], str) and token[name]
                    for name in ("token", "lease", "use_cell",
                                 "activation_slot_id", "context"))
                and token["token"] not in token_ids
                and token["lease"] not in token_by_lease,
                "duplicate token or lease execution")
        require(token["lease"] in lease_by_id
                and token["use_cell"] in use_by_id
                and use_by_id[token["use_cell"]]["lease"] == token["lease"],
                "token execution references an unknown or mismatched use")
        token_ids.add(token["token"])
        token_by_lease[token["lease"]] = token
        segments = token["segments"]
        require(isinstance(segments, list) and segments,
                "token execution must contain segments")
        for segment in segments:
            exact_keys(segment, {"resume_sequence", "start", "end"},
                       f"{scenario}.segment")
            require(all(natural(segment[name]) for name in segment),
                    "execution segment values must be naturals")
    executable_uses = [row for row in use_cells if row["states"][-1] == "Settled"]
    witness_check(set(token_by_lease) == {row["lease"] for row in executable_uses}
                  and all(
                      token_by_lease[row["lease"]]["use_cell"] == row["id"]
                      and token_by_lease[row["lease"]]["activation_slot_id"]
                      == row["activation_slot_id"]
                      and token_by_lease[row["lease"]]["context"]
                      == lease_by_id[row["lease"]]["context"]
                      for row in executable_uses
                  ),
                  scenario, "token_lease_slot_bijection", done)
    cumulative_ok = True
    interval_ok = True
    resume_ok = True
    flattened: list[tuple[str, int, int]] = []
    for lease_id, token in token_by_lease.items():
        lease = lease_by_id[lease_id]
        consumed = sum(segment["end"] - segment["start"]
                       for segment in token["segments"])
        cumulative_ok = cumulative_ok and natural(token["entry_permit_uses"]) \
            and natural(token["reported_consumed_budget"]) \
            and token["entry_permit_uses"] == 1 \
            and consumed == token["reported_consumed_budget"] \
            and consumed <= lease["token_budget"]
        interval_ok = interval_ok and all(
            lease["start"] <= segment["start"] < segment["end"]
            <= min(lease["end"], lease["normalized_not_after"])
            for segment in token["segments"]
        )
        resume_ok = resume_ok and [
            segment["resume_sequence"] for segment in token["segments"]
        ] == list(range(len(token["segments"])))
        flattened.extend((token["context"], segment["start"], segment["end"])
                         for segment in token["segments"])
    witness_check(cumulative_ok, scenario,
                  "one_use_entry_and_cumulative_budget", done)
    witness_check(interval_ok, scenario,
                  "segments_within_cell_and_normalized_horizon", done)
    witness_check(resume_ok, scenario, "resume_sequences_monotonic", done)
    overlap_free = True
    by_context: dict[str, list[tuple[int, int]]] = {}
    for context, start, end in flattened:
        by_context.setdefault(context, []).append((start, end))
    for rows in by_context.values():
        ordered = sorted(rows)
        overlap_free = overlap_free and all(
            left[1] <= right[0]
            for left, right in zip(ordered, ordered[1:])
        )
    witness_check(overlap_free, scenario, "no_context_overlap", done)
    witness_check(all(token["decision_state"] == "Settled"
                      and token["settlement_state"] == "Settled"
                      and token["replay_after_settlement_executable"] is False
                      for token in tokens),
                  scenario, "settled_token_replay_rejected", done)
    expired_use_ids = {row["id"] for row in use_cells
                       if row["states"][-1] == "Expired"}
    witness_check(expired_use_ids
                  and expired_use_ids.isdisjoint(
                      {row["use_cell"] for row in tokens}),
                  scenario, "expired_has_no_token", done)
    expired = [row for row in use_cells if row["states"][-1] == "Expired"]
    retry_pairs: list[tuple[dict[str, Any], dict[str, Any]]] = []
    for old_use in expired:
        old_lease = lease_by_id[old_use["lease"]]
        for new_use in executable_uses:
            new_lease = lease_by_id[new_use["lease"]]
            if (new_lease["lane"] == old_lease["lane"]
                    and new_lease["start"] >= old_lease["end"]):
                retry_pairs.append((old_use, new_use))
    witness_check(len(expired) == 1 and len(retry_pairs) == 1
                  and retry_pairs[0][0]["lease"] != retry_pairs[0][1]["lease"]
                  and retry_pairs[0][0]["physical_occurrence"]
                  != retry_pairs[0][1]["physical_occurrence"]
                  and retry_pairs[0][0]["activation_slot_id"]
                  != retry_pairs[0][1]["activation_slot_id"],
                  scenario, "retry_uses_fresh_occurrence", done)
    finish_witness_checks(scenario, ex, done)


def execute_target_control(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "target_control_conservation", {
        "initial", "dispatches", "anchors", "post_state_lane_turns",
    })
    done: list[str] = []
    initial = exact_keys(ex["initial"], {
        "control_turn", "target_A", "target_B",
    }, f"{scenario}.initial")
    require(all(natural(item) for item in initial.values()),
            "invalid initial target-control state")
    state = dict(initial)
    dispatches = ex["dispatches"]
    require(isinstance(dispatches, list) and dispatches,
            "target dispatches must be a nonempty array")
    one_shard = True
    one_target = True
    other_unchanged = True
    for dispatch in dispatches:
        exact_keys(dispatch, {"target", "after"}, f"{scenario}.dispatch")
        target = dispatch["target"]
        after = exact_keys(dispatch["after"], set(state),
                           f"{scenario}.dispatch.after")
        require(nonempty_string(target)
                and target in {"target_A", "target_B"}
                and all(natural(item) for item in after.values()),
                "invalid target dispatch")
        one_shard = one_shard and after["control_turn"] - state["control_turn"] == 1
        deltas = {name: after[name] - state[name]
                  for name in ("target_A", "target_B")}
        one_target = one_target and deltas[target] == 1 \
            and sum(deltas.values()) == 1
        peer = "target_B" if target == "target_A" else "target_A"
        other_unchanged = other_unchanged and deltas[peer] == 0
        state = dict(after)
    witness_check(one_shard, scenario, "one_shard_turn_per_dispatch", done)
    witness_check(one_target, scenario, "exactly_one_target_advances", done)
    witness_check(other_unchanged, scenario, "other_target_unchanged", done)
    anchors = exact_keys(ex["anchors"], {"target_A", "target_B"},
                         f"{scenario}.anchors")
    post_turns = exact_keys(ex["post_state_lane_turns"], {
        "target_A", "target_B",
    }, f"{scenario}.post_state_lane_turns")
    require(all(natural(item) for item in post_turns.values()),
            "post-state lane turns must be naturals")
    quota_ok = True
    for target, anchor in anchors.items():
        exact_keys(anchor, {"lane_turn", "target_turn", "min_control_per_lane",
                            "max_initial_lead"}, f"{scenario}.anchor.{target}")
        require(all(natural(item) for item in anchor.values()),
                f"target-control anchor values must be naturals: {target}")
        lhs = anchor["min_control_per_lane"] * max(
            0, post_turns[target]
            - anchor["lane_turn"] - anchor["max_initial_lead"])
        rhs = state[target] - anchor["target_turn"]
        quota_ok = quota_ok and anchor["min_control_per_lane"] > 0 and lhs <= rhs
    witness_check(quota_ok, scenario, "post_anchor_quota_holds", done)
    finish_witness_checks(scenario, ex, done)


def execute_partition(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "partition_import", {
        "certificate_installed_at", "issuer_earliest_safe_expiry",
        "issuer_latest_possible_expiry", "disconnect_tick",
        "max_offline_duration", "modes",
    })
    done: list[str] = []
    require_natural_fields(ex, (
        "certificate_installed_at", "issuer_earliest_safe_expiry",
        "issuer_latest_possible_expiry", "disconnect_tick",
        "max_offline_duration",
    ), f"{scenario}.partition")
    require(ex["max_offline_duration"] > 0,
            "partition offline duration must be positive")
    modes = ex["modes"]
    require(isinstance(modes, dict)
            and set(modes) == {"CONNECTED_ONLY",
                               "CONTINUE_TO_CONSERVATIVE_EXPIRY",
                               "RECOVERY_ONLY"}, "partition modes changed")
    connected = exact_keys(modes["CONNECTED_ONLY"], {
        "connectivity", "ordinary_release", "ordinary_activation",
    }, f"{scenario}.CONNECTED_ONLY")
    conservative = exact_keys(modes["CONTINUE_TO_CONSERVATIVE_EXPIRY"], {
        "computed_deadline", "allow_tick", "deny_tick",
    }, f"{scenario}.CONTINUE_TO_CONSERVATIVE_EXPIRY")
    recovery = exact_keys(modes["RECOVERY_ONLY"], {
        "connectivity", "ordinary_release_at_install",
        "ordinary_activation_at_install", "bootstrap_recovery",
    }, f"{scenario}.RECOVERY_ONLY")
    require_boolean_fields(connected, (
        "connectivity", "ordinary_release", "ordinary_activation",
    ), f"{scenario}.CONNECTED_ONLY")
    require_natural_fields(conservative, (
        "computed_deadline", "allow_tick", "deny_tick",
    ), f"{scenario}.CONTINUE_TO_CONSERVATIVE_EXPIRY")
    require_boolean_fields(recovery, (
        "connectivity", "ordinary_release_at_install",
        "ordinary_activation_at_install", "bootstrap_recovery",
    ), f"{scenario}.RECOVERY_ONLY")
    expected_deadline = min(ex["issuer_earliest_safe_expiry"],
                            ex["disconnect_tick"] + ex["max_offline_duration"])
    witness_check(ex["issuer_earliest_safe_expiry"]
                  <= ex["issuer_latest_possible_expiry"]
                  and conservative["computed_deadline"] == expected_deadline,
                  scenario, "conservative_deadline_is_minimum", done)
    witness_check(connected["connectivity"] is False
                  and connected["ordinary_release"] is False
                  and connected["ordinary_activation"] is False,
                  scenario, "connected_only_requires_evidence", done)
    witness_check(ex["certificate_installed_at"] < expected_deadline
                  and recovery["ordinary_release_at_install"] is False
                  and recovery["ordinary_activation_at_install"] is False
                  and recovery["bootstrap_recovery"] is True,
                  scenario, "recovery_only_blocks_from_installation", done)
    witness_check(recovery["connectivity"] is True
                  and not recovery["ordinary_release_at_install"]
                  and not recovery["ordinary_activation_at_install"],
                  scenario, "connectivity_cannot_reopen_recovery_only", done)
    witness_check(conservative["allow_tick"] < expected_deadline
                  and conservative["deny_tick"] == expected_deadline,
                  scenario, "expiry_is_half_open", done)
    finish_witness_checks(scenario, ex, done)


def execute_placement(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "placement_horizon_supersession", {
        "target_lease_clock_epoch", "required_source_classes",
        "deadline_entries", "expected_effective_horizon",
        "predecessor_global_placement", "raw_cross_clock_minimum_allowed",
        "lease_only_extension", "fresh_global_placement",
        "bounded_residual_effect_horizons", "clock_uncertainty",
        "protected_stop_bound", "activation_not_before",
        "unbounded_effect_classes", "exact_source_quiescence_present_for_unbounded",
        "time_supersession_allowed_for_unbounded",
    })
    done: list[str] = []
    source_classes = unique_strings(
        ex["required_source_classes"], f"{scenario}.required_source_classes")
    expected_classes = [
        "frozen_lease", "node_lease_import", "global_placement",
        "security_use", "retirement_fence", "execution_cell", "root_budget",
    ]
    entries = ex["deadline_entries"]
    require(isinstance(entries, list), "deadline entries must be an array")
    entry_keys = {
        "source_class", "source_clock", "source_epoch", "source_expiry",
        "conversion_certificate", "target_epoch", "conservative_not_after",
    }
    normalized: dict[str, int] = {}
    clocks: set[tuple[str, int]] = set()
    entries_well_typed = True
    for entry in entries:
        exact_keys(entry, entry_keys, f"{scenario}.deadline_entry")
        entries_well_typed = entries_well_typed and all(
            isinstance(entry[name], str) and bool(entry[name])
            for name in ("source_class", "source_clock",
                         "conversion_certificate")
        ) and all(natural(entry[name]) for name in (
            "source_epoch", "source_expiry", "target_epoch",
            "conservative_not_after",
        )) and entry["source_epoch"] > 0 and entry["source_expiry"] > 0 \
            and entry["conservative_not_after"] > 0
        if isinstance(entry.get("source_class"), str):
            require(entry["source_class"] not in normalized,
                    "duplicate normalized deadline source class")
            normalized[entry["source_class"]] = entry["conservative_not_after"]
        if (isinstance(entry.get("source_clock"), str)
                and natural(entry.get("source_epoch"))):
            clocks.add((entry["source_clock"], entry["source_epoch"]))
    witness_check(source_classes == expected_classes
                  and entries_well_typed
                  and len(entries) == len(expected_classes)
                  and set(normalized) == set(expected_classes),
                  scenario, "deadline_source_schema_complete_unique", done)
    witness_check(natural(ex["target_lease_clock_epoch"])
                  and ex["target_lease_clock_epoch"] > 0
                  and all(entry["target_epoch"]
                          == ex["target_lease_clock_epoch"] for entry in entries),
                  scenario, "all_deadlines_normalized_to_exact_target_epoch",
                  done)
    witness_check(ex["raw_cross_clock_minimum_allowed"] is False
                  and len(clocks) > 1,
                  scenario, "raw_cross_clock_minimum_rejected", done)
    witness_check(natural(ex["expected_effective_horizon"])
                  and min(normalized.values())
                  == ex["expected_effective_horizon"], scenario,
                  "effective_horizon_is_conservative_minimum", done)
    predecessor = exact_keys(ex["predecessor_global_placement"], {
        "ownership_epoch", "fencing_token", "normalized_horizon",
    }, f"{scenario}.predecessor_global_placement")
    require(all(natural(item) for item in predecessor.values()),
            "predecessor placement values must be naturals")
    extension = exact_keys(ex["lease_only_extension"], {
        "new_frozen_lease", "unchanged_global_placement",
        "requested_release_tick", "allowed",
    }, f"{scenario}.lease_only_extension")
    witness_check(all(natural(extension[name]) for name in (
                      "new_frozen_lease", "unchanged_global_placement",
                      "requested_release_tick"))
                  and extension["unchanged_global_placement"]
                  == predecessor["normalized_horizon"]
                  == normalized["global_placement"]
                  and extension["new_frozen_lease"]
                  > extension["unchanged_global_placement"]
                  and extension["requested_release_tick"]
                  > extension["unchanged_global_placement"]
                  and extension["allowed"] is False,
                  scenario, "lease_only_extension_rejected", done)
    fresh = exact_keys(ex["fresh_global_placement"], {
        "new_ownership_epoch", "new_fencing_token", "new_horizon",
        "requested_release_tick", "allowed",
    }, f"{scenario}.fresh_global_placement")
    witness_check(all(natural(fresh[name]) for name in (
                      "new_ownership_epoch", "new_fencing_token",
                      "new_horizon", "requested_release_tick"))
                  and fresh["requested_release_tick"] < fresh["new_horizon"]
                  and fresh["allowed"] is True,
                  scenario, "fresh_placement_can_extend", done)
    residual = exact_keys(ex["bounded_residual_effect_horizons"], {
        "cpu", "device_queue", "dma_write",
    }, f"{scenario}.bounded_residual_effect_horizons")
    require(all(natural(item) for item in residual.values())
            and natural(ex["clock_uncertainty"])
            and natural(ex["protected_stop_bound"])
            and natural(ex["activation_not_before"]),
            "residual effect horizon values must be naturals")
    threshold = max(residual.values()) + ex["clock_uncertainty"] \
        + ex["protected_stop_bound"]
    witness_check(ex["activation_not_before"] > threshold,
                  scenario, "activation_strictly_after_all_residual_effects", done)
    unbounded = unique_strings(ex["unbounded_effect_classes"],
                               f"{scenario}.unbounded_effect_classes")
    witness_check(bool(unbounded)
                  and ex["exact_source_quiescence_present_for_unbounded"] is False
                  and ex["time_supersession_allowed_for_unbounded"] is False,
                  scenario, "unbounded_effect_rejects_time_supersession", done)
    witness_check(fresh["new_ownership_epoch"]
                  > predecessor["ownership_epoch"]
                  and fresh["new_fencing_token"]
                  > predecessor["fencing_token"],
                  scenario, "successor_epoch_and_token_advance", done)
    finish_witness_checks(scenario, ex, done)


def tree_ancestors(parent: dict[str, Any], node: str) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    current: Any = node
    while current is not None:
        require(isinstance(current, str) and current in parent,
                f"failure cover tree has unknown node: {current}")
        require(current not in seen, "failure cover tree has a cycle")
        seen.add(current)
        result.append(current)
        current = parent[current]
    return result


def tree_lca(parent: dict[str, Any], nodes: list[str]) -> str:
    require(nodes, "LCA requires a nonempty set")
    first = tree_ancestors(parent, nodes[0])
    others = [set(tree_ancestors(parent, node)) for node in nodes[1:]]
    for candidate in first:
        if all(candidate in ancestors for ancestors in others):
            return candidate
    raise ValidationError("failure cover tree has no common root")


def execute_failure_cover(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "failure_cover_and_escrow", {
        "cover_tree_parent", "stable_order", "publication_snapshot",
        "closure_seed", "reverse_index", "claimed_iterations",
        "closure_bounds", "max_failure_scopes", "expected_union",
        "expected_cover", "root_case_union", "root_case_result",
        "capacity_before", "capacity_after_commit",
        "capacity_after_terminal_cleanup", "leaf_reverse_edges",
        "cover_ancestor_cleanup_reservations", "cleanup_steps",
        "unaffected_scope",
    })
    done: list[str] = []
    parent = ex["cover_tree_parent"]
    require(isinstance(parent, dict) and parent,
            "failure cover parent map must be nonempty")
    require(all(isinstance(node, str) and node
                and (owner is None or isinstance(owner, str))
                for node, owner in parent.items()),
            "failure cover parent map contains invalid identities")
    roots = [node for node, owner in parent.items() if owner is None]
    stable_order = unique_strings(ex["stable_order"],
                                  f"{scenario}.stable_order")
    tree_ok = (len(roots) == 1 and set(stable_order) == set(parent)
               and stable_order[0] == roots[0])
    try:
        for node in parent:
            ancestors = tree_ancestors(parent, node)
            tree_ok = tree_ok and ancestors[-1] == roots[0]
    except ValidationError:
        tree_ok = False
    witness_check(tree_ok, scenario,
                  "cover_tree_is_rooted_unique_parent_acyclic", done)
    reverse = exact_keys(ex["reverse_index"], {
        "scope_to_uses", "uses",
    }, f"{scenario}.reverse_index")
    scope_to_uses = reverse["scope_to_uses"]
    uses = reverse["uses"]
    require(isinstance(scope_to_uses, dict) and scope_to_uses
            and isinstance(uses, dict) and uses
            and set(scope_to_uses) <= set(parent),
            "failure reverse index is malformed")
    referenced_uses: set[str] = set()
    for scope, use_ids in scope_to_uses.items():
        referenced_uses.update(unique_strings(
            use_ids, f"{scenario}.scope_to_uses.{scope}"))
    use_rows: dict[str, dict[str, Any]] = {}
    sequences: set[int] = set()
    for use_id, value_row in uses.items():
        require(isinstance(use_id, str) and use_id,
                "failure reverse use ID must be a nonempty string")
        row = exact_keys(value_row, {
            "sequence", "adds_scopes", "topology_generation",
        }, f"{scenario}.reverse_use.{use_id}")
        adds = unique_strings(row["adds_scopes"],
                              f"{scenario}.reverse_use.{use_id}.adds_scopes")
        require(natural(row["sequence"])
                and row["sequence"] not in sequences
                and set(adds) <= set(parent)
                and isinstance(row["topology_generation"], str)
                and bool(row["topology_generation"]),
                "failure reverse use row is malformed")
        sequences.add(row["sequence"])
        use_rows[use_id] = row
    require(referenced_uses == set(use_rows),
            "failure reverse index contains missing or unreachable use rows")
    publication = exact_keys(ex["publication_snapshot"], {
        "fence_position", "reverse_index_highwater",
        "committed_before_highwater", "after_fence_use",
        "after_fence_published",
    }, f"{scenario}.publication_snapshot")
    require_natural_fields(publication, (
        "fence_position", "reverse_index_highwater",
    ), f"{scenario}.publication_snapshot")
    require(type(publication["after_fence_published"]) is bool,
            "failure publication flag must be boolean")
    committed = unique_strings(publication["committed_before_highwater"],
                               f"{scenario}.committed_before_highwater")
    published_by_highwater = sorted(
        use_id for use_id, row in use_rows.items()
        if row["sequence"] <= publication["reverse_index_highwater"]
    )
    witness_check(publication["fence_position"]
                  > publication["reverse_index_highwater"]
                  and sorted(committed) == published_by_highwater
                  and isinstance(publication["after_fence_use"], str)
                  and bool(publication["after_fence_use"])
                  and publication["after_fence_use"] not in use_rows
                  and publication["after_fence_use"] not in committed
                  and publication["after_fence_published"] is False,
                  scenario, "publication_fence_snapshot_is_total", done)
    seed = exact_keys(ex["closure_seed"], {
        "scopes", "topology_generations",
    }, f"{scenario}.closure_seed")
    seed_scopes = unique_strings(seed["scopes"],
                                 f"{scenario}.closure_seed.scopes")
    seed_generations = unique_strings(
        seed["topology_generations"],
        f"{scenario}.closure_seed.topology_generations")
    require(set(seed_scopes) <= set(parent),
            "failure closure seed contains an unknown scope")
    computed: list[dict[str, Any]] = []
    current_scopes = set(seed_scopes)
    current_uses: set[str] = set()
    current_generations = set(seed_generations)

    def closure_row(ordinal: int) -> dict[str, Any]:
        return {
            "ordinal": ordinal,
            "scopes": sorted(current_scopes),
            "uses": sorted(current_uses),
            "topology_generations": sorted(current_generations),
        }

    computed.append(closure_row(0))
    for _ in range(len(use_rows) + 1):
        eligible = {
            use_id for scope in current_scopes
            for use_id in scope_to_uses.get(scope, [])
            if use_id in committed
        }
        newly_reached = eligible - current_uses
        if not newly_reached:
            computed.append(closure_row(len(computed)))
            break
        current_uses.update(newly_reached)
        for use_id in newly_reached:
            current_scopes.update(use_rows[use_id]["adds_scopes"])
            current_generations.add(use_rows[use_id]["topology_generation"])
        computed.append(closure_row(len(computed)))
    else:
        raise ValidationError("failure closure did not reach a fixed point")
    claimed = ex["claimed_iterations"]
    require(isinstance(claimed, list) and len(claimed) >= 2,
            "claimed failure closure iterations must include a fixed point")
    for row in claimed:
        exact_keys(row, {
            "ordinal", "scopes", "uses", "topology_generations",
        }, f"{scenario}.claimed_iteration")
        require(natural(row["ordinal"]),
                "claimed failure closure ordinal is not a natural")
        unique_strings(row["scopes"], f"{scenario}.claimed.scopes")
        unique_strings(row["uses"], f"{scenario}.claimed.uses")
        unique_strings(row["topology_generations"],
                       f"{scenario}.claimed.generations")
    witness_check(claimed == computed
                  and claimed[-1] == {
                      **claimed[-2], "ordinal": claimed[-1]["ordinal"],
                  }, scenario,
                  "claimed_iterations_equal_monotonic_least_fixed_point",
                  done)
    bounds = exact_keys(ex["closure_bounds"], {
        "iterations", "scopes", "edges",
    }, f"{scenario}.closure_bounds")
    edge_count = sum(len(items) for items in scope_to_uses.values()) \
        + sum(len(row["adds_scopes"]) for row in use_rows.values())
    witness_check(all(natural(item) and item > 0 for item in bounds.values())
                  and len(computed) <= bounds["iterations"]
                  and len(current_scopes) <= bounds["scopes"]
                  and edge_count <= bounds["edges"], scenario,
                  "least_fixed_point_within_NodeConfig_bounds", done)
    expected_generations = set(seed_generations) | {
        use_rows[use_id]["topology_generation"] for use_id in current_uses
    }
    witness_check(current_generations == expected_generations
                  and current_uses == set(committed), scenario,
                  "all_intermediate_topology_generations_reached", done)
    union = unique_strings(ex["expected_union"],
                           f"{scenario}.expected_union")
    require(set(union) == current_scopes,
            "expected failure union differs from least fixed point")
    require(natural(ex["max_failure_scopes"]),
            "max failure scopes must be a natural")
    cover = tree_lca(parent, union)
    witness_check(len(union) > ex["max_failure_scopes"]
                  and cover == ex["expected_cover"] and cover != roots[0],
                  scenario, "oversized_union_uses_unique_lca", done)
    root_case = unique_strings(ex["root_case_union"],
                               f"{scenario}.root_case_union")
    require(set(root_case) <= set(parent),
            "root failure case contains an unknown scope")
    root_cover = tree_lca(parent, root_case)
    witness_check(root_cover == roots[0]
                  and ex["root_case_result"] == "node_failstop",
                  scenario, "root_lca_forces_node_failstop", done)
    before = exact_keys(ex["capacity_before"], {
        "current", "pending", "retiring", "failure_escrow",
    }, f"{scenario}.capacity_before")
    after = exact_keys(ex["capacity_after_commit"], {
        "current", "pending", "retiring", "failure_escrow",
    }, f"{scenario}.capacity_after_commit")
    require(all(natural(item) for item in before.values())
            and all(natural(item) for item in after.values()),
            "failure capacity counters must be naturals")
    before_total = sum(before.values())
    after_total = sum(after.values())
    witness_check(before_total == after_total
                  and after["current"] == after["pending"] == after["retiring"] == 0
                  and after["failure_escrow"] == before_total,
                  scenario, "commit_conserves_and_moves_to_escrow", done)
    cleanup = exact_keys(ex["capacity_after_terminal_cleanup"], {
        "current", "pending", "retiring", "failure_escrow", "released",
    }, f"{scenario}.capacity_after_terminal_cleanup")
    witness_check(all(natural(item) for item in cleanup.values())
                  and cleanup["current"] == cleanup["pending"]
                  == cleanup["retiring"] == cleanup["failure_escrow"] == 0
                  and cleanup["released"] == before_total,
                  scenario, "cleanup_only_releases_after_terminal", done)
    leaf_edges = ex["leaf_reverse_edges"]
    require(isinstance(leaf_edges, dict) and set(leaf_edges) == set(union)
            and all(isinstance(name, str) and natural(count)
                    for name, count in leaf_edges.items()),
            "leaf reverse-edge charges do not match the closure")
    cover_ancestors = tree_ancestors(parent, ex["expected_cover"])
    reservations = ex["cover_ancestor_cleanup_reservations"]
    require(isinstance(reservations, dict)
            and set(reservations) == set(cover_ancestors)
            and all(natural(item) for item in reservations.values())
            and natural(ex["cleanup_steps"]),
            "cover ancestor cleanup reservation inventory changed")
    aggregate_by_ancestor = {
        ancestor: sum(
            charge for leaf, charge in leaf_edges.items()
            if ancestor in tree_ancestors(parent, leaf)
        ) for ancestor in cover_ancestors
    }
    witness_check(all(reservations[ancestor]
                      == aggregate_by_ancestor[ancestor]
                      for ancestor in cover_ancestors)
                  and ex["cleanup_steps"]
                  == aggregate_by_ancestor[ex["expected_cover"]]
                  and all(ex["cleanup_steps"] <= reservations[ancestor]
                          for ancestor in cover_ancestors), scenario,
                  "cover_ancestor_cleanup_within_precharge", done)
    expected_descendants = {node for node in parent
                            if ex["expected_cover"]
                            in tree_ancestors(parent, node)}
    witness_check(nonempty_string(ex["unaffected_scope"])
                  and ex["unaffected_scope"] in parent
                  and ex["unaffected_scope"] not in expected_descendants
                  and ex["root_case_result"] == "node_failstop",
                  scenario, "unaffected_is_outside_selected_cover", done)
    finish_witness_checks(scenario, ex, done)


def execute_activation(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "activation_delivery_crash", {
        "identity", "expected_activation_id", "lease", "use_cell",
        "required_receipt_classes", "receipt_policy", "receipts", "decision",
        "cancel_race", "pre_gate_crash", "settlement", "delivery",
        "zero_delivery", "voluntary_yield", "token_replay",
        "failed_validation",
    })
    done: list[str] = []
    identity = exact_keys(ex["identity"], {
        "activation_scoped_namespace_root", "monitor_boot_epoch",
        "projection_epoch", "cpu_incarnation", "physical_context",
        "root_execution_allocation_generation", "activation_slot_id",
        "lease_issuance_id", "activation_generation", "intent_generation",
        "intent_digest",
    }, f"{scenario}.identity")
    root = exact_keys(identity["activation_scoped_namespace_root"], {
        "root_id", "domain_key", "domain_epoch", "plan_shard_id",
        "plan_namespace_epoch", "root_plan_epoch", "lane_id",
        "lane_clock_epoch", "lane_turn", "service_stream_id",
        "service_stream_incarnation", "opportunity_ordinal",
    }, f"{scenario}.activation_scoped_namespace_root")
    require(all(isinstance(root[name], str) and root[name]
                for name in ("root_id", "domain_key", "plan_shard_id",
                             "lane_id", "service_stream_id"))
            and all(natural(root[name]) for name in (
                "domain_epoch", "plan_namespace_epoch", "root_plan_epoch",
                "lane_clock_epoch", "lane_turn", "service_stream_incarnation",
                "opportunity_ordinal",
            ))
            and all(isinstance(identity[name], str) and identity[name]
                    for name in ("physical_context", "activation_slot_id",
                                 "lease_issuance_id", "intent_digest"))
            and all(natural(identity[name]) for name in (
                "monitor_boot_epoch", "projection_epoch", "cpu_incarnation",
                "root_execution_allocation_generation",
                "activation_generation", "intent_generation",
            )), "activation identity contains invalid parent values")
    derived = (
        f"nsroot:{root['root_id']}|domain:{root['domain_key']}@"
        f"{root['domain_epoch']}|plan:{root['plan_shard_id']}:"
        f"{root['plan_namespace_epoch']}:{root['root_plan_epoch']}|lane:"
        f"{root['lane_id']}:{root['lane_clock_epoch']}:{root['lane_turn']}|"
        f"stream:{root['service_stream_id']}:"
        f"{root['service_stream_incarnation']}:q"
        f"{root['opportunity_ordinal']}|boot:{identity['monitor_boot_epoch']}|"
        f"projection:{identity['projection_epoch']}|"
        f"cpu:{identity['cpu_incarnation']}|"
        f"context:{identity['physical_context']}|allocation:"
        f"{identity['root_execution_allocation_generation']}|slot:"
        f"{identity['activation_slot_id']}|lease:"
        f"{identity['lease_issuance_id']}|activation:"
        f"{identity['activation_generation']}|intent:"
        f"{identity['intent_generation']}|{identity['intent_digest']}"
    )
    witness_check(derived == ex["expected_activation_id"]
                  and identity["intent_digest"].startswith("sha256:"), scenario,
                  "activation_id_full_parent_derivation", done)
    lease = exact_keys(ex["lease"], {
        "id", "issuance_id", "physical_occurrence", "lane",
        "physical_context", "activation_slot_id", "issued_at", "cell_start",
        "cell_end", "entry_exit_guard", "budget",
        "target_lease_clock_epoch", "normalized_authority_not_after",
        "normalized_source_count", "stop_tick",
    }, f"{scenario}.lease")
    use = exact_keys(ex["use_cell"], {
        "id", "lease", "physical_occurrence", "activation_slot_id",
        "intent_prepared_at", "bound_intent_digest", "decision_key", "states",
    }, f"{scenario}.use_cell")
    require(all(isinstance(lease[name], str) and lease[name]
                for name in ("id", "issuance_id", "physical_occurrence",
                             "lane", "physical_context", "activation_slot_id"))
            and all(natural(lease[name]) for name in (
                "issued_at", "cell_start", "cell_end", "entry_exit_guard",
                "budget", "target_lease_clock_epoch",
                "normalized_authority_not_after", "normalized_source_count",
                "stop_tick",
            ))
            and all(isinstance(use[name], str) and use[name]
                    for name in ("id", "lease", "physical_occurrence",
                                 "activation_slot_id", "bound_intent_digest",
                                 "decision_key"))
            and natural(use["intent_prepared_at"]),
            "activation lease or use-cell values are invalid")
    expected_decision_key = (
        f"{root['service_stream_id']}:inc"
        f"{root['service_stream_incarnation']}:q"
        f"{root['opportunity_ordinal']}"
    )
    witness_check(lease["issuance_id"] == identity["lease_issuance_id"]
                  and lease["activation_slot_id"]
                  == identity["activation_slot_id"]
                  and lease["physical_context"]
                  == identity["physical_context"]
                  and lease["lane"] == root["lane_id"]
                  and use["lease"] == lease["id"]
                  and use["physical_occurrence"]
                  == lease["physical_occurrence"]
                  and use["activation_slot_id"]
                  == lease["activation_slot_id"]
                  and use["bound_intent_digest"] == identity["intent_digest"]
                  and use["decision_key"] == expected_decision_key
                  and lease["issued_at"] < use["intent_prepared_at"]
                  < lease["cell_start"], scenario,
                  "slot_intent_lease_binding_acyclic", done)
    witness_check(one_way_states(use["states"]), scenario,
                  "one_way_use_state_from_unbound", done)
    required_receipts = unique_strings(ex["required_receipt_classes"],
                                       f"{scenario}.receipt_classes")
    expected_receipts = [
        "view", "code", "entry", "translation", "backing",
        "mutable_state", "device",
    ]
    policy = exact_keys(ex["receipt_policy"], set(expected_receipts),
                        f"{scenario}.receipt_policy")
    receipts = ex["receipts"]
    require(all(nonempty_string(item) for item in policy.values()),
            "receipt policy values must be nonempty strings")
    witness_check(required_receipts == expected_receipts
                  and isinstance(receipts, dict)
                  and set(receipts) == set(expected_receipts)
                  and set(policy.values()) <= {
                      "required_present", "typed_optional",
                  }, scenario, "receipt_class_schema_fixed", done)
    required_present = {
        name for name, requirement in policy.items()
        if requirement == "required_present"
    }
    required_ok = True
    for name in required_present:
        row = exact_keys(receipts[name], {"status", "receipt"},
                         f"{scenario}.receipt.{name}")
        required_ok = required_ok and row["status"] == "present" \
            and isinstance(row["receipt"], str) and bool(row["receipt"])
    witness_check(required_present == set(expected_receipts) - {"device"}
                  and required_ok, scenario,
                  "required_receipts_cannot_be_not_applicable", done)
    optional = exact_keys(receipts["device"], {
        "status", "reason", "context_receipt",
    }, f"{scenario}.receipt.device")
    witness_check(policy["device"] == "typed_optional"
                  and optional["status"] == "typed_not_applicable"
                  and isinstance(optional["reason"], str)
                  and bool(optional["reason"])
                  and isinstance(optional["context_receipt"], str)
                  and bool(optional["context_receipt"]), scenario,
                  "typed_optional_receipt_has_reason_and_context", done)
    settlement = exact_keys(ex["settlement"], {
        "states", "entry_tick", "entry_permit_uses", "initial_budget",
        "segments", "consumed_budget", "remaining_budget",
        "activation_commit_receipt_id", "delivery_receipt_id",
        "retry_delivery_receipt_id", "first_service_account_apply",
        "duplicate_service_account_apply",
    }, f"{scenario}.settlement")
    require(isinstance(settlement["states"], list)
            and settlement["states"]
            and all(isinstance(state, str) and state
                    for state in settlement["states"])
            and all(natural(settlement[name]) for name in (
                "entry_tick", "entry_permit_uses", "initial_budget",
                "consumed_budget", "remaining_budget",
            )), "delivery settlement state or counters are malformed")
    witness_check(lease["cell_start"] < settlement["entry_tick"]
                  < lease["stop_tick"] <= min(
                      lease["cell_end"],
                      lease["normalized_authority_not_after"])
                  and lease["entry_exit_guard"] + lease["budget"]
                  <= lease["cell_end"] - lease["cell_start"]
                  and lease["stop_tick"] - settlement["entry_tick"]
                  <= lease["budget"]
                  and lease["target_lease_clock_epoch"] > 0
                  and lease["normalized_source_count"] == 7,
                  scenario, "budget_within_cell_and_normalized_horizon", done)
    decision_edges = {
        ("Undecided", "SuppressedBeforeActivation"),
        ("Undecided", "PreparedInert"),
        ("Undecided", "Expired"),
        ("PreparedInert", "Entered"),
        ("PreparedInert", "StopPending"),
        ("Entered", "StopPending"),
        ("Entered", "Settled"),
        ("StopPending", "Settled"),
    }
    cancel = exact_keys(ex["cancel_race"], {
        "cancel_winner", "activation_winner", "distinct_shadow_decision_cell",
    }, f"{scenario}.cancel_race")
    cancel_winner = exact_keys(cancel["cancel_winner"], {
        "states", "entry_allowed",
    }, f"{scenario}.cancel_winner")
    activation_winner = exact_keys(cancel["activation_winner"], {
        "states", "late_cancel_can_suppress", "late_cancel_requests_stop",
    }, f"{scenario}.activation_winner")
    race_traces = [cancel_winner["states"], activation_winner["states"]]
    require(all(isinstance(trace, list)
                and all(nonempty_string(state) for state in trace)
                for trace in race_traces)
            and type(cancel_winner["entry_allowed"]) is bool
            and type(activation_winner["late_cancel_can_suppress"]) is bool
            and type(activation_winner["late_cancel_requests_stop"]) is bool
            and type(cancel["distinct_shadow_decision_cell"]) is bool,
            "activation/cancel race fields are malformed")
    witness_check(all(len(trace) == len(set(trace))
                      and all((left, right) in decision_edges
                              for left, right in zip(trace, trace[1:]))
                      for trace in race_traces)
                  and cancel_winner["states"]
                  == ["Undecided", "SuppressedBeforeActivation"]
                  and cancel_winner["entry_allowed"] is False
                  and activation_winner["states"] == [
                      "Undecided", "PreparedInert", "Entered", "StopPending",
                      "Settled",
                  ]
                  and activation_winner["late_cancel_can_suppress"] is False
                  and activation_winner["late_cancel_requests_stop"] is True
                  and cancel["distinct_shadow_decision_cell"] is False,
                  scenario, "canonical_cancel_activation_race", done)
    decision = exact_keys(ex["decision"], {
        "key", "expected_key", "states", "staging_generation",
        "expected_staging_generation", "valid_gate_before_PreparedInert",
        "valid_gate_after_Entered", "entry_permit_uses",
        "activation_commit_receipt_id", "retry_activation_id",
    }, f"{scenario}.decision")
    witness_check(decision["key"] == decision["expected_key"]
                  == expected_decision_key == use["decision_key"]
                  and decision["states"]
                  == ["Undecided", "PreparedInert", "Entered", "Settled"]
                  and all((left, right) in decision_edges
                          for left, right in zip(decision["states"],
                                                 decision["states"][1:]))
                  and natural(decision["staging_generation"])
                  and decision["staging_generation"]
                  == decision["expected_staging_generation"]
                  and decision["valid_gate_before_PreparedInert"] is False
                  and decision["valid_gate_after_Entered"] is True
                  and decision["retry_activation_id"] == derived
                  and isinstance(decision["activation_commit_receipt_id"], str)
                  and bool(decision["activation_commit_receipt_id"]),
                  scenario, "decision_key_staging_and_retry_bijection", done)
    crash = exact_keys(ex["pre_gate_crash"], {
        "decision_state", "use_state", "valid_gate", "entry_permit_consumed",
        "executable", "service", "recovery_activation_id", "within_same_cell",
    }, f"{scenario}.pre_gate_crash")
    witness_check(crash["decision_state"] == "PreparedInert"
                  and crash["use_state"] == "Consumed"
                  and crash["valid_gate"] is False
                  and crash["entry_permit_consumed"] is False
                  and crash["executable"] is False
                  and crash["service"] is False
                  and crash["recovery_activation_id"] == derived
                  and crash["within_same_cell"] is True,
                  scenario, "pre_gate_crash_nonexecutable", done)
    witness_check(natural(decision["entry_permit_uses"])
                  and natural(settlement["entry_permit_uses"])
                  and decision["entry_permit_uses"]
                  == settlement["entry_permit_uses"] == 1,
                  scenario, "one_use_entry_permit", done)
    settlement_edges = {
        ("Inert", "Active"), ("Active", "StopPending"),
        ("Active", "Settled"), ("StopPending", "Settled"),
    }
    segments = settlement["segments"]
    require(isinstance(segments, list) and segments,
            "delivery settlement requires execution segments")
    for segment in segments:
        exact_keys(segment, {"resume_sequence", "start", "end"},
                   f"{scenario}.settlement.segment")
        require(all(natural(segment[name]) for name in segment),
                "settlement segment values must be naturals")
    consumed = sum(segment["end"] - segment["start"] for segment in segments)
    witness_check(settlement["states"][0] == "Inert"
                  and settlement["states"][-1] == "Settled"
                  and len(settlement["states"])
                  == len(set(settlement["states"]))
                  and all((left, right) in settlement_edges
                          for left, right in zip(settlement["states"],
                                                 settlement["states"][1:]))
                  and [segment["resume_sequence"] for segment in segments]
                  == list(range(len(segments)))
                  and all(settlement["entry_tick"] <= segment["start"]
                          < segment["end"] <= lease["stop_tick"]
                          for segment in segments)
                  and all(left["end"] <= right["start"]
                          for left, right in zip(segments, segments[1:]))
                  and consumed == settlement["consumed_budget"]
                  and settlement["initial_budget"] == lease["budget"]
                  == settlement["consumed_budget"]
                  + settlement["remaining_budget"], scenario,
                  "delivery_settlement_one_way_resume_and_budget", done)
    delivery = exact_keys(ex["delivery"], {
        "activation_commit_receipt", "state_after_commit", "delivered_ticks",
        "authenticated_post_entry_yield", "state_after_delivery",
        "consumed_budget", "remaining_budget",
    }, f"{scenario}.delivery")
    require(all(natural(delivery[name]) for name in (
        "delivered_ticks", "consumed_budget", "remaining_budget",
    )) and type(delivery["activation_commit_receipt"]) is bool
        and type(delivery["authenticated_post_entry_yield"]) is bool,
        "delivery counters and flags are malformed")
    witness_check(delivery["activation_commit_receipt"] is True
                  and delivery["state_after_commit"] == "ActivatedUnserved",
                  scenario, "commit_is_activated_unserved", done)
    witness_check(delivery["delivered_ticks"] > 0
                  and natural(delivery["delivered_ticks"])
                  and delivery["authenticated_post_entry_yield"] is False
                  and delivery["state_after_delivery"] == "Served"
                  and delivery["consumed_budget"] == delivery["delivered_ticks"]
                  and delivery["consumed_budget"] + delivery["remaining_budget"]
                  == lease["budget"]
                  and delivery["consumed_budget"]
                  == settlement["consumed_budget"]
                  and delivery["remaining_budget"]
                  == settlement["remaining_budget"],
                  scenario, "positive_delivery_counts_service", done)
    witness_check(settlement["activation_commit_receipt_id"]
                  == decision["activation_commit_receipt_id"]
                  and settlement["delivery_receipt_id"]
                  == settlement["retry_delivery_receipt_id"]
                  and settlement["first_service_account_apply"] is True
                  and settlement["duplicate_service_account_apply"] is False,
                  scenario,
                  "delivery_retry_and_service_accounting_idempotent", done)
    zero = exact_keys(ex["zero_delivery"], {
        "activation_commit_receipt", "delivered_ticks",
        "authenticated_post_entry_yield", "counts_service",
    }, f"{scenario}.zero_delivery")
    witness_check(natural(zero["delivered_ticks"])
                  and zero["activation_commit_receipt"] is True
                  and zero["delivered_ticks"] == 0
                  and zero["authenticated_post_entry_yield"] is False
                  and zero["counts_service"] is False,
                  scenario, "zero_without_yield_not_service", done)
    yielded = exact_keys(ex["voluntary_yield"], {
        "activation_commit_receipt", "hardware_entry_seen", "delivered_ticks",
        "authenticated_post_entry_yield", "counts_service",
    }, f"{scenario}.voluntary_yield")
    witness_check(natural(yielded["delivered_ticks"])
                  and yielded["activation_commit_receipt"] is True
                  and yielded["hardware_entry_seen"] is True
                  and yielded["delivered_ticks"] == 0
                  and yielded["authenticated_post_entry_yield"] is True
                  and yielded["counts_service"] is True,
                  scenario, "post_entry_yield_counts_service", done)
    replay = exact_keys(ex["token_replay"], {
        "after_settlement_executable", "after_cell_end_executable",
        "untrusted_reentry_allowed",
    }, f"{scenario}.token_replay")
    witness_check(use["states"][-1] == "Settled"
                  and all(item is False for item in replay.values()),
                  scenario, "settled_or_expired_token_replay_rejected", done)
    failed = exact_keys(ex["failed_validation"], {
        "missing_class", "use_state", "canonical_decision_state",
        "partial_executable_state", "token_count",
        "failed_activation_slot_id", "fresh_activation_slot_required_for_retry",
    }, f"{scenario}.failed_validation")
    witness_check(nonempty_string(failed["missing_class"])
                  and failed["missing_class"] in required_present
                  and failed["use_state"] == "Expired"
                  and failed["canonical_decision_state"] == "Undecided"
                  and failed["partial_executable_state"] is False
                  and natural(failed["token_count"])
                  and failed["token_count"] == 0
                  and nonempty_string(failed["failed_activation_slot_id"])
                  and failed["failed_activation_slot_id"]
                  != lease["activation_slot_id"]
                  and failed["fresh_activation_slot_required_for_retry"] is True,
                  scenario,
                  "failed_validation_expires_attempt_only_without_partial_state",
                  done)
    finish_witness_checks(scenario, ex, done)


def execute_management(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "management_bootstrap", {
        "reserved", "ordinary_before", "ordinary_borrow_attempt",
        "recovery_action", "bootstrap_root_failure",
    })
    done: list[str] = []
    reserved = ex["reserved"]
    witness_check(isinstance(reserved, dict) and reserved
                  and all(natural(item) and item > 0
                          for item in reserved.values()),
                  scenario, "all_bootstrap_resources_positive", done)
    ordinary = exact_keys(ex["ordinary_before"], {
        "execution_cells", "control_cells", "namespace_slots",
    }, f"{scenario}.ordinary_before")
    require(all(natural(item) for item in ordinary.values()),
            "ordinary pre-recovery capacities must be naturals")
    borrow = exact_keys(ex["ordinary_borrow_attempt"], {
        "resource", "accepted",
    }, f"{scenario}.ordinary_borrow_attempt")
    witness_check(borrow["resource"] == "management_execution_cells"
                  and borrow["accepted"] is False,
                  scenario, "ordinary_cannot_borrow", done)
    action = exact_keys(ex["recovery_action"], {
        "uses_management_execution", "uses_management_control",
        "ordinary_delta", "terminal",
    }, f"{scenario}.recovery_action")
    require_natural_fields(action, (
        "uses_management_execution", "uses_management_control",
        "ordinary_delta",
    ), f"{scenario}.recovery_action")
    require(type(action["terminal"]) is bool,
            "management recovery terminal flag must be boolean")
    witness_check(action["uses_management_execution"] <= reserved["execution_cells"]
                  and action["uses_management_control"] <= reserved["control_cells"]
                  and action["terminal"] is True,
                  scenario, "recovery_debits_reserved_capacity", done)
    witness_check(action["ordinary_delta"] == 0,
                  scenario, "ordinary_capacity_unchanged", done)
    failure = exact_keys(ex["bootstrap_root_failure"], {
        "result", "ordinary_linux_fallback",
    }, f"{scenario}.bootstrap_root_failure")
    witness_check(failure["result"] == "node_failstop"
                  and failure["ordinary_linux_fallback"] is False,
                  scenario, "bootstrap_failure_failstops", done)
    finish_witness_checks(scenario, ex, done)


def apply_named_operation(state: dict[str, Any], operation: dict[str, Any]) \
        -> dict[str, Any]:
    result = dict(state)
    for key, value in operation["set"].items():
        result[key] = value
    return result


def execute_commutation(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "disjoint_commutation", {
        "initial", "operation_A", "operation_B", "left_order", "right_order",
        "expected_terminal",
    })
    done: list[str] = []
    initial = ex["initial"]
    require(isinstance(initial, dict)
            and {"A", "B", "escrow_A", "escrow_B"} <= set(initial)
            and all(nonempty_string(key) for key in initial),
            "commutation initial state is malformed")
    expected_terminal = exact_keys(ex["expected_terminal"], set(initial),
                                   f"{scenario}.expected_terminal")
    require(all(natural(item) for item in initial.values())
            and all(natural(item) for item in expected_terminal.values()),
            "commutation states must contain naturals")
    operations = {name: ex[name] for name in ("operation_A", "operation_B")}
    for name, operation in operations.items():
        exact_keys(operation, {"writes", "mutable_reads", "set"},
                   f"{scenario}.{name}")
        unique_strings(operation["writes"], f"{scenario}.{name}.writes")
        unique_strings(operation["mutable_reads"],
                       f"{scenario}.{name}.mutable_reads")
        require(operation["mutable_reads"],
                f"operation mutable-read footprint is empty: {name}")
        require(isinstance(operation["set"], dict)
                and set(operation["set"]) == set(operation["writes"])
                and all(natural(item) for item in operation["set"].values()),
                f"operation writes differ from update: {name}")
    a = operations["operation_A"]
    b = operations["operation_B"]
    disjoint = set(a["writes"]).isdisjoint(
        set(b["writes"]) | set(b["mutable_reads"]))
    disjoint = disjoint and set(b["writes"]).isdisjoint(
        set(a["writes"]) | set(a["mutable_reads"]))
    witness_check(disjoint, scenario, "write_read_footprints_disjoint", done)
    terminals: list[dict[str, Any]] = []
    for order in (ex["left_order"], ex["right_order"]):
        names = unique_strings(order, f"{scenario}.commutation_order")
        state = dict(initial)
        require(set(names) == set(operations) and len(names) == 2,
                "commutation order changed")
        for name in names:
            state = apply_named_operation(state, operations[name])
        terminals.append(state)
    witness_check(terminals[0] == terminals[1] == expected_terminal,
                  scenario, "left_and_right_terminal_equal", done)
    witness_check(all(terminal["escrow_A"] == initial["escrow_A"]
                      and terminal["escrow_B"] == initial["escrow_B"]
                      for terminal in terminals),
                  scenario, "immutable_escrow_unchanged", done)
    witness_check("ancestor" not in set(a["writes"]) | set(b["writes"]),
                  scenario, "no_shared_ancestor_direct_write", done)
    finish_witness_checks(scenario, ex, done)


def execute_service_capacity(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "protected_service_capacity", {
        "frame", "literal_schedule", "dispatches",
    })
    done: list[str] = []
    frame = ex["frame"]
    require(isinstance(frame, dict) and set(frame) == {
        "capacity", "emergency", "management", "local", "A", "B", "slack",
    }, "service frame changed")
    witness_check(all(natural(item) for item in frame.values())
                  and frame["capacity"] == sum(
                      value for key, value in frame.items() if key != "capacity"),
                  scenario, "frame_partition_sum", done)
    schedule = ex["literal_schedule"]
    permitted_schedule_classes = {
        "A", "B", "management", "emergency", "local", "slack",
    }
    witness_check(isinstance(schedule, list)
                  and all(isinstance(item, str)
                          and item in permitted_schedule_classes
                          for item in schedule)
                  and len(schedule) == frame["capacity"]
                  and schedule.count("A") == frame["A"]
                  and schedule.count("B") == frame["B"]
                  and schedule.count("management") == frame["management"]
                  and schedule.count("emergency") == frame["emergency"]
                  and schedule.count("local") == frame["local"]
                  and schedule.count("slack") == frame["slack"],
                  scenario, "literal_occurrences_equal_reservations", done)
    cells: list[int] = []
    dispatch_ok = True
    dispatches = ex["dispatches"]
    require(isinstance(dispatches, list) and dispatches,
            "service dispatches must be a nonempty array")
    for row in dispatches:
        exact_keys(row, {"cell", "child"}, f"{scenario}.dispatch")
        require(natural(row["cell"])
                and row["cell"] < len(schedule)
                and nonempty_string(row["child"])
                and row["child"] in {"A", "B"},
                "service dispatch cell or child is invalid")
        cells.append(row["cell"])
        dispatch_ok = dispatch_ok and schedule[row["cell"]] == row["child"]
    expected_child_cells = {
        index for index, owner in enumerate(schedule) if owner in {"A", "B"}
    }
    witness_check(dispatch_ok and len(cells) == len(set(cells))
                  and set(cells) == expected_child_cells,
                  scenario, "one_cell_one_descendant", done)
    witness_check({row["child"] for row in ex["dispatches"]} == {"A", "B"},
                  scenario, "both_children_share_parent_certificate", done)
    finish_witness_checks(scenario, ex, done)


def execute_independent_lane(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "independent_lane_progress", {
        "selected_failure_cover", "node_failstop", "lane_scopes", "lane_A",
        "lane_B", "cross_lane_writes",
    })
    done: list[str] = []
    scopes = exact_keys(ex["lane_scopes"], {"lane_A", "lane_B"},
                       f"{scenario}.lane_scopes")
    require(nonempty_string(ex["selected_failure_cover"])
            and all(nonempty_string(item) for item in scopes.values()),
            "independent-lane scopes must be nonempty strings")
    witness_check(scopes["lane_A"] == ex["selected_failure_cover"]
                  and scopes["lane_B"] != ex["selected_failure_cover"],
                  scenario, "lane_B_outside_selected_cover", done)
    witness_check(ex["node_failstop"] is False, scenario,
                  "no_node_failstop", done)
    lane_b = exact_keys(ex["lane_B"], {
        "rank_trace", "owned_cells", "terminal",
    }, f"{scenario}.lane_B")
    rank = lane_b["rank_trace"]
    witness_check(isinstance(rank, list) and len(rank) >= 2
                  and all(natural(item) for item in rank)
                  and rank[-1] == 0
                  and all(left > right
                          for left, right in zip(rank, rank[1:])),
                  scenario, "lane_B_rank_strictly_decreases_on_owned_steps",
                  done)
    witness_check(ex["cross_lane_writes"] == [], scenario,
                  "no_cross_lane_write", done)
    lane_a = exact_keys(ex["lane_A"], {"held", "rank", "owned_cells"},
                       f"{scenario}.lane_A")
    lane_a_cells = lane_a["owned_cells"]
    lane_b_cells = lane_b["owned_cells"]
    require(natural(lane_a["rank"])
            and isinstance(lane_a_cells, list) and lane_a_cells
            and isinstance(lane_b_cells, list) and lane_b_cells
            and all(natural(item) for item in lane_a_cells + lane_b_cells)
            and len(lane_a_cells) == len(set(lane_a_cells))
            and len(lane_b_cells) == len(set(lane_b_cells)),
            "independent-lane ranks or owned cells are malformed")
    witness_check(lane_a["held"] is True
                  and set(lane_a_cells).isdisjoint(set(lane_b_cells))
                  and lane_b["terminal"] is True,
                  scenario, "lane_A_hold_not_in_lane_B_rank", done)
    finish_witness_checks(scenario, ex, done)


def execute_mixed_apply(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "mixed_apply_failure", {
        "capacity", "base", "slack", "entries", "security_fence_writer",
        "left_order", "right_order", "expected_successors",
    })
    done: list[str] = []
    entries = ex["entries"]
    require(isinstance(entries, dict) and set(entries) == {"A", "B"},
            "mixed apply entries changed")
    require_natural_fields(ex, ("capacity", "base", "slack"),
                           f"{scenario}.mixed_apply")
    for name, row in entries.items():
        exact_keys(row, {"escrow", "status", "demand", "residual",
                         "status_writer"}, f"{scenario}.entry.{name}")
        require_natural_fields(row, ("escrow", "demand", "residual"),
                               f"{scenario}.entry.{name}")
        require(nonempty_string(row["status"])
                and row["status"] in {"Applied", "FailedFenced"}
                and nonempty_string(row["status_writer"]),
                f"mixed apply status or writer is invalid: {name}")
    witness_check(all(row["demand"] + row["residual"] == row["escrow"]
                      for row in entries.values()), scenario,
                  "each_demand_plus_residual_equals_escrow", done)
    witness_check(ex["base"] + ex["slack"]
                  + sum(row["demand"] + row["residual"]
                        for row in entries.values()) == ex["capacity"],
                  scenario, "total_capacity_conserved", done)
    witness_check(len({row["status_writer"] for row in entries.values()})
                  == len(entries), scenario,
                  "one_status_writer_per_entry", done)
    fence_writers = exact_keys(ex["security_fence_writer"], set(entries),
                               f"{scenario}.security_fence_writer")
    witness_check(all(fence_writers[name] != entries[name]["status_writer"]
                      and nonempty_string(fence_writers[name])
                      for name in entries), scenario,
                  "failure_scope_writer_distinct", done)
    left = unique_strings(ex["left_order"], f"{scenario}.left_order")
    right = unique_strings(ex["right_order"], f"{scenario}.right_order")
    successors = unique_strings(ex["expected_successors"],
                                f"{scenario}.expected_successors")
    witness_check(set(left) == set(right)
                  and successors == [
                      name for name, row in entries.items()
                      if row["status"] == "Applied"],
                  scenario, "orders_have_same_terminal_projection", done)
    finish_witness_checks(scenario, ex, done)


def execute_retiring(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "retiring_opportunity", {
        "cutover_turn", "opportunities", "old_membership_release_attempts",
        "retirement_fence", "token", "reservation",
    })
    done: list[str] = []
    opportunities = ex["opportunities"]
    require(natural(ex["cutover_turn"])
            and isinstance(opportunities, list) and opportunities,
            "retiring opportunities or cutover are malformed")
    for row in opportunities:
        exact_keys(row, {"id", "released_turn", "preserved"},
                   f"{scenario}.opportunity")
        require(nonempty_string(row["id"])
                and natural(row["released_turn"])
                and type(row["preserved"]) is bool,
                "retiring opportunity fields are malformed")
    preserved = [row for row in opportunities if row.get("preserved") is True]
    witness_check(len(preserved) <= 1, scenario, "at_most_one_preserved", done)
    witness_check(len(preserved) == 1
                  and preserved[0]["released_turn"] < ex["cutover_turn"],
                  scenario, "preserved_was_preboundary_released", done)
    fence = exact_keys(ex["retirement_fence"], {
        "generation_before", "generation_after", "release_not_after",
        "activation_not_after", "preserved_opportunity",
    }, f"{scenario}.retirement_fence")
    require_natural_fields(fence, (
        "generation_before", "generation_after", "release_not_after",
        "activation_not_after",
    ), f"{scenario}.retirement_fence")
    require(nonempty_string(fence["preserved_opportunity"]),
            "retirement fence opportunity must be a nonempty string")
    token = exact_keys(ex["token"], {
        "opportunity", "fence_generation", "activation_turn", "stop_turn",
    }, f"{scenario}.token")
    require_natural_fields(token, (
        "fence_generation", "activation_turn", "stop_turn",
    ), f"{scenario}.token")
    require(nonempty_string(token["opportunity"]),
            "retiring token opportunity must be a nonempty string")
    witness_check(fence["generation_after"] > fence["generation_before"]
                  and fence["release_not_after"] == ex["cutover_turn"]
                  and fence["preserved_opportunity"] == preserved[0]["id"]
                  and token["opportunity"] == fence["preserved_opportunity"]
                  and token["fence_generation"] == fence["generation_after"],
                  scenario, "token_binds_current_fence", done)
    witness_check(ex["cutover_turn"] < token["activation_turn"]
                  <= fence["activation_not_after"]
                  and token["stop_turn"] > token["activation_turn"],
                  scenario, "activation_within_cutoff", done)
    reservation = exact_keys(ex["reservation"], {
        "owner", "held_until_terminal", "released_after_terminal",
    }, f"{scenario}.reservation")
    require(nonempty_string(reservation["owner"]),
            "retiring reservation owner must be a nonempty string")
    require_boolean_fields(reservation, (
        "held_until_terminal", "released_after_terminal",
    ), f"{scenario}.reservation")
    witness_check(reservation["owner"] == fence["preserved_opportunity"]
                  and reservation["held_until_terminal"] is True
                  and reservation["released_after_terminal"] is True,
                  scenario, "reservation_has_owner_until_terminal", done)
    attempts = ex["old_membership_release_attempts"]
    require(isinstance(attempts, list) and attempts,
            "old-membership release attempts must be nonempty")
    for row in attempts:
        exact_keys(row, {"turn", "accepted"},
                   f"{scenario}.old_membership_release_attempt")
        require(natural(row["turn"]) and type(row["accepted"]) is bool,
                "old-membership release attempt is malformed")
    witness_check(all(row["turn"] > ex["cutover_turn"]
                      and row["accepted"] is False
                      for row in attempts),
                  scenario, "no_post_cutover_old_release", done)
    finish_witness_checks(scenario, ex, done)


def execute_failure_crash(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "scoped_failure_crash", {
        "events", "crash_recovery_prefixes", "lane_B",
    })
    done: list[str] = []
    events = ex["events"]
    require(isinstance(events, list) and len(events) == 6,
            "failure crash events must contain the six modeled steps")
    event_keys = {"step", "writer", "source_state", "txn_state", "commit_bit",
                  "materialized_generation", "effective_generation",
                  "audit_positions"}
    for row in events:
        exact_keys(row, event_keys, f"{scenario}.event")
        require_natural_fields(row, (
            "step", "materialized_generation", "effective_generation",
            "audit_positions",
        ), f"{scenario}.event")
        require_string_fields(row, (
            "writer", "source_state", "txn_state",
        ), f"{scenario}.event")
        require(type(row["commit_bit"]) is bool,
                "failure crash commit bit must be boolean")
    witness_check([row["step"] for row in events] == list(range(1, 7))
                  and events[0]["writer"] == "source_A"
                  and events[0]["source_state"] == "DurablePending"
                  and events[0]["txn_state"] == "None"
                  and events[1]["writer"] == "txn_A"
                  and events[1]["source_state"] == "DurablePendingLinked",
                  scenario, "source_pending_precedes_txn_link", done)
    commit_indices = [index for index, row in enumerate(events)
                      if row["commit_bit"] is True]
    require(commit_indices,
            "failure crash trace never commits the authority decision")
    first_commit = min(commit_indices)
    witness_check([row["commit_bit"] for row in events]
                  == [False, False, True, True, True, True]
                  and [row["txn_state"] for row in events]
                  == ["None", "Prepared", "Committed", "Committed",
                      "Committed", "Committed"]
                  and all(row["effective_generation"] == 4
                      for row in events[:first_commit])
                  and all(row["effective_generation"] == 5
                          for row in events[first_commit:]),
                  scenario, "effective_generation_changes_only_at_commit", done)
    witness_check([row["writer"] for row in events] == [
                      "source_A", "txn_A", "txn_A", "scope_A",
                      "source_A", "audit_A",
                  ]
                  and [row["materialized_generation"] for row in events]
                  == [4, 4, 4, 5, 5, 5]
                  and events[first_commit]["materialized_generation"] == 4
                  and events[first_commit + 1]["materialized_generation"] == 5
                  and events[first_commit]["effective_generation"]
                  == events[first_commit + 1]["effective_generation"],
                  scenario, "materialization_does_not_change_authority", done)
    terminal_indices = [index for index, row in enumerate(events)
                        if row["source_state"] == "Terminal"]
    witness_check([row["source_state"] for row in events] == [
                      "DurablePending", "DurablePendingLinked",
                      "DurablePendingLinked", "DurablePendingLinked",
                      "Terminal", "Terminal",
                  ]
                  and terminal_indices == [4, 5]
                  and terminal_indices[0] > first_commit,
                  scenario, "source_terminal_after_commit", done)
    witness_check(events[-1]["audit_positions"] == 1
                  and max(row["audit_positions"] for row in events) == 1,
                  scenario, "one_audit_position", done)
    witness_check(ex["crash_recovery_prefixes"]
                  == list(range(1, len(events) + 1))
                  and all(row["effective_generation"] in {4, 5}
                          for row in events),
                  scenario, "every_prefix_has_fail_closed_recovery", done)
    lane_b = exact_keys(ex["lane_B"], {
        "scope", "delivery_receipts", "terminal", "changed_by_failure_A",
    }, f"{scenario}.lane_B")
    witness_check(lane_b["scope"] == "scope_B"
                  and lane_b["delivery_receipts"] == 1
                  and lane_b["terminal"] is True
                  and lane_b["changed_by_failure_A"] is False,
                  scenario, "disjoint_lane_unchanged", done)
    finish_witness_checks(scenario, ex, done)


def execute_source_exhaustion(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "source_exhaustion", {
        "source_namespace", "emergency_transaction", "dependent_uses",
        "alternate_selection_after_failure",
    })
    done: list[str] = []
    namespace = exact_keys(ex["source_namespace"], {
        "next", "maximum", "exhausted",
    }, f"{scenario}.source_namespace")
    require_natural_fields(namespace, ("next", "maximum"),
                           f"{scenario}.source_namespace")
    require(type(namespace["exhausted"]) is bool,
            "source exhaustion flag must be boolean")
    witness_check(namespace["next"] > namespace["maximum"]
                  and namespace["exhausted"] is True,
                  scenario, "exhaustion_detected_before_wrap", done)
    emergency = exact_keys(ex["emergency_transaction"], {
        "namespace", "pre_reserved", "uses_exhausted_namespace",
    }, f"{scenario}.emergency_transaction")
    require(nonempty_string(emergency["namespace"]),
            "emergency namespace must be a nonempty string")
    require_boolean_fields(emergency, (
        "pre_reserved", "uses_exhausted_namespace",
    ), f"{scenario}.emergency_transaction")
    witness_check(emergency["namespace"] == "source_health_emergency"
                  and emergency["pre_reserved"] is True
                  and emergency["uses_exhausted_namespace"] is False,
                  scenario, "emergency_identity_is_independent", done)
    uses = exact_keys(ex["dependent_uses"], {"A", "B"},
                      f"{scenario}.dependent_uses")
    use_a = exact_keys(uses["A"], {
        "binds_source_health", "token_executable_after_fence",
    }, f"{scenario}.dependent_uses.A")
    use_b = exact_keys(uses["B"], {
        "binds_source_health", "alternate_coverage_preselected",
        "token_executable_after_fence",
    }, f"{scenario}.dependent_uses.B")
    require_boolean_fields(use_a, (
        "binds_source_health", "token_executable_after_fence",
    ), f"{scenario}.dependent_uses.A")
    require_boolean_fields(use_b, (
        "binds_source_health", "alternate_coverage_preselected",
        "token_executable_after_fence",
    ), f"{scenario}.dependent_uses.B")
    witness_check(uses["A"]["binds_source_health"] is True
                  and uses["A"]["token_executable_after_fence"] is False,
                  scenario, "dependent_use_fenced", done)
    witness_check(uses["B"]["binds_source_health"] is False
                  and uses["B"]["alternate_coverage_preselected"] is True
                  and uses["B"]["token_executable_after_fence"] is True,
                  scenario, "independent_preselected_coverage_survives", done)
    witness_check(ex["alternate_selection_after_failure"] is False,
                  scenario, "no_retroactive_alternate", done)
    finish_witness_checks(scenario, ex, done)


def execute_calendar_migration(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "calendar_migration", {
        "calendar", "source", "destination", "clock_relation", "envelope",
        "expected",
    })
    done: list[str] = []
    calendar = exact_keys(ex["calendar"], {
        "base_ordinal", "base_tick", "period", "destination_lease_clock_epoch",
    }, f"{scenario}.calendar")
    require(all(natural(item) for item in calendar.values())
            and calendar["period"] > 0
            and calendar["destination_lease_clock_epoch"] > 0,
            "calendar values must be positive-domain naturals")
    source = exact_keys(ex["source"], {
        "node_incarnation", "lease_clock_epoch", "next_ordinal_before_skip",
        "debt_before_skip", "next_ordinal_after_skip", "debt_after_skip",
        "last_delivery_receipt", "last_delivery_tick", "stop_tick",
        "current_opportunity", "write_close_position", "zero_active_tokens",
        "zero_active_contexts", "unsettled_delivery_cells",
        "all_prior_settlements_terminal",
    }, f"{scenario}.source")
    destination = exact_keys(ex["destination"], {
        "node_incarnation", "lease_clock_epoch", "current_turn",
        "preparation_lead", "cell_for_q44", "release_tick",
        "activation_tick", "first_delivery_tick", "terminal_tick",
    }, f"{scenario}.destination")
    relation = exact_keys(ex["clock_relation"], {
        "certificate", "source_epoch", "destination_epoch", "valid",
        "source_last_delivery_to_destination_interval",
        "source_stop_to_destination_interval", "valid_destination_interval",
    }, f"{scenario}.clock_relation")
    envelope = exact_keys(ex["envelope"], {
        "not_before", "not_after", "authority_expiry", "maximum_gap",
        "rank_upper", "rank_bound",
    }, f"{scenario}.envelope")
    expected = exact_keys(ex["expected"], {
        "due_tick_q44", "due_end_tick_q44", "worst_case_delivery_gap",
    }, f"{scenario}.expected")
    require(isinstance(source["node_incarnation"], str)
            and bool(source["node_incarnation"])
            and isinstance(source["last_delivery_receipt"], str)
            and bool(source["last_delivery_receipt"])
            and isinstance(destination["node_incarnation"], str)
            and bool(destination["node_incarnation"])
            and source["node_incarnation"] != destination["node_incarnation"]
            and all(natural(source[name]) for name in (
                "lease_clock_epoch", "next_ordinal_before_skip",
                "debt_before_skip", "next_ordinal_after_skip",
                "debt_after_skip", "last_delivery_tick", "stop_tick",
                "write_close_position", "unsettled_delivery_cells",
            ))
            and all(natural(destination[name]) for name in (
                "lease_clock_epoch", "current_turn", "preparation_lead",
                "cell_for_q44", "release_tick", "activation_tick",
                "first_delivery_tick", "terminal_tick",
            ))
            and all(natural(item) for item in envelope.values())
            and all(natural(item) for item in expected.values()),
            "calendar migration values are malformed")
    due = calendar["base_tick"] + (
        source["next_ordinal_after_skip"] - calendar["base_ordinal"]
    ) * calendar["period"]
    due_end = due + calendar["period"]
    witness_check(due == expected["due_tick_q44"]
                  and due_end == expected["due_end_tick_q44"],
                  scenario, "due_tick_checked_arithmetic", done)
    relation_intervals = []
    for name in ("source_last_delivery_to_destination_interval",
                 "source_stop_to_destination_interval",
                 "valid_destination_interval"):
        interval = relation[name]
        require(isinstance(interval, list) and len(interval) == 2
                and all(natural(item) for item in interval)
                and interval[0] <= interval[1],
                f"invalid clock relation interval: {name}")
        relation_intervals.append(interval)
    last_delivery_interval, stop_interval, valid_interval = relation_intervals
    witness_check(isinstance(relation["certificate"], str)
                  and bool(relation["certificate"])
                  and relation["valid"] is True
                  and relation["source_epoch"] == source["lease_clock_epoch"]
                  and relation["destination_epoch"]
                  == destination["lease_clock_epoch"]
                  == calendar["destination_lease_clock_epoch"]
                  and source["lease_clock_epoch"]
                  != destination["lease_clock_epoch"]
                  and all(valid_interval[0] <= interval[0] <= interval[1]
                          <= valid_interval[1]
                          for interval in (last_delivery_interval,
                                           stop_interval)), scenario,
                  "clock_relation_binds_both_node_epochs_and_intervals", done)
    witness_check(source["write_close_position"] > 0
                  and source["current_opportunity"] is None
                  and source["zero_active_tokens"] is True
                  and source["zero_active_contexts"] is True
                  and source["unsettled_delivery_cells"] == 0
                  and source["all_prior_settlements_terminal"] is True,
                  scenario, "source_quiescence_write_close_and_zero_active",
                  done)
    witness_check(destination["activation_tick"] > stop_interval[1],
                  scenario,
                  "destination_activation_strictly_after_converted_source_stop",
                  done)
    witness_check(destination["cell_for_q44"]
                  == destination["current_turn"]
                  + source["next_ordinal_after_skip"]
                  - calendar["base_ordinal"]
                  and destination["cell_for_q44"]
                  >= destination["current_turn"]
                  + 1 + destination["preparation_lead"],
                  scenario, "destination_cell_is_exact_future_ordinal", done)
    witness_check(destination["activation_tick"] >= due
                  and destination["activation_tick"] >= envelope["not_before"],
                  scenario, "activation_after_due_and_envelope_start", done)
    witness_check(destination["first_delivery_tick"]
                  >= destination["activation_tick"]
                  and destination["first_delivery_tick"] < envelope["not_after"]
                  and destination["first_delivery_tick"] < due_end,
                  scenario, "first_delivery_inside_envelope_and_due_period", done)
    witness_check(destination["terminal_tick"] < due_end
                  and destination["terminal_tick"] < envelope["authority_expiry"],
                  scenario, "terminal_before_due_end_and_authority_expiry", done)
    gap = destination["first_delivery_tick"] - last_delivery_interval[0]
    witness_check(gap == expected["worst_case_delivery_gap"], scenario,
                  "worst_case_gap_uses_earliest_converted_last_delivery", done)
    witness_check(gap >= 0 and gap <= envelope["maximum_gap"], scenario,
                  "worst_case_gap_within_bound", done)
    witness_check(envelope["rank_upper"] <= envelope["rank_bound"],
                  scenario, "rank_within_bound", done)
    witness_check(source["next_ordinal_after_skip"]
                  == source["next_ordinal_before_skip"] + 1
                  and source["debt_after_skip"] >= source["debt_before_skip"]
                  and source["current_opportunity"] is None,
                  scenario, "debt_and_ordinal_preserved", done)
    finish_witness_checks(scenario, ex, done)


def execute_namespace_control(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "namespace_and_sparse_control", {
        "ring", "wear", "new_insert", "guaranteed_commit",
    })
    done: list[str] = []
    ring = exact_keys(ex["ring"], {
        "slots", "occupied", "cursor", "successor", "slots_inspected",
    }, f"{scenario}.ring")
    require_natural_fields(ring, (
        "slots", "cursor", "successor", "slots_inspected",
    ), f"{scenario}.ring")
    occupied = ring["occupied"]
    require(isinstance(occupied, list) and occupied
            and all(natural(item) for item in occupied)
            and len(occupied) == len(set(occupied))
            and all(item < ring["slots"] for item in occupied),
            "sparse-control occupied ring slots are malformed")
    witness_check(ring["successor"] in ring["occupied"]
                  and ring["slots_inspected"] == 1
                  and ring["slots"] > len(ring["occupied"]),
                  scenario, "selection_cost_constant_not_slot_scan", done)
    insertion = exact_keys(ex["new_insert"], {
        "slot", "cursor_before", "cursor_after", "older_successor",
    }, f"{scenario}.new_insert")
    require(all(natural(item) for item in insertion.values()),
            "sparse-control insertion fields must be naturals")
    witness_check(insertion["cursor_before"] == insertion["cursor_after"]
                  and insertion["cursor_before"] == ring["cursor"]
                  and insertion["older_successor"] == ring["successor"]
                  and insertion["slot"] < ring["slots"]
                  and insertion["slot"] not in occupied,
                  scenario, "cursor_stable_on_insert", done)
    wear = exact_keys(ex["wear"], {
        "guaranteed_before", "guaranteed_after", "best_effort_before",
        "best_effort_after_reject", "renewal_before", "renewal_after",
        "refund",
    }, f"{scenario}.wear")
    require(all(natural(item) for item in wear.values()),
            "namespace wear counters must be naturals")
    witness_check(wear["best_effort_after_reject"] >= 0
                  and wear["best_effort_after_reject"]
                  <= wear["best_effort_before"]
                  and wear["guaranteed_after"]
                  == wear["guaranteed_before"] - 1,
                  scenario, "best_effort_cannot_spend_guaranteed", done)
    witness_check(wear["refund"] == 0, scenario,
                  "wear_nonrefundable", done)
    witness_check(wear["renewal_before"] == wear["renewal_after"],
                  scenario, "renewal_headroom_unchanged", done)
    commit = exact_keys(ex["guaranteed_commit"], {
        "principal", "committed", "peer_overtook",
    }, f"{scenario}.guaranteed_commit")
    require(natural(commit["principal"])
            and type(commit["committed"]) is bool
            and type(commit["peer_overtook"]) is bool,
            "guaranteed commit fields are malformed")
    witness_check(commit["principal"] == ring["successor"]
                  and commit["committed"] is True
                  and commit["peer_overtook"] is False,
                  scenario, "selected_guaranteed_not_overtaken", done)
    finish_witness_checks(scenario, ex, done)


def execute_clock(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "clock_progress_or_failstop", {
        "lease_clock", "watchdog_clock", "progress_branch", "stutter_branch",
    })
    done: list[str] = []
    lease_clock = exact_keys(ex["lease_clock"], {"source", "epoch"},
                             f"{scenario}.lease_clock")
    watchdog_clock = exact_keys(ex["watchdog_clock"], {"source", "epoch"},
                                f"{scenario}.watchdog_clock")
    witness_check(isinstance(lease_clock["source"], str)
                  and bool(lease_clock["source"])
                  and isinstance(watchdog_clock["source"], str)
                  and bool(watchdog_clock["source"])
                  and lease_clock["source"] != watchdog_clock["source"]
                  and natural(lease_clock["epoch"])
                  and natural(watchdog_clock["epoch"])
                  and lease_clock["epoch"] > 0
                  and watchdog_clock["epoch"] > 0
                  and lease_clock["epoch"] != watchdog_clock["epoch"],
                  scenario, "clock_sources_and_epochs_are_distinct", done)
    progress = exact_keys(ex["progress_branch"], {
        "lease_ticks", "watchdog_turns", "expiry_tick", "expiry_fired",
        "time_bounded_liveness_claimed",
    }, f"{scenario}.progress_branch")
    stutter = exact_keys(ex["stutter_branch"], {
        "lease_ticks", "watchdog_turns",
        "maximum_watchdog_turn_delta_without_lease_progress",
        "time_scope_fence_committed", "node_failstop",
        "time_bounded_liveness_claimed_after_failstop",
    }, f"{scenario}.stutter_branch")
    progress_ticks = progress["lease_ticks"]
    progress_watchdog = progress["watchdog_turns"]
    stutter_ticks = stutter["lease_ticks"]
    stutter_watchdog = stutter["watchdog_turns"]
    arrays = (progress_ticks, progress_watchdog, stutter_ticks, stutter_watchdog)
    witness_check(all(isinstance(items, list) and len(items) >= 2
                      and all(natural(item) for item in items)
                      for items in arrays)
                  and natural(progress["expiry_tick"])
                  and natural(stutter[
                      "maximum_watchdog_turn_delta_without_lease_progress"]),
                  scenario, "all_clock_values_and_bounds_are_natural", done)
    witness_check(len(progress_ticks) == len(progress_watchdog)
                  and all(right > left for left, right
                          in zip(progress_ticks, progress_ticks[1:]))
                  and all(right > left for left, right
                          in zip(progress_watchdog, progress_watchdog[1:])),
                  scenario, "progress_branch_lease_and_watchdog_advance", done)
    witness_check(progress_ticks[-1] == progress["expiry_tick"]
                  and progress["expiry_fired"] is True,
                  scenario, "expiry_fires_at_boundary", done)
    witness_check(len(stutter_ticks) == len(stutter_watchdog)
                  and len(set(stutter_ticks)) == 1
                  and all(right > left for left, right
                          in zip(stutter_watchdog, stutter_watchdog[1:]))
                  and stutter_watchdog[-1] - stutter_watchdog[0]
                  >= stutter[
                      "maximum_watchdog_turn_delta_without_lease_progress"]
                  and stutter[
                      "maximum_watchdog_turn_delta_without_lease_progress"] > 0,
                  scenario,
                  "lease_stutter_reaches_independent_watchdog_bound", done)
    witness_check(stutter["time_scope_fence_committed"] is True
                  and stutter["node_failstop"] is True, scenario,
                  "stutter_branch_fences_and_failstops", done)
    witness_check(progress["time_bounded_liveness_claimed"] is True
                  and stutter["time_bounded_liveness_claimed_after_failstop"]
                  is False,
                  scenario, "liveness_withdrawn_after_failstop", done)
    finish_witness_checks(scenario, ex, done)


def execute_prefix_or_loss(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "settlement_prefix_or_continuity_loss", {
        "predecessor", "successor", "clock_relation", "prefix_branch",
        "loss_branch",
    })
    done: list[str] = []
    predecessor = exact_keys(ex["predecessor"], {
        "stream_incarnation", "placement_epoch", "fencing_token",
        "lease_clock_epoch", "write_close_position", "last_delivery_tick",
    }, f"{scenario}.predecessor")
    successor = exact_keys(ex["successor"], {
        "placement_epoch", "fencing_token", "lease_clock_epoch",
        "first_delivery_tick", "maximum_gap",
    }, f"{scenario}.successor")
    require(all(natural(item) for item in predecessor.values())
            and all(natural(item) for item in successor.values()),
            "settlement-prefix placement values must be naturals")
    witness_check(successor["placement_epoch"]
                  > predecessor["placement_epoch"]
                  and successor["fencing_token"]
                  > predecessor["fencing_token"],
                  scenario, "successor_placement_advances", done)
    relation = exact_keys(ex["clock_relation"], {
        "certificate", "predecessor_epoch", "successor_epoch", "valid",
        "last_delivery_source_tick",
        "last_delivery_to_successor_interval", "valid_successor_interval",
    }, f"{scenario}.clock_relation")
    converted = relation["last_delivery_to_successor_interval"]
    valid_interval = relation["valid_successor_interval"]
    require(isinstance(converted, list) and len(converted) == 2
            and isinstance(valid_interval, list) and len(valid_interval) == 2
            and all(natural(item) for item in converted + valid_interval)
            and natural(relation["predecessor_epoch"])
            and natural(relation["successor_epoch"])
            and natural(relation["last_delivery_source_tick"])
            and converted[0] <= converted[1]
            and valid_interval[0] <= valid_interval[1],
            "settlement-prefix clock relation intervals are malformed")
    witness_check(isinstance(relation["certificate"], str)
                  and bool(relation["certificate"])
                  and relation["valid"] is True
                  and relation["predecessor_epoch"]
                  == predecessor["lease_clock_epoch"]
                  and relation["successor_epoch"]
                  == successor["lease_clock_epoch"]
                  and predecessor["lease_clock_epoch"]
                  != successor["lease_clock_epoch"]
                  and relation["last_delivery_source_tick"]
                  == predecessor["last_delivery_tick"]
                  and valid_interval[0] <= converted[0] <= converted[1]
                  <= valid_interval[1], scenario,
                  "prefix_clock_relation_binds_epochs_and_interval", done)
    prefix_branch = exact_keys(ex["prefix_branch"], {
        "certificate", "successor_stream_incarnation", "exactly_once_claim",
        "maximum_gap_claim",
    }, f"{scenario}.prefix_branch")
    certificate = exact_keys(prefix_branch["certificate"], {
        "quorum_replicated", "predecessor_write_close_position",
        "no_later_delivery_fence", "quorum_checkpoint_position",
        "prefix_position", "settled_through_ordinal", "next_ordinal", "debt",
        "last_delivery_receipt", "last_delivery_tick",
        "open_ordinal_disposition", "prefix_digest",
    }, f"{scenario}.prefix_certificate")
    require(all(natural(certificate[name]) for name in (
                "predecessor_write_close_position",
                "quorum_checkpoint_position", "prefix_position",
                "settled_through_ordinal", "next_ordinal", "debt",
                "last_delivery_tick",
            ))
            and nonempty_string(certificate["last_delivery_receipt"])
            and nonempty_string(certificate["prefix_digest"]),
            "settlement prefix certificate values are malformed")
    witness_check(certificate["quorum_replicated"] is True
                  and certificate["predecessor_write_close_position"]
                  == predecessor["write_close_position"]
                  and certificate["no_later_delivery_fence"] is True
                  and predecessor["write_close_position"]
                  < certificate["quorum_checkpoint_position"]
                  < certificate["prefix_position"], scenario,
                  "prefix_follows_write_close_and_quorum_checkpoint", done)
    witness_check(certificate["quorum_replicated"] is True
                  and certificate["next_ordinal"]
                  == certificate["settled_through_ordinal"] + 1
                  and certificate["last_delivery_tick"]
                  == predecessor["last_delivery_tick"] > 0
                  and nonempty_string(certificate["last_delivery_receipt"])
                  and certificate["open_ordinal_disposition"] == "none"
                  and isinstance(certificate["prefix_digest"], str)
                  and certificate["prefix_digest"].startswith("sha256:")
                  and prefix_branch["successor_stream_incarnation"]
                  == predecessor["stream_incarnation"],
                  scenario, "prefix_branch_preserves_exact_state", done)
    witness_check(prefix_branch["successor_stream_incarnation"]
                  == predecessor["stream_incarnation"]
                  and certificate is not None,
                  scenario, "same_incarnation_requires_prefix", done)
    gap = successor["first_delivery_tick"] - converted[0]
    witness_check(prefix_branch["exactly_once_claim"] is True
                  and prefix_branch["maximum_gap_claim"] is True
                  and gap >= 0 and gap <= successor["maximum_gap"], scenario,
                  "prefix_branch_gap_theorem_holds", done)
    loss = exact_keys(ex["loss_branch"], {
        "certificate", "continuity_loss_record",
        "successor_stream_incarnation", "exactly_once_claim",
        "maximum_gap_claim",
    }, f"{scenario}.loss_branch")
    loss_record = exact_keys(loss["continuity_loss_record"], {
        "old_stream_incarnation", "new_stream_incarnation",
        "uncertain_ordinal_range", "old_range_nonservice",
    }, f"{scenario}.continuity_loss_record")
    witness_check(loss["certificate"] is None
                  and loss_record["old_stream_incarnation"]
                  == predecessor["stream_incarnation"]
                  and loss["successor_stream_incarnation"]
                  == predecessor["stream_incarnation"] + 1
                  and loss_record["new_stream_incarnation"]
                  == loss["successor_stream_incarnation"],
                  scenario, "missing_prefix_advances_incarnation", done)
    witness_check(loss["exactly_once_claim"] is False
                  and loss["maximum_gap_claim"] is False,
                  scenario, "loss_branch_withdraws_continuity_claims", done)
    witness_check(loss_record["old_range_nonservice"] is True
                  and isinstance(loss_record["uncertain_ordinal_range"], list)
                  and len(loss_record["uncertain_ordinal_range"]) == 2
                  and all(natural(item)
                          for item in loss_record["uncertain_ordinal_range"])
                  and loss_record["uncertain_ordinal_range"][0]
                  <= loss_record["uncertain_ordinal_range"][1],
                  scenario, "uncertain_old_range_is_nonservice", done)
    finish_witness_checks(scenario, ex, done)


def execute_lifecycle(scenario: str, value: Any) -> None:
    ex = exact_executable(value, "lifecycle_writer_refinement", {
        "machine_states", "service_trace", "suppressed_trace", "allowed_edges",
        "human_to_machine", "failure_writer_events",
    })
    done: list[str] = []
    expected_states = [
        "Released", "Preparing", "HeldReady", "ActivationIntentPending",
        "ActivatedUnserved", "Served", "SuppressedBeforeActivation",
        "StopPending", "Settling", "Terminal",
    ]
    expected_edges = {
        ("Released", "Preparing"),
        ("Preparing", "HeldReady"),
        ("HeldReady", "ActivationIntentPending"),
        ("ActivationIntentPending", "ActivatedUnserved"),
        ("ActivationIntentPending", "SuppressedBeforeActivation"),
        ("ActivatedUnserved", "Served"),
        ("ActivatedUnserved", "StopPending"),
        ("Served", "StopPending"),
        ("SuppressedBeforeActivation", "Settling"),
        ("StopPending", "Settling"),
        ("Settling", "Terminal"),
    }
    require(ex["machine_states"] == expected_states,
            "lifecycle machine-state inventory changed")
    raw_edges = ex["allowed_edges"]
    require(isinstance(raw_edges, list)
            and all(isinstance(edge, list) and len(edge) == 2
                    and all(isinstance(item, str) for item in edge)
                    for edge in raw_edges),
            "lifecycle edge schema is malformed")
    edges = {tuple(edge) for edge in raw_edges}
    traces = (ex["service_trace"], ex["suppressed_trace"])
    witness_check(edges == expected_edges
                  and len(raw_edges) == len(edges)
                  and ex["service_trace"] == [
                      "Released", "Preparing", "HeldReady",
                      "ActivationIntentPending", "ActivatedUnserved", "Served",
                      "StopPending", "Settling", "Terminal",
                  ]
                  and ex["suppressed_trace"] == [
                      "Released", "Preparing", "HeldReady",
                      "ActivationIntentPending", "SuppressedBeforeActivation",
                      "Settling", "Terminal",
                  ]
                  and all(all((left, right) in edges
                          for left, right in zip(trace, trace[1:]))
                      for trace in traces),
                  scenario, "trace_edges_allowed", done)
    mapping = exact_keys(ex["human_to_machine"], {
        "Released", "Preparing", "HeldReady", "ActivationIntentPending",
        "Activated", "WithdrawOrRevokePending", "Cleanup", "Settling",
        "Completed_Withdrawn_Revoked_LeaseExpired_or_ActivatedAndStopped",
    }, f"{scenario}.human_to_machine")
    require(all(isinstance(images, list)
                and all(isinstance(state, str) and state in expected_states
                        for state in images) for images in mapping.values()),
            "human lifecycle refinement contains an unknown machine state")
    preimages = {state for images in mapping.values() for state in images}
    witness_check(all(mapping.values())
                  and preimages == set(ex["machine_states"]), scenario,
                  "every_machine_state_has_human_preimage", done)
    witness_check(mapping["Activated"] == ["ActivatedUnserved", "Served"]
                  and "ActivatedUnserved" in ex["service_trace"]
                  and ex["service_trace"].index("ActivatedUnserved")
                  < ex["service_trace"].index("Served"),
                  scenario, "activated_unserved_distinct_from_served", done)
    witness_check(all(left != "Terminal" for left, _ in edges)
                  and all(trace[-1] == "Terminal" for trace in traces),
                  scenario, "terminal_is_absorbing", done)
    writer_events = ex["failure_writer_events"]
    require(isinstance(writer_events, list) and len(writer_events) == 2,
            "failure writer trace must contain exactly two events")
    for row in writer_events:
        exact_keys(row, {"step", "writer", "effect"},
                   f"{scenario}.failure_writer_event")
        require(natural(row["step"])
                and nonempty_string(row["writer"])
                and nonempty_string(row["effect"]),
                "failure writer event fields are malformed")
    witness_check(len(writer_events) == 2
                  and writer_events[0] == {
                      "step": 1, "writer": "source_owner",
                      "effect": "publish_DurablePending",
                  }
                  and writer_events[1] == {
                      "step": 2, "writer": "transaction_owner",
                      "effect": "allocate_and_link_PhysicalResidencyTxn",
                  }, scenario, "source_pending_precedes_transaction_link", done)
    witness_check(writer_events[0]["writer"] != writer_events[1]["writer"],
                  scenario, "writers_are_distinct", done)
    finish_witness_checks(scenario, ex, done)


WITNESS_EXECUTORS = {
    "hierarchy_capacity": execute_hierarchy,
    "hardware_execution_cells": execute_hardware_cells,
    "target_control_conservation": execute_target_control,
    "partition_import": execute_partition,
    "placement_horizon_supersession": execute_placement,
    "failure_cover_and_escrow": execute_failure_cover,
    "activation_delivery_crash": execute_activation,
    "management_bootstrap": execute_management,
    "disjoint_commutation": execute_commutation,
    "protected_service_capacity": execute_service_capacity,
    "independent_lane_progress": execute_independent_lane,
    "mixed_apply_failure": execute_mixed_apply,
    "retiring_opportunity": execute_retiring,
    "scoped_failure_crash": execute_failure_crash,
    "source_exhaustion": execute_source_exhaustion,
    "calendar_migration": execute_calendar_migration,
    "namespace_and_sparse_control": execute_namespace_control,
    "clock_progress_or_failstop": execute_clock,
    "settlement_prefix_or_continuity_loss": execute_prefix_or_loss,
    "lifecycle_writer_refinement": execute_lifecycle,
}


def validate_witness(root: Path, contract: dict[str, Any]) -> None:
    rel = contract["preformal_two_lane_witness"]
    require(rel ==
            "analysis/dynamic-residency-preformal-two-lane-witness-v1.json",
            "witness path changed")
    witness = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / rel), "pre-formal witness"))
    exact_keys(witness, {
        "schema_version", "id", "date", "work_record", "requirement",
        "analysis", "architecture_contract", "kind", "purpose",
        "not_a_tla_or_proof_result", "execution_semantics", "topology",
        "ownership", "shared_rely_guarantee", "scenarios", "coverage",
        "claims",
    }, "witness")
    require(witness["schema_version"] == 3
            and witness["id"] ==
            "dynamic-residency-preformal-two-lane-witness-v1"
            and witness["requirement"] == EXPECTED_REQUIREMENT
            and witness["architecture_contract"] ==
            "analysis/dynamic-admission-recurring-residency-architecture-contract-v1.json"
            and witness["kind"] == "executable_preformal_architecture_witness"
            and witness["not_a_tla_or_proof_result"] is True,
            "witness identity or proof boundary changed")
    semantics = exact_keys(witness["execution_semantics"], {
        "integer_domain", "time_intervals", "state_updates",
        "scenario_result", "failure_result", "scope",
    }, "witness.execution_semantics")
    require(semantics == {
        "integer_domain": "nonnegative_checked_integers_without_wrap",
        "time_intervals": "half_open_start_inclusive_end_exclusive",
        "state_updates":
            "ordered_total_transitions_with_explicit_pre_state_guards",
        "scenario_result":
            "validator_must_execute_every_required_check_from_structured_input_and_must_not_accept_narrative_labels_as_evidence",
        "failure_result": "one_failed_required_check_rejects_the_candidate",
        "scope":
            "finite_architecture_consistency_counterexample_witness_not_proof_not_freeze_not_protection_evidence",
    }, "witness execution semantics changed")

    topology = exact_keys(witness["topology"], {
        "protected_service_parent", "physical_execution_parent", "lanes",
        "plan_shards", "control_shards", "control_targets", "streams",
        "source_shards", "transition_shards", "failure_scopes",
        "audit_shards", "hierarchy_paths", "partition_modes",
        "clock_epochs", "bounds",
    }, "witness.topology")
    require(topology["lanes"] == ["lane_A", "lane_B"]
            and topology["control_targets"] == ["target_A", "target_B"],
            "witness two-lane/two-target topology changed")
    require(topology["clock_epochs"] == {
        "root_execution": 1, "service_opportunity": 1, "lane": 2,
        "control": 2, "target_control": 2, "lease": 1,
        "watchdog": 4,
    }, "witness clock epochs changed")
    require(topology["bounds"] == {
        "KDepth": 3, "KEligibleContexts": 2, "KSecurityScopes": 2,
        "KFailureScopesPerEvent": 1,
        "KFailureClosureIterations": 4, "KFailureClosureScopes": 6,
        "KFailureClosureEdges": 8, "KDelegationEdges": 2,
        "KReplicas": 2, "KTransitionShards": 2, "KControlTargets": 2,
        "KLiveAuthorityUsesPerScope": 2,
        "KLiveAuthorityUsesPerCoverAncestor": 6,
        "KQuiescenceReceipts": 7,
        "KProofBytes": 4096, "KVectorBytes": 2048,
        "KMutationFootprintEntries": 16,
    }, "witness NodeConfig bounds changed")

    ownership = witness["ownership"]
    require(isinstance(ownership, list) and len(ownership) == 31,
            "witness ownership inventory changed")
    objects: list[str] = []
    for row in ownership:
        exact_keys(row, {"object", "sole_writer", "readers",
                         "forbidden_writers"}, "witness ownership row")
        require(isinstance(row["object"], str) and row["object"],
                "empty witness ownership object")
        require(isinstance(row["sole_writer"], str) and row["sole_writer"],
                "empty witness sole writer")
        unique_strings(row["readers"], f"{row['object']}.readers")
        forbidden = unique_strings(row["forbidden_writers"],
                                   f"{row['object']}.forbidden")
        require(row["sole_writer"] not in forbidden,
                f"sole writer is forbidden for {row['object']}")
        objects.append(row["object"])
    require(len(objects) == len(set(objects)), "duplicate ownership object")
    owner_map = {row["object"]: row["sole_writer"] for row in ownership}
    for obj, owner in EXPECTED_OWNERS.items():
        require(owner_map.get(obj) == owner,
                f"critical witness owner changed: {obj}")

    scenarios = witness["scenarios"]
    require(isinstance(scenarios, list)
            and [row.get("id") for row in scenarios] == EXPECTED_SCENARIOS,
            "witness scenario inventory/order changed")
    machines: list[str] = []
    for row in scenarios:
        require(isinstance(row, dict)
                and isinstance(row.get("executable"), dict)
                and isinstance(row["executable"].get("machine"), str),
                "witness scenario or executable schema is malformed")
        machines.append(row["executable"]["machine"])
    require(list(WITNESS_EXECUTORS) == machines,
            "witness machine inventory/order changed")
    for row in scenarios:
        exact_keys(row, {
            "id", "purpose", "preconditions", "trace_left", "trace_right",
            "required_observations", "forbidden", "executable",
            "residual_executable_model",
        }, f"scenario {row.get('id')}")
        require(isinstance(row["purpose"], str) and row["purpose"],
                f"empty purpose: {row['id']}")
        for key in ("preconditions", "trace_left", "trace_right",
                    "required_observations", "forbidden"):
            values = unique_strings(row[key], f"{row['id']}.{key}")
            require(values, f"empty scenario field: {row['id']}.{key}")
        require(row["trace_left"] != row["trace_right"],
                f"paired traces are a no-op duplicate: {row['id']}")
        executable = row["executable"]
        require(isinstance(executable, dict)
                and executable.get("machine") in WITNESS_EXECUTORS,
                f"unknown executable witness machine: {row['id']}")
        try:
            WITNESS_EXECUTORS[executable["machine"]](row["id"], executable)
        except ValidationError:
            raise
        except (AttributeError, IndexError, KeyError, TypeError,
                ValueError) as error:
            raise ValidationError(
                f"malformed executable witness input: {row['id']}: "
                f"{type(error).__name__}: {error}") from error

    coverage = exact_keys(witness["coverage"], {
        "all_second_round_findings_partitioned", "third_round_trace_findings",
        "datacenter_composition_boundary_findings",
        "third_round_assurance_findings_owned_by_protocol_v2",
        "third_round_schema_mapping_and_vocabulary_findings_owned_by_validator",
        "fourth_round_architecture_findings_executed",
        "fifth_round_architecture_findings_executed",
        "every_scenario_has_structured_executable_input_and_required_checks",
        "validator_must_report_every_executed_check",
        "no_finding_is_closed_by_this_witness",
    }, "witness.coverage")
    require(coverage["all_second_round_findings_partitioned"] is True,
            "second-round witness partition changed")
    require(coverage["third_round_trace_findings"] == [
        "SEC-R3-01", "SEC-R3-02", "FORM-R3-02", "FORM-R3-03",
        "FORM-R3-04", "FORM-R3-05", "FORM-R3-06", "FORM-R3-07",
        "SCALE-R3-01", "SCALE-R3-02", "SCALE-R3-03",
        *EXPECTED_R3_SELF_IDS,
    ], "witness R3 trace partition changed")
    require(coverage["datacenter_composition_boundary_findings"]
            == EXPECTED_DC_IDS, "witness datacenter partition changed")
    require(coverage["fourth_round_architecture_findings_executed"]
            == EXPECTED_R4_IDS, "witness R4 partition changed")
    require(coverage["fifth_round_architecture_findings_executed"]
            == EXPECTED_R5_IDS, "witness R5 partition changed")
    require(coverage[
        "every_scenario_has_structured_executable_input_and_required_checks"
    ] is True and coverage["validator_must_report_every_executed_check"] is True,
            "witness executable coverage claim changed")
    require(coverage["no_finding_is_closed_by_this_witness"] is True,
            "witness closes findings")
    claims = witness["claims"]
    require(claims["witness_written"] is True
            and all(value is False for key, value in claims.items()
                    if key != "witness_written"),
            "witness overclaims")


def validate_markdown(root: Path, contract: dict[str, Any]) -> None:
    analysis = resolve_regular_file(
        root, str(ANALYSIS_PREFIX / contract["analysis"]), "human contract")
    text = artifact_text(analysis)
    require(fenced_block(text, "Safety Invariants") == contract["safety"],
            "human/machine safety inventory or order differs")
    require(fenced_block(text, "Required Negative Matrix") ==
            contract["negative_cases"],
            "human/machine negative inventory or order differs")
    required_phrases = [
        "NodeConfig", "DomainHierarchyCertificate",
        "RootExecutionAllocationCertificate", "TargetControlTurn",
        "NodeLeaseImportCertificate", "GlobalPlacementUse",
        "CanonicalFailureCover", "ActivationIntent",
        "ExecutionContextKey", "ActivationCommitReceipt",
        "ManagementRecoveryBootstrapContract",
        "Network silence is never quiescence",
        "TLA+ begins only after a separate valid freeze record",
    ]
    for phrase in required_phrases:
        require(phrase in text, f"human contract omits critical phrase: {phrase}")

    witness_rel = contract["preformal_two_lane_witness"]
    witness = load_strict_json(resolve_regular_file(
        root, str(ANALYSIS_PREFIX / witness_rel), "witness"))
    witness_md = resolve_regular_file(
        root, str(ANALYSIS_PREFIX / witness["analysis"]), "witness Markdown")
    witness_text = artifact_text(witness_md)
    headings = re.findall(r"^## Witness (\d+): .*?\(`([^`]+)`\)$",
                          witness_text, re.MULTILINE)
    require([int(number) for number, _ in headings]
            == list(range(1, len(EXPECTED_SCENARIOS) + 1)),
            "witness Markdown numbering is incomplete")
    require([scenario_id for _, scenario_id in headings] == EXPECTED_SCENARIOS,
            "witness Markdown/machine scenario order differs")


def validate_candidate_pins(root: Path, contract: dict[str, Any]) -> str:
    require(set(EXPECTED_SECTION_DIGESTS) == EXPECTED_TOP_KEYS,
            "validator section pins are incomplete")
    for key in sorted(EXPECTED_TOP_KEYS):
        require(canonical_digest(contract[key]) == EXPECTED_SECTION_DIGESTS[key],
                f"candidate section bytes changed without validator review: {key}")
    require(EXPECTED_ARTIFACT_DIGESTS,
            "validator artifact pins are not populated")
    for relative, expected in EXPECTED_ARTIFACT_DIGESTS.items():
        path = resolve_regular_file(root, relative, f"pinned artifact {relative}")
        require(file_digest(path) == expected,
                f"candidate artifact changed without validator review: {relative}")
    artifacts: list[dict[str, Any]] = []
    for relative in sorted(EXPECTED_ARTIFACT_DIGESTS):
        path = resolve_regular_file(root, relative,
                                    f"candidate object {relative}")
        data = artifact_bytes(path)
        artifacts.append({
            "path": relative,
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
        })
    object_set = {
        "schema": "domainlease.residency-dyn.preformal-object-set.v1",
        "contract_id": EXPECTED_ID,
        "requirement": EXPECTED_REQUIREMENT,
        "section_sha256": {
            key: canonical_digest(contract[key])
            for key in sorted(EXPECTED_TOP_KEYS)
        },
        "artifacts": artifacts,
    }
    object_set_digest = canonical_digest(object_set)
    require(object_set_digest == EXPECTED_CANDIDATE_OBJECT_SET_DIGEST,
            "candidate object-set digest changed without validator review")
    return object_set_digest


def validate(root: Path, contract_path: Path) -> str:
    contract = load_strict_json(contract_path)
    exact_keys(contract, EXPECTED_TOP_KEYS, "architecture contract")
    require(contract["schema_version"] == 1, "contract schema changed")
    require(contract["id"] == EXPECTED_ID, "contract id changed")
    require(contract["requirement"] == EXPECTED_REQUIREMENT,
            "contract requirement changed")
    require(contract["status"] == EXPECTED_STATUS,
            "candidate status may not claim freeze")
    require(contract["implementation_selected"] is False
            and contract["linux_behavior_change_approved"] is False,
            "candidate selected implementation or Linux behavior")
    require(contract["claims"] == EXPECTED_CLAIMS,
            "candidate claims changed or overclaim")
    require(contract["object_types"] == EXPECTED_OBJECT_TYPES,
            "object type inventory/order changed")
    require(contract["version_spaces"] == EXPECTED_VERSION_SPACES,
            "version-space inventory/order changed")
    require(contract["formal_decomposition"]["models"] == EXPECTED_MODELS,
            "formal decomposition model inventory changed")
    require(contract["formal_decomposition"]["derived_not_stored_predicates"]
            == EXPECTED_DERIVED, "derived predicate inventory changed")
    require(contract["formalization_order"][-1] ==
            "claim_specific_EC1_decision",
            "formalization order no longer ends in claim decision")
    require(contract["formalization_order"].index(
        "recompute_threshold_verify_and_derive_separate_preformal_freeze_with_exact_capsule_tla_authorization"
    ) < contract["formalization_order"].index(
        "decomposed_tla_models_including_DYN_SHARD_and_DYN_MULTILANE_COMPOSE"
    ), "TLA appears before an external freeze record")
    require(contract["linux_source_identity"] == {
        "work_commit": EXPECTED_LINUX_COMMIT,
        "work_tree": EXPECTED_LINUX_TREE,
        "newer_upstream_rhashtable_fix":
            "8173f7e2ce67e6ca1d4763f3da14e5b01ce77456",
        "newer_fix_is_current_domainlease_vulnerability_evidence": False,
        "implementation_rebase_required": True,
    }, "Linux source identity changed")

    serialized = json.dumps(contract, ensure_ascii=False, sort_keys=True)
    for term in OBSOLETE_TERMS:
        require(term not in serialized, f"obsolete architecture term remains: {term}")

    validate_parent_registry(contract)
    validate_formal_dependency_dag(contract)
    validate_critical_contract(contract)
    validate_review_ledger(root, contract)
    validate_assurance_protocol(root, contract)
    validate_witness(root, contract)
    validate_markdown(root, contract)
    return validate_candidate_pins(root, contract)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path,
                        default=Path(__file__).resolve().parents[2])
    parser.add_argument("--contract", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        ARTIFACT_BYTES.clear()
        if args.contract:
            supplied = args.contract.resolve()
            try:
                contract_relative = str(supplied.relative_to(root))
            except ValueError as error:
                raise ValidationError(
                    "contract path must remain inside --root") from error
        else:
            contract_relative = str(CONTRACT_REL)
        contract_path = resolve_regular_file(
            root, contract_relative, "architecture contract")
        object_set_digest = validate(root, contract_path)
    except (OSError, UnicodeError, ValidationError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(
        "PASS: exact RESIDENCY-DYN pre-formal candidate is internally "
        "consistent; architecture freeze, TLA, protection, and deployment "
        "claims remain false; candidate_object_set_sha256="
        f"{object_set_digest}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
