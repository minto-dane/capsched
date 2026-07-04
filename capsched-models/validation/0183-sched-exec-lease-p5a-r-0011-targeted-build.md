# Validation 0183: SchedExecLease P5A-R 0011 Targeted Build

Date: 2026-07-04

Status: passed for strict checkpatch and targeted CONFIG off/on scheduler
object build. QEMU negative runtime validation remains pending.

## Scope

Validate the corrective draft `0011` patch after validations/0181 and 0182
exposed a CFS deny-and-repick forward-progress bug.

```text
linux_commit=38340eceafa88119ba3e0bcdc10f309bfff6462b
linux_subject=sched/fair: Fix exec lease denied CFS repick progress
patch_queue_file=linux-patches/patches/capsched-linux-l0/0011-sched-fair-Fix-exec-lease-denied-CFS-repick-progress.patch
patch_queue_sha256=a2e93e499321e85e4c886ed2e3c7436fe1c1b59e1faa439e2ffa0e1cdd0eafd5
series_sha256=b1589e42886b374af8f1288f6e2608f4a1341070b07e0704c73745ee6b0b503a
```

## Checks

Patch style:

```text
linux/scripts/checkpatch.pl --strict --no-tree <0011 patch>
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
build/source-check/sched-exec-lease-p5a-r-0011-targeted-build/20260704T-p5ar-0011-targeted-build
```

Hashes:

```text
on_log_sha256=ded0d036e12db19848e015655dd5b3254a1eb890f9633edfdebf792eece0f781
off_log_sha256=bc1f7cd210e3aeb24c8a5a831b40cd388a96c81dec6720d3b63c6237d9fbbfe6
off_fair_o_sha256=80b826bcc394177419dc9a2d2c19a4074957d5aa02e1ca19022c47681dc6a9cb
off_core_o_sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on_fair_o_sha256=ee5d2d5b5655368731884826d6b21ab312c96864c384a33f3d94551802b79961
on_core_o_sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

Sizes:

```text
off_fair_o_size=164608
off_core_o_size=364448
on_fair_o_size=167416
on_core_o_size=364448
```

## Verdict

The corrective source compiles in the checked scheduler objects for both
CONFIG states and the patch is style-clean.

This does not prove that the runtime denial path is correct. The required next
runtime check is the QEMU negative workload against `0011`.

## Non-Claims

This validation does not prove:

```text
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
capability semantics
monitor enforcement
protection
cost efficiency
deployment readiness
datacenter readiness
```
