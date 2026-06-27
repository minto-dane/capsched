# Validation 0042: Workqueue Origin Source Inventory Result

Status: Executed observation-only source inventory

Date: 2026-06-27

Runner:

```text
capsched/capsched-models/validation/run-workqueue-origin-source-inventory.sh
```

Related analysis:

```text
capsched/capsched-models/analysis/0046-workqueue-origin-taxonomy.md
capsched/capsched-models/analysis/workqueue-origin-taxonomy-v1.json
capsched/capsched-models/validation/0041-workqueue-origin-observation-plan.md
```

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Result Summary

Final run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-source-inventory/20260627T102126Z

classification:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-source-inventory/20260627T102126Z/workqueue-origin-classification.tsv

gaps:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-source-inventory/20260627T102126Z/workqueue-origin-gaps.tsv

counts:
  /media/nia/scsiusb/dev/linux-cap/build/workqueue-origin-source-inventory/20260627T102126Z/api-callsite-counts.tsv
```

Outcome:

```text
status: observation_only_source_inventory
known_classification_rows: 10
gap_rows: 49
api_count_rows: 297 data rows plus header
```

## Classification Rows

The runner emitted source-inferred seed classifications for:

| Callback or Path | Class | Reason |
| --- | --- | --- |
| `aio_fsync_work` | PerInvocation | one fsync request work item; stored creds are not CapSched authority |
| `aio_poll_complete_work` | ExplicitMerge | `work_scheduled` and `work_need_resched` coalesce poll wakeups |
| `blk_zone_wplug_bio_work` | ExplicitMerge | pending-bit/refcount/list batching drains accumulated BIO state |
| `timerfd_resume_work` | ServiceOnly | timekeeping resume maintenance |
| `io_ring_exit_work` | ServiceOnly | io_uring ring teardown and cancellation |
| `pool->idle_cull_work` | KernelException | workqueue infrastructure cleanup |
| `irq_work_queue` path | InterruptDeferred | IRQ/deferred context cannot discover authority |
| `bio_alloc_rescue` | ReclaimRescue | forward-progress rescue path |
| `f_task_work` | TaskLocal | task context preserved, but not endpoint authority |
| `vfio_virqfd_inject` | InterruptDeferred | eventfd signal can cause device interrupt injection |

These are seed classifications, not full-kernel coverage.

## Gap Rows

The runner emitted 49 gap rows. The largest bulk unknown groups were:

```text
drivers/net:        1440 API matches
drivers/gpu:         475 API matches
drivers/scsi:        277 API matches
drivers/usb:         234 API matches
sound/soc:           227 API matches
drivers/media:       222 API matches
drivers/power:       210 API matches
drivers/infiniband:  205 API matches
drivers/md:          127 API matches
drivers/hid:         109 API matches
```

Important non-bulk gaps:

```text
queue-stack:
  workqueue tracepoints do not identify semantic caller by themselves

task-work-generic-trace:
  generic task_work_add/task_work_run lacks a broad tracepoint in this tree

irq-work-trace:
  irq_work has no dedicated trace event in inspected headers

rescuer-runtime:
  WQ_MEM_RECLAIM presence does not prove rescuer execution

hardware-dependent:
  IOMMU SVA, VFIO, GPU, NIC, and block paths may depend on unavailable hardware
```

## Validation Meaning

This validation supports this claim:

```text
The workqueue origin taxonomy can now be applied mechanically enough to emit
seed classifications and explicit unknown/gap rows.
```

It does not prove:

```text
the source inventory covers all workqueue callsites
observed source-inferred classifications are enforcement-ready
generic workqueue hooks are safe
caller endpoint authority is preserved
trace evidence alone is sufficient
```

## Consequence

The next work should either:

```text
1. deepen source inventory for the largest unknown groups, especially
   drivers/net, drivers/gpu, drivers/scsi, drivers/usb, and sound/soc, or
2. build a QEMU trace runner with queue-site stack capture for selected
   taxonomy classes.
```

No generic workqueue enforcement hook should be proposed from this result
alone.
