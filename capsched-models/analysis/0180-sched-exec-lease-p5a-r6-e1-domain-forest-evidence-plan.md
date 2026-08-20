# Analysis 0180: SchedExecLease P5A-R6 E1 Domain-Forest Evidence Plan

Date: 2026-07-25

Status: pre-source evidence plan. Passing validation authorizes only an exact,
disposable, default-off R6-E2 layout candidate. It does not authorize a
selector, scheduler hook, cgroup integration, task migration behavior,
runtime denial, or production use.

## Purpose

Validation/0275 selected Sealed Masked Domain Forest after R5 failed before
source. This E1 plan resolves the Linux-specific shape before any R6 source:

```text
sealed domain-to-slot and per-CPU allowed masks
fixed 64-slot top selection with exact work bounds
mutable slot-local EEVDF state
existing fair-group hierarchy composition
equal-domain fairness and re-enable placement
finite private storage
admission, migration, current, hotplug, and lifetime ordering
later correctness and timing rejection gates
```

The exact primary remains Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.

## Decisive Hierarchy Constraint

One `sched_entity` has one `parent`, one owning `cfs_rq`, and at most one owned
`my_q`. Domain hierarchy therefore cannot be inserted orthogonally beneath
every mutable cgroup without cloning the cgroup tree, nor above arbitrary
mixed-domain cgroups without losing domain separation.

R6 fixes this composition:

```text
root fair rq
  fixed R6 top selector over at most 64 sealed domain roots
    one dedicated root-child FAIR_GROUP_SCHED subtree per domain slot
      ordinary descendant cgroups belonging to that same domain
        ordinary CFS tasks with the same sealed slot binding
```

The first fair-group ancestor below root is the domain-root mechanism object.
Its slot mapping is supplied by a sealed descriptor and checked against the
task-local identity; its cgroup identity is never authority.

The following configurations fail closed:

- one root-child subtree containing tasks from multiple DomainLease slots;
- one domain spanning multiple root-child subtrees in the same descriptor;
- an ordinary leased task attached directly to the fair root;
- a cgroup move without a replacement monitor-authorized task binding;
- a subtree move that changes the sealed domain-root mapping;
- `SCHED_AUTOGROUP`, because it independently changes `sched_task_group`; and
- any use of cgroup shares, membership, CSS lifetime, or topology as proof of
  execution authority.

Kernel idle/stop/per-CPU workers and non-fair classes are not silently mapped
through this ordinary-CFS design. They remain explicit later integration or
exclusion obligations.

## Sealed Authority Descriptor

One immutable RCU-published descriptor contains:

```text
generation
slot-map digest
domain-root identity digest for every occupied slot
per-CPU allowed-slot mask
fixed equal-domain-weight profile id
descriptor digest
sealed state
```

The descriptor is fully allocated, hashed, and sealed before release
publication. Generation and slot identities never wrap or reuse. Publication
swaps one pointer and generation in constant work and performs no rq, task,
slot, cgroup, or CPU walk; allocation; scheduling-state repair; queueing;
waiting; flush; or cancellation.

The per-CPU mask array is immutable descriptor input, not per-rq mutable
authority. A selector acquire-loads the descriptor, checks sealed state,
generation, slot-map/domain-root/profile digests, and indexes exactly one CPU
mask. Failure is `Blocked`; an old descriptor is never fallback authority.

## Mutable Top Selector

Each rq owns 64 fixed leaves and a complete six-level reduction tree with 127
unique nodes. Every internal node has a static slot mask. Live leaf and
aggregate scheduling fields are mutable only under the owning rq lock with
local IRQs disabled.

The selector uses two exact masked phases:

1. **Aggregate phase**: skip disjoint subtrees, combine a fully allowed
   subtree's current weight/weighted-vruntime aggregate, and descend partial
   subtrees. Compute the allowed runnable domain virtual time using Linux
   EEVDF's left-biased signed division semantics.
2. **Candidate phase**: skip disjoint or wholly ineligible subtrees, evaluate
   current eligible leaves, and select the earliest deadline with a stable
   slot-id tie break.

Each phase visits at most 127 nodes. The full top query therefore visits at
most 254 nodes, not 127 operations and not `O(log 64)`. It is fixed
`O(B_max)` independent of task count. A final slot-local `pick_eevdf()` then
uses the ordinary dynamic EEVDF tree, followed by an exact task-local
generation/domain/slot check.

One task execution/accounting change updates its domain leaf and at most six
ancestors. Enqueue/dequeue changes the slot runnable state and the same bounded
path. No copied immutable selector summary exists.

The first rq observation of a new descriptor reconciles at most 64 changed
mask bits. Revoked slots become invisible immediately to the next pick.
Newly allowed or newly nonempty slots are placed with zero negative lag at the
current allowed-domain virtual time; time spent unauthorized creates no
catch-up credit. The rq records the observed generation/mask as a
non-authoritative cache only after the exact descriptor checks and bounded
reconciliation complete.

The fixed work bounds are:

```text
B_max                                      = 64
unique top nodes                           = 127
aggregate-phase node visits                <= 127
candidate-phase node visits                <= 127
complete top-query node visits             <= 254
descriptor mask-reconcile slot visits      <= 64
one dynamic leaf-update ancestor visits    <= 6
task-tree scan for authorization            = 0
publication rq/task/slot/cgroup walks       = 0
```

These are structural bounds, not latency or performance claims.

## Fairness Contract

R6 deliberately implements two-level fairness:

1. equal weight among currently allowed, runnable DomainLease slots; then
2. ordinary Linux fair-group/cgroup and task fairness inside the selected
   domain subtree.

The R6 candidate supports only fixed `NICE_0_LOAD` domain weights. Runtime
weight controls and cgroup shares do not change top-domain authority or
weight. Variable monitor-issued domain weights remain deferred.

Top domain entities use EEVDF vruntime, virtual lag, deadline, slice, and
current accounting semantics. A domain that becomes unauthorized stops
accruing service and is excluded from the allowed aggregate. Re-enable/new
runnable placement gives zero negative lag, preventing a revocation interval
from creating a service burst. Positive debt is not erased. Equal-weight
service-ratio, no-starvation under a stable allowed mask, no denied service,
and no catch-up burst require independent deterministic oracle checks.

This is not flat-CFS equivalence. CFS bandwidth, PELT, utilization clamping,
load balancing, EAS, core scheduling, sched_ext, RT/DL, deadline server,
proxy execution, and CPU capacity behavior remain unaccepted until explicitly
integrated or excluded.

## Finite Storage and Admission

R6-E2 measures private candidate types using conservative architecture-local
bounds:

```text
one slot state:
  inner cfs_rq + top sched_entity + sched_statistics + private metadata
                                               <=   1024 bytes
one top reduction node                         <=     64 bytes
one rq control/receipt-cache block             <=   1024 bytes

64 slot states                                 <=  65536 bytes
127 top nodes                                  <=   8128 bytes
one rq control                                 <=   1024 bytes
computed private total                         <=  74688 bytes/rq
hard private-rq envelope                       <=  98304 bytes/rq
private object alignment                       <=     64 bytes
```

The 98,304-byte envelope covers arm64/x86_64 debug layouts, including
`CONFIG_SCHEDSTATS`; it is an admission limit, not a target.

All per-rq state is allocated and initialized in sleepable context before the
CPU accepts R6 tasks. Slot 65, allocation failure, descriptor overflow, or a
layout above the hard envelope fails closed. There is no eviction, merging,
slot alias, ordinary-root fallback, or allocation under task/rq locks.

The layout candidate adds zero bytes to ordinary `sched_entity`, `cfs_rq`,
`rq`, and `task_struct`. Future task slot binding must use a reviewed encoding
inside the already existing private `sched_exec.flags` word; E2 only measures
that possibility and does not assign semantics.

## Exact R6-E2 Source Boundary

After E1 passes, R6-E2 may create one disposable direct child of the primary
and change exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

The new option is `CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE`. It defaults to
`n` and depends on:

```text
SCHED_EXEC_LEASE
SCHED_EXEC_LEASE_LAYOUT_PROBE
DEBUG_KERNEL
SMP
CGROUP_SCHED
FAIR_GROUP_SCHED
!SCHED_AUTOGROUP
```

Only private type definitions and object-local size/alignment/offset symbols
may be added. E2 adds no constructor, scheduler/cgroup hook, callback, CPUHP
registration, static key, allocation, export, tracepoint, file, ABI,
monitor/policy call, or behavior. It changes no public/scheduler header.

Arm64 and x86_64 each compare architecture-local clean primary baselines with
the candidate. All existing expanded layout-probe values must remain exact.
Config-off must contain no new private symbols, relocations, or strings.

## Task, Enqueue, and Migration Ordering

A task binding is valid only when task-local domain id/epoch/generations and
encoded slot match the acquire-loaded sealed descriptor and the task's
domain-root subtree. Fork inherits a frozen binding only under the existing
task lifecycle handshake. Exec advances the task's exec generation before a
new runnable commitment.

Before first enqueue:

```text
descriptor and slot valid
domain-root subtree mapping exact
destination CPU mask allows the slot, or task remains Blocked
rq state allocated, online, and accepting
task contributes nowhere else
```

Enqueue under rq lock rechecks all of those fields before adding exactly one
slot-local contribution. The final picker repeats the task-local check; group
placement alone is not authority.

Migration is remove-neutral-add. The source contribution and current/top
state are removed under the source rq lock before source unlock. Neutral state
has no source or destination contribution. Destination rq lock then checks
its descriptor, per-CPU mask, domain-root mapping, capacity, online, and
accepting state before adding. Failure leaves the task explicitly Blocked; it
does not restore stale authority or bypass into the ordinary root.

A cgroup move uses `task_rq_lock()` settlement and is accepted only if the
new subtree maps to the same sealed slot or a new monitor-authorized task
binding is already frozen. Mutable cgroup movement never changes authority.

## Current, Hotplug, and Lifetime

The next-pick mask fence does not stop an already running task. Revocation
records a separate stop request and calls `resched_curr()` under rq lock.
Evidence requires a later scheduler observation that current changed or
revalidated. Linux reschedule is not a monitor interrupt or completion
receipt.

The fair rq-offline seam runs under scheduler locking and may only clear
`accepting`, remove top visibility, mark current/queued state Blocked, and
prevent new contributions. A sleepable `CPUHP_AP_ONLINE_DYN` phase later
drains private refs and waits for RCU. Allocation/free, cancellation,
`synchronize_rcu()`, and monitor calls are forbidden under rq/task locks.

Online allocates and initializes all private state first, then publishes the
pointer, then sets `accepting` under rq lock. Offline reverses visibility,
drains, RCU-unpublishes, and frees only after:

```text
zero queued/current slot contributions
zero selector readers and task refs
no cgroup/domain-root attachment in transition
accepting false
RCU grace complete
```

Descriptor and slot generation saturation blocks and requires quiescent
replacement. Neither is reused into trust.

## R6-E3 Correctness Gate

Only exact dual-architecture E2 closure may unlock a separate default-off
same-translation-unit synthetic prototype. E3 must include:

- mask cases empty, singleton, alternating, all-64, current-only, and
  revoked-current;
- aggregate and candidate traversal counts with hard 127/127/254 bounds;
- exact comparison against a simple 64-leaf independent oracle;
- leaf/current/enqueue/dequeue update paths bounded to six ancestors;
- descriptor changes with 0, 1, 63, and 64 changed bits;
- re-enable placement with no negative lag or catch-up burst;
- equal-weight domain service and stable-mask no-starvation checks;
- nested cgroup/domain mapping, mixed-subtree/root-task/autogroup rejection;
- fork/exec/enqueue/cgroup-move/CPU migration remove-neutral-add cases;
- offline/current/reader/ref/RCU and saturation/allocation faults; and
- arm64/x86_64 standard debug, arm64 KASAN, and x86_64 KCSAN/lockdep
  diagnostics before any timing plan.

The oracle, generated masks, expected picks, visit bounds, contribution
counts, and fairness ledger must be separate from the implementation.

## R6-E4 Measurement Rejection Gate

Only independently closed E3 evidence may unlock a separate arm64-first
measurement plan. Paired empty controls and at least 10,000 pairs per cell
must cover:

```text
constant-work descriptor publication
six-ancestor leaf update
127-node aggregate phase
127-node candidate phase
254-node complete top query
64-bit descriptor reconciliation
slot-local EEVDF pick plus final task check
revoked-current request and later observation
offline visibility removal
```

Dimensions include active slots, allowed-mask density/pattern, current slot,
newly allowed bits, inner task count, descendant cgroup depth, and publication
burst. Fixed ordinary rq-lock gates remain additional p99 <= 5,000 ns,
p99.9 <= 25,000 ns, and maximum <= 50,000 ns; a sample reaching the 700,000
ns normalized base slice rejects. Offline uses the existing separate
25,000/40,000/50,000 ns rq-lock gates. Any compiler diagnostic, lockdep,
irqsoff, RCU, KASAN, KCSAN, workqueue, soft/hard-lockup, parser, placement, or
harness failure gives no timing credit.

Arm64 threshold rejection stops R6 and x86_64. A clean virtual result may
authorize only same-source x86_64; it cannot prove bare-metal performance.
There is no global settlement deadline or continuous-publication liveness
claim.

## Claim Boundary

No R6 layout/source, real scheduler or cgroup attachment, runtime denial,
monitor delivery, N-136 runtime charge, flat-CFS fairness equivalence,
cross-class coverage, bare-metal latency, performance, cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness is
accepted.
