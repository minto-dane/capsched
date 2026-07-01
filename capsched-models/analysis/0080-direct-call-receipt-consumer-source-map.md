# Analysis 0080: Direct-Call Receipt Consumer Source Map

Status: draft source-only map, no patch approved

Date: 2026-06-30

## Purpose

N-116 fixed the monitor-owned direct-call receipt families. N-117 maps where
future Linux code might consume opaque receipt handles or derived shadows, and
where it must not.

This analysis still does not choose an implementation patch. It is a source
map for later design review and upstream drift tracking.

## Rule

Linux-facing code may eventually:

```text
carry an opaque monitor receipt id
cache a derived non-authoritative shadow
compare a monitor generation or epoch supplied by the monitor
invalidate a Linux shadow after monitor revoke
```

Linux-facing code may not:

```text
mint RequestImageReceipt, SchemaReceipt, EntryResultReceipt,
ResponseHandleReceipt, or RevokeReceipt
turn a return code, timeout, trace row, or cached shadow into authority
decide schema acceptance
complete revoke while in-flight response state survives
use generic async worker identity as caller authority
```

## Surface Classes

The machine-readable source map separates five classes:

```text
current_inert_namespace:
  Existing CONFIG_CAPSCHED type/build scaffolding. It is a place to keep names
  visible, not a receipt consumer yet.

scheduler_hot_path_candidate:
  enqueue/wake/pick/switch locations where future receipt shadows might be
  checked. These are not direct-call minting points.

policy_lifecycle_candidate:
  scheduler syscalls and fork/exec/exit paths that shape request identity,
  generation, and stale-shadow invalidation. Existing Linux permission checks
  remain policy inputs, not monitor receipt authority.

excluded_generic_async_surface:
  workqueue/io_uring surfaces where caller authority is naturally lost or work
  items can coalesce. These need typed carriers for Domain-originated work
  rather than a generic direct-call receipt consumer hook.

future_gap:
  Still-absent direct-call request envelope, wrapper/backend, schema cache,
  response shadow, control revoke, test-only, and trace-only surfaces.
```

## Important Exclusions

Generic `work_struct` reuse is dangerous for receipt state. `queue_work()` may
coalesce repeated submissions of the same work item while it is pending. A
design that overwrites a caller-specific ticket or receipt shadow in the
container work object would confuse callers.

Execution enters worker context through `worker->current_func(work)`. The
worker task is not the original caller. Therefore generic workqueue execution
must not become a direct-call receipt authority path.

`io_uring` workers have similar provenance pressure. Worker creation and worker
loops are real source anchors, but they require typed io_uring provenance and
per-request authority, not ambient worker authority.

## Drift Tracking

`direct-call-receipt-consumer-source-map-v1.json` uses source paths and
symbol/pattern anchors instead of line-only anchors. The project drift checker
can mechanically detect missing paths and missing symbols after an upstream
Linux update.

Every row keeps:

```text
source_only=true
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
user_abi=false
public_tracepoint_abi=false
protection_claim=false
```

This map is not semantic validation of those Linux regions. It is a
non-authoritative candidate/negative map for the next gate.

