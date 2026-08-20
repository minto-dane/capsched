#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary.sh"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-v1.json"
FIXTURE_ROOT="$WORKSPACE_DIR/build/authorization-gate-tests/p5a-r6-post-e3-$$"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-post-e3-authorization-threat-boundary-test"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	chmod -R u+w "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-post-e3-*-"$$" \
		2>/dev/null || true
	find "$FIXTURE_ROOT" "$OUT_ROOT"/test-r6-post-e3-*-"$$" \
		-depth -delete 2>/dev/null || true
}

run_fixture()
{
	local name=$1 file=$2 sha

	sha=$(sha256sum "$file" | awk '{print $1}')
	RUN_ID="test-r6-post-e3-$name-$$" AUTH_TEST_MODE=1 \
		OFFLINE_TEST_MODE=1 PREFLIGHT_ONLY=1 \
		TEST_CONFIG_SHA="$sha" CONFIG_OVERRIDE="$file" \
		"$RUNNER"
}

expect_reject()
{
	local name=$1 file=$2

	if run_fixture "$name" "$file" >/dev/null 2>&1; then
		die "authorization gate accepted mutation: $name"
	fi
}

trap cleanup EXIT INT TERM
[ -x "$RUNNER" ] || die 'authorization runner is not executable'
[ -f "$CONFIG" ] && [ ! -L "$CONFIG" ] ||
	die 'canonical config is missing or unsafe'
mkdir -p "$FIXTURE_ROOT"
cp -- "$CONFIG" "$FIXTURE_ROOT/good.json"
run_fixture good "$FIXTURE_ROOT/good.json" >/dev/null

jq '.r6_e3_evidence.source_gate_result_sha256 = "tampered"' "$CONFIG" \
	> "$FIXTURE_ROOT/evidence-hash.json"
expect_reject evidence-hash "$FIXTURE_ROOT/evidence-hash.json"

jq '.threat_model.repository_version = "tampered"' "$CONFIG" \
	> "$FIXTURE_ROOT/threat-version.json"
expect_reject threat-version "$FIXTURE_ROOT/threat-version.json"

jq '.threat_model.sha256 = "tampered"' "$CONFIG" \
	> "$FIXTURE_ROOT/threat-hash.json"
expect_reject threat-hash "$FIXTURE_ROOT/threat-hash.json"

jq '.upstream_drift_freshness.touched_path_drift_classified = "unclassified"' \
	"$CONFIG" > "$FIXTURE_ROOT/unclassified-drift.json"
expect_reject unclassified-drift "$FIXTURE_ROOT/unclassified-drift.json"

jq '.source_identity.allowed_files += ["kernel/sched/fair.c"]' "$CONFIG" \
	> "$FIXTURE_ROOT/source-scope.json"
expect_reject source-scope "$FIXTURE_ROOT/source-scope.json"

jq '.authorization_after_gate_pass.live_scheduler_attachment_allowed = true' \
	"$CONFIG" > "$FIXTURE_ROOT/live-scheduler.json"
expect_reject live-scheduler "$FIXTURE_ROOT/live-scheduler.json"

jq '.safety_flags.monitor_verified = true' "$CONFIG" \
	> "$FIXTURE_ROOT/monitor.json"
expect_reject monitor "$FIXTURE_ROOT/monitor.json"

jq '.safety_flags.production_protection = true' "$CONFIG" \
	> "$FIXTURE_ROOT/production.json"
expect_reject production "$FIXTURE_ROOT/production.json"

ln -s "$CONFIG" "$FIXTURE_ROOT/symlink.json"
if RUN_ID="test-r6-post-e3-symlink-$$" AUTH_TEST_MODE=1 \
	OFFLINE_TEST_MODE=1 PREFLIGHT_ONLY=1 \
	TEST_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')" \
	CONFIG_OVERRIDE="$FIXTURE_ROOT/symlink.json" "$RUNNER" >/dev/null 2>&1; then
	die 'authorization gate accepted a symlinked config'
fi

printf '%s\n' \
	'passed: exact contract accepted; evidence/threat/drift/scope/overclaim mutations and symlink rejected'
