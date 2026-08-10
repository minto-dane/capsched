"""Digest-bound checked semantic-root occurrences for DL-F0-5.

This construction joins source static derivations to deterministic LinkedModel
roots. It deliberately does not issue SemanticContextDigest or F0 acceptance.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from types import MappingProxyType
from typing import Any, Mapping, NoReturn


LANGUAGE_ID = "DL-F0-5"
ARTIFACT_ID = "domainlease-r11-epoch2-f0-checked-term-occurrences-v5-construction-1"
OCCURRENCE_DOMAIN = b"DL-F0-5\x00CHECKED_TERM_OCCURRENCE_CONSTRUCTION\x00"
INDEX_DOMAIN = b"DL-F0-5\x00CHECKED_TERM_OCCURRENCE_INDEX_CONSTRUCTION\x00"
MAX_ARTIFACT_BYTES = 8 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512
EXPECTED_AUTHORIZATION = {
    "checked_term_occurrences_materialized": True,
    "checked_term_occurrences_independently_validated": False,
    "semantic_context_bound": False,
    "evaluation_validated": False,
    "CoreSyntaxWF": False,
    "F0_local_acceptance": False,
    "K0_G0_complete": False,
    "candidate_IR": False,
    "TLA_translation": False,
    "model_supported": False,
    "linux_behavior_change": False,
    "protection_claim": False,
}


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise Reject(reject_id, detail)


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-OCC-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-OCC-INTEGER", str(exc))


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def _validate_tree(value: Any) -> None:
    stack: list[tuple[Any, str, int]] = [(value, "$", 0)]
    nodes = 0
    while stack:
        current, path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-OCC-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-OCC-DEPTH", f"{path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-OCC-UNSAFE-SCALAR", path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-OCC-NEGATIVE-INTEGER", path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-OCC-NON-ASCII", path)
            if any(ord(character) < 0x20 or ord(character) == 0x7F for character in current):
                reject("F05-OCC-CONTROL-STRING", path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-OCC-COLLECTION-LIMIT", path)
            for key, child in current.items():
                if not isinstance(key, str):
                    reject("F05-OCC-NON-STRING-KEY", path)
                stack.append((child, _child_path(path, f".{key}"), depth + 1))
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-OCC-COLLECTION-LIMIT", path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (current[index], _child_path(path, f"[{index}]"), depth + 1)
                )
            continue
        reject("F05-OCC-UNSAFE-TYPE", f"{path}:{type(current).__name__}")


def canonical_bytes(value: Any) -> bytes:
    _validate_tree(value)
    try:
        return json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
        ).encode("ascii")
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-OCC-CANONICALIZE", type(exc).__name__)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def typed_id(tag: str, domain: bytes, payload: Any) -> dict[str, Any]:
    return {
        "tag": tag,
        "domain": domain[:-1].decode("ascii").replace("\x00", ":"),
        "sha256": sha256(domain + canonical_bytes(payload)),
    }


def qname(value: Any, path: str) -> tuple[str, str]:
    if (
        not isinstance(value, list)
        or len(value) != 2
        or not all(isinstance(part, str) and part for part in value)
    ):
        reject("F05-OCC-QNAME", path)
    return value[0], value[1]


def _key(value: Any) -> bytes:
    return canonical_bytes(value)


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-OCC-DUPLICATE-KEY", key)
        result[key] = value
    return result


def parse_canonical_artifact(raw: bytes) -> dict[str, Any]:
    if type(raw) is not bytes or not raw or len(raw) > MAX_ARTIFACT_BYTES:
        reject("F05-OCC-SIZE", str(len(raw) if isinstance(raw, bytes) else -1))
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-OCC-ASCII", str(exc.start))
    try:
        value = json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_int=_parse_integer,
            parse_float=lambda token: reject("F05-OCC-FLOAT", token),
            parse_constant=lambda token: reject("F05-OCC-NON-JSON-NUMBER", token),
        )
    except Reject:
        raise
    except json.JSONDecodeError as exc:
        reject("F05-OCC-JSON", type(exc).__name__)
    _validate_tree(value)
    if not isinstance(value, dict):
        reject("F05-OCC-TOPLEVEL", type(value).__name__)
    canonical = canonical_bytes(value)
    if canonical != raw:
        reject("F05-OCC-NONCANONICAL", sha256(raw))
    return value


def _resolve_path(root: Any, path: list[Any]) -> Any:
    current = root
    for index, component in enumerate(path):
        if isinstance(component, str) and isinstance(current, dict):
            if component not in current:
                reject("F05-OCC-LINKED-PATH", f"{index}:{component}")
            current = current[component]
        elif type(component) is int and isinstance(current, list):
            if component < 0 or component >= len(current):
                reject("F05-OCC-LINKED-PATH", f"{index}:{component}")
            current = current[component]
        else:
            reject("F05-OCC-LINKED-PATH", f"{index}:{component!r}")
    return current


def validate_snapshot(
    raw: bytes,
    linked_artifact: Mapping[str, Any],
    static_rule_contract: Any,
    eval_rule_contract: Any,
) -> dict[str, Any]:
    artifact = parse_canonical_artifact(raw)
    expected_top = {
        "schema_version",
        "language_id",
        "artifact_id",
        "status",
        "construction_inputs",
        "occurrences",
        "checked_term_occurrence_index_construction_id",
        "semantic_context_digest",
        "authorization",
    }
    if set(artifact) != expected_top:
        reject("F05-OCC-TOPLEVEL", "exact fields required")
    expected_identity = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "artifact_id": ARTIFACT_ID,
        "status": "checked_term_occurrences_materialized_not_independently_validated",
    }
    for field, expected in expected_identity.items():
        if type(artifact.get(field)) is not type(expected) or artifact.get(field) != expected:
            reject("F05-OCC-IDENTITY", field)
    if artifact.get("authorization") != EXPECTED_AUTHORIZATION:
        reject("F05-OCC-AUTHORIZATION", "exact false boundary required")
    if artifact.get("semantic_context_digest") != {
        "status": "NOT_ISSUED",
        "reason": "TRANSITION_CLAIM_MORPHISM_THEOREM_AND_PROOF_RULES_NOT_FROZEN",
    }:
        reject("F05-OCC-SEMANTIC-CONTEXT", "must remain unissued")

    inputs = artifact["construction_inputs"]
    source_binding = linked_artifact["source_binding"]
    expected_inputs = {
        "canonical_model_sha256": source_binding["canonical_model_sha256"],
        "model_artifact_id": source_binding["model_artifact_id"],
        "linked_model_construction_id": linked_artifact["linked_model_construction_id"],
        "linked_semantic_projection_construction_id": linked_artifact[
            "linked_semantic_projection_construction_id"
        ],
        "static_rules_raw_sha256": static_rule_contract.rules_raw_sha256,
        "static_rules_canonical_sha256": static_rule_contract.rules_canonical_sha256,
        "eval_rules_raw_sha256": eval_rule_contract.rules_raw_sha256,
        "eval_rules_canonical_sha256": eval_rule_contract.rules_canonical_sha256,
        "normative_part_sha256": dict(eval_rule_contract.normative_part_sha256),
    }
    if inputs != expected_inputs:
        reject("F05-OCC-CONSTRUCTION-INPUTS", "identity mismatch")

    expected_occurrence_fields = {
        "linked_model_construction_id",
        "linked_path",
        "role",
        "owner_module",
        "locator",
        "component",
        "origin",
        "term",
        "term_sha256",
        "result_sort",
        "provenance",
        "root_context",
        "gamma",
        "delta",
        "checked_term_occurrence_id",
    }
    occurrences = artifact["occurrences"]
    if not isinstance(occurrences, list) or not occurrences:
        reject("F05-OCC-DOMAIN", "nonempty occurrence list required")
    previous_path: bytes | None = None
    ids: set[str] = set()
    for index, occurrence in enumerate(occurrences):
        if not isinstance(occurrence, dict) or set(occurrence) != expected_occurrence_fields:
            reject("F05-OCC-SHAPE", str(index))
        path = occurrence["linked_path"]
        if not isinstance(path, list) or not path:
            reject("F05-OCC-PATH", str(index))
        path_key = canonical_bytes(path)
        if previous_path is not None and previous_path >= path_key:
            reject("F05-OCC-PATH-ORDER", str(index))
        previous_path = path_key
        if occurrence["linked_model_construction_id"] != linked_artifact[
            "linked_model_construction_id"
        ]:
            reject("F05-OCC-LINKED-ID", str(index))
        linked_term = _resolve_path(linked_artifact["linked_model"], path)
        if canonical_bytes(linked_term) != canonical_bytes(occurrence["term"]):
            reject("F05-OCC-LINKED-TERM-DRIFT", str(index))
        if occurrence["term_sha256"] != sha256(canonical_bytes(occurrence["term"])):
            reject("F05-OCC-TERM-DIGEST", str(index))
        if occurrence["term"].get("result_sort") != occurrence["result_sort"]:
            reject("F05-OCC-RESULT-SORT", str(index))
        provenance = occurrence["provenance"]
        if (
            not isinstance(provenance, list)
            or provenance != sorted(provenance)
            or len(provenance) != len(set(provenance))
            or not set(provenance) <= {"PARAM", "PRE", "POST", "EVENT"}
        ):
            reject("F05-OCC-PROVENANCE", str(index))
        root_context = occurrence["root_context"]
        gamma = occurrence["gamma"]
        delta = occurrence["delta"]
        if root_context == {"tag": "CLOSED_ROOT"}:
            if gamma != [] or delta != []:
                reject("F05-OCC-ROOT-CONTEXT", str(index))
        elif isinstance(root_context, dict) and root_context.get("tag") == "ACTION_PARAM_ROOT":
            variable = root_context.get("parameter_variable")
            sort = root_context.get("parameter_sort")
            slot = root_context.get("parameter_slot")
            expected_gamma = [
                {
                    "variable": variable,
                    "sort": sort,
                    "sources": ["PARAM"],
                    "parameter_slot": slot,
                }
            ]
            expected_delta = [
                {
                    "variable": variable,
                    "dependencies": [{"kind": "PARAM", "subject": slot}],
                }
            ]
            if gamma != expected_gamma or delta != expected_delta:
                reject("F05-OCC-ROOT-CONTEXT", str(index))
        else:
            reject("F05-OCC-ROOT-CONTEXT", str(index))
        identifier = occurrence["checked_term_occurrence_id"]
        payload = {key: value for key, value in occurrence.items() if key != "checked_term_occurrence_id"}
        expected_id = typed_id(
            "CHECKED_TERM_OCCURRENCE_CONSTRUCTION", OCCURRENCE_DOMAIN, payload
        )
        if identifier != expected_id:
            reject("F05-OCC-ID", str(index))
        digest = identifier["sha256"]
        if digest in ids:
            reject("F05-OCC-ID-COLLISION", digest)
        ids.add(digest)

    index_payload = {
        "construction_inputs": inputs,
        "occurrences": occurrences,
    }
    expected_index_id = typed_id(
        "CHECKED_TERM_OCCURRENCE_INDEX_CONSTRUCTION", INDEX_DOMAIN, index_payload
    )
    if artifact["checked_term_occurrence_index_construction_id"] != expected_index_id:
        reject("F05-OCC-INDEX-ID", "digest mismatch")
    return {
        "schema_version": 1,
        "status": "checked_term_occurrence_construction_locally_revalidated",
        "authority": "local_construction_identity_and_link_binding_only",
        "occurrence_count": len(occurrences),
        "checked_term_occurrence_index_construction_id": expected_index_id,
        "checked_term_occurrences_materialized": True,
        "checked_term_occurrences_independently_validated": False,
        "semantic_context_bound": False,
        "evaluation_validated": False,
        "CoreSyntaxWF": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "protection_claim": False,
    }


def _component_key(locator: Mapping[str, Any], component: str) -> tuple[bytes, str]:
    return _key(dict(locator)), component


def _typed_result(checker: Any, term: Any, path: str) -> Any:
    if not isinstance(term, dict) or term.get("tag") != "TYPED_TERM":
        reject("F05-OCC-TERM", path)
    result = checker.term_results.get(id(term))
    context = checker.term_contexts.get(id(term))
    if result is None or context is None:
        reject("F05-OCC-NOT-STATIC-CHECKED", path)
    return result, context


def _closed_context() -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    return {"tag": "CLOSED_ROOT"}, [], []


def _action_context(
    action_name: tuple[str, str],
    parameter_variable: str,
    parameter_sort: Mapping[str, Any],
    source_action_artifact_id: Mapping[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    artifact_sha = source_action_artifact_id.get("sha256")
    if not isinstance(artifact_sha, str) or len(artifact_sha) != 64:
        reject("F05-OCC-ACTION-ID", repr(action_name))
    slot = ["ACTION_PARAM", action_name[0], action_name[1], artifact_sha]
    root_context = {
        "tag": "ACTION_PARAM_ROOT",
        "action_name": list(action_name),
        "source_action_artifact_id": dict(source_action_artifact_id),
        "parameter_variable": parameter_variable,
        "parameter_sort": json.loads(canonical_bytes(parameter_sort).decode("ascii")),
        "parameter_slot": slot,
    }
    gamma = [
        {
            "variable": parameter_variable,
            "sort": json.loads(canonical_bytes(parameter_sort).decode("ascii")),
            "sources": ["PARAM"],
            "parameter_slot": slot,
        }
    ]
    delta = [
        {
            "variable": parameter_variable,
            "dependencies": [
                {"kind": "PARAM", "subject": slot},
            ],
        }
    ]
    return root_context, gamma, delta


@dataclass(frozen=True)
class CheckedTermOccurrenceIndexSnapshot:
    artifact_raw: bytes
    index_construction_id: Mapping[str, Any]
    occurrence_count: int

    def artifact(self) -> dict[str, Any]:
        value = json.loads(self.artifact_raw.decode("ascii"))
        if not isinstance(value, dict):
            raise RuntimeError("checked occurrence artifact is not an object")
        return value


def materialize(checker: Any, eval_rule_contract: Any) -> CheckedTermOccurrenceIndexSnapshot:
    if not getattr(checker, "_checked", False) or checker.linked_model_snapshot is None:
        reject("F05-OCC-STATIC-CHECKER", "completed CoreSyntaxChecker required")
    linked_artifact = checker.linked_model_snapshot.artifact()
    source_binding = linked_artifact["source_binding"]
    linked = linked_artifact["linked_model"]

    body_origins = {
        _key(row["locator"]): row
        for row in source_binding["body_origin_manifest"]
    }
    module_artifacts = {
        row["module_name"]: row["module_artifact_id"]
        for row in source_binding["module_manifest"]
    }
    action_artifacts = {
        qname(row["action_name"], "source_action_artifacts.action_name"): row[
            "source_action_artifact_id"
        ]
        for row in source_binding["source_action_artifacts"]
    }
    modules = {module["name"]: module for module in checker.model["modules"]}

    source_terms: dict[tuple[bytes, str], dict[str, Any]] = {}

    def add_source(
        owner_module: str,
        locator: dict[str, Any],
        component: str,
        term: dict[str, Any],
        root_context: dict[str, Any],
        gamma: list[dict[str, Any]],
        delta: list[dict[str, Any]],
        origin: dict[str, Any],
        path: str,
    ) -> None:
        result, context = _typed_result(checker, term, path)
        key = _component_key(locator, component)
        if key in source_terms:
            reject("F05-OCC-DUPLICATE-SOURCE-COMPONENT", f"{locator}:{component}")
        expected_context = tuple(
            (
                entry["variable"],
                canonical_bytes(entry["sort"]),
                tuple(entry["sources"]),
            )
            for entry in gamma
        )
        if context != expected_context:
            reject(
                "F05-OCC-STATIC-CONTEXT",
                f"{path}:actual={context!r} expected={expected_context!r}",
            )
        source_terms[key] = {
            "owner_module": owner_module,
            "locator": locator,
            "component": component,
            "term": json.loads(canonical_bytes(term).decode("ascii")),
            "result_sort": json.loads(canonical_bytes(result.sort).decode("ascii")),
            "provenance": sorted(result.provenance),
            "root_context": root_context,
            "gamma": gamma,
            "delta": delta,
            "origin": origin,
        }

    for module_name in sorted(checker.active_modules):
        module = modules[module_name]
        closed, gamma, delta = _closed_context()
        add_source(
            module_name,
            {"kind": "MODULE_INIT", "module_name": module_name},
            "BODY",
            module["init_contribution"],
            closed,
            gamma,
            delta,
            {
                "kind": "SOURCE_MODULE_INIT",
                "module_artifact_id": module_artifacts[module_name],
            },
            f"module[{module_name}].init_contribution",
        )
        for declaration in module["declarations"]:
            tag = declaration["tag"]
            if tag == "DECL_CLAIM_BASE_ALWAYS":
                locator = {
                    "kind": "BASE_CLAIM",
                    "claim_name": declaration["name"],
                }
                origin = body_origins.get(_key(locator))
                if origin is None:
                    reject("F05-OCC-BODY-ORIGIN", repr(locator))
                add_source(
                    module_name,
                    locator,
                    "INVARIANT",
                    declaration["invariant"],
                    closed,
                    [],
                    [],
                    {"kind": "SOURCE_BODY", "body_origin_id": origin["body_origin_id"]},
                    f"{module_name}.{declaration['name']}.invariant",
                )
            elif tag == "DECL_ACTION":
                action_name = qname(declaration["name"], "action.name")
                action_context, action_gamma, action_delta = _action_context(
                    action_name,
                    declaration["parameter_variable"],
                    declaration["parameter_sort"],
                    action_artifacts[action_name],
                )
                invoke_locator = {"kind": "ACTION_INVOKE", "action_name": list(action_name)}
                invoke_origin = body_origins.get(_key(invoke_locator))
                if invoke_origin is None:
                    reject("F05-OCC-BODY-ORIGIN", repr(invoke_locator))
                add_source(
                    module_name,
                    invoke_locator,
                    "BODY",
                    declaration["invoke"],
                    action_context,
                    action_gamma,
                    action_delta,
                    {"kind": "SOURCE_BODY", "body_origin_id": invoke_origin["body_origin_id"]},
                    f"{module_name}.{action_name}.invoke",
                )
                for branch in declaration["branches"]:
                    branch_name = branch["branch"]
                    guard_locator = {
                        "kind": "ACTION_GUARD",
                        "action_name": list(action_name),
                        "branch": branch_name,
                    }
                    guard_origin = body_origins.get(_key(guard_locator))
                    if guard_origin is None:
                        reject("F05-OCC-BODY-ORIGIN", repr(guard_locator))
                    add_source(
                        module_name,
                        guard_locator,
                        "BODY",
                        branch["guard"],
                        action_context,
                        action_gamma,
                        action_delta,
                        {"kind": "SOURCE_BODY", "body_origin_id": guard_origin["body_origin_id"]},
                        f"{module_name}.{action_name}.{branch_name}.guard",
                    )
                    for update_index, update in enumerate(branch["updates"]):
                        update_locator = {
                            "kind": "ACTION_UPDATE",
                            "action_name": list(action_name),
                            "branch": branch_name,
                            "update_index": update_index,
                        }
                        update_origin = body_origins.get(_key(update_locator))
                        if update_origin is None:
                            reject("F05-OCC-BODY-ORIGIN", repr(update_locator))
                        fields = (
                            ("KEY", "key"),
                            ("VALUE", "value"),
                        ) if update["tag"] == "PUT_UPDATE" else (
                            ("DOMAIN", "domain"),
                            ("VALUES", "values"),
                        )
                        for component, field_name in fields:
                            add_source(
                                module_name,
                                update_locator,
                                component,
                                update[field_name],
                                action_context,
                                action_gamma,
                                action_delta,
                                {
                                    "kind": "SOURCE_BODY_COMPONENT",
                                    "body_origin_id": update_origin["body_origin_id"],
                                    "component": component,
                                },
                                f"{module_name}.{action_name}.{branch_name}.updates[{update_index}].{field_name}",
                            )
                    for emit in branch["emits"]:
                        emit_locator = {
                            "kind": "ACTION_EMIT",
                            "action_name": list(action_name),
                            "branch": branch_name,
                            "event_channel": emit["event_channel"],
                        }
                        emit_origin = body_origins.get(_key(emit_locator))
                        if emit_origin is None:
                            reject("F05-OCC-BODY-ORIGIN", repr(emit_locator))
                        add_source(
                            module_name,
                            emit_locator,
                            "VALUE",
                            emit["value"],
                            action_context,
                            action_gamma,
                            action_delta,
                            {"kind": "SOURCE_BODY", "body_origin_id": emit_origin["body_origin_id"]},
                            f"{module_name}.{action_name}.{branch_name}.emit[{emit['event_channel']}]",
                        )

    occurrences: list[dict[str, Any]] = []

    def add_linked(
        role: str,
        linked_path: list[Any],
        term: dict[str, Any],
        metadata: dict[str, Any],
    ) -> None:
        if canonical_bytes(term) != canonical_bytes(metadata["term"]):
            reject("F05-OCC-LINKED-TERM-DRIFT", repr(linked_path))
        payload = {
            "linked_model_construction_id": linked_artifact["linked_model_construction_id"],
            "linked_path": linked_path,
            "role": role,
            "owner_module": metadata["owner_module"],
            "locator": metadata["locator"],
            "component": metadata["component"],
            "origin": metadata["origin"],
            "term": metadata["term"],
            "term_sha256": sha256(canonical_bytes(metadata["term"])),
            "result_sort": metadata["result_sort"],
            "provenance": metadata["provenance"],
            "root_context": metadata["root_context"],
            "gamma": metadata["gamma"],
            "delta": metadata["delta"],
        }
        occurrence = dict(payload)
        occurrence["checked_term_occurrence_id"] = typed_id(
            "CHECKED_TERM_OCCURRENCE_CONSTRUCTION",
            OCCURRENCE_DOMAIN,
            payload,
        )
        occurrences.append(occurrence)

    init_parts = []
    for index, contribution in enumerate(linked["init"]["ordered_contributions"]):
        locator = {"kind": "MODULE_INIT", "module_name": contribution["module_name"]}
        source = source_terms[_component_key(locator, "BODY")]
        if canonical_bytes(contribution["body"]) != canonical_bytes(source["term"]):
            reject("F05-OCC-INIT-CONTRIBUTION-DRIFT", contribution["module_name"])
        init_parts.append(source)
    init_body = linked["init"]["body"]
    if len(init_parts) == 1:
        init_metadata = dict(init_parts[0])
    else:
        expected = {
            "tag": "TYPED_TERM",
            "result_sort": {"tag": "SORT_BOOL"},
            "node": {"tag": "TERM_AND", "operands": [part["term"] for part in init_parts]},
        }
        if canonical_bytes(init_body) != canonical_bytes(expected):
            reject("F05-OCC-GENERATED-INIT", "canonical outer AND drift")
        init_metadata = {
            "owner_module": linked["active_modules"][0],
            "locator": {"kind": "LINKED_INIT"},
            "component": "BODY",
            "term": expected,
            "result_sort": {"tag": "SORT_BOOL"},
            "provenance": sorted(
                {source for part in init_parts for source in part["provenance"]}
            ),
            "root_context": {"tag": "CLOSED_ROOT"},
            "gamma": [],
            "delta": [],
            "origin": {
                "kind": "LINKER_GENERATED_INIT_CONJUNCTION",
                "contribution_origins": [part["origin"] for part in init_parts],
            },
        }
    add_linked("INIT", ["init", "body"], init_body, init_metadata)

    for action_index, action in enumerate(linked["action_bodies"]):
        action_name = qname(action["name"], "linked.action.name")
        invoke_locator = {"kind": "ACTION_INVOKE", "action_name": list(action_name)}
        add_linked(
            "ACTION_INVOKE",
            ["action_bodies", action_index, "invoke"],
            action["invoke"],
            source_terms[_component_key(invoke_locator, "BODY")],
        )
        for branch_index, branch in enumerate(action["branches"]):
            branch_name = branch["branch"]
            guard_locator = {
                "kind": "ACTION_GUARD",
                "action_name": list(action_name),
                "branch": branch_name,
            }
            add_linked(
                "ACTION_GUARD",
                ["action_bodies", action_index, "branches", branch_index, "guard"],
                branch["guard"],
                source_terms[_component_key(guard_locator, "BODY")],
            )
            for update_index, update in enumerate(branch["updates"]):
                locator = {
                    "kind": "ACTION_UPDATE",
                    "action_name": list(action_name),
                    "branch": branch_name,
                    "update_index": update_index,
                }
                fields = (
                    ("KEY", "key"),
                    ("VALUE", "value"),
                ) if update["tag"] == "PUT_UPDATE" else (
                    ("DOMAIN", "domain"),
                    ("VALUES", "values"),
                )
                for component, field_name in fields:
                    add_linked(
                        f"ACTION_{update['tag']}_{component}",
                        [
                            "action_bodies",
                            action_index,
                            "branches",
                            branch_index,
                            "updates",
                            update_index,
                            field_name,
                        ],
                        update[field_name],
                        source_terms[_component_key(locator, component)],
                    )
            for channel_index, coordinate in enumerate(branch["event_coordinates"]):
                origin = coordinate["origin"]
                if origin["kind"] == "SOURCE_DECLARED_EMIT":
                    locator = {
                        "kind": "ACTION_EMIT",
                        "action_name": list(action_name),
                        "branch": branch_name,
                        "event_channel": coordinate["event_channel"],
                    }
                    metadata = source_terms[_component_key(locator, "VALUE")]
                else:
                    invoke_metadata = source_terms[_component_key(invoke_locator, "BODY")]
                    expected_none = {
                        "tag": "TYPED_TERM",
                        "result_sort": {
                            "tag": "SORT_OPTION",
                            "element": coordinate["payload_sort"],
                        },
                        "node": {
                            "tag": "TERM_NONE",
                            "element_sort": coordinate["payload_sort"],
                        },
                    }
                    metadata = {
                        "owner_module": action["owner_module"],
                        "locator": {
                            "kind": "LINKER_GENERATED_EMIT",
                            "action_name": list(action_name),
                            "branch": branch_name,
                            "event_channel": coordinate["event_channel"],
                        },
                        "component": "VALUE",
                        "term": expected_none,
                        "result_sort": expected_none["result_sort"],
                        "provenance": [],
                        "root_context": invoke_metadata["root_context"],
                        "gamma": invoke_metadata["gamma"],
                        "delta": invoke_metadata["delta"],
                        "origin": origin,
                    }
                add_linked(
                    "ACTION_EMIT",
                    [
                        "action_bodies",
                        action_index,
                        "branches",
                        branch_index,
                        "event_coordinates",
                        channel_index,
                        "value",
                    ],
                    coordinate["value"],
                    metadata,
                )

    for index, claim in enumerate(linked["base_claim_bodies"]):
        locator = {"kind": "BASE_CLAIM", "claim_name": claim["name"]}
        add_linked(
            "BASE_CLAIM",
            ["base_claim_bodies", index, "invariant"],
            claim["invariant"],
            source_terms[_component_key(locator, "INVARIANT")],
        )

    occurrences.sort(key=lambda row: canonical_bytes(row["linked_path"]))
    occurrence_ids = [row["checked_term_occurrence_id"]["sha256"] for row in occurrences]
    if len(occurrence_ids) != len(set(occurrence_ids)):
        reject("F05-OCC-ID-COLLISION", "duplicate occurrence construction id")

    construction_inputs = {
        "canonical_model_sha256": source_binding["canonical_model_sha256"],
        "model_artifact_id": source_binding["model_artifact_id"],
        "linked_model_construction_id": linked_artifact["linked_model_construction_id"],
        "linked_semantic_projection_construction_id": linked_artifact[
            "linked_semantic_projection_construction_id"
        ],
        "static_rules_raw_sha256": checker.rule_contract.rules_raw_sha256,
        "static_rules_canonical_sha256": checker.rule_contract.rules_canonical_sha256,
        "eval_rules_raw_sha256": eval_rule_contract.rules_raw_sha256,
        "eval_rules_canonical_sha256": eval_rule_contract.rules_canonical_sha256,
        "normative_part_sha256": dict(eval_rule_contract.normative_part_sha256),
    }
    index_payload = {
        "construction_inputs": construction_inputs,
        "occurrences": occurrences,
    }
    index_id = typed_id(
        "CHECKED_TERM_OCCURRENCE_INDEX_CONSTRUCTION",
        INDEX_DOMAIN,
        index_payload,
    )
    artifact = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "artifact_id": ARTIFACT_ID,
        "status": "checked_term_occurrences_materialized_not_independently_validated",
        **index_payload,
        "checked_term_occurrence_index_construction_id": index_id,
        "semantic_context_digest": {
            "status": "NOT_ISSUED",
            "reason": "TRANSITION_CLAIM_MORPHISM_THEOREM_AND_PROOF_RULES_NOT_FROZEN",
        },
        "authorization": dict(EXPECTED_AUTHORIZATION),
    }
    raw = canonical_bytes(artifact)
    return CheckedTermOccurrenceIndexSnapshot(
        artifact_raw=raw,
        index_construction_id=MappingProxyType(dict(index_id)),
        occurrence_count=len(occurrences),
    )
