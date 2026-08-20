#!/usr/bin/env python3
"""Hostile regression for actor-separated supervisor orchestration v3."""

from __future__ import annotations

from dataclasses import replace

import f0_supervisor_orchestrator_v3 as model


HAPPY = (
    "EXT-001-DELIVER-PARENT-GRANT",
    "SUP-002-CONSUME-PARENT-GRANT",
    "STORE-002B-COMMIT-GRANT-CONSUMPTION",
    "EXT-003-DELIVER-PRODUCER-GRANT",
    "SUP-004-START-PRODUCER",
    "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
    "EXT-009-DELIVER-CHECKER-GRANT",
    "SUP-010-START-CHECKER",
    "CHILD-011-ATTACH-CHECKER-ACCEPT",
    "SUP-016-SEAL-PARENT-EVIDENCE",
    "SUP-017-DECIDE-LOCAL-DISPOSITION",
    "SUP-018-PREPARE-LOCAL-PUBLICATION",
    "STORE-019-DURABLE-ACK",
    "STORE-020-PUBLISH-CAS",
)


def state_after(actions: tuple[str, ...]) -> model.OrchestratorState:
    return model.apply_trace(model.initial_state(), actions)


def assert_not_wf(label: str, state: model.OrchestratorState) -> None:
    if model.orchestrator_wf(state):
        raise AssertionError(f"{label}: hostile state passed OrchestratorWF")


def expect_reject(label: str, operation) -> None:
    try:
        operation()
    except model.OrchestratorReject:
        return
    raise AssertionError(f"{label}: expected OrchestratorReject")


def expect_reject_id(label: str, reject_id: str, operation) -> None:
    try:
        operation()
    except model.OrchestratorReject as exc:
        if exc.reject_id != reject_id:
            raise AssertionError(
                f"{label}: expected {reject_id}, got {exc.reject_id}"
            ) from exc
        return
    raise AssertionError(f"{label}: expected {reject_id}")


def coherent_parent_receipt_mutation(
    receipt: model.ParentReceipt,
    **changes: object,
) -> model.ParentReceipt:
    changed = replace(receipt, **changes, auth_tag="")
    return replace(changed, auth_tag=model._parent_receipt_auth(changed))


def coherent_grant_ack_mutation(
    ack: model.GrantConsumptionAck,
    **changes: object,
) -> model.GrantConsumptionAck:
    changed = replace(ack, **changes, auth_tag="")
    return replace(changed, auth_tag=model._grant_consumption_ack_auth(changed))


def rechain_open_parent_receipts(
    state: model.OrchestratorState,
    receipts: tuple[model.ParentReceipt, ...],
) -> model.OrchestratorState:
    assert state.parent_grant is not None and state.parent_ledger == "OPEN"
    previous = model._parent_genesis(state.parent_grant)
    rebuilt: list[model.ParentReceipt] = []
    for sequence, receipt in enumerate(receipts, start=1):
        current = replace(
            receipt,
            sequence=sequence,
            previous_hash=previous,
            auth_tag="",
        )
        current = replace(current, auth_tag=model._parent_receipt_auth(current))
        rebuilt.append(current)
        previous = model.parent_receipt_hash(current)
    return replace(state, parent_receipts=tuple(rebuilt))


def drive_abandonment(state: model.OrchestratorState) -> model.OrchestratorState:
    current = state
    for _ in range(6):
        if current.publication == "ABANDONED":
            return current
        actions = {edge.action_id for edge in model.next_states(current)}
        if "GRD-023B-FENCE-AFTER-OWNER-FAILURE" in actions:
            current = model.apply_trace(current, ("GRD-023B-FENCE-AFTER-OWNER-FAILURE",))
        elif "CHILD-024-ATTACH-ACTIVE-ABANDONED" in actions:
            current = model.apply_trace(current, ("CHILD-024-ATTACH-ACTIVE-ABANDONED",))
        elif "STORE-002C-RETIRE-GRANT-NONCE" in actions:
            current = model.apply_trace(current, ("STORE-002C-RETIRE-GRANT-NONCE",))
        elif "GRD-025-PREPARE-ABANDONMENT" in actions:
            current = model.apply_trace(current, ("GRD-025-PREPARE-ABANDONMENT",))
        elif "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT" in actions:
            current = model.apply_trace(current, ("STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",))
        else:
            raise AssertionError(f"no abandonment progress from {current.phase}")
    raise AssertionError("abandonment did not terminate")


def main() -> None:
    cases = 0

    parent = model.fixture_parent_grant()
    assert model.parent_grant_wf(parent)
    cases += 1
    parent_mutations = (
        replace(parent, parent_run_id="replayed-parent"),
        replace(parent, epoch=0),
        replace(parent, nonce=""),
        replace(parent, policy_digest=""),
        replace(parent, profile_digest=""),
        replace(parent, issuance_registry_id=""),
        replace(parent, issuance_generation=0),
        replace(parent, expected_publication_generation=-1),
        replace(parent, issuer="PRIMARY_SUPERVISOR"),
        replace(parent, auth_tag="forged"),
    )
    for index, mutated in enumerate(parent_mutations):
        assert not model.parent_grant_wf(mutated), f"parent mutation {index} passed"
        cases += 1

    delivered = state_after((HAPPY[0],))
    consume_requested = state_after(HAPPY[:2])
    consumed = state_after(HAPPY[:3])
    receipt = consume_requested.parent_receipts[0]
    receipt_mutations = (
        coherent_parent_receipt_mutation(receipt, kind="FORGED_KIND"),
        coherent_parent_receipt_mutation(receipt, issuer="ADVERSARY"),
        coherent_parent_receipt_mutation(receipt, parent_run_id="foreign-parent"),
        coherent_parent_receipt_mutation(receipt, binding_digest="foreign-binding"),
        coherent_parent_receipt_mutation(receipt, sequence=2),
        coherent_parent_receipt_mutation(receipt, previous_hash="rollback-root"),
        coherent_parent_receipt_mutation(
            receipt,
            payload="changed",
            payload_digest=model.child.digest(
                "PARENT_RECEIPT_PAYLOAD",
                receipt.kind,
                "changed",
            ),
        ),
        replace(receipt, auth_tag="forged"),
    )
    for index, mutated in enumerate(receipt_mutations):
        assert_not_wf(
            f"parent receipt mutation {index}",
            replace(consume_requested, parent_receipts=(mutated,)),
        )
        cases += 1
    assert_not_wf(
        "duplicate parent receipt",
        replace(consume_requested, parent_receipts=(receipt, receipt)),
    )
    extra_certificate_receipt = model._append_parent_receipt(
        consumed,
        "CHILD_ENVELOPE",
        "PRODUCER_CERT_ATTACHED",
        "forged-certificate-root",
    )
    assert_not_wf(
        "certificate receipt without certificate state",
        extra_certificate_receipt,
    )
    cases += 2

    expect_reject(
        "supervisor cannot mint parent grant",
        lambda: model._edge(
            "SUP-002-CONSUME-PARENT-GRANT",
            "PRIMARY_SUPERVISOR",
            model.initial_state(),
            replace(model.initial_state(), parent_grant=parent),
        ),
    )
    cases += 1

    requested_actions = {edge.action_id for edge in model.next_states(consume_requested)}
    assert "STORE-002B-COMMIT-GRANT-CONSUMPTION" in requested_actions
    assert "EXT-003-DELIVER-PRODUCER-GRANT" not in requested_actions
    assert "SUP-004-START-PRODUCER" not in requested_actions
    assert consume_requested.grant_registry_state == "PENDING"
    assert consume_requested.grant_consumption_ack is None
    assert not consume_requested.grant_consumed
    assert consumed.grant_registry_state == "CONSUMED"
    assert consumed.grant_consumption_ack is not None
    assert consumed.grant_consumption_ack.outcome == "CONSUMED"
    assert consumed.grant_registry_generation == parent.issuance_generation + 1
    cases += 10

    reordered_consumption = rechain_open_parent_receipts(
        consumed,
        (
            consumed.parent_receipts[1],
            consumed.parent_receipts[0],
        ),
    )
    assert_not_wf("resigned grant consumption causal inversion", reordered_consumption)
    cases += 1

    expect_reject(
        "supervisor cannot mint grant consumption ack",
        lambda: model._edge(
            "SUP-002-CONSUME-PARENT-GRANT",
            "PRIMARY_SUPERVISOR",
            consume_requested,
            replace(
                consume_requested,
                phase="PARENT_ACTIVE",
                grant_consumed=True,
                grant_registry_state="CONSUMED",
                grant_registry_generation=consumed.grant_registry_generation,
                grant_consumption_ack=consumed.grant_consumption_ack,
                parent_receipts=consumed.parent_receipts,
            ),
        ),
    )
    cases += 1

    consumed_ack = consumed.grant_consumption_ack
    assert_not_wf(
        "forged grant consumption ack",
        replace(
            consumed,
            grant_consumption_ack=replace(consumed_ack, auth_tag="forged"),
        ),
    )
    rollback_ack = coherent_grant_ack_mutation(
        consumed_ack,
        old_generation=parent.issuance_generation - 1,
        new_generation=parent.issuance_generation,
    )
    assert_not_wf(
        "grant registry rollback ack",
        replace(
            consumed,
            grant_registry_generation=rollback_ack.new_generation,
            grant_consumption_ack=rollback_ack,
        ),
    )
    assert_not_wf(
        "grant registry generation rollback",
        replace(consumed, grant_registry_generation=parent.issuance_generation),
    )
    assert_not_wf(
        "grant consumption outcome substitution",
        replace(
            consumed,
            grant_consumption_ack=coherent_grant_ack_mutation(
                consumed_ack,
                outcome="RETIRED",
            ),
        ),
    )
    cases += 4

    producer_running = state_after(HAPPY[:5])
    producer_candidate = state_after(HAPPY[:6])
    checker_granted = state_after(HAPPY[:7])
    checker_running = state_after(HAPPY[:8])
    children_complete = state_after(HAPPY[:9])
    sealed = state_after(HAPPY[:10])
    decided = state_after(HAPPY[:11])
    prepared = state_after(HAPPY[:12])
    durable = state_after(HAPPY[:13])
    published = state_after(HAPPY)

    assert producer_candidate.producer_grant.child_run_id != checker_granted.checker_grant.child_run_id
    assert checker_granted.checker_grant.immutable_input_digest == model.expected_checker_input(
        producer_candidate.producer_certificate
    )
    cases += 2

    producer_value_b = model.fixture_child_certificate(
        producer_candidate.producer_grant,
        "CANDIDATE_B",
    )
    assert producer_candidate.producer_certificate.payload_value == "VALUE_A"
    assert producer_value_b.payload_value == "VALUE_B"
    assert producer_candidate.producer_certificate.payload_digest != producer_value_b.payload_digest
    assert model.expected_checker_input(
        producer_candidate.producer_certificate
    ) != model.expected_checker_input(producer_value_b)
    cases += 4

    foreign_parent = replace(
        parent,
        parent_run_id="parent-e2-foreign",
        nonce="foreign-parent-nonce",
        epoch=2,
        auth_tag="",
    )
    foreign_parent = replace(foreign_parent, auth_tag=model._parent_grant_auth(foreign_parent))
    foreign_producer_grant = model.fixture_child_grant(
        foreign_parent,
        "PRODUCER",
        foreign_parent.immutable_input_digest,
    )
    foreign_certificate = model.fixture_child_certificate(foreign_producer_grant, "CANDIDATE")
    assert_not_wf(
        "producer certificate from foreign parent",
        replace(
            producer_candidate,
            producer_grant=foreign_producer_grant,
            producer_certificate=foreign_certificate,
        ),
    )
    cases += 1

    wrong_checker_grant = model.fixture_child_grant(
        parent,
        "CHECKER",
        "wrong-producer-root",
    )
    assert_not_wf(
        "checker grant not bound to producer",
        replace(checker_granted, checker_grant=wrong_checker_grant),
    )
    wrong_checker_certificate = model.fixture_child_certificate(
        wrong_checker_grant,
        "CANDIDATE",
    )
    assert_not_wf(
        "checker certificate mix and match",
        replace(
            children_complete,
            checker_grant=wrong_checker_grant,
            checker_certificate=wrong_checker_certificate,
        ),
    )
    cases += 2

    forged_producer_certificate = replace(
        producer_candidate.producer_certificate,
        evidence_root="foreign-evidence-root",
    )
    assert_not_wf(
        "forged child evidence root",
        replace(producer_candidate, producer_certificate=forged_producer_certificate),
    )
    forged_child_decision = replace(
        producer_candidate.producer_certificate.decision_receipt,
        auth_tag="forged-child-auth",
    )
    assert_not_wf(
        "forged child decision auth",
        replace(
            producer_candidate,
            producer_certificate=replace(
                producer_candidate.producer_certificate,
                decision_receipt=forged_child_decision,
            ),
        ),
    )
    certificate = producer_candidate.producer_certificate
    unreachable_decision = replace(
        certificate.decision_receipt,
        evidence_root="unreachable-but-resigned-root",
        auth_tag="",
    )
    unreachable_decision = replace(
        unreachable_decision,
        auth_tag=model.child._decision_auth_tag(unreachable_decision),
    )
    unreachable_certificate = replace(
        certificate,
        evidence_root=unreachable_decision.evidence_root,
        decision_receipt=unreachable_decision,
        certificate_digest="",
    )
    unreachable_certificate = replace(
        unreachable_certificate,
        certificate_digest=model.certificate_digest(unreachable_certificate),
    )
    assert not model.child_certificate_wf(
        unreachable_certificate,
        producer_candidate.parent_grant,
        "PRODUCER",
        producer_candidate.parent_grant.immutable_input_digest,
    )
    assert_not_wf(
        "resigned unreachable child terminal",
        replace(
            producer_candidate,
            producer_certificate=unreachable_certificate,
        ),
    )
    invalid_trace_certificate = replace(
        certificate,
        trace_actions=certificate.trace_actions[:-1],
        trace_digest=model._child_trace_digest(certificate.trace_actions[:-1]),
        certificate_digest="",
    )
    invalid_trace_certificate = replace(
        invalid_trace_certificate,
        certificate_digest=model.certificate_digest(invalid_trace_certificate),
    )
    assert not model.child_certificate_wf(
        invalid_trace_certificate,
        producer_candidate.parent_grant,
        "PRODUCER",
        producer_candidate.parent_grant.immutable_input_digest,
    )
    producer_summary_change = replace(
        certificate,
        local_decision="INTERNAL_FAILURE",
        certificate_digest="",
    )
    producer_summary_change = replace(
        producer_summary_change,
        certificate_digest=model.certificate_digest(producer_summary_change),
    )
    assert model.expected_checker_input(certificate) != model.expected_checker_input(
        producer_summary_change
    )
    cases += 6

    assert sealed.parent_ledger == "SEALED" and sealed.parent_evidence_root
    expect_reject(
        "append parent evidence after seal",
        lambda: model._append_parent_receipt(
            sealed,
            sealed.controller,
            "PARENT_EVIDENCE_SEAL",
            sealed.parent_evidence_root,
        ),
    )
    assert_not_wf(
        "truncate sealed parent evidence",
        replace(sealed, parent_receipts=sealed.parent_receipts[:-1]),
    )
    assert_not_wf(
        "replace sealed parent root",
        replace(sealed, parent_evidence_root="rollback-root"),
    )
    assert_not_wf(
        "local decision before parent seal",
        replace(children_complete, local_disposition="LOCAL_CHECKED_CANDIDATE"),
    )
    cases += 4

    assert decided.semantic_verdict is None
    assert decided.local_capsule.artifact_type == "LOCAL_DISPOSITION_CAPSULE"
    assert_not_wf(
        "local capsule relabeled semantic verdict",
        replace(
            decided,
            local_capsule=replace(
                decided.local_capsule,
                artifact_type="SEMANTIC_VERDICT",
            ),
        ),
    )
    assert_not_wf(
        "self-issued semantic verdict",
        replace(
            decided,
            semantic_verdict=model.SemanticVerdict(
                external_review_root="self-root",
                verdict="ACCEPT",
                external_issuer="PRIMARY_SUPERVISOR",
            ),
        ),
    )
    cases += 4

    assert "STORE-020-PUBLISH-CAS" not in {
        edge.action_id for edge in model.next_states(prepared)
    }
    assert published.publication == "PUBLISHED"
    assert published.durable_ack is not None
    assert published.store_head_generation == parent.expected_publication_generation + 1
    cases += 3

    assert_not_wf(
        "forged published state without durable ack",
        replace(published, durable_ack=None),
    )
    assert_not_wf(
        "future durable ack in prepared phase",
        replace(prepared, durable_ack=durable.durable_ack),
    )
    assert_not_wf(
        "future publication ack in prepared phase",
        replace(prepared, publication_ack=published.publication_ack),
    )
    assert_not_wf(
        "durable store head drift",
        replace(durable, store_head_generation=99),
    )
    assert_not_wf(
        "publication and phase disagreement",
        replace(prepared, phase="LOCAL_DECIDED"),
    )
    assert_not_wf(
        "publication generation rollback",
        replace(published, store_head_generation=0),
    )
    assert_not_wf(
        "publication ack generation jump",
        replace(
            published,
            publication_ack=replace(
                published.publication_ack,
                new_generation=2,
            ),
        ),
    )
    cases += 7

    stale_prepared = model.apply_trace(prepared, ("STORE-021-HEAD-CONFLICT",))
    stale_durable = model.apply_trace(durable, ("STORE-021-HEAD-CONFLICT",))
    assert stale_prepared.publication == stale_durable.publication == "STALE_REJECTED"
    assert stale_prepared.store_head_generation == stale_durable.store_head_generation == 1
    cases += 2

    for state, attack_action, expected in (
        (delivered, "ADV-027-REPLAY-GRANT", "GRANT_REPLAY"),
        (prepared, "ADV-028-ROLLBACK-PUBLICATION", "PUBLICATION_ROLLBACK"),
    ):
        attacked = model.apply_trace(state, (attack_action,))
        assert attacked.pending_attack == expected
        assert attacked.pending_attack_context
        assert attacked.store_attack_attempts == (expected,)
        assert attacked.attempted_attack_contexts == (
            attacked.pending_attack_context,
        )
        assert attacked.store_attack_rejections == ()
        assert tuple(event.event_kind for event in attacked.store_security_events) == (
            "ATTEMPT",
        )
        outgoing = model.next_states(attacked)
        assert {
            "STORE-029-REJECT-HOSTILE-REQUEST",
            "ADV-029B-SUCCEED-STORE-BYPASS",
        } <= {edge.action_id for edge in outgoing}
        rejected = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "STORE-029-REJECT-HOSTILE-REQUEST"
        )
        assert rejected.pending_attack == "NONE"
        assert rejected.pending_attack_context == ""
        assert rejected.store_attack_attempts == (expected,)
        assert rejected.attempted_attack_contexts == (
            attacked.pending_attack_context,
        )
        assert rejected.store_attack_rejections == (expected,)
        assert tuple(event.event_kind for event in rejected.store_security_events) == (
            "ATTEMPT",
            "REJECTED",
        )
        assert rejected.store_security_events[-1].issuer == "DURABLE_STORE"
        assert rejected.store_head_generation == state.store_head_generation
        assert rejected.publication_commitment == state.publication_commitment
        assert rejected.grant_registry_state == state.grant_registry_state
        assert rejected.grant_registry_generation == state.grant_registry_generation
        assert rejected.grant_consumption_ack == state.grant_consumption_ack
        breached = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "ADV-029B-SUCCEED-STORE-BYPASS"
        )
        expected_breach = {
            "GRANT_REPLAY": "GRANT_REGISTRY_BYPASS",
            "PUBLICATION_ROLLBACK": "PUBLICATION_ROLLBACK",
        }[expected]
        assert breached.phase == "ASSURANCE_BREACHED"
        assert breached.publication == "ASSURANCE_BREACHED"
        assert breached.assurance_breach == expected_breach
        assert breached.pending_attack == "NONE"
        assert breached.pending_attack_context == ""
        assert breached.store_attack_attempts == (expected,)
        assert breached.store_attack_rejections == ()
        assert breached.semantic_verdict is None
        assert model.next_states(breached) == ()
        assert model.orchestrator_wf(breached)
        wrong_breach = next(
            candidate
            for candidate in (
                "GRANT_REGISTRY_BYPASS",
                "PUBLICATION_ROLLBACK",
                "POST_OWNER_FAILURE_PUBLICATION",
            )
            if candidate != expected_breach
        )
        assert_not_wf(
            "store bypass reason does not match audited attack",
            replace(breached, assurance_breach=wrong_breach),
        )
        assert attacked.store_security_events[0].context_digest == (
            attacked.attempted_attack_contexts[0]
        )
        cases += 33

    first_attack = model.apply_trace(delivered, ("ADV-027-REPLAY-GRANT",))
    first_rejected = model.apply_trace(
        first_attack,
        ("STORE-029-REJECT-HOSTILE-REQUEST",),
    )
    prepared_after_rejection = model.apply_trace(first_rejected, HAPPY[1:12])
    second_attack = model.apply_trace(
        prepared_after_rejection,
        ("ADV-028-ROLLBACK-PUBLICATION",),
    )
    assert second_attack.store_attack_attempts == (
        "GRANT_REPLAY",
        "PUBLICATION_ROLLBACK",
    )
    assert second_attack.store_attack_rejections == ("GRANT_REPLAY",)
    second_rejected = model.apply_trace(
        second_attack,
        ("STORE-029-REJECT-HOSTILE-REQUEST",),
    )
    assert second_rejected.store_attack_rejections == (
        "GRANT_REPLAY",
        "PUBLICATION_ROLLBACK",
    )
    assert tuple(
        (event.attempt, event.event_kind, event.attack, event.context_digest)
        for event in second_rejected.store_security_events
    ) == (
        (
            1,
            "ATTEMPT",
            "GRANT_REPLAY",
            second_rejected.attempted_attack_contexts[0],
        ),
        (
            1,
            "REJECTED",
            "GRANT_REPLAY",
            second_rejected.attempted_attack_contexts[0],
        ),
        (
            2,
            "ATTEMPT",
            "PUBLICATION_ROLLBACK",
            second_rejected.attempted_attack_contexts[1],
        ),
        (
            2,
            "REJECTED",
            "PUBLICATION_ROLLBACK",
            second_rejected.attempted_attack_contexts[1],
        ),
    )
    assert len(set(second_rejected.attempted_attack_contexts)) == 2
    assert "ADV-028-ROLLBACK-PUBLICATION" not in {
        edge.action_id for edge in model.next_states(second_rejected)
    }
    forged_context_event = replace(
        second_rejected.store_security_events[0],
        context_digest="forged-context",
        auth_tag="",
    )
    forged_context_event = replace(
        forged_context_event,
        auth_tag=model._store_security_auth(forged_context_event),
    )
    assert_not_wf(
        "resigned store event context substitution",
        replace(
            second_rejected,
            store_security_events=(forged_context_event,)
            + second_rejected.store_security_events[1:],
        ),
    )
    assert model.orchestrator_wf(second_rejected)
    cases += 12

    pending_actions = {edge.action_id for edge in model.next_states(first_attack)}
    assert "EXT-023-OWNER-FAILURE" in pending_actions
    assert "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH" in pending_actions
    failed_with_pending = model.apply_trace(
        first_attack,
        ("EXT-023-OWNER-FAILURE",),
    )
    assert failed_with_pending.pending_attack == "GRANT_REPLAY"
    assert failed_with_pending.owner_failure_notice is not None
    failed_pending_actions = {
        edge.action_id for edge in model.next_states(failed_with_pending)
    }
    assert "STORE-029-REJECT-HOSTILE-REQUEST" in failed_pending_actions
    assert "GRD-023B-FENCE-AFTER-OWNER-FAILURE" in failed_pending_actions
    rejected_after_failure = model.apply_trace(
        failed_with_pending,
        ("STORE-029-REJECT-HOSTILE-REQUEST",),
    )
    assert rejected_after_failure.owner_state == "FAILED"
    assert rejected_after_failure.store_attack_rejections == ("GRANT_REPLAY",)
    assert model.orchestrator_wf(rejected_after_failure)
    cases += 9

    post_owner = model.apply_trace(
        prepared,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
        ),
    )
    assert post_owner.publication_commitment is not None
    post_owner_attack = model.apply_trace(
        post_owner,
        ("ADV-020A-DELAYED-POST-OWNER-PUBLISH",),
    )
    assert post_owner_attack.pending_attack == "POST_OWNER_PUBLISH"
    post_owner_outgoing = {
        edge.action_id: edge.state for edge in model.next_states(post_owner_attack)
    }
    assert "STORE-029-REJECT-HOSTILE-REQUEST" in post_owner_outgoing
    assert "ADV-029B-SUCCEED-STORE-BYPASS" in post_owner_outgoing
    post_owner_breach = post_owner_outgoing["ADV-029B-SUCCEED-STORE-BYPASS"]
    assert post_owner_breach.assurance_breach == "POST_OWNER_FAILURE_PUBLICATION"
    assert model.orchestrator_wf(post_owner_breach)
    cases += 8

    third_attack = model.apply_trace(
        second_rejected,
        ("ADV-027-REPLAY-GRANT",),
    )
    third_rejected = model.apply_trace(
        third_attack,
        ("STORE-029-REJECT-HOSTILE-REQUEST",),
    )
    assert len(third_rejected.attempted_attack_contexts) == 3
    assert len(set(third_rejected.attempted_attack_contexts)) == 3
    post_owner_after_three = model.apply_trace(
        third_rejected,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
        ),
    )
    assert "ADV-020A-DELAYED-POST-OWNER-PUBLISH" in {
        edge.action_id for edge in model.next_states(post_owner_after_three)
    }
    fourth_attack = model.apply_trace(
        post_owner_after_three,
        ("ADV-020A-DELAYED-POST-OWNER-PUBLISH",),
    )
    assert len(fourth_attack.attempted_attack_contexts) == 4
    assert len(set(fourth_attack.attempted_attack_contexts)) == 4
    cases += 6

    abandonment_prepared = model.apply_trace(
        post_owner,
        ("GRD-025-PREPARE-ABANDONMENT",),
    )
    tombstone_actions = {
        edge.action_id for edge in model.next_states(abandonment_prepared)
    }
    assert "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT" in tombstone_actions
    assert "STORE-026B-TOMBSTONE-HEAD-CONFLICT" in tombstone_actions
    abandonment_conflict = model.apply_trace(
        abandonment_prepared,
        ("STORE-026B-TOMBSTONE-HEAD-CONFLICT",),
    )
    assert abandonment_conflict.phase == "ASSURANCE_BREACHED"
    assert abandonment_conflict.publication == "ASSURANCE_BREACHED"
    assert (
        abandonment_conflict.assurance_breach
        == "ABANDONMENT_HEAD_CONFLICT_UNATTRIBUTED"
    )
    assert abandonment_conflict.abandonment_ack is None
    assert abandonment_conflict.abandonment_conflict_notice is not None
    assert (
        abandonment_conflict.abandonment_conflict_notice.observed_head_kind
        == "UNATTRIBUTED"
    )
    assert model.next_states(abandonment_conflict) == ()
    assert model.orchestrator_wf(abandonment_conflict)
    assert_not_wf(
        "unattributed abandonment conflict relabeled as abandoned",
        replace(
            abandonment_conflict,
            phase="TERMINAL",
            publication="ABANDONED",
            assurance_breach="NONE",
        ),
    )
    assert_not_wf(
        "forged abandonment conflict head identity",
        replace(
            abandonment_conflict,
            abandonment_conflict_notice=replace(
                abandonment_conflict.abandonment_conflict_notice,
                observed_head_digest="forged-head",
            ),
        ),
    )
    cases += 13

    owner_failure_points = (
        delivered,
        consume_requested,
        consumed,
        state_after(HAPPY[:4]),
        producer_running,
        producer_candidate,
        checker_granted,
        checker_running,
        children_complete,
        sealed,
        decided,
        prepared,
        durable,
    )
    for index, state in enumerate(owner_failure_points):
        failed = model.apply_trace(state, ("EXT-023-OWNER-FAILURE",))
        assert failed.owner_state == "FAILED"
        assert failed.primary_state == state.primary_state == "ACTIVE"
        assert failed.controller == state.controller == "PRIMARY_SUPERVISOR"
        assert failed.recovery_receipts == state.recovery_receipts == ()
        assert failed.owner_failure_notice is not None
        assert failed.owner_failure_notice.observed_phase == state.phase
        assert failed.owner_failure_notice.issuer == "EXTERNAL_OWNER"
        assert failed.semantic_verdict is None
        assert "GRD-023B-FENCE-AFTER-OWNER-FAILURE" in {
            edge.action_id for edge in model.next_states(failed)
        }
        terminal = drive_abandonment(failed)
        assert terminal.publication == "ABANDONED", index
        expected_registry = (
            "RETIRED"
            if state.grant_registry_state in {"ISSUED", "PENDING"}
            else "CONSUMED"
        )
        assert terminal.grant_registry_state == expected_registry
        assert terminal.grant_consumption_ack is not None
        assert terminal.grant_consumption_ack.outcome == expected_registry
        assert terminal.abandonment_commitment is not None
        assert terminal.abandonment_ack is not None
        assert terminal.abandonment_ack.outcome == "ABANDONED"
        assert terminal.store_head_generation == parent.expected_publication_generation + 1
        assert "STORE-020-PUBLISH-CAS" not in {
            edge.action_id for edge in model.next_states(terminal)
        }
        assert model.orchestrator_wf(terminal)
        assert_not_wf(
            "failed owner without authenticated failure notice",
            replace(failed, owner_failure_notice=None),
        )
        cases += 22

    failed_delivered = model.apply_trace(
        delivered,
        ("EXT-023-OWNER-FAILURE",),
    )
    substituted_notice = replace(
        failed_delivered.owner_failure_notice,
        observed_phase="PARENT_ACTIVE",
        auth_tag="",
    )
    substituted_notice = replace(
        substituted_notice,
        auth_tag=model._owner_failure_auth(substituted_notice),
    )
    owner_receipt = failed_delivered.parent_receipts[-1]
    substituted_payload = model._owner_failure_digest(substituted_notice)
    substituted_receipt = coherent_parent_receipt_mutation(
        owner_receipt,
        payload=substituted_payload,
        payload_digest=model.child.digest(
            "PARENT_RECEIPT_PAYLOAD",
            owner_receipt.kind,
            substituted_payload,
        ),
    )
    assert_not_wf(
        "coherently resigned owner failure phase substitution",
        replace(
            failed_delivered,
            owner_failure_notice=substituted_notice,
            parent_receipts=(substituted_receipt,),
        ),
    )
    cases += 1

    failover_points = (
        delivered,
        consume_requested,
        consumed,
        producer_running,
        checker_running,
        sealed,
        decided,
        prepared,
        durable,
    )
    for state in failover_points:
        takeover = model.apply_trace(
            state,
            ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
        )
        assert takeover.primary_state == "FAILED"
        assert takeover.controller == "RECOVERY_GUARDIAN"
        assert takeover.semantic_verdict is None
        assert model.orchestrator_wf(takeover)
        cases += 4

    prepared_takeover = model.apply_trace(
        prepared,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    assert prepared_takeover.phase == "PUBLICATION_FENCED"
    assert prepared_takeover.publication == "FENCED"
    assert prepared_takeover.publication_commitment == prepared.publication_commitment
    assert {
        "STORE-019-DURABLE-ACK",
        "STORE-020-PUBLISH-CAS",
        "STORE-021-HEAD-CONFLICT",
    }.isdisjoint({edge.action_id for edge in model.next_states(prepared_takeover)})
    assert "GRD-018B-REAUTHORIZE-PUBLICATION" in {
        edge.action_id for edge in model.next_states(prepared_takeover)
    }
    assert_not_wf(
        "old generation publication resumed after guardian fence",
        replace(
            prepared_takeover,
            phase="PREPARED",
            publication="PREPARED",
        ),
    )
    prepared_reauthorized = model.apply_trace(
        prepared_takeover,
        ("GRD-018B-REAUTHORIZE-PUBLICATION",),
    )
    assert prepared_reauthorized.publication == "PREPARED"
    assert prepared_reauthorized.publication_commitment.controller_generation == 1
    assert prepared_reauthorized.publication_commitment.issuer == "RECOVERY_GUARDIAN"
    assert (
        prepared_reauthorized.publication_commitment.commitment_digest
        != prepared.publication_commitment.commitment_digest
    )
    assert len(prepared_reauthorized.superseded_publications) == 1
    assert (
        prepared_reauthorized.superseded_publications[0].commitment
        == prepared.publication_commitment
    )
    assert prepared_reauthorized.superseded_publications[0].durable_ack is None
    guardian_durable = model.apply_trace(
        prepared_reauthorized,
        ("STORE-019-DURABLE-ACK",),
    )
    guardian_published = model.apply_trace(
        guardian_durable,
        ("STORE-020-PUBLISH-CAS",),
    )
    assert guardian_published.publication == "PUBLISHED"
    assert guardian_published.publication_ack.commitment_digest == (
        prepared_reauthorized.publication_commitment.commitment_digest
    )

    durable_takeover = model.apply_trace(
        durable,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    assert durable_takeover.phase == "PUBLICATION_FENCED"
    assert durable_takeover.publication == "FENCED"
    assert durable_takeover.durable_ack == durable.durable_ack
    assert "STORE-020-PUBLISH-CAS" not in {
        edge.action_id for edge in model.next_states(durable_takeover)
    }
    durable_reauthorized = model.apply_trace(
        durable_takeover,
        ("GRD-018B-REAUTHORIZE-PUBLICATION",),
    )
    assert durable_reauthorized.durable_ack is None
    assert (
        durable_reauthorized.superseded_publications[0].durable_ack
        == durable.durable_ack
    )
    assert model.orchestrator_wf(durable_reauthorized)
    cases += 25

    takeover = model.apply_trace(
        delivered,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    guardian_consume = next(
        edge
        for edge in model.supervisor_next(takeover)
        if edge.action_id == "SUP-002-CONSUME-PARENT-GRANT"
    )
    expect_reject_id(
        "stale primary cannot act after guardian takeover",
        "F05-ORCH-STALE-CONTROLLER",
        lambda: model._edge(
            guardian_consume.action_id,
            "PRIMARY_SUPERVISOR",
            takeover,
            guardian_consume.state,
        ),
    )
    primary_consume = next(
        edge
        for edge in model.supervisor_next(delivered)
        if edge.action_id == "SUP-002-CONSUME-PARENT-GRANT"
    )
    expect_reject_id(
        "guardian has no ambient authority before takeover",
        "F05-ORCH-STALE-CONTROLLER",
        lambda: model._edge(
            primary_consume.action_id,
            "RECOVERY_GUARDIAN",
            delivered,
            primary_consume.state,
        ),
    )
    expect_reject_id(
        "non-stall action cannot be a no-op",
        "F05-ORCH-ACTION-REQUIRED-EFFECT",
        lambda: model._edge(
            "STORE-019-DURABLE-ACK",
            "DURABLE_STORE",
            prepared,
            prepared,
        ),
    )
    producer_candidate_edge = next(
        edge
        for edge in model.child_next(producer_running)
        if edge.action_id == "CHILD-005-ATTACH-PRODUCER-CANDIDATE"
    )
    expect_reject_id(
        "child outcome cannot be relabeled as candidate B",
        "F05-ORCH-ACTION-POSTCONDITION",
        lambda: model._edge(
            "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B",
            "CHILD_ENVELOPE",
            producer_running,
            producer_candidate_edge.state,
        ),
    )
    expect_reject_id(
        "stall action cannot smuggle a disposition capsule",
        "F05-ORCH-ACTION-EFFECT",
        lambda: model._edge(
            "ADV-030-STALL",
            "ADVERSARY",
            delivered,
            replace(
                delivered,
                local_disposition=decided.local_disposition,
                local_capsule=decided.local_capsule,
            ),
        ),
    )
    guardian_breached = model.apply_trace(
        takeover,
        ("ADV-031-FAIL-GUARDIAN",),
    )
    assert guardian_breached.primary_state == "FAILED"
    assert guardian_breached.guardian_state == "FAILED"
    assert guardian_breached.controller == "RECOVERY_GUARDIAN"
    assert guardian_breached.phase == "ASSURANCE_BREACHED"
    assert guardian_breached.publication == "ASSURANCE_BREACHED"
    assert guardian_breached.assurance_breach == "GUARDIAN_FAILURE"
    assert guardian_breached.semantic_verdict is None
    assert model.next_states(guardian_breached) == ()
    assert model.orchestrator_wf(guardian_breached)
    assert_not_wf(
        "failed parent primary without guardian recovery",
        replace(takeover, recovery_receipts=()),
    )
    recovery = takeover.recovery_receipts[0]
    foreign_recovery = replace(
        recovery,
        parent_run_id="foreign-parent-run",
        parent_prefix_hash="foreign-prefix-root",
        auth_tag="",
    )
    foreign_recovery = replace(
        foreign_recovery,
        auth_tag=model._recovery_auth(foreign_recovery),
    )
    assert_not_wf(
        "resigned foreign parent recovery",
        replace(takeover, recovery_receipts=(foreign_recovery,)),
    )
    expect_reject(
        "external owner cannot mint guardian recovery",
        lambda: model._edge(
            "EXT-023-OWNER-FAILURE",
            "EXTERNAL_OWNER",
            delivered,
            takeover,
        ),
    )
    cases += 17

    declared_actions = set(model.ACTION_IDS)
    assert len(model.ACTION_IDS) == len(declared_actions)
    assert declared_actions == set(model.ACTION_SPECS)
    assert all(spec.actors for spec in model.ACTION_SPECS.values())
    assert {
        spec.relation for spec in model.ACTION_SPECS.values()
    } == {
        "ExternalNext",
        "SupervisorNext",
        "ChildNext",
        "GuardianNext",
        "StoreNext",
        "AdversaryNext",
    }
    assert published.semantic_verdict is None
    assert abandonment_conflict.semantic_verdict is None
    assert guardian_breached.semantic_verdict is None
    cases += 7

    print(f"PASS supervisor orchestrator v3 hostile cases={cases}")


if __name__ == "__main__":
    main()
