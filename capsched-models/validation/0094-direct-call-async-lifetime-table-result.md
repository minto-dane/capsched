# Validation 0094: Direct-Call Async Carrier Lifetime Table Result

Status: executed; no-patch lifetime table checked

Date: 2026-06-30

## Inputs

```text
analysis/0082-direct-call-async-carrier-lifetime-table.md
analysis/direct-call-async-carrier-lifetime-table-v1.json
analysis/direct-call-async-workqueue-source-map-v1.json
analysis/direct-call-async-io-uring-source-map-v1.json
implementation/0011-direct-call-async-carrier-gate.md
formal/0058-direct-call-async-carrier-model/
```

## Commands

```sh
jq empty \
  capsched/capsched-models/analysis/direct-call-async-carrier-lifetime-table-v1.json

jq -r '.stages as $stages | .lifetime_rows as $rows |
  [($rows|length),
   ($rows|map(select(.surface=="workqueue"))|length),
   ($rows|map(select(.surface=="io_uring"))|length),
   ($rows|map(select(.stage as $s | $stages|index($s)))|length),
   ($rows|map(select((.forbidden_collapses|length>0) and
                     (.patch_precondition|length>0) and
                     (.source_map_rows|length>0)))|length),
   ($rows|map(select(.safety_flags.implementation_approval==false and
                     .safety_flags.authority_claim==false and
                     .safety_flags.monitor_verified==false and
                     .safety_flags.runtime_coverage==false and
                     .safety_flags.behavior_change==false and
                     .safety_flags.public_tracepoint_abi==false and
                     .safety_flags.protection_claim==false))|length)] | @tsv' \
  capsched/capsched-models/analysis/direct-call-async-carrier-lifetime-table-v1.json
```

## Result

```text
lifetime_rows=22
workqueue_rows=11
io_uring_rows=11
rows_with_known_stage=22
rows_with_source_refs_forbidden_collapses_and_patch_precondition=22
rows_with_required_nonclaim_safety_flags=22
```

Both surfaces cover the same stage names:

```text
allocate
freeze
bind_service_or_resource
enqueue
coalesce_or_link
pending_protect
execute
cancel_or_revoke
retry_or_reissue
complete
free
```

## Meaning

The table is a pre-code obligation map:

```text
workqueue:
  raw work_struct, pending bits, callback identity, worker identity, flush,
  cancel, requeue, and free are never caller authority or monitor receipt proof.

io_uring:
  io_kiocb and io_rsrc_node are useful future storage anchors, but req->creds,
  req->tctx, io_wq_work, registered resource liveness, cancel flags, CQEs,
  completion, retry, ref drop, and free are never authority by themselves.
```

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
