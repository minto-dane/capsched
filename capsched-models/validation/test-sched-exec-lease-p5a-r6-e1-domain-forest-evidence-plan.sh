#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e1-domain-forest-evidence-plan-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r6-e1-plan-test.XXXXXX")

cleanup()
{
	rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

expect_reject()
{
	local name=$1
	local filter=$2
	local mutated

	mutated="$TMP_ROOT/$name.json"
	jq "$filter" "$CONFIG" > "$mutated"
	if TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID="$name" CONFIG_OVERRIDE="$mutated" \
		"$RUNNER" > "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: R6-E1 contract accepted mutation: %s\n' "$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject mixed-domain-subtree \
	'.hierarchy_composition.mixed_domain_subtree_allowed = true'
expect_reject cgroup-authority \
	'.hierarchy_composition.cgroup_css_shares_membership_or_topology_is_authority = true'
expect_reject wrong-complete-query-bound \
	'.top_selector.complete_query_visit_bound = 127'
expect_reject logarithmic-overclaim \
	'.top_selector.logarithmic_query_claim = true'
expect_reject variable-domain-weight \
	'.fairness.variable_domain_weights_supported = true'
expect_reject envelope-growth \
	'.storage.hard_private_bytes_limit_per_rq = 131072'
expect_reject e2-behavior \
	'.e2_boundary.constructors_callsites_callbacks_cpuhp_allocations_or_static_keys = true'
expect_reject migration-double-contribution \
	'.task_and_migration.simultaneous_source_destination_contribution = true'
expect_reject current-conflation \
	'.current_hotplug_lifetime.picker_mask_fence_stops_current = true'
expect_reject premature-runtime \
	'.claims.runtime_behavior_approved = true'

printf 'all R6-E1 domain-forest evidence-plan contract tests passed\n'
