"""DL-F0-5 source-level static semantics under construction."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from dataclasses import dataclass
from typing import Any, Mapping, NoReturn


def _load_local_module(name: str, path: Path):
    existing = sys.modules.get(name)
    if existing is not None:
        existing_path = getattr(existing, "__file__", None)
        if existing_path is None or Path(existing_path).resolve() != path.resolve():
            raise RuntimeError(f"module identity collision for {name}")
        return existing
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


HERE = Path(__file__).resolve().parent
static_registry = _load_local_module(
    "f0_static_checker_registry_v5",
    HERE / "f0_static_checker_registry_v5.py",
)
static_rules = _load_local_module(
    "f0_static_rules_v5",
    HERE / "f0_static_rules_v5.py",
)
wire_snapshot = _load_local_module(
    "f0_wire_snapshot_v5",
    HERE / "f0_wire_snapshot_v5.py",
)
linked_model = _load_local_module(
    "f0_linked_model_v5",
    HERE / "f0_linked_model_v5.py",
)


PARAM = "PARAM"
PRE = "PRE"
POST = "POST"
EVENT = "EVENT"
MAX_TERM_NODES = 1_000_000
MAX_TERM_DEPTH = 192
MODULE_DIGEST_DOMAIN = b"DL-F0-5|MODULE|DL-F0-CJSON-1|"

CORE_LINK_IMPLEMENTATION_HANDLERS = {
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

NAMED_DECLARATIONS = {
    "DECL_ATOM",
    "DECL_ENUM",
    "DECL_UNIT",
    "DECL_LIMIT",
    "DECL_RECORD",
    "DECL_VARIANT",
    "DECL_CONSTANT",
    "DECL_STATE_PRODUCT",
    "DECL_EVENT_CHANNEL",
    "DECL_ACTION",
    "DECL_PREMISE",
    "DECL_CLAIM_BASE_ALWAYS",
}


class SemanticReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


class VerificationInconclusive(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise SemanticReject(reject_id, detail)


def inconclusive(reason_id: str, detail: str) -> NoReturn:
    raise VerificationInconclusive(reason_id, detail)


def _type_strict_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, Mapping):
        return set(actual) == set(expected) and all(
            _type_strict_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, (list, tuple)):
        return len(actual) == len(expected) and all(
            _type_strict_equal(left, right)
            for left, right in zip(actual, expected, strict=True)
        )
    return actual == expected


def _binder_contract_tuple(tag: str, rule: Mapping[str, str]) -> tuple[str, ...]:
    if tag == "TERM_MATCH_VARIANT":
        fields = (
            "kind",
            "collection",
            "variable",
            "scope",
            "sort_source",
            "provenance_source",
            "freshness",
        )
    else:
        fields = (
            "kind",
            "variable",
            "scope",
            "sort_source",
            "provenance_source",
            "freshness",
        )
    try:
        return tuple(rule[field] for field in fields)
    except KeyError as exc:
        reject("F05-CORE-RULE-BINDER-SHAPE", f"{tag}:{exc}")


def bind_static_rule_contract(contract: static_rules.StaticRuleContract) -> None:
    term_contract = {
        tag: (
            rule.typing_rule,
            rule.result_rule,
            rule.provenance_rule,
            rule.binder_rule,
        )
        for tag, rule in contract.term_rules.items()
    }
    term_registry = {
        tag: tuple(handler)
        for tag, handler in static_registry.TERM_HANDLERS.items()
    }
    binder_contract = {
        tag: _binder_contract_tuple(tag, rule)
        for tag, rule in contract.binder_rules.items()
    }
    link_materialization = contract.link_materialization
    declaration_link_contract = {
        tag: (
            rule.signature_fields,
            rule.signature_derived,
            rule.body_kind,
            rule.body_fields,
            rule.carrier_role,
        )
        for tag, rule in link_materialization.declaration_rules.items()
    }
    always_linked_contract = {
        tag: (rule.target, rule.fields)
        for tag, rule in link_materialization.always_linked_rules.items()
    }
    identity_preimage_contract = {
        kind: (
            rule.domain_field,
            rule.fields,
            rule.stability,
            rule.binder_policy,
        )
        for kind, rule in link_materialization.identity_preimages.items()
    }
    comparisons = {
        "provenance_combiner": (
            contract.provenance_combiner,
            static_registry.PROVENANCE_COMBINER,
        ),
        "phase": (dict(contract.phase_rules), dict(static_registry.PHASE_HANDLERS)),
        "link": (dict(contract.link_rules), dict(static_registry.LINK_HANDLERS)),
        "link_materialization_status": (
            link_materialization.status,
            static_registry.LINK_MATERIALIZATION_STATUS,
        ),
        "declaration_link": (
            declaration_link_contract,
            {
                tag: tuple(handler)
                for tag, handler in static_registry.DECLARATION_LINK_HANDLERS.items()
            },
        ),
        "always_linked": (
            always_linked_contract,
            {
                tag: tuple(handler)
                for tag, handler in static_registry.ALWAYS_LINKED_HANDLERS.items()
            },
        ),
        "module_init_link": (
            dict(link_materialization.module_init),
            dict(static_registry.MODULE_INIT_LINK),
        ),
        "event_totalization": (
            dict(link_materialization.event_totalization),
            dict(static_registry.EVENT_TOTALIZATION),
        ),
        "link_identity": (
            dict(link_materialization.identity),
            dict(static_registry.LINK_IDENTITY),
        ),
        "link_identity_preimages": (
            identity_preimage_contract,
            {
                kind: tuple(handler)
                for kind, handler in static_registry.IDENTITY_PREIMAGE_HANDLERS.items()
            },
        ),
        "source_binding_fields": (
            link_materialization.source_binding_fields,
            static_registry.SOURCE_BINDING_FIELDS,
        ),
        "linked_model_fields": (
            link_materialization.linked_model_fields,
            static_registry.LINKED_MODEL_FIELDS,
        ),
        "final_identity_issued": (
            link_materialization.final_identity_issued,
            static_registry.FINAL_IDENTITY_ISSUED,
        ),
        "sort": (dict(contract.sort_rules), dict(static_registry.SORT_HANDLERS)),
        "premise": (
            dict(contract.premise_rules),
            dict(static_registry.PREMISE_HANDLERS),
        ),
        "term": (term_contract, term_registry),
        "binder": (binder_contract, dict(static_registry.BINDER_HANDLERS)),
        "relation": (
            dict(contract.relation_boundary),
            dict(static_registry.RELATION_BOUNDARY),
        ),
        "update": (dict(contract.update_rules), dict(static_registry.UPDATE_HANDLERS)),
        "body": (dict(contract.body_rules), dict(static_registry.BODY_HANDLERS)),
    }
    for family, (actual, expected) in comparisons.items():
        if not _type_strict_equal(actual, expected):
            reject(
                "F05-CORE-RULE-REGISTRY-DRIFT",
                f"{family}:contract={actual!r} registry={expected!r}",
            )


STATIC_RULE_CONTRACT = static_rules.load_contract()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def module_content_sha256(value: Any) -> str:
    return hashlib.sha256(MODULE_DIGEST_DOMAIN + canonical_bytes(value)).hexdigest()


def qname(value: Any, path: str) -> tuple[str, str]:
    if (
        not isinstance(value, list)
        or len(value) != 2
        or not all(isinstance(item, str) for item in value)
    ):
        reject("F05-CORE-QNAME", path)
    return value[0], value[1]


def sort_key(sort: dict[str, Any]) -> bytes:
    return canonical_bytes(sort)


def sort_bool() -> dict[str, Any]:
    return {"tag": "SORT_BOOL"}


def sort_one() -> dict[str, Any]:
    return {"tag": "SORT_ONE"}


def sort_option(element: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_OPTION", "element": element}


def sort_finset(element: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_FINSET", "element": element}


def sort_totalmap(key: dict[str, Any], value: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_TOTALMAP", "key": key, "value": value}


@dataclass(frozen=True)
class Typed:
    sort: dict[str, Any]
    provenance: frozenset[str]


@dataclass(frozen=True)
class DeclarationInfo:
    tag: str
    node: dict[str, Any]
    module: str
    path: str


@dataclass(frozen=True)
class ArithmeticBinding:
    result_sort: dict[str, Any]
    module: str
    path: str


class CoreSyntaxChecker:
    def __init__(
        self,
        source_snapshot: wire_snapshot.WireValidatedModelSnapshot,
        rule_contract: static_rules.StaticRuleContract = STATIC_RULE_CONTRACT,
        *,
        max_link_event_coordinates: int | None = None,
    ) -> None:
        if not isinstance(source_snapshot, wire_snapshot.WireValidatedModelSnapshot):
            raise TypeError(
                "CoreSyntaxChecker requires WireValidatedModelSnapshot; "
                "use for_internal_test_model() only in hostile/unit tests"
            )
        self.source_snapshot = source_snapshot
        try:
            self.model = source_snapshot.parse_model()
        except wire_snapshot.SnapshotReject as exc:
            reject("F05-CORE-SNAPSHOT", f"{exc.reject_id}:{exc.detail}")
        self.rule_contract = rule_contract
        self.max_link_event_coordinates = max_link_event_coordinates
        self.modules: dict[str, dict[str, Any]] = {}
        self.active_modules: frozenset[str] = frozenset()
        self.module_paths: dict[str, str] = {}
        self.visibility: dict[str, frozenset[str]] = {}
        self.declarations: dict[tuple[str, str], DeclarationInfo] = {}
        self.constraints: list[tuple[str, dict[str, Any], str]] = []
        self.arith_declarations: list[tuple[str, dict[str, Any], str]] = []
        self.arith_results: dict[bytes, ArithmeticBinding] = {}
        self.named_type_cell_sort: dict[tuple[str, str], bool] = {}
        self.module_digests: dict[str, str] = {}
        self.owned_event_channels: dict[
            str, dict[tuple[str, str], DeclarationInfo]
        ] = {}
        self._checked = False
        self.term_count = 0
        self.term_tag_counts: dict[str, int] = {}
        self.action_count = 0
        self.branch_count = 0
        self.update_count = 0
        self.emit_count = 0
        self.term_results: dict[int, Typed] = {}
        self.term_contexts: dict[int, tuple[tuple[str, bytes, tuple[str, ...]], ...]] = {}
        self.term_objects: dict[int, dict[str, Any]] = {}
        self.sort_rule_counts: dict[str, int] = {}
        self.premise_rule_counts: dict[str, int] = {}
        self.term_typing_rule_counts: dict[str, int] = {}
        self.update_rule_counts: dict[str, int] = {}
        self.body_rule_counts: dict[str, int] = {}
        self.binder_rule_counts: dict[str, int] = {}
        self.binder_tag_counts: dict[str, int] = {}
        self.link_rules_consumed: set[str] = set()
        self.linked_model_snapshot: Any | None = None
        self.term_result_rederived_count = 0
        self.term_provenance_rederived_count = 0
        self.binder_binding_count = 0

    @classmethod
    def for_internal_test_model(
        cls,
        model: Mapping[str, Any],
        rule_contract: static_rules.StaticRuleContract = STATIC_RULE_CONTRACT,
    ) -> "CoreSyntaxChecker":
        return cls(
            wire_snapshot.WireValidatedModelSnapshot.for_internal_test(model),
            rule_contract,
        )

    def check(self) -> dict[str, Any]:
        if self._checked:
            raise RuntimeError("CoreSyntaxChecker instances are single-use")
        self._checked = True
        bind_static_rule_contract(self.rule_contract)
        self._index_modules()
        self._check_import_graph()
        self._index_declarations()
        self._check_type_and_resource_declarations()
        self._check_arithmetic_bindings()
        self._check_constraints_premises_actions_claims_and_init()
        for link_rule in (
            "active_modules",
            "active_import_closure",
            "active_bodies",
            "inactive_channel_bundle_coordinates",
            "claim_package_claims",
            "declaration_ownership",
            "init",
            "linked_model_materialization",
            "imports_authorize_effects",
            "same_snapshot_for_wire_and_semantics",
        ):
            self._consume_link_rule(link_rule)
        self.linked_model_snapshot = linked_model.materialize(
            self.source_snapshot,
            self.rule_contract,
            reject,
            max_event_coordinates=self.max_link_event_coordinates,
            inconclusive=inconclusive,
        )
        linked = self.linked_model_snapshot.linked_model()
        return {
            "module_count": len(self.modules),
            "active_module_count": len(self.active_modules),
            "declaration_count": len(self.declarations),
            "constraint_count": len(self.constraints),
            "arithmetic_binding_count": len(self.arith_results),
            "action_count": self.action_count,
            "active_action_count": len(linked["action_bodies"]),
            "active_premise_count": len(linked["class_premise_bodies"]),
            "active_claim_count": len(linked["base_claim_bodies"]),
            "linked_state_product_count": len(
                linked["sigma"]["state_product_carriers"]
            ),
            "linked_event_channel_count": len(
                linked["sigma"]["event_channel_carriers"]
            ),
            "branch_count": self.branch_count,
            "update_count": self.update_count,
            "emit_count": self.emit_count,
            "term_count": self.term_count,
            "term_constructor_coverage": dict(sorted(self.term_tag_counts.items())),
            "static_rule_contract_raw_sha256": self.rule_contract.rules_raw_sha256,
            "static_rule_contract_canonical_sha256": self.rule_contract.rules_canonical_sha256,
            "static_checker_registry_id": static_registry.REGISTRY_ID,
            "static_rule_table_consumed": True,
            "rule_registry_parity_bound": True,
            "sort_dispatch_bound": True,
            "premise_dispatch_bound": True,
            "term_typing_dispatch_bound": True,
            "term_result_rederived": self.term_result_rederived_count == self.term_count,
            "term_provenance_rederived": self.term_provenance_rederived_count == self.term_count,
            "term_binder_registry_bound": True,
            "update_static_dispatch_bound": True,
            "body_static_dispatch_bound": True,
            "link_rule_registry_bound": True,
            "sort_rule_counts": dict(sorted(self.sort_rule_counts.items())),
            "premise_rule_counts": dict(sorted(self.premise_rule_counts.items())),
            "term_typing_rule_counts": dict(sorted(self.term_typing_rule_counts.items())),
            "update_rule_counts": dict(sorted(self.update_rule_counts.items())),
            "body_rule_counts": dict(sorted(self.body_rule_counts.items())),
            "binder_rule_counts": dict(sorted(self.binder_rule_counts.items())),
            "binder_tag_counts": dict(sorted(self.binder_tag_counts.items())),
            "binder_binding_count": self.binder_binding_count,
            "static_link_rules_consumed": sorted(self.link_rules_consumed),
            "link_materialization_rule_observations": list(
                self.linked_model_snapshot.link_rule_observations
            ),
            "static_checker_bound": False,
            "linked_model_materialized": True,
            "linked_model_independently_validated": False,
            "wire_validated_model_snapshot": self.source_snapshot.wire_validated,
            "model_artifact_id": self.linked_model_snapshot.model_artifact_id,
            "linked_semantic_projection_construction_id": (
                self.linked_model_snapshot.semantic_projection_construction_id
            ),
            "linked_model_construction_id": (
                self.linked_model_snapshot.linked_model_construction_id
            ),
            "linked_model_artifact_bytes": len(
                self.linked_model_snapshot.artifact_raw
            ),
        }

    @staticmethod
    def module_digest(module: dict[str, Any]) -> str:
        return module_content_sha256(module)

    def linked_model_object(self) -> dict[str, Any]:
        if self.linked_model_snapshot is None:
            raise RuntimeError("check() must complete before LinkedModel is available")
        return self.linked_model_snapshot.linked_model()

    def _consume_link_rule(self, key: str) -> Any:
        actual = self.rule_contract.link_rules.get(key)
        expected = static_registry.LINK_HANDLERS.get(key)
        implemented = CORE_LINK_IMPLEMENTATION_HANDLERS.get(key)
        if (
            key not in self.rule_contract.link_rules
            or key not in static_registry.LINK_HANDLERS
            or key not in CORE_LINK_IMPLEMENTATION_HANDLERS
        ):
            reject("F05-CORE-RULE-LINK-MISSING", key)
        if not _type_strict_equal(actual, expected) or not _type_strict_equal(
            actual, implemented
        ):
            reject(
                "F05-CORE-RULE-LINK-DRIFT",
                (
                    f"{key}:contract={actual!r} registry={expected!r} "
                    f"implementation={implemented!r}"
                ),
            )
        self.link_rules_consumed.add(key)
        return actual

    def _sort_rule(self, tag: str, path: str) -> str:
        rule = self.rule_contract.sort_rules.get(tag)
        if rule is None:
            reject("F05-CORE-RULE-SORT-MISSING", f"{path}:{tag}")
        self.sort_rule_counts[rule] = self.sort_rule_counts.get(rule, 0) + 1
        return rule

    def _premise_rule(self, tag: str, path: str) -> str:
        rule = self.rule_contract.premise_rules.get(tag)
        if rule is None:
            reject("F05-CORE-RULE-PREMISE-MISSING", f"{path}:{tag}")
        self.premise_rule_counts[rule] = self.premise_rule_counts.get(rule, 0) + 1
        return rule

    def _term_rule(self, tag: str, path: str) -> static_rules.TermRule:
        rule = self.rule_contract.term_rules.get(tag)
        if rule is None:
            reject("F05-CORE-RULE-TERM-MISSING", f"{path}:{tag}")
        self.term_typing_rule_counts[rule.typing_rule] = (
            self.term_typing_rule_counts.get(rule.typing_rule, 0) + 1
        )
        return rule

    def _update_rule(self, tag: str, path: str) -> tuple[str, str]:
        rule = self.rule_contract.update_rules.get(tag)
        if rule is None:
            reject("F05-CORE-RULE-UPDATE-MISSING", f"{path}:{tag}")
        self.update_rule_counts[rule[0]] = self.update_rule_counts.get(rule[0], 0) + 1
        return rule

    def _body_rule(self, body: str, path: str) -> tuple[str, str, str, str]:
        rule = self.rule_contract.body_rules.get(body)
        if rule is None:
            reject("F05-CORE-RULE-BODY-MISSING", f"{path}:{body}")
        self.body_rule_counts[body] = self.body_rule_counts.get(body, 0) + 1
        return rule

    def _require_phase_name(self, result: Typed, phase: str, path: str) -> None:
        specification = self.rule_contract.phase_rules.get(phase)
        if specification is None:
            reject("F05-CORE-RULE-PHASE-MISSING", f"{path}:{phase}")
        result_kind, allowed = specification
        if result_kind == "BOOL":
            self.require_sort(result.sort, sort_bool(), path)
        elif result_kind != "ANY":
            reject("F05-CORE-RULE-PHASE-RESULT", f"{path}:{phase}:{result_kind}")
        self.require_phase(result, allowed, path)

    @staticmethod
    def _context_fingerprint(
        environment: Mapping[str, Typed],
    ) -> tuple[tuple[str, bytes, tuple[str, ...]], ...]:
        return tuple(
            (
                variable,
                sort_key(binding.sort),
                tuple(sorted(binding.provenance)),
            )
            for variable, binding in sorted(environment.items())
        )

    def _typed_child(self, term: Any, path: str) -> Typed:
        if not isinstance(term, dict) or term.get("tag") != "TYPED_TERM":
            reject("F05-CORE-RULE-OPERAND-SHAPE", path)
        result = self.term_results.get(id(term))
        if result is None:
            reject("F05-CORE-RULE-OPERAND-NOT-TYPED", path)
        return result

    @staticmethod
    def _selector_field(selector: str, prefix: str, path: str) -> str:
        marker = f"{prefix}:"
        if not selector.startswith(marker) or selector.count(":") != 1:
            reject("F05-CORE-RULE-SELECTOR", f"{path}:{selector}")
        field = selector[len(marker) :]
        if not field:
            reject("F05-CORE-RULE-SELECTOR", f"{path}:{selector}")
        return field

    def _selector_terms(
        self,
        node: dict[str, Any],
        selector: str,
        path: str,
    ) -> list[dict[str, Any]]:
        parts = selector.split(":")
        try:
            if len(parts) == 2 and parts[0] == "FIELD":
                values = [node[parts[1]]]
            elif len(parts) == 2 and parts[0] == "EACH":
                values = list(node[parts[1]])
            elif len(parts) == 3 and parts[0] == "EACH_MEMBER":
                values = [member[parts[2]] for member in node[parts[1]]]
            else:
                reject("F05-CORE-RULE-SELECTOR", f"{path}:{selector}")
        except (KeyError, TypeError) as exc:
            reject("F05-CORE-RULE-SELECTOR-SHAPE", f"{path}:{selector}:{exc}")
        for index, value in enumerate(values):
            if not isinstance(value, dict) or value.get("tag") != "TYPED_TERM":
                reject(
                    "F05-CORE-RULE-SELECTOR-TERM",
                    f"{path}:{selector}[{index}]",
                )
        return values

    def _binder_scope_contexts(
        self,
        tag: str,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        binder_rule: str,
    ) -> dict[int, tuple[tuple[str, bytes, tuple[str, ...]], ...]]:
        if binder_rule == "NONE":
            if tag in self.rule_contract.binder_rules:
                reject("F05-CORE-RULE-BINDER-UNEXPECTED", f"{path}:{tag}")
            return {}
        specification = self.rule_contract.binder_rules.get(tag)
        if specification is None:
            reject("F05-CORE-RULE-BINDER-MISSING", f"{path}:{tag}")
        self.binder_rule_counts[binder_rule] = (
            self.binder_rule_counts.get(binder_rule, 0) + 1
        )
        self.binder_tag_counts[tag] = self.binder_tag_counts.get(tag, 0) + 1
        base_context = self._context_fingerprint(environment)
        contexts: dict[int, tuple[tuple[str, bytes, tuple[str, ...]], ...]] = {}

        def install(
            variable: Any,
            scope: Any,
            binder_sort: dict[str, Any],
            provenance: frozenset[str],
            scope_path: str,
        ) -> None:
            if not isinstance(variable, str):
                reject("F05-CORE-RULE-BINDER-VARIABLE", scope_path)
            if variable in environment:
                reject("F05-CORE-BINDER-NOT-FRESH", f"{scope_path}:{variable}")
            if not isinstance(scope, dict) or scope.get("tag") != "TYPED_TERM":
                reject("F05-CORE-RULE-BINDER-SCOPE", scope_path)
            extended = dict(environment)
            extended[variable] = Typed(binder_sort, provenance)
            scope_id = id(scope)
            if scope_id in contexts:
                reject("F05-CORE-RULE-BINDER-DUPLICATE-SCOPE", scope_path)
            contexts[scope_id] = self._context_fingerprint(extended)
            self.binder_binding_count += 1

        kind = specification["kind"]
        if kind == "SINGLE":
            variable_field = self._selector_field(
                specification["variable"], "FIELD", f"{path}.variable"
            )
            scope_field = self._selector_field(
                specification["scope"], "FIELD", f"{path}.scope"
            )
            sort_source = specification["sort_source"]
            if sort_source.startswith("TERM_RESULT:"):
                source_field = self._selector_field(
                    sort_source, "TERM_RESULT", f"{path}.sort_source"
                )
                binder_sort = self._typed_child(
                    node[source_field], f"{path}.{source_field}"
                ).sort
            elif sort_source.startswith("NODE_SORT:"):
                source_field = self._selector_field(
                    sort_source, "NODE_SORT", f"{path}.sort_source"
                )
                binder_sort = node[source_field]
            else:
                reject("F05-CORE-RULE-BINDER-SORT-SOURCE", f"{path}:{sort_source}")
            provenance_source = specification["provenance_source"]
            if provenance_source == "EMPTY":
                provenance = frozenset()
            elif provenance_source.startswith("TERM_PROVENANCE:"):
                source_field = self._selector_field(
                    provenance_source,
                    "TERM_PROVENANCE",
                    f"{path}.provenance_source",
                )
                provenance = self._typed_child(
                    node[source_field], f"{path}.{source_field}"
                ).provenance
            else:
                reject(
                    "F05-CORE-RULE-BINDER-PROVENANCE-SOURCE",
                    f"{path}:{provenance_source}",
                )
            if specification["freshness"] != "INPUT_CONTEXT":
                reject("F05-CORE-RULE-BINDER-FRESHNESS", path)
            install(
                node[variable_field],
                node[scope_field],
                binder_sort,
                provenance,
                f"{path}.{scope_field}",
            )
        elif kind == "EACH_MEMBER":
            collection_field = self._selector_field(
                specification["collection"], "FIELD", f"{path}.collection"
            )
            variable_field = self._selector_field(
                specification["variable"], "MEMBER_FIELD", f"{path}.variable"
            )
            scope_field = self._selector_field(
                specification["scope"], "MEMBER_FIELD", f"{path}.scope"
            )
            if specification["sort_source"] != (
                "DECLARED_VARIANT_PAYLOAD:variant:variant_tag"
            ):
                reject("F05-CORE-RULE-BINDER-SORT-SOURCE", path)
            provenance_field = self._selector_field(
                specification["provenance_source"],
                "TERM_PROVENANCE",
                f"{path}.provenance_source",
            )
            if specification["freshness"] != "INPUT_CONTEXT_PER_BRANCH":
                reject("F05-CORE-RULE-BINDER-FRESHNESS", path)
            declaration = self._resolve(
                node["variant"], module, "DECL_VARIANT", f"{path}.variant"
            )
            payload_sorts = {
                item["variant_tag"]: item["payload_sort"]
                for item in declaration.node["variant_tags"]
            }
            provenance = self._typed_child(
                node[provenance_field], f"{path}.{provenance_field}"
            ).provenance
            for index, member in enumerate(node[collection_field]):
                variant_tag = member["variant_tag"]
                if variant_tag not in payload_sorts:
                    reject("F05-CORE-RULE-BINDER-VARIANT-TAG", f"{path}[{index}]")
                install(
                    member[variable_field],
                    member[scope_field],
                    payload_sorts[variant_tag],
                    provenance,
                    f"{path}.{collection_field}[{index}].{scope_field}",
                )
        else:
            reject("F05-CORE-RULE-BINDER-KIND", f"{path}:{kind}")

        if base_context != self._context_fingerprint(environment):
            reject("F05-CORE-RULE-CONTEXT-MUTATED", path)
        return contexts

    def _rederive_provenance(
        self,
        tag: str,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        binder_rule: str,
    ) -> frozenset[str]:
        rule = self.rule_contract.provenance_rules.get(tag)
        if rule is None:
            reject("F05-CORE-RULE-PROVENANCE-MISSING", f"{path}:{tag}")
        scope_contexts = self._binder_scope_contexts(
            tag, node, module, environment, path, binder_rule
        )
        base_context = self._context_fingerprint(environment)
        provenance = frozenset(rule.introduced_sources)
        selected_ids: set[int] = set()
        for selector in rule.term_operands:
            for index, operand in enumerate(self._selector_terms(node, selector, path)):
                operand_id = id(operand)
                selected_ids.add(operand_id)
                actual_context = self.term_contexts.get(operand_id)
                if actual_context is None:
                    reject(
                        "F05-CORE-RULE-OPERAND-CONTEXT-MISSING",
                        f"{path}:{selector}[{index}]",
                    )
                expected_context = scope_contexts.get(operand_id, base_context)
                if actual_context != expected_context:
                    reject(
                        "F05-CORE-RULE-CONTEXT-DRIFT",
                        f"{path}:{selector}[{index}]",
                    )
                provenance |= self._typed_child(
                    operand, f"{path}:{selector}[{index}]"
                ).provenance
        if not set(scope_contexts) <= selected_ids:
            reject("F05-CORE-RULE-BINDER-SCOPE-NOT-OPERAND", path)
        for field in rule.context_variable_fields:
            variable = node[field]
            binding = environment.get(variable)
            if binding is None:
                reject("F05-CORE-UNBOUND-VARIABLE", f"{path}:{variable}")
            provenance |= binding.provenance
        self.term_provenance_rederived_count += 1
        return provenance

    def _rederive_result_sort(
        self,
        result_rule: str,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
    ) -> dict[str, Any]:
        tag = node["tag"]

        def child(field: str) -> Typed:
            return self._typed_child(node[field], f"{path}.{field}")

        if result_rule == "BOOL":
            result = sort_bool()
        elif result_rule == "ONE":
            result = sort_one()
        elif result_rule == "NAMED_ENUM":
            result = {"tag": "SORT_ENUM", "enum": node["enum"]}
        elif result_rule == "NAMED_QTY":
            result = {"tag": "SORT_QTY", "unit": node["unit"], "limit": node["limit"]}
        elif result_rule == "ARITH_RESULT_OF_NAMED_QTY":
            quantity = {"tag": "SORT_QTY", "unit": node["unit"], "limit": node["limit"]}
            result = self._resolve_arithmetic_result(quantity, module, path)
        elif result_rule == "DECLARED_CONSTANT_SORT":
            result = self._resolve(
                node["constant"], module, "DECL_CONSTANT", f"{path}.constant"
            ).node["sort"]
        elif result_rule == "CONTEXT_SORT":
            binding = environment.get(node["variable"])
            if binding is None:
                reject("F05-CORE-UNBOUND-VARIABLE", f"{path}:{node['variable']}")
            result = binding.sort
        elif result_rule == "BODY_SORT":
            result = child("body").sort
        elif result_rule == "NAMED_RECORD":
            result = {"tag": "SORT_RECORD", "record": node["record"]}
        elif result_rule == "DECLARED_FIELD_SORT":
            declaration = self._resolve(
                node["record"], module, "DECL_RECORD", f"{path}.record"
            )
            fields = {
                entry["field"]: entry["sort"] for entry in declaration.node["fields"]
            }
            if node["field"] not in fields:
                reject("F05-CORE-RECORD-FIELD", path)
            result = fields[node["field"]]
        elif result_rule == "NAMED_VARIANT":
            result = {"tag": "SORT_VARIANT", "variant": node["variant"]}
        elif result_rule == "COMMON_BRANCH_SORT":
            if tag == "TERM_MATCH_VARIANT":
                terms = [entry["body"] for entry in node["branches"]]
            elif tag == "TERM_MATCH_OPTION":
                terms = [node["none_body"], node["some_body"]]
            elif tag == "TERM_IF":
                terms = [node["then"], node["else"]]
            else:
                reject("F05-CORE-RULE-RESULT-COMMON-BRANCH", f"{path}:{tag}")
            if not terms:
                reject("F05-CORE-RULE-RESULT-EMPTY-BRANCH", path)
            sorts = [self._typed_child(term, path).sort for term in terms]
            result = sorts[0]
            for branch_sort in sorts[1:]:
                self.require_sort(branch_sort, result, path)
        elif result_rule == "OPTION_OF_DECLARED_ELEMENT":
            result = sort_option(node["element_sort"])
        elif result_rule == "FINSET_OF_DECLARED_ELEMENT":
            result = sort_finset(node["element_sort"])
        elif result_rule == "LEFT_FINSET_SORT":
            field = "set" if tag in {"TERM_SET_INSERT", "TERM_SET_REMOVE"} else "left"
            result = child(field).sort
        elif result_rule == "MAP_VALUE_SORT":
            mapping_sort = child("map").sort
            if mapping_sort.get("tag") != "SORT_TOTALMAP":
                reject("F05-CORE-MAP-SORT", f"{path}.map")
            result = mapping_sort["value"]
        elif result_rule == "MAP_SORT":
            result = child("map").sort
        elif result_rule == "ARITH_RESULT_OF_LEFT_QTY":
            result = self._resolve_arithmetic_result(child("left").sort, module, path)
        elif result_rule == "STATE_PRODUCT_VALUE_SORT":
            result = self._resolve(
                node["state_product"],
                module,
                "DECL_STATE_PRODUCT",
                f"{path}.state_product",
            ).node["value_sort"]
        elif result_rule == "OPTION_OF_EVENT_PAYLOAD":
            channel = self._resolve(
                node["event_channel"],
                module,
                "DECL_EVENT_CHANNEL",
                f"{path}.event_channel",
            )
            result = sort_option(
                {"tag": "SORT_VARIANT", "variant": channel.node["payload_variant"]}
            )
        else:
            reject("F05-CORE-RULE-RESULT-MISSING", f"{path}:{result_rule}")
        self.term_result_rederived_count += 1
        return result

    def _index_modules(self) -> None:
        for index, module in enumerate(self.model["modules"]):
            path = f"$.modules[{index}]"
            name = module["name"]
            if name in self.modules:
                reject("F05-CORE-DUPLICATE-MODULE", name)
            self.modules[name] = module
            self.module_paths[name] = path
        root = self.model["root_module"]
        if root not in self.modules:
            reject("F05-CORE-ROOT-MODULE", root)
        active = self.model["active_modules"]
        if len(set(active)) != len(active):
            reject("F05-CORE-DUPLICATE-ACTIVE-MODULE", repr(active))
        unknown = set(active) - set(self.modules)
        if unknown:
            reject("F05-CORE-UNKNOWN-ACTIVE-MODULE", repr(sorted(unknown)))
        if root not in active:
            reject("F05-CORE-INACTIVE-ROOT-MODULE", root)
        self.active_modules = frozenset(active)

    def _check_import_graph(self) -> None:
        self._consume_link_rule("dependency_modules")
        self._consume_link_rule("visibility")
        digest_domain = self._consume_link_rule("module_content_digest_domain")
        if digest_domain.encode("ascii") != MODULE_DIGEST_DOMAIN:
            reject("F05-CORE-RULE-MODULE-DIGEST-DOMAIN", digest_domain)
        graph: dict[str, list[str]] = {}
        pinned_imports: list[tuple[str, str, str]] = []
        for module_name, module in self.modules.items():
            edges: list[str] = []
            import_keys: set[bytes] = set()
            for index, imported in enumerate(module["imports"]):
                target = imported["module"]
                path = f"{self.module_paths[module_name]}.imports[{index}]"
                import_key = canonical_bytes(imported)
                if import_key in import_keys:
                    reject("F05-CORE-DUPLICATE-IMPORT", path)
                import_keys.add(import_key)
                if target not in self.modules:
                    reject("F05-CORE-UNRESOLVED-IMPORT", f"{path}:{target}")
                edges.append(target)
                pinned_imports.append((path, target, imported["artifact_sha256"]))
            graph[module_name] = edges

        colors: dict[str, int] = {}
        for start in self.modules:
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
                    path = [entry[0] for entry in stack]
                    cycle_start = path.index(target)
                    reject(
                        "F05-CORE-IMPORT-CYCLE",
                        " -> ".join(path[cycle_start:] + [target]),
                    )
                if color == 0:
                    colors[target] = 1
                    stack.append((target, 0))

        for path, target, declared_digest in pinned_imports:
            actual = self.module_digests.get(target)
            if actual is None:
                actual = module_content_sha256(self.modules[target])
                self.module_digests[target] = actual
            if declared_digest != actual:
                reject(
                    "F05-CORE-IMPORT-DIGEST",
                    f"{path}:declared={declared_digest} actual={actual}",
                )

        for module_name in self.modules:
            self.visibility[module_name] = frozenset({module_name, *graph[module_name]})

        reachable: set[str] = set()
        pending = [self.model["root_module"]]
        while pending:
            module_name = pending.pop()
            if module_name in reachable:
                continue
            reachable.add(module_name)
            pending.extend(graph[module_name])
        if reachable != frozenset(self.modules):
            reject(
                "F05-CORE-UNREACHABLE-MODULE",
                str(sorted(set(self.modules) - set(reachable))),
            )

    def _index_declarations(self) -> None:
        self._consume_link_rule("signature")
        self._consume_link_rule("carrier_declarations")
        for module_name, module in self.modules.items():
            module_path = self.module_paths[module_name]
            unnamed_declarations: set[bytes] = set()
            for index, declaration in enumerate(module["declarations"]):
                path = f"{module_path}.declarations[{index}]"
                tag = declaration["tag"]
                if tag in NAMED_DECLARATIONS:
                    name = qname(declaration["name"], f"{path}.name")
                    if name[0] != module_name:
                        reject(
                            "F05-CORE-DECLARATION-MODULE",
                            f"{path}:{name[0]} != {module_name}",
                        )
                    if name in self.declarations:
                        reject("F05-CORE-DUPLICATE-DECLARATION", repr(name))
                    self.declarations[name] = DeclarationInfo(tag, declaration, module_name, path)
                elif tag == "DECL_CONSTANT_CONSTRAINT":
                    unnamed_key = canonical_bytes(declaration)
                    if unnamed_key in unnamed_declarations:
                        reject("F05-CORE-DUPLICATE-UNNAMED-DECLARATION", path)
                    unnamed_declarations.add(unnamed_key)
                    self.constraints.append((module_name, declaration, path))
                elif tag == "DECL_ARITH_RESULT_BINDING":
                    unnamed_key = canonical_bytes(declaration)
                    if unnamed_key in unnamed_declarations:
                        reject("F05-CORE-DUPLICATE-UNNAMED-DECLARATION", path)
                    unnamed_declarations.add(unnamed_key)
                    self.arith_declarations.append((module_name, declaration, path))
                else:
                    reject("F05-CORE-DECLARATION-TAG", f"{path}:{tag}")
        for module_name in self.modules:
            self.owned_event_channels[module_name] = {
                name: info
                for name, info in self.declarations.items()
                if info.tag == "DECL_EVENT_CHANNEL"
                and info.module == module_name
            }

    def _resolve(
        self,
        raw_name: Any,
        module: str,
        expected: str | set[str],
        path: str,
    ) -> DeclarationInfo:
        name = qname(raw_name, path)
        if name[0] not in self.visibility[module]:
            reject("F05-CORE-INVISIBLE-NAME", f"{path}:{name} from {module}")
        declaration = self.declarations.get(name)
        if declaration is None:
            reject("F05-CORE-UNRESOLVED-NAME", f"{path}:{name}")
        expected_tags = {expected} if isinstance(expected, str) else expected
        if declaration.tag not in expected_tags:
            reject(
                "F05-CORE-NAMESPACE-MISMATCH",
                f"{path}:{name}:{declaration.tag} expected={sorted(expected_tags)}",
            )
        return declaration

    def _check_type_and_resource_declarations(self) -> None:
        for name, declaration in self.declarations.items():
            if declaration.tag == "DECL_RECORD":
                fields = declaration.node["fields"]
                field_names = [entry["field"] for entry in fields]
                if len(set(field_names)) != len(field_names):
                    reject("F05-CORE-DUPLICATE-RECORD-FIELD", declaration.path)
                for index, field in enumerate(fields):
                    self.check_sort(
                        field["sort"],
                        declaration.module,
                        f"{declaration.path}.fields[{index}].sort",
                    )
            elif declaration.tag == "DECL_VARIANT":
                variants = declaration.node["variant_tags"]
                tag_names = [entry["variant_tag"] for entry in variants]
                if len(set(tag_names)) != len(tag_names):
                    reject("F05-CORE-DUPLICATE-VARIANT-TAG", declaration.path)
                for index, variant in enumerate(variants):
                    self.check_sort(
                        variant["payload_sort"],
                        declaration.module,
                        f"{declaration.path}.variant_tags[{index}].payload_sort",
                    )
            elif declaration.tag == "DECL_ENUM":
                if len(set(declaration.node["members"])) != len(declaration.node["members"]):
                    reject("F05-CORE-DUPLICATE-ENUM-MEMBER", declaration.path)
            elif declaration.tag == "DECL_CONSTANT":
                self.check_sort(declaration.node["sort"], declaration.module, f"{declaration.path}.sort")
            elif declaration.tag == "DECL_STATE_PRODUCT":
                key_sort = declaration.node["key_sort"]
                value_sort = declaration.node["value_sort"]
                self.check_sort(key_sort, declaration.module, f"{declaration.path}.key_sort")
                self.check_sort(value_sort, declaration.module, f"{declaration.path}.value_sort")
            elif declaration.tag == "DECL_EVENT_CHANNEL":
                self._resolve(
                    declaration.node["payload_variant"],
                    declaration.module,
                    "DECL_VARIANT",
                    f"{declaration.path}.payload_variant",
                )
            elif declaration.tag in {
                "DECL_ATOM",
                "DECL_UNIT",
                "DECL_LIMIT",
                "DECL_ACTION",
                "DECL_PREMISE",
                "DECL_CLAIM_BASE_ALWAYS",
            }:
                pass
            else:
                reject("F05-CORE-DECLARATION-PASS", declaration.path)

        self._check_named_type_graph()
        for declaration in self.declarations.values():
            if declaration.tag != "DECL_STATE_PRODUCT":
                continue
            if not self.is_key_or_cell_sort(declaration.node["key_sort"], declaration.module):
                reject("F05-CORE-KEYSORT", declaration.path)
            if not self.is_key_or_cell_sort(declaration.node["value_sort"], declaration.module):
                reject("F05-CORE-CELLSORT", declaration.path)

    @staticmethod
    def _named_member_sorts(declaration: DeclarationInfo) -> list[dict[str, Any]]:
        if declaration.tag == "DECL_RECORD":
            return [field["sort"] for field in declaration.node["fields"]]
        if declaration.tag == "DECL_VARIANT":
            return [variant["payload_sort"] for variant in declaration.node["variant_tags"]]
        raise RuntimeError(f"not a named type: {declaration.tag}")

    def _named_dependencies(
        self,
        sort: dict[str, Any],
        module: str,
        path: str,
    ) -> set[tuple[str, str]]:
        dependencies: set[tuple[str, str]] = set()
        pending = [(sort, path)]
        while pending:
            current, current_path = pending.pop()
            tag = current["tag"]
            if tag == "SORT_RECORD":
                declaration = self._resolve(
                    current["record"], module, "DECL_RECORD", f"{current_path}.record"
                )
                dependencies.add(qname(declaration.node["name"], declaration.path))
            elif tag == "SORT_VARIANT":
                declaration = self._resolve(
                    current["variant"], module, "DECL_VARIANT", f"{current_path}.variant"
                )
                dependencies.add(qname(declaration.node["name"], declaration.path))
            elif tag in {"SORT_OPTION", "SORT_FINSET"}:
                pending.append((current["element"], f"{current_path}.element"))
            elif tag == "SORT_TOTALMAP":
                pending.append((current["value"], f"{current_path}.value"))
                pending.append((current["key"], f"{current_path}.key"))
        return dependencies

    def _check_named_type_graph(self) -> None:
        named = {
            name: declaration
            for name, declaration in self.declarations.items()
            if declaration.tag in {"DECL_RECORD", "DECL_VARIANT"}
        }
        graph: dict[tuple[str, str], set[tuple[str, str]]] = {}
        for name, declaration in named.items():
            dependencies: set[tuple[str, str]] = set()
            for index, member_sort in enumerate(self._named_member_sorts(declaration)):
                dependencies.update(
                    self._named_dependencies(
                        member_sort,
                        declaration.module,
                        f"{declaration.path}.members[{index}]",
                    )
                )
            graph[name] = dependencies

        colors: dict[tuple[str, str], int] = {}
        dependency_first: list[tuple[str, str]] = []
        for start in graph:
            if colors.get(start, 0) == 2:
                continue
            colors[start] = 1
            stack: list[tuple[tuple[str, str], int, list[tuple[str, str]]]] = [
                (start, 0, sorted(graph[start]))
            ]
            while stack:
                name, edge_index, edges = stack[-1]
                if edge_index == len(edges):
                    colors[name] = 2
                    dependency_first.append(name)
                    stack.pop()
                    continue
                target = edges[edge_index]
                stack[-1] = (name, edge_index + 1, edges)
                color = colors.get(target, 0)
                if color == 1:
                    path = [entry[0] for entry in stack]
                    cycle_start = path.index(target)
                    reject(
                        "F05-CORE-SORT-CYCLE",
                        " -> ".join(repr(item) for item in path[cycle_start:] + [target]),
                    )
                if color == 0:
                    colors[target] = 1
                    stack.append((target, 0, sorted(graph[target])))

        for name in dependency_first:
            declaration = named[name]
            self.named_type_cell_sort[name] = all(
                self._structural_cell_sort(member_sort)
                for member_sort in self._named_member_sorts(declaration)
            )

    def check_sort(
        self,
        sort: dict[str, Any],
        module: str,
        path: str,
        depth: int = 0,
    ) -> None:
        if depth > MAX_TERM_DEPTH:
            raise VerificationInconclusive("F05-CORE-RESOURCE-SORT-DEPTH", path)
        tag = sort["tag"]
        rule = self._sort_rule(tag, path)
        if rule in {"SORT_BASE_BOOL", "SORT_BASE_ONE"}:
            return
        if rule == "SORT_RESOLVE_ATOM":
            self._resolve(sort["atom"], module, "DECL_ATOM", f"{path}.atom")
            return
        if rule == "SORT_RESOLVE_ENUM":
            self._resolve(sort["enum"], module, "DECL_ENUM", f"{path}.enum")
            return
        if rule == "SORT_RESOLVE_UNIT_LIMIT":
            self._resolve(sort["unit"], module, "DECL_UNIT", f"{path}.unit")
            self._resolve(sort["limit"], module, "DECL_LIMIT", f"{path}.limit")
            return
        if rule == "SORT_RESOLVE_ACYCLIC_RECORD":
            self._resolve(sort["record"], module, "DECL_RECORD", f"{path}.record")
            return
        if rule == "SORT_RESOLVE_ACYCLIC_VARIANT":
            self._resolve(sort["variant"], module, "DECL_VARIANT", f"{path}.variant")
            return
        if rule in {"SORT_RECURSIVE_OPTION", "SORT_RECURSIVE_FINSET"}:
            self.check_sort(sort["element"], module, f"{path}.element", depth + 1)
            return
        if rule == "SORT_RECURSIVE_TOTALMAP":
            self.check_sort(sort["key"], module, f"{path}.key", depth + 1)
            self.check_sort(sort["value"], module, f"{path}.value", depth + 1)
            return
        reject("F05-CORE-RULE-SORT-DISPATCH", f"{path}:{tag}:{rule}")

    def _structural_cell_sort(self, sort: dict[str, Any], depth: int = 0) -> bool:
        if depth > MAX_TERM_DEPTH:
            raise VerificationInconclusive(
                "F05-CORE-RESOURCE-CELL-SORT-DEPTH", str(depth)
            )
        tag = sort["tag"]
        if tag in {"SORT_BOOL", "SORT_ONE", "SORT_ATOM", "SORT_ENUM", "SORT_QTY"}:
            return True
        if tag == "SORT_OPTION":
            return self._structural_cell_sort(sort["element"], depth + 1)
        if tag == "SORT_RECORD":
            return self.named_type_cell_sort[qname(sort["record"], "CellSort.record")]
        if tag == "SORT_VARIANT":
            return self.named_type_cell_sort[qname(sort["variant"], "CellSort.variant")]
        return False

    def is_key_or_cell_sort(self, sort: dict[str, Any], module: str) -> bool:
        self.check_sort(sort, module, "KeyCellSort")
        return self._structural_cell_sort(sort)

    def _check_arithmetic_bindings(self) -> None:
        for module, declaration, path in self.arith_declarations:
            quantity_sort = declaration["quantity_sort"]
            self.check_sort(quantity_sort, module, f"{path}.quantity_sort")
            if quantity_sort["tag"] != "SORT_QTY":
                reject("F05-CORE-ARITH-NON-QTY", path)
            key = sort_key(quantity_sort)
            if key in self.arith_results:
                reject("F05-CORE-DUPLICATE-ARITH-BINDING", path)
            variant = self._resolve(
                declaration["result_variant"],
                module,
                "DECL_VARIANT",
                f"{path}.result_variant",
            )
            tags = {
                item["variant_tag"]: item["payload_sort"]
                for item in variant.node["variant_tags"]
            }
            if set(tags) != {"Ok", "Overflow", "Underflow"}:
                reject("F05-CORE-ARITH-VARIANT-TAGS", path)
            if tags["Ok"] != quantity_sort or tags["Overflow"] != sort_one() or tags["Underflow"] != sort_one():
                reject("F05-CORE-ARITH-VARIANT-PAYLOAD", path)
            self.arith_results[key] = ArithmeticBinding(
                result_sort={
                    "tag": "SORT_VARIANT",
                    "variant": variant.node["name"],
                },
                module=module,
                path=path,
            )

    def _resolve_arithmetic_result(
        self,
        quantity_sort: dict[str, Any],
        module: str,
        path: str,
    ) -> dict[str, Any]:
        binding = self.arith_results.get(sort_key(quantity_sort))
        if binding is None:
            reject("F05-CORE-MISSING-ARITH-BINDING", path)
        if binding.module not in self.visibility[module]:
            reject(
                "F05-CORE-INVISIBLE-ARITH-BINDING",
                f"{path}:binding={binding.path} from={module}",
            )
        return binding.result_sort

    def _check_constraints_premises_actions_claims_and_init(self) -> None:
        self._consume_link_rule("constant_constraints")
        self._consume_link_rule("embedded_body_static_validation")
        for module, declaration, path in self.constraints:
            context, phase, _, _ = self._body_rule("CONSTANT_CONSTRAINT", path)
            if context != "INTERPRETATION_ONLY" or phase != "STATIC_CONSTRAINT":
                reject("F05-CORE-RULE-BODY-DISPATCH", f"{path}:CONSTANT_CONSTRAINT")
            constraint = declaration["constraint"]
            left = self._resolve(
                constraint["left"], module, "DECL_CONSTANT", f"{path}.constraint.left"
            )
            right = self._resolve(
                constraint["right"], module, "DECL_CONSTANT", f"{path}.constraint.right"
            )
            if left.node["sort"] != right.node["sort"]:
                reject("F05-CORE-CONSTANT-CONSTRAINT-SORT", path)

        for declaration in self.declarations.values():
            if declaration.tag == "DECL_PREMISE":
                context, phase, _, _ = self._body_rule(
                    "CLASS_PREMISE", declaration.path
                )
                if context != "INTERPRETATION_ONLY" or phase != "INTERPRETATION_PREMISE":
                    reject("F05-CORE-RULE-BODY-DISPATCH", declaration.path)
                self.check_premise(
                    declaration.node["body"],
                    declaration.module,
                    f"{declaration.path}.body",
                )
            elif declaration.tag == "DECL_ACTION":
                self.check_action(declaration)
            elif declaration.tag == "DECL_CLAIM_BASE_ALWAYS":
                context, phase, _, _ = self._body_rule("BASE_CLAIM", declaration.path)
                if context != "EMPTY":
                    reject("F05-CORE-RULE-BODY-CONTEXT", declaration.path)
                result = self.type_term(
                    declaration.node["invariant"],
                    declaration.module,
                    {},
                    f"{declaration.path}.invariant",
                )
                self._require_phase_name(result, phase, declaration.path)

        for module_name, module in self.modules.items():
            path = f"{self.module_paths[module_name]}.init_contribution"
            context, phase, _, _ = self._body_rule("MODULE_INIT", path)
            if context != "EMPTY":
                reject("F05-CORE-RULE-BODY-CONTEXT", path)
            result = self.type_term(module["init_contribution"], module_name, {}, path)
            self._require_phase_name(result, phase, path)

    def check_premise(self, premise: dict[str, Any], module: str, path: str) -> None:
        pending = [(premise, path)]
        while pending:
            current, current_path = pending.pop()
            tag = current["tag"]
            rule = self._premise_rule(tag, current_path)
            if rule in {
                "PREMISE_SAME_SORT_CONSTANT_EQ",
                "PREMISE_SAME_SORT_CONSTANT_NEQ",
            }:
                left = self._resolve(
                    current["left"], module, "DECL_CONSTANT", f"{current_path}.left"
                )
                right = self._resolve(
                    current["right"], module, "DECL_CONSTANT", f"{current_path}.right"
                )
                if left.node["sort"] != right.node["sort"]:
                    reject("F05-CORE-PREMISE-CONSTANT-SORT", current_path)
            elif rule in {
                "PREMISE_NAT_LIMIT_EQ",
                "PREMISE_NAT_LIMIT_LE",
                "PREMISE_NAT_LIMIT_LT",
            }:
                self._resolve(current["left"], module, "DECL_LIMIT", f"{current_path}.left")
                self._resolve(current["right"], module, "DECL_LIMIT", f"{current_path}.right")
            elif rule == "PREMISE_LIMIT_GE_LITERAL_NAT":
                self._resolve(current["limit"], module, "DECL_LIMIT", f"{current_path}.limit")
            elif rule in {
                "PREMISE_ATOM_CARDINALITY_EQ",
                "PREMISE_ATOM_CARDINALITY_GE",
            }:
                self._resolve(current["atom"], module, "DECL_ATOM", f"{current_path}.atom")
            elif rule == "PREMISE_BOOLEAN_NOT":
                pending.append((current["operand"], f"{current_path}.operand"))
            elif rule in {"PREMISE_BOOLEAN_AND_STRICT", "PREMISE_BOOLEAN_OR_STRICT"}:
                for index in reversed(range(len(current["operands"]))):
                    pending.append(
                        (current["operands"][index], f"{current_path}.operands[{index}]")
                    )
            else:
                reject(
                    "F05-CORE-RULE-PREMISE-DISPATCH",
                    f"{current_path}:{tag}:{rule}",
                )

    def check_action(self, declaration: DeclarationInfo) -> None:
        action = declaration.node
        parameter = action["parameter_variable"]
        parameter_sort = action["parameter_sort"]
        self.check_sort(parameter_sort, declaration.module, f"{declaration.path}.parameter_sort")
        invoke_context, invoke_phase, _, _ = self._body_rule(
            "ACTION_INVOKE", f"{declaration.path}.invoke"
        )
        if invoke_context != "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE":
            reject("F05-CORE-RULE-BODY-CONTEXT", f"{declaration.path}.invoke")
        environment = {parameter: Typed(parameter_sort, frozenset({PARAM}))}
        invoke = self.type_term(
            action["invoke"],
            declaration.module,
            environment,
            f"{declaration.path}.invoke",
        )
        self._require_phase_name(invoke, invoke_phase, f"{declaration.path}.invoke")
        self.action_count += 1

        event_channels = self.owned_event_channels[declaration.module]
        branch_names = [branch["branch"] for branch in action["branches"]]
        if len(set(branch_names)) != len(branch_names):
            reject("F05-CORE-DUPLICATE-ACTION-BRANCH", declaration.path)
        for branch_index, branch in enumerate(action["branches"]):
            branch_path = f"{declaration.path}.branches[{branch_index}]"
            guard_context, guard_phase, _, _ = self._body_rule(
                "ACTION_GUARD", f"{branch_path}.guard"
            )
            if guard_context != "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE":
                reject("F05-CORE-RULE-BODY-CONTEXT", f"{branch_path}.guard")
            guard = self.type_term(
                branch["guard"], declaration.module, environment, f"{branch_path}.guard"
            )
            self._require_phase_name(guard, guard_phase, f"{branch_path}.guard")
            self.branch_count += 1

            for update_index, update in enumerate(branch["updates"]):
                update_context, update_phase, _, _ = self._body_rule(
                    "ACTION_UPDATE", f"{branch_path}.updates[{update_index}]"
                )
                if update_context != "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE":
                    reject(
                        "F05-CORE-RULE-BODY-CONTEXT",
                        f"{branch_path}.updates[{update_index}]",
                    )
                self.check_update(
                    update,
                    declaration.module,
                    environment,
                    f"{branch_path}.updates[{update_index}]",
                    update_phase,
                )
                self.update_count += 1

            emits = {
                qname(item["event_channel"], f"{branch_path}.emits.event_channel"): item
                for item in branch["emits"]
            }
            if len(emits) != len(branch["emits"]):
                reject("F05-CORE-DUPLICATE-CHANNEL-EMIT", branch_path)
            if set(emits) != set(event_channels):
                reject(
                    "F05-CORE-EMIT-CHANNEL-COVERAGE",
                    f"{branch_path}:missing={sorted(set(event_channels)-set(emits))} extra={sorted(set(emits)-set(event_channels))}",
                )
            for channel_name, emit in emits.items():
                emit_context, emit_phase, _, _ = self._body_rule(
                    "ACTION_EMIT", f"{branch_path}.emits[{channel_name}]"
                )
                if emit_context != "EXACT_SINGLE_PARAMETER_WITH_PARAM_SOURCE":
                    reject(
                        "F05-CORE-RULE-BODY-CONTEXT",
                        f"{branch_path}.emits[{channel_name}]",
                    )
                channel = self._resolve(
                    emit["event_channel"],
                    declaration.module,
                    "DECL_EVENT_CHANNEL",
                    f"{branch_path}.emits.event_channel",
                )
                payload_sort = {
                    "tag": "SORT_VARIANT",
                    "variant": channel.node["payload_variant"],
                }
                emitted = self.type_term(
                    emit["value"],
                    declaration.module,
                    environment,
                    f"{branch_path}.emits[{channel_name}].value",
                )
                self.require_sort(
                    emitted.sort,
                    sort_option(payload_sort),
                    f"{branch_path}.emits[{channel_name}]",
                )
                self._require_phase_name(
                    emitted, emit_phase, f"{branch_path}.emits[{channel_name}]"
                )
                self.emit_count += 1

    def check_update(
        self,
        update: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        body_phase: str,
    ) -> None:
        state_product = self._resolve(
            update["state_product"], module, "DECL_STATE_PRODUCT", f"{path}.state_product"
        )
        key_sort = state_product.node["key_sort"]
        value_sort = state_product.node["value_sort"]
        rule, source_phase = self._update_rule(update["tag"], path)
        if source_phase != body_phase:
            reject(
                "F05-CORE-RULE-UPDATE-PHASE-DRIFT",
                f"{path}:update={source_phase} body={body_phase}",
            )
        if rule == "STATIC_TYPED_POINT_WRITE_PRE_EVALUABLE":
            key = self.type_term(update["key"], module, environment, f"{path}.key")
            value = self.type_term(update["value"], module, environment, f"{path}.value")
            self.require_sort(key.sort, key_sort, f"{path}.key")
            self.require_sort(value.sort, value_sort, f"{path}.value")
            self._require_phase_name(key, source_phase, f"{path}.key")
            self._require_phase_name(value, source_phase, f"{path}.value")
            return
        if rule == "STATIC_TYPED_FINITE_PATCH_PRE_EVALUABLE":
            domain = self.type_term(update["domain"], module, environment, f"{path}.domain")
            values = self.type_term(update["values"], module, environment, f"{path}.values")
            self.require_sort(domain.sort, sort_finset(key_sort), f"{path}.domain")
            self.require_sort(values.sort, sort_totalmap(key_sort, value_sort), f"{path}.values")
            self._require_phase_name(domain, source_phase, f"{path}.domain")
            self._require_phase_name(values, source_phase, f"{path}.values")
            return
        reject(
            "F05-CORE-RULE-UPDATE-DISPATCH",
            f"{path}:{update['tag']}:{rule}",
        )

    def type_term(
        self,
        term: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        depth: int = 0,
    ) -> Typed:
        if depth > MAX_TERM_DEPTH:
            raise VerificationInconclusive("F05-CORE-RESOURCE-TERM-DEPTH", path)
        self.term_count += 1
        if self.term_count > MAX_TERM_NODES:
            raise VerificationInconclusive(
                "F05-CORE-RESOURCE-TERM-COUNT", str(self.term_count)
            )
        annotated = term["result_sort"]
        self.check_sort(annotated, module, f"{path}.result_sort")
        node = term["node"]
        tag = node["tag"]
        rule = self._term_rule(tag, path)
        term_id = id(term)
        if term_id in self.term_contexts or term_id in self.term_results:
            reject("F05-CORE-RULE-TERM-REUSED", path)
        self.term_objects[term_id] = term
        self.term_contexts[term_id] = self._context_fingerprint(environment)
        self.term_tag_counts[tag] = self.term_tag_counts.get(tag, 0) + 1
        derived = self._type_node(
            node,
            module,
            environment,
            f"{path}.node",
            depth + 1,
            rule,
        )
        rederived_sort = self._rederive_result_sort(
            rule.result_rule,
            node,
            module,
            environment,
            f"{path}.node",
        )
        if not _type_strict_equal(derived.sort, rederived_sort):
            reject(
                "F05-CORE-RULE-RESULT-DRIFT",
                f"{path}:handler={derived.sort!r} rule={rederived_sort!r}",
            )
        rederived_provenance = self._rederive_provenance(
            tag,
            node,
            module,
            environment,
            f"{path}.node",
            rule.binder_rule,
        )
        if not _type_strict_equal(derived.provenance, rederived_provenance):
            reject(
                "F05-CORE-RULE-PROVENANCE-DRIFT",
                f"{path}:handler={sorted(derived.provenance)} rule={sorted(rederived_provenance)}",
            )
        if annotated != derived.sort:
            reject(
                "F05-CORE-TERM-ANNOTATION",
                f"{path}:annotated={annotated} derived={derived.sort}",
            )
        self.term_results[term_id] = derived
        return derived

    def _type_node(
        self,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        depth: int,
        term_rule: static_rules.TermRule,
    ) -> Typed:
        tag = node["tag"]
        rule = term_rule.typing_rule
        empty = frozenset()
        if rule == "TYPE_BOOL_LITERAL":
            return Typed(sort_bool(), empty)
        if rule == "TYPE_ONE_LITERAL":
            return Typed(sort_one(), empty)
        if rule == "TYPE_ENUM_MEMBER":
            declaration = self._resolve(node["enum"], module, "DECL_ENUM", f"{path}.enum")
            if node["member"] not in declaration.node["members"]:
                reject("F05-CORE-ENUM-MEMBER", path)
            return Typed({"tag": "SORT_ENUM", "enum": node["enum"]}, empty)
        if rule in {"TYPE_QTY_ZERO", "TYPE_QTY_CHECKED"}:
            self._resolve(node["unit"], module, "DECL_UNIT", f"{path}.unit")
            self._resolve(node["limit"], module, "DECL_LIMIT", f"{path}.limit")
            quantity_sort = {
                "tag": "SORT_QTY",
                "unit": node["unit"],
                "limit": node["limit"],
            }
            if rule == "TYPE_QTY_ZERO":
                return Typed(quantity_sort, empty)
            return Typed(
                self._resolve_arithmetic_result(quantity_sort, module, path),
                empty,
            )
        if rule == "TYPE_CONSTANT_REFERENCE":
            declaration = self._resolve(
                node["constant"], module, "DECL_CONSTANT", f"{path}.constant"
            )
            return Typed(declaration.node["sort"], empty)
        if rule == "TYPE_VARIABLE_LOOKUP":
            variable = node["variable"]
            if variable not in environment:
                reject("F05-CORE-UNBOUND-VARIABLE", f"{path}:{variable}")
            return environment[variable]
        if rule == "TYPE_LET":
            variable = node["variable"]
            self.require_fresh(variable, environment, path)
            bound = self.type_term(node["bound"], module, environment, f"{path}.bound", depth)
            extended = dict(environment)
            extended[variable] = bound
            body = self.type_term(node["body"], module, extended, f"{path}.body", depth)
            return Typed(body.sort, bound.provenance | body.provenance)
        if rule == "TYPE_RECORD_CONSTRUCTION":
            declaration = self._resolve(node["record"], module, "DECL_RECORD", f"{path}.record")
            expected = {field["field"]: field["sort"] for field in declaration.node["fields"]}
            actual = {entry["field"]: entry for entry in node["values"]}
            if set(actual) != set(expected):
                reject("F05-CORE-RECORD-FIELDS", path)
            provenance = empty
            for field_name, field_sort in expected.items():
                result = self.type_term(
                    actual[field_name]["value"],
                    module,
                    environment,
                    f"{path}.values[{field_name}]",
                    depth,
                )
                self.require_sort(result.sort, field_sort, f"{path}.values[{field_name}]")
                provenance |= result.provenance
            return Typed({"tag": "SORT_RECORD", "record": node["record"]}, provenance)
        if rule == "TYPE_RECORD_PROJECTION":
            record = self._resolve(node["record"], module, "DECL_RECORD", f"{path}.record")
            record_term = self.type_term(
                node["record_term"], module, environment, f"{path}.record_term", depth
            )
            self.require_sort(
                record_term.sort,
                {"tag": "SORT_RECORD", "record": node["record"]},
                path,
            )
            fields = {entry["field"]: entry["sort"] for entry in record.node["fields"]}
            if node["field"] not in fields:
                reject("F05-CORE-RECORD-FIELD", path)
            return Typed(fields[node["field"]], record_term.provenance)
        if rule == "TYPE_VARIANT_INJECTION":
            declaration = self._resolve(node["variant"], module, "DECL_VARIANT", f"{path}.variant")
            variants = {
                entry["variant_tag"]: entry["payload_sort"]
                for entry in declaration.node["variant_tags"]
            }
            if node["variant_tag"] not in variants:
                reject("F05-CORE-VARIANT-TAG", path)
            payload = self.type_term(node["payload"], module, environment, f"{path}.payload", depth)
            self.require_sort(payload.sort, variants[node["variant_tag"]], f"{path}.payload")
            return Typed({"tag": "SORT_VARIANT", "variant": node["variant"]}, payload.provenance)
        if rule == "TYPE_EXHAUSTIVE_VARIANT_MATCH":
            return self._type_match_variant(node, module, environment, path, depth)
        if rule == "TYPE_OPTION_NONE":
            self.check_sort(node["element_sort"], module, f"{path}.element_sort")
            return Typed(sort_option(node["element_sort"]), empty)
        if rule == "TYPE_OPTION_SOME":
            self.check_sort(node["element_sort"], module, f"{path}.element_sort")
            value = self.type_term(node["value"], module, environment, f"{path}.value", depth)
            self.require_sort(value.sort, node["element_sort"], f"{path}.value")
            return Typed(sort_option(node["element_sort"]), value.provenance)
        if rule == "TYPE_EXHAUSTIVE_OPTION_MATCH":
            return self._type_match_option(node, module, environment, path, depth)
        if rule == "TYPE_FINSET_EMPTY":
            self.check_sort(node["element_sort"], module, f"{path}.element_sort")
            return Typed(sort_finset(node["element_sort"]), empty)
        if rule in {"TYPE_FINSET_INSERT", "TYPE_FINSET_REMOVE"}:
            set_value = self.type_term(node["set"], module, environment, f"{path}.set", depth)
            if set_value.sort["tag"] != "SORT_FINSET":
                reject("F05-CORE-SET-SORT", f"{path}.set")
            element = self.type_term(node["element"], module, environment, f"{path}.element", depth)
            self.require_sort(element.sort, set_value.sort["element"], f"{path}.element")
            return Typed(set_value.sort, set_value.provenance | element.provenance)
        if rule == "TYPE_FINSET_MEMBER":
            set_value = self.type_term(node["set"], module, environment, f"{path}.set", depth)
            if set_value.sort["tag"] != "SORT_FINSET":
                reject("F05-CORE-SET-SORT", f"{path}.set")
            element = self.type_term(node["element"], module, environment, f"{path}.element", depth)
            self.require_sort(element.sort, set_value.sort["element"], f"{path}.element")
            return Typed(sort_bool(), set_value.provenance | element.provenance)
        if rule in {
            "TYPE_SAME_FINSET_SUBSET",
            "TYPE_SAME_FINSET_UNION",
            "TYPE_SAME_FINSET_DIFFERENCE",
        }:
            left, right = self.binary_terms(node, module, environment, path, depth)
            if left.sort["tag"] != "SORT_FINSET" or left.sort != right.sort:
                reject("F05-CORE-SET-BINARY-SORT", path)
            result_sort = (
                sort_bool() if rule == "TYPE_SAME_FINSET_SUBSET" else left.sort
            )
            return Typed(result_sort, left.provenance | right.provenance)
        if rule == "TYPE_TOTALMAP_GET":
            mapping = self.type_term(node["map"], module, environment, f"{path}.map", depth)
            if mapping.sort["tag"] != "SORT_TOTALMAP":
                reject("F05-CORE-MAP-SORT", f"{path}.map")
            key = self.type_term(node["key"], module, environment, f"{path}.key", depth)
            self.require_sort(key.sort, mapping.sort["key"], f"{path}.key")
            return Typed(mapping.sort["value"], mapping.provenance | key.provenance)
        if rule == "TYPE_TOTALMAP_SET":
            mapping = self.type_term(node["map"], module, environment, f"{path}.map", depth)
            if mapping.sort["tag"] != "SORT_TOTALMAP":
                reject("F05-CORE-MAP-SORT", f"{path}.map")
            key = self.type_term(node["key"], module, environment, f"{path}.key", depth)
            value = self.type_term(node["value"], module, environment, f"{path}.value", depth)
            self.require_sort(key.sort, mapping.sort["key"], f"{path}.key")
            self.require_sort(value.sort, mapping.sort["value"], f"{path}.value")
            return Typed(
                mapping.sort,
                mapping.provenance | key.provenance | value.provenance,
            )
        if rule in {"TYPE_BOOL_AND_STRICT", "TYPE_BOOL_OR_STRICT"}:
            provenance = empty
            for index, operand in enumerate(node["operands"]):
                result = self.type_term(
                    operand, module, environment, f"{path}.operands[{index}]", depth
                )
                self.require_sort(result.sort, sort_bool(), f"{path}.operands[{index}]")
                provenance |= result.provenance
            return Typed(sort_bool(), provenance)
        if rule == "TYPE_BOOL_NOT":
            operand = self.type_term(node["operand"], module, environment, f"{path}.operand", depth)
            self.require_sort(operand.sort, sort_bool(), f"{path}.operand")
            return Typed(sort_bool(), operand.provenance)
        if rule in {"TYPE_BOOL_IMPLIES_STRICT", "TYPE_BOOL_IFF_STRICT"}:
            left, right = self.binary_terms(node, module, environment, path, depth)
            self.require_sort(left.sort, sort_bool(), f"{path}.left")
            self.require_sort(right.sort, sort_bool(), f"{path}.right")
            return Typed(sort_bool(), left.provenance | right.provenance)
        if rule == "TYPE_SAME_SORT_EQUALITY":
            left, right = self.binary_terms(node, module, environment, path, depth)
            self.require_sort(left.sort, right.sort, path)
            return Typed(sort_bool(), left.provenance | right.provenance)
        if rule in {
            "TYPE_SAME_QTY_LT",
            "TYPE_SAME_QTY_LE",
            "TYPE_SAME_QTY_GT",
            "TYPE_SAME_QTY_GE",
        }:
            left, right = self.binary_terms(node, module, environment, path, depth)
            if left.sort["tag"] != "SORT_QTY" or left.sort != right.sort:
                reject("F05-CORE-QTY-COMPARISON-SORT", path)
            return Typed(sort_bool(), left.provenance | right.provenance)
        if rule in {"TYPE_CHECKED_QTY_ADD", "TYPE_CHECKED_QTY_SUB"}:
            left, right = self.binary_terms(node, module, environment, path, depth)
            if left.sort["tag"] != "SORT_QTY" or left.sort != right.sort:
                reject("F05-CORE-QTY-ARITH-SORT", path)
            return Typed(
                self._resolve_arithmetic_result(left.sort, module, path),
                left.provenance | right.provenance,
            )
        if rule == "TYPE_BOOL_IF_COMMON_BRANCH":
            condition = self.type_term(
                node["condition"], module, environment, f"{path}.condition", depth
            )
            then = self.type_term(node["then"], module, environment, f"{path}.then", depth)
            otherwise = self.type_term(node["else"], module, environment, f"{path}.else", depth)
            self.require_sort(condition.sort, sort_bool(), f"{path}.condition")
            self.require_sort(then.sort, otherwise.sort, path)
            return Typed(
                then.sort,
                condition.provenance | then.provenance | otherwise.provenance,
            )
        if rule in {"TYPE_KEYSORT_FORALL", "TYPE_KEYSORT_EXISTS"}:
            variable = node["variable"]
            self.require_fresh(variable, environment, path)
            self.check_sort(node["sort"], module, f"{path}.sort")
            if not self.is_key_or_cell_sort(node["sort"], module):
                reject("F05-CORE-QUANT-SORT", path)
            extended = dict(environment)
            extended[variable] = Typed(node["sort"], empty)
            body = self.type_term(node["body"], module, extended, f"{path}.body", depth)
            self.require_sort(body.sort, sort_bool(), f"{path}.body")
            return Typed(sort_bool(), body.provenance)
        if rule in {"TYPE_STATE_PRODUCT_PRE_GET", "TYPE_STATE_PRODUCT_POST_GET"}:
            state_product = self._resolve(
                node["state_product"], module, "DECL_STATE_PRODUCT", f"{path}.state_product"
            )
            key = self.type_term(node["key"], module, environment, f"{path}.key", depth)
            self.require_sort(key.sort, state_product.node["key_sort"], f"{path}.key")
            source = PRE if rule == "TYPE_STATE_PRODUCT_PRE_GET" else POST
            return Typed(
                state_product.node["value_sort"],
                key.provenance | frozenset({source}),
            )
        if rule == "TYPE_EVENT_CHANNEL_GET":
            channel = self._resolve(
                node["event_channel"], module, "DECL_EVENT_CHANNEL", f"{path}.event_channel"
            )
            payload = {"tag": "SORT_VARIANT", "variant": channel.node["payload_variant"]}
            return Typed(sort_option(payload), frozenset({EVENT}))
        reject("F05-CORE-RULE-TERM-DISPATCH", f"{path}:{tag}:{rule}")

    def _type_match_variant(
        self,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        depth: int,
    ) -> Typed:
        declaration = self._resolve(node["variant"], module, "DECL_VARIANT", f"{path}.variant")
        scrutinee = self.type_term(
            node["scrutinee"], module, environment, f"{path}.scrutinee", depth
        )
        self.require_sort(
            scrutinee.sort,
            {"tag": "SORT_VARIANT", "variant": node["variant"]},
            f"{path}.scrutinee",
        )
        variants = {
            item["variant_tag"]: item["payload_sort"]
            for item in declaration.node["variant_tags"]
        }
        branches = {item["variant_tag"]: item for item in node["branches"]}
        if set(branches) != set(variants):
            reject("F05-CORE-MATCH-VARIANT-EXHAUSTIVE", path)
        result_sort: dict[str, Any] | None = None
        provenance = scrutinee.provenance
        for variant_tag, payload_sort in variants.items():
            branch = branches[variant_tag]
            variable = branch["payload_variable"]
            self.require_fresh(variable, environment, f"{path}.{variant_tag}")
            extended = dict(environment)
            extended[variable] = Typed(payload_sort, scrutinee.provenance)
            body = self.type_term(
                branch["body"], module, extended, f"{path}.branches[{variant_tag}]", depth
            )
            if result_sort is None:
                result_sort = body.sort
            else:
                self.require_sort(body.sort, result_sort, path)
            provenance |= body.provenance
        if result_sort is None:
            reject("F05-CORE-MATCH-VARIANT-EMPTY", path)
        return Typed(result_sort, provenance)

    def _type_match_option(
        self,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        depth: int,
    ) -> Typed:
        self.check_sort(node["element_sort"], module, f"{path}.element_sort")
        scrutinee = self.type_term(
            node["scrutinee"], module, environment, f"{path}.scrutinee", depth
        )
        self.require_sort(
            scrutinee.sort,
            sort_option(node["element_sort"]),
            f"{path}.scrutinee",
        )
        none_body = self.type_term(
            node["none_body"], module, environment, f"{path}.none_body", depth
        )
        variable = node["some_variable"]
        self.require_fresh(variable, environment, path)
        extended = dict(environment)
        extended[variable] = Typed(node["element_sort"], scrutinee.provenance)
        some_body = self.type_term(
            node["some_body"], module, extended, f"{path}.some_body", depth
        )
        self.require_sort(none_body.sort, some_body.sort, path)
        return Typed(
            none_body.sort,
            scrutinee.provenance | none_body.provenance | some_body.provenance,
        )

    def binary_terms(
        self,
        node: dict[str, Any],
        module: str,
        environment: dict[str, Typed],
        path: str,
        depth: int,
    ) -> tuple[Typed, Typed]:
        return (
            self.type_term(node["left"], module, environment, f"{path}.left", depth),
            self.type_term(node["right"], module, environment, f"{path}.right", depth),
        )

    @staticmethod
    def require_fresh(variable: str, environment: dict[str, Typed], path: str) -> None:
        if variable in environment:
            reject("F05-CORE-BINDER-NOT-FRESH", f"{path}:{variable}")

    @staticmethod
    def require_sort(actual: dict[str, Any], expected: dict[str, Any], path: str) -> None:
        if actual != expected:
            reject("F05-CORE-SORT-MISMATCH", f"{path}:actual={actual} expected={expected}")

    @staticmethod
    def require_phase(result: Typed, allowed: frozenset[str], path: str) -> None:
        if not result.provenance <= allowed:
            reject(
                "F05-CORE-PROVENANCE-PHASE",
                f"{path}:actual={sorted(result.provenance)} allowed={sorted(allowed)}",
            )
