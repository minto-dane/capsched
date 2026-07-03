#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Upstream-maintenance/style evidence collector for the P5A0.P1 0008
# no-behavior source-contract patch.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_QUEUE_DIR=${DOMAINLEASE_PATCH_QUEUE_DIR:-"$WORKSPACE_DIR/linux-patches"}
CONFIG=${DOMAINLEASE_P5A0_P1_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a0-p1-no-behavior-implementation-v1.json"}
OUT_ROOT=${DOMAINLEASE_P5A0_P1_UPSTREAM_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-p1-0008-upstream-check"}
RUN_ID=${DOMAINLEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
UPSTREAM_REF=${DOMAINLEASE_UPSTREAM_REF:-upstream/master}
WORK_REF=${DOMAINLEASE_WORK_REF:-capsched-linux-l0}
FETCH=${DOMAINLEASE_FETCH_UPSTREAM:-0}
OUT_DIR="$OUT_ROOT/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_cmd awk
require_cmd cmp
require_cmd git
require_cmd jq
require_cmd sha256sum
require_cmd sort
require_cmd wc

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
git -C "$PATCH_QUEUE_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "patch queue Git tree not found: $PATCH_QUEUE_DIR"
[ -f "$CONFIG" ] || die "implementation contract not found: $CONFIG"

mkdir -p "$OUT_DIR"

if [ "$FETCH" = "1" ]; then
	git -C "$LINUX_DIR" fetch upstream master
fi

expected_commit=$(jq -r '.linux.future_commit' "$CONFIG")
expected_parent=$(jq -r '.linux.parent_commit' "$CONFIG")
patch_name=$(jq -r '.linux.patch_name' "$CONFIG")
expected_patch_sha=$(jq -r '.linux.patch_sha256' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
work_commit=$(git -C "$LINUX_DIR" rev-parse "$WORK_REF")
[ "$actual_commit" = "$expected_commit" ] || \
	die "Linux HEAD $actual_commit does not match contract $expected_commit"
[ "$work_commit" = "$expected_commit" ] || \
	die "work ref $WORK_REF is $work_commit not $expected_commit"

patch_file="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/$patch_name"
[ -f "$patch_file" ] || die "missing patch queue file: $patch_file"
actual_patch_sha=$(sha256sum "$patch_file" | awk '{ print $1 }')
[ "$actual_patch_sha" = "$expected_patch_sha" ] || \
	die "patch sha mismatch: $actual_patch_sha != $expected_patch_sha"
grep -qxF "$patch_name" "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series" || \
	die "patch queue series missing $patch_name"

git -C "$LINUX_DIR" diff --name-only "$expected_parent..$expected_commit" \
	| sort -u > "$OUT_DIR/candidate-delta-files.txt"
cat > "$OUT_DIR/expected-candidate-delta-files.txt" <<'EOF'
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
EOF
cmp -s "$OUT_DIR/expected-candidate-delta-files.txt" "$OUT_DIR/candidate-delta-files.txt" || \
	die "candidate delta files changed"

"$LINUX_DIR/scripts/checkpatch.pl" --strict --no-tree "$patch_file" \
	> "$OUT_DIR/checkpatch-strict.txt" 2>&1 || \
	die "strict checkpatch failed; see $OUT_DIR/checkpatch-strict.txt"
grep -q 'total: 0 errors, 0 warnings' "$OUT_DIR/checkpatch-strict.txt" || \
	die "strict checkpatch did not report 0 errors, 0 warnings"

( cd "$LINUX_DIR" && scripts/get_maintainer.pl --no-rolestats "$patch_file" ) \
	> "$OUT_DIR/get-maintainer.txt" 2>&1 || \
	die "get_maintainer failed; see $OUT_DIR/get-maintainer.txt"
maintainer_count=$(wc -l < "$OUT_DIR/get-maintainer.txt")
[ "$maintainer_count" -gt 0 ] || die "get_maintainer returned no rows"

base_commit=$(git -C "$LINUX_DIR" merge-base "$UPSTREAM_REF" "$WORK_REF")
upstream_commit=$(git -C "$LINUX_DIR" rev-parse "$UPSTREAM_REF")
upstream_count=$(git -C "$LINUX_DIR" rev-list --count "$base_commit..$upstream_commit")

set +e
merge_tree_output=$(git -C "$LINUX_DIR" merge-tree --write-tree "$UPSTREAM_REF" "$WORK_REF" 2>&1)
merge_tree_exit=$?
set -e
printf '%s\n' "$merge_tree_output" > "$OUT_DIR/merge-tree.txt"
[ "$merge_tree_exit" -eq 0 ] || die "merge-tree failed; see $OUT_DIR/merge-tree.txt"

cat > "$OUT_DIR/candidate-anchor-paths.txt" <<'EOF'
fs/exec.c
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/exit.c
kernel/fork.c
kernel/sched/core.c
kernel/sched/exec_lease.c
kernel/sched/sched.h
EOF
mapfile -t anchor_paths < "$OUT_DIR/candidate-anchor-paths.txt"
git -C "$LINUX_DIR" diff --name-status "$base_commit..$upstream_commit" \
	-- "${anchor_paths[@]}" > "$OUT_DIR/candidate-anchor-drift.name-status"
anchor_drift_count=$(wc -l < "$OUT_DIR/candidate-anchor-drift.name-status")
[ "$anchor_drift_count" -eq 0 ] || \
	die "candidate anchor drift found; see $OUT_DIR/candidate-anchor-drift.name-status"

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_commit"
	printf 'patch_sha_matches\ttrue\t%s\n' "$actual_patch_sha"
	printf 'candidate_delta_exact_allowlist\ttrue\t%s\n' "$OUT_DIR/candidate-delta-files.txt"
	printf 'strict_checkpatch_clean\ttrue\t%s\n' "$OUT_DIR/checkpatch-strict.txt"
	printf 'get_maintainer_rows\t%s\t%s\n' "$maintainer_count" "$OUT_DIR/get-maintainer.txt"
	printf 'base_commit\t%s\tmerge-base\n' "$base_commit"
	printf 'upstream_commit\t%s\t%s\n' "$upstream_commit" "$UPSTREAM_REF"
	printf 'base_to_upstream_commit_count\t%s\trev-list\n' "$upstream_count"
	printf 'merge_tree_clean\ttrue\t%s\n' "$OUT_DIR/merge-tree.txt"
	printf 'candidate_anchor_drift_count\t%s\t%s\n' "$anchor_drift_count" "$OUT_DIR/candidate-anchor-drift.name-status"
	printf 'runtime_denial\tfalse\tnon-claim\n'
	printf 'runtime_coverage\tfalse\tnon-claim\n'
	printf 'production_protection\tfalse\tnon-claim\n'
} > "$OUT_DIR/p5a0-p1-upstream-proof.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_commit" \
	--arg patch_name "$patch_name" \
	--arg patch_sha "$actual_patch_sha" \
	--arg base_commit "$base_commit" \
	--arg upstream_commit "$upstream_commit" \
	--argjson upstream_count "$upstream_count" \
	--argjson maintainer_count "$maintainer_count" \
	--argjson anchor_drift_count "$anchor_drift_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  patch_name: $patch_name,
	  patch_sha256: $patch_sha,
	  candidate_delta_exact_allowlist: true,
	  strict_checkpatch_clean: true,
	  get_maintainer_rows: $maintainer_count,
	  base_commit: $base_commit,
	  upstream_commit: $upstream_commit,
	  base_to_upstream_commit_count: $upstream_count,
	  merge_tree_clean: true,
	  candidate_anchor_drift_count: $anchor_drift_count,
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0.P1 0008 upstream check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-p1-upstream-proof.tsv"
