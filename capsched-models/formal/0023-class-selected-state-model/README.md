# Class Selected-State Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0040-class-selected-state-boundary.md
```

## Purpose

This model captures the selected-state safety rule:

```text
class pick is selection, not authority.
execution requires class-specific revalidation at execution commit.
```

## Modeled Hazards

```text
running immediately after pick without class revalidation
running with stale FrozenRunUse
using core cached pick after task/core sequence staleness
deadline-server borrowed execution without a typed server ticket
sched_ext slice refill or infinite slice treated as authority
proxy execution running owner with donor authority but no ProxyExecutionTicket
class state mutation after pick without refresh/fail-closed
```

## Checked Invariants

```text
NoRunWithoutFrozenUse
NoRunWithoutClassRevalidation
NoCoreCachedPickWithStaleSeq
NoDlServerBorrowWithoutTicket
NoScxSliceAsAuthority
NoProxyRunWithoutProxyTicket
NoClassMutationRunWithoutRefresh
```

## Scope Limit

This is not a full CFS, RT, DL, SCX, core scheduling, or proxy execution model.
It abstracts exact vruntime, deadline, dispatch queue, core-cookie, and mutex
chain behavior into selected-state hazards. It is a design filter for deciding
where CapSched must revalidate after Linux class-specific selection has settled.
