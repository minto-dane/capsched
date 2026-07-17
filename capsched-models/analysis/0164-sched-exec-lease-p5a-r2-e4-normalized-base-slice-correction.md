# Analysis 0164: SchedExecLease P5A-R2 E4 Normalized Base-Slice Correction

Date: 2026-07-14

Status: source correction defined after arm64 attempt 1 harness failure. No E4
measurement, full rebuild, latency, performance, or production claim exists.

## Failure

Arm64 run `20260714T-p5a-r2-e4-arm64` built and booted the exact first E4
Image, started the filtered KUnit suite, and failed at its first assertion
before emitting any `E4_RESULT` row. The source compared
`sysctl_sched_base_slice` directly with 700,000ns.

That comparison was semantically wrong. Linux stores the fixed baseline in
`normalized_sysctl_sched_base_slice` and derives the live value through
`update_sysctl()`. With the default `SCHED_TUNABLESCALING_LOG` policy and two
online CPUs, the factor is `1 + ilog2(2) = 2`; the runtime value is therefore
1,400,000ns. This is expected scheduler behavior, not rebuild evidence.

## Correction

The measurement must:

1. assert the normalized baseline is exactly 700,000ns;
2. record the live scaled value, scaling enum, and online CPU count separately;
3. retain 700,000ns as the fixed base-slice rejection basis;
4. retain additional p99 <=25,000ns and max <=50,000ns;
5. retain all 35 cells, 256 warm-up pairs, and 10,000 measured pairs per cell;
6. change no measured-interval instruction, fixture topology, E3 rebuild, or
   live scheduler path; and
7. reject unknown kernel command-line parameters as a harness failure.

Runtime scaling may not widen any threshold. The correction therefore repairs
measurement metadata and precondition semantics only; it cannot make the
algorithm easier to pass.

The QEMU command line also replaces the unrecognized `hardlockup_panic=0`
with `nmi_watchdog=nopanic,1` and prefixes the RCU module parameter as
`rcupdate.rcu_cpu_stall_suppress=0`. These changes restore the intended warning
evidence without changing source or thresholds.

## Source Identity

The corrected disposable E4 commit is amended so it remains a direct child of
E3 rather than stacking a second experimental commit:

```text
parent:          d1d5e78da8484c91eae70f22399c6901da680ea0
corrected commit:f6ad4e454778c52bcdaaecf684c148a3a8dae857
corrected tree:  265e6357627490e51084979382ef34b2cfcc0cb8
full diff SHA:   3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3
full delta:      362 additions, 0 deletions, exactly two files
correction diff: 22cb55c3a8a9841122820a467712c015ba761961676898160f941157fc3414ed
```

The correction-only diff is 10 additions and 4 deletions in `fair.c`. The
primary Linux branch, patch queue, E2 fields/probe, E3 helper/tests, Kconfig
boundary, and all live scheduler paths remain frozen.

## Classification

Attempt 1 is `harness_failed`: zero measurement rows means it supplies neither
a pass nor a valid `rejected_full_locked_rebuild` result. A corrected source
gate must pass before arm64 rerun. x86_64 remains blocked until a valid arm64
result is recorded.
