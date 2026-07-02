#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source/object checker for the P4 allow-only validation skeleton.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCH_QUEUE_DIR=${DOMAINLEASE_PATCH_QUEUE_DIR:-"$WORKSPACE_DIR/linux-patches"}
CONFIG=${DOMAINLEASE_P4_SKELETON_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p4-allow-only-validation-skeleton-implementation-v1.json"}
OUT_ROOT=${DOMAINLEASE_P4_SKELETON_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p4-allow-only-skeleton"}
RUN_ID=${DOMAINLEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
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
require_cmd git
require_cmd jq
require_cmd nm
require_cmd size

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
git -C "$PATCH_QUEUE_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "patch queue Git tree not found: $PATCH_QUEUE_DIR"
[ -f "$CONFIG" ] || die "P4 skeleton contract not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_work_commit=$(jq -r '.linux.work_commit' "$CONFIG")
actual_work_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_work_commit" = "$expected_work_commit" ] || \
	die "Linux HEAD $actual_work_commit does not match contract $expected_work_commit"

patch_name=$(jq -r '.patch_queue.series_entry' "$CONFIG")
patch_file="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/$patch_name"
[ -f "$patch_file" ] || die "missing patch queue file: $patch_file"
grep -qxF "$patch_name" "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series" || \
	die "patch queue series missing $patch_name"
grep -qxF "work_commit=$actual_work_commit" "$PATCH_QUEUE_DIR/upstream/base.txt" || \
	die "patch queue base.txt work_commit does not match Linux HEAD"

"$LINUX_DIR/scripts/checkpatch.pl" --no-tree "$patch_file" > "$OUT_DIR/checkpatch.txt" 2>&1 || \
	die "checkpatch failed; see $OUT_DIR/checkpatch.txt"

header="$LINUX_DIR/include/linux/sched_exec_lease.h"
core="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"

helper_count=0
while IFS= read -r helper; do
	line=$(awk -v fn="$helper" 'index($0, fn "(") { print NR; exit }' "$header")
	[ -n "$line" ] || die "missing helper definition: $helper"
	return_line=$(awk -v start="$line" \
		'NR > start && index($0, "return SCHED_EXEC_VALIDATION_ALLOW;") { print NR; exit }' \
		"$header")
	[ -n "$return_line" ] || die "helper does not return ALLOW: $helper"
	printf '%s\t%s\t%s\n' "$helper" "$line" "$return_line" >> "$OUT_DIR/helper-lines.tsv"
	helper_count=$((helper_count + 1))
done < <(jq -r '.helpers[].name' "$CONFIG")

[ "$helper_count" -eq 3 ] || die "unexpected helper count: $helper_count"

for forbidden in RETRY INELIGIBLE QUARANTINE; do
	if grep -RIn --include='*.c' --include='*.h' \
		"return[[:space:]]\\+SCHED_EXEC_VALIDATION_${forbidden};" \
		"$LINUX_DIR/include/linux/sched_exec_lease.h" "$LINUX_DIR/kernel/sched" \
		> "$OUT_DIR/forbidden-return-$forbidden.txt"; then
		die "found forbidden P4 return: SCHED_EXEC_VALIDATION_${forbidden}"
	fi
done

if grep -RIn "if (.*sched_exec_.*validation\\|switch (.*sched_exec_.*validation\\|if (.*sched_exec_lease_validate\\|switch (.*sched_exec_lease_validate" \
	"$LINUX_DIR/kernel/sched" "$LINUX_DIR/include/linux/sched_exec_lease.h" \
	> "$OUT_DIR/validation-branch-hits.txt"; then
	die "scheduler or helper currently branches on validation result"
fi

grep -nF "(void)sched_exec_lease_validate_run_edge(prev, next);" "$core" > "$OUT_DIR/final-run-callsite.txt" || \
	die "missing final-run validate callsite"
grep -nF "(void)sched_exec_lease_validate_move_edge(p, new_cpu);" "$core" > "$OUT_DIR/move-callsite.txt" || \
	die "missing move validate callsite"
grep -nF "(void)sched_exec_lease_validate_move_edge_locked(task, dst_rq->cpu);" "$sched_h" > "$OUT_DIR/move-locked-callsite.txt" || \
	die "missing locked move validate callsite"

callsite_count=$(grep -RIn "sched_exec_lease_validate_.*edge" "$LINUX_DIR/kernel/sched" | wc -l)
[ "$callsite_count" -eq 3 ] || die "unexpected scheduler callsite count: $callsite_count"

build_tag=$(jq -r '.validation.targeted_build_tag' "$CONFIG")
off_core="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-$build_tag-x86_64/kernel/sched/core.o"
on_core="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-$build_tag-x86_64/kernel/sched/core.o"
on_exec="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-$build_tag-x86_64/kernel/sched/exec_lease.o"

[ -f "$off_core" ] || die "missing targeted build off core.o: $off_core"
[ -f "$on_core" ] || die "missing targeted build on core.o: $on_core"
[ -f "$on_exec" ] || die "missing targeted build on exec_lease.o: $on_exec"

size "$off_core" "$on_core" "$on_exec" > "$OUT_DIR/object-size.txt"
if nm "$off_core" "$on_core" "$on_exec" | \
	grep -E 'sched_exec_lease_validate|sched_exec_allow_all_validation' \
	> "$OUT_DIR/forbidden-symbols.txt"; then
	die "found emitted validation helper symbol"
fi

off_size=$(stat -c '%s' "$off_core")
on_size=$(stat -c '%s' "$on_core")
[ "$off_size" = "$on_size" ] || die "off/on core.o file sizes differ"

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_work_commit"
	printf 'patch_queue_entry_present\ttrue\t%s\n' "$patch_name"
	printf 'checkpatch_clean\ttrue\t%s\n' "$OUT_DIR/checkpatch.txt"
	printf 'helper_count\t%s\t%s\n' "$helper_count" "$OUT_DIR/helper-lines.tsv"
	printf 'callsite_count\t%s\tsource_grep\n' "$callsite_count"
	printf 'non_allow_returns_found\tfalse\tsource_grep\n'
	printf 'scheduler_branches_on_validation_result\tfalse\tsource_grep\n'
	printf 'targeted_build_objects_present\ttrue\t%s\n' "$build_tag"
	printf 'validation_symbols_emitted\tfalse\tnm\n'
	printf 'core_o_file_size_equal\ttrue\t%s/%s\n' "$off_size" "$on_size"
	printf 'runtime_denial\tfalse\tnon-claim\n'
	printf 'runtime_coverage\tfalse\tnon-claim\n'
	printf 'production_protection\tfalse\tnon-claim\n'
} > "$OUT_DIR/p4-skeleton-proof.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_work_commit" \
	--arg patch_name "$patch_name" \
	--arg build_tag "$build_tag" \
	--argjson helper_count "$helper_count" \
	--argjson callsite_count "$callsite_count" \
	--argjson core_o_size "$off_size" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  patch_name: $patch_name,
	  build_tag: $build_tag,
	  helper_count: $helper_count,
	  callsite_count: $callsite_count,
	  helper_return_set_allow_only: true,
	  non_allow_returns_found: false,
	  scheduler_branches_on_validation_result: false,
	  checkpatch_clean: true,
	  patch_queue_entry_present: true,
	  targeted_build_objects_present: true,
	  validation_symbols_emitted: false,
	  core_o_file_size_equal: true,
	  core_o_size: $core_o_size,
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P4 allow-only skeleton check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p4-skeleton-proof.tsv"
