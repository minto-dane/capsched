#!/usr/bin/env python3
"""Hostile construction tests for the DL-F0-5 LinkedModel projection."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
from dataclasses import replace
from pathlib import Path
from types import MappingProxyType
from typing import Any


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(specification)
    sys.modules[name] = module
    specification.loader.exec_module(module)
    return module


fixtures = load_module(
    "test_f0_core_syntax_v5_for_link",
    HERE / "test-f0-core-syntax-v5.py",
)
semantics = fixtures.semantics


def checked(model: dict[str, Any]) -> tuple[Any, dict[str, Any], dict[str, Any]]:
    fixtures.repin_imports(model)
    checker = semantics.CoreSyntaxChecker.for_internal_test_model(model)
    counts = checker.check()
    return checker, counts, checker.linked_model_object()


def named(entries: list[dict[str, Any]], local: str) -> dict[str, Any]:
    for entry in entries:
        if entry["name"][1] == local:
            return entry
    raise KeyError(local)


def add_dormant_policy_bodies(model: dict[str, Any]) -> None:
    side = fixtures.module_by_name(model, "side")
    side["declarations"].extend(
        [
            {
                "tag": "DECL_CONSTANT_CONSTRAINT",
                "constraint": {
                    "tag": "CONSTANT_CONSTRAINT",
                    "relation": "EQ",
                    "left": fixtures.qn("types", "Always"),
                    "right": fixtures.qn("types", "Always"),
                },
            },
            {
                "tag": "DECL_PREMISE",
                "name": fixtures.qn("side", "DormantPremise"),
                "body": {
                    "tag": "PREMISE_LIMIT_GE_NAT",
                    "limit": fixtures.qn("types", "MaxTick"),
                    "bound": 0,
                },
            },
            {
                "tag": "DECL_CLAIM_BASE_ALWAYS",
                "name": fixtures.qn("side", "DormantClaim"),
                "invariant": fixtures.t_bool(),
            },
        ]
    )


def add_inactive_channel(model: dict[str, Any]) -> None:
    side = fixtures.module_by_name(model, "side")
    side["declarations"].append(
        {
            "tag": "DECL_EVENT_CHANNEL",
            "name": fixtures.qn("side", "ExtraEvents"),
            "payload_variant": fixtures.qn("types", "EventPayload"),
        }
    )
    action = fixtures.declaration(model, "DECL_ACTION", "SideAction")
    action["branches"][0]["emits"].append(
        {
            "tag": "CHANNEL_EMIT",
            "event_channel": fixtures.qn("side", "ExtraEvents"),
            "value": fixtures.term(
                fixtures.s_option(fixtures.s_event()),
                "TERM_NONE",
                element_sort=fixtures.s_event(),
            ),
        }
    )


def add_inactive_state_product(model: dict[str, Any]) -> None:
    fixtures.module_by_name(model, "side")["declarations"].append(
        {
            "tag": "DECL_STATE_PRODUCT",
            "name": fixtures.qn("side", "DormantState"),
            "key_sort": fixtures.s_bool(),
            "value_sort": fixtures.s_bool(),
        }
    )


def id_sha(counts: dict[str, Any], field: str) -> str:
    return counts[field]["sha256"]


def manifest_id(
    checker: Any,
    manifest: str,
    id_field: str,
    predicate: Any,
) -> dict[str, Any]:
    return next(
        entry[id_field]
        for entry in checker.linked_model_snapshot.source_binding()[manifest]
        if predicate(entry)
    )


def replace_string(value: Any, old: str, new: str) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if isinstance(child, str) and child == old:
                value[key] = new
            else:
                replace_string(child, old, new)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            if isinstance(child, str) and child == old:
                value[index] = new
            else:
                replace_string(child, old, new)


def main() -> int:
    all_active = fixtures.independent_module_composition_fixture()
    checker, counts, linked = checked(copy.deepcopy(all_active))
    if counts["linked_model_materialized"] is not True:
        raise RuntimeError("LinkedModel construction was not reported")
    if counts["linked_model_independently_validated"] is not False:
        raise RuntimeError("construction must not self-attest independent validation")
    if linked["dependency_modules"] != ["app", "root", "side", "types"]:
        raise RuntimeError("dependency module domain drift")
    if linked["active_modules"] != ["app", "root", "side", "types"]:
        raise RuntimeError("active module domain drift")
    if len(linked["sigma"]["state_product_carriers"]) != 1:
        raise RuntimeError("state carrier projection drift")
    if len(linked["sigma"]["event_channel_carriers"]) != 2:
        raise RuntimeError("event carrier projection drift")
    if len(linked["sigma"]["empty_event_template"]) != 2:
        raise RuntimeError("EmptyEvent did not totalize every channel")
    if [entry["module_name"] for entry in linked["init"]["ordered_contributions"]] != [
        "app",
        "root",
        "side",
        "types",
    ]:
        raise RuntimeError("active init order is not canonical ModuleName order")
    if linked["init"]["form"] != "UNFLATTENED_OUTER_AND":
        raise RuntimeError("multi-module init did not preserve outer conjunction")
    if linked["init"]["body"]["node"]["operands"][0]["node"]["tag"] != "TERM_AND":
        raise RuntimeError("nested source conjunction was flattened")

    link_contract = checker.rule_contract.link_materialization
    mutated_contracts: list[tuple[str, Any]] = []

    def add_link_mutation(case_id: str, mutated_link: Any) -> None:
        mutated_contracts.append(
            (
                case_id,
                replace(
                    checker.rule_contract,
                    link_materialization=mutated_link,
                ),
            )
        )

    add_link_mutation(
        "status",
        replace(link_contract, status=link_contract.status + "_MUTATED"),
    )
    for tag, rule in link_contract.declaration_rules.items():
        rows = dict(link_contract.declaration_rules)
        rows[tag] = replace(
            rule,
            signature_fields=rule.signature_fields + ("__mutated_field__",),
        )
        add_link_mutation(
            f"declaration_rule_{tag}",
            replace(link_contract, declaration_rules=MappingProxyType(rows)),
        )
    for tag, rule in link_contract.always_linked_rules.items():
        rows = dict(link_contract.always_linked_rules)
        rows[tag] = replace(rule, target=rule.target + "_MUTATED")
        add_link_mutation(
            f"always_linked_rule_{tag}",
            replace(link_contract, always_linked_rules=MappingProxyType(rows)),
        )
    for field, value in link_contract.module_init.items():
        row = dict(link_contract.module_init)
        row[field] = value + "_MUTATED"
        add_link_mutation(
            f"module_init_{field}",
            replace(link_contract, module_init=MappingProxyType(row)),
        )
    for field, value in link_contract.event_totalization.items():
        row = dict(link_contract.event_totalization)
        row[field] = value + "_MUTATED"
        add_link_mutation(
            f"event_totalization_{field}",
            replace(link_contract, event_totalization=MappingProxyType(row)),
        )
    for field, value in link_contract.identity.items():
        row = dict(link_contract.identity)
        row[field] = value + "_MUTATED"
        add_link_mutation(
            f"identity_{field}",
            replace(link_contract, identity=MappingProxyType(row)),
        )
    for kind, rule in link_contract.identity_preimages.items():
        rows = dict(link_contract.identity_preimages)
        rows[kind] = replace(rule, stability=rule.stability + "_MUTATED")
        add_link_mutation(
            f"identity_preimage_{kind}",
            replace(link_contract, identity_preimages=MappingProxyType(rows)),
        )
    add_link_mutation(
        "source_binding_fields",
        replace(
            link_contract,
            source_binding_fields=tuple(reversed(link_contract.source_binding_fields)),
        ),
    )
    add_link_mutation(
        "linked_model_fields",
        replace(
            link_contract,
            linked_model_fields=tuple(reversed(link_contract.linked_model_fields)),
        ),
    )
    add_link_mutation(
        "final_identity_issued",
        replace(link_contract, final_identity_issued=True),
    )
    for case_id, mutated_contract in mutated_contracts:
        try:
            semantics.linked_model.materialize(
                checker.source_snapshot,
                mutated_contract,
                semantics.reject,
            )
        except semantics.SemanticReject as exc:
            if exc.reject_id != "F05-LINK-RULE-NOT-IMPLEMENTED":
                raise RuntimeError(
                    f"{case_id}: unexpected link-rule rejection {exc.reject_id}"
                )
        else:
            raise RuntimeError(f"{case_id}: mutated link rule was accepted")

    action_names = [entry["name"] for entry in linked["action_bodies"]]
    if action_names != [fixtures.qn("app", "Operate"), fixtures.qn("side", "SideAction")]:
        raise RuntimeError("active action domain drift")
    for action in linked["action_bodies"]:
        for branch in action["branches"]:
            coordinates = branch["event_coordinates"]
            if len(coordinates) != 2:
                raise RuntimeError("action event relation is not total over model channels")
            source_count = sum(
                coordinate["origin"]["kind"] == "SOURCE_DECLARED_EMIT"
                for coordinate in coordinates
            )
            generated_count = sum(
                coordinate["origin"]["kind"] == "LINKER_GENERATED_NON_OWNER_NONE"
                for coordinate in coordinates
            )
            if source_count != 1 or generated_count != 1:
                raise RuntimeError("source and linker event origins were conflated")

    dormant = copy.deepcopy(all_active)
    dormant["active_modules"] = ["app", "root", "types"]
    dormant_checker, dormant_counts, dormant_linked = checked(dormant)
    if [entry["name"] for entry in dormant_linked["action_bodies"]] != [
        fixtures.qn("app", "Operate")
    ]:
        raise RuntimeError("dormant action entered ActionBodies")
    if fixtures.qn("side", "SideEvents") not in [
        entry["name"] for entry in dormant_linked["sigma"]["event_channel_carriers"]
    ]:
        raise RuntimeError("dormant-owner channel disappeared from carrier")
    app_action = dormant_linked["action_bodies"][0]
    side_coordinate = next(
        coordinate
        for coordinate in app_action["branches"][0]["event_coordinates"]
        if coordinate["event_channel"] == fixtures.qn("side", "SideEvents")
    )
    if side_coordinate["origin"]["kind"] != "LINKER_GENERATED_NON_OWNER_NONE":
        raise RuntimeError("inactive-owner channel lacks generated typed None")
    if b"side_parameter" in dormant_checker.linked_model_snapshot.linked_model_raw:
        raise RuntimeError("dormant action body leaked through Sigma")
    if b"SideApplied" not in dormant_checker.linked_model_snapshot.linked_model_raw:
        raise RuntimeError("dormant action signature lost branch-name header")
    if dormant_counts["active_action_count"] != 1:
        raise RuntimeError("active action count is not materialized-domain based")

    root_only = copy.deepcopy(all_active)
    root_only["active_modules"] = ["root"]
    _, _, root_linked = checked(root_only)
    if root_linked["action_bodies"] or root_linked["class_premise_bodies"] or root_linked["base_claim_bodies"]:
        raise RuntimeError("explicit non-import-closed activation acquired dormant bodies")
    if root_linked["init"]["form"] != "SINGLE_IDENTITY":
        raise RuntimeError("single active init was not source-term identity")
    if root_linked["init"]["body"] != fixtures.module_by_name(root_only, "root")["init_contribution"]:
        raise RuntimeError("single active init body changed")
    if len(root_linked["sigma"]["event_channel_carriers"]) != 2:
        raise RuntimeError("root-only activation erased dependency carriers")

    dormant_policy = copy.deepcopy(all_active)
    add_dormant_policy_bodies(dormant_policy)
    dormant_policy["active_modules"] = ["app", "root", "types"]
    policy_checker, policy_counts, policy_linked = checked(dormant_policy)
    if any(entry["name"][0] == "side" for entry in policy_linked["class_premise_bodies"]):
        raise RuntimeError("dormant named premise entered semantic assumptions")
    if any(entry["name"][0] == "side" for entry in policy_linked["base_claim_bodies"]):
        raise RuntimeError("dormant claim became ClaimPackage-eligible")
    if len(policy_linked["sigma"]["constant_constraints"]) != 2:
        raise RuntimeError("dormant constant constraint did not remain interpretation-wide")
    signature_names = [
        entry["signature"]["name"]
        for entry in policy_linked["sigma"]["declaration_signatures"]
    ]
    if fixtures.qn("side", "DormantClaim") not in signature_names:
        raise RuntimeError("dormant claim header disappeared from Sigma")

    invalid_dormant = copy.deepcopy(all_active)
    invalid_dormant["active_modules"] = ["app", "root", "types"]
    event_read = fixtures.term(
        fixtures.s_option(fixtures.s_event()),
        "TERM_EVENT_GET",
        event_channel=fixtures.qn("side", "SideEvents"),
    )
    event_none = fixtures.term(
        fixtures.s_option(fixtures.s_event()),
        "TERM_NONE",
        element_sort=fixtures.s_event(),
    )
    fixtures.declaration(invalid_dormant, "DECL_ACTION", "SideAction")["invoke"] = (
        fixtures.t_eq(event_read, event_none)
    )
    fixtures.repin_imports(invalid_dormant)
    try:
        semantics.CoreSyntaxChecker.for_internal_test_model(invalid_dormant).check()
    except semantics.SemanticReject as exc:
        if exc.reject_id != "F05-CORE-PROVENANCE-PHASE":
            raise RuntimeError(f"unexpected dormant-body rejection: {exc.reject_id}")
    else:
        raise RuntimeError("invalid dormant action escaped static validation")

    source_none = copy.deepcopy(all_active)
    side_emit = fixtures.declaration(source_none, "DECL_ACTION", "SideAction")["branches"][0]["emits"][0]
    side_emit["value"] = fixtures.term(
        fixtures.s_option(fixtures.s_event()),
        "TERM_NONE",
        element_sort=fixtures.s_event(),
    )
    _, _, source_none_linked = checked(source_none)
    side_action = named(source_none_linked["action_bodies"], "SideAction")
    own_coordinate = next(
        coordinate
        for coordinate in side_action["branches"][0]["event_coordinates"]
        if coordinate["event_channel"] == fixtures.qn("side", "SideEvents")
    )
    if own_coordinate["origin"]["kind"] != "SOURCE_DECLARED_EMIT":
        raise RuntimeError("source TERM_NONE was laundered into linker-generated origin")

    claim_true = copy.deepcopy(all_active)
    add_dormant_policy_bodies(claim_true)
    claim_true["active_modules"] = ["app", "root", "types"]
    claim_true_checker, claim_true_counts, _ = checked(claim_true)
    claim_false = copy.deepcopy(claim_true)
    fixtures.declaration(claim_false, "DECL_CLAIM_BASE_ALWAYS", "DormantClaim")[
        "invariant"
    ] = fixtures.t_bool(False)
    claim_false_checker, claim_false_counts, _ = checked(claim_false)
    if id_sha(claim_true_counts, "model_artifact_id") == id_sha(
        claim_false_counts, "model_artifact_id"
    ):
        raise RuntimeError("exact ModelArtifactId ignored dormant source change")
    if id_sha(
        claim_true_counts, "linked_semantic_projection_construction_id"
    ) != id_sha(claim_false_counts, "linked_semantic_projection_construction_id"):
        raise RuntimeError("dormant claim body polluted linked semantic projection")
    if id_sha(claim_true_counts, "linked_model_construction_id") == id_sha(
        claim_false_counts, "linked_model_construction_id"
    ):
        raise RuntimeError("construction identity ignored source binding change")
    declaration_predicate = lambda entry: entry["source_locator"].get("name") == fixtures.qn(
        "side", "SideAction"
    )
    true_declaration_id = manifest_id(
        claim_true_checker,
        "declaration_artifact_manifest",
        "source_declaration_artifact_id",
        declaration_predicate,
    )
    false_declaration_id = manifest_id(
        claim_false_checker,
        "declaration_artifact_manifest",
        "source_declaration_artifact_id",
        declaration_predicate,
    )
    if true_declaration_id != false_declaration_id:
        raise RuntimeError("declaration-node ID over-invalidated on unrelated claim change")
    action_predicate = lambda entry: entry["action_name"] == fixtures.qn(
        "side", "SideAction"
    )
    true_action_id = manifest_id(
        claim_true_checker,
        "source_action_artifacts",
        "source_action_artifact_id",
        action_predicate,
    )
    false_action_id = manifest_id(
        claim_false_checker,
        "source_action_artifacts",
        "source_action_artifact_id",
        action_predicate,
    )
    if true_action_id == false_action_id:
        raise RuntimeError("module-scoped source action ID failed to invalidate")
    true_module_id = manifest_id(
        claim_true_checker,
        "module_manifest",
        "module_artifact_id",
        lambda entry: entry["module_name"] == "side",
    )
    false_module_id = manifest_id(
        claim_false_checker,
        "module_manifest",
        "module_artifact_id",
        lambda entry: entry["module_name"] == "side",
    )
    if true_module_id == false_module_id:
        raise RuntimeError("module artifact ID ignored owner-module change")
    body_predicate = lambda entry: entry["locator"].get("kind") == "ACTION_INVOKE" and entry[
        "locator"
    ].get("action_name") == fixtures.qn("side", "SideAction")
    true_body_id = manifest_id(
        claim_true_checker,
        "body_origin_manifest",
        "body_origin_id",
        body_predicate,
    )
    false_body_id = manifest_id(
        claim_false_checker,
        "body_origin_manifest",
        "body_origin_id",
        body_predicate,
    )
    if true_body_id == false_body_id:
        raise RuntimeError("module-scoped body occurrence ID failed to invalidate")

    dormant_action_changed = copy.deepcopy(dormant)
    fixtures.declaration(dormant_action_changed, "DECL_ACTION", "SideAction")[
        "invoke"
    ] = fixtures.t_bool(False)
    _, dormant_action_counts, _ = checked(dormant_action_changed)
    dormant_init_changed = copy.deepcopy(dormant)
    fixtures.module_by_name(dormant_init_changed, "side")["init_contribution"] = (
        fixtures.t_bool(False)
    )
    _, dormant_init_counts, _ = checked(dormant_init_changed)
    dormant_premise_changed = copy.deepcopy(dormant_policy)
    fixtures.declaration(
        dormant_premise_changed,
        "DECL_PREMISE",
        "DormantPremise",
    )["body"]["bound"] = 1
    _, dormant_premise_counts, _ = checked(dormant_premise_changed)
    dormant_projection = id_sha(
        dormant_counts, "linked_semantic_projection_construction_id"
    )
    if any(
        id_sha(candidate, "linked_semantic_projection_construction_id")
        != dormant_projection
        for candidate in (dormant_action_counts, dormant_init_counts)
    ):
        raise RuntimeError("dormant action/init body entered linked semantic projection")
    if id_sha(
        dormant_premise_counts, "linked_semantic_projection_construction_id"
    ) != id_sha(policy_counts, "linked_semantic_projection_construction_id"):
        raise RuntimeError("dormant premise body entered linked semantic projection")

    alpha_renamed = copy.deepcopy(all_active)
    side_action_node = fixtures.declaration(alpha_renamed, "DECL_ACTION", "SideAction")
    replace_string(side_action_node, "side_parameter", "renamed_parameter")
    _, alpha_counts, _ = checked(alpha_renamed)
    if id_sha(alpha_counts, "linked_semantic_projection_construction_id") == id_sha(
        counts, "linked_semantic_projection_construction_id"
    ):
        raise RuntimeError("construction identity ignored binder spelling policy")

    channel_added = copy.deepcopy(dormant)
    add_inactive_channel(channel_added)
    _, channel_counts, channel_linked = checked(channel_added)
    if id_sha(channel_counts, "linked_semantic_projection_construction_id") == id_sha(
        dormant_counts, "linked_semantic_projection_construction_id"
    ):
        raise RuntimeError("inactive-owner channel failed to change event completion plan")
    if len(channel_linked["action_bodies"][0]["branches"][0]["event_coordinates"]) != 3:
        raise RuntimeError("new inactive-owner channel was not totalized")

    state_added = copy.deepcopy(dormant)
    add_inactive_state_product(state_added)
    _, state_counts, state_linked = checked(state_added)
    if id_sha(state_counts, "linked_semantic_projection_construction_id") == id_sha(
        dormant_counts, "linked_semantic_projection_construction_id"
    ):
        raise RuntimeError("inactive-owner state product failed to change state carrier")
    if len(state_linked["sigma"]["state_product_carriers"]) != 2:
        raise RuntimeError("inactive-owner state product disappeared")

    state_sort_changed = copy.deepcopy(state_added)
    fixtures.declaration(
        state_sort_changed,
        "DECL_STATE_PRODUCT",
        "DormantState",
    )["value_sort"] = fixtures.s_one()
    _, state_sort_counts, _ = checked(state_sort_changed)
    if id_sha(
        state_sort_counts, "linked_semantic_projection_construction_id"
    ) == id_sha(state_counts, "linked_semantic_projection_construction_id"):
        raise RuntimeError("inactive state carrier sort change was invisible")

    channel_sort_changed = copy.deepcopy(channel_added)
    payload = copy.deepcopy(
        fixtures.declaration(channel_sort_changed, "DECL_VARIANT", "EventPayload")
    )
    payload["name"] = fixtures.qn("types", "EventPayloadAlt")
    fixtures.module_by_name(channel_sort_changed, "types")["declarations"].append(payload)
    extra_channel = fixtures.declaration(
        channel_sort_changed,
        "DECL_EVENT_CHANNEL",
        "ExtraEvents",
    )
    extra_channel["payload_variant"] = fixtures.qn("types", "EventPayloadAlt")
    side_action_changed = fixtures.declaration(
        channel_sort_changed,
        "DECL_ACTION",
        "SideAction",
    )
    extra_emit = next(
        emit
        for emit in side_action_changed["branches"][0]["emits"]
        if emit["event_channel"] == fixtures.qn("side", "ExtraEvents")
    )
    alt_payload_sort = {
        "tag": "SORT_VARIANT",
        "variant": fixtures.qn("types", "EventPayloadAlt"),
    }
    extra_emit["value"] = fixtures.term(
        {"tag": "SORT_OPTION", "element": copy.deepcopy(alt_payload_sort)},
        "TERM_NONE",
        element_sort=alt_payload_sort,
    )
    _, channel_sort_counts, _ = checked(channel_sort_changed)
    if id_sha(
        channel_sort_counts, "linked_semantic_projection_construction_id"
    ) == id_sha(channel_counts, "linked_semantic_projection_construction_id"):
        raise RuntimeError("inactive event carrier payload sort change was invisible")

    mutable_source = fixtures.independent_module_composition_fixture()
    snapshot_checker = semantics.CoreSyntaxChecker.for_internal_test_model(mutable_source)
    snapshotted_sha = semantics.linked_model.sha256(
        semantics.canonical_bytes(snapshot_checker.model)
    )
    mutable_source["active_modules"] = ["root"]
    snapshot_counts = snapshot_checker.check()
    if snapshot_counts["model_artifact_id"]["kind"] != "MODEL_ARTIFACT":
        raise RuntimeError("typed ID kind missing")
    source_binding = snapshot_checker.linked_model_snapshot.source_binding()
    if source_binding["canonical_model_sha256"] != snapshotted_sha:
        raise RuntimeError("post-construction source mutation changed immutable snapshot")
    identity_hashes = {
        snapshot_counts["model_artifact_id"]["sha256"],
        snapshot_counts["linked_semantic_projection_construction_id"]["sha256"],
        snapshot_counts["linked_model_construction_id"]["sha256"],
    }
    if len(identity_hashes) != 3:
        raise RuntimeError("typed identity domains collapsed")

    immutable_artifact = snapshot_checker.linked_model_snapshot.artifact_raw
    snapshot_checker.active_modules = frozenset()
    snapshot_checker.modules.pop("side")
    rematerialized = semantics.linked_model.materialize(
        snapshot_checker.source_snapshot,
        snapshot_checker.rule_contract,
        semantics.reject,
    )
    if rematerialized.artifact_raw != immutable_artifact:
        raise RuntimeError("post-check derived-state mutation split source and LinkedModel")

    repeat_checker, repeat_counts, _ = checked(copy.deepcopy(all_active))
    if repeat_checker.linked_model_snapshot.artifact_raw != checker.linked_model_snapshot.artifact_raw:
        raise RuntimeError("LinkedModel materialization is not deterministic")
    if repeat_counts["linked_model_construction_id"] != counts["linked_model_construction_id"]:
        raise RuntimeError("construction ID is not deterministic")

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "linked_model_construction_hostile_regression_only",
                "dependency_modules_checked": len(linked["dependency_modules"]),
                "active_actions_checked": len(linked["action_bodies"]),
                "event_channels_totalized": len(
                    linked["sigma"]["event_channel_carriers"]
                ),
                "root_only_non_import_closed_activation_checked": True,
                "dormant_body_static_validation_checked": True,
                "dormant_claim_eligibility_rejected": True,
                "dormant_constraint_retained": True,
                "source_none_origin_preserved": True,
                "dormant_body_semantic_projection_stable": True,
                "inactive_channel_projection_changed": True,
                "inactive_state_projection_changed": True,
                "dormant_init_premise_action_projection_stable": True,
                "carrier_sort_projection_changed": True,
                "identity_invalidation_policy_checked": True,
                "construction_binder_spelling_policy_checked": True,
                "immutable_source_snapshot_checked": True,
                "typed_identity_domains_checked": 3,
                "deterministic_materialization_checked": True,
                "link_rule_field_mutations_rejected": len(mutated_contracts),
                "linked_model_materialized": True,
                "linked_model_independently_validated": False,
                "source_action_semantic_id_issued": False,
                "linked_action_semantic_id_issued": False,
                "linked_action_id_issued": False,
                "Eval": False,
                "Reads": False,
                "transition_semantics": False,
                "InstanceWF": False,
                "ClaimPackageWF": False,
                "proof_validation": False,
                "CoreSyntaxWF": False,
                "F0_local_acceptance": False,
                "K0_G0_complete": False,
                "candidate_IR": False,
                "TLA_translation": False,
                "model_supported": False,
                "linux_behavior_change": False,
                "protection_claim": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
