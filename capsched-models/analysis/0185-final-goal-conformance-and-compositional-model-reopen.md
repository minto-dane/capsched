# Analysis 0185: Final Goal Conformance and Compositional Model Reopen

Status: Accepted architecture audit; final compositional model reopened; no
Linux behavior change approved

Date: 2026-08-08

Work record: N-174

Reviewed project revision:

```text
75e34749b94af52338085caced75c44c70f0a1b4
```

## Question

Does the current model set already describe the complete DomainLease-Linux
goal strongly enough to begin optimizing and promoting the R6 Linux selector?

## Verdict

```text
No.
```

The repository contains a strong set of local contracts, useful
counterexamples, detailed Linux source maps, and unusually careful non-claim
boundaries. It does not yet contain a composed model of the complete target:

```text
hostile Domain-local Linux kernel execution
+ process-through-container Domain granularity
+ monitor-enforced CPU, memory, and device roots
+ survivable node-local Domain scheduling
+ typed service mediation
+ partition-aware multi-cluster authority
+ a measurable cost advantage over VM-based deployment
```

N-155 remains valid only as the v1 claim-inventory, local-contract, and
overclaim-gate completion record. Final compositional-model completeness is
reopened by ADR-0012.

No Protection-evidenced claim is downgraded because none exists. Existing
component models remain useful. Their conjunction is not assumed to prove the
system claim.

## Goal Restatement

The security comparison is not ordinary container hardening:

```text
VM:
  compromised guest kernel -> hypervisor escape required

DomainLease-Linux:
  compromised Domain-local Linux kernel context
    -> Domain Monitor or typed service endpoint break required
```

The comparison includes integrity and confidentiality. Because the repository
threat model also includes cross-Domain starvation and monitor starvation, it
includes bounded root-scheduling availability as well. Linux policy may be
compromised and therefore cannot be the sole root of that guarantee.

The cluster goal is one logical OS and authority namespace across nodes and
clusters. It is not one cross-machine runqueue or one cross-machine mutable
heap. Enforcement remains node-local and lease-derived.

## What Is Already Strong

1. The assurance case keeps `TOP-001` Open and prohibits Linux-only protection
   claims.
2. The threat model admits Domain-local arbitrary Linux kernel-context
   execution instead of assuming Linux correctness.
3. Monitor root-budget expiry is separated from Linux timers and modeled
   fail-closed.
4. The MemoryView/TLB work records a real stale-translation counterexample.
5. Cluster authority is compiled into node-local authority rather than used as
   a directly executable remote object.
6. Async workqueue and io_uring analysis recognizes that worker identity and
   generic Linux object lifetime are not caller authority.
7. R6 records fixed storage and traversal bounds, explicit two-level fairness,
   overflow refusal, and honest non-claims.
8. Linux compatibility, source shape, runtime experiments, and production
   protection are kept as different evidence classes.

These are retained as foundations. The audit does not restart the project.

## Conformance Gap Matrix

| Requirement | Current useful evidence | Missing system obligation | Required successor |
| --- | --- | --- | --- |
| `ROOTSCHED-001` | Monitor root timer stops an expired Domain; R6 chooses among modeled slots | A compromised Linux selector can corrupt or withhold global scheduling state; no trusted handoff or eligible-other-Domain progress exists | Compose adversarial Linux selector state with a minimal Monitor root scheduler and bounded service guarantee |
| `RESIDENCY-001` | R6 has 64 bounded slots and no overflow alias | Global process-scale Domain cardinality, admission, eviction, migration, churn, generation fencing, and progress beyond 64 resident slots are absent | Treat slots as a per-CPU resident cache and model more global Domains than resident slots |
| `ENTRY-001` | Activation and MemoryView/TLB models exist | Syscall, exception, IRQ, NMI, machine-check/SError, nested entry, entry stacks, per-CPU data, and return sequencing are absent | Compose every entry/return edge with active Domain, MemoryView, stack, and epoch invariants |
| `CODE-001` | Shared immutable kernel code is an architectural intention | No executable provenance, W^X, module, livepatch, ftrace/kprobe, BPF JIT, text-poke, or code-epoch model exists | Model monitor-verified executable sealing and controlled code mutation across all views |
| `STATE-001` | MM, allocator, page-cache, async, socket, and service maps identify risks | There is no exhaustive ownership partition for every mutable page reachable by Domain kernel code | Require each mutable page to be Domain-private, typed-service-owned, or Monitor-owned; unknown ownership is unmapped |
| `SVC-001` | Typed endpoint and service/caller intersection contracts exist | Service compromise blast radius and shared parser/global-state behavior are not composed with memory and revoke | Model a compromised service with only endpoint-scoped objects, budget, and explicit shared buffers |
| `MGMT-001` | Management issues placement, leases, and policy in architecture notes | Management Domain and signing-key compromise are neither modeled nor explicitly bounded | Separate online management, offline roots, node Monitor authority, recovery, rotation, and declared out-of-scope cases |
| `CLUSTER-PART-001` | ClusterLease compilation and node-local enforcement are modeled | Atomic global revoke bypasses partitions; clocks, expiry, message delay/reorder, quorum, fencing, namespace uniqueness, and migration duplication are absent | Model signed bounded leases under local monotonic time, partition behavior, fencing, and recovery |
| `COMPOSE-001` | Many local TLA models and counterexamples exist | No shared assume/guarantee contract or refinement mapping connects scheduler, Monitor, memory, async, service, device, and cluster state | Build an explicit composition ledger and cross-component adversarial model |
| `GRANULARITY-001` | Process, service, container, tenant, and cluster-cell Domains are intended | No rule states when process-granular MemoryView switching is cost-effective or when grouping is required | Define a security/cost envelope and measure complete same-Domain and cross-Domain paths |
| `EVIDENCE-001` | Extensive source, build, QEMU, KUnit, TLC, and measurement records exist | Several positive gates trust producer-authored summaries or mutable inputs instead of validator-owned captured bytes | Introduce immutable evidence capsules and mark affected promotion credit for revalidation |

## Architecture Requirement 1: Monitor-Owned Root Scheduling

The Monitor must own the minimum scheduling state needed to prevent one
compromised Domain from suppressing all others. This does not put Linux CFS,
EEVDF, RT, deadline, topology balancing, or cgroup policy into the Monitor.

Required split:

```text
Linux:
  proposes runnable Domain candidates
  schedules tasks within the active Domain
  optimizes locality, fairness, and same-Domain batching

Domain Monitor:
  owns live root leases and epochs
  owns root budget/deadline timers
  chooses or validates the next root Domain at a lease boundary
  guarantees bounded service for admitted guaranteed Domains
  may accept Linux hints but cannot depend on Linux cooperation
```

The Monitor root scheduler should be deliberately small. Candidate policies
include a bounded deadline/deficit table or another simple verified server
algorithm. The policy is not selected here. The required properties are:

```text
NoRootRunWithoutLease
NoRootBudgetOverrun
LinuxCannotExtendOrSuppressLease
ExpiredDomainCannotRemainActive
EligibleGuaranteedDomainEventuallyRuns
ManagementAndRecoveryServiceRemainSchedulable
```

Best-effort work may have weaker progress guarantees, but the class must be
explicit. Terminal stuttering after stopping an attacker is not sufficient for
the in-scope cross-Domain starvation threat.

## Architecture Requirement 2: Global Identity, Local Residency

The R6 `B_max=64` bound cannot be the global number of Domains on a datacenter
node. It is retained only as a candidate local working-set bound:

```text
global Domain identity:
  stable monitor-owned DomainID + epoch

per-CPU resident identity:
  slot + slot_generation -> exact DomainID + epoch

R6 selector:
  operates only on admitted resident slots
```

The model must include more global Domains than resident slots and prove:

```text
NoSlotAlias
NoStaleSlotGenerationUse
NoEvictWhileRunningOrReferenced
NoDuplicateExclusiveResidency
MigrationPreservesIdentityAndAuthority
OverflowCannotMintAuthority
GuaranteedNonresidentDomainEventuallyAdmitted
BestEffortChurnCannotStarveGuaranteedDomain
```

Admission and eviction may be driven by Linux hints, but Monitor-owned identity,
lease, epoch, and hard progress contracts cannot be forged by Linux.

## Architecture Requirement 3: Entry and Shared Code Integrity

Every transition into privileged execution is part of the isolation boundary.
The model must cover at least:

```text
syscall
page fault and synchronous exception
IRQ and nested IRQ
NMI / machine check / SError-class entry
IPI and TLB shootdown
debug and perf interrupt
return to user and return to interrupted kernel context
```

An entry path must either activate a Monitor/service entry view before touching
mutable global state or remain inside the current Domain view while touching
only that Domain's permitted state. Per-CPU entry stacks and metadata need an
owner and mapping rule. A stale MemoryView, stack pointer, or Domain epoch must
not survive entry nesting or return.

Shared kernel text can be shared only as monitor-verified read-only executable
content. Text mutation is an authority-changing transaction, including:

```text
module load/unload
livepatch
alternatives and static keys
ftrace, kprobe, and text_poke
BPF JIT and executable allocator paths
firmware-generated or device-generated executable code
```

The future model must define W^X, executable provenance, a code epoch, update
serialization, cross-view invalidation, and recovery. A Domain-local kernel
compromise must not gain writable access to executable pages shared by other
Domains.

## Architecture Requirement 4: Mutable State and Service Containment

Every mutable physical page reachable in privileged mode must have exactly one
security classification:

```text
Domain-private
typed-service-owned
Domain-Monitor-owned
explicitly shared buffer with a typed protocol
```

Unknown ownership fails closed and is not mapped. A global Linux pointer does
not imply global mapping authority.

Service Domains should isolate drivers, parsers, and shared control planes, but
service decomposition is not enough by itself. The composed service model must
assume arbitrary service kernel-context compromise and bound its authority to:

```text
declared endpoint operations
caller-frozen authority intersection
service-local objects
explicit shared buffers
service and caller budgets
monitor-minted receipts
```

Management is a separate trust question. Offline signing roots, online control
planes, node Monitors, recovery authorities, and break-glass operations must not
be collapsed into one ambient root Domain.

## Architecture Requirement 5: Partition-Aware Cluster Semantics

The cluster model must not simulate revocation as an atomic write to every
node. It must represent delayed, lost, duplicated, and reordered messages,
network partitions, node restart, and local clock assumptions.

The intended baseline is:

```text
remote authority:
  signed, bounded-duration, scoped lease

local execution:
  compiled node-local lease checked against local monotonic time and epoch

partition:
  existing lease remains valid only within its explicit bound
  renewal fails closed when required authority is unavailable

migration:
  source is fenced or its lease expires before destination gains exclusive use
```

The architecture cannot promise both instantaneous global revocation and
continued partition availability. Claims must state the maximum stale-authority
window and which workloads fail closed versus continue under a bounded lease.

No cross-node runnable pointer, shared runqueue, or synchronously shared kernel
heap is introduced.

## Architecture Requirement 6: Explicit Composition

A giant monolithic TLC run is not required and may be counterproductive. The
required artifact is an explicit composition, not a particular checker.

Each component must publish:

```text
owned state
trusted inputs
untrusted inputs
assumptions
guarantees
visible actions
stuttering/internal actions
failure and recovery actions
refinement mapping to architecture objects
```

Cross-component checks must include at least:

```text
root scheduler + RunToken + root budget
activation + entry + MemoryView + TLB
Domain identity + resident slot + migration
async/service endpoint + BudgetTicket + revoke
QueueLease + PageOwner + IOMMU + IRQ
ClusterLease + local lease + epoch + partition/fencing
```

TLA+ remains suitable for concurrency and temporal properties. TLAPS or
Apalache can strengthen stable invariants where useful. Linux memory-ordering
obligations should later be represented with LKMM litmus tests; bounded C
helpers can use CBMC or equivalent; implementation conformance needs KUnit,
kselftest, QEMU, and adversarial fault injection. Tool success is evidence for
a named obligation, never the goal itself.

## Architecture Requirement 7: Granularity and Cost Envelope

Process-granular Domains are supported, not universally prescribed. A
cross-Domain switch may require MemoryView and translation-context work that a
VM avoids for process switches inside one guest. Cost efficiency therefore
depends on workload and grouping:

```text
same-Domain threads:
  native Linux scheduling fast path where possible

cross-Domain process switch:
  Monitor activation and MemoryView cost

container/service Domain:
  amortize activation across a larger trust group

high-risk process Domain:
  pay finer-grained isolation cost deliberately
```

The evaluation must measure the complete operation, not only the top selector:

```text
root handoff
MemoryView/stage-2 or EPT switch
TLB/PCID/ASID/VMID effects
entry and per-Domain kernel-state effects
service IPC
async continuation
device queue path
same-Domain batching benefit
resident-slot miss/admission cost
```

Comparisons need containers, KVM, and a microVM baseline under matched security
and workload envelopes. A local selector microbenchmark can reject a bad
mechanism, but cannot establish the datacenter cost claim.

## N-155 Disposition

Historical statement retained:

```text
N-155 completed the v1 declared claim inventory and local overclaim gates.
```

Current statement:

```text
final compositional model complete = false
TOP-001 complete = false
implementation complete = false
protection evidenced = false
cost efficiency evidenced = false
```

Analysis 0109 and its JSON ledger carry a supersession notice. Their IDs,
model, validation record, and original result stay stable.

## Work Order

1. Define validator-owned immutable evidence capsules and revalidation policy.
2. Model Monitor root scheduling against arbitrary Linux selector corruption.
3. Model global Domain identity with bounded per-CPU residency.
4. Compose privileged entry, MemoryView, TLB, stacks, and executable sealing.
5. Model exhaustive mutable-state ownership, service compromise, and management
   trust/recovery boundaries.
6. Model partition-aware leases, fencing, migration, and namespace uniqueness.
7. Build the assume/guarantee composition and architecture refinement ledger.
8. Define and then execute the complete granularity/cost evaluation contract.
9. Re-evaluate R6 or its successor as a local implementation mechanism.

The order is dependency-driven. Selector performance does not resolve a missing
root scheduler, and more local model checking does not resolve incompatible
component assumptions.

## Immediate Stop/Continue Decisions

Continue:

```text
Linux source reading
negative and counterexample preservation
component model refinement
architecture composition
evidence-pipeline repair
R6 preservation as a bounded local mechanism candidate
```

Pause:

```text
R6 E4 measurement as an assurance promotion gate
new behavior-changing Linux scheduler patches
claims that N-155 completed the final system model
claims that 64 slots bound node-wide Domain cardinality
```

## Non-Claims

This audit does not prove the new requirements, select an exact Monitor
scheduler, approve a Linux hook, prove process-scale performance, prove
partition safety, prove model composition, invalidate useful negative evidence,
or establish hypervisor-grade protection.
