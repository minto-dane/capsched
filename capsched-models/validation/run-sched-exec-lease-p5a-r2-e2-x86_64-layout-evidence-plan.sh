#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-e2-x86_64-layout-evidence-plan-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0127-p5a-r2-e2-x86_64-layout-evidence-plan-model"
MODEL=P5AR2E2X8664LayoutEvidencePlan.tla
TLA_JAR=${TLA_JAR:-"$WORKSPACE_DIR/build/tools/tla/tla2tools.jar"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-x86_64-layout-evidence-plan/$RUN_ID"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in awk find git grep java jq sed sha256sum wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
[ -f "$TLA_JAR" ] || die "missing TLA jar: $TLA_JAR"
mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_primary=$(jq -r '.source.primary_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] || die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^{tree})" = "$expected_tree" ] || die 'candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] || die 'candidate dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = \
	'0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'

arm_result="$WORKSPACE_DIR/$(jq -r '.prerequisites.arm64_e2_result' "$CONFIG")"
[ "$(sha256sum "$arm_result" | awk '{print $1}')" = \
	"$(jq -r '.prerequisites.arm64_e2_result_sha256' "$CONFIG")" ] || die 'arm64 result hash mismatch'
jq -e '.status == "passed" and .architecture == "arm64" and .arm64_layout_envelope_passed == true and .candidate_probe_symbol_count == 59 and .changed_e1_symbol_value_count == 0' "$arm_result" >/dev/null

jq -e '
  .status == "x86_64_e2_cross_build_plan_no_source_change" and
  .toolchain.build_host_architecture == "arm64" and
  .toolchain.target_architecture == "x86_64" and
  .toolchain.kernel_arch == "x86_64" and
  .toolchain.cross_compile_prefix == "x86_64-linux-gnu-" and
  .toolchain.same_toolchain_for_e1_and_candidate == true and
  .toolchain.cross_build_is_runtime_evidence == false and
  (.build_matrix | all(.[]; . == true)) and
  .symbol_contract.e1_symbols == 51 and
  .symbol_contract.candidate_added_symbols == 8 and
  .symbol_contract.candidate_total_symbols == 59 and
  .symbol_contract.cacheline_table_fields == 27 and
  .symbol_contract.missing_e1_symbols_allowed == 0 and
  .symbol_contract.changed_e1_values_allowed == 0 and
  .x86_64_baseline == {sched_entity_size:320,cfs_rq_size:384,rq_size:3392,task_struct_size:3328} and
  .delta_limits.sched_entity_max == 8 and
  .delta_limits.cfs_rq_required == 0 and
  .delta_limits.rq_max == 32 and
  .delta_limits.task_struct_required == 0 and
  (.source_anchors | length == 18) and
  (.absence_checks | length == 4) and
  .formal.unsafe_cfg_count == 24 and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$anchors"
while IFS='|' read -r id path pattern commit; do
	if [ -n "$commit" ]; then
		actual=$(git -C "$WORKSPACE_DIR/$path" rev-parse HEAD)
		[ "$actual" = "$commit" ] && status=ok || status=missing
	elif grep -Fq "$pattern" "$WORKSPACE_DIR/$path"; then
		status=ok
	else
		status=missing
	fi
	printf '%s\t%s\t%s\t%s%s\n' "$id" "$status" "$path" "$pattern" "$commit" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .path, (.pattern // ""), (.git_commit // "")] | join("|")' "$CONFIG")
anchor_count=$(jq '.source_anchors | length' "$CONFIG")
anchor_failures=$(awk -F '\t' 'NR > 1 && $2 != "ok" {c++} END {print c+0}' "$anchors")
[ "$anchor_failures" = 0 ] || die "source anchor failures: $anchor_failures"

absence="$OUT_DIR/absence-checks.tsv"
printf 'id\tstatus\tpath\tpattern\n' > "$absence"
while IFS='|' read -r id path pattern; do
	if git -C "$WORKSPACE_DIR/$path" grep -Fq "$pattern" -- .; then status=present; else status=absent; fi
	printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$path" "$pattern" >> "$absence"
done < <(jq -r '.absence_checks[] | [.id, .path, .pattern] | join("|")' "$CONFIG")
absence_failures=$(awk -F '\t' 'NR > 1 && $2 != "absent" {c++} END {print c+0}' "$absence")
[ "$absence_failures" = 0 ] || die "absence failures: $absence_failures"

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock -metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2E2X8664LayoutEvidencePlanSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1
grep -q 'Model checking completed. No error has been found' "$OUT_DIR/tlc-safe.log" || die 'safe TLC failed'
safe_states=$(sed -n 's/^\([0-9][0-9]*\) states generated.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_distinct=$(sed -n 's/^[0-9][0-9]* states generated, \([0-9][0-9]*\) distinct states found.*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -n 1)

unsafe_expected=0
unsafe_failures=0
for cfg in "$MODEL_DIR"/P5AR2E2X8664LayoutEvidencePlanUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (cd "$MODEL_DIR" && java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/states-$name" -config "$(basename "$cfg")" "$MODEL") > "$log" 2>&1; then
		unsafe_failures=$((unsafe_failures + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		unsafe_failures=$((unsafe_failures + 1))
	fi
done
cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2E2X8664LayoutEvidencePlanUnsafe*.cfg' | wc -l | tr -d ' ')
[ "$unsafe_failures" = 0 ] || die "unsafe TLC failures: $unsafe_failures"
[ "$cfg_count" = 24 ] && [ "$unsafe_expected" = 24 ] || die 'unsafe TLC count mismatch'

jq -n \
	--arg run_id "$RUN_ID" --arg primary_commit "$expected_primary" --arg candidate_commit "$expected_candidate" \
	--argjson anchor_count "$anchor_count" --argjson anchor_failures "$anchor_failures" \
	--argjson absence_failures "$absence_failures" --argjson safe_states "${safe_states:-0}" \
	--argjson safe_distinct "${safe_distinct:-0}" --argjson safe_depth "${safe_depth:-0}" \
	--argjson unsafe_expected "$unsafe_expected" \
	'{schema_version:1,run_id:$run_id,status:"passed_plan_only",target_architecture:"x86_64",build_host_architecture:"arm64",cross_compile_prefix:"x86_64-linux-gnu-",primary_commit:$primary_commit,candidate_commit:$candidate_commit,source_anchor_count:$anchor_count,source_anchor_failures:$anchor_failures,absence_failures:$absence_failures,safe_states_generated:$safe_states,safe_distinct_states:$safe_distinct,safe_depth:$safe_depth,unsafe_expected_counterexamples:$unsafe_expected,e1_symbols:51,candidate_added_symbols:8,candidate_total_symbols:59,cacheline_table_fields:27,source_change_approved:false,layout_candidate_accepted:false,e3_rebuild_approved:false,runtime_evidence:false,protection_claim:false}' \
	> "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
