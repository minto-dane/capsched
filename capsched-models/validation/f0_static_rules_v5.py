"""Fail-closed contract loader for the DL-F0-5 static semantics rule table.

This module validates only the construction-time static rule inventory.  It
does not establish implementation parity, CoreSyntaxWF, or F0 acceptance.
"""

from __future__ import annotations

import hashlib
import json
import os
import stat
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping, NoReturn


MODELS = Path(__file__).resolve().parents[1]
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v5"
RULES_PATH = F0 / "f0-static-semantics-rules-v5.json"
GRAMMAR_PATH = F0 / "f0-machine-grammar-v5.json"
MAX_BYTES = 4 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512
EXPECTED_SURFACE_SHA256 = (
    "02503654aae81c865cc1446fe707a49e9c50821603c41bb113dd017f79801039"
)
EXPECTED_GRAMMAR_CANONICAL_SHA256 = (
    "59e03c51c6a31e8c9c26a046dccb3ff06f1bf2aa8445f43f1e006ecdd204c066"
)
SURFACE_FIELDS = (
    "primitive_kinds",
    "primitive_wire_types",
    "collection_kinds",
    "collection_field_policies",
    "kind_unions",
    "kind_bindings",
    "root_kinds",
    "sort_nodes",
    "term_nodes",
    "support_nodes",
    "premise_nodes",
    "declaration_nodes",
    "model_nodes",
    "profile_nodes",
    "ground_value_nodes",
    "scope_nodes",
    "runtime_nodes",
    "semantic_checker_obligations",
    "forbidden_nodes",
)
EXPECTED_TOP_LEVEL = (
    "schema_version",
    "language_id",
    "artifact_id",
    "status",
    "grammar_surface_sha256",
    "provenance_sources",
    "provenance_combiner",
    "phase_rules",
    "link_rules",
    "link_materialization",
    "sort_rules",
    "premise_rules",
    "term_rules",
    "provenance_derivations",
    "binder_derivations",
    "relation_boundary",
    "update_rules",
    "body_rules",
    "nonclaims",
    "authorization",
)
EXPECTED_IDENTITY = {
    "schema_version": 1,
    "language_id": "DL-F0-5",
    "artifact_id": "domainlease-r11-epoch2-f0-static-semantics-rules-v5-draft1",
    "status": "construction_draft_not_review_target",
    "grammar_surface_sha256": EXPECTED_SURFACE_SHA256,
}
EXPECTED_PROVENANCE_SOURCES = ["EVENT", "PARAM", "POST", "PRE"]
EXPECTED_PROVENANCE_COMBINER = (
    "SET_UNION_EXACT_TERM_OPERANDS_CONTEXT_VARIABLES_AND_INTRODUCED_SOURCES"
)
EXPECTED_PHASE_RULES = [
    {"phase": "STATIC", "result": "ANY", "allowed_sources": []},
    {"phase": "STATE_TERM", "result": "ANY", "allowed_sources": ["PRE"]},
    {"phase": "STATE_PRED", "result": "BOOL", "allowed_sources": ["PRE"]},
    {
        "phase": "ACTION_TERM",
        "result": "ANY",
        "allowed_sources": ["PARAM", "PRE"],
    },
    {
        "phase": "ACTION_PRED",
        "result": "BOOL",
        "allowed_sources": ["PARAM", "PRE"],
    },
    {
        "phase": "REL_TERM",
        "result": "ANY",
        "allowed_sources": ["EVENT", "PARAM", "POST", "PRE"],
    },
    {
        "phase": "REL_PRED",
        "result": "BOOL",
        "allowed_sources": ["EVENT", "PARAM", "POST", "PRE"],
    },
]
EXPECTED_LINK_RULES = {
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
}
EXPECTED_DECLARATION_LINK_ROWS = (
    ("DECL_ATOM", ("name", "carrier_class"), (), "NONE", (), "NONE"),
    ("DECL_ENUM", ("name", "members"), (), "NONE", (), "NONE"),
    ("DECL_UNIT", ("name",), (), "NONE", (), "NONE"),
    ("DECL_LIMIT", ("name",), (), "NONE", (), "NONE"),
    ("DECL_RECORD", ("name", "fields"), (), "NONE", (), "NONE"),
    ("DECL_VARIANT", ("name", "variant_tags"), (), "NONE", (), "NONE"),
    ("DECL_CONSTANT", ("name", "sort"), (), "NONE", (), "NONE"),
    (
        "DECL_STATE_PRODUCT",
        ("name", "key_sort", "value_sort"),
        (),
        "NONE",
        (),
        "STATE_PRODUCT",
    ),
    (
        "DECL_EVENT_CHANNEL",
        ("name", "payload_variant"),
        (),
        "NONE",
        (),
        "EVENT_CHANNEL",
    ),
    (
        "DECL_ACTION",
        ("name", "parameter_sort"),
        ("BRANCH_NAMES:EACH:branches:branch",),
        "ACTION",
        ("parameter_variable", "invoke", "branches"),
        "NONE",
    ),
    (
        "DECL_PREMISE",
        ("name",),
        (),
        "CLASS_PREMISE",
        ("body",),
        "NONE",
    ),
    (
        "DECL_CLAIM_BASE_ALWAYS",
        ("name",),
        (),
        "BASE_CLAIM",
        ("invariant",),
        "NONE",
    ),
)
EXPECTED_ALWAYS_LINKED_ROWS = (
    ("DECL_CONSTANT_CONSTRAINT", "CONSTANT_CONSTRAINTS", ("constraint",)),
    (
        "DECL_ARITH_RESULT_BINDING",
        "ARITHMETIC_BINDINGS",
        ("quantity_sort", "result_variant"),
    ),
)
EXPECTED_MODULE_INIT_LINK = {
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
EXPECTED_LINK_IDENTITY = {
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
EXPECTED_IDENTITY_PREIMAGE_ROWS = (
    (
        "BODY_ORIGIN",
        "body_origin_domain",
        ("module_artifact_id", "locator"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "LINKED_MODEL_CONSTRUCTION",
        "linked_construction_domain",
        ("schema_version", "language_id", "source_binding", "linked_model"),
        "EXACT_CONSTRUCTION_OCCURRENCE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "LINKED_SEMANTIC_PROJECTION_CONSTRUCTION",
        "semantic_projection_construction_domain",
        ("linked_model",),
        "STABLE_UNDER_DORMANT_BODY_ONLY_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "MODEL_ARTIFACT",
        "model_artifact_domain",
        ("canonical_source_model",),
        "EXACT_CANONICAL_SOURCE_BYTES",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "MODULE_ARTIFACT",
        "module_artifact_domain",
        ("owner_module", "module_node"),
        "EXACT_OWNER_MODULE_NODE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "SOURCE_ACTION_ARTIFACT",
        "source_action_artifact_domain",
        ("module_artifact_id", "action_name"),
        "INVALIDATED_BY_ANY_OWNER_MODULE_ARTIFACT_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
    (
        "SOURCE_DECLARATION_ARTIFACT",
        "source_declaration_domain",
        ("owner_module", "declaration_node"),
        "STABLE_UNDER_UNRELATED_OWNER_MODULE_CHANGE",
        "SOURCE_SPELLING_SIGNIFICANT",
    ),
)
EXPECTED_SOURCE_BINDING_FIELDS = [
    "root_module",
    "canonical_model_sha256",
    "model_artifact_id",
    "module_manifest",
    "declaration_artifact_manifest",
    "body_origin_manifest",
    "source_action_artifacts",
]
EXPECTED_LINKED_MODEL_FIELDS = [
    "language_id",
    "dependency_modules",
    "active_modules",
    "inactive_modules",
    "sigma",
    "class_premise_bodies",
    "init",
    "action_bodies",
    "base_claim_bodies",
]
EXPECTED_SORT_ROWS = (
    ("SORT_BOOL", "SORT_BASE_BOOL"),
    ("SORT_ONE", "SORT_BASE_ONE"),
    ("SORT_ATOM", "SORT_RESOLVE_ATOM"),
    ("SORT_ENUM", "SORT_RESOLVE_ENUM"),
    ("SORT_QTY", "SORT_RESOLVE_UNIT_LIMIT"),
    ("SORT_RECORD", "SORT_RESOLVE_ACYCLIC_RECORD"),
    ("SORT_VARIANT", "SORT_RESOLVE_ACYCLIC_VARIANT"),
    ("SORT_OPTION", "SORT_RECURSIVE_OPTION"),
    ("SORT_FINSET", "SORT_RECURSIVE_FINSET"),
    ("SORT_TOTALMAP", "SORT_RECURSIVE_TOTALMAP"),
)
EXPECTED_PREMISE_ROWS = (
    ("PREMISE_CONST_EQ", "PREMISE_SAME_SORT_CONSTANT_EQ"),
    ("PREMISE_CONST_NEQ", "PREMISE_SAME_SORT_CONSTANT_NEQ"),
    ("PREMISE_LIMIT_EQ", "PREMISE_NAT_LIMIT_EQ"),
    ("PREMISE_LIMIT_LE", "PREMISE_NAT_LIMIT_LE"),
    ("PREMISE_LIMIT_LT", "PREMISE_NAT_LIMIT_LT"),
    ("PREMISE_LIMIT_GE_NAT", "PREMISE_LIMIT_GE_LITERAL_NAT"),
    ("PREMISE_ATOM_CARD_EQ", "PREMISE_ATOM_CARDINALITY_EQ"),
    ("PREMISE_ATOM_CARD_GE", "PREMISE_ATOM_CARDINALITY_GE"),
    ("PREMISE_NOT", "PREMISE_BOOLEAN_NOT"),
    ("PREMISE_AND", "PREMISE_BOOLEAN_AND_STRICT"),
    ("PREMISE_OR", "PREMISE_BOOLEAN_OR_STRICT"),
)
EXPECTED_TERM_ROWS = (
    ("TERM_BOOL", "TYPE_BOOL_LITERAL", "BOOL", "EMPTY", "NONE"),
    ("TERM_ONE", "TYPE_ONE_LITERAL", "ONE", "EMPTY", "NONE"),
    ("TERM_ENUM", "TYPE_ENUM_MEMBER", "NAMED_ENUM", "EMPTY", "NONE"),
    ("TERM_QTY_ZERO", "TYPE_QTY_ZERO", "NAMED_QTY", "EMPTY", "NONE"),
    (
        "TERM_QTY_CHECKED",
        "TYPE_QTY_CHECKED",
        "ARITH_RESULT_OF_NAMED_QTY",
        "EMPTY",
        "NONE",
    ),
    (
        "TERM_CONSTANT",
        "TYPE_CONSTANT_REFERENCE",
        "DECLARED_CONSTANT_SORT",
        "EMPTY",
        "NONE",
    ),
    (
        "TERM_VARIABLE",
        "TYPE_VARIABLE_LOOKUP",
        "CONTEXT_SORT",
        "CONTEXT_SOURCE",
        "NONE",
    ),
    (
        "TERM_LET",
        "TYPE_LET",
        "BODY_SORT",
        "UNION_IMMEDIATE_TERMS",
        "FRESH_BOUND_SORT_AND_SOURCE",
    ),
    (
        "TERM_RECORD",
        "TYPE_RECORD_CONSTRUCTION",
        "NAMED_RECORD",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_FIELD",
        "TYPE_RECORD_PROJECTION",
        "DECLARED_FIELD_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_VARIANT",
        "TYPE_VARIANT_INJECTION",
        "NAMED_VARIANT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_MATCH_VARIANT",
        "TYPE_EXHAUSTIVE_VARIANT_MATCH",
        "COMMON_BRANCH_SORT",
        "UNION_IMMEDIATE_TERMS",
        "FRESH_PAYLOAD_PER_BRANCH_WITH_SCRUTINEE_SOURCE",
    ),
    (
        "TERM_NONE",
        "TYPE_OPTION_NONE",
        "OPTION_OF_DECLARED_ELEMENT",
        "EMPTY",
        "NONE",
    ),
    (
        "TERM_SOME",
        "TYPE_OPTION_SOME",
        "OPTION_OF_DECLARED_ELEMENT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_MATCH_OPTION",
        "TYPE_EXHAUSTIVE_OPTION_MATCH",
        "COMMON_BRANCH_SORT",
        "UNION_IMMEDIATE_TERMS",
        "FRESH_SOME_WITH_SCRUTINEE_SOURCE",
    ),
    (
        "TERM_SET_EMPTY",
        "TYPE_FINSET_EMPTY",
        "FINSET_OF_DECLARED_ELEMENT",
        "EMPTY",
        "NONE",
    ),
    (
        "TERM_SET_INSERT",
        "TYPE_FINSET_INSERT",
        "LEFT_FINSET_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_SET_REMOVE",
        "TYPE_FINSET_REMOVE",
        "LEFT_FINSET_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_SET_MEMBER",
        "TYPE_FINSET_MEMBER",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_SET_SUBSET",
        "TYPE_SAME_FINSET_SUBSET",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_SET_UNION",
        "TYPE_SAME_FINSET_UNION",
        "LEFT_FINSET_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_SET_DIFFERENCE",
        "TYPE_SAME_FINSET_DIFFERENCE",
        "LEFT_FINSET_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_MAP_GET",
        "TYPE_TOTALMAP_GET",
        "MAP_VALUE_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_MAP_SET",
        "TYPE_TOTALMAP_SET",
        "MAP_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_AND",
        "TYPE_BOOL_AND_STRICT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_OR",
        "TYPE_BOOL_OR_STRICT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_NOT",
        "TYPE_BOOL_NOT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_IMPLIES",
        "TYPE_BOOL_IMPLIES_STRICT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_IFF",
        "TYPE_BOOL_IFF_STRICT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_EQ",
        "TYPE_SAME_SORT_EQUALITY",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_LT",
        "TYPE_SAME_QTY_LT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_LE",
        "TYPE_SAME_QTY_LE",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_GT",
        "TYPE_SAME_QTY_GT",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_GE",
        "TYPE_SAME_QTY_GE",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_ADD",
        "TYPE_CHECKED_QTY_ADD",
        "ARITH_RESULT_OF_LEFT_QTY",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_QTY_SUB",
        "TYPE_CHECKED_QTY_SUB",
        "ARITH_RESULT_OF_LEFT_QTY",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_IF",
        "TYPE_BOOL_IF_COMMON_BRANCH",
        "COMMON_BRANCH_SORT",
        "UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_FORALL",
        "TYPE_KEYSORT_FORALL",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "FRESH_QUANTIFIED_EMPTY_SOURCE",
    ),
    (
        "TERM_EXISTS",
        "TYPE_KEYSORT_EXISTS",
        "BOOL",
        "UNION_IMMEDIATE_TERMS",
        "FRESH_QUANTIFIED_EMPTY_SOURCE",
    ),
    (
        "TERM_PRE_GET",
        "TYPE_STATE_PRODUCT_PRE_GET",
        "STATE_PRODUCT_VALUE_SORT",
        "PRE_UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_POST_GET",
        "TYPE_STATE_PRODUCT_POST_GET",
        "STATE_PRODUCT_VALUE_SORT",
        "POST_UNION_IMMEDIATE_TERMS",
        "NONE",
    ),
    (
        "TERM_EVENT_GET",
        "TYPE_EVENT_CHANNEL_GET",
        "OPTION_OF_EVENT_PAYLOAD",
        "EVENT_ONLY",
        "NONE",
    ),
)
EXPECTED_UPDATE_RULES = [
    {
        "tag": "PUT_UPDATE",
        "rule": "STATIC_TYPED_POINT_WRITE_PRE_EVALUABLE",
        "source_phase": "ACTION_TERM",
    },
    {
        "tag": "PATCH_UPDATE",
        "rule": "STATIC_TYPED_FINITE_PATCH_PRE_EVALUABLE",
        "source_phase": "ACTION_TERM",
    },
]
EXPECTED_BODY_RULES = [
    {
        "body": "CONSTANT_CONSTRAINT",
        "context": "INTERPRETATION_ONLY",
        "phase": "STATIC_CONSTRAINT",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ALL_DEPENDENCY_MODULES_SIGNATURE",
    },
    {
        "body": "CLASS_PREMISE",
        "context": "INTERPRETATION_ONLY",
        "phase": "INTERPRETATION_PREMISE",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "MODULE_INIT",
        "context": "EMPTY",
        "phase": "STATE_PRED",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "BASE_CLAIM",
        "context": "EMPTY",
        "phase": "STATE_PRED",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "ACTION_INVOKE",
        "context": "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE",
        "phase": "ACTION_PRED",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "ACTION_GUARD",
        "context": "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE",
        "phase": "ACTION_PRED",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "ACTION_UPDATE",
        "context": "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE",
        "phase": "ACTION_TERM",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
    {
        "body": "ACTION_EMIT",
        "context": "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE",
        "phase": "ACTION_TERM",
        "static_check_scope": "ALL_DEPENDENCY_MODULES",
        "linked_semantic_scope": "ACTIVE_MODULES_ONLY",
    },
]
EXPECTED_BINDER_DERIVATIONS = [
    {"tag": "TERM_LET", "kind": "SINGLE", "variable": "FIELD:variable", "scope": "FIELD:body", "sort_source": "TERM_RESULT:bound", "provenance_source": "TERM_PROVENANCE:bound", "freshness": "INPUT_CONTEXT"},
    {"tag": "TERM_MATCH_VARIANT", "kind": "EACH_MEMBER", "collection": "FIELD:branches", "variable": "MEMBER_FIELD:payload_variable", "scope": "MEMBER_FIELD:body", "sort_source": "DECLARED_VARIANT_PAYLOAD:variant:variant_tag", "provenance_source": "TERM_PROVENANCE:scrutinee", "freshness": "INPUT_CONTEXT_PER_BRANCH"},
    {"tag": "TERM_MATCH_OPTION", "kind": "SINGLE", "variable": "FIELD:some_variable", "scope": "FIELD:some_body", "sort_source": "NODE_SORT:element_sort", "provenance_source": "TERM_PROVENANCE:scrutinee", "freshness": "INPUT_CONTEXT"},
    {"tag": "TERM_FORALL", "kind": "SINGLE", "variable": "FIELD:variable", "scope": "FIELD:body", "sort_source": "NODE_SORT:sort", "provenance_source": "EMPTY", "freshness": "INPUT_CONTEXT"},
    {"tag": "TERM_EXISTS", "kind": "SINGLE", "variable": "FIELD:variable", "scope": "FIELD:body", "sort_source": "NODE_SORT:sort", "provenance_source": "EMPTY", "freshness": "INPUT_CONTEXT"},
]
EXPECTED_RELATION_BOUNDARY = {
    "REL_TERM_and_REL_PRED": "RESERVED_NO_SOURCE_RELATION_BODY_AST",
    "TERM_POST_GET": "RELATION_ONLY_COMPONENT_TYPECHECK_NOT_SOURCE_BODY",
    "TERM_EVENT_GET": "RELATION_ONLY_COMPONENT_TYPECHECK_NOT_SOURCE_BODY",
    "required_future_context": "EXACT_ACTION_PARAMETER_PRE_POST_EVENT_AND_ACTION_IDENTITY",
}
EXPECTED_NONCLAIMS = [
    "This draft table does not define Eval, Reads, transition, InstanceWF, proof, or F0 acceptance.",
    "A table-shape pass does not prove checker implementation parity or metatheory.",
    "SemanticContextDigest and ValidationContextDigest binding remain incomplete.",
]
EXPECTED_AUTHORIZATION = {
    "construction_draft": True,
    "static_rule_table_complete": False,
    "static_checker_bound": False,
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


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-SR-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _reject_float(token: str) -> NoReturn:
    reject("F05-SR-FLOAT", token)


def _reject_non_json_number(token: str) -> NoReturn:
    reject("F05-SR-NON-JSON-NUMBER", token)


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-SR-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-SR-INTEGER", str(exc))


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def _reject_unsafe_scalar(value: Any, path: str = "$") -> None:
    stack: list[tuple[Any, str, int]] = [(value, path, 0)]
    nodes = 0
    while stack:
        current, current_path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-SR-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-SR-DEPTH", f"{current_path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-SR-UNSAFE-SCALAR", current_path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-SR-NEGATIVE-INTEGER", current_path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-SR-NON-ASCII-STRING", current_path)
            if any(
                ord(character) < 0x20 or ord(character) == 0x7F
                for character in current
            ):
                reject("F05-SR-CONTROL-STRING", current_path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-SR-COLLECTION-LIMIT", current_path)
            for key, child in current.items():
                try:
                    key.encode("ascii")
                except UnicodeEncodeError:
                    reject(
                        "F05-SR-NON-ASCII-KEY",
                        _child_path(current_path, f".{key}"),
                    )
                stack.append(
                    (child, _child_path(current_path, f".{key}"), depth + 1)
                )
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-SR-COLLECTION-LIMIT", current_path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (
                        current[index],
                        _child_path(current_path, f"[{index}]"),
                        depth + 1,
                    )
                )
            continue
        reject("F05-SR-UNSAFE-TYPE", f"{current_path}:{type(current).__name__}")


def read_once(path: Path) -> bytes:
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        reject("F05-SR-FILE-OPEN", f"{path}:{exc.errno}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            reject("F05-SR-FILE-TYPE", str(path))
        if before.st_size <= 0 or before.st_size > MAX_BYTES:
            reject("F05-SR-FILE-SIZE", f"{path}:{before.st_size}")
        chunks: list[bytes] = []
        remaining = MAX_BYTES + 1
        while remaining:
            chunk = os.read(descriptor, min(64 * 1024, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
        after = os.fstat(descriptor)
        identity_before = (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        )
        identity_after = (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        )
        if identity_before != identity_after or len(raw) != before.st_size:
            reject("F05-SR-FILE-CHANGED-DURING-READ", str(path))
        if not raw or len(raw) > MAX_BYTES:
            reject("F05-SR-FILE-SIZE", f"{path}:{len(raw)}")
        return raw
    finally:
        os.close(descriptor)


def parse_ascii_json(raw: bytes, path: Path) -> Any:
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-SR-NON-ASCII-JSON", f"{path}:{exc}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_int=_parse_integer,
            parse_float=_reject_float,
            parse_constant=_reject_non_json_number,
        )
    except Reject:
        raise
    except json.JSONDecodeError as exc:
        reject("F05-SR-JSON", f"{path}:{exc}")
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-SR-PARSE-RESOURCE", f"{path}:{type(exc).__name__}")
    _reject_unsafe_scalar(value)
    return value


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


@dataclass(frozen=True)
class TermRule:
    tag: str
    typing_rule: str
    result_rule: str
    provenance_rule: str
    binder_rule: str


@dataclass(frozen=True)
class ProvenanceRule:
    tag: str
    term_operands: tuple[str, ...]
    context_variable_fields: tuple[str, ...]
    introduced_sources: frozenset[str]


@dataclass(frozen=True)
class DeclarationLinkRule:
    tag: str
    signature_fields: tuple[str, ...]
    signature_derived: tuple[str, ...]
    body_kind: str
    body_fields: tuple[str, ...]
    carrier_role: str


@dataclass(frozen=True)
class AlwaysLinkedRule:
    tag: str
    target: str
    fields: tuple[str, ...]


@dataclass(frozen=True)
class IdentityPreimageRule:
    kind: str
    domain_field: str
    fields: tuple[str, ...]
    stability: str
    binder_policy: str


@dataclass(frozen=True)
class LinkMaterializationContract:
    status: str
    declaration_rules: Mapping[str, DeclarationLinkRule]
    always_linked_rules: Mapping[str, AlwaysLinkedRule]
    module_init: Mapping[str, str]
    event_totalization: Mapping[str, str]
    identity: Mapping[str, str]
    identity_preimages: Mapping[str, IdentityPreimageRule]
    source_binding_fields: tuple[str, ...]
    linked_model_fields: tuple[str, ...]
    final_identity_issued: bool


@dataclass(frozen=True)
class StaticRuleContract:
    rules_raw_sha256: str
    rules_canonical_sha256: str
    grammar_raw_sha256: str
    grammar_canonical_sha256: str
    grammar_surface_sha256: str
    provenance_combiner: str
    phase_rules: Mapping[str, tuple[str, frozenset[str]]]
    link_rules: Mapping[str, Any]
    link_materialization: LinkMaterializationContract
    sort_rules: Mapping[str, str]
    premise_rules: Mapping[str, str]
    term_rules: Mapping[str, TermRule]
    provenance_rules: Mapping[str, ProvenanceRule]
    binder_rules: Mapping[str, Mapping[str, str]]
    relation_boundary: Mapping[str, str]
    update_rules: Mapping[str, tuple[str, str]]
    body_rules: Mapping[str, tuple[str, str, str, str]]


def _type_strict_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(
            _type_strict_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            _type_strict_equal(left, right)
            for left, right in zip(actual, expected, strict=True)
        )
    return actual == expected


def _exact(actual: Any, expected: Any, reject_id: str) -> None:
    if not _type_strict_equal(actual, expected):
        reject(reject_id, f"actual={actual!r} expected={expected!r}")


def _tags(grammar: dict[str, Any], section: str) -> list[str]:
    value = grammar.get(section)
    if not isinstance(value, list):
        reject("F05-SR-GRAMMAR-SHAPE", section)
    result: list[str] = []
    for index, row in enumerate(value):
        if not isinstance(row, dict) or not isinstance(row.get("tag"), str):
            reject("F05-SR-GRAMMAR-SHAPE", f"{section}[{index}]")
        result.append(row["tag"])
    return result


def _split_kind(kind: Any, path: str) -> tuple[str, str | None]:
    if not isinstance(kind, str):
        reject("F05-SR-GRAMMAR-SHAPE", path)
    for suffix in ("[2+]", "[1+]", "[]"):
        if kind.endswith(suffix):
            return kind[: -len(suffix)], suffix
    return kind, None


def _expected_provenance_derivations(
    grammar: dict[str, Any],
) -> list[dict[str, Any]]:
    node_by_tag: dict[str, dict[str, Any]] = {}
    for section in (
        "sort_nodes",
        "term_nodes",
        "support_nodes",
        "premise_nodes",
        "declaration_nodes",
        "model_nodes",
        "profile_nodes",
        "ground_value_nodes",
        "scope_nodes",
        "runtime_nodes",
    ):
        for node in grammar.get(section, []):
            if not isinstance(node, dict) or not isinstance(node.get("tag"), str):
                reject("F05-SR-GRAMMAR-SHAPE", section)
            node_by_tag[node["tag"]] = node
    bindings = grammar.get("kind_bindings")
    if not isinstance(bindings, dict):
        reject("F05-SR-GRAMMAR-SHAPE", "kind_bindings")

    result: list[dict[str, Any]] = []
    for term in grammar.get("term_nodes", []):
        tag = term["tag"]
        selectors: list[str] = []
        for field_name, kind in term["fields"]:
            base, suffix = _split_kind(kind, f"{tag}.{field_name}")
            if base == "Term":
                selectors.append(
                    f"EACH:{field_name}" if suffix is not None else f"FIELD:{field_name}"
                )
                continue
            if suffix is None or base not in bindings:
                continue
            support = node_by_tag.get(bindings[base])
            if support is None:
                reject("F05-SR-GRAMMAR-SHAPE", f"binding:{base}")
            for member_field, member_kind in support["fields"]:
                if member_kind == "Term":
                    selectors.append(
                        f"EACH_MEMBER:{field_name}:{member_field}"
                    )
        result.append(
            {
                "tag": tag,
                "term_operands": selectors,
                "context_variable_fields": ["variable"]
                if tag == "TERM_VARIABLE"
                else [],
                "introduced_sources": {
                    "TERM_PRE_GET": ["PRE"],
                    "TERM_POST_GET": ["POST"],
                    "TERM_EVENT_GET": ["EVENT"],
                }.get(tag, []),
            }
        )
    return result


def validate_loaded(
    rules_raw: bytes,
    grammar_raw: bytes,
    rules_path: Path = RULES_PATH,
    grammar_path: Path = GRAMMAR_PATH,
) -> StaticRuleContract:
    rules = parse_ascii_json(rules_raw, rules_path)
    grammar = parse_ascii_json(grammar_raw, grammar_path)
    if not isinstance(rules, dict) or not isinstance(grammar, dict):
        reject("F05-SR-TOPLEVEL", "rules and grammar must be objects")
    if set(rules) != set(EXPECTED_TOP_LEVEL):
        reject(
            "F05-SR-TOPLEVEL-FIELDS",
            f"actual={sorted(rules)} expected={sorted(EXPECTED_TOP_LEVEL)}",
        )
    _exact(
        {key: rules.get(key) for key in EXPECTED_IDENTITY},
        EXPECTED_IDENTITY,
        "F05-SR-IDENTITY",
    )

    try:
        surface_projection = {field: grammar[field] for field in SURFACE_FIELDS}
        declared_surface = grammar["surface_digest"]
    except KeyError as exc:
        reject("F05-SR-GRAMMAR-SHAPE", str(exc))
    actual_surface = sha256(canonical_bytes(surface_projection))
    grammar_canonical_sha256 = sha256(canonical_bytes(grammar))
    if grammar_canonical_sha256 != EXPECTED_GRAMMAR_CANONICAL_SHA256:
        reject("F05-SR-GRAMMAR-IDENTITY", grammar_canonical_sha256)
    expected_declared_surface = {
        "algorithm": "sha256",
        "projection": "DL-F0-5-language-surface-v1",
        "sha256": actual_surface,
    }
    if declared_surface != expected_declared_surface:
        reject("F05-SR-GRAMMAR-SURFACE-DIGEST", repr(declared_surface))
    if actual_surface != EXPECTED_SURFACE_SHA256:
        reject("F05-SR-GRAMMAR-SURFACE-IDENTITY", actual_surface)

    _exact(
        rules["provenance_sources"],
        EXPECTED_PROVENANCE_SOURCES,
        "F05-SR-PROVENANCE-SOURCES",
    )
    _exact(
        rules["provenance_combiner"],
        EXPECTED_PROVENANCE_COMBINER,
        "F05-SR-PROVENANCE-COMBINER",
    )
    _exact(rules["phase_rules"], EXPECTED_PHASE_RULES, "F05-SR-PHASE-RULES")
    _exact(rules["link_rules"], EXPECTED_LINK_RULES, "F05-SR-LINK-RULES")
    expected_link_materialization = {
        "status": "CONSTRUCTION_SPEC_NOT_COMPLETION_CLAIM",
        "declaration_projections": [
            {
                "tag": tag,
                "signature_fields": list(signature_fields),
                "signature_derived": list(signature_derived),
                "body_kind": body_kind,
                "body_fields": list(body_fields),
                "carrier_role": carrier_role,
            }
            for (
                tag,
                signature_fields,
                signature_derived,
                body_kind,
                body_fields,
                carrier_role,
            ) in EXPECTED_DECLARATION_LINK_ROWS
        ],
        "always_linked_unnamed": [
            {"tag": tag, "target": target, "fields": list(fields)}
            for tag, target, fields in EXPECTED_ALWAYS_LINKED_ROWS
        ],
        "module_init": EXPECTED_MODULE_INIT_LINK,
        "event_totalization": EXPECTED_EVENT_TOTALIZATION,
        "identity": EXPECTED_LINK_IDENTITY,
        "identity_preimages": [
            {
                "kind": kind,
                "domain_field": domain_field,
                "fields": list(fields),
                "stability": stability,
                "binder_policy": binder_policy,
            }
            for kind, domain_field, fields, stability, binder_policy in EXPECTED_IDENTITY_PREIMAGE_ROWS
        ],
        "source_binding_fields": EXPECTED_SOURCE_BINDING_FIELDS,
        "linked_model_fields": EXPECTED_LINKED_MODEL_FIELDS,
        "final_identity_issued": False,
    }
    _exact(
        rules["link_materialization"],
        expected_link_materialization,
        "F05-SR-LINK-MATERIALIZATION",
    )

    declaration_nodes = {
        row["tag"]: row
        for row in grammar.get("declaration_nodes", [])
        if isinstance(row, dict) and isinstance(row.get("tag"), str)
    }
    linked_declaration_tags = {
        row[0] for row in EXPECTED_DECLARATION_LINK_ROWS
    }
    always_linked_tags = {row[0] for row in EXPECTED_ALWAYS_LINKED_ROWS}
    if linked_declaration_tags | always_linked_tags != set(declaration_nodes):
        reject("F05-SR-LINK-DECLARATION-INVENTORY", repr(sorted(declaration_nodes)))
    if linked_declaration_tags & always_linked_tags:
        reject("F05-SR-LINK-DECLARATION-OVERLAP", repr(sorted(linked_declaration_tags)))
    for tag, signature_fields, _, _, body_fields, _ in EXPECTED_DECLARATION_LINK_ROWS:
        grammar_fields = [field[0] for field in declaration_nodes[tag]["fields"]]
        projected_fields = [*signature_fields, *body_fields]
        if len(set(projected_fields)) != len(projected_fields):
            reject("F05-SR-LINK-PROJECTION-DUPLICATE", tag)
        if set(projected_fields) != set(grammar_fields):
            reject(
                "F05-SR-LINK-PROJECTION-COVERAGE",
                f"{tag}:projected={projected_fields} grammar={grammar_fields}",
            )
    for tag, _, fields in EXPECTED_ALWAYS_LINKED_ROWS:
        grammar_fields = [field[0] for field in declaration_nodes[tag]["fields"]]
        if list(fields) != grammar_fields:
            reject(
                "F05-SR-LINK-UNNAMED-COVERAGE",
                f"{tag}:projected={fields} grammar={grammar_fields}",
            )

    expected_sort_rules = [
        {"tag": tag, "rule": rule} for tag, rule in EXPECTED_SORT_ROWS
    ]
    expected_premise_rules = [
        {"tag": tag, "rule": rule} for tag, rule in EXPECTED_PREMISE_ROWS
    ]
    expected_term_rules = [
        {
            "tag": tag,
            "typing_rule": typing_rule,
            "result_rule": result_rule,
            "provenance_rule": provenance_rule,
            "binder_rule": binder_rule,
        }
        for tag, typing_rule, result_rule, provenance_rule, binder_rule in EXPECTED_TERM_ROWS
    ]
    _exact(rules["sort_rules"], expected_sort_rules, "F05-SR-SORT-RULES")
    _exact(rules["premise_rules"], expected_premise_rules, "F05-SR-PREMISE-RULES")
    _exact(rules["term_rules"], expected_term_rules, "F05-SR-TERM-RULES")
    expected_provenance = _expected_provenance_derivations(grammar)
    _exact(
        rules["provenance_derivations"],
        expected_provenance,
        "F05-SR-PROVENANCE-DERIVATIONS",
    )
    _exact(
        rules["binder_derivations"],
        EXPECTED_BINDER_DERIVATIONS,
        "F05-SR-BINDER-DERIVATIONS",
    )
    _exact(
        rules["relation_boundary"],
        EXPECTED_RELATION_BOUNDARY,
        "F05-SR-RELATION-BOUNDARY",
    )
    _exact(rules["update_rules"], EXPECTED_UPDATE_RULES, "F05-SR-UPDATE-RULES")
    _exact(rules["body_rules"], EXPECTED_BODY_RULES, "F05-SR-BODY-RULES")
    _exact(rules["nonclaims"], EXPECTED_NONCLAIMS, "F05-SR-NONCLAIMS")
    _exact(
        rules["authorization"],
        EXPECTED_AUTHORIZATION,
        "F05-SR-AUTHORIZATION",
    )

    grammar_inventory = {
        "sort": _tags(grammar, "sort_nodes"),
        "premise": _tags(grammar, "premise_nodes"),
        "term": _tags(grammar, "term_nodes"),
    }
    try:
        grammar_inventory["update"] = grammar["kind_unions"]["Update"]
    except (KeyError, TypeError) as exc:
        reject("F05-SR-GRAMMAR-SHAPE", f"Update:{exc}")
    rule_inventory = {
        "sort": [row["tag"] for row in rules["sort_rules"]],
        "premise": [row["tag"] for row in rules["premise_rules"]],
        "term": [row["tag"] for row in rules["term_rules"]],
        "update": [row["tag"] for row in rules["update_rules"]],
    }
    _exact(rule_inventory, grammar_inventory, "F05-SR-GRAMMAR-INVENTORY")

    return StaticRuleContract(
        rules_raw_sha256=sha256(rules_raw),
        rules_canonical_sha256=sha256(canonical_bytes(rules)),
        grammar_raw_sha256=sha256(grammar_raw),
        grammar_canonical_sha256=grammar_canonical_sha256,
        grammar_surface_sha256=actual_surface,
        provenance_combiner=EXPECTED_PROVENANCE_COMBINER,
        phase_rules=MappingProxyType(
            {
                row["phase"]: (
                    row["result"],
                    frozenset(row["allowed_sources"]),
                )
                for row in EXPECTED_PHASE_RULES
            }
        ),
        link_rules=MappingProxyType(dict(EXPECTED_LINK_RULES)),
        link_materialization=LinkMaterializationContract(
            status="CONSTRUCTION_SPEC_NOT_COMPLETION_CLAIM",
            declaration_rules=MappingProxyType(
                {
                    row[0]: DeclarationLinkRule(*row)
                    for row in EXPECTED_DECLARATION_LINK_ROWS
                }
            ),
            always_linked_rules=MappingProxyType(
                {
                    row[0]: AlwaysLinkedRule(*row)
                    for row in EXPECTED_ALWAYS_LINKED_ROWS
                }
            ),
            module_init=MappingProxyType(dict(EXPECTED_MODULE_INIT_LINK)),
            event_totalization=MappingProxyType(dict(EXPECTED_EVENT_TOTALIZATION)),
            identity=MappingProxyType(dict(EXPECTED_LINK_IDENTITY)),
            identity_preimages=MappingProxyType(
                {
                    row[0]: IdentityPreimageRule(*row)
                    for row in EXPECTED_IDENTITY_PREIMAGE_ROWS
                }
            ),
            source_binding_fields=tuple(EXPECTED_SOURCE_BINDING_FIELDS),
            linked_model_fields=tuple(EXPECTED_LINKED_MODEL_FIELDS),
            final_identity_issued=False,
        ),
        sort_rules=MappingProxyType(dict(EXPECTED_SORT_ROWS)),
        premise_rules=MappingProxyType(dict(EXPECTED_PREMISE_ROWS)),
        term_rules=MappingProxyType(
            {
                row[0]: TermRule(*row)
                for row in EXPECTED_TERM_ROWS
            }
        ),
        provenance_rules=MappingProxyType(
            {
                row["tag"]: ProvenanceRule(
                    tag=row["tag"],
                    term_operands=tuple(row["term_operands"]),
                    context_variable_fields=tuple(row["context_variable_fields"]),
                    introduced_sources=frozenset(row["introduced_sources"]),
                )
                for row in expected_provenance
            }
        ),
        binder_rules=MappingProxyType(
            {
                row["tag"]: MappingProxyType(
                    {key: value for key, value in row.items() if key != "tag"}
                )
                for row in EXPECTED_BINDER_DERIVATIONS
            }
        ),
        relation_boundary=MappingProxyType(dict(EXPECTED_RELATION_BOUNDARY)),
        update_rules=MappingProxyType(
            {
                row["tag"]: (row["rule"], row["source_phase"])
                for row in EXPECTED_UPDATE_RULES
            }
        ),
        body_rules=MappingProxyType(
            {
                row["body"]: (
                    row["context"],
                    row["phase"],
                    row["static_check_scope"],
                    row["linked_semantic_scope"],
                )
                for row in EXPECTED_BODY_RULES
            }
        ),
    )


def load_contract(
    rules_path: Path = RULES_PATH,
    grammar_path: Path = GRAMMAR_PATH,
) -> StaticRuleContract:
    rules_raw = read_once(rules_path)
    grammar_raw = read_once(grammar_path)
    return validate_loaded(rules_raw, grammar_raw, rules_path, grammar_path)


def result(contract: StaticRuleContract) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "status": "construction_static_rule_table_shape_passed",
        "authority": "local_static_rule_inventory_only",
        "language_id": "DL-F0-5",
        "rules_raw_sha256": contract.rules_raw_sha256,
        "rules_canonical_sha256": contract.rules_canonical_sha256,
        "grammar_raw_sha256": contract.grammar_raw_sha256,
        "grammar_canonical_sha256": contract.grammar_canonical_sha256,
        "grammar_surface_sha256": contract.grammar_surface_sha256,
        "phase_rule_count": len(contract.phase_rules),
        "declaration_link_rule_count": len(
            contract.link_materialization.declaration_rules
        ),
        "always_linked_rule_count": len(
            contract.link_materialization.always_linked_rules
        ),
        "identity_preimage_rule_count": len(
            contract.link_materialization.identity_preimages
        ),
        "sort_rule_count": len(contract.sort_rules),
        "premise_rule_count": len(contract.premise_rules),
        "term_rule_count": len(contract.term_rules),
        "provenance_derivation_count": len(contract.provenance_rules),
        "binder_derivation_count": len(contract.binder_rules),
        "update_rule_count": len(contract.update_rules),
        "body_rule_count": len(contract.body_rules),
        "static_rule_table_complete": False,
        "static_checker_bound": False,
        "CoreSyntaxWF": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
        "nonclaims": EXPECTED_NONCLAIMS,
    }
