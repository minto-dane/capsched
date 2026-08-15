#!/usr/bin/env python3
"""Validate the bounded Candidate-4 Rust child-refinement checkpoint."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys


RECORD = "f0-c4-rust-child-transition-refinement-checkpoint-v1.json"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_CLOSED = {
    "all_declared_child_actions_have_exact_witness_edges",
    "bounded_child_state_and_transition_differential",
    "canonical_behavioral_projection_encoding",
    "digest_collisions_resolved_by_full_equality",
    "no_third_party_rust_dependencies",
    "reproducible_rust_binary_from_distinct_roots",
    "rust_instance_wf_and_evidence_wf_independent_checks",
    "shared_receipt_history_preserves_canonical_behavior",
}
EXPECTED_OPEN = {
    "authority_disjoint_clean_install",
    "child_exhaustive_reachability_and_commutation",
    "deterministic_multiworker_and_external_memory",
    "full_295_child_hostile_fixture_parity",
    "parent_orchestrator_transition_and_hostile_refinement",
    "result_schema_and_capture_integration",
}


class ValidationError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def strict_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, object]:
    with path.open(encoding="utf-8") as stream:
        value = json.load(
            stream,
            object_pairs_hook=strict_object,
            parse_constant=lambda token: (_ for _ in ()).throw(
                ValidationError(f"non-finite JSON number: {token}")
            ),
        )
    require(isinstance(value, dict), "checkpoint root must be an object")
    return value


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(repo_root: Path) -> dict[str, object]:
    validation_root = repo_root / "capsched-models/validation"
    record = load_json(validation_root / RECORD)
    require(
        set(record)
        == {
            "artifact_id",
            "schema_version",
            "status",
            "normative_model",
            "rust_refinement",
            "differential_results",
            "representation",
            "reproducible_build",
            "closed_subgates",
            "open_subgates",
            "disposition",
        },
        "checkpoint top-level fields differ",
    )
    require(
        record["artifact_id"]
        == "f0-c4-rust-child-transition-refinement-checkpoint-v1",
        "checkpoint artifact id differs",
    )
    require(record["schema_version"] == 1, "checkpoint schema version differs")
    require(
        record["status"]
        == "child_transition_independent_wf_and_59_hostile_wf_fixture_slice_pass_parent_and_exhaustive_gates_open",
        "checkpoint status differs",
    )

    normative = record["normative_model"]
    require(isinstance(normative, dict), "normative model record differs")
    require(normative.get("authority") == "PYTHON_ONLY", "Python authority drift")
    normative_path = normative.get("path")
    normative_sha = normative.get("sha256")
    require(isinstance(normative_path, str), "normative path differs")
    require(isinstance(normative_sha, str) and SHA256.fullmatch(normative_sha), "normative hash differs")
    require(file_sha256(repo_root / normative_path) == normative_sha, "normative model bytes drifted")

    rust = record["rust_refinement"]
    require(isinstance(rust, dict), "Rust refinement record differs")
    require(rust.get("third_party_dependency_count") == 0, "Rust dependencies drifted")
    require(
        rust.get("wire_schema") == "F0-C4-RUST-DIFFERENTIAL-V1",
        "Rust wire schema drifted",
    )
    engine_path = rust.get("path")
    hashes = rust.get("input_sha256")
    require(isinstance(engine_path, str) and isinstance(hashes, dict), "Rust input manifest differs")
    engine_root = repo_root / engine_path
    actual_files = {
        str(path.relative_to(engine_root))
        for path in engine_root.rglob("*")
        if path.is_file()
        and "target" not in path.relative_to(engine_root).parts
        and "__pycache__" not in path.relative_to(engine_root).parts
    }
    require(actual_files == set(hashes), "Rust input file set drifted")
    for relative, expected_hash in hashes.items():
        require(isinstance(expected_hash, str) and SHA256.fullmatch(expected_hash), f"invalid input hash: {relative}")
        require(file_sha256(engine_root / relative) == expected_hash, f"Rust input drifted: {relative}")

    cargo_toml = (engine_root / "Cargo.toml").read_text(encoding="utf-8")
    cargo_lock = (engine_root / "Cargo.lock").read_text(encoding="utf-8")
    dependency_section = cargo_toml.split("[dependencies]", 1)[1].split("[profile.release]", 1)[0]
    require(not dependency_section.strip(), "Cargo dependency section is not empty")
    require(cargo_lock.count("[[package]]") == 1, "Cargo lock contains another package")

    results = record["differential_results"]
    require(isinstance(results, dict), "differential result record differs")
    require(
        set(results)
        == {
            "setup_closure",
            "bounded_exact_prefix",
            "all_action_trace_corpus",
            "bounded_wide_stats",
            "independent_wf_prefix",
            "hostile_wf_fixture_slice",
        },
        "differential result set differs",
    )
    setup = results.get("setup_closure", {})
    prefix = results.get("bounded_exact_prefix", {})
    traces = results.get("all_action_trace_corpus", {})
    wide = results.get("bounded_wide_stats", {})
    independent_wf = results.get("independent_wf_prefix", {})
    hostile_wf = results.get("hostile_wf_fixture_slice", {})
    require(
        setup.get("status") == "PASS_BYTE_EXACT"
        and setup.get("producer", {}).get("states") == 57
        and setup.get("producer", {}).get("edges") == 58
        and setup.get("checker", {}).get("states") == 57
        and setup.get("checker", {}).get("edges") == 58,
        "setup differential result differs",
    )
    require(
        prefix.get("status") == "PASS_BYTE_EXACT"
        and prefix.get("expanded_sources") == 1000
        and prefix.get("producer", {}).get("states") == 6410
        and prefix.get("producer", {}).get("edges") == 12212
        and prefix.get("checker", {}).get("states") == 6410
        and prefix.get("checker", {}).get("edges") == 12212,
        "exact prefix result differs",
    )
    require(
        traces.get("status") == "PASS_BYTE_EXACT"
        and traces.get("trace_count") == 17
        and traces.get("declared_action_count") == 56
        and traces.get("observed_action_count") == 56
        and traces.get("repeated_rust_runs_per_trace") == 2,
        "all-action trace result differs",
    )
    require(
        wide.get("status")
        == "PASS_EXACT_CARDINALITY_AND_ACTION_MULTIPLICITY_DIAGNOSTIC"
        and wide.get("expanded_sources") == 10000
        and wide.get("producer", {}).get("states") == 52764
        and wide.get("producer", {}).get("edges") == 118552
        and wide.get("checker", {}).get("states") == 52764
        and wide.get("checker", {}).get("edges") == 118552,
        "wide diagnostic result differs",
    )
    require(
        independent_wf.get("status")
        == "PASS_INDEPENDENT_RUST_INSTANCE_AND_EVIDENCE_WF"
        and independent_wf.get("expanded_sources") == 1000
        and independent_wf.get("rust_runs_per_role") == 2
        and independent_wf.get("producer", {}).get("states") == 6410
        and independent_wf.get("producer", {}).get("edges") == 12212
        and independent_wf.get("producer", {}).get("wf_checks") == 12213
        and independent_wf.get("checker", {}).get("states") == 6410
        and independent_wf.get("checker", {}).get("edges") == 12212
        and independent_wf.get("checker", {}).get("wf_checks") == 12213,
        "independent Rust WF result differs",
    )
    require(
        hostile_wf.get("status") == "PASS_BYTE_EXACT_PARTIAL_SLICE"
        and hostile_wf.get("case_count") == 59
        and hostile_wf.get("grant_cases") == 10
        and hostile_wf.get("state_cases") == 49
        and hostile_wf.get("malformed_fixture_cases") == 11
        and hostile_wf.get("remaining_original_case_credits") == 236
        and hostile_wf.get("case_count")
        + hostile_wf.get("remaining_original_case_credits")
        == 295
        and hostile_wf.get("rust_runs") == 2
        and hostile_wf.get("complete_295_case_parity") is False
        and hostile_wf.get("fixture_sha256")
        == "e6b974694d79f210bce7d9d79f598433951b708b377f696ea24d2babdf7edc21"
        and hostile_wf.get("result_sha256")
        == "5d8155140245051b6e1d0308d910dbfe1e321490d253530aeefe20600bef7c90",
        "hostile WF fixture slice differs",
    )

    representation = record["representation"]
    require(
        representation.get("digest_match_resolution")
        == "FULL_CANONICAL_BYTE_EQUALITY_REQUIRED"
        and representation.get("forced_same_digest_distinct_state_case") == "PASS"
        and representation.get("receipt_history") == "IMMUTABLE_SHARED_LOSSLESS_NODES",
        "collision or receipt-history policy drifted",
    )
    build = record["reproducible_build"]
    require(
        build.get("status") == "PASS_BYTE_IDENTICAL"
        and build.get("distinct_source_roots") == 2
        and build.get("binary_bytes") == 592120
        and build.get("binary_sha256")
        == "2fd58730d3bf2884eb436177fc996f4b857d44307427051ca052e22ad8bfbe36",
        "reproducible build record differs",
    )
    for key in ("binary_sha256", "cargo_sha256", "rustc_sha256"):
        require(SHA256.fullmatch(build.get(key, "")), f"invalid build hash: {key}")

    closed = record["closed_subgates"]
    opened = record["open_subgates"]
    require(set(closed) == EXPECTED_CLOSED and all(closed.values()), "closed subgates differ")
    require(set(opened) == EXPECTED_OPEN and all(opened.values()), "open subgates differ")
    disposition = record["disposition"]
    require(
        disposition
        == {
            "claim_credit": False,
            "f0_local_acceptance": False,
            "g6_retry_eligible": False,
            "g6_status": "OPEN",
            "g7_status": "BLOCKED",
            "linux_or_monitor_hot_path_changed": False,
            "production_performance_claim": False,
            "protection_claim": False,
            "rust_model_authority": False,
        },
        "checkpoint disposition overclaims authority",
    )
    return {
        "artifact_id": "f0-c4-rust-child-refinement-structural-validation-v1",
        "claim_credit": False,
        "input_files": len(actual_files),
        "open_subgates": len(opened),
        "status": "pass",
    }


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    try:
        result = validate(repo_root)
    except (OSError, KeyError, TypeError, ValueError, ValidationError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
