#!/usr/bin/env python3
"""Hostile and ordered-trace regression for supervisor-envelope LTS v3."""

from __future__ import annotations

from array import array
from dataclasses import replace

if not __debug__:
    raise RuntimeError("supervisor mutation tests require Python assertions")

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


def assert_declared_commutation(
    state: model.EnvelopeState,
    left_action: str,
    right_action: str,
    expected_history_relation: str,
) -> None:
    left_then_right = model.apply_trace(state, (left_action, right_action))
    right_then_left = model.apply_trace(state, (right_action, left_action))
    prefix_length = len(state.evidence_receipts)
    assert left_then_right.evidence_receipts[:prefix_length] == state.evidence_receipts
    assert right_then_left.evidence_receipts[:prefix_length] == state.evidence_receipts
    assert model.outcome_projection(left_then_right) == model.outcome_projection(
        right_then_left
    )
    exact_equal = model.semantic_projection(
        left_then_right
    ) == model.semantic_projection(right_then_left)
    assert exact_equal == (expected_history_relation == "EXACT")


def coherent_receipt_mutation(receipt: model.Receipt, **changes: object) -> model.Receipt:
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


def exact_prefix(
    source_limit: int,
    *,
    compact: bool,
) -> tuple[object, array, array, array, int]:
    """Enumerate one bounded BFS prefix with or without packed state storage."""

    initial = start()
    states: object
    if compact:
        states = model.CompactExactStateStore(
            model.EnvelopeState,
            model.CHILD_STATE_REFERENCE_FIELDS,
        )
    else:
        states = []
    index = model.ExactStateIndex(states)
    initial_index, is_new = index.intern(model.semantic_projection(initial))
    assert initial_index == 0 and is_new
    frontier = array("I", [initial_index])
    targets = array("I")
    actions = array("B")
    cursor = 0
    while cursor < len(frontier) and cursor < source_limit:
        source = states[frontier[cursor]]
        cursor += 1
        for edge in model.next_states(source):
            target, target_is_new = index.intern(model.semantic_projection(edge.state))
            targets.append(target)
            actions.append(model.ACTION_INDEX[edge.action_id])
            if target_is_new:
                frontier.append(target)
    if compact:
        states.freeze()
    return states, frontier, targets, actions, cursor


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
    assert_not_wf(
        "unrestricted stopping phase",
        replace(start(), phase="STOPPING"),
    )
    normal_edge = next(
        edge for edge in model.next_states(running)
        if edge.action_id == "OBS-029-NORMAL-EXIT"
    )
    smuggled_descendant = replace(
        normal_edge.state,
        descendants="LIVE",
        descendant_generation=1,
        visible_population="NONEMPTY",
    )
    assert model.instance_wf(smuggled_descendant)
    expect_protocol_reject(
        "normal exit cannot smuggle descendant creation",
        lambda: model._edge(
            normal_edge.action_id,
            normal_edge.actor,
            running,
            smuggled_descendant,
        ),
    )
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
    cases += 8

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

    # A surviving descendant may acquire new hidden async work after the
    # leader exits.  Draining that descendant must move hidden work back to
    # PENDING, and the declared effect policy must permit that exact write.
    post_exit_hidden_work = run(
        "PRODUCER",
        SETUP
        + (
            "ADV-016-FORK-DESCENDANT",
            "OBS-029-NORMAL-EXIT",
            "ADV-017-OPEN-ASYNC-REF",
        ),
    )
    assert post_exit_hidden_work.hidden_work == "ACTIVE"
    post_exit_descendant_drain = model.apply_trace(
        post_exit_hidden_work,
        ("OBS-032-DESCENDANTS-EXIT",),
    )
    assert post_exit_descendant_drain.descendants == "EXITED"
    assert post_exit_descendant_drain.hidden_work == "PENDING"
    assert "hidden_work" in model.ACTION_WRITE_FIELDS["OBS-032-DESCENDANTS-EXIT"]
    cases += 1

    receipts = list(redrained.evidence_receipts)
    first_descendant = next(
        index for index, receipt in enumerate(receipts)
        if receipt.kind == "DESCENDANTS_EXITED"
    )
    wait_normal = next(
        index for index, receipt in enumerate(receipts)
        if receipt.kind == "WAIT_NORMAL"
    )
    moved = receipts.pop(first_descendant)
    receipts.insert(wait_normal, moved)
    assert_not_wf(
        "early first descendant drain hidden by later drain",
        rechain_open_receipts(redrained, tuple(receipts)),
    )
    receipts = list(async_cleanup.evidence_receipts)
    first_async = next(
        index for index, receipt in enumerate(receipts)
        if receipt.kind == "ASYNC_REFS_DRAINED"
    )
    admission_close = next(
        index for index, receipt in enumerate(receipts)
        if receipt.kind == "ASYNC_ADMISSION_CLOSED"
    )
    moved = receipts.pop(first_async)
    receipts.insert(admission_close, moved)
    assert_not_wf(
        "early first async drain hidden by later drain",
        rechain_open_receipts(async_cleanup, tuple(receipts)),
    )
    cases += 19

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
    assert model.outcome_projection(producer_a) != model.outcome_projection(producer_b)
    assert producer_a.evidence_receipts != producer_b.evidence_receipts
    assert producer_a.evidence_root != producer_b.evidence_root
    assert model.instance_wf(producer_a) and model.instance_wf(producer_b)
    before_seal_for_order = model.apply_trace(
        start("PRODUCER"),
        clean_candidate_trace("PRODUCER", "OBS-009A-PRODUCER-CANDIDATE-A")[:-2],
    )
    receipts = list(before_seal_for_order.evidence_receipts)
    delayed_kinds = {"UNTRUSTED_FRAME_OBSERVED", "STREAM_EOF_VALID"}
    delayed = [receipt for receipt in receipts if receipt.kind in delayed_kinds]
    receipts = [receipt for receipt in receipts if receipt.kind not in delayed_kinds] + delayed
    assert_not_wf(
        "completion linearized before candidate evidence",
        rechain_open_receipts(before_seal_for_order, tuple(receipts)),
    )
    cases += 7

    for role, candidate_actions in (
        (
            "PRODUCER",
            (
                "OBS-009A-PRODUCER-CANDIDATE-A",
                "OBS-009B-PRODUCER-CANDIDATE-B",
            ),
        ),
        (
            "CHECKER",
            (
                "OBS-010-CHECKER-ACCEPT",
                "OBS-011-CHECKER-REJECT",
            ),
        ),
    ):
        runtime = run(role, SETUP)
        for candidate_action in candidate_actions:
            assert_declared_commutation(
                runtime,
                candidate_action,
                "OBS-029-NORMAL-EXIT",
                "ORDER_DISTINCT",
            )
            framed = model.apply_trace(runtime, (candidate_action,))
            assert_declared_commutation(
                framed,
                "OBS-013-EOF-VALID",
                "OBS-029-NORMAL-EXIT",
                "ORDER_DISTINCT",
            )
        assert_declared_commutation(
            runtime,
            "ADV-016-FORK-DESCENDANT",
            "ADV-017-OPEN-ASYNC-REF",
            "EXACT",
        )
    assert len({spec.independence_id for spec in model.INDEPENDENCE_SPECS}) == len(
        model.INDEPENDENCE_SPECS
    )
    race_source = run(
        "PRODUCER",
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
        ),
    )
    completion_then_quota = model.apply_trace(
        race_source,
        ("OBS-033B-COMPLETION-ARRIVAL", "MON-026-QUOTA-ARRIVAL"),
    )
    quota_then_completion = model.apply_trace(
        race_source,
        ("MON-026-QUOTA-ARRIVAL", "OBS-033B-COMPLETION-ARRIVAL"),
    )
    assert model.outcome_projection(completion_then_quota) != model.outcome_projection(
        quota_then_completion
    )
    completion_winner = model.apply_trace(
        completion_then_quota,
        ("ARB-034-COMPLETION-WINS",),
    )
    quota_winner = model.apply_trace(
        quota_then_completion,
        ("ARB-026B-QUOTA-WINS",),
    )
    assert completion_winner.winner == "COMPLETION"
    assert quota_winner.winner == "QUOTA"
    declared_pairs = {
        frozenset((spec.left_action, spec.right_action))
        for spec in model.INDEPENDENCE_SPECS
    }
    assert frozenset(
        ("OBS-033B-COMPLETION-ARRIVAL", "MON-026-QUOTA-ARRIVAL")
    ) not in declared_pairs
    cases += 17

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
    quota_pending_actions = {edge.action_id for edge in model.next_states(quota_arrived)}
    assert "ARB-026B-QUOTA-WINS" in quota_pending_actions
    assert "OBS-009A-PRODUCER-CANDIDATE-A" in quota_pending_actions
    assert "ADV-018-ATTACH-ATTEMPT" in quota_pending_actions
    assert_not_wf(
        "quota winner without arbiter receipt",
        replace(quota_arrived, winner="QUOTA", winner_sequence=1),
    )
    quota_stopping = model.apply_trace(quota_arrived, ("ARB-026B-QUOTA-WINS",))
    stopping_actions = {edge.action_id for edge in model.next_states(quota_stopping)}
    assert "ADV-018-ATTACH-ATTEMPT" in stopping_actions
    assert "ADV-047-STALL" in stopping_actions
    cases += 11

    completion_then_quota = run(
        "PRODUCER",
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
            "OBS-033B-COMPLETION-ARRIVAL",
            "MON-026-QUOTA-ARRIVAL",
        ),
    )
    assert completion_then_quota.completion_arrival_sequence == 1
    assert completion_then_quota.quota_arrival_sequence == 2
    completion_wins = model.apply_trace(
        completion_then_quota,
        ("ARB-034-COMPLETION-WINS",),
    )
    assert completion_wins.winner == "COMPLETION"

    quota_then_completion = run(
        "PRODUCER",
        SETUP
        + (
            "MON-026-QUOTA-ARRIVAL",
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
            "OBS-033B-COMPLETION-ARRIVAL",
        ),
    )
    assert quota_then_completion.quota_arrival_sequence == 1
    assert quota_then_completion.completion_arrival_sequence == 2
    quota_wins = model.apply_trace(quota_then_completion, ("ARB-026B-QUOTA-WINS",))
    assert quota_wins.winner == "QUOTA"
    cases += 8

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
    assert "ARB-035-FAULT-WINS" in {
        edge.action_id for edge in model.next_states(unattributed)
    }
    cases += 3

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
    before_final_actions = {edge.action_id for edge in model.next_states(before_final)}
    assert "ARB-034-COMPLETION-WINS" in before_final_actions
    assert "MON-041-FINAL-COUNTERS" in before_final_actions
    assert "MON-041B-FINAL-OVERLIMIT-QUOTA" in before_final_actions
    overlimit = model.apply_trace(
        before_final,
        (
            "MON-041B-FINAL-OVERLIMIT-QUOTA",
            "ARB-034-COMPLETION-WINS",
            "OBS-043-CSS-OFFLINE",
            "OBS-044-SCOPE-RELEASED",
            "SUP-045-SEAL-EVIDENCE",
            "SUP-046-DECIDE-LOCAL",
        ),
    )
    assert overlimit.winner == "COMPLETION"
    assert overlimit.final_value > overlimit.grant.budget_limit
    assert overlimit.local_decision == "INTERNAL_FAILURE"
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
    forged_overlimit = replace(
        forged_overlimit,
        final_value=canonical_overlimit.grant.budget_limit,
    )
    assert_not_wf(
        "monitor over-limit observation exceeds final cumulative counter",
        forged_overlimit,
    )
    expect_protocol_reject(
        "over-limit final counter action rejects split observed/final values",
        lambda: model._edge(
            "MON-041B-FINAL-OVERLIMIT-QUOTA",
            "MONITOR_OBSERVER",
            before_final,
            forged_overlimit,
        ),
    )
    normal_final = model.apply_trace(before_final, ("MON-041-FINAL-COUNTERS",))
    assert normal_final.winner == "OPEN"
    assert normal_final.completion_arrival_sequence == normal_final.event_clock == 1
    assert "ARB-034-COMPLETION-WINS" in {
        edge.action_id for edge in model.next_states(normal_final)
    }
    assert_not_wf(
        "unattributed over-limit final counter",
        replace(normal_final, final_value=normal_final.grant.budget_limit + 1),
    )
    cases += 13

    revoked = run("PRODUCER", SETUP + ("EXT-025-REVOKE-RUN",))
    assert revoked.owner_state == "REVOKED" and revoked.fault == "STICKY"
    assert "ARB-035-FAULT-WINS" in {
        edge.action_id for edge in model.next_states(revoked)
    }
    assert "ADV-018-ATTACH-ATTEMPT" in {
        edge.action_id for edge in model.next_states(revoked)
    }
    cases += 3

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
        assert attempted.attack_attempts == (attack,)
        outgoing = model.next_states(attempted)
        assert {
            "OBS-023-REJECT-HOSTILE-ATTEMPT",
            "ADV-023B-SUCCEED-HOSTILE-BYPASS",
        } <= {edge.action_id for edge in outgoing}
        rejected = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "OBS-023-REJECT-HOSTILE-ATTEMPT"
        )
        assert rejected.attack_rejections == (attack,) and rejected.fault == "STICKY"
        assert model.instance_wf(rejected)
        breached = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "ADV-023B-SUCCEED-HOSTILE-BYPASS"
        )
        assert breached.phase == "BREACHED"
        assert breached.protection_state == "BREACHED"
        assert breached.breach_kind == attack
        assert_not_wf(
            "breach kind detached from latest attempt",
            replace(
                breached,
                breach_kind="FD_ESCAPE" if attack != "FD_ESCAPE" else "ATTACH",
            ),
        )
        assert model.next_states(breached) == ()
        expect_protocol_reject(
            "breach cannot become decision certificate",
            lambda breached=breached: model.decision_certificate(breached),
        )
        cases += 11

    first_attempt = model.apply_trace(
        running,
        ("ADV-018-ATTACH-ATTEMPT", "OBS-023-REJECT-HOSTILE-ATTEMPT"),
    )
    second_attempt = model.apply_trace(first_attempt, ("ADV-019-FD-ESCAPE-ATTEMPT",))
    assert second_attempt.attack_attempts == ("ATTACH", "FD_ESCAPE")
    assert second_attempt.attack_rejections == ("ATTACH",)
    assert second_attempt.pending_attack == "FD_ESCAPE"
    second_outcomes = {edge.action_id for edge in model.next_states(second_attempt)}
    assert "OBS-023-REJECT-HOSTILE-ATTEMPT" in second_outcomes
    assert "ADV-023B-SUCCEED-HOSTILE-BYPASS" in second_outcomes
    misnumbered_receipts = []
    for receipt in second_attempt.evidence_receipts:
        if receipt.kind in {
            "HOSTILE_ATTEMPT_OBSERVED",
            "HOSTILE_ATTEMPT_REJECTED",
        }:
            receipt = coherent_receipt_mutation(
                receipt,
                payload="attempt=1:kind=ATTACH",
            )
        misnumbered_receipts.append(receipt)
    misnumbered_second_attempt = rechain_open_receipts(
        second_attempt,
        tuple(misnumbered_receipts),
    )
    assert_not_wf(
        "child attack ledger cannot reuse attempt one for later records",
        misnumbered_second_attempt,
    )
    second_rejected = model.apply_trace(
        second_attempt,
        ("OBS-023-REJECT-HOSTILE-ATTEMPT",),
    )
    rejection_sequences = [
        index
        for index, receipt in enumerate(
            second_rejected.evidence_receipts,
            start=1,
        )
        if receipt.kind == "HOSTILE_ATTEMPT_REJECTED"
    ]
    moved_fault_pointer = replace(
        second_rejected,
        fault_cause_receipt_sequence=rejection_sequences[-1],
    )
    assert_not_wf(
        "sticky hostile fault remains bound to its first rejection",
        moved_fault_pointer,
    )
    expect_protocol_reject(
        "later rejection cannot rewrite a sticky fault pointer",
        lambda: model._edge(
            "OBS-023-REJECT-HOSTILE-ATTEMPT",
            "MANAGEMENT_DOMAIN_OBSERVER",
            second_attempt,
            moved_fault_pointer,
        ),
    )

    delayed_attempt = model.apply_trace(
        running,
        (
            "ADV-018-ATTACH-ATTEMPT",
            "OBS-029-NORMAL-EXIT",
            "MON-035B-REVOKE-EXECUTION",
            "OBS-036-LEADER-REAPED",
            "OBS-037-VISIBLE-EMPTY",
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
        ),
    )
    assert delayed_attempt.pending_attack == "ATTACH"
    assert delayed_attempt.protection_state == "EXECUTION_REVOKED"
    delayed_actions = {edge.action_id for edge in model.next_states(delayed_attempt)}
    assert "MON-039C-PROTECTION-CLOSED" not in delayed_actions
    assert "OBS-023-REJECT-HOSTILE-ATTEMPT" in delayed_actions
    assert "ADV-023B-SUCCEED-HOSTILE-BYPASS" in delayed_actions
    delayed_breached = model.apply_trace(
        delayed_attempt,
        ("ADV-023B-SUCCEED-HOSTILE-BYPASS",),
    )
    assert delayed_breached.phase == "BREACHED"
    assert delayed_breached.protection_state == "BREACHED"
    assert model.instance_wf(delayed_breached)
    delayed_rejected = model.apply_trace(
        delayed_attempt,
        ("OBS-023-REJECT-HOSTILE-ATTEMPT",),
    )
    assert delayed_rejected.pending_attack == "NONE"
    assert delayed_rejected.attack_attempts == delayed_rejected.attack_rejections
    assert "MON-039C-PROTECTION-CLOSED" in {
        edge.action_id for edge in model.next_states(delayed_rejected)
    }
    cases += 1

    rejected_then_internal = model.apply_trace(
        first_attempt,
        ("OBS-012-INTERNAL-FRAME",),
    )
    internal_sequence = next(
        receipt.sequence
        for receipt in rejected_then_internal.evidence_receipts
        if receipt.kind == "UNTRUSTED_FRAME_OBSERVED"
        and receipt.payload.startswith("INTERNAL|INTERNAL|")
    )
    reassigned_fault = rechain_open_receipts(
        replace(
            rejected_then_internal,
            fault_cause="INTERNAL_FRAME",
            fault_cause_receipt_sequence=internal_sequence,
        ),
        rejected_then_internal.evidence_receipts,
    )
    assert_not_wf(
        "later causal receipt cannot replace the first sticky fault cause",
        reassigned_fault,
    )

    quota_then_fault = run(
        "PRODUCER",
        SETUP + ("MON-026-QUOTA-ARRIVAL", "OBS-012-INTERNAL-FRAME"),
    )
    permuted_arrival_receipts = []
    for receipt in quota_then_fault.evidence_receipts:
        if receipt.kind == "MONITOR_QUOTA_ARRIVED":
            payload = (
                f"{quota_then_fault.grant.budget_id}:"
                f"epoch={quota_then_fault.grant.epoch}:"
                f"value={quota_then_fault.resource_observed_value}:arrival=2"
            )
            receipt = coherent_receipt_mutation(
                receipt,
                payload=payload,
                payload_digest=model.digest(
                    "RECEIPT_PAYLOAD",
                    receipt.kind,
                    payload,
                ),
            )
        permuted_arrival_receipts.append(receipt)
    permuted_arrivals = rechain_open_receipts(
        replace(
            quota_then_fault,
            quota_arrival_sequence=2,
            fault_arrival_sequence=1,
        ),
        tuple(permuted_arrival_receipts),
    )
    assert model.evidence_wf(permuted_arrivals)
    assert_not_wf(
        "arrival numbering must follow causal receipt order",
        permuted_arrivals,
    )
    cases += 10

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
    assert "ARB-035-FAULT-WINS" in {
        edge.action_id for edge in model.next_states(runtime_takeover)
    }
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
    assert_not_wf(
        "fault cause detached from causal receipt",
        replace(runtime_takeover, fault_cause="INTERNAL_FRAME"),
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
        early_takeover.evidence_receipts[:-1] + (false_phase_receipt,),
    )
    assert_not_wf(
        "immediate takeover cannot claim a false observed phase",
        false_phase_takeover,
    )
    expect_protocol_reject(
        "takeover edge binds the actual pre-state phase",
        lambda: model._edge(
            "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",
            "RECOVERY_GUARDIAN",
            start(),
            false_phase_takeover,
        ),
    )
    post_takeover_scope = model.apply_trace(
        early_takeover,
        ("SUP-001-REQUEST-SCOPE",),
    )
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
    later_false_takeover = rechain_open_receipts(
        replace(
            post_takeover_scope,
            recovery_receipts=(later_false_recovery,),
        ),
        later_false_receipts,
    )
    assert_not_wf(
        "later receipts cannot erase the takeover prefix phase",
        later_false_takeover,
    )
    guardian_scope = model.apply_trace(
        start(),
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH", "SUP-001-REQUEST-SCOPE"),
    )
    stale_receipt = coherent_receipt_mutation(
        guardian_scope.evidence_receipts[-1],
        issuer="PRIMARY_SUPERVISOR",
    )
    assert_not_wf(
        "stale primary receipt after fence",
        replace(
            guardian_scope,
            evidence_receipts=guardian_scope.evidence_receipts[:-1] + (stale_receipt,),
        ),
    )
    guardian_ambient = model._append_receipt(
        start(),
        "RECOVERY_GUARDIAN",
        "SCOPE_REQUESTED",
        start().grant.scope_id,
    )
    guardian_ambient = replace(
        guardian_ambient,
        phase="SCOPE_REQUESTED",
        scope="REQUESTED",
    )
    assert_not_wf("guardian ambient authority before fence", guardian_ambient)
    expect_protocol_reject(
        "stale controller edge after takeover",
        lambda: model._edge(
            "SUP-001-REQUEST-SCOPE",
            "PRIMARY_SUPERVISOR",
            model.apply_trace(start(), ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",)),
            guardian_scope,
        ),
    )
    running_for_effects = run("PRODUCER", SETUP)
    normal_edge = next(
        edge
        for edge in model.next_states(running_for_effects)
        if edge.action_id == "OBS-029-NORMAL-EXIT"
    )
    candidate_a_edge = next(
        edge
        for edge in model.next_states(running_for_effects)
        if edge.action_id == "OBS-009A-PRODUCER-CANDIDATE-A"
    )
    expect_protocol_reject(
        "non-stall child action cannot be a no-op",
        lambda: model._edge(
            "OBS-029-NORMAL-EXIT",
            "TARGET_LINUX_OBSERVER",
            running_for_effects,
            running_for_effects,
        ),
    )
    expect_protocol_reject(
        "normal exit cannot be relabeled abnormal",
        lambda: model._edge(
            "OBS-031-ABNORMAL-EXIT",
            "TARGET_LINUX_OBSERVER",
            running_for_effects,
            normal_edge.state,
        ),
    )
    expect_protocol_reject(
        "producer candidate A cannot be relabeled candidate B",
        lambda: model._edge(
            "OBS-009B-PRODUCER-CANDIDATE-B",
            "TARGET_LINUX_OBSERVER",
            running_for_effects,
            candidate_a_edge.state,
        ),
    )

    framed_for_effects = model.apply_trace(
        running_for_effects,
        ("OBS-009A-PRODUCER-CANDIDATE-A",),
    )
    valid_eof_edge = next(
        edge
        for edge in model.next_states(framed_for_effects)
        if edge.action_id == "OBS-013-EOF-VALID"
    )
    exited_open = normal_edge.state
    truncated_edge = next(
        edge
        for edge in model.next_states(exited_open)
        if edge.action_id == "OBS-014-EOF-TRUNCATED"
    )
    invalid_edge = next(
        edge
        for edge in model.next_states(running_for_effects)
        if edge.action_id == "OBS-015-EOF-INVALID"
    )
    for label, before, edge in (
        ("valid EOF", framed_for_effects, valid_eof_edge),
        ("truncated EOF", exited_open, truncated_edge),
        ("invalid EOF", running_for_effects, invalid_edge),
    ):
        omitted = rechain_open_receipts(
            replace(edge.state, writer_confinement="CONFINED"),
            edge.state.evidence_receipts,
        )
        assert model.instance_wf(omitted)
        assert not model._action_semantics_wf(edge.action_id, before, omitted)
        expect_protocol_reject(
            f"{label} cannot omit writer closure",
            lambda edge=edge, before=before, omitted=omitted: model._edge(
                edge.action_id,
                edge.actor,
                before,
                omitted,
            ),
        )

    signal_source = model.apply_trace(
        running_for_effects,
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
        for edge in model.next_states(running_for_effects)
        if edge.action_id == "OBS-031-ABNORMAL-EXIT"
    )
    for label, before, edge in (
        ("normal exit", running_for_effects, normal_edge),
        ("signal exit", signal_source, signal_edge),
        ("abnormal exit", running_for_effects, abnormal_edge),
    ):
        omitted = rechain_open_receipts(
            replace(edge.state, hidden_work="ACTIVE"),
            edge.state.evidence_receipts,
        )
        assert model.instance_wf(omitted)
        assert not model._action_semantics_wf(edge.action_id, before, omitted)
        expect_protocol_reject(
            f"{label} cannot omit pending hidden work",
            lambda edge=edge, before=before, omitted=omitted: model._edge(
                edge.action_id,
                edge.actor,
                before,
                omitted,
            ),
        )

    final_counter_receipts = list(normal_final.evidence_receipts)
    final_receipt = final_counter_receipts[-1]
    assert final_receipt.kind == "FINAL_COUNTERS"
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
    assert model.instance_wf(zero_final)
    assert not model._action_semantics_wf(
        "MON-041-FINAL-COUNTERS",
        before_final,
        zero_final,
    )
    expect_protocol_reject(
        "final counters require the exact measured value and receipt",
        lambda: model._edge(
            "MON-041-FINAL-COUNTERS",
            "MONITOR_OBSERVER",
            before_final,
            zero_final,
        ),
    )
    cases += 24

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

    packed_prefix = exact_prefix(2_000, compact=True)
    reference_prefix = exact_prefix(2_000, compact=False)
    packed_states, packed_frontier, packed_targets, packed_actions, packed_cursor = (
        packed_prefix
    )
    (
        reference_states,
        reference_frontier,
        reference_targets,
        reference_actions,
        reference_cursor,
    ) = reference_prefix
    assert packed_cursor == reference_cursor == 2_000
    assert packed_frontier == reference_frontier
    assert packed_targets == reference_targets
    assert packed_actions == reference_actions
    assert len(packed_states) == len(reference_states)
    for packed_state, reference_state in zip(
        packed_states,
        reference_states,
        strict=True,
    ):
        assert packed_state == reference_state
        assert hash(packed_state) == hash(reference_state)
        assert tuple(packed_state.evidence_receipts) == tuple(
            reference_state.evidence_receipts
        )
    evidence_index = packed_states._field_names.index("evidence_receipts")
    evidence_column = packed_states._columns[evidence_index].implementation
    assert isinstance(evidence_column, model._PackedPersistentSequenceColumn)
    assert evidence_column.arena.fixed_column_bytes_per_node_upper_bound == 17
    assert evidence_column.arena.fixed_column_bytes_per_record_upper_bound <= 64
    cases += 9

    print(f"LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases={cases}")


if __name__ == "__main__":
    main()
