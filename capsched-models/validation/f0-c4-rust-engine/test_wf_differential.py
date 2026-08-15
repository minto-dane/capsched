#!/usr/bin/env python3
"""Compare independent Rust WF with normative Python WF over a BFS prefix."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


HERE = Path(__file__).resolve().parent
BINARY = HERE / "target/release/f0-c4-rust-engine"


def run(command: list[str]) -> bytes:
    return subprocess.run(
        command,
        cwd=HERE,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout


def parse(value: bytes) -> dict[str, object]:
    fields = value.rstrip(b"\n").split(b"\t")
    if len(fields) != 7 or fields[0] != b"F0_C4_RUST_WF_PREFIX_V1":
        raise SystemExit("error: WF-prefix record differs")
    return {
        "role": fields[1].decode("ascii"),
        "source_limit": int(fields[2]),
        "expanded_sources": int(fields[3]),
        "states": int(fields[4]),
        "edges": int(fields[5]),
        "wf_checks": int(fields[6]),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-limit", type=int, default=1_000)
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
        command = [
            "wf-prefix",
            "--role",
            role,
            "--source-limit",
            str(arguments.source_limit),
        ]
        python_bytes = run([sys.executable, str(HERE / "python_oracle.py"), *command])
        rust_command = [str(BINARY), *command]
        rust_bytes = run(rust_command)
        if rust_bytes != python_bytes:
            raise SystemExit(
                "error: Python/Rust WF-prefix evidence differs "
                f"role={role} source_limit={arguments.source_limit}\n"
                f"python={python_bytes!r}\nrust={rust_bytes!r}"
            )
        if run(rust_command) != rust_bytes:
            raise SystemExit(f"error: nondeterministic Rust WF-prefix output: {role}")
        parsed = parse(rust_bytes)
        if parsed["wf_checks"] != parsed["edges"] + 1:
            raise SystemExit(f"error: incomplete WF checks: {role}")
        results.append(
            {
                **parsed,
                "canonical_sha256": hashlib.sha256(rust_bytes).hexdigest(),
            }
        )
    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-independent-wf-differential-v1",
                "claim_credit": False,
                "comparison": "independent-rust-instance-and-evidence-wf",
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
