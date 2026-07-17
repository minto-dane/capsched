# Validation 0235: SchedExecLease P5A-R3 E4 Arm64 Bucket Measurement Rejection

Date: 2026-07-16

Status: complete valid negative evidence. The R3 bucket-local targeted-
projection design is rejected by the fixed arm64 virtual gates. x86_64 and E5
are stopped.

## Canonical result

Run `20260716T-p5a-r3-e4-arm64-measurement-r1` built and booted the exact
candidate, emitted every required row, and cleanly powered off QEMU.

```text
source commit:             f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
source tree:               61541cb0c8aedef941e534c73effdea1f6b3d938
source parent:             be9339363a99fb31a5b7d03f3d70430d64a45593
source-gate SHA-256:        8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c
E3-regression SHA-256:      3d02a2b6c52a856e6bde5417665bfc41e1fa547c774f9274f1f85d53167b5707
measurement rows:          42/42
warm-up pairs per cell:    256
measured pairs per cell:   10,000
QEMU exit code:            0
KUnit cases:               3/3 passed
required skips/failures:   0/0
gated warning count:       0
result status:             rejected_r3_bucket_measurement
```

Result:
`build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement/20260716T-p5a-r3-e4-arm64-measurement-r1/result.json`.

Result SHA-256:
`edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b`.

Important evidence hashes:

```text
Image source:       59813a8f2b9421ccea631966d9c16696876f0f73c1f337ff6771cf4904e15847
Image archive:      b5d63b415dd40025793c20ddb55dec6ab1109cdadc75b72ab2360e72f639c9cb
exec_lease.o source:4a8a3fb99ecb9167cbb48e93406ecca03f08c374709094ec30a376823fb49636
object archive:     9e69fc603f5f2ad3af118d3df1804ef5b571d10c1f2b33a14b0ffe3bdbec0cff
serial:             0a92b0c19aab6c8507864050594409e92863aa717f1fe2049129566684b7c35b
normalized KTAP:    08ddddec8c34449a060de9453650a3a5e436d9c4110767ff1b393b51cdabacaa
measurement table:  9fe89e77b2c6b9008fe7a93bf8e83d1638de19cc4b60dd7fa2a8e37d3223acc6
configuration:      9015e7cdd2ccc97e5fba3380c85002a6105884c6cea40d7d9be238aff7aa65f5
governor source:    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
governor availability: 5f20489aa6a97eeb0144f9755e8f22d204c9fb958ce1d4a024754c4f46a71df1
```

Both compressed binaries passed zstd archive tests, and decompression hashes
matched the recorded source hashes. The internal ext4-compatible build output
was pruned after QEMU.

## Post-QEMU parser recovery

The original managed job exited after QEMU because the host AWK parser compared
numeric strings produced by `substr()` without explicit numeric coercion. The
first valid row therefore exited monotonicity check 8; the AWK `END` block then
masked that diagnostic as exit 17. No kernel, configuration, Image, object,
serial, KTAP source, or measurement row failed.

The runner now:

- coerces every statistic to a number before monotonic and threshold checks;
- preserves the first parser failure code;
- supports a postprocess-only recovery that revalidates exact source and
  prerequisite hashes, build/config records, compiler warnings, QEMU exit,
  object symbols, compressed artifacts, decompression hashes, KUnit, all cells,
  summaries, warnings, and fixed gates before producing a result; and
- records build/QEMU reuse and the unmodified-raw-input boundary in the result.

The preserved frequency/governor source file was empty because Apple Container
exposed no cpufreq files. Recovery left it unchanged and added an explicit
availability record: availability recorded, governor unavailable, source
record empty. QEMU TCG does not use that guest governor as a bare-metal
frequency claim.

Two complete postprocess-only executions over the same evidence produced the
same result SHA-256 shown above. This is recovery of a completed measurement,
not a second or merged measurement attempt.

After terminal classification, the clean disposable E2/E3/E4 worktrees were
removed while their commits and local/remote-tracking branches were retained.
Postprocess-only mode then revalidated the E4 commit, tree, and parent directly
from the parent Linux repository and reproduced the same result SHA-256.
Normal measurement launch continues to require an exact clean E4 worktree.

## Fixed-gate outcome

```text
family          rejected cells   threshold breaches
one_projection  12/32            16
hotplug          3/5              4
fanout            4/5              6
total            19/42            26
```

The 26 conditions comprise 15 additional-maximum breaches, five additional
samples reaching the 700,000ns normalized base-slice boundary, four fanout
treatment-p99 breaches, and two fanout treatment-maximum breaches.

One-projection additional p99 and p999 maxima were 784ns and 13,696ns, inside
their 5,000ns and 25,000ns gates, but 12 cells exceeded the 50,000ns maximum
gate and four reached the base-slice boundary. Hotplug rejected three cells;
its worst additional maximum was 1,277,904ns.

Fanout passed only at one active rq. It first rejected at two active rqs and
scaled to 494,241,840ns treatment p99 and 1,660,608,240ns treatment maximum at
64 active rqs, against fixed 10,000,000ns and 100,000,000ns limits.

All 42 source-reported gates agreed with independent recomputation. The three
source summaries reported 32/12, 5/3, and 5/4 rows/rejections with zero harness
errors and exactly matched derived summaries.

## Decision boundary

Arm64 has already rejected R3 against the architecture-independent fixed
virtual gates. The plan therefore forbids an x86_64 continuation and E5. The
disposable E2/E3/E4 line is not promoted.

Any successor needs a separate design gate. In particular, publication cannot
wait for synchronous completion of all targeted-rq work as an authority
condition. A successor may preserve an O(1) generation mismatch fence and make
fanout an asynchronous availability accelerator only if it separately proves
bounded recovery, no stale trust, hotplug/retirement settlement, and no
unbounded picker or rq-lock work.

This TCG result is valid negative design evidence under the fixed plan. It is
not bare-metal latency or general performance evidence. Primary Linux, the
patch queue, live scheduler behavior, runtime denial, monitor enforcement,
cross-path coverage, production protection, cost, deployment, and datacenter
readiness remain unapproved.
