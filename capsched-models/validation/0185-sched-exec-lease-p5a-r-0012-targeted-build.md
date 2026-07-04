# Validation 0185: SchedExecLease P5A-R 0012 Targeted Build

Date: 2026-07-04

Status: passed for strict checkpatch and targeted CONFIG off/on scheduler
object build. QEMU negative runtime validation remains pending.

## Scope

Validate corrective draft `0012`, which adds forced pickable CFS progress after
validation/0184 showed that the `0011` eligible-only fallback was insufficient.

```text
linux_commit=bd71af5daeae808ac948cbd12af2663151936f22
linux_subject=sched/fair: Force exec lease pickable CFS progress
patch_queue_file=linux-patches/patches/capsched-linux-l0/0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch
patch_queue_sha256=f306bbfb16265df5a02632f8b2551b5f3e5a8420180ea13d6a59d4291fd2fa35
series_sha256=98cb3e54768b918be459498bc0d9731aaf8234787a956686d8edad83c6fbb240
```

## Checks

Patch style:

```text
linux/scripts/checkpatch.pl --strict --no-tree <0012 patch>
result=clean
errors=0
warnings=0
```

Targeted build:

```text
make -C linux O=<on-build-dir> kernel/sched/fair.o kernel/sched/core.o
make -C linux O=<off-build-dir> kernel/sched/fair.o kernel/sched/core.o
result=passed
```

Output directory:

```text
build/source-check/sched-exec-lease-p5a-r-0012-targeted-build/20260704T-p5ar-0012-targeted-build
```

Hashes:

```text
on_log_sha256=29b110ab331c5e5fe038dcafe6b9243e5a1cbeb8ba728a3bcd7cb483cd0f6df4
off_log_sha256=e083d8f8c6eb3277d848b169abc3dc7a6df64dfae3b39633dfd6b5d1ec8f65b7
off_fair_o_sha256=9691fdaacac021a719e1ec88a79029490394c733e5f066a23075c3102193f844
off_core_o_sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on_fair_o_sha256=562bd19ef2f06c617b044234ab51da5dd05a3c9e90623f968dbf5b01c36fe185
on_core_o_sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

Sizes:

```text
off_fair_o_size=164608
off_core_o_size=364448
on_fair_o_size=167976
on_core_o_size=364448
```

## Verdict

The corrective source compiles in the checked scheduler objects for both
CONFIG states and the patch is style-clean.

This does not prove that runtime denial is correct. The required next runtime
check is the QEMU negative workload against `0012`.

## Non-Claims

This validation does not prove:

```text
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
production fairness correctness
capability semantics
monitor enforcement
protection
cost efficiency
deployment readiness
datacenter readiness
```
