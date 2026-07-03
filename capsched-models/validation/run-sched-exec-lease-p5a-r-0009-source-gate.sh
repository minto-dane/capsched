#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCHES_DIR=${DOMAINLEASE_LINUX_PATCHES_DIR:-"$WORKSPACE_DIR/linux-patches"}
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r-0009-ordinary-cfs-draft-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0113-p5a-r-0009-source-gate-model"
MODEL="P5AR0009SourceGate.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-0009-source-gate/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
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

require_cmd awk
require_cmd git
require_cmd grep
require_cmd jq
require_cmd java
require_cmd sed
require_cmd sha256sum
require_cmd sort
require_cmd wc

[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
git -C "$PATCHES_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "linux-patches Git tree not found: $PATCHES_DIR"

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_parent=$(jq -r '.source_basis.parent_linux_commit' "$CONFIG")
expected_future=$(jq -r '.source_basis.linux_commit' "$CONFIG")
expected_upstream=$(jq -r '.source_basis.upstream_commit' "$CONFIG")
expected_patch_sha=$(jq -r '.source_basis.patch_sha256' "$CONFIG")
expected_series_sha=$(jq -r '.source_basis.series_sha256' "$CONFIG")

future=$(git -C "$LINUX_DIR" rev-parse HEAD)
parent=$(git -C "$LINUX_DIR" rev-parse HEAD^)
upstream=$(git -C "$LINUX_DIR" rev-parse upstream/master)

[ "$future" = "$expected_future" ] || \
	die "linux HEAD mismatch: expected=$expected_future actual=$future"
[ "$parent" = "$expected_parent" ] || \
	die "linux parent mismatch: expected=$expected_parent actual=$parent"
[ "$upstream" = "$expected_upstream" ] || \
	die "upstream mismatch: expected=$expected_upstream actual=$upstream"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty"
fi

jq -e '
	.scope.ordinary_cfs_only == true and
	.scope.linux_patch_drafted == true and
	.scope.linux_patch_accepted == false and
	.scope.behavior_candidate == true and
	.scope.behavior_change_accepted == false and
	.scope.runtime_denial_correctness == false and
	.scope.cfs_deny_and_repick_correctness == false and
	.required_source_shape.ordinary_cfs_fast_path_wrapper == true and
	.required_source_shape.pre_settle_picker_visible_denial_shape == true and
	.required_source_shape.attempt_local_carrier == true and
	.required_source_shape.denied_task_receipt_capacity == 1 and
	.required_source_shape.blocked_group_receipt_capacity == 1 and
	.required_source_shape.retry_limit == 1 and
	.required_source_shape.cross_path_predicate.static_key_has_enable_site == false and
	.required_source_shape.persistent_hot_denial_layout == false and
	.required_source_shape.public_abi == false and
	.required_source_shape.public_trace_abi == false and
	.required_source_shape.exported_symbol == false and
	.required_source_shape.monitor_call == false and
	.required_source_shape.unbounded_scan == false and
	all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

base_work=$(sed -n 's/^work_commit=//p' "$PATCHES_DIR/upstream/base.txt")
[ "$base_work" = "$future" ] || \
	die "base.txt work_commit $base_work does not match future $future"

series="$PATCHES_DIR/patches/capsched-linux-l0/series"
[ -f "$series" ] || die "missing series file: $series"
patch_count=$(grep -c '^0009-' "$series")
[ "$patch_count" -eq 1 ] || die "expected one 0009 series entry, got $patch_count"
patch_name=$(grep '^0009-' "$series")
patch_file="$PATCHES_DIR/patches/capsched-linux-l0/$patch_name"
[ -f "$patch_file" ] || die "missing 0009 patch file: $patch_file"

patch_sha=$(sha256sum "$patch_file" | awk '{ print $1 }')
series_sha=$(sha256sum "$series" | awk '{ print $1 }')
[ "$patch_sha" = "$expected_patch_sha" ] || \
	die "patch sha mismatch: expected=$expected_patch_sha actual=$patch_sha"
[ "$series_sha" = "$expected_series_sha" ] || \
	die "series sha mismatch: expected=$expected_series_sha actual=$series_sha"

head_from_patch=$(sed -n '1s/^From \([0-9a-f]*\) .*/\1/p' "$patch_file")
[ "$head_from_patch" = "$future" ] || \
	die "patch From hash $head_from_patch does not match future $future"

"$LINUX_DIR/scripts/checkpatch.pl" --no-tree "$patch_file" \
	> "$OUT_DIR/checkpatch.txt" 2>&1 || \
	die "checkpatch failed; see $OUT_DIR/checkpatch.txt"

git -C "$LINUX_DIR" diff --name-only "$parent..$future" | sort \
	> "$OUT_DIR/0009-delta-files.txt"
{
	printf 'kernel/sched/core.c\n'
	printf 'kernel/sched/fair.c\n'
	printf 'kernel/sched/sched.h\n'
} | sort > "$OUT_DIR/0009-expected-files.txt"
diff -u "$OUT_DIR/0009-expected-files.txt" "$OUT_DIR/0009-delta-files.txt" \
	> "$OUT_DIR/0009-file-diff.txt" || \
	die "0009 changed files are not the exact allowlist"

git -C "$LINUX_DIR" diff --check "$parent..$future" \
	> "$OUT_DIR/diff-check.txt" 2>&1 || \
	die "git diff --check failed"

core="$LINUX_DIR/kernel/sched/core.c"
fair="$LINUX_DIR/kernel/sched/fair.c"
sched_h="$LINUX_DIR/kernel/sched/sched.h"

ordinary_pick_line=$(require_line "ordinary CFS wrapper call" "$core" \
	"p = pick_task_fair_sched_exec_lease(rq, rf);")
ordinary_settle_line=$(require_line "ordinary CFS settlement" "$core" \
	"put_prev_set_next_task(rq, rq->donor, p);")
[ "$ordinary_pick_line" -lt "$ordinary_settle_line" ] || \
	die "ordinary CFS wrapper is not before settlement"

require_line "wrapper prototype" "$sched_h" \
	"extern struct task_struct *pick_task_fair_sched_exec_lease" \
	> "$OUT_DIR/wrapper-prototype-line.txt"
require_line "normal fair picker preserved" "$fair" \
	"struct task_struct *pick_task_fair(struct rq *rq, struct rq_flags *rf)" \
	> "$OUT_DIR/normal-picker-line.txt"
require_line "ordinary CFS wrapper definition" "$fair" \
	"pick_task_fair_sched_exec_lease(struct rq *rq, struct rq_flags *rf)" \
	> "$OUT_DIR/wrapper-definition-line.txt"
require_line "DL fair server still uses normal picker" "$fair" \
	"return pick_task_fair(dl_se->rq, rf);" \
	> "$OUT_DIR/dl-server-picker-line.txt"
require_line "class-loop fair picker preserved" "$fair" \
	".pick_task		= pick_task_fair," \
	> "$OUT_DIR/class-picker-line.txt"

require_line "dormant static key" "$fair" \
	"static DEFINE_STATIC_KEY_FALSE(sched_exec_cfs_candidate_key);" \
	> "$OUT_DIR/static-key-line.txt"
require_line "static key read" "$fair" \
	"return static_branch_unlikely(&sched_exec_cfs_candidate_key) &&" \
	> "$OUT_DIR/static-key-read-line.txt"
require_line "sched_ext exclusion" "$fair" \
	"!scx_enabled() && !sched_core_enabled(rq) && !sched_proxy_exec();" \
	> "$OUT_DIR/cross-path-predicate-line.txt"

if grep -RInE 'static_branch_(enable|inc|disable).*sched_exec_cfs_candidate_key' \
	"$LINUX_DIR/kernel/sched" "$LINUX_DIR/include/linux" \
	> "$OUT_DIR/static-key-enable-hits.txt"; then
	die "0009 static key has an enable/inc/disable site"
fi

require_line "denied capacity" "$fair" \
	"#define SCHED_EXEC_CFS_DENIED_CAPACITY	1" \
	> "$OUT_DIR/denied-capacity-line.txt"
require_line "retry limit" "$fair" \
	"#define SCHED_EXEC_CFS_RETRY_LIMIT	1" \
	> "$OUT_DIR/retry-limit-line.txt"
require_line "attempt-local state" "$fair" \
	"struct sched_exec_cfs_pick_state" \
	> "$OUT_DIR/pick-state-line.txt"
require_line "blocked group carrier" "$fair" \
	"struct sched_entity		*blocked_group;" \
	> "$OUT_DIR/blocked-group-line.txt"
require_line "denied identity compare" "$fair" \
	"sched_exec_cfs_same_identity(&candidate, &pick->denied[i])" \
	> "$OUT_DIR/identity-compare-line.txt"
require_line "group blocked receipt" "$fair" \
	"sched_exec_cfs_record_blocked_group(struct sched_exec_cfs_pick_state *pick," \
	> "$OUT_DIR/blocked-group-helper-line.txt"

pickable_count=$(grep -c 'sched_exec_cfs_entity_pickable(sched_exec_pick' "$fair")
[ "$pickable_count" -ge 6 ] || \
	die "expected pick_eevdf candidate pickable checks >=6, got $pickable_count"

task_of_line=$(require_line "leaf task materialization" "$fair" "p = task_of(se);")
validate_line=$(require_line "candidate validation" "$fair" \
	"sched_exec_cfs_validate_candidate(sched_exec_pick, p)")
throttle_line=$(require_line "throttle setup" "$fair" "task_throttle_setup_work(p);")
[ "$task_of_line" -lt "$validate_line" ] || \
	die "candidate validation must happen after task_of"
[ "$validate_line" -lt "$throttle_line" ] || \
	die "candidate validation must happen before throttle setup"

git -C "$LINUX_DIR" diff --unified=0 "$parent..$future" -- \
	kernel/sched/core.c kernel/sched/fair.c kernel/sched/sched.h \
	> "$OUT_DIR/0009-u0.diff"

for token in \
	SYSCALL_DEFINE \
	register_sysctl \
	proc_create \
	debugfs_create \
	TRACE_EVENT \
	EXPORT_SYMBOL \
	EXPORT_SYMBOL_GPL \
	static_branch_enable \
	static_branch_inc \
	static_branch_disable \
	kmalloc \
	kzalloc \
	vmalloc \
	msleep \
	schedule_timeout \
	mutex_lock \
	spin_lock \
	monitor_call \
	hypertag
do
	if grep -E "^[+] .*${token}|^[+]${token}" "$OUT_DIR/0009-u0.diff" \
		> "$OUT_DIR/forbidden-added-token-$token.txt"; then
		die "0009 adds forbidden token: $token"
	fi
done

for token in for_each list_for_each rb_next rb_prev "while[[:space:]]*\\("; do
	if grep -E "^[+] .*${token}|^[+]${token}" "$OUT_DIR/0009-u0.diff" \
		> "$OUT_DIR/forbidden-added-scan-$token.txt"; then
		die "0009 adds forbidden unbounded scan token: $token"
	fi
done

build_blocked_missing_gelf=false
if [ ! -f /usr/include/gelf.h ]; then
	build_blocked_missing_gelf=true
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR0009SourceGateSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1

if ! grep -q 'Model checking completed. No error has been found.' \
	"$OUT_DIR/tlc-safe.log"; then
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	die "safe TLC model did not pass"
fi

state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{ print $1 }')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{ print $2 }')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -1)

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5AR0009SourceGateUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/tlc-$name-states" \
			-config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe config unexpectedly passed: %s\n' "$(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe config failed unexpectedly: %s\n' "$(basename "$cfg")" >&2
		tail -80 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR0009SourceGateUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 10 ] || \
   [ "$cfg_count" -ne 10 ]; then
	die "unsafe counterexample mismatch: expected=10 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail"
fi

cat > "$OUT_DIR/source-gate.tsv" <<EOF_TSV
property	value	evidence
linux_commit	$future	git
parent_commit	$parent	git
upstream_commit	$upstream	git
patch_name	$patch_name	series
patch_sha256	$patch_sha	$patch_file
series_sha256	$series_sha	$series
checkpatch_clean	true	$OUT_DIR/checkpatch.txt
diff_check_clean	true	$OUT_DIR/diff-check.txt
delta_files_exact_allowlist	true	$OUT_DIR/0009-delta-files.txt
ordinary_cfs_wrapper_before_settlement	true	$core
static_key_dormant	true	$OUT_DIR/static-key-enable-hits.txt
cross_path_predicate_present	true	$OUT_DIR/cross-path-predicate-line.txt
attempt_local_carrier_present	true	$OUT_DIR/pick-state-line.txt
pick_eevdf_pickable_checks	$pickable_count	$fair
no_forbidden_added_tokens	true	$OUT_DIR/0009-u0.diff
runtime_denial_correctness	false	non_claim
cfs_deny_and_repick_correctness	false	non_claim
production_or_cost_claim	false	non_claim
targeted_build_blocked_missing_gelf	$build_blocked_missing_gelf	/usr/include/gelf.h
EOF_TSV

jq -n \
	--arg run_id "$RUN_ID" \
	--arg out_dir "$OUT_DIR" \
	--arg linux_commit "$future" \
	--arg parent_commit "$parent" \
	--arg upstream_commit "$upstream" \
	--arg patch_name "$patch_name" \
	--arg patch_sha "$patch_sha" \
	--arg series_sha "$series_sha" \
	--argjson pickable_count "$pickable_count" \
	--argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" \
	--argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" \
	--argjson build_blocked_missing_gelf "$build_blocked_missing_gelf" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  out_dir: $out_dir,
	  status: "passed",
	  linux_commit: $linux_commit,
	  parent_commit: $parent_commit,
	  upstream_commit: $upstream_commit,
	  patch_name: $patch_name,
	  patch_sha256: $patch_sha,
	  series_sha256: $series_sha,
	  checkpatch_clean: true,
	  diff_check_clean: true,
	  delta_files_exact_allowlist: true,
	  ordinary_cfs_wrapper_before_settlement: true,
	  static_key_dormant: true,
	  cross_path_predicate_present: true,
	  attempt_local_carrier_present: true,
	  pick_eevdf_pickable_checks: $pickable_count,
	  no_forbidden_added_tokens: true,
	  safe_tlc_passed: true,
	  safe_states_generated: $safe_states,
	  safe_distinct_states: $safe_distinct,
	  safe_depth: $safe_depth,
	  unsafe_expected_counterexamples: $unsafe_expected,
	  linux_0009_accepted: false,
	  runtime_denial_correctness: false,
	  cfs_deny_and_repick_correctness: false,
	  production_protection: false,
	  cost_efficiency_claim: false,
	  targeted_build_blocked_missing_gelf: $build_blocked_missing_gelf
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
