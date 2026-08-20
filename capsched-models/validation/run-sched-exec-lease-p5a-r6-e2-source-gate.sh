#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e2-domain-forest-layout-candidate-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
TEST_MODE=${TEST_MODE:-0}
CONTRACT_ONLY=${CONTRACT_ONLY:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

if [ "$TEST_MODE" = 1 ]; then
	[ "$CONTRACT_ONLY" = 1 ] ||
		die 'TEST_MODE requires CONTRACT_ONLY=1'
	[ -n "$CONFIG_OVERRIDE" ] ||
		die 'TEST_MODE requires CONFIG_OVERRIDE'
	CONFIG=$CONFIG_OVERRIDE
else
	[ "$CONTRACT_ONLY" = 0 ] ||
		die 'CONTRACT_ONLY is restricted to TEST_MODE'
	[ -z "$CONFIG_OVERRIDE" ] ||
		die 'CONFIG_OVERRIDE is restricted to TEST_MODE'
	CONFIG=$CANONICAL_CONFIG
fi

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
for command in awk chmod diff git grep jq mkdir sed sha256sum sort tail wc; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ -f "$CONFIG" ] || die "missing config: $CONFIG"

jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "disposable_source_committed_awaiting_dual_arch_r6_e2" and
  .e1_input.result_sha256 ==
    "364c1c21b0bcb33ccda1e7dd95eb99542cf3dd4f40fcc754aee9c93b89211f62" and
  .source.parent_commit ==
    "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source.parent_tree ==
    "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source.candidate_commit ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .source.candidate_tree ==
    "603762b7a36d7b57e2456b90538c3ba77a1aba16" and
  .source.candidate_diff_sha256 ==
    "1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed" and
  .source.signed_off == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source.insertions == 208 and .source.deletions == 0 and
  .source.strict_checkpatch_errors == 0 and
  .source.strict_checkpatch_warnings == 0 and
  .source.strict_checkpatch_checks == 0 and
  .candidate_config.name == "SCHED_EXEC_LEASE_R6_LAYOUT_PROBE" and
  .candidate_config.default_enabled == false and
  .candidate_config.direct_dependencies == [
    "SCHED_EXEC_LEASE","SCHED_EXEC_LEASE_LAYOUT_PROBE","DEBUG_KERNEL",
    "SMP","CGROUP_SCHED","FAIR_GROUP_SCHED","!SCHED_AUTOGROUP"
  ] and
  .candidate_config.build_only == true and
  .candidate_config.selected_normally == false and
  .private_layout.b_max == 64 and
  .private_layout.top_node_count == 127 and
  .private_layout.slot_state_max_bytes == 1024 and
  .private_layout.top_node_max_bytes == 64 and
  .private_layout.rq_control_max_bytes == 1024 and
  .private_layout.computed_private_bytes_per_rq == 74688 and
  .private_layout.hard_private_bytes_limit_per_rq == 98304 and
  .private_layout.private_object_max_alignment == 64 and
  .private_layout.slot_embeds_inner_cfs_rq == true and
  .private_layout.slot_embeds_top_sched_entity == true and
  .private_layout.slot_embeds_explicit_sched_statistics == true and
  .private_layout.rq_state_embeds_fixed_slots_nodes_and_control == true and
  (.private_layout.ordinary_hot_object_growth_bytes |
    [.sched_entity,.cfs_rq,.rq,.task_struct] | all(. == 0)) and
  .arm64_preflight.config_resolved == true and
  .arm64_preflight.slot_state_bytes == 768 and
  .arm64_preflight.top_node_bytes == 64 and
  .arm64_preflight.rq_control_bytes == 48 and
  .arm64_preflight.rq_state_bytes == 57344 and
  .arm64_preflight.conservative_private_bytes_per_rq == 74688 and
  .arm64_preflight.hard_limit_bytes_per_rq == 98304 and
  .arm64_preflight.maximum_alignment == 64 and
  .arm64_preflight.dual_arch_credit == false and
  .probe.existing_expanded_symbols_required == 51 and
  .probe.added_private_symbols == 49 and
  (.probe.expected_added_symbol_names | length) == 49 and
  (.probe.expected_added_symbol_names | unique | length) == 49 and
  .architecture_matrix.architectures == ["arm64","x86_64"] and
  .architecture_matrix.fresh_architecture_local_baselines_required == true and
  .architecture_matrix.disabled_private_symbols_relocations_and_strings_absent == true and
  .architecture_matrix.existing_51_values_unchanged == true and
  .next_gate.source_gate_must_pass_before_dual_arch == true and
  .next_gate.dual_arch_layout_may_start_after_source_gate == true and
  .next_gate.r6_e3_source_may_start == false and
  .next_gate.primary_linux_or_patch_queue_change == false and
  (.claims | to_entries | all(.value == false))
' "$CONFIG" >/dev/null || die 'R6-E2 source contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	printf 'exact R6-E2 source contract accepted in test mode\n'
	exit 0
fi

E1_RESULT="$WORKSPACE_DIR/$(jq -r '.e1_input.result' "$CONFIG")"
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-source-gate/$RUN_ID"
[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
for file in "$E1_RESULT" "$CANDIDATE_DIR/init/Kconfig" \
	"$CANDIDATE_DIR/kernel/sched/exec_lease.c"; do
	[ -f "$file" ] || die "missing input: $file"
	[ ! -L "$file" ] || die "input is a symlink: $file"
done
mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

[ "$(file_sha "$E1_RESULT")" = "$(jq -r '.e1_input.result_sha256' "$CONFIG")" ] ||
	die 'R6-E1 result hash changed'
jq -e '
  .status == "passed_r6_e1_domain_forest_evidence_plan" and
  .source_anchor_count == 40 and .source_anchor_failures == 0 and
  .future_absence_check_count == 8 and
  .future_absence_check_failures == 0 and
  .aggregate_phase_visit_bound == 127 and
  .candidate_phase_visit_bound == 127 and
  .complete_query_visit_bound == 254 and
  .computed_private_bytes_per_rq == 74688 and
  .hard_private_bytes_limit_per_rq == 98304 and
  .r6_e1_plan_accepted == true and
  .r6_e2_disposable_layout_may_start == true and
  .r6_layout_source_accepted == false and
  .r6_e3_or_behavior_may_start == false
' "$E1_RESULT" >/dev/null || die 'R6-E1 result semantics changed'

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_parent_tree=$(jq -r '.source.parent_tree' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
primary_commit=$(git -C "$PRIMARY_DIR" rev-parse HEAD)
primary_tree=$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')
candidate_commit=$(git -C "$CANDIDATE_DIR" rev-parse HEAD)
candidate_parent=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)
candidate_tree=$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')
remote_candidate=$(git -C "$CANDIDATE_DIR" rev-parse \
	'fork/codex/p5a-r6-e2-layout')
[ "$primary_commit" = "$expected_parent" ] || die 'primary Linux moved'
[ "$primary_tree" = "$expected_parent_tree" ] || die 'primary tree moved'
[ "$candidate_commit" = "$expected_candidate" ] || die 'candidate moved'
[ "$candidate_parent" = "$expected_parent" ] ||
	die 'candidate is not a direct primary child'
[ "$candidate_tree" = "$expected_tree" ] || die 'candidate tree moved'
[ "$remote_candidate" = "$expected_candidate" ] || die 'remote candidate moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'primary Linux tracked tree is dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'candidate tracked tree is dirty'
[ "$(git -C "$CANDIDATE_DIR" log -1 --format=%P)" = "$expected_parent" ] ||
	die 'candidate has more than one parent'
git -C "$CANDIDATE_DIR" log -1 --format=%B |
	grep -Eq '^Signed-off-by: .+ <.+>$' || die 'candidate lacks sign-off'

git -C "$CANDIDATE_DIR" diff --name-only \
	"$expected_parent..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" \
	> "$OUT_DIR/delta-files.diff" || die 'candidate escaped two-file boundary'
git -C "$CANDIDATE_DIR" diff --numstat \
	"$expected_parent..$expected_candidate" > "$OUT_DIR/delta-numstat.txt"
insertions=$(awk '{n += $1} END {print n+0}' "$OUT_DIR/delta-numstat.txt")
deletions=$(awk '{n += $2} END {print n+0}' "$OUT_DIR/delta-numstat.txt")
if [ "$insertions" != 208 ] || [ "$deletions" != 0 ]; then
	die "candidate line delta is $insertions/$deletions"
fi
git -C "$CANDIDATE_DIR" diff --check \
	"$expected_parent..$expected_candidate" > "$OUT_DIR/diff-check.txt"
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" \
	> "$OUT_DIR/candidate.diff"
diff_sha=$(file_sha "$OUT_DIR/candidate.diff")
[ "$diff_sha" = "$(jq -r '.source.candidate_diff_sha256' "$CONFIG")" ] ||
	die "candidate diff hash changed: $diff_sha"
git -C "$PRIMARY_DIR" apply --check "$OUT_DIR/candidate.diff"
git -C "$CANDIDATE_DIR" apply --reverse --check "$OUT_DIR/candidate.diff"

"$CANDIDATE_DIR/scripts/checkpatch.pl" --strict --no-tree \
	"$OUT_DIR/candidate.diff" > "$OUT_DIR/checkpatch.txt"
grep -q 'total: 0 errors, 0 warnings, 0 checks' \
	"$OUT_DIR/checkpatch.txt" || die 'strict checkpatch is not 0/0/0'

kconfig="$CANDIDATE_DIR/init/Kconfig"
source="$CANDIDATE_DIR/kernel/sched/exec_lease.c"
sed -n '/^config SCHED_EXEC_LEASE_R6_LAYOUT_PROBE$/,/^config /p' \
	"$kconfig" > "$OUT_DIR/candidate-kconfig.txt"
grep -q 'depends on SCHED_EXEC_LEASE && SCHED_EXEC_LEASE_LAYOUT_PROBE' \
	"$OUT_DIR/candidate-kconfig.txt" || die 'lease/layout dependency mismatch'
grep -q 'depends on DEBUG_KERNEL && SMP && CGROUP_SCHED && FAIR_GROUP_SCHED' \
	"$OUT_DIR/candidate-kconfig.txt" || die 'debug/group dependency mismatch'
grep -q 'depends on !SCHED_AUTOGROUP' \
	"$OUT_DIR/candidate-kconfig.txt" || die 'autogroup exclusion missing'
grep -q '^[[:space:]]*default n$' "$OUT_DIR/candidate-kconfig.txt" ||
	die 'candidate is not default off'

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpattern\n' > "$anchors"
check_anchor()
{
	local id=$1 pattern=$2 status
	if grep -Fq "$pattern" "$source"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\n' "$id" "$status" "$pattern" >> "$anchors"
}
check_anchor conditional '#ifdef CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE'
check_anchor b_max '#define SCHED_EXEC_R6_B_MAX'
check_anchor top_count '#define SCHED_EXEC_R6_TOP_NODE_COUNT'
check_anchor slot_max '#define SCHED_EXEC_R6_SLOT_STATE_MAX'
check_anchor top_max '#define SCHED_EXEC_R6_TOP_NODE_MAX'
check_anchor control_max '#define SCHED_EXEC_R6_RQ_CONTROL_MAX'
check_anchor hard_limit '#define SCHED_EXEC_R6_PRIVATE_RQ_LIMIT'
check_anchor slot_type 'struct sched_exec_r6_slot_state {'
check_anchor inner_cfs 'inner_cfs_rq;'
check_anchor top_entity 'top_entity;'
check_anchor top_stats 'top_stats;'
check_anchor root_digest 'domain_root_digest;'
check_anchor top_type 'struct sched_exec_r6_top_node {'
check_anchor subtree_mask 'subtree_mask;'
check_anchor runnable_mask 'runnable_mask;'
check_anchor eligible_mask 'eligible_mask;'
check_anchor leaf_version 'leaf_version;'
check_anchor summary_version 'summary_version;'
check_anchor control_type 'struct sched_exec_r6_rq_control {'
check_anchor observed_generation 'observed_generation;'
check_anchor allowed_mask 'observed_allowed_mask;'
check_anchor rq_state 'struct sched_exec_r6_rq_state {'
check_anchor fixed_slots 'slots[SCHED_EXEC_R6_B_MAX];'
check_anchor fixed_nodes 'top[SCHED_EXEC_R6_TOP_NODE_COUNT];'
anchor_count=$(awk 'NR > 1 {n++} END {print n+0}' "$anchors")
anchor_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "ok" {n++} END {print n+0}' "$anchors")
[ "$anchor_count" = 24 ] || die "source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

if grep -En '^\+.*(EXPORT_SYMBOL|DEFINE_STATIC_KEY|TRACE_EVENT|SYSCALL_DEFINE|debugfs_|proc_create|sysfs_)' \
	"$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-surfaces.txt"; then
	die 'candidate adds a runtime or userspace surface'
fi
if grep -En '^\+.*(queue_work|irq_work_queue|call_rcu|synchronize_rcu|kmalloc|kzalloc|kcalloc|alloc_percpu|alloc_workqueue|cpuhp_setup_state)[[:space:]]*\(' \
	"$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-runtime-calls.txt"; then
	die 'candidate adds a runtime callsite'
fi
if grep -En '^\+[^+].*\)[[:space:]]*\{' \
	"$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-functions.txt"; then
	die 'candidate adds a function definition'
fi
: > "$OUT_DIR/forbidden-surfaces.txt"
: > "$OUT_DIR/forbidden-runtime-calls.txt"
: > "$OUT_DIR/forbidden-functions.txt"

jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort \
	> "$OUT_DIR/expected-private-symbols.txt"
awk '
  /SCHED_EXEC_R6_SIZE_PROBE\(sched_exec_r6l_/ {
    line=$0; sub(/^.*\(/,"",line); sub(/,.*/,"",line); print line "_size"
  }
  /SCHED_EXEC_R6_OFFSET_PROBE\(sched_exec_r6l_/ {
    line=$0; sub(/^.*\(/,"",line); sub(/,.*/,"",line);
    print line "_offset_plus_one"
  }
  /SCHED_EXEC_R6_VALUE_PROBE\(sched_exec_r6l_/ {
    line=$0; sub(/^.*\(/,"",line); sub(/,.*/,"",line); print line "_value"
  }
' "$source" | sort > "$OUT_DIR/declared-private-symbols.txt"
diff -u "$OUT_DIR/expected-private-symbols.txt" \
	"$OUT_DIR/declared-private-symbols.txt" \
	> "$OUT_DIR/private-symbol-manifest.diff" ||
	die 'declared private-symbol manifest mismatch'
symbol_count=$(wc -l < "$OUT_DIR/expected-private-symbols.txt" | tr -d ' ')
[ "$symbol_count" = 49 ] || die "private symbol count: $symbol_count"

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = "16bb080da472ffabbbafd2698073eca633fb0602" ] ||
	die 'primary patch queue moved'

jq -S -n \
	--arg run_id "$RUN_ID" --arg primary_commit "$primary_commit" \
	--arg primary_tree "$primary_tree" \
	--arg candidate_commit "$candidate_commit" \
	--arg candidate_parent "$candidate_parent" \
	--arg candidate_tree "$candidate_tree" \
	--arg diff_sha "$diff_sha" \
	--arg e1_sha "$(file_sha "$E1_RESULT")" \
	--arg patch_queue_commit "$patch_queue_commit" \
	--argjson insertions "$insertions" --argjson deletions "$deletions" \
	--argjson anchors "$anchor_count" \
	--argjson symbols "$symbol_count" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r6_e2_source_gate",
  primary_linux_commit:$primary_commit,
  primary_linux_tree:$primary_tree,
  candidate_commit:$candidate_commit,
  candidate_parent:$candidate_parent,
  candidate_tree:$candidate_tree,
  candidate_diff_sha256:$diff_sha,
  r6_e1_result_sha256:$e1_sha,
  patch_queue_commit:$patch_queue_commit,
  insertions:$insertions,
  deletions:$deletions,
  exact_two_file_boundary:true,
  direct_primary_child:true,
  remote_candidate_exact:true,
  signed_off:true,
  forward_replay_check_passed:true,
  reverse_replay_check_passed:true,
  strict_checkpatch_errors:0,
  strict_checkpatch_warnings:0,
  strict_checkpatch_checks:0,
  source_anchor_count:$anchors,
  source_anchor_failures:0,
  private_symbol_count:$symbols,
  forbidden_runtime_calls:0,
  forbidden_function_definitions:0,
  forbidden_surfaces:0,
  config_default_off:true,
  sched_autogroup_excluded:true,
  conservative_private_bytes_per_rq:74688,
  hard_private_bytes_limit_per_rq:98304,
  dual_arch_layout_build_may_start:true,
  r6_e3_source_may_start:false,
  primary_linux_may_change:false,
  patch_queue_may_change:false,
  runtime_behavior_approved:false,
  performance_claim:false,
  production_protection:false,
  deployment_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
