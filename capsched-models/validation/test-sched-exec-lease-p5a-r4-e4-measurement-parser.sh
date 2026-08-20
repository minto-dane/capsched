#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PARSER="$SCRIPT_DIR/parse-sched-exec-lease-p5a-r4-e4-measurement-evidence.sh"
TMP=${TMPDIR:-/tmp}/p5a-r4-e4-parser-test.$$
ROWS="$TMP/rows.txt"
SUMMARIES="$TMP/summaries.txt"

cleanup()
{
	find "$TMP" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

mkdir -p "$TMP"

emit_row()
{
	local family=$1 operations=$2 asynchronous=$3 irq=$4 preempt=$5
	shift 5
	local async_stats='async_min=0 async_p50=0 async_p95=0 async_p99=0 async_p999=0 async_max=0'
	local async_gate=na
	if [ "$asynchronous" = 1 ]; then
		async_stats='async_min=100 async_p50=200 async_p95=300 async_p99=400 async_p999=450 async_max=500'
		async_gate=pass
	fi
	printf 'R4_E4_RESULT family=%s %s samples=10000 warmups=256 operations=%s measurement_cpu=0 cpu_migrations=0 control_irqs_disabled=%s treatment_irqs_disabled=%s control_preempt_depth=%s treatment_preempt_depth=%s state_errors=0 control_min=10 control_p50=20 control_p95=30 control_p99=40 control_p999=45 control_max=50 treatment_min=20 treatment_p50=30 treatment_p95=40 treatment_p99=50 treatment_p999=55 treatment_max=60 additional_min=0 additional_p50=5 additional_p95=10 additional_p99=15 additional_p999=20 additional_max=25 %s local_gate=pass async_gate=%s harness_errors=0\n' \
		"$family" "$*" "$operations" "$irq" "$irq" "$preempt" "$preempt" "$async_stats" "$async_gate"
}

{
	for active in 0 1 2; do for occupancy in 1 8 32 64; do for inner in 0 1 64 4096; do for burst in 1 64 4096; do for owner in clear owned_restart; do
		emit_row publication 1 0 0 0 "active_rqs=$active" "occupancy=$occupancy" "inner=$inner" "burst=$burst" "owner=$owner"
	done; done; done; done; done
	for occupancy in 1 8 32 64; do for inner in 0 1 64 4096; do for burst in 1 64 4096; do for owner in idle dirty_irq_pending work_running; do
		emit_row picker_kick 1 0 1 1 "occupancy=$occupancy" "inner=$inner" "burst=$burst" "owner=$owner"
	done; done; done; done
	for outcome in queued false_pending false_running; do for depth in 0 1 64; do
		emit_row irq_dispatch 1 0 1 65536 "queue_work=$outcome" "unrelated_depth=$depth"
	done; done
	for depth in 1 8 32 64; do for occupancy in 1 8 32 64; do for class in queued delayed current; do for outcome in settle republished_race blocked; do
		emit_row recovery 1 0 1 1 "dirty_depth=$depth" "occupancy=$occupancy" "class=$class" "outcome=$outcome"
	done; done; done; done
	for active in 1 2; do for cursor in first last end_of_pass; do for membership in stable changed_restart; do for class in queued current; do for owner in idle coalesced; do
		emit_row notifier 1 0 0 0 "active_rqs=$active" "cursor=$cursor" "membership=$membership" "class=$class" "owner=$owner"
	done; done; done; done; done
	for source in recovery notifier; do for observation in current_changed same_current_revalidated; do for owner in idle coalesced; do for burst in 1 64 4096; do
		emit_row current_stop 1 1 1 1 "source=$source" "observation=$observation" "owner=$owner" "burst=$burst"
	done; done; done; done
	for occupancy in 0 1 8 32 64; do for callback in idle irq_pending work_pending work_running self_requeue; do
		emit_row offline "$occupancy" 1 1 1 "occupancy=$occupancy" "callback=$callback"
	done; done
} > "$ROWS"

cat > "$SUMMARIES" <<'EOF'
R4_E4_SUMMARY family=publication rows=288 rejected_cells=0 harness_errors=0
R4_E4_SUMMARY family=picker_kick rows=144 rejected_cells=0 harness_errors=0
R4_E4_SUMMARY family=irq_dispatch rows=9 rejected_cells=0 harness_errors=0
R4_E4_SUMMARY family=recovery rows=144 rejected_cells=0 harness_errors=0
R4_E4_SUMMARY family=notifier rows=48 rejected_cells=0 harness_errors=0 logical_final_bound=2*A
R4_E4_SUMMARY family=current_stop rows=24 rejected_cells=0 harness_errors=0 availability_only=1
R4_E4_SUMMARY family=offline rows=25 rejected_cells=0 harness_errors=0 availability_only=1
EOF

run_accept()
{
	local label=$1 rows=$2 summaries=$3
	GUEST_VCPUS=2 "$PARSER" "$rows" "$summaries" "$TMP/out-$label" >/dev/null
	jq -e '.status == "passed_exact_682_cell_parser" and .result_rows == 682 and .measured_pairs == 6820000 and .rejected_cells == 0 and .threshold_breaches == 0' "$TMP/out-$label/result.json" >/dev/null
	printf 'ok: %s\n' "$label"
}

run_reject()
{
	local label=$1 rows=$2 summaries=$3
	if GUEST_VCPUS=2 "$PARSER" "$rows" "$summaries" "$TMP/out-$label" >/dev/null 2>&1; then
		printf 'error: parser accepted tamper: %s\n' "$label" >&2
		exit 1
	fi
	printf 'ok: rejected %s\n' "$label"
}

run_accept exact "$ROWS" "$SUMMARIES"

sed '1s/additional_p99=15 additional_p999=20 additional_max=25/additional_p99=6000 additional_p999=6000 additional_max=6000/; 1s/local_gate=pass/local_gate=reject/' "$ROWS" > "$TMP/valid-negative.txt"
sed 's/family=publication rows=288 rejected_cells=0/family=publication rows=288 rejected_cells=1/' "$SUMMARIES" > "$TMP/valid-negative-summaries.txt"
GUEST_VCPUS=2 "$PARSER" "$TMP/valid-negative.txt" "$TMP/valid-negative-summaries.txt" "$TMP/out-valid-negative" >/dev/null
jq -e '.status == "passed_exact_682_cell_parser" and .rejected_cells == 1 and .threshold_breaches == 1' "$TMP/out-valid-negative/result.json" >/dev/null
printf 'ok: valid threshold rejection remains evidence, not harness failure\n'

sed '1d' "$ROWS" > "$TMP/missing-row.txt"
run_reject missing-row "$TMP/missing-row.txt" "$SUMMARIES"

sed '1s/cpu_migrations=0/cpu_migrations=1/' "$ROWS" > "$TMP/migration.txt"
run_reject observed-migration "$TMP/migration.txt" "$SUMMARIES"

sed '1s/local_gate=pass/local_gate=reject/' "$ROWS" > "$TMP/gate.txt"
run_reject gate-mismatch "$TMP/gate.txt" "$SUMMARIES"

sed '1s/harness_errors=0/harness_errors=0 unknown=1/' "$ROWS" > "$TMP/unknown-key.txt"
run_reject unknown-key "$TMP/unknown-key.txt" "$SUMMARIES"

sed 's/family=offline rows=25/family=offline rows=24/' "$SUMMARIES" > "$TMP/summary.txt"
run_reject summary-mismatch "$ROWS" "$TMP/summary.txt"

printf 'all R4-E4 measurement parser tests passed\n'
