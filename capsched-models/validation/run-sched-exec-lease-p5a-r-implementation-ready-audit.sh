#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r-implementation-ready-audit-v1.json"
PATCH_PLAN_CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r-ordinary-cfs-patch-plan-v1.json"
PATCH_PLAN_RUNNER="$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.sh"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0111-p5a-r-implementation-ready-audit-model"
MODEL="P5ARImplementationReadyAudit.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-implementation-ready-audit/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq java grep sed find wc; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "missing command: $cmd" >&2
		exit 1
	fi
done

if [ ! -f "$TLA_JAR" ]; then
	echo "missing TLA jar: $TLA_JAR" >&2
	exit 1
fi

jq empty "$CONFIG" "$PATCH_PLAN_CONFIG"

expected_linux_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_linux_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
if [ "$actual_linux_commit" != "$expected_linux_commit" ]; then
	echo "linux commit mismatch: expected=$expected_linux_commit actual=$actual_linux_commit" >&2
	exit 1
fi

jq -e '
	.readiness.ordinary_cfs_only == true and
	.readiness.linux_0009_may_be_drafted == true and
	.readiness.linux_0009_exists == false and
	.readiness.linux_0009_accepted == false and
	.readiness.runtime_denial_approved == false and
	.readiness.cfs_deny_and_repick_approved == false and
	.readiness.broad_move_denial_approved == false and
	((.required_validations | length) == .required_counts.required_validation_count) and
	((.required_models | length) == .required_counts.required_model_count) and
	((.must_hold_for_0009_draft | length) == .required_counts.must_hold_for_0009_draft_count) and
	((.acceptance_required_before_claims | length) == .required_counts.acceptance_required_before_claims_count) and
	(.formal.safe_passed == true) and
	(.formal.unsafe_cfg_count == 10) and
	(.formal.unsafe_expected_counterexamples == 10) and
	all(.safety_flags[]; . == false)
' "$CONFIG" >/dev/null

jq -e '
	.scope.linux_behavior_patch_may_be_drafted == true and
	.scope.linux_patch_accepted == false and
	.scope.runtime_denial_approved == false and
	.scope.cfs_deny_and_repick_approved == false and
	.required_code_shape.pre_settle_candidate_rejection == true and
	.required_code_shape.attempt_local_carrier == true and
	.required_code_shape.unsupported_cross_paths_excluded_or_settled == true
' "$PATCH_PLAN_CONFIG" >/dev/null

missing_validation=0
validation_file="$OUT_DIR/required-validations.tsv"
printf 'path\tstatus\n' > "$validation_file"
while IFS= read -r path; do
	full="$CAPSCHED_DIR/capsched-models/$path"
	if [ -f "$full" ] && grep -qi 'passed' "$full"; then
		status=present_passed
	else
		status=missing_or_not_passed
		missing_validation=$((missing_validation + 1))
	fi
	printf '%s\t%s\n' "$path" "$status" >> "$validation_file"
done < <(jq -r '.required_validations[]' "$CONFIG")

if [ "$missing_validation" -ne 0 ]; then
	echo "required validation missing or not passed: $missing_validation" >&2
	cat "$validation_file" >&2
	exit 1
fi

missing_model=0
model_file="$OUT_DIR/required-models.tsv"
printf 'path\tstatus\n' > "$model_file"
while IFS= read -r path; do
	full="$CAPSCHED_DIR/capsched-models/$path"
	if [ -d "$full" ]; then
		status=present
	else
		status=missing
		missing_model=$((missing_model + 1))
	fi
	printf '%s\t%s\n' "$path" "$status" >> "$model_file"
done < <(jq -r '.required_models[]' "$CONFIG")

if [ "$missing_model" -ne 0 ]; then
	echo "required formal model missing: $missing_model" >&2
	cat "$model_file" >&2
	exit 1
fi

series="$WORKSPACE_DIR/linux-patches/patches/capsched-linux-l0/series"
if grep -q '^0009-' "$series"; then
	echo "0009 patch already exists; audit must be refreshed after code draft" >&2
	tail -20 "$series" >&2
	exit 1
fi
if ! grep -qx '0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch' "$series"; then
	echo "series does not end at expected 0008 basis" >&2
	tail -20 "$series" >&2
	exit 1
fi

RUN_ID="${RUN_ID}-patch-plan" "$PATCH_PLAN_RUNNER" > "$OUT_DIR/patch-plan-runner.json"
jq empty "$OUT_DIR/patch-plan-runner.json"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" -config P5ARImplementationReadyAuditSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1

if ! grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log"; then
	echo "safe TLC model did not pass" >&2
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	exit 1
fi

state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5ARImplementationReadyAuditUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-$name-states" -config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		echo "unsafe config unexpectedly passed: $(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		echo "unsafe config failed for unexpected reason: $(basename "$cfg")" >&2
		tail -80 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5ARImplementationReadyAuditUnsafe*.cfg' | wc -l)
if [ "$unsafe_fail" -ne 0 ] || [ "$unsafe_expected" -ne 10 ] || [ "$cfg_count" -ne 10 ]; then
	echo "unsafe counterexample mismatch: expected=10 actual=$unsafe_expected cfg_count=$cfg_count failures=$unsafe_fail" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF_JSON
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "linux_commit": "$actual_linux_commit",
  "required_validation_count": $(jq '.required_validations | length' "$CONFIG"),
  "missing_validation_count": $missing_validation,
  "required_model_count": $(jq '.required_models | length' "$CONFIG"),
  "missing_model_count": $missing_model,
  "linux_0009_may_be_drafted": true,
  "linux_0009_exists": false,
  "linux_0009_accepted": false,
  "runtime_denial_approved": false,
  "cfs_deny_and_repick_approved": false,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF_JSON

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
