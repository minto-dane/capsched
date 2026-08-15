#!/usr/bin/env python3
"""Named exact-value fixtures for the Rust hostile-WF differential slice."""

from __future__ import annotations

from dataclasses import dataclass, fields, is_dataclass, replace
from typing import Any

import f0_supervisor_lts_v3 as model
from python_oracle import encode


FIXTURE_HEADER = "F0_C4_RUST_HOSTILE_WF_FIXTURES_V2"
RESULT_HEADER = "F0_C4_RUST_HOSTILE_WF_RESULTS_V2"
ORIGINAL_CASE_TOTAL = 295
BASE_WF_MAPPED_ORIGINAL_CASE_CREDITS = 59
MAPPED_ORIGINAL_CASE_CREDITS = 71
SUPPLEMENTAL_EDGE_CASES = 10
SETUP = (
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
CLEANUP_AFTER_COMPLETION = (
    "OBS-043-CSS-OFFLINE",
    "OBS-044-SCOPE-RELEASED",
    "SUP-045-SEAL-EVIDENCE",
    "SUP-046-DECIDE-LOCAL",
)


@dataclass(frozen=True)
class Fixture:
    fixture_id: str
    value: model.RunGrant | model.EnvelopeState

    @property
    def kind(self) -> str:
        if isinstance(self.value, model.RunGrant):
            return "G"
        if isinstance(self.value, model.EnvelopeState):
            return "S"
        raise TypeError(f"unsupported hostile fixture: {type(self.value).__qualname__}")


@dataclass(frozen=True)
class EdgeFixture:
    fixture_id: str
    action_id: str
    actor: str
    before: model.EnvelopeState
    after: model.EnvelopeState

    @property
    def kind(self) -> str:
        return "E"


FixtureCase = Fixture | EdgeFixture


def start(role: str = "PRODUCER") -> model.EnvelopeState:
    return model.initial_state(model.fixture_external_grant(role))


def run(role: str, actions: tuple[str, ...]) -> model.EnvelopeState:
    return model.apply_trace(start(role), actions)


def clean_candidate_trace(
    role: str,
    candidate_action: str,
    *,
    exit_first: bool = False,
) -> tuple[str, ...]:
    observations = (
        ("OBS-029-NORMAL-EXIT", candidate_action, "OBS-013-EOF-VALID")
        if exit_first
        else (candidate_action, "OBS-013-EOF-VALID", "OBS-029-NORMAL-EXIT")
    )
    return SETUP + observations + (
        "OBS-033B-COMPLETION-ARRIVAL",
        "MON-035B-REVOKE-EXECUTION",
        "OBS-036-LEADER-REAPED",
        "OBS-037-VISIBLE-EMPTY",
        "OBS-039-RMDIR-ATTACH-CLOSED",
        "SUP-039B-CLOSE-ASYNC-ADMISSION",
        "MON-039C-PROTECTION-CLOSED",
        "OBS-038-TASK-POPULATION-ZERO",
        "OBS-040-HIDDEN-WORK-DRAINED",
        "MON-041-FINAL-COUNTERS",
        "ARB-034-COMPLETION-WINS",
    ) + CLEANUP_AFTER_COMPLETION


def quiescent_candidate() -> model.EnvelopeState:
    state = run(
        "PRODUCER",
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A")[:-1],
    )
    if state.phase != "QUIESCENT":
        raise RuntimeError("quiescent hostile fixture drift")
    return state


def coherent_receipt_mutation(
    receipt: model.Receipt,
    **changes: object,
) -> model.Receipt:
    changed = replace(receipt, **changes, auth_tag="")
    if (
        ("kind" in changes or "payload" in changes)
        and "payload_digest" not in changes
    ):
        changed = replace(
            changed,
            payload_digest=model.digest(
                "RECEIPT_PAYLOAD",
                changed.kind,
                changed.payload,
            ),
        )
    return replace(changed, auth_tag=model._receipt_auth_tag(changed))


def rechain_open_receipts(
    state: model.EnvelopeState,
    receipts: tuple[model.Receipt, ...],
) -> model.EnvelopeState:
    if state.evidence_ledger != "OPEN":
        raise ValueError("hostile fixture rechain requires open evidence")
    previous = model.genesis_hash(state.grant)
    rebuilt: list[model.Receipt] = []
    for sequence, receipt in enumerate(receipts, start=1):
        current = replace(
            receipt,
            sequence=sequence,
            previous_hash=previous,
            auth_tag="",
        )
        current = replace(current, auth_tag=model._receipt_auth_tag(current))
        rebuilt.append(current)
        previous = model.receipt_hash(current)
    return replace(state, evidence_receipts=tuple(rebuilt))


def cases() -> tuple[FixtureCase, ...]:
    producer_grant = model.fixture_external_grant("PRODUCER")
    checker_grant = model.fixture_external_grant("CHECKER")
    fixtures = [
        Fixture("grant.baseline.producer", producer_grant),
        Fixture("grant.baseline.checker", checker_grant),
    ]
    for fixture_id, grant in (
        (
            "grant.reject.foreign-child-id",
            replace(producer_grant, child_run_id=checker_grant.child_run_id),
        ),
        ("grant.reject.role-ordinal", replace(producer_grant, ordinal=1)),
        (
            "grant.reject.foreign-nonce",
            replace(producer_grant, nonce=checker_grant.nonce),
        ),
        (
            "grant.reject.foreign-scope",
            replace(producer_grant, scope_id=checker_grant.scope_id),
        ),
        ("grant.reject.zero-budget", replace(producer_grant, budget_limit=0)),
        ("grant.reject.empty-policy", replace(producer_grant, policy_digest="")),
        (
            "grant.reject.supervisor-issuer",
            replace(producer_grant, issuer="PRIMARY_SUPERVISOR"),
        ),
        ("grant.reject.forged-auth", replace(producer_grant, auth_tag="forged")),
    ):
        fixtures.append(Fixture(fixture_id, grant))

    first = model.apply_trace(start(), ("SUP-001-REQUEST-SCOPE",))
    receipt = first.evidence_receipts[0]
    receipt_mutations = (
        (
            "receipt.reject.unknown-kind",
            coherent_receipt_mutation(receipt, kind="FORGED_KIND"),
        ),
        (
            "receipt.reject.wrong-issuer",
            coherent_receipt_mutation(receipt, issuer="ADVERSARY"),
        ),
        (
            "receipt.reject.foreign-run",
            coherent_receipt_mutation(receipt, run_id="foreign-run"),
        ),
        (
            "receipt.reject.foreign-binding",
            coherent_receipt_mutation(receipt, binding_digest="foreign-binding"),
        ),
        (
            "receipt.reject.foreign-scope",
            coherent_receipt_mutation(receipt, scope_id="foreign-scope"),
        ),
        (
            "receipt.reject.foreign-subject",
            coherent_receipt_mutation(receipt, subject_id="foreign-subject"),
        ),
        (
            "receipt.reject.sequence-gap",
            coherent_receipt_mutation(receipt, sequence=2),
        ),
        (
            "receipt.reject.rollback-root",
            coherent_receipt_mutation(receipt, previous_hash="rollback-root"),
        ),
        (
            "receipt.reject.changed-payload",
            coherent_receipt_mutation(receipt, payload="changed"),
        ),
        (
            "receipt.reject.forged-auth",
            replace(receipt, auth_tag="forged-auth"),
        ),
    )
    for fixture_id, mutated in receipt_mutations:
        fixtures.append(
            Fixture(
                fixture_id,
                replace(first, evidence_receipts=(mutated,)),
            )
        )
    fixtures.append(
        Fixture(
            "receipt.reject.duplicate-singleton",
            replace(first, evidence_receipts=(receipt, receipt)),
        )
    )
    fixtures.append(
        Fixture(
            "receipt.reject.future-lifecycle",
            model._append_receipt(
                first,
                "TARGET_LINUX_OBSERVER",
                "SCOPE_RELEASED_ACK",
                first.grant.scope_id,
            ),
        )
    )

    running = model.apply_trace(start(), SETUP)
    normal_edge = next(
        edge
        for edge in model.next_states(running)
        if edge.action_id == "OBS-029-NORMAL-EXIT"
    )
    fixtures.append(
        Fixture(
            "state.reject.unrestricted-stopping",
            replace(start(), phase="STOPPING"),
        )
    )
    fixtures.append(
        Fixture(
            "state.accept.smuggled-descendant-before-edge-check",
            replace(
                normal_edge.state,
                descendants="LIVE",
                descendant_generation=1,
                visible_population="NONEMPTY",
            ),
        )
    )
    fixtures.append(
        Fixture(
            "state.reject.setup-causal-inversion",
            rechain_open_receipts(
                running,
                (
                    running.evidence_receipts[1],
                    running.evidence_receipts[0],
                )
                + tuple(running.evidence_receipts[2:]),
            ),
        )
    )
    fixtures.append(
        Fixture("state.reject.phase-rollback", replace(running, phase="NEW"))
    )
    fixtures.append(
        Fixture(
            "state.reject.candidate-without-receipt",
            replace(
                running,
                stream="FRAME",
                candidate_kind="PRODUCER_RESULT",
                candidate_value="VALUE_A",
                candidate_digest=model._expected_candidate_digest(
                    running,
                    "PRODUCER_RESULT",
                    "VALUE_A",
                ),
            ),
        )
    )
    fixtures.append(
        Fixture(
            "state.reject.winner-without-receipt",
            replace(running, winner="COMPLETION", winner_sequence=1),
        )
    )
    fixtures.append(
        Fixture(
            "state.reject.release-without-teardown",
            replace(running, scope="RELEASED", attach_authority="CLOSED"),
        )
    )

    reacquisition = run(
        "PRODUCER",
        SETUP
        + (
            "ADV-016-FORK-DESCENDANT",
            "ADV-017-OPEN-ASYNC-REF",
            "ADV-017-OPEN-ASYNC-REF",
            "OBS-029-NORMAL-EXIT",
            "OBS-032-DESCENDANTS-EXIT",
            "OBS-037-VISIBLE-EMPTY",
        ),
    )
    reopened = model.apply_trace(reacquisition, ("ADV-016-FORK-DESCENDANT",))
    redrained = model.apply_trace(
        reopened,
        ("OBS-032-DESCENDANTS-EXIT", "OBS-037-VISIBLE-EMPTY"),
    )
    async_cleanup = model.apply_trace(
        redrained,
        (
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
            "OBS-033-ASYNC-REFS-DRAIN",
            "OBS-033-ASYNC-REFS-DRAIN",
        ),
    )
    receipts = list(redrained.evidence_receipts)
    first_descendant = next(
        index
        for index, receipt in enumerate(receipts)
        if receipt.kind == "DESCENDANTS_EXITED"
    )
    wait_normal = next(
        index for index, receipt in enumerate(receipts) if receipt.kind == "WAIT_NORMAL"
    )
    receipts.insert(wait_normal, receipts.pop(first_descendant))
    fixtures.append(
        Fixture(
            "ordering.reject.early-descendant-drain",
            rechain_open_receipts(redrained, tuple(receipts)),
        )
    )
    receipts = list(async_cleanup.evidence_receipts)
    first_async = next(
        index
        for index, receipt in enumerate(receipts)
        if receipt.kind == "ASYNC_REFS_DRAINED"
    )
    admission_close = next(
        index
        for index, receipt in enumerate(receipts)
        if receipt.kind == "ASYNC_ADMISSION_CLOSED"
    )
    receipts.insert(admission_close, receipts.pop(first_async))
    fixtures.append(
        Fixture(
            "ordering.reject.early-async-drain",
            rechain_open_receipts(async_cleanup, tuple(receipts)),
        )
    )

    before_seal_for_order = run(
        "PRODUCER",
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A")[:-2],
    )
    receipts = list(before_seal_for_order.evidence_receipts)
    delayed_kinds = {"UNTRUSTED_FRAME_OBSERVED", "STREAM_EOF_VALID"}
    delayed = [receipt for receipt in receipts if receipt.kind in delayed_kinds]
    receipts = [receipt for receipt in receipts if receipt.kind not in delayed_kinds] + delayed
    fixtures.append(
        Fixture(
            "ordering.reject.completion-before-candidate-evidence",
            rechain_open_receipts(before_seal_for_order, tuple(receipts)),
        )
    )

    producer_a = run(
        "PRODUCER",
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A"),
    )
    fixtures.append(
        Fixture(
            "candidate.reject.value-digest-mix",
            replace(producer_a, candidate_value="VALUE_B"),
        )
    )
    quota_arrived = run("PRODUCER", SETUP + ("MON-026-QUOTA-ARRIVAL",))
    fixtures.append(
        Fixture(
            "arbitration.reject.quota-winner-without-receipt",
            replace(quota_arrived, winner="QUOTA", winner_sequence=1),
        )
    )

    before_final = run(
        "PRODUCER",
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
            "OBS-033B-COMPLETION-ARRIVAL",
            "MON-035B-REVOKE-EXECUTION",
            "OBS-036-LEADER-REAPED",
            "OBS-037-VISIBLE-EMPTY",
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
            "MON-039C-PROTECTION-CLOSED",
            "OBS-038-TASK-POPULATION-ZERO",
            "OBS-040-HIDDEN-WORK-DRAINED",
        ),
    )
    canonical_overlimit = next(
        edge.state
        for edge in model.next_states(before_final)
        if edge.action_id == "MON-041B-FINAL-OVERLIMIT-QUOTA"
    )
    forged_receipts = list(canonical_overlimit.evidence_receipts)
    forged_receipts[-1] = coherent_receipt_mutation(
        forged_receipts[-1],
        payload=(
            f"{canonical_overlimit.grant.budget_id}:"
            f"epoch={canonical_overlimit.grant.epoch}:"
            f"value={canonical_overlimit.grant.budget_limit}"
        ),
    )
    forged_overlimit = rechain_open_receipts(
        canonical_overlimit,
        tuple(forged_receipts),
    )
    fixtures.append(
        Fixture(
            "counters.reject.observed-exceeds-final",
            replace(
                forged_overlimit,
                final_value=canonical_overlimit.grant.budget_limit,
            ),
        )
    )
    normal_final = model.apply_trace(before_final, ("MON-041-FINAL-COUNTERS",))
    fixtures.append(
        Fixture(
            "counters.reject.unattributed-overlimit-final",
            replace(normal_final, final_value=normal_final.grant.budget_limit + 1),
        )
    )

    hostile_actions = {
        "ADV-018-ATTACH-ATTEMPT": "ATTACH",
        "ADV-019-FD-ESCAPE-ATTEMPT": "FD_ESCAPE",
        "ADV-020-PTRACE-ATTEMPT": "PTRACE",
        "ADV-021-FORGED-RECEIPT": "FORGED_RECEIPT",
        "ADV-022-REPLAY-RECEIPT": "REPLAY_RECEIPT",
    }
    for action_id, attack in hostile_actions.items():
        attempted = model.apply_trace(running, (action_id,))
        breached = model.apply_trace(
            attempted,
            ("ADV-023B-SUCCEED-HOSTILE-BYPASS",),
        )
        wrong = "FD_ESCAPE" if attack != "FD_ESCAPE" else "ATTACH"
        fixtures.append(
            Fixture(
                f"breach.reject.detached-{attack.lower().replace('_', '-')}",
                replace(breached, breach_kind=wrong),
            )
        )

    first_attempt = model.apply_trace(
        running,
        ("ADV-018-ATTACH-ATTEMPT", "OBS-023-REJECT-HOSTILE-ATTEMPT"),
    )
    second_attempt = model.apply_trace(first_attempt, ("ADV-019-FD-ESCAPE-ATTEMPT",))
    misnumbered_receipts = []
    for receipt in second_attempt.evidence_receipts:
        if receipt.kind in {"HOSTILE_ATTEMPT_OBSERVED", "HOSTILE_ATTEMPT_REJECTED"}:
            receipt = coherent_receipt_mutation(
                receipt,
                payload="attempt=1:kind=ATTACH",
            )
        misnumbered_receipts.append(receipt)
    fixtures.append(
        Fixture(
            "attack-ledger.reject-reused-attempt-number",
            rechain_open_receipts(second_attempt, tuple(misnumbered_receipts)),
        )
    )
    second_rejected = model.apply_trace(
        second_attempt,
        ("OBS-023-REJECT-HOSTILE-ATTEMPT",),
    )
    rejection_sequences = [
        index
        for index, receipt in enumerate(second_rejected.evidence_receipts, start=1)
        if receipt.kind == "HOSTILE_ATTEMPT_REJECTED"
    ]
    fixtures.append(
        Fixture(
            "fault.reject-later-hostile-pointer",
            replace(
                second_rejected,
                fault_cause_receipt_sequence=rejection_sequences[-1],
            ),
        )
    )
    rejected_then_internal = model.apply_trace(first_attempt, ("OBS-012-INTERNAL-FRAME",))
    internal_sequence = next(
        receipt.sequence
        for receipt in rejected_then_internal.evidence_receipts
        if receipt.kind == "UNTRUSTED_FRAME_OBSERVED"
        and receipt.payload.startswith("INTERNAL|INTERNAL|")
    )
    fixtures.append(
        Fixture(
            "fault.reject-later-internal-cause",
            rechain_open_receipts(
                replace(
                    rejected_then_internal,
                    fault_cause="INTERNAL_FRAME",
                    fault_cause_receipt_sequence=internal_sequence,
                ),
                tuple(rejected_then_internal.evidence_receipts),
            ),
        )
    )
    quota_then_fault = run(
        "PRODUCER",
        SETUP + ("MON-026-QUOTA-ARRIVAL", "OBS-012-INTERNAL-FRAME"),
    )
    permuted_arrival_receipts = []
    for receipt in quota_then_fault.evidence_receipts:
        if receipt.kind == "MONITOR_QUOTA_ARRIVED":
            receipt = coherent_receipt_mutation(
                receipt,
                payload=(
                    f"{quota_then_fault.grant.budget_id}:"
                    f"epoch={quota_then_fault.grant.epoch}:"
                    f"value={quota_then_fault.resource_observed_value}:arrival=2"
                ),
            )
        permuted_arrival_receipts.append(receipt)
    fixtures.append(
        Fixture(
            "arbitration.reject-arrival-number-causal-inversion",
            rechain_open_receipts(
                replace(
                    quota_then_fault,
                    quota_arrival_sequence=2,
                    fault_arrival_sequence=1,
                ),
                tuple(permuted_arrival_receipts),
            ),
        )
    )

    runtime_takeover = model.apply_trace(
        running,
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    fixtures.append(
        Fixture(
            "recovery.reject.missing-receipt",
            replace(runtime_takeover, recovery_receipts=()),
        )
    )
    recovery = runtime_takeover.recovery_receipts[0]
    foreign_recovery = replace(
        recovery,
        evidence_prefix_hash="foreign-prefix-root",
        auth_tag="",
    )
    foreign_recovery = replace(
        foreign_recovery,
        auth_tag=model._recovery_auth_tag(foreign_recovery),
    )
    fixtures.append(
        Fixture(
            "recovery.reject.foreign-prefix",
            replace(runtime_takeover, recovery_receipts=(foreign_recovery,)),
        )
    )
    fixtures.append(
        Fixture(
            "recovery.reject.detached-fault-cause",
            replace(runtime_takeover, fault_cause="INTERNAL_FRAME"),
        )
    )
    early_takeover = model.apply_trace(
        start(),
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    false_phase_recovery = replace(
        early_takeover.recovery_receipts[0],
        observed_phase="RUNNING",
        auth_tag="",
    )
    false_phase_recovery = replace(
        false_phase_recovery,
        auth_tag=model._recovery_auth_tag(false_phase_recovery),
    )
    false_phase_receipt = coherent_receipt_mutation(
        early_takeover.evidence_receipts[-1],
        payload="phase=RUNNING",
    )
    false_phase_takeover = rechain_open_receipts(
        replace(
            early_takeover,
            recovery_receipts=(false_phase_recovery,),
        ),
        tuple(early_takeover.evidence_receipts[:-1]) + (false_phase_receipt,),
    )
    fixtures.append(
        Fixture(
            "recovery.reject.false-immediate-phase",
            false_phase_takeover,
        )
    )
    post_takeover_scope = model.apply_trace(early_takeover, ("SUP-001-REQUEST-SCOPE",))
    later_false_recovery = replace(
        post_takeover_scope.recovery_receipts[0],
        observed_phase="RUNNING",
        auth_tag="",
    )
    later_false_recovery = replace(
        later_false_recovery,
        auth_tag=model._recovery_auth_tag(later_false_recovery),
    )
    later_false_receipts = tuple(
        coherent_receipt_mutation(receipt, payload="phase=RUNNING")
        if receipt.kind == "PRIMARY_FAILOVER"
        else receipt
        for receipt in post_takeover_scope.evidence_receipts
    )
    fixtures.append(
        Fixture(
            "recovery.reject.false-prefix-phase-after-later-receipt",
            rechain_open_receipts(
                replace(
                    post_takeover_scope,
                    recovery_receipts=(later_false_recovery,),
                ),
                later_false_receipts,
            ),
        )
    )
    guardian_scope = model.apply_trace(
        start(),
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH", "SUP-001-REQUEST-SCOPE"),
    )
    stale_receipt = coherent_receipt_mutation(
        guardian_scope.evidence_receipts[-1],
        issuer="PRIMARY_SUPERVISOR",
    )
    fixtures.append(
        Fixture(
            "recovery.reject.stale-primary-after-fence",
            replace(
                guardian_scope,
                evidence_receipts=tuple(guardian_scope.evidence_receipts[:-1])
                + (stale_receipt,),
            ),
        )
    )
    guardian_ambient = model._append_receipt(
        start(),
        "RECOVERY_GUARDIAN",
        "SCOPE_REQUESTED",
        start().grant.scope_id,
    )
    fixtures.append(
        Fixture(
            "recovery.reject.guardian-before-fence",
            replace(
                guardian_ambient,
                phase="SCOPE_REQUESTED",
                scope="REQUESTED",
            ),
        )
    )

    candidate_a_edge = next(
        edge
        for edge in model.next_states(running)
        if edge.action_id == "OBS-009A-PRODUCER-CANDIDATE-A"
    )
    framed_for_effects = candidate_a_edge.state
    valid_eof_edge = next(
        edge
        for edge in model.next_states(framed_for_effects)
        if edge.action_id == "OBS-013-EOF-VALID"
    )
    truncated_eof_edge = next(
        edge
        for edge in model.next_states(normal_edge.state)
        if edge.action_id == "OBS-014-EOF-TRUNCATED"
    )
    invalid_eof_edge = next(
        edge
        for edge in model.next_states(running)
        if edge.action_id == "OBS-015-EOF-INVALID"
    )
    signal_source = model.apply_trace(
        running,
        (
            "MON-026-QUOTA-ARRIVAL",
            "ARB-026B-QUOTA-WINS",
            "SUP-028-REQUEST-TERMINATION",
        ),
    )
    signal_edge = next(
        edge
        for edge in model.next_states(signal_source)
        if edge.action_id == "OBS-030-SIGNAL-EXIT"
    )
    abnormal_edge = next(
        edge
        for edge in model.next_states(running)
        if edge.action_id == "OBS-031-ABNORMAL-EXIT"
    )
    final_edge = next(
        edge
        for edge in model.next_states(before_final)
        if edge.action_id == "MON-041-FINAL-COUNTERS"
    )

    positive_edges = (
        (
            "edge.accept.immediate-takeover",
            start(),
            "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",
            "RECOVERY_GUARDIAN",
            early_takeover,
        ),
        (
            "edge.accept.guardian-scope-request",
            early_takeover,
            "SUP-001-REQUEST-SCOPE",
            "RECOVERY_GUARDIAN",
            guardian_scope,
        ),
        (
            "edge.accept.normal-exit",
            running,
            normal_edge.action_id,
            normal_edge.actor,
            normal_edge.state,
        ),
        (
            "edge.accept.producer-candidate-a",
            running,
            candidate_a_edge.action_id,
            candidate_a_edge.actor,
            candidate_a_edge.state,
        ),
        (
            "edge.accept.valid-eof",
            framed_for_effects,
            valid_eof_edge.action_id,
            valid_eof_edge.actor,
            valid_eof_edge.state,
        ),
        (
            "edge.accept.truncated-eof",
            normal_edge.state,
            truncated_eof_edge.action_id,
            truncated_eof_edge.actor,
            truncated_eof_edge.state,
        ),
        (
            "edge.accept.invalid-eof",
            running,
            invalid_eof_edge.action_id,
            invalid_eof_edge.actor,
            invalid_eof_edge.state,
        ),
        (
            "edge.accept.signal-exit",
            signal_source,
            signal_edge.action_id,
            signal_edge.actor,
            signal_edge.state,
        ),
        (
            "edge.accept.abnormal-exit",
            running,
            abnormal_edge.action_id,
            abnormal_edge.actor,
            abnormal_edge.state,
        ),
        (
            "edge.accept.final-counters",
            before_final,
            final_edge.action_id,
            final_edge.actor,
            final_edge.state,
        ),
    )
    for fixture_id, before, action_id, actor, after in positive_edges:
        model._edge(action_id, actor, before, after)
        fixtures.append(EdgeFixture(fixture_id, action_id, actor, before, after))

    omitted_effects: list[
        tuple[str, model.EnvelopeState, model.Edge, model.EnvelopeState]
    ] = []
    for label, before, edge in (
        ("valid-eof-writer-closure", framed_for_effects, valid_eof_edge),
        ("truncated-eof-writer-closure", normal_edge.state, truncated_eof_edge),
        ("invalid-eof-writer-closure", running, invalid_eof_edge),
    ):
        omitted = rechain_open_receipts(
            replace(edge.state, writer_confinement="CONFINED"),
            tuple(edge.state.evidence_receipts),
        )
        omitted_effects.append((label, before, edge, omitted))
    for label, before, edge in (
        ("normal-exit-hidden-work", running, normal_edge),
        ("signal-exit-hidden-work", signal_source, signal_edge),
        ("abnormal-exit-hidden-work", running, abnormal_edge),
    ):
        omitted = rechain_open_receipts(
            replace(edge.state, hidden_work="ACTIVE"),
            tuple(edge.state.evidence_receipts),
        )
        omitted_effects.append((label, before, edge, omitted))
    for label, before, edge, omitted in omitted_effects:
        if not model.instance_wf(omitted):
            raise RuntimeError(f"edge fixture {label}: hostile after-state lost WF")
        if model._action_semantics_wf(edge.action_id, before, omitted):
            raise RuntimeError(f"edge fixture {label}: omitted effect became valid")

    final_counter_receipts = list(normal_final.evidence_receipts)
    final_receipt = final_counter_receipts[-1]
    if final_receipt.kind != "FINAL_COUNTERS":
        raise RuntimeError("final-counter edge fixture drift")
    zero_payload = (
        f"{normal_final.grant.budget_id}:epoch={normal_final.grant.epoch}:value=0"
    )
    final_counter_receipts[-1] = coherent_receipt_mutation(
        final_receipt,
        payload=zero_payload,
        payload_digest=model.digest(
            "RECEIPT_PAYLOAD",
            final_receipt.kind,
            zero_payload,
        ),
    )
    zero_final = rechain_open_receipts(
        replace(normal_final, final_value=0),
        tuple(final_counter_receipts),
    )
    if not model.instance_wf(zero_final) or model._action_semantics_wf(
        "MON-041-FINAL-COUNTERS", before_final, zero_final
    ):
        raise RuntimeError("final-counter hostile edge fixture drift")

    invalid_edges = (
        (
            "edge.reject.takeover-false-observed-phase",
            start(),
            "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",
            "RECOVERY_GUARDIAN",
            false_phase_takeover,
        ),
        (
            "edge.reject.stale-controller-after-takeover",
            early_takeover,
            "SUP-001-REQUEST-SCOPE",
            "PRIMARY_SUPERVISOR",
            guardian_scope,
        ),
        (
            "edge.reject.nonstall-noop",
            running,
            "OBS-029-NORMAL-EXIT",
            "TARGET_LINUX_OBSERVER",
            running,
        ),
        (
            "edge.reject.normal-relabeled-abnormal",
            running,
            "OBS-031-ABNORMAL-EXIT",
            "TARGET_LINUX_OBSERVER",
            normal_edge.state,
        ),
        (
            "edge.reject.candidate-a-relabeled-b",
            running,
            "OBS-009B-PRODUCER-CANDIDATE-B",
            "TARGET_LINUX_OBSERVER",
            candidate_a_edge.state,
        ),
    ) + tuple(
        (
            f"edge.reject.omitted-{label}",
            before,
            edge.action_id,
            edge.actor,
            omitted,
        )
        for label, before, edge, omitted in omitted_effects
    ) + (
        (
            "edge.reject.final-counters-wrong-measurement",
            before_final,
            "MON-041-FINAL-COUNTERS",
            "MONITOR_OBSERVER",
            zero_final,
        ),
    )
    for fixture_id, before, action_id, actor, after in invalid_edges:
        try:
            model._edge(action_id, actor, before, after)
        except model.ProtocolReject:
            pass
        else:
            raise RuntimeError(f"edge fixture {fixture_id}: hostile edge accepted")
        fixtures.append(EdgeFixture(fixture_id, action_id, actor, before, after))

    quiescent = quiescent_candidate()
    fixtures.append(
        Fixture(
            "seal.reject.truncated-evidence",
            replace(
                quiescent,
                evidence_receipts=quiescent.evidence_receipts[:-1],
            ),
        )
    )
    fixtures.append(
        Fixture(
            "seal.reject.forged-root",
            replace(quiescent, evidence_root="rollback-root"),
        )
    )
    if producer_a.decision_receipt is None:
        raise RuntimeError("decided producer fixture lacks receipt")
    fixtures.append(
        Fixture(
            "decision.reject.foreign-evidence-root",
            replace(
                producer_a,
                decision_receipt=replace(
                    producer_a.decision_receipt,
                    evidence_root="foreign-root",
                ),
            ),
        )
    )
    fixtures.append(
        Fixture(
            "decision.reject.state-disagreement",
            replace(producer_a, local_decision="INCONCLUSIVE_RESOURCE"),
        )
    )
    fixtures.append(
        Fixture(
            "decision.reject.no-decision-receipt",
            replace(
                quiescent,
                phase="DECIDED",
                local_decision="LOCAL_SYNTACTIC_CANDIDATE",
            ),
        )
    )
    fixtures.append(
        Fixture(
            "seal.reject.quiescent-without-closure",
            replace(start(), phase="QUIESCENT"),
        )
    )
    fixtures.append(
        Fixture(
            "seal.reject.candidate-quiescent-without-seal",
            replace(
                run(
                    "PRODUCER",
                    clean_candidate_trace(
                        "PRODUCER",
                        "OBS-009A-PRODUCER-CANDIDATE-A",
                    )[:-2],
                ),
                phase="QUIESCENT",
            ),
        )
    )

    result = tuple(fixtures)
    if (
        len(result) != 81
        or len({fixture.fixture_id for fixture in result}) != len(result)
        or SUPPLEMENTAL_EDGE_CASES != len(positive_edges)
        or MAPPED_ORIGINAL_CASE_CREDITS
        != BASE_WF_MAPPED_ORIGINAL_CASE_CREDITS + len(invalid_edges)
        or len(result)
        != MAPPED_ORIGINAL_CASE_CREDITS + SUPPLEMENTAL_EDGE_CASES
    ):
        raise RuntimeError("hostile WF fixture inventory drift")
    return result


def normalize(value: Any) -> Any:
    if isinstance(value, model.PersistentSequence):
        return tuple(normalize(item) for item in value)
    if is_dataclass(value):
        return tuple(normalize(getattr(value, field.name)) for field in fields(value))
    if isinstance(value, (tuple, list)):
        return tuple(normalize(item) for item in value)
    return value


def fixture_bytes(fixtures: tuple[FixtureCase, ...]) -> bytes:
    lines = [f"{FIXTURE_HEADER}\t{len(fixtures)}"]
    for fixture in fixtures:
        if isinstance(fixture, EdgeFixture):
            lines.append(
                "\t".join(
                    (
                        fixture.kind,
                        fixture.fixture_id.encode("ascii").hex(),
                        fixture.action_id.encode("ascii").hex(),
                        fixture.actor.encode("ascii").hex(),
                        encode(normalize(fixture.before)).hex(),
                        encode(normalize(fixture.after)).hex(),
                    )
                )
            )
        else:
            lines.append(
                "\t".join(
                    (
                        fixture.kind,
                        fixture.fixture_id.encode("ascii").hex(),
                        encode(normalize(fixture.value)).hex(),
                    )
                )
            )
    return ("\n".join(lines) + "\n").encode("ascii")


def expected_result_bytes(fixtures: tuple[FixtureCase, ...]) -> bytes:
    lines = [f"{RESULT_HEADER}\t{len(fixtures)}"]
    for fixture in fixtures:
        prefix = f"R\t{fixture.fixture_id.encode('ascii').hex()}\t{fixture.kind}"
        if isinstance(fixture, EdgeFixture):
            try:
                model._edge(
                    fixture.action_id,
                    fixture.actor,
                    fixture.before,
                    fixture.after,
                )
            except model.ProtocolReject:
                accepted = False
            else:
                accepted = True
            lines.append(f"{prefix}\t{int(accepted)}")
        elif fixture.kind == "G":
            lines.append(f"{prefix}\t{int(model.grant_wf(fixture.value))}")
        else:
            lines.append(
                f"{prefix}\t{int(model.evidence_wf(fixture.value))}"
                f"\t{int(model.instance_wf(fixture.value))}"
            )
    return ("\n".join(lines) + "\n").encode("ascii")
