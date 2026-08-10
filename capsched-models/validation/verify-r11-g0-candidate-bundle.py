#!/usr/bin/env python3
"""Verify the exact local R11 G0 candidate bundle without promoting it."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any

from jsonschema import Draft202012Validator


WORKTREE = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = WORKTREE / "capsched-models/policy/r11/g0-candidate-bundle-v1.json"
DEFAULT_SCHEMA = WORKTREE / "capsched-models/policy/r11/g0-candidate-bundle-schema-v1.json"

EXPECTED_PATHS = {
    "semantic_policy_schema": "capsched-models/policy/r11/semantic-policy-schema-v1.json",
    "semantic_policy": "capsched-models/policy/r11/semantic-policy-v1.json",
    "semantic_rule_registry_schema": "capsched-models/policy/r11/semantic-rule-registry-schema-v1.json",
    "semantic_rule_registry": "capsched-models/policy/r11/semantic-rule-registry-v1.json",
    "scenario_profile_schema": "capsched-models/policy/r11/scenario-profile-schema-v1.json",
    "scenario_profile": "capsched-models/policy/r11/scenario-profile-v1.json",
    "review_contract_schema": "capsched-models/policy/r11/g0-review-contract-schema-v1.json",
    "review_contract": "capsched-models/policy/r11/g0-review-contract-v1.json",
    "exact_mutation_catalog_schema": "capsched-models/policy/r11/g0-mutation-catalog-schema-v1.json",
    "exact_mutation_catalog": "capsched-models/policy/r11/g0-mutation-catalog-v1.json",
    "assurance_claim_catalog": "capsched-models/assurance/claims.json",
    "mechanical_checker": "capsched-models/validation/validate-r11-g0-policy-profile.py",
    "exact_mutation_runner": "capsched-models/validation/run-r11-g0-exact-campaign.py",
    "candidate_bundle_schema": "capsched-models/policy/r11/g0-candidate-bundle-schema-v1.json",
    "candidate_bundle_verifier": "capsched-models/validation/verify-r11-g0-candidate-bundle.py",
    "review_receipt_schema": "capsched-models/policy/r11/g0-review-receipt-schema-v1.json",
    "gate_decision_schema": "capsched-models/policy/r11/g0-gate-decision-schema-v1.json",
}
CATALOG_TO_MANIFEST_ROLE = {
    "policy_schema": "semantic_policy_schema",
    "policy": "semantic_policy",
    "registry_schema": "semantic_rule_registry_schema",
    "registry": "semantic_rule_registry",
    "profile_schema": "scenario_profile_schema",
    "profile": "scenario_profile",
    "review_contract_schema": "review_contract_schema",
    "review_contract": "review_contract",
    "claims": "assurance_claim_catalog",
    "mechanical_checker": "mechanical_checker",
}


class BundleFailure(RuntimeError):
    pass


class DuplicateKey(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise BundleFailure(message)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKey(key)
        result[key] = value
    return result


def reject_bad_scalars(value: Any, pointer: str = "") -> None:
    require(value is not None, f"null is forbidden at {pointer or '/'}")
    require(not isinstance(value, float), f"float is forbidden at {pointer or '/'}")
    if isinstance(value, dict):
        for key, child in value.items():
            reject_bad_scalars(child, f"{pointer}/{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_bad_scalars(child, f"{pointer}/{index}")


def parse_json(raw: bytes, label: str) -> Any:
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        raise BundleFailure(f"{label}: invalid strict JSON: {exc}") from exc
    reject_bad_scalars(value)
    return value


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_stable_once(path: Path) -> tuple[bytes, tuple[int, int]]:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        raise BundleFailure(f"cannot open {path}: {exc}") from exc
    try:
        before = os.fstat(descriptor)
        require(stat.S_ISREG(before.st_mode), f"not a regular file: {path}")
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    before_identity = (
        before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
        before.st_ctime_ns,
    )
    after_identity = (
        after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
        after.st_ctime_ns,
    )
    require(before_identity == after_identity, f"input changed while read: {path}")
    raw = b"".join(chunks)
    require(len(raw) == before.st_size, f"short read: {path}")
    return raw, (before.st_dev, before.st_ino)


def safe_repo_path(raw_path: str) -> Path:
    relative = PurePosixPath(raw_path)
    require(not relative.is_absolute(), f"absolute artifact path: {raw_path}")
    require(".." not in relative.parts and "." not in relative.parts, f"unsafe artifact path: {raw_path}")
    path = WORKTREE.joinpath(*relative.parts)
    require(path.is_relative_to(WORKTREE), f"path escapes worktree: {raw_path}")
    return path


def validate_manifest_shape(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    require(manifest["artifact_id"] == "domainlease-r11-g0-candidate-bundle-v1", "wrong manifest ID")
    artifacts = manifest["artifacts"]
    by_role = {row["role"]: row for row in artifacts}
    require(len(by_role) == len(artifacts), "duplicate artifact role")
    require(set(by_role) == set(EXPECTED_PATHS), "artifact role inventory mismatch")
    require([row["ordinal"] for row in artifacts] == list(range(17)), "artifact ordinals are not exact and contiguous")
    paths = [row["path"] for row in artifacts]
    require(len(paths) == len(set(paths)), "duplicate artifact path")
    for role, expected_path in EXPECTED_PATHS.items():
        require(by_role[role]["path"] == expected_path, f"unexpected path for {role}")
    require(
        "capsched-models/policy/r11/g0-candidate-bundle-v1.json" not in paths,
        "manifest contains itself",
    )
    return by_role


def capture_artifacts(
    by_role: dict[str, dict[str, Any]],
    schema_path: Path,
    schema_raw: bytes,
    schema_identity: tuple[int, int],
) -> dict[str, bytes]:
    captured: dict[str, bytes] = {}
    identities: set[tuple[int, int]] = set()
    for role in EXPECTED_PATHS:
        entry = by_role[role]
        path = safe_repo_path(entry["path"])
        if path.resolve() == schema_path.resolve():
            raw, identity = schema_raw, schema_identity
        else:
            raw, identity = read_stable_once(path)
        require(identity not in identities, f"artifact aliases an earlier inode: {path}")
        identities.add(identity)
        require(len(raw) == entry["byte_length"], f"{role}: byte length mismatch")
        require(sha256(raw) == entry["sha256"], f"{role}: digest mismatch")
        captured[role] = raw
    return captured


def validate_cross_artifact_contract(
    manifest: dict[str, Any],
    captured: dict[str, bytes],
) -> None:
    review_contract = parse_json(captured["review_contract"], "review contract")
    require(
        set(review_contract["artifact_role_layers"]["candidate_bundle"]) == set(EXPECTED_PATHS),
        "review contract candidate-bundle roles differ from the manifest",
    )

    mutation_catalog = parse_json(captured["exact_mutation_catalog"], "mutation catalog")
    catalog_baselines = {row["role"]: row for row in mutation_catalog["baseline_artifacts"]}
    require(set(catalog_baselines) == set(CATALOG_TO_MANIFEST_ROLE), "mutation baseline inventory mismatch")
    for catalog_role, manifest_role in CATALOG_TO_MANIFEST_ROLE.items():
        catalog_entry = catalog_baselines[catalog_role]
        manifest_entry = next(
            row for row in manifest["artifacts"] if row["role"] == manifest_role
        )
        require(catalog_entry["path"] == manifest_entry["path"], f"{catalog_role}: path disagreement")
        require(catalog_entry["byte_length"] == manifest_entry["byte_length"], f"{catalog_role}: length disagreement")
        require(catalog_entry["sha256"] == manifest_entry["sha256"], f"{catalog_role}: digest disagreement")

    policy = parse_json(captured["semantic_policy"], "semantic policy")
    registry = parse_json(captured["semantic_rule_registry"], "semantic rule registry")
    profile = parse_json(captured["scenario_profile"], "scenario profile")
    counts = {
        "semantic_rules": len(registry["rules"]),
        "invariants": len(policy["invariant_obligations"]),
        "progress_obligations": len(policy["progress_obligations"]),
        "provider_contracts": len(policy["provider_contracts"]),
        "profiles": len(profile["profiles"]),
        "witness_ids": len(profile["suite_coverage"]["required_witnesses"]),
        "g0_checks": len(review_contract["checks"]),
        "review_roles": len(review_contract["review_roles"]),
        "g0_exact_mutations": len(mutation_catalog["cases"]),
        "future_ir_mutation_templates": len(policy["mutation_oracle"]["future_ir_mutation_templates"]),
    }
    require(counts == manifest["semantic_counts"], f"semantic count mismatch: {counts}")


def write_exact(path: Path, raw: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.chmod(path, 0o444)


def run_exact_campaign(captured: dict[str, bytes]) -> tuple[dict[str, Any], bytes]:
    with tempfile.TemporaryDirectory(prefix="r11-g0-bundle-") as directory:
        root = Path(directory)
        for role, relative in EXPECTED_PATHS.items():
            write_exact(root / relative, captured[role])
        runner = root / EXPECTED_PATHS["exact_mutation_runner"]
        environment = {
            "LC_ALL": "C.UTF-8",
            "LANG": "C.UTF-8",
            "TZ": "UTC",
            "PYTHONHASHSEED": "0",
        }
        try:
            completed = subprocess.run(
                [sys.executable, "-I", str(runner)],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                timeout=120,
                check=False,
                env=environment,
            )
        except subprocess.TimeoutExpired as exc:
            raise BundleFailure("exact mutation campaign timed out") from exc
        require(completed.returncode == 0, f"exact campaign exit {completed.returncode}: {completed.stdout!r}")
        require(not completed.stderr, f"exact campaign wrote stderr: {completed.stderr!r}")
        require(len(completed.stdout) <= 1024 * 1024, "exact campaign output exceeds bound")
        result = parse_json(completed.stdout, "exact mutation campaign output")
        require(result.get("status") == "passed", f"exact campaign did not pass: {result}")
        require(result.get("authority") == "local_exact_regression_only", "exact campaign overstates authority")
        require(result.get("g0_complete") is False, "exact campaign self-promotes G0")
        require(result.get("r11_machine_source_construction") is False, "exact campaign authorizes source construction")
        require(result.get("executed_cases") == 12, "exact campaign case count mismatch")
        require(result.get("deferred_external_cases") == [], "exact campaign leaves a mutation unexecuted")
        require(result.get("runner_sha256") == sha256(captured["exact_mutation_runner"]), "runner identity mismatch")
        require(result.get("mechanical_checker_sha256") == sha256(captured["mechanical_checker"]), "checker identity mismatch")
        return result, completed.stdout


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest_raw, _ = read_stable_once(args.manifest)
        schema_raw, schema_identity = read_stable_once(args.schema)
        manifest = parse_json(manifest_raw, "candidate bundle manifest")
        schema = parse_json(schema_raw, "candidate bundle schema")
        Draft202012Validator.check_schema(schema)
        errors = sorted(
            Draft202012Validator(schema).iter_errors(manifest),
            key=lambda error: [str(part) for part in error.absolute_path],
        )
        require(not errors, f"manifest schema rejection: {errors[0].message if errors else ''}")
        by_role = validate_manifest_shape(manifest)
        captured = capture_artifacts(by_role, args.schema, schema_raw, schema_identity)
        validate_cross_artifact_contract(manifest, captured)
        campaign, campaign_raw = run_exact_campaign(captured)
    except (BundleFailure, OSError, ValueError) as exc:
        print(json.dumps({"status": "failed", "failure": str(exc)}, sort_keys=True))
        return 1

    result = {
        "schema_version": 1,
        "authority": "local_candidate_integrity_only",
        "status": "passed",
        "candidate_bundle_manifest_sha256": sha256(manifest_raw),
        "candidate_bundle_manifest_byte_length": len(manifest_raw),
        "artifact_count": len(captured),
        "artifact_sha256": {
            role: sha256(raw) for role, raw in captured.items()
        },
        "exact_campaign_result_sha256": sha256(campaign_raw),
        "exact_campaign_catalog_sha256": campaign["catalog_sha256"],
        "exact_campaign_cases": campaign["executed_cases"],
        "runtime": {
            "python": sys.version.split()[0],
            "jsonschema": importlib.metadata.version("jsonschema"),
        },
        "local_advisory_receipts": manifest["review_state"]["local_advisory_receipts"],
        "external_review_receipts": 0,
        "external_gate_decision": False,
        "g0_complete": False,
        "r11_machine_source_construction": False,
        "semantic_freeze": False,
        "tla_translation": False,
        "model_supported": False,
        "nonclaims": [
            "This verifies exact local bytes and a local mutation campaign only.",
            "It does not authenticate external review principals, an authority registry, or a gate decision.",
            "It cannot authorize IR construction, semantic freeze, TLA+, model support, Linux changes, or protection claims.",
        ],
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
