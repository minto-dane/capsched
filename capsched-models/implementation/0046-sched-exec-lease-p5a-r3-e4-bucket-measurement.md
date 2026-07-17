# Implementation 0046: SchedExecLease P5A-R3 E4 Bucket Measurement

Date: 2026-07-16

Status: complete as valid negative evidence. The exact arm64 measurement
rejects R3 in 19/42 cells with 26 fixed-gate breaches. x86_64, E5, promotion,
and every production or performance claim remain stopped.

## Disposable identity

```text
historical worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r3-e4-bucket-measurement
branch:   codex/p5a-r3-e4-bucket-measurement
parent:   be9339363a99fb31a5b7d03f3d70430d64a45593
commit:   f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
tree:     61541cb0c8aedef941e534c73effdea1f6b3d938
diff sha: ec369f6b40b427f1297b9ef5061d91bebb2e26c25d9f145a54b995b4b4a73205
```

The commit is the direct child of the corrected E3 diagnostic candidate. It
adds 1,006 lines and deletes 10 in exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`. Strict checkpatch is 0/0/0. Primary Linux and the
patch queue remain unchanged.

After terminal rejection, the clean E2, E3, and E4 disposable worktrees were
removed to reclaim 5.1GB. Their commits, local branches, and `fork/codex/...`
tracking branches remain intact in the parent Linux repository. Postprocess-
only validation now accepts the fixed E4 commit object from that parent repo;
normal measurement launch still requires the exact clean E4 worktree.

## Measurement boundary

`CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST` is default off, depends on
the E3 KUnit option, remains in the same translation unit, and registers only
suite `sched_exec_lease_bucket_measure`. The suite has three cases and emits
exactly 42 machine-readable rows:

```text
one projection:  4 occupancies x 4 inner counts x 2 generation outcomes = 32
hotplug drain:   occupancies 0, 1, 8, 32, 64                         = 5
targeted fanout: active-rq counts 1, 2, 8, 32, 64                   = 5
```

Every cell uses 256 warm-up pairs and 10,000 measured pairs. The
one-projection and hotplug intervals use a real synthetic `struct rq` lock and
the same extracted transition helpers exercised by E3. Fanout snapshots the
private active-rq index while membership-locked, owns references before
unlock, and queues only after unlock. Storage, sorting, printing, and oracle
checks stay outside the measured interval.

The fixed rejection limits remain 5/25/50 microseconds for one-projection
additional p99/p999/max, 25/50 microseconds for hotplug additional p99/max,
10/100 milliseconds for fanout absolute p99/max, and 700 microseconds as the
normalized base-slice ceiling. A threshold breach is valid negative evidence;
missing or malformed evidence is a harness failure.

## Gate closure

Validation/0229 corrected source-gate run
`20260716T-p5a-r3-e4-source-gate-r2` passed exact identity, direct-child and
two-file scope, strict checkpatch, arm64/x86_64 E3-parent/E4-off/E4-on `W=1`
objects, 43 frozen E2 values, and disabled-artifact absence. Its result
SHA-256 is
`8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c`.

Validation/0233 run `20260716T-p5a-r3-e4-e3-regression-r2` then built and
booted the exact E4 source with measurement explicitly disabled. Arm64 and
x86_64 standard debug, arm64 generic KASAN, and x86_64 KCSAN each passed the
unchanged E3 suite at 20/20 with zero failures, skips, QEMU timeouts, or gated
diagnostic reports. Its result SHA-256 is
`3d02a2b6c52a856e6bde5417665bfc41e1fa547c774f9274f1f85d53167b5707`.

The corrected run used fresh Apple Container internal ext4-compatible build
storage. It preserved the exact boot image and `exec_lease.o` for each boot as
eight lossless zstd archives, independently verified archive and restored
SHA-256 values, and pruned all four successful scratch outputs.

## Arm64 final measurement

Run `20260716T-p5a-r3-e4-arm64-measurement-r1` completed the exact 64-vCPU
arm64 TCG experiment. QEMU exited zero, all three KUnit cases passed, all 42
unique cells emitted 10,000 paired samples, the three source summaries had
zero harness errors, independent gate recomputation agreed with every row, and
gated warning count was zero.

Result:
`build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement/20260716T-p5a-r3-e4-arm64-measurement-r1/result.json`.

Result SHA-256:
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`.

```text
family          rejected cells   threshold breaches
one_projection  12/32            16
hotplug          3/5              4
fanout            4/5              6
total            19/42            26
```

The 26 conditions are 15 additional-maximum breaches, five additional samples
at or beyond the 700,000ns normalized base-slice boundary, four fanout p99
breaches, and two fanout maximum breaches. Fanout passed only at one active rq;
at 64 active rqs its treatment p99 was 494,241,840ns and maximum was
1,660,608,240ns against 10,000,000ns and 100,000,000ns limits.

Validation/0235 therefore classifies the complete result as
`rejected_r3_bucket_measurement`. Arm64 already falsifies the design against
the fixed architecture-independent virtual gates, so x86_64 is not launched,
E5 remains blocked, and the disposable E2/E3/E4 line is not promoted.

## Post-QEMU parser repair

The original managed job completed build and QEMU but stopped during host
postprocessing. AWK dictionary values extracted with `substr()` were compared
lexically instead of numerically; the first valid row failed monotonic check 8,
then the `END` block masked it as exit 17.

The runner now coerces statistics before comparison, preserves the first parser
failure code, and has a postprocess-only recovery mode. Recovery revalidates
source and prerequisite hashes, config and build evidence, object records,
QEMU exit, zstd archives and restored hashes, KUnit, rows, summaries, warnings,
and gates without rebuilding or rerunning QEMU. It records build/QEMU reuse and
an unmodified raw-input boundary. Two recoveries over the retained evidence
produced the identical result SHA-256 above.

A further recovery after removing the disposable worktree verified the exact
commit/tree/parent from the parent Linux repository and reproduced the same
result SHA-256.

Apple Container exposed no cpufreq governor/frequency files, so the original
availability source file was empty. Recovery preserves that fact and emits a
separate explicit unavailable record. Future full runs emit the unavailable
marker directly instead of leaving an empty file.

## Non-claims

The completed gate rejects R3; it does not accept E4, authorize E5, attach the
candidate to the live scheduler, change primary Linux or the patch queue, or
establish runtime denial, cross-path coverage, monitor enforcement, production
protection, bare-metal latency, performance, cost, deployment, or datacenter
readiness. Any asynchronous-settlement successor requires a separate design
gate and may not weaken or relabel these fixed results.
