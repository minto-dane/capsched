# Implementation 0013: Combined Async Adapter Precondition Gate

Status: proposed implementation-facing gate, no Linux patch approved yet

Date: 2026-07-01

Related artifacts:

```text
analysis/0083-direct-call-async-carrier-api-direction.md
implementation/0012-direct-call-async-carrier-api-sketch.md
formal/0059-direct-call-async-carrier-api-sketch-model/
validation/0097-direct-call-async-carrier-api-sketch-tlc.md
analysis/0084-direct-call-workqueue-adapter-refinement.md
formal/0060-direct-call-workqueue-adapter-refinement-model/
validation/0098-direct-call-workqueue-adapter-tlc.md
analysis/0085-direct-call-io-uring-adapter-refinement.md
formal/0061-direct-call-io-uring-adapter-refinement-model/
validation/0099-direct-call-io-uring-adapter-tlc.md
implementation/combined-async-adapter-precondition-gate-v1.json
```

## Purpose

This gate reconciles the shared async carrier core with the dedicated
workqueue and io_uring adapter refinements.

Passing this gate means only:

```text
a future candidate Linux patch proposal may be written against these
preconditions, with the remaining blockers explicit.
```

It does not mean:

```text
Linux code is approved
workqueue integration is approved
io_uring integration is approved
direct-call ABI is approved
public tracepoint ABI is approved
runtime coverage occurred
monitor verification occurred
behavior-changing patches are approved
production protection exists
```

## Gate Rows

### DCADAPT-001: Shared Core Is Authority State Only

Required:

```text
`capsched_async_carrier` remains a shared authority-state core with neutral
operations: freeze, bind, revoke_check, validate, settle, and release.
```

Forbidden fallback:

```text
turning the shared core into a generic Linux async execution subsystem or a
global workqueue/io_uring hook
```

### DCADAPT-002: Adapter Mechanics Stay Separate

Required:

```text
workqueue pending/coalescing/delayed/requeue/cancel mechanics and io_uring
request/resource/io-wq/reissue/CQE mechanics remain separate adapter contracts.
```

Forbidden fallback:

```text
using one adapter's lifecycle as proof for the other adapter
```

### DCADAPT-003: Workqueue Refinement Is Required

Required:

```text
future workqueue carrier proposals must satisfy validation/0098: freeze before
publication, queue_work false first-carrier preservation, rejected second-caller
settlement, no delayed retime or self-requeue receipt refresh, no worker or
rescuer authority, no cancel/flush/pending-clear revoke receipt, caller-budget
settlement, and release separate from Linux work lifetime.
```

Forbidden fallback:

```text
using formal/0059 alone, raw work_struct, pending bit, callback pointer,
kworker identity, cancel, flush, pending clear, or service-only budget as
authority evidence
```

### DCADAPT-004: io_uring Refinement Is Required

Required:

```text
future io_uring carrier proposals must satisfy validation/0099: SQE consumption
before freeze, resource authority binding, resource generation snapshot,
inline/io-wq issue separation, no reissue receipt refresh, no CQE settlement
proof, no cancel revoke receipt, no Linux object authority, no implicit linked
request inheritance, no resource-update mutation of in-flight authority, and no
uring_cmd bypass.
```

Forbidden fallback:

```text
using formal/0059 alone, io_kiocb, io_wq_work, req->creds, req->tctx,
SQPOLL credentials, io_rsrc_node liveness, REQ_F_REISSUE, CQE, cancel, ref
drop, or request free as authority evidence
```

### DCADAPT-005: Effective Authority Is an Intersection

Required:

```text
the adapter must validate that effective authority is a subset of both caller
frozen authority and service/resource authority before endpoint side effects.
```

Forbidden fallback:

```text
service-only authority, caller-only authority, credential snapshots,
namespace membership, cgroup membership, LSM result, worker identity, or
registered-resource liveness as complete authority
```

### DCADAPT-006: Budget and Settlement Are Caller-Scoped

Required:

```text
BudgetTicket reservation, charge, refund, cancel, revoke, completion, retry,
and rejected-candidate settlement are explicitly caller-scoped or derived from
a modeled child ticket.
```

Forbidden fallback:

```text
service-only budget, kworker runtime, io-wq worker runtime, cgroup CPU
accounting, Linux completion, CQE, cancel, ref drop, or free as settlement
proof
```

### DCADAPT-007: Revoke and Freshness Are Not Linux Cleanup

Required:

```text
epoch/generation/revoke checks are explicit and occur before side effects.
Linux cleanup, cancel, flush, pending clear, completion, CQE, ref drop, and
free are synchronization or lifecycle events only.
```

Forbidden fallback:

```text
treating Linux lifecycle cleanup as monitor revoke receipt, receipt refresh,
or stale-carrier rejection proof
```

### DCADAPT-008: Source Anchors and Drift Rules Are Required

Required:

```text
any candidate patch proposal must name the Linux source anchors it touches and
must preserve source-only/semantic-validation/evidence-class flags in the
traceability overlay.
```

Forbidden fallback:

```text
using stale source maps, line-only anchors, source observations, or trace plans
as implementation approval
```

### DCADAPT-009: Evidence Classes Remain Separate

Required:

```text
source maps, small TLC models, build checks, QEMU traces, monitor-backed tests,
and production protection evidence remain separate claim classes.
```

Forbidden fallback:

```text
TLC pass, JSON gate pass, build pass, source anchor, trace plan, or QEMU smoke
as ABI approval, runtime coverage, monitor verification, behavior change, or
production protection
```

### DCADAPT-010: Candidate Patch Scope Is Narrow

Required:

```text
the next Linux proposal may only be a candidate patch plan or inert/no-behavior
scaffolding until the relevant adapter-specific preconditions are satisfied for
the touched surface.
```

Forbidden fallback:

```text
shipping behavior-changing workqueue/io_uring enforcement based only on the
combined precondition gate
```

## Required Evidence Before Any Async Carrier Linux Patch

Before any behavior-changing async carrier Linux patch proposal:

```text
1. DCADAPT-001 through DCADAPT-010 must be satisfied or carried as explicit
   blockers.
2. The proposal must name whether it touches shared core, workqueue adapter,
   io_uring adapter, or source-only traceability.
3. A workqueue-touching proposal must cite validation/0098 obligations and show
   how queue_work false, delayed retime, self-requeue, rescuer, cancel/flush,
   pending clear, and service-only budget are handled.
4. An io_uring-touching proposal must cite validation/0099 obligations and show
   how SQE consume, resource generation, io-wq punt, reissue, cancel, CQE,
   linked request, resource update, and uring_cmd are handled.
5. The proposal must state non-claims for ABI, tracepoints, runtime coverage,
   monitor verification, behavior change, and protection.
6. If any required proof is missing, the patch remains a no-behavior scaffold
   or is blocked.
```

## Exit Rule

This gate can only allow a future candidate patch proposal to be drafted. It
cannot approve Linux behavior changes, direct-call ABI, public tracepoints,
monitor verification, runtime coverage, or production protection.
