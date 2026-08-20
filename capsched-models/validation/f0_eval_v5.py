"""Finite reference ObsD/Eval/DynDeps evaluator for DL-F0-5.

The implementation is an untrusted construction oracle. Passing it is not a
metatheory proof, independent validation, CoreSyntaxWF, or F0 acceptance.
"""

from __future__ import annotations

import importlib.util
import hashlib
import json
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Mapping


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


rules_module = _load_local("f0_eval_rules_v5_runtime", "f0_eval_rules_v5.py")
values_module = _load_local("f0_finite_values_v5_runtime", "f0_finite_values_v5.py")

EvalRuleContract = rules_module.EvalRuleContract
RuleReject = rules_module.Reject
FiniteInterpretation = values_module.FiniteInterpretation
StateView = values_module.StateView
EventView = values_module.EventView
Value = values_module.Value
InterpretationRef = values_module.InterpretationRef
ResourceUsage = values_module.ResourceUsage
ResourceProfile = values_module.ResourceProfile
ValueReject = values_module.Reject
ValueInconclusive = values_module.Inconclusive
canonical_bytes = values_module.canonical_bytes
make_value = values_module.make_value
qname = values_module.qname
qwire = values_module.qwire
declaration_ref = values_module.declaration_ref
constant_value_ref = values_module.constant_value_ref
arithmetic_binding_ref = values_module.arithmetic_binding_ref


EXPECTED_RULE_CANONICAL_SHA256 = "a40b4e91e751adae2ba20ea076c839453acab5f77101d10136f16489b1920f9b"
EXPECTED_TERM_TAGS = frozenset(
    {
        "TERM_BOOL",
        "TERM_ONE",
        "TERM_ENUM",
        "TERM_QTY_ZERO",
        "TERM_QTY_CHECKED",
        "TERM_CONSTANT",
        "TERM_VARIABLE",
        "TERM_LET",
        "TERM_RECORD",
        "TERM_FIELD",
        "TERM_VARIANT",
        "TERM_MATCH_VARIANT",
        "TERM_NONE",
        "TERM_SOME",
        "TERM_MATCH_OPTION",
        "TERM_SET_EMPTY",
        "TERM_SET_INSERT",
        "TERM_SET_REMOVE",
        "TERM_SET_MEMBER",
        "TERM_SET_SUBSET",
        "TERM_SET_UNION",
        "TERM_SET_DIFFERENCE",
        "TERM_MAP_GET",
        "TERM_MAP_SET",
        "TERM_AND",
        "TERM_OR",
        "TERM_NOT",
        "TERM_IMPLIES",
        "TERM_IFF",
        "TERM_EQ",
        "TERM_QTY_LT",
        "TERM_QTY_LE",
        "TERM_QTY_GT",
        "TERM_QTY_GE",
        "TERM_QTY_ADD",
        "TERM_QTY_SUB",
        "TERM_IF",
        "TERM_FORALL",
        "TERM_EXISTS",
        "TERM_PRE_GET",
        "TERM_POST_GET",
        "TERM_EVENT_GET",
    }
)


class EvalReject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> None:
    raise EvalReject(reject_id, detail)


def bind_rule_contract(contract: EvalRuleContract) -> None:
    if not isinstance(contract, EvalRuleContract):
        raise TypeError("EvalRuleContract required")
    if contract.rules_canonical_sha256 != EXPECTED_RULE_CANONICAL_SHA256:
        reject(
            "F05-EVAL-RULE-IMPLEMENTATION-DRIFT",
            f"{contract.rules_canonical_sha256}!={EXPECTED_RULE_CANONICAL_SHA256}",
        )
    if set(contract.evaluation_rules) != EXPECTED_TERM_TAGS:
        reject("F05-EVAL-RULE-HANDLER-DOMAIN", "evaluation rule domain")
    if set(contract.may_dependency_rules) != EXPECTED_TERM_TAGS:
        reject("F05-EVAL-RULE-HANDLER-DOMAIN", "MayDeps rule domain")
    if set(contract.evaluation_reference_rules) != EXPECTED_TERM_TAGS:
        reject("F05-EVAL-RULE-HANDLER-DOMAIN", "InterpretationRefs rule domain")
    if set(contract.carrier_reference_rules) != {
        "SORT_BOOL",
        "SORT_ONE",
        "SORT_ATOM",
        "SORT_ENUM",
        "SORT_QTY",
        "SORT_RECORD",
        "SORT_VARIANT",
        "SORT_OPTION",
        "SORT_FINSET",
        "SORT_TOTALMAP",
    }:
        reject("F05-EVAL-RULE-HANDLER-DOMAIN", "CarrierRefs rule domain")


@dataclass(frozen=True)
class InputDep:
    kind: str
    subject: tuple[str, ...]
    key: Value | None = None

    def __post_init__(self) -> None:
        if self.kind not in {"PARAM", "PRE", "POST", "EVENT"}:
            raise ValueError(f"unknown dependency kind {self.kind}")
        if not self.subject or not all(isinstance(part, str) and part for part in self.subject):
            raise ValueError("dependency subject must be a nonempty string tuple")
        if self.kind in {"PRE", "POST"} and self.key is None:
            raise ValueError("state dependency needs a typed key")
        if self.kind not in {"PRE", "POST"} and self.key is not None:
            raise ValueError("non-state dependency cannot carry a key")

    @property
    def source(self) -> str:
        return self.kind

    def as_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"kind": self.kind, "subject": list(self.subject)}
        if self.key is not None:
            result["key"] = values_module.value_wire(self.key)
        return result


def param_dep(slot: tuple[str, ...]) -> InputDep:
    return InputDep("PARAM", slot)


def state_dep(phase: str, product: tuple[str, str], key: Value) -> InputDep:
    return InputDep(phase, product, key)


def event_dep(channel: tuple[str, str]) -> InputDep:
    return InputDep("EVENT", channel)


@dataclass(frozen=True)
class EnvBinding:
    value: Value
    dependencies: frozenset[InputDep]
    lookup_trace: tuple[InputDep, ...]
    root_external: bool

    @classmethod
    def external_parameter(cls, value: Value, slot: tuple[str, ...]) -> "EnvBinding":
        dependency = param_dep(slot)
        return cls(value, frozenset({dependency}), (dependency,), True)

    @classmethod
    def external(cls, value: Value, dependencies: frozenset[InputDep]) -> "EnvBinding":
        ordered = tuple(sorted(dependencies, key=lambda dep: canonical_bytes(dep.as_dict())))
        return cls(value, dependencies, ordered, True)

    @classmethod
    def derived(cls, value: Value, dependencies: frozenset[InputDep]) -> "EnvBinding":
        return cls(value, dependencies, (), False)

    @classmethod
    def quantified(cls, value: Value) -> "EnvBinding":
        return cls(value, frozenset(), (), False)


@dataclass(frozen=True)
class GammaBinding:
    sort_raw: bytes
    sources: frozenset[str]
    parameter_slot: tuple[str, ...] | None = None

    @classmethod
    def create(
        cls,
        sort: Mapping[str, Any],
        sources: frozenset[str],
        parameter_slot: tuple[str, ...] | None = None,
    ) -> "GammaBinding":
        if not isinstance(sort, Mapping):
            raise TypeError("Gamma sort must be a mapping")
        if not isinstance(sources, frozenset) or not sources <= {
            "PARAM",
            "PRE",
            "POST",
            "EVENT",
        }:
            raise TypeError("Gamma sources must be an exact source frozenset")
        if "PARAM" in sources:
            if parameter_slot is None or not parameter_slot:
                raise ValueError("PARAM Gamma binding requires an exact ParamSlot")
        elif parameter_slot is not None:
            raise ValueError("non-PARAM Gamma binding cannot carry a ParamSlot")
        return cls(canonical_bytes(dict(sort)), sources, parameter_slot)


@dataclass(frozen=True)
class EvalInputs:
    pre: StateView | None = None
    post: StateView | None = None
    event: EventView | None = None


@dataclass(frozen=True)
class Observation:
    value: Value
    dependencies: frozenset[InputDep]
    access_trace: tuple[InputDep, ...]
    interpretation_refs: frozenset[InterpretationRef]

    @property
    def state_reads(self) -> frozenset[InputDep]:
        return frozenset(dep for dep in self.dependencies if dep.kind in {"PRE", "POST"})

    def as_dict(self) -> dict[str, Any]:
        dependency_rows = sorted(
            (dep.as_dict() for dep in self.dependencies), key=canonical_bytes
        )
        state_rows = sorted((dep.as_dict() for dep in self.state_reads), key=canonical_bytes)
        return {
            "value": values_module.value_wire(self.value),
            "dynamic_dependencies": dependency_rows,
            "state_reads": state_rows,
            "access_trace": [entry.as_dict() for entry in self.access_trace],
            "interpretation_refs": sorted(
                (ref.as_dict() for ref in self.interpretation_refs), key=canonical_bytes
            ),
        }


@dataclass(frozen=True)
class EvaluationResult:
    observation: Observation
    may_dependencies: frozenset[InputDep]
    usage: Mapping[str, int]
    resource_profile: Mapping[str, int]
    resource_profile_sha256: str
    rule_table_canonical_sha256: str

    @property
    def authority(self) -> str:
        return "untrusted_finite_reference_evaluator_only"

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
            "status": "finite_reference_evaluation_completed",
            "authority": "untrusted_finite_reference_evaluator_only",
            **self.observation.as_dict(),
            "may_dependencies": sorted(
                (dep.as_dict() for dep in self.may_dependencies), key=canonical_bytes
            ),
            "usage": dict(self.usage),
            "resource_profile": dict(self.resource_profile),
            "resource_profile_sha256": self.resource_profile_sha256,
            "rule_table_canonical_sha256": self.rule_table_canonical_sha256,
            "evaluation_validated": False,
            "F0_local_acceptance": False,
            "protection_claim": False,
        }


def _merge(value: Value, observations: list[Observation]) -> Observation:
    dependencies: set[InputDep] = set()
    trace: list[InputDep] = []
    refs: set[InterpretationRef] = set()
    for observation in observations:
        dependencies.update(observation.dependencies)
        trace.extend(observation.access_trace)
        refs.update(observation.interpretation_refs)
    return Observation(value, frozenset(dependencies), tuple(trace), frozenset(refs))


def _bool(value: Value, path: str) -> bool:
    if value.constructor != "VALUE_BOOL" or type(value.payload[0]) is not bool:
        reject("F05-EVAL-INTERNAL-TYPE", path)
    return value.payload[0]


def _qty(value: Value, path: str) -> int:
    if value.constructor != "VALUE_QTY" or type(value.payload[2]) is not int:
        reject("F05-EVAL-INTERNAL-TYPE", path)
    return value.payload[2]


class FiniteEvaluator:
    def __init__(
        self,
        interpretation: FiniteInterpretation,
        rule_contract: EvalRuleContract | None = None,
        resource_profile: ResourceProfile | None = None,
    ) -> None:
        self.base_interpretation = interpretation
        self.resource_profile = resource_profile or interpretation.usage.profile
        self.interpretation = interpretation.fork_request(self.resource_profile)
        self.rule_contract = rule_contract or rules_module.load_contract()
        bind_rule_contract(self.rule_contract)
        self.usage: ResourceUsage = self.interpretation.usage
        self.term_tag_counts: dict[str, int] = {}
        self._access_trace: list[InputDep] = []
        self._request_lock = threading.Lock()
        self._bound_request_session_consumed = False

    def evaluate_root(
        self,
        term: Mapping[str, Any],
        environment: Mapping[str, EnvBinding],
        gamma: Mapping[str, GammaBinding],
        inputs: EvalInputs,
        term_sources: frozenset[str],
    ) -> EvaluationResult:
        with self._request_lock:
            return self._evaluate_root_locked(
                term,
                environment,
                gamma,
                inputs,
                term_sources,
                fork_request=True,
            )

    def evaluate_root_in_bound_request_session(
        self,
        term: Mapping[str, Any],
        environment: Mapping[str, EnvBinding],
        gamma: Mapping[str, GammaBinding],
        inputs: EvalInputs,
        term_sources: frozenset[str],
    ) -> EvaluationResult:
        """Consume one interpretation session already used to decode its inputs.

        This preserves one resource ledger and one carrier cache from profile and
        input decoding through Eval, DynDeps, MayDeps, and result construction.
        The entry point remains an untrusted construction API and is deliberately
        one-shot so a caller cannot amortize several evaluations over one ledger.
        """

        with self._request_lock:
            if self._bound_request_session_consumed:
                reject(
                    "F05-EVAL-BOUND-REQUEST-REUSED",
                    "bound finite-evaluation request sessions are one-shot",
                )
            if self.base_interpretation.usage.profile != self.resource_profile:
                reject(
                    "F05-EVAL-BOUND-REQUEST-PROFILE",
                    "interpretation and evaluator resource profiles differ",
                )
            self._bound_request_session_consumed = True
            return self._evaluate_root_locked(
                term,
                environment,
                gamma,
                inputs,
                term_sources,
                fork_request=False,
            )

    def _evaluate_root_locked(
        self,
        term: Mapping[str, Any],
        environment: Mapping[str, EnvBinding],
        gamma: Mapping[str, GammaBinding],
        inputs: EvalInputs,
        term_sources: frozenset[str],
        fork_request: bool,
    ) -> EvaluationResult:
        self.interpretation = (
            self.base_interpretation.fork_request(self.resource_profile)
            if fork_request
            else self.base_interpretation
        )
        self.usage = self.interpretation.usage
        self._access_trace = []
        if not isinstance(term_sources, frozenset) or not term_sources <= {
            "PARAM",
            "PRE",
            "POST",
            "EVENT",
        }:
            raise TypeError("term_sources must be an exact source frozenset")
        view_presence = {
            "PRE": inputs.pre is not None,
            "POST": inputs.post is not None,
            "EVENT": inputs.event is not None,
        }
        for source, present in view_presence.items():
            if present != (source in term_sources):
                reject(
                    "F05-EVAL-ROOT-INPUT-DOMAIN",
                    f"{source}:present={present} required={source in term_sources}",
                )
        if inputs.pre is not None and not isinstance(inputs.pre, StateView):
            raise TypeError("PRE input must be a decoded StateView")
        if inputs.post is not None and not isinstance(inputs.post, StateView):
            raise TypeError("POST input must be a decoded StateView")
        if inputs.event is not None and not isinstance(inputs.event, EventView):
            raise TypeError("EVENT input must be a decoded EventView")
        if set(environment) != set(gamma):
            reject("F05-EVAL-ROOT-GAMMA-DOMAIN", "environment and Gamma differ")
        if len(gamma) > 1:
            reject("F05-EVAL-ROOT-CONTEXT", "root Gamma is neither closed nor one action parameter")
        delta: dict[str, frozenset[InputDep]] = {}
        for variable, binding in environment.items():
            gamma_binding = gamma.get(variable)
            if (
                not isinstance(variable, str)
                or not isinstance(binding, EnvBinding)
                or not isinstance(gamma_binding, GammaBinding)
            ):
                raise TypeError("root environment/Gamma have invalid binding types")
            if not binding.root_external:
                reject("F05-EVAL-ROOT-ENV-DERIVED", variable)
            if binding.value.sort_raw != gamma_binding.sort_raw:
                reject("F05-EVAL-ROOT-GAMMA-SORT", variable)
            binding.value.require_sort(
                json.loads(gamma_binding.sort_raw.decode("ascii")),
                f"root.{variable}",
            )
            if gamma_binding.sources != frozenset({"PARAM"}):
                reject("F05-EVAL-ROOT-CONTEXT", f"{variable}:non-PARAM root binding")
            expected_parameter = param_dep(gamma_binding.parameter_slot or ())
            if binding.dependencies != frozenset({expected_parameter}):
                reject("F05-EVAL-ROOT-GAMMA-PARAM-SLOT", variable)
            if binding.lookup_trace != (expected_parameter,):
                reject("F05-EVAL-ROOT-ENV-TRACE", variable)
            delta[variable] = frozenset({expected_parameter})
        evaluated = self._eval(term, dict(environment), inputs, 0)
        observation = Observation(
            evaluated.value,
            evaluated.dependencies,
            tuple(self._access_trace),
            evaluated.interpretation_refs,
        )
        trace_projection = frozenset(observation.access_trace)
        if trace_projection != observation.dependencies:
            raise RuntimeError("AccessTrace projection differs from DynDeps")
        observed_sources = {dependency.source for dependency in observation.dependencies}
        if not observed_sources <= term_sources:
            reject(
                "F05-EVAL-DYNAMIC-SOURCE",
                f"observed={sorted(observed_sources)} static={sorted(term_sources)}",
            )
        may = self._may(term, delta, 0)
        if not observation.dependencies <= may:
            raise RuntimeError("DynDeps is not contained in MayDeps")
        self.usage.observe_peak("INTERPRETATION_REFS", len(observation.interpretation_refs))
        return EvaluationResult(
            observation=observation,
            may_dependencies=may,
            usage=MappingProxyType(self.usage.as_dict()),
            resource_profile=MappingProxyType(self.resource_profile.as_dict()),
            resource_profile_sha256=hashlib.sha256(
                canonical_bytes(self.resource_profile.as_dict())
            ).hexdigest(),
            rule_table_canonical_sha256=self.rule_contract.rules_canonical_sha256,
        )

    def _term(self, term: Mapping[str, Any], depth: int) -> tuple[dict[str, Any], dict[str, Any]]:
        self.usage.enter_depth(depth)
        self.usage.charge("TERM_VISITS")
        if not isinstance(term, dict) or set(term) != {"tag", "result_sort", "node"} or term.get("tag") != "TYPED_TERM":
            reject("F05-EVAL-TERM-SHAPE", f"depth={depth}")
        result_sort = term["result_sort"]
        node = term["node"]
        if not isinstance(result_sort, dict) or not isinstance(node, dict):
            reject("F05-EVAL-TERM-SHAPE", f"depth={depth}")
        tag = node.get("tag")
        if tag not in EXPECTED_TERM_TAGS:
            reject("F05-EVAL-TERM-TAG", repr(tag))
        self.term_tag_counts[tag] = self.term_tag_counts.get(tag, 0) + 1
        return result_sort, node

    def _checked(self, observation: Observation, result_sort: dict[str, Any], tag: str) -> Observation:
        observation.value.require_sort(result_sort, tag)
        return observation

    def _record_access(self, dependency: InputDep) -> None:
        self.usage.charge("ACCESS_TRACE_ENTRIES")
        self._access_trace.append(dependency)

    def _eval(
        self,
        term: Mapping[str, Any],
        environment: dict[str, EnvBinding],
        inputs: EvalInputs,
        depth: int,
    ) -> Observation:
        result_sort, node = self._term(term, depth)
        tag = node["tag"]

        if tag == "TERM_BOOL":
            if type(node.get("value")) is not bool:
                reject("F05-EVAL-BOOL", repr(node.get("value")))
            result = Observation(make_value(result_sort, "VALUE_BOOL", node["value"]), frozenset(), (), frozenset())
        elif tag == "TERM_ONE":
            result = Observation(make_value(result_sort, "VALUE_ONE"), frozenset(), (), frozenset())
        elif tag == "TERM_ENUM":
            enum = qname(node["enum"], "TERM_ENUM.enum")
            declaration = self.interpretation.signature.declaration(enum, "DECL_ENUM", "TERM_ENUM")
            if node["member"] not in declaration["members"]:
                reject("F05-EVAL-ENUM", node["member"])
            result = Observation(
                make_value(result_sort, "VALUE_ENUM", enum, node["member"]),
                frozenset(),
                (),
                frozenset({declaration_ref("DECL_ENUM", enum)}),
            )
        elif tag == "TERM_QTY_ZERO":
            unit = qname(node["unit"], "TERM_QTY_ZERO.unit")
            limit = qname(node["limit"], "TERM_QTY_ZERO.limit")
            self.interpretation.signature.declaration(unit, "DECL_UNIT", tag)
            self.interpretation.signature.declaration(limit, "DECL_LIMIT", tag)
            result = Observation(
                make_value(result_sort, "VALUE_QTY", unit, limit, 0),
                frozenset(),
                (),
                self.interpretation.carrier_refs(result_sort),
            )
        elif tag == "TERM_QTY_CHECKED":
            result = self._eval_qty_checked(result_sort, node)
        elif tag == "TERM_CONSTANT":
            constant = qname(node["constant"], "TERM_CONSTANT.constant")
            value = self.interpretation.constants.get(constant)
            if value is None:
                reject("F05-EVAL-CONSTANT", repr(constant))
            result = Observation(
                value,
                frozenset(),
                (),
                frozenset(
                    {
                        declaration_ref("DECL_CONSTANT", constant),
                        constant_value_ref(constant),
                    }
                ),
            )
        elif tag == "TERM_VARIABLE":
            variable = node["variable"]
            binding = environment.get(variable)
            if binding is None:
                reject("F05-EVAL-VARIABLE", repr(variable))
            for dependency in binding.lookup_trace:
                self._record_access(dependency)
            result = Observation(binding.value, binding.dependencies, (), frozenset())
        elif tag == "TERM_LET":
            bound = self._eval(node["bound"], environment, inputs, depth + 1)
            extended = dict(environment)
            extended[node["variable"]] = EnvBinding.derived(bound.value, bound.dependencies)
            body = self._eval(node["body"], extended, inputs, depth + 1)
            result = _merge(body.value, [bound, body])
        elif tag == "TERM_RECORD":
            observations: list[Observation] = []
            fields: list[tuple[str, Value]] = []
            for entry in node["values"]:
                observation = self._eval(entry["value"], environment, inputs, depth + 1)
                observations.append(observation)
                fields.append((entry["field"], observation.value))
            record = qname(node["record"], "TERM_RECORD.record")
            self.interpretation.signature.declaration(record, "DECL_RECORD", tag)
            result = _merge(
                make_value(result_sort, "VALUE_RECORD", record, tuple(sorted(fields))),
                observations,
            )
            result = Observation(
                result.value,
                result.dependencies,
                result.access_trace,
                frozenset(set(result.interpretation_refs) | {declaration_ref("DECL_RECORD", record)}),
            )
        elif tag == "TERM_FIELD":
            record = self._eval(node["record_term"], environment, inputs, depth + 1)
            fields = dict(record.value.payload[1])
            if node["field"] not in fields:
                reject("F05-EVAL-FIELD", node["field"])
            result = _merge(fields[node["field"]], [record])
        elif tag == "TERM_VARIANT":
            payload = self._eval(node["payload"], environment, inputs, depth + 1)
            variant = qname(node["variant"], "TERM_VARIANT.variant")
            self.interpretation.signature.declaration(variant, "DECL_VARIANT", tag)
            result = _merge(
                make_value(result_sort, "VALUE_VARIANT", variant, node["variant_tag"], payload.value),
                [payload],
            )
            result = Observation(
                result.value,
                result.dependencies,
                result.access_trace,
                frozenset(set(result.interpretation_refs) | {declaration_ref("DECL_VARIANT", variant)}),
            )
        elif tag == "TERM_MATCH_VARIANT":
            scrutinee = self._eval(node["scrutinee"], environment, inputs, depth + 1)
            selected_tag = scrutinee.value.payload[1]
            branch = next((row for row in node["branches"] if row["variant_tag"] == selected_tag), None)
            if branch is None:
                reject("F05-EVAL-MATCH-VARIANT", selected_tag)
            extended = dict(environment)
            extended[branch["payload_variable"]] = EnvBinding.derived(
                scrutinee.value.payload[2], scrutinee.dependencies
            )
            body = self._eval(branch["body"], extended, inputs, depth + 1)
            result = _merge(body.value, [scrutinee, body])
        elif tag == "TERM_NONE":
            result = Observation(make_value(result_sort, "VALUE_NONE"), frozenset(), (), frozenset())
        elif tag == "TERM_SOME":
            value = self._eval(node["value"], environment, inputs, depth + 1)
            result = _merge(make_value(result_sort, "VALUE_SOME", value.value), [value])
        elif tag == "TERM_MATCH_OPTION":
            scrutinee = self._eval(node["scrutinee"], environment, inputs, depth + 1)
            if scrutinee.value.constructor == "VALUE_NONE":
                body = self._eval(node["none_body"], environment, inputs, depth + 1)
            elif scrutinee.value.constructor == "VALUE_SOME":
                extended = dict(environment)
                extended[node["some_variable"]] = EnvBinding.derived(
                    scrutinee.value.payload[0], scrutinee.dependencies
                )
                body = self._eval(node["some_body"], extended, inputs, depth + 1)
            else:
                reject("F05-EVAL-MATCH-OPTION", scrutinee.value.constructor)
            result = _merge(body.value, [scrutinee, body])
        elif tag == "TERM_SET_EMPTY":
            result = Observation(make_value(result_sort, "VALUE_FINSET", ()), frozenset(), (), frozenset())
        elif tag in {
            "TERM_SET_INSERT",
            "TERM_SET_REMOVE",
            "TERM_SET_MEMBER",
            "TERM_SET_SUBSET",
            "TERM_SET_UNION",
            "TERM_SET_DIFFERENCE",
        }:
            result = self._eval_set(tag, result_sort, node, environment, inputs, depth)
        elif tag == "TERM_MAP_GET":
            map_observation = self._eval(node["map"], environment, inputs, depth + 1)
            key_observation = self._eval(node["key"], environment, inputs, depth + 1)
            entries = dict(map_observation.value.payload[0])
            if key_observation.value not in entries:
                reject("F05-EVAL-MAP-DOMAIN", "validated total map lost a key")
            result = _merge(entries[key_observation.value], [map_observation, key_observation])
        elif tag == "TERM_MAP_SET":
            map_observation = self._eval(node["map"], environment, inputs, depth + 1)
            key_observation = self._eval(node["key"], environment, inputs, depth + 1)
            value_observation = self._eval(node["value"], environment, inputs, depth + 1)
            entries = [
                (key, value_observation.value if key == key_observation.value else value)
                for key, value in map_observation.value.payload[0]
            ]
            result = _merge(
                make_value(result_sort, "VALUE_TOTALMAP", tuple(entries)),
                [map_observation, key_observation, value_observation],
            )
        elif tag in {"TERM_AND", "TERM_OR"}:
            operands = [self._eval(item, environment, inputs, depth + 1) for item in node["operands"]]
            values = [_bool(item.value, tag) for item in operands]
            boolean = all(values) if tag == "TERM_AND" else any(values)
            result = _merge(make_value(result_sort, "VALUE_BOOL", boolean), operands)
        elif tag == "TERM_NOT":
            operand = self._eval(node["operand"], environment, inputs, depth + 1)
            result = _merge(make_value(result_sort, "VALUE_BOOL", not _bool(operand.value, tag)), [operand])
        elif tag in {"TERM_IMPLIES", "TERM_IFF"}:
            left = self._eval(node["left"], environment, inputs, depth + 1)
            right = self._eval(node["right"], environment, inputs, depth + 1)
            left_value = _bool(left.value, tag)
            right_value = _bool(right.value, tag)
            boolean = (not left_value or right_value) if tag == "TERM_IMPLIES" else left_value == right_value
            result = _merge(make_value(result_sort, "VALUE_BOOL", boolean), [left, right])
        elif tag == "TERM_EQ":
            left = self._eval(node["left"], environment, inputs, depth + 1)
            right = self._eval(node["right"], environment, inputs, depth + 1)
            result = _merge(make_value(result_sort, "VALUE_BOOL", left.value == right.value), [left, right])
        elif tag in {"TERM_QTY_LT", "TERM_QTY_LE", "TERM_QTY_GT", "TERM_QTY_GE"}:
            left = self._eval(node["left"], environment, inputs, depth + 1)
            right = self._eval(node["right"], environment, inputs, depth + 1)
            left_value = _qty(left.value, tag)
            right_value = _qty(right.value, tag)
            comparison = {
                "TERM_QTY_LT": left_value < right_value,
                "TERM_QTY_LE": left_value <= right_value,
                "TERM_QTY_GT": left_value > right_value,
                "TERM_QTY_GE": left_value >= right_value,
            }[tag]
            result = _merge(make_value(result_sort, "VALUE_BOOL", comparison), [left, right])
        elif tag in {"TERM_QTY_ADD", "TERM_QTY_SUB"}:
            result = self._eval_qty_arithmetic(tag, result_sort, node, environment, inputs, depth)
        elif tag == "TERM_IF":
            condition = self._eval(node["condition"], environment, inputs, depth + 1)
            selected = node["then"] if _bool(condition.value, tag) else node["else"]
            body = self._eval(selected, environment, inputs, depth + 1)
            result = _merge(body.value, [condition, body])
        elif tag in {"TERM_FORALL", "TERM_EXISTS"}:
            dependencies: set[InputDep] = set()
            refs: set[InterpretationRef] = set(
                self.interpretation.carrier_refs(node["sort"], depth + 1)
            )
            boolean = tag == "TERM_FORALL"
            for value in self.interpretation.enumerate_sort(node["sort"], depth + 1):
                self.usage.charge("QUANTIFIER_ITERATIONS")
                extended = dict(environment)
                extended[node["variable"]] = EnvBinding.quantified(value)
                body = self._eval(node["body"], extended, inputs, depth + 1)
                body_value = _bool(body.value, tag)
                boolean = boolean and body_value if tag == "TERM_FORALL" else boolean or body_value
                dependencies.update(body.dependencies)
                refs.update(body.interpretation_refs)
            result = Observation(
                make_value(result_sort, "VALUE_BOOL", boolean),
                frozenset(dependencies),
                (),
                frozenset(refs),
            )
        elif tag in {"TERM_PRE_GET", "TERM_POST_GET"}:
            key_observation = self._eval(node["key"], environment, inputs, depth + 1)
            product = qname(node["state_product"], f"{tag}.state_product")
            phase = "PRE" if tag == "TERM_PRE_GET" else "POST"
            view = inputs.pre if phase == "PRE" else inputs.post
            if view is None:
                reject("F05-EVAL-MISSING-INPUT", phase)
            self.interpretation.signature.declaration(product, "DECL_STATE_PRODUCT", tag)
            dependency = state_dep(phase, product, key_observation.value)
            self._record_access(dependency)
            value = view.get(product, key_observation.value)
            result = Observation(
                value,
                frozenset(set(key_observation.dependencies) | {dependency}),
                (),
                frozenset(
                    set(key_observation.interpretation_refs)
                    | {declaration_ref("DECL_STATE_PRODUCT", product)}
                ),
            )
        elif tag == "TERM_EVENT_GET":
            channel = qname(node["event_channel"], "TERM_EVENT_GET.event_channel")
            if inputs.event is None:
                reject("F05-EVAL-MISSING-INPUT", "EVENT")
            self.interpretation.signature.declaration(channel, "DECL_EVENT_CHANNEL", tag)
            dependency = event_dep(channel)
            self._record_access(dependency)
            result = Observation(
                inputs.event.get(channel),
                frozenset({dependency}),
                (),
                frozenset({declaration_ref("DECL_EVENT_CHANNEL", channel)}),
            )
        else:
            raise RuntimeError(f"implementation handler missing for {tag}")
        return self._checked(result, result_sort, tag)

    def _eval_qty_checked(self, result_sort: dict[str, Any], node: Mapping[str, Any]) -> Observation:
        unit = qname(node["unit"], "TERM_QTY_CHECKED.unit")
        limit = qname(node["limit"], "TERM_QTY_CHECKED.limit")
        amount = node["value"]
        if type(amount) is not int or amount < 0:
            reject("F05-EVAL-QTY-CHECKED", repr(amount))
        quantity_sort = {"tag": "SORT_QTY", "unit": qwire(unit), "limit": qwire(limit)}
        variant = self.interpretation.arithmetic_result_variant(quantity_sort)
        self.interpretation.signature.declaration(variant, "DECL_VARIANT", "TERM_QTY_CHECKED")
        if amount <= self.interpretation.limits[limit]:
            variant_tag = "Ok"
            payload = make_value(quantity_sort, "VALUE_QTY", unit, limit, amount)
        else:
            variant_tag = "Overflow"
            payload = make_value({"tag": "SORT_ONE"}, "VALUE_ONE")
        refs = set(self.interpretation.carrier_refs(quantity_sort))
        refs.update(
            {
                arithmetic_binding_ref(unit, limit, variant),
                declaration_ref("DECL_VARIANT", variant),
            }
        )
        return Observation(
            make_value(result_sort, "VALUE_VARIANT", variant, variant_tag, payload),
            frozenset(),
            (),
            frozenset(refs),
        )

    def _eval_qty_arithmetic(
        self,
        tag: str,
        result_sort: dict[str, Any],
        node: Mapping[str, Any],
        environment: dict[str, EnvBinding],
        inputs: EvalInputs,
        depth: int,
    ) -> Observation:
        left = self._eval(node["left"], environment, inputs, depth + 1)
        right = self._eval(node["right"], environment, inputs, depth + 1)
        quantity_sort = left.value.sort
        variant = self.interpretation.arithmetic_result_variant(quantity_sort)
        self.interpretation.signature.declaration(variant, "DECL_VARIANT", tag)
        left_amount = _qty(left.value, tag)
        right_amount = _qty(right.value, tag)
        limit = left.value.payload[1]
        if tag == "TERM_QTY_ADD":
            amount = left_amount + right_amount
            if amount <= self.interpretation.limits[limit]:
                variant_tag = "Ok"
                payload = make_value(quantity_sort, "VALUE_QTY", left.value.payload[0], limit, amount)
            else:
                variant_tag = "Overflow"
                payload = make_value({"tag": "SORT_ONE"}, "VALUE_ONE")
        elif right_amount <= left_amount:
            variant_tag = "Ok"
            payload = make_value(
                quantity_sort,
                "VALUE_QTY",
                left.value.payload[0],
                limit,
                left_amount - right_amount,
            )
        else:
            variant_tag = "Underflow"
            payload = make_value({"tag": "SORT_ONE"}, "VALUE_ONE")
        merged = _merge(
            make_value(result_sort, "VALUE_VARIANT", variant, variant_tag, payload),
            [left, right],
        )
        unit = left.value.payload[0]
        refs = set(merged.interpretation_refs)
        refs.update(self.interpretation.carrier_refs(quantity_sort))
        refs.update(
            {
                arithmetic_binding_ref(unit, limit, variant),
                declaration_ref("DECL_VARIANT", variant),
            }
        )
        return Observation(
            merged.value,
            merged.dependencies,
            merged.access_trace,
            frozenset(refs),
        )

    def _eval_set(
        self,
        tag: str,
        result_sort: dict[str, Any],
        node: Mapping[str, Any],
        environment: dict[str, EnvBinding],
        inputs: EvalInputs,
        depth: int,
    ) -> Observation:
        if tag in {"TERM_SET_INSERT", "TERM_SET_REMOVE", "TERM_SET_MEMBER"}:
            left = self._eval(node["set"], environment, inputs, depth + 1)
            right = self._eval(node["element"], environment, inputs, depth + 1)
            items = set(left.value.payload[0])
            if tag == "TERM_SET_INSERT":
                items.add(right.value)
                value = make_value(result_sort, "VALUE_FINSET", tuple(sorted(items, key=values_module.value_order_key)))
            elif tag == "TERM_SET_REMOVE":
                items.discard(right.value)
                value = make_value(result_sort, "VALUE_FINSET", tuple(sorted(items, key=values_module.value_order_key)))
            else:
                value = make_value(result_sort, "VALUE_BOOL", right.value in items)
            return _merge(value, [left, right])
        left = self._eval(node["left"], environment, inputs, depth + 1)
        right = self._eval(node["right"], environment, inputs, depth + 1)
        left_set = set(left.value.payload[0])
        right_set = set(right.value.payload[0])
        if tag == "TERM_SET_SUBSET":
            value = make_value(result_sort, "VALUE_BOOL", left_set <= right_set)
        elif tag == "TERM_SET_UNION":
            value = make_value(result_sort, "VALUE_FINSET", tuple(sorted(left_set | right_set, key=values_module.value_order_key)))
        else:
            value = make_value(result_sort, "VALUE_FINSET", tuple(sorted(left_set - right_set, key=values_module.value_order_key)))
        return _merge(value, [left, right])

    def _may(
        self,
        term: Mapping[str, Any],
        environment: Mapping[str, frozenset[InputDep]],
        depth: int,
    ) -> frozenset[InputDep]:
        self.usage.enter_depth(depth)
        self.usage.charge("MAY_TERM_VISITS")
        if not isinstance(term, dict) or term.get("tag") != "TYPED_TERM" or not isinstance(term.get("node"), dict):
            reject("F05-EVAL-MAY-TERM", f"depth={depth}")
        node = term["node"]
        tag = node.get("tag")
        empty_tags = {
            "TERM_BOOL",
            "TERM_ONE",
            "TERM_ENUM",
            "TERM_QTY_ZERO",
            "TERM_QTY_CHECKED",
            "TERM_CONSTANT",
            "TERM_NONE",
            "TERM_SET_EMPTY",
        }
        if tag in empty_tags:
            return self._bounded_may(())
        if tag == "TERM_VARIABLE":
            if node["variable"] not in environment:
                reject("F05-EVAL-MAY-VARIABLE", node["variable"])
            return self._bounded_may(environment[node["variable"]])
        if tag == "TERM_LET":
            bound = self._may(node["bound"], environment, depth + 1)
            extended = dict(environment)
            extended[node["variable"]] = bound
            return self._bounded_may(
                bound,
                self._may(node["body"], extended, depth + 1),
            )
        if tag == "TERM_RECORD":
            return self._may_union((entry["value"] for entry in node["values"]), environment, depth)
        if tag == "TERM_FIELD":
            return self._may(node["record_term"], environment, depth + 1)
        if tag in {"TERM_VARIANT", "TERM_SOME"}:
            field = "payload" if tag == "TERM_VARIANT" else "value"
            return self._may(node[field], environment, depth + 1)
        if tag == "TERM_MATCH_VARIANT":
            scrutinee = self._may(node["scrutinee"], environment, depth + 1)
            parts: list[frozenset[InputDep]] = [scrutinee]
            for branch in node["branches"]:
                extended = dict(environment)
                extended[branch["payload_variable"]] = scrutinee
                parts.append(self._may(branch["body"], extended, depth + 1))
            return self._bounded_may(*parts)
        if tag == "TERM_MATCH_OPTION":
            scrutinee = self._may(node["scrutinee"], environment, depth + 1)
            parts = [scrutinee, self._may(node["none_body"], environment, depth + 1)]
            extended = dict(environment)
            extended[node["some_variable"]] = scrutinee
            parts.append(self._may(node["some_body"], extended, depth + 1))
            return self._bounded_may(*parts)
        binary_set = {
            "TERM_SET_INSERT": ("set", "element"),
            "TERM_SET_REMOVE": ("set", "element"),
            "TERM_SET_MEMBER": ("set", "element"),
            "TERM_SET_SUBSET": ("left", "right"),
            "TERM_SET_UNION": ("left", "right"),
            "TERM_SET_DIFFERENCE": ("left", "right"),
            "TERM_MAP_GET": ("map", "key"),
            "TERM_AND": ("operands",),
            "TERM_OR": ("operands",),
            "TERM_IMPLIES": ("left", "right"),
            "TERM_IFF": ("left", "right"),
            "TERM_EQ": ("left", "right"),
            "TERM_QTY_LT": ("left", "right"),
            "TERM_QTY_LE": ("left", "right"),
            "TERM_QTY_GT": ("left", "right"),
            "TERM_QTY_GE": ("left", "right"),
            "TERM_QTY_ADD": ("left", "right"),
            "TERM_QTY_SUB": ("left", "right"),
        }
        if tag in binary_set:
            fields = binary_set[tag]
            if fields == ("operands",):
                terms = node["operands"]
            else:
                terms = [node[field] for field in fields]
            return self._may_union(terms, environment, depth)
        if tag == "TERM_MAP_SET":
            return self._may_union((node["map"], node["key"], node["value"]), environment, depth)
        if tag == "TERM_NOT":
            return self._may(node["operand"], environment, depth + 1)
        if tag == "TERM_IF":
            return self._may_union((node["condition"], node["then"], node["else"]), environment, depth)
        if tag in {"TERM_FORALL", "TERM_EXISTS"}:
            extended = dict(environment)
            extended[node["variable"]] = frozenset()
            return self._may(node["body"], extended, depth + 1)
        if tag in {"TERM_PRE_GET", "TERM_POST_GET"}:
            result = set(self._may(node["key"], environment, depth + 1))
            product = qname(node["state_product"], f"{tag}.state_product")
            product_sorts = self.interpretation.signature.state_products.get(product)
            if product_sorts is None:
                reject("F05-EVAL-MAY-STATE-PRODUCT", repr(product))
            phase = "PRE" if tag == "TERM_PRE_GET" else "POST"
            for key in self.interpretation.enumerate_sort(product_sorts[0], depth + 1):
                dependency = state_dep(phase, product, key)
                if dependency not in result:
                    if len(result) >= self.usage.profile.max_may_dependencies:
                        self.usage.observe_peak("MAY_DEPENDENCIES", len(result) + 1)
                    result.add(dependency)
            return self._bounded_may(result)
        if tag == "TERM_EVENT_GET":
            return self._bounded_may(
                (event_dep(qname(node["event_channel"], "TERM_EVENT_GET.event_channel")),)
            )
        raise RuntimeError(f"MayDeps implementation handler missing for {tag}")

    def _may_union(
        self,
        terms: Any,
        environment: Mapping[str, frozenset[InputDep]],
        depth: int,
    ) -> frozenset[InputDep]:
        result: set[InputDep] = set()
        for term in terms:
            self._extend_may(result, self._may(term, environment, depth + 1))
        self.usage.observe_peak("MAY_DEPENDENCIES", len(result))
        return frozenset(result)

    def _bounded_may(self, *parts: Any) -> frozenset[InputDep]:
        result: set[InputDep] = set()
        for part in parts:
            self._extend_may(result, part)
        self.usage.observe_peak("MAY_DEPENDENCIES", len(result))
        return frozenset(result)

    def _extend_may(self, result: set[InputDep], part: Any) -> None:
        for dependency in part:
            if dependency in result:
                continue
            if len(result) >= self.usage.profile.max_may_dependencies:
                self.usage.observe_peak("MAY_DEPENDENCIES", len(result) + 1)
            result.add(dependency)
