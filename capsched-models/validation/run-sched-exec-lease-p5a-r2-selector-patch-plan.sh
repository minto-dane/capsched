#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-selector-patch-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0117-p5a-r2-selector-patch-plan-model"
MODEL="P5AR2SelectorPatchPlan.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-selector-patch-plan/$RUN_ID"

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

prior_missing=0
prior_file="$OUT_DIR/prior-validations.tsv"
printf 'path\tstatus\n' > "$prior_file"
while IFS= read -r path; do
	full="$CAPSCHED_DIR/capsched-models/$path"
	if [ -f "$full" ]; then
		status=present
	else
		status=missing
		prior_missing=$((prior_missing + 1))
	fi
	printf '%s\t%s\n' "$path" "$status" >> "$prior_file"
done < <(jq -r '.source_basis.prior_validations[]' "$CONFIG")

if [ "$prior_missing" -ne 0 ]; then
	echo "missing prior validations: $prior_missing" >&2
	cat "$prior_file" >&2
	exit 1
fi

series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
if ! grep -qx '0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch' "$series"; then
	echo "series must currently end at experimental 0012" >&2
	tail -20 "$series" >&2
	exit 1
fi
if grep -q '^0013-' "$series"; then
	echo "0013 patch already exists; refresh this plan before using it" >&2
	tail -20 "$series" >&2
	exit 1
fi

jq -e '
	.status == "source_design_patch_plan_no_linux_patch_approved" and
	(.required_patch_contract | all(.[]; . == true)) and
	.existing_experimental_blockers.post_filter_fallback_present == true and
	.existing_experimental_blockers.unbounded_rb_next_scan_present == true and
	.existing_experimental_blockers.future_patch_must_replace_not_extend == true and
	.existing_experimental_blockers.existing_0012_accepted == false and
	((.source_basis.prior_validations | length) == 6) and
	((.source_anchors | length) == 21) and
	((.required_acceptance_validation | length) == 20) and
	.formal.safe_expected_states_generated == 6 and
	.formal.safe_expected_distinct_states == 5 and
	.formal.safe_expected_depth == 5 and
	.formal.unsafe_cfg_count == 30 and
	.formal.unsafe_expected_counterexamples == 30 and
	(.safety_flags | all(.[]; . == false)) and
	.next.linux_patch_allowed_after_this_gate == false
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tpath\texpected_line\tactual_line\tline_status\n' > "$anchors"
anchor_count=0
line_drift=0
missing_anchor=0

while IFS=$'\t' read -r id path expected_line pattern; do
	anchor_count=$((anchor_count + 1))
	file="$WORKSPACE_DIR/$path"
	actual_line=""
	if [ -f "$file" ]; then
		actual_line=$(awk -v pat="$pattern" 'index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
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
done < <(jq -r '.source_anchors[] | [.id, .path, (.expected_line | tostring), .pattern] | @tsv' "$CONFIG")

if [ "$missing_anchor" -ne 0 ]; then
	echo "missing source anchors: $missing_anchor" >&2
	cat "$anchors" >&2
	exit 1
fi

fair_c="$LINUX_DIR/kernel/sched/fair.c"
core_c="$LINUX_DIR/kernel/sched/core.c"

line_of_first() {
	local file=$1
	local pattern=$2
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

l_scan=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_scan')
l_scan_next=$(awk '/sched_exec_cfs_pickable_scan/ { start=NR } start && index($0, "node = rb_next(node)") { print NR; exit }' "$fair_c")
l_fallback=$(line_of_first "$fair_c" 'sched_exec_cfs_pickable_fallback')
l_fallback_call=$(line_of_first "$fair_c" 'best = sched_exec_cfs_pickable_fallback')
l_min_cb=$(line_of_first "$fair_c" 'RB_DECLARE_CALLBACKS(static, min_vruntime_cb')
l_pick_eevdf=$(line_of_first "$fair_c" 'pick_eevdf')
l_heap=$(awk '/pick_eevdf/ { start=NR } start && index($0, "while (node)") { print NR; exit }' "$fair_c")
l_direct=$(line_of_first "$core_c" 'p = pick_task_fair_sched_exec_lease')
l_class_loop=$(line_of_first "$core_c" 'for_each_active_class(class)')
l_sched_exec_pick=$(line_of_first "$fair_c" 'pick_task_fair_sched_exec_lease')
l_fair_server=$(line_of_first "$fair_c" 'return pick_task_fair(dl_se->rq, rf)')

missing_semantic=0
for v in l_scan l_scan_next l_fallback l_fallback_call l_min_cb l_pick_eevdf l_heap l_direct l_class_loop l_sched_exec_pick l_fair_server; do
	if [ -z "${!v:-}" ]; then
		missing_semantic=$((missing_semantic + 1))
	fi
done

experimental_blocker_observed=false
selector_basis_observed=false
ordinary_scope_observed=false
if [ "$missing_semantic" -eq 0 ]; then
	if [ "$l_scan" -lt "$l_fallback" ] &&
	   [ "$l_scan" -lt "$l_scan_next" ] &&
	   [ "$l_fallback" -lt "$l_fallback_call" ]; then
		experimental_blocker_observed=true
	fi
	if [ "$l_min_cb" -lt "$l_pick_eevdf" ] &&
	   [ "$l_pick_eevdf" -lt "$l_heap" ] &&
	   [ "$l_heap" -lt "$l_fallback_call" ]; then
		selector_basis_observed=true
	fi
	if [ "$l_direct" -lt "$l_class_loop" ] &&
	   [ "$l_sched_exec_pick" -lt "$l_fair_server" ]; then
		ordinary_scope_observed=true
	fi
fi

semantic_shape_ok=false
if $experimental_blocker_observed && $selector_basis_observed && $ordinary_scope_observed; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "source_anchor_count": $anchor_count,
  "prior_missing_count": $prior_missing,
  "experimental_blocker_observed": $experimental_blocker_observed,
  "selector_basis_observed": $selector_basis_observed,
  "ordinary_scope_observed": $ordinary_scope_observed,
  "anchors": {
    "experimental_scan": ${l_scan:-0},
    "experimental_scan_rb_next": ${l_scan_next:-0},
    "experimental_fallback": ${l_fallback:-0},
    "experimental_fallback_call": ${l_fallback_call:-0},
    "min_vruntime_callback": ${l_min_cb:-0},
    "pick_eevdf": ${l_pick_eevdf:-0},
    "eevdf_heap_search": ${l_heap:-0},
    "ordinary_direct_pick": ${l_direct:-0},
    "class_loop_boundary": ${l_class_loop:-0},
    "sched_exec_pick_entry": ${l_sched_exec_pick:-0},
    "fair_server_plain_pick": ${l_fair_server:-0}
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
		-config P5AR2SelectorPatchPlanSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2SelectorPatchPlanUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2SelectorPatchPlanUnsafe*.cfg' | wc -l)
if [ "$unsafe_expected" -ne 30 ] || [ "$cfg_count" -ne 30 ]; then
	echo "unsafe counterexample count mismatch: expected=30 actual=$unsafe_expected cfg_count=$cfg_count" >&2
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
  "prior_missing_count": $prior_missing,
  "source_anchor_count": $anchor_count,
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "experimental_blocker_observed": $experimental_blocker_observed,
  "selector_basis_observed": $selector_basis_observed,
  "ordinary_scope_observed": $ordinary_scope_observed,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

cat "$OUT_DIR/result.json"
