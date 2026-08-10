#!/usr/bin/env python3
"""Run the exact, local-only R11 G0 mutation campaign.

This runner is intentionally outside the policy/profile checker and consumes an
exact catalog. A successful run is regression evidence, not external G0
authorization.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
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
DEFAULT_CATALOG = WORKTREE / "capsched-models/policy/r11/g0-mutation-catalog-v1.json"
DEFAULT_SCHEMA = WORKTREE / "capsched-models/policy/r11/g0-mutation-catalog-schema-v1.json"

EXPECTED_BASELINES = {
    "policy_schema": "capsched-models/policy/r11/semantic-policy-schema-v1.json",
    "policy": "capsched-models/policy/r11/semantic-policy-v1.json",
    "registry_schema": "capsched-models/policy/r11/semantic-rule-registry-schema-v1.json",
    "registry": "capsched-models/policy/r11/semantic-rule-registry-v1.json",
    "profile_schema": "capsched-models/policy/r11/scenario-profile-schema-v1.json",
    "profile": "capsched-models/policy/r11/scenario-profile-v1.json",
    "review_contract_schema": "capsched-models/policy/r11/g0-review-contract-schema-v1.json",
    "review_contract": "capsched-models/policy/r11/g0-review-contract-v1.json",
    "claims": "capsched-models/assurance/claims.json",
    "mechanical_checker": "capsched-models/validation/validate-r11-g0-policy-profile.py",
}
EXPECTED_CASES = {
    "MUT-G0-UNKNOWN-FIELD": ("artifact", "policy", "CAT-G0-SCHEMA"),
    "MUT-G0-DUPLICATE-KEY": ("artifact", "policy", "CAT-G0-DUPLICATE-KEY"),
    "MUT-G0-SELF-AUTHORIZE": ("artifact", "policy", "CAT-G0-SELF-AUTHORIZATION"),
    "MUT-G0-DELETE-CATALOG-ITEM": ("artifact", "policy", "CAT-G0-CATALOG-COVERAGE"),
    "MUT-G0-REFERENCE-UNKNOWN": ("artifact", "policy", "CAT-G0-REFERENCE"),
    "MUT-G0-LINUX-AUTHORITY": ("artifact", "policy", "CAT-G0-TRUST"),
    "MUT-G0-PROVIDER-GENESIS": ("artifact", "policy", "CAT-G0-PROVIDER"),
    "MUT-G0-PROFILE-COLLAPSE": ("artifact", "profile", "CAT-G0-PROFILE"),
    "MUT-G0-PROFILE-SKIP": ("artifact", "profile", "CAT-G0-PROFILE-COVERAGE"),
    "MUT-G0-ORACLE-FORGERY": ("artifact", "policy", "HM-G0-ORACLE-DIGEST"),
    "MUT-G0-CHECKER-SKIP": ("meta_fixture", "META-G0-CHECK-RECEIPT", "HM-G0-CHECK-COVERAGE"),
    "MUT-G0-STALE-REVIEW": ("meta_fixture", "META-G0-STALE-REVIEW", "HM-G0-REVIEW-DIGEST"),
}
EXPECTED_CHECKS = {
    "HM-G0-001", "HM-G0-002", "CAT-G0-001", "CAT-G0-002",
    "CAT-G0-003", "CAT-G0-004", "CAT-G0-005", "CAT-G0-006",
    "HM-G0-003", "HM-G0-004", "HM-G0-005",
}
VALIDATOR_FLAGS = {
    "policy_schema": "--policy-schema",
    "policy": "--policy",
    "registry_schema": "--registry-schema",
    "registry": "--registry",
    "profile_schema": "--profile-schema",
    "profile": "--profile",
    "review_contract_schema": "--review-contract-schema",
    "review_contract": "--review-contract",
    "claims": "--claims",
}


class CampaignFailure(RuntimeError):
    pass


class MetaReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(detail)
        self.reject_id = reject_id
        self.detail = detail


class DuplicateKey(ValueError):
    pass


_MISSING = object()
_NO_DEFAULT = object()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CampaignFailure(message)


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
        raise CampaignFailure(f"{label}: invalid strict JSON: {exc}") from exc
    reject_bad_scalars(value)
    return value


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_stable_once(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        raise CampaignFailure(f"cannot open {path}: {exc}") from exc
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
    identity_before = (
        before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
        before.st_ctime_ns,
    )
    identity_after = (
        after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
        after.st_ctime_ns,
    )
    require(identity_before == identity_after, f"input changed while read: {path}")
    raw = b"".join(chunks)
    require(len(raw) == before.st_size, f"short read: {path}")
    return raw


def safe_repo_path(raw_path: str) -> Path:
    relative = PurePosixPath(raw_path)
    require(not relative.is_absolute(), f"absolute catalog path: {raw_path}")
    require(".." not in relative.parts and "." not in relative.parts, f"unsafe catalog path: {raw_path}")
    path = WORKTREE.joinpath(*relative.parts)
    require(path.is_relative_to(WORKTREE), f"path escapes worktree: {raw_path}")
    return path


def pointer_parts(pointer: str) -> list[str]:
    require(pointer == "" or pointer.startswith("/"), f"invalid JSON pointer: {pointer}")
    if pointer == "":
        return []
    return [
        part.replace("~1", "/").replace("~0", "~")
        for part in pointer.split("/")[1:]
    ]


def pointer_get(document: Any, pointer: str, default: Any = _NO_DEFAULT) -> Any:
    current = document
    for part in pointer_parts(pointer):
        if isinstance(current, dict) and part in current:
            current = current[part]
        elif isinstance(current, list) and part.isdigit() and int(part) < len(current):
            current = current[int(part)]
        elif default is not _NO_DEFAULT:
            return default
        else:
            raise CampaignFailure(f"unresolved JSON pointer: {pointer}")
    return current


def pointer_parent(document: Any, pointer: str) -> tuple[Any, str]:
    parts = pointer_parts(pointer)
    require(parts, "root replacement is not allowed")
    current = document
    for part in parts[:-1]:
        if isinstance(current, dict):
            require(part in current, f"unresolved JSON pointer: {pointer}")
            current = current[part]
        elif isinstance(current, list):
            require(part.isdigit() and int(part) < len(current), f"unresolved JSON pointer: {pointer}")
            current = current[int(part)]
        else:
            raise CampaignFailure(f"non-container JSON pointer: {pointer}")
    return current, parts[-1]


def check_preconditions(document: Any, raw: bytes, preconditions: list[dict[str, Any]]) -> None:
    for precondition in preconditions:
        kind = precondition["kind"]
        if kind == "pointer_equals":
            actual = pointer_get(document, precondition["path"])
            require(actual == precondition["value"], f"precondition mismatch at {precondition['path']}")
        elif kind == "pointer_absent":
            actual = pointer_get(document, precondition["path"], _MISSING)
            require(actual is _MISSING, f"pointer unexpectedly present: {precondition['path']}")
        elif kind == "array_not_contains":
            actual = pointer_get(document, precondition["path"])
            require(isinstance(actual, list), f"precondition is not an array: {precondition['path']}")
            require(precondition["value"] not in actual, f"array already contains value: {precondition['path']}")
        elif kind == "canonical_prefix_equals":
            prefix = precondition["value_utf8"].encode("utf-8")
            require(raw.startswith(prefix), "canonical prefix precondition mismatch")
        else:
            raise CampaignFailure(f"unknown precondition kind: {kind}")


def apply_patch(document: Any, operations: list[dict[str, Any]]) -> Any:
    result = copy.deepcopy(document)
    for operation in operations:
        op = operation["op"]
        require(op in {"add", "remove", "replace"}, f"invalid JSON patch operation: {op}")
        parent, token = pointer_parent(result, operation["path"])
        if isinstance(parent, dict):
            if op == "add":
                require(token not in parent, f"add target already exists: {operation['path']}")
                parent[token] = copy.deepcopy(operation["value"])
            elif op == "replace":
                require(token in parent, f"replace target missing: {operation['path']}")
                parent[token] = copy.deepcopy(operation["value"])
            else:
                require(token in parent, f"remove target missing: {operation['path']}")
                del parent[token]
        elif isinstance(parent, list):
            if op == "add":
                if token == "-":
                    parent.append(copy.deepcopy(operation["value"]))
                else:
                    require(token.isdigit() and int(token) <= len(parent), f"bad add index: {operation['path']}")
                    parent.insert(int(token), copy.deepcopy(operation["value"]))
            else:
                require(token.isdigit() and int(token) < len(parent), f"bad array index: {operation['path']}")
                if op == "replace":
                    parent[int(token)] = copy.deepcopy(operation["value"])
                else:
                    del parent[int(token)]
        else:
            raise CampaignFailure(f"patch parent is not a container: {operation['path']}")
    return result


def materialize_mutant(case: dict[str, Any], document: Any, baseline_raw: bytes) -> bytes:
    kind = case["transform"]["kind"]
    if kind in {"rfc6902_subset", "meta_rfc6902_subset"}:
        check_preconditions(document, baseline_raw, case["preconditions"])
        return canonical_bytes(apply_patch(document, case["transform"]["operations"]))
    if kind == "canonical_raw_splice":
        canonical = canonical_bytes(document)
        check_preconditions(document, canonical, case["preconditions"])
        result = canonical
        for operation in case["transform"]["operations"]:
            require(operation["op"] == "insert_after_prefix", "raw transform is not an exact splice")
            prefix = operation["prefix_utf8"].encode("utf-8")
            insertion = operation["value_utf8"].encode("utf-8")
            require(result.startswith(prefix), "raw splice prefix mismatch")
            result = prefix + insertion + result[len(prefix):]
        return result
    raise CampaignFailure(f"unknown transform kind: {kind}")


def validate_meta(document: dict[str, Any]) -> None:
    if {"required_checks", "executed_checks"} <= set(document):
        required = document["required_checks"]
        executed = document["executed_checks"]
        if (
            not isinstance(required, list)
            or not isinstance(executed, list)
            or len(required) != len(set(required))
            or len(executed) != len(set(executed))
            or set(required) != EXPECTED_CHECKS
            or set(executed) != EXPECTED_CHECKS
        ):
            raise MetaReject("HM-G0-CHECK-COVERAGE", "required and executed check sets differ")
        return
    if "review_receipt" in document:
        receipt = document["review_receipt"]
        if receipt.get("candidate_bundle_sha256") != document.get("candidate_bundle_sha256"):
            raise MetaReject("HM-G0-REVIEW-DIGEST", "review receipt binds a stale candidate bundle")
        return
    raise CampaignFailure("unknown meta fixture")


def write_exact(path: Path, raw: bytes, mode: int = 0o444) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        offset = 0
        while offset < len(raw):
            offset += os.write(descriptor, raw[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.chmod(path, mode)


def run_checker(snapshot: dict[str, bytes], override: tuple[str, bytes] | None = None) -> tuple[int, dict[str, Any], bytes]:
    with tempfile.TemporaryDirectory(prefix="r11-g0-exact-check-") as directory:
        root = Path(directory)
        paths: dict[str, Path] = {}
        for role, raw in snapshot.items():
            path = root / role
            write_exact(path, override[1] if override and override[0] == role else raw)
            paths[role] = path
        checker = paths["mechanical_checker"]
        command = [sys.executable, "-I", str(checker)]
        for role, flag in VALIDATOR_FLAGS.items():
            command.extend((flag, str(paths[role])))
        environment = {
            "LC_ALL": "C.UTF-8",
            "LANG": "C.UTF-8",
            "TZ": "UTC",
            "PYTHONHASHSEED": "0",
        }
        try:
            completed = subprocess.run(
                command,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                timeout=30,
                check=False,
                env=environment,
            )
        except subprocess.TimeoutExpired as exc:
            raise CampaignFailure("mechanical checker timed out") from exc
        require(not completed.stderr, f"mechanical checker wrote stderr: {completed.stderr!r}")
        payload = parse_json(completed.stdout, "mechanical checker output")
        require(isinstance(payload, dict), "mechanical checker output is not an object")
        return completed.returncode, payload, completed.stdout


def validate_catalog_shape(catalog: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    require(catalog["artifact_id"] == "domainlease-r11-g0-exact-mutation-catalog-v1", "wrong catalog ID")
    baselines = {row["role"]: row for row in catalog["baseline_artifacts"]}
    require(len(baselines) == len(catalog["baseline_artifacts"]), "duplicate baseline role")
    require(set(baselines) == set(EXPECTED_BASELINES), "baseline role inventory mismatch")
    for role, expected_path in EXPECTED_BASELINES.items():
        require(baselines[role]["path"] == expected_path, f"unexpected path for {role}")

    fixtures = {row["id"]: row for row in catalog["meta_fixtures"]}
    require(len(fixtures) == 2, "meta fixture inventory mismatch")
    require(set(fixtures) == {"META-G0-CHECK-RECEIPT", "META-G0-STALE-REVIEW"}, "unknown meta fixture")

    cases = {row["id"]: row for row in catalog["cases"]}
    require(len(cases) == len(catalog["cases"]), "duplicate mutation case")
    require(set(cases) == set(EXPECTED_CASES), "mutation case inventory mismatch")
    for case_id, (target_type, target_id, reject_id) in EXPECTED_CASES.items():
        case = cases[case_id]
        require(case["template_id"] == case_id, f"{case_id}: template ID mismatch")
        require(case["target_type"] == target_type, f"{case_id}: target type mismatch")
        require(case["target_id"] == target_id, f"{case_id}: target ID mismatch")
        require(case["expected"] == {"exit_code": 1, "status": "rejected", "reject_id": reject_id}, f"{case_id}: oracle mismatch")
    return baselines, fixtures


def capture_baselines(baselines: dict[str, dict[str, Any]]) -> dict[str, bytes]:
    captured: dict[str, bytes] = {}
    identities: set[tuple[int, int]] = set()
    for role in EXPECTED_BASELINES:
        entry = baselines[role]
        path = safe_repo_path(entry["path"])
        stat_result = os.stat(path, follow_symlinks=False)
        identity = (stat_result.st_dev, stat_result.st_ino)
        require(identity not in identities, f"baseline path aliases an earlier inode: {path}")
        identities.add(identity)
        raw = read_stable_once(path)
        require(len(raw) == entry["byte_length"], f"{role}: byte length mismatch")
        require(sha256(raw) == entry["sha256"], f"{role}: digest mismatch")
        captured[role] = raw
    return captured


def derive(catalog: dict[str, Any], baselines: dict[str, dict[str, Any]], fixtures: dict[str, dict[str, Any]]) -> dict[str, Any]:
    captured = capture_baselines(baselines)
    fixture_documents = {name: row["document"] for name, row in fixtures.items()}
    fixture_hashes = {name: sha256(canonical_bytes(value)) for name, value in fixture_documents.items()}
    derived_cases: dict[str, dict[str, str]] = {}
    for case in catalog["cases"]:
        if case["target_type"] == "artifact":
            baseline_raw = captured[case["target_id"]]
            document = parse_json(baseline_raw, case["target_id"])
            baseline_digest = sha256(baseline_raw)
        else:
            document = fixture_documents[case["target_id"]]
            baseline_raw = canonical_bytes(document)
            baseline_digest = sha256(baseline_raw)
        mutant = materialize_mutant(case, document, baseline_raw)
        derived_cases[case["id"]] = {
            "baseline_sha256": baseline_digest,
            "mutant_sha256": sha256(mutant),
        }
    return {
        "baseline_artifacts": {
            role: {"byte_length": len(raw), "sha256": sha256(raw)}
            for role, raw in captured.items()
        },
        "meta_fixture_sha256": fixture_hashes,
        "cases": derived_cases,
    }


def execute(catalog_raw: bytes, schema_raw: bytes, catalog: dict[str, Any], baselines: dict[str, dict[str, Any]], fixtures: dict[str, dict[str, Any]]) -> dict[str, Any]:
    captured = capture_baselines(baselines)
    fixture_documents = {name: row["document"] for name, row in fixtures.items()}
    for name, row in fixtures.items():
        require(sha256(canonical_bytes(row["document"])) == row["canonical_sha256"], f"{name}: fixture digest mismatch")
        validate_meta(row["document"])

    baseline_code, baseline_payload, baseline_stdout = run_checker(captured)
    require(baseline_code == 0 and baseline_payload.get("status") == "passed", f"baseline checker failed: {baseline_payload}")

    results: list[dict[str, Any]] = []
    for case in catalog["cases"]:
        if case["target_type"] == "artifact":
            baseline_raw = captured[case["target_id"]]
            document = parse_json(baseline_raw, case["target_id"])
        else:
            document = fixture_documents[case["target_id"]]
            baseline_raw = canonical_bytes(document)
        require(sha256(baseline_raw) == case["baseline_sha256"], f"{case['id']}: baseline digest mismatch")
        mutant = materialize_mutant(case, document, baseline_raw)
        require(sha256(mutant) == case["mutant_sha256"], f"{case['id']}: mutant digest mismatch")

        if case["target_type"] == "artifact":
            code, payload, _ = run_checker(captured, (case["target_id"], mutant))
            actual_reject = payload.get("reject_id")
            require(
                code == 1
                and payload.get("status") == "rejected"
                and actual_reject == case["expected"]["reject_id"],
                f"{case['id']}: expected {case['expected']}, got code={code} payload={payload}",
            )
        else:
            mutant_document = parse_json(mutant, case["id"])
            try:
                validate_meta(mutant_document)
            except MetaReject as exc:
                actual_reject = exc.reject_id
            else:
                raise CampaignFailure(f"{case['id']}: meta mutant was accepted")
            require(actual_reject == case["expected"]["reject_id"], f"{case['id']}: wrong meta reject {actual_reject}")

        results.append({
            "case_id": case["id"],
            "target_type": case["target_type"],
            "target_id": case["target_id"],
            "mutant_sha256": sha256(mutant),
            "actual_reject": actual_reject,
        })

    return {
        "schema_version": 1,
        "authority": "local_exact_regression_only",
        "status": "passed",
        "g0_complete": False,
        "r11_machine_source_construction": False,
        "semantic_freeze": False,
        "tla_translation": False,
        "catalog_sha256": sha256(catalog_raw),
        "catalog_schema_sha256": sha256(schema_raw),
        "runner_sha256": sha256(read_stable_once(Path(__file__))),
        "mechanical_checker_sha256": sha256(captured["mechanical_checker"]),
        "baseline_result_sha256": sha256(baseline_stdout),
        "baseline_input_sha256": {role: sha256(raw) for role, raw in captured.items()},
        "executed_cases": len(results),
        "deferred_external_cases": [],
        "results": results,
        "nonclaims": [
            "The candidate catalog, runner, checker, and inputs remain under one local change authority.",
            "Meta cases exercise exact protocol fixtures but do not authenticate a real external review or gate.",
            "This result cannot authorize G0, semantic freeze, TLA+, model support, Linux changes, or protection claims.",
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--derive", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        catalog_raw = read_stable_once(args.catalog)
        schema_raw = read_stable_once(args.schema)
        catalog = parse_json(catalog_raw, "mutation catalog")
        schema = parse_json(schema_raw, "mutation catalog schema")
        Draft202012Validator.check_schema(schema)
        errors = sorted(
            Draft202012Validator(schema).iter_errors(catalog),
            key=lambda error: [str(part) for part in error.absolute_path],
        )
        require(not errors, f"catalog schema rejection: {errors[0].message if errors else ''}")
        baselines, fixtures = validate_catalog_shape(catalog)
        result = derive(catalog, baselines, fixtures) if args.derive else execute(
            catalog_raw, schema_raw, catalog, baselines, fixtures
        )
    except (CampaignFailure, OSError, ValueError) as exc:
        print(json.dumps({"status": "failed", "failure": str(exc)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
