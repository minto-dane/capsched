#!/usr/bin/env python3
"""Profile the Candidate-4 child graph modulo audit-chain representation.

This diagnostic grants no claim credit.  It keeps every operational field and
every authenticated receipt semantic fact/multiplicity, but erases receipt
sequence numbers, hash-chain links, authentication tags, and the fields that
only point back into that representation.  A separate congruence regression
must justify this projection before reachability may use it.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import resource
import sys
import time
from typing import Any


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


ERASED_STATE_FIELDS = model.BEHAVIORAL_PROJECTION_ERASED_STATE_FIELDS


def operational_projection(state: model.EnvelopeState) -> tuple[object, ...]:
    """Return the non-ledger state that controls all successor generation."""

    return tuple(
        getattr(state, field_name)
        for field_name in model.EnvelopeState.__dataclass_fields__
        if field_name not in ERASED_STATE_FIELDS
    )


def behavioral_projection(state: model.EnvelopeState) -> tuple[object, ...]:
    return model.behavioral_projection(state)


def authority_projection(state: model.EnvelopeState) -> tuple[object, ...]:
    return (
        operational_projection(state),
        model._decision_semantic_fact(state.decision_receipt),
        tuple(
            model._recovery_semantic_fact(receipt)
            for receipt in state.recovery_receipts
        ),
    )


def resident_bytes() -> int:
    status = Path("/proc/self/status")
    if status.is_file():
        for line in status.read_text(encoding="ascii").splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) * 1024
    maximum = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return int(maximum if sys.platform == "darwin" else maximum * 1024)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-limit", type=int, required=True)
    parser.add_argument("--report-every", type=int, default=10_000)
    parser.add_argument(
        "--projection",
        choices=("operational", "authority", "receipt-multiset"),
        default="receipt-multiset",
    )
    parser.add_argument("--diagnose-ledger-conflicts", action="store_true")
    arguments = parser.parse_args()
    if arguments.source_limit <= 0 or arguments.report_every <= 0:
        parser.error("limits must be positive")

    start = model.initial_state(model.fixture_external_grant("PRODUCER"))
    states: list[model.EnvelopeState] = [start]
    project = {
        "operational": operational_projection,
        "authority": authority_projection,
        "receipt-multiset": behavioral_projection,
    }[arguments.projection]
    representatives = {project(start): 0}
    frontier = [0]
    cursor = 0
    edge_count = 0
    next_report = arguments.report_every
    ledger_conflicts = 0
    started = time.monotonic()
    while cursor < len(frontier) and cursor < arguments.source_limit:
        state = states[frontier[cursor]]
        cursor += 1
        for edge in model.next_states(state):
            key = project(edge.state)
            target = representatives.get(key)
            if target is None:
                target = len(states)
                representatives[key] = target
                states.append(edge.state)
                frontier.append(target)
            elif (
                arguments.diagnose_ledger_conflicts
                and arguments.projection == "authority"
                and model.behavioral_projection(states[target])
                != model.behavioral_projection(edge.state)
            ):
                ledger_conflicts += 1
                if ledger_conflicts <= 8:
                    left = {
                        model._receipt_semantic_fact(receipt)
                        for receipt in states[target].evidence_receipts
                    }
                    right = {
                        model._receipt_semantic_fact(receipt)
                        for receipt in edge.state.evidence_receipts
                    }
                    print(
                        json.dumps(
                            {
                                "ledger_conflict": ledger_conflicts,
                                "source_action": edge.action_id,
                                "left_only": sorted(left - right),
                                "right_only": sorted(right - left),
                            },
                            sort_keys=True,
                            separators=(",", ":"),
                        ),
                        flush=True,
                    )
            edge_count += 1
        if cursor >= next_report:
            print(
                json.dumps(
                    {
                        "artifact_id": "f0-c4-behavioral-quotient-profile-v1",
                        "claim_credit": False,
                        "elapsed_seconds": round(time.monotonic() - started, 6),
                        "expanded_states": cursor,
                        "retained_quotient_states": len(states),
                        "pending_frontier_states": len(frontier) - cursor,
                        "edges": edge_count,
                        "resident_bytes": resident_bytes(),
                        "projection": arguments.projection,
                        "progress": f"{min(100, cursor * 100 // arguments.source_limit)}%",
                    },
                    sort_keys=True,
                    separators=(",", ":"),
                ),
                flush=True,
            )
            next_report += arguments.report_every
    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-behavioral-quotient-profile-v1",
                "claim_credit": False,
                "ledger_conflicts": ledger_conflicts,
                "elapsed_seconds": round(time.monotonic() - started, 6),
                "expanded_states": cursor,
                "frontier_empty": cursor == len(frontier),
                "retained_quotient_states": len(states),
                "pending_frontier_states": len(frontier) - cursor,
                "edges": edge_count,
                "resident_bytes": resident_bytes(),
                "projection_erases_only": sorted(ERASED_STATE_FIELDS),
                "receipt_semantic_facts_and_multiplicity_retained": (
                    arguments.projection == "receipt-multiset"
                ),
                "projection": arguments.projection,
                "progress": "100%",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
