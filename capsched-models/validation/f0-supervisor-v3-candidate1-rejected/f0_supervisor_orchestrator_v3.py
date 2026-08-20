#!/usr/bin/env python3
"""Actor-separated parent orchestration LTS for supervisor v3 candidate-1."""

from __future__ import annotations

from collections import Counter, defaultdict, deque
from dataclasses import dataclass, replace
from functools import lru_cache

import f0_supervisor_lts_v3 as child


SCHEMA = "F0-SPV3-ORCH-C1"

ACTORS = {
    "EXTERNAL_OWNER",
    "PRIMARY_SUPERVISOR",
    "RECOVERY_GUARDIAN",
    "CHILD_ENVELOPE",
    "DURABLE_STORE",
    "ADVERSARY",
}
CONTROLLERS = {"PRIMARY_SUPERVISOR", "RECOVERY_GUARDIAN"}
PHASES = {
    "WAIT_GRANT",
    "GRANT_AVAILABLE",
    "GRANT_CONSUME_PENDING",
    "PARENT_ACTIVE",
    "PRODUCER_GRANT_AVAILABLE",
    "PRODUCER_RUNNING",
    "PRODUCER_ATTACHED",
    "CHECKER_GRANT_AVAILABLE",
    "CHECKER_RUNNING",
    "CHILDREN_COMPLETE",
    "PARENT_SEALED",
    "LOCAL_DECIDED",
    "PREPARED",
    "DURABLE",
    "ABANDONING",
    "ASSURANCE_BREACHED",
    "TERMINAL",
}
OWNER_STATES = {"ACTIVE", "FAILED"}
PRIMARY_STATES = {"ACTIVE", "FAILED"}
GUARDIAN_STATES = {"ACTIVE", "FAILED"}
CHILD_STATUSES = {"NONE", "GRANT_AVAILABLE", "RUNNING", "ATTACHED", "SKIPPED"}
PARENT_LEDGERS = {"OPEN", "SEALED"}
LOCAL_DISPOSITIONS = {
    "NONE",
    "LOCAL_CHECKED_CANDIDATE",
    "LOCAL_REJECTED_CANDIDATE",
    "INCONCLUSIVE_RESOURCE",
    "INTERNAL_FAILURE",
    "ABANDONED",
}
PUBLICATIONS = {
    "NONE",
    "PREPARED",
    "DURABLE",
    "PUBLISHED",
    "ABANDONING",
    "ABANDONED",
    "STALE_REJECTED",
    "ASSURANCE_BREACHED",
}
PENDING_ATTACKS = {"NONE", "GRANT_REPLAY", "PUBLICATION_ROLLBACK"}
GRANT_REGISTRY_STATES = {"NONE", "ISSUED", "PENDING", "CONSUMED", "RETIRED"}
ASSURANCE_BREACHES = {
    "NONE",
    "GUARDIAN_FAILURE",
    "GRANT_REGISTRY_BYPASS",
    "PUBLICATION_ROLLBACK",
}
TERMINAL_PUBLICATIONS = {
    "PUBLISHED",
    "ABANDONED",
    "STALE_REJECTED",
    "ASSURANCE_BREACHED",
}

OPEN_REFINEMENT_OBLIGATIONS = (
    "ORCH-EXT-001 external parent and child RunGrant authenticity and uniqueness",
    "ORCH-REG-001 external issuance registry atomic consume-or-retire and global nonce uniqueness",
    "ORCH-CHILD-001 refinement from child terminal state to attached certificate",
    "ORCH-INDEP-001 producer/checker process, code, authority, and failure independence",
    "ORCH-STORE-001 durable-store authentication, atomic CAS, recovery, and anti-rollback",
    "ORCH-GUARD-001 guardian cleanup authority after owner or primary failure",
    "ORCH-LIVE-001 fairness for child cleanup, store acknowledgment, and publication",
    "ORCH-SEM-001 external semantic verifier and verdict issuance remain outside this LTS",
)


class OrchestratorReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


@dataclass(frozen=True)
class ParentGrant:
    parent_run_id: str
    epoch: int
    nonce: str
    validation_context_digest: str
    policy_digest: str
    profile_digest: str
    immutable_input_digest: str
    issuance_registry_id: str
    issuance_generation: int
    expected_publication_generation: int
    issuer: str
    auth_tag: str


def _parent_grant_payload(grant: ParentGrant) -> tuple[object, ...]:
    return (
        grant.parent_run_id,
        grant.epoch,
        grant.nonce,
        grant.validation_context_digest,
        grant.policy_digest,
        grant.profile_digest,
        grant.immutable_input_digest,
        grant.issuance_registry_id,
        grant.issuance_generation,
        grant.expected_publication_generation,
        grant.issuer,
    )


def parent_binding_digest(grant: ParentGrant) -> str:
    return child.digest("PARENT_GRANT_BINDING", *_parent_grant_payload(grant))


def _parent_grant_auth(grant: ParentGrant) -> str:
    return child.digest("ABSTRACT_PARENT_OWNER_AUTH", *_parent_grant_payload(grant))


def fixture_parent_grant() -> ParentGrant:
    partial = ParentGrant(
        parent_run_id="parent-e1-nonce-a",
        epoch=1,
        nonce="parent-nonce-a",
        validation_context_digest="validation-context-root-a",
        policy_digest="policy-root-a",
        profile_digest="profile-root-a",
        immutable_input_digest="input-root-a",
        issuance_registry_id="run-issuance-registry-a",
        issuance_generation=1,
        expected_publication_generation=0,
        issuer="EXTERNAL_OWNER",
        auth_tag="",
    )
    return replace(partial, auth_tag=_parent_grant_auth(partial))


def parent_grant_wf(grant: ParentGrant) -> bool:
    return (
        grant.epoch > 0
        and bool(grant.parent_run_id)
        and bool(grant.nonce)
        and bool(grant.validation_context_digest)
        and bool(grant.policy_digest)
        and bool(grant.profile_digest)
        and bool(grant.immutable_input_digest)
        and bool(grant.issuance_registry_id)
        and grant.issuance_generation > 0
        and grant.expected_publication_generation >= 0
        and grant.issuer == "EXTERNAL_OWNER"
        and grant.auth_tag == _parent_grant_auth(replace(grant, auth_tag=""))
    )


@dataclass(frozen=True)
class GrantConsumptionAck:
    schema: str
    parent_run_id: str
    binding_digest: str
    nonce: str
    epoch: int
    registry_id: str
    old_generation: int
    new_generation: int
    outcome: str
    issuer: str
    auth_tag: str


def _grant_consumption_ack_body(ack: GrantConsumptionAck) -> tuple[object, ...]:
    return (
        ack.schema,
        ack.parent_run_id,
        ack.binding_digest,
        ack.nonce,
        ack.epoch,
        ack.registry_id,
        ack.old_generation,
        ack.new_generation,
        ack.outcome,
        ack.issuer,
    )


def _grant_consumption_ack_auth(ack: GrantConsumptionAck) -> str:
    return child.digest(
        "ABSTRACT_GRANT_REGISTRY_ACK_AUTH",
        *_grant_consumption_ack_body(ack),
    )


def _grant_consume_request_payload(grant: ParentGrant) -> str:
    return child.digest(
        "PARENT_GRANT_CONSUME_REQUEST",
        parent_binding_digest(grant),
        grant.issuance_registry_id,
        grant.issuance_generation,
    )


def _grant_consumption_ack_payload(ack: GrantConsumptionAck) -> str:
    return child.digest(
        "PARENT_GRANT_REGISTRY_ACK",
        *_grant_consumption_ack_body(ack),
        ack.auth_tag,
    )


def grant_consumption_ack_wf(
    ack: GrantConsumptionAck,
    grant: ParentGrant,
) -> bool:
    return (
        ack.schema == SCHEMA
        and ack.parent_run_id == grant.parent_run_id
        and ack.binding_digest == parent_binding_digest(grant)
        and ack.nonce == grant.nonce
        and ack.epoch == grant.epoch
        and ack.registry_id == grant.issuance_registry_id
        and ack.old_generation == grant.issuance_generation
        and ack.new_generation == ack.old_generation + 1
        and ack.outcome in {"CONSUMED", "RETIRED"}
        and ack.issuer == "DURABLE_STORE"
        and ack.auth_tag
        == _grant_consumption_ack_auth(replace(ack, auth_tag=""))
    )


def fixture_child_grant(
    parent: ParentGrant,
    role: str,
    immutable_input_digest: str,
) -> child.RunGrant:
    nonce = f"{parent.nonce}:{role.lower()}"
    grant = child.fixture_external_grant(
        role,
        parent_run_id=parent.parent_run_id,
        epoch=parent.epoch,
        nonce=nonce,
        immutable_input_digest=immutable_input_digest,
    )
    grant = replace(
        grant,
        validation_context_digest=parent.validation_context_digest,
        policy_digest=parent.policy_digest,
        profile_digest=parent.profile_digest,
        auth_tag="",
    )
    return replace(grant, auth_tag=child._grant_auth_tag(grant))


def child_grant_matches_parent(
    grant: child.RunGrant,
    parent: ParentGrant,
    role: str,
    immutable_input_digest: str,
) -> bool:
    expected = fixture_child_grant(parent, role, immutable_input_digest)
    return child.grant_wf(grant) and grant == expected


@dataclass(frozen=True)
class ChildCertificate:
    grant: child.RunGrant
    trace_actions: tuple[str, ...]
    trace_digest: str
    evidence_root: str
    local_decision: str
    payload_kind: str
    payload_value: str
    payload_digest: str
    decision_receipt: child.DecisionReceipt
    certificate_digest: str


def _certificate_payload(certificate: ChildCertificate) -> tuple[object, ...]:
    return (
        child.grant_binding_digest(certificate.grant),
        certificate.trace_digest,
        certificate.evidence_root,
        certificate.local_decision,
        certificate.payload_kind,
        certificate.payload_value,
        certificate.payload_digest,
        certificate.decision_receipt.auth_tag,
    )


def certificate_digest(certificate: ChildCertificate) -> str:
    return child.digest("CHILD_CERTIFICATE", *_certificate_payload(certificate))


def _child_trace_digest(trace_actions: tuple[str, ...]) -> str:
    return child.digest("CHILD_TERMINAL_TRACE", *trace_actions)


@lru_cache(maxsize=None)
def _replay_child_terminal(
    grant: child.RunGrant,
    trace_actions: tuple[str, ...],
) -> child.EnvelopeState:
    return child.apply_trace(child.initial_state(grant), trace_actions)


def certificate_from_terminal(
    state: child.EnvelopeState,
    trace_actions: tuple[str, ...],
) -> ChildCertificate:
    if not child.instance_wf(state) or state.phase != "DECIDED" or state.decision_receipt is None:
        raise OrchestratorReject("F05-ORCH-CHILD-NOT-DECIDED", state.phase)
    if not trace_actions or _replay_child_terminal(state.grant, trace_actions) != state:
        raise OrchestratorReject("F05-ORCH-CHILD-TRACE-MISMATCH", state.phase)
    partial = ChildCertificate(
        grant=state.grant,
        trace_actions=trace_actions,
        trace_digest=_child_trace_digest(trace_actions),
        evidence_root=state.evidence_root,
        local_decision=state.local_decision,
        payload_kind=state.candidate_kind,
        payload_value=state.candidate_value,
        payload_digest=state.candidate_digest,
        decision_receipt=state.decision_receipt,
        certificate_digest="",
    )
    return replace(partial, certificate_digest=certificate_digest(partial))


def _certificate_payload_wf(certificate: ChildCertificate) -> bool:
    if certificate.payload_kind == "NONE":
        return certificate.payload_value == "NONE" and certificate.payload_digest == ""
    expected_values = {
        "PRODUCER_RESULT": {"VALUE_A", "VALUE_B"},
        "CHECKER_ACCEPT": {"ACCEPT"},
        "CHECKER_REJECT": {"REJECT"},
        "INTERNAL": {"INTERNAL"},
    }
    if certificate.payload_value not in expected_values.get(certificate.payload_kind, set()):
        return False
    fixture = child.initial_state(certificate.grant)
    return certificate.payload_digest == child._expected_candidate_digest(
        fixture,
        certificate.payload_kind,
        certificate.payload_value,
    )


def child_certificate_wf(
    certificate: ChildCertificate,
    parent: ParentGrant,
    role: str,
    immutable_input_digest: str,
) -> bool:
    receipt = certificate.decision_receipt
    try:
        terminal = _replay_child_terminal(
            certificate.grant,
            certificate.trace_actions,
        )
    except (child.ProtocolReject, ValueError):
        return False
    return (
        child_grant_matches_parent(certificate.grant, parent, role, immutable_input_digest)
        and bool(certificate.trace_actions)
        and certificate.trace_digest == _child_trace_digest(certificate.trace_actions)
        and child.instance_wf(terminal)
        and terminal.phase == "DECIDED"
        and terminal.grant == certificate.grant
        and terminal.evidence_root == certificate.evidence_root
        and terminal.local_decision == certificate.local_decision
        and terminal.candidate_kind == certificate.payload_kind
        and terminal.candidate_value == certificate.payload_value
        and terminal.candidate_digest == certificate.payload_digest
        and terminal.decision_receipt == receipt
        and bool(certificate.evidence_root)
        and certificate.local_decision in child.LOCAL_DECISIONS - {"NONE"}
        and certificate.payload_kind in child.CANDIDATE_KINDS
        and certificate.payload_value in child.CANDIDATE_VALUES
        and _certificate_payload_wf(certificate)
        and receipt.schema == child.SCHEMA
        and receipt.run_id == certificate.grant.child_run_id
        and receipt.binding_digest == child.grant_binding_digest(certificate.grant)
        and receipt.evidence_root == certificate.evidence_root
        and receipt.decision == certificate.local_decision
        and receipt.payload_kind == certificate.payload_kind
        and receipt.payload_digest == certificate.payload_digest
        and receipt.issuer in child.CONTROLLERS
        and receipt.auth_tag == child._decision_auth_tag(replace(receipt, auth_tag=""))
        and certificate.certificate_digest
        == certificate_digest(replace(certificate, certificate_digest=""))
    )


CHILD_SETUP = (
    "SUP-001-REQUEST-SCOPE",
    "OBS-002-CONFIGURE-SCOPE-ACK",
    "SUP-003-REQUEST-CHARGED-BOOTSTRAP",
    "OBS-004-CHARGED-BOOTSTRAP-ACK",
    "MON-004B-ACTIVATE-EXECUTION",
    "SUP-005-REQUEST-SANDBOX",
    "OBS-006-SANDBOX-PROFILE-ACK",
    "MON-007-BASELINE-COUNTERS",
    "SUP-008-RELEASE-HOSTILE-PAYLOAD",
)
CHILD_CLEANUP = (
    "MON-035B-REVOKE-EXECUTION",
    "OBS-036-LEADER-REAPED",
    "OBS-037-VISIBLE-EMPTY",
    "OBS-039-RMDIR-ATTACH-CLOSED",
    "SUP-039B-CLOSE-ASYNC-ADMISSION",
    "MON-039C-PROTECTION-CLOSED",
    "OBS-038-TASK-POPULATION-ZERO",
    "OBS-040-HIDDEN-WORK-DRAINED",
    "MON-041-FINAL-COUNTERS",
    "OBS-043-CSS-OFFLINE",
    "OBS-044-SCOPE-RELEASED",
    "SUP-045-SEAL-EVIDENCE",
    "SUP-046-DECIDE-LOCAL",
)


@lru_cache(maxsize=None)
def fixture_child_certificate(grant: child.RunGrant, scenario: str) -> ChildCertificate:
    candidate = (
        "OBS-009A-PRODUCER-CANDIDATE-A"
        if grant.role == "PRODUCER"
        else "OBS-010-CHECKER-ACCEPT"
    )
    if scenario == "CANDIDATE_B" and grant.role == "PRODUCER":
        candidate = "OBS-009B-PRODUCER-CANDIDATE-B"
    if scenario == "CHECKER_REJECT" and grant.role == "CHECKER":
        candidate = "OBS-011-CHECKER-REJECT"

    if scenario in {"CANDIDATE", "CANDIDATE_B", "CHECKER_REJECT"}:
        suffix = (
            (
                candidate,
                "OBS-013-EOF-VALID",
                "OBS-029-NORMAL-EXIT",
            )
            + CHILD_CLEANUP[:9]
            + ("ARB-034-COMPLETION-WINS",)
            + CHILD_CLEANUP[9:]
        )
    elif scenario == "RESOURCE":
        suffix = (
            (
                "MON-026-QUOTA-ARRIVAL",
                "ARB-026B-QUOTA-WINS",
                candidate,
                "OBS-013-EOF-VALID",
                "SUP-028-REQUEST-TERMINATION",
                "OBS-030-SIGNAL-EXIT",
            )
            + CHILD_CLEANUP
        )
    elif scenario == "INTERNAL":
        suffix = (
            (
                "OBS-012-INTERNAL-FRAME",
                "ARB-035-FAULT-WINS",
                "SUP-028-REQUEST-TERMINATION",
                "OBS-030-SIGNAL-EXIT",
                "OBS-015-EOF-INVALID",
            )
            + CHILD_CLEANUP
        )
    elif scenario == "ABANDONED":
        suffix = (
            (
                "EXT-025-REVOKE-RUN",
                "ARB-035-FAULT-WINS",
                "SUP-028-REQUEST-TERMINATION",
                "OBS-030-SIGNAL-EXIT",
                "OBS-014-EOF-TRUNCATED",
            )
            + CHILD_CLEANUP
        )
    else:
        raise OrchestratorReject("F05-ORCH-SCENARIO", scenario)
    trace_actions = CHILD_SETUP + suffix
    state = _replay_child_terminal(grant, trace_actions)
    return certificate_from_terminal(state, trace_actions)


def expected_checker_input(producer: ChildCertificate) -> str:
    return child.digest(
        "CHECKER_INPUT_BINDING",
        producer.certificate_digest,
    )


@dataclass(frozen=True)
class ParentReceiptSpec:
    issuers: frozenset[str]


PARENT_RECEIPT_SPECS = {
    "PARENT_GRANT_CONSUME_REQUESTED": ParentReceiptSpec(frozenset(CONTROLLERS)),
    "PARENT_GRANT_CONSUMED": ParentReceiptSpec(frozenset({"DURABLE_STORE"})),
    "PARENT_GRANT_RETIRED": ParentReceiptSpec(frozenset({"DURABLE_STORE"})),
    "PRODUCER_GRANT_ACCEPTED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "PRODUCER_CERT_ATTACHED": ParentReceiptSpec(frozenset({"CHILD_ENVELOPE"})),
    "CHECKER_GRANT_ACCEPTED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "CHECKER_CERT_ATTACHED": ParentReceiptSpec(frozenset({"CHILD_ENVELOPE"})),
    "PRIMARY_FAILOVER": ParentReceiptSpec(frozenset({"RECOVERY_GUARDIAN"})),
    "OWNER_FAILURE_OBSERVED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "PARENT_EVIDENCE_SEAL": ParentReceiptSpec(frozenset(CONTROLLERS)),
}


@dataclass(frozen=True)
class ParentReceipt:
    schema: str
    parent_run_id: str
    binding_digest: str
    sequence: int
    kind: str
    payload: str
    payload_digest: str
    issuer: str
    previous_hash: str
    auth_tag: str


def _parent_receipt_body(receipt: ParentReceipt) -> tuple[object, ...]:
    return (
        receipt.schema,
        receipt.parent_run_id,
        receipt.binding_digest,
        receipt.sequence,
        receipt.kind,
        receipt.payload,
        receipt.payload_digest,
        receipt.issuer,
        receipt.previous_hash,
    )


def parent_receipt_hash(receipt: ParentReceipt) -> str:
    return child.digest("PARENT_RECEIPT_HASH", *_parent_receipt_body(receipt), receipt.auth_tag)


def _parent_receipt_auth(receipt: ParentReceipt) -> str:
    return child.digest("ABSTRACT_PARENT_RECEIPT_AUTH", *_parent_receipt_body(receipt))


@dataclass(frozen=True)
class LocalDispositionCapsule:
    schema: str
    parent_run_id: str
    parent_evidence_root: str
    producer_root: str
    checker_root: str
    local_disposition: str
    artifact_type: str
    issuer: str
    capsule_digest: str
    auth_tag: str


def _capsule_body(capsule: LocalDispositionCapsule) -> tuple[object, ...]:
    return (
        capsule.schema,
        capsule.parent_run_id,
        capsule.parent_evidence_root,
        capsule.producer_root,
        capsule.checker_root,
        capsule.local_disposition,
        capsule.artifact_type,
        capsule.issuer,
    )


def _capsule_digest(capsule: LocalDispositionCapsule) -> str:
    return child.digest("LOCAL_DISPOSITION_CAPSULE", *_capsule_body(capsule))


def _capsule_auth(capsule: LocalDispositionCapsule) -> str:
    return child.digest("ABSTRACT_LOCAL_CAPSULE_AUTH", *_capsule_body(capsule), capsule.capsule_digest)


@dataclass(frozen=True)
class SemanticVerdict:
    """A distinct external type; no transition in this module constructs one."""

    external_review_root: str
    verdict: str
    external_issuer: str


@dataclass(frozen=True)
class PublicationCommitment:
    parent_run_id: str
    artifact_type: str
    capsule_digest: str
    expected_generation: int
    commitment_digest: str


def _commitment_digest(commitment: PublicationCommitment) -> str:
    return child.digest(
        "PUBLICATION_COMMITMENT",
        commitment.parent_run_id,
        commitment.artifact_type,
        commitment.capsule_digest,
        commitment.expected_generation,
    )


@dataclass(frozen=True)
class DurableAck:
    commitment_digest: str
    generation: int
    issuer: str
    auth_tag: str


def _durable_ack_auth(ack: DurableAck) -> str:
    return child.digest(
        "DURABLE_ACK",
        ack.commitment_digest,
        ack.generation,
        ack.issuer,
    )


@dataclass(frozen=True)
class PublicationAck:
    commitment_digest: str
    old_generation: int
    new_generation: int
    issuer: str
    auth_tag: str


def _publication_ack_auth(ack: PublicationAck) -> str:
    return child.digest(
        "PUBLICATION_ACK",
        ack.commitment_digest,
        ack.old_generation,
        ack.new_generation,
        ack.issuer,
    )


@dataclass(frozen=True)
class AbandonmentCommitment:
    parent_run_id: str
    binding_digest: str
    reason: str
    parent_evidence_root: str
    local_capsule_digest: str
    prior_publication_commitment_digest: str
    expected_generation: int
    commitment_digest: str


def _abandonment_commitment_digest(
    commitment: AbandonmentCommitment,
) -> str:
    return child.digest(
        "ABANDONMENT_TOMBSTONE_COMMITMENT",
        commitment.parent_run_id,
        commitment.binding_digest,
        commitment.reason,
        commitment.parent_evidence_root,
        commitment.local_capsule_digest,
        commitment.prior_publication_commitment_digest,
        commitment.expected_generation,
    )


@dataclass(frozen=True)
class AbandonmentAck:
    commitment_digest: str
    old_generation: int
    new_generation: int
    outcome: str
    issuer: str
    auth_tag: str


def _abandonment_ack_auth(ack: AbandonmentAck) -> str:
    return child.digest(
        "ABANDONMENT_TOMBSTONE_ACK",
        ack.commitment_digest,
        ack.old_generation,
        ack.new_generation,
        ack.outcome,
        ack.issuer,
    )


@dataclass(frozen=True)
class RecoveryReceipt:
    schema: str
    parent_run_id: str
    binding_digest: str
    sequence: int
    observed_phase: str
    parent_prefix_hash: str
    reason: str
    failed_controller: str
    fence_generation: int
    issuer: str
    auth_tag: str


def _recovery_auth(receipt: RecoveryReceipt) -> str:
    return child.digest(
        "ORCH_RECOVERY_RECEIPT",
        receipt.schema,
        receipt.parent_run_id,
        receipt.binding_digest,
        receipt.sequence,
        receipt.observed_phase,
        receipt.parent_prefix_hash,
        receipt.reason,
        receipt.failed_controller,
        receipt.fence_generation,
        receipt.issuer,
    )


@dataclass(frozen=True)
class OrchestratorState:
    phase: str = "WAIT_GRANT"
    parent_grant: ParentGrant | None = None
    grant_consume_requested: bool = False
    grant_consumed: bool = False
    grant_registry_state: str = "NONE"
    grant_registry_generation: int = 0
    grant_consumption_ack: GrantConsumptionAck | None = None
    owner_state: str = "ACTIVE"
    primary_state: str = "ACTIVE"
    guardian_state: str = "ACTIVE"
    controller: str = "PRIMARY_SUPERVISOR"
    producer_status: str = "NONE"
    producer_grant: child.RunGrant | None = None
    producer_certificate: ChildCertificate | None = None
    checker_status: str = "NONE"
    checker_grant: child.RunGrant | None = None
    checker_certificate: ChildCertificate | None = None
    active_child: str = "NONE"
    parent_ledger: str = "OPEN"
    parent_receipts: tuple[ParentReceipt, ...] = ()
    parent_evidence_root: str = ""
    local_disposition: str = "NONE"
    local_capsule: LocalDispositionCapsule | None = None
    semantic_verdict: SemanticVerdict | None = None
    publication: str = "NONE"
    publication_commitment: PublicationCommitment | None = None
    durable_ack: DurableAck | None = None
    publication_ack: PublicationAck | None = None
    abandonment_commitment: AbandonmentCommitment | None = None
    abandonment_ack: AbandonmentAck | None = None
    store_head_generation: int = 0
    pending_attack: str = "NONE"
    rejected_attack: str = "NONE"
    assurance_breach: str = "NONE"
    recovery_receipts: tuple[RecoveryReceipt, ...] = ()


@dataclass(frozen=True)
class OrchEdge:
    action_id: str
    actor: str
    state: OrchestratorState


@dataclass(frozen=True)
class ActionSpec:
    actors: frozenset[str]
    relation: str


ACTION_SPECS = {
    "EXT-001-DELIVER-PARENT-GRANT": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "ExternalNext"),
    "SUP-002-CONSUME-PARENT-GRANT": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "STORE-002B-COMMIT-GRANT-CONSUMPTION": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-002C-RETIRE-GRANT-NONCE": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "EXT-003-DELIVER-PRODUCER-GRANT": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "ExternalNext"),
    "SUP-004-START-PRODUCER": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "CHILD-005-ATTACH-PRODUCER-CANDIDATE": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-006-ATTACH-PRODUCER-RESOURCE": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-007-ATTACH-PRODUCER-INTERNAL": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-008-ATTACH-PRODUCER-ABANDONED": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "EXT-009-DELIVER-CHECKER-GRANT": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "ExternalNext"),
    "SUP-010-START-CHECKER": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "CHILD-011-ATTACH-CHECKER-ACCEPT": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-012-ATTACH-CHECKER-REJECT": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-013-ATTACH-CHECKER-RESOURCE": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-014-ATTACH-CHECKER-INTERNAL": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "CHILD-015-ATTACH-CHECKER-ABANDONED": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "SUP-016-SEAL-PARENT-EVIDENCE": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "SUP-017-DECIDE-LOCAL-DISPOSITION": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "SUP-018-PREPARE-LOCAL-PUBLICATION": ActionSpec(frozenset(CONTROLLERS), "SupervisorNext"),
    "STORE-019-DURABLE-ACK": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-020-PUBLISH-CAS": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-021-HEAD-CONFLICT": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "EXT-023-OWNER-FAILURE": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "ExternalNext"),
    "GRD-023B-FENCE-AFTER-OWNER-FAILURE": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "CHILD-024-ATTACH-ACTIVE-ABANDONED": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "GRD-025-PREPARE-ABANDONMENT": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "ADV-027-REPLAY-GRANT": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-028-ROLLBACK-PUBLICATION": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "STORE-029-REJECT-HOSTILE-REQUEST": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "ADV-029B-SUCCEED-STORE-BYPASS": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-030-STALL": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-031-FAIL-GUARDIAN": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
}
ACTION_IDS = tuple(ACTION_SPECS)


def initial_state() -> OrchestratorState:
    return OrchestratorState()


def _parent_genesis(grant: ParentGrant) -> str:
    return child.digest("PARENT_EVIDENCE_GENESIS", parent_binding_digest(grant))


def _last_parent_hash(state: OrchestratorState) -> str:
    if state.parent_grant is None:
        raise OrchestratorReject("F05-ORCH-NO-PARENT-GRANT", state.phase)
    if not state.parent_receipts:
        return _parent_genesis(state.parent_grant)
    return parent_receipt_hash(state.parent_receipts[-1])


def _append_parent_receipt(
    state: OrchestratorState,
    issuer: str,
    kind: str,
    payload: str,
) -> OrchestratorState:
    if state.parent_grant is None or state.parent_ledger != "OPEN":
        raise OrchestratorReject("F05-ORCH-PARENT-LEDGER", kind)
    spec = PARENT_RECEIPT_SPECS.get(kind)
    if spec is None or issuer not in spec.issuers:
        raise OrchestratorReject("F05-ORCH-PARENT-ISSUER", f"{kind}:{issuer}")
    receipt = ParentReceipt(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        sequence=len(state.parent_receipts) + 1,
        kind=kind,
        payload=payload,
        payload_digest=child.digest("PARENT_RECEIPT_PAYLOAD", kind, payload),
        issuer=issuer,
        previous_hash=_last_parent_hash(state),
        auth_tag="",
    )
    receipt = replace(receipt, auth_tag=_parent_receipt_auth(receipt))
    return replace(state, parent_receipts=state.parent_receipts + (receipt,))


def _append_recovery(
    state: OrchestratorState,
    reason: str,
) -> OrchestratorState:
    if state.parent_grant is None or reason not in {"PRIMARY_CRASH", "OWNER_FAILURE"}:
        raise OrchestratorReject("F05-ORCH-RECOVERY-PRECONDITION", reason)
    receipt = RecoveryReceipt(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        sequence=len(state.recovery_receipts) + 1,
        observed_phase=state.phase,
        parent_prefix_hash=_last_parent_hash(state),
        reason=reason,
        failed_controller="PRIMARY_SUPERVISOR",
        fence_generation=1,
        issuer="RECOVERY_GUARDIAN",
        auth_tag="",
    )
    receipt = replace(receipt, auth_tag=_recovery_auth(receipt))
    return replace(state, recovery_receipts=state.recovery_receipts + (receipt,))


def _certificate_payload_value(certificate: ChildCertificate) -> str:
    return certificate.certificate_digest


def parent_evidence_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return not state.parent_receipts and state.parent_ledger == "OPEN" and not state.parent_evidence_root
    previous = _parent_genesis(state.parent_grant)
    counts: Counter[str] = Counter()
    for sequence, receipt in enumerate(state.parent_receipts, start=1):
        spec = PARENT_RECEIPT_SPECS.get(receipt.kind)
        if not (
            spec
            and receipt.schema == SCHEMA
            and receipt.parent_run_id == state.parent_grant.parent_run_id
            and receipt.binding_digest == parent_binding_digest(state.parent_grant)
            and receipt.sequence == sequence
            and receipt.payload_digest
            == child.digest("PARENT_RECEIPT_PAYLOAD", receipt.kind, receipt.payload)
            and receipt.issuer in spec.issuers
            and receipt.previous_hash == previous
            and receipt.auth_tag == _parent_receipt_auth(replace(receipt, auth_tag=""))
        ):
            return False
        counts[receipt.kind] += 1
        if counts[receipt.kind] > 1:
            return False
        previous = parent_receipt_hash(receipt)

    expected_payloads: dict[str, str] = {}
    if state.grant_consume_requested:
        expected_payloads["PARENT_GRANT_CONSUME_REQUESTED"] = (
            _grant_consume_request_payload(state.parent_grant)
        )
    if state.grant_consumed:
        if state.grant_consumption_ack is None:
            return False
        expected_payloads["PARENT_GRANT_CONSUMED"] = (
            _grant_consumption_ack_payload(state.grant_consumption_ack)
        )
    if state.grant_registry_state == "RETIRED":
        if state.grant_consumption_ack is None:
            return False
        expected_payloads["PARENT_GRANT_RETIRED"] = (
            _grant_consumption_ack_payload(state.grant_consumption_ack)
        )
    if state.producer_grant:
        expected_payloads["PRODUCER_GRANT_ACCEPTED"] = child.grant_binding_digest(state.producer_grant)
    if state.producer_certificate:
        expected_payloads["PRODUCER_CERT_ATTACHED"] = _certificate_payload_value(state.producer_certificate)
    if state.checker_grant:
        expected_payloads["CHECKER_GRANT_ACCEPTED"] = child.grant_binding_digest(state.checker_grant)
    if state.checker_certificate:
        expected_payloads["CHECKER_CERT_ATTACHED"] = _certificate_payload_value(state.checker_certificate)
    owner_failure_receipts = [
        receipt
        for receipt in state.parent_receipts
        if receipt.kind == "OWNER_FAILURE_OBSERVED"
    ]
    if owner_failure_receipts:
        if (
            len(owner_failure_receipts) != 1
            or state.owner_state != "FAILED"
            or owner_failure_receipts[0].payload != state.parent_grant.parent_run_id
        ):
            return False
    for kind, payload in expected_payloads.items():
        matches = [receipt for receipt in state.parent_receipts if receipt.kind == kind]
        if len(matches) != 1 or matches[0].payload != payload:
            return False
    exact_presence = {
        "PARENT_GRANT_CONSUME_REQUESTED": state.grant_consume_requested,
        "PARENT_GRANT_CONSUMED": state.grant_consumed,
        "PARENT_GRANT_RETIRED": state.grant_registry_state == "RETIRED",
        "PRODUCER_GRANT_ACCEPTED": state.producer_grant is not None,
        "PRODUCER_CERT_ATTACHED": state.producer_certificate is not None,
        "CHECKER_GRANT_ACCEPTED": state.checker_grant is not None,
        "CHECKER_CERT_ATTACHED": state.checker_certificate is not None,
    }
    for kind, expected in exact_presence.items():
        if (counts[kind] == 1) != expected:
            return False

    positions = {
        receipt.kind: index
        for index, receipt in enumerate(state.parent_receipts)
    }

    def ordered(before: str, after: str) -> bool:
        return before in positions and after in positions and positions[before] < positions[after]

    if state.grant_consumed and not ordered(
        "PARENT_GRANT_CONSUME_REQUESTED",
        "PARENT_GRANT_CONSUMED",
    ):
        return False
    if state.grant_registry_state == "RETIRED":
        if "OWNER_FAILURE_OBSERVED" not in positions:
            return False
        if not ordered("OWNER_FAILURE_OBSERVED", "PARENT_GRANT_RETIRED"):
            return False
        if state.grant_consume_requested and not ordered(
            "PARENT_GRANT_CONSUME_REQUESTED",
            "PARENT_GRANT_RETIRED",
        ):
            return False
    causal_pairs = (
        ("PARENT_GRANT_CONSUMED", "PRODUCER_GRANT_ACCEPTED"),
        ("PRODUCER_GRANT_ACCEPTED", "PRODUCER_CERT_ATTACHED"),
        ("PRODUCER_CERT_ATTACHED", "CHECKER_GRANT_ACCEPTED"),
        ("CHECKER_GRANT_ACCEPTED", "CHECKER_CERT_ATTACHED"),
    )
    for before, after in causal_pairs:
        if after in positions and not ordered(before, after):
            return False
    primary_receipts = [
        receipt for receipt in state.parent_receipts if receipt.kind == "PRIMARY_FAILOVER"
    ]
    if primary_receipts:
        if (
            len(primary_receipts) != 1
            or state.primary_state != "FAILED"
            or primary_receipts[0].payload not in PHASES
        ):
            return False
    if state.primary_state == "ACTIVE" and primary_receipts:
        return False
    if (
        state.primary_state == "FAILED"
        and state.parent_ledger == "OPEN"
        and len(primary_receipts) != 1
    ):
        return False

    seal_count = counts["PARENT_EVIDENCE_SEAL"]
    if state.parent_ledger == "OPEN":
        return seal_count == 0 and not state.parent_evidence_root
    return (
        state.parent_ledger == "SEALED"
        and seal_count == 1
        and state.parent_receipts[-1].kind == "PARENT_EVIDENCE_SEAL"
        and state.parent_receipts[-1].payload == state.parent_receipts[-1].previous_hash
        and state.parent_evidence_root == previous
    )


def grant_registry_wf(state: OrchestratorState) -> bool:
    grant = state.parent_grant
    if state.grant_registry_state not in GRANT_REGISTRY_STATES:
        return False
    if grant is None:
        return (
            state.grant_registry_state == "NONE"
            and state.grant_registry_generation == 0
            and not state.grant_consume_requested
            and not state.grant_consumed
            and state.grant_consumption_ack is None
        )
    if state.grant_registry_state == "NONE":
        return False

    ack = state.grant_consumption_ack
    issuance_generation = grant.issuance_generation
    if state.grant_registry_state == "ISSUED":
        return (
            state.grant_registry_generation == issuance_generation
            and not state.grant_consume_requested
            and not state.grant_consumed
            and ack is None
            and state.phase in {
                "GRANT_AVAILABLE",
                "ABANDONING",
                "ASSURANCE_BREACHED",
            }
        )
    if state.grant_registry_state == "PENDING":
        return (
            state.grant_registry_generation == issuance_generation
            and state.grant_consume_requested
            and not state.grant_consumed
            and ack is None
            and state.phase in {
                "GRANT_CONSUME_PENDING",
                "ABANDONING",
                "ASSURANCE_BREACHED",
            }
        )
    if ack is None or not grant_consumption_ack_wf(ack, grant):
        return False
    if state.grant_registry_generation != ack.new_generation:
        return False
    if state.grant_registry_state == "CONSUMED":
        return (
            state.grant_consume_requested
            and state.grant_consumed
            and ack.outcome == "CONSUMED"
            and state.phase not in {
                "WAIT_GRANT",
                "GRANT_AVAILABLE",
                "GRANT_CONSUME_PENDING",
            }
        )
    return (
        state.grant_registry_state == "RETIRED"
        and not state.grant_consumed
        and ack.outcome == "RETIRED"
        and state.owner_state == "FAILED"
        and state.publication in {
            "ABANDONING",
            "ABANDONED",
            "ASSURANCE_BREACHED",
        }
        and state.phase in {"ABANDONING", "TERMINAL", "ASSURANCE_BREACHED"}
    )


def _expected_local_disposition(state: OrchestratorState) -> str:
    producer = state.producer_certificate
    checker = state.checker_certificate
    if any(
        receipt.kind == "OWNER_FAILURE_OBSERVED"
        for receipt in state.parent_receipts
    ):
        return "ABANDONED"
    if producer is None:
        return "INTERNAL_FAILURE"
    if producer.local_decision == "ABANDONED":
        return "ABANDONED"
    if producer.local_decision == "INTERNAL_FAILURE":
        return "INTERNAL_FAILURE"
    if producer.local_decision == "INCONCLUSIVE_RESOURCE":
        return "INCONCLUSIVE_RESOURCE"
    if producer.local_decision != "LOCAL_SYNTACTIC_CANDIDATE" or checker is None:
        return "INTERNAL_FAILURE"
    if checker.local_decision == "ABANDONED":
        return "ABANDONED"
    if checker.local_decision == "INTERNAL_FAILURE":
        return "INTERNAL_FAILURE"
    if checker.local_decision == "INCONCLUSIVE_RESOURCE":
        return "INCONCLUSIVE_RESOURCE"
    if checker.local_decision != "LOCAL_SYNTACTIC_CANDIDATE":
        return "INTERNAL_FAILURE"
    if checker.payload_kind == "CHECKER_ACCEPT":
        return "LOCAL_CHECKED_CANDIDATE"
    if checker.payload_kind == "CHECKER_REJECT":
        return "LOCAL_REJECTED_CANDIDATE"
    return "INTERNAL_FAILURE"


def capsule_wf(state: OrchestratorState) -> bool:
    capsule = state.local_capsule
    if state.local_disposition == "NONE":
        return capsule is None
    if capsule is None or state.parent_grant is None:
        return False
    producer_root = state.producer_certificate.evidence_root if state.producer_certificate else ""
    checker_root = state.checker_certificate.evidence_root if state.checker_certificate else ""
    return (
        capsule.schema == SCHEMA
        and capsule.parent_run_id == state.parent_grant.parent_run_id
        and capsule.parent_evidence_root == state.parent_evidence_root
        and capsule.producer_root == producer_root
        and capsule.checker_root == checker_root
        and capsule.local_disposition == state.local_disposition
        and capsule.artifact_type == "LOCAL_DISPOSITION_CAPSULE"
        and capsule.issuer in CONTROLLERS
        and capsule.capsule_digest == _capsule_digest(replace(capsule, capsule_digest="", auth_tag=""))
        and capsule.auth_tag == _capsule_auth(replace(capsule, auth_tag=""))
    )


def publication_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return (
            state.publication == "NONE"
            and state.publication_commitment is None
            and state.durable_ack is None
            and state.publication_ack is None
            and state.abandonment_commitment is None
            and state.abandonment_ack is None
            and state.store_head_generation == 0
        )

    grant = state.parent_grant
    expected_generation = grant.expected_publication_generation
    commitment = state.publication_commitment
    if commitment is not None:
        if state.local_capsule is None:
            return False
        if not (
            commitment.parent_run_id == grant.parent_run_id
            and commitment.artifact_type == "LOCAL_DISPOSITION_CAPSULE"
            and commitment.capsule_digest == state.local_capsule.capsule_digest
            and commitment.expected_generation == expected_generation
            and commitment.commitment_digest
            == _commitment_digest(replace(commitment, commitment_digest=""))
        ):
            return False
    if state.durable_ack is not None:
        ack = state.durable_ack
        if not (
            commitment is not None
            and ack.commitment_digest == commitment.commitment_digest
            and ack.generation == commitment.expected_generation
            and ack.issuer == "DURABLE_STORE"
            and ack.auth_tag == _durable_ack_auth(replace(ack, auth_tag=""))
        ):
            return False
    if state.publication_ack is not None:
        ack = state.publication_ack
        if not (
            commitment is not None
            and ack.commitment_digest == commitment.commitment_digest
            and ack.old_generation == commitment.expected_generation
            and ack.new_generation == commitment.expected_generation + 1
            and ack.issuer == "DURABLE_STORE"
            and ack.auth_tag == _publication_ack_auth(replace(ack, auth_tag=""))
        ):
            return False

    tombstone = state.abandonment_commitment
    if tombstone is not None:
        if state.local_capsule is None or not state.parent_evidence_root:
            return False
        prior_digest = commitment.commitment_digest if commitment else ""
        if not (
            tombstone.parent_run_id == grant.parent_run_id
            and tombstone.binding_digest == parent_binding_digest(grant)
            and tombstone.reason == "OWNER_FAILURE"
            and tombstone.parent_evidence_root == state.parent_evidence_root
            and tombstone.local_capsule_digest == state.local_capsule.capsule_digest
            and tombstone.prior_publication_commitment_digest == prior_digest
            and tombstone.expected_generation == expected_generation
            and tombstone.commitment_digest
            == _abandonment_commitment_digest(
                replace(tombstone, commitment_digest="")
            )
        ):
            return False
    if state.abandonment_ack is not None:
        ack = state.abandonment_ack
        if not (
            tombstone is not None
            and ack.commitment_digest == tombstone.commitment_digest
            and ack.old_generation == tombstone.expected_generation
            and ack.new_generation == ack.old_generation + 1
            and ack.outcome == "ABANDONED"
            and ack.issuer == "DURABLE_STORE"
            and ack.auth_tag == _abandonment_ack_auth(replace(ack, auth_tag=""))
        ):
            return False

    if state.publication == "ASSURANCE_BREACHED":
        return (
            state.phase == "ASSURANCE_BREACHED"
            and state.assurance_breach != "NONE"
            and state.publication_ack is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation
        )

    if state.publication == "NONE":
        return (
            commitment is None
            and state.durable_ack is None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation
        )
    if state.publication == "PREPARED":
        return (
            state.phase == "PREPARED"
            and commitment is not None
            and state.durable_ack is None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation
        )
    if state.publication == "DURABLE":
        return (
            state.phase == "DURABLE"
            and commitment is not None
            and state.durable_ack is not None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation
        )
    if state.publication == "PUBLISHED":
        return (
            state.phase == "TERMINAL"
            and commitment is not None
            and state.durable_ack is not None
            and state.publication_ack is not None
            and tombstone is None
            and state.abandonment_ack is None
            and state.store_head_generation == state.publication_ack.new_generation
        )
    if state.publication == "STALE_REJECTED":
        return (
            state.phase == "TERMINAL"
            and commitment is not None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation + 1
        )
    if state.publication == "ABANDONING":
        return (
            state.phase == "ABANDONING"
            and state.publication_ack is None
            and state.abandonment_ack is None
            and state.store_head_generation == expected_generation
        )
    return (
        state.publication == "ABANDONED"
        and state.phase == "TERMINAL"
        and state.publication_ack is None
        and tombstone is not None
        and state.abandonment_ack is not None
        and state.store_head_generation == state.abandonment_ack.new_generation
    )


def recovery_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return not state.recovery_receipts and state.primary_state == "ACTIVE"
    if len(state.recovery_receipts) > 1:
        return False
    for sequence, receipt in enumerate(state.recovery_receipts, start=1):
        if not (
            receipt.schema == SCHEMA
            and receipt.parent_run_id == state.parent_grant.parent_run_id
            and receipt.binding_digest == parent_binding_digest(state.parent_grant)
            and receipt.sequence == sequence
            and receipt.observed_phase in PHASES
            and bool(receipt.parent_prefix_hash)
            and receipt.reason in {"PRIMARY_CRASH", "OWNER_FAILURE"}
            and receipt.failed_controller == "PRIMARY_SUPERVISOR"
            and receipt.fence_generation == sequence
            and receipt.issuer == "RECOVERY_GUARDIAN"
            and receipt.auth_tag == _recovery_auth(replace(receipt, auth_tag=""))
        ):
            return False
    if (len(state.recovery_receipts) == 1) != (state.primary_state == "FAILED"):
        return False
    if not state.recovery_receipts:
        return True

    receipt = state.recovery_receipts[0]
    if receipt.reason == "OWNER_FAILURE" and state.owner_state != "FAILED":
        return False
    failovers = [
        item for item in state.parent_receipts if item.kind == "PRIMARY_FAILOVER"
    ]
    if failovers:
        return (
            len(failovers) == 1
            and receipt.parent_prefix_hash == failovers[0].previous_hash
            and failovers[0].payload == receipt.observed_phase
        )
    return (
        state.parent_ledger == "SEALED"
        and receipt.parent_prefix_hash == state.parent_evidence_root
        and receipt.observed_phase in {
            "PARENT_SEALED",
            "LOCAL_DECIDED",
            "PREPARED",
            "DURABLE",
            "ABANDONING",
        }
    )


@lru_cache(maxsize=None)
def orchestrator_wf(state: OrchestratorState) -> bool:
    if not (
        state.phase in PHASES
        and state.owner_state in OWNER_STATES
        and state.primary_state in PRIMARY_STATES
        and state.guardian_state in GUARDIAN_STATES
        and state.controller in CONTROLLERS
        and state.producer_status in CHILD_STATUSES
        and state.checker_status in CHILD_STATUSES
        and state.active_child in {"NONE", "PRODUCER", "CHECKER"}
        and state.parent_ledger in PARENT_LEDGERS
        and state.local_disposition in LOCAL_DISPOSITIONS
        and state.publication in PUBLICATIONS
        and state.pending_attack in PENDING_ATTACKS
        and state.rejected_attack in PENDING_ATTACKS
        and state.assurance_breach in ASSURANCE_BREACHES
        and state.grant_registry_state in GRANT_REGISTRY_STATES
        and state.grant_registry_generation >= 0
        and state.store_head_generation >= 0
        and state.semantic_verdict is None
        and grant_registry_wf(state)
        and parent_evidence_wf(state)
        and capsule_wf(state)
        and publication_wf(state)
        and recovery_wf(state)
    ):
        return False
    if state.parent_grant is not None and not parent_grant_wf(state.parent_grant):
        return False
    if state.parent_grant is None:
        if (
            state.phase != "WAIT_GRANT"
            or state.grant_consume_requested
            or state.grant_consumed
        ):
            return False
    if state.grant_consumed and state.parent_grant is None:
        return False
    if state.primary_state == "ACTIVE" and state.controller != "PRIMARY_SUPERVISOR":
        return False
    if state.primary_state == "FAILED" and state.controller != "RECOVERY_GUARDIAN":
        return False
    if state.owner_state == "FAILED" and state.publication not in {
        "ABANDONING",
        "ABANDONED",
        "ASSURANCE_BREACHED",
    }:
        return False
    if state.pending_attack != "NONE" and state.rejected_attack != "NONE":
        return False
    if (state.phase == "ASSURANCE_BREACHED") != (
        state.publication == "ASSURANCE_BREACHED"
        and state.assurance_breach != "NONE"
    ):
        return False
    if state.assurance_breach == "GUARDIAN_FAILURE":
        if state.guardian_state != "FAILED" or state.primary_state != "FAILED":
            return False
    elif state.guardian_state != "ACTIVE":
        return False
    if state.assurance_breach in {
        "GRANT_REGISTRY_BYPASS",
        "PUBLICATION_ROLLBACK",
    } and state.guardian_state != "ACTIVE":
        return False

    if state.parent_grant and state.producer_grant:
        if not child_grant_matches_parent(
            state.producer_grant,
            state.parent_grant,
            "PRODUCER",
            state.parent_grant.immutable_input_digest,
        ):
            return False
    if state.producer_certificate:
        if not (
            state.parent_grant
            and child_certificate_wf(
                state.producer_certificate,
                state.parent_grant,
                "PRODUCER",
                state.parent_grant.immutable_input_digest,
            )
            and state.producer_grant == state.producer_certificate.grant
        ):
            return False
    if state.checker_grant:
        if not (
            state.parent_grant
            and state.producer_certificate
            and child_grant_matches_parent(
                state.checker_grant,
                state.parent_grant,
                "CHECKER",
                expected_checker_input(state.producer_certificate),
            )
            and state.producer_grant
            and state.checker_grant.child_run_id != state.producer_grant.child_run_id
        ):
            return False
    if state.checker_certificate:
        if not (
            state.parent_grant
            and state.producer_certificate
            and child_certificate_wf(
                state.checker_certificate,
                state.parent_grant,
                "CHECKER",
                expected_checker_input(state.producer_certificate),
            )
            and state.checker_grant == state.checker_certificate.grant
        ):
            return False

    if state.producer_status == "NONE" and (state.producer_grant or state.producer_certificate):
        return False
    if state.producer_status == "GRANT_AVAILABLE" and not state.producer_grant:
        return False
    if state.producer_status == "RUNNING" and state.active_child != "PRODUCER":
        return False
    if state.producer_status == "ATTACHED" and not state.producer_certificate:
        return False
    if state.checker_status == "GRANT_AVAILABLE" and not state.checker_grant:
        return False
    if state.checker_status == "RUNNING" and state.active_child != "CHECKER":
        return False
    if state.checker_status == "ATTACHED" and not state.checker_certificate:
        return False
    if state.active_child == "NONE" and (
        state.producer_status == "RUNNING" or state.checker_status == "RUNNING"
    ):
        return False

    if state.parent_ledger == "SEALED" and state.phase not in {
        "PARENT_SEALED",
        "LOCAL_DECIDED",
        "PREPARED",
        "DURABLE",
        "ABANDONING",
        "TERMINAL",
        "ASSURANCE_BREACHED",
    }:
        return False
    if state.local_disposition != "NONE":
        if state.parent_ledger != "SEALED" or state.local_disposition != _expected_local_disposition(state):
            return False
    if state.phase == "TERMINAL" and state.publication not in TERMINAL_PUBLICATIONS:
        return False
    if (
        state.publication in TERMINAL_PUBLICATIONS - {"ASSURANCE_BREACHED"}
        and state.phase != "TERMINAL"
    ):
        return False
    return True


def semantic_projection(state: OrchestratorState) -> tuple[object, ...]:
    # Exact identity is deliberate: evidence and recovery histories affect future
    # roots and therefore cannot be quotient-elided without a congruence proof.
    return (state,)


def _edge(action_id: str, actor: str, before: OrchestratorState, after: OrchestratorState) -> OrchEdge:
    spec = ACTION_SPECS.get(action_id)
    if spec is None or actor not in spec.actors:
        raise OrchestratorReject("F05-ORCH-ACTION-ACTOR", f"{action_id}:{actor}")
    if before.parent_grant != after.parent_grant and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-PARENT-GRANT-WRITE", action_id)
    before_receipts = before.parent_receipts
    after_receipts = after.parent_receipts
    if after_receipts[: len(before_receipts)] != before_receipts:
        raise OrchestratorReject("F05-ORCH-EVIDENCE-NONAPPEND", action_id)
    if any(receipt.issuer != actor for receipt in after_receipts[len(before_receipts) :]):
        raise OrchestratorReject("F05-ORCH-EVIDENCE-ACTOR-MISMATCH", action_id)
    if before.owner_state != after.owner_state and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-OWNER-WRITE", action_id)
    if before.producer_grant != after.producer_grant and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-PRODUCER-GRANT-WRITE", action_id)
    if before.checker_grant != after.checker_grant and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-CHECKER-GRANT-WRITE", action_id)
    if before.producer_certificate != after.producer_certificate and actor != "CHILD_ENVELOPE":
        raise OrchestratorReject("F05-ORCH-PRODUCER-CERT-WRITE", action_id)
    if before.checker_certificate != after.checker_certificate and actor != "CHILD_ENVELOPE":
        raise OrchestratorReject("F05-ORCH-CHECKER-CERT-WRITE", action_id)
    if (
        before.grant_consume_requested != after.grant_consume_requested
        and actor not in CONTROLLERS
    ):
        raise OrchestratorReject("F05-ORCH-GRANT-REQUEST-WRITE", action_id)
    if before.grant_consumed != after.grant_consumed and actor != "DURABLE_STORE":
        raise OrchestratorReject("F05-ORCH-GRANT-CONSUMED-WRITE", action_id)
    if (
        before.grant_consumption_ack != after.grant_consumption_ack
        and actor != "DURABLE_STORE"
    ):
        raise OrchestratorReject("F05-ORCH-GRANT-ACK-WRITE", action_id)
    registry_transition = (
        before.grant_registry_state,
        after.grant_registry_state,
        actor,
    )
    allowed_registry_transitions = {
        ("NONE", "ISSUED", "EXTERNAL_OWNER"),
        ("ISSUED", "PENDING", "PRIMARY_SUPERVISOR"),
        ("ISSUED", "PENDING", "RECOVERY_GUARDIAN"),
        ("PENDING", "CONSUMED", "DURABLE_STORE"),
        ("ISSUED", "RETIRED", "DURABLE_STORE"),
        ("PENDING", "RETIRED", "DURABLE_STORE"),
    }
    if (
        before.grant_registry_state != after.grant_registry_state
        and registry_transition not in allowed_registry_transitions
    ):
        raise OrchestratorReject("F05-ORCH-GRANT-REGISTRY-WRITE", action_id)
    if (
        before.grant_registry_generation != after.grant_registry_generation
        and actor not in {"EXTERNAL_OWNER", "DURABLE_STORE"}
    ):
        raise OrchestratorReject("F05-ORCH-GRANT-GENERATION-WRITE", action_id)
    if before.durable_ack != after.durable_ack and actor != "DURABLE_STORE":
        raise OrchestratorReject("F05-ORCH-DURABLE-WRITE", action_id)
    if before.publication_ack != after.publication_ack and actor != "DURABLE_STORE":
        raise OrchestratorReject("F05-ORCH-PUBLISH-WRITE", action_id)
    if (
        before.abandonment_commitment != after.abandonment_commitment
        and actor != "RECOVERY_GUARDIAN"
    ):
        raise OrchestratorReject("F05-ORCH-ABANDONMENT-COMMIT-WRITE", action_id)
    if before.abandonment_ack != after.abandonment_ack and actor != "DURABLE_STORE":
        raise OrchestratorReject("F05-ORCH-ABANDONMENT-ACK-WRITE", action_id)
    if (
        before.store_head_generation != after.store_head_generation
        and actor not in {"EXTERNAL_OWNER", "DURABLE_STORE"}
    ):
        raise OrchestratorReject("F05-ORCH-STORE-HEAD-WRITE", action_id)
    if before.semantic_verdict != after.semantic_verdict:
        raise OrchestratorReject("F05-ORCH-SEMANTIC-VERDICT-WRITE", action_id)
    if before.recovery_receipts != after.recovery_receipts and actor != "RECOVERY_GUARDIAN":
        raise OrchestratorReject("F05-ORCH-RECOVERY-RECEIPT-WRITE", action_id)
    if before.primary_state != after.primary_state and actor != "RECOVERY_GUARDIAN":
        raise OrchestratorReject("F05-ORCH-PRIMARY-FENCE-WRITE", action_id)
    if before.controller != after.controller and actor != "RECOVERY_GUARDIAN":
        raise OrchestratorReject("F05-ORCH-CONTROLLER-WRITE", action_id)
    if before.guardian_state != after.guardian_state:
        if actor != "ADVERSARY" or after.guardian_state != "FAILED":
            raise OrchestratorReject("F05-ORCH-GUARDIAN-STATE-WRITE", action_id)
    if before.assurance_breach != after.assurance_breach and actor != "ADVERSARY":
        raise OrchestratorReject("F05-ORCH-ASSURANCE-BREACH-WRITE", action_id)
    if not orchestrator_wf(after):
        raise OrchestratorReject("F05-ORCH-EFFECT-WF", action_id)
    return OrchEdge(action_id, actor, after)


def _controller(state: OrchestratorState) -> str:
    return state.controller


def external_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.publication in TERMINAL_PUBLICATIONS or state.pending_attack != "NONE":
        return ()
    edges: list[OrchEdge] = []
    actor = "EXTERNAL_OWNER"
    if state.phase == "WAIT_GRANT" and state.parent_grant is None:
        grant = fixture_parent_grant()
        updated = replace(
            state,
            phase="GRANT_AVAILABLE",
            parent_grant=grant,
            grant_registry_state="ISSUED",
            grant_registry_generation=grant.issuance_generation,
            store_head_generation=grant.expected_publication_generation,
        )
        edges.append(_edge("EXT-001-DELIVER-PARENT-GRANT", actor, state, updated))
    elif state.phase == "PARENT_ACTIVE" and state.producer_status == "NONE":
        assert state.parent_grant is not None
        grant = fixture_child_grant(
            state.parent_grant,
            "PRODUCER",
            state.parent_grant.immutable_input_digest,
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "PRODUCER_GRANT_ACCEPTED",
            child.grant_binding_digest(grant),
        )
        updated = replace(
            updated,
            phase="PRODUCER_GRANT_AVAILABLE",
            producer_status="GRANT_AVAILABLE",
            producer_grant=grant,
        )
        edges.append(_edge("EXT-003-DELIVER-PRODUCER-GRANT", actor, state, updated))
    elif state.phase == "PRODUCER_ATTACHED" and state.checker_status == "NONE":
        assert state.parent_grant is not None and state.producer_certificate is not None
        grant = fixture_child_grant(
            state.parent_grant,
            "CHECKER",
            expected_checker_input(state.producer_certificate),
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "CHECKER_GRANT_ACCEPTED",
            child.grant_binding_digest(grant),
        )
        updated = replace(
            updated,
            phase="CHECKER_GRANT_AVAILABLE",
            checker_status="GRANT_AVAILABLE",
            checker_grant=grant,
        )
        edges.append(_edge("EXT-009-DELIVER-CHECKER-GRANT", actor, state, updated))

    if state.owner_state == "ACTIVE" and state.phase != "WAIT_GRANT":
        updated = state
        if state.parent_grant and state.parent_ledger == "OPEN":
            updated = _append_parent_receipt(
                updated,
                actor,
                "OWNER_FAILURE_OBSERVED",
                state.parent_grant.parent_run_id,
            )
        updated = replace(
            updated,
            phase="ABANDONING",
            owner_state="FAILED",
            publication="ABANDONING",
        )
        edges.append(_edge("EXT-023-OWNER-FAILURE", actor, state, updated))
    return tuple(edges)


def supervisor_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.owner_state != "ACTIVE" or state.publication in TERMINAL_PUBLICATIONS:
        return ()
    actor = _controller(state)
    edges: list[OrchEdge] = []
    if (
        state.phase == "GRANT_AVAILABLE"
        and state.grant_registry_state == "ISSUED"
        and not state.grant_consume_requested
    ):
        assert state.parent_grant is not None
        updated = _append_parent_receipt(
            state,
            actor,
            "PARENT_GRANT_CONSUME_REQUESTED",
            _grant_consume_request_payload(state.parent_grant),
        )
        updated = replace(
            updated,
            phase="GRANT_CONSUME_PENDING",
            grant_consume_requested=True,
            grant_registry_state="PENDING",
        )
        edges.append(_edge("SUP-002-CONSUME-PARENT-GRANT", actor, state, updated))
    elif state.phase == "PRODUCER_GRANT_AVAILABLE":
        updated = replace(
            state,
            phase="PRODUCER_RUNNING",
            producer_status="RUNNING",
            active_child="PRODUCER",
        )
        edges.append(_edge("SUP-004-START-PRODUCER", actor, state, updated))
    elif state.phase == "CHECKER_GRANT_AVAILABLE":
        updated = replace(
            state,
            phase="CHECKER_RUNNING",
            checker_status="RUNNING",
            active_child="CHECKER",
        )
        edges.append(_edge("SUP-010-START-CHECKER", actor, state, updated))
    elif state.phase == "CHILDREN_COMPLETE" and state.parent_ledger == "OPEN":
        prefix_root = _last_parent_hash(state)
        updated = _append_parent_receipt(
            state,
            actor,
            "PARENT_EVIDENCE_SEAL",
            prefix_root,
        )
        updated = replace(
            updated,
            phase="PARENT_SEALED",
            parent_ledger="SEALED",
            parent_evidence_root=_last_parent_hash(updated),
        )
        edges.append(_edge("SUP-016-SEAL-PARENT-EVIDENCE", actor, state, updated))
    elif state.phase == "PARENT_SEALED":
        disposition = _expected_local_disposition(state)
        producer_root = state.producer_certificate.evidence_root if state.producer_certificate else ""
        checker_root = state.checker_certificate.evidence_root if state.checker_certificate else ""
        capsule = LocalDispositionCapsule(
            schema=SCHEMA,
            parent_run_id=state.parent_grant.parent_run_id,
            parent_evidence_root=state.parent_evidence_root,
            producer_root=producer_root,
            checker_root=checker_root,
            local_disposition=disposition,
            artifact_type="LOCAL_DISPOSITION_CAPSULE",
            issuer=actor,
            capsule_digest="",
            auth_tag="",
        )
        capsule = replace(capsule, capsule_digest=_capsule_digest(capsule))
        capsule = replace(capsule, auth_tag=_capsule_auth(capsule))
        updated = replace(
            state,
            phase="LOCAL_DECIDED",
            local_disposition=disposition,
            local_capsule=capsule,
        )
        edges.append(_edge("SUP-017-DECIDE-LOCAL-DISPOSITION", actor, state, updated))
    elif state.phase == "LOCAL_DECIDED":
        assert state.local_capsule is not None and state.parent_grant is not None
        commitment = PublicationCommitment(
            parent_run_id=state.parent_grant.parent_run_id,
            artifact_type="LOCAL_DISPOSITION_CAPSULE",
            capsule_digest=state.local_capsule.capsule_digest,
            expected_generation=state.parent_grant.expected_publication_generation,
            commitment_digest="",
        )
        commitment = replace(commitment, commitment_digest=_commitment_digest(commitment))
        updated = replace(
            state,
            phase="PREPARED",
            publication="PREPARED",
            publication_commitment=commitment,
        )
        edges.append(_edge("SUP-018-PREPARE-LOCAL-PUBLICATION", actor, state, updated))
    return tuple(edges)


def _producer_certificates(state: OrchestratorState) -> tuple[tuple[str, ChildCertificate], ...]:
    assert state.producer_grant is not None
    return (
        ("CHILD-005-ATTACH-PRODUCER-CANDIDATE", fixture_child_certificate(state.producer_grant, "CANDIDATE")),
        ("CHILD-006-ATTACH-PRODUCER-RESOURCE", fixture_child_certificate(state.producer_grant, "RESOURCE")),
        ("CHILD-007-ATTACH-PRODUCER-INTERNAL", fixture_child_certificate(state.producer_grant, "INTERNAL")),
        ("CHILD-008-ATTACH-PRODUCER-ABANDONED", fixture_child_certificate(state.producer_grant, "ABANDONED")),
    )


def _checker_certificates(state: OrchestratorState) -> tuple[tuple[str, ChildCertificate], ...]:
    assert state.checker_grant is not None
    return (
        ("CHILD-011-ATTACH-CHECKER-ACCEPT", fixture_child_certificate(state.checker_grant, "CANDIDATE")),
        ("CHILD-012-ATTACH-CHECKER-REJECT", fixture_child_certificate(state.checker_grant, "CHECKER_REJECT")),
        ("CHILD-013-ATTACH-CHECKER-RESOURCE", fixture_child_certificate(state.checker_grant, "RESOURCE")),
        ("CHILD-014-ATTACH-CHECKER-INTERNAL", fixture_child_certificate(state.checker_grant, "INTERNAL")),
        ("CHILD-015-ATTACH-CHECKER-ABANDONED", fixture_child_certificate(state.checker_grant, "ABANDONED")),
    )


def child_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    actor = "CHILD_ENVELOPE"
    edges: list[OrchEdge] = []
    if (
        state.publication == "ABANDONING"
        and state.primary_state == "FAILED"
        and state.controller == "RECOVERY_GUARDIAN"
        and state.active_child != "NONE"
    ):
        if state.active_child == "PRODUCER":
            assert state.producer_grant is not None
            certificate = fixture_child_certificate(state.producer_grant, "ABANDONED")
            updated = _append_parent_receipt(
                state,
                actor,
                "PRODUCER_CERT_ATTACHED",
                certificate.certificate_digest,
            )
            updated = replace(
                updated,
                producer_status="ATTACHED",
                producer_certificate=certificate,
                active_child="NONE",
            )
        else:
            assert state.checker_grant is not None
            certificate = fixture_child_certificate(state.checker_grant, "ABANDONED")
            updated = _append_parent_receipt(
                state,
                actor,
                "CHECKER_CERT_ATTACHED",
                certificate.certificate_digest,
            )
            updated = replace(
                updated,
                checker_status="ATTACHED",
                checker_certificate=certificate,
                active_child="NONE",
            )
        edges.append(_edge("CHILD-024-ATTACH-ACTIVE-ABANDONED", actor, state, updated))
        return tuple(edges)

    if state.phase == "PRODUCER_RUNNING":
        for action_id, certificate in _producer_certificates(state):
            updated = _append_parent_receipt(
                state,
                actor,
                "PRODUCER_CERT_ATTACHED",
                certificate.certificate_digest,
            )
            needs_checker = certificate.local_decision == "LOCAL_SYNTACTIC_CANDIDATE"
            updated = replace(
                updated,
                phase="PRODUCER_ATTACHED" if needs_checker else "CHILDREN_COMPLETE",
                producer_status="ATTACHED",
                producer_certificate=certificate,
                checker_status="NONE" if needs_checker else "SKIPPED",
                active_child="NONE",
            )
            edges.append(_edge(action_id, actor, state, updated))
    elif state.phase == "CHECKER_RUNNING":
        for action_id, certificate in _checker_certificates(state):
            updated = _append_parent_receipt(
                state,
                actor,
                "CHECKER_CERT_ATTACHED",
                certificate.certificate_digest,
            )
            updated = replace(
                updated,
                phase="CHILDREN_COMPLETE",
                checker_status="ATTACHED",
                checker_certificate=certificate,
                active_child="NONE",
            )
            edges.append(_edge(action_id, actor, state, updated))
    return tuple(edges)


def guardian_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.publication in TERMINAL_PUBLICATIONS or state.guardian_state != "ACTIVE":
        return ()
    edges: list[OrchEdge] = []
    actor = "RECOVERY_GUARDIAN"
    if state.parent_grant is not None and state.primary_state == "ACTIVE":
        reason = "OWNER_FAILURE" if state.owner_state == "FAILED" else "PRIMARY_CRASH"
        updated = _append_recovery(state, reason)
        if state.parent_ledger == "OPEN":
            updated = _append_parent_receipt(
                updated,
                actor,
                "PRIMARY_FAILOVER",
                state.phase,
            )
        updated = replace(
            updated,
            primary_state="FAILED",
            controller="RECOVERY_GUARDIAN",
        )
        action_id = (
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE"
            if reason == "OWNER_FAILURE"
            else "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH"
        )
        edges.append(_edge(action_id, actor, state, updated))

    if (
        state.publication == "ABANDONING"
        and state.primary_state == "FAILED"
        and state.controller == "RECOVERY_GUARDIAN"
        and state.active_child == "NONE"
        and (
            state.parent_grant is None
            or state.grant_registry_state in {"CONSUMED", "RETIRED"}
        )
        and state.abandonment_commitment is None
    ):
        updated = state
        if state.parent_grant and state.parent_ledger == "OPEN":
            prefix_root = _last_parent_hash(updated)
            updated = _append_parent_receipt(
                updated,
                actor,
                "PARENT_EVIDENCE_SEAL",
                prefix_root,
            )
            updated = replace(
                updated,
                parent_ledger="SEALED",
                parent_evidence_root=_last_parent_hash(updated),
            )
        if updated.parent_grant and updated.local_capsule is None:
            producer_root = updated.producer_certificate.evidence_root if updated.producer_certificate else ""
            checker_root = updated.checker_certificate.evidence_root if updated.checker_certificate else ""
            disposition = _expected_local_disposition(updated)
            capsule = LocalDispositionCapsule(
                schema=SCHEMA,
                parent_run_id=updated.parent_grant.parent_run_id,
                parent_evidence_root=updated.parent_evidence_root,
                producer_root=producer_root,
                checker_root=checker_root,
                local_disposition=disposition,
                artifact_type="LOCAL_DISPOSITION_CAPSULE",
                issuer=actor,
                capsule_digest="",
                auth_tag="",
            )
            capsule = replace(capsule, capsule_digest=_capsule_digest(capsule))
            capsule = replace(capsule, auth_tag=_capsule_auth(capsule))
            updated = replace(
                updated,
                local_disposition=disposition,
                local_capsule=capsule,
            )
        assert updated.parent_grant is not None
        assert updated.local_capsule is not None
        prior_digest = (
            updated.publication_commitment.commitment_digest
            if updated.publication_commitment
            else ""
        )
        tombstone = AbandonmentCommitment(
            parent_run_id=updated.parent_grant.parent_run_id,
            binding_digest=parent_binding_digest(updated.parent_grant),
            reason="OWNER_FAILURE",
            parent_evidence_root=updated.parent_evidence_root,
            local_capsule_digest=updated.local_capsule.capsule_digest,
            prior_publication_commitment_digest=prior_digest,
            expected_generation=updated.parent_grant.expected_publication_generation,
            commitment_digest="",
        )
        tombstone = replace(
            tombstone,
            commitment_digest=_abandonment_commitment_digest(tombstone),
        )
        updated = replace(updated, abandonment_commitment=tombstone)
        edges.append(_edge("GRD-025-PREPARE-ABANDONMENT", actor, state, updated))
    return tuple(edges)


def store_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    actor = "DURABLE_STORE"
    if state.pending_attack != "NONE":
        updated = replace(
            state,
            rejected_attack=state.pending_attack,
            pending_attack="NONE",
        )
        return (_edge("STORE-029-REJECT-HOSTILE-REQUEST", actor, state, updated),)
    edges: list[OrchEdge] = []
    if (
        state.phase == "GRANT_CONSUME_PENDING"
        and state.owner_state == "ACTIVE"
        and state.grant_registry_state == "PENDING"
    ):
        assert state.parent_grant is not None
        ack = GrantConsumptionAck(
            schema=SCHEMA,
            parent_run_id=state.parent_grant.parent_run_id,
            binding_digest=parent_binding_digest(state.parent_grant),
            nonce=state.parent_grant.nonce,
            epoch=state.parent_grant.epoch,
            registry_id=state.parent_grant.issuance_registry_id,
            old_generation=state.parent_grant.issuance_generation,
            new_generation=state.parent_grant.issuance_generation + 1,
            outcome="CONSUMED",
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_grant_consumption_ack_auth(ack))
        updated = _append_parent_receipt(
            state,
            actor,
            "PARENT_GRANT_CONSUMED",
            _grant_consumption_ack_payload(ack),
        )
        updated = replace(
            updated,
            phase="PARENT_ACTIVE",
            grant_consumed=True,
            grant_registry_state="CONSUMED",
            grant_registry_generation=ack.new_generation,
            grant_consumption_ack=ack,
        )
        edges.append(
            _edge(
                "STORE-002B-COMMIT-GRANT-CONSUMPTION",
                actor,
                state,
                updated,
            )
        )
    if (
        state.publication == "ABANDONING"
        and state.owner_state == "FAILED"
        and state.parent_grant is not None
        and state.parent_ledger == "OPEN"
        and state.grant_registry_state in {"ISSUED", "PENDING"}
    ):
        ack = GrantConsumptionAck(
            schema=SCHEMA,
            parent_run_id=state.parent_grant.parent_run_id,
            binding_digest=parent_binding_digest(state.parent_grant),
            nonce=state.parent_grant.nonce,
            epoch=state.parent_grant.epoch,
            registry_id=state.parent_grant.issuance_registry_id,
            old_generation=state.parent_grant.issuance_generation,
            new_generation=state.parent_grant.issuance_generation + 1,
            outcome="RETIRED",
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_grant_consumption_ack_auth(ack))
        updated = _append_parent_receipt(
            state,
            actor,
            "PARENT_GRANT_RETIRED",
            _grant_consumption_ack_payload(ack),
        )
        updated = replace(
            updated,
            grant_registry_state="RETIRED",
            grant_registry_generation=ack.new_generation,
            grant_consumption_ack=ack,
        )
        edges.append(
            _edge(
                "STORE-002C-RETIRE-GRANT-NONCE",
                actor,
                state,
                updated,
            )
        )
    if state.phase == "PREPARED" and state.publication == "PREPARED":
        assert state.publication_commitment is not None
        ack = DurableAck(
            commitment_digest=state.publication_commitment.commitment_digest,
            generation=state.publication_commitment.expected_generation,
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_durable_ack_auth(ack))
        updated = replace(
            state,
            phase="DURABLE",
            publication="DURABLE",
            durable_ack=ack,
        )
        edges.append(_edge("STORE-019-DURABLE-ACK", actor, state, updated))
    if state.phase == "DURABLE" and state.publication == "DURABLE" and state.owner_state == "ACTIVE":
        assert state.publication_commitment is not None
        expected = state.publication_commitment.expected_generation
        if state.store_head_generation == expected:
            ack = PublicationAck(
                commitment_digest=state.publication_commitment.commitment_digest,
                old_generation=expected,
                new_generation=expected + 1,
                issuer=actor,
                auth_tag="",
            )
            ack = replace(ack, auth_tag=_publication_ack_auth(ack))
            updated = replace(
                state,
                phase="TERMINAL",
                publication="PUBLISHED",
                publication_ack=ack,
                store_head_generation=expected + 1,
            )
            edges.append(_edge("STORE-020-PUBLISH-CAS", actor, state, updated))
    if state.publication in {"PREPARED", "DURABLE"} and state.owner_state == "ACTIVE":
        expected = state.parent_grant.expected_publication_generation
        updated = replace(
            state,
            phase="TERMINAL",
            publication="STALE_REJECTED",
            store_head_generation=expected + 1,
        )
        edges.append(_edge("STORE-021-HEAD-CONFLICT", actor, state, updated))
    if (
        state.publication == "ABANDONING"
        and state.abandonment_commitment is not None
        and state.abandonment_ack is None
        and state.active_child == "NONE"
    ):
        expected = state.abandonment_commitment.expected_generation
        if state.store_head_generation != expected:
            return tuple(edges)
        ack = AbandonmentAck(
            commitment_digest=state.abandonment_commitment.commitment_digest,
            old_generation=expected,
            new_generation=expected + 1,
            outcome="ABANDONED",
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_abandonment_ack_auth(ack))
        updated = replace(
            state,
            phase="TERMINAL",
            publication="ABANDONED",
            abandonment_ack=ack,
            store_head_generation=ack.new_generation,
        )
        edges.append(_edge("STORE-026-TOMBSTONE-DURABLE-ABANDONMENT", actor, state, updated))
    return tuple(edges)


def adversary_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.publication in TERMINAL_PUBLICATIONS or state.pending_attack != "NONE":
        return ()
    edges: list[OrchEdge] = []
    actor = "ADVERSARY"
    if state.primary_state == "FAILED" and state.guardian_state == "ACTIVE":
        breached = replace(
            state,
            phase="ASSURANCE_BREACHED",
            guardian_state="FAILED",
            publication="ASSURANCE_BREACHED",
            assurance_breach="GUARDIAN_FAILURE",
        )
        edges.append(_edge("ADV-031-FAIL-GUARDIAN", actor, state, breached))
    if state.parent_grant is not None and state.rejected_attack == "NONE":
        edges.append(
            _edge(
                "ADV-027-REPLAY-GRANT",
                actor,
                state,
                replace(state, pending_attack="GRANT_REPLAY"),
            )
        )
    if state.publication in {"PREPARED", "DURABLE"} and state.rejected_attack == "NONE":
        edges.append(
            _edge(
                "ADV-028-ROLLBACK-PUBLICATION",
                actor,
                state,
                replace(state, pending_attack="PUBLICATION_ROLLBACK"),
            )
        )
    edges.append(_edge("ADV-030-STALL", actor, state, state))
    return tuple(edges)


def hostile_store_bypass_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.pending_attack == "NONE":
        return ()
    reason = (
        "GRANT_REGISTRY_BYPASS"
        if state.pending_attack == "GRANT_REPLAY"
        else "PUBLICATION_ROLLBACK"
    )
    breached = replace(
        state,
        phase="ASSURANCE_BREACHED",
        publication="ASSURANCE_BREACHED",
        pending_attack="NONE",
        assurance_breach=reason,
    )
    return (
        _edge(
            "ADV-029B-SUCCEED-STORE-BYPASS",
            "ADVERSARY",
            state,
            breached,
        ),
    )


@lru_cache(maxsize=None)
def next_states(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if not orchestrator_wf(state):
        raise OrchestratorReject("F05-ORCH-STATE-WF", state.phase)
    if state.publication in TERMINAL_PUBLICATIONS:
        return ()
    if state.pending_attack != "NONE":
        return store_next(state) + hostile_store_bypass_next(state)
    edges = (
        external_next(state)
        + supervisor_next(state)
        + child_next(state)
        + guardian_next(state)
        + store_next(state)
        + adversary_next(state)
    )
    return edges


def apply_trace(state: OrchestratorState, actions: tuple[str, ...]) -> OrchestratorState:
    current = state
    for action_id in actions:
        matches = [edge for edge in next_states(current) if edge.action_id == action_id]
        if len(matches) != 1:
            raise OrchestratorReject("F05-ORCH-TRACE", f"{action_id}:{len(matches)}")
        current = matches[0].state
    return current


def reachable_states() -> tuple[set[OrchestratorState], list[tuple[OrchestratorState, OrchEdge]]]:
    start = initial_state()
    key = semantic_projection(start)
    representatives = {key: start}
    queue: deque[tuple[object, ...]] = deque([key])
    graph: list[tuple[OrchestratorState, OrchEdge]] = []
    while queue:
        state = representatives[queue.popleft()]
        for edge in next_states(state):
            target_key = semantic_projection(edge.state)
            target = representatives.get(target_key)
            if target is None:
                target = edge.state
                representatives[target_key] = target
                queue.append(target_key)
            graph.append((state, replace(edge, state=target)))
    return set(representatives.values()), graph


def explore() -> dict[str, object]:
    states, graph = reachable_states()
    reverse: dict[OrchestratorState, set[OrchestratorState]] = defaultdict(set)
    terminals: set[OrchestratorState] = set()
    terminal_counts: Counter[str] = Counter()
    actions: set[str] = set()
    deadlocks = 0
    for state in states:
        outgoing = next_states(state)
        if state.publication in TERMINAL_PUBLICATIONS:
            terminals.add(state)
            terminal_counts[state.publication] += 1
            if outgoing:
                raise OrchestratorReject("F05-ORCH-TERMINAL-EDGE", state.publication)
        elif not outgoing:
            deadlocks += 1
    for before, edge in graph:
        reverse[edge.state].add(before)
        actions.add(edge.action_id)
        if edge.state.semantic_verdict is not None:
            raise OrchestratorReject("F05-ORCH-SEMANTIC-SELF-ISSUE", edge.action_id)
    coaccessible = set(terminals)
    queue: deque[OrchestratorState] = deque(terminals)
    while queue:
        state = queue.popleft()
        for predecessor in reverse[state]:
            if predecessor not in coaccessible:
                coaccessible.add(predecessor)
                queue.append(predecessor)
    return {
        "reachable_semantic_state_count": len(states),
        "edge_count": len(graph),
        "terminal_counts": dict(sorted(terminal_counts.items())),
        "nonterminal_deadlock_count": deadlocks,
        "states_without_terminal_path": len(states - coaccessible),
        "declared_action_count": len(ACTION_SPECS),
        "reachable_action_count": len(actions),
        "missing_actions": sorted(set(ACTION_SPECS) - actions),
        "undeclared_actions": sorted(actions - set(ACTION_SPECS)),
        "semantic_verdict_always_absent": True,
        "published_artifact_type": "LOCAL_DISPOSITION_CAPSULE",
        "external_assumptions_discharged": False,
        "durable_store_refinement_proved": False,
        "issuance_registry_refinement_proved": False,
        "global_nonce_uniqueness_proved": False,
        "symbolic_authentication_discharged": False,
        "exact_state_identity_explored": True,
        "child_terminal_trace_replay_checked": True,
        "durable_abandonment_ack_required": True,
        "coaccessibility_only": True,
        "universal_termination_proved": False,
        "infinite_stutter_counterexample_present": True,
        "assurance_breach_explicit": True,
        "assurance_breach_terminal_count": terminal_counts["ASSURANCE_BREACHED"],
        "guardian_survivability_proved": False,
        "external_semantic_verdict_issued": False,
    }


__all__ = [
    "ACTION_IDS",
    "ACTION_SPECS",
    "AbandonmentAck",
    "AbandonmentCommitment",
    "ChildCertificate",
    "DurableAck",
    "GrantConsumptionAck",
    "LocalDispositionCapsule",
    "OPEN_REFINEMENT_OBLIGATIONS",
    "OrchestratorReject",
    "OrchestratorState",
    "ParentGrant",
    "ParentReceipt",
    "PublicationAck",
    "PublicationCommitment",
    "SemanticVerdict",
    "apply_trace",
    "certificate_from_terminal",
    "child_certificate_wf",
    "child_grant_matches_parent",
    "child_next",
    "explore",
    "external_next",
    "fixture_child_certificate",
    "fixture_child_grant",
    "fixture_parent_grant",
    "guardian_next",
    "grant_consumption_ack_wf",
    "initial_state",
    "next_states",
    "orchestrator_wf",
    "parent_evidence_wf",
    "parent_grant_wf",
    "reachable_states",
    "semantic_projection",
    "store_next",
    "supervisor_next",
]
