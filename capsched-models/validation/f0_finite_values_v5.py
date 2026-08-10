"""Finite typed values and interpretation wire for DL-F0-5.

These classes implement one construction reference for finite replay. They do
not redefine the denotational carriers and do not establish InstanceWF.
"""

from __future__ import annotations

import itertools
import json
from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Any, Mapping, NoReturn


HARD_MAX_RECURSION_DEPTH = 256


def _plain_json(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _plain_json(child) for key, child in value.items()}
    if isinstance(value, (list, tuple)):
        return [_plain_json(child) for child in value]
    return value


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        _plain_json(value), sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")


def deep_freeze_json(value: Any) -> Any:
    detached = json.loads(canonical_bytes(value).decode("ascii"))

    def freeze(current: Any) -> Any:
        if isinstance(current, dict):
            return MappingProxyType({key: freeze(child) for key, child in current.items()})
        if isinstance(current, list):
            return tuple(freeze(child) for child in current)
        return current

    return freeze(detached)


def qname(value: Any, path: str) -> tuple[str, str]:
    if (
        not isinstance(value, (list, tuple))
        or len(value) != 2
        or not all(isinstance(part, str) and part for part in value)
    ):
        reject("F05-EVAL-QNAME", path)
    return value[0], value[1]


def qwire(value: tuple[str, str]) -> list[str]:
    return [value[0], value[1]]


def exact_object(value: Any, fields: set[str], path: str, tag: str | None = None) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != fields:
        reject("F05-EVAL-VALUE-SHAPE", f"{path}:fields")
    if tag is not None and value.get("tag") != tag:
        reject("F05-EVAL-VALUE-TAG", f"{path}:{value.get('tag')!r}")
    return value


def require_canonical_rows(
    rows: Any,
    key_field: str,
    path: str,
) -> list[Any]:
    if not isinstance(rows, list):
        reject("F05-EVAL-CANONICAL-COLLECTION", f"{path}:not-list")
    keys: list[bytes] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or key_field not in row:
            reject("F05-EVAL-CANONICAL-COLLECTION", f"{path}[{index}].{key_field}")
        keys.append(canonical_bytes(row[key_field]))
    if keys != sorted(keys) or len(keys) != len(set(keys)):
        reject("F05-EVAL-CANONICAL-COLLECTION", path)
    return rows


def bounded_product(factors: Any, cap: int) -> int:
    result = 1
    for factor in factors:
        if type(factor) is not int or factor < 0:
            raise RuntimeError("invalid cardinality factor")
        if factor and result > cap // factor:
            return cap + 1
        result *= factor
    return result


def bounded_power(base: int, exponent: int, cap: int) -> int:
    if type(base) is not int or type(exponent) is not int or base < 0 or exponent < 0:
        raise RuntimeError("invalid cardinality power")
    result = 1
    factor = base
    power = exponent
    while power:
        if power & 1:
            if factor and result > cap // factor:
                return cap + 1
            result *= factor
        power >>= 1
        if power:
            if factor and factor > cap // factor:
                factor = cap + 1
            else:
                factor *= factor
            if factor > cap:
                factor = cap + 1
    return result


class Reject(RuntimeError):
    def __init__(self, reject_id: str, detail: str) -> None:
        super().__init__(f"{reject_id}: {detail}")
        self.reject_id = reject_id
        self.detail = detail


class Inconclusive(RuntimeError):
    def __init__(self, reason_id: str, detail: str) -> None:
        super().__init__(f"{reason_id}: {detail}")
        self.reason_id = reason_id
        self.detail = detail


def reject(reject_id: str, detail: str) -> NoReturn:
    raise Reject(reject_id, detail)


def inconclusive(reason_id: str, detail: str) -> NoReturn:
    raise Inconclusive(reason_id, detail)


@dataclass(frozen=True)
class ResourceProfile:
    max_term_visits: int = 1_000_000
    max_may_term_visits: int = 1_000_000
    max_recursion_depth: int = HARD_MAX_RECURSION_DEPTH
    max_carrier_values: int = 1_000_000
    max_quantifier_iterations: int = 1_000_000
    max_ground_value_nodes: int = 2_000_000
    max_totalmap_entries: int = 1_000_000
    max_access_trace_entries: int = 2_000_000
    max_may_dependencies: int = 2_000_000
    max_interpretation_ref_visits: int = 1_000_000
    max_interpretation_refs: int = 1_000_000

    def __post_init__(self) -> None:
        for name, value in self.__dict__.items():
            if type(value) is not int or value <= 0:
                raise ValueError(f"{name} must be a positive exact integer")
        if self.max_recursion_depth > HARD_MAX_RECURSION_DEPTH:
            raise ValueError(
                f"max_recursion_depth exceeds hard executable limit {HARD_MAX_RECURSION_DEPTH}"
            )

    def as_dict(self) -> dict[str, int]:
        return dict(self.__dict__)


@dataclass
class ResourceUsage:
    profile: ResourceProfile
    term_visits: int = 0
    may_term_visits: int = 0
    peak_recursion_depth: int = 0
    carrier_values: int = 0
    quantifier_iterations: int = 0
    ground_value_nodes: int = 0
    totalmap_entries: int = 0
    access_trace_entries: int = 0
    may_dependencies: int = 0
    interpretation_ref_visits: int = 0
    interpretation_refs: int = 0

    def charge(self, coordinate: str, amount: int = 1) -> None:
        if type(amount) is not int or amount < 0:
            raise RuntimeError("invalid resource charge")
        field_name = coordinate.lower()
        current = getattr(self, field_name) + amount
        limit = getattr(self.profile, f"max_{field_name}")
        if current > limit:
            inconclusive("F05-EVAL-INCONCLUSIVE-RESOURCE", f"{coordinate}:{current}>{limit}")
        setattr(self, field_name, current)

    def enter_depth(self, depth: int) -> None:
        if depth > self.profile.max_recursion_depth:
            inconclusive(
                "F05-EVAL-INCONCLUSIVE-RESOURCE",
                f"RECURSION_DEPTH:{depth}>{self.profile.max_recursion_depth}",
            )
        self.peak_recursion_depth = max(self.peak_recursion_depth, depth)

    def observe_peak(self, coordinate: str, value: int) -> None:
        if type(value) is not int or value < 0:
            raise RuntimeError("invalid resource peak")
        field_name = coordinate.lower()
        limit = getattr(self.profile, f"max_{field_name}")
        if value > limit:
            inconclusive("F05-EVAL-INCONCLUSIVE-RESOURCE", f"{coordinate}:{value}>{limit}")
        setattr(self, field_name, max(getattr(self, field_name), value))

    def as_dict(self) -> dict[str, int]:
        return {
            "term_visits": self.term_visits,
            "may_term_visits": self.may_term_visits,
            "peak_recursion_depth": self.peak_recursion_depth,
            "carrier_values": self.carrier_values,
            "quantifier_iterations": self.quantifier_iterations,
            "ground_value_nodes": self.ground_value_nodes,
            "totalmap_entries": self.totalmap_entries,
            "access_trace_entries": self.access_trace_entries,
            "may_dependencies": self.may_dependencies,
            "interpretation_ref_visits": self.interpretation_ref_visits,
            "interpretation_refs": self.interpretation_refs,
        }


@dataclass(frozen=True)
class InterpretationRef:
    kind: str
    subject: tuple[str, ...]

    def __post_init__(self) -> None:
        lengths = {
            "DECLARATION": 3,
            "ATOM_CARRIER": 2,
            "LIMIT_VALUE": 2,
            "CONSTANT_VALUE": 2,
            "ARITHMETIC_BINDING": 6,
        }
        if self.kind not in lengths or len(self.subject) != lengths[self.kind]:
            raise ValueError(f"invalid interpretation reference {self.kind}")
        if not all(isinstance(part, str) and part for part in self.subject):
            raise ValueError("interpretation reference subjects must be nonempty strings")

    def as_dict(self) -> dict[str, Any]:
        return {"kind": self.kind, "subject": list(self.subject)}


def declaration_ref(declaration_tag: str, name: tuple[str, str]) -> InterpretationRef:
    return InterpretationRef("DECLARATION", (declaration_tag, name[0], name[1]))


def atom_carrier_ref(name: tuple[str, str]) -> InterpretationRef:
    return InterpretationRef("ATOM_CARRIER", name)


def limit_value_ref(name: tuple[str, str]) -> InterpretationRef:
    return InterpretationRef("LIMIT_VALUE", name)


def constant_value_ref(name: tuple[str, str]) -> InterpretationRef:
    return InterpretationRef("CONSTANT_VALUE", name)


def arithmetic_binding_ref(
    unit: tuple[str, str],
    limit: tuple[str, str],
    result_variant: tuple[str, str],
) -> InterpretationRef:
    return InterpretationRef(
        "ARITHMETIC_BINDING",
        unit + limit + result_variant,
    )


@dataclass(frozen=True)
class Value:
    sort_raw: bytes
    constructor: str
    payload: tuple[Any, ...]

    @property
    def sort(self) -> dict[str, Any]:
        value = json.loads(self.sort_raw.decode("ascii"))
        if not isinstance(value, dict):
            raise RuntimeError("invalid frozen sort")
        return value

    def require_sort(self, expected: dict[str, Any], path: str) -> None:
        if self.sort_raw != canonical_bytes(expected):
            reject("F05-EVAL-VALUE-SORT", path)
        allowed = {
            "SORT_BOOL": {"VALUE_BOOL"},
            "SORT_ONE": {"VALUE_ONE"},
            "SORT_ATOM": {"VALUE_ATOM"},
            "SORT_ENUM": {"VALUE_ENUM"},
            "SORT_QTY": {"VALUE_QTY"},
            "SORT_RECORD": {"VALUE_RECORD"},
            "SORT_VARIANT": {"VALUE_VARIANT"},
            "SORT_OPTION": {"VALUE_NONE", "VALUE_SOME"},
            "SORT_FINSET": {"VALUE_FINSET"},
            "SORT_TOTALMAP": {"VALUE_TOTALMAP"},
        }.get(expected.get("tag"))
        if allowed is None or self.constructor not in allowed:
            reject(
                "F05-EVAL-VALUE-CONSTRUCTOR-SORT",
                f"{path}:{self.constructor}:{expected.get('tag')}",
            )


def make_value(sort: dict[str, Any], constructor: str, *payload: Any) -> Value:
    return Value(canonical_bytes(sort), constructor, tuple(payload))


def value_wire(value: Value) -> dict[str, Any]:
    sort = value.sort
    tag = value.constructor
    payload = value.payload
    if tag == "VALUE_BOOL":
        return {"tag": tag, "value": payload[0]}
    if tag == "VALUE_ONE":
        return {"tag": tag}
    if tag == "VALUE_ATOM":
        return {"tag": tag, "atom": qwire(payload[0]), "value": payload[1]}
    if tag == "VALUE_ENUM":
        return {"tag": tag, "enum": qwire(payload[0]), "member": payload[1]}
    if tag == "VALUE_QTY":
        return {
            "tag": tag,
            "unit": qwire(payload[0]),
            "limit": qwire(payload[1]),
            "value": payload[2],
        }
    if tag == "VALUE_RECORD":
        return {
            "tag": tag,
            "record": qwire(payload[0]),
            "values": [
                {"tag": "GROUND_FIELD_ENTRY", "field": name, "value": value_wire(item)}
                for name, item in payload[1]
            ],
        }
    if tag == "VALUE_VARIANT":
        return {
            "tag": tag,
            "variant": qwire(payload[0]),
            "variant_tag": payload[1],
            "payload": value_wire(payload[2]),
        }
    if tag == "VALUE_NONE":
        return {"tag": tag, "element_sort": sort["element"]}
    if tag == "VALUE_SOME":
        return {"tag": tag, "element_sort": sort["element"], "value": value_wire(payload[0])}
    if tag == "VALUE_FINSET":
        items = sorted((value_wire(item) for item in payload[0]), key=canonical_bytes)
        return {"tag": tag, "element_sort": sort["element"], "values": items}
    if tag == "VALUE_TOTALMAP":
        entries = [
            {"tag": "GROUND_MAP_ENTRY", "key": value_wire(key), "value": value_wire(item)}
            for key, item in payload[0]
        ]
        entries.sort(key=lambda entry: canonical_bytes(entry["key"]))
        return {
            "tag": tag,
            "key_sort": sort["key"],
            "value_sort": sort["value"],
            "entries": entries,
        }
    raise RuntimeError(f"unknown Value constructor {tag}")


def value_order_key(value: Value) -> bytes:
    return canonical_bytes(value_wire(value))


@dataclass(frozen=True)
class SignatureIndex:
    declarations: Mapping[tuple[str, str], tuple[str, Mapping[str, Any]]]
    state_products: Mapping[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]]
    event_channels: Mapping[tuple[str, str], dict[str, Any]]
    arithmetic_bindings: Mapping[bytes, tuple[str, str]]
    constant_constraints: tuple[Mapping[str, Any], ...]

    @classmethod
    def from_linked_model(cls, linked: Mapping[str, Any]) -> "SignatureIndex":
        linked_snapshot = json.loads(canonical_bytes(linked).decode("ascii"))
        sigma = linked_snapshot.get("sigma")
        if not isinstance(sigma, dict):
            reject("F05-EVAL-LINKED-SIGMA", "missing sigma")
        declarations: dict[tuple[str, str], tuple[str, Mapping[str, Any]]] = {}
        for index, row in enumerate(sigma.get("declaration_signatures", [])):
            if not isinstance(row, dict):
                reject("F05-EVAL-LINKED-SIGMA", f"declaration_signatures[{index}]")
            tag = row.get("declaration_tag")
            signature = row.get("signature")
            if not isinstance(tag, str) or not isinstance(signature, dict):
                reject("F05-EVAL-LINKED-SIGMA", f"declaration_signatures[{index}]")
            name_value = signature.get("name")
            if name_value is None:
                continue
            name = qname(name_value, f"declaration_signatures[{index}].signature.name")
            if name in declarations:
                reject("F05-EVAL-LINKED-DUPLICATE", repr(name))
            frozen_signature = deep_freeze_json(signature)
            if not isinstance(frozen_signature, Mapping):
                raise TypeError("frozen declaration signature expected")
            declarations[name] = (tag, frozen_signature)

        state_products: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}
        for index, row in enumerate(sigma.get("state_product_carriers", [])):
            name = qname(row.get("name"), f"state_product_carriers[{index}].name")
            if name in state_products:
                reject("F05-EVAL-LINKED-DUPLICATE-STATE-PRODUCT", repr(name))
            state_products[name] = (
                deep_freeze_json(row["key_sort"]),
                deep_freeze_json(row["value_sort"]),
            )
        event_channels: dict[tuple[str, str], dict[str, Any]] = {}
        for index, row in enumerate(sigma.get("event_channel_carriers", [])):
            name = qname(row.get("name"), f"event_channel_carriers[{index}].name")
            if name in event_channels:
                reject("F05-EVAL-LINKED-DUPLICATE-EVENT-CHANNEL", repr(name))
            event_channels[name] = deep_freeze_json(row["payload_sort"])
        arithmetic: dict[bytes, tuple[str, str]] = {}
        for index, row in enumerate(sigma.get("arithmetic_bindings", [])):
            key = canonical_bytes(row["quantity_sort"])
            if key in arithmetic:
                reject("F05-EVAL-ARITH-DUPLICATE", str(index))
            arithmetic[key] = qname(row["result_variant"], f"arithmetic_bindings[{index}].result_variant")
        constraints = tuple(deep_freeze_json(row["constraint"]) for row in sigma.get("constant_constraints", []))
        return cls(
            declarations=MappingProxyType(declarations),
            state_products=MappingProxyType(state_products),
            event_channels=MappingProxyType(event_channels),
            arithmetic_bindings=MappingProxyType(arithmetic),
            constant_constraints=constraints,
        )

    def declaration(self, name: tuple[str, str], expected_tag: str, path: str) -> Mapping[str, Any]:
        found = self.declarations.get(name)
        if found is None or found[0] != expected_tag:
            reject("F05-EVAL-DECLARATION", f"{path}:{name}:{expected_tag}")
        return found[1]


@dataclass(frozen=True)
class FiniteInterpretation:
    interpretation_id: tuple[str, str]
    model_sha256: str
    signature: SignatureIndex
    atom_carriers: Mapping[tuple[str, str], tuple[Value, ...]]
    limits: Mapping[tuple[str, str], int]
    constants: Mapping[tuple[str, str], Value]
    usage: ResourceUsage
    _carrier_cache: dict[bytes, tuple[Value, ...]] = field(default_factory=dict)
    _carrier_ref_cache: dict[bytes, frozenset[InterpretationRef]] = field(default_factory=dict)

    def fork_request(
        self,
        resource_profile: ResourceProfile | None = None,
    ) -> "FiniteInterpretation":
        """Create one isolated executable request session.

        Signature values are immutable and shared. Resource usage and carrier
        memoization are exact per-request state and are never shared.
        """

        return FiniteInterpretation(
            interpretation_id=self.interpretation_id,
            model_sha256=self.model_sha256,
            signature=self.signature,
            atom_carriers=self.atom_carriers,
            limits=self.limits,
            constants=self.constants,
            usage=ResourceUsage(resource_profile or self.usage.profile),
            _carrier_cache={},
            _carrier_ref_cache={},
        )

    @classmethod
    def decode(
        cls,
        linked_artifact: Mapping[str, Any],
        profile: Mapping[str, Any],
        resource_profile: ResourceProfile | None = None,
    ) -> "FiniteInterpretation":
        exact_object(
            profile,
            {"tag", "interpretation_id", "model_sha256", "atom_carriers", "limits", "constants"},
            "$profile",
            "FINITE_PROFILE",
        )
        source_binding = linked_artifact.get("source_binding")
        linked = linked_artifact.get("linked_model")
        if not isinstance(source_binding, dict) or not isinstance(linked, dict):
            reject("F05-EVAL-LINKED-ARTIFACT", "source_binding/linked_model")
        model_sha256 = profile["model_sha256"]
        if model_sha256 != source_binding.get("canonical_model_sha256"):
            reject("F05-EVAL-PROFILE-MODEL", str(model_sha256))
        usage = ResourceUsage(resource_profile or ResourceProfile())
        signature = SignatureIndex.from_linked_model(linked)

        atom_declarations = {
            name for name, (tag, _) in signature.declarations.items() if tag == "DECL_ATOM"
        }
        atom_carriers: dict[tuple[str, str], tuple[Value, ...]] = {}
        atom_rows = require_canonical_rows(profile["atom_carriers"], "atom", "$profile.atom_carriers")
        for index, carrier in enumerate(atom_rows):
            exact_object(carrier, {"tag", "atom", "values"}, f"$profile.atom_carriers[{index}]", "ATOM_CARRIER")
            name = qname(carrier["atom"], f"$profile.atom_carriers[{index}].atom")
            signature.declaration(name, "DECL_ATOM", f"$profile.atom_carriers[{index}]")
            if name in atom_carriers:
                reject("F05-EVAL-PROFILE-ATOM-DUPLICATE", repr(name))
            values: list[Value] = []
            seen: set[str] = set()
            value_rows = require_canonical_rows(
                carrier["values"], "value", f"$profile.atom_carriers[{index}].values"
            )
            for value_index, raw_value in enumerate(value_rows):
                exact_object(raw_value, {"tag", "atom", "value"}, f"$profile.atom_carriers[{index}].values[{value_index}]", "ATOM_VALUE")
                if qname(raw_value["atom"], "ATOM_VALUE.atom") != name:
                    reject("F05-EVAL-PROFILE-ATOM-NOMINAL", repr(name))
                local = raw_value["value"]
                if not isinstance(local, str) or not local or local in seen:
                    reject("F05-EVAL-PROFILE-ATOM-VALUE", repr(local))
                seen.add(local)
                values.append(make_value({"tag": "SORT_ATOM", "atom": qwire(name)}, "VALUE_ATOM", name, local))
            if not values:
                reject("F05-EVAL-PROFILE-ATOM-EMPTY", repr(name))
            values.sort(key=lambda value: value.payload[1])
            atom_carriers[name] = tuple(values)
        if set(atom_carriers) != atom_declarations:
            reject("F05-EVAL-PROFILE-ATOM-DOMAIN", "not exact")

        limit_declarations = {
            name for name, (tag, _) in signature.declarations.items() if tag == "DECL_LIMIT"
        }
        limits: dict[tuple[str, str], int] = {}
        limit_rows = require_canonical_rows(profile["limits"], "limit", "$profile.limits")
        for index, row in enumerate(limit_rows):
            exact_object(row, {"tag", "limit", "value"}, f"$profile.limits[{index}]", "LIMIT_VALUE")
            name = qname(row["limit"], f"$profile.limits[{index}].limit")
            signature.declaration(name, "DECL_LIMIT", f"$profile.limits[{index}]")
            value = row["value"]
            if type(value) is not int or value < 0 or name in limits:
                reject("F05-EVAL-PROFILE-LIMIT", repr(name))
            limits[name] = value
        if set(limits) != limit_declarations:
            reject("F05-EVAL-PROFILE-LIMIT-DOMAIN", "not exact")

        instance = cls(
            interpretation_id=qname(profile["interpretation_id"], "$profile.interpretation_id"),
            model_sha256=model_sha256,
            signature=signature,
            atom_carriers=MappingProxyType(atom_carriers),
            limits=MappingProxyType(limits),
            constants=MappingProxyType({}),
            usage=usage,
        )
        constant_declarations = {
            name: signature_row["sort"]
            for name, (tag, signature_row) in signature.declarations.items()
            if tag == "DECL_CONSTANT"
        }
        constants: dict[tuple[str, str], Value] = {}
        constant_rows = require_canonical_rows(
            profile["constants"], "constant", "$profile.constants"
        )
        for index, row in enumerate(constant_rows):
            exact_object(row, {"tag", "constant", "value"}, f"$profile.constants[{index}]", "CONSTANT_VALUE")
            name = qname(row["constant"], f"$profile.constants[{index}].constant")
            expected_sort = constant_declarations.get(name)
            if expected_sort is None or name in constants:
                reject("F05-EVAL-PROFILE-CONSTANT", repr(name))
            constants[name] = instance.decode_value(row["value"], expected_sort, f"$profile.constants[{index}].value")
        if set(constants) != set(constant_declarations):
            reject("F05-EVAL-PROFILE-CONSTANT-DOMAIN", "not exact")
        object.__setattr__(instance, "constants", MappingProxyType(constants))
        instance._check_constant_constraints()
        return instance

    def _check_constant_constraints(self) -> None:
        for index, constraint in enumerate(self.signature.constant_constraints):
            exact_object(dict(constraint), {"tag", "relation", "left", "right"}, f"constraint[{index}]", "CONSTANT_CONSTRAINT")
            left = self.constants.get(qname(constraint["left"], f"constraint[{index}].left"))
            right = self.constants.get(qname(constraint["right"], f"constraint[{index}].right"))
            if left is None or right is None or left.sort_raw != right.sort_raw:
                reject("F05-EVAL-CONSTRAINT-SORT", str(index))
            relation = constraint["relation"]
            satisfied = left == right if relation == "EQ" else left != right if relation == "NEQ" else None
            if satisfied is not True:
                reject("F05-EVAL-CONSTRAINT-FALSE", str(index))

    def decode_value(self, raw: Any, expected_sort: dict[str, Any], path: str, depth: int = 0) -> Value:
        self.usage.enter_depth(depth)
        self.usage.charge("GROUND_VALUE_NODES")
        if not isinstance(raw, dict) or not isinstance(raw.get("tag"), str):
            reject("F05-EVAL-GROUND-SHAPE", path)
        sort_tag = expected_sort.get("tag")
        value_tag = raw["tag"]
        if sort_tag == "SORT_BOOL":
            exact_object(raw, {"tag", "value"}, path, "VALUE_BOOL")
            if type(raw["value"]) is not bool:
                reject("F05-EVAL-GROUND-BOOL", path)
            return make_value(expected_sort, value_tag, raw["value"])
        if sort_tag == "SORT_ONE":
            exact_object(raw, {"tag"}, path, "VALUE_ONE")
            return make_value(expected_sort, value_tag)
        if sort_tag == "SORT_ATOM":
            exact_object(raw, {"tag", "atom", "value"}, path, "VALUE_ATOM")
            name = qname(expected_sort["atom"], f"{path}.sort.atom")
            if qname(raw["atom"], f"{path}.atom") != name:
                reject("F05-EVAL-GROUND-ATOM-NOMINAL", path)
            local = raw["value"]
            carrier = self.atom_carriers.get(name)
            if not isinstance(local, str) or carrier is None or local not in {value.payload[1] for value in carrier}:
                reject("F05-EVAL-GROUND-ATOM-MEMBER", path)
            return make_value(expected_sort, value_tag, name, local)
        if sort_tag == "SORT_ENUM":
            exact_object(raw, {"tag", "enum", "member"}, path, "VALUE_ENUM")
            name = qname(expected_sort["enum"], f"{path}.sort.enum")
            if qname(raw["enum"], f"{path}.enum") != name:
                reject("F05-EVAL-GROUND-ENUM-NOMINAL", path)
            declaration = self.signature.declaration(name, "DECL_ENUM", path)
            member = raw["member"]
            if member not in declaration["members"]:
                reject("F05-EVAL-GROUND-ENUM-MEMBER", path)
            return make_value(expected_sort, value_tag, name, member)
        if sort_tag == "SORT_QTY":
            exact_object(raw, {"tag", "unit", "limit", "value"}, path, "VALUE_QTY")
            unit = qname(expected_sort["unit"], f"{path}.sort.unit")
            limit = qname(expected_sort["limit"], f"{path}.sort.limit")
            self.signature.declaration(unit, "DECL_UNIT", path)
            self.signature.declaration(limit, "DECL_LIMIT", path)
            if qname(raw["unit"], f"{path}.unit") != unit or qname(raw["limit"], f"{path}.limit") != limit:
                reject("F05-EVAL-GROUND-QTY-NOMINAL", path)
            amount = raw["value"]
            if type(amount) is not int or amount < 0 or amount > self.limits[limit]:
                reject("F05-EVAL-GROUND-QTY-BOUND", path)
            return make_value(expected_sort, value_tag, unit, limit, amount)
        if sort_tag == "SORT_RECORD":
            exact_object(raw, {"tag", "record", "values"}, path, "VALUE_RECORD")
            name = qname(expected_sort["record"], f"{path}.sort.record")
            if qname(raw["record"], f"{path}.record") != name:
                reject("F05-EVAL-GROUND-RECORD-NOMINAL", path)
            declaration = self.signature.declaration(name, "DECL_RECORD", path)
            expected_fields = {row["field"]: row["sort"] for row in declaration["fields"]}
            decoded: dict[str, Value] = {}
            for index, entry in enumerate(raw["values"]):
                exact_object(entry, {"tag", "field", "value"}, f"{path}.values[{index}]", "GROUND_FIELD_ENTRY")
                field_name = entry["field"]
                if field_name not in expected_fields or field_name in decoded:
                    reject("F05-EVAL-GROUND-RECORD-FIELD", f"{path}:{field_name}")
                decoded[field_name] = self.decode_value(entry["value"], expected_fields[field_name], f"{path}.values[{index}].value", depth + 1)
            if set(decoded) != set(expected_fields):
                reject("F05-EVAL-GROUND-RECORD-DOMAIN", path)
            return make_value(expected_sort, value_tag, name, tuple(sorted(decoded.items())))
        if sort_tag == "SORT_VARIANT":
            exact_object(raw, {"tag", "variant", "variant_tag", "payload"}, path, "VALUE_VARIANT")
            name = qname(expected_sort["variant"], f"{path}.sort.variant")
            if qname(raw["variant"], f"{path}.variant") != name:
                reject("F05-EVAL-GROUND-VARIANT-NOMINAL", path)
            declaration = self.signature.declaration(name, "DECL_VARIANT", path)
            tags = {row["variant_tag"]: row["payload_sort"] for row in declaration["variant_tags"]}
            selected = raw["variant_tag"]
            if selected not in tags:
                reject("F05-EVAL-GROUND-VARIANT-TAG", path)
            payload = self.decode_value(raw["payload"], tags[selected], f"{path}.payload", depth + 1)
            return make_value(expected_sort, value_tag, name, selected, payload)
        if sort_tag == "SORT_OPTION":
            if value_tag == "VALUE_NONE":
                exact_object(raw, {"tag", "element_sort"}, path, "VALUE_NONE")
                if canonical_bytes(raw["element_sort"]) != canonical_bytes(expected_sort["element"]):
                    reject("F05-EVAL-GROUND-OPTION-SORT", path)
                return make_value(expected_sort, value_tag)
            exact_object(raw, {"tag", "element_sort", "value"}, path, "VALUE_SOME")
            if canonical_bytes(raw["element_sort"]) != canonical_bytes(expected_sort["element"]):
                reject("F05-EVAL-GROUND-OPTION-SORT", path)
            payload = self.decode_value(raw["value"], expected_sort["element"], f"{path}.value", depth + 1)
            return make_value(expected_sort, value_tag, payload)
        if sort_tag == "SORT_FINSET":
            exact_object(raw, {"tag", "element_sort", "values"}, path, "VALUE_FINSET")
            if canonical_bytes(raw["element_sort"]) != canonical_bytes(expected_sort["element"]):
                reject("F05-EVAL-GROUND-FINSET-SORT", path)
            items: list[Value] = []
            seen: set[Value] = set()
            raw_keys: list[bytes] = []
            for index, item in enumerate(raw["values"]):
                raw_keys.append(canonical_bytes(item))
                decoded = self.decode_value(item, expected_sort["element"], f"{path}.values[{index}]", depth + 1)
                if decoded in seen:
                    reject("F05-EVAL-GROUND-FINSET-DUPLICATE", path)
                seen.add(decoded)
                items.append(decoded)
            if raw_keys != sorted(raw_keys) or len(set(raw_keys)) != len(raw_keys):
                reject("F05-EVAL-GROUND-FINSET-CANONICAL", path)
            return make_value(expected_sort, value_tag, tuple(sorted(items, key=value_order_key)))
        if sort_tag == "SORT_TOTALMAP":
            exact_object(raw, {"tag", "key_sort", "value_sort", "entries"}, path, "VALUE_TOTALMAP")
            if canonical_bytes(raw["key_sort"]) != canonical_bytes(expected_sort["key"]) or canonical_bytes(raw["value_sort"]) != canonical_bytes(expected_sort["value"]):
                reject("F05-EVAL-GROUND-TOTALMAP-SORT", path)
            provided: dict[Value, Value] = {}
            raw_keys: list[bytes] = []
            for index, entry in enumerate(raw["entries"]):
                self.usage.charge("TOTALMAP_ENTRIES")
                exact_object(entry, {"tag", "key", "value"}, f"{path}.entries[{index}]", "GROUND_MAP_ENTRY")
                raw_keys.append(canonical_bytes(entry["key"]))
                key = self.decode_value(entry["key"], expected_sort["key"], f"{path}.entries[{index}].key", depth + 1)
                if key in provided:
                    reject("F05-EVAL-GROUND-TOTALMAP-DUPLICATE", path)
                provided[key] = self.decode_value(entry["value"], expected_sort["value"], f"{path}.entries[{index}].value", depth + 1)
            if raw_keys != sorted(raw_keys) or len(set(raw_keys)) != len(raw_keys):
                reject("F05-EVAL-GROUND-TOTALMAP-CANONICAL", path)
            expected_keys = self.enumerate_sort(expected_sort["key"], depth + 1)
            if set(provided) != set(expected_keys):
                reject("F05-EVAL-GROUND-TOTALMAP-DOMAIN", path)
            return make_value(expected_sort, value_tag, tuple((key, provided[key]) for key in expected_keys))
        reject("F05-EVAL-GROUND-SORT", f"{path}:{sort_tag}")

    def enumerate_sort(self, sort: dict[str, Any], depth: int = 0) -> tuple[Value, ...]:
        self.usage.enter_depth(depth)
        key = canonical_bytes(sort)
        cached = self._carrier_cache.get(key)
        if cached is not None:
            return cached
        tag = sort.get("tag")
        values: list[Value] = []
        cardinality = 0
        if tag == "SORT_BOOL":
            cardinality = 2
            constructors = (
                make_value(sort, "VALUE_BOOL", False),
                make_value(sort, "VALUE_BOOL", True),
            )
        elif tag == "SORT_ONE":
            cardinality = 1
            constructors = (make_value(sort, "VALUE_ONE"),)
        elif tag == "SORT_ATOM":
            name = qname(sort["atom"], "enumerate.atom")
            self.signature.declaration(name, "DECL_ATOM", "enumerate.atom")
            constructors = self.atom_carriers[name]
            cardinality = len(constructors)
        elif tag == "SORT_ENUM":
            name = qname(sort["enum"], "enumerate.enum")
            declaration = self.signature.declaration(name, "DECL_ENUM", "enumerate.enum")
            members = tuple(sorted(declaration["members"]))
            cardinality = len(members)
            constructors = (
                make_value(sort, "VALUE_ENUM", name, member) for member in members
            )
        elif tag == "SORT_QTY":
            unit = qname(sort["unit"], "enumerate.qty.unit")
            limit = qname(sort["limit"], "enumerate.qty.limit")
            self.signature.declaration(unit, "DECL_UNIT", "enumerate.qty")
            self.signature.declaration(limit, "DECL_LIMIT", "enumerate.qty")
            cardinality = self.limits[limit] + 1
            constructors = (
                make_value(sort, "VALUE_QTY", unit, limit, amount)
                for amount in range(cardinality)
            )
        elif tag == "SORT_RECORD":
            name = qname(sort["record"], "enumerate.record")
            declaration = self.signature.declaration(name, "DECL_RECORD", "enumerate.record")
            fields = sorted((row["field"], row["sort"]) for row in declaration["fields"])
            carriers = [self.enumerate_sort(field_sort, depth + 1) for _, field_sort in fields]
            remaining = self.usage.profile.max_carrier_values - self.usage.carrier_values
            cardinality = bounded_product((len(carrier) for carrier in carriers), remaining)
            constructors = (
                make_value(
                    sort,
                    "VALUE_RECORD",
                    name,
                    tuple((fields[index][0], item) for index, item in enumerate(product)),
                )
                for product in itertools.product(*carriers)
            )
        elif tag == "SORT_VARIANT":
            name = qname(sort["variant"], "enumerate.variant")
            declaration = self.signature.declaration(name, "DECL_VARIANT", "enumerate.variant")
            members = [
                (row["variant_tag"], self.enumerate_sort(row["payload_sort"], depth + 1))
                for row in sorted(declaration["variant_tags"], key=lambda entry: entry["variant_tag"])
            ]
            cardinality = sum(len(carrier) for _, carrier in members)
            constructors = (
                make_value(sort, "VALUE_VARIANT", name, variant_tag, payload)
                for variant_tag, carrier in members
                for payload in carrier
            )
        elif tag == "SORT_OPTION":
            elements = self.enumerate_sort(sort["element"], depth + 1)
            cardinality = 1 + len(elements)
            constructors = itertools.chain(
                (make_value(sort, "VALUE_NONE"),),
                (make_value(sort, "VALUE_SOME", item) for item in elements),
            )
        elif tag == "SORT_FINSET":
            elements = self.enumerate_sort(sort["element"], depth + 1)
            remaining = self.usage.profile.max_carrier_values - self.usage.carrier_values
            cardinality = bounded_power(2, len(elements), remaining)
            constructors = (
                make_value(sort, "VALUE_FINSET", subset)
                for size in range(len(elements) + 1)
                for subset in itertools.combinations(elements, size)
            )
        elif tag == "SORT_TOTALMAP":
            keys = self.enumerate_sort(sort["key"], depth + 1)
            outputs = self.enumerate_sort(sort["value"], depth + 1)
            remaining = self.usage.profile.max_carrier_values - self.usage.carrier_values
            cardinality = bounded_power(len(outputs), len(keys), remaining)
            constructors = (
                make_value(
                    sort,
                    "VALUE_TOTALMAP",
                    tuple(zip(keys, assignment, strict=True)),
                )
                for assignment in itertools.product(outputs, repeat=len(keys))
            )
        else:
            reject("F05-EVAL-ENUM-SORT", repr(tag))
        self.usage.charge("CARRIER_VALUES", cardinality)
        values.extend(constructors)
        if len(values) != cardinality:
            raise RuntimeError(f"carrier cardinality drift for {tag}")
        frozen = tuple(values)
        self._carrier_cache[key] = frozen
        return frozen

    def carrier_refs(
        self,
        sort: Mapping[str, Any],
        depth: int = 0,
    ) -> frozenset[InterpretationRef]:
        self.usage.enter_depth(depth)
        self.usage.charge("INTERPRETATION_REF_VISITS")
        key = canonical_bytes(sort)
        cached = self._carrier_ref_cache.get(key)
        if cached is not None:
            return cached
        tag = sort.get("tag")
        refs: set[InterpretationRef] = set()
        if tag in {"SORT_BOOL", "SORT_ONE"}:
            pass
        elif tag == "SORT_ATOM":
            name = qname(sort["atom"], "carrier_refs.atom")
            self.signature.declaration(name, "DECL_ATOM", "carrier_refs.atom")
            refs.update({declaration_ref("DECL_ATOM", name), atom_carrier_ref(name)})
        elif tag == "SORT_ENUM":
            name = qname(sort["enum"], "carrier_refs.enum")
            self.signature.declaration(name, "DECL_ENUM", "carrier_refs.enum")
            refs.add(declaration_ref("DECL_ENUM", name))
        elif tag == "SORT_QTY":
            unit = qname(sort["unit"], "carrier_refs.qty.unit")
            limit = qname(sort["limit"], "carrier_refs.qty.limit")
            self.signature.declaration(unit, "DECL_UNIT", "carrier_refs.qty")
            self.signature.declaration(limit, "DECL_LIMIT", "carrier_refs.qty")
            if limit not in self.limits:
                reject("F05-EVAL-CARRIER-REF-LIMIT", repr(limit))
            refs.update(
                {
                    declaration_ref("DECL_UNIT", unit),
                    declaration_ref("DECL_LIMIT", limit),
                    limit_value_ref(limit),
                }
            )
        elif tag == "SORT_RECORD":
            name = qname(sort["record"], "carrier_refs.record")
            declaration = self.signature.declaration(name, "DECL_RECORD", "carrier_refs.record")
            refs.add(declaration_ref("DECL_RECORD", name))
            for row in declaration["fields"]:
                refs.update(self.carrier_refs(row["sort"], depth + 1))
        elif tag == "SORT_VARIANT":
            name = qname(sort["variant"], "carrier_refs.variant")
            declaration = self.signature.declaration(name, "DECL_VARIANT", "carrier_refs.variant")
            refs.add(declaration_ref("DECL_VARIANT", name))
            for row in declaration["variant_tags"]:
                refs.update(self.carrier_refs(row["payload_sort"], depth + 1))
        elif tag in {"SORT_OPTION", "SORT_FINSET"}:
            refs.update(self.carrier_refs(sort["element"], depth + 1))
        elif tag == "SORT_TOTALMAP":
            refs.update(self.carrier_refs(sort["key"], depth + 1))
            refs.update(self.carrier_refs(sort["value"], depth + 1))
        else:
            reject("F05-EVAL-CARRIER-REF-SORT", repr(tag))
        self.usage.observe_peak("INTERPRETATION_REFS", len(refs))
        frozen = frozenset(refs)
        self._carrier_ref_cache[key] = frozen
        return frozen

    def arithmetic_result_variant(self, quantity_sort: dict[str, Any]) -> tuple[str, str]:
        result = self.signature.arithmetic_bindings.get(canonical_bytes(quantity_sort))
        if result is None:
            reject("F05-EVAL-ARITH-BINDING", canonical_bytes(quantity_sort).decode("ascii"))
        return result


@dataclass(frozen=True)
class StateView:
    cells: Mapping[tuple[str, str], Mapping[Value, Value]]

    @classmethod
    def decode(cls, raw: Mapping[str, Any], interpretation: FiniteInterpretation) -> "StateView":
        exact_object(raw, {"tag", "cells"}, "$state", "STATE_VALUE")
        cells: dict[tuple[str, str], dict[Value, Value]] = {
            name: {} for name in interpretation.signature.state_products
        }
        rows = require_canonical_rows(raw["cells"], "location", "$state.cells")
        for index, cell in enumerate(rows):
            exact_object(cell, {"tag", "location", "value"}, f"$state.cells[{index}]", "CELL_VALUE")
            location = exact_object(cell["location"], {"tag", "state_product", "key"}, f"$state.cells[{index}].location", "LOCATION_VALUE")
            product = qname(location["state_product"], f"$state.cells[{index}].location.state_product")
            sorts = interpretation.signature.state_products.get(product)
            if sorts is None:
                reject("F05-EVAL-STATE-PRODUCT", repr(product))
            key = interpretation.decode_value(location["key"], sorts[0], f"$state.cells[{index}].location.key")
            if key in cells[product]:
                reject("F05-EVAL-STATE-DUPLICATE", repr(product))
            cells[product][key] = interpretation.decode_value(cell["value"], sorts[1], f"$state.cells[{index}].value")
        for product, (key_sort, _) in interpretation.signature.state_products.items():
            if set(cells[product]) != set(interpretation.enumerate_sort(key_sort)):
                reject("F05-EVAL-STATE-DOMAIN", repr(product))
        return cls(
            MappingProxyType(
                {name: MappingProxyType(dict(product_cells)) for name, product_cells in cells.items()}
            )
        )

    def get(self, product: tuple[str, str], key: Value) -> Value:
        product_cells = self.cells.get(product)
        if product_cells is None or key not in product_cells:
            reject("F05-EVAL-STATE-DOMAIN", f"missing:{product}")
        return product_cells[key]


@dataclass(frozen=True)
class EventView:
    channels: Mapping[tuple[str, str], Value]

    @classmethod
    def decode(cls, raw: Mapping[str, Any], interpretation: FiniteInterpretation) -> "EventView":
        exact_object(raw, {"tag", "channels"}, "$event", "EVENT_BUNDLE_VALUE")
        channels: dict[tuple[str, str], Value] = {}
        rows = require_canonical_rows(raw["channels"], "event_channel", "$event.channels")
        for index, row in enumerate(rows):
            exact_object(row, {"tag", "event_channel", "value"}, f"$event.channels[{index}]", "EVENT_CHANNEL_VALUE")
            channel = qname(row["event_channel"], f"$event.channels[{index}].event_channel")
            payload = interpretation.signature.event_channels.get(channel)
            if payload is None or channel in channels:
                reject("F05-EVAL-EVENT-CHANNEL", repr(channel))
            expected = {"tag": "SORT_OPTION", "element": payload}
            channels[channel] = interpretation.decode_value(row["value"], expected, f"$event.channels[{index}].value")
        if set(channels) != set(interpretation.signature.event_channels):
            reject("F05-EVAL-EVENT-DOMAIN", "not exact")
        return cls(MappingProxyType(channels))

    def get(self, channel: tuple[str, str]) -> Value:
        if channel not in self.channels:
            reject("F05-EVAL-EVENT-DOMAIN", f"missing:{channel}")
        return self.channels[channel]
