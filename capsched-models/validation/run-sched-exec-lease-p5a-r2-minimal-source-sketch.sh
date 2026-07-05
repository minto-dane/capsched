#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-minimal-source-sketch-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0118-p5a-r2-minimal-source-sketch-model"
MODEL="P5AR2MinimalSourceSketch.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-minimal-source-sketch/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq java grep sed find wc basename awk; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "missing command: $cmd" >&2
		exit 1
	fi
done

if [ ! -f "$TLA_JAR" ]; then
	echo "missing TLA jar: $TLA_JAR" >&2
	exit 1
fi

jq empty "$CONFIG"

expected_linux_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_linux_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
if [ "$actual_linux_commit" != "$expected_linux_commit" ]; then
	echo "linux commit mismatch: expected=$expected_linux_commit actual=$actual_linux_commit" >&2
	exit 1
fi

expected_tree=$(jq -r '.source_basis.local_tree' "$CONFIG")
actual_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^{tree})
if [ "$actual_tree" != "$expected_tree" ]; then
	echo "linux tree mismatch: expected=$expected_tree actual=$actual_tree" >&2
	exit 1
fi

prior_validation=$(jq -r '.source_basis.prior_validation' "$CONFIG")
if [ ! -f "$CAPSCHED_DIR/capsched-models/$prior_validation" ]; then
	echo "missing prior validation: $prior_validation" >&2
	exit 1
fi

series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
if ! grep -qx '0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch' "$series"; then
	echo "series must currently end at experimental 0012" >&2
	tail -20 "$series" >&2
	exit 1
fi
if grep -q '^0013-' "$series"; then
	echo "0013 patch already exists; refresh this sketch before using it" >&2
	tail -20 "$series" >&2
	exit 1
fi

jq -e '
	.status == "source_sketch_no_linux_patch_approved" and
	(.minimal_sketch | all(.[]; . == true)) and
	.field_sketch.names_are_provisional == true and
	.field_sketch.approval_status == "not_approved_without_layout_evidence" and
	((.source_anchors | length) == 36) and
	((.unsafe_families | length) == 32) and
	.formal.safe_expected_states_generated == 6 and
	.formal.safe_expected_distinct_states == 5 and
	.formal.safe_expected_depth == 5 and
	.formal.unsafe_cfg_count == 32 and
	.formal.unsafe_expected_counterexamples == 32 and
	(.safety_flags | all(.[]; . == false)) and
	.next.linux_patch_allowed_after_this_gate == false
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tpath\texpected_line\tactual_line\tline_status\n' > "$anchors"
anchor_count=0
line_drift=0
missing_anchor=0

while IFS=$'\t' read -r id path expected_line symbol pattern; do
	anchor_count=$((anchor_count + 1))
	file="$WORKSPACE_DIR/$path"
	actual_line=""
	if [ -f "$file" ]; then
		if [ "$symbol" != "-" ]; then
			start_line=$(awk -v sym="$symbol" 'index($0, sym) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
			if [ -n "$start_line" ]; then
				actual_line=$(awk -v start="$start_line" -v pat="$pattern" 'NR >= start && index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
			fi
		else
			actual_line=$(awk -v pat="$pattern" 'index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
		fi
	fi
	if [ -z "$actual_line" ]; then
		status=missing
		missing_anchor=$((missing_anchor + 1))
	elif [ "$actual_line" = "$expected_line" ]; then
		status=ok
	else
		status=line_drift
		line_drift=$((line_drift + 1))
	fi
	printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "$expected_line" "${actual_line:-missing}" "$status" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .path, (.expected_line | tostring), (.symbol // "-"), .pattern] | @tsv' "$CONFIG")

if [ "$missing_anchor" -ne 0 ]; then
	echo "missing source anchors: $missing_anchor" >&2
	cat "$anchors" >&2
	exit 1
fi

fair_c="$LINUX_DIR/kernel/sched/fair.c"
sched_h="$LINUX_DIR/include/linux/sched.h"
sched_internal_h="$LINUX_DIR/kernel/sched/sched.h"
core_c="$LINUX_DIR/kernel/sched/core.c"

line_of_first() {
	local file=$1
	local pattern=$2
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

line_after_symbol() {
	local file=$1
	local symbol=$2
	local pattern=$3
	awk -v sym="$symbol" -v pat="$pattern" '
		index($0, sym) { start=NR }
		start && index($0, pat) { print NR; exit }
	' "$file"
}

l_task_shadow=$(line_of_first "$LINUX_DIR/include/linux/sched_exec_lease.h" 'struct sched_exec_task {')
l_task_field=$(line_of_first "$sched_h" 'struct sched_exec_task')
l_min_update=$(line_of_first "$fair_c" 'static inline void __min_vruntime_update')
l_cb=$(line_of_first "$fair_c" 'RB_DECLARE_CALLBACKS(static, min_vruntime_cb')
l_enqueue=$(line_of_first "$fair_c" 'static void __enqueue_entity')
l_dequeue=$(line_of_first "$fair_c" 'static void __dequeue_entity')
l_scan=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_scan')
l_scan_next=$(line_after_symbol "$fair_c" 'sched_exec_cfs_pickable_scan' 'node = rb_next(node)) {')
l_fallback=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_fallback')
l_pick_eevdf=$(line_of_first "$fair_c" 'pick_eevdf')
l_heap=$(line_after_symbol "$fair_c" 'pick_eevdf' 'while (node)')
l_fallback_call=$(line_of_first "$fair_c" 'best = sched_exec_cfs_pickable_fallback')
l_se_layout=$(line_of_first "$sched_h" 'struct sched_entity {')
l_se_min=$(line_of_first "$sched_h" 'min_vruntime')
l_cfs_layout=$(line_of_first "$sched_internal_h" 'struct cfs_rq {')
l_cfs_timeline=$(line_of_first "$sched_internal_h" 'tasks_timeline')
l_cfs_curr=$(line_of_first "$sched_internal_h" '*curr')
l_pick_next_entity=$(line_of_first "$fair_c" 'pick_next_entity')
l_pick_next_eevdf=$(line_after_symbol "$fair_c" 'pick_next_entity' 'se = pick_eevdf')
l_delayed=$(line_after_symbol "$fair_c" 'pick_next_entity' 'if (se->sched_delayed)')
l_reenqueue_curr=$(line_after_symbol "$fair_c" 'put_prev_entity' '__enqueue_entity(cfs_rq, prev)')
l_pick_task=$(line_of_first "$fair_c" '__pick_task_fair')
l_current_update=$(line_after_symbol "$fair_c" '__pick_task_fair' 'if (cfs_rq->curr && cfs_rq->curr->on_rq)')
l_pick_next_call=$(line_after_symbol "$fair_c" '__pick_task_fair' 'se = pick_next_entity')
l_group_descent=$(line_after_symbol "$fair_c" '__pick_task_fair' 'cfs_rq = group_cfs_rq(se)')
l_task_leaf=$(line_after_symbol "$fair_c" '__pick_task_fair' 'p = task_of(se)')
l_late_validate=$(line_after_symbol "$fair_c" '__pick_task_fair' 'sched_exec_cfs_validate_candidate(sched_exec_pick, p)')
l_newidle=$(line_after_symbol "$fair_c" '__pick_task_fair' 'new_tasks = sched_balance_newidle')
l_test_denies=$(line_of_first "$fair_c" 'sched_exec_cfs_test_denies')
l_run_edge=$(line_of_first "$core_c" 'sched_exec_lease_validate_run_edge')

missing_semantic=0
for v in l_task_shadow l_task_field l_min_update l_cb l_enqueue l_dequeue \
	 l_scan l_scan_next l_fallback l_pick_eevdf l_heap l_fallback_call \
	 l_se_layout l_se_min l_cfs_layout l_cfs_timeline l_cfs_curr \
	 l_pick_next_entity l_pick_next_eevdf l_delayed l_reenqueue_curr \
	 l_pick_task l_current_update l_pick_next_call l_group_descent l_task_leaf \
	 l_late_validate l_newidle l_test_denies l_run_edge; do
	if [ -z "${!v:-}" ]; then
		missing_semantic=$((missing_semantic + 1))
	fi
done

augmentation_basis_observed=false
experimental_replacement_target_observed=false
current_group_boundaries_observed=false
hot_layout_conditional_basis_observed=false
late_validation_observed=false

if [ "$missing_semantic" -eq 0 ]; then
	if [ "$l_min_update" -lt "$l_cb" ] &&
	   [ "$l_cb" -lt "$l_enqueue" ] &&
	   [ "$l_enqueue" -lt "$l_dequeue" ] &&
	   [ "$l_dequeue" -lt "$l_pick_eevdf" ] &&
	   [ "$l_pick_eevdf" -lt "$l_heap" ]; then
		augmentation_basis_observed=true
	fi
	if [ "$l_scan" -lt "$l_scan_next" ] &&
	   [ "$l_scan_next" -lt "$l_fallback" ] &&
	   [ "$l_fallback" -lt "$l_fallback_call" ]; then
		experimental_replacement_target_observed=true
	fi
	if [ "$l_pick_next_entity" -lt "$l_pick_task" ] &&
	   [ "$l_pick_next_eevdf" -lt "$l_pick_task" ] &&
	   [ "$l_current_update" -lt "$l_pick_next_call" ] &&
	   [ "$l_pick_next_call" -lt "$l_group_descent" ] &&
	   [ "$l_group_descent" -lt "$l_task_leaf" ]; then
		current_group_boundaries_observed=true
	fi
	if [ "$l_se_layout" -lt "$l_se_min" ] &&
	   [ "$l_cfs_layout" -lt "$l_cfs_timeline" ] &&
	   [ "$l_cfs_timeline" -lt "$l_cfs_curr" ] &&
	   [ "$l_task_shadow" -lt "$l_task_field" ]; then
		hot_layout_conditional_basis_observed=true
	fi
	if [ "$l_test_denies" -lt "$l_late_validate" ] &&
	   [ "$l_late_validate" -gt "$l_task_leaf" ] &&
	   [ "$l_run_edge" -gt 0 ]; then
		late_validation_observed=true
	fi
fi

semantic_shape_ok=false
if $augmentation_basis_observed &&
   $experimental_replacement_target_observed &&
   $current_group_boundaries_observed &&
   $hot_layout_conditional_basis_observed &&
   $late_validation_observed; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "source_anchor_count": $anchor_count,
  "augmentation_basis_observed": $augmentation_basis_observed,
  "experimental_replacement_target_observed": $experimental_replacement_target_observed,
  "current_group_boundaries_observed": $current_group_boundaries_observed,
  "hot_layout_conditional_basis_observed": $hot_layout_conditional_basis_observed,
  "late_validation_observed": $late_validation_observed,
  "anchors": {
    "task_shadow": ${l_task_shadow:-0},
    "task_field": ${l_task_field:-0},
    "min_vruntime_update": ${l_min_update:-0},
    "min_vruntime_callback": ${l_cb:-0},
    "enqueue_entity": ${l_enqueue:-0},
    "dequeue_entity": ${l_dequeue:-0},
    "experimental_scan": ${l_scan:-0},
    "experimental_scan_rb_next": ${l_scan_next:-0},
    "experimental_fallback": ${l_fallback:-0},
    "pick_eevdf": ${l_pick_eevdf:-0},
    "eevdf_heap": ${l_heap:-0},
    "experimental_fallback_call": ${l_fallback_call:-0},
    "pick_next_entity": ${l_pick_next_entity:-0},
    "pick_next_eevdf": ${l_pick_next_eevdf:-0},
    "delayed_dequeue": ${l_delayed:-0},
    "reenqueue_current": ${l_reenqueue_curr:-0},
    "pick_task": ${l_pick_task:-0},
    "current_update": ${l_current_update:-0},
    "pick_next_call": ${l_pick_next_call:-0},
    "group_descent": ${l_group_descent:-0},
    "task_leaf": ${l_task_leaf:-0},
    "late_validate": ${l_late_validate:-0},
    "newidle": ${l_newidle:-0},
    "test_denies": ${l_test_denies:-0},
    "run_edge": ${l_run_edge:-0}
  }
}
EOF_JSON

jq empty "$OUT_DIR/source-shape.json"
if ! $semantic_shape_ok; then
	echo "source shape failed" >&2
	cat "$OUT_DIR/source-shape.json" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2MinimalSourceSketchSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1

if ! grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log"; then
	echo "safe TLC model did not pass" >&2
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	exit 1
fi

state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

if [ "${safe_states:-0}" -ne 6 ] ||
   [ "${safe_distinct:-0}" -ne 5 ] ||
   [ "${safe_depth:-0}" -ne 5 ]; then
	echo "safe TLC size mismatch: states=${safe_states:-0} distinct=${safe_distinct:-0} depth=${safe_depth:-0}" >&2
	exit 1
fi

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5AR2MinimalSourceSketchUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" \
			-config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		echo "unsafe config unexpectedly passed: $(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		echo "unsafe config failed for unexpected reason: $(basename "$cfg")" >&2
		tail -80 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done

if [ "$unsafe_fail" -ne 0 ]; then
	exit 1
fi

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2MinimalSourceSketchUnsafe*.cfg' | wc -l)
if [ "$unsafe_expected" -ne 32 ] || [ "$cfg_count" -ne 32 ]; then
	echo "unsafe counterexample count mismatch: expected=32 actual=$unsafe_expected cfg_count=$cfg_count" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "model_dir": "$MODEL_DIR",
  "linux_commit": "$actual_linux_commit",
  "linux_tree": "$actual_tree",
  "source_anchor_count": $anchor_count,
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "augmentation_basis_observed": $augmentation_basis_observed,
  "experimental_replacement_target_observed": $experimental_replacement_target_observed,
  "current_group_boundaries_observed": $current_group_boundaries_observed,
  "hot_layout_conditional_basis_observed": $hot_layout_conditional_basis_observed,
  "late_validation_observed": $late_validation_observed,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

cat "$OUT_DIR/result.json"
