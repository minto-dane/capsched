#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r5-e1-eevdf-selector-coherence-rejection.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r5-e1-eevdf-selector-coherence-rejection-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r5-e1-rejection-test.XXXXXX")

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
		printf 'error: R5 E1 rejection gate accepted mutation: %s\n' \
			"$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject selector-static \
	'.eevdf_contract.authority_stability_implies_selector_stability = true'
expect_reject mutable-view \
	'.r5_contradiction.immutable_selector_view = false'
expect_reject stale-trust \
	'.r5_contradiction.stale_view_trusted = true'
expect_reject variable-scan \
	'.r5_contradiction.variable_picker_scan_allowed = true'
expect_reject r5-feasible \
	'.r5_contradiction.r5_e1_feasible = true'
expect_reject repair-authorized \
	'.decision.r5_repair_authorized = true'
expect_reject premature-r5-source \
	'.claims.r5_source_approved = true'
expect_reject premature-r6-source \
	'.claims.r6_source_approved = true'

printf 'all R5 E1 selector-coherence rejection contract tests passed\n'
