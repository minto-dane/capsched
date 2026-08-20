#!/usr/bin/env python3
"""Hostile regression campaign for the DL-F0-5 CoreSyntaxWF checker."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
F0 = HERE.parent / "policy" / "r11" / "epoch2" / "foundation-v5"
GRAMMAR_PATH = F0 / "f0-machine-grammar-v5.json"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


core = load_module("validate_f0_core_syntax_v5_test", HERE / "validate-f0-core-syntax-v5.py")
wire = core.wire
semantics = core.semantics
GRAMMAR = json.loads(GRAMMAR_PATH.read_text(encoding="ascii"))
WIRE_GENERATION = wire.load_generation()
wire.load_generation = lambda: WIRE_GENERATION
NODE_BY_TAG = {
    node["tag"]: node
    for section in wire.checker.NODE_SECTIONS
    for node in GRAMMAR[section]
}
POLICIES = {
    (entry["owner_tag"], entry["field"]): entry
    for entry in GRAMMAR["collection_field_policies"]
}


def qn(module: str, local: str) -> list[str]:
    return [module, local]


def s_bool() -> dict[str, Any]:
    return {"tag": "SORT_BOOL"}


def s_one() -> dict[str, Any]:
    return {"tag": "SORT_ONE"}


def s_qty() -> dict[str, Any]:
    return {"tag": "SORT_QTY", "unit": qn("types", "Tick"), "limit": qn("types", "MaxTick")}


def s_pair() -> dict[str, Any]:
    return {"tag": "SORT_RECORD", "record": qn("types", "Pair")}


def s_arith() -> dict[str, Any]:
    return {"tag": "SORT_VARIANT", "variant": qn("types", "ArithResult")}


def s_event() -> dict[str, Any]:
    return {"tag": "SORT_VARIANT", "variant": qn("types", "EventPayload")}


def s_option(element: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_OPTION", "element": copy.deepcopy(element)}


def s_set(element: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_FINSET", "element": copy.deepcopy(element)}


def s_map(key: dict[str, Any], value: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "SORT_TOTALMAP", "key": copy.deepcopy(key), "value": copy.deepcopy(value)}


def term(result_sort: dict[str, Any], tag: str, **fields: Any) -> dict[str, Any]:
    return {
        "tag": "TYPED_TERM",
        "result_sort": copy.deepcopy(result_sort),
        "node": {"tag": tag, **fields},
    }


def t_bool(value: bool = True) -> dict[str, Any]:
    return term(s_bool(), "TERM_BOOL", value=value)


def t_one() -> dict[str, Any]:
    return term(s_one(), "TERM_ONE")


def t_var(variable: str, sort: dict[str, Any]) -> dict[str, Any]:
    return term(sort, "TERM_VARIABLE", variable=variable)


def t_const(local: str, sort: dict[str, Any]) -> dict[str, Any]:
    return term(sort, "TERM_CONSTANT", constant=qn("types", local))


def t_qty_zero() -> dict[str, Any]:
    return term(
        s_qty(),
        "TERM_QTY_ZERO",
        unit=qn("types", "Tick"),
        limit=qn("types", "MaxTick"),
    )


def t_qty_checked(value: int) -> dict[str, Any]:
    return term(
        s_arith(),
        "TERM_QTY_CHECKED",
        unit=qn("types", "Tick"),
        limit=qn("types", "MaxTick"),
        value=value,
    )


def t_eq(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    return term(s_bool(), "TERM_EQ", left=left, right=right)


def t_pair(flag: dict[str, Any] | None = None, amount: dict[str, Any] | None = None) -> dict[str, Any]:
    return term(
        s_pair(),
        "TERM_RECORD",
        record=qn("types", "Pair"),
        values=[
            {"tag": "FIELD_TERM_ENTRY", "field": "flag", "value": flag or t_bool()},
            {"tag": "FIELD_TERM_ENTRY", "field": "amount", "value": amount or t_qty_zero()},
        ],
    )


def t_field(record_term: dict[str, Any], field: str, result_sort: dict[str, Any]) -> dict[str, Any]:
    return term(
        result_sort,
        "TERM_FIELD",
        record_term=record_term,
        record=qn("types", "Pair"),
        field=field,
    )


def t_pre(key: dict[str, Any] | None = None) -> dict[str, Any]:
    return term(
        s_pair(),
        "TERM_PRE_GET",
        state_product=qn("app", "Queue"),
        key=key or t_bool(),
    )


def t_post(key: dict[str, Any] | None = None) -> dict[str, Any]:
    return term(
        s_pair(),
        "TERM_POST_GET",
        state_product=qn("app", "Queue"),
        key=key or t_bool(),
    )


def arith_result_match(scrutinee: dict[str, Any]) -> dict[str, Any]:
    return term(
        s_bool(),
        "TERM_MATCH_VARIANT",
        scrutinee=scrutinee,
        variant=qn("types", "ArithResult"),
        branches=[
            {
                "tag": "VARIANT_TERM_BRANCH",
                "variant_tag": "Ok",
                "payload_variable": "arith_ok",
                "body": t_bool(),
            },
            {
                "tag": "VARIANT_TERM_BRANCH",
                "variant_tag": "Overflow",
                "payload_variable": "arith_overflow",
                "body": t_bool(),
            },
            {
                "tag": "VARIANT_TERM_BRANCH",
                "variant_tag": "Underflow",
                "payload_variable": "arith_underflow",
                "body": t_bool(),
            },
        ],
    )


def arithmetic_match(operator: str) -> dict[str, Any]:
    arithmetic = term(
        s_arith(),
        operator,
        left=t_const("Amount", s_qty()),
        right=t_qty_zero(),
    )
    return arith_result_match(arithmetic)


def rich_state_predicate() -> dict[str, Any]:
    empty = term(s_set(s_bool()), "TERM_SET_EMPTY", element_sort=s_bool())
    inserted = term(s_set(s_bool()), "TERM_SET_INSERT", set=copy.deepcopy(empty), element=t_bool())
    removed = term(s_set(s_bool()), "TERM_SET_REMOVE", set=copy.deepcopy(inserted), element=t_bool())
    union = term(s_set(s_bool()), "TERM_SET_UNION", left=copy.deepcopy(inserted), right=copy.deepcopy(empty))
    difference = term(
        s_set(s_bool()),
        "TERM_SET_DIFFERENCE",
        left=copy.deepcopy(inserted),
        right=copy.deepcopy(empty),
    )
    base_map = t_const("PairMap", s_map(s_bool(), s_pair()))
    changed_map = term(
        s_map(s_bool(), s_pair()),
        "TERM_MAP_SET",
        map=copy.deepcopy(base_map),
        key=t_bool(),
        value=t_pair(),
    )
    event_value = term(
        s_event(),
        "TERM_VARIANT",
        variant=qn("types", "EventPayload"),
        variant_tag="Changed",
        payload=t_one(),
    )
    variant_match = term(
        s_bool(),
        "TERM_MATCH_VARIANT",
        scrutinee=event_value,
        variant=qn("types", "EventPayload"),
        branches=[
            {
                "tag": "VARIANT_TERM_BRANCH",
                "variant_tag": "Changed",
                "payload_variable": "event_changed",
                "body": t_bool(),
            },
            {
                "tag": "VARIANT_TERM_BRANCH",
                "variant_tag": "Idle",
                "payload_variable": "event_idle",
                "body": t_bool(),
            },
        ],
    )
    some = term(s_option(s_bool()), "TERM_SOME", element_sort=s_bool(), value=t_bool())
    option_match = term(
        s_bool(),
        "TERM_MATCH_OPTION",
        scrutinee=some,
        element_sort=s_bool(),
        none_body=t_bool(),
        some_variable="option_value",
        some_body=t_var("option_value", s_bool()),
    )
    predicates = [
        t_const("Always", s_bool()),
        term(
            s_bool(),
            "TERM_LET",
            variable="local_value",
            bound=t_bool(),
            body=t_var("local_value", s_bool()),
        ),
        t_field(t_pair(), "flag", s_bool()),
        variant_match,
        t_eq(
            term(s_option(s_bool()), "TERM_NONE", element_sort=s_bool()),
            term(s_option(s_bool()), "TERM_NONE", element_sort=s_bool()),
        ),
        option_match,
        term(s_bool(), "TERM_SET_MEMBER", set=copy.deepcopy(inserted), element=t_bool()),
        term(s_bool(), "TERM_SET_SUBSET", left=copy.deepcopy(removed), right=copy.deepcopy(inserted)),
        t_eq(union, copy.deepcopy(inserted)),
        t_eq(difference, copy.deepcopy(inserted)),
        t_field(
            term(s_pair(), "TERM_MAP_GET", map=copy.deepcopy(base_map), key=t_bool()),
            "flag",
            s_bool(),
        ),
        t_field(
            term(s_pair(), "TERM_MAP_GET", map=changed_map, key=t_bool()),
            "flag",
            s_bool(),
        ),
        term(s_bool(), "TERM_OR", operands=[t_bool(), t_bool(False)]),
        term(s_bool(), "TERM_NOT", operand=t_bool(False)),
        term(s_bool(), "TERM_IMPLIES", left=t_bool(), right=t_bool()),
        term(s_bool(), "TERM_IFF", left=t_bool(), right=t_bool()),
        t_eq(t_one(), t_one()),
        t_eq(
            term({"tag": "SORT_ENUM", "enum": qn("types", "Color")}, "TERM_ENUM", enum=qn("types", "Color"), member="Blue"),
            term({"tag": "SORT_ENUM", "enum": qn("types", "Color")}, "TERM_ENUM", enum=qn("types", "Color"), member="Blue"),
        ),
        term(s_bool(), "TERM_QTY_LT", left=t_qty_zero(), right=t_const("Amount", s_qty())),
        term(s_bool(), "TERM_QTY_LE", left=t_qty_zero(), right=t_const("Amount", s_qty())),
        term(s_bool(), "TERM_QTY_GT", left=t_const("Amount", s_qty()), right=t_qty_zero()),
        term(s_bool(), "TERM_QTY_GE", left=t_const("Amount", s_qty()), right=t_qty_zero()),
        arith_result_match(t_qty_checked(1)),
        arithmetic_match("TERM_QTY_ADD"),
        arithmetic_match("TERM_QTY_SUB"),
        term(s_bool(), "TERM_IF", condition=t_bool(), then=t_bool(), **{"else": t_bool(False)}),
        term(
            s_bool(),
            "TERM_FORALL",
            variable="forall_value",
            sort=s_bool(),
            body=t_eq(t_var("forall_value", s_bool()), t_var("forall_value", s_bool())),
        ),
        term(
            s_bool(),
            "TERM_EXISTS",
            variable="exists_value",
            sort=s_bool(),
            body=t_var("exists_value", s_bool()),
        ),
        t_field(t_pre(), "flag", s_bool()),
    ]
    return term(s_bool(), "TERM_AND", operands=predicates)


def types_module() -> dict[str, Any]:
    declarations = [
        {"tag": "DECL_ATOM", "name": qn("types", "Entity"), "carrier_class": "FINITE"},
        {"tag": "DECL_ENUM", "name": qn("types", "Color"), "members": ["Blue", "Red"]},
        {"tag": "DECL_UNIT", "name": qn("types", "Tick")},
        {"tag": "DECL_LIMIT", "name": qn("types", "MaxTick")},
        {
            "tag": "DECL_RECORD",
            "name": qn("types", "Pair"),
            "fields": [
                {"tag": "FIELD_DECL", "field": "flag", "sort": s_bool()},
                {"tag": "FIELD_DECL", "field": "amount", "sort": s_qty()},
            ],
        },
        {
            "tag": "DECL_VARIANT",
            "name": qn("types", "ArithResult"),
            "variant_tags": [
                {"tag": "VARIANT_TAG_DECL", "variant_tag": "Ok", "payload_sort": s_qty()},
                {"tag": "VARIANT_TAG_DECL", "variant_tag": "Overflow", "payload_sort": s_one()},
                {"tag": "VARIANT_TAG_DECL", "variant_tag": "Underflow", "payload_sort": s_one()},
            ],
        },
        {
            "tag": "DECL_VARIANT",
            "name": qn("types", "EventPayload"),
            "variant_tags": [
                {"tag": "VARIANT_TAG_DECL", "variant_tag": "Changed", "payload_sort": s_one()},
                {"tag": "VARIANT_TAG_DECL", "variant_tag": "Idle", "payload_sort": s_one()},
            ],
        },
        {"tag": "DECL_CONSTANT", "name": qn("types", "Always"), "sort": s_bool()},
        {"tag": "DECL_CONSTANT", "name": qn("types", "Amount"), "sort": s_qty()},
        {"tag": "DECL_CONSTANT", "name": qn("types", "BoolSet"), "sort": s_set(s_bool())},
        {
            "tag": "DECL_CONSTANT",
            "name": qn("types", "PairMap"),
            "sort": s_map(s_bool(), s_pair()),
        },
        {
            "tag": "DECL_CONSTANT_CONSTRAINT",
            "constraint": {
                "tag": "CONSTANT_CONSTRAINT",
                "relation": "EQ",
                "left": qn("types", "Always"),
                "right": qn("types", "Always"),
            },
        },
        {
            "tag": "DECL_ARITH_RESULT_BINDING",
            "quantity_sort": s_qty(),
            "result_variant": qn("types", "ArithResult"),
        },
        {
            "tag": "DECL_PREMISE",
            "name": qn("types", "CarrierPremise"),
            "body": {
                "tag": "PREMISE_AND",
                "operands": [
                    {"tag": "PREMISE_ATOM_CARD_GE", "atom": qn("types", "Entity"), "bound": 1},
                    {"tag": "PREMISE_LIMIT_LE", "left": qn("types", "MaxTick"), "right": qn("types", "MaxTick")},
                    {"tag": "PREMISE_LIMIT_GE_NAT", "limit": qn("types", "MaxTick"), "bound": 0},
                ],
            },
        },
    ]
    return {
        "tag": "MODULE",
        "name": "types",
        "imports": [],
        "declarations": declarations,
        "init_contribution": t_bool(),
    }


def app_module() -> dict[str, Any]:
    action = {
        "tag": "DECL_ACTION",
        "name": qn("app", "Operate"),
        "parameter_variable": "parameter",
        "parameter_sort": s_bool(),
        "invoke": t_bool(),
        "branches": [
            {
                "tag": "ACTION_BRANCH",
                "branch": "Applied",
                "guard": t_bool(),
                "updates": [
                    {
                        "tag": "PUT_UPDATE",
                        "state_product": qn("app", "Queue"),
                        "key": t_var("parameter", s_bool()),
                        "value": t_pre(t_var("parameter", s_bool())),
                    },
                    {
                        "tag": "PATCH_UPDATE",
                        "state_product": qn("app", "Queue"),
                        "domain": t_const("BoolSet", s_set(s_bool())),
                        "values": t_const("PairMap", s_map(s_bool(), s_pair())),
                    },
                ],
                "emits": [
                    {
                        "tag": "CHANNEL_EMIT",
                        "event_channel": qn("app", "Events"),
                        "value": term(
                            s_option(s_event()),
                            "TERM_SOME",
                            element_sort=s_event(),
                            value=term(
                                s_event(),
                                "TERM_VARIANT",
                                variant=qn("types", "EventPayload"),
                                variant_tag="Changed",
                                payload=t_one(),
                            ),
                        ),
                    }
                ],
            }
        ],
    }
    declarations = [
        {
            "tag": "DECL_STATE_PRODUCT",
            "name": qn("app", "Queue"),
            "key_sort": s_bool(),
            "value_sort": s_pair(),
        },
        {
            "tag": "DECL_EVENT_CHANNEL",
            "name": qn("app", "Events"),
            "payload_variant": qn("types", "EventPayload"),
        },
        action,
        {
            "tag": "DECL_CLAIM_BASE_ALWAYS",
            "name": qn("app", "BaseInvariant"),
            "invariant": t_field(t_pre(), "flag", s_bool()),
        },
    ]
    return {
        "tag": "MODULE",
        "name": "app",
        "imports": [{"tag": "IMPORT", "module": "types", "artifact_sha256": "0" * 64}],
        "declarations": declarations,
        "init_contribution": rich_state_predicate(),
    }


def collection_key(item: Any, key_rule: str) -> bytes:
    if key_rule == "SELF_CANONICAL":
        return wire.checker.canonical_bytes(item)
    if key_rule == "TAG_THEN_CANONICAL":
        return item["tag"].encode("ascii") + b"\x00" + wire.checker.canonical_bytes(item)
    return wire.checker.canonical_bytes(item[key_rule])


def canonicalize_collections(value: Any) -> None:
    if isinstance(value, list):
        for item in value:
            canonicalize_collections(item)
        return
    if not isinstance(value, dict) or value.get("tag") not in NODE_BY_TAG:
        return
    tag = value["tag"]
    for field_name, kind in NODE_BY_TAG[tag]["fields"]:
        child = value[field_name]
        match = wire.checker.COLLECTION_RE.fullmatch(kind)
        if match is None:
            raise RuntimeError(f"unrecognized kind {kind}")
        if match.group("suffix") is None:
            canonicalize_collections(child)
            continue
        for item in child:
            canonicalize_collections(item)
        policy = POLICIES[(tag, field_name)]
        if policy["mode"] != "ordered_sequence":
            child.sort(key=lambda item: collection_key(item, policy["key"]))


def module_by_name(model: dict[str, Any], name: str) -> dict[str, Any]:
    return next(module for module in model["modules"] if module["name"] == name)


def declaration(model: dict[str, Any], tag: str, local: str | None = None) -> dict[str, Any]:
    for module in model["modules"]:
        for item in module["declarations"]:
            if item["tag"] != tag:
                continue
            if local is None or item.get("name", [None, None])[1] == local:
                return item
    raise KeyError((tag, local))


def repin_imports(model: dict[str, Any]) -> None:
    modules = {module["name"]: module for module in model["modules"]}
    visiting: set[str] = set()
    done: set[str] = set()

    def visit(name: str) -> None:
        if name in done:
            return
        if name in visiting:
            raise RuntimeError("cannot repin cyclic imports")
        visiting.add(name)
        module = modules[name]
        for imported in module["imports"]:
            visit(imported["module"])
            canonicalize_collections(modules[imported["module"]])
            imported["artifact_sha256"] = semantics.module_content_sha256(
                modules[imported["module"]]
            )
        canonicalize_collections(module)
        visiting.remove(name)
        done.add(name)

    for name in modules:
        visit(name)
    canonicalize_collections(model)


def model_fixture() -> dict[str, Any]:
    model = {
        "tag": "MODEL",
        "modules": [app_module(), types_module()],
        "root_module": "app",
        "active_modules": ["app", "types"],
    }
    repin_imports(model)
    return model


def independent_module_composition_fixture() -> dict[str, Any]:
    model = model_fixture()
    side = {
        "tag": "MODULE",
        "name": "side",
        "imports": [{"tag": "IMPORT", "module": "types", "artifact_sha256": "0" * 64}],
        "declarations": [
            {
                "tag": "DECL_EVENT_CHANNEL",
                "name": qn("side", "SideEvents"),
                "payload_variant": qn("types", "EventPayload"),
            },
            {
                "tag": "DECL_ACTION",
                "name": qn("side", "SideAction"),
                "parameter_variable": "side_parameter",
                "parameter_sort": s_bool(),
                "invoke": t_bool(),
                "branches": [
                    {
                        "tag": "ACTION_BRANCH",
                        "branch": "SideApplied",
                        "guard": t_bool(),
                        "updates": [],
                        "emits": [
                            {
                                "tag": "CHANNEL_EMIT",
                                "event_channel": qn("side", "SideEvents"),
                                "value": term(
                                    s_option(s_event()),
                                    "TERM_SOME",
                                    element_sort=s_event(),
                                    value=term(
                                        s_event(),
                                        "TERM_VARIANT",
                                        variant=qn("types", "EventPayload"),
                                        variant_tag="Idle",
                                        payload=t_one(),
                                    ),
                                ),
                            }
                        ],
                    }
                ],
            },
        ],
        "init_contribution": t_bool(),
    }
    root = {
        "tag": "MODULE",
        "name": "root",
        "imports": [
            {"tag": "IMPORT", "module": "app", "artifact_sha256": "0" * 64},
            {"tag": "IMPORT", "module": "side", "artifact_sha256": "0" * 64},
        ],
        "declarations": [],
        "init_contribution": t_bool(),
    }
    model["modules"].extend([side, root])
    model["root_module"] = "root"
    model["active_modules"] = ["app", "root", "side", "types"]
    repin_imports(model)
    return model


def deep_import_fixture(count: int) -> dict[str, Any]:
    modules_by_name: dict[str, dict[str, Any]] = {}
    for index in reversed(range(count)):
        name = f"M{index:04d}"
        imports: list[dict[str, Any]] = []
        if index + 1 < count:
            target = f"M{index + 1:04d}"
            imports.append(
                {
                    "tag": "IMPORT",
                    "module": target,
                    "artifact_sha256": semantics.module_content_sha256(modules_by_name[target]),
                }
            )
        modules_by_name[name] = {
            "tag": "MODULE",
            "name": name,
            "imports": imports,
            "declarations": [],
            "init_contribution": t_bool(),
        }
    return {
        "tag": "MODEL",
        "modules": [modules_by_name[name] for name in sorted(modules_by_name)],
        "root_module": "M0000",
        "active_modules": ["M0000"],
    }


def deep_named_type_fixture(count: int) -> dict[str, Any]:
    declarations: list[dict[str, Any]] = []
    for index in range(count):
        payload_sort = (
            s_bool()
            if index + 1 == count
            else {"tag": "SORT_RECORD", "record": qn("deep", f"R{index + 1:04d}")}
        )
        declarations.append(
            {
                "tag": "DECL_RECORD",
                "name": qn("deep", f"R{index:04d}"),
                "fields": [
                    {"tag": "FIELD_DECL", "field": "next_value", "sort": payload_sort}
                ],
            }
        )
    declarations.append(
        {
            "tag": "DECL_STATE_PRODUCT",
            "name": qn("deep", "State"),
            "key_sort": s_bool(),
            "value_sort": {"tag": "SORT_RECORD", "record": qn("deep", "R0000")},
        }
    )
    model = {
        "tag": "MODEL",
        "modules": [
            {
                "tag": "MODULE",
                "name": "deep",
                "imports": [],
                "declarations": declarations,
                "init_contribution": t_bool(),
            }
        ],
        "root_module": "deep",
        "active_modules": ["deep"],
    }
    canonicalize_collections(model)
    return model


def find_term(value: Any, node_tag: str) -> dict[str, Any]:
    if isinstance(value, dict):
        if value.get("tag") == "TYPED_TERM" and value["node"].get("tag") == node_tag:
            return value
        for child in value.values():
            try:
                return find_term(child, node_tag)
            except KeyError:
                pass
    elif isinstance(value, list):
        for child in value:
            try:
                return find_term(child, node_tag)
            except KeyError:
                pass
    raise KeyError(node_tag)


def validate_model(model: dict[str, Any], repin: bool = True) -> dict[str, Any]:
    if repin:
        repin_imports(model)
    else:
        canonicalize_collections(model)
    with tempfile.TemporaryDirectory(prefix="f0-core-syntax-v5-") as temporary:
        path = Path(temporary) / "model.json"
        path.write_bytes(wire.checker.canonical_bytes(model))
        return core.validate(path)


Mutation = Callable[[dict[str, Any]], None]


def expect_reject(
    baseline: dict[str, Any],
    case_id: str,
    expected: str,
    mutate: Mutation,
    *,
    repin: bool = True,
    direct: bool = True,
) -> dict[str, str]:
    model = copy.deepcopy(baseline)
    mutate(model)
    try:
        if direct:
            if repin:
                repin_imports(model)
            else:
                canonicalize_collections(model)
            semantics.CoreSyntaxChecker.for_internal_test_model(model).check()
        else:
            validate_model(model, repin=repin)
    except semantics.SemanticReject as exc:
        if exc.reject_id != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {exc.reject_id}: {exc.detail}")
        return {"id": case_id, "reject_id": exc.reject_id}
    raise RuntimeError(f"{case_id}: mutation was accepted")


def main() -> int:
    baseline = model_fixture()
    accepted = validate_model(copy.deepcopy(baseline))
    if accepted["CoreSyntaxWF"] is not False:
        raise RuntimeError("construction checker must not claim complete CoreSyntaxWF")
    try:
        semantics.CoreSyntaxChecker(copy.deepcopy(baseline))
    except TypeError:
        pass
    else:
        raise RuntimeError("direct mutable-dict checker API remained production-callable")
    expected_source_tags = {
        entry["tag"] for entry in GRAMMAR["term_nodes"]
    } - {"TERM_POST_GET", "TERM_EVENT_GET"}
    actual_source_tags = set(accepted["term_constructor_coverage"])
    if actual_source_tags != expected_source_tags:
        raise RuntimeError(
            f"source constructor coverage mismatch missing={sorted(expected_source_tags-actual_source_tags)} "
            f"extra={sorted(actual_source_tags-expected_source_tags)}"
        )

    checker = semantics.CoreSyntaxChecker.for_internal_test_model(copy.deepcopy(baseline))
    checker.check()
    post = checker.type_term(t_post(), "app", {}, "$.relation.post")
    event = checker.type_term(
        term(
            s_option(s_event()),
            "TERM_EVENT_GET",
            event_channel=qn("app", "Events"),
        ),
        "app",
        {},
        "$.relation.event",
    )
    if post.provenance != frozenset({semantics.POST}) or event.provenance != frozenset({semantics.EVENT}):
        raise RuntimeError("relation-only provenance dispatch mismatch")
    checker.check_sort(
        {"tag": "SORT_ATOM", "atom": qn("types", "Entity")},
        "types",
        "$.dispatch.sort_atom",
    )
    checker.check_premise(
        {
            "tag": "PREMISE_AND",
            "operands": [
                {"tag": "PREMISE_CONST_EQ", "left": qn("types", "Always"), "right": qn("types", "Always")},
                {"tag": "PREMISE_CONST_NEQ", "left": qn("types", "Always"), "right": qn("types", "Always")},
                {"tag": "PREMISE_LIMIT_EQ", "left": qn("types", "MaxTick"), "right": qn("types", "MaxTick")},
                {"tag": "PREMISE_LIMIT_LE", "left": qn("types", "MaxTick"), "right": qn("types", "MaxTick")},
                {"tag": "PREMISE_LIMIT_LT", "left": qn("types", "MaxTick"), "right": qn("types", "MaxTick")},
                {"tag": "PREMISE_LIMIT_GE_NAT", "limit": qn("types", "MaxTick"), "bound": 0},
                {"tag": "PREMISE_ATOM_CARD_EQ", "atom": qn("types", "Entity"), "bound": 1},
                {"tag": "PREMISE_ATOM_CARD_GE", "atom": qn("types", "Entity"), "bound": 1},
                {
                    "tag": "PREMISE_NOT",
                    "operand": {
                        "tag": "PREMISE_OR",
                        "operands": [
                            {"tag": "PREMISE_LIMIT_GE_NAT", "limit": qn("types", "MaxTick"), "bound": 0},
                            {"tag": "PREMISE_ATOM_CARD_GE", "atom": qn("types", "Entity"), "bound": 1},
                        ],
                    },
                },
            ],
        },
        "types",
        "$.dispatch.premises",
    )
    expected_dispatch = {
        "sort": set(semantics.static_registry.SORT_HANDLERS.values()),
        "premise": set(semantics.static_registry.PREMISE_HANDLERS.values()),
        "term": {
            handler.typing_rule
            for handler in semantics.static_registry.TERM_HANDLERS.values()
        },
        "update": {
            handler[0]
            for handler in semantics.static_registry.UPDATE_HANDLERS.values()
        },
        "body": set(semantics.static_registry.BODY_HANDLERS),
        "binder": set(semantics.static_registry.BINDER_HANDLERS),
    }
    actual_dispatch = {
        "sort": set(checker.sort_rule_counts),
        "premise": set(checker.premise_rule_counts),
        "term": set(checker.term_typing_rule_counts),
        "update": set(checker.update_rule_counts),
        "body": set(checker.body_rule_counts),
        "binder": set(checker.binder_tag_counts),
    }
    if actual_dispatch != expected_dispatch:
        raise RuntimeError(
            f"static dispatch coverage mismatch actual={actual_dispatch} expected={expected_dispatch}"
        )
    if (
        checker.term_result_rederived_count != checker.term_count
        or checker.term_provenance_rederived_count != checker.term_count
    ):
        raise RuntimeError("not every typed term was independently rederived")

    deep_counts = semantics.CoreSyntaxChecker.for_internal_test_model(deep_import_fixture(1100)).check()
    if deep_counts["module_count"] != 1100:
        raise RuntimeError("deep import DAG traversal count mismatch")
    deep_type_counts = semantics.CoreSyntaxChecker.for_internal_test_model(deep_named_type_fixture(1100)).check()
    if deep_type_counts["declaration_count"] != 1101:
        raise RuntimeError("deep named-type DAG traversal count mismatch")
    composed_counts = semantics.CoreSyntaxChecker.for_internal_test_model(independent_module_composition_fixture()).check()
    if composed_counts["action_count"] != 2:
        raise RuntimeError("independent sibling action/channel composition failed")
    dormant = independent_module_composition_fixture()
    dormant["active_modules"] = ["app", "root", "types"]
    dormant_counts = semantics.CoreSyntaxChecker.for_internal_test_model(dormant).check()
    if dormant_counts["action_count"] != 2 or dormant_counts["active_action_count"] != 1:
        raise RuntimeError("dependency and semantic activation were not separated")

    with tempfile.TemporaryDirectory(prefix="f0-core-toctou-v5-") as temporary:
        path = Path(temporary) / "model.json"
        original_raw = wire.checker.canonical_bytes(baseline)
        path.write_bytes(original_raw)
        original_read_once = wire.checker.read_once
        model_reads = 0

        def swapping_read_once(candidate: Path) -> bytes:
            nonlocal model_reads
            raw = original_read_once(candidate)
            if candidate == path:
                model_reads += 1
                if model_reads == 1:
                    path.write_bytes(b"{}")
            return raw

        wire.checker.read_once = swapping_read_once
        try:
            snapshot_result = core.validate(path)
        finally:
            wire.checker.read_once = original_read_once
        if model_reads != 1 or snapshot_result["model_sha256"] != wire.checker.digest(original_raw):
            raise RuntimeError("wire and semantic checks did not share one immutable byte snapshot")

    too_deep = copy.deepcopy(baseline)
    nested = t_bool()
    for _ in range(semantics.MAX_TERM_DEPTH + 1):
        nested = term(s_bool(), "TERM_NOT", operand=nested)
    module_by_name(too_deep, "app")["init_contribution"] = nested
    try:
        semantics.CoreSyntaxChecker.for_internal_test_model(too_deep).check()
    except semantics.VerificationInconclusive as exc:
        if exc.reason_id != "F05-CORE-RESOURCE-TERM-DEPTH":
            raise RuntimeError(f"unexpected resource reason: {exc.reason_id}")
        resource_reason = exc.reason_id
    except RecursionError as exc:
        raise RuntimeError("term resource envelope leaked host RecursionError") from exc
    else:
        raise RuntimeError("term beyond checker profile was accepted")

    cases: list[dict[str, str]] = []

    def case(case_id: str, expected: str, mutate: Mutation, **options: Any) -> None:
        cases.append(expect_reject(baseline, case_id, expected, mutate, **options))

    case(
        "duplicate_direct_import_defense_in_depth",
        "F05-CORE-DUPLICATE-IMPORT",
        lambda model: module_by_name(model, "app")["imports"].append(
            copy.deepcopy(module_by_name(model, "app")["imports"][0])
        ),
    )
    case(
        "duplicate_unnamed_constraint_defense_in_depth",
        "F05-CORE-DUPLICATE-UNNAMED-DECLARATION",
        lambda model: module_by_name(model, "types")["declarations"].append(
            copy.deepcopy(
                next(
                    declaration
                    for declaration in module_by_name(model, "types")["declarations"]
                    if declaration["tag"] == "DECL_CONSTANT_CONSTRAINT"
                )
            )
        ),
    )

    case(
        "import_digest_substitution",
        "F05-CORE-IMPORT-DIGEST",
        lambda m: module_by_name(m, "app")["imports"][0].__setitem__("artifact_sha256", "0" * 64),
        repin=False,
    )
    case(
        "unresolved_import",
        "F05-CORE-UNRESOLVED-IMPORT",
        lambda m: module_by_name(m, "app")["imports"][0].__setitem__("module", "missing"),
        repin=False,
    )

    def import_cycle(model: dict[str, Any]) -> None:
        module_by_name(model, "types")["imports"] = [
            {"tag": "IMPORT", "module": "app", "artifact_sha256": "0" * 64}
        ]

    case("import_cycle", "F05-CORE-IMPORT-CYCLE", import_cycle, repin=False)

    def unreachable(model: dict[str, Any]) -> None:
        model["modules"].append(
            {"tag": "MODULE", "name": "unused", "imports": [], "declarations": [], "init_contribution": t_bool()}
        )

    case("unreachable_module", "F05-CORE-UNREACHABLE-MODULE", unreachable)
    case(
        "inactive_root_module",
        "F05-CORE-INACTIVE-ROOT-MODULE",
        lambda m: m.__setitem__("active_modules", ["types"]),
    )
    case(
        "unknown_active_module",
        "F05-CORE-UNKNOWN-ACTIVE-MODULE",
        lambda m: m.__setitem__("active_modules", ["app", "missing", "types"]),
    )
    case(
        "declaration_module_mismatch",
        "F05-CORE-DECLARATION-MODULE",
        lambda m: declaration(m, "DECL_ATOM", "Entity").__setitem__("name", qn("app", "Entity")),
    )

    def duplicate_declaration(model: dict[str, Any]) -> None:
        module_by_name(model, "types")["declarations"].append(
            {"tag": "DECL_UNIT", "name": qn("types", "Entity")}
        )

    case("cross_namespace_duplicate", "F05-CORE-DUPLICATE-DECLARATION", duplicate_declaration)
    case(
        "invisible_reference",
        "F05-CORE-INVISIBLE-NAME",
        lambda m: declaration(m, "DECL_CONSTANT", "Always").__setitem__(
            "sort", {"tag": "SORT_RECORD", "record": qn("app", "Private")}
        ),
    )
    case(
        "unresolved_visible_reference",
        "F05-CORE-UNRESOLVED-NAME",
        lambda m: declaration(m, "DECL_STATE_PRODUCT", "Queue").__setitem__(
            "key_sort", {"tag": "SORT_RECORD", "record": qn("types", "Missing")}
        ),
    )

    def transitive_visibility(model: dict[str, Any]) -> None:
        bridge = {
            "tag": "MODULE",
            "name": "bridge",
            "imports": [{"tag": "IMPORT", "module": "types", "artifact_sha256": "0" * 64}],
            "declarations": [],
            "init_contribution": t_bool(),
        }
        model["modules"].append(bridge)
        module_by_name(model, "app")["imports"] = [
            {"tag": "IMPORT", "module": "bridge", "artifact_sha256": "0" * 64}
        ]

    case("transitive_import_not_reexported", "F05-CORE-INVISIBLE-NAME", transitive_visibility)
    case(
        "namespace_mismatch",
        "F05-CORE-NAMESPACE-MISMATCH",
        lambda m: declaration(m, "DECL_STATE_PRODUCT", "Queue").__setitem__(
            "key_sort", {"tag": "SORT_ATOM", "atom": qn("types", "Color")}
        ),
    )

    def recursive_record(model: dict[str, Any]) -> None:
        declaration(model, "DECL_RECORD", "Pair")["fields"][0]["sort"] = s_pair()

    case("recursive_sort", "F05-CORE-SORT-CYCLE", recursive_record)
    case(
        "collection_state_key",
        "F05-CORE-KEYSORT",
        lambda m: declaration(m, "DECL_STATE_PRODUCT", "Queue").__setitem__("key_sort", s_set(s_bool())),
    )
    case(
        "collection_state_value",
        "F05-CORE-CELLSORT",
        lambda m: declaration(m, "DECL_STATE_PRODUCT", "Queue").__setitem__(
            "value_sort", s_map(s_bool(), s_bool())
        ),
    )
    case(
        "non_quantity_arithmetic_binding",
        "F05-CORE-ARITH-NON-QTY",
        lambda m: declaration(m, "DECL_ARITH_RESULT_BINDING").__setitem__("quantity_sort", s_bool()),
    )

    def bad_arith_tags(model: dict[str, Any]) -> None:
        declaration(model, "DECL_VARIANT", "ArithResult")["variant_tags"][0]["variant_tag"] = "Bad"

    case("arithmetic_variant_tags", "F05-CORE-ARITH-VARIANT-TAGS", bad_arith_tags)

    def bad_arith_payload(model: dict[str, Any]) -> None:
        arith = declaration(model, "DECL_VARIANT", "ArithResult")
        next(item for item in arith["variant_tags"] if item["variant_tag"] == "Ok")["payload_sort"] = s_one()

    case("arithmetic_variant_payload", "F05-CORE-ARITH-VARIANT-PAYLOAD", bad_arith_payload)

    def duplicate_arith_binding(model: dict[str, Any]) -> None:
        types = module_by_name(model, "types")
        types["declarations"].extend(
            [
                {
                    "tag": "DECL_VARIANT",
                    "name": qn("types", "ArithResult2"),
                    "variant_tags": [
                        {"tag": "VARIANT_TAG_DECL", "variant_tag": "Ok", "payload_sort": s_qty()},
                        {"tag": "VARIANT_TAG_DECL", "variant_tag": "Overflow", "payload_sort": s_one()},
                        {"tag": "VARIANT_TAG_DECL", "variant_tag": "Underflow", "payload_sort": s_one()},
                    ],
                },
                {
                    "tag": "DECL_ARITH_RESULT_BINDING",
                    "quantity_sort": s_qty(),
                    "result_variant": qn("types", "ArithResult2"),
                },
            ]
        )

    case("duplicate_arithmetic_binding", "F05-CORE-DUPLICATE-ARITH-BINDING", duplicate_arith_binding)

    def remove_arith_binding(model: dict[str, Any]) -> None:
        types = module_by_name(model, "types")
        types["declarations"] = [
            item for item in types["declarations"] if item["tag"] != "DECL_ARITH_RESULT_BINDING"
        ]

    case("missing_arithmetic_binding", "F05-CORE-MISSING-ARITH-BINDING", remove_arith_binding)
    case(
        "constant_constraint_sort",
        "F05-CORE-CONSTANT-CONSTRAINT-SORT",
        lambda m: declaration(m, "DECL_CONSTANT_CONSTRAINT")["constraint"].__setitem__(
            "right", qn("types", "Amount")
        ),
    )

    def premise_constant_sort(model: dict[str, Any]) -> None:
        declaration(model, "DECL_PREMISE", "CarrierPremise")["body"] = {
            "tag": "PREMISE_CONST_EQ",
            "left": qn("types", "Always"),
            "right": qn("types", "Amount"),
        }

    case("premise_constant_sort", "F05-CORE-PREMISE-CONSTANT-SORT", premise_constant_sort)

    case(
        "term_annotation_forgery",
        "F05-CORE-TERM-ANNOTATION",
        lambda m: module_by_name(m, "app")["init_contribution"].__setitem__("result_sort", s_one()),
    )
    case(
        "unbound_variable",
        "F05-CORE-UNBOUND-VARIABLE",
        lambda m: declaration(m, "DECL_CLAIM_BASE_ALWAYS", "BaseInvariant").__setitem__(
            "invariant", t_var("ambient", s_bool())
        ),
    )

    def shadow_parameter(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["invoke"] = term(
            s_bool(),
            "TERM_LET",
            variable="parameter",
            bound=t_bool(),
            body=t_bool(),
        )

    case("action_parameter_shadow", "F05-CORE-BINDER-NOT-FRESH", shadow_parameter)

    def post_in_action(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["invoke"] = t_field(t_post(), "flag", s_bool())

    case("post_source_in_action", "F05-CORE-PROVENANCE-PHASE", post_in_action)

    def post_hidden_in_untaken_branch(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["invoke"] = term(
            s_bool(),
            "TERM_IF",
            condition=t_bool(),
            then=t_bool(),
            **{"else": t_field(t_post(), "flag", s_bool())},
        )

    case("static_provenance_untaken_branch", "F05-CORE-PROVENANCE-PHASE", post_hidden_in_untaken_branch)

    def missing_emit(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["emits"] = []

    case("event_channel_coverage", "F05-CORE-EMIT-CHANNEL-COVERAGE", missing_emit)

    def wrong_emit_sort(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["emits"][0]["value"] = t_bool()

    case("event_payload_sort", "F05-CORE-SORT-MISMATCH", wrong_emit_sort)

    def event_source_in_emit(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["emits"][0]["value"] = term(
            s_option(s_event()),
            "TERM_EVENT_GET",
            event_channel=qn("app", "Events"),
        )

    case("event_source_in_action_emit", "F05-CORE-PROVENANCE-PHASE", event_source_in_emit)

    def wrong_put_key(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["updates"][0]["key"] = t_one()

    case("put_key_sort", "F05-CORE-SORT-MISMATCH", wrong_put_key)

    def wrong_patch_domain(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["updates"][1]["domain"] = t_bool()

    case("patch_domain_sort", "F05-CORE-SORT-MISMATCH", wrong_patch_domain)

    def post_in_update(model: dict[str, Any]) -> None:
        declaration(model, "DECL_ACTION", "Operate")["branches"][0]["updates"][0]["value"] = t_post()

    case("post_source_in_update", "F05-CORE-PROVENANCE-PHASE", post_in_update)

    def bad_enum_member(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_ENUM")["node"]["member"] = "Missing"

    case("enum_member", "F05-CORE-ENUM-MEMBER", bad_enum_member)

    def bad_record_fields(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_RECORD")["node"]["values"] = []

    case("record_field_totality", "F05-CORE-RECORD-FIELDS", bad_record_fields)

    def bad_field_projection(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_FIELD")["node"]["field"] = "missing"

    case("record_projection", "F05-CORE-RECORD-FIELD", bad_field_projection)

    def bad_variant_payload(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_VARIANT")["node"]["payload"] = t_bool()

    case("variant_payload_sort", "F05-CORE-SORT-MISMATCH", bad_variant_payload)

    def incomplete_variant_match(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_MATCH_VARIANT")["node"]["branches"] = [
            find_term(module_by_name(model, "app")["init_contribution"], "TERM_MATCH_VARIANT")["node"]["branches"][0]
        ]

    case("variant_match_exhaustiveness", "F05-CORE-MATCH-VARIANT-EXHAUSTIVE", incomplete_variant_match)

    def invalid_quantifier_sort(model: dict[str, Any]) -> None:
        quantified = find_term(module_by_name(model, "app")["init_contribution"], "TERM_FORALL")
        quantified["node"]["sort"] = s_set(s_bool())
        quantified["node"]["body"] = t_bool()

    case("quantifier_collection_sort", "F05-CORE-QUANT-SORT", invalid_quantifier_sort)

    def wrong_state_key(model: dict[str, Any]) -> None:
        find_term(module_by_name(model, "app")["init_contribution"], "TERM_PRE_GET")["node"]["key"] = t_one()

    case("state_read_key_sort", "F05-CORE-SORT-MISMATCH", wrong_state_key)

    def duplicate_action_branch(model: dict[str, Any]) -> None:
        action = declaration(model, "DECL_ACTION", "Operate")
        action["branches"].append(copy.deepcopy(action["branches"][0]))

    case(
        "duplicate_action_branch_direct_boundary",
        "F05-CORE-DUPLICATE-ACTION-BRANCH",
        duplicate_action_branch,
    )

    def duplicate_channel_emit(model: dict[str, Any]) -> None:
        branch = declaration(model, "DECL_ACTION", "Operate")["branches"][0]
        branch["emits"].append(copy.deepcopy(branch["emits"][0]))

    case(
        "duplicate_channel_emit_direct_boundary",
        "F05-CORE-DUPLICATE-CHANNEL-EMIT",
        duplicate_channel_emit,
    )

    checker_binding_case_ids: list[str] = []

    def registry_case(
        case_id: str,
        attribute: str,
        mutate_registry: Callable[[dict[str, Any]], None],
    ) -> None:
        original = getattr(semantics.static_registry, attribute)
        tampered = dict(original)
        mutate_registry(tampered)
        setattr(semantics.static_registry, attribute, tampered)
        try:
            semantics.CoreSyntaxChecker.for_internal_test_model(copy.deepcopy(baseline)).check()
        except semantics.SemanticReject as exc:
            if exc.reject_id != "F05-CORE-RULE-REGISTRY-DRIFT":
                raise RuntimeError(
                    f"{case_id}: expected registry drift, got {exc.reject_id}: {exc.detail}"
                )
            cases.append({"id": case_id, "reject_id": exc.reject_id})
            checker_binding_case_ids.append(case_id)
        else:
            raise RuntimeError(f"{case_id}: registry drift was accepted")
        finally:
            setattr(semantics.static_registry, attribute, original)

    registry_case(
        "checker_term_registry_substitution",
        "TERM_HANDLERS",
        lambda rows: rows.__setitem__(
            "TERM_BOOL",
            rows["TERM_BOOL"]._replace(typing_rule="TYPE_ONE_LITERAL"),
        ),
    )
    registry_case(
        "checker_link_projection_registry_substitution",
        "DECLARATION_LINK_HANDLERS",
        lambda rows: rows.__setitem__(
            "DECL_ACTION",
            rows["DECL_ACTION"]._replace(
                body_fields=("parameter_variable", "branches")
            ),
        ),
    )
    registry_case(
        "checker_registry_boolean_integer_alias",
        "LINK_HANDLERS",
        lambda rows: rows.__setitem__("imports_authorize_effects", 0),
    )

    def patched_handler_case(
        case_id: str,
        expected: str,
        mutate_model: Mutation,
        build_handler: Callable[[Callable[..., Any]], Callable[..., Any]],
    ) -> None:
        model = copy.deepcopy(baseline)
        mutate_model(model)
        repin_imports(model)
        original = semantics.CoreSyntaxChecker._type_node
        semantics.CoreSyntaxChecker._type_node = build_handler(original)
        try:
            semantics.CoreSyntaxChecker.for_internal_test_model(model).check()
        except semantics.SemanticReject as exc:
            if exc.reject_id != expected:
                raise RuntimeError(
                    f"{case_id}: expected {expected}, got {exc.reject_id}: {exc.detail}"
                )
            cases.append({"id": case_id, "reject_id": exc.reject_id})
            checker_binding_case_ids.append(case_id)
        else:
            raise RuntimeError(f"{case_id}: checker implementation drift was accepted")
        finally:
            semantics.CoreSyntaxChecker._type_node = original

    def corrupt_result_handler(original: Callable[..., Any]) -> Callable[..., Any]:
        def patched(self: Any, node: Any, module: Any, environment: Any, path: Any, depth: Any, term_rule: Any):
            result = original(self, node, module, environment, path, depth, term_rule)
            if term_rule.typing_rule == "TYPE_BOOL_LITERAL":
                return semantics.Typed(semantics.sort_one(), result.provenance)
            return result

        return patched

    patched_handler_case(
        "checker_result_rederivation_detects_handler_drift",
        "F05-CORE-RULE-RESULT-DRIFT",
        lambda _model: None,
        corrupt_result_handler,
    )

    def corrupt_provenance_handler(original: Callable[..., Any]) -> Callable[..., Any]:
        def patched(self: Any, node: Any, module: Any, environment: Any, path: Any, depth: Any, term_rule: Any):
            result = original(self, node, module, environment, path, depth, term_rule)
            if term_rule.typing_rule == "TYPE_STATE_PRODUCT_PRE_GET":
                return semantics.Typed(result.sort, frozenset())
            return result

        return patched

    patched_handler_case(
        "checker_provenance_rederivation_detects_laundering",
        "F05-CORE-RULE-PROVENANCE-DRIFT",
        lambda _model: None,
        corrupt_provenance_handler,
    )

    def skip_if_operand_handler(original: Callable[..., Any]) -> Callable[..., Any]:
        def patched(self: Any, node: Any, module: Any, environment: Any, path: Any, depth: Any, term_rule: Any):
            if term_rule.typing_rule != "TYPE_BOOL_IF_COMMON_BRANCH":
                return original(self, node, module, environment, path, depth, term_rule)
            condition = self.type_term(
                node["condition"], module, environment, f"{path}.condition", depth
            )
            then = self.type_term(node["then"], module, environment, f"{path}.then", depth)
            self.require_sort(condition.sort, semantics.sort_bool(), f"{path}.condition")
            return semantics.Typed(then.sort, condition.provenance | then.provenance)

        return patched

    patched_handler_case(
        "checker_selector_detects_skipped_operand",
        "F05-CORE-RULE-OPERAND-NOT-TYPED",
        lambda _model: None,
        skip_if_operand_handler,
    )

    def make_let_bound_stateful(model: dict[str, Any]) -> None:
        let_term = find_term(module_by_name(model, "app")["init_contribution"], "TERM_LET")
        let_term["node"]["bound"] = t_field(t_pre(), "flag", s_bool())

    def corrupt_binder_context_handler(original: Callable[..., Any]) -> Callable[..., Any]:
        def patched(self: Any, node: Any, module: Any, environment: Any, path: Any, depth: Any, term_rule: Any):
            if term_rule.typing_rule != "TYPE_LET":
                return original(self, node, module, environment, path, depth, term_rule)
            variable = node["variable"]
            self.require_fresh(variable, environment, path)
            bound = self.type_term(node["bound"], module, environment, f"{path}.bound", depth)
            extended = dict(environment)
            extended[variable] = semantics.Typed(bound.sort, frozenset())
            body = self.type_term(node["body"], module, extended, f"{path}.body", depth)
            return semantics.Typed(body.sort, bound.provenance | body.provenance)

        return patched

    patched_handler_case(
        "checker_binder_context_detects_provenance_reset",
        "F05-CORE-RULE-CONTEXT-DRIFT",
        make_let_bound_stateful,
        corrupt_binder_context_handler,
    )

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "CoreSyntaxWF_static_checker_hostile_regression_only",
                "positive_model_sha256": accepted["model_sha256"],
                "source_term_constructors_total": len(expected_source_tags),
                "source_term_constructors_covered": len(actual_source_tags),
                "relation_only_term_constructors_checked": ["TERM_EVENT_GET", "TERM_POST_GET"],
                "immutable_snapshot_reads": model_reads,
                "deep_import_DAG_modules_checked": deep_counts["module_count"],
                "deep_named_type_DAG_declarations_checked": deep_type_counts[
                    "declaration_count"
                ],
                "resource_inconclusive_reason_checked": resource_reason,
                "independent_sibling_actions_checked": composed_counts["action_count"],
                "dormant_source_actions_checked": dormant_counts["action_count"],
                "dormant_linked_active_actions": dormant_counts["active_action_count"],
                "mutations_total": len(cases),
                "mutations_rejected_at_expected_id": len(cases),
                "checker_binding_mutations_total": len(checker_binding_case_ids),
                "checker_binding_mutation_ids": checker_binding_case_ids,
                "sort_dispatch_handlers_exercised": len(actual_dispatch["sort"]),
                "premise_dispatch_handlers_exercised": len(actual_dispatch["premise"]),
                "term_dispatch_handlers_exercised": len(actual_dispatch["term"]),
                "update_dispatch_handlers_exercised": len(actual_dispatch["update"]),
                "body_dispatch_handlers_exercised": len(actual_dispatch["body"]),
                "binder_dispatch_handlers_exercised": len(actual_dispatch["binder"]),
                "results": cases,
                "InstanceWF": False,
                "ClaimPackageWF": False,
                "evaluation_validated": False,
                "transition_semantics_validated": False,
                "proof_validation": False,
                "F0_local_acceptance": False,
                "K0_G0_complete": False,
                "model_supported": False,
                "protection_claim": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
