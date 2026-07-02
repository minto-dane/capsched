#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only Linux upstream drift and model-freshness gate.
#
# This runner:
# - does not modify Linux source
# - does not build kernels
# - does not attach probes, write tracefs, or load BPF
# - does not approve Linux patches, ABI, runtime coverage, monitor
#   verification, behavior change, or protection claims

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-${CAPSCHED_LINUX_DIR:-"$WORKSPACE_DIR/linux"}}
CONFIG=${DOMAINLEASE_DRIFT_CONFIG:-${CAPSCHED_DRIFT_CONFIG:-"$REPO_DIR/capsched-models/analysis/linux-source-drift-model-freshness-gate-v1.json"}}
OUT_ROOT=${DOMAINLEASE_DRIFT_OUT_ROOT:-${CAPSCHED_DRIFT_OUT_ROOT:-"$WORKSPACE_DIR/build/source-drift/linux-source-drift-gate"}}
RUN_ID=${DOMAINLEASE_RUN_ID:-${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}}
OUT_DIR="$OUT_ROOT/$RUN_ID"

UPSTREAM_REF=${DOMAINLEASE_DRIFT_UPSTREAM_REF:-${CAPSCHED_DRIFT_UPSTREAM_REF:-upstream/master}}
WORK_REF=${DOMAINLEASE_DRIFT_WORK_REF:-${CAPSCHED_DRIFT_WORK_REF:-capsched-linux-l0}}
BASE_REF=${DOMAINLEASE_DRIFT_BASE_REF:-${CAPSCHED_DRIFT_BASE_REF:-}}
FETCH=${DOMAINLEASE_DRIFT_FETCH:-${CAPSCHED_DRIFT_FETCH:-0}}
CONCRETE_CONSUMER_NEED=${DOMAINLEASE_CONCRETE_CONSUMER_NEED:-${CAPSCHED_CONCRETE_CONSUMER_NEED:-0}}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_cmd git
require_cmd jq

[ -d "$LINUX_DIR/.git" ] || die "Linux Git tree not found: $LINUX_DIR"
[ -f "$CONFIG" ] || die "drift config not found: $CONFIG"

mkdir -p "$OUT_DIR"

if [ "$FETCH" = "1" ]; then
	git -C "$LINUX_DIR" fetch upstream master
fi

if [ -z "$BASE_REF" ]; then
	BASE_REF=$(git -C "$LINUX_DIR" merge-base "$UPSTREAM_REF" "$WORK_REF")
fi

BASE_COMMIT=$(git -C "$LINUX_DIR" rev-parse "$BASE_REF")
UPSTREAM_COMMIT=$(git -C "$LINUX_DIR" rev-parse "$UPSTREAM_REF")
WORK_COMMIT=$(git -C "$LINUX_DIR" rev-parse "$WORK_REF")
UPSTREAM_COUNT=$(git -C "$LINUX_DIR" rev-list --count "$BASE_COMMIT..$UPSTREAM_COMMIT")

jq -r '.watch_groups[].paths[]' "$CONFIG" | sort -u > "$OUT_DIR/watched-paths.txt"
mapfile -t WATCH_PATHS < "$OUT_DIR/watched-paths.txt"

jq -r '.watch_groups[] | select(.group_id == "l0_footprint") | .paths[]' "$CONFIG" \
	> "$OUT_DIR/patch-footprint-paths.txt"
mapfile -t PATCH_FOOTPRINT_PATHS < "$OUT_DIR/patch-footprint-paths.txt"
[ "${#PATCH_FOOTPRINT_PATHS[@]}" -gt 0 ] || die "l0_footprint has no paths"

git -C "$LINUX_DIR" diff --name-status "$BASE_COMMIT..$WORK_COMMIT" \
	-- "${PATCH_FOOTPRINT_PATHS[@]}" > "$OUT_DIR/patch-footprint.name-status"

git -C "$LINUX_DIR" diff --name-status "$BASE_COMMIT..$UPSTREAM_COMMIT" \
	-- "${WATCH_PATHS[@]}" > "$OUT_DIR/watched-drift.name-status"

git -C "$LINUX_DIR" diff --stat --compact-summary "$BASE_COMMIT..$UPSTREAM_COMMIT" \
	-- "${WATCH_PATHS[@]}" > "$OUT_DIR/watched-drift.stat"

set +e
MERGE_TREE_OUTPUT=$(git -C "$LINUX_DIR" merge-tree --write-tree "$UPSTREAM_REF" "$WORK_REF" 2>&1)
MERGE_TREE_EXIT=$?
set -e
printf '%s\n' "$MERGE_TREE_OUTPUT" > "$OUT_DIR/merge-tree.txt"

{
	printf 'timestamp_utc=%s\n' "$RUN_ID"
	printf 'workspace=%s\n' "$WORKSPACE_DIR"
	printf 'linux_dir=%s\n' "$LINUX_DIR"
	printf 'config=%s\n' "$CONFIG"
	printf 'base_commit=%s\n' "$BASE_COMMIT"
	printf 'upstream_ref=%s\n' "$UPSTREAM_REF"
	printf 'upstream_commit=%s\n' "$UPSTREAM_COMMIT"
	printf 'work_ref=%s\n' "$WORK_REF"
	printf 'work_commit=%s\n' "$WORK_COMMIT"
	printf 'base_to_upstream_commit_count=%s\n' "$UPSTREAM_COUNT"
	printf 'merge_tree_exit=%s\n' "$MERGE_TREE_EXIT"
	printf 'concrete_consumer_need=%s\n' "$CONCRETE_CONSUMER_NEED"
} > "$OUT_DIR/metadata.txt"

printf 'group_id\tchanged_count\tstale_if_changed\tmodel_refresh_required\tdrift_class\tchanged_paths\taffected_artifacts_count\tblocked_until_refresh_count\n' > "$OUT_DIR/group-results.tsv"

jq -r '.watch_groups[] | @base64' "$CONFIG" | while read -r group_b64; do
	group_json=$(printf '%s' "$group_b64" | base64 -d)
	group_id=$(printf '%s' "$group_json" | jq -r '.group_id')
	stale_if_changed=$(printf '%s' "$group_json" | jq -r '.stale_if_changed')
	drift_class=$(printf '%s' "$group_json" | jq -r '.drift_class_if_changed')
	affected_count=$(printf '%s' "$group_json" | jq -r '.affected_artifacts | length')
	blocked_count=$(printf '%s' "$group_json" | jq -r '.blocked_until_refresh | length')
	mapfile -t group_paths < <(printf '%s' "$group_json" | jq -r '.paths[]')
	mapfile -t changed < <(git -C "$LINUX_DIR" diff --name-only "$BASE_COMMIT..$UPSTREAM_COMMIT" -- "${group_paths[@]}")
	changed_count=${#changed[@]}
	if [ "$changed_count" -eq 0 ]; then
		effective_class=D0_no_relevant_drift
		model_refresh_required=false
		changed_paths=none
	else
		effective_class=$drift_class
		if [ "$stale_if_changed" = "true" ]; then
			model_refresh_required=true
		else
			model_refresh_required=false
		fi
		changed_paths=$(printf '%s\n' "${changed[@]}" | paste -sd ';' -)
	fi
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$group_id" "$changed_count" "$stale_if_changed" "$model_refresh_required" \
		"$effective_class" "$changed_paths" "$affected_count" "$blocked_count" \
		>> "$OUT_DIR/group-results.tsv"
done

jq -R -s '
  split("\n")[:-1] as $lines |
  ($lines[0] | split("\t")) as $headers |
  [
    $lines[1:][] |
    split("\t") as $values |
    reduce range(0; $headers | length) as $i
      ({}; .[$headers[$i]] = $values[$i])
  ]
' "$OUT_DIR/group-results.tsv" > "$OUT_DIR/group-results.json"

WATCHED_CHANGED_COUNT=$(awk 'NR > 1 { sum += $2 } END { print sum + 0 }' "$OUT_DIR/group-results.tsv")
MODEL_REFRESH_REQUIRED_COUNT=$(awk 'NR > 1 && $4 == "true" { sum += 1 } END { print sum + 0 }' "$OUT_DIR/group-results.tsv")
DIRECT_FOOTPRINT_DRIFT=$(awk 'NR > 1 && $1 == "l0_footprint" && $2 > 0 { found=1 } END { print found ? "true" : "false" }' "$OUT_DIR/group-results.tsv")
FUTURE_ATTACHMENT_DRIFT=$(awk 'NR > 1 && $5 ~ /^D3_/ && $2 > 0 { found=1 } END { print found ? "true" : "false" }' "$OUT_DIR/group-results.tsv")
SEMANTIC_DRIFT=$(awk 'NR > 1 && $5 ~ /^D4_/ && $2 > 0 { found=1 } END { print found ? "true" : "false" }' "$OUT_DIR/group-results.tsv")

if [ "$MERGE_TREE_EXIT" -eq 0 ]; then
	MERGE_TREE_CLEAN=true
else
	MERGE_TREE_CLEAN=false
fi

if [ "$MODEL_REFRESH_REQUIRED_COUNT" -eq 0 ]; then
	MODEL_FRESHNESS=fresh
else
	MODEL_FRESHNESS=stale
fi

if [ "$MODEL_FRESHNESS" = "fresh" ] && [ "$MERGE_TREE_CLEAN" = "true" ] && [ "$CONCRETE_CONSUMER_NEED" = "1" ]; then
	CANDIDATE_NO_BEHAVIOR_PATCH_REVIEWABLE=true
else
	CANDIDATE_NO_BEHAVIOR_PATCH_REVIEWABLE=false
fi

{
	printf 'base_commit=%s\n' "$BASE_COMMIT"
	printf 'upstream_commit=%s\n' "$UPSTREAM_COMMIT"
	printf 'work_commit=%s\n' "$WORK_COMMIT"
	printf 'base_to_upstream_commit_count=%s\n' "$UPSTREAM_COUNT"
	printf 'watched_changed_count=%s\n' "$WATCHED_CHANGED_COUNT"
	printf 'model_refresh_required_count=%s\n' "$MODEL_REFRESH_REQUIRED_COUNT"
	printf 'direct_footprint_drift=%s\n' "$DIRECT_FOOTPRINT_DRIFT"
	printf 'future_attachment_drift=%s\n' "$FUTURE_ATTACHMENT_DRIFT"
	printf 'semantic_drift_requires_refresh=%s\n' "$SEMANTIC_DRIFT"
	printf 'merge_tree_exit=%s\n' "$MERGE_TREE_EXIT"
	printf 'merge_tree_clean=%s\n' "$MERGE_TREE_CLEAN"
	printf 'model_freshness=%s\n' "$MODEL_FRESHNESS"
	printf 'concrete_consumer_need=%s\n' "$CONCRETE_CONSUMER_NEED"
	printf 'candidate_no_behavior_patch_reviewable=%s\n' "$CANDIDATE_NO_BEHAVIOR_PATCH_REVIEWABLE"
	printf 'linux_patch_approved=false\n'
	printf 'behavior_change=false\n'
	printf 'runtime_coverage=false\n'
	printf 'abi=false\n'
	printf 'public_tracepoint_abi=false\n'
	printf 'monitor_verified=false\n'
	printf 'production_protection=false\n'
} > "$OUT_DIR/summary.env"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg base_commit "$BASE_COMMIT" \
	--arg upstream_commit "$UPSTREAM_COMMIT" \
	--arg work_commit "$WORK_COMMIT" \
	--argjson upstream_count "$UPSTREAM_COUNT" \
	--argjson watched_changed_count "$WATCHED_CHANGED_COUNT" \
	--argjson model_refresh_required_count "$MODEL_REFRESH_REQUIRED_COUNT" \
	--arg direct_footprint_drift "$DIRECT_FOOTPRINT_DRIFT" \
	--arg future_attachment_drift "$FUTURE_ATTACHMENT_DRIFT" \
	--arg semantic_drift_requires_refresh "$SEMANTIC_DRIFT" \
	--argjson merge_tree_exit "$MERGE_TREE_EXIT" \
	--arg merge_tree_clean "$MERGE_TREE_CLEAN" \
	--arg model_freshness "$MODEL_FRESHNESS" \
	--arg concrete_consumer_need "$CONCRETE_CONSUMER_NEED" \
	--arg candidate_no_behavior_patch_reviewable "$CANDIDATE_NO_BEHAVIOR_PATCH_REVIEWABLE" \
	--slurpfile groups "$OUT_DIR/group-results.json" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  base_commit: $base_commit,
	  upstream_commit: $upstream_commit,
	  work_commit: $work_commit,
	  base_to_upstream_commit_count: $upstream_count,
	  watched_changed_count: $watched_changed_count,
	  model_refresh_required_count: $model_refresh_required_count,
	  direct_footprint_drift: ($direct_footprint_drift == "true"),
	  future_attachment_drift: ($future_attachment_drift == "true"),
	  semantic_drift_requires_refresh: ($semantic_drift_requires_refresh == "true"),
	  merge_tree_exit: $merge_tree_exit,
	  merge_tree_clean: ($merge_tree_clean == "true"),
	  model_freshness: $model_freshness,
	  concrete_consumer_need: ($concrete_consumer_need == "1"),
	  candidate_no_behavior_patch_reviewable: ($candidate_no_behavior_patch_reviewable == "true"),
	  linux_patch_approved: false,
	  behavior_change: false,
	  runtime_coverage: false,
	  abi: false,
	  public_tracepoint_abi: false,
	  monitor_verified: false,
	  production_protection: false,
	  groups: $groups[0]
	}' > "$OUT_DIR/result.json"

printf '[capsched] Linux source-drift gate completed\n'
printf '[capsched] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/summary.env"
