# ADR-0009: Async Carrier API Direction

Status: Accepted

Date: 2026-07-01

## Context

N-120 through N-123 established that Domain-originated async direct-call receipt
use cannot rely on generic Linux async state.

The important facts are:

- raw `struct work_struct`, pending bits, callback identity, worker task
  identity, flush, cancel, requeue, and free are not caller authority
- `queue_work()` can return false for already-pending work, so a second caller
  must not overwrite the first caller's BudgetTicket, receipt, or generation
- `io_kiocb` and `io_rsrc_node` are useful future storage anchors, but
  `req->creds`, `req->tctx`, `io_wq_work`, registered-resource liveness,
  cancel flags, CQEs, completion, retry, ref drop, and free are not authority
- the common security invariant is shared across workqueue and io_uring, but
  their lifetime hazards are different

N-124 chooses the direction for the next no-behavior API sketch. This is not a
Linux patch approval.

## Decision

Use a shared internal `capsched_async_carrier` semantic core with
per-subsystem adapters.

The shared core is for CapSched authority state only:

```text
frozen caller authority
caller BudgetTicket or split child ticket
opaque monitor receipt reference or derived shadow
caller Domain/epoch/generation
service or resource authority binding
carrier generation
revoke/freshness state
settlement/release ownership
```

The shared core must use neutral operations such as:

```text
freeze
bind
validate
revoke_check
settle
release
```

It must not encode workqueue or io_uring mechanics as the generic authority
model.

The first adapters are:

```text
workqueue adapter:
  typed wrapper/container around Domain-originated work
  preserve first carrier on pending coalescing
  no global hook treating all work as Domain-originated

io_uring adapter:
  request/resource carrier attached to explicit io_uring storage
  registered resource generation separated from io_rsrc_node liveness
  validate before issue, io-wq punt, retry, reissue, and completion effects
```

## Rationale

The shared carrier prevents two incompatible async authority dialects from
emerging.

A workqueue-only helper is initially smaller, but it risks baking
`queue_work()` pending and delayed-work retiming semantics into the core
authority vocabulary. That would make io_uring integration look like an
afterthought and would likely require later cleanup.

An io_uring-only helper has attractive request anchors, but it risks overfitting
CapSched semantics to SQE/request/CQE/resource-ref lifetimes while leaving
generic service-domain workqueue provenance unresolved.

The shared internal core is the best long-term waist if it remains narrow:

```text
shared:
  immutable authority fields and freshness/settlement rules

not shared:
  Linux subsystem lifetime mechanics
  generic queue execution model
  public ABI
  behavior-changing hook placement
```

## Alternatives

`workqueue-only helper`
: Rejected as the main direction. It is useful as one adapter, but not as the
  semantic core.

`io_uring-only request carrier helper`
: Rejected as the main direction. It is useful as one adapter, but not as the
  semantic core.

`shared internal carrier with adapters`
: Accepted. It unifies the invariant without hiding subsystem-specific
  lifetime hazards.

## Guardrails

This decision requires:

- no behavior change
- no public ABI
- no public tracepoint ABI
- no monitor-verification claim
- no production-protection claim
- no global workqueue hook in `__queue_work()` or `process_one_work()` that
  treats generic kernel work as Domain-originated
- no use of `work_struct`, callback pointer, worker identity, `io_wq_work`,
  `io_kiocb`, `req->creds`, `req->tctx`, `io_rsrc_node`, CQE, cancel flags,
  retry flags, or ref drops as authority
- separate workqueue and io_uring lifetime tables remain required

## Consequences

The next no-behavior API sketch should define the internal carrier's fields,
ownership, neutral operations, and adapter contracts.

It must keep workqueue and io_uring hazards explicit:

- workqueue must cover `queue_work_on() == false`, delayed-work retiming,
  self-requeue, cancel/flush, callback entry, and free
- io_uring must cover SQE consumption, fixed file/buffer binding, inline issue,
  io-wq punt, cancel, linked requests, `REQ_F_REISSUE`, completion/CQE,
  resource ref release, and free

This makes future Linux patches more maintainable because subsystem adapters
can move with upstream churn while the CapSched invariant remains stable.

## Evidence

- `formal/0058-direct-call-async-carrier-model/`
- `validation/0091-direct-call-async-carrier-tlc.md`
- `implementation/0011-direct-call-async-carrier-gate.md`
- `analysis/0081-direct-call-async-workqueue-io-uring-source-map.md`
- `analysis/0082-direct-call-async-carrier-lifetime-table.md`
- `validation/0094-direct-call-async-lifetime-table-result.md`
- `analysis/0083-direct-call-async-carrier-api-direction.md`
- `analysis/direct-call-async-carrier-api-direction-v1.json`
- `validation/0095-direct-call-async-carrier-api-direction-result.md`

