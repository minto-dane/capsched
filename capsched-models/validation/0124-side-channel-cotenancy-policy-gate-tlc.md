# Validation 0124: Side-Channel and Co-Tenancy Policy Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0085-side-channel-cotenancy-policy-gate-model/
```

The model defines explicit side-channel and co-tenancy policy constraints for
SMT, core, cache, NUMA, device queue, and cluster placement decisions.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/side-channel-cotenancy-policy-gate-20260702T000905Z/safe \
  -config SideChannelCotenancyPolicyGateSafe.cfg \
  SideChannelCotenancyPolicyGate.tla
```

Unsafe configs:

```text
SideChannelCotenancyPolicyGateUnsafe*.cfg
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
15 expected counterexamples
```

JSON contract:

```text
6 policy dimensions
5 hard boundaries preserved
8 requirements
15 unsafe cases
7/8 safety flags false
```

Rejected hazards:

```text
unknown policy defaulting to allow
SMT/core/cache/NUMA/device queue/cluster sharing without explicit policy
performance optimizer overriding isolation
side policy weakening hard boundary
scheduler ignoring side policy
missing monitor binding
missing leakage classification
side policy as authority root
production-protection overclaim
cost-efficiency overclaim
```

## Evidence

This validation adds:

```text
E-SIDE-COTENANCY-001
```

It supports:

```text
SIDE-001
```

only as model evidence.

## Non-Claims

This is not scheduler implementation, core-scheduling integration,
cache/NUMA/device queue isolation implementation, runtime side-channel testing,
performance evidence, monitor verification, production protection, or
cost-efficiency evidence.
