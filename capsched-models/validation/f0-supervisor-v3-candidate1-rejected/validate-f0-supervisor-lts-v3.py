#!/usr/bin/env python3
"""Validate supervisor v3 candidate-1 without granting F0 or G0 credit."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import asdict
from hashlib import sha256
from pathlib import Path

import f0_supervisor_lts_v3 as child
import f0_supervisor_orchestrator_v3 as orchestrator


HERE = Path(__file__).resolve().parent
INPUT_FILES = (
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "validate-f0-supervisor-lts-v3.py",
)


def file_hash(path: Path) -> str:
    hasher = sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def input_hashes() -> dict[str, str]:
    return {name: file_hash(HERE / name) for name in INPUT_FILES}


def run_test(path: Path) -> dict[str, object]:
    environment = dict(os.environ)
    environment["PYTHONPATH"] = str(HERE)
    completed = subprocess.run(
        [sys.executable, str(path)],
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    return {
        "path": path.name,
        "returncode": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
        "passed": completed.returncode == 0 and "PASS" in completed.stdout,
    }


def component_result(component: str) -> dict[str, object]:
    if component == "tests":
        tests = [
            run_test(HERE / "test-f0-supervisor-lts-v3-mutations.py"),
            run_test(HERE / "test-f0-supervisor-orchestrator-v3-mutations.py"),
        ]
        return {
            "component": component,
            "tests": tests,
            "passed": all(test["passed"] for test in tests),
        }
    if component == "child-producer":
        result = asdict(child.explore("PRODUCER"))
        return {"component": component, "result": result}
    if component == "child-checker":
        result = asdict(child.explore("CHECKER"))
        return {"component": component, "result": result}
    if component == "diamonds-producer":
        return {
            "component": component,
            "result": child.check_semantic_diamonds("PRODUCER"),
        }
    if component == "diamonds-checker":
        return {
            "component": component,
            "result": child.check_semantic_diamonds("CHECKER"),
        }
    if component == "orchestrator":
        return {"component": component, "result": orchestrator.explore()}
    raise ValueError(component)


def invoke_component(component: str) -> dict[str, object]:
    environment = dict(os.environ)
    environment["PYTHONPATH"] = str(HERE)
    completed = subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), "--component", component],
        cwd=HERE,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"component {component} failed rc={completed.returncode}: "
            f"{completed.stderr.strip()}"
        )
    marker = "RESULT_JSON="
    lines = [line for line in completed.stdout.splitlines() if line.startswith(marker)]
    if len(lines) != 1:
        raise RuntimeError(f"component {component} returned no unique JSON result")
    return json.loads(lines[0][len(marker) :])


def child_result_ok(result: dict[str, object]) -> bool:
    return bool(
        result["terminal_state_count"] > 0
        and result["nonterminal_deadlock_count"] == 0
        and result["states_without_terminal_path"] == 0
        and result["winner_overwrite_count"] == 0
        and result["protection_breach_terminal_count"] > 0
        and result["hostile_bypass_explicit"] is True
        and result["coaccessibility_only"] is True
        and result["universal_termination_proved"] is False
        and result["infinite_stutter_counterexample_present"] is True
        and result["management_domain_refinement_proved"] is False
        and result["monitor_protection_refinement_proved"] is False
        and result["external_assumptions_discharged"] is False
        and result["linux_refinement_proved"] is False
        and result["semantic_verdict_issued"] is False
        and result["ordered_trace_states_exhaustively_enumerated"] is True
    )


def full_result() -> dict[str, object]:
    before = input_hashes()
    order = (
        "tests",
        "child-producer",
        "child-checker",
        "diamonds-producer",
        "diamonds-checker",
        "orchestrator",
    )
    components = {name: invoke_component(name) for name in order}
    after = input_hashes()

    producer = components["child-producer"]["result"]
    checker = components["child-checker"]["result"]
    producer_actions = set(producer["reachable_action_ids"])
    checker_actions = set(checker["reachable_action_ids"])
    combined_actions = producer_actions | checker_actions
    declared_actions = set(child.ACTION_IDS)
    child_registry = {
        "declared_action_count": len(declared_actions),
        "combined_reachable_action_count": len(combined_actions),
        "missing_actions": sorted(declared_actions - combined_actions),
        "undeclared_actions": sorted(combined_actions - declared_actions),
        "exact": combined_actions == declared_actions,
    }
    orch = components["orchestrator"]["result"]
    orch_ok = bool(
        orch["nonterminal_deadlock_count"] == 0
        and orch["states_without_terminal_path"] == 0
        and orch["missing_actions"] == []
        and orch["undeclared_actions"] == []
        and orch["semantic_verdict_always_absent"] is True
        and orch["published_artifact_type"] == "LOCAL_DISPOSITION_CAPSULE"
        and orch["external_assumptions_discharged"] is False
        and orch["durable_store_refinement_proved"] is False
        and orch["issuance_registry_refinement_proved"] is False
        and orch["global_nonce_uniqueness_proved"] is False
        and orch["symbolic_authentication_discharged"] is False
        and orch["exact_state_identity_explored"] is True
        and orch["child_terminal_trace_replay_checked"] is True
        and orch["durable_abandonment_ack_required"] is True
        and orch["coaccessibility_only"] is True
        and orch["universal_termination_proved"] is False
        and orch["infinite_stutter_counterexample_present"] is True
        and orch["assurance_breach_explicit"] is True
        and orch["assurance_breach_terminal_count"] > 0
        and orch["guardian_survivability_proved"] is False
        and orch["external_semantic_verdict_issued"] is False
    )
    local_candidate = bool(
        before == after
        and components["tests"]["passed"]
        and child_result_ok(producer)
        and child_result_ok(checker)
        and components["diamonds-producer"]["result"]["passed"]
        and components["diamonds-checker"]["result"]["passed"]
        and child_registry["exact"]
        and orch_ok
    )
    return {
        "schema_version": 1,
        "artifact_id": "dynamic-residency-f0-v5-supervisor-v3-candidate1-full-local-result",
        "status": (
            "LOCAL_EXECUTABLE_CANDIDATE_ONLY"
            if local_candidate
            else "LOCAL_CANDIDATE_REJECTED"
        ),
        "input_hashes_before": before,
        "input_hashes_after": after,
        "immutable_input_check": before == after,
        "components": components,
        "child_action_registry": child_registry,
        "open_refinement_obligations": {
            "child": list(child.OPEN_REFINEMENT_OBLIGATIONS),
            "orchestrator": list(orchestrator.OPEN_REFINEMENT_OBLIGATIONS),
        },
        "authorization": {
            "local_executable_candidate": local_candidate,
            "bounded_ordered_receipt_state_space_exhaustive": bool(
                producer["ordered_trace_states_exhaustively_enumerated"]
                and checker["ordered_trace_states_exhaustively_enumerated"]
            ),
            "unbounded_ordered_receipt_state_space_exhaustive": False,
            "external_authentication_assumption_discharged": False,
            "linux_refinement": False,
            "monitor_refinement": False,
            "resource_causality_implemented": False,
            "durable_store_refinement": False,
            "checker_soundness": False,
            "external_review": False,
            "semantic_verdict_issued": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "candidate_IR": False,
            "TLA_translation": False,
            "model_supported": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
    }


def fast_result() -> dict[str, object]:
    before = input_hashes()
    tests = component_result("tests")
    orch = component_result("orchestrator")
    after = input_hashes()
    passed = bool(
        before == after
        and tests["passed"]
        and orch["result"]["nonterminal_deadlock_count"] == 0
        and orch["result"]["states_without_terminal_path"] == 0
        and orch["result"]["missing_actions"] == []
        and orch["result"]["semantic_verdict_always_absent"] is True
        and orch["result"]["assurance_breach_explicit"] is True
        and orch["result"]["assurance_breach_terminal_count"] > 0
        and orch["result"]["guardian_survivability_proved"] is False
    )
    return {
        "schema_version": 1,
        "status": "FAST_LOCAL_REGRESSION_PASS" if passed else "FAST_LOCAL_REGRESSION_REJECT",
        "input_hashes_before": before,
        "input_hashes_after": after,
        "tests": tests,
        "orchestrator": orch,
        "authorization": {
            "fast_local_regression": passed,
            "full_child_reachability": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--component",
        choices=(
            "tests",
            "child-producer",
            "child-checker",
            "diamonds-producer",
            "diamonds-checker",
            "orchestrator",
        ),
    )
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()

    if arguments.component:
        result = component_result(arguments.component)
        print("RESULT_JSON=" + json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0

    result = full_result() if arguments.full else fast_result()
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    if arguments.full:
        return 0 if result["authorization"]["local_executable_candidate"] else 1
    return 0 if result["authorization"]["fast_local_regression"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
