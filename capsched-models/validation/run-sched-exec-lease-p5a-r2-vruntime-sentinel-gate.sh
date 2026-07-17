#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-vruntime-sentinel-gate-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0121-p5a-r2-vruntime-sentinel-gate-model"
MODEL=P5AR2VruntimeSentinelGate.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-vruntime-sentinel-gate/$RUN_ID"

die()
{
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for command_name in git grep java jq python3 sed wc; do
  command -v "$command_name" >/dev/null 2>&1 \
    || die "missing command: $command_name"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

jq -e '
  .status == "source_representation_gate_no_linux_patch_approved" and
  .counterexample.signed_delta_result == -101 and
  .counterexample.literal_sentinel_rejected == true and
  .representation_contract.explicit_validity_required == true and
  .representation_contract.numeric_value_ignored_when_invalid == true and
  .representation_contract.numeric_value_required_when_valid == true and
  .representation_contract.wrap_aware_minimum_required == true and
  .representation_contract.boolean_only_summary_rejected == true and
  .representation_contract.field_placement_approved == false and
  .picker_contract.validity_checked_before_vruntime_eligible == true and
  .picker_contract.current_entity_checked_separately == true and
  .group_contract.group_entity_projects_child_aggregate == true and
  .group_contract.runqueue_lock_ownership_required == true and
  .group_contract.enqueue_dequeue_only_refresh_rejected == true and
  .formal.unsafe_cfg_count == 18 and
  .formal.unsafe_expected_counterexamples == 18 and
  (.safety_flags | all(.[]; . == false)) and
  .next.linux_behavior_patch_allowed_after_this_gate == false
' "$CONFIG" >/dev/null

expected_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.linux_tree' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify HEAD^{tree})
[ "$actual_commit" = "$expected_commit" ] \
  || die "Linux commit mismatch: expected=$expected_commit actual=$actual_commit"
[ "$actual_tree" = "$expected_tree" ] \
  || die "Linux tree mismatch: expected=$expected_tree actual=$actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] \
  || die 'Linux tracked working tree is dirty'

anchor_ledger="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchor_ledger"
while IFS= read -r row; do
  id=$(printf '%s\n' "$row" | jq -r '.id')
  relative_path=$(printf '%s\n' "$row" | jq -r '.path')
  pattern=$(printf '%s\n' "$row" | jq -r '.pattern')
  file="$WORKSPACE_DIR/$relative_path"
  if [ -f "$file" ] && grep -Fq "$pattern" "$file"; then
    status=ok
  else
    status=missing
  fi
  printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$relative_path" "$pattern" \
    >> "$anchor_ledger"
done < <(jq -c '.source_anchors[]' "$CONFIG")

anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchor_ledger")
[ "$anchor_count" = 16 ] || die "unexpected source anchor count: $anchor_count"
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

python3 - <<'PY' > "$OUT_DIR/vruntime-sentinel-counterexample.json"
import json

mask = (1 << 64) - 1
sentinel = mask
real_vruntime = 100
delta = (sentinel - real_vruntime) & mask
signed_delta = delta - (1 << 64) if delta >= (1 << 63) else delta
print(json.dumps({
    "sentinel": sentinel,
    "real_vruntime": real_vruntime,
    "u64_delta": delta,
    "signed_delta": signed_delta,
    "vruntime_cmp_sentinel_greater_than_real": signed_delta > 0,
}, indent=2))
PY
jq -e '
  .signed_delta == -101 and
  .vruntime_cmp_sentinel_greater_than_real == false
' "$OUT_DIR/vruntime-sentinel-counterexample.json" >/dev/null

(
  cd "$MODEL_DIR"
  java -cp "$TLA_JAR" tlc2.TLC -deadlock \
    -metadir "$OUT_DIR/tlc-safe-states" \
    -config P5AR2VruntimeSentinelGateSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" \
  || die 'safe TLC model did not pass'

safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_states=${safe_states:-0}
safe_distinct=${safe_distinct:-0}
safe_depth=${safe_depth:-0}

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2VruntimeSentinelGateUnsafe*.cfg; do
  name=$(basename "$cfg" .cfg)
  log="$OUT_DIR/tlc-$name.log"
  if (
    cd "$MODEL_DIR"
    java -cp "$TLA_JAR" tlc2.TLC -deadlock \
      -metadir "$OUT_DIR/states-$name" \
      -config "$(basename "$cfg")" "$MODEL"
  ) > "$log" 2>&1; then
    printf 'unsafe config unexpectedly passed: %s\n' "$(basename "$cfg")" >&2
    unsafe_failures=$((unsafe_failures + 1))
  elif grep -q 'Invariant Safety is violated' "$log"; then
    unsafe_expected=$((unsafe_expected + 1))
  else
    printf 'unsafe config failed unexpectedly: %s\n' "$(basename "$cfg")" >&2
    tail -n 60 "$log" >&2
    unsafe_failures=$((unsafe_failures + 1))
  fi
done

[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2VruntimeSentinelGateUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$cfg_count" = 18 ] || die "unsafe config count mismatch: $cfg_count"
[ "$unsafe_expected" = 18 ] || die "unsafe counterexample count mismatch: $unsafe_expected"

jq -n \
  --arg run_id "$RUN_ID" \
  --arg linux_commit "$actual_commit" \
  --arg linux_tree "$actual_tree" \
  --arg config "$CONFIG" \
  --arg model_dir "$MODEL_DIR" \
  --arg tla_jar "$TLA_JAR" \
  --argjson source_anchor_count "$anchor_count" \
  --argjson source_anchor_failures "$anchor_failures" \
  --argjson safe_states_generated "$safe_states" \
  --argjson safe_distinct_states "$safe_distinct" \
  --argjson safe_depth "$safe_depth" \
  --argjson unsafe_expected_counterexamples "$unsafe_expected" \
  '{
    schema_version: 1,
    run_id: $run_id,
    status: "passed",
    linux_commit: $linux_commit,
    linux_tree: $linux_tree,
    config: $config,
    model_dir: $model_dir,
    tla_jar: $tla_jar,
    source_anchor_count: $source_anchor_count,
    source_anchor_failures: $source_anchor_failures,
    literal_u64max_signed_delta: -101,
    literal_u64max_is_vruntime_infinity: false,
    explicit_validity_plus_wrap_min_required: true,
    safe_passed: true,
    safe_states_generated: $safe_states_generated,
    safe_distinct_states: $safe_distinct_states,
    safe_depth: $safe_depth,
    unsafe_expected_counterexamples: $unsafe_expected_counterexamples,
    linux_patch_approved: false,
    runtime_behavior_approved: false,
    protection_claim: false,
    cost_claim: false
  }' > "$OUT_DIR/result.json"

cat "$OUT_DIR/result.json"
