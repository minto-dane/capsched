#!/usr/bin/env python3
"""Hostile regression for actor-separated supervisor orchestration v3."""

from __future__ import annotations

from dataclasses import replace

if not __debug__:
    raise RuntimeError("optimized Python disables security assertions")

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


def rebind_parent_receipt_payloads(
    state: model.OrchestratorState,
    payloads: dict[str, str],
) -> model.OrchestratorState:
    receipts: list[model.ParentReceipt] = []
    for receipt in state.parent_receipts:
        payload = payloads.get(receipt.kind)
        if payload is None:
            receipts.append(receipt)
            continue
        receipts.append(
            coherent_parent_receipt_mutation(
                receipt,
                payload=payload,
                payload_digest=model.child.digest(
                    "PARENT_RECEIPT_PAYLOAD",
                    receipt.kind,
                    payload,
                ),
            )
        )
    return rechain_open_parent_receipts(state, tuple(receipts))


def coherent_attack_context_mutation(
    state: model.OrchestratorState,
    **changes: object,
) -> model.OrchestratorState:
    original = state.pending_attack_context
    assert original is not None and state.parent_grant is not None
    mutated = replace(original, **changes, context_digest="")
    mutated = replace(
        mutated,
        context_digest=model._store_attack_context_digest(mutated),
    )
    previous = model._store_security_genesis(state.parent_grant)
    rebuilt_events: list[model.StoreSecurityEvent] = []
    for sequence, event in enumerate(state.store_security_events, start=1):
        if event.context_digest == original.context_digest:
            event = replace(
                event,
                context=mutated,
                context_digest=mutated.context_digest,
            )
        event = replace(
            event,
            sequence=sequence,
            previous_hash=previous,
            auth_tag="",
        )
        event = replace(event, auth_tag=model._store_security_auth(event))
        rebuilt_events.append(event)
        previous = model.store_security_hash(event)
    rebuilt_keys = tuple(
        model.StoreAttackKey(key.attack, mutated.context_digest)
        if key.context_digest == original.context_digest
        else key
        for key in state.attempted_attack_contexts
    )
    return replace(
        state,
        pending_attack_context=mutated,
        attempted_attack_contexts=rebuilt_keys,
        store_security_events=tuple(rebuilt_events),
    )


def forge_retirement_before_acceptance(
    retired: model.OrchestratorState,
    role: str,
) -> model.OrchestratorState:
    accepted_kind = f"{role}_GRANT_ACCEPTED"
    retired_kind = f"{role}_GRANT_RETIRED"
    prior = tuple(
        receipt
        for receipt in retired.parent_receipts
        if receipt.kind
        not in {accepted_kind, "OWNER_FAILURE_OBSERVED", retired_kind}
    )
    scratch = replace(
        retired,
        parent_receipts=(),
        owner_failure_notice=None,
        owner_failure_phase="NONE",
        **{f"{role.lower()}_retirement": None},
    )
    for receipt in prior:
        scratch = model._append_parent_receipt(
            scratch,
            receipt.issuer,
            receipt.kind,
            receipt.payload,
        )
    observed_phase = model._parent_phase_at_receipt_count(
        scratch,
        len(scratch.parent_receipts),
    )
    assert observed_phase is not None and scratch.parent_grant is not None
    notice = model.OwnerFailureNotice(
        schema=model.SCHEMA,
        parent_run_id=scratch.parent_grant.parent_run_id,
        binding_digest=model.parent_binding_digest(scratch.parent_grant),
        observed_phase=observed_phase,
        parent_prefix_hash=model._last_parent_hash(scratch),
        issuer="EXTERNAL_OWNER",
        auth_tag="",
    )
    notice = replace(notice, auth_tag=model._owner_failure_auth(notice))
    scratch = replace(
        scratch,
        owner_failure_notice=notice,
        owner_failure_phase=observed_phase,
    )
    scratch = model._append_parent_receipt(
        scratch,
        "EXTERNAL_OWNER",
        "OWNER_FAILURE_OBSERVED",
        model._owner_failure_digest(notice),
    )
    grant = getattr(scratch, f"{role.lower()}_grant")
    assert grant is not None
    retirement = model._make_child_retirement(scratch, grant, role)
    scratch = model._append_parent_receipt(
        scratch,
        "EXTERNAL_OWNER",
        retired_kind,
        retirement.retirement_digest,
    )
    accepted = next(
        receipt for receipt in retired.parent_receipts
        if receipt.kind == accepted_kind
    )
    scratch = model._append_parent_receipt(
        scratch,
        accepted.issuer,
        accepted.kind,
        accepted.payload,
    )
    return replace(
        scratch,
        **{f"{role.lower()}_retirement": retirement},
    )


def drive_abandonment(state: model.OrchestratorState) -> model.OrchestratorState:
    current = state
    for _ in range(12):
        if current.publication == "ABANDONED":
            return current
        actions = {edge.action_id for edge in model.next_states(current)}
        if "GRD-023B-FENCE-AFTER-OWNER-FAILURE" in actions:
            current = model.apply_trace(current, ("GRD-023B-FENCE-AFTER-OWNER-FAILURE",))
        elif "STORE-018A-FENCE-PUBLICATION-CONTROLLER" in actions:
            current = model.apply_trace(
                current,
                ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
            )
        elif "CHILD-024-ATTACH-ACTIVE-ABANDONED" in actions:
            current = model.apply_trace(current, ("CHILD-024-ATTACH-ACTIVE-ABANDONED",))
        elif "EXT-024A-RETIRE-PRODUCER-GRANT" in actions:
            current = model.apply_trace(
                current,
                ("EXT-024A-RETIRE-PRODUCER-GRANT",),
            )
        elif "EXT-024B-RETIRE-CHECKER-GRANT" in actions:
            current = model.apply_trace(
                current,
                ("EXT-024B-RETIRE-CHECKER-GRANT",),
            )
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

    normal_attach_edges = (
        model.child_next(producer_running)
        + model.child_next(checker_running)
    )
    assert len(normal_attach_edges) == 10
    for edge in normal_attach_edges:
        expected_phase = (
            "PRODUCER_ATTACHED"
            if edge.action_id in {
                "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
                "CHILD-005B-ATTACH-PRODUCER-CANDIDATE-B",
            }
            else "CHILDREN_COMPLETE"
        )
        before = (
            producer_running
            if edge.action_id.startswith("CHILD-00")
            else checker_running
        )
        assert edge.state.phase == expected_phase
        assert model.orchestrator_wf(edge.state)
        model.next_states(edge.state)
        for forged_phase in {"PARENT_SEALED", "ABANDONING"}:
            expect_reject_id(
                f"{edge.action_id} rejects forged phase {forged_phase}",
                "F05-ORCH-ACTION-POSTCONDITION",
                lambda edge=edge, before=before, forged_phase=forged_phase: model._edge(
                    edge.action_id,
                    edge.actor,
                    before,
                    replace(edge.state, phase=forged_phase),
                ),
            )
        cases += 5

    for running_state in (producer_running, checker_running):
        failed_running = model.apply_trace(
            running_state,
            (
                "EXT-023-OWNER-FAILURE",
                "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
            ),
        )
        abandoned_edge = next(
            edge
            for edge in model.child_next(failed_running)
            if edge.action_id == "CHILD-024-ATTACH-ACTIVE-ABANDONED"
        )
        assert abandoned_edge.state.phase == "ABANDONING"
        assert model.orchestrator_wf(abandoned_edge.state)
        model.next_states(abandoned_edge.state)
        expect_reject(
            "owner-failure child attachment rejects forged sealed phase",
            lambda abandoned_edge=abandoned_edge, failed_running=failed_running: model._edge(
                abandoned_edge.action_id,
                abandoned_edge.actor,
                failed_running,
                replace(abandoned_edge.state, phase="PARENT_SEALED"),
            ),
        )
        cases += 4

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
    assert published.store_head.generation == parent.expected_publication_generation + 1
    assert published.store_head.content_kind == "LOCAL_PUBLICATION"
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
        replace(
            durable,
            store_head=replace(durable.store_head, generation=99),
        ),
    )
    assert_not_wf(
        "publication and phase disagreement",
        replace(prepared, phase="LOCAL_DECIDED"),
    )
    assert_not_wf(
        "publication generation rollback",
        replace(
            published,
            store_head=model._empty_store_head(
                parent.expected_publication_generation
            ),
        ),
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

    stale_prepared_base = model.apply_trace(
        prepared,
        ("EXT-018C-ADVANCE-STORE-HEAD",),
    )
    stale_durable_base = model.apply_trace(
        durable,
        ("EXT-018C-ADVANCE-STORE-HEAD",),
    )
    stale_prepared = model.apply_trace(
        stale_prepared_base,
        ("STORE-021-HEAD-CONFLICT",),
    )
    stale_durable = model.apply_trace(
        stale_durable_base,
        ("STORE-021-HEAD-CONFLICT",),
    )
    assert stale_prepared.publication == stale_durable.publication == "STALE_REJECTED"
    assert stale_prepared.store_head.content_kind == "FOREIGN"
    assert stale_durable.store_head.content_kind == "FOREIGN"
    cases += 2

    for state, attack_action, expected in (
        (delivered, "ADV-027-REPLAY-GRANT", "GRANT_REPLAY"),
        (prepared, "ADV-028-ROLLBACK-PUBLICATION", "PUBLICATION_ROLLBACK"),
    ):
        attacked = model.apply_trace(state, (attack_action,))
        assert attacked.pending_attack == expected
        assert attacked.pending_attack_context
        assert attacked.store_attack_attempts == (expected,)
        expected_key = model.StoreAttackKey(
            expected,
            attacked.pending_attack_context.context_digest,
        )
        assert attacked.attempted_attack_contexts == (expected_key,)
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
        assert rejected.pending_attack_context is None
        assert rejected.store_attack_attempts == (expected,)
        assert rejected.attempted_attack_contexts == (expected_key,)
        assert rejected.store_attack_rejections == (expected,)
        assert tuple(event.event_kind for event in rejected.store_security_events) == (
            "ATTEMPT",
            "REJECTED",
        )
        assert rejected.store_security_events[-1].issuer == "DURABLE_STORE"
        assert rejected.store_head == state.store_head
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
        assert breached.pending_attack_context is None
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
            attacked.attempted_attack_contexts[0].context_digest
        )
        cases += 33

    rollback_attack = model.apply_trace(
        prepared,
        ("ADV-028-ROLLBACK-PUBLICATION",),
    )
    rollback_context = rollback_attack.pending_attack_context
    assert rollback_context is not None
    transplanted_rollback = replace(
        delivered,
        pending_attack="PUBLICATION_ROLLBACK",
        pending_attack_context=rollback_context,
        store_attack_attempts=("PUBLICATION_ROLLBACK",),
        attempted_attack_contexts=(
            model.StoreAttackKey(
                "PUBLICATION_ROLLBACK",
                rollback_context.context_digest,
            ),
        ),
        store_security_events=rollback_attack.store_security_events,
    )
    assert_not_wf(
        "valid rollback context cannot be transplanted before its parent prefix",
        transplanted_rollback,
    )
    cases += 2

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
            second_rejected.attempted_attack_contexts[0].context_digest,
        ),
        (
            1,
            "REJECTED",
            "GRANT_REPLAY",
            second_rejected.attempted_attack_contexts[0].context_digest,
        ),
        (
            2,
            "ATTEMPT",
            "PUBLICATION_ROLLBACK",
            second_rejected.attempted_attack_contexts[1].context_digest,
        ),
        (
            2,
            "REJECTED",
            "PUBLICATION_ROLLBACK",
            second_rejected.attempted_attack_contexts[1].context_digest,
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
        (
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
            "EXT-018C-ADVANCE-STORE-HEAD",
            "GRD-025-PREPARE-ABANDONMENT",
        ),
    )
    tombstone_actions = {
        edge.action_id for edge in model.next_states(abandonment_prepared)
    }
    assert "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT" not in tombstone_actions
    assert "STORE-026B-TOMBSTONE-HEAD-CONFLICT" in tombstone_actions
    abandonment_conflict = model.apply_trace(
        abandonment_prepared,
        ("STORE-026B-TOMBSTONE-HEAD-CONFLICT",),
    )
    assert abandonment_conflict.phase == "ASSURANCE_BREACHED"
    assert abandonment_conflict.publication == "ASSURANCE_BREACHED"
    assert (
        abandonment_conflict.assurance_breach
        == "ABANDONMENT_HEAD_CONFLICT"
    )
    assert abandonment_conflict.abandonment_ack is None
    assert abandonment_conflict.abandonment_conflict_notice is not None
    assert abandonment_conflict.abandonment_conflict_notice.observed_head == (
        abandonment_conflict.store_head
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
    forged_head = replace(
        abandonment_conflict.store_head,
        content_digest="forged-head",
        auth_tag="",
    )
    forged_head = replace(
        forged_head,
        auth_tag=model._store_head_auth(forged_head),
    )
    forged_notice = replace(
        abandonment_conflict.abandonment_conflict_notice,
        observed_head=forged_head,
        auth_tag="",
    )
    forged_notice = replace(
        forged_notice,
        auth_tag=model._abandonment_conflict_auth(forged_notice),
    )
    assert_not_wf(
        "forged abandonment conflict head identity",
        replace(
            abandonment_conflict,
            abandonment_conflict_notice=forged_notice,
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
        assert terminal.store_head.generation == parent.expected_publication_generation + 1
        assert terminal.store_head.content_kind == "ABANDONMENT_TOMBSTONE"
        assert "STORE-020-PUBLISH-CAS" not in {
            edge.action_id for edge in model.next_states(terminal)
        }
        assert model.orchestrator_wf(terminal)
        assert_not_wf(
            "failed owner without authenticated failure notice",
            replace(failed, owner_failure_notice=None),
        )
        cases += 22

    for role, available, retirement_action in (
        (
            "PRODUCER",
            state_after(HAPPY[:4]),
            "EXT-024A-RETIRE-PRODUCER-GRANT",
        ),
        (
            "CHECKER",
            checker_granted,
            "EXT-024B-RETIRE-CHECKER-GRANT",
        ),
    ):
        retired = model.apply_trace(
            available,
            ("EXT-023-OWNER-FAILURE", retirement_action),
        )
        assert model.orchestrator_wf(retired)
        reordered = forge_retirement_before_acceptance(retired, role)
        kinds = tuple(receipt.kind for receipt in reordered.parent_receipts)
        assert kinds.index(f"{role}_GRANT_RETIRED") < kinds.index(
            f"{role}_GRANT_ACCEPTED"
        )
        assert model.owner_failure_wf(reordered)
        assert model.child_lifecycle_wf(reordered)
        assert not model.parent_evidence_wf(reordered)
        assert_not_wf(
            f"{role.lower()} retirement cannot precede grant acceptance",
            reordered,
        )
        cases += 7

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

    delivered_takeover = model.apply_trace(
        delivered,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    false_phase_recovery = replace(
        delivered_takeover.recovery_receipts[0],
        observed_phase="PARENT_ACTIVE",
        auth_tag="",
    )
    false_phase_recovery = replace(
        false_phase_recovery,
        auth_tag=model._recovery_auth(false_phase_recovery),
    )
    false_phase_takeover = replace(
        delivered_takeover,
        recovery_receipts=(false_phase_recovery,),
    )
    false_phase_takeover = rebind_parent_receipt_payloads(
        false_phase_takeover,
        {"PRIMARY_FAILOVER": "PARENT_ACTIVE"},
    )
    assert_not_wf(
        "immediate parent takeover cannot claim a false observed phase",
        false_phase_takeover,
    )
    expect_reject_id(
        "takeover receipt cannot claim a phase other than its pre-state",
        "F05-ORCH-ACTION-POSTCONDITION",
        lambda: model._edge(
            "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",
            "RECOVERY_GUARDIAN",
            delivered,
            false_phase_takeover,
        ),
    )
    cases += 2

    takeover_after_later_receipt = model.apply_trace(
        delivered_takeover,
        ("SUP-002-CONSUME-PARENT-GRANT",),
    )
    later_false_recovery = replace(
        takeover_after_later_receipt.recovery_receipts[0],
        observed_phase="PARENT_ACTIVE",
        auth_tag="",
    )
    later_false_recovery = replace(
        later_false_recovery,
        auth_tag=model._recovery_auth(later_false_recovery),
    )
    later_false_takeover = replace(
        takeover_after_later_receipt,
        recovery_receipts=(later_false_recovery,),
    )
    later_false_takeover = rebind_parent_receipt_payloads(
        later_false_takeover,
        {"PRIMARY_FAILOVER": "PARENT_ACTIVE"},
    )
    assert_not_wf(
        "later receipts cannot detach takeover from its observed phase",
        later_false_takeover,
    )

    retired_parent_after_failure = model.apply_trace(
        failed_delivered,
        ("STORE-002C-RETIRE-GRANT-NONCE",),
    )
    later_false_notice = replace(
        retired_parent_after_failure.owner_failure_notice,
        observed_phase="PARENT_ACTIVE",
        auth_tag="",
    )
    later_false_notice = replace(
        later_false_notice,
        auth_tag=model._owner_failure_auth(later_false_notice),
    )
    later_false_owner = replace(
        retired_parent_after_failure,
        owner_failure_notice=later_false_notice,
        owner_failure_phase="PARENT_ACTIVE",
    )
    later_false_owner = rebind_parent_receipt_payloads(
        later_false_owner,
        {
            "OWNER_FAILURE_OBSERVED": model._owner_failure_digest(
                later_false_notice
            ),
        },
    )
    assert_not_wf(
        "later receipts cannot detach owner failure from its observed phase",
        later_false_owner,
    )
    cases += 2

    prepared_takeover = model.apply_trace(
        prepared,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    assert prepared_takeover.phase == "PUBLICATION_FENCE_PENDING"
    assert prepared_takeover.publication == "FENCE_PENDING"
    assert prepared_takeover.publication_commitment == prepared.publication_commitment
    assert {
        "STORE-019-DURABLE-ACK",
        "STORE-020-PUBLISH-CAS",
        "STORE-021-HEAD-CONFLICT",
    }.isdisjoint({edge.action_id for edge in model.next_states(prepared_takeover)})
    assert "STORE-019A-ACK-OLD-PRE-FENCE" in {
        edge.action_id for edge in model.next_states(prepared_takeover)
    }
    assert "GRD-018B-REAUTHORIZE-PUBLICATION" not in {
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
    prepared_fenced = model.apply_trace(
        prepared_takeover,
        ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
    )
    assert prepared_fenced.phase == "PUBLICATION_FENCED"
    assert prepared_fenced.publication == "FENCED"
    assert prepared_fenced.publication_commitment is None
    assert prepared_fenced.store_controller_generation == 1
    assert prepared_fenced.store_fence_ack is not None
    false_foreign_observation = replace(
        prepared_fenced.store_fence_ack,
        observed_head=model._foreign_store_head(prepared_takeover),
        auth_tag="",
    )
    false_foreign_observation = replace(
        false_foreign_observation,
        auth_tag=model._store_fence_auth(false_foreign_observation),
    )
    assert_not_wf(
        "nonempty fence observation cannot roll back to an empty current head",
        replace(
            prepared_fenced,
            store_fence_ack=false_foreign_observation,
        ),
    )
    superseded_local_head = model._publication_store_head(
        prepared.publication_commitment
    )
    forged_superseded_head = replace(
        prepared_fenced,
        store_head=superseded_local_head,
    )
    assert prepared_fenced.store_fence_ack.observed_head.content_kind == "EMPTY"
    assert superseded_local_head.controller_generation == 0
    assert not model.store_fence_wf(forged_superseded_head)
    assert_not_wf(
        "empty fence observation cannot admit a superseded local head",
        forged_superseded_head,
    )
    cases += 6
    prepared_reauthorized = model.apply_trace(
        prepared_fenced,
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
    assert durable_takeover.phase == "PUBLICATION_FENCE_PENDING"
    assert durable_takeover.publication == "FENCE_PENDING"
    assert durable_takeover.durable_ack == durable.durable_ack
    assert "STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS" in {
        edge.action_id for edge in model.next_states(durable_takeover)
    }
    durable_old_published = model.apply_trace(
        durable_takeover,
        ("STORE-020B-PUBLISH-OLD-PRE-FENCE-CAS",),
    )
    assert durable_old_published.publication == "PUBLISHED"
    assert durable_old_published.store_controller_generation == 0
    durable_fenced = model.apply_trace(
        durable_takeover,
        ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
    )
    durable_reauthorized = model.apply_trace(
        durable_fenced,
        ("GRD-018B-REAUTHORIZE-PUBLICATION",),
    )
    assert durable_reauthorized.durable_ack is None
    assert (
        durable_reauthorized.superseded_publications[0].durable_ack
        == durable.durable_ack
    )
    assert model.orchestrator_wf(durable_reauthorized)

    for fenced_state, forged_phase in (
        (prepared_fenced, "DURABLE"),
        (durable_fenced, "PREPARED"),
    ):
        forged_recovery = replace(
            fenced_state.recovery_receipts[0],
            observed_phase=forged_phase,
            auth_tag="",
        )
        forged_recovery = replace(
            forged_recovery,
            auth_tag=model._recovery_auth(forged_recovery),
        )
        assert_not_wf(
            f"fenced takeover cannot substitute observed phase {forged_phase}",
            replace(fenced_state, recovery_receipts=(forged_recovery,)),
        )

    owner_prepared_fenced = model.apply_trace(
        prepared,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
        ),
    )
    owner_durable_fenced = model.apply_trace(
        durable,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
        ),
    )
    for failed_state, forged_phase in (
        (owner_prepared_fenced, "DURABLE"),
        (owner_durable_fenced, "PREPARED"),
    ):
        forged_notice = replace(
            failed_state.owner_failure_notice,
            observed_phase=forged_phase,
            auth_tag="",
        )
        forged_notice = replace(
            forged_notice,
            auth_tag=model._owner_failure_auth(forged_notice),
        )
        assert_not_wf(
            f"fenced owner failure cannot substitute observed phase {forged_phase}",
            replace(
                failed_state,
                owner_failure_notice=forged_notice,
                owner_failure_phase=forged_phase,
            ),
        )
    cases += 31

    future_head = replace(
        delivered.store_head,
        generation=parent.expected_publication_generation + 1,
        content_kind="FOREIGN",
        content_digest="future-controller-head",
        controller_generation=1,
        issuer="CONCURRENT_STORE_WRITER",
        auth_tag="",
    )
    future_head = replace(
        future_head,
        auth_tag=model._store_head_auth(future_head),
    )
    assert_not_wf(
        "store head cannot come from a future controller generation",
        replace(delivered, store_head=future_head),
    )

    forged_publish_after = replace(
        stale_durable_base,
        phase="TERMINAL",
        publication="PUBLISHED",
        publication_ack=published.publication_ack,
        store_head=published.store_head,
    )
    expect_reject_id(
        "publication CAS cannot overwrite an existing foreign head",
        "F05-ORCH-ACTION-POSTCONDITION",
        lambda: model._edge(
            "STORE-020-PUBLISH-CAS",
            "DURABLE_STORE",
            stale_durable_base,
            forged_publish_after,
        ),
    )

    empty_abandonment_prepared = model.apply_trace(
        post_owner,
        (
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
            "GRD-025-PREPARE-ABANDONMENT",
        ),
    )
    empty_tombstone_actions = {
        edge.action_id for edge in model.next_states(empty_abandonment_prepared)
    }
    assert "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT" in (
        empty_tombstone_actions
    )
    assert "STORE-026B-TOMBSTONE-HEAD-CONFLICT" not in (
        empty_tombstone_actions
    )
    empty_abandoned = model.apply_trace(
        empty_abandonment_prepared,
        ("STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",),
    )
    expect_reject_id(
        "tombstone CAS cannot overwrite an existing foreign head",
        "F05-ORCH-ACTION-POSTCONDITION",
        lambda: model._edge(
            "STORE-026-TOMBSTONE-DURABLE-ABANDONMENT",
            "DURABLE_STORE",
            abandonment_prepared,
            empty_abandoned,
        ),
    )
    cases += 6

    delayed_old_ack = model.apply_trace(
        prepared_takeover,
        ("STORE-019A-ACK-OLD-PRE-FENCE",),
    )
    exact_fence = model.apply_trace(
        delayed_old_ack,
        ("STORE-018A-FENCE-PUBLICATION-CONTROLLER",),
    )
    archived = exact_fence.superseded_publications[0]
    stripped_archive = replace(
        archived,
        durable_ack=None,
        supersession_digest="",
        auth_tag="",
    )
    stripped_archive = replace(
        stripped_archive,
        supersession_digest=model._supersession_digest(stripped_archive),
    )
    stripped_archive = replace(
        stripped_archive,
        auth_tag=model._supersession_auth(stripped_archive),
    )
    rewritten_fence_ack = replace(
        exact_fence.store_fence_ack,
        supersession_digest=stripped_archive.supersession_digest,
        auth_tag="",
    )
    rewritten_fence_ack = replace(
        rewritten_fence_ack,
        auth_tag=model._store_fence_auth(rewritten_fence_ack),
    )
    stripped_after = replace(
        exact_fence,
        superseded_publications=(stripped_archive,),
        store_fence_ack=rewritten_fence_ack,
    )
    expect_reject_id(
        "store fence archive cannot erase a delayed durable ack",
        "F05-ORCH-ACTION-POSTCONDITION",
        lambda: model._edge(
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
            "DURABLE_STORE",
            delayed_old_ack,
            stripped_after,
        ),
    )
    unbound_fence_ack = replace(
        exact_fence.store_fence_ack,
        supersession_digest="forged-supersession",
        auth_tag="",
    )
    unbound_fence_ack = replace(
        unbound_fence_ack,
        auth_tag=model._store_fence_auth(unbound_fence_ack),
    )
    assert_not_wf(
        "store fence ack must bind the exact archived supersession",
        replace(exact_fence, store_fence_ack=unbound_fence_ack),
    )
    cases += 4

    grant_available = state_after(HAPPY[:4])
    primary_started_then_failed = model.apply_trace(
        grant_available,
        (
            "SUP-004-START-PRODUCER",
            "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",
            "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
        ),
    )
    guardian_started = model.apply_trace(
        grant_available,
        (
            "GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",
            "SUP-004-START-PRODUCER",
            "CHILD-005-ATTACH-PRODUCER-CANDIDATE",
        ),
    )
    assert (
        primary_started_then_failed.producer_certificate
        == guardian_started.producer_certificate
    )
    assert (
        primary_started_then_failed.producer_start_binding.start_digest
        != guardian_started.producer_start_binding.start_digest
    )
    assert (
        primary_started_then_failed.producer_attachment.attachment_digest
        != guardian_started.producer_attachment.attachment_digest
    )
    mutated_start = replace(
        primary_started_then_failed.producer_start_binding,
        controller_generation=1,
        issuer="RECOVERY_GUARDIAN",
        start_digest="",
        auth_tag="",
    )
    mutated_start = replace(
        mutated_start,
        start_digest=model._child_start_digest(mutated_start),
    )
    mutated_start = replace(
        mutated_start,
        auth_tag=model._child_start_auth(mutated_start),
    )
    assert_not_wf(
        "attachment remains bound to the original child start generation",
        replace(
            primary_started_then_failed,
            producer_start_binding=mutated_start,
        ),
    )
    stale_guardian_start = replace(
        guardian_started.producer_start_binding,
        controller_generation=0,
        issuer="PRIMARY_SUPERVISOR",
        start_digest="",
        auth_tag="",
    )
    stale_guardian_start = replace(
        stale_guardian_start,
        start_digest=model._child_start_digest(stale_guardian_start),
    )
    stale_guardian_start = replace(
        stale_guardian_start,
        auth_tag=model._child_start_auth(stale_guardian_start),
    )
    rebound_attachment = replace(
        guardian_started.producer_attachment,
        start_binding_digest=stale_guardian_start.start_digest,
        attachment_digest="",
        auth_tag="",
    )
    rebound_attachment = replace(
        rebound_attachment,
        attachment_digest=model._child_attachment_digest(
            rebound_attachment
        ),
    )
    rebound_attachment = replace(
        rebound_attachment,
        auth_tag=model._child_attachment_auth(rebound_attachment),
    )
    stale_guardian_start_state = replace(
        guardian_started,
        producer_start_binding=stale_guardian_start,
        producer_attachment=rebound_attachment,
    )
    stale_guardian_start_state = rebind_parent_receipt_payloads(
        stale_guardian_start_state,
        {
            "PRODUCER_STARTED": stale_guardian_start.start_digest,
            "PRODUCER_CERT_ATTACHED": rebound_attachment.attachment_digest,
        },
    )
    assert_not_wf(
        "guardian-created start cannot be coherently relabeled generation zero",
        stale_guardian_start_state,
    )

    stale_guardian_attachment = replace(
        guardian_started.producer_attachment,
        parent_controller_generation=0,
        attachment_digest="",
        auth_tag="",
    )
    stale_guardian_attachment = replace(
        stale_guardian_attachment,
        attachment_digest=model._child_attachment_digest(
            stale_guardian_attachment
        ),
    )
    stale_guardian_attachment = replace(
        stale_guardian_attachment,
        auth_tag=model._child_attachment_auth(stale_guardian_attachment),
    )
    stale_guardian_attachment_state = replace(
        guardian_started,
        producer_attachment=stale_guardian_attachment,
    )
    stale_guardian_attachment_state = rebind_parent_receipt_payloads(
        stale_guardian_attachment_state,
        {
            "PRODUCER_CERT_ATTACHED": (
                stale_guardian_attachment.attachment_digest
            ),
        },
    )
    assert_not_wf(
        "post-takeover attachment cannot precede its start generation",
        stale_guardian_attachment_state,
    )
    cases += 11

    unretired = model.apply_trace(
        grant_available,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
        ),
    )
    assert unretired.producer_status == "GRANT_AVAILABLE"
    assert "GRD-025-PREPARE-ABANDONMENT" not in {
        edge.action_id for edge in model.next_states(unretired)
    }
    assert "EXT-024A-RETIRE-PRODUCER-GRANT" in {
        edge.action_id for edge in model.next_states(unretired)
    }
    retired_after_fence = model.apply_trace(
        unretired,
        ("EXT-024A-RETIRE-PRODUCER-GRANT",),
    )
    stale_retirement = replace(
        retired_after_fence.producer_retirement,
        controller_generation=0,
        retirement_digest="",
        auth_tag="",
    )
    stale_retirement = replace(
        stale_retirement,
        retirement_digest=model._child_retirement_digest(
            stale_retirement
        ),
    )
    stale_retirement = replace(
        stale_retirement,
        auth_tag=model._child_retirement_auth(stale_retirement),
    )
    stale_retirement_state = replace(
        retired_after_fence,
        producer_retirement=stale_retirement,
    )
    stale_retirement_state = rebind_parent_receipt_payloads(
        stale_retirement_state,
        {"PRODUCER_GRANT_RETIRED": stale_retirement.retirement_digest},
    )
    assert_not_wf(
        "post-fence retirement cannot be coherently relabeled generation zero",
        stale_retirement_state,
    )
    running_failed = model.apply_trace(
        producer_running,
        (
            "EXT-023-OWNER-FAILURE",
            "GRD-023B-FENCE-AFTER-OWNER-FAILURE",
            "STORE-018A-FENCE-PUBLICATION-CONTROLLER",
        ),
    )
    assert "EXT-024A-RETIRE-PRODUCER-GRANT" not in {
        edge.action_id for edge in model.next_states(running_failed)
    }
    assert "CHILD-024-ATTACH-ACTIVE-ABANDONED" in {
        edge.action_id for edge in model.next_states(running_failed)
    }
    cases += 10

    superseded_attempt = model.apply_trace(
        prepared_fenced,
        ("ADV-020C-ATTEMPT-SUPERSEDED-PUBLICATION",),
    )
    assert superseded_attempt.pending_attack == "SUPERSEDED_PUBLICATION"
    assert superseded_attempt.pending_attack_context.attack == (
        "SUPERSEDED_PUBLICATION"
    )
    assert superseded_attempt.pending_attack_context.supersession_digest
    superseded_rejected = model.apply_trace(
        superseded_attempt,
        ("STORE-029-REJECT-HOSTILE-REQUEST",),
    )
    assert superseded_rejected.pending_attack_context is None
    assert_not_wf(
        "superseded publication breach requires an unmatched typed attempt",
        replace(
            prepared_fenced,
            phase="ASSURANCE_BREACHED",
            publication="ASSURANCE_BREACHED",
            assurance_breach="SUPERSEDED_PUBLICATION_ACCEPTED",
        ),
    )

    grant_attempt = model.apply_trace(
        delivered,
        ("ADV-027-REPLAY-GRANT",),
    )
    forged_context_states = (
        coherent_attack_context_mutation(
            grant_attempt,
            phase="PREPARED",
            local_disposition=prepared.local_disposition,
            local_capsule_digest=prepared.local_capsule.capsule_digest,
            publication="PREPARED",
            publication_commitment_digest=(
                prepared.publication_commitment.commitment_digest
            ),
            publication_commitment_controller_generation=0,
        ),
        coherent_attack_context_mutation(
            grant_attempt,
            primary_state="FAILED",
            controller="RECOVERY_GUARDIAN",
            recovery_generation=1,
        ),
        coherent_attack_context_mutation(
            grant_attempt,
            store_head=model._foreign_store_head(delivered),
        ),
        coherent_attack_context_mutation(
            rollback_attack,
            phase="DURABLE",
            publication="DURABLE",
            durable_ack_auth_tag=durable.durable_ack.auth_tag,
        ),
    )
    forged_context_labels = (
        "phase and commitment projection",
        "controller generation projection",
        "store-head projection",
        "durable commitment projection",
    )
    for label, forged_context_state in zip(
        forged_context_labels,
        forged_context_states,
        strict=True,
    ):
        context = forged_context_state.pending_attack_context
        assert context is not None
        assert model._store_attack_context_wf(context)
        assert not model._store_attack_context_history_wf(
            forged_context_state,
            context,
        )
        assert_not_wf(
            f"typed attack context rejects forged historical {label}",
            forged_context_state,
        )
        cases += 4

    original_event = grant_attempt.store_security_events[0]
    substituted_context = replace(
        original_event.context,
        attack="PUBLICATION_ROLLBACK",
        context_digest="",
    )
    substituted_context = replace(
        substituted_context,
        context_digest=model._store_attack_context_digest(
            substituted_context
        ),
    )
    substituted_event = replace(
        original_event,
        attack="PUBLICATION_ROLLBACK",
        context=substituted_context,
        context_digest=substituted_context.context_digest,
        auth_tag="",
    )
    substituted_event = replace(
        substituted_event,
        auth_tag=model._store_security_auth(substituted_event),
    )
    assert_not_wf(
        "coherent cross-class typed context substitution",
        replace(
            grant_attempt,
            pending_attack="PUBLICATION_ROLLBACK",
            pending_attack_context=substituted_context,
            store_attack_attempts=("PUBLICATION_ROLLBACK",),
            attempted_attack_contexts=(
                model.StoreAttackKey(
                    "PUBLICATION_ROLLBACK",
                    substituted_context.context_digest,
                ),
            ),
            store_security_events=(substituted_event,),
        ),
    )
    cases += 10

    guardian_sealed = model.apply_trace(
        model.apply_trace(
            delivered,
            ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
        ),
        HAPPY[1:10],
    )
    guardian_decided = model.apply_trace(
        guardian_sealed,
        ("SUP-017-DECIDE-LOCAL-DISPOSITION",),
    )
    stale_capsule = replace(
        guardian_decided.local_capsule,
        controller_generation=0,
        issuer="PRIMARY_SUPERVISOR",
        capsule_digest="",
        auth_tag="",
    )
    stale_capsule = replace(
        stale_capsule,
        capsule_digest=model._capsule_digest(stale_capsule),
    )
    stale_capsule = replace(
        stale_capsule,
        auth_tag=model._capsule_auth(stale_capsule),
    )
    stale_capsule_after = replace(
        guardian_decided,
        local_capsule=stale_capsule,
    )
    expect_reject_id(
        "new guardian capsule cannot claim the stale primary generation",
        "F05-ORCH-CAPSULE-CREATION-GENERATION",
        lambda: model._edge(
            "SUP-017-DECIDE-LOCAL-DISPOSITION",
            "RECOVERY_GUARDIAN",
            guardian_sealed,
            stale_capsule_after,
        ),
    )
    cases += 2

    retained_primary_capsule = model.apply_trace(
        decided,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
    )
    assert retained_primary_capsule.controller == "RECOVERY_GUARDIAN"
    assert retained_primary_capsule.local_capsule == decided.local_capsule
    assert retained_primary_capsule.local_capsule.controller_generation == 0
    assert retained_primary_capsule.local_capsule.issuer == "PRIMARY_SUPERVISOR"
    assert model.orchestrator_wf(retained_primary_capsule)
    assert_not_wf(
        "active owner cannot enter abandonment preparation",
        replace(
            consumed,
            phase="ABANDONING",
            publication="ABANDONING",
        ),
    )
    assert_not_wf(
        "active owner cannot be relabeled abandoned",
        replace(
            consumed,
            phase="TERMINAL",
            publication="ABANDONED",
        ),
    )
    cases += 7

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
        "ConcurrentStoreNext",
        "AdversaryNext",
    }
    assert published.semantic_verdict is None
    assert abandonment_conflict.semantic_verdict is None
    assert guardian_breached.semantic_verdict is None
    cases += 7

    print(f"LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases={cases}")


if __name__ == "__main__":
    main()
