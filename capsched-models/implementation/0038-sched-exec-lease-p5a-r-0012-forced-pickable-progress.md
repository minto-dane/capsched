# Implementation 0038: SchedExecLease P5A-R 0012 Forced Pickable Progress

Date: 2026-07-04

Status: corrective draft Linux patch applied after validation/0184 showed that
the `0011` eligible-only fallback still allowed a post-start timeout. This is
not accepted as production denial policy, fairness policy, cost evidence, or
protection.

## Purpose

Patch `0011` stopped one same-state retry class but still allowed the fair
class to settle to idle when denial hid the only eligible entity and an allowed
entity was runnable but temporarily not CFS-eligible.

That shape can dead-end progress:

```text
denied entity:
  eligible but not pickable

allowed entity:
  runnable and pickable, but temporarily not eligible

bad settlement:
  return NULL -> idle

consequence:
  allowed task may not run enough to complete and settle the test
```

## Linux Patch

```text
linux_commit=bd71af5daeae808ac948cbd12af2663151936f22
linux_subject=sched/fair: Force exec lease pickable CFS progress
patch_queue_file=linux-patches/patches/capsched-linux-l0/0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch
patch_queue_sha256=f306bbfb16265df5a02632f8b2551b5f3e5a8420180ea13d6a59d4291fd2fa35
series_sha256=98cb3e54768b918be459498bc0d9731aaf8234787a956686d8edad83c6fbb240
```

Touched Linux files:

```text
kernel/sched/fair.c
```

## Change Shape

The patch splits the fallback scan into:

```text
sched_exec_cfs_pickable_scan(..., require_eligible=true)
sched_exec_cfs_pickable_scan(..., require_eligible=false)
```

The first pass preserves ordinary CFS eligibility when possible. The second
pass is used only after denial blockage has already been observed and no
eligible pickable entity exists.

Rule:

```text
prefer allowed pickable runnable progress over idle
never run a known denied candidate
```

## Design Caveat

This is a draft forced-progress rule for the test path. It trades ordinary CFS
eligibility precision for forward progress only after denial has blocked the
eligible candidate.

Production SchedExecLease still needs a modeled pickability-aware selection
structure or a bounded fallback with explicit fairness, latency, and cost
evidence. This patch alone does not settle that design.

## Fast Evidence

Patch style:

```text
checkpatch_strict=clean
```

Targeted build:

```text
run_id=20260704T-p5ar-0012-targeted-build
out_dir=build/source-check/sched-exec-lease-p5a-r-0012-targeted-build/20260704T-p5ar-0012-targeted-build
```

Objects:

```text
off_fair_o_size=164608
off_fair_o_sha256=9691fdaacac021a719e1ec88a79029490394c733e5f066a23075c3102193f844
off_core_o_size=364448
off_core_o_sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on_fair_o_size=167976
on_fair_o_sha256=562bd19ef2f06c617b044234ab51da5dd05a3c9e90623f968dbf5b01c36fe185
on_core_o_size=364448
on_core_o_sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

## Required Next Validation

Validation/0186 reran the P5A-R QEMU negative workload against `0012`:

```text
qemu_status=0
NEGATIVE_ALLOWED_NEXT 770
NEGATIVE_DENIED_NEXT 0
NEGATIVE_RESULT PASS
```

This closes the immediate synthetic ordinary-CFS forward-progress failure
exposed by validations/0181, 0182, and 0184.

Validation/0187 records the security/overclaim boundary review. It found no
immediate memory-safety finding in the reviewed diff, but keeps `0012`
experimental because the fallback still has production blockers:

```text
unbounded rb-tree scan when denial blockage is active
forced progress over ordinary CFS eligibility
single-denial receipt capacity / single retry
ordinary-CFS-only coverage
synthetic comm-prefix denial rather than real authority, including task-name
race unsuitability
patch-queue metadata/style cleanup still needed before RFC/mainline-style use
```

## Non-Claims

This patch does not prove:

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
