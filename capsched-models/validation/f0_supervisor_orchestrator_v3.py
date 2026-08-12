#!/usr/bin/env python3
"""Actor-separated parent orchestration LTS for supervisor v3 candidate-4."""

from __future__ import annotations

from array import array
from collections import Counter, deque
from dataclasses import dataclass, replace
from functools import lru_cache

import f0_supervisor_lts_v3 as child


if not __debug__:
    raise RuntimeError("supervisor orchestrator model rejects optimized Python")


SCHEMA = "F0-SPV3-ORCH-C4"
SMALL_CACHE_MAX_ENTRIES = 256
STATE_CACHE_MAX_ENTRIES = 16384

if array("I").itemsize != 4 or array("B").itemsize != 1:
    raise RuntimeError("candidate-4 requires 32-bit and 8-bit compact array items")

ACTORS = {
    "EXTERNAL_OWNER",
    "PRIMARY_SUPERVISOR",
    "RECOVERY_GUARDIAN",
    "CHILD_ENVELOPE",
    "DURABLE_STORE",
    "CONCURRENT_STORE_WRITER",
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
    "PUBLICATION_FENCE_PENDING",
    "PUBLICATION_FENCED",
    "ABANDONING",
    "ASSURANCE_BREACHED",
    "TERMINAL",
}
OWNER_STATES = {"ACTIVE", "FAILED"}
PRIMARY_STATES = {"ACTIVE", "FAILED"}
GUARDIAN_STATES = {"ACTIVE", "FAILED"}
CHILD_STATUSES = {
    "NONE",
    "GRANT_AVAILABLE",
    "RUNNING",
    "ATTACHED",
    "RETIRED",
    "SKIPPED",
}
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
    "FENCE_PENDING",
    "FENCED",
    "PUBLISHED",
    "ABANDONING",
    "ABANDONED",
    "STALE_REJECTED",
    "ASSURANCE_BREACHED",
}
PENDING_ATTACKS = {
    "NONE",
    "GRANT_REPLAY",
    "PUBLICATION_ROLLBACK",
    "POST_OWNER_PUBLISH",
    "SUPERSEDED_PUBLICATION",
}
GRANT_REGISTRY_STATES = {"NONE", "ISSUED", "PENDING", "CONSUMED", "RETIRED"}
ASSURANCE_BREACHES = {
    "NONE",
    "GUARDIAN_FAILURE",
    "GRANT_REGISTRY_BYPASS",
    "PUBLICATION_ROLLBACK",
    "POST_OWNER_FAILURE_PUBLICATION",
    "ABANDONMENT_HEAD_CONFLICT",
    "SUPERSEDED_PUBLICATION_ACCEPTED",
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
    "ORCH-ATTACK-CTX-001 typed attack-context refinement and unbounded repeated-attempt history",
    "ORCH-GUARD-001 guardian cleanup authority after owner or primary failure",
    "ORCH-LIVE-001 fairness for child cleanup, store acknowledgment, and publication",
    "ORCH-SEM-001 external semantic verifier and verdict issuance remain outside this LTS",
)


@dataclass(frozen=True, slots=True)
class StoreAttackSpec:
    action_id: str
    breach: str


STORE_ATTACK_SPECS = {
    "GRANT_REPLAY": StoreAttackSpec(
        "ADV-027-REPLAY-GRANT",
        "GRANT_REGISTRY_BYPASS",
    ),
    "PUBLICATION_ROLLBACK": StoreAttackSpec(
        "ADV-028-ROLLBACK-PUBLICATION",
        "PUBLICATION_ROLLBACK",
    ),
    "POST_OWNER_PUBLISH": StoreAttackSpec(
        "ADV-020A-DELAYED-POST-OWNER-PUBLISH",
        "POST_OWNER_FAILURE_PUBLICATION",
    ),
    "SUPERSEDED_PUBLICATION": StoreAttackSpec(
        "ADV-020C-ATTEMPT-SUPERSEDED-PUBLICATION",
        "SUPERSEDED_PUBLICATION_ACCEPTED",
    ),
}

if set(STORE_ATTACK_SPECS) != PENDING_ATTACKS - {"NONE"}:
    raise RuntimeError("typed store attack registry is not exact")
if {spec.breach for spec in STORE_ATTACK_SPECS.values()} - ASSURANCE_BREACHES:
    raise RuntimeError("typed store attack breach registry is not exact")


class OrchestratorReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
class ChildStartBinding:
    schema: str
    parent_run_id: str
    binding_digest: str
    role: str
    child_run_id: str
    grant_digest: str
    controller_generation: int
    authority_namespace: str
    parent_prefix_hash: str
    issuer: str
    start_digest: str
    auth_tag: str


def _child_start_body(binding: ChildStartBinding) -> tuple[object, ...]:
    return (
        binding.schema,
        binding.parent_run_id,
        binding.binding_digest,
        binding.role,
        binding.child_run_id,
        binding.grant_digest,
        binding.controller_generation,
        binding.authority_namespace,
        binding.parent_prefix_hash,
        binding.issuer,
    )


def _child_start_digest(binding: ChildStartBinding) -> str:
    return child.digest("CHILD_START_BINDING", *_child_start_body(binding))


def _child_start_auth(binding: ChildStartBinding) -> str:
    return child.digest(
        "ABSTRACT_CHILD_START_AUTH",
        _child_start_digest(binding),
    )


@dataclass(frozen=True, slots=True)
class ChildAttachment:
    schema: str
    parent_run_id: str
    binding_digest: str
    role: str
    child_run_id: str
    grant_digest: str
    start_binding_digest: str
    certificate_digest: str
    parent_controller_generation: int
    parent_prefix_hash: str
    owner_failure_notice_digest: str
    issuer: str
    attachment_digest: str
    auth_tag: str


def _child_attachment_body(
    attachment: ChildAttachment,
) -> tuple[object, ...]:
    return (
        attachment.schema,
        attachment.parent_run_id,
        attachment.binding_digest,
        attachment.role,
        attachment.child_run_id,
        attachment.grant_digest,
        attachment.start_binding_digest,
        attachment.certificate_digest,
        attachment.parent_controller_generation,
        attachment.parent_prefix_hash,
        attachment.owner_failure_notice_digest,
        attachment.issuer,
    )


def _child_attachment_digest(attachment: ChildAttachment) -> str:
    return child.digest(
        "CHILD_CERTIFICATE_ATTACHMENT",
        *_child_attachment_body(attachment),
    )


def _child_attachment_auth(attachment: ChildAttachment) -> str:
    return child.digest(
        "ABSTRACT_CHILD_ATTACHMENT_AUTH",
        _child_attachment_digest(attachment),
    )


@dataclass(frozen=True, slots=True)
class ChildGrantRetirement:
    schema: str
    parent_run_id: str
    binding_digest: str
    role: str
    child_run_id: str
    grant_digest: str
    owner_failure_notice_digest: str
    controller_generation: int
    parent_prefix_hash: str
    reason: str
    issuer: str
    retirement_digest: str
    auth_tag: str


def _child_retirement_body(
    retirement: ChildGrantRetirement,
) -> tuple[object, ...]:
    return (
        retirement.schema,
        retirement.parent_run_id,
        retirement.binding_digest,
        retirement.role,
        retirement.child_run_id,
        retirement.grant_digest,
        retirement.owner_failure_notice_digest,
        retirement.controller_generation,
        retirement.parent_prefix_hash,
        retirement.reason,
        retirement.issuer,
    )


def _child_retirement_digest(retirement: ChildGrantRetirement) -> str:
    return child.digest(
        "CHILD_GRANT_RETIREMENT",
        *_child_retirement_body(retirement),
    )


def _child_retirement_auth(retirement: ChildGrantRetirement) -> str:
    return child.digest(
        "ABSTRACT_CHILD_GRANT_RETIREMENT_AUTH",
        _child_retirement_digest(retirement),
    )


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


@lru_cache(maxsize=SMALL_CACHE_MAX_ENTRIES)
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


@lru_cache(maxsize=SMALL_CACHE_MAX_ENTRIES)
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
                "OBS-033B-COMPLETION-ARRIVAL",
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


@dataclass(frozen=True, slots=True)
class ParentReceiptSpec:
    issuers: frozenset[str]


PARENT_RECEIPT_SPECS = {
    "PARENT_GRANT_CONSUME_REQUESTED": ParentReceiptSpec(frozenset(CONTROLLERS)),
    "PARENT_GRANT_CONSUMED": ParentReceiptSpec(frozenset({"DURABLE_STORE"})),
    "PARENT_GRANT_RETIRED": ParentReceiptSpec(frozenset({"DURABLE_STORE"})),
    "PRODUCER_GRANT_ACCEPTED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "PRODUCER_STARTED": ParentReceiptSpec(frozenset(CONTROLLERS)),
    "PRODUCER_CERT_ATTACHED": ParentReceiptSpec(frozenset({"CHILD_ENVELOPE"})),
    "PRODUCER_GRANT_RETIRED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "CHECKER_GRANT_ACCEPTED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "CHECKER_STARTED": ParentReceiptSpec(frozenset(CONTROLLERS)),
    "CHECKER_CERT_ATTACHED": ParentReceiptSpec(frozenset({"CHILD_ENVELOPE"})),
    "CHECKER_GRANT_RETIRED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "PRIMARY_FAILOVER": ParentReceiptSpec(frozenset({"RECOVERY_GUARDIAN"})),
    "OWNER_FAILURE_OBSERVED": ParentReceiptSpec(frozenset({"EXTERNAL_OWNER"})),
    "PARENT_EVIDENCE_SEAL": ParentReceiptSpec(frozenset(CONTROLLERS)),
}


@dataclass(frozen=True, slots=True)
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


class ParentReceiptHistory(child.PersistentSequence):
    """Typed parent evidence view over the shared persistent mechanism."""

    __slots__ = ()

    def append(self, value: object) -> ParentReceiptHistory:
        if not isinstance(value, ParentReceipt):
            raise TypeError("parent history accepts ParentReceipt values only")
        return ParentReceiptHistory(self, value)


EMPTY_PARENT_RECEIPT_HISTORY = ParentReceiptHistory()


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


@dataclass(frozen=True, slots=True)
class LocalDispositionCapsule:
    schema: str
    parent_run_id: str
    parent_evidence_root: str
    producer_root: str
    checker_root: str
    local_disposition: str
    artifact_type: str
    controller_generation: int
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
        capsule.controller_generation,
        capsule.issuer,
    )


def _capsule_digest(capsule: LocalDispositionCapsule) -> str:
    return child.digest("LOCAL_DISPOSITION_CAPSULE", *_capsule_body(capsule))


def _capsule_auth(capsule: LocalDispositionCapsule) -> str:
    return child.digest("ABSTRACT_LOCAL_CAPSULE_AUTH", *_capsule_body(capsule), capsule.capsule_digest)


@dataclass(frozen=True, slots=True)
class SemanticVerdict:
    """A distinct external type; no transition in this module constructs one."""

    external_review_root: str
    verdict: str
    external_issuer: str


@dataclass(frozen=True, slots=True)
class PublicationCommitment:
    parent_run_id: str
    artifact_type: str
    capsule_digest: str
    expected_generation: int
    controller_generation: int
    issuer: str
    commitment_digest: str


def _commitment_digest(commitment: PublicationCommitment) -> str:
    return child.digest(
        "PUBLICATION_COMMITMENT",
        commitment.parent_run_id,
        commitment.artifact_type,
        commitment.capsule_digest,
        commitment.expected_generation,
        commitment.controller_generation,
        commitment.issuer,
    )


@dataclass(frozen=True, slots=True)
class DurableAck:
    commitment_digest: str
    generation: int
    controller_generation: int
    observation_generation: int
    issuer: str
    auth_tag: str


def _durable_ack_auth(ack: DurableAck) -> str:
    return child.digest(
        "DURABLE_ACK",
        ack.commitment_digest,
        ack.generation,
        ack.controller_generation,
        ack.observation_generation,
        ack.issuer,
    )


STORE_HEAD_KINDS = {
    "EMPTY",
    "LOCAL_PUBLICATION",
    "ABANDONMENT_TOMBSTONE",
    "FOREIGN",
}


@dataclass(frozen=True, slots=True)
class StoreHead:
    generation: int
    content_kind: str
    content_digest: str
    controller_generation: int
    issuer: str
    auth_tag: str


def _store_head_body(head: StoreHead) -> tuple[object, ...]:
    return (
        head.generation,
        head.content_kind,
        head.content_digest,
        head.controller_generation,
        head.issuer,
    )


def _store_head_auth(head: StoreHead) -> str:
    return child.digest("ABSTRACT_STORE_HEAD_AUTH", *_store_head_body(head))


def _empty_store_head(generation: int) -> StoreHead:
    partial = StoreHead(
        generation=generation,
        content_kind="EMPTY",
        content_digest="",
        controller_generation=0,
        issuer="DURABLE_STORE",
        auth_tag="",
    )
    return replace(partial, auth_tag=_store_head_auth(partial))


def _publication_store_head(
    commitment: PublicationCommitment,
) -> StoreHead:
    partial = StoreHead(
        generation=commitment.expected_generation + 1,
        content_kind="LOCAL_PUBLICATION",
        content_digest=commitment.commitment_digest,
        controller_generation=commitment.controller_generation,
        issuer="DURABLE_STORE",
        auth_tag="",
    )
    return replace(partial, auth_tag=_store_head_auth(partial))


def _abandonment_store_head(
    commitment: AbandonmentCommitment,
    controller_generation: int,
) -> StoreHead:
    partial = StoreHead(
        generation=commitment.expected_generation + 1,
        content_kind="ABANDONMENT_TOMBSTONE",
        content_digest=commitment.commitment_digest,
        controller_generation=controller_generation,
        issuer="DURABLE_STORE",
        auth_tag="",
    )
    return replace(partial, auth_tag=_store_head_auth(partial))


def _foreign_store_head(state: OrchestratorState) -> StoreHead:
    if state.parent_grant is None:
        raise OrchestratorReject("F05-ORCH-FOREIGN-HEAD-NO-GRANT", state.phase)
    expected = state.parent_grant.expected_publication_generation
    partial = StoreHead(
        generation=expected + 1,
        content_kind="FOREIGN",
        content_digest=child.digest(
            "CONCURRENT_STORE_WRITE",
            parent_binding_digest(state.parent_grant),
            expected,
            state.store_controller_generation,
        ),
        controller_generation=state.store_controller_generation,
        issuer="CONCURRENT_STORE_WRITER",
        auth_tag="",
    )
    return replace(partial, auth_tag=_store_head_auth(partial))


@dataclass(frozen=True, slots=True)
class StoreFenceAck:
    schema: str
    parent_run_id: str
    binding_digest: str
    old_controller_generation: int
    new_controller_generation: int
    superseded_commitment_digest: str
    supersession_digest: str
    observed_head: StoreHead
    issuer: str
    auth_tag: str


def _store_fence_body(ack: StoreFenceAck) -> tuple[object, ...]:
    return (
        ack.schema,
        ack.parent_run_id,
        ack.binding_digest,
        ack.old_controller_generation,
        ack.new_controller_generation,
        ack.superseded_commitment_digest,
        ack.supersession_digest,
        _store_head_body(ack.observed_head),
        ack.observed_head.auth_tag,
        ack.issuer,
    )


def _store_fence_auth(ack: StoreFenceAck) -> str:
    return child.digest("ABSTRACT_STORE_FENCE_AUTH", *_store_fence_body(ack))


@dataclass(frozen=True, slots=True)
class SupersededPublicationAttempt:
    commitment: PublicationCommitment
    durable_ack: DurableAck | None
    superseded_by_generation: int
    issuer: str
    supersession_digest: str
    auth_tag: str


def _supersession_digest(attempt: SupersededPublicationAttempt) -> str:
    return child.digest(
        "SUPERSEDED_PUBLICATION_ATTEMPT",
        attempt.commitment.commitment_digest,
        attempt.durable_ack.auth_tag if attempt.durable_ack else "",
        attempt.superseded_by_generation,
        attempt.issuer,
    )


def _supersession_auth(attempt: SupersededPublicationAttempt) -> str:
    return child.digest(
        "ABSTRACT_PUBLICATION_SUPERSESSION_AUTH",
        _supersession_digest(attempt),
    )


@dataclass(frozen=True, slots=True)
class PublicationAck:
    commitment_digest: str
    old_generation: int
    new_generation: int
    controller_generation: int
    issuer: str
    auth_tag: str


def _publication_ack_auth(ack: PublicationAck) -> str:
    return child.digest(
        "PUBLICATION_ACK",
        ack.commitment_digest,
        ack.old_generation,
        ack.new_generation,
        ack.controller_generation,
        ack.issuer,
    )


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
class AbandonmentConflictNotice:
    schema: str
    parent_run_id: str
    binding_digest: str
    commitment_digest: str
    expected_generation: int
    observed_head: StoreHead
    issuer: str
    auth_tag: str


def _abandonment_conflict_body(
    notice: AbandonmentConflictNotice,
) -> tuple[object, ...]:
    return (
        notice.schema,
        notice.parent_run_id,
        notice.binding_digest,
        notice.commitment_digest,
        notice.expected_generation,
        _store_head_body(notice.observed_head),
        notice.observed_head.auth_tag,
        notice.issuer,
    )


def _abandonment_conflict_auth(notice: AbandonmentConflictNotice) -> str:
    return child.digest(
        "ABSTRACT_ABANDONMENT_CONFLICT_AUTH",
        *_abandonment_conflict_body(notice),
    )


@dataclass(frozen=True, slots=True)
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


@dataclass(frozen=True, slots=True)
class OwnerFailureNotice:
    schema: str
    parent_run_id: str
    binding_digest: str
    observed_phase: str
    parent_prefix_hash: str
    local_capsule_digest_at_failure: str
    publication_at_failure: str
    store_controller_generation_at_failure: int
    publication_commitment_digest_at_failure: str
    durable_ack_auth_at_failure: str
    store_fence_ack_auth_at_failure: str
    issuer: str
    auth_tag: str


def _owner_failure_auth(notice: OwnerFailureNotice) -> str:
    return child.digest(
        "ABSTRACT_OWNER_FAILURE_AUTH",
        _owner_failure_digest(notice),
    )


def _owner_failure_digest(notice: OwnerFailureNotice) -> str:
    return child.digest(
        "OWNER_FAILURE_NOTICE",
        notice.schema,
        notice.parent_run_id,
        notice.binding_digest,
        notice.observed_phase,
        notice.parent_prefix_hash,
        notice.local_capsule_digest_at_failure,
        notice.publication_at_failure,
        notice.store_controller_generation_at_failure,
        notice.publication_commitment_digest_at_failure,
        notice.durable_ack_auth_at_failure,
        notice.store_fence_ack_auth_at_failure,
        notice.issuer,
    )


MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT = 1


@dataclass(frozen=True, slots=True)
class StoreAttackContext:
    schema: str
    parent_run_id: str
    binding_digest: str
    parent_receipt_count: int
    parent_prefix_hash: str
    attack: str
    phase: str
    owner_state: str
    primary_state: str
    controller: str
    recovery_generation: int
    store_controller_generation: int
    grant_nonce: str
    grant_registry_id: str
    grant_registry_state: str
    grant_registry_generation: int
    expected_publication_generation: int
    local_disposition: str
    local_capsule_digest: str
    publication: str
    publication_commitment_digest: str
    publication_commitment_controller_generation: int
    durable_ack_auth_tag: str
    store_head: StoreHead
    store_fence_ack_auth_tag: str
    owner_failure_notice_digest: str
    superseded_commitment_digest: str
    supersession_digest: str
    context_digest: str


def _store_attack_context_body(
    context: StoreAttackContext,
) -> tuple[object, ...]:
    return (
        context.schema,
        context.parent_run_id,
        context.binding_digest,
        context.parent_receipt_count,
        context.parent_prefix_hash,
        context.attack,
        context.phase,
        context.owner_state,
        context.primary_state,
        context.controller,
        context.recovery_generation,
        context.store_controller_generation,
        context.grant_nonce,
        context.grant_registry_id,
        context.grant_registry_state,
        context.grant_registry_generation,
        context.expected_publication_generation,
        context.local_disposition,
        context.local_capsule_digest,
        context.publication,
        context.publication_commitment_digest,
        context.publication_commitment_controller_generation,
        context.durable_ack_auth_tag,
        _store_head_body(context.store_head),
        context.store_head.auth_tag,
        context.store_fence_ack_auth_tag,
        context.owner_failure_notice_digest,
        context.superseded_commitment_digest,
        context.supersession_digest,
    )


def _store_attack_context_digest(context: StoreAttackContext) -> str:
    return child.digest(
        "TYPED_STORE_ATTACK_CONTEXT",
        *_store_attack_context_body(context),
    )


@dataclass(frozen=True, slots=True)
class StoreAttackKey:
    attack: str
    context_digest: str


@dataclass(frozen=True, slots=True)
class StoreSecurityEvent:
    schema: str
    parent_run_id: str
    binding_digest: str
    sequence: int
    attempt: int
    event_kind: str
    attack: str
    context: StoreAttackContext
    context_digest: str
    issuer: str
    previous_hash: str
    auth_tag: str


def _store_security_body(event: StoreSecurityEvent) -> tuple[object, ...]:
    return (
        event.schema,
        event.parent_run_id,
        event.binding_digest,
        event.sequence,
        event.attempt,
        event.event_kind,
        event.attack,
        _store_attack_context_body(event.context),
        event.context.context_digest,
        event.context_digest,
        event.issuer,
        event.previous_hash,
    )


def _store_security_auth(event: StoreSecurityEvent) -> str:
    return child.digest("STORE_SECURITY_AUTH", *_store_security_body(event))


def store_security_hash(event: StoreSecurityEvent) -> str:
    return child.digest(
        "STORE_SECURITY_EVENT",
        *_store_security_body(event),
        event.auth_tag,
    )


@dataclass(frozen=True, slots=True)
class OrchestratorState:
    phase: str = "WAIT_GRANT"
    parent_grant: ParentGrant | None = None
    grant_consume_requested: bool = False
    grant_consumed: bool = False
    grant_registry_state: str = "NONE"
    grant_registry_generation: int = 0
    grant_consumption_ack: GrantConsumptionAck | None = None
    owner_state: str = "ACTIVE"
    owner_failure_notice: OwnerFailureNotice | None = None
    owner_failure_phase: str = "NONE"
    primary_state: str = "ACTIVE"
    guardian_state: str = "ACTIVE"
    controller: str = "PRIMARY_SUPERVISOR"
    producer_status: str = "NONE"
    producer_grant: child.RunGrant | None = None
    producer_start_binding: ChildStartBinding | None = None
    producer_certificate: ChildCertificate | None = None
    producer_attachment: ChildAttachment | None = None
    producer_retirement: ChildGrantRetirement | None = None
    checker_status: str = "NONE"
    checker_grant: child.RunGrant | None = None
    checker_start_binding: ChildStartBinding | None = None
    checker_certificate: ChildCertificate | None = None
    checker_attachment: ChildAttachment | None = None
    checker_retirement: ChildGrantRetirement | None = None
    active_child: str = "NONE"
    parent_ledger: str = "OPEN"
    parent_receipts: ParentReceiptHistory | tuple[ParentReceipt, ...] = (
        EMPTY_PARENT_RECEIPT_HISTORY
    )
    parent_evidence_root: str = ""
    local_disposition: str = "NONE"
    local_capsule: LocalDispositionCapsule | None = None
    semantic_verdict: SemanticVerdict | None = None
    publication: str = "NONE"
    publication_commitment: PublicationCommitment | None = None
    durable_ack: DurableAck | None = None
    superseded_publications: tuple[SupersededPublicationAttempt, ...] = ()
    publication_ack: PublicationAck | None = None
    abandonment_commitment: AbandonmentCommitment | None = None
    abandonment_ack: AbandonmentAck | None = None
    abandonment_conflict_notice: AbandonmentConflictNotice | None = None
    store_head: StoreHead | None = None
    store_controller_generation: int = 0
    store_fence_ack: StoreFenceAck | None = None
    pending_attack: str = "NONE"
    pending_attack_context: StoreAttackContext | None = None
    store_attack_attempts: tuple[str, ...] = ()
    attempted_attack_contexts: tuple[StoreAttackKey, ...] = ()
    store_attack_rejections: tuple[str, ...] = ()
    store_security_events: tuple[StoreSecurityEvent, ...] = ()
    assurance_breach: str = "NONE"
    recovery_receipts: tuple[RecoveryReceipt, ...] = ()

    @property
    def store_head_generation(self) -> int:
        return self.store_head.generation if self.store_head is not None else 0


@dataclass(frozen=True, slots=True)
class OrchEdge:
    action_id: str
    actor: str
    state: OrchestratorState


@dataclass(frozen=True, slots=True)
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
    "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B": ActionSpec(
        frozenset({"CHILD_ENVELOPE"}), "ChildNext"
    ),
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
    "STORE-018A-FENCE-PUBLICATION-CONTROLLER": ActionSpec(
        frozenset({"DURABLE_STORE"}), "StoreNext"
    ),
    "EXT-018C-ADVANCE-STORE-HEAD": ActionSpec(
        frozenset({"CONCURRENT_STORE_WRITER"}), "ConcurrentStoreNext"
    ),
    "GRD-018B-REAUTHORIZE-PUBLICATION": ActionSpec(
        frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"
    ),
    "STORE-019-DURABLE-ACK": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-019A-ACK-OLD-PRE-FENCE": ActionSpec(
        frozenset({"DURABLE_STORE"}), "StoreNext"
    ),
    "STORE-020-PUBLISH-CAS": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS": ActionSpec(
        frozenset({"DURABLE_STORE"}), "StoreNext"
    ),
    "ADV-020A-DELAYED-POST-OWNER-PUBLISH": ActionSpec(
        frozenset({"ADVERSARY"}), "AdversaryNext"
    ),
    "ADV-020C-ATTEMPT-SUPERSEDED-PUBLICATION": ActionSpec(
        frozenset({"ADVERSARY"}), "AdversaryNext"
    ),
    "STORE-021-HEAD-CONFLICT": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "EXT-023-OWNER-FAILURE": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "ExternalNext"),
    "GRD-023B-FENCE-AFTER-OWNER-FAILURE": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "CHILD-024-ATTACH-ACTIVE-ABANDONED": ActionSpec(frozenset({"CHILD_ENVELOPE"}), "ChildNext"),
    "EXT-024A-RETIRE-PRODUCER-GRANT": ActionSpec(
        frozenset({"EXTERNAL_OWNER"}), "ExternalNext"
    ),
    "EXT-024B-RETIRE-CHECKER-GRANT": ActionSpec(
        frozenset({"EXTERNAL_OWNER"}), "ExternalNext"
    ),
    "GRD-025-PREPARE-ABANDONMENT": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "GuardianNext"),
    "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "STORE-026B-TOMBSTONE-HEAD-CONFLICT": ActionSpec(
        frozenset({"DURABLE_STORE"}), "StoreNext"
    ),
    "ADV-027-REPLAY-GRANT": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-028-ROLLBACK-PUBLICATION": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "STORE-029-REJECT-HOSTILE-REQUEST": ActionSpec(frozenset({"DURABLE_STORE"}), "StoreNext"),
    "ADV-029B-SUCCEED-STORE-BYPASS": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-030-STALL": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
    "ADV-031-FAIL-GUARDIAN": ActionSpec(frozenset({"ADVERSARY"}), "AdversaryNext"),
}
ACTION_IDS = tuple(ACTION_SPECS)
if len(ACTION_IDS) > 256:
    raise RuntimeError("compact orchestrator action index exceeds one byte")
ACTION_INDEX = {action_id: index for index, action_id in enumerate(ACTION_IDS)}


PARENT_STATE_REFERENCE_FIELDS = frozenset(
    {
        "parent_grant",
        "grant_consumption_ack",
        "owner_failure_notice",
        "producer_grant",
        "producer_start_binding",
        "producer_certificate",
        "producer_attachment",
        "producer_retirement",
        "checker_grant",
        "checker_start_binding",
        "checker_certificate",
        "checker_attachment",
        "checker_retirement",
        "parent_receipts",
        "local_capsule",
        "semantic_verdict",
        "publication_commitment",
        "durable_ack",
        "superseded_publications",
        "publication_ack",
        "abandonment_commitment",
        "abandonment_ack",
        "abandonment_conflict_notice",
        "store_head",
        "store_fence_ack",
        "pending_attack_context",
        "store_attack_attempts",
        "attempted_attack_contexts",
        "store_attack_rejections",
        "store_security_events",
        "recovery_receipts",
    }
)


@dataclass(frozen=True, slots=True)
class OrchestratorReachabilityGraph:
    """Exact orchestrator states with fixed-width adjacency indexes."""

    states: child.CompactExactStateStore
    edge_offsets: array
    target_indices: array
    action_indices: array

    def __post_init__(self) -> None:
        if (
            self.edge_offsets.typecode != "I"
            or self.target_indices.typecode != "I"
            or self.action_indices.typecode != "B"
            or len(self.edge_offsets) != len(self.states) + 1
            or not self.edge_offsets
            or self.edge_offsets[0] != 0
            or self.edge_offsets[-1] != len(self.target_indices)
            or len(self.target_indices) != len(self.action_indices)
            or not self.states.frozen
        ):
            raise RuntimeError("malformed compact orchestrator reachability graph")

    @property
    def edge_count(self) -> int:
        return len(self.target_indices)

_registered_attack_actions = {
    spec.action_id for spec in STORE_ATTACK_SPECS.values()
}
if len(_registered_attack_actions) != len(STORE_ATTACK_SPECS):
    raise RuntimeError("typed store attack action IDs are not unique")
for _attack_action in _registered_attack_actions:
    _attack_action_spec = ACTION_SPECS.get(_attack_action)
    if _attack_action_spec != ActionSpec(
        frozenset({"ADVERSARY"}),
        "AdversaryNext",
    ):
        raise RuntimeError(
            f"typed store attack action registry mismatch: {_attack_action}"
        )


ACTION_WRITE_FIELDS: dict[str, frozenset[str]] = {}


def _allow_writes(action_ids: tuple[str, ...], *field_names: str) -> None:
    allowed = frozenset(field_names)
    for action_id in action_ids:
        if action_id in ACTION_WRITE_FIELDS:
            raise RuntimeError(f"duplicate orchestrator action write policy: {action_id}")
        ACTION_WRITE_FIELDS[action_id] = allowed


_allow_writes(
    ("EXT-001-DELIVER-PARENT-GRANT",),
    "grant_registry_generation", "grant_registry_state", "parent_grant", "phase",
    "store_head",
)
_allow_writes(
    ("SUP-002-CONSUME-PARENT-GRANT",),
    "grant_consume_requested", "grant_registry_state", "parent_receipts", "phase",
)
_allow_writes(
    ("STORE-002B-COMMIT-GRANT-CONSUMPTION",),
    "grant_consumed", "grant_consumption_ack", "grant_registry_generation",
    "grant_registry_state", "parent_receipts", "phase",
)
_allow_writes(
    ("STORE-002C-RETIRE-GRANT-NONCE",),
    "grant_consumption_ack", "grant_registry_generation", "grant_registry_state",
    "parent_receipts",
)
_allow_writes(
    ("EXT-003-DELIVER-PRODUCER-GRANT",),
    "parent_receipts", "phase", "producer_grant", "producer_status",
)
_allow_writes(
    ("SUP-004-START-PRODUCER",),
    "active_child", "parent_receipts", "phase", "producer_start_binding",
    "producer_status",
)
_allow_writes(
    (
        "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
        "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B",
        "CHILD-006-ATTACH-PRODUCER-RESOURCE",
        "CHILD-007-ATTACH-PRODUCER-INTERNAL",
        "CHILD-008-ATTACH-PRODUCER-ABANDONED",
    ),
    "active_child", "checker_status", "parent_receipts", "phase",
    "producer_attachment", "producer_certificate", "producer_status",
)
_allow_writes(
    ("EXT-009-DELIVER-CHECKER-GRANT",),
    "checker_grant", "checker_status", "parent_receipts", "phase",
)
_allow_writes(
    ("SUP-010-START-CHECKER",),
    "active_child", "checker_start_binding", "checker_status",
    "parent_receipts", "phase",
)
_allow_writes(
    (
        "CHILD-011-ATTACH-CHECKER-ACCEPT",
        "CHILD-012-ATTACH-CHECKER-REJECT",
        "CHILD-013-ATTACH-CHECKER-RESOURCE",
        "CHILD-014-ATTACH-CHECKER-INTERNAL",
        "CHILD-015-ATTACH-CHECKER-ABANDONED",
    ),
    "active_child", "checker_attachment", "checker_certificate",
    "checker_status", "parent_receipts", "phase",
)
_allow_writes(
    ("SUP-016-SEAL-PARENT-EVIDENCE",),
    "parent_evidence_root", "parent_ledger", "parent_receipts", "phase",
)
_allow_writes(
    ("SUP-017-DECIDE-LOCAL-DISPOSITION",),
    "local_capsule", "local_disposition", "phase",
)
_allow_writes(
    ("SUP-018-PREPARE-LOCAL-PUBLICATION",),
    "phase", "publication", "publication_commitment",
)
_allow_writes(
    ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
    "durable_ack", "phase", "publication", "publication_commitment",
    "store_controller_generation", "store_fence_ack",
    "superseded_publications",
)
_allow_writes(
    ("EXT-018C-ADVANCE-STORE-HEAD",),
    "store_head",
)
_allow_writes(
    ("GRD-018B-REAUTHORIZE-PUBLICATION",),
    "phase", "publication", "publication_commitment",
)
_allow_writes(("STORE-019-DURABLE-ACK",), "durable_ack", "phase", "publication")
_allow_writes(("STORE-019A-ACK-OLD-PRE-FENCE",), "durable_ack")
_allow_writes(
    ("STORE-020-PUBLISH-CAS",),
    "phase", "publication", "publication_ack", "store_head",
)
_allow_writes(
    ("STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS",),
    "phase", "publication", "publication_ack", "store_head",
)
_allow_writes(
    ("ADV-020A-DELAYED-POST-OWNER-PUBLISH",),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_allow_writes(
    ("ADV-020C-ATTEMPT-SUPERSEDED-PUBLICATION",),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_allow_writes(
    ("STORE-021-HEAD-CONFLICT",),
    "phase", "publication",
)
_allow_writes(
    ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    "controller", "parent_receipts", "phase", "primary_state", "publication",
    "recovery_receipts",
)
_allow_writes(
    ("EXT-023-OWNER-FAILURE",),
    "owner_failure_notice", "owner_failure_phase", "owner_state", "parent_receipts",
    "phase", "publication",
)
_allow_writes(
    ("GRD-023B-FENCE-AFTER-OWNER-FAILURE",),
    "controller", "parent_receipts", "primary_state", "recovery_receipts",
)
_allow_writes(
    ("CHILD-024-ATTACH-ACTIVE-ABANDONED",),
    "active_child", "checker_attachment", "checker_certificate",
    "checker_status", "parent_receipts", "producer_attachment",
    "producer_certificate", "producer_status",
)
_allow_writes(
    ("EXT-024A-RETIRE-PRODUCER-GRANT",),
    "parent_receipts", "producer_retirement", "producer_status",
)
_allow_writes(
    ("EXT-024B-RETIRE-CHECKER-GRANT",),
    "checker_retirement", "checker_status", "parent_receipts",
)
_allow_writes(
    ("GRD-025-PREPARE-ABANDONMENT",),
    "abandonment_commitment", "local_capsule", "local_disposition",
    "parent_evidence_root", "parent_ledger", "parent_receipts",
)
_allow_writes(
    ("STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",),
    "abandonment_ack", "phase", "publication", "store_head",
)
_allow_writes(
    ("STORE-026B-TOMBSTONE-HEAD-CONFLICT",),
    "abandonment_conflict_notice", "assurance_breach", "phase", "publication",
)
_allow_writes(
    (
        "ADV-027-REPLAY-GRANT",
        "ADV-028-ROLLBACK-PUBLICATION",
    ),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_allow_writes(
    ("STORE-029-REJECT-HOSTILE-REQUEST",),
    "pending_attack", "pending_attack_context", "store_attack_rejections",
    "store_security_events",
)
_allow_writes(
    ("ADV-029B-SUCCEED-STORE-BYPASS",),
    "assurance_breach", "pending_attack", "pending_attack_context", "phase",
    "publication",
)
_allow_writes(("ADV-030-STALL",))
_allow_writes(
    ("ADV-031-FAIL-GUARDIAN",),
    "assurance_breach", "guardian_state", "phase", "publication",
)

ACTION_REQUIRED_WRITE_FIELDS: dict[str, frozenset[str]] = {}


def _require_writes(action_ids: tuple[str, ...], *field_names: str) -> None:
    required = frozenset(field_names)
    for action_id in action_ids:
        if action_id in ACTION_REQUIRED_WRITE_FIELDS:
            raise RuntimeError(
                f"duplicate orchestrator required-write policy: {action_id}"
            )
        ACTION_REQUIRED_WRITE_FIELDS[action_id] = required


_require_writes(
    ("EXT-001-DELIVER-PARENT-GRANT",),
    "grant_registry_generation", "grant_registry_state", "parent_grant", "phase",
    "store_head",
)
_require_writes(
    ("SUP-002-CONSUME-PARENT-GRANT",),
    "grant_consume_requested", "grant_registry_state", "parent_receipts", "phase",
)
_require_writes(
    ("STORE-002B-COMMIT-GRANT-CONSUMPTION",),
    "grant_consumed", "grant_consumption_ack", "grant_registry_generation",
    "grant_registry_state", "parent_receipts", "phase",
)
_require_writes(
    ("STORE-002C-RETIRE-GRANT-NONCE",),
    "grant_consumption_ack", "grant_registry_generation", "grant_registry_state",
    "parent_receipts",
)
_require_writes(
    ("EXT-003-DELIVER-PRODUCER-GRANT",),
    "parent_receipts", "phase", "producer_grant", "producer_status",
)
_require_writes(
    ("SUP-004-START-PRODUCER",),
    "active_child", "parent_receipts", "phase", "producer_start_binding",
    "producer_status",
)
_require_writes(
    (
        "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
        "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B",
        "CHILD-006-ATTACH-PRODUCER-RESOURCE",
        "CHILD-007-ATTACH-PRODUCER-INTERNAL",
        "CHILD-008-ATTACH-PRODUCER-ABANDONED",
    ),
    "active_child", "parent_receipts", "phase", "producer_attachment",
    "producer_certificate", "producer_status",
)
_require_writes(
    ("EXT-009-DELIVER-CHECKER-GRANT",),
    "checker_grant", "checker_status", "parent_receipts", "phase",
)
_require_writes(
    ("SUP-010-START-CHECKER",),
    "active_child", "checker_start_binding", "checker_status",
    "parent_receipts", "phase",
)
_require_writes(
    (
        "CHILD-011-ATTACH-CHECKER-ACCEPT",
        "CHILD-012-ATTACH-CHECKER-REJECT",
        "CHILD-013-ATTACH-CHECKER-RESOURCE",
        "CHILD-014-ATTACH-CHECKER-INTERNAL",
        "CHILD-015-ATTACH-CHECKER-ABANDONED",
    ),
    "active_child", "checker_attachment", "checker_certificate",
    "checker_status", "parent_receipts", "phase",
)
_require_writes(
    ("SUP-016-SEAL-PARENT-EVIDENCE",),
    "parent_evidence_root", "parent_ledger", "parent_receipts", "phase",
)
_require_writes(
    ("SUP-017-DECIDE-LOCAL-DISPOSITION",),
    "local_capsule", "local_disposition", "phase",
)
_require_writes(
    ("SUP-018-PREPARE-LOCAL-PUBLICATION",),
    "phase", "publication", "publication_commitment",
)
_require_writes(
    ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
    "store_controller_generation", "store_fence_ack",
)
_require_writes(
    ("EXT-018C-ADVANCE-STORE-HEAD",),
    "store_head",
)
_require_writes(
    ("GRD-018B-REAUTHORIZE-PUBLICATION",),
    "phase", "publication", "publication_commitment",
)
_require_writes(
    ("STORE-019-DURABLE-ACK",),
    "durable_ack", "phase", "publication",
)
_require_writes(("STORE-019A-ACK-OLD-PRE-FENCE",), "durable_ack")
_require_writes(
    ("STORE-020-PUBLISH-CAS",),
    "phase", "publication", "publication_ack", "store_head",
)
_require_writes(
    ("STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS",),
    "phase", "publication", "publication_ack", "store_head",
)
_require_writes(
    ("ADV-020A-DELAYED-POST-OWNER-PUBLISH",),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_require_writes(
    ("ADV-020C-ATTEMPT-SUPERSEDED-PUBLICATION",),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_require_writes(
    ("STORE-021-HEAD-CONFLICT",),
    "phase", "publication",
)
_require_writes(
    ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    "controller", "primary_state", "recovery_receipts",
)
_require_writes(
    ("EXT-023-OWNER-FAILURE",),
    "owner_failure_notice", "owner_failure_phase", "owner_state", "phase",
    "publication",
)
_require_writes(
    ("GRD-023B-FENCE-AFTER-OWNER-FAILURE",),
    "controller", "primary_state", "recovery_receipts",
)
_require_writes(
    ("CHILD-024-ATTACH-ACTIVE-ABANDONED",),
    "active_child", "parent_receipts",
)
_require_writes(
    ("EXT-024A-RETIRE-PRODUCER-GRANT",),
    "parent_receipts", "producer_retirement", "producer_status",
)
_require_writes(
    ("EXT-024B-RETIRE-CHECKER-GRANT",),
    "checker_retirement", "checker_status", "parent_receipts",
)
_require_writes(
    ("GRD-025-PREPARE-ABANDONMENT",),
    "abandonment_commitment",
)
_require_writes(
    ("STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",),
    "abandonment_ack", "phase", "publication", "store_head",
)
_require_writes(
    ("STORE-026B-TOMBSTONE-HEAD-CONFLICT",),
    "abandonment_conflict_notice", "assurance_breach", "phase", "publication",
)
_require_writes(
    ("ADV-027-REPLAY-GRANT", "ADV-028-ROLLBACK-PUBLICATION"),
    "attempted_attack_contexts", "pending_attack", "pending_attack_context",
    "store_attack_attempts", "store_security_events",
)
_require_writes(
    ("STORE-029-REJECT-HOSTILE-REQUEST",),
    "pending_attack", "pending_attack_context", "store_attack_rejections",
    "store_security_events",
)
_require_writes(
    ("ADV-029B-SUCCEED-STORE-BYPASS",),
    "assurance_breach", "pending_attack", "pending_attack_context", "phase",
    "publication",
)
_require_writes(("ADV-030-STALL",))
_require_writes(
    ("ADV-031-FAIL-GUARDIAN",),
    "assurance_breach", "guardian_state", "phase", "publication",
)

if (
    set(ACTION_WRITE_FIELDS) != set(ACTION_SPECS)
    or set(ACTION_REQUIRED_WRITE_FIELDS) != set(ACTION_SPECS)
    or any(
        not ACTION_REQUIRED_WRITE_FIELDS[action_id]
        <= ACTION_WRITE_FIELDS[action_id]
        for action_id in ACTION_SPECS
    )
):
    raise RuntimeError(
        "orchestrator action effect policies do not exactly cover the action registry"
    )


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


def _parent_prefix_hash_at(
    state: OrchestratorState,
    receipt_count: int,
) -> str:
    if state.parent_grant is None or not 0 <= receipt_count <= len(
        state.parent_receipts
    ):
        return ""
    if receipt_count == 0:
        return _parent_genesis(state.parent_grant)
    return parent_receipt_hash(state.parent_receipts[receipt_count - 1])


def _parent_phase_at_receipt_count(
    state: OrchestratorState,
    receipt_count: int,
) -> str | None:
    """Reconstruct the parent phase represented by an authenticated prefix."""
    if state.parent_grant is None or not 0 <= receipt_count <= len(
        state.parent_receipts
    ):
        return None
    phase = "GRANT_AVAILABLE"
    for receipt in state.parent_receipts[:receipt_count]:
        kind = receipt.kind
        if kind == "PARENT_GRANT_CONSUME_REQUESTED":
            if phase != "GRANT_AVAILABLE":
                return None
            phase = "GRANT_CONSUME_PENDING"
        elif kind == "PARENT_GRANT_CONSUMED":
            if phase != "GRANT_CONSUME_PENDING":
                return None
            phase = "PARENT_ACTIVE"
        elif kind == "PRODUCER_GRANT_ACCEPTED":
            if phase != "PARENT_ACTIVE":
                return None
            phase = "PRODUCER_GRANT_AVAILABLE"
        elif kind == "PRODUCER_STARTED":
            if phase != "PRODUCER_GRANT_AVAILABLE":
                return None
            phase = "PRODUCER_RUNNING"
        elif kind == "PRODUCER_CERT_ATTACHED":
            if phase == "ABANDONING":
                continue
            if phase != "PRODUCER_RUNNING" or state.producer_certificate is None:
                return None
            phase = (
                "PRODUCER_ATTACHED"
                if state.producer_certificate.local_decision
                == "LOCAL_SYNTACTIC_CANDIDATE"
                else "CHILDREN_COMPLETE"
            )
        elif kind == "CHECKER_GRANT_ACCEPTED":
            if phase != "PRODUCER_ATTACHED":
                return None
            phase = "CHECKER_GRANT_AVAILABLE"
        elif kind == "CHECKER_STARTED":
            if phase != "CHECKER_GRANT_AVAILABLE":
                return None
            phase = "CHECKER_RUNNING"
        elif kind == "CHECKER_CERT_ATTACHED":
            if phase == "ABANDONING":
                continue
            if phase != "CHECKER_RUNNING":
                return None
            phase = "CHILDREN_COMPLETE"
        elif kind == "OWNER_FAILURE_OBSERVED":
            if phase in {"WAIT_GRANT", "TERMINAL", "ASSURANCE_BREACHED"}:
                return None
            phase = "ABANDONING"
        elif kind in {
            "PARENT_GRANT_RETIRED",
            "PRODUCER_GRANT_RETIRED",
            "CHECKER_GRANT_RETIRED",
        }:
            if phase != "ABANDONING":
                return None
        elif kind == "PRIMARY_FAILOVER":
            if phase in {"WAIT_GRANT", "TERMINAL", "ASSURANCE_BREACHED"}:
                return None
        elif kind == "PARENT_EVIDENCE_SEAL":
            if phase == "ABANDONING":
                continue
            if phase != "CHILDREN_COMPLETE":
                return None
            phase = "PARENT_SEALED"
        else:
            return None
    return phase


def _sealed_phase_at_controller_generation(
    state: OrchestratorState,
    generation: int,
) -> str | None:
    """Recover the latest sealed phase attributable to a controller generation."""
    if generation not in {0, 1}:
        return None
    capsule = state.local_capsule
    if capsule is None or capsule.controller_generation > generation:
        return "PARENT_SEALED"

    attempts: list[tuple[PublicationCommitment, DurableAck | None]] = [
        (item.commitment, item.durable_ack)
        for item in state.superseded_publications
        if item.commitment.controller_generation <= generation
    ]
    if (
        state.publication_commitment is not None
        and state.publication_commitment.controller_generation <= generation
    ):
        attempts.append((state.publication_commitment, state.durable_ack))
    if not attempts:
        return "LOCAL_DECIDED"
    commitment, durable_ack = max(
        attempts,
        key=lambda item: item[0].controller_generation,
    )
    durable_before_generation = bool(
        durable_ack is not None
        and durable_ack.observation_generation <= generation
    )
    return "DURABLE" if durable_before_generation else "PREPARED"


def _sealed_owner_failure_phase(state: OrchestratorState) -> str | None:
    notice = state.owner_failure_notice
    if (
        state.parent_ledger != "SEALED"
        or notice is None
        or not _owner_failure_snapshot_wf(state, notice)
    ):
        return None
    # A sealed parent ledger cannot append OWNER_FAILURE_OBSERVED.  The
    # authenticated notice therefore carries the exact pre-failure snapshot;
    # never infer that historical phase from artifacts changed by later
    # recovery, store fencing, or abandonment.
    return notice.observed_phase


def _grant_registry_projection_at_prefix(
    state: OrchestratorState,
    receipt_count: int,
) -> tuple[str, int] | None:
    grant = state.parent_grant
    if grant is None or not 0 <= receipt_count <= len(state.parent_receipts):
        return None
    kinds = {
        receipt.kind for receipt in state.parent_receipts[:receipt_count]
    }
    if "PARENT_GRANT_RETIRED" in kinds:
        return ("RETIRED", grant.issuance_generation + 1)
    if "PARENT_GRANT_CONSUMED" in kinds:
        return ("CONSUMED", grant.issuance_generation + 1)
    if "PARENT_GRANT_CONSUME_REQUESTED" in kinds:
        return ("PENDING", grant.issuance_generation)
    return ("ISSUED", grant.issuance_generation)


def _store_attack_context_history_wf(
    state: OrchestratorState,
    context: StoreAttackContext,
) -> bool:
    """Bind an attack snapshot to the historical parent projection it names."""
    grant = state.parent_grant
    if grant is None:
        return False
    if context.parent_prefix_hash != _parent_prefix_hash_at(
        state,
        context.parent_receipt_count,
    ):
        return False
    prefix_phase = _parent_phase_at_receipt_count(
        state,
        context.parent_receipt_count,
    )
    registry_projection = _grant_registry_projection_at_prefix(
        state,
        context.parent_receipt_count,
    )
    if prefix_phase is None or registry_projection is None:
        return False
    if not (
        context.parent_run_id == grant.parent_run_id
        and context.binding_digest == parent_binding_digest(grant)
        and context.grant_nonce == grant.nonce
        and context.grant_registry_id == grant.issuance_registry_id
        and (
            context.grant_registry_state,
            context.grant_registry_generation,
        )
        == registry_projection
        and context.expected_publication_generation
        == grant.expected_publication_generation
    ):
        return False

    prefix = state.parent_receipts[: context.parent_receipt_count]
    owner_failed_in_prefix = any(
        receipt.kind == "OWNER_FAILURE_OBSERVED" for receipt in prefix
    )
    failover_in_prefix = any(
        receipt.kind == "PRIMARY_FAILOVER" for receipt in prefix
    )
    sealed_prefix = prefix_phase == "PARENT_SEALED"

    if owner_failed_in_prefix:
        if not (
            context.owner_state == "FAILED"
            and state.owner_failure_notice is not None
            and context.owner_failure_notice_digest
            == _owner_failure_digest(state.owner_failure_notice)
        ):
            return False
    elif sealed_prefix and context.owner_failure_notice_digest:
        if not (
            context.owner_state == "FAILED"
            and state.owner_failure_notice is not None
            and context.owner_failure_notice_digest
            == _owner_failure_digest(state.owner_failure_notice)
        ):
            return False
    elif context.owner_state != "ACTIVE" or context.owner_failure_notice_digest:
        return False

    if failover_in_prefix:
        expected_recovery_generation = 1
    elif sealed_prefix and context.recovery_generation == 1:
        if not (
            state.recovery_receipts
            and state.recovery_receipts[0].parent_prefix_hash
            == context.parent_prefix_hash
        ):
            return False
        expected_recovery_generation = 1
    else:
        expected_recovery_generation = 0
    if not (
        context.recovery_generation == expected_recovery_generation
        and context.primary_state
        == ("FAILED" if expected_recovery_generation else "ACTIVE")
        and context.controller
        == (
            "RECOVERY_GUARDIAN"
            if expected_recovery_generation
            else "PRIMARY_SUPERVISOR"
        )
    ):
        return False

    if context.local_capsule_digest:
        if not (
            state.local_capsule is not None
            and context.local_capsule_digest
            == state.local_capsule.capsule_digest
            and context.local_disposition == state.local_capsule.local_disposition
        ):
            return False
    elif context.local_disposition != "NONE":
        return False

    if sealed_prefix:
        if context.owner_state == "FAILED":
            expected_phase = "ABANDONING"
        else:
            expected_phase = {
                "FENCE_PENDING": "PUBLICATION_FENCE_PENDING",
                "FENCED": "PUBLICATION_FENCED",
                "PREPARED": "PREPARED",
                "DURABLE": "DURABLE",
                "NONE": (
                    "LOCAL_DECIDED"
                    if context.local_capsule_digest
                    else "PARENT_SEALED"
                ),
            }.get(context.publication)
    else:
        expected_phase = prefix_phase
    if context.phase != expected_phase:
        return False

    known_attempts = [
        (item.commitment, item.durable_ack)
        for item in state.superseded_publications
    ]
    if state.publication_commitment is not None:
        known_attempts.append(
            (state.publication_commitment, state.durable_ack)
        )
    matching_attempt = next(
        (
            (commitment, durable_ack)
            for commitment, durable_ack in known_attempts
            if commitment.commitment_digest
            == context.publication_commitment_digest
            and commitment.controller_generation
            == context.publication_commitment_controller_generation
        ),
        None,
    )
    if context.publication_commitment_digest:
        if matching_attempt is None:
            return False
        _, historical_ack = matching_attempt
        if context.durable_ack_auth_tag and (
            historical_ack is None
            or historical_ack.auth_tag != context.durable_ack_auth_tag
        ):
            return False
    elif context.durable_ack_auth_tag:
        return False

    if (
        context.store_head.content_kind != "EMPTY"
        and context.store_head != state.store_head
    ):
        return False
    if context.store_controller_generation > state.store_controller_generation:
        return False
    if context.store_fence_ack_auth_tag:
        if not (
            state.store_fence_ack is not None
            and context.store_fence_ack_auth_tag
            == state.store_fence_ack.auth_tag
        ):
            return False
    if context.superseded_commitment_digest:
        if not any(
            item.commitment.commitment_digest
            == context.superseded_commitment_digest
            and item.supersession_digest == context.supersession_digest
            for item in state.superseded_publications
        ):
            return False
    return True


def _store_security_genesis(grant: ParentGrant) -> str:
    return child.digest(
        "STORE_SECURITY_GENESIS",
        grant.parent_run_id,
        parent_binding_digest(grant),
    )


def _make_store_attack_context(
    state: OrchestratorState,
    attack: str,
) -> StoreAttackContext:
    grant = state.parent_grant
    head = state.store_head
    if grant is None or head is None:
        raise OrchestratorReject("F05-ORCH-ATTACK-CONTEXT-NO-GRANT", attack)
    if attack not in STORE_ATTACK_SPECS:
        raise OrchestratorReject("F05-ORCH-ATTACK-CONTEXT-KIND", attack)
    commitment = state.publication_commitment
    superseded = (
        state.superseded_publications[-1]
        if state.superseded_publications
        else None
    )
    partial = StoreAttackContext(
        schema=SCHEMA,
        parent_run_id=grant.parent_run_id,
        binding_digest=parent_binding_digest(grant),
        parent_receipt_count=len(state.parent_receipts),
        parent_prefix_hash=_last_parent_hash(state),
        attack=attack,
        phase=state.phase,
        owner_state=state.owner_state,
        primary_state=state.primary_state,
        controller=state.controller,
        recovery_generation=len(state.recovery_receipts),
        store_controller_generation=state.store_controller_generation,
        grant_nonce=grant.nonce,
        grant_registry_id=grant.issuance_registry_id,
        grant_registry_state=state.grant_registry_state,
        grant_registry_generation=state.grant_registry_generation,
        expected_publication_generation=(
            grant.expected_publication_generation
        ),
        local_disposition=state.local_disposition,
        local_capsule_digest=(
            state.local_capsule.capsule_digest if state.local_capsule else ""
        ),
        publication=state.publication,
        publication_commitment_digest=(
            commitment.commitment_digest if commitment else ""
        ),
        publication_commitment_controller_generation=(
            commitment.controller_generation if commitment else -1
        ),
        durable_ack_auth_tag=(
            state.durable_ack.auth_tag if state.durable_ack else ""
        ),
        store_head=head,
        store_fence_ack_auth_tag=(
            state.store_fence_ack.auth_tag if state.store_fence_ack else ""
        ),
        owner_failure_notice_digest=(
            _owner_failure_digest(state.owner_failure_notice)
            if state.owner_failure_notice
            else ""
        ),
        superseded_commitment_digest=(
            superseded.commitment.commitment_digest if superseded else ""
        ),
        supersession_digest=(
            superseded.supersession_digest if superseded else ""
        ),
        context_digest="",
    )
    return replace(
        partial,
        context_digest=_store_attack_context_digest(partial),
    )


def _store_attack_context_wf(context: StoreAttackContext) -> bool:
    if not (
        context.schema == SCHEMA
        and bool(context.parent_run_id)
        and bool(context.binding_digest)
        and context.parent_receipt_count >= 0
        and bool(context.parent_prefix_hash)
        and context.attack in STORE_ATTACK_SPECS
        and context.phase in PHASES
        and context.owner_state in OWNER_STATES
        and context.primary_state in PRIMARY_STATES
        and context.controller in CONTROLLERS
        and context.recovery_generation in {0, 1}
        and 0
        <= context.store_controller_generation
        <= context.recovery_generation
        and bool(context.grant_nonce)
        and bool(context.grant_registry_id)
        and context.grant_registry_state in GRANT_REGISTRY_STATES
        and context.grant_registry_generation >= 0
        and context.expected_publication_generation >= 0
        and context.local_disposition in LOCAL_DISPOSITIONS
        and context.publication in PUBLICATIONS
        and _store_head_wf(
            context.store_head,
            context.expected_publication_generation,
        )
    ):
        return False
    if bool(context.local_capsule_digest) != (
        context.local_disposition != "NONE"
    ):
        return False
    if context.store_head.controller_generation > context.store_controller_generation:
        return False
    if (context.primary_state == "ACTIVE") != (
        context.controller == "PRIMARY_SUPERVISOR"
        and context.recovery_generation == 0
    ):
        return False
    if context.primary_state == "FAILED" and not (
        context.controller == "RECOVERY_GUARDIAN"
        and context.recovery_generation == 1
    ):
        return False
    has_commitment = bool(context.publication_commitment_digest)
    if has_commitment != (
        context.publication_commitment_controller_generation in {0, 1}
    ):
        return False
    if context.durable_ack_auth_tag and not has_commitment:
        return False
    if bool(context.owner_failure_notice_digest) != (
        context.owner_state == "FAILED"
    ):
        return False
    if bool(context.store_fence_ack_auth_tag) != (
        context.store_controller_generation > 0
    ):
        return False
    if bool(context.superseded_commitment_digest) != bool(
        context.supersession_digest
    ):
        return False
    if context.context_digest != _store_attack_context_digest(
        replace(context, context_digest="")
    ):
        return False
    if context.publication in TERMINAL_PUBLICATIONS:
        return False
    phase_publication_pairs = {
        "PREPARED": "PREPARED",
        "DURABLE": "DURABLE",
        "PUBLICATION_FENCE_PENDING": "FENCE_PENDING",
        "PUBLICATION_FENCED": "FENCED",
        "ABANDONING": "ABANDONING",
    }
    expected_publication = phase_publication_pairs.get(context.phase)
    if expected_publication is not None:
        if context.publication != expected_publication:
            return False
    elif context.publication != "NONE":
        return False
    if context.publication == "NONE" and (has_commitment or context.durable_ack_auth_tag):
        return False
    if context.publication == "PREPARED" and (
        not has_commitment or context.durable_ack_auth_tag
    ):
        return False
    if context.publication == "DURABLE" and not (
        has_commitment and context.durable_ack_auth_tag
    ):
        return False
    if context.publication == "FENCE_PENDING" and not has_commitment:
        return False
    if context.publication == "FENCED" and (
        has_commitment
        or context.durable_ack_auth_tag
        or not context.superseded_commitment_digest
        or not context.store_fence_ack_auth_tag
    ):
        return False
    if context.publication == "ABANDONING" and context.owner_state != "FAILED":
        return False
    if context.attack == "GRANT_REPLAY":
        return True
    if context.attack == "PUBLICATION_ROLLBACK":
        return context.publication in {"PREPARED", "DURABLE"} and has_commitment
    if context.attack == "POST_OWNER_PUBLISH":
        return bool(
            context.owner_state == "FAILED"
            and context.publication == "ABANDONING"
            and has_commitment
            and context.owner_failure_notice_digest
        )
    return bool(
        context.attack == "SUPERSEDED_PUBLICATION"
        and context.superseded_commitment_digest
        and context.supersession_digest
        and context.store_controller_generation
        == context.recovery_generation
        and context.store_fence_ack_auth_tag
    )


def _append_store_security_event(
    state: OrchestratorState,
    actor: str,
    event_kind: str,
    attack: str,
) -> OrchestratorState:
    if state.parent_grant is None:
        raise OrchestratorReject("F05-ORCH-STORE-SECURITY-NO-GRANT", attack)
    expected_actor = {
        "ATTEMPT": "ADVERSARY",
        "REJECTED": "DURABLE_STORE",
    }.get(event_kind)
    if actor != expected_actor or attack not in STORE_ATTACK_SPECS:
        raise OrchestratorReject(
            "F05-ORCH-STORE-SECURITY-ACTOR",
            f"{event_kind}:{actor}:{attack}",
        )
    context = (
        _make_store_attack_context(state, attack)
        if event_kind == "ATTEMPT"
        else state.pending_attack_context
    )
    if context is None or not _store_attack_context_wf(context):
        raise OrchestratorReject("F05-ORCH-ATTACK-CONTEXT-ABSENT", attack)
    key = StoreAttackKey(attack, context.context_digest)
    if (
        event_kind == "ATTEMPT"
        and state.attempted_attack_contexts.count(key)
        >= MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT
    ):
        raise OrchestratorReject("F05-ORCH-ATTACK-CONTEXT-REPEAT", attack)
    if event_kind == "REJECTED" and (
        state.pending_attack != attack
        or state.pending_attack_context != context
    ):
        raise OrchestratorReject("F05-ORCH-ATTACK-CONTEXT-MISMATCH", attack)
    attempt = (
        len(state.store_attack_attempts) + 1
        if event_kind == "ATTEMPT"
        else len(state.store_attack_rejections) + 1
    )
    previous_hash = (
        store_security_hash(state.store_security_events[-1])
        if state.store_security_events
        else _store_security_genesis(state.parent_grant)
    )
    event = StoreSecurityEvent(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        sequence=len(state.store_security_events) + 1,
        attempt=attempt,
        event_kind=event_kind,
        attack=attack,
        context=context,
        context_digest=context.context_digest,
        issuer=actor,
        previous_hash=previous_hash,
        auth_tag="",
    )
    event = replace(event, auth_tag=_store_security_auth(event))
    attempts = state.store_attack_attempts
    contexts = state.attempted_attack_contexts
    rejections = state.store_attack_rejections
    if event_kind == "ATTEMPT":
        attempts += (attack,)
        contexts += (key,)
    else:
        rejections += (attack,)
    return replace(
        state,
        store_attack_attempts=attempts,
        attempted_attack_contexts=contexts,
        store_attack_rejections=rejections,
        store_security_events=state.store_security_events + (event,),
    )


def store_security_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return not (
            state.store_attack_attempts
            or state.attempted_attack_contexts
            or state.store_attack_rejections
            or state.store_security_events
            or state.pending_attack != "NONE"
            or state.pending_attack_context
        )
    previous_hash = _store_security_genesis(state.parent_grant)

    attempts: list[str] = []
    contexts: list[StoreAttackKey] = []
    attempt_contexts: list[StoreAttackContext] = []
    rejections: list[str] = []
    for sequence, event in enumerate(state.store_security_events, start=1):
        expected_issuer = {
            "ATTEMPT": "ADVERSARY",
            "REJECTED": "DURABLE_STORE",
        }.get(event.event_kind)
        if not (
            expected_issuer
            and event.schema == SCHEMA
            and event.parent_run_id == state.parent_grant.parent_run_id
            and event.binding_digest == parent_binding_digest(state.parent_grant)
            and event.sequence == sequence
            and event.attack in STORE_ATTACK_SPECS
            and _store_attack_context_wf(event.context)
            and event.context.attack == event.attack
            and event.context.parent_run_id == event.parent_run_id
            and event.context.binding_digest == event.binding_digest
            and _store_attack_context_history_wf(state, event.context)
            and event.context_digest == event.context.context_digest
            and event.issuer == expected_issuer
            and event.previous_hash == previous_hash
            and event.auth_tag == _store_security_auth(replace(event, auth_tag=""))
        ):
            return False
        key = StoreAttackKey(event.attack, event.context_digest)
        if event.event_kind == "ATTEMPT":
            if (
                len(attempts) != len(rejections)
                or event.attempt != len(attempts) + 1
                or contexts.count(key)
                >= MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT
            ):
                return False
            attempts.append(event.attack)
            contexts.append(key)
            attempt_contexts.append(event.context)
        else:
            if (
                len(attempts) != len(rejections) + 1
                or event.attempt != len(rejections) + 1
                or event.attack != attempts[-1]
                or key != contexts[-1]
                or event.context != attempt_contexts[-1]
            ):
                return False
            rejections.append(event.attack)
        previous_hash = store_security_hash(event)
    if (
        tuple(attempts) != state.store_attack_attempts
        or tuple(contexts) != state.attempted_attack_contexts
        or tuple(rejections) != state.store_attack_rejections
    ):
        return False
    if state.pending_attack != "NONE":
        return (
            len(attempts) == len(rejections) + 1
            and attempts[-1] == state.pending_attack
            and state.pending_attack_context is not None
            and attempt_contexts[-1] == state.pending_attack_context
            and contexts[-1]
            == StoreAttackKey(
                state.pending_attack,
                state.pending_attack_context.context_digest,
            )
            and state.assurance_breach == "NONE"
        )
    if state.pending_attack_context is not None:
        return False
    attack_breach = next(
        (
            attack
            for attack, spec in STORE_ATTACK_SPECS.items()
            if spec.breach == state.assurance_breach
        ),
        None,
    )
    if attack_breach:
        if not (
            len(attempts) == len(rejections) + 1
            and attempts[-1] == attack_breach
        ):
            return False
        return True
    return len(attempts) == len(rejections)


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
    active_controller = "PRIMARY_SUPERVISOR"
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
        if receipt.kind == "PRIMARY_FAILOVER":
            if (
                active_controller != "PRIMARY_SUPERVISOR"
                or receipt.issuer != "RECOVERY_GUARDIAN"
            ):
                return False
            active_controller = "RECOVERY_GUARDIAN"
        elif receipt.issuer in CONTROLLERS and receipt.issuer != active_controller:
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
    if state.producer_start_binding:
        expected_payloads["PRODUCER_STARTED"] = (
            state.producer_start_binding.start_digest
        )
    if state.producer_attachment:
        expected_payloads["PRODUCER_CERT_ATTACHED"] = (
            state.producer_attachment.attachment_digest
        )
    if state.producer_retirement:
        expected_payloads["PRODUCER_GRANT_RETIRED"] = (
            state.producer_retirement.retirement_digest
        )
    if state.checker_grant:
        expected_payloads["CHECKER_GRANT_ACCEPTED"] = child.grant_binding_digest(state.checker_grant)
    if state.checker_start_binding:
        expected_payloads["CHECKER_STARTED"] = (
            state.checker_start_binding.start_digest
        )
    if state.checker_attachment:
        expected_payloads["CHECKER_CERT_ATTACHED"] = (
            state.checker_attachment.attachment_digest
        )
    if state.checker_retirement:
        expected_payloads["CHECKER_GRANT_RETIRED"] = (
            state.checker_retirement.retirement_digest
        )
    owner_failure_receipts = [
        receipt
        for receipt in state.parent_receipts
        if receipt.kind == "OWNER_FAILURE_OBSERVED"
    ]
    if owner_failure_receipts:
        if (
            len(owner_failure_receipts) != 1
            or state.owner_state != "FAILED"
            or state.owner_failure_notice is None
            or owner_failure_receipts[0].payload
            != _owner_failure_digest(state.owner_failure_notice)
        ):
            return False
    if state.owner_state == "FAILED" and state.parent_ledger == "OPEN":
        if len(owner_failure_receipts) != 1:
            return False
    if state.owner_state == "ACTIVE" and owner_failure_receipts:
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
        "PRODUCER_STARTED": state.producer_start_binding is not None,
        "PRODUCER_CERT_ATTACHED": state.producer_attachment is not None,
        "PRODUCER_GRANT_RETIRED": state.producer_retirement is not None,
        "CHECKER_GRANT_ACCEPTED": state.checker_grant is not None,
        "CHECKER_STARTED": state.checker_start_binding is not None,
        "CHECKER_CERT_ATTACHED": state.checker_attachment is not None,
        "CHECKER_GRANT_RETIRED": state.checker_retirement is not None,
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
        ("PRODUCER_GRANT_ACCEPTED", "PRODUCER_STARTED"),
        ("PRODUCER_STARTED", "PRODUCER_CERT_ATTACHED"),
        ("PRODUCER_CERT_ATTACHED", "CHECKER_GRANT_ACCEPTED"),
        ("CHECKER_GRANT_ACCEPTED", "CHECKER_STARTED"),
        ("CHECKER_STARTED", "CHECKER_CERT_ATTACHED"),
        ("OWNER_FAILURE_OBSERVED", "PRODUCER_GRANT_RETIRED"),
        ("OWNER_FAILURE_OBSERVED", "CHECKER_GRANT_RETIRED"),
        ("PRODUCER_GRANT_ACCEPTED", "PRODUCER_GRANT_RETIRED"),
        ("CHECKER_GRANT_ACCEPTED", "CHECKER_GRANT_RETIRED"),
    )
    for before, after in causal_pairs:
        if after in positions and not ordered(before, after):
            return False
    provenance = (
        ("PRODUCER_STARTED", state.producer_start_binding),
        ("PRODUCER_CERT_ATTACHED", state.producer_attachment),
        ("PRODUCER_GRANT_RETIRED", state.producer_retirement),
        ("CHECKER_STARTED", state.checker_start_binding),
        ("CHECKER_CERT_ATTACHED", state.checker_attachment),
        ("CHECKER_GRANT_RETIRED", state.checker_retirement),
    )
    for kind, value in provenance:
        if value is None:
            continue
        receipts = [item for item in state.parent_receipts if item.kind == kind]
        if len(receipts) != 1 or value.parent_prefix_hash != receipts[0].previous_hash:
            return False
    failover_position = positions.get("PRIMARY_FAILOVER")

    def creation_generation(kind: str) -> int:
        position = positions[kind]
        return int(
            failover_position is not None
            and position > failover_position
        )

    for kind, binding in (
        ("PRODUCER_STARTED", state.producer_start_binding),
        ("CHECKER_STARTED", state.checker_start_binding),
    ):
        if binding is None:
            continue
        receipt = state.parent_receipts[positions[kind]]
        if (
            binding.controller_generation != creation_generation(kind)
            or binding.issuer != receipt.issuer
        ):
            return False
    for kind, attachment, start in (
        (
            "PRODUCER_CERT_ATTACHED",
            state.producer_attachment,
            state.producer_start_binding,
        ),
        (
            "CHECKER_CERT_ATTACHED",
            state.checker_attachment,
            state.checker_start_binding,
        ),
    ):
        if attachment is None:
            continue
        if (
            start is None
            or attachment.parent_controller_generation
            != creation_generation(kind)
            or attachment.parent_controller_generation
            < start.controller_generation
        ):
            return False
    for kind, retirement in (
        ("PRODUCER_GRANT_RETIRED", state.producer_retirement),
        ("CHECKER_GRANT_RETIRED", state.checker_retirement),
    ):
        if retirement is not None and (
            retirement.controller_generation != creation_generation(kind)
        ):
            return False
    for kind, attachment in (
        ("PRODUCER_CERT_ATTACHED", state.producer_attachment),
        ("CHECKER_CERT_ATTACHED", state.checker_attachment),
    ):
        if attachment is None:
            continue
        attached_after_owner_failure = ordered("OWNER_FAILURE_OBSERVED", kind)
        expected_failure_digest = (
            _owner_failure_digest(state.owner_failure_notice)
            if attached_after_owner_failure and state.owner_failure_notice is not None
            else ""
        )
        if attachment.owner_failure_notice_digest != expected_failure_digest:
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


def _owner_failure_snapshot_wf(
    state: OrchestratorState,
    notice: OwnerFailureNotice,
) -> bool:
    """Cross-check the signed pre-failure snapshot against retained evidence."""
    expected_publication = {
        "PREPARED": "PREPARED",
        "DURABLE": "DURABLE",
        "PUBLICATION_FENCE_PENDING": "FENCE_PENDING",
        "PUBLICATION_FENCED": "FENCED",
    }.get(notice.observed_phase, "NONE")
    if notice.publication_at_failure != expected_publication:
        return False

    capsule_phases = {
        "LOCAL_DECIDED",
        "PREPARED",
        "DURABLE",
        "PUBLICATION_FENCE_PENDING",
        "PUBLICATION_FENCED",
    }
    if bool(notice.local_capsule_digest_at_failure) != (
        notice.observed_phase in capsule_phases
    ):
        return False
    if notice.local_capsule_digest_at_failure and not (
        state.local_capsule is not None
        and notice.local_capsule_digest_at_failure
        == state.local_capsule.capsule_digest
    ):
        return False

    generation = notice.store_controller_generation_at_failure
    if not (
        generation in {0, 1}
        and generation <= state.store_controller_generation
        and generation <= len(state.recovery_receipts)
    ):
        return False
    if notice.observed_phase == "PUBLICATION_FENCE_PENDING" and generation != 0:
        return False
    if notice.observed_phase == "PUBLICATION_FENCED" and generation != 1:
        return False

    fence_auth = notice.store_fence_ack_auth_at_failure
    if bool(fence_auth) != (generation == 1):
        return False
    if fence_auth and not (
        state.store_fence_ack is not None
        and state.store_fence_ack.auth_tag == fence_auth
        and state.store_fence_ack.new_controller_generation == generation
    ):
        return False

    commitments = tuple(
        value
        for value in (
            state.publication_commitment,
            *(item.commitment for item in state.superseded_publications),
        )
        if value is not None
    )
    commitment_digest = notice.publication_commitment_digest_at_failure
    commitment_required = notice.publication_at_failure in {
        "PREPARED",
        "DURABLE",
        "FENCE_PENDING",
    }
    if bool(commitment_digest) != commitment_required:
        return False
    matching_commitment = next(
        (
            value
            for value in commitments
            if value.commitment_digest == commitment_digest
        ),
        None,
    )
    if commitment_digest and not (
        matching_commitment is not None
        and matching_commitment.controller_generation == generation
    ):
        return False

    durable_acks = tuple(
        value
        for value in (
            state.durable_ack,
            *(item.durable_ack for item in state.superseded_publications),
        )
        if value is not None
    )
    durable_auth = notice.durable_ack_auth_at_failure
    if notice.publication_at_failure == "DURABLE" and not durable_auth:
        return False
    if (
        notice.publication_at_failure not in {"DURABLE", "FENCE_PENDING"}
        and durable_auth
    ):
        return False
    matching_durable_ack = next(
        (value for value in durable_acks if value.auth_tag == durable_auth),
        None,
    )
    if durable_auth and not (
        matching_durable_ack is not None
        and matching_durable_ack.commitment_digest == commitment_digest
        and matching_durable_ack.controller_generation == generation
    ):
        return False
    return True


def owner_failure_wf(state: OrchestratorState) -> bool:
    notice = state.owner_failure_notice
    if state.owner_state == "ACTIVE":
        return notice is None and state.owner_failure_phase == "NONE"
    if state.parent_grant is None or notice is None:
        return False
    if not (
        notice.schema == SCHEMA
        and notice.parent_run_id == state.parent_grant.parent_run_id
        and notice.binding_digest == parent_binding_digest(state.parent_grant)
        and notice.observed_phase in PHASES - {"WAIT_GRANT", "TERMINAL", "ASSURANCE_BREACHED"}
        and state.owner_failure_phase == notice.observed_phase
        and bool(notice.parent_prefix_hash)
        and notice.issuer == "EXTERNAL_OWNER"
        and notice.auth_tag == _owner_failure_auth(replace(notice, auth_tag=""))
    ):
        return False
    if not _owner_failure_snapshot_wf(state, notice):
        return False
    owner_receipts = [
        receipt
        for receipt in state.parent_receipts
        if receipt.kind == "OWNER_FAILURE_OBSERVED"
    ]
    if owner_receipts:
        owner_position = state.parent_receipts.index(owner_receipts[0])
        expected_phase = _parent_phase_at_receipt_count(
            state,
            owner_position,
        )
        return (
            len(owner_receipts) == 1
            and expected_phase is not None
            and notice.observed_phase == expected_phase
            and notice.parent_prefix_hash == owner_receipts[0].previous_hash
            and owner_receipts[0].payload == _owner_failure_digest(notice)
        )
    expected_phase = _sealed_owner_failure_phase(state)
    return (
        state.parent_ledger == "SEALED"
        and notice.parent_prefix_hash == state.parent_evidence_root
        and expected_phase is not None
        and notice.observed_phase == expected_phase
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


def _controller_generation_wf(
    state: OrchestratorState,
    generation: int,
    issuer: str,
) -> bool:
    expected_issuer = {
        0: "PRIMARY_SUPERVISOR",
        1: "RECOVERY_GUARDIAN",
    }.get(generation)
    return (
        expected_issuer == issuer
        and generation <= len(state.recovery_receipts)
    )


def _make_child_start_binding(
    state: OrchestratorState,
    grant: child.RunGrant,
    role: str,
    issuer: str,
) -> ChildStartBinding:
    assert state.parent_grant is not None
    partial = ChildStartBinding(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        role=role,
        child_run_id=grant.child_run_id,
        grant_digest=child.grant_binding_digest(grant),
        controller_generation=len(state.recovery_receipts),
        authority_namespace="CHILD_ENVELOPE_AUTHORITY_NAMESPACE_V1",
        parent_prefix_hash=_last_parent_hash(state),
        issuer=issuer,
        start_digest="",
        auth_tag="",
    )
    partial = replace(partial, start_digest=_child_start_digest(partial))
    return replace(partial, auth_tag=_child_start_auth(partial))


def child_start_binding_wf(
    state: OrchestratorState,
    binding: ChildStartBinding,
    grant: child.RunGrant,
    role: str,
) -> bool:
    parent = state.parent_grant
    return bool(
        parent is not None
        and binding.schema == SCHEMA
        and binding.parent_run_id == parent.parent_run_id
        and binding.binding_digest == parent_binding_digest(parent)
        and binding.role == role
        and binding.child_run_id == grant.child_run_id
        and binding.grant_digest == child.grant_binding_digest(grant)
        and _controller_generation_wf(
            state,
            binding.controller_generation,
            binding.issuer,
        )
        and binding.authority_namespace
        == "CHILD_ENVELOPE_AUTHORITY_NAMESPACE_V1"
        and bool(binding.parent_prefix_hash)
        and binding.start_digest
        == _child_start_digest(replace(binding, start_digest="", auth_tag=""))
        and binding.auth_tag
        == _child_start_auth(replace(binding, auth_tag=""))
    )


def _make_child_attachment(
    state: OrchestratorState,
    role: str,
    certificate: ChildCertificate,
    start: ChildStartBinding,
    *,
    owner_failure_bound: bool,
) -> ChildAttachment:
    assert state.parent_grant is not None
    notice_digest = ""
    if owner_failure_bound:
        if state.owner_failure_notice is None:
            raise OrchestratorReject(
                "F05-ORCH-CHILD-ATTACH-NO-OWNER-FAILURE",
                role,
            )
        notice_digest = _owner_failure_digest(state.owner_failure_notice)
    partial = ChildAttachment(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        role=role,
        child_run_id=certificate.grant.child_run_id,
        grant_digest=child.grant_binding_digest(certificate.grant),
        start_binding_digest=start.start_digest,
        certificate_digest=certificate.certificate_digest,
        parent_controller_generation=len(state.recovery_receipts),
        parent_prefix_hash=_last_parent_hash(state),
        owner_failure_notice_digest=notice_digest,
        issuer="CHILD_ENVELOPE",
        attachment_digest="",
        auth_tag="",
    )
    partial = replace(
        partial,
        attachment_digest=_child_attachment_digest(partial),
    )
    return replace(partial, auth_tag=_child_attachment_auth(partial))


def child_attachment_wf(
    state: OrchestratorState,
    attachment: ChildAttachment,
    certificate: ChildCertificate,
    start: ChildStartBinding,
    role: str,
) -> bool:
    parent = state.parent_grant
    expected_failure_digest = (
        _owner_failure_digest(state.owner_failure_notice)
        if state.owner_failure_notice is not None
        and attachment.owner_failure_notice_digest
        else ""
    )
    return bool(
        parent is not None
        and attachment.schema == SCHEMA
        and attachment.parent_run_id == parent.parent_run_id
        and attachment.binding_digest == parent_binding_digest(parent)
        and attachment.role == role
        and attachment.child_run_id == certificate.grant.child_run_id
        and attachment.grant_digest
        == child.grant_binding_digest(certificate.grant)
        and attachment.start_binding_digest == start.start_digest
        and attachment.certificate_digest == certificate.certificate_digest
        and 0
        <= attachment.parent_controller_generation
        <= len(state.recovery_receipts)
        and bool(attachment.parent_prefix_hash)
        and attachment.owner_failure_notice_digest == expected_failure_digest
        and attachment.issuer == "CHILD_ENVELOPE"
        and attachment.attachment_digest
        == _child_attachment_digest(
            replace(attachment, attachment_digest="", auth_tag="")
        )
        and attachment.auth_tag
        == _child_attachment_auth(replace(attachment, auth_tag=""))
    )


def _canonical_child_attachment_successor(
    state: OrchestratorState,
    role: str,
    certificate: ChildCertificate,
    *,
    owner_failure_bound: bool,
) -> OrchestratorState:
    if role == "PRODUCER":
        start = state.producer_start_binding
    elif role == "CHECKER":
        start = state.checker_start_binding
    else:
        raise OrchestratorReject("F05-ORCH-CHILD-ATTACH-ROLE", role)
    if start is None:
        raise OrchestratorReject("F05-ORCH-CHILD-ATTACH-NO-START", role)
    attachment = _make_child_attachment(
        state,
        role,
        certificate,
        start,
        owner_failure_bound=owner_failure_bound,
    )
    updated = _append_parent_receipt(
        state,
        "CHILD_ENVELOPE",
        f"{role}_CERT_ATTACHED",
        attachment.attachment_digest,
    )
    if owner_failure_bound:
        if state.phase != "ABANDONING" or state.active_child != role:
            raise OrchestratorReject(
                "F05-ORCH-CHILD-ATTACH-FAILURE-PHASE",
                role,
            )
        changes = {
            f"{role.lower()}_status": "ATTACHED",
            f"{role.lower()}_certificate": certificate,
            f"{role.lower()}_attachment": attachment,
            "active_child": "NONE",
        }
        return replace(updated, **changes)
    if role == "PRODUCER":
        if state.phase != "PRODUCER_RUNNING":
            raise OrchestratorReject(
                "F05-ORCH-CHILD-ATTACH-PRODUCER-PHASE",
                state.phase,
            )
        needs_checker = (
            certificate.local_decision == "LOCAL_SYNTACTIC_CANDIDATE"
        )
        return replace(
            updated,
            phase=(
                "PRODUCER_ATTACHED" if needs_checker else "CHILDREN_COMPLETE"
            ),
            producer_status="ATTACHED",
            producer_certificate=certificate,
            producer_attachment=attachment,
            checker_status="NONE" if needs_checker else "SKIPPED",
            active_child="NONE",
        )
    if state.phase != "CHECKER_RUNNING":
        raise OrchestratorReject(
            "F05-ORCH-CHILD-ATTACH-CHECKER-PHASE",
            state.phase,
        )
    return replace(
        updated,
        phase="CHILDREN_COMPLETE",
        checker_status="ATTACHED",
        checker_certificate=certificate,
        checker_attachment=attachment,
        active_child="NONE",
    )


def _make_child_retirement(
    state: OrchestratorState,
    grant: child.RunGrant,
    role: str,
) -> ChildGrantRetirement:
    if state.parent_grant is None or state.owner_failure_notice is None:
        raise OrchestratorReject("F05-ORCH-CHILD-RETIRE-NO-FAILURE", role)
    partial = ChildGrantRetirement(
        schema=SCHEMA,
        parent_run_id=state.parent_grant.parent_run_id,
        binding_digest=parent_binding_digest(state.parent_grant),
        role=role,
        child_run_id=grant.child_run_id,
        grant_digest=child.grant_binding_digest(grant),
        owner_failure_notice_digest=_owner_failure_digest(
            state.owner_failure_notice
        ),
        controller_generation=len(state.recovery_receipts),
        parent_prefix_hash=_last_parent_hash(state),
        reason="OWNER_FAILURE",
        issuer="EXTERNAL_OWNER",
        retirement_digest="",
        auth_tag="",
    )
    partial = replace(
        partial,
        retirement_digest=_child_retirement_digest(partial),
    )
    return replace(partial, auth_tag=_child_retirement_auth(partial))


def child_retirement_wf(
    state: OrchestratorState,
    retirement: ChildGrantRetirement,
    grant: child.RunGrant,
    role: str,
) -> bool:
    parent = state.parent_grant
    notice = state.owner_failure_notice
    return bool(
        parent is not None
        and notice is not None
        and state.owner_state == "FAILED"
        and retirement.schema == SCHEMA
        and retirement.parent_run_id == parent.parent_run_id
        and retirement.binding_digest == parent_binding_digest(parent)
        and retirement.role == role
        and retirement.child_run_id == grant.child_run_id
        and retirement.grant_digest == child.grant_binding_digest(grant)
        and retirement.owner_failure_notice_digest
        == _owner_failure_digest(notice)
        and 0 <= retirement.controller_generation <= len(state.recovery_receipts)
        and bool(retirement.parent_prefix_hash)
        and retirement.reason == "OWNER_FAILURE"
        and retirement.issuer == "EXTERNAL_OWNER"
        and retirement.retirement_digest
        == _child_retirement_digest(
            replace(retirement, retirement_digest="", auth_tag="")
        )
        and retirement.auth_tag
        == _child_retirement_auth(replace(retirement, auth_tag=""))
    )


def _children_settled_for_abandonment(state: OrchestratorState) -> bool:
    unsettled = {"GRANT_AVAILABLE", "RUNNING"}
    return bool(
        state.active_child == "NONE"
        and state.producer_status not in unsettled
        and state.checker_status not in unsettled
    )


def _current_publication_authority(state: OrchestratorState) -> bool:
    commitment = state.publication_commitment
    return bool(
        commitment is not None
        and commitment.controller_generation == len(state.recovery_receipts)
        and commitment.controller_generation == state.store_controller_generation
        and commitment.issuer == state.controller
    )


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
        and _controller_generation_wf(
            state,
            capsule.controller_generation,
            capsule.issuer,
        )
        and capsule.capsule_digest == _capsule_digest(replace(capsule, capsule_digest="", auth_tag=""))
        and capsule.auth_tag == _capsule_auth(replace(capsule, auth_tag=""))
    )


def _store_head_wf(head: StoreHead, expected_generation: int) -> bool:
    if not (
        head.generation in {expected_generation, expected_generation + 1}
        and head.content_kind in STORE_HEAD_KINDS
        and head.controller_generation in {0, 1}
        and head.issuer in {"DURABLE_STORE", "CONCURRENT_STORE_WRITER"}
        and head.auth_tag == _store_head_auth(replace(head, auth_tag=""))
    ):
        return False
    if head.content_kind == "EMPTY":
        return (
            head.generation == expected_generation
            and head.content_digest == ""
            and head.controller_generation == 0
            and head.issuer == "DURABLE_STORE"
        )
    if not (
        head.generation == expected_generation + 1
        and bool(head.content_digest)
    ):
        return False
    if head.content_kind == "FOREIGN":
        return head.issuer == "CONCURRENT_STORE_WRITER"
    if head.content_kind == "ABANDONMENT_TOMBSTONE":
        return head.issuer == "DURABLE_STORE" and head.controller_generation == 1
    return head.content_kind == "LOCAL_PUBLICATION" and head.issuer == "DURABLE_STORE"


def store_fence_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return (
            state.store_head is None
            and state.store_controller_generation == 0
            and state.store_fence_ack is None
        )
    expected = state.parent_grant.expected_publication_generation
    head = state.store_head
    if head is None or not _store_head_wf(head, expected):
        return False
    if head.controller_generation > state.store_controller_generation:
        return False
    if not 0 <= state.store_controller_generation <= len(state.recovery_receipts):
        return False
    ack = state.store_fence_ack
    if state.store_controller_generation == 0:
        return ack is None
    if ack is None:
        return False
    superseded_digest = (
        state.superseded_publications[-1].commitment.commitment_digest
        if state.superseded_publications
        else ""
    )
    supersession_digest = (
        state.superseded_publications[-1].supersession_digest
        if state.superseded_publications
        else ""
    )
    observed_head_monotonic = bool(
        (
            ack.observed_head.content_kind == "EMPTY"
            and (
                head == ack.observed_head
                or head.content_kind != "EMPTY"
            )
        )
        or (
            ack.observed_head.content_kind != "EMPTY"
            and head == ack.observed_head
        )
    )
    post_empty_fence_head_authorized = True
    if ack.observed_head.content_kind == "EMPTY":
        if head.content_kind == "LOCAL_PUBLICATION":
            post_empty_fence_head_authorized = bool(
                state.publication_commitment is not None
                and state.publication_commitment.controller_generation
                >= ack.new_controller_generation
                and head
                == _publication_store_head(state.publication_commitment)
            )
        elif head.content_kind == "ABANDONMENT_TOMBSTONE":
            post_empty_fence_head_authorized = bool(
                state.abandonment_commitment is not None
                and head.controller_generation
                >= ack.new_controller_generation
                and head
                == _abandonment_store_head(
                    state.abandonment_commitment,
                    head.controller_generation,
                )
            )
    return (
        ack.schema == SCHEMA
        and ack.parent_run_id == state.parent_grant.parent_run_id
        and ack.binding_digest == parent_binding_digest(state.parent_grant)
        and ack.old_controller_generation == 0
        and ack.new_controller_generation == 1
        and ack.new_controller_generation == state.store_controller_generation
        and _store_head_wf(ack.observed_head, expected)
        and ack.observed_head.controller_generation
        <= ack.old_controller_generation
        and observed_head_monotonic
        and post_empty_fence_head_authorized
        and ack.superseded_commitment_digest == superseded_digest
        and ack.supersession_digest == supersession_digest
        and ack.issuer == "DURABLE_STORE"
        and ack.auth_tag == _store_fence_auth(replace(ack, auth_tag=""))
    )


def publication_wf(state: OrchestratorState) -> bool:
    if state.parent_grant is None:
        return (
            state.publication == "NONE"
            and state.publication_commitment is None
            and state.durable_ack is None
            and not state.superseded_publications
            and state.publication_ack is None
            and state.abandonment_commitment is None
            and state.abandonment_ack is None
            and state.abandonment_conflict_notice is None
            and state.store_head is None
        )

    grant = state.parent_grant
    expected_generation = grant.expected_publication_generation
    head = state.store_head
    commitment = state.publication_commitment
    if head is None or not _store_head_wf(head, expected_generation):
        return False

    def commitment_wf(value: PublicationCommitment) -> bool:
        return bool(
            state.local_capsule is not None
            and value.parent_run_id == grant.parent_run_id
            and value.artifact_type == "LOCAL_DISPOSITION_CAPSULE"
            and value.capsule_digest == state.local_capsule.capsule_digest
            and value.expected_generation == expected_generation
            and _controller_generation_wf(
                state,
                value.controller_generation,
                value.issuer,
            )
            and value.commitment_digest
            == _commitment_digest(replace(value, commitment_digest=""))
        )

    if commitment is not None and not commitment_wf(commitment):
        return False
    if len(state.superseded_publications) > 1:
        return False
    for superseded in state.superseded_publications:
        old = superseded.commitment
        old_ack = superseded.durable_ack
        if not (
            commitment_wf(old)
            and superseded.superseded_by_generation
            == old.controller_generation + 1
            and superseded.superseded_by_generation
            <= len(state.recovery_receipts)
            and superseded.issuer == "DURABLE_STORE"
            and superseded.supersession_digest
            == _supersession_digest(
                replace(superseded, supersession_digest="", auth_tag="")
            )
            and superseded.auth_tag
            == _supersession_auth(replace(superseded, auth_tag=""))
        ):
            return False
        if old_ack is not None and not (
            old_ack.commitment_digest == old.commitment_digest
            and old_ack.generation == old.expected_generation
            and old_ack.controller_generation == old.controller_generation
            and old_ack.controller_generation
            <= old_ack.observation_generation
            <= len(state.recovery_receipts)
            and old_ack.issuer == "DURABLE_STORE"
            and old_ack.auth_tag
            == _durable_ack_auth(replace(old_ack, auth_tag=""))
        ):
            return False
    if (
        state.superseded_publications
        and commitment is not None
        and commitment.commitment_digest
        == state.superseded_publications[-1].commitment.commitment_digest
    ):
        return False

    if state.durable_ack is not None:
        ack = state.durable_ack
        if not (
            commitment is not None
            and ack.commitment_digest == commitment.commitment_digest
            and ack.generation == commitment.expected_generation
            and ack.controller_generation == commitment.controller_generation
            and ack.controller_generation
            <= ack.observation_generation
            <= len(state.recovery_receipts)
            and (
                ack.observation_generation == ack.controller_generation
                or (
                    state.primary_state == "FAILED"
                    and ack.controller_generation
                    < len(state.recovery_receipts)
                )
            )
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
            and ack.controller_generation == commitment.controller_generation
            and ack.issuer == "DURABLE_STORE"
            and ack.auth_tag == _publication_ack_auth(replace(ack, auth_tag=""))
        ):
            return False

    if (
        state.owner_state == "ACTIVE"
        and state.publication in {"PREPARED", "DURABLE"}
        and not _current_publication_authority(state)
    ):
        return False

    tombstone = state.abandonment_commitment
    prior_digest = (
        commitment.commitment_digest
        if commitment is not None
        else (
            state.superseded_publications[-1].commitment.commitment_digest
            if state.superseded_publications
            else ""
        )
    )
    if tombstone is not None:
        if state.local_capsule is None or not state.parent_evidence_root:
            return False
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

    conflict = state.abandonment_conflict_notice
    conflict_breach = state.assurance_breach == "ABANDONMENT_HEAD_CONFLICT"
    if conflict is not None:
        if not (
            tombstone is not None
            and conflict.schema == SCHEMA
            and conflict.parent_run_id == grant.parent_run_id
            and conflict.binding_digest == parent_binding_digest(grant)
            and conflict.commitment_digest == tombstone.commitment_digest
            and conflict.expected_generation == tombstone.expected_generation
            and conflict.observed_head == head
            and head.generation != expected_generation
            and conflict.issuer == "DURABLE_STORE"
            and conflict.auth_tag
            == _abandonment_conflict_auth(replace(conflict, auth_tag=""))
        ):
            return False
    if (conflict is not None) != conflict_breach:
        return False

    if state.publication == "ASSURANCE_BREACHED":
        return (
            state.phase == "ASSURANCE_BREACHED"
            and state.assurance_breach != "NONE"
            and state.publication_ack is None
            and state.abandonment_ack is None
        )
    if state.publication == "NONE":
        return (
            commitment is None
            and state.durable_ack is None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "PREPARED":
        return (
            state.phase == "PREPARED"
            and commitment is not None
            and state.durable_ack is None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "DURABLE":
        return (
            state.phase == "DURABLE"
            and commitment is not None
            and state.durable_ack is not None
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "FENCE_PENDING":
        return (
            state.phase == "PUBLICATION_FENCE_PENDING"
            and state.owner_state == "ACTIVE"
            and state.primary_state == "FAILED"
            and commitment is not None
            and commitment.controller_generation < len(state.recovery_receipts)
            and commitment.controller_generation
            == state.store_controller_generation
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "FENCED":
        return (
            state.phase == "PUBLICATION_FENCED"
            and state.owner_state == "ACTIVE"
            and state.primary_state == "FAILED"
            and state.store_controller_generation == len(state.recovery_receipts)
            and state.store_fence_ack is not None
            and commitment is None
            and state.durable_ack is None
            and bool(state.superseded_publications)
            and state.publication_ack is None
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "PUBLISHED":
        return (
            state.phase == "TERMINAL"
            and commitment is not None
            and commitment.controller_generation
            == state.store_controller_generation
            and state.durable_ack is not None
            and state.publication_ack is not None
            and head == _publication_store_head(commitment)
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "STALE_REJECTED":
        return (
            state.phase == "TERMINAL"
            and commitment is not None
            and commitment.controller_generation
            == state.store_controller_generation
            and state.publication_ack is None
            and head.generation == expected_generation + 1
            and head.content_kind != "EMPTY"
            and tombstone is None
            and state.abandonment_ack is None
        )
    if state.publication == "ABANDONING":
        return (
            state.phase == "ABANDONING"
            and state.owner_state == "FAILED"
            and state.publication_ack is None
            and state.abandonment_ack is None
        )
    return (
        state.publication == "ABANDONED"
        and state.phase == "TERMINAL"
        and state.owner_state == "FAILED"
        and state.publication_ack is None
        and tombstone is not None
        and state.abandonment_ack is not None
        and head
        == _abandonment_store_head(
            tombstone,
            state.store_controller_generation,
        )
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
        failover_position = state.parent_receipts.index(failovers[0])
        expected_phase = _parent_phase_at_receipt_count(
            state,
            failover_position,
        )
        if not (
            len(failovers) == 1
            and expected_phase is not None
            and receipt.observed_phase == expected_phase
            and receipt.parent_prefix_hash == failovers[0].previous_hash
            and failovers[0].payload == receipt.observed_phase
        ):
            return False
        if (
            state.parent_ledger == "OPEN"
            and state.parent_receipts[-1] == failovers[0]
            and state.store_controller_generation == 0
            and state.publication not in {
                "FENCE_PENDING",
                "FENCED",
                "ASSURANCE_BREACHED",
            }
            and state.phase not in {"TERMINAL", "ASSURANCE_BREACHED"}
            and receipt.observed_phase != state.phase
        ):
            return False
        return True
    expected_phase = (
        "ABANDONING"
        if receipt.reason == "OWNER_FAILURE"
        else _sealed_phase_at_controller_generation(
            state,
            receipt.sequence - 1,
        )
    )
    return (
        state.parent_ledger == "SEALED"
        and receipt.parent_prefix_hash == state.parent_evidence_root
        and expected_phase is not None
        and receipt.observed_phase == expected_phase
    )


def child_lifecycle_wf(state: OrchestratorState) -> bool:
    if state.producer_start_binding is not None and not (
        state.producer_grant is not None
        and child_start_binding_wf(
            state,
            state.producer_start_binding,
            state.producer_grant,
            "PRODUCER",
        )
    ):
        return False
    if state.producer_attachment is not None and not (
        state.producer_certificate is not None
        and state.producer_start_binding is not None
        and child_attachment_wf(
            state,
            state.producer_attachment,
            state.producer_certificate,
            state.producer_start_binding,
            "PRODUCER",
        )
    ):
        return False
    if state.producer_retirement is not None and not (
        state.producer_grant is not None
        and child_retirement_wf(
            state,
            state.producer_retirement,
            state.producer_grant,
            "PRODUCER",
        )
    ):
        return False
    if state.checker_start_binding is not None and not (
        state.checker_grant is not None
        and child_start_binding_wf(
            state,
            state.checker_start_binding,
            state.checker_grant,
            "CHECKER",
        )
    ):
        return False
    if state.checker_attachment is not None and not (
        state.checker_certificate is not None
        and state.checker_start_binding is not None
        and child_attachment_wf(
            state,
            state.checker_attachment,
            state.checker_certificate,
            state.checker_start_binding,
            "CHECKER",
        )
    ):
        return False
    if state.checker_retirement is not None and not (
        state.checker_grant is not None
        and child_retirement_wf(
            state,
            state.checker_retirement,
            state.checker_grant,
            "CHECKER",
        )
    ):
        return False

    producer_shapes = {
        "NONE": (
            state.producer_grant is None
            and state.producer_start_binding is None
            and state.producer_certificate is None
            and state.producer_attachment is None
            and state.producer_retirement is None
            and state.active_child != "PRODUCER"
        ),
        "GRANT_AVAILABLE": (
            state.producer_grant is not None
            and state.producer_start_binding is None
            and state.producer_certificate is None
            and state.producer_attachment is None
            and state.producer_retirement is None
            and state.active_child == "NONE"
        ),
        "RUNNING": (
            state.producer_grant is not None
            and state.producer_start_binding is not None
            and state.producer_certificate is None
            and state.producer_attachment is None
            and state.producer_retirement is None
            and state.active_child == "PRODUCER"
        ),
        "ATTACHED": (
            state.producer_grant is not None
            and state.producer_start_binding is not None
            and state.producer_certificate is not None
            and state.producer_attachment is not None
            and state.producer_retirement is None
            and state.active_child != "PRODUCER"
        ),
        "RETIRED": (
            state.producer_grant is not None
            and state.producer_start_binding is None
            and state.producer_certificate is None
            and state.producer_attachment is None
            and state.producer_retirement is not None
            and state.active_child == "NONE"
        ),
        "SKIPPED": False,
    }
    checker_shapes = {
        "NONE": (
            state.checker_grant is None
            and state.checker_start_binding is None
            and state.checker_certificate is None
            and state.checker_attachment is None
            and state.checker_retirement is None
            and state.active_child != "CHECKER"
        ),
        "GRANT_AVAILABLE": (
            state.checker_grant is not None
            and state.checker_start_binding is None
            and state.checker_certificate is None
            and state.checker_attachment is None
            and state.checker_retirement is None
            and state.active_child == "NONE"
        ),
        "RUNNING": (
            state.checker_grant is not None
            and state.checker_start_binding is not None
            and state.checker_certificate is None
            and state.checker_attachment is None
            and state.checker_retirement is None
            and state.active_child == "CHECKER"
        ),
        "ATTACHED": (
            state.checker_grant is not None
            and state.checker_start_binding is not None
            and state.checker_certificate is not None
            and state.checker_attachment is not None
            and state.checker_retirement is None
            and state.active_child != "CHECKER"
        ),
        "RETIRED": (
            state.checker_grant is not None
            and state.checker_start_binding is None
            and state.checker_certificate is None
            and state.checker_attachment is None
            and state.checker_retirement is not None
            and state.active_child == "NONE"
        ),
        "SKIPPED": (
            state.checker_grant is None
            and state.checker_start_binding is None
            and state.checker_certificate is None
            and state.checker_attachment is None
            and state.checker_retirement is None
            and state.active_child == "NONE"
        ),
    }
    if not producer_shapes[state.producer_status] or not checker_shapes[state.checker_status]:
        return False
    if state.active_child == "NONE":
        if state.producer_status == "RUNNING" or state.checker_status == "RUNNING":
            return False
    elif state.active_child == "PRODUCER":
        if state.producer_status != "RUNNING" or state.checker_status == "RUNNING":
            return False
    elif state.checker_status != "RUNNING" or state.producer_status == "RUNNING":
        return False

    phase_shapes = {
        "WAIT_GRANT": ("NONE", "NONE", "NONE"),
        "GRANT_AVAILABLE": ("NONE", "NONE", "NONE"),
        "GRANT_CONSUME_PENDING": ("NONE", "NONE", "NONE"),
        "PARENT_ACTIVE": ("NONE", "NONE", "NONE"),
        "PRODUCER_GRANT_AVAILABLE": ("GRANT_AVAILABLE", "NONE", "NONE"),
        "PRODUCER_RUNNING": ("RUNNING", "NONE", "PRODUCER"),
        "PRODUCER_ATTACHED": ("ATTACHED", "NONE", "NONE"),
        "CHECKER_GRANT_AVAILABLE": ("ATTACHED", "GRANT_AVAILABLE", "NONE"),
        "CHECKER_RUNNING": ("ATTACHED", "RUNNING", "CHECKER"),
    }
    expected = phase_shapes.get(state.phase)
    if expected and expected != (
        state.producer_status,
        state.checker_status,
        state.active_child,
    ):
        return False
    complete_phases = {
        "CHILDREN_COMPLETE",
        "PARENT_SEALED",
        "LOCAL_DECIDED",
        "PREPARED",
        "DURABLE",
        "PUBLICATION_FENCE_PENDING",
        "PUBLICATION_FENCED",
    }
    if state.phase in complete_phases:
        if not (
            state.producer_status == "ATTACHED"
            and state.checker_status in {"ATTACHED", "SKIPPED"}
            and state.active_child == "NONE"
        ):
            return False
    if state.phase == "TERMINAL":
        if state.active_child != "NONE" or state.pending_attack != "NONE":
            return False
        if state.publication in {"PUBLISHED", "STALE_REJECTED"}:
            if not (
                state.producer_status == "ATTACHED"
                and state.checker_status in {"ATTACHED", "SKIPPED"}
            ):
                return False
        if state.publication == "ABANDONED" and not (
            state.owner_state == "FAILED"
            and _children_settled_for_abandonment(state)
        ):
            return False
    if state.phase == "ABANDONING" and not _children_settled_for_abandonment(state):
        if state.active_child == "NONE" and not (
            state.producer_status == "GRANT_AVAILABLE"
            or state.checker_status == "GRANT_AVAILABLE"
        ):
            return False
    return True


@lru_cache(maxsize=STATE_CACHE_MAX_ENTRIES)
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
        and state.assurance_breach in ASSURANCE_BREACHES
        and state.grant_registry_state in GRANT_REGISTRY_STATES
        and state.grant_registry_generation >= 0
        and state.semantic_verdict is None
        and grant_registry_wf(state)
        and parent_evidence_wf(state)
        and owner_failure_wf(state)
        and store_security_wf(state)
        and child_lifecycle_wf(state)
        and capsule_wf(state)
        and store_fence_wf(state)
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
    pre_capsule_phases = {
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
    }
    if state.phase in pre_capsule_phases and (
        state.local_disposition != "NONE" or state.local_capsule is not None
    ):
        return False
    capsule_required_phases = {
        "LOCAL_DECIDED",
        "PREPARED",
        "DURABLE",
        "PUBLICATION_FENCE_PENDING",
        "PUBLICATION_FENCED",
    }
    if state.phase in capsule_required_phases and (
        state.local_disposition == "NONE" or state.local_capsule is None
    ):
        return False
    if (
        state.abandonment_commitment is not None
        or state.publication in {"PUBLISHED", "STALE_REJECTED", "ABANDONED"}
    ) and state.local_capsule is None:
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
        "POST_OWNER_FAILURE_PUBLICATION",
    } and state.guardian_state != "ACTIVE":
        return False
    if state.assurance_breach == "ABANDONMENT_HEAD_CONFLICT":
        if state.owner_state != "FAILED" or state.guardian_state != "ACTIVE":
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
        "PUBLICATION_FENCE_PENDING",
        "PUBLICATION_FENCED",
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


def semantic_projection(state: OrchestratorState) -> OrchestratorState:
    # Exact identity is deliberate: evidence and recovery histories affect future
    # roots and therefore cannot be quotient-elided without a congruence proof.
    return state


def _action_semantics_wf(
    action_id: str,
    before: OrchestratorState,
    after: OrchestratorState,
) -> bool:
    fixed_phase_pairs = {
        "EXT-001-DELIVER-PARENT-GRANT": ("WAIT_GRANT", "GRANT_AVAILABLE"),
        "SUP-002-CONSUME-PARENT-GRANT": (
            "GRANT_AVAILABLE",
            "GRANT_CONSUME_PENDING",
        ),
        "STORE-002B-COMMIT-GRANT-CONSUMPTION": (
            "GRANT_CONSUME_PENDING",
            "PARENT_ACTIVE",
        ),
        "STORE-002C-RETIRE-GRANT-NONCE": ("ABANDONING", "ABANDONING"),
        "EXT-024A-RETIRE-PRODUCER-GRANT": ("ABANDONING", "ABANDONING"),
        "EXT-024B-RETIRE-CHECKER-GRANT": ("ABANDONING", "ABANDONING"),
        "EXT-003-DELIVER-PRODUCER-GRANT": (
            "PARENT_ACTIVE",
            "PRODUCER_GRANT_AVAILABLE",
        ),
        "SUP-004-START-PRODUCER": (
            "PRODUCER_GRANT_AVAILABLE",
            "PRODUCER_RUNNING",
        ),
        "EXT-009-DELIVER-CHECKER-GRANT": (
            "PRODUCER_ATTACHED",
            "CHECKER_GRANT_AVAILABLE",
        ),
        "SUP-010-START-CHECKER": (
            "CHECKER_GRANT_AVAILABLE",
            "CHECKER_RUNNING",
        ),
        "SUP-016-SEAL-PARENT-EVIDENCE": (
            "CHILDREN_COMPLETE",
            "PARENT_SEALED",
        ),
        "SUP-017-DECIDE-LOCAL-DISPOSITION": (
            "PARENT_SEALED",
            "LOCAL_DECIDED",
        ),
        "SUP-018-PREPARE-LOCAL-PUBLICATION": (
            "LOCAL_DECIDED",
            "PREPARED",
        ),
        "GRD-018B-REAUTHORIZE-PUBLICATION": (
            "PUBLICATION_FENCED",
            "PREPARED",
        ),
        "STORE-019-DURABLE-ACK": ("PREPARED", "DURABLE"),
        "STORE-019A-ACK-OLD-PRE-FENCE": (
            "PUBLICATION_FENCE_PENDING",
            "PUBLICATION_FENCE_PENDING",
        ),
        "STORE-020-PUBLISH-CAS": ("DURABLE", "TERMINAL"),
        "STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS": (
            "PUBLICATION_FENCE_PENDING",
            "TERMINAL",
        ),
        "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT": (
            "ABANDONING",
            "TERMINAL",
        ),
        "STORE-026B-TOMBSTONE-HEAD-CONFLICT": (
            "ABANDONING",
            "ASSURANCE_BREACHED",
        ),
    }
    expected_pair = fixed_phase_pairs.get(action_id)
    if expected_pair is not None and (before.phase, after.phase) != expected_pair:
        return False

    producer_scenarios = {
        "CHILD-005-ATTACH-PRODUCER-CANDIDATE": "CANDIDATE",
        "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B": "CANDIDATE_B",
        "CHILD-006-ATTACH-PRODUCER-RESOURCE": "RESOURCE",
        "CHILD-007-ATTACH-PRODUCER-INTERNAL": "INTERNAL",
        "CHILD-008-ATTACH-PRODUCER-ABANDONED": "ABANDONED",
    }
    if action_id in producer_scenarios:
        expected_certificate = fixture_child_certificate(
            before.producer_grant,
            producer_scenarios[action_id],
        ) if before.producer_grant is not None else None
        if not (
            before.phase == "PRODUCER_RUNNING"
            and before.producer_grant is not None
            and before.producer_start_binding is not None
            and expected_certificate is not None
        ):
            return False
        return after == _canonical_child_attachment_successor(
            before,
            "PRODUCER",
            expected_certificate,
            owner_failure_bound=False,
        )

    checker_scenarios = {
        "CHILD-011-ATTACH-CHECKER-ACCEPT": "CANDIDATE",
        "CHILD-012-ATTACH-CHECKER-REJECT": "CHECKER_REJECT",
        "CHILD-013-ATTACH-CHECKER-RESOURCE": "RESOURCE",
        "CHILD-014-ATTACH-CHECKER-INTERNAL": "INTERNAL",
        "CHILD-015-ATTACH-CHECKER-ABANDONED": "ABANDONED",
    }
    if action_id in checker_scenarios:
        expected_certificate = fixture_child_certificate(
            before.checker_grant,
            checker_scenarios[action_id],
        ) if before.checker_grant is not None else None
        if not (
            before.phase == "CHECKER_RUNNING"
            and before.checker_grant is not None
            and before.checker_start_binding is not None
            and expected_certificate is not None
        ):
            return False
        return after == _canonical_child_attachment_successor(
            before,
            "CHECKER",
            expected_certificate,
            owner_failure_bound=False,
        )

    attack_actions = {
        spec.action_id: attack
        for attack, spec in STORE_ATTACK_SPECS.items()
    }
    if action_id in attack_actions:
        expected_attack = attack_actions[action_id]
        return bool(
            before.pending_attack == "NONE"
            and after.pending_attack == expected_attack
            and after.pending_attack_context
            == _make_store_attack_context(before, expected_attack)
        )

    if action_id == "STORE-002B-COMMIT-GRANT-CONSUMPTION":
        return bool(
            after.grant_consumption_ack is not None
            and after.grant_consumption_ack.outcome == "CONSUMED"
        )
    if action_id == "STORE-002C-RETIRE-GRANT-NONCE":
        return bool(
            after.grant_consumption_ack is not None
            and after.grant_consumption_ack.outcome == "RETIRED"
        )
    if action_id == "SUP-004-START-PRODUCER":
        return bool(
            before.producer_grant is not None
            and after.producer_start_binding
            == _make_child_start_binding(
                before,
                before.producer_grant,
                "PRODUCER",
                before.controller,
            )
        )
    if action_id == "SUP-010-START-CHECKER":
        return bool(
            before.checker_grant is not None
            and after.checker_start_binding
            == _make_child_start_binding(
                before,
                before.checker_grant,
                "CHECKER",
                before.controller,
            )
        )
    if action_id == "STORE-018A-FENCE-PUBLICATION-CONTROLLER":
        archived_old = bool(
            before.publication_commitment is not None
            and before.publication_commitment.controller_generation
            < after.store_controller_generation
        )
        archive_exact = (
            after.publication_commitment is None
            and after.durable_ack is None
            and after.superseded_publications[:-1]
            == before.superseded_publications
            and after.superseded_publications[-1].commitment
            == before.publication_commitment
            and after.superseded_publications[-1].durable_ack
            == before.durable_ack
            and after.store_fence_ack is not None
            and after.store_fence_ack.supersession_digest
            == after.superseded_publications[-1].supersession_digest
        ) if archived_old else (
            after.publication_commitment == before.publication_commitment
            and after.durable_ack == before.durable_ack
            and after.superseded_publications == before.superseded_publications
            and after.store_fence_ack is not None
            and not after.store_fence_ack.supersession_digest
        )
        return bool(
            before.primary_state == "FAILED"
            and before.store_controller_generation
            < len(before.recovery_receipts)
            and after.store_head == before.store_head
            and after.store_controller_generation
            == before.store_controller_generation + 1
            and after.store_fence_ack is not None
            and after.store_fence_ack.old_controller_generation
            == before.store_controller_generation
            and after.store_fence_ack.new_controller_generation
            == after.store_controller_generation
            and after.store_fence_ack.observed_head == before.store_head
            and archive_exact
            and (
                (
                    before.publication == "FENCE_PENDING"
                    and after.publication == "FENCED"
                    and after.phase == "PUBLICATION_FENCED"
                )
                or (
                    before.publication != "FENCE_PENDING"
                    and after.publication == before.publication
                    and after.phase == before.phase
                )
            )
        )
    if action_id == "EXT-018C-ADVANCE-STORE-HEAD":
        return bool(
            before.store_head is not None
            and before.store_head.content_kind == "EMPTY"
            and after.store_head == _foreign_store_head(before)
        )
    if action_id in {
        "STORE-020-PUBLISH-CAS",
        "STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS",
    }:
        return bool(
            before.store_head is not None
            and before.store_head.content_kind == "EMPTY"
            and after.publication == "PUBLISHED"
            and after.publication_ack is not None
            and before.publication_commitment is not None
            and after.store_head
            == _publication_store_head(before.publication_commitment)
        )
    if action_id == "STORE-019A-ACK-OLD-PRE-FENCE":
        return bool(
            before.publication == after.publication == "FENCE_PENDING"
            and before.durable_ack is None
            and after.durable_ack is not None
        )
    if action_id == "STORE-021-HEAD-CONFLICT":
        return bool(
            before.phase in {"PREPARED", "DURABLE"}
            and before.store_head is not None
            and before.store_head.content_kind != "EMPTY"
            and after.store_head == before.store_head
            and after.phase == "TERMINAL"
            and after.publication == "STALE_REJECTED"
        )
    if action_id == "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH":
        if not (
            before.owner_state == "ACTIVE"
            and before.primary_state == "ACTIVE"
        ):
            return False
        expected = _append_recovery(before, "PRIMARY_CRASH")
        if before.parent_ledger == "OPEN":
            expected = _append_parent_receipt(
                expected,
                "RECOVERY_GUARDIAN",
                "PRIMARY_FAILOVER",
                before.phase,
            )
        expected = replace(
            expected,
            primary_state="FAILED",
            controller="RECOVERY_GUARDIAN",
        )
        if before.publication in {"PREPARED", "DURABLE"}:
            expected = replace(
                expected,
                phase="PUBLICATION_FENCE_PENDING",
                publication="FENCE_PENDING",
            )
        return after == expected
    if action_id == "EXT-023-OWNER-FAILURE":
        return bool(
            before.owner_state == "ACTIVE"
            and after.owner_state == "FAILED"
            and after.phase == "ABANDONING"
            and after.publication == "ABANDONING"
            and after.owner_failure_notice is not None
            and after.owner_failure_phase == before.phase
        )
    if action_id == "GRD-023B-FENCE-AFTER-OWNER-FAILURE":
        if not (
            before.owner_state == "FAILED"
            and before.primary_state == "ACTIVE"
        ):
            return False
        expected = _append_recovery(before, "OWNER_FAILURE")
        if before.parent_ledger == "OPEN":
            expected = _append_parent_receipt(
                expected,
                "RECOVERY_GUARDIAN",
                "PRIMARY_FAILOVER",
                before.phase,
            )
        expected = replace(
            expected,
            primary_state="FAILED",
            controller="RECOVERY_GUARDIAN",
        )
        return after == expected
    if action_id == "CHILD-024-ATTACH-ACTIVE-ABANDONED":
        if before.active_child == "PRODUCER":
            if (
                before.producer_grant is None
                or before.producer_start_binding is None
            ):
                return False
            expected_certificate = fixture_child_certificate(
                before.producer_grant,
                "ABANDONED",
            )
            return after == _canonical_child_attachment_successor(
                before,
                "PRODUCER",
                expected_certificate,
                owner_failure_bound=True,
            )
        if before.active_child == "CHECKER":
            if before.checker_grant is None or before.checker_start_binding is None:
                return False
            expected_certificate = fixture_child_certificate(
                before.checker_grant,
                "ABANDONED",
            )
            return after == _canonical_child_attachment_successor(
                before,
                "CHECKER",
                expected_certificate,
                owner_failure_bound=True,
            )
        return False
    if action_id == "EXT-024A-RETIRE-PRODUCER-GRANT":
        return bool(
            before.owner_state == "FAILED"
            and before.producer_status == "GRANT_AVAILABLE"
            and before.producer_grant is not None
            and after.producer_status == "RETIRED"
            and after.producer_retirement
            == _make_child_retirement(
                before,
                before.producer_grant,
                "PRODUCER",
            )
        )
    if action_id == "EXT-024B-RETIRE-CHECKER-GRANT":
        return bool(
            before.owner_state == "FAILED"
            and before.checker_status == "GRANT_AVAILABLE"
            and before.checker_grant is not None
            and after.checker_status == "RETIRED"
            and after.checker_retirement
            == _make_child_retirement(
                before,
                before.checker_grant,
                "CHECKER",
            )
        )
    if action_id == "GRD-025-PREPARE-ABANDONMENT":
        return bool(
            before.phase == after.phase == "ABANDONING"
            and after.abandonment_commitment is not None
        )
    if action_id == "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT":
        return bool(
            before.store_head is not None
            and before.store_head.content_kind == "EMPTY"
            and before.abandonment_commitment is not None
            and after.publication == "ABANDONED"
            and after.abandonment_ack is not None
            and after.store_head
            == _abandonment_store_head(
                before.abandonment_commitment,
                before.store_controller_generation,
            )
        )
    if action_id == "STORE-026B-TOMBSTONE-HEAD-CONFLICT":
        return bool(
            before.store_head is not None
            and before.store_head.content_kind != "EMPTY"
            and after.store_head == before.store_head
            and after.publication == "ASSURANCE_BREACHED"
            and after.assurance_breach
            == "ABANDONMENT_HEAD_CONFLICT"
            and after.abandonment_conflict_notice is not None
            and after.abandonment_conflict_notice.observed_head
            == before.store_head
        )
    if action_id == "STORE-029-REJECT-HOSTILE-REQUEST":
        return bool(
            before.pending_attack != "NONE"
            and after.pending_attack == "NONE"
            and after.pending_attack_context is None
            and after.store_attack_rejections[-1] == before.pending_attack
        )
    if action_id == "ADV-029B-SUCCEED-STORE-BYPASS":
        expected_breach = STORE_ATTACK_SPECS.get(before.pending_attack)
        return bool(
            expected_breach is not None
            and after.assurance_breach == expected_breach.breach
            and after.phase == "ASSURANCE_BREACHED"
            and after.publication == "ASSURANCE_BREACHED"
            and after.pending_attack == "NONE"
            and after.pending_attack_context is None
        )
    if action_id == "ADV-030-STALL":
        return before == after
    if action_id == "ADV-031-FAIL-GUARDIAN":
        return bool(
            before.primary_state == "FAILED"
            and before.guardian_state == "ACTIVE"
            and after.guardian_state == "FAILED"
            and after.assurance_breach == "GUARDIAN_FAILURE"
            and after.phase == "ASSURANCE_BREACHED"
            and after.publication == "ASSURANCE_BREACHED"
        )
    return expected_pair is not None


def _edge(action_id: str, actor: str, before: OrchestratorState, after: OrchestratorState) -> OrchEdge:
    spec = ACTION_SPECS.get(action_id)
    if spec is None or actor not in spec.actors:
        raise OrchestratorReject("F05-ORCH-ACTION-ACTOR", f"{action_id}:{actor}")
    if (
        actor in CONTROLLERS
        and action_id not in {
            "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
        }
        and actor != before.controller
    ):
        raise OrchestratorReject("F05-ORCH-STALE-CONTROLLER", f"{action_id}:{actor}")
    changed_fields = {
        field_name
        for field_name in OrchestratorState.__dataclass_fields__
        if getattr(before, field_name) != getattr(after, field_name)
    }
    unexpected_fields = changed_fields - ACTION_WRITE_FIELDS[action_id]
    if unexpected_fields:
        raise OrchestratorReject(
            "F05-ORCH-ACTION-EFFECT",
            f"{action_id}:{','.join(sorted(unexpected_fields))}",
        )
    missing_fields = ACTION_REQUIRED_WRITE_FIELDS[action_id] - changed_fields
    if missing_fields:
        raise OrchestratorReject(
            "F05-ORCH-ACTION-REQUIRED-EFFECT",
            f"{action_id}:{','.join(sorted(missing_fields))}",
        )
    if not _action_semantics_wf(action_id, before, after):
        raise OrchestratorReject("F05-ORCH-ACTION-POSTCONDITION", action_id)
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
    if (
        before.owner_failure_notice != after.owner_failure_notice
        and actor != "EXTERNAL_OWNER"
    ):
        raise OrchestratorReject("F05-ORCH-OWNER-NOTICE-WRITE", action_id)
    if before.local_capsule != after.local_capsule:
        if before.local_capsule is not None or after.local_capsule is None:
            raise OrchestratorReject("F05-ORCH-CAPSULE-IMMUTABLE", action_id)
        if not (
            actor in CONTROLLERS
            and after.local_capsule.issuer == actor
            and after.local_capsule.controller_generation
            == len(after.recovery_receipts)
        ):
            raise OrchestratorReject(
                "F05-ORCH-CAPSULE-CREATION-GENERATION",
                action_id,
            )
    before_security = before.store_security_events
    after_security = after.store_security_events
    if after_security[: len(before_security)] != before_security:
        raise OrchestratorReject("F05-ORCH-STORE-SECURITY-NONAPPEND", action_id)
    if any(
        event.issuer != actor
        for event in after_security[len(before_security) :]
    ):
        raise OrchestratorReject("F05-ORCH-STORE-SECURITY-ACTOR", action_id)
    if before.producer_grant != after.producer_grant and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-PRODUCER-GRANT-WRITE", action_id)
    if before.checker_grant != after.checker_grant and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-CHECKER-GRANT-WRITE", action_id)
    if before.producer_certificate != after.producer_certificate and actor != "CHILD_ENVELOPE":
        raise OrchestratorReject("F05-ORCH-PRODUCER-CERT-WRITE", action_id)
    if before.checker_certificate != after.checker_certificate and actor != "CHILD_ENVELOPE":
        raise OrchestratorReject("F05-ORCH-CHECKER-CERT-WRITE", action_id)
    if (
        before.producer_start_binding != after.producer_start_binding
        or before.checker_start_binding != after.checker_start_binding
    ) and actor not in CONTROLLERS:
        raise OrchestratorReject("F05-ORCH-CHILD-START-WRITE", action_id)
    if (
        before.producer_attachment != after.producer_attachment
        or before.checker_attachment != after.checker_attachment
    ) and actor != "CHILD_ENVELOPE":
        raise OrchestratorReject("F05-ORCH-CHILD-ATTACHMENT-WRITE", action_id)
    if (
        before.producer_retirement != after.producer_retirement
        or before.checker_retirement != after.checker_retirement
    ) and actor != "EXTERNAL_OWNER":
        raise OrchestratorReject("F05-ORCH-CHILD-RETIREMENT-WRITE", action_id)
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
    if before.durable_ack != after.durable_ack:
        if actor != "DURABLE_STORE":
            raise OrchestratorReject("F05-ORCH-DURABLE-WRITE", action_id)
    if (
        before.publication_commitment != after.publication_commitment
        and actor not in CONTROLLERS
        and not (
            actor == "DURABLE_STORE"
            and action_id == "STORE-018A-FENCE-PUBLICATION-CONTROLLER"
        )
    ):
        raise OrchestratorReject("F05-ORCH-PUBLICATION-COMMIT-WRITE", action_id)
    if (
        before.superseded_publications != after.superseded_publications
        and not (
            actor == "DURABLE_STORE"
            and action_id == "STORE-018A-FENCE-PUBLICATION-CONTROLLER"
        )
    ):
        raise OrchestratorReject("F05-ORCH-PUBLICATION-ARCHIVE-WRITE", action_id)
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
        before.abandonment_conflict_notice
        != after.abandonment_conflict_notice
        and actor != "DURABLE_STORE"
    ):
        raise OrchestratorReject("F05-ORCH-ABANDONMENT-CONFLICT-WRITE", action_id)
    if before.store_head != after.store_head:
        if (
            before.store_head is not None
            and before.store_head.content_kind != "EMPTY"
        ):
            raise OrchestratorReject(
                "F05-ORCH-STORE-HEAD-NONEMPTY-IMMUTABLE",
                action_id,
            )
        allowed_store_head_writer = (
            (action_id == "EXT-001-DELIVER-PARENT-GRANT" and actor == "EXTERNAL_OWNER")
            or actor == "DURABLE_STORE"
            or actor == "CONCURRENT_STORE_WRITER"
        )
        if not allowed_store_head_writer:
            raise OrchestratorReject("F05-ORCH-STORE-HEAD-WRITE", action_id)
    if (
        before.store_controller_generation != after.store_controller_generation
        or before.store_fence_ack != after.store_fence_ack
    ) and not (
        actor == "DURABLE_STORE"
        and action_id == "STORE-018A-FENCE-PUBLICATION-CONTROLLER"
    ):
        raise OrchestratorReject("F05-ORCH-STORE-FENCE-WRITE", action_id)
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
    if before.assurance_breach != after.assurance_breach:
        store_conflict_breach = (
            action_id == "STORE-026B-TOMBSTONE-HEAD-CONFLICT"
            and actor == "DURABLE_STORE"
            and after.assurance_breach
            == "ABANDONMENT_HEAD_CONFLICT"
        )
        if actor != "ADVERSARY" and not store_conflict_breach:
            raise OrchestratorReject("F05-ORCH-ASSURANCE-BREACH-WRITE", action_id)
    if not orchestrator_wf(after):
        raise OrchestratorReject("F05-ORCH-EFFECT-WF", action_id)
    return OrchEdge(action_id, actor, after)


def _controller(state: OrchestratorState) -> str:
    return state.controller


def external_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.publication in TERMINAL_PUBLICATIONS:
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
            store_head=_empty_store_head(
                grant.expected_publication_generation
            ),
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
        assert state.parent_grant is not None
        notice = OwnerFailureNotice(
            schema=SCHEMA,
            parent_run_id=state.parent_grant.parent_run_id,
            binding_digest=parent_binding_digest(state.parent_grant),
            observed_phase=state.phase,
            parent_prefix_hash=_last_parent_hash(state),
            local_capsule_digest_at_failure=(
                state.local_capsule.capsule_digest
                if state.local_capsule is not None
                else ""
            ),
            publication_at_failure=state.publication,
            store_controller_generation_at_failure=(
                state.store_controller_generation
            ),
            publication_commitment_digest_at_failure=(
                state.publication_commitment.commitment_digest
                if state.publication_commitment is not None
                else ""
            ),
            durable_ack_auth_at_failure=(
                state.durable_ack.auth_tag
                if state.durable_ack is not None
                else ""
            ),
            store_fence_ack_auth_at_failure=(
                state.store_fence_ack.auth_tag
                if state.store_fence_ack is not None
                else ""
            ),
            issuer=actor,
            auth_tag="",
        )
        notice = replace(notice, auth_tag=_owner_failure_auth(notice))
        updated = replace(state, owner_failure_notice=notice)
        if state.parent_ledger == "OPEN":
            updated = _append_parent_receipt(
                updated,
                actor,
                "OWNER_FAILURE_OBSERVED",
                _owner_failure_digest(notice),
            )
        updated = replace(
            updated,
            phase="ABANDONING",
            owner_state="FAILED",
            owner_failure_phase=state.phase,
            publication="ABANDONING",
        )
        edges.append(_edge("EXT-023-OWNER-FAILURE", actor, state, updated))
    if (
        state.owner_state == "FAILED"
        and state.phase == "ABANDONING"
        and state.parent_ledger == "OPEN"
        and state.producer_status == "GRANT_AVAILABLE"
        and state.producer_grant is not None
    ):
        retirement = _make_child_retirement(
            state,
            state.producer_grant,
            "PRODUCER",
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "PRODUCER_GRANT_RETIRED",
            retirement.retirement_digest,
        )
        updated = replace(
            updated,
            producer_status="RETIRED",
            producer_retirement=retirement,
        )
        edges.append(
            _edge(
                "EXT-024A-RETIRE-PRODUCER-GRANT",
                actor,
                state,
                updated,
            )
        )
    if (
        state.owner_state == "FAILED"
        and state.phase == "ABANDONING"
        and state.parent_ledger == "OPEN"
        and state.checker_status == "GRANT_AVAILABLE"
        and state.checker_grant is not None
    ):
        retirement = _make_child_retirement(
            state,
            state.checker_grant,
            "CHECKER",
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "CHECKER_GRANT_RETIRED",
            retirement.retirement_digest,
        )
        updated = replace(
            updated,
            checker_status="RETIRED",
            checker_retirement=retirement,
        )
        edges.append(
            _edge(
                "EXT-024B-RETIRE-CHECKER-GRANT",
                actor,
                state,
                updated,
            )
        )
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
        assert state.producer_grant is not None
        start = _make_child_start_binding(
            state,
            state.producer_grant,
            "PRODUCER",
            actor,
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "PRODUCER_STARTED",
            start.start_digest,
        )
        updated = replace(
            updated,
            phase="PRODUCER_RUNNING",
            producer_status="RUNNING",
            producer_start_binding=start,
            active_child="PRODUCER",
        )
        edges.append(_edge("SUP-004-START-PRODUCER", actor, state, updated))
    elif state.phase == "CHECKER_GRANT_AVAILABLE":
        assert state.checker_grant is not None
        start = _make_child_start_binding(
            state,
            state.checker_grant,
            "CHECKER",
            actor,
        )
        updated = _append_parent_receipt(
            state,
            actor,
            "CHECKER_STARTED",
            start.start_digest,
        )
        updated = replace(
            updated,
            phase="CHECKER_RUNNING",
            checker_status="RUNNING",
            checker_start_binding=start,
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
            controller_generation=len(state.recovery_receipts),
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
    elif (
        state.phase == "LOCAL_DECIDED"
        and state.store_controller_generation == len(state.recovery_receipts)
    ):
        assert state.local_capsule is not None and state.parent_grant is not None
        commitment = PublicationCommitment(
            parent_run_id=state.parent_grant.parent_run_id,
            artifact_type="LOCAL_DISPOSITION_CAPSULE",
            capsule_digest=state.local_capsule.capsule_digest,
            expected_generation=state.parent_grant.expected_publication_generation,
            controller_generation=len(state.recovery_receipts),
            issuer=actor,
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
        (
            "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B",
            fixture_child_certificate(state.producer_grant, "CANDIDATE_B"),
        ),
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
            assert (
                state.producer_grant is not None
                and state.producer_start_binding is not None
            )
            certificate = fixture_child_certificate(state.producer_grant, "ABANDONED")
            updated = _canonical_child_attachment_successor(
                state,
                "PRODUCER",
                certificate,
                owner_failure_bound=True,
            )
        else:
            assert (
                state.checker_grant is not None
                and state.checker_start_binding is not None
            )
            certificate = fixture_child_certificate(state.checker_grant, "ABANDONED")
            updated = _canonical_child_attachment_successor(
                state,
                "CHECKER",
                certificate,
                owner_failure_bound=True,
            )
        edges.append(_edge("CHILD-024-ATTACH-ACTIVE-ABANDONED", actor, state, updated))
        return tuple(edges)

    if state.phase == "PRODUCER_RUNNING":
        for action_id, certificate in _producer_certificates(state):
            assert state.producer_start_binding is not None
            updated = _canonical_child_attachment_successor(
                state,
                "PRODUCER",
                certificate,
                owner_failure_bound=False,
            )
            edges.append(_edge(action_id, actor, state, updated))
    elif state.phase == "CHECKER_RUNNING":
        for action_id, certificate in _checker_certificates(state):
            assert state.checker_start_binding is not None
            updated = _canonical_child_attachment_successor(
                state,
                "CHECKER",
                certificate,
                owner_failure_bound=False,
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
        if state.owner_state == "ACTIVE" and state.publication in {
            "PREPARED",
            "DURABLE",
        }:
            updated = replace(
                updated,
                phase="PUBLICATION_FENCE_PENDING",
                publication="FENCE_PENDING",
            )
        action_id = (
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE"
            if reason == "OWNER_FAILURE"
            else "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH"
        )
        edges.append(_edge(action_id, actor, state, updated))

    if (
        state.phase == "PUBLICATION_FENCED"
        and state.publication == "FENCED"
        and state.owner_state == "ACTIVE"
        and state.primary_state == "FAILED"
        and state.controller == actor
        and state.publication_commitment is None
        and state.superseded_publications
        and state.store_controller_generation == len(state.recovery_receipts)
        and state.store_fence_ack is not None
    ):
        old = state.superseded_publications[-1].commitment
        commitment = PublicationCommitment(
            parent_run_id=old.parent_run_id,
            artifact_type=old.artifact_type,
            capsule_digest=old.capsule_digest,
            expected_generation=old.expected_generation,
            controller_generation=len(state.recovery_receipts),
            issuer=actor,
            commitment_digest="",
        )
        commitment = replace(
            commitment,
            commitment_digest=_commitment_digest(commitment),
        )
        updated = replace(
            state,
            phase="PREPARED",
            publication="PREPARED",
            publication_commitment=commitment,
        )
        edges.append(
            _edge(
                "GRD-018B-REAUTHORIZE-PUBLICATION",
                actor,
                state,
                updated,
            )
        )

    if (
        state.publication == "ABANDONING"
        and state.primary_state == "FAILED"
        and state.controller == "RECOVERY_GUARDIAN"
        and state.store_controller_generation == len(state.recovery_receipts)
        and state.store_fence_ack is not None
        and _children_settled_for_abandonment(state)
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
                controller_generation=len(updated.recovery_receipts),
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
            else (
                updated.superseded_publications[-1].commitment.commitment_digest
                if updated.superseded_publications
                else ""
            )
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
    edges: list[OrchEdge] = []
    if state.pending_attack != "NONE":
        updated = _append_store_security_event(
            state,
            actor,
            "REJECTED",
            state.pending_attack,
        )
        updated = replace(
            updated,
            pending_attack="NONE",
            pending_attack_context=None,
        )
        edges.append(
            _edge("STORE-029-REJECT-HOSTILE-REQUEST", actor, state, updated)
        )
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
    if (
        state.parent_grant is not None
        and state.primary_state == "FAILED"
        and state.store_head is not None
        and state.store_controller_generation < len(state.recovery_receipts)
        and state.pending_attack == "NONE"
    ):
        new_generation = state.store_controller_generation + 1
        old = state.publication_commitment
        superseded = state.superseded_publications
        superseded_digest = ""
        supersession_digest = ""
        clear_old = bool(
            old is not None
            and old.controller_generation < new_generation
        )
        if clear_old:
            assert old is not None
            archived = SupersededPublicationAttempt(
                commitment=old,
                durable_ack=state.durable_ack,
                superseded_by_generation=new_generation,
                issuer=actor,
                supersession_digest="",
                auth_tag="",
            )
            archived = replace(
                archived,
                supersession_digest=_supersession_digest(archived),
            )
            archived = replace(
                archived,
                auth_tag=_supersession_auth(archived),
            )
            superseded = superseded + (archived,)
            superseded_digest = old.commitment_digest
            supersession_digest = archived.supersession_digest
        fence = StoreFenceAck(
            schema=SCHEMA,
            parent_run_id=state.parent_grant.parent_run_id,
            binding_digest=parent_binding_digest(state.parent_grant),
            old_controller_generation=state.store_controller_generation,
            new_controller_generation=new_generation,
            superseded_commitment_digest=superseded_digest,
            supersession_digest=supersession_digest,
            observed_head=state.store_head,
            issuer=actor,
            auth_tag="",
        )
        fence = replace(fence, auth_tag=_store_fence_auth(fence))
        updated = replace(
            state,
            publication_commitment=None if clear_old else old,
            durable_ack=None if clear_old else state.durable_ack,
            superseded_publications=superseded,
            store_controller_generation=new_generation,
            store_fence_ack=fence,
        )
        if state.publication == "FENCE_PENDING":
            updated = replace(
                updated,
                phase="PUBLICATION_FENCED",
                publication="FENCED",
            )
        edges.append(
            _edge(
                "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
                actor,
                state,
                updated,
            )
        )

    if (
        state.phase == "PREPARED"
        and state.publication == "PREPARED"
        and _current_publication_authority(state)
    ):
        assert state.publication_commitment is not None
        ack = DurableAck(
            commitment_digest=state.publication_commitment.commitment_digest,
            generation=state.publication_commitment.expected_generation,
            controller_generation=state.publication_commitment.controller_generation,
            observation_generation=len(state.recovery_receipts),
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

    if (
        state.phase == "PUBLICATION_FENCE_PENDING"
        and state.publication == "FENCE_PENDING"
        and state.publication_commitment is not None
        and state.publication_commitment.controller_generation
        == state.store_controller_generation
        and state.store_controller_generation < len(state.recovery_receipts)
        and state.durable_ack is None
    ):
        ack = DurableAck(
            commitment_digest=state.publication_commitment.commitment_digest,
            generation=state.publication_commitment.expected_generation,
            controller_generation=state.publication_commitment.controller_generation,
            observation_generation=len(state.recovery_receipts),
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_durable_ack_auth(ack))
        updated = replace(state, durable_ack=ack)
        edges.append(
            _edge("STORE-019A-ACK-OLD-PRE-FENCE", actor, state, updated)
        )

    if (
        state.phase == "DURABLE"
        and state.publication == "DURABLE"
        and state.owner_state == "ACTIVE"
        and state.pending_attack == "NONE"
        and state.store_head is not None
        and state.store_head.content_kind == "EMPTY"
        and _current_publication_authority(state)
    ):
        assert state.publication_commitment is not None
        commitment = state.publication_commitment
        expected = commitment.expected_generation
        ack = PublicationAck(
            commitment_digest=commitment.commitment_digest,
            old_generation=expected,
            new_generation=expected + 1,
            controller_generation=commitment.controller_generation,
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_publication_ack_auth(ack))
        updated = replace(
            state,
            phase="TERMINAL",
            publication="PUBLISHED",
            publication_ack=ack,
            store_head=_publication_store_head(commitment),
        )
        edges.append(_edge("STORE-020-PUBLISH-CAS", actor, state, updated))

    if (
        state.phase == "PUBLICATION_FENCE_PENDING"
        and state.publication == "FENCE_PENDING"
        and state.owner_state == "ACTIVE"
        and state.pending_attack == "NONE"
        and state.publication_commitment is not None
        and state.durable_ack is not None
        and state.store_head is not None
        and state.store_head.content_kind == "EMPTY"
        and state.publication_commitment.controller_generation
        == state.store_controller_generation
        and state.store_controller_generation < len(state.recovery_receipts)
    ):
        commitment = state.publication_commitment
        expected = commitment.expected_generation
        ack = PublicationAck(
            commitment_digest=commitment.commitment_digest,
            old_generation=expected,
            new_generation=expected + 1,
            controller_generation=commitment.controller_generation,
            issuer=actor,
            auth_tag="",
        )
        ack = replace(ack, auth_tag=_publication_ack_auth(ack))
        updated = replace(
            state,
            phase="TERMINAL",
            publication="PUBLISHED",
            publication_ack=ack,
            store_head=_publication_store_head(commitment),
        )
        edges.append(
            _edge(
                "STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS",
                actor,
                state,
                updated,
            )
        )

    if (
        state.publication in {"PREPARED", "DURABLE"}
        and state.owner_state == "ACTIVE"
        and state.pending_attack == "NONE"
        and state.store_head is not None
        and state.store_head.content_kind != "EMPTY"
        and _current_publication_authority(state)
    ):
        updated = replace(
            state,
            phase="TERMINAL",
            publication="STALE_REJECTED",
        )
        edges.append(_edge("STORE-021-HEAD-CONFLICT", actor, state, updated))

    if (
        state.publication == "ABANDONING"
        and state.abandonment_commitment is not None
        and state.abandonment_ack is None
        and _children_settled_for_abandonment(state)
        and state.pending_attack == "NONE"
        and state.store_head is not None
        and state.store_controller_generation == len(state.recovery_receipts)
    ):
        commitment = state.abandonment_commitment
        expected = commitment.expected_generation
        if state.store_head.content_kind == "EMPTY":
            ack = AbandonmentAck(
                commitment_digest=commitment.commitment_digest,
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
                store_head=_abandonment_store_head(
                    commitment,
                    state.store_controller_generation,
                ),
            )
            edges.append(
                _edge(
                    "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",
                    actor,
                    state,
                    updated,
                )
            )
        else:
            assert state.parent_grant is not None
            notice = AbandonmentConflictNotice(
                schema=SCHEMA,
                parent_run_id=state.parent_grant.parent_run_id,
                binding_digest=parent_binding_digest(state.parent_grant),
                commitment_digest=commitment.commitment_digest,
                expected_generation=expected,
                observed_head=state.store_head,
                issuer=actor,
                auth_tag="",
            )
            notice = replace(
                notice,
                auth_tag=_abandonment_conflict_auth(notice),
            )
            conflict = replace(
                state,
                phase="ASSURANCE_BREACHED",
                publication="ASSURANCE_BREACHED",
                abandonment_conflict_notice=notice,
                assurance_breach="ABANDONMENT_HEAD_CONFLICT",
            )
            edges.append(
                _edge(
                    "STORE-026B-TOMBSTONE-HEAD-CONFLICT",
                    actor,
                    state,
                    conflict,
                )
            )
    return tuple(edges)


def concurrent_store_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if (
        state.parent_grant is None
        or state.store_head is None
        or state.store_head.content_kind != "EMPTY"
        or state.publication in TERMINAL_PUBLICATIONS
        or state.pending_attack != "NONE"
    ):
        return ()
    updated = replace(state, store_head=_foreign_store_head(state))
    return (
        _edge(
            "EXT-018C-ADVANCE-STORE-HEAD",
            "CONCURRENT_STORE_WRITER",
            state,
            updated,
        ),
    )


def adversary_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.publication in TERMINAL_PUBLICATIONS:
        return ()
    edges: list[OrchEdge] = []
    actor = "ADVERSARY"
    if (
        state.primary_state == "FAILED"
        and state.guardian_state == "ACTIVE"
        and state.pending_attack == "NONE"
    ):
        breached = replace(
            state,
            phase="ASSURANCE_BREACHED",
            guardian_state="FAILED",
            publication="ASSURANCE_BREACHED",
            assurance_breach="GUARDIAN_FAILURE",
        )
        edges.append(_edge("ADV-031-FAIL-GUARDIAN", actor, state, breached))
    if state.pending_attack == "NONE":
        def attempt_edge(action_id: str, attack: str) -> OrchEdge | None:
            context = _make_store_attack_context(state, attack)
            key = StoreAttackKey(attack, context.context_digest)
            if (
                state.attempted_attack_contexts.count(key)
                >= MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT
            ):
                return None
            updated = _append_store_security_event(
                state,
                actor,
                "ATTEMPT",
                attack,
            )
            updated = replace(
                updated,
                pending_attack=attack,
                pending_attack_context=context,
            )
            return _edge(action_id, actor, state, updated)

        if state.parent_grant is not None:
            edge = attempt_edge(
                STORE_ATTACK_SPECS["GRANT_REPLAY"].action_id,
                "GRANT_REPLAY",
            )
            if edge is not None:
                edges.append(edge)
        if state.publication in {"PREPARED", "DURABLE"}:
            edge = attempt_edge(
                STORE_ATTACK_SPECS["PUBLICATION_ROLLBACK"].action_id,
                "PUBLICATION_ROLLBACK",
            )
            if edge is not None:
                edges.append(edge)
        if (
            state.owner_state == "FAILED"
            and state.publication == "ABANDONING"
            and state.publication_commitment is not None
        ):
            edge = attempt_edge(
                STORE_ATTACK_SPECS["POST_OWNER_PUBLISH"].action_id,
                "POST_OWNER_PUBLISH",
            )
            if edge is not None:
                edges.append(edge)
        if state.superseded_publications and state.store_fence_ack is not None:
            edge = attempt_edge(
                STORE_ATTACK_SPECS["SUPERSEDED_PUBLICATION"].action_id,
                "SUPERSEDED_PUBLICATION",
            )
            if edge is not None:
                edges.append(edge)
    edges.append(_edge("ADV-030-STALL", actor, state, state))
    return tuple(edges)


def hostile_store_bypass_next(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if state.pending_attack == "NONE":
        return ()
    reason = STORE_ATTACK_SPECS[state.pending_attack].breach
    breached = replace(
        state,
        phase="ASSURANCE_BREACHED",
        publication="ASSURANCE_BREACHED",
        pending_attack="NONE",
        pending_attack_context=None,
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


def next_states(state: OrchestratorState) -> tuple[OrchEdge, ...]:
    if not orchestrator_wf(state):
        raise OrchestratorReject("F05-ORCH-STATE-WF", state.phase)
    if state.publication in TERMINAL_PUBLICATIONS:
        return ()
    edges = (
        external_next(state)
        + supervisor_next(state)
        + child_next(state)
        + guardian_next(state)
        + store_next(state)
        + concurrent_store_next(state)
        + adversary_next(state)
        + hostile_store_bypass_next(state)
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


def reachable_states() -> OrchestratorReachabilityGraph:
    """Enumerate exact reachability without per-edge or dict-entry objects."""

    maximum_index = (1 << 32) - 1
    start = initial_state()
    key = semantic_projection(start)
    states = child.CompactExactStateStore(
        OrchestratorState,
        PARENT_STATE_REFERENCE_FIELDS,
    )
    representatives = child.ExactStateIndex(states)
    start_index, start_is_new = representatives.intern(key)
    if start_index != 0 or not start_is_new:
        raise RuntimeError("initial parent exact state was not uniquely interned")
    frontier_indices = array("I", [start_index])
    frontier_cursor = 0
    edge_offsets = array("I", [0])
    target_indices = array("I")
    action_indices = array("B")
    while frontier_cursor < len(frontier_indices):
        source_index = frontier_indices[frontier_cursor]
        frontier_cursor += 1
        state = states[source_index]
        for edge in next_states(state):
            target_key = semantic_projection(edge.state)
            target_index, target_is_new = representatives.intern(target_key)
            if target_is_new:
                frontier_indices.append(target_index)
            if len(target_indices) >= maximum_index:
                raise OrchestratorReject(
                    "F05-ORCH-GRAPH-EDGE-BOUND",
                    str(len(target_indices)),
                )
            target_indices.append(target_index)
            action_indices.append(ACTION_INDEX[edge.action_id])
        edge_offsets.append(len(target_indices))
    states.freeze()
    if len(states) != len(representatives):
        raise RuntimeError("parent state vector and compact index diverged")
    del representatives, frontier_indices
    return OrchestratorReachabilityGraph(
        states=states,
        edge_offsets=edge_offsets,
        target_indices=target_indices,
        action_indices=action_indices,
    )


def _coaccessible_state_count(
    graph: OrchestratorReachabilityGraph,
    terminal_indices: array,
) -> int:
    state_count = len(graph.states)
    incoming_counts = array("I", [0]) * state_count
    for target_index in graph.target_indices:
        if incoming_counts[target_index] == (1 << 32) - 1:
            raise OrchestratorReject(
                "F05-ORCH-GRAPH-INDEGREE-BOUND",
                str(target_index),
            )
        incoming_counts[target_index] += 1
    incoming_offsets = array("I", [0])
    running = 0
    for count in incoming_counts:
        running += count
        if running > (1 << 32) - 1:
            raise OrchestratorReject(
                "F05-ORCH-GRAPH-REVERSE-BOUND",
                str(running),
            )
        incoming_offsets.append(running)
    cursor = incoming_offsets[:-1]
    incoming_sources = array("I", [0]) * graph.edge_count
    for source_index in range(state_count):
        begin = graph.edge_offsets[source_index]
        end = graph.edge_offsets[source_index + 1]
        for edge_index in range(begin, end):
            target_index = graph.target_indices[edge_index]
            position = cursor[target_index]
            incoming_sources[position] = source_index
            cursor[target_index] += 1

    coaccessible = bytearray(state_count)
    queue: deque[int] = deque()
    for terminal_index in terminal_indices:
        if not coaccessible[terminal_index]:
            coaccessible[terminal_index] = 1
            queue.append(terminal_index)
    count = len(queue)
    while queue:
        target_index = queue.popleft()
        begin = incoming_offsets[target_index]
        end = incoming_offsets[target_index + 1]
        for position in range(begin, end):
            source_index = incoming_sources[position]
            if not coaccessible[source_index]:
                coaccessible[source_index] = 1
                count += 1
                queue.append(source_index)
    return count


def explore() -> dict[str, object]:
    graph = reachable_states()
    states = graph.states
    terminal_indices = array("I")
    terminal_counts: Counter[str] = Counter()
    actions: set[int] = set()
    deadlocks = 0
    multiple_store_attack_contexts = 0
    owner_failure_with_pending_attack = 0
    post_owner_publish_attacks = 0
    guardian_generation_capsules = 0
    for state_index, state in enumerate(states):
        if len(state.store_attack_attempts) >= 2:
            multiple_store_attack_contexts += 1
        if state.owner_state == "FAILED" and state.pending_attack != "NONE":
            owner_failure_with_pending_attack += 1
        if "POST_OWNER_PUBLISH" in state.store_attack_attempts:
            post_owner_publish_attacks += 1
        if (
            state.local_capsule is not None
            and state.local_capsule.controller_generation == 1
            and state.local_capsule.issuer == "RECOVERY_GUARDIAN"
        ):
            guardian_generation_capsules += 1
        has_outgoing = (
            graph.edge_offsets[state_index]
            != graph.edge_offsets[state_index + 1]
        )
        if state.publication in TERMINAL_PUBLICATIONS:
            terminal_indices.append(state_index)
            terminal_counts[state.publication] += 1
            if has_outgoing:
                raise OrchestratorReject("F05-ORCH-TERMINAL-EDGE", state.publication)
        elif not has_outgoing:
            deadlocks += 1
    for edge_index, target_index in enumerate(graph.target_indices):
        action_index = graph.action_indices[edge_index]
        actions.add(action_index)
        if states[target_index].semantic_verdict is not None:
            raise OrchestratorReject(
                "F05-ORCH-SEMANTIC-SELF-ISSUE",
                ACTION_IDS[action_index],
            )
    coaccessible_count = _coaccessible_state_count(graph, terminal_indices)
    return {
        "exploration_semantics": (
            "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL"
        ),
        "reachable_repetition_bounded_state_count": len(states),
        "edge_count": graph.edge_count,
        "terminal_counts": dict(sorted(terminal_counts.items())),
        "nonterminal_deadlock_count": deadlocks,
        "states_without_terminal_path": len(states) - coaccessible_count,
        "declared_action_count": len(ACTION_SPECS),
        "reachable_action_count": len(actions),
        "missing_actions": sorted(
            set(ACTION_SPECS) - {ACTION_IDS[index] for index in actions}
        ),
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
        "store_attack_repetition_policy": (
            "FIRST_ATTEMPT_PER_TYPED_CONTEXT_REPETITION_BOUND"
        ),
        "max_store_attack_attempts_per_typed_context": (
            MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT
        ),
        "repetition_bounded_state_space_exhaustive": True,
        "unbounded_attack_history_frontier_empty": False,
        "partial_order_reduction_applied": False,
        "partial_order_equivalence_proved": False,
        "unbounded_repeated_store_attack_history_exhaustive": False,
        "attack_context_key_refinement_proved": False,
        "multiple_store_attack_context_state_count": (
            multiple_store_attack_contexts
        ),
        "owner_failure_with_pending_attack_state_count": (
            owner_failure_with_pending_attack
        ),
        "post_owner_publish_attack_state_count": post_owner_publish_attacks,
        "guardian_generation_capsule_state_count": guardian_generation_capsules,
        "abandoned_terminal_requires_matching_ack": True,
        "typed_abandonment_conflict_withholds_assurance": True,
        "abandonment_conflict_breach_terminal_count": sum(
            1
            for terminal_index in terminal_indices
            for state in (states[terminal_index],)
            if state.assurance_breach
            == "ABANDONMENT_HEAD_CONFLICT"
        ),
        "publication_fence_reauthorization_encoded": True,
        "publication_fence_store_refinement_proved": False,
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
    "ACTION_REQUIRED_WRITE_FIELDS",
    "ACTION_SPECS",
    "ACTION_WRITE_FIELDS",
    "AbandonmentAck",
    "AbandonmentCommitment",
    "AbandonmentConflictNotice",
    "ChildAttachment",
    "ChildCertificate",
    "ChildGrantRetirement",
    "ChildStartBinding",
    "DurableAck",
    "GrantConsumptionAck",
    "LocalDispositionCapsule",
    "MAX_STORE_ATTACK_ATTEMPTS_PER_TYPED_CONTEXT",
    "OPEN_REFINEMENT_OBLIGATIONS",
    "OwnerFailureNotice",
    "OrchestratorReject",
    "OrchestratorState",
    "ParentGrant",
    "ParentReceipt",
    "PublicationAck",
    "PublicationCommitment",
    "RecoveryReceipt",
    "SemanticVerdict",
    "STORE_ATTACK_SPECS",
    "StoreAttackContext",
    "StoreAttackKey",
    "StoreAttackSpec",
    "StoreFenceAck",
    "StoreHead",
    "StoreSecurityEvent",
    "SupersededPublicationAttempt",
    "apply_trace",
    "certificate_from_terminal",
    "child_attachment_wf",
    "child_certificate_wf",
    "child_grant_matches_parent",
    "child_lifecycle_wf",
    "child_next",
    "child_retirement_wf",
    "child_start_binding_wf",
    "concurrent_store_next",
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
    "store_fence_wf",
    "store_next",
    "store_security_hash",
    "store_security_wf",
    "supervisor_next",
]
