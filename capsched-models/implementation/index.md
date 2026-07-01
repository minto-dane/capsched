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
- `0013-combined-async-adapter-precondition-gate.md`
  - Status: proposed implementation-facing gate, no Linux patch approved yet.
  - Purpose: reconcile the shared async-carrier core with the dedicated
    workqueue and io_uring refinement models before any candidate Linux async
    carrier patch proposal.
- `0014-linux-async-carrier-candidate-patch-plan.md`
  - Status: candidate patch plan only, no Linux patch approved yet.
  - Purpose: define the only next Linux async-carrier work that may be
    considered: no Linux patch, or a separately reviewed no-behavior opaque
    type scaffolding proposal; behavior-changing workqueue/io_uring hooks
    remain blocked.

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
- `formal/0059-direct-call-async-carrier-api-sketch-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: the N-125 async carrier API sketch requires side effects after
    revoke_check and validate, immutable frozen/bind tuples, no second-caller
    coalescing leak, at-most-once settlement, release separated from Linux
    object cleanup, no CQE settlement proof, no reissue receipt refresh,
    set-based authority intersection, no Linux object authority, and no
    ABI/runtime/monitor/protection overclaims.
- `formal/0060-direct-call-workqueue-adapter-refinement-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: workqueue publication, queue_work false, delayed retime,
    self-requeue, rescuer, cancel/flush, pending clear, caller budget, and
    Linux work lifetime must not collapse into authority.
- `formal/0061-direct-call-io-uring-adapter-refinement-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: SQE consume, resource generation, inline/io-wq issue, reissue,
    cancel, CQE, linked requests, resource update, and uring_cmd must not
    collapse into authority.
- `formal/0062-combined-async-adapter-precondition-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: N-126 alone is not enough for a Linux candidate patch proposal;
    both N-127 workqueue and N-128 io_uring adapter refinements plus evidence
    split are required.
- `formal/0063-linux-async-carrier-patch-scope-model/`
  - Status: checked with safe pass and expected unsafe counterexamples.
  - Pressure: a candidate patch plan is not Linux patch approval; workqueue
    hooks, io_uring hooks, callable prototypes, object layout, runtime state,
    ABI, behavior change, monitor verification, and protection claims remain
    rejected.

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
  intersection, and workqueue delayed-work/self-requeue choices. formal/0059
  and validation/0097 check this first transition-ordering gate. formal/0060
  plus validation/0098 split the workqueue adapter internals. formal/0061 plus
  validation/0099 split the io_uring adapter internals. implementation/0013,
  formal/0062, and validation/0100 now add a combined precondition gate before
  any candidate Linux async-carrier patch proposal.

Current blocker to behavior-changing Linux patches:
  validation/0080 through validation/0100 improve traceability and
  model/source-map the gap-closure, receipt-schema, receipt-consumer,
  placement, async-carrier, source-map, lifetime, gate, API-direction, API
  sketch, adapter-refinement, and combined-precondition artifacts, but they are
  not Linux stub implementation, monitor
  verification, ABI approval, runtime coverage, behavior-change approval, or
  production protection evidence.

Current Linux async-carrier patch decision:
  analysis/0086, formal/0064, and validation/0102 now make N-131 a negative
  maintenance gate. No new Linux async-carrier patch is approved now, including
  no-behavior opaque async-carrier names. The current fetched upstream review
  saw 340 commits since the L0 base, only nearby non-intersecting watched-path
  drift in kernel/sched/cpufreq_schedutil.c, and a clean merge-tree result, but
  this is not enough to justify new Linux names without a concrete consumer.
  The next implementation-facing work is source-drift automation and a
  model-freshness gate, not a C declaration.

Current upstream-following gate:
  analysis/0087, validation/run-linux-source-drift-gate.sh, formal/0065, and
  validation/0103 now provide the reusable source-drift/model-freshness gate.
  The current run observed 340 upstream commits since the L0 base, one
  non-stale watched change in kernel/sched/cpufreq_schedutil.c, no model
  refresh requirement, a clean merge-tree, and no Linux patch approval. This is
  the gate to rerun before source-map refreshes or any future patch proposal.

Current source-map refresh target:
  analysis/0088, formal/0066, and validation/0104 select
  scheduler_authority_core as the next source-only refresh target. This is not
  Linux patch approval. The refresh should update analysis/0025, analysis/0026,
  analysis/0028, and the formal/0012 mapping before any scheduler authority
  patch movement.

Current scheduler authority refresh:
  analysis/0025, analysis/0026, analysis/0028, formal/0012 README,
  linux-scheduler-authority-core-refresh-v1.json, and validation/0105 now
  refresh scheduler_authority_core against upstream
  665159e246749578d4e4bfe106ee3b74edcdab18. The existing formal/0012 model was
  rechecked with 126113 generated states, 17344 distinct states, and depth 21.
  No scheduler authority patch is approved. The next implementation-facing
  pressure is model decomposition around donor/current budget charging,
  TASK_WAKING failure boundary, and selected-state class retry semantics.

Current scheduler authority refinement gate:
  analysis/0089, formal/0067, scheduler-authority-refinement-gate-v1.json, and
  validation/0106 now decompose that pressure into a blocking model gate. Safe
  TLC passed with 18 generated states, 14 distinct states, and depth 7. Unsafe
  configs produced expected counterexamples for TASK_WAKING before freeze,
  current-only proxy budget, run after retry, and run without class settlement.
  No scheduler authority patch is approved. The next implementation-facing
  pressure is trace-only runtime coverage for current/donor/proxy paths and F1
  admission-freeze data dependency refresh against current upstream.

Current runtime charge subject gate:
  analysis/0090, formal/0068, runtime-charge-subject-v1.json, and
  validation/0107 now make NoUnspecifiedRuntimeCharge an explicit budget gate.
  Safe TLC passed with 79 generated states, 48 distinct states, and depth 4.
  Unsafe configs produced expected counterexamples for unspecified runtime
  charge, class runtime as root authority, proxy runtime without ticket, remote
  tick proxy authority, task_sched_runtime as authority, and CFS proxy without
  donor/cgroup charge. No budget hook or scheduler authority patch is approved.

Current scheduler server-ticket gate:
  analysis/0091, formal/0069, scheduler-server-ticket-v1.json, and
  validation/0108 now model fair/ext/DL server borrow tickets and class runtime
  non-authority. Safe TLC passed with 39 generated states, 24 distinct states,
  and depth 6. Unsafe configs produced expected counterexamples for server
  pick without ticket, server runtime as root authority, RT bandwidth as root
  authority, SCX slice as root authority, server replenish without epoch,
  server stop with live ticket, and lower task without authority. No scheduler
  hook, budget hook, or behavior-changing patch is approved.

Current runtime coverage gate:
  analysis/0092, formal/0070, runtime-coverage-gate-v1.json, and
  validation/0109 now define the trace-only coverage contract for
  current/donor/proxy/server runtime paths. Safe TLC passed with 49 generated
  states, 29 distinct states, and depth 6. Unsafe configs produced expected
  counterexamples for missing current, missing donor, missing proxy relation,
  missing server coverage, missing evidence class, sched_stat_runtime as
  authority, remote tick as proxy coverage, trace evidence as protection,
  server lifecycle-only coverage, and class runtime as root budget evidence.
  No tracefs execution, tracepoint, public ABI, budget hook, scheduler hook,
  runtime coverage result, monitor verification, behavior change, or production
  protection is approved.

Current monitor root budget timer gate:
  analysis/0093, formal/0071, monitor-root-budget-timer-v1.json, and
  validation/0110 now define the semantic root for production CPU budget
  enforcement. Safe TLC passed with 78 generated states, 37 distinct states,
  and depth 7. Unsafe configs produced expected counterexamples for running
  without a monitor timer, running without root budget, Linux timer as root
  authority, overrun after budget expiry, Linux charge as monitor charge,
  activation without sealed token, running after epoch revoke, running after
  monitor interrupt, NO_HZ stopping the monitor timer, and protection claim
  without implementation. No monitor timer implementation, Linux hook, budget
  hook, scheduler hook, ABI, runtime test, behavior change, or production
  protection is approved.

Current server epoch relation gate:
  analysis/0094, formal/0072, server-epoch-relation-v1.json, and
  validation/0111 now refine N-137 so fair/ext/DL server lifecycle changes
  cannot extend stale ServerBorrowTicket authority. Safe TLC passed with 107
  generated states, 32 distinct states, and depth 6. Unsafe configs produced
  expected counterexamples for stale ticket after replenish, ticket surviving
  server swap, server-kind mismatch after swap, ticket surviving stop, pick
  without fresh ticket, lower task without authority, Linux runtime as
  authority, parameter update keeping a ticket, CPU teardown keeping a running
  ticket, and protection claim without implementation. No server-epoch field,
  scheduler hook, budget hook, tracepoint ABI, behavior change, or production
  protection is approved.

Current deadline CBS/GRUB compatibility gate:
  analysis/0095, formal/0073, deadline-cbs-grub-compat-v1.json, and
  validation/0112 now model Linux SCHED_DEADLINE admission, CBS runtime and
  replenishment, GRUB reclaim, inactive timers, dynamic sched_getattr, and
  overrun notification as compatibility policy or observation surfaces rather
  than CapSched authority. Safe TLC passed with 70 generated states, 27
  distinct states, and depth 10. Unsafe configs produced expected
  counterexamples for admission minting run authority, CBS replenish minting
  run authority, GRUB minting monitor budget, DL runtime as monitor budget,
  inactive timer authority, dynamic sched_getattr authority, overrun
  notification as enforcement, run without DL admission, run while
  CBS-throttled, and protection claim without implementation. No deadline hook,
  scheduler hook, budget hook, ABI change, tracepoint ABI, behavior change, or
  production protection is approved.

Current F1 admission-freeze refresh gate:
  analysis/0096, formal/0074, f1-admission-freeze-refresh-v1.json, and
  validation/0113 now refresh the wake publication boundary against current
  upstream. Safe TLC passed with 44 generated states, 24 distinct states, and
  depth 7. Unsafe configs produced expected counterexamples for TASK_WAKING
  before freeze, wake_list before freeze, enqueue before freeze, running with
  missing generation, Domain epoch, SchedContext, placement, or root budget,
  raw cap handles after publication, heavy lookup after publication, late
  denial that loses a wakeup, placement-as-authority, current continuation
  mint, fork ambient authority, and protection claim without implementation.
  No F1 hook, scheduler hook, task field, ABI, monitor ABI, tracepoint ABI,
  behavior change, runtime coverage, monitor verification, or production
  protection is approved.
```
