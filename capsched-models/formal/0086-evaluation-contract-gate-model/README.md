# Evaluation Contract Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This N-154 model closes the model-only blocker for `EVAL-001`.

It defines the evaluation contract required before CapSched-H may claim
production protection or cost efficiency:

```text
security:
  exploit containment
  cross-Domain memory attempts
  cross-Domain DMA attempts
  cross-Domain control-authority attempts
  monitor escape testing

cost/performance:
  KVM baseline
  Firecracker baseline
  container baseline
  workload envelope
  throughput, tail latency, density, and operational cost metrics
```

## Non-Claims

This model is not an evaluation result. It does not claim production
protection, cost efficiency, runtime coverage, or benchmark success.
