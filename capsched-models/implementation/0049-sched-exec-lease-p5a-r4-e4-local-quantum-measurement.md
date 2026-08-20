# Implementation 0049: SchedExecLease P5A-R4 E4 Local-Quantum Measurement

Date: 2026-07-24

Status: terminal valid-negative arm64 result. Timing r7 completed all 682 cells
and 6,820,000 paired samples with clean build, boot, KUnit, placement, parser,
diagnostic, and artifact checks, but 362 cells produced 692 fixed-gate
breaches. Two independent read-only closures reproduce one normalized
decision. R4, same-source x86_64 timing, and R4-E5 stop; only a source-free
successor analysis is reviewable.

## Source Identity

```text
branch:    codex/p5a-r4-e4-local-quantum-measurement-r7
parent:    da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:    4077ba840f713979c29af64f405dbde39f845d93
tree:      6ce127d738618fd356ed3533ac32e5796fa72d55
diff sha:  a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255
files:     init/Kconfig, kernel/sched/exec_lease.c
line diff: +1768 -97
```

Linux Draft PR: `minto-dane/linux#4`, based on the exact R4-E3 branch.

## Implemented Boundary

`CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST` is default off, depends on the
R4-E3 KUnit suite and built-in KUnit, and registers
`sched_exec_lease_r4_measure` only in the existing private translation unit.
No Makefile, header, scheduler, CPUHP, ABI, primary-Linux, or patch-queue change
is present.

The suite implements the exact seven families and 682 cells:

```text
publication       288
picker/kick       144
hard-IRQ dispatch   9
recovery          144
notifier           48
current stop       24
offline/drain      25
```

Every cell uses 256 warmup pairs and 10,000 alternating treatment/control
pairs. Additional time is saturating subtraction; minimum, p50, p95, p99,
p99.9, and maximum use nearest rank. The source retains the fixed local,
offline-lock, asynchronous-availability, and 700,000ns rejection markers.
There is no all-rq fanout or last-settlement wall-clock gate.

Each complete cell executes under `migrate_disable()`, records its guest CPU,
and compares every control/treatment sample against that CPU. The hard-IRQ
callback records its own CPU, IRQ-disabled state, and preemption depth; the
other six families record the same state at their timing boundary. Every
result row emits the selected CPU, migration count, control/treatment IRQ and
preemption state, and state-error count. Any CPU change or state drift is a
harness error. The later timing runner must additionally record its QEMU/vCPU
placement command and environment.

The E3 worker paths and measurement paths share extracted dispatch,
publication, one-projection recovery, notifier, current-request, and offline
helpers. The 36 E3 case/oracle/receipt bodies remain byte-identical. Measurement
brackets, fixtures, and hard-IRQ timestamps remain inside the default-off test
block.

## Short Verification

```text
git diff --check:                       passed
strict checkpatch:                      0 errors, 0 warnings, 0 checks
arm64 fixed E4-enabled W=1 object:       passed, zero diagnostics
x86_64 fixed E4-enabled W=1 object:      passed, zero diagnostics
source-only corrected contract smoke:      passed, complete cleanup verified
source-only shared-hard-IRQ scope smoke:    passed, complete cleanup verified
```

The short checks are implementation feedback, not source acceptance. Attempt
1 produced six fresh objects and six clean diagnostic boots at 216/216 E3
cases and receipts, but receives no source or timing credit because the gate
was incomplete. The predecessor canonical runner reproduced the entire matrix
at commit `9e4cb44f...` and received an independent read-only closure before
attempt 1. That closure does not transfer to replacement `5857720d...`.

Attempt 2 started no object build or boot and emitted no result. The gate now
preserves `sched_exec_r4_dispatch_irq()` as a separate evidence artifact and
requires each hard-IRQ CPU/IRQ/preemption assignment exactly once in that
shared-helper region. Source-only run
`20260719T-p5a-r4-e4-source-gate-r3-hard-irq-scope` passes this corrected
boundary and retires its worktrees.

## Pre-fix Source and Regression Closure

Canonical combined run
`20260719T-p5a-r4-e4-source-e3-regression-r3` passed all six fresh
arm64/x86_64 source-object modes, all six standard/fault/KASAN/KCSAN E3
profiles, 216/216 cases, and 216/216 typed receipts with zero compiler, final
clock-skew, kernel-warning, case, timeout, QEMU, or network-device failure. Its
combined result SHA-256 is
`9896e12b2882ac88c7b4d57f53c59f7d245b5d3b78717df7d39097af64de8b72`.

Independent closures r1 and r2 snapshot all 267 retained artifacts read-only,
recompute exact object/profile/case/receipt and observability contracts, and
produce result SHA-256 values
`c1d9afa02f516e893e0dd0f910b7d1a60a56f2c1389b9426878545ef6a691325`
and
`9c19029ca7c18d44ec873374c9e85327a7a81d94221b1e10538f19cd16e8633e`.
After removing only `run_id`, both decisions are byte-identical at SHA-256
`ff91f2517b460b4d60322ea1670aab94058a8db4246bf2e2b63b7454250f528f`.
This accepted only predecessor commit `9e4cb44f...` and authorized attempt 1;
it does not transfer to replacement commit `5857720d...` or accept a
measurement result. The separate replacement closure below is authoritative
for timing r2.

## Arm64 Timing Attempt 1 Rejection and Repair

Detached run `20260719T-p5a-r4-e4-arm64-timing-r1` completed approximately
10,300 compiler/link steps, then the build diagnostic gate rejected
`kernel/sched/exec_lease.c:4373`: the notifier KUnit case used a 2,064-byte
stack frame, exceeding the 2,048-byte arm64 warning boundary. No QEMU boot or
measurement row started. The result is `harness_failed` at stage `build`, and
both run-owned build scratch and worktree were retired.

The repair moves only the 192-byte-axes measurement cell to KUnit-managed
memory; fixture lifetime, arrays, synchronization, sample order, thresholds,
and all 682 cells are unchanged. Strict checkpatch remains 0/0/0. Exact arm64
r1-config and x86_64 E4-on W=1 object builds emit zero diagnostics and retire
their scratch. The correction was squashed into a single exact direct child of
R4-E3, so the original source-plan topology remains intact. Fresh full source
and E3 evidence was nevertheless required and has now passed.

## Replacement Source and Regression Closure

Fresh detached run `20260719T-p5a-r4-e4-source-e3-regression-r4` exited zero
after six exact source objects and all six standard/fault/KASAN/KCSAN E3
profiles. It sealed 216/216 cases and 216/216 typed receipts with zero compiler
diagnostic, final clock-skew warning, kernel warning, case failure, skip,
timeout, or nonzero QEMU exit. Combined result SHA-256 is
`2b90c47e69c4c190029bc0fb2b25e66db68f87ec16f0a4d4034f4741caf5d7ea`.

The replacement closure fixes 267 regular artifacts totaling 10,880,574
bytes. Independent closure runs
`20260720T-p5a-r4-e4-source-e3-final-closure-r1` and
`20260720T-p5a-r4-e4-source-e3-final-closure-r2` produce result SHA-256 values
`5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f`
and
`bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720`.
Deleting only `run_id` yields byte-identical SHA-256
`767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21`.
All 536 copied inputs are read-only; result, symlink, hard-IRQ observation,
config, receipt, and artifact-removal mutations fail closed.

## Arm64 Timing Attempt 2 QMP Rejection and Harness Repair

Detached run `20260720T-p5a-r4-e4-arm64-timing-r2` completed the full arm64
Image build and booted QEMU, but sealed `harness_failed` at `qemu_boot`. The
guest emitted exactly one result row at guest time 5.264269 seconds before the
runner could prove complete vCPU placement. The pin record contains only the
QEMU PID and parent CPU allowance; it contains no vCPU entry. No cell, gate,
threshold, performance, or x86_64 credit is accepted. Build/worktree scratch
was retired and the Image plus `exec_lease.o` remain losslessly archived.

The root cause is exact: QEMU 8.2.2 truncated every default Linux task name to
`qemu-system-aar`, while the runner searched for `CPU */TCG`. Diagnostic
`debug-threads=on` restores readable names, but the corrected contract does not
trust names. QEMU now starts with `-S` and a run-owned QMP socket. A hash-bound
Python helper requires paused status, obtains exactly indexes 0 and 1 with
distinct positive TIDs from `query-cpus-fast`, and rejects malformed,
duplicate, missing, or drifting mappings. The shell proves the TIDs belong to
the active QEMU, pins each to a distinct allowed host CPU, and reads back exact
singleton affinity. Immediately before `cont`, the helper re-queries the same
mapping and revalidates each `/proc` Tgid and affinity. Zero result rows are
allowed before resume.

Independent read-only closures
`20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r1` and
`20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r2` audit 68 copied inputs
and produce result SHA-256 values
`749777dbd6e9310538f76146650eca52d6c9d6c721645cb21c99cda196a0b705`
and
`83ec59df2275ab6d6b8c6a9fe2aed9ecb12156ae318b991a9fa1829d47b37e66`.
After removing only `run_id`, both decisions are byte-identical at SHA-256
`9c079b47fae1b7ae45baa6cd7517a9b02af2d6b3f4a9780f180366932e3178ef`.
Result mutation and symlink substitution fail closed.

## Arm64 Timing Harness

The timing runner creates the exact candidate worktree and build output only
on VM-internal ext4, builds one arm64 Image, losslessly preserves and
restore-verifies the Image and `exec_lease.o`, and boots network-disabled QEMU
TCG paused. QMP must return exactly two vCPU indexes and distinct Linux TIDs.
Each TID is singleton-pinned one-to-one to the Apple Container VM's two
distinct allowed host CPUs, and the same QMP mapping plus `/proc` affinity is
reverified before QMP resume. Any result row before resume, mapping/affinity
drift, guest migration, IRQ/preemption-state drift, malformed/missing/duplicate
cell, KUnit failure, compiler/skew/kernel diagnostic, missing artifact, or
cleanup failure is a harness failure. A valid fixed-threshold breach remains
complete negative architecture evidence and stops x86_64.

The independent parser requires exactly 682 unique cells, 6,820,000 recorded
pairs, seven exact summaries, monotonic statistics, source-reported gates equal
to independently recomputed gates, zero migration/state/harness errors, and
hard-IRQ context proof. Its synthetic suite accepts a complete clean matrix and
a valid threshold rejection, while rejecting missing rows, migration, gate
mismatch, unknown fields, and summary mismatch. The QMP helper's 15 negative
fixtures and a real stopped-QEMU integration test verify exact mapping,
singleton affinity, tamper rejection, and paused-to-running transition. Final
replacement config smoke r7 resolves the exact two-vCPU diagnostic
configuration with zero builds and boots, snapshots the corrected runner and
helper, and retires all scratch. A forced insufficient-space control fails
after worktree creation and proves both worktree and build-root retirement.

## Arm64 Timing Attempt 3 Host-Storage Rejection

Detached run `20260721T-p5a-r4-e4-arm64-timing-r3` completed the Image build
and established the corrected paused-QMP contract exactly: indexes 0 and 1
mapped to distinct active-QEMU TIDs, both TIDs were singleton-pinned to host
CPUs 0 and 1, mapping plus `/proc` ownership and affinity were revalidated,
zero rows existed before resume, and QMP reported `running` afterwards.

The run nevertheless sealed `harness_failed/qemu_boot` at result SHA-256
`a35076dc95800d34c39bf3cc38f6e6a7c429aac69a8c1bb88278b48f4669a689`.
The job log contains exactly one `No space left on device`, at the shared-host
progress write. Its last durable counter is 397/682; the serial log contains
399 result rows and one summary. The incomplete matrix receives no threshold,
architecture, performance, or x86_64 credit. Both scratch roots are retired,
Image/object archives restore exactly, and wrapper trim reclaimed
340,478,111,744 bytes from `/dev/vdb`.

Validation/0266 closes the failure twice over 38 timing artifacts and five job
records. Closure r1/r2 results are
`e7d2bb95d9f5899fdbf50a4962d8f2175d879218ccc85135766ef8b9c430700c`
and
`b1f44a63b233182f401f9cc65b5e1176c2874b4915d22d89104e0de556d72b03`;
deleting only `run_id` yields byte-identical SHA-256
`da37226ef0bc0bb6587ce1b234cbdacb09ad133e27986473bc2e7bca5182a624`.
All copied inputs are read-only. An exact copied fixture passes, while job-log
mutation and pin-record symlink substitution fail closed.

Storage-hardened runner
`2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69`
creates an fsync'd 64 MiB seal reserve, checks an 8 GiB shared-host floor at
every progress boundary, preserves exact capacity/write failure reasons, and
releases the reserve before failure or successful result sealing. Config smoke
r8 starts no build or boot and retires all scratch. Forced-capacity control r2
fails before build, seals exact result
`457fb3a7a5f00c0ea40b53af78d09d9f95021678b7003fbd02ef061ca2043c4c`,
releases the reserve, and leaves no scratch. R4 preflight additionally requires
VM trim, at least 32 GiB shared-host free, and at least 16 GiB VM-internal free.

Both standalone and detach-time r4 preflight passed. Job
`p5a-r4-e4-arm64-timing-r4`, run
`20260721T-p5a-r4-e4-arm64-timing-r4`, detached at
`2026-07-21T13:03:24Z` after immediate wrapper trim and capacity readback of
53,959,464 KiB shared-host plus 526,306,264 KiB VM-internal free. Independent
status/probe and a 30-second watch observed the VM-internal Image build advance
from 550 to 850 steps with zero measurement rows; stopping the watch left the
runner active and a later probe observed 1,050 steps.

## Arm64 Timing Attempt 4 KUnit Rejection and Coalesced-Owner Repair

R4 finished with QEMU exit zero, empty compiler diagnostics, exact paused-QMP
placement, and complete storage cleanup, but sealed
`harness_failed/evidence_validation` at result SHA-256
`f5f06d933700f74b96f13397fa3b84a7a7a2875e1fcbb19e33b37d825a0132d4`.
Recovery fixture setup returned `-EINVAL` at line 4160 for 64 buckets. Offline
setup emitted ten rows for occupancies 0 and 1, then returned `-EINVAL` at line
4727 while advancing to occupancy 8. KUnit totals are 5 pass, 2 fail, 0 skip,
7 total. The 523/682 rows and five/seven summaries receive no threshold,
architecture, or x86_64 credit.

Two race-checked read-only closures audit 40 timing files and eight job-control
files. Their result SHA-256 values are
`2a2da5fe97fe40474dd31581cac95852db881c0e08ebf4bc16fbbb2f87c7e01f`
and
`600e98938ade8a2195efeded93ec502dda49cd7708413a4364e851ea84c09a67`;
deleting only `run_id` yields byte-identical
`3e23453369db1c4dcb1f64b1e36357e49e37221c8a152956e581b78e49e003a2`.
The exact fixture passes and four source/job/symlink mutations fail closed.

The source cause is a synthetic diagnostic TOCTOU: false from
`irq_work_queue()` or `queue_work()` already proves a live coalesced owner at
the call's linearization point, but three helpers re-sampled pending/running
state afterwards and upgraded an owner that completed during that gap to
`protocol_errors`. The larger fixtures expose this diagnostic-only race even
though their dirty work drains to idle.

The minimal correction removes those post-return error upgrades only in the
default-off synthetic irq-work kick, recovery dispatch, and notifier queue
helpers. No matrix, threshold, timed sample, lock, refcount, production helper,
or ordinary scheduler path changes. The corrected direct-child identity is
commit `82d91805f8e145d2403057f656e590e4bcae12f1`, tree
`44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f`, and two-file diff SHA-256
`a7cb42fe5fc6f346ba8ea009097fa15433050e79e3255d64467d7b8ad636aeb9`.
Strict checkpatch, focused arm64/x86_64 E4-on W=1 objects, and the corrected
source-only static gate pass.

Because every previous combined regression and closure binds the superseded
commit, fresh six-object/six-profile/216-case evidence and new independent
double closure are mandatory. Timing and x86_64 remain blocked until that
sequence completes.

## Corrected Source Closure and Arm64 Timing R5 Readiness

Fresh combined run
`20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5` passes the six
source objects and six preserved E3 profiles at 216/216 cases and receipts,
with zero compiler, clock-skew, or kernel diagnostics. Its combined, source,
configuration, regression, and boot-results SHA-256 values are respectively
`6a77daf3...77b3777`, `24be737d...418989`, `6c0be87f...a267a`,
`fd558602...69a00`, and `1749d60e...59c7f`.

Updated closure runner `dddc11a3...5280f8` additionally audits all three
coalesced-owner correction helpers. Two read-only closures cover exactly 270
artifacts/10,871,386 bytes and produce `313651a8...2c57c` plus
`10dd9320...d4a`, normalized after deleting only `run_id` to
`75369701...b449`. Exact-fixture and six mutation controls pass. Validation/
0268 therefore completes the reopened source prerequisite.

Timing runner `cd2f2103...27db` binds the corrected candidate and closures
without changing the 682-cell matrix, thresholds, paused-QMP placement,
diagnostic rules, or capacity gates. Config smoke r9 starts zero builds/boots;
forced-capacity r3 fails before build and seals `5000e8ef...bb39`; parser and
QMP positive/negative controls pass. The build machine reads back six vCPUs,
10,240 MiB, and `nproc=6`; only build concurrency follows `nproc`, while the
measurement remains two pinned guest vCPUs. Sparsebundle compaction preserves
all Git identities and leaves 52,127,908 KiB host plus 526,289,848 KiB
VM-internal free.

Only exact arm64 timing r5 is authorized. A clean complete result still needs
independent timing closure before any exact same-source x86_64 work; a valid
threshold rejection stops x86_64, and a harness failure authorizes only
root-cause work.

## Arm64 Timing R5 Host-Restart Rejection and R6 Readiness

Host reboot interrupted r5 after 166/682 rows and before all seven summaries.
Serial and job-log final mtime epoch `1784710956` precedes the new host boot
epoch `1784710983` by 27 seconds. No partial row is accepted. Recovery tool
`55ed64fb...916ed` seals `harness_failed/host_restart` result
`d7fb9ec3...268d3` and a 55-file read-only manifest
`ad49a9c1...7b70`.

Before deleting run-owned VM scratch, recovery preserves exact Image
`21b6ed89...e6fe`, object `e8b81482...7818`, and configuration
`2cbf3e91...f07b`. The 3.9 GiB build root, 1.8 GiB worktree, stale worktree
registration, and 64 MiB reserve are then retired. The existing sparsebundle,
primary Linux identity, and six-vCPU/10-GiB machine are restored exactly.

Validation/0269 authorizes only a new complete arm64 r6 bound to the r5
interruption result. It may not resume or combine r5 rows. All normal source,
closure, parser, QMP, capacity, identity, and cleanup preflights remain
mandatory.

## Arm64 Timing R6 Repair, R7 Source Closure, and Terminal Rejection

Timing r6 completed exact paused-QMP placement and QEMU exit zero but rejected
all 538 partial rows after recovery lost-handoff and offline-oracle KUnit
failures. Two failure closures normalize to
`1ed1c743...a3c3f`. Direct-child R7 moves the bounded continuation to ordinary
work self-requeue, adds an exact handoff-race case, and corrects the offline
control oracle.

Fresh combined R7 run
`20260723T-p5a-r4-e4-owner-oracle-correction-source-e3-regression-r7` passes
six source objects, six profiles, 216/216 cases and receipts, and zero
diagnostics. Two 272-artifact source closures normalize to
`f8e184c1...d4ba2`.

Timing r7 then completes all 682 cells and 6,820,000 paired samples with KUnit
7/0/0, QEMU exit zero, exact two-vCPU paused-QMP singleton placement, zero
compiler/kernel/clock diagnostics, and exact parser regeneration. Result
`edb07251...a0951` is nevertheless
`rejected_r4_local_quantum_measurement`: 362 cells have 692 fixed-gate
breaches. Family rejection counts are publication 184/288, picker/kick 3/144,
IRQ dispatch 4/9, recovery 105/144, notifier 48/48, current stop 0/24, and
offline 18/25.

Two independent timing closures produce `b5279add...297af` and
`75e734bc...a2719`, normalized to `8ebacd3c...84b5`. Validation/0272 therefore
terminates R4 and stops same-source x86_64 plus R4-E5. No threshold, matrix, or
claim boundary is relaxed.

## Claim Boundary

This accepted-for-timing replacement source and runner measure only virtual
synthetic protocol quanta. They do not prove
live scheduler correctness, CPU hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.
