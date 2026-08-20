#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-arm64-timing-r4-kunit-failure-closure.sh"
SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260721T-p5a-r4-e4-arm64-timing-r4"
JOB="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r4"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r4-kunit-failure-closure-test"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r4-e4-closure-test.XXXXXX")

cleanup()
{
	chmod -R u+w "$TMP_ROOT" "$OUT_ROOT" 2>/dev/null || true
	rm -rf -- "$TMP_ROOT" "$OUT_ROOT"
}
trap cleanup EXIT

expect_reject()
{
	local name=$1 source=$2 job=$3
	if CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID="$name" \
		SOURCE_OVERRIDE="$source" JOB_OVERRIDE="$job" "$RUNNER" \
		> "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: closure accepted mutation: %s\n' "$name" >&2
		exit 1
	fi
}

chmod -R u+w "$OUT_ROOT" 2>/dev/null || true
rm -rf -- "$OUT_ROOT"
CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID=exact-fixture \
	SOURCE_OVERRIDE="$SOURCE" JOB_OVERRIDE="$JOB" "$RUNNER" >/dev/null

mkdir "$TMP_ROOT/job-tamper"
cp -a -- "$JOB/." "$TMP_ROOT/job-tamper/"
printf 'tampered\n' >> "$TMP_ROOT/job-tamper/job.log"
expect_reject job-tamper "$SOURCE" "$TMP_ROOT/job-tamper"

mkdir "$TMP_ROOT/source-tamper"
cp -a -- "$SOURCE/." "$TMP_ROOT/source-tamper/"
printf '\n' >> "$TMP_ROOT/source-tamper/raw/qemu-serial.log"
expect_reject source-tamper "$TMP_ROOT/source-tamper" "$JOB"

ln -s -- "$SOURCE" "$TMP_ROOT/source-link"
expect_reject source-root-symlink "$TMP_ROOT/source-link" "$JOB"

mkdir "$TMP_ROOT/job-symlink"
cp -a -- "$JOB/." "$TMP_ROOT/job-symlink/"
rm -- "$TMP_ROOT/job-symlink/vm_exit_code"
ln -s -- "$JOB/vm_exit_code" "$TMP_ROOT/job-symlink/vm_exit_code"
expect_reject job-input-symlink "$SOURCE" "$TMP_ROOT/job-symlink"

printf 'all timing r4 KUnit-failure closure tests passed\n'
