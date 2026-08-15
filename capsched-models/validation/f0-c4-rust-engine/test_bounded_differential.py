#!/usr/bin/env python3
"""Compare bounded Python/Rust BFS prefixes without retaining them in RAM."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


HERE = Path(__file__).resolve().parent
BINARY = HERE / "target/release/f0-c4-rust-engine"
CHUNK_BYTES = 1024 * 1024


def run_to_file(command: list[str], destination: Path) -> float:
    started = time.monotonic()
    with destination.open("wb") as output:
        subprocess.run(command, cwd=HERE, check=True, stdout=output)
        output.flush()
    return time.monotonic() - started


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(CHUNK_BYTES):
            value.update(chunk)
    return value.hexdigest()


def first_mismatch(left_path: Path, right_path: Path) -> int | None:
    offset = 0
    with left_path.open("rb") as left, right_path.open("rb") as right:
        while True:
            left_chunk = left.read(CHUNK_BYTES)
            right_chunk = right.read(CHUNK_BYTES)
            if left_chunk == right_chunk:
                if not left_chunk:
                    return None
                offset += len(left_chunk)
                continue
            for index, (left_byte, right_byte) in enumerate(
                zip(left_chunk, right_chunk, strict=False)
            ):
                if left_byte != right_byte:
                    return offset + index
            return offset + min(len(left_chunk), len(right_chunk))


def graph_summary(path: Path) -> dict[str, object]:
    action_ids: set[str] = set()
    observed_edges = 0
    with path.open("rb") as stream:
        header = stream.readline().decode("ascii").rstrip("\n").split("\t")
        if len(header) != 6 or header[0] != "F0_C4_RUST_BOUNDED_PREFIX_V1":
            raise SystemExit("error: bounded-prefix header differs")
        for line in stream:
            fields = line.rstrip(b"\n").split(b"\t", 3)
            if len(fields) != 4 or fields[0] != b"S":
                raise SystemExit("error: bounded-prefix state record differs")
            declared_outgoing = int(fields[2])
            if not fields[3]:
                if declared_outgoing != 0:
                    raise SystemExit("error: empty edge list has nonzero count")
                continue
            entries = fields[3].split(b";")
            if len(entries) != declared_outgoing:
                raise SystemExit("error: state edge count differs")
            observed_edges += len(entries)
            for entry in entries:
                action_hex = entry.split(b":", 1)[0]
                action_ids.add(bytes.fromhex(action_hex.decode("ascii")).decode("ascii"))
    declared_edges = int(header[5])
    if observed_edges != declared_edges:
        raise SystemExit("error: graph edge total differs")
    return {
        "action_ids": sorted(action_ids),
        "edges": declared_edges,
        "expanded_sources": int(header[3]),
        "states": int(header[4]),
    }


def parse_limits(value: str) -> list[int]:
    try:
        limits = [int(item) for item in value.split(",")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("limits must be comma-separated integers") from error
    if not limits or any(limit <= 0 for limit in limits):
        raise argparse.ArgumentTypeError("every source limit must be positive")
    if len(limits) != len(set(limits)):
        raise argparse.ArgumentTypeError("source limits must be unique")
    return limits


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-limits",
        type=parse_limits,
        default=parse_limits("1,50,250,1000"),
    )
    arguments = parser.parse_args()
    if sys.version_info < (3, 10):
        raise SystemExit("error: Python 3.10 or newer is required")

    subprocess.run(
        ["cargo", "build", "--release", "--locked", "--offline"],
        cwd=HERE,
        check=True,
    )

    results = []
    with tempfile.TemporaryDirectory(prefix="f0-c4-prefix-diff-") as temporary:
        temporary_root = Path(temporary)
        for role in ("PRODUCER", "CHECKER"):
            for source_limit in arguments.source_limits:
                python_output = temporary_root / f"python-{role}-{source_limit}"
                rust_output = temporary_root / f"rust-{role}-{source_limit}"
                python_seconds = run_to_file(
                    [
                        sys.executable,
                        str(HERE / "python_oracle.py"),
                        "bounded-prefix",
                        "--role",
                        role,
                        "--source-limit",
                        str(source_limit),
                    ],
                    python_output,
                )
                rust_command = [
                    str(BINARY),
                    "bounded-prefix",
                    "--role",
                    role,
                    "--source-limit",
                    str(source_limit),
                ]
                rust_seconds = run_to_file(rust_command, rust_output)
                mismatch = first_mismatch(python_output, rust_output)
                if mismatch is not None:
                    raise SystemExit(
                        "error: Python/Rust bounded prefix differs "
                        f"role={role} source_limit={source_limit} byte={mismatch} "
                        f"python_size={python_output.stat().st_size} "
                        f"rust_size={rust_output.stat().st_size}"
                    )
                output_sha256 = digest(rust_output)
                summary = graph_summary(rust_output)
                results.append(
                    {
                        "action_count": len(summary["action_ids"]),
                        "action_ids": summary["action_ids"],
                        "canonical_bytes": rust_output.stat().st_size,
                        "canonical_sha256": output_sha256,
                        "edges": summary["edges"],
                        "expanded_sources": summary["expanded_sources"],
                        "python_seconds": round(python_seconds, 6),
                        "role": role,
                        "rust_seconds": round(rust_seconds, 6),
                        "source_limit": source_limit,
                        "states": summary["states"],
                    }
                )
                python_output.unlink()
                rust_output.unlink()

    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-bounded-prefix-differential-v1",
                "claim_credit": False,
                "comparison": "byte-exact-canonical-graph",
                "results": results,
                "status": "pass",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
