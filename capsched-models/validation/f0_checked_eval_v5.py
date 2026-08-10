"""Atomic immutable checked finite-evaluation adapter for DL-F0-5.

This adapter removes caller-supplied term, Gamma, Delta, provenance, and input
domain choices. It reconstructs those values from one source-derived checked
term occurrence and keeps every acceptance or protection claim false.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping, NoReturn


HERE = Path(__file__).resolve().parent


def _load_local(name: str, filename: str):
    path = HERE / filename
    existing = sys.modules.get(name)
    if existing is not None:
        existing_path = getattr(existing, "__file__", None)
        if existing_path is None or Path(existing_path).resolve() != path.resolve():
            raise RuntimeError(f"module identity collision for {name}")
        return existing
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


occurrence_module = _load_local(
    "f0_checked_term_occurrences_v5_checked_eval",
    "f0_checked_term_occurrences_v5.py",
)
eval_module = _load_local("f0_eval_v5_checked_eval", "f0_eval_v5.py")
semantics_module = _load_local("f0_semantics_v5_checked_eval", "f0_semantics_v5.py")
wire_validator = _load_local(
    "validate_f0_canonical_instance_v5_checked_eval",
    "validate-f0-canonical-instance-v5.py",
)
linked_validator = _load_local(
    "f0_linked_model_validator_v5_checked_eval",
    "f0_linked_model_validator_v5.py",
)


LANGUAGE_ID = "DL-F0-5"
ARTIFACT_ID = "domainlease-r11-epoch2-f0-checked-finite-evaluation-request-v5-1"
REQUEST_DOMAIN = b"DL-F0-5\x00CHECKED_FINITE_EVALUATION_REQUEST_CONSTRUCTION\x00"
CONTEXT_DOMAIN = b"DL-F0-5\x00FINITE_EVALUATION_VALIDATION_CONTEXT\x00"
RESULT_DOMAIN = b"DL-F0-5\x00CHECKED_FINITE_EVALUATION_RESULT_CONSTRUCTION\x00"
MAX_REQUEST_BYTES = 64 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512
MAX_DETAIL_CHARS = 512
IMPLEMENTATION_FILES = (
    "validate-f0-machine-grammar-v5.py",
    "generate-f0-strict-schemas-v5.py",
    "validate-f0-canonical-instance-v5.py",
    "f0_wire_snapshot_v5.py",
    "f0_static_rules_v5.py",
    "f0_static_checker_registry_v5.py",
    "f0_semantics_v5.py",
    "f0_linked_model_v5.py",
    "f0_linked_model_validator_v5.py",
    "f0_eval_rules_v5.py",
    "f0_finite_values_v5.py",
    "f0_eval_v5.py",
    "f0_checked_term_occurrences_v5.py",
    "f0_checked_eval_v5.py",
)

RESOURCE_FIELDS = {
    "max_term_visits",
    "max_may_term_visits",
    "max_recursion_depth",
    "max_carrier_values",
    "max_quantifier_iterations",
    "max_ground_value_nodes",
    "max_totalmap_entries",
    "max_access_trace_entries",
    "max_may_dependencies",
    "max_interpretation_ref_visits",
    "max_interpretation_refs",
}


@dataclass(frozen=True)
class OperatorHardEnvelope:
    max_source_model_bytes: int
    max_linked_artifact_bytes: int
    max_occurrence_index_bytes: int
    max_request_bytes: int
    max_total_ingress_bytes: int
    max_json_depth: int
    max_json_nodes: int
    max_collection_items: int
    max_integer_digits: int
    max_static_term_nodes: int
    max_static_term_depth: int
    max_link_event_coordinates: int
    max_checked_occurrences: int
    max_result_body_bytes: int
    evaluation_profile: Any

    def as_dict(self) -> dict[str, Any]:
        return {
            "max_source_model_bytes": self.max_source_model_bytes,
            "max_linked_artifact_bytes": self.max_linked_artifact_bytes,
            "max_occurrence_index_bytes": self.max_occurrence_index_bytes,
            "max_request_bytes": self.max_request_bytes,
            "max_total_ingress_bytes": self.max_total_ingress_bytes,
            "max_json_depth": self.max_json_depth,
            "max_json_nodes": self.max_json_nodes,
            "max_collection_items": self.max_collection_items,
            "max_integer_digits": self.max_integer_digits,
            "max_static_term_nodes": self.max_static_term_nodes,
            "max_static_term_depth": self.max_static_term_depth,
            "max_link_event_coordinates": self.max_link_event_coordinates,
            "max_checked_occurrences": self.max_checked_occurrences,
            "max_result_body_bytes": self.max_result_body_bytes,
            "evaluation_profile": self.evaluation_profile.as_dict(),
            "subprocess_supervisor": "NOT_BOUND",
        }


OPERATOR_HARD_ENVELOPE = OperatorHardEnvelope(
    max_source_model_bytes=4 * 1024 * 1024,
    max_linked_artifact_bytes=64 * 1024 * 1024,
    max_occurrence_index_bytes=8 * 1024 * 1024,
    max_request_bytes=64 * 1024 * 1024,
    max_total_ingress_bytes=140 * 1024 * 1024,
    max_json_depth=512,
    max_json_nodes=2_000_000,
    max_collection_items=1_000_000,
    max_integer_digits=4096,
    max_static_term_nodes=1_000_000,
    max_static_term_depth=192,
    max_link_event_coordinates=50_000,
    max_checked_occurrences=100_000,
    max_result_body_bytes=32 * 1024 * 1024,
    evaluation_profile=eval_module.ResourceProfile(
        max_term_visits=250_000,
        max_may_term_visits=250_000,
        max_recursion_depth=192,
        max_carrier_values=100_000,
        max_quantifier_iterations=250_000,
        max_ground_value_nodes=500_000,
        max_totalmap_entries=100_000,
        max_access_trace_entries=250_000,
        max_may_dependencies=250_000,
        max_interpretation_ref_visits=250_000,
        max_interpretation_refs=100_000,
    ),
)
OUTCOME_TAGS = {
    "SUCCESS",
    "REJECT",
    "INCONCLUSIVE_RESOURCE",
    "INCONCLUSIVE_UNSUPPORTED",
    "INTERNAL_FAILURE",
}
OUTCOME_STATUS = {
    "SUCCESS": "checked_finite_evaluation_construction_completed",
    "REJECT": "checked_finite_evaluation_request_rejected",
    "INCONCLUSIVE_RESOURCE": "checked_finite_evaluation_inconclusive_resource",
    "INCONCLUSIVE_UNSUPPORTED": "checked_finite_evaluation_inconclusive_unsupported",
    "INTERNAL_FAILURE": "checked_finite_evaluation_internal_failure",
}


class RequestReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


class RequestUnsupported(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


class ValidationContextFailure(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


class OperatorResourceInconclusive(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise RequestReject(reject_id, detail)


def unsupported(reason_id: str, detail: str) -> NoReturn:
    raise RequestUnsupported(reason_id, detail)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


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
            reject("F05-CFE-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-CFE-DEPTH", f"{path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-CFE-UNSAFE-SCALAR", path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-CFE-NEGATIVE-INTEGER", path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-CFE-NON-ASCII", path)
            if any(ord(character) < 0x20 or ord(character) == 0x7F for character in current):
                reject("F05-CFE-CONTROL-STRING", path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-CFE-COLLECTION-LIMIT", path)
            for key, child in current.items():
                if not isinstance(key, str):
                    reject("F05-CFE-NON-STRING-KEY", path)
                stack.append((child, _child_path(path, f".{key}"), depth + 1))
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-CFE-COLLECTION-LIMIT", path)
            for index in range(len(current) - 1, -1, -1):
                stack.append(
                    (current[index], _child_path(path, f"[{index}]"), depth + 1)
                )
            continue
        reject("F05-CFE-UNSAFE-TYPE", f"{path}:{type(current).__name__}")


def canonical_bytes(value: Any) -> bytes:
    _validate_tree(value)
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("F05-CFE-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-CFE-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-CFE-INTEGER", str(exc))


def parse_canonical_object(raw: bytes, label: str) -> dict[str, Any]:
    if type(raw) is not bytes or not raw or len(raw) > MAX_REQUEST_BYTES:
        reject(
            "F05-CFE-SIZE",
            f"{label}:{len(raw) if isinstance(raw, bytes) else -1}",
        )
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-CFE-NON-ASCII", f"{label}:{exc.start}")
    try:
        value = json.loads(
            text,
            object_pairs_hook=_strict_object,
            parse_int=_parse_integer,
            parse_float=lambda token: reject("F05-CFE-FLOAT", token),
            parse_constant=lambda token: reject("F05-CFE-NON-JSON-NUMBER", token),
        )
    except RequestReject:
        raise
    except json.JSONDecodeError as exc:
        reject("F05-CFE-JSON", f"{label}:{exc.msg}")
    _validate_tree(value)
    if not isinstance(value, dict):
        reject("F05-CFE-TOPLEVEL", f"{label}:{type(value).__name__}")
    if canonical_bytes(value) != raw:
        reject("F05-CFE-NONCANONICAL", label)
    return value


def _typed_request_id(payload: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "tag": "CHECKED_FINITE_EVALUATION_REQUEST_CONSTRUCTION",
        "domain": "DL-F0-5:CHECKED_FINITE_EVALUATION_REQUEST_CONSTRUCTION",
        "sha256": sha256(REQUEST_DOMAIN + canonical_bytes(dict(payload))),
    }


def _typed_context_id(payload: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "tag": "FINITE_EVALUATION_VALIDATION_CONTEXT",
        "domain": "DL-F0-5:FINITE_EVALUATION_VALIDATION_CONTEXT",
        "sha256": sha256(CONTEXT_DOMAIN + canonical_bytes(dict(payload))),
    }


def _typed_result_id(payload: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "tag": "CHECKED_FINITE_EVALUATION_RESULT_CONSTRUCTION",
        "domain": "DL-F0-5:CHECKED_FINITE_EVALUATION_RESULT_CONSTRUCTION",
        "sha256": sha256(RESULT_DOMAIN + canonical_bytes(dict(payload))),
    }


@dataclass(frozen=True)
class ValidationContext:
    foundation_snapshot: Any
    grammar_raw: bytes
    generated_outputs: Mapping[str, bytes]
    static_contract: Any
    eval_contract: Any
    module_graph: tuple[tuple[str, Any], ...]
    operator_envelope_raw: bytes
    identity_raw: bytes

    def identity(self) -> dict[str, Any]:
        return parse_canonical_object(self.identity_raw, "validation_context.identity")

    def grammar(self) -> dict[str, Any]:
        checker = wire_validator.generator.checker
        value = checker.parse_ascii_json(
            self.grammar_raw,
            Path("<validation-context-grammar>"),
        )
        if not isinstance(value, dict):
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-GRAMMAR",
                "captured grammar is no longer an object",
            )
        return value

    def assert_module_graph(self) -> None:
        for name, module in self.module_graph:
            if sys.modules.get(name) is not module:
                raise ValidationContextFailure(
                    "F05-CFE-CONTEXT-MODULE-GRAPH",
                    name,
                )
        if canonical_bytes(OPERATOR_HARD_ENVELOPE.as_dict()) != self.operator_envelope_raw:
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-OPERATOR-ENVELOPE",
                "process operator envelope changed after context capture",
            )


_CONTEXT_LOCK = threading.RLock()
_EXECUTION_LOCK = threading.RLock()
_VALIDATION_CONTEXT: ValidationContext | None = None


def _context_read(path: Path, label: str) -> bytes:
    checker = wire_validator.generator.checker
    try:
        return checker.read_once(path)
    except checker.Reject as exc:
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-READ",
            f"{label}:{exc.reject_id}",
        ) from exc


def _capture_validation_context() -> ValidationContext:
    checker = wire_validator.generator.checker
    foundation_paths: dict[str, Path] = {
        "grammar": checker.GRAMMAR,
        "meta_schema": checker.META_SCHEMA,
        **{
            f"normative:{filename}": checker.F0 / filename
            for filename, _, _ in checker.EXPECTED_PARTS
        },
        "static_rules": semantics_module.static_rules.RULES_PATH,
        "eval_rules": eval_module.rules_module.RULES_PATH,
    }

    def read_set(paths: Mapping[str, Path]) -> dict[str, bytes]:
        return {label: _context_read(path, label) for label, path in paths.items()}

    first = read_set(foundation_paths)
    second = read_set(foundation_paths)
    if first != second:
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-NONATOMIC",
            "semantic source files changed during double capture",
        )
    foundation = checker.FoundationSnapshot(
        grammar_raw=first["grammar"],
        meta_schema_raw=first["meta_schema"],
        normative_parts_raw=tuple(
            (filename, first[f"normative:{filename}"])
            for filename, _, _ in checker.EXPECTED_PARTS
        ),
    )
    grammar_result, grammar, _ = checker.validate_snapshot(foundation)
    if grammar_result.get("status") != "construction_draft_shape_passed":
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-GRAMMAR",
            "captured foundation did not pass construction validation",
        )
    implementation_paths = {
        filename: HERE / filename for filename in IMPLEMENTATION_FILES
    }
    implementation_first = read_set(implementation_paths)
    implementation_second = read_set(implementation_paths)
    if implementation_first != implementation_second:
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-NONATOMIC",
            "implementation files changed during double capture",
        )

    generated = wire_validator.generator.build_outputs_from_snapshot(
        grammar,
        foundation,
        generator_raw=implementation_first["generate-f0-strict-schemas-v5.py"],
        grammar_checker_raw=implementation_first["validate-f0-machine-grammar-v5.py"],
    )
    generated_paths = {
        filename: wire_validator.generator.DEFAULT_OUTPUT / filename
        for filename in generated
    }
    generated_first = read_set(generated_paths)
    generated_second = read_set(generated_paths)
    if generated_first != generated_second:
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-NONATOMIC",
            "generated schema files changed during double capture",
        )
    for filename, expected in generated.items():
        if generated_first.get(filename) != expected:
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-GENERATED-DRIFT",
                filename,
            )

    static_contract = semantics_module.static_rules.validate_loaded(
        first["static_rules"],
        first["grammar"],
        semantics_module.static_rules.RULES_PATH,
        semantics_module.static_rules.GRAMMAR_PATH,
    )
    normative_by_id = {
        part_id: first[f"normative:{path.name}"]
        for part_id, path in eval_module.rules_module.NORMATIVE_PATHS.items()
    }
    eval_contract = eval_module.rules_module.validate_loaded(
        first["eval_rules"],
        first["grammar"],
        first["static_rules"],
        normative_by_id,
    )
    if (
        static_contract.grammar_raw_sha256 != eval_contract.grammar_raw_sha256
        or static_contract.grammar_canonical_sha256
        != eval_contract.grammar_canonical_sha256
        or static_contract.rules_raw_sha256 != eval_contract.static_rules_raw_sha256
        or static_contract.rules_canonical_sha256
        != eval_contract.static_rules_canonical_sha256
    ):
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-CROSS-BINDING",
            "grammar/static/eval contracts do not share one captured generation",
        )
    limit_bindings = {
        "checked_request.max_json_depth": MAX_JSON_DEPTH,
        "checked_request.max_json_nodes": MAX_JSON_NODES,
        "checked_request.max_collection_items": MAX_COLLECTION_ITEMS,
        "checked_request.max_integer_digits": MAX_INTEGER_DIGITS,
        "occurrence.max_json_depth": occurrence_module.MAX_JSON_DEPTH,
        "occurrence.max_json_nodes": occurrence_module.MAX_JSON_NODES,
        "occurrence.max_collection_items": occurrence_module.MAX_COLLECTION_ITEMS,
        "occurrence.max_integer_digits": occurrence_module.MAX_INTEGER_DIGITS,
        "wire_snapshot.max_json_depth": semantics_module.wire_snapshot.MAX_JSON_DEPTH,
        "wire_snapshot.max_json_nodes": semantics_module.wire_snapshot.MAX_JSON_NODES,
        "wire_snapshot.max_collection_items": semantics_module.wire_snapshot.MAX_COLLECTION_ITEMS,
        "wire_snapshot.max_integer_digits": semantics_module.wire_snapshot.MAX_INTEGER_DIGITS,
        "linked_validator.max_json_depth": linked_validator.MAX_JSON_DEPTH,
        "linked_validator.max_json_nodes": linked_validator.MAX_JSON_NODES,
        "linked_validator.max_collection_items": linked_validator.MAX_COLLECTION_ITEMS,
        "linked_validator.max_integer_digits": linked_validator.MAX_INTEGER_DIGITS,
        "static.max_term_nodes": semantics_module.MAX_TERM_NODES,
        "static.max_term_depth": semantics_module.MAX_TERM_DEPTH,
    }
    expected_limit_by_suffix = {
        "max_json_depth": OPERATOR_HARD_ENVELOPE.max_json_depth,
        "max_json_nodes": OPERATOR_HARD_ENVELOPE.max_json_nodes,
        "max_collection_items": OPERATOR_HARD_ENVELOPE.max_collection_items,
        "max_integer_digits": OPERATOR_HARD_ENVELOPE.max_integer_digits,
        "max_term_nodes": OPERATOR_HARD_ENVELOPE.max_static_term_nodes,
        "max_term_depth": OPERATOR_HARD_ENVELOPE.max_static_term_depth,
    }
    for label, actual in limit_bindings.items():
        suffix = label.rsplit(".", 1)[1]
        if actual != expected_limit_by_suffix[suffix]:
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-OPERATOR-LIMIT-BINDING",
                label,
            )
    if (
        eval_module.EvalRuleContract is not eval_module.rules_module.EvalRuleContract
        or eval_module.Value is not eval_module.values_module.Value
        or eval_module.FiniteInterpretation
        is not eval_module.values_module.FiniteInterpretation
        or not isinstance(
            static_contract,
            semantics_module.static_rules.StaticRuleContract,
        )
        or not isinstance(eval_contract, eval_module.rules_module.EvalRuleContract)
    ):
        raise ValidationContextFailure(
            "F05-CFE-CONTEXT-CLASS-IDENTITY",
            "runtime module graph contains split semantic classes",
        )
    graph_modules = (
        occurrence_module,
        eval_module,
        eval_module.rules_module,
        eval_module.values_module,
        semantics_module,
        semantics_module.static_registry,
        semantics_module.static_rules,
        semantics_module.wire_snapshot,
        semantics_module.linked_model,
        wire_validator,
        linked_validator,
    )
    graph_by_name: dict[str, Any] = {}
    for module in graph_modules:
        name = module.__name__
        previous = graph_by_name.get(name)
        if previous is not None and previous is not module:
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-MODULE-GRAPH",
                f"duplicate module name {name}",
            )
        if sys.modules.get(name) is not module:
            raise ValidationContextFailure(
                "F05-CFE-CONTEXT-MODULE-GRAPH",
                f"unregistered or replaced module {name}",
            )
        graph_by_name[name] = module
    operator_profile = OPERATOR_HARD_ENVELOPE.evaluation_profile.as_dict()
    payload = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "authority": "local_rule_bundle_execution_context_construction_only",
        "taxonomy_version": 1,
        "semantic_sources": {
            label: sha256(raw) for label, raw in sorted(first.items())
        },
        "generated_outputs": {
            filename: sha256(raw) for filename, raw in sorted(generated.items())
        },
        "implementation_sources": {
            filename: sha256(raw)
            for filename, raw in sorted(implementation_first.items())
        },
        "operator_evaluation_hard_profile": operator_profile,
        "operator_hard_envelope": OPERATOR_HARD_ENVELOPE.as_dict(),
        "captured_implementation_executed_directly": False,
        "module_graph_identity_checked": True,
        "whole_pipeline_resource_envelope_complete": False,
        "external_process_supervisor_bound": False,
        "ValidationContextDigest_issued": False,
    }
    identity = dict(payload)
    identity["validation_context_id"] = _typed_context_id(payload)
    return ValidationContext(
        foundation_snapshot=foundation,
        grammar_raw=bytes(first["grammar"]),
        generated_outputs=MappingProxyType(
            {filename: bytes(raw) for filename, raw in generated.items()}
        ),
        static_contract=static_contract,
        eval_contract=eval_contract,
        module_graph=tuple(sorted(graph_by_name.items())),
        operator_envelope_raw=canonical_bytes(OPERATOR_HARD_ENVELOPE.as_dict()),
        identity_raw=canonical_bytes(identity),
    )


def validation_context() -> ValidationContext:
    global _VALIDATION_CONTEXT
    with _CONTEXT_LOCK:
        if _VALIDATION_CONTEXT is None:
            _VALIDATION_CONTEXT = _capture_validation_context()
        return _VALIDATION_CONTEXT


def _presence(raw: bytes | None, label: str) -> dict[str, Any]:
    if raw is None:
        return {"tag": "ABSENT"}
    return {"tag": "PRESENT", "value": parse_canonical_object(raw, label)}


def materialize_request(
    *,
    source_model_raw: bytes,
    linked_artifact_raw: bytes,
    occurrence_index_raw: bytes,
    checked_term_occurrence_id: Mapping[str, Any],
    finite_profile_raw: bytes,
    parameter_raw: bytes | None = None,
    pre_raw: bytes | None = None,
    post_raw: bytes | None = None,
    event_raw: bytes | None = None,
    resource_profile_raw: bytes | None = None,
) -> bytes:
    """Build immutable bytes; this helper does not authorize their evaluation."""

    for label, raw in (
        ("source_model", source_model_raw),
        ("linked_artifact", linked_artifact_raw),
        ("occurrence_index", occurrence_index_raw),
    ):
        if type(raw) is not bytes or not raw:
            reject("F05-CFE-ARGUMENT-TYPE", label)
    if resource_profile_raw is None:
        resource_profile_raw = canonical_bytes(
            {
                "tag": "FINITE_EVALUATION_RESOURCE_PROFILE",
                **eval_module.ResourceProfile().as_dict(),
            }
        )
    identifier = json.loads(canonical_bytes(dict(checked_term_occurrence_id)).decode("ascii"))
    context = validation_context()
    payload = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "artifact_id": ARTIFACT_ID,
        "tag": "CHECKED_FINITE_EVALUATION_REQUEST",
        "validation_context_id": context.identity()["validation_context_id"],
        "external_artifact_digests": {
            "source_model_sha256": sha256(source_model_raw),
            "linked_artifact_sha256": sha256(linked_artifact_raw),
            "occurrence_index_sha256": sha256(occurrence_index_raw),
        },
        "checked_term_occurrence_id": identifier,
        "finite_profile": parse_canonical_object(finite_profile_raw, "finite_profile"),
        "root_inputs": {
            "parameter": _presence(parameter_raw, "parameter"),
            "pre": _presence(pre_raw, "pre"),
            "post": _presence(post_raw, "post"),
            "event": _presence(event_raw, "event"),
        },
        "resource_profile": parse_canonical_object(
            resource_profile_raw, "resource_profile"
        ),
    }
    artifact = dict(payload)
    artifact["checked_evaluation_request_construction_id"] = _typed_request_id(payload)
    return canonical_bytes(artifact)


def _bounded_detail(value: Any) -> str:
    text = str(value)
    try:
        text.encode("ascii")
    except UnicodeEncodeError:
        text = text.encode("ascii", "backslashreplace").decode("ascii")
    if len(text) > MAX_DETAIL_CHARS:
        return text[: MAX_DETAIL_CHARS - 3] + "..."
    return text


def _is_operator_limit_id(identifier: str) -> bool:
    return any(
        marker in identifier
        for marker in (
            "NODE-LIMIT",
            "COLLECTION-LIMIT",
            "INTEGER-DIGITS",
            "RESOURCE-SORT-DEPTH",
            "RESOURCE-TERM-DEPTH",
            "RESOURCE-TERM-NODES",
        )
    ) or identifier.endswith("-DEPTH")


@dataclass(frozen=True)
class CheckedEvaluationOutcome:
    outcome_tag: str
    request_raw_sha256: str
    request_identity_raw: bytes
    body_raw: bytes

    def __post_init__(self) -> None:
        if self.outcome_tag not in OUTCOME_TAGS:
            raise ValueError("unknown checked evaluation outcome")
        if not isinstance(self.request_raw_sha256, str):
            raise TypeError("request raw digest must be a string")
        parse_canonical_object(self.request_identity_raw, "outcome.request_identity")
        parse_canonical_object(self.body_raw, "outcome.body")

    @property
    def evaluation_validated(self) -> bool:
        return False

    @property
    def F0_local_acceptance(self) -> bool:
        return False

    @property
    def protection_claim(self) -> bool:
        return False

    def as_dict(self) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "language_id": LANGUAGE_ID,
            "status": OUTCOME_STATUS[self.outcome_tag],
            "outcome_tag": self.outcome_tag,
            "authority": "local_atomic_checked_finite_evaluation_construction_only",
            "request_raw_sha256": self.request_raw_sha256,
            "request_identity": parse_canonical_object(
                self.request_identity_raw, "outcome.request_identity"
            ),
            "body": parse_canonical_object(self.body_raw, "outcome.body"),
            "checked_term_occurrence_source_reconstructed": self.outcome_tag == "SUCCESS",
            "semantic_context_bound": False,
            "ValidationContextDigest_issued": False,
            "evaluation_validated": False,
            "CoreSyntaxWF": False,
            "InstanceWF": False,
            "F0_local_acceptance": False,
            "K0_G0_complete": False,
            "candidate_IR": False,
            "TLA_translation": False,
            "model_supported": False,
            "linux_behavior_change": False,
            "protection_claim": False,
        }


def _outcome(
    tag: str,
    request_raw: Any,
    request_identity: Mapping[str, Any] | None,
    body: Mapping[str, Any],
) -> CheckedEvaluationOutcome:
    digest = sha256(request_raw) if type(request_raw) is bytes else "UNAVAILABLE"
    identity = (
        dict(request_identity)
        if request_identity is not None
        else {"status": "NOT_AVAILABLE"}
    )
    body_raw = canonical_bytes(dict(body))
    if len(body_raw) > OPERATOR_HARD_ENVELOPE.max_result_body_bytes:
        raise OperatorResourceInconclusive(
            "F05-CFE-INCONCLUSIVE-RESOURCE-RESULT-BYTES",
            f"{len(body_raw)}>{OPERATOR_HARD_ENVELOPE.max_result_body_bytes}",
        )
    return CheckedEvaluationOutcome(
        outcome_tag=tag,
        request_raw_sha256=digest,
        request_identity_raw=canonical_bytes(identity),
        body_raw=body_raw,
    )


def _sha_field(value: Any, path: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 64
        or any(character not in "0123456789abcdef" for character in value)
    ):
        reject("F05-CFE-SHA256", path)
    return value


def _validate_request_artifact(
    request_raw: bytes,
    source_model_raw: bytes,
    linked_artifact_raw: bytes,
    occurrence_index_raw: bytes,
    context: ValidationContext,
) -> tuple[dict[str, Any], dict[str, Any]]:
    request = parse_canonical_object(request_raw, "request")
    fields = {
        "schema_version",
        "language_id",
        "artifact_id",
        "tag",
        "validation_context_id",
        "external_artifact_digests",
        "checked_term_occurrence_id",
        "finite_profile",
        "root_inputs",
        "resource_profile",
        "checked_evaluation_request_construction_id",
    }
    if set(request) != fields:
        reject("F05-CFE-REQUEST-SHAPE", "exact top-level fields required")
    identity = {
        "schema_version": 1,
        "language_id": LANGUAGE_ID,
        "artifact_id": ARTIFACT_ID,
        "tag": "CHECKED_FINITE_EVALUATION_REQUEST",
    }
    for field, expected in identity.items():
        if type(request.get(field)) is not type(expected) or request.get(field) != expected:
            reject("F05-CFE-REQUEST-IDENTITY", field)
    if request["validation_context_id"] != context.identity()["validation_context_id"]:
        reject(
            "F05-CFE-VALIDATION-CONTEXT-ID",
            "request was constructed for a different validation context",
        )
    digests = request["external_artifact_digests"]
    if not isinstance(digests, dict) or set(digests) != {
        "source_model_sha256",
        "linked_artifact_sha256",
        "occurrence_index_sha256",
    }:
        reject("F05-CFE-EXTERNAL-DIGEST-SHAPE", "exact digest fields required")
    expected_digests = {
        "source_model_sha256": sha256(source_model_raw),
        "linked_artifact_sha256": sha256(linked_artifact_raw),
        "occurrence_index_sha256": sha256(occurrence_index_raw),
    }
    for field, expected in expected_digests.items():
        if _sha_field(digests.get(field), field) != expected:
            reject("F05-CFE-EXTERNAL-DIGEST", field)
    payload = {
        key: value
        for key, value in request.items()
        if key != "checked_evaluation_request_construction_id"
    }
    expected_id = _typed_request_id(payload)
    if request["checked_evaluation_request_construction_id"] != expected_id:
        reject("F05-CFE-REQUEST-ID", "digest mismatch")
    if not isinstance(request["finite_profile"], dict):
        reject("F05-CFE-PROFILE-SHAPE", "finite_profile")
    if not isinstance(request["root_inputs"], dict) or set(request["root_inputs"]) != {
        "parameter",
        "pre",
        "post",
        "event",
    }:
        reject("F05-CFE-INPUT-SHAPE", "exact root input fields required")
    if not isinstance(request["resource_profile"], dict):
        reject("F05-CFE-RESOURCE-PROFILE", "object required")
    return request, expected_id


def _resource_profile(raw: Mapping[str, Any]) -> tuple[dict[str, int], Any]:
    if set(raw) != {"tag", *RESOURCE_FIELDS} or raw.get("tag") != "FINITE_EVALUATION_RESOURCE_PROFILE":
        reject("F05-CFE-RESOURCE-PROFILE", "exact fields and tag required")
    requested: dict[str, int] = {}
    for field in RESOURCE_FIELDS:
        value = raw[field]
        if type(value) is not int or value <= 0:
            reject("F05-CFE-RESOURCE-PROFILE", field)
        requested[field] = value
    operator = OPERATOR_HARD_ENVELOPE.evaluation_profile.as_dict()
    effective = {
        field: min(requested[field], operator[field]) for field in RESOURCE_FIELDS
    }
    try:
        return requested, eval_module.ResourceProfile(**effective)
    except ValueError as exc:
        reject("F05-CFE-RESOURCE-PROFILE", _bounded_detail(exc))


def _presence_value(wrapper: Any, label: str, required: bool) -> dict[str, Any] | None:
    if not isinstance(wrapper, dict) or wrapper.get("tag") not in {"ABSENT", "PRESENT"}:
        reject("F05-CFE-INPUT-PRESENCE", label)
    if wrapper["tag"] == "ABSENT":
        if set(wrapper) != {"tag"}:
            reject("F05-CFE-INPUT-PRESENCE", f"{label}:absent-shape")
        if required:
            reject("F05-CFE-INPUT-DOMAIN", f"{label}:required")
        return None
    if set(wrapper) != {"tag", "value"} or not isinstance(wrapper["value"], dict):
        reject("F05-CFE-INPUT-PRESENCE", f"{label}:present-shape")
    if not required:
        reject("F05-CFE-INPUT-DOMAIN", f"{label}:forbidden")
    return wrapper["value"]


def _reconstruct_chain(
    context: ValidationContext,
    source_model_raw: bytes,
    linked_artifact_raw: bytes,
    occurrence_index_raw: bytes,
) -> tuple[Any, dict[str, Any], dict[str, Any], Any, dict[str, Any], dict[str, Any]]:
    source_model = semantics_module.wire_snapshot.parse_canonical_model(source_model_raw)
    grammar = context.grammar()
    schemas = dict(context.generated_outputs)
    wire_result = wire_validator.validate_loaded(
        source_model,
        source_model_raw,
        "Model",
        grammar,
        schemas,
    )
    source_snapshot = semantics_module.wire_snapshot.WireValidatedModelSnapshot.from_wire_validation(
        source_model_raw,
        wire_result,
    )
    source_snapshot.require_wire_validated()
    checker = semantics_module.CoreSyntaxChecker(
        source_snapshot,
        context.static_contract,
        max_link_event_coordinates=OPERATOR_HARD_ENVELOPE.max_link_event_coordinates,
    )
    static_result = checker.check()
    if checker.linked_model_snapshot is None:
        reject("F05-CFE-LINKED-MISSING", "static checker produced no LinkedModel")
    if checker.linked_model_snapshot.artifact_raw != linked_artifact_raw:
        reject(
            "F05-CFE-LINKED-RECONSTRUCTION",
            "supplied LinkedModel differs from source-derived construction",
        )
    linked_result = linked_validator.validate(
        source_model_raw,
        checker.rule_contract,
        linked_artifact_raw,
        max_event_coordinates=OPERATOR_HARD_ENVELOPE.max_link_event_coordinates,
    )
    linked_artifact = checker.linked_model_snapshot.artifact()
    linked = linked_artifact["linked_model"]
    expected_occurrence_count = (
        1
        + len(linked["base_claim_bodies"])
        + sum(
            1
            + sum(
                1
                + 2 * len(branch["updates"])
                + len(branch["event_coordinates"])
                for branch in action["branches"]
            )
            for action in linked["action_bodies"]
        )
    )
    if expected_occurrence_count > OPERATOR_HARD_ENVELOPE.max_checked_occurrences:
        raise OperatorResourceInconclusive(
            "F05-CFE-INCONCLUSIVE-RESOURCE-OCCURRENCES",
            (
                f"{expected_occurrence_count}>"
                f"{OPERATOR_HARD_ENVELOPE.max_checked_occurrences}"
            ),
        )
    eval_contract = context.eval_contract
    expected_occurrences = occurrence_module.materialize(checker, eval_contract)
    if expected_occurrences.artifact_raw != occurrence_index_raw:
        reject(
            "F05-CFE-OCCURRENCE-RECONSTRUCTION",
            "supplied occurrence index differs from source-derived construction",
        )
    occurrence_result = occurrence_module.validate_snapshot(
        occurrence_index_raw,
        linked_artifact,
        checker.rule_contract,
        eval_contract,
    )
    occurrence_artifact = expected_occurrences.artifact()
    return (
        checker,
        linked_artifact,
        occurrence_artifact,
        eval_contract,
        {
            "wire": wire_result,
            "static": static_result,
            "linked": linked_result,
            "validation_context": context.identity(),
        },
        occurrence_result,
    )


def _select_occurrence(
    occurrence_artifact: Mapping[str, Any],
    identifier: Any,
) -> dict[str, Any]:
    if not isinstance(identifier, dict) or set(identifier) != {"tag", "domain", "sha256"}:
        reject("F05-CFE-OCCURRENCE-ID", "exact typed identifier required")
    _sha_field(identifier.get("sha256"), "checked_term_occurrence_id.sha256")
    matches = [
        row
        for row in occurrence_artifact["occurrences"]
        if row["checked_term_occurrence_id"] == identifier
    ]
    if len(matches) != 1:
        reject("F05-CFE-OCCURRENCE-ID", f"match-count={len(matches)}")
    return matches[0]


def _decode_execution(
    request: Mapping[str, Any],
    occurrence: Mapping[str, Any],
    linked_artifact: Mapping[str, Any],
    eval_contract: Any,
) -> tuple[Any, dict[str, Any]]:
    requested_profile, profile = _resource_profile(request["resource_profile"])
    interpretation = eval_module.FiniteInterpretation.decode(
        linked_artifact,
        request["finite_profile"],
        profile,
    )
    provenance = frozenset(occurrence["provenance"])
    root_inputs = request["root_inputs"]
    root_context = occurrence["root_context"]
    environment: dict[str, Any] = {}
    gamma: dict[str, Any] = {}
    if root_context == {"tag": "CLOSED_ROOT"}:
        _presence_value(root_inputs["parameter"], "parameter", False)
        if "PARAM" in provenance:
            reject("F05-CFE-ROOT-PROVENANCE", "closed root contains PARAM")
        if occurrence["gamma"] != [] or occurrence["delta"] != []:
            reject("F05-CFE-ROOT-CONTEXT", "closed runtime Gamma/Delta drift")
    elif isinstance(root_context, dict) and root_context.get("tag") == "ACTION_PARAM_ROOT":
        parameter_raw = _presence_value(root_inputs["parameter"], "parameter", True)
        if parameter_raw is None:
            raise RuntimeError("required parameter disappeared")
        variable = root_context["parameter_variable"]
        parameter_sort = root_context["parameter_sort"]
        slot_raw = root_context["parameter_slot"]
        if (
            not isinstance(variable, str)
            or not variable
            or not isinstance(parameter_sort, dict)
            or not isinstance(slot_raw, list)
            or not slot_raw
            or not all(isinstance(part, str) and part for part in slot_raw)
        ):
            reject("F05-CFE-ROOT-CONTEXT", "invalid action parameter root")
        slot = tuple(slot_raw)
        expected_gamma = [
            {
                "variable": variable,
                "sort": parameter_sort,
                "sources": ["PARAM"],
                "parameter_slot": slot_raw,
            }
        ]
        expected_delta = [
            {
                "variable": variable,
                "dependencies": [{"kind": "PARAM", "subject": slot_raw}],
            }
        ]
        if occurrence["gamma"] != expected_gamma or occurrence["delta"] != expected_delta:
            reject("F05-CFE-ROOT-CONTEXT", "runtime Gamma/Delta derivation drift")
        parameter = interpretation.decode_value(
            parameter_raw,
            parameter_sort,
            "$request.root_inputs.parameter.value",
        )
        environment[variable] = eval_module.EnvBinding.external_parameter(parameter, slot)
        gamma[variable] = eval_module.GammaBinding.create(
            parameter_sort,
            frozenset({"PARAM"}),
            slot,
        )
    else:
        reject("F05-CFE-ROOT-CONTEXT", "unknown checked root context")

    pre_raw = _presence_value(root_inputs["pre"], "pre", "PRE" in provenance)
    post_raw = _presence_value(root_inputs["post"], "post", "POST" in provenance)
    event_raw = _presence_value(root_inputs["event"], "event", "EVENT" in provenance)
    pre = (
        eval_module.StateView.decode(pre_raw, interpretation)
        if pre_raw is not None
        else None
    )
    post = (
        eval_module.StateView.decode(post_raw, interpretation)
        if post_raw is not None
        else None
    )
    event = (
        eval_module.EventView.decode(event_raw, interpretation)
        if event_raw is not None
        else None
    )
    evaluator = eval_module.FiniteEvaluator(
        interpretation,
        rule_contract=eval_contract,
        resource_profile=profile,
    )
    result = evaluator.evaluate_root_in_bound_request_session(
        occurrence["term"],
        environment,
        gamma,
        eval_module.EvalInputs(pre=pre, post=post, event=event),
        provenance,
    )
    if result.observation.value.sort_raw != canonical_bytes(occurrence["result_sort"]):
        raise RuntimeError("checked occurrence result sort drifted after evaluation")
    if not result.observation.dependencies <= result.may_dependencies:
        raise RuntimeError("DynDeps escaped MayDeps at checked request boundary")
    may_sources = {dependency.source for dependency in result.may_dependencies}
    if not may_sources <= provenance:
        raise RuntimeError("MayDeps source kinds escaped checked occurrence provenance")
    return result, {
        "interpretation_id": list(interpretation.interpretation_id),
        "finite_profile_sha256": sha256(canonical_bytes(request["finite_profile"])),
        "requested_resource_profile": requested_profile,
        "requested_resource_profile_sha256": sha256(
            canonical_bytes(request["resource_profile"])
        ),
        "effective_resource_profile": profile.as_dict(),
        "effective_resource_profile_sha256": sha256(
            canonical_bytes(profile.as_dict())
        ),
        "operator_hard_profile_applied": requested_profile != profile.as_dict(),
    }


def execute_checked_request(
    *,
    source_model_raw: bytes,
    linked_artifact_raw: bytes,
    occurrence_index_raw: bytes,
    request_raw: bytes,
) -> CheckedEvaluationOutcome:
    """Run one atomic construction and return an exact non-authorizing taxonomy."""

    with _EXECUTION_LOCK:
        return _execute_checked_request_locked(
            source_model_raw=source_model_raw,
            linked_artifact_raw=linked_artifact_raw,
            occurrence_index_raw=occurrence_index_raw,
            request_raw=request_raw,
        )


def _execute_checked_request_locked(
    *,
    source_model_raw: bytes,
    linked_artifact_raw: bytes,
    occurrence_index_raw: bytes,
    request_raw: bytes,
) -> CheckedEvaluationOutcome:
    request_identity: dict[str, Any] | None = None
    try:
        for label, raw in (
            ("source_model", source_model_raw),
            ("linked_artifact", linked_artifact_raw),
            ("occurrence_index", occurrence_index_raw),
            ("request", request_raw),
        ):
            if type(raw) is not bytes or not raw:
                reject("F05-CFE-ARGUMENT-TYPE", label)
        ingress = {
            "source_model": (
                len(source_model_raw),
                OPERATOR_HARD_ENVELOPE.max_source_model_bytes,
            ),
            "linked_artifact": (
                len(linked_artifact_raw),
                OPERATOR_HARD_ENVELOPE.max_linked_artifact_bytes,
            ),
            "occurrence_index": (
                len(occurrence_index_raw),
                OPERATOR_HARD_ENVELOPE.max_occurrence_index_bytes,
            ),
            "request": (
                len(request_raw),
                OPERATOR_HARD_ENVELOPE.max_request_bytes,
            ),
        }
        for label, (actual, limit) in ingress.items():
            if actual > limit:
                raise OperatorResourceInconclusive(
                    "F05-CFE-INCONCLUSIVE-RESOURCE-INGRESS-BYTES",
                    f"{label}:{actual}>{limit}",
                )
        total_ingress = sum(actual for actual, _ in ingress.values())
        if total_ingress > OPERATOR_HARD_ENVELOPE.max_total_ingress_bytes:
            raise OperatorResourceInconclusive(
                "F05-CFE-INCONCLUSIVE-RESOURCE-TOTAL-INGRESS-BYTES",
                f"{total_ingress}>{OPERATOR_HARD_ENVELOPE.max_total_ingress_bytes}",
            )
        context = validation_context()
        context.assert_module_graph()
        request, request_identity = _validate_request_artifact(
            request_raw,
            source_model_raw,
            linked_artifact_raw,
            occurrence_index_raw,
            context,
        )
        (
            _checker,
            linked_artifact,
            occurrence_artifact,
            eval_contract,
            chain_result,
            occurrence_result,
        ) = _reconstruct_chain(
            context,
            source_model_raw,
            linked_artifact_raw,
            occurrence_index_raw,
        )
        checked_occurrence = _select_occurrence(
            occurrence_artifact,
            request["checked_term_occurrence_id"],
        )
        evaluation_result, interpretation_result = _decode_execution(
            request,
            checked_occurrence,
            linked_artifact,
            eval_contract,
        )
        body = {
            "checked_term_occurrence_id": checked_occurrence[
                "checked_term_occurrence_id"
            ],
            "checked_term_occurrence_index_construction_id": occurrence_artifact[
                "checked_term_occurrence_index_construction_id"
            ],
            "construction_chain": {
                "source_model_sha256": sha256(source_model_raw),
                "linked_artifact_sha256": chain_result["linked"]["artifact_sha256"],
                "linked_model_construction_id": linked_artifact[
                    "linked_model_construction_id"
                ],
                "occurrence_count": occurrence_result["occurrence_count"],
                "source_wire_revalidated": True,
                "static_semantics_reexecuted": True,
                "linked_model_source_reconstructed": True,
                "occurrence_index_source_reconstructed": True,
                "independent_external_validation": False,
            },
            "validation_context": context.identity(),
            "interpretation": interpretation_result,
            "evaluation_result": evaluation_result.as_dict(),
            "semantic_context_digest": {
                "status": "NOT_ISSUED",
                "reason": "TRANSITION_CLAIM_MORPHISM_THEOREM_AND_PROOF_RULES_NOT_FROZEN",
            },
        }
        result_preimage = {
            "request_construction_id": request_identity,
            "validation_context_id": context.identity()["validation_context_id"],
            "outcome_tag": "SUCCESS",
            "body": body,
        }
        body["checked_evaluation_result_construction_id"] = _typed_result_id(
            result_preimage
        )
        return _outcome("SUCCESS", request_raw, request_identity, body)
    except OperatorResourceInconclusive as exc:
        return _outcome(
            "INCONCLUSIVE_RESOURCE",
            request_raw,
            request_identity,
            {"reason_id": exc.reason_id, "detail": _bounded_detail(exc.detail)},
        )
    except linked_validator.InconclusiveResource as exc:
        return _outcome(
            "INCONCLUSIVE_RESOURCE",
            request_raw,
            request_identity,
            {"reason_id": exc.reason_id, "detail": _bounded_detail(exc.detail)},
        )
    except RequestUnsupported as exc:
        return _outcome(
            "INCONCLUSIVE_UNSUPPORTED",
            request_raw,
            request_identity,
            {"reason_id": exc.reason_id, "detail": _bounded_detail(exc.detail)},
        )
    except eval_module.ValueInconclusive as exc:
        return _outcome(
            "INCONCLUSIVE_RESOURCE",
            request_raw,
            request_identity,
            {"reason_id": exc.reason_id, "detail": _bounded_detail(exc.detail)},
        )
    except semantics_module.VerificationInconclusive as exc:
        return _outcome(
            "INCONCLUSIVE_RESOURCE",
            request_raw,
            request_identity,
            {"reason_id": exc.reason_id, "detail": _bounded_detail(exc.detail)},
        )
    except ValidationContextFailure as exc:
        return _outcome(
            "INTERNAL_FAILURE",
            request_raw,
            request_identity,
            {
                "failure_class": type(exc).__name__,
                "reason_id": exc.reason_id,
                "detail_disclosed": False,
                "evidence_usable": False,
            },
        )
    except (
        RequestReject,
        occurrence_module.Reject,
        eval_module.EvalReject,
        eval_module.ValueReject,
        eval_module.RuleReject,
        semantics_module.SemanticReject,
        semantics_module.wire_snapshot.SnapshotReject,
        wire_validator.Reject,
        linked_validator.Reject,
    ) as exc:
        reject_id = getattr(exc, "reject_id", "F05-CFE-REJECT")
        detail = _bounded_detail(getattr(exc, "detail", exc))
        wrapped_host_resource = any(
            marker in reject_id or marker in detail
            for marker in (
                "PARSE-RESOURCE",
                "CANONICALIZE-RESOURCE",
                "HOST-RESOURCE",
                "RESOURCE-WIRE-RECURSION",
                "RESOURCE-HOST-RECURSION",
            )
        )
        if _is_operator_limit_id(reject_id):
            return _outcome(
                "INCONCLUSIVE_RESOURCE",
                request_raw,
                request_identity,
                {
                    "reason_id": reject_id,
                    "detail": detail,
                    "operator_meter": "captured_parser_or_static_limit",
                },
            )
        if wrapped_host_resource:
            return _outcome(
                "INTERNAL_FAILURE",
                request_raw,
                request_identity,
                {
                    "failure_class": type(exc).__name__,
                    "wrapped_resource_failure": True,
                    "evidence_usable": False,
                },
            )
        return _outcome(
            "REJECT",
            request_raw,
            request_identity,
            {
                "reject_id": reject_id,
                "detail": detail,
                "classification_source": type(exc).__name__,
            },
        )
    except (MemoryError, RecursionError) as exc:
        return _outcome(
            "INTERNAL_FAILURE",
            request_raw,
            request_identity,
            {
                "failure_class": type(exc).__name__,
                "host_resource_failure_not_ledger_attributed": True,
                "evidence_usable": False,
            },
        )
    except Exception as exc:
        return _outcome(
            "INTERNAL_FAILURE",
            request_raw,
            request_identity,
            {
                "failure_class": type(exc).__name__,
                "detail_disclosed": False,
                "evidence_usable": False,
            },
        )
