# Plan 0005: Assurance-Driven Achievement Plan

Status: Active

Date: 2026-06-26

## Purpose

This plan updates the older roadmap after the first major semantic models have
been checked. It answers the practical question:

```text
What should we do next to make the actual CapSched-H goal more true?
```

The answer is to advance implementation only where the evidence supports it,
and in parallel build an explicit assurance case that prevents local progress
from drifting away from the final goal.

## Current Position

Already available:

```text
Linux source:
  upstream fetched
  capsched-linux-l0 branch
  Slice 0A inert CONFIG_CAPSCHED scaffolding committed and build-validated

Formal evidence:
  RunnableLease
  EndpointAsync
  BrokerBudget
  DomainMonitor
  Cluster authority decomposition
  MemoryOwnership decomposition
  DirectMapTLB
  PageCacheOverlay
  QueueLease
```

Not available:

```text
behavior-changing Linux scheduler hooks
task_struct attachment
async provenance implementation
endpoint enforcement implementation
monitor implementation
per-Domain mutable kernel state implementation
device-specific QueueLease endpoint implementation
performance evidence
exploit-containment evidence
```

## Strategy

Use three synchronized loops.

### Loop 1: Vocabulary Without Behavior

Purpose:

```text
create stable names for authority objects without changing Linux semantics
```

Next patch:

```text
Slice 0B:
  include/linux/capsched.h
  kernel/sched/capsched.c
```

Allowed:

```text
opaque forward declarations
typedefs for ids and epochs
comments preserving non-claim boundaries
maybe capsched_enabled()
```

Forbidden:

```text
task_struct fields
enqueue/pick/tick hooks
workqueue/io_uring/socket/VFS/MM/device changes
user ABI
monitor-backed claim
generic universal capability object
```

Exit evidence:

```text
CONFIG_CAPSCHED=n build still excludes capsched.o
CONFIG_CAPSCHED=y build still includes capsched.o
only allowed files changed
static review confirms no behavior or security claim
```

### Loop 2: Assurance Case

Purpose:

```text
turn models and patches into a defensible chain of claims
```

Deliverables:

```text
assurance top-level claim
subclaim tree
evidence index
counterexample log
forbidden-claim list
gap list
per-gate exit criteria
```

Exit evidence:

```text
every model maps to at least one claim
every Linux patch maps to one gate
every forbidden claim is visible in handoff/state
```

### Loop 3: Trace Before Enforcement

Purpose:

```text
observe real Linux behavior before deciding enforcement hooks
```

Candidate after Slice 0B:

```text
Slice 0C:
  trace-only or debug-only Domain shadow identity instrumentation
  no scheduling decision changes
  no endpoint checks
  no user ABI unless explicitly scoped as debug/test-only
```

Exit evidence:

```text
boot/build validation
trace output sanity
no measurable disabled-config impact
no security claim
```

## Why Not Behavior Yet

Behavior-changing scheduler hooks now would be premature because the hardest
Linux integration questions are still open:

```text
wakeup path coverage
already-runnable task handling
migration and remote wake interactions
class-specific runtime accounting
fork/exec/exit generation policy
proxy execution and rq donor semantics
async provenance attachment
user ABI and issuer policy
```

The models justify names and constraints. They do not yet justify modifying the
scheduler fast path.

## Near-Term Sequence

1. Update Slice 0B gate with memory and QueueLease evidence.
2. Apply Slice 0B type-only scaffolding.
3. Build-validate CONFIG_CAPSCHED=n/y.
4. Create an assurance-case index.
5. Select Slice 0C trace-only instrumentation or a narrower scheduler source
   read focused on wakeup/enqueue coverage.

## Medium-Term Sequence

After Slice 0B and assurance indexing:

```text
L0 trace-only:
  Domain shadow identity and transition observations

L0 runnable prototype:
  FrozenRunUse and SchedContext in controlled test path

L1 provenance:
  workqueue/task_work/io_uring carriers

L2 state:
  page owner shadow, page-cache overlay prototype, service-domain boundaries

L3 monitor:
  RunToken, MemoryView, root budget, epoch, page ownership

L4 device:
  typed QueueLease endpoint and monitor-owned IOMMU/IRQ route

L5 evaluation:
  exploit containment, VM comparison, performance/cost evidence
```

## Decision Rule

When in doubt, choose the move that improves the final assurance case without
inflating the claimed security boundary.

Good moves:

```text
make authority types more explicit
record counterexamples
add validation gates
preserve Linux compatibility
separate policy frontend from authority root
separate prototype claims from production claims
```

Bad moves:

```text
add behavior without a model
claim isolation in Linux-only L0
combine capability types for convenience
let Linux mutable state be production authority
add user ABI before issuer/revocation semantics are modeled
touch devices/MM/VFS without endpoint-specific gates
```
