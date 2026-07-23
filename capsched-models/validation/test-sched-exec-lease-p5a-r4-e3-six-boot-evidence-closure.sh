#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e3-six-boot-evidence-closure.sh"
SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-diagnostic-matrix/20260718T-p5a-r4-e3-six-boot-r4"
FIXTURE_ROOT="$WORKSPACE_DIR/build/closure-tests/p5a-r4-e3-six-boot-evidence-closure-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-six-boot-evidence-closure-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT/test-good-$$" "$OUT_ROOT/test-tamper-$$" "$OUT_ROOT/test-symlink-$$" 2>/dev/null || true
	rm -rf -- "$FIXTURE_ROOT" "$OUT_ROOT/test-good-$$" "$OUT_ROOT/test-tamper-$$" "$OUT_ROOT/test-symlink-$$"
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'closure runner is not executable'
[ -d "$SOURCE" ] || die 'canonical six-boot evidence missing'
mkdir -p "$FIXTURE_ROOT"

cp -a -- "$SOURCE" "$FIXTURE_ROOT/good"
RUN_ID="test-good-$$" CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 SOURCE_DIR_OVERRIDE="$FIXTURE_ROOT/good" "$RUNNER" >/dev/null

cp -a -- "$SOURCE" "$FIXTURE_ROOT/tamper"
chmod u+w "$FIXTURE_ROOT/tamper/x86_64-kcsan-console.log"
printf '%s\n' 'tampered-after-seal' >> "$FIXTURE_ROOT/tamper/x86_64-kcsan-console.log"
if RUN_ID="test-tamper-$$" CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 SOURCE_DIR_OVERRIDE="$FIXTURE_ROOT/tamper" "$RUNNER" >/dev/null 2>&1; then
	die 'closure accepted a tampered console'
fi

cp -a -- "$SOURCE" "$FIXTURE_ROOT/symlink"
ln -s x86_64-kcsan-console.log "$FIXTURE_ROOT/symlink/forbidden-console-link"
if RUN_ID="test-symlink-$$" CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 SOURCE_DIR_OVERRIDE="$FIXTURE_ROOT/symlink" "$RUNNER" >/dev/null 2>&1; then
	die 'closure accepted a symlinked artifact'
fi

printf 'passed: exact fixture accepted; content tamper and symlink rejected\n'
