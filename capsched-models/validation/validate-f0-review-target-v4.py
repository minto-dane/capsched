#!/usr/bin/env python3
"""Fail-closed identity and shape check for the exact local F0 v4 review target."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


MODELS = Path(__file__).resolve().parents[1]
ROOT = MODELS.parent
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v4"
MANIFEST = F0 / "f0-review-target-v4.json"
SOURCE = F0 / "f0-core-calculus-v4.md"
V3 = MODELS / "policy" / "r11" / "epoch2"
MAX_BYTES = 4 * 1024 * 1024

EXPECTED_SOURCE = {
    "path": "capsched-models/policy/r11/epoch2/foundation-v4/f0-core-calculus-v4.md",
    "sha256": "177ae3e0a860b808fd49a5bd93d03adc74d5b56f9950d1d257fa63e8fb6c7d9c",
    "bytes": 24915,
    "language_id": "DL-F0-Core-4",
}
EXPECTED_V3 = {
    "v3_spec_sha256": "9fbb5fd5c5e2d4da8246114b2eb136b8795bb3c20a44801d5947cb8cf1fe1734",
    "v3_schema_sha256": "4880f50071f4299bc0e88b9cf1072e551bd36a9a9894e17a33e8e945fa2585ae",
    "v3_contract_sha256": "d38891c32bd9449df60777f2e421c98549b01e56409d1bff92a6cef37fda93b4",
}
EXPECTED_CLAUSES = [f"F0-DEN-{index:03d}" for index in range(1, 19)]
EXPECTED_REVIEWS = {
    ("type_theory_and_metatheory", "019fe9ef-b8e2-72e0-a807-923b3e9ecdf1"),
    ("action_frame_and_security_semantics", "019fe9ef-d8d8-7990-bd03-ecc2b1aed28b"),
    ("safety_nonvacuity_scope_and_backend", "019fe9f0-041f-7141-b872-e518f5f5e576"),
    ("extension_interface_and_expressive_adequacy", "019fe9f0-244b-7a82-83c2-e59032f5cda0"),
}
EXPECTED_AUTHORIZATION = {
    "local_exact_review": True,
    "F0_local_acceptance": False,
    "F1_design": False,
    "F2_design": False,
    "F3_completion": False,
    "K0_G0_complete": False,
    "candidate_IR": False,
    "semantic_freeze": False,
    "TLA_translation": False,
    "model_supported": False,
    "linux_behavior_change": False,
    "protection_claim": False,
}
REQUIRED_SNIPPETS = (
    "LocationI = dependent sum over q",
    "LabelI = StutterLabel(One)",
    "A variable lookup preserves the",
    "F0 action bodies use `GuardPred`, `UpdateTerm`, and `EventTerm`",
    "Diff(s,s_raw) subseteq WriteSet(a,b,s,p)",
    "ClosedBranch(M,I,a,b,s,p,s',e) iff",
    "`Exec(M,I)` is the set of all such executions",
    "BaseAlways(M,I,Inv) iff",
    "Every F0 claim decision includes `InitNonempty`",
    "Scope widening requires a named proof rule",
    "PHASE-NONINTERFERENCE",
    "F2 supplies physical state/observation coverage",
    "This document is a local F0 design candidate",
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
            reject("F0-STRUCT-DUPLICATE-KEY", key)
        result[key] = value
    return result


def reject_unsafe_scalars(value: Any, path: str = "$") -> None:
    if value is None or isinstance(value, float):
        reject("F0-STRUCT-SCALAR", path)
    if isinstance(value, dict):
        for key, child in value.items():
            reject_unsafe_scalars(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_unsafe_scalars(child, f"{path}[{index}]")


def read_once(path: Path) -> bytes:
    raw = path.read_bytes()
    if not raw or len(raw) > MAX_BYTES:
        reject("F0-STRUCT-SIZE", f"{path}: {len(raw)}")
    return raw


def parse(raw: bytes, path: Path) -> Any:
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        reject("F0-STRUCT-JSON", f"{path}: {exc}")
    reject_unsafe_scalars(value)
    return value


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require_keys(value: dict[str, Any], expected: set[str], owner: str) -> None:
    actual = set(value)
    if actual != expected:
        reject(
            "F0-STRUCT-KEYS",
            f"{owner}: missing={sorted(expected-actual)} extra={sorted(actual-expected)}",
        )


def main() -> int:
    manifest_raw = read_once(MANIFEST)
    source_raw = read_once(SOURCE)
    manifest = parse(manifest_raw, MANIFEST)
    require_keys(
        manifest,
        {
            "schema_version", "artifact_id", "date", "status", "authority",
            "normative_source", "predecessor_disposition", "normative_clause_ids",
            "included_scope", "excluded_scope", "local_review_assignments",
            "authorization",
        },
        "manifest",
    )
    if manifest["schema_version"] != 1:
        reject("F0-STRUCT-IDENTITY", "schema_version")
    if manifest["artifact_id"] != "domainlease-r11-epoch2-f0-review-target-v4":
        reject("F0-STRUCT-IDENTITY", "artifact_id")
    if manifest["status"] != "local_exact_hostile_review_in_progress":
        reject("F0-STRUCT-STATUS", str(manifest["status"]))
    if manifest["authority"] != "non_normative_identity_index_only":
        reject("F0-STRUCT-AUTHORITY", str(manifest["authority"]))
    if manifest["normative_source"] != EXPECTED_SOURCE:
        reject("F0-STRUCT-SOURCE-METADATA", str(manifest["normative_source"]))
    if len(source_raw) != EXPECTED_SOURCE["bytes"] or digest(source_raw) != EXPECTED_SOURCE["sha256"]:
        reject("F0-STRUCT-SOURCE-DIGEST", digest(source_raw))

    predecessor = manifest["predecessor_disposition"]
    for key, expected in EXPECTED_V3.items():
        if predecessor.get(key) != expected:
            reject("F0-STRUCT-PREDECESSOR-METADATA", key)
    v3_raw = {
        "v3_spec_sha256": read_once(V3 / "semantic-foundation-v3.md"),
        "v3_schema_sha256": read_once(V3 / "semantic-foundation-schema-v3.json"),
        "v3_contract_sha256": read_once(V3 / "semantic-foundation-v3.json"),
    }
    for key, raw in v3_raw.items():
        if digest(raw) != EXPECTED_V3[key]:
            reject("F0-STRUCT-PREDECESSOR-DRIFT", key)
    if predecessor.get("v3_status") != "rejected":
        reject("F0-STRUCT-PREDECESSOR-STATUS", str(predecessor.get("v3_status")))

    try:
        source = source_raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F0-STRUCT-ASCII", str(exc))
    headings = re.findall(r"^## (F0-DEN-[0-9]{3}): (.+)$", source, re.MULTILINE)
    ids = [item[0] for item in headings]
    if ids != EXPECTED_CLAUSES or manifest["normative_clause_ids"] != EXPECTED_CLAUSES:
        reject("F0-STRUCT-CLAUSES", str(ids))
    if len({title for _, title in headings}) != len(headings):
        reject("F0-STRUCT-CLAUSE-TITLE", "duplicate title")
    for snippet in REQUIRED_SNIPPETS:
        if snippet not in source:
            reject("F0-STRUCT-ANCHOR", snippet)

    reviews = manifest["local_review_assignments"]
    actual_reviews = {
        (entry.get("axis"), entry.get("session_id")) for entry in reviews
        if entry.get("external_authority") is False and set(entry) == {"axis", "session_id", "external_authority"}
    }
    if len(reviews) != 4 or actual_reviews != EXPECTED_REVIEWS:
        reject("F0-STRUCT-REVIEWS", str(actual_reviews))
    if manifest["authorization"] != EXPECTED_AUTHORIZATION:
        reject("F0-STRUCT-AUTHORIZATION", str(manifest["authorization"]))

    output = {
        "schema_version": 1,
        "status": "passed",
        "authority": "local_identity_and_shape_only",
        "source_sha256": digest(source_raw),
        "source_bytes": len(source_raw),
        "manifest_sha256": digest(manifest_raw),
        "clause_count": len(ids),
        "local_review_count": len(reviews),
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "semantic_freeze": False,
        "TLA_translation": False,
        "model_supported": False,
        "nonclaims": [
            "Shape checking does not validate denotation or metatheory.",
            "Local review assignments carry no external authority.",
            "No candidate construction, backend translation, implementation, or protection claim is authorized."
        ]
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Reject as exc:
        print(json.dumps({"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail}, sort_keys=True, separators=(",", ":")))
        raise SystemExit(1)
