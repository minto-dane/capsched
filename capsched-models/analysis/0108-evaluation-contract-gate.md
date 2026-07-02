# Analysis 0108: Evaluation Contract Gate

Status: Draft model gate with TLC-backed design filter; no evaluation result or
cost/protection claim approved

Date: 2026-07-01

## Purpose

N-154 closes the model-only blocker for `EVAL-001`.

This gate does not run benchmarks and does not claim cost efficiency. It defines
the evaluation contract required before production protection or datacenter cost
efficiency can be claimed.

## Required Security Evaluation Contract

The security contract must include:

```text
Domain-local kernel exploit containment
cross-Domain user/kernel memory read/write attempts
cross-Domain DMA attempts
cross-Domain control-authority attempts
HyperTag Monitor escape attempts
explicit security pass/fail criteria
negative-result recording policy
```

## Required Cost and Performance Evaluation Contract

The cost contract must include:

```text
KVM baseline
Firecracker baseline
container/Linux baseline
workload envelope
throughput metric
tail latency metric
density metric
operational cost metric
explicit cost pass/fail criteria
```

Microbenchmarks alone are not sufficient for datacenter OS cost-efficiency
claims.

## Model

New model:

```text
formal/0086-evaluation-contract-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoModelSupportWithoutSecurityContract
NoModelSupportWithoutCostContract
NoProductionProtectionClaim
NoCostEfficiencyClaim
NoEvaluationResultClaim
```

## Rejected Designs

The model rejects:

```text
missing exploit-containment contract
missing cross-Domain memory contract
missing cross-Domain DMA contract
missing cross-Domain control-authority contract
missing monitor-escape contract
missing KVM baseline
missing Firecracker baseline
missing container baseline
missing workload envelope
missing throughput metric
missing tail-latency metric
missing density metric
missing operational-cost metric
missing security pass criteria
missing cost pass criteria
missing negative-result policy
microbench-only evaluation
production-protection claim from contract
cost-efficiency claim from contract
evaluation-result claim from contract
```

## Assurance Effect

This gate moves `EVAL-001` from open to model-supported. It does not make
`EVAL-001` production-evidenced.

## Non-Claims

This gate does not provide evaluation results, runtime coverage, benchmark
results, exploit-containment success, monitor verification, production
protection, or cost-efficiency evidence.
