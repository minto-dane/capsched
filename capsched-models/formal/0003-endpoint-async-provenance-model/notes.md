# Notes: Endpoint Async Provenance Model

Date: 2026-06-26

## Scope

This model deliberately covers a narrow async pattern:

```text
register endpoint/resource
submit typed operation
queue async work
execute on worker
complete
```

It represents sockets, io_uring fixed resources, and workqueue-like worker
execution at the semantic level. It does not model full Linux object lifetimes,
fdtable sharing, protocol-specific socket behavior, SQPOLL details, or memory
pinning.

## Main Separation

The model separates three authorities:

```text
RegisteredEndpoint:
  proves that a resource was captured from a domain-owned endpoint.

FrozenEndpointUse:
  proves that a concrete request operation was frozen with current domain epoch
  and resource generation.

WorkerServiceAuthority:
  proves that the selected worker/service domain may execute that endpoint
  operation.
```

This is the async analogue of the Runnable Lease separation:

```text
RunCap -> FrozenRunUse -> CPU execution

EndpointCap -> FrozenEndpointUse -> worker/service execution
```

## Important Design Result

Registration is not execution authority.

A registered file/socket/resource can outlive the syscall that created it, so
every request must derive a `FrozenEndpointUse`. This is especially important
for io_uring fixed files and registered buffers.

## Credential Override

The model allows Linux credential override as `credDomain`, but worker
activation uses:

```text
activeDomain = frozenUse.domain
```

This encodes the rule:

```text
Linux credentials may affect DAC/LSM policy.
Linux credentials must not silently change CapSched DomainTag.
```

In implementation terms, io_uring personality or SQPOLL credentials are policy
inputs, not Domain authority roots.

## Revocation

This model uses eager revocation:

```text
RevokeDomain:
  increments domain epoch
  cancels pending/executing requests for that domain
  clears registered and frozen endpoint authority
  clears worker references

RevokeResource:
  increments resource generation
  cancels pending/executing requests using that resource
  clears registered and frozen endpoint authority
  clears worker references
```

This matches the strict choice made by the Runnable Lease model. A future Linux
implementation could choose lazy revocation, but then the invariants would need
to change to require pick/execute-time rejection rather than queue cleanup.

## Worker Authority

Worker execution requires:

```text
ValidFrozenUse(request)
ServiceAllows(worker.service_domain, endpoint, op)
ticketLeft(request) > 0
```

This prevents a generic worker from becoming a confused deputy. The worker's
ambient service identity is not enough, and the caller's frozen authority is not
enough by itself.

## Design Pressure for Linux

Likely future implementation objects:

```c
struct capsched_endpoint_use {
        u64 caller_domain;
        u64 caller_epoch;
        u64 endpoint_id;
        u64 endpoint_generation;
        u32 op;
        struct capsched_budget_ticket *ticket;
        struct capsched_domain *service_domain;
};

struct capsched_work_ctx {
        struct capsched_endpoint_use frozen;
        struct capsched_domain *service_domain;
};
```

The exact Linux patch point is not chosen by this model. Candidate attachment
points remain:

```text
io_uring request object
io_uring registered resource node
workqueue wrapper for Domain-derived work
socket operation frozen-use wrapper
task_work callback provenance wrapper
```

## Limitations

This model does not prove:

```text
correct Linux integration
full socket security
buffer/page ownership
IOMMU or DMA isolation
monitor-backed non-forgeability
RunCap scheduler enforcement
```

It only checks a small async authority state machine.
