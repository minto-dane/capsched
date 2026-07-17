#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-e4-lock-hold-measurement-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0130-p5a-r2-e4-lock-hold-measurement-plan-model"
MODEL=P5AR2E4LockHoldMeasurementPlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-measurement-plan/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
for cmd in awk find git grep java jq sed sha256sum wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_primary=$(jq -r '.source.primary_commit' "$CONFIG")
expected_e2=$(jq -r '.source.e2_candidate_commit' "$CONFIG")
expected_e3=$(jq -r '.source.e3_candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.e3_candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.e3_candidate_diff_sha256' "$CONFIG")

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$expected_e3" ] || die 'E3 candidate moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^{tree})" = "$expected_tree" ] || die 'E3 tree moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$expected_e2" ] || die 'E3 parent moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 candidate dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = \
	'0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'

git -C "$E3_DIR" diff "$expected_e2..$expected_e3" > "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = "$expected_diff" ] || die 'E3 diff changed'

e3_result="$WORKSPACE_DIR/$(jq -r '.prerequisite.result' "$CONFIG")"
e3_hash=$(sha256sum "$e3_result" | awk '{print $1}')
[ "$e3_hash" = "$(jq -r '.prerequisite.result_sha256' "$CONFIG")" ] || die 'E3 result hash mismatch'
jq -e '
  .status == "passed_e3_rebuild_prototype" and
  .source_commit == "d1d5e78da8484c91eae70f22399c6901da680ea0" and
  .source_tree == "aa6a5a3848415643f3b67434964b056e30421bb2" and
  .source_diff_sha256 == "a5351bbdd7a6617382bdea5ca9a7546e3defd97bd4a08c9c6ccf53390a88b4ed" and
  .qemu.suite_passed == true and .qemu.case_count == 12 and
  .qemu.failed_cases == 0 and .qemu.skipped_required_cases == 0 and
  .e3_source_accepted_for_disposable_correctness_evidence == true and
  .e3_rebuild_correctness_accepted_for_synthetic_fixtures == true and
  .e4_measurement_may_be_planned == true and
  .production_layout_accepted == false and .performance_claim == false
' "$e3_result" >/dev/null

jq -e '
  .status == "e4_lock_hold_measurement_pre_source_plan" and
  .source.allowed_files == ["init/Kconfig","kernel/sched/fair.c"] and
  ([.source.primary_change_allowed,.source.patch_queue_change_allowed,.source.e2_field_change_allowed,.source.e3_rebuild_change_allowed] | all(. == false)) and
  .configuration.name == "SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST" and
  .configuration.type == "bool" and .configuration.default_enabled == false and
  .configuration.depends_on_e3_rebuild_test == true and .configuration.depends_on_builtin_kunit == true and
  .configuration.selected_by_ordinary_lease == false and .configuration.selected_by_kunit_all_tests == false and
  .configuration.same_translation_unit == "kernel/sched/fair.c" and
  .configuration.suite_name == "sched_exec_lease_rebuild_measure" and .configuration.makefile_change_allowed == false and
  ([.fixture.real_rq_cfs_rq_sched_entity_structures,.fixture.real_rb_and_bottom_up_iterators,.fixture.real_irq_disabled_rq_lock,.fixture.all_allocation_before_measurement,.fixture.o1_container_leaf_callback,.fixture.untimed_correctness_and_visit_check_per_cell] | all(. == true)) and
  .fixture.registered_with_live_scheduler == false and .fixture.e3_linear_search_callback_allowed_in_timing == false and .fixture.topology_mutation_during_samples == false and
  .interval.clock == "local_clock" and
  ([.interval.local_irq_save_restore,.interval.raw_spin_rq_lock_unlock,.interval.clock_boundaries_outside_lock_inside_irq_disabled,.interval.paired_empty_control,.interval.alternating_pair_order,.interval.sort_and_report_after_irq_restore] | all(. == true)) and
  .interval.additional_formula == "max(rebuild_ns-control_ns,0)" and
  .interval.allocation_sort_print_trace_sleep_policy_monitor_inside_interval_allowed == false and .interval.extra_task_or_rq_lock_inside_interval_allowed == false and
  .matrix.runnable_entities == [0,1,8,64,256,1024,4096] and .matrix.hierarchy_depths == [0,1,4,16,64] and
  .matrix.cell_count == 35 and .matrix.minimum_warmup_pairs_per_cell == 256 and .matrix.measured_pairs_per_cell == 10000 and
  .matrix.generation_race_rate_ppm == 0 and .matrix.result_rows_required == 35 and
  .matrix.arrays == ["control","rebuild","additional"] and .matrix.statistics == ["minimum","p50","p95","p99","p999","maximum"] and
  .matrix.nearest_rank_documented == true and .matrix.all_cells_required == true and .matrix.range_reduction_after_failure_allowed == false and
  .gate.base_slice_ns == 700000 and .gate.additional_p99_limit_ns == 25000 and .gate.additional_max_limit_ns == 50000 and
  .gate.sample_may_reach_base_slice == false and .gate.warning_count_allowed == 0 and .gate.failure_rejects_full_locked_rebuild == true and
  .gate.threshold_failure_is_valid_negative_evidence == true and .gate.threshold_failure_makes_kunit_integrity_fail == false and .gate.missing_or_malformed_evidence_is_harness_failure == true and
  ([.environments.arm64_apple_container_qemu_required,.environments.x86_64_comparable_environment_required,.environments.same_e4_source_identity_required,.environments.record_cpu_arch_frequency_governor,.environments.record_virtualization_qemu_accelerator_cpu,.environments.record_kernel_config_compiler_mitigations_clock,.environments.record_image_and_config_hashes] | all(. == true)) and
  .environments.virtualized_result_supports_bare_metal_claim == false and .environments.single_architecture_pass_completes_e4 == false and
  .classification.valid_results == ["passed_e4_architecture_measurement","rejected_full_locked_rebuild"] and .classification.invalid_result == "harness_failed" and
  (.source_anchors | length == 24) and (.absence_checks | length == 4) and .formal.unsafe_cfg_count == 28 and
  .authorization_after_plan_pass.e4_disposable_worktree_may_be_created == true and .authorization_after_plan_pass.e4_two_file_source_draft_may_be_created == true and
  .authorization_after_plan_pass.e4_arm64_measurement_may_be_launched_after_source_gate == false and .authorization_after_plan_pass.e4_measurement_accepted == false and .authorization_after_plan_pass.full_locked_rebuild_approved == false and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchors"
while IFS='|' read -r id path pattern; do
	if grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then status=ok; else status=missing; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .path, .pattern] | join("|")' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchors")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence="$OUT_DIR/absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence"
while IFS='|' read -r id path pattern; do
	if git -C "$WORKSPACE_DIR/$path" grep -Fq "$pattern" -- .; then status=present; else status=absent; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence"
done < <(jq -r '.absence_checks[] | [.id, .path, .pattern] | join("|")' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence")
[ "$absence_failures" = 0 ] || die "absence failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2E4LockHoldMeasurementPlanSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2E4LockHoldMeasurementPlanUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (cd "$MODEL_DIR" && java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/states-$name" -config "$(basename "$cfg")" "$MODEL") > "$log" 2>&1; then
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		unsafe_failures=$((unsafe_failures + 1))
	fi
done
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2E4LockHoldMeasurementPlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 28 ] && [ "$unsafe_expected" = 28 ] || die 'unsafe TLC count mismatch'

jq -n \
	--arg run_id "$RUN_ID" --arg e3_result_sha256 "$e3_hash" \
	--arg primary "$expected_primary" --arg e2 "$expected_e2" --arg e3 "$expected_e3" \
	--arg tree "$expected_tree" --arg diff "$expected_diff" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" --argjson absence_failures "$absence_failures" \
	--argjson safe_states "${safe_states:-0}" --argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" --argjson unsafe "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_e4_plan_only",e3_result_sha256:$e3_result_sha256,primary_commit:$primary,e2_candidate_commit:$e2,e3_candidate_commit:$e3,e3_candidate_tree:$tree,e3_candidate_diff_sha256:$diff,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,absence_failures:$absence_failures,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe,allowed_files:["init/Kconfig","kernel/sched/fair.c"],matrix_cell_count:35,measured_pairs_per_cell:10000,base_slice_ns:700000,additional_p99_limit_ns:25000,additional_max_limit_ns:50000,e4_disposable_worktree_may_be_created:true,e4_two_file_source_draft_may_be_created:true,e4_arm64_measurement_may_be_launched_after_source_gate:false,e4_measurement_accepted:false,full_locked_rebuild_approved:false,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,real_picker_fence_approved:false,real_publisher_approved:false,real_fanout_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,latency_claim:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
