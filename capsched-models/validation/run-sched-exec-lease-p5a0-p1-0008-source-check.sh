#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the actual P5A0.P1 0008 source delta.
#
# This checker is stricter than the P5A0.P1 plan gate: it expects a real
# 0008 patch, validates the parent..future delta, and rejects anything beyond
# comment-only contract text in the two allowlisted files.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCHES_DIR=${DOMAINLEASE_LINUX_PATCHES_DIR:-"$WORKSPACE_DIR/linux-patches"}
OUT_ROOT=${DOMAINLEASE_P5A0_P1_0008_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-p1-0008-source-check"}
RUN_ID=${DOMAINLEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

PARENT_EXPECTED="a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8"
ALLOWLIST_1="include/linux/sched_exec_lease.h"
ALLOWLIST_2="kernel/sched/exec_lease.c"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

line_of()
{
	local file=$1
	local pattern=$2

	awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$file"
}

require_line()
{
	local name=$1
	local file=$2
	local pattern=$3
	local line

	line=$(line_of "$file" "$pattern")
	[ -n "$line" ] || die "missing $name: $pattern"
	printf '%s' "$line"
}

extract_function()
{
	local ref=$1
	local file=$2
	local fn=$3

	git -C "$LINUX_DIR" show "$ref:$file" | awk -v fn="$fn" '
		index($0, fn "(") { seen = 1 }
		seen {
			print
			for (i = 1; i <= length($0); i++) {
				ch = substr($0, i, 1)
				if (ch == "{")
					depth++
				else if (ch == "}")
					depth--
			}
			if (depth == 0 && index($0, "}") && seen)
				exit
		}
	'
}

function_hash()
{
	local ref=$1
	local file=$2
	local fn=$3

	extract_function "$ref" "$file" "$fn" | sha256sum | awk '{ print $1 }'
}

require_cmd awk
require_cmd git
require_cmd grep
require_cmd jq
require_cmd sha256sum
require_cmd sort
require_cmd wc

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
git -C "$PATCHES_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "linux-patches Git tree not found: $PATCHES_DIR"

mkdir -p "$OUT_DIR"

future=$(git -C "$LINUX_DIR" rev-parse HEAD)
parent=$(git -C "$LINUX_DIR" rev-parse HEAD^)
[ "$parent" = "$PARENT_EXPECTED" ] || \
	die "unexpected 0008 parent $parent; expected $PARENT_EXPECTED"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty"
fi

base_work=$(sed -n 's/^work_commit=//p' "$PATCHES_DIR/upstream/base.txt")
[ "$base_work" = "$future" ] || \
	die "base.txt work_commit $base_work does not match future $future"

series="$PATCHES_DIR/patches/capsched-linux-l0/series"
[ -f "$series" ] || die "missing series file: $series"
patch_count=$(grep -c '^0008-' "$series")
[ "$patch_count" -eq 1 ] || die "expected exactly one 0008 series entry, got $patch_count"
patch_name=$(grep '^0008-' "$series")
patch_file="$PATCHES_DIR/patches/capsched-linux-l0/$patch_name"
[ -f "$patch_file" ] || die "missing 0008 patch file: $patch_file"

patch_sha=$(sha256sum "$patch_file" | awk '{ print $1 }')
series_sha=$(sha256sum "$series" | awk '{ print $1 }')
printf '%s  %s\n' "$patch_sha" "$patch_file" > "$OUT_DIR/patch-sha256.txt"
printf '%s  %s\n' "$series_sha" "$series" > "$OUT_DIR/series-sha256.txt"

"$LINUX_DIR/scripts/checkpatch.pl" --no-tree "$patch_file" \
	> "$OUT_DIR/checkpatch.txt" 2>&1 || \
	die "checkpatch failed; see $OUT_DIR/checkpatch.txt"

git -C "$LINUX_DIR" diff --name-only "$parent..$future" | sort \
	> "$OUT_DIR/0008-delta-files.txt"
{
	printf '%s\n' "$ALLOWLIST_1"
	printf '%s\n' "$ALLOWLIST_2"
} | sort > "$OUT_DIR/0008-expected-files.txt"
diff -u "$OUT_DIR/0008-expected-files.txt" "$OUT_DIR/0008-delta-files.txt" \
	> "$OUT_DIR/0008-file-diff.txt" || \
	die "0008 changed files are not the exact P5A0.P1 allowlist"

git -C "$LINUX_DIR" diff --check "$parent..$future" \
	> "$OUT_DIR/diff-check.txt" 2>&1 || \
	die "git diff --check failed"

if git -C "$LINUX_DIR" diff "$parent..$future" -- . \
	":!$ALLOWLIST_1" ":!$ALLOWLIST_2" --exit-code \
	> "$OUT_DIR/out-of-allowlist.diff"; then
	:
else
	die "0008 has out-of-allowlist changes"
fi

git -C "$LINUX_DIR" diff --unified=0 "$parent..$future" -- \
	"$ALLOWLIST_1" "$ALLOWLIST_2" > "$OUT_DIR/0008-u0.diff"

awk '
	/^diff --git / { next }
	/^index / { next }
	/^--- / { next }
	/^\+\+\+ / { next }
	/^@@ / { next }
	/^-/{ print "removed line: " $0; bad = 1; next }
	/^\+$/ { next }
	/^\+[[:space:]]*(\/\*|\*|\*\/)/ { next }
	/^\+[[:space:]]*$/ { next }
	/^\+/ { print "non-comment added line: " $0; bad = 1; next }
	END { exit bad }
' "$OUT_DIR/0008-u0.diff" > "$OUT_DIR/comment-only-check.txt" || \
	die "0008 delta is not comment-only"

header="$LINUX_DIR/include/linux/sched_exec_lease.h"
exec_lease_c="$LINUX_DIR/kernel/sched/exec_lease.c"
core="$LINUX_DIR/kernel/sched/core.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"
fair="$LINUX_DIR/kernel/sched/fair.c"

for helper in \
	sched_exec_lease_prepare_wake \
	sched_exec_lease_prepare_new_task \
	sched_exec_lease_note_queued_move \
	sched_exec_lease_observe_tick \
	sched_exec_lease_note_switch \
	sched_exec_lease_validate_run_edge \
	sched_exec_lease_validate_move_edge \
	sched_exec_lease_validate_move_edge_locked
do
	parent_hash=$(function_hash "$parent" "$ALLOWLIST_1" "$helper")
	future_hash=$(function_hash "$future" "$ALLOWLIST_1" "$helper")
	printf '%s\t%s\t%s\n' "$helper" "$parent_hash" "$future_hash" \
		>> "$OUT_DIR/hot-helper-hashes.tsv"
	[ "$parent_hash" = "$future_hash" ] || \
		die "hot helper body changed: $helper"
done

for helper in \
	sched_exec_task_reset \
	sched_exec_task_prepare_fork \
	sched_exec_task_commit_exec \
	sched_exec_task_exit
do
	parent_hash=$(function_hash "$parent" "$ALLOWLIST_2" "$helper")
	future_hash=$(function_hash "$future" "$ALLOWLIST_2" "$helper")
	printf '%s\t%s\t%s\n' "$helper" "$parent_hash" "$future_hash" \
		>> "$OUT_DIR/lifecycle-helper-hashes.tsv"
	[ "$parent_hash" = "$future_hash" ] || \
		die "lifecycle helper body changed: $helper"
done

if git -C "$LINUX_DIR" diff "$parent..$future" -- "$ALLOWLIST_1" | \
	grep -E '^[+-].*struct sched_exec_task|^[+-].*(domain_id|domain_epoch|task_generation|exec_generation|flags);' \
	> "$OUT_DIR/sched-exec-task-layout-diff.txt"; then
	die "struct sched_exec_task layout changed"
fi

for forbidden in RETRY INELIGIBLE QUARANTINE; do
	if grep -RIn --include='*.c' --include='*.h' \
		"return[[:space:]]\\+SCHED_EXEC_VALIDATION_${forbidden};" \
		"$header" "$LINUX_DIR/kernel/sched" > "$OUT_DIR/forbidden-return-$forbidden.txt"; then
		die "found forbidden return: SCHED_EXEC_VALIDATION_${forbidden}"
	fi
done

if grep -RInE "if[[:space:]]*\\(.*sched_exec_lease_validate|switch[[:space:]]*\\(.*sched_exec_lease_validate|\\?.*sched_exec_lease_validate|sched_exec_lease_validate.*\\?" \
	"$LINUX_DIR/kernel/sched" "$header" > "$OUT_DIR/validation-branch-hits.txt"; then
	die "scheduler branches or ternary-depends on validation helper"
fi

validation_callsite_count=$(grep -RIn "sched_exec_lease_validate_.*edge" "$LINUX_DIR/kernel/sched" | wc -l)
[ "$validation_callsite_count" -eq 3 ] || \
	die "unexpected scheduler validation callsite count: $validation_callsite_count"

if grep -RIn "sched_exec_lease" "$fair" > "$OUT_DIR/fair-picker-sched-exec-hits.txt"; then
	die "fair picker contains sched_exec_lease hook"
fi

require_line "run validate discard" "$core" "(void)sched_exec_lease_validate_run_edge(prev, next);" \
	> "$OUT_DIR/run-validate-discard-line.txt"
require_line "common move validate discard" "$core" "(void)sched_exec_lease_validate_move_edge(p, new_cpu);" \
	> "$OUT_DIR/common-move-validate-discard-line.txt"
require_line "locked move validate discard" "$sched_h" "(void)sched_exec_lease_validate_move_edge_locked(task, dst_rq->cpu);" \
	> "$OUT_DIR/locked-move-validate-discard-line.txt"

for token in \
	SYSCALL_DEFINE \
	register_sysctl \
	proc_create \
	debugfs_create \
	TRACE_EVENT \
	EXPORT_SYMBOL \
	EXPORT_SYMBOL_GPL \
	DEFINE_STATIC_KEY \
	static_branch \
	printk \
	pr_warn \
	WARN_ON \
	kmalloc \
	kzalloc \
	vmalloc \
	msleep \
	schedule_timeout \
	refcount_inc \
	refcount_dec \
	mutex_lock \
	spin_lock
do
	if git -C "$LINUX_DIR" diff "$parent..$future" -- "$ALLOWLIST_1" "$ALLOWLIST_2" | \
		grep -E "^[+] .*${token}|^[+]${token}" \
		> "$OUT_DIR/forbidden-added-token-$token.txt"; then
		die "0008 adds forbidden token: $token"
	fi
done

{
	printf 'property\tvalue\tevidence\n'
	printf 'parent_commit\t%s\tgit\n' "$parent"
	printf 'future_commit\t%s\tgit\n' "$future"
	printf 'patch_name\t%s\tseries\n' "$patch_name"
	printf 'patch_sha256\t%s\t%s\n' "$patch_sha" "$patch_file"
	printf 'series_sha256\t%s\t%s\n' "$series_sha" "$series"
	printf 'checkpatch_clean\ttrue\t%s\n' "$OUT_DIR/checkpatch.txt"
	printf 'delta_files_exact_allowlist\ttrue\t%s\n' "$OUT_DIR/0008-delta-files.txt"
	printf 'delta_comment_only\ttrue\t%s\n' "$OUT_DIR/comment-only-check.txt"
	printf 'hot_helper_bodies_unchanged\ttrue\t%s\n' "$OUT_DIR/hot-helper-hashes.tsv"
	printf 'lifecycle_helper_bodies_unchanged\ttrue\t%s\n' "$OUT_DIR/lifecycle-helper-hashes.tsv"
	printf 'sched_exec_task_layout_changed\tfalse\t%s\n' "$OUT_DIR/sched-exec-task-layout-diff.txt"
	printf 'helper_return_set_allow_only\ttrue\tsource_grep\n'
	printf 'scheduler_branch_on_validation_result\tfalse\tsource_grep\n'
	printf 'scheduler_validation_callsite_count\t%s\tsource_grep\n' "$validation_callsite_count"
	printf 'fair_picker_ineligibility\tfalse\t%s\n' "$fair"
	printf 'public_abi_or_monitor\tfalse\tcomment-only-delta\n'
	printf 'runtime_denial\tfalse\tcomment-only-delta\n'
	printf 'runtime_coverage_claim\tfalse\tnon-claim\n'
	printf 'production_or_cost_claim\tfalse\tnon-claim\n'
} > "$OUT_DIR/p5a0-p1-0008-source-check.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg parent "$parent" \
	--arg future "$future" \
	--arg patch_name "$patch_name" \
	--arg patch_sha "$patch_sha" \
	--arg series_sha "$series_sha" \
	--argjson validation_callsite_count "$validation_callsite_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  parent_commit: $parent,
	  future_commit: $future,
	  patch_name: $patch_name,
	  patch_sha256: $patch_sha,
	  series_sha256: $series_sha,
	  checkpatch_clean: true,
	  delta_files_exact_allowlist: true,
	  delta_comment_only: true,
	  hot_helper_bodies_unchanged: true,
	  lifecycle_helper_bodies_unchanged: true,
	  sched_exec_task_layout_changed: false,
	  helper_return_set_allow_only: true,
	  scheduler_branch_on_validation_result: false,
	  scheduler_validation_callsite_count: $validation_callsite_count,
	  fair_picker_ineligibility: false,
	  public_abi_or_monitor: false,
	  runtime_denial: false,
	  runtime_coverage_claim: false,
	  production_or_cost_claim: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0.P1 0008 source check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-p1-0008-source-check.tsv"
