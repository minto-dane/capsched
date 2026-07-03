# Analysis 0137: SchedExecLease P5A-R EEVDF Return Dominance

Date: 2026-07-03

Status: source-shape gate. No Linux behavior patch is approved.

## Purpose

P5A-R cannot safely implement:

```text
deny one CFS task and pick the next CFS task
```

until every `pick_eevdf()` return path is understood. A denial check placed
after only the "normal" best-entity path would miss singleton, buddy, protected
current, or final-current-override returns.

This artifact records the current Linux source shape and defines a mechanical
checker for EEVDF return dominance. It is not a Linux patch plan and does not
approve behavior.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
```

## Current `pick_eevdf()` Return Shape

Current direct returns in `kernel/sched/fair.c` are:

```text
line 1148:
  singleton cfs_rq fast path:
    return curr && curr->on_rq ? curr : se;

line 1157:
  next-buddy fast path:
    return cfs_rq->next;

line 1164:
  protected-current fast path:
    return curr;

line 1204:
  final best-entity funnel:
    return best;
```

Leftmost and heap-search candidates do not return directly. They flow through:

```text
leftmost eligible:
  best = se;
  goto found;

heap search:
  best = se;
  break;

found:
  if (!best || (curr && entity_before(curr, best)))
          best = curr;
  return best;
```

This means a future denial design must either make the ineligibility predicate
visible before all four direct returns or must funnel all four returns through a
single checked return path. A post-`task_of(se)` check in `pick_task_fair()` is
not enough to prove EEVDF dominance because group hierarchy selection may
already have selected parent entities.

The semantic candidate families are six, even though there are four syntactic
`return` statements:

```text
1. singleton curr/first
2. next buddy
3. protected current
4. leftmost eligible through best/found
5. heap-search result through best/found
6. final current override through best/found
```

The final `return best` also has a theoretical nullable edge. Current
`pick_next_entity()` immediately dereferences `se->sched_delayed`, so a future
denial design must not introduce a nullable denial result unless it changes the
caller before the dereference and keeps denial separate from delayed dequeue.

## Mechanical Source-Shape Checks

The checker must verify:

```text
pick_eevdf:
  function body is found by symbol/pattern
  direct return count is exactly 4
  singleton return is guarded by cfs_rq->nr_queued == 1
  next-buddy return is guarded by PICK_BUDDY, protect, cfs_rq->next, and
    entity_eligible(cfs_rq, cfs_rq->next)
  protected-current return is guarded by curr, protect, and protect_slice(curr)
  leftmost eligible path assigns best and jumps to found
  heap search path assigns best and breaks to found
  final funnel contains found:, final current override, and return best
  line/order relation is singleton < buddy < protected-current < leftmost <
    heap search < found < return best

pick_next_entity:
  calls pick_eevdf exactly at the source-visible picker boundary
  delayed dequeue is handled after pick_eevdf
  delayed dequeue warning prevents reusing old se after dequeue

pick_task_fair:
  calls pick_next_entity in the schedule-pick descent loop
  descends group_cfs_rq(se) before task_of(se)
  materializes task_of(se) only after hierarchy descent ends
  has an explicit no-queued-cfs path to idle/newidle

wakeup-preempt separation:
  a separate wakeup-preempt use of pick_next_entity exists
  future denial must be gated to active schedule-pick attempts and must not
  bleed into wakeup preemption without a separate model

performance and drift:
  line drift is reported but is not the primary gate
  missing symbols, changed return-site count, changed return-shape order, new
  shortcut returns, or missing funnel evidence block future behavior patches
  future denial designs must not introduce rb_next/rb_first/list_for_each style
  scans, per-cgroup denied maps, or retry bounds derived from nr_queued,
  cgroup depth, or denied-list length
```

## Design Consequence

The first acceptable future implementation shape is not:

```text
se = pick_next_entity(...);
p = task_of(se);
if (deny(p))
        retry;
```

That is too late for hierarchy dominance and can miss direct EEVDF returns.

The acceptable shape must be one of:

```text
Shape A:
  make denial/ineligibility visible to the EEVDF candidate decision before
  every direct return and before the final current override.

Shape B:
  refactor pick_eevdf() into a single checked return funnel without changing
  disabled semantics or hot-path cost.
```

Shape B would be upstream-riskier because it touches a very hot function and
must prove identical disabled behavior, function size, branch layout, and
performance envelope. Shape A is more likely to be reviewable, but only if it
does not add O(n) search, persistent hot layout state, or wakeup-preempt
semantic bleed.

## Non-Claims

This source-shape gate does not approve:

```text
Linux code changes
runtime denial
CFS deny-and-repick implementation
group hierarchy settlement
core/DL/proxy/SCX settlement
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

Use this as the source half of the next P5A-R stage:

```text
1. keep this source-shape checker fresh against upstream
2. add group hierarchy settlement model
3. only then draft an implementation plan for an ordinary-CFS-only,
   off-by-default, test-only denial experiment
```
