# Validation 0243: SchedExecLease P5A-R4 E3 Concurrency Source Gate Launch

Date: 2026-07-17

Status: attempt 1 completed but is invalidated by validation/0244. This launch
record never claimed a pass. Corrected r2 is the only allowed rerun.

## Frozen Inputs

```text
N-133 canonical r13 SHA-256
  79a9c62edc8dfa58645028c9ab43af9554f7672bbae267f8b5c7ab0c9157c912
N-133 independent r14 SHA-256
  2be94265244a7cde6ff5f4d353133fa6315b692b65ad762b743ac0a89d309537
R4-E2 parent
  a429fc30252ac6af94c51d96cd4ac24e72d9f83b
R4-E3 candidate
  f9c737c93ecff48c6f512048b05b1b49f4a54ca5
candidate tree
  274f7b5d6969dc68e158819191fe598f9587e0ad
candidate diff SHA-256
  c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781
source-gate runner SHA-256
  0f5a6987b40cf4c443b65a4e517773d3f45aa7d8384f777a99d3a146f6b586b4
```

The candidate is a clean one-commit direct child and changes exactly
`init/Kconfig` and `kernel/sched/exec_lease.c`, with 2,758 additions and no
deletions. Strict source and commit style checks are `0/0/0`.

## Independent Gate

Runner
`run-sched-exec-lease-p5a-r4-e3-concurrency-source-gate.sh` refuses reused or
unsafe output IDs, locks all repository and evidence identities, creates a
temporary exact E2 checkout, checks the two-file/additive/byte-preservation
boundary, verifies the exact 36-case and six-fault contract, rejects forbidden
runtime surfaces and hard-IRQ lock/allocation/wait operations, and writes its
result atomically. The plan, N-133 results, hardening helper, and runner are
verified read-only snapshots; builds use isolated E2 and E3 worktrees created
from the fixed Git objects rather than requiring the mutable development
checkout to remain on disk.

The build phase uses fresh per-architecture output for all four modes:

1. exact R4-E2 parent;
2. all R4 options off;
3. R4 layout on and E3 test off;
4. R4 E3 test on.

On arm64 and x86_64 it must preserve all 58 private and 51 expanded probe
values, emit no E3 symbol, relocation, string, or initcall artifact when
disabled, and emit the exact suite and IRQ/work bridge when enabled. Build
scratch and both temporary E2/E3 checkouts are removed on every exit.

## Preflight

Run `20260717T-p5a-r4-e3-source-preflight-r6` passed every non-build check and
then intentionally stopped. Its output, temporary worktree, and scratch were
removed, so it cannot be mistaken for canonical evidence.

## Canonical Launch

```text
run id:   20260717T-p5a-r4-e3-source-gate-r1
job name: p5a-r4-e3-source-gate
machine:  domainlease-dev
monitor:  ./tools/long-job.sh watch p5a-r4-e3-source-gate 30
```

The detached wrapper records progress, process/result probes, runner exit
status, and a validated completion state across chat or host-terminal exits.

Attempt 1 returned exit zero and a provisional result, but independent log
closure found two x86_64 modes with future-mtime and GNU make clock-skew
warnings. The old runner had no build-warning gate. Therefore its provisional
result cannot authorize the diagnostic matrix; see validation/0244.

## Decision Boundary

A passing result may authorize only the separately fixed six-boot diagnostic
matrix. Until that result exists, diagnostic boot launch is blocked. Even a
source-gate pass does not by itself accept R4-E3 correctness, runtime behavior,
primary/patch promotion, monitor enforcement, production protection,
deployment, multi-node, multi-cluster, or datacenter readiness.
