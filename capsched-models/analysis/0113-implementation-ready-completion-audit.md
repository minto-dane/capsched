# Analysis 0113: Implementation-Ready Completion Audit

Status: Design-readiness audit; not complete for implementation-ready claim

Date: 2026-07-02

## Purpose

Audit the current state against the active goal:

```text
Make the design implementation-ready and deeply checked.
Actual implementation is out of scope.
```

This document prevents accidental narrowing of the goal to "P2 passed." P2 is
important evidence, but implementation-ready design requires stronger
cross-path proof obligations before any new Linux patch should be proposed.

## Current Evidence

Current Linux implementation state:

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Current validated implementation evidence:

```text
P1 private object vocabulary: implemented and full-build validated
P2 task identity shadow: implemented and validated
P2 patch queue replay: passed to exact final HEAD
P2 full vmlinux off/on: passed
P2 task layout off/on: passed
P2 QEMU boot/workload off/on: passed
```

Current scope decision:

```text
ADR-0011: no new Linux implementation in the current scope
analysis/0112: P3/P4 source anchors verified as design-only
```

## Completion Verdict

Implementation-ready design is not complete yet.

The project is past the first validated lifecycle scaffold, but it has not yet
closed the design obligations needed to safely propose P3/P4/P5 implementation.

## Requirement Audit

| Requirement | Current Evidence | Verdict |
| --- | --- | --- |
| No new implementation in current scope | ADR-0011, clean Linux tree at P2 | Satisfied |
| P2 lifecycle identity scaffold validated | implementation/0022, validation/0133, validation/0134 | Satisfied |
| P3 source anchors verified | analysis/0112 | Partially satisfied |
| P3 no-behavior/no-ABI patch contract | implementation/0023 | Needs scope refresh before implementation |
| P4 final run/move allow-all contract | implementation/0024, analysis/0100 | Needs current-source refresh |
| P5 test-only denial gate | implementation/0025, analysis/0101 | Needs source-specific retry design |
| sched_ext coverage decision | implementation/0025 mentions decision | Open |
| core scheduling cached-pick decision | analysis/0100/0101 identify risk | Open |
| proxy donor/current/executor decision | analysis/0111 identifies risk | Open |
| workqueue/kthread classification | prior async models exist | Open for scheduler-denial scope |
| bounded retry/ineligibility representation | analysis/0101 model gate, analysis/0115 source design | Partially satisfied; source shape documented, model refresh still open |
| negative denial test plan | implementation/0025 lists required tests | Open |
| claim-ledger overclaim guard for implementation | non-claims exist | Open as a concrete gate |
| upstream-drift refresh policy before implementation | prior drift gates exist | Needs re-run before any implementation |

## Hard Blockers Before Implementation Scope Reopens

### B1: sched_ext/core/proxy Coverage Boundary

The design must decide whether these paths are supported, disabled, or
explicitly excluded from protection claims:

```text
sched_ext DSQ custody and fallback
core scheduling cached picks and sibling picks
proxy execution donor/current/executor split
```

Without this decision, a later final run validation point can be bypassed or
mis-accounted by Linux-selected state.

### B2: Bounded Denial Retry Shape

The design must define a Linux-feasible representation for:

```text
denied candidate ineligibility
retry epoch
retry budget
class-state neutralization
balance-callback cleanup
fail-closed condition
```

The model requires these semantics, but a source-specific design is still
needed before implementation. analysis/0115 now records the current-source
shape and the critical finding that pre-`rq->curr` denial may still be
post-class-settlement. This partially closes the source-shape question, but B2
remains open until the model and negative validation plan are refreshed around
pre-settle validation versus post-settle rollback.

### B3: Negative Test Design

Before implementation scope reopens, the project needs tests that fail for the
unsafe designs:

```text
denied candidate reaches rq->curr
same denied candidate selected again in same epoch
sched_ext fallback bypasses denial
core cached pick bypasses freshness
proxy donor/current mismatch charges or authorizes the wrong task
kworker identity is treated as caller authority
```

### B4: Claim Ledger Gate

Every implementation proposal must carry explicit non-claims:

```text
no runtime protection without negative denial evidence
no hypervisor-grade claim without monitor-backed MemoryView/IOMMU/root budget
no production protection without exploit-containment evaluation
no cost-efficiency claim without the evaluation contract
```

## Next Design Work

The next design work should close blockers in this order:

```text
1. sched_ext/core/proxy coverage boundary
2. bounded retry and ineligibility model refresh
3. negative denial validation plan
4. implementation claim-ledger gate
5. upstream-drift recheck plan for reopening implementation scope
```

## Non-Claims

This audit does not approve implementation, P3/P4/P5 code, runtime denial,
runtime coverage, ABI, monitor implementation, monitor verification,
production protection, or cost-efficiency claims.
