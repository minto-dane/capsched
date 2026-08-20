#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e2-source-gate.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e2-domain-forest-layout-candidate-v1.json"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r6-e2-source-test.XXXXXX")

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
	if TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID="$name" CONFIG_OVERRIDE="$mutated" \
		"$RUNNER" > "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: R6-E2 source contract accepted mutation: %s\n' \
			"$name" >&2
		exit 1
	fi
}

TEST_MODE=1 CONTRACT_ONLY=1 RUN_ID=exact-contract CONFIG_OVERRIDE="$CONFIG" \
	"$RUNNER" >/dev/null
expect_reject wrong-parent '.source.parent_commit = "bad"'
expect_reject extra-file '.source.allowed_files += ["kernel/sched/fair.c"]'
expect_reject default-on '.candidate_config.default_enabled = true'
expect_reject autogroup '.candidate_config.direct_dependencies[-1] = "SCHED_AUTOGROUP"'
expect_reject wrong-envelope '.private_layout.computed_private_bytes_per_rq = 74689'
expect_reject missing-symbol '.probe.expected_added_symbol_names |= .[:-1]'
expect_reject dual-credit '.arm64_preflight.dual_arch_credit = true'
expect_reject premature-e3 '.next_gate.r6_e3_source_may_start = true'
expect_reject runtime-claim '.claims.runtime_behavior_approved = true'

printf 'all R6-E2 source-gate contract tests passed\n'
