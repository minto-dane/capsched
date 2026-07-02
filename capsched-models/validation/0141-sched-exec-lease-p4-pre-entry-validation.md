# Validation 0141: SchedExecLease P4 Pre-Entry Validation

Status: Passed for P4 allow-all/no-denial pre-entry evidence; P4 implementation
is not applied and no runtime protection claim is made

Date: 2026-07-02

## Purpose

Validate everything required before opening the P4 implementation step. P4 is
allowed to be an allow-all final run/move revalidation skeleton only. This
record does not validate runtime denial, monitor protection, or production
security.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
```

## Patch Queue Replay

Command:

```sh
rm -rf build/replay/p4-pre-localref-20260702T100222Z
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux \
DOMAINLEASE_RECREATE_FETCH=0 \
  ./linux-patches/scripts/recreate-capsched-linux-l0.sh \
  /media/nia/scsiusb/dev/linux-cap/build/replay/p4-pre-localref-20260702T100222Z/linux
```

Result:

```text
replay_head=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
expected_head=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
replay_exact_match=true
```

## Upstream Drift Gate

Run directory:

```text
build/source-drift/linux-source-drift-gate/20260702T095803Z-p4-pre
```

Summary:

```text
upstream_commit=4a50a141f05a8d1737661b19ee22ff8455b94409
work_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
base_to_upstream_commit_count=342
watched_changed_count=1
changed_path=kernel/sched/cpufreq_schedutil.c
drift_class=D1_nearby_non_intersecting_drift
model_refresh_required_count=0
merge_tree_clean=true
model_freshness=fresh
candidate_no_behavior_patch_reviewable=true
linux_patch_approved=false
behavior_change=false
runtime_coverage=false
abi=false
monitor_verified=false
production_protection=false
```

## Diff and Security Review

P3 diff from P2:

```text
include/linux/sched_exec_lease.h | 36 ++++++++++++++++++++++++++++++++++++
kernel/sched/core.c              |  5 +++++
kernel/sched/sched.h             |  1 +
3 files changed, 42 insertions(+)
```

`git diff --check` result:

```text
git_diff_check_p3=passed
```

Forbidden-surface grep over the P3 diff found only comment text that explicitly
denies validation, denial, retry, budget charge, and monitor calls. It found no
new ABI, tracepoint, export, monitor call, allocation, policy hook, or fallible
runtime path in added code.

Codex Security plugin preflight for a diff scan profile returned ready. A full
canonical security scan was not launched because the P3 diff does not create a
new parser, syscall, ioctl, sysfs/procfs/debugfs surface, allocator, copy path,
credential path, monitor call, or privilege boundary. This validation records a
scoped diff security review only.

`checkpatch.pl --strict --no-tree` against patch queue 0006 reported:

```text
WARNING: Missing commit description
ERROR: Missing Signed-off-by
```

Interpretation:

```text
semantic/security blocker for P4 pre-entry: no
upstream/RFC readiness blocker before public patch series: yes
```

## Generated-Code Review

P2-vs-P3 `kernel/sched/core.o` comparison after normal rebuild:

```text
mode=off:
  p2_p3_core_o_differs
  marker symbols absent

mode=on:
  p2_p3_core_o_differs
  marker symbols absent
```

Section-size and relocation review:

```text
mode=off:
  text=73924 data=29289 bss=704 dec=103917 in both P2 and P3
  relocations_identical

mode=on:
  text=73924 data=29289 bss=704 dec=103917 in both P2 and P3
  relocations_identical
```

Disassembly differences:

```text
try_to_wake_up:
  commutative test operand order changed

__schedule:
  two independent mov loads before switch_mm_irqs_off changed order
```

Interpretation:

```text
P3 generated code is not byte-identical to P2.
The reviewed differences are semantically equivalent instruction-order noise.
No marker helper symbols or relocation changes were introduced.
No byte-identity claim is made.
```

## QEMU Broader Workload Matrix

Clean direct runner:

```text
log=build/logs/sched-exec-lease-p4-pre-qemu-matrix-20260702T100641Z-direct.log
workload_mode=all
kprobes_enabled=1
```

The `all` workload runs fork/exec, cross-CPU futex ping-pong, affinity
migration, and CPU pressure in one boot.

Disabled run:

```text
run_dir=build/qemu/sched-exec-lease-p4-pre-matrix-direct/20260702T100641Z-off
qemu_status=0
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
sched_switch=15092
sched_migrate_task=44
enqueue_task=14952
sched_tick=1160
kprobe:dlease_enqueue_task=7476
kprobe:dlease_try_to_wake_up=7430
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=580
```

Enabled run:

```text
run_dir=build/qemu/sched-exec-lease-p4-pre-matrix-direct/20260702T100707Z-on
CONFIG_SCHED_EXEC_LEASE=y
qemu_status=0
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
sched_switch=15101
sched_migrate_task=41
enqueue_task=14954
sched_tick=1160
kprobe:dlease_enqueue_task=7477
kprobe:dlease_try_to_wake_up=7431
kprobe:dlease_wake_up_new_task=9
kprobe:dlease_sched_tick=580
```

Coverage limits remained:

```text
FUNCTION_MISSING pick_next_task
FUNCTION_MISSING __schedule
KPROBE_ADD_FAILED p:domainlease/dlease_pick_next_task pick_next_task
```

An earlier systemd wrapper run also produced successful off/on QEMU guest
results, but the transient unit itself timed out during process-substitution
cleanup. The direct runner above is the accepted clean validation evidence.

## P4 Entry Verdict

P4 may be prepared as an allow-all/no-denial skeleton. Its plan has been
updated to this P3 source basis.

P4 must not claim or implement:

```text
runtime denial
retry or ineligibility state
fail-closed CPU idling
monitor call or monitor receipt
budget charge or budget enforcement
policy frontend integration
user ABI or public tracepoint ABI
runtime coverage
production protection
hypervisor-grade isolation
cost efficiency
datacenter deployment readiness
```

P5 remains blocked until pre-settle/rollback proof, negative denial tests,
path classification, runtime traces for the supported set, and claim-ledger
rows exist.
