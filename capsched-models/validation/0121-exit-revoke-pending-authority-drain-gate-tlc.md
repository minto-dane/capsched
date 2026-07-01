# Validation 0121: Exit/Revoke Pending Authority Drain Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0082-exit-revoke-pending-authority-drain-gate-model/
```

The model is a semantic integration gate for exit/revoke completion across
scheduler, async, endpoint, monitor admission, device, budget, server, root
execution, and unknown pending authority carriers.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/exit-revoke-pending-authority-drain-gate-20260701T234340Z/safe \
  -config ExitRevokePendingAuthorityDrainGateSafe.cfg \
  ExitRevokePendingAuthorityDrainGate.tla
```

Unsafe configs:

```text
ExitRevokePendingAuthorityDrainGateUnsafe*.cfg
```

## Result

Safe TLC:

```text
13 generated states
11 distinct states
0 states left on queue
depth 10
```

Unsafe TLC:

```text
28 expected counterexamples
```

JSON contract:

```text
44 source anchors
14 inventory key fields
20 carrier families
9 safe path steps
16 requirements
20 forbidden substitutions
28 unsafe cases
18/18 safety flags false
```

Rejected hazards:

```text
exit complete with remote wake pending
exit complete with queued/selected/denied/move FrozenRunUse pending
release before drain settlement
PID/TGID or raw pointer reuse matching stale authority
revoke complete with workqueue carrier pending
cancel_work_sync() or flush_work() as drain receipt
work pending-bit clear as revoke receipt
self-requeue using old workqueue carrier
io_uring cancel/free as drain receipt
CQE delivery or skip as authority settlement
linked/reissued io_uring request using old authority
endpoint use after exit/revoke
futex waiter wake after endpoint revoke
direct-call revoke complete with in-flight request/response
ring revoke complete with pending slot/response
derived receipt or Linux shadow live after revoke complete
device queue reassignment before drain/quarantine
BudgetTicket refund before carrier terminal state
server borrow ticket surviving exit/revoke
root timer or RunToken live after terminal state
audit/trace/timeout/Linux cleanup as drain proof
unknown pending carrier treated as drained
budget reservation leak
budget double settlement
RCU visibility as authority
behavior-change overclaim
monitor-verification overclaim
protection overclaim
```

## Evidence

This validation adds:

```text
E-SCHED-EXIT-REVOKE-DRAIN-001
```

It supports:

```text
EXEC-001
BUDGET-001
ENDP-001
ASYNC-001
DEV-001
REVOKE-001
COMPAT-001
```

only as model evidence.

## Non-Claims

This is not Linux implementation, hook approval, task field approval, async
carrier approval, endpoint implementation, device implementation, budget
implementation, ABI approval, runtime coverage, monitor verification, behavior
change, or production protection.
