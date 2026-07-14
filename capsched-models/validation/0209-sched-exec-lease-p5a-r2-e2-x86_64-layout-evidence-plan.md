# Validation 0209: SchedExecLease P5A-R2 E2 x86_64 Layout Evidence Plan

Date: 2026-07-14

Status: passed for launching the detached x86_64 cross-build only. This gate
does not authorize source or behavior.

## Scope

Validate analysis/0160 and formal/0127 against the passed arm64 result, exact
E1 and disposable-candidate commits, frozen primary patch queue, and existing
x86_64 architecture-local baseline.

## Expected Gate

```text
18 source anchors
4 runtime-source absence checks
safe TLC pass
24 expected unsafe counterexamples
target x86_64 from arm64 with x86_64-linux-gnu-
fresh same-toolchain E1 and candidate build matrix
51 E1 + 8 candidate = 59 symbols
27 cacheline-table fields
no source, acceptance, E3, runtime, or protection approval
```

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-e2-x86_64-layout-evidence-plan.sh
```

## Result

Run `20260714T-p5a-r2-e2-x86_64-layout-plan` passed:

```text
source anchors:                  18, failures 0
runtime-source absence checks:  4, failures 0
safe TLC:                       5 generated, 4 distinct, depth 4
unsafe expected counterexamples: 24/24
target:                         x86_64
build host:                     arm64
cross prefix:                   x86_64-linux-gnu-
```

Result SHA-256:
`507b3ab7a1634cf7aec436a03924ab9c3ffa6b43f58380b2159078e73a17b314`.

## Claim Boundary

Even a passed plan is not build evidence. Validation/0210 must independently
rebuild the E1 probe and all candidate modes for x86_64. Cross-built object
layout is not x86_64 runtime, boot, latency, bare-metal, or production proof.

## Attempt History

The first plan run stopped before TLC because one machine-searchable arm64
documentation anchor was absent. Validation/0208 already contained the four
individual zero rows and the authoritative result encoded all four zero
deltas; an explicit summary sentence was added. No model rule, source tree,
candidate identity, build result, or safety claim changed.

A subsequent direct macOS-host invocation could not locate Java. The
authoritative run therefore executed in the existing Linux machine with
OpenJDK 21, consistent with prior project TLC runs.

After validation/0210 exposed x86_64 defconfig's disabled `EXPERT` dependency,
the plan was made explicit that all four modes enable `EXPERT` before applying
their lease/probe settings. The same run ID was re-executed against that
updated plan and again passed 18 anchors, 4 absence checks, safe TLC, and all
24 expected counterexamples with the same result hash.
