#!/usr/bin/env python3
"""Build and differentially validate the closed Candidate-4 setup slice."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys


HERE = Path(__file__).resolve().parent
BINARY = HERE / "target/release/f0-c4-rust-engine"


def run(command: list[str], *, capture: bool = False) -> bytes:
    result = subprocess.run(
        command,
        cwd=HERE,
        check=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=None,
    )
    return result.stdout if capture else b""


def main() -> int:
    if sys.version_info < (3, 10):
        raise SystemExit("error: Python 3.10 or newer is required")

    metadata = json.loads(
        run(
            ["cargo", "metadata", "--locked", "--no-deps", "--format-version", "1"],
            capture=True,
        )
    )
    package = metadata["packages"][0]
    if package["name"] != "f0-c4-rust-engine" or package["dependencies"]:
        raise SystemExit("error: Rust refinement dependency boundary drift")

    run(["cargo", "test", "--release", "--locked"])
    run(["cargo", "build", "--release", "--locked"])

    results = []
    for role in ("PRODUCER", "CHECKER"):
        python_bytes = run(
            [sys.executable, str(HERE / "python_oracle.py"), "setup-closure", "--role", role],
            capture=True,
        )
        rust_command = [str(BINARY), "setup-closure", "--role", role]
        rust_bytes = run(rust_command, capture=True)
        if rust_bytes != python_bytes:
            mismatch = next(
                (
                    index
                    for index, (left, right) in enumerate(
                        zip(python_bytes, rust_bytes, strict=False)
                    )
                    if left != right
                ),
                min(len(python_bytes), len(rust_bytes)),
            )
            raise SystemExit(
                "error: Python/Rust setup closure differs "
                f"role={role} byte={mismatch} "
                f"python_size={len(python_bytes)} rust_size={len(rust_bytes)}"
            )
        for repeat in range(3):
            if run(rust_command, capture=True) != rust_bytes:
                raise SystemExit(
                    f"error: nondeterministic Rust output role={role} repeat={repeat}"
                )
        results.append(
            {
                "role": role,
                "states": 57,
                "edges": 58,
                "canonical_bytes": len(rust_bytes),
                "canonical_sha256": hashlib.sha256(rust_bytes).hexdigest(),
            }
        )

    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-setup-differential-v1",
                "claim_credit": False,
                "dependencies": 0,
                "repeated_rust_runs_per_role": 4,
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
