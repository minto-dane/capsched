"""Fail-closed loader for the DL-F0-5 evaluation/dependency rule table.

This validates representation, source bindings, and closed dispatch domains.
It does not prove the denotational rules or authorize F0 acceptance.
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
RULES_PATH = F0 / "f0-eval-dependency-rules-v5.json"
GRAMMAR_PATH = F0 / "f0-machine-grammar-v5.json"
STATIC_RULES_PATH = F0 / "f0-static-semantics-rules-v5.json"
NORMATIVE_PATHS = {
    "F05-00": F0 / "f0-00-core-language-v5.md",
    "F05-01": F0 / "f0-01-model-transition-claims-v5.md",
    "F05-02": F0 / "f0-02-morphisms-proof-boundary-v5.md",
}

MAX_BYTES = 4 * 1024 * 1024
MAX_JSON_DEPTH = 512
MAX_JSON_NODES = 2_000_000
MAX_COLLECTION_ITEMS = 1_000_000
MAX_INTEGER_DIGITS = 4096
MAX_DIAGNOSTIC_PATH = 512

EXPECTED_TOP_LEVEL = {
    "schema_version",
    "language_id",
    "artifact_id",
    "status",
    "bindings",
    "semantic_domains",
    "environment_contract",
    "denotational_contract",
    "carrier_rules",
    "carrier_reference_rules",
    "ground_value_rules",
    "evaluation_rules",
    "may_dependency_rules",
    "evaluation_reference_rules",
    "finite_profile_contract",
    "finite_execution_contract",
    "result_taxonomy",
    "metatheory_obligations",
    "nonclaims",
    "authorization",
}
EXPECTED_IDENTITY = {
    "schema_version": 1,
    "language_id": "DL-F0-5",
    "artifact_id": "domainlease-r11-epoch2-f0-eval-dependency-rules-v5-draft1",
    "status": "construction_draft_not_review_target",
}
EXPECTED_BINDING_FIELDS = {
    "grammar_surface_sha256",
    "grammar_raw_sha256",
    "grammar_canonical_sha256",
    "static_rules_raw_sha256",
    "static_rules_canonical_sha256",
    "normative_part_sha256",
}
EXPECTED_EVAL_FIELDS = {
    "tag",
    "eval_rule",
    "eval_operands",
    "may_operands",
    "dependency_rule",
    "trace_rule",
}
EXPECTED_CARRIER_FIELDS = {
    "sort_tag",
    "denotation_rule",
    "equality_rule",
    "finite_enumeration_rule",
}
EXPECTED_GROUND_FIELDS = {
    "value_tag",
    "sort_rule",
    "decode_rule",
    "canonical_rule",
}
EXPECTED_AUTHORIZATION = {
    "F0_local_acceptance": False,
    "F1_design": False,
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
            reject("F05-ER-DUPLICATE-KEY", key)
        result[key] = value
    return result


def _reject_float(token: str) -> NoReturn:
    reject("F05-ER-FLOAT", token)


def _reject_non_json_number(token: str) -> NoReturn:
    reject("F05-ER-NON-JSON-NUMBER", token)


def _parse_integer(token: str) -> int:
    digits = token[1:] if token.startswith("-") else token
    if len(digits) > MAX_INTEGER_DIGITS:
        reject("F05-ER-INTEGER-DIGITS", str(len(digits)))
    try:
        return int(token)
    except ValueError as exc:
        reject("F05-ER-INTEGER", type(exc).__name__)


def _child_path(path: str, suffix: str) -> str:
    candidate = path + suffix
    if len(candidate) <= MAX_DIAGNOSTIC_PATH:
        return candidate
    return candidate[: MAX_DIAGNOSTIC_PATH - 3] + "..."


def _reject_unsafe_scalar(value: Any) -> None:
    stack: list[tuple[Any, str, int]] = [(value, "$", 0)]
    nodes = 0
    while stack:
        current, path, depth = stack.pop()
        nodes += 1
        if nodes > MAX_JSON_NODES:
            reject("F05-ER-NODE-LIMIT", str(nodes))
        if depth > MAX_JSON_DEPTH:
            reject("F05-ER-DEPTH", f"{path}:{depth}")
        if current is None or isinstance(current, float):
            reject("F05-ER-UNSAFE-SCALAR", path)
        if isinstance(current, bool):
            continue
        if isinstance(current, int):
            if current < 0:
                reject("F05-ER-NEGATIVE-INTEGER", path)
            continue
        if isinstance(current, str):
            try:
                current.encode("ascii")
            except UnicodeEncodeError:
                reject("F05-ER-NON-ASCII-STRING", path)
            if any(ord(character) < 0x20 or ord(character) == 0x7F for character in current):
                reject("F05-ER-CONTROL-STRING", path)
            continue
        if isinstance(current, dict):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-ER-COLLECTION-LIMIT", path)
            for key, child in current.items():
                if not isinstance(key, str):
                    reject("F05-ER-NON-STRING-KEY", path)
                try:
                    key.encode("ascii")
                except UnicodeEncodeError:
                    reject("F05-ER-NON-ASCII-KEY", path)
                stack.append((child, _child_path(path, f".{key}"), depth + 1))
            continue
        if isinstance(current, list):
            if len(current) > MAX_COLLECTION_ITEMS:
                reject("F05-ER-COLLECTION-LIMIT", path)
            for index in range(len(current) - 1, -1, -1):
                stack.append((current[index], _child_path(path, f"[{index}]"), depth + 1))
            continue
        reject("F05-ER-UNSAFE-TYPE", f"{path}:{type(current).__name__}")


def read_once(path: Path) -> bytes:
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    except OSError as exc:
        reject("F05-ER-FILE-OPEN", f"{path}:{exc.errno}")
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode):
            reject("F05-ER-FILE-TYPE", str(path))
        if before.st_size <= 0 or before.st_size > MAX_BYTES:
            reject("F05-ER-FILE-SIZE", f"{path}:{before.st_size}")
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
        before_id = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns)
        after_id = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        if before_id != after_id or len(raw) != before.st_size:
            reject("F05-ER-FILE-CHANGED-DURING-READ", str(path))
        return raw
    finally:
        os.close(descriptor)


def parse_ascii_json(raw: bytes, path: Path) -> Any:
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError as exc:
        reject("F05-ER-NON-ASCII-JSON", f"{path}:{exc.start}")
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
        reject("F05-ER-JSON", f"{path}:{exc.lineno}:{exc.colno}")
    except (MemoryError, RecursionError, ValueError) as exc:
        reject("F05-ER-PARSE-RESOURCE", f"{path}:{type(exc).__name__}")
    _reject_unsafe_scalar(value)
    return value


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _exact_type(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(_exact_type(actual[key], expected[key]) for key in actual)
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            _exact_type(left, right) for left, right in zip(actual, expected, strict=True)
        )
    return actual == expected


def _require_object(value: Any, fields: set[str], path: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != fields:
        reject("F05-ER-SHAPE", f"{path}:fields")
    return value


def _require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        reject("F05-ER-SHAPE", f"{path}:string")
    return value


def _require_string_list(value: Any, path: str) -> tuple[str, ...]:
    if not isinstance(value, list):
        reject("F05-ER-SHAPE", f"{path}:list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(_require_string(item, f"{path}[{index}]"))
    return tuple(result)


def _tag_domain(grammar: dict[str, Any], section: str, prefix: str | None = None) -> set[str]:
    rows = grammar.get(section)
    if not isinstance(rows, list):
        reject("F05-ER-GRAMMAR-SHAPE", section)
    result: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            reject("F05-ER-GRAMMAR-SHAPE", f"{section}[{index}]")
        tag = _require_string(row.get("tag"), f"{section}[{index}].tag")
        if prefix is None or tag.startswith(prefix):
            if tag in result:
                reject("F05-ER-GRAMMAR-DUPLICATE-TAG", tag)
            result.add(tag)
    return result


@dataclass(frozen=True)
class EvalRule:
    tag: str
    eval_rule: str
    eval_operands: tuple[str, ...]
    may_operands: tuple[str, ...]
    dependency_rule: str
    trace_rule: str


@dataclass(frozen=True)
class CarrierRule:
    sort_tag: str
    denotation_rule: str
    equality_rule: str
    finite_enumeration_rule: str


@dataclass(frozen=True)
class GroundValueRule:
    value_tag: str
    sort_rule: str
    decode_rule: str
    canonical_rule: str


@dataclass(frozen=True)
class EvalRuleContract:
    rules_raw_sha256: str
    rules_canonical_sha256: str
    grammar_raw_sha256: str
    grammar_canonical_sha256: str
    static_rules_raw_sha256: str
    static_rules_canonical_sha256: str
    normative_part_sha256: Mapping[str, str]
    semantic_domains: Mapping[str, Any]
    environment_contract: Mapping[str, Any]
    denotational_contract: Mapping[str, Any]
    carrier_rules: Mapping[str, CarrierRule]
    carrier_reference_rules: Mapping[str, str]
    ground_value_rules: Mapping[str, GroundValueRule]
    evaluation_rules: Mapping[str, EvalRule]
    may_dependency_rules: Mapping[str, str]
    evaluation_reference_rules: Mapping[str, str]
    finite_profile_contract: Mapping[str, Any]
    finite_execution_contract: Mapping[str, Any]
    result_taxonomy: Mapping[str, str]
    metatheory_obligations: tuple[str, ...]
    nonclaims: tuple[str, ...]


def _deep_freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return MappingProxyType({key: _deep_freeze(child) for key, child in value.items()})
    if isinstance(value, list):
        return tuple(_deep_freeze(child) for child in value)
    return value


def _freeze_mapping(value: dict[str, Any]) -> Mapping[str, Any]:
    detached = json.loads(canonical_bytes(value).decode("ascii"))
    frozen = _deep_freeze(detached)
    if not isinstance(frozen, Mapping):
        raise TypeError("frozen mapping expected")
    return frozen


def validate_loaded(
    rules_raw: bytes,
    grammar_raw: bytes,
    static_raw: bytes,
    normative_raw: Mapping[str, bytes],
    rules_path: Path = RULES_PATH,
    grammar_path: Path = GRAMMAR_PATH,
    static_path: Path = STATIC_RULES_PATH,
) -> EvalRuleContract:
    rules = parse_ascii_json(rules_raw, rules_path)
    grammar = parse_ascii_json(grammar_raw, grammar_path)
    static_rules = parse_ascii_json(static_raw, static_path)
    if not isinstance(rules, dict) or set(rules) != EXPECTED_TOP_LEVEL:
        reject("F05-ER-TOP-LEVEL", "exact fields required")
    for key, expected in EXPECTED_IDENTITY.items():
        if not _exact_type(rules.get(key), expected):
            reject("F05-ER-IDENTITY", key)

    bindings = _require_object(rules["bindings"], EXPECTED_BINDING_FIELDS, "bindings")
    normative_hashes = _require_object(
        bindings["normative_part_sha256"], set(NORMATIVE_PATHS), "bindings.normative_part_sha256"
    )
    if set(normative_raw) != set(NORMATIVE_PATHS):
        reject(
            "F05-ER-NORMATIVE-DOMAIN",
            f"actual={sorted(normative_raw)} expected={sorted(NORMATIVE_PATHS)}",
        )
    actual_bindings = {
        "grammar_surface_sha256": grammar.get("surface_digest", {}).get("sha256") if isinstance(grammar.get("surface_digest"), dict) else None,
        "grammar_raw_sha256": sha256(grammar_raw),
        "grammar_canonical_sha256": sha256(canonical_bytes(grammar)),
        "static_rules_raw_sha256": sha256(static_raw),
        "static_rules_canonical_sha256": sha256(canonical_bytes(static_rules)),
    }
    for key, actual in actual_bindings.items():
        if bindings.get(key) != actual:
            reject("F05-ER-BINDING", f"{key}:actual={actual}")
    for part, raw in normative_raw.items():
        if normative_hashes.get(part) != sha256(raw):
            reject("F05-ER-NORMATIVE-BINDING", part)

    term_domain = _tag_domain(grammar, "term_nodes")
    sort_domain = _tag_domain(grammar, "sort_nodes")
    ground_domain = _tag_domain(grammar, "ground_value_nodes", "VALUE_")

    evaluation: dict[str, EvalRule] = {}
    rows = rules["evaluation_rules"]
    if not isinstance(rows, list):
        reject("F05-ER-SHAPE", "evaluation_rules")
    for index, raw_row in enumerate(rows):
        row = _require_object(raw_row, EXPECTED_EVAL_FIELDS, f"evaluation_rules[{index}]")
        tag = _require_string(row["tag"], f"evaluation_rules[{index}].tag")
        if tag in evaluation:
            reject("F05-ER-EVAL-DUPLICATE", tag)
        evaluation[tag] = EvalRule(
            tag=tag,
            eval_rule=_require_string(row["eval_rule"], f"evaluation_rules[{index}].eval_rule"),
            eval_operands=_require_string_list(row["eval_operands"], f"evaluation_rules[{index}].eval_operands"),
            may_operands=_require_string_list(row["may_operands"], f"evaluation_rules[{index}].may_operands"),
            dependency_rule=_require_string(row["dependency_rule"], f"evaluation_rules[{index}].dependency_rule"),
            trace_rule=_require_string(row["trace_rule"], f"evaluation_rules[{index}].trace_rule"),
        )
    if set(evaluation) != term_domain:
        reject("F05-ER-EVAL-DOMAIN", "must equal grammar TermNode tags")

    may_raw = rules["may_dependency_rules"]
    if not isinstance(may_raw, dict) or set(may_raw) != term_domain:
        reject("F05-ER-MAY-DOMAIN", "must equal grammar TermNode tags")
    may_rules = {tag: _require_string(value, f"may_dependency_rules.{tag}") for tag, value in may_raw.items()}
    evaluation_refs_raw = rules["evaluation_reference_rules"]
    if not isinstance(evaluation_refs_raw, dict) or set(evaluation_refs_raw) != term_domain:
        reject("F05-ER-EVAL-REF-DOMAIN", "must equal grammar TermNode tags")
    evaluation_refs = {
        tag: _require_string(value, f"evaluation_reference_rules.{tag}")
        for tag, value in evaluation_refs_raw.items()
    }

    carriers: dict[str, CarrierRule] = {}
    carrier_rows = rules["carrier_rules"]
    if not isinstance(carrier_rows, list):
        reject("F05-ER-SHAPE", "carrier_rules")
    for index, raw_row in enumerate(carrier_rows):
        row = _require_object(raw_row, EXPECTED_CARRIER_FIELDS, f"carrier_rules[{index}]")
        tag = _require_string(row["sort_tag"], f"carrier_rules[{index}].sort_tag")
        if tag in carriers:
            reject("F05-ER-CARRIER-DUPLICATE", tag)
        carriers[tag] = CarrierRule(
            sort_tag=tag,
            denotation_rule=_require_string(row["denotation_rule"], f"carrier_rules[{index}].denotation_rule"),
            equality_rule=_require_string(row["equality_rule"], f"carrier_rules[{index}].equality_rule"),
            finite_enumeration_rule=_require_string(row["finite_enumeration_rule"], f"carrier_rules[{index}].finite_enumeration_rule"),
        )
    if set(carriers) != sort_domain:
        reject("F05-ER-CARRIER-DOMAIN", "must equal grammar Sort tags")
    carrier_refs_raw = rules["carrier_reference_rules"]
    if not isinstance(carrier_refs_raw, dict) or set(carrier_refs_raw) != sort_domain:
        reject("F05-ER-CARRIER-REF-DOMAIN", "must equal grammar Sort tags")
    carrier_refs = {
        tag: _require_string(value, f"carrier_reference_rules.{tag}")
        for tag, value in carrier_refs_raw.items()
    }

    ground_values: dict[str, GroundValueRule] = {}
    ground_rows = rules["ground_value_rules"]
    if not isinstance(ground_rows, list):
        reject("F05-ER-SHAPE", "ground_value_rules")
    for index, raw_row in enumerate(ground_rows):
        row = _require_object(raw_row, EXPECTED_GROUND_FIELDS, f"ground_value_rules[{index}]")
        tag = _require_string(row["value_tag"], f"ground_value_rules[{index}].value_tag")
        if tag in ground_values:
            reject("F05-ER-GROUND-DUPLICATE", tag)
        ground_values[tag] = GroundValueRule(
            value_tag=tag,
            sort_rule=_require_string(row["sort_rule"], f"ground_value_rules[{index}].sort_rule"),
            decode_rule=_require_string(row["decode_rule"], f"ground_value_rules[{index}].decode_rule"),
            canonical_rule=_require_string(row["canonical_rule"], f"ground_value_rules[{index}].canonical_rule"),
        )
    if set(ground_values) != ground_domain:
        reject("F05-ER-GROUND-DOMAIN", "must equal grammar VALUE tags")

    for field in (
        "semantic_domains",
        "environment_contract",
        "denotational_contract",
        "finite_profile_contract",
        "finite_execution_contract",
        "result_taxonomy",
    ):
        if not isinstance(rules[field], dict) or not rules[field]:
            reject("F05-ER-SHAPE", field)
    obligations = _require_string_list(rules["metatheory_obligations"], "metatheory_obligations")
    if len(set(obligations)) != len(obligations):
        reject("F05-ER-METATHEORY-DUPLICATE", "metatheory_obligations")
    nonclaims = _require_string_list(rules["nonclaims"], "nonclaims")
    if not _exact_type(rules["authorization"], EXPECTED_AUTHORIZATION):
        reject("F05-ER-AUTHORIZATION", "must remain all false")

    return EvalRuleContract(
        rules_raw_sha256=sha256(rules_raw),
        rules_canonical_sha256=sha256(canonical_bytes(rules)),
        grammar_raw_sha256=sha256(grammar_raw),
        grammar_canonical_sha256=sha256(canonical_bytes(grammar)),
        static_rules_raw_sha256=sha256(static_raw),
        static_rules_canonical_sha256=sha256(canonical_bytes(static_rules)),
        normative_part_sha256=MappingProxyType(dict(normative_hashes)),
        semantic_domains=_freeze_mapping(rules["semantic_domains"]),
        environment_contract=_freeze_mapping(rules["environment_contract"]),
        denotational_contract=_freeze_mapping(rules["denotational_contract"]),
        carrier_rules=MappingProxyType(carriers),
        carrier_reference_rules=MappingProxyType(carrier_refs),
        ground_value_rules=MappingProxyType(ground_values),
        evaluation_rules=MappingProxyType(evaluation),
        may_dependency_rules=MappingProxyType(may_rules),
        evaluation_reference_rules=MappingProxyType(evaluation_refs),
        finite_profile_contract=_freeze_mapping(rules["finite_profile_contract"]),
        finite_execution_contract=_freeze_mapping(rules["finite_execution_contract"]),
        result_taxonomy=MappingProxyType(dict(rules["result_taxonomy"])),
        metatheory_obligations=obligations,
        nonclaims=nonclaims,
    )


def load_contract(
    rules_path: Path = RULES_PATH,
    grammar_path: Path = GRAMMAR_PATH,
    static_path: Path = STATIC_RULES_PATH,
) -> EvalRuleContract:
    return validate_loaded(
        read_once(rules_path),
        read_once(grammar_path),
        read_once(static_path),
        {part: read_once(path) for part, path in NORMATIVE_PATHS.items()},
        rules_path,
        grammar_path,
        static_path,
    )


def result(contract: EvalRuleContract) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "status": "construction_eval_dependency_rule_table_shape_passed",
        "authority": "local_rule_inventory_and_source_binding_only",
        "language_id": "DL-F0-5",
        "rules_raw_sha256": contract.rules_raw_sha256,
        "rules_canonical_sha256": contract.rules_canonical_sha256,
        "carrier_rule_count": len(contract.carrier_rules),
        "carrier_reference_rule_count": len(contract.carrier_reference_rules),
        "ground_value_rule_count": len(contract.ground_value_rules),
        "evaluation_rule_count": len(contract.evaluation_rules),
        "may_dependency_rule_count": len(contract.may_dependency_rules),
        "evaluation_reference_rule_count": len(contract.evaluation_reference_rules),
        "metatheory_obligation_count": len(contract.metatheory_obligations),
        "implementation_parity_bound": False,
        "evaluation_validated": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
        "nonclaims": list(contract.nonclaims),
    }
