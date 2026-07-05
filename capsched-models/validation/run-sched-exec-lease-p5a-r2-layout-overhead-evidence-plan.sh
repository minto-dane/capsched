#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-layout-overhead-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0119-p5a-r2-layout-overhead-evidence-plan-model"
MODEL="P5AR2LayoutOverheadEvidencePlan.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-layout-overhead-evidence-plan/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq java grep sed find wc basename awk tail; do
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
if [ "$(tail -n 1 "$series")" != '0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch' ]; then
	echo "series must currently end at experimental 0012" >&2
	tail -20 "$series" >&2
	exit 1
fi
if grep -q '^0013-' "$series"; then
	echo "0013 patch already exists; refresh this evidence plan before using it" >&2
	tail -20 "$series" >&2
	exit 1
fi

jq -e '
	.status == "evidence_plan_no_linux_patch_approved" and
	(.required_evidence_contract | all(.[]; . == true)) and
	((.source_anchors | length) == 40) and
	((.future_probe_outputs | length) == 10) and
	((.unsafe_families | length) == 36) and
	.formal.safe_expected_states_generated == 6 and
	.formal.safe_expected_distinct_states == 5 and
	.formal.safe_expected_depth == 5 and
	.formal.unsafe_cfg_count == 36 and
	.formal.unsafe_expected_counterexamples == 36 and
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

sched_h="$LINUX_DIR/include/linux/sched.h"
sched_internal_h="$LINUX_DIR/kernel/sched/sched.h"
fair_c="$LINUX_DIR/kernel/sched/fair.c"
task_layout_probe="$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh"
p5ar_object_runner="$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-p5a-r-0009-object-layout.sh"
p5ar_object_note="$CAPSCHED_DIR/capsched-models/validation/0175-sched-exec-lease-p5a-r-0009-object-layout.md"
prior_note="$CAPSCHED_DIR/capsched-models/$prior_validation"
blockers="$OUT_DIR/blockers.tsv"
printf 'kind\tdetail\n' > "$blockers"

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

l_sched_entity=$(line_of_first "$sched_h" 'struct sched_entity {')
l_run_node=$(line_after_symbol "$sched_h" 'struct sched_entity {' 'struct rb_node')
l_se_min_vruntime=$(line_after_symbol "$sched_h" 'struct sched_entity {' 'min_vruntime')
l_se_vruntime=$(line_after_symbol "$sched_h" 'sum_exec_runtime' 'vruntime')
l_se_parent=$(line_after_symbol "$sched_h" 'struct sched_entity {' '*parent')
l_cfs_rq=$(line_of_first "$sched_internal_h" 'struct cfs_rq {')
l_tasks_timeline=$(line_after_symbol "$sched_internal_h" 'struct cfs_rq {' 'tasks_timeline')
l_cfs_curr=$(line_after_symbol "$sched_internal_h" 'struct cfs_rq {' '*curr')
l_cfs_next=$(line_after_symbol "$sched_internal_h" 'struct cfs_rq {' '*next')
l_rq=$(line_of_first "$sched_internal_h" 'struct rq {')
l_rq_hot=$(line_after_symbol "$sched_internal_h" 'struct rq {' 'extremely hot loop')

l_min_update=$(line_of_first "$fair_c" 'static inline bool min_vruntime_update')
l_cb=$(line_of_first "$fair_c" 'RB_DECLARE_CALLBACKS(static, min_vruntime_cb')
l_enqueue=$(line_of_first "$fair_c" 'static void __enqueue_entity')
l_dequeue=$(line_of_first "$fair_c" 'static void __dequeue_entity')
l_scan=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_scan')
l_scan_next=$(line_after_symbol "$fair_c" 'sched_exec_cfs_pickable_scan' 'node = rb_next(node)) {')
l_fallback=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_fallback')
l_pick_eevdf=$(line_of_first "$fair_c" 'pick_eevdf')
l_single=$(line_after_symbol "$fair_c" 'pick_eevdf' 'if (cfs_rq->nr_queued == 1)')
l_heap=$(line_after_symbol "$fair_c" 'pick_eevdf' 'while (node)')
l_fallback_call=$(line_after_symbol "$fair_c" 'pick_eevdf' 'best = sched_exec_cfs_pickable_fallback')
l_pick_next_entity=$(line_of_first "$fair_c" 'pick_next_entity')
l_pick_task=$(line_of_first "$fair_c" '__pick_task_fair')

l_task_probe_size=$(line_after_symbol "$task_layout_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_task_struct_size_probe')
l_task_probe_offset=$(line_after_symbol "$task_layout_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_field_offset_plus_one_probe')
l_task_probe_field=$(line_after_symbol "$task_layout_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_field_size_probe')
l_object_off_build=$(line_of_first "$p5ar_object_runner" 'off_build=')
l_object_function_table=$(line_of_first "$p5ar_object_runner" 'make_function_table()')
l_object_nonclaim=$(line_of_first "$p5ar_object_note" 'This validation does not approve')
l_prior_anchor_count=$(line_of_first "$prior_note" 'source_anchor_count: 36')

missing_semantic=0
for v in l_sched_entity l_run_node l_se_min_vruntime l_se_vruntime l_se_parent \
	l_cfs_rq l_tasks_timeline l_cfs_curr l_cfs_next l_rq l_rq_hot \
	l_min_update l_cb l_enqueue l_dequeue l_scan l_scan_next l_fallback \
	l_pick_eevdf l_single l_heap l_fallback_call l_pick_next_entity l_pick_task \
	l_task_probe_size l_task_probe_offset l_task_probe_field \
	l_object_off_build l_object_function_table l_object_nonclaim l_prior_anchor_count; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

future_field_matches=$(grep -R -nE 'sched_exec_min_pickable|pickable_vruntime|min_pickable_vruntime' \
	"$LINUX_DIR/include/linux" "$LINUX_DIR/kernel/sched" 2>/dev/null || true)
future_field_match_count=$(printf '%s\n' "$future_field_matches" | sed '/^$/d' | wc -l)

hot_structures_observed=false
eevdf_update_paths_observed=false
existing_probe_basis_observed=false
future_fields_absent=false
experimental_replacement_target_observed=false

if [ "$missing_semantic" -eq 0 ]; then
	if [ "$l_sched_entity" -lt "$l_run_node" ] &&
	   [ "$l_run_node" -lt "$l_se_min_vruntime" ] &&
	   [ "$l_se_min_vruntime" -lt "$l_se_vruntime" ] &&
	   [ "$l_se_vruntime" -lt "$l_se_parent" ] &&
	   [ "$l_cfs_rq" -lt "$l_tasks_timeline" ] &&
	   [ "$l_tasks_timeline" -lt "$l_cfs_curr" ] &&
	   [ "$l_cfs_curr" -lt "$l_cfs_next" ] &&
	   [ "$l_rq" -lt "$l_rq_hot" ]; then
		hot_structures_observed=true
	fi
	if [ "$l_min_update" -lt "$l_cb" ] &&
	   [ "$l_cb" -lt "$l_enqueue" ] &&
	   [ "$l_enqueue" -lt "$l_dequeue" ] &&
	   [ "$l_dequeue" -lt "$l_pick_eevdf" ] &&
	   [ "$l_pick_eevdf" -lt "$l_heap" ] &&
	   [ "$l_heap" -lt "$l_fallback_call" ]; then
		eevdf_update_paths_observed=true
	fi
	if [ "$l_task_probe_size" -lt "$l_task_probe_offset" ] &&
	   [ "$l_task_probe_offset" -lt "$l_task_probe_field" ] &&
	   [ "$l_object_off_build" -lt "$l_object_function_table" ] &&
	   [ "$l_object_nonclaim" -gt 0 ] &&
	   [ "$l_prior_anchor_count" -gt 0 ]; then
		existing_probe_basis_observed=true
	fi
	if [ "$l_scan" -lt "$l_scan_next" ] &&
	   [ "$l_scan_next" -lt "$l_fallback" ] &&
	   [ "$l_fallback" -lt "$l_fallback_call" ] &&
	   [ "$l_pick_next_entity" -lt "$l_pick_task" ]; then
		experimental_replacement_target_observed=true
	fi
fi

if [ "$future_field_match_count" -eq 0 ]; then
	future_fields_absent=true
else
	printf '%s\n' "$future_field_matches" > "$OUT_DIR/future-field-matches.txt"
	echo -e "semantic\tfuture P5A-R2 fields already present" >> "$blockers"
fi

semantic_shape_ok=false
if $hot_structures_observed &&
   $eevdf_update_paths_observed &&
   $existing_probe_basis_observed &&
   $future_fields_absent &&
   $experimental_replacement_target_observed; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "source_anchor_count": $anchor_count,
  "hot_structures_observed": $hot_structures_observed,
  "eevdf_update_paths_observed": $eevdf_update_paths_observed,
  "existing_probe_basis_observed": $existing_probe_basis_observed,
  "future_fields_absent": $future_fields_absent,
  "future_field_match_count": $future_field_match_count,
  "experimental_replacement_target_observed": $experimental_replacement_target_observed,
  "anchors": {
    "sched_entity": ${l_sched_entity:-0},
    "sched_entity_run_node": ${l_run_node:-0},
    "sched_entity_min_vruntime": ${l_se_min_vruntime:-0},
    "sched_entity_vruntime": ${l_se_vruntime:-0},
    "sched_entity_parent": ${l_se_parent:-0},
    "cfs_rq": ${l_cfs_rq:-0},
    "tasks_timeline": ${l_tasks_timeline:-0},
    "cfs_curr": ${l_cfs_curr:-0},
    "cfs_next": ${l_cfs_next:-0},
    "rq": ${l_rq:-0},
    "rq_hot_loop_comment": ${l_rq_hot:-0},
    "min_vruntime_update": ${l_min_update:-0},
    "min_vruntime_callback": ${l_cb:-0},
    "enqueue_entity": ${l_enqueue:-0},
    "dequeue_entity": ${l_dequeue:-0},
    "experimental_scan": ${l_scan:-0},
    "experimental_scan_rb_next": ${l_scan_next:-0},
    "experimental_fallback": ${l_fallback:-0},
    "pick_eevdf": ${l_pick_eevdf:-0},
    "pick_eevdf_single": ${l_single:-0},
    "pick_eevdf_heap": ${l_heap:-0},
    "experimental_fallback_call": ${l_fallback_call:-0},
    "pick_next_entity": ${l_pick_next_entity:-0},
    "__pick_task_fair": ${l_pick_task:-0},
    "task_probe_size": ${l_task_probe_size:-0},
    "task_probe_offset": ${l_task_probe_offset:-0},
    "task_probe_field_size": ${l_task_probe_field:-0},
    "p5ar_object_off_build": ${l_object_off_build:-0},
    "p5ar_object_function_table": ${l_object_function_table:-0},
    "p5ar_object_nonclaim": ${l_object_nonclaim:-0},
    "prior_source_anchor_count": ${l_prior_anchor_count:-0}
  }
}
EOF_JSON

jq empty "$OUT_DIR/source-shape.json"
if ! $semantic_shape_ok; then
	echo "source shape failed" >&2
	cat "$OUT_DIR/source-shape.json" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2LayoutOverheadEvidencePlanSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2LayoutOverheadEvidencePlanUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2LayoutOverheadEvidencePlanUnsafe*.cfg' | wc -l)
if [ "$unsafe_expected" -ne 36 ] || [ "$cfg_count" -ne 36 ]; then
	echo "unsafe counterexample count mismatch: expected=36 actual=$unsafe_expected cfg_count=$cfg_count" >&2
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
  "hot_structures_observed": $hot_structures_observed,
  "eevdf_update_paths_observed": $eevdf_update_paths_observed,
  "existing_probe_basis_observed": $existing_probe_basis_observed,
  "future_fields_absent": $future_fields_absent,
  "experimental_replacement_target_observed": $experimental_replacement_target_observed,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
