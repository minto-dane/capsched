#!/usr/bin/env python3
"""Hostile mutations for the pre-normative F0 supervisor protocol v2."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
VALIDATOR_PATH = HERE / "validate-f0-supervisor-protocol-v2.py"


def _load_validator() -> Any:
    spec = importlib.util.spec_from_file_location("f0_supervisor_protocol_v2_validator", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load supervisor protocol validator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


validator = _load_validator()


def _fresh(baseline: dict[str, Any]) -> dict[str, Any]:
    return copy.deepcopy(baseline)


def _expect_document_reject(
    baseline: dict[str, Any],
    case_id: str,
    expected: str,
    mutate: Callable[[dict[str, Any]], None],
) -> dict[str, str]:
    document = _fresh(baseline)
    mutate(document)
    try:
        validator.validate_document(document)
    except validator.Reject as exc:
        if exc.reject_id != expected:
            raise AssertionError(f"{case_id}: expected {expected}, got {exc.reject_id}") from exc
        return {"id": case_id, "reject_id": exc.reject_id}
    raise AssertionError(f"{case_id}: mutation was accepted")


def _expect_raw_reject(case_id: str, expected: str, raw: bytes) -> dict[str, str]:
    try:
        document = validator.parse_ascii_json(raw, case_id)
        validator.validate_document(document)
    except validator.Reject as exc:
        if exc.reject_id != expected:
            raise AssertionError(f"{case_id}: expected {expected}, got {exc.reject_id}") from exc
        return {"id": case_id, "reject_id": exc.reject_id}
    raise AssertionError(f"{case_id}: raw mutation was accepted")


def _rule(document: dict[str, Any], rule_id: str) -> dict[str, Any]:
    for row in document["classification_semantics"]["positive_rules"]:
        if row["id"] == rule_id:
            return row
    raise AssertionError(rule_id)


def main() -> int:
    baseline_raw = validator.read_once(validator.PROTOCOL)
    baseline = validator.parse_ascii_json(baseline_raw, str(validator.PROTOCOL))
    validator.validate_document(baseline, verify_predecessor_files=True)

    cases: list[tuple[str, str, Callable[[dict[str, Any]], None]]] = []

    cases.extend(
        [
            ("unknown-top-level", "F05-SPV2-TOPLEVEL", lambda d: d.__setitem__("unknown", False)),
            ("missing-top-level", "F05-SPV2-TOPLEVEL", lambda d: d.pop("proof_obligations")),
            ("status-promotion", "F05-SPV2-IDENTITY", lambda d: d.__setitem__("status", "normative")),
            ("predecessor-digest", "F05-SPV2-PREDECESSOR", lambda d: d["predecessor"].__setitem__("artifact_sha256", "0" * 64)),
            ("guardian-role-removed", "F05-SPV2-ROLE-SEPARATION", lambda d: d["role_separation"]["guardian"].pop()),
            ("supervisor-parses-requester", "F05-SPV2-ROLE-SEPARATION", lambda d: d["role_separation"]["transport_supervisor"].append("PARSE_REQUESTER_BYTES")),
            ("trust-requester-parse", "F05-SPV2-TRUST-BOUNDARY", lambda d: d["trust_boundary"].__setitem__("requester_bytes_interpreted_by_transport_supervisor", True)),
            ("trust-result-json-parse", "F05-SPV2-TRUST-BOUNDARY", lambda d: d["trust_boundary"].__setitem__("result_json_interpreted_by_transport_supervisor", True)),
            ("transport-frame-semantic-evidence", "F05-SPV2-TRUST-BOUNDARY", lambda d: d["trust_boundary"].__setitem__("transport_valid_frame_is_semantic_evidence", True)),
            ("reference-evaluator-trusted-proof", "F05-SPV2-TRUST-BOUNDARY", lambda d: d["trust_boundary"].__setitem__("reference_evaluator_is_trusted_proof_producer", True)),
            ("host-compromise-covered", "F05-SPV2-TRUST-BOUNDARY", lambda d: d["trust_boundary"].__setitem__("host_kernel_compromise_covered", True)),
            ("run-id-removed", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"]["common_fields"].remove("RUN_ID")),
            ("guardian-id-removed", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"]["common_fields"].remove("GUARDIAN_ID")),
            ("run-id-reusable", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"].__setitem__("run_id_fresh_non_reusable", False)),
            ("ledger-sequence-not-strict", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"].__setitem__("sequence_strictly_increasing", False)),
            ("ledger-not-append-only", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"].__setitem__("ledger_append_only", False)),
            ("ledger-not-sealed", "F05-SPV2-RUN-BINDING", lambda d: d["run_binding"].__setitem__("ledger_sealed_before_classification", False)),
            ("state-eof-removed", "F05-SPV2-STATE-DOMAINS", lambda d: d["state_domains"]["stream"].remove("EOF_VALID")),
            ("state-stage-duplicate", "F05-SPV2-STATE-DOMAINS", lambda d: d["state_domains"]["stage"].append("RUNNING")),
            ("initial-running", "F05-SPV2-INITIAL", lambda d: d["initial_state"].__setitem__("stage", "RUNNING")),
            ("partial-stream-is-fault", "F05-SPV2-MONOTONICITY", lambda d: d["monotonicity"].__setitem__("partial_stream_is_not_fault", False)),
            ("wait-overwrite", "F05-SPV2-MONOTONICITY", lambda d: d["monotonicity"].__setitem__("wait_single_assignment_after_none", False)),
            ("fault-overwrite", "F05-SPV2-MONOTONICITY", lambda d: d["monotonicity"].__setitem__("fault_clean_to_sticky_fault_only", False)),
            ("receipt-run-genesis-removed", "F05-SPV2-RECEIPTS", lambda d: d["receipt_types"].remove("RUN_GENESIS")),
            ("receipt-outcome-verdict-removed", "F05-SPV2-RECEIPTS", lambda d: d["receipt_types"].remove("OUTCOME_CHECKER_VERDICT")),
            ("transport-limit-made-semantic", "F05-SPV2-RESOURCE-ROLES", lambda d: d["resource_roles"]["semantic_budget"].append("TRANSPORT_FRAME_LIMIT")),
            ("resource-role-overlap", "F05-SPV2-RESOURCE-ROLES", lambda d: d["resource_roles"]["environment"].append("WALL_DEADLINE")),
            ("containment-may-issue-resource", "F05-SPV2-RESOURCE-ROLES", lambda d: d["resource_roles"].__setitem__("only_semantic_budget_may_issue_resource", False)),
            ("release-before-sandbox", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][4].__setitem__("from_stage", ["LAUNCHER_CHARGED"])),
            ("classify-before-quiescence", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][18].__setitem__("from_stage", ["STOPPING"])),
            ("publish-before-decision", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][19].__setitem__("from_stage", ["QUIESCENT"])),
            ("abort-cannot-cover-decided", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][20]["from_stage"].remove("DECIDED")),
            ("abort-transition-removed", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"].pop()),
            ("abort-publishes", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][20].__setitem__("to_stage", "PUBLISHED")),
            ("unknown-transition-receipt", "F05-SPV2-TRANSITIONS", lambda d: d["transitions"][0].__setitem__("receipt", "WORKER_SELF_ATTEST")),
            ("scope-empty-quiescence-removed", "F05-SPV2-QUIESCENCE", lambda d: d["quiescence_requirements"].remove("EXECUTION_SCOPE_EMPTY_AND_CLOSED_TO_NEW_TASKS")),
            ("eof-quiescence-removed", "F05-SPV2-QUIESCENCE", lambda d: d["quiescence_requirements"].remove("STREAM_EOF_CLASSIFIED")),
            ("final-domain-unknown", "F05-SPV2-FINAL-DOMAINS", lambda d: d["finalization_domains"]["fault"].append("MAYBE")),
            ("final-domain-no-nonquiescent", "F05-SPV2-FINAL-DOMAINS", lambda d: d["finalization_domains"].__setitem__("quiescent", [True])),
            ("classifier-mode-priority", "F05-SPV2-CLASSIFIER-MODE", lambda d: d["classification_semantics"].__setitem__("mode", "EVENT_ORDER_PRIORITY")),
            ("fallback-resource", "F05-SPV2-CLASSIFIER-MODE", lambda d: d["classification_semantics"].__setitem__("fallback_outcome", "INCONCLUSIVE_RESOURCE")),
            ("nonquiescent-internal", "F05-SPV2-CLASSIFIER-MODE", lambda d: d["classification_semantics"].__setitem__("nonquiescent_outcome", "INTERNAL_FAILURE")),
            ("success-condition-missing-eof", "F05-SPV2-CLASSIFIER-CONDITIONS", lambda d: _rule(d, "SV2-CF-001")["conditions"].pop("stream")),
            ("success-condition-unknown", "F05-SPV2-CLASSIFIER-CONDITIONS", lambda d: _rule(d, "SV2-CF-001")["conditions"].__setitem__("stream", ["OPEN_PARTIAL"])),
            ("success-allows-truncated", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["stream"].append("EOF_ABSENT_OR_TRUNCATED")),
            ("success-allows-abnormal", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["wait"].append("ABNORMAL_OR_UNKNOWN")),
            ("success-allows-nonempty-scope", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["scope"].append("NONEMPTY_OR_ESCAPED")),
            ("success-allows-counter-drift", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["counters"].append("MISSING_OR_DRIFT")),
            ("success-allows-binding-mismatch", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["binding"].append("MISMATCH")),
            ("success-before-quiescence", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-001")["conditions"]["quiescent"].append(False)),
            ("quota-resource-allows-fault", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-006")["conditions"]["fault"].append("PRESENT")),
            ("quota-resource-ambiguous", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-006")["conditions"]["quota"].append("AMBIGUOUS_OR_ENVIRONMENT")),
            ("quota-resource-invalid-stream", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-006")["conditions"]["stream"].append("EOF_INVALID_OR_TRAILING")),
            ("unsupported-after-support-hit", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-004")["conditions"].__setitem__("checkpoint", ["WF_SUPPORTED"])),
            ("reject-without-receipt", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-002")["conditions"].__setitem__("typed_receipt", ["NONE_OR_INVALID"])),
            ("meter-without-meter-checkpoint", "F05-SPV2-CLASSIFIER-CONTRACT", lambda d: _rule(d, "SV2-CF-003")["conditions"].__setitem__("checkpoint", ["NOT_REACHED"])),
        ]
    )

    def duplicate_success(document: dict[str, Any]) -> None:
        duplicate = copy.deepcopy(_rule(document, "SV2-CF-001"))
        duplicate["id"] = "SV2-CF-999"
        document["classification_semantics"]["positive_rules"].append(duplicate)

    cases.append(("overlapping-success-guard", "F05-SPV2-CLASSIFIER-OVERLAP", duplicate_success))

    cases.extend(
        [
            ("scenario-removed", "F05-SPV2-SCENARIOS", lambda d: d["required_scenarios"].pop()),
            ("scenario-expected-flip", "F05-SPV2-SCENARIOS", lambda d: d["required_scenarios"][0].__setitem__("expected_outcome", "INTERNAL_FAILURE")),
            ("scenario-domain-escape", "F05-SPV2-SCENARIOS", lambda d: d["required_scenarios"][0]["state"].__setitem__("stream", "OPEN_PARTIAL")),
            ("observation-event-removed", "F05-SPV2-OBSERVATION-ORDER", lambda d: d["observation_order_pairs"][0]["order_b"].pop()),
            ("observation-event-duplicate", "F05-SPV2-OBSERVATION-ORDER", lambda d: d["observation_order_pairs"][0]["order_b"].append("STREAM_EOF")),
            ("observation-outcome-flip", "F05-SPV2-OBSERVATION-ORDER", lambda d: d["observation_order_pairs"][0].__setitem__("expected_outcome", "INTERNAL_FAILURE")),
            ("proof-obligation-removed", "F05-SPV2-PROOF-OBLIGATIONS", lambda d: d["proof_obligations"].pop()),
            ("linux-candidate-selected", "F05-SPV2-LINUX-CANDIDATES", lambda d: d["linux_refinement_candidates"].__setitem__("status", "SELECTED_AND_PROVED")),
            ("linux-cpu-max-conflation", "F05-SPV2-LINUX-CANDIDATES", lambda d: d["linux_refinement_candidates"]["charged_launch"].append("CPU_MAX_IS_TOTAL_CPU")),
            ("open-decision-hidden", "F05-SPV2-OPEN-DECISIONS", lambda d: d["open_decisions"].pop()),
        ]
    )

    authorization = baseline["authorization"]
    for field, value in authorization.items():
        replacement = not value

        def flip(document: dict[str, Any], *, key: str = field, new_value: bool = replacement) -> None:
            document["authorization"][key] = new_value

        cases.append((f"authorization-flip-{field}", "F05-SPV2-AUTHORIZATION", flip))

    results = [
        _expect_document_reject(baseline, case_id, expected, mutate)
        for case_id, expected, mutate in cases
    ]

    raw_cases = [
        (
            "duplicate-json-key",
            "F05-SPV2-DUPLICATE-KEY",
            baseline_raw.replace(b'"schema_version": 2,', b'"schema_version": 2,\n  "schema_version": 2,', 1),
        ),
        (
            "actual-non-ascii",
            "F05-SPV2-NON-ASCII-JSON",
            baseline_raw.replace(b'"project": "DomainLease-Linux"', '"project": "DomainLease-Linu\u00e9"'.encode("utf-8"), 1),
        ),
        (
            "escaped-non-ascii",
            "F05-SPV2-NON-ASCII-STRING",
            baseline_raw.replace(b'"project": "DomainLease-Linux"', b'"project": "DomainLease-\\u00e9"', 1),
        ),
        (
            "escaped-control",
            "F05-SPV2-CONTROL-STRING",
            baseline_raw.replace(b'"project": "DomainLease-Linux"', b'"project": "DomainLease-\\u0001"', 1),
        ),
        ("null-scalar", "F05-SPV2-UNSAFE-SCALAR", b'{"x":null}'),
        ("float-scalar", "F05-SPV2-FLOAT", b'{"x":1.0}'),
        ("negative-integer", "F05-SPV2-NEGATIVE-INTEGER", b'{"x":-1}'),
        ("integer-digit-limit", "F05-SPV2-INTEGER-DIGITS", b'{"x":' + b"9" * (validator.MAX_INTEGER_DIGITS + 1) + b"}"),
        ("depth-limit", "F05-SPV2-DEPTH", b'{"x":' + b"[" * (validator.MAX_DEPTH + 2) + b"0" + b"]" * (validator.MAX_DEPTH + 2) + b"}"),
        ("file-size-limit", "F05-SPV2-FILE-SIZE", b"{}" + b" " * validator.MAX_BYTES),
    ]
    results.extend(_expect_raw_reject(*case) for case in raw_cases)

    output = {
        "schema_version": 1,
        "status": "pre_normative_supervisor_v2_hostile_mutations_passed",
        "authority": "local_protocol_mutation_regression_only",
        "baseline_protocol_sha256": validator.sha256(baseline_raw),
        "case_count": len(results),
        "cases_rejected_at_expected_id": len(results),
        "cases": results,
        "machine_validator_implemented": True,
        "machine_exploration_passed": True,
        "machine_exploration_is_linux_refinement_proof": False,
        "fresh_hostile_review_complete": False,
        "protocol_normative": False,
        "supervisor_implemented": False,
        "external_process_supervisor_bound": False,
        "result_taxonomy_closed": False,
        "ValidationContextDigest_issued": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
