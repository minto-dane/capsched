#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh-v1.json"
PATCH_PLAN_RUNNER="$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.sh"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0112-p5a-r-upstream-drift-source-shape-refresh-model"
MODEL="P5ARUpstreamDriftSourceShapeRefresh.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-upstream-drift-source-shape-refresh/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq java grep sed find wc sort comm; do
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

expected_upstream=$(jq -r '.source_basis.current_upstream_commit' "$CONFIG")
actual_upstream=$(git -C "$LINUX_DIR" rev-parse upstream/master)
if [ "$actual_upstream" != "$expected_upstream" ]; then
	echo "upstream commit mismatch: expected=$expected_upstream actual=$actual_upstream" >&2
	exit 1
fi

previous_upstream=$(jq -r '.source_basis.previous_upstream_commit' "$CONFIG")
if ! git -C "$LINUX_DIR" merge-base --is-ancestor "$previous_upstream" "$actual_upstream"; then
	echo "previous upstream is not ancestor of current upstream" >&2
	exit 1
fi

jq -e '
	.drift_classification.upstream_advanced == true and
	.drift_classification.previous_upstream_is_ancestor == true and
	.drift_classification.merge_tree_clean == true and
	.drift_classification.p5a_r_direct_scheduler_source_shape_changed == false and
	.drift_classification.lifecycle_source_changed == true and
	.drift_classification.nonblocking_for_ordinary_cfs_0009_draft == true and
	.drift_classification.blocks_lifecycle_patch_claims == true and
	.drift_classification.blocks_global_all_angles_claims == true and
	((.p5a_r_direct_source_shape_files | length) == .required_counts.direct_source_shape_file_count) and
	((.changed_between_previous_and_current_upstream | length) == .required_counts.changed_upstream_file_count) and
	((.required_anchor_refresh | length) == .required_counts.required_anchor_refresh_count) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 9) and
	(.formal.unsafe_expected_counterexamples == 9) and
	all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

changed_all="$OUT_DIR/changed-all.txt"
git -C "$LINUX_DIR" diff --name-only "$previous_upstream".."$actual_upstream" -- > "$changed_all"

changed_direct="$OUT_DIR/changed-direct.txt"
>"$changed_direct"
while IFS= read -r path; do
	if grep -qx "$path" "$changed_all"; then
		printf '%s\n' "$path" >> "$changed_direct"
	fi
done < <(jq -r '.p5a_r_direct_source_shape_files[]' "$CONFIG")

direct_changed_count=$(wc -l < "$changed_direct" | tr -d ' ')
if [ "$direct_changed_count" -ne 0 ]; then
	echo "P5A-R direct scheduler source-shape drift detected" >&2
	cat "$changed_direct" >&2
	exit 1
fi

changed_expected="$OUT_DIR/changed-expected.txt"
jq -r '.changed_between_previous_and_current_upstream[]' "$CONFIG" | sort > "$changed_expected"
changed_lifecycle="$OUT_DIR/changed-lifecycle.txt"
git -C "$LINUX_DIR" diff --name-only "$previous_upstream".."$actual_upstream" -- fs/exec.c kernel/fork.c | sort > "$changed_lifecycle"

if ! cmp -s "$changed_expected" "$changed_lifecycle"; then
	echo "changed lifecycle file set mismatch" >&2
	echo "expected:" >&2
	cat "$changed_expected" >&2
	echo "actual:" >&2
	cat "$changed_lifecycle" >&2
	exit 1
fi

merge_tree_out="$OUT_DIR/merge-tree.txt"
if ! git -C "$LINUX_DIR" merge-tree --write-tree HEAD upstream/master > "$merge_tree_out"; then
	echo "merge-tree failed against current upstream" >&2
	cat "$merge_tree_out" >&2
	exit 1
fi

RUN_ID="${RUN_ID}-patch-plan" "$PATCH_PLAN_RUNNER" > "$OUT_DIR/patch-plan-runner.json"
jq empty "$OUT_DIR/patch-plan-runner.json"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5ARUpstreamDriftSourceShapeRefreshSafe.cfg "$MODEL"
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
for cfg in "$MODEL_DIR"/P5ARUpstreamDriftSourceShapeRefreshUnsafe*.cfg; do
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

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5ARUpstreamDriftSourceShapeRefreshUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 9 ] || [ "$cfg_count" -ne 9 ]; then
	echo "unsafe counterexample mismatch: expected=9 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF_JSON
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "linux_commit": "$actual_linux_commit",
  "previous_upstream_commit": "$previous_upstream",
  "current_upstream_commit": "$actual_upstream",
  "direct_source_shape_changed_count": $direct_changed_count,
  "lifecycle_changed_count": $(wc -l < "$changed_lifecycle" | tr -d ' '),
  "merge_tree_clean": true,
  "ordinary_cfs_0009_draft_reviewable": true,
  "lifecycle_freshness_claim": false,
  "global_all_angles_freshness_claim": false,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF_JSON

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
