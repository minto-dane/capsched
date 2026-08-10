#!/usr/bin/env python3
"""Reject malformed scalar/container types at every witness input node."""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any, Iterator


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "capsched-models/validation/validate-dynamic-residency-architecture-contract.py"
WITNESS = ROOT / "capsched-models/analysis/dynamic-residency-preformal-two-lane-witness-v1.json"


def load_validator() -> Any:
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("dynamic_residency_validator",
                                                  VALIDATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load dynamic residency validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def nodes(value: Any, path: tuple[Any, ...] = ()) \
        -> Iterator[tuple[tuple[Any, ...], Any]]:
    if path:
        yield path, value
    if isinstance(value, dict):
        for key, child in value.items():
            yield from nodes(child, path + (key,))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from nodes(child, path + (index,))


def replace(value: Any, path: tuple[Any, ...], replacement: Any) -> None:
    cursor = value
    for component in path[:-1]:
        cursor = cursor[component]
    cursor[path[-1]] = replacement


def malformed_values(value: Any) -> list[Any]:
    if type(value) is bool:
        return [None, 0, "", [], {}]
    if type(value) is int:
        return [None, -1, "", False, [], {}]
    if isinstance(value, str):
        return [None, "", 0, False, [], {}]
    if isinstance(value, list):
        return [None, 0, "", {}, []]
    if isinstance(value, dict):
        return [None, 0, "", [], {}]
    if value is None:
        return ["", 0, False, [], {}]
    raise TypeError(f"unmodeled JSON value type: {type(value).__name__}")


def main() -> int:
    validator = load_validator()
    witness = json.loads(WITNESS.read_text(encoding="utf-8"))
    attempted = 0
    failures: list[str] = []

    for scenario in witness["scenarios"]:
        original = scenario["executable"]
        executor = validator.WITNESS_EXECUTORS[original["machine"]]
        for path, old in nodes(original):
            for malformed in malformed_values(old):
                if type(malformed) is type(old) and malformed == old:
                    continue
                attempted += 1
                candidate = copy.deepcopy(original)
                replace(candidate, path, malformed)
                dotted = ".".join(str(component) for component in path)
                try:
                    executor(scenario["id"], candidate)
                except validator.ValidationError:
                    continue
                except Exception as error:  # noqa: BLE001 - reports fail-open crashes
                    failures.append(
                        f"CRASH {scenario['id']} {dotted} "
                        f"{type(error).__name__}: {error}"
                    )
                else:
                    failures.append(
                        f"ACCEPT {scenario['id']} {dotted} "
                        f"replacement={malformed!r}"
                    )

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        print(
            f"FAIL: {len(failures)} malformed witness inputs did not "
            f"fail closed out of {attempted}",
            file=sys.stderr,
        )
        return 1
    print(
        f"PASS: {attempted} malformed witness type/container replacements "
        "were rejected with no unhandled executor exception"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
