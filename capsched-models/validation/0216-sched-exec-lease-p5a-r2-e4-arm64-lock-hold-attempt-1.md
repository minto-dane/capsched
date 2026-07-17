# Validation 0216: SchedExecLease P5A-R2 E4 Arm64 Lock-Hold Attempt 1

Date: 2026-07-14

Status: harness failed before measurement. This is not threshold evidence and
does not accept or reject the full locked rebuild.

## Result

Run `20260714T-p5a-r2-e4-arm64` completed the full instrumented arm64 Image
build and booted under Apple Container/QEMU. The irqsoff tracer started and the
filtered `sched_exec_lease_rebuild_measure` KUnit suite began. Its only case
failed at `kernel/sched/fair.c:17066` before `E4_META` or any of the 35 required
`E4_RESULT` rows were emitted.

The first source asserted the runtime-scaled `sysctl_sched_base_slice` was
700,000ns. In the two-CPU guest, default logarithmic scheduler scaling makes
that runtime value 1,400,000ns; 700,000ns is the normalized baseline. Analysis
0164 defines the correction.

```text
source commit:       dc3618e2bc56d3ede9b8d1378099c7b9ad15e08f
source tree:         b8a7023993560bcc40077a5db25288c3fdf4765a
result rows:         0/35
KUnit cases:         0 passed, 1 failed
classification:      harness_failed
Image SHA-256:        9c56544c4ab873b85371b6d318badbaa1ee9925d00257919916712abccf7d370
config SHA-256:       8597202b53e7eeb3647dd94c965f4a3942ecc1252a776751460d45cf9cb6b303
serial SHA-256:       eb7549deb9beb60e9f7220f6868fb1336e2f3a0ff13f9c9fe6a7be865f6779e3
normalized KTAP SHA: 3377505826cea98ef248ddd3216c4d759ba81b0d8463484b3c1e8ec446217833
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/20260714T-p5a-r2-e4-arm64/result.json`.

Result SHA-256:
`12370a90745e94edd56a50ecf378c2bd7397d0dfd50805d579309b51bed4ee97`.

## Additional Harness Defect

Serial output also identified two unrecognized command-line spellings:
`hardlockup_panic=0` and `rcu_cpu_stall_suppress=0`. The corrected runner uses
`nmi_watchdog=nopanic,1` and `rcupdate.rcu_cpu_stall_suppress=0` and rejects any
future unknown kernel parameter.

## Boundary

No matrix cell ran, so this attempt cannot be used for latency, performance,
architecture, or design-rejection evidence. Arm64 relaunch requires the exact
corrected source to pass validation/0217. x86_64, E4 acceptance, production
layout, runtime behavior, protection, cost, deployment, and datacenter claims
remain false.
