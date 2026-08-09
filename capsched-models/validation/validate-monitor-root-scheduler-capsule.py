#!/usr/bin/env python3
"""Validate a ROOTSCHED-001 Evidence Capsule without producer summaries."""

from __future__ import annotations

import argparse
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


CONTRACT_ID = "ROOTSCHED-001-TLC-v1"
TARGET_CLAIM = "ROOTSCHED-001"
ORIGIN_COMMIT = "345efd04052d2d78c135914a7fd62ebbb3b0904f"
ORIGIN_TREE = "89131d49fe4e553801dc1e908a0748f7b4cb085d"
TOOL_SHA256 = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
MODEL_NAME = "MonitorRootScheduler.tla"
MAX_JSON_BYTES = 1024 * 1024
MAX_LOG_BYTES = 8 * 1024 * 1024

STATIC_HASHES = {
    "inputs/model/MonitorRootScheduler.tla":
        "491d02fb75317fec31868c7a7e57a7f85512f10d7a1ba12eba8f48fab565a3b1",
    "inputs/model/MonitorRootSchedulerSafeRevoke.cfg":
        "397134958f13ae23e5b9bcb441a68ec4502930ca915a2909dff2bb9c49f2de18",
    "inputs/model/MonitorRootSchedulerSafeSteady.cfg":
        "b6d870732d13ea1f5ac9f2f8255c3225d203848b2709de052659b82e24981ec5",
    "inputs/model/MonitorRootSchedulerUnsafeExpiryStillRunning.cfg":
        "aeb6be9c7924f76b443ca0e824eaca9ec325305eaa90c887d9c1c2a2d8c59135",
    "inputs/model/MonitorRootSchedulerUnsafeLinuxExtend.cfg":
        "fa49887c4e336f8967e7fd55986c3d830f272fc2aa51218ed89a786db81adcbf",
    "inputs/model/MonitorRootSchedulerUnsafeLinuxMint.cfg":
        "56c6db921b7ab3a3a964e2a4d247fefe5c7dc6aa243f072e77f5fc29f066ad38",
    "inputs/model/MonitorRootSchedulerUnsafeNoTimer.cfg":
        "fcba5c619e8ca54edfa969467d63bf142c0f8b0189f5583c307cccb5f0e0a775",
    "inputs/model/MonitorRootSchedulerUnsafeRevokeManagement.cfg":
        "0199a30951f370cf4b35cae7e4b63c4b989c183f73bf52c20891d3a16f6ce4e3",
    "inputs/model/MonitorRootSchedulerUnsafeSkipReserved.cfg":
        "464ffda33e8a71db92b46fca9c021fad594e02511ac44d063c97d61688456523",
    "inputs/model/MonitorRootSchedulerUnsafeStaleEpoch.cfg":
        "d81741f55ab74a90aabd356362cbfd39a51d7cdec545f5125e4ed553f4c8f124",
    "inputs/model/MonitorRootSchedulerUnsafeStealReserved.cfg":
        "2cf02fcaa6b95f66a8d2adbe7ad1f68b231e32f559395b0b4514885fdd0fdf9b",
    "inputs/model/MonitorRootSchedulerUnsafeStopAfterExpiry.cfg":
        "2da10e460886cf49606448e2b08d3fb2d113beed27a48ba2fb8aed6d8d8681de",
    "inputs/model/MonitorRootSchedulerUnsafeWaitForLinuxHint.cfg":
        "322b9d6daf5bb3501a391607716074adef5eaf890d5b21c8357ffb19675e3beb",
    "inputs/tools/tla2tools.jar": TOOL_SHA256,
}

EXPECTED_RUNS = [
    {
        "id": "safe-steady",
        "config": "MonitorRootSchedulerSafeSteady.cfg",
        "codes": [0],
        "marker": "Model checking completed. No error has been found.",
        "stats": (155817, 1920, 21),
        "violation": None,
    },
    {
        "id": "safe-revoke",
        "config": "MonitorRootSchedulerSafeRevoke.cfg",
        "codes": [0],
        "marker": "Model checking completed. No error has been found.",
        "stats": (853049, 10400, 21),
        "violation": None,
    },
    {
        "id": "unsafe-wait-for-linux-hint",
        "config": "MonitorRootSchedulerUnsafeWaitForLinuxHint.cfg",
        "codes": [13],
        "marker": "Error: Temporal properties were violated.",
        "stats": None,
        "violation": "GuaranteedRecurringService",
    },
    {
        "id": "unsafe-skip-reserved",
        "config": "MonitorRootSchedulerUnsafeSkipReserved.cfg",
        "codes": [12],
        "marker": "Invariant BoundedGuaranteedWait is violated.",
        "stats": None,
        "violation": "BoundedGuaranteedWait",
    },
    {
        "id": "unsafe-steal-reserved",
        "config": "MonitorRootSchedulerUnsafeStealReserved.cfg",
        "codes": [12],
        "marker": "Invariant ReservedSlotIntegrity is violated.",
        "stats": None,
        "violation": "ReservedSlotIntegrity",
    },
    {
        "id": "unsafe-stale-epoch",
        "config": "MonitorRootSchedulerUnsafeStaleEpoch.cfg",
        "codes": [12],
        "marker": "Invariant CurrentEpochOnly is violated.",
        "stats": None,
        "violation": "CurrentEpochOnly",
    },
    {
        "id": "unsafe-linux-extend",
        "config": "MonitorRootSchedulerUnsafeLinuxExtend.cfg",
        "codes": [12],
        "marker": "Invariant LinuxCannotExtendRootLease is violated.",
        "stats": None,
        "violation": "LinuxCannotExtendRootLease",
    },
    {
        "id": "unsafe-expiry-still-running",
        "config": "MonitorRootSchedulerUnsafeExpiryStillRunning.cfg",
        "codes": [12],
        "marker": "Invariant NoRootBudgetOverrun is violated.",
        "stats": None,
        "violation": "NoRootBudgetOverrun",
    },
    {
        "id": "unsafe-stop-after-expiry",
        "config": "MonitorRootSchedulerUnsafeStopAfterExpiry.cfg",
        "codes": [13],
        "marker": "Error: Temporal properties were violated.",
        "stats": None,
        "violation": "TrustedHandoffProgress",
    },
    {
        "id": "unsafe-revoke-management",
        "config": "MonitorRootSchedulerUnsafeRevokeManagement.cfg",
        "codes": [12],
        "marker": "Invariant ManagementAlwaysAdmitted is violated.",
        "stats": None,
        "violation": "ManagementAlwaysAdmitted",
    },
    {
        "id": "unsafe-no-timer",
        "config": "MonitorRootSchedulerUnsafeNoTimer.cfg",
        "codes": [12],
        "marker": "Invariant NoRootRunWithoutLease is violated.",
        "stats": None,
        "violation": "NoRootRunWithoutLease",
    },
    {
        "id": "unsafe-linux-mint",
        "config": "MonitorRootSchedulerUnsafeLinuxMint.cfg",
        "codes": [12],
        "marker": "Invariant LinuxCannotMintRootAuthority is violated.",
        "stats": None,
        "violation": "LinuxCannotMintRootAuthority",
    },
]


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


def expected_contract_runs() -> list[dict[str, Any]]:
    result = []
    for run in EXPECTED_RUNS:
        row: dict[str, Any] = {
            "id": run["id"],
            "config": run["config"],
            "expected_exit_codes": run["codes"],
            "expected_marker": run["marker"],
        }
        if run["stats"] is not None:
            row.update({
                "expected_generated_states": run["stats"][0],
                "expected_distinct_states": run["stats"][1],
                "expected_depth": run["stats"][2],
            })
        else:
            row["expected_violation"] = run["violation"]
        result.append(row)
    return result


def expected_commands() -> dict[str, Any]:
    runs = []
    for run in EXPECTED_RUNS:
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
                "2",
                "-metadir",
                f"../../work/states-{run['id']}",
                "-config",
                run["config"],
                MODEL_NAME,
            ],
        })
    return {"schema_version": 1, "runs": runs}


def parse_stats(log: str) -> tuple[int, int, int] | None:
    match = re.search(
        r"(\d+) states generated, (\d+) distinct states found, "
        r"0 states left on queue\.\s+"
        r"The depth of the complete state graph search is (\d+)\.",
        log,
    )
    if match is None:
        return None
    return tuple(int(value) for value in match.groups())  # type: ignore[return-value]


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

        manifest_bytes = read_regular(
            capsule / "core-manifest.json", MAX_JSON_BYTES, "core manifest"
        )
        manifest = strict_json_bytes(manifest_bytes, "core manifest")
        capsule_id = manifest["capsule_id"]
        core = manifest["core"]
        rows = {row["capsule_path"]: row for row in core["objects"]}

        request_bytes = read_regular(
            capsule / "inputs/capture-request.json",
            MAX_JSON_BYTES,
            "capture request",
        )
        request = strict_json_bytes(request_bytes, "capture request")
        contract_path = core["experiment_contract"]["object_path"]
        contract_bytes = read_regular(
            capsule / contract_path, MAX_JSON_BYTES, "experiment contract"
        )
        contract = strict_json_bytes(contract_bytes, "experiment contract")
        contract_sha = sha256_bytes(contract_bytes)

        scope_ok = (
            core["target_claims"] == [TARGET_CLAIM]
            and request["target_claims"] == [TARGET_CLAIM]
            and contract.get("id") == CONTRACT_ID
            and contract.get("target_claim") == TARGET_CLAIM
            and contract.get("evidence_level") == "EC1"
            and core["experiment_contract"]["id"] == CONTRACT_ID
            and core["experiment_contract"]["sha256"] == contract_sha
        )
        check("claim_and_contract_scope", scope_ok, f"capsule={capsule_id}")

        origin = contract.get("origin_model", {})
        tool = contract.get("tool", {})
        contract_static = contract.get("static_inputs", [])
        expected_model_paths = {
            path: digest
            for path, digest in STATIC_HASHES.items()
            if path.startswith("inputs/model/")
        }
        contract_static_ok = (
            isinstance(contract_static, list)
            and len(contract_static) == len(expected_model_paths)
            and all(isinstance(row, dict) for row in contract_static)
            and {row.get("run_path") for row in contract_static}
                == set(expected_model_paths)
        )
        if contract_static_ok:
            for row in contract_static:
                run_path = row.get("run_path")
                filename = Path(run_path).name if isinstance(run_path, str) else ""
                contract_static_ok &= (
                    run_path in expected_model_paths
                    and row.get("sha256") == expected_model_paths.get(run_path)
                    and row.get("repository_path")
                    == "capsched-models/formal/0147-monitor-root-scheduler-model/"
                    + filename
                )
        exact_contract = (
            origin.get("commit") == ORIGIN_COMMIT
            and origin.get("tree") == ORIGIN_TREE
            and origin.get("model_path")
            == "capsched-models/formal/0147-monitor-root-scheduler-model/MonitorRootScheduler.tla"
            and tool.get("sha256") == TOOL_SHA256
            and tool.get("maximum_run_seconds") == 120
            and tool.get("workers") == 2
            and contract.get("expected_runs") == expected_contract_runs()
            and contract_static_ok
        )
        check("independent_contract_oracle", exact_contract, "hard-coded EC1 contract")

        declared_paths = {row["capsule_path"] for row in request["objects"]}
        contract_paths = {row["capsule_path"] for row in contract["capture_objects"]}
        expected_paths = {
            "inputs/contract.json",
            "inputs/tools/tla2tools.jar",
            "inputs/producer-runner.sh",
            "inputs/claim-validator.py",
            "inputs/environment.json",
            "inputs/commands.json",
            *STATIC_HASHES.keys(),
        }
        for run in EXPECTED_RUNS:
            expected_paths.add(f"raw/tlc/{run['id']}.log")
            expected_paths.add(f"raw/tlc/{run['id']}.status")
        exact_objects = (
            declared_paths == expected_paths
            and contract_paths == expected_paths
            and len(request["objects"]) == len(expected_paths)
            and len(contract["capture_objects"]) == len(expected_paths)
            and request["objects"] == contract["capture_objects"]
            and "producer-summary.json" not in declared_paths
        )
        check("exact_declared_object_set", exact_objects, f"objects={len(expected_paths)}")

        static_ok = True
        for path, expected_sha in STATIC_HASHES.items():
            data = read_regular(capsule / path, 4 * 1024 * 1024, path)
            row = rows[path]
            static_ok &= sha256_bytes(data) == expected_sha == row["sha256"]
        captured_validator = read_regular(
            capsule / "inputs/claim-validator.py",
            2 * 1024 * 1024,
            "captured claim validator",
        )
        static_ok &= sha256_bytes(captured_validator) == validator_sha
        static_ok &= rows["inputs/claim-validator.py"]["sha256"] == validator_sha
        local_collector_sha = sha256_file(local_collector)
        static_ok &= (
            rows["inputs/collector/evidence_capsule_v1.py"]["sha256"]
            == local_collector_sha
            == core["collector_implementation_sha256"]
        )
        check("static_input_identity", static_ok, f"validator={validator_sha}")

        commands_bytes = read_regular(
            capsule / "inputs/commands.json", MAX_JSON_BYTES, "command manifest"
        )
        commands = strict_json_bytes(commands_bytes, "command manifest")
        check(
            "exact_command_manifest",
            commands == expected_commands(),
            f"runs={len(commands.get('runs', []))}",
        )

        environment_bytes = read_regular(
            capsule / "inputs/environment.json",
            MAX_JSON_BYTES,
            "execution environment",
        )
        environment = strict_json_bytes(environment_bytes, "execution environment")
        environment_ok = (
            environment.get("schema_version") == 1
            and environment.get("tool_sha256") == TOOL_SHA256
            and environment.get("origin_model_commit") == ORIGIN_COMMIT
            and environment.get("origin_model_tree") == ORIGIN_TREE
            and isinstance(environment.get("java_version"), str)
            and environment.get("java_version")
        )
        check("declared_environment", bool(environment_ok), "tool and model origin bound")

        producer_ok = True
        safe_stats_ok = True
        negative_count = 0
        for run in EXPECTED_RUNS:
            log_path = f"raw/tlc/{run['id']}.log"
            status_path = f"raw/tlc/{run['id']}.status"
            raw_consumed.update({log_path, status_path})
            log_bytes = read_regular(capsule / log_path, MAX_LOG_BYTES, log_path)
            status_bytes = read_regular(capsule / status_path, 32, status_path)
            if sha256_bytes(log_bytes) != rows[log_path]["sha256"]:
                producer_ok = False
            if sha256_bytes(status_bytes) != rows[status_path]["sha256"]:
                producer_ok = False
            log = log_bytes.decode("utf-8", errors="strict")
            status_text = status_bytes.decode("ascii", errors="strict").strip()
            status = int(status_text) if re.fullmatch(r"\d+", status_text) else -1
            producer_ok &= status in run["codes"] and run["marker"] in log
            if run["stats"] is not None:
                safe_stats_ok &= parse_stats(log) == run["stats"]
                producer_ok &= "Error:" not in log
            else:
                config_bytes = read_regular(
                    capsule / f"inputs/model/{run['config']}",
                    1024 * 1024,
                    run["config"],
                )
                config_text = config_bytes.decode("utf-8", errors="strict")
                producer_ok &= run["violation"] in config_text
                negative_count += 1
        check("captured_raw_outcomes", producer_ok, "12 logs and statuses recomputed")
        check("safe_state_space_exact", safe_stats_ok, "steady and revoke counts/depth exact")
        check("negative_discrimination", negative_count == 10, "10 targeted counterexamples")
        check(
            "no_producer_summary_oracle",
            not any("summary" in path for path in declared_paths),
            "validator consumed raw logs/status only",
        )

        java = shutil.which("java")
        if java is None:
            raise ValidationError("java executable is unavailable")
        rerun_ok = True
        rerun_witness: list[str] = []
        with tempfile.TemporaryDirectory(prefix="rootsched-validator-") as temporary:
            root = Path(temporary)
            model_dir = root / "inputs" / "model"
            tool_dir = root / "inputs" / "tools"
            work_dir = root / "work"
            model_dir.mkdir(parents=True)
            tool_dir.mkdir(parents=True)
            work_dir.mkdir()
            for path in STATIC_HASHES:
                source = capsule / path
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(read_regular(source, 4 * 1024 * 1024, path))
            for run in EXPECTED_RUNS:
                state_dir = work_dir / f"states-{run['id']}"
                command = [
                    java,
                    "-XX:+UseParallelGC",
                    "-cp",
                    str(tool_dir / "tla2tools.jar"),
                    "tlc2.TLC",
                    "-workers",
                    "2",
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
                    timeout=120,
                    env={**os.environ, "LC_ALL": "C"},
                )
                output_text = completed.stdout + completed.stderr
                current_ok = (
                    completed.returncode in run["codes"]
                    and run["marker"] in output_text
                )
                if run["stats"] is not None:
                    current_ok &= parse_stats(output_text) == run["stats"]
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
        if not checks:
            checks.append({
                "id": "validator_execution",
                "status": "fail",
                "witness": str(error),
            })

    result = {
        "schema_version": 1,
        "capsule_id": capsule_id,
        "validator_id": "ROOTSCHED-001-EC1-validator-v1",
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
