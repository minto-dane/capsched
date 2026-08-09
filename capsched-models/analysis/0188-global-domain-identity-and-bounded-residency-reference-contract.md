# Analysis 0188: Global Domain Identity and Bounded Residency Reference Contract

Status: Accepted semantic reference pending claim-specific EC1; no Linux
behavior change approved

Date: 2026-08-09

Work record: N-176

Requirement: `RESIDENCY-001`

## Question

How can process-scale global Domain identity refine into a bounded local
scheduler working set without making the slot bound a Domain-count limit,
letting stale slot state become authority, or allowing hostile Linux churn to
starve an admitted guaranteed Domain?

## Verdict

Residency is not one state and a resident slot is not an execution
capability. The minimum sound decomposition is:

```text
cluster identity / signed authority
  -> Monitor-owned node admission directory
    -> optional locality-scope descriptor cache
      -> bounded per-CPU scheduling projection
        -> CPU-bound sealed activation token

Linux locality, runnable, load, queue, and replacement data:
  untrusted shadow and hints only
```

The stable identity carried across sleeping, wakeup, async continuation, and
CPU migration is a principal and execution-instance identity plus current
epoch, never a local slot number. The full hierarchy is:

```text
PrincipalID
  long-lived security principal or tenant

DomainID / InstanceID + DomainEpoch
  process, container, service, or replica execution compartment

NodeID + MonitorBootEpoch + NodeLeaseEpoch
  node-local authority incarnation

HardwareCpuID + CpuIncarnation
  one non-reusable execution-context incarnation

SlotID + SlotGeneration
  local cache locator inside that CPU incarnation

ActivationGeneration + RunToken
  one bounded root execution opportunity
```

A resident binding is a Monitor-owned cache entry:

```text
(NodeID, MonitorBootEpoch, HardwareCpuID, CpuIncarnation,
 SlotID, SlotGeneration)
  -> (DomainID, DomainEpoch, NodeLeaseEpoch, MemoryViewID, policy class)
```

It makes later activation bounded; it does not authorize activation by
itself. A root RunToken must still bind the exact CPU, resident generation,
Domain epoch, MemoryView, root budget, and lease interval.

The first executable reference uses a Monitor-serialized ensure-resident
transaction and more guaranteed Domains than replaceable slots. It is a
semantic lower bound, not a production cache or replacement algorithm.

## Four Different Objects Previously Called Resident

The design must keep these objects separate:

| Object | Purpose | Authority | Cardinality |
| --- | --- | --- | --- |
| global Domain identity | stable logical name and revocation incarnation | issuing root and Domain Monitor | datacenter scale |
| node admission record | node-local lease, class, budget, placement, MemoryView | Domain Monitor | node-admitted working population |
| resident scheduling projection | bounded local translation into a scheduler slot | Monitor binding plus Linux shadow | fixed per execution context |
| active root token | permission to execute now on one CPU/view/budget | Domain Monitor and hardware | at most one current token per CPU |

Collapsing them creates several attacks:

```text
slot number as Domain identity
  -> reuse becomes cross-Domain alias

Linux queue membership as admission
  -> compromised Linux can mint or suppress authority

resident bit as RunToken
  -> a stale cache entry becomes executable authority

Linux refcount as eviction veto
  -> an attacker pins every slot and starves guaranteed Domains

global Domain epoch as slot generation
  -> local churn causes global invalidation amplification
```

## Version Algebra

At least four version spaces are required:

```text
DomainEpoch
  revokes or reincarnates the Domain authority itself

NodeLeaseEpoch
  fences node-local authority derived from cluster policy

TableEpoch
  versions rare locality/topology table replacement

SlotGeneration
  fences reuse of one local resident slot

MonitorBootEpoch / CpuIncarnation
  fence node restart, CPU offline/online, and numeric CPU-id reuse
```

They are not interchangeable. A slot miss or eviction does not change
`DomainEpoch`. A Domain revoke does not permit reuse of a stale active token.
A CPU hotplug rebuild does not rename a Domain. Slot generation never wraps
into trust: saturation quarantines the slot or requires a separately modeled
quiescent rekey.

Task, process, ExecutionGrant, and placement generations remain separate
again. A
single integer reused for all of these would turn an ordering bug into an
authority alias.

## Scope and Cardinality

The global namespace may contain far more Domains than any node and far more
node-admitted Domains than any CPU projection. Dormant process-granular
Domains consume no per-rq slot.

The reference model deliberately has:

```text
global ordinary Domains: 5
replaceable per-CPU slots: 1 on each of 2 CPUs
guaranteed Domains:       3
```

Thus both the per-CPU and total replaceable capacities are smaller than the
global population. This catches the old interpretation of R6's 64 leaves as
a node-wide Domain limit.

No finite machine can promise a fixed wait bound to an unbounded set of
simultaneously guaranteed Domains. A guaranteed class is accepted only after
a Monitor-owned feasibility test. Its service bound may scale with the
accepted guaranteed population and declared admission work, but not with
attacker-created best-effort churn.

## Authority Ownership

The Domain Monitor owns every fact needed for safety or cross-Domain
availability:

```text
DomainID and DomainEpoch
node admission class and NodeLeaseEpoch
eligible execution-context set
resident slot binding and SlotGeneration
install / hold / drain / retire state
trusted active and nested-entry references
root request cursor and guaranteed admission work
CPU online/accepting authority
MemoryView binding
sealed activation token
exclusive placement lease, when one is requested
```

Hostile Linux may provide:

```text
runnable and idle hints
preferred CPU / NUMA / LLC hints
load, utilization, cache-hotness, and queue depth
best-effort admission and eviction proposals
within-Domain fairness state
Linux object lifetime and RCU state
```

Linux hints may improve locality. They cannot bind a slot, choose a generation,
make a CPU authoritative-online, cancel a guaranteed request, release a
trusted reference, or prove quiescence.

## Resident Binding Lifecycle

The abstract lifecycle is:

```text
Empty
  -> Installing
  -> Resident
  -> HeldForRootHandoff
  -> Resident or Draining
  -> Retired
  -> Empty with a fresh SlotGeneration
```

`Installing` validates the current node lease, Domain epoch, target execution
context, MemoryView, class, and generation before publication. No partially
initialized binding is visible.

`HeldForRootHandoff` closes a composition race: once ROOTSCHED asks for an
admitted guaranteed Domain and residency reports ready, best-effort
replacement cannot evict the binding before the root token is issued or the
Monitor cancels the handoff.

`Draining` rejects new activations. Reuse waits for Monitor/hardware-owned
active and nested-entry references to reach zero. Linux-managed references do
not confer authority and cannot veto trusted retirement. Linux shadow objects
must instead be generation-discardable or Domain-private; their detailed
memory lifetime remains an `ENTRY-001` and `STATE-001` composition obligation.

A generation comparison does not make stale writable backing memory safe. An
old Domain pointer to a slot page could corrupt the next occupant after reuse.
Monitor bindings must therefore live in Monitor-protected memory; any reused
Linux shadow backing must be unmapped/retyped from the old MemoryView with the
required translation fence, or remain private to the same Domain. The later
memory/entry composition must discharge this physical-lifetime obligation.

## Replication and Exclusivity

It is incorrect to prohibit every duplicate Domain residency. A multithreaded
Domain may run on several CPUs, and the same immutable Domain descriptor may
be cached in several per-CPU projections.

Safe replication means:

```text
same DomainID and current DomainEpoch
different CPU-bound SlotGeneration values
independent exact RunTokens
one shared Monitor root-budget ledger or a sound partition of it
no implication that residency itself grants execution
```

Uniqueness applies only to an explicitly exclusive placement lease. For such
a lease, migration is:

```text
source blocks new activation
source root token expires or is stopped
source trusted references drain
source binding retires
placement generation advances
destination binding installs
destination may activate
```

Copy-before-fence and destination activation before source stop are unsafe.
Ordinary Linux task migration is not this authority transfer. A compromised
Domain may duplicate or corrupt its own task bookkeeping, just as a
compromised guest kernel may corrupt guest tasks; the Monitor must still cap
the Domain's CPU set and root budget and prevent cross-Domain authority.

The same rule applies to async and service carriers: durable work references
bind global principal/instance identity, epoch, object generation, and frozen
authority. They never retain or pin a CPU-local resident slot.

## ROOTSCHED Composition

The visible interface is a Monitor-owned handshake:

```text
ROOTSCHED NeedResident(DomainID, DomainEpoch, eligible CPU set)
  -> RESIDENCY ResidentReady(exact binding)
  -> ROOTSCHED Activate(exact binding, root budget, lease)
  -> hardware/Monitor ExpireOrStop
  -> trusted reference release
```

The request remains pending while a victim drains. It is neither retried nor
cancelled by Linux. Best-effort work cannot overwrite the held binding or
consume guaranteed admission work.

The model assumes the ROOTSCHED reference supplies a guaranteed request. It
guarantees that the ensure-resident transaction completes under the declared
capacity and hardware assumptions. Their composition yields a Monitor-created
activation opportunity; it still does not guarantee useful progress by
Domain-local Linux.

Management/recovery cannot depend on the replaceable pool whose failure it
must repair. The reference therefore requires a sealed pinned recovery
binding, dedicated recovery context, or equivalent no-general-slot bootstrap
path. Production may choose among these, but an evictable ordinary slot is not
sufficient.

## Liveness Assumptions and Impossibility Boundaries

Guaranteed admission requires all of the following:

```text
the guaranteed set passed a finite Monitor feasibility test
at least one eligible execution context remains authoritative-online
root leases and trusted hardware references have bounded completion
Monitor request, drain, retire, bind, and activate actions are weakly fair
slot generation capacity remains available or a safe rekey completes
the management/recovery path remains independently available
```

No fairness is assumed for Linux. The reference does not claim progress while
all eligible CPUs are offline, firmware prevents Monitor entry forever, a
trusted hardware reference never completes, generation space is exhausted,
or admission exceeds the declared feasible envelope.

The semantic wait unit is a completed Monitor transition/admission turn. A
wall-clock bound additionally needs Monitor WCET, timer/interrupt latency,
MemoryView installation cost, shootdown bounds, and hardware/firmware
assumptions.

## Churn and Denial of Service

Best-effort churn is a security-relevant cost attack even when it cannot mint
authority. A production refinement must provide:

```text
coalescing by DomainID, epoch, and target scope
per-Domain or tenant admission-work budgets
reserved admission bandwidth for guaranteed and recovery work
constant bounded rejection of malformed or stale hints
no global task/rq scan on a miss
Monitor-observed replacement state, not Linux-authored popularity
minimum residency or hysteresis where it does not violate guarantees
bounded collision behavior in directory lookup
cost attribution for drain, IPI, MemoryView, and cache reconstruction work
```

Best-effort starvation under overload may be policy-allowed. Guaranteed or
management starvation caused by best-effort requests is not.

## CPU Hotplug and Revocation

Linux `cpu_online_mask` and scheduler rq state are compatibility views, not
root authority. Monitor offlining proceeds as:

```text
accepting = false
block new root tokens and resident installs
expire/stop active root authority
drain trusted entry references
retire resident bindings
mark execution context authoritative-offline
```

An offline context has no active token, trusted pin, or resident binding.
Linux cannot bring it back into the authority set by changing a mask.

Domain revocation uses a similar prepare/drain/commit protocol. `Revoking`
blocks new activation while already-issued bounded leases are stopped. The
effective `DomainEpoch` change is committed only after the modeled trusted
drain, unless an architecture-specific mechanism can atomically invalidate
all active tokens. Stale resident replicas may be cleaned lazily only if every
activation checks the current Monitor epoch.

## R6 Refinement Decision

R6 remains useful only as a Linux scheduling projection candidate. Its fixed
64 leaves, bounded masked traversal, and preallocated per-rq state are valuable
for a local hit path. Its existing interpretation is not a complete
`RESIDENCY-001` refinement:

1. The R6 descriptor has a bounded slot map and therefore cannot be the global
   registry.
2. A task-carried fixed slot is not stable across independent per-CPU maps.
3. A whole-table generation for every slot replacement creates invalidation
   amplification.
4. R6 mutable EEVDF state is Linux-owned policy and cannot preserve root
   authority or guaranteed progress under the hostile-Linux model.
5. Sleeping tasks and Linux references cannot permanently pin a resident
   authority slot.

Any successor must carry stable Domain identity in the frozen authority,
resolve a destination-local slot before enqueue, and recheck the exact local
generation at final selection. R6's slot-local queue and top forest can remain
an optimization shadow. Cgroup membership, scheduler weights, and a successful
Linux move remain non-authoritative.

This is a refinement requirement, not approval to modify or discard R6 source.

## Linux Source Map

The reviewed Linux source is commit
`74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.

Relevant semantics are distributed rather than located at one hook:

| Concern | Current source anchors | Consequence |
| --- | --- | --- |
| task/rq ownership | `kernel/sched/core.c:570-657`, `730-789` | `rq->lock`, `p->pi_lock`, migrating state, and memory ordering are Linux correctness, not Monitor authority |
| queued move and stopper | `kernel/sched/core.c:2542-2680` | remove/change CPU/add is a useful projection protocol, but stopper completion cannot mint a placement lease |
| affinity and migrate-disable | `kernel/sched/core.c:2885-3214` | affinity has concurrent pending/stopper semantics; an added authority check cannot assume one synchronous path |
| wake placement | `kernel/sched/core.c:3616-3650`, `4160-4435` | destination selection occurs before or during wakeup and may change without a resident hit |
| fair balancing | `kernel/sched/fair.c:11090-11423`, `13680-13760` | detach/neutral/attach spans separate rq locks and multiple balancing paths |
| other scheduler classes | `kernel/sched/deadline.c:648`, `kernel/sched/ext/ext.c:2255` | deadline and sched_ext have additional move paths; one CFS hook cannot establish completeness |
| cgroup movement | `kernel/sched/core.c:9440-9603` | mutable cgroup attach is policy input, never Domain identity |
| CPU hotplug | `kernel/sched/core.c:8556-8862` | scheduler online/offline callbacks must refine, not define, Monitor CPU authority |
| core scheduling | `kernel/sched/core.c:6233-6663` | SMT co-tenancy is a separate core-wide constraint and may motivate an optional per-core descriptor layer |

This checkout is the upstream-derived DomainLease branch rather than an
unmodified upstream commit. It contains historical default-off SchedExecLease scaffold calls
near queued migration. They are observations only and provide no production
boundary.

There is no safe conclusion yet about exact patch points. The source map says
the future Linux adapter must present a small semantic interface across many
existing paths, while the Monitor directory and binding protocol remain
independent of high-churn scheduler internals.

## Hierarchical Scalability Candidate

The current architecture candidate is:

```text
global signed Domain namespace
  -> node-local Monitor admission directory
    -> optional per-NUMA/LLC/core immutable descriptor cache
      -> per-CPU bounded mutable Linux scheduling projection
        -> Monitor-owned active token
```

Only immutable identity descriptors should be shared at an LLC/core layer.
Sharing Linux runqueues would conflict with the scheduler's per-rq locking and
increase cross-CPU failure coupling.

The memory envelope is:

```text
node-admitted Domains * authoritative directory bytes
+ locality scopes * shared descriptor-cache bytes
+ CPUs * bounded projection bytes
+ CPUs * active-token bytes
```

It must scale with node-admitted Domains, not all cluster Domains. Existing R6
layout evidence is about 57 KiB/rq on arm64 and 74 KiB/rq on x86_64, with a
96 KiB conservative hard envelope. Capacity alone is not acceptance evidence;
cache footprint, rq-lock hold time, churn amplification, and admission tail
latency remain decisive.

## Cost Vector for Later Evaluation

Each path is measured as a vector, not one score:

```text
CPU cycles
Monitor entries
rq-lock hold time
shared-lock wait
cache lines read/written
remote-NUMA accesses
IPIs and trusted drain actions
TLB/translation invalidations
MemoryView work
bytes allocated/touched
attacker amplification per rejected request
guaranteed admission wait
```

Separate cells are required for same-active hit, per-CPU hit, optional shared
cache hit, node-directory hit, clean eviction, active victim drain, CPU
migration, hotplug, revoke, and process-versus-container Domain granularity.

Selector-only nanoseconds, average latency, registration count, or an unmatched
container/KVM comparison cannot establish cost efficiency.

## Formal Reference Scenarios

Formal 0148 separates four scenarios so one small state space does not hide
different assumptions:

```text
Admission:
  3 guaranteed Domains traverse 2 replaceable slots despite hostile Linux

Migration:
  one explicitly exclusive placement moves source-drain-first

Hotplug:
  one CPU stops accepting, drains, retires, and returns only with a fresh
  CpuIncarnation

Revoke:
  legal multi-CPU replicas stop, drain, and commit a new Domain epoch
```

Safe properties include:

```text
GlobalPopulationExceedsResidentCapacity
MonitorOwnsGlobalRegistry
MonitorOwnsResidentBindings
ResidentEpochCurrent
SlotGenerationFresh
ActiveBindingExact
NoEvictWhileRunningOrReferenced
HeldBindingMatchesRequest
NoDuplicateExclusiveResidency
ExclusiveAuthoritySingleCPU
MigrationPreservesIdentityAndAuthority
OfflineCPUHasNoAuthority
HotplugCreatesFreshCpuIncarnation
NoActivationIssuedDuringRevocation
ManagementRecoveryIndependent
NoProtectionClaim
```

Temporal properties include guaranteed admission, pending handoff completion,
exclusive migration completion, hotplug quiescence, and revoke completion.
Fairness is attached only to Monitor and hardware actions. Linux noise has no
fairness assumption.

Negative configurations independently exercise Linux-gated admission,
skipped guarantees, absent hardware quiescence, pinned eviction, generation
reuse, stale epoch binding, best-effort overwrite, stale-handle activation,
Linux-owned binding/registry/CPU state, resident-slot-as-authority, management
loss, copy-before-fence migration, destination-before-source-stop, identity
drift, offline-before-drain, and activation during revoke.

## Accepted and Deferred

Accepted after claim-specific EC1:

```text
stable identity is not a slot
resident binding is not a RunToken
the Monitor owns binding, generation, drain, and guaranteed admission
replicated cache residency is legal unless an explicit lease is exclusive
management has an independent recovery binding
R6 can refine only the bounded Linux projection layer
```

Deferred:

```text
production directory representation and replacement policy
cryptographic descriptor format and public ABI
exact per-CPU/per-core/per-LLC cache sizes
architecture-specific trusted reference and interrupt protocol
budget-fragment conservation across exclusive migration
entry, MemoryView, TLB, and Linux-shadow lifetime composition
cross-node migration, partitions, and fencing
wall-clock bound
Linux patch points
performance, cost, protection, or deployment evidence
```

## Non-Claims

This contract and its finite model do not implement a Domain Monitor, change
Linux behavior, prove memory isolation, prove a real hotplug or migration
path, establish a wall-clock service bound, select the production cache, or
support hypervisor-grade protection, performance, cost-efficiency,
multi-cluster, or deployment claims.

The next composition obligation after this contract is `ENTRY-001 + CODE-001`.
