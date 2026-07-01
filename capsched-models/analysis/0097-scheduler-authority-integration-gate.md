# Analysis 0097: Scheduler Authority Integration Gate

Status: Draft integration model gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

This note returns the recent scheduler authority refinements to the core
`LinuxSchedulerAuthority` model.

The integration rule is:

```text
Running is allowed only when all required authority layers are fresh at the
same boundary.
```

The recent gates are individually useful, but they are not sufficient if a
future patch satisfies one layer while silently substituting another Linux
state for a missing layer.

This gate composes:

```text
F1 admission-freeze:
  wake/enqueue publication requires a complete FrozenRunUse tuple

selected-state settlement:
  class/core/proxy/sched_ext pick state must settle before execution

server epoch:
  fair/ext/DL server borrowing requires a fresh ServerBorrowTicket

deadline compatibility:
  Linux CBS/GRUB constrains deadline execution but never mints authority

monitor root budget:
  production execution requires monitor-owned timer/budget/token/epoch roots
```

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

Integration source anchors:

| Layer | Current upstream anchor | Integration meaning |
| --- | --- | --- |
| F1 wake boundary | `kernel/sched/core.c:4295` through `:4357` | fail-capable authority freeze must precede `TASK_WAKING` |
| remote wake publication | `kernel/sched/core.c:4378` through `:4380` | remote wake-list state cannot carry raw authority |
| enqueue-visible activation | `kernel/sched/core.c:3805` through `:3827`, `kernel/sched/core.c:4067` through `:4078` | activation consumes frozen authority |
| new task initial enqueue | `kernel/sched/core.c:4935` through `:4964` | Spawn/admission freeze must precede initial runnable state |
| selected-state core | `kernel/sched/core.c:6124` through `:6161` | fast path, class iteration, and `RETRY_TASK` require settlement |
| core scheduling/proxy path | `kernel/sched/core.c:6216` through `:6440` | core/proxy selected state must not bypass authority |
| switch commit | `kernel/sched/core.c:7061` through `:7234` | `rq->curr` and context switch are commit/activation boundaries |
| Linux tick/accounting | `kernel/sched/core.c:5762` through `:5874` | donor/current accounting is observation or compatibility, not root authority |
| fair server start | `kernel/sched/fair.c:7891` | fair server lifecycle can require server tickets |
| fair server retry | `kernel/sched/fair.c:9950` | server/class retry cannot be execution authority |
| fair server init | `kernel/sched/fair.c:9969` | server identity is Linux scheduler state, not root authority |
| deadline CBS/GRUB | `kernel/sched/deadline.c:920`, `:1013`, `:1416`, `:2388`, `:2428` | CBS/GRUB constrains deadline compatibility only |
| deadline server fields | `kernel/sched/core.c:128`, `:6130`, `:6241`, `:6260` | server fields require fresh ticket relation before lower task execution |
| monitor timer reference substrate | `arch/x86/kvm/vmx/vmx.c:6218`, `:7395`, `:7413`, `:8315` | reference shape for VMX timer/deadline, not current implementation |

## Integrated Required Subjects

The model treats these as distinct subjects:

```text
FrozenRunUse:
  task generation, Domain epoch, SchedContext, placement, root-budget ticket

WakePublication:
  TASK_WAKING, wake_list, enqueue-visible state, initial enqueue

SelectedUse:
  class/core/proxy/sched_ext selected state after retry has settled

ServerBorrowTicket:
  server kind, server epoch, live server state, lower task authority

DeadlineCompatibility:
  DL admission, CBS runtime availability, GRUB/CBS throttle state

MonitorRootActivation:
  monitor timer, monitor root budget, sealed RunToken, fresh Domain epoch

LinuxObservation:
  runtime accounting, class runtime, deadline runtime, server runtime,
  placement fallback, trace evidence
```

## Gate Rule

A future scheduler authority patch is blocked unless the execution edge
preserves all of:

```text
1. Wake/enqueue publication implies a complete frozen tuple.
2. Running implies a complete frozen tuple.
3. Running implies class/core/proxy selected-state settlement and no pending
   retry.
4. Server-backed execution implies a fresh ServerBorrowTicket, live server
   state, and lower-task authority.
5. Deadline execution implies Linux DL admission and available CBS runtime, and
   is blocked while CBS-throttled.
6. Running implies monitor-owned root timer, root budget, sealed RunToken, and
   fresh monitor epoch.
7. Linux runtime, server runtime, DL admission/CBS/GRUB, and placement fallback
   never mint or replace CapSched authority.
8. Raw cap handles and heavy authority lookup do not cross wake publication.
```

## Integration Model

New model:

```text
formal/0075-scheduler-authority-integration-gate-model/
```

Checked invariants:

```text
NoPublicationWithoutFrozenTuple
NoRunWithoutFrozenTuple
NoRunWithoutSelectedSettlement
NoRunWithoutServerAuthority
NoRunWithoutDeadlineCompatibility
NoRunWithoutMonitorRoot
NoRawCapAfterPublication
NoHeavyLookupAfterPublication
NoLinuxRuntimeAsAuthority
NoServerRuntimeAsAuthority
NoDeadlineCompatibilityAsAuthority
NoPlacementAsAuthority
NoFailClosedRunning
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
TASK_WAKING/wake_list/enqueue publication before frozen tuple
running with incomplete frozen tuple
running before selected-state settlement or while retry is pending
server-backed running without fresh server ticket, server epoch, live server,
  or lower task authority
deadline running without DL admission or CBS runtime, or while CBS-throttled
running without monitor timer, root budget, sealed token, or monitor epoch
Linux runtime accounting as root budget authority
Linux server runtime as server ticket authority
Linux DL admission/CBS/GRUB as RunCap or monitor budget authority
placement/cpuset/hotplug result as execution authority
raw cap handles or heavy authority lookup after publication
fail-closed state still running
protection claim without implementation and attack evidence
```

## Non-Claims

This gate does not approve a Linux hook, task field, scheduler behavior change,
public ABI, monitor ABI, tracepoint ABI, runtime coverage result, monitor
verification, architecture timer implementation, or production protection.
