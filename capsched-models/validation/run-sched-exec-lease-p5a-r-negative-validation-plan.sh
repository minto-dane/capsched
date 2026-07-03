#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-negative-validation-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0109-p5a-r-negative-validation-plan-model"
MODEL="P5ARNegativeValidationPlan.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-negative-validation-plan/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq awk java grep sed find wc; do
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

jq -e '
	.scope.linux_patch_approved == false and
	.scope.behavior_change_approved == false and
	.scope.test_instrumentation_approved == false and
	.scope.runtime_denial_approved == false and
	.scope.cfs_deny_and_repick_approved == false and
	((.negative_test_families | length) == .required_checks.negative_test_family_count) and
	((.required_observables | length) == .required_checks.required_observable_count) and
	.validation_layers.static_source_layer_required == true and
	.validation_layers.build_object_layout_layer_required == true and
	.validation_layers.runtime_negative_layer_required == true and
	.validation_layers.claim_layer_required == true and
	all(.safety_flags[]; . == false) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 17) and
	(.formal.unsafe_expected_counterexamples == 17)
' "$CONFIG" >/dev/null

prior_missing=0
prior_file="$OUT_DIR/prior-gates.tsv"
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
done < <(jq -r '.source_basis.prior_validation_gates[]' "$CONFIG")

if [ "$prior_missing" -ne 0 ]; then
	echo "missing prior validation gates: $prior_missing" >&2
	cat "$prior_file" >&2
	exit 1
fi

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tpath\texpected_line\tactual_line\tline_status\n' > "$anchors"
anchor_count=0
line_drift=0
missing_anchor=0

while IFS=$'\t' read -r id path symbol expected_line pattern; do
	anchor_count=$((anchor_count + 1))
	file="$WORKSPACE_DIR/$path"
	actual_line=""
	if [ -f "$file" ]; then
		start_line=$(awk -v sym="$symbol" 'index($0, sym) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
		if [ -n "$start_line" ]; then
			actual_line=$(awk -v start="$start_line" -v pat="$pattern" 'NR >= start && index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
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
done < <(jq -r '.source_anchors[] | [.id, .path, .symbol, (.expected_line | tostring), .pattern] | @tsv' "$CONFIG")

if [ "$missing_anchor" -ne 0 ]; then
	echo "missing source anchors: $missing_anchor" >&2
	cat "$anchors" >&2
	exit 1
fi

core_c="$LINUX_DIR/kernel/sched/core.c"
fair_c="$LINUX_DIR/kernel/sched/fair.c"
blockers="$OUT_DIR/blockers.tsv"
printf 'kind\tdetail\n' > "$blockers"

line_of_first() {
	local file=$1
	local pattern=$2
	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

l_fair_pick=$(line_of_first "$core_c" 'p = pick_task_fair(rq, rf);')
l_run_edge=$(line_of_first "$core_c" '(void)sched_exec_lease_validate_run_edge(prev, next);')
l_rq_curr=$(line_of_first "$core_c" 'RCU_INIT_POINTER(rq->curr, next);')
l_sched_switch=$(line_of_first "$core_c" 'trace_sched_switch(preempt, prev, next, prev_state);')
l_task_of=$(awk '/struct task_struct \*pick_task_fair/ { start=NR } start && index($0, "p = task_of(se);") { print NR; exit }' "$fair_c")

missing_semantic=0
for v in l_fair_pick l_run_edge l_rq_curr l_sched_switch l_task_of; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

order_ok=1
if [ "$missing_semantic" -eq 0 ]; then
	if ! [ "$l_fair_pick" -lt "$l_run_edge" ] ||
	   ! [ "$l_run_edge" -lt "$l_rq_curr" ] ||
	   ! [ "$l_rq_curr" -lt "$l_sched_switch" ]; then
		order_ok=0
		echo -e 'semantic\tnegative validation anchor order failed' >> "$blockers"
	fi
else
	order_ok=0
fi

semantic_shape_ok=false
if [ "$missing_semantic" -eq 0 ] && [ "$order_ok" -eq 1 ]; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/negative-validation-source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "prior_missing_count": $prior_missing,
  "negative_test_family_count": $(jq '.negative_test_families | length' "$CONFIG"),
  "required_observable_count": $(jq '.required_observables | length' "$CONFIG"),
  "anchors": {
    "fair_pick": ${l_fair_pick:-0},
    "task_of_in_pick_task_fair": ${l_task_of:-0},
    "run_edge": ${l_run_edge:-0},
    "rq_curr_publication": ${l_rq_curr:-0},
    "sched_switch": ${l_sched_switch:-0}
  },
  "relative_order_ok": $(if [ "$order_ok" -eq 1 ]; then echo true; else echo false; fi)
}
EOF_JSON

cat > "$OUT_DIR/nonclaim-results.json" <<EOF_JSON
{
  "status": "passed",
  "linux_patch_approved": false,
  "behavior_change_approved": false,
  "test_instrumentation_approved": false,
  "runtime_denial_approved": false,
  "cfs_deny_and_repick_approved": false,
  "runtime_coverage_claim": false,
  "benchmark_claim": false,
  "monitor_verified": false,
  "production_protection": false,
  "cost_efficiency_claim": false,
  "datacenter_ready": false
}
EOF_JSON

jq empty "$OUT_DIR/negative-validation-source-shape.json" "$OUT_DIR/nonclaim-results.json"

if ! $semantic_shape_ok; then
	echo "negative validation source shape failed" >&2
	cat "$blockers" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5ARNegativeValidationPlanSafe.cfg "$MODEL"
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

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5ARNegativeValidationPlanUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-$name-states" -config "$(basename "$cfg")" "$MODEL"
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5ARNegativeValidationPlanUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 17 ] || [ "$cfg_count" -ne 17 ]; then
	echo "unsafe counterexample mismatch: expected=17 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF_JSON
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "model_dir": "$MODEL_DIR",
  "linux_commit": "$actual_linux_commit",
  "anchor_count": $anchor_count,
  "missing_anchor_count": $missing_anchor,
  "line_drift_count": $line_drift,
  "prior_missing_count": $prior_missing,
  "semantic_shape_ok": true,
  "negative_test_family_count": $(jq '.negative_test_families | length' "$CONFIG"),
  "required_observable_count": $(jq '.required_observables | length' "$CONFIG"),
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF_JSON

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
