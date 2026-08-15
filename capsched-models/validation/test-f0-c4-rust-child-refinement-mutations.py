#!/usr/bin/env python3
"""Require the Rust child-refinement checkpoint validator to fail closed."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import shutil
import tempfile


HERE = Path(__file__).resolve().parent
VALIDATOR_PATH = HERE / "validate-f0-c4-rust-child-refinement.py"
RECORD_NAME = "f0-c4-rust-child-transition-refinement-checkpoint-v1.json"
spec = importlib.util.spec_from_file_location("f0_c4_rust_refinement_validator", VALIDATOR_PATH)
if spec is None or spec.loader is None:
    raise SystemExit("error: cannot load Rust refinement validator")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def make_fixture(destination: Path) -> Path:
    validation = destination / "capsched-models/validation"
    validation.mkdir(parents=True)
    shutil.copy2(HERE / RECORD_NAME, validation / RECORD_NAME)
    shutil.copy2(HERE / "f0_supervisor_lts_v3.py", validation / "f0_supervisor_lts_v3.py")
    shutil.copytree(HERE / "f0-c4-rust-engine", validation / "f0-c4-rust-engine")
    return destination


def read_record(root: Path) -> dict[str, object]:
    return json.loads((root / "capsched-models/validation" / RECORD_NAME).read_text())


def write_record(root: Path, record: dict[str, object]) -> None:
    (root / "capsched-models/validation" / RECORD_NAME).write_text(
        json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def record_mutation(path: tuple[str, ...], value: object):
    def mutate(root: Path) -> None:
        record = read_record(root)
        target = record
        for key in path[:-1]:
            target = target[key]  # type: ignore[index,assignment]
        target[path[-1]] = value
        write_record(root, record)

    return mutate


def remove_input(root: Path) -> None:
    (root / "capsched-models/validation/f0-c4-rust-engine/src/model.rs").unlink()


def add_unbound_input(root: Path) -> None:
    (root / "capsched-models/validation/f0-c4-rust-engine/src/unbound.rs").write_text(
        "// unbound\n", encoding="utf-8"
    )


def alter_cargo(root: Path) -> None:
    path = root / "capsched-models/validation/f0-c4-rust-engine/Cargo.toml"
    path.write_text(path.read_text() + "\nserde = \"1\"\n", encoding="utf-8")


MUTATIONS = (
    ("Rust becomes normative", record_mutation(("normative_model", "authority"), "RUST")),
    ("normative bytes drift", record_mutation(("normative_model", "sha256"), "0" * 64)),
    ("input hash drift", record_mutation(("rust_refinement", "input_sha256", "src/model.rs"), "0" * 64)),
    ("missing input", remove_input),
    ("unbound input", add_unbound_input),
    ("dependency injection", alter_cargo),
    ("prefix count inflation", record_mutation(("differential_results", "bounded_exact_prefix", "producer", "states"), 6411)),
    ("action coverage omission", record_mutation(("differential_results", "all_action_trace_corpus", "observed_action_count"), 55)),
    ("WF check omission", record_mutation(("differential_results", "independent_wf_prefix", "producer", "wf_checks"), 12212)),
    ("collision equality weakened", record_mutation(("representation", "digest_match_resolution"), "HASH_ONLY")),
    ("reproducibility removed", record_mutation(("reproducible_build", "status"), "NOT_RUN")),
    ("closed gate false", record_mutation(("closed_subgates", "digest_collisions_resolved_by_full_equality"), False)),
    ("independent WF gate reopened", record_mutation(("closed_subgates", "rust_instance_wf_and_evidence_wf_independent_checks"), False)),
    ("open parent gate hidden", record_mutation(("open_subgates", "parent_orchestrator_transition_and_hostile_refinement"), False)),
    ("G6 retry overclaim", record_mutation(("disposition", "g6_retry_eligible"), True)),
    ("Rust authority overclaim", record_mutation(("disposition", "rust_model_authority"), True)),
)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="f0-c4-rust-refinement-mutations-") as temporary:
        baseline = Path(temporary) / "baseline"
        make_fixture(baseline)
        validator.validate(baseline)
        for index, (name, mutate) in enumerate(MUTATIONS):
            case = Path(temporary) / f"case-{index:02d}"
            shutil.copytree(baseline, case)
            mutate(case)
            try:
                validator.validate(case)
            except (OSError, KeyError, TypeError, ValueError, validator.ValidationError):
                continue
            raise SystemExit(f"error: mutation accepted: {name}")
    print(f"F0_C4_RUST_CHILD_REFINEMENT_MUTATION_PASS cases={len(MUTATIONS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
