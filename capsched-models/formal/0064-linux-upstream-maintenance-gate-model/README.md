# Formal 0064: Linux Upstream Maintenance Gate Model

Status: checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

Related artifacts:

```text
analysis/0086-linux-upstream-drift-maintenance-review.md
analysis/linux-upstream-drift-maintenance-review-v1.json
implementation/0014-linux-async-carrier-candidate-patch-plan.md
validation/0102-linux-upstream-maintenance-gate-tlc.md
```

## Purpose

This model captures the N-131 decision that no new Linux async-carrier patch is
approved in the current tree, even a no-behavior opaque type patch.

The model deliberately separates:

```text
Git merge cleanliness
watched-path drift review
concrete consumer need
patch approval
security/protection claims
```

The safe path records upstream drift and merge cleanliness, then accepts a
defer decision.

## Non-Claims

This model does not verify Linux behavior, runtime coverage, async carrier
implementation, monitor enforcement, or production protection.
