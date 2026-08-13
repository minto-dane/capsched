#!/usr/bin/env python3
"""Prove bounded RAM and ext4-spill exploration are exactly equivalent."""

from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import tempfile
from typing import Any


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
import sys

sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


SOURCE_LIMIT = 2_000


@dataclass(slots=True)
class BoundedGraph:
    states: Any
    frontier: Any
    depths: Any
    targets: Any
    expanded: int


def enumerate_bounded() -> BoundedGraph:
    initial = model.semantic_projection(
        model.initial_state(model.fixture_external_grant("PRODUCER"))
    )
    states = model.CompactExactStateStore(
        model.EnvelopeState,
        model.CHILD_STATE_REFERENCE_FIELDS,
    )
    index = model.ExactStateIndex(states)
    initial_index, is_new = index.intern(initial)
    if initial_index != 0 or not is_new:
        raise AssertionError("initial exact state was not uniquely interned")
    frontier = model._new_array("I", (initial_index,))
    depths = model._new_array("B", (0,))
    targets = model._new_array("I")
    cursor = 0
    while cursor < len(frontier) and cursor < SOURCE_LIMIT:
        source = states[frontier[cursor]]
        source_depth = depths[cursor]
        cursor += 1
        for edge in model.next_states(source):
            target, target_is_new = index.intern(
                model.semantic_projection(edge.state)
            )
            targets.append(target)
            if target_is_new:
                frontier.append(target)
                depths.append(source_depth + 1)
    return BoundedGraph(states, frontier, depths, targets, cursor)


def require_equal(left: BoundedGraph, right: BoundedGraph) -> None:
    scalar_pairs = (
        (left.expanded, right.expanded, "expanded sources"),
        (len(left.states), len(right.states), "retained states"),
        (len(left.frontier), len(right.frontier), "frontier length"),
        (len(left.targets), len(right.targets), "edge length"),
    )
    for expected, actual, label in scalar_pairs:
        if actual != expected:
            raise AssertionError(f"spill changed {label}: {actual} != {expected}")
    for label, expected, actual in (
        ("frontier", left.frontier, right.frontier),
        ("depths", left.depths, right.depths),
        ("targets", left.targets, right.targets),
    ):
        if expected != actual:
            raise AssertionError(f"spill changed exact {label} sequence")
    for state_index in range(len(left.states)):
        if left.states[state_index] != right.states[state_index]:
            raise AssertionError(
                f"spill changed exact state sequence at index {state_index}"
            )


def main() -> None:
    if os.environ.get(model.EXACT_STORE_DIRECTORY_ENV):
        raise AssertionError("equivalence test must start without a spill directory")
    memory_graph = enumerate_bounded()
    with tempfile.TemporaryDirectory(prefix="f0-c4-equivalence-") as raw:
        spill = Path(raw)
        os.chmod(spill, 0o700)
        os.environ[model.EXACT_STORE_DIRECTORY_ENV] = str(spill)
        try:
            spill_graph = enumerate_bounded()
            require_equal(memory_graph, spill_graph)
            if list(spill.iterdir()):
                raise AssertionError("spill mappings remained path-visible")
        finally:
            os.environ.pop(model.EXACT_STORE_DIRECTORY_ENV, None)
            if model._spill_directory_fd is not None:
                os.close(model._spill_directory_fd)
            model._spill_directory_fd = None
            model._spill_directory_path = None
    print(
        "F0_C4_MODEL_STORAGE_EQUIVALENCE_PASS "
        f"expanded={memory_graph.expanded} states={len(memory_graph.states)} "
        f"edges={len(memory_graph.targets)}"
    )


if __name__ == "__main__":
    main()
