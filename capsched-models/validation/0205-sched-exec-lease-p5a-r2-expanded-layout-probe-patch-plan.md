# Validation 0205: SchedExecLease P5A-R2 Expanded Layout Probe Patch Plan

Date: 2026-07-13

Status: passed for patch 0014 drafting only. No behavior or hot-field patch is
approved.

## Scope

Validate analysis/0158 and formal/0125 against the exact recreated Linux tree.
Patch 0014 is limited to `kernel/sched/exec_lease_layout_probe.c` and must add
25 object-local measurements to the existing 24-symbol probe.

## Result

```text
run_id: 20260713T-p5a-r2-expanded-layout-probe-plan
status: passed_patch_plan_only
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
source anchors: 25
source anchor failures: 0
absence failures: 0
safe TLC: 5 generated, 4 distinct, depth 4
unsafe expected counterexamples: 20
patch slot: 0014
expected total probe symbols: 49
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-expanded-layout-probe-patch-plan/
  20260713T-p5a-r2-expanded-layout-probe-plan/result.json
```

## Approved Draft Boundary

0014 may modify only the existing probe translation unit. Kconfig, Makefile,
structure definitions, runtime functions, call sites, exports, and ABI remain
frozen. Candidate fields remain absent and must not receive fabricated probe
symbols. Cacheline indices are derived from object measurements.

## Non-Claims

This gate does not approve selector/rebuild behavior, hot fields, runtime
denial correctness, monitor enforcement, protection, performance, cost,
deployment, or datacenter readiness.

## Next

Draft 0014, create its patch-queue entry, and validate exact replay plus normal
off/on absence and explicit probe-on 49-symbol extraction.
