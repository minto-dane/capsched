#!/usr/bin/env python3
"""Compare a wider compact Python/Rust child-model BFS diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time


HERE = Path(__file__).resolve().parent
BINARY = HERE / "target/release/f0-c4-rust-engine"


def run(command: list[str]) -> tuple[bytes, float]:
    started = time.monotonic()
    result = subprocess.run(
        command,
        cwd=HERE,
        check=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout, time.monotonic() - started


def parse(value: bytes) -> dict[str, object]:
    lines = value.rstrip(b"\n").split(b"\n")
    header = lines[0].split(b"\t")
    if len(header) != 6 or header[0] != b"F0_C4_RUST_BOUNDED_STATS_V1":
        raise SystemExit("error: bounded-stats header differs")
    action_counts = {}
    for line in lines[1:]:
        fields = line.split(b"\t")
        if len(fields) != 3 or fields[0] != b"A":
            raise SystemExit("error: bounded-stats action record differs")
        action_id = bytes.fromhex(fields[1].decode("ascii")).decode("ascii")
        if action_id in action_counts:
            raise SystemExit("error: duplicate bounded-stats action")
        action_counts[action_id] = int(fields[2])
    return {
        "action_counts": dict(sorted(action_counts.items())),
        "edges": int(header[5]),
        "expanded_sources": int(header[3]),
        "role": header[1].decode("ascii"),
        "source_limit": int(header[2]),
        "states": int(header[4]),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-limit", type=int, default=10_000)
    arguments = parser.parse_args()
    if arguments.source_limit <= 0:
        parser.error("--source-limit must be positive")
    if sys.version_info < (3, 10):
        raise SystemExit("error: Python 3.10 or newer is required")

    subprocess.run(
        ["cargo", "build", "--release", "--locked", "--offline"],
        cwd=HERE,
        check=True,
    )
    results = []
    for role in ("PRODUCER", "CHECKER"):
        common = ["bounded-stats", "--role", role, "--source-limit", str(arguments.source_limit)]
        python_bytes, python_seconds = run(
            [sys.executable, str(HERE / "python_oracle.py"), *common]
        )
        rust_command = [str(BINARY), *common]
        rust_bytes, rust_seconds = run(rust_command)
        if rust_bytes != python_bytes:
            raise SystemExit(
                "error: Python/Rust bounded stats differ "
                f"role={role} source_limit={arguments.source_limit}"
            )
        rust_repeat, _ = run(rust_command)
        if rust_repeat != rust_bytes:
            raise SystemExit(f"error: nondeterministic Rust bounded stats: {role}")
        summary = parse(rust_bytes)
        results.append(
            {
                **summary,
                "action_count": len(summary["action_counts"]),
                "canonical_sha256": hashlib.sha256(rust_bytes).hexdigest(),
                "python_seconds": round(python_seconds, 6),
                "rust_seconds": round(rust_seconds, 6),
            }
        )

    producer = dict(results[0])
    checker = dict(results[1])
    for value in (producer, checker):
        value.pop("role")
        value.pop("canonical_sha256")
        value.pop("python_seconds")
        value.pop("rust_seconds")
        value.pop("action_counts")
    if producer != checker:
        raise SystemExit("error: producer/checker bounded graph cardinalities differ")
    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-bounded-stats-differential-v1",
                "claim_credit": False,
                "collision_policy": "sha256-bucket-plus-full-canonical-byte-equality",
                "comparison": "exact-cardinality-and-action-multiplicity-diagnostic",
                "results": results,
                "rust_runs_per_role": 2,
                "status": "pass",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
