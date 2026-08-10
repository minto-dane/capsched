#!/usr/bin/env python3
"""Actor-separated pre-normative child supervisor-envelope LTS v3 candidate-1.

This module is an executable abstract machine.  It deliberately does not claim
that Linux implements its observer, authentication, containment, quota, or
durability assumptions.  Those are named refinement obligations.
"""

from __future__ import annotations

from collections import Counter, defaultdict, deque
from dataclasses import dataclass, replace
from functools import lru_cache
from hashlib import sha256
from itertools import combinations
from typing import Iterable


SCHEMA = "F0-SPV3-C1"
AUTH_MODEL = "SYMBOLIC_PERFECT_AUTHENTICATION_ASSUMPTION"

ROLES = {"PRODUCER", "CHECKER"}
PHASES = {
    "NEW",
    "SCOPE_REQUESTED",
    "SCOPE_CONFIGURED",
    "BOOTSTRAP_REQUESTED",
    "BOOTSTRAP_HELD",
    "SANDBOX_REQUESTED",
    "READY",
    "RUNNING",
    "STOPPING",
    "QUIESCENT",
    "DECIDED",
    "BREACHED",
}
SCOPES = {
    "UNCREATED",
    "REQUESTED",
    "CONFIGURED_EMPTY",
    "LIVE",
    "ATTACH_CLOSED",
    "HIDDEN_DRAINED",
    "CSS_OFFLINE",
    "RELEASED",
}
VISIBLE_POPULATIONS = {"UNKNOWN", "EMPTY", "NONEMPTY"}
TASK_POPULATIONS = {"UNKNOWN", "EMPTY", "NONEMPTY"}
ASYNC_ADMISSIONS = {"UNBOUND", "OPEN", "CLOSED"}
EXECUTION_AUTHORITIES = {"UNBOUND", "ACTIVE", "REVOKED"}
PROTECTION_STATES = {"OPEN", "EXECUTION_REVOKED", "CLOSED", "BREACHED"}
MAX_REACQUISITIONS = 2
ATTACH_AUTHORITIES = {"UNBOUND", "EXTERNAL_EXCLUSIVE", "CLOSED"}
LEADERS = {"ABSENT", "TRUSTED_HELD", "HOSTILE_RUNNING", "EXITED", "REAPED"}
DESCENDANTS = {"NONE", "LIVE", "EXITED"}
ASYNC_REFS = {"NONE", "LIVE", "DRAINED"}
HIDDEN_WORK = {"NONE", "ACTIVE", "PENDING", "DRAINED"}
SANDBOXES = {"UNVERIFIED", "REQUESTED", "ATTESTED"}
PAYLOADS = {"HELD", "RELEASED"}
WRITER_CONFINEMENT = {"UNVERIFIED", "CONFINED", "CLOSED"}
STREAMS = {"UNOPENED", "OPEN", "FRAME", "EOF_VALID", "EOF_TRUNCATED", "EOF_INVALID"}
CANDIDATE_KINDS = {"NONE", "PRODUCER_RESULT", "CHECKER_ACCEPT", "CHECKER_REJECT", "INTERNAL"}
CANDIDATE_VALUES = {"NONE", "VALUE_A", "VALUE_B", "ACCEPT", "REJECT", "INTERNAL"}
WAITS = {"NONE", "NORMAL", "SIGNALLED", "ABNORMAL"}
RESOURCE_EVENTS = {"NONE", "MONITOR_PROVED", "LINUX_UNATTRIBUTED"}
ENFORCEMENTS = {"NONE", "TERMINATION_REQUESTED"}
WINNERS = {"OPEN", "COMPLETION", "QUOTA", "FAULT"}
COUNTERS = {"NONE", "BASELINE", "FINAL", "FAILED"}
FAULTS = {"CLEAN", "STICKY"}
LEDGERS = {"OPEN", "SEALED"}
LOCAL_DECISIONS = {
    "NONE",
    "LOCAL_SYNTACTIC_CANDIDATE",
    "INCONCLUSIVE_RESOURCE",
    "INTERNAL_FAILURE",
    "ABANDONED",
}
OWNER_STATES = {"ACTIVE", "REVOKED"}
PRIMARY_STATES = {"ACTIVE", "FAILED"}
CONTROLLERS = {"PRIMARY_SUPERVISOR", "RECOVERY_GUARDIAN"}
PENDING_ATTACKS = {
    "NONE",
    "ATTACH",
    "FD_ESCAPE",
    "PTRACE",
    "FORGED_RECEIPT",
    "REPLAY_RECEIPT",
}
BREACH_KINDS = PENDING_ATTACKS

ACTORS = {
    "PRIMARY_SUPERVISOR",
    "RECOVERY_GUARDIAN",
    "TARGET_LINUX_OBSERVER",
    "MANAGEMENT_DOMAIN_OBSERVER",
    "MONITOR_OBSERVER",
    "LOCAL_ARBITER",
    "EXTERNAL_OWNER",
    "ADVERSARY",
}

OPEN_REFINEMENT_OBLIGATIONS = (
    "EXT-AUTH-001 external RunGrant issuer, freshness, nonce uniqueness, and revocation",
    "LINUX-SCOPE-001 exclusive hierarchy and attach/migration authority",
    "LINUX-BOOT-001 charged trusted bootstrap before hostile payload execution",
    "LINUX-SANDBOX-001 credential namespace seccomp ptrace fd and scheduler closure",
    "LINUX-SCOPE-002 visible empty, subtree empty, attach close, hidden drain, CSS offline, and release receipts",
    "LINUX-ASYNC-001 descendant, io_uring, workqueue, timer, and deferred-work closure",
    "RESOURCE-001 baseline/final subtree accounting and causal event attribution",
    "MONITOR-001 monitor receipt authenticity under hostile Linux kernel execution",
    "TARGET-001 target Linux receipts are candidate/reclamation evidence, never a protection root",
    "MGMT-001 management Domain observer isolation, authority, and non-collusion",
    "HOSTILE-001 explicit bypass terminals must be eliminated only by a lower-layer refinement",
    "GUARDIAN-001 guardian survivability and authority after primary failure",
    "LIVENESS-001 observer delivery and cleanup fairness under killable execution",
    "LIVENESS-002 explicit disposition for uninterruptible tasks and permanent observer silence",
)


class ProtocolReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def _encode(parts: Iterable[object]) -> bytes:
    encoded = []
    for value in parts:
        text = str(value)
        encoded.append(f"{len(text)}:{text}")
    return "|".join(encoded).encode("utf-8")


@lru_cache(maxsize=None)
def digest(label: str, *parts: object) -> str:
    return sha256(_encode((SCHEMA, label, *parts))).hexdigest()


@dataclass(frozen=True)
class RunGrant:
    parent_run_id: str
    child_run_id: str
    role: str
    ordinal: int
    epoch: int
    nonce: str
    validation_context_digest: str
    policy_digest: str
    profile_digest: str
    immutable_input_digest: str
    hierarchy_id: str
    scope_id: str
    subject_id: str
    budget_id: str
    budget_limit: int
    issuer: str
    auth_tag: str


def _grant_payload(grant: RunGrant) -> tuple[object, ...]:
    return (
        grant.parent_run_id,
        grant.child_run_id,
        grant.role,
        grant.ordinal,
        grant.epoch,
        grant.nonce,
        grant.validation_context_digest,
        grant.policy_digest,
        grant.profile_digest,
        grant.immutable_input_digest,
        grant.hierarchy_id,
        grant.scope_id,
        grant.subject_id,
        grant.budget_id,
        grant.budget_limit,
        grant.issuer,
    )


@lru_cache(maxsize=None)
def grant_binding_digest(grant: RunGrant) -> str:
    return digest("RUN_GRANT_BINDING", *_grant_payload(grant))


@lru_cache(maxsize=None)
def _grant_auth_tag(grant: RunGrant) -> str:
    return digest("ABSTRACT_EXTERNAL_OWNER_AUTH", *_grant_payload(grant))


def derive_child_run_id(parent_run_id: str, role: str, ordinal: int, nonce: str) -> str:
    return f"child-{digest('CHILD_RUN_ID', parent_run_id, role, ordinal, nonce)[:24]}"


def fixture_external_grant(
    role: str,
    *,
    parent_run_id: str = "parent-e1-nonce-a",
    epoch: int = 1,
    nonce: str | None = None,
    immutable_input_digest: str = "input-root-a",
) -> RunGrant:
    """Build a finite external-input fixture; no supervisor transition calls it."""

    if role not in ROLES:
        raise ProtocolReject("F05-SPV3-ROLE", role)
    ordinal = 0 if role == "PRODUCER" else 1
    child_nonce = nonce or f"nonce-{role.lower()}-e{epoch}"
    child_run_id = derive_child_run_id(parent_run_id, role, ordinal, child_nonce)
    partial = RunGrant(
        parent_run_id=parent_run_id,
        child_run_id=child_run_id,
        role=role,
        ordinal=ordinal,
        epoch=epoch,
        nonce=child_nonce,
        validation_context_digest="validation-context-root-a",
        policy_digest="policy-root-a",
        profile_digest="profile-root-a",
        immutable_input_digest=immutable_input_digest,
        hierarchy_id="hierarchy-owned-a",
        scope_id=f"scope-{child_run_id}",
        subject_id=f"subject-{child_run_id}",
        budget_id=f"budget-{child_run_id}",
        budget_limit=1,
        issuer="EXTERNAL_OWNER",
        auth_tag="",
    )
    return replace(partial, auth_tag=_grant_auth_tag(partial))


@lru_cache(maxsize=None)
def grant_wf(grant: RunGrant) -> bool:
    expected_ordinal = 0 if grant.role == "PRODUCER" else 1
    return (
        grant.role in ROLES
        and grant.ordinal == expected_ordinal
        and grant.epoch > 0
        and bool(grant.parent_run_id)
        and bool(grant.nonce)
        and grant.child_run_id
        == derive_child_run_id(grant.parent_run_id, grant.role, grant.ordinal, grant.nonce)
        and grant.scope_id == f"scope-{grant.child_run_id}"
        and grant.subject_id == f"subject-{grant.child_run_id}"
        and grant.budget_id == f"budget-{grant.child_run_id}"
        and grant.budget_limit > 0
        and grant.issuer == "EXTERNAL_OWNER"
        and grant.auth_tag == _grant_auth_tag(replace(grant, auth_tag=""))
        and all(
            (
                grant.validation_context_digest,
                grant.policy_digest,
                grant.profile_digest,
                grant.immutable_input_digest,
                grant.hierarchy_id,
            )
        )
    )


@dataclass(frozen=True)
class ReceiptSpec:
    issuers: frozenset[str]
    channel: str
    singleton: bool = True


RECEIPT_SPECS: dict[str, ReceiptSpec] = {
    "SCOPE_REQUESTED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "SCOPE_CONFIGURED_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "BOOTSTRAP_REQUESTED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "CHARGED_BOOTSTRAP_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "MONITOR_EXECUTION_ACTIVATED_ACK": ReceiptSpec(
        frozenset({"MONITOR_OBSERVER"}), "RESOURCE"
    ),
    "SANDBOX_REQUESTED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "SANDBOX_PROFILE_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "BASELINE_COUNTERS": ReceiptSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "HOSTILE_PAYLOAD_RELEASED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "UNTRUSTED_FRAME_OBSERVED": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "STREAM_EOF_VALID": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "STREAM_EOF_TRUNCATED": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "STREAM_EOF_INVALID": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "HOSTILE_ATTEMPT_REJECTED": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "SECURITY"),
    "PRIMARY_FAILOVER": ReceiptSpec(frozenset({"RECOVERY_GUARDIAN"}), "RECOVERY"),
    "OWNER_REVOKED": ReceiptSpec(frozenset({"EXTERNAL_OWNER"}), "EXTERNAL"),
    "MONITOR_QUOTA_ARRIVED": ReceiptSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "QUOTA_LINEARIZED": ReceiptSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "LINUX_LIMIT_UNATTRIBUTED": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "RESOURCE"),
    "TERMINATION_REQUESTED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "WAIT_NORMAL": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "WAIT_SIGNALLED": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "WAIT_ABNORMAL": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "DESCENDANTS_EXITED": ReceiptSpec(
        frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX", singleton=False
    ),
    "ASYNC_REFS_DRAINED": ReceiptSpec(
        frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT", singleton=False
    ),
    "COMPLETION_LINEARIZED": ReceiptSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "FAULT_LINEARIZED": ReceiptSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "LEADER_REAPED": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "VISIBLE_EMPTY_ACK": ReceiptSpec(
        frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX", singleton=False
    ),
    "RMDIR_ATTACH_CLOSED_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "ASYNC_ADMISSION_CLOSED": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
    "EXECUTION_REVOKED_ACK": ReceiptSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "MONITOR_PROTECTION_CLOSED_ACK": ReceiptSpec(
        frozenset({"MONITOR_OBSERVER"}), "RESOURCE"
    ),
    "TASK_POPULATION_ZERO_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "HIDDEN_WORK_DRAINED_ACK": ReceiptSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "MANAGEMENT"),
    "FINAL_COUNTERS": ReceiptSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "FINAL_COUNTERS_FAILED": ReceiptSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "CSS_OFFLINE_ACK": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "SCOPE_RELEASED_ACK": ReceiptSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "TARGET_LINUX"),
    "EVIDENCE_SEAL": ReceiptSpec(frozenset(CONTROLLERS), "CONTROL"),
}


@dataclass(frozen=True)
class Receipt:
    schema: str
    run_id: str
    binding_digest: str
    scope_id: str
    subject_id: str
    sequence: int
    kind: str
    payload: str
    payload_digest: str
    issuer: str
    channel: str
    previous_hash: str
    auth_tag: str


def _receipt_body(receipt: Receipt) -> tuple[object, ...]:
    return (
        receipt.schema,
        receipt.run_id,
        receipt.binding_digest,
        receipt.scope_id,
        receipt.subject_id,
        receipt.sequence,
        receipt.kind,
        receipt.payload,
        receipt.payload_digest,
        receipt.issuer,
        receipt.channel,
        receipt.previous_hash,
    )


@lru_cache(maxsize=None)
def receipt_hash(receipt: Receipt) -> str:
    return digest("RECEIPT_HASH", *_receipt_body(receipt), receipt.auth_tag)


@lru_cache(maxsize=None)
def _receipt_auth_tag(receipt: Receipt) -> str:
    return digest("ABSTRACT_ISSUER_AUTH", *_receipt_body(receipt))


@lru_cache(maxsize=None)
def genesis_hash(grant: RunGrant) -> str:
    return digest("EVIDENCE_GENESIS", grant_binding_digest(grant), grant.child_run_id)


@lru_cache(maxsize=None)
def receipt_wf(receipt: Receipt, grant: RunGrant, previous_hash: str, sequence: int) -> bool:
    spec = RECEIPT_SPECS.get(receipt.kind)
    return bool(
        spec
        and receipt.schema == SCHEMA
        and receipt.run_id == grant.child_run_id
        and receipt.binding_digest == grant_binding_digest(grant)
        and receipt.scope_id == grant.scope_id
        and receipt.subject_id == grant.subject_id
        and receipt.sequence == sequence
        and receipt.payload_digest == digest("RECEIPT_PAYLOAD", receipt.kind, receipt.payload)
        and receipt.issuer in spec.issuers
        and receipt.channel == spec.channel
        and receipt.previous_hash == previous_hash
        and receipt.auth_tag == _receipt_auth_tag(replace(receipt, auth_tag=""))
    )


def receipt_payload_wf(state: EnvelopeState, receipt: Receipt) -> bool:
    grant = state.grant
    fixed = {
        "SCOPE_REQUESTED": grant.scope_id,
        "SCOPE_CONFIGURED_ACK": f"{grant.hierarchy_id}:{grant.scope_id}:exclusive",
        "BOOTSTRAP_REQUESTED": grant.scope_id,
        "CHARGED_BOOTSTRAP_ACK": f"{grant.scope_id}:held-before-hostile-exec",
        "MONITOR_EXECUTION_ACTIVATED_ACK": (
            f"{grant.child_run_id}:epoch={grant.epoch}:activated-held"
        ),
        "SANDBOX_REQUESTED": grant.profile_digest,
        "SANDBOX_PROFILE_ACK": f"{grant.profile_digest}:payload-held:fd-confined",
        "BASELINE_COUNTERS": f"{grant.budget_id}:epoch={grant.epoch}:value=0",
        "HOSTILE_PAYLOAD_RELEASED": f"{grant.subject_id}:{grant.profile_digest}",
        "STREAM_EOF_TRUNCATED": "no-complete-frame",
        "OWNER_REVOKED": f"epoch={grant.epoch}",
        "LINUX_LIMIT_UNATTRIBUTED": f"{grant.budget_id}:causality-unproved",
        "WAIT_NORMAL": "leader-normal-exit",
        "WAIT_SIGNALLED": "controller-termination",
        "WAIT_ABNORMAL": "unattributed-abnormal-exit",
        "LEADER_REAPED": grant.subject_id,
        "RMDIR_ATTACH_CLOSED_ACK": f"{grant.scope_id}:no-future-attach",
        "ASYNC_ADMISSION_CLOSED": f"{grant.scope_id}:no-future-async-acquire",
        "EXECUTION_REVOKED_ACK": f"{grant.child_run_id}:epoch={grant.epoch}:revoked",
        "MONITOR_PROTECTION_CLOSED_ACK": (
            f"{grant.child_run_id}:epoch={grant.epoch}:admission-and-execution-closed"
        ),
        "TASK_POPULATION_ZERO_ACK": grant.scope_id,
        "HIDDEN_WORK_DRAINED_ACK": grant.scope_id,
        "FINAL_COUNTERS_FAILED": f"{grant.budget_id}:read-failed",
        "CSS_OFFLINE_ACK": grant.scope_id,
        "SCOPE_RELEASED_ACK": grant.scope_id,
    }
    if receipt.kind in fixed:
        return receipt.payload == fixed[receipt.kind]
    if receipt.kind == "UNTRUSTED_FRAME_OBSERVED":
        return (
            state.candidate_kind != "NONE"
            and receipt.payload
            == _candidate_payload(
                state,
                state.candidate_kind,
                state.candidate_value,
            )
        )
    if receipt.kind == "STREAM_EOF_VALID":
        return bool(state.candidate_digest) and receipt.payload == state.candidate_digest
    if receipt.kind == "STREAM_EOF_INVALID":
        expected = "framing-invalid" if state.candidate_kind == "NONE" else "trailing-or-duplicate-frame"
        return receipt.payload == expected
    if receipt.kind == "HOSTILE_ATTEMPT_REJECTED":
        return state.attack_seen != "NONE" and receipt.payload == state.attack_seen
    if receipt.kind == "PRIMARY_FAILOVER":
        if not receipt.payload.startswith("phase="):
            return False
        return receipt.payload.removeprefix("phase=") in PHASES
    if receipt.kind == "MONITOR_QUOTA_ARRIVED":
        return receipt.payload == (
            f"{grant.budget_id}:epoch={grant.epoch}:"
            f"value={state.resource_observed_value}:"
            f"arrival={state.quota_arrival_sequence}"
        )
    if receipt.kind == "TERMINATION_REQUESTED":
        return receipt.payload == f"winner={state.winner}"
    if receipt.kind == "COMPLETION_LINEARIZED":
        return bool(state.candidate_digest) and receipt.payload == (
            f"{state.candidate_digest}:arrival={state.completion_arrival_sequence}"
        )
    if receipt.kind == "QUOTA_LINEARIZED":
        return receipt.payload == f"arrival={state.quota_arrival_sequence}"
    if receipt.kind == "FAULT_LINEARIZED":
        return receipt.payload == f"arrival={state.fault_arrival_sequence}"
    if receipt.kind == "FINAL_COUNTERS":
        return receipt.payload == (
            f"{grant.budget_id}:epoch={grant.epoch}:value={state.final_value}"
        )
    if receipt.kind == "EVIDENCE_SEAL":
        return receipt.payload == receipt.previous_hash
    if receipt.kind == "DESCENDANTS_EXITED":
        prefix = f"{grant.scope_id}:generation="
        if not receipt.payload.startswith(prefix):
            return False
        try:
            generation = int(receipt.payload.removeprefix(prefix))
        except ValueError:
            return False
        return 1 <= generation <= state.descendant_drained_generation
    if receipt.kind == "VISIBLE_EMPTY_ACK":
        prefix = f"{grant.scope_id}:observation="
        if not receipt.payload.startswith(prefix):
            return False
        try:
            observation = int(receipt.payload.removeprefix(prefix))
        except ValueError:
            return False
        return 1 <= observation <= state.visible_empty_observations
    if receipt.kind == "ASYNC_REFS_DRAINED":
        prefix = f"{grant.scope_id}:generation="
        if not receipt.payload.startswith(prefix):
            return False
        try:
            generation = int(receipt.payload.removeprefix(prefix))
        except ValueError:
            return False
        return 1 <= generation <= state.async_drained_generation
    return False


@dataclass(frozen=True)
class DecisionReceipt:
    schema: str
    run_id: str
    binding_digest: str
    evidence_root: str
    decision: str
    payload_kind: str
    payload_digest: str
    issuer: str
    auth_tag: str


def _decision_body(receipt: DecisionReceipt) -> tuple[object, ...]:
    return (
        receipt.schema,
        receipt.run_id,
        receipt.binding_digest,
        receipt.evidence_root,
        receipt.decision,
        receipt.payload_kind,
        receipt.payload_digest,
        receipt.issuer,
    )


def _decision_auth_tag(receipt: DecisionReceipt) -> str:
    return digest("ABSTRACT_DECISION_AUTH", *_decision_body(receipt))


@dataclass(frozen=True)
class RecoveryReceipt:
    schema: str
    run_id: str
    binding_digest: str
    sequence: int
    observed_phase: str
    evidence_prefix_hash: str
    reason: str
    failed_controller: str
    fence_generation: int
    issuer: str
    auth_tag: str


def _recovery_auth_tag(receipt: RecoveryReceipt) -> str:
    return digest(
        "ABSTRACT_RECOVERY_AUTH",
        receipt.schema,
        receipt.run_id,
        receipt.binding_digest,
        receipt.sequence,
        receipt.observed_phase,
        receipt.evidence_prefix_hash,
        receipt.reason,
        receipt.failed_controller,
        receipt.fence_generation,
        receipt.issuer,
    )


@dataclass(frozen=True)
class EnvelopeState:
    grant: RunGrant
    phase: str = "NEW"
    owner_state: str = "ACTIVE"
    primary_state: str = "ACTIVE"
    controller: str = "PRIMARY_SUPERVISOR"
    scope: str = "UNCREATED"
    visible_population: str = "UNKNOWN"
    visible_empty_observations: int = 0
    task_population: str = "UNKNOWN"
    attach_authority: str = "UNBOUND"
    async_admission: str = "UNBOUND"
    execution_authority: str = "UNBOUND"
    protection_state: str = "OPEN"
    leader: str = "ABSENT"
    descendants: str = "NONE"
    descendant_generation: int = 0
    descendant_drained_generation: int = 0
    async_refs: str = "NONE"
    async_generation: int = 0
    async_drained_generation: int = 0
    hidden_work: str = "NONE"
    sandbox: str = "UNVERIFIED"
    payload: str = "HELD"
    writer_confinement: str = "UNVERIFIED"
    stream: str = "UNOPENED"
    candidate_kind: str = "NONE"
    candidate_value: str = "NONE"
    candidate_digest: str = ""
    wait: str = "NONE"
    resource_event: str = "NONE"
    resource_observed_value: int = 0
    event_clock: int = 0
    completion_arrival_sequence: int = 0
    quota_arrival_sequence: int = 0
    fault_arrival_sequence: int = 0
    enforcement: str = "NONE"
    winner: str = "OPEN"
    winner_sequence: int = 0
    counters: str = "NONE"
    baseline_value: int = 0
    final_value: int = 0
    fault: str = "CLEAN"
    pending_attack: str = "NONE"
    attack_seen: str = "NONE"
    breach_kind: str = "NONE"
    evidence_ledger: str = "OPEN"
    evidence_receipts: tuple[Receipt, ...] = ()
    evidence_root: str = ""
    local_decision: str = "NONE"
    decision_receipt: DecisionReceipt | None = None
    recovery_receipts: tuple[RecoveryReceipt, ...] = ()


@dataclass(frozen=True)
class Edge:
    action_id: str
    actor: str
    state: EnvelopeState


@dataclass(frozen=True)
class ActionSpec:
    actors: frozenset[str]
    category: str


ACTION_SPECS: dict[str, ActionSpec] = {
    "SUP-001-REQUEST-SCOPE": ActionSpec(frozenset(CONTROLLERS), "SETUP"),
    "OBS-002-CONFIGURE-SCOPE-ACK": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "SETUP"),
    "SUP-003-REQUEST-CHARGED-BOOTSTRAP": ActionSpec(frozenset(CONTROLLERS), "SETUP"),
    "OBS-004-CHARGED-BOOTSTRAP-ACK": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "SETUP"),
    "MON-004B-ACTIVATE-EXECUTION": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "SETUP"),
    "SUP-005-REQUEST-SANDBOX": ActionSpec(frozenset(CONTROLLERS), "SETUP"),
    "OBS-006-SANDBOX-PROFILE-ACK": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "SETUP"),
    "MON-007-BASELINE-COUNTERS": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "SETUP"),
    "SUP-008-RELEASE-HOSTILE-PAYLOAD": ActionSpec(frozenset(CONTROLLERS), "SETUP"),
    "OBS-009A-PRODUCER-CANDIDATE-A": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-009B-PRODUCER-CANDIDATE-B": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-010-CHECKER-ACCEPT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-011-CHECKER-REJECT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-012-INTERNAL-FRAME": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-013-EOF-VALID": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-014-EOF-TRUNCATED": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "OBS-015-EOF-INVALID": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "STREAM"),
    "ADV-016-FORK-DESCENDANT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-017-OPEN-ASYNC-REF": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-018-ATTACH-ATTEMPT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-019-FD-ESCAPE-ATTEMPT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-020-PTRACE-ATTEMPT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-021-FORGED-RECEIPT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "ADV-022-REPLAY-RECEIPT": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "OBS-023-REJECT-HOSTILE-ATTEMPT": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "HOSTILE"),
    "ADV-023B-SUCCEED-HOSTILE-BYPASS": ActionSpec(frozenset({"ADVERSARY"}), "HOSTILE"),
    "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH": ActionSpec(frozenset({"RECOVERY_GUARDIAN"}), "RECOVERY"),
    "EXT-025-REVOKE-RUN": ActionSpec(frozenset({"EXTERNAL_OWNER"}), "RECOVERY"),
    "MON-026-QUOTA-ARRIVAL": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "RESOURCE"),
    "ARB-026B-QUOTA-WINS": ActionSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "OBS-027-UNATTRIBUTED-LIMIT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "RESOURCE"),
    "SUP-028-REQUEST-TERMINATION": ActionSpec(frozenset(CONTROLLERS), "CONTROL"),
    "OBS-029-NORMAL-EXIT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "EXIT"),
    "OBS-030-SIGNAL-EXIT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "EXIT"),
    "OBS-031-ABNORMAL-EXIT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "EXIT"),
    "OBS-032-DESCENDANTS-EXIT": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "EXIT"),
    "OBS-033-ASYNC-REFS-DRAIN": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "CLEANUP"),
    "ARB-034-COMPLETION-WINS": ActionSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "ARB-035-FAULT-WINS": ActionSpec(frozenset({"LOCAL_ARBITER"}), "ARBITRATION"),
    "OBS-036-LEADER-REAPED": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "CLEANUP"),
    "OBS-037-VISIBLE-EMPTY": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "CLEANUP"),
    "OBS-038-TASK-POPULATION-ZERO": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "CLEANUP"),
    "OBS-039-RMDIR-ATTACH-CLOSED": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "CLEANUP"),
    "SUP-039B-CLOSE-ASYNC-ADMISSION": ActionSpec(frozenset(CONTROLLERS), "CLEANUP"),
    "MON-039C-PROTECTION-CLOSED": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "CLEANUP"),
    "MON-035B-REVOKE-EXECUTION": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "CONTROL"),
    "OBS-040-HIDDEN-WORK-DRAINED": ActionSpec(frozenset({"MANAGEMENT_DOMAIN_OBSERVER"}), "CLEANUP"),
    "MON-041-FINAL-COUNTERS": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "CLEANUP"),
    "MON-041B-FINAL-OVERLIMIT-QUOTA": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "CLEANUP"),
    "MON-042-FINAL-COUNTERS-FAILED": ActionSpec(frozenset({"MONITOR_OBSERVER"}), "CLEANUP"),
    "OBS-043-CSS-OFFLINE": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "CLEANUP"),
    "OBS-044-SCOPE-RELEASED": ActionSpec(frozenset({"TARGET_LINUX_OBSERVER"}), "CLEANUP"),
    "SUP-045-SEAL-EVIDENCE": ActionSpec(frozenset(CONTROLLERS), "EVIDENCE"),
    "SUP-046-DECIDE-LOCAL": ActionSpec(frozenset(CONTROLLERS), "DECISION"),
    "ADV-047-STALL": ActionSpec(frozenset({"ADVERSARY"}), "STUTTER"),
}

ACTION_IDS = tuple(ACTION_SPECS)


@dataclass(frozen=True)
class Exploration:
    role: str
    reachable_semantic_state_count: int
    retained_evidence_witness_count: int
    edge_count: int
    reachable_action_count: int
    reachable_action_ids: tuple[str, ...]
    terminal_state_count: int
    decision_counts: tuple[tuple[str, int], ...]
    nonterminal_deadlock_count: int
    states_without_terminal_path: int
    winner_overwrite_count: int
    protection_breach_terminal_count: int
    hostile_bypass_explicit: bool
    coaccessibility_only: bool
    universal_termination_proved: bool
    infinite_stutter_counterexample_present: bool
    management_domain_refinement_proved: bool
    monitor_protection_refinement_proved: bool
    external_assumptions_discharged: bool
    linux_refinement_proved: bool
    semantic_verdict_issued: bool
    ordered_trace_states_exhaustively_enumerated: bool


def initial_state(grant: RunGrant) -> EnvelopeState:
    if not grant_wf(grant):
        raise ProtocolReject("F05-SPV3-GRANT-WF", grant.child_run_id)
    return EnvelopeState(grant=grant)


def _last_evidence_hash(state: EnvelopeState) -> str:
    if not state.evidence_receipts:
        return genesis_hash(state.grant)
    return receipt_hash(state.evidence_receipts[-1])


def _append_receipt(state: EnvelopeState, issuer: str, kind: str, payload: str) -> EnvelopeState:
    if state.evidence_ledger != "OPEN":
        raise ProtocolReject("F05-SPV3-LEDGER-SEALED", kind)
    spec = RECEIPT_SPECS.get(kind)
    if spec is None or issuer not in spec.issuers:
        raise ProtocolReject("F05-SPV3-ISSUER", f"{kind}:{issuer}")
    receipt = Receipt(
        schema=SCHEMA,
        run_id=state.grant.child_run_id,
        binding_digest=grant_binding_digest(state.grant),
        scope_id=state.grant.scope_id,
        subject_id=state.grant.subject_id,
        sequence=len(state.evidence_receipts) + 1,
        kind=kind,
        payload=payload,
        payload_digest=digest("RECEIPT_PAYLOAD", kind, payload),
        issuer=issuer,
        channel=spec.channel,
        previous_hash=_last_evidence_hash(state),
        auth_tag="",
    )
    receipt = replace(receipt, auth_tag=_receipt_auth_tag(receipt))
    return replace(state, evidence_receipts=state.evidence_receipts + (receipt,))


def _append_recovery_receipt(state: EnvelopeState) -> EnvelopeState:
    receipt = RecoveryReceipt(
        schema=SCHEMA,
        run_id=state.grant.child_run_id,
        binding_digest=grant_binding_digest(state.grant),
        sequence=len(state.recovery_receipts) + 1,
        observed_phase=state.phase,
        evidence_prefix_hash=_last_evidence_hash(state),
        reason="PRIMARY_CRASH",
        failed_controller="PRIMARY_SUPERVISOR",
        fence_generation=1,
        issuer="RECOVERY_GUARDIAN",
        auth_tag="",
    )
    receipt = replace(receipt, auth_tag=_recovery_auth_tag(receipt))
    return replace(state, recovery_receipts=state.recovery_receipts + (receipt,))


def _controller(state: EnvelopeState) -> str:
    return state.controller


def _candidate_payload(state: EnvelopeState, kind: str, value: str) -> str:
    return "|".join(
        (
            kind,
            value,
            state.grant.role,
            state.grant.immutable_input_digest,
            state.grant.validation_context_digest,
        )
    )


def _expected_candidate_digest(state: EnvelopeState, kind: str, value: str) -> str:
    return digest("LOCAL_CANDIDATE_PAYLOAD", _candidate_payload(state, kind, value))


def _receipt_counts(state: EnvelopeState) -> Counter[str]:
    return Counter(receipt.kind for receipt in state.evidence_receipts)


@lru_cache(maxsize=None)
def evidence_wf(state: EnvelopeState) -> bool:
    previous = genesis_hash(state.grant)
    counts: Counter[str] = Counter()
    for sequence, receipt in enumerate(state.evidence_receipts, start=1):
        if not (
            receipt_wf(receipt, state.grant, previous, sequence)
            and receipt_payload_wf(state, receipt)
        ):
            return False
        counts[receipt.kind] += 1
        spec = RECEIPT_SPECS[receipt.kind]
        if spec.singleton and counts[receipt.kind] > 1:
            return False
        previous = receipt_hash(receipt)

    positions = {
        receipt.kind: index
        for index, receipt in enumerate(state.evidence_receipts)
    }

    def require_before(before: str, after: str) -> bool:
        if after not in positions:
            return True
        return before in positions and positions[before] < positions[after]

    setup_chain = (
        "SCOPE_REQUESTED",
        "SCOPE_CONFIGURED_ACK",
        "BOOTSTRAP_REQUESTED",
        "CHARGED_BOOTSTRAP_ACK",
        "MONITOR_EXECUTION_ACTIVATED_ACK",
        "SANDBOX_REQUESTED",
        "SANDBOX_PROFILE_ACK",
        "BASELINE_COUNTERS",
        "HOSTILE_PAYLOAD_RELEASED",
    )
    for before, after in zip(setup_chain, setup_chain[1:]):
        if not require_before(before, after):
            return False

    runtime_receipts = set(RECEIPT_SPECS) - {
        *setup_chain,
        "PRIMARY_FAILOVER",
        "EVIDENCE_SEAL",
    }
    for kind in runtime_receipts:
        if kind in positions and not require_before("HOSTILE_PAYLOAD_RELEASED", kind):
            return False

    causal_pairs = (
        ("UNTRUSTED_FRAME_OBSERVED", "STREAM_EOF_VALID"),
        ("TERMINATION_REQUESTED", "WAIT_SIGNALLED"),
        ("VISIBLE_EMPTY_ACK", "RMDIR_ATTACH_CLOSED_ACK"),
        ("RMDIR_ATTACH_CLOSED_ACK", "ASYNC_ADMISSION_CLOSED"),
        ("RMDIR_ATTACH_CLOSED_ACK", "TASK_POPULATION_ZERO_ACK"),
        ("ASYNC_ADMISSION_CLOSED", "ASYNC_REFS_DRAINED"),
        ("EXECUTION_REVOKED_ACK", "MONITOR_PROTECTION_CLOSED_ACK"),
        ("RMDIR_ATTACH_CLOSED_ACK", "MONITOR_PROTECTION_CLOSED_ACK"),
        ("ASYNC_ADMISSION_CLOSED", "MONITOR_PROTECTION_CLOSED_ACK"),
        ("MONITOR_PROTECTION_CLOSED_ACK", "HIDDEN_WORK_DRAINED_ACK"),
        ("TASK_POPULATION_ZERO_ACK", "HIDDEN_WORK_DRAINED_ACK"),
        ("LEADER_REAPED", "HIDDEN_WORK_DRAINED_ACK"),
        ("HIDDEN_WORK_DRAINED_ACK", "FINAL_COUNTERS"),
        ("HIDDEN_WORK_DRAINED_ACK", "FINAL_COUNTERS_FAILED"),
        ("FINAL_COUNTERS", "COMPLETION_LINEARIZED"),
        ("CSS_OFFLINE_ACK", "SCOPE_RELEASED_ACK"),
    )
    for before, after in causal_pairs:
        if not require_before(before, after):
            return False
    if "STREAM_EOF_INVALID" in positions and "UNTRUSTED_FRAME_OBSERVED" in positions:
        if not require_before("UNTRUSTED_FRAME_OBSERVED", "STREAM_EOF_INVALID"):
            return False
    if "TERMINATION_REQUESTED" in positions:
        winner_kinds = {
            "QUOTA_LINEARIZED",
            "FAULT_LINEARIZED",
        }
        if not any(
            kind in positions
            and positions[kind] < positions["TERMINATION_REQUESTED"]
            for kind in winner_kinds
        ):
            return False
    if "FAULT_LINEARIZED" in positions:
        fault_causes = {
            "UNTRUSTED_FRAME_OBSERVED",
            "STREAM_EOF_TRUNCATED",
            "STREAM_EOF_INVALID",
            "HOSTILE_ATTEMPT_REJECTED",
            "OWNER_REVOKED",
            "LINUX_LIMIT_UNATTRIBUTED",
            "WAIT_ABNORMAL",
            "FINAL_COUNTERS_FAILED",
            "PRIMARY_FAILOVER",
        }
        if not any(
            kind in positions and positions[kind] < positions["FAULT_LINEARIZED"]
            for kind in fault_causes
        ):
            return False
    if "MONITOR_QUOTA_ARRIVED" in positions and "FINAL_COUNTERS" in positions:
        if not require_before("MONITOR_QUOTA_ARRIVED", "FINAL_COUNTERS"):
            return False
    if not require_before("MONITOR_QUOTA_ARRIVED", "QUOTA_LINEARIZED"):
        return False
    if "DESCENDANTS_EXITED" in positions:
        wait_positions = [
            positions[kind]
            for kind in {"WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"}
            if kind in positions
        ]
        if not wait_positions or min(wait_positions) > positions["DESCENDANTS_EXITED"]:
            return False
    for after in {"STREAM_EOF_TRUNCATED", "LEADER_REAPED", "CSS_OFFLINE_ACK"}:
        if after not in positions:
            continue
        predecessors = (
            {"FINAL_COUNTERS", "FINAL_COUNTERS_FAILED"}
            if after == "CSS_OFFLINE_ACK"
            else {"WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"}
        )
        if not any(
            kind in positions and positions[kind] < positions[after]
            for kind in predecessors
        ):
            return False
    if "VISIBLE_EMPTY_ACK" in positions:
        wait_positions = [
            positions[kind]
            for kind in {"WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"}
            if kind in positions
        ]
        if not wait_positions or min(wait_positions) > positions["VISIBLE_EMPTY_ACK"]:
            return False
    if "ASYNC_REFS_DRAINED" in positions and not require_before(
        "ASYNC_REFS_DRAINED",
        "HIDDEN_WORK_DRAINED_ACK",
    ):
        return False
    if "DESCENDANTS_EXITED" in positions and not require_before(
        "DESCENDANTS_EXITED",
        "HIDDEN_WORK_DRAINED_ACK",
    ):
        return False
    for kind, drained_generation in (
        ("DESCENDANTS_EXITED", state.descendant_drained_generation),
        ("ASYNC_REFS_DRAINED", state.async_drained_generation),
    ):
        prefix = f"{state.grant.scope_id}:generation="
        generations = []
        for receipt in state.evidence_receipts:
            if receipt.kind != kind or not receipt.payload.startswith(prefix):
                continue
            try:
                generations.append(int(receipt.payload.removeprefix(prefix)))
            except ValueError:
                return False
        if sorted(generations) != list(range(1, drained_generation + 1)):
            return False
    visible_prefix = f"{state.grant.scope_id}:observation="
    visible_observations = []
    for receipt in state.evidence_receipts:
        if receipt.kind != "VISIBLE_EMPTY_ACK" or not receipt.payload.startswith(visible_prefix):
            continue
        try:
            visible_observations.append(
                int(receipt.payload.removeprefix(visible_prefix))
            )
        except ValueError:
            return False
    if sorted(visible_observations) != list(
        range(1, state.visible_empty_observations + 1)
    ):
        return False
    seal_count = counts["EVIDENCE_SEAL"]
    if state.evidence_ledger == "OPEN":
        return seal_count == 0 and state.evidence_root == ""
    if state.evidence_ledger != "SEALED":
        return False
    return (
        seal_count == 1
        and bool(state.evidence_receipts)
        and state.evidence_receipts[-1].kind == "EVIDENCE_SEAL"
        and state.evidence_root == previous
        and state.evidence_receipts[-1].payload
        == state.evidence_receipts[-1].previous_hash
    )


@lru_cache(maxsize=None)
def recovery_wf(state: EnvelopeState) -> bool:
    if len(state.recovery_receipts) > 1:
        return False
    for sequence, receipt in enumerate(state.recovery_receipts, start=1):
        if not (
            receipt.schema == SCHEMA
            and receipt.run_id == state.grant.child_run_id
            and receipt.binding_digest == grant_binding_digest(state.grant)
            and receipt.sequence == sequence
            and receipt.observed_phase in PHASES
            and bool(receipt.evidence_prefix_hash)
            and receipt.reason == "PRIMARY_CRASH"
            and receipt.failed_controller == "PRIMARY_SUPERVISOR"
            and receipt.fence_generation == sequence
            and receipt.issuer == "RECOVERY_GUARDIAN"
            and receipt.auth_tag == _recovery_auth_tag(replace(receipt, auth_tag=""))
        ):
            return False
    if (len(state.recovery_receipts) == 1) != (state.primary_state == "FAILED"):
        return False
    if not state.recovery_receipts:
        return True

    receipt = state.recovery_receipts[0]
    failovers = [item for item in state.evidence_receipts if item.kind == "PRIMARY_FAILOVER"]
    if failovers:
        return (
            len(failovers) == 1
            and receipt.evidence_prefix_hash == failovers[0].previous_hash
            and failovers[0].payload == f"phase={receipt.observed_phase}"
        )
    return (
        state.evidence_ledger == "SEALED"
        and receipt.evidence_prefix_hash == state.evidence_root
        and receipt.observed_phase == "QUIESCENT"
    )


def _has(state: EnvelopeState, kind: str) -> bool:
    return any(receipt.kind == kind for receipt in state.evidence_receipts)


def _winner_receipt_kind(winner: str) -> str | None:
    return {
        "COMPLETION": "COMPLETION_LINEARIZED",
        "QUOTA": "QUOTA_LINEARIZED",
        "FAULT": "FAULT_LINEARIZED",
    }.get(winner)


def closure_ready(state: EnvelopeState) -> bool:
    return (
        state.scope == "RELEASED"
        and state.visible_population == "EMPTY"
        and state.task_population == "EMPTY"
        and state.attach_authority == "CLOSED"
        and state.async_admission == "CLOSED"
        and state.execution_authority == "REVOKED"
        and state.protection_state == "CLOSED"
        and state.leader == "REAPED"
        and state.descendants != "LIVE"
        and state.async_refs != "LIVE"
        and state.hidden_work == "DRAINED"
        and state.writer_confinement == "CLOSED"
        and state.stream in {"EOF_VALID", "EOF_TRUNCATED", "EOF_INVALID"}
        and state.wait != "NONE"
        and state.winner != "OPEN"
        and state.counters in {"FINAL", "FAILED"}
    )


def completion_ready(state: EnvelopeState) -> bool:
    expected_kind = "PRODUCER_RESULT" if state.grant.role == "PRODUCER" else None
    checker_kind = state.candidate_kind in {"CHECKER_ACCEPT", "CHECKER_REJECT"}
    kind_ok = state.candidate_kind == expected_kind if expected_kind else checker_kind
    return (
        state.fault == "CLEAN"
        and state.wait == "NORMAL"
        and state.stream == "EOF_VALID"
        and kind_ok
        and state.scope in {
            "HIDDEN_DRAINED",
            "CSS_OFFLINE",
            "RELEASED",
        }
        and state.descendants != "LIVE"
        and state.async_refs != "LIVE"
        and state.hidden_work == "DRAINED"
        and state.attach_authority == "CLOSED"
        and state.async_admission == "CLOSED"
        and state.execution_authority == "REVOKED"
        and state.protection_state == "CLOSED"
        and state.visible_population == "EMPTY"
        and state.task_population == "EMPTY"
        and state.counters == "FINAL"
        and state.final_value <= state.grant.budget_limit
    )


def _expected_local_decision(state: EnvelopeState) -> str:
    if state.owner_state == "REVOKED":
        return "ABANDONED"
    if state.fault == "STICKY" or state.counters == "FAILED" or state.winner == "FAULT":
        return "INTERNAL_FAILURE"
    if state.winner == "QUOTA" and state.resource_event == "MONITOR_PROVED":
        return "INCONCLUSIVE_RESOURCE"
    if state.winner == "COMPLETION" and completion_ready(state):
        return "LOCAL_SYNTACTIC_CANDIDATE"
    return "INTERNAL_FAILURE"


def decision_receipt_wf(state: EnvelopeState) -> bool:
    receipt = state.decision_receipt
    if state.local_decision == "NONE":
        return receipt is None
    if receipt is None:
        return False
    return (
        receipt.schema == SCHEMA
        and receipt.run_id == state.grant.child_run_id
        and receipt.binding_digest == grant_binding_digest(state.grant)
        and receipt.evidence_root == state.evidence_root
        and receipt.decision == state.local_decision
        and receipt.payload_kind == state.candidate_kind
        and receipt.payload_digest == state.candidate_digest
        and receipt.issuer == state.controller
        and receipt.auth_tag == _decision_auth_tag(replace(receipt, auth_tag=""))
    )


@lru_cache(maxsize=None)
def instance_wf(state: EnvelopeState) -> bool:
    if not (
        grant_wf(state.grant)
        and state.phase in PHASES
        and state.owner_state in OWNER_STATES
        and state.primary_state in PRIMARY_STATES
        and state.controller in CONTROLLERS
        and state.scope in SCOPES
        and state.visible_population in VISIBLE_POPULATIONS
        and 0 <= state.visible_empty_observations <= MAX_REACQUISITIONS + 1
        and state.task_population in TASK_POPULATIONS
        and state.attach_authority in ATTACH_AUTHORITIES
        and state.async_admission in ASYNC_ADMISSIONS
        and state.execution_authority in EXECUTION_AUTHORITIES
        and state.protection_state in PROTECTION_STATES
        and state.leader in LEADERS
        and state.descendants in DESCENDANTS
        and 0 <= state.descendant_drained_generation <= state.descendant_generation <= MAX_REACQUISITIONS
        and state.async_refs in ASYNC_REFS
        and 0 <= state.async_drained_generation <= state.async_generation <= MAX_REACQUISITIONS
        and state.hidden_work in HIDDEN_WORK
        and state.sandbox in SANDBOXES
        and state.payload in PAYLOADS
        and state.writer_confinement in WRITER_CONFINEMENT
        and state.stream in STREAMS
        and state.candidate_kind in CANDIDATE_KINDS
        and state.candidate_value in CANDIDATE_VALUES
        and state.wait in WAITS
        and state.resource_event in RESOURCE_EVENTS
        and state.resource_observed_value >= 0
        and state.event_clock >= 0
        and state.completion_arrival_sequence >= 0
        and state.quota_arrival_sequence >= 0
        and state.fault_arrival_sequence >= 0
        and state.enforcement in ENFORCEMENTS
        and state.winner in WINNERS
        and state.counters in COUNTERS
        and state.fault in FAULTS
        and state.pending_attack in PENDING_ATTACKS
        and state.attack_seen in PENDING_ATTACKS
        and state.breach_kind in BREACH_KINDS
        and state.evidence_ledger in LEDGERS
        and state.local_decision in LOCAL_DECISIONS
        and state.baseline_value >= 0
        and state.final_value >= 0
        and evidence_wf(state)
        and recovery_wf(state)
        and decision_receipt_wf(state)
    ):
        return False

    if state.primary_state == "ACTIVE" and state.controller != "PRIMARY_SUPERVISOR":
        return False
    if state.primary_state == "FAILED" and state.controller != "RECOVERY_GUARDIAN":
        return False
    if state.pending_attack != "NONE" and state.attack_seen != "NONE":
        return False
    if (state.phase == "BREACHED") != (
        state.protection_state == "BREACHED" and state.breach_kind != "NONE"
    ):
        return False
    if state.breach_kind != "NONE":
        if (
            state.pending_attack != "NONE"
            or state.attack_seen != "NONE"
            or state.fault != "STICKY"
            or state.evidence_ledger != "OPEN"
            or state.local_decision != "NONE"
        ):
            return False
    if state.attack_seen != "NONE" and state.fault != "STICKY":
        return False
    if state.owner_state == "REVOKED" and state.fault != "STICKY":
        return False

    counts = _receipt_counts(state)

    def present(kind: str) -> bool:
        return counts[kind] > 0

    if state.primary_state == "ACTIVE":
        if present("PRIMARY_FAILOVER") or state.recovery_receipts:
            return False
    elif state.evidence_ledger == "OPEN" and not present("PRIMARY_FAILOVER"):
        return False

    setup_phase_shapes = {
        "NEW": (
            state.scope == "UNCREATED"
            and state.visible_population == "UNKNOWN"
            and state.task_population == "UNKNOWN"
            and state.attach_authority == "UNBOUND"
            and state.async_admission == "UNBOUND"
            and state.execution_authority == "UNBOUND"
            and state.leader == "ABSENT"
            and state.sandbox == "UNVERIFIED"
            and state.payload == "HELD"
            and state.counters == "NONE"
        ),
        "SCOPE_REQUESTED": (
            state.scope == "REQUESTED"
            and state.visible_population == "UNKNOWN"
            and state.task_population == "UNKNOWN"
        ),
        "SCOPE_CONFIGURED": (
            state.scope == "CONFIGURED_EMPTY"
            and state.visible_population == "EMPTY"
            and state.task_population == "EMPTY"
            and state.attach_authority == "EXTERNAL_EXCLUSIVE"
            and state.async_admission == "OPEN"
        ),
        "BOOTSTRAP_REQUESTED": (
            state.scope == "CONFIGURED_EMPTY"
            and state.leader == "ABSENT"
        ),
        "BOOTSTRAP_HELD": (
            state.scope == "LIVE"
            and state.visible_population == "NONEMPTY"
            and state.task_population == "NONEMPTY"
            and state.leader == "TRUSTED_HELD"
            and state.execution_authority in {"UNBOUND", "ACTIVE"}
            and state.sandbox == "UNVERIFIED"
        ),
        "SANDBOX_REQUESTED": (
            state.scope == "LIVE"
            and state.visible_population == "NONEMPTY"
            and state.task_population == "NONEMPTY"
            and state.leader == "TRUSTED_HELD"
            and state.sandbox == "REQUESTED"
        ),
        "READY": (
            state.scope == "LIVE"
            and state.visible_population == "NONEMPTY"
            and state.task_population == "NONEMPTY"
            and state.leader == "TRUSTED_HELD"
            and state.sandbox == "ATTESTED"
            and state.payload == "HELD"
            and state.counters in {"NONE", "BASELINE"}
        ),
        "RUNNING": (
            state.scope == "LIVE"
            and state.visible_population == "NONEMPTY"
            and state.task_population == "NONEMPTY"
            and state.leader == "HOSTILE_RUNNING"
            and state.payload == "RELEASED"
            and state.sandbox == "ATTESTED"
            and state.wait == "NONE"
            and state.winner == "OPEN"
            and state.fault == "CLEAN"
            and state.owner_state == "ACTIVE"
        ),
    }
    if state.phase in setup_phase_shapes and not setup_phase_shapes[state.phase]:
        return False

    setup_presence = {
        "SCOPE_REQUESTED": state.scope != "UNCREATED",
        "SCOPE_CONFIGURED_ACK": state.scope not in {"UNCREATED", "REQUESTED"},
        "BOOTSTRAP_REQUESTED": (
            state.phase == "BOOTSTRAP_REQUESTED" or state.leader != "ABSENT"
        ),
        "CHARGED_BOOTSTRAP_ACK": state.leader != "ABSENT",
        "MONITOR_EXECUTION_ACTIVATED_ACK": state.execution_authority in {
            "ACTIVE",
            "REVOKED",
        },
        "SANDBOX_REQUESTED": state.sandbox != "UNVERIFIED",
        "SANDBOX_PROFILE_ACK": state.sandbox == "ATTESTED",
        "BASELINE_COUNTERS": state.counters != "NONE",
        "HOSTILE_PAYLOAD_RELEASED": state.payload == "RELEASED",
    }
    for kind, expected in setup_presence.items():
        if present(kind) != expected:
            return False

    scope_presence = {
        "RMDIR_ATTACH_CLOSED_ACK": state.scope in {
            "ATTACH_CLOSED",
            "HIDDEN_DRAINED",
            "CSS_OFFLINE",
            "RELEASED",
        },
        "ASYNC_ADMISSION_CLOSED": state.async_admission == "CLOSED",
        "EXECUTION_REVOKED_ACK": state.execution_authority == "REVOKED",
        "MONITOR_PROTECTION_CLOSED_ACK": state.protection_state == "CLOSED",
        "TASK_POPULATION_ZERO_ACK": (
            state.payload == "RELEASED" and state.task_population == "EMPTY"
        ),
        "HIDDEN_WORK_DRAINED_ACK": state.scope in {
            "HIDDEN_DRAINED",
            "CSS_OFFLINE",
            "RELEASED",
        },
        "CSS_OFFLINE_ACK": state.scope in {"CSS_OFFLINE", "RELEASED"},
        "SCOPE_RELEASED_ACK": state.scope == "RELEASED",
    }
    for kind, expected in scope_presence.items():
        if present(kind) != expected:
            return False
    if counts["VISIBLE_EMPTY_ACK"] != state.visible_empty_observations:
        return False
    if (
        state.payload == "RELEASED"
        and state.visible_population == "EMPTY"
        and state.visible_empty_observations == 0
    ):
        return False

    observation_presence = {
        "UNTRUSTED_FRAME_OBSERVED": state.candidate_kind != "NONE",
        "STREAM_EOF_VALID": state.stream == "EOF_VALID",
        "STREAM_EOF_TRUNCATED": state.stream == "EOF_TRUNCATED",
        "STREAM_EOF_INVALID": state.stream == "EOF_INVALID",
        "HOSTILE_ATTEMPT_REJECTED": state.attack_seen != "NONE",
        "OWNER_REVOKED": state.owner_state == "REVOKED",
        "WAIT_NORMAL": state.wait == "NORMAL",
        "WAIT_SIGNALLED": state.wait == "SIGNALLED",
        "WAIT_ABNORMAL": state.wait == "ABNORMAL",
        "LEADER_REAPED": state.leader == "REAPED",
        "LINUX_LIMIT_UNATTRIBUTED": state.resource_event == "LINUX_UNATTRIBUTED",
        "TERMINATION_REQUESTED": state.enforcement == "TERMINATION_REQUESTED",
        "FINAL_COUNTERS": state.counters == "FINAL",
        "FINAL_COUNTERS_FAILED": state.counters == "FAILED",
        "MONITOR_QUOTA_ARRIVED": state.quota_arrival_sequence > 0,
        "EVIDENCE_SEAL": state.evidence_ledger == "SEALED",
    }
    for kind, expected in observation_presence.items():
        if present(kind) != expected:
            return False
    if present("PRIMARY_FAILOVER") and state.primary_state != "FAILED":
        return False
    stage_requirements = {
        "SCOPE_REQUESTED": "SCOPE_REQUESTED",
        "SCOPE_CONFIGURED": "SCOPE_CONFIGURED_ACK",
        "BOOTSTRAP_REQUESTED": "BOOTSTRAP_REQUESTED",
        "BOOTSTRAP_HELD": "CHARGED_BOOTSTRAP_ACK",
        "SANDBOX_REQUESTED": "SANDBOX_REQUESTED",
        "READY": "SANDBOX_PROFILE_ACK",
        "RUNNING": "HOSTILE_PAYLOAD_RELEASED",
    }
    required = stage_requirements.get(state.phase)
    if required and not counts[required]:
        return False

    if state.scope in {
        "REQUESTED",
        "CONFIGURED_EMPTY",
        "LIVE",
        "ATTACH_CLOSED",
        "HIDDEN_DRAINED",
        "CSS_OFFLINE",
        "RELEASED",
    } and not counts["SCOPE_REQUESTED"]:
        return False
    if state.scope != "UNCREATED" and not counts["SCOPE_REQUESTED"]:
        return False
    if state.scope not in {"UNCREATED", "REQUESTED"} and not counts["SCOPE_CONFIGURED_ACK"]:
        return False
    if state.attach_authority == "EXTERNAL_EXCLUSIVE" and state.scope in {"UNCREATED", "REQUESTED"}:
        return False
    if state.attach_authority == "CLOSED" and state.scope not in {
        "ATTACH_CLOSED",
        "HIDDEN_DRAINED",
        "CSS_OFFLINE",
        "RELEASED",
    }:
        return False
    if state.scope in {"ATTACH_CLOSED", "HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"}:
        if state.visible_population != "EMPTY":
            return False
    if state.scope in {"HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"} and state.hidden_work != "DRAINED":
        return False
    if state.scope in {"CSS_OFFLINE", "RELEASED"} and state.counters not in {"FINAL", "FAILED"}:
        return False
    if state.scope == "RELEASED" and state.attach_authority != "CLOSED":
        return False
    if state.scope in {"HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"}:
        if not (
            state.task_population == "EMPTY"
            and state.async_admission == "CLOSED"
            and state.protection_state == "CLOSED"
        ):
            return False
    if state.protection_state == "OPEN":
        if state.execution_authority == "REVOKED":
            return False
    elif state.protection_state == "EXECUTION_REVOKED":
        if state.execution_authority != "REVOKED":
            return False
    elif state.protection_state == "CLOSED":
        if not (
            state.execution_authority == "REVOKED"
            and state.attach_authority == "CLOSED"
            and state.async_admission == "CLOSED"
        ):
            return False
    if state.execution_authority == "ACTIVE" and state.leader == "ABSENT":
        return False
    if state.async_admission == "UNBOUND" and state.scope not in {"UNCREATED", "REQUESTED"}:
        return False

    if state.descendant_generation == 0:
        if state.descendants != "NONE" or state.descendant_drained_generation != 0:
            return False
    elif state.descendants == "LIVE":
        if state.descendant_generation <= state.descendant_drained_generation:
            return False
    elif state.descendants == "EXITED":
        if state.descendant_generation != state.descendant_drained_generation:
            return False
    else:
        return False
    if counts["DESCENDANTS_EXITED"] != state.descendant_drained_generation:
        return False

    if state.async_generation == 0:
        if state.async_refs != "NONE" or state.async_drained_generation != 0:
            return False
    elif state.async_refs == "LIVE":
        if state.async_generation <= state.async_drained_generation:
            return False
    elif state.async_refs == "DRAINED":
        if state.async_generation != state.async_drained_generation:
            return False
    else:
        return False
    if counts["ASYNC_REFS_DRAINED"] != state.async_drained_generation:
        return False

    if state.leader in {"TRUSTED_HELD", "HOSTILE_RUNNING", "EXITED", "REAPED"} and not counts["CHARGED_BOOTSTRAP_ACK"]:
        return False
    if state.leader == "HOSTILE_RUNNING" and state.payload != "RELEASED":
        return False
    if state.wait != "NONE" and state.leader not in {"EXITED", "REAPED"}:
        return False
    if state.leader == "REAPED" and state.wait == "NONE":
        return False
    if state.leader == "REAPED" and not counts["LEADER_REAPED"]:
        return False
    if state.descendants == "LIVE" and state.leader not in {"HOSTILE_RUNNING", "EXITED", "REAPED"}:
        return False
    if state.descendants == "EXITED" and not counts["DESCENDANTS_EXITED"]:
        return False
    if state.async_refs == "LIVE" and state.payload != "RELEASED":
        return False
    if state.async_refs == "DRAINED" and not counts["ASYNC_REFS_DRAINED"]:
        return False

    if state.sandbox == "ATTESTED" and not counts["SANDBOX_PROFILE_ACK"]:
        return False
    if state.payload == "RELEASED":
        if not (
            state.sandbox == "ATTESTED"
            and state.counters in {"BASELINE", "FINAL", "FAILED"}
            and counts["HOSTILE_PAYLOAD_RELEASED"]
            and counts["SCOPE_REQUESTED"]
            and counts["SCOPE_CONFIGURED_ACK"]
            and counts["BOOTSTRAP_REQUESTED"]
            and counts["CHARGED_BOOTSTRAP_ACK"]
            and counts["SANDBOX_REQUESTED"]
            and counts["SANDBOX_PROFILE_ACK"]
            and counts["BASELINE_COUNTERS"]
        ):
            return False
    if state.writer_confinement == "CONFINED" and state.sandbox != "ATTESTED":
        return False
    if state.writer_confinement == "CLOSED" and state.stream not in {"EOF_VALID", "EOF_TRUNCATED", "EOF_INVALID"}:
        return False

    if state.candidate_kind == "NONE" and (
        state.candidate_value != "NONE" or state.candidate_digest
    ):
        return False
    if state.candidate_kind != "NONE":
        if state.stream not in {"FRAME", "EOF_VALID", "EOF_INVALID"}:
            return False
        expected_values = {
            "PRODUCER_RESULT": {"VALUE_A", "VALUE_B"},
            "CHECKER_ACCEPT": {"ACCEPT"},
            "CHECKER_REJECT": {"REJECT"},
            "INTERNAL": {"INTERNAL"},
        }
        if state.candidate_value not in expected_values[state.candidate_kind]:
            return False
        if state.candidate_digest != _expected_candidate_digest(
            state,
            state.candidate_kind,
            state.candidate_value,
        ):
            return False
        if state.grant.role == "PRODUCER" and state.candidate_kind not in {"PRODUCER_RESULT", "INTERNAL"}:
            return False
        if state.grant.role == "CHECKER" and state.candidate_kind not in {"CHECKER_ACCEPT", "CHECKER_REJECT", "INTERNAL"}:
            return False
        if not counts["UNTRUSTED_FRAME_OBSERVED"]:
            return False
    if state.stream == "FRAME" and not counts["UNTRUSTED_FRAME_OBSERVED"]:
        return False
    if state.stream == "EOF_VALID" and state.candidate_kind in {"NONE", "INTERNAL"}:
        return False
    if state.stream == "EOF_VALID" and not counts["STREAM_EOF_VALID"]:
        return False
    if state.stream == "EOF_TRUNCATED" and not counts["STREAM_EOF_TRUNCATED"]:
        return False
    if state.stream == "EOF_INVALID" and not counts["STREAM_EOF_INVALID"]:
        return False
    if state.stream in {"EOF_TRUNCATED", "EOF_INVALID"} and state.fault != "STICKY":
        return False

    wait_receipt = {
        "NORMAL": "WAIT_NORMAL",
        "SIGNALLED": "WAIT_SIGNALLED",
        "ABNORMAL": "WAIT_ABNORMAL",
    }.get(state.wait)
    if wait_receipt and not counts[wait_receipt]:
        return False

    winner_kind = _winner_receipt_kind(state.winner)
    linearization_presence = {
        "COMPLETION_LINEARIZED": state.winner == "COMPLETION",
        "QUOTA_LINEARIZED": state.winner == "QUOTA",
        "FAULT_LINEARIZED": state.winner == "FAULT",
    }
    for kind, expected in linearization_presence.items():
        if present(kind) != expected:
            return False

    arrivals = {
        "COMPLETION": state.completion_arrival_sequence,
        "QUOTA": state.quota_arrival_sequence,
        "FAULT": state.fault_arrival_sequence,
    }
    nonzero_arrivals = [sequence for sequence in arrivals.values() if sequence > 0]
    if (
        len(nonzero_arrivals) != len(set(nonzero_arrivals))
        or sorted(nonzero_arrivals) != list(range(1, state.event_clock + 1))
    ):
        return False
    if (state.quota_arrival_sequence > 0) != (state.resource_event == "MONITOR_PROVED"):
        return False
    if (state.fault_arrival_sequence > 0) != (state.fault == "STICKY"):
        return False
    if state.completion_arrival_sequence > 0:
        expected_kind = "PRODUCER_RESULT" if state.grant.role == "PRODUCER" else None
        checker_kind = state.candidate_kind in {"CHECKER_ACCEPT", "CHECKER_REJECT"}
        kind_ok = state.candidate_kind == expected_kind if expected_kind else checker_kind
        if not (
            state.wait == "NORMAL"
            and state.stream == "EOF_VALID"
            and kind_ok
            and state.scope in {"HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"}
            and state.attach_authority == "CLOSED"
            and state.hidden_work == "DRAINED"
            and state.counters == "FINAL"
            and state.final_value <= state.grant.budget_limit
        ):
            return False
    if state.winner == "OPEN":
        if state.winner_sequence != 0:
            return False
    else:
        matching = [receipt for receipt in state.evidence_receipts if receipt.kind == winner_kind]
        winner_arrival = arrivals[state.winner]
        if (
            len(matching) != 1
            or state.winner_sequence != matching[0].sequence
            or winner_arrival <= 0
            or winner_arrival != min(nonzero_arrivals)
        ):
            return False
    if state.resource_event == "MONITOR_PROVED" and state.winner not in {"OPEN", "QUOTA"}:
        return False
    if (
        state.resource_event == "MONITOR_PROVED"
        and state.resource_observed_value <= state.grant.budget_limit
    ):
        return False
    if state.resource_event == "LINUX_UNATTRIBUTED" and state.fault != "STICKY":
        return False
    if state.resource_event == "NONE" and state.resource_observed_value != 0:
        return False
    if state.resource_event == "MONITOR_PROVED" and not counts["MONITOR_QUOTA_ARRIVED"]:
        return False
    if state.resource_event == "LINUX_UNATTRIBUTED" and not counts["LINUX_LIMIT_UNATTRIBUTED"]:
        return False
    if state.enforcement == "TERMINATION_REQUESTED" and not counts["TERMINATION_REQUESTED"]:
        return False

    if state.attack_seen != "NONE" and not counts["HOSTILE_ATTEMPT_REJECTED"]:
        return False
    if state.owner_state == "REVOKED" and not counts["OWNER_REVOKED"]:
        return False
    if state.primary_state == "FAILED" and not state.recovery_receipts:
        return False

    if state.counters == "NONE" and state.baseline_value != 0:
        return False
    if state.counters in {"BASELINE", "FINAL", "FAILED"} and not counts["BASELINE_COUNTERS"]:
        return False
    if state.counters == "FINAL" and state.final_value < state.baseline_value:
        return False
    if (
        state.counters == "FINAL"
        and state.final_value > state.grant.budget_limit
        and state.resource_event != "MONITOR_PROVED"
    ):
        return False
    if state.counters == "FINAL" and not counts["FINAL_COUNTERS"]:
        return False
    if state.counters == "FAILED" and state.fault != "STICKY":
        return False
    if state.counters == "FAILED" and not counts["FINAL_COUNTERS_FAILED"]:
        return False

    if state.evidence_ledger == "SEALED":
        if state.phase not in {"QUIESCENT", "DECIDED"} or not closure_ready(state):
            return False
    if state.phase in {"QUIESCENT", "DECIDED"}:
        if state.evidence_ledger != "SEALED" or not closure_ready(state):
            return False
    if state.phase == "QUIESCENT" and state.local_decision != "NONE":
        return False
    if state.phase == "DECIDED":
        if state.local_decision == "NONE" or state.local_decision != _expected_local_decision(state):
            return False
    elif state.local_decision != "NONE":
        return False
    return True


@lru_cache(maxsize=None)
def semantic_projection(state: EnvelopeState) -> tuple[object, ...]:
    """Return exact state identity until a congruent quotient is proved."""

    return (state,)


def _edge(action_id: str, actor: str, before: EnvelopeState, after: EnvelopeState) -> Edge:
    spec = ACTION_SPECS.get(action_id)
    if spec is None or actor not in spec.actors or actor not in ACTORS:
        raise ProtocolReject("F05-SPV3-ACTION-ACTOR", f"{action_id}:{actor}")
    if before.grant != after.grant:
        raise ProtocolReject("F05-SPV3-SUPERVISOR-MINTED-GRANT", action_id)
    before_receipts = before.evidence_receipts
    after_receipts = after.evidence_receipts
    if after_receipts[: len(before_receipts)] != before_receipts:
        raise ProtocolReject("F05-SPV3-EVIDENCE-NONAPPEND", action_id)
    if any(receipt.issuer != actor for receipt in after_receipts[len(before_receipts) :]):
        raise ProtocolReject("F05-SPV3-EVIDENCE-ACTOR-MISMATCH", action_id)
    if before.owner_state != after.owner_state and actor != "EXTERNAL_OWNER":
        raise ProtocolReject("F05-SPV3-OWNER-WRITE", action_id)
    if before.primary_state != after.primary_state and actor != "RECOVERY_GUARDIAN":
        raise ProtocolReject("F05-SPV3-PRIMARY-FENCE-WRITE", action_id)
    if before.controller != after.controller and actor != "RECOVERY_GUARDIAN":
        raise ProtocolReject("F05-SPV3-CONTROLLER-WRITE", action_id)
    if before.recovery_receipts != after.recovery_receipts and actor != "RECOVERY_GUARDIAN":
        raise ProtocolReject("F05-SPV3-RECOVERY-RECEIPT-WRITE", action_id)
    if before.async_admission != after.async_admission:
        allowed_async_admission = (
            before.async_admission,
            after.async_admission,
            actor,
        ) in {
            ("UNBOUND", "OPEN", "MANAGEMENT_DOMAIN_OBSERVER"),
            ("OPEN", "CLOSED", "PRIMARY_SUPERVISOR"),
            ("OPEN", "CLOSED", "RECOVERY_GUARDIAN"),
        }
        if not allowed_async_admission:
            raise ProtocolReject("F05-SPV3-ASYNC-ADMISSION-WRITE", action_id)
    if before.execution_authority != after.execution_authority:
        allowed_execution = (
            before.execution_authority,
            after.execution_authority,
            actor,
        ) in {
            ("UNBOUND", "ACTIVE", "MONITOR_OBSERVER"),
            ("ACTIVE", "REVOKED", "MONITOR_OBSERVER"),
        }
        if not allowed_execution:
            raise ProtocolReject("F05-SPV3-EXECUTION-AUTHORITY-WRITE", action_id)
    if before.protection_state != after.protection_state:
        allowed = (
            actor == "MONITOR_OBSERVER"
            or (
                actor == "ADVERSARY"
                and after.protection_state == "BREACHED"
            )
        )
        if not allowed:
            raise ProtocolReject("F05-SPV3-PROTECTION-WRITE", action_id)
    if before.winner != after.winner and before.winner != "OPEN":
        raise ProtocolReject("F05-SPV3-WINNER-OVERWRITE", action_id)
    if not instance_wf(after):
        raise ProtocolReject("F05-SPV3-EFFECT-WF", action_id)
    return Edge(action_id=action_id, actor=actor, state=after)


def _fault(state: EnvelopeState) -> EnvelopeState:
    if state.fault == "STICKY":
        return replace(state, phase="STOPPING")
    sequence = state.event_clock + 1
    return replace(
        state,
        fault="STICKY",
        phase="STOPPING",
        event_clock=sequence,
        fault_arrival_sequence=sequence,
    )


def _linearize(state: EnvelopeState, actor: str, winner: str, kind: str, payload: str) -> EnvelopeState:
    if state.winner != "OPEN":
        raise ProtocolReject("F05-SPV3-WINNER-NOT-OPEN", winner)
    updated = _append_receipt(state, actor, kind, payload)
    return replace(updated, winner=winner, winner_sequence=len(updated.evidence_receipts), phase="STOPPING")


def _failover_edge(state: EnvelopeState, *, mark_runtime_fault: bool) -> Edge:
    if state.primary_state != "ACTIVE":
        raise ProtocolReject("F05-SPV3-FAILOVER-PRECONDITION", state.primary_state)
    actor = "RECOVERY_GUARDIAN"
    updated = _append_recovery_receipt(state)
    if state.evidence_ledger == "OPEN":
        updated = _append_receipt(
            updated,
            actor,
            "PRIMARY_FAILOVER",
            f"phase={state.phase}",
        )
    if mark_runtime_fault:
        updated = _fault(updated)
    updated = replace(
        updated,
        primary_state="FAILED",
        controller="RECOVERY_GUARDIAN",
    )
    return _edge("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH", actor, state, updated)


def _stream_edges(state: EnvelopeState) -> list[Edge]:
    edges: list[Edge] = []
    actor = "TARGET_LINUX_OBSERVER"
    if state.stream == "OPEN":
        if state.grant.role == "PRODUCER":
            kind = "PRODUCER_RESULT"
            for action_id, value in (
                ("OBS-009A-PRODUCER-CANDIDATE-A", "VALUE_A"),
                ("OBS-009B-PRODUCER-CANDIDATE-B", "VALUE_B"),
            ):
                updated = _append_receipt(
                    state,
                    actor,
                    "UNTRUSTED_FRAME_OBSERVED",
                    _candidate_payload(state, kind, value),
                )
                updated = replace(
                    updated,
                    stream="FRAME",
                    candidate_kind=kind,
                    candidate_value=value,
                    candidate_digest=_expected_candidate_digest(state, kind, value),
                )
                edges.append(_edge(action_id, actor, state, updated))
        else:
            for action_id, kind, value in (
                ("OBS-010-CHECKER-ACCEPT", "CHECKER_ACCEPT", "ACCEPT"),
                ("OBS-011-CHECKER-REJECT", "CHECKER_REJECT", "REJECT"),
            ):
                updated = _append_receipt(
                    state,
                    actor,
                    "UNTRUSTED_FRAME_OBSERVED",
                    _candidate_payload(state, kind, value),
                )
                updated = replace(
                    updated,
                    stream="FRAME",
                    candidate_kind=kind,
                    candidate_value=value,
                    candidate_digest=_expected_candidate_digest(state, kind, value),
                )
                edges.append(_edge(action_id, actor, state, updated))
        internal_kind = "INTERNAL"
        internal_value = "INTERNAL"
        internal = _append_receipt(
            state,
            actor,
            "UNTRUSTED_FRAME_OBSERVED",
            _candidate_payload(state, internal_kind, internal_value),
        )
        internal = _fault(
            replace(
                internal,
                stream="FRAME",
                candidate_kind=internal_kind,
                candidate_value=internal_value,
                candidate_digest=_expected_candidate_digest(
                    state,
                    internal_kind,
                    internal_value,
                ),
            )
        )
        edges.append(_edge("OBS-012-INTERNAL-FRAME", actor, state, internal))
        if state.leader in {"EXITED", "REAPED"}:
            truncated = _append_receipt(state, actor, "STREAM_EOF_TRUNCATED", "no-complete-frame")
            truncated = _fault(replace(truncated, stream="EOF_TRUNCATED", writer_confinement="CLOSED"))
            edges.append(_edge("OBS-014-EOF-TRUNCATED", actor, state, truncated))
        invalid = _append_receipt(state, actor, "STREAM_EOF_INVALID", "framing-invalid")
        invalid = _fault(replace(invalid, stream="EOF_INVALID", writer_confinement="CLOSED"))
        edges.append(_edge("OBS-015-EOF-INVALID", actor, state, invalid))
    elif state.stream == "FRAME":
        if state.candidate_kind != "INTERNAL":
            valid = _append_receipt(state, actor, "STREAM_EOF_VALID", state.candidate_digest)
            valid = replace(valid, stream="EOF_VALID", writer_confinement="CLOSED")
            edges.append(_edge("OBS-013-EOF-VALID", actor, state, valid))
        invalid = _append_receipt(state, actor, "STREAM_EOF_INVALID", "trailing-or-duplicate-frame")
        invalid = _fault(replace(invalid, stream="EOF_INVALID", writer_confinement="CLOSED"))
        edges.append(_edge("OBS-015-EOF-INVALID", actor, state, invalid))
    return edges


@lru_cache(maxsize=None)
def next_states(state: EnvelopeState) -> tuple[Edge, ...]:
    if not instance_wf(state):
        raise ProtocolReject("F05-SPV3-STATE-WF", state.phase)
    if state.phase in {"DECIDED", "BREACHED"}:
        return ()

    if state.pending_attack != "NONE":
        actor = "MANAGEMENT_DOMAIN_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "HOSTILE_ATTEMPT_REJECTED",
            state.pending_attack,
        )
        updated = _fault(
            replace(
                updated,
                attack_seen=state.pending_attack,
                pending_attack="NONE",
            )
        )
        rejected = _edge("OBS-023-REJECT-HOSTILE-ATTEMPT", actor, state, updated)
        bypass = _fault(
            replace(
                state,
                pending_attack="NONE",
                breach_kind=state.pending_attack,
                protection_state="BREACHED",
            )
        )
        bypass = replace(bypass, phase="BREACHED")
        return (
            rejected,
            _edge(
                "ADV-023B-SUCCEED-HOSTILE-BYPASS",
                "ADVERSARY",
                state,
                bypass,
            ),
        )

    if state.winner == "OPEN":
        arrivals = {
            "COMPLETION": state.completion_arrival_sequence,
            "QUOTA": state.quota_arrival_sequence,
            "FAULT": state.fault_arrival_sequence,
        }
        pending = {
            winner: sequence
            for winner, sequence in arrivals.items()
            if sequence > 0
        }
        if pending:
            winner = min(pending, key=pending.get)
            actor = "LOCAL_ARBITER"
            action_id, receipt_kind, payload = {
                "COMPLETION": (
                    "ARB-034-COMPLETION-WINS",
                    "COMPLETION_LINEARIZED",
                    f"{state.candidate_digest}:"
                    f"arrival={state.completion_arrival_sequence}",
                ),
                "QUOTA": (
                    "ARB-026B-QUOTA-WINS",
                    "QUOTA_LINEARIZED",
                    f"arrival={state.quota_arrival_sequence}",
                ),
                "FAULT": (
                    "ARB-035-FAULT-WINS",
                    "FAULT_LINEARIZED",
                    f"arrival={state.fault_arrival_sequence}",
                ),
            }[winner]
            updated = _linearize(
                state,
                actor,
                winner,
                receipt_kind,
                payload,
            )
            return (_edge(action_id, actor, state, updated),)

    edges: list[Edge] = []
    controller = _controller(state)

    def setup_edges(normal: Edge) -> tuple[Edge, ...]:
        local_edges = [normal]
        if state.primary_state == "ACTIVE":
            local_edges.append(_failover_edge(state, mark_runtime_fault=False))
        return tuple(local_edges)

    if state.phase == "NEW":
        updated = _append_receipt(state, controller, "SCOPE_REQUESTED", state.grant.scope_id)
        updated = replace(updated, phase="SCOPE_REQUESTED", scope="REQUESTED")
        return setup_edges(_edge("SUP-001-REQUEST-SCOPE", controller, state, updated))
    if state.phase == "SCOPE_REQUESTED":
        actor = "MANAGEMENT_DOMAIN_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "SCOPE_CONFIGURED_ACK",
            f"{state.grant.hierarchy_id}:{state.grant.scope_id}:exclusive",
        )
        updated = replace(
            updated,
            phase="SCOPE_CONFIGURED",
            scope="CONFIGURED_EMPTY",
            visible_population="EMPTY",
            task_population="EMPTY",
            attach_authority="EXTERNAL_EXCLUSIVE",
            async_admission="OPEN",
        )
        return setup_edges(_edge("OBS-002-CONFIGURE-SCOPE-ACK", actor, state, updated))
    if state.phase == "SCOPE_CONFIGURED":
        updated = _append_receipt(state, controller, "BOOTSTRAP_REQUESTED", state.grant.scope_id)
        updated = replace(updated, phase="BOOTSTRAP_REQUESTED")
        return setup_edges(_edge("SUP-003-REQUEST-CHARGED-BOOTSTRAP", controller, state, updated))
    if state.phase == "BOOTSTRAP_REQUESTED":
        actor = "MANAGEMENT_DOMAIN_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "CHARGED_BOOTSTRAP_ACK",
            f"{state.grant.scope_id}:held-before-hostile-exec",
        )
        updated = replace(
            updated,
            phase="BOOTSTRAP_HELD",
            scope="LIVE",
            visible_population="NONEMPTY",
            task_population="NONEMPTY",
            leader="TRUSTED_HELD",
            hidden_work="ACTIVE",
            stream="OPEN",
        )
        return setup_edges(_edge("OBS-004-CHARGED-BOOTSTRAP-ACK", actor, state, updated))
    if state.phase == "BOOTSTRAP_HELD" and state.execution_authority == "UNBOUND":
        actor = "MONITOR_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "MONITOR_EXECUTION_ACTIVATED_ACK",
            f"{state.grant.child_run_id}:epoch={state.grant.epoch}:activated-held",
        )
        updated = replace(updated, execution_authority="ACTIVE")
        return setup_edges(_edge("MON-004B-ACTIVATE-EXECUTION", actor, state, updated))
    if state.phase == "BOOTSTRAP_HELD" and state.execution_authority == "ACTIVE":
        updated = _append_receipt(state, controller, "SANDBOX_REQUESTED", state.grant.profile_digest)
        updated = replace(updated, phase="SANDBOX_REQUESTED", sandbox="REQUESTED")
        return setup_edges(_edge("SUP-005-REQUEST-SANDBOX", controller, state, updated))
    if state.phase == "SANDBOX_REQUESTED":
        actor = "MANAGEMENT_DOMAIN_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "SANDBOX_PROFILE_ACK",
            f"{state.grant.profile_digest}:payload-held:fd-confined",
        )
        updated = replace(
            updated,
            phase="READY",
            sandbox="ATTESTED",
            writer_confinement="CONFINED",
        )
        return setup_edges(_edge("OBS-006-SANDBOX-PROFILE-ACK", actor, state, updated))
    if state.phase == "READY" and state.counters == "NONE":
        actor = "MONITOR_OBSERVER"
        updated = _append_receipt(
            state,
            actor,
            "BASELINE_COUNTERS",
            f"{state.grant.budget_id}:epoch={state.grant.epoch}:value=0",
        )
        updated = replace(updated, counters="BASELINE", baseline_value=0)
        return setup_edges(_edge("MON-007-BASELINE-COUNTERS", actor, state, updated))
    if state.phase == "READY" and state.counters == "BASELINE":
        updated = _append_receipt(
            state,
            controller,
            "HOSTILE_PAYLOAD_RELEASED",
            f"{state.grant.subject_id}:{state.grant.profile_digest}",
        )
        updated = replace(
            updated,
            phase="RUNNING",
            leader="HOSTILE_RUNNING",
            payload="RELEASED",
        )
        return setup_edges(_edge("SUP-008-RELEASE-HOSTILE-PAYLOAD", controller, state, updated))

    if state.phase in {"RUNNING", "STOPPING"} and state.evidence_ledger == "OPEN":
        edges.extend(_stream_edges(state))

        if state.leader == "HOSTILE_RUNNING" and state.wait == "NONE":
            actor = "TARGET_LINUX_OBSERVER"
            normal = _append_receipt(state, actor, "WAIT_NORMAL", "leader-normal-exit")
            normal = replace(
                normal,
                leader="EXITED",
                wait="NORMAL",
                hidden_work="PENDING",
                phase="STOPPING",
            )
            edges.append(_edge("OBS-029-NORMAL-EXIT", actor, state, normal))
            if state.enforcement == "TERMINATION_REQUESTED":
                signalled = _append_receipt(state, actor, "WAIT_SIGNALLED", "controller-termination")
                signalled = replace(
                    signalled,
                    leader="EXITED",
                    wait="SIGNALLED",
                    hidden_work="PENDING",
                    phase="STOPPING",
                )
                edges.append(_edge("OBS-030-SIGNAL-EXIT", actor, state, signalled))
            abnormal = _append_receipt(state, actor, "WAIT_ABNORMAL", "unattributed-abnormal-exit")
            abnormal = _fault(
                replace(
                    abnormal,
                    leader="EXITED",
                    wait="ABNORMAL",
                    hidden_work="PENDING",
                )
            )
            edges.append(_edge("OBS-031-ABNORMAL-EXIT", actor, state, abnormal))

        if (
            state.execution_authority == "ACTIVE"
            and state.protection_state == "OPEN"
            and state.payload == "RELEASED"
            and state.task_population == "NONEMPTY"
        ):
            if (
                state.attach_authority != "CLOSED"
                and state.descendant_generation < MAX_REACQUISITIONS
            ):
                edges.append(
                    _edge(
                        "ADV-016-FORK-DESCENDANT",
                        "ADVERSARY",
                        state,
                        replace(
                            state,
                            descendants="LIVE",
                            descendant_generation=state.descendant_generation + 1,
                            visible_population="NONEMPTY",
                            task_population="NONEMPTY",
                        ),
                    )
                )
            if (
                state.async_admission == "OPEN"
                and state.async_generation < MAX_REACQUISITIONS
            ):
                edges.append(
                    _edge(
                        "ADV-017-OPEN-ASYNC-REF",
                        "ADVERSARY",
                        state,
                        replace(
                            state,
                            async_refs="LIVE",
                            async_generation=state.async_generation + 1,
                            hidden_work="ACTIVE",
                        ),
                    )
                )
        if state.phase == "RUNNING" and state.leader == "HOSTILE_RUNNING":
            if state.attack_seen == "NONE":
                for action_id, attack in (
                    ("ADV-018-ATTACH-ATTEMPT", "ATTACH"),
                    ("ADV-019-FD-ESCAPE-ATTEMPT", "FD_ESCAPE"),
                    ("ADV-020-PTRACE-ATTEMPT", "PTRACE"),
                    ("ADV-021-FORGED-RECEIPT", "FORGED_RECEIPT"),
                    ("ADV-022-REPLAY-RECEIPT", "REPLAY_RECEIPT"),
                ):
                    edges.append(
                        _edge(
                            action_id,
                            "ADVERSARY",
                            state,
                            replace(state, pending_attack=attack),
                        )
                    )
            edges.append(_edge("ADV-047-STALL", "ADVERSARY", state, state))

        if state.primary_state == "ACTIVE":
            edges.append(_failover_edge(state, mark_runtime_fault=True))

        if (
            state.owner_state == "ACTIVE"
            and state.phase in {"RUNNING", "STOPPING"}
            and state.evidence_ledger == "OPEN"
        ):
            actor = "EXTERNAL_OWNER"
            updated = _append_receipt(state, actor, "OWNER_REVOKED", f"epoch={state.grant.epoch}")
            updated = _fault(replace(updated, owner_state="REVOKED"))
            edges.append(_edge("EXT-025-REVOKE-RUN", actor, state, updated))

        if (
            state.winner == "OPEN"
            and state.resource_event == "NONE"
            and state.quota_arrival_sequence == 0
            and state.completion_arrival_sequence == 0
        ):
            actor = "MONITOR_OBSERVER"
            arrival = state.event_clock + 1
            updated = _append_receipt(
                state,
                actor,
                "MONITOR_QUOTA_ARRIVED",
                f"{state.grant.budget_id}:epoch={state.grant.epoch}:"
                f"value={state.grant.budget_limit + 1}:arrival={arrival}",
            )
            updated = replace(
                updated,
                resource_event="MONITOR_PROVED",
                resource_observed_value=state.grant.budget_limit + 1,
                event_clock=arrival,
                quota_arrival_sequence=arrival,
            )
            edges.append(_edge("MON-026-QUOTA-ARRIVAL", actor, state, updated))

            actor = "TARGET_LINUX_OBSERVER"
            ambiguous = _append_receipt(
                state,
                actor,
                "LINUX_LIMIT_UNATTRIBUTED",
                f"{state.grant.budget_id}:causality-unproved",
            )
            ambiguous = _fault(replace(ambiguous, resource_event="LINUX_UNATTRIBUTED"))
            ambiguous = replace(
                ambiguous,
                resource_observed_value=state.grant.budget_limit,
            )
            edges.append(_edge("OBS-027-UNATTRIBUTED-LIMIT", actor, state, ambiguous))

        if (
            state.winner in {"QUOTA", "FAULT"}
            and state.leader == "HOSTILE_RUNNING"
            and state.enforcement == "NONE"
        ):
            updated = _append_receipt(
                state,
                controller,
                "TERMINATION_REQUESTED",
                f"winner={state.winner}",
            )
            updated = replace(updated, enforcement="TERMINATION_REQUESTED", phase="STOPPING")
            edges.append(_edge("SUP-028-REQUEST-TERMINATION", controller, state, updated))

        if state.descendants == "LIVE" and state.leader in {"EXITED", "REAPED"}:
            actor = "TARGET_LINUX_OBSERVER"
            drained_generation = state.descendant_drained_generation + 1
            updated = _append_receipt(
                state,
                actor,
                "DESCENDANTS_EXITED",
                f"{state.grant.scope_id}:generation={drained_generation}",
            )
            updated = replace(
                updated,
                descendants=(
                    "LIVE"
                    if state.descendant_generation > drained_generation
                    else "EXITED"
                ),
                descendant_drained_generation=drained_generation,
                hidden_work="PENDING",
                phase="STOPPING",
            )
            edges.append(_edge("OBS-032-DESCENDANTS-EXIT", actor, state, updated))

        if state.leader == "EXITED":
            actor = "TARGET_LINUX_OBSERVER"
            updated = _append_receipt(state, actor, "LEADER_REAPED", state.grant.subject_id)
            updated = replace(updated, leader="REAPED", phase="STOPPING")
            edges.append(_edge("OBS-036-LEADER-REAPED", actor, state, updated))

        if (
            state.scope == "LIVE"
            and state.visible_population == "NONEMPTY"
            and state.leader in {"EXITED", "REAPED"}
            and state.descendants in {"NONE", "EXITED"}
        ):
            actor = "TARGET_LINUX_OBSERVER"
            observation = state.visible_empty_observations + 1
            updated = _append_receipt(
                state,
                actor,
                "VISIBLE_EMPTY_ACK",
                f"{state.grant.scope_id}:observation={observation}",
            )
            updated = replace(
                updated,
                visible_population="EMPTY",
                visible_empty_observations=observation,
                phase="STOPPING",
            )
            edges.append(_edge("OBS-037-VISIBLE-EMPTY", actor, state, updated))

        if (
            state.scope == "LIVE"
            and state.visible_population == "EMPTY"
            and state.attach_authority == "EXTERNAL_EXCLUSIVE"
        ):
            actor = "MANAGEMENT_DOMAIN_OBSERVER"
            updated = _append_receipt(
                state,
                actor,
                "RMDIR_ATTACH_CLOSED_ACK",
                f"{state.grant.scope_id}:no-future-attach",
            )
            updated = replace(updated, scope="ATTACH_CLOSED", attach_authority="CLOSED", phase="STOPPING")
            edges.append(_edge("OBS-039-RMDIR-ATTACH-CLOSED", actor, state, updated))

        if state.scope == "ATTACH_CLOSED" and state.async_admission == "OPEN":
            updated = _append_receipt(
                state,
                controller,
                "ASYNC_ADMISSION_CLOSED",
                f"{state.grant.scope_id}:no-future-async-acquire",
            )
            updated = replace(updated, async_admission="CLOSED", phase="STOPPING")
            edges.append(
                _edge(
                    "SUP-039B-CLOSE-ASYNC-ADMISSION",
                    controller,
                    state,
                    updated,
                )
            )

        if (
            state.execution_authority == "ACTIVE"
            and state.payload == "RELEASED"
            and (
                state.wait != "NONE"
                or state.winner in {"QUOTA", "FAULT"}
                or state.owner_state == "REVOKED"
            )
        ):
            actor = "MONITOR_OBSERVER"
            updated = _append_receipt(
                state,
                actor,
                "EXECUTION_REVOKED_ACK",
                f"{state.grant.child_run_id}:epoch={state.grant.epoch}:revoked",
            )
            updated = replace(
                updated,
                execution_authority="REVOKED",
                protection_state="EXECUTION_REVOKED",
                phase="STOPPING",
            )
            edges.append(_edge("MON-035B-REVOKE-EXECUTION", actor, state, updated))

        if (
            state.scope == "ATTACH_CLOSED"
            and state.task_population == "NONEMPTY"
            and state.leader == "REAPED"
            and state.descendants != "LIVE"
        ):
            actor = "MANAGEMENT_DOMAIN_OBSERVER"
            updated = _append_receipt(
                state,
                actor,
                "TASK_POPULATION_ZERO_ACK",
                state.grant.scope_id,
            )
            updated = replace(updated, task_population="EMPTY", phase="STOPPING")
            edges.append(_edge("OBS-038-TASK-POPULATION-ZERO", actor, state, updated))

        if (
            state.scope == "ATTACH_CLOSED"
            and state.async_admission == "CLOSED"
            and state.async_refs == "LIVE"
        ):
            actor = "MANAGEMENT_DOMAIN_OBSERVER"
            drained_generation = state.async_drained_generation + 1
            updated = _append_receipt(
                state,
                actor,
                "ASYNC_REFS_DRAINED",
                f"{state.grant.scope_id}:generation={drained_generation}",
            )
            updated = replace(
                updated,
                async_refs=(
                    "LIVE"
                    if state.async_generation > drained_generation
                    else "DRAINED"
                ),
                async_drained_generation=drained_generation,
                phase="STOPPING",
            )
            edges.append(_edge("OBS-033-ASYNC-REFS-DRAIN", actor, state, updated))

        if (
            state.protection_state == "EXECUTION_REVOKED"
            and state.execution_authority == "REVOKED"
            and state.attach_authority == "CLOSED"
            and state.async_admission == "CLOSED"
        ):
            actor = "MONITOR_OBSERVER"
            updated = _append_receipt(
                state,
                actor,
                "MONITOR_PROTECTION_CLOSED_ACK",
                f"{state.grant.child_run_id}:epoch={state.grant.epoch}:"
                "admission-and-execution-closed",
            )
            updated = replace(updated, protection_state="CLOSED", phase="STOPPING")
            edges.append(_edge("MON-039C-PROTECTION-CLOSED", actor, state, updated))

        if (
            state.scope == "ATTACH_CLOSED"
            and state.leader == "REAPED"
            and state.descendants != "LIVE"
            and state.async_refs != "LIVE"
            and state.task_population == "EMPTY"
            and state.async_admission == "CLOSED"
            and state.protection_state == "CLOSED"
        ):
            actor = "MANAGEMENT_DOMAIN_OBSERVER"
            updated = _append_receipt(
                state,
                actor,
                "HIDDEN_WORK_DRAINED_ACK",
                state.grant.scope_id,
            )
            updated = replace(updated, scope="HIDDEN_DRAINED", hidden_work="DRAINED", phase="STOPPING")
            edges.append(_edge("OBS-040-HIDDEN-WORK-DRAINED", actor, state, updated))

        if state.scope == "HIDDEN_DRAINED" and state.counters == "BASELINE":
            actor = "MONITOR_OBSERVER"
            final_value = max(1, state.resource_observed_value)
            final = _append_receipt(
                state,
                actor,
                "FINAL_COUNTERS",
                f"{state.grant.budget_id}:epoch={state.grant.epoch}:value={final_value}",
            )
            final = replace(final, counters="FINAL", final_value=final_value, phase="STOPPING")
            if (
                final.completion_arrival_sequence == 0
                and completion_ready(final)
            ):
                arrival = final.event_clock + 1
                final = replace(
                    final,
                    event_clock=arrival,
                    completion_arrival_sequence=arrival,
                )
            edges.append(_edge("MON-041-FINAL-COUNTERS", actor, state, final))

            if state.winner == "OPEN" and state.resource_event == "NONE":
                observed_value = state.grant.budget_limit + 1
                arrival = state.event_clock + 1
                overlimit = _append_receipt(
                    state,
                    actor,
                    "MONITOR_QUOTA_ARRIVED",
                    f"{state.grant.budget_id}:epoch={state.grant.epoch}:"
                    f"value={observed_value}:arrival={arrival}",
                )
                overlimit = replace(
                    overlimit,
                    resource_event="MONITOR_PROVED",
                    resource_observed_value=observed_value,
                    event_clock=arrival,
                    quota_arrival_sequence=arrival,
                )
                overlimit = _append_receipt(
                    overlimit,
                    actor,
                    "FINAL_COUNTERS",
                    f"{state.grant.budget_id}:epoch={state.grant.epoch}:"
                    f"value={observed_value}",
                )
                overlimit = replace(
                    overlimit,
                    counters="FINAL",
                    final_value=observed_value,
                    phase="STOPPING",
                )
                edges.append(
                    _edge(
                        "MON-041B-FINAL-OVERLIMIT-QUOTA",
                        actor,
                        state,
                        overlimit,
                    )
                )

            failed = _append_receipt(
                state,
                actor,
                "FINAL_COUNTERS_FAILED",
                f"{state.grant.budget_id}:read-failed",
            )
            failed = _fault(replace(failed, counters="FAILED", final_value=0))
            edges.append(_edge("MON-042-FINAL-COUNTERS-FAILED", actor, state, failed))

        if state.scope == "HIDDEN_DRAINED" and state.counters in {"FINAL", "FAILED"}:
            actor = "TARGET_LINUX_OBSERVER"
            updated = _append_receipt(state, actor, "CSS_OFFLINE_ACK", state.grant.scope_id)
            updated = replace(updated, scope="CSS_OFFLINE", phase="STOPPING")
            edges.append(_edge("OBS-043-CSS-OFFLINE", actor, state, updated))

        if state.scope == "CSS_OFFLINE":
            actor = "TARGET_LINUX_OBSERVER"
            updated = _append_receipt(state, actor, "SCOPE_RELEASED_ACK", state.grant.scope_id)
            updated = replace(updated, scope="RELEASED", phase="STOPPING")
            edges.append(_edge("OBS-044-SCOPE-RELEASED", actor, state, updated))

        if closure_ready(state):
            prefix_root = _last_evidence_hash(state)
            updated = _append_receipt(state, controller, "EVIDENCE_SEAL", prefix_root)
            updated = replace(
                updated,
                evidence_ledger="SEALED",
                evidence_root=_last_evidence_hash(updated),
                phase="QUIESCENT",
            )
            edges.append(_edge("SUP-045-SEAL-EVIDENCE", controller, state, updated))

    if state.phase == "QUIESCENT":
        decision = _expected_local_decision(state)
        receipt = DecisionReceipt(
            schema=SCHEMA,
            run_id=state.grant.child_run_id,
            binding_digest=grant_binding_digest(state.grant),
            evidence_root=state.evidence_root,
            decision=decision,
            payload_kind=state.candidate_kind,
            payload_digest=state.candidate_digest,
            issuer=controller,
            auth_tag="",
        )
        receipt = replace(receipt, auth_tag=_decision_auth_tag(receipt))
        updated = replace(
            state,
            local_decision=decision,
            decision_receipt=receipt,
            phase="DECIDED",
        )
        edges.append(_edge("SUP-046-DECIDE-LOCAL", controller, state, updated))

        if state.primary_state == "ACTIVE":
            edges.append(_failover_edge(state, mark_runtime_fault=False))

    return tuple(edges)


def apply_trace(state: EnvelopeState, actions: Iterable[str]) -> EnvelopeState:
    current = state
    for action_id in actions:
        matches = [edge for edge in next_states(current) if edge.action_id == action_id]
        if len(matches) != 1:
            raise ProtocolReject("F05-SPV3-TRACE-ACTION", f"{action_id}:{len(matches)}")
        current = matches[0].state
    return current


def reachable_states(grant: RunGrant) -> tuple[set[EnvelopeState], list[tuple[EnvelopeState, Edge]]]:
    start = initial_state(grant)
    start_key = semantic_projection(start)
    queue: deque[tuple[object, ...]] = deque([start_key])
    representatives: dict[tuple[object, ...], EnvelopeState] = {start_key: start}
    edges: list[tuple[EnvelopeState, Edge]] = []
    while queue:
        state = representatives[queue.popleft()]
        for edge in next_states(state):
            target_key = semantic_projection(edge.state)
            target = representatives.get(target_key)
            if target is None:
                target = edge.state
                representatives[target_key] = target
                queue.append(target_key)
            canonical_edge = replace(edge, state=target)
            edges.append((state, canonical_edge))
    return set(representatives.values()), edges


def explore(role: str) -> Exploration:
    grant = fixture_external_grant(role)
    states, graph_edges = reachable_states(grant)
    reverse: dict[EnvelopeState, set[EnvelopeState]] = defaultdict(set)
    terminals: set[EnvelopeState] = set()
    deadlocks = 0
    decisions: Counter[str] = Counter()
    actions: set[str] = set()
    winner_overwrites = 0
    protection_breaches = 0
    for state in states:
        outgoing = next_states(state)
        if state.phase in {"DECIDED", "BREACHED"}:
            terminals.add(state)
            if state.phase == "DECIDED":
                decisions[state.local_decision] += 1
            else:
                protection_breaches += 1
            if outgoing:
                raise ProtocolReject("F05-SPV3-TERMINAL-EDGE", state.phase)
        elif not outgoing:
            deadlocks += 1
    for before, edge in graph_edges:
        actions.add(edge.action_id)
        reverse[edge.state].add(before)
        if before.winner != edge.state.winner and before.winner != "OPEN":
            winner_overwrites += 1
    coaccessible = set(terminals)
    queue: deque[EnvelopeState] = deque(terminals)
    while queue:
        state = queue.popleft()
        for predecessor in reverse[state]:
            if predecessor not in coaccessible:
                coaccessible.add(predecessor)
                queue.append(predecessor)
    return Exploration(
        role=role,
        reachable_semantic_state_count=len(states),
        retained_evidence_witness_count=len(states),
        edge_count=len(graph_edges),
        reachable_action_count=len(actions),
        reachable_action_ids=tuple(sorted(actions)),
        terminal_state_count=len(terminals),
        decision_counts=tuple(sorted(decisions.items())),
        nonterminal_deadlock_count=deadlocks,
        states_without_terminal_path=len(states - coaccessible),
        winner_overwrite_count=winner_overwrites,
        protection_breach_terminal_count=protection_breaches,
        hostile_bypass_explicit=True,
        coaccessibility_only=True,
        universal_termination_proved=False,
        infinite_stutter_counterexample_present=True,
        management_domain_refinement_proved=False,
        monitor_protection_refinement_proved=False,
        external_assumptions_discharged=False,
        linux_refinement_proved=False,
        semantic_verdict_issued=False,
        ordered_trace_states_exhaustively_enumerated=True,
    )


def decision_certificate(state: EnvelopeState) -> tuple[str, ...]:
    if state.phase != "DECIDED" or state.decision_receipt is None or not instance_wf(state):
        raise ProtocolReject("F05-SPV3-NOT-DECIDED", state.phase)
    return (
        state.grant.parent_run_id,
        state.grant.child_run_id,
        state.grant.role,
        state.grant.immutable_input_digest,
        state.evidence_root,
        state.local_decision,
        state.candidate_kind,
        state.candidate_value,
        state.candidate_digest,
        state.decision_receipt.auth_tag,
    )


def check_action_registry() -> dict[str, object]:
    reachable: set[str] = set()
    for role in sorted(ROLES):
        _, graph_edges = reachable_states(fixture_external_grant(role))
        reachable.update(edge.action_id for _, edge in graph_edges)
    declared = set(ACTION_SPECS)
    return {
        "declared": len(declared),
        "reachable": len(reachable),
        "missing_from_reachability": sorted(declared - reachable),
        "undeclared_reachable": sorted(reachable - declared),
        "exact": declared == reachable,
    }


def check_semantic_diamonds(role: str) -> dict[str, object]:
    """Check enabled two-action diamonds without erasing the ordered histories."""

    states, _ = reachable_states(fixture_external_grant(role))
    checked = 0
    failures: set[tuple[str, str]] = set()
    skipped_conflicts = 0
    for state in states:
        outgoing = next_states(state)
        for left, right in combinations(outgoing, 2):
            if left.action_id == right.action_id:
                continue
            left_then = [
                edge
                for edge in next_states(left.state)
                if edge.action_id == right.action_id
            ]
            right_then = [
                edge
                for edge in next_states(right.state)
                if edge.action_id == left.action_id
            ]
            if len(left_then) != 1 or len(right_then) != 1:
                skipped_conflicts += 1
                continue
            checked += 1
            if semantic_projection(left_then[0].state) != semantic_projection(right_then[0].state):
                failures.add(tuple(sorted((left.action_id, right.action_id))))
    return {
        "role": role,
        "ordered_diamonds_checked": checked,
        "conflicting_or_disabling_pairs_skipped": skipped_conflicts,
        "semantic_projection_failures": sorted(failures),
        "passed": not failures and checked > 0,
    }


__all__ = [
    "ACTION_IDS",
    "ACTION_SPECS",
    "AUTH_MODEL",
    "DecisionReceipt",
    "Edge",
    "EnvelopeState",
    "Exploration",
    "OPEN_REFINEMENT_OBLIGATIONS",
    "ProtocolReject",
    "Receipt",
    "RunGrant",
    "apply_trace",
    "check_action_registry",
    "check_semantic_diamonds",
    "closure_ready",
    "completion_ready",
    "decision_certificate",
    "digest",
    "evidence_wf",
    "explore",
    "fixture_external_grant",
    "grant_binding_digest",
    "grant_wf",
    "initial_state",
    "instance_wf",
    "next_states",
    "reachable_states",
    "receipt_wf",
    "semantic_projection",
]
