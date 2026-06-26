# Validation 0005: Endpoint Async Provenance TLC Check

Status: Passed for tiny finite model

Date: 2026-06-26

Model:

```text
capsched/capsched-models/formal/0003-endpoint-async-provenance-model/EndpointAsync.tla
capsched/capsched-models/formal/0003-endpoint-async-provenance-model/EndpointAsync.cfg
```

Tool:

```text
TLC2 Version 2.19 of 08 August 2024
java: /usr/bin/java
tla2tools.jar: /home/nia/tools/tla/tla2tools.jar
```

Command:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC EndpointAsync.tla
```

Working directory:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0003-endpoint-async-provenance-model
```

## Result

TLC completed without invariant errors.

Summary:

```text
291297 states generated
37392 distinct states found
0 states left on queue
complete graph depth: 17
no error found
```

Fingerprint risk estimate reported by TLC:

```text
optimistic: 5.1E-10
actual fingerprints: 1.4E-9
```

## Checked Invariants

The run checked:

```text
TypeOK
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

## Deadlock Handling

`CHECK_DEADLOCK FALSE` is set in `EndpointAsync.cfg`.

Reason: the model has valid terminal states, including all requests completed,
cancelled, or made unable to proceed by exhausted finite epochs/generations.
This is a safety check, not a liveness proof.

## Scope

Tiny finite configuration:

```text
2 domains
2 tasks
2 endpoints
2 resources
2 requests
2 workers
3 endpoint operations: send, recv, cmd
epochs: 0..1
resource generations: 0..1
budget ticket: 0..1
```

## Interpretation

This validates only the modeled async endpoint authority story:

```text
registered resources are not enough to execute async work
each request must freeze endpoint authority before queue/worker execution
worker execution requires both caller frozen authority and service authority
worker execution requires a caller budget ticket
Linux credential override does not change active CapSched DomainTag
domain or resource revocation eagerly cancels pending/executing async work
```

This is not evidence of Linux implementation correctness and not evidence of
hypervisor-grade isolation.

## Design Pressure Found

The model reinforces a strict rule:

```text
No FrozenEndpointUse, no async execution.
```

It also argues that future Linux implementation should avoid treating
io_uring fixed files, socket fds, workqueue callbacks, or task_work callbacks as
ambient authority. They need explicit frozen authority and provenance.

The next design step is to connect this model back to concrete Linux objects:

```text
io_kiocb
io_rsrc_node
work_struct or a CapSched work wrapper
socket/file endpoint wrappers
task_work callbacks
```
