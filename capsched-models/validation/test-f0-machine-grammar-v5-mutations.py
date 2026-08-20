#!/usr/bin/env python3
"""Hostile structural mutations for the unfinished DL-F0-5 grammar checker."""

from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import shutil
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
CHECKER_PATH = HERE / "validate-f0-machine-grammar-v5.py"
MODELS = HERE.parent
SOURCE_F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v5"
GRAMMAR_NAME = "f0-machine-grammar-v5.json"
META_SCHEMA_NAME = "f0-machine-grammar-meta-schema-v5.json"

spec = importlib.util.spec_from_file_location("validate_f0_machine_grammar_v5", CHECKER_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("cannot load DL-F0-5 machine grammar checker")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
BASELINE_SURFACE_SHA256 = checker.EXPECTED_SURFACE_SHA256


Mutation = Callable[[Path], None]
JsonChange = Callable[[dict[str, Any]], None]


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="ascii"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected object: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=True) + "\n",
        encoding="ascii",
    )


def refresh_surface_digest(value: dict[str, Any]) -> None:
    projection = {field: value[field] for field in checker.SURFACE_FIELDS}
    value["surface_digest"]["sha256"] = hashlib.sha256(
        json.dumps(
            projection,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")
    ).hexdigest()


def mutate_json(
    filename: str,
    change: JsonChange,
    *,
    refresh_surface: bool = False,
) -> Mutation:
    def apply(f0: Path) -> None:
        path = f0 / filename
        value = load_json(path)
        change(value)
        if refresh_surface:
            refresh_surface_digest(value)
        write_json(path, value)

    return apply


def grammar(change: JsonChange, *, refresh_surface: bool = True) -> Mutation:
    return mutate_json(GRAMMAR_NAME, change, refresh_surface=refresh_surface)


def meta_schema(change: JsonChange) -> Mutation:
    return mutate_json(META_SCHEMA_NAME, change)


def duplicate_grammar_key(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(
        raw.replace(
            '"schema_version": 1,',
            '"schema_version": 1,\n  "schema_version": 1,',
            1,
        ),
        encoding="ascii",
    )


def duplicate_meta_schema_key(f0: Path) -> None:
    path = f0 / META_SCHEMA_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(
        raw.replace(
            '"title": "DL-F0-5 machine grammar construction-2 meta-schema",',
            '"title": "DL-F0-5 machine grammar construction-2 meta-schema",\n  "title": "duplicate",',
            1,
        ),
        encoding="ascii",
    )


def non_json_number(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace('"schema_version": 1,', '"schema_version": NaN,', 1), encoding="ascii")


def exponent_number(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace('"schema_version": 1,', '"schema_version": 1e0,', 1), encoding="ascii")


def leading_zero_number(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace('"schema_version": 1,', '"schema_version": 01,', 1), encoding="ascii")


def escaped_duplicate_key(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_text(encoding="ascii")
    path.write_text(
        raw.replace(
            '{"tag":"SORT_BOOL","fields":[]}',
            '{"tag":"SORT_BOOL","\\u0074ag":"SORT_BOOL","fields":[]}',
            1,
        ),
        encoding="ascii",
    )


def actual_non_ascii(f0: Path) -> None:
    path = f0 / GRAMMAR_NAME
    raw = path.read_bytes()
    path.write_bytes(raw.replace(b"construction-2", "construction-\N{SNOWMAN}".encode("utf-8"), 1))


def change_part_h1(f0: Path) -> None:
    path = f0 / "f0-00-core-language-v5.md"
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace("# DL-F0-5 Part 00:", "# DL-F0-5 Part XX:", 1), encoding="ascii")


def remove_part_heading(f0: Path) -> None:
    path = f0 / "f0-01-model-transition-claims-v5.md"
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace("## F05-01-012:", "### F05-01-012:", 1), encoding="ascii")


def drift_part_body(f0: Path) -> None:
    path = f0 / "f0-02-morphisms-proof-boundary-v5.md"
    raw = path.read_text(encoding="ascii")
    path.write_text(raw.replace("sound forward refinement", "forward refinement", 1), encoding="ascii")


def symlink_part(f0: Path) -> None:
    path = f0 / "f0-02-morphisms-proof-boundary-v5.md"
    path.unlink()
    path.symlink_to(f0 / "README.md")


def add_unknown_top_level(value: dict[str, Any]) -> None:
    value["claim_accepted"] = True


def remove_required_top_level(value: dict[str, Any]) -> None:
    del value["root_kinds"]


def set_null(value: dict[str, Any]) -> None:
    value["artifact_id"] = None


def set_float(value: dict[str, Any]) -> None:
    value["schema_version"] = 1.0


def set_negative(value: dict[str, Any]) -> None:
    value["schema_version"] = -1


def set_boolean_schema_version(value: dict[str, Any]) -> None:
    value["schema_version"] = True


def set_unicode_escape(value: dict[str, Any]) -> None:
    value["artifact_id"] += "\N{SNOWMAN}"


def set_control_tag(value: dict[str, Any]) -> None:
    value["sort_nodes"][0]["tag"] += "\n"


def escalate_status(value: dict[str, Any]) -> None:
    value["status"] = "F0_accepted"


def escalate_authorization(value: dict[str, Any]) -> None:
    value["authorization"]["F0_local_acceptance"] = True


def flip_authorization(flag: str) -> JsonChange:
    def apply(value: dict[str, Any]) -> None:
        value["authorization"][flag] = not value["authorization"][flag]

    return apply


def relax_meta_schema(value: dict[str, Any]) -> None:
    value["additionalProperties"] = True


def weaken_meta_required(value: dict[str, Any]) -> None:
    value["required"].remove("runtime_nodes")


def null_meta_schema(value: dict[str, Any]) -> None:
    value["title"] = None


def reorder_parts(value: dict[str, Any]) -> None:
    value["normative_parts"][0], value["normative_parts"][1] = (
        value["normative_parts"][1],
        value["normative_parts"][0],
    )


def traverse_part(value: dict[str, Any]) -> None:
    value["normative_parts"][0] = "../f0-00-core-language-v5.md"


def duplicate_global_tag(value: dict[str, Any]) -> None:
    value["support_nodes"][0]["tag"] = value["sort_nodes"][0]["tag"]


def duplicate_field(value: dict[str, Any]) -> None:
    value["sort_nodes"][4]["fields"][1][0] = value["sort_nodes"][4]["fields"][0][0]


def reorder_term_union(value: dict[str, Any]) -> None:
    value["kind_unions"]["TermNode"][0], value["kind_unions"]["TermNode"][1] = (
        value["kind_unions"]["TermNode"][1],
        value["kind_unions"]["TermNode"][0],
    )


def reorder_update_union(value: dict[str, Any]) -> None:
    value["kind_unions"]["Update"].reverse()


def put_helper_in_ground_union(value: dict[str, Any]) -> None:
    value["kind_unions"]["GroundValue"].append("GROUND_FIELD_ENTRY")


def reorder_label_union(value: dict[str, Any]) -> None:
    value["kind_unions"]["Label"].reverse()


def remove_required_binding(value: dict[str, Any]) -> None:
    value["kind_bindings"]["ActionBranch"] = "MODULE"


def alias_binding_target(value: dict[str, Any]) -> None:
    value["kind_bindings"]["ExtraAlias"] = "FIELD_TERM_ENTRY"


def undeclared_binding_target(value: dict[str, Any]) -> None:
    value["kind_bindings"]["ExtraNode"] = "UNDECLARED_NODE"


def alias_union_as_binding(value: dict[str, Any]) -> None:
    value["kind_bindings"]["ExtraNode"] = "SORT_BOOL"


def add_unclassified_tag(value: dict[str, Any]) -> None:
    value["support_nodes"].append({"tag": "UNCLASSIFIED_NODE", "fields": []})


def use_unresolved_kind(value: dict[str, Any]) -> None:
    value["term_nodes"][0]["fields"][0][1] = "MissingKind"


def add_unused_binding(value: dict[str, Any]) -> None:
    value["support_nodes"].append({"tag": "UNUSED_NODE", "fields": []})
    value["kind_bindings"]["UnusedNode"] = "UNUSED_NODE"


def drift_primitive_kinds(value: dict[str, Any]) -> None:
    value["primitive_kinds"][-1] = "OpaqueHostValue"


def collide_kind_namespace(value: dict[str, Any]) -> None:
    value["support_nodes"].append({"tag": "BOOL_HELPER", "fields": []})
    value["kind_bindings"]["Bool"] = "BOOL_HELPER"


def drift_primitive_wire(value: dict[str, Any]) -> None:
    value["primitive_wire_types"]["SHA256"]["pattern"] = "[0-9A-Fa-f]{64}"


def drift_root_kind(value: dict[str, Any]) -> None:
    value["root_kinds"]["Model"] = "FINITE_PROFILE"


def remove_root_tag(value: dict[str, Any]) -> None:
    value["model_nodes"][2]["tag"] = "MODEL_RENAMED"


def collide_forbidden_tag(value: dict[str, Any]) -> None:
    value["forbidden_nodes"].append("MODEL")


def remove_checker_obligation(value: dict[str, Any]) -> None:
    value["semantic_checker_obligations"].remove("type_uniqueness")


def remove_open_gap(value: dict[str, Any]) -> None:
    value["completion_gaps"].remove("proof_kernel_or_certificate_checker")


def restore_stale_gap(value: dict[str, Any]) -> None:
    value["completion_gaps"].append("meta_schema_for_this_grammar")


def duplicate_collection_policy(value: dict[str, Any]) -> None:
    value["collection_field_policies"][-1] = dict(value["collection_field_policies"][0])


def invalid_collection_policy_target(value: dict[str, Any]) -> None:
    value["collection_field_policies"][0]["field"] = "missing"


def sequence_policy_with_key(value: dict[str, Any]) -> None:
    for policy in value["collection_field_policies"]:
        if policy["owner_tag"] == "TERM_AND":
            policy["key"] = "operand"
            return
    raise RuntimeError("TERM_AND policy missing")


def map_policy_with_missing_key(value: dict[str, Any]) -> None:
    for policy in value["collection_field_policies"]:
        if policy["owner_tag"] == "TERM_RECORD":
            policy["key"] = "missing"
            return
    raise RuntimeError("TERM_RECORD policy missing")


def remove_action_parameter_field(value: dict[str, Any]) -> None:
    fields = value["declaration_nodes"][11]["fields"]
    fields[:] = [field for field in fields if field[0] != "parameter_variable"]


def drift_collection_suffixes(value: dict[str, Any]) -> None:
    value["collection_kinds"]["suffixes"].append("[3+]")


def use_bad_collection_suffix(value: dict[str, Any]) -> None:
    value["term_nodes"][23]["fields"][0][1] = "Term[3+]"


MutationCase = tuple[str, Mutation, str, bool]

MUTATIONS: list[MutationCase] = [
    ("duplicate_grammar_key", duplicate_grammar_key, "F05-MG-DUPLICATE-KEY", False),
    ("escaped_duplicate_key", escaped_duplicate_key, "F05-MG-DUPLICATE-KEY", False),
    ("duplicate_meta_schema_key", duplicate_meta_schema_key, "F05-MG-DUPLICATE-KEY", False),
    ("null_scalar", grammar(set_null), "F05-MG-UNSAFE-SCALAR", False),
    ("float_scalar", grammar(set_float), "F05-MG-FLOAT", False),
    ("exponent_scalar", exponent_number, "F05-MG-FLOAT", False),
    ("nan_scalar", non_json_number, "F05-MG-NON-JSON-NUMBER", False),
    ("negative_integer", grammar(set_negative), "F05-MG-NEGATIVE-INTEGER", False),
    ("boolean_schema_version", grammar(set_boolean_schema_version), "F05-MG-META-SCHEMA-REJECT", False),
    ("actual_non_ascii", actual_non_ascii, "F05-MG-NON-ASCII-JSON", False),
    ("escaped_non_ascii", grammar(set_unicode_escape), "F05-MG-NON-ASCII-STRING", False),
    ("escaped_control_string", grammar(set_control_tag), "F05-MG-CONTROL-STRING", False),
    ("leading_zero_integer", leading_zero_number, "F05-MG-JSON", False),
    ("unknown_top_level", grammar(add_unknown_top_level), "F05-MG-META-SCHEMA-REJECT", False),
    ("missing_required_top_level", grammar(remove_required_top_level, refresh_surface=False), "F05-MG-META-SCHEMA-REJECT", False),
    ("status_escalation", grammar(escalate_status), "F05-MG-META-SCHEMA-REJECT", False),
    ("meta_schema_relaxation", meta_schema(relax_meta_schema), "F05-MG-META-SCHEMA-IDENTITY", False),
    ("meta_schema_required_weakened", meta_schema(weaken_meta_required), "F05-MG-META-SCHEMA-IDENTITY", False),
    ("meta_schema_null", meta_schema(null_meta_schema), "F05-MG-UNSAFE-SCALAR", False),
    ("normative_part_reorder", grammar(reorder_parts), "F05-MG-NORMATIVE-PARTS", False),
    ("normative_part_traversal", grammar(traverse_part), "F05-MG-META-SCHEMA-REJECT", False),
    ("normative_part_h1", change_part_h1, "F05-MG-PART-H1", False),
    ("normative_part_heading", remove_part_heading, "F05-MG-PART-HEADINGS", False),
    ("normative_part_body", drift_part_body, "F05-MG-PART-DIGEST", False),
    ("normative_part_symlink", symlink_part, "F05-MG-FILE-TYPE", False),
    ("stale_surface_digest", grammar(remove_action_parameter_field, refresh_surface=False), "F05-MG-SURFACE-DIGEST", False),
    ("coordinated_surface_drift", grammar(remove_action_parameter_field), "F05-MG-SURFACE-IDENTITY", False),
    ("global_tag_collision_unit", grammar(duplicate_global_tag), "F05-MG-GLOBAL-TAG-COLLISION", True),
    ("field_name_collision_unit", grammar(duplicate_field), "F05-MG-FIELD-COLLISION", True),
    ("term_union_order_unit", grammar(reorder_term_union), "F05-MG-UNION-SECTION-MISMATCH", True),
    ("update_union_order_unit", grammar(reorder_update_union), "F05-MG-UPDATE-UNION", True),
    ("ground_helper_union_unit", grammar(put_helper_in_ground_union), "F05-MG-GROUND-UNION", True),
    ("label_union_order_unit", grammar(reorder_label_union), "F05-MG-LABEL-UNION", True),
    ("required_binding_unit", grammar(remove_required_binding), "F05-MG-REQUIRED-BINDING", True),
    ("unresolved_field_kind_unit", grammar(use_unresolved_kind), "F05-MG-UNRESOLVED-FIELD-KIND", True),
    ("primitive_kind_drift_unit", grammar(drift_primitive_kinds), "F05-MG-PRIMITIVE-KINDS", True),
    ("primitive_wire_drift_unit", grammar(drift_primitive_wire), "F05-MG-PRIMITIVE-WIRE", True),
    ("root_kind_drift_unit", grammar(drift_root_kind), "F05-MG-ROOT-KINDS", True),
    ("root_tag_removed_unit", grammar(remove_root_tag), "F05-MG-ROOT-TAG", True),
    ("forbidden_tag_collision_unit", grammar(collide_forbidden_tag), "F05-MG-FORBIDDEN-COLLISION", True),
    ("checker_obligation_removed_unit", grammar(remove_checker_obligation), "F05-MG-CHECKER-OBLIGATION", True),
    ("open_gap_removed", grammar(remove_open_gap), "F05-MG-OPEN-GAP", False),
    ("extra_stale_gap", grammar(restore_stale_gap), "F05-MG-OPEN-GAP", False),
    ("collection_policy_duplicate_unit", grammar(duplicate_collection_policy), "F05-MG-COLLECTION-POLICY-DUPLICATE", True),
    ("collection_policy_target_unit", grammar(invalid_collection_policy_target), "F05-MG-COLLECTION-POLICY-TARGET", True),
    ("collection_sequence_key_unit", grammar(sequence_policy_with_key), "F05-MG-COLLECTION-SEQUENCE-KEY", True),
    ("collection_map_key_unit", grammar(map_policy_with_missing_key), "F05-MG-COLLECTION-MAP-KEY-FIELD", True),
    ("collection_suffix_inventory", grammar(drift_collection_suffixes), "F05-MG-META-SCHEMA-REJECT", False),
    ("unsupported_collection_suffix", grammar(use_bad_collection_suffix), "F05-MG-META-SCHEMA-REJECT", False),
]

for authorization_flag in checker.EXPECTED_AUTHORIZATION:
    MUTATIONS.append(
        (
            f"authorization_flip_{authorization_flag}",
            grammar(flip_authorization(authorization_flag)),
            "F05-MG-META-SCHEMA-REJECT",
            False,
        )
    )


def bundle_sha256(f0: Path) -> str:
    hasher = hashlib.sha256()
    for filename in (
        GRAMMAR_NAME,
        META_SCHEMA_NAME,
        "f0-00-core-language-v5.md",
        "f0-01-model-transition-claims-v5.md",
        "f0-02-morphisms-proof-boundary-v5.md",
    ):
        raw = (f0 / filename).read_bytes()
        encoded_name = filename.encode("ascii")
        hasher.update(len(encoded_name).to_bytes(4, "big"))
        hasher.update(encoded_name)
        hasher.update(len(raw).to_bytes(8, "big"))
        hasher.update(raw)
    return hasher.hexdigest()


def run_case(mutation: Mutation | None, repin_surface: bool = False) -> tuple[int, str, str]:
    with tempfile.TemporaryDirectory(prefix="f0-machine-grammar-v5-mutation-") as temporary:
        f0 = Path(temporary) / "foundation-v5"
        shutil.copytree(SOURCE_F0, f0)
        if mutation is not None:
            mutation(f0)

        checker.EXPECTED_SURFACE_SHA256 = BASELINE_SURFACE_SHA256
        if repin_surface:
            mutated_grammar = load_json(f0 / GRAMMAR_NAME)
            checker.EXPECTED_SURFACE_SHA256 = mutated_grammar["surface_digest"]["sha256"]
        checker.F0 = f0
        checker.GRAMMAR = f0 / GRAMMAR_NAME
        checker.META_SCHEMA = f0 / META_SCHEMA_NAME
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                checker.main()
        except checker.Reject as exc:
            return 1, exc.reject_id, bundle_sha256(f0)
        return 0, output.getvalue(), bundle_sha256(f0)


def main() -> int:
    baseline_code, baseline_output, baseline_bundle_sha256 = run_case(None)
    if baseline_code != 0:
        raise RuntimeError(f"baseline rejected: {baseline_output}")
    baseline = json.loads(baseline_output)
    if (
        baseline["status"] != "construction_draft_shape_passed"
        or baseline["F0_local_acceptance"] is not False
        or baseline["K0_G0_complete"] is not False
    ):
        raise RuntimeError("baseline authority mismatch")

    results = []
    for mutation_id, mutation, expected_reject_id, repin_surface in MUTATIONS:
        code, actual, mutant_bundle_sha256 = run_case(mutation, repin_surface)
        if code == 0 or actual != expected_reject_id:
            raise RuntimeError(
                f"{mutation_id}: expected {expected_reject_id}, got {actual}"
            )
        results.append(
            {
                "id": mutation_id,
                "reject_id": actual,
                "lane": "checker_component_repin" if repin_surface else "production_boundary",
                "mutant_bundle_sha256": mutant_bundle_sha256,
            }
        )

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "local_construction_draft_shape_mutations_only",
                "baseline_passed": True,
                "baseline_bundle_sha256": baseline_bundle_sha256,
                "mutations_total": len(results),
                "mutations_rejected_at_expected_id": len(results),
                "results": results,
                "F0_local_acceptance": False,
                "K0_G0_complete": False,
                "semantic_validation": False,
                "proof_validation": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
