# Analysis 0086: Linux Upstream Drift and Maintenance Review

Status: current-source review complete; no new Linux patch recommended

Date: 2026-07-01

Related artifacts:

```text
implementation/0014-linux-async-carrier-candidate-patch-plan.md
implementation/linux-async-carrier-candidate-patch-plan-v1.json
formal/0063-linux-async-carrier-patch-scope-model/
validation/0101-linux-async-carrier-patch-scope-tlc.md
linux branch: capsched-linux-l0
```

## Purpose

N-130 left one narrow Linux-facing possibility open: a separate no-behavior
opaque async-carrier type patch. This review asks whether adding that patch now
is actually worth the maintenance cost.

The answer for the current tree is no.

That is not because the current branch is hard to rebase. It is because the
current branch is still easy to rebase, and adding names before a concrete
consumer exists would spend that advantage without improving protection,
runtime evidence, or implementation readiness.

## Current Source Observations

Local Linux work branch:

```text
branch: capsched-linux-l0
base:   4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
head:   7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Current L0 patch footprint relative to base:

```text
include/linux/capsched.h
init/Kconfig
kernel/sched/Makefile
kernel/sched/capsched.c
```

Patch size:

```text
4 files changed, 115 insertions(+)
```

Fetched upstream state:

```text
upstream/master: 665159e246749
base..upstream/master: 340 commits
latest observed commit: Merge tag 'probes-fixes-v7.2-rc1'
```

Watched path drift from base to fetched upstream:

```text
M kernel/sched/cpufreq_schedutil.c
```

No observed fetched-upstream changes in this watch set:

```text
include/linux/sched.h
include/linux/capsched.h
init/Kconfig
kernel/sched/Makefile
kernel/sched/core.c
kernel/sched/sched.h
kernel/workqueue.c
io_uring/
kernel/fork.c
fs/exec.c
kernel/exit.c
```

Mechanical merge-tree result:

```text
git merge-tree --write-tree upstream/master capsched-linux-l0
exit_code=0
result_tree=cda01cf9b8c171e29869170aa160ad0724cc9ad4
```

## Interpretation

The current L0 patch is low-drift:

```text
- It adds two CapSched files.
- It adds one Kconfig option under scheduler features.
- It adds one scheduler Makefile object line.
- It does not touch task_struct, workqueue, io_uring, scheduler core, fork,
  exec, exit, cgroup, LSM, or UAPI.
```

That is a strength. It means upstream churn can currently be handled with a
small rebase surface.

Adding async-carrier names now would not break that property by itself if the
patch is only forward declarations. But it would create a new commitment:

```text
the Linux tree would contain names for an async carrier design whose concrete
storage, lifetime, locking, ownership, and adapter boundaries are not yet
approved for implementation.
```

That is dangerous mostly as a process hazard, not as an immediate code hazard.
It can cause future work to treat names as accepted architecture.

## Decision

Do not add the no-behavior async-carrier Linux patch now.

The current decision is:

```text
defer Linux async-carrier scaffolding
continue model/source/traceability work
preserve the tiny L0 Linux footprint
```

The future decision point is different:

```text
if a concrete out-of-tree CapSched consumer is blocked by missing opaque names,
then draft a separate no-behavior patch proposal and run the maintenance gate
again.
```

## Maintenance Gate for Any Future No-Behavior Patch

A future no-behavior opaque type patch must pass all of these gates:

```text
1. concrete consumer need exists
2. upstream/master has been freshly fetched
3. current base..upstream watched-path drift is recorded
4. merge-tree or equivalent rebase-conflict check exits clean
5. patch footprint is isolated and reviewable alone
6. touched files are limited to an approved no-behavior boundary
7. no callable function prototype is added
8. no object layout is added
9. no allocation, refcount, lock, callback, or lifetime rule is added
10. no workqueue, io_uring, scheduler-core, task_struct, fork, exec, exit, LSM,
    cgroup, namespace, tracepoint, debugfs, sysfs, ioctl, syscall, UAPI, module
    parameter, static key, or monitor-call surface is added
11. CONFIG_CAPSCHED=n and CONFIG_CAPSCHED=y build expectations are explicit
12. commit text repeats non-claims: no behavior change, no runtime coverage,
    no monitor verification, no production protection
```

Failure of any gate means no Linux patch.

## Drift Classes

### Class D0: No Relevant Drift

Watched paths do not move, merge-tree is clean, and the proposed patch remains
inside the no-behavior boundary.

Result:

```text
still do not patch unless concrete consumer need exists
```

### Class D1: Nearby but Non-Intersecting Drift

Example from this review:

```text
kernel/sched/cpufreq_schedutil.c changed, but CapSched L0 does not touch it.
```

Result:

```text
record drift, keep no-behavior patch deferred unless concrete need exists
```

### Class D2: Direct Footprint Drift

Examples:

```text
init/Kconfig scheduler feature menu changed
kernel/sched/Makefile object structure changed
include/linux/capsched.h appears upstream
```

Result:

```text
no new Linux patch until the L0 patch queue is refreshed and rebuilt
```

### Class D3: Future Attachment-Point Drift

Examples:

```text
kernel/workqueue.c changed around queue_work/pending/execution/cancel
io_uring request, io-wq, CQE, cancellation, linked request, or resource update
paths changed
kernel/sched/core.c enqueue/pick/tick/switch paths changed
kernel/fork.c, fs/exec.c, or kernel/exit.c task identity paths changed
```

Result:

```text
no behavior-changing CapSched patch
refresh source maps and rerun the relevant formal/source gates first
```

### Class D4: Semantic Drift

The code may still merge cleanly, but an upstream change alters a meaning that
CapSched relies on, such as:

```text
queue coalescing
worker execution identity
io_uring reissue behavior
runtime accounting
task generation/lifetime ordering
IRQ/DMA ownership semantics
```

Result:

```text
the affected model is stale even if Git reports no conflict
```

## Unsafe Patterns

These patterns must be rejected:

```text
- using a clean merge-tree result as proof that the semantic model is fresh
- adding opaque names because they feel inevitable
- naming concrete async providers before storage/lifetime is approved
- adding function prototypes that imply callable semantics
- adding object layout, refcounts, locks, callbacks, or registration tables
- introducing tracepoints as a "harmless" public observation ABI
- treating no-behavior scaffolding as implementation progress toward protection
- claiming runtime coverage, monitor verification, or hypervisor-grade security
```

## Current Recommendation

For the current tree:

```text
do not patch Linux for async carriers
keep L0 as-is
record upstream drift and clean merge evidence
continue with source-drift automation and model freshness gates
```

The next useful work is not a new C declaration. It is a reusable update gate:

```text
fetch upstream
compute watched-path drift
classify drift D0-D4
run merge-tree
decide whether models/source maps are stale
only then consider patch movement
```

## Independent Critical Review

Two biased reviews were used as a check on this decision.

Maintenance/rebase review:

```text
default outcome: do not add async-carrier scaffolding now
reason: the tiny L0 footprint is currently valuable and should not be expanded
without a concrete consumer need
```

Security/model-completion review:

```text
N-131 must be a negative gate, not an implementation milestone
opaque names are at most traceability, not carrier semantics, authority,
lifetime management, enforcement, monitor verification, or protection
```

Both reviews reject these false-progress patterns:

```text
logging-only hooks that alter timing or execution paths
public tracepoints that become receipt substitutes
empty callable prototypes that define an API before semantics are proven
compile-only stubs that imply an async subsystem exists
TLC safe runs treated as Linux runtime assurance
generic async unification before workqueue and io_uring hazards are closed
future HyperTag design treated as current isolation evidence
```

## Non-Claims

This review does not approve Linux code, async carrier implementation,
workqueue integration, io_uring integration, direct-call ABI, tracepoints,
runtime coverage, monitor verification, behavior change, or production
protection.
