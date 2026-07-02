# Validation 0125: Evaluation Contract Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0086-evaluation-contract-gate-model/
```

The model defines the evaluation contract required before production protection
or datacenter cost-efficiency claims.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/evaluation-contract-gate-20260702T001605Z/safe \
  -config EvaluationContractGateSafe.cfg \
  EvaluationContractGate.tla
```

Unsafe configs:

```text
EvaluationContractGateUnsafe*.cfg
```

## Result

Safe TLC:

```text
3 generated states
2 distinct states
0 states left on queue
depth 2
```

Unsafe TLC:

```text
20 expected counterexamples
```

JSON contract:

```text
7 security-contract rows
9 cost/performance-contract rows
6 forbidden shortcuts
20 unsafe cases
7/8 safety flags false
```

Rejected hazards:

```text
missing exploit-containment contract
missing cross-Domain memory/DMA/control contract
missing monitor-escape contract
missing KVM/Firecracker/container baseline
missing workload envelope
missing throughput, tail-latency, density, or operational-cost metric
missing security or cost pass criteria
missing negative-result policy
microbench-only evaluation
production-protection claim from contract
cost-efficiency claim from contract
evaluation-result claim from contract
```

## Evidence

This validation adds:

```text
E-EVAL-CONTRACT-001
```

It supports:

```text
EVAL-001
```

only as model evidence.

## Non-Claims

This is not evaluation execution, runtime coverage, exploit-containment
success, benchmark result, monitor verification, production protection, or
cost-efficiency evidence.
