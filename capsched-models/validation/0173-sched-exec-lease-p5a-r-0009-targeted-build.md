# Validation 0173: SchedExecLease P5A-R 0009 Targeted Build

Date: 2026-07-04

Status: passed for targeted scheduler object build only. Linux patch `0009`
remains unaccepted.

## Scope

This validation checks that the concrete `0009` Linux draft builds the touched
scheduler objects for both CONFIG states:

```text
kernel/sched/fair.o
kernel/sched/core.o
```

It does not validate full `vmlinux`, boot compatibility, runtime denial, or
protection.

## Runner

```text
validation/run-sched-exec-lease-p5a-r-0009-targeted-build.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-0009-targeted-build/20260704T-p5ar-0009-targeted-build/
```

## Checks

Build inputs:

```text
linux_commit=7a402107fd63faf7063c2dea05e88e7f8a23f4bf
gelf_h_present=true
off_output=build/linux-l0-sched-exec-lease-off-p5a0-p1-0008-qemu-x86_64
on_output=build/linux-l0-sched-exec-lease-on-p5a0-p1-0008-qemu-x86_64
```

Build commands:

```text
make -C linux O=<off_output> -j$(nproc) kernel/sched/fair.o kernel/sched/core.o
make -C linux O=<on_output> -j$(nproc) kernel/sched/fair.o kernel/sched/core.o
```

Object evidence:

```text
off fair.o size=164608 sha256=00d68ab37b06b4f84cf303949600666df5fc3376c0df28120c067fd3994b8dea
off core.o size=364448 sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on fair.o size=166376 sha256=ef39d7414cf451770f093e1962d59cb766afecb06157a4f3b7942d1a9b5f512b
on core.o size=364448 sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

## Result

The targeted build blocker from validation/0172 is closed:

```text
missing_gelf_h=false
targeted_build_passed=true
config_off_sched_objects_build=true
config_on_sched_objects_build=true
```

## Non-Claims

This validation does not approve:

```text
accepting 0009
full vmlinux build compatibility
QEMU boot compatibility
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
object/layout overhead acceptance
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next acceptance step is full CONFIG off/on `vmlinux` build validation. It
should run under a durable systemd user runner because it can take longer than
is worth monitoring in chat.
