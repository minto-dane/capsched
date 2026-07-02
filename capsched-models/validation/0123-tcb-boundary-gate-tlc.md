# Validation 0123: TCB Boundary Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0084-tcb-boundary-gate-model/
```

The model defines the model-supported TCB boundary for the HyperTag Monitor and
service Domains.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/tcb-boundary-gate-20260702T000304Z/safe \
  -config TcbBoundaryGateSafe.cfg \
  TcbBoundaryGate.tla
```

Unsafe configs:

```text
TcbBoundaryGateUnsafe*.cfg
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
11 expected counterexamples
```

JSON contract:

```text
9 monitor allowed responsibilities
7 monitor forbidden responsibilities
6 monitor interface requirements
6 service-domain requirements
8 comparison-envelope fields
11 unsafe cases
7/8 safety flags false
```

Rejected hazards:

```text
unbounded monitor core
untyped monitor interface
driver, parser, or policy engine inside the monitor
Linux mutable state as trusted root
service Domain ambient authority
raw handle exposure
missing TCB budget
missing VM/VMM comparison envelope
implementation overclaim
production-protection overclaim
cost-efficiency overclaim
```

## Evidence

This validation adds:

```text
E-TCB-BOUNDARY-001
```

It supports:

```text
TCB-001
```

only as model evidence.

## Non-Claims

This is not monitor implementation, service-domain implementation, line-count
measurement, interface-count measurement, runtime coverage, monitor
verification, production protection, or cost-efficiency evidence.
