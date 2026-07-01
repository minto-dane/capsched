# Implementation Index

Updated: 2026-07-01

No behavior-changing implementation patch points are accepted yet.

Candidate implementation plans:

- `0001-l0-runnable-lease-implementation-plan.md`
  - Status: candidate plan, not accepted patch points.
  - Purpose: derive Linux L0 scaffolding and validation sequence from the
    checked Runnable Lease TLA+ model and upstream source maps.
- `0002-l0-slice0-scaffolding-plan.md`
  - Status: applied to Linux as commit
    `0b685979f27b3d42ee620ced5f707ee391a2a27f`.
  - Purpose: narrow the first patch to inert `CONFIG_CAPSCHED` build
    scaffolding with no task layout or scheduler behavior changes.
- `0003-endpoint-async-attachment-plan.md`
  - Status: candidate plan, not accepted patch points.
  - Purpose: derive endpoint/async attachment pressure from the checked
    Endpoint Async Provenance model and Linux io_uring/workqueue/socket source
    reading.
- `0004-slice0b-readiness-gate.md`
  - Status: gate applied by Slice 0B.
  - Purpose: integrate the checked RunnableLease, EndpointAsync, BrokerBudget,
    DomainMonitor, and decomposed cluster authority models into the
    acceptance criteria for a possible type-only Slice 0B patch.
- `0005-l0-slice0b-type-scaffolding.md`
  - Status: applied to Linux as commit
    `7cf0b1e415bcead8a2079c8be94a9d41aad7d462`.
  - Purpose: add type-only authority names in `include/linux/capsched.h` and
    inert documentation in `kernel/sched/capsched.c` with no behavior change.
- `0006-slice0c-trace-observation-gate.md`
  - Status: proposed gate, no Linux patch approved yet.
  - Purpose: define a strict trace-only observation gate tied to assurance
    claims `EXEC-001`, `COMPAT-001`, and gate `G2`, using analysis `0019`.
- `0007-modern-nic-hypertag-readiness-gate.md`
  - Status: proposed gate, no Linux patch approved yet.
  - Purpose: define the observation-only probe and inert-stub gate for the
    monitor-backed modern NIC path before any behavior-changing QueueLease,
    DMA, IRQ, VF, representor, offload, or service-work enforcement.
- `0008-direct-call-attachment-readiness-gate.md`
  - Status: proposed gate, no Linux patch approved yet.
  - Purpose: define the no-code Linux/monitor attachment-readiness gate before
    any direct-call carrier, monitor implementation, binary ABI, public
    tracepoint ABI, user ABI, or production protection claim.
- `0009-direct-call-gap-closure-gate.md`
  - Status: proposed implementation-facing gate, no Linux patch approved yet.
  - Purpose: translate the DirectCallGapClosure model into required future
    Linux/monitor anchors, receipts, forbidden fallbacks, and validation
    evidence before any direct-call stub or ABI patch.
- `0010-direct-call-receipt-consumer-placement-gate.md`
  - Status: proposed implementation-facing gate, no Linux patch approved yet.
  - Purpose: translate the DirectCallReceiptConsumerPlacement model into
    receipt provenance, hot-path bounded-consumption, policy/lifecycle,
    generic async exclusion, future-gap, revoke/shadow, and evidence-class
    preconditions before any direct-call carrier patch.
- `0011-direct-call-async-carrier-gate.md`
  - Status: proposed implementation-facing gate, no Linux patch approved yet.
  - Purpose: translate the DirectCallAsyncCarrier model into typed carrier,
    pending coalescing, caller BudgetTicket, service/caller intersection,
    monitor receipt provenance, revoke/stale-carrier, workqueue, io_uring, and
    evidence-class preconditions before any async direct-call receipt carrier
    patch.
- `0012-direct-call-async-carrier-api-sketch.md`
  - Status: proposed no-behavior API sketch, no Linux patch approved yet.
  - Purpose: define a narrow internal `capsched_async_carrier` semantic core
    with freeze, bind, validate, revoke_check, settle, and release operations,
    plus separate workqueue and io_uring adapter contracts before any Linux
    code proposal.

Validated formal inputs:

- `formal/0002-runnable-lease-model/`
  - Status: checked with TLC.
  - Pressure: `RunCap -> FrozenRunUse -> CPU execution`.
- `formal/0003-endpoint-async-provenance-model/`
  - Status: checked with TLC.
  - Pressure: `EndpointCap -> FrozenEndpointUse -> async worker execution`.
- `formal/0004-broker-budget-ticket-model/`
  - Status: checked with TLC.
  - Pressure: caller-reserved `BudgetTicket` plus frozen broker use is required
    for service execution on caller behalf.
- `formal/0005-domain-monitor-activation-model/`
  - Status: checked with TLC.
  - Pressure: Linux-visible DomainTag shadow state is not execution authority
    without monitor-owned activation.
- `formal/0006-cluster-lease-compilation-model/`
  - Status: full integration stress TLC stopped before completion after state
    explosion; not a pass.
  - Pressure: cluster authority must compile into node-local authority before
    local execution or endpoint use.
- `formal/0007-cluster-authority-decomposition-model/`
  - Status: checked with TLC.
  - Pressure: forged local shadow claims are not authority, and stale cluster
    epochs cannot remain executable.
- `formal/0008-memory-ownership-model/`
  - Status: checked via decomposed TLC models; broad integration stress model
    stopped before completion and is not a pass.
  - Pressure: Linux page/slab/memcg/page-cache shadow metadata is not memory
    authority; monitor-owned PageOwner, MemoryView, object generation, and
    memory work provenance are required.
- `formal/0009-direct-map-tlb-model/`
  - Status: checked with TLC after a counterexample-driven fix.
  - Pressure: monitor PageOwner and MemoryView are not enough if stale direct
    map or TLB translations survive; Domain activation must flush or retag
    translations, and page revoke cannot finish while translations remain.
- `formal/0010-page-cache-overlay-model/`
  - Status: checked with TLC after a counterexample-driven fix.
  - Pressure: sealed shared bases may be shared, but mutable page-cache overlay
    state must be per-Domain and service-mediated; commits require provenance,
    tickets, current base version, and base-level serialization.
- `formal/0011-queue-lease-model/`
  - Status: checked with two TLC runs.
  - Pressure: queue submit, DMA mapping, IRQ delivery, epoch, and budget are
    one lease boundary; Linux shadow queue/IOMMU state is not authority.
- `formal/0053-direct-call-attachment-readiness-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: direct-call readiness must remain observation-only and inert;
    Linux-side probes, stubs, timeouts, shadows, or source rows cannot become
    authority, monitor verification, ABI, behavior change, or protection.
- `formal/0054-direct-call-inventory-contract-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: a direct-call source inventory runner must default to read-only
    source mode and cannot modify Linux, require root, write tracefs, attach
    probes, create public tracepoint ABI, treat observations as authority,
    claim runtime coverage, expose raw handles, claim monitor verification, or
    claim protection.
- `formal/0055-direct-call-gap-closure-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: high-severity direct-call gaps close only through monitor-owned
    request image, replay, schema acceptance, response handle, epoch, and revoke
    ordering; Linux stubs, wrappers, schema queries, timeouts, trace plans, or
    test hooks cannot stand in for those authorities.
- `formal/0056-direct-call-receipt-schema-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: future Linux-facing direct-call surfaces may consume opaque
    monitor receipts and derived shadows, but Linux cannot mint request, schema,
    entry, response, or revoke authority.
- `formal/0057-direct-call-receipt-consumer-placement-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: receipt consumers must keep hot-path checks bounded, separate
    policy/lifecycle request shaping from schema authority, exclude generic
    async worker authority, preserve future gaps, and avoid ABI/runtime/
    monitor/protection overclaims.
- `formal/0058-direct-call-async-carrier-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: Domain-originated async direct-call receipt use requires a typed
    carrier with caller frozen authority, service authority, caller budget
    ticket, and monitor receipt. Generic workqueue authority, pending
    work-struct overwrite, worker identity authority, service-only execution,
    Linux-minted receipt, and consume-after-revoke semantics are rejected.

Known future branch names:

- `capsched-linux-l0`: Linux-only prototype branch.
- `capsched-linux-h`: monitor-backed research branch.

Slice 0A and Slice 0B are applied and build-validated. Slice 0B remains
type-only and does not accept any behavior-changing patch point.

Likely investigation targets, not decisions:

- `include/linux/sched.h`
- `kernel/sched/core.c`
- `kernel/sched/sched.h`
- `kernel/fork.c`
- `fs/exec.c`
- `kernel/exit.c`
- `kernel/workqueue.c`
- `io_uring/`
- cgroup CPU and cpuset code
- core scheduling code
- LSM/security hooks

Current patch recommendation, not yet executed:

```text
Next gate:
  use implementation/0009, analysis/0079, and analysis/0080 as the pre-patch
  gate for any direct-call carrier proposal. implementation/0010 now adds the
  placement gate from formal/0057. formal/0058 adds the typed async carrier
  model required before any generic workqueue or io_uring direct-call receipt
  consumption is allowed. implementation/0011 now translates formal/0058 into
  an implementation-facing no-patch async-carrier gate. ADR-0009 and
  analysis/0083 choose the next no-behavior API sketch direction: a shared
  internal `capsched_async_carrier` semantic core with separate workqueue and
  io_uring adapters. implementation/0012 now sketches that no-behavior API
  contract, including single-assignment frozen fields, core/adapter ownership
  boundaries, exactly-once settlement pressure, workqueue and io_uring adapter
  obligations, and required future model obligations.

Current API-sketch direction:
  The shared core may carry only CapSched authority state: frozen caller
  authority, caller BudgetTicket, opaque monitor receipt reference or derived
  shadow, generation/epoch/revoke state, service/resource binding, and
  settlement/release state. It must not become a generic async execution model,
  public ABI, public tracepoint ABI, monitor verification claim, behavior
  change, or production protection claim. Workqueue and io_uring lifetimes must
  remain separate adapter contracts. The next gate is to model this API sketch,
  especially io_uring request/resource/reissue/CQE state, BudgetTicket/receipt
  settlement, generation/epoch revoke interleavings, set-based authority
  intersection, and workqueue delayed-work/self-requeue choices.

Current blocker to behavior-changing Linux patches:
  validation/0080 through validation/0096 improve traceability and
  model/source-map the gap-closure, receipt-schema, receipt-consumer,
  placement, async-carrier, source-map, lifetime, gate, API-direction, and API
  sketch artifacts, but they are not Linux stub implementation, monitor
  verification, ABI approval, runtime coverage, behavior-change approval, or
  production protection evidence.
```
