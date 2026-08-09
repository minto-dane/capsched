#!/usr/bin/env python3
"""Validate a RESIDENCY-001 Evidence Capsule without producer summaries."""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from typing import Any


CONTRACT_ID = "RESIDENCY-001-TLC-v1"
TARGET_CLAIM = "RESIDENCY-001"
EXPECTED_CONTRACT_SHA256 = (
    "6bb792016d74172501f75556924a6a5eb7819443f637408a37254d05b2e3ba1c"
)
ORIGIN_COMMIT = "9f1eaae410fd4878d7e0e04bf757377434980b86"
ORIGIN_TREE = "736a9484b931b79d6374c468831b6c0d78353fe2"
TOOL_SHA256 = (
    "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
)
FORMAL_PREFIX = (
    "capsched-models/formal/0148-bounded-domain-residency-model/"
)
MODEL_NAME = "BoundedDomainResidency.tla"
MAX_JSON_BYTES = 2 * 1024 * 1024
MAX_LOG_BYTES = 8 * 1024 * 1024
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
RUN_ID_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


class ValidationError(RuntimeError):
    pass


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON constant: {value}")


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json_bytes(data: bytes, label: str) -> Any:
    try:
        text = data.decode("utf-8", errors="strict")
        return json.loads(
            text,
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeDecodeError, ValueError, json.JSONDecodeError) as error:
        raise ValidationError(f"{label} is not strict JSON: {error}") from error


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def read_regular(path: Path, maximum: int, label: str) -> bytes:
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValidationError(f"{label} is not a regular file")
    if info.st_size > maximum:
        raise ValidationError(f"{label} exceeds {maximum} bytes")
    data = path.read_bytes()
    after = path.lstat()
    before_key = (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns)
    after_key = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
    if before_key != after_key:
        raise ValidationError(f"{label} changed while being read")
    return data


def parse_stats(log: str) -> tuple[int, int, int] | None:
    match = re.search(
        r"([0-9][0-9,]*) states generated, "
        r"([0-9][0-9,]*) distinct states found, "
        r"0 states left on queue\.\s+"
        r"The depth of the complete state graph search is ([0-9]+)\.",
        log,
    )
    if match is None:
        return None
    generated, distinct, depth = match.groups()
    return (int(generated.replace(",", "")),
            int(distinct.replace(",", "")), int(depth))


def is_safe_run(run: dict[str, Any]) -> bool:
    return "expected_generated_states" in run


def expected_commands(contract: dict[str, Any]) -> dict[str, Any]:
    workers = str(contract["tool"]["workers"])
    runs = []
    for run in contract["expected_runs"]:
        runs.append({
            "id": run["id"],
            "cwd": "inputs/model",
            "argv": [
                "java",
                "-XX:+UseParallelGC",
                "-cp",
                "../tools/tla2tools.jar",
                "tlc2.TLC",
                "-workers",
                workers,
                "-metadir",
                f"../../work/states-{run['id']}",
                "-config",
                run["config"],
                MODEL_NAME,
            ],
        })
    return {"schema_version": 1, "runs": runs}


def capture_object(path: str, role: str, media_type: str) -> dict[str, Any]:
    return {
        "source_path": path,
        "capsule_path": path,
        "role": role,
        "media_type": media_type,
        "required": True,
    }


def expected_capture_objects(contract: dict[str, Any]) -> list[dict[str, Any]]:
    objects = [
        capture_object(
            "inputs/contract.json", "experiment_contract", "application/json"
        ),
        capture_object(
            "inputs/tools/tla2tools.jar",
            "formal_tool",
            "application/java-archive",
        ),
        capture_object(
            "inputs/producer-runner.sh",
            "producer_implementation",
            "text/x-shellscript",
        ),
        capture_object(
            "inputs/claim-validator.py",
            "validator_implementation",
            "text/x-python",
        ),
        capture_object(
            "inputs/environment.json",
            "execution_environment",
            "application/json",
        ),
        capture_object(
            "inputs/commands.json", "command_manifest", "application/json"
        ),
    ]
    for path, row in contract["static_inputs"].items():
        objects.append(capture_object(path, row["role"], "text/plain"))
    for run in contract["expected_runs"]:
        objects.append(capture_object(
            f"raw/tlc/{run['id']}.log", "raw_tlc_log", "text/plain"
        ))
        objects.append(capture_object(
            f"raw/tlc/{run['id']}.status", "raw_exit_status", "text/plain"
        ))
    return objects


def contract_shape_valid(contract: dict[str, Any]) -> bool:
    if set(contract) != {
        "schema_version", "id", "target_claim", "evidence_level",
        "origin_model", "tool", "static_inputs", "expected_runs",
        "capture_policy", "forbidden_inputs", "claim_boundary",
    }:
        return False
    if contract.get("schema_version") != 1:
        return False
    origin = contract.get("origin_model")
    if origin != {
        "commit": ORIGIN_COMMIT,
        "tree": ORIGIN_TREE,
        "model_path": FORMAL_PREFIX + MODEL_NAME,
    }:
        return False
    tool = contract.get("tool")
    if tool != {
        "name": "tla2tools.jar",
        "sha256": TOOL_SHA256,
        "maximum_run_seconds": 120,
        "workers": 4,
    }:
        return False

    static_inputs = contract.get("static_inputs")
    if not isinstance(static_inputs, dict) or len(static_inputs) != 27:
        return False
    model_count = 0
    config_count = 0
    for run_path, row in static_inputs.items():
        if not isinstance(run_path, str) or not run_path.startswith("inputs/model/"):
            return False
        if not isinstance(row, dict) or set(row) != {
            "repository_path", "sha256", "role"
        }:
            return False
        filename = Path(run_path).name
        if row["repository_path"] != FORMAL_PREFIX + filename:
            return False
        if SHA256_PATTERN.fullmatch(row["sha256"]) is None:
            return False
        if row["role"] == "formal_model" and filename == MODEL_NAME:
            model_count += 1
        elif row["role"] == "tlc_configuration" and filename.endswith(".cfg"):
            config_count += 1
        else:
            return False
    if (model_count, config_count) != (1, 26):
        return False

    runs = contract.get("expected_runs")
    if not isinstance(runs, list) or len(runs) != 26:
        return False
    ids: set[str] = set()
    configs: set[str] = set()
    safe_count = 0
    failure_kinds: Counter[str] = Counter()
    for run in runs:
        if not isinstance(run, dict):
            return False
        run_id = run.get("id")
        config = run.get("config")
        codes = run.get("expected_exit_codes")
        marker = run.get("expected_marker")
        if not isinstance(run_id, str) or RUN_ID_PATTERN.fullmatch(run_id) is None:
            return False
        if run_id in ids or config in configs:
            return False
        if not isinstance(config, str) or not config.endswith(".cfg"):
            return False
        if f"inputs/model/{config}" not in static_inputs:
            return False
        if not isinstance(marker, str) or not marker:
            return False
        ids.add(run_id)
        configs.add(config)
        if is_safe_run(run):
            if set(run) != {
                "id", "config", "expected_exit_codes", "expected_marker",
                "expected_generated_states", "expected_distinct_states",
                "expected_depth",
            }:
                return False
            if codes != [0] or marker != (
                "Model checking completed. No error has been found."
            ):
                return False
            if not all(
                isinstance(run[key], int) and run[key] > 0
                for key in (
                    "expected_generated_states", "expected_distinct_states",
                    "expected_depth",
                )
            ):
                return False
            safe_count += 1
        else:
            if set(run) != {
                "id", "config", "expected_exit_codes", "expected_marker",
                "expected_violation", "expected_failure_kind",
            }:
                return False
            kind = run.get("expected_failure_kind")
            violation = run.get("expected_violation")
            if not isinstance(violation, str) or not violation:
                return False
            if kind == "temporal_transition":
                if codes != [13] or marker != (
                    "Error: Temporal properties were violated."
                ):
                    return False
            elif kind in {"safety_transition", "initial_state_boundary"}:
                expected = f"Error: Invariant {violation} is violated"
                if codes != [12] or marker != expected:
                    return False
            else:
                return False
            failure_kinds[kind] += 1
    if safe_count != 4:
        return False
    if failure_kinds != Counter({
        "safety_transition": 14,
        "initial_state_boundary": 5,
        "temporal_transition": 3,
    }):
        return False

    if contract.get("capture_policy") != {
        "object_set": (
            "exactly_derived_from_static_inputs_expected_runs_and_"
            "fixed_validator_inputs"
        ),
        "allow_extra_files": False,
        "producer_summary_allowed": False,
        "maximum_objects": 96,
        "maximum_object_bytes": 8388608,
        "maximum_total_bytes": 67108864,
    }:
        return False
    return True


def config_declares_violation(config_text: str, run: dict[str, Any]) -> bool:
    directives = re.findall(
        r"^(INVARIANT|PROPERTY)[ \t]+([A-Za-z][A-Za-z0-9_]*)[ \t]*$",
        config_text,
        flags=re.MULTILINE,
    )
    invariants = [name for kind, name in directives if kind == "INVARIANT"]
    properties = [name for kind, name in directives if kind == "PROPERTY"]
    violation = run["expected_violation"]
    if run["expected_failure_kind"] == "temporal_transition":
        return properties == [violation] and invariants == ["TypeOK"]
    return properties == [] and invariants == ["TypeOK", violation]


def write_result(path: Path, result: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(path, flags, 0o600)
    try:
        data = (json.dumps(result, indent=2, sort_keys=True) + "\n").encode()
        os.write(fd, data)
        os.fsync(fd)
    finally:
        os.close(fd)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--capsule", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    capsule = Path(args.capsule).resolve()
    output = Path(args.output).resolve()
    validator_path = Path(__file__).resolve()
    validator_sha = sha256_file(validator_path)
    checks: list[dict[str, str]] = []
    failures: list[str] = []
    raw_consumed: set[str] = set()
    capsule_id = "0" * 64
    contract_sha = "0" * 64

    def check(check_id: str, passed: bool, witness: str) -> None:
        checks.append({
            "id": check_id,
            "status": "pass" if passed else "fail",
            "witness": witness,
        })
        if not passed:
            failures.append(f"{check_id}: {witness}")

    try:
        local_collector = (
            validator_path.parent
            / "evidence-capsule-v1"
            / "evidence_capsule_v1.py"
        )
        local_runner = (
            validator_path.parent
            / "run-bounded-domain-residency-evidence-capsule.sh"
        )
        structural = subprocess.run(
            [sys.executable, str(local_collector), "verify", "--capsule", str(capsule)],
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
        check(
            "structural_verification",
            structural.returncode == 0,
            structural.stdout.strip() or structural.stderr.strip(),
        )
        if structural.returncode != 0:
            raise ValidationError("structural verification failed")

        manifest = strict_json_bytes(
            read_regular(
                capsule / "core-manifest.json", MAX_JSON_BYTES, "core manifest"
            ),
            "core manifest",
        )
        capsule_id = manifest["capsule_id"]
        core = manifest["core"]
        object_rows = core["objects"]
        rows = {row["capsule_path"]: row for row in object_rows}
        check(
            "unique_manifest_object_paths",
            len(rows) == len(object_rows),
            f"objects={len(object_rows)}",
        )

        request = strict_json_bytes(
            read_regular(
                capsule / "inputs/capture-request.json",
                MAX_JSON_BYTES,
                "capture request",
            ),
            "capture request",
        )
        contract_path = core["experiment_contract"]["object_path"]
        contract_bytes = read_regular(
            capsule / contract_path, MAX_JSON_BYTES, "experiment contract"
        )
        contract = strict_json_bytes(contract_bytes, "experiment contract")
        contract_sha = sha256_bytes(contract_bytes)
        digest_ok = contract_sha == EXPECTED_CONTRACT_SHA256
        check(
            "independent_contract_digest_oracle",
            digest_ok,
            f"sha256={contract_sha}",
        )
        if not digest_ok:
            raise ValidationError("contract digest mismatch; reexecution forbidden")

        shape_ok = contract_shape_valid(contract)
        check("exact_contract_shape", shape_ok, "27 static inputs and 26 runs")

        scope_ok = (
            core["target_claims"] == [TARGET_CLAIM]
            and request["target_claims"] == [TARGET_CLAIM]
            and contract.get("id") == CONTRACT_ID
            and contract.get("target_claim") == TARGET_CLAIM
            and contract.get("evidence_level") == "EC1"
            and core["experiment_contract"]["id"] == CONTRACT_ID
            and core["experiment_contract"]["sha256"] == contract_sha
            and request["experiment_contract"]["sha256"] == contract_sha
        )
        check("claim_and_contract_scope", scope_ok, f"capsule={capsule_id}")

        expected_objects = expected_capture_objects(contract)
        expected_paths = {row["capsule_path"] for row in expected_objects}
        declared_paths = {row["capsule_path"] for row in request["objects"]}
        expected_manifest_paths = expected_paths | {
            "inputs/capture-request.json",
            "inputs/collector/evidence_capsule_v1.py",
        }
        exact_objects = (
            request["objects"] == expected_objects
            and declared_paths == expected_paths
            and set(rows) == expected_manifest_paths
            and request["completeness_rule"] == {
                "allow_extra_files": False,
                "required_capsule_paths": [
                    row["capsule_path"] for row in expected_objects
                ],
            }
            and len(expected_paths) == 85
            and not any("summary" in path for path in declared_paths)
        )
        check(
            "exact_declared_object_set",
            exact_objects,
            f"objects={len(expected_paths)}",
        )

        source_identity = request["source_identity"]
        producer_scope_ok = (
            request["producer_identity"] == "RESIDENCY-001-TLC-producer-v1"
            and core["producer_identity"] == request["producer_identity"]
            and core["source_identity"] == source_identity
            and source_identity.get("kind") == "git"
            and source_identity.get("repository") == "RESIDENCY-001-EC1-run"
            and source_identity.get("object_format") == "sha1"
            and re.fullmatch(
                r"[0-9a-f]{40}", source_identity.get("commit", "")
            ) is not None
            and re.fullmatch(
                r"[0-9a-f]{40}", source_identity.get("tree", "")
            ) is not None
            and source_identity.get("parents") == []
            and source_identity.get("dirty") is False
            and core["capture_limits"] == {
                "max_request_bytes": 1048576,
                "max_objects": 96,
                "max_object_bytes": 8388608,
                "max_total_bytes": 67108864,
            }
        )
        check(
            "producer_identity_and_capture_scope",
            producer_scope_ok,
            "fresh single-commit producer and bounded capture",
        )

        static_ok = shape_ok
        for path, expected in contract["static_inputs"].items():
            data = read_regular(capsule / path, 4 * 1024 * 1024, path)
            static_ok &= (
                sha256_bytes(data) == expected["sha256"] == rows[path]["sha256"]
            )
        tool_data = read_regular(
            capsule / "inputs/tools/tla2tools.jar",
            8 * 1024 * 1024,
            "captured TLC tool",
        )
        static_ok &= (
            sha256_bytes(tool_data)
            == TOOL_SHA256
            == rows["inputs/tools/tla2tools.jar"]["sha256"]
        )
        captured_validator = read_regular(
            capsule / "inputs/claim-validator.py",
            2 * 1024 * 1024,
            "captured claim validator",
        )
        static_ok &= (
            sha256_bytes(captured_validator)
            == validator_sha
            == rows["inputs/claim-validator.py"]["sha256"]
        )
        captured_runner = read_regular(
            capsule / "inputs/producer-runner.sh",
            2 * 1024 * 1024,
            "captured producer runner",
        )
        local_runner_sha = sha256_file(local_runner)
        static_ok &= (
            sha256_bytes(captured_runner)
            == local_runner_sha
            == rows["inputs/producer-runner.sh"]["sha256"]
        )
        local_collector_sha = sha256_file(local_collector)
        static_ok &= (
            rows["inputs/collector/evidence_capsule_v1.py"]["sha256"]
            == local_collector_sha
            == core["collector_implementation_sha256"]
        )
        check("static_input_identity", static_ok, f"validator={validator_sha}")

        commands = strict_json_bytes(
            read_regular(
                capsule / "inputs/commands.json", MAX_JSON_BYTES, "command manifest"
            ),
            "command manifest",
        )
        check(
            "exact_command_manifest",
            commands == expected_commands(contract),
            f"runs={len(commands.get('runs', []))}",
        )

        environment = strict_json_bytes(
            read_regular(
                capsule / "inputs/environment.json",
                MAX_JSON_BYTES,
                "execution environment",
            ),
            "execution environment",
        )
        environment_ok = (
            environment.get("schema_version") == 1
            and environment.get("tool_sha256") == TOOL_SHA256
            and environment.get("origin_model_commit") == ORIGIN_COMMIT
            and environment.get("origin_model_tree") == ORIGIN_TREE
            and isinstance(environment.get("validation_tool_commit"), str)
            and re.fullmatch(
                r"[0-9a-f]{40,64}", environment["validation_tool_commit"]
            ) is not None
            and isinstance(environment.get("java_version"), str)
            and bool(environment.get("java_version"))
            and environment.get("locale") == "C"
            and request["declared_environment"] == environment
            and core["declared_environment"] == environment
        )
        check("declared_environment", environment_ok, "tool and model origin bound")

        producer_ok = True
        safe_stats_ok = True
        negative_kinds: Counter[str] = Counter()
        for run in contract["expected_runs"]:
            log_path = f"raw/tlc/{run['id']}.log"
            status_path = f"raw/tlc/{run['id']}.status"
            raw_consumed.update({log_path, status_path})
            log_bytes = read_regular(capsule / log_path, MAX_LOG_BYTES, log_path)
            status_bytes = read_regular(capsule / status_path, 32, status_path)
            producer_ok &= sha256_bytes(log_bytes) == rows[log_path]["sha256"]
            producer_ok &= sha256_bytes(status_bytes) == rows[status_path]["sha256"]
            log = log_bytes.decode("utf-8", errors="strict")
            status_text = status_bytes.decode("ascii", errors="strict").strip()
            status = int(status_text) if re.fullmatch(r"[0-9]+", status_text) else -1
            producer_ok &= (
                status in run["expected_exit_codes"]
                and run["expected_marker"] in log
                and "Error: Invariant TypeOK is violated" not in log
                and "TLC threw an unexpected exception" not in log
                and "Parsing or semantic analysis failed" not in log
            )
            if is_safe_run(run):
                expected_stats = (
                    run["expected_generated_states"],
                    run["expected_distinct_states"],
                    run["expected_depth"],
                )
                safe_stats_ok &= parse_stats(log) == expected_stats
                producer_ok &= "Error:" not in log
            else:
                config_path = f"inputs/model/{run['config']}"
                config_text = read_regular(
                    capsule / config_path, 1024 * 1024, config_path
                ).decode("utf-8", errors="strict")
                producer_ok &= config_declares_violation(config_text, run)
                negative_kinds[run["expected_failure_kind"]] += 1
        check(
            "captured_raw_outcomes",
            producer_ok,
            "26 logs and statuses recomputed",
        )
        check(
            "safe_state_space_exact",
            safe_stats_ok,
            "four safe counts and depths exact",
        )
        check(
            "negative_discrimination",
            negative_kinds == Counter({
                "safety_transition": 14,
                "initial_state_boundary": 5,
                "temporal_transition": 3,
            }),
            "22 targeted counterexamples classified",
        )
        check(
            "no_producer_summary_oracle",
            not any("summary" in path for path in declared_paths),
            "validator consumed raw logs and statuses only",
        )

        if failures:
            check(
                "validator_reexecution",
                False,
                "skipped because a pre-execution trust check failed",
            )
        else:
            java = shutil.which("java")
            if java is None:
                raise ValidationError("java executable is unavailable")
            rerun_ok = True
            rerun_witness: list[str] = []
            with tempfile.TemporaryDirectory(
                prefix="residency-validator-"
            ) as temporary:
                root = Path(temporary)
                model_dir = root / "inputs" / "model"
                tool_dir = root / "inputs" / "tools"
                work_dir = root / "work"
                model_dir.mkdir(parents=True)
                tool_dir.mkdir(parents=True)
                work_dir.mkdir()
                for path in contract["static_inputs"]:
                    source = capsule / path
                    destination = root / path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(
                        read_regular(source, 4 * 1024 * 1024, path)
                    )
                (tool_dir / "tla2tools.jar").write_bytes(tool_data)
                for run in contract["expected_runs"]:
                    state_dir = work_dir / f"states-{run['id']}"
                    command = [
                        java,
                        "-XX:+UseParallelGC",
                        "-cp",
                        str(tool_dir / "tla2tools.jar"),
                        "tlc2.TLC",
                        "-workers",
                        str(contract["tool"]["workers"]),
                        "-metadir",
                        str(state_dir),
                        "-config",
                        run["config"],
                        MODEL_NAME,
                    ]
                    completed = subprocess.run(
                        command,
                        cwd=model_dir,
                        check=False,
                        capture_output=True,
                        text=True,
                        timeout=contract["tool"]["maximum_run_seconds"],
                        env={**os.environ, "LC_ALL": "C"},
                    )
                    output_text = completed.stdout + completed.stderr
                    current_ok = (
                        completed.returncode in run["expected_exit_codes"]
                        and run["expected_marker"] in output_text
                        and "Error: Invariant TypeOK is violated" not in output_text
                        and "TLC threw an unexpected exception" not in output_text
                        and "Parsing or semantic analysis failed" not in output_text
                    )
                    if is_safe_run(run):
                        current_ok &= parse_stats(output_text) == (
                            run["expected_generated_states"],
                            run["expected_distinct_states"],
                            run["expected_depth"],
                        )
                        current_ok &= "Error:" not in output_text
                    rerun_ok &= current_ok
                    rerun_witness.append(f"{run['id']}={completed.returncode}")
            check("validator_reexecution", rerun_ok, ",".join(rerun_witness))

        structural_after = subprocess.run(
            [sys.executable, str(local_collector), "verify", "--capsule", str(capsule)],
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
        check(
            "post_validation_structural_verification",
            structural_after.returncode == 0,
            structural_after.stdout.strip() or structural_after.stderr.strip(),
        )
    except (ValidationError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        failures.append(str(error))
        if not any(row["id"] == "validator_reexecution" for row in checks):
            checks.append({
                "id": "validator_reexecution",
                "status": "fail",
                "witness": "skipped after validation exception",
            })
        if not checks:
            checks.append({
                "id": "validator_execution",
                "status": "fail",
                "witness": str(error),
            })

    result = {
        "schema_version": 1,
        "capsule_id": capsule_id,
        "validator_id": "RESIDENCY-001-EC1-validator-v1",
        "validator_implementation_sha256": validator_sha,
        "contract_id": CONTRACT_ID,
        "contract_sha256": contract_sha,
        "status": "Valid" if not failures and all(
            row["status"] == "pass" for row in checks
        ) else "Invalid",
        "checks": checks,
        "raw_objects_consumed": sorted(raw_consumed),
        "derived_objects_produced": ["validator-result.json"],
        "unknown_classifications": [],
        "failure_reasons": failures,
    }
    write_result(output, result)
    print(json.dumps({
        "status": result["status"],
        "capsule_id": capsule_id,
        "output": str(output),
        "checks": len(checks),
        "failures": len(failures),
    }, sort_keys=True))
    return 0 if result["status"] == "Valid" else 1


if __name__ == "__main__":
    raise SystemExit(main())
