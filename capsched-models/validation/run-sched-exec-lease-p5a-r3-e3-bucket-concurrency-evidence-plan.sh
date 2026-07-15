#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0133-p5a-r3-e3-bucket-concurrency-evidence-plan-model"
MODEL=P5AR3E3BucketConcurrencyEvidencePlan.tla
SAFE_CFG=P5AR3E3BucketConcurrencyEvidencePlanSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan/$RUN_ID"

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
mkdir -p "$OUT_DIR/generated-unsafe-configs"
jq empty "$CONFIG"

jq -e '
  .status == "r3_e3_bucket_concurrency_pre_source_plan" and
  .source_basis.rejected_r2_line_is_parent == false and
  .source_boundary.future_parent == .source_basis.e2_candidate_commit and
  .source_boundary.direct_child_required == true and
  .source_boundary.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source_boundary.frozen_files == ["include/linux/sched.h","include/linux/sched_exec_lease.h","kernel/sched/Makefile","kernel/sched/sched.h","kernel/sched/fair.c","kernel/sched/core.c","kernel/sched/exec_lease_layout_probe.c"] and
  .source_boundary.e2_private_type_block_must_be_preserved == true and
  .source_boundary.e2_private_probe_values_preserved == 43 and
  .source_boundary.existing_expanded_probe_values_preserved == 51 and
  ([.source_boundary.ordinary_sched_entity_delta_bytes,.source_boundary.ordinary_cfs_rq_delta_bytes,.source_boundary.ordinary_rq_delta_bytes,.source_boundary.ordinary_task_struct_delta_bytes] | all(. == 0)) and
  ([.source_boundary.strict_checkpatch_errors_allowed,.source_boundary.strict_checkpatch_warnings_allowed,.source_boundary.strict_checkpatch_checks_allowed] | all(. == 0)) and
  ([.source_boundary.primary_linux_change_allowed,.source_boundary.patch_queue_change_allowed,.source_boundary.e2_candidate_amend_allowed] | all(. == false)) and
  .configuration.name == "SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST" and
  .configuration.type == "bool" and
  .configuration.default_enabled == false and
  .configuration.direct_dependencies == ["SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE","KUNIT=y"] and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_bucket" and
  ([.configuration.selected_by_ordinary_lease,.configuration.selected_by_layout_probe,.configuration.selected_by_kunit_all_tests,.configuration.makefile_change_allowed,.configuration.header_change_allowed] | all(. == false)) and
  .configuration.disabled_symbols_relocations_strings_required == 0 and
  ([.prototype_scope.uses_e2_private_types,.prototype_scope.synthetic_rq_identifiers,.prototype_scope.real_membership_lock,.prototype_scope.real_refcount,.prototype_scope.real_cpumask_var,.prototype_scope.real_xarray,.prototype_scope.real_workqueue,.prototype_scope.real_rcu_callbacks] | all(. == true)) and
  ([.prototype_scope.real_rq_or_cfs_attachment,.prototype_scope.real_task_or_cgroup_attachment,.prototype_scope.real_picker_connection,.prototype_scope.real_publisher_registry,.prototype_scope.real_hotplug_hook,.prototype_scope.monitor_or_policy_call,.prototype_scope.capability_or_denial_decision,.prototype_scope.full_leaf_rebuild,.prototype_scope.leaf_scan,.prototype_scope.export_static_key_trace_debug_user_abi] | all(. == false)) and
  .capacity_and_allocation.b_max_per_rq == 64 and
  .capacity_and_allocation.accepted_cases == [0,1,63,64] and
  .capacity_and_allocation.rejected_cases == [65] and
  .capacity_and_allocation.slot_before_first_contribution == true and
  .capacity_and_allocation.projection_before_first_contribution == true and
  .capacity_and_allocation.failure_errno == "-ENOMEM" and
  .capacity_and_allocation.failure_leaves_partial_state == false and
  .capacity_and_allocation.retry_after_failure_required == true and
  .capacity_and_allocation.allocation_under_rq_or_membership_lock == false and
  .capacity_and_allocation.overflow_evicts_or_merges == false and
  .capacity_and_allocation.overflow_falls_back == false and
  .capacity_and_allocation.allocation_fault_sites == ["workqueue_create","bucket_control","active_rq_cpumask","rq_state","projection","xarray_reserve"] and
  (.capacity_and_allocation.failure_zero_assertions | length) == 9 and
  .locking.mutation_order == "synthetic_rq_then_at_most_one_raw_membership_lock" and
  .locking.publisher_membership_lock_only == true and
  .locking.publisher_takes_rq_lock == false and
  .locking.publisher_releases_before_queue_work == true and
  .locking.worker_updates_one_projection_under_one_rq_lock == true and
  .locking.worker_releases_rq_before_membership_settlement == true and
  ([.locking.two_membership_locks_held,.locking.reverse_membership_to_rq_order,.locking.queue_work_under_any_test_lock,.locking.cancel_work_sync_under_any_test_lock,.locking.allocation_or_free_under_any_test_lock] | all(. == false)) and
  .publication_work.dedicated_workqueue == true and
  .publication_work.workqueue_flags == ["WQ_UNBOUND","WQ_HIGHPRI","WQ_MEM_RECLAIM"] and
  ([.publication_work.fresh_active_rq_snapshot_every_generation,.publication_work.desired_generation_coalesced_under_membership_lock,.publication_work.one_work_owner_per_projection,.publication_work.work_ref_acquired_before_queue,.publication_work.queue_false_pending_has_live_owner,.publication_work.queue_false_running_has_live_owner,.publication_work.worker_rechecks_desired_after_rq_unlock,.publication_work.worker_clear_vs_republish_serialized,.publication_work.requeue_outside_locks] | all(. == true)) and
  .publication_work.stale_worker_marks_new_generation_fresh == false and
  .publication_work.generation_zero_valid == false and
  .publication_work.generation_saturation_value == "U64_MAX" and
  .publication_work.generation_saturation_state == "Blocked" and
  .publication_work.generation_wrap_reuse == false and
  .contribution_oracle.classes == ["queued","delayed","current"] and
  .contribution_oracle.active_bit_iff_total_nonzero == true and
  .contribution_oracle.rq_active_projection_count_exact == true and
  .contribution_oracle.independent_plain_record_representation == true and
  ([.contribution_oracle.shares_transition_helper,.contribution_oracle.shares_ref_helper,.contribution_oracle.shares_mask_helper,.contribution_oracle.shares_generation_helper,.contribution_oracle.shares_work_helper] | all(. == false)) and
  .contribution_oracle.checks_every_forced_schedule == true and
  .contribution_oracle.checks_after_failed_assertion_during_cleanup == true and
  (.contribution_oracle.reference_classes | length) == 5 and
  .migration.protocol == "remove_neutral_add" and
  .migration.source_total_zero_before_active_clear == true and
  .migration.oracle_visible_neutral_state == true and
  .migration.destination_preallocated_before_add == true and
  .migration.destination_capacity_failure_fails_closed == true and
  .migration.destination_failure_restores_unverified_source == false and
  .migration.partial_destination_contribution == false and
  .cpu_hotplug.online_initializes_before_accepting == true and
  .cpu_hotplug.offline_clears_accepting_first == true and
  .cpu_hotplug.offline_visits_at_most_b_max == 64 and
  .cpu_hotplug.offline_settles_all_contribution_classes == true and
  .cpu_hotplug.offline_clears_membership_only_at_zero == true and
  .cpu_hotplug.unbound_work_not_stranded == true and
  .cpu_hotplug.publication_worker_offline_interleavings_forced == true and
  ([.retirement.retiring_blocks_new_work_ownership,.retirement.rcu_unpublish_before_drain,.retirement.task_and_contribution_refs_zero_before_free,.retirement.cancel_each_sparse_projection,.retirement.cancel_work_sync_outside_locks,.retirement.canceled_owner_settled_under_membership_lock,.retirement.racing_enqueue_disabled_before_cancel,.retirement.active_mask_and_xarray_empty_before_free,.retirement.projection_free_after_work_drain,.retirement.pre_unpublish_readers_exit_before_free,.retirement.bucket_free_after_rcu_grace,.retirement.workqueue_destroy_after_all_buckets] | all(. == true)) and
  .retirement.cancel_work_sync_is_revocation_receipt == false and
  .retirement.cancel_cases == ["pending_before_run","running","running_requires_requeue"] and
  (.required_case_families | length) == 20 and
  .race_control.completion_or_barrier_forced == true and
  .race_control.timing_sleep_as_proof == false and
  .race_control.hard_timeout_seconds == 5 and
  .race_control.stress_iterations_per_diagnostic_boot == 1024 and
  (.race_control.required_stress_families | length) == 4 and
  .race_control.required_failure_count == 0 and
  .race_control.required_skip_count == 0 and
  .race_control.matrix_reduction_after_failure == false and
  .build_and_boot_matrix.architectures == ["arm64","x86_64"] and
  (.build_and_boot_matrix.modes_per_architecture | length) == 4 and
  .build_and_boot_matrix.disabled_e3_symbols_relocations_strings == 0 and
  .build_and_boot_matrix.enabled_existing_values_preserved == 51 and
  .build_and_boot_matrix.enabled_private_values_preserved == 43 and
  .build_and_boot_matrix.ordinary_structure_growth_bytes == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .build_and_boot_matrix.qemu_boots == ["arm64_standard_debug","x86_64_standard_debug","arm64_generic_kasan","x86_64_kcsan"] and
  .build_and_boot_matrix.standard_debug_options == ["KUNIT","PROVE_LOCKING","DEBUG_OBJECTS_WORK","PROVE_RCU"] and
  .build_and_boot_matrix.kasan_mode == "arm64_generic_kasan" and
  .build_and_boot_matrix.kcsan_mode == "x86_64_kcsan" and
  .build_and_boot_matrix.suite_filter_exact == "sched_exec_lease_bucket" and
  ([.build_and_boot_matrix.required_case_failures_allowed,.build_and_boot_matrix.required_case_skips_allowed,.build_and_boot_matrix.required_timeouts_allowed,.build_and_boot_matrix.warning_reports_allowed] | all(. == 0)) and
  .build_and_boot_matrix.record_compiler_config_image_object_qemu_ktap_console == true and
  (.warning_rejection_patterns | length) == 11 and
  (.source_hash_paths | length) == 25 and
  (.source_anchors | length) == 58 and
  (.future_absence_checks | length) == 10 and
  (.formal.unsafe_faults | length) == 51 and
  .formal.unsafe_expected_counterexamples == 51 and
  .authorization_after_pass.r3_e3_disposable_worktree_may_be_created == true and
  .authorization_after_pass.r3_e3_exact_two_file_source_draft_may_be_created == true and
  .authorization_after_pass.r3_e3_source_accepted == false and
  .authorization_after_pass.r3_e3_concurrency_correctness_accepted == false and
  .authorization_after_pass.r3_e4_plan_may_be_drafted == false and
  .authorization_after_pass.r3_e4_source_may_be_created == false and
  .authorization_after_pass.primary_linux_may_change == false and
  .authorization_after_pass.patch_queue_may_change == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

expected_primary=$(jq -r '.source_basis.primary_linux_commit' "$CONFIG")
expected_primary_tree=$(jq -r '.source_basis.primary_linux_tree' "$CONFIG")
expected_candidate=$(jq -r '.source_basis.e2_candidate_commit' "$CONFIG")
expected_parent=$(jq -r '.source_basis.e2_candidate_parent' "$CONFIG")
expected_candidate_tree=$(jq -r '.source_basis.e2_candidate_tree' "$CONFIG")
expected_candidate_diff=$(jq -r '.source_basis.e2_candidate_diff_sha256' "$CONFIG")

primary_commit=$(git -C "$PRIMARY_DIR" rev-parse HEAD)
primary_tree=$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')
candidate_commit=$(git -C "$CANDIDATE_DIR" rev-parse HEAD)
candidate_parent=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)
candidate_tree=$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')
[ "$primary_commit" = "$expected_primary" ] || die "primary moved: $primary_commit"
[ "$primary_tree" = "$expected_primary_tree" ] || die "primary tree moved: $primary_tree"
[ "$candidate_commit" = "$expected_candidate" ] || die "E2 candidate moved: $candidate_commit"
[ "$candidate_parent" = "$expected_parent" ] || die "E2 candidate parent moved: $candidate_parent"
[ "$candidate_tree" = "$expected_candidate_tree" ] || die "E2 candidate tree moved: $candidate_tree"

git -C "$CANDIDATE_DIR" diff --name-only "$expected_parent..$expected_candidate" > "$OUT_DIR/e2-delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-e2-delta-files.txt"
diff -u "$OUT_DIR/expected-e2-delta-files.txt" "$OUT_DIR/e2-delta-files.txt" > "$OUT_DIR/e2-delta-files.diff" \
	|| die 'E2 candidate escaped exact two-file scope'
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" > "$OUT_DIR/e2-candidate.diff"
candidate_diff=$(sha256sum "$OUT_DIR/e2-candidate.diff" | awk '{print $1}')
[ "$candidate_diff" = "$expected_candidate_diff" ] || die "E2 candidate diff moved: $candidate_diff"

e2_closure="$WORKSPACE_DIR/$(jq -r '.source_basis.e2_closure_result' "$CONFIG")"
e2_dual="$WORKSPACE_DIR/$(jq -r '.source_basis.e2_dual_arch_result' "$CONFIG")"
e2_closure_sha=$(sha256sum "$e2_closure" | awk '{print $1}')
e2_dual_sha=$(sha256sum "$e2_dual" | awk '{print $1}')
[ "$e2_closure_sha" = "$(jq -r '.source_basis.e2_closure_result_sha256' "$CONFIG")" ] \
	|| die "E2 closure hash moved: $e2_closure_sha"
[ "$e2_dual_sha" = "$(jq -r '.source_basis.e2_dual_arch_result_sha256' "$CONFIG")" ] \
	|| die "E2 dual-arch hash moved: $e2_dual_sha"
jq -e '
  .status == "passed_for_e3_planning_only" and
  .input_contract_sha256 == "3ea7b3142e74007858d453e35481f7908ed9e4369430be60611bbbf21c5826bf" and
  .primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .candidate_commit == "63313b329e1d44901acfce30698613c38615c8d5" and
  .candidate_tree == "8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb" and
  .exact_direct_child == true and
  .exact_two_file_scope == true and
  .source_files_match_head == true and
  .architectures == ["arm64","x86_64"] and
  .existing_probe_value_changes_per_architecture == 0 and
  .private_disabled_symbol_count == 0 and
  .private_disabled_relocation_count == 0 and
  .private_disabled_string_count == 0 and
  .ordinary_scheduler_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .private_memory_envelope_passed == true and
  .dual_arch_e2_complete == true and
  .e3_plan_may_start == true and
  .e3_source_may_start == false and
  .separate_e3_plan_required == true and
  .primary_linux_changed == false and
  .patch_queue_changed == false
' "$e2_closure" >/dev/null

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = "$(jq -r '.source_basis.patch_queue_commit' "$CONFIG")" ] \
	|| die "patch queue commit moved: $patch_queue_commit"
series=patches/capsched-linux-l0/series
series_head_blob=$(git -C "$PATCH_QUEUE_DIR" rev-parse "HEAD:$series")
series_working_blob=$(git -C "$PATCH_QUEUE_DIR" hash-object "$series")
[ "$series_head_blob" = "$(jq -r '.source_basis.patch_queue_series_blob' "$CONFIG")" ] \
	|| die "patch queue series HEAD moved: $series_head_blob"
[ "$series_working_blob" = "$series_head_blob" ] || die 'patch queue series working content moved'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/$series")" = "$(jq -r '.source_basis.patch_queue_tail' "$CONFIG")" ] \
	|| die 'patch queue tail moved'

source_manifest="$OUT_DIR/source-file-hashes.tsv"
printf 'path\texpected_blob\tworking_blob\n' > "$source_manifest"
while IFS= read -r path; do
	expected_blob=$(git -C "$CANDIDATE_DIR" rev-parse "HEAD:$path")
	working_blob=$(git -C "$CANDIDATE_DIR" hash-object "$path")
	printf '%s\t%s\t%s\n' "$path" "$expected_blob" "$working_blob" >> "$source_manifest"
	[ "$working_blob" = "$expected_blob" ] || die "candidate source differs from HEAD: $path"
done < <(jq -r '.source_hash_paths[]' "$CONFIG")
source_manifest_count=$(($(wc -l < "$source_manifest") - 1))
[ "$source_manifest_count" = 25 ] || die "source manifest count: $source_manifest_count"
source_manifest_sha=$(sha256sum "$source_manifest" | awk '{print $1}')

anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchor_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	relative_path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	file="$WORKSPACE_DIR/$relative_path"
	if [ -f "$file" ] && grep -Fq "$pattern" "$file"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$relative_path" "$pattern" >> "$anchor_ledger"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {count++} END {print count+0}' "$anchor_ledger")
[ "$anchor_count" = 58 ] || die "source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence_ledger="$OUT_DIR/future-absence-checks.tsv"
printf 'id\tstatus\tpattern\n' > "$absence_ledger"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$CANDIDATE_DIR" grep -Fq "$pattern" -- include/linux init/Kconfig kernel/sched; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$id" "$status" "$pattern" >> "$absence_ledger"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {count++} END {print count+0}' "$absence_ledger")
[ "$absence_count" = 10 ] || die "absence count: $absence_count"
[ "$absence_failures" = 0 ] || die "future absence failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" -config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
	|| die 'safe TLC model did not pass'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
while IFS= read -r fault; do
	name="P5AR3E3BucketConcurrencyEvidencePlanUnsafe${fault}"
	cfg="$OUT_DIR/generated-unsafe-configs/$name.cfg"
	log="$OUT_DIR/tlc-$name.log"
	printf 'SPECIFICATION Spec\nCONSTANT Fault = "%s"\nINVARIANT Safety\n' "$fault" > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" -config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe fault unexpectedly passed: %s\n' "$fault" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		printf 'unsafe fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 40 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$unsafe_expected" = 51 ] || die "unsafe counterexample count: $unsafe_expected"

config_sha=$(sha256sum "$CONFIG" | awk '{print $1}')
model_sha=$(sha256sum "$MODEL_DIR/$MODEL" | awk '{print $1}')
tla_jar_sha=$(sha256sum "$TLA_JAR" | awk '{print $1}')
case_family_count=$(jq '.required_case_families | length' "$CONFIG")
allocation_fault_site_count=$(jq '.capacity_and_allocation.allocation_fault_sites | length' "$CONFIG")
qemu_boot_count=$(jq '.build_and_boot_matrix.qemu_boots | length' "$CONFIG")

jq -n \
	--arg run_id "$RUN_ID" \
	--arg config "$CONFIG" --arg config_sha "$config_sha" \
	--arg model "$MODEL_DIR/$MODEL" --arg model_sha "$model_sha" \
	--arg tla_jar "$TLA_JAR" --arg tla_jar_sha "$tla_jar_sha" \
	--arg primary_commit "$primary_commit" --arg primary_tree "$primary_tree" \
	--arg candidate_commit "$candidate_commit" --arg candidate_parent "$candidate_parent" --arg candidate_tree "$candidate_tree" --arg candidate_diff "$candidate_diff" \
	--arg patch_queue_commit "$patch_queue_commit" --arg patch_queue_series_blob "$series_working_blob" \
	--arg e2_closure "$e2_closure" --arg e2_closure_sha "$e2_closure_sha" --arg e2_dual "$e2_dual" --arg e2_dual_sha "$e2_dual_sha" \
	--arg source_manifest "$source_manifest" --arg source_manifest_sha "$source_manifest_sha" \
	--argjson source_manifest_count "$source_manifest_count" --argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_count "$absence_count" --argjson absence_failures "$absence_failures" \
	--argjson safe_states "${safe_states:-0}" --argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" --argjson case_family_count "$case_family_count" \
	--argjson allocation_fault_site_count "$allocation_fault_site_count" --argjson qemu_boot_count "$qemu_boot_count" \
	'{
	  schema_version:1,
	  run_id:$run_id,
	  status:"passed_r3_e3_plan_only",
	  config:$config,
	  config_sha256:$config_sha,
	  model:$model,
	  model_sha256:$model_sha,
	  tla_jar:$tla_jar,
	  tla_jar_sha256:$tla_jar_sha,
	  primary_linux_commit:$primary_commit,
	  primary_linux_tree:$primary_tree,
	  e2_candidate_commit:$candidate_commit,
	  e2_candidate_parent:$candidate_parent,
	  e2_candidate_tree:$candidate_tree,
	  e2_candidate_diff_sha256:$candidate_diff,
	  exact_e2_direct_child:true,
	  exact_future_two_file_scope:true,
	  patch_queue_commit:$patch_queue_commit,
	  patch_queue_series_blob:$patch_queue_series_blob,
	  patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",
	  e2_closure_result:$e2_closure,
	  e2_closure_result_sha256:$e2_closure_sha,
	  e2_dual_arch_result:$e2_dual,
	  e2_dual_arch_result_sha256:$e2_dual_sha,
	  source_file_hash_manifest:$source_manifest,
	  source_file_hash_manifest_sha256:$source_manifest_sha,
	  source_file_hash_count:$source_manifest_count,
	  source_files_match_head:true,
	  source_anchor_count:$anchor_count,
	  source_anchor_failures:$anchor_failures,
	  future_absence_check_count:$absence_count,
	  future_absence_check_failures:$absence_failures,
	  safe_passed:true,
	  safe_states_generated:$safe_states,
	  safe_distinct_states:$safe_distinct,
	  safe_depth:$safe_depth,
	  unsafe_expected_counterexamples:$unsafe_expected,
	  b_max_cases:[0,1,63,64,65],
	  required_case_family_count:$case_family_count,
	  allocation_fault_site_count:$allocation_fault_site_count,
	  diagnostic_qemu_boot_count:$qemu_boot_count,
	  architectures:["arm64","x86_64"],
	  diagnostics:["KUnit","KASAN","KCSAN","lockdep","DEBUG_OBJECTS_WORK","PROVE_RCU"],
	  allowed_files:["init/Kconfig","kernel/sched/exec_lease.c"],
	  r3_e3_disposable_worktree_may_be_created:true,
	  r3_e3_exact_two_file_source_draft_may_be_created:true,
	  r3_e3_source_accepted:false,
	  r3_e3_concurrency_correctness_accepted:false,
	  r3_e4_plan_may_be_drafted:false,
	  r3_e4_source_may_be_created:false,
	  primary_linux_change_approved:false,
	  patch_queue_change_approved:false,
	  runtime_scheduler_hook_approved:false,
	  runtime_behavior_approved:false,
	  runtime_denial_correctness:false,
	  monitor_delivery_or_enforcement:false,
	  cross_class_coverage:false,
	  bounded_latency_claim:false,
	  performance_claim:false,
	  cost_claim:false,
	  production_protection:false,
	  deployment_ready:false,
	  datacenter_ready:false
	}' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
