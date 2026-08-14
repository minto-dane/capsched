#!/usr/bin/env python3
"""Bounded hostile check for Candidate-4 audit-representation quotienting.

This test is deliberately not a proof of the unbounded implementation
refinement.  It checks every exact state expanded in a deterministic prefix:
projection-equivalent states must expose the same action identifiers and the
same projected successor for each action.  It also locks the projection's
retained and erased data classes against accidental weakening or re-expansion.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
import sys


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


SOURCE_LIMIT = 2_000
EXPECTED_ERASED_FIELDS = frozenset(
    {
        "winner_sequence",
        "fault_cause_receipt_sequence",
        "evidence_receipts",
        "evidence_root",
        "decision_receipt",
        "recovery_receipts",
    }
)


def successor_signature(
    state: model.EnvelopeState,
) -> tuple[tuple[str, tuple[object, ...]], ...]:
    rows = [
        (edge.action_id, model.behavioral_projection(edge.state))
        for edge in model.next_states(state)
    ]
    action_ids = [row[0] for row in rows]
    if len(action_ids) != len(set(action_ids)):
        raise AssertionError("one state exposed a duplicate action identifier")
    return tuple(sorted(rows, key=lambda row: row[0]))


def append_first_receipt() -> model.EnvelopeState:
    state = model.initial_state(model.fixture_external_grant("PRODUCER"))
    matches = [
        edge for edge in model.next_states(state)
        if edge.action_id == "SUP-001-REQUEST-SCOPE"
    ]
    if len(matches) != 1 or not matches[0].state.evidence_receipts:
        raise AssertionError("deterministic setup prefix changed")
    return matches[0].state


def projection_boundary_checks() -> int:
    cases = 0
    if model.BEHAVIORAL_PROJECTION_ERASED_STATE_FIELDS != EXPECTED_ERASED_FIELDS:
        raise AssertionError("behavioral projection erased-field policy drifted")
    cases += 1

    state = append_first_receipt()
    receipt = state.evidence_receipts[-1]
    representation_only = replace(
        state,
        evidence_receipts=(
            replace(
                receipt,
                sequence=receipt.sequence + 99,
                previous_hash="representation-only-previous-hash",
                auth_tag="representation-only-auth-tag",
            ),
        ),
        evidence_root="representation-only-root",
        winner_sequence=99,
        fault_cause_receipt_sequence=98,
    )
    if model.behavioral_projection(state) != model.behavioral_projection(
        representation_only
    ):
        raise AssertionError("audit representation leaked into behavioral identity")
    cases += 1

    semantic_receipt_change = replace(
        state,
        evidence_receipts=(replace(receipt, payload=receipt.payload + "-changed"),),
    )
    duplicate_receipt = replace(
        state,
        evidence_receipts=(receipt, receipt),
    )
    if (
        model.behavioral_projection(state)
        == model.behavioral_projection(semantic_receipt_change)
        or model.behavioral_projection(state)
        == model.behavioral_projection(duplicate_receipt)
    ):
        raise AssertionError("receipt semantics or multiplicity was erased")
    cases += 2

    if model.behavioral_projection(state) == model.behavioral_projection(
        replace(state, phase="RUNNING")
    ):
        raise AssertionError("operational state was erased")
    cases += 1

    recovery = model.RecoveryReceipt(
        schema=model.SCHEMA,
        run_id=state.grant.child_run_id,
        binding_digest=model.grant_binding_digest(state.grant),
        sequence=1,
        observed_phase="RUNNING",
        evidence_prefix_hash="representation-a",
        reason="PRIMARY_CRASH",
        failed_controller="PRIMARY_SUPERVISOR",
        fence_generation=1,
        issuer="RECOVERY_GUARDIAN",
        auth_tag="representation-b",
    )
    recovery_state = replace(state, recovery_receipts=(recovery,))
    recovery_representation = replace(
        recovery_state,
        recovery_receipts=(
            replace(
                recovery,
                evidence_prefix_hash="representation-c",
                auth_tag="representation-d",
            ),
        ),
    )
    recovery_semantic = replace(
        recovery_state,
        recovery_receipts=(replace(recovery, observed_phase="STOPPING"),),
    )
    if (
        model.behavioral_projection(recovery_state)
        != model.behavioral_projection(recovery_representation)
        or model.behavioral_projection(recovery_state)
        == model.behavioral_projection(recovery_semantic)
    ):
        raise AssertionError("recovery receipt projection boundary drifted")
    cases += 2

    decision = model.DecisionReceipt(
        schema=model.SCHEMA,
        run_id=state.grant.child_run_id,
        binding_digest=model.grant_binding_digest(state.grant),
        evidence_root="representation-e",
        decision="INTERNAL_FAILURE",
        payload_kind="NONE",
        payload_digest="",
        issuer="PRIMARY_SUPERVISOR",
        auth_tag="representation-f",
    )
    decision_state = replace(state, decision_receipt=decision)
    decision_representation = replace(
        decision_state,
        decision_receipt=replace(
            decision,
            evidence_root="representation-g",
            auth_tag="representation-h",
        ),
    )
    decision_semantic = replace(
        decision_state,
        decision_receipt=replace(decision, decision="ABANDONED"),
    )
    if (
        model.behavioral_projection(decision_state)
        != model.behavioral_projection(decision_representation)
        or model.behavioral_projection(decision_state)
        == model.behavioral_projection(decision_semantic)
    ):
        raise AssertionError("decision receipt projection boundary drifted")
    cases += 2
    return cases


def bounded_congruence_check() -> tuple[int, int, int, int]:
    start = model.initial_state(model.fixture_external_grant("PRODUCER"))
    states = model.CompactExactStateStore(
        model.EnvelopeState,
        model.CHILD_STATE_REFERENCE_FIELDS,
    )
    exact = model.ExactStateIndex(states)
    start_index, is_new = exact.intern(start)
    if start_index != 0 or not is_new:
        raise AssertionError("initial exact state was not uniquely interned")
    frontier = [start_index]
    class_representatives: dict[tuple[object, ...], int] = {}
    expanded = 0
    edges = 0
    equivalent_states = 0
    order_distinct_states = 0

    while expanded < len(frontier) and expanded < SOURCE_LIMIT:
        source_index = frontier[expanded]
        state = states[source_index]
        expanded += 1
        projection = model.behavioral_projection(state)
        representative_index = class_representatives.get(projection)
        if representative_index is None:
            class_representatives[projection] = source_index
        else:
            representative = states[representative_index]
            if representative == state:
                raise AssertionError("exact index retained a duplicate exact state")
            equivalent_states += 1
            if representative.evidence_receipts != state.evidence_receipts:
                order_distinct_states += 1
            if successor_signature(representative) != successor_signature(state):
                raise AssertionError(
                    "projection-equivalent states have different projected successors"
                )

        outgoing = model.next_states(state)
        for edge in outgoing:
            target_index, target_is_new = exact.intern(edge.state)
            if target_is_new:
                frontier.append(target_index)
            edges += 1

    if expanded != SOURCE_LIMIT or equivalent_states <= 0 or order_distinct_states <= 0:
        raise AssertionError(
            "bounded prefix did not exercise distinct exact audit orderings"
        )
    return expanded, len(states), edges, equivalent_states


def main() -> None:
    cases = projection_boundary_checks()
    expanded, states, edges, equivalent = bounded_congruence_check()
    print(
        "F0_C4_BEHAVIORAL_QUOTIENT_PASS "
        f"cases={cases} expanded={expanded} exact_states={states} "
        f"edges={edges} equivalent_expanded_states={equivalent}"
    )


if __name__ == "__main__":
    main()
