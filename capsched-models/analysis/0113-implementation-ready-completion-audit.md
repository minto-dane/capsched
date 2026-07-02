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
| P5 test-only denial gate | implementation/0025, analysis/0101, analysis/0117, analysis/0118 | Needs drift gate before implementation scope |
| sched_ext coverage decision | analysis/0114, analysis/0117 | Satisfied for initial P5: disabled, not covered |
| core scheduling cached-pick decision | analysis/0100/0101, analysis/0114, analysis/0117 | Satisfied for initial P5: disabled, not covered |
| proxy donor/current/executor decision | analysis/0111, analysis/0114, analysis/0117 | Satisfied for initial P5: disabled, not covered |
| workqueue/kthread classification | prior async models, analysis/0117 | Satisfied for initial P5: excluded, future typed async required |
| bounded retry/ineligibility representation | analysis/0101, analysis/0115, formal/0088, validation/0135 | Partially satisfied; source shape and model refresh done, implementation test evidence still future |
| negative denial test plan | implementation/0025, analysis/0116 | Partially satisfied; design plan exists, future implementation tests still open |
| claim-ledger overclaim guard for implementation | analysis/0118, formal/0090, validation/0137 | Satisfied as a design gate; future proposals must include ledger row |
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

analysis/0117 closes B1 for the first P5 test-only denial scope by classifying:

```text
supported:
  ordinary CFS final run in a non-core, non-proxy, non-sched_ext configuration
  common queued move through move_queued_task() / move_queued_task_locked()

disabled:
  sched_ext
  core scheduling
  proxy execution

excluded:
  fair direct load balance
  RT
  deadline
  idle exception
  stopper/hotplug/migration kernel threads
  generic kthreads/workqueues
  io_uring workers
```

formal/0089 and validation/0136 check that this classification cannot support
runtime coverage, implementation approval, production protection, or
cost-efficiency claims. B1 remains a future full-support requirement, but it is
no longer an open ambiguity for the narrow initial P5 test-only denial gate.

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
needed before implementation. analysis/0115 records the current-source shape
and the critical finding that pre-`rq->curr` denial may still be
post-class-settlement. formal/0088 and validation/0135 refresh the model around
pre-settle validation versus post-settle rollback. B2 remains open only in the
sense that implementation-level test evidence is future P5 work.

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

analysis/0116 records the design-only negative validation plan. It does not
approve test instrumentation or implementation, but it fixes the required
unsafe cases and observables for future P5 review.

### B4: Claim Ledger Gate

Every implementation proposal must carry explicit non-claims:

```text
no runtime protection without negative denial evidence
no hypervisor-grade claim without monitor-backed MemoryView/IOMMU/root budget
no production protection without exploit-containment evaluation
no cost-efficiency claim without the evaluation contract
```

analysis/0118 closes B4 as a design gate. It requires every future
implementation proposal to carry a machine-readable claim ledger row naming:

```text
evidence classes present
supported claims
forbidden claims
open gaps
validation before review
validation before acceptance
upstream drift freshness
safety flags
```

formal/0090 and validation/0137 check that missing ledger rows and overclaims
are rejected, including implementation approval without reopened scope,
implementation approval with stale drift, behavior change without P5 evidence,
runtime denial without denied-candidate trace evidence, runtime coverage
without trace coverage, monitor verification without monitor roots, production
protection without monitor/evaluation evidence, hypervisor-grade claim from
Linux-only P5 evidence, cost-efficiency without evaluation, public ABI without
ABI gate, model-only production claim, and compatibility-as-protection.

## Next Design Work

The next design work should close blockers in this order:

```text
1. upstream-drift recheck plan for reopening implementation scope
2. final implementation-ready audit
```

## Non-Claims

This audit does not approve implementation, P3/P4/P5 code, runtime denial,
runtime coverage, ABI, monitor implementation, monitor verification,
production protection, or cost-efficiency claims.
