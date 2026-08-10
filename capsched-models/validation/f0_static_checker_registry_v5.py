"""Independent DL-F0-5 static-checker handler registry.

This registry intentionally does not import the machine rule-table validator.
Parity between the two independently maintained descriptions is checked before
the semantic checker consumes either one.
"""

from __future__ import annotations

from types import MappingProxyType
from typing import Any, Mapping, NamedTuple


REGISTRY_ID = "DL-F0-5-STATIC-CHECKER-REGISTRY-1"
PROVENANCE_COMBINER = (
    "SET_UNION_EXACT_TERM_OPERANDS_CONTEXT_VARIABLES_AND_INTRODUCED_SOURCES"
)


def _frozen(values: dict[str, Any]) -> Mapping[str, Any]:
    return MappingProxyType(values)


class TermHandler(NamedTuple):
    typing_rule: str
    result_rule: str
    provenance_rule: str
    binder_rule: str


class DeclarationLinkHandler(NamedTuple):
    signature_fields: tuple[str, ...]
    signature_derived: tuple[str, ...]
    body_kind: str
    body_fields: tuple[str, ...]
    carrier_role: str


class AlwaysLinkedHandler(NamedTuple):
    target: str
    fields: tuple[str, ...]


class IdentityPreimageHandler(NamedTuple):
    domain_field: str
    fields: tuple[str, ...]
    stability: str
    binder_policy: str


PHASE_HANDLERS = _frozen({
    "STATIC": ("ANY", frozenset()),
    "STATE_TERM": ("ANY", frozenset({"PRE"})),
    "STATE_PRED": ("BOOL", frozenset({"PRE"})),
    "ACTION_TERM": ("ANY", frozenset({"PARAM", "PRE"})),
    "ACTION_PRED": ("BOOL", frozenset({"PARAM", "PRE"})),
    "REL_TERM": ("ANY", frozenset({"EVENT", "PARAM", "POST", "PRE"})),
    "REL_PRED": ("BOOL", frozenset({"EVENT", "PARAM", "POST", "PRE"})),
})

LINK_HANDLERS = _frozen({
    "dependency_modules": "REFLEXIVE_TRANSITIVE_ROOT_IMPORT_CLOSURE_EQUALS_EMBEDDED_MODULES",
    "active_modules": "CANONICAL_NONEMPTY_SUBSET_CONTAINING_ROOT",
    "active_import_closure": "NOT_REQUIRED_EXPLICIT_ACTIVATION_ONLY",
    "visibility": "SELF_UNION_DIRECT_IMPORTS_NO_REEXPORT",
    "signature": "DISJOINT_QUALIFIED_UNION_OF_DEPENDENCY_DECLARATIONS",
    "carrier_declarations": "STATE_PRODUCTS_AND_EVENT_CHANNELS_FROM_ALL_DEPENDENCY_MODULES",
    "constant_constraints": "ALL_DEPENDENCY_MODULES_AS_SIGNATURE_INTERPRETATION_CONSTRAINTS",
    "embedded_body_static_validation": "ALL_DEPENDENCY_MODULES_BEFORE_ACTIVATION",
    "active_bodies": "PREMISE_INIT_ACTION_CLAIM_CONTRIBUTIONS_FROM_ACTIVE_MODULES_ONLY",
    "inactive_channel_bundle_coordinates": "PRESENT_AND_TYPED_NONE_FOR_EVERY_ACTION",
    "claim_package_claims": "ACTIVE_BASE_CLAIM_NAMES_ONLY",
    "declaration_ownership": "NAMESPACE_PROVENANCE_NOT_RUNTIME_AUTHORITY",
    "init": "CANONICAL_MODULE_ORDER_CONJUNCTION_WITH_ORIGIN_CONTEXT",
    "linked_model_materialization": "CONSTRUCTION_MATERIALIZATION_V1_WITH_LOCAL_CROSS_IMPLEMENTATION_RECONSTRUCTION_NOT_EXTERNAL_REVIEW",
    "imports_authorize_effects": False,
    "module_content_digest_domain": "DL-F0-5|MODULE|DL-F0-CJSON-1|",
    "same_snapshot_for_wire_and_semantics": True,
})

RELATION_BOUNDARY = _frozen({
    "REL_TERM_and_REL_PRED": "RESERVED_NO_SOURCE_RELATION_BODY_AST",
    "TERM_POST_GET": "RELATION_ONLY_COMPONENT_TYPECHECK_NOT_SOURCE_BODY",
    "TERM_EVENT_GET": "RELATION_ONLY_COMPONENT_TYPECHECK_NOT_SOURCE_BODY",
    "required_future_context": "EXACT_ACTION_PARAMETER_PRE_POST_EVENT_AND_ACTION_IDENTITY",
})

LINK_MATERIALIZATION_STATUS = "CONSTRUCTION_SPEC_NOT_COMPLETION_CLAIM"
DECLARATION_LINK_HANDLERS = _frozen({
    "DECL_ATOM": DeclarationLinkHandler(("name", "carrier_class"), (), "NONE", (), "NONE"),
    "DECL_ENUM": DeclarationLinkHandler(("name", "members"), (), "NONE", (), "NONE"),
    "DECL_UNIT": DeclarationLinkHandler(("name",), (), "NONE", (), "NONE"),
    "DECL_LIMIT": DeclarationLinkHandler(("name",), (), "NONE", (), "NONE"),
    "DECL_RECORD": DeclarationLinkHandler(("name", "fields"), (), "NONE", (), "NONE"),
    "DECL_VARIANT": DeclarationLinkHandler(("name", "variant_tags"), (), "NONE", (), "NONE"),
    "DECL_CONSTANT": DeclarationLinkHandler(("name", "sort"), (), "NONE", (), "NONE"),
    "DECL_STATE_PRODUCT": DeclarationLinkHandler(
        ("name", "key_sort", "value_sort"), (), "NONE", (), "STATE_PRODUCT"
    ),
    "DECL_EVENT_CHANNEL": DeclarationLinkHandler(
        ("name", "payload_variant"), (), "NONE", (), "EVENT_CHANNEL"
    ),
    "DECL_ACTION": DeclarationLinkHandler(
        ("name", "parameter_sort"),
        ("BRANCH_NAMES:EACH:branches:branch",),
        "ACTION",
        ("parameter_variable", "invoke", "branches"),
        "NONE",
    ),
    "DECL_PREMISE": DeclarationLinkHandler(
        ("name",), (), "CLASS_PREMISE", ("body",), "NONE"
    ),
    "DECL_CLAIM_BASE_ALWAYS": DeclarationLinkHandler(
        ("name",), (), "BASE_CLAIM", ("invariant",), "NONE"
    ),
})
ALWAYS_LINKED_HANDLERS = _frozen({
    "DECL_CONSTANT_CONSTRAINT": AlwaysLinkedHandler(
        "CONSTANT_CONSTRAINTS", ("constraint",)
    ),
    "DECL_ARITH_RESULT_BINDING": AlwaysLinkedHandler(
        "ARITHMETIC_BINDINGS", ("quantity_sort", "result_variant")
    ),
})
MODULE_INIT_LINK = _frozen({
    "source_field": "init_contribution",
    "selection": "ACTIVE_MODULES_ONLY",
    "order": "ASCENDING_MODULE_NAME",
    "single": "SOURCE_TERM_IDENTITY",
    "multiple": "OUTER_TERM_AND_NO_FLATTEN_NO_DEDUPLICATION",
    "origin": "EXACT_MODULE_AND_SOURCE_BODY_ARTIFACT",
})
EVENT_TOTALIZATION = _frozen({
    "channel_domain": "ALL_DEPENDENCY_EVENT_CHANNELS",
    "owned_channels": "ALL_CHANNELS_DECLARED_BY_ACTION_OWNER_MODULE",
    "source_emit_domain": "EXACT_OWNED_CHANNELS",
    "non_owner_coordinate": "SYNTHESIZED_EXACT_TYPED_NONE",
    "coordinate_order": "ASCENDING_QUALIFIED_CHANNEL_NAME",
    "source_none_origin": "DECLARED_SOURCE_EMIT_NOT_SYNTHESIZED",
    "empty_event": "SYNTHESIZED_EXACT_TYPED_NONE_AT_EVERY_CHANNEL",
})
LINK_IDENTITY = _frozen({
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
})
IDENTITY_PREIMAGE_HANDLERS = _frozen({
    "BODY_ORIGIN": IdentityPreimageHandler(
        "body_origin_domain",
        ("module_artifact_id", "locator"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "LINKED_MODEL_CONSTRUCTION": IdentityPreimageHandler(
        "linked_construction_domain",
        ("schema_version", "language_id", "source_binding", "linked_model"),
        "EXACT_CONSTRUCTION_OCCURRENCE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "LINKED_SEMANTIC_PROJECTION_CONSTRUCTION": IdentityPreimageHandler(
        "semantic_projection_construction_domain",
        ("linked_model",),
        "STABLE_UNDER_DORMANT_BODY_ONLY_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "MODEL_ARTIFACT": IdentityPreimageHandler(
        "model_artifact_domain",
        ("canonical_source_model",),
        "EXACT_CANONICAL_SOURCE_BYTES",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "MODULE_ARTIFACT": IdentityPreimageHandler(
        "module_artifact_domain",
        ("owner_module", "module_node"),
        "EXACT_OWNER_MODULE_NODE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "SOURCE_ACTION_ARTIFACT": IdentityPreimageHandler(
        "source_action_artifact_domain",
        ("module_artifact_id", "action_name"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    "SOURCE_DECLARATION_ARTIFACT": IdentityPreimageHandler(
        "source_declaration_domain",
        ("owner_module", "declaration_node"),
        "STABLE_UNDER_UNRELATED_OWNER_MODULE_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
})
SOURCE_BINDING_FIELDS = (
    "root_module",
    "canonical_model_sha256",
    "model_artifact_id",
    "module_manifest",
    "declaration_artifact_manifest",
    "body_origin_manifest",
    "source_action_artifacts",
)
LINKED_MODEL_FIELDS = (
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
FINAL_IDENTITY_ISSUED = False

SORT_HANDLERS = _frozen({
    "SORT_BOOL": "SORT_BASE_BOOL",
    "SORT_ONE": "SORT_BASE_ONE",
    "SORT_ATOM": "SORT_RESOLVE_ATOM",
    "SORT_ENUM": "SORT_RESOLVE_ENUM",
    "SORT_QTY": "SORT_RESOLVE_UNIT_LIMIT",
    "SORT_RECORD": "SORT_RESOLVE_ACYCLIC_RECORD",
    "SORT_VARIANT": "SORT_RESOLVE_ACYCLIC_VARIANT",
    "SORT_OPTION": "SORT_RECURSIVE_OPTION",
    "SORT_FINSET": "SORT_RECURSIVE_FINSET",
    "SORT_TOTALMAP": "SORT_RECURSIVE_TOTALMAP",
})

PREMISE_HANDLERS = _frozen({
    "PREMISE_CONST_EQ": "PREMISE_SAME_SORT_CONSTANT_EQ",
    "PREMISE_CONST_NEQ": "PREMISE_SAME_SORT_CONSTANT_NEQ",
    "PREMISE_LIMIT_EQ": "PREMISE_NAT_LIMIT_EQ",
    "PREMISE_LIMIT_LE": "PREMISE_NAT_LIMIT_LE",
    "PREMISE_LIMIT_LT": "PREMISE_NAT_LIMIT_LT",
    "PREMISE_LIMIT_GE_NAT": "PREMISE_LIMIT_GE_LITERAL_NAT",
    "PREMISE_ATOM_CARD_EQ": "PREMISE_ATOM_CARDINALITY_EQ",
    "PREMISE_ATOM_CARD_GE": "PREMISE_ATOM_CARDINALITY_GE",
    "PREMISE_NOT": "PREMISE_BOOLEAN_NOT",
    "PREMISE_AND": "PREMISE_BOOLEAN_AND_STRICT",
    "PREMISE_OR": "PREMISE_BOOLEAN_OR_STRICT",
})

_TERM_ROWS = (
    ("TERM_BOOL", "TYPE_BOOL_LITERAL", "BOOL", "EMPTY", "NONE"),
    ("TERM_ONE", "TYPE_ONE_LITERAL", "ONE", "EMPTY", "NONE"),
    ("TERM_ENUM", "TYPE_ENUM_MEMBER", "NAMED_ENUM", "EMPTY", "NONE"),
    ("TERM_QTY_ZERO", "TYPE_QTY_ZERO", "NAMED_QTY", "EMPTY", "NONE"),
    ("TERM_QTY_CHECKED", "TYPE_QTY_CHECKED", "ARITH_RESULT_OF_NAMED_QTY", "EMPTY", "NONE"),
    ("TERM_CONSTANT", "TYPE_CONSTANT_REFERENCE", "DECLARED_CONSTANT_SORT", "EMPTY", "NONE"),
    ("TERM_VARIABLE", "TYPE_VARIABLE_LOOKUP", "CONTEXT_SORT", "CONTEXT_SOURCE", "NONE"),
    ("TERM_LET", "TYPE_LET", "BODY_SORT", "UNION_IMMEDIATE_TERMS", "FRESH_BOUND_SORT_AND_SOURCE"),
    ("TERM_RECORD", "TYPE_RECORD_CONSTRUCTION", "NAMED_RECORD", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_FIELD", "TYPE_RECORD_PROJECTION", "DECLARED_FIELD_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_VARIANT", "TYPE_VARIANT_INJECTION", "NAMED_VARIANT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_MATCH_VARIANT", "TYPE_EXHAUSTIVE_VARIANT_MATCH", "COMMON_BRANCH_SORT", "UNION_IMMEDIATE_TERMS", "FRESH_PAYLOAD_PER_BRANCH_WITH_SCRUTINEE_SOURCE"),
    ("TERM_NONE", "TYPE_OPTION_NONE", "OPTION_OF_DECLARED_ELEMENT", "EMPTY", "NONE"),
    ("TERM_SOME", "TYPE_OPTION_SOME", "OPTION_OF_DECLARED_ELEMENT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_MATCH_OPTION", "TYPE_EXHAUSTIVE_OPTION_MATCH", "COMMON_BRANCH_SORT", "UNION_IMMEDIATE_TERMS", "FRESH_SOME_WITH_SCRUTINEE_SOURCE"),
    ("TERM_SET_EMPTY", "TYPE_FINSET_EMPTY", "FINSET_OF_DECLARED_ELEMENT", "EMPTY", "NONE"),
    ("TERM_SET_INSERT", "TYPE_FINSET_INSERT", "LEFT_FINSET_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_SET_REMOVE", "TYPE_FINSET_REMOVE", "LEFT_FINSET_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_SET_MEMBER", "TYPE_FINSET_MEMBER", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_SET_SUBSET", "TYPE_SAME_FINSET_SUBSET", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_SET_UNION", "TYPE_SAME_FINSET_UNION", "LEFT_FINSET_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_SET_DIFFERENCE", "TYPE_SAME_FINSET_DIFFERENCE", "LEFT_FINSET_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_MAP_GET", "TYPE_TOTALMAP_GET", "MAP_VALUE_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_MAP_SET", "TYPE_TOTALMAP_SET", "MAP_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_AND", "TYPE_BOOL_AND_STRICT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_OR", "TYPE_BOOL_OR_STRICT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_NOT", "TYPE_BOOL_NOT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_IMPLIES", "TYPE_BOOL_IMPLIES_STRICT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_IFF", "TYPE_BOOL_IFF_STRICT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_EQ", "TYPE_SAME_SORT_EQUALITY", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_LT", "TYPE_SAME_QTY_LT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_LE", "TYPE_SAME_QTY_LE", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_GT", "TYPE_SAME_QTY_GT", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_GE", "TYPE_SAME_QTY_GE", "BOOL", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_ADD", "TYPE_CHECKED_QTY_ADD", "ARITH_RESULT_OF_LEFT_QTY", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_QTY_SUB", "TYPE_CHECKED_QTY_SUB", "ARITH_RESULT_OF_LEFT_QTY", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_IF", "TYPE_BOOL_IF_COMMON_BRANCH", "COMMON_BRANCH_SORT", "UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_FORALL", "TYPE_KEYSORT_FORALL", "BOOL", "UNION_IMMEDIATE_TERMS", "FRESH_QUANTIFIED_EMPTY_SOURCE"),
    ("TERM_EXISTS", "TYPE_KEYSORT_EXISTS", "BOOL", "UNION_IMMEDIATE_TERMS", "FRESH_QUANTIFIED_EMPTY_SOURCE"),
    ("TERM_PRE_GET", "TYPE_STATE_PRODUCT_PRE_GET", "STATE_PRODUCT_VALUE_SORT", "PRE_UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_POST_GET", "TYPE_STATE_PRODUCT_POST_GET", "STATE_PRODUCT_VALUE_SORT", "POST_UNION_IMMEDIATE_TERMS", "NONE"),
    ("TERM_EVENT_GET", "TYPE_EVENT_CHANNEL_GET", "OPTION_OF_EVENT_PAYLOAD", "EVENT_ONLY", "NONE"),
)
TERM_HANDLERS = _frozen({
    tag: TermHandler(typing, result, provenance, binder)
    for tag, typing, result, provenance, binder in _TERM_ROWS
})

UPDATE_HANDLERS = _frozen({
    "PUT_UPDATE": ("STATIC_TYPED_POINT_WRITE_PRE_EVALUABLE", "ACTION_TERM"),
    "PATCH_UPDATE": ("STATIC_TYPED_FINITE_PATCH_PRE_EVALUABLE", "ACTION_TERM"),
})

BODY_HANDLERS = _frozen({
    "CONSTANT_CONSTRAINT": ("INTERPRETATION_ONLY", "STATIC_CONSTRAINT", "ALL_DEPENDENCY_MODULES", "ALL_DEPENDENCY_MODULES_SIGNATURE"),
    "CLASS_PREMISE": ("INTERPRETATION_ONLY", "INTERPRETATION_PREMISE", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "MODULE_INIT": ("EMPTY", "STATE_PRED", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "BASE_CLAIM": ("EMPTY", "STATE_PRED", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "ACTION_INVOKE": ("EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE", "ACTION_PRED", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "ACTION_GUARD": ("EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE", "ACTION_PRED", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "ACTION_UPDATE": ("EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE", "ACTION_TERM", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
    "ACTION_EMIT": ("EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE", "ACTION_TERM", "ALL_DEPENDENCY_MODULES", "ACTIVE_MODULES_ONLY"),
})

BINDER_HANDLERS = _frozen({
    "TERM_LET": ("SINGLE", "FIELD:variable", "FIELD:body", "TERM_RESULT:bound", "TERM_PROVENANCE:bound", "INPUT_CONTEXT"),
    "TERM_MATCH_VARIANT": ("EACH_MEMBER", "FIELD:branches", "MEMBER_FIELD:payload_variable", "MEMBER_FIELD:body", "DECLARED_VARIANT_PAYLOAD:variant:variant_tag", "TERM_PROVENANCE:scrutinee", "INPUT_CONTEXT_PER_BRANCH"),
    "TERM_MATCH_OPTION": ("SINGLE", "FIELD:some_variable", "FIELD:some_body", "NODE_SORT:element_sort", "TERM_PROVENANCE:scrutinee", "INPUT_CONTEXT"),
    "TERM_FORALL": ("SINGLE", "FIELD:variable", "FIELD:body", "NODE_SORT:sort", "EMPTY", "INPUT_CONTEXT"),
    "TERM_EXISTS": ("SINGLE", "FIELD:variable", "FIELD:body", "NODE_SORT:sort", "EMPTY", "INPUT_CONTEXT"),
})
