#!/usr/bin/env python3
"""Validate the pre-normative F0 supervised-evaluation protocol v2."""

from __future__ import annotations

import hashlib
import itertools
import json
import os
import stat
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Mapping


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
ANALYSIS = ROOT / "capsched-models" / "analysis"
PROTOCOL = ANALYSIS / "dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.json"
PREDECESSOR = ANALYSIS / "dynamic-residency-f0-v5-supervised-evaluation-protocol-v1.json"

MAX_BYTES = 2 * 1024 * 1024
MAX_DEPTH = 96
MAX_NODES = 200_000
MAX_COLLECTION_ITEMS = 100_000
MAX_INTEGER_DIGITS = 64

OUTCOMES = {
    "NONE",
    "SUCCESS",
    "REJECT",
    "INCONCLUSIVE_RESOURCE",
    "INCONCLUSIVE_UNSUPPORTED",
    "INTERNAL_FAILURE",
}


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _reject(reject_id: str, detail: str) -> None:
    raise Reject(reject_id, detail)


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            _reject("F05-SPV2-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _parse_int(text: str) -> int:
    digits = text[1:] if text.startswith("-") else text
    if len(digits) > MAX_INTEGER_DIGITS:
        _reject("F05-SPV2-INTEGER-DIGITS", str(len(digits)))
    return int(text)


def _reject_float(text: str) -> Any:
    _reject("F05-SPV2-FLOAT", text)


def _reject_constant(text: str) -> Any:
    _reject("F05-SPV2-NON-JSON-NUMBER", text)


def _validate_tree(root: Any) -> None:
    stack: list[tuple[Any, int, str]] = [(root, 0, "$")]
    nodes = 0
    collection_items = 0
    while stack:
        value, depth, path = stack.pop()
        nodes += 1
        if nodes > MAX_NODES:
            _reject("F05-SPV2-NODE-LIMIT", str(nodes))
        if depth > MAX_DEPTH:
            _reject("F05-SPV2-DEPTH", path[:256])
        if value is None or isinstance(value, float):
            _reject("F05-SPV2-UNSAFE-SCALAR", path[:256])
        if isinstance(value, bool):
            continue
        if isinstance(value, int):
            if value < 0:
                _reject("F05-SPV2-NEGATIVE-INTEGER", path[:256])
            if len(str(value)) > MAX_INTEGER_DIGITS:
                _reject("F05-SPV2-INTEGER-DIGITS", path[:256])
            continue
        if isinstance(value, str):
            try:
                value.encode("ascii")
            except UnicodeEncodeError:
                _reject("F05-SPV2-NON-ASCII-STRING", path[:256])
            if any(ord(char) < 0x20 for char in value):
                _reject("F05-SPV2-CONTROL-STRING", path[:256])
            continue
        if isinstance(value, list):
            collection_items += len(value)
            if collection_items > MAX_COLLECTION_ITEMS:
                _reject("F05-SPV2-COLLECTION-LIMIT", str(collection_items))
            for index, child in enumerate(reversed(value)):
                actual = len(value) - index - 1
                stack.append((child, depth + 1, f"{path}[{actual}]"))
            continue
        if isinstance(value, dict):
            collection_items += len(value)
            if collection_items > MAX_COLLECTION_ITEMS:
                _reject("F05-SPV2-COLLECTION-LIMIT", str(collection_items))
            for key, child in reversed(list(value.items())):
                if not isinstance(key, str):
                    _reject("F05-SPV2-KEY-TYPE", path[:256])
                stack.append((child, depth + 1, f"{path}.{key}"))
            continue
        _reject("F05-SPV2-UNSAFE-SCALAR", path[:256])


def parse_ascii_json(raw: bytes, label: str) -> dict[str, Any]:
    if len(raw) > MAX_BYTES:
        _reject("F05-SPV2-FILE-SIZE", f"{label}:{len(raw)}")
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError:
        _reject("F05-SPV2-NON-ASCII-JSON", label)
    try:
        value = json.loads(
            text,
            object_pairs_hook=_pairs,
            parse_int=_parse_int,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except Reject:
        raise
    except (json.JSONDecodeError, ValueError, RecursionError) as exc:
        _reject("F05-SPV2-JSON", f"{label}:{type(exc).__name__}")
    _validate_tree(value)
    if not isinstance(value, dict):
        _reject("F05-SPV2-ROOT", label)
    return value


def read_once(path: Path) -> bytes:
    try:
        info = path.lstat()
    except OSError as exc:
        _reject("F05-SPV2-READ", f"{path}:{exc.__class__.__name__}")
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
        _reject("F05-SPV2-FILE-TYPE", str(path))
    if info.st_size > MAX_BYTES:
        _reject("F05-SPV2-FILE-SIZE", f"{path}:{info.st_size}")
    try:
        with path.open("rb") as handle:
            opened = os.fstat(handle.fileno())
            if not stat.S_ISREG(opened.st_mode):
                _reject("F05-SPV2-FILE-TYPE", str(path))
            raw = handle.read(MAX_BYTES + 1)
    except Reject:
        raise
    except OSError as exc:
        _reject("F05-SPV2-READ", f"{path}:{exc.__class__.__name__}")
    if len(raw) > MAX_BYTES:
        _reject("F05-SPV2-FILE-SIZE", f"{path}:{len(raw)}")
    return raw


EXPECTED_TOP_LEVEL = {
    "schema_version",
    "artifact_id",
    "project",
    "requirement",
    "date",
    "status",
    "predecessor",
    "role_separation",
    "trust_boundary",
    "run_binding",
    "state_domains",
    "initial_state",
    "monotonicity",
    "receipt_types",
    "resource_roles",
    "transitions",
    "quiescence_requirements",
    "finalization_domains",
    "classification_semantics",
    "required_scenarios",
    "observation_order_pairs",
    "proof_obligations",
    "linux_refinement_candidates",
    "open_decisions",
    "authorization",
}

EXPECTED_ROLE_SEPARATION = {
    "guardian": [
        "ISSUE_FRESH_RUN_ID",
        "OWN_AGGREGATE_ADMISSION",
        "OWN_EXECUTION_SCOPE_LIFETIME",
        "CLEAN_ON_SUPERVISOR_DEATH",
        "ATOMICALLY_PUBLISH_OR_ABANDON",
    ],
    "transport_supervisor": [
        "HANDLE_FIXED_METADATA",
        "HASH_AND_SEAL_BOUNDED_OPAQUE_BYTES",
        "OWN_LIVE_KERNEL_HANDLES",
        "ARBITRATE_QUOTAS",
        "DRAIN_FIXED_FRAME_TRANSPORT",
        "CLEAN_SCOPE",
        "SEAL_EVIDENCE_LEDGER",
        "APPLY_PURE_CLASSIFIER",
    ],
    "bounded_worker": [
        "PARSE_REQUESTER_BYTES",
        "WIRE_STATIC_LINK_OCCURRENCE_CHECK",
        "DECODE_FINITE_INPUTS",
        "EVALUATE",
        "CONSTRUCT_AND_SERIALIZE_RESULT",
    ],
    "independent_checker": [
        "VALIDATE_TYPED_RESULT_OR_PROOF_CERTIFICATE",
        "ISSUE_CHECKED_CANDIDATE_RECEIPT",
    ],
}

EXPECTED_TRUST = {
    "requester_bytes_interpreted_by_transport_supervisor": False,
    "result_json_interpreted_by_transport_supervisor": False,
    "transport_valid_frame_is_semantic_evidence": False,
    "reference_evaluator_is_trusted_proof_producer": False,
    "positive_semantic_credit_requires_independent_checked_proof_or_certificate": True,
    "host_kernel_is_supervisor_tcb": True,
    "host_kernel_compromise_covered": False,
}

EXPECTED_COMMON_FIELDS = [
    "RUN_ID",
    "SUPERVISOR_EPOCH",
    "GUARDIAN_ID",
    "REQUEST_RAW_SHA256",
    "OPTIONAL_PARSED_REQUEST_ID",
    "VALIDATION_CONTEXT_CANDIDATE_ID",
    "PRODUCER_EXECUTABLE_CLOSURE_ID",
    "OUTCOME_CHECKER_EXECUTABLE_CLOSURE_ID",
    "OPERATOR_ENVELOPE_ID",
    "SUPERVISOR_POLICY_ID",
    "SUPPORT_MATRIX_ID",
    "TAXONOMY_ID",
]

EXPECTED_LEDGER_FIELDS = [
    "ISSUER_ROLE",
    "SEQUENCE",
    "PREVIOUS_RECEIPT_SHA256",
    "EVENT_KIND",
    "EVENT_PAYLOAD_SHA256",
]

EXPECTED_STATE_DOMAINS = {
    "stage": [
        "NEW",
        "GENESIS_BOUND",
        "SCOPE_READY",
        "LAUNCHER_CHARGED",
        "SANDBOX_READY",
        "RUNNING",
        "STOPPING",
        "OBSERVATIONS_CLOSED",
        "QUIESCENT",
        "DECIDED",
        "PUBLISHED",
        "ABANDONED",
    ],
    "worker": [
        "ABSENT",
        "CHARGED_NOT_RELEASED",
        "RUNNING",
        "STOP_REQUESTED",
        "LEADER_EXITED",
        "LEADER_REAPED",
    ],
    "stream": [
        "UNOPENED",
        "OPEN_EMPTY",
        "OPEN_PARTIAL",
        "CANDIDATE_AWAIT_EOF",
        "EOF_VALID",
        "EOF_ABSENT_OR_TRUNCATED",
        "EOF_INVALID_OR_TRAILING",
    ],
    "wait": [
        "NONE",
        "NORMAL_ZERO",
        "ATTRIBUTED_QUOTA_STOP",
        "ABNORMAL_OR_UNKNOWN",
        "NO_WORKER",
    ],
    "quota": ["NONE", "ATTRIBUTED_SEMANTIC", "AMBIGUOUS_OR_ENVIRONMENT"],
    "fault": ["CLEAN", "PROTOCOL", "CONTAINMENT", "IDENTITY", "SUPERVISOR"],
    "scope": [
        "UNCREATED",
        "CONFIGURED_EMPTY",
        "POPULATED",
        "STOPPING",
        "EMPTY",
        "ESCAPED_OR_UNKNOWN",
    ],
    "counters": ["BASELINE_ONLY", "FINAL_MATCH", "MISSING_OR_DRIFT"],
    "decision": [
        "NONE",
        "SUCCESS",
        "REJECT",
        "INCONCLUSIVE_RESOURCE",
        "INCONCLUSIVE_UNSUPPORTED",
        "INTERNAL_FAILURE",
    ],
    "publication": ["NONE", "PUBLISHED", "ABANDONED"],
}

EXPECTED_INITIAL_STATE = {
    "stage": "NEW",
    "worker": "ABSENT",
    "stream": "UNOPENED",
    "wait": "NONE",
    "quota": "NONE",
    "fault": "CLEAN",
    "scope": "UNCREATED",
    "counters": "BASELINE_ONLY",
    "decision": "NONE",
    "publication": "NONE",
}

EXPECTED_MONOTONICITY = {
    "receipt_sequence": "STRICTLY_INCREASES",
    "receipt_ledger": "APPEND_ONLY",
    "stream_terminal_states": [
        "EOF_VALID",
        "EOF_ABSENT_OR_TRUNCATED",
        "EOF_INVALID_OR_TRAILING",
    ],
    "wait_single_assignment_after_none": True,
    "quota_single_assignment_after_none": True,
    "fault_clean_to_sticky_fault_only": True,
    "decision_single_assignment_after_none": True,
    "publication_single_assignment_after_none": True,
    "partial_stream_is_not_fault": True,
}

EXPECTED_RECEIPTS = [
    "RUN_GENESIS",
    "SCOPE_CONFIGURATION",
    "CHARGED_LAUNCH",
    "SANDBOX_READY",
    "REQUEST_RELEASE",
    "STREAM_EOF",
    "WAIT_STATUS",
    "QUOTA_ARBITRATION",
    "PROTOCOL_OR_CONTAINMENT_FAULT",
    "SCOPE_STOP_REQUEST",
    "LEADER_REAP",
    "GROUP_EMPTY",
    "FINAL_COUNTERS",
    "OUTCOME_CHECKER_VERDICT",
    "LEDGER_SEAL",
    "CLASSIFICATION_RULE",
    "ATOMIC_PUBLICATION",
    "GUARDIAN_ABORT",
]

EXPECTED_RESOURCE_ROLES = {
    "semantic_budget": [
        "INGRESS_BYTES",
        "REQUESTER_LEDGER",
        "OPERATOR_LEDGER",
        "TOTAL_CPU_CONTRACT",
        "WALL_DEADLINE",
        "EXACT_MEMORY_CHARGE_CONTRACT",
        "RESULT_BODY_CONSTRUCTION",
    ],
    "containment": [
        "TRANSPORT_FRAME_LIMIT",
        "DUPLICATE_OR_TRAILING_FRAME",
        "FD_MANIFEST",
        "FORK_CLONE_EXEC",
        "SECCOMP_OR_AUTHORITY_VIOLATION",
        "CORE_DUMP",
        "SCOPE_ESCAPE",
    ],
    "environment": [
        "HOST_OOM_AMBIGUITY",
        "EXTERNAL_SIGNAL",
        "MISSING_KERNEL_OBSERVATION",
        "SUPERVISOR_DEATH",
        "GUARDIAN_FAILURE",
    ],
    "only_semantic_budget_may_issue_resource": True,
}

EXPECTED_TRANSITIONS = [
    ("SV2-001", "BIND_RUN_GENESIS", ["NEW"], "GENESIS_BOUND", "RUN_GENESIS"),
    ("SV2-002", "CONFIGURE_FRESH_EXCLUSIVE_SCOPE", ["GENESIS_BOUND"], "SCOPE_READY", "SCOPE_CONFIGURATION"),
    ("SV2-003", "CREATE_CHARGED_STERILE_LAUNCHER", ["SCOPE_READY"], "LAUNCHER_CHARGED", "CHARGED_LAUNCH"),
    ("SV2-004", "VERIFY_SANDBOX_READY", ["LAUNCHER_CHARGED"], "SANDBOX_READY", "SANDBOX_READY"),
    ("SV2-005", "RELEASE_REQUESTER_BYTES", ["SANDBOX_READY"], "RUNNING", "REQUEST_RELEASE"),
    ("SV2-006", "ACCUMULATE_PARTIAL_STREAM", ["RUNNING", "STOPPING"], "SAME", "NONE"),
    ("SV2-007", "RECORD_CANDIDATE_AWAIT_EOF", ["RUNNING", "STOPPING"], "SAME", "NONE"),
    ("SV2-008", "RECORD_STREAM_EOF_CLASS", ["RUNNING", "STOPPING"], "SAME", "STREAM_EOF"),
    ("SV2-009", "RECORD_WAIT_STATUS", ["RUNNING", "STOPPING"], "SAME", "WAIT_STATUS"),
    ("SV2-010", "ARBITRATE_SEMANTIC_QUOTA", ["GENESIS_BOUND", "RUNNING", "STOPPING"], "STOPPING", "QUOTA_ARBITRATION"),
    ("SV2-011", "RECORD_AMBIGUOUS_LIMIT_OR_FAULT", ["GENESIS_BOUND", "RUNNING", "STOPPING"], "STOPPING", "PROTOCOL_OR_CONTAINMENT_FAULT"),
    ("SV2-012", "REQUEST_SCOPE_STOP", ["RUNNING", "STOPPING"], "STOPPING", "SCOPE_STOP_REQUEST"),
    ("SV2-013", "REAP_LEADER", ["RUNNING", "STOPPING"], "STOPPING", "LEADER_REAP"),
    ("SV2-014", "OBSERVE_GROUP_EMPTY", ["RUNNING", "STOPPING"], "STOPPING", "GROUP_EMPTY"),
    ("SV2-015", "CAPTURE_FINAL_COUNTERS", ["RUNNING", "STOPPING"], "STOPPING", "FINAL_COUNTERS"),
    ("SV2-016", "RECORD_BOUNDED_OUTCOME_CHECKER_VERDICT", ["RUNNING", "STOPPING"], "SAME", "OUTCOME_CHECKER_VERDICT"),
    ("SV2-017", "CLOSE_OBSERVATIONS", ["RUNNING", "STOPPING", "GENESIS_BOUND"], "OBSERVATIONS_CLOSED", "LEDGER_SEAL"),
    ("SV2-018", "ENTER_QUIESCENT", ["OBSERVATIONS_CLOSED"], "QUIESCENT", "LEDGER_SEAL"),
    ("SV2-019", "APPLY_PURE_CLASSIFIER", ["QUIESCENT"], "DECIDED", "CLASSIFICATION_RULE"),
    ("SV2-020", "ATOMICALLY_PUBLISH_TERMINAL_CAPSULE", ["DECIDED"], "PUBLISHED", "ATOMIC_PUBLICATION"),
    (
        "SV2-021",
        "GUARDIAN_ABORT_UNPUBLISHED_RUN",
        [
            "NEW",
            "GENESIS_BOUND",
            "SCOPE_READY",
            "LAUNCHER_CHARGED",
            "SANDBOX_READY",
            "RUNNING",
            "STOPPING",
            "OBSERVATIONS_CLOSED",
            "QUIESCENT",
            "DECIDED",
        ],
        "ABANDONED",
        "GUARDIAN_ABORT",
    ),
]

EXPECTED_QUIESCENCE = [
    "LEADER_REAPED_OR_RECORDED_NO_WORKER_PATH",
    "EXECUTION_SCOPE_EMPTY_AND_CLOSED_TO_NEW_TASKS",
    "ALL_OUTPUT_WRITERS_GONE",
    "STREAM_EOF_CLASSIFIED",
    "QUOTA_AND_DEADLINE_ARBITRATION_FINAL",
    "FINAL_COUNTERS_BOUND_TO_BASELINE",
    "IDENTITY_AND_POLICY_GENERATIONS_MATCH",
    "CLEANUP_COMPLETE",
    "EVIDENCE_LEDGER_SEALED",
]

EXPECTED_FINAL_DOMAINS = {
    "quiescent": [False, True],
    "binding": ["MATCH", "MISMATCH"],
    "fault": ["CLEAN", "PRESENT"],
    "quota": ["NONE", "ATTRIBUTED_SEMANTIC", "AMBIGUOUS_OR_ENVIRONMENT"],
    "stream": ["EOF_VALID", "EOF_ABSENT_OR_TRUNCATED", "EOF_INVALID_OR_TRAILING"],
    "wait": ["NORMAL_ZERO", "ATTRIBUTED_QUOTA_STOP", "ABNORMAL_OR_UNKNOWN", "NO_WORKER"],
    "scope": ["EMPTY", "NONEMPTY_OR_ESCAPED"],
    "counters": ["FINAL_MATCH", "MISSING_OR_DRIFT"],
    "frame_claim": ["SUCCESS", "REJECT", "RESOURCE_METER", "UNSUPPORTED", "INTERNAL", "NONE_OR_UNKNOWN"],
    "typed_receipt": ["VALID", "NONE_OR_INVALID"],
    "checkpoint": ["NOT_REACHED", "WF_SUPPORTED", "WF_UNSUPPORTED", "REJECTED", "METERED", "CONFLICT"],
}


def _base_conditions() -> dict[str, list[Any]]:
    return {
        "quiescent": [True],
        "binding": ["MATCH"],
        "fault": ["CLEAN"],
        "quota": ["NONE"],
        "stream": ["EOF_VALID"],
        "wait": ["NORMAL_ZERO"],
        "scope": ["EMPTY"],
        "counters": ["FINAL_MATCH"],
    }


def _rule(
    rule_id: str,
    outcome: str,
    frame_claim: list[str],
    typed_receipt: list[str],
    checkpoint: list[str],
    **overrides: list[Any],
) -> dict[str, Any]:
    conditions = _base_conditions()
    conditions.update(overrides)
    conditions.update(
        {
            "frame_claim": frame_claim,
            "typed_receipt": typed_receipt,
            "checkpoint": checkpoint,
        }
    )
    return {"id": rule_id, "outcome": outcome, "conditions": conditions}


NONCONFLICT_CHECKPOINTS = [
    "NOT_REACHED",
    "WF_SUPPORTED",
    "WF_UNSUPPORTED",
    "REJECTED",
    "METERED",
]

EXPECTED_POSITIVE_RULES = [
    _rule("SV2-CF-001", "SUCCESS", ["SUCCESS"], ["VALID"], ["WF_SUPPORTED"]),
    _rule("SV2-CF-002", "REJECT", ["REJECT"], ["VALID"], ["REJECTED"]),
    _rule(
        "SV2-CF-003",
        "INCONCLUSIVE_RESOURCE",
        ["RESOURCE_METER"],
        ["VALID"],
        ["METERED"],
    ),
    _rule(
        "SV2-CF-004",
        "INCONCLUSIVE_UNSUPPORTED",
        ["UNSUPPORTED"],
        ["VALID"],
        ["WF_UNSUPPORTED"],
    ),
    _rule(
        "SV2-CF-005",
        "INCONCLUSIVE_RESOURCE",
        ["SUCCESS", "REJECT", "RESOURCE_METER", "UNSUPPORTED", "INTERNAL"],
        ["VALID"],
        NONCONFLICT_CHECKPOINTS,
        quota=["ATTRIBUTED_SEMANTIC"],
        wait=["ATTRIBUTED_QUOTA_STOP"],
    ),
    _rule(
        "SV2-CF-006",
        "INCONCLUSIVE_RESOURCE",
        ["NONE_OR_UNKNOWN"],
        ["NONE_OR_INVALID"],
        NONCONFLICT_CHECKPOINTS,
        quota=["ATTRIBUTED_SEMANTIC"],
        stream=["EOF_ABSENT_OR_TRUNCATED"],
        wait=["ATTRIBUTED_QUOTA_STOP"],
    ),
    _rule(
        "SV2-CF-007",
        "INCONCLUSIVE_RESOURCE",
        ["NONE_OR_UNKNOWN"],
        ["NONE_OR_INVALID"],
        ["NOT_REACHED"],
        quota=["ATTRIBUTED_SEMANTIC"],
        stream=["EOF_ABSENT_OR_TRUNCATED"],
        wait=["NO_WORKER"],
    ),
]

EXPECTED_SCENARIO_IDS = [
    "CLEAN_SUCCESS",
    "CLEAN_REJECT",
    "CLEAN_REQUESTER_METER",
    "CLEAN_UNSUPPORTED",
    "WORKER_INTERNAL",
    "QUOTA_TRUNCATES_FRAME",
    "VALID_FRAME_THEN_QUOTA",
    "PROTOCOL_FAULT_THEN_QUOTA",
    "NORMAL_EXIT_WITHOUT_FRAME",
    "CROSS_RUN_BINDING_MISMATCH",
    "AMBIGUOUS_OOM",
    "DESCENDANT_OR_SCOPE_REMAINS",
    "INGRESS_LIMIT_NO_WORKER",
    "NOT_YET_QUIESCENT",
    "TRAILING_BYTE_AFTER_SUCCESS",
    "CONFLICTING_CHECKPOINT",
]

EXPECTED_ORDER_EVENT_SETS = {
    "FRAME_EXIT_EOF_COMMUTE": {
        "FRAME_CANDIDATE",
        "NORMAL_EXIT",
        "STREAM_EOF",
        "LEADER_REAP",
        "GROUP_EMPTY",
        "FINAL_COUNTERS",
    },
    "QUOTA_PARTIAL_EXIT_COMMUTE": {
        "OPEN_PARTIAL",
        "QUOTA_ATTRIBUTED",
        "ATTRIBUTED_EXIT",
        "STREAM_EOF",
        "LEADER_REAP",
        "GROUP_EMPTY",
        "FINAL_COUNTERS",
    },
    "FAULT_QUOTA_COMMUTE": {
        "PROTOCOL_FAULT",
        "QUOTA_ATTRIBUTED",
        "ATTRIBUTED_EXIT",
        "STREAM_EOF",
        "LEADER_REAP",
        "GROUP_EMPTY",
        "FINAL_COUNTERS",
    },
}

EXPECTED_PROOF_OBLIGATIONS = [
    "INIT_TYPEOK_AND_REACHABLE_WF",
    "NO_REQUESTER_INTERPRETATION_BEFORE_CHARGED_SANDBOX_READY",
    "MONOTONE_OBSERVATION_COORDINATES",
    "NO_DECISION_BEFORE_QUIESCENCE",
    "NO_PUBLICATION_BEFORE_DECISION",
    "POSITIVE_CLASSIFICATION_GUARDS_PAIRWISE_DISJOINT",
    "QUIESCENT_CLASSIFICATION_TOTAL_WITH_INTERNAL_FALLBACK",
    "FRAME_EXIT_QUOTA_OBSERVATION_ORDER_COMMUTATIVITY",
    "RECEIPT_FRESHNESS_APPEND_ONLY_SINGLE_USE_AND_CROSS_RUN_ISOLATION",
    "PROTOCOL_AND_CONTAINMENT_FAULT_PRECEDENCE_OVER_RESOURCE",
    "LEADER_REAP_SCOPE_EMPTY_WRITER_EOF_AND_FINAL_COUNTER_SAFETY",
    "CONDITIONAL_LIVENESS_UNDER_EXPLICIT_KERNEL_AND_GUARDIAN_FAIRNESS",
    "GUARDIAN_ABORT_CANNOT_PUBLISH_TERMINAL_RESULT",
    "SELECTED_LINUX_MECHANISM_REFINES_EACH_ABSTRACT_OPERATION",
]

EXPECTED_LINUX_CANDIDATES = {
    "charged_launch": ["CLONE_INTO_FRESH_CGROUP_WITH_STERILE_LAUNCHER"],
    "live_identity": ["PIDFD_FOR_LEADER", "CGROUPFD_FOR_EXECUTION_SCOPE"],
    "cleanup": ["CGROUP_KILL", "CGROUP_EVENTS_POPULATED_ZERO", "LEADER_REAP"],
    "stream": ["NONBLOCKING_EPOLL_DRAIN_TO_LIMIT_PLUS_ONE_AND_EOF"],
    "authority": [
        "EXACT_FD_MANIFEST",
        "EMPTY_CAPABILITIES",
        "NO_NEW_PRIVS",
        "NONDUMPABLE",
        "ARCH_SPECIFIC_SECCOMP_ALLOWLIST",
    ],
    "status": "CANDIDATES_ONLY_NOT_SELECTED_OR_PROVED",
}

EXPECTED_OPEN_DECISIONS = [
    "EXACT_GUARDIAN_AND_SUPERVISOR_EXECUTABLE_CLOSURE",
    "EXACT_RACE_FREE_CHARGED_LAUNCH",
    "CUMULATIVE_CPU_AND_MEMORY_CAUSALITY",
    "FIXED_BINARY_FRAME_AND_RECEIPT_ENCODING",
    "STATIC_EXECUTABLE_OR_CAPTURED_INTERPRETER_CLOSURE",
    "INDEPENDENT_RESULT_AND_PROOF_CHECKER_COMPOSITION",
    "ATOMIC_PUBLICATION_AND_CRASH_RECOVERY",
    "KERNEL_VERSION_SPECIFIC_REFINEMENT_PROOF",
]

EXPECTED_AUTHORIZATION = {
    "predecessor_rejection_addressed_in_candidate": True,
    "machine_validator_implemented": True,
    "machine_exploration_passed": True,
    "fresh_hostile_review_complete": False,
    "protocol_normative": False,
    "supervisor_implemented": False,
    "executed_artifact_bound": False,
    "external_process_supervisor_bound": False,
    "result_taxonomy_closed": False,
    "ValidationContextDigest_issued": False,
    "evaluation_validated": False,
    "CoreSyntaxWF": False,
    "InstanceWF": False,
    "F0_local_acceptance": False,
    "K0_G0_complete": False,
    "candidate_IR": False,
    "TLA_translation": False,
    "model_supported": False,
    "linux_behavior_change": False,
    "protection_claim": False,
}


def _unique_strings(values: Any, reject_id: str, label: str) -> list[str]:
    if not isinstance(values, list) or not values or not all(isinstance(v, str) for v in values):
        _reject(reject_id, label)
    if len(values) != len(set(values)):
        _reject(reject_id, f"{label}:duplicate")
    return values


def _validate_predecessor(document: Mapping[str, Any], verify_files: bool) -> None:
    expected = {
        "artifact_id": "dynamic-residency-f0-v5-supervised-evaluation-protocol-v1",
        "artifact_sha256": "35d2f6c711a54a96841076882d97177b78a81e90dc16ff6e852e83d568d6f5f5",
        "disposition_id": "dynamic-residency-f0-v5-supervisor-v1-hostile-rejection-v1",
        "disposition": "LOCAL_ADVISORY_REJECT",
    }
    if document.get("predecessor") != expected:
        _reject("F05-SPV2-PREDECESSOR", "predecessor disposition drift")
    if verify_files and sha256(read_once(PREDECESSOR)) != expected["artifact_sha256"]:
        _reject("F05-SPV2-PREDECESSOR", "reviewed predecessor bytes changed")


def _validate_transitions(document: Mapping[str, Any]) -> None:
    transitions = document.get("transitions")
    if not isinstance(transitions, list) or len(transitions) != len(EXPECTED_TRANSITIONS):
        _reject("F05-SPV2-TRANSITIONS", "transition count")
    actual: list[tuple[Any, ...]] = []
    allowed_receipts = set(EXPECTED_RECEIPTS) | {"NONE"}
    stages = set(EXPECTED_STATE_DOMAINS["stage"])
    for row in transitions:
        if not isinstance(row, dict) or set(row) != {"id", "name", "from_stage", "to_stage", "receipt"}:
            _reject("F05-SPV2-TRANSITIONS", "transition row shape")
        sources = _unique_strings(row["from_stage"], "F05-SPV2-TRANSITIONS", str(row.get("id")))
        if not set(sources) <= stages:
            _reject("F05-SPV2-TRANSITIONS", f"{row.get('id')}:source")
        if row["to_stage"] not in stages | {"SAME"}:
            _reject("F05-SPV2-TRANSITIONS", f"{row.get('id')}:target")
        if row["receipt"] not in allowed_receipts:
            _reject("F05-SPV2-TRANSITIONS", f"{row.get('id')}:receipt")
        actual.append((row["id"], row["name"], sources, row["to_stage"], row["receipt"]))
    if actual != EXPECTED_TRANSITIONS:
        _reject("F05-SPV2-TRANSITIONS", "transition contract drift")
    if [row[0] for row in actual] != [f"SV2-{index:03d}" for index in range(1, 22)]:
        _reject("F05-SPV2-TRANSITIONS", "transition IDs")
    deciding = [row for row in actual if row[3] == "DECIDED"]
    publishing = [row for row in actual if row[3] == "PUBLISHED"]
    if deciding != [EXPECTED_TRANSITIONS[18]] or publishing != [EXPECTED_TRANSITIONS[19]]:
        _reject("F05-SPV2-TRANSITIONS", "decision/publication gate")


def _matches(state: Mapping[str, Any], conditions: Mapping[str, Any]) -> bool:
    return all(state[key] in allowed for key, allowed in conditions.items())


def classify(
    state: Mapping[str, Any],
    domains: Mapping[str, list[Any]],
    rules: list[Mapping[str, Any]],
) -> tuple[str, str | None]:
    if not state["quiescent"]:
        return "NONE", None
    matched = [row for row in rules if _matches(state, row["conditions"])]
    if len(matched) > 1:
        _reject(
            "F05-SPV2-CLASSIFIER-OVERLAP",
            ",".join(str(row["id"]) for row in matched),
        )
    if not matched:
        return "INTERNAL_FAILURE", "FALLBACK_INTERNAL"
    return str(matched[0]["outcome"]), str(matched[0]["id"])


def _validate_classifier(document: Mapping[str, Any]) -> dict[str, Any]:
    domains = document.get("finalization_domains")
    if domains != EXPECTED_FINAL_DOMAINS:
        _reject("F05-SPV2-FINAL-DOMAINS", "finalization domain drift")
    semantics = document.get("classification_semantics")
    if not isinstance(semantics, dict) or set(semantics) != {
        "mode",
        "nonquiescent_outcome",
        "fallback_outcome",
        "positive_rules",
    }:
        _reject("F05-SPV2-CLASSIFIER-MODE", "classifier shape")
    if (
        semantics["mode"] != "FIRST_MATCH_POSITIVE_ELSE_INTERNAL_AFTER_QUIESCENCE"
        or semantics["nonquiescent_outcome"] != "NONE"
        or semantics["fallback_outcome"] != "INTERNAL_FAILURE"
    ):
        _reject("F05-SPV2-CLASSIFIER-MODE", "classifier mode drift")
    rules = semantics["positive_rules"]
    if not isinstance(rules, list) or not rules:
        _reject("F05-SPV2-CLASSIFIER-RULES", "missing rules")
    seen_ids: set[str] = set()
    for row in rules:
        if not isinstance(row, dict) or set(row) != {"id", "outcome", "conditions"}:
            _reject("F05-SPV2-CLASSIFIER-RULES", "row shape")
        if row["id"] in seen_ids:
            _reject("F05-SPV2-CLASSIFIER-RULES", f"duplicate {row['id']}")
        seen_ids.add(row["id"])
        if row["outcome"] not in OUTCOMES - {"NONE", "INTERNAL_FAILURE"}:
            _reject("F05-SPV2-CLASSIFIER-RULES", f"outcome {row['outcome']}")
        conditions = row["conditions"]
        if not isinstance(conditions, dict) or set(conditions) != set(domains):
            _reject("F05-SPV2-CLASSIFIER-CONDITIONS", str(row["id"]))
        for key, allowed in conditions.items():
            if not isinstance(allowed, list) or not allowed or len(allowed) != len(set(map(repr, allowed))):
                _reject("F05-SPV2-CLASSIFIER-CONDITIONS", f"{row['id']}:{key}")
            if any(value not in domains[key] for value in allowed):
                _reject("F05-SPV2-CLASSIFIER-CONDITIONS", f"{row['id']}:{key}:domain")

    keys = list(domains)
    counts: Counter[str] = Counter()
    rule_hits: Counter[str] = Counter()
    total = 0
    quiescent = 0
    for values in itertools.product(*(domains[key] for key in keys)):
        state = dict(zip(keys, values, strict=True))
        outcome, rule_id = classify(state, domains, rules)
        total += 1
        counts[outcome] += 1
        if state["quiescent"]:
            quiescent += 1
            if outcome == "NONE":
                _reject("F05-SPV2-CLASSIFIER-TOTAL", "quiescent NONE")
        elif outcome != "NONE":
            _reject("F05-SPV2-CLASSIFIER-EARLY", outcome)
        if rule_id and rule_id != "FALLBACK_INTERNAL":
            rule_hits[rule_id] += 1
    if any(rule_hits[row["id"]] == 0 for row in rules):
        _reject("F05-SPV2-CLASSIFIER-RULES", "unreachable positive rule")
    if rules != EXPECTED_POSITIVE_RULES:
        _reject("F05-SPV2-CLASSIFIER-CONTRACT", "positive classifier drift")
    return {
        "state_count": total,
        "quiescent_state_count": quiescent,
        "outcome_counts": dict(sorted(counts.items())),
        "positive_rule_hit_counts": dict(sorted(rule_hits.items())),
    }


def _validate_scenarios(document: Mapping[str, Any]) -> int:
    scenarios = document.get("required_scenarios")
    if not isinstance(scenarios, list) or [row.get("id") for row in scenarios if isinstance(row, dict)] != EXPECTED_SCENARIO_IDS:
        _reject("F05-SPV2-SCENARIOS", "scenario inventory")
    domains = document["finalization_domains"]
    rules = document["classification_semantics"]["positive_rules"]
    for row in scenarios:
        if set(row) != {"id", "state", "expected_outcome"}:
            _reject("F05-SPV2-SCENARIOS", f"{row.get('id')}:shape")
        state = row["state"]
        if not isinstance(state, dict) or set(state) != set(domains):
            _reject("F05-SPV2-SCENARIOS", f"{row['id']}:state")
        if any(state[key] not in domains[key] for key in domains):
            _reject("F05-SPV2-SCENARIOS", f"{row['id']}:domain")
        outcome, _ = classify(state, domains, rules)
        if row["expected_outcome"] != outcome:
            _reject("F05-SPV2-SCENARIOS", f"{row['id']}:{outcome}")
    return len(scenarios)


def _state_from_events(events: set[str]) -> dict[str, Any]:
    protocol_fault = "PROTOCOL_FAULT" in events
    quota = "QUOTA_ATTRIBUTED" in events
    candidate = "FRAME_CANDIDATE" in events
    partial = "OPEN_PARTIAL" in events
    eof = "STREAM_EOF" in events
    normal = "NORMAL_EXIT" in events
    attributed = "ATTRIBUTED_EXIT" in events
    terminal_evidence = {
        "STREAM_EOF",
        "LEADER_REAP",
        "GROUP_EMPTY",
        "FINAL_COUNTERS",
    } <= events and (normal or attributed)
    if protocol_fault:
        stream = "EOF_INVALID_OR_TRAILING" if eof else "EOF_ABSENT_OR_TRUNCATED"
        frame_claim = "NONE_OR_UNKNOWN"
        receipt = "NONE_OR_INVALID"
    elif candidate and eof:
        stream = "EOF_VALID"
        frame_claim = "SUCCESS"
        receipt = "VALID"
    elif partial and eof:
        stream = "EOF_ABSENT_OR_TRUNCATED"
        frame_claim = "NONE_OR_UNKNOWN"
        receipt = "NONE_OR_INVALID"
    else:
        stream = "EOF_ABSENT_OR_TRUNCATED"
        frame_claim = "NONE_OR_UNKNOWN"
        receipt = "NONE_OR_INVALID"
    return {
        "quiescent": terminal_evidence,
        "binding": "MATCH",
        "fault": "PRESENT" if protocol_fault else "CLEAN",
        "quota": "ATTRIBUTED_SEMANTIC" if quota else "NONE",
        "stream": stream,
        "wait": "ATTRIBUTED_QUOTA_STOP" if attributed else "NORMAL_ZERO" if normal else "ABNORMAL_OR_UNKNOWN",
        "scope": "EMPTY" if "GROUP_EMPTY" in events else "NONEMPTY_OR_ESCAPED",
        "counters": "FINAL_MATCH" if "FINAL_COUNTERS" in events else "MISSING_OR_DRIFT",
        "frame_claim": frame_claim,
        "typed_receipt": receipt,
        "checkpoint": "WF_SUPPORTED" if candidate else "NOT_REACHED",
    }


def _validate_observation_orders(document: Mapping[str, Any]) -> int:
    pairs = document.get("observation_order_pairs")
    if not isinstance(pairs, list) or [row.get("id") for row in pairs if isinstance(row, dict)] != list(EXPECTED_ORDER_EVENT_SETS):
        _reject("F05-SPV2-OBSERVATION-ORDER", "pair inventory")
    domains = document["finalization_domains"]
    rules = document["classification_semantics"]["positive_rules"]
    for row in pairs:
        if set(row) != {"id", "order_a", "order_b", "expected_outcome"}:
            _reject("F05-SPV2-OBSERVATION-ORDER", f"{row.get('id')}:shape")
        a = _unique_strings(row["order_a"], "F05-SPV2-OBSERVATION-ORDER", f"{row['id']}:a")
        b = _unique_strings(row["order_b"], "F05-SPV2-OBSERVATION-ORDER", f"{row['id']}:b")
        expected_set = EXPECTED_ORDER_EVENT_SETS[row["id"]]
        if set(a) != expected_set or set(b) != expected_set or a == b:
            _reject("F05-SPV2-OBSERVATION-ORDER", f"{row['id']}:event set")
        state_a = _state_from_events(set(a))
        state_b = _state_from_events(set(b))
        if state_a != state_b:
            _reject("F05-SPV2-OBSERVATION-ORDER", f"{row['id']}:state")
        outcome_a, _ = classify(state_a, domains, rules)
        outcome_b, _ = classify(state_b, domains, rules)
        if outcome_a != outcome_b or outcome_a != row["expected_outcome"]:
            _reject("F05-SPV2-OBSERVATION-ORDER", f"{row['id']}:{outcome_a}:{outcome_b}")
    return len(pairs)


def validate_document(document: dict[str, Any], *, verify_predecessor_files: bool = False) -> dict[str, Any]:
    _validate_tree(document)
    if set(document) != EXPECTED_TOP_LEVEL:
        _reject("F05-SPV2-TOPLEVEL", "top-level field set")
    if (
        document.get("schema_version") != 2
        or document.get("artifact_id") != "dynamic-residency-f0-v5-supervised-evaluation-protocol-v2"
        or document.get("project") != "DomainLease-Linux"
        or document.get("requirement") != "RESIDENCY-DYN-001"
        or document.get("date") != "2026-08-10"
        or document.get("status") != "pre_normative_candidate_local_machine_validation_passed_requires_fresh_hostile_review"
    ):
        _reject("F05-SPV2-IDENTITY", "identity/status drift")
    _validate_predecessor(document, verify_predecessor_files)
    if document.get("role_separation") != EXPECTED_ROLE_SEPARATION:
        _reject("F05-SPV2-ROLE-SEPARATION", "role contract drift")
    if document.get("trust_boundary") != EXPECTED_TRUST:
        _reject("F05-SPV2-TRUST-BOUNDARY", "trust boundary drift")
    binding = document.get("run_binding")
    if not isinstance(binding, dict) or set(binding) != {
        "run_id_fresh_non_reusable",
        "common_fields",
        "ledger_fields",
        "sequence_strictly_increasing",
        "ledger_append_only",
        "ledger_sealed_before_classification",
    }:
        _reject("F05-SPV2-RUN-BINDING", "run binding shape")
    if (
        binding["run_id_fresh_non_reusable"] is not True
        or binding["common_fields"] != EXPECTED_COMMON_FIELDS
        or binding["ledger_fields"] != EXPECTED_LEDGER_FIELDS
        or binding["sequence_strictly_increasing"] is not True
        or binding["ledger_append_only"] is not True
        or binding["ledger_sealed_before_classification"] is not True
    ):
        _reject("F05-SPV2-RUN-BINDING", "run binding drift")
    if document.get("state_domains") != EXPECTED_STATE_DOMAINS:
        _reject("F05-SPV2-STATE-DOMAINS", "state domain drift")
    if document.get("initial_state") != EXPECTED_INITIAL_STATE:
        _reject("F05-SPV2-INITIAL", "initial state drift")
    if document.get("monotonicity") != EXPECTED_MONOTONICITY:
        _reject("F05-SPV2-MONOTONICITY", "monotonicity drift")
    if document.get("receipt_types") != EXPECTED_RECEIPTS:
        _reject("F05-SPV2-RECEIPTS", "receipt inventory drift")
    if document.get("resource_roles") != EXPECTED_RESOURCE_ROLES:
        _reject("F05-SPV2-RESOURCE-ROLES", "resource classification drift")
    role_sets = [set(EXPECTED_RESOURCE_ROLES[key]) for key in ("semantic_budget", "containment", "environment")]
    if any(left & right for index, left in enumerate(role_sets) for right in role_sets[index + 1 :]):
        _reject("F05-SPV2-RESOURCE-ROLES", "resource role overlap")
    _validate_transitions(document)
    if document.get("quiescence_requirements") != EXPECTED_QUIESCENCE:
        _reject("F05-SPV2-QUIESCENCE", "quiescence requirement drift")
    classifier = _validate_classifier(document)
    scenario_count = _validate_scenarios(document)
    order_pair_count = _validate_observation_orders(document)
    if document.get("proof_obligations") != EXPECTED_PROOF_OBLIGATIONS:
        _reject("F05-SPV2-PROOF-OBLIGATIONS", "proof obligation drift")
    if document.get("linux_refinement_candidates") != EXPECTED_LINUX_CANDIDATES:
        _reject("F05-SPV2-LINUX-CANDIDATES", "Linux candidate drift")
    if document.get("open_decisions") != EXPECTED_OPEN_DECISIONS:
        _reject("F05-SPV2-OPEN-DECISIONS", "open decision drift")
    if document.get("authorization") != EXPECTED_AUTHORIZATION:
        _reject("F05-SPV2-AUTHORIZATION", "authorization drift")
    return {
        "schema_version": 1,
        "status": "pre_normative_supervisor_v2_local_machine_contract_passed",
        "authority": "local_protocol_shape_and_finite_classifier_exploration_only",
        "transition_count": len(EXPECTED_TRANSITIONS),
        "receipt_type_count": len(EXPECTED_RECEIPTS),
        "required_scenario_count": scenario_count,
        "observation_order_pair_count": order_pair_count,
        "positive_guard_pairwise_disjoint": True,
        "nonquiescent_decision_impossible": True,
        "quiescent_classifier_total": True,
        **classifier,
        "machine_validator_implemented": True,
        "machine_exploration_passed": True,
        "machine_exploration_is_linux_refinement_proof": False,
        "protocol_normative": False,
        "supervisor_implemented": False,
        "executed_artifact_bound": False,
        "external_process_supervisor_bound": False,
        "result_taxonomy_closed": False,
        "ValidationContextDigest_issued": False,
        "evaluation_validated": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }


def validate_path(path: Path = PROTOCOL) -> tuple[dict[str, Any], bytes]:
    raw = read_once(path)
    document = parse_ascii_json(raw, str(path))
    result = validate_document(document, verify_predecessor_files=True)
    result["protocol_bytes"] = len(raw)
    result["protocol_sha256"] = sha256(raw)
    return result, raw


def main() -> int:
    try:
        result, _ = validate_path()
    except Reject as exc:
        print(json.dumps({"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail}, sort_keys=True, separators=(",", ":")))
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
