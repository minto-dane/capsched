# Analysis 0139: SchedExecLease P5A-R Cross-Path Exclusion/Settlement

Date: 2026-07-03

Status: design/formal/source-shape gate. No Linux behavior patch is approved.

## Purpose

P5A-R is currently scoped to:

```text
ordinary CFS task denial inside the CFS picker
```

That scope is not enough unless Linux scheduler paths outside the ordinary CFS
fast path are either explicitly excluded or separately settled. The current
Linux scheduler can select or transform the next task through:

```text
core scheduling cached picks and sibling picks
deadline servers borrowing fair/ext pickers
proxy execution donor/executor rewriting
sched_ext class selection and switched-all fair takeover
generic class-loop fallback after the fair fast path is not used
```

Therefore, a future CFS deny-one-and-pick-next behavior patch is not ready if it
only hooks `pick_task_fair()` and ignores these paths.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
prior_gate=analysis/0138-sched-exec-lease-p5a-r-group-hierarchy-settlement.md
```

## Current Linux Shape

### Ordinary CFS Fast Path

`__pick_next_task()` uses the direct fair fast path only when `sched_ext` is not
enabled and all runnable tasks are in fair class:

```text
if scx_enabled():
  use restart/class-loop path

if all runnable tasks are fair:
  p = pick_task_fair(rq, rf)
  put_prev_set_next_task(...)
  return p
```

The future P5A-R behavior patch may start here, but this is not the whole
scheduler.

### Core Scheduling

`pick_next_task()` wraps `__pick_next_task()` when `CONFIG_SCHED_CORE` is active
and `sched_core_enabled(rq)` is true. It can:

```text
reuse cached rq->core_pick
pick tasks on sibling runqueues
replace a sibling pick with sched_core_find(rq_i, cookie)
store rq_i->core_pick and later schedule it
steal cookied tasks with try_steal_cookie()
```

These are not ordinary local CFS picks. A denied local CFS task is not enough to
settle cached core picks, sibling picks, or cookie-based movement.

### Deadline Servers

`__pick_task_dl()` treats deadline server entities specially:

```text
dl_se = pick_next_dl_entity(...)
if dl_server(dl_se):
  p = dl_se->server_pick_task(dl_se, rf)
  rq->dl_server = dl_se
```

Current servers include:

```text
fair_server_pick_task() -> pick_task_fair(...)
ext_server_pick_task()  -> do_pick_task_scx(..., force_scx=true)
```

The selected task then receives `next->dl_server = rq->dl_server` through
`put_prev_set_next_task()`. A CFS denial rule cannot safely ignore server
identity, server budget, and server retry semantics.

### Proxy Execution

`__schedule()` may first pick a donor task and then rewrite the execution
context:

```text
next = pick_next_task(...)
rq_set_donor(rq, next)
if next->is_blocked:
  next = find_proxy_task(rq, next, &rf)
```

The donor and the executor can differ. A future SchedExecLease check must either
validate both subjects and their relation or exclude proxy execution from P5A-R.

### sched_ext

`sched_ext` changes class iteration and can take over all fair tasks:

```text
scx_enabled() makes __pick_next_task() avoid the fair fast path
scx_switched_all() skips fair_sched_class in next_active_class()
ext_sched_class.pick_task = pick_task_scx
```

Because `sched_ext` delegates policy to BPF scheduler code and has fallback
semantics, it cannot be treated as the P5A-R security root. It must be excluded
or settled separately.

## Required State Distinctions

```text
OrdinaryCfsPick:
  local fair-class pick in the ordinary CFS fast path.

ClassLoopNonFairPick:
  class-loop pick from any class other than ordinary fair.

CoreCachedPick:
  rq->core_pick reused from a prior core-wide selection.

CoreSiblingPick:
  pick_task(rq_i, rf) performed for a sibling runqueue.

CoreCookieReplacement:
  sched_core_find(rq_i, cookie) replacing a sibling selection.

CoreCookieSteal:
  try_steal_cookie() movement before future execution.

DlFairServerPick:
  deadline server calling fair_server_pick_task().

DlExtServerPick:
  deadline server calling ext_server_pick_task().

ProxyDonorPick:
  task selected as rq->donor before proxy rewrite.

ProxyExecutorPick:
  task returned by find_proxy_task() as actual execution context.

ScxClassPick:
  ext_sched_class pick_task_scx() selection.

ScxSwitchedAll:
  sched_ext state where fair class iteration is skipped.

CrossPathExcluded:
  a current-slice exclusion predicate proves the unsupported path cannot be
  entered while P5A-R denial semantics are claimed.

CrossPathSettled:
  a separate model and source gate validates equivalent SchedExecLease
  semantics for that path.
```

## Required Invariants

```text
P5A-R implementation readiness requires every non-ordinary-CFS path to be
excluded or settled.

ordinary CFS denial must not be claimed while core scheduling is enabled unless
core cached picks, sibling picks, cookie replacement, and cookie steal are
settled.

deadline fair/ext servers must not borrow CFS or SCX picks without explicit
server identity, budget, retry, and next->dl_server settlement.

proxy execution must not collapse donor authority into executor authority, or
executor authority into donor authority.

sched_ext must not be the security root for P5A-R; switched-all and ext class
picks must be excluded or settled.

class-loop fallback must not silently pick unsupported classes after fair
denial.

RETRY_TASK is scheduler retry control flow, not SchedExecLease denial proof.

runtime/protection/cost/datacenter claims remain false.
```

## Accepted P5A-R Direction

The next behavior patch may be prepared only as an ordinary-CFS-only patch if it
contains a clear exclusion predicate for unsupported paths. At this design
level, acceptable exclusion means:

```text
core scheduling: disabled or no P5A-R denial claim
deadline server selection: excluded or no P5A-R denial claim
proxy execution: disabled or no P5A-R denial claim
sched_ext: disabled/not switched-all or no P5A-R denial claim
class-loop non-fair selection: excluded from CFS denial semantics
```

This is not a permanent architecture limitation. It is a slice boundary. Later
work may replace any exclusion with a settlement model and implementation.

## Rejected Design Families

```text
fair-only-hook-with-core-enabled:
  rejected because cached/sibling/core-cookie picks can bypass local CFS denial.

deadline-server-borrow-without-server-settlement:
  rejected because server budget and selected task authority differ.

proxy-donor-equals-executor:
  rejected because proxy execution intentionally separates them.

sched_ext-as-security-root:
  rejected because BPF scheduler policy is not the enforcement root.

class-loop-fallback-after-cfs-denial:
  rejected unless unsupported classes are excluded or settled.

retry-task-as-denial-proof:
  rejected because RETRY_TASK only restarts scheduler selection.

behavior-patch-before-cross-path-gate:
  rejected because it would overclaim ordinary-CFS coverage.
```

## Non-Claims

This gate does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
core scheduling settlement
deadline server settlement
proxy execution settlement
sched_ext settlement
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

After this gate, P5A-R still needs:

```text
no-O(n)/no-hot-layout/disabled-overhead gate
negative validation plan
implementation patch plan
```
