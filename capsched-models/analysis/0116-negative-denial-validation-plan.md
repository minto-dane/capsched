# Analysis 0116: Negative Denial Validation Plan

Status: Design-only negative validation plan; no implementation approved

Date: 2026-07-02

## Purpose

Convert analysis/0115 and validation/0135 into a future P5 negative-test plan.

The goal is to ensure that a future test-only denial implementation fails for
the unsafe designs before any runtime enforcement claim is allowed.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Model basis:

```text
analysis/0115-bounded-retry-ineligibility-source-design.md
formal/0088-final-deny-source-shape-gate-model/
validation/0135-final-deny-source-shape-gate-tlc.md
```

## Required Negative Tests

| ID | Unsafe Design | Required Evidence |
| --- | --- | --- |
| NDENY-001 | Post-settle denial without rollback | Denial after `put_prev_set_next_task()` or class equivalent is rejected unless rollback proof is enabled |
| NDENY-002 | Denied candidate reaches `rq->curr` | Trace or test assertion shows denied task never reaches `RCU_INIT_POINTER(rq->curr, next)` or `sched_switch` |
| NDENY-003 | Same candidate repick | Same task/generation cannot be selected again in the same retry epoch |
| NDENY-004 | Class picker cannot see ineligibility | CFS/RT/DL class selection must consult or be wrapped by retry-epoch ineligibility |
| NDENY-005 | sched_ext local DSQ head livelock | Denied SCX head task is removed, requeued, quarantined, or sched_ext is disabled/excluded |
| NDENY-006 | sched_ext fallback bypass | Global DSQ, bypass DSQ, direct dispatch, and server pick cannot run a denied task |
| NDENY-007 | Core cached pick bypass | Denial invalidates or revalidates sibling `core_pick` state before cached consumption |
| NDENY-008 | Core cookie steal bypass | `try_steal_cookie()` move edge cannot move a denied or destination-invalid task |
| NDENY-009 | Proxy donor/executor mismatch | Denial and budget subject explicitly name donor, executor/current, or both |
| NDENY-010 | Proxy cleanup breaks mutex handoff | Denial cleanup cannot silently destroy required `blocked_donor` handoff semantics |
| NDENY-011 | Fail closed with eligible candidate | Fail-closed path is rejected while any supported ordinary Domain candidate remains eligible |
| NDENY-012 | Linux retry machinery as authority | `RETRY_TASK`, `pick_again`, idle fallback, sched_ext fallback, and class priority are rejected as authority |
| NDENY-013 | kworker identity as caller authority | kworker/service execution cannot inherit caller authority without typed async carrier evidence |
| NDENY-014 | Claim overreach | Runtime coverage, monitor verification, production protection, and cost-efficiency claims remain false |

## Validation Layers

### Model Layer

Already covered by validation/0135:

```text
post-settle denial without rollback
class picker invisible ineligibility
same candidate repick
sched_ext head livelock
core cached pick bypass
proxy subject mismatch
fail closed while eligible
authority substitution
claim overreach
```

### Future Build/Test Layer

Once implementation scope is explicitly reopened, the first P5 patch must add
test-only denial mode evidence for:

```text
CONFIG_SCHED_EXEC_LEASE=n full build still unchanged
CONFIG_SCHED_EXEC_LEASE=y denial disabled full build still unchanged
test-only denial config builds
QEMU boot/workload with denial disabled still passes
QEMU negative denial workload with denial enabled observes denial before
  class settlement or observes rollback proof
trace/kprobe/ftrace evidence denied task does not reach rq->curr or
  sched_switch
retry epoch evidence same candidate/generation is not reselected
fail-closed evidence or explicit unsupported note
```

### Source Coverage Layer

Before accepting P5 test-only denial, the implementation must record one of:

```text
supported:
  CFS/RT/DL/sched_ext/core/proxy path has negative tests.

disabled:
  path is disabled while test denial is enabled.

excluded:
  path is explicitly excluded and runtime coverage/protection claims are
  impossible for that configuration.
```

## Required Test Observables

A future denial test needs at least:

```text
task pointer or stable test identifier
task generation
domain epoch or placeholder epoch
retry epoch
candidate CPU
denial result: RETRY, INELIGIBLE, or QUARANTINE
class path: CFS, RT, DL, SCX, core, proxy, or exception
class settlement point: pre-settle, rollback-proved, or forbidden
rq->curr publication observation
sched_switch observation
fail-closed reason if applicable
claim flags all false
```

These observables may be internal test instrumentation. They must not become a
public ABI or production tracepoint ABI without a separate gate.

## Implementation-Ready Consequence

P5 is not ready until the project has:

```text
analysis/0115 source-shape design
formal/0088 source-shape model
validation/0135 TLC evidence
this negative validation plan
explicit path classification for sched_ext/core/proxy/workqueue
future test harness design for denied-not-running and same-candidate-repick
```

Even after those are present, P5 remains test-only and off by default until
implementation scope is explicitly reopened.

## Non-Claims

This plan does not approve Linux code, scheduler hooks, test instrumentation,
runtime denial, runtime coverage, user ABI, public tracepoint ABI, monitor ABI,
monitor verification, production protection, or cost-efficiency claims.
