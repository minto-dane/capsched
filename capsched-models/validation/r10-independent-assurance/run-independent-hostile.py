#!/usr/bin/env python3
"""Run exact R10 hostile cases without importing code from the validator."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import random
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parent.parent.parent
MODEL_REL = Path("capsched-models/formal/0149-dynamic-residency-r10-machine-semantics")
DISPOSITION_REL = Path(
    "capsched-models/analysis/dynamic-residency-r10-pre-ir-hostile-review-rejection-v1.json"
)
CATALOG_NAME = "hostile-catalog-v1.json"
RESULT_NAME = "independent-hostile-results-v1.json"


class HarnessFailure(RuntimeError):
    def __init__(self, failure_id: str, message: str) -> None:
        super().__init__(f"{failure_id}: {message}")
        self.failure_id = failure_id
        self.message = message


def fail(failure_id: str, message: str) -> None:
    raise HarnessFailure(failure_id, message)


def require(condition: bool, failure_id: str, message: str) -> None:
    if not condition:
        fail(failure_id, message)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, "HM-DUPLICATE-KEY", key)
        result[key] = value
    return result


def reject_scalars(value: Any, path: str) -> None:
    require(value is not None, "HM-NULL", path)
    require(not isinstance(value, float), "HM-FLOAT", path)
    if isinstance(value, dict):
        for key, child in value.items():
            reject_scalars(child, f"{path}/{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_scalars(child, f"{path}/{index}")


def parse_json(data: bytes, label: str) -> Any:
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail("HM-JSON", f"{label}: {exc}")
    reject_scalars(value, label)
    return value


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n"
    ).encode("ascii")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_stable_once(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        fail("HM-INPUT-OPEN", f"{path}: {exc}")
    try:
        before = os.fstat(descriptor)
        require(stat.S_ISREG(before.st_mode), "HM-INPUT-TYPE", str(path))
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
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
        before.st_ctime_ns,
    )
    identity_after = (
        after.st_dev,
        after.st_ino,
        after.st_size,
        after.st_mtime_ns,
        after.st_ctime_ns,
    )
    require(identity_before == identity_after, "HM-INPUT-RACE", str(path))
    data = b"".join(chunks)
    require(len(data) == before.st_size, "HM-INPUT-SHORT-READ", str(path))
    return data


def write_exact(path: Path, data: bytes, mode: int = 0o444) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        offset = 0
        while offset < len(data):
            offset += os.write(descriptor, data[offset:])
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.chmod(path, mode)


def exact_keys(value: dict[str, Any], keys: set[str], label: str) -> None:
    require(set(value) == keys, "HM-CATALOG-SCHEMA", f"{label}: {sorted(set(value) ^ keys)}")


def validate_catalog(catalog: dict[str, Any]) -> None:
    exact_keys(
        catalog,
        {
            "schema_version",
            "catalog_id",
            "model_id",
            "status",
            "baseline_inputs",
            "repetition_seeds",
            "timeout_seconds",
            "cases",
            "nonclaims",
        },
        "catalog",
    )
    require(catalog["schema_version"] == 1, "HM-CATALOG-SCHEMA", "schema_version")
    require(catalog["status"] == "negative_and_regression_evidence_only", "HM-CATALOG-SCHEMA", "status")
    exact_keys(
        catalog["baseline_inputs"],
        {
            "materialize-r10.py",
            "r10-schema.json",
            "r10-source.json",
            "r9-rejection-disposition.json",
        },
        "baseline_inputs",
    )
    require(
        isinstance(catalog["repetition_seeds"], list)
        and len(catalog["repetition_seeds"]) >= 2
        and len(set(catalog["repetition_seeds"])) == len(catalog["repetition_seeds"]),
        "HM-CATALOG-SCHEMA",
        "repetition_seeds",
    )
    require(
        isinstance(catalog["timeout_seconds"], int) and 1 <= catalog["timeout_seconds"] <= 120,
        "HM-CATALOG-SCHEMA",
        "timeout_seconds",
    )
    case_ids: set[str] = set()
    mutations: set[str] = set()
    for case in catalog["cases"]:
        exact_keys(case, {"id", "mutation", "expected", "allowed_change_roots"}, "case")
        exact_keys(case["expected"], {"exit_code", "status", "reject_id"}, case["id"])
        require(case["id"] not in case_ids, "HM-DUPLICATE-CASE", case["id"])
        require(case["mutation"] not in mutations, "HM-DUPLICATE-MUTATION", case["mutation"])
        require(case["allowed_change_roots"], "HM-CATALOG-SCHEMA", f"{case['id']} changes")
        case_ids.add(case["id"])
        mutations.add(case["mutation"])
    require(mutations == set(MUTATORS), "HM-MUTATION-COVERAGE", str(sorted(mutations ^ set(MUTATORS))))


def entry(source: dict[str, Any], registry: str, item_id: str) -> dict[str, Any]:
    matches = [item for item in source[registry] if item.get("id") == item_id]
    require(len(matches) == 1, "HM-MUTATION-PRECONDITION", f"{registry}:{item_id}")
    return matches[0]


def status_promotion(source: dict[str, Any]) -> None:
    require(source["status"] == "draft", "HM-MUTATION-PRECONDITION", "status")
    source["status"] = "frozen"


def function_recursion(source: dict[str, Any]) -> None:
    entry(source, "functions", "AuthorityUseBalance")["body_ast"] = [
        "call", "AuthorityUseBalance", ["param", "node"], ["param", "shard"], ["param", "authority"]
    ]


def hidden_cross_shard_read(source: dict[str, Any]) -> None:
    require(not any(item.get("id") == "HostileHiddenRead" for item in source["functions"]), "HM-MUTATION-PRECONDITION", "HostileHiddenRead")
    source["functions"].append(
        {
            "id": "HostileHiddenRead",
            "parameters": [],
            "return_type": "Bool",
            "body_ast": [
                "eq",
                ["tag", ["read", "authority_account", ["id", "NodeID", "N0"], ["id", "ShardID", "S1"], ["id", "AuthorityID", "AUTH0"]]],
                ["string", "Live"],
            ],
        }
    )
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["guard_ast"] = ["and", action["guard_ast"], ["call", "HostileHiddenRead"]]


def transaction_identity_alias(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-PUBLISH-ELIGIBLE")
    alias = copy.deepcopy(txn["instance_scope"]["catalog_rows"][0])
    alias["slot"] = "TS3"
    txn["instance_scope"]["catalog_rows"].append(alias)


def temporal_action_guard(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["guard_ast"] = ["always", ["bool", True]]


def stateful_init(source: dict[str, Any]) -> None:
    entry(source, "variables", "monitor_epoch")["init_ast"] = ["read", "monitor_epoch", ["param", "node"], ["param", "shard"]]


def unguarded_variant_field(source: dict[str, Any]) -> None:
    account = ["read", "authority_account", ["param", "node"], ["param", "shard"], ["param", "authority"]]
    entry(source, "functions", "AuthorityUseBalance")["body_ast"] = ["field", ["field", account, "balance"], "uses"]


def concrete_duplicate_write(source: dict[str, Any]) -> None:
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["parameters"].append({"name": "other_node", "type": "NodeID"})
    action["updates"].append(
        {
            "target": ["loc", "monitor_epoch", ["param", "other_node"], ["param", "shard"]],
            "value_ast": ["add", ["read", "monitor_epoch", ["param", "other_node"], ["param", "shard"]], ["int", 1]],
        }
    )


def linearization_outside_write(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["linearization_ast"] = ["loc", "monitor_epoch", ["param", "node"], ["id", "ShardID", "S1"]]


def authority_exemption(source: dict[str, Any]) -> None:
    entry(source, "variables", "authority_account")["authority_relevant"] = False


def stateful_owner(source: dict[str, Any]) -> None:
    account = ["read", "authority_account", ["param", "node"], ["param", "shard"], ["param", "authority"]]
    writer = ["writer", "WR-MONITOR", ["param", "node"], ["param", "shard"]]
    entry(source, "variables", "authority_account")["owner_ast"] = [
        "if", ["eq", ["tag", account], ["string", "Live"]], writer, writer
    ]


def writer_cd_mismatch(source: dict[str, Any]) -> None:
    entry(source, "variables", "cpu_state")["consistency_domain_ast"] = [
        "cd", "CD-CPU", ["param", "node"], ["param", "shard"], ["param", "cpu"]
    ]


def boolean_shard(source: dict[str, Any]) -> None:
    entry(source, "variables", "authority_account")["transaction_shard_ast"] = ["bool", True]


def missing_edge_path(source: dict[str, Any]) -> None:
    entry(source, "objects", "OBJDEF-AuthorityCore")["reference_edges"][-1]["field_path"] = "missing"


def edge_coverage_hole(source: dict[str, Any]) -> None:
    entry(source, "objects", "OBJDEF-AuthorityCore")["reference_edges"].pop()


def constructor_no_allocator(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-AUTH-ISSUE")
    txn["commit_updates"] = [update for update in txn["commit_updates"] if update["target"][1] != "object_allocator"]


def instance_scope_hole(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["instance_scope"] = {
        "mode": "catalog",
        "catalog_rows": [{"node": "N0", "shard": "S0"}],
        "scope_nonclaim": "hostile narrowed fault scope",
    }


def recovery_mismatch(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["recovery_ast"] = ["int", 0]


def provider_fact_overwrite(source: dict[str, Any]) -> None:
    entry(source, "variables", "monitor_epoch")["storage_class"] = "provider_immutable_fact"


def unknown_claim(source: dict[str, Any]) -> None:
    entry(source, "proof_nodes", "PROOF-BASE-TYPING")["claim_ids"].append("R10-UNDECLARED-CLAIM")


def invariant_matrix_hole(source: dict[str, Any]) -> None:
    entry(source, "invariants", "INV-NONNEGATIVE-AUTHORITY")["preserved_by"].pop()


def unknown_witness_step(source: dict[str, Any]) -> None:
    entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["steps"][0]["parameters"]["node"] = "N1"


def disabled_witness_step(source: dict[str, Any]) -> None:
    steps = entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["steps"]
    steps[0], steps[1] = steps[1], steps[0]


def false_witness_final(source: dict[str, Any]) -> None:
    entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["final_formula_ast"] = ["bool", False]


def allocator_undercounts_publications(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-ASYNC-CARRIER")
    allocator = next(update for update in txn["commit_updates"] if update["target"][1] == "object_allocator")
    fields = allocator["value_ast"][2]
    fields["next_ordinal"][-1] = ["int", 1]
    fields["exhausted"][1][-1] = ["int", 1]


def conditional_object_constructor(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-AUTH-ISSUE")
    publication = next(update for update in txn["commit_updates"] if update["target"][1] == "object_store")
    original = publication["value_ast"]
    publication["value_ast"] = [
        "if", ["bool", False], original, ["variant", "ObjectSlotState", "Vacant", {"generation": ["int", 0]}]
    ]


def fake_edge_policy(source: dict[str, Any]) -> None:
    edge = entry(source, "objects", "OBJDEF-AuthorityCore")["reference_edges"][0]
    edge["class"] = "REF-FAKE"
    edge["strength"] = "audit_only"


def witness_skips_invariants(source: dict[str, Any]) -> None:
    entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["invariant_scope"] = "selected"


def cross_next_tag_fact(source: dict[str, Any]) -> None:
    account = ["read", "authority_account", ["id", "NodeID", "N0"], ["id", "ShardID", "S0"], ["id", "AuthorityID", "AUTH0"]]
    entry(source, "provider_formulas", "PF-STORE-EPOCH")["guarantee_ast"] = [
        "always",
        ["and", ["eq", ["tag", account], ["string", "Live"]], ["next", ["ge", ["field", ["field", account, "balance"], "uses"], ["int", 0]]]],
    ]


MUTATORS: dict[str, Callable[[dict[str, Any]], None]] = {
    "status_promotion": status_promotion,
    "function_recursion": function_recursion,
    "hidden_cross_shard_read": hidden_cross_shard_read,
    "transaction_identity_alias": transaction_identity_alias,
    "temporal_action_guard": temporal_action_guard,
    "stateful_init": stateful_init,
    "unguarded_variant_field": unguarded_variant_field,
    "concrete_duplicate_write": concrete_duplicate_write,
    "linearization_outside_write": linearization_outside_write,
    "authority_exemption": authority_exemption,
    "stateful_owner": stateful_owner,
    "writer_cd_mismatch": writer_cd_mismatch,
    "boolean_shard": boolean_shard,
    "missing_edge_path": missing_edge_path,
    "edge_coverage_hole": edge_coverage_hole,
    "constructor_no_allocator": constructor_no_allocator,
    "instance_scope_hole": instance_scope_hole,
    "recovery_mismatch": recovery_mismatch,
    "provider_fact_overwrite": provider_fact_overwrite,
    "unknown_claim": unknown_claim,
    "invariant_matrix_hole": invariant_matrix_hole,
    "unknown_witness_step": unknown_witness_step,
    "disabled_witness_step": disabled_witness_step,
    "false_witness_final": false_witness_final,
    "allocator_undercounts_publications": allocator_undercounts_publications,
    "conditional_object_constructor": conditional_object_constructor,
    "fake_edge_policy": fake_edge_policy,
    "witness_skips_invariants": witness_skips_invariants,
    "cross_next_tag_fact": cross_next_tag_fact,
}


def pointer_escape(value: str) -> str:
    return value.replace("~", "~0").replace("/", "~1")


def changed_pointers(before: Any, after: Any, path: str = "") -> set[str]:
    if type(before) is not type(after):
        return {path or "/"}
    if isinstance(before, dict):
        if set(before) != set(after):
            return {path or "/"}
        result: set[str] = set()
        for key in sorted(before):
            result |= changed_pointers(before[key], after[key], f"{path}/{pointer_escape(key)}")
        return result
    if isinstance(before, list):
        if len(before) != len(after):
            return {path or "/"}
        result: set[str] = set()
        for index, (left, right) in enumerate(zip(before, after)):
            segment = str(index)
            if isinstance(left, dict) and isinstance(right, dict) and left.get("id") == right.get("id") and isinstance(left.get("id"), str):
                segment = f"@{pointer_escape(left['id'])}"
            result |= changed_pointers(left, right, f"{path}/{segment}")
        return result
    return set() if before == after else {path or "/"}


def validate_change_scope(case: dict[str, Any], before: Any, after: Any) -> list[str]:
    changes = sorted(changed_pointers(before, after))
    roots = case["allowed_change_roots"]
    require(changes, "HM-NO-MUTATION", case["id"])
    for changed in changes:
        matching = [root for root in roots if changed == root or changed.startswith(root + "/")]
        require(len(matching) == 1, "HM-MUTATION-SCOPE", f"{case['id']}:{changed}")
    for root in roots:
        require(any(changed == root or changed.startswith(root + "/") for changed in changes), "HM-MUTATION-SCOPE", f"{case['id']}:unused:{root}")
    return changes


def parse_process_result(completed: subprocess.CompletedProcess[bytes]) -> dict[str, Any]:
    stdout_lines = [line for line in completed.stdout.splitlines() if line.strip()]
    stderr_lines = [line for line in completed.stderr.splitlines() if line.strip()]
    if completed.returncode == 0:
        require(len(stdout_lines) == 1 and not stderr_lines, "HM-MALFORMED-RESULT", "accepted streams")
        payload = parse_json(stdout_lines[0], "validator stdout")
    else:
        require(not stdout_lines and len(stderr_lines) == 1, "HM-MALFORMED-RESULT", "rejected streams")
        payload = parse_json(stderr_lines[0], "validator stderr")
    require(isinstance(payload, dict) and isinstance(payload.get("status"), str), "HM-MALFORMED-RESULT", "payload")
    return {
        "exit_code": completed.returncode,
        "status": payload["status"],
        "reject_id": payload.get("reject_id", ""),
        "payload": payload,
    }


def make_case_bundle(
    case_root: Path,
    input_bytes: dict[str, bytes],
    source_bytes: bytes,
) -> Path:
    formal = case_root / MODEL_REL
    analysis = case_root / DISPOSITION_REL.parent
    write_exact(formal / "materialize-r10.py", input_bytes["materialize-r10.py"], 0o555)
    write_exact(formal / "r10-schema.json", input_bytes["r10-schema.json"])
    write_exact(formal / "r10-source.json", source_bytes)
    write_exact(
        analysis / DISPOSITION_REL.name,
        input_bytes["r9-rejection-disposition.json"],
    )
    return formal


def run_validator(
    input_bytes: dict[str, bytes],
    work_root: Path,
    run_id: str,
    source_bytes: bytes,
    timeout: int,
) -> dict[str, Any]:
    case_root = work_root / run_id
    formal = make_case_bundle(case_root, input_bytes, source_bytes)
    environment = {
        "HOME": str(work_root / "empty-home"),
        "LANG": "C",
        "LC_ALL": "C",
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONHASHSEED": "0",
    }
    try:
        completed = subprocess.run(
            [sys.executable, str(formal / "materialize-r10.py"), "--validate-only"],
            cwd=formal,
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        fail("HM-TIMEOUT", run_id)
    return parse_process_result(completed)


def validate_complete_results(catalog: dict[str, Any], results: list[dict[str, Any]]) -> None:
    expected_keys = {
        (seed, case["id"])
        for seed in catalog["repetition_seeds"]
        for case in catalog["cases"]
    }
    actual_keys: set[tuple[int, str]] = set()
    expected_by_id = {case["id"]: case["expected"] for case in catalog["cases"]}
    projections: dict[str, set[tuple[int, str, str]]] = {}
    for result in results:
        require(result["case_id"] in expected_by_id, "HM-UNKNOWN-RESULT", result["case_id"])
        key = (result["seed"], result["case_id"])
        require(key not in actual_keys, "HM-DUPLICATE-RESULT", str(key))
        actual_keys.add(key)
        projections.setdefault(result["case_id"], set()).add(
            (result["exit_code"], result["status"], result["reject_id"])
        )
    require(actual_keys == expected_keys, "HM-MISSING-CASE", str(sorted(expected_keys ^ actual_keys)))
    require(all(len(values) == 1 for values in projections.values()), "HM-NONDETERMINISTIC", str(projections))
    for result in results:
        expected = expected_by_id[result["case_id"]]
        actual_projection = {
            "exit_code": result["exit_code"],
            "status": result["status"],
            "reject_id": result["reject_id"],
        }
        require(actual_projection == expected, "HM-WRONG-REJECT", f"{result['case_id']}:{actual_projection}")


def validate_baseline_hashes(expected: dict[str, str], actual: dict[str, str]) -> None:
    require(actual == expected, "HM-BASELINE-DIGEST", str(actual))


def run_meta_checks(catalog: dict[str, Any], results: list[dict[str, Any]]) -> list[dict[str, str]]:
    checks: list[tuple[str, str, Callable[[list[dict[str, Any]]], None]]] = []

    def skip_case(mutant: list[dict[str, Any]]) -> None:
        mutant.pop()

    def duplicate_case(mutant: list[dict[str, Any]]) -> None:
        mutant.append(copy.deepcopy(mutant[0]))

    def forge_result(mutant: list[dict[str, Any]]) -> None:
        target = mutant[0]["case_id"]
        for item in mutant:
            if item["case_id"] == target:
                item["reject_id"] = "IR-FORGED"

    def nondeterministic(mutant: list[dict[str, Any]]) -> None:
        target = mutant[0]["case_id"]
        peer = next(item for item in mutant[1:] if item["case_id"] == target)
        peer["reject_id"] = "IR-NONDETERMINISTIC"

    checks.extend(
        [
            ("META-SKIPPED-CASE", "HM-MISSING-CASE", skip_case),
            ("META-DUPLICATE-CASE", "HM-DUPLICATE-RESULT", duplicate_case),
            ("META-FORGED-RESULT", "HM-WRONG-REJECT", forge_result),
            ("META-NONDETERMINISM", "HM-NONDETERMINISTIC", nondeterministic),
        ]
    )
    meta_results: list[dict[str, str]] = []
    for check_id, expected_failure, mutate in checks:
        mutant = copy.deepcopy(results)
        mutate(mutant)
        actual = "ACCEPTED"
        try:
            validate_complete_results(catalog, mutant)
        except HarnessFailure as exc:
            actual = exc.failure_id
        require(actual == expected_failure, "HM-META-SURVIVOR", f"{check_id}:{actual}")
        meta_results.append({"id": check_id, "expected_failure_id": expected_failure, "actual_failure_id": actual})
    for check_id, replacement in (
        ("META-CONSTANT-HASH", "0" * 64),
        ("META-STALE-INPUT", "f" * 64),
    ):
        expected = dict(catalog["baseline_inputs"])
        expected["r10-source.json"] = replacement
        actual = "ACCEPTED"
        try:
            validate_baseline_hashes(expected, catalog["baseline_inputs"])
        except HarnessFailure as exc:
            actual = exc.failure_id
        require(actual == "HM-BASELINE-DIGEST", "HM-META-SURVIVOR", f"{check_id}:{actual}")
        meta_results.append({"id": check_id, "expected_failure_id": "HM-BASELINE-DIGEST", "actual_failure_id": actual})
    return meta_results


def worker(snapshot_root: Path, work_root: Path) -> dict[str, Any]:
    catalog_bytes = (snapshot_root / "harness" / CATALOG_NAME).read_bytes()
    catalog = parse_json(catalog_bytes, CATALOG_NAME)
    validate_catalog(catalog)
    input_paths = {
        "materialize-r10.py": snapshot_root / MODEL_REL / "materialize-r10.py",
        "r10-schema.json": snapshot_root / MODEL_REL / "r10-schema.json",
        "r10-source.json": snapshot_root / MODEL_REL / "r10-source.json",
        "r9-rejection-disposition.json": snapshot_root / DISPOSITION_REL,
    }
    input_bytes = {name: read_stable_once(path) for name, path in input_paths.items()}
    input_hashes = {name: digest(data) for name, data in input_bytes.items()}
    validate_baseline_hashes(catalog["baseline_inputs"], input_hashes)
    source = parse_json(input_bytes["r10-source.json"], "r10-source.json")
    require(source.get("imports") == [], "HM-UNSNAPSHOTTED-IMPORT", "R10 v1 requires an empty import registry")
    baseline_results = []
    results: list[dict[str, Any]] = []
    cases_by_id = {case["id"]: case for case in catalog["cases"]}
    for seed in catalog["repetition_seeds"]:
        baseline = run_validator(
            input_bytes,
            work_root,
            f"baseline-{seed}",
            input_bytes["r10-source.json"],
            catalog["timeout_seconds"],
        )
        require(
            baseline["exit_code"] == 0 and baseline["status"] == "accepted",
            "HM-BASELINE-REJECTED",
            f"{seed}:{baseline}",
        )
        require(baseline["payload"].get("inputs") == input_hashes, "HM-BASELINE-IDENTITY", str(seed))
        baseline_results.append({"seed": seed, "exit_code": 0, "status": "accepted", "input_hashes": input_hashes})
        order = list(cases_by_id)
        random.Random(seed).shuffle(order)
        for ordinal, case_id in enumerate(order):
            case = cases_by_id[case_id]
            mutant = copy.deepcopy(source)
            MUTATORS[case["mutation"]](mutant)
            changes = validate_change_scope(case, source, mutant)
            result = run_validator(
                input_bytes,
                work_root,
                f"case-{seed}-{ordinal:03d}-{case_id}",
                canonical_bytes(mutant),
                catalog["timeout_seconds"],
            )
            results.append(
                {
                    "seed": seed,
                    "ordinal": ordinal,
                    "case_id": case_id,
                    "mutation": case["mutation"],
                    "changed_pointers": changes,
                    "exit_code": result["exit_code"],
                    "status": result["status"],
                    "reject_id": result["reject_id"],
                }
            )
    validate_complete_results(catalog, results)
    meta_results = run_meta_checks(catalog, results)
    return {
        "schema_version": 1,
        "status": "passed",
        "authority": "development_regression_only",
        "catalog_id": catalog["catalog_id"],
        "inputs": input_hashes,
        "catalog_sha256": digest(catalog_bytes),
        "runner_sha256": digest((snapshot_root / "harness" / Path(__file__).name).read_bytes()),
        "baseline_results": baseline_results,
        "case_count": len(catalog["cases"]),
        "repetition_count": len(catalog["repetition_seeds"]),
        "results": results,
        "meta_results": meta_results,
        "nonclaims": catalog["nonclaims"],
    }


def capture_inputs() -> tuple[dict[str, bytes], dict[str, Path]]:
    paths = {
        "runner": Path(__file__).resolve(),
        "catalog": HERE / CATALOG_NAME,
        "materializer": WORKTREE / MODEL_REL / "materialize-r10.py",
        "schema": WORKTREE / MODEL_REL / "r10-schema.json",
        "source": WORKTREE / MODEL_REL / "r10-source.json",
        "disposition": WORKTREE / DISPOSITION_REL,
    }
    return ({name: read_stable_once(path) for name, path in paths.items()}, paths)


def stage_snapshot(root: Path, captured: dict[str, bytes]) -> Path:
    write_exact(root / "harness" / Path(__file__).name, captured["runner"], 0o555)
    write_exact(root / "harness" / CATALOG_NAME, captured["catalog"])
    write_exact(root / MODEL_REL / "materialize-r10.py", captured["materializer"], 0o555)
    write_exact(root / MODEL_REL / "r10-schema.json", captured["schema"])
    write_exact(root / MODEL_REL / "r10-source.json", captured["source"])
    write_exact(root / DISPOSITION_REL, captured["disposition"])
    return root / "harness" / Path(__file__).name


def publish_result(path: Path, data: bytes) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
        directory = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def parent(args: argparse.Namespace) -> int:
    captured, original_paths = capture_inputs()
    with tempfile.TemporaryDirectory(prefix="r10-assurance-snapshot-") as snapshot_name, tempfile.TemporaryDirectory(prefix="r10-assurance-work-") as work_name:
        snapshot_root = Path(snapshot_name)
        worker_path = stage_snapshot(snapshot_root, captured)
        completed = subprocess.run(
            [sys.executable, str(worker_path), "--worker", "--snapshot-root", str(snapshot_root), "--work-root", work_name],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180,
            check=False,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1", "PYTHONHASHSEED": "0"},
        )
        require(completed.returncode == 0, "HM-WORKER", completed.stderr.decode("utf-8", "replace"))
        lines = [line for line in completed.stdout.splitlines() if line.strip()]
        require(len(lines) == 1 and not completed.stderr.strip(), "HM-WORKER-OUTPUT", completed.stderr.decode("utf-8", "replace"))
        result = parse_json(lines[0], "worker result")
    changed = []
    for name, path in original_paths.items():
        try:
            current = read_stable_once(path)
        except HarnessFailure:
            changed.append(name)
            continue
        if digest(current) != digest(captured[name]):
            changed.append(name)
    require(not changed, "HM-INPUT-CHANGED", str(changed))
    result_bytes = canonical_bytes(result)
    result_path = HERE / RESULT_NAME
    if args.write_evidence:
        publish_result(result_path, result_bytes)
    if args.check:
        require(result_path.is_file(), "HM-STALE-EVIDENCE", "missing result")
        require(read_stable_once(result_path) == result_bytes, "HM-STALE-EVIDENCE", RESULT_NAME)
    sys.stdout.buffer.write(result_bytes)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--snapshot-root", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--work-root", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.worker:
            require(args.snapshot_root is not None and args.work_root is not None, "HM-CLI", "worker paths")
            result = worker(args.snapshot_root, args.work_root)
            sys.stdout.buffer.write(canonical_bytes(result))
            return 0
        return parent(args)
    except HarnessFailure as exc:
        print(json.dumps({"status": "failed", "failure_id": exc.failure_id, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
