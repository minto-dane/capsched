#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r3-e2-private-layout-candidate-v1.json"
E1_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e1-source-locking-lifetime-evidence-plan/20260715T-p5a-r3-e1-plan-r2/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e2-source-gate/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in awk diff git grep jq sed sha256sum sort wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"
jq -e '
  .status == "passed_r3_e1_plan_only" and
  .r3_e2_disposable_worktree_may_be_created == true and
  .r3_e2_exact_two_file_layout_draft_may_be_created == true and
  .primary_linux_change_approved == false and
  .patch_queue_change_approved == false
' "$E1_RESULT" >/dev/null

jq -e '
  .status == "disposable_source_committed_awaiting_dual_arch_e2" and
  .source.allowed_files == ["init/Kconfig", "kernel/sched/exec_lease.c"] and
  .source.insertions == 209 and
  .source.deletions == 0 and
  .source.strict_checkpatch_errors == 0 and
  .source.strict_checkpatch_warnings == 0 and
  .source.strict_checkpatch_checks == 0 and
  .candidate_config.name == "SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE" and
  .candidate_config.default_enabled == false and
  .candidate_config.direct_dependencies == ["SCHED_EXEC_LEASE_LAYOUT_PROBE", "SMP", "FAIR_GROUP_SCHED"] and
  .candidate_config.transitive_dependencies == ["SCHED_EXEC_LEASE", "DEBUG_KERNEL"] and
  .candidate_config.selected_normally == false and
  .private_layout.b_max_per_rq == 64 and
  .private_layout.bucket_key_u64_words == 8 and
  .private_layout.projection_embeds_inner_cfs_rq == true and
  .private_layout.projection_embeds_one_outer_sched_entity == true and
  .private_layout.private_rq_state_embeds_outer_cfs_rq == true and
  .private_layout.active_rq_index_is_cpumask_var == true and
  .private_layout.projection_map_is_sparse_xarray == true and
  .private_layout.dense_nr_cpu_ids_storage == false and
  .probe.existing_expanded_symbols == 51 and
  .probe.added_private_symbols == 43 and
  (.probe.expected_added_symbol_names | length) == 43 and
  .architecture_matrix.architectures == ["arm64", "x86_64"] and
  .ordinary_layout_delta_required == {sched_entity:0, cfs_rq:0, rq:0, task_struct:0} and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff_sha=$(jq -r '.source.diff_sha256' "$CONFIG")
expected_primary_tree=$(jq -r '.primary_boundary.linux_tree' "$CONFIG")

primary_commit=$(git -C "$PRIMARY_DIR" rev-parse HEAD)
primary_tree=$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')
candidate_commit=$(git -C "$CANDIDATE_DIR" rev-parse HEAD)
candidate_parent=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)
candidate_tree=$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')
[ "$primary_commit" = "$expected_parent" ] || die "primary Linux moved: $primary_commit"
[ "$primary_tree" = "$expected_primary_tree" ] || die "primary tree moved: $primary_tree"
[ "$candidate_commit" = "$expected_candidate" ] || die "candidate moved: $candidate_commit"
[ "$candidate_parent" = "$expected_parent" ] || die "candidate is not direct child: $candidate_parent"
[ "$candidate_tree" = "$expected_tree" ] || die "candidate tree moved: $candidate_tree"
verify_source_file()
{
	local tree=$1 path=$2 expected_blob working_blob
	expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
	working_blob=$(git -C "$tree" hash-object "$path")
	[ "$working_blob" = "$expected_blob" ] || die "build-relevant source differs from HEAD: $tree/$path"
}
for tree in "$PRIMARY_DIR" "$CANDIDATE_DIR"; do
	for path in \
		init/Kconfig \
		include/linux/sched.h \
		include/linux/sched_exec_lease.h \
		include/linux/cpumask.h \
		include/linux/refcount.h \
		include/linux/stddef.h \
		include/linux/workqueue.h \
		include/linux/xarray.h \
		kernel/sched/Makefile \
		kernel/sched/sched.h \
		kernel/sched/core.c \
		kernel/sched/fair.c \
		kernel/sched/exec_lease.c \
		kernel/sched/exec_lease_layout_probe.c; do
		verify_source_file "$tree" "$path"
	done
done

series_tail=$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")
[ "$series_tail" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die "patch queue moved: $series_tail"

git -C "$CANDIDATE_DIR" diff --name-only "$expected_parent..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" > "$OUT_DIR/delta-files.diff" || die 'candidate escaped exact two-file boundary'
git -C "$CANDIDATE_DIR" diff --check "$expected_parent..$expected_candidate" > "$OUT_DIR/diff-check.txt"
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" > "$OUT_DIR/candidate.diff"
diff_sha=$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')
[ "$diff_sha" = "$expected_diff_sha" ] || die "candidate diff hash mismatch: $diff_sha"
"$CANDIDATE_DIR/scripts/checkpatch.pl" --strict --no-tree "$OUT_DIR/candidate.diff" > "$OUT_DIR/checkpatch.txt"
grep -q 'total: 0 errors, 0 warnings, 0 checks' "$OUT_DIR/checkpatch.txt" || die 'strict checkpatch is not 0/0/0'

kconfig="$CANDIDATE_DIR/init/Kconfig"
source="$CANDIDATE_DIR/kernel/sched/exec_lease.c"
sed -n '/^config SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE$/,/^config /p' "$kconfig" > "$OUT_DIR/candidate-kconfig.txt"
grep -q '^[[:space:]]*depends on SCHED_EXEC_LEASE_LAYOUT_PROBE && SMP && FAIR_GROUP_SCHED$' "$OUT_DIR/candidate-kconfig.txt" || die 'Kconfig dependency mismatch'
grep -q '^[[:space:]]*default n$' "$OUT_DIR/candidate-kconfig.txt" || die 'candidate is not default off'

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpattern\n' > "$anchors"
check_anchor()
{
	local id=$1 pattern=$2
	if grep -Fq "$pattern" "$source"; then
		printf '%s\tok\t%s\n' "$id" "$pattern" >> "$anchors"
	else
		printf '%s\tmissing\t%s\n' "$id" "$pattern" >> "$anchors"
	fi
}
check_anchor conditional '#ifdef CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE'
check_anchor b_max $'#define SCHED_EXEC_BUCKET_B_MAX\t64'
check_anchor key 'struct sched_exec_bucket_key {'
check_anchor bucket 'struct sched_exec_bucket {'
check_anchor projection 'struct sched_exec_bucket_rq_projection {'
check_anchor rq_state 'struct sched_exec_bucket_rq_state {'
check_anchor inner_cfs $'struct cfs_rq\t\t\tinner_cfs_rq;'
check_anchor outer_entity $'struct sched_entity\t\touter_entity;'
check_anchor outer_cfs $'struct cfs_rq\t\t\touter_cfs_rq;'
check_anchor active_cpumask $'cpumask_var_t\t\t\tactive_rqs;'
check_anchor sparse_xarray $'struct xarray\t\t\tprojections;'
check_anchor membership_lock $'raw_spinlock_t\t\t\tmembership_lock;'
check_anchor work $'struct work_struct\t\twork;'
anchor_count=$(awk 'NR > 1 {count++} END {print count+0}' "$anchors")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {count++} END {print count+0}' "$anchors")
[ "$anchor_count" = 13 ] || die "source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

if grep -En '^\+.*(EXPORT_SYMBOL|DEFINE_STATIC_KEY|TRACE_EVENT|SYSCALL_DEFINE|debugfs_|proc_create|sysfs_)' "$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-surfaces.txt"; then
	die 'candidate adds export, key, trace, syscall, or userspace surface'
fi
if grep -En '^\+.*(queue_work|cancel_work_sync|call_rcu|kmalloc|kzalloc|kcalloc|alloc_percpu|xa_store)[[:space:]]*\(' "$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-runtime-calls.txt"; then
	die 'candidate adds a runtime callsite'
fi
: > "$OUT_DIR/forbidden-surfaces.txt"
: > "$OUT_DIR/forbidden-runtime-calls.txt"

for path in include/linux/sched.h include/linux/sched_exec_lease.h kernel/sched/sched.h kernel/sched/fair.c kernel/sched/core.c kernel/sched/Makefile kernel/sched/exec_lease_layout_probe.c; do
	if ! git -C "$CANDIDATE_DIR" diff --quiet "$expected_parent..$expected_candidate" -- "$path"; then
		die "forbidden source changed: $path"
	fi
done

jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort > "$OUT_DIR/expected-private-symbols.txt"
expected_symbol_count=$(wc -l < "$OUT_DIR/expected-private-symbols.txt" | tr -d ' ')
unique_symbol_count=$(sort -u "$OUT_DIR/expected-private-symbols.txt" | wc -l | tr -d ' ')
[ "$expected_symbol_count" = 43 ] && [ "$unique_symbol_count" = 43 ] || die 'private symbol manifest is not 43 unique names'

e1_sha=$(sha256sum "$E1_RESULT" | awk '{print $1}')
jq -n \
	--arg run_id "$RUN_ID" --arg primary_commit "$primary_commit" --arg primary_tree "$primary_tree" \
	--arg candidate_commit "$candidate_commit" --arg candidate_parent "$candidate_parent" --arg candidate_tree "$candidate_tree" \
	--arg diff_sha "$diff_sha" --arg series_tail "$series_tail" --arg e1_result "$E1_RESULT" --arg e1_sha "$e1_sha" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" --argjson expected_symbol_count "$expected_symbol_count" \
	'{schema_version:1,run_id:$run_id,status:"passed",primary_linux_commit:$primary_commit,primary_linux_tree:$primary_tree,candidate_commit:$candidate_commit,candidate_parent:$candidate_parent,candidate_tree:$candidate_tree,candidate_diff_sha256:$diff_sha,exact_two_file_boundary:true,strict_checkpatch_errors:0,strict_checkpatch_warnings:0,strict_checkpatch_checks:0,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,forbidden_runtime_calls:0,forbidden_surfaces:0,expected_private_symbol_count:$expected_symbol_count,existing_expanded_probe_values_required:51,primary_patch_queue_tail:$series_tail,e1_result:$e1_result,e1_result_sha256:$e1_sha,dual_arch_layout_build_may_start:true,source_accepted_for_runtime:false,e3_source_may_start:false,primary_linux_may_change:false,patch_queue_may_change:false,runtime_behavior_approved:false,production_protection:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
