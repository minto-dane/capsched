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
        outgoing = model.next_states(attacked)
        assert {edge.action_id for edge in outgoing} == {
            "STORE-029-REJECT-HOSTILE-REQUEST",
            "ADV-029B-SUCCEED-STORE-BYPASS",
        }
        rejected = next(
            edge.state
            for edge in outgoing
            if edge.action_id == "STORE-029-REJECT-HOSTILE-REQUEST"
        )
        assert rejected.rejected_attack == expected
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
        assert breached.semantic_verdict is None
        assert model.next_states(breached) == ()
        assert model.orchestrator_wf(breached)
        cases += 17

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
        cases += 18

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

    takeover = model.apply_trace(
        delivered,
        ("GRD-022-TAKEOVER-AFTER-PRIMARY-CRASH",),
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
    cases += 12

    result = model.explore()
    assert result["nonterminal_deadlock_count"] == 0
    assert result["states_without_terminal_path"] == 0
    assert result["missing_actions"] == []
    assert result["undeclared_actions"] == []
    assert result["semantic_verdict_always_absent"] is True
    assert result["published_artifact_type"] == "LOCAL_DISPOSITION_CAPSULE"
    assert result["issuance_registry_refinement_proved"] is False
    assert result["global_nonce_uniqueness_proved"] is False
    assert result["symbolic_authentication_discharged"] is False
    assert result["exact_state_identity_explored"] is True
    assert result["child_terminal_trace_replay_checked"] is True
    assert result["durable_abandonment_ack_required"] is True
    assert result["coaccessibility_only"] is True
    assert result["universal_termination_proved"] is False
    assert result["infinite_stutter_counterexample_present"] is True
    assert result["assurance_breach_explicit"] is True
    assert result["assurance_breach_terminal_count"] > 0
    assert result["guardian_survivability_proved"] is False
    cases += 18

    print(f"PASS supervisor orchestrator v3 hostile cases={cases}")


if __name__ == "__main__":
    main()
