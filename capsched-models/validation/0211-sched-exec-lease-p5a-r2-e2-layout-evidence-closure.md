# Validation 0211: SchedExecLease P5A-R2 E2 Layout Evidence Closure

Date: 2026-07-14

Status: passed. The exact disposable E2 layout is frozen for E3 planning only;
E3 source and production layout remain unapproved.

## Scope

Validate analysis/0161 and formal/0128 against exact, hashed arm64 and x86_64
results, immutable primary/candidate/patch-queue identities, normal-build
absence, symbol/table accounting, zero growth, protected measurements, field
bounds, and architecture-local offsets.

## Expected Gate

```text
arm64 and x86_64 result hashes exact
51 E1 values preserved per architecture
8 additions, 59 total symbols, 27 fields per architecture
all four structure deltas zero per architecture
safe TLC pass
24 expected unsafe counterexamples
E3 plan drafting only
no E3 worktree/source, primary promotion, production, runtime, or cost claim
```

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-e2-layout-evidence-closure.sh
```

## Claim Boundary

A passed result closes E2 layout evidence and freezes only the exact candidate
identity for an E3 plan. It does not make those fields production-approved,
modify a Linux tree, or permit E3 implementation before its own plan passes.

## Result

Run `20260714T-p5a-r2-e2-layout-closure` passed:

```text
architectures:                    arm64, x86_64
E1 values preserved each:        51
candidate additions each:        8
candidate symbols each:          59
cacheline table fields each:      27
all structure deltas zero:        true
architecture-local offsets:      preserved
safe TLC:                         5 generated, 4 distinct, depth 4
unsafe expected counterexamples: 24/24
E3 plan may be drafted:           true
E3 worktree/source approved:      false
production layout accepted:       false
```

Result SHA-256:
`8530480492cee6b2182bbe5b99a5d886cf5a2559dd8ad1341cba1643d6464031`.
