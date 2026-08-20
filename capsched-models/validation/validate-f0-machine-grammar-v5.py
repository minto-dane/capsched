#!/usr/bin/env python3
"""Fail-closed shape check for the unfinished DL-F0-5 machine grammar.

Passing this checker establishes only that the construction draft is internally
well-shaped. It does not establish denotational adequacy, metatheory, F0 local
acceptance, external assurance, or any implementation/protection claim.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
from pathlib import Path
from typing import Any, NamedTuple, NoReturn

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError


MODELS = Path(__file__).resolve().parents[1]
ROOT = MODELS.parent
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v5"
GRAMMAR = F0 / "f0-machine-grammar-v5.json"
META_SCHEMA = F0 / "f0-machine-grammar-meta-schema-v5.json"
MAX_BYTES = 4 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512
EXPECTED_META_SCHEMA_SHA256 = (
    "7ce28be035e907b7dacb09d1e2dfd5657e29f7f069b6b72015ae0c4a92ad92b8"
)
EXPECTED_SURFACE_SHA256 = (
    "02503654aae81c865cc1446fe707a49e9c50821603c41bb113dd017f79801039"
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

EXPECTED_PARTS = (
    (
        "f0-00-core-language-v5.md",
        "# DL-F0-5 Part 00: Core Language and Denotation",
        tuple(f"F05-00-{index:03d}" for index in range(1, 11)),
    ),
    (
        "f0-01-model-transition-claims-v5.md",
        "# DL-F0-5 Part 01: Models, Transitions, and Base Claims",
        tuple(f"F05-01-{index:03d}" for index in range(1, 13)),
    ),
    (
        "f0-02-morphisms-proof-boundary-v5.md",
        "# DL-F0-5 Part 02: Morphisms and Proof Boundary",
        tuple(f"F05-02-{index:03d}" for index in range(1, 11)),
    ),
)
EXPECTED_PART_SHA256 = {
    "f0-00-core-language-v5.md": "b9725ea4144649bbb186912bff8962a57a868bc6ad628ffe3bfef8fd29edd308",
    "f0-01-model-transition-claims-v5.md": "db17921615081f79046dfe29efaca64ee3405fe4e349457665da411398164483",
    "f0-02-morphisms-proof-boundary-v5.md": "0781fd947bf297c16281c2787e8d613bc254d11bda2a53e02823321adf1ddf2f",
}
NODE_SECTIONS = (
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
)
EXPECTED_PRIMITIVE_KINDS = (
    "Bool",
    "Nat",
    "ModuleName",
    "LocalName",
    "QualifiedName",
    "VariableName",
    "SHA256",
    "EQ_or_NEQ",
    "AtomCarrierClass",
)
EXPECTED_PRIMITIVE_WIRE_TYPES = {
    "Bool": {"form": "JSON_BOOLEAN"},
    "Nat": {"form": "JSON_INTEGER", "minimum": 0},
    "ModuleName": {
        "form": "ASCII_FULLMATCH",
        "pattern": "[A-Za-z][A-Za-z0-9_]{0,127}",
    },
    "LocalName": {
        "form": "ASCII_FULLMATCH",
        "pattern": "[A-Za-z][A-Za-z0-9_]{0,127}",
    },
    "QualifiedName": {
        "form": "PAIR",
        "components": ["ModuleName", "LocalName"],
    },
    "VariableName": {
        "form": "ASCII_FULLMATCH",
        "pattern": "[a-z][a-z0-9_]{0,127}",
    },
    "SHA256": {"form": "ASCII_FULLMATCH", "pattern": "[0-9a-f]{64}"},
    "EQ_or_NEQ": {"form": "CLOSED_ENUM", "values": ["EQ", "NEQ"]},
    "AtomCarrierClass": {
        "form": "CLOSED_ENUM",
        "values": ["FINITE", "UNRESTRICTED"],
    },
}
EXPECTED_UNION_SECTIONS = {
    "Sort": "sort_nodes",
    "TermNode": "term_nodes",
    "Premise": "premise_nodes",
    "Declaration": "declaration_nodes",
    "Scope": "scope_nodes",
}
EXPECTED_UPDATE_TAGS = ("PUT_UPDATE", "PATCH_UPDATE")
GROUND_HELPER_TAGS = ("GROUND_FIELD_ENTRY", "GROUND_MAP_ENTRY")
EXPECTED_LABEL_TAGS = ("LABEL_STUTTER", "LABEL_DO")
EXPECTED_ROOT_KINDS = {
    "Model": ("MODEL", "model_nodes"),
    "FiniteProfile": ("FINITE_PROFILE", "profile_nodes"),
    "FiniteRun": ("FINITE_RUN_VALUE", "runtime_nodes"),
}
REQUIRED_KIND_BINDINGS = {
    "Term": "TYPED_TERM",
    "FieldTermEntry": "FIELD_TERM_ENTRY",
    "VariantTermBranch": "VARIANT_TERM_BRANCH",
    "FieldDecl": "FIELD_DECL",
    "VariantTagDecl": "VARIANT_TAG_DECL",
    "ConstantConstraint": "CONSTANT_CONSTRAINT",
    "ChannelEmit": "CHANNEL_EMIT",
    "ActionBranch": "ACTION_BRANCH",
    "Import": "IMPORT",
    "Module": "MODULE",
    "AtomValue": "ATOM_VALUE",
    "AtomCarrier": "ATOM_CARRIER",
    "LimitValue": "LIMIT_VALUE",
    "ConstantValue": "CONSTANT_VALUE",
    "GroundFieldEntry": "GROUND_FIELD_ENTRY",
    "GroundMapEntry": "GROUND_MAP_ENTRY",
    "LocationValue": "LOCATION_VALUE",
    "CellValue": "CELL_VALUE",
    "StateValue": "STATE_VALUE",
    "EventChannelValue": "EVENT_CHANNEL_VALUE",
    "EventBundleValue": "EVENT_BUNDLE_VALUE",
    "TransitionValue": "TRANSITION_VALUE",
}
REQUIRED_CHECKER_OBLIGATIONS = {
    "primitive_wire_fullmatch_and_canonical_scalar_encoding",
    "collection_policy_totality_uniqueness_and_canonical_order",
    "qualified_namespace_and_import_closure",
    "sort_dependency_acyclicity",
    "KeySort_and_CellSort_restrictions",
    "constructor_and_match_exhaustiveness",
    "binder_freshness_capture_avoidance_and_exact_action_parameter",
    "typed_Term_annotation_equals_unique_derived_sort",
    "quantity_zero_checked_literal_and_arithmetic_result_binding_shape_totality",
    "type_uniqueness",
    "provenance_inference",
    "closed_StatePred_and_exact_action_parameter_context",
    "all_declared_actions_have_exactly_one_body",
    "invoke_guard_exact_one_partition",
    "Put_and_Patch_sort_original_pre_and_footprint_rules",
    "event_channel_completeness_and_nonempty_nonstutter_bundle",
    "finite_profile_totality_and_class_premise_satisfaction",
    "finite_state_event_label_transition_and_run_replay",
    "CoreSyntaxWF_InstanceWF_ClaimPackageWF",
    "claim_scope_inhabitation_and_nonvacuity",
    "morphism_witness_and_proof_object_validation",
}
REQUIRED_OPEN_GAPS = {
    "syntax_directed_typing_and_provenance_rule_table",
    "Eval_Reads_and_finite_evaluator_rule_tables",
    "Apply_Bundle_BranchStep_Step_and_WF_rule_tables",
    "fresh_channel_observer_and_event_composition_rule_nodes",
    "interpretation_registry_and_exact_scope_resolution",
    "claim_package_and_nonvacuity_witness_nodes",
    "semantic_mutation_record_nodes",
    "PureExtension_signature_state_label_event_path_witness_nodes",
    "conservativity_and_assumption_refinement_witness_nodes",
    "PlatformRefinement_relation_simulation_observation_footprint_witness_nodes",
    "theorem_statement_AST",
    "proof_and_certificate_nodes",
    "checker_protocol_result_and_reject_taxonomy_nodes",
    "semantic_context_and_validation_context_digest_binding",
    "counterexample_replay_nodes",
    "type_provenance_semantic_checker",
    "evaluation_transition_and_read_footprint_checker",
    "proof_kernel_or_certificate_checker",
    "markdown_machine_bidirectional_parity",
    "semantic_hostile_mutation_suite",
    "exact_F0_review_manifest_and_fresh_hostile_review",
}
EXPECTED_FORBIDDEN_NODES = {
    "RAW_STRING_VALUE",
    "HOST_INT",
    "FLOAT",
    "NULL",
    "PARTIAL_LOOKUP",
    "UNCHECKED_ARITHMETIC",
    "ARBITRARY_CHOICE",
    "RECURSION",
    "OPAQUE_FUNCTION",
    "DIGEST_TERM",
    "IO_TERM",
    "BACKEND_SOURCE_TERM",
    "CURRENT_PARAMETER_WITHOUT_BINDER",
    "ARBITRARY_ACTION_RELATION",
    "FINITE_ARRAY_AS_INFINITE_DENOTATION",
}
EXPECTED_AUTHORIZATION = {
    "construction_draft": True,
    "grammar_complete": False,
    "semantic_checker_complete": False,
    "proof_boundary_complete": False,
    "F0_local_acceptance": False,
    "F1_design": False,
    "K0_G0_complete": False,
    "candidate_IR": False,
    "TLA_translation": False,
    "model_supported": False,
    "linux_behavior_change": False,
    "protection_claim": False,
}
COLLECTION_RE = re.compile(
    r"^(?P<base>[A-Za-z][A-Za-z0-9_]*)(?P<suffix>\[\]|\[1\+\]|\[2\+\])?$"
)
TAG_RE = re.compile(r"[A-Z][A-Z0-9_]*")
FIELD_NAME_RE = re.compile(r"[a-z][a-z0-9_]*")
KIND_NAME_RE = re.compile(r"[A-Z][A-Za-z0-9_]*")
HEADING_RE = re.compile(r"^## (F05-[0-9]{2}-[0-9]{3}): .+$", re.MULTILINE)


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise Reject(reject_id, detail)


class FoundationSnapshot(NamedTuple):
    grammar_raw: bytes
    meta_schema_raw: bytes
    normative_parts_raw: tuple[tuple[str, bytes], ...]


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-MG-DUPLICATE-KEY", key)
        result[key] = value
    return result


def reject_float(token: str) -> NoReturn:
    reject("F05-MG-FLOAT", token)


def reject_non_json_number(token: str) -> NoReturn:
    reject("F05-MG-NON-JSON-NUMBER", token)


def parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-MG-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-MG-INTEGER", str(exc))


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def reject_unsafe_scalar(value: Any, path: str = "$") -> None:
    stack: list[tuple[Any, str, int]] = [(value, path, 0)]
    nodes = 0
    while stack:
        current, current_path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-MG-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-MG-DEPTH", f"{current_path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-MG-UNSAFE-SCALAR", current_path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-MG-NEGATIVE-INTEGER", current_path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-MG-NON-ASCII-STRING", current_path)
            if any(
                ord(character) < 0x20 or ord(character) == 0x7F
                for character in current
            ):
                reject("F05-MG-CONTROL-STRING", current_path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-MG-COLLECTION-LIMIT", current_path)
            for key, child in current.items():
                try:
                    key.encode("ascii")
                except UnicodeEncodeError:
                    reject("F05-MG-NON-ASCII-KEY", _child_path(current_path, f".{key}"))
                stack.append(
                    (child, _child_path(current_path, f".{key}"), depth + 1)
                )
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-MG-COLLECTION-LIMIT", current_path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (
                        current[index],
                        _child_path(current_path, f"[{index}]"),
                        depth + 1,
                    )
                )
            continue
        reject("F05-MG-UNSAFE-TYPE", f"{current_path}:{type(current).__name__}")


def read_once(path: Path) -> bytes:
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        reject("F05-MG-FILE-TYPE", f"{path}:{exc.errno}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            reject("F05-MG-FILE-TYPE", str(path))
        if before.st_size <= 0 or before.st_size > MAX_BYTES:
            reject("F05-MG-FILE-SIZE", f"{path}: {before.st_size}")
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
            reject("F05-MG-FILE-CHANGED-DURING-READ", str(path))
        if not raw or len(raw) > MAX_BYTES:
            reject("F05-MG-FILE-SIZE", f"{path}: {len(raw)}")
        return raw
    finally:
        os.close(descriptor)


def capture_foundation_snapshot() -> FoundationSnapshot:
    return FoundationSnapshot(
        grammar_raw=read_once(GRAMMAR),
        meta_schema_raw=read_once(META_SCHEMA),
        normative_parts_raw=tuple(
            (filename, read_once(F0 / filename))
            for filename, _, _ in EXPECTED_PARTS
        ),
    )


def parse_ascii_json(raw: bytes, path: Path) -> Any:
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-MG-NON-ASCII-JSON", f"{path}: {exc}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=strict_object,
            parse_int=parse_integer,
            parse_float=reject_float,
            parse_constant=reject_non_json_number,
        )
    except Reject:
        raise
    except json.JSONDecodeError as exc:
        reject("F05-MG-JSON", f"{path}: {exc}")
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-MG-PARSE-RESOURCE", f"{path}:{type(exc).__name__}")
    reject_unsafe_scalar(value)
    return value


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def validate_surface_digest(grammar: dict[str, Any]) -> str:
    projection = {field: grammar[field] for field in SURFACE_FIELDS}
    actual = digest(canonical_bytes(projection))
    declared = grammar["surface_digest"]
    if declared != {
        "algorithm": "sha256",
        "projection": "DL-F0-5-language-surface-v1",
        "sha256": actual,
    }:
        reject(
            "F05-MG-SURFACE-DIGEST",
            f"declared={declared.get('sha256')} actual={actual}",
        )
    if actual != EXPECTED_SURFACE_SHA256:
        reject("F05-MG-SURFACE-IDENTITY", actual)
    return actual


def render_json_path(parts: Any) -> str:
    rendered = "$"
    for part in parts:
        if isinstance(part, int):
            rendered += f"[{part}]"
        else:
            rendered += f".{part}"
    return rendered


def validate_against_meta_schema(grammar: Any, meta_schema: Any) -> None:
    try:
        Draft202012Validator.check_schema(meta_schema)
    except SchemaError as exc:
        reject(
            "F05-MG-META-SCHEMA-INVALID",
            f"{render_json_path(exc.absolute_schema_path)}: {exc.message}",
        )
    validator = Draft202012Validator(meta_schema)
    errors = sorted(
        validator.iter_errors(grammar),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        first = errors[0]
        reject(
            "F05-MG-META-SCHEMA-REJECT",
            f"{render_json_path(first.absolute_path)}: {first.message}",
        )


def validate_normative_parts(
    grammar: dict[str, Any],
    snapshot: FoundationSnapshot,
) -> list[dict[str, Any]]:
    expected_names = [part[0] for part in EXPECTED_PARTS]
    if grammar["normative_parts"] != expected_names:
        reject("F05-MG-NORMATIVE-PARTS", str(grammar["normative_parts"]))

    evidence: list[dict[str, Any]] = []
    part_bytes = dict(snapshot.normative_parts_raw)
    if tuple(part_bytes) != tuple(expected_names):
        reject("F05-MG-SNAPSHOT-PARTS", str(tuple(part_bytes)))
    for filename, expected_h1, expected_headings in EXPECTED_PARTS:
        raw = part_bytes[filename]
        try:
            text = raw.decode("ascii")
        except UnicodeDecodeError as exc:
            reject("F05-MG-PART-NON-ASCII", f"{filename}: {exc}")
        lines = text.splitlines()
        if not lines or lines[0] != expected_h1:
            reject("F05-MG-PART-H1", filename)
        all_h2 = [line for line in lines if line.startswith("## ")]
        actual_headings = tuple(HEADING_RE.findall(text))
        if len(all_h2) != len(actual_headings) or actual_headings != expected_headings:
            reject(
                "F05-MG-PART-HEADINGS",
                f"{filename}: {list(actual_headings)}",
            )
        if digest(raw) != EXPECTED_PART_SHA256[filename]:
            reject("F05-MG-PART-DIGEST", f"{filename}:{digest(raw)}")
        evidence.append(
            {
                "path": f"capsched-models/policy/r11/epoch2/foundation-v5/{filename}",
                "sha256": digest(raw),
                "bytes": len(raw),
                "heading_count": len(actual_headings),
            }
        )
    return evidence


def collect_nodes(
    grammar: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], dict[str, list[str]], set[str]]:
    node_by_tag: dict[str, dict[str, Any]] = {}
    section_tags: dict[str, list[str]] = {}
    field_kinds: set[str] = set()
    for section in NODE_SECTIONS:
        tags: list[str] = []
        for index, node in enumerate(grammar[section]):
            tag = node["tag"]
            if TAG_RE.fullmatch(tag) is None:
                reject("F05-MG-TAG-SYNTAX", f"{section}[{index}]:{tag!r}")
            if tag in node_by_tag:
                reject(
                    "F05-MG-GLOBAL-TAG-COLLISION",
                    f"{tag}: {node_by_tag[tag]['section']} and {section}[{index}]",
                )
            field_names = [field[0] for field in node["fields"]]
            for field_name in field_names:
                if FIELD_NAME_RE.fullmatch(field_name) is None:
                    reject("F05-MG-FIELD-NAME-SYNTAX", f"{tag}:{field_name!r}")
            if len(field_names) != len(set(field_names)):
                reject("F05-MG-FIELD-COLLISION", f"{section}.{tag}")
            node_by_tag[tag] = {"section": section, "index": index, "node": node}
            tags.append(tag)
            field_kinds.update(field[1] for field in node["fields"])
        section_tags[section] = tags
    return node_by_tag, section_tags, field_kinds


def validate_union_partition(
    grammar: dict[str, Any],
    node_by_tag: dict[str, dict[str, Any]],
    section_tags: dict[str, list[str]],
) -> set[str]:
    unions = grammar["kind_unions"]
    for kind, section in EXPECTED_UNION_SECTIONS.items():
        if unions[kind] != section_tags[section]:
            reject(
                "F05-MG-UNION-SECTION-MISMATCH",
                f"{kind}: union={unions[kind]} section={section_tags[section]}",
            )

    if tuple(unions["Update"]) != EXPECTED_UPDATE_TAGS:
        reject("F05-MG-UPDATE-UNION", str(unions["Update"]))
    for tag in EXPECTED_UPDATE_TAGS:
        if node_by_tag.get(tag, {}).get("section") != "support_nodes":
            reject("F05-MG-UPDATE-TAG", tag)

    if tuple(unions["Label"]) != EXPECTED_LABEL_TAGS:
        reject("F05-MG-LABEL-UNION", str(unions["Label"]))
    for tag in EXPECTED_LABEL_TAGS:
        if node_by_tag.get(tag, {}).get("section") != "runtime_nodes":
            reject("F05-MG-LABEL-TAG", tag)

    ground_tags = section_tags["ground_value_nodes"]
    for helper in GROUND_HELPER_TAGS:
        if helper not in ground_tags:
            reject("F05-MG-GROUND-HELPER", helper)
    expected_ground = [tag for tag in ground_tags if tag not in GROUND_HELPER_TAGS]
    if unions["GroundValue"] != expected_ground:
        reject(
            "F05-MG-GROUND-UNION",
            f"union={unions['GroundValue']} section_values={expected_ground}",
        )

    union_tags: set[str] = set()
    for kind, tags in unions.items():
        for tag in tags:
            if tag not in node_by_tag:
                reject("F05-MG-UNION-UNDECLARED-TAG", f"{kind}:{tag}")
            if tag in union_tags:
                reject("F05-MG-UNION-TAG-ALIAS", tag)
            union_tags.add(tag)
    return union_tags


def validate_kind_resolution(
    grammar: dict[str, Any],
    node_by_tag: dict[str, dict[str, Any]],
    section_tags: dict[str, list[str]],
    field_kinds: set[str],
    union_tags: set[str],
) -> dict[str, int]:
    if tuple(grammar["primitive_kinds"]) != EXPECTED_PRIMITIVE_KINDS:
        reject("F05-MG-PRIMITIVE-KINDS", str(grammar["primitive_kinds"]))
    if grammar["primitive_wire_types"] != EXPECTED_PRIMITIVE_WIRE_TYPES:
        reject("F05-MG-PRIMITIVE-WIRE", str(grammar["primitive_wire_types"]))

    bindings = grammar["kind_bindings"]
    for kind, expected_tag in REQUIRED_KIND_BINDINGS.items():
        if bindings.get(kind) != expected_tag:
            reject("F05-MG-REQUIRED-BINDING", f"{kind}:{bindings.get(kind)}")
    if len(set(bindings.values())) != len(bindings):
        reject("F05-MG-BINDING-TARGET-ALIAS", str(bindings))

    roots = grammar["root_kinds"]
    expected_roots = {
        kind: tag_and_section[0]
        for kind, tag_and_section in EXPECTED_ROOT_KINDS.items()
    }
    if roots != expected_roots:
        reject("F05-MG-ROOT-KINDS", str(roots))

    primitive = set(grammar["primitive_kinds"])
    union_kinds = set(grammar["kind_unions"])
    binding_kinds = set(bindings)
    root_kinds = set(roots)
    kind_namespaces = (primitive, union_kinds, binding_kinds, root_kinds)
    for index, left in enumerate(kind_namespaces):
        for right in kind_namespaces[index + 1:]:
            if left & right:
                reject("F05-MG-KIND-NAMESPACE-COLLISION", str(sorted(left & right)))
    for kind in primitive | union_kinds | binding_kinds | root_kinds:
        if KIND_NAME_RE.fullmatch(kind) is None:
            reject("F05-MG-KIND-NAME-SYNTAX", repr(kind))

    for kind, tag in bindings.items():
        if tag not in node_by_tag:
            reject("F05-MG-BINDING-UNDECLARED-TAG", f"{kind}:{tag}")
        if tag in union_tags:
            reject("F05-MG-BINDING-UNION-ALIAS", f"{kind}:{tag}")

    for kind, (tag, expected_section) in EXPECTED_ROOT_KINDS.items():
        if node_by_tag.get(tag, {}).get("section") != expected_section:
            reject("F05-MG-ROOT-TAG", f"{kind}:{tag}:{expected_section}")
        if tag in union_tags or tag in set(bindings.values()):
            reject("F05-MG-ROOT-CLASSIFICATION", tag)

    if len(set(roots.values())) != len(roots):
        reject("F05-MG-ROOT-TARGET-ALIAS", str(roots))
    classified_tags = union_tags | set(bindings.values()) | set(roots.values())
    declared_tags = set(node_by_tag)
    if declared_tags != classified_tags:
        reject(
            "F05-MG-TAG-CLASSIFICATION",
            f"unclassified={sorted(declared_tags-classified_tags)} undeclared={sorted(classified_tags-declared_tags)}",
        )

    known_kinds = primitive | union_kinds | binding_kinds | root_kinds
    used_base_kinds: set[str] = set()
    collection_field_count = 0
    suffixes = set(grammar["collection_kinds"]["suffixes"])
    for kind in sorted(field_kinds):
        match = COLLECTION_RE.fullmatch(kind)
        if match is None:
            reject("F05-MG-FIELD-KIND-SYNTAX", kind)
        base = match.group("base")
        suffix = match.group("suffix")
        if suffix is not None:
            collection_field_count += 1
            if suffix not in suffixes:
                reject("F05-MG-COLLECTION-SUFFIX", kind)
        if base not in known_kinds:
            reject("F05-MG-UNRESOLVED-FIELD-KIND", kind)
        used_base_kinds.add(base)

    unused_bindings = binding_kinds - used_base_kinds
    if unused_bindings:
        reject("F05-MG-UNUSED-BINDING", str(sorted(unused_bindings)))

    forbidden = set(grammar["forbidden_nodes"])
    collisions = forbidden & (declared_tags | known_kinds | set(roots.values()))
    if collisions:
        reject("F05-MG-FORBIDDEN-COLLISION", str(sorted(collisions)))

    return {
        "declared_tag_count": len(declared_tags),
        "field_kind_count": len(field_kinds),
        "collection_field_kind_count": collection_field_count,
        "kind_binding_count": len(bindings),
        "root_kind_count": len(roots),
    }


def validate_collection_policies(
    grammar: dict[str, Any],
    node_by_tag: dict[str, dict[str, Any]],
) -> int:
    bindings = grammar["kind_bindings"]
    roots = grammar["root_kinds"]
    unions = grammar["kind_unions"]
    collection_fields: dict[tuple[str, str], str] = {}
    for tag, entry in node_by_tag.items():
        for field_name, kind in entry["node"]["fields"]:
            match = COLLECTION_RE.fullmatch(kind)
            if match is None:
                reject("F05-MG-FIELD-KIND-SYNTAX", kind)
            if match.group("suffix") is not None:
                collection_fields[(tag, field_name)] = match.group("base")

    policy_by_field: dict[tuple[str, str], dict[str, str]] = {}
    for policy in grammar["collection_field_policies"]:
        owner = policy["owner_tag"]
        field = policy["field"]
        identity = (owner, field)
        if identity in policy_by_field:
            reject("F05-MG-COLLECTION-POLICY-DUPLICATE", f"{owner}.{field}")
        if identity not in collection_fields:
            reject("F05-MG-COLLECTION-POLICY-TARGET", f"{owner}.{field}")
        mode = policy["mode"]
        key = policy["key"]
        if mode == "ordered_sequence":
            if key != "NONE":
                reject("F05-MG-COLLECTION-SEQUENCE-KEY", f"{owner}.{field}:{key}")
        elif mode == "canonical_set":
            if key not in {"SELF_CANONICAL", "TAG_THEN_CANONICAL"}:
                reject("F05-MG-COLLECTION-SET-KEY", f"{owner}.{field}:{key}")
        elif mode == "canonical_map":
            if key in {"NONE", "SELF_CANONICAL", "TAG_THEN_CANONICAL"}:
                reject("F05-MG-COLLECTION-MAP-KEY", f"{owner}.{field}:{key}")
            element_kind = collection_fields[identity]
            if element_kind in bindings:
                target_tags = [bindings[element_kind]]
            elif element_kind in roots:
                target_tags = [roots[element_kind]]
            elif element_kind in unions:
                target_tags = unions[element_kind]
            else:
                target_tags = []
            if len(target_tags) != 1:
                reject(
                    "F05-MG-COLLECTION-MAP-ELEMENT",
                    f"{owner}.{field}:{element_kind}",
                )
            target_fields = {
                item[0] for item in node_by_tag[target_tags[0]]["node"]["fields"]
            }
            if key not in target_fields:
                reject(
                    "F05-MG-COLLECTION-MAP-KEY-FIELD",
                    f"{owner}.{field}:{target_tags[0]}.{key}",
                )
        else:
            reject("F05-MG-COLLECTION-MODE", str(mode))
        policy_by_field[identity] = policy

    expected = set(collection_fields)
    actual = set(policy_by_field)
    if actual != expected:
        reject(
            "F05-MG-COLLECTION-POLICY-COVERAGE",
            f"missing={sorted(expected-actual)} extra={sorted(actual-expected)}",
        )
    return len(actual)


def validate_draft_boundary(grammar: dict[str, Any]) -> None:
    if grammar["authorization"] != EXPECTED_AUTHORIZATION:
        reject("F05-MG-AUTHORIZATION", str(grammar["authorization"]))
    if grammar["status"] != "construction_draft_not_review_target":
        reject("F05-MG-STATUS", str(grammar["status"]))

    obligations = set(grammar["semantic_checker_obligations"])
    if obligations != REQUIRED_CHECKER_OBLIGATIONS:
        reject(
            "F05-MG-CHECKER-OBLIGATION",
            f"missing={sorted(REQUIRED_CHECKER_OBLIGATIONS-obligations)} extra={sorted(obligations-REQUIRED_CHECKER_OBLIGATIONS)}",
        )

    gaps = set(grammar["completion_gaps"])
    if gaps != REQUIRED_OPEN_GAPS:
        reject(
            "F05-MG-OPEN-GAP",
            f"missing={sorted(REQUIRED_OPEN_GAPS-gaps)} extra={sorted(gaps-REQUIRED_OPEN_GAPS)}",
        )
    forbidden = set(grammar["forbidden_nodes"])
    if forbidden != EXPECTED_FORBIDDEN_NODES:
        reject(
            "F05-MG-FORBIDDEN-INVENTORY",
            f"missing={sorted(EXPECTED_FORBIDDEN_NODES-forbidden)} extra={sorted(forbidden-EXPECTED_FORBIDDEN_NODES)}",
        )


def validate_snapshot(
    snapshot: FoundationSnapshot,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    grammar_raw = snapshot.grammar_raw
    meta_schema_raw = snapshot.meta_schema_raw
    grammar = parse_ascii_json(grammar_raw, GRAMMAR)
    meta_schema = parse_ascii_json(meta_schema_raw, META_SCHEMA)
    if not isinstance(grammar, dict) or not isinstance(meta_schema, dict):
        reject("F05-MG-TOPLEVEL", "grammar and meta-schema must be objects")
    if digest(meta_schema_raw) != EXPECTED_META_SCHEMA_SHA256:
        reject("F05-MG-META-SCHEMA-IDENTITY", digest(meta_schema_raw))

    validate_against_meta_schema(grammar, meta_schema)
    surface_sha256 = validate_surface_digest(grammar)
    normative_evidence = validate_normative_parts(grammar, snapshot)
    node_by_tag, section_tags, field_kinds = collect_nodes(grammar)
    union_tags = validate_union_partition(grammar, node_by_tag, section_tags)
    counts = validate_kind_resolution(
        grammar,
        node_by_tag,
        section_tags,
        field_kinds,
        union_tags,
    )
    collection_policy_count = validate_collection_policies(grammar, node_by_tag)
    validate_draft_boundary(grammar)

    output = {
        "schema_version": 1,
        "status": "construction_draft_shape_passed",
        "authority": "local_structural_consistency_only",
        "language_id": grammar["language_id"],
        "grammar_sha256": digest(grammar_raw),
        "grammar_bytes": len(grammar_raw),
        "meta_schema_sha256": digest(meta_schema_raw),
        "meta_schema_bytes": len(meta_schema_raw),
        "surface_sha256": surface_sha256,
        "normative_parts": normative_evidence,
        **counts,
        "collection_policy_count": collection_policy_count,
        "union_kind_count": len(grammar["kind_unions"]),
        "semantic_checker_obligation_count": len(grammar["semantic_checker_obligations"]),
        "open_completion_gap_count": len(grammar["completion_gaps"]),
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
        "nonclaims": [
            "Meta-schema and relational shape checks do not prove Markdown/AST semantic parity.",
            "This grammar-shape pass does not itself attest the separate static type/provenance checker.",
            "This grammar-shape invocation does not validate the separate ObsD/Eval/DynDeps rule artifact, transition, InstanceWF, morphism, theorem, or proof object.",
            "A construction-draft pass does not authorize F0 review acceptance or any downstream phase."
        ],
    }
    return output, grammar, meta_schema


def main() -> int:
    output, _, _ = validate_snapshot(capture_foundation_snapshot())
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Reject as exc:
        print(
            json.dumps(
                {
                    "status": "rejected",
                    "reject_id": exc.reject_id,
                    "detail": exc.detail,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
