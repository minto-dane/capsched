# Validation 0233: SchedExecLease P5A-R3 E4 Exact-Source E3 Regression

Date: 2026-07-16

Status: passed. The exact E4 source preserves the complete E3 diagnostic
contract while E4 measurement is disabled. The controlled E4 measurement may
now start; E4 itself remains unaccepted.

## Authoritative result

Detached job `p5a-r3-e4-e3-regression-r2`, run
`20260716T-p5a-r3-e4-e3-regression-r2`, produced:

```text
build/source-check/
  sched-exec-lease-p5a-r3-e4-e3-regression-diagnostic/
    20260716T-p5a-r3-e4-e3-regression-r2/result.json
```

The independently recomputed result SHA-256 matches `result.sha256`:

```text
3d02a2b6c52a856e6bde5417665bfc41e1fa547c774f9274f1f85d53167b5707
```

The result binds exact E4 candidate
`f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1`, tree
`61541cb0c8aedef941e534c73effdea1f6b3d938`, direct E3 parent
`be9339363a99fb31a5b7d03f3d70430d64a45593`, primary commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, and source-gate result SHA-256
`8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c`.

## Four-boot regression

Every fresh image explicitly set
`CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST` off, retained the E3 suite,
and booted with the exact `sched_exec_lease_bucket` filter:

```text
arm64 standard debug:   20 pass, 0 fail, 0 skip, QEMU exit 0
x86_64 standard debug:  20 pass, 0 fail, 0 skip, QEMU exit 0
arm64 generic KASAN:    20 pass, 0 fail, 0 skip, QEMU exit 0
x86_64 strict KCSAN:    20 pass, 0 fail, 0 skip, QEMU exit 0
aggregate:              0 gated diagnostic reports, 0 final clock-skew warnings
```

The 20 names in every normalized KTAP log exactly match the source-derived
manifest. Standard and sanitizer configs retain `PROVE_LOCKING`,
`DEBUG_OBJECTS_WORK`, and `PROVE_RCU`; the sanitizer boots additionally prove
generic KASAN and strict KCSAN respectively. Compiler, config, object, image,
QEMU command/version, full serial, normalized KTAP, and per-boot SHA-256
manifests are retained.

The x86_64 KCSAN guest emitted the known QEMU/TCG clocksource watchdog message
`Watchdog remote CPU 1 read timed out` during boot. It is not a runner or KUnit
timeout: QEMU exited zero, KCSAN self-tests passed, the complete E3 suite
passed, and none of the fixed sanitizer/lockdep/RCU/workqueue/BUG/WARNING/
lockup rejection patterns fired. The full serial is retained rather than
silently removed.

## Storage integrity and bounded scratch

Attempt 1 in validation/0232 proved shared APFS/virtiofs build output unsafe
under critical host-capacity pressure. The corrected run required fresh build
roots under `/var/tmp/linux-cap-builds/` on the Apple Container machine's
internal ext4-compatible filesystem and rejected shared-host build output.

After each successful boot the exact boot image and
`kernel/sched/exec_lease.o` were compressed losslessly with zstd level 9. The
final evidence contains four manifests and eight archives. Independent audit:

```text
zstd integrity tests:                    8/8 pass
archive SHA-256 vs manifest:             8/8 match
decompressed SHA-256 vs source manifest: 8/8 match
successful build outputs pruned:         4/4
remaining internal scratch:              directory skeleton only
```

This preserves the exact tested binaries while preventing four complete
kernel trees from accumulating. The failed attempt-1 corruption evidence is
retained separately and was not merged into this pass.

## Authorization boundary

This result sets `e3_regression_diagnostic_passed=true` and
`e4_measurement_may_start=true`. It authorizes only the immutable 42-cell,
10,000-pair-per-cell virtual E4 measurement against this exact source.

It does not set `e4_measurement_accepted`, authorize E5, attach buckets to the
live scheduler, change primary Linux or the patch queue, or establish runtime
denial, monitor enforcement, cross-path coverage, production protection,
bare-metal latency, performance, cost, deployment, or datacenter readiness.
