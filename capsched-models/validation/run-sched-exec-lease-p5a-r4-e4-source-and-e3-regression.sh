#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_GATE="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-local-quantum-source-gate.sh"
E3_REGRESSION="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-e3-six-profile-regression.sh"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-2}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-and-e3-regression"
OUT_DIR="$OUT_ROOT/$RUN_ID"
SOURCE_RUN_ID="$RUN_ID-source"
CONFIG_RUN_ID="$RUN_ID-config-smoke"
REGRESSION_RUN_ID="$RUN_ID-e3-regression"
SOURCE_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate/$SOURCE_RUN_ID/result.json"
CONFIG_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$CONFIG_RUN_ID/config-smoke-result.json"
REGRESSION_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$REGRESSION_RUN_ID/result.json"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '[progress] %s\n' "$*"
	if [ -n "$PROGRESS_FILE" ]; then
		printf '%s\n' "$*" > "$PROGRESS_FILE"
	fi
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$JOBS" in
	''|*[!0-9]*) die 'JOBS must be a positive integer' ;;
esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be greater than zero'
for command in jq sha256sum; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for script in "$SOURCE_GATE" "$E3_REGRESSION"; do
	if [ ! -x "$script" ] || [ -L "$script" ]; then
		die "runner is not executable: $script"
	fi
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "output already exists: $OUT_DIR"
fi
mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

progress '2% starting exact source and six-object dual-architecture gate'
RUN_ID="$SOURCE_RUN_ID" JOBS="$JOBS" PROGRESS_FILE="$PROGRESS_FILE" "$SOURCE_GATE"
if [ ! -f "$SOURCE_RESULT" ] || [ -L "$SOURCE_RESULT" ]; then
	die 'source-gate result missing'
fi
jq -e '
  .status == "passed_source_and_object_gate_awaiting_six_profile_e3_regression" and
  .candidate_commit == "1dac9953b1b5c326a27285b1f2a6e4fac9960a1d" and
  .fresh_objects == 6 and .w1_compiler_diagnostics == 0 and
  .disabled_e4_artifacts == 0 and .e3_cases_byte_preserved == 36 and
  .six_profile_e3_regression_required == true and
  .timing_measurement_may_start == false
' "$SOURCE_RESULT" >/dev/null
SOURCE_RESULT_SHA=$(sha256sum "$SOURCE_RESULT" | awk '{print $1}')

progress '22% source gate passed; resolving all six E3 regression configs without build or boot'
E4_SOURCE_GATE_RESULT="$SOURCE_RESULT" CONFIG_SMOKE_ONLY=1 \
	RUN_ID="$CONFIG_RUN_ID" JOBS="$JOBS" PROGRESS_FILE="$PROGRESS_FILE" \
	"$E3_REGRESSION"
if [ ! -f "$CONFIG_RESULT" ] || [ -L "$CONFIG_RESULT" ]; then
	die 'config-smoke result missing'
fi
jq -e '
  .status == "passed_e4_candidate_six_profile_e3_config_smoke_without_build_or_boot" and
  .candidate_commit == "1dac9953b1b5c326a27285b1f2a6e4fac9960a1d" and
  .builds_started == 0 and .boots_started == 0 and
  .e4_measurement_suite_enabled == false and
  .timing_measurement_may_start == false
' "$CONFIG_RESULT" >/dev/null
CONFIG_RESULT_SHA=$(sha256sum "$CONFIG_RESULT" | awk '{print $1}')

progress '30% configs passed; starting complete fresh six-profile E3 build/boot regression'
E4_SOURCE_GATE_RESULT="$SOURCE_RESULT" RUN_ID="$REGRESSION_RUN_ID" \
	JOBS="$JOBS" PROGRESS_FILE="$PROGRESS_FILE" "$E3_REGRESSION"
if [ ! -f "$REGRESSION_RESULT" ] || [ -L "$REGRESSION_RESULT" ]; then
	die 'six-profile regression result missing'
fi
jq -e '
  .status == "passed_six_profile_e3_regression_awaiting_independent_closure" and
  .candidate_commit == "1dac9953b1b5c326a27285b1f2a6e4fac9960a1d" and
  .total_passed_cases == 216 and .total_receipts == 216 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
  .warning_reports == 0 and .six_profile_e3_regression_passed == true and
  .e4_measurement_suite_enabled == false and
  .timing_measurement_may_start == false and
  .r4_e4_source_accepted == false and .datacenter_ready == false
' "$REGRESSION_RESULT" >/dev/null
REGRESSION_RESULT_SHA=$(sha256sum "$REGRESSION_RESULT" | awk '{print $1}')

jq -n --arg run_id "$RUN_ID" \
	--arg source_result "$SOURCE_RESULT" --arg source_sha "$SOURCE_RESULT_SHA" \
	--arg config_result "$CONFIG_RESULT" --arg config_sha "$CONFIG_RESULT_SHA" \
	--arg regression_result "$REGRESSION_RESULT" --arg regression_sha "$REGRESSION_RESULT_SHA" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e4-source-and-e3-regression-result-v1",run_id:$run_id,status:"passed_source_and_six_profile_e3_regression_awaiting_independent_closure",candidate_commit:"1dac9953b1b5c326a27285b1f2a6e4fac9960a1d",source_gate_result:$source_result,source_gate_result_sha256:$source_sha,config_smoke_result:$config_result,config_smoke_result_sha256:$config_sha,e3_regression_result:$regression_result,e3_regression_result_sha256:$regression_sha,fresh_source_objects:6,e3_profiles:6,e3_cases_passed:216,e3_receipts:216,independent_closure_required:true,timing_measurement_may_start:false,r4_e4_source_accepted:false,real_scheduler_attachment:false,runtime_behavior_approved:false,production_protection:false,deployment_ready:false,multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e '.status == "passed_source_and_six_profile_e3_regression_awaiting_independent_closure" and .fresh_source_objects == 6 and .e3_profiles == 6 and .e3_cases_passed == 216 and .e3_receipts == 216 and .independent_closure_required == true and .timing_measurement_may_start == false and .r4_e4_source_accepted == false and .production_protection == false and .datacenter_ready == false' \
	"$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% source and E3 regression passed; independent closure still required before timing'
printf 'result=%s\n' "$OUT_DIR/result.json"
