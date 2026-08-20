#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r5-generation-sealed-immutable-projection-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0140-p5a-r5-generation-sealed-immutable-projection-model"
MODEL=P5AR5GenerationSealedImmutableProjection.tla
SAFE_CFG=P5AR5GenerationSealedImmutableProjectionSafe.cfg
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
TEST_MODE=${TEST_MODE:-0}
CONTRACT_ONLY=${CONTRACT_ONLY:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}

if [ "$TEST_MODE" = 1 ]; then
	[ "$CONTRACT_ONLY" = 1 ] ||
		{ printf 'error: TEST_MODE requires CONTRACT_ONLY=1\n' >&2; exit 1; }
	[ -n "$CONFIG_OVERRIDE" ] ||
		{ printf 'error: TEST_MODE requires CONFIG_OVERRIDE\n' >&2; exit 1; }
	CONFIG=$CONFIG_OVERRIDE
else
	[ "$CONTRACT_ONLY" = 0 ] ||
		{ printf 'error: CONTRACT_ONLY is restricted to TEST_MODE\n' >&2; exit 1; }
	[ -z "$CONFIG_OVERRIDE" ] ||
		{ printf 'error: CONFIG_OVERRIDE is restricted to TEST_MODE\n' >&2; exit 1; }
	CONFIG=$CANONICAL_CONFIG
fi

R4_RESULT="$WORKSPACE_DIR/$(jq -r '.trigger.result' "$CONFIG")"
CLOSURE_R1="$WORKSPACE_DIR/$(jq -r '.trigger.closure_r1' "$CONFIG")"
CLOSURE_R2="$WORKSPACE_DIR/$(jq -r '.trigger.closure_r2' "$CONFIG")"
R4_RUN_DIR=$(dirname "$R4_RESULT")
MEASUREMENTS="$R4_RUN_DIR/derived/measurements.tsv"
THRESHOLDS="$R4_RUN_DIR/derived/threshold-failures.json"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r5-generation-sealed-immutable-projection"
OUT_DIR="$OUT_ROOT/$RUN_ID"

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

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$TEST_MODE:$CONTRACT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid runner mode' ;;
esac
for command in awk cmp git grep java jq mkdir sed sha256sum sort tail; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -f "$CONFIG" ] || die "missing config: $CONFIG"

progress '5% validating immutable R4 trigger and R5 contract'
jq empty "$CONFIG"
jq -e '
  .schema_version == 1 and
  .status == "generation_sealed_immutable_projection_architecture_gate_no_linux_patch" and
  .trigger.result_sha256 == "edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951" and
  .trigger.closure_r1_sha256 == "b5279add6127b35472cc15d2345c37c3bd1a3a4b2030fe4f87d30abe7a4297af" and
  .trigger.closure_r2_sha256 == "75e734bc61e239db868b426c8cf37d40677ff3a04567da72437bcdafa41a2719" and
  .trigger.closure_normalized_sha256 == "8ebacd3c03dee0519a978cd21a7537b729fb61267d2491b70f76f54219fa84b5" and
  .trigger.valid_negative_evidence == true and
  .trigger.cells == 682 and .trigger.paired_measurements == 6820000 and
  .trigger.rejected_cells == 362 and .trigger.threshold_breaches == 692 and
  .trigger.kunit_pass == 7 and .trigger.kunit_fail == 0 and
  .trigger.qemu_exit_code == 0 and .trigger.harness_failures == 0 and
  .trigger.x86_64_and_r4_e5_stopped == true and
  .distribution.reason_counts == {
    "additional_max":358,"additional_p99":164,
    "additional_p999":160,"additional_reached_base_slice":10
  } and
  .distribution.rare_tail_only_does_not_explain_rejection == true and
  .distribution.recovery_notifier_offline_percentile_failures_are_structural_input == true and
  .distribution.virtual_tcg_supports_bare_metal_performance_claim == false and
  .decision.name == "generation_sealed_immutable_projection_install" and
  .decision.mutable_projection_repair_under_rq_lock == false and
  .decision.projection_repair_notifier == false and
  .decision.immutable_view_built_outside_rq_lock == true and
  .decision.sealed_receipt_required_before_install == true and
  .decision.rq_lock_install_constant_work == true and
  .decision.picker_exact_view_fence == true and
  .decision.current_stop_distribution_separate == true and
  .decision.global_last_settlement_gate == false and
  .decision.r5_e1_plan_selected == true and
  .descriptor_contract.frozen_before_release_publish == true and
  .descriptor_contract.generation_release_published == true and
  .descriptor_contract.generation_reuse == false and
  .descriptor_contract.generation_saturation_blocks == true and
  .descriptor_contract.publication_walks_rqs_or_membership == false and
  .descriptor_contract.publication_takes_rq_lock == false and
  .descriptor_contract.publication_allocates_waits_flushes_or_cancels == false and
  .descriptor_contract.publisher_waits_for_views == false and
  .compile_contract.one_preallocated_owner_per_demanded_rq_bucket == true and
  .compile_contract.duplicate_publications_add_owner_or_queue_depth == false and
  .compile_contract.newest_desired_generation_wins == true and
  .compile_contract.view_built_outside_rq_lock == true and
  .compile_contract.mutable_scheduler_tree_lockless_traversal_assumed_safe == false and
  .compile_contract.build_start_and_end_descriptor_match == true and
  .compile_contract.build_start_and_end_membership_sequence_match == true and
  .compile_contract.raced_build_discarded == true and
  .compile_contract.allocation_or_build_failure_state == "Blocked" and
  .compile_contract.old_view_fallback_after_failure == false and
  (.compile_contract.sealed_receipt_fields | length) == 7 and
  .install_contract.takes_exactly_one_owning_rq_lock == true and
  .install_contract.final_descriptor_acquire_read == true and
  .install_contract.final_generation_membership_selector_digest_check == true and
  .install_contract.swaps_one_rcu_pointer == true and
  .install_contract.records_one_installed_generation_and_state == true and
  .install_contract.walks_tasks_entities_leaves_buckets_projections_cpumasks_or_membership == false and
  .install_contract.allocates_hashes_variable_input_compiles_queues_waits_flushes_or_cancels == false and
  .install_contract.raced_or_unsealed_view_installed == false and
  .install_contract.old_view_retired_after_zero_refs_and_rcu_grace == true and
  .picker_contract.requires_sealed_view == true and
  .picker_contract.requires_view_generation_equals_acquire_published_generation == true and
  .picker_contract.requires_current_membership_sequence == true and
  .picker_contract.requires_selector_key_and_authority_digest == true and
  .picker_contract.requires_selected_entity_membership_proof == true and
  .picker_contract.requires_final_task_local_check == true and
  .picker_contract.mismatch_fails_closed == true and
  .picker_contract.may_record_one_preallocated_compile_needed_edge == true and
  .picker_contract.builds_installs_scans_allocates_waits_policy_or_monitor == false and
  .picker_contract.fallback_authority == false and
  .current_contract.projection_repair_notifier_removed == true and
  .current_contract.current_stop_distributor_separate == true and
  .current_contract.current_stop_distributor_repairs_or_installs_views == false and
  .current_contract.later_distinct_scheduler_observation_required == true and
  .current_contract.linux_resched_is_completion_receipt == false and
  .current_contract.monitor_interrupt_timer_and_receipt_required_for_protection == true and
  .liveness_contract.safety_under_continuous_publication == true and
  .liveness_contract.availability_under_continuous_publication_claim == false and
  .liveness_contract.stable_generation_descriptor_selector_and_membership_required == true and
  .liveness_contract.weak_fair_compile_owner_required == true and
  .liveness_contract.finite_membership_and_memory_bounds_required == true and
  .liveness_contract.eventual_one_view_allocation_required == true and
  .liveness_contract.non_demanded_stale_rq_may_remain_blocked == true and
  .liveness_contract.demanded_rq_installs_or_remains_explicitly_blocked == true and
  .liveness_contract.global_last_settlement_deadline == false and
  .liveness_contract.wall_clock_claim == false and
  .lifetime_contract.enqueue_current_descriptor_handshake == true and
  .lifetime_contract.migration_source_removed_before_destination_contribution == true and
  .lifetime_contract.simultaneous_source_destination_contribution == false and
  .lifetime_contract.offline_clears_accepting_before_pointer_detach == true and
  .lifetime_contract.offline_pointer_detach_constant_work_under_rq_lock == true and
  .lifetime_contract.cancel_flush_free_or_rcu_wait_under_rq_lock == false and
  .lifetime_contract.builder_installed_reader_and_retirement_states_explicit == true and
  .lifetime_contract.zero_refs_and_rcu_grace_before_free == true and
  .next_gate.source_free_only == true and
  .next_gate.may_start_after_validation == true and
  .next_gate.r5_layout_or_source_may_start == false and
  .next_gate.primary_linux_or_patch_queue_change == false and
  (.claims | [
    .r4_accepted,.r5_source_approved,.x86_64_timing_approved,
    .real_scheduler_attachment,.runtime_behavior_approved,.n136_complete,
    .bare_metal_validated,.performance_claim,.cost_claim,.monitor_verified,
    .production_protection,.deployment_ready,.multi_node_ready,
    .multi_cluster_ready,.datacenter_ready
  ] | all(. == false)) and
  .claims.r5_architecture_selected == true
' "$CONFIG" >/dev/null || die 'R5 architecture contract changed'

if [ "$CONTRACT_ONLY" = 1 ]; then
	progress '100% exact contract accepted in test mode'
	exit 0
fi

[ -e "$OUT_DIR" ] && die "output already exists: $OUT_DIR"
mkdir -p "$OUT_DIR/generated-unsafe-configs"
for file in "$TLA_JAR" "$R4_RESULT" "$CLOSURE_R1" "$CLOSURE_R2" \
	"$MEASUREMENTS" "$THRESHOLDS"; do
	[ -f "$file" ] || die "missing canonical input: $file"
	[ ! -L "$file" ] || die "canonical input is a symlink: $file"
done

progress '12% revalidating exact R4 result, closures, and measured distribution'
[ "$(file_sha "$R4_RESULT")" = "$(jq -r '.trigger.result_sha256' "$CONFIG")" ] ||
	die 'R4 result hash changed'
[ "$(file_sha "$CLOSURE_R1")" = "$(jq -r '.trigger.closure_r1_sha256' "$CONFIG")" ] ||
	die 'R4 closure r1 hash changed'
[ "$(file_sha "$CLOSURE_R2")" = "$(jq -r '.trigger.closure_r2_sha256' "$CONFIG")" ] ||
	die 'R4 closure r2 hash changed'
[ "$(jq -S 'del(.run_id)' "$CLOSURE_R1" | sha256sum | awk '{print $1}')" = \
	"$(jq -r '.trigger.closure_normalized_sha256' "$CONFIG")" ] ||
	die 'R4 closure r1 normalization changed'
[ "$(jq -S 'del(.run_id)' "$CLOSURE_R2" | sha256sum | awk '{print $1}')" = \
	"$(jq -r '.trigger.closure_normalized_sha256' "$CONFIG")" ] ||
	die 'R4 closure r2 normalization changed'
jq -e '
  .status == "rejected_r4_local_quantum_measurement" and
  .architecture_measurement_valid == true and
  .threshold_failure_is_valid_negative_evidence == true and
  .matrix.result_rows == 682 and .matrix.total_measured_pairs == 6820000 and
  .parser.rejected_cells == 362 and .parser.threshold_breaches == 692 and
  .parser.malformed_or_missing_rows == 0 and
  .parser.duplicate_or_unexpected_cells == 0 and
  .parser.summary_mismatches == 0 and .parser.harness_observation_failures == 0 and
  .diagnostics.kunit_cases_passed == 7 and .diagnostics.kunit_cases_failed == 0 and
  .diagnostics.qemu_exit_code == 0 and .diagnostics.compiler_diagnostics == 0 and
  .diagnostics.kernel_warning_reports == 0 and .diagnostics.clock_skew_reports == 0 and
  .x86_64_measurement_may_start == false and .e5_plan_may_start == false
' "$R4_RESULT" >/dev/null || die 'R4 result semantics changed'
for closure in "$CLOSURE_R1" "$CLOSURE_R2"; do
	jq -e '
	  .status == "passed_independent_arm64_timing_r7_valid_negative_closure" and
	  .matrix.cells == 682 and .matrix.pairs == 6820000 and
	  .matrix.rejected_cells == 362 and .matrix.threshold_breaches == 692 and
	  .parser.recomputed_outputs_exact == true and
	  .threshold_failure_is_valid_negative_evidence == true and
	  .r4_local_quantum_measurement_rejected == true and
	  .successor_design_required == true and
	  .x86_64_measurement_may_start == false and .e5_plan_may_start == false
	' "$closure" >/dev/null || die "R4 closure semantics changed: $closure"
done

awk -F '\t' '
	NR == 1 { next }
	{
		rows[$1]++
		if ($NF == "reject") rejected[$1]++
	}
	END {
		for (family in rows)
			printf "%s\t%d\t%d\n", family, rows[family], rejected[family] + 0
	}
' "$MEASUREMENTS" | sort > "$OUT_DIR/family-actual.tsv"
jq -r '.distribution.families | to_entries[] |
  [.key,.value.rows,.value.rejected] | @tsv' "$CONFIG" |
	sort > "$OUT_DIR/family-expected.tsv"
cmp "$OUT_DIR/family-expected.tsv" "$OUT_DIR/family-actual.tsv" >/dev/null ||
	die 'R4 family distribution changed'
jq -r 'group_by(.reason)[] | [.[0].reason,length] | @tsv' \
	"$THRESHOLDS" > "$OUT_DIR/reasons-actual.tsv"
jq -r '.distribution.reason_counts | to_entries[] | [.key,.value] | @tsv' \
	"$CONFIG" | sort > "$OUT_DIR/reasons-expected.tsv"
sort -o "$OUT_DIR/reasons-actual.tsv" "$OUT_DIR/reasons-actual.tsv"
cmp "$OUT_DIR/reasons-expected.tsv" "$OUT_DIR/reasons-actual.tsv" >/dev/null ||
	die 'R4 threshold reason distribution changed'

progress '22% checking Linux mechanism anchors and future-source absence'
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
	id=$(printf '%s\n' "$row" | jq -r '.id')
	path=$(printf '%s\n' "$row" | jq -r '.path')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" \
		>> "$OUT_DIR/source-anchors.tsv"
done < <(jq -c '.source_anchors[]' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {n++} END {print n+0}' \
	"$OUT_DIR/source-anchors.tsv")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"
printf 'id\tstatus\tpattern\n' > "$OUT_DIR/future-absence.tsv"
while IFS= read -r row; do
	id=$(printf '%s\n' "$row" | jq -r '.id')
	pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
	if git -C "$LINUX_DIR" grep -Fq "$pattern" -- \
		include/linux/sched.h include/linux/sched_exec_lease.h \
		kernel/sched init/Kconfig; then
		status=unexpected-present
	else
		status=absent
	fi
	printf '%s\t%s\t%s\n' "$id" "$status" "$pattern" \
		>> "$OUT_DIR/future-absence.tsv"
done < <(jq -c '.future_absence_checks[]' "$CONFIG")
absence_count=$(jq '.future_absence_checks | length' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {n++} END {print n+0}' \
	"$OUT_DIR/future-absence.tsv")
[ "$absence_failures" = 0 ] ||
	die "future-source absence failures: $absence_failures"

progress '30% checking safe receipt/install safety and stable-window liveness'
(
	cd "$MODEL_DIR"
	java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config "$SAFE_CFG" "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" ||
	die 'safe TLC model did not pass'
grep -q 'Checking 2 branches of temporal properties' "$OUT_DIR/tlc-safe.log" ||
	die 'safe TLC liveness properties were not checked'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n \
	's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n \
	's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' \
	"$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_states=${safe_states:-0}
safe_distinct=${safe_distinct:-0}
safe_depth=${safe_depth:-0}

fault_count=$(jq '.formal.unsafe_faults | length' "$CONFIG")
unsafe_expected=0
unsafe_failures=0
while IFS= read -r fault; do
	name="P5AR5GenerationSealedImmutableProjectionUnsafe${fault}"
	cfg="$OUT_DIR/generated-unsafe-configs/$name.cfg"
	log="$OUT_DIR/tlc-$name.log"
	printf 'SPECIFICATION Spec\nCONSTANT Fault = "%s"\nINVARIANT TypeOK\nINVARIANT Safety\n' \
		"$fault" > "$cfg"
	if (
		cd "$MODEL_DIR"
		java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" -config "$cfg" "$MODEL"
	) > "$log" 2>&1; then
		printf 'unsafe fault unexpectedly passed: %s\n' "$fault" >&2
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -Eq 'Invariant (TypeOK|Safety) is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
		progress "$((30 + unsafe_expected * 65 / fault_count))% unsafe counterexamples $unsafe_expected/$fault_count"
	else
		printf 'unsafe fault failed unexpectedly: %s\n' "$fault" >&2
		tail -n 50 "$log" >&2
		unsafe_failures=$((unsafe_failures + 1))
	fi
done < <(jq -r '.formal.unsafe_faults[]' "$CONFIG")
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$unsafe_expected" = "$fault_count" ] ||
	die "unsafe counterexample mismatch: expected=$fault_count actual=$unsafe_expected"

progress '97% sealing source-free R5 architecture decision'
jq -S -n \
	--arg run_id "$RUN_ID" --arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" --arg r4_result_sha "$(file_sha "$R4_RESULT")" \
	--arg closure_normalized_sha "$(jq -r '.trigger.closure_normalized_sha256' "$CONFIG")" \
	--argjson anchors "$anchor_count" --argjson absences "$absence_count" \
	--argjson safe_states "$safe_states" --argjson safe_distinct "$safe_distinct" \
	--argjson safe_depth "$safe_depth" --argjson faults "$unsafe_expected" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_generation_sealed_immutable_projection_architecture_only",
  linux_commit:$linux_commit,
  linux_tree:$linux_tree,
  r4_result_sha256:$r4_result_sha,
  r4_closure_normalized_sha256:$closure_normalized_sha,
  r4_valid_negative:{cells:682,pairs:6820000,rejected_cells:362,threshold_breaches:692},
  source_anchor_count:$anchors,
  source_anchor_failures:0,
  future_absence_check_count:$absences,
  future_absence_check_failures:0,
  selected_successor:"generation_sealed_immutable_projection_install",
  mutable_projection_repair_under_rq_lock:false,
  immutable_view_built_outside_rq_lock:true,
  sealed_receipt_required:true,
  constant_work_rq_lock_install:true,
  exact_picker_fence:true,
  projection_repair_notifier_removed:true,
  current_stop_separate:true,
  safe_passed:true,
  liveness_properties_checked:2,
  safe_states_generated:$safe_states,
  safe_distinct_states:$safe_distinct,
  safe_depth:$safe_depth,
  unsafe_expected_counterexamples:$faults,
  r5_e1_source_free_plan_may_be_drafted:true,
  r5_layout_or_source_may_start:false,
  x86_64_timing_may_start:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
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
progress '100% R5 source-free architecture selected; E1 evidence plan only'
printf 'result=%s\nsha256=%s\n' "$OUT_DIR/result.json" \
	"$(cat "$OUT_DIR/result.sha256")"
