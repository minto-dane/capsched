# Implementation 0051: SchedExecLease P5A-R6 E3 Domain-Forest Correctness Prototype

Date: 2026-07-26

Status: the exact disposable direct-R6-E2-child candidate passed its source
gate, four fresh virtual diagnostic profiles, and two independent read-only
evidence closures. A separate post-evidence authorization gate is still
required before the source identity or synthetic correctness semantics may be
accepted, or an R6-E4 plan may be drafted.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype
branch:   codex/p5a-r6-e3-correctness-prototype
parent:   66e2fd20fc85012d7dc03649fcf4c7af583cbb94
commit:   99287291f1c8e0d6c1b3ea86d121508c5547f424
tree:     2b863b57dfe3f03609ad1a73c965874f71056e8f
diff:     2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
```

The candidate is one pushed direct child of the closed R6-E2 layout commit.
It adds 1,516 lines and deletes none in exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

Primary Linux remains
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, and the patch queue remains
`16bb080da472ffabbbafd2698073eca633fb0602`.

## Synthetic Boundary

`CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST` defaults to off, depends on the R6
layout probe and built-in KUnit, and registers only suite
`sched_exec_lease_r6_correctness` in `kernel/sched/exec_lease.c`.

The suite exercises a private 64-slot masked forest using real raw spinlocks,
cpumasks, refcounts, and RCU lifetime primitives against an independent
64-leaf oracle. It does not attach state to a live runqueue, task, task group,
cgroup, scheduler class, current task, monitor, MemoryView, device, or cluster
control plane.

The exact contract contains 55 deterministic case families, three allocation
fault sites, 4,096 stress repetitions per diagnostic profile, a 15-second
hard case timeout, and one typed `R6_RECEIPT` per required case.

## Source Gate

Canonical source-gate run
`20260726T-p5a-r6-e3-source-gate-r1` passed at result SHA-256:

```text
88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25
```

It independently checked the direct-child/two-file/additive boundary,
default-off Kconfig, exact cases and fault sites, preserved R6-E2 private
layout, 49 R6 values, 51 existing expanded values, zero ordinary scheduler
structure growth, disabled-artifact absence, strict checkpatch 0/0/0, and
fresh arm64/x86_64 W=1 builds in four modes per architecture.

## Four-Profile Matrix

Canonical run `20260726T-p5a-r6-e3-four-profile-r1` passed at:

```text
result:
  bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be
profile results:
  9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71
```

The profiles were arm64 and x86_64 standard debug/lockdep/RCU/hotplug/fault,
arm64 generic KASAN, and x86_64 strict KCSAN. Every fresh build booted only
the exact suite and was retired after its evidence was sealed.

All four profiles passed 55/55 cases and emitted 55/55 receipts. Aggregate
counts are 220/220 cases and 220/220 receipts, with zero failure, skip,
timeout, compiler diagnostic, final clock-skew warning, or classified kernel
warning.

## Independent Closure

The closure runner SHA-256 is:

```text
5b4176a7b71b246f270a95db520ea7f5410dc25551adb75dfad9b873c387481b
```

It freezes all 60 retained regular files and 2,659,341 bytes at manifest
SHA-256
`151c877301d3f59d171fc30bf449044990e46892860c8f9d2eb4f3467b0b4ecc`.
It separately rechecks the configs, logs, ELF records, KTAP, console-derived
receipts, warning classification, Git identity, and retired build boundary.
Its regression accepts the exact fixture and rejects content tamper and
symlink injection.

Two canonical closures passed:

```text
r1:
  0dce94b2ddf3448727bf936611704e33637f9114e8668cf1311aa1274775239a
r2:
  964a16b0636d7f02850b851dd1530e9c08cc6c9e0c495c6b6a3ba78a1856a514
normalized:
  3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7
```

## Authorization Boundary

This record describes what was built and observed. It does not itself accept
source, correctness, or any next implementation step.

The following remain false:

```text
r6_e3_source_accepted
r6_e3_correctness_accepted
r6_e4_plan_may_be_drafted
r6_e4_plan_accepted
r6_e4_source_may_be_created
primary_linux_may_change
patch_queue_may_change
live_scheduler_attachment
runtime_behavior_approved
runtime_denial_correctness
runtime_coverage
async_service_boundary_validated
memoryview_or_tlb_validated
device_dma_iommu_validated
monitor_verified
cluster_authority_validated
bare_metal_validated
production_protection
deployment_ready
multi_node_ready
multi_cluster_ready
datacenter_ready
```

The next step is a source-free, repository-threat-model-bound authorization
gate. It may accept only the exact existing disposable source and synthetic
protocol scope, and may authorize only drafting a separate R6-E4 plan.
