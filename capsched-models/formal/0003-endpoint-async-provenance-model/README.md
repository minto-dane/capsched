# Formal 0003: Endpoint Async Provenance Model

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This is the second executable semantic model for CapSched. It models the
minimal async endpoint authority flow that appears in sockets, workqueue, and
io_uring:

```text
registered resource
-> submitted request
-> queued async work
-> worker execution
-> completion
```

The model intentionally does not model full io_uring, full VFS/socket
semantics, protocol stacks, DMA, monitor page ownership, or Linux scheduler
fairness. It pressures one central question:

```text
Can async execution proceed after the originating task context disappears
without losing caller provenance and endpoint authority?
```

## Files

```text
EndpointAsync.tla
EndpointAsync.cfg
notes.md
```

## Core Idea

The model separates:

```text
RegisteredEndpoint:
  resource captured from an fd/socket-like endpoint at registration time.

FrozenEndpointUse:
  per-request authority frozen at submission time.

WorkerServiceAuthority:
  service or worker authority needed to execute async work.

BudgetTicket:
  bounded caller-supplied execution budget for service/worker execution.

LinuxCred:
  subjective Linux credential override. This may change operation credentials,
  but it must not change DomainTag or frozen endpoint authority.
```

Effective async authority is modeled as:

```text
FrozenEndpointUse ∩ WorkerServiceAuthority ∩ BudgetTicket
```

## Encoded Safety Properties

```text
NoPendingRequestWithoutAuthority
NoExecutionWithoutFrozenEndpointUse
NoExecutionWithStaleDomainEpoch
NoExecutionWithStaleResourceGeneration
NoExecutionWithoutBudgetTicket
NoWorkerAmbientAuthority
NoCredentialOverrideChangesActiveDomain
NoWorkerUsesOtherDomainEndpoint
NoTwoWorkersForOneRequest
NoCancelledRequestOnWorker
```

## Expected Validation

Run from this directory:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC EndpointAsync.tla
```

The configuration intentionally uses a tiny finite model:

```text
2 domains
2 tasks
2 endpoints
2 resources
2 requests
2 workers
3 operations: send, recv, cmd
epochs: 0..1
resource generations: 0..1
ticket: 0..1
```

## Design Questions This Model Pressures

1. Registered resources are not sufficient authority. Every request must derive
   a `FrozenEndpointUse` before it can be queued or executed.
2. Worker identity is not caller identity. Worker execution must require both
   frozen caller authority and service authority for the endpoint operation.
3. Linux credential override must not silently change DomainTag, endpoint
   generation, Domain epoch, or service budget.
4. Domain or resource revocation must cancel or invalidate pending async work;
   otherwise stale requests can execute after their authority changed.
5. `RunCap` remains out of scope. This model is about endpoint authority after
   a task is already allowed to submit work.
