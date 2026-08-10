#!/usr/bin/env python3
"""Finite Eval/DynDeps/MayDeps hostile regression for DL-F0-5."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


fixture = load_module("f0_core_fixture_for_eval", HERE / "test-f0-core-syntax-v5.py")
eval_module = load_module("f0_eval_v5_test", HERE / "f0_eval_v5.py")
values = eval_module.values_module


def v_bool(value: bool) -> dict[str, Any]:
    return {"tag": "VALUE_BOOL", "value": value}


def v_one() -> dict[str, Any]:
    return {"tag": "VALUE_ONE"}


def v_qty(value: int) -> dict[str, Any]:
    return {
        "tag": "VALUE_QTY",
        "unit": fixture.qn("types", "Tick"),
        "limit": fixture.qn("types", "MaxTick"),
        "value": value,
    }


def v_pair(flag: bool, amount: int = 1) -> dict[str, Any]:
    return {
        "tag": "VALUE_RECORD",
        "record": fixture.qn("types", "Pair"),
        "values": [
            {"tag": "GROUND_FIELD_ENTRY", "field": "amount", "value": v_qty(amount)},
            {"tag": "GROUND_FIELD_ENTRY", "field": "flag", "value": v_bool(flag)},
        ],
    }


def v_event(tag: str = "Changed") -> dict[str, Any]:
    return {
        "tag": "VALUE_VARIANT",
        "variant": fixture.qn("types", "EventPayload"),
        "variant_tag": tag,
        "payload": v_one(),
    }


def v_some(element_sort: dict[str, Any], value: dict[str, Any]) -> dict[str, Any]:
    return {"tag": "VALUE_SOME", "element_sort": element_sort, "value": value}


def linked_fixture() -> tuple[dict[str, Any], dict[str, Any]]:
    model = fixture.model_fixture()
    checker = fixture.semantics.CoreSyntaxChecker.for_internal_test_model(model)
    checker.check()
    if checker.linked_model_snapshot is None:
        raise RuntimeError("missing linked model")
    return model, checker.linked_model_snapshot.artifact()


def profile_fixture(linked: dict[str, Any]) -> dict[str, Any]:
    pair_map = {
        "tag": "VALUE_TOTALMAP",
        "key_sort": fixture.s_bool(),
        "value_sort": fixture.s_pair(),
        "entries": [
            {"tag": "GROUND_MAP_ENTRY", "key": v_bool(False), "value": v_pair(False)},
            {"tag": "GROUND_MAP_ENTRY", "key": v_bool(True), "value": v_pair(True)},
        ],
    }
    profile = {
        "tag": "FINITE_PROFILE",
        "interpretation_id": fixture.qn("profile", "Tiny"),
        "model_sha256": linked["source_binding"]["canonical_model_sha256"],
        "atom_carriers": [
            {
                "tag": "ATOM_CARRIER",
                "atom": fixture.qn("types", "Entity"),
                "values": [
                    {
                        "tag": "ATOM_VALUE",
                        "atom": fixture.qn("types", "Entity"),
                        "value": "entity0",
                    }
                ],
            }
        ],
        "limits": [
            {
                "tag": "LIMIT_VALUE",
                "limit": fixture.qn("types", "MaxTick"),
                "value": 2,
            }
        ],
        "constants": [
            {
                "tag": "CONSTANT_VALUE",
                "constant": fixture.qn("types", "Always"),
                "value": v_bool(True),
            },
            {
                "tag": "CONSTANT_VALUE",
                "constant": fixture.qn("types", "Amount"),
                "value": v_qty(1),
            },
            {
                "tag": "CONSTANT_VALUE",
                "constant": fixture.qn("types", "BoolSet"),
                "value": {
                    "tag": "VALUE_FINSET",
                    "element_sort": fixture.s_bool(),
                    "values": [v_bool(False), v_bool(True)],
                },
            },
            {
                "tag": "CONSTANT_VALUE",
                "constant": fixture.qn("types", "PairMap"),
                "value": pair_map,
            },
        ],
    }
    fixture.canonicalize_collections(profile)
    return profile


def state_fixture(false_flag: bool = False, true_flag: bool = True) -> dict[str, Any]:
    state = {
        "tag": "STATE_VALUE",
        "cells": [
            {
                "tag": "CELL_VALUE",
                "location": {
                    "tag": "LOCATION_VALUE",
                    "state_product": fixture.qn("app", "Queue"),
                    "key": v_bool(False),
                },
                "value": v_pair(false_flag),
            },
            {
                "tag": "CELL_VALUE",
                "location": {
                    "tag": "LOCATION_VALUE",
                    "state_product": fixture.qn("app", "Queue"),
                    "key": v_bool(True),
                },
                "value": v_pair(true_flag),
            },
        ],
    }
    fixture.canonicalize_collections(state)
    return state


def event_fixture() -> dict[str, Any]:
    event_sort = fixture.s_event()
    event = {
        "tag": "EVENT_BUNDLE_VALUE",
        "channels": [
            {
                "tag": "EVENT_CHANNEL_VALUE",
                "event_channel": fixture.qn("app", "Events"),
                "value": v_some(event_sort, v_event()),
            }
        ],
    }
    fixture.canonicalize_collections(event)
    return event


def t_state_flag(key: dict[str, Any], post: bool = False) -> dict[str, Any]:
    state_term = fixture.term(
        fixture.s_pair(),
        "TERM_POST_GET" if post else "TERM_PRE_GET",
        state_product=fixture.qn("app", "Queue"),
        key=key,
    )
    return fixture.t_field(state_term, "flag", fixture.s_bool())


def dep_signature(result: eval_module.EvaluationResult) -> set[tuple[str, bool | None]]:
    output: set[tuple[str, bool | None]] = set()
    for dependency in result.observation.dependencies:
        key = dependency.key.payload[0] if dependency.key is not None else None
        output.add((dependency.kind, key))
    return output


def expect_value_reject(case_id: str, expected: str, function) -> dict[str, str]:
    try:
        function()
    except values.Reject as exc:
        if exc.reject_id != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {exc.reject_id}")
        return {"id": case_id, "reject_id": exc.reject_id}
    raise RuntimeError(f"{case_id}: unexpectedly accepted")


def expect_eval_reject(case_id: str, expected: str, function) -> dict[str, str]:
    try:
        function()
    except eval_module.EvalReject as exc:
        if exc.reject_id != expected:
            raise RuntimeError(f"{case_id}: expected {expected}, got {exc.reject_id}")
        return {"id": case_id, "reject_id": exc.reject_id}
    raise RuntimeError(f"{case_id}: unexpectedly accepted")


def main() -> int:
    _, linked = linked_fixture()
    interpretation = values.FiniteInterpretation.decode(linked, profile_fixture(linked))
    pre = values.StateView.decode(state_fixture(), interpretation)
    post = values.StateView.decode(state_fixture(true_flag=False), interpretation)
    event = values.EventView.decode(event_fixture(), interpretation)
    evaluator = eval_module.FiniteEvaluator(interpretation)

    linked_model = linked["linked_model"]
    init_term = linked_model["init"]["body"]
    init_result = evaluator.evaluate_root(
        init_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    if init_result.observation.value.payload != (True,):
        raise RuntimeError("init fixture did not evaluate true")

    condition = t_state_flag(fixture.t_bool(True))
    selected = t_state_flag(fixture.t_bool(False))
    branch_term = fixture.term(
        fixture.s_bool(),
        "TERM_IF",
        condition=condition,
        then=selected,
        **{"else": fixture.t_bool(True)},
    )
    branch_result = evaluator.evaluate_root(
        branch_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    if dep_signature(branch_result) != {("PRE", False), ("PRE", True)}:
        raise RuntimeError("selected branch dependencies are wrong")

    condition_false_state = values.StateView.decode(
        state_fixture(false_flag=False, true_flag=False), interpretation
    )
    condition_false_result = evaluator.evaluate_root(
        branch_term,
        {},
        {},
        eval_module.EvalInputs(pre=condition_false_state),
        frozenset({"PRE"}),
    )
    outside_changed_state = values.StateView.decode(
        state_fixture(false_flag=True, true_flag=False), interpretation
    )
    stable_result = evaluator.evaluate_root(
        branch_term,
        {},
        {},
        eval_module.EvalInputs(pre=outside_changed_state),
        frozenset({"PRE"}),
    )
    if dep_signature(condition_false_result) != {("PRE", True)}:
        raise RuntimeError("untaken branch was evaluated")
    if (
        stable_result.observation.value != condition_false_result.observation.value
        or stable_result.observation.dependencies
        != condition_false_result.observation.dependencies
    ):
        raise RuntimeError("outside-footprint mutation violated one-sided stability")

    strict_term = fixture.term(
        fixture.s_bool(),
        "TERM_AND",
        operands=[fixture.t_bool(False), t_state_flag(fixture.t_bool(True))],
    )
    strict_result = evaluator.evaluate_root(
        strict_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    if dep_signature(strict_result) != {("PRE", True)}:
        raise RuntimeError("strict boolean was short-circuited")

    quantified_term = fixture.term(
        fixture.s_bool(),
        "TERM_FORALL",
        variable="quantified_key",
        sort=fixture.s_bool(),
        body=fixture.t_eq(
            t_state_flag(fixture.t_var("quantified_key", fixture.s_bool())),
            t_state_flag(fixture.t_var("quantified_key", fixture.s_bool())),
        ),
    )
    quantified_result = evaluator.evaluate_root(
        quantified_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    if dep_signature(quantified_result) != {("PRE", False), ("PRE", True)}:
        raise RuntimeError("quantifier did not evaluate the full carrier")

    atom_sort = {"tag": "SORT_ATOM", "atom": fixture.qn("types", "Entity")}
    atom_quantifier = fixture.term(
        fixture.s_bool(),
        "TERM_FORALL",
        variable="entity",
        sort=atom_sort,
        body=fixture.t_bool(True),
    )
    atom_result = evaluator.evaluate_root(
        atom_quantifier,
        {},
        {},
        eval_module.EvalInputs(),
        frozenset(),
    )
    atom_refs = {ref.kind for ref in atom_result.observation.interpretation_refs}
    if not {"DECLARATION", "ATOM_CARRIER"} <= atom_refs:
        raise RuntimeError("quantifier omitted finite carrier interpretation references")

    parameter_value = interpretation.decode_value(v_bool(True), fixture.s_bool(), "$parameter")
    parameter_term = fixture.t_var("parameter", fixture.s_bool())
    parameter_result = evaluator.evaluate_root(
        parameter_term,
        {
            "parameter": eval_module.EnvBinding.external_parameter(
                parameter_value,
                ("ACTION", "app.Operate", "PARAMETER_SLOT"),
            )
        },
        {
            "parameter": eval_module.GammaBinding.create(
                fixture.s_bool(),
                frozenset({"PARAM"}),
                ("ACTION", "app.Operate", "PARAMETER_SLOT"),
            )
        },
        eval_module.EvalInputs(),
        frozenset({"PARAM"}),
    )
    if {dependency.kind for dependency in parameter_result.observation.dependencies} != {"PARAM"}:
        raise RuntimeError("parameter dependency disappeared")

    post_result = evaluator.evaluate_root(
        t_state_flag(fixture.t_bool(True), post=True),
        {},
        {},
        eval_module.EvalInputs(post=post),
        frozenset({"POST"}),
    )
    if {dependency.kind for dependency in post_result.observation.dependencies} != {"POST"}:
        raise RuntimeError("POST dependency was erased")

    event_term = fixture.term(
        fixture.s_option(fixture.s_event()),
        "TERM_EVENT_GET",
        event_channel=fixture.qn("app", "Events"),
    )
    event_result = evaluator.evaluate_root(
        event_term,
        {},
        {},
        eval_module.EvalInputs(event=event),
        frozenset({"EVENT"}),
    )
    if {dependency.kind for dependency in event_result.observation.dependencies} != {"EVENT"}:
        raise RuntimeError("EVENT dependency disappeared")

    action = linked_model["action_bodies"][0]
    action_environment = {
        action["parameter_variable"]: eval_module.EnvBinding.external_parameter(
            parameter_value,
            ("ACTION", "app.Operate", "PARAMETER_SLOT"),
        )
    }
    action_gamma = {
        action["parameter_variable"]: eval_module.GammaBinding.create(
            action["parameter_sort"],
            frozenset({"PARAM"}),
            ("ACTION", "app.Operate", "PARAMETER_SLOT"),
        )
    }
    action_cases = (
        (action["invoke"], frozenset(), eval_module.EvalInputs()),
        (action["branches"][0]["guard"], frozenset(), eval_module.EvalInputs()),
        (
            action["branches"][0]["updates"][0]["key"],
            frozenset({"PARAM"}),
            eval_module.EvalInputs(),
        ),
        (
            action["branches"][0]["updates"][0]["value"],
            frozenset({"PARAM", "PRE"}),
            eval_module.EvalInputs(pre=pre),
        ),
        (action["branches"][0]["updates"][1]["domain"], frozenset(), eval_module.EvalInputs()),
        (action["branches"][0]["updates"][1]["values"], frozenset(), eval_module.EvalInputs()),
        (action["branches"][0]["event_coordinates"][0]["value"], frozenset(), eval_module.EvalInputs()),
    )
    for term, term_sources, term_inputs in action_cases:
        evaluator.evaluate_root(
            term,
            action_environment,
            action_gamma,
            term_inputs,
            term_sources,
        )

    if set(evaluator.term_tag_counts) != eval_module.EXPECTED_TERM_TAGS:
        missing = sorted(eval_module.EXPECTED_TERM_TAGS - set(evaluator.term_tag_counts))
        raise RuntimeError(f"constructor execution coverage incomplete: {missing}")

    dynamic_key_term = t_state_flag(t_state_flag(fixture.t_bool(True)))
    dynamic_key_result = evaluator.evaluate_root(
        dynamic_key_term,
        {},
        {},
        eval_module.EvalInputs(pre=condition_false_state),
        frozenset({"PRE"}),
    )
    dynamic_trace_keys = [
        dependency.key.payload[0]
        for dependency in dynamic_key_result.observation.access_trace
        if dependency.kind == "PRE" and dependency.key is not None
    ]
    if dynamic_trace_keys != [True, False]:
        raise RuntimeError(f"dynamic-key access order is wrong: {dynamic_trace_keys}")

    unselected_post_term = fixture.term(
        fixture.s_bool(),
        "TERM_IF",
        condition=fixture.t_bool(True),
        then=fixture.t_bool(True),
        **{"else": t_state_flag(fixture.t_bool(True), post=True)},
    )
    unselected_post_result = evaluator.evaluate_root(
        unselected_post_term,
        {},
        {},
        eval_module.EvalInputs(post=post),
        frozenset({"POST"}),
    )
    if unselected_post_result.observation.dependencies:
        raise RuntimeError("unselected POST branch produced dynamic dependencies")
    if {dependency.kind for dependency in unselected_post_result.may_dependencies} != {"POST"}:
        raise RuntimeError("MayDeps omitted the unselected POST branch")

    none_event_raw = event_fixture()
    none_event_raw["channels"][0]["value"] = {
        "tag": "VALUE_NONE",
        "element_sort": fixture.s_event(),
    }
    fixture.canonicalize_collections(none_event_raw)
    none_event = values.EventView.decode(none_event_raw, interpretation)
    none_event_result = evaluator.evaluate_root(
        event_term,
        {},
        {},
        eval_module.EvalInputs(event=none_event),
        frozenset({"EVENT"}),
    )
    if none_event_result.observation.value.constructor != "VALUE_NONE" or not none_event_result.observation.dependencies:
        raise RuntimeError("typed None event was mistaken for no channel access")

    checked_overflow = evaluator.evaluate_root(
        fixture.t_qty_checked(3),
        {},
        {},
        eval_module.EvalInputs(),
        frozenset(),
    )
    if checked_overflow.observation.value.payload[1] != "Overflow":
        raise RuntimeError("QtyChecked overflow is wrong")
    subtraction = fixture.term(
        fixture.s_arith(),
        "TERM_QTY_SUB",
        left=fixture.t_qty_zero(),
        right=fixture.t_const("Amount", fixture.s_qty()),
    )
    underflow = evaluator.evaluate_root(
        subtraction,
        {},
        {},
        eval_module.EvalInputs(),
        frozenset(),
    )
    if underflow.observation.value.payload[1] != "Underflow":
        raise RuntimeError("Qty subtraction underflow is wrong")

    pair_map_term = fixture.t_const(
        "PairMap", fixture.s_map(fixture.s_bool(), fixture.s_pair())
    )
    same_false_pair = fixture.t_pair(
        flag=fixture.t_bool(False),
        amount=fixture.t_const("Amount", fixture.s_qty()),
    )
    same_map = fixture.term(
        fixture.s_map(fixture.s_bool(), fixture.s_pair()),
        "TERM_MAP_SET",
        map=copy.deepcopy(pair_map_term),
        key=fixture.t_bool(False),
        value=same_false_pair,
    )
    extensional_equality = evaluator.evaluate_root(
        fixture.t_eq(pair_map_term, same_map),
        {},
        {},
        eval_module.EvalInputs(),
        frozenset(),
    )
    if extensional_equality.observation.value.payload != (True,):
        raise RuntimeError("TotalMap equality was not extensional")

    bad_profile = profile_fixture(linked)
    pair_map = next(
        row["value"]
        for row in bad_profile["constants"]
        if row["constant"] == fixture.qn("types", "PairMap")
    )
    pair_map["entries"].pop()
    failures = [
        expect_value_reject(
            "total-map-missing-key",
            "F05-EVAL-GROUND-TOTALMAP-DOMAIN",
            lambda: values.FiniteInterpretation.decode(linked, bad_profile),
        )
    ]

    int_bool_profile = profile_fixture(linked)
    next(
        row for row in int_bool_profile["constants"]
        if row["constant"] == fixture.qn("types", "Always")
    )["value"]["value"] = 1
    failures.append(
        expect_value_reject(
            "bool-int-confusion",
            "F05-EVAL-GROUND-BOOL",
            lambda: values.FiniteInterpretation.decode(linked, int_bool_profile),
        )
    )

    over_limit_profile = profile_fixture(linked)
    next(
        row for row in over_limit_profile["constants"]
        if row["constant"] == fixture.qn("types", "Amount")
    )["value"]["value"] = 3
    failures.append(
        expect_value_reject(
            "quantity-over-profile-limit",
            "F05-EVAL-GROUND-QTY-BOUND",
            lambda: values.FiniteInterpretation.decode(linked, over_limit_profile),
        )
    )

    missing_state = state_fixture()
    missing_state["cells"].pop()
    failures.append(
        expect_value_reject(
            "state-missing-cell",
            "F05-EVAL-STATE-DOMAIN",
            lambda: values.StateView.decode(missing_state, interpretation),
        )
    )

    missing_event = event_fixture()
    missing_event["channels"].clear()
    failures.append(
        expect_value_reject(
            "event-missing-channel",
            "F05-EVAL-EVENT-DOMAIN",
            lambda: values.EventView.decode(missing_event, interpretation),
        )
    )

    false_key = interpretation.decode_value(v_bool(False), fixture.s_bool(), "$false_key")
    forged_environment = {
        "parameter": eval_module.EnvBinding.external(
            parameter_value,
            frozenset(
                {
                    eval_module.state_dep(
                        "PRE", ("app", "Queue"), false_key
                    )
                }
            ),
        )
    }
    parameter_gamma = {
        "parameter": eval_module.GammaBinding.create(
            fixture.s_bool(),
            frozenset({"PARAM"}),
            ("ACTION", "app.Operate", "PARAMETER_SLOT"),
        )
    }
    failures.append(
        expect_eval_reject(
            "gamma-origin-substitution",
            "F05-EVAL-ROOT-GAMMA-PARAM-SLOT",
            lambda: evaluator.evaluate_root(
                parameter_term,
                forged_environment,
                parameter_gamma,
                eval_module.EvalInputs(),
                frozenset({"PARAM"}),
            ),
        )
    )

    failures.append(
        expect_value_reject(
            "constructor-sort-confusion",
            "F05-EVAL-VALUE-CONSTRUCTOR-SORT",
            lambda: evaluator.evaluate_root(
                fixture.term(fixture.s_bool(), "TERM_ONE"),
                {},
                {},
                eval_module.EvalInputs(),
                frozenset(),
            ),
        )
    )

    event_origin = eval_module.event_dep(("app", "Events"))
    failures.append(
        expect_eval_reject(
            "arbitrary-root-event-binding",
            "F05-EVAL-ROOT-CONTEXT",
            lambda: evaluator.evaluate_root(
                parameter_term,
                {
                    "parameter": eval_module.EnvBinding.external(
                        parameter_value,
                        frozenset({event_origin}),
                    )
                },
                {
                    "parameter": eval_module.GammaBinding.create(
                        fixture.s_bool(), frozenset({"EVENT"})
                    )
                },
                eval_module.EvalInputs(event=event),
                frozenset({"EVENT"}),
            ),
        )
    )
    failures.append(
        expect_eval_reject(
            "extra-pre-view",
            "F05-EVAL-ROOT-INPUT-DOMAIN",
            lambda: evaluator.evaluate_root(
                fixture.t_bool(True),
                {},
                {},
                eval_module.EvalInputs(pre=pre),
                frozenset(),
            ),
        )
    )
    failures.append(
        expect_eval_reject(
            "missing-pre-view",
            "F05-EVAL-ROOT-INPUT-DOMAIN",
            lambda: evaluator.evaluate_root(
                t_state_flag(fixture.t_bool(True)),
                {},
                {},
                eval_module.EvalInputs(),
                frozenset({"PRE"}),
            ),
        )
    )

    per_request_evaluator = eval_module.FiniteEvaluator(
        interpretation,
        resource_profile=values.ResourceProfile(max_carrier_values=2),
    )
    first_request = per_request_evaluator.evaluate_root(
        quantified_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    second_request = per_request_evaluator.evaluate_root(
        quantified_term,
        {},
        {},
        eval_module.EvalInputs(pre=pre),
        frozenset({"PRE"}),
    )
    if (
        first_request.usage["carrier_values"] != 2
        or second_request.usage["carrier_values"] != 2
    ):
        raise RuntimeError("carrier cache or usage leaked across root requests")

    tiny_resource = values.ResourceProfile(max_carrier_values=1)
    try:
        limited = values.FiniteInterpretation.decode(linked, profile_fixture(linked), tiny_resource)
        limited.enumerate_sort(fixture.s_bool())
    except values.Inconclusive as exc:
        if exc.reason_id != "F05-EVAL-INCONCLUSIVE-RESOURCE":
            raise
        failures.append({"id": "resource-is-inconclusive", "reason_id": exc.reason_id})
    else:
        raise RuntimeError("resource exhaustion did not become inconclusive")

    may_heavy_term = fixture.term(
        fixture.s_bool(),
        "TERM_IF",
        condition=fixture.t_bool(True),
        then=fixture.t_bool(True),
        **{
            "else": fixture.term(
                fixture.s_bool(),
                "TERM_AND",
                operands=[fixture.t_bool(True) for _ in range(8)],
            )
        },
    )
    may_limited = eval_module.FiniteEvaluator(
        interpretation,
        resource_profile=values.ResourceProfile(max_may_term_visits=4),
    )
    try:
        may_limited.evaluate_root(
            may_heavy_term,
            {},
            {},
            eval_module.EvalInputs(),
            frozenset(),
        )
    except values.Inconclusive as exc:
        if exc.reason_id != "F05-EVAL-INCONCLUSIVE-RESOURCE":
            raise
        failures.append({"id": "may-traversal-is-resource-bounded", "reason_id": exc.reason_id})
    else:
        raise RuntimeError("MayDeps traversal bypassed its resource profile")

    linked_mutation = copy.deepcopy(linked)
    color_signature = next(
        row["signature"]
        for row in linked_mutation["linked_model"]["sigma"]["declaration_signatures"]
        if row["declaration_tag"] == "DECL_ENUM"
        and row["signature"]["name"] == fixture.qn("types", "Color")
    )
    color_signature["members"].append("ForgedAfterDecode")
    color_values = interpretation.enumerate_sort(
        {"tag": "SORT_ENUM", "enum": fixture.qn("types", "Color")}
    )
    if len(color_values) != 2:
        raise RuntimeError("linked-model mutation changed a decoded interpretation")

    duplicate_product = copy.deepcopy(linked)
    duplicate_product["linked_model"]["sigma"]["state_product_carriers"].append(
        copy.deepcopy(
            duplicate_product["linked_model"]["sigma"]["state_product_carriers"][0]
        )
    )
    failures.append(
        expect_value_reject(
            "duplicate-linked-state-product",
            "F05-EVAL-LINKED-DUPLICATE-STATE-PRODUCT",
            lambda: values.FiniteInterpretation.decode(
                duplicate_product, profile_fixture(duplicate_product)
            ),
        )
    )

    noncanonical_profile = profile_fixture(linked)
    noncanonical_profile["constants"][0], noncanonical_profile["constants"][1] = (
        noncanonical_profile["constants"][1],
        noncanonical_profile["constants"][0],
    )
    failures.append(
        expect_value_reject(
            "noncanonical-profile-order",
            "F05-EVAL-CANONICAL-COLLECTION",
            lambda: values.FiniteInterpretation.decode(linked, noncanonical_profile),
        )
    )

    try:
        eval_module.EvaluationResult(
            observation=init_result.observation,
            may_dependencies=init_result.may_dependencies,
            usage=init_result.usage,
            resource_profile=init_result.resource_profile,
            resource_profile_sha256=init_result.resource_profile_sha256,
            rule_table_canonical_sha256=init_result.rule_table_canonical_sha256,
            authority="forged",
        )
    except TypeError:
        failures.append({"id": "construction-result-authority-not-initializable", "reject_id": "TYPE_ERROR"})
    else:
        raise RuntimeError("construction result authority was caller-controlled")

    output = {
        "schema_version": 1,
        "status": "construction_finite_eval_dependency_regression_passed",
        "constructor_execution_coverage": sorted(evaluator.term_tag_counts),
        "constructor_count": len(evaluator.term_tag_counts),
        "checks": failures,
        "strict_boolean_read_preserved": True,
        "quantifier_full_carrier_preserved": True,
        "pre_post_event_param_distinct": True,
        "trace_projection_equal": True,
        "maydeps_contains_dyndeps": True,
        "delta_not_rho_seeds_maydeps": True,
        "interpretation_carrier_refs_present": True,
        "checked_term_occurrence_bound": False,
        "evaluation_validated": False,
        "F0_local_acceptance": False,
        "protection_claim": False,
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
