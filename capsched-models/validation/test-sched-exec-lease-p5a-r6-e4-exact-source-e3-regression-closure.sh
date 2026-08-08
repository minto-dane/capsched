#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-closure.sh"
SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression/20260730T-p5a-r6-e4-e3-regression-r1"
FIXTURE_ROOT="$WORKSPACE_DIR/build/closure-tests/p5a-r6-e4-exact-source-e3-regression-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-closure-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-e3-*"-$$" \
		2>/dev/null || true
	find "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-e4-e3-*"-$$" \
		-depth -delete 2>/dev/null || true
}

run_fixture()
{
	local name=$1 root=$2

	RUN_ID="test-r6-e4-e3-$name-$$" CLOSURE_TEST_MODE=1 \
		PREFLIGHT_ONLY=1 OFFLINE_TEST_MODE=1 \
		SOURCE_DIR_OVERRIDE="$root" "$RUNNER"
}

expect_reject()
{
	local name=$1 root=$2

	if run_fixture "$name" "$root" >/dev/null 2>&1; then
		die "closure accepted invalid fixture: $name"
	fi
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'closure runner is not executable'
[ -d "$SOURCE" ] || die 'canonical regression evidence is missing'
mkdir -p "$FIXTURE_ROOT"

cp -a -- "$SOURCE" "$FIXTURE_ROOT/good"
run_fixture good "$FIXTURE_ROOT/good" >/dev/null

cp -a -- "$SOURCE" "$FIXTURE_ROOT/tamper-console"
chmod u+w "$FIXTURE_ROOT/tamper-console/x86_64-kcsan-console.log"
printf '%s\n' 'tampered-after-seal' \
	>> "$FIXTURE_ROOT/tamper-console/x86_64-kcsan-console.log"
expect_reject tamper-console "$FIXTURE_ROOT/tamper-console"

cp -a -- "$SOURCE" "$FIXTURE_ROOT/tamper-result"
chmod u+w "$FIXTURE_ROOT/tamper-result/result.json"
jq '.measurement_authorized = true' "$SOURCE/result.json" \
	> "$FIXTURE_ROOT/tamper-result/result.json"
expect_reject tamper-result "$FIXTURE_ROOT/tamper-result"

cp -a -- "$SOURCE" "$FIXTURE_ROOT/symlink"
chmod u+w "$FIXTURE_ROOT/symlink"
ln -s x86_64-kcsan-console.log \
	"$FIXTURE_ROOT/symlink/forbidden-console-link"
expect_reject symlink "$FIXTURE_ROOT/symlink"

printf '%s\n' \
	'passed: exact fixture accepted; console/result tamper and symlink rejected'
