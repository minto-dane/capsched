#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-post-n135-authorization-gate.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/authorization-gate-tests/p5a-r4-post-n135-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-post-n135-authorization-gate-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT/test-good-$$" "$OUT_ROOT/test-config-tamper-$$" "$OUT_ROOT/test-overclaim-$$" "$OUT_ROOT/test-symlink-$$" 2>/dev/null || true
	find "$FIXTURE_ROOT" -depth -delete 2>/dev/null || true
	find "$OUT_ROOT/test-good-$$" "$OUT_ROOT/test-config-tamper-$$" "$OUT_ROOT/test-overclaim-$$" "$OUT_ROOT/test-symlink-$$" -depth -delete 2>/dev/null || true
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'authorization runner is not executable'
[ -f "$CONFIG" ] || die 'authorization config missing'
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONFIG" "$FIXTURE_ROOT/good.json"

RUN_ID="test-good-$$" AUTH_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 CONFIG_OVERRIDE="$FIXTURE_ROOT/good.json" "$RUNNER" >/dev/null

jq '.evidence.closure_r1_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"' "$CONFIG" > "$FIXTURE_ROOT/config-tamper.json"
config_tamper_sha=$(sha256sum "$FIXTURE_ROOT/config-tamper.json" | awk '{print $1}')
if RUN_ID="test-config-tamper-$$" AUTH_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 TEST_CONFIG_SHA="$config_tamper_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/config-tamper.json" "$RUNNER" >/dev/null 2>&1; then
	die 'authorization gate accepted a tampered evidence hash'
fi

jq '.authorization_after_gate_pass.r4_e4_source_may_be_created = true' "$CONFIG" > "$FIXTURE_ROOT/overclaim.json"
overclaim_sha=$(sha256sum "$FIXTURE_ROOT/overclaim.json" | awk '{print $1}')
if RUN_ID="test-overclaim-$$" AUTH_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 TEST_CONFIG_SHA="$overclaim_sha" CONFIG_OVERRIDE="$FIXTURE_ROOT/overclaim.json" "$RUNNER" >/dev/null 2>&1; then
	die 'authorization gate accepted an R4-E4 source overclaim'
fi

ln -s "$CONFIG" "$FIXTURE_ROOT/symlink.json"
if RUN_ID="test-symlink-$$" AUTH_GATE_TEST_MODE=1 OFFLINE_TEST_MODE=1 CONFIG_OVERRIDE="$FIXTURE_ROOT/symlink.json" "$RUNNER" >/dev/null 2>&1; then
	die 'authorization gate accepted a symlinked config'
fi

printf 'passed: exact config accepted; evidence tamper, E4-source overclaim, and symlink rejected\n'
