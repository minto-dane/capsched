#!/usr/bin/env python3
"""Show forged-acceptance documents admitted by the R11 G0 review schemas."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Callable

from jsonschema import Draft202012Validator


POLICY_ROOT = Path(__file__).resolve().parents[1] / "policy" / "r11"
REVIEW_SCHEMA_PATH = POLICY_ROOT / "g0-review-receipt-schema-v1.json"
GATE_SCHEMA_PATH = POLICY_ROOT / "g0-gate-decision-schema-v1.json"
ZERO = "0" * 64
ONE = "1" * 64
TWO = "2" * 64


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def review_document() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_id": "domainlease-r11-g0-review-receipt-hostile-v1",
        "receipt_epoch": 1,
        "status": "final",
        "review_role": "REVIEW-G0-SECURITY-SEMANTIC",
        "reviewer": {
            "principal_id": "principal-hostile",
            "authority_id": "authority-hostile",
            "credential_fingerprint": ZERO,
            "review_nonce": "hostile-review-0001",
        },
        "independence": {
            "can_modify_candidate_bundle": False,
            "can_modify_checker": False,
            "can_modify_mutation_catalog": False,
            "same_change_authority_as_candidate_author": False,
            "same_orchestrator_only": False,
            "subject_to_gate_verification": True,
        },
        "candidate_bundle": {
            "artifact_id": "domainlease-r11-g0-candidate-bundle-v1",
            "manifest_byte_length": 7073,
            "manifest_sha256": ONE,
        },
        "assigned_checks": ["CAT-G0-003"],
        "check_dispositions": [
            {
                "check_id": "CAT-G0-003",
                "verdict": "fail",
                "evidence_digest": ZERO,
                "rationale": "assigned check failed but receipt claims accept",
            },
            {
                "check_id": "CAT-G0-003",
                "verdict": "pass",
                "evidence_digest": ZERO,
                "rationale": "duplicate contradictory disposition",
            },
        ],
        "findings": [
            {
                "id": "G0-FINDING-HOSTILE-OPEN",
                "severity": "blocking",
                "status": "open",
                "statement": "blocking finding deliberately omitted from the count",
                "evidence_digest": ZERO,
            }
        ],
        "blocking_finding_count": 0,
        "verdict": "accept",
        "limitations": [],
        "attestation": {
            "method": "organizational_record",
            "signed_payload_sha256": ZERO,
            "reference": "self-asserted-reference",
            "verification_required": True,
        },
        "authorization": {
            "receipt_self_promotes": False,
            "g0_complete": False,
            "semantic_freeze": False,
            "tla_translation": False,
            "model_supported": False,
        },
    }


def artifact_ref(artifact_id: str, digest: str = ZERO) -> dict[str, Any]:
    return {"artifact_id": artifact_id, "byte_length": 1, "sha256": digest}


def review_ref() -> dict[str, Any]:
    return {
        "review_role": "REVIEW-G0-FORMAL-ENCODABILITY",
        "principal_id": "one-principal",
        "authority_id": "one-authority",
        "receipt_byte_length": 1,
        "receipt_sha256": ZERO,
    }


def gate_document() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_id": "domainlease-r11-g0-gate-decision-hostile-v1",
        "decision_epoch": 1,
        "status": "final",
        "decision": "accept",
        "gate_authority": {
            "principal_id": "candidate-controlled-gate",
            "authority_id": "candidate-controlled-authority",
            "credential_fingerprint": ZERO,
            "independent_from_candidate_change_authority": True,
        },
        "external_authority_registry": artifact_ref("self-asserted-authority-registry"),
        "candidate_bundle": artifact_ref(
            "domainlease-r11-g0-candidate-bundle-v1", TWO
        ),
        "review_set": artifact_ref("hostile-review-set"),
        "exact_mutation_result": artifact_ref("hostile-mutation-result"),
        "promotion_runtime": artifact_ref("hostile-runtime"),
        "promotion_verifier": artifact_ref("hostile-verifier"),
        "check_results": [
            {
                "check_id": "CAT-G0-001",
                "status": "failed",
                "evidence_sha256": ZERO,
            }
            for _ in range(11)
        ],
        "review_receipts": [review_ref(), review_ref(), review_ref()],
        "blocking_finding_count": 0,
        "allowed_output": {
            "r11_machine_source_construction": True,
            "semantic_freeze": False,
            "proof_complete": False,
            "tla_translation": False,
            "model_supported": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        },
        "attestation": {
            "method": "organizational_record",
            "signed_payload_sha256": ZERO,
            "reference": "self-asserted-gate-attestation",
            "verified_against_external_registry": True,
        },
    }


def schema_accepts(schema: dict[str, Any], document: dict[str, Any]) -> list[str]:
    return [
        error.message
        for error in Draft202012Validator(schema).iter_errors(document)
    ]


def main() -> int:
    review_schema_raw = REVIEW_SCHEMA_PATH.read_bytes()
    gate_schema_raw = GATE_SCHEMA_PATH.read_bytes()
    review_schema = json.loads(review_schema_raw)
    gate_schema = json.loads(gate_schema_raw)
    Draft202012Validator.check_schema(review_schema)
    Draft202012Validator.check_schema(gate_schema)

    cases: list[tuple[str, dict[str, Any], dict[str, Any]]] = [
        (
            "VAC-R11-REVIEW-ACCEPTS-FAILED-DUPLICATE-CHECK",
            review_schema,
            review_document(),
        ),
        (
            "VAC-R11-REVIEW-ACCEPTS-OPEN-BLOCKING-FINDING",
            review_schema,
            review_document(),
        ),
        (
            "VAC-R11-GATE-ACCEPTS-ELEVEN-DUPLICATE-FAILED-CHECKS",
            gate_schema,
            gate_document(),
        ),
        (
            "VAC-R11-GATE-ACCEPTS-THREE-DUPLICATE-REVIEW-ROLES",
            gate_schema,
            gate_document(),
        ),
        (
            "VAC-R11-GATE-ACCEPTS-SAME-PRINCIPAL-AND-AUTHORITY",
            gate_schema,
            gate_document(),
        ),
    ]

    results: list[dict[str, Any]] = []
    for case_id, schema, document in cases:
        errors = schema_accepts(schema, document)
        if errors:
            raise RuntimeError(f"{case_id}: schema unexpectedly rejected: {errors}")
        results.append(
            {
                "case_id": case_id,
                "schema_status": "accepted",
                "hostile_document_sha256": sha256(canonical_bytes(document)),
            }
        )

    output = {
        "schema_version": 1,
        "authority": "negative_schema_counterexample_only",
        "status": "passed",
        "accepted_counterexamples": len(results),
        "review_schema_sha256": sha256(review_schema_raw),
        "gate_schema_sha256": sha256(gate_schema_raw),
        "results": results,
        "disposition": "reject_R11_G0_review_and_gate_schema_v1",
        "g0_complete": False,
        "r11_machine_source_construction": False,
        "semantic_freeze": False,
        "tla_translation": False,
        "model_supported": False,
        "nonclaims": [
            "Schema acceptance is evidence of a missing semantic cross-check, not a valid receipt or decision.",
            "The hostile identities and attestations are synthetic and carry no authority.",
            "No external review, IR construction, TLA translation, Linux change, or protection claim is authorized.",
        ],
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
