use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;

use crate::canonical;
use crate::sha256;

const SCHEMA: &str = "F0-SPV3-C4";
pub const EXPECTED_SETUP_STATES: usize = 57;
pub const EXPECTED_SETUP_EDGES: usize = 58;

fn model_encode(parts: &[String]) -> Vec<u8> {
    let mut encoded = Vec::new();
    for (index, value) in parts.iter().enumerate() {
        if index != 0 {
            encoded.push(b'|');
        }
        // Python uses len(text), not encoded-byte length.  Candidate-4 model
        // atoms are currently ASCII; char counting preserves the definition.
        encoded.extend_from_slice(value.chars().count().to_string().as_bytes());
        encoded.push(b':');
        encoded.extend_from_slice(value.as_bytes());
    }
    encoded
}

fn digest(label: &str, parts: &[String]) -> String {
    let mut values = Vec::with_capacity(parts.len() + 2);
    values.push(SCHEMA.to_owned());
    values.push(label.to_owned());
    values.extend_from_slice(parts);
    sha256::hash_hex(&model_encode(&values))
}

#[derive(Clone, Debug)]
pub struct RunGrant {
    parent_run_id: String,
    child_run_id: String,
    role: &'static str,
    ordinal: u64,
    epoch: u64,
    nonce: String,
    validation_context_digest: String,
    policy_digest: String,
    profile_digest: String,
    immutable_input_digest: String,
    hierarchy_id: String,
    scope_id: String,
    subject_id: String,
    budget_id: String,
    budget_limit: u64,
    issuer: &'static str,
    auth_tag: String,
}

impl RunGrant {
    fn payload(&self) -> Vec<String> {
        vec![
            self.parent_run_id.clone(),
            self.child_run_id.clone(),
            self.role.to_owned(),
            self.ordinal.to_string(),
            self.epoch.to_string(),
            self.nonce.clone(),
            self.validation_context_digest.clone(),
            self.policy_digest.clone(),
            self.profile_digest.clone(),
            self.immutable_input_digest.clone(),
            self.hierarchy_id.clone(),
            self.scope_id.clone(),
            self.subject_id.clone(),
            self.budget_id.clone(),
            self.budget_limit.to_string(),
            self.issuer.to_owned(),
        ]
    }

    fn binding_digest(&self) -> String {
        digest("RUN_GRANT_BINDING", &self.payload())
    }

    fn canonical(&self) -> Vec<u8> {
        canonical::tuple(vec![
            canonical::string(&self.parent_run_id),
            canonical::string(&self.child_run_id),
            canonical::string(self.role),
            canonical::integer(self.ordinal),
            canonical::integer(self.epoch),
            canonical::string(&self.nonce),
            canonical::string(&self.validation_context_digest),
            canonical::string(&self.policy_digest),
            canonical::string(&self.profile_digest),
            canonical::string(&self.immutable_input_digest),
            canonical::string(&self.hierarchy_id),
            canonical::string(&self.scope_id),
            canonical::string(&self.subject_id),
            canonical::string(&self.budget_id),
            canonical::integer(self.budget_limit),
            canonical::string(self.issuer),
            canonical::string(&self.auth_tag),
        ])
    }
}

fn derive_child_run_id(parent_run_id: &str, role: &str, ordinal: u64, nonce: &str) -> String {
    let value = digest(
        "CHILD_RUN_ID",
        &[
            parent_run_id.to_owned(),
            role.to_owned(),
            ordinal.to_string(),
            nonce.to_owned(),
        ],
    );
    format!("child-{}", &value[..24])
}

fn fixture_external_grant(role: &'static str) -> RunGrant {
    assert!(
        role == "PRODUCER" || role == "CHECKER",
        "invalid fixture role"
    );
    let parent_run_id = "parent-e1-nonce-a".to_owned();
    let ordinal = if role == "PRODUCER" { 0 } else { 1 };
    let epoch = 1;
    let nonce = format!("nonce-{}-e{epoch}", role.to_ascii_lowercase());
    let child_run_id = derive_child_run_id(&parent_run_id, role, ordinal, &nonce);
    let mut grant = RunGrant {
        parent_run_id,
        child_run_id: child_run_id.clone(),
        role,
        ordinal,
        epoch,
        nonce,
        validation_context_digest: "validation-context-root-a".to_owned(),
        policy_digest: "policy-root-a".to_owned(),
        profile_digest: "profile-root-a".to_owned(),
        immutable_input_digest: "input-root-a".to_owned(),
        hierarchy_id: "hierarchy-owned-a".to_owned(),
        scope_id: format!("scope-{child_run_id}"),
        subject_id: format!("subject-{child_run_id}"),
        budget_id: format!("budget-{child_run_id}"),
        budget_limit: 1,
        issuer: "EXTERNAL_OWNER",
        auth_tag: String::new(),
    };
    grant.auth_tag = digest("ABSTRACT_EXTERNAL_OWNER_AUTH", &grant.payload());
    grant
}

#[derive(Clone, Debug)]
struct Receipt {
    schema: &'static str,
    run_id: String,
    binding_digest: String,
    scope_id: String,
    subject_id: String,
    sequence: u64,
    kind: &'static str,
    payload: String,
    payload_digest: String,
    issuer: &'static str,
    channel: &'static str,
    previous_hash: String,
    auth_tag: String,
}

impl Receipt {
    fn body(&self) -> Vec<String> {
        vec![
            self.schema.to_owned(),
            self.run_id.clone(),
            self.binding_digest.clone(),
            self.scope_id.clone(),
            self.subject_id.clone(),
            self.sequence.to_string(),
            self.kind.to_owned(),
            self.payload.clone(),
            self.payload_digest.clone(),
            self.issuer.to_owned(),
            self.channel.to_owned(),
            self.previous_hash.clone(),
        ]
    }

    fn receipt_hash(&self) -> String {
        let mut body = self.body();
        body.push(self.auth_tag.clone());
        digest("RECEIPT_HASH", &body)
    }

    fn semantic_fact(&self) -> Vec<String> {
        vec![
            self.schema.to_owned(),
            self.run_id.clone(),
            self.binding_digest.clone(),
            self.scope_id.clone(),
            self.subject_id.clone(),
            self.kind.to_owned(),
            self.payload.clone(),
            self.payload_digest.clone(),
            self.issuer.to_owned(),
            self.channel.to_owned(),
        ]
    }
}

#[derive(Clone, Debug, Default)]
struct ReceiptHistory {
    tail: Option<Arc<ReceiptNode>>,
    length: usize,
}

#[derive(Debug)]
struct ReceiptNode {
    receipt: Receipt,
    previous: Option<Arc<ReceiptNode>>,
}

struct ReceiptHistoryIter<'a> {
    next: Option<&'a ReceiptNode>,
}

impl<'a> Iterator for ReceiptHistoryIter<'a> {
    type Item = &'a Receipt;

    fn next(&mut self) -> Option<Self::Item> {
        let node = self.next?;
        self.next = node.previous.as_deref();
        Some(&node.receipt)
    }
}

impl ReceiptHistory {
    fn len(&self) -> usize {
        self.length
    }

    fn last(&self) -> Option<&Receipt> {
        self.tail.as_deref().map(|node| &node.receipt)
    }

    fn push(&mut self, receipt: Receipt) {
        self.tail = Some(Arc::new(ReceiptNode {
            receipt,
            previous: self.tail.clone(),
        }));
        self.length += 1;
    }

    fn iter(&self) -> ReceiptHistoryIter<'_> {
        ReceiptHistoryIter {
            next: self.tail.as_deref(),
        }
    }
}

#[derive(Clone, Debug)]
struct RecoveryReceipt {
    schema: &'static str,
    run_id: String,
    binding_digest: String,
    sequence: u64,
    observed_phase: &'static str,
    evidence_prefix_hash: String,
    reason: &'static str,
    failed_controller: &'static str,
    fence_generation: u64,
    issuer: &'static str,
    auth_tag: String,
}

impl RecoveryReceipt {
    fn body(&self) -> Vec<String> {
        vec![
            self.schema.to_owned(),
            self.run_id.clone(),
            self.binding_digest.clone(),
            self.sequence.to_string(),
            self.observed_phase.to_owned(),
            self.evidence_prefix_hash.clone(),
            self.reason.to_owned(),
            self.failed_controller.to_owned(),
            self.fence_generation.to_string(),
            self.issuer.to_owned(),
        ]
    }

    fn semantic_fact(&self) -> Vec<u8> {
        canonical::tuple(vec![
            canonical::string(self.schema),
            canonical::string(&self.run_id),
            canonical::string(&self.binding_digest),
            canonical::integer(self.sequence),
            canonical::string(self.observed_phase),
            canonical::string(self.reason),
            canonical::string(self.failed_controller),
            canonical::integer(self.fence_generation),
            canonical::string(self.issuer),
        ])
    }
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
struct DecisionReceipt {
    schema: &'static str,
    run_id: String,
    binding_digest: String,
    evidence_root: String,
    decision: &'static str,
    payload_kind: &'static str,
    payload_digest: String,
    issuer: &'static str,
    auth_tag: String,
}

impl DecisionReceipt {
    fn body(&self) -> Vec<String> {
        vec![
            self.schema.to_owned(),
            self.run_id.clone(),
            self.binding_digest.clone(),
            self.evidence_root.clone(),
            self.decision.to_owned(),
            self.payload_kind.to_owned(),
            self.payload_digest.clone(),
            self.issuer.to_owned(),
        ]
    }

    fn semantic_fact(&self) -> Vec<u8> {
        canonical::tuple(vec![
            canonical::string(self.schema),
            canonical::string(&self.run_id),
            canonical::string(&self.binding_digest),
            canonical::string(self.decision),
            canonical::string(self.payload_kind),
            canonical::string(&self.payload_digest),
            canonical::string(self.issuer),
        ])
    }
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
struct State {
    grant: Arc<RunGrant>,
    phase: &'static str,
    owner_state: &'static str,
    primary_state: &'static str,
    controller: &'static str,
    scope: &'static str,
    visible_population: &'static str,
    visible_empty_observations: u64,
    task_population: &'static str,
    attach_authority: &'static str,
    async_admission: &'static str,
    execution_authority: &'static str,
    protection_state: &'static str,
    leader: &'static str,
    descendants: &'static str,
    descendant_generation: u64,
    descendant_drained_generation: u64,
    async_refs: &'static str,
    async_generation: u64,
    async_drained_generation: u64,
    hidden_work: &'static str,
    sandbox: &'static str,
    payload: &'static str,
    writer_confinement: &'static str,
    stream: &'static str,
    candidate_kind: &'static str,
    candidate_value: &'static str,
    candidate_digest: String,
    wait: &'static str,
    resource_event: &'static str,
    resource_observed_value: u64,
    event_clock: u64,
    completion_arrival_sequence: u64,
    quota_arrival_sequence: u64,
    fault_arrival_sequence: u64,
    enforcement: &'static str,
    winner: &'static str,
    winner_sequence: u64,
    counters: &'static str,
    baseline_value: u64,
    final_value: u64,
    fault: &'static str,
    fault_cause: &'static str,
    fault_cause_receipt_sequence: u64,
    pending_attack: &'static str,
    attack_attempts: Vec<&'static str>,
    attack_rejections: Vec<&'static str>,
    breach_kind: &'static str,
    evidence_ledger: &'static str,
    evidence_receipts: ReceiptHistory,
    evidence_root: String,
    local_decision: &'static str,
    decision_receipt: Option<DecisionReceipt>,
    recovery_receipts: Vec<RecoveryReceipt>,
}

impl State {
    fn initial(grant: RunGrant) -> Self {
        Self {
            grant: Arc::new(grant),
            phase: "NEW",
            owner_state: "ACTIVE",
            primary_state: "ACTIVE",
            controller: "PRIMARY_SUPERVISOR",
            scope: "UNCREATED",
            visible_population: "UNKNOWN",
            visible_empty_observations: 0,
            task_population: "UNKNOWN",
            attach_authority: "UNBOUND",
            async_admission: "UNBOUND",
            execution_authority: "UNBOUND",
            protection_state: "OPEN",
            leader: "ABSENT",
            descendants: "NONE",
            descendant_generation: 0,
            descendant_drained_generation: 0,
            async_refs: "NONE",
            async_generation: 0,
            async_drained_generation: 0,
            hidden_work: "NONE",
            sandbox: "UNVERIFIED",
            payload: "HELD",
            writer_confinement: "UNVERIFIED",
            stream: "UNOPENED",
            candidate_kind: "NONE",
            candidate_value: "NONE",
            candidate_digest: String::new(),
            wait: "NONE",
            resource_event: "NONE",
            resource_observed_value: 0,
            event_clock: 0,
            completion_arrival_sequence: 0,
            quota_arrival_sequence: 0,
            fault_arrival_sequence: 0,
            enforcement: "NONE",
            winner: "OPEN",
            winner_sequence: 0,
            counters: "NONE",
            baseline_value: 0,
            final_value: 0,
            fault: "CLEAN",
            fault_cause: "NONE",
            fault_cause_receipt_sequence: 0,
            pending_attack: "NONE",
            attack_attempts: Vec::new(),
            attack_rejections: Vec::new(),
            breach_kind: "NONE",
            evidence_ledger: "OPEN",
            evidence_receipts: ReceiptHistory::default(),
            evidence_root: String::new(),
            local_decision: "NONE",
            decision_receipt: None,
            recovery_receipts: Vec::new(),
        }
    }

    fn genesis_hash(&self) -> String {
        digest(
            "EVIDENCE_GENESIS",
            &[self.grant.binding_digest(), self.grant.child_run_id.clone()],
        )
    }

    fn last_evidence_hash(&self) -> String {
        self.evidence_receipts
            .last()
            .map(Receipt::receipt_hash)
            .unwrap_or_else(|| self.genesis_hash())
    }

    fn append_receipt(&mut self, issuer: &'static str, kind: &'static str, payload: String) {
        assert_eq!(self.evidence_ledger, "OPEN", "receipt after evidence seal");
        let channel = receipt_channel(kind);
        let binding_digest = self.grant.binding_digest();
        let mut receipt = Receipt {
            schema: SCHEMA,
            run_id: self.grant.child_run_id.clone(),
            binding_digest,
            scope_id: self.grant.scope_id.clone(),
            subject_id: self.grant.subject_id.clone(),
            sequence: self.evidence_receipts.len() as u64 + 1,
            kind,
            payload: payload.clone(),
            payload_digest: digest("RECEIPT_PAYLOAD", &[kind.to_owned(), payload]),
            issuer,
            channel,
            previous_hash: self.last_evidence_hash(),
            auth_tag: String::new(),
        };
        receipt.auth_tag = digest("ABSTRACT_ISSUER_AUTH", &receipt.body());
        self.evidence_receipts.push(receipt);
    }

    fn append_recovery_receipt(&mut self) {
        let mut receipt = RecoveryReceipt {
            schema: SCHEMA,
            run_id: self.grant.child_run_id.clone(),
            binding_digest: self.grant.binding_digest(),
            sequence: self.recovery_receipts.len() as u64 + 1,
            observed_phase: self.phase,
            evidence_prefix_hash: self.last_evidence_hash(),
            reason: "PRIMARY_CRASH",
            failed_controller: "PRIMARY_SUPERVISOR",
            fence_generation: 1,
            issuer: "RECOVERY_GUARDIAN",
            auth_tag: String::new(),
        };
        receipt.auth_tag = digest("ABSTRACT_RECOVERY_AUTH", &receipt.body());
        self.recovery_receipts.push(receipt);
    }

    fn behavioral_bytes(&self) -> Vec<u8> {
        // EnvelopeState declaration order, excluding exactly the six fields in
        // BEHAVIORAL_PROJECTION_ERASED_STATE_FIELDS.
        let operational = canonical::tuple(vec![
            self.grant.canonical(),
            canonical::string(self.phase),
            canonical::string(self.owner_state),
            canonical::string(self.primary_state),
            canonical::string(self.controller),
            canonical::string(self.scope),
            canonical::string(self.visible_population),
            canonical::integer(self.visible_empty_observations),
            canonical::string(self.task_population),
            canonical::string(self.attach_authority),
            canonical::string(self.async_admission),
            canonical::string(self.execution_authority),
            canonical::string(self.protection_state),
            canonical::string(self.leader),
            canonical::string(self.descendants),
            canonical::integer(self.descendant_generation),
            canonical::integer(self.descendant_drained_generation),
            canonical::string(self.async_refs),
            canonical::integer(self.async_generation),
            canonical::integer(self.async_drained_generation),
            canonical::string(self.hidden_work),
            canonical::string(self.sandbox),
            canonical::string(self.payload),
            canonical::string(self.writer_confinement),
            canonical::string(self.stream),
            canonical::string(self.candidate_kind),
            canonical::string(self.candidate_value),
            canonical::string(&self.candidate_digest),
            canonical::string(self.wait),
            canonical::string(self.resource_event),
            canonical::integer(self.resource_observed_value),
            canonical::integer(self.event_clock),
            canonical::integer(self.completion_arrival_sequence),
            canonical::integer(self.quota_arrival_sequence),
            canonical::integer(self.fault_arrival_sequence),
            canonical::string(self.enforcement),
            canonical::string(self.winner),
            canonical::string(self.counters),
            canonical::integer(self.baseline_value),
            canonical::integer(self.final_value),
            canonical::string(self.fault),
            canonical::string(self.fault_cause),
            canonical::string(self.pending_attack),
            canonical::strings(self.attack_attempts.iter().copied()),
            canonical::strings(self.attack_rejections.iter().copied()),
            canonical::string(self.breach_kind),
            canonical::string(self.evidence_ledger),
            canonical::string(self.local_decision),
        ]);

        let mut receipt_facts: Vec<Vec<String>> = self
            .evidence_receipts
            .iter()
            .map(Receipt::semantic_fact)
            .collect();
        receipt_facts.sort();
        let receipt_semantics = canonical::tuple(
            receipt_facts
                .into_iter()
                .map(|fact| canonical::tuple(fact.iter().map(|value| canonical::string(value)))),
        );
        let decision_semantics = self
            .decision_receipt
            .as_ref()
            .map(DecisionReceipt::semantic_fact)
            .unwrap_or_else(canonical::none);
        let recovery_semantics = canonical::tuple(
            self.recovery_receipts
                .iter()
                .map(RecoveryReceipt::semantic_fact),
        );
        canonical::tuple(vec![
            canonical::string(canonical::WIRE_SCHEMA),
            operational,
            receipt_semantics,
            decision_semantics,
            recovery_semantics,
        ])
    }
}

fn receipt_channel(kind: &str) -> &'static str {
    match kind {
        "SCOPE_REQUESTED"
        | "BOOTSTRAP_REQUESTED"
        | "SANDBOX_REQUESTED"
        | "HOSTILE_PAYLOAD_RELEASED"
        | "ASYNC_ADMISSION_CLOSED"
        | "TERMINATION_REQUESTED"
        | "EVIDENCE_SEAL" => "CONTROL",
        "SCOPE_CONFIGURED_ACK"
        | "CHARGED_BOOTSTRAP_ACK"
        | "SANDBOX_PROFILE_ACK"
        | "ASYNC_REFS_DRAINED"
        | "RMDIR_ATTACH_CLOSED_ACK"
        | "TASK_POPULATION_ZERO_ACK"
        | "HIDDEN_WORK_DRAINED_ACK" => "MANAGEMENT",
        "MONITOR_EXECUTION_ACTIVATED_ACK"
        | "BASELINE_COUNTERS"
        | "MONITOR_QUOTA_ARRIVED"
        | "EXECUTION_REVOKED_ACK"
        | "MONITOR_PROTECTION_CLOSED_ACK"
        | "FINAL_COUNTERS"
        | "FINAL_COUNTERS_FAILED" => "RESOURCE",
        "UNTRUSTED_FRAME_OBSERVED"
        | "STREAM_EOF_VALID"
        | "STREAM_EOF_TRUNCATED"
        | "STREAM_EOF_INVALID" => "STREAM",
        "HOSTILE_ATTEMPT_OBSERVED" | "HOSTILE_ATTEMPT_REJECTED" => "SECURITY",
        "PRIMARY_FAILOVER" => "RECOVERY",
        "OWNER_REVOKED" => "EXTERNAL",
        "QUOTA_LINEARIZED" | "COMPLETION_LINEARIZED" | "FAULT_LINEARIZED" => "ARBITRATION",
        "LINUX_LIMIT_UNATTRIBUTED" => "RESOURCE",
        "WAIT_NORMAL" | "WAIT_SIGNALLED" | "WAIT_ABNORMAL" | "DESCENDANTS_EXITED"
        | "COMPLETION_ARRIVED" | "LEADER_REAPED" | "VISIBLE_EMPTY_ACK" | "CSS_OFFLINE_ACK"
        | "SCOPE_RELEASED_ACK" => "TARGET_LINUX",
        other => panic!("unknown receipt kind: {other}"),
    }
}

#[derive(Clone)]
struct Edge {
    action_id: &'static str,
    actor: &'static str,
    state: State,
}

fn edge(action_id: &'static str, actor: &'static str, state: State) -> Edge {
    Edge {
        action_id,
        actor,
        state,
    }
}

fn fault(state: &mut State, cause: &'static str) {
    if state.fault == "STICKY" {
        state.phase = "STOPPING";
        return;
    }
    let cause_sequence = if cause == "HOSTILE_BYPASS" {
        0
    } else {
        let expected_kind = match cause {
            "PRIMARY_RUNTIME_FAILOVER" => "PRIMARY_FAILOVER",
            "INTERNAL_FRAME" => "UNTRUSTED_FRAME_OBSERVED",
            "STREAM_TRUNCATED" => "STREAM_EOF_TRUNCATED",
            "STREAM_INVALID" => "STREAM_EOF_INVALID",
            "HOSTILE_REJECTION" => "HOSTILE_ATTEMPT_REJECTED",
            "OWNER_REVOCATION" => "OWNER_REVOKED",
            "LINUX_LIMIT" => "LINUX_LIMIT_UNATTRIBUTED",
            "ABNORMAL_EXIT" => "WAIT_ABNORMAL",
            "FINAL_COUNTER_FAILURE" => "FINAL_COUNTERS_FAILED",
            other => panic!("unknown fault cause: {other}"),
        };
        assert_eq!(
            state.evidence_receipts.last().map(|receipt| receipt.kind),
            Some(expected_kind),
            "fault receipt mismatch"
        );
        state.evidence_receipts.len() as u64
    };
    let sequence = state.event_clock + 1;
    state.fault = "STICKY";
    state.fault_cause = cause;
    state.fault_cause_receipt_sequence = cause_sequence;
    state.phase = "STOPPING";
    state.event_clock = sequence;
    state.fault_arrival_sequence = sequence;
}

fn candidate_payload(state: &State, kind: &str, value: &str) -> String {
    [
        kind,
        value,
        state.grant.role,
        state.grant.immutable_input_digest.as_str(),
        state.grant.validation_context_digest.as_str(),
    ]
    .join("|")
}

fn expected_candidate_digest(state: &State, kind: &str, value: &str) -> String {
    digest(
        "LOCAL_CANDIDATE_PAYLOAD",
        &[candidate_payload(state, kind, value)],
    )
}

fn linearize(
    state: &State,
    actor: &'static str,
    winner: &'static str,
    kind: &'static str,
    payload: String,
) -> State {
    assert_eq!(state.winner, "OPEN", "winner already closed");
    let mut updated = state.clone();
    updated.append_receipt(actor, kind, payload);
    updated.winner = winner;
    updated.winner_sequence = updated.evidence_receipts.len() as u64;
    updated.phase = "STOPPING";
    updated
}

fn failover_edge(state: &State, mark_runtime_fault: bool) -> Edge {
    assert_eq!(state.primary_state, "ACTIVE");
    let mut updated = state.clone();
    updated.append_recovery_receipt();
    if state.evidence_ledger == "OPEN" {
        updated.append_receipt(
            "RECOVERY_GUARDIAN",
            "PRIMARY_FAILOVER",
            format!("phase={}", state.phase),
        );
    }
    if mark_runtime_fault {
        fault(&mut updated, "PRIMARY_RUNTIME_FAILOVER");
    }
    updated.primary_state = "FAILED";
    updated.controller = "RECOVERY_GUARDIAN";
    edge(
        "GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",
        "RECOVERY_GUARDIAN",
        updated,
    )
}

fn setup_edges(state: &State, normal: Edge) -> Vec<Edge> {
    let mut edges = vec![normal];
    if state.primary_state == "ACTIVE" {
        edges.push(failover_edge(state, false));
    }
    edges
}

fn next_setup_states(state: &State) -> Vec<Edge> {
    let controller = state.controller;
    match (state.phase, state.execution_authority, state.counters) {
        ("NEW", _, _) => {
            let mut updated = state.clone();
            updated.append_receipt(controller, "SCOPE_REQUESTED", state.grant.scope_id.clone());
            updated.phase = "SCOPE_REQUESTED";
            updated.scope = "REQUESTED";
            setup_edges(state, edge("SUP-001-REQUEST-SCOPE", controller, updated))
        }
        ("SCOPE_REQUESTED", _, _) => {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "SCOPE_CONFIGURED_ACK",
                format!(
                    "{}:{}:exclusive",
                    state.grant.hierarchy_id, state.grant.scope_id
                ),
            );
            updated.phase = "SCOPE_CONFIGURED";
            updated.scope = "CONFIGURED_EMPTY";
            updated.visible_population = "EMPTY";
            updated.task_population = "EMPTY";
            updated.attach_authority = "EXTERNAL_EXCLUSIVE";
            updated.async_admission = "OPEN";
            setup_edges(state, edge("OBS-002-CONFIGURE-SCOPE-ACK", actor, updated))
        }
        ("SCOPE_CONFIGURED", _, _) => {
            let mut updated = state.clone();
            updated.append_receipt(
                controller,
                "BOOTSTRAP_REQUESTED",
                state.grant.scope_id.clone(),
            );
            updated.phase = "BOOTSTRAP_REQUESTED";
            setup_edges(
                state,
                edge("SUP-003-REQUEST-CHARGED-BOOTSTRAP", controller, updated),
            )
        }
        ("BOOTSTRAP_REQUESTED", _, _) => {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "CHARGED_BOOTSTRAP_ACK",
                format!("{}:held-before-hostile-exec", state.grant.scope_id),
            );
            updated.phase = "BOOTSTRAP_HELD";
            updated.scope = "LIVE";
            updated.visible_population = "NONEMPTY";
            updated.task_population = "NONEMPTY";
            updated.leader = "TRUSTED_HELD";
            updated.hidden_work = "ACTIVE";
            updated.stream = "OPEN";
            setup_edges(state, edge("OBS-004-CHARGED-BOOTSTRAP-ACK", actor, updated))
        }
        ("BOOTSTRAP_HELD", "UNBOUND", _) => {
            let actor = "MONITOR_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "MONITOR_EXECUTION_ACTIVATED_ACK",
                format!(
                    "{}:epoch={}:activated-held",
                    state.grant.child_run_id, state.grant.epoch
                ),
            );
            updated.execution_authority = "ACTIVE";
            setup_edges(state, edge("MON-004B-ACTIVATE-EXECUTION", actor, updated))
        }
        ("BOOTSTRAP_HELD", "ACTIVE", _) => {
            let mut updated = state.clone();
            updated.append_receipt(
                controller,
                "SANDBOX_REQUESTED",
                state.grant.profile_digest.clone(),
            );
            updated.phase = "SANDBOX_REQUESTED";
            updated.sandbox = "REQUESTED";
            setup_edges(state, edge("SUP-005-REQUEST-SANDBOX", controller, updated))
        }
        ("SANDBOX_REQUESTED", _, _) => {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "SANDBOX_PROFILE_ACK",
                format!("{}:payload-held:fd-confined", state.grant.profile_digest),
            );
            updated.phase = "READY";
            updated.sandbox = "ATTESTED";
            updated.writer_confinement = "CONFINED";
            setup_edges(state, edge("OBS-006-SANDBOX-PROFILE-ACK", actor, updated))
        }
        ("READY", _, "NONE") => {
            let actor = "MONITOR_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "BASELINE_COUNTERS",
                format!(
                    "{}:epoch={}:value=0",
                    state.grant.budget_id, state.grant.epoch
                ),
            );
            updated.counters = "BASELINE";
            updated.baseline_value = 0;
            setup_edges(state, edge("MON-007-BASELINE-COUNTERS", actor, updated))
        }
        ("READY", _, "BASELINE") => {
            let mut updated = state.clone();
            updated.append_receipt(
                controller,
                "HOSTILE_PAYLOAD_RELEASED",
                format!("{}:{}", state.grant.subject_id, state.grant.profile_digest),
            );
            updated.phase = "RUNNING";
            updated.leader = "HOSTILE_RUNNING";
            updated.payload = "RELEASED";
            setup_edges(
                state,
                edge("SUP-008-RELEASE-HOSTILE-PAYLOAD", controller, updated),
            )
        }
        _ => Vec::new(),
    }
}

fn stream_edges(state: &State) -> Vec<Edge> {
    let actor = "TARGET_LINUX_OBSERVER";
    let mut edges = Vec::new();
    if state.stream == "OPEN" {
        let candidates: &[(&str, &str, &str)] = if state.grant.role == "PRODUCER" {
            &[
                (
                    "OBS-009A-PRODUCER-CANDIDATE-A",
                    "PRODUCER_RESULT",
                    "VALUE_A",
                ),
                (
                    "OBS-009B-PRODUCER-CANDIDATE-B",
                    "PRODUCER_RESULT",
                    "VALUE_B",
                ),
            ]
        } else {
            &[
                ("OBS-010-CHECKER-ACCEPT", "CHECKER_ACCEPT", "ACCEPT"),
                ("OBS-011-CHECKER-REJECT", "CHECKER_REJECT", "REJECT"),
            ]
        };
        for &(action_id, kind, value) in candidates {
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "UNTRUSTED_FRAME_OBSERVED",
                candidate_payload(state, kind, value),
            );
            updated.stream = "FRAME";
            updated.candidate_kind = kind;
            updated.candidate_value = value;
            updated.candidate_digest = expected_candidate_digest(state, kind, value);
            edges.push(edge(action_id, actor, updated));
        }

        let mut internal = state.clone();
        internal.append_receipt(
            actor,
            "UNTRUSTED_FRAME_OBSERVED",
            candidate_payload(state, "INTERNAL", "INTERNAL"),
        );
        internal.stream = "FRAME";
        internal.candidate_kind = "INTERNAL";
        internal.candidate_value = "INTERNAL";
        internal.candidate_digest = expected_candidate_digest(state, "INTERNAL", "INTERNAL");
        fault(&mut internal, "INTERNAL_FRAME");
        edges.push(edge("OBS-012-INTERNAL-FRAME", actor, internal));

        if state.leader == "EXITED" || state.leader == "REAPED" {
            let mut truncated = state.clone();
            truncated.append_receipt(
                actor,
                "STREAM_EOF_TRUNCATED",
                "no-complete-frame".to_owned(),
            );
            truncated.stream = "EOF_TRUNCATED";
            truncated.writer_confinement = "CLOSED";
            fault(&mut truncated, "STREAM_TRUNCATED");
            edges.push(edge("OBS-014-EOF-TRUNCATED", actor, truncated));
        }

        let mut invalid = state.clone();
        invalid.append_receipt(actor, "STREAM_EOF_INVALID", "framing-invalid".to_owned());
        invalid.stream = "EOF_INVALID";
        invalid.writer_confinement = "CLOSED";
        fault(&mut invalid, "STREAM_INVALID");
        edges.push(edge("OBS-015-EOF-INVALID", actor, invalid));
    } else if state.stream == "FRAME" {
        if state.candidate_kind != "INTERNAL" {
            let mut valid = state.clone();
            valid.append_receipt(actor, "STREAM_EOF_VALID", state.candidate_digest.clone());
            valid.stream = "EOF_VALID";
            valid.writer_confinement = "CLOSED";
            edges.push(edge("OBS-013-EOF-VALID", actor, valid));
        }
        let mut invalid = state.clone();
        invalid.append_receipt(
            actor,
            "STREAM_EOF_INVALID",
            "trailing-or-duplicate-frame".to_owned(),
        );
        invalid.stream = "EOF_INVALID";
        invalid.writer_confinement = "CLOSED";
        fault(&mut invalid, "STREAM_INVALID");
        edges.push(edge("OBS-015-EOF-INVALID", actor, invalid));
    }
    edges
}

fn closure_ready(state: &State) -> bool {
    state.scope == "RELEASED"
        && state.visible_population == "EMPTY"
        && state.task_population == "EMPTY"
        && state.attach_authority == "CLOSED"
        && state.async_admission == "CLOSED"
        && state.execution_authority == "REVOKED"
        && state.protection_state == "CLOSED"
        && state.leader == "REAPED"
        && state.descendants != "LIVE"
        && state.async_refs != "LIVE"
        && state.hidden_work == "DRAINED"
        && state.writer_confinement == "CLOSED"
        && matches!(state.stream, "EOF_VALID" | "EOF_TRUNCATED" | "EOF_INVALID")
        && state.wait != "NONE"
        && state.winner != "OPEN"
        && matches!(state.counters, "FINAL" | "FAILED")
        && state.pending_attack == "NONE"
        && state.attack_attempts == state.attack_rejections
}

fn completion_ready(state: &State) -> bool {
    let kind_ok = if state.grant.role == "PRODUCER" {
        state.candidate_kind == "PRODUCER_RESULT"
    } else {
        matches!(state.candidate_kind, "CHECKER_ACCEPT" | "CHECKER_REJECT")
    };
    state.fault == "CLEAN"
        && state.wait == "NORMAL"
        && state.stream == "EOF_VALID"
        && kind_ok
        && matches!(state.scope, "HIDDEN_DRAINED" | "CSS_OFFLINE" | "RELEASED")
        && state.descendants != "LIVE"
        && state.async_refs != "LIVE"
        && state.hidden_work == "DRAINED"
        && state.attach_authority == "CLOSED"
        && state.async_admission == "CLOSED"
        && state.execution_authority == "REVOKED"
        && state.protection_state == "CLOSED"
        && state.visible_population == "EMPTY"
        && state.task_population == "EMPTY"
        && state.counters == "FINAL"
        && state.final_value <= state.grant.budget_limit
}

fn expected_local_decision(state: &State) -> &'static str {
    if state.owner_state == "REVOKED" {
        "ABANDONED"
    } else if state.fault == "STICKY" || state.counters == "FAILED" || state.winner == "FAULT" {
        "INTERNAL_FAILURE"
    } else if state.winner == "QUOTA" && state.resource_event == "MONITOR_PROVED" {
        "INCONCLUSIVE_RESOURCE"
    } else if state.winner == "COMPLETION" && completion_ready(state) {
        "LOCAL_SYNTACTIC_CANDIDATE"
    } else {
        "INTERNAL_FAILURE"
    }
}

fn next_states(state: &State) -> Vec<Edge> {
    if state.phase == "DECIDED" || state.phase == "BREACHED" {
        return Vec::new();
    }
    let mut edges = Vec::new();

    if state.pending_attack != "NONE" {
        let attempt = state.attack_attempts.len();
        let attack_payload = format!("attempt={attempt}:kind={}", state.pending_attack);
        let actor = "MANAGEMENT_DOMAIN_OBSERVER";
        let mut rejected = state.clone();
        rejected.append_receipt(actor, "HOSTILE_ATTEMPT_REJECTED", attack_payload);
        rejected.attack_rejections.push(state.pending_attack);
        rejected.pending_attack = "NONE";
        fault(&mut rejected, "HOSTILE_REJECTION");
        edges.push(edge("OBS-023-REJECT-HOSTILE-ATTEMPT", actor, rejected));

        let mut bypass = state.clone();
        bypass.pending_attack = "NONE";
        bypass.breach_kind = state.pending_attack;
        bypass.protection_state = "BREACHED";
        fault(&mut bypass, "HOSTILE_BYPASS");
        bypass.phase = "BREACHED";
        edges.push(edge("ADV-023B-SUCCEED-HOSTILE-BYPASS", "ADVERSARY", bypass));
    }

    if state.winner == "OPEN" {
        let arrivals = [
            (
                "COMPLETION",
                state.completion_arrival_sequence,
                "ARB-034-COMPLETION-WINS",
                "COMPLETION_LINEARIZED",
            ),
            (
                "QUOTA",
                state.quota_arrival_sequence,
                "ARB-026B-QUOTA-WINS",
                "QUOTA_LINEARIZED",
            ),
            (
                "FAULT",
                state.fault_arrival_sequence,
                "ARB-035-FAULT-WINS",
                "FAULT_LINEARIZED",
            ),
        ];
        let mut selected: Option<(&str, u64, &str, &str)> = None;
        for candidate in arrivals {
            if candidate.1 > 0
                && selected
                    .as_ref()
                    .map(|current| candidate.1 < current.1)
                    .unwrap_or(true)
            {
                selected = Some(candidate);
            }
        }
        if let Some((winner, arrival, action_id, receipt_kind)) = selected {
            let payload = match winner {
                "COMPLETION" => format!(
                    "{}:arrival={}",
                    state.candidate_digest, state.completion_arrival_sequence
                ),
                "QUOTA" | "FAULT" => format!("arrival={arrival}"),
                _ => unreachable!(),
            };
            let updated = linearize(state, "LOCAL_ARBITER", winner, receipt_kind, payload);
            edges.push(edge(action_id, "LOCAL_ARBITER", updated));
        }
    }

    let setup = next_setup_states(state);
    if !setup.is_empty() {
        return setup;
    }

    let controller = state.controller;
    if matches!(state.phase, "RUNNING" | "STOPPING") && state.evidence_ledger == "OPEN" {
        edges.extend(stream_edges(state));

        if state.leader == "HOSTILE_RUNNING" && state.wait == "NONE" {
            let actor = "TARGET_LINUX_OBSERVER";
            let mut normal = state.clone();
            normal.append_receipt(actor, "WAIT_NORMAL", "leader-normal-exit".to_owned());
            normal.leader = "EXITED";
            normal.wait = "NORMAL";
            normal.hidden_work = "PENDING";
            normal.phase = "STOPPING";
            edges.push(edge("OBS-029-NORMAL-EXIT", actor, normal));

            if state.enforcement == "TERMINATION_REQUESTED" {
                let mut signalled = state.clone();
                signalled.append_receipt(
                    actor,
                    "WAIT_SIGNALLED",
                    "controller-termination".to_owned(),
                );
                signalled.leader = "EXITED";
                signalled.wait = "SIGNALLED";
                signalled.hidden_work = "PENDING";
                signalled.phase = "STOPPING";
                edges.push(edge("OBS-030-SIGNAL-EXIT", actor, signalled));
            }

            let mut abnormal = state.clone();
            abnormal.append_receipt(
                actor,
                "WAIT_ABNORMAL",
                "unattributed-abnormal-exit".to_owned(),
            );
            abnormal.leader = "EXITED";
            abnormal.wait = "ABNORMAL";
            abnormal.hidden_work = "PENDING";
            fault(&mut abnormal, "ABNORMAL_EXIT");
            edges.push(edge("OBS-031-ABNORMAL-EXIT", actor, abnormal));
        }

        let completion_kind_ok = if state.grant.role == "PRODUCER" {
            state.candidate_kind == "PRODUCER_RESULT"
        } else {
            matches!(state.candidate_kind, "CHECKER_ACCEPT" | "CHECKER_REJECT")
        };
        if state.winner == "OPEN"
            && state.completion_arrival_sequence == 0
            && state.stream == "EOF_VALID"
            && state.wait == "NORMAL"
            && completion_kind_ok
        {
            let actor = "TARGET_LINUX_OBSERVER";
            let arrival = state.event_clock + 1;
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "COMPLETION_ARRIVED",
                format!("{}:arrival={arrival}", state.candidate_digest),
            );
            updated.event_clock = arrival;
            updated.completion_arrival_sequence = arrival;
            edges.push(edge("OBS-033B-COMPLETION-ARRIVAL", actor, updated));
        }

        if state.execution_authority == "ACTIVE"
            && state.protection_state == "OPEN"
            && state.payload == "RELEASED"
            && state.task_population == "NONEMPTY"
        {
            if state.attach_authority != "CLOSED" && state.descendant_generation < 2 {
                let mut updated = state.clone();
                updated.descendants = "LIVE";
                updated.descendant_generation += 1;
                updated.visible_population = "NONEMPTY";
                updated.task_population = "NONEMPTY";
                edges.push(edge("ADV-016-FORK-DESCENDANT", "ADVERSARY", updated));
            }
            if state.async_admission == "OPEN" && state.async_generation < 2 {
                let mut updated = state.clone();
                updated.async_refs = "LIVE";
                updated.async_generation += 1;
                updated.hidden_work = "ACTIVE";
                edges.push(edge("ADV-017-OPEN-ASYNC-REF", "ADVERSARY", updated));
            }
        }

        let hostile_execution_open = state.leader == "HOSTILE_RUNNING"
            && state.execution_authority == "ACTIVE"
            && state.protection_state == "OPEN";
        if hostile_execution_open {
            if state.pending_attack == "NONE" && state.attack_attempts.len() < 2 {
                for (action_id, attack) in [
                    ("ADV-018-ATTACH-ATTEMPT", "ATTACH"),
                    ("ADV-019-FD-ESCAPE-ATTEMPT", "FD_ESCAPE"),
                    ("ADV-020-PTRACE-ATTEMPT", "PTRACE"),
                    ("ADV-021-FORGED-RECEIPT", "FORGED_RECEIPT"),
                    ("ADV-022-REPLAY-RECEIPT", "REPLAY_RECEIPT"),
                ] {
                    let attempt = state.attack_attempts.len() + 1;
                    let mut updated = state.clone();
                    updated.append_receipt(
                        "ADVERSARY",
                        "HOSTILE_ATTEMPT_OBSERVED",
                        format!("attempt={attempt}:kind={attack}"),
                    );
                    updated.pending_attack = attack;
                    updated.attack_attempts.push(attack);
                    edges.push(edge(action_id, "ADVERSARY", updated));
                }
            }
            edges.push(edge("ADV-047-STALL", "ADVERSARY", state.clone()));
        }

        if state.primary_state == "ACTIVE" {
            edges.push(failover_edge(state, true));
        }

        if state.owner_state == "ACTIVE"
            && matches!(state.phase, "RUNNING" | "STOPPING")
            && state.evidence_ledger == "OPEN"
        {
            let actor = "EXTERNAL_OWNER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "OWNER_REVOKED",
                format!("epoch={}", state.grant.epoch),
            );
            updated.owner_state = "REVOKED";
            fault(&mut updated, "OWNER_REVOCATION");
            edges.push(edge("EXT-025-REVOKE-RUN", actor, updated));
        }

        if state.winner == "OPEN"
            && state.resource_event == "NONE"
            && state.quota_arrival_sequence == 0
            && state.counters == "BASELINE"
        {
            let arrival = state.event_clock + 1;
            let actor = "MONITOR_OBSERVER";
            let observed = state.grant.budget_limit + 1;
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "MONITOR_QUOTA_ARRIVED",
                format!(
                    "{}:epoch={}:value={observed}:arrival={arrival}",
                    state.grant.budget_id, state.grant.epoch
                ),
            );
            updated.resource_event = "MONITOR_PROVED";
            updated.resource_observed_value = observed;
            updated.event_clock = arrival;
            updated.quota_arrival_sequence = arrival;
            edges.push(edge("MON-026-QUOTA-ARRIVAL", actor, updated));

            let actor = "TARGET_LINUX_OBSERVER";
            let mut ambiguous = state.clone();
            ambiguous.append_receipt(
                actor,
                "LINUX_LIMIT_UNATTRIBUTED",
                format!("{}:causality-unproved", state.grant.budget_id),
            );
            ambiguous.resource_event = "LINUX_UNATTRIBUTED";
            fault(&mut ambiguous, "LINUX_LIMIT");
            ambiguous.resource_observed_value = state.grant.budget_limit;
            edges.push(edge("OBS-027-UNATTRIBUTED-LIMIT", actor, ambiguous));
        }

        if matches!(state.winner, "QUOTA" | "FAULT")
            && state.leader == "HOSTILE_RUNNING"
            && state.enforcement == "NONE"
        {
            let mut updated = state.clone();
            updated.append_receipt(
                controller,
                "TERMINATION_REQUESTED",
                format!("winner={}", state.winner),
            );
            updated.enforcement = "TERMINATION_REQUESTED";
            updated.phase = "STOPPING";
            edges.push(edge("SUP-028-REQUEST-TERMINATION", controller, updated));
        }

        if state.descendants == "LIVE" && matches!(state.leader, "EXITED" | "REAPED") {
            let actor = "TARGET_LINUX_OBSERVER";
            let drained = state.descendant_drained_generation + 1;
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "DESCENDANTS_EXITED",
                format!("{}:generation={drained}", state.grant.scope_id),
            );
            updated.descendants = if state.descendant_generation > drained {
                "LIVE"
            } else {
                "EXITED"
            };
            updated.descendant_drained_generation = drained;
            updated.hidden_work = "PENDING";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-032-DESCENDANTS-EXIT", actor, updated));
        }

        if state.leader == "EXITED" {
            let actor = "TARGET_LINUX_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(actor, "LEADER_REAPED", state.grant.subject_id.clone());
            updated.leader = "REAPED";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-036-LEADER-REAPED", actor, updated));
        }

        if state.scope == "LIVE"
            && state.visible_population == "NONEMPTY"
            && matches!(state.leader, "EXITED" | "REAPED")
            && matches!(state.descendants, "NONE" | "EXITED")
        {
            let actor = "TARGET_LINUX_OBSERVER";
            let observation = state.visible_empty_observations + 1;
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "VISIBLE_EMPTY_ACK",
                format!("{}:observation={observation}", state.grant.scope_id),
            );
            updated.visible_population = "EMPTY";
            updated.visible_empty_observations = observation;
            updated.phase = "STOPPING";
            edges.push(edge("OBS-037-VISIBLE-EMPTY", actor, updated));
        }

        if state.scope == "LIVE"
            && state.visible_population == "EMPTY"
            && state.attach_authority == "EXTERNAL_EXCLUSIVE"
        {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "RMDIR_ATTACH_CLOSED_ACK",
                format!("{}:no-future-attach", state.grant.scope_id),
            );
            updated.scope = "ATTACH_CLOSED";
            updated.attach_authority = "CLOSED";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-039-RMDIR-ATTACH-CLOSED", actor, updated));
        }

        if state.scope == "ATTACH_CLOSED" && state.async_admission == "OPEN" {
            let mut updated = state.clone();
            updated.append_receipt(
                controller,
                "ASYNC_ADMISSION_CLOSED",
                format!("{}:no-future-async-acquire", state.grant.scope_id),
            );
            updated.async_admission = "CLOSED";
            updated.phase = "STOPPING";
            edges.push(edge("SUP-039B-CLOSE-ASYNC-ADMISSION", controller, updated));
        }

        if state.execution_authority == "ACTIVE"
            && state.payload == "RELEASED"
            && (state.wait != "NONE"
                || matches!(state.winner, "QUOTA" | "FAULT")
                || state.owner_state == "REVOKED")
        {
            let actor = "MONITOR_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "EXECUTION_REVOKED_ACK",
                format!(
                    "{}:epoch={}:revoked",
                    state.grant.child_run_id, state.grant.epoch
                ),
            );
            updated.execution_authority = "REVOKED";
            updated.protection_state = "EXECUTION_REVOKED";
            updated.phase = "STOPPING";
            edges.push(edge("MON-035B-REVOKE-EXECUTION", actor, updated));
        }

        if state.scope == "ATTACH_CLOSED"
            && state.task_population == "NONEMPTY"
            && state.leader == "REAPED"
            && state.descendants != "LIVE"
        {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "TASK_POPULATION_ZERO_ACK",
                state.grant.scope_id.clone(),
            );
            updated.task_population = "EMPTY";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-038-TASK-POPULATION-ZERO", actor, updated));
        }

        if state.scope == "ATTACH_CLOSED"
            && state.async_admission == "CLOSED"
            && state.async_refs == "LIVE"
        {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let drained = state.async_drained_generation + 1;
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "ASYNC_REFS_DRAINED",
                format!("{}:generation={drained}", state.grant.scope_id),
            );
            updated.async_refs = if state.async_generation > drained {
                "LIVE"
            } else {
                "DRAINED"
            };
            updated.async_drained_generation = drained;
            updated.phase = "STOPPING";
            edges.push(edge("OBS-033-ASYNC-REFS-DRAIN", actor, updated));
        }

        if state.protection_state == "EXECUTION_REVOKED"
            && state.execution_authority == "REVOKED"
            && state.attach_authority == "CLOSED"
            && state.async_admission == "CLOSED"
            && state.pending_attack == "NONE"
            && state.attack_attempts == state.attack_rejections
        {
            let actor = "MONITOR_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "MONITOR_PROTECTION_CLOSED_ACK",
                format!(
                    "{}:epoch={}:admission-and-execution-closed",
                    state.grant.child_run_id, state.grant.epoch
                ),
            );
            updated.protection_state = "CLOSED";
            updated.phase = "STOPPING";
            edges.push(edge("MON-039C-PROTECTION-CLOSED", actor, updated));
        }

        if state.scope == "ATTACH_CLOSED"
            && state.leader == "REAPED"
            && state.descendants != "LIVE"
            && state.async_refs != "LIVE"
            && state.task_population == "EMPTY"
            && state.async_admission == "CLOSED"
            && state.protection_state == "CLOSED"
        {
            let actor = "MANAGEMENT_DOMAIN_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(
                actor,
                "HIDDEN_WORK_DRAINED_ACK",
                state.grant.scope_id.clone(),
            );
            updated.scope = "HIDDEN_DRAINED";
            updated.hidden_work = "DRAINED";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-040-HIDDEN-WORK-DRAINED", actor, updated));
        }

        if state.scope == "HIDDEN_DRAINED" && state.counters == "BASELINE" {
            let actor = "MONITOR_OBSERVER";
            let final_value = state.resource_observed_value.max(1);
            let mut final_state = state.clone();
            final_state.append_receipt(
                actor,
                "FINAL_COUNTERS",
                format!(
                    "{}:epoch={}:value={final_value}",
                    state.grant.budget_id, state.grant.epoch
                ),
            );
            final_state.counters = "FINAL";
            final_state.final_value = final_value;
            final_state.phase = "STOPPING";
            edges.push(edge("MON-041-FINAL-COUNTERS", actor, final_state));

            if state.winner == "OPEN" && state.resource_event == "NONE" {
                let observed = state.grant.budget_limit + 1;
                let arrival = state.event_clock + 1;
                let mut overlimit = state.clone();
                overlimit.append_receipt(
                    actor,
                    "MONITOR_QUOTA_ARRIVED",
                    format!(
                        "{}:epoch={}:value={observed}:arrival={arrival}",
                        state.grant.budget_id, state.grant.epoch
                    ),
                );
                overlimit.resource_event = "MONITOR_PROVED";
                overlimit.resource_observed_value = observed;
                overlimit.event_clock = arrival;
                overlimit.quota_arrival_sequence = arrival;
                overlimit.append_receipt(
                    actor,
                    "FINAL_COUNTERS",
                    format!(
                        "{}:epoch={}:value={observed}",
                        state.grant.budget_id, state.grant.epoch
                    ),
                );
                overlimit.counters = "FINAL";
                overlimit.final_value = observed;
                overlimit.phase = "STOPPING";
                edges.push(edge("MON-041B-FINAL-OVERLIMIT-QUOTA", actor, overlimit));
            }

            let mut failed = state.clone();
            failed.append_receipt(
                actor,
                "FINAL_COUNTERS_FAILED",
                format!("{}:read-failed", state.grant.budget_id),
            );
            failed.counters = "FAILED";
            failed.final_value = 0;
            fault(&mut failed, "FINAL_COUNTER_FAILURE");
            edges.push(edge("MON-042-FINAL-COUNTERS-FAILED", actor, failed));
        }

        if state.scope == "HIDDEN_DRAINED" && matches!(state.counters, "FINAL" | "FAILED") {
            let actor = "TARGET_LINUX_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(actor, "CSS_OFFLINE_ACK", state.grant.scope_id.clone());
            updated.scope = "CSS_OFFLINE";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-043-CSS-OFFLINE", actor, updated));
        }

        if state.scope == "CSS_OFFLINE" {
            let actor = "TARGET_LINUX_OBSERVER";
            let mut updated = state.clone();
            updated.append_receipt(actor, "SCOPE_RELEASED_ACK", state.grant.scope_id.clone());
            updated.scope = "RELEASED";
            updated.phase = "STOPPING";
            edges.push(edge("OBS-044-SCOPE-RELEASED", actor, updated));
        }

        if closure_ready(state) {
            let prefix_root = state.last_evidence_hash();
            let mut updated = state.clone();
            updated.append_receipt(controller, "EVIDENCE_SEAL", prefix_root);
            updated.evidence_ledger = "SEALED";
            updated.evidence_root = updated.last_evidence_hash();
            updated.phase = "QUIESCENT";
            edges.push(edge("SUP-045-SEAL-EVIDENCE", controller, updated));
        }
    }

    if state.phase == "QUIESCENT" {
        let decision = expected_local_decision(state);
        let mut receipt = DecisionReceipt {
            schema: SCHEMA,
            run_id: state.grant.child_run_id.clone(),
            binding_digest: state.grant.binding_digest(),
            evidence_root: state.evidence_root.clone(),
            decision,
            payload_kind: state.candidate_kind,
            payload_digest: state.candidate_digest.clone(),
            issuer: controller,
            auth_tag: String::new(),
        };
        receipt.auth_tag = digest("ABSTRACT_DECISION_AUTH", &receipt.body());
        let mut updated = state.clone();
        updated.local_decision = decision;
        updated.decision_receipt = Some(receipt);
        updated.phase = "DECIDED";
        edges.push(edge("SUP-046-DECIDE-LOCAL", controller, updated));
        if state.primary_state == "ACTIVE" {
            edges.push(failover_edge(state, false));
        }
    }

    edges
}

struct GraphEdge {
    source: usize,
    action_id: &'static str,
    actor: &'static str,
    target_key: Vec<u8>,
}

struct SetupGraph {
    role: &'static str,
    states: Vec<State>,
    edges: Vec<GraphEdge>,
}

struct PrefixGraph {
    role: &'static str,
    source_limit: usize,
    expanded: usize,
    states: Vec<State>,
    edges: Vec<GraphEdge>,
}

struct PrefixStats {
    role: &'static str,
    source_limit: usize,
    expanded: usize,
    state_count: usize,
    edge_count: usize,
    action_counts: BTreeMap<&'static str, usize>,
}

struct ExactBehavioralIndex {
    heads: HashMap<[u8; 32], usize>,
    collision_links: Vec<usize>,
}

impl ExactBehavioralIndex {
    const END: usize = usize::MAX;

    fn new() -> Self {
        Self {
            heads: HashMap::new(),
            collision_links: Vec::new(),
        }
    }

    fn intern(&mut self, states: &mut Vec<State>, candidate: State) -> (usize, bool) {
        let candidate_bytes = candidate.behavioral_bytes();
        let identity_digest = sha256::hash(&candidate_bytes);
        self.intern_with_digest(states, candidate, candidate_bytes, identity_digest)
    }

    fn intern_with_digest(
        &mut self,
        states: &mut Vec<State>,
        candidate: State,
        candidate_bytes: Vec<u8>,
        identity_digest: [u8; 32],
    ) -> (usize, bool) {
        assert_eq!(states.len(), self.collision_links.len());
        let mut cursor = self
            .heads
            .get(&identity_digest)
            .copied()
            .unwrap_or(Self::END);
        while cursor != Self::END {
            if states[cursor].behavioral_bytes() == candidate_bytes {
                return (cursor, false);
            }
            cursor = self.collision_links[cursor];
        }
        let state_index = states.len();
        let previous_head = self
            .heads
            .insert(identity_digest, state_index)
            .unwrap_or(Self::END);
        states.push(candidate);
        self.collision_links.push(previous_head);
        (state_index, true)
    }
}

fn setup_closure(role: &'static str) -> SetupGraph {
    let start = State::initial(fixture_external_grant(role));
    let start_key = start.behavioral_bytes();
    let mut states = vec![start];
    let mut representatives = HashMap::new();
    representatives.insert(start_key, 0_usize);
    let mut frontier = vec![0_usize];
    let mut cursor = 0_usize;
    let mut graph_edges = Vec::new();
    while cursor < frontier.len() {
        let source = frontier[cursor];
        cursor += 1;
        if states[source].phase == "RUNNING" {
            continue;
        }
        for edge in next_states(&states[source]) {
            let target_key = edge.state.behavioral_bytes();
            if !representatives.contains_key(&target_key) {
                let target = states.len();
                representatives.insert(target_key.clone(), target);
                states.push(edge.state.clone());
                frontier.push(target);
            }
            graph_edges.push(GraphEdge {
                source,
                action_id: edge.action_id,
                actor: edge.actor,
                target_key,
            });
        }
    }
    assert_eq!(
        states.len(),
        EXPECTED_SETUP_STATES,
        "setup state-count drift"
    );
    assert_eq!(
        graph_edges.len(),
        EXPECTED_SETUP_EDGES,
        "setup edge-count drift"
    );
    SetupGraph {
        role,
        states,
        edges: graph_edges,
    }
}

fn bounded_prefix(role: &'static str, source_limit: usize) -> PrefixGraph {
    assert!(source_limit > 0, "source limit must be positive");
    let start = State::initial(fixture_external_grant(role));
    let start_key = start.behavioral_bytes();
    let mut states = vec![start];
    let mut representatives = HashMap::new();
    representatives.insert(start_key, 0_usize);
    let mut frontier = vec![0_usize];
    let mut cursor = 0_usize;
    let mut graph_edges = Vec::new();
    while cursor < frontier.len() && cursor < source_limit {
        let source = frontier[cursor];
        cursor += 1;
        for edge in next_states(&states[source]) {
            let target_key = edge.state.behavioral_bytes();
            if !representatives.contains_key(&target_key) {
                let target = states.len();
                representatives.insert(target_key.clone(), target);
                states.push(edge.state.clone());
                frontier.push(target);
            }
            graph_edges.push(GraphEdge {
                source,
                action_id: edge.action_id,
                actor: edge.actor,
                target_key,
            });
        }
    }
    PrefixGraph {
        role,
        source_limit,
        expanded: cursor,
        states,
        edges: graph_edges,
    }
}

fn bounded_stats(role: &'static str, source_limit: usize) -> PrefixStats {
    assert!(source_limit > 0, "source limit must be positive");
    let mut states = Vec::new();
    let mut representatives = ExactBehavioralIndex::new();
    let (start_index, start_is_new) =
        representatives.intern(&mut states, State::initial(fixture_external_grant(role)));
    assert_eq!((start_index, start_is_new), (0, true));
    let mut frontier = vec![0_usize];
    let mut cursor = 0_usize;
    let mut edge_count = 0_usize;
    let mut action_counts = BTreeMap::new();
    while cursor < frontier.len() && cursor < source_limit {
        let source = frontier[cursor];
        cursor += 1;
        for edge in next_states(&states[source]) {
            let (target, target_is_new) = representatives.intern(&mut states, edge.state);
            if target_is_new {
                frontier.push(target);
            }
            edge_count += 1;
            *action_counts.entry(edge.action_id).or_insert(0) += 1;
        }
    }
    PrefixStats {
        role,
        source_limit,
        expanded: cursor,
        state_count: states.len(),
        edge_count,
        action_counts,
    }
}

pub fn emit_setup_closure(role: &'static str) {
    let graph = setup_closure(role);
    let keys: Vec<Vec<u8>> = graph.states.iter().map(State::behavioral_bytes).collect();
    let mut outgoing: BTreeMap<Vec<u8>, Vec<(&str, &str, Vec<u8>)>> =
        keys.iter().cloned().map(|key| (key, Vec::new())).collect();
    for edge in &graph.edges {
        outgoing
            .get_mut(&keys[edge.source])
            .expect("source state absent")
            .push((edge.action_id, edge.actor, edge.target_key.clone()));
    }
    println!(
        "F0_C4_RUST_SETUP_CLOSURE_V1\t{}\t{}\t{}",
        graph.role,
        graph.states.len(),
        graph.edges.len()
    );
    for (key, mut edges) in outgoing {
        edges.sort();
        let edge_text = edges
            .iter()
            .map(|(action, actor, target)| {
                format!(
                    "{}:{}:{}",
                    canonical::hex(action.as_bytes()),
                    canonical::hex(actor.as_bytes()),
                    canonical::hex(target)
                )
            })
            .collect::<Vec<_>>()
            .join(";");
        println!(
            "S\t{}\t{}\t{}",
            canonical::hex(&key),
            edges.len(),
            edge_text
        );
    }
}

pub fn emit_bounded_prefix(role: &'static str, source_limit: usize) {
    let graph = bounded_prefix(role, source_limit);
    let keys: Vec<Vec<u8>> = graph.states.iter().map(State::behavioral_bytes).collect();
    let mut outgoing: BTreeMap<Vec<u8>, Vec<(&str, &str, Vec<u8>)>> =
        keys.iter().cloned().map(|key| (key, Vec::new())).collect();
    for edge in &graph.edges {
        outgoing
            .get_mut(&keys[edge.source])
            .expect("source state absent")
            .push((edge.action_id, edge.actor, edge.target_key.clone()));
    }
    println!(
        "F0_C4_RUST_BOUNDED_PREFIX_V1\t{}\t{}\t{}\t{}\t{}",
        graph.role,
        graph.source_limit,
        graph.expanded,
        graph.states.len(),
        graph.edges.len()
    );
    for (key, mut edges) in outgoing {
        edges.sort();
        let edge_text = edges
            .iter()
            .map(|(action, actor, target)| {
                format!(
                    "{}:{}:{}",
                    canonical::hex(action.as_bytes()),
                    canonical::hex(actor.as_bytes()),
                    canonical::hex(target)
                )
            })
            .collect::<Vec<_>>()
            .join(";");
        println!(
            "S\t{}\t{}\t{}",
            canonical::hex(&key),
            edges.len(),
            edge_text
        );
    }
}

pub fn emit_bounded_stats(role: &'static str, source_limit: usize) {
    let stats = bounded_stats(role, source_limit);
    println!(
        "F0_C4_RUST_BOUNDED_STATS_V1\t{}\t{}\t{}\t{}\t{}",
        stats.role, stats.source_limit, stats.expanded, stats.state_count, stats.edge_count
    );
    for (action_id, count) in stats.action_counts {
        println!("A\t{}\t{}", canonical::hex(action_id.as_bytes()), count);
    }
}

fn emit_trace_point(index: usize, state: &State, outgoing: &[Edge]) {
    let mut edges: Vec<(&str, &str, Vec<u8>)> = outgoing
        .iter()
        .map(|edge| (edge.action_id, edge.actor, edge.state.behavioral_bytes()))
        .collect();
    edges.sort();
    let edge_text = edges
        .iter()
        .map(|(action, actor, target)| {
            format!(
                "{}:{}:{}",
                canonical::hex(action.as_bytes()),
                canonical::hex(actor.as_bytes()),
                canonical::hex(target)
            )
        })
        .collect::<Vec<_>>()
        .join(";");
    println!(
        "P\t{}\t{}\t{}\t{}",
        index,
        canonical::hex(&state.behavioral_bytes()),
        edges.len(),
        edge_text
    );
}

pub fn emit_trace(role: &'static str, action_ids: &[String]) {
    assert!(!action_ids.is_empty(), "trace must contain an action");
    assert!(
        action_ids.iter().all(|action_id| !action_id.is_empty()),
        "trace contains an empty action"
    );
    println!(
        "F0_C4_RUST_TRACE_V1\t{}\t{}\t{}",
        role,
        action_ids.len(),
        action_ids
            .iter()
            .map(|action_id| canonical::hex(action_id.as_bytes()))
            .collect::<Vec<_>>()
            .join(";")
    );
    let mut state = State::initial(fixture_external_grant(role));
    for (index, action_id) in action_ids.iter().enumerate() {
        let mut outgoing = next_states(&state);
        emit_trace_point(index, &state, &outgoing);
        let matching: Vec<usize> = outgoing
            .iter()
            .enumerate()
            .filter_map(|(position, edge)| (edge.action_id == action_id).then_some(position))
            .collect();
        assert_eq!(
            matching.len(),
            1,
            "trace action is not uniquely enabled: {index}:{action_id}:{}",
            matching.len()
        );
        state = outgoing.remove(matching[0]).state;
    }
    let outgoing = next_states(&state);
    emit_trace_point(action_ids.len(), &state, &outgoing);
}

#[cfg(test)]
mod tests {
    use super::{
        bounded_prefix, bounded_stats, fixture_external_grant, setup_closure, ExactBehavioralIndex,
        State, EXPECTED_SETUP_EDGES, EXPECTED_SETUP_STATES,
    };

    #[test]
    fn fixture_grant_ids_are_stable() {
        assert_eq!(
            fixture_external_grant("PRODUCER").child_run_id,
            "child-dc5da0fb42f64581cc143755"
        );
        assert_eq!(
            fixture_external_grant("CHECKER").child_run_id,
            "child-ca08b3d4b0c44e8e943de350"
        );
    }

    #[test]
    fn setup_closure_counts_are_role_stable() {
        for role in ["PRODUCER", "CHECKER"] {
            let graph = setup_closure(role);
            assert_eq!(graph.states.len(), EXPECTED_SETUP_STATES);
            assert_eq!(graph.edges.len(), EXPECTED_SETUP_EDGES);
            assert_eq!(
                graph
                    .states
                    .iter()
                    .filter(|state| state.phase == "RUNNING")
                    .count(),
                8
            );
        }
    }

    #[test]
    fn bounded_prefix_expands_requested_sources() {
        for role in ["PRODUCER", "CHECKER"] {
            let graph = bounded_prefix(role, 1);
            assert_eq!(graph.expanded, 1);
            assert_eq!(graph.source_limit, 1);
            assert!(graph.states.len() > 1);
            assert!(!graph.edges.is_empty());
        }
    }

    #[test]
    fn bounded_stats_match_prefix_counts() {
        for role in ["PRODUCER", "CHECKER"] {
            let graph = bounded_prefix(role, 50);
            let stats = bounded_stats(role, 50);
            assert_eq!(stats.expanded, 50);
            assert_eq!(stats.state_count, graph.states.len());
            assert_eq!(stats.edge_count, graph.edges.len());
        }
    }

    #[test]
    fn behavioral_index_resolves_forced_digest_collisions_by_full_bytes() {
        let mut index = ExactBehavioralIndex::new();
        let mut states = Vec::new();
        let first = State::initial(fixture_external_grant("PRODUCER"));
        let first_bytes = first.behavioral_bytes();
        let forced_digest = [0x5a; 32];
        assert_eq!(
            index.intern_with_digest(
                &mut states,
                first.clone(),
                first_bytes.clone(),
                forced_digest,
            ),
            (0, true)
        );
        let mut distinct = first.clone();
        distinct.phase = "SCOPE_REQUESTED";
        assert_eq!(
            index.intern_with_digest(
                &mut states,
                distinct.clone(),
                distinct.behavioral_bytes(),
                forced_digest,
            ),
            (1, true)
        );
        assert_eq!(
            index.intern_with_digest(&mut states, first, first_bytes, forced_digest),
            (0, false)
        );
        assert_eq!(states.len(), 2);
    }
}
