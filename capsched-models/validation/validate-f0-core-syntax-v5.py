#!/usr/bin/env python3
"""Validate DL-F0-5 CoreSyntaxWF static typing/provenance obligations."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
WIRE_CHECKER_PATH = HERE / "validate-f0-canonical-instance-v5.py"
SEMANTICS_PATH = HERE / "f0_semantics_v5.py"
LINKED_VALIDATOR_PATH = HERE / "f0_linked_model_validator_v5.py"
SNAPSHOT_PATH = HERE / "f0_wire_snapshot_v5.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


wire = load_module("validate_f0_canonical_instance_v5", WIRE_CHECKER_PATH)
snapshot_module = load_module("f0_wire_snapshot_v5", SNAPSHOT_PATH)
semantics = load_module("f0_semantics_v5", SEMANTICS_PATH)
linked_validator = load_module("f0_linked_model_validator_v5", LINKED_VALIDATOR_PATH)
CoreSyntaxChecker = semantics.CoreSyntaxChecker
SemanticReject = semantics.SemanticReject
VerificationInconclusive = semantics.VerificationInconclusive


def validate(path: Path) -> dict[str, object]:
    try:
        wire_result, model, raw = wire.validate_and_load(path, "Model")
    except wire.Reject as exc:
        raise SemanticReject("F05-CORE-WIRE", f"{exc.reject_id}:{exc.detail}") from exc
    except RecursionError as exc:
        raise VerificationInconclusive(
            "F05-CORE-RESOURCE-WIRE-RECURSION",
            "wire validator recursion capacity exhausted before a semantic decision",
        ) from exc
    try:
        if not isinstance(model, dict):
            raise SemanticReject("F05-CORE-MODEL", "top level is not an object")
        try:
            source_snapshot = snapshot_module.WireValidatedModelSnapshot.from_wire_validation(
                raw,
                wire_result,
            )
            source_snapshot.require_wire_validated()
        except snapshot_module.SnapshotReject as exc:
            raise SemanticReject(
                "F05-CORE-SNAPSHOT",
                f"{exc.reject_id}:{exc.detail}",
            ) from exc
        semantic_checker = CoreSyntaxChecker(source_snapshot)
        counts = semantic_checker.check()
        if semantic_checker.linked_model_snapshot is None:
            raise SemanticReject("F05-CORE-LINK-MISSING", "no LinkedModel snapshot")
        try:
            linked_result = linked_validator.validate(
                source_snapshot.canonical_model_raw,
                semantic_checker.rule_contract,
                semantic_checker.linked_model_snapshot.artifact_raw,
            )
        except linked_validator.Reject as exc:
            raise SemanticReject(
                "F05-CORE-LINK-VERIFY",
                f"{exc.reject_id}:{exc.detail}",
            ) from exc
    except RecursionError as exc:
        raise VerificationInconclusive(
            "F05-CORE-RESOURCE-HOST-RECURSION",
            "checker recursion capacity exhausted before a semantic decision",
        ) from exc
    return {
        "schema_version": 1,
        "status": "CoreSyntaxWF_construction_static_checks_passed",
        "authority": "local_source_static_semantics_only",
        "model_sha256": wire.checker.digest(raw),
        "model_bytes": len(raw),
        "surface_sha256": wire_result["surface_sha256"],
        **counts,
        "static_link_rules_consumed": sorted(
            {
                *counts["static_link_rules_consumed"],
                "same_snapshot_for_wire_and_semantics",
            }
        ),
        "linked_model_artifact_sha256": linked_result["artifact_sha256"],
        "linked_model_locally_cross_reconstructed": True,
        "linked_model_independently_validated": False,
        "linked_model_validation_authority": "local_cross_implementation_reconstruction_only",
        "linked_model_external_review": False,
        "same_snapshot_for_wire_link_and_semantics": True,
        "CoreSyntaxWF": False,
        "semantic_rule_table_bound": False,
        "module_link_elaboration_complete": False,
        "module_link_construction_materialized": True,
        "module_link_construction_complete": False,
        "resource_envelope_complete": False,
        "InstanceWF": False,
        "ClaimPackageWF": False,
        "evaluation_validated": False,
        "transition_semantics_validated": False,
        "proof_validation": False,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "candidate_IR": False,
        "TLA_translation": False,
        "model_supported": False,
        "linux_behavior_change": False,
        "protection_claim": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate(args.path), sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except VerificationInconclusive as exc:
        print(
            json.dumps(
                {
                    "status": "inconclusive",
                    "reason_id": exc.reason_id,
                    "detail": exc.detail,
                    "semantic_rejection": False,
                    "F0_local_acceptance": False,
                    "protection_claim": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(2)
    except SemanticReject as exc:
        print(
            json.dumps(
                {"status": "rejected", "reject_id": exc.reject_id, "detail": exc.detail},
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        raise SystemExit(1)
