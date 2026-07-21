# Validation 0265: SchedExecLease P5A-R4 E4 Arm64 Timing R2 QMP Rejection and R3 Readiness

Date: 2026-07-21

Status: arm64 timing r2 is a sealed harness failure, not threshold evidence.
The runner relied on QEMU debug thread names without enabling them, so no vCPU
thread was identified before the guest emitted its first row. Two independent
read-only closures preserve the exact failure. The corrected runner starts
QEMU paused, discovers vCPU TIDs through QMP, verifies distinct singleton
affinity, revalidates the mapping, and only then resumes the guest. Focused
negative tests, real-QEMU integration, config smoke, and forced cleanup pass.
Only fresh arm64 timing r3 is authorized; x86_64 remains blocked.

## Timing R2 Classification

```text
job:          p5a-r4-e4-arm64-timing-r2
run:          20260720T-p5a-r4-e4-arm64-timing-r2
started:      2026-07-20T06:12:10Z
finished:     2026-07-21T07:37:11Z
result:       171df609d8f8dc272a20f585cea3b419a0ae487c6a0feda1367e880afec12a22
status:       harness_failed
stage:        qemu_boot
reason:       measurement emitted rows before all QEMU vCPU threads were pinned
x86 allowed:  false
```

The exact arm64 Image and `exec_lease.o` build completed with zero compiler or
clock-skew diagnostics. Both were losslessly archived and restore-verified.
The guest reached `sched_exec_lease_r4_measure` and emitted one publication
row at guest time 5.264269 seconds. The harness then terminated QEMU. This row
has no measurement credit because host placement was not established first.

`vcpu-pinning.txt` contains only the QEMU PID and parent allowance `0-1`.
There is no `vcpu=` record and no false singleton-pin claim. The result records
`architecture_measurement_valid=false`, rejects x86_64, and confirms both
VM-internal build scratch and the disposable worktree were retired. VM trim
also exited zero.

## Root Cause

QEMU 8.2.2 leaves every Linux `/proc/<pid>/task/<tid>/comm` as the truncated
`qemu-system-aar` by default. The r2 runner searched only for `CPU */TCG`, but
did not pass QEMU's `debug-threads=on` option. Therefore the scan could never
identify a vCPU. It slept and retried while the unconstrained guest continued,
then correctly rejected the first measurement row.

A no-kernel stopped-QEMU probe reproduced four indistinguishable default
thread names. The same probe with
`-name guest=...,debug-threads=on` exposed `CPU 0/TCG` and `CPU 1/TCG`.
Thread names are retained only for human diagnostics in the corrected runner;
they are no longer the authority for identifying vCPU TIDs.

## Independent Failure Closure

The closure runner snapshots all 34 regular r2 artifacts, rejects symlinks and
non-regular objects, checks original-before/original-after/snapshot manifests,
and makes each snapshot read-only. It independently verifies:

- the exact result seal and harness-failure semantics;
- 33,365,585 bytes under manifest SHA-256
  `056949c807a88b48187c822e56144ab864453743cd2e01e303678444a1780efd`;
- runner, parser, warning classifier, plan, config, build, serial, and pinning
  hashes;
- zero compiler diagnostics, exact two-vCPU config, and one pre-termination
  result row;
- absence of QMP/paused startup in r2;
- lossless Image and object restoration; and
- complete build/worktree retirement with false measurement/runtime claims.

```text
r1 run:         20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r1
r1 result:      749777dbd6e9310538f76146650eca52d6c9d6c721645cb21c99cda196a0b705
r2 run:         20260721T-p5a-r4-e4-arm64-timing-r2-failure-closure-r2
r2 result:      83ec59df2275ab6d6b8c6a9fe2aed9ecb12156ae318b991a9fa1829d47b37e66
normalized:     9c079b47fae1b7ae45baa6cd7517a9b02af2d6b3f4a9780f180366932e3178ef
closure runner: 0610b76838bbd4eeb65625b490ac3bbb93331526b283b86d1969c6a71916881d
```

The normalized decisions are byte-identical after deleting only `run_id`.
Independent readback verifies both result and normalized seals and confirms
all 68 copied evidence inputs are read-only. A changed result and a symlinked
pinning record are both rejected.

## Corrected Paused-QMP Placement Protocol

The corrected runner no longer permits the guest to execute while placement
is being discovered:

1. Start two-vCPU TCG QEMU with `-S`, a run-owned Unix QMP socket, network
   disabled, and debug thread names enabled for diagnostics.
2. Require QMP `query-status` to report `prelaunch` or `paused`.
3. Use `query-cpus-fast` to obtain exactly indexes 0 and 1 with distinct,
   positive Linux TIDs. Reject missing, duplicate, malformed, or out-of-range
   entries.
4. Prove each TID exists below the active QEMU's `/proc/<pid>/task`, then pin
   vCPU 0 and vCPU 1 to two distinct allowed host CPUs and read back each
   singleton `Cpus_allowed_list`.
5. Reconnect to QMP immediately before resume, require the same paused mapping,
   re-read each thread's `Tgid` and singleton affinity from `/proc`, and reject
   any mapping or affinity drift.
6. Require zero `R4_E4_RESULT` rows while paused, issue QMP `cont`, and require
   `query-status=running` before starting the measurement timeout.

The QMP helper is hash-bound, copied into raw evidence, and verified unchanged
again before successful result sealing. A successful result must now include
`qmp_pause_before_affinity=true` and
`qmp_mapping_reverified_before_resume=true` in its placement contract.

## Focused Verification

```text
arm64 runner:    8b7ae0d18636f5027fd741527b0b5d1b8b5c5323fb62272c3a47cb5d17942fb2
QMP helper:      e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e
QMP test:        06c5f057cb4507b53b2b6cb6f55a3c35d150cd561cf282ac3681f41d17650876
config smoke:    20260721T-p5a-r4-e4-arm64-timing-config-smoke-r7
cleanup control: 20260721T-p5a-r4-e4-arm64-timing-cleanup-negative-r3
```

Host `bash -n` and VM ShellCheck pass. The helper self-test accepts the exact
two-vCPU mapping and rejects 15 missing, duplicate-index, duplicate-TID,
out-of-range, malformed, incomplete-affinity, reused-host-CPU, and unknown-line
fixtures. The real-QEMU integration test proves paused discovery, two distinct
singleton pins, duplicate mapping rejection, affinity tamper rejection, exact
mapping/affinity revalidation, and transition to `running`.

Config smoke r7 resolves the exact arm64 config with zero builds and guest
boots, snapshots the corrected runner/helper, runs the helper self-test, and
retires both scratch roots. The forced storage failure occurs after worktree
creation, seals `harness_failed/worktree`, snapshots the corrected inputs, and
again retires both roots.

## Arm64 Timing R3 Boundary

Only this exact run was authorized after exact clean/pushed preflight:

```text
job:     p5a-r4-e4-arm64-timing-r3
run:     20260721T-p5a-r4-e4-arm64-timing-r3
monitor: ./tools/long-job.sh watch p5a-r4-e4-arm64-timing-r3 30
```

The launcher must bind the corrected runner, QMP helper/test, parser suite,
warning classifier, both replacement-source closures, both r2 failure
closures, config smoke r7, cleanup control r3, pushed Git identities, running
VM, internal ext4, distinct CPU capacity, free-space floors, absent run-owned
paths, and no competing build/QEMU process before detach.

A clean r3 result may authorize only same-source x86_64 timing. A complete
fixed-threshold or diagnostic rejection stops x86_64. Any harness failure
requires another root-cause closure. Every complete result still requires an
independent read-only timing-evidence closure before measurement acceptance.

## Arm64 Timing R3 Operational Launch

The exact clean/pushed preflight passed twice: once independently with
`--preflight-only` and once immediately before detach. It revalidated both
source closures, both r2 failure closures, the runner/helper/test/parser hashes,
config smoke r7, cleanup control r3, root/capsched/Linux/patch identities, the
candidate's local/fork identity, two VM-allowed CPUs, internal ext4, storage
floors, absent run-owned paths, and no competing timing/build/QEMU process.

Job `p5a-r4-e4-arm64-timing-r3`, run
`20260721T-p5a-r4-e4-arm64-timing-r3`, detached at
`2026-07-21T08:07:59Z`. Independent status and result probe observed the
VM-internal Image build running with zero measurement rows, and the first
30-second watch display also observed continued build progress. Interrupting
only the watch left the detached runner active.

This is operational launch evidence, not a timing result. Completion must be
classified by the exact r3 probe and then independently closed before any
measurement acceptance or same-source x86_64 authorization.

## Claim Boundary

This record repairs only the timing harness's host-placement sequencing. It
does not change Linux source, sample order, matrix size, thresholds, parser,
warning classifier, or source/regression acceptance. It accepts no timing
result, live scheduler behavior, N-136 charge, bare-metal latency, performance,
cost, production protection, deployment, multi-node, multi-cluster, or
datacenter readiness.
