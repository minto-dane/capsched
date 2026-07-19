#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/plan-gate-tests/p5a-r4-e4-local-quantum-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT/test-r4-e4-good-$$" \
		"$OUT_ROOT/test-r4-e4-threshold-$$" "$OUT_ROOT/test-r4-e4-matrix-$$" \
		"$OUT_ROOT/test-r4-e4-overclaim-$$" "$OUT_ROOT/test-r4-e4-global-$$" \
		"$OUT_ROOT/test-r4-e4-symlink-$$" 2>/dev/null || true
	find "$FIXTURE_ROOT" "$OUT_ROOT/test-r4-e4-good-$$" \
		"$OUT_ROOT/test-r4-e4-threshold-$$" "$OUT_ROOT/test-r4-e4-matrix-$$" \
		"$OUT_ROOT/test-r4-e4-overclaim-$$" "$OUT_ROOT/test-r4-e4-global-$$" \
		"$OUT_ROOT/test-r4-e4-symlink-$$" -depth -delete 2>/dev/null || true
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'plan runner is not executable'
if [ ! -f "$CONFIG" ] || [ -L "$CONFIG" ]; then
	die 'canonical config missing or unsafe'
fi
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONFIG" "$FIXTURE_ROOT/good.json"
good_sha=$(sha256sum "$FIXTURE_ROOT/good.json" | awk '{print $1}')

RUN_ID="test-r4-e4-good-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$good_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/good.json" \
	"$RUNNER" >/dev/null

jq '.local_gate.additional_p99_limit_ns = 5001' "$CONFIG" > "$FIXTURE_ROOT/threshold.json"
threshold_sha=$(sha256sum "$FIXTURE_ROOT/threshold.json" | awk '{print $1}')
if RUN_ID="test-r4-e4-threshold-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$threshold_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/threshold.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted a relaxed local threshold'
fi

jq '.publication.cell_count = 287' "$CONFIG" > "$FIXTURE_ROOT/matrix.json"
matrix_sha=$(sha256sum "$FIXTURE_ROOT/matrix.json" | awk '{print $1}')
if RUN_ID="test-r4-e4-matrix-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$matrix_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/matrix.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted a reduced publication matrix'
fi

jq '.authorization_after_plan_pass.e4_measurement_may_start_before_source_gate = true' \
	"$CONFIG" > "$FIXTURE_ROOT/overclaim.json"
overclaim_sha=$(sha256sum "$FIXTURE_ROOT/overclaim.json" | awk '{print $1}')
if RUN_ID="test-r4-e4-overclaim-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$overclaim_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/overclaim.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted measurement launch before the source gate'
fi

jq '.logical_bounds.publication_to_last_settlement_wall_clock_gate_present = true' \
	"$CONFIG" > "$FIXTURE_ROOT/global.json"
global_sha=$(sha256sum "$FIXTURE_ROOT/global.json" | awk '{print $1}')
if RUN_ID="test-r4-e4-global-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$global_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/global.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted a restored global settlement threshold'
fi

ln -s "$CONFIG" "$FIXTURE_ROOT/symlink.json"
if RUN_ID="test-r4-e4-symlink-$$" PLAN_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 \
	TEST_CONFIG_SHA="$good_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/symlink.json" \
	"$RUNNER" >/dev/null 2>&1; then
	die 'plan gate accepted a symlinked config'
fi

printf 'passed: exact plan accepted; relaxed threshold, reduced matrix, premature launch, global settlement gate, and symlink rejected\n'
