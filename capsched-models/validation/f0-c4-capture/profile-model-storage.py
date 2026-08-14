#!/usr/bin/env python3
"""Report bounded Candidate-4 exact-store residency without claim credit."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import resource
import sys
import time
import tracemalloc
from typing import Any


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


def resident_bytes() -> int:
    status = Path("/proc/self/status")
    if status.is_file():
        for line in status.read_text(encoding="ascii").splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) * 1024
        raise RuntimeError("VmRSS is absent from /proc/self/status")
    maximum = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return int(maximum if sys.platform == "darwin" else maximum * 1024)


def compact_column_summary(column: Any) -> dict[str, Any]:
    if column is None:
        return {"implementation": "validated-derived-omitted", "item_bytes": 0}
    if isinstance(column, model._CompactCodeColumn):
        return {
            "implementation": "compact-code",
            "rows": len(column),
            "code_item_bytes": column.itemsize,
            "unique_values": len(column._pool._values),
        }
    if isinstance(column, model._ExactDigestColumn):
        return {
            "implementation": "exact-digest",
            "rows": len(column),
            "fixed_item_bytes": column.itemsize,
            "canonical_rows": column._tags.count(0),
            "fallback_unique_values": len(column._fallback._pool._values),
        }
    if isinstance(column, model._DirectExactReferenceColumn):
        return {
            "implementation": "direct-reference",
            "rows": len(column),
            "item_bytes": column.itemsize,
        }
    if isinstance(column, model._AdaptiveExactReferenceColumn):
        result = compact_column_summary(column.implementation)
        result["implementation"] = "adaptive-" + result["implementation"]
        return result
    if isinstance(column, model._PackedPersistentSequenceColumn):
        arena = column.arena
        return {
            "implementation": "packed-persistent-sequence",
            "rows": len(column),
            "row_item_bytes": column.itemsize,
            "arena_nodes": len(arena),
            "arena_fixed_bytes_per_node": (
                arena.fixed_column_bytes_per_node_upper_bound
            ),
            "arena_records": len(arena._records),
            "record_fixed_bytes_per_row": (
                arena.fixed_column_bytes_per_record_upper_bound
            ),
            "record_fields": {
                name: compact_column_summary(field_column)
                for name, field_column in zip(
                    arena._records._field_names,
                    arena._records._columns,
                    strict=True,
                )
            },
        }
    if isinstance(column, model._ExactReferenceColumn):
        if column.implementation is None:
            return {"implementation": "empty-exact-reference", "rows": 0}
        result = compact_column_summary(column.implementation)
        result["implementation"] = "exact-reference-" + result["implementation"]
        return result
    raise TypeError(type(column).__qualname__)


def snapshot(
    *,
    started: float,
    cursor: int,
    states: model.CompactExactStateStore,
    representatives: model.ExactStateIndex,
    frontier: Any,
    depths: Any,
    targets: Any,
    final: bool,
) -> dict[str, Any]:
    depth_counts = Counter(depths)
    return {
        "schema_version": 1,
        "artifact_id": "f0-c4-bounded-model-storage-profile-v1",
        "claim_credit": False,
        "final": final,
        "elapsed_seconds": round(time.monotonic() - started, 6),
        "expanded_states": cursor,
        "retained_exact_states": len(states),
        "pending_frontier_states": len(frontier) - cursor,
        "expanded_depth": int(depths[cursor - 1]) if cursor else 0,
        "maximum_discovered_depth": max(depth_counts),
        "states_by_shortest_depth": dict(sorted(depth_counts.items())),
        "edges": len(targets),
        "resident_bytes": resident_bytes(),
        "exact_index_capacity": representatives.capacity,
        "state_fixed_column_bytes_per_row": (
            states.fixed_column_bytes_per_state_upper_bound
        ),
        "state_fields": {
            name: compact_column_summary(column)
            for name, column in zip(
                states._field_names,
                states._columns,
                strict=True,
            )
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-limit", type=int, required=True)
    parser.add_argument("--report-every", type=int, default=25_000)
    parser.add_argument("--trace-allocations", action="store_true")
    parser.add_argument("--behavioral-quotient", action="store_true")
    arguments = parser.parse_args()
    if arguments.source_limit <= 0 or arguments.report_every <= 0:
        parser.error("limits must be positive")

    if arguments.trace_allocations:
        tracemalloc.start(1)

    grant = model.fixture_external_grant("PRODUCER")
    initial = model.semantic_projection(model.initial_state(grant))
    states = model.CompactExactStateStore(
        model.EnvelopeState,
        model.CHILD_STATE_REFERENCE_FIELDS,
    )
    representatives = model.ExactStateIndex(
        states,
        projection=(
            model.behavioral_projection
            if arguments.behavioral_quotient
            else None
        ),
        projected_equals_at=(
            states.behavioral_identity_equals_at
            if arguments.behavioral_quotient
            else None
        ),
    )
    initial_index, is_new = representatives.intern(initial)
    if initial_index != 0 or not is_new:
        raise RuntimeError("initial state was not uniquely interned")
    frontier = model._new_array("I", (initial_index,))
    depths = model._new_array("B", (0,))
    targets = model._new_array("I")
    cursor = 0
    next_report = arguments.report_every
    started = time.monotonic()
    while cursor < len(frontier) and cursor < arguments.source_limit:
        source = states[frontier[cursor]]
        source_depth = depths[cursor]
        cursor += 1
        for edge in model.next_states(source):
            target_index, target_is_new = representatives.intern(
                model.semantic_projection(edge.state)
            )
            targets.append(target_index)
            if target_is_new:
                frontier.append(target_index)
                if source_depth == (1 << 8) - 1:
                    raise RuntimeError("profile depth exceeds one byte")
                depths.append(source_depth + 1)
        if cursor >= next_report:
            progress = snapshot(
                started=started,
                cursor=cursor,
                states=states,
                representatives=representatives,
                frontier=frontier,
                depths=depths,
                targets=targets,
                final=False,
            )
            progress.pop("state_fields")
            progress["progress"] = (
                f"{min(100, cursor * 100 // arguments.source_limit)}%"
            )
            print(json.dumps(progress, sort_keys=True, separators=(",", ":")), flush=True)
            next_report += arguments.report_every
    final = snapshot(
        started=started,
        cursor=cursor,
        states=states,
        representatives=representatives,
        frontier=frontier,
        depths=depths,
        targets=targets,
        final=True,
    )
    final["progress"] = "100%"
    final["state_identity"] = (
        "BEHAVIORAL_AUDIT_REPRESENTATION_QUOTIENT"
        if arguments.behavioral_quotient
        else "EXACT_ORDERED_AUDIT_STATE"
    )
    if arguments.trace_allocations:
        final["traced_current_bytes"], final["traced_peak_bytes"] = (
            tracemalloc.get_traced_memory()
        )
        final["largest_allocation_sites"] = [
            {
                "bytes": statistic.size,
                "count": statistic.count,
                "traceback": str(statistic.traceback),
            }
            for statistic in tracemalloc.take_snapshot().statistics("lineno")[:30]
        ]
    print(
        json.dumps(
            final,
            sort_keys=True,
            separators=(",", ":"),
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
