# Analysis 0131: SchedExecLease P5A0 No-Behavior Infrastructure Proposal

Date: 2026-07-02

Status: P5A0 proposal recorded; no Linux patch approved.

## Purpose

P5A scope is recorded in analysis/0130. The next safe step is P5A0:

```text
no-behavior infrastructure proposal
```

P5A0 exists because both harder directions are still blocked:

```text
P5A-R:
  deny-one-CFS-and-pick-next needs fair-picker eligibility integration.

P5A-M:
  broad common move denial needs status settlement across migration, affinity,
  swap, push, and core-cookie-steal paths.
```

Therefore P5A0 must not deny anything. It defines the shape of a future
no-behavior patch that may make later behavior work reviewable.

## Source Basis

```text
linux_repo: /media/nia/scsiusb/dev/linux-cap/linux
linux_branch: capsched-linux-l0
linux_commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
linux_subject: sched/exec_lease: Add allow-only validation skeleton
```

Current blocker basis:

```text
analysis/0129-sched-exec-lease-p5-readiness-refresh-after-p4.md
analysis/0130-sched-exec-lease-p5a-scope-proposal.md
validation/0151-sched-exec-lease-p5-readiness-after-p4.md
validation/0152-sched-exec-lease-p5a-scope-gate.md
```

## P5A0 Allowed Shapes

P5A0 may propose, but not yet implement, the following no-behavior patch shapes:

```text
status plumbing shape:
  make future move/run validation status observable to callers without changing
  the current allow-only outcome.

test harness shape:
  define internal-only test observables for later denied-not-running and
  denied-not-moved tests.

setup-time path-disable shape:
  define how future test-denial setup would refuse unsupported paths.

claim ledger shape:
  define the evidence-to-claim row required before any behavior patch.
```

The first possible P5A0 Linux patch, if later approved, must still be:

```text
CONFIG_SCHED_EXEC_LEASE=n:
  no object or behavior impact

CONFIG_SCHED_EXEC_LEASE=y:
  helpers still return ALLOW
  scheduler still does not branch on non-ALLOW
  no runtime denial
  no retry
  no fail-closed
  no quarantine
  no task_struct, rq, sched_entity, or cfs_rq layout change
  no hot-path allocation, sleeping call, monitor transition, exported symbol,
  public tracepoint ABI, or public ABI
```

## Move Status Plumbing Shape

The future no-behavior move plumbing may use a status carrier such as:

```text
common move:
  result contains resulting rq plus validation result
  ALLOW path is identical to today
  non-ALLOW path is not reachable in P5A0

locked move:
  helper returns validation result
  callers ignore or assert ALLOW only
  non-ALLOW path is not reachable in P5A0
```

Required no-behavior rules:

```text
no caller changes success/failure behavior
no caller completes or withholds waiters differently
no caller skips resched differently
no task CPU placement changes
no new retry loop
no new fail-closed path
no public ABI
```

`sched_exec_lease_note_queued_move()` may be split later into ALLOW and DENIED
receipts, but P5A0 may only record the planned split. It must not create a
runtime denied receipt.

## Run Status Plumbing Shape

P5A0 must not use the current P4 final-run helper as a denial hook.

It may propose a future internal status plumbing shape that records:

```text
candidate task identity
candidate generation
edge kind
candidate CPU
whether status is pre-settle or post-settle
whether status is observation-only
```

For P5A0, this status must remain observation-only and ALLOW-only.

Any future run-denial patch must still come from P5A-R after fair-picker
eligibility integration or a separate rollback proof.

## Test Harness Shape

P5A0 may define internal test observables for future negative tests:

```text
denial injection point id
candidate task pointer or stable test id
task generation
edge kind
candidate CPU or destination CPU
validation result
settlement point
rq->curr observation
sched_switch observation
context_switch observation
move mutation observation
waiter completion observation
claim flags
```

These observables must be:

```text
internal-only
not public tracepoint ABI
not syscall/ioctl/sysfs/procfs/debugfs ABI
not monitor ABI
```

## Setup-Time Disable Shape

Future test-denial setup must refuse or mark unsupported:

```text
sched_ext
core scheduling
proxy execution
RT
deadline
fair direct detach/attach
idle as authority
stopper/hotplug/migration kthreads as ordinary Domain execution
generic kthreads/workqueues
io_uring workers
```

P5A0 may only describe this shape. It must not change setup behavior unless a
separate no-behavior patch is proposed and validated.

## Required Before a P5A0 Patch

Before a P5A0 Linux patch is reviewable:

```text
fresh upstream drift row for touched groups
patch queue plan
source checker plan
full build off/on plan
QEMU denial-disabled smoke plan
object/symbol review plan
hot-path codegen and layout review plan
negative harness plan
claim ledger row
explicit non-claims
```

Before accepting a P5A0 Linux patch:

```text
patch queue replay
checkpatch
source checker proving no non-ALLOW reachable behavior
source checker proving scheduler does not branch on validation result
CONFIG off/on build
QEMU denial-disabled boot/workload smoke
object/symbol review
overclaim review
```

## Non-Claims

This proposal does not approve Linux code changes, behavior changes, runtime
denial, retry, fail-closed behavior, quarantine, task-field changes, ABI,
tracepoint ABI, monitor calls, monitor verification, runtime coverage,
production protection, hypervisor-grade isolation, cost-efficiency, deployment
readiness, or datacenter readiness.
