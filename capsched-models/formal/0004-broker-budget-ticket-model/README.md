# Formal 0004: Broker BudgetTicket Model

Status: Checked by TLC in tiny finite model

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This model captures the minimum service/broker execution rule needed by
CapSched:

```text
No caller budget, no broker/service execution on behalf of that caller.
```

It extends the Endpoint Async model by making `BudgetTicket` explicit. The
model checks that service Domains cannot execute caller work using only ambient
service authority, and that caller budget cannot be overspent, double-spent, or
reused after completion/cancellation.

## Files

```text
BrokerBudget.tla
BrokerBudget.cfg
notes.md
```

## Core Idea

The model separates:

```text
CallerBudget:
  budget owned by the calling Domain.

BudgetTicket:
  reserved caller budget attached to one broker request.

FrozenBrokerUse:
  caller, endpoint operation, service Domain, caller epoch, and service epoch
  frozen for one request.

ServiceBudget:
  service-side execution capacity. This models the service's own scheduling or
  rate limit and prevents "caller ticket exists" from implying unlimited
  service execution.
```

Effective broker execution requires:

```text
BudgetTicket
AND FrozenBrokerUse
AND ServiceAllows(endpoint operation)
AND ServiceBudget
```

## Encoded Safety Properties

```text
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

## Expected Validation

Run from this directory:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC BrokerBudget.tla
```

The configuration intentionally uses a tiny finite model:

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

## Design Questions This Model Pressures

1. Budget donation should reserve caller budget at ticket issuance, not at an
   arbitrary later worker execution point.
2. Service authority alone is insufficient; the request must also carry caller
   authority and a live ticket.
3. Caller epoch revocation cancels outstanding tickets and forfeits unspent
   reserved budget in this strict model.
4. Service epoch revocation cancels outstanding work and refunds unspent caller
   budget.
5. If Linux chooses different refund/forfeit behavior, it must be stated as a
   deliberate policy and modeled explicitly.
