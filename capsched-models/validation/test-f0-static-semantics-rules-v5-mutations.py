#!/usr/bin/env python3
"""Hostile mutations for the DL-F0-5 static semantics rule-table boundary."""

from __future__ import annotations

import copy
import hashlib
import json
import tempfile
from pathlib import Path
from typing import Any, Callable

import f0_static_rules_v5 as static_rules


RULES = static_rules.RULES_PATH
GRAMMAR = static_rules.GRAMMAR_PATH
Mutation = Callable[[dict[str, Any], dict[str, Any]], None]


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="ascii"))
    if not isinstance(value, dict):
        raise RuntimeError(f"object expected: {path}")
    return value


def write(path: Path, value: dict[str, Any]) -> None:
    path.write_bytes(static_rules.canonical_bytes(value) + b"\n")


def mutate_row(
    section: str,
    tag: str,
    field: str,
    value: Any,
) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        row = next(row for row in rules[section] if row.get("tag") == tag)
        row[field] = value

    return mutation


def mutate_body(body: str, field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        row = next(row for row in rules["body_rules"] if row.get("body") == body)
        row[field] = value

    return mutation


def mutate_provenance(tag: str, field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        row = next(
            row for row in rules["provenance_derivations"] if row["tag"] == tag
        )
        row[field] = value

    return mutation


def mutate_binder(tag: str, field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        row = next(row for row in rules["binder_derivations"] if row["tag"] == tag)
        row[field] = value

    return mutation


def flip_authorization(flag: str) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        rules["authorization"][flag] = not rules["authorization"][flag]

    return mutation


def run_structured(mutation: Mutation | None) -> tuple[int, str, str]:
    with tempfile.TemporaryDirectory(prefix="f0-static-rules-v5-") as temporary:
        directory = Path(temporary)
        rules_path = directory / RULES.name
        grammar_path = directory / GRAMMAR.name
        rules = load(RULES)
        grammar = load(GRAMMAR)
        if mutation is not None:
            mutation(rules, grammar)
        write(rules_path, rules)
        write(grammar_path, grammar)
        bundle = hashlib.sha256(rules_path.read_bytes() + grammar_path.read_bytes()).hexdigest()
        try:
            contract = static_rules.load_contract(rules_path, grammar_path)
        except static_rules.Reject as exc:
            return 1, exc.reject_id, bundle
        return 0, json.dumps(static_rules.result(contract), sort_keys=True), bundle


def run_raw(mutator: Callable[[bytes], bytes]) -> tuple[int, str, str]:
    with tempfile.TemporaryDirectory(prefix="f0-static-rules-v5-raw-") as temporary:
        directory = Path(temporary)
        rules_path = directory / RULES.name
        grammar_path = directory / GRAMMAR.name
        rules_path.write_bytes(mutator(RULES.read_bytes()))
        grammar_path.write_bytes(GRAMMAR.read_bytes())
        bundle = hashlib.sha256(rules_path.read_bytes() + grammar_path.read_bytes()).hexdigest()
        try:
            static_rules.load_contract(rules_path, grammar_path)
        except static_rules.Reject as exc:
            return 1, exc.reject_id, bundle
        return 0, "accepted", bundle


def remove_term(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    rules["term_rules"].pop()


def duplicate_term(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    rules["term_rules"].append(copy.deepcopy(rules["term_rules"][-1]))


def reorder_terms(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    rules["term_rules"][0], rules["term_rules"][1] = (
        rules["term_rules"][1],
        rules["term_rules"][0],
    )


def substitute_term_tag(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    rules["term_rules"][0]["tag"] = "TERM_ONE"


def drift_grammar_surface(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del rules
    grammar["term_nodes"][0]["tag"] = "TERM_FALSE_AUTHORITY"
    projection = {field: grammar[field] for field in static_rules.SURFACE_FIELDS}
    grammar["surface_digest"]["sha256"] = static_rules.sha256(
        static_rules.canonical_bytes(projection)
    )


def unknown_top(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    rules["unexpected"] = False


def remove_top(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
    del grammar
    del rules["nonclaims"]


def link_mutation(field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        rules["link_rules"][field] = value

    return mutation


def link_projection_mutation(tag: str, field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        row = next(
            row
            for row in rules["link_materialization"]["declaration_projections"]
            if row["tag"] == tag
        )
        row[field] = value

    return mutation


def link_materialization_mutation(section: str, field: str, value: Any) -> Mutation:
    def mutation(rules: dict[str, Any], grammar: dict[str, Any]) -> None:
        del grammar
        rules["link_materialization"][section][field] = value

    return mutation


Cases = list[tuple[str, Mutation, str]]
CASES: Cases = [
    ("unknown_top_level", unknown_top, "F05-SR-TOPLEVEL-FIELDS"),
    ("missing_top_level", remove_top, "F05-SR-TOPLEVEL-FIELDS"),
    (
        "status_escalation",
        lambda r, g: r.__setitem__("status", "accepted"),
        "F05-SR-IDENTITY",
    ),
    (
        "stale_grammar_surface_reference",
        lambda r, g: r.__setitem__("grammar_surface_sha256", "0" * 64),
        "F05-SR-IDENTITY",
    ),
    ("coordinated_grammar_surface_drift", drift_grammar_surface, "F05-SR-GRAMMAR-IDENTITY"),
    (
        "grammar_language_identity_drift",
        lambda r, g: g.__setitem__("language_id", "DL-F0-X"),
        "F05-SR-GRAMMAR-IDENTITY",
    ),
    (
        "grammar_status_escalation",
        lambda r, g: g.__setitem__("status", "accepted"),
        "F05-SR-GRAMMAR-IDENTITY",
    ),
    (
        "provenance_source_reorder",
        lambda r, g: r["provenance_sources"].reverse(),
        "F05-SR-PROVENANCE-SOURCES",
    ),
    (
        "state_phase_post_laundering",
        lambda r, g: r["phase_rules"][1]["allowed_sources"].append("POST"),
        "F05-SR-PHASE-RULES",
    ),
    (
        "provenance_combiner_runtime_branch_laundering",
        lambda r, g: r.__setitem__(
            "provenance_combiner", "RUNTIME_SELECTED_OPERANDS_ONLY"
        ),
        "F05-SR-PROVENANCE-COMBINER",
    ),
    (
        "imports_authorize_effects",
        link_mutation("imports_authorize_effects", True),
        "F05-SR-LINK-RULES",
    ),
    (
        "active_dependency_conflation",
        link_mutation("active_modules", "ALL_DEPENDENCY_MODULES"),
        "F05-SR-LINK-RULES",
    ),
    (
        "transitive_reexport",
        link_mutation("visibility", "TRANSITIVE_IMPORT_CLOSURE"),
        "F05-SR-LINK-RULES",
    ),
    (
        "module_digest_domain_removed",
        link_mutation("module_content_digest_domain", ""),
        "F05-SR-LINK-RULES",
    ),
    (
        "inactive_body_static_validation_removed",
        link_mutation("embedded_body_static_validation", "ACTIVE_MODULES_ONLY"),
        "F05-SR-LINK-RULES",
    ),
    (
        "active_import_closure_inferred",
        link_mutation("active_import_closure", "REQUIRED_TRANSITIVE_IMPORT_CLOSURE"),
        "F05-SR-LINK-RULES",
    ),
    (
        "inactive_carriers_removed",
        link_mutation("carrier_declarations", "ACTIVE_MODULES_ONLY"),
        "F05-SR-LINK-RULES",
    ),
    (
        "action_body_leaked_into_signature",
        link_projection_mutation(
            "DECL_ACTION",
            "signature_fields",
            ["name", "parameter_sort", "invoke"],
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "action_body_projection_removed",
        link_projection_mutation(
            "DECL_ACTION", "body_fields", ["parameter_variable", "branches"]
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "dormant_premise_activated_as_signature",
        link_projection_mutation("DECL_PREMISE", "body_kind", "NONE"),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "state_carrier_role_removed",
        link_projection_mutation("DECL_STATE_PRODUCT", "carrier_role", "NONE"),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "init_selection_includes_dormant",
        link_materialization_mutation(
            "module_init", "selection", "ALL_DEPENDENCY_MODULES"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "init_flattening_enabled",
        link_materialization_mutation(
            "module_init", "multiple", "FLATTEN_AND_DEDUPLICATE"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "event_domain_narrowed_to_active",
        link_materialization_mutation(
            "event_totalization", "channel_domain", "ACTIVE_MODULE_EVENT_CHANNELS"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "event_non_owner_coordinate_omitted",
        link_materialization_mutation(
            "event_totalization", "non_owner_coordinate", "OMIT"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "source_none_origin_laundered",
        link_materialization_mutation(
            "event_totalization", "source_none_origin", "SYNTHESIZED"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "model_artifact_identity_deferred",
        link_materialization_mutation(
            "identity", "model_artifact_id", "DEFERRED"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "source_action_semantic_identity_self_issued",
        link_materialization_mutation(
            "identity", "source_action_semantic_id", "ISSUED_LOCALLY"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "identity_preimage_stability_laundered",
        lambda r, g: r["link_materialization"]["identity_preimages"][0].__setitem__(
            "stability", "STABLE_UNDER_ANY_CHANGE"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "final_identity_authorization_flip",
        lambda r, g: r["link_materialization"].__setitem__(
            "final_identity_issued", True
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "body_origin_manifest_removed",
        lambda r, g: r["link_materialization"]["source_binding_fields"].remove(
            "body_origin_manifest"
        ),
        "F05-SR-LINK-MATERIALIZATION",
    ),
    (
        "sort_rule_substitution",
        mutate_row("sort_rules", "SORT_QTY", "rule", "SORT_BASE_NAT"),
        "F05-SR-SORT-RULES",
    ),
    (
        "premise_rule_substitution",
        mutate_row("premise_rules", "PREMISE_LIMIT_GE_NAT", "rule", "TYPE_QTY_LITERAL"),
        "F05-SR-PREMISE-RULES",
    ),
    ("term_missing", remove_term, "F05-SR-TERM-RULES"),
    ("term_duplicate", duplicate_term, "F05-SR-TERM-RULES"),
    ("term_reorder", reorder_terms, "F05-SR-TERM-RULES"),
    ("term_tag_substitution", substitute_term_tag, "F05-SR-TERM-RULES"),
    (
        "if_provenance_laundering",
        mutate_row("term_rules", "TERM_IF", "provenance_rule", "EMPTY"),
        "F05-SR-TERM-RULES",
    ),
    (
        "variant_match_provenance_laundering",
        mutate_row("term_rules", "TERM_MATCH_VARIANT", "provenance_rule", "EMPTY"),
        "F05-SR-TERM-RULES",
    ),
    (
        "pre_source_removed",
        mutate_row("term_rules", "TERM_PRE_GET", "provenance_rule", "UNION_IMMEDIATE_TERMS"),
        "F05-SR-TERM-RULES",
    ),
    (
        "post_source_laundered",
        mutate_row("term_rules", "TERM_POST_GET", "provenance_rule", "PRE_UNION_IMMEDIATE_TERMS"),
        "F05-SR-TERM-RULES",
    ),
    (
        "event_source_removed",
        mutate_row("term_rules", "TERM_EVENT_GET", "provenance_rule", "EMPTY"),
        "F05-SR-TERM-RULES",
    ),
    (
        "variant_branch_operand_laundered",
        mutate_provenance(
            "TERM_MATCH_VARIANT",
            "term_operands",
            ["FIELD:scrutinee"],
        ),
        "F05-SR-PROVENANCE-DERIVATIONS",
    ),
    (
        "record_value_operand_laundered",
        mutate_provenance("TERM_RECORD", "term_operands", []),
        "F05-SR-PROVENANCE-DERIVATIONS",
    ),
    (
        "if_operand_order_drift",
        mutate_provenance(
            "TERM_IF",
            "term_operands",
            ["FIELD:condition", "FIELD:else", "FIELD:then"],
        ),
        "F05-SR-PROVENANCE-DERIVATIONS",
    ),
    (
        "variable_context_source_removed",
        mutate_provenance("TERM_VARIABLE", "context_variable_fields", []),
        "F05-SR-PROVENANCE-DERIVATIONS",
    ),
    (
        "pre_introduced_source_removed",
        mutate_provenance("TERM_PRE_GET", "introduced_sources", []),
        "F05-SR-PROVENANCE-DERIVATIONS",
    ),
    (
        "let_binder_removed",
        mutate_row("term_rules", "TERM_LET", "binder_rule", "NONE"),
        "F05-SR-TERM-RULES",
    ),
    (
        "variant_match_binder_removed",
        mutate_row("term_rules", "TERM_MATCH_VARIANT", "binder_rule", "NONE"),
        "F05-SR-TERM-RULES",
    ),
    (
        "quantifier_binder_source_inflation",
        mutate_row("term_rules", "TERM_FORALL", "binder_rule", "FRESH_QUANTIFIED_PRE_SOURCE"),
        "F05-SR-TERM-RULES",
    ),
    (
        "let_binder_provenance_reset",
        mutate_binder("TERM_LET", "provenance_source", "EMPTY"),
        "F05-SR-BINDER-DERIVATIONS",
    ),
    (
        "variant_binder_scope_drift",
        mutate_binder("TERM_MATCH_VARIANT", "scope", "FIELD:scrutinee"),
        "F05-SR-BINDER-DERIVATIONS",
    ),
    (
        "checked_qty_narrowed_result",
        mutate_row("term_rules", "TERM_QTY_CHECKED", "result_rule", "NAMED_QTY"),
        "F05-SR-TERM-RULES",
    ),
    (
        "checked_qty_hidden_premise",
        mutate_row("term_rules", "TERM_QTY_CHECKED", "typing_rule", "TYPE_QTY_IF_LIMIT_GE_NAT"),
        "F05-SR-TERM-RULES",
    ),
    (
        "update_phase_inflation",
        mutate_row("update_rules", "PUT_UPDATE", "source_phase", "REL_TERM"),
        "F05-SR-UPDATE-RULES",
    ),
    (
        "update_dynamic_last_write_overclaim",
        mutate_row(
            "update_rules",
            "PATCH_UPDATE",
            "rule",
            "ORIGINAL_PRE_TYPED_FINITE_PATCH_LEFT_TO_RIGHT_LAST_WRITE_WINS",
        ),
        "F05-SR-UPDATE-RULES",
    ),
    (
        "inactive_body_activation",
        mutate_body("MODULE_INIT", "linked_semantic_scope", "ALL_DEPENDENCY_MODULES"),
        "F05-SR-BODY-RULES",
    ),
    (
        "inactive_body_static_skip",
        mutate_body("MODULE_INIT", "static_check_scope", "ACTIVE_MODULES_ONLY"),
        "F05-SR-BODY-RULES",
    ),
    (
        "relation_ast_fabricated",
        lambda r, g: r["relation_boundary"].__setitem__(
            "REL_TERM_and_REL_PRED", "AVAILABLE_SOURCE_RELATION_BODY_AST"
        ),
        "F05-SR-RELATION-BOUNDARY",
    ),
    (
        "nonclaim_removed",
        lambda r, g: r["nonclaims"].pop(),
        "F05-SR-NONCLAIMS",
    ),
]
for flag in static_rules.EXPECTED_AUTHORIZATION:
    CASES.append(
        (f"authorization_flip_{flag}", flip_authorization(flag), "F05-SR-AUTHORIZATION")
    )


RAW_CASES: list[tuple[str, Callable[[bytes], bytes], str]] = [
    (
        "duplicate_key",
        lambda raw: raw.replace(b'"schema_version": 1,', b'"schema_version": 1,"schema_version": 1,', 1),
        "F05-SR-DUPLICATE-KEY",
    ),
    (
        "null_scalar",
        lambda raw: raw.replace(b'"schema_version": 1', b'"schema_version": null', 1),
        "F05-SR-UNSAFE-SCALAR",
    ),
    (
        "float_scalar",
        lambda raw: raw.replace(b'"schema_version": 1', b'"schema_version": 1.0', 1),
        "F05-SR-FLOAT",
    ),
    (
        "negative_integer",
        lambda raw: raw.replace(b'"schema_version": 1', b'"schema_version": -1', 1),
        "F05-SR-NEGATIVE-INTEGER",
    ),
    (
        "non_ascii_json",
        lambda raw: raw.replace(b'"DL-F0-5"', '"DL-F0-\u03bb"'.encode("utf-8"), 1),
        "F05-SR-NON-ASCII-JSON",
    ),
    (
        "escaped_non_ascii",
        lambda raw: raw.replace(b'"DL-F0-5"', b'"DL-F0-\\u03bb"', 1),
        "F05-SR-NON-ASCII-STRING",
    ),
    (
        "boolean_schema_version",
        lambda raw: raw.replace(b'"schema_version": 1', b'"schema_version": true', 1),
        "F05-SR-IDENTITY",
    ),
    (
        "integer_link_boolean",
        lambda raw: raw.replace(
            b'"imports_authorize_effects": false',
            b'"imports_authorize_effects": 0',
            1,
        ),
        "F05-SR-LINK-RULES",
    ),
    (
        "integer_authorization_boolean",
        lambda raw: raw.replace(
            b'"construction_draft": true',
            b'"construction_draft": 1',
            1,
        ),
        "F05-SR-AUTHORIZATION",
    ),
    (
        "integer_digit_resource",
        lambda raw: raw.replace(
            b'"schema_version": 1',
            b'"schema_version": ' + b"1" * 5000,
            1,
        ),
        "F05-SR-INTEGER-DIGITS",
    ),
    (
        "depth_resource",
        lambda raw: b'{"x":' * 1200 + b"0" + b"}" * 1200,
        "F05-SR-DEPTH",
    ),
    (
        "oversized_input",
        lambda raw: raw + b" " * (static_rules.MAX_BYTES + 1),
        "F05-SR-FILE-SIZE",
    ),
]


def main() -> int:
    code, baseline_output, baseline_bundle = run_structured(None)
    if code != 0:
        raise RuntimeError(f"baseline rejected: {baseline_output}")
    baseline = json.loads(baseline_output)
    if (
        baseline["status"] != "construction_static_rule_table_shape_passed"
        or baseline["static_rule_table_complete"] is not False
        or baseline["CoreSyntaxWF"] is not False
        or baseline["F0_local_acceptance"] is not False
    ):
        raise RuntimeError("baseline authority mismatch")

    results: list[dict[str, str]] = []
    for case_id, mutation, expected in CASES:
        code, actual, bundle = run_structured(mutation)
        if code == 0 or actual != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {actual}")
        results.append({"id": case_id, "reject_id": actual, "bundle_sha256": bundle})
    for case_id, mutation, expected in RAW_CASES:
        code, actual, bundle = run_raw(mutation)
        if code == 0 or actual != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {actual}")
        results.append({"id": case_id, "reject_id": actual, "bundle_sha256": bundle})

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "local_static_rule_table_hostile_mutations_only",
                "baseline_bundle_sha256": baseline_bundle,
                "mutations_total": len(results),
                "mutations_rejected_at_expected_id": len(results),
                "results": results,
                "static_rule_table_complete": False,
                "static_checker_bound": False,
                "CoreSyntaxWF": False,
                "F0_local_acceptance": False,
                "K0_G0_complete": False,
                "protection_claim": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
