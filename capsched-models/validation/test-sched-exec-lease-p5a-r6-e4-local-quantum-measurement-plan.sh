#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/plan-gate-tests/p5a-r6-e4-local-quantum-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-*-"$$" \
		2>/dev/null || true
	find "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-*-"$$" \
		-depth -delete 2>/dev/null || true
}

run_fixture()
{
	local name=$1 file=$2 sha

	sha=$(sha256sum "$file" | awk '{print $1}')
	RUN_ID="test-r6-e4-$name-$$" PLAN_TEST_MODE=1 PREFLIGHT_ONLY=1 \
		OFFLINE_TEST_MODE=1 TEST_CONFIG_SHA="$sha" CONFIG_OVERRIDE="$file" \
		"$RUNNER"
}

expect_reject()
{
	local name=$1 file=$2

	if run_fixture "$name" "$file" >/dev/null 2>&1; then
		die "plan gate accepted mutation: $name"
	fi
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'plan runner is not executable'
[ -f "$CONFIG" ] && [ ! -L "$CONFIG" ] ||
	die 'canonical config is missing or unsafe'
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONFIG" "$FIXTURE_ROOT/good.json"
run_fixture good "$FIXTURE_ROOT/good.json" >/dev/null

jq '.prerequisite.post_e3_authorization_normalized_sha256 = "tampered"' \
	"$CONFIG" > "$FIXTURE_ROOT/authorization.json"
expect_reject authorization "$FIXTURE_ROOT/authorization.json"

jq '.prerequisite.threat_model_sha256 = "tampered"' "$CONFIG" \
	> "$FIXTURE_ROOT/threat-model.json"
expect_reject threat-model "$FIXTURE_ROOT/threat-model.json"

jq '.source.allowed_files += ["kernel/sched/fair.c"]' "$CONFIG" \
	> "$FIXTURE_ROOT/source-scope.json"
expect_reject source-scope "$FIXTURE_ROOT/source-scope.json"

jq '.matrix.total_cells = 854' "$CONFIG" \
	> "$FIXTURE_ROOT/matrix.json"
expect_reject matrix "$FIXTURE_ROOT/matrix.json"

jq '.common_measurement.measured_pairs_per_cell = 9999' "$CONFIG" \
	> "$FIXTURE_ROOT/pairs.json"
expect_reject pairs "$FIXTURE_ROOT/pairs.json"

jq '.thresholds.ordinary_additional_p99_limit_ns = 5001' "$CONFIG" \
	> "$FIXTURE_ROOT/threshold.json"
expect_reject threshold "$FIXTURE_ROOT/threshold.json"

jq '.families.slot_local_handoff_final_task_check.ordinary_linux_eevdf_is_unchanged_baseline = false |
    .families.slot_local_handoff_final_task_check.pick_eevdf_latency_or_improvement_claim = true' \
	"$CONFIG" > "$FIXTURE_ROOT/eevdf-overclaim.json"
expect_reject eevdf-overclaim "$FIXTURE_ROOT/eevdf-overclaim.json"

jq '.diagnostics.arm64_runs_first = false' "$CONFIG" \
	> "$FIXTURE_ROOT/architecture-order.json"
expect_reject architecture-order "$FIXTURE_ROOT/architecture-order.json"

jq '.common_measurement.rounding_aggregation_or_raw_row_discard_allowed = true' \
	"$CONFIG" > "$FIXTURE_ROOT/raw-evidence.json"
expect_reject raw-evidence "$FIXTURE_ROOT/raw-evidence.json"

jq '.safety_flags.monitor_verified = true' "$CONFIG" \
	> "$FIXTURE_ROOT/monitor.json"
expect_reject monitor "$FIXTURE_ROOT/monitor.json"

ln -s "$CONFIG" "$FIXTURE_ROOT/symlink.json"
if RUN_ID="test-r6-e4-symlink-$$" PLAN_TEST_MODE=1 PREFLIGHT_ONLY=1 \
	OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')" \
	CONFIG_OVERRIDE="$FIXTURE_ROOT/symlink.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted a symlinked config'
fi

printf '%s\n' \
	'passed: exact R6-E4 plan accepted; authorization/threat/scope/matrix/pair/threshold/EEVDF/order/raw/monitor mutations and symlink rejected'
