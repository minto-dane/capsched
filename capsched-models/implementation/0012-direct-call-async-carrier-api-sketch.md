# Implementation 0012: Direct-Call Async Carrier API Sketch

Status: proposed no-behavior API sketch, no Linux patch approved yet

Date: 2026-07-01

Related artifacts:

```text
capsched-ai/decisions/ADR-0009-async-carrier-api-direction.md
analysis/0083-direct-call-async-carrier-api-direction.md
analysis/direct-call-async-carrier-api-direction-v1.json
analysis/0082-direct-call-async-carrier-lifetime-table.md
implementation/0011-direct-call-async-carrier-gate.md
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
validation/0095-direct-call-async-carrier-api-direction-result.md
implementation/direct-call-async-carrier-api-sketch-v1.json
```

## Purpose

This sketch defines the shape of a future internal
`capsched_async_carrier` API.

It is a contract for review and modeling, not Linux code. The names below are
candidate internal vocabulary only. They are not a public ABI, not a tracepoint
ABI, not an approved header, and not a behavior-changing patch.

## Core Rule

The shared carrier core may hold only CapSched authority state:

```text
caller Domain / epoch / generation
frozen caller authority reference
caller BudgetTicket or split child ticket
opaque monitor receipt reference or derived shadow
service or resource authority binding
carrier generation
revoke and freshness state
settlement and release state
```

The core must not know Linux subsystem mechanics:

```text
no queue_work state
no workqueue pending bit as authority
no io_uring SQE/CQE state as authority
no worker task identity as authority
no retry/reissue as receipt refresh
no cancel/free/ref drop as revoke or settlement proof
```

## Core Object

Candidate internal type:

```c
struct capsched_async_carrier;
```

The type should be opaque outside CapSched-internal code. Future adapters may
embed it or reference it, but raw `work_struct`, `io_wq_work`, `io_kiocb`, CQE,
callback pointer, worker task, or resource-ref liveness must not become the
carrier.

Candidate non-code layout:

```c
/* internal only; not UAPI, not a public tracepoint ABI */
struct capsched_async_carrier {
        /* immutable after freeze */
        caller_domain_ref;
        caller_epoch;
        caller_generation;
        frozen_caller_authority_ref;
        caller_budget_ticket_or_split_child_ticket;
        opaque_monitor_receipt_ref_or_shadow;
        carrier_generation;

        /* immutable after bind */
        service_or_resource_authority_binding;

        /* mutable only through revoke_check / settle / release */
        revoke_generation_seen;
        freshness_state;
        settlement_state;
        released;
};
```

This is intentionally not a proposed header. It is a field-shape contract for
the next model and later code review.

## Ownership Boundary

The core owns only CapSched references explicitly acquired by `freeze` or
`bind`:

```text
caller frozen authority reference
caller BudgetTicket settlement right
opaque monitor receipt reference or derived shadow
service/resource binding references
freshness and settlement state
```

The adapter owns Linux mechanics:

```text
carrier storage
Linux object lifetime
locking
work/request references
cancel and flush races
retry/reissue mechanics
completion/CQE delivery
final memory free
```

`release` drops CapSched references only. It must not call `kfree`, flush,
cancel, complete CQEs, drop `io_kiocb` references, put registered resources, or
pretend that Linux object cleanup is authority settlement.

## Single-Assignment Rule

The frozen tuple is single-assignment:

```text
caller Domain / epoch / generation
frozen caller authority
caller BudgetTicket or split child ticket
monitor receipt reference or shadow
carrier generation
```

After `freeze`, the tuple cannot be overwritten by queue coalescing,
delayed-work retiming, self-requeue, io-wq punt, retry, `REQ_F_REISSUE`, cancel,
completion, ref drop, or free.

The bind tuple is also single-assignment unless a future model defines an
explicit monitor-approved replacement path:

```text
service/resource authority binding
operation class
endpoint/resource class
```

The only mutable shared-core state is:

```text
revoke/freshness state through revoke_check
settlement/release state through settle and release
```

Settlement must be exactly once across success, failure, cancel, revoke,
coalesced second-caller rejection, retry, reissue, completion, and free.

The carrier has two categories of operations.

Non-authority lifetime helpers:

```text
create_empty
get
put
destroy_empty_or_released
```

These helpers allocate or hold storage only. They do not freeze authority, bind
service authority, mint receipts, validate execution, revoke, settle, or approve
side effects.

Authority transitions:

```text
freeze
bind
validate
revoke_check
settle
release
```

These transitions are the only shared core operations. They intentionally avoid
subsystem verbs such as enqueue, dispatch, queue_work, issue_sqe, complete_cqe,
or finish_work.

## Candidate Operation Semantics

### `freeze`

Input:

```text
caller Domain / epoch / generation
frozen caller authority reference
caller BudgetTicket or split child ticket
opaque monitor receipt reference or derived shadow
carrier generation
```

Effect:

```text
freeze immutable caller-side fields before async publication
```

Forbidden:

```text
freezing from worker current
freezing from work_struct pointer
freezing from req->creds or req->tctx
freezing without caller BudgetTicket
Linux minting the monitor receipt
```

### `bind`

Input:

```text
service Domain or resource authority reference
operation class
allowed endpoint/resource class
```

Effect:

```text
bind service/resource authority separately from caller frozen authority
```

Forbidden:

```text
service authority alone as effective authority
caller authority alone as effective authority
LSM, credential, namespace, or cgroup result as a complete capability
```

### `validate`

Input:

```text
carrier
current Domain epoch view
current revoke generation view
adapter execution context
```

Effect:

```text
reject stale or revoked carrier before endpoint side effects
compute service/resource authority intersected with caller frozen authority
confirm caller BudgetTicket remains chargeable
confirm monitor receipt reference is fresh enough for this carrier generation
```

Forbidden:

```text
worker identity validation
generic queue membership validation
completion/CQE validation
retry/reissue validation as receipt renewal
```

### `revoke_check`

Input:

```text
carrier generation
Domain epoch
revoke generation
adapter state summary
```

Effect:

```text
classify carrier as still usable, stale rejected, or requiring adapter drain
```

Forbidden:

```text
Linux cancel/free/ref-drop as monitor revoke completion
local cleanup as receipt invalidation
executing a stale carrier and repairing later
```

### `settle`

Input:

```text
execution outcome
caller BudgetTicket charge/refund state
receipt consumption state
adapter completion state summary
```

Effect:

```text
record budget and receipt settlement before final release. Settlement is
exactly once for success, failure, cancel, revoke, coalesced rejection, retry,
reissue, completion, and free paths.
```

Forbidden:

```text
service-only budget charge
worker kthread runtime as caller ticket
cgroup CPU accounting as capability settlement
CQE as settlement proof
```

### `release`

Input:

```text
settled or never-published carrier
no live adapter execution reference
```

Effect:

```text
drop CapSched references after settlement or safe rejection
```

Forbidden:

```text
free path as authority decision
free path racing with worker validation
release before stale/revoke outcome is known
release coupled to Linux object free or CQE completion
```

## Workqueue Adapter Contract

The workqueue adapter is a typed wrapper/container for Domain-originated work.
It is not a global workqueue hook.

Candidate shape:

```text
capsched_work_carrier:
  struct work_struct storage or reference
  capsched_async_carrier core
  adapter owner and callback metadata
```

Required behavior:

```text
prepare:
  create empty carrier, freeze caller, bind service/resource authority.

queue:
  publish immutable carrier before queue_work_on().

queue_work_on() == false:
  preserve first caller, first BudgetTicket, first receipt, and first carrier
  generation. The second caller is rejected or represented by an explicitly
  modeled future coalescing path. It must not overwrite the pending carrier.
  The second candidate carrier remains caller/adapter-owned and must be
  rejected, settled, and released exactly once without transferring its budget
  or receipt to the first carrier.

mod_delayed_work_on():
  must preserve existing carrier, reject the new caller, or use an explicit
  monitor-approved regeneration path. Silent merge is forbidden.

self-requeue:
  does not refresh receipt, generation, or caller BudgetTicket.

cancel/flush:
  synchronization only. Not monitor revoke receipt and not settlement proof.

callback entry:
  recover typed carrier through the adapter container, validate before service
  side effects, reject worker task identity as authority.

free:
  only after settle/release or never-published discard.
```

## io_uring Adapter Contract

The io_uring adapter attaches carrier state to explicit request/resource
storage. `io_kiocb` and `io_rsrc_node` are possible future storage anchors, but
they are not authority by themselves.

Required behavior:

```text
request creation:
  no authority from allocation.

SQE consumption:
  freeze after SQE is copied/consumed and before side effects.

resource binding:
  fixed file and fixed buffer authority must be frozen or generation-checked
  explicitly. io_rsrc_node liveness/refcount is storage state, not authority.

inline issue:
  validate before __io_issue_sqe() side effects.

io-wq punt:
  publish immutable carrier before worker execution and validate before
  io_wq_submit_work() side effects.

linked requests:
  each request has a carrier or an explicit child/split relationship. Linkage
  is not authority inheritance.

cancel:
  Linux cancel state is matching/synchronization only. It is not monitor revoke
  receipt.

REQ_F_REISSUE:
  preserves original carrier or uses an explicitly modeled monitor-approved
  replacement path. It must not refresh receipt implicitly.

completion/CQE:
  result delivery only. Not monitor verification, not receipt minting, and not
  settlement proof by itself. Any settlement-affecting completion path must pass
  through the carrier settlement state.

resource ref release/free:
  storage lifetime only. Not EndpointCap revoke, not receipt settlement.
```

## Patch Preconditions

Before any Linux patch implements this sketch, the patch proposal must name:

```text
carrier storage location
owner and reference lifetime
freeze-before-publication ordering
adapter retrieval path
stale/revoked rejection path
service/caller intersection point
BudgetTicket charge/refund/overrun path
receipt generation comparison
single-assignment and mutability table
second-caller rejection cleanup path
exactly-once settlement table
set-based service/caller intersection representation
cancel/retry/reissue/free ordering
evidence class and non-claim flags
```

## Postponed

This sketch deliberately postpones:

```text
public user ABI
public tracepoint ABI
direct-call monitor stub implementation
monitor-owned ring implementation
global workqueue integration
generic io-wq integration
task_struct field changes
scheduler behavior changes
LSM/cgroup policy front-end integration
KUnit or runtime tests
production protection claims
multi-caller merge semantics
delayed-work retiming helpers beyond explicit preserve/reject/regenerate policy
full linked-request inheritance rules
budget overrun/refund policy
```

## Required Future Models

N-125 is still a sketch. The next model should refine the parts that are only
obligation text here:

```text
io_uring refinement:
  SQE consumption, fixed resources, inline issue, io-wq punt, linked requests,
  cancel, REQ_F_REISSUE, CQE, resource ref release, and free.

BudgetTicket and receipt settlement:
  exactly-once settlement across success, failure, cancel, revoke, coalesced
  second-caller rejection, retry, reissue, completion, and free.

generation and epoch monotonicity:
  queued, pending, executing, completed, canceled, retried, reissued, and freed
  carriers must reject stale authority before side effects.

authority algebra:
  effective authority is a set intersection and must be a subset of both caller
  frozen authority and service/resource authority.

workqueue refinements:
  delayed-work retiming, self-requeue, and preserve/reject/regenerate choices.
```

## Non-Claims

This sketch does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
