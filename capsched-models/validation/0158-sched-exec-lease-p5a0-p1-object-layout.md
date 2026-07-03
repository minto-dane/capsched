# Validation 0158: SchedExecLease P5A0.P1 Object and Layout Evidence

Date: 2026-07-03

Status: passed for object/symbol/section-size review, hot scheduler function
size review, and build-only task layout probe. QEMU denial-disabled smoke,
upstream-maintenance, and final overclaim/security acceptance remain pending.

## Scope

This validates the concrete P5A0.P1 `0008` no-behavior source-contract patch at
the generated-object and build-layout level.

It remains compatibility evidence only. It is not runtime coverage, runtime
denial, behavior equivalence, monitor verification, production protection,
cost-efficiency, deployment readiness, or datacenter readiness evidence.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_subject=sched/exec_lease: Document P5A0.P1 no-behavior boundary
build_tag=p5a0-p1-0008
```

## Object Checker

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-object-check.sh
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260703T-p5a0-p1-0008-object \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-object-check.sh
```

Output:

```text
/media/nia/scsiusb/dev/linux-cap/build/source-check/sched-exec-lease-p5a0-p1-0008-object-check/20260703T-p5a0-p1-0008-object
```

Key results:

```text
work_commit_matches=true
config_off_undef=true
config_on_y=true
off_exec_lease_object_absent=true
on_exec_lease_object_present=true
core_o_file_size_equal=true
core_o_file_size=347728/347728
core_function_size_table_equal=true
core_function_count=396
core_function_hash=93118056ab488b9f280f37d64983b1935f531e3988ba372910266188bc1401d3
validation_symbols_emitted=false
exec_lease_task_symbols_expected=true
exec_lease_o_text=289
exec_lease_o_data=32
exec_lease_o_bss=0
exec_lease_o_dec=321
```

Generated `exec_lease.o` task symbols:

```text
sched_exec_task_exit          0x0000000000000011
sched_exec_task_commit_exec   0x0000000000000023
sched_exec_task_prepare_fork  0x0000000000000040
sched_exec_task_reset         0x0000000000000040
```

The checker also captured:

```text
object-size.txt
object-sha256.txt
off-core-sections.txt
on-core-sections.txt
on-exec-lease-sections.txt
on-exec-lease-disassembly.txt
off-core-function-sizes.tsv
on-core-function-sizes.tsv
```

Raw object byte identity is not claimed. Debug paths and build metadata can
make object bytes unsuitable as a semantic equality oracle. The accepted hot
scheduler evidence is instead that `core.o` file size, defined function count,
and defined function-size table match exactly between disabled and enabled
configurations.

## Task Layout Probe

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh
```

Command:

```sh
BUILD_TAG=p5a0-p1-0008 \
  capsched/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-task-layout-probe-20260703T005619Z.log
```

Output:

```text
/media/nia/scsiusb/dev/linux-cap/build/task-layout/sched-exec-lease-p5a0-p1-0008-20260703T005619Z
```

Disabled symbols:

```text
sched_exec_no_config_probe         0x0000000000000001
sched_exec_task_struct_size_probe  0x0000000000000cc0
```

Enabled symbols:

```text
sched_exec_field_size_probe             0x0000000000000028
sched_exec_field_offset_plus_one_probe  0x0000000000000591
sched_exec_task_struct_size_probe       0x0000000000000d00
```

Interpretation:

```text
CONFIG_SCHED_EXEC_LEASE=off:
  sched_exec field is absent from task_struct.

CONFIG_SCHED_EXEC_LEASE=on:
  sched_exec field is present.
  sizeof(task_struct.sched_exec) is 0x28 bytes.
  offsetof(task_struct, sched_exec) + 1 is 0x591.
  sizeof(struct task_struct) is 0xd00.
```

P5A0.P1 `0008` itself is comment-only and did not touch `include/linux/sched.h`
or `kernel/sched/sched.h`; therefore this validation records that the existing
P2 task shadow layout remains as expected, and that P5A0.P1 adds no new task,
rq, sched_entity, or cfs_rq layout change.

## Interpretation

This closes the generated-object and layout part of P5A0.P1 acceptance:

```text
CONFIG_SCHED_EXEC_LEASE=off:
  exec_lease.o is absent.
  core.o function-size table is the comparison baseline.

CONFIG_SCHED_EXEC_LEASE=on:
  exec_lease.o is present with the expected four lifecycle helper symbols.
  no validation helper symbol is emitted.
  core.o file size and function-size table match the disabled configuration.
  task_struct sched_exec layout remains the already validated P2 layout.
```

## Remaining P5A0.P1 Acceptance Work

Still required before final P5A0.P1 acceptance:

```text
QEMU denial-disabled boot/workload smoke
fresh upstream drift and merge-tree evidence
strict checkpatch and get_maintainer output
final overclaim/security review
```

## Non-Claims

This validation does not approve:

```text
runtime denial
CFS deny-and-repick
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```
