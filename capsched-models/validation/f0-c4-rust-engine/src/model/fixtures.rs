//! Bounded exact-state transport for named hostile well-formedness fixtures.

use std::collections::BTreeSet;
use std::fs::File;
use std::io::Read;

use crate::canonical;
use crate::decode::{self, Value};

use super::{wf, DecisionReceipt, Receipt, ReceiptHistory, RecoveryReceipt, RunGrant, State};

const FIXTURE_HEADER: &str = "F0_C4_RUST_HOSTILE_WF_FIXTURES_V1";
const RESULT_HEADER: &str = "F0_C4_RUST_HOSTILE_WF_RESULTS_V1";
const MAX_FIXTURE_BYTES: u64 = 32 * 1024 * 1024;
const MAX_CASES: usize = 4_096;
const MAX_ATOM_BYTES: usize = 256;

enum Fixture {
    Grant { id_hex: String, grant: RunGrant },
    State { id_hex: String, state: State },
}

pub(super) fn emit_results(path: &str) {
    let fixtures =
        parse_file(path).unwrap_or_else(|error| panic!("hostile fixture error: {error}"));
    let mut output = format!("{RESULT_HEADER}\t{}\n", fixtures.len());
    for fixture in fixtures {
        match fixture {
            Fixture::Grant { id_hex, grant } => {
                output.push_str(&format!("R\t{id_hex}\tG\t{}\n", bit(wf::grant_wf(&grant))));
            }
            Fixture::State { id_hex, state } => {
                output.push_str(&format!(
                    "R\t{id_hex}\tS\t{}\t{}\n",
                    bit(wf::evidence_wf(&state)),
                    bit(wf::instance_wf(&state))
                ));
            }
        }
    }
    print!("{output}");
}

fn bit(value: bool) -> u8 {
    u8::from(value)
}

fn parse_file(path: &str) -> Result<Vec<Fixture>, String> {
    let mut file = File::open(path).map_err(|error| format!("open: {error}"))?;
    let metadata = file
        .metadata()
        .map_err(|error| format!("metadata: {error}"))?;
    if !metadata.is_file() || metadata.len() > MAX_FIXTURE_BYTES {
        return Err("fixture must be a bounded regular file".to_owned());
    }
    let mut bytes = Vec::with_capacity(metadata.len() as usize);
    file.by_ref()
        .take(MAX_FIXTURE_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| format!("read: {error}"))?;
    if bytes.len() as u64 != metadata.len() || !bytes.ends_with(b"\n") || bytes.contains(&b'\r') {
        return Err("fixture changed while read or lacks final newline".to_owned());
    }
    let text = std::str::from_utf8(&bytes).map_err(|_| "fixture is not UTF-8".to_owned())?;
    let mut lines = text.lines();
    let header = lines
        .next()
        .ok_or_else(|| "fixture header absent".to_owned())?;
    let header_fields: Vec<&str> = header.split('\t').collect();
    if header_fields.len() != 2 || header_fields[0] != FIXTURE_HEADER {
        return Err("fixture header differs".to_owned());
    }
    let declared = parse_count(header_fields[1], "fixture count")?;
    if declared == 0 || declared > MAX_CASES {
        return Err("fixture count outside bound".to_owned());
    }

    let mut ids = BTreeSet::new();
    let mut fixtures = Vec::with_capacity(declared);
    for (offset, line) in lines.enumerate() {
        let line_number = offset + 2;
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 3 || !matches!(fields[0], "G" | "S") {
            return Err(format!("line {line_number}: fixture record differs"));
        }
        let id = decode_hex(fields[1])?;
        if id.is_empty()
            || id.len() > 160
            || !id.iter().all(|value| {
                value.is_ascii_lowercase() || value.is_ascii_digit() || b"._-".contains(value)
            })
            || canonical::hex(&id) != fields[1]
        {
            return Err(format!("line {line_number}: invalid canonical case id"));
        }
        if !ids.insert(id) {
            return Err(format!("line {line_number}: duplicate case id"));
        }
        let encoded = decode_hex(fields[2])?;
        if canonical::hex(&encoded) != fields[2] {
            return Err(format!(
                "line {line_number}: payload hex is not canonical lowercase"
            ));
        }
        let value =
            decode::exact(&encoded).map_err(|error| format!("line {line_number}: {error}"))?;
        let id_hex = fields[1].to_owned();
        fixtures.push(match fields[0] {
            "G" => Fixture::Grant {
                id_hex,
                grant: parse_grant(value, "grant")?,
            },
            "S" => Fixture::State {
                id_hex,
                state: parse_state(value)?,
            },
            _ => unreachable!(),
        });
    }
    if fixtures.len() != declared {
        return Err(format!(
            "fixture count differs: declared={declared} actual={}",
            fixtures.len()
        ));
    }
    Ok(fixtures)
}

fn parse_count(value: &str, context: &str) -> Result<usize, String> {
    if value.is_empty()
        || value.bytes().any(|byte| !byte.is_ascii_digit())
        || (value.len() > 1 && value.starts_with('0'))
    {
        return Err(format!("{context}: non-canonical integer"));
    }
    value
        .parse()
        .map_err(|_| format!("{context}: integer exceeds usize"))
}

fn decode_hex(value: &str) -> Result<Vec<u8>, String> {
    if value.len() % 2 != 0 || value.bytes().any(|byte| !byte.is_ascii_hexdigit()) {
        return Err("non-hex fixture field".to_owned());
    }
    let mut output = Vec::with_capacity(value.len() / 2);
    for pair in value.as_bytes().chunks_exact(2) {
        output.push((hex_nibble(pair[0])? << 4) | hex_nibble(pair[1])?);
    }
    Ok(output)
}

fn hex_nibble(value: u8) -> Result<u8, String> {
    match value {
        b'0'..=b'9' => Ok(value - b'0'),
        b'a'..=b'f' => Ok(value - b'a' + 10),
        b'A'..=b'F' => Ok(value - b'A' + 10),
        _ => Err("invalid hex digit".to_owned()),
    }
}

struct Fields {
    values: std::vec::IntoIter<Value>,
    context: String,
}

impl Fields {
    fn exact(value: Value, count: usize, context: &str) -> Result<Self, String> {
        let values = value.into_tuple(context)?;
        if values.len() != count {
            return Err(format!(
                "{context}: field count differs: expected={count} actual={}",
                values.len()
            ));
        }
        Ok(Self {
            values: values.into_iter(),
            context: context.to_owned(),
        })
    }

    fn next(&mut self, name: &str) -> Result<Value, String> {
        self.values
            .next()
            .ok_or_else(|| format!("{}.{}: absent", self.context, name))
    }

    fn string(&mut self, name: &str) -> Result<String, String> {
        self.next(name)?
            .into_string(&format!("{}.{}", self.context, name))
    }

    fn integer(&mut self, name: &str) -> Result<u64, String> {
        self.next(name)?
            .into_integer(&format!("{}.{}", self.context, name))
    }

    fn atom(&mut self, name: &str) -> Result<&'static str, String> {
        let value = self.string(name)?;
        if value.is_empty() || value.len() > MAX_ATOM_BYTES || !value.is_ascii() {
            return Err(format!("{}.{}: invalid bounded atom", self.context, name));
        }
        // Hostile-fixture processes are short-lived and the complete input is
        // bounded above.  Leaking only enum-like atoms lets the production BFS
        // retain its compact &'static str representation.
        Ok(Box::leak(value.into_boxed_str()))
    }
}

fn parse_grant(value: Value, context: &str) -> Result<RunGrant, String> {
    let mut fields = Fields::exact(value, 17, context)?;
    Ok(RunGrant {
        parent_run_id: fields.string("parent_run_id")?,
        child_run_id: fields.string("child_run_id")?,
        role: fields.atom("role")?,
        ordinal: fields.integer("ordinal")?,
        epoch: fields.integer("epoch")?,
        nonce: fields.string("nonce")?,
        validation_context_digest: fields.string("validation_context_digest")?,
        policy_digest: fields.string("policy_digest")?,
        profile_digest: fields.string("profile_digest")?,
        immutable_input_digest: fields.string("immutable_input_digest")?,
        hierarchy_id: fields.string("hierarchy_id")?,
        scope_id: fields.string("scope_id")?,
        subject_id: fields.string("subject_id")?,
        budget_id: fields.string("budget_id")?,
        budget_limit: fields.integer("budget_limit")?,
        issuer: fields.atom("issuer")?,
        auth_tag: fields.string("auth_tag")?,
    })
}

fn parse_receipt(value: Value, context: &str) -> Result<Receipt, String> {
    let mut fields = Fields::exact(value, 13, context)?;
    Ok(Receipt {
        schema: fields.atom("schema")?,
        run_id: fields.string("run_id")?,
        binding_digest: fields.string("binding_digest")?,
        scope_id: fields.string("scope_id")?,
        subject_id: fields.string("subject_id")?,
        sequence: fields.integer("sequence")?,
        kind: fields.atom("kind")?,
        payload: fields.string("payload")?,
        payload_digest: fields.string("payload_digest")?,
        issuer: fields.atom("issuer")?,
        channel: fields.atom("channel")?,
        previous_hash: fields.string("previous_hash")?,
        auth_tag: fields.string("auth_tag")?,
    })
}

fn parse_decision(value: Value, context: &str) -> Result<DecisionReceipt, String> {
    let mut fields = Fields::exact(value, 9, context)?;
    Ok(DecisionReceipt {
        schema: fields.atom("schema")?,
        run_id: fields.string("run_id")?,
        binding_digest: fields.string("binding_digest")?,
        evidence_root: fields.string("evidence_root")?,
        decision: fields.atom("decision")?,
        payload_kind: fields.atom("payload_kind")?,
        payload_digest: fields.string("payload_digest")?,
        issuer: fields.atom("issuer")?,
        auth_tag: fields.string("auth_tag")?,
    })
}

fn parse_recovery(value: Value, context: &str) -> Result<RecoveryReceipt, String> {
    let mut fields = Fields::exact(value, 11, context)?;
    Ok(RecoveryReceipt {
        schema: fields.atom("schema")?,
        run_id: fields.string("run_id")?,
        binding_digest: fields.string("binding_digest")?,
        sequence: fields.integer("sequence")?,
        observed_phase: fields.atom("observed_phase")?,
        evidence_prefix_hash: fields.string("evidence_prefix_hash")?,
        reason: fields.atom("reason")?,
        failed_controller: fields.atom("failed_controller")?,
        fence_generation: fields.integer("fence_generation")?,
        issuer: fields.atom("issuer")?,
        auth_tag: fields.string("auth_tag")?,
    })
}

fn parse_atoms(value: Value, context: &str) -> Result<Vec<&'static str>, String> {
    let values = value.into_tuple(context)?;
    if values.len() > MAX_CASES {
        return Err(format!("{context}: atom sequence exceeds bound"));
    }
    values
        .into_iter()
        .enumerate()
        .map(|(index, value)| {
            let string = value.into_string(&format!("{context}[{index}]"))?;
            if string.is_empty() || string.len() > MAX_ATOM_BYTES || !string.is_ascii() {
                return Err(format!("{context}[{index}]: invalid bounded atom"));
            }
            Ok(Box::leak(string.into_boxed_str()) as &'static str)
        })
        .collect()
}

fn parse_receipts(value: Value) -> Result<ReceiptHistory, String> {
    let values = value.into_tuple("state.evidence_receipts")?;
    if values.len() > MAX_CASES {
        return Err("state.evidence_receipts: count exceeds bound".to_owned());
    }
    let mut history = ReceiptHistory::default();
    for (index, value) in values.into_iter().enumerate() {
        history.push(parse_receipt(
            value,
            &format!("state.evidence_receipts[{index}]"),
        )?);
    }
    Ok(history)
}

fn parse_recoveries(value: Value) -> Result<Vec<RecoveryReceipt>, String> {
    let values = value.into_tuple("state.recovery_receipts")?;
    if values.len() > MAX_CASES {
        return Err("state.recovery_receipts: count exceeds bound".to_owned());
    }
    values
        .into_iter()
        .enumerate()
        .map(|(index, value)| parse_recovery(value, &format!("state.recovery_receipts[{index}]")))
        .collect()
}

fn parse_state(value: Value) -> Result<State, String> {
    let mut fields = Fields::exact(value, 54, "state")?;
    let grant = parse_grant(fields.next("grant")?, "state.grant")?;
    let phase = fields.atom("phase")?;
    let owner_state = fields.atom("owner_state")?;
    let primary_state = fields.atom("primary_state")?;
    let controller = fields.atom("controller")?;
    let scope = fields.atom("scope")?;
    let visible_population = fields.atom("visible_population")?;
    let visible_empty_observations = fields.integer("visible_empty_observations")?;
    let task_population = fields.atom("task_population")?;
    let attach_authority = fields.atom("attach_authority")?;
    let async_admission = fields.atom("async_admission")?;
    let execution_authority = fields.atom("execution_authority")?;
    let protection_state = fields.atom("protection_state")?;
    let leader = fields.atom("leader")?;
    let descendants = fields.atom("descendants")?;
    let descendant_generation = fields.integer("descendant_generation")?;
    let descendant_drained_generation = fields.integer("descendant_drained_generation")?;
    let async_refs = fields.atom("async_refs")?;
    let async_generation = fields.integer("async_generation")?;
    let async_drained_generation = fields.integer("async_drained_generation")?;
    let hidden_work = fields.atom("hidden_work")?;
    let sandbox = fields.atom("sandbox")?;
    let payload = fields.atom("payload")?;
    let writer_confinement = fields.atom("writer_confinement")?;
    let stream = fields.atom("stream")?;
    let candidate_kind = fields.atom("candidate_kind")?;
    let candidate_value = fields.atom("candidate_value")?;
    let candidate_digest = fields.string("candidate_digest")?;
    let wait = fields.atom("wait")?;
    let resource_event = fields.atom("resource_event")?;
    let resource_observed_value = fields.integer("resource_observed_value")?;
    let event_clock = fields.integer("event_clock")?;
    let completion_arrival_sequence = fields.integer("completion_arrival_sequence")?;
    let quota_arrival_sequence = fields.integer("quota_arrival_sequence")?;
    let fault_arrival_sequence = fields.integer("fault_arrival_sequence")?;
    let enforcement = fields.atom("enforcement")?;
    let winner = fields.atom("winner")?;
    let winner_sequence = fields.integer("winner_sequence")?;
    let counters = fields.atom("counters")?;
    let baseline_value = fields.integer("baseline_value")?;
    let final_value = fields.integer("final_value")?;
    let fault = fields.atom("fault")?;
    let fault_cause = fields.atom("fault_cause")?;
    let fault_cause_receipt_sequence = fields.integer("fault_cause_receipt_sequence")?;
    let pending_attack = fields.atom("pending_attack")?;
    let attack_attempts = parse_atoms(fields.next("attack_attempts")?, "state.attack_attempts")?;
    let attack_rejections =
        parse_atoms(fields.next("attack_rejections")?, "state.attack_rejections")?;
    let breach_kind = fields.atom("breach_kind")?;
    let evidence_ledger = fields.atom("evidence_ledger")?;
    let evidence_receipts = parse_receipts(fields.next("evidence_receipts")?)?;
    let evidence_root = fields.string("evidence_root")?;
    let local_decision = fields.atom("local_decision")?;
    let decision_receipt = match fields.next("decision_receipt")? {
        Value::None => None,
        value => Some(parse_decision(value, "state.decision_receipt")?),
    };
    let recovery_receipts = parse_recoveries(fields.next("recovery_receipts")?)?;

    Ok(State {
        grant: std::sync::Arc::new(grant),
        phase,
        owner_state,
        primary_state,
        controller,
        scope,
        visible_population,
        visible_empty_observations,
        task_population,
        attach_authority,
        async_admission,
        execution_authority,
        protection_state,
        leader,
        descendants,
        descendant_generation,
        descendant_drained_generation,
        async_refs,
        async_generation,
        async_drained_generation,
        hidden_work,
        sandbox,
        payload,
        writer_confinement,
        stream,
        candidate_kind,
        candidate_value,
        candidate_digest,
        wait,
        resource_event,
        resource_observed_value,
        event_clock,
        completion_arrival_sequence,
        quota_arrival_sequence,
        fault_arrival_sequence,
        enforcement,
        winner,
        winner_sequence,
        counters,
        baseline_value,
        final_value,
        fault,
        fault_cause,
        fault_cause_receipt_sequence,
        pending_attack,
        attack_attempts,
        attack_rejections,
        breach_kind,
        evidence_ledger,
        evidence_receipts,
        evidence_root,
        local_decision,
        decision_receipt,
        recovery_receipts,
    })
}
