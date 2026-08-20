#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression.sh"
CONTRACT="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/source-gate-tests/p5a-r6-e4-e3-regression-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" \
		"$OUT_ROOT"/test-r6-e4-e3-regression-*-"$$" \
		2>/dev/null || true
	find "$FIXTURE_ROOT" \
		"$OUT_ROOT"/test-r6-e4-e3-regression-*-"$$" \
		-depth -delete 2>/dev/null || true
}

run_fixture()
{
	local name=$1 file=$2 sha

	sha=$(sha256sum "$file" | awk '{print $1}')
	RUN_ID="test-r6-e4-e3-regression-$name-$$" \
		REGRESSION_TEST_MODE=1 PREFLIGHT_ONLY=1 OFFLINE_TEST_MODE=1 \
		TEST_CONTRACT_SHA="$sha" CONTRACT_OVERRIDE="$file" "$RUNNER"
}

expect_reject()
{
	local name=$1 file=$2

	if run_fixture "$name" "$file" >/dev/null 2>&1; then
		die "regression gate accepted mutation: $name"
	fi
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'regression runner is not executable'
if [ ! -f "$CONTRACT" ] || [ -L "$CONTRACT" ]; then
	die 'canonical regression contract is missing or unsafe'
fi
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONTRACT" "$FIXTURE_ROOT/good.json"
run_fixture good "$FIXTURE_ROOT/good.json" >/dev/null

jq '.candidate.commit = "tampered"' "$CONTRACT" \
	> "$FIXTURE_ROOT/candidate.json"
expect_reject candidate "$FIXTURE_ROOT/candidate.json"

jq '.candidate.allowed_files += ["kernel/sched/fair.c"]' "$CONTRACT" \
	> "$FIXTURE_ROOT/scope.json"
expect_reject scope "$FIXTURE_ROOT/scope.json"

jq '.regression.measurement_must_be_disabled = false' "$CONTRACT" \
	> "$FIXTURE_ROOT/measurement-enabled.json"
expect_reject measurement-enabled "$FIXTURE_ROOT/measurement-enabled.json"

jq '.regression.profiles = .regression.profiles[:3]' "$CONTRACT" \
	> "$FIXTURE_ROOT/profiles.json"
expect_reject profiles "$FIXTURE_ROOT/profiles.json"

jq '.resource_policy.jobs = 5' "$CONTRACT" \
	> "$FIXTURE_ROOT/jobs.json"
expect_reject jobs "$FIXTURE_ROOT/jobs.json"

jq '.source_gate.e3_four_profile_regression_required = false' "$CONTRACT" \
	> "$FIXTURE_ROOT/source-gate.json"
expect_reject source-gate "$FIXTURE_ROOT/source-gate.json"

jq '.claims.r6_e4_source_accepted = true' "$CONTRACT" \
	> "$FIXTURE_ROOT/source-accepted.json"
expect_reject source-accepted "$FIXTURE_ROOT/source-accepted.json"

jq '.claims.measurement_authorized = true' "$CONTRACT" \
	> "$FIXTURE_ROOT/measurement-authorized.json"
expect_reject measurement-authorized \
	"$FIXTURE_ROOT/measurement-authorized.json"

ln -s "$CONTRACT" "$FIXTURE_ROOT/symlink.json"
expect_reject symlink "$FIXTURE_ROOT/symlink.json"

printf '%s\n' \
	'passed: exact regression contract accepted; 8 mutations and symlink rejected'
