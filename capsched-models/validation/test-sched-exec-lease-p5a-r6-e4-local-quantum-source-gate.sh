#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e4-local-quantum-source-gate.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/source-gate-tests/p5a-r6-e4-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-source-*-"$$" \
		2>/dev/null || true
	find "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-source-*-"$$" \
		-depth -delete 2>/dev/null || true
}

run_fixture()
{
	local name=$1 file=$2 sha

	sha=$(sha256sum "$file" | awk '{print $1}')
	RUN_ID="test-r6-e4-source-$name-$$" \
		SOURCE_GATE_TEST_MODE=1 PREFLIGHT_ONLY=1 OFFLINE_TEST_MODE=1 \
		TEST_CONFIG_SHA="$sha" CONFIG_OVERRIDE="$file" "$RUNNER"
}

expect_reject()
{
	local name=$1 file=$2

	if run_fixture "$name" "$file" >/dev/null 2>&1; then
		die "source gate accepted mutation: $name"
	fi
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'source-gate runner is not executable'
if [ ! -f "$CONFIG" ] || [ -L "$CONFIG" ]; then
	die 'canonical config is missing or unsafe'
fi
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONFIG" "$FIXTURE_ROOT/good.json"
run_fixture good "$FIXTURE_ROOT/good.json" >/dev/null

jq '.candidate.commit = "tampered"' "$CONFIG" \
	> "$FIXTURE_ROOT/candidate.json"
expect_reject candidate "$FIXTURE_ROOT/candidate.json"

jq '.candidate.allowed_files += ["kernel/sched/fair.c"]' "$CONFIG" \
	> "$FIXTURE_ROOT/scope.json"
expect_reject scope "$FIXTURE_ROOT/scope.json"

jq '.configuration.default_enabled = true' "$CONFIG" \
	> "$FIXTURE_ROOT/default.json"
expect_reject default "$FIXTURE_ROOT/default.json"

jq '.configuration.selected_by_kunit_all_tests = true' "$CONFIG" \
	> "$FIXTURE_ROOT/kunit-all.json"
expect_reject kunit-all "$FIXTURE_ROOT/kunit-all.json"

jq '.matrix.families.candidate_127 = 179 | .matrix.total_cells = 854' \
	"$CONFIG" > "$FIXTURE_ROOT/matrix.json"
expect_reject matrix "$FIXTURE_ROOT/matrix.json"

jq '.matrix.exact_raw_rows_required = false' "$CONFIG" \
	> "$FIXTURE_ROOT/raw.json"
expect_reject raw "$FIXTURE_ROOT/raw.json"

jq '.operation_boundary.ordinary_eevdf_inside_additional_interval = true' \
	"$CONFIG" > "$FIXTURE_ROOT/eevdf.json"
expect_reject eevdf "$FIXTURE_ROOT/eevdf.json"

jq '.operation_boundary.full_e3_four_profile_regression_required = false' \
	"$CONFIG" > "$FIXTURE_ROOT/e3-regression.json"
expect_reject e3-regression "$FIXTURE_ROOT/e3-regression.json"

jq '.upstream.candidate_path_changes = ["init/Kconfig"]' "$CONFIG" \
	> "$FIXTURE_ROOT/upstream.json"
expect_reject upstream "$FIXTURE_ROOT/upstream.json"

jq '.claims.monitor_verified = true' "$CONFIG" \
	> "$FIXTURE_ROOT/monitor.json"
expect_reject monitor "$FIXTURE_ROOT/monitor.json"

jq '.claims.measurement_authorized = true' "$CONFIG" \
	> "$FIXTURE_ROOT/measurement.json"
expect_reject measurement "$FIXTURE_ROOT/measurement.json"

jq '.claims.bare_metal_validated = true' "$CONFIG" \
	> "$FIXTURE_ROOT/bare-metal.json"
expect_reject bare-metal "$FIXTURE_ROOT/bare-metal.json"

ln -s "$CONFIG" "$FIXTURE_ROOT/symlink.json"
expect_reject symlink "$FIXTURE_ROOT/symlink.json"

printf '%s\n' \
	'passed: exact R6-E4 source gate accepted; 12 contract mutations and symlink rejected'
