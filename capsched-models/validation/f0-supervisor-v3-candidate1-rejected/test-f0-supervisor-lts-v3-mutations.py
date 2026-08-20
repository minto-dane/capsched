#!/usr/bin/env python3
"""Hostile and ordered-trace regression for supervisor-envelope LTS v3."""

from __future__ import annotations

from dataclasses import replace

import f0_supervisor_lts_v3 as model


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


def start(role: str = "PRODUCER") -> model.EnvelopeState:
    return model.initial_state(model.fixture_external_grant(role))


def run(role: str, actions: tuple[str, ...]) -> model.EnvelopeState:
    return model.apply_trace(start(role), actions)


def clean_candidate_trace(role: str, candidate_action: str, *, exit_first: bool = False) -> tuple[str, ...]:
    observations = (
        ("OBS-029-NORMAL-EXIT", candidate_action, "OBS-013-EOF-VALID")
        if exit_first
        else (candidate_action, "OBS-013-EOF-VALID", "OBS-029-NORMAL-EXIT")
    )
    return SETUP + observations + (
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


def quiescent_candidate(role: str = "PRODUCER") -> model.EnvelopeState:
    candidate = "OBS-009A-PRODUCER-CANDIDATE-A" if role == "PRODUCER" else "OBS-010-CHECKER-ACCEPT"
    trace = clean_candidate_trace(role, candidate)[:-1]
    state = run(role, trace)
    assert state.phase == "QUIESCENT"
    return state


def expect_protocol_reject(label: str, operation) -> None:
    try:
        operation()
    except model.ProtocolReject:
        return
    raise AssertionError(f"{label}: expected ProtocolReject")


def assert_not_wf(label: str, state: model.EnvelopeState) -> None:
    if model.instance_wf(state):
        raise AssertionError(f"{label}: hostile state passed InstanceWF")


def coherent_receipt_mutation(receipt: model.Receipt, **changes: object) -> model.Receipt:
    changed = replace(receipt, **changes, auth_tag="")
    return replace(changed, auth_tag=model._receipt_auth_tag(changed))


def rechain_open_receipts(
    state: model.EnvelopeState,
    receipts: tuple[model.Receipt, ...],
) -> model.EnvelopeState:
    assert state.evidence_ledger == "OPEN"
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


def main() -> None:
    cases = 0

    producer_grant = model.fixture_external_grant("PRODUCER")
    checker_grant = model.fixture_external_grant("CHECKER")
    assert model.grant_wf(producer_grant)
    assert model.grant_wf(checker_grant)
    assert producer_grant.child_run_id != checker_grant.child_run_id
    cases += 3

    grant_mutations = (
        replace(producer_grant, child_run_id=checker_grant.child_run_id),
        replace(producer_grant, ordinal=1),
        replace(producer_grant, nonce=checker_grant.nonce),
        replace(producer_grant, scope_id=checker_grant.scope_id),
        replace(producer_grant, budget_limit=0),
        replace(producer_grant, policy_digest=""),
        replace(producer_grant, issuer="PRIMARY_SUPERVISOR"),
        replace(producer_grant, auth_tag="forged"),
    )
    for index, grant in enumerate(grant_mutations):
        assert not model.grant_wf(grant), f"grant mutation {index} passed"
        cases += 1

    first = model.apply_trace(start(), ("SUP-001-REQUEST-SCOPE",))
    receipt = first.evidence_receipts[0]
    receipt_mutations = (
        coherent_receipt_mutation(receipt, kind="FORGED_KIND"),
        coherent_receipt_mutation(receipt, issuer="ADVERSARY"),
        coherent_receipt_mutation(receipt, run_id="foreign-run"),
        coherent_receipt_mutation(receipt, binding_digest="foreign-binding"),
        coherent_receipt_mutation(receipt, scope_id="foreign-scope"),
        coherent_receipt_mutation(receipt, subject_id="foreign-subject"),
        coherent_receipt_mutation(receipt, sequence=2),
        coherent_receipt_mutation(receipt, previous_hash="rollback-root"),
        coherent_receipt_mutation(
            receipt,
            payload="changed",
            payload_digest=model.digest("RECEIPT_PAYLOAD", receipt.kind, "changed"),
        ),
        replace(receipt, auth_tag="forged-auth"),
    )
    for index, mutated in enumerate(receipt_mutations):
        assert_not_wf(
            f"receipt mutation {index}",
            replace(first, evidence_receipts=(mutated,)),
        )
        cases += 1
    assert_not_wf(
        "duplicate receipt",
        replace(first, evidence_receipts=(receipt, receipt)),
    )
    future_receipt = model._append_receipt(
        first,
        "TARGET_LINUX_OBSERVER",
        "SCOPE_RELEASED_ACK",
        first.grant.scope_id,
    )
    assert_not_wf("future lifecycle receipt without state", future_receipt)
    cases += 2

    running = model.apply_trace(start(), SETUP)
    reordered_setup = rechain_open_receipts(
        running,
        (
            running.evidence_receipts[1],
            running.evidence_receipts[0],
        )
        + running.evidence_receipts[2:],
    )
    assert_not_wf("resigned setup causal inversion", reordered_setup)
    assert_not_wf("phase rollback after hostile release", replace(running, phase="NEW"))
    forged_candidate = replace(
        running,
        stream="FRAME",
        candidate_kind="PRODUCER_RESULT",
        candidate_value="VALUE_A",
        candidate_digest=model._expected_candidate_digest(
            running,
            "PRODUCER_RESULT",
            "VALUE_A",
        ),
    )
    assert_not_wf("candidate without frame receipt", forged_candidate)
    assert_not_wf(
        "winner without linearization receipt",
        replace(running, winner="COMPLETION", winner_sequence=1),
    )
    assert_not_wf(
        "released scope without teardown receipts",
        replace(running, scope="RELEASED", attach_authority="CLOSED"),
    )
    cases += 5

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
    assert reacquisition.descendant_generation == reacquisition.descendant_drained_generation == 1
    assert reacquisition.async_generation == 2
    assert reacquisition.async_drained_generation == 0
    race_actions = {edge.action_id for edge in model.next_states(reacquisition)}
    assert "ADV-016-FORK-DESCENDANT" in race_actions
    assert "OBS-039-RMDIR-ATTACH-CLOSED" in race_actions
    reopened = model.apply_trace(reacquisition, ("ADV-016-FORK-DESCENDANT",))
    assert reopened.descendant_generation == 2
    assert reopened.descendant_drained_generation == 1
    assert reopened.descendants == "LIVE"
    assert reopened.visible_population == "NONEMPTY"
    assert "OBS-039-RMDIR-ATTACH-CLOSED" not in {
        edge.action_id for edge in model.next_states(reopened)
    }
    redrained = model.apply_trace(
        reopened,
        ("OBS-032-DESCENDANTS-EXIT", "OBS-037-VISIBLE-EMPTY"),
    )
    assert redrained.descendant_generation == redrained.descendant_drained_generation == 2
    assert redrained.visible_empty_observations == 2
    async_cleanup = model.apply_trace(
        redrained,
        (
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
            "OBS-033-ASYNC-REFS-DRAIN",
        ),
    )
    assert async_cleanup.async_refs == "LIVE"
    assert async_cleanup.async_drained_generation == 1
    assert "ADV-017-OPEN-ASYNC-REF" not in {
        edge.action_id for edge in model.next_states(async_cleanup)
    }
    async_cleanup = model.apply_trace(
        async_cleanup,
        ("OBS-033-ASYNC-REFS-DRAIN",),
    )
    assert async_cleanup.async_refs == "DRAINED"
    assert async_cleanup.async_drained_generation == 2
    cases += 17

    candidate_trace = clean_candidate_trace(
        "PRODUCER",
        "OBS-009A-PRODUCER-CANDIDATE-A",
    )
    protection_index = candidate_trace.index("MON-039C-PROTECTION-CLOSED") + 1
    protection_closed = run("PRODUCER", candidate_trace[:protection_index])
    assert protection_closed.protection_state == "CLOSED"
    assert protection_closed.execution_authority == "REVOKED"
    assert protection_closed.scope == "ATTACH_CLOSED"
    assert protection_closed.task_population == "NONEMPTY"
    assert protection_closed.hidden_work != "DRAINED"
    post_close_actions = {edge.action_id for edge in model.next_states(protection_closed)}
    assert "ADV-016-FORK-DESCENDANT" not in post_close_actions
    assert "ADV-017-OPEN-ASYNC-REF" not in post_close_actions
    cases += 7

    expect_protocol_reject(
        "supervisor cannot mint kernel wait receipt",
        lambda: model._append_receipt(
            running,
            "PRIMARY_SUPERVISOR",
            "WAIT_NORMAL",
            "forged",
        ),
    )
    cases += 1

    producer_a = run(
        "PRODUCER",
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A"),
    )
    producer_b = run(
        "PRODUCER",
        clean_candidate_trace(
            "PRODUCER",
            "OBS-009A-PRODUCER-CANDIDATE-A",
            exit_first=True,
        ),
    )
    assert producer_a.local_decision == producer_b.local_decision == "LOCAL_SYNTACTIC_CANDIDATE"
    assert model.semantic_projection(producer_a) != model.semantic_projection(producer_b)
    assert producer_a.evidence_receipts != producer_b.evidence_receipts
    assert producer_a.evidence_root != producer_b.evidence_root
    assert model.instance_wf(producer_a) and model.instance_wf(producer_b)
    cases += 5

    producer_value_b = run(
        "PRODUCER",
        clean_candidate_trace(
            "PRODUCER",
            "OBS-009B-PRODUCER-CANDIDATE-B",
        ),
    )
    assert producer_a.candidate_value == "VALUE_A"
    assert producer_value_b.candidate_value == "VALUE_B"
    assert producer_a.candidate_digest != producer_value_b.candidate_digest
    assert producer_a.evidence_root != producer_value_b.evidence_root
    assert_not_wf(
        "payload value and digest mix",
        replace(producer_a, candidate_value="VALUE_B"),
    )
    cases += 5

    checker_accept = run(
        "CHECKER",
        clean_candidate_trace("CHECKER", "OBS-010-CHECKER-ACCEPT"),
    )
    checker_reject = run(
        "CHECKER",
        clean_candidate_trace("CHECKER", "OBS-011-CHECKER-REJECT"),
    )
    assert checker_accept.candidate_kind == "CHECKER_ACCEPT"
    assert checker_reject.candidate_kind == "CHECKER_REJECT"
    assert checker_accept.local_decision == checker_reject.local_decision == "LOCAL_SYNTACTIC_CANDIDATE"
    cases += 3

    quota_trace = SETUP + (
        "MON-026-QUOTA-ARRIVAL",
        "ARB-026B-QUOTA-WINS",
        "OBS-009A-PRODUCER-CANDIDATE-A",
        "OBS-013-EOF-VALID",
        "SUP-028-REQUEST-TERMINATION",
        "OBS-030-SIGNAL-EXIT",
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
    quota = run("PRODUCER", quota_trace)
    assert quota.winner == "QUOTA"
    assert quota.resource_observed_value > quota.grant.budget_limit
    assert quota.local_decision == "INCONCLUSIVE_RESOURCE"
    quota_arrived = run("PRODUCER", SETUP + ("MON-026-QUOTA-ARRIVAL",))
    assert quota_arrived.winner == "OPEN"
    assert quota_arrived.quota_arrival_sequence == quota_arrived.event_clock == 1
    assert [edge.action_id for edge in model.next_states(quota_arrived)] == [
        "ARB-026B-QUOTA-WINS"
    ]
    assert_not_wf(
        "quota winner without arbiter receipt",
        replace(quota_arrived, winner="QUOTA", winner_sequence=1),
    )
    cases += 7

    quota_internal_prefix = SETUP + (
        "MON-026-QUOTA-ARRIVAL",
        "ARB-026B-QUOTA-WINS",
        "OBS-012-INTERNAL-FRAME",
    )
    quota_internal = run("PRODUCER", quota_internal_prefix)
    assert quota_internal.winner == "QUOTA"
    assert quota_internal.fault == "STICKY"
    assert quota_internal.quota_arrival_sequence == 1
    assert quota_internal.fault_arrival_sequence == 2
    assert quota_internal.event_clock == 2
    assert all(edge.state.winner == "QUOTA" for edge in model.next_states(quota_internal))
    cases += 6

    unattributed = run("PRODUCER", SETUP + ("OBS-027-UNATTRIBUTED-LIMIT",))
    assert unattributed.resource_event == "LINUX_UNATTRIBUTED"
    assert unattributed.fault == "STICKY"
    assert [edge.action_id for edge in model.next_states(unattributed)] == ["ARB-035-FAULT-WINS"]
    cases += 3

    before_final = run(
        "PRODUCER",
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
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
    before_final_actions = {edge.action_id for edge in model.next_states(before_final)}
    assert "ARB-034-COMPLETION-WINS" not in before_final_actions
    assert "MON-041-FINAL-COUNTERS" in before_final_actions
    assert "MON-041B-FINAL-OVERLIMIT-QUOTA" in before_final_actions
    overlimit = model.apply_trace(
        before_final,
        (
            "MON-041B-FINAL-OVERLIMIT-QUOTA",
            "ARB-026B-QUOTA-WINS",
            "OBS-043-CSS-OFFLINE",
            "OBS-044-SCOPE-RELEASED",
            "SUP-045-SEAL-EVIDENCE",
            "SUP-046-DECIDE-LOCAL",
        ),
    )
    assert overlimit.winner == "QUOTA"
    assert overlimit.final_value > overlimit.grant.budget_limit
    assert overlimit.local_decision == "INCONCLUSIVE_RESOURCE"
    normal_final = model.apply_trace(before_final, ("MON-041-FINAL-COUNTERS",))
    assert normal_final.winner == "OPEN"
    assert normal_final.completion_arrival_sequence == normal_final.event_clock == 1
    assert [edge.action_id for edge in model.next_states(normal_final)] == [
        "ARB-034-COMPLETION-WINS"
    ]
    assert_not_wf(
        "unattributed over-limit final counter",
        replace(normal_final, final_value=normal_final.grant.budget_limit + 1),
    )
    cases += 11

    revoked = run("PRODUCER", SETUP + ("EXT-025-REVOKE-RUN",))
    assert revoked.owner_state == "REVOKED" and revoked.fault == "STICKY"
    assert [edge.action_id for edge in model.next_states(revoked)] == ["ARB-035-FAULT-WINS"]
    cases += 2

    hostile_actions = {
        "ADV-018-ATTACH-ATTEMPT": "ATTACH",
        "ADV-019-FD-ESCAPE-ATTEMPT": "FD_ESCAPE",
        "ADV-020-PTRACE-ATTEMPT": "PTRACE",
        "ADV-021-FORGED-RECEIPT": "FORGED_RECEIPT",
        "ADV-022-REPLAY-RECEIPT": "REPLAY_RECEIPT",
    }
    for action_id, attack in hostile_actions.items():
        attempted = model.apply_trace(running, (action_id,))
        assert attempted.pending_attack == attack
        outgoing = model.next_states(attempted)
        assert {edge.action_id for edge in outgoing} == {
            "OBS-023-REJECT-HOSTILE-ATTEMPT",
            "ADV-023B-SUCCEED-HOSTILE-BYPASS",
        }
        rejected = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "OBS-023-REJECT-HOSTILE-ATTEMPT"
        )
        assert rejected.attack_seen == attack and rejected.fault == "STICKY"
        assert model.instance_wf(rejected)
        breached = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "ADV-023B-SUCCEED-HOSTILE-BYPASS"
        )
        assert breached.phase == "BREACHED"
        assert breached.protection_state == "BREACHED"
        assert breached.breach_kind == attack
        assert model.next_states(breached) == ()
        expect_protocol_reject(
            "breach cannot become decision certificate",
            lambda breached=breached: model.decision_certificate(breached),
        )
        cases += 9

    for setup_point in range(len(SETUP)):
        state = start()
        state = model.apply_trace(state, SETUP[:setup_point])
        takeover = model.apply_trace(state, ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",))
        assert takeover.controller == "RECOVERY_GUARDIAN"
        assert takeover.primary_state == "FAILED"
        assert takeover.fault == "CLEAN"
        assert model.instance_wf(takeover)
        cases += 4

    runtime_takeover = model.apply_trace(running, ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",))
    assert runtime_takeover.controller == "RECOVERY_GUARDIAN"
    assert runtime_takeover.fault == "STICKY"
    assert [edge.action_id for edge in model.next_states(runtime_takeover)] == ["ARB-035-FAULT-WINS"]
    assert_not_wf(
        "failed primary without guardian recovery receipt",
        replace(runtime_takeover, recovery_receipts=()),
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
    assert_not_wf(
        "resigned foreign recovery prefix",
        replace(runtime_takeover, recovery_receipts=(foreign_recovery,)),
    )
    cases += 5

    quiescent = quiescent_candidate()
    post_seal_takeover = model.apply_trace(
        quiescent,
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH", "SUP-046-DECIDE-LOCAL"),
    )
    assert post_seal_takeover.controller == "RECOVERY_GUARDIAN"
    assert post_seal_takeover.local_decision == "LOCAL_SYNTACTIC_CANDIDATE"
    assert post_seal_takeover.evidence_root == quiescent.evidence_root
    cases += 3

    expect_protocol_reject(
        "append after seal",
        lambda: model._append_receipt(
            quiescent,
            quiescent.controller,
            "EVIDENCE_SEAL",
            quiescent.evidence_root,
        ),
    )
    assert_not_wf(
        "truncate sealed evidence",
        replace(quiescent, evidence_receipts=quiescent.evidence_receipts[:-1]),
    )
    assert_not_wf(
        "forge evidence root",
        replace(quiescent, evidence_root="rollback-root"),
    )
    cases += 3

    forged_decision = replace(
        producer_a,
        decision_receipt=replace(producer_a.decision_receipt, evidence_root="foreign-root"),
    )
    assert_not_wf("foreign decision root", forged_decision)
    assert_not_wf(
        "decision/state disagreement",
        replace(producer_a, local_decision="INCONCLUSIVE_RESOURCE"),
    )
    assert_not_wf(
        "forged decided state without decision receipt",
        replace(quiescent, phase="DECIDED", local_decision="LOCAL_SYNTACTIC_CANDIDATE"),
    )
    unsealed_quiescent = replace(start(), phase="QUIESCENT")
    assert_not_wf("quiescent without sealed closure", unsealed_quiescent)
    expect_protocol_reject(
        "decision transition without sealed closure",
        lambda: model.next_states(unsealed_quiescent),
    )
    unsealed_candidate = replace(
        model.apply_trace(
            start(),
            clean_candidate_trace(
                "PRODUCER",
                "OBS-009A-PRODUCER-CANDIDATE-A",
            )[:-2],
        ),
        phase="QUIESCENT",
    )
    assert_not_wf("candidate decision path without seal", unsealed_candidate)
    cases += 6

    before_seal = model.apply_trace(
        start(),
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A")[:-2],
    )
    assert before_seal.scope == "RELEASED"
    before_seal_actions = {edge.action_id for edge in model.next_states(before_seal)}
    assert "SUP-045-SEAL-EVIDENCE" in before_seal_actions
    assert before_seal_actions <= {
        "SUP-045-SEAL-EVIDENCE",
        "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",
        "EXT-025-REVOKE-RUN",
    }
    early = model.apply_trace(
        start(),
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
        ),
    )
    assert "SUP-045-SEAL-EVIDENCE" not in {edge.action_id for edge in model.next_states(early)}
    cases += 3

    print(f"PASS supervisor v3 hostile and ordered-trace cases={cases}")


if __name__ == "__main__":
    main()
