#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
SOURCE_RUN_ID=20260717T-p5a-r4-e3-source-gate-r2
SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-source-gate/$SOURCE_RUN_ID"
SOURCE_RESULT="$SOURCE_DIR/result.json"
INVALID_R1_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-source-gate/20260717T-p5a-r4-e3-source-gate-r1/result.json"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-source-gate-closure"
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/source-gate-evidence"
PROGRESS_FILE=${PROGRESS_FILE:-}

SOURCE_RESULT_SHA=7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27
INVALID_R1_RESULT_SHA=fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a
SOURCE_RUNNER_SHA=61d0a4968b21bf595b710947e11369ca7dfe9316fec91767bedd21f760055cde
PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
N133_R13_SHA=79a9c62edc8dfa58645028c9ab43af9554f7672bbae267f8b5c7ab0c9157c912
N133_R14_SHA=2be94265244a7cde6ff5f4d353133fa6315b692b65ad762b743ac0a89d309537
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
SOURCE_MANIFEST_SHA=376f56af0659f6456a28085210441e0941cf2482c498a0dd537b78745c27708e
ARM_RESULT_SHA=39f67681971e03cd0e7fb6740f717aec45c39200923daab226402e98c1c3efe2
X86_RESULT_SHA=56217fc651947f80ca0241ff8ab0493d6498e90876cde3ec37f159220c0dbaff
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
E2_COMMIT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
E3_COMMIT=f9c737c93ecff48c6f512048b05b1b49f4a54ca5
E3_TREE=274f7b5d6969dc68e158819191fe598f9587e0ad
E3_DIFF_SHA=c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781
EXPECTED_ARTIFACTS=105

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

tree_manifest()
{
	local root=$1

	(
		cd "$root"
		find . -type f -print0 | sort -z | xargs -0 sha256sum
	)
}

case "$RUN_ID" in
	[A-Za-z0-9]* ) ;;
	* ) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac

for command in awk cmp cp diff find git grep jq mkdir sha256sum sort wc xargs; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -d "$SOURCE_DIR" ] || die 'canonical corrected source-gate evidence missing'
[ ! -L "$SOURCE_DIR" ] || die 'source-gate evidence root is a symlink'
[ -f "$SOURCE_RESULT" ] || die 'canonical corrected source-gate result missing'
[ ! -L "$SOURCE_RESULT" ] || die 'source-gate result is a symlink'
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'source-gate evidence contains a symlink'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$EXPECTED_ARTIFACTS" ] || die 'source-gate artifact count changed'

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(sha256sum "$RUNNER_SOURCE" | awk '{print $1}')
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '5% snapshotting every canonical source-gate artifact'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-before.sha256"
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot-artifacts.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/source-artifacts-after.sha256" > "$OUT_DIR/source-artifacts-race.diff" || die 'source evidence changed while snapshotting'
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/snapshot-artifacts.sha256" > "$OUT_DIR/source-vs-snapshot.diff" || die 'evidence snapshot differs from source'
chmod -R a-w "$EVIDENCE_DIR"

RESULT="$EVIDENCE_DIR/result.json"
progress '15% validating result, immutable inputs, and negative attempt history'
[ "$(sha256sum "$RESULT" | awk '{print $1}')" = "$SOURCE_RESULT_SHA" ] || die 'corrected source-gate result hash changed'
[ "$(awk '{print $1}' "$EVIDENCE_DIR/result.sha256")" = "$SOURCE_RESULT_SHA" ] || die 'corrected source-gate seal changed'
[ "$(sha256sum "$EVIDENCE_DIR/inputs/runner.sh" | awk '{print $1}')" = "$SOURCE_RUNNER_SHA" ] || die 'corrected source runner snapshot changed'
[ "$(sha256sum "$EVIDENCE_DIR/inputs/plan.json" | awk '{print $1}')" = "$PLAN_SHA" ] || die 'plan snapshot changed'
[ "$(sha256sum "$EVIDENCE_DIR/inputs/n133-r13-result.json" | awk '{print $1}')" = "$N133_R13_SHA" ] || die 'N-133 r13 snapshot changed'
[ "$(sha256sum "$EVIDENCE_DIR/inputs/n133-r14-result.json" | awk '{print $1}')" = "$N133_R14_SHA" ] || die 'N-133 r14 snapshot changed'
[ "$(sha256sum "$EVIDENCE_DIR/inputs/immutable-evidence-inputs.sh" | awk '{print $1}')" = "$HARDENING_LIB_SHA" ] || die 'hardening helper snapshot changed'
[ "$(sha256sum "$INVALID_R1_RESULT" | awk '{print $1}')" = "$INVALID_R1_RESULT_SHA" ] || die 'invalid r1 result history changed'
grep -Eiq 'Clock skew detected|modification time .* in the future' \
	"$(dirname "$INVALID_R1_RESULT")/x86_64-e3-layout-on-test-off-build.log" || die 'r1 negative warning evidence missing'
grep -Eiq 'Clock skew detected|modification time .* in the future' \
	"$(dirname "$INVALID_R1_RESULT")/x86_64-e3-test-on-build.log" || die 'r1 second negative warning evidence missing'

jq -e '
	.status == "passed_source_gate_awaiting_six_boot_diagnostic_matrix" and
	.candidate_commit == "f9c737c93ecff48c6f512048b05b1b49f4a54ca5" and
	.candidate_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
	.candidate_tree == "274f7b5d6969dc68e158819191fe598f9587e0ad" and
	.candidate_diff_sha256 == "c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781" and
	.primary_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
	.patch_queue_commit == "16bb080da472ffabbbafd2698073eca633fb0602" and
	.immutable_input_snapshots_verified == true and
	.isolated_git_object_worktrees == true and
	.exact_direct_e2_child == true and .exact_two_file_boundary == true and
	.insertions == 2758 and .deletions == 0 and
	.e2_private_layout_and_58_probes_preserved == true and
	.existing_expanded_51_values_preserved == true and
	.config_default_off == true and .same_translation_unit == true and
	.suite_name == "sched_exec_lease_r4_concurrency" and
	.deterministic_case_families == 36 and .allocation_fault_sites == 6 and
	.hard_timeout_seconds == 15 and .stress_iterations == 2048 and
	.strict_checkpatch == {errors:0,warnings:0,checks:0} and
	.w1_compiler_diagnostics == 0 and .clock_skew_retries == 0 and
	.final_clock_skew_warnings == 0 and
	.architectures == ["arm64","x86_64"] and
	.disabled_e3_symbols_relocations_strings_initcalls == 0 and
	.results.arm64.status == "passed" and .results.x86_64.status == "passed" and
	.diagnostic_matrix_may_start == true and
	.r4_e3_source_accepted == false and
	.r4_e3_concurrency_correctness_accepted == false and
	.primary_linux_changed == false and .patch_queue_changed == false and
	.runtime_scheduler_hook_approved == false and .runtime_behavior_approved == false and
	.runtime_denial_correctness == false and .production_protection == false and
	.deployment_ready == false and .multi_node_ready == false and
	.multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null

progress '35% auditing all build logs, configs, diffs, and value tables'
[ "$(find "$EVIDENCE_DIR" -maxdepth 1 -name '*-build.log' -type f | wc -l | tr -d ' ')" = 8 ] || die 'build-log count changed'
[ "$(find "$EVIDENCE_DIR" -maxdepth 1 -name '*-clock-skew-verification.log' -type f | wc -l | tr -d ' ')" = 8 ] || die 'verification-log count changed'
[ -z "$(find "$EVIDENCE_DIR" -maxdepth 1 -name '*-clock-skew-verification.log' -type f -size +0c -print)" ] || die 'unexpected verification-build output with zero retries'
if grep -Eihn 'Clock skew detected|modification time .* in the future|:[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' \
	"$EVIDENCE_DIR"/*-build.log > "$OUT_DIR/build-warning-scan.txt"; then
	die 'corrected source-gate build warning found'
fi
: > "$OUT_DIR/build-warning-scan.txt"
[ -z "$(find "$EVIDENCE_DIR" -name '*.diff' ! -name 'e3-source.diff' -type f -size +0c -print)" ] || die 'unexpected nonempty comparison diff'
[ ! -s "$EVIDENCE_DIR/forbidden-runtime-surfaces.txt" ] || die 'forbidden runtime surface recorded'
grep -q '^total: 0 errors, 0 warnings, 0 checks,' "$EVIDENCE_DIR/checkpatch.log" || die 'strict checkpatch totals changed'
[ "$(wc -l < "$EVIDENCE_DIR/actual-cases.txt" | tr -d ' ')" = 36 ] || die 'case count changed'
[ "$(wc -l < "$EVIDENCE_DIR/actual-fault-sites.txt" | tr -d ' ')" = 6 ] || die 'fault count changed'
diff -u <(jq -r '.required_case_families[] | "sched_exec_r4_test_" + .' "$EVIDENCE_DIR/inputs/plan.json") \
	"$EVIDENCE_DIR/actual-cases.txt" > "$OUT_DIR/closure-cases.diff" || die 'case set/order changed'
diff -u <(jq -r '.capacity_and_allocation.allocation_fault_sites[] | ascii_upcase' "$EVIDENCE_DIR/inputs/plan.json") \
	"$EVIDENCE_DIR/actual-fault-sites.txt" > "$OUT_DIR/closure-fault-sites.diff" || die 'fault-site set/order changed'
for arch in arm64 x86_64; do
	[ "$(wc -l < "$EVIDENCE_DIR/$arch/e2-private.tsv" | tr -d ' ')" = 58 ] || die "$arch private table count changed"
	[ "$(wc -l < "$EVIDENCE_DIR/$arch/e2-expanded.tsv" | tr -d ' ')" = 51 ] || die "$arch expanded table count changed"
done
[ "$(sha256sum "$EVIDENCE_DIR/source-file-hashes.tsv" | awk '{print $1}')" = "$SOURCE_MANIFEST_SHA" ] || die 'source manifest hash changed'
[ "$(sha256sum "$EVIDENCE_DIR/arm64/result.json" | awk '{print $1}')" = "$ARM_RESULT_SHA" ] || die 'arm64 child result changed'
[ "$(sha256sum "$EVIDENCE_DIR/x86_64/result.json" | awk '{print $1}')" = "$X86_RESULT_SHA" ] || die 'x86_64 child result changed'
jq -e --slurpfile child "$EVIDENCE_DIR/arm64/result.json" '.results.arm64 == $child[0]' "$RESULT" >/dev/null
jq -e --slurpfile child "$EVIDENCE_DIR/x86_64/result.json" '.results.x86_64 == $child[0]' "$RESULT" >/dev/null

progress '60% recomputing candidate Git identity and every source blob'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^")" = "$E2_COMMIT" ] || die 'candidate is no longer a direct E2 child'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^{tree}")" = "$E3_TREE" ] || die 'candidate tree changed'
[ "$(git -C "$LINUX_DIR" rev-parse refs/heads/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'local candidate ref changed'
[ "$(git -C "$LINUX_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'fork candidate ref changed'
git -C "$LINUX_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" > "$OUT_DIR/recomputed-e3-source.diff"
[ "$(sha256sum "$OUT_DIR/recomputed-e3-source.diff" | awk '{print $1}')" = "$E3_DIFF_SHA" ] || die 'candidate diff changed'
cmp "$OUT_DIR/recomputed-e3-source.diff" "$EVIDENCE_DIR/e3-source.diff" || die 'retained candidate diff mismatch'
[ "$(git -C "$LINUX_DIR" diff --name-only "$E2_COMMIT..$E3_COMMIT" | sort | tr '\n' ' ')" = 'init/Kconfig kernel/sched/exec_lease.c ' ] || die 'candidate escaped two-file boundary'
[ "$(git -C "$LINUX_DIR" diff --numstat "$E2_COMMIT..$E3_COMMIT" | awk '{a += $1; d += $2} END {print a+0, d+0}')" = '2758 0' ] || die 'candidate additive size changed'
[ "$(wc -l < "$EVIDENCE_DIR/source-file-hashes.tsv" | tr -d ' ')" = 13 ] || die 'source manifest row count changed'
while IFS=$'\t' read -r label file_path expected working; do
	[ "$label" = tree ] && continue
	case "$label" in
		primary) commit=$PRIMARY_COMMIT ;;
		e2) commit=$E2_COMMIT ;;
		e3) commit=$E3_COMMIT ;;
		*) die "unknown source manifest label: $label" ;;
	esac
	[ "$expected" = "$working" ] || die "working/source blob mismatch: $label/$file_path"
	[ "$(git -C "$LINUX_DIR" rev-parse "$commit:$file_path")" = "$expected" ] || die "Git/source blob mismatch: $label/$file_path"
done < "$EVIDENCE_DIR/source-file-hashes.tsv"
[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux checkout is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] || die 'patch queue is dirty'
[ -z "$(find "$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees" -mindepth 1 -maxdepth 1 -print -quit)" ] || die 'temporary worktree leaked'
[ ! -e "$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r4-e3-source-gate/$SOURCE_RUN_ID" ] || die 'source-gate build scratch leaked'

progress '85% sealing N-134 closure and claim boundary'
[ "$(sha256sum "$RUNNER_SOURCE" | awk '{print $1}')" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(sha256sum "$INPUT_DIR/closure-runner.sh" | awk '{print $1}')" = "$runner_initial_sha" ] || die 'closure runner snapshot changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-artifacts-final.sha256"
diff -u "$OUT_DIR/source-artifacts-before.sha256" "$OUT_DIR/source-artifacts-final.sha256" > "$OUT_DIR/source-artifacts-final.diff" || die 'source evidence changed during audit'
snapshot_manifest_sha=$(sha256sum "$OUT_DIR/snapshot-artifacts.sha256" | awk '{print $1}')

jq -n \
	--arg run_id "$RUN_ID" \
	--arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$SOURCE_RESULT_SHA" \
	--arg invalid_r1_sha "$INVALID_R1_RESULT_SHA" \
	--arg closure_runner "$INPUT_DIR/closure-runner.sh" \
	--arg closure_runner_sha "$runner_initial_sha" \
	--arg artifact_manifest "$OUT_DIR/snapshot-artifacts.sha256" \
	--arg artifact_manifest_sha "$snapshot_manifest_sha" \
	--arg candidate "$E3_COMMIT" \
	--arg parent "$E2_COMMIT" \
	--arg tree "$E3_TREE" \
	--arg diff_sha "$E3_DIFF_SHA" \
	--argjson artifact_count "$EXPECTED_ARTIFACTS" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e3-source-gate-closure-result-v1",run_id:$run_id,status:"passed_r4_e3_source_gate_closure_authorizing_six_boot_diagnostic_matrix",source_gate_run_id:$source_run_id,source_gate_result_sha256:$source_result_sha,invalid_attempt_1_result_sha256:$invalid_r1_sha,closure_runner:$closure_runner,closure_runner_sha256:$closure_runner_sha,artifact_snapshot_manifest:$artifact_manifest,artifact_snapshot_manifest_sha256:$artifact_manifest_sha,artifact_count:$artifact_count,all_artifacts_snapshotted_read_only:true,source_artifact_race_check_passed:true,candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,exact_direct_e2_child:true,exact_two_file_boundary:true,insertions:2758,deletions:0,build_logs_audited:8,w1_compiler_diagnostics:0,clock_skew_retries:0,final_clock_skew_warnings:0,architectures:["arm64","x86_64"],fresh_modes_per_architecture:4,r4_private_values_preserved:58,existing_expanded_values_preserved:51,disabled_e3_symbols_relocations_strings_initcalls:0,deterministic_case_families:36,allocation_fault_sites:6,strict_checkpatch:{errors:0,warnings:0,checks:0},primary_linux_changed:false,patch_queue_changed:false,n134_complete:true,six_boot_diagnostic_matrix_may_start:true,r4_e3_source_accepted:false,r4_e3_concurrency_correctness_accepted:false,runtime_scheduler_hook_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,monitor_delivery_or_enforcement:false,cross_class_coverage:false,bounded_wall_clock_latency_claim:false,performance_claim:false,cost_claim:false,production_protection:false,deployment_ready:false,multi_node_ready:false,multi_cluster_ready:false,datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
jq -e '.status == "passed_r4_e3_source_gate_closure_authorizing_six_boot_diagnostic_matrix" and .artifact_count == 105 and .n134_complete == true and .six_boot_diagnostic_matrix_may_start == true and .r4_e3_source_accepted == false and .production_protection == false and .datacenter_ready == false' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$INPUT_DIR"
progress '100% N-134 source-gate closure passed; exact six-boot matrix may start'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
