# Validation Index

Updated: 2026-06-26

## Current Validation Records

| ID | Status | Title |
| --- | --- | --- |
| 0001 | Passed for tiny finite model | Runnable Lease TLC Check |
| 0002 | Executed by systemd user runner | L0 Slice 0 Build Validation Plan |
| 0003 | Partially blocked by missing host dependency | L0 Slice 0 Validation Attempt |
| 0004 | Passed | L0 Slice 0 Systemd User Build Run |
| 0005 | Passed for tiny finite model | Endpoint Async Provenance TLC Check |

## Principles

Validation principles:

- Validate semantic claims, not only whether tests pass.
- Separate Linux-only prototype claims from monitor-backed protection claims.
- Treat security invariants as explicit properties.
- Record negative results and counterexamples.
- Prefer small models before broad prototypes.

Candidate validators/verifiers:

- TLA+ for state-machine safety and liveness properties.
- Alloy for relational capability/object invariants.
- KUnit for kernel-local unit properties once implementation exists.
- LKDTM or targeted fault-injection style tests for boundary behavior.
- syzkaller-style fuzzing after a minimal prototype exists.
- perf/trace/bpftrace/ftrace for overhead and scheduling behavior evidence.
