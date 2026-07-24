#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0143-p5a-r6-e1-domain-forest-evidence-plan-model"
MODEL=P5AR6E1DomainForestEvidencePlan.tla
SAFE_CFG=P5AR6E1DomainForestEvidencePlanSafe.cfg
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
for command in awk chmod git grep java jq mkdir sed sha256sum tail; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ -f "$CONFIG" ] || die "missing config: $CONFIG"

progress '5% validating exact R6-E1 source-free contract'
jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "r6_e1_pre_source_plan_exact_disposable_e2_only" and
  .source_basis.primary_linux_commit ==
    "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .source_basis.primary_linux_tree ==
    "54f685aad94f28f0027cbba18cf5e29aadce234a" and
  .source_basis.r6_result_sha256 ==
    "82f9c5dd5f6793934e18ded895501a363527df144a3874a427437cef1ffe0bd6" and
  .source_basis.r5_immutable_selector_restored == false and
  .hierarchy_composition.one_sealed_domain_per_root_child_fair_subtree == true and
  .hierarchy_composition.first_fair_ancestor_below_root_is_domain_root_mechanism == true and
  .hierarchy_composition.descendant_cgroups_remain_inside_one_domain == true and
  .hierarchy_composition.cgroup_css_shares_membership_or_topology_is_authority == false and
  .hierarchy_composition.mixed_domain_subtree_allowed == false and
  .hierarchy_composition.one_domain_multiple_root_subtrees_allowed == false and
  .hierarchy_composition.ordinary_leased_task_directly_on_fair_root_allowed == false and
  .hierarchy_composition.cgroup_move_without_frozen_replacement_binding_allowed == false and
  .hierarchy_composition.sched_autogroup_supported == false and
  .hierarchy_composition.group_placement_replaces_final_task_check == false and
  .authority_descriptor.immutable_rcu_published == true and
  .authority_descriptor.fully_allocated_hashed_and_sealed_before_release_publish == true and
  .authority_descriptor.generation_and_slot_identity_reuse == false and
  .authority_descriptor.publication_constant_work == true and
  .authority_descriptor.publication_walks_rqs_tasks_slots_cgroups_or_cpus == false and
  .authority_descriptor.publication_allocates_repairs_queues_waits_flushes_or_cancels == false and
  .authority_descriptor.selector_acquire_checks_seal_generation_slot_root_profile_and_digest == true and
  .authority_descriptor.selector_reads_exactly_one_cpu_mask == true and
  .authority_descriptor.old_descriptor_fallback_authority == false and
  .authority_descriptor.mismatch_state == "Blocked" and
  .top_selector.b_max == 64 and
  .top_selector.unique_nodes == 127 and
  .top_selector.levels == 6 and
  .top_selector.aggregate_phase_visit_bound == 127 and
  .top_selector.candidate_phase_visit_bound == 127 and
  .top_selector.complete_query_visit_bound == 254 and
  .top_selector.mask_reconcile_slot_visit_bound == 64 and
  .top_selector.leaf_update_ancestor_visit_bound == 6 and
  .top_selector.logarithmic_query_claim == false and
  .top_selector.task_count_independent == true and
  .top_selector.aggregate_uses_allowed_runnable_domains_only == true and
  .top_selector.final_task_local_generation_domain_slot_check == true and
  .top_selector.task_tree_authorization_scan == false and
  .top_selector.immutable_selector_copy == false and
  .top_selector.revoked_slot_next_pick_visible == false and
  .top_selector.unauthorized_interval_creates_catch_up_credit == false and
  .fairness.two_level_domain_then_internal_fairness == true and
  .fairness.domain_weight == "NICE_0_LOAD" and
  .fairness.variable_domain_weights_supported == false and
  .fairness.cgroup_shares_change_top_domain_weight == false and
  .fairness.flat_cfs_equivalence_claim == false and
  .storage.slot_state_count_per_rq == 64 and
  .storage.top_node_count_per_rq == 127 and
  .storage.computed_private_bytes_per_rq == 74688 and
  .storage.hard_private_bytes_limit_per_rq == 98304 and
  .storage.private_object_max_alignment == 64 and
  .storage.allocation_before_cpu_accepts_r6_tasks == true and
  .storage.slot_65_or_allocation_or_descriptor_overflow_state == "Blocked" and
  .storage.evict_merge_alias_or_ordinary_root_fallback == false and
  .storage.allocation_under_task_or_rq_lock == false and
  (.storage | [
    .ordinary_sched_entity_delta_bytes,.ordinary_cfs_rq_delta_bytes,
    .ordinary_rq_delta_bytes,.ordinary_task_struct_delta_bytes
  ] | all(. == 0)) and
  .e2_boundary.direct_child_of_primary == true and
  .e2_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .e2_boundary.config == "SCHED_EXEC_LEASE_R6_LAYOUT_PROBE" and
  .e2_boundary.config_default_n == true and
  .e2_boundary.config_depends_on == [
    "SCHED_EXEC_LEASE","SCHED_EXEC_LEASE_LAYOUT_PROBE","DEBUG_KERNEL",
    "SMP","CGROUP_SCHED","FAIR_GROUP_SCHED","!SCHED_AUTOGROUP"
  ] and
  .e2_boundary.private_types_and_object_local_probes_only == true and
  .e2_boundary.constructors_callsites_callbacks_cpuhp_allocations_or_static_keys == false and
  .e2_boundary.export_trace_file_abi_monitor_or_policy == false and
  .e2_boundary.public_or_scheduler_header_change == false and
  .e2_boundary.primary_linux_change == false and
  .e2_boundary.patch_queue_change == false and
  .e2_boundary.arm64_architecture_local_build == true and
  .e2_boundary.x86_64_architecture_local_build == true and
  .e2_boundary.existing_expanded_probe_values_preserved == 51 and
  .e2_boundary.disabled_new_symbols_relocations_and_strings_absent == true and
  .task_and_migration.enqueue_rechecks_descriptor_slot_root_cpu_mask_online_accepting == true and
  .task_and_migration.one_slot_rq_contribution_per_task == true and
  .task_and_migration.migration_order == "remove_neutral_add" and
  .task_and_migration.simultaneous_source_destination_contribution == false and
  .task_and_migration.destination_rechecks_descriptor_mask_root_capacity_online_accepting == true and
  .task_and_migration.ordinary_root_fallback == false and
  .current_hotplug_lifetime.picker_mask_fence_stops_current == false and
  .current_hotplug_lifetime.current_stop_request_separate == true and
  .current_hotplug_lifetime.rq_offline_clears_accepting_and_visibility_first == true and
  .current_hotplug_lifetime.sleepable_cpuhp_drain_outside_scheduler_locks == true and
  .current_hotplug_lifetime.rcu_unpublish_and_grace_before_free == true and
  .current_hotplug_lifetime.generation_or_slot_reuse == false and
  .e3_gate.requires_e2_dual_arch_closure == true and
  .e3_gate.query_visit_bounds_checked == [127,127,254] and
  .e4_gate.requires_e3_correctness_closure == true and
  .e4_gate.arm64_first == true and
  .e4_gate.minimum_pairs_per_cell == 10000 and
  .e4_gate.ordinary_additional_p99_limit_ns == 5000 and
  .e4_gate.ordinary_additional_p999_limit_ns == 25000 and
  .e4_gate.ordinary_additional_max_limit_ns == 50000 and
  .cross_path.ordinary_cfs_only == true and
  .cross_path.sched_ext_core_proxy_deadline_server_rt_dl_idle_stop_percpu_covered == false and
  (.source_anchors | length) == 40 and
  (.future_absence_checks | length) == 8 and
  (.formal.unsafe_safety_faults | length) == 50 and
  (.formal.unsafe_safety_faults | unique | length) == 50 and
  (.formal.unsafe_liveness_faults | length) == 2 and
  (.formal.unsafe_liveness_faults | unique | length) == 2 and
  .formal.safe_liveness_properties == 2 and
  .next_gate.r6_e2_disposable_layout_may_start_after_validation == true and
  .next_gate.r6_e3_or_behavior_may_start == false and
  .next_gate.primary_linux_or_patch_queue_change == false and
  (.claims | to_entries | all(.value == false))
' "$CONFIG" >/dev/null || die 'R6-E1 contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	progress '100% exact R6-E1 contract accepted in test mode'
	exit 0
fi

R6_RESULT="$WORKSPACE_DIR/$(jq -r '.source_basis.r6_result' "$CONFIG")"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan"
OUT_DIR="$OUT_ROOT/$RUN_ID"
[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
for file in "$TLA_JAR" "$R6_RESULT" "$MODEL_DIR/$MODEL" \
	"$MODEL_DIR/$SAFE_CFG"; do
	[ -f "$file" ] || die "missing canonical input: $file"
	[ ! -L "$file" ] || die "canonical input is a symlink: $file"
done
mkdir -p "$OUT_DIR/generated-unsafe-configs"
chmod 0700 "$OUT_DIR"

progress '13% revalidating exact R6 architecture result'
[ "$(file_sha "$R6_RESULT")" = \
	"$(jq -r '.source_basis.r6_result_sha256' "$CONFIG")" ] ||
	die 'R6 architecture result hash changed'
jq -e '
  .status == "passed_sealed_masked_domain_forest_architecture_only" and
  .selected_successor == "sealed_masked_domain_forest" and
  .b_max == 64 and .allowed_mask_bits == 64 and
  .fixed_top_depth == 6 and .masked_query_worst_case_nodes == 127 and
  .masked_query_logarithmic_claimed == false and
  .immutable_authority_plane == true and .dynamic_selector_plane == true and
  .cgroup_is_authority == false and .flat_tree_variable_fallback == false and
  .two_level_fairness_explicit == true and
  .flat_cfs_equivalence_claimed == false and
  .r6_e1_source_free_plan_may_be_drafted == true and
  .r6_layout_or_source_may_start == false
' "$R6_RESULT" >/dev/null || die 'R6 architecture result semantics changed'

progress '22% checking Linux hierarchy/lifetime anchors and R6 absence'
expected_commit=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify 'HEAD^{tree}')
[ "$actual_commit" = "$expected_commit" ] ||
	die "Linux commit mismatch: expected=$expected_commit actual=$actual_commit"
[ "$actual_tree" = "$expected_tree" ] ||
	die "Linux tree mismatch: expected=$expected_tree actual=$actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'Linux tracked working tree is dirty'

printf 'id\tstatus\tpath\tpattern\n' > "$OUT_DIR/source-anchors.tsv"
while IFS= read -r row; do
	anchor_id=$(printf '%s\n' "$row" | jq -r '.id')
	anchor_path=$(printf '%s\n' "$row" | jq -r '.path')
	anchor_pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if grep -Fq "$anchor_pattern" "$WORKSPACE_DIR/$anchor_path"; then
		anchor_status=ok
	else
		anchor_status=missing
	fi
	printf '%s\t%s\t%s\t%s\n' \
		"$anchor_id" "$anchor_status" "$anchor_path" "$anchor_pattern" \
		>> "$OUT_DIR/source-anchors.tsv"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "ok" {n++} END {print n+0}' \
	"$OUT_DIR/source-anchors.tsv")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

printf 'id\tstatus\tpattern\n' > "$OUT_DIR/future-absence.tsv"
while IFS= read -r row; do
	absence_id=$(printf '%s\n' "$row" | jq -r '.id')
	absence_pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$absence_pattern" -- \
		include/linux/sched.h include/linux/sched_exec_lease.h \
		kernel/sched init/Kconfig; then
		absence_status=unexpected-present
	else
		absence_status=absent
	fi
	printf '%s\t%s\t%s\n' \
		"$absence_id" "$absence_status" "$absence_pattern" \
		>> "$OUT_DIR/future-absence.tsv"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' \
	'NR > 1 && $2 != "absent" {n++} END {print n+0}' \
	"$OUT_DIR/future-absence.tsv")
[ "$absence_failures" = 0 ] ||
	die "future-source absence failures: $absence_failures"

progress '34% checking safe R6-E1 ordering and progress'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' \
	"$OUT_DIR/tlc-safe.log" || die 'safe R6-E1 model did not pass'
grep -q 'Checking 2 branches of temporal properties' "$OUT_DIR/tlc-safe.log" ||
	die 'safe R6-E1 liveness properties were not checked'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
[ "${safe_states:-0}" = 10 ] || die 'unexpected safe state count'
[ "${safe_distinct:-0}" = 10 ] || die 'unexpected safe distinct-state count'
[ "${safe_depth:-0}" = 10 ] || die 'unexpected safe search depth'

progress '43% reproducing 50 safety counterexamples'
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
		'INVARIANT ArchitectureSafety' > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
			-metadir "$OUT_DIR/states-safety-$fault" \
			-config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe safety fault unexpectedly passed: %s\n' "$fault" >&2
		safety_failures=$((safety_failures + 1))
	elif grep -Eq \
		'Invariant (TypeOK|ArchitectureSafety) is violated' "$log"; then
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

progress '83% reproducing two independent liveness counterexamples'
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
		'INVARIANT ArchitectureSafety' \
		'PROPERTY AllowedProgress' \
		'PROPERTY RevokedCurrentProgress' > "$cfg"
	if (
		cd "$MODEL_DIR"
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

progress '96% sealing exact source-free R6-E1 decision'
jq -S -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" --arg linux_tree "$actual_tree" \
	--arg r6_result_sha "$(file_sha "$R6_RESULT")" \
	--argjson anchors "$anchor_count" --argjson absences "$absence_count" \
	--argjson safe_states "$safe_states" \
	--argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" \
	--argjson safety_faults "$safety_expected" \
	--argjson liveness_faults "$liveness_expected" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r6_e1_domain_forest_evidence_plan",
  linux_commit:$linux_commit,
  linux_tree:$linux_tree,
  r6_architecture_result_sha256:$r6_result_sha,
  source_anchor_count:$anchors,
  source_anchor_failures:0,
  future_absence_check_count:$absences,
  future_absence_check_failures:0,
  hierarchy_composition:"one_sealed_domain_per_root_child_fair_subtree",
  cgroup_is_authority:false,
  sched_autogroup_supported:false,
  b_max:64,
  unique_top_nodes:127,
  aggregate_phase_visit_bound:127,
  candidate_phase_visit_bound:127,
  complete_query_visit_bound:254,
  query_logarithmic_claim:false,
  mask_reconcile_slot_bound:64,
  leaf_update_ancestor_bound:6,
  fixed_equal_domain_weight:true,
  flat_cfs_equivalence_claim:false,
  computed_private_bytes_per_rq:74688,
  hard_private_bytes_limit_per_rq:98304,
  ordinary_hot_object_growth_bytes:0,
  migration_remove_neutral_add:true,
  current_stop_separate_from_picker:true,
  safe_passed:true,
  liveness_properties_checked:2,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  unsafe_safety_counterexamples:$safety_faults,
  unsafe_liveness_counterexamples:$liveness_faults,
  r6_e1_plan_accepted:true,
  r6_e2_disposable_layout_may_start:true,
  r6_layout_source_accepted:false,
  r6_e3_or_behavior_may_start:false,
  runtime_behavior_approved:false,
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
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% R6-E1 accepted; disposable default-off E2 layout only'
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
