# Implementation Index

Updated: 2026-06-30

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
  no-code trace run plan using existing scheduler tracepoints and dynamic
  ftrace before any Slice 0C Linux patch
```
