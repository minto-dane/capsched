# Notes: Broker BudgetTicket Model

Date: 2026-06-26

## Claim Being Modeled

The model pressures one narrow but important CapSched rule:

```text
No caller budget, no broker/service execution on behalf of that caller.
```

This is not only accounting. In CapSched, `BudgetTicket` is part of the
authority required to execute delegated work. A service Domain may hold its own
service authority, but that authority alone is insufficient to run work for a
caller.

## Modeled Objects

```text
CallerBudget:
  Budget owned by a caller Domain.

BudgetTicket:
  Reserved caller budget bound to exactly one request.

FrozenBrokerUse:
  Caller Domain, caller epoch, service Domain, service epoch, endpoint, and
  operation frozen for one broker request.

ServiceBudget:
  Service-side execution capacity. This prevents caller ticket existence from
  becoming unlimited service execution.
```

The effective authority for service execution is modeled as:

```text
BudgetTicket
AND FrozenBrokerUse
AND caller endpoint authority
AND service endpoint authority
AND live caller epoch
AND live service epoch
AND available service budget
```

## Why Reserve at Submission

The model reserves caller budget when a broker request is submitted, not when a
worker later executes it. This removes an important ambiguity:

```text
submit now, charge later
```

would allow a Domain to queue more outstanding delegated work than its current
budget can cover. That creates a DoS and confused-deputy surface where the
service has to remember, re-check, or reject caller budget at a later and more
complex point.

Reservation at submission gives the model a simple conservation law:

```text
callerBudget + spent + forfeited + outstandingTicketRemaining
  = MaxCallerBudget
```

That conservation law is what lets the model distinguish:

- budget that was never reserved,
- budget reserved but not yet consumed,
- budget consumed by service execution,
- budget intentionally forfeited by caller epoch revocation.

## Revocation Semantics

This model chooses strict caller revocation:

```text
caller epoch revoke:
  cancel outstanding caller work
  clear frozen authority
  forfeit unspent reserved ticket budget
```

That is deliberately severe. It keeps caller revocation monotonic and avoids
revocation becoming a budget-refund oracle. Linux L0 could later choose refund
semantics for some classes of cancellation, but that would need to be modeled
explicitly.

Service epoch revocation is different:

```text
service epoch revoke:
  cancel outstanding service work
  clear frozen authority
  refund unspent caller ticket budget
```

The reason is responsibility: if the service authority disappeared, the caller
did not voluntarily revoke its own identity. Refunding unspent caller budget is
the safer default for this tiny model.

## Security Meaning

The model separates three failure modes that can otherwise collapse into one:

```text
No ticket:
  service has no caller-donated execution budget.

No frozen use:
  service has no caller-authorized endpoint operation.

Stale epoch:
  previously authorized work is no longer live authority.
```

This is the shape we want in Linux too. A future `capsched_work_ctx`,
`io_kiocb`, or broker request must not be able to say only "a service is running
this". It must also carry whose authority is being used, which operation was
frozen, which epochs were live, and how much caller budget can still be spent.

## Linux Implications

The model suggests these implementation constraints without deciding exact patch
points yet:

1. Broker or service work needs an explicit `BudgetTicket`-like object, not just
   an inherited `current` or credential snapshot.
2. Ticket issuance should reserve caller budget before work becomes visible to
   a service queue.
3. Service execution should charge both caller ticket budget and service-side
   budget or rate limits.
4. Caller epoch revocation must invalidate outstanding broker work before it can
   execute again.
5. Service epoch revocation must invalidate outstanding work for that service,
   even if the caller budget is still live.
6. A generic workqueue item cannot be sufficient authority for Domain-derived
   delegated work; it needs a CapSched wrapper or a typed request object.

## What This Does Not Prove

This is a tiny finite TLA+ model. It does not prove:

- Linux locking correctness,
- RCU lifetime safety,
- exact scheduler integration,
- side-channel isolation,
- memory view isolation,
- IOMMU or device queue ownership,
- liveness or fairness,
- correctness under arbitrary kernel memory corruption.

It only validates the modeled safety properties for the finite state space in
`BrokerBudget.cfg`.
