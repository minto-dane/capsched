#!/usr/bin/env python3
"""Validate and deterministically materialize the R10 semantic IR."""

from __future__ import annotations

import argparse
import copy
import hashlib
import itertools
import json
import os
import sys
import tempfile
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, Iterable

import jsonschema


HERE = Path(__file__).resolve().parent
SCHEMA_PATH = HERE / "r10-schema.json"
SOURCE_PATH = HERE / "r10-source.json"
EXPANDED_PATH = HERE / "r10-expanded.json"
LOCK_PATH = HERE / "r10-lock.json"
GENERATED_MD_PATH = HERE / "r10-generated.md"
HOSTILE_TEST_PATH = HERE / "test-r10-hostile.py"
HOSTILE_RESULTS_PATH = HERE / "r10-hostile-results.json"
DISPOSITION_PATH = (
    HERE.parent.parent
    / "analysis"
    / "dynamic-residency-r10-pre-ir-hostile-review-rejection-v1.json"
)


class Reject(RuntimeError):
    def __init__(self, reject_id: str, message: str) -> None:
        super().__init__(f"{reject_id}: {message}")
        self.reject_id = reject_id
        self.message = message


def reject(reject_id: str, message: str) -> None:
    raise Reject(reject_id, message)


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("IR-DUPLICATE-KEY", f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def parse_json_bytes(data: bytes, label: str) -> Any:
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=strict_object)
    except UnicodeDecodeError as exc:
        reject("IR-JSON", f"{label}: {exc}")
    except json.JSONDecodeError as exc:
        reject("IR-JSON", f"{label}: {exc}")
    reject_noncanonical_scalars(value, label)
    return value


def read_bytes(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        reject("IR-MISSING-INPUT", str(path))
    raise AssertionError


def load_json(path: Path) -> Any:
    return parse_json_bytes(read_bytes(path), str(path))


def reject_noncanonical_scalars(value: Any, path: str) -> None:
    if value is None:
        reject("IR-NULL", f"implicit null at {path}")
    if isinstance(value, float):
        reject("IR-FLOAT", f"floating point value at {path}")
    if isinstance(value, dict):
        for key, child in value.items():
            reject_noncanonical_scalars(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_noncanonical_scalars(child, f"{path}[{index}]")


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode(
        "ascii"
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def registry(items: list[dict[str, Any]], name: str) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in items:
        item_id = item["id"]
        if item_id in result:
            reject("IR-DUPLICATE-ID", f"duplicate {name} id {item_id}")
        result[item_id] = item
    return result


def expect(condition: bool, reject_id: str, message: str) -> None:
    if not condition:
        reject(reject_id, message)


class SemanticModel:
    BOOL = "Bool"
    INT = "Int"
    STRING = "String"
    WRITER_REF = "@WriterRef"
    CD_REF = "@ConsistencyDomainRef"
    LOCATION_REF = "@LocationRef"

    CTX_STATIC = "static"
    CTX_INIT = "init"
    CTX_METADATA = "metadata"
    CTX_STATE = "state"
    CTX_ACTION = "action"
    CTX_TEMPORAL = "temporal"
    CTX_LOCATION = "location"

    TEMPORAL_OPS = {
        "always",
        "eventually",
        "next",
        "enabled",
        "leads_to",
        "weak_fair",
        "strong_fair",
    }
    STATE_OPS = {"read", "call"}
    METADATA_OPS = {"writer", "cd"}
    EDGE_POLICY = {
        ("OBJDEF-AuthorityCore", "id"): ("REF-AUTHORITY-ID", "identity"),
        ("OBJDEF-AuthorityCore", "parent"): ("REF-AUTHORITY-PARENT", "liveness"),
        ("OBJDEF-AuthorityCore", "owner"): ("REF-SUBJECT", "liveness"),
        ("OBJDEF-AuthorityCore", "revocation_path[].scope"): ("REF-REVOCATION-PATH", "authorization_horizon"),
        ("OBJDEF-AuthorityCore", "own_scope"): ("REF-REVOCATION", "authorization_horizon"),
        ("OBJDEF-AuthorityIntersectionCore", "caller_authority"): ("REF-ASYNC-CALLER", "authorization_horizon"),
        ("OBJDEF-AuthorityIntersectionCore", "service_authority"): ("REF-ASYNC-SERVICE", "authorization_horizon"),
        ("OBJDEF-AuthorityIntersectionCore", "caller_escrow"): ("REF-ASYNC-CALLER-ESCROW", "liveness"),
        ("OBJDEF-AuthorityIntersectionCore", "service_escrow"): ("REF-ASYNC-SERVICE-ESCROW", "liveness"),
        ("OBJDEF-ActivationRequestCore", "id"): ("REF-ACTIVATION-ID", "identity"),
        ("OBJDEF-ActivationRequestCore", "carrier"): ("REF-ACTIVATION-CARRIER", "liveness"),
        ("OBJDEF-ActivationRequestCore", "execution_subject"): ("REF-ACTIVATION-SUBJECT", "liveness"),
        ("OBJDEF-ActivationRequestCore", "program"): ("REF-ACTIVATION-PROGRAM", "liveness"),
        ("OBJDEF-ActivationRequestCore", "protection_domain"): ("REF-ACTIVATION-PDOMAIN", "authorization_horizon"),
        ("OBJDEF-ActivationRequestCore", "run_authority"): ("REF-ACTIVATION-RUN", "authorization_horizon"),
        ("OBJDEF-ActivationRequestCore", "sched_authority"): ("REF-ACTIVATION-SCHED", "authorization_horizon"),
        ("OBJDEF-ActivationRequestCore", "charge_authority"): ("REF-ACTIVATION-CHARGE", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "id"): ("REF-DISPATCH-ID", "identity"),
        ("OBJDEF-DispatchAuthoritySnapshot", "opportunity"): ("REF-DISPATCH-OPPORTUNITY", "liveness"),
        ("OBJDEF-DispatchAuthoritySnapshot", "attempt"): ("REF-DISPATCH-ATTEMPT", "liveness"),
        ("OBJDEF-DispatchAuthoritySnapshot", "activation_request"): ("REF-ACTIVATION-OBJECT", "liveness"),
        ("OBJDEF-DispatchAuthoritySnapshot", "subject"): ("REF-DISPATCH-SUBJECT", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "program"): ("REF-DISPATCH-PROGRAM", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "run_authority"): ("REF-DISPATCH-RUN", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "sched_authority"): ("REF-DISPATCH-SCHED", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "charge_authority"): ("REF-DISPATCH-CHARGE", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "aggregate"): ("REF-DISPATCH-AGGREGATE", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "ready"): ("REF-DISPATCH-READY", "liveness"),
        ("OBJDEF-DispatchAuthoritySnapshot", "escrow"): ("REF-DISPATCH-ESCROW", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "context"): ("REF-DISPATCH-CONTEXT", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "target_cpu"): ("REF-DISPATCH-CPU", "authorization_horizon"),
        ("OBJDEF-DispatchAuthoritySnapshot", "revocation_path[].scope"): ("REF-DISPATCH-REVOCATION-PATH", "authorization_horizon"),
        ("OBJDEF-EligibilitySealCore", "id"): ("REF-ELIGIBILITY-ID", "identity"),
        ("OBJDEF-EligibilitySealCore", "snapshot"): ("REF-ELIGIBILITY-SNAPSHOT", "liveness"),
        ("OBJDEF-EligibilitySealCore", "context_receipt"): ("REF-CONTEXT-RECEIPT", "authorization_horizon"),
    }

    def __init__(
        self,
        source: dict[str, Any],
        root: Path,
        disposition: dict[str, Any],
    ) -> None:
        self.source = source
        self.root = root
        self.disposition = disposition
        self.bounds = source["bounds"]
        self.types = registry(source["types"], "type")
        self.cds = registry(source["consistency_domains"], "consistency domain")
        self.writers = registry(source["writers"], "writer")
        self.objects = registry(source["objects"], "object")
        self.variables = registry(source["variables"], "variable")
        self.functions = registry(source["functions"], "function")
        self.txns = registry(source["transaction_kinds"], "transaction kind")
        self.actions = registry(source["actions"], "action")
        self.provider_formulas = registry(source["provider_formulas"], "provider formula")
        self.invariants = registry(source["invariants"], "invariant")
        self.progress = registry(source["progress_properties"], "progress property")
        self.refinements = registry(source["refinements"], "refinement")
        self.proofs = registry(source["proof_nodes"], "proof node")
        self.mutations = registry(source["mutation_obligations"], "mutation")
        self.imports = registry(source["imports"], "import")
        self.witnesses = registry(source["witnesses"], "witness")
        self.type_values_cache: dict[str, list[Any]] = {}
        self.location_table: dict[str, dict[str, Any]] = {}
        self.function_stack: list[str] = []
        self.ast_context_stack: list[str] = []
        self.function_graph: dict[str, list[str]] = {}
        self.import_bytes: dict[str, bytes] = {}
        self.witness_results: list[dict[str, Any]] = []

    def validate(self) -> dict[str, Any]:
        self.validate_types()
        self.validate_domains_and_writers()
        self.validate_variables()
        self.validate_objects()
        self.validate_functions()
        self.validate_provider_formulas()
        self.expand_locations()
        expanded_actions = self.expand_actions()
        expanded_txns = self.expand_transactions()
        all_actions = expanded_actions + expanded_txns
        self.validate_action_ownership_and_frames(all_actions)
        self.validate_formulas_and_proofs(all_actions)
        self.validate_imports()
        self.validate_blocker_and_mutation_coverage()
        self.validate_witnesses(all_actions)
        return self.make_expanded(all_actions)

    def known_type(self, type_id: str) -> bool:
        return type_id in self.types or type_id in {
            self.WRITER_REF,
            self.CD_REF,
            self.LOCATION_REF,
        }

    def validate_types(self) -> None:
        for builtin in (self.BOOL, self.INT, self.STRING):
            expect(builtin in self.types, "IR-TYPE", f"missing builtin type {builtin}")
            entry = self.types[builtin]
            expect(
                entry["kind"] == "builtin" and entry.get("builtin") == builtin,
                "IR-TYPE",
                f"invalid builtin declaration {builtin}",
            )

        for type_id, entry in self.types.items():
            kind = entry["kind"]
            if kind == "builtin":
                expect("builtin" in entry, "IR-TYPE", f"{type_id} lacks builtin")
            elif kind in {"enum", "nominal"}:
                has_values = bool(entry.get("values"))
                has_bound = "bound" in entry
                expect(has_values ^ has_bound, "IR-TYPE", f"{type_id} needs values xor bound")
                if has_bound:
                    expect(entry["bound"] in self.bounds, "IR-TYPE", f"unknown bound in {type_id}")
            elif kind == "range":
                expect("minimum" in entry and "maximum_ast" in entry, "IR-TYPE", f"range {type_id}")
                maximum_type = self.infer(entry["maximum_ast"], {}, self.CTX_STATIC)
                expect(maximum_type == self.INT, "IR-TYPE", f"range maximum for {type_id}")
            elif kind in {"option", "vector", "set"}:
                element = entry.get("element_type")
                expect(element in self.types, "IR-TYPE", f"unknown element type in {type_id}")
                if kind == "vector":
                    expect("length_ast" in entry, "IR-TYPE", f"vector {type_id} lacks length")
                    expect(
                        self.infer(entry["length_ast"], {}, self.CTX_STATIC) == self.INT,
                        "IR-TYPE",
                        type_id,
                    )
            elif kind == "record":
                self.validate_field_list(type_id, entry.get("fields", []))
                expect(bool(entry.get("fields")), "IR-TYPE", f"empty record {type_id}")
            elif kind == "variant":
                variants = entry.get("variants", [])
                expect(bool(variants), "IR-TYPE", f"empty variant {type_id}")
                tags: set[str] = set()
                for variant in variants:
                    expect(variant["tag"] not in tags, "IR-TYPE", f"duplicate tag in {type_id}")
                    tags.add(variant["tag"])
                    self.validate_field_list(f"{type_id}.{variant['tag']}", variant["fields"])
            elif kind == "tuple":
                members = entry.get("members", [])
                expect(bool(members), "IR-TYPE", f"empty tuple {type_id}")
                for member in members:
                    expect(member in self.types, "IR-TYPE", f"unknown tuple member {member}")
            else:
                reject("IR-TYPE", f"unknown kind {kind} for {type_id}")
        expect(
            self.bounds.get("ObjectSlotCapacity") == len(self.finite_values("ObjectSlotID")),
            "IR-BOUND",
            "ObjectSlotCapacity must equal the ObjectSlotID universe",
        )

    def validate_field_list(self, owner: str, fields: list[dict[str, Any]]) -> None:
        names: set[str] = set()
        for field in fields:
            expect(field["name"] not in names, "IR-TYPE", f"duplicate field {owner}.{field['name']}")
            names.add(field["name"])
            expect(field["type"] in self.types, "IR-TYPE", f"unknown type for {owner}.{field['name']}")

    def validate_domains_and_writers(self) -> None:
        for cd_id, entry in self.cds.items():
            for type_id in entry["index_types"]:
                expect(type_id in self.types, "IR-CD", f"{cd_id} unknown index type {type_id}")
        for writer_id, entry in self.writers.items():
            names = entry["index_names"]
            types = entry["index_types"]
            expect(len(names) == len(types), "IR-WRITER", f"{writer_id} index arity")
            env = dict(zip(names, types))
            for type_id in types:
                expect(type_id in self.types, "IR-WRITER", f"{writer_id} unknown type {type_id}")
            expect(
                self.infer(entry["consistency_domain_ast"], env, self.CTX_METADATA) == self.CD_REF,
                "IR-WRITER",
                f"{writer_id} CD AST",
            )

    def validate_variables(self) -> None:
        authoritative_storage = {
            "protected_authoritative",
            "provider_authoritative",
            "provider_immutable_fact",
        }
        storage_writer_classes = {
            "protected_authoritative": {"monitor"},
            "provider_authoritative": {
                "cpu_provider",
                "time_provider",
                "quorum_provider",
            },
            "provider_immutable_fact": {
                "cpu_provider",
                "time_provider",
                "quorum_provider",
            },
            "derived_index": {"monitor"},
            "audit": {"monitor"},
            "untrusted_input": {"environment"},
        }
        for variable_id, entry in self.variables.items():
            names = entry["key_names"]
            types = entry["key_types"]
            expect(len(names) == len(types), "IR-VARIABLE", f"{variable_id} key arity")
            env = dict(zip(names, types))
            for type_id in types:
                expect(type_id in self.types, "IR-VARIABLE", f"{variable_id} unknown key type")
                self.finite_values(type_id)
            expect(entry["value_type"] in self.types, "IR-VARIABLE", f"{variable_id} value type")
            expect(
                self.infer(entry["init_ast"], env, self.CTX_INIT) == entry["value_type"],
                "IR-INIT",
                variable_id,
            )
            self.validate_variant_field_safety(entry["init_ast"], env, self.CTX_INIT)
            expect(
                self.infer(entry["owner_ast"], env, self.CTX_METADATA) == self.WRITER_REF,
                "IR-OWNER",
                variable_id,
            )
            expect(
                self.infer(entry["consistency_domain_ast"], env, self.CTX_METADATA) == self.CD_REF,
                "IR-CD",
                variable_id,
            )
            shard_type = self.infer(entry["transaction_shard_ast"], env, self.CTX_METADATA)
            expect(shard_type == "ShardKey", "IR-SHARD", f"{variable_id} shard AST")
            expect(
                entry["authority_relevant"] == (entry["storage_class"] in authoritative_storage),
                "IR-AUTHORITY-CLASS",
                f"{variable_id} authority_relevant is not derived from storage_class",
            )
            owner_writer = entry["owner_ast"][1]
            writer_class = self.writers[owner_writer]["class"]
            expect(
                writer_class in storage_writer_classes[entry["storage_class"]],
                "IR-WRITER-STORAGE",
                f"{variable_id}: {writer_class}/{entry['storage_class']}",
            )

    def validate_objects(self) -> None:
        declared_policy_keys: set[tuple[str, str]] = set()
        for object_id, entry in self.objects.items():
            record_type = entry["record_type"]
            expect(record_type in self.types, "IR-OBJECT", f"{object_id} unknown record type")
            expect(self.types[record_type]["kind"] == "record", "IR-OBJECT", object_id)
            fields = {field["name"] for field in self.types[record_type]["fields"]}
            expect(set(entry["identity_fields"]) <= fields, "IR-OBJECT", f"{object_id} identity fields")
            expect(
                entry["constructor_action"] in self.actions or entry["constructor_action"] in self.txns,
                "IR-OBJECT",
                f"{object_id} constructor",
            )
            expect(entry["allocator"] in self.variables, "IR-OBJECT", f"{object_id} allocator")
            edge_paths: set[str] = set()
            for edge in entry["reference_edges"]:
                expect(edge["field_path"] not in edge_paths, "IR-EDGE", f"duplicate edge in {object_id}")
                edge_paths.add(edge["field_path"])
                expect(edge["target_type"] in self.types, "IR-EDGE", f"{object_id} target")
                leaf_type = self.resolve_field_path(record_type, edge["field_path"])
                expect(
                    leaf_type == edge["target_type"],
                    "IR-EDGE",
                    f"{object_id}.{edge['field_path']}: {leaf_type}/{edge['target_type']}",
                )
                policy_key = (object_id, edge["field_path"])
                declared_policy_keys.add(policy_key)
                expect(policy_key in self.EDGE_POLICY, "IR-EDGE-POLICY", str(policy_key))
                expect(
                    (edge["class"], edge["strength"]) == self.EDGE_POLICY[policy_key],
                    "IR-EDGE-POLICY",
                    f"{policy_key}: {(edge['class'], edge['strength'])}",
                )
            expected_reference_paths = self.reference_leaf_paths(record_type)
            expect(
                edge_paths == expected_reference_paths,
                "IR-EDGE-COVERAGE",
                f"{object_id}: missing={sorted(expected_reference_paths - edge_paths)} "
                f"extra={sorted(edge_paths - expected_reference_paths)}",
            )
            self.validate_object_constructor(object_id, entry)
        expect(
            declared_policy_keys == set(self.EDGE_POLICY),
            "IR-EDGE-POLICY",
            "edge policy and object registry differ",
        )
        payload_record_types = {
            field["type"]
            for variant in self.types["ObjectPayload"]["variants"]
            for field in variant["fields"]
        }
        expect(
            payload_record_types == {entry["record_type"] for entry in self.objects.values()},
            "IR-OBJECT-REGISTRY",
            "ObjectPayload and ObjectDef registries differ",
        )

    def contains_record_constructor(self, value: Any, record_type: str) -> bool:
        if isinstance(value, list):
            if len(value) >= 2 and value[0] == "record" and value[1] == record_type:
                return True
            return any(self.contains_record_constructor(child, record_type) for child in value)
        if isinstance(value, dict):
            return any(self.contains_record_constructor(child, record_type) for child in value.values())
        return False

    def contains_exact_ast(self, value: Any, expected: Any) -> bool:
        if canonical_bytes(value) == canonical_bytes(expected):
            return True
        if isinstance(value, list):
            return any(self.contains_exact_ast(child, expected) for child in value)
        if isinstance(value, dict):
            return any(self.contains_exact_ast(child, expected) for child in value.values())
        return False

    def parse_object_publication(self, update: dict[str, Any]) -> str:
        value = update["value_ast"]
        expect(
            isinstance(value, list)
            and len(value) == 4
            and value[:3] == ["variant", "ObjectSlotState", "Published"],
            "IR-OBJECT-CONSTRUCTOR",
            "object publication is not an unconditional Published constructor",
        )
        fields = value[3]
        expect(
            set(fields) == {"generation", "payload", "digest", "txn_id"},
            "IR-OBJECT-CONSTRUCTOR",
            "Published field set",
        )
        target_read = ["read", update["target"][1], *update["target"][2:]]
        expect(
            canonical_bytes(fields["generation"])
            == canonical_bytes(["field", target_read, "generation"]),
            "IR-OBJECT-CONSTRUCTOR",
            "publication generation is not preserved",
        )
        payload = fields["payload"]
        expect(
            isinstance(payload, list)
            and len(payload) == 4
            and payload[0] == "variant"
            and payload[1] == "ObjectPayload",
            "IR-OBJECT-CONSTRUCTOR",
            "payload constructor",
        )
        payload_variants = {
            variant["tag"]: variant for variant in self.types["ObjectPayload"]["variants"]
        }
        expect(payload[2] in payload_variants, "IR-OBJECT-CONSTRUCTOR", str(payload[2]))
        variant = payload_variants[payload[2]]
        expect(len(variant["fields"]) == 1, "IR-OBJECT-CONSTRUCTOR", payload[2])
        field = variant["fields"][0]
        expect(set(payload[3]) == {field["name"]}, "IR-OBJECT-CONSTRUCTOR", payload[2])
        record_ast = payload[3][field["name"]]
        expect(
            isinstance(record_ast, list)
            and len(record_ast) == 3
            and record_ast[0] == "record"
            and record_ast[1] == field["type"],
            "IR-OBJECT-CONSTRUCTOR",
            f"{payload[2]} record constructor",
        )
        return field["type"]

    def validate_object_constructor(self, object_id: str, entry: dict[str, Any]) -> None:
        constructor_id = entry["constructor_action"]
        expect(constructor_id in self.txns, "IR-OBJECT-CONSTRUCTOR", f"{object_id} direct constructor")
        txn = self.txns[constructor_id]
        updates = txn["commit_updates"]
        allocator_updates = [
            update for update in updates if update["target"][1] == entry["allocator"]
        ]
        expect(
            len(allocator_updates) == 1,
            "IR-OBJECT-ALLOCATOR",
            f"{object_id} constructor must update allocator exactly once",
        )
        all_publications = [
            update for update in updates if update["target"][1] == "object_store"
        ]
        publication_types = [
            self.parse_object_publication(update) for update in all_publications
        ]
        expect(
            entry["record_type"] in publication_types,
            "IR-OBJECT-CONSTRUCTOR",
            f"{object_id} constructor does not publish {entry['record_type']}",
        )
        allocator_update = allocator_updates[0]
        allocator_read = [
            "read",
            allocator_update["target"][1],
            *allocator_update["target"][2:],
        ]
        publication_count = len(all_publications)
        next_ordinal = [
            "add",
            ["field", allocator_read, "next_ordinal"],
            ["int", publication_count],
        ]
        expected_allocator_value = [
            "record",
            "ObjectAllocatorState",
            {
                "next_ordinal": next_ordinal,
                "exhausted": [
                    "ge",
                    next_ordinal,
                    ["bound", "ObjectSlotCapacity"],
                ],
            },
        ]
        expect(
            canonical_bytes(allocator_update["value_ast"])
            == canonical_bytes(expected_allocator_value),
            "IR-OBJECT-ALLOCATOR",
            f"{constructor_id} must advance by {publication_count}",
        )

    def generated_publication_guard(self, txn: dict[str, Any]) -> list[Any]:
        publications = [
            update for update in txn["commit_updates"] if update["target"][1] == "object_store"
        ]
        if not publications:
            return ["bool", True]
        allocator_updates = [
            update
            for update in txn["commit_updates"]
            if update["target"][1] == "object_allocator"
        ]
        expect(len(allocator_updates) == 1, "IR-OBJECT-ALLOCATOR", txn["id"])
        allocator = allocator_updates[0]
        allocator_read = ["read", allocator["target"][1], *allocator["target"][2:]]
        next_ordinal = [
            "add",
            ["field", allocator_read, "next_ordinal"],
            ["int", len(publications)],
        ]
        guards: list[Any] = [
            ["eq", ["field", allocator_read, "exhausted"], ["bool", False]],
            ["le", next_ordinal, ["bound", "ObjectSlotCapacity"]],
        ]
        guards.extend(
            [
                "eq",
                [
                    "tag",
                    ["read", publication["target"][1], *publication["target"][2:]],
                ],
                ["string", "Vacant"],
            ]
            for publication in publications
        )
        return ["and", *guards]

    def resolve_field_path(self, root_type: str, field_path: str) -> str:
        current = root_type
        for component_with_suffix in field_path.split("."):
            is_collection = component_with_suffix.endswith("[]")
            component = component_with_suffix[:-2] if is_collection else component_with_suffix
            entry = self.types[current]
            if entry["kind"] == "record":
                matches = [field["type"] for field in entry["fields"] if field["name"] == component]
            elif entry["kind"] == "variant":
                matches = [
                    field["type"]
                    for variant in entry["variants"]
                    for field in variant["fields"]
                    if field["name"] == component
                ]
            else:
                matches = []
            expect(bool(matches), "IR-EDGE", f"{current}.{component}")
            expect(len(set(matches)) == 1, "IR-EDGE", f"ambiguous {current}.{component}")
            current = matches[0]
            if is_collection:
                collection = self.types[current]
                expect(
                    collection["kind"] in {"vector", "set", "option"},
                    "IR-EDGE",
                    f"{current} is not a collection",
                )
                current = collection["element_type"]
        return current

    def reference_leaf_paths(self, type_id: str, prefix: str = "") -> set[str]:
        entry = self.types[type_id]
        if entry["kind"] == "nominal":
            expect(bool(prefix), "IR-EDGE-COVERAGE", f"root nominal {type_id}")
            return {prefix}
        if entry["kind"] == "record":
            result: set[str] = set()
            for field in entry["fields"]:
                child_prefix = f"{prefix}.{field['name']}" if prefix else field["name"]
                result |= self.reference_leaf_paths(field["type"], child_prefix)
            return result
        if entry["kind"] in {"vector", "set", "option"}:
            expect(bool(prefix), "IR-EDGE-COVERAGE", f"root collection {type_id}")
            return self.reference_leaf_paths(entry["element_type"], f"{prefix}[]")
        if entry["kind"] == "tuple":
            result = set()
            for index, member in enumerate(entry["members"]):
                child_prefix = f"{prefix}.{index}" if prefix else str(index)
                result |= self.reference_leaf_paths(member, child_prefix)
            return result
        if entry["kind"] == "variant":
            result = set()
            for variant in entry["variants"]:
                for field in variant["fields"]:
                    child_prefix = (
                        f"{prefix}.{variant['tag']}.{field['name']}"
                        if prefix
                        else f"{variant['tag']}.{field['name']}"
                    )
                    result |= self.reference_leaf_paths(field["type"], child_prefix)
            return result
        return set()

    def validate_functions(self) -> None:
        self.function_graph = {
            function_id: sorted(self.collect_function_calls(entry["body_ast"]))
            for function_id, entry in self.functions.items()
        }
        for function_id, callees in self.function_graph.items():
            for callee in callees:
                expect(callee in self.functions, "IR-AST-CALL", f"{function_id} -> {callee}")
        self.require_acyclic(self.function_graph, "IR-FUNCTION-CYCLE")
        for function_id, entry in self.functions.items():
            env = self.parameter_env(entry["parameters"], f"function {function_id}")
            expect(entry["return_type"] in self.types, "IR-FUNCTION", function_id)
            actual = self.infer(entry["body_ast"], env, self.CTX_STATE)
            expect(actual == entry["return_type"], "IR-FUNCTION", f"{function_id}: {actual}")
            self.validate_variant_field_safety(entry["body_ast"], env, self.CTX_STATE)

    def collect_function_calls(self, value: Any) -> set[str]:
        calls: set[str] = set()
        if isinstance(value, list):
            if value and value[0] == "call" and len(value) >= 2 and isinstance(value[1], str):
                calls.add(value[1])
            for child in value:
                calls |= self.collect_function_calls(child)
        elif isinstance(value, dict):
            for child in value.values():
                calls |= self.collect_function_calls(child)
        return calls

    def validate_provider_formulas(self) -> None:
        for formula_id, entry in self.provider_formulas.items():
            expect(entry["provider_writer"] in self.writers, "IR-PROVIDER", formula_id)
            for field in ("state_formula_ast", "fault_formula_ast", "fault_bound_ast"):
                expect(
                    self.infer(entry[field], {}, self.CTX_STATE) == self.BOOL,
                    "IR-PROVIDER",
                    f"{formula_id}.{field}",
                )
                self.validate_variant_field_safety(entry[field], {}, self.CTX_STATE)
            for field in ("guarantee_ast", "progress_ast"):
                expect(
                    self.infer(entry[field], {}, self.CTX_TEMPORAL) == self.BOOL,
                    "IR-PROVIDER",
                    f"{formula_id}.{field}",
                )
                self.validate_variant_field_safety(entry[field], {}, self.CTX_TEMPORAL)

    def parameter_env(self, parameters: list[dict[str, Any]], owner: str) -> dict[str, str]:
        env: dict[str, str] = {}
        for parameter in parameters:
            name = parameter["name"]
            type_id = parameter["type"]
            expect(name not in env, "IR-PARAM", f"duplicate {owner} parameter {name}")
            expect(type_id in self.types, "IR-PARAM", f"unknown {owner} type {type_id}")
            self.finite_values(type_id)
            env[name] = type_id
        return env

    def type_field(self, type_id: str, field_name: str) -> str:
        entry = self.types[type_id]
        if entry["kind"] == "record":
            matches = [field["type"] for field in entry["fields"] if field["name"] == field_name]
        elif entry["kind"] == "variant":
            matches = [
                field["type"]
                for variant in entry["variants"]
                for field in variant["fields"]
                if field["name"] == field_name
            ]
        else:
            matches = []
        expect(bool(matches), "IR-AST-FIELD", f"{type_id}.{field_name}")
        expect(len(set(matches)) == 1, "IR-AST-FIELD", f"ambiguous {type_id}.{field_name}")
        return matches[0]

    def positive_tag_facts(self, ast: Any) -> dict[bytes, str]:
        facts: dict[bytes, str] = {}
        if not isinstance(ast, list) or not ast:
            return facts
        if ast[0] == "and":
            conflicts: set[bytes] = set()
            for child in ast[1:]:
                for key, tag in self.positive_tag_facts(child).items():
                    if key in conflicts:
                        continue
                    if key in facts and facts[key] != tag:
                        facts.pop(key)
                        conflicts.add(key)
                    elif key not in facts:
                        facts[key] = tag
            return facts
        if ast[0] == "eq" and len(ast) == 3:
            pairs = ((ast[1], ast[2]), (ast[2], ast[1]))
            for tag_ast, literal_ast in pairs:
                if (
                    isinstance(tag_ast, list)
                    and len(tag_ast) == 2
                    and tag_ast[0] == "tag"
                    and isinstance(literal_ast, list)
                    and len(literal_ast) == 2
                    and literal_ast[0] == "string"
                ):
                    facts[canonical_bytes(tag_ast[1])] = literal_ast[1]
        return facts

    def validate_variant_field_safety(
        self,
        ast: Any,
        env: dict[str, str],
        context: str,
        assumptions: dict[bytes, str] | None = None,
    ) -> None:
        active = dict(assumptions or {})
        if isinstance(ast, dict):
            for child in ast.values():
                self.validate_variant_field_safety(child, env, context, active)
            return
        if not isinstance(ast, list) or not ast:
            return
        op = ast[0]
        if not isinstance(op, str):
            for child in ast:
                self.validate_variant_field_safety(child, env, context, active)
            return
        if op in self.TEMPORAL_OPS:
            for child in ast[1:]:
                self.validate_variant_field_safety(child, env, context, {})
            return
        if op == "field":
            source = ast[1]
            source_type = self.infer(source, env, context)
            entry = self.types[source_type]
            if entry["kind"] == "variant":
                field_name = ast[2]
                valid_tags = {
                    variant["tag"]
                    for variant in entry["variants"]
                    if any(field["name"] == field_name for field in variant["fields"])
                }
                all_tags = {variant["tag"] for variant in entry["variants"]}
                if valid_tags != all_tags:
                    selected_tag = active.get(canonical_bytes(source))
                    expect(
                        selected_tag in valid_tags,
                        "IR-VARIANT-FIELD",
                        f"{source_type}.{field_name} lacks dominating tag guard",
                    )
            self.validate_variant_field_safety(source, env, context, active)
            return
        if op == "and":
            sequential = dict(active)
            for child in ast[1:]:
                self.validate_variant_field_safety(child, env, context, sequential)
                sequential.update(self.positive_tag_facts(child))
            return
        if op in {"if", "implies"}:
            condition = ast[1]
            self.validate_variant_field_safety(condition, env, context, active)
            guarded = dict(active)
            guarded.update(self.positive_tag_facts(condition))
            self.validate_variant_field_safety(ast[2], env, context, guarded)
            if op == "if":
                self.validate_variant_field_safety(ast[3], env, context, active)
            return
        for child in ast[1:]:
            self.validate_variant_field_safety(child, env, context, active)

    def infer(
        self,
        ast: Any,
        env: dict[str, str],
        context: str | None = None,
    ) -> str:
        inherited = self.ast_context_stack[-1] if self.ast_context_stack else self.CTX_STATE
        active_context = context or inherited
        expect(
            active_context
            in {
                self.CTX_STATIC,
                self.CTX_INIT,
                self.CTX_METADATA,
                self.CTX_STATE,
                self.CTX_ACTION,
                self.CTX_TEMPORAL,
                self.CTX_LOCATION,
            },
            "IR-AST-CONTEXT",
            active_context,
        )
        self.ast_context_stack.append(active_context)
        try:
            return self._infer_in_context(ast, env)
        finally:
            self.ast_context_stack.pop()

    def _infer_in_context(self, ast: Any, env: dict[str, str]) -> str:
        expect(isinstance(ast, list) and ast, "IR-AST", f"not an AST: {ast!r}")
        op = ast[0]
        expect(isinstance(op, str), "IR-AST", "operator is not a string")
        context = self.ast_context_stack[-1]
        if op in self.TEMPORAL_OPS:
            expect(context == self.CTX_TEMPORAL, "IR-AST-CONTEXT", f"{op} in {context}")
        if op in self.STATE_OPS:
            expect(
                context in {self.CTX_STATE, self.CTX_ACTION, self.CTX_TEMPORAL},
                "IR-AST-CONTEXT",
                f"{op} in {context}",
            )
        if op in self.METADATA_OPS:
            expect(context == self.CTX_METADATA, "IR-AST-CONTEXT", f"{op} in {context}")
        if op == "loc":
            expect(context == self.CTX_LOCATION, "IR-AST-CONTEXT", f"loc in {context}")

        if op == "bool":
            expect(len(ast) == 2 and isinstance(ast[1], bool), "IR-AST", "bool")
            return self.BOOL
        if op == "int":
            expect(len(ast) == 2 and isinstance(ast[1], int) and not isinstance(ast[1], bool), "IR-AST", "int")
            return self.INT
        if op == "string":
            expect(len(ast) == 2 and isinstance(ast[1], str), "IR-AST", "string")
            return self.STRING
        if op == "bound":
            expect(len(ast) == 2 and ast[1] in self.bounds, "IR-AST", f"bound {ast}")
            return self.INT
        if op in {"enum", "id"}:
            expect(len(ast) == 3 and ast[1] in self.types, "IR-AST", f"literal {ast}")
            expect(ast[2] in self.finite_values(ast[1]), "IR-AST", f"literal value {ast}")
            return ast[1]
        if op == "param":
            expect(len(ast) == 2 and ast[1] in env, "IR-AST", f"parameter {ast}")
            return env[ast[1]]
        if op == "none":
            expect(len(ast) == 2 and self.types.get(ast[1], {}).get("kind") == "option", "IR-AST", "none")
            return ast[1]
        if op == "some":
            expect(len(ast) == 3 and self.types.get(ast[1], {}).get("kind") == "option", "IR-AST", "some")
            expect(self.infer(ast[2], env) == self.types[ast[1]]["element_type"], "IR-AST", "some type")
            return ast[1]
        if op == "read":
            expect(len(ast) >= 2 and ast[1] in self.variables, "IR-AST-READ", str(ast))
            variable = self.variables[ast[1]]
            expect(len(ast) - 2 == len(variable["key_types"]), "IR-AST-READ", f"arity {ast[1]}")
            for key_ast, key_type in zip(ast[2:], variable["key_types"]):
                expect(self.infer(key_ast, env) == key_type, "IR-AST-READ", f"key type {ast[1]}")
            return variable["value_type"]
        if op == "field":
            expect(len(ast) == 3 and isinstance(ast[2], str), "IR-AST-FIELD", str(ast))
            return self.type_field(self.infer(ast[1], env), ast[2])
        if op == "tag":
            expect(len(ast) == 2, "IR-AST", "tag")
            source_type = self.infer(ast[1], env)
            expect(self.types[source_type]["kind"] == "variant", "IR-AST", "tag source")
            return self.STRING
        if op in {"record", "variant"}:
            minimum = 3 if op == "record" else 4
            expect(len(ast) == minimum and ast[1] in self.types, "IR-AST-CONSTRUCTOR", str(ast))
            type_id = ast[1]
            entry = self.types[type_id]
            expected_kind = "record" if op == "record" else "variant"
            expect(entry["kind"] == expected_kind, "IR-AST-CONSTRUCTOR", type_id)
            if op == "record":
                fields_value = ast[2]
                field_defs = entry["fields"]
            else:
                tag = ast[2]
                variants = {variant["tag"]: variant for variant in entry["variants"]}
                expect(tag in variants, "IR-AST-CONSTRUCTOR", f"{type_id}.{tag}")
                fields_value = ast[3]
                field_defs = variants[tag]["fields"]
            expect(isinstance(fields_value, dict), "IR-AST-CONSTRUCTOR", type_id)
            expected_fields = {field["name"]: field["type"] for field in field_defs}
            expect(set(fields_value) == set(expected_fields), "IR-AST-CONSTRUCTOR", f"field set {type_id}")
            for name, value_ast in fields_value.items():
                expect(self.infer(value_ast, env) == expected_fields[name], "IR-AST-CONSTRUCTOR", f"{type_id}.{name}")
            return type_id
        if op == "with":
            expect(len(ast) == 3 and isinstance(ast[2], dict), "IR-AST-CONSTRUCTOR", "with")
            type_id = self.infer(ast[1], env)
            entry = self.types[type_id]
            expect(entry["kind"] == "record", "IR-AST-CONSTRUCTOR", f"with {type_id}")
            field_types = {field["name"]: field["type"] for field in entry["fields"]}
            expect(set(ast[2]) <= set(field_types), "IR-AST-CONSTRUCTOR", f"with fields {type_id}")
            for name, value_ast in ast[2].items():
                expect(self.infer(value_ast, env) == field_types[name], "IR-AST-CONSTRUCTOR", f"with {type_id}.{name}")
            return type_id
        if op in {"vector", "set", "tuple"}:
            expect(len(ast) == 3 and ast[1] in self.types and isinstance(ast[2], list), "IR-AST", str(ast))
            type_id = ast[1]
            entry = self.types[type_id]
            expect(entry["kind"] == op, "IR-AST", f"{type_id} is not {op}")
            if op == "tuple":
                expect(len(ast[2]) == len(entry["members"]), "IR-AST", f"tuple arity {type_id}")
                for value_ast, member_type in zip(ast[2], entry["members"]):
                    expect(self.infer(value_ast, env) == member_type, "IR-AST", f"tuple {type_id}")
            else:
                for value_ast in ast[2]:
                    expect(self.infer(value_ast, env) == entry["element_type"], "IR-AST", type_id)
                if op == "vector":
                    expected_len = self.eval_int(entry["length_ast"])
                    expect(len(ast[2]) == expected_len, "IR-AST", f"vector length {type_id}")
            return type_id
        if op == "call":
            expect(len(ast) >= 2 and ast[1] in self.functions, "IR-AST-CALL", str(ast))
            function = self.functions[ast[1]]
            expect(len(ast) - 2 == len(function["parameters"]), "IR-AST-CALL", ast[1])
            for arg, parameter in zip(ast[2:], function["parameters"]):
                expect(self.infer(arg, env) == parameter["type"], "IR-AST-CALL", ast[1])
            return function["return_type"]
        if op in {"and", "or"}:
            expect(len(ast) >= 3, "IR-AST", op)
            for arg in ast[1:]:
                expect(self.infer(arg, env) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op == "not":
            expect(len(ast) == 2 and self.infer(ast[1], env) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op in {"implies", "iff"}:
            expect(len(ast) == 3, "IR-AST", op)
            expect(self.infer(ast[1], env) == self.BOOL, "IR-AST", op)
            expect(self.infer(ast[2], env) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op in {"eq", "ne"}:
            expect(len(ast) == 3, "IR-AST", op)
            left = self.infer(ast[1], env)
            right = self.infer(ast[2], env)
            expect(left == right, "IR-AST", f"{op} type mismatch {left}/{right}")
            return self.BOOL
        if op in {"lt", "le", "gt", "ge"}:
            expect(len(ast) == 3, "IR-AST", op)
            expect(self.infer(ast[1], env) == self.INT, "IR-AST", op)
            expect(self.infer(ast[2], env) == self.INT, "IR-AST", op)
            return self.BOOL
        if op in {"add", "sub", "min", "max"}:
            expect(len(ast) >= 3, "IR-AST", op)
            for arg in ast[1:]:
                expect(self.infer(arg, env) == self.INT, "IR-AST", op)
            return self.INT
        if op == "if":
            expect(len(ast) == 4 and self.infer(ast[1], env) == self.BOOL, "IR-AST", op)
            then_type = self.infer(ast[2], env)
            expect(self.infer(ast[3], env) == then_type, "IR-AST", "if branch type")
            return then_type
        if op in {"forall", "exists"}:
            expect(len(ast) == 3 and isinstance(ast[1], list), "IR-AST", op)
            nested = dict(env)
            for binder in ast[1]:
                expect(isinstance(binder, list) and len(binder) == 2, "IR-AST", f"{op} binder")
                name, type_id = binder
                expect(name not in nested and type_id in self.types, "IR-AST", f"{op} binder")
                self.finite_values(type_id)
                nested[name] = type_id
            expect(self.infer(ast[2], nested) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op == "sum":
            expect(len(ast) == 3 and isinstance(ast[1], list), "IR-AST", op)
            nested = dict(env)
            for binder in ast[1]:
                expect(isinstance(binder, list) and len(binder) == 2, "IR-AST", "sum binder")
                name, type_id = binder
                expect(name not in nested and type_id in self.types, "IR-AST", "sum binder")
                self.finite_values(type_id)
                nested[name] = type_id
            expect(self.infer(ast[2], nested) == self.INT, "IR-AST", op)
            return self.INT
        if op in {"always", "eventually", "next", "enabled"}:
            expect(len(ast) == 2 and self.infer(ast[1], env) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op in {"leads_to", "weak_fair", "strong_fair"}:
            expect(len(ast) == 3, "IR-AST", op)
            expect(self.infer(ast[1], env) == self.BOOL, "IR-AST", op)
            expect(self.infer(ast[2], env) == self.BOOL, "IR-AST", op)
            return self.BOOL
        if op == "writer":
            expect(len(ast) >= 2 and ast[1] in self.writers, "IR-AST-WRITER", str(ast))
            writer = self.writers[ast[1]]
            expect(len(ast) - 2 == len(writer["index_types"]), "IR-AST-WRITER", ast[1])
            for arg, type_id in zip(ast[2:], writer["index_types"]):
                expect(self.infer(arg, env) == type_id, "IR-AST-WRITER", ast[1])
            return self.WRITER_REF
        if op == "cd":
            expect(len(ast) >= 2 and ast[1] in self.cds, "IR-AST-CD", str(ast))
            cd = self.cds[ast[1]]
            expect(len(ast) - 2 == len(cd["index_types"]), "IR-AST-CD", ast[1])
            for arg, type_id in zip(ast[2:], cd["index_types"]):
                expect(self.infer(arg, env) == type_id, "IR-AST-CD", ast[1])
            return self.CD_REF
        if op == "loc":
            expect(len(ast) >= 2 and ast[1] in self.variables, "IR-AST-LOC", str(ast))
            variable = self.variables[ast[1]]
            expect(len(ast) - 2 == len(variable["key_types"]), "IR-AST-LOC", ast[1])
            for arg, type_id in zip(ast[2:], variable["key_types"]):
                expect(self.infer(arg, env) == type_id, "IR-AST-LOC", ast[1])
            return self.LOCATION_REF
        if op == "digest":
            expect(len(ast) == 2, "IR-AST", op)
            self.infer(ast[1], env)
            return self.STRING
        reject("IR-AST-OP", f"unknown operator {op}")
        raise AssertionError

    def eval_int(self, ast: Any) -> int:
        op = ast[0]
        if op == "int":
            return ast[1]
        if op == "bound":
            return self.bounds[ast[1]]
        if op == "sub":
            values = [self.eval_int(value) for value in ast[1:]]
            return values[0] - sum(values[1:])
        if op == "add":
            return sum(self.eval_int(value) for value in ast[1:])
        reject("IR-STATIC-INT", str(ast))
        raise AssertionError

    def finite_values(self, type_id: str) -> list[Any]:
        if type_id in self.type_values_cache:
            return self.type_values_cache[type_id]
        entry = self.types[type_id]
        kind = entry["kind"]
        if kind in {"enum", "nominal"}:
            if "values" in entry:
                values: list[Any] = list(entry["values"])
            else:
                values = [f"{type_id}:{index}" for index in range(self.bounds[entry["bound"]])]
        elif kind == "range":
            maximum = self.eval_int(entry["maximum_ast"])
            values = list(range(entry["minimum"], maximum + 1))
        elif kind == "builtin" and type_id == self.BOOL:
            values = [False, True]
        else:
            reject("IR-UNBOUNDED-PARAM", f"type {type_id} cannot be enumerated")
            raise AssertionError
        expect(bool(values), "IR-EMPTY-TYPE", type_id)
        self.type_values_cache[type_id] = values
        return values

    def literal_ast(self, type_id: str, value: Any) -> list[Any]:
        if type_id == self.BOOL:
            return ["bool", value]
        if type_id == self.INT or self.types[type_id]["kind"] == "range":
            return ["int", value]
        return ["id", type_id, value]

    def eval_ast(
        self,
        ast: Any,
        state: dict[str, Any],
        env: dict[str, Any],
        read_trace: set[str] | None = None,
    ) -> Any:
        expect(isinstance(ast, list) and ast, "IR-EVAL", str(ast))
        op = ast[0]
        if op in {"bool", "int", "string"}:
            return ast[1]
        if op == "bound":
            return self.bounds[ast[1]]
        if op in {"enum", "id"}:
            return ast[2]
        if op == "param":
            expect(ast[1] in env, "IR-EVAL", f"unbound {ast[1]}")
            return env[ast[1]]
        if op == "none":
            return {"@option": ast[1], "present": False}
        if op == "some":
            return {
                "@option": ast[1],
                "present": True,
                "value": self.eval_ast(ast[2], state, env, read_trace),
            }
        if op == "read":
            keys = [self.eval_ast(key, state, env, read_trace) for key in ast[2:]]
            location = self.location_id(ast[1], keys)
            expect(location in state, "IR-EVAL", f"unknown state location {location}")
            if read_trace is not None:
                read_trace.add(location)
            return copy.deepcopy(state[location])
        if op == "field":
            source = self.eval_ast(ast[1], state, env, read_trace)
            expect(isinstance(source, dict) and ast[2] in source, "IR-EVAL-FIELD", ast[2])
            return copy.deepcopy(source[ast[2]])
        if op == "tag":
            source = self.eval_ast(ast[1], state, env, read_trace)
            expect(isinstance(source, dict) and "@tag" in source, "IR-EVAL-TAG", str(ast[1]))
            return source["@tag"]
        if op == "record":
            return {
                "@type": ast[1],
                **{
                    name: self.eval_ast(value, state, env, read_trace)
                    for name, value in ast[2].items()
                },
            }
        if op == "variant":
            return {
                "@type": ast[1],
                "@tag": ast[2],
                **{
                    name: self.eval_ast(value, state, env, read_trace)
                    for name, value in ast[3].items()
                },
            }
        if op == "with":
            value = self.eval_ast(ast[1], state, env, read_trace)
            expect(isinstance(value, dict), "IR-EVAL", "with source")
            result = copy.deepcopy(value)
            for name, update in ast[2].items():
                result[name] = self.eval_ast(update, state, env, read_trace)
            return result
        if op in {"vector", "tuple"}:
            return [self.eval_ast(value, state, env, read_trace) for value in ast[2]]
        if op == "set":
            values = [self.eval_ast(value, state, env, read_trace) for value in ast[2]]
            return sorted(values, key=lambda value: canonical_bytes(value))
        if op == "call":
            function = self.functions[ast[1]]
            arguments = [self.eval_ast(arg, state, env, read_trace) for arg in ast[2:]]
            nested = {
                parameter["name"]: argument
                for parameter, argument in zip(function["parameters"], arguments)
            }
            return self.eval_ast(function["body_ast"], state, nested, read_trace)
        if op == "and":
            for child in ast[1:]:
                if not self.eval_ast(child, state, env, read_trace):
                    return False
            return True
        if op == "or":
            for child in ast[1:]:
                if self.eval_ast(child, state, env, read_trace):
                    return True
            return False
        if op == "not":
            return not self.eval_ast(ast[1], state, env, read_trace)
        if op == "implies":
            return (not self.eval_ast(ast[1], state, env, read_trace)) or bool(
                self.eval_ast(ast[2], state, env, read_trace)
            )
        if op == "iff":
            return bool(self.eval_ast(ast[1], state, env, read_trace)) == bool(
                self.eval_ast(ast[2], state, env, read_trace)
            )
        if op in {"eq", "ne", "lt", "le", "gt", "ge"}:
            left = self.eval_ast(ast[1], state, env, read_trace)
            right = self.eval_ast(ast[2], state, env, read_trace)
            if op == "eq":
                return left == right
            if op == "ne":
                return left != right
            if op == "lt":
                return left < right
            if op == "le":
                return left <= right
            if op == "gt":
                return left > right
            return left >= right
        if op in {"add", "sub", "min", "max"}:
            values = [self.eval_ast(value, state, env, read_trace) for value in ast[1:]]
            if op == "add":
                return sum(values)
            if op == "sub":
                return values[0] - sum(values[1:])
            if op == "min":
                return min(values)
            return max(values)
        if op == "if":
            branch = ast[2] if self.eval_ast(ast[1], state, env, read_trace) else ast[3]
            return self.eval_ast(branch, state, env, read_trace)
        if op in {"forall", "exists", "sum"}:
            binders = ast[1]
            value_sets = [self.finite_values(type_id) for _, type_id in binders]
            results: list[Any] = []
            for values in itertools.product(*value_sets):
                nested = dict(env)
                nested.update({name: value for (name, _), value in zip(binders, values)})
                result = self.eval_ast(ast[2], state, nested, read_trace)
                if op == "forall" and not result:
                    return False
                if op == "exists" and result:
                    return True
                results.append(result)
            if op == "forall":
                return True
            if op == "exists":
                return False
            return sum(results)
        if op == "digest":
            value = self.eval_ast(ast[1], state, env, read_trace)
            return sha256_bytes(canonical_bytes(value))
        reject("IR-EVAL-OP", f"operator {op} is not executable in a state witness")
        raise AssertionError

    def substitute(self, value: Any, env: dict[str, tuple[str, Any]]) -> Any:
        if isinstance(value, list):
            if len(value) == 2 and value[0] == "param" and value[1] in env:
                type_id, concrete = env[value[1]]
                return self.literal_ast(type_id, concrete)
            return [self.substitute(child, env) for child in value]
        if isinstance(value, dict):
            return {key: self.substitute(child, env) for key, child in value.items()}
        return value

    def substitute_parameter_asts(self, value: Any, env: dict[str, Any]) -> Any:
        if isinstance(value, list):
            if len(value) == 2 and value[0] == "param" and value[1] in env:
                return copy.deepcopy(env[value[1]])
            return [self.substitute_parameter_asts(child, env) for child in value]
        if isinstance(value, dict):
            return {key: self.substitute_parameter_asts(child, env) for key, child in value.items()}
        return value

    def literal_value(self, ast: Any) -> Any:
        expect(isinstance(ast, list) and ast, "IR-LOCATION", str(ast))
        if ast[0] in {"enum", "id", "int", "string", "bool"}:
            return ast[-1]
        reject("IR-DYNAMIC-LOCATION", f"location key is not a literal: {ast}")
        raise AssertionError

    def location_id(self, variable_id: str, key_values: list[Any]) -> str:
        encoded = ",".join(json.dumps(value, sort_keys=True, separators=(",", ":")) for value in key_values)
        return f"{variable_id}[{encoded}]"

    def location_from_ast(self, ast: Any) -> str:
        expect(ast[0] in {"loc", "read"}, "IR-LOCATION", str(ast))
        variable_id = ast[1]
        key_values = [self.literal_value(key_ast) for key_ast in ast[2:]]
        location_id = self.location_id(variable_id, key_values)
        expect(location_id in self.location_table, "IR-LOCATION", f"unknown {location_id}")
        return location_id

    def collect_reads(self, value: Any, call_stack: tuple[str, ...] = ()) -> set[str]:
        reads: set[str] = set()
        if isinstance(value, list):
            if value and value[0] == "read":
                reads.add(self.location_from_ast(value))
            elif value and value[0] == "call":
                function_id = value[1]
                expect(function_id in self.functions, "IR-AST-CALL", function_id)
                expect(function_id not in call_stack, "IR-FUNCTION-CYCLE", function_id)
                function = self.functions[function_id]
                arguments = value[2:]
                for argument in arguments:
                    reads |= self.collect_reads(argument, call_stack)
                body = self.substitute_parameter_asts(
                    function["body_ast"],
                    {
                        parameter["name"]: argument
                        for parameter, argument in zip(function["parameters"], arguments)
                    },
                )
                reads |= self.collect_reads(body, (*call_stack, function_id))
                return reads
            for child in value:
                reads |= self.collect_reads(child, call_stack)
        elif isinstance(value, dict):
            for child in value.values():
                reads |= self.collect_reads(child, call_stack)
        return reads

    def concrete_writer_cd(self, writer_ast: list[Any]) -> list[Any]:
        expect(writer_ast and writer_ast[0] == "writer", "IR-WRITER-CD", str(writer_ast))
        writer = self.writers[writer_ast[1]]
        expect(
            len(writer_ast) - 2 == len(writer["index_names"]),
            "IR-WRITER-CD",
            writer_ast[1],
        )
        env = {
            name: (type_id, self.literal_value(argument))
            for name, type_id, argument in zip(
                writer["index_names"],
                writer["index_types"],
                writer_ast[2:],
            )
        }
        concrete = self.substitute(writer["consistency_domain_ast"], env)
        expect(
            self.infer(concrete, {}, self.CTX_METADATA) == self.CD_REF,
            "IR-WRITER-CD",
            writer_ast[1],
        )
        return concrete

    def expand_locations(self) -> None:
        for variable_id, entry in self.variables.items():
            value_sets = [self.finite_values(type_id) for type_id in entry["key_types"]]
            for values in itertools.product(*value_sets):
                typed_env = {
                    name: (type_id, value)
                    for name, type_id, value in zip(entry["key_names"], entry["key_types"], values)
                }
                owner = self.substitute(entry["owner_ast"], typed_env)
                cd = self.substitute(entry["consistency_domain_ast"], typed_env)
                shard = self.substitute(entry["transaction_shard_ast"], typed_env)
                init = self.substitute(entry["init_ast"], typed_env)
                self.infer(owner, {}, self.CTX_METADATA)
                self.infer(cd, {}, self.CTX_METADATA)
                self.infer(shard, {}, self.CTX_METADATA)
                self.infer(init, {}, self.CTX_INIT)
                expect(
                    canonical_bytes(self.concrete_writer_cd(owner)) == canonical_bytes(cd),
                    "IR-WRITER-CD",
                    f"{variable_id}{values}",
                )
                location_id = self.location_id(variable_id, list(values))
                expect(location_id not in self.location_table, "IR-LOCATION", location_id)
                self.location_table[location_id] = {
                    "id": location_id,
                    "variable": variable_id,
                    "keys": list(values),
                    "value_type": entry["value_type"],
                    "owner_ast": owner,
                    "consistency_domain_ast": cd,
                    "transaction_shard_ast": shard,
                    "storage_class": entry["storage_class"],
                    "authority_relevant": entry["authority_relevant"],
                    "init_ast": init,
                }

    def parameter_products(
        self,
        parameters: list[dict[str, Any]],
        instance_scope: dict[str, Any],
        owner: str,
    ) -> Iterable[dict[str, tuple[str, Any]]]:
        env_types = self.parameter_env(parameters, owner)
        mode = instance_scope["mode"]
        if mode == "full_product":
            expect(
                "catalog_rows" not in instance_scope and "scope_nonclaim" not in instance_scope,
                "IR-INSTANCE",
                f"{owner} full product has catalog fields",
            )
            rows: Iterable[dict[str, Any]] = (
                dict(zip(env_types, values))
                for values in itertools.product(
                    *(self.finite_values(type_id) for type_id in env_types.values())
                )
            )
            candidate_count = 1
            for type_id in env_types.values():
                candidate_count *= len(self.finite_values(type_id))
        elif mode == "catalog":
            rows = instance_scope["catalog_rows"]
            candidate_count = len(instance_scope["catalog_rows"])
        else:
            reject("IR-INSTANCE", f"{owner} mode {mode}")
        expect(
            candidate_count <= self.bounds["MaxInstanceCandidates"],
            "IR-INSTANCE-BOUND",
            f"{owner}: {candidate_count}",
        )
        seen: set[bytes] = set()
        selected = 0
        for row in rows:
            expect(set(row) == set(env_types), "IR-INSTANCE", f"{owner} row keys")
            typed: dict[str, tuple[str, Any]] = {}
            for name, type_id in env_types.items():
                value = row[name]
                expect(value in self.finite_values(type_id), "IR-INSTANCE", f"{owner}.{name}={value}")
                typed[name] = (type_id, value)
            key = canonical_bytes(row)
            expect(key not in seen, "IR-INSTANCE", f"duplicate {owner} row")
            seen.add(key)
            selected += 1
            yield typed
        expect(selected > 0, "IR-INSTANCE", f"{owner} selects no instances")

    def instance_suffix(self, env: dict[str, tuple[str, Any]]) -> str:
        return ",".join(f"{name}={value}" for name, (_, value) in env.items())

    def validate_update_types(self, updates: list[dict[str, Any]], env_types: dict[str, str]) -> None:
        targets: set[str] = set()
        for update in updates:
            expect(
                self.infer(update["target"], env_types, self.CTX_LOCATION) == self.LOCATION_REF,
                "IR-UPDATE",
                "target",
            )
            target_variable = update["target"][1]
            expected_type = self.variables[target_variable]["value_type"]
            actual_type = self.infer(update["value_ast"], env_types, self.CTX_ACTION)
            expect(actual_type == expected_type, "IR-UPDATE", f"{target_variable}: {actual_type}")
            target_key = json.dumps(update["target"], sort_keys=True, separators=(",", ":"))
            expect(target_key not in targets, "IR-DUPLICATE-WRITE", target_key)
            targets.add(target_key)

    def expand_actions(self) -> list[dict[str, Any]]:
        expanded: list[dict[str, Any]] = []
        for action_id, action in self.actions.items():
            if action["work_class"] == "WORK-PROVIDER-FAULT":
                expect(
                    action["instance_scope"]["mode"] == "full_product",
                    "IR-INSTANCE-POLICY",
                    f"{action_id} provider fault must cover the full product",
                )
            env_types = self.parameter_env(action["parameters"], f"action {action_id}")
            expect(
                self.infer(action["writer_ast"], env_types, self.CTX_METADATA) == self.WRITER_REF,
                "IR-ACTION",
                action_id,
            )
            expect(
                self.infer(action["guard_ast"], env_types, self.CTX_ACTION) == self.BOOL,
                "IR-ACTION",
                action_id,
            )
            self.validate_update_types(action["updates"], env_types)
            expect(
                self.infer(action["linearization_ast"], env_types, self.CTX_LOCATION)
                == self.LOCATION_REF,
                "IR-ACTION",
                action_id,
            )
            self.infer(action["recovery_ast"], env_types, self.CTX_ACTION)
            expect(
                self.infer(action["rank_delta_ast"], env_types, self.CTX_ACTION) == self.INT,
                "IR-ACTION",
                action_id,
            )
            for env in self.parameter_products(action["parameters"], action["instance_scope"], f"action {action_id}"):
                guard = self.substitute(action["guard_ast"], env)
                updates = self.substitute(action["updates"], env)
                writer = self.substitute(action["writer_ast"], env)
                linearization = self.substitute(action["linearization_ast"], env)
                recovery = self.substitute(action["recovery_ast"], env)
                rank_delta = self.substitute(action["rank_delta_ast"], env)
                self.validate_variant_field_safety(guard, {}, self.CTX_ACTION)
                guard_facts = self.positive_tag_facts(guard)
                for update in updates:
                    self.validate_variant_field_safety(
                        update["value_ast"], {}, self.CTX_ACTION, guard_facts
                    )
                self.validate_variant_field_safety(recovery, {}, self.CTX_ACTION, guard_facts)
                write_locations = [self.location_from_ast(update["target"]) for update in updates]
                expect(
                    len(write_locations) == len(set(write_locations)),
                    "IR-DUPLICATE-WRITE",
                    action_id,
                )
                linearization_location = self.location_from_ast(linearization)
                expect(
                    linearization_location in write_locations,
                    "IR-LINEARIZATION",
                    f"{action_id} linearization is not a write",
                )
                linearization_type = self.location_table[linearization_location]["value_type"]
                expect(
                    self.infer(recovery, {}, self.CTX_ACTION) == linearization_type,
                    "IR-RECOVERY",
                    f"{action_id} recovery successor type",
                )
                linearization_updates = [
                    update["value_ast"]
                    for update, location in zip(updates, write_locations)
                    if location == linearization_location
                ]
                expect(len(linearization_updates) == 1, "IR-LINEARIZATION", action_id)
                if action["crash_class"] in {"atomic", "provider_atomic"}:
                    expect(
                        canonical_bytes(linearization_updates[0]) == canonical_bytes(recovery),
                        "IR-RECOVERY",
                        f"{action_id} recovery differs from atomic successor",
                    )
                reads = self.collect_reads(guard)
                reads |= self.collect_reads([update["value_ast"] for update in updates])
                instance_id = f"{action_id}::{self.instance_suffix(env)}"
                expanded.append(
                    {
                        "id": instance_id,
                        "template_id": action_id,
                        "kind": "direct",
                        "parameters": {name: value for name, (_, value) in env.items()},
                        "semantic_actor": action["semantic_actor"],
                        "writer_ast": writer,
                        "guard_ast": guard,
                        "reads": sorted(reads),
                        "writes": sorted(write_locations),
                        "updates": updates,
                        "linearization_ast": linearization,
                        "linearization_location": linearization_location,
                        "crash_class": action["crash_class"],
                        "recovery_ast": recovery,
                        "refinement": action["refinement"],
                        "work_class": action["work_class"],
                        "rank_delta_ast": rank_delta,
                        "blocker_ids": action["blocker_ids"],
                    }
                )
        return expanded

    def txn_slot_read(self, txn: dict[str, Any]) -> list[Any]:
        return ["read", txn["slot_variable"], *txn["slot_keys_ast"]]

    def txn_state(self, tag: str, fields: dict[str, Any]) -> list[Any]:
        return ["variant", "TxnState", tag, fields]

    def expand_transactions(self) -> list[dict[str, Any]]:
        expanded: list[dict[str, Any]] = []
        used_slots: dict[tuple[str, int], str] = {}
        used_txn_ids: dict[Any, str] = {}
        used_outcome_ids: dict[Any, str] = {}
        used_tombstone_ids: dict[Any, str] = {}
        for txn_id, txn in self.txns.items():
            expect(
                txn["instance_scope"]["mode"] == "catalog",
                "IR-INSTANCE-POLICY",
                f"{txn_id} must use an explicit bounded invocation catalog",
            )
            env_types = self.parameter_env(txn["parameters"], f"transaction {txn_id}")
            expect(txn["slot_variable"] in self.variables, "IR-TXN", f"{txn_id} slot")
            slot_variable = self.variables[txn["slot_variable"]]
            expect(slot_variable["value_type"] == "TxnState", "IR-TXN", f"{txn_id} slot type")
            expect(len(txn["slot_keys_ast"]) == len(slot_variable["key_types"]), "IR-TXN", txn_id)
            for key_ast, key_type in zip(txn["slot_keys_ast"], slot_variable["key_types"]):
                expect(
                    self.infer(key_ast, env_types, self.CTX_STATIC) == key_type,
                    "IR-TXN",
                    f"{txn_id} slot key",
                )
            expect(
                self.infer(txn["expected_slot_generation_ast"], env_types, self.CTX_STATIC)
                == self.INT,
                "IR-TXN",
                f"{txn_id} expected slot generation",
            )
            expect(self.infer(txn["txn_id_ast"], env_types, self.CTX_STATIC) == "TxnID", "IR-TXN", f"{txn_id} txn id")
            expect(self.infer(txn["outcome_id_ast"], env_types, self.CTX_STATIC) == "OutcomeID", "IR-TXN", f"{txn_id} outcome")
            expect(self.infer(txn["tombstone_id_ast"], env_types, self.CTX_STATIC) == "TombstoneID", "IR-TXN", f"{txn_id} tombstone")
            expect(self.infer(txn["plan_ast"], env_types, self.CTX_ACTION) == "TxnPlan", "IR-TXN", f"{txn_id} plan")
            expect(self.infer(txn["prepare_guard_ast"], env_types, self.CTX_ACTION) == self.BOOL, "IR-TXN", txn_id)
            expect(self.infer(txn["decision_ast"], env_types, self.CTX_ACTION) == self.BOOL, "IR-TXN", txn_id)
            expect(self.infer(txn["abort_reason_ast"], env_types, self.CTX_STATIC) == "AbortReason", "IR-TXN", txn_id)
            expect(self.infer(txn["retire_guard_ast"], env_types, self.CTX_ACTION) == self.BOOL, "IR-TXN", txn_id)
            expect(self.infer(txn["reuse_guard_ast"], env_types, self.CTX_ACTION) == self.BOOL, "IR-TXN", txn_id)
            expect(self.infer(txn["rank_delta_ast"], env_types, self.CTX_ACTION) == self.INT, "IR-TXN", txn_id)
            self.validate_update_types(txn["commit_updates"], env_types)
            for projection in txn["projections"]:
                self.validate_update_types(projection["updates"], env_types)
                for update in projection["updates"]:
                    variable = self.variables[update["target"][1]]
                    expect(variable["storage_class"] == projection["target_storage_class"], "IR-TXN-PROJECTION", projection["id"])

            for env in self.parameter_products(txn["parameters"], txn["instance_scope"], f"transaction {txn_id}"):
                owner = f"{txn_id}::{self.instance_suffix(env)}"
                slot = self.location_from_ast(
                    self.substitute(["loc", txn["slot_variable"], *txn["slot_keys_ast"]], env)
                )
                concrete_slot_generation = self.literal_value(
                    self.substitute(txn["expected_slot_generation_ast"], env)
                )
                expect(
                    isinstance(concrete_slot_generation, int) and concrete_slot_generation >= 0,
                    "IR-TXN-IDENTITY",
                    f"slot generation {concrete_slot_generation}",
                )
                concrete_txn = self.literal_value(self.substitute(txn["txn_id_ast"], env))
                concrete_outcome = self.literal_value(self.substitute(txn["outcome_id_ast"], env))
                concrete_tombstone = self.literal_value(self.substitute(txn["tombstone_id_ast"], env))
                for value, table, label in (
                    ((slot, concrete_slot_generation), used_slots, "slot/generation"),
                    (concrete_txn, used_txn_ids, "TxnID"),
                    (concrete_outcome, used_outcome_ids, "OutcomeID"),
                    (concrete_tombstone, used_tombstone_ids, "TombstoneID"),
                ):
                    expect(value not in table, "IR-TXN-IDENTITY", f"{label} {value}: {table.get(value)} / {owner}")
                    table[value] = owner
                expanded.extend(self.expand_one_transaction(txn_id, txn, env))
        return expanded

    def expand_one_transaction(
        self,
        txn_id: str,
        txn: dict[str, Any],
        env: dict[str, tuple[str, Any]],
    ) -> list[dict[str, Any]]:
        slot_target = ["loc", txn["slot_variable"], *txn["slot_keys_ast"]]
        slot_read = self.txn_slot_read(txn)
        slot_generation = txn["expected_slot_generation_ast"]
        txn_literal = ["string", txn_id]
        plan = txn["plan_ast"]
        txn_identity = txn["txn_id_ast"]
        outcome = txn["outcome_id_ast"]
        tombstone = txn["tombstone_id_ast"]
        prepared_epoch = ["read", "monitor_epoch", ["param", "node"], ["param", "shard"]]
        cursor_zero = ["int", 0]
        decision_commit = ["enum", "DecisionTag", "Commit"]
        decision_abort = ["enum", "DecisionTag", "Abort"]
        publication_guard = self.generated_publication_guard(txn)
        effective_prepare_guard = ["and", txn["prepare_guard_ast"], publication_guard]
        effective_decision = ["and", txn["decision_ast"], publication_guard]

        prepared = self.txn_state(
            "Prepared",
            {
                "slot_generation": slot_generation,
                "txn_id": txn_identity,
                "txn_kind": txn_literal,
                "plan": plan,
                "prepared_epoch": prepared_epoch,
            },
        )
        commit_intent = self.txn_state(
            "CommitIntent",
            {
                "slot_generation": slot_generation,
                "txn_id": txn_identity,
                "txn_kind": txn_literal,
                "plan": plan,
                "outcome_id": outcome,
                "projection_cursor": cursor_zero,
            },
        )
        abort_intent = self.txn_state(
            "AbortIntent",
            {
                "slot_generation": slot_generation,
                "txn_id": txn_identity,
                "txn_kind": txn_literal,
                "plan": plan,
                "outcome_id": outcome,
                "reason": txn["abort_reason_ast"],
                "projection_cursor": cursor_zero,
            },
        )

        phases: list[tuple[str, list[Any], list[dict[str, Any]], list[Any]]] = []
        phases.append(
            (
                "Begin",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Vacant"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    effective_prepare_guard,
                ],
                [{"target": slot_target, "value_ast": prepared}],
                prepared,
            )
        )

        retired = self.txn_state(
            "Retired",
            {
                "slot_generation": slot_generation,
                "txn_id": txn_identity,
                "tombstone_id": tombstone,
            },
        )
        phases.append(
            (
                "Retire",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Complete"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    ["eq", ["field", slot_read, "txn_id"], txn_identity],
                    ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                    ["eq", ["field", slot_read, "outcome_id"], outcome],
                    txn["retire_guard_ast"],
                ],
                [{"target": slot_target, "value_ast": retired}],
                retired,
            )
        )
        vacant_next = self.txn_state(
            "Vacant",
            {"slot_generation": ["add", slot_generation, ["int", 1]]},
        )
        phases.append(
            (
                "Reuse",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Retired"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    ["eq", ["field", slot_read, "txn_id"], txn_identity],
                    ["eq", ["field", slot_read, "tombstone_id"], tombstone],
                    txn["reuse_guard_ast"],
                ],
                [{"target": slot_target, "value_ast": vacant_next}],
                vacant_next,
            )
        )
        phases.append(
            (
                "CommitDecision",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Prepared"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    ["eq", ["field", slot_read, "txn_id"], txn_identity],
                    ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                    ["eq", ["field", slot_read, "plan"], plan],
                    ["eq", ["field", slot_read, "prepared_epoch"], prepared_epoch],
                    effective_decision,
                ],
                [*txn["commit_updates"], {"target": slot_target, "value_ast": commit_intent}],
                commit_intent,
            )
        )
        phases.append(
            (
                "AbortDecision",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Prepared"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    ["eq", ["field", slot_read, "txn_id"], txn_identity],
                    ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                    ["eq", ["field", slot_read, "plan"], plan],
                    [
                        "or",
                        ["ne", ["field", slot_read, "prepared_epoch"], prepared_epoch],
                        ["not", effective_decision],
                    ],
                ],
                [{"target": slot_target, "value_ast": abort_intent}],
                abort_intent,
            )
        )

        projection_count = len(txn["projections"])
        for decision_tag, intent_tag, decision_literal in (
            ("Commit", "CommitIntent", decision_commit),
            ("Abort", "AbortIntent", decision_abort),
        ):
            applying = self.txn_state(
                "Applying",
                {
                    "slot_generation": slot_generation,
                    "txn_id": txn_identity,
                    "txn_kind": txn_literal,
                    "plan": plan,
                    "decision": decision_literal,
                    "outcome_id": outcome,
                    "projection_cursor": cursor_zero,
                },
            )
            phases.append(
                (
                    f"BeginApplying{decision_tag}",
                    [
                        "and",
                        ["eq", ["tag", slot_read], ["string", intent_tag]],
                        ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                        ["eq", ["field", slot_read, "txn_id"], txn_identity],
                        ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                        ["eq", ["field", slot_read, "plan"], plan],
                        ["eq", ["field", slot_read, "outcome_id"], outcome],
                    ],
                    [{"target": slot_target, "value_ast": applying}],
                    applying,
                )
            )

        for index, projection in enumerate(txn["projections"]):
            applying_next = self.txn_state(
                "Applying",
                {
                    "slot_generation": slot_generation,
                    "txn_id": txn_identity,
                    "txn_kind": txn_literal,
                    "plan": plan,
                    "decision": ["field", slot_read, "decision"],
                    "outcome_id": outcome,
                    "projection_cursor": ["int", index + 1],
                },
            )
            phases.append(
                (
                    f"ApplyProjection{index:03d}.{projection['id']}",
                    [
                        "and",
                        ["eq", ["tag", slot_read], ["string", "Applying"]],
                        ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                        ["eq", ["field", slot_read, "txn_id"], txn_identity],
                        ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                        ["eq", ["field", slot_read, "plan"], plan],
                        ["eq", ["field", slot_read, "outcome_id"], outcome],
                        ["eq", ["field", slot_read, "projection_cursor"], ["int", index]],
                    ],
                    [*projection["updates"], {"target": slot_target, "value_ast": applying_next}],
                    applying_next,
                )
            )

        complete = self.txn_state(
            "Complete",
            {
                "slot_generation": slot_generation,
                "txn_id": txn_identity,
                "txn_kind": txn_literal,
                "decision": ["field", slot_read, "decision"],
                "outcome_id": outcome,
            },
        )
        phases.append(
            (
                "Complete",
                [
                    "and",
                    ["eq", ["tag", slot_read], ["string", "Applying"]],
                    ["eq", ["field", slot_read, "slot_generation"], slot_generation],
                    ["eq", ["field", slot_read, "txn_id"], txn_identity],
                    ["eq", ["field", slot_read, "txn_kind"], txn_literal],
                    ["eq", ["field", slot_read, "plan"], plan],
                    ["eq", ["field", slot_read, "outcome_id"], outcome],
                    ["eq", ["field", slot_read, "projection_cursor"], ["int", projection_count]],
                ],
                [{"target": slot_target, "value_ast": complete}],
                complete,
            )
        )

        expanded: list[dict[str, Any]] = []
        for phase_name, guard, updates, recovery in phases:
            substituted_guard = self.substitute(guard, env)
            substituted_updates = self.substitute(updates, env)
            substituted_recovery = self.substitute(recovery, env)
            substituted_slot = self.substitute(slot_target, env)
            expect(
                self.infer(substituted_guard, {}, self.CTX_ACTION) == self.BOOL,
                "IR-TXN",
                f"{txn_id}.{phase_name} guard",
            )
            self.validate_variant_field_safety(substituted_guard, {}, self.CTX_ACTION)
            guard_facts = self.positive_tag_facts(substituted_guard)
            for update in substituted_updates:
                expect(
                    self.infer(update["target"], {}, self.CTX_LOCATION) == self.LOCATION_REF,
                    "IR-TXN",
                    f"{txn_id}.{phase_name} target",
                )
                expected_type = self.variables[update["target"][1]]["value_type"]
                expect(
                    self.infer(update["value_ast"], {}, self.CTX_ACTION) == expected_type,
                    "IR-TXN",
                    f"{txn_id}.{phase_name} value",
                )
                self.validate_variant_field_safety(
                    update["value_ast"], {}, self.CTX_ACTION, guard_facts
                )
            write_locations = [self.location_from_ast(update["target"]) for update in substituted_updates]
            expect(
                len(write_locations) == len(set(write_locations)),
                "IR-DUPLICATE-WRITE",
                f"{txn_id}.{phase_name}",
            )
            linearization_location = self.location_from_ast(substituted_slot)
            expect(
                linearization_location in write_locations,
                "IR-LINEARIZATION",
                f"{txn_id}.{phase_name}",
            )
            expect(
                self.infer(substituted_recovery, {}, self.CTX_ACTION)
                == self.location_table[linearization_location]["value_type"],
                "IR-RECOVERY",
                f"{txn_id}.{phase_name}",
            )
            self.validate_variant_field_safety(
                substituted_recovery, {}, self.CTX_ACTION, guard_facts
            )
            linearization_updates = [
                update["value_ast"]
                for update, location in zip(substituted_updates, write_locations)
                if location == linearization_location
            ]
            expect(len(linearization_updates) == 1, "IR-LINEARIZATION", f"{txn_id}.{phase_name}")
            expect(
                canonical_bytes(linearization_updates[0]) == canonical_bytes(substituted_recovery),
                "IR-RECOVERY",
                f"{txn_id}.{phase_name} recovery differs from atomic successor",
            )
            reads = self.collect_reads(substituted_guard)
            reads |= self.collect_reads([update["value_ast"] for update in substituted_updates])
            instance_id = f"TXN.{txn_id}.{phase_name}::{self.instance_suffix(env)}"
            writer = self.location_table[self.location_from_ast(substituted_slot)]["owner_ast"]
            expanded.append(
                {
                    "id": instance_id,
                    "template_id": f"TXN.{txn_id}.{phase_name}",
                    "transaction_kind": txn_id,
                    "kind": "transaction",
                    "parameters": {name: value for name, (_, value) in env.items()},
                    "semantic_actor": f"TXN-{txn_id}",
                    "writer_ast": writer,
                    "guard_ast": substituted_guard,
                    "reads": sorted(reads),
                    "writes": sorted(write_locations),
                    "updates": substituted_updates,
                    "linearization_ast": substituted_slot,
                    "linearization_location": linearization_location,
                    "crash_class": "atomic",
                    "recovery_ast": substituted_recovery,
                    "refinement": "REF-TXN-INTERNAL",
                    "work_class": "WORK-TXN-RECOVERY",
                    "rank_delta_ast": self.substitute(txn["rank_delta_ast"], env),
                    "blocker_ids": txn["blocker_ids"],
                }
            )
        return expanded

    def validate_action_ownership_and_frames(self, actions: list[dict[str, Any]]) -> None:
        all_location_ids = sorted(self.location_table)
        max_writes = self.bounds.get("MaxTxnLocations", 0)
        expect(max_writes > 0, "IR-BOUND", "MaxTxnLocations")
        for action in actions:
            expect(len(action["writes"]) <= max_writes, "IR-TXN-FOOTPRINT", action["id"])
            writer_key = canonical_bytes(action["writer_ast"])
            relevant_locations = set(action["writes"]) | set(action["reads"])
            cds: set[bytes] = set()
            shards: set[bytes] = set()
            for location_id in action["writes"]:
                location = self.location_table[location_id]
                expect(canonical_bytes(location["owner_ast"]) == writer_key, "IR-OWNER", f"{action['id']} -> {location_id}")
            for location_id in relevant_locations:
                location = self.location_table[location_id]
                cds.add(canonical_bytes(location["consistency_domain_ast"]))
                shards.add(canonical_bytes(location["transaction_shard_ast"]))
            expect(len(cds) <= 1, "IR-CD", f"cross-CD {action['id']}")
            expect(len(shards) <= 1, "IR-SHARD", f"cross-shard {action['id']}")
            writer_class = self.writers[action["writer_ast"][1]]["class"]
            expected_classes = {
                "atomic": {"monitor"},
                "provider_atomic": {"cpu_provider", "time_provider", "quorum_provider"},
                "environment_input": {"environment"},
            }
            expect(
                writer_class in expected_classes[action["crash_class"]],
                "IR-CRASH-WRITER",
                f"{action['id']}: {action['crash_class']}/{writer_class}",
            )
            for update in action["updates"]:
                target_location = self.location_from_ast(update["target"])
                target = self.location_table[target_location]
                if target["storage_class"] != "provider_immutable_fact":
                    continue
                target_read = ["read", update["target"][1], *update["target"][2:]]
                expect(
                    self.positive_tag_facts(action["guard_ast"]).get(
                        canonical_bytes(target_read)
                    )
                    == "Vacant",
                    "IR-PROVIDER-WRITE-ONCE",
                    f"{action['id']} lacks Vacant guard for {target_location}",
                )
                value_ast = update["value_ast"]
                expect(
                    value_ast[0] == "variant" and value_ast[2] != "Vacant",
                    "IR-PROVIDER-WRITE-ONCE",
                    f"{action['id']} does not terminalize {target_location}",
                )
            writes = set(action["writes"])
            unchanged = [loc for loc in all_location_ids if loc not in writes]
            action["unchanged_rule"] = "AllConcreteLocationsMinusWrites"
            action["unchanged_count"] = len(unchanged)
            action["unchanged_locations"] = unchanged
            action["frame_sha256"] = sha256_bytes(canonical_bytes(unchanged))

    def validate_formulas_and_proofs(self, expanded_actions: list[dict[str, Any]]) -> None:
        template_ids = set(self.actions)
        template_ids |= {action["template_id"] for action in expanded_actions}
        formula_ids = set(self.provider_formulas) | set(self.invariants) | set(self.progress)
        valid_provider_consumers = (
            set(self.proofs)
            | set(self.invariants)
            | set(self.progress)
            | template_ids
        )
        concrete_provider_writers = {action["writer_ast"][1] for action in expanded_actions}
        for provider_id, provider in self.provider_formulas.items():
            expect(
                provider["provider_writer"] in concrete_provider_writers,
                "IR-PROVIDER",
                f"{provider_id} has no concrete provider action",
            )
            for consumer in provider["consumers"]:
                expect(
                    consumer in valid_provider_consumers,
                    "IR-PROVIDER",
                    f"{provider_id} unknown consumer {consumer}",
                )
        for invariant_id, invariant in self.invariants.items():
            context = self.CTX_STATE if invariant["scope"] == "state" else self.CTX_TEMPORAL
            expect(
                self.infer(invariant["formula_ast"], {}, context) == self.BOOL,
                "IR-INVARIANT",
                invariant_id,
            )
            self.validate_variant_field_safety(invariant["formula_ast"], {}, context)
            for action_id in invariant["preserved_by"]:
                expect(action_id in template_ids, "IR-INVARIANT", f"{invariant_id} unknown {action_id}")
            expect(
                template_ids <= set(invariant["preserved_by"]),
                "IR-INVARIANT-COVERAGE",
                f"{invariant_id}: {sorted(template_ids - set(invariant['preserved_by']))}",
            )
        for progress_id, progress in self.progress.items():
            expect(self.infer(progress["premise_ast"], {}, self.CTX_STATE) == self.BOOL, "IR-PROGRESS", progress_id)
            expect(self.infer(progress["temporal_formula_ast"], {}, self.CTX_TEMPORAL) == self.BOOL, "IR-PROGRESS", progress_id)
            self.validate_variant_field_safety(progress["premise_ast"], {}, self.CTX_STATE)
            self.validate_variant_field_safety(
                progress["temporal_formula_ast"], {}, self.CTX_TEMPORAL
            )
            expect(progress["rank_function"] in self.functions, "IR-PROGRESS", progress_id)
            for action_id in progress["fair_actions"]:
                expect(action_id in template_ids, "IR-PROGRESS", f"{progress_id} unknown {action_id}")
                instances = [
                    action for action in expanded_actions if action["template_id"] == action_id
                ]
                expect(bool(instances), "IR-PROGRESS", f"{progress_id} empty fair action {action_id}")
                for action in instances:
                    expect(
                        self.eval_int(action["rank_delta_ast"]) < 0,
                        "IR-RANK",
                        f"{progress_id}/{action['id']} is not decreasing",
                    )
        for refinement_id, refinement in self.refinements.items():
            expect(refinement["target_import"] in self.imports, "IR-REFINEMENT", refinement_id)
            expect(self.infer(refinement["state_mapping_ast"], {}, self.CTX_STATE) == self.BOOL, "IR-REFINEMENT", refinement_id)
            expect(self.infer(refinement["simulation_ast"], {}, self.CTX_TEMPORAL) == self.BOOL, "IR-REFINEMENT", refinement_id)
            self.validate_variant_field_safety(refinement["state_mapping_ast"], {}, self.CTX_STATE)
            self.validate_variant_field_safety(refinement["simulation_ast"], {}, self.CTX_TEMPORAL)
            for action_id in refinement["action_mapping"]:
                expect(action_id in template_ids, "IR-REFINEMENT", f"{refinement_id} unknown {action_id}")

        graph: dict[str, list[str]] = {}
        declared_claims = set(self.source["claim_boundary"]["claims"])
        proven_claims: set[str] = set()
        for proof_id, proof in self.proofs.items():
            graph[proof_id] = proof["predecessors"]
            for predecessor in proof["predecessors"]:
                expect(predecessor in self.proofs, "IR-PROOF", f"{proof_id} predecessor")
            for formula_id in proof["formula_ids"]:
                expect(formula_id in formula_ids, "IR-PROOF", f"{proof_id} formula {formula_id}")
            for action_id in proof["action_ids"]:
                expect(action_id in template_ids, "IR-PROOF", f"{proof_id} action {action_id}")
            for claim_id in proof["claim_ids"]:
                expect(claim_id in declared_claims, "IR-PROOF", f"{proof_id} claim {claim_id}")
                proven_claims.add(claim_id)
        self.require_acyclic(graph, "IR-PROOF-CYCLE")
        expect(declared_claims <= proven_claims, "IR-PROOF", f"unproven claims {sorted(declared_claims - proven_claims)}")

    def require_acyclic(self, graph: dict[str, list[str]], reject_id: str) -> None:
        indegree = {node: 0 for node in graph}
        successors: dict[str, list[str]] = defaultdict(list)
        for node, predecessors in graph.items():
            indegree[node] = len(predecessors)
            for predecessor in predecessors:
                successors[predecessor].append(node)
        ready = deque(sorted(node for node, degree in indegree.items() if degree == 0))
        visited: list[str] = []
        while ready:
            node = ready.popleft()
            visited.append(node)
            for successor in sorted(successors[node]):
                indegree[successor] -= 1
                if indegree[successor] == 0:
                    ready.append(successor)
        expect(len(visited) == len(graph), reject_id, f"{reject_id} graph has a cycle")

    def validate_imports(self) -> None:
        for import_id, entry in self.imports.items():
            path = (self.root / entry["path"]).resolve()
            expect(path.is_file(), "IR-IMPORT", f"{import_id} path {path}")
            raw_file = read_bytes(path)
            self.import_bytes[import_id] = raw_file
            expect(sha256_bytes(raw_file) == entry["raw_sha256"], "IR-IMPORT-HASH", import_id)
            raw_slice = entry["raw_slice_text"].encode("utf-8")
            expect(raw_slice in raw_file, "IR-IMPORT-SLICE", import_id)
            expect(sha256_bytes(raw_slice) == entry["raw_slice_sha256"], "IR-IMPORT-SLICE", import_id)
            expect(
                sha256_bytes(canonical_bytes(entry["formula_ast"])) == entry["canonical_ast_sha256"],
                "IR-IMPORT-AST",
                import_id,
            )
            expect(
                self.infer(entry["formula_ast"], {}, self.CTX_TEMPORAL) == self.BOOL,
                "IR-IMPORT-AST",
                import_id,
            )
            self.validate_variant_field_safety(entry["formula_ast"], {}, self.CTX_TEMPORAL)

    def validate_blocker_and_mutation_coverage(self) -> None:
        expected_blockers = set(self.disposition["canonical_findings"])
        actual_blockers = set(self.source["blocker_coverage"])
        expect(actual_blockers == expected_blockers, "IR-BLOCKER-COVERAGE", str(sorted(expected_blockers ^ actual_blockers)))
        if self.source["status"] != "draft":
            pending = {
                blocker_id: refs
                for blocker_id, refs in self.source["blocker_coverage"].items()
                if any(ref.startswith("PENDING-") for ref in refs)
            }
            expect(not pending, "IR-BLOCKER-COVERAGE", f"pending review-candidate coverage: {sorted(pending)}")
        valid_targets = (
            set(self.types)
            | set(self.variables)
            | set(self.objects)
            | set(self.functions)
            | set(self.txns)
            | set(self.actions)
            | set(self.provider_formulas)
            | set(self.invariants)
            | set(self.progress)
            | set(self.proofs)
            | set(self.witnesses)
            | set(self.source["claim_boundary"]["claims"])
            | {"materialize-r10.py", "r10-schema.json", "r10-source.json"}
        )
        reject_ids: set[str] = set()
        mutation_targets: set[str] = set()
        for mutation_id, mutation in self.mutations.items():
            expect(mutation["target_id"] in valid_targets, "IR-MUTATION", f"{mutation_id} target")
            mutation_targets.add(mutation["target_id"])
            reject_ids.update(mutation["expected_reject_ids"])
        expected_reject_families = {
            "IR-SCHEMA",
            "IR-FUNCTION-CYCLE",
            "IR-CD",
            "IR-TXN-IDENTITY",
            "IR-AST-CONTEXT",
            "IR-VARIANT-FIELD",
            "IR-DUPLICATE-WRITE",
            "IR-LINEARIZATION",
            "IR-AUTHORITY-CLASS",
            "IR-WRITER-CD",
            "IR-SHARD",
            "IR-EDGE",
            "IR-EDGE-COVERAGE",
            "IR-EDGE-POLICY",
            "IR-OBJECT-ALLOCATOR",
            "IR-OBJECT-CONSTRUCTOR",
            "IR-INSTANCE-POLICY",
            "IR-RECOVERY",
            "IR-PROVIDER-WRITE-ONCE",
            "IR-PROOF",
            "IR-INVARIANT-COVERAGE",
            "IR-WITNESS",
            "IR-WITNESS-DISABLED",
            "IR-WITNESS-FINAL",
        }
        expect(expected_reject_families <= reject_ids, "IR-MUTATION-COVERAGE", str(sorted(expected_reject_families - reject_ids)))
        if self.source["status"] != "draft":
            expect(len(self.mutations) >= len(expected_blockers), "IR-MUTATION-COVERAGE", "one mutation per blocker minimum")
            expect(bool(self.imports), "IR-IMPORT", "review candidate has no imports")
            expect(bool(mutation_targets), "IR-MUTATION-COVERAGE", "empty mutation targets")

    def validate_witnesses(self, expanded_actions: list[dict[str, Any]]) -> None:
        concrete_actions = {
            (
                action["template_id"],
                canonical_bytes(action["parameters"]),
            ): action
            for action in expanded_actions
        }
        for witness_id, witness in self.witnesses.items():
            override_targets: set[str] = set()
            for update in witness["initial_overrides"]:
                expect(update["target"][0] == "loc", "IR-WITNESS", witness_id)
                self.infer(update["target"], {}, self.CTX_LOCATION)
                location = self.location_from_ast(update["target"])
                expect(location not in override_targets, "IR-WITNESS", f"duplicate override {location}")
                expect(
                    self.location_table[location]["storage_class"] == "untrusted_input",
                    "IR-WITNESS",
                    f"{witness_id} cannot override protected state {location}",
                )
                override_targets.add(location)
                target_variable = update["target"][1]
                expect(self.infer(update["value_ast"], {}, self.CTX_STATE) == self.variables[target_variable]["value_type"], "IR-WITNESS", witness_id)
                self.validate_variant_field_safety(update["value_ast"], {}, self.CTX_STATE)
            for step_index, step in enumerate(witness["steps"]):
                key = (step["template_id"], canonical_bytes(step["parameters"]))
                expect(
                    key in concrete_actions,
                    "IR-WITNESS",
                    f"{witness_id} step {step_index} is not a concrete action",
                )
            expect(
                witness["invariant_scope"] == "all_state_invariants",
                "IR-WITNESS-INVARIANT-COVERAGE",
                witness_id,
            )
            expect(
                self.infer(witness["final_formula_ast"], {}, self.CTX_STATE) == self.BOOL,
                "IR-WITNESS",
                f"{witness_id} final formula",
            )
            self.validate_variant_field_safety(
                witness["final_formula_ast"], {}, self.CTX_STATE
            )
            self.execute_witness(witness_id, witness, concrete_actions)

    def execute_witness(
        self,
        witness_id: str,
        witness: dict[str, Any],
        concrete_actions: dict[tuple[str, bytes], dict[str, Any]],
    ) -> None:
        state: dict[str, Any] = {}
        for location_id in sorted(self.location_table):
            state[location_id] = self.eval_ast(
                self.location_table[location_id]["init_ast"], state, {}
            )
        override_values: dict[str, Any] = {}
        for update in witness["initial_overrides"]:
            location = self.location_from_ast(update["target"])
            override_values[location] = self.eval_ast(update["value_ast"], state, {})
        state.update(override_values)

        invariant_ids = sorted(
            invariant_id
            for invariant_id, invariant in self.invariants.items()
            if invariant["scope"] == "state"
        )
        expect(bool(invariant_ids), "IR-WITNESS-INVARIANT-COVERAGE", witness_id)
        for invariant_id in invariant_ids:
            expect(
                self.eval_ast(self.invariants[invariant_id]["formula_ast"], state, {}) is True,
                "IR-WITNESS-INVARIANT",
                f"{witness_id} initial {invariant_id}",
            )

        step_results: list[dict[str, Any]] = []
        for index, step in enumerate(witness["steps"]):
            action = concrete_actions[
                (step["template_id"], canonical_bytes(step["parameters"]))
            ]
            reads: set[str] = set()
            enabled = self.eval_ast(action["guard_ast"], state, {}, reads)
            expect(
                enabled is True,
                "IR-WITNESS-DISABLED",
                f"{witness_id} step {index} {action['id']}",
            )
            next_values: dict[str, Any] = {}
            for update in action["updates"]:
                location = self.location_from_ast(update["target"])
                expect(location not in next_values, "IR-WITNESS", f"duplicate write {location}")
                next_values[location] = self.eval_ast(
                    update["value_ast"], state, {}, reads
                )
            expect(
                set(next_values) == set(action["writes"]),
                "IR-WITNESS-FRAME",
                action["id"],
            )
            expect(
                reads <= set(action["reads"]),
                "IR-WITNESS-READSET",
                f"{action['id']}: {sorted(reads - set(action['reads']))}",
            )
            state.update(next_values)
            for invariant_id in invariant_ids:
                expect(
                    self.eval_ast(self.invariants[invariant_id]["formula_ast"], state, {})
                    is True,
                    "IR-WITNESS-INVARIANT",
                    f"{witness_id} step {index} {invariant_id}",
                )
            step_results.append(
                {
                    "index": index,
                    "action_id": action["id"],
                    "read_count": len(reads),
                    "write_count": len(next_values),
                    "state_sha256": sha256_bytes(canonical_bytes(state)),
                }
            )
        expect(
            self.eval_ast(witness["final_formula_ast"], state, {}) is True,
            "IR-WITNESS-FINAL",
            witness_id,
        )
        self.witness_results.append(
            {
                "id": witness_id,
                "status": "executed",
                "steps": step_results,
                "final_state_sha256": sha256_bytes(canonical_bytes(state)),
            }
        )

    def make_expanded(self, actions: list[dict[str, Any]]) -> dict[str, Any]:
        return {
            "schema_version": 2,
            "generator_version": "r10-materializer-2",
            "python_version": ".".join(str(part) for part in sys.version_info[:3]),
            "model_id": self.source["model_id"],
            "source_sha256": sha256_bytes(canonical_bytes(self.source)),
            "status": self.source["status"],
            "requirement": self.source["requirement"],
            "predecessor": self.source["predecessor"],
            "bounds": self.bounds,
            "counts": {
                "types": len(self.types),
                "objects": len(self.objects),
                "variables": len(self.variables),
                "concrete_locations": len(self.location_table),
                "transaction_kinds": len(self.txns),
                "direct_action_templates": len(self.actions),
                "concrete_actions": len(actions),
                "provider_formulas": len(self.provider_formulas),
                "invariants": len(self.invariants),
                "progress_properties": len(self.progress),
                "proof_nodes": len(self.proofs),
                "mutation_obligations": len(self.mutations),
                "witnesses": len(self.witnesses),
            },
            "locations": [self.location_table[key] for key in sorted(self.location_table)],
            "location_universe_sha256": sha256_bytes(canonical_bytes(sorted(self.location_table))),
            "types": list(self.types.values()),
            "consistency_domains": list(self.cds.values()),
            "writers": list(self.writers.values()),
            "objects": list(self.objects.values()),
            "variables": list(self.variables.values()),
            "functions": list(self.functions.values()),
            "transaction_kinds": list(self.txns.values()),
            "direct_action_templates": list(self.actions.values()),
            "actions": sorted(actions, key=lambda action: action["id"]),
            "provider_formulas": list(self.provider_formulas.values()),
            "invariants": list(self.invariants.values()),
            "progress_properties": list(self.progress.values()),
            "refinements": list(self.refinements.values()),
            "proof_nodes": list(self.proofs.values()),
            "imports": list(self.imports.values()),
            "mutation_obligations": list(self.mutations.values()),
            "witnesses": list(self.witnesses.values()),
            "witness_execution_results": self.witness_results,
            "blocker_coverage": self.source["blocker_coverage"],
            "claim_boundary": self.source["claim_boundary"],
        }


def render_markdown(source: dict[str, Any], expanded: dict[str, Any], lock: dict[str, Any]) -> str:
    counts = expanded["counts"]
    lines = [
        "# Dynamic Residency R10 Generated Review Projection",
        "",
        "This file is generated from `r10-source.json`; it is not a semantic source.",
        "",
        "## Identity",
        "",
        f"- Model: `{source['model_id']}`",
        f"- Status: `{source['status']}`",
        f"- Source SHA-256: `{lock['artifacts']['r10-source.json']}`",
        f"- Expanded SHA-256: `{lock['artifacts']['r10-expanded.json']}`",
        "",
        "## Counts",
        "",
    ]
    for key, value in counts.items():
        lines.append(f"- {key}: `{value}`")
    lines.extend(["", "## Claims", ""])
    lines.extend(f"- `{claim}`" for claim in source["claim_boundary"]["claims"])
    lines.extend(["", "## Nonclaims", ""])
    lines.extend(f"- `{claim}`" for claim in source["claim_boundary"]["nonclaims"])
    lines.extend(["", "## Blocker Coverage", ""])
    for blocker_id in sorted(source["blocker_coverage"]):
        refs = ", ".join(f"`{ref}`" for ref in source["blocker_coverage"][blocker_id])
        lines.append(f"- `{blocker_id}`: {refs}")
    lines.append("")
    return "\n".join(lines)


def atomic_replace(path: Path, content: bytes) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def fsync_directory(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def validate_hostile_evidence(
    source: dict[str, Any],
    evidence: dict[str, Any],
    input_hashes: dict[str, str],
) -> None:
    expect(evidence.get("status") == "ok", "IR-MUTATION-EVIDENCE", "hostile status")
    expect(evidence.get("base") == "accepted", "IR-MUTATION-EVIDENCE", "base")
    expect(
        evidence.get("inputs") == input_hashes,
        "IR-MUTATION-EVIDENCE",
        "hostile evidence is stale",
    )
    declared = {
        mutation["id"]: mutation["expected_reject_ids"]
        for mutation in source["mutation_obligations"]
    }
    expect(
        evidence.get("mutation_registry_sha256")
        == sha256_bytes(canonical_bytes(source["mutation_obligations"])),
        "IR-MUTATION-EVIDENCE",
        "mutation registry digest",
    )
    results = evidence.get("results", [])
    expect(
        evidence.get("case_count") == len(results) == len(declared),
        "IR-MUTATION-EVIDENCE",
        "mutation case count",
    )
    actual: dict[str, list[str]] = {}
    for result in results:
        expect(result.get("passed") is True, "IR-MUTATION-EVIDENCE", str(result.get("id")))
        case_id = result.get("id")
        expect(case_id not in actual, "IR-MUTATION-EVIDENCE", f"duplicate {case_id}")
        expect(
            result.get("actual_reject_id") == result.get("expected_reject_id"),
            "IR-MUTATION-EVIDENCE",
            str(case_id),
        )
        actual[case_id] = [result["actual_reject_id"]]
    expect(actual == declared, "IR-MUTATION-EVIDENCE", "registry/result mismatch")


def load_and_validate_source() -> tuple[
    bytes,
    bytes,
    bytes,
    bytes,
    dict[str, Any],
    dict[str, Any],
    SemanticModel,
]:
    schema_bytes = read_bytes(SCHEMA_PATH)
    source_bytes = read_bytes(SOURCE_PATH)
    materializer_bytes = read_bytes(Path(__file__).resolve())
    disposition_bytes = read_bytes(DISPOSITION_PATH)
    schema = parse_json_bytes(schema_bytes, str(SCHEMA_PATH))
    source = parse_json_bytes(source_bytes, str(SOURCE_PATH))
    disposition = parse_json_bytes(disposition_bytes, str(DISPOSITION_PATH))
    try:
        jsonschema.Draft202012Validator(schema).validate(source)
    except jsonschema.ValidationError as exc:
        path = ".".join(str(part) for part in exc.absolute_path)
        reject("IR-SCHEMA", f"{path}: {exc.message}")

    expect(source["status"] == "draft", "IR-STATUS-AUTHORITY", "promotion manifest is not implemented")
    model = SemanticModel(source, HERE, disposition)
    expanded = model.validate()
    return (
        schema_bytes,
        source_bytes,
        materializer_bytes,
        disposition_bytes,
        source,
        expanded,
        model,
    )


def validate_only() -> None:
    (
        schema_bytes,
        source_bytes,
        materializer_bytes,
        disposition_bytes,
        source,
        expanded,
        _model,
    ) = load_and_validate_source()
    print(
        json.dumps(
            {
                "status": "accepted",
                "model_id": source["model_id"],
                "counts": expanded["counts"],
                "inputs": {
                    "r10-schema.json": sha256_bytes(schema_bytes),
                    "r10-source.json": sha256_bytes(source_bytes),
                    "materialize-r10.py": sha256_bytes(materializer_bytes),
                    "r9-rejection-disposition.json": sha256_bytes(disposition_bytes),
                },
            },
            sort_keys=True,
        )
    )


def materialize(check_only: bool) -> None:
    (
        schema_bytes,
        source_bytes,
        materializer_bytes,
        disposition_bytes,
        source,
        expanded,
        model,
    ) = load_and_validate_source()
    hostile_test_bytes = read_bytes(HOSTILE_TEST_PATH)
    hostile_results_bytes = read_bytes(HOSTILE_RESULTS_PATH)
    hostile_results = parse_json_bytes(hostile_results_bytes, str(HOSTILE_RESULTS_PATH))
    hostile_input_hashes = {
        "r10-schema.json": sha256_bytes(schema_bytes),
        "r10-source.json": sha256_bytes(source_bytes),
        "materialize-r10.py": sha256_bytes(materializer_bytes),
        "test-r10-hostile.py": sha256_bytes(hostile_test_bytes),
        "r9-rejection-disposition.json": sha256_bytes(disposition_bytes),
    }
    validate_hostile_evidence(source, hostile_results, hostile_input_hashes)
    expanded["hostile_mutation_evidence"] = {
        "status": hostile_results["status"],
        "case_count": hostile_results["case_count"],
        "sha256": sha256_bytes(hostile_results_bytes),
    }
    expanded_bytes = canonical_bytes(expanded)
    artifacts = {
        "r10-schema.json": sha256_bytes(schema_bytes),
        "r10-source.json": sha256_bytes(source_bytes),
        "materialize-r10.py": sha256_bytes(materializer_bytes),
        "r9-rejection-disposition.json": sha256_bytes(disposition_bytes),
        "test-r10-hostile.py": sha256_bytes(hostile_test_bytes),
        "r10-hostile-results.json": sha256_bytes(hostile_results_bytes),
        "r10-expanded.json": sha256_bytes(expanded_bytes),
    }
    for import_entry in source["imports"]:
        artifacts[f"import:{import_entry['id']}"] = sha256_bytes(
            model.import_bytes[import_entry["id"]]
        )
    lock = {
        "schema_version": 1,
        "model_id": source["model_id"],
        "status": source["status"],
        "artifacts": dict(sorted(artifacts.items())),
        "canonicalization": "UTF-8 JSON, sorted keys, compact separators, one LF, no floats/null",
        "publication": "temporary files with fsync; r10-lock.json replaced last as authoritative manifest",
    }
    markdown = render_markdown(source, expanded, lock)
    lock["artifacts"]["r10-generated.md"] = sha256_bytes(markdown.encode("ascii"))
    lock["artifacts"] = dict(sorted(lock["artifacts"].items()))
    if check_only:
        expected = {
            EXPANDED_PATH: expanded_bytes,
            LOCK_PATH: canonical_bytes(lock),
            GENERATED_MD_PATH: markdown.encode("ascii"),
        }
        for path, content in expected.items():
            expect(path.is_file(), "IR-GENERATED-DRIFT", f"missing {path.name}")
            expect(path.read_bytes() == content, "IR-GENERATED-DRIFT", path.name)
    else:
        atomic_replace(EXPANDED_PATH, expanded_bytes)
        atomic_replace(GENERATED_MD_PATH, markdown.encode("ascii"))
        fsync_directory(HERE)
        atomic_replace(LOCK_PATH, canonical_bytes(lock))
        fsync_directory(HERE)
    print(json.dumps({"status": "ok", "counts": expanded["counts"], "check_only": check_only}, sort_keys=True))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="reject generated drift")
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="validate source semantics without reading or publishing generated evidence",
    )
    args = parser.parse_args()
    try:
        if args.validate_only:
            expect(not args.check, "IR-CLI", "--check and --validate-only are mutually exclusive")
            validate_only()
        else:
            materialize(args.check)
    except Reject as exc:
        print(json.dumps({"status": "rejected", "reject_id": exc.reject_id, "message": exc.message}, sort_keys=True), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
