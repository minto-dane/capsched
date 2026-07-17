#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e3-bucket-concurrency-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-e4-bucket-measurement-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0134-p5a-r3-e4-bucket-measurement-plan-model"
MODEL=P5AR3E4BucketMeasurementPlan.tla
SAFE_CFG=P5AR3E4BucketMeasurementPlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement-plan/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command_name in awk diff find git grep java jq sed sha256sum sort tail tr wc; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
jq empty "$CONFIG"

jq -e '
  .status == "r3_e4_bucket_measurement_pre_source_plan" and
  .prerequisite.e3_status == "passed_four_boot_diagnostic_matrix" and
  .prerequisite.synthetic_protocol_passed == true and
  .prerequisite.real_scheduler_attachment == false and
  .prerequisite.production_ready == false and
  .source.direct_child_required == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source.frozen_files == ["include/linux/sched.h","include/linux/sched_exec_lease.h","kernel/sched/Makefile","kernel/sched/sched.h","kernel/sched/fair.c","kernel/sched/core.c"] and
  .source.e2_layout_and_43_values_preserved == true and
  .source.e3_suite_and_20_cases_preserved == true and
  .source.same_helper_required_for_e3_worker_and_e4_measurement == true and
  .source.timing_only_substitute_allowed == false and
  .source.primary_change_allowed == false and .source.patch_queue_change_allowed == false and
  .configuration.name == "SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST" and
  .configuration.type == "bool" and .configuration.default_enabled == false and
  .configuration.direct_dependencies == ["SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST","KUNIT=y"] and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_bucket_measure" and
  ([.configuration.selected_by_ordinary_lease,.configuration.selected_by_layout_probe,.configuration.selected_by_e3_test,.configuration.selected_by_kunit_all_tests,.configuration.makefile_or_header_change_allowed] | all(. == false)) and
  .configuration.disabled_symbols_relocations_strings_required == 0 and
  ([.fixture.real_private_bucket_projection_rq_state,.fixture.real_struct_rq_lock,.fixture.real_outer_rb_operations,.fixture.synthetic_outer_entities_and_inner_runnable_state,.fixture.real_e3_unbound_workqueue_protocol,.fixture.all_storage_preallocated,.fixture.untimed_oracle_check_per_cell] | all(. == true)) and
  ([.fixture.registered_with_live_scheduler,.fixture.task_or_cgroup_attachment,.fixture.live_picker_hotplug_migration_call,.fixture.policy_monitor_or_denial_decision,.fixture.ordinary_scheduler_state_modified] | all(. == false)) and
  .common_interval.clock == "local_clock" and
  ([.common_interval.local_irq_save_restore,.common_interval.raw_spin_rq_lock_unlock,.common_interval.at_most_one_membership_lock,.common_interval.paired_empty_control,.common_interval.same_membership_lock_in_control,.common_interval.alternating_pair_order,.common_interval.sort_after_irq_restore,.common_interval.nearest_rank_documented] | all(. == true)) and
  .common_interval.additional_formula == "max(treatment_ns-control_ns,0)" and
  .common_interval.minimum_warmup_pairs_per_cell == 256 and .common_interval.measured_pairs_per_cell == 10000 and
  .common_interval.statistics == ["minimum","p50","p95","p99","p999","maximum"] and
  .common_interval.allocation_free_sort_print_trace_sleep_reschedule_topology_policy_monitor_inside_interval == false and
  .common_interval.second_rq_lock_inside_interval == false and
  .one_projection.bucket_occupancy == [1,8,32,64] and .one_projection.inner_runnable == [0,1,64,4096] and
  .one_projection.generation_outcomes == ["stable","raced"] and .one_projection.cell_count == 32 and
  .one_projection.one_outer_layer == true and .one_projection.one_projection_or_entity_updated_max == 1 and
  .one_projection.leaf_or_hierarchy_scan == false and .one_projection.all_bucket_loop == false and
  .one_projection.inner_runnable_changes_algorithmic_work == false and
  .one_projection.acquire_read_generation_and_state == true and .one_projection.fresh_only_after_stable_final_read == true and
  .one_projection.raced_leaves_stale_and_requeues_one == true and .one_projection.raced_control_performs_same_injection == true and
  .one_projection.additional_p99_limit_ns == 5000 and .one_projection.additional_p999_limit_ns == 25000 and
  .one_projection.additional_max_limit_ns == 50000 and .one_projection.normalized_base_slice_ns == 700000 and
  .one_projection.sample_may_reach_base_slice == false and
  .hotplug.occupancy == [0,1,8,32,64] and .hotplug.cell_count == 5 and
  .hotplug.clears_accepting_first == true and .hotplug.bounded_visits_max == 64 and
  .hotplug.one_membership_lock_at_a_time == true and .hotplug.all_contribution_classes_accounted == ["queued","delayed","current"] and
  .hotplug.nonzero_residual_retained_blocked == true and .hotplug.cancel_or_rcu_wait_under_rq_lock == false and
  .hotplug.additional_p99_limit_ns == 25000 and .hotplug.additional_max_limit_ns == 50000 and .hotplug.normalized_base_slice_ns == 700000 and
  .fanout.active_rqs == [1,2,8,32,64] and .fanout.cell_count == 5 and
  ([.fanout.fresh_active_rq_snapshot,.fanout.existing_work_owner_before_queue,.fanout.queue_after_membership_unlock,.fanout.unbound_work,.fanout.paired_dispatch_completion_control,.fanout.availability_not_trust_gate,.fanout.generation_mismatch_fails_closed] | all(. == true)) and
  .fanout.all_online_rq_scan == false and .fanout.cpu_bound_work == false and
  .fanout.gate_statistic == "absolute_publication_to_last_settlement" and
  .fanout.p99_limit_ns == 10000000 and .fanout.max_limit_ns == 100000000 and
  .matrix.total_cell_count == 42 and .matrix.all_cells_required == true and
  .matrix.range_reduction_after_failure_allowed == false and .matrix.result_row_per_cell_required == true and
  .diagnostics.architectures == ["arm64","x86_64"] and .diagnostics.same_source_identity_required == true and
  .diagnostics.disabled_and_enabled_builds_per_architecture == true and .diagnostics.e3_suite_rerun_required == true and
  .diagnostics.measurement_options == ["KUNIT","PROVE_LOCKING","DEBUG_OBJECTS_WORK","PROVE_RCU"] and
  .diagnostics.record_environment_compiler_config_object_image_qemu_console_ktap == true and
  .diagnostics.warning_reports_allowed == 0 and (.diagnostics.warning_classes | length) == 10 and
  .diagnostics.virtual_result_supports_bare_metal_claim == false and
  .classification.valid_results == ["passed_r3_e4_architecture_measurement","rejected_r3_bucket_measurement"] and
  .classification.invalid_result == "harness_failed" and .classification.threshold_failure_is_valid_negative_evidence == true and
  .classification.missing_or_malformed_evidence_is_harness_failure == true and
  .classification.two_architecture_same_source_required_for_e4_compatibility_pass == true and
  .classification.e5_plan_only_after_two_architecture_pass == true and .classification.e5_source_authorized == false and
  .cross_path.ordinary_cfs_test_scope_only == true and (.cross_path.uncovered | length) == 12 and
  .cross_path.e5_requires_integrate_or_explicitly_exclude == true and
  (.source_anchors | length) == 30 and (.future_absence_checks | length) == 6 and
  (.formal.unsafe_faults | length) == 40 and .formal.unsafe_expected_counterexamples == 40 and
  .authorization_after_plan_pass.e4_disposable_worktree_may_be_created == true and
  .authorization_after_plan_pass.e4_exact_two_file_source_draft_may_be_created == true and
  .authorization_after_plan_pass.e4_measurement_may_start_before_source_gate == false and
  .authorization_after_plan_pass.e4_measurement_accepted == false and
  .authorization_after_plan_pass.e5_plan_may_start == false and .authorization_after_plan_pass.e5_source_may_start == false and
  .authorization_after_plan_pass.primary_linux_may_change == false and .authorization_after_plan_pass.patch_queue_may_change == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_primary=$(jq -r '.source.primary_commit' "$CONFIG")
expected_e2=$(jq -r '.source.e2_candidate_commit' "$CONFIG")
expected_e3=$(jq -r '.source.e3_candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.e3_candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.e3_candidate_diff_sha256' "$CONFIG")

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$expected_e3" ] || die 'E3 candidate moved'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] || die 'E3 tree moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$expected_e2" ] || die 'E3 parent moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 candidate dirty'

git -C "$E3_DIR" diff "$expected_e2..$expected_e3" > "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = "$expected_diff" ] || die 'E3 diff moved'

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = "$(jq -r '.source.patch_queue_commit' "$CONFIG")" ] || die 'patch queue commit moved'
series=patches/capsched-linux-l0/series
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse "HEAD:$series")" = "$(jq -r '.source.patch_queue_series_blob' "$CONFIG")" ] || die 'patch queue series HEAD moved'
[ "$(git -C "$PATCH_QUEUE_DIR" hash-object "$series")" = "$(jq -r '.source.patch_queue_series_blob' "$CONFIG")" ] || die 'patch queue series working content moved'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/$series")" = "$(jq -r '.source.patch_queue_tail' "$CONFIG")" ] || die 'patch queue tail moved'

e3_result="$WORKSPACE_DIR/$(jq -r '.prerequisite.e3_result' "$CONFIG")"
e3_hash=$(sha256sum "$e3_result" | awk '{print $1}')
[ "$e3_hash" = "$(jq -r '.prerequisite.e3_result_sha256' "$CONFIG")" ] || die 'E3 result hash mismatch'
jq -e --arg e3 "$expected_e3" --arg tree "$expected_tree" --arg parent "$expected_e2" '
  .status == "passed_four_boot_diagnostic_matrix" and
  .candidate_commit == $e3 and .candidate_tree == $tree and .candidate_parent == $parent and
  .architectures == ["arm64","x86_64"] and (.qemu_boots | length) == 4 and
  .required_cases == 20 and .passed_cases_per_boot == 20 and
  .failed_cases == 0 and .skipped_cases == 0 and .timeouts == 0 and .warning_reports == 0 and
  .synthetic_protocol_diagnostic_matrix_passed == true and
  .real_scheduler_attachment == false and .production_ready == false
' "$e3_result" >/dev/null

anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchor_ledger"
while IFS='|' read -r id path pattern; do
	if grep -Fq "$pattern" "$E3_DIR/$path"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$anchor_ledger"
done < <(jq -r '.source_anchors[] | [.id,.path,.pattern] | join("|")' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" { count++ } END { print count+0 }' "$anchor_ledger")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence.tsv"
printf 'status\tpath\tpattern\n' > "$absence_ledger"
while IFS='|' read -r path pattern; do
	if grep -Fq "$pattern" "$E3_DIR/$path"; then status=present; else status=absent; fi
	printf '%s\t%s\t%s\n' "$status" "$path" "$pattern" >> "$absence_ledger"
done < <(jq -r '.future_absence_checks[] | [.path,.pattern] | join("|")' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $1 != "absent" { count++ } END { print count+0 }' "$absence_ledger")
[ "$absence_failures" = 0 ] || die "future absence failures: $absence_failures"

e3_case_count=$(sed -n '/static struct kunit_case sched_exec_bucket_test_cases\[\] = {/,/};/p' "$E3_DIR/kernel/sched/exec_lease.c" | grep -c 'KUNIT_CASE(')
[ "$e3_case_count" = 20 ] || die "E3 case count moved: $e3_case_count"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
unsafe_index=0
while IFS= read -r fault; do
	unsafe_index=$((unsafe_index + 1))
	cfg="$OUT_DIR/generated-unsafe-configs/unsafe-$unsafe_index-$fault.cfg"
	log="$OUT_DIR/tlc-unsafe-$unsafe_index-$fault.log"
	printf 'SPECIFICATION Spec\nCONSTANT Fault = "%s"\nINVARIANT Safety\n' "$fault" > "$cfg"
	if (cd "$MODEL_DIR" && java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/states-unsafe-$unsafe_index-$fault" -config "$cfg" "$MODEL") > "$log" 2>&1; then
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$unsafe_expected" = 40 ] || die "unsafe TLC count: $unsafe_expected"

jq -n \
	--arg run_id "$RUN_ID" --arg e3_result_sha256 "$e3_hash" \
	--arg primary "$expected_primary" --arg e2 "$expected_e2" --arg e3 "$expected_e3" \
	--arg tree "$expected_tree" --arg diff "$expected_diff" \
	--argjson anchors "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" --argjson e3_case_count "$e3_case_count" \
	--argjson safe_states "${safe_states:-0}" --argjson safe_distinct "${safe_distinct:-0}" \
	--argjson safe_depth "${safe_depth:-0}" --argjson unsafe "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_r3_e4_plan_only",e3_result_sha256:$e3_result_sha256,primary_commit:$primary,e2_candidate_commit:$e2,e3_candidate_commit:$e3,e3_candidate_tree:$tree,e3_candidate_diff_sha256:$diff,source_anchor_count:$anchors,source_anchor_failures:$anchor_failures,future_absence_failures:$absence_failures,e3_case_count:$e3_case_count,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe,allowed_files:["init/Kconfig","kernel/sched/exec_lease.c"],matrix:{one_projection_cells:32,hotplug_cells:5,fanout_cells:5,total_cells:42,measured_pairs_per_cell:10000},gates_ns:{one_projection:{p99:5000,p999:25000,max:50000},hotplug:{p99:25000,max:50000},fanout:{p99:10000000,max:100000000},normalized_base_slice:700000},e4_disposable_worktree_may_be_created:true,e4_source_draft_may_be_created:true,e4_measurement_may_start_before_source_gate:false,e4_measurement_accepted:false,e5_plan_may_start:false,e5_source_may_start:false,real_scheduler_attachment:false,primary_linux_change_approved:false,patch_queue_change_approved:false,runtime_behavior_approved:false,production_protection:false,bare_metal_latency_claim:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
