#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CANDIDATE_DIR=${DOMAINLEASE_R6_E2_DIR:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout"}
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0144-p5a-r6-e3-correctness-concurrency-evidence-plan-model"
MODEL=P5AR6E3CorrectnessConcurrencyEvidencePlan.tla
SAFE_CFG=P5AR6E3CorrectnessConcurrencyEvidencePlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
TEST_MODE=${TEST_MODE:-0}
CONTRACT_ONLY=${CONTRACT_ONLY:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '[progress] %s\n' "$*"
	if [ -n "$PROGRESS_FILE" ]; then
		mkdir -p "$(dirname "$PROGRESS_FILE")"
		printf '%s\n' "$*" > "$PROGRESS_FILE"
	fi
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
for command in awk chmod cp diff git grep java jq mkdir sed sha256sum \
	sort tail wc; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ -f "$CONFIG" ] || die "missing config: $CONFIG"

progress '4% validating exact source-free R6-E3 contract'
jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "r6_e3_source_free_pre_source_plan" and
  .source_basis.primary_linux_commit ==
    "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_basis.primary_linux_tree ==
    "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_basis.e2_candidate_parent ==
    .source_basis.primary_linux_commit and
  .source_basis.e2_candidate_commit ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .source_basis.e2_candidate_tree ==
    "603762b7a36d7b57e2456b90538c3ba77a1aba16" and
  .source_basis.e2_candidate_diff_sha256 ==
    "1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed" and
  .source_basis.e2_contract_sha256 ==
    "451704317503cf9453e1f3cb5b1de9d687209ba3a61f852bcbb3000e94af4dc6" and
  .source_basis.e2_source_gate_sha256 ==
    "18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f" and
  .source_basis.e2_dual_arch_result_sha256 ==
    "6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4" and
  .source_basis.e2_closure_result_sha256 ==
    "e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8" and
  .source_basis.patch_queue_commit ==
    "16bb080da472ffabbbafd2698073eca633fb0602" and
  .source_basis.patch_queue_series_blob ==
    "298567f8e0bd18168222da4e64da32750b9ea818" and
  .source_basis.patch_queue_tail ==
    "0014-sched-exec_lease-Expand-build-only-layout-probe.patch" and
  .source_basis.primary_linux_change_allowed == false and
  .source_basis.patch_queue_change_allowed == false and
  .source_basis.e2_candidate_amend_allowed == false and
  .source_boundary.future_parent ==
    .source_basis.e2_candidate_commit and
  .source_boundary.direct_child_required == true and
  .source_boundary.allowed_files ==
    ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source_boundary.e2_private_layout_block_byte_preserved == true and
  .source_boundary.e2_private_probe_values_preserved == 49 and
  .source_boundary.existing_expanded_probe_values_preserved == 51 and
  (.source_boundary.ordinary_structure_growth_bytes |
    to_entries | all(.value == 0)) and
  .source_boundary.strict_checkpatch_errors_allowed == 0 and
  .source_boundary.strict_checkpatch_warnings_allowed == 0 and
  .source_boundary.strict_checkpatch_checks_allowed == 0 and
  .source_boundary.production_attachment_allowed == false and
  .configuration.name == "SCHED_EXEC_LEASE_R6_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.depends_on ==
    ["SCHED_EXEC_LEASE_R6_LAYOUT_PROBE","KUNIT=y"] and
  .configuration.selected_by_lease_layout_or_kunit_all_tests == false and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite == "sched_exec_lease_r6_correctness" and
  .configuration.release_config_enabled == false and
  .configuration.disabled_symbols_relocations_strings_initcalls_or_allocations == false and
  .prototype_scope.synthetic_rq_only == true and
  .prototype_scope.instantiates_exact_e2_private_types == true and
  .prototype_scope.real_raw_spinlocks_and_rcu == true and
  .prototype_scope.real_refcounts_and_cpumasks == true and
  .prototype_scope.live_rq_task_group_or_cgroup_attachment == false and
  .prototype_scope.production_enqueue_dequeue_pick_migrate_or_hotplug_call == false and
  .prototype_scope.monitor_policy_budget_or_authority_decision == false and
  .prototype_scope.export_trace_file_or_userspace_surface == false and
  .prototype_scope.timing_sleep_as_race_proof == false and
  .independent_oracle.plain_64_leaf_records == true and
  .independent_oracle.reuses_implementation_tree_or_transition_helper == false and
  .independent_oracle.enumerates_all_64_leaves == true and
  .independent_oracle.allowed_runnable_aggregate_only == true and
  .independent_oracle.linux_left_biased_signed_division == true and
  .independent_oracle.tie_break == "stable_slot_id" and
  .independent_oracle.mask_cases ==
    ["empty","singleton","alternating","all_64",
     "current_only","revoked_current"] and
  .independent_oracle.implementation_and_oracle_state_separate == true and
  .independent_oracle.receipt_after_every_forced_transition == true and
  .selector_bounds.b_max == 64 and
  .selector_bounds.unique_tree_nodes == 127 and
  .selector_bounds.levels == 6 and
  .selector_bounds.aggregate_phase_max_visits == 127 and
  .selector_bounds.candidate_phase_max_visits == 127 and
  .selector_bounds.complete_query_max_visits == 254 and
  .selector_bounds.leaf_update_max_ancestors == 6 and
  .selector_bounds.reconcile_max_slots == 64 and
  .selector_bounds.reconcile_changed_bit_cases == [0,1,63,64] and
  .selector_bounds.task_tree_authorization_scan == false and
  .selector_bounds.logarithmic_arbitrary_mask_claim == false and
  .selector_bounds.bounds_are_structural_not_latency == true and
  .fairness_oracles.fixed_equal_domain_weight == "NICE_0_LOAD" and
  .fairness_oracles.two_level_domain_then_internal_fairness == true and
  .fairness_oracles.canonical_equal_domain_rounds == 4096 and
  .fairness_oracles.equal_service_difference_max_one_top_slice == true and
  .fairness_oracles.stable_all_64_no_starvation_max_pick_gap == 64 and
  .fairness_oracles.denied_domain_service_increment == 0 and
  .fairness_oracles.reallowed_initial_negative_lag == 0 and
  .fairness_oracles.unauthorized_interval_catch_up_credit == 0 and
  .fairness_oracles.positive_debt_erased_on_reallow == false and
  .fairness_oracles.flat_cfs_equivalence_claim == false and
  .fairness_oracles.variable_domain_weight_supported == false and
  .hierarchy_and_authority.one_domain_per_root_child_fair_subtree == true and
  .hierarchy_and_authority.cgroup_is_mechanism_not_authority == true and
  .hierarchy_and_authority.mixed_domain_subtree_state == "Blocked" and
  .hierarchy_and_authority.one_domain_multiple_roots_state == "Blocked" and
  .hierarchy_and_authority.leased_root_task_state == "Blocked" and
  .hierarchy_and_authority.sched_autogroup_state == "Blocked" and
  .hierarchy_and_authority.final_task_generation_domain_slot_check == true and
  .hierarchy_and_authority.old_descriptor_fallback_authority == false and
  .task_and_migration.fork_inherits_frozen_binding == true and
  .task_and_migration.exec_advances_generation_before_runnable_commitment == true and
  .task_and_migration.enqueue_rechecks_descriptor_slot_root_mask_online_accepting == true and
  .task_and_migration.one_contribution_per_task == true and
  .task_and_migration.migration_order == "remove_neutral_add" and
  .task_and_migration.simultaneous_source_destination_contribution == false and
  .task_and_migration.destination_failure_state == "BlockedNeutral" and
  .task_and_migration.source_restoration_after_destination_failure == false and
  .task_and_migration.ordinary_root_fallback == false and
  .current_hotplug_lifetime.picker_mask_fence_stops_current == false and
  .current_hotplug_lifetime.current_stop_request_separate == true and
  .current_hotplug_lifetime.later_changed_or_revalidated_observation_required == true and
  .current_hotplug_lifetime.request_is_monitor_interrupt_or_completion_receipt == false and
  .current_hotplug_lifetime.offline_visibility_and_accepting_removed_first == true and
  .current_hotplug_lifetime.sleepable_drain_outside_scheduler_locks == true and
  .current_hotplug_lifetime.online_order ==
    "allocate_initialize_publish_accept" and
  .current_hotplug_lifetime.offline_order ==
    "stop_accepting_remove_visibility_drain_unpublish_grace_free" and
  .current_hotplug_lifetime.rcu_grace_before_free == true and
  .current_hotplug_lifetime.generation_or_slot_reuse == false and
  .allocation_faults.sites ==
    ["sealed_descriptor","per_cpu_rq_state","task_binding"] and
  .allocation_faults.all_allocations_before_runnable_contribution == true and
  .allocation_faults.allocation_under_task_or_rq_lock == false and
  .allocation_faults.failure_state == "Blocked" and
  .allocation_faults.failure_leaves_contribution_or_reference == false and
  .allocation_faults.clean_retry_after_fault_removal == true and
  .allocation_faults.slot_65_state == "Blocked" and
  (.required_case_families | length) == 55 and
  (.required_case_families | unique | length) == 55 and
  .race_control.completions_atomic_checkpoints_or_explicit_barriers == true and
  .race_control.timing_only_sleep_is_proof == false and
  .race_control.hard_case_timeout_seconds == 15 and
  .race_control.stress_repetitions_per_diagnostic_profile == 4096 and
  .race_control.case_reduction_after_failure == false and
  .race_control.skip_or_expected_failure_allowed == false and
  .build_and_boot_matrix.architectures == ["arm64","x86_64"] and
  (.build_and_boot_matrix.fresh_build_modes_per_architecture | length) == 4 and
  (.build_and_boot_matrix.diagnostic_boots | length) == 4 and
  .build_and_boot_matrix.exact_suite_filter ==
    "sched_exec_lease_r6_correctness" and
  .build_and_boot_matrix.every_case_and_receipt_required == true and
  .build_and_boot_matrix.zero_fail_skip_timeout_or_warning == true and
  .build_and_boot_matrix.e2_49_values_preserved_when_enabled == true and
  .build_and_boot_matrix.existing_51_values_preserved == true and
  .build_and_boot_matrix.disabled_e3_symbols_relocations_strings_initcalls_absent == true and
  .build_and_boot_matrix.ordinary_structure_growth_bytes == 0 and
  .build_and_boot_matrix.fresh_builds_and_boots_required == true and
  (.warning_rejection_patterns | length) == 17 and
  (.formal.safe_liveness_properties | length) == 3 and
  (.formal.unsafe_safety_faults | length) == 79 and
  (.formal.unsafe_safety_faults | unique | length) == 79 and
  (.formal.unsafe_liveness_faults | length) == 3 and
  (.formal.unsafe_liveness_faults | unique | length) == 3 and
  .authorization_after_pass.disposable_e3_source_draft_may_start == true and
  .authorization_after_pass.e3_source_or_correctness_accepted == false and
  .authorization_after_pass.e4_plan_or_source_may_start == false and
  .authorization_after_pass.primary_linux_or_patch_queue_change == false and
  (.claims | to_entries | all(.value == false)) and
  (.source_anchors | length) == 24 and
  (.source_anchors | map(.id) | unique | length) == 24 and
  (.future_absence_checks | length) == 12 and
  (.future_absence_checks | map(.id) | unique | length) == 12
' "$CONFIG" >/dev/null || die 'R6-E3 contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	progress '100% exact R6-E3 contract accepted in test mode'
	exit 0
fi

OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan"
OUT_DIR="$OUT_ROOT/$RUN_ID"
[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
mkdir -p "$OUT_DIR/inputs" "$OUT_DIR/generated-unsafe-configs"
chmod 0700 "$OUT_DIR"

RUNNER="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
runner_sha_start=$(file_sha "$RUNNER")
tla_jar_sha_start=$(file_sha "$TLA_JAR")

snapshot_input()
{
	local source=$1 name=$2 before after
	[ -f "$source" ] || die "missing canonical input: $source"
	[ ! -L "$source" ] || die "canonical input is a symlink: $source"
	before=$(file_sha "$source")
	cp "$source" "$OUT_DIR/inputs/$name"
	after=$(file_sha "$source")
	[ "$before" = "$after" ] || die "input changed while copied: $source"
	[ "$(file_sha "$OUT_DIR/inputs/$name")" = "$before" ] ||
		die "input snapshot differs: $source"
	printf '%s\t%s\t%s\n' "$name" "$source" "$before" \
		>> "$OUT_DIR/input-manifest.tsv"
}

printf 'snapshot\tsource\tsha256\n' > "$OUT_DIR/input-manifest.tsv"
snapshot_input "$CANONICAL_CONFIG" contract.json
snapshot_input "$MODEL_DIR/$MODEL" "$MODEL"
snapshot_input "$MODEL_DIR/$SAFE_CFG" "$SAFE_CFG"
E2_CONTRACT="$CAPSCHED_DIR/$(jq -r '.source_basis.e2_contract' "$CONFIG")"
E2_SOURCE_GATE="$WORKSPACE_DIR/$(jq -r '.source_basis.e2_source_gate' "$CONFIG")"
E2_RESULT="$WORKSPACE_DIR/$(jq -r '.source_basis.e2_dual_arch_result' "$CONFIG")"
E2_CLOSURE="$WORKSPACE_DIR/$(jq -r '.source_basis.e2_closure_result' "$CONFIG")"
snapshot_input "$E2_CONTRACT" e2-contract.json
snapshot_input "$E2_SOURCE_GATE" e2-source-gate-result.json
snapshot_input "$E2_RESULT" e2-dual-arch-result.json
snapshot_input "$E2_CLOSURE" e2-closure-result.json
CONFIG="$OUT_DIR/inputs/contract.json"
SNAPSHOT_MODEL_DIR="$OUT_DIR/inputs"

progress '11% revalidating exact R6-E2 result and independent closure'
[ "$(file_sha "$OUT_DIR/inputs/e2-contract.json")" = \
	"$(jq -r '.source_basis.e2_contract_sha256' "$CONFIG")" ] ||
	die 'R6-E2 contract hash changed'
[ "$(file_sha "$OUT_DIR/inputs/e2-source-gate-result.json")" = \
	"$(jq -r '.source_basis.e2_source_gate_sha256' "$CONFIG")" ] ||
	die 'R6-E2 source-gate hash changed'
[ "$(file_sha "$OUT_DIR/inputs/e2-dual-arch-result.json")" = \
	"$(jq -r '.source_basis.e2_dual_arch_result_sha256' "$CONFIG")" ] ||
	die 'R6-E2 dual-architecture hash changed'
[ "$(file_sha "$OUT_DIR/inputs/e2-closure-result.json")" = \
	"$(jq -r '.source_basis.e2_closure_result_sha256' "$CONFIG")" ] ||
	die 'R6-E2 closure hash changed'
jq -e '
  .status == "passed_r6_e2_evidence_closure" and
  .dual_arch_r6_e2_complete == true and
  .r6_e2_evidence_closed == true and
  .architectures == ["arm64","x86_64"] and
  .configurations_revalidated == 8 and .objects_revalidated == 14 and
  .build_log_count == 24 and .build_diagnostic_count == 0 and
  .existing_probe_symbol_count_per_architecture == 51 and
  .existing_probe_value_changes_per_architecture == 0 and
  .private_probe_symbol_count_per_architecture == 49 and
  .private_disabled_symbol_count == 0 and
  .private_disabled_relocation_count == 0 and
  .private_disabled_string_count == 0 and
  .ordinary_scheduler_layout_delta ==
    {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .private_memory_envelope_passed == true and
  .r6_e3_plan_may_start == true and .r6_e3_source_may_start == false and
  .runtime_behavior_approved == false and .production_protection == false
' "$OUT_DIR/inputs/e2-closure-result.json" >/dev/null ||
	die 'R6-E2 closure semantics changed'

progress '18% checking candidate, primary, patch queue, and source anchors'
expected_primary=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_primary_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
expected_candidate=$(jq -r '.source_basis.e2_candidate_commit' "$CONFIG")
expected_candidate_tree=$(jq -r '.source_basis.e2_candidate_tree' "$CONFIG")
expected_candidate_diff=$(jq -r \
	'.source_basis.e2_candidate_diff_sha256' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] ||
	die 'primary Linux moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')" = \
	"$expected_primary_tree" ] || die 'primary Linux tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] ||
	die 'R6-E2 candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$expected_primary" ] ||
	die 'R6-E2 candidate is not a direct primary child'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = \
	"$expected_candidate_tree" ] || die 'R6-E2 candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'primary Linux tracked tree is dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'R6-E2 candidate tracked tree is dirty'
git -C "$CANDIDATE_DIR" diff "$expected_primary..$expected_candidate" \
	> "$OUT_DIR/e2-candidate.diff"
[ "$(file_sha "$OUT_DIR/e2-candidate.diff")" = "$expected_candidate_diff" ] ||
	die 'R6-E2 candidate diff changed'
git -C "$CANDIDATE_DIR" diff --name-only \
	"$expected_primary..$expected_candidate" > "$OUT_DIR/e2-delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-e2-delta-files.txt"
diff -u "$OUT_DIR/expected-e2-delta-files.txt" \
	"$OUT_DIR/e2-delta-files.txt" > "$OUT_DIR/e2-delta-files.diff" ||
	die 'R6-E2 candidate escaped exact two-file scope'

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = \
	"$(jq -r '.source_basis.patch_queue_commit' "$CONFIG")" ] ||
	die 'patch queue commit moved'
series=patches/capsched-linux-l0/series
series_blob=$(git -C "$PATCH_QUEUE_DIR" hash-object \
	"$PATCH_QUEUE_DIR/$series")
[ "$series_blob" = \
	"$(jq -r '.source_basis.patch_queue_series_blob' "$CONFIG")" ] ||
	die 'patch queue series moved'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/$series")" = \
	"$(jq -r '.source_basis.patch_queue_tail' "$CONFIG")" ] ||
	die 'patch queue tail moved'

printf 'id\tstatus\ttree\tpath\tpattern\n' > "$OUT_DIR/source-anchors.tsv"
while IFS= read -r row; do
	anchor_id=$(printf '%s\n' "$row" | jq -r '.id')
	tree_name=$(printf '%s\n' "$row" | jq -r '.tree')
	path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	case "$tree_name" in
		primary) tree=$PRIMARY_DIR ;;
		candidate) tree=$CANDIDATE_DIR ;;
		*) die "unknown anchor tree: $tree_name" ;;
	esac
	if grep -Fq "$pattern" "$tree/$path"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\t%s\n' "$anchor_id" "$status" \
		"$tree_name" "$path" "$pattern" >> "$OUT_DIR/source-anchors.tsv"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "ok" {n++} END {print n+0}' \
	"$OUT_DIR/source-anchors.tsv")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

printf 'tree\tpath\texpected_blob\tworking_blob\n' \
	> "$OUT_DIR/source-object-manifest.tsv"
jq -r '.source_anchors[] | [.tree,.path] | @tsv' "$CONFIG" | sort -u |
while IFS=$'\t' read -r tree_name path; do
	case "$tree_name" in
		primary) tree=$PRIMARY_DIR ;;
		candidate) tree=$CANDIDATE_DIR ;;
	esac
	expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
	working_blob=$(git -C "$tree" hash-object "$tree/$path")
	[ "$expected_blob" = "$working_blob" ] ||
		die "$tree_name source differs from HEAD: $path"
	printf '%s\t%s\t%s\t%s\n' "$tree_name" "$path" \
		"$expected_blob" "$working_blob" \
		>> "$OUT_DIR/source-object-manifest.tsv"
done
source_object_count=$(( $(wc -l < "$OUT_DIR/source-object-manifest.tsv") - 1 ))

progress '27% checking future R6-E3 source absence'
printf 'id\tstatus\tpattern\n' > "$OUT_DIR/future-absence.tsv"
while IFS= read -r row; do
	absence_id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$CANDIDATE_DIR" grep -Fq "$pattern" -- \
		init/Kconfig kernel/sched/exec_lease.c; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$absence_id" "$status" "$pattern" \
		>> "$OUT_DIR/future-absence.tsv"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "absent" {n++} END {print n+0}' \
	"$OUT_DIR/future-absence.tsv")
[ "$absence_failures" = 0 ] ||
	die "future-source absence failures: $absence_failures"

progress '34% checking safe selector, migration, current, and lifetime order'
(
	cd "$SNAPSHOT_MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' \
	"$OUT_DIR/tlc-safe.log" || die 'safe R6-E3 model did not pass'
grep -q 'Checking 3 branches of temporal properties' "$OUT_DIR/tlc-safe.log" ||
	die 'safe R6-E3 liveness properties were not checked'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
[ "${safe_states:-0}" = 14 ] || die 'unexpected safe state count'
[ "${safe_distinct:-0}" = 14 ] || die 'unexpected safe distinct-state count'
[ "${safe_depth:-0}" = 14 ] || die 'unexpected safe search depth'

progress '42% reproducing 79 R6-E3 safety counterexamples'
safety_fault_count=$(jq '.formal.unsafe_safety_faults | length' "$CONFIG")
safety_expected=0
safety_failures=0
while IFS= read -r fault; do
	cfg="$OUT_DIR/generated-unsafe-configs/safety-$fault.cfg"
	log="$OUT_DIR/tlc-safety-$fault.log"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT EvidenceSafety' > "$cfg"
	if (
		cd "$SNAPSHOT_MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-safety-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe safety fault unexpectedly passed: %s\n' "$fault" >&2
		safety_failures=$((safety_failures + 1))
	elif grep -Eq \
		'Invariant (TypeOK|EvidenceSafety) is violated' "$log"; then
		safety_expected=$((safety_expected + 1))
	else
		printf 'unsafe safety fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 40 "$log" >&2
		safety_failures=$((safety_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_safety_faults[]' "$CONFIG")
[ "$safety_failures" = 0 ] ||
	die "unsafe safety TLC failures: $safety_failures"
[ "$safety_expected" = "$safety_fault_count" ] ||
	die "unsafe safety mismatch: expected=$safety_fault_count actual=$safety_expected"

progress '88% reproducing three independent liveness counterexamples'
liveness_fault_count=$(jq '.formal.unsafe_liveness_faults | length' "$CONFIG")
liveness_expected=0
liveness_failures=0
while IFS= read -r fault; do
	cfg="$OUT_DIR/generated-unsafe-configs/liveness-$fault.cfg"
	log="$OUT_DIR/tlc-liveness-$fault.log"
	printf '%s\n' \
		'SPECIFICATION Spec' \
		"CONSTANT Fault = \"$fault\"" \
		'CHECK_DEADLOCK FALSE' \
		'INVARIANT TypeOK' \
		'INVARIANT EvidenceSafety' \
		'PROPERTY AllowedPickProgress' \
		'PROPERTY RevokedCurrentProgress' \
		'PROPERTY OfflineDrainProgress' > "$cfg"
	if (
		cd "$SNAPSHOT_MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-liveness-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe liveness fault unexpectedly passed: %s\n' "$fault" >&2
		liveness_failures=$((liveness_failures + 1))
	elif grep -q 'Temporal properties were violated' "$log"; then
		liveness_expected=$((liveness_expected + 1))
	else
		printf 'unsafe liveness fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 40 "$log" >&2
		liveness_failures=$((liveness_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_liveness_faults[]' "$CONFIG")
[ "$liveness_failures" = 0 ] ||
	die "unsafe liveness TLC failures: $liveness_failures"
[ "$liveness_expected" = "$liveness_fault_count" ] ||
	die "unsafe liveness mismatch: expected=$liveness_fault_count actual=$liveness_expected"

progress '96% sealing exact R6-E3 source-free decision'
[ "$(file_sha "$RUNNER")" = "$runner_sha_start" ] ||
	die 'runner changed during validation'
[ "$(file_sha "$TLA_JAR")" = "$tla_jar_sha_start" ] ||
	die 'TLA+ tool changed during validation'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] ||
	die 'primary Linux changed during validation'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] ||
	die 'R6-E2 candidate changed during validation'

input_manifest_sha=$(file_sha "$OUT_DIR/input-manifest.tsv")
source_manifest_sha=$(file_sha "$OUT_DIR/source-object-manifest.tsv")
contract_sha=$(file_sha "$OUT_DIR/inputs/contract.json")
model_sha=$(file_sha "$OUT_DIR/inputs/$MODEL")
safe_cfg_sha=$(file_sha "$OUT_DIR/inputs/$SAFE_CFG")
case_count=$(jq '.required_case_families | length' "$CONFIG")
boot_count=$(jq '.build_and_boot_matrix.diagnostic_boots | length' "$CONFIG")

jq -S -n \
	--arg run_id "$RUN_ID" \
	--arg runner "$RUNNER" --arg runner_sha "$runner_sha_start" \
	--arg contract_sha "$contract_sha" \
	--arg model_sha "$model_sha" --arg safe_cfg_sha "$safe_cfg_sha" \
	--arg tla_jar_sha "$tla_jar_sha_start" \
	--arg input_manifest "$OUT_DIR/input-manifest.tsv" \
	--arg input_manifest_sha "$input_manifest_sha" \
	--arg source_manifest "$OUT_DIR/source-object-manifest.tsv" \
	--arg source_manifest_sha "$source_manifest_sha" \
	--arg primary_commit "$expected_primary" \
	--arg primary_tree "$expected_primary_tree" \
	--arg candidate_commit "$expected_candidate" \
	--arg candidate_tree "$expected_candidate_tree" \
	--arg candidate_diff "$expected_candidate_diff" \
	--arg patch_queue_commit "$patch_queue_commit" \
	--arg patch_queue_series_blob "$series_blob" \
	--arg e2_source_gate_sha "$(file_sha "$OUT_DIR/inputs/e2-source-gate-result.json")" \
	--arg e2_result_sha "$(file_sha "$OUT_DIR/inputs/e2-dual-arch-result.json")" \
	--arg e2_closure_sha "$(file_sha "$OUT_DIR/inputs/e2-closure-result.json")" \
	--argjson anchors "$anchor_count" \
	--argjson source_objects "$source_object_count" \
	--argjson absences "$absence_count" \
	--argjson cases "$case_count" --argjson boots "$boot_count" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson safety_faults "$safety_expected" \
	--argjson liveness_faults "$liveness_expected" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r6_e3_correctness_concurrency_evidence_plan",
  runner:$runner,
  runner_sha256:$runner_sha,
  contract_sha256:$contract_sha,
  model_sha256:$model_sha,
  safe_cfg_sha256:$safe_cfg_sha,
  tla_jar_sha256:$tla_jar_sha,
  input_manifest:$input_manifest,
  input_manifest_sha256:$input_manifest_sha,
  primary_linux_commit:$primary_commit,
  primary_linux_tree:$primary_tree,
  e2_candidate_commit:$candidate_commit,
  e2_candidate_tree:$candidate_tree,
  e2_candidate_diff_sha256:$candidate_diff,
  e2_source_gate_sha256:$e2_source_gate_sha,
  e2_dual_arch_result_sha256:$e2_result_sha,
  e2_closure_result_sha256:$e2_closure_sha,
  patch_queue_commit:$patch_queue_commit,
  patch_queue_series_blob:$patch_queue_series_blob,
  source_object_manifest:$source_manifest,
  source_object_manifest_sha256:$source_manifest_sha,
  source_object_count:$source_objects,
  source_anchor_count:$anchors,
  source_anchor_failures:0,
  future_absence_check_count:$absences,
  future_absence_check_failures:0,
  independent_oracle_leaves:64,
  mask_cases:6,
  required_case_families:$cases,
  aggregate_phase_visit_bound:127,
  candidate_phase_visit_bound:127,
  complete_query_visit_bound:254,
  reconcile_slot_bound:64,
  leaf_update_ancestor_bound:6,
  equal_domain_fairness_rounds:4096,
  diagnostic_boots_required:$boots,
  safe_passed:true,
  liveness_properties_checked:3,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  unsafe_safety_counterexamples:$safety_faults,
  unsafe_liveness_counterexamples:$liveness_faults,
  r6_e3_plan_accepted:true,
  disposable_e3_source_draft_may_start:true,
  r6_e3_source_accepted:false,
  r6_e3_correctness_accepted:false,
  r6_e4_plan_or_source_may_start:false,
  primary_linux_changed:false,
  patch_queue_changed:false,
  runtime_behavior_approved:false,
  runtime_denial_correctness:false,
  monitor_verified:false,
  flat_cfs_equivalence:false,
  bare_metal_validated:false,
  performance_claim:false,
  cost_claim:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% R6-E3 plan accepted; exact disposable source draft only'
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
