#!/usr/bin/env python3
"""Execute adversarial mutations against the R10 schema and semantic validator."""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable

import jsonschema


HERE = Path(__file__).resolve().parent
MATERIALIZER = HERE / "materialize-r10.py"
RESULTS = HERE / "r10-hostile-results.json"


def load_materializer() -> Any:
    spec = importlib.util.spec_from_file_location("r10_materializer", MATERIALIZER)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load materialize-r10.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


M = load_materializer()


def entry(source: dict[str, Any], registry: str, item_id: str) -> dict[str, Any]:
    return next(item for item in source[registry] if item["id"] == item_id)


def mutate_status(source: dict[str, Any]) -> None:
    source["status"] = "frozen"


def mutate_recursive_function(source: dict[str, Any]) -> None:
    function = entry(source, "functions", "AuthorityUseBalance")
    function["body_ast"] = [
        "call",
        "AuthorityUseBalance",
        ["param", "node"],
        ["param", "shard"],
        ["param", "authority"],
    ]


def mutate_hidden_cross_shard_read(source: dict[str, Any]) -> None:
    source["functions"].append(
        {
            "id": "HostileHiddenRead",
            "parameters": [],
            "return_type": "Bool",
            "body_ast": [
                "eq",
                [
                    "tag",
                    [
                        "read",
                        "authority_account",
                        ["id", "NodeID", "N0"],
                        ["id", "ShardID", "S1"],
                        ["id", "AuthorityID", "AUTH0"],
                    ],
                ],
                ["string", "Live"],
            ],
        }
    )
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["guard_ast"] = ["and", action["guard_ast"], ["call", "HostileHiddenRead"]]


def mutate_transaction_identity_alias(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-PUBLISH-ELIGIBLE")
    alias = copy.deepcopy(txn["instance_scope"]["catalog_rows"][0])
    alias["slot"] = "TS3"
    txn["instance_scope"]["catalog_rows"].append(alias)


def mutate_temporal_action_guard(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["guard_ast"] = [
        "always",
        ["bool", True],
    ]


def mutate_stateful_init(source: dict[str, Any]) -> None:
    variable = entry(source, "variables", "monitor_epoch")
    variable["init_ast"] = [
        "read",
        "monitor_epoch",
        ["param", "node"],
        ["param", "shard"],
    ]


def mutate_unguarded_variant_field(source: dict[str, Any]) -> None:
    function = entry(source, "functions", "AuthorityUseBalance")
    account = [
        "read",
        "authority_account",
        ["param", "node"],
        ["param", "shard"],
        ["param", "authority"],
    ]
    function["body_ast"] = ["field", ["field", account, "balance"], "uses"]


def mutate_concrete_duplicate_write(source: dict[str, Any]) -> None:
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["parameters"].append({"name": "other_node", "type": "NodeID"})
    action["updates"].append(
        {
            "target": [
                "loc",
                "monitor_epoch",
                ["param", "other_node"],
                ["param", "shard"],
            ],
            "value_ast": [
                "add",
                [
                    "read",
                    "monitor_epoch",
                    ["param", "other_node"],
                    ["param", "shard"],
                ],
                ["int", 1],
            ],
        }
    )


def mutate_linearization_outside_write(source: dict[str, Any]) -> None:
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["linearization_ast"] = [
        "loc",
        "monitor_epoch",
        ["param", "node"],
        ["id", "ShardID", "S1"],
    ]


def mutate_authority_exemption(source: dict[str, Any]) -> None:
    entry(source, "variables", "authority_account")["authority_relevant"] = False


def mutate_stateful_owner(source: dict[str, Any]) -> None:
    variable = entry(source, "variables", "authority_account")
    variable["owner_ast"] = [
        "if",
        [
            "eq",
            [
                "tag",
                [
                    "read",
                    "authority_account",
                    ["param", "node"],
                    ["param", "shard"],
                    ["param", "authority"],
                ],
            ],
            ["string", "Live"],
        ],
        ["writer", "WR-MONITOR", ["param", "node"], ["param", "shard"]],
        ["writer", "WR-MONITOR", ["param", "node"], ["param", "shard"]],
    ]


def mutate_writer_cd_mismatch(source: dict[str, Any]) -> None:
    variable = entry(source, "variables", "cpu_state")
    variable["consistency_domain_ast"] = [
        "cd",
        "CD-CPU",
        ["param", "node"],
        ["param", "shard"],
        ["param", "cpu"],
    ]


def mutate_boolean_shard(source: dict[str, Any]) -> None:
    entry(source, "variables", "authority_account")["transaction_shard_ast"] = [
        "bool",
        True,
    ]


def mutate_missing_edge_path(source: dict[str, Any]) -> None:
    object_def = entry(source, "objects", "OBJDEF-AuthorityCore")
    object_def["reference_edges"][-1]["field_path"] = "missing"


def mutate_edge_coverage_hole(source: dict[str, Any]) -> None:
    entry(source, "objects", "OBJDEF-AuthorityCore")["reference_edges"].pop()


def mutate_constructor_without_allocator(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-AUTH-ISSUE")
    txn["commit_updates"] = [
        update for update in txn["commit_updates"] if update["target"][1] != "object_allocator"
    ]


def mutate_instance_scope_hole(source: dict[str, Any]) -> None:
    action = entry(source, "actions", "ACT-MONITOR-CRASH")
    action["instance_scope"] = {
        "mode": "catalog",
        "catalog_rows": [{"node": "N0", "shard": "S0"}],
        "scope_nonclaim": "hostile narrowed fault scope",
    }


def mutate_recovery_mismatch(source: dict[str, Any]) -> None:
    entry(source, "actions", "ACT-MONITOR-CRASH")["recovery_ast"] = ["int", 0]


def mutate_provider_fact_overwrite(source: dict[str, Any]) -> None:
    entry(source, "variables", "monitor_epoch")["storage_class"] = "provider_immutable_fact"


def mutate_unknown_claim(source: dict[str, Any]) -> None:
    entry(source, "proof_nodes", "PROOF-BASE-TYPING")["claim_ids"].append(
        "R10-UNDECLARED-CLAIM"
    )


def mutate_invariant_matrix_hole(source: dict[str, Any]) -> None:
    entry(source, "invariants", "INV-NONNEGATIVE-AUTHORITY")["preserved_by"].pop()


def mutate_unknown_witness_step(source: dict[str, Any]) -> None:
    witness = entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")
    witness["steps"][0]["parameters"]["node"] = "N1"


def mutate_disabled_witness_step(source: dict[str, Any]) -> None:
    witness = entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")
    witness["steps"][0], witness["steps"][1] = witness["steps"][1], witness["steps"][0]


def mutate_false_witness_final(source: dict[str, Any]) -> None:
    entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["final_formula_ast"] = [
        "bool",
        False,
    ]


def mutate_allocator_undercharges_publications(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-ASYNC-CARRIER")
    allocator = next(
        update for update in txn["commit_updates"] if update["target"][1] == "object_allocator"
    )
    fields = allocator["value_ast"][2]
    fields["next_ordinal"][-1] = ["int", 1]
    fields["exhausted"][1][-1] = ["int", 1]


def mutate_conditional_constructor(source: dict[str, Any]) -> None:
    txn = entry(source, "transaction_kinds", "TXN-AUTH-ISSUE")
    publication = next(
        update for update in txn["commit_updates"] if update["target"][1] == "object_store"
    )
    original = publication["value_ast"]
    publication["value_ast"] = [
        "if",
        ["bool", False],
        original,
        ["variant", "ObjectSlotState", "Vacant", {"generation": ["int", 0]}],
    ]


def mutate_fake_edge_policy(source: dict[str, Any]) -> None:
    edge = entry(source, "objects", "OBJDEF-AuthorityCore")["reference_edges"][0]
    edge["class"] = "REF-FAKE"
    edge["strength"] = "audit_only"


def mutate_witness_skips_invariants(source: dict[str, Any]) -> None:
    entry(source, "witnesses", "WIT-AUTHORITY-TRANSFER")["invariant_scope"] = "selected"


def mutate_cross_next_tag_fact(source: dict[str, Any]) -> None:
    account = [
        "read",
        "authority_account",
        ["id", "NodeID", "N0"],
        ["id", "ShardID", "S0"],
        ["id", "AuthorityID", "AUTH0"],
    ]
    entry(source, "provider_formulas", "PF-STORE-EPOCH")["guarantee_ast"] = [
        "always",
        [
            "and",
            ["eq", ["tag", account], ["string", "Live"]],
            [
                "next",
                [
                    "ge",
                    ["field", ["field", account, "balance"], "uses"],
                    ["int", 0],
                ],
            ],
        ],
    ]


CASES: list[tuple[str, str, Callable[[dict[str, Any]], None]]] = [
    ("HOSTILE-STATUS-PROMOTION", "IR-SCHEMA", mutate_status),
    ("HOSTILE-FUNCTION-RECURSION", "IR-FUNCTION-CYCLE", mutate_recursive_function),
    ("HOSTILE-HIDDEN-CROSS-SHARD-READ", "IR-CD", mutate_hidden_cross_shard_read),
    ("HOSTILE-TXN-IDENTITY-ALIAS", "IR-TXN-IDENTITY", mutate_transaction_identity_alias),
    ("HOSTILE-TEMPORAL-ACTION-GUARD", "IR-AST-CONTEXT", mutate_temporal_action_guard),
    ("HOSTILE-STATEFUL-INIT", "IR-AST-CONTEXT", mutate_stateful_init),
    ("HOSTILE-UNGUARDED-VARIANT-FIELD", "IR-VARIANT-FIELD", mutate_unguarded_variant_field),
    ("HOSTILE-CONCRETE-DUPLICATE-WRITE", "IR-DUPLICATE-WRITE", mutate_concrete_duplicate_write),
    ("HOSTILE-LINEARIZATION-OUTSIDE-WRITE", "IR-LINEARIZATION", mutate_linearization_outside_write),
    ("HOSTILE-AUTHORITY-EXEMPTION", "IR-AUTHORITY-CLASS", mutate_authority_exemption),
    ("HOSTILE-STATEFUL-OWNER", "IR-AST-CONTEXT", mutate_stateful_owner),
    ("HOSTILE-WRITER-CD-MISMATCH", "IR-WRITER-CD", mutate_writer_cd_mismatch),
    ("HOSTILE-BOOLEAN-SHARD", "IR-SHARD", mutate_boolean_shard),
    ("HOSTILE-MISSING-EDGE-PATH", "IR-EDGE", mutate_missing_edge_path),
    ("HOSTILE-EDGE-COVERAGE-HOLE", "IR-EDGE-COVERAGE", mutate_edge_coverage_hole),
    ("HOSTILE-CONSTRUCTOR-NO-ALLOCATOR", "IR-OBJECT-ALLOCATOR", mutate_constructor_without_allocator),
    ("HOSTILE-INSTANCE-SCOPE-HOLE", "IR-INSTANCE-POLICY", mutate_instance_scope_hole),
    ("HOSTILE-RECOVERY-MISMATCH", "IR-RECOVERY", mutate_recovery_mismatch),
    ("HOSTILE-PROVIDER-FACT-OVERWRITE", "IR-PROVIDER-WRITE-ONCE", mutate_provider_fact_overwrite),
    ("HOSTILE-UNKNOWN-CLAIM", "IR-PROOF", mutate_unknown_claim),
    ("HOSTILE-INVARIANT-MATRIX-HOLE", "IR-INVARIANT-COVERAGE", mutate_invariant_matrix_hole),
    ("HOSTILE-UNKNOWN-WITNESS-STEP", "IR-WITNESS", mutate_unknown_witness_step),
    ("HOSTILE-DISABLED-WITNESS-STEP", "IR-WITNESS-DISABLED", mutate_disabled_witness_step),
    ("HOSTILE-FALSE-WITNESS-FINAL", "IR-WITNESS-FINAL", mutate_false_witness_final),
    ("HOSTILE-ALLOCATOR-UNDERCOUNTS-PUBLICATIONS", "IR-OBJECT-ALLOCATOR", mutate_allocator_undercharges_publications),
    ("HOSTILE-CONDITIONAL-OBJECT-CONSTRUCTOR", "IR-OBJECT-CONSTRUCTOR", mutate_conditional_constructor),
    ("HOSTILE-FAKE-EDGE-POLICY", "IR-EDGE-POLICY", mutate_fake_edge_policy),
    ("HOSTILE-WITNESS-SKIPS-INVARIANTS", "IR-SCHEMA", mutate_witness_skips_invariants),
    ("HOSTILE-CROSS-NEXT-TAG-FACT", "IR-VARIANT-FIELD", mutate_cross_next_tag_fact),
]


def validate_mutant(
    source: dict[str, Any],
    schema: dict[str, Any],
    disposition: dict[str, Any],
) -> str:
    try:
        jsonschema.Draft202012Validator(schema).validate(source)
    except jsonschema.ValidationError:
        return "IR-SCHEMA"
    try:
        M.SemanticModel(source, HERE, disposition).validate()
    except M.Reject as exc:
        return exc.reject_id
    return "ACCEPTED"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    schema = M.load_json(HERE / "r10-schema.json")
    source = M.load_json(HERE / "r10-source.json")
    disposition = M.load_json(M.DISPOSITION_PATH)
    declared = {
        mutation["id"]: mutation["expected_reject_ids"]
        for mutation in source["mutation_obligations"]
    }
    executable = {case_id: [expected] for case_id, expected, _ in CASES}
    if declared != executable:
        print(
            json.dumps(
                {
                    "status": "registry-mismatch",
                    "missing_executable": sorted(set(declared) - set(executable)),
                    "missing_declaration": sorted(set(executable) - set(declared)),
                    "expectation_mismatch": sorted(
                        key
                        for key in set(declared) & set(executable)
                        if declared[key] != executable[key]
                    ),
                },
                sort_keys=True,
            )
        )
        return 1
    base_result = validate_mutant(copy.deepcopy(source), schema, disposition)
    if base_result != "ACCEPTED":
        print(json.dumps({"status": "base-rejected", "reject_id": base_result}, sort_keys=True))
        return 1
    results = []
    failed = False
    for case_id, expected, mutate in CASES:
        mutant = copy.deepcopy(source)
        mutate(mutant)
        actual = validate_mutant(mutant, schema, disposition)
        passed = actual == expected
        failed |= not passed
        results.append(
            {
                "id": case_id,
                "expected_reject_id": expected,
                "actual_reject_id": actual,
                "passed": passed,
            }
        )
    evidence = {
        "schema_version": 1,
        "status": "failed" if failed else "ok",
        "base": "accepted",
        "case_count": len(results),
        "inputs": {
            "r10-schema.json": M.sha256_bytes((HERE / "r10-schema.json").read_bytes()),
            "r10-source.json": M.sha256_bytes((HERE / "r10-source.json").read_bytes()),
            "materialize-r10.py": M.sha256_bytes(MATERIALIZER.read_bytes()),
            "test-r10-hostile.py": M.sha256_bytes(Path(__file__).resolve().read_bytes()),
            "r9-rejection-disposition.json": M.sha256_bytes(M.DISPOSITION_PATH.read_bytes()),
        },
        "mutation_registry_sha256": M.sha256_bytes(
            M.canonical_bytes(source["mutation_obligations"])
        ),
        "results": results,
    }
    evidence_bytes = M.canonical_bytes(evidence)
    if args.write_evidence and not failed:
        M.atomic_replace(RESULTS, evidence_bytes)
        M.fsync_directory(HERE)
    if args.check:
        if not RESULTS.is_file() or RESULTS.read_bytes() != evidence_bytes:
            print(json.dumps({"status": "stale-evidence"}, sort_keys=True))
            return 1
    print(json.dumps(evidence, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
