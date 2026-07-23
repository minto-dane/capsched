# Validation 0267: SchedExecLease P5A-R4 E4 Arm64 Timing R4 KUnit Rejection and Source Retry

Date: 2026-07-21

Status: arm64 timing r4 is immutably rejected as a synthetic KUnit-fixture
failure. Two independent read-only closures reproduce one normalized decision.
The smallest fail-closed source correction is committed and short-gated, but a
fresh six-object and six-profile E3 regression plus independent double closure
remain mandatory before any new timing run.

## Exact R4 Decision

Detached job `p5a-r4-e4-arm64-timing-r4`, run
`20260721T-p5a-r4-e4-arm64-timing-r4`, built the exact arm64 Image and exited
QEMU zero after an orderly KUnit shutdown. Compiler diagnostics are empty and
the paused-QMP placement contract passed: exactly two vCPU TIDs mapped to
indexes 0 and 1, singleton affinity to host CPUs 0 and 1 was revalidated, and
zero measurement rows existed before resume.

The result is nevertheless sealed as `harness_failed/evidence_validation` at
SHA-256
`f5f06d933700f74b96f13397fa3b84a7a7a2875e1fcbb19e33b37d825a0132d4`.
The KUnit suite passed five cases and failed two:

```text
recovery: line 4160, fixture setup returned -EINVAL for B_MAX=64
offline:  line 4727, fixture setup returned -EINVAL while advancing to occupancy=8
suite:    pass=5 fail=2 skip=0 total=7
```

Only 523 of 682 result rows and five of seven summaries exist. Exact family
counts are publication 288, picker-kick 144, IRQ dispatch 9, recovery 0,
notifier 48, current-stop 24, and offline 10. Every partial value and every
observed threshold rejection receives zero architecture, performance, or
x86_64 authorization credit.

The storage controls also completed: pre-run trim reclaimed 975,572,992 bytes,
the launch observed 53,959,464 KiB shared-host free, and post-run trim reclaimed
245,980,114,944 bytes. Both run-owned scratch roots are absent and the archived
Image and `exec_lease.o` losslessly restore to their manifest hashes.

## Independent Failure Closure

The closure runner at SHA-256
`c5b1fc53052e59f69d965069253dfaceb6529efd2050a03506fa4ee1784b99b0`
race-checks and snapshots all 40 timing files totaling 34,231,272 bytes plus
eight selected job-control files totaling 29,738 bytes. It verifies the sealed
result, both exact assertions and `-EINVAL` values, all row and summary
cardinalities, KTAP 5/2/0/7 totals, QEMU zero exit, QMP placement, empty
diagnostics, both trim phases, lossless archives, read-only inputs, and retired
scratch.

```text
r1 result: 2a2da5fe97fe40474dd31581cac95852db881c0e08ebf4bc16fbbb2f87c7e01f
r2 result: 600e98938ade8a2195efeded93ec502dda49cd7708413a4364e851ea84c09a67
normalized: 3e23453369db1c4dcb1f64b1e36357e49e37221c8a152956e581b78e49e003a2
```

Deleting only `run_id` produces byte-identical normalized results. The focused
test accepts the exact fixture and rejects job-log mutation, serial mutation,
a symlinked evidence root, and a symlinked job input.

## Root Cause and Minimal Correction

The synthetic helpers treated a post-return state sample as authoritative after
`irq_work_queue()` or `queue_work()` returned false. That return already proves
that the same work item had a live coalesced owner at its linearization point.
Under the larger fixture, the owner could complete between the false return and
the diagnostic `pending`/`running` read; the diagnostic then incremented
`protocol_errors` even though the dirty work drained and the environment became
idle. Fixture setup mapped that diagnostic-only count to `-EINVAL`.

The correction removes only those racy post-return error upgrades in the three
default-off synthetic helpers: irq-work kick, recovery-work dispatch, and
notifier queueing. False recovery dispatch with no later visible state is
classified with the completed/running outcome. No matrix, threshold, sample,
lock, refcount, production helper, scheduler attachment, or ordinary runtime
path changes.

The repaired feature remains an exact direct child of R4-E3:

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement
parent:    da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:    82d91805f8e145d2403057f656e590e4bcae12f1
tree:      44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f
diff SHA:  a7cb42fe5fc6f346ba8ea009097fa15433050e79e3255d64467d7b8ad636aeb9
files:     init/Kconfig, kernel/sched/exec_lease.c
numstat:   +1749 -91
```

Strict checkpatch reports zero errors, warnings, and checks. Focused arm64 and
x86_64 E4-on `W=1` object builds pass. Source-only gate
`20260721T-p5a-r4-e4-coalesced-owner-source-only-r1` verifies the exact
direct-child identity, two-file boundary, 36 byte-preserved E3 cases, immutable
682-cell contract, and absence of `protocol_errors++` from all three
coalesced-owner helpers, then retires both worktrees.

## Re-authorization Boundary

The prior six-profile evidence and closure bind commit `5857720d...`; they
cannot authorize `82d91805...`. The next and only authorized long operation is
a fresh combined source/E3 run. It must produce six diagnostic-free objects,
six complete standard/fault/KASAN/KCSAN profiles, 216/216 E3 cases, 216/216
typed receipts, zero warning reports, and complete scratch retirement. Two new
independent read-only closures must then agree before any arm64 timing retry.

x86_64 timing remains blocked. Live scheduler attachment, N-136 charging,
bare-metal latency, runtime enforcement, monitor delivery, performance, cost,
production protection, deployment, multi-node, multi-cluster, and datacenter
claims remain false.
