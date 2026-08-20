#!/usr/bin/env python3
"""Require exact Python/Rust parity over an all-action witness corpus."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
BINARY = HERE / "target/release/f0-c4-rust-engine"
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as model  # noqa: E402


SETUP = (
    "SUP-001-REQUEST-SCOPE",
    "OBS-002-CONFIGURE-SCOPE-ACK",
    "SUP-003-REQUEST-CHARGED-BOOTSTRAP",
    "OBS-004-CHARGED-BOOTSTRAP-ACK",
    "MON-004B-ACTIVATE-EXECUTION",
    "SUP-005-REQUEST-SANDBOX",
    "OBS-006-SANDBOX-PROFILE-ACK",
    "MON-007-BASELINE-COUNTERS",
    "SUP-008-RELEASE-HOSTILE-PAYLOAD",
)


def to_hidden(
    candidate_action: str,
    *,
    pre_runtime: tuple[str, ...] = (),
    descendant: bool = False,
    async_ref: bool = False,
) -> tuple[str, ...]:
    actions = list(SETUP + pre_runtime)
    actions.extend(
        (
            candidate_action,
            "OBS-013-EOF-VALID",
            "OBS-029-NORMAL-EXIT",
            "OBS-033B-COMPLETION-ARRIVAL",
            "MON-035B-REVOKE-EXECUTION",
            "OBS-036-LEADER-REAPED",
        )
    )
    if descendant:
        actions.append("OBS-032-DESCENDANTS-EXIT")
    actions.extend(
        (
            "OBS-037-VISIBLE-EMPTY",
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
        )
    )
    if async_ref:
        actions.append("OBS-033-ASYNC-REFS-DRAIN")
    actions.extend(
        (
            "MON-039C-PROTECTION-CLOSED",
            "OBS-038-TASK-POPULATION-ZERO",
            "OBS-040-HIDDEN-WORK-DRAINED",
        )
    )
    return tuple(actions)


def terminal_suffix(final_action: str, arbiter_action: str) -> tuple[str, ...]:
    return (
        final_action,
        arbiter_action,
        "OBS-043-CSS-OFFLINE",
        "OBS-044-SCOPE-RELEASED",
        "SUP-045-SEAL-EVIDENCE",
        "SUP-046-DECIDE-LOCAL",
    )


TRACE_CORPUS = (
    (
        "producer-clean",
        "PRODUCER",
        to_hidden("OBS-009A-PRODUCER-CANDIDATE-A")
        + terminal_suffix("MON-041-FINAL-COUNTERS", "ARB-034-COMPLETION-WINS"),
    ),
    (
        "producer-overlimit",
        "PRODUCER",
        to_hidden("OBS-009B-PRODUCER-CANDIDATE-B")
        + terminal_suffix(
            "MON-041B-FINAL-OVERLIMIT-QUOTA", "ARB-034-COMPLETION-WINS"
        ),
    ),
    (
        "producer-final-counter-failure",
        "PRODUCER",
        to_hidden("OBS-009A-PRODUCER-CANDIDATE-A")
        + terminal_suffix(
            "MON-042-FINAL-COUNTERS-FAILED", "ARB-034-COMPLETION-WINS"
        ),
    ),
    (
        "producer-quota",
        "PRODUCER",
        SETUP
        + (
            "MON-026-QUOTA-ARRIVAL",
            "ARB-026B-QUOTA-WINS",
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-013-EOF-VALID",
            "SUP-028-REQUEST-TERMINATION",
            "OBS-030-SIGNAL-EXIT",
            "MON-035B-REVOKE-EXECUTION",
            "OBS-036-LEADER-REAPED",
            "OBS-037-VISIBLE-EMPTY",
            "OBS-039-RMDIR-ATTACH-CLOSED",
            "SUP-039B-CLOSE-ASYNC-ADMISSION",
            "MON-039C-PROTECTION-CLOSED",
            "OBS-038-TASK-POPULATION-ZERO",
            "OBS-040-HIDDEN-WORK-DRAINED",
            "MON-041-FINAL-COUNTERS",
            "OBS-043-CSS-OFFLINE",
            "OBS-044-SCOPE-RELEASED",
            "SUP-045-SEAL-EVIDENCE",
            "SUP-046-DECIDE-LOCAL",
        ),
    ),
    (
        "producer-descendant-drain",
        "PRODUCER",
        to_hidden(
            "OBS-009A-PRODUCER-CANDIDATE-A",
            pre_runtime=("ADV-016-FORK-DESCENDANT",),
            descendant=True,
        )
        + terminal_suffix("MON-041-FINAL-COUNTERS", "ARB-034-COMPLETION-WINS"),
    ),
    (
        "producer-async-drain",
        "PRODUCER",
        to_hidden(
            "OBS-009A-PRODUCER-CANDIDATE-A",
            pre_runtime=("ADV-017-OPEN-ASYNC-REF",),
            async_ref=True,
        )
        + terminal_suffix("MON-041-FINAL-COUNTERS", "ARB-034-COMPLETION-WINS"),
    ),
    (
        "checker-accept",
        "CHECKER",
        to_hidden("OBS-010-CHECKER-ACCEPT")
        + terminal_suffix("MON-041-FINAL-COUNTERS", "ARB-034-COMPLETION-WINS"),
    ),
    (
        "checker-reject",
        "CHECKER",
        to_hidden("OBS-011-CHECKER-REJECT")
        + terminal_suffix("MON-041-FINAL-COUNTERS", "ARB-034-COMPLETION-WINS"),
    ),
    (
        "hostile-rejected",
        "PRODUCER",
        SETUP
        + (
            "ADV-018-ATTACH-ATTEMPT",
            "OBS-023-REJECT-HOSTILE-ATTEMPT",
            "ARB-035-FAULT-WINS",
        ),
    ),
    (
        "hostile-bypass",
        "PRODUCER",
        SETUP + ("ADV-019-FD-ESCAPE-ATTEMPT", "ADV-023B-SUCCEED-HOSTILE-BYPASS"),
    ),
    (
        "setup-failover",
        "PRODUCER",
        ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH",) + SETUP,
    ),
    (
        "internal-frame",
        "PRODUCER",
        SETUP + ("OBS-012-INTERNAL-FRAME", "ARB-035-FAULT-WINS"),
    ),
    (
        "truncated-stream",
        "PRODUCER",
        SETUP
        + ("OBS-029-NORMAL-EXIT", "OBS-014-EOF-TRUNCATED", "ARB-035-FAULT-WINS"),
    ),
    (
        "invalid-stream",
        "PRODUCER",
        SETUP
        + (
            "OBS-009A-PRODUCER-CANDIDATE-A",
            "OBS-015-EOF-INVALID",
            "ARB-035-FAULT-WINS",
        ),
    ),
    (
        "owner-revocation",
        "PRODUCER",
        SETUP + ("EXT-025-REVOKE-RUN", "ARB-035-FAULT-WINS"),
    ),
    (
        "unattributed-limit",
        "PRODUCER",
        SETUP + ("OBS-027-UNATTRIBUTED-LIMIT", "ARB-035-FAULT-WINS"),
    ),
    (
        "runtime-failover",
        "PRODUCER",
        SETUP + ("GRD-024-TAKEOVER-AFTER-PRIMARY-CRASH", "ARB-035-FAULT-WINS"),
    ),
)


def run_to_file(command: list[str], destination: Path) -> None:
    with destination.open("wb") as output:
        subprocess.run(command, cwd=HERE, check=True, stdout=output)


def first_mismatch(left_path: Path, right_path: Path) -> int | None:
    offset = 0
    with left_path.open("rb") as left, right_path.open("rb") as right:
        while True:
            left_chunk = left.read(1024 * 1024)
            right_chunk = right.read(1024 * 1024)
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


def observed_actions(path: Path) -> set[str]:
    result: set[str] = set()
    with path.open("rb") as stream:
        header = stream.readline().rstrip(b"\n").split(b"\t")
        if len(header) != 4 or header[0] != b"F0_C4_RUST_TRACE_V1":
            raise SystemExit("error: trace header differs")
        if header[3]:
            result.update(
                bytes.fromhex(item.decode("ascii")).decode("ascii")
                for item in header[3].split(b";")
            )
        for line in stream:
            fields = line.rstrip(b"\n").split(b"\t", 4)
            if len(fields) != 5 or fields[0] != b"P":
                raise SystemExit("error: trace point differs")
            if not fields[4]:
                continue
            for edge in fields[4].split(b";"):
                action_hex = edge.split(b":", 1)[0]
                result.add(bytes.fromhex(action_hex.decode("ascii")).decode("ascii"))
    return result


def main() -> int:
    if sys.version_info < (3, 10):
        raise SystemExit("error: Python 3.10 or newer is required")
    subprocess.run(
        ["cargo", "build", "--release", "--locked", "--offline"],
        cwd=HERE,
        check=True,
    )

    results = []
    action_coverage: set[str] = set()
    with tempfile.TemporaryDirectory(prefix="f0-c4-trace-diff-") as temporary:
        root = Path(temporary)
        for name, role, actions in TRACE_CORPUS:
            action_value = ",".join(actions)
            python_output = root / f"python-{name}"
            rust_output = root / f"rust-{name}"
            rust_repeat = root / f"rust-repeat-{name}"
            run_to_file(
                [
                    sys.executable,
                    str(HERE / "python_oracle.py"),
                    "trace",
                    "--role",
                    role,
                    "--actions",
                    action_value,
                ],
                python_output,
            )
            rust_command = [
                str(BINARY),
                "trace",
                "--role",
                role,
                "--actions",
                action_value,
            ]
            run_to_file(rust_command, rust_output)
            mismatch = first_mismatch(python_output, rust_output)
            if mismatch is not None:
                raise SystemExit(
                    "error: Python/Rust trace differs "
                    f"trace={name} byte={mismatch} "
                    f"python_size={python_output.stat().st_size} "
                    f"rust_size={rust_output.stat().st_size}"
                )
            run_to_file(rust_command, rust_repeat)
            if first_mismatch(rust_output, rust_repeat) is not None:
                raise SystemExit(f"error: nondeterministic Rust trace: {name}")
            trace_actions = observed_actions(rust_output)
            action_coverage.update(trace_actions)
            results.append(
                {
                    "canonical_bytes": rust_output.stat().st_size,
                    "canonical_sha256": hashlib.sha256(
                        rust_output.read_bytes()
                    ).hexdigest(),
                    "name": name,
                    "observed_action_count": len(trace_actions),
                    "role": role,
                    "selected_steps": len(actions),
                }
            )

    expected_actions = set(model.ACTION_IDS)
    if action_coverage != expected_actions:
        raise SystemExit(
            "error: trace action coverage differs "
            f"missing={sorted(expected_actions - action_coverage)} "
            f"extra={sorted(action_coverage - expected_actions)}"
        )
    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-trace-differential-v1",
                "claim_credit": False,
                "declared_action_count": len(expected_actions),
                "observed_action_ids": sorted(action_coverage),
                "repeated_rust_runs_per_trace": 2,
                "results": results,
                "status": "pass",
                "trace_count": len(TRACE_CORPUS),
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
