#!/usr/bin/env python3
"""Validate the draft R11 external policy/profile bundle without promoting it."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from jsonschema import Draft202012Validator


EXPECTED_ASSURANCE_CLAIMS = {
    "ACT-001", "EXEC-001", "ROOTSCHED-001", "RESIDENCY-001",
    "RESIDENCY-DYN-001", "BUDGET-001", "ASYNC-001", "REVOKE-001",
    "MGMT-001", "CLUSTER-001", "CLUSTER-PART-001", "COMPOSE-001",
    "EVIDENCE-001",
}
EXPECTED_POLICY_CLAIMS = {
    "POL-R11-NO-AMBIENT-EXECUTION", "POL-R11-AUTHORITY-CONSERVATION",
    "POL-R11-PROVIDER-ROOTED-ENTRY", "POL-R11-BOUNDED-CPU-USE",
    "POL-R11-REVOCATION-CUT", "POL-R11-ASYNC-PROVENANCE",
    "POL-R11-DISJOINT-PROGRESS", "POL-R11-FAILURE-CLOSURE",
    "POL-R11-TRANSFER-NONDUPLICATION", "POL-R11-SAFE-NAMESPACE-REUSE",
}
EXPECTED_ROLES = {
    "ROLE-BOOT-ROOT", "ROLE-DOMAIN-MONITOR", "ROLE-CPU-ENTRY-PROVIDER",
    "ROLE-TIME-PROVIDER", "ROLE-MEMORY-PROVIDER", "ROLE-CODE-PROVIDER",
    "ROLE-ENTRY-STATE-PROVIDER", "ROLE-DEVICE-PROVIDER", "ROLE-STOP-PROVIDER",
    "ROLE-CLUSTER-ISSUER", "ROLE-MANAGEMENT-DOMAIN", "ROLE-LINUX",
    "ROLE-TENANT-DOMAIN", "ROLE-SERVICE-DOMAIN",
}
EXPECTED_STATE_CLASSES = {
    "sealed_genesis", "monitor_authoritative", "monitor_immutable_receipt",
    "provider_authoritative", "provider_immutable_receipt", "derived_cache",
    "audit_evidence", "untrusted_proposal",
}
EXPECTED_CONSISTENCY_DOMAINS = {
    "CD-NODE-MONITOR-SHARD", "CD-CPU-INCARNATION", "CD-AUTHORITY-ACCOUNT",
    "CD-REVOCATION-SCOPE", "CD-SERVICE-STREAM", "CD-OPPORTUNITY",
    "CD-ATTEMPT", "CD-SETTLEMENT", "CD-FAILURE-SCOPE", "CD-TRANSFER",
    "CD-NAMESPACE-ROOT", "CD-CLUSTER-ISSUER",
}
EXPECTED_AUTHORITY_KINDS = {
    "AUTH-EXECUTION-GRANT", "AUTH-CPU-BUDGET-CONTEXT", "AUTH-SCHED-CONTROL",
    "AUTH-PLACEMENT", "AUTH-CHARGE", "AUTH-ASYNC-CALLER",
    "AUTH-ASYNC-SERVICE", "AUTH-ENDPOINT", "AUTH-SPAWN",
    "AUTH-THREAD-CONTROL", "AUTH-ADMISSION", "AUTH-ISSUE", "AUTH-TRANSFER",
    "AUTH-RECOVERY", "AUTH-MANAGEMENT-BOOTSTRAP",
}
EXPECTED_RESOURCE_COMPONENTS = {
    "RES-EXECUTION-USE", "RES-CPU-TIME", "RES-ROOT-CELL", "RES-ROLE-USE",
    "RES-CONTROL-WORK", "RES-CLEANUP-WORK", "RES-FAILURE-WORK",
    "RES-NAMESPACE-SLOT", "RES-PUBLICATION-WEAR", "RES-REVERSE-EDGE",
    "RES-RECEIPT-SLOT", "RES-AUDIT-ENTRY", "RES-TRANSFER-WORK",
    "RES-RETRY-USE",
}
EXPECTED_BUCKETS = {
    "available", "delegated_child", "prepared_transaction", "reserved_role_use",
    "reserved_runtime_escrow", "active_use", "retiring", "failure_escrow",
    "fenced_export", "settled_consumption", "authorized_burn",
}
EXPECTED_PROVIDERS = {
    "PC-CONTEXT-INSTALL", "PC-MEMORY-VIEW", "PC-CODE-INTEGRITY",
    "PC-ENTRY-STATE", "PC-MUTABLE-STATE", "PC-DEVICE-ISOLATION",
    "PC-STOP-ENFORCEMENT", "PC-TIME-PARTITION", "PC-PHYSICAL-ENTRY",
    "PC-PLACEMENT-FENCE",
}
EXPECTED_INVARIANTS = {
    "INV-WELL-FORMED-BOUNDED", "INV-NO-EXECUTABLE-INIT",
    "INV-EXACT-WRITER-PARTITION", "INV-IDENTITY-GENERATION-NONALIAS",
    "INV-RESOURCE-VECTOR-CONSERVATION", "INV-AUTHORITY-ATTENUATION",
    "INV-NO-AMBIENT-ACTIVATION", "INV-ASYNC-ROLE-USE-CONSERVATION",
    "INV-PUBLICATION-SEAL-BEFORE-VISIBILITY", "INV-ADMISSION-SEAL-BEFORE-USE",
    "INV-ENTRY-RECEIPT-CAUSAL-CHAIN", "INV-READY-CONSUMED-ONLY-BY-ENTERED",
    "INV-CURRENT-EXECUTABLE-COMPLETE", "INV-ONE-PHYSICAL-OWNER-PER-CPU",
    "INV-ONE-ENTERED-ATTEMPT-PER-OCCURRENCE",
    "INV-ARMED-UPPER-WITHIN-ESCROWS-HORIZONS",
    "INV-ONE-RECEIPT-ONE-SETTLEMENT-ONE-APPLY",
    "INV-REVOCATION-EFFECTIVE-AFTER-STOP",
    "INV-OFFLINE-INCARNATION-INVALIDATES-OLD-ENTRY",
    "INV-CLOSE-FAILURE-ACTIVE-USE-CUT", "INV-COMPLETED-FAILURE-EPOCH-IMMUTABLE",
    "INV-TRANSFER-SOURCE-DESTINATION-DISJOINT",
    "INV-PARTITION-TIME-CONSERVATIVE", "INV-TWO-LANE-NO-DISJOINT-WAIT",
    "INV-MANAGEMENT-BEFORE-TENANT-ADMISSION",
    "INV-NO-RECLAIM-WITH-AUTHENTICATING-REFERENCE",
    "INV-LINUX-CANNOT-WRITE-OR-MINT-AUTHORITY",
}
EXPECTED_PROGRESS = {
    "PROG-MANAGEMENT-BOOTSTRAP", "PROG-GUARANTEED-OCCURRENCE",
    "PROG-ASYNC-TERMINAL", "PROG-REVOCATION-DRAIN", "PROG-DISJOINT-LANE",
    "PROG-FAILURE-CLOSURE", "PROG-TRANSFER-TERMINAL",
    "PROG-GC-OR-QUARANTINE",
}
EXPECTED_G0_MUTATION_REJECTS = {
    "MUT-G0-UNKNOWN-FIELD": "CAT-G0-SCHEMA",
    "MUT-G0-DUPLICATE-KEY": "CAT-G0-DUPLICATE-KEY",
    "MUT-G0-SELF-AUTHORIZE": "CAT-G0-SELF-AUTHORIZATION",
    "MUT-G0-DELETE-CATALOG-ITEM": "CAT-G0-CATALOG-COVERAGE",
    "MUT-G0-REFERENCE-UNKNOWN": "CAT-G0-REFERENCE",
    "MUT-G0-LINUX-AUTHORITY": "CAT-G0-TRUST",
    "MUT-G0-PROVIDER-GENESIS": "CAT-G0-PROVIDER",
    "MUT-G0-PROFILE-COLLAPSE": "CAT-G0-PROFILE",
    "MUT-G0-PROFILE-SKIP": "CAT-G0-PROFILE-COVERAGE",
    "MUT-G0-ORACLE-FORGERY": "HM-G0-ORACLE-DIGEST",
    "MUT-G0-CHECKER-SKIP": "HM-G0-CHECK-COVERAGE",
    "MUT-G0-STALE-REVIEW": "HM-G0-REVIEW-DIGEST",
}
EXPECTED_G0_CHECKS = {
    "HM-G0-001", "HM-G0-002", "CAT-G0-001", "CAT-G0-002", "CAT-G0-003",
    "CAT-G0-004", "CAT-G0-005", "CAT-G0-006", "HM-G0-003", "HM-G0-004",
    "HM-G0-005",
}
EXPECTED_G0_REVIEW_ROLES = {
    "REVIEW-G0-SECURITY-SEMANTIC",
    "REVIEW-G0-FORMAL-ENCODABILITY",
    "REVIEW-G0-SCENARIO-SCALE",
}
EXPECTED_G0_ARTIFACT_ROLE_LAYERS = {
    "candidate_bundle": {
        "semantic_policy_schema", "semantic_policy",
        "semantic_rule_registry_schema", "semantic_rule_registry",
        "scenario_profile_schema", "scenario_profile",
        "review_contract_schema", "review_contract",
        "exact_mutation_catalog_schema", "exact_mutation_catalog",
        "assurance_claim_catalog", "mechanical_checker",
        "exact_mutation_runner", "candidate_bundle_schema",
        "candidate_bundle_verifier", "review_receipt_schema",
        "gate_decision_schema",
    },
    "review_set": {
        "external_authority_registry", "security_semantic_review_receipt",
        "formal_encodability_review_receipt", "scenario_scale_review_receipt",
    },
    "gate_decision": {
        "exact_mutation_result", "promotion_runtime_identity",
        "promotion_verifier", "gate_decision",
    },
    "evidence_capsule": {
        "candidate_bundle_manifest", "review_set_manifest",
        "gate_decision", "evidence_capsule_manifest",
    },
}
EXPECTED_G0_LAYER_PREDECESSORS = {
    "L0-CANDIDATE-BUNDLE": set(),
    "L1-EXTERNAL-REVIEW-SET": {"L0-CANDIDATE-BUNDLE"},
    "L2-INDEPENDENT-GATE-DECISION": {
        "L0-CANDIDATE-BUNDLE", "L1-EXTERNAL-REVIEW-SET",
    },
    "L3-EVIDENCE-CAPSULE": {
        "L0-CANDIDATE-BUNDLE", "L1-EXTERNAL-REVIEW-SET",
        "L2-INDEPENDENT-GATE-DECISION",
    },
}
EXPECTED_G0_REVIEW_ASSIGNMENTS = {
    "REVIEW-G0-SECURITY-SEMANTIC": {
        "CAT-G0-002", "CAT-G0-004", "CAT-G0-005", "CAT-G0-006",
    },
    "REVIEW-G0-FORMAL-ENCODABILITY": {
        "CAT-G0-001", "CAT-G0-002", "CAT-G0-005", "CAT-G0-006",
    },
    "REVIEW-G0-SCENARIO-SCALE": {
        "CAT-G0-003", "CAT-G0-005", "CAT-G0-006",
    },
}


class Reject(Exception):
    def __init__(self, reject_id: str, detail: str):
        super().__init__(detail)
        self.reject_id = reject_id
        self.detail = detail


class DuplicateKey(ValueError):
    pass


def reject(reject_id: str, detail: str) -> None:
    raise Reject(reject_id, detail)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKey(key)
        result[key] = value
    return result


def load_json(path: Path) -> tuple[bytes, Any]:
    raw = path.read_bytes()
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=strict_object)
    except DuplicateKey as exc:
        reject("CAT-G0-DUPLICATE-KEY", f"{path}: duplicate key {exc}")
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        reject("CAT-G0-SCHEMA", f"{path}: malformed UTF-8 JSON: {exc}")
    return raw, value


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def validate_schema(schema: Any, value: Any, label: str) -> None:
    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:  # jsonschema exposes several schema subclasses.
        reject("CAT-G0-SCHEMA", f"{label} schema invalid: {exc}")
    errors = sorted(
        Draft202012Validator(schema).iter_errors(value),
        key=lambda error: [str(part) for part in error.absolute_path],
    )
    if errors:
        error = errors[0]
        pointer = "/" + "/".join(str(part) for part in error.absolute_path)
        reject("CAT-G0-SCHEMA", f"{label}{pointer}: {error.message}")


def ids(rows: Iterable[dict[str, Any]], label: str) -> set[str]:
    values = [row["id"] for row in rows]
    if len(values) != len(set(values)):
        duplicates = sorted(key for key, count in Counter(values).items() if count > 1)
        reject("CAT-G0-CATALOG-COVERAGE", f"duplicate {label} IDs: {duplicates}")
    return set(values)


def exact_set(actual: Iterable[str], expected: Iterable[str], reject_id: str, label: str) -> None:
    actual_set = set(actual)
    expected_set = set(expected)
    if actual_set != expected_set:
        reject(
            reject_id,
            f"{label}: missing={sorted(expected_set - actual_set)} "
            f"extra={sorted(actual_set - expected_set)}",
        )


def references_subset(actual: Iterable[str], allowed: set[str], reject_id: str, label: str) -> None:
    unknown = set(actual) - allowed
    if unknown:
        reject(reject_id, f"{label}: unknown references {sorted(unknown)}")


def pointer_get(document: Any, pointer: str) -> Any:
    current = document
    for raw_part in pointer.split("/")[1:]:
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict) and part in current:
            current = current[part]
        elif isinstance(current, list) and part.isdigit() and int(part) < len(current):
            current = current[int(part)]
        else:
            reject("CAT-G0-REFERENCE", f"unresolved policy pointer {pointer}")
    return current


def require_false_authorization(document: dict[str, Any], label: str) -> None:
    true_keys = sorted(key for key, value in document["authorization"].items() if value is not False)
    if true_keys:
        reject("CAT-G0-SELF-AUTHORIZATION", f"{label} self-authorizes {true_keys}")


def check_no_pending(value: Any, pointer: str = "") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            check_no_pending(child, f"{pointer}/{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            check_no_pending(child, f"{pointer}/{index}")
    elif isinstance(value, str) and value.startswith("PENDING-"):
        reject("CAT-G0-CATALOG-COVERAGE", f"pending marker at {pointer}: {value}")


def check_dag(rows: list[dict[str, Any]]) -> None:
    row_ids = ids(rows, "semantic DAG")
    expected = {f"D{index}" for index in range(18)}
    exact_set(row_ids, expected, "CAT-G0-CATALOG-COVERAGE", "semantic DAG")
    predecessors = {row["id"]: set(row["predecessors"]) for row in rows}
    for node, deps in predecessors.items():
        references_subset(deps, row_ids, "CAT-G0-REFERENCE", f"{node} predecessors")
        if node in deps:
            reject("CAT-G0-CATALOG-COVERAGE", f"{node} is its own predecessor")
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str) -> None:
        if node in visiting:
            reject("CAT-G0-CATALOG-COVERAGE", f"semantic DAG cycle through {node}")
        if node in visited:
            return
        visiting.add(node)
        for predecessor in predecessors[node]:
            visit(predecessor)
        visiting.remove(node)
        visited.add(node)

    for node in sorted(row_ids):
        visit(node)


def check_policy(policy: dict[str, Any], claims: dict[str, Any]) -> dict[str, set[str]]:
    require_false_authorization(policy, "policy")
    check_no_pending(policy)

    claim_ids = ids(claims["claims"], "assurance claim")
    exact_set(
        policy["claim_boundary"]["assurance_claims"],
        EXPECTED_ASSURANCE_CLAIMS,
        "CAT-G0-CLAIM-CATALOG",
        "assurance claim boundary",
    )
    exact_set(
        policy["claim_boundary"]["policy_claims"],
        EXPECTED_POLICY_CLAIMS,
        "CAT-G0-CLAIM-CATALOG",
        "policy claim boundary",
    )
    references_subset(
        policy["claim_boundary"]["assurance_claims"],
        claim_ids,
        "CAT-G0-CLAIM-CATALOG",
        "policy assurance claims",
    )

    role_ids = ids(policy["trust_roles"], "trust role")
    state_ids = ids(policy["state_classes"], "state class")
    exact_set(role_ids, EXPECTED_ROLES, "CAT-G0-CATALOG-COVERAGE", "trust roles")
    exact_set(state_ids, EXPECTED_STATE_CLASSES, "CAT-G0-CATALOG-COVERAGE", "state classes")
    role_map = {row["id"]: row for row in policy["trust_roles"]}
    state_map = {row["id"]: row for row in policy["state_classes"]}
    for role in policy["trust_roles"]:
        references_subset(
            role["may_write_state_classes"],
            state_ids,
            "CAT-G0-REFERENCE",
            f"{role['id']} state classes",
        )
        for state in role["may_write_state_classes"]:
            if role["id"] not in state_map[state]["allowed_writer_roles"]:
                reject("CAT-G0-TRUST", f"writer matrix is asymmetric for {role['id']} and {state}")
    for state in policy["state_classes"]:
        references_subset(
            state["allowed_writer_roles"],
            role_ids,
            "CAT-G0-REFERENCE",
            f"{state['id']} writer roles",
        )
        for role in state["allowed_writer_roles"]:
            if state["id"] not in role_map[role]["may_write_state_classes"]:
                reject("CAT-G0-TRUST", f"writer matrix is asymmetric for {state['id']} and {role}")

    untrusted_roles = {
        "ROLE-LINUX",
        "ROLE-MANAGEMENT-DOMAIN",
        "ROLE-TENANT-DOMAIN",
        "ROLE-SERVICE-DOMAIN",
    }
    for state in policy["state_classes"]:
        if state["authoritative"] and set(state["allowed_writer_roles"]) & untrusted_roles:
            reject("CAT-G0-TRUST", f"untrusted authoritative writer in {state['id']}")
    executable_roles = [row["id"] for row in policy["trust_roles"] if row["may_make_current_executable"]]
    if executable_roles != ["ROLE-CPU-ENTRY-PROVIDER"]:
        reject("CAT-G0-ENTRY-ROOT", f"CurrentExecutable writers are {executable_roles}")
    if policy["physical_entry_policy"]["current_executable_writer"] != executable_roles[0]:
        reject("CAT-G0-ENTRY-ROOT", "physical entry writer does not match trust role")
    if policy["physical_entry_policy"]["continuation_token_input_to_initial_entry"]:
        reject("CAT-G0-ENTRY-ROOT", "initial entry cyclically consumes a continuation token")

    authority_ids = ids(policy["authority_kinds"], "authority kind")
    ids(policy["authority_separation_rules"], "authority separation rule")
    consistency_ids = ids(policy["consistency_domains"], "consistency domain")
    exact_set(authority_ids, EXPECTED_AUTHORITY_KINDS, "CAT-G0-CATALOG-COVERAGE", "authority kinds")
    exact_set(consistency_ids, EXPECTED_CONSISTENCY_DOMAINS, "CAT-G0-CATALOG-COVERAGE", "consistency domains")
    component_ids = ids(policy["resource_algebra"]["components"], "resource component")
    exact_set(component_ids, EXPECTED_RESOURCE_COMPONENTS, "CAT-G0-RESOURCE-ALGEBRA", "resource components")
    buckets = policy["resource_algebra"]["disjoint_buckets"]
    exact_set(buckets, EXPECTED_BUCKETS, "CAT-G0-RESOURCE-ALGEBRA", "resource buckets")
    exact_set(
        policy["resource_algebra"]["conservation_equation"]["right"],
        buckets,
        "CAT-G0-RESOURCE-ALGEBRA",
        "conservation right-hand buckets",
    )
    if policy["transaction_policy"]["cross_domain_protocol"]["in_transit_bucket"] != "fenced_export":
        reject("CAT-G0-RESOURCE-ALGEBRA", "cross-CD protocol is outside conservation")
    if policy["transaction_policy"]["cross_domain_protocol"]["remote_atomic_write"]:
        reject("CAT-G0-PARTITION", "cross-CD remote atomic write is enabled")
    if policy["settlement_policy"]["cross_domain_atomic_apply"]:
        reject("CAT-G0-PARTITION", "cross-CD settlement is atomic")

    check_dag(policy["semantic_dag"])
    invariant_ids = ids(policy["invariant_obligations"], "invariant obligation")
    progress_ids = ids(policy["progress_obligations"], "progress obligation")
    exact_set(invariant_ids, EXPECTED_INVARIANTS, "CAT-G0-CATALOG-COVERAGE", "invariant obligations")
    exact_set(progress_ids, EXPECTED_PROGRESS, "CAT-G0-CATALOG-COVERAGE", "progress obligations")
    expected_witnesses = {f"W{index}" for index in range(13)}
    for row in policy["invariant_obligations"] + policy["progress_obligations"]:
        references_subset(
            row["witnesses"],
            expected_witnesses,
            "CAT-G0-REFERENCE",
            f"{row['id']} witnesses",
        )

    provider_ids = ids(policy["provider_contracts"], "provider contract")
    exact_set(provider_ids, EXPECTED_PROVIDERS, "CAT-G0-CATALOG-COVERAGE", "provider contracts")
    provider_receipts = [row["success_receipt"] for row in policy["provider_contracts"]]
    if len(provider_receipts) != len(set(provider_receipts)):
        reject("CAT-G0-PROVIDER", "provider success receipts are not unique")
    for provider in policy["provider_contracts"]:
        if provider["writer_role"] not in role_ids:
            reject("CAT-G0-REFERENCE", f"unknown writer for {provider['id']}")
        receipt_class = provider["receipt_state_class"]
        if receipt_class not in state_ids:
            reject("CAT-G0-REFERENCE", f"unknown receipt state class for {provider['id']}")
        if provider["writer_role"] not in state_map[receipt_class]["allowed_writer_roles"]:
            reject("CAT-G0-TRUST", f"{provider['writer_role']} cannot write {provider['id']} receipt class")
        if provider["receipt_initial"] != "Vacant" or not provider["write_once"]:
            reject("CAT-G0-PROVIDER", f"runtime receipt is precreated or mutable: {provider['id']}")
        references_subset(
            provider["consumer_obligations"],
            invariant_ids,
            "CAT-G0-REFERENCE",
            f"{provider['id']} consumers",
        )
        for field in ("trigger", "prestate", "success_relation", "fault_partition", "failure_successor", "bound_class", "fairness_class"):
            if not provider[field] or str(provider[field]).lower() in {"true", "always_true", "none"}:
                reject("CAT-G0-PROVIDER", f"vacuous {provider['id']} {field}")

    mutation = policy["mutation_oracle"]
    g0_mutation_ids = ids(mutation["g0_policy_profile_templates"], "G0 mutation template")
    ir_mutation_ids = ids(mutation["future_ir_mutation_templates"], "IR mutation template")
    if mutation["exact_g0_campaign_materialized"] or mutation["future_ir_campaign_materialized"]:
        reject("CAT-G0-SELF-AUTHORIZATION", "draft policy claims a materialized mutation campaign")
    exact_set(
        g0_mutation_ids,
        EXPECTED_G0_MUTATION_REJECTS,
        "CAT-G0-CATALOG-COVERAGE",
        "G0 mutation template IDs",
    )
    for row in mutation["g0_policy_profile_templates"]:
        if not row["expected_reject"].startswith(("CAT-", "HM-")):
            reject("CAT-G0-CATALOG-COVERAGE", f"bad G0 reject namespace in {row['id']}")
        if row["expected_reject"] != EXPECTED_G0_MUTATION_REJECTS[row["id"]]:
            reject("HM-G0-ORACLE-DIGEST", f"forged expected reject for {row['id']}")
    for row in mutation["future_ir_mutation_templates"]:
        if not row["expected_reject"].startswith("CAT-"):
            reject("CAT-G0-CATALOG-COVERAGE", f"bad IR template reject namespace in {row['id']}")

    return {
        "claims": claim_ids | set(policy["claim_boundary"]["policy_claims"]),
        "roles": role_ids,
        "invariants": invariant_ids,
        "progress": progress_ids,
        "providers": provider_ids,
        "g0_mutations": g0_mutation_ids,
        "ir_mutations": ir_mutation_ids,
        "witnesses": expected_witnesses,
        "dag": {row["id"] for row in policy["semantic_dag"]},
    }


def check_registry(registry: dict[str, Any], policy: dict[str, Any], catalog: dict[str, set[str]]) -> None:
    require_false_authorization(registry, "semantic rule registry")
    check_no_pending(registry)
    rule_ids = ids(registry["rules"], "semantic rule")
    templates = [row["canonical_template"] for row in registry["rules"]]
    if len(templates) != len(set(templates)):
        reject("CAT-G0-CATALOG-COVERAGE", "canonical semantic templates are duplicated")
    bindings = [row["candidate_binding_schema"] for row in registry["rules"]]
    if len(bindings) != len(set(bindings)):
        reject("CAT-G0-CATALOG-COVERAGE", "candidate binding schema IDs are duplicated")
    expected_rules: set[str] = set()
    for family, count in registry["family_counts"].items():
        expected_rules |= {f"{family}-{index:03d}" for index in range(1, count + 1)}
    exact_set(rule_ids, expected_rules, "CAT-G0-CATALOG-COVERAGE", "semantic rule sequence")
    for row in registry["rules"]:
        for pointer in row["policy_pointers"]:
            pointer_get(policy, pointer)
        references_subset(
            row["generated_obligation_ids"],
            catalog["invariants"] | catalog["progress"],
            "CAT-G0-REFERENCE",
            f"{row['id']} obligations",
        )
        references_subset(
            row["required_witnesses"],
            catalog["witnesses"],
            "CAT-G0-REFERENCE",
            f"{row['id']} witnesses",
        )
        references_subset(
            row["required_mutation_ids"],
            catalog["ir_mutations"],
            "CAT-G0-REFERENCE",
            f"{row['id']} mutations",
        )
        references_subset(
            row["claim_ids"],
            catalog["claims"],
            "CAT-G0-CLAIM-CATALOG",
            f"{row['id']} claims",
        )


def require_minimum(profile: dict[str, Any], **minimums: int) -> None:
    for key, minimum in minimums.items():
        actual = profile["dimensions"][key]
        if actual < minimum:
            reject("CAT-G0-PROFILE", f"{profile['id']} {key}={actual}, need >= {minimum}")


def check_profile(profile: dict[str, Any], catalog: dict[str, set[str]]) -> None:
    require_false_authorization(profile, "scenario profile")
    check_no_pending(profile)
    profiles = profile["profiles"]
    profile_ids = ids(profiles, "scenario profile")
    if len(profile_ids) != 19:
        reject("CAT-G0-PROFILE-COVERAGE", f"expected 19 fixed profiles, got {len(profile_ids)}")
    by_id = {row["id"]: row for row in profiles}

    relation_ids = ids(profile["relation_catalog"], "scenario relation")
    cut_ids = set(profile["cutpoint_catalog"])
    outcome_ids = set(profile["outcome_catalog"])
    action_ids = set(profile["action_class_catalog"])
    ids(profile["anti_vacuity_rules"], "anti-vacuity rule")
    ids(profile["forbidden_profile_weakening"], "profile weakening")

    mode_rows = profile["profile_mode_contract"]
    mode_profiles = [row["profile"] for row in mode_rows]
    if len(mode_profiles) != len(set(mode_profiles)):
        reject("CAT-G0-PROFILE-COVERAGE", "duplicate profile mode assignment")
    exact_set(mode_profiles, profile_ids, "CAT-G0-PROFILE-COVERAGE", "profile mode assignments")
    mode_by_profile = {row["profile"]: row for row in mode_rows}
    for key, allowed in profile["mode_catalog"].items():
        for row in mode_rows:
            if row[key] not in allowed:
                reject("CAT-G0-PROFILE", f"{row['profile']} has unknown {key} {row[key]}")

    action_rows = profile["profile_action_contract"]
    action_profiles = [row["profile"] for row in action_rows]
    if len(action_profiles) != len(set(action_profiles)):
        reject("CAT-G0-PROFILE-COVERAGE", "duplicate profile action assignment")
    exact_set(action_profiles, profile_ids, "CAT-G0-PROFILE-COVERAGE", "profile action assignments")
    used_actions: set[str] = set()
    for row in action_rows:
        references_subset(row["actions"], action_ids, "CAT-G0-REFERENCE", f"{row['profile']} actions")
        used_actions.update(row["actions"])
    exact_set(used_actions, action_ids, "CAT-G0-PROFILE-COVERAGE", "action class coverage")

    witnesses: set[str] = set()
    dag: set[str] = set()
    relations: set[str] = set()
    cuts: set[str] = set()
    outcomes: set[str] = set()
    for row in profiles:
        witnesses.add(row["witness"])
        dag.update(row["dag_nodes"])
        relations.update(row["relations"])
        cuts.update(row["cutpoints"])
        outcomes.update(row["outcomes"])
        references_subset(row["dag_nodes"], catalog["dag"], "CAT-G0-REFERENCE", f"{row['id']} DAG")
        references_subset(row["relations"], relation_ids, "CAT-G0-REFERENCE", f"{row['id']} relations")
        references_subset(row["cutpoints"], cut_ids, "CAT-G0-REFERENCE", f"{row['id']} cuts")
        references_subset(row["outcomes"], outcome_ids, "CAT-G0-REFERENCE", f"{row['id']} outcomes")

    coverage = profile["suite_coverage"]
    exact_set(coverage["required_witnesses"], catalog["witnesses"], "CAT-G0-PROFILE-COVERAGE", "required witnesses")
    exact_set(coverage["required_dag_nodes"], catalog["dag"], "CAT-G0-PROFILE-COVERAGE", "required DAG")
    exact_set(coverage["required_relations"], relation_ids, "CAT-G0-PROFILE-COVERAGE", "required relations")
    exact_set(coverage["required_cutpoints"], cut_ids, "CAT-G0-PROFILE-COVERAGE", "required cuts")
    exact_set(coverage["required_outcomes"], outcome_ids, "CAT-G0-PROFILE-COVERAGE", "required outcomes")
    exact_set(witnesses, coverage["required_witnesses"], "CAT-G0-PROFILE-COVERAGE", "witness union")
    exact_set(dag, coverage["required_dag_nodes"], "CAT-G0-PROFILE-COVERAGE", "DAG union")
    exact_set(relations, coverage["required_relations"], "CAT-G0-PROFILE-COVERAGE", "relation union")
    exact_set(cuts, coverage["required_cutpoints"], "CAT-G0-PROFILE-COVERAGE", "cut union")
    exact_set(outcomes, coverage["required_outcomes"], "CAT-G0-PROFILE-COVERAGE", "outcome union")

    required_profiles = {
        "PROFILE-W0-BOOTSTRAP",
        "PROFILE-W1-AUTHORITY-TXN",
        "PROFILE-W2-ASYNC-DISTINCT",
        "PROFILE-W3-ASYNC-ALIASED",
        "PROFILE-W4-FULL-ENTRY",
        "PROFILE-W5-CANCEL-RACES",
        "PROFILE-W6-RETRY-RECURRENCE",
        "PROFILE-W7-RUNTIME-SETTLEMENT",
        "PROFILE-W8-REVOKE-OFFLINE",
        "PROFILE-W9-TWO-LANE",
        "PROFILE-W10-FAILURE-CLOSURE",
        "PROFILE-W11-TRANSFER-STRONG",
        "PROFILE-W11-TRANSFER-SAFE-GAP",
        "PROFILE-W11-TRANSFER-CONTINUITY-LOSS",
        "PROFILE-W12-PARTITION-CONNECTED-ONLY",
        "PROFILE-W12-PARTITION-CONSERVATIVE-EXPIRY",
        "PROFILE-W12-PARTITION-RECOVERY-ONLY",
        "PROFILE-W12-RECLAIM-NAMESPACE",
        "PROFILE-W12-RECLAIM-RESTART",
    }
    exact_set(profile_ids, required_profiles, "CAT-G0-PROFILE-COVERAGE", "fixed profile inventory")

    require_minimum(by_id["PROFILE-W0-BOOTSTRAP"], management_domains=1, tenant_domains=1, cpus=1, provider_receipt_sets=2)
    require_minimum(by_id["PROFILE-W1-AUTHORITY-TXN"], authority_accounts=2, transaction_slots=2, resource_value_levels=3)
    require_minimum(by_id["PROFILE-W2-ASYNC-DISTINCT"], authority_accounts=2, role_use_ordinals_per_authority=2, service_domains=1)
    require_minimum(by_id["PROFILE-W3-ASYNC-ALIASED"], authority_accounts=1, role_use_ordinals_per_authority=2, resource_value_levels=3)
    require_minimum(by_id["PROFILE-W4-FULL-ENTRY"], opportunities=1, attempts_per_occurrence=1, ready_cells=1, root_slots=1, provider_receipt_sets=2)
    require_minimum(by_id["PROFILE-W5-CANCEL-RACES"], attempts_per_occurrence=2, root_slots=2)
    require_minimum(by_id["PROFILE-W6-RETRY-RECURRENCE"], attempts_per_occurrence=2, occurrences_per_stream=2, generation_values=3)
    require_minimum(by_id["PROFILE-W7-RUNTIME-SETTLEMENT"], quantum_generations=2, resource_value_levels=4, transaction_slots=2)
    require_minimum(by_id["PROFILE-W8-REVOKE-OFFLINE"], cpus=2, cpu_incarnations_per_cpu=2, revocation_scopes=2)
    require_minimum(by_id["PROFILE-W9-TWO-LANE"], cpus=2, tenant_domains=2, streams=2, root_slots=2)
    require_minimum(by_id["PROFILE-W10-FAILURE-CLOSURE"], failure_events=3, failure_scopes=4, dependency_edges=5)

    if mode_by_profile["PROFILE-W2-ASYNC-DISTINCT"]["async_mode"] != "DISTINCT":
        reject("CAT-G0-PROFILE", "distinct async profile does not fix DISTINCT mode")
    if mode_by_profile["PROFILE-W3-ASYNC-ALIASED"]["async_mode"] != "ALIASED":
        reject("CAT-G0-PROFILE", "aliased async profile does not fix ALIASED mode")
    if "REL-CALLER-SERVICE-DISTINCT" not in by_id["PROFILE-W2-ASYNC-DISTINCT"]["relations"]:
        reject("CAT-G0-PROFILE", "distinct async equality constraint missing")
    if "REL-CALLER-SERVICE-ALIASED" not in by_id["PROFILE-W3-ASYNC-ALIASED"]["relations"]:
        reject("CAT-G0-PROFILE", "aliased async equality constraint missing")

    transfer_modes = {
        mode_by_profile["PROFILE-W11-TRANSFER-STRONG"]["transfer_mode"],
        mode_by_profile["PROFILE-W11-TRANSFER-SAFE-GAP"]["transfer_mode"],
        mode_by_profile["PROFILE-W11-TRANSFER-CONTINUITY-LOSS"]["transfer_mode"],
    }
    exact_set(transfer_modes, {"STRONG_CONTINUITY", "SAFE_GAP", "CONTINUITY_LOST"}, "CAT-G0-PROFILE", "transfer modes")
    for profile_id in (
        "PROFILE-W11-TRANSFER-STRONG",
        "PROFILE-W11-TRANSFER-SAFE-GAP",
        "PROFILE-W11-TRANSFER-CONTINUITY-LOSS",
    ):
        require_minimum(by_id[profile_id], nodes=2, clock_domains=2, transfer_records=3, occurrences_per_stream=3)
        needed = {"REL-SOURCE-DESTINATION-DISTINCT", "REL-CLOCK-UNCERTAINTY-POSITIVE", "REL-NETWORK-SILENCE-NOT-FENCE"}
        references_subset(needed, set(by_id[profile_id]["relations"]), "CAT-G0-PROFILE", f"{profile_id} relations")

    partition_profiles = {
        "CONNECTED_ONLY": "PROFILE-W12-PARTITION-CONNECTED-ONLY",
        "CONTINUE_TO_CONSERVATIVE_EXPIRY": "PROFILE-W12-PARTITION-CONSERVATIVE-EXPIRY",
        "RECOVERY_ONLY": "PROFILE-W12-PARTITION-RECOVERY-ONLY",
    }
    for mode, profile_id in partition_profiles.items():
        if mode_by_profile[profile_id]["partition_mode"] != mode:
            reject("CAT-G0-PROFILE", f"{profile_id} does not fix {mode}")
        require_minimum(by_id[profile_id], clusters=2, nodes=2, clock_domains=2, clock_ticks=3, network_messages=4, authority_accounts=2)
        if "REL-CLUSTER-A-B-DISTINCT" not in by_id[profile_id]["relations"]:
            reject("CAT-G0-PROFILE", f"{profile_id} collapses cluster identities")

    namespace = by_id["PROFILE-W12-RECLAIM-NAMESPACE"]
    restart = by_id["PROFILE-W12-RECLAIM-RESTART"]
    if namespace["dimensions"]["allocation_requests"] <= namespace["dimensions"]["namespace_slots"]:
        reject("CAT-G0-PROFILE", "namespace exhaustion profile does not exhaust")
    if restart["dimensions"]["allocation_requests"] <= restart["dimensions"]["namespace_slots"]:
        reject("CAT-G0-PROFILE", "restart profile does not retain exhaustion")
    require_minimum(restart, boot_roots=2, cpu_incarnations_per_cpu=2, generation_values=3)
    for row in (namespace, restart):
        needed = {"REL-NAMESPACE-EXHAUSTION", "REL-NAMESPACE-ROOTS-DISTINCT"}
        references_subset(needed, set(row["relations"]), "CAT-G0-PROFILE", f"{row['id']} relations")

    offline_cuts = {
        "CUT-PRE-CONTEXT",
        "CUT-AFTER-CONTEXT-BEFORE-ELIGIBILITY",
        "CUT-AFTER-ELIGIBILITY-BEFORE-ROOT-CLAIM",
        "CUT-AFTER-ROOT-CLAIM-BEFORE-ENTRY-PREPARE",
        "CUT-AFTER-ENTRY-PREPARE-BEFORE-COMMIT",
        "CUT-ENTERED-PRE-BOUNDARY",
        "CUT-BOUNDARY-OR-IDLE-PRE-SETTLEMENT",
    }
    references_subset(
        offline_cuts,
        set(by_id["PROFILE-W8-REVOKE-OFFLINE"]["cutpoints"]),
        "CAT-G0-PROFILE-COVERAGE",
        "offline/revoke physical-entry cuts",
    )


def check_review_contract(contract: dict[str, Any]) -> None:
    require_false_authorization(contract, "G0 review contract")
    check_no_pending(contract)
    exact_set(ids(contract["checks"], "G0 check"), EXPECTED_G0_CHECKS, "CAT-G0-CATALOG-COVERAGE", "G0 checks")
    exact_set(ids(contract["review_roles"], "G0 review role"), EXPECTED_G0_REVIEW_ROLES, "CAT-G0-CATALOG-COVERAGE", "G0 review roles")
    exact_set(
        contract["artifact_role_layers"],
        EXPECTED_G0_ARTIFACT_ROLE_LAYERS,
        "CAT-G0-CATALOG-COVERAGE",
        "G0 artifact role layers",
    )
    for layer, expected_roles in EXPECTED_G0_ARTIFACT_ROLE_LAYERS.items():
        exact_set(
            contract["artifact_role_layers"][layer],
            expected_roles,
            "CAT-G0-CATALOG-COVERAGE",
            f"{layer} artifact roles",
        )

    layer_rows = contract["evidence_layer_dag"]
    layer_ids = ids(layer_rows, "G0 evidence layer")
    exact_set(
        layer_ids,
        EXPECTED_G0_LAYER_PREDECESSORS,
        "CAT-G0-CATALOG-COVERAGE",
        "G0 evidence layers",
    )
    output_digests = [row["output_digest"] for row in layer_rows]
    if len(output_digests) != len(set(output_digests)):
        reject("CAT-G0-CATALOG-COVERAGE", "G0 evidence layer outputs are duplicated")
    for row in layer_rows:
        exact_set(
            row["predecessors"],
            EXPECTED_G0_LAYER_PREDECESSORS[row["id"]],
            "CAT-G0-CATALOG-COVERAGE",
            f"{row['id']} predecessors",
        )
        if row["id"] in row["predecessors"]:
            reject("CAT-G0-CATALOG-COVERAGE", f"{row['id']} self-references")

    assigned_union: set[str] = set()
    for row in contract["review_roles"]:
        exact_set(
            row["assigned_checks"],
            EXPECTED_G0_REVIEW_ASSIGNMENTS[row["id"]],
            "CAT-G0-CATALOG-COVERAGE",
            f"{row['id']} assigned checks",
        )
        assigned_union.update(row["assigned_checks"])
    exact_set(
        assigned_union,
        {f"CAT-G0-{index:03d}" for index in range(1, 7)},
        "CAT-G0-CATALOG-COVERAGE",
        "review-assigned catalog checks",
    )
    disposition = contract["current_disposition"]
    if disposition["g0_complete"] or disposition["external_gate_decision"]:
        reject("CAT-G0-SELF-AUTHORIZATION", "draft G0 contract claims an external decision")
    if disposition["external_review_receipts"] != 0:
        reject("HM-G0-REVIEW-DIGEST", "unbound external review receipt count is nonzero")
    allowed = contract["allowed_gate_output"]
    if not allowed["r11_machine_source_construction"]:
        reject("CAT-G0-CATALOG-COVERAGE", "G0 would authorize no next step")
    forbidden_true = sorted(
        key for key, value in allowed.items()
        if key != "r11_machine_source_construction" and value is not False
    )
    if forbidden_true:
        reject("CAT-G0-SELF-AUTHORIZATION", f"G0 over-authorizes {forbidden_true}")


def parse_args() -> argparse.Namespace:
    model_root = Path(__file__).resolve().parents[1]
    policy_root = model_root / "policy" / "r11"
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy-schema", type=Path, default=policy_root / "semantic-policy-schema-v1.json")
    parser.add_argument("--policy", type=Path, default=policy_root / "semantic-policy-v1.json")
    parser.add_argument("--registry-schema", type=Path, default=policy_root / "semantic-rule-registry-schema-v1.json")
    parser.add_argument("--registry", type=Path, default=policy_root / "semantic-rule-registry-v1.json")
    parser.add_argument("--profile-schema", type=Path, default=policy_root / "scenario-profile-schema-v1.json")
    parser.add_argument("--profile", type=Path, default=policy_root / "scenario-profile-v1.json")
    parser.add_argument("--review-contract-schema", type=Path, default=policy_root / "g0-review-contract-schema-v1.json")
    parser.add_argument("--review-contract", type=Path, default=policy_root / "g0-review-contract-v1.json")
    parser.add_argument("--claims", type=Path, default=model_root / "assurance" / "claims.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paths = {
        "policy_schema": args.policy_schema,
        "policy": args.policy,
        "registry_schema": args.registry_schema,
        "registry": args.registry,
        "profile_schema": args.profile_schema,
        "profile": args.profile,
        "review_contract_schema": args.review_contract_schema,
        "review_contract": args.review_contract,
        "claims": args.claims,
    }
    try:
        loaded = {name: load_json(path) for name, path in paths.items()}
        policy_schema = loaded["policy_schema"][1]
        policy = loaded["policy"][1]
        registry_schema = loaded["registry_schema"][1]
        registry = loaded["registry"][1]
        profile_schema = loaded["profile_schema"][1]
        profile = loaded["profile"][1]
        review_contract_schema = loaded["review_contract_schema"][1]
        review_contract = loaded["review_contract"][1]
        claims = loaded["claims"][1]

        validate_schema(policy_schema, policy, "policy")
        validate_schema(registry_schema, registry, "registry")
        validate_schema(profile_schema, profile, "profile")
        validate_schema(review_contract_schema, review_contract, "review contract")
        catalog = check_policy(policy, claims)
        check_registry(registry, policy, catalog)
        check_profile(profile, catalog)
        check_review_contract(review_contract)
    except Reject as exc:
        print(json.dumps({"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail}, sort_keys=True))
        return 1

    result = {
        "schema_version": 1,
        "authority": "development_mechanical_consistency_only",
        "status": "passed",
        "g0_complete": False,
        "r11_machine_ir_authorized": False,
        "semantic_freeze": False,
        "tla_translation": False,
        "input_sha256": {name: sha256(raw) for name, (raw, _) in loaded.items()},
        "counts": {
            "semantic_rules": len(registry["rules"]),
            "invariants": len(policy["invariant_obligations"]),
            "progress_obligations": len(policy["progress_obligations"]),
            "provider_contracts": len(policy["provider_contracts"]),
            "profiles": len(profile["profiles"]),
            "g0_checks": len(review_contract["checks"]),
            "g0_review_roles": len(review_contract["review_roles"]),
            "witness_ids": len(profile["suite_coverage"]["required_witnesses"]),
            "anti_vacuity_rules": len(profile["anti_vacuity_rules"]),
            "future_ir_mutation_templates": len(policy["mutation_oracle"]["future_ir_mutation_templates"]),
            "g0_mutation_templates": len(policy["mutation_oracle"]["g0_policy_profile_templates"]),
        },
        "runtime": {
            "python": sys.version.split()[0],
            "jsonschema": importlib.metadata.version("jsonschema"),
        },
        "nonclaims": [
            "No independent external review or decision was performed.",
            "No exact G0 mutation campaign was executed.",
            "No R11 candidate IR, witness execution, proof, TLA translation, or protection claim is authorized."
        ],
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
