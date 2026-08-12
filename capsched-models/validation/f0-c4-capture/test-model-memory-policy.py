#!/usr/bin/env python3
"""Bounded-memory regression for exact Candidate-4 graph enumeration."""

from __future__ import annotations

from array import array
from dataclasses import is_dataclass
from pathlib import Path
import sys
from types import ModuleType
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as child  # noqa: E402
import f0_supervisor_orchestrator_v3 as parent  # noqa: E402


ABSOLUTE_CACHE_MAX_ENTRIES = 32768
EXPECTED_CACHE_CONSTANTS = {
    child: {
        "SMALL_CACHE_MAX_ENTRIES": 256,
        "DIGEST_CACHE_MAX_ENTRIES": 32768,
        "STATE_CACHE_MAX_ENTRIES": 16384,
        "PREFIX_CACHE_MAX_ENTRIES": 8192,
    },
    parent: {
        "SMALL_CACHE_MAX_ENTRIES": 256,
        "STATE_CACHE_MAX_ENTRIES": 16384,
    },
}
EXPECTED_CACHED_FUNCTIONS = {
    child: {
        "_grant_auth_tag",
        "_phase_after_evidence_prefix",
        "_receipt_auth_tag",
        "digest",
        "evidence_wf",
        "genesis_hash",
        "grant_binding_digest",
        "grant_wf",
        "instance_wf",
        "receipt_hash",
        "receipt_wf",
        "recovery_wf",
    },
    parent: {
        "_replay_child_terminal",
        "fixture_child_certificate",
        "orchestrator_wf",
    },
}


def require_module_cache_policy(module: ModuleType) -> None:
    for name, expected in EXPECTED_CACHE_CONSTANTS[module].items():
        actual = getattr(module, name, None)
        if actual != expected:
            raise AssertionError(f"{module.__name__}.{name} drifted: {actual!r}")
    cached = {
        name: value
        for name, value in vars(module).items()
        if callable(value) and hasattr(value, "cache_parameters")
    }
    if set(cached) != EXPECTED_CACHED_FUNCTIONS[module]:
        raise AssertionError(
            f"{module.__name__} cached-function inventory drifted: {sorted(cached)}"
        )
    for name, function in cached.items():
        maximum = function.cache_parameters()["maxsize"]
        if (
            not isinstance(maximum, int)
            or maximum <= 0
            or maximum > ABSOLUTE_CACHE_MAX_ENTRIES
        ):
            raise AssertionError(
                f"{module.__name__}.{name} cache is not independently bounded: "
                f"{maximum!r}"
            )


def require_module_dataclasses_slotted(module: ModuleType) -> None:
    classes = {
        name: value
        for name, value in vars(module).items()
        if isinstance(value, type)
        and value.__module__ == module.__name__
        and is_dataclass(value)
    }
    if not classes:
        raise AssertionError(f"{module.__name__} has no state dataclasses")
    missing = sorted(name for name, value in classes.items() if "__slots__" not in value.__dict__)
    if missing:
        raise AssertionError(f"{module.__name__} dataclasses lack slots: {missing}")


def main() -> None:
    cases = 0
    child_start = child.initial_state(child.fixture_external_grant("PRODUCER"))
    parent_start = parent.initial_state()
    if hasattr(child_start, "__dict__") or hasattr(parent_start, "__dict__"):
        raise AssertionError("reachable state dataclasses must use slots")
    cases += 2

    if child.semantic_projection(child_start) is not child_start:
        raise AssertionError("exact child projection allocated a wrapper identity")
    if parent.semantic_projection(parent_start) is not parent_start:
        raise AssertionError("exact parent projection allocated a wrapper identity")
    cases += 2

    for module in (child, parent):
        require_module_cache_policy(module)
        cases += 1

    if hasattr(child.next_states, "cache_info") or hasattr(parent.next_states, "cache_info"):
        raise AssertionError("transition expansion must not retain an unbounded graph cache")
    cases += 1

    with patch.object(child, "next_states", return_value=()):
        child_graph = child.reachable_states(child.fixture_external_grant("PRODUCER"))
    if (
        not isinstance(child_graph, child.ReachabilityGraph)
        or child_graph.states != (child_start,)
        or child_graph.edge_offsets != array("I", (0, 0))
        or child_graph.target_indices.typecode != "I"
        or child_graph.action_indices.typecode != "B"
    ):
        raise AssertionError("child reachable_states did not return compact exact CSR")
    cases += 1

    with patch.object(parent, "next_states", return_value=()):
        parent_graph = parent.reachable_states()
    if (
        not isinstance(parent_graph, parent.OrchestratorReachabilityGraph)
        or parent_graph.states != (parent_start,)
        or parent_graph.edge_offsets != array("I", (0, 0))
        or parent_graph.target_indices.typecode != "I"
        or parent_graph.action_indices.typecode != "B"
    ):
        raise AssertionError("parent reachable_states did not return compact exact CSR")
    cases += 1

    for module in (child, parent):
        require_module_dataclasses_slotted(module)
        cases += 1

    for source in (child.__file__, parent.__file__):
        if "@lru_cache(maxsize=None)" in Path(source).read_text(encoding="utf-8"):
            raise AssertionError(f"unbounded cache returned: {source}")
    cases += 1

    print(f"F0_C4_MODEL_MEMORY_POLICY_PASS cases={cases}")


if __name__ == "__main__":
    main()
