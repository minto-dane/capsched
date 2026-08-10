"""Deterministic DL-F0-5 LinkedModel construction.

This module materializes the active semantic body projection after every
embedded source body has passed the static checker.  It does not implement
Eval, transition semantics, proof checking, or final semantic identities.
"""

from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import dataclass
from typing import Any, Callable, Mapping


ARTIFACT_ID = "DL-F0-5-LINKED-MODEL-CONSTRUCTION-1"
LANGUAGE_ID = "DL-F0-5"
MODULE_DIGEST_DOMAIN = b"DL-F0-5|MODULE|DL-F0-CJSON-1|"

EXPECTED_LINK_STATUS = "CONSTRUCTION_SPEC_NOT_COMPLETION_CLAIM"
EXPECTED_DECLARATION_RULES = {
    "DECL_ATOM": (("name", "carrier_class"), (), "NONE", (), "NONE"),
    "DECL_ENUM": (("name", "members"), (), "NONE", (), "NONE"),
    "DECL_UNIT": (("name",), (), "NONE", (), "NONE"),
    "DECL_LIMIT": (("name",), (), "NONE", (), "NONE"),
    "DECL_RECORD": (("name", "fields"), (), "NONE", (), "NONE"),
    "DECL_VARIANT": (("name", "variant_tags"), (), "NONE", (), "NONE"),
    "DECL_CONSTANT": (("name", "sort"), (), "NONE", (), "NONE"),
    "DECL_STATE_PRODUCT": (
        ("name", "key_sort", "value_sort"),
        (),
        "NONE",
        (),
        "STATE_PRODUCT",
    ),
    "DECL_EVENT_CHANNEL": (
        ("name", "payload_variant"),
        (),
        "NONE",
        (),
        "EVENT_CHANNEL",
    ),
    "DECL_ACTION": (
        ("name", "parameter_sort"),
        ("BRANCH_NAMES:EACH:branches:branch",),
        "ACTION",
        ("parameter_variable", "invoke", "branches"),
        "NONE",
    ),
    "DECL_PREMISE": (("name",), (), "CLASS_PREMISE", ("body",), "NONE"),
    "DECL_CLAIM_BASE_ALWAYS": (
        ("name",),
        (),
        "BASE_CLAIM",
        ("invariant",),
        "NONE",
    ),
}
EXPECTED_ALWAYS_LINKED_RULES = {
    "DECL_CONSTANT_CONSTRAINT": ("CONSTANT_CONSTRAINTS", ("constraint",)),
    "DECL_ARITH_RESULT_BINDING": (
        "ARITHMETIC_BINDINGS",
        ("quantity_sort", "result_variant"),
    ),
}
EXPECTED_MODULE_INIT = {
    "source_field": "init_contribution",
    "selection": "ACTIVE_MODULES_ONLY",
    "order": "ASCENDING_MODULE_NAME",
    "single": "SOURCE_TERM_IDENTITY",
    "multiple": "OUTER_TERM_AND_NO_FLATTEN_NO_DEDUPLICATION",
    "origin": "EXACT_MODULE_AND_SOURCE_BODY_ARTIFACT",
}
EXPECTED_EVENT_TOTALIZATION = {
    "channel_domain": "ALL_DEPENDENCY_EVENT_CHANNELS",
    "owned_channels": "ALL_CHANNELS_DECLARED_BY_ACTION_OWNER_MODULE",
    "source_emit_domain": "EXACT_OWNED_CHANNELS",
    "non_owner_coordinate": "SYNTHESIZED_EXACT_TYPED_NONE",
    "coordinate_order": "ASCENDING_QUALIFIED_CHANNEL_NAME",
    "source_none_origin": "DECLARED_SOURCE_EMIT_NOT_SYNTHESIZED",
    "empty_event": "SYNTHESIZED_EXACT_TYPED_NONE_AT_EVERY_CHANNEL",
}
EXPECTED_IDENTITY = {
    "hash": "sha256",
    "encoding": "DL-F0-CJSON-1",
    "id_domain_template": "DL-F0-5|ID|{K}|v1|DL-F0-CJSON-1|",
    "model_artifact_domain": "DL-F0-5|ID|MODEL_ARTIFACT|v1|DL-F0-CJSON-1|",
    "module_artifact_domain": "DL-F0-5|ID|MODULE_ARTIFACT|v1|DL-F0-CJSON-1|",
    "source_declaration_domain": "DL-F0-5|ID|SOURCE_DECLARATION_ARTIFACT|v1|DL-F0-CJSON-1|",
    "body_origin_domain": "DL-F0-5|ID|BODY_ORIGIN|v1|DL-F0-CJSON-1|",
    "source_action_artifact_domain": "DL-F0-5|ID|SOURCE_ACTION_ARTIFACT|v1|DL-F0-CJSON-1|",
    "linked_construction_domain": "DL-F0-5|ID|LINKED_MODEL_CONSTRUCTION|v1|DL-F0-CJSON-1|",
    "semantic_projection_construction_domain": "DL-F0-5|ID|LINKED_SEMANTIC_PROJECTION_CONSTRUCTION|v1|DL-F0-CJSON-1|",
    "typed_id_wire": "OBJECT_WITH_KIND_VERSION_ALGORITHM_SHA256",
    "model_artifact_id": "ISSUED_FROM_EXACT_CANONICAL_SOURCE_MODEL",
    "source_action_artifact_id": "ISSUED_FROM_TYPED_MODULE_ARTIFACT_ID_AND_ACTION_QNAME",
    "construction_binder_spelling_policy": "IDENTITY_SIGNIFICANT",
    "future_semantic_alpha_policy": "UNRESOLVED_BLOCKS_FINAL_SEMANTIC_ID_ISSUANCE",
    "source_action_semantic_id": "DEFERRED_UNTIL_SEMANTIC_CONTEXT_AND_REFERENCE_GRAPH",
    "linked_action_semantic_id": "DEFERRED_UNTIL_STATE_CARRIER_EVENT_COMPLETION_AND_OBSERVER_PLAN",
    "linked_action_id": "DEFERRED_UNTIL_MODEL_ARTIFACT_AND_OBSERVER_PLAN",
}
EXPECTED_IDENTITY_PREIMAGES = {
    "BODY_ORIGIN": (
        "body_origin_domain",
        ("module_artifact_id", "locator"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "LINKED_MODEL_CONSTRUCTION": (
        "linked_construction_domain",
        ("schema_version", "language_id", "source_binding", "linked_model"),
        "EXACT_CONSTRUCTION_OCCURRENCE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "LINKED_SEMANTIC_PROJECTION_CONSTRUCTION": (
        "semantic_projection_construction_domain",
        ("linked_model",),
        "STABLE_UNDER_DORMANT_BODY_ONLY_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "MODEL_ARTIFACT": (
        "model_artifact_domain",
        ("canonical_source_model",),
        "EXACT_CANONICAL_SOURCE_BYTES",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "MODULE_ARTIFACT": (
        "module_artifact_domain",
        ("owner_module", "module_node"),
        "EXACT_OWNER_MODULE_NODE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "SOURCE_ACTION_ARTIFACT": (
        "source_action_artifact_domain",
        ("module_artifact_id", "action_name"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "SOURCE_DECLARATION_ARTIFACT": (
        "source_declaration_domain",
        ("owner_module", "declaration_node"),
        "STABLE_UNDER_UNRELATED_OWNER_MODULE_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
}
EXPECTED_SOURCE_BINDING_FIELDS = (
    "root_module",
    "canonical_model_sha256",
    "model_artifact_id",
    "module_manifest",
    "declaration_artifact_manifest",
    "body_origin_manifest",
    "source_action_artifacts",
)
EXPECTED_LINKED_MODEL_FIELDS = (
    "language_id",
    "dependency_modules",
    "active_modules",
    "inactive_modules",
    "sigma",
    "class_premise_bodies",
    "init",
    "action_bodies",
    "base_claim_bodies",
)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _typed_id(kind: str, domain: str, preimage: Any) -> dict[str, Any]:
    return {
        "kind": kind,
        "version": 1,
        "algorithm": "sha256",
        "sha256": sha256(domain.encode("ascii") + canonical_bytes(preimage)),
    }


def _qname_key(value: list[str]) -> bytes:
    return canonical_bytes(value)


def _typed_none(payload_variant: list[str]) -> dict[str, Any]:
    payload_sort = {"tag": "SORT_VARIANT", "variant": copy.deepcopy(payload_variant)}
    return {
        "tag": "TYPED_TERM",
        "result_sort": {"tag": "SORT_OPTION", "element": copy.deepcopy(payload_sort)},
        "node": {
            "tag": "TERM_NONE",
            "element_sort": payload_sort,
        },
    }


@dataclass(frozen=True)
class LinkedModelSnapshot:
    source_binding_raw: bytes
    linked_model_raw: bytes
    artifact_raw: bytes
    model_artifact_id: Mapping[str, Any]
    semantic_projection_construction_id: Mapping[str, Any]
    linked_model_construction_id: Mapping[str, Any]
    link_rule_observations: tuple[str, ...]

    def source_binding(self) -> dict[str, Any]:
        return json.loads(self.source_binding_raw.decode("ascii"))

    def linked_model(self) -> dict[str, Any]:
        return json.loads(self.linked_model_raw.decode("ascii"))

    def artifact(self) -> dict[str, Any]:
        return json.loads(self.artifact_raw.decode("ascii"))


def materialize(
    source_snapshot: Any,
    rule_contract: Any,
    reject: Callable[[str, str], None],
    *,
    max_event_coordinates: int | None = None,
    inconclusive: Callable[[str, str], None] | None = None,
) -> LinkedModelSnapshot:
    contract = rule_contract.link_materialization
    observations: set[str] = set()

    def observe(path: str, actual: Any, expected: Any) -> Any:
        if type(actual) is not type(expected) or actual != expected:
            reject(
                "F05-LINK-RULE-NOT-IMPLEMENTED",
                f"{path}:actual={actual!r} expected={expected!r}",
            )
        observations.add(path)
        return actual

    observe("link_materialization.status", contract.status, EXPECTED_LINK_STATUS)
    actual_declaration_rules = {
        tag: (
            rule.signature_fields,
            rule.signature_derived,
            rule.body_kind,
            rule.body_fields,
            rule.carrier_role,
        )
        for tag, rule in contract.declaration_rules.items()
    }
    if set(actual_declaration_rules) != set(EXPECTED_DECLARATION_RULES):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "declaration rule domain")
    for tag, expected in EXPECTED_DECLARATION_RULES.items():
        observe(
            f"link_materialization.declaration_rules.{tag}",
            actual_declaration_rules[tag],
            expected,
        )
    actual_always_rules = {
        tag: (rule.target, rule.fields)
        for tag, rule in contract.always_linked_rules.items()
    }
    if set(actual_always_rules) != set(EXPECTED_ALWAYS_LINKED_RULES):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "always-linked rule domain")
    for tag, expected in EXPECTED_ALWAYS_LINKED_RULES.items():
        observe(
            f"link_materialization.always_linked_rules.{tag}",
            actual_always_rules[tag],
            expected,
        )
    for field, expected in EXPECTED_MODULE_INIT.items():
        observe(
            f"link_materialization.module_init.{field}",
            contract.module_init.get(field),
            expected,
        )
    if set(contract.module_init) != set(EXPECTED_MODULE_INIT):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "module-init field domain")
    for field, expected in EXPECTED_EVENT_TOTALIZATION.items():
        observe(
            f"link_materialization.event_totalization.{field}",
            contract.event_totalization.get(field),
            expected,
        )
    if set(contract.event_totalization) != set(EXPECTED_EVENT_TOTALIZATION):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "event field domain")
    for field, expected in EXPECTED_IDENTITY.items():
        observe(
            f"link_materialization.identity.{field}",
            contract.identity.get(field),
            expected,
        )
    if set(contract.identity) != set(EXPECTED_IDENTITY):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "identity field domain")
    actual_identity_preimages = {
        kind: (
            rule.domain_field,
            rule.fields,
            rule.stability,
            rule.binder_policy,
        )
        for kind, rule in contract.identity_preimages.items()
    }
    if set(actual_identity_preimages) != set(EXPECTED_IDENTITY_PREIMAGES):
        reject("F05-LINK-RULE-NOT-IMPLEMENTED", "identity preimage domain")
    for kind, expected in EXPECTED_IDENTITY_PREIMAGES.items():
        observe(
            f"link_materialization.identity_preimages.{kind}",
            actual_identity_preimages[kind],
            expected,
        )
    observe(
        "link_materialization.source_binding_fields",
        contract.source_binding_fields,
        EXPECTED_SOURCE_BINDING_FIELDS,
    )
    observe(
        "link_materialization.linked_model_fields",
        contract.linked_model_fields,
        EXPECTED_LINKED_MODEL_FIELDS,
    )
    observe(
        "link_materialization.final_identity_issued",
        contract.final_identity_issued,
        False,
    )

    identity = contract.identity
    try:
        model = source_snapshot.parse_model()
    except Exception as exc:
        reject("F05-LINK-SOURCE-SNAPSHOT", f"{type(exc).__name__}:{exc}")
    model_raw = bytes(source_snapshot.canonical_model_raw)
    if canonical_bytes(model) != model_raw:
        reject("F05-LINK-SOURCE-SNAPSHOT", "parsed model differs from canonical bytes")
    modules: dict[str, dict[str, Any]] = {}
    for module in model["modules"]:
        module_name = module["name"]
        if module_name in modules:
            reject("F05-LINK-DUPLICATE-MODULE", module_name)
        modules[module_name] = module
    active_modules = frozenset(model["active_modules"])
    if len(active_modules) != len(model["active_modules"]):
        reject("F05-LINK-DUPLICATE-ACTIVE-MODULE", repr(model["active_modules"]))
    if model["root_module"] not in active_modules:
        reject("F05-LINK-INACTIVE-ROOT", model["root_module"])
    if not active_modules <= set(modules):
        reject("F05-LINK-UNKNOWN-ACTIVE-MODULE", repr(sorted(active_modules - set(modules))))
    owned_event_channels: dict[str, dict[tuple[str, str], dict[str, Any]]] = {
        module_name: {} for module_name in modules
    }
    for module_name, module in modules.items():
        for declaration in module["declarations"]:
            if declaration["tag"] == "DECL_EVENT_CHANNEL":
                channel_name = tuple(declaration["name"])
                if channel_name in owned_event_channels[module_name]:
                    reject("F05-LINK-DUPLICATE-EVENT-CHANNEL", repr(channel_name))
                owned_event_channels[module_name][channel_name] = declaration
    model_artifact_id = _typed_id(
        "MODEL_ARTIFACT",
        identity["model_artifact_domain"],
        model,
    )

    module_digests: dict[str, str] = {}
    module_artifact_ids: dict[str, dict[str, Any]] = {}
    module_manifest: list[dict[str, Any]] = []
    declaration_manifest: list[dict[str, Any]] = []
    body_origin_manifest: list[dict[str, Any]] = []
    source_action_artifacts: list[dict[str, Any]] = []
    body_locator_keys: set[bytes] = set()

    def module_digest(module_name: str) -> str:
        digest = module_digests.get(module_name)
        if digest is None:
            digest = sha256(MODULE_DIGEST_DOMAIN + canonical_bytes(modules[module_name]))
            module_digests[module_name] = digest
        return digest

    def module_artifact_id(module_name: str) -> dict[str, Any]:
        artifact_id = module_artifact_ids.get(module_name)
        if artifact_id is None:
            artifact_id = _typed_id(
                "MODULE_ARTIFACT",
                identity["module_artifact_domain"],
                {
                    "owner_module": module_name,
                    "module_node": modules[module_name],
                },
            )
            module_artifact_ids[module_name] = artifact_id
        return copy.deepcopy(artifact_id)

    def body_origin(module_name: str, locator: dict[str, Any]) -> None:
        locator_key = canonical_bytes(locator)
        if locator_key in body_locator_keys:
            reject("F05-LINK-DUPLICATE-BODY-LOCATOR", locator_key.decode("ascii"))
        body_locator_keys.add(locator_key)
        body_origin_manifest.append(
            {
                "owner_module": module_name,
                "locator": copy.deepcopy(locator),
                "body_origin_id": _typed_id(
                    "BODY_ORIGIN",
                    identity["body_origin_domain"],
                    {
                        "module_artifact_id": module_artifact_id(module_name),
                        "locator": locator,
                    },
                ),
            }
        )

    for module_name in sorted(modules):
        module = modules[module_name]
        module_manifest.append(
            {
                "module_name": module_name,
                "module_content_sha256": module_digest(module_name),
                "module_artifact_id": module_artifact_id(module_name),
                "direct_imports": [
                    {
                        "module": imported["module"],
                        "artifact_sha256": imported["artifact_sha256"],
                    }
                    for imported in sorted(
                        module["imports"], key=lambda item: item["module"]
                    )
                ],
                "activation": (
                    "ACTIVE" if module_name in active_modules else "DORMANT"
                ),
            }
        )
        body_origin(module_name, {"kind": "MODULE_INIT", "module": module_name})
        for declaration_index, declaration in enumerate(module["declarations"]):
            declaration_id = _typed_id(
                "SOURCE_DECLARATION_ARTIFACT",
                identity["source_declaration_domain"],
                {"owner_module": module_name, "declaration": declaration},
            )
            declaration_manifest.append(
                {
                    "owner_module": module_name,
                    "declaration_index": declaration_index,
                    "declaration_tag": declaration["tag"],
                    "source_locator": (
                        {
                            "kind": "NAMED_DECLARATION",
                            "name": copy.deepcopy(declaration["name"]),
                        }
                        if "name" in declaration
                        else {
                            "kind": "UNNAMED_DECLARATION",
                            "declaration_index": declaration_index,
                        }
                    ),
                    "source_declaration_artifact_id": declaration_id,
                }
            )
            tag = declaration["tag"]
            if tag == "DECL_ACTION":
                action_name = copy.deepcopy(declaration["name"])
                source_action_artifacts.append(
                    {
                        "action_name": action_name,
                        "source_action_artifact_id": _typed_id(
                            "SOURCE_ACTION_ARTIFACT",
                            identity["source_action_artifact_domain"],
                            {
                                "module_artifact_id": module_artifact_id(module_name),
                                "action_name": action_name,
                            },
                        ),
                    }
                )
                body_origin(
                    module_name,
                    {"kind": "ACTION_INVOKE", "action_name": action_name},
                )
                for branch in declaration["branches"]:
                    branch_name = branch["branch"]
                    body_origin(
                        module_name,
                        {
                            "kind": "ACTION_GUARD",
                            "action_name": action_name,
                            "branch": branch_name,
                        },
                    )
                    for update_index, _ in enumerate(branch["updates"]):
                        body_origin(
                            module_name,
                            {
                                "kind": "ACTION_UPDATE",
                                "action_name": action_name,
                                "branch": branch_name,
                                "update_index": update_index,
                            },
                        )
                    for emit in branch["emits"]:
                        body_origin(
                            module_name,
                            {
                                "kind": "ACTION_EMIT",
                                "action_name": action_name,
                                "branch": branch_name,
                                "event_channel": copy.deepcopy(emit["event_channel"]),
                            },
                        )
            elif tag == "DECL_PREMISE":
                body_origin(
                    module_name,
                    {
                        "kind": "CLASS_PREMISE",
                        "premise_name": copy.deepcopy(declaration["name"]),
                    },
                )
            elif tag == "DECL_CLAIM_BASE_ALWAYS":
                body_origin(
                    module_name,
                    {
                        "kind": "BASE_CLAIM",
                        "claim_name": copy.deepcopy(declaration["name"]),
                    },
                )

    declaration_manifest.sort(
        key=lambda entry: (entry["owner_module"], entry["declaration_index"])
    )
    body_origin_manifest.sort(key=lambda entry: canonical_bytes(entry["locator"]))
    source_action_artifacts.sort(key=lambda entry: _qname_key(entry["action_name"]))

    source_binding = {
        "root_module": model["root_module"],
        "canonical_model_sha256": sha256(model_raw),
        "model_artifact_id": model_artifact_id,
        "module_manifest": module_manifest,
        "declaration_artifact_manifest": declaration_manifest,
        "body_origin_manifest": body_origin_manifest,
        "source_action_artifacts": source_action_artifacts,
    }
    if tuple(source_binding) != contract.source_binding_fields:
        reject(
            "F05-LINK-SOURCE-BINDING-FIELDS",
            f"actual={tuple(source_binding)} expected={contract.source_binding_fields}",
        )

    declaration_signatures: list[dict[str, Any]] = []
    constant_constraints: list[dict[str, Any]] = []
    arithmetic_bindings: list[dict[str, Any]] = []
    state_products: list[dict[str, Any]] = []
    event_channels: list[dict[str, Any]] = []
    class_premises: list[dict[str, Any]] = []
    action_declarations: list[tuple[str, dict[str, Any]]] = []
    base_claims: list[dict[str, Any]] = []

    for module_name in sorted(modules):
        for declaration in modules[module_name]["declarations"]:
            tag = declaration["tag"]
            projection_rule = contract.declaration_rules.get(tag)
            if projection_rule is not None:
                signature = {
                    field: copy.deepcopy(declaration[field])
                    for field in projection_rule.signature_fields
                }
                derived: dict[str, Any] = {}
                if projection_rule.signature_derived:
                    if projection_rule.signature_derived != (
                        "BRANCH_NAMES:EACH:branches:branch",
                    ):
                        reject("F05-LINK-SIGNATURE-DERIVATION", tag)
                    derived["branch_names"] = [
                        branch["branch"] for branch in declaration["branches"]
                    ]
                declaration_signatures.append(
                    {
                        "declaration_tag": tag,
                        "owner_module": module_name,
                        "signature": signature,
                        "derived": derived,
                        "carrier_role": projection_rule.carrier_role,
                        "body_kind": projection_rule.body_kind,
                    }
                )
                if projection_rule.carrier_role == "STATE_PRODUCT":
                    state_products.append(
                        {
                            "name": copy.deepcopy(declaration["name"]),
                            "key_sort": copy.deepcopy(declaration["key_sort"]),
                            "value_sort": copy.deepcopy(declaration["value_sort"]),
                        }
                    )
                elif projection_rule.carrier_role == "EVENT_CHANNEL":
                    payload_sort = {
                        "tag": "SORT_VARIANT",
                        "variant": copy.deepcopy(declaration["payload_variant"]),
                    }
                    event_channels.append(
                        {
                            "name": copy.deepcopy(declaration["name"]),
                            "payload_sort": payload_sort,
                        }
                    )
                if module_name in active_modules:
                    if projection_rule.body_kind == "CLASS_PREMISE":
                        class_premises.append(
                            {
                                "name": copy.deepcopy(declaration["name"]),
                                "owner_module": module_name,
                                "body": copy.deepcopy(declaration["body"]),
                            }
                        )
                    elif projection_rule.body_kind == "ACTION":
                        action_declarations.append((module_name, declaration))
                    elif projection_rule.body_kind == "BASE_CLAIM":
                        base_claims.append(
                            {
                                "name": copy.deepcopy(declaration["name"]),
                                "owner_module": module_name,
                                "invariant": copy.deepcopy(declaration["invariant"]),
                            }
                        )
                continue
            always_rule = contract.always_linked_rules.get(tag)
            if always_rule is None:
                reject("F05-LINK-DECLARATION-RULE-MISSING", tag)
            linked_entry = {
                "owner_module": module_name,
                **{
                    field: copy.deepcopy(declaration[field])
                    for field in always_rule.fields
                },
            }
            if always_rule.target == "CONSTANT_CONSTRAINTS":
                constant_constraints.append(linked_entry)
            elif always_rule.target == "ARITHMETIC_BINDINGS":
                arithmetic_bindings.append(linked_entry)
            else:
                reject("F05-LINK-UNNAMED-TARGET", always_rule.target)

    declaration_signatures.sort(
        key=lambda entry: _qname_key(entry["signature"]["name"])
    )
    constant_constraints.sort(key=canonical_bytes)
    arithmetic_bindings.sort(key=canonical_bytes)
    state_products.sort(key=lambda entry: _qname_key(entry["name"]))
    event_channels.sort(key=lambda entry: _qname_key(entry["name"]))
    class_premises.sort(key=lambda entry: _qname_key(entry["name"]))
    action_declarations.sort(key=lambda entry: _qname_key(entry[1]["name"]))
    base_claims.sort(key=lambda entry: _qname_key(entry["name"]))

    branch_total = sum(
        len(declaration["branches"])
        for _, declaration in action_declarations
    )
    event_coordinate_total = branch_total * len(event_channels)
    if (
        max_event_coordinates is not None
        and event_coordinate_total > max_event_coordinates
    ):
        if inconclusive is None:
            raise RuntimeError("linked event-coordinate resource callback missing")
        inconclusive(
            "F05-LINK-INCONCLUSIVE-RESOURCE-EVENT-COORDINATES",
            f"{event_coordinate_total}>{max_event_coordinates}",
        )

    empty_event_template = [
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

    action_bodies: list[dict[str, Any]] = []
    channels_by_name = {
        tuple(channel["name"]): channel for channel in event_channels
    }
    for module_name, declaration in action_declarations:
        owned_names = sorted(
            (
                tuple(channel_name)
                for channel_name in owned_event_channels[module_name]
            )
        )
        branches: list[dict[str, Any]] = []
        for branch in sorted(declaration["branches"], key=lambda item: item["branch"]):
            declared_emits = {
                tuple(emit["event_channel"]): emit for emit in branch["emits"]
            }
            if set(declared_emits) != set(owned_names):
                reject("F05-LINK-SOURCE-EMIT-DOMAIN", repr(declaration["name"]))
            coordinates: list[dict[str, Any]] = []
            for channel_name in sorted(channels_by_name):
                channel = channels_by_name[channel_name]
                if channel_name in declared_emits:
                    emit = declared_emits[channel_name]
                    origin = {
                        "kind": "SOURCE_DECLARED_EMIT",
                        "action_name": copy.deepcopy(declaration["name"]),
                        "branch": branch["branch"],
                        "event_channel": list(channel_name),
                    }
                    value = copy.deepcopy(emit["value"])
                else:
                    origin = {
                        "kind": "LINKER_GENERATED_NON_OWNER_NONE",
                        "rule": "SYNTHESIZED_EXACT_TYPED_NONE",
                        "action_name": copy.deepcopy(declaration["name"]),
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
            branches.append(
                {
                    "branch": branch["branch"],
                    "guard": copy.deepcopy(branch["guard"]),
                    "updates": copy.deepcopy(branch["updates"]),
                    "event_coordinates": coordinates,
                }
            )
        action_bodies.append(
            {
                "name": copy.deepcopy(declaration["name"]),
                "owner_module": module_name,
                "parameter_variable": declaration["parameter_variable"],
                "parameter_sort": copy.deepcopy(declaration["parameter_sort"]),
                "invoke": copy.deepcopy(declaration["invoke"]),
                "owned_channels": [list(name) for name in owned_names],
                "branches": branches,
            }
        )

    active_module_order = sorted(active_modules)
    init_contributions = [
        {
            "module_name": module_name,
            "body": copy.deepcopy(
                modules[module_name][contract.module_init["source_field"]]
            ),
        }
        for module_name in active_module_order
    ]
    if len(init_contributions) == 1:
        init_form = "SINGLE_IDENTITY"
        init_body = copy.deepcopy(init_contributions[0]["body"])
    else:
        init_form = "UNFLATTENED_OUTER_AND"
        init_body = {
            "tag": "TYPED_TERM",
            "result_sort": {"tag": "SORT_BOOL"},
            "node": {
                "tag": "TERM_AND",
                "operands": [
                    copy.deepcopy(contribution["body"])
                    for contribution in init_contributions
                ],
            },
        }

    sigma = {
        "declaration_signatures": declaration_signatures,
        "constant_constraints": constant_constraints,
        "arithmetic_bindings": arithmetic_bindings,
        "state_product_carriers": state_products,
        "event_channel_carriers": event_channels,
        "empty_event_template": empty_event_template,
    }
    linked_model = {
        "language_id": LANGUAGE_ID,
        "dependency_modules": sorted(modules),
        "active_modules": active_module_order,
        "inactive_modules": sorted(set(modules) - set(active_modules)),
        "sigma": sigma,
        "class_premise_bodies": class_premises,
        "init": {
            "form": init_form,
            "ordered_contributions": init_contributions,
            "body": init_body,
        },
        "action_bodies": action_bodies,
        "base_claim_bodies": base_claims,
    }
    if tuple(linked_model) != contract.linked_model_fields:
        reject(
            "F05-LINK-LINKED-MODEL-FIELDS",
            f"actual={tuple(linked_model)} expected={contract.linked_model_fields}",
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
    artifact = {
        "schema_version": 1,
        "artifact_id": ARTIFACT_ID,
        "status": "construction_materialized_not_independently_validated",
        "link_rule_observations": sorted(observations),
        "source_binding": source_binding,
        "linked_model": linked_model,
        "linked_semantic_projection_construction_id": semantic_projection_id,
        "linked_model_construction_id": construction_id,
        "authorization": {
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
        },
    }
    return LinkedModelSnapshot(
        source_binding_raw=canonical_bytes(source_binding),
        linked_model_raw=canonical_bytes(linked_model),
        artifact_raw=canonical_bytes(artifact),
        model_artifact_id=copy.deepcopy(model_artifact_id),
        semantic_projection_construction_id=copy.deepcopy(semantic_projection_id),
        linked_model_construction_id=copy.deepcopy(construction_id),
        link_rule_observations=tuple(sorted(observations)),
    )
