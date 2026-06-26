# Validation 0006: Broker BudgetTicket TLC Check

Status: Passed for tiny finite model

Date: 2026-06-26

## Scope

Formal model:

```text
capsched/capsched-models/formal/0004-broker-budget-ticket-model/
```

This validation checks the `BrokerBudget.tla` model with TLC. The model is a
small finite state machine for caller budget donation to broker/service
execution.

## Command

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0004-broker-budget-ticket-model
```

Command:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC BrokerBudget.tla
```

## Configuration

```text
2 caller Domains
2 service Domains
2 endpoints
2 requests
2 operations
caller budget: 0..2
service budget: 0..2
epochs: 0..1
```

Config file:

```text
BrokerBudget.cfg
```

## Checked Invariants

```text
TypeOK
NoServiceExecutionWithoutTicket
NoServiceExecutionWithoutFrozenUse
NoExecutionWithStaleCallerEpoch
NoExecutionWithStaleServiceEpoch
NoServiceAmbientAuthority
NoConfusedDeputyExecution
NoBudgetUnderflow
CallerBudgetConserved
NoTicketReuseAfterTerminalState
NoTwoServicesForOneRequest
NoCancelledRequestActive
```

## TLC Result

```text
TLC2 Version 2.19 of 08 August 2024
Model checking completed. No error has been found.
129777 states generated
25008 distinct states found
0 states left on queue
complete state graph depth: 17
finished in 03s
```

## Interpretation

For this finite model, TLC found no counterexample to the core broker budget
claim:

```text
No caller budget, no broker/service execution on behalf of that caller.
```

The model also reinforces:

```text
Service authority alone is not sufficient.
Frozen caller endpoint authority is required.
Caller and service epochs must both be live.
Outstanding ticket budget is conserved across submit, execute, cancel, and
revocation transitions.
```

## Limits

This validation does not prove Linux implementation correctness. It does not
cover RCU, locking, workqueue lifetime rules, actual io_uring or socket paths,
monitor-backed MemoryViews, IOMMU ownership, or hostile kernel memory
corruption. It is a semantic gate for the budget-donation rule only.
