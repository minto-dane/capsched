use std::collections::BTreeMap;

use super::{
    closure_ready, digest, expected_candidate_digest, expected_local_decision, Receipt,
    RecoveryReceipt, RunGrant, State, SCHEMA,
};

const MAX_REACQUISITIONS: u64 = 2;
const MAX_HOSTILE_ATTEMPTS: usize = 2;

fn one_of(value: &str, choices: &[&str]) -> bool {
    choices.contains(&value)
}

fn pending_attack(value: &str) -> bool {
    one_of(
        value,
        &[
            "NONE",
            "ATTACH",
            "FD_ESCAPE",
            "PTRACE",
            "FORGED_RECEIPT",
            "REPLAY_RECEIPT",
        ],
    )
}

fn nonempty(values: &[&str]) -> bool {
    values.iter().all(|value| !value.is_empty())
}

fn grant_wf(grant: &RunGrant) -> bool {
    if !one_of(grant.role, &["PRODUCER", "CHECKER"]) {
        return false;
    }
    let expected_ordinal = if grant.role == "PRODUCER" { 0 } else { 1 };
    grant.ordinal == expected_ordinal
        && grant.epoch > 0
        && !grant.parent_run_id.is_empty()
        && !grant.nonce.is_empty()
        && grant.child_run_id
            == super::derive_child_run_id(
                &grant.parent_run_id,
                grant.role,
                grant.ordinal,
                &grant.nonce,
            )
        && grant.scope_id == format!("scope-{}", grant.child_run_id)
        && grant.subject_id == format!("subject-{}", grant.child_run_id)
        && grant.budget_id == format!("budget-{}", grant.child_run_id)
        && grant.budget_limit > 0
        && grant.issuer == "EXTERNAL_OWNER"
        && grant.auth_tag == digest("ABSTRACT_EXTERNAL_OWNER_AUTH", &grant.payload())
        && nonempty(&[
            &grant.validation_context_digest,
            &grant.policy_digest,
            &grant.profile_digest,
            &grant.immutable_input_digest,
            &grant.hierarchy_id,
        ])
}

#[derive(Clone, Copy)]
struct ReceiptSpec {
    channel: &'static str,
    singleton: bool,
}

fn receipt_spec(kind: &str) -> Option<ReceiptSpec> {
    let singleton = !one_of(
        kind,
        &[
            "HOSTILE_ATTEMPT_OBSERVED",
            "HOSTILE_ATTEMPT_REJECTED",
            "DESCENDANTS_EXITED",
            "ASYNC_REFS_DRAINED",
            "VISIBLE_EMPTY_ACK",
        ],
    );
    let channel = match kind {
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
        | "FINAL_COUNTERS_FAILED"
        | "LINUX_LIMIT_UNATTRIBUTED" => "RESOURCE",
        "UNTRUSTED_FRAME_OBSERVED"
        | "STREAM_EOF_VALID"
        | "STREAM_EOF_TRUNCATED"
        | "STREAM_EOF_INVALID" => "STREAM",
        "HOSTILE_ATTEMPT_OBSERVED" | "HOSTILE_ATTEMPT_REJECTED" => "SECURITY",
        "PRIMARY_FAILOVER" => "RECOVERY",
        "OWNER_REVOKED" => "EXTERNAL",
        "QUOTA_LINEARIZED" | "COMPLETION_LINEARIZED" | "FAULT_LINEARIZED" => "ARBITRATION",
        "WAIT_NORMAL" | "WAIT_SIGNALLED" | "WAIT_ABNORMAL" | "DESCENDANTS_EXITED"
        | "COMPLETION_ARRIVED" | "LEADER_REAPED" | "VISIBLE_EMPTY_ACK" | "CSS_OFFLINE_ACK"
        | "SCOPE_RELEASED_ACK" => "TARGET_LINUX",
        _ => return None,
    };
    Some(ReceiptSpec { channel, singleton })
}

fn receipt_issuer_wf(kind: &str, issuer: &str) -> bool {
    match kind {
        "SCOPE_REQUESTED"
        | "BOOTSTRAP_REQUESTED"
        | "SANDBOX_REQUESTED"
        | "HOSTILE_PAYLOAD_RELEASED"
        | "ASYNC_ADMISSION_CLOSED"
        | "TERMINATION_REQUESTED"
        | "EVIDENCE_SEAL" => one_of(issuer, &["PRIMARY_SUPERVISOR", "RECOVERY_GUARDIAN"]),
        "SCOPE_CONFIGURED_ACK"
        | "CHARGED_BOOTSTRAP_ACK"
        | "SANDBOX_PROFILE_ACK"
        | "ASYNC_REFS_DRAINED"
        | "RMDIR_ATTACH_CLOSED_ACK"
        | "TASK_POPULATION_ZERO_ACK"
        | "HIDDEN_WORK_DRAINED_ACK" => issuer == "MANAGEMENT_DOMAIN_OBSERVER",
        "MONITOR_EXECUTION_ACTIVATED_ACK"
        | "BASELINE_COUNTERS"
        | "MONITOR_QUOTA_ARRIVED"
        | "EXECUTION_REVOKED_ACK"
        | "MONITOR_PROTECTION_CLOSED_ACK"
        | "FINAL_COUNTERS"
        | "FINAL_COUNTERS_FAILED" => issuer == "MONITOR_OBSERVER",
        "UNTRUSTED_FRAME_OBSERVED"
        | "STREAM_EOF_VALID"
        | "STREAM_EOF_TRUNCATED"
        | "STREAM_EOF_INVALID"
        | "LINUX_LIMIT_UNATTRIBUTED"
        | "WAIT_NORMAL"
        | "WAIT_SIGNALLED"
        | "WAIT_ABNORMAL"
        | "DESCENDANTS_EXITED"
        | "COMPLETION_ARRIVED"
        | "LEADER_REAPED"
        | "VISIBLE_EMPTY_ACK"
        | "CSS_OFFLINE_ACK"
        | "SCOPE_RELEASED_ACK" => issuer == "TARGET_LINUX_OBSERVER",
        "HOSTILE_ATTEMPT_OBSERVED" => issuer == "ADVERSARY",
        "HOSTILE_ATTEMPT_REJECTED" => issuer == "MANAGEMENT_DOMAIN_OBSERVER",
        "PRIMARY_FAILOVER" => issuer == "RECOVERY_GUARDIAN",
        "OWNER_REVOKED" => issuer == "EXTERNAL_OWNER",
        "QUOTA_LINEARIZED" | "COMPLETION_LINEARIZED" | "FAULT_LINEARIZED" => {
            issuer == "LOCAL_ARBITER"
        }
        _ => false,
    }
}

fn chronological_receipts(state: &State) -> Vec<&Receipt> {
    let mut receipts: Vec<&Receipt> = state.evidence_receipts.iter().collect();
    receipts.reverse();
    receipts
}

fn receipt_wf(receipt: &Receipt, grant: &RunGrant, previous_hash: &str, sequence: usize) -> bool {
    let Some(spec) = receipt_spec(receipt.kind) else {
        return false;
    };
    receipt.schema == SCHEMA
        && receipt.run_id == grant.child_run_id
        && receipt.binding_digest == grant.binding_digest()
        && receipt.scope_id == grant.scope_id
        && receipt.subject_id == grant.subject_id
        && receipt.sequence == sequence as u64
        && receipt.payload_digest
            == digest(
                "RECEIPT_PAYLOAD",
                &[receipt.kind.to_owned(), receipt.payload.clone()],
            )
        && receipt_issuer_wf(receipt.kind, receipt.issuer)
        && receipt.channel == spec.channel
        && receipt.previous_hash == previous_hash
        && receipt.auth_tag == digest("ABSTRACT_ISSUER_AUTH", &receipt.body())
}

fn parse_number_after(value: &str, prefix: &str) -> Option<u64> {
    value.strip_prefix(prefix)?.parse().ok()
}

fn receipt_payload_wf(state: &State, receipt: &Receipt) -> bool {
    let grant = &state.grant;
    let fixed = match receipt.kind {
        "SCOPE_REQUESTED" => Some(grant.scope_id.clone()),
        "SCOPE_CONFIGURED_ACK" => Some(format!(
            "{}:{}:exclusive",
            grant.hierarchy_id, grant.scope_id
        )),
        "BOOTSTRAP_REQUESTED" => Some(grant.scope_id.clone()),
        "CHARGED_BOOTSTRAP_ACK" => Some(format!("{}:held-before-hostile-exec", grant.scope_id)),
        "MONITOR_EXECUTION_ACTIVATED_ACK" => Some(format!(
            "{}:epoch={}:activated-held",
            grant.child_run_id, grant.epoch
        )),
        "SANDBOX_REQUESTED" => Some(grant.profile_digest.clone()),
        "SANDBOX_PROFILE_ACK" => Some(format!("{}:payload-held:fd-confined", grant.profile_digest)),
        "BASELINE_COUNTERS" => Some(format!("{}:epoch={}:value=0", grant.budget_id, grant.epoch)),
        "HOSTILE_PAYLOAD_RELEASED" => {
            Some(format!("{}:{}", grant.subject_id, grant.profile_digest))
        }
        "STREAM_EOF_TRUNCATED" => Some("no-complete-frame".to_owned()),
        "OWNER_REVOKED" => Some(format!("epoch={}", grant.epoch)),
        "LINUX_LIMIT_UNATTRIBUTED" => Some(format!("{}:causality-unproved", grant.budget_id)),
        "WAIT_NORMAL" => Some("leader-normal-exit".to_owned()),
        "WAIT_SIGNALLED" => Some("controller-termination".to_owned()),
        "WAIT_ABNORMAL" => Some("unattributed-abnormal-exit".to_owned()),
        "LEADER_REAPED" => Some(grant.subject_id.clone()),
        "RMDIR_ATTACH_CLOSED_ACK" => Some(format!("{}:no-future-attach", grant.scope_id)),
        "ASYNC_ADMISSION_CLOSED" => Some(format!("{}:no-future-async-acquire", grant.scope_id)),
        "EXECUTION_REVOKED_ACK" => Some(format!(
            "{}:epoch={}:revoked",
            grant.child_run_id, grant.epoch
        )),
        "MONITOR_PROTECTION_CLOSED_ACK" => Some(format!(
            "{}:epoch={}:admission-and-execution-closed",
            grant.child_run_id, grant.epoch
        )),
        "TASK_POPULATION_ZERO_ACK"
        | "HIDDEN_WORK_DRAINED_ACK"
        | "CSS_OFFLINE_ACK"
        | "SCOPE_RELEASED_ACK" => Some(grant.scope_id.clone()),
        "FINAL_COUNTERS_FAILED" => Some(format!("{}:read-failed", grant.budget_id)),
        _ => None,
    };
    if let Some(expected) = fixed {
        return receipt.payload == expected;
    }

    match receipt.kind {
        "UNTRUSTED_FRAME_OBSERVED" => {
            state.candidate_kind != "NONE"
                && receipt.payload
                    == super::candidate_payload(state, state.candidate_kind, state.candidate_value)
        }
        "STREAM_EOF_VALID" => {
            !state.candidate_digest.is_empty() && receipt.payload == state.candidate_digest
        }
        "STREAM_EOF_INVALID" => {
            let expected = if state.candidate_kind == "NONE" {
                "framing-invalid"
            } else {
                "trailing-or-duplicate-frame"
            };
            receipt.payload == expected
        }
        "HOSTILE_ATTEMPT_OBSERVED" | "HOSTILE_ATTEMPT_REJECTED" => {
            let Some(value) = receipt.payload.strip_prefix("attempt=") else {
                return false;
            };
            let Some((raw_attempt, kind)) = value.split_once(":kind=") else {
                return false;
            };
            let Ok(attempt) = raw_attempt.parse::<usize>() else {
                return false;
            };
            let history = if receipt.kind == "HOSTILE_ATTEMPT_OBSERVED" {
                &state.attack_attempts
            } else {
                &state.attack_rejections
            };
            attempt > 0 && attempt <= history.len() && history[attempt - 1] == kind
        }
        "PRIMARY_FAILOVER" => receipt
            .payload
            .strip_prefix("phase=")
            .map(|phase| phase_wf(phase))
            .unwrap_or(false),
        "MONITOR_QUOTA_ARRIVED" => {
            receipt.payload
                == format!(
                    "{}:epoch={}:value={}:arrival={}",
                    grant.budget_id,
                    grant.epoch,
                    state.resource_observed_value,
                    state.quota_arrival_sequence
                )
        }
        "TERMINATION_REQUESTED" => receipt.payload == format!("winner={}", state.winner),
        "COMPLETION_LINEARIZED" | "COMPLETION_ARRIVED" => {
            !state.candidate_digest.is_empty()
                && receipt.payload
                    == format!(
                        "{}:arrival={}",
                        state.candidate_digest, state.completion_arrival_sequence
                    )
        }
        "QUOTA_LINEARIZED" => {
            receipt.payload == format!("arrival={}", state.quota_arrival_sequence)
        }
        "FAULT_LINEARIZED" => {
            receipt.payload == format!("arrival={}", state.fault_arrival_sequence)
        }
        "FINAL_COUNTERS" => {
            receipt.payload
                == format!(
                    "{}:epoch={}:value={}",
                    grant.budget_id, grant.epoch, state.final_value
                )
        }
        "EVIDENCE_SEAL" => receipt.payload == receipt.previous_hash,
        "DESCENDANTS_EXITED" => {
            let prefix = format!("{}:generation=", grant.scope_id);
            parse_number_after(&receipt.payload, &prefix)
                .map(|generation| {
                    generation > 0 && generation <= state.descendant_drained_generation
                })
                .unwrap_or(false)
        }
        "VISIBLE_EMPTY_ACK" => {
            let prefix = format!("{}:observation=", grant.scope_id);
            parse_number_after(&receipt.payload, &prefix)
                .map(|observation| {
                    observation > 0 && observation <= state.visible_empty_observations
                })
                .unwrap_or(false)
        }
        "ASYNC_REFS_DRAINED" => {
            let prefix = format!("{}:generation=", grant.scope_id);
            parse_number_after(&receipt.payload, &prefix)
                .map(|generation| generation > 0 && generation <= state.async_drained_generation)
                .unwrap_or(false)
        }
        _ => false,
    }
}

fn phase_wf(value: &str) -> bool {
    one_of(
        value,
        &[
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
        ],
    )
}

fn count(receipts: &[&Receipt], kind: &str) -> usize {
    receipts
        .iter()
        .filter(|receipt| receipt.kind == kind)
        .count()
}

fn positions(receipts: &[&Receipt], kind: &str) -> Vec<usize> {
    receipts
        .iter()
        .enumerate()
        .filter_map(|(index, receipt)| (receipt.kind == kind).then_some(index))
        .collect()
}

fn sorted_values_are_exact_one_based(values: &mut [u64], expected_count: u64) -> bool {
    if u64::try_from(values.len()).ok() != Some(expected_count) {
        return false;
    }
    values.sort_unstable();
    values.iter().enumerate().all(|(index, value)| {
        u64::try_from(index)
            .ok()
            .and_then(|converted| converted.checked_add(1))
            == Some(*value)
    })
}

fn require_before(receipts: &[&Receipt], before: &str, after: &str) -> bool {
    let before_positions = positions(receipts, before);
    let after_positions = positions(receipts, after);
    if after_positions.is_empty() {
        return true;
    }
    !before_positions.is_empty()
        && before_positions.iter().max().unwrap() < after_positions.iter().min().unwrap()
}

fn phase_after_evidence_prefix(receipts: &[&Receipt]) -> &'static str {
    let mut phase = "NEW";
    for receipt in receipts {
        if receipt.kind == "UNTRUSTED_FRAME_OBSERVED"
            && receipt.payload.starts_with("INTERNAL|INTERNAL|")
        {
            phase = "STOPPING";
            continue;
        }
        phase = match receipt.kind {
            "SCOPE_REQUESTED" => "SCOPE_REQUESTED",
            "SCOPE_CONFIGURED_ACK" => "SCOPE_CONFIGURED",
            "BOOTSTRAP_REQUESTED" => "BOOTSTRAP_REQUESTED",
            "CHARGED_BOOTSTRAP_ACK" => "BOOTSTRAP_HELD",
            "SANDBOX_REQUESTED" => "SANDBOX_REQUESTED",
            "SANDBOX_PROFILE_ACK" => "READY",
            "HOSTILE_PAYLOAD_RELEASED" => "RUNNING",
            "STREAM_EOF_TRUNCATED"
            | "STREAM_EOF_INVALID"
            | "HOSTILE_ATTEMPT_REJECTED"
            | "OWNER_REVOKED"
            | "QUOTA_LINEARIZED"
            | "LINUX_LIMIT_UNATTRIBUTED"
            | "TERMINATION_REQUESTED"
            | "WAIT_NORMAL"
            | "WAIT_SIGNALLED"
            | "WAIT_ABNORMAL"
            | "DESCENDANTS_EXITED"
            | "ASYNC_REFS_DRAINED"
            | "COMPLETION_LINEARIZED"
            | "FAULT_LINEARIZED"
            | "LEADER_REAPED"
            | "VISIBLE_EMPTY_ACK"
            | "RMDIR_ATTACH_CLOSED_ACK"
            | "ASYNC_ADMISSION_CLOSED"
            | "EXECUTION_REVOKED_ACK"
            | "MONITOR_PROTECTION_CLOSED_ACK"
            | "TASK_POPULATION_ZERO_ACK"
            | "HIDDEN_WORK_DRAINED_ACK"
            | "FINAL_COUNTERS"
            | "FINAL_COUNTERS_FAILED"
            | "CSS_OFFLINE_ACK"
            | "SCOPE_RELEASED_ACK" => "STOPPING",
            "EVIDENCE_SEAL" => "QUIESCENT",
            _ => phase,
        };
    }
    phase
}

fn receipt_backed_fault_events(state: &State, receipts: &[&Receipt]) -> Vec<(u64, &'static str)> {
    let recovery_phase = if state.recovery_receipts.len() == 1 {
        Some(state.recovery_receipts[0].observed_phase)
    } else {
        None
    };
    let mut events = Vec::new();
    for receipt in receipts {
        let mut cause = match receipt.kind {
            "STREAM_EOF_TRUNCATED" => Some("STREAM_TRUNCATED"),
            "STREAM_EOF_INVALID" => Some("STREAM_INVALID"),
            "HOSTILE_ATTEMPT_REJECTED" => Some("HOSTILE_REJECTION"),
            "OWNER_REVOKED" => Some("OWNER_REVOCATION"),
            "LINUX_LIMIT_UNATTRIBUTED" => Some("LINUX_LIMIT"),
            "WAIT_ABNORMAL" => Some("ABNORMAL_EXIT"),
            "FINAL_COUNTERS_FAILED" => Some("FINAL_COUNTER_FAILURE"),
            _ => None,
        };
        if receipt.kind == "PRIMARY_FAILOVER"
            && matches!(recovery_phase, Some("RUNNING" | "STOPPING"))
        {
            cause = Some("PRIMARY_RUNTIME_FAILOVER");
        } else if receipt.kind == "UNTRUSTED_FRAME_OBSERVED"
            && receipt.payload.starts_with("INTERNAL|INTERNAL|")
        {
            cause = Some("INTERNAL_FRAME");
        }
        if let Some(cause) = cause {
            events.push((receipt.sequence, cause));
        }
    }
    events
}

pub(super) fn evidence_wf(state: &State) -> bool {
    let receipts = chronological_receipts(state);
    let mut previous = state.genesis_hash();
    let mut counts: BTreeMap<&str, usize> = BTreeMap::new();
    let mut active_controller = "PRIMARY_SUPERVISOR";
    for (index, receipt) in receipts.iter().enumerate() {
        if !receipt_wf(receipt, &state.grant, &previous, index + 1)
            || !receipt_payload_wf(state, receipt)
        {
            return false;
        }
        if receipt.kind == "PRIMARY_FAILOVER" {
            if active_controller != "PRIMARY_SUPERVISOR" || receipt.issuer != "RECOVERY_GUARDIAN" {
                return false;
            }
            active_controller = "RECOVERY_GUARDIAN";
        } else if one_of(receipt.issuer, &["PRIMARY_SUPERVISOR", "RECOVERY_GUARDIAN"])
            && receipt.issuer != active_controller
        {
            return false;
        }
        let entry = counts.entry(receipt.kind).or_default();
        *entry += 1;
        if receipt_spec(receipt.kind).unwrap().singleton && *entry > 1 {
            return false;
        }
        previous = receipt.receipt_hash();
    }

    let setup_chain = [
        "SCOPE_REQUESTED",
        "SCOPE_CONFIGURED_ACK",
        "BOOTSTRAP_REQUESTED",
        "CHARGED_BOOTSTRAP_ACK",
        "MONITOR_EXECUTION_ACTIVATED_ACK",
        "SANDBOX_REQUESTED",
        "SANDBOX_PROFILE_ACK",
        "BASELINE_COUNTERS",
        "HOSTILE_PAYLOAD_RELEASED",
    ];
    for pair in setup_chain.windows(2) {
        if !require_before(&receipts, pair[0], pair[1]) {
            return false;
        }
    }
    for receipt in &receipts {
        if !setup_chain.contains(&receipt.kind)
            && receipt.kind != "PRIMARY_FAILOVER"
            && receipt.kind != "EVIDENCE_SEAL"
            && !require_before(&receipts, "HOSTILE_PAYLOAD_RELEASED", receipt.kind)
        {
            return false;
        }
    }

    for (before, after) in [
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
        ("STREAM_EOF_VALID", "COMPLETION_ARRIVED"),
        ("WAIT_NORMAL", "COMPLETION_ARRIVED"),
        ("COMPLETION_ARRIVED", "COMPLETION_LINEARIZED"),
        ("CSS_OFFLINE_ACK", "SCOPE_RELEASED_ACK"),
    ] {
        if !require_before(&receipts, before, after) {
            return false;
        }
    }
    if count(&receipts, "STREAM_EOF_INVALID") > 0
        && count(&receipts, "UNTRUSTED_FRAME_OBSERVED") > 0
        && !require_before(&receipts, "UNTRUSTED_FRAME_OBSERVED", "STREAM_EOF_INVALID")
    {
        return false;
    }
    if count(&receipts, "TERMINATION_REQUESTED") > 0 {
        let termination = positions(&receipts, "TERMINATION_REQUESTED")[0];
        let winner_before = ["QUOTA_LINEARIZED", "FAULT_LINEARIZED"].iter().any(|kind| {
            positions(&receipts, kind)
                .last()
                .map(|position| *position < termination)
                .unwrap_or(false)
        });
        if !winner_before {
            return false;
        }
    }
    if count(&receipts, "FAULT_LINEARIZED") > 0 {
        let fault_linearized = positions(&receipts, "FAULT_LINEARIZED")[0];
        if state.fault_cause_receipt_sequence == 0
            || state.fault_cause_receipt_sequence as usize > receipts.len()
            || state.fault_cause_receipt_sequence as usize - 1 >= fault_linearized
        {
            return false;
        }
    }
    if count(&receipts, "MONITOR_QUOTA_ARRIVED") > 0
        && count(&receipts, "FINAL_COUNTERS") > 0
        && !require_before(&receipts, "MONITOR_QUOTA_ARRIVED", "FINAL_COUNTERS")
    {
        return false;
    }
    if !require_before(&receipts, "MONITOR_QUOTA_ARRIVED", "QUOTA_LINEARIZED") {
        return false;
    }
    if count(&receipts, "DESCENDANTS_EXITED") > 0 {
        let first_descendants = positions(&receipts, "DESCENDANTS_EXITED")[0];
        let first_wait = ["WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"]
            .iter()
            .filter_map(|kind| positions(&receipts, kind).first().copied())
            .min();
        if first_wait
            .map(|position| position > first_descendants)
            .unwrap_or(true)
        {
            return false;
        }
    }
    for after in ["STREAM_EOF_TRUNCATED", "LEADER_REAPED", "CSS_OFFLINE_ACK"] {
        if count(&receipts, after) == 0 {
            continue;
        }
        let first_after = positions(&receipts, after)[0];
        let predecessors: &[&str] = if after == "CSS_OFFLINE_ACK" {
            &["FINAL_COUNTERS", "FINAL_COUNTERS_FAILED"]
        } else {
            &["WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"]
        };
        if !predecessors.iter().any(|kind| {
            positions(&receipts, kind)
                .last()
                .map(|position| *position < first_after)
                .unwrap_or(false)
        }) {
            return false;
        }
    }
    if count(&receipts, "VISIBLE_EMPTY_ACK") > 0 {
        let first_visible = positions(&receipts, "VISIBLE_EMPTY_ACK")[0];
        let first_wait = ["WAIT_NORMAL", "WAIT_SIGNALLED", "WAIT_ABNORMAL"]
            .iter()
            .filter_map(|kind| positions(&receipts, kind).first().copied())
            .min();
        if first_wait
            .map(|position| position > first_visible)
            .unwrap_or(true)
        {
            return false;
        }
    }
    if count(&receipts, "ASYNC_REFS_DRAINED") > 0
        && !require_before(&receipts, "ASYNC_REFS_DRAINED", "HIDDEN_WORK_DRAINED_ACK")
    {
        return false;
    }
    if count(&receipts, "DESCENDANTS_EXITED") > 0
        && !require_before(&receipts, "DESCENDANTS_EXITED", "HIDDEN_WORK_DRAINED_ACK")
    {
        return false;
    }

    for (kind, drained_generation) in [
        ("DESCENDANTS_EXITED", state.descendant_drained_generation),
        ("ASYNC_REFS_DRAINED", state.async_drained_generation),
    ] {
        let prefix = format!("{}:generation=", state.grant.scope_id);
        let mut generations: Vec<u64> = receipts
            .iter()
            .filter(|receipt| receipt.kind == kind && receipt.payload.starts_with(&prefix))
            .filter_map(|receipt| parse_number_after(&receipt.payload, &prefix))
            .collect();
        if generations.len() != count(&receipts, kind) {
            return false;
        }
        if !sorted_values_are_exact_one_based(&mut generations, drained_generation) {
            return false;
        }
    }
    let visible_prefix = format!("{}:observation=", state.grant.scope_id);
    let mut observations: Vec<u64> = receipts
        .iter()
        .filter(|receipt| {
            receipt.kind == "VISIBLE_EMPTY_ACK" && receipt.payload.starts_with(&visible_prefix)
        })
        .filter_map(|receipt| parse_number_after(&receipt.payload, &visible_prefix))
        .collect();
    if observations.len() != count(&receipts, "VISIBLE_EMPTY_ACK") {
        return false;
    }
    if !sorted_values_are_exact_one_based(&mut observations, state.visible_empty_observations) {
        return false;
    }

    let attempt_positions = positions(&receipts, "HOSTILE_ATTEMPT_OBSERVED");
    let rejection_positions = positions(&receipts, "HOSTILE_ATTEMPT_REJECTED");
    if attempt_positions.len() != state.attack_attempts.len()
        || rejection_positions.len() != state.attack_rejections.len()
        || rejection_positions.len() > attempt_positions.len()
    {
        return false;
    }
    for (attempt, receipt_position) in attempt_positions.iter().enumerate() {
        if receipts[*receipt_position].payload
            != format!(
                "attempt={}:kind={}",
                attempt + 1,
                state.attack_attempts[attempt]
            )
        {
            return false;
        }
    }
    for (attempt, receipt_position) in rejection_positions.iter().enumerate() {
        if receipts[*receipt_position].payload
            != format!(
                "attempt={}:kind={}",
                attempt + 1,
                state.attack_rejections[attempt]
            )
        {
            return false;
        }
    }
    for (index, rejection_position) in rejection_positions.iter().enumerate() {
        if attempt_positions[index] >= *rejection_position
            || (index + 1 < attempt_positions.len()
                && *rejection_position >= attempt_positions[index + 1])
        {
            return false;
        }
    }

    let fault_events = receipt_backed_fault_events(state, &receipts);
    if state.fault == "CLEAN" {
        if state.fault_cause != "NONE"
            || state.fault_cause_receipt_sequence != 0
            || !fault_events.is_empty()
        {
            return false;
        }
    } else if let Some((first_sequence, first_cause)) = fault_events.first() {
        if state.fault_cause != *first_cause
            || state.fault_cause_receipt_sequence != *first_sequence
        {
            return false;
        }
    } else if !(state.fault_cause == "HOSTILE_BYPASS"
        && state.fault_cause_receipt_sequence == 0
        && state.phase == "BREACHED"
        && state.breach_kind != "NONE")
    {
        return false;
    }

    let seal_count = count(&receipts, "EVIDENCE_SEAL");
    if state.evidence_ledger == "OPEN" {
        return seal_count == 0 && state.evidence_root.is_empty();
    }
    if state.evidence_ledger != "SEALED" {
        return false;
    }
    seal_count == 1
        && !receipts.is_empty()
        && receipts.last().unwrap().kind == "EVIDENCE_SEAL"
        && state.evidence_root == previous
        && receipts.last().unwrap().payload == receipts.last().unwrap().previous_hash
}

fn recovery_receipt_wf(state: &State, receipt: &RecoveryReceipt, sequence: usize) -> bool {
    receipt.schema == SCHEMA
        && receipt.run_id == state.grant.child_run_id
        && receipt.binding_digest == state.grant.binding_digest()
        && receipt.sequence == sequence as u64
        && phase_wf(receipt.observed_phase)
        && !receipt.evidence_prefix_hash.is_empty()
        && receipt.reason == "PRIMARY_CRASH"
        && receipt.failed_controller == "PRIMARY_SUPERVISOR"
        && receipt.fence_generation == sequence as u64
        && receipt.issuer == "RECOVERY_GUARDIAN"
        && receipt.auth_tag == digest("ABSTRACT_RECOVERY_AUTH", &receipt.body())
}

fn recovery_wf(state: &State) -> bool {
    if state.recovery_receipts.len() > 1 {
        return false;
    }
    if !state
        .recovery_receipts
        .iter()
        .enumerate()
        .all(|(index, receipt)| recovery_receipt_wf(state, receipt, index + 1))
    {
        return false;
    }
    if (state.recovery_receipts.len() == 1) != (state.primary_state == "FAILED") {
        return false;
    }
    if state.recovery_receipts.is_empty() {
        return true;
    }

    let receipt = &state.recovery_receipts[0];
    let receipts = chronological_receipts(state);
    let failover_positions = positions(&receipts, "PRIMARY_FAILOVER");
    if let Some(failover_index) = failover_positions.first().copied() {
        let failover = receipts[failover_index];
        return failover_positions.len() == 1
            && receipt.evidence_prefix_hash == failover.previous_hash
            && failover.payload == format!("phase={}", receipt.observed_phase)
            && receipt.observed_phase == phase_after_evidence_prefix(&receipts[..failover_index]);
    }
    state.evidence_ledger == "SEALED"
        && receipt.evidence_prefix_hash == state.evidence_root
        && receipt.observed_phase == "QUIESCENT"
}

fn decision_receipt_wf(state: &State) -> bool {
    if state.local_decision == "NONE" {
        return state.decision_receipt.is_none();
    }
    let Some(receipt) = &state.decision_receipt else {
        return false;
    };
    receipt.schema == SCHEMA
        && receipt.run_id == state.grant.child_run_id
        && receipt.binding_digest == state.grant.binding_digest()
        && receipt.evidence_root == state.evidence_root
        && receipt.decision == state.local_decision
        && receipt.payload_kind == state.candidate_kind
        && receipt.payload_digest == state.candidate_digest
        && receipt.issuer == state.controller
        && receipt.auth_tag == digest("ABSTRACT_DECISION_AUTH", &receipt.body())
}

fn count_map(receipts: &[&Receipt]) -> BTreeMap<&'static str, usize> {
    let mut result = BTreeMap::new();
    for receipt in receipts {
        *result.entry(receipt.kind).or_default() += 1;
    }
    result
}

fn map_count(counts: &BTreeMap<&'static str, usize>, kind: &str) -> usize {
    counts.get(kind).copied().unwrap_or(0)
}

fn map_present(counts: &BTreeMap<&'static str, usize>, kind: &str) -> bool {
    map_count(counts, kind) > 0
}

pub(super) fn instance_wf(state: &State) -> bool {
    if !(grant_wf(&state.grant)
        && phase_wf(state.phase)
        && one_of(state.owner_state, &["ACTIVE", "REVOKED"])
        && one_of(state.primary_state, &["ACTIVE", "FAILED"])
        && one_of(
            state.controller,
            &["PRIMARY_SUPERVISOR", "RECOVERY_GUARDIAN"],
        )
        && one_of(
            state.scope,
            &[
                "UNCREATED",
                "REQUESTED",
                "CONFIGURED_EMPTY",
                "LIVE",
                "ATTACH_CLOSED",
                "HIDDEN_DRAINED",
                "CSS_OFFLINE",
                "RELEASED",
            ],
        )
        && one_of(state.visible_population, &["UNKNOWN", "EMPTY", "NONEMPTY"])
        && state.visible_empty_observations <= MAX_REACQUISITIONS + 1
        && one_of(state.task_population, &["UNKNOWN", "EMPTY", "NONEMPTY"])
        && one_of(
            state.attach_authority,
            &["UNBOUND", "EXTERNAL_EXCLUSIVE", "CLOSED"],
        )
        && one_of(state.async_admission, &["UNBOUND", "OPEN", "CLOSED"])
        && one_of(state.execution_authority, &["UNBOUND", "ACTIVE", "REVOKED"])
        && one_of(
            state.protection_state,
            &["OPEN", "EXECUTION_REVOKED", "CLOSED", "BREACHED"],
        )
        && one_of(
            state.leader,
            &[
                "ABSENT",
                "TRUSTED_HELD",
                "HOSTILE_RUNNING",
                "EXITED",
                "REAPED",
            ],
        )
        && one_of(state.descendants, &["NONE", "LIVE", "EXITED"])
        && state.descendant_drained_generation <= state.descendant_generation
        && state.descendant_generation <= MAX_REACQUISITIONS
        && one_of(state.async_refs, &["NONE", "LIVE", "DRAINED"])
        && state.async_drained_generation <= state.async_generation
        && state.async_generation <= MAX_REACQUISITIONS
        && one_of(state.hidden_work, &["NONE", "ACTIVE", "PENDING", "DRAINED"])
        && one_of(state.sandbox, &["UNVERIFIED", "REQUESTED", "ATTESTED"])
        && one_of(state.payload, &["HELD", "RELEASED"])
        && one_of(
            state.writer_confinement,
            &["UNVERIFIED", "CONFINED", "CLOSED"],
        )
        && one_of(
            state.stream,
            &[
                "UNOPENED",
                "OPEN",
                "FRAME",
                "EOF_VALID",
                "EOF_TRUNCATED",
                "EOF_INVALID",
            ],
        )
        && one_of(
            state.candidate_kind,
            &[
                "NONE",
                "PRODUCER_RESULT",
                "CHECKER_ACCEPT",
                "CHECKER_REJECT",
                "INTERNAL",
            ],
        )
        && one_of(
            state.candidate_value,
            &["NONE", "VALUE_A", "VALUE_B", "ACCEPT", "REJECT", "INTERNAL"],
        )
        && one_of(state.wait, &["NONE", "NORMAL", "SIGNALLED", "ABNORMAL"])
        && one_of(
            state.resource_event,
            &["NONE", "MONITOR_PROVED", "LINUX_UNATTRIBUTED"],
        )
        && one_of(state.enforcement, &["NONE", "TERMINATION_REQUESTED"])
        && one_of(state.winner, &["OPEN", "COMPLETION", "QUOTA", "FAULT"])
        && one_of(state.counters, &["NONE", "BASELINE", "FINAL", "FAILED"])
        && one_of(state.fault, &["CLEAN", "STICKY"])
        && one_of(
            state.fault_cause,
            &[
                "NONE",
                "PRIMARY_RUNTIME_FAILOVER",
                "INTERNAL_FRAME",
                "STREAM_TRUNCATED",
                "STREAM_INVALID",
                "HOSTILE_REJECTION",
                "HOSTILE_BYPASS",
                "OWNER_REVOCATION",
                "LINUX_LIMIT",
                "ABNORMAL_EXIT",
                "FINAL_COUNTER_FAILURE",
            ],
        )
        && state.fault_cause_receipt_sequence <= state.evidence_receipts.len() as u64
        && pending_attack(state.pending_attack)
        && state.attack_attempts.len() <= MAX_HOSTILE_ATTEMPTS
        && state.attack_rejections.len() <= state.attack_attempts.len()
        && state
            .attack_attempts
            .iter()
            .all(|attack| *attack != "NONE" && pending_attack(attack))
        && state
            .attack_rejections
            .iter()
            .all(|attack| *attack != "NONE" && pending_attack(attack))
        && pending_attack(state.breach_kind)
        && one_of(state.evidence_ledger, &["OPEN", "SEALED"])
        && one_of(
            state.local_decision,
            &[
                "NONE",
                "LOCAL_SYNTACTIC_CANDIDATE",
                "INCONCLUSIVE_RESOURCE",
                "INTERNAL_FAILURE",
                "ABANDONED",
            ],
        )
        && evidence_wf(state)
        && recovery_wf(state)
        && decision_receipt_wf(state))
    {
        return false;
    }

    if state.primary_state == "ACTIVE" && state.controller != "PRIMARY_SUPERVISOR" {
        return false;
    }
    if state.primary_state == "FAILED" && state.controller != "RECOVERY_GUARDIAN" {
        return false;
    }
    if (state.phase == "BREACHED")
        != (state.protection_state == "BREACHED" && state.breach_kind != "NONE")
    {
        return false;
    }
    if state.pending_attack != "NONE" {
        if !(state.attack_attempts.len() == state.attack_rejections.len() + 1
            && state.attack_attempts.last().copied() == Some(state.pending_attack)
            && state.breach_kind == "NONE"
            && state.evidence_ledger == "OPEN")
        {
            return false;
        }
    } else if state.phase == "BREACHED" {
        if !(state.attack_attempts.len() == state.attack_rejections.len() + 1
            && state.attack_attempts.last().copied() == Some(state.breach_kind))
        {
            return false;
        }
    } else if state.attack_attempts != state.attack_rejections {
        return false;
    }
    if state.breach_kind != "NONE"
        && (state.pending_attack != "NONE"
            || state.fault != "STICKY"
            || state.evidence_ledger != "OPEN"
            || state.local_decision != "NONE")
    {
        return false;
    }
    if !state.attack_rejections.is_empty() && state.fault != "STICKY" {
        return false;
    }
    if state.owner_state == "REVOKED" && state.fault != "STICKY" {
        return false;
    }

    let receipts = chronological_receipts(state);
    let counts = count_map(&receipts);
    if state.primary_state == "ACTIVE" {
        if map_present(&counts, "PRIMARY_FAILOVER") || !state.recovery_receipts.is_empty() {
            return false;
        }
    } else if state.evidence_ledger == "OPEN" && !map_present(&counts, "PRIMARY_FAILOVER") {
        return false;
    }

    let setup_shape_ok = match state.phase {
        "NEW" => {
            state.scope == "UNCREATED"
                && state.visible_population == "UNKNOWN"
                && state.task_population == "UNKNOWN"
                && state.attach_authority == "UNBOUND"
                && state.async_admission == "UNBOUND"
                && state.execution_authority == "UNBOUND"
                && state.leader == "ABSENT"
                && state.sandbox == "UNVERIFIED"
                && state.payload == "HELD"
                && state.counters == "NONE"
        }
        "SCOPE_REQUESTED" => {
            state.scope == "REQUESTED"
                && state.visible_population == "UNKNOWN"
                && state.task_population == "UNKNOWN"
        }
        "SCOPE_CONFIGURED" => {
            state.scope == "CONFIGURED_EMPTY"
                && state.visible_population == "EMPTY"
                && state.task_population == "EMPTY"
                && state.attach_authority == "EXTERNAL_EXCLUSIVE"
                && state.async_admission == "OPEN"
        }
        "BOOTSTRAP_REQUESTED" => state.scope == "CONFIGURED_EMPTY" && state.leader == "ABSENT",
        "BOOTSTRAP_HELD" => {
            state.scope == "LIVE"
                && state.visible_population == "NONEMPTY"
                && state.task_population == "NONEMPTY"
                && state.leader == "TRUSTED_HELD"
                && one_of(state.execution_authority, &["UNBOUND", "ACTIVE"])
                && state.sandbox == "UNVERIFIED"
        }
        "SANDBOX_REQUESTED" => {
            state.scope == "LIVE"
                && state.visible_population == "NONEMPTY"
                && state.task_population == "NONEMPTY"
                && state.leader == "TRUSTED_HELD"
                && state.sandbox == "REQUESTED"
        }
        "READY" => {
            state.scope == "LIVE"
                && state.visible_population == "NONEMPTY"
                && state.task_population == "NONEMPTY"
                && state.leader == "TRUSTED_HELD"
                && state.sandbox == "ATTESTED"
                && state.payload == "HELD"
                && one_of(state.counters, &["NONE", "BASELINE"])
        }
        "RUNNING" => {
            state.scope == "LIVE"
                && state.visible_population == "NONEMPTY"
                && state.task_population == "NONEMPTY"
                && state.leader == "HOSTILE_RUNNING"
                && state.payload == "RELEASED"
                && state.sandbox == "ATTESTED"
                && state.wait == "NONE"
                && state.winner == "OPEN"
                && state.fault == "CLEAN"
                && state.owner_state == "ACTIVE"
        }
        _ => true,
    };
    if !setup_shape_ok {
        return false;
    }
    if one_of(
        state.phase,
        &["STOPPING", "QUIESCENT", "DECIDED", "BREACHED"],
    ) && state.payload != "RELEASED"
    {
        return false;
    }
    if state.phase == "STOPPING" {
        let stopping_started = state.fault == "STICKY"
            || state.wait != "NONE"
            || state.winner != "OPEN"
            || state.owner_state == "REVOKED"
            || state.execution_authority == "REVOKED"
            || one_of(
                state.scope,
                &["ATTACH_CLOSED", "HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"],
            );
        if !stopping_started || state.evidence_ledger != "OPEN" {
            return false;
        }
    }

    for (kind, expected) in [
        ("SCOPE_REQUESTED", state.scope != "UNCREATED"),
        (
            "SCOPE_CONFIGURED_ACK",
            !one_of(state.scope, &["UNCREATED", "REQUESTED"]),
        ),
        (
            "BOOTSTRAP_REQUESTED",
            state.phase == "BOOTSTRAP_REQUESTED" || state.leader != "ABSENT",
        ),
        ("CHARGED_BOOTSTRAP_ACK", state.leader != "ABSENT"),
        (
            "MONITOR_EXECUTION_ACTIVATED_ACK",
            one_of(state.execution_authority, &["ACTIVE", "REVOKED"]),
        ),
        ("SANDBOX_REQUESTED", state.sandbox != "UNVERIFIED"),
        ("SANDBOX_PROFILE_ACK", state.sandbox == "ATTESTED"),
        ("BASELINE_COUNTERS", state.counters != "NONE"),
        ("HOSTILE_PAYLOAD_RELEASED", state.payload == "RELEASED"),
    ] {
        if map_present(&counts, kind) != expected {
            return false;
        }
    }

    for (kind, expected) in [
        (
            "RMDIR_ATTACH_CLOSED_ACK",
            one_of(
                state.scope,
                &["ATTACH_CLOSED", "HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"],
            ),
        ),
        ("ASYNC_ADMISSION_CLOSED", state.async_admission == "CLOSED"),
        (
            "EXECUTION_REVOKED_ACK",
            state.execution_authority == "REVOKED",
        ),
        (
            "MONITOR_PROTECTION_CLOSED_ACK",
            state.protection_state == "CLOSED",
        ),
        (
            "TASK_POPULATION_ZERO_ACK",
            state.payload == "RELEASED" && state.task_population == "EMPTY",
        ),
        (
            "HIDDEN_WORK_DRAINED_ACK",
            one_of(state.scope, &["HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"]),
        ),
        (
            "CSS_OFFLINE_ACK",
            one_of(state.scope, &["CSS_OFFLINE", "RELEASED"]),
        ),
        ("SCOPE_RELEASED_ACK", state.scope == "RELEASED"),
    ] {
        if map_present(&counts, kind) != expected {
            return false;
        }
    }
    if map_count(&counts, "VISIBLE_EMPTY_ACK") as u64 != state.visible_empty_observations {
        return false;
    }
    if state.payload == "RELEASED"
        && state.visible_population == "EMPTY"
        && state.visible_empty_observations == 0
    {
        return false;
    }

    for (kind, expected) in [
        ("UNTRUSTED_FRAME_OBSERVED", state.candidate_kind != "NONE"),
        ("STREAM_EOF_VALID", state.stream == "EOF_VALID"),
        ("STREAM_EOF_TRUNCATED", state.stream == "EOF_TRUNCATED"),
        ("STREAM_EOF_INVALID", state.stream == "EOF_INVALID"),
        ("OWNER_REVOKED", state.owner_state == "REVOKED"),
        ("WAIT_NORMAL", state.wait == "NORMAL"),
        ("WAIT_SIGNALLED", state.wait == "SIGNALLED"),
        ("WAIT_ABNORMAL", state.wait == "ABNORMAL"),
        ("LEADER_REAPED", state.leader == "REAPED"),
        (
            "LINUX_LIMIT_UNATTRIBUTED",
            state.resource_event == "LINUX_UNATTRIBUTED",
        ),
        (
            "TERMINATION_REQUESTED",
            state.enforcement == "TERMINATION_REQUESTED",
        ),
        ("FINAL_COUNTERS", state.counters == "FINAL"),
        ("FINAL_COUNTERS_FAILED", state.counters == "FAILED"),
        ("MONITOR_QUOTA_ARRIVED", state.quota_arrival_sequence > 0),
        ("COMPLETION_ARRIVED", state.completion_arrival_sequence > 0),
        ("EVIDENCE_SEAL", state.evidence_ledger == "SEALED"),
    ] {
        if map_present(&counts, kind) != expected {
            return false;
        }
    }
    if map_present(&counts, "PRIMARY_FAILOVER") && state.primary_state != "FAILED" {
        return false;
    }
    let required_stage = match state.phase {
        "SCOPE_REQUESTED" => Some("SCOPE_REQUESTED"),
        "SCOPE_CONFIGURED" => Some("SCOPE_CONFIGURED_ACK"),
        "BOOTSTRAP_REQUESTED" => Some("BOOTSTRAP_REQUESTED"),
        "BOOTSTRAP_HELD" => Some("CHARGED_BOOTSTRAP_ACK"),
        "SANDBOX_REQUESTED" => Some("SANDBOX_REQUESTED"),
        "READY" => Some("SANDBOX_PROFILE_ACK"),
        "RUNNING" => Some("HOSTILE_PAYLOAD_RELEASED"),
        _ => None,
    };
    if required_stage
        .map(|kind| !map_present(&counts, kind))
        .unwrap_or(false)
    {
        return false;
    }

    if state.scope != "UNCREATED" && !map_present(&counts, "SCOPE_REQUESTED") {
        return false;
    }
    if !one_of(state.scope, &["UNCREATED", "REQUESTED"])
        && !map_present(&counts, "SCOPE_CONFIGURED_ACK")
    {
        return false;
    }
    if state.attach_authority == "EXTERNAL_EXCLUSIVE"
        && one_of(state.scope, &["UNCREATED", "REQUESTED"])
    {
        return false;
    }
    if state.attach_authority == "CLOSED"
        && !one_of(
            state.scope,
            &["ATTACH_CLOSED", "HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"],
        )
    {
        return false;
    }
    if one_of(
        state.scope,
        &["ATTACH_CLOSED", "HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"],
    ) && state.visible_population != "EMPTY"
    {
        return false;
    }
    if one_of(state.scope, &["HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"])
        && state.hidden_work != "DRAINED"
    {
        return false;
    }
    if one_of(state.scope, &["CSS_OFFLINE", "RELEASED"])
        && !one_of(state.counters, &["FINAL", "FAILED"])
    {
        return false;
    }
    if state.scope == "RELEASED" && state.attach_authority != "CLOSED" {
        return false;
    }
    if one_of(state.scope, &["HIDDEN_DRAINED", "CSS_OFFLINE", "RELEASED"])
        && !(state.task_population == "EMPTY"
            && state.async_admission == "CLOSED"
            && state.protection_state == "CLOSED")
    {
        return false;
    }
    match state.protection_state {
        "OPEN" if state.execution_authority == "REVOKED" => return false,
        "EXECUTION_REVOKED" if state.execution_authority != "REVOKED" => return false,
        "CLOSED"
            if !(state.execution_authority == "REVOKED"
                && state.attach_authority == "CLOSED"
                && state.async_admission == "CLOSED") =>
        {
            return false
        }
        _ => {}
    }
    if state.execution_authority == "ACTIVE" && state.leader == "ABSENT" {
        return false;
    }
    if state.async_admission == "UNBOUND" && !one_of(state.scope, &["UNCREATED", "REQUESTED"]) {
        return false;
    }

    if state.descendant_generation == 0 {
        if state.descendants != "NONE" || state.descendant_drained_generation != 0 {
            return false;
        }
    } else if state.descendants == "LIVE" {
        if state.descendant_generation <= state.descendant_drained_generation {
            return false;
        }
    } else if state.descendants == "EXITED" {
        if state.descendant_generation != state.descendant_drained_generation {
            return false;
        }
    } else {
        return false;
    }
    if map_count(&counts, "DESCENDANTS_EXITED") as u64 != state.descendant_drained_generation {
        return false;
    }

    if state.async_generation == 0 {
        if state.async_refs != "NONE" || state.async_drained_generation != 0 {
            return false;
        }
    } else if state.async_refs == "LIVE" {
        if state.async_generation <= state.async_drained_generation {
            return false;
        }
    } else if state.async_refs == "DRAINED" {
        if state.async_generation != state.async_drained_generation {
            return false;
        }
    } else {
        return false;
    }
    if map_count(&counts, "ASYNC_REFS_DRAINED") as u64 != state.async_drained_generation {
        return false;
    }

    if one_of(
        state.leader,
        &["TRUSTED_HELD", "HOSTILE_RUNNING", "EXITED", "REAPED"],
    ) && !map_present(&counts, "CHARGED_BOOTSTRAP_ACK")
    {
        return false;
    }
    if state.leader == "HOSTILE_RUNNING" && state.payload != "RELEASED" {
        return false;
    }
    if state.wait != "NONE" && !one_of(state.leader, &["EXITED", "REAPED"]) {
        return false;
    }
    if state.leader == "REAPED" && (state.wait == "NONE" || !map_present(&counts, "LEADER_REAPED"))
    {
        return false;
    }
    if state.descendants == "LIVE"
        && !one_of(state.leader, &["HOSTILE_RUNNING", "EXITED", "REAPED"])
    {
        return false;
    }
    if state.descendants == "EXITED" && !map_present(&counts, "DESCENDANTS_EXITED") {
        return false;
    }
    if state.async_refs == "LIVE" && state.payload != "RELEASED" {
        return false;
    }
    if state.async_refs == "DRAINED" && !map_present(&counts, "ASYNC_REFS_DRAINED") {
        return false;
    }

    if state.sandbox == "ATTESTED" && !map_present(&counts, "SANDBOX_PROFILE_ACK") {
        return false;
    }
    if state.payload == "RELEASED"
        && !(state.sandbox == "ATTESTED"
            && one_of(state.counters, &["BASELINE", "FINAL", "FAILED"])
            && [
                "HOSTILE_PAYLOAD_RELEASED",
                "SCOPE_REQUESTED",
                "SCOPE_CONFIGURED_ACK",
                "BOOTSTRAP_REQUESTED",
                "CHARGED_BOOTSTRAP_ACK",
                "SANDBOX_REQUESTED",
                "SANDBOX_PROFILE_ACK",
                "BASELINE_COUNTERS",
            ]
            .iter()
            .all(|kind| map_present(&counts, kind)))
    {
        return false;
    }
    if state.writer_confinement == "CONFINED" && state.sandbox != "ATTESTED" {
        return false;
    }
    if state.writer_confinement == "CLOSED"
        && !one_of(state.stream, &["EOF_VALID", "EOF_TRUNCATED", "EOF_INVALID"])
    {
        return false;
    }

    if state.candidate_kind == "NONE"
        && (state.candidate_value != "NONE" || !state.candidate_digest.is_empty())
    {
        return false;
    }
    if state.candidate_kind != "NONE" {
        if !one_of(state.stream, &["FRAME", "EOF_VALID", "EOF_INVALID"]) {
            return false;
        }
        let value_ok = match state.candidate_kind {
            "PRODUCER_RESULT" => one_of(state.candidate_value, &["VALUE_A", "VALUE_B"]),
            "CHECKER_ACCEPT" => state.candidate_value == "ACCEPT",
            "CHECKER_REJECT" => state.candidate_value == "REJECT",
            "INTERNAL" => state.candidate_value == "INTERNAL",
            _ => false,
        };
        if !value_ok
            || state.candidate_digest
                != expected_candidate_digest(state, state.candidate_kind, state.candidate_value)
        {
            return false;
        }
        if state.grant.role == "PRODUCER"
            && !one_of(state.candidate_kind, &["PRODUCER_RESULT", "INTERNAL"])
        {
            return false;
        }
        if state.grant.role == "CHECKER"
            && !one_of(
                state.candidate_kind,
                &["CHECKER_ACCEPT", "CHECKER_REJECT", "INTERNAL"],
            )
        {
            return false;
        }
        if !map_present(&counts, "UNTRUSTED_FRAME_OBSERVED") {
            return false;
        }
    }
    if state.stream == "FRAME" && !map_present(&counts, "UNTRUSTED_FRAME_OBSERVED") {
        return false;
    }
    if state.stream == "EOF_VALID"
        && (one_of(state.candidate_kind, &["NONE", "INTERNAL"])
            || !map_present(&counts, "STREAM_EOF_VALID"))
    {
        return false;
    }
    if state.stream == "EOF_TRUNCATED" && !map_present(&counts, "STREAM_EOF_TRUNCATED") {
        return false;
    }
    if state.stream == "EOF_INVALID" && !map_present(&counts, "STREAM_EOF_INVALID") {
        return false;
    }
    if one_of(state.stream, &["EOF_TRUNCATED", "EOF_INVALID"]) && state.fault != "STICKY" {
        return false;
    }
    let wait_kind = match state.wait {
        "NORMAL" => Some("WAIT_NORMAL"),
        "SIGNALLED" => Some("WAIT_SIGNALLED"),
        "ABNORMAL" => Some("WAIT_ABNORMAL"),
        _ => None,
    };
    if wait_kind
        .map(|kind| !map_present(&counts, kind))
        .unwrap_or(false)
    {
        return false;
    }

    for (kind, expected) in [
        ("COMPLETION_LINEARIZED", state.winner == "COMPLETION"),
        ("QUOTA_LINEARIZED", state.winner == "QUOTA"),
        ("FAULT_LINEARIZED", state.winner == "FAULT"),
    ] {
        if map_present(&counts, kind) != expected {
            return false;
        }
    }
    let arrivals = [
        ("COMPLETION", state.completion_arrival_sequence),
        ("QUOTA", state.quota_arrival_sequence),
        ("FAULT", state.fault_arrival_sequence),
    ];
    let mut nonzero_arrivals: Vec<u64> = arrivals
        .iter()
        .map(|(_, sequence)| *sequence)
        .filter(|sequence| *sequence > 0)
        .collect();
    let mut unique_arrivals = nonzero_arrivals.clone();
    unique_arrivals.sort_unstable();
    unique_arrivals.dedup();
    nonzero_arrivals.sort_unstable();
    if unique_arrivals.len() != nonzero_arrivals.len()
        || u64::try_from(nonzero_arrivals.len()).ok() != Some(state.event_clock)
        || nonzero_arrivals
            .iter()
            .enumerate()
            .any(|(index, sequence)| *sequence != index as u64 + 1)
    {
        return false;
    }
    if (state.quota_arrival_sequence > 0) != (state.resource_event == "MONITOR_PROVED")
        || (state.fault_arrival_sequence > 0) != (state.fault == "STICKY")
    {
        return false;
    }
    let mut receipt_backed_arrivals = Vec::new();
    if state.completion_arrival_sequence > 0 {
        let Some(receipt) = receipts
            .iter()
            .find(|receipt| receipt.kind == "COMPLETION_ARRIVED")
        else {
            return false;
        };
        receipt_backed_arrivals.push((receipt.sequence, state.completion_arrival_sequence));
    }
    if state.quota_arrival_sequence > 0 {
        let Some(receipt) = receipts
            .iter()
            .find(|receipt| receipt.kind == "MONITOR_QUOTA_ARRIVED")
        else {
            return false;
        };
        receipt_backed_arrivals.push((receipt.sequence, state.quota_arrival_sequence));
    }
    if state.fault_arrival_sequence > 0 && state.fault_cause_receipt_sequence > 0 {
        receipt_backed_arrivals.push((
            state.fault_cause_receipt_sequence,
            state.fault_arrival_sequence,
        ));
    }
    for left in 0..receipt_backed_arrivals.len() {
        for right in left + 1..receipt_backed_arrivals.len() {
            let (left_receipt, left_arrival) = receipt_backed_arrivals[left];
            let (right_receipt, right_arrival) = receipt_backed_arrivals[right];
            if (left_receipt < right_receipt) != (left_arrival < right_arrival) {
                return false;
            }
        }
    }
    if state.completion_arrival_sequence > 0 {
        let kind_ok = if state.grant.role == "PRODUCER" {
            state.candidate_kind == "PRODUCER_RESULT"
        } else {
            one_of(state.candidate_kind, &["CHECKER_ACCEPT", "CHECKER_REJECT"])
        };
        if !(state.wait == "NORMAL"
            && state.stream == "EOF_VALID"
            && kind_ok
            && map_count(&counts, "COMPLETION_ARRIVED") == 1)
        {
            return false;
        }
    }
    if state.winner == "OPEN" {
        if state.winner_sequence != 0 {
            return false;
        }
    } else {
        let winner_kind = match state.winner {
            "COMPLETION" => "COMPLETION_LINEARIZED",
            "QUOTA" => "QUOTA_LINEARIZED",
            "FAULT" => "FAULT_LINEARIZED",
            _ => return false,
        };
        let matching: Vec<&Receipt> = receipts
            .iter()
            .copied()
            .filter(|receipt| receipt.kind == winner_kind)
            .collect();
        let winner_arrival = arrivals
            .iter()
            .find(|(winner, _)| *winner == state.winner)
            .unwrap()
            .1;
        if matching.len() != 1
            || state.winner_sequence != matching[0].sequence
            || winner_arrival == 0
            || nonzero_arrivals.first().copied() != Some(winner_arrival)
        {
            return false;
        }
    }

    if state.resource_event == "MONITOR_PROVED"
        && state.resource_observed_value <= state.grant.budget_limit
    {
        return false;
    }
    if state.resource_event == "LINUX_UNATTRIBUTED" && state.fault != "STICKY" {
        return false;
    }
    if state.resource_event == "NONE" && state.resource_observed_value != 0 {
        return false;
    }
    if state.resource_event == "MONITOR_PROVED" && !map_present(&counts, "MONITOR_QUOTA_ARRIVED") {
        return false;
    }
    if state.resource_event == "LINUX_UNATTRIBUTED"
        && !map_present(&counts, "LINUX_LIMIT_UNATTRIBUTED")
    {
        return false;
    }
    if state.enforcement == "TERMINATION_REQUESTED"
        && !map_present(&counts, "TERMINATION_REQUESTED")
    {
        return false;
    }
    if state.owner_state == "REVOKED" && !map_present(&counts, "OWNER_REVOKED") {
        return false;
    }
    if state.primary_state == "FAILED" && state.recovery_receipts.is_empty() {
        return false;
    }

    if state.counters == "NONE" && state.baseline_value != 0 {
        return false;
    }
    if one_of(state.counters, &["BASELINE", "FINAL", "FAILED"])
        && !map_present(&counts, "BASELINE_COUNTERS")
    {
        return false;
    }
    if state.counters == "FINAL" && state.final_value < state.baseline_value {
        return false;
    }
    if state.counters == "FINAL"
        && state.resource_event == "MONITOR_PROVED"
        && state.final_value < state.resource_observed_value
    {
        return false;
    }
    if state.counters == "FINAL"
        && state.final_value > state.grant.budget_limit
        && state.resource_event != "MONITOR_PROVED"
    {
        return false;
    }
    if state.counters == "FINAL" && !map_present(&counts, "FINAL_COUNTERS") {
        return false;
    }
    if state.counters == "FAILED"
        && (state.fault != "STICKY" || !map_present(&counts, "FINAL_COUNTERS_FAILED"))
    {
        return false;
    }

    if state.evidence_ledger == "SEALED"
        && (!one_of(state.phase, &["QUIESCENT", "DECIDED"]) || !closure_ready(state))
    {
        return false;
    }
    if one_of(state.phase, &["QUIESCENT", "DECIDED"])
        && (state.evidence_ledger != "SEALED" || !closure_ready(state))
    {
        return false;
    }
    if state.phase == "QUIESCENT" && state.local_decision != "NONE" {
        return false;
    }
    if state.phase == "DECIDED" {
        if state.local_decision == "NONE" || state.local_decision != expected_local_decision(state)
        {
            return false;
        }
    } else if state.local_decision != "NONE" {
        return false;
    }
    true
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use super::{evidence_wf, instance_wf};
    use crate::model::{bounded_wf_prefix, fixture_external_grant, next_states, State};

    fn apply(mut state: State, action_id: &str) -> State {
        let mut matching = next_states(&state)
            .into_iter()
            .filter(|edge| edge.action_id == action_id);
        state = matching
            .next()
            .unwrap_or_else(|| panic!("action not enabled: {action_id}"))
            .state;
        assert!(matching.next().is_none(), "action not unique: {action_id}");
        state
    }

    fn running(role: &'static str) -> State {
        let mut state = State::initial(fixture_external_grant(role));
        for action in [
            "SUP-001-REQUEST-SCOPE",
            "OBS-002-CONFIGURE-SCOPE-ACK",
            "SUP-003-REQUEST-CHARGED-BOOTSTRAP",
            "OBS-004-CHARGED-BOOTSTRAP-ACK",
            "MON-004B-ACTIVATE-EXECUTION",
            "SUP-005-REQUEST-SANDBOX",
            "OBS-006-SANDBOX-PROFILE-ACK",
            "MON-007-BASELINE-COUNTERS",
            "SUP-008-RELEASE-HOSTILE-PAYLOAD",
        ] {
            state = apply(state, action);
        }
        state
    }

    #[test]
    fn independent_wf_accepts_bounded_reachable_states() {
        for role in ["PRODUCER", "CHECKER"] {
            let stats = bounded_wf_prefix(role, 250);
            assert_eq!(stats.expanded, 250);
            assert_eq!(stats.wf_checks, stats.edge_count + 1);
            assert!(stats.state_count > stats.expanded);
        }
    }

    #[test]
    fn independent_wf_rejects_structural_mutations() {
        let initial = State::initial(fixture_external_grant("PRODUCER"));
        assert!(evidence_wf(&initial));
        assert!(instance_wf(&initial));

        let mut invalid = initial.clone();
        invalid.phase = "STOPPING";
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.controller = "RECOVERY_GUARDIAN";
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.visible_empty_observations = 4;
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.visible_empty_observations = u64::MAX;
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.descendant_drained_generation = u64::MAX;
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.async_drained_generation = u64::MAX;
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        invalid.event_clock = u64::MAX;
        assert!(!instance_wf(&invalid));

        let mut invalid = initial.clone();
        let mut grant = (*invalid.grant).clone();
        grant.auth_tag = "forged".to_owned();
        invalid.grant = Arc::new(grant);
        assert!(!instance_wf(&invalid));

        let first = apply(initial.clone(), "SUP-001-REQUEST-SCOPE");
        let mut invalid = first.clone();
        let tail = invalid
            .evidence_receipts
            .tail
            .as_mut()
            .expect("first receipt absent");
        Arc::make_mut(tail).receipt.auth_tag = "forged".to_owned();
        assert!(!evidence_wf(&invalid));
        assert!(!instance_wf(&invalid));

        let mut invalid = first.clone();
        let duplicate = invalid
            .evidence_receipts
            .last()
            .expect("first receipt absent")
            .clone();
        invalid.evidence_receipts.push(duplicate);
        assert!(!evidence_wf(&invalid));
        assert!(!instance_wf(&invalid));

        let running = running("PRODUCER");
        assert!(instance_wf(&running));
        let mut invalid = running.clone();
        invalid.phase = "NEW";
        assert!(!instance_wf(&invalid));

        let mut invalid = running.clone();
        invalid.stream = "FRAME";
        invalid.candidate_kind = "PRODUCER_RESULT";
        invalid.candidate_value = "VALUE_A";
        invalid.candidate_digest =
            crate::model::expected_candidate_digest(&invalid, "PRODUCER_RESULT", "VALUE_A");
        assert!(!instance_wf(&invalid));

        let mut invalid = running.clone();
        invalid.winner = "COMPLETION";
        invalid.winner_sequence = 1;
        assert!(!instance_wf(&invalid));

        let mut invalid = running;
        invalid.scope = "RELEASED";
        invalid.attach_authority = "CLOSED";
        assert!(!instance_wf(&invalid));
    }
}
