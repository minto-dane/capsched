# Analysis 0187: Monitor-Owned Root Scheduling Reference Contract

Status: Accepted model-supported reference contract; implementation policy not
selected; no Linux behavior change approved

Date: 2026-08-09

Work record: N-175

Requirement: `ROOTSCHED-001`

## Question

What is the smallest root-scheduling contract that prevents a compromised
Domain-local Linux scheduler from retaining a CPU, extending a root lease, or
permanently suppressing another admitted guaranteed Domain?

## Verdict

Linux cannot be the source of truth for any fact needed to guarantee another
Domain's service. In particular, Monitor handoff cannot depend on Linux
runnable state, a Linux-maintained Domain queue, a Linux yield, or fairness of
a Linux action.

The first executable reference policy is therefore a Monitor-owned cyclic
reservation frame:

```text
management/recovery -> guaranteed A -> guaranteed B -> best-effort slack
```

Each reserved slot creates a Monitor-known service opportunity with a fresh
root lease. The Monitor-owned timer expires the opportunity and advances the
trusted cursor. Linux may supply best-effort hints and schedule tasks within
the active Domain, but cannot alter the frame, cursor, epoch, lease, timer, or
token.

This selects a semantic lower bound, not the final production algorithm. A
dynamic deadline, deficit, or reservation server is acceptable only if it
refines the same safety and availability obligations.

## Why Runnable Hints Are Insufficient

The attacker controls all Domain-local userspace and may obtain arbitrary
Linux kernel-context execution in the currently active Domain. That attacker
can falsify or withhold:

```text
runnable task state
Linux Domain queues
reschedule requests
yield notifications
load and utilization reports
cgroup throttling state
Linux timer and NO_HZ state
candidate selection and fairness metadata
```

If a reserved Domain is dispatched only after Linux reports it runnable, the
current Domain can suppress that report forever. Weak fairness on a Monitor
action does not repair the design because the malicious hint keeps the action
disabled. The model's `WaitForLinuxHint` counterexample demonstrates exactly
this failure.

The root guarantee is consequently an opportunity guarantee:

```text
Monitor guarantee:
  activate the admitted Domain's fresh root authority within a bounded number
  of completed root slots

not a Monitor guarantee:
  Domain-local Linux runs a useful application task or makes application
  progress during that opportunity
```

An idle or compromised Domain may waste or immediately return its slot. A
future optimization may use a Monitor-authenticated voluntary relinquish or a
trusted service-side readiness source, but an untrusted Linux negative hint
cannot cancel a reserved opportunity.

## Authority Split

| State or action | Owner | Meaning |
| --- | --- | --- |
| Domain admission class | Monitor | Guaranteed, best-effort, or absent |
| Domain epoch | Monitor | Revocation and stale-token fence |
| Root frame/reservation table | Monitor | Minimum periodic service contract |
| Trusted frame cursor | Monitor | Next reservation; never a Linux pointer |
| Root lease and consumed amount | Monitor | Absolute CPU authority for one opportunity |
| Root expiry timer | Monitor/hardware | Forces expiry independently of Linux tick state |
| RunToken seal and frozen tuple | Monitor | Domain, epoch, CPU/slot, activation generation, and MemoryView binding in later refinement |
| Handoff and expiry receipt | Monitor | Old authority cleared before a new activation |
| Linux candidate and shadow cursor | Linux, adversarial | Advisory input only |
| Within-Domain task selection | Active Domain Linux | CFS/EEVDF, RT, deadline, sched_ext, topology, and cgroup policy below the root lease |
| Best-effort slack fill | Monitor validates Linux hint | No guaranteed per-Domain progress |

The reference model uses one root CPU lane. A production multi-CPU design may
use one protected server per CPU or a small partitioned server set. Shared
Monitor scheduling state must remain bounded and race-defined; this model does
not choose that representation.

## Root Slot Transition

For a reserved slot, the abstract transition is:

```text
Monitor cursor names admitted guaranteed Domain
  -> validate current epoch and root admission
  -> mint and seal a fresh activation token
  -> bind token to trusted slot/CPU and later MemoryView tuple
  -> arm immutable Monitor deadline
  -> activate Domain opportunity
  -> hardware consumes finite root quantum
  -> expiry atomically clears active token and timer authority
  -> record departed Domain and pending handoff
  -> advance trusted cursor and bounded-wait counters
  -> dispatch or skip only slots that are Monitor-known unavailable
```

Linux extension requests are observable noise. They cannot change
`leaseIssued`, `leaseRemaining`, or `leaseConsumed`. The accounting invariant
while active is:

```text
leaseRemaining + leaseConsumed = leaseIssued
leaseIssued = monitor-authorized quantum
```

The architecture substrate remains the one required by Analysis 0098: x86
VMX-root or arm64 EL2 timer state, expiry path, budget ledger, and Monitor
state must be protected from Linux. A Linux hrtimer, scheduler tick, hrtick,
NO_HZ callback, KVM guest timer, or Domain-local accounting value cannot be the
root timer.

## Revocation and Management

Revocation increments a Monitor-owned epoch and removes admission. If the
revoked Domain is active, the same transition clears its active root authority
and creates a pending handoff. A slot may be skipped only when the Monitor's
own admission state says its reserved Domain is absent.

Management/recovery is a permanently admitted reserved Domain in this first
contract. It cannot be revoked by the ordinary Domain-revocation action. This
does not make management omnipotent: later `MGMT-001` work must split offline
signing roots, online control, node Monitor, recovery, and break-glass
authority. It only ensures that attacker-controlled Linux cannot starve the
minimum recovery path.

If every other guaranteed Domain is revoked during a pending handoff, the
contract permits returning to management. A handoff obligation is discharged
by either service of another still-admitted guaranteed Domain or authoritative
revocation of all such candidates. Revocation is not allowed to discharge the
management recurring-service obligation.

## Safety Obligations

The model checks:

```text
NoRootRunWithoutLease
NoRootBudgetOverrun
LinuxCannotExtendRootLease
CurrentEpochOnly
ReservedSlotIntegrity
GuaranteedOnlyUsesReservedSlot
BestEffortOnlyUsesSlack
ExpiredOrRevokedAuthorityCleared
BoundedGuaranteedWait
ManagementAlwaysAdmitted
LinuxCannotMintRootAuthority
NoProtectionClaim
```

`BoundedGuaranteedWait` is measured in completed root opportunities, not wall
clock. A wall-clock bound additionally requires architecture-specific maximum
quantum, timer-overrun, Monitor-action latency, interrupt masking, SMI/firmware,
and hardware failure assumptions.

## Availability Obligations

The liveness properties are:

```text
AdmittedGuaranteedEventuallyRuns
GuaranteedRecurringService
ManagementRecurringService
TrustedHandoffProgress
```

Only Monitor dispatch, Monitor close/advance, and hardware lease-step actions
receive weak fairness. Linux receives no fairness assumption. The steady-state
model proves recurring opportunities for all guaranteed Domains. The revoke
model qualifies ordinary guaranteed progress by authoritative revocation while
retaining unconditional recurring management service.

This is stronger than the previous monitor-budget model, which could expire a
Domain and then remain forever in terminal fail-closed stutter. Stopping an
attacker is necessary safety, but it is not sufficient availability for a
datacenter OS.

## Counterexample Matrix

| Fault | Expected failure | Security meaning |
| --- | --- | --- |
| `WaitForLinuxHint` | recurring-service liveness | malicious Linux withholds readiness |
| `SkipReserved` | bounded guaranteed wait | trusted cursor skips an admitted reservation |
| `StealReserved` | reserved-slot integrity | best-effort hint consumes guaranteed capacity |
| `StaleEpoch` | current-epoch-only | revoked authority is reactivated |
| `LinuxExtend` | lease conservation | Linux retimes or replenishes root authority |
| `ExpiryStillRunning` | no budget overrun | expired Domain remains active |
| `StopAfterExpiry` | handoff liveness | Monitor stops attacker but never resumes service |
| `RevokeManagement` | management admission | ordinary revoke removes recovery service |
| `NoTimer` | no run without lease/timer | active execution lacks independent expiry |
| `LinuxMint` | authority provenance | Linux shadow state becomes root authority |

Validation 0288 captures the exact model, configurations, tool, commands, raw
logs, statuses, and validator in EC1 capsule
`d805b92acee2bca93a965e63925f7f48b8bf8d518043b0c55edf9ca3a3210abe`.
Producer and validator executions reproduced both safe state spaces and all
ten intended counterexamples. The capsule-bound decision permits only
`ROOTSCHED-001` Open-to-Model-supported.

## Current Linux and Architecture Anchors

The source review is bound to:

```text
Linux repository: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 74311ca1ac4937e0e62f1e0f6a3e5bfa4fc77d6f
tree: 54f685aad94f28f0027cbba18cf5e29aadce234a
fetched upstream/master: a7c7074b58d28c4206d666a12aa2e33447b3c581
```

Relevant current anchors:

| Surface | Anchor | Contract meaning |
| --- | --- | --- |
| Linux hrtick | `kernel/sched/core.c:960 hrtick_start()` | advisory Linux policy timer only |
| Linux scheduler tick | `kernel/sched/core.c:5766 sched_tick()` | Domain-local accounting/policy, not root expiry |
| Current no-op observation | `kernel/sched/core.c:5783 sched_exec_lease_observe_tick()` | inert prototype marker, explicitly no authority |
| Current no-op helper contract | `include/linux/sched_exec_lease.h:108-137` | states that markers do not validate, deny, charge, or call a Monitor |
| Linux context switch | `kernel/sched/core.c:5455 context_switch()` | future integration surface only; not an approved hook |
| Linux picker | `kernel/sched/core.c:6129 __pick_next_task()` and `:6221 pick_next_task()` | within-Domain policy candidate, not root scheduler |
| x86 preemption exit | `arch/x86/kvm/vmx/vmx.c:6218 handle_preemption_timer()` | mechanism reference, currently KVM guest-timer behavior |
| x86 timer programming | `arch/x86/kvm/vmx/vmx.c:7395 vmx_update_hv_timer()` and `:8315 vmx_set_hv_timer()` | mechanism reference; mutable KVM vCPU timer state is forbidden as Domain root authority |
| arm64 EL2 trap control | `arch/arm64/kvm/hyp/nvhe/timer-sr.c:23` and `:41` | architecture mechanism reference, not an existing root scheduler |

No source anchor selects an implementation. The current Linux scaffold remains
inert and Linux is unchanged by this work.

## Cost and Scale Consequences

The reference contract preserves the intended fast path:

```text
ordinary syscall and same-Domain task switch:
  no Monitor transition required by ROOTSCHED

root lease boundary, revoke, or Domain switch:
  Monitor transition required
```

Larger quanta reduce Monitor transitions and MemoryView/TLB cost but increase
the service bound and maximum interference window. Smaller quanta improve
latency and recovery but cost more transitions. A production server must make
this tradeoff explicit by service class and measured architecture bounds.

Fixed reservations can waste idle capacity. Best-effort slack recovers only
declared slack in this model. Future work may safely reclaim an early-returned
reserved slot, but must not let Linux-originated readiness suppression erase
the next guaranteed opportunity.

Global Domain cardinality is deliberately absent. `RESIDENCY-001` must map
stable global Domain identity and admission leases into a bounded per-CPU
resident set. It may replace the literal frame with a verified server, but it
must preserve Monitor-owned progress and management reservation.

## Refinement Boundary

This model composes and strengthens:

```text
formal/0005 Domain activation
formal/0071 Monitor root budget expiry
formal/0076 architecture timer substrate
formal/0012 adversarial Linux scheduler authority
```

It does not yet compose MemoryView activation, entry/return, executable
integrity, per-Domain mutable state, IOMMU/device queues, async carriers,
service compromise, global residency, cluster partitions, or cost evidence.
Those remain named obligations in Plan 0006.

## Non-Claims

This analysis and model do not choose a production Monitor scheduler, reserve
table representation, Linux hook, VMX-root implementation, EL2
implementation, interrupt priority, wall-clock service bound, multi-CPU
algorithm, dynamic admission protocol, global residency protocol, public ABI,
or Linux patch. They do not prove Monitor code, hardware behavior, protection,
availability under hardware/firmware failure, performance, cost efficiency,
multi-node operation, multi-cluster operation, or hypervisor replacement.
