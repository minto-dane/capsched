#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-layout-probe-patch-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0120-p5a-r2-layout-probe-patch-plan-model"
MODEL="P5AR2LayoutProbePatchPlan.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-layout-probe-patch-plan/$RUN_ID"

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
prior_evidence_plan=$(jq -r '.source_basis.prior_evidence_plan' "$CONFIG")
for prior in "$prior_validation" "$prior_evidence_plan"; do
	if [ ! -f "$CAPSCHED_DIR/capsched-models/$prior" ]; then
		echo "missing prior artifact: $prior" >&2
		exit 1
	fi
done

series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
if [ "$(tail -n 1 "$series")" != '0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch' ]; then
	echo "series must currently end at experimental 0012" >&2
	tail -20 "$series" >&2
	exit 1
fi
if grep -q '^0013-' "$series"; then
	echo "0013 patch already exists; refresh this patch-plan gate before using it" >&2
	tail -20 "$series" >&2
	exit 1
fi

jq -e '
	.status == "layout_probe_patch_plan_no_linux_patch_created" and
	.candidate_patch_plan.next_patch_slot == "0013" and
	.candidate_patch_plan.linux_patch_created == false and
	.candidate_patch_plan.linux_patch_approved == false and
	.candidate_patch_plan.behavior_change_allowed == false and
	.candidate_patch_plan.normal_config_modes_must_not_build_probe == true and
	.candidate_patch_plan.probe_config_must_default_n == true and
	.candidate_patch_plan.main_config_must_not_select_probe == true and
	.candidate_patch_plan.runtime_callsite_change_allowed == false and
	(.candidate_patch_plan.allowed_linux_paths | length == 3) and
	.probe_contract.external_module_only_is_insufficient == true and
	.probe_contract.normal_config_off_probe_object_absent == true and
	.probe_contract.normal_config_on_probe_object_absent == true and
	.probe_contract.probe_on_build_object_present == true and
	.probe_contract.symbols_non_exported == true and
	.probe_contract.public_abi == false and
	.probe_contract.trace_abi == false and
	.probe_contract.monitor_abi == false and
	.probe_contract.runtime_behavior == false and
	(.required_measurements | all(.[]; . == true)) and
	(.required_validation_after_patch | all(.[]; . == true)) and
	((.source_anchors | length) == 32) and
	((.absence_checks | length) == 3) and
	.formal.safe_expected_states_generated == 6 and
	.formal.safe_expected_distinct_states == 5 and
	.formal.safe_expected_depth == 5 and
	.formal.unsafe_cfg_count == 31 and
	.formal.unsafe_expected_counterexamples == 31 and
	(.safety_flags | all(.[]; . == false)) and
	.next.linux_patch_allowed_after_this_gate == true and
	.next.behavior_patch_allowed_after_this_gate == false
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

absence_results="$OUT_DIR/absence-results.tsv"
printf 'id\tmatch_count\tstatus\n' > "$absence_results"
absence_failure=0
while IFS=$'\t' read -r id paths_json patterns_json; do
	matches="$OUT_DIR/absence-$id.txt"
	: > "$matches"
	while IFS= read -r rel_path; do
		path="$WORKSPACE_DIR/$rel_path"
		if [ -d "$path" ]; then
			while IFS= read -r pattern; do
				grep -R -n -F "$pattern" "$path" >> "$matches" 2>/dev/null || true
			done < <(printf '%s\n' "$patterns_json" | jq -r '.[]')
		elif [ -f "$path" ]; then
			while IFS= read -r pattern; do
				grep -n -F "$pattern" "$path" >> "$matches" 2>/dev/null || true
			done < <(printf '%s\n' "$patterns_json" | jq -r '.[]')
		else
			echo "absence path missing: $rel_path" >&2
			exit 1
		fi
	done < <(printf '%s\n' "$paths_json" | jq -r '.[]')
	count=$(sed '/^$/d' "$matches" | wc -l)
	if [ "$count" -eq 0 ]; then
		status=ok
	else
		status=failed
		absence_failure=$((absence_failure + 1))
	fi
	printf '%s\t%s\t%s\n' "$id" "$count" "$status" >> "$absence_results"
done < <(jq -r '.absence_checks[] | [.id, (.paths | @json), (.forbidden_patterns | @json)] | @tsv' "$CONFIG")

if [ "$absence_failure" -ne 0 ]; then
	echo "absence checks failed" >&2
	cat "$absence_results" >&2
	exit 1
fi

init_kconfig="$LINUX_DIR/init/Kconfig"
makefile="$LINUX_DIR/kernel/sched/Makefile"
sched_h="$LINUX_DIR/include/linux/sched.h"
sched_internal_h="$LINUX_DIR/kernel/sched/sched.h"
task_probe="$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh"
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

l_kconfig_sched=$(line_of_first "$init_kconfig" 'config SCHED_EXEC_LEASE')
l_kconfig_default=$(line_after_symbol "$init_kconfig" 'config SCHED_EXEC_LEASE' 'default n')
l_kconfig_deny=$(line_of_first "$init_kconfig" 'config SCHED_EXEC_LEASE_CFS_DENY_TEST')
l_makefile_exec=$(line_of_first "$makefile" 'obj-$(CONFIG_SCHED_EXEC_LEASE) += exec_lease.o')
l_forward_cfs=$(line_of_first "$sched_h" 'struct cfs_rq;')
l_forward_rq=$(line_of_first "$sched_h" 'struct rq;')
l_sched_entity=$(line_of_first "$sched_h" 'struct sched_entity {')
l_task_field=$(line_after_symbol "$sched_h" '#ifdef CONFIG_SCHED_EXEC_LEASE' 'struct sched_exec_task')
l_cfs=$(line_of_first "$sched_internal_h" 'struct cfs_rq {')
l_cfs_timeline=$(line_after_symbol "$sched_internal_h" 'struct cfs_rq {' 'tasks_timeline')
l_cfs_curr=$(line_after_symbol "$sched_internal_h" 'struct cfs_rq {' '*curr')
l_rq=$(line_of_first "$sched_internal_h" 'struct rq {')
l_rq_nr=$(line_after_symbol "$sched_internal_h" 'struct rq {' 'nr_running')
l_rq_curr=$(line_after_symbol "$sched_internal_h" 'struct rq {' '*curr')
l_rq_cfs=$(line_after_symbol "$sched_internal_h" 'struct rq {' 'struct cfs_rq')
l_task_probe_size=$(line_after_symbol "$task_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_task_struct_size_probe')
l_task_probe_offset=$(line_after_symbol "$task_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_field_offset_plus_one_probe')
l_task_probe_field=$(line_after_symbol "$task_probe" 'cat > "$dir/sched_exec_layout_probe.c"' 'sched_exec_field_size_probe')

missing_semantic=0
for v in l_kconfig_sched l_kconfig_default l_kconfig_deny l_makefile_exec \
	l_forward_cfs l_forward_rq l_sched_entity l_task_field l_cfs \
	l_cfs_timeline l_cfs_curr l_rq l_rq_nr l_rq_curr l_rq_cfs \
	l_task_probe_size l_task_probe_offset l_task_probe_field; do
	if [ -z "${!v:-}" ]; then
		echo -e "semantic\tmissing $v" >> "$blockers"
		missing_semantic=$((missing_semantic + 1))
	fi
done

patch_slot_free=false
kconfig_boundary_observed=false
internal_probe_need_observed=false
hot_layout_basis_observed=false
task_probe_basis_observed=false

if ! grep -q '^0013-' "$series"; then
	patch_slot_free=true
fi

if [ "$missing_semantic" -eq 0 ]; then
	if [ "$l_kconfig_sched" -lt "$l_kconfig_default" ] &&
	   [ "$l_kconfig_default" -lt "$l_kconfig_deny" ] &&
	   [ "$l_makefile_exec" -gt 0 ]; then
		kconfig_boundary_observed=true
	fi
	if [ "$l_forward_cfs" -lt "$l_sched_entity" ] &&
	   [ "$l_forward_rq" -lt "$l_sched_entity" ] &&
	   [ "$l_cfs" -gt "$l_sched_entity" ] &&
	   [ "$l_rq" -gt "$l_cfs" ]; then
		internal_probe_need_observed=true
	fi
	if [ "$l_sched_entity" -lt "$l_task_field" ] &&
	   [ "$l_cfs" -lt "$l_cfs_timeline" ] &&
	   [ "$l_cfs_timeline" -lt "$l_cfs_curr" ] &&
	   [ "$l_rq" -lt "$l_rq_nr" ] &&
	   [ "$l_rq_nr" -lt "$l_rq_curr" ] &&
	   [ "$l_rq_curr" -lt "$l_rq_cfs" ]; then
		hot_layout_basis_observed=true
	fi
	if [ "$l_task_probe_size" -lt "$l_task_probe_offset" ] &&
	   [ "$l_task_probe_offset" -lt "$l_task_probe_field" ]; then
		task_probe_basis_observed=true
	fi
fi

semantic_shape_ok=false
if $patch_slot_free &&
   $kconfig_boundary_observed &&
   $internal_probe_need_observed &&
   $hot_layout_basis_observed &&
   $task_probe_basis_observed; then
	semantic_shape_ok=true
fi

cat > "$OUT_DIR/source-shape.json" <<EOF_JSON
{
  "status": "$(if $semantic_shape_ok; then echo passed; else echo failed; fi)",
  "line_drift_count": $line_drift,
  "missing_anchor_count": $missing_anchor,
  "source_anchor_count": $anchor_count,
  "absence_failure_count": $absence_failure,
  "patch_slot_free": $patch_slot_free,
  "kconfig_boundary_observed": $kconfig_boundary_observed,
  "internal_probe_need_observed": $internal_probe_need_observed,
  "hot_layout_basis_observed": $hot_layout_basis_observed,
  "task_probe_basis_observed": $task_probe_basis_observed,
  "anchors": {
    "kconfig_sched_exec_lease": ${l_kconfig_sched:-0},
    "kconfig_sched_exec_lease_default": ${l_kconfig_default:-0},
    "kconfig_deny_test": ${l_kconfig_deny:-0},
    "makefile_exec_lease": ${l_makefile_exec:-0},
    "forward_cfs_rq": ${l_forward_cfs:-0},
    "forward_rq": ${l_forward_rq:-0},
    "sched_entity": ${l_sched_entity:-0},
    "task_sched_exec_field": ${l_task_field:-0},
    "cfs_rq": ${l_cfs:-0},
    "cfs_tasks_timeline": ${l_cfs_timeline:-0},
    "cfs_curr": ${l_cfs_curr:-0},
    "rq": ${l_rq:-0},
    "rq_nr_running": ${l_rq_nr:-0},
    "rq_curr": ${l_rq_curr:-0},
    "rq_cfs": ${l_rq_cfs:-0},
    "task_probe_size": ${l_task_probe_size:-0},
    "task_probe_offset": ${l_task_probe_offset:-0},
    "task_probe_field": ${l_task_probe_field:-0}
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
		-config P5AR2LayoutProbePatchPlanSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5AR2LayoutProbePatchPlanUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2LayoutProbePatchPlanUnsafe*.cfg' | wc -l)
if [ "$unsafe_expected" -ne 31 ] || [ "$cfg_count" -ne 31 ]; then
	echo "unsafe counterexample count mismatch: expected=31 actual=$unsafe_expected cfg_count=$cfg_count" >&2
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
  "absence_failure_count": $absence_failure,
  "patch_slot_free": $patch_slot_free,
  "kconfig_boundary_observed": $kconfig_boundary_observed,
  "internal_probe_need_observed": $internal_probe_need_observed,
  "hot_layout_basis_observed": $hot_layout_basis_observed,
  "task_probe_basis_observed": $task_probe_basis_observed,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
