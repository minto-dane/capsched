#!/usr/bin/env python3
"""Compare named exact hostile-WF fixtures against independent Rust checks."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
BINARY = HERE / "target/release/f0-c4-rust-engine"
sys.path.insert(0, str(HERE.parent))

from hostile_wf_fixtures import (  # noqa: E402
    FIXTURE_HEADER,
    MAPPED_ORIGINAL_CASE_CREDITS,
    ORIGINAL_CASE_TOTAL,
    SUPPLEMENTAL_EDGE_CASES,
    cases,
    expected_result_bytes,
    fixture_bytes,
)


def run_rust(path: Path) -> bytes:
    return subprocess.run(
        [str(BINARY), "hostile-wf", "--fixtures", str(path)],
        cwd=HERE,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout


def require_malformed_rejected(path: Path, value: bytes, label: str) -> None:
    path.write_bytes(value)
    result = subprocess.run(
        [str(BINARY), "hostile-wf", "--fixtures", str(path)],
        cwd=HERE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode == 0 or result.stdout:
        raise SystemExit(f"error: malformed hostile fixture accepted: {label}")


def main() -> int:
    if sys.version_info < (3, 10):
        raise SystemExit("error: Python 3.10 or newer is required")
    subprocess.run(
        ["cargo", "build", "--release", "--locked", "--offline"],
        cwd=HERE,
        check=True,
    )
    fixtures = cases()
    encoded = fixture_bytes(fixtures)
    expected = expected_result_bytes(fixtures)
    with tempfile.TemporaryDirectory(prefix="f0-c4-hostile-wf-") as temporary:
        path = Path(temporary) / "fixtures.tsv"
        path.write_bytes(encoded)
        first = run_rust(path)
        second = run_rust(path)
        lines = encoded.splitlines()
        fields = lines[1].split(b"\t")
        edge_fields = next(line for line in lines[1:] if line.startswith(b"E\t")).split(
            b"\t"
        )
        header = FIXTURE_HEADER.encode("ascii")

        def one_record(record: bytes) -> bytes:
            return header + b"\t1\n" + record + b"\n"

        malformed = {
            "zero-count": header + b"\t0\n",
            "leading-zero-count": header + b"\t081\n"
            + b"\n".join(lines[1:])
            + b"\n",
            "count-mismatch": header + b"\t1\n",
            "duplicate-id": header + b"\t2\n"
            + lines[1]
            + b"\n"
            + lines[1]
            + b"\n",
            "uppercase-id-hex": b"\t".join((fields[0], fields[1].upper(), fields[2]))
            + b"\n",
            "uppercase-payload-hex": b"\t".join(
                (fields[0], fields[1], fields[2].upper())
            )
            + b"\n",
            "odd-payload-hex": b"\t".join((fields[0], fields[1], b"0")) + b"\n",
            "truncated-canonical": b"\t".join(
                (fields[0], fields[1], b"T2:N".hex().encode("ascii"))
            )
            + b"\n",
            "extra-field": lines[1] + b"\textra\n",
            "edge-missing-after": one_record(b"\t".join(edge_fields[:-1])),
            "edge-empty-action": one_record(
                b"\t".join((edge_fields[0], edge_fields[1], b"", *edge_fields[3:]))
            ),
            "edge-uppercase-action-hex": one_record(
                b"\t".join(
                    (
                        edge_fields[0],
                        edge_fields[1],
                        edge_fields[2].upper(),
                        *edge_fields[3:],
                    )
                )
            ),
            "edge-uppercase-before-hex": one_record(
                b"\t".join((*edge_fields[:4], edge_fields[4].upper(), edge_fields[5]))
            ),
            "crlf": encoded.replace(b"\n", b"\r\n"),
            "missing-final-newline": encoded[:-1],
        }
        for label, malformed_bytes in malformed.items():
            if not malformed_bytes.startswith(header):
                malformed_bytes = one_record(malformed_bytes.rstrip(b"\n"))
            require_malformed_rejected(path, malformed_bytes, label)
    if first != expected:
        raise SystemExit(
            "error: Python/Rust hostile-WF results differ\n"
            f"python={expected!r}\nrust={first!r}"
        )
    if second != first:
        raise SystemExit("error: nondeterministic Rust hostile-WF results")

    kind_counts = {"edge": 0, "grant": 0, "state": 0}
    for fixture in fixtures:
        kind_counts[{"E": "edge", "G": "grant", "S": "state"}[fixture.kind]] += 1
    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-hostile-wf-differential-v2",
                "case_count": len(fixtures),
                "claim_credit": False,
                "complete_295_case_parity": False,
                "fixture_sha256": hashlib.sha256(encoded).hexdigest(),
                "kind_counts": kind_counts,
                "malformed_fixture_cases": len(malformed),
                "mapped_original_case_credits": MAPPED_ORIGINAL_CASE_CREDITS,
                "remaining_original_case_credits": (
                    ORIGINAL_CASE_TOTAL - MAPPED_ORIGINAL_CASE_CREDITS
                ),
                "result_sha256": hashlib.sha256(first).hexdigest(),
                "rust_runs": 2,
                "status": "pass",
                "supplemental_edge_cases": SUPPLEMENTAL_EDGE_CASES,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
