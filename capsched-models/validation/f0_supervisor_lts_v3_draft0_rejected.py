#!/usr/bin/env python3
"""Executable pre-normative supervisor-envelope LTS v3."""

from __future__ import annotations

from collections import Counter, deque
from dataclasses import dataclass, replace
from typing import Callable, Iterable


ROLES = {"PRODUCER", "CHECKER"}
PHASES = {
    "NEW",
    "SCOPE_CONFIGURED",
    "CHARGED",
    "SANDBOX_READY",
    "RUNNING",
    "STOPPING",
    "QUIESCENT",
    "DECIDED",
}
SCOPES = {"UNCREATED", "CONFIGURED_EMPTY", "POPULATED", "DRAINED", "OFFLINED"}
WORKERS = {"ABSENT", "CHARGED", "RUNNING", "EXITED", "REAPED"}
STREAMS = {
    "UNOPENED",
    "OPEN",
    "CANDIDATE",
    "EOF_VALID",
    "EOF_TRUNCATED",
    "EOF_INVALID",
}
WAITS = {"NONE", "NORMAL", "QUOTA", "ABNORMAL"}
WINNERS = {"OPEN", "COMPLETION", "QUOTA", "AMBIGUOUS"}
CANDIDATES = {"NONE", "OPAQUE", "INTERNAL", "INVALID"}
COUNTERS = {"BASELINE", "FINAL"}
FAULTS = {"CLEAN", "STICKY"}
LEDGERS = {"OPEN", "SEALED"}
DECISIONS = {"NONE", "CANDIDATE_CAPSULE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"}

EVIDENCE_ISSUERS = {
    "SCOPE_CONFIGURED": "SUPERVISOR",
    "CHARGED_LAUNCH": "SUPERVISOR",
    "SANDBOX_READY": "SUPERVISOR",
    "REQUEST_RELEASE": "SUPERVISOR",
    "FRAME_CANDIDATE": "WORKER",
    "WORKER_INTERNAL_FRAME": "WORKER",
    "STREAM_EOF_VALID": "SUPERVISOR",
    "STREAM_EOF_TRUNCATED": "SUPERVISOR",
    "STREAM_PROTOCOL_FAULT": "SUPERVISOR",
    "WAIT_NORMAL": "KERNEL_OBSERVER",
    "WAIT_QUOTA": "KERNEL_OBSERVER",
    "WAIT_ABNORMAL": "KERNEL_OBSERVER",
    "COMPLETION_LINEARIZED": "SUPERVISOR",
    "QUOTA_LINEARIZED": "SUPERVISOR",
    "ARBITRATION_AMBIGUOUS": "SUPERVISOR",
    "INTERNAL_RESOLUTION": "SUPERVISOR",
    "LEADER_REAPED": "KERNEL_OBSERVER",
    "FINAL_COUNTERS": "SUPERVISOR",
    "SCOPE_DRAINED": "SUPERVISOR",
    "SCOPE_OFFLINED": "SUPERVISOR",
    "REJECTED_FOREIGN_RECEIPT": "SUPERVISOR",
    "REJECTED_CONFLICTING_WAIT": "SUPERVISOR",
    "REJECTED_DUPLICATE_FRAME": "SUPERVISOR",
    "REJECTED_CONFLICTING_WINNER": "SUPERVISOR",
    "EVIDENCE_SEAL": "SUPERVISOR",
}


class ProtocolReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


@dataclass(frozen=True)
class EnvelopeState:
    role: str
    run_slot: str
    phase: str = "NEW"
    scope: str = "UNCREATED"
    worker: str = "ABSENT"
    stream: str = "UNOPENED"
    wait: str = "NONE"
    winner: str = "OPEN"
    candidate: str = "NONE"
    counters: str = "BASELINE"
    fault: str = "CLEAN"
    evidence_ledger: str = "OPEN"
    evidence_receipts: tuple[str, ...] = ()
    decision: str = "NONE"
    decision_chain: tuple[str, ...] = ()
    rejected_receipts: int = 0


@dataclass(frozen=True)
class Edge:
    action_id: str
    state: EnvelopeState


@dataclass(frozen=True)
class Exploration:
    role: str
    state_count: int
    edge_count: int
    type_ok_count: int
    decision_counts: tuple[tuple[str, int], ...]
    terminal_state_count: int
    nonterminal_deadlock_count: int


def initial_state(role: str, run_slot: str | None = None) -> EnvelopeState:
    if role not in ROLES:
        raise ProtocolReject("F05-SPV3-ROLE", role)
    return EnvelopeState(role=role, run_slot=run_slot or role)


def _receipt(state: EnvelopeState, kind: str) -> EnvelopeState:
    if state.evidence_ledger != "OPEN":
        raise ProtocolReject("F05-SPV3-LEDGER-SEALED", kind)
    issuer = EVIDENCE_ISSUERS.get(kind)
    if issuer is None:
        raise ProtocolReject("F05-SPV3-RECEIPT-KIND", kind)
    sequence = len(state.evidence_receipts) + 1
    token = f"{state.run_slot}:{sequence}:{kind}:{issuer}"
    return replace(state, evidence_receipts=state.evidence_receipts + (token,))


def _decision_receipt(state: EnvelopeState, decision: str) -> EnvelopeState:
    if state.evidence_ledger != "SEALED":
        raise ProtocolReject("F05-SPV3-DECISION-BEFORE-SEAL", decision)
    token = f"{state.run_slot}:DECISION:{decision}:SUPERVISOR"
    return replace(state, decision_chain=state.decision_chain + (token,))


def derived_quiescent(state: EnvelopeState) -> bool:
    return (
        state.worker == "REAPED"
        and state.scope == "OFFLINED"
        and state.stream in {"EOF_VALID", "EOF_TRUNCATED", "EOF_INVALID"}
        and state.wait != "NONE"
        and state.winner != "OPEN"
        and state.counters == "FINAL"
        and state.evidence_ledger == "OPEN"
    )


def classify_quiescent(state: EnvelopeState) -> str:
    if state.phase != "QUIESCENT" or state.evidence_ledger != "SEALED":
        raise ProtocolReject("F05-SPV3-NOT-QUIESCENT", state.phase)
    if (
        state.fault == "STICKY"
        or state.candidate in {"INTERNAL", "INVALID"}
        or state.winner == "AMBIGUOUS"
        or state.stream == "EOF_INVALID"
        or state.wait == "ABNORMAL"
    ):
        return "INTERNAL_FAILURE"
    if state.winner == "QUOTA":
        if state.wait != "QUOTA":
            return "INTERNAL_FAILURE"
        return "INCONCLUSIVE_RESOURCE"
    if (
        state.winner == "COMPLETION"
        and state.wait == "NORMAL"
        and state.stream == "EOF_VALID"
        and state.candidate == "OPAQUE"
    ):
        return "CANDIDATE_CAPSULE"
    return "INTERNAL_FAILURE"


def type_ok(state: EnvelopeState) -> bool:
    if (
        state.role not in ROLES
        or not state.run_slot
        or state.phase not in PHASES
        or state.scope not in SCOPES
        or state.worker not in WORKERS
        or state.stream not in STREAMS
        or state.wait not in WAITS
        or state.winner not in WINNERS
        or state.candidate not in CANDIDATES
        or state.counters not in COUNTERS
        or state.fault not in FAULTS
        or state.evidence_ledger not in LEDGERS
        or state.decision not in DECISIONS
        or state.rejected_receipts < 0
    ):
        return False
    if state.stream in {"CANDIDATE", "EOF_VALID"} and state.candidate == "NONE":
        return False
    if state.stream == "EOF_INVALID" and state.fault != "STICKY":
        return False
    if state.wait != "NONE" and state.worker not in {"EXITED", "REAPED"}:
        return False
    if state.worker == "REAPED" and state.wait == "NONE":
        return False
    if state.scope == "DRAINED" and state.worker != "REAPED":
        return False
    if state.scope == "OFFLINED" and state.worker != "REAPED":
        return False
    if state.phase in {"QUIESCENT", "DECIDED"}:
        if state.evidence_ledger != "SEALED":
            return False
        unsealed = replace(state, phase="STOPPING", evidence_ledger="OPEN")
        if not derived_quiescent(unsealed):
            return False
    if state.evidence_ledger == "SEALED" and state.phase not in {"QUIESCENT", "DECIDED"}:
        return False
    if state.decision != "NONE" and state.phase != "DECIDED":
        return False
    if state.phase == "DECIDED" and state.decision == "NONE":
        return False
    if state.decision_chain and state.decision == "NONE":
        return False
    if state.decision == "CANDIDATE_CAPSULE":
        if not (
            state.fault == "CLEAN"
            and state.winner == "COMPLETION"
            and state.wait == "NORMAL"
            and state.stream == "EOF_VALID"
            and state.candidate == "OPAQUE"
        ):
            return False
    if state.decision == "INCONCLUSIVE_RESOURCE":
        if not (
            state.fault == "CLEAN"
            and state.winner == "QUOTA"
            and state.wait == "QUOTA"
            and state.candidate not in {"INTERNAL", "INVALID"}
        ):
            return False
    for index, token in enumerate(state.evidence_receipts, start=1):
        prefix = f"{state.run_slot}:{index}:"
        if not token.startswith(prefix):
            return False
    return True


def _edge(action_id: str, state: EnvelopeState) -> Edge:
    if not type_ok(state):
        raise ProtocolReject("F05-SPV3-EFFECT-TYPE", action_id)
    return Edge(action_id, state)


def next_states(state: EnvelopeState) -> tuple[Edge, ...]:
    if not type_ok(state):
        raise ProtocolReject("F05-SPV3-STATE-TYPE", state.phase)
    if state.phase == "DECIDED":
        return ()
    edges: list[Edge] = []

    if state.phase == "NEW":
        updated = _receipt(state, "SCOPE_CONFIGURED")
        edges.append(_edge("ENV-001-CONFIGURE-SCOPE", replace(updated, phase="SCOPE_CONFIGURED", scope="CONFIGURED_EMPTY")))
        return tuple(edges)
    if state.phase == "SCOPE_CONFIGURED":
        updated = _receipt(state, "CHARGED_LAUNCH")
        edges.append(_edge("ENV-002-CHARGED-LAUNCH", replace(updated, phase="CHARGED", scope="POPULATED", worker="CHARGED")))
        return tuple(edges)
    if state.phase == "CHARGED":
        updated = _receipt(state, "SANDBOX_READY")
        edges.append(_edge("ENV-003-SANDBOX-READY", replace(updated, phase="SANDBOX_READY")))
        return tuple(edges)
    if state.phase == "SANDBOX_READY":
        updated = _receipt(state, "REQUEST_RELEASE")
        edges.append(_edge("ENV-004-RELEASE", replace(updated, phase="RUNNING", worker="RUNNING", stream="OPEN")))
        return tuple(edges)

    if state.phase in {"RUNNING", "STOPPING"} and state.evidence_ledger == "OPEN":
        if state.stream == "OPEN":
            opaque = _receipt(state, "FRAME_CANDIDATE")
            edges.append(_edge("ENV-005-OPAQUE-CANDIDATE", replace(opaque, stream="CANDIDATE", candidate="OPAQUE")))
            internal = _receipt(state, "WORKER_INTERNAL_FRAME")
            edges.append(_edge("ENV-006-INTERNAL-CANDIDATE", replace(internal, stream="CANDIDATE", candidate="INTERNAL", fault="STICKY")))
            if state.worker == "EXITED":
                truncated = _receipt(state, "STREAM_EOF_TRUNCATED")
                edges.append(_edge("ENV-007-EOF-TRUNCATED", replace(truncated, stream="EOF_TRUNCATED")))
            invalid = _receipt(state, "STREAM_PROTOCOL_FAULT")
            edges.append(_edge("ENV-008-STREAM-FAULT", replace(invalid, stream="EOF_INVALID", candidate="INVALID", fault="STICKY", phase="STOPPING")))
        elif state.stream == "CANDIDATE":
            valid = _receipt(state, "STREAM_EOF_VALID")
            edges.append(_edge("ENV-009-EOF-VALID", replace(valid, stream="EOF_VALID")))
            invalid = _receipt(state, "STREAM_PROTOCOL_FAULT")
            edges.append(_edge("ENV-010-TRAILING-OR-DUPLICATE", replace(invalid, stream="EOF_INVALID", candidate="INVALID", fault="STICKY", phase="STOPPING")))

        if state.worker == "RUNNING" and state.wait == "NONE":
            normal = _receipt(state, "WAIT_NORMAL")
            edges.append(_edge("ENV-011-NORMAL-EXIT", replace(normal, worker="EXITED", wait="NORMAL", phase="STOPPING")))
            abnormal = _receipt(state, "WAIT_ABNORMAL")
            edges.append(_edge("ENV-012-ABNORMAL-EXIT", replace(abnormal, worker="EXITED", wait="ABNORMAL", winner="AMBIGUOUS", fault="STICKY", phase="STOPPING")))
            if state.winner == "OPEN":
                quota = _receipt(state, "QUOTA_LINEARIZED")
                edges.append(_edge("ENV-013-QUOTA-WINS", replace(quota, winner="QUOTA", phase="STOPPING")))
                ambiguous = _receipt(state, "ARBITRATION_AMBIGUOUS")
                edges.append(_edge("ENV-014-AMBIGUOUS-ARBITRATION", replace(ambiguous, winner="AMBIGUOUS", fault="STICKY", phase="STOPPING")))

        if state.winner == "QUOTA" and state.worker == "RUNNING" and state.wait == "NONE":
            quota_wait = _receipt(state, "WAIT_QUOTA")
            edges.append(_edge("ENV-015-QUOTA-EXIT", replace(quota_wait, worker="EXITED", wait="QUOTA", phase="STOPPING")))

        if (
            state.winner == "OPEN"
            and state.worker == "EXITED"
            and state.wait == "NORMAL"
            and state.stream == "EOF_VALID"
            and state.candidate in {"OPAQUE", "INTERNAL"}
        ):
            completed = _receipt(state, "COMPLETION_LINEARIZED")
            edges.append(_edge("ENV-016-COMPLETION-WINS", replace(completed, winner="COMPLETION", phase="STOPPING")))

        if (
            state.winner == "OPEN"
            and state.worker == "EXITED"
            and state.wait == "NORMAL"
            and state.stream in {"EOF_TRUNCATED", "EOF_INVALID"}
        ):
            resolved = _receipt(state, "INTERNAL_RESOLUTION")
            edges.append(_edge("ENV-017-RESOLVE-NONCOMPLETION", replace(resolved, winner="AMBIGUOUS", fault="STICKY", phase="STOPPING")))

        if state.worker == "EXITED":
            reaped = _receipt(state, "LEADER_REAPED")
            edges.append(_edge("ENV-018-REAP", replace(reaped, worker="REAPED", phase="STOPPING")))
        if state.worker == "REAPED" and state.counters == "BASELINE":
            final = _receipt(state, "FINAL_COUNTERS")
            edges.append(_edge("ENV-019-FINAL-COUNTERS", replace(final, counters="FINAL", phase="STOPPING")))
        if state.worker == "REAPED" and state.scope == "POPULATED":
            drained = _receipt(state, "SCOPE_DRAINED")
            edges.append(_edge("ENV-020-DRAIN-SCOPE", replace(drained, scope="DRAINED", phase="STOPPING")))
        if state.scope == "DRAINED":
            offlined = _receipt(state, "SCOPE_OFFLINED")
            edges.append(_edge("ENV-021-OFFLINE-SCOPE", replace(offlined, scope="OFFLINED", phase="STOPPING")))

        if derived_quiescent(state):
            sealed = _receipt(state, "EVIDENCE_SEAL")
            edges.append(_edge("ENV-022-SEAL-EVIDENCE", replace(sealed, evidence_ledger="SEALED", phase="QUIESCENT")))

    if state.phase == "QUIESCENT":
        decision = classify_quiescent(state)
        updated = _decision_receipt(state, decision)
        edges.append(_edge("ENV-023-DECIDE", replace(updated, decision=decision, phase="DECIDED")))

    return tuple(edges)


def inject_foreign_receipt(state: EnvelopeState, foreign_run_slot: str) -> EnvelopeState:
    if state.evidence_ledger != "OPEN":
        raise ProtocolReject("F05-SPV3-LEDGER-SEALED", "foreign receipt")
    if foreign_run_slot == state.run_slot:
        raise ProtocolReject("F05-SPV3-NOT-FOREIGN", foreign_run_slot)
    updated = _receipt(state, "REJECTED_FOREIGN_RECEIPT")
    return replace(updated, fault="STICKY", rejected_receipts=state.rejected_receipts + 1)


def inject_conflicting_wait(state: EnvelopeState) -> EnvelopeState:
    if state.evidence_ledger != "OPEN" or state.wait == "NONE":
        raise ProtocolReject("F05-SPV3-CONFLICT-PRECONDITION", "wait")
    updated = _receipt(state, "REJECTED_CONFLICTING_WAIT")
    return replace(updated, fault="STICKY", rejected_receipts=state.rejected_receipts + 1)


def inject_duplicate_frame(state: EnvelopeState) -> EnvelopeState:
    if state.evidence_ledger != "OPEN" or state.stream not in {"CANDIDATE", "EOF_VALID"}:
        raise ProtocolReject("F05-SPV3-CONFLICT-PRECONDITION", "frame")
    updated = _receipt(state, "REJECTED_DUPLICATE_FRAME")
    return replace(updated, stream="EOF_INVALID", candidate="INVALID", fault="STICKY", rejected_receipts=state.rejected_receipts + 1)


def inject_conflicting_winner(state: EnvelopeState) -> EnvelopeState:
    if state.evidence_ledger != "OPEN" or state.winner == "OPEN":
        raise ProtocolReject("F05-SPV3-CONFLICT-PRECONDITION", "winner")
    updated = _receipt(state, "REJECTED_CONFLICTING_WINNER")
    return replace(updated, fault="STICKY", rejected_receipts=state.rejected_receipts + 1)


def apply_trace(state: EnvelopeState, actions: Iterable[str]) -> EnvelopeState:
    current = state
    for action_id in actions:
        matches = [edge for edge in next_states(current) if edge.action_id == action_id]
        if len(matches) != 1:
            raise ProtocolReject("F05-SPV3-TRACE-ACTION", f"{action_id}:{len(matches)}")
        current = matches[0].state
    return current


def explore(role: str) -> Exploration:
    start = initial_state(role)
    queue: deque[EnvelopeState] = deque([start])
    seen: set[EnvelopeState] = {start}
    edge_count = 0
    decisions: Counter[str] = Counter()
    terminal = 0
    deadlocks = 0
    while queue:
        state = queue.popleft()
        if not type_ok(state):
            raise ProtocolReject("F05-SPV3-REACHABLE-TYPE", state.phase)
        edges = next_states(state)
        edge_count += len(edges)
        if state.phase == "DECIDED":
            terminal += 1
            decisions[state.decision] += 1
            if edges:
                raise ProtocolReject("F05-SPV3-TERMINAL-EDGE", state.decision)
        elif not edges:
            deadlocks += 1
        for edge in edges:
            if edge.state not in seen:
                seen.add(edge.state)
                queue.append(edge.state)
    return Exploration(
        role=role,
        state_count=len(seen),
        edge_count=edge_count,
        type_ok_count=len(seen),
        decision_counts=tuple(sorted(decisions.items())),
        terminal_state_count=terminal,
        nonterminal_deadlock_count=deadlocks,
    )


@dataclass(frozen=True)
class OrchestratorState:
    external_context: str = "ABSENT"
    parent_run: str = "UNISSUED"
    producer: str = "NONE"
    checker: str = "NOT_STARTED"
    parent_evidence: str = "OPEN"
    local_disposition: str = "NONE"
    semantic_verdict: str = "UNISSUED"
    publication: str = "NONE"
    parent_receipts: tuple[str, ...] = ()
    decision_chain: tuple[str, ...] = ()
    publication_chain: tuple[str, ...] = ()


ORCH_PRODUCER = {"NONE", "CANDIDATE_CAPSULE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"}
ORCH_CHECKER = {"NOT_STARTED", "RUNNING", "CANDIDATE_CAPSULE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE", "SKIPPED"}
LOCAL_DISPOSITIONS = {"NONE", "LOCAL_CHECKED_CANDIDATE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"}
PUBLICATIONS = {"NONE", "PREPARED", "DURABLE", "PUBLISHED", "ABANDONED", "ORPHANED"}


def orchestrator_type_ok(state: OrchestratorState) -> bool:
    if (
        state.external_context not in {"ABSENT", "EXTERNALLY_ISSUED"}
        or state.parent_run not in {"UNISSUED", "ISSUED"}
        or state.producer not in ORCH_PRODUCER
        or state.checker not in ORCH_CHECKER
        or state.parent_evidence not in {"OPEN", "SEALED"}
        or state.local_disposition not in LOCAL_DISPOSITIONS
        or state.semantic_verdict != "UNISSUED"
        or state.publication not in PUBLICATIONS
    ):
        return False
    if state.parent_run == "ISSUED" and state.external_context != "EXTERNALLY_ISSUED":
        return False
    if state.checker == "RUNNING" and state.producer != "CANDIDATE_CAPSULE":
        return False
    if state.checker not in {"NOT_STARTED", "SKIPPED"} and state.producer != "CANDIDATE_CAPSULE":
        return False
    if state.parent_evidence == "SEALED" and state.producer == "NONE":
        return False
    if state.local_disposition != "NONE" and state.parent_evidence != "SEALED":
        return False
    if state.publication in {"PREPARED", "DURABLE", "PUBLISHED"} and state.local_disposition == "NONE":
        return False
    if state.publication == "PUBLISHED" and not state.publication_chain:
        return False
    return True


def orchestrator_next(state: OrchestratorState) -> tuple[tuple[str, OrchestratorState], ...]:
    if not orchestrator_type_ok(state):
        raise ProtocolReject("F05-SPV3-ORCH-TYPE", state.publication)
    if state.publication in {"PUBLISHED", "ABANDONED", "ORPHANED"}:
        return ()
    edges: list[tuple[str, OrchestratorState]] = []
    if state.external_context == "ABSENT":
        edges.append(("ORCH-001-IMPORT-EXTERNAL-CONTEXT", replace(state, external_context="EXTERNALLY_ISSUED")))
        edges.append(("ORCH-002-OUTER-OWNER-FAILS", replace(state, publication="ORPHANED")))
        return tuple(edges)
    if state.parent_run == "UNISSUED":
        edges.append(("ORCH-003-ISSUE-PARENT-RUN", replace(state, parent_run="ISSUED", parent_receipts=("PARENT_RUN_ISSUED:EXTERNAL_OWNER",))))
        edges.append(("ORCH-004-ABANDON-BEFORE-RUN", replace(state, publication="ABANDONED")))
        return tuple(edges)
    if state.producer == "NONE":
        for outcome in ("CANDIDATE_CAPSULE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"):
            checker = "NOT_STARTED" if outcome == "CANDIDATE_CAPSULE" else "SKIPPED"
            updated = replace(
                state,
                producer=outcome,
                checker=checker,
                parent_receipts=state.parent_receipts + (f"PRODUCER_ROOT:{outcome}",),
            )
            edges.append((f"ORCH-005-ATTACH-PRODUCER-{outcome}", updated))
        edges.append(("ORCH-006-ABANDON-PRODUCER", replace(state, publication="ABANDONED")))
        return tuple(edges)
    if state.producer == "CANDIDATE_CAPSULE" and state.checker == "NOT_STARTED":
        edges.append(("ORCH-007-START-CHECKER-CHILD", replace(state, checker="RUNNING")))
        edges.append(("ORCH-008-ABANDON-BEFORE-CHECKER", replace(state, publication="ABANDONED")))
        return tuple(edges)
    if state.checker == "RUNNING":
        for outcome in ("CANDIDATE_CAPSULE", "INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"):
            updated = replace(
                state,
                checker=outcome,
                parent_receipts=state.parent_receipts + (f"CHECKER_ROOT:{outcome}",),
            )
            edges.append((f"ORCH-009-ATTACH-CHECKER-{outcome}", updated))
        edges.append(("ORCH-010-ABANDON-CHECKER", replace(state, publication="ABANDONED")))
        return tuple(edges)
    child_complete = state.producer in {"INCONCLUSIVE_RESOURCE", "INTERNAL_FAILURE"} or state.checker in {
        "CANDIDATE_CAPSULE",
        "INCONCLUSIVE_RESOURCE",
        "INTERNAL_FAILURE",
    }
    if child_complete and state.parent_evidence == "OPEN":
        edges.append(("ORCH-011-SEAL-PARENT-EVIDENCE", replace(state, parent_evidence="SEALED", parent_receipts=state.parent_receipts + ("PARENT_EVIDENCE_SEAL",))))
        return tuple(edges)
    if state.parent_evidence == "SEALED" and state.local_disposition == "NONE":
        if state.producer == "INTERNAL_FAILURE" or state.checker == "INTERNAL_FAILURE":
            disposition = "INTERNAL_FAILURE"
        elif state.producer == "INCONCLUSIVE_RESOURCE" or state.checker == "INCONCLUSIVE_RESOURCE":
            disposition = "INCONCLUSIVE_RESOURCE"
        elif state.producer == "CANDIDATE_CAPSULE" and state.checker == "CANDIDATE_CAPSULE":
            disposition = "LOCAL_CHECKED_CANDIDATE"
        else:
            disposition = "INTERNAL_FAILURE"
        edges.append(("ORCH-012-DECIDE-LOCAL-DISPOSITION", replace(state, local_disposition=disposition, decision_chain=(f"LOCAL_DISPOSITION:{disposition}",))))
        return tuple(edges)
    if state.local_disposition != "NONE" and state.publication == "NONE":
        edges.append(("ORCH-013-PREPARE-PUBLICATION", replace(state, publication="PREPARED", publication_chain=("PREPARED",))))
        edges.append(("ORCH-014-ABANDON-BEFORE-PREPARE", replace(state, publication="ABANDONED")))
        return tuple(edges)
    if state.publication == "PREPARED":
        edges.append(("ORCH-015-MAKE-DURABLE", replace(state, publication="DURABLE", publication_chain=state.publication_chain + ("DURABLE",))))
        edges.append(("ORCH-016-ABANDON-PREPARED", replace(state, publication="ABANDONED")))
        return tuple(edges)
    if state.publication == "DURABLE":
        edges.append(("ORCH-017-PUBLISH-DURABLE", replace(state, publication="PUBLISHED", publication_chain=state.publication_chain + ("PUBLISHED",))))
        return tuple(edges)
    return ()


def explore_orchestrator() -> dict[str, object]:
    start = OrchestratorState()
    queue: deque[OrchestratorState] = deque([start])
    seen = {start}
    edges = 0
    terminals: Counter[str] = Counter()
    deadlocks = 0
    while queue:
        state = queue.popleft()
        if not orchestrator_type_ok(state):
            raise ProtocolReject("F05-SPV3-ORCH-REACHABLE-TYPE", state.publication)
        outgoing = orchestrator_next(state)
        edges += len(outgoing)
        if state.publication in {"PUBLISHED", "ABANDONED", "ORPHANED"}:
            terminals[state.publication] += 1
            if outgoing:
                raise ProtocolReject("F05-SPV3-ORCH-TERMINAL-EDGE", state.publication)
        elif not outgoing:
            deadlocks += 1
        for _, successor in outgoing:
            if successor.semantic_verdict != "UNISSUED":
                raise ProtocolReject("F05-SPV3-SEMANTIC-SELF-ISSUE", successor.semantic_verdict)
            if successor not in seen:
                seen.add(successor)
                queue.append(successor)
    return {
        "state_count": len(seen),
        "edge_count": edges,
        "terminal_counts": dict(sorted(terminals.items())),
        "nonterminal_deadlock_count": deadlocks,
        "semantic_verdict_always_unissued": True,
    }


ACTION_IDS = tuple(
    [f"ENV-{index:03d}" for index in range(1, 24)]
)


__all__ = [
    "ACTION_IDS",
    "DECISIONS",
    "EVIDENCE_ISSUERS",
    "EnvelopeState",
    "Exploration",
    "OrchestratorState",
    "ProtocolReject",
    "apply_trace",
    "classify_quiescent",
    "derived_quiescent",
    "explore",
    "explore_orchestrator",
    "initial_state",
    "inject_conflicting_wait",
    "inject_conflicting_winner",
    "inject_duplicate_frame",
    "inject_foreign_receipt",
    "next_states",
    "orchestrator_next",
    "orchestrator_type_ok",
    "type_ok",
]
