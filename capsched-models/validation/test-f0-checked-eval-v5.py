#!/usr/bin/env python3
"""Hostile regression for atomic immutable DL-F0-5 finite evaluation."""

from __future__ import annotations

import copy
import dataclasses
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


fixture = load_module("f0_checked_eval_fixture", HERE / "test-f0-core-syntax-v5.py")
eval_fixture = load_module("f0_checked_eval_value_fixture", HERE / "test-f0-eval-v5.py")
checked = load_module("f0_checked_eval_v5_test", HERE / "f0_checked_eval_v5.py")


def build_chain() -> tuple[Any, bytes, bytes, bytes, dict[str, Any], dict[str, Any]]:
    checker = fixture.semantics.CoreSyntaxChecker.for_internal_test_model(
        fixture.model_fixture()
    )
    checker.check()
    if checker.linked_model_snapshot is None:
        raise RuntimeError("fixture did not construct LinkedModel")
    contract = checked.eval_module.rules_module.load_contract()
    occurrences = checked.occurrence_module.materialize(checker, contract)
    return (
        checker,
        checker.source_snapshot.canonical_model_raw,
        checker.linked_model_snapshot.artifact_raw,
        occurrences.artifact_raw,
        checker.linked_model_snapshot.artifact(),
        occurrences.artifact(),
    )


def resource_profile(**overrides: int) -> bytes:
    profile = checked.eval_module.ResourceProfile().as_dict()
    profile.update(overrides)
    return checked.canonical_bytes(
        {"tag": "FINITE_EVALUATION_RESOURCE_PROFILE", **profile}
    )


def reissue_request(candidate: dict[str, Any]) -> bytes:
    payload = {
        key: value
        for key, value in candidate.items()
        if key != "checked_evaluation_request_construction_id"
    }
    candidate["checked_evaluation_request_construction_id"] = checked._typed_request_id(
        payload
    )
    return checked.canonical_bytes(candidate)


def expect_outcome(
    case_id: str,
    expected_tag: str,
    function: Callable[[], Any],
    expected_reason: str | None = None,
) -> dict[str, str]:
    outcome = function()
    result = outcome.as_dict()
    if result["outcome_tag"] != expected_tag:
        raise RuntimeError(
            f"{case_id}: expected {expected_tag}, got {result['outcome_tag']}: {result['body']}"
        )
    if expected_reason is not None:
        actual = result["body"].get("reject_id", result["body"].get("reason_id"))
        if actual != expected_reason:
            raise RuntimeError(f"{case_id}: expected {expected_reason}, got {actual}")
    forbidden_true = {
        "semantic_context_bound",
        "ValidationContextDigest_issued",
        "evaluation_validated",
        "CoreSyntaxWF",
        "InstanceWF",
        "F0_local_acceptance",
        "K0_G0_complete",
        "candidate_IR",
        "TLA_translation",
        "model_supported",
        "linux_behavior_change",
        "protection_claim",
    }
    if any(result[field] is not False for field in forbidden_true):
        raise RuntimeError(f"{case_id}: outcome promoted an authority claim")
    return {"id": case_id, "outcome_tag": expected_tag}


def main() -> int:
    (
        checker,
        source_raw,
        linked_raw,
        occurrences_raw,
        linked,
        occurrence_artifact,
    ) = build_chain()
    rows = occurrence_artifact["occurrences"]
    selected = next(
        row
        for row in rows
        if row["root_context"]["tag"] == "ACTION_PARAM_ROOT"
        and "PRE" in row["provenance"]
    )
    closed = next(row for row in rows if row["root_context"]["tag"] == "CLOSED_ROOT")
    profile_object = eval_fixture.profile_fixture(linked)
    pre_object = eval_fixture.state_fixture()
    profile_raw = checked.canonical_bytes(profile_object)
    parameter_raw = checked.canonical_bytes(eval_fixture.v_bool(True))
    pre_raw = checked.canonical_bytes(pre_object)

    request_raw = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
    )
    execute = lambda raw=request_raw, source=source_raw, linked_bytes=linked_raw, occ=occurrences_raw: checked.execute_checked_request(
        source_model_raw=source,
        linked_artifact_raw=linked_bytes,
        occurrence_index_raw=occ,
        request_raw=raw,
    )
    cases: list[dict[str, str]] = []
    cases.append(expect_outcome("source-derived-success", "SUCCESS", execute))
    first_success = execute().as_dict()
    second_success = execute().as_dict()
    if first_success != second_success:
        raise RuntimeError("atomic request replay is not deterministic")
    evaluation = first_success["body"]["evaluation_result"]
    if evaluation["usage"]["ground_value_nodes"] <= 0:
        raise RuntimeError("bound request usage omitted finite input decoding")
    context_identity = first_success["body"]["validation_context"]
    if context_identity["whole_pipeline_resource_envelope_complete"] is not False:
        raise RuntimeError("unfinished whole-pipeline envelope was promoted")
    if "checked_evaluation_result_construction_id" not in first_success["body"]:
        raise RuntimeError("success result omitted execution-context-bound identity")
    request_object = json.loads(request_raw.decode("ascii"))
    result_body = copy.deepcopy(first_success["body"])
    actual_result_id = result_body.pop("checked_evaluation_result_construction_id")
    expected_result_id = checked._typed_result_id(
        {
            "request_construction_id": request_object[
                "checked_evaluation_request_construction_id"
            ],
            "validation_context_id": context_identity["validation_context_id"],
            "outcome_tag": "SUCCESS",
            "body": result_body,
        }
    )
    if actual_result_id != expected_result_id:
        raise RuntimeError("result identity omitted request or execution context")

    profile_object["limits"][0]["value"] = 0
    pre_object["cells"].clear()
    if execute().as_dict() != first_success:
        raise RuntimeError("post-materialization object mutation changed immutable request")

    mutated_request = json.loads(request_raw.decode("ascii"))
    mutated_request["term"] = copy.deepcopy(selected["term"])
    cases.append(
        expect_outcome(
            "caller-term-injection",
            "REJECT",
            lambda: execute(reissue_request(mutated_request)),
            "F05-CFE-REQUEST-SHAPE",
        )
    )

    missing_parameter = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        pre_raw=pre_raw,
    )
    cases.append(
        expect_outcome(
            "missing-action-parameter",
            "REJECT",
            lambda: execute(missing_parameter),
            "F05-CFE-INPUT-DOMAIN",
        )
    )
    extra_post = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
        post_raw=pre_raw,
    )
    cases.append(
        expect_outcome(
            "extra-post-view",
            "REJECT",
            lambda: execute(extra_post),
            "F05-CFE-INPUT-DOMAIN",
        )
    )
    missing_pre = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
    )
    cases.append(
        expect_outcome(
            "missing-pre-view",
            "REJECT",
            lambda: execute(missing_pre),
            "F05-CFE-INPUT-DOMAIN",
        )
    )
    wrong_parameter = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=checked.canonical_bytes(eval_fixture.v_one()),
        pre_raw=pre_raw,
    )
    cases.append(
        expect_outcome(
            "wrong-parameter-sort",
            "REJECT",
            lambda: execute(wrong_parameter),
            "F05-EVAL-VALUE-SHAPE",
        )
    )

    closed_with_parameter = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=closed["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw if "PRE" in closed["provenance"] else None,
    )
    cases.append(
        expect_outcome(
            "closed-root-extra-parameter",
            "REJECT",
            lambda: execute(closed_with_parameter),
            "F05-CFE-INPUT-DOMAIN",
        )
    )

    forged_occurrence = copy.deepcopy(occurrence_artifact)
    selected_index = next(
        index
        for index, row in enumerate(forged_occurrence["occurrences"])
        if row["checked_term_occurrence_id"] == selected["checked_term_occurrence_id"]
    )
    forged_row = forged_occurrence["occurrences"][selected_index]
    forged_row["provenance"] = sorted(set(forged_row["provenance"]) | {"EVENT"})
    row_payload = {
        key: value
        for key, value in forged_row.items()
        if key != "checked_term_occurrence_id"
    }
    forged_row["checked_term_occurrence_id"] = checked.occurrence_module.typed_id(
        "CHECKED_TERM_OCCURRENCE_CONSTRUCTION",
        checked.occurrence_module.OCCURRENCE_DOMAIN,
        row_payload,
    )
    index_payload = {
        "construction_inputs": forged_occurrence["construction_inputs"],
        "occurrences": forged_occurrence["occurrences"],
    }
    forged_occurrence[
        "checked_term_occurrence_index_construction_id"
    ] = checked.occurrence_module.typed_id(
        "CHECKED_TERM_OCCURRENCE_INDEX_CONSTRUCTION",
        checked.occurrence_module.INDEX_DOMAIN,
        index_payload,
    )
    forged_occurrence_raw = checked.canonical_bytes(forged_occurrence)
    forged_occurrence_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=forged_occurrence_raw,
        checked_term_occurrence_id=forged_row["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
        event_raw=checked.canonical_bytes(eval_fixture.event_fixture()),
    )
    cases.append(
        expect_outcome(
            "rehashed-provenance-forgery",
            "REJECT",
            lambda: execute(
                forged_occurrence_request,
                occ=forged_occurrence_raw,
            ),
            "F05-CFE-OCCURRENCE-RECONSTRUCTION",
        )
    )

    forged_linked = copy.deepcopy(linked)
    forged_linked["linked_model"]["init"]["body"]["node"]["forged"] = True
    forged_linked_raw = checked.canonical_bytes(forged_linked)
    forged_linked_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=forged_linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
    )
    cases.append(
        expect_outcome(
            "linked-artifact-substitution",
            "REJECT",
            lambda: execute(
                forged_linked_request,
                linked_bytes=forged_linked_raw,
            ),
            "F05-CFE-LINKED-RECONSTRUCTION",
        )
    )

    unknown_id_request = json.loads(request_raw.decode("ascii"))
    unknown_id_request["checked_term_occurrence_id"]["sha256"] = "0" * 64
    cases.append(
        expect_outcome(
            "unknown-occurrence-id",
            "REJECT",
            lambda: execute(reissue_request(unknown_id_request)),
            "F05-CFE-OCCURRENCE-ID",
        )
    )
    bad_request_id = json.loads(request_raw.decode("ascii"))
    bad_request_id["checked_evaluation_request_construction_id"]["sha256"] = "0" * 64
    cases.append(
        expect_outcome(
            "request-id-substitution",
            "REJECT",
            lambda: execute(checked.canonical_bytes(bad_request_id)),
            "F05-CFE-REQUEST-ID",
        )
    )
    wrong_context_request = json.loads(request_raw.decode("ascii"))
    wrong_context_request["validation_context_id"]["sha256"] = "0" * 64
    cases.append(
        expect_outcome(
            "validation-context-replay",
            "REJECT",
            lambda: execute(reissue_request(wrong_context_request)),
            "F05-CFE-VALIDATION-CONTEXT-ID",
        )
    )
    duplicate_raw = request_raw.replace(
        b'{"artifact_id":',
        b'{"artifact_id":"duplicate","artifact_id":',
        1,
    )
    cases.append(
        expect_outcome(
            "duplicate-request-key",
            "REJECT",
            lambda: execute(duplicate_raw),
            "F05-CFE-DUPLICATE-KEY",
        )
    )

    mismatched_profile = eval_fixture.profile_fixture(linked)
    mismatched_profile["model_sha256"] = "0" * 64
    mismatch_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=checked.canonical_bytes(mismatched_profile),
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
    )
    cases.append(
        expect_outcome(
            "profile-model-mismatch",
            "REJECT",
            lambda: execute(mismatch_request),
            "F05-EVAL-PROFILE-MODEL",
        )
    )

    low_resource_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
        resource_profile_raw=resource_profile(max_ground_value_nodes=1),
    )
    cases.append(
        expect_outcome(
            "finite-input-resource-exhaustion",
            "INCONCLUSIVE_RESOURCE",
            lambda: execute(low_resource_request),
            "F05-EVAL-INCONCLUSIVE-RESOURCE",
        )
    )

    baseline_context = checked._VALIDATION_CONTEXT
    baseline_envelope = checked.OPERATOR_HARD_ENVELOPE
    try:
        checked.OPERATOR_HARD_ENVELOPE = dataclasses.replace(
            baseline_envelope,
            max_link_event_coordinates=0,
        )
        checked._VALIDATION_CONTEXT = None
        link_limited_request = checked.materialize_request(
            source_model_raw=source_raw,
            linked_artifact_raw=linked_raw,
            occurrence_index_raw=occurrences_raw,
            checked_term_occurrence_id=selected["checked_term_occurrence_id"],
            finite_profile_raw=profile_raw,
            parameter_raw=parameter_raw,
            pre_raw=pre_raw,
        )
        cases.append(
            expect_outcome(
                "operator-link-coordinate-resource",
                "INCONCLUSIVE_RESOURCE",
                lambda: execute(link_limited_request),
                "F05-LINK-INCONCLUSIVE-RESOURCE-EVENT-COORDINATES",
            )
        )
    finally:
        checked.OPERATOR_HARD_ENVELOPE = baseline_envelope
        checked._VALIDATION_CONTEXT = baseline_context
    unsupported_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
        resource_profile_raw=resource_profile(
            max_recursion_depth=checked.eval_module.values_module.HARD_MAX_RECURSION_DEPTH
            + 1
        ),
    )
    capped_success = execute(unsupported_request).as_dict()
    if capped_success["outcome_tag"] != "SUCCESS":
        raise RuntimeError("operator hard profile did not safely cap a larger requested ceiling")
    if capped_success["body"]["interpretation"]["operator_hard_profile_applied"] is not True:
        raise RuntimeError("operator hard profile truncation was hidden")

    original_decode = checked._decode_execution
    try:
        def injected_unsupported(*_args: Any, **_kwargs: Any) -> Any:
            raise checked.RequestUnsupported(
                "F05-CFE-TEST-UNSUPPORTED",
                "well-formed executable feature intentionally unsupported",
            )

        checked._decode_execution = injected_unsupported
        cases.append(
            expect_outcome(
                "explicit-well-formed-unsupported",
                "INCONCLUSIVE_UNSUPPORTED",
                execute,
                "F05-CFE-TEST-UNSUPPORTED",
            )
        )
    finally:
        checked._decode_execution = original_decode

    original_reconstruct = checked._reconstruct_chain
    try:
        def injected_failure(*_args: Any, **_kwargs: Any) -> Any:
            raise RuntimeError("injected internal defect")

        checked._reconstruct_chain = injected_failure
        cases.append(
            expect_outcome(
                "unexpected-defect-not-evidence",
                "INTERNAL_FAILURE",
                execute,
            )
        )
    finally:
        checked._reconstruct_chain = original_reconstruct

    for failure_type in (MemoryError, RecursionError):
        original_reconstruct = checked._reconstruct_chain
        try:
            def injected_host_failure(*_args: Any, _failure=failure_type, **_kwargs: Any) -> Any:
                raise _failure()

            checked._reconstruct_chain = injected_host_failure
            cases.append(
                expect_outcome(
                    f"generic-{failure_type.__name__.lower()}-not-resource-evidence",
                    "INTERNAL_FAILURE",
                    execute,
                )
            )
        finally:
            checked._reconstruct_chain = original_reconstruct

    context = checked.validation_context()
    module_name, module_object = context.module_graph[0]
    sys.modules[module_name] = object()
    try:
        cases.append(
            expect_outcome(
                "runtime-module-graph-substitution",
                "INTERNAL_FAILURE",
                execute,
            )
        )
    finally:
        sys.modules[module_name] = module_object

    original_read_once = checked.wire_validator.generator.checker.read_once
    original_load_generation = checked.wire_validator.load_generation
    original_static_load = checked.semantics_module.static_rules.load_contract
    original_eval_load = checked.eval_module.rules_module.load_contract
    try:
        def forbidden_filesystem_read(*_args: Any, **_kwargs: Any) -> Any:
            raise RuntimeError("captured request path performed a forbidden filesystem read")

        checked.wire_validator.generator.checker.read_once = forbidden_filesystem_read
        checked.wire_validator.load_generation = forbidden_filesystem_read
        checked.semantics_module.static_rules.load_contract = forbidden_filesystem_read
        checked.eval_module.rules_module.load_contract = forbidden_filesystem_read
        cases.append(
            expect_outcome(
                "post-context-filesystem-independence",
                "SUCCESS",
                execute,
            )
        )
    finally:
        checked.wire_validator.generator.checker.read_once = original_read_once
        checked.wire_validator.load_generation = original_load_generation
        checked.semantics_module.static_rules.load_contract = original_static_load
        checked.eval_module.rules_module.load_contract = original_eval_load

    false_parameter_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=checked.canonical_bytes(eval_fixture.v_bool(False)),
        pre_raw=pre_raw,
    )
    if (
        json.loads(false_parameter_request.decode("ascii"))[
            "checked_evaluation_request_construction_id"
        ]
        == json.loads(request_raw.decode("ascii"))[
            "checked_evaluation_request_construction_id"
        ]
    ):
        raise RuntimeError("request identity does not bind parameter bytes")
    changed_resource_request = checked.materialize_request(
        source_model_raw=source_raw,
        linked_artifact_raw=linked_raw,
        occurrence_index_raw=occurrences_raw,
        checked_term_occurrence_id=selected["checked_term_occurrence_id"],
        finite_profile_raw=profile_raw,
        parameter_raw=parameter_raw,
        pre_raw=pre_raw,
        resource_profile_raw=resource_profile(max_term_visits=999_999),
    )
    if (
        json.loads(changed_resource_request.decode("ascii"))[
            "checked_evaluation_request_construction_id"
        ]
        == json.loads(request_raw.decode("ascii"))[
            "checked_evaluation_request_construction_id"
        ]
    ):
        raise RuntimeError("request identity does not bind resource profile")

    try:
        checked.CheckedEvaluationOutcome(
            outcome_tag="SUCCESS",
            request_raw_sha256="0" * 64,
            request_identity_raw=checked.canonical_bytes({"status": "FORGED"}),
            body_raw=checked.canonical_bytes({"status": "FORGED"}),
            F0_local_acceptance=True,
        )
    except TypeError:
        pass
    else:
        raise RuntimeError("outcome constructor accepted authority self-promotion")

    output = {
        "schema_version": 1,
        "status": "checked_finite_evaluation_hostile_regression_passed",
        "case_count": len(cases),
        "cases": cases,
        "source_reconstruction_bound": True,
        "caller_term_gamma_delta_provenance_accepted": False,
        "complete_request_snapshot_bound": True,
        "result_taxonomy_dispatch_bound": True,
        "closed_result_taxonomy_bound": False,
        "local_validation_context_construction_bound": True,
        "ValidationContextDigest_issued": False,
        "captured_implementation_executed_directly": False,
        "whole_pipeline_resource_envelope_complete": False,
        "external_process_supervisor_bound": False,
        "operator_link_preallocation_meter_bound": True,
        "semantic_context_bound": False,
        "evaluation_validated": False,
        "CoreSyntaxWF": False,
        "InstanceWF": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "protection_claim": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
