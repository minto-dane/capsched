# Validation 0199: SchedExecLease P5A-R2 0013 Disabled-Overhead Boundary

Date: 2026-07-05

Status: passed. No runtime behavior, performance, or protection claim is
approved.

## Scope

This validation checks that the no-behavior 0013 layout probe does not enter
normal CONFIG off/on scheduler object builds.

Run:

```text
RUN_ID=20260705T-p5a-r2-0013-disabled-overhead
```

Result:

```text
linux_commit: 0b79e307dc9536d38557141cfd650f2be9a2af57
parent_commit: bd71af5daeae808ac948cbd12af2663151936f22
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
changed_files_only_probe_boundary: true
touched_existing_hot_or_lifecycle_file: false
layout_probe_default_n: true
layout_probe_selected_by_normal_config: false
normal_config_off_probe_object_absent: true
normal_config_on_probe_object_absent: true
normal_objects_with_probe_symbols: false
normal_object_count: 5
normal_object_ledger_sha256: 9e3b71bc4ac6d4db7095c3fde5db5cbe143595e8adc8b82418ee88f20ce5569a
object_byte_identity_claim: false
```

## Normal Object Ledger

```text
off fair.o size=157712 sha256=7ffe2581363a25c2a8816843ae43a16adaef096a65dbc9614d8467226e2b3f5d
off core.o size=347744 sha256=b10d6f05c8be1fd5654ff0686235a4bb2e6c752873518a74d52c697fb189dd1b
on fair.o size=160088 sha256=b12f0e621617c220dc7d468943128da6d363a65d36c288f66d93df7580e42fab
on core.o size=347744 sha256=d48b9bd593ae53468b246bbaede0e92a95b1cd8c9598d945be4977936acb8aea
on exec_lease.o size=2304 sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
```

## Interpretation

Patch 0013 changes only the probe boundary:

```text
init/Kconfig
kernel/sched/Makefile
kernel/sched/exec_lease_layout_probe.c
```

It does not touch existing hot scheduler or lifecycle files. The probe Kconfig
is default-off and is not selected by normal `CONFIG_SCHED_EXEC_LEASE`.

This validation intentionally does not make an object byte-identity claim
against another source checkout or build directory. Kernel object bytes can be
affected by build path and debug metadata. The evidence here is the narrower
build-graph boundary: the normal off/on scheduler object builds do not emit
`exec_lease_layout_probe.o` and do not contain `sched_exec_lp_*` probe symbols.

## Non-Claims

This validation does not approve:

```text
performance improvement
global disabled-overhead benchmark
runtime behavior changes
new hot scheduler runtime fields
future min-pickable summary fields
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

The next step is to decide whether another evidence-only slice is needed, or
whether P5A-R2 should move back to source/model work for a future fresh-summary
selector patch.
