"""Local cross-implementation verifier for DL-F0-5 LinkedModel bytes."""

from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import dataclass
from typing import Any, NoReturn


LANGUAGE_ID = "DL-F0-5"
ARTIFACT_ID = "DL-F0-5-LINKED-MODEL-CONSTRUCTION-1"
MAX_ARTIFACT_BYTES = 64 * 1024 * 1024
MAX_MODEL_BYTES = 4 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512
MODULE_DIGEST_DOMAIN = b"DL-F0-5|MODULE|DL-F0-CJSON-1|"


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise Reject(reject_id, detail)


class InconclusiveResource(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-LV-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _reject_float(token: str) -> NoReturn:
    reject("F05-LV-FLOAT", token)


def _reject_constant(token: str) -> NoReturn:
    reject("F05-LV-NON-JSON-NUMBER", token)


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-LV-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-LV-INTEGER", str(exc))


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def _safe_scalar(value: Any, path: str = "$") -> None:
    stack: list[tuple[Any, str, int]] = [(value, path, 0)]
    nodes = 0
    while stack:
        current, current_path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-LV-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-LV-DEPTH", f"{current_path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-LV-UNSAFE-SCALAR", current_path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-LV-NEGATIVE-INTEGER", current_path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-LV-NON-ASCII", current_path)
            if any(
                ord(character) < 0x20 or ord(character) == 0x7F
                for character in current
            ):
                reject("F05-LV-CONTROL-STRING", current_path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-LV-COLLECTION-LIMIT", current_path)
            for key, child in current.items():
                stack.append(
                    (child, _child_path(current_path, f".{key}"), depth + 1)
                )
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-LV-COLLECTION-LIMIT", current_path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (
                        current[index],
                        _child_path(current_path, f"[{index}]"),
                        depth + 1,
                    )
                )
            continue
        reject("F05-LV-UNSAFE-TYPE", f"{current_path}:{type(current).__name__}")


def _parse_canonical(raw: bytes, max_bytes: int, label: str) -> dict[str, Any]:
    if type(raw) is not bytes or not raw or len(raw) > max_bytes:
        reject(
            f"F05-LV-{label}-SIZE",
            str(len(raw) if isinstance(raw, bytes) else -1),
        )
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject(f"F05-LV-{label}-NON-ASCII", str(exc))
    try:
        value = json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_int=_parse_integer,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except Reject:
        raise
    except json.JSONDecodeError as exc:
        reject(f"F05-LV-{label}-JSON", str(exc))
    except (MemoryError, RecursionError, ValueError) as exc:
        reject(f"F05-LV-{label}-RESOURCE", type(exc).__name__)
    _safe_scalar(value)
    if not isinstance(value, dict):
        reject(f"F05-LV-{label}-TOPLEVEL", type(value).__name__)
    try:
        canonical = canonical_bytes(value)
    except (MemoryError, RecursionError, ValueError) as exc:
        reject(f"F05-LV-{label}-RESOURCE", type(exc).__name__)
    if raw != canonical:
        reject(f"F05-LV-{label}-NONCANONICAL", f"{label.lower()} bytes")
    return value


def parse_artifact(raw: bytes) -> dict[str, Any]:
    return _parse_canonical(raw, MAX_ARTIFACT_BYTES, "ARTIFACT")


def parse_source_model(raw: bytes) -> dict[str, Any]:
    return _parse_canonical(raw, MAX_MODEL_BYTES, "SOURCE")


def _strict_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(
            _strict_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            _strict_equal(left, right)
            for left, right in zip(actual, expected, strict=True)
        )
    return actual == expected


def _typed_id(kind: str, domain: str, preimage: Any) -> dict[str, Any]:
    return {
        "kind": kind,
        "version": 1,
        "algorithm": "sha256",
        "sha256": sha256(domain.encode("ascii") + canonical_bytes(preimage)),
    }


def _typed_none(payload_variant: list[str]) -> dict[str, Any]:
    payload_sort = {"tag": "SORT_VARIANT", "variant": copy.deepcopy(payload_variant)}
    return {
        "tag": "TYPED_TERM",
        "result_sort": {"tag": "SORT_OPTION", "element": copy.deepcopy(payload_sort)},
        "node": {"tag": "TERM_NONE", "element_sort": payload_sort},
    }


def _qname_key(value: list[str]) -> bytes:
    return canonical_bytes(value)


@dataclass(frozen=True)
class IndependentSourceView:
    model: dict[str, Any]
    modules: dict[str, dict[str, Any]]
    active_modules: frozenset[str]
    owned_event_channels: dict[str, dict[tuple[str, str], dict[str, Any]]]
    link_contract: Any


def _module_digest(module: dict[str, Any]) -> str:
    return sha256(MODULE_DIGEST_DOMAIN + canonical_bytes(module))


def _index_source(model: dict[str, Any], rule_contract: Any) -> IndependentSourceView:
    modules: dict[str, dict[str, Any]] = {}
    for index, module in enumerate(model.get("modules", [])):
        if not isinstance(module, dict) or not isinstance(module.get("name"), str):
            reject("F05-LV-SOURCE-MODULE", str(index))
        module_name = module["name"]
        if module_name in modules:
            reject("F05-LV-SOURCE-DUPLICATE-MODULE", module_name)
        modules[module_name] = module
    root = model.get("root_module")
    if root not in modules:
        reject("F05-LV-SOURCE-ROOT", repr(root))
    active_raw = model.get("active_modules")
    if not isinstance(active_raw, list) or not all(
        isinstance(module_name, str) for module_name in active_raw
    ):
        reject("F05-LV-SOURCE-ACTIVE", type(active_raw).__name__)
    active_modules = frozenset(active_raw)
    if len(active_modules) != len(active_raw):
        reject("F05-LV-SOURCE-DUPLICATE-ACTIVE", repr(active_raw))
    if root not in active_modules:
        reject("F05-LV-SOURCE-INACTIVE-ROOT", root)
    if not active_modules <= set(modules):
        reject(
            "F05-LV-SOURCE-UNKNOWN-ACTIVE",
            repr(sorted(active_modules - set(modules))),
        )

    graph: dict[str, list[str]] = {}
    for module_name, module in modules.items():
        imports = module.get("imports")
        declarations = module.get("declarations")
        if not isinstance(imports, list) or not isinstance(declarations, list):
            reject("F05-LV-SOURCE-MODULE-SHAPE", module_name)
        import_keys: set[bytes] = set()
        edges: list[str] = []
        for imported in imports:
            if not isinstance(imported, dict):
                reject("F05-LV-SOURCE-IMPORT", module_name)
            key = canonical_bytes(imported)
            if key in import_keys:
                reject("F05-LV-SOURCE-DUPLICATE-IMPORT", module_name)
            import_keys.add(key)
            target = imported.get("module")
            if target not in modules:
                reject("F05-LV-SOURCE-UNRESOLVED-IMPORT", repr(target))
            declared_digest = imported.get("artifact_sha256")
            actual_digest = _module_digest(modules[target])
            if declared_digest != actual_digest:
                reject(
                    "F05-LV-SOURCE-IMPORT-DIGEST",
                    f"{module_name}->{target}",
                )
            edges.append(target)
        graph[module_name] = edges

    colors: dict[str, int] = {}
    for start in modules:
        if colors.get(start, 0) == 2:
            continue
        colors[start] = 1
        stack: list[tuple[str, int]] = [(start, 0)]
        while stack:
            module_name, edge_index = stack[-1]
            if edge_index == len(graph[module_name]):
                colors[module_name] = 2
                stack.pop()
                continue
            target = graph[module_name][edge_index]
            stack[-1] = (module_name, edge_index + 1)
            color = colors.get(target, 0)
            if color == 1:
                reject("F05-LV-SOURCE-IMPORT-CYCLE", f"{module_name}->{target}")
            if color == 0:
                colors[target] = 1
                stack.append((target, 0))

    reachable: set[str] = set()
    pending = [root]
    while pending:
        module_name = pending.pop()
        if module_name in reachable:
            continue
        reachable.add(module_name)
        pending.extend(graph[module_name])
    if reachable != set(modules):
        reject(
            "F05-LV-SOURCE-DEPENDENCY-CLOSURE",
            repr(sorted(set(modules) - reachable)),
        )

    owned_event_channels: dict[str, dict[tuple[str, str], dict[str, Any]]] = {
        module_name: {} for module_name in modules
    }
    named: set[tuple[str, str]] = set()
    unnamed: dict[str, set[bytes]] = {module_name: set() for module_name in modules}
    for module_name, module in modules.items():
        for declaration in module["declarations"]:
            if not isinstance(declaration, dict) or not isinstance(
                declaration.get("tag"), str
            ):
                reject("F05-LV-SOURCE-DECLARATION", module_name)
            if "name" in declaration:
                raw_name = declaration["name"]
                if (
                    not isinstance(raw_name, list)
                    or len(raw_name) != 2
                    or raw_name[0] != module_name
                    or not isinstance(raw_name[1], str)
                ):
                    reject("F05-LV-SOURCE-QNAME", repr(raw_name))
                name = (raw_name[0], raw_name[1])
                if name in named:
                    reject("F05-LV-SOURCE-DUPLICATE-DECLARATION", repr(name))
                named.add(name)
                if declaration["tag"] == "DECL_EVENT_CHANNEL":
                    owned_event_channels[module_name][name] = declaration
            else:
                key = canonical_bytes(declaration)
                if key in unnamed[module_name]:
                    reject("F05-LV-SOURCE-DUPLICATE-UNNAMED", module_name)
                unnamed[module_name].add(key)
    return IndependentSourceView(
        model=model,
        modules=modules,
        active_modules=active_modules,
        owned_event_channels=owned_event_channels,
        link_contract=rule_contract.link_materialization,
    )


def _expected_source_binding(source: IndependentSourceView) -> dict[str, Any]:
    identity = source.link_contract.identity
    model = source.model
    module_digests = {
        module_name: _module_digest(module)
        for module_name, module in source.modules.items()
    }
    module_artifact_ids = {
        module_name: _typed_id(
            "MODULE_ARTIFACT",
            identity["module_artifact_domain"],
            {
                "owner_module": module_name,
                "module_node": module,
            },
        )
        for module_name, module in source.modules.items()
    }
    module_manifest: list[dict[str, Any]] = []
    declarations: list[dict[str, Any]] = []
    body_origins: list[dict[str, Any]] = []
    source_actions: list[dict[str, Any]] = []
    locator_keys: set[bytes] = set()

    def add_origin(module_name: str, locator: dict[str, Any]) -> None:
        key = canonical_bytes(locator)
        if key in locator_keys:
            reject("F05-LV-EXPECTED-DUPLICATE-LOCATOR", key.decode("ascii"))
        locator_keys.add(key)
        body_origins.append(
            {
                "owner_module": module_name,
                "locator": copy.deepcopy(locator),
                "body_origin_id": _typed_id(
                    "BODY_ORIGIN",
                    identity["body_origin_domain"],
                    {
                        "module_artifact_id": module_artifact_ids[module_name],
                        "locator": locator,
                    },
                ),
            }
        )

    for module_name in sorted(source.modules):
        module = source.modules[module_name]
        module_manifest.append(
            {
                "module_name": module_name,
                "module_content_sha256": module_digests[module_name],
                "module_artifact_id": copy.deepcopy(
                    module_artifact_ids[module_name]
                ),
                "direct_imports": [
                    {
                        "module": imported["module"],
                        "artifact_sha256": imported["artifact_sha256"],
                    }
                    for imported in sorted(
                        module["imports"], key=lambda entry: entry["module"]
                    )
                ],
                "activation": (
                    "ACTIVE" if module_name in source.active_modules else "DORMANT"
                ),
            }
        )
        add_origin(module_name, {"kind": "MODULE_INIT", "module": module_name})
        for index, declaration in enumerate(module["declarations"]):
            declarations.append(
                {
                    "owner_module": module_name,
                    "declaration_index": index,
                    "declaration_tag": declaration["tag"],
                    "source_locator": (
                        {
                            "kind": "NAMED_DECLARATION",
                            "name": copy.deepcopy(declaration["name"]),
                        }
                        if "name" in declaration
                        else {
                            "kind": "UNNAMED_DECLARATION",
                            "declaration_index": index,
                        }
                    ),
                    "source_declaration_artifact_id": _typed_id(
                        "SOURCE_DECLARATION_ARTIFACT",
                        identity["source_declaration_domain"],
                        {"owner_module": module_name, "declaration": declaration},
                    ),
                }
            )
            tag = declaration["tag"]
            if tag == "DECL_PREMISE":
                add_origin(
                    module_name,
                    {
                        "kind": "CLASS_PREMISE",
                        "premise_name": copy.deepcopy(declaration["name"]),
                    },
                )
            elif tag == "DECL_CLAIM_BASE_ALWAYS":
                add_origin(
                    module_name,
                    {
                        "kind": "BASE_CLAIM",
                        "claim_name": copy.deepcopy(declaration["name"]),
                    },
                )
            elif tag == "DECL_ACTION":
                action_name = copy.deepcopy(declaration["name"])
                source_actions.append(
                    {
                        "action_name": action_name,
                        "source_action_artifact_id": _typed_id(
                            "SOURCE_ACTION_ARTIFACT",
                            identity["source_action_artifact_domain"],
                            {
                                "module_artifact_id": module_artifact_ids[module_name],
                                "action_name": action_name,
                            },
                        ),
                    }
                )
                add_origin(
                    module_name,
                    {"kind": "ACTION_INVOKE", "action_name": action_name},
                )
                for branch in declaration["branches"]:
                    branch_name = branch["branch"]
                    add_origin(
                        module_name,
                        {
                            "kind": "ACTION_GUARD",
                            "action_name": action_name,
                            "branch": branch_name,
                        },
                    )
                    for update_index, _ in enumerate(branch["updates"]):
                        add_origin(
                            module_name,
                            {
                                "kind": "ACTION_UPDATE",
                                "action_name": action_name,
                                "branch": branch_name,
                                "update_index": update_index,
                            },
                        )
                    for emit in branch["emits"]:
                        add_origin(
                            module_name,
                            {
                                "kind": "ACTION_EMIT",
                                "action_name": action_name,
                                "branch": branch_name,
                                "event_channel": copy.deepcopy(emit["event_channel"]),
                            },
                        )

    declarations.sort(
        key=lambda entry: (entry["owner_module"], entry["declaration_index"])
    )
    body_origins.sort(key=lambda entry: canonical_bytes(entry["locator"]))
    source_actions.sort(key=lambda entry: _qname_key(entry["action_name"]))
    return {
        "root_module": model["root_module"],
        "canonical_model_sha256": sha256(canonical_bytes(model)),
        "model_artifact_id": _typed_id(
            "MODEL_ARTIFACT",
            identity["model_artifact_domain"],
            model,
        ),
        "module_manifest": module_manifest,
        "declaration_artifact_manifest": declarations,
        "body_origin_manifest": body_origins,
        "source_action_artifacts": source_actions,
    }


def _expected_linked_model(source: IndependentSourceView) -> dict[str, Any]:
    contract = source.link_contract
    signatures: list[dict[str, Any]] = []
    constraints: list[dict[str, Any]] = []
    arithmetic: list[dict[str, Any]] = []
    state_products: list[dict[str, Any]] = []
    event_channels: list[dict[str, Any]] = []
    premises: list[dict[str, Any]] = []
    claims: list[dict[str, Any]] = []
    actions: list[tuple[str, dict[str, Any]]] = []

    for module_name in sorted(source.modules):
        for declaration in source.modules[module_name]["declarations"]:
            tag = declaration["tag"]
            projection = contract.declaration_rules.get(tag)
            if projection is not None:
                signature = {
                    field: copy.deepcopy(declaration[field])
                    for field in projection.signature_fields
                }
                derived: dict[str, Any] = {}
                if projection.signature_derived:
                    if projection.signature_derived != (
                        "BRANCH_NAMES:EACH:branches:branch",
                    ):
                        reject("F05-LV-EXPECTED-DERIVATION", tag)
                    derived["branch_names"] = [
                        branch["branch"] for branch in declaration["branches"]
                    ]
                signatures.append(
                    {
                        "declaration_tag": tag,
                        "owner_module": module_name,
                        "signature": signature,
                        "derived": derived,
                        "carrier_role": projection.carrier_role,
                        "body_kind": projection.body_kind,
                    }
                )
                if projection.carrier_role == "STATE_PRODUCT":
                    state_products.append(
                        {
                            "name": copy.deepcopy(declaration["name"]),
                            "key_sort": copy.deepcopy(declaration["key_sort"]),
                            "value_sort": copy.deepcopy(declaration["value_sort"]),
                        }
                    )
                elif projection.carrier_role == "EVENT_CHANNEL":
                    event_channels.append(
                        {
                            "name": copy.deepcopy(declaration["name"]),
                            "payload_sort": {
                                "tag": "SORT_VARIANT",
                                "variant": copy.deepcopy(
                                    declaration["payload_variant"]
                                ),
                            },
                        }
                    )
                if module_name in source.active_modules:
                    if projection.body_kind == "CLASS_PREMISE":
                        premises.append(
                            {
                                "name": copy.deepcopy(declaration["name"]),
                                "owner_module": module_name,
                                "body": copy.deepcopy(declaration["body"]),
                            }
                        )
                    elif projection.body_kind == "BASE_CLAIM":
                        claims.append(
                            {
                                "name": copy.deepcopy(declaration["name"]),
                                "owner_module": module_name,
                                "invariant": copy.deepcopy(declaration["invariant"]),
                            }
                        )
                    elif projection.body_kind == "ACTION":
                        actions.append((module_name, declaration))
                continue
            always = contract.always_linked_rules.get(tag)
            if always is None:
                reject("F05-LV-EXPECTED-DECLARATION-RULE", tag)
            entry = {
                "owner_module": module_name,
                **{
                    field: copy.deepcopy(declaration[field])
                    for field in always.fields
                },
            }
            if always.target == "CONSTANT_CONSTRAINTS":
                constraints.append(entry)
            elif always.target == "ARITHMETIC_BINDINGS":
                arithmetic.append(entry)
            else:
                reject("F05-LV-EXPECTED-UNNAMED-TARGET", always.target)

    signatures.sort(key=lambda entry: _qname_key(entry["signature"]["name"]))
    constraints.sort(key=canonical_bytes)
    arithmetic.sort(key=canonical_bytes)
    state_products.sort(key=lambda entry: _qname_key(entry["name"]))
    event_channels.sort(key=lambda entry: _qname_key(entry["name"]))
    premises.sort(key=lambda entry: _qname_key(entry["name"]))
    claims.sort(key=lambda entry: _qname_key(entry["name"]))
    actions.sort(key=lambda entry: _qname_key(entry[1]["name"]))

    empty_event = [
        {
            "event_channel": copy.deepcopy(channel["name"]),
            "payload_sort": copy.deepcopy(channel["payload_sort"]),
            "origin": {
                "kind": "LINKER_GENERATED_EMPTY_EVENT",
                "rule": "SYNTHESIZED_EXACT_TYPED_NONE_AT_EVERY_CHANNEL",
                "event_channel": copy.deepcopy(channel["name"]),
            },
            "value": _typed_none(channel["payload_sort"]["variant"]),
        }
        for channel in event_channels
    ]
    channels_by_name = {
        tuple(channel["name"]): channel for channel in event_channels
    }
    action_bodies: list[dict[str, Any]] = []
    for module_name, action in actions:
        owned_channels = sorted(
            tuple(name) for name in source.owned_event_channels[module_name]
        )
        branch_bodies: list[dict[str, Any]] = []
        for branch in sorted(action["branches"], key=lambda entry: entry["branch"]):
            declared = {
                tuple(emit["event_channel"]): emit for emit in branch["emits"]
            }
            if len(declared) != len(branch["emits"]):
                reject("F05-LV-EXPECTED-DUPLICATE-EMIT", repr(action["name"]))
            if set(declared) != set(owned_channels):
                reject("F05-LV-EXPECTED-EMIT-DOMAIN", repr(action["name"]))
            coordinates: list[dict[str, Any]] = []
            for channel_name in sorted(channels_by_name):
                channel = channels_by_name[channel_name]
                if channel_name in declared:
                    origin = {
                        "kind": "SOURCE_DECLARED_EMIT",
                        "action_name": copy.deepcopy(action["name"]),
                        "branch": branch["branch"],
                        "event_channel": list(channel_name),
                    }
                    value = copy.deepcopy(declared[channel_name]["value"])
                else:
                    origin = {
                        "kind": "LINKER_GENERATED_NON_OWNER_NONE",
                        "rule": "SYNTHESIZED_EXACT_TYPED_NONE",
                        "action_name": copy.deepcopy(action["name"]),
                        "branch": branch["branch"],
                        "event_channel": list(channel_name),
                    }
                    value = _typed_none(channel["payload_sort"]["variant"])
                coordinates.append(
                    {
                        "event_channel": list(channel_name),
                        "payload_sort": copy.deepcopy(channel["payload_sort"]),
                        "origin": origin,
                        "value": value,
                    }
                )
            branch_bodies.append(
                {
                    "branch": branch["branch"],
                    "guard": copy.deepcopy(branch["guard"]),
                    "updates": copy.deepcopy(branch["updates"]),
                    "event_coordinates": coordinates,
                }
            )
        action_bodies.append(
            {
                "name": copy.deepcopy(action["name"]),
                "owner_module": module_name,
                "parameter_variable": action["parameter_variable"],
                "parameter_sort": copy.deepcopy(action["parameter_sort"]),
                "invoke": copy.deepcopy(action["invoke"]),
                "owned_channels": [list(name) for name in owned_channels],
                "branches": branch_bodies,
            }
        )

    active_modules = sorted(source.active_modules)
    contributions = [
        {
            "module_name": module_name,
            "body": copy.deepcopy(source.modules[module_name]["init_contribution"]),
        }
        for module_name in active_modules
    ]
    if len(contributions) == 1:
        init_form = "SINGLE_IDENTITY"
        init_body = copy.deepcopy(contributions[0]["body"])
    else:
        init_form = "UNFLATTENED_OUTER_AND"
        init_body = {
            "tag": "TYPED_TERM",
            "result_sort": {"tag": "SORT_BOOL"},
            "node": {
                "tag": "TERM_AND",
                "operands": [
                    copy.deepcopy(contribution["body"])
                    for contribution in contributions
                ],
            },
        }
    return {
        "language_id": LANGUAGE_ID,
        "dependency_modules": sorted(source.modules),
        "active_modules": active_modules,
        "inactive_modules": sorted(set(source.modules) - set(source.active_modules)),
        "sigma": {
            "declaration_signatures": signatures,
            "constant_constraints": constraints,
            "arithmetic_bindings": arithmetic,
            "state_product_carriers": state_products,
            "event_channel_carriers": event_channels,
            "empty_event_template": empty_event,
        },
        "class_premise_bodies": premises,
        "init": {
            "form": init_form,
            "ordered_contributions": contributions,
            "body": init_body,
        },
        "action_bodies": action_bodies,
        "base_claim_bodies": claims,
    }


EXPECTED_AUTHORIZATION = {
    "linked_model_materialized": True,
    "linked_model_independently_validated": False,
    "source_action_semantic_id_issued": False,
    "linked_action_semantic_id_issued": False,
    "linked_action_id_issued": False,
    "Eval": False,
    "Reads": False,
    "transition_semantics": False,
    "InstanceWF": False,
    "ClaimPackageWF": False,
    "proof_validation": False,
    "CoreSyntaxWF": False,
    "F0_local_acceptance": False,
    "K0_G0_complete": False,
    "candidate_IR": False,
    "TLA_translation": False,
    "model_supported": False,
    "linux_behavior_change": False,
    "protection_claim": False,
}


def validate(
    model_raw: bytes,
    rule_contract: Any,
    artifact_raw: bytes,
    *,
    max_event_coordinates: int | None = None,
) -> dict[str, Any]:
    artifact = parse_artifact(artifact_raw)
    model = parse_source_model(model_raw)
    source = _index_source(model, rule_contract)
    active_actions = [
        declaration
        for module_name in source.active_modules
        for declaration in source.modules[module_name]["declarations"]
        if declaration["tag"] == "DECL_ACTION"
    ]
    event_channel_count = sum(
        1
        for module_name in source.modules
        for declaration in source.modules[module_name]["declarations"]
        if declaration["tag"] == "DECL_EVENT_CHANNEL"
    )
    event_coordinate_total = sum(
        len(action["branches"]) for action in active_actions
    ) * event_channel_count
    if (
        max_event_coordinates is not None
        and event_coordinate_total > max_event_coordinates
    ):
        raise InconclusiveResource(
            "F05-LV-INCONCLUSIVE-RESOURCE-EVENT-COORDINATES",
            f"{event_coordinate_total}>{max_event_coordinates}",
        )
    source_binding = _expected_source_binding(source)
    linked_model = _expected_linked_model(source)
    identity = source.link_contract.identity
    observations = sorted(
        {
            "link_materialization.status",
            "link_materialization.source_binding_fields",
            "link_materialization.linked_model_fields",
            "link_materialization.final_identity_issued",
            *(
                f"link_materialization.declaration_rules.{tag}"
                for tag in source.link_contract.declaration_rules
            ),
            *(
                f"link_materialization.always_linked_rules.{tag}"
                for tag in source.link_contract.always_linked_rules
            ),
            *(
                f"link_materialization.module_init.{field}"
                for field in source.link_contract.module_init
            ),
            *(
                f"link_materialization.event_totalization.{field}"
                for field in source.link_contract.event_totalization
            ),
            *(
                f"link_materialization.identity.{field}"
                for field in source.link_contract.identity
            ),
            *(
                f"link_materialization.identity_preimages.{kind}"
                for kind in source.link_contract.identity_preimages
            ),
        }
    )
    semantic_projection_id = _typed_id(
        "LINKED_SEMANTIC_PROJECTION_CONSTRUCTION",
        identity["semantic_projection_construction_domain"],
        linked_model,
    )
    construction_payload = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "source_binding": source_binding,
        "linked_model": linked_model,
    }
    construction_id = _typed_id(
        "LINKED_MODEL_CONSTRUCTION",
        identity["linked_construction_domain"],
        construction_payload,
    )
    expected = {
        "schema_version": 1,
        "artifact_id": ARTIFACT_ID,
        "status": "construction_materialized_not_independently_validated",
        "link_rule_observations": observations,
        "source_binding": source_binding,
        "linked_model": linked_model,
        "linked_semantic_projection_construction_id": semantic_projection_id,
        "linked_model_construction_id": construction_id,
        "authorization": EXPECTED_AUTHORIZATION,
    }
    if not _strict_equal(artifact, expected):
        reject("F05-LV-ARTIFACT-MISMATCH", "producer output differs from independent reconstruction")
    return {
        "schema_version": 1,
        "status": "linked_model_construction_locally_cross_reconstructed",
        "authority": "local_cross_implementation_reconstruction_only",
        "artifact_sha256": sha256(artifact_raw),
        "source_sha256": sha256(model_raw),
        "source_bytes_reparsed_independently": True,
        "model_artifact_id": source_binding["model_artifact_id"],
        "linked_semantic_projection_construction_id": semantic_projection_id,
        "linked_model_construction_id": construction_id,
        "dependency_module_count": len(linked_model["dependency_modules"]),
        "active_module_count": len(linked_model["active_modules"]),
        "action_body_count": len(linked_model["action_bodies"]),
        "claim_body_count": len(linked_model["base_claim_bodies"]),
        "event_channel_count": len(
            linked_model["sigma"]["event_channel_carriers"]
        ),
        "linked_model_materialized": True,
        "linked_model_locally_cross_reconstructed": True,
        "linked_model_independently_validated": False,
        "external_review": False,
        "Eval": False,
        "Reads": False,
        "transition_semantics": False,
        "InstanceWF": False,
        "ClaimPackageWF": False,
        "proof_validation": False,
        "CoreSyntaxWF": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }
