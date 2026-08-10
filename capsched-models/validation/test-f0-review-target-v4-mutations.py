#!/usr/bin/env python3
"""Exercise fail-closed identity boundaries of the local F0 v4 target checker."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import shutil
import tempfile
from pathlib import Path
from typing import Callable


HERE = Path(__file__).resolve().parent
CHECKER_PATH = HERE / "validate-f0-review-target-v4.py"
MODELS = HERE.parent
F0 = MODELS / "policy" / "r11" / "epoch2" / "foundation-v4"
V3 = MODELS / "policy" / "r11" / "epoch2"

spec = importlib.util.spec_from_file_location("validate_f0_v4", CHECKER_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("cannot load checker")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


Mutation = Callable[[Path, Path, Path], None]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def mutate_json(change: Callable[[dict], None]) -> Mutation:
    def apply(manifest: Path, _source: Path, _v3: Path) -> None:
        value = load_json(manifest)
        change(value)
        write_json(manifest, value)
    return apply


def duplicate_key(manifest: Path, _source: Path, _v3: Path) -> None:
    raw = manifest.read_text(encoding="utf-8")
    manifest.write_text(raw.replace('"schema_version": 1,', '"schema_version": 1,\n  "schema_version": 1,', 1), encoding="utf-8")


def source_drift(_manifest: Path, source: Path, _v3: Path) -> None:
    source.write_text(source.read_text(encoding="ascii").replace("typed transition calculus", "typed transition relation", 1), encoding="ascii")


def predecessor_drift(_manifest: Path, _source: Path, v3: Path) -> None:
    target = v3 / "semantic-foundation-v3.md"
    target.write_bytes(target.read_bytes() + b"\n")


def add_extra(value: dict) -> None:
    value["candidate_verdict"] = "accept"


def set_null(value: dict) -> None:
    value["date"] = None


def set_float(value: dict) -> None:
    value["normative_source"]["bytes"] = 24915.0


def bad_artifact(value: dict) -> None:
    value["artifact_id"] = "forged"


def bad_authority(value: dict) -> None:
    value["authority"] = "normative_semantics"


def bad_path(value: dict) -> None:
    value["normative_source"]["path"] = "attacker.md"


def bad_hash(value: dict) -> None:
    value["normative_source"]["sha256"] = "0" * 64


def bad_bytes(value: dict) -> None:
    value["normative_source"]["bytes"] = 1


def remove_clause(value: dict) -> None:
    value["normative_clause_ids"].pop()


def duplicate_clause(value: dict) -> None:
    value["normative_clause_ids"][-1] = value["normative_clause_ids"][0]


def predecessor_status(value: dict) -> None:
    value["predecessor_disposition"]["v3_status"] = "accepted"


def predecessor_hash(value: dict) -> None:
    value["predecessor_disposition"]["v3_spec_sha256"] = "f" * 64


def remove_review(value: dict) -> None:
    value["local_review_assignments"].pop()


def external_review(value: dict) -> None:
    value["local_review_assignments"][0]["external_authority"] = True


def forged_review(value: dict) -> None:
    value["local_review_assignments"][0]["session_id"] = "forged"


def local_accept(value: dict) -> None:
    value["authorization"]["F0_local_acceptance"] = True


def k0_accept(value: dict) -> None:
    value["authorization"]["K0_G0_complete"] = True


def candidate_ir(value: dict) -> None:
    value["authorization"]["candidate_IR"] = True


MUTATIONS: list[tuple[str, Mutation, str]] = [
    ("duplicate_json_key", duplicate_key, "F0-STRUCT-DUPLICATE-KEY"),
    ("unknown_top_level_key", mutate_json(add_extra), "F0-STRUCT-KEYS"),
    ("null_scalar", mutate_json(set_null), "F0-STRUCT-SCALAR"),
    ("float_scalar", mutate_json(set_float), "F0-STRUCT-SCALAR"),
    ("artifact_identity", mutate_json(bad_artifact), "F0-STRUCT-IDENTITY"),
    ("authority_escalation", mutate_json(bad_authority), "F0-STRUCT-AUTHORITY"),
    ("source_path", mutate_json(bad_path), "F0-STRUCT-SOURCE-METADATA"),
    ("source_declared_hash", mutate_json(bad_hash), "F0-STRUCT-SOURCE-METADATA"),
    ("source_declared_bytes", mutate_json(bad_bytes), "F0-STRUCT-SOURCE-METADATA"),
    ("source_actual_drift", source_drift, "F0-STRUCT-SOURCE-DIGEST"),
    ("remove_clause", mutate_json(remove_clause), "F0-STRUCT-CLAUSES"),
    ("duplicate_clause", mutate_json(duplicate_clause), "F0-STRUCT-CLAUSES"),
    ("predecessor_status", mutate_json(predecessor_status), "F0-STRUCT-PREDECESSOR-STATUS"),
    ("predecessor_declared_hash", mutate_json(predecessor_hash), "F0-STRUCT-PREDECESSOR-METADATA"),
    ("predecessor_actual_drift", predecessor_drift, "F0-STRUCT-PREDECESSOR-DRIFT"),
    ("remove_review", mutate_json(remove_review), "F0-STRUCT-REVIEWS"),
    ("external_authority_forgery", mutate_json(external_review), "F0-STRUCT-REVIEWS"),
    ("review_session_forgery", mutate_json(forged_review), "F0-STRUCT-REVIEWS"),
    ("local_accept_forgery", mutate_json(local_accept), "F0-STRUCT-AUTHORIZATION"),
    ("k0_accept_forgery", mutate_json(k0_accept), "F0-STRUCT-AUTHORIZATION"),
    ("candidate_ir_forgery", mutate_json(candidate_ir), "F0-STRUCT-AUTHORIZATION"),
]


def run_case(mutation: Mutation | None) -> tuple[int, str]:
    with tempfile.TemporaryDirectory(prefix="f0-v4-mutation-") as temporary:
        root = Path(temporary)
        manifest = root / "manifest.json"
        source = root / "source.md"
        v3 = root / "v3"
        v3.mkdir()
        shutil.copyfile(F0 / "f0-review-target-v4.json", manifest)
        shutil.copyfile(F0 / "f0-core-calculus-v4.md", source)
        for name in ("semantic-foundation-v3.md", "semantic-foundation-schema-v3.json", "semantic-foundation-v3.json"):
            shutil.copyfile(V3 / name, v3 / name)
        if mutation is not None:
            mutation(manifest, source, v3)
        checker.MANIFEST = manifest
        checker.SOURCE = source
        checker.V3 = v3
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                checker.main()
        except checker.Reject as exc:
            return 1, exc.reject_id
        return 0, output.getvalue()


def main() -> int:
    baseline_code, baseline_output = run_case(None)
    if baseline_code != 0:
        raise RuntimeError(f"baseline rejected: {baseline_output}")
    baseline = json.loads(baseline_output)
    if baseline["status"] != "passed" or baseline["K0_G0_complete"] is not False:
        raise RuntimeError("baseline authority mismatch")

    results = []
    for name, mutation, expected in MUTATIONS:
        code, actual = run_case(mutation)
        if code == 0 or actual != expected:
            raise RuntimeError(f"{name}: expected {expected}, got {actual}")
        results.append({"id": name, "reject_id": actual})
    print(json.dumps({
        "schema_version": 1,
        "status": "passed",
        "authority": "local_structural_mutation_regression_only",
        "baseline_passed": True,
        "mutations_total": len(results),
        "mutations_rejected_at_expected_id": len(results),
        "results": results,
        "F0_local_acceptance": False,
        "K0_G0_complete": False,
        "semantic_validation": False
    }, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
