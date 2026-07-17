# Validation 0207: SchedExecLease P5A-R2 E2 Disposable Layout Candidate Plan

Date: 2026-07-13

Status: passed for disposable arm64 E2 candidate creation only.

## Scope

Validate analysis/0159 and formal/0126 against exact E1 Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`. This gate may authorize only a
disposable arm64 layout candidate worktree. It cannot modify the primary Linux
branch or patch queue and cannot approve behavior, ABI, hot fields, E3 rebuild,
protection, performance, cost, deployment, or datacenter readiness.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan.sh
```

## Expected Gate

```text
20 source anchors
6 candidate-absence checks
safe TLC pass
30 expected unsafe counterexamples
primary patch queue tail remains 0014
candidate symbols: 51 existing + 8 conditional = 59
arm64 cacheline table: 27 fields
```

## Result

Run `20260713T-p5a-r2-e2-layout-plan` passed:

```text
source anchors: 20, failures: 0
candidate absence checks: 6, failures: 0
safe TLC: 5 generated, 4 distinct, depth 4
unsafe expected counterexamples: 30
primary patch queue tail: 0014
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan/
  20260713T-p5a-r2-e2-layout-plan/result.json
```

## Claim Boundary

This passed plan result creates no primary Linux or patch-queue change and
makes no build, layout, runtime, or protection claim. The separately monitored
validation/0208 must measure the disposable candidate.
