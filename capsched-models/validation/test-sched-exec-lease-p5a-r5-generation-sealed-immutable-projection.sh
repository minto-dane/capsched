#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r5-generation-sealed-immutable-projection.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r5-generation-sealed-immutable-projection-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r5-architecture-test.XXXXXX")

cleanup()
{
	rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

expect_reject()
{
	local name=$1 filter=$2 mutated

	mutated="$TMP_ROOT/$name.json"

	jq "$filter" "$CONFIG" > "$mutated"
	if TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID="$name" CONFIG_OVERRIDE="$mutated" \
		"$RUNNER" > "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: architecture gate accepted mutation: %s\n' "$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject repair-under-rq-lock '.decision.mutable_projection_repair_under_rq_lock = true'
expect_reject unsealed-install '.install_contract.raced_or_unsealed_view_installed = true'
expect_reject install-scan '.install_contract.walks_tasks_entities_leaves_buckets_projections_cpumasks_or_membership = true'
expect_reject old-view-fallback '.compile_contract.old_view_fallback_after_failure = true'
expect_reject current-repair '.current_contract.current_stop_distributor_repairs_or_installs_views = true'
expect_reject premature-source '.claims.r5_source_approved = true'

printf 'all R5 generation-sealed immutable-projection contract tests passed\n'
