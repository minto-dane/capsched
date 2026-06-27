# Analysis 0045: Workqueue Internal Redesign Boundary

Status: Draft design boundary, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related notes:

```text
analysis/0005-async-provenance-risk-map.md
analysis/0015-endpoint-async-linux-attachment-map.md
analysis/0034-workqueue-kthread-budgetticket-carrier.md
analysis/0041-wider-endpoint-capability-semantics.md
analysis/0044-post-exec-resource-trace-coverage-map.md
validation/0040-post-exec-resource-qemu-trace-result.md
```

## Question

Would it be enough to deeply redesign and reimplement only Linux's internal
async machinery, rather than requiring typed CapSched carriers only for
Domain-derived async work?

Short answer:

```text
Yes, deeply redesigning the internal async substrate is likely necessary for
production CapSched-H.

No, "internal redesign only" is not enough if it means generic internal worker
execution becomes a trusted ambient authority path.
```

The distinction matters. The rejected design is not internal redesign. The
rejected design is loss of typed caller provenance.

## Two Source Facts

The current Linux workqueue implementation has two properties that are decisive
for CapSched.

First, queueing an already pending `work_struct` does not create a second
queued operation:

```text
kernel/workqueue.c:2442 queue_work_on(...)
kernel/workqueue.c:2450 test_and_set_bit(WORK_STRUCT_PENDING_BIT, ...)
kernel/workqueue.c:2456 return ret
include/linux/workqueue.h:696 queue_work(...) delegates to queue_work_on()
```

The documented return value is:

```text
false if work was already on a queue, true otherwise
```

Second, execution enters the callback in worker context:

```text
kernel/workqueue.c:3248 worker->current_work = work
kernel/workqueue.c:3249 worker->current_func = work->func
kernel/workqueue.c:3288 set_work_pool_and_clear_pending(...)
kernel/workqueue.c:3322 worker->current_func(work)
```

For `kthread_work`, the equivalent execution shape is:

```text
kernel/kthread.c:1021 worker->current_work = work
kernel/kthread.c:1027 work->func(work)
```

Therefore:

```text
same work_struct + multiple callers => possible merge/coalescing
worker current task => worker/kthread identity, not caller identity
```

## Why Carrier Overwrite Is Unsafe

The dangerous design is:

```text
caller A prepares BudgetTicket A
caller A queues work W
caller B prepares BudgetTicket B
caller B queues the same already-pending work W
queue_work() returns false
caller B overwrites W's CapSched carrier
worker executes W once
```

This loses the semantic identity of the operation. Depending on timing, the
single callback can:

```text
spend caller B's ticket for caller A's request
spend caller A's ticket for caller B's request
merge A and B without an accounting rule
drop one caller's revocation
run after one caller's epoch changed
perform endpoint effects with no unique frozen use
```

The bug is not merely accounting. It is authority laundering.

## Why Worker Identity Is Unsafe

The worker task is a service execution vehicle. It is not the Domain that
caused the operation.

Rejected inference:

```text
current kworker task has some kernel/service authority
therefore callback may perform caller-attributed endpoint effects
```

Safe inference:

```text
worker authority allows the service to execute service code
caller-derived endpoint effects still require caller frozen authority
```

Required authority shape:

```text
effective authority =
  service authority
  intersect caller FrozenEndpointUse
  intersect live BudgetTicket
  intersect caller/service epoch validity
```

## Is Internal Redesign Still Useful?

Yes. For production CapSched-H, a deep internal redesign is probably necessary.
The async substrate eventually should not be "ordinary Linux workqueue plus a
few wrappers." It should be a typed execution substrate with explicit work
classes.

Target class set:

```text
KernelCoreWork:
  audited internal kernel work, no caller-attributed endpoint effect

ServiceMaintenanceWork:
  service Domain authority only, no hidden caller authority

DomainRequestWork:
  one caller-derived operation with caller Domain, caller epoch,
  FrozenEndpointUse, BudgetTicket, service Domain, work generation

MergedDomainBatchWork:
  explicit multi-caller merge with defined admission, budget reservation,
  cancellation, revocation, settlement, and endpoint effect semantics

InterruptDeferredWork:
  interrupt-origin deferred work; may later hand off to service or Domain work
  but must not invent caller authority in interrupt context

ReclaimRescueWork:
  memory-pressure or rescuer work; allowed to preserve system liveness, but not
  allowed to bypass caller ticket requirements for caller-attributed effects

TaskLocalWork:
  task_work-style execution in target task context; still requires generation
  and endpoint checks because task identity alone is not endpoint authority
```

This is an internal redesign, but it preserves typed authority rather than
erasing it.

## Why "Only Internal" Is Not Enough

An internal-only redesign fails if the security argument is:

```text
the kernel internally knows what the work means
therefore no explicit caller capability carrier is needed
```

That is not acceptable under the hostile-Domain threat model. A compromised
Domain may reach kernel bugs in its Domain context. If async execution later
uses global service or worker authority without a caller-derived proof object,
the boundary becomes:

```text
can attacker confuse an internal kernel worker?
```

instead of:

```text
can attacker forge a live Domain-scoped authority object and monitor-protected
budget/epoch?
```

The first is too weak for the desired "process boundary becomes hypervisor
escape class" goal.

## Compatibility Constraint

Linux workqueue coalescing is not accidental. Many subsystems rely on it to
turn repeated signals into one callback:

```text
schedule once
process accumulated state
avoid per-event allocation
avoid unbounded queue growth
support reclaim/rescuer behavior
```

CapSched must not blindly convert every `queue_work()` into a per-caller
operation. That would break performance and sometimes correctness.

Therefore, every converted path needs one of:

```text
PerInvocation:
  allocate one work object and one carrier per caller-derived operation

ExplicitMerge:
  keep coalescing, but define a merge object with a set or aggregate of caller
  tickets, endpoint uses, epochs, and revocation outcomes

ServiceOnly:
  classify as service maintenance and prohibit caller-attributed endpoint
  effects unless a separate DomainRequestWork is created

KernelException:
  audited exception for core kernel liveness paths, with no caller authority
  claim
```

## Correct Production Direction

The production architecture should aim for:

```text
typed async substrate inside Linux
+
Domain-derived work carriers at every Domain boundary
```

Not:

```text
generic workqueue callbacks are trusted because they are internal
```

The internal substrate can hide complexity from normal subsystems, but it
cannot hide authority from the proof model. The proof model must still see:

```text
origin class
caller Domain
caller epoch
program/process generation when relevant
FrozenEndpointUse
BudgetTicket
service Domain
merge policy or per-invocation identity
revocation result
settlement result
```

## Internal-Only Redesign Boundary

It is tempting to say:

```text
if we redesign the internals deeply enough, the async subsystem itself can
become the authority model
```

That is only partly true.

Internal redesign is valuable for:

```text
reducing ad hoc callback shapes
making merge semantics explicit
making service execution budgetable
making cancellation and flush settlement auditable
separating device/service maintenance from caller-derived work
preparing hooks for per-Domain mutable state
```

Internal redesign is not sufficient for:

```text
proving caller authority after work coalescing
protecting against arbitrary Linux kernel execution in one Domain
preventing forged DomainTag, epoch, queue owner, or IOMMU state
turning worker task identity into caller identity
claiming hypervisor-grade separation without monitor-owned roots
```

The safe formulation is therefore:

```text
internal redesign provides a typed substrate
typed carriers/ledgers provide proof-visible caller and resource provenance
the HyperTag Monitor provides the non-forgeable root for production claims
```

## Clarification: Reimplementing The Inside

Reimplementing the internal async machinery is acceptable if "the inside" is
defined as:

```text
typed work classes
explicit merge objects
per-invocation carriers where needed
service-domain worker activation
settlement ledgers
generation and epoch checks
auditable cancel/flush/revoke outcomes
```

It is not acceptable if "the inside" means:

```text
ordinary queue_work() sites continue to submit ambiguous work_struct objects
the async core later infers the caller from worker state or the last queuer
Domain-derived effects run by ambient kworker/service authority
caller BudgetTicket or FrozenEndpointUse can be overwritten while pending
proof-visible authority is hidden behind subsystem-local mutable state
```

The reason is causal, not stylistic. Once caller context is gone and an already
pending `work_struct` has coalesced later queue attempts, the async core cannot
reconstruct a unique caller authority unless a typed carrier or explicit merge
ledger was created at the boundary. A stronger implementation may make this
carrier internal to a new CapSched async API, but the proof object must still
exist before authority can be lost.

This applies directly to device queues. A redesigned network driver or
workqueue implementation may make the path cleaner, but a shared callback that
processes a descriptor ring still cannot become "the last caller's work." The
submit, DMA map, descriptor publish, doorbell, IRQ/NAPI completion, settlement,
and revoke/drop points need a ledger or equivalent typed state that survives
coalescing without overwriting caller or queue identity.

## L0/L1/L2 Consequence

L0 should remain conservative:

```text
no generic behavior-changing process_one_work() authority lookup
no assumption that all workqueue callbacks are caller-derived
type names, observation, and narrow synthetic wrappers only
```

L1 should introduce:

```text
mandatory carriers for chosen DomainRequestWork paths
explicit no-overwrite checks while pending
cancel/flush settlement rules
traceable work generation and caller epoch
```

L2 should restructure:

```text
per-Domain async queues where appropriate
per-service queues for broker/service Domains
explicit merge queues for coalescing subsystems
Domain-aware worker dispatch and accounting
```

CapSched-H should additionally require:

```text
monitor-backed Domain activation on service/Domain crossings
root budget enforcement for service execution on behalf of Domains
MemoryView and IOMMU/queue ownership checks for endpoint effects
```

## Decision Boundary

The design answer is:

```text
Deep internal redesign:
  accepted, probably necessary for production.

Internal-only trust:
  rejected.

Typed carrier only for Domain-derived async work:
  accepted as the first safe boundary because it avoids false attribution of
  kernel maintenance work while preserving caller authority where it matters.

Generic workqueue CapSched enforcement before classification:
  rejected for L0 because it risks breaking Linux semantics and producing a
  security model full of exceptions.
```

This means the immediate design rule remains:

```text
Domain-derived async work needs a typed carrier before it leaves caller
context. Existing kernel-internal work remains service/kernel classified until
proved otherwise.
```

That rule does not weaken the final goal. It prevents the first implementation
from accidentally claiming more protection than it can prove.

## New Follow-Up

```text
N-063:
  Build a workqueue origin taxonomy and observation plan that separates
  PerInvocation, ExplicitMerge, ServiceOnly, KernelException,
  InterruptDeferred, ReclaimRescue, and TaskLocal paths before any generic
  workqueue enforcement hook.
```
