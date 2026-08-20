#!/usr/bin/env python3
"""Bind the installed reducer policy to the current exact Candidate-4 inputs."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
from types import ModuleType
from typing import Any


HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
STATE = REPO_ROOT / "capsched-ai/state/state.json"
REDUCER = HERE / "f0_c4_post_run_reducer.py"
REDUCTION_TEST = HERE / "test-reduction-boundary.py"
VALIDATOR = HERE.parent / "validate-f0-supervisor-lts-v3.py"


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"JSON object required: {path}")
    return value


def load_module(name: str, path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise AssertionError(f"cannot load source module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def static_registry_result() -> dict[str, Any]:
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    completed = subprocess.run(
        [sys.executable, str(VALIDATOR), "--component", "static-registries"],
        cwd=VALIDATOR.parent,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=60,
        check=False,
    )
    if completed.returncode != 0 or completed.stderr:
        raise AssertionError(
            "current static-registry validation failed: "
            f"rc={completed.returncode} stderr={completed.stderr!r}"
        )
    frames = [
        line.removeprefix("RESULT_JSON=")
        for line in completed.stdout.splitlines()
        if line.startswith("RESULT_JSON=")
    ]
    if len(frames) != 1:
        raise AssertionError(f"expected one static RESULT_JSON frame: {completed.stdout!r}")
    value = json.loads(frames[0])
    if not isinstance(value, dict) or value.get("passed") is not True:
        raise AssertionError("current static-registry result is not a passing object")
    return value


def main() -> None:
    state = load_json(STATE)
    canonical = state["canonical_files"]
    current = load_json(REPO_ROOT / canonical["f0_c4_current_input_contract"])
    reducer = load_module("f0_c4_post_run_reducer", REDUCER)
    fixture = load_module("test_reduction_boundary", REDUCTION_TEST)

    claim = current["claim_registry"]
    expected_inputs = {
        Path(claim["path"]).name: claim["sha256"],
        **current["exact_inputs"],
    }
    expected_root = hashlib.sha256(
        json.dumps(expected_inputs, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    if (
        reducer.INPUT_DIGESTS != expected_inputs
        or fixture.INPUT_DIGESTS != expected_inputs
        or reducer.INPUT_ROOT_SHA256 != expected_root
        or fixture.INPUT_ROOT_SHA256 != expected_root
        or current["local_regression"]["input_root_sha256"] != expected_root
    ):
        raise AssertionError("reducer exact-input or input-root binding drifted")

    static = static_registry_result()
    expected_registry = current["local_regression"]["semantic_registry_sha256"]
    if (
        static["semantic_registry_sha256"] != expected_registry
        or static["worker_provenance"]["input_root_sha256"] != expected_root
        or reducer.SEMANTIC_REGISTRY_SHA256 != expected_registry
        or fixture.static_result()["semantic_registry_sha256"] != expected_registry
    ):
        raise AssertionError("reducer semantic-registry binding drifted")

    capture = state["evidence"]["authority_capture_contract"]
    if (
        reducer.CONTRACT_SHA256 != capture["canonical_sha256"]
        or fixture.CONTRACT_SHA256 != capture["canonical_sha256"]
    ):
        raise AssertionError("reducer or reduction fixture contract binding drifted")

    print("F0_C4_REDUCER_CURRENT_INPUT_BINDING_PASS cases=3")


if __name__ == "__main__":
    main()
