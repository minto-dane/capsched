#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_WQ_ORIGIN_OUT_ROOT:-$ROOT/build/workqueue-origin-source-inventory}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
CLASSIFICATION="$RUN_DIR/workqueue-origin-classification.tsv"
GAPS="$RUN_DIR/workqueue-origin-gaps.tsv"
COUNTS="$RUN_DIR/api-callsite-counts.tsv"
SUMMARY="$RUN_DIR/summary.txt"
TAXONOMY="$ROOT/capsched/capsched-models/analysis/workqueue-origin-taxonomy-v1.json"

mkdir -p "$RUN_DIR"

require()
{
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: missing required command: $1" >&2
		exit 1
	fi
}

say()
{
	printf '[%s] %s\n' "$(date -Is)" "$*"
}

write_counts()
{
	{
		printf 'count\tsource_group\n'
		git -C "$LINUX" grep -n -E \
			'\b(queue_work|queue_work_on|schedule_work|schedule_work_on|queue_delayed_work|queue_delayed_work_on|mod_delayed_work|schedule_delayed_work|queue_rcu_work|kthread_queue_work|kthread_queue_delayed_work|task_work_add|irq_work_queue|irq_work_queue_on)\b' \
			-- ':!Documentation' ':!tools' |
			awk -F: '{
				split($1, a, "/");
				d = a[1];
				if (a[2] != "")
					d = d "/" a[2];
				count[d]++;
			}
			END {
				for (d in count)
					print count[d] "\t" d;
			}' |
			sort -nr
	} > "$COUNTS"
}

write_classification()
{
	{
		printf 'work_ptr\tcallback_symbol\tworkqueue_name\tqueue_site\texecute_site\ttaxonomy_class\torigin_context\tobject_scope\tcoalescing\tendpoint_effect\tauthority_source\treclaim_path\tmonitor_relevance\tconfidence\treason\n'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'aio_fsync_work' \
			'system_wq(schedule_work)' \
			'fs/aio.c:aio_fsync' \
			'fs/aio.c:aio_fsync_work' \
			'PerInvocation' \
			'syscall' \
			'per_request,per_file' \
			'none' \
			'file' \
			'unknown_linux_creds_not_capsched' \
			'none' \
			'DomainTag,Budget' \
			'source_inferred' \
			'one fsync request work item; stored creds exist but no CapSched carrier'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'aio_poll_complete_work' \
			'system_wq(schedule_work)' \
			'fs/aio.c:aio_poll_wake' \
			'fs/aio.c:aio_poll_complete_work' \
			'ExplicitMerge' \
			'waitqueue' \
			'per_request,per_file' \
			'explicit_flags' \
			'file' \
			'merge_object_required' \
			'none' \
			'DomainTag,Budget' \
			'source_inferred' \
			'work_scheduled and work_need_resched coalesce poll wakeups'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'blk_zone_wplug_bio_work' \
			'zone_wplugs_wq' \
			'block/blk-zoned.c:disk_zone_wplug_schedule_work' \
			'block/blk-zoned.c:blk_zone_wplug_bio_work' \
			'ExplicitMerge' \
			'block_io' \
			'per_zone,per_device' \
			'pending_bit,refcount_batch,list_batch' \
			'device_queue' \
			'merge_object_required' \
			'WQ_MEM_RECLAIM_possible' \
			'Budget,QueueLease' \
			'source_inferred' \
			'queue_work false path drops extra ref; work drains accumulated BIO state'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'timerfd_resume_work' \
			'system_wq(schedule_work)' \
			'fs/timerfd.c:timerfd_resume' \
			'fs/timerfd.c:timerfd_resume_work' \
			'ServiceOnly' \
			'suspend_resume' \
			'global' \
			'pending_bit' \
			'none' \
			'service_only' \
			'none' \
			'none' \
			'source_inferred' \
			'timekeeping resume maintenance; no caller endpoint effect claim'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'io_ring_exit_work' \
			'iou_wq' \
			'io_uring/io_uring.c:io_ring_ctx_wait_and_kill' \
			'io_uring/io_uring.c:io_ring_exit_work' \
			'ServiceOnly' \
			'file_release' \
			'per_io_uring_ctx' \
			'none' \
			'mixed_cleanup' \
			'service_only_or_tasklocal_handoff' \
			'none' \
			'DomainTag,Budget' \
			'source_inferred' \
			'ring teardown and cancellation work; endpoint effects need separate derivation if any survive'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'pool->idle_cull_work' \
			'system_dfl_wq' \
			'kernel/workqueue.c:idle_worker_timeout' \
			'kernel/workqueue.c:idle_cull_fn' \
			'KernelException' \
			'workqueue' \
			'global' \
			'pending_bit' \
			'none' \
			'kernel_exception' \
			'none' \
			'none' \
			'source_inferred' \
			'workqueue infrastructure liveness/cleanup; not caller attributed'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'irq_work_queue' \
			'irq_work' \
			'kernel/irq_work.c:irq_work_queue' \
			'kernel/irq_work.c:irq_work_single_or_irq_work_run' \
			'InterruptDeferred' \
			'irq' \
			'per_cpu_or_global' \
			'pending_bit' \
			'mixed' \
			'handoff_required' \
			'none' \
			'DomainTag,Budget' \
			'source_inferred' \
			'irq_work can run outside sleepable context; cannot discover authority there'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'bio_alloc_rescue' \
			'bioset rescue_workqueue' \
			'block/bio.c:punt_bios_to_rescuer' \
			'block/bio.c:bio_alloc_rescue' \
			'ReclaimRescue' \
			'reclaim' \
			'per_bioset' \
			'list_batch' \
			'block_io' \
			'carrier_or_service_cleanup_only' \
			'WQ_MEM_RECLAIM,rescuer_possible' \
			'Budget,QueueLease' \
			'source_inferred' \
			'forward-progress rescue path; liveness is not authority'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'f_task_work' \
			'task_work' \
			'fs/file_table.c:task_work_add' \
			'kernel/task_work.c:task_work_run' \
			'TaskLocal' \
			'task' \
			'per_task,per_file' \
			'LIFO_task_work' \
			'file' \
			'task_context_not_authority' \
			'none' \
			'DomainTag,Budget' \
			'source_inferred' \
			'target task context is preserved but generation and endpoint authority still required'
		printf 'source\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			'vfio_virqfd_inject' \
			'system_wq(schedule_work)' \
			'drivers/vfio/virqfd.c:virqfd_wakeup' \
			'drivers/vfio/virqfd.c:virqfd_inject' \
			'InterruptDeferred' \
			'eventfd_waitqueue' \
			'per_device,per_eventfd' \
			'pending_bit' \
			'device_queue' \
			'handoff_required' \
			'none' \
			'IOMMU,QueueLease,Budget' \
			'source_inferred' \
			'eventfd signal can cause device interrupt injection; requires typed queue/endpoint lease model'
	} > "$CLASSIFICATION"
}

write_gaps()
{
	{
		printf 'gap_id\tcategory\tevidence\trequired_next_step\n'
		awk -F '\t' 'NR > 1 && $1 + 0 >= 25 {
			printf "bulk-%s\tunknown_or_mixed\t%s API matches in %s\tsource-map top callbacks and queue sites\n", $2, $1, $2;
		}' "$COUNTS"
		printf 'queue-stack\tmissing_evidence\tworkqueue tracepoints do not identify semantic caller by themselves\tenable event stack traces or targeted fprobe stack capture\n'
		printf 'task-work-generic-trace\tmissing_evidence\tgeneric task_work_add/task_work_run lacks a broad tracepoint in this tree\tuse kprobes/fprobes or source inventory for task-local paths\n'
		printf 'irq-work-trace\tmissing_evidence\tirq_work has no dedicated trace event in inspected headers\tuse kprobes/fprobes around irq_work_queue and irq_work_single\n'
		printf 'rescuer-runtime\tmissing_evidence\tWQ_MEM_RECLAIM presence does not prove rescuer execution\tobserve current_is_workqueue_rescuer or rescuer_thread execution under controlled pressure\n'
		printf 'hardware-dependent\tcoverage_gap\tIOMMU SVA, VFIO, GPU, NIC, and block paths may depend on unavailable hardware\tkeep hardware paths optional and record not_observed rather than weakening taxonomy\n'
	} > "$GAPS"
}

write_summary()
{
	{
		echo "timestamp_utc=$STAMP"
		echo "linux_commit=$(git -C "$LINUX" rev-parse HEAD)"
		echo "linux_subject=$(git -C "$LINUX" log -1 --format=%s)"
		echo "taxonomy=$TAXONOMY"
		echo "classification=$CLASSIFICATION"
		echo "gaps=$GAPS"
		echo "counts=$COUNTS"
		echo "known_classification_rows=$(($(wc -l < "$CLASSIFICATION") - 1))"
		echo "gap_rows=$(($(wc -l < "$GAPS") - 1))"
		echo "status=observation_only_source_inventory"
	} > "$SUMMARY"
}

require git
require awk
require sort
require jq

jq empty "$TAXONOMY"

say "workqueue origin source inventory started"
say "run directory: $RUN_DIR"
write_counts
write_classification
write_gaps
write_summary
say "classification: $CLASSIFICATION"
say "gaps: $GAPS"
