#!/usr/bin/env python3
"""Validate only the local structural integrity of DL-SemFoundation-3."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
EPOCH2 = ROOT / "policy" / "r11" / "epoch2"
SPEC_PATH = EPOCH2 / "semantic-foundation-v3.md"
SCHEMA_PATH = EPOCH2 / "semantic-foundation-schema-v3.json"
CONTRACT_PATH = EPOCH2 / "semantic-foundation-v3.json"
V2_SCHEMA_PATH = EPOCH2 / "semantic-kernel-contract-schema-v2.json"
V2_CONTRACT_PATH = EPOCH2 / "semantic-kernel-contract-v2.json"
MAX_BYTES = 4 * 1024 * 1024

EXPECTED_V2 = {
    "schema": "f30bf42e28a527904d0663feec7e34dc3494c7708169d0f3741fa2d0b4ae13ad",
    "contract": "a70489bf816569f382268d69e23e147a0319b7c0370717cc1367f3b1834f8c8a",
}
EXPECTED_CLAUSES = {f"SF-DEN-{index:03d}" for index in range(1, 19)}
EXPECTED_NAMESPACES = {
    "SORT",
    "UNIT",
    "LIMIT",
    "PRODUCT",
    "CONSTANT",
    "EVENT",
    "ACTION",
}
EXPECTED_SORTS = {
    "BOOL",
    "ATOM",
    "ENUM",
    "QTY",
    "PROD",
    "SUM",
    "OPTION",
    "FINSET",
    "TOTALMAP",
    "ONE-SORT",
}
EXPECTED_JUDGMENTS = {
    "TERM",
    "STATIC-TERM",
    "PRE-TERM",
    "POST-TERM",
    "STATE-PRED",
    "ACTION-REL",
}
EXPECTED_EXPRESSIONS = {
    "BOOL-LITERAL",
    "TYPED-LITERAL",
    "VARIABLE",
    "LET",
    "PRODUCT-CONSTRUCT",
    "PRODUCT-FIELD",
    "SUM-CONSTRUCT",
    "SUM-MATCH",
    "MAP-GET",
    "MAP-SET",
    "SET-EMPTY",
    "SET-INSERT",
    "SET-REMOVE",
    "SET-MEMBER",
    "SET-SUBSET",
    "SET-UNION",
    "SET-DIFFERENCE",
    "BOOL-AND",
    "BOOL-OR",
    "BOOL-NOT",
    "BOOL-IMPLIES",
    "BOOL-IFF",
    "SAME-SORT-EQ",
    "QTY-ORDER",
    "QTY-ADD",
    "QTY-SUB",
    "IF",
    "FORALL",
    "EXISTS",
    "PRE-READ",
    "POST-READ",
    "EVENT-READ",
}
EXPECTED_ENTITIES = {
    "INTERPRETATION",
    "STATE",
    "EVENT-VALUE",
    "ACTION-FAMILY",
    "ACTION-LABEL",
    "STUTTER",
    "NEXT",
    "ENABLED",
    "TRACE",
    "FINITE-PREFIX",
}
EXPECTED_EXTENSIONS = {
    "PROGRESS-FAIRNESS",
    "TIMED-PROVIDER",
    "TRANSACTION-DURABILITY",
    "DISTRIBUTED",
    "TWO-TRACE-NONINTERFERENCE",
}
EXPECTED_OBLIGATIONS = {
    "INIT-NONEMPTY",
    "INIT-SAFE",
    "ACTION-INDUCTIVE",
    "ALWAYS-SAFETY",
    "ACTION-BRANCH-REACHABLE",
    "REACHABLE-ANTECEDENT",
    "FRAME-EXACT",
    "ACTION-CLOSURE",
    "WEAK-FAIRNESS",
    "STRONG-FAIRNESS",
    "RESPONSE",
    "TIMED-BOUND",
    "CUT-RECOVERY-RECRASH",
    "TRANSFER-CONSERVATION",
    "RELATIONAL-NONINTERFERENCE",
    "BACKEND-PRESERVATION",
}
REQUIRED_SPEC_SNIPPETS = (
    "[[State]]I = product over p in Product",
    "[[a]]I subseteq [[State]]I x [[Pa]]I x [[State]]I x [[Event]]I",
    "Gamma |- t : Term<T,R>",
    "ArithResult(q) = Sum(Ok:q, Overflow:One, Underflow:One)",
    "Stutter(s,s',e) iff s' = s and e = StutterEvent(one)",
    "Enabled(a,s,p) iff exists s',e: [[a]]I(s,p,s',e)",
    "I |= InitNonempty",
    "WF(a,p) iff for every i",
    "Network silence is never",
    "Confidentiality uses self-composition",
    "no counterexample in I_F",
    "Differential agreement is regression evidence",
)


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> None:
    raise Reject(reject_id, detail)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("K0-STRUCT-DUPLICATE-KEY", key)
        result[key] = value
    return result


def reject_scalars(value: Any, path: str = "$") -> None:
    if value is None or isinstance(value, float):
        reject("K0-STRUCT-SCALAR", path)
    if isinstance(value, dict):
        for key, child in value.items():
            reject_scalars(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_scalars(child, f"{path}[{index}]")


def read_once(path: Path) -> bytes:
    raw = path.read_bytes()
    if not raw or len(raw) > MAX_BYTES:
        reject("K0-STRUCT-SIZE", f"{path}: {len(raw)}")
    return raw


def parse_json(raw: bytes, path: Path) -> Any:
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=strict_object)
    except UnicodeDecodeError as exc:
        reject("K0-STRUCT-UTF8", f"{path}: {exc}")
    except json.JSONDecodeError as exc:
        reject("K0-STRUCT-JSON", f"{path}: {exc}")
    reject_scalars(value)
    return value


def ids(items: list[dict[str, Any]], owner: str) -> set[str]:
    values = [item["id"] for item in items]
    if len(values) != len(set(values)):
        reject("K0-STRUCT-DUPLICATE-ID", owner)
    return set(values)


def title_tokens(value: str) -> tuple[str, ...]:
    """Treat Markdown punctuation as presentation, while preserving every word."""
    return tuple(re.findall(r"[A-Za-z0-9]+", value.casefold()))


def require_exact(actual: set[str], expected: set[str], owner: str) -> None:
    if actual != expected:
        reject(
            "K0-STRUCT-CLOSED-INVENTORY",
            f"{owner}: missing={sorted(expected - actual)} extra={sorted(actual - expected)}",
        )


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def main() -> int:
    raw = {
        "spec": read_once(SPEC_PATH),
        "schema": read_once(SCHEMA_PATH),
        "contract": read_once(CONTRACT_PATH),
        "v2_schema": read_once(V2_SCHEMA_PATH),
        "v2_contract": read_once(V2_CONTRACT_PATH),
    }
    schema = parse_json(raw["schema"], SCHEMA_PATH)
    contract = parse_json(raw["contract"], CONTRACT_PATH)
    Draft202012Validator.check_schema(schema)
    errors = sorted(
        Draft202012Validator(schema).iter_errors(contract),
        key=lambda error: list(error.absolute_path),
    )
    if errors:
        first = errors[0]
        reject("K0-STRUCT-SCHEMA", f"{list(first.absolute_path)}: {first.message}")

    if sha256(raw["v2_schema"]) != EXPECTED_V2["schema"]:
        reject("K0-STRUCT-V2-DRIFT", "rejected v2 schema changed")
    if sha256(raw["v2_contract"]) != EXPECTED_V2["contract"]:
        reject("K0-STRUCT-V2-DRIFT", "rejected v2 contract changed")

    try:
        spec = raw["spec"].decode("ascii")
    except UnicodeDecodeError as exc:
        reject("K0-STRUCT-SPEC-ASCII", str(exc))
    headings = re.findall(r"^## (SF-DEN-[0-9]{3}): (.+)$", spec, re.MULTILINE)
    heading_ids = [item[0] for item in headings]
    if len(heading_ids) != len(set(heading_ids)):
        reject("K0-STRUCT-CLAUSE", "duplicate Markdown clause")
    require_exact(set(heading_ids), EXPECTED_CLAUSES, "Markdown clauses")

    clauses = contract["denotation_clauses"]
    require_exact(ids(clauses, "denotation clauses"), EXPECTED_CLAUSES, "JSON clauses")
    heading_map = dict(headings)
    for clause in clauses:
        if title_tokens(heading_map[clause["id"]]) != title_tokens(clause["title"]):
            reject("K0-STRUCT-CLAUSE", f"title mismatch {clause['id']}")

    require_exact(set(contract["signature_namespaces"]), EXPECTED_NAMESPACES, "namespaces")
    require_exact(ids(contract["sort_forms"], "sorts"), EXPECTED_SORTS, "sorts")
    require_exact(ids(contract["term_judgments"], "judgments"), EXPECTED_JUDGMENTS, "judgments")
    require_exact(ids(contract["base_expression_forms"], "expressions"), EXPECTED_EXPRESSIONS, "expressions")
    require_exact(ids(contract["model_entities"], "entities"), EXPECTED_ENTITIES, "entities")
    require_exact(ids(contract["extensions"], "extensions"), EXPECTED_EXTENSIONS, "extensions")
    require_exact(ids(contract["obligation_families"], "obligations"), EXPECTED_OBLIGATIONS, "obligations")

    referenced: set[str] = set()
    for key in (
        "sort_forms",
        "term_judgments",
        "base_expression_forms",
        "model_entities",
        "extensions",
        "obligation_families",
    ):
        referenced.update(item["clause"] for item in contract[key])
    if not referenced <= EXPECTED_CLAUSES:
        reject("K0-STRUCT-CLAUSE", f"unknown references {sorted(referenced - EXPECTED_CLAUSES)}")

    if any(not item["total"] for item in contract["base_expression_forms"]):
        reject("K0-STRUCT-TOTALITY", "non-total expression entry")
    for snippet in REQUIRED_SPEC_SNIPPETS:
        if snippet not in spec:
            reject("K0-STRUCT-SPEC-ANCHOR", snippet)

    auth = contract["authorization"]
    if auth != {
        "local_K0_candidate": True,
        "external_K0_adoption": False,
        "candidate_IR": False,
        "semantic_freeze": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }:
        reject("K0-STRUCT-AUTHORIZATION", str(auth))

    output = {
        "schema_version": 1,
        "authority": "local_structural_regression_only",
        "status": "passed",
        "language_id": contract["language_id"],
        "digests": {key: sha256(value) for key, value in raw.items()},
        "byte_lengths": {key: len(value) for key, value in raw.items()},
        "counts": {
            "denotation_clauses": len(clauses),
            "sort_forms": len(contract["sort_forms"]),
            "term_judgments": len(contract["term_judgments"]),
            "base_expression_forms": len(contract["base_expression_forms"]),
            "model_entities": len(contract["model_entities"]),
            "extensions": len(contract["extensions"]),
            "obligation_families": len(contract["obligation_families"]),
        },
        "K0_G0_complete": False,
        "candidate_IR": False,
        "semantic_freeze": False,
        "TLA_translation": False,
        "model_supported": False,
        "nonclaims": [
            "Structural agreement does not validate the mathematical clauses.",
            "This checker is local and supplies no external authority.",
            "No interpreter, backend, proof, model, Linux change, or protection claim is authorized.",
        ],
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Reject as exc:
        print(json.dumps({"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail}, sort_keys=True, separators=(",", ":")))
        raise SystemExit(1)
