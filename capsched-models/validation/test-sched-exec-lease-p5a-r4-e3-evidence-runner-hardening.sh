#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LIB="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json"
RUN_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan"
TEST_TAG="hardening-test-$$"
TMP_DIR=$(mktemp -d)

cleanup()
{
	rm -rf -- "$TMP_DIR" \
		"$RUN_ROOT/$TEST_TAG-existing" \
		"$RUN_ROOT/$TEST_TAG-symlink" \
		"$RUN_ROOT/$TEST_TAG-plan"
}
trap cleanup EXIT

fail()
{
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

# shellcheck source=lib/immutable-evidence-inputs.sh
# The path is derived from this script directory.
# shellcheck disable=SC1091
. "$LIB"

for value in run1 20260717T-plan-r7 A_b.c-9; do
	capsched_validate_run_id "$value" || fail "valid RUN_ID rejected: $value"
done

for value in '' . .. .hidden -option ../escape a/b 'space value'; do
	if capsched_validate_run_id "$value"; then
		fail "invalid RUN_ID accepted: $value"
	fi
done

fresh_root="$TMP_DIR/fresh-root"
capsched_create_fresh_run_dir "$fresh_root" run1 \
	|| fail 'fresh run directory rejected'
if capsched_create_fresh_run_dir "$fresh_root" run1; then
	fail 'existing run directory accepted'
fi
ln -s "$TMP_DIR" "$fresh_root/symlink-run"
if capsched_create_fresh_run_dir "$fresh_root" symlink-run; then
	fail 'symlink run directory accepted'
fi

printf 'immutable evidence\n' > "$TMP_DIR/source"
source_sha=$(capsched_sha256_file "$TMP_DIR/source")
capsched_snapshot_verified_file "$TMP_DIR/source" "$source_sha" "$TMP_DIR/snapshot" \
	|| fail 'valid evidence snapshot rejected'
printf 'mutated after snapshot\n' > "$TMP_DIR/source"
capsched_verify_file_sha256 "$TMP_DIR/snapshot" "$source_sha" \
	|| fail 'snapshot changed with mutable source'
if capsched_snapshot_verified_file "$TMP_DIR/source" "$source_sha" "$TMP_DIR/bad-snapshot"; then
	fail 'wrong-hash evidence snapshot accepted'
fi
ln -s "$TMP_DIR/snapshot" "$TMP_DIR/symlink-source"
if capsched_snapshot_verified_file "$TMP_DIR/symlink-source" "$source_sha" "$TMP_DIR/symlink-snapshot"; then
	fail 'symlink evidence source accepted'
fi

mkdir -p -- "$RUN_ROOT/$TEST_TAG-existing"
if RUN_ID="$TEST_TAG-existing" "$RUNNER" >"$TMP_DIR/existing.out" 2>"$TMP_DIR/existing.err"; then
	fail 'runner reused an existing output directory'
fi
grep -Fq 'run output directory is not fresh' "$TMP_DIR/existing.err" \
	|| fail 'existing-directory rejection was not explicit'

ln -s "$TMP_DIR" "$RUN_ROOT/$TEST_TAG-symlink"
if RUN_ID="$TEST_TAG-symlink" "$RUNNER" >"$TMP_DIR/symlink.out" 2>"$TMP_DIR/symlink.err"; then
	fail 'runner followed a symlink output directory'
fi
grep -Fq 'run output directory is not fresh' "$TMP_DIR/symlink.err" \
	|| fail 'symlink-directory rejection was not explicit'

jq '.formal.unsafe_faults[0] as $fault | .formal.unsafe_faults = [range(0; 76) | $fault]' \
	"$CONFIG" > "$TMP_DIR/substituted-plan.json"
if RUN_ID="$TEST_TAG-plan" CAPSCHED_PLAN_CONFIG="$TMP_DIR/substituted-plan.json" \
	"$RUNNER" >"$TMP_DIR/plan.out" 2>"$TMP_DIR/plan.err"; then
	fail 'runner accepted a count-preserving substituted plan'
fi
grep -Fq 'plan config snapshot failed exact hash binding' "$TMP_DIR/plan.err" \
	|| fail 'substituted-plan rejection was not exact-hash based'

printf 'PASS: RUN_ID, fresh-output, exact-plan, and immutable-snapshot controls\n'
