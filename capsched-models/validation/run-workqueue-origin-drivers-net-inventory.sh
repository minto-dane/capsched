#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
OUT_ROOT="${CAPSCHED_WQ_NET_OUT_ROOT:-$ROOT/build/workqueue-origin-drivers-net-inventory}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
CALLS="$RUN_DIR/drivers-net-callsite-inventory.tsv"
FAMILY_COUNTS="$RUN_DIR/drivers-net-family-counts.tsv"
API_COUNTS="$RUN_DIR/drivers-net-api-counts.tsv"
HOTSPOTS="$RUN_DIR/drivers-net-hotspots.tsv"
GAPS="$RUN_DIR/drivers-net-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"

PATTERN='\b(queue_work|queue_work_on|schedule_work|schedule_work_on|queue_delayed_work|queue_delayed_work_on|mod_delayed_work|schedule_delayed_work|queue_rcu_work|kthread_queue_work|kthread_queue_delayed_work|task_work_add|irq_work_queue|irq_work_queue_on)\b'

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

write_calls()
{
	{
		printf 'file\tline\tapi\tfamily\tsubfamily\torigin_context\tcoalescing\tendpoint_effect\ttaxonomy_projection\tmonitor_relevance\tconfidence\treason\tcode\n'
		git -C "$LINUX" grep -n -E "$PATTERN" -- drivers/net |
			awk -F: '
			function api_of(s,    m) {
				if (match(s, /(queue_work_on|queue_work|schedule_work_on|schedule_work|queue_delayed_work_on|queue_delayed_work|mod_delayed_work|schedule_delayed_work|queue_rcu_work|kthread_queue_delayed_work|kthread_queue_work|task_work_add|irq_work_queue_on|irq_work_queue)/))
					return substr(s, RSTART, RLENGTH);
				return "unknown";
			}
			function basename(path,    n, a) {
				n = split(path, a, "/");
				return a[n];
			}
			function family_of(path,    n, a) {
				n = split(path, a, "/");
				if (n >= 3)
					return a[3];
				return "root";
			}
			function subfamily_of(path,    n, a) {
				n = split(path, a, "/");
				if (n >= 4)
					return a[4];
				return basename(path);
			}
			function origin_for(api, line) {
				if (api ~ /^irq_work/)
					return "irq";
				if (api ~ /^kthread_/)
					return "kthread";
				if (api == "task_work_add")
					return "task";
				if (line ~ /system_bh_wq|system_bh_highpri_wq/)
					return "softirq";
				if (api ~ /delayed|mod_delayed/)
					return "timer_or_delayed";
				return "workqueue";
			}
			function coalescing_for(api, line) {
				if (api ~ /mod_delayed/)
					return "delayed_mod";
				if (api ~ /delayed/)
					return "delayed_pending";
				if (api ~ /^irq_work/)
					return "pending_bit";
				if (api == "task_work_add")
					return "LIFO_task_work";
				if (api ~ /^kthread_/)
					return "kthread_pending_or_delayed";
				if (line ~ /system_bh_wq|system_bh_highpri_wq/)
					return "bh_pending";
				return "pending_bit";
			}
			function taxonomy_for(api, line) {
				if (api ~ /^irq_work/ || line ~ /system_bh_wq|system_bh_highpri_wq/)
					return "InterruptDeferred_candidate";
				if (api == "task_work_add")
					return "TaskLocal_candidate";
				if (api ~ /^kthread_/)
					return "InterruptDeferred_or_ServiceOnly_candidate";
				if (api ~ /delayed|mod_delayed/)
					return "ExplicitMerge_or_ServiceOnly_candidate";
				return "PerInvocation_or_ServiceOnly_or_ExplicitMerge_candidate";
			}
			function monitor_for(fam, subfam, line) {
				if (fam == "wireless")
					return "DomainTag,Budget,QueueLease,DeviceService";
				if (fam == "ethernet" || fam == "usb" || fam == "dsa" || fam == "phy" || fam == "bonding" || fam == "team")
					return "DomainTag,Budget,QueueLease";
				if (line ~ /xdp|bpf|XDP|BPF/)
					return "DomainTag,Budget,QueueLease,BPF";
				return "DomainTag,Budget,QueueLease";
			}
			{
				file = $1;
				line_no = $2;
				code = substr($0, length($1) + length($2) + 3);
				api = api_of(code);
				fam = family_of(file);
				subfam = subfamily_of(file);
				origin = origin_for(api, code);
				coalescing = coalescing_for(api, code);
				tax = taxonomy_for(api, code);
				monitor = monitor_for(fam, subfam, code);
				reason = "drivers/net source inventory; candidate only until callback and endpoint effect are source-mapped";
				gsub(/\t/, " ", code);
				print file "\t" line_no "\t" api "\t" fam "\t" subfam "\t" origin "\t" coalescing "\tnetwork_device_or_control_plane\t" tax "\t" monitor "\tsource_inventory_only\t" reason "\t" code;
			}'
	} > "$CALLS"
}

write_counts()
{
	{
		printf 'count\tfamily\tsubfamily\n'
		awk -F '\t' 'NR > 1 { count[$4 "\t" $5]++ } END { for (k in count) print count[k] "\t" k }' "$CALLS" |
			sort -nr
	} > "$FAMILY_COUNTS"

	{
		printf 'count\tapi\n'
		awk -F '\t' 'NR > 1 { count[$3]++ } END { for (k in count) print count[k] "\t" k }' "$CALLS" |
			sort -nr
	} > "$API_COUNTS"

	{
		printf 'count\tfile\n'
		awk -F '\t' 'NR > 1 { count[$1]++ } END { for (k in count) print count[k] "\t" k }' "$CALLS" |
			sort -nr |
			head -n 40
	} > "$HOTSPOTS"
}

write_gaps()
{
	{
		printf 'gap_id\tcategory\tevidence\trequired_next_step\n'
		awk -F '\t' 'NR > 1 && $1 + 0 >= 25 {
			printf "family-%s/%s\tunknown_or_mixed\t%s callsites in drivers/net/%s/%s\tsource-map top callbacks, queue sites, endpoint effects, and merge rules\n", $2, $3, $1, $2, $3;
		}' "$FAMILY_COUNTS"
		awk -F '\t' 'NR > 1 && $1 + 0 >= 25 {
			printf "hotspot-%s\tunknown_or_mixed\t%s callsites in %s\tinspect INIT_WORK callbacks and queueing conditions\n", $2, $1, $2;
		}' "$HOTSPOTS"
		printf 'driver-callback-correlation\tmissing_evidence\tinventory rows are API callsites, not callback-to-container mappings\tparse INIT_WORK/INIT_DELAYED_WORK or use cscope/clang tooling\n'
		printf 'endpoint-effect-map\tmissing_evidence\tnetwork drivers mix link maintenance, reset, stats, tx/rx completion, firmware, PTP, and queue control\tclassify endpoint effects before any carrier rule\n'
		printf 'queue-lease-boundary\tmissing_evidence\tnetwork data/control plane queue ownership is not represented by workqueue API names\tmap netdev queue, NAPI, XDP, ethtool, firmware, and device reset paths\n'
		printf 'hardware-coverage\tcoverage_gap\tmany drivers/net paths require hardware-specific events\tkeep hardware paths source-inferred or not_observed unless QEMU/device setup proves execution\n'
	} > "$GAPS"
}

write_summary()
{
	{
		echo "timestamp_utc=$STAMP"
		echo "linux_commit=$(git -C "$LINUX" rev-parse HEAD)"
		echo "linux_subject=$(git -C "$LINUX" log -1 --format=%s)"
		echo "calls=$CALLS"
		echo "family_counts=$FAMILY_COUNTS"
		echo "api_counts=$API_COUNTS"
		echo "hotspots=$HOTSPOTS"
		echo "gaps=$GAPS"
		echo "callsite_rows=$(($(wc -l < "$CALLS") - 1))"
		echo "family_rows=$(($(wc -l < "$FAMILY_COUNTS") - 1))"
		echo "api_rows=$(($(wc -l < "$API_COUNTS") - 1))"
		echo "hotspot_rows=$(($(wc -l < "$HOTSPOTS") - 1))"
		echo "gap_rows=$(($(wc -l < "$GAPS") - 1))"
		echo "status=observation_only_drivers_net_source_inventory"
	} > "$SUMMARY"
}

require git
require awk
require sort
require head

say "drivers/net workqueue origin inventory started"
say "run directory: $RUN_DIR"
write_calls
write_counts
write_gaps
write_summary
say "calls: $CALLS"
say "gaps: $GAPS"
