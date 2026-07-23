#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-arm64-timing-r7-valid-negative-closure.sh"
SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/20260723T-p5a-r4-e4-arm64-timing-r7"
JOB="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r7"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r7-valid-negative-closure-test"
TMP_ROOT=$(mktemp -d "$WORKSPACE_DIR/build/r7-valid-negative-closure-test.XXXXXX")

cleanup()
{
	chmod -R u+w "$TMP_ROOT" "$OUT_ROOT" 2>/dev/null || true
	rm -rf -- "$TMP_ROOT" "$OUT_ROOT"
}
trap cleanup EXIT

expect_source_reject()
{
	local name=$1 relative=$2 payload=$3 fixture

	fixture="$TMP_ROOT/$name-source"

	mkdir "$fixture"
	cp -a -- "$SOURCE/." "$fixture/"
	chmod u+w "$fixture/$relative"
	printf '%s\n' "$payload" >> "$fixture/$relative"
	if CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID="$name" \
		SOURCE_OVERRIDE="$fixture" JOB_OVERRIDE="$JOB" "$RUNNER" \
		> "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: closure accepted source mutation: %s\n' "$name" >&2
		exit 1
	fi
	chmod -R u+w "$fixture"
	rm -rf -- "$fixture"
}

expect_job_reject()
{
	local name=$1 relative=$2 value=$3 fixture

	fixture="$TMP_ROOT/$name-job"

	mkdir "$fixture"
	cp -a -- "$JOB/." "$fixture/"
	chmod u+w "$fixture/$relative"
	printf '%s\n' "$value" > "$fixture/$relative"
	if CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID="$name" \
		SOURCE_OVERRIDE="$SOURCE" JOB_OVERRIDE="$fixture" "$RUNNER" \
		> "$TMP_ROOT/$name.log" 2>&1; then
		printf 'error: closure accepted job mutation: %s\n' "$name" >&2
		exit 1
	fi
	chmod -R u+w "$fixture"
	rm -rf -- "$fixture"
}

chmod -R u+w "$OUT_ROOT" 2>/dev/null || true
rm -rf -- "$OUT_ROOT"
CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID=exact-fixture \
	SOURCE_OVERRIDE="$SOURCE" JOB_OVERRIDE="$JOB" "$RUNNER" >/dev/null

expect_source_reject result-tamper result.json '{"tampered":true}'
expect_source_reject rows-tamper raw/r4-e4-result-rows.txt 'tampered'
expect_source_reject summary-tamper raw/r4-e4-summary-rows.txt 'tampered'
expect_source_reject threshold-tamper derived/threshold-failures.tsv 'tampered'
expect_source_reject pinning-tamper raw/vcpu-pinning.txt 'tampered'
expect_source_reject archive-tamper raw/boot-artifacts/arm64/exec_lease.o.zst 'tampered'
expect_job_reject job-exit-tamper vm_exit_code 1

ln -s -- "$SOURCE" "$TMP_ROOT/source-link"
if CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 RUN_ID=source-root-symlink \
	SOURCE_OVERRIDE="$TMP_ROOT/source-link" JOB_OVERRIDE="$JOB" "$RUNNER" \
	> "$TMP_ROOT/source-root-symlink.log" 2>&1; then
	printf 'error: closure accepted source-root symlink\n' >&2
	exit 1
fi

printf 'all timing r7 valid-negative closure tests passed\n'
