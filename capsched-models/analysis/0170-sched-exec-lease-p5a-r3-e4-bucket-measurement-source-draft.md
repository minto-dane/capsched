# Analysis 0170: SchedExecLease P5A-R3 E4 Bucket Measurement Source Draft

Date: 2026-07-16

Status: historical exact disposable source draft. The source and exact-source
regression gates later passed, but validation/0235 and analysis/0171 record the
terminal arm64 E4 rejection. No runtime or production claim is accepted.

## Exact Candidate

```text
parent:      be9339363a99fb31a5b7d03f3d70430d64a45593
commit:      f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
tree:        61541cb0c8aedef941e534c73effdea1f6b3d938
diff sha256: ec369f6b40b427f1297b9ef5061d91bebb2e26c25d9f145a54b995b4b4a73205
insertions:  1006
deletions:   10
files:       init/Kconfig
             kernel/sched/exec_lease.c
```

The candidate is a direct child of the corrected E3 diagnostic commit. It is
published on user-owned branch `codex/p5a-r3-e4-bucket-measurement`; primary
Linux and the patch series are unchanged.

## Source Shape

The default-off `CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST` option
depends on the E3 KUnit option and remains in the same translation unit. It
registers only suite `sched_exec_lease_bucket_measure` with three cases:

```text
one projection: 4 occupancies x 4 inner counts x 2 generation outcomes
hotplug drain:  occupancies 0, 1, 8, 32, 64
targeted fanout: active-rq counts 1, 2, 8, 32, 64
```

Every cell fixes 256 warmup pairs and 10,000 recorded pairs. Arrays and
fixtures are allocated before timing. The one-projection and hotplug intervals
use a real synthetic `struct rq` lock and the same extracted transition helpers
as E3. Fanout snapshots the private active-rq mask under the membership lock,
owns references before unlock, and queues only after unlock on a dedicated
unbound workqueue.

The candidate records threshold breaches as valid rejection rows. Harness,
clock, ownership, or structural defects still fail KUnit. It does not register
with a live runqueue, task, cgroup, picker, migration, or CPU-hotplug seam.

## Pre-Gate Checks

The complete commit diff passes strict checkpatch with zero errors, warnings,
or checks. Targeted E4-enabled `kernel/sched/exec_lease.o` builds passed with
`W=1` on arm64 and x86_64. The x86_64 smoke caught and removed a nonportable
assignment to `cpumask_var_t`, which is an array when off-stack cpumasks are
disabled.

These checks do not replace the independent gate. Validation/0229 must rebuild
fresh E3-parent, E4-disabled, and E4-enabled objects for both architectures,
prove disabled artifact absence and frozen manifests, then authorize only an
E3 regression diagnostic. Because the source draft extracted shared E3
helpers, measurement remains blocked until that unchanged 20-case suite passes
again on the exact E4 source.

## Non-Claims

The draft does not prove E3 regression correctness, E4 latency, bare-metal
bounds, performance, cost, fairness, runtime denial, monitor enforcement,
cross-path coverage, production protection, deployment readiness, or
datacenter readiness.

## Terminal outcome

Exact arm64 run `20260716T-p5a-r3-e4-arm64-measurement-r1` completed all 42
cells but rejected 19 with 26 fixed-gate breaches. Result SHA-256 is
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`.
See analysis/0171 and validation/0235. The disposable source is not promoted;
x86_64 and E5 are stopped.
