# 0326 — Candidate-4 Rust execution-refinement boundary validation

## Result

`candidate4-full-20260814T130141Z` is validated as a durable,
positive-ineligible `RAW_CAPTURE_INCOMPLETE` result.  The current exact
behavioral-quotient inputs must not be replayed unchanged.  G6 is open with
retry disabled pending a Python/Rust differential refinement; G7 remains
blocked by `NO_COMPLETE_G6_CAPTURE`.

## Evidence checks

The root-owned VM-native evidence contains a `RAW_COMMIT.json` whose capture
status is incomplete, whose positive-eligibility field is false, and whose
reduction field is false.  Its digest is
`23a3c1a64f082171cc0827c1296549a7f44fad4d65e1bfce506f0bac56d98eec`.
The committed manifest digest is
`91b0921a38da532e93e3f8cd9aa2b38d74cb6adb202a83cc19f40e716c16bd61`;
it binds three component receipts and the exact current child-model digest
`033170ef47e877890dfbb9f31f7bc32e0a3a0e0d0277499f81582d2f69c07888`.

The failed child receipt establishes:

- `DEADLINE_EXCEEDED` at the sealed 43,200-second bound;
- 43,198,293,123 CPU microseconds and one peak PID;
- 4,659,470,336 bytes peak memory below the 8,053,063,680-byte limit;
- zero memory-limit, OOM, OOM-kill, and group-kill events;
- empty stdout and stderr and no result framing;
- direct-I/O private ext4 use with 3,963,437,056 allocated bytes;
- `populated 0`, component kill-and-drain, unmount, loop detach, and backing
  removal.

Systemd reports the trusted capture unit `Result=success` and
`ExecMainStatus=0`, meaning capture/finalization completed; the host launcher
reports `Result=exit-code` and status 1, correctly mapping the incomplete
candidate result to a failed campaign.  Service exit is not used as semantic
success.

## Mechanical policy

The current-state consistency checker binds the newest attempt, observation
digest, readiness digest, exact child bytes, resource classification, and
fail-closed G6/G7 disposition.  It also rejects a Rust path that changes either
transition relation or the behavioral projection, drops full collision
equality, omits deterministic differential checks, uses an unpinned or
non-reproducible toolchain, bypasses clean authority-disjoint installation, or
claims a production hot-path change.

The recorded readiness state is
`G6_RETRY_BLOCKED_PENDING_RUST_DIFFERENTIAL_REFINEMENT`.  It is a work gate,
not evidence that a Rust implementation exists or that full reachability will
fit the next deadline.  No G6, G7, F0, R11, K0/G0, protection, performance,
cost, Linux/Monitor, cluster, or deployment credit is granted.

