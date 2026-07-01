# Formal 0070: Runtime Coverage Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the trace-only runtime coverage gate from analysis/0092.

The model does not attempt to prove budget enforcement. It checks that a future
runtime coverage artifact cannot be accepted unless it names current, donor,
proxy, server, evidence class, and trace-only non-claim boundaries.

## Required Meaning

Acceptable coverage requires:

```text
current executor observed
donor/accounting subject observed
proxy relation observed when proxy execution is in scope
server lifecycle, runtime, and epoch relation observed when server execution is
  in scope
evidence class tagged
trace-only status preserved
no authority, enforcement, monitor verification, behavior-change, or protection
claim
```

## Forbidden

```text
sched_stat_runtime as authority
remote tick as proxy coverage
server start/stop alone as full server coverage
class runtime as root budget evidence
trace-only coverage as production protection
```

## Validation

Recorded in:

```text
validation/0109-runtime-coverage-gate-tlc.md
```

Safe TLC:

```text
49 generated states
29 distinct states
depth 6
```
