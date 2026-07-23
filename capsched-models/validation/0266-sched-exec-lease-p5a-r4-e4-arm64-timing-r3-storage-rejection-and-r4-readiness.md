# Validation 0266: SchedExecLease P5A-R4 E4 Arm64 Timing R3 Storage Rejection and R4 Readiness

Date: 2026-07-21

Status: arm64 timing r3 is a sealed host-storage harness failure, not timing
evidence. Exact QMP placement succeeded and the guest emitted 399 of 682
result rows, but the shared-host progress write reached `ENOSPC` before the
matrix completed. Two independent read-only closures reproduce the failure and
give every partial row zero threshold or architecture credit. The runner now
maintains a failure-seal reserve and checks shared-host capacity at every
progress boundary. Config smoke and a forced-capacity negative control pass.
Only a fresh arm64 timing r4 is authorized; x86_64 remains blocked.

## Timing R3 Classification

```text
job:             p5a-r4-e4-arm64-timing-r3
run:             20260721T-p5a-r4-e4-arm64-timing-r3
started:         2026-07-21T08:07:59Z
finished:        2026-07-21T11:48:09Z
result:          a35076dc95800d34c39bf3cc38f6e6a7c429aac69a8c1bb88278b48f4669a689
status/stage:    harness_failed/qemu_boot
sealed reason:   runner exited unexpectedly with code 1
exact root cause: host progress record write returned ENOSPC
x86 allowed:     false
```

The Image build completed with zero compiler diagnostics. QEMU started paused,
QMP mapped vCPU indexes 0 and 1 to TIDs 578597 and 578598 under QEMU PID
578593, and each TID was read back with singleton affinity on distinct host
CPUs 0 and 1. The mapping, Tgid ownership, and affinity were revalidated before
resume; zero rows existed before `cont`, and QMP then reported `running`.

The last durable progress record says 397/682. The immutable serial log
contains 399 `R4_E4_RESULT` rows and one summary; the publication family
reported 288 rows and 240 rejected cells. The matrix is incomplete, so none of
those values can satisfy a threshold, architecture, performance, or x86_64
gate. QEMU was terminated by the harness. Build and worktree scratch were
retired, and the exact Image and `exec_lease.o` archives remain losslessly
restorable.

## Host-Storage Root Cause and Recovery

The detached job log contains exactly one `No space left on device`, at the
progress-file write. The wrapper subsequently completed `fstrim` with exit
zero and reclaimed 340,478,111,744 bytes (317.1 GiB) on `/dev/vdb`. This
establishes the failure as shared-host exhaustion caused by untrimmed thin-VM
blocks, not a kernel, QMP, parser, or threshold result.

After host cleanup, the exact shared workspace has more than the 32 GiB r4
launch floor and VM-internal `/dev/vdb` has about 502 GiB free. The r4 launcher
must trim before preflight, measure both filesystems again, and refuse detach
unless the shared-host and VM-internal floors still hold.

## Independent Read-Only Failure Closure

The closure runner snapshots the 38 timing artifacts and five selected job
control records with before/after race checks, rejects symlinks and non-regular
objects, and makes all copied inputs read-only. It verifies the exact result,
source and job manifests, ENOSPC cardinality, partial-row counts, QMP placement,
archive restoration, trim recovery, and scratch retirement.

```text
timing artifacts: 38 files / 33,701,110 bytes
timing manifest:  8cbb4b23f48d715bd8a6ae617accf2af52cc1505611588c76411900a6dbc1521
job records:      5 files / 26,396 bytes
job manifest:     f943abaf9518840eb427ed0c6b1d002d6c10f765aff537c77156698d6383c1f1
closure runner:   c425c924ef0f61b46ead7797f61f1ec14ee933825f31d960cc837ebe27cc1578
r1 result:        e7d2bb95d9f5899fdbf50a4962d8f2175d879218ccc85135766ef8b9c430700c
r2 result:        b1f44a63b233182f401f9cc65b5e1176c2874b4915d22d89104e0de556d72b03
normalized:       da37226ef0bc0bb6587ce1b234cbdacb09ad133e27986473bc2e7bca5182a624
```

The normalized results are byte-identical after deleting only `run_id`.
Independent readback confirms the snapshots remain read-only and the original
R3 result still has its exact seal. Test mode accepts an exact copied fixture,
rejects a changed job log, and rejects a symlinked pinning record.

## Storage-Hardened Runner

Runner SHA-256
`2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69`
adds two fail-closed mechanisms without changing Linux source, the 682-cell
matrix, sample order, parser, QMP protocol, diagnostics, or thresholds:

- every progress update requires at least 8,388,608 KiB on shared-host storage;
- a 64 MiB fsync'd reserve is created before work, then released before any
  failure or successful final seal so the result remains writable near full
  capacity; and
- capacity-read and progress-write failures retain an exact failure reason.

Host `bash -n` and VM ShellCheck pass. Config smoke
`20260721T-p5a-r4-e4-arm64-timing-config-smoke-r8` snapshots this exact runner
and QMP helper, resolves the exact two-vCPU config with zero builds and boots,
retires both scratch roots, and leaves no reserve.

Forced-capacity control
`20260721T-p5a-r4-e4-host-capacity-negative-r2` raises the floor above all
possible capacity. It fails before build at `prerequisite_closure`, records the
exact observed availability, seals result SHA-256
`457fb3a7a5f00c0ea40b53af78d09d9f95021678b7003fbd02ef061ca2043c4c`,
releases the reserve, and retires both scratch roots. This proves that low
shared-host space is detected while enough reserved space remains to classify
the run.

## Arm64 Timing R4 Boundary

Only a fresh r4 may run after exact clean/pushed preflight. The launcher must
bind the storage-hardened runner, QMP helper/test, parser suite, warning
classifier, both replacement-source closures, both r2 QMP-failure closures,
both r3 storage-failure closures, config smoke r8, capacity-negative r2, exact
Git identities, running VM, two distinct allowed CPUs, internal ext4, absent
run-owned paths, and no competing build or QEMU process. It must perform
preflight VM trim and require at least 33,554,432 KiB shared-host free plus
16,777,216 KiB VM-internal free before detach.

A complete clean arm64 result may authorize only same-source x86_64 timing. A
complete valid threshold rejection stops x86_64. Any incomplete result or
harness failure requires another root-cause closure. Every complete result
still requires an independent read-only timing-evidence closure before
measurement acceptance.

## Arm64 Timing R4 Operational Launch

Standalone and detach-time preflight both passed the exact pushed Git,
source-closure, r2-failure-closure, r3-storage-closure, runner, QMP, parser,
config-smoke, capacity-negative, process, CPU, storage, and scratch-path gates.
Preflight trim completed successfully. The immediate detached wrapper trim
reclaimed another 975,572,992 bytes, then recorded 53,959,464 KiB shared-host
free and 526,306,264 KiB VM-internal free, above the 32 GiB and 16 GiB floors.

Job `p5a-r4-e4-arm64-timing-r4`, run
`20260721T-p5a-r4-e4-arm64-timing-r4`, detached at
`2026-07-21T13:03:24Z`. Independent status and result probe observed the exact
VM-internal Image build with zero measurement rows. The first 30-second watch
advanced from 13%/550 compiler-link steps to 15%/850 steps. Interrupting only
the watch left the detached runner active, and a subsequent probe observed
17%/1,050 steps.

This is launch evidence, not a timing result. Monitor with
`./tools/long-job.sh watch p5a-r4-e4-arm64-timing-r4 30`; completion must be
classified by the exact r4 probe and independently closed before any timing or
x86_64 decision.

## Claim Boundary

This record closes only an operational storage failure and hardens evidence
sealing. It accepts no timing threshold, architecture result, live scheduler
behavior, N-136 charge, bare-metal latency, performance, cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness.
