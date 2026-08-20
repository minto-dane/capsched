#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r6-e3-plan-test.XXXXXX")

cleanup()
{
	rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

expect_reject()
{
	local name=$1
	local filter=$2
	local mutated="$TMP_ROOT/$name.json"

	jq "$filter" "$CONFIG" > "$mutated"
	if TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID="$name" \
		CONFIG_OVERRIDE="$mutated" "$RUNNER" \
		> "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: R6-E3 contract accepted mutation: %s\n' "$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject closure-substitution \
	'.source_basis.e2_closure_result_sha256 = "00"'
expect_reject wrong-parent \
	'.source_boundary.future_parent = .source_basis.primary_linux_commit'
expect_reject broad-source-scope \
	'.source_boundary.allowed_files += ["kernel/sched/fair.c"]'
expect_reject e3-default-on \
	'.configuration.default_enabled = true'
expect_reject shared-oracle \
	'.independent_oracle.reuses_implementation_tree_or_transition_helper = true'
expect_reject oracle-shortcut \
	'.independent_oracle.enumerates_all_64_leaves = false'
expect_reject complete-bound-halved \
	'.selector_bounds.complete_query_max_visits = 127'
expect_reject logarithmic-overclaim \
	'.selector_bounds.logarithmic_arbitrary_mask_claim = true'
expect_reject catch-up-credit \
	'.fairness_oracles.unauthorized_interval_catch_up_credit = 1'
expect_reject cgroup-authority \
	'.hierarchy_and_authority.cgroup_is_mechanism_not_authority = false'
expect_reject migration-double-contribution \
	'.task_and_migration.simultaneous_source_destination_contribution = true'
expect_reject current-picker-conflation \
	'.current_hotplug_lifetime.picker_mask_fence_stops_current = true'
expect_reject rcu-before-drain \
	'.current_hotplug_lifetime.offline_order = "stop_accepting_free"'
expect_reject reduced-case-matrix \
	'del(.required_case_families[-1])'
expect_reject reduced-diagnostics \
	'del(.build_and_boot_matrix.diagnostic_boots[-1])'
expect_reject premature-runtime \
	'.claims.runtime_behavior_approved = true'

printf 'all R6-E3 correctness/concurrency evidence-plan contract tests passed\n'
