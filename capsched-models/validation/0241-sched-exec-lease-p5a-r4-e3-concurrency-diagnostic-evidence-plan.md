# Validation 0241: SchedExecLease P5A-R4 E3 Concurrency and Diagnostic Evidence Plan

Date: 2026-07-17

Status: plan semantics passed, but the r5/r6 evidence-generator seal is
superseded by validation/0242. The exact disposable, default-off R4-E3
two-file synthetic KUnit source draft remains authorized. R4-E3 source,
concurrency correctness, scheduler behavior, and production use remain
unaccepted. Do not cite r5/r6 as sealed generator evidence.

## Scope

The gate validates:

```text
analysis/0174-sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan.md
analysis/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json
formal/0137-p5a-r4-e3-concurrency-diagnostic-evidence-plan-model/
validation/run-sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan.sh
```

It binds the exact R4-E2 parent/commit/tree/diff, tracked input-contract and
result-metadata hashes, dual-architecture result, two independent closure
results, primary Linux identity, and patch-queue commit/series/tail.

## Corrected Attempts

The first two attempts are retained as harness/model evidence rather than
being misclassified as engineering failures:

```text
r1  stopped before model checking: the runner treated capsched-relative
    tracked contracts as workspace-relative build evidence

r2  source and safe checks passed; 75/76 unsafe faults counterexampled;
    NewestDesiredLost unexpectedly passed because the formal invariant did
    not require desiredGeneration == 2 after the generation-2 publication
```

The runner now resolves tracked `capsched-models/` inputs relative to the
capsched repository and build evidence relative to the workspace. The model
now freezes desired generation from republish through the first recovery.
Targeted safe and `NewestDesiredLost` runs passed before the complete rerun.

No source, E2 evidence, kernel object, or promotion boundary changed in either
correction.

The corrected semantic runs r3/r4 then passed and reproduced all stable
fields. Commit review subsequently sealed the evidence generator itself:
`RUN_ID` now accepts only `[A-Za-z0-9._-]`, an existing `result.json` cannot be
overwritten, the locale is fixed, and the runner pathname and SHA-256 are
recorded in every result. Final canonical/reproduction evidence therefore uses
r5/r6 below; r3/r4 remain pre-seal confirmation, not the cited final result.

## Historical Pre-Hardening Runs (Superseded)

The r5/r6 results below preserve the evidence available when this record was
written. A later exhaustive diff review reproduced three generator-robustness
defects: dot-segment RUN_ID/output-root reuse, count-only plan substitution,
and hash-then-reopen input races. Validation/0242 fixes all three and replaces
r5/r6 with canonical r9/r10. The plan/model semantics recorded here remain
valid; only the generator-seal claim is superseded.

Canonical:

```bash
RUN_ID=20260717T-p5a-r4-e3-concurrency-plan-r5
container machine run -n domainlease-dev \
  --workdir /Users/niania/Documents/linux-cap/capsched \
  env RUN_ID="$RUN_ID" \
  ./capsched-models/validation/\
run-sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan.sh
```

Result:

```text
build/source-check/
  sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan/
  20260717T-p5a-r4-e3-concurrency-plan-r5/result.json
SHA-256 113fe8ddd65da0961d11c2251cef76c5016c7ad0a9fe90e0a690b34d46dc22a0
```

Independent reproduction `20260717T-p5a-r4-e3-concurrency-plan-r6` passed with
result SHA-256
`35157c866049948e72880ba334408ef77c08718226f72c6635ff9a91a14fd5b7`.
After removing only `run_id` and the run-specific manifest pathname, every
field is identical; the canonical normalized SHA-256 is
`9e232bc1292e652a4c15fdf3dbd5220779fb1fafb157fd9528f961800260c1a6`.
Both runs independently produced the same source-object manifest SHA-256
`d820f285d5486b5b7ddf287302ff41379d3718389ac3e9f0d648e494b59820c2`.
Both also bind runner SHA-256
`2bc0e914d154a91a4085e87631258939246f8f3a2467c7d337725785d6842b42`.

## Input and Source Closure

The gate revalidated:

```text
primary Linux commit/tree:
  5e1ca3037e34823d1ba0cdd1dc04161fac170280
  54f685aad94f28f0027cbba18cf5e29aadce234a

R4-E2 candidate commit/tree/diff:
  a429fc30252ac6af94c51d96cd4ac24e72d9f83b
  fffd419bbc05bab87ad304c1e4a3213439d62bab
  94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15

R4-E2 dual-architecture result:
  6346c3570008942fae533395ff4eb1165c3d42c6572d134c945e20fb57cbad1e
R4-E2 closure result:
  fed621ee76effc554df806f40f6289d375dafe3f127427a9be73d6ff2ddcc048
post-retirement closure reproduction:
  27f5a7acc52cc3852ca049a6abc07a72bce2c4e99e7a1a2e02167548a7b3d0f6

patch queue commit/series blob:
  16bb080da472ffabbbafd2698073eca633fb0602
  298567f8e0bd18168222da4e64da32750b9ea818
```

All 12 unique source objects were hashed. All 48 primary/candidate source
anchors passed and all ten future E3 names were absent from the candidate.
The runner independently rechecked the CPUHP source order
`WORKQUEUE_ONLINE < ONLINE_DYN < AP_ACTIVE`, hence reverse teardown remains
`AP_ACTIVE -> ONLINE_DYN -> WORKQUEUE_ONLINE`.

## Fixed Future Source Boundary

```text
parent:    a429fc30252ac6af94c51d96cd4ac24e72d9f83b
branch:    codex/p5a-r4-e3-concurrency-prototype
worktree:  build/DomainLeaseLinux.volume/worktrees/
             p5a-r4-e3-concurrency-prototype
files:     init/Kconfig, kernel/sched/exec_lease.c
config:    CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST, default n
suite:     sched_exec_lease_r4_concurrency
```

The future draft stays in the E2 translation unit, preserves all 51 expanded
and 58 R4-private values, and adds no production hook or public surface. It
may instantiate the E2-private types only inside a synthetic KUnit control
plane with real locks, refs, XArray/cpumask, irq-work, unbound work, and RCU.

## Correctness and Diagnostic Contract

The plan freezes:

```text
B_max cases                         0, 1, 63, 64, rejected 65
pre-runnable allocation fault sites 6
deterministic case families          36
stress repetitions/diagnostic boot   2048
hard case timeout                    15 seconds
architectures                        arm64, x86_64
fresh build modes/architecture       4
QEMU diagnostic boots                6
```

The 36 families force the irq-to-work bridge through pending/callback/work
states, false queue returns with retained ownership, final-empty insertion,
self-requeue, one-projection quanta, notifier generation/membership restart,
owner-clear races, late admission and removal around the cursor, independent
current observation, remove-neutral-add migration and destination failure,
every offline phase, cancellation, retirement/RCU, saturation, all allocation
faults, and cleanup reference equations.

The six future boots require arm64/x86_64 standard debug, both-architecture
hotplug plus allocation-fault stress, arm64 generic KASAN, and x86_64 KCSAN.
Every required case and receipt must be present with zero fail, skip, timeout,
or diagnostic warning. Matrix reduction after a failure is forbidden.

## Formal Result

Each complete run produced:

```text
safe states generated       30
safe distinct states        29
complete graph depth        29
states left on queue         0
temporal properties checked  4
unsafe counterexamples      76/76
```

The safe trace covers duplicate kick, republish while irq pending,
dispatch-only irq callback, newest-generation recovery, final-empty insertion
and self-requeue, old notifier tail plus generation/membership restart, late
admission, current request then observation, remove-neutral-add migration, and
offline/retirement/RCU drain.

Every unsafe configuration violated `TypeOK` or `Safety`. The counterexamples
cover exact-input/scope drift, disabled artifacts, oracle coupling, lost
desired generation, dirty/owner duplication, irq/work lost wakeups, multi-
projection recovery, notifier restart/owner-clear/late-admission loss, current
receipt conflation, migration double contribution, offline/cancel ordering,
retirement/ref/RCU faults, diagnostic reduction, accepted warnings, and all
runtime/protection/deployment overclaims.

## Decision

```text
R4-E3 disposable worktree: allowed
R4-E3 exact default-off two-file synthetic source draft: allowed
R4-E3 source/correctness acceptance: blocked on source gate + six boots
R4-E4 planning/source: blocked
live scheduler behavior: blocked
primary Linux or patch queue change: blocked
```

This validation does not establish runtime admission or denial, current-stop
latency, monitor delivery/enforcement, cross-class coverage, production
protection, performance, cost, deployment, multi-node or multi-cluster
operation, or datacenter readiness.
