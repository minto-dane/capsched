#!/usr/bin/env python3
"""Hostile mutations for the local cross-implementation LinkedModel verifier."""

from __future__ import annotations

import copy
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable


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
    "test_f0_core_syntax_v5_for_link_validator",
    HERE / "test-f0-core-syntax-v5.py",
)
validator = load_module(
    "f0_linked_model_validator_v5_test",
    HERE / "f0_linked_model_validator_v5.py",
)
semantics = fixtures.semantics
Mutation = Callable[[dict[str, Any]], None]


def find_action(artifact: dict[str, Any], local: str) -> dict[str, Any]:
    return next(
        action
        for action in artifact["linked_model"]["action_bodies"]
        if action["name"][1] == local
    )


def main() -> int:
    model = fixtures.independent_module_composition_fixture()
    model["active_modules"] = ["app", "root", "types"]
    fixtures.repin_imports(model)
    checker = semantics.CoreSyntaxChecker.for_internal_test_model(model)
    checker.check()
    if checker.linked_model_snapshot is None:
        raise RuntimeError("missing producer snapshot")
    raw = checker.linked_model_snapshot.artifact_raw
    model_raw = checker.source_snapshot.canonical_model_raw
    baseline = validator.validate(model_raw, checker.rule_contract, raw)
    if baseline["linked_model_locally_cross_reconstructed"] is not True:
        raise RuntimeError("local cross-implementation reconstruction did not run")
    try:
        validator.validate(
            model_raw,
            checker.rule_contract,
            raw,
            max_event_coordinates=0,
        )
    except validator.InconclusiveResource as exc:
        if exc.reason_id != "F05-LV-INCONCLUSIVE-RESOURCE-EVENT-COORDINATES":
            raise RuntimeError(f"unexpected link resource reason {exc.reason_id}")
    else:
        raise RuntimeError("linked verifier allocated beyond its event-coordinate ceiling")

    cases: list[dict[str, str]] = []

    def case(case_id: str, expected: str, mutate: Mutation) -> None:
        artifact = json.loads(raw.decode("ascii"))
        mutate(artifact)
        mutant = validator.canonical_bytes(artifact)
        try:
            validator.validate(model_raw, checker.rule_contract, mutant)
        except validator.Reject as exc:
            if exc.reject_id != expected:
                raise RuntimeError(
                    f"{case_id}: expected {expected}, got {exc.reject_id}: {exc.detail}"
                )
            cases.append({"id": case_id, "reject_id": exc.reject_id})
        else:
            raise RuntimeError(f"{case_id}: mutant accepted")

    case(
        "dormant_action_body_injected_into_signature",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: next(
            entry
            for entry in artifact["linked_model"]["sigma"]["declaration_signatures"]
            if entry["signature"]["name"] == fixtures.qn("side", "SideAction")
        )["signature"].__setitem__("invoke", fixtures.t_bool()),
    )
    case(
        "inactive_owner_channel_removed",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["sigma"][
            "event_channel_carriers"
        ].pop(),
    )
    case(
        "empty_event_coordinate_removed",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["sigma"][
            "empty_event_template"
        ].pop(),
    )
    case(
        "action_non_owner_coordinate_removed",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: find_action(artifact, "Operate")["branches"][0][
            "event_coordinates"
        ].pop(),
    )
    case(
        "source_emit_origin_laundered",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: find_action(artifact, "Operate")["branches"][0][
            "event_coordinates"
        ][0]["origin"].__setitem__("kind", "LINKER_GENERATED_NON_OWNER_NONE"),
    )
    case(
        "dormant_action_activated",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["action_bodies"].append(
            copy.deepcopy(artifact["linked_model"]["action_bodies"][0])
        ),
    )
    case(
        "dormant_claim_made_eligible",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["base_claim_bodies"].append(
            {
                "name": fixtures.qn("side", "ForgedClaim"),
                "owner_module": "side",
                "invariant": fixtures.t_bool(),
            }
        ),
    )
    case(
        "init_contribution_reordered",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["init"][
            "ordered_contributions"
        ].reverse(),
    )
    case(
        "init_flattened",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model"]["init"].__setitem__(
            "form", "FLATTENED_AND"
        ),
    )
    case(
        "ordered_updates_reversed",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: find_action(artifact, "Operate")["branches"][0][
            "updates"
        ].reverse(),
    )
    case(
        "typed_none_payload_changed",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: next(
            coordinate
            for coordinate in find_action(artifact, "Operate")["branches"][0][
                "event_coordinates"
            ]
            if coordinate["origin"]["kind"]
            == "LINKER_GENERATED_NON_OWNER_NONE"
        )["value"]["node"].__setitem__("element_sort", fixtures.s_bool()),
    )
    case(
        "source_model_digest_forged",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["source_binding"].__setitem__(
            "canonical_model_sha256", "0" * 64
        ),
    )
    case(
        "typed_id_kind_confused",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["source_binding"]["model_artifact_id"].__setitem__(
            "kind", "LINKED_MODEL_CONSTRUCTION"
        ),
    )
    case(
        "identity_digest_reused_across_kind",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["linked_model_construction_id"].__setitem__(
            "sha256", artifact["source_binding"]["model_artifact_id"]["sha256"]
        ),
    )
    case(
        "final_identity_self_authorized",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact["authorization"].__setitem__(
            "linked_action_id_issued", True
        ),
    )
    case(
        "boolean_integer_alias",
        "F05-LV-ARTIFACT-MISMATCH",
        lambda artifact: artifact.__setitem__("schema_version", True),
    )

    noncanonical = b'{"schema_version":1, "artifact_id":"x"}'
    try:
        validator.validate(model_raw, checker.rule_contract, noncanonical)
    except validator.Reject as exc:
        if exc.reject_id != "F05-LV-ARTIFACT-NONCANONICAL":
            raise RuntimeError(f"unexpected noncanonical rejection: {exc.reject_id}")
        cases.append({"id": "noncanonical_artifact", "reject_id": exc.reject_id})
    else:
        raise RuntimeError("noncanonical artifact accepted")

    duplicate = raw.replace(
        b'{"artifact_id":',
        b'{"schema_version":1,"artifact_id":',
        1,
    )
    try:
        validator.validate(model_raw, checker.rule_contract, duplicate)
    except validator.Reject as exc:
        if exc.reject_id != "F05-LV-DUPLICATE-KEY":
            raise RuntimeError(f"unexpected duplicate rejection: {exc.reject_id}")
        cases.append({"id": "duplicate_artifact_key", "reject_id": exc.reject_id})
    else:
        raise RuntimeError("duplicate artifact key accepted")

    deeply_nested = b'{"x":' * 1200 + b"0" + b"}" * 1200
    try:
        validator.validate(model_raw, checker.rule_contract, deeply_nested)
    except validator.Reject as exc:
        if exc.reject_id != "F05-LV-DEPTH":
            raise RuntimeError(f"unexpected deep artifact rejection: {exc.reject_id}")
        cases.append({"id": "artifact_depth_resource", "reject_id": exc.reject_id})
    else:
        raise RuntimeError("deep hostile artifact escaped the resource envelope")

    oversized_integer = b'{"x":' + b"1" * 5000 + b"}"
    try:
        validator.validate(model_raw, checker.rule_contract, oversized_integer)
    except validator.Reject as exc:
        if exc.reject_id != "F05-LV-INTEGER-DIGITS":
            raise RuntimeError(f"unexpected integer rejection: {exc.reject_id}")
        cases.append({"id": "artifact_integer_digit_resource", "reject_id": exc.reject_id})
    else:
        raise RuntimeError("hostile integer escaped the resource envelope")

    original_typed_none = semantics.linked_model._typed_none

    def wrong_typed_none(_payload_variant: list[str]) -> dict[str, Any]:
        return fixtures.term(
            {"tag": "SORT_OPTION", "element": fixtures.s_bool()},
            "TERM_NONE",
            element_sort=fixtures.s_bool(),
        )

    semantics.linked_model._typed_none = wrong_typed_none
    try:
        corrupted_checker = semantics.CoreSyntaxChecker.for_internal_test_model(
            copy.deepcopy(model)
        )
        corrupted_checker.check()
        try:
            validator.validate(
                corrupted_checker.source_snapshot.canonical_model_raw,
                corrupted_checker.rule_contract,
                corrupted_checker.linked_model_snapshot.artifact_raw,
            )
        except validator.Reject as exc:
            if exc.reject_id != "F05-LV-ARTIFACT-MISMATCH":
                raise RuntimeError(
                    f"producer corruption: unexpected rejection {exc.reject_id}"
                )
            cases.append(
                {
                    "id": "corrupted_materializer_typed_none",
                    "reject_id": exc.reject_id,
                }
            )
        else:
            raise RuntimeError("independent verifier accepted corrupted producer")
    finally:
        semantics.linked_model._typed_none = original_typed_none

    pipeline = fixtures.validate_model(
        fixtures.independent_module_composition_fixture()
    )
    if pipeline["linked_model_locally_cross_reconstructed"] is not True:
        raise RuntimeError("production wrapper did not run local cross reconstruction")
    if pipeline["linked_model_independently_validated"] is not False:
        raise RuntimeError("local cross reconstruction was overstated as independent validation")
    if pipeline["linked_model_external_review"] is not False:
        raise RuntimeError("local reconstruction was mislabeled external review")

    print(
        json.dumps(
            {
                "schema_version": 1,
                "status": "passed",
                "authority": "linked_model_local_cross_verifier_hostile_mutations_only",
                "baseline_artifact_sha256": baseline["artifact_sha256"],
                "mutations_total": len(cases),
                "mutations_rejected_at_expected_id": len(cases),
                "results": cases,
                "producer_corruption_rejected": True,
                "pipeline_local_cross_reconstruction": True,
                "event_coordinate_preallocation_meter_checked": True,
                "external_review": False,
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
