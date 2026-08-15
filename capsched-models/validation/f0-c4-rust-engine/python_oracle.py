#!/usr/bin/env python3
"""Canonical Python oracle for the Candidate-4 Rust refinement.

The oracle does not grant G6 credit.  It serializes the retained Python
behavioral quotient without relying on Python object hashes, then emits the
complete setup closure through (but not beyond) RUNNING.  Rust must generate
the same state and edge bytes independently.
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import fields, is_dataclass
from pathlib import Path
import sys
from typing import Any


VALIDATION = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


WIRE_SCHEMA = "F0-C4-RUST-DIFFERENTIAL-V1"
EXPECTED_SETUP_STATES = 57
EXPECTED_SETUP_EDGES = 58


def _frame(value: bytes) -> bytes:
    return str(len(value)).encode("ascii") + b":" + value


def encode(value: Any) -> bytes:
    """Encode the exact comparison value without a probabilistic identity."""

    if value is None:
        return b"N"
    if isinstance(value, bool):
        return b"B1" if value else b"B0"
    if isinstance(value, int):
        return b"I" + str(value).encode("ascii")
    if isinstance(value, str):
        return b"S" + value.encode("utf-8")
    if is_dataclass(value):
        value = tuple(getattr(value, item.name) for item in fields(value))
    if isinstance(value, (tuple, list)):
        return b"T" + b"".join(_frame(encode(item)) for item in value)
    raise TypeError(f"unsupported canonical value: {type(value).__qualname__}")


def behavioral_state_bytes(state: model.EnvelopeState) -> bytes:
    operational = tuple(
        getattr(state, field_name)
        for field_name in model.EnvelopeState.__dataclass_fields__
        if field_name not in model.BEHAVIORAL_PROJECTION_ERASED_STATE_FIELDS
    )
    receipt_semantics = tuple(
        sorted(
            model._receipt_semantic_fact(receipt)
            for receipt in state.evidence_receipts
        )
    )
    decision_semantics = model._decision_semantic_fact(state.decision_receipt)
    recovery_semantics = tuple(
        model._recovery_semantic_fact(receipt)
        for receipt in state.recovery_receipts
    )
    return encode(
        (
            WIRE_SCHEMA,
            operational,
            receipt_semantics,
            decision_semantics,
            recovery_semantics,
        )
    )


def _hex(value: bytes | str) -> str:
    if isinstance(value, str):
        value = value.encode("utf-8")
    return value.hex()


def setup_closure(role: str) -> tuple[list[model.EnvelopeState], list[tuple[int, Any]]]:
    grant = model.fixture_external_grant(role)
    start = model.initial_state(grant)
    states = [start]
    representatives = {behavioral_state_bytes(start): 0}
    frontier = [0]
    edges: list[tuple[int, Any]] = []
    cursor = 0
    while cursor < len(frontier):
        source = frontier[cursor]
        cursor += 1
        state = states[source]
        if state.phase == "RUNNING":
            continue
        for edge in model.next_states(state):
            target_key = behavioral_state_bytes(edge.state)
            target = representatives.get(target_key)
            if target is None:
                target = len(states)
                representatives[target_key] = target
                states.append(edge.state)
                frontier.append(target)
            edges.append((source, edge))
    if len(states) != EXPECTED_SETUP_STATES or len(edges) != EXPECTED_SETUP_EDGES:
        raise RuntimeError(
            f"setup closure drift: states={len(states)} edges={len(edges)}"
        )
    return states, edges


def emit_setup_closure(role: str) -> None:
    states, graph_edges = setup_closure(role)
    keys = [behavioral_state_bytes(state) for state in states]
    outgoing: dict[bytes, list[tuple[str, str, bytes]]] = {
        key: [] for key in keys
    }
    for source, edge in graph_edges:
        outgoing[keys[source]].append(
            (edge.action_id, edge.actor, behavioral_state_bytes(edge.state))
        )
    print(
        "\t".join(
            (
                "F0_C4_RUST_SETUP_CLOSURE_V1",
                role,
                str(len(states)),
                str(len(graph_edges)),
            )
        )
    )
    for key in sorted(keys):
        encoded_edges = sorted(outgoing[key])
        edge_text = ";".join(
            ":".join((_hex(action), _hex(actor), _hex(target)))
            for action, actor, target in encoded_edges
        )
        print(f"S\t{_hex(key)}\t{len(encoded_edges)}\t{edge_text}")


def bounded_prefix(
    role: str, source_limit: int
) -> tuple[list[model.EnvelopeState], list[tuple[int, Any]], int]:
    """Expand exactly the first ``source_limit`` BFS representatives."""

    if source_limit <= 0:
        raise ValueError("source_limit must be positive")
    grant = model.fixture_external_grant(role)
    start = model.initial_state(grant)
    states = [start]
    representatives = {behavioral_state_bytes(start): 0}
    frontier = [0]
    edges: list[tuple[int, Any]] = []
    cursor = 0
    while cursor < len(frontier) and cursor < source_limit:
        source = frontier[cursor]
        cursor += 1
        for edge in model.next_states(states[source]):
            target_key = behavioral_state_bytes(edge.state)
            target = representatives.get(target_key)
            if target is None:
                target = len(states)
                representatives[target_key] = target
                states.append(edge.state)
                frontier.append(target)
            edges.append((source, edge))
    return states, edges, cursor


def emit_bounded_prefix(role: str, source_limit: int) -> None:
    states, graph_edges, expanded = bounded_prefix(role, source_limit)
    keys = [behavioral_state_bytes(state) for state in states]
    outgoing: dict[bytes, list[tuple[str, str, bytes]]] = {
        key: [] for key in keys
    }
    for source, edge in graph_edges:
        outgoing[keys[source]].append(
            (edge.action_id, edge.actor, behavioral_state_bytes(edge.state))
        )
    print(
        "\t".join(
            (
                "F0_C4_RUST_BOUNDED_PREFIX_V1",
                role,
                str(source_limit),
                str(expanded),
                str(len(states)),
                str(len(graph_edges)),
            )
        )
    )
    for key in sorted(keys):
        encoded_edges = sorted(outgoing[key])
        edge_text = ";".join(
            ":".join((_hex(action), _hex(actor), _hex(target)))
            for action, actor, target in encoded_edges
        )
        print(f"S\t{_hex(key)}\t{len(encoded_edges)}\t{edge_text}")


def emit_bounded_stats(role: str, source_limit: int) -> None:
    """Emit a compact, non-authoritative diagnostic for a wider BFS prefix."""

    if source_limit <= 0:
        raise ValueError("source_limit must be positive")
    states = model.CompactExactStateStore(
        model.EnvelopeState, model.CHILD_STATE_REFERENCE_FIELDS
    )
    representatives = model.ExactStateIndex(
        states,
        projection=model.behavioral_projection,
        projected_equals_at=states.behavioral_identity_equals_at,
    )
    start_index, start_is_new = representatives.intern(
        model.initial_state(model.fixture_external_grant(role))
    )
    if start_index != 0 or not start_is_new:
        raise RuntimeError("initial state was not uniquely interned")
    frontier = [start_index]
    cursor = 0
    edge_count = 0
    action_counts: Counter[str] = Counter()
    while cursor < len(frontier) and cursor < source_limit:
        source = frontier[cursor]
        cursor += 1
        for edge in model.next_states(states[source]):
            target, target_is_new = representatives.intern(edge.state)
            if target_is_new:
                frontier.append(target)
            edge_count += 1
            action_counts[edge.action_id] += 1
    print(
        "\t".join(
            (
                "F0_C4_RUST_BOUNDED_STATS_V1",
                role,
                str(source_limit),
                str(cursor),
                str(len(states)),
                str(edge_count),
            )
        )
    )
    for action_id, count in sorted(action_counts.items()):
        print(f"A\t{_hex(action_id)}\t{count}")


def _emit_trace_point(index: int, state: model.EnvelopeState) -> None:
    state_bytes = behavioral_state_bytes(state)
    outgoing = sorted(
        (
            edge.action_id,
            edge.actor,
            behavioral_state_bytes(edge.state),
        )
        for edge in model.next_states(state)
    )
    edge_text = ";".join(
        ":".join((_hex(action), _hex(actor), _hex(target)))
        for action, actor, target in outgoing
    )
    print(f"P\t{index}\t{_hex(state_bytes)}\t{len(outgoing)}\t{edge_text}")


def emit_trace(role: str, action_ids: list[str]) -> None:
    if not action_ids or any(not action_id for action_id in action_ids):
        raise ValueError("trace action list must be nonempty")
    print(
        "\t".join(
            (
                "F0_C4_RUST_TRACE_V1",
                role,
                str(len(action_ids)),
                ";".join(_hex(action_id) for action_id in action_ids),
            )
        )
    )
    state = model.initial_state(model.fixture_external_grant(role))
    for index, action_id in enumerate(action_ids):
        _emit_trace_point(index, state)
        matches = [
            edge for edge in model.next_states(state) if edge.action_id == action_id
        ]
        if len(matches) != 1:
            raise RuntimeError(
                f"trace action is not uniquely enabled: {index}:{action_id}:{len(matches)}"
            )
        state = matches[0].state
    _emit_trace_point(len(action_ids), state)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("setup-closure", "bounded-prefix", "bounded-stats", "trace"),
    )
    parser.add_argument("--role", choices=("PRODUCER", "CHECKER"), required=True)
    parser.add_argument("--source-limit", type=int)
    parser.add_argument("--actions")
    arguments = parser.parse_args()
    if arguments.command == "setup-closure":
        if arguments.source_limit is not None or arguments.actions is not None:
            parser.error("setup-closure accepts only --role")
        emit_setup_closure(arguments.role)
    elif arguments.command == "bounded-prefix":
        if arguments.actions is not None:
            parser.error("--actions is not valid for bounded-prefix")
        if arguments.source_limit is None or arguments.source_limit <= 0:
            parser.error("bounded-prefix requires a positive --source-limit")
        emit_bounded_prefix(arguments.role, arguments.source_limit)
    elif arguments.command == "bounded-stats":
        if arguments.actions is not None:
            parser.error("--actions is not valid for bounded-stats")
        if arguments.source_limit is None or arguments.source_limit <= 0:
            parser.error("bounded-stats requires a positive --source-limit")
        emit_bounded_stats(arguments.role, arguments.source_limit)
    elif arguments.command == "trace":
        if arguments.source_limit is not None:
            parser.error("--source-limit is not valid for trace")
        if arguments.actions is None:
            parser.error("trace requires --actions")
        emit_trace(arguments.role, arguments.actions.split(","))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
