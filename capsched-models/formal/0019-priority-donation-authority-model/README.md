# Priority Donation Authority Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0036-pi-rt-wwmutex-priority-donation-authority.md
```

## Purpose

This model captures the local safety boundary for RT mutex PI, PI futex proxy
locking, scheduler proxy execution, and ww_mutex wound/wait:

```text
priority donation is dependency-derived scheduling order,
not RunCap, not SchedControlCap, not ThreadControlCap, and not free budget.
```

## Modeled Objects

```text
LockWaitCap:
  waiter may block on the lock endpoint

PriorityDonationCap:
  lock endpoint may derive temporary owner boost from a blocked waiter

ProxyExecutionTicket:
  bounded budget ticket for owner execution caused by blocked dependency

WoundWaitCap:
  ww_mutex wound/wait backoff authority, modeled as woundIssued
```

## Checked Invariants

```text
NoDonationWithoutBlockedDependency
NoDonationWithoutDonationCap
NoCrossDomainDonationWithoutEndpoint
NoDonationCreatesRunAuthority
NoDonationCreatesBudget
NoDonationAfterUnlockOrRevoke
NoWoundAsThreadControl
NoProxyChainCycle
```

## Scope Limit

This is not a full rt_mutex or futex model. It does not model rb trees, exact
Linux lock ordering, all timeout/signal paths, real priority comparisons, or
the full proxy-execution scheduler loop. It is a design filter for the
authority split before any behavior-changing CapSched patch.
