#!/usr/bin/env python3
"""Cross-artifact semantic consistency checks for the compact current state.

The JSON schema checks shape.  This checker derives relationships across the
state ledger, claim register, Candidate-4 gate contract, current exact-input
record, G6 disposition, and the structured handoff projection.  It is invoked
by check-current-state.sh so there is one public state-validation entry point.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


EXIT_CLAIMS = (
    "ROOTSCHED-001",
    "RESIDENCY-001",
    "RESIDENCY-DYN-001",
    "ENTRY-001",
    "CODE-001",
    "STATE-001",
    "SVC-001",
    "MGMT-001",
    "CLUSTER-PART-001",
    "COMPOSE-001",
    "GRANULARITY-001",
    "EVIDENCE-001",
)

PROJECTION_BEGIN = "<!-- CURRENT-STATE-PROJECTION-BEGIN -->"
PROJECTION_END = "<!-- CURRENT-STATE-PROJECTION-END -->"


class ConsistencyError(ValueError):
    """A current-state relationship is internally inconsistent."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ConsistencyError(message)


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ConsistencyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle, object_pairs_hook=unique_object)
    except (OSError, json.JSONDecodeError) as error:
        raise ConsistencyError(f"cannot load {path}: {error}") from error
    require(isinstance(value, dict), f"top-level JSON object required: {path}")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def objects_by_id(items: list[dict[str, Any]], label: str) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in items:
        item_id = item.get("id")
        require(isinstance(item_id, str) and item_id, f"{label} has an invalid id")
        require(item_id not in result, f"duplicate {label} id: {item_id}")
        result[item_id] = item
    return result


def claim_statuses(claims: dict[str, Any]) -> dict[str, str]:
    indexed = objects_by_id(claims["claims"], "claim")
    missing = sorted(set(EXIT_CLAIMS) - set(indexed))
    require(not missing, f"missing final-plan claims: {missing}")
    return {claim_id: indexed[claim_id]["status"] for claim_id in EXIT_CLAIMS}


def current_projection(state: dict[str, Any], claims: dict[str, Any]) -> dict[str, Any]:
    current = state["evidence"]["current_candidate_inputs"]
    capture = state["evidence"]["authority_capture_contract"]
    g6 = capture["g6"]
    latest = next(
        attempt
        for attempt in g6["attempt_history"]
        if attempt["run_id"] == g6["latest_completed_attempt_run_id"]
    )
    return {
        "schema_version": 1,
        "updated": state["updated"],
        "project_phase": state["project"]["current_phase"],
        "completion": state["completion"],
        "claim_statuses": claim_statuses(claims),
        "candidate4": {
            "current_input_artifact": current["artifact_id"],
            "fast_validator_status": current["fast_validator_status"],
            "full_validator_status": current["full_validator_status"],
            "hostile_case_counts": current["hostile_case_counts"],
            "capture_contract_sha256": capture["canonical_sha256"],
            "closed_gates": capture["closed_gates"],
            "remaining_gates": capture["remaining_gates"],
            "clean_install": capture["clean_install"],
            "g6": {
                "gate_status": g6["gate_status"],
                "retry_eligible": g6["retry_eligible"],
                "complete_capture_available": g6["complete_capture_available"],
                "latest_completed_attempt": latest,
            },
            "g7": capture["g7"],
        },
    }


def validate_semantics(
    state: dict[str, Any],
    claims: dict[str, Any],
    contract: dict[str, Any],
    current_input: dict[str, Any],
    observation: dict[str, Any],
) -> None:
    completion = state["completion"]
    for key in (
        "final_compositional_model_complete",
        "linux_implementation_complete",
        "monitor_implementation_complete",
        "protection_evidenced",
        "cost_efficiency_evidenced",
        "deployment_ready",
    ):
        require(completion[key] is False, f"unsupported completion flag: {key}")

    statuses = claim_statuses(claims)
    require(statuses["ROOTSCHED-001"] == "model_supported", "ROOTSCHED state drift")
    require(statuses["RESIDENCY-001"] == "model_supported", "RESIDENCY state drift")
    require(statuses["EVIDENCE-001"] == "contract_defined", "EVIDENCE state drift")
    for claim_id in EXIT_CLAIMS:
        if claim_id not in {"ROOTSCHED-001", "RESIDENCY-001", "EVIDENCE-001"}:
            require(statuses[claim_id] == "open", f"unexpected claim status: {claim_id}")

    evidence = state["evidence"]
    historical = evidence["local_candidate_checkpoint"]
    require(
        historical["full_validator_status_at_checkpoint"] == "NOT_RUN",
        "historical pre-full checkpoint was rewritten",
    )
    require(
        historical["authority_disjoint_capture_at_checkpoint"] is False,
        "historical checkpoint authority was rewritten",
    )
    historical_counts = historical["hostile_case_counts_at_checkpoint"]
    require(
        historical_counts["total"]
        == historical_counts["child"] + historical_counts["parent"] + historical_counts["runner"],
        "historical hostile-case total mismatch",
    )

    current = evidence["current_candidate_inputs"]
    require(current["artifact_id"] == current_input["artifact_id"], "current input artifact drift")
    require(
        current["artifact_sha256"] == current_input["artifact_sha256"],
        "current input artifact digest drift",
    )
    require(
        current["fast_validator_status"]
        == current_input["local_regression"]["fast_validator_status"],
        "current fast-validator status drift",
    )
    require(
        current["full_validator_status"]
        == current_input["local_regression"]["full_validator_status"],
        "current full-validator status drift",
    )
    for key in ("child", "parent", "runner", "total"):
        source_key = f"{key}_hostile_cases" if key != "total" else "total_hostile_cases"
        require(
            current["hostile_case_counts"][key]
            == current_input["local_regression"][source_key],
            f"current hostile-case count drift: {key}",
        )
    counts = current["hostile_case_counts"]
    require(
        counts["total"] == counts["child"] + counts["parent"] + counts["runner"],
        "current hostile-case total mismatch",
    )

    capture = evidence["authority_capture_contract"]
    contract_gates = [item["id"] for item in contract["implementation_gates"]]
    closed = capture["closed_gates"]
    remaining = capture["remaining_gates"]
    require(len(closed) == len(set(closed)), "duplicate closed capture gate")
    require(len(remaining) == len(set(remaining)), "duplicate remaining capture gate")
    require(not set(closed) & set(remaining), "capture gate both closed and remaining")
    require(closed + remaining == contract_gates, "capture gate partition/order drift")
    require(closed == contract_gates[:5], "G1-G5 mechanism closure drift")
    require(remaining == contract_gates[5:], "G6/G7 remaining-gate drift")

    install = capture["clean_install"]
    g6 = capture["g6"]
    g7 = capture["g7"]
    attempts = objects_by_id(
        [{**attempt, "id": attempt["run_id"]} for attempt in g6["attempt_history"]],
        "G6 attempt",
    )
    require(g6["attempt_count"] == len(attempts), "G6 attempt count drift")
    latest_id = g6["latest_completed_attempt_run_id"]
    require(latest_id in attempts, "latest G6 attempt is absent from history")
    latest = attempts[latest_id]
    require(latest["status"] == "RAW_CAPTURE_INCOMPLETE", "latest G6 result drift")
    require(latest["observation_record"] == state["canonical_files"]["f0_c4_g6_incomplete_record"], "G6 observation path drift")
    require(latest["observation_sha256"] == observation["artifact_sha256"], "G6 observation digest drift")
    require(observation["run_id"] == latest_id, "G6 observation run-id drift")
    require(observation["raw_commit"]["capture_status"] == latest["status"], "G6 capture status drift")
    require(observation["raw_commit"]["candidate_bytes_positive_eligible"] is False, "incomplete G6 became positive-eligible")
    require(observation["raw_commit"]["reduction_performed"] is False, "incomplete G6 was reduced")
    require(observation["disposition"]["g6_closed"] is False, "incomplete G6 closed its gate")
    require(observation["disposition"]["g7_eligible"] is False, "incomplete G6 enabled G7")
    require(
        observation["captured_child_model_sha256"]
        != current_input["exact_inputs"]["f0_supervisor_lts_v3.py"],
        "repaired input did not change the rejected child-model bytes",
    )
    require(current_input["repair"]["counterexample_trace_added_to_fast_regression"] is True, "counterexample regression absent")
    require(current_input["repair"]["semantic_change"] is False, "repair unexpectedly changed semantics")

    require(g6["gate_status"] == "OPEN", "G6 closed without a complete capture")
    require(g6["complete_capture_available"] is False, "complete G6 bytes claimed absent evidence")
    require(g6["candidate_bytes_positive_eligible"] is False, "G6 raw bytes claimed positive")
    require(g7["gate_status"] == "BLOCKED", "G7 enabled before complete G6")
    require(g7["real_reduction_run"] is False, "G7 real reduction claimed before eligibility")
    require(g7["blocked_reason"] == "NO_COMPLETE_G6_CAPTURE", "G7 block reason drift")

    if install["status"] == "REINSTALL_REQUIRED_AFTER_INPUT_REPAIR":
        require(install["current_inputs_installed"] is False, "pending reinstall marked installed")
        require(g6["retry_eligible"] is False, "G6 retry enabled before clean reinstall")
        expected_input_status = "counterexample_repaired_locally_g6_retry_requires_clean_install"
        expected_phase = "f0_v5_c4_g6_open_reinstall_required"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_reinstall_required_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_reinstall_required_g7_blocked"
        expected_install_action = "counterexample_repaired_clean_install_pending"
        expected_full_action = "blocked_until_repaired_clean_install"
    elif install["status"] == "PASSED_FOR_REPAIRED_INPUTS":
        require(install["current_inputs_installed"] is True, "passed reinstall not marked installed")
        require(g6["retry_eligible"] is True, "G6 retry not enabled after clean reinstall")
        expected_input_status = "counterexample_repaired_clean_installed_g6_retry_eligible"
        expected_phase = "f0_v5_c4_g6_open_retry_eligible"
        expected_capture_status = "local_mechanism_g1_g5_closed_g6_open_retry_eligible_g7_blocked"
        expected_track_status = "open_candidate4_g1_g5_closed_g6_retry_eligible_g7_blocked"
        expected_install_action = "completed_clean_reviewed_install_for_repaired_inputs"
        expected_full_action = "g6_retry_eligible"
    else:
        raise ConsistencyError(f"unknown clean-install status: {install['status']}")

    require(current["status"] == expected_input_status, "current input/install status drift")
    require(state["project"]["current_phase"] == expected_phase, "project phase drift")
    require(capture["status"] == expected_capture_status, "capture status drift")

    tracks = objects_by_id(state["planned_tracks"], "planned track")
    require(tracks["ROOTSCHED-001"]["status"] == "model_supported_ec1", "ROOTSCHED track drift")
    require(tracks["RESIDENCY-001"]["status"] == "model_supported_ec1", "RESIDENCY track drift")
    require(tracks["EVIDENCE-001"]["status"].startswith("partial_"), "EVIDENCE track drift")
    require(tracks["RESIDENCY-DYN-001"]["status"] == expected_track_status, "RESIDENCY-DYN track drift")
    for track_id in (
        "ENTRY-001+CODE-001",
        "STATE-001+SVC-001+MGMT-001",
        "CLUSTER-PART-001",
        "COMPOSE-001",
        "GRANULARITY-001",
    ):
        require(tracks[track_id]["status"] == "open", f"open track drift: {track_id}")

    actions = objects_by_id(state["next_actions"], "next action")
    require(
        actions["F0-C4-AUTHORITY-DISJOINT-LAUNCHER"]["status"]
        == expected_install_action,
        "clean-install action drift",
    )
    require(
        actions["F0-C4-FULL-LOCAL"]["status"] == expected_full_action,
        "G6 next-action drift",
    )


def extract_handoff_projection(text: str) -> dict[str, Any]:
    require(text.count(PROJECTION_BEGIN) == 1, "handoff projection begin marker missing/duplicate")
    require(text.count(PROJECTION_END) == 1, "handoff projection end marker missing/duplicate")
    body = text.split(PROJECTION_BEGIN, 1)[1].split(PROJECTION_END, 1)[0].strip()
    match = re.fullmatch(r"```json\s*(\{.*\})\s*```", body, flags=re.DOTALL)
    require(match is not None, "handoff projection must be one JSON code block")
    try:
        value = json.loads(match.group(1), object_pairs_hook=unique_object)
    except json.JSONDecodeError as error:
        raise ConsistencyError(f"invalid handoff projection JSON: {error}") from error
    require(isinstance(value, dict), "handoff projection must be an object")
    return value


def validate_repo(repo_root: Path, *, self_test: bool) -> dict[str, Any]:
    state_path = repo_root / "capsched-ai/state/state.json"
    state = load_json(state_path)
    canonical = state["canonical_files"]

    def canonical_json(key: str) -> tuple[Path, dict[str, Any]]:
        path = repo_root / canonical[key]
        return path, load_json(path)

    claims_path, claims = canonical_json("assurance_register")
    contract_path, contract = canonical_json("f0_c4_capture_contract")
    current_path, current_input = canonical_json("f0_c4_current_input_contract")
    observation_path, observation = canonical_json("f0_c4_g6_incomplete_record")
    current_input["artifact_sha256"] = sha256_file(current_path)
    observation["artifact_sha256"] = sha256_file(observation_path)

    require(
        state["evidence"]["current_candidate_inputs"]["artifact_sha256"]
        == current_input["artifact_sha256"],
        "current-input record file digest mismatch",
    )
    latest = state["evidence"]["authority_capture_contract"]["g6"]["attempt_history"][-1]
    require(
        latest["observation_sha256"] == observation["artifact_sha256"],
        "G6 observation file digest mismatch",
    )
    for name, expected in current_input["exact_inputs"].items():
        path = repo_root / "capsched-models/validation" / name
        require(path.is_file(), f"current Candidate-4 input missing: {name}")
        require(sha256_file(path) == expected, f"current Candidate-4 input digest mismatch: {name}")

    validate_semantics(state, claims, contract, current_input, observation)

    handoff_path = repo_root / canonical["handoff"]
    projection = extract_handoff_projection(handoff_path.read_text(encoding="utf-8"))
    require(projection == current_projection(state, claims), "handoff/state projection drift")

    stable_pointer_requirements = {
        "capsched/README.md": "Volatile campaign status is intentionally not duplicated here",
        "capsched-models/index.md": "Volatile campaign status is intentionally not duplicated in this index",
        "capsched-models/plans/0006-final-compositional-model-completion-plan.md": "Volatile execution status is intentionally not duplicated in this plan",
    }
    for relative, sentence in stable_pointer_requirements.items():
        document = (repo_root / relative.removeprefix("capsched/")).read_text(
            encoding="utf-8"
        )
        normalized = " ".join(document.split())
        require(sentence in normalized, f"current-state pointer policy missing: {relative}")

    hostile_cases = 0
    if self_test:
        mutations: list[tuple[str, dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]] = []

        def add_state_mutation(label: str, mutate) -> None:
            changed = copy.deepcopy(state)
            mutate(changed)
            mutations.append((label, changed, claims, contract, current_input, observation))

        add_state_mutation(
            "stale planned-track status",
            lambda value: value["planned_tracks"][3].__setitem__(
                "status", "open_candidate4_capture_contract_g1_g2_closed_g3_g7_open"
            ),
        )
        add_state_mutation(
            "G7 enabled without complete G6",
            lambda value: value["evidence"]["authority_capture_contract"]["g7"].__setitem__(
                "gate_status", "OPEN"
            ),
        )
        add_state_mutation(
            "capture gate omitted",
            lambda value: value["evidence"]["authority_capture_contract"]["remaining_gates"].pop(),
        )
        add_state_mutation(
            "hostile count drift",
            lambda value: value["evidence"]["current_candidate_inputs"]["hostile_case_counts"].__setitem__(
                "total", 1
            ),
        )
        add_state_mutation(
            "retry/install relation drift",
            lambda value: value["evidence"]["authority_capture_contract"]["g6"].__setitem__(
                "retry_eligible",
                not value["evidence"]["authority_capture_contract"]["g6"]["retry_eligible"],
            ),
        )
        add_state_mutation(
            "observation identity drift",
            lambda value: value["evidence"]["authority_capture_contract"]["g6"]["attempt_history"][-1].__setitem__(
                "observation_sha256", "0" * 64
            ),
        )
        changed_claims = copy.deepcopy(claims)
        next(item for item in changed_claims["claims"] if item["id"] == "COMPOSE-001")["status"] = "model_supported"
        mutations.append(("claim status drift", state, changed_claims, contract, current_input, observation))
        changed_observation = copy.deepcopy(observation)
        changed_observation["raw_commit"]["candidate_bytes_positive_eligible"] = True
        mutations.append(("incomplete bytes promoted", state, claims, contract, current_input, changed_observation))

        for label, mutated_state, mutated_claims, mutated_contract, mutated_input, mutated_observation in mutations:
            try:
                validate_semantics(
                    mutated_state,
                    mutated_claims,
                    mutated_contract,
                    mutated_input,
                    mutated_observation,
                )
            except ConsistencyError:
                hostile_cases += 1
            else:
                raise ConsistencyError(f"self-test mutation passed: {label}")

    return {
        "status": "pass",
        "state": str(state_path.relative_to(repo_root)),
        "claims": str(claims_path.relative_to(repo_root)),
        "contract": str(contract_path.relative_to(repo_root)),
        "current_input": str(current_path.relative_to(repo_root)),
        "g6_observation": str(observation_path.relative_to(repo_root)),
        "handoff_projection": "exact",
        "hostile_self_test_cases": hostile_cases,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        result = validate_repo(arguments.repo_root.resolve(), self_test=arguments.self_test)
    except (ConsistencyError, KeyError, TypeError, StopIteration) as error:
        print(f"error: current-state semantic inconsistency: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
