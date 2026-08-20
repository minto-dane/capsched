#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-sealed-masked-domain-forest.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-sealed-masked-domain-forest-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r6-architecture-test.XXXXXX")

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
		printf 'error: R6 architecture gate accepted mutation: %s\n' \
			"$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject mutable-authority \
	'.authority_plane.slot_map_digest_frozen = false'
expect_reject publication-fanout \
	'.authority_plane.publication_walks_rqs_tasks_or_queues = true'
expect_reject immutable-selector \
	'.selector_plane.immutable_copy_of_dynamic_selector_state = true'
expect_reject variable-flat-scan \
	'.selector_plane.flat_task_tree_variable_fallback = true'
expect_reject logarithmic-overclaim \
	'.selector_plane.masked_query_logarithmic_claimed = true'
expect_reject cgroup-authority \
	'.authority_plane.cgroup_task_group_weight_vruntime_deadline_or_topology_is_authority = true'
expect_reject double-contribution \
	'.task_lifetime.simultaneous_source_destination_contribution = true'
expect_reject flat-fairness-claim \
	'.fairness_boundary.flat_cfs_equivalence_claimed = true'
expect_reject premature-source \
	'.claims.r6_source_approved = true'

printf 'all R6 sealed-masked-domain-forest contract tests passed\n'
