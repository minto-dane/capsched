#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${CAPSCHED_TRACE_OUT:-$ROOT/build/traces/slice0c-no-code-$TS}"
RUN_AS="${CAPSCHED_TRACE_RUN_AS:-${SUDO_USER:-}}"

if [[ "$(id -u)" != "0" ]]; then
	echo "error: this runner needs root or equivalent tracefs write access" >&2
	exit 1
fi

if [[ -w /sys/kernel/tracing/tracing_on ]]; then
	TRACEFS=/sys/kernel/tracing
elif [[ -w /sys/kernel/debug/tracing/tracing_on ]]; then
	TRACEFS=/sys/kernel/debug/tracing
else
	echo "error: writable tracefs not found" >&2
	exit 1
fi

mkdir -p "$OUT"

EVENTS=(
	sched/sched_waking
	sched/sched_wakeup
	sched/sched_wakeup_new
	sched/sched_switch
	sched/sched_migrate_task
	sched/sched_process_fork
	sched/sched_process_exec
	sched/sched_process_exit
)

FUNCTIONS=(
	try_to_wake_up
	ttwu_runnable
	ttwu_do_activate
	sched_ttwu_pending
	__ttwu_queue_wakelist
	ttwu_queue
	wake_up_new_task
	move_queued_task
	enqueue_task
	__pick_next_task
	pick_next_task
	__schedule
)

read_tracefs() {
	local rel="$1"
	cat "$TRACEFS/$rel"
}

write_tracefs() {
	local rel="$1"
	local value="$2"
	printf '%s\n' "$value" > "$TRACEFS/$rel"
}

OLD_TRACING_ON="$(read_tracefs tracing_on)"
OLD_TRACER="$(read_tracefs current_tracer)"
OLD_FILTER="$(read_tracefs set_ftrace_filter || true)"

declare -A OLD_EVENT_ENABLE
for event in "${EVENTS[@]}"; do
	if [[ -e "$TRACEFS/events/$event/enable" ]]; then
		OLD_EVENT_ENABLE["$event"]="$(cat "$TRACEFS/events/$event/enable")"
	fi
done

restore_tracefs() {
	set +e
	write_tracefs tracing_on 0
	for event in "${!OLD_EVENT_ENABLE[@]}"; do
		printf '%s\n' "${OLD_EVENT_ENABLE[$event]}" > "$TRACEFS/events/$event/enable"
	done
	printf '%s\n' "$OLD_FILTER" > "$TRACEFS/set_ftrace_filter"
	printf '%s\n' "$OLD_TRACER" > "$TRACEFS/current_tracer"
	printf '%s\n' "$OLD_TRACING_ON" > "$TRACEFS/tracing_on"
}

trap restore_tracefs EXIT

{
	echo "timestamp_utc=$TS"
	echo "tracefs=$TRACEFS"
	echo "uname=$(uname -a)"
	echo "workspace=$ROOT"
	echo "output=$OUT"
	if [[ -n "$RUN_AS" ]]; then
		echo "workload_run_as=$RUN_AS"
	else
		echo "workload_run_as=root"
	fi
	if [[ -r /proc/version ]]; then
		echo "proc_version=$(cat /proc/version)"
	fi
	if [[ -r /boot/config-$(uname -r) ]]; then
		echo "config=/boot/config-$(uname -r)"
	elif [[ -r /proc/config.gz ]]; then
		echo "config=/proc/config.gz"
	else
		echo "config=unavailable"
	fi
} > "$OUT/metadata.txt"

if (($#)); then
	printf '%q ' "$@" > "$OUT/workload.txt"
	printf '\n' >> "$OUT/workload.txt"
	WORKLOAD=("$@")
else
	cat > "$OUT/workload.txt" <<'WORKLOAD'
bash -lc 'for i in $(seq 1 300); do /bin/true >/dev/null 2>&1; done'
WORKLOAD
	WORKLOAD=(bash -lc 'for i in $(seq 1 300); do /bin/true >/dev/null 2>&1; done')
fi

write_tracefs tracing_on 0
write_tracefs current_tracer nop
: > "$TRACEFS/trace"
: > "$TRACEFS/set_ftrace_filter"

: > "$OUT/enabled-events.txt"
: > "$OUT/missing-events.txt"
for event in "${EVENTS[@]}"; do
	if [[ -e "$TRACEFS/events/$event/enable" ]]; then
		printf '%s\n' "$event" >> "$OUT/enabled-events.txt"
		printf '1\n' > "$TRACEFS/events/$event/enable"
	else
		printf '%s\n' "$event" >> "$OUT/missing-events.txt"
	fi
done

: > "$OUT/enabled-functions.txt"
: > "$OUT/missing-functions.txt"
if [[ -r "$TRACEFS/available_filter_functions" ]]; then
	for func in "${FUNCTIONS[@]}"; do
		if grep -qw "$func" "$TRACEFS/available_filter_functions"; then
			printf '%s\n' "$func" >> "$OUT/enabled-functions.txt"
			printf '%s\n' "$func" >> "$TRACEFS/set_ftrace_filter"
		else
			printf '%s\n' "$func" >> "$OUT/missing-functions.txt"
		fi
	done
else
	printf '%s\n' "${FUNCTIONS[@]}" >> "$OUT/missing-functions.txt"
fi

write_tracefs current_tracer function
write_tracefs tracing_on 1

if [[ -n "$RUN_AS" && "$RUN_AS" != "root" ]]; then
	if ! command -v runuser >/dev/null 2>&1; then
		echo "error: runuser not available for CAPSCHED_TRACE_RUN_AS=$RUN_AS" >&2
		exit 1
	fi
	runuser -u "$RUN_AS" -- "${WORKLOAD[@]}"
else
	"${WORKLOAD[@]}"
fi

write_tracefs tracing_on 0
cat "$TRACEFS/trace" > "$OUT/trace.txt"

{
	echo "Trace captured in $OUT"
	echo "Review trace.txt and map observed paths back to analysis/0019."
	echo "This run is observation only and is not enforcement evidence."
} | tee "$OUT/summary.txt"
