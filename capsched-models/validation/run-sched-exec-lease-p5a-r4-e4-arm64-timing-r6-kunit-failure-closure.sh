#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_RUN_ID=20260722T-p5a-r4-e4-arm64-timing-r6
SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$SOURCE_RUN_ID"
JOB_DIR="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r6"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r6-kunit-failure-closure"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/timing-r6"
JOB_EVIDENCE_DIR="$INPUT_DIR/job-control"

RESULT_SHA=28bd8b4cc8561a1b01a4fdcbbd3d584427ce5c7cf4b8bef55085745fce5f0c53
SOURCE_MANIFEST_SHA=3b45c7249c3d50bd74ff15375aa7d883f5729bf869b4e71687f0758996cfaf1a
SOURCE_FILES=40
SOURCE_BYTES=34254159
JOB_MANIFEST_SHA=bc2849c08d64c5c0edf32a8c16d48ba32a8cf2e3cee7ba387ea271b2ceebd0b7
JOB_FILES=26
JOB_BYTES=32403
RUNNER_SHA=cd2f210304fae4be4586bb9bcf750e959513ff59e96796ad2a6b64a8a1a727db
PARSER_SHA=dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
SERIAL_SHA=616765293b86a5d5e539a81b28af26d575cc2532e8383ddf810e4cd124fa2830
KTAP_SHA=b18cf97993d1cd18a14606a692078027a8c38a639211dadbf841930caf812c05
PINNING_SHA=2550bfe4a993a2b1bb05ae96917cbb04101a61ac1b2f21e0108bec055ab3ebef
IMAGE_ARCHIVE_SHA=e3075eccf5f9918b0750122a7f3736f955d503bdc862d9ca1f59eaf525ba5173
IMAGE_SOURCE_SHA=52bacab8c679229869ba0e7c8e13ad8dbb091698b15ab9729b6a724aefd80b1c
OBJECT_ARCHIVE_SHA=f8add9ac34cd79d149630246ae9ea09134cc3104667a5364df3031ba179d4f0e
OBJECT_SOURCE_SHA=f7c5b69b24e95f169e411d3fea226a887a2dc3b43543875d49531daa3cd91837
BUILD_ROOT=/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
WORKTREE=/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID

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

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

tree_manifest()
{
	(
		cd "$1"
		find . -type f -print0 | sort -z | xargs -0 sha256sum
	)
}

tree_bytes()
{
	find "$1" -type f -printf '%s\n' |
		awk '{sum += $1} END {printf "%.0f\n", sum}'
}

verify_hash()
{
	local file=$1 expected=$2 label=$3

	[ -f "$file" ] || die "$label missing"
	[ ! -L "$file" ] || die "$label is a symlink"
	[ "$(file_sha "$file")" = "$expected" ] || die "$label hash changed"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
for command in awk cat chmod cmp cp date find grep jq mkdir sed sha256sum \
	sort tr wc xargs zstd; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for source_root in "$SOURCE_DIR" "$JOB_DIR"; do
	[ -d "$source_root" ] || die "source root missing: $source_root"
	[ ! -L "$source_root" ] || die "source root is a symlink: $source_root"
	[ -z "$(find "$source_root" -type l -print -quit)" ] ||
		die "source root contains a symlink: $source_root"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "${BASH_SOURCE[0]}")
cp -- "${BASH_SOURCE[0]}" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '10% snapshotting exact r6 failure and job control with race checks'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] ||
	die 'timing r6 artifact count changed'
[ "$(tree_bytes "$SOURCE_DIR")" = "$SOURCE_BYTES" ] ||
	die 'timing r6 artifact bytes changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-before.sha256"
[ "$(file_sha "$OUT_DIR/source-before.sha256")" = "$SOURCE_MANIFEST_SHA" ] ||
	die 'timing r6 artifact manifest changed'
[ "$(find "$JOB_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')" = "$JOB_FILES" ] ||
	die 'timing r6 job file count changed'
[ "$(tree_bytes "$JOB_DIR")" = "$JOB_BYTES" ] || die 'timing r6 job bytes changed'
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-before.sha256"
[ "$(file_sha "$OUT_DIR/job-before.sha256")" = "$JOB_MANIFEST_SHA" ] ||
	die 'timing r6 job manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
cp -a -- "$JOB_DIR/." "$JOB_EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/source-snapshot.sha256"
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-after.sha256"
tree_manifest "$JOB_EVIDENCE_DIR" > "$OUT_DIR/job-snapshot.sha256"
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-after.sha256" >/dev/null ||
	die 'timing r6 source changed while snapshotting'
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-snapshot.sha256" >/dev/null ||
	die 'timing r6 source snapshot differs'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-after.sha256" >/dev/null ||
	die 'timing r6 job control changed while snapshotting'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-snapshot.sha256" >/dev/null ||
	die 'timing r6 job snapshot differs'
chmod -R a-w "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"

progress '35% validating result semantics, exact rows, failures, and placement'
RESULT="$EVIDENCE_DIR/result.json"
SERIAL="$EVIDENCE_DIR/raw/qemu-serial.log"
KTAP="$EVIDENCE_DIR/raw/qemu-ktap.log"
verify_hash "$RESULT" "$RESULT_SHA" 'timing r6 result'
[ "$(awk 'NF {print $1; exit}' "$EVIDENCE_DIR/result.sha256")" = "$RESULT_SHA" ] ||
	die 'timing r6 result seal changed'
verify_hash "$EVIDENCE_DIR/raw/measurement-runner.sh" "$RUNNER_SHA" 'timing runner'
verify_hash "$EVIDENCE_DIR/raw/measurement-parser.sh" "$PARSER_SHA" 'measurement parser'
verify_hash "$SERIAL" "$SERIAL_SHA" 'serial log'
verify_hash "$KTAP" "$KTAP_SHA" 'KTAP log'
verify_hash "$EVIDENCE_DIR/raw/vcpu-pinning.txt" "$PINNING_SHA" 'pinning record'
jq -e '
  .schema_version == 1 and
  .run_id == "20260722T-p5a-r4-e4-arm64-timing-r6" and
  .status == "harness_failed" and .architecture == "arm64" and
  .failure.stage == "evidence_validation" and
  .failure.reason == "measurement KUnit suite did not pass" and
  .source_commit == "82d91805f8e145d2403057f656e590e4bcae12f1" and
  .architecture_measurement_valid == false and
  .run_owned_build_scratch_retired == true and
  .run_owned_worktree_retired == true and
  .x86_64_measurement_may_start == false and
  .measurement_result_accepted == false and
  .runtime_behavior_approved == false and
  .production_protection == false and .datacenter_ready == false
' "$RESULT" >/dev/null || die 'timing r6 result semantics changed'
[ ! -s "$EVIDENCE_DIR/raw/compiler-diagnostics.txt" ] ||
	die 'timing r6 compiler diagnostics are nonempty'
[ "$(cat "$EVIDENCE_DIR/raw/qemu-exit-code.txt")" = 0 ] || die 'QEMU exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_exit_code")" = 1 ] || die 'runner exit changed'
[ "$(grep -c 'R4_E4_RESULT ' "$SERIAL")" = 538 ] || die 'result row count changed'
[ "$(grep -c 'R4_E4_SUMMARY ' "$SERIAL")" = 6 ] || die 'summary count changed'
for family_count in publication:288 picker_kick:144 irq_dispatch:9 recovery:0 \
	notifier:48 current_stop:24 offline:25; do
	family=${family_count%:*}
	expected=${family_count#*:}
	actual=$(grep -c "R4_E4_RESULT family=$family " "$SERIAL" || true)
	[ "$actual" = "$expected" ] || die "timing r6 $family row count changed"
done
grep -Fxq 'not ok 4 sched_exec_r4_measure_recovery_case' "$KTAP" ||
	die 'recovery terminal changed'
grep -Fxq 'not ok 7 sched_exec_r4_measure_offline_case' "$KTAP" ||
	die 'offline terminal changed'
grep -Fxq '# sched_exec_lease_r4_measure: pass:5 fail:2 skip:0 total:7' "$KTAP" ||
	die 'suite totals changed'
[ "$(grep -c 'ASSERTION FAILED at kernel/sched/exec_lease.c:4156' "$KTAP")" = 1 ] ||
	die 'recovery assertion changed'
[ "$(grep -c 'ret == -22 (0xffffffffffffffea)' "$KTAP")" = 1 ] ||
	die 'recovery -EINVAL changed'
[ "$(grep -c 'EXPECTATION FAILED at kernel/sched/exec_lease.c:4741' "$KTAP")" = 1 ] ||
	die 'offline assertion changed'
grep -Fq 'integrity_errors == 205120 (0x32140)' "$KTAP" ||
	die 'offline integrity count changed'
[ "$((20 * (256 + 10000)))" = 205120 ] || die 'offline arithmetic changed'
for anchor in qmp_status_before_resume=prelaunch qmp_mapping_reverified=true \
	singleton_affinity_reverified=true qmp_status_after_resume=running \
	rows_before_all_vcpus_pinned=0 pinned_vcpu_threads=2 \
	qmp_pause_before_affinity=true qmp_mapping_reverified_before_resume=true; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/vcpu-pinning.txt" ||
		die "placement anchor changed: $anchor"
done
grep -Fxq 'vcpu=0 tid=75912 host_cpu=0' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" ||
	die 'vCPU 0 affinity changed'
grep -Fxq 'vcpu=1 tid=75913 host_cpu=1' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" ||
	die 'vCPU 1 affinity changed'

progress '70% losslessly validating binaries and retired scratch'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" \
	"$IMAGE_ARCHIVE_SHA" 'Image archive'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" \
	"$OBJECT_ARCHIVE_SHA" 'object archive'
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst"
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst"
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" |
	sha256sum | awk '{print $1}')" = "$IMAGE_SOURCE_SHA" ] || die 'Image restore changed'
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" |
	sha256sum | awk '{print $1}')" = "$OBJECT_SOURCE_SHA" ] ||
	die 'object restore changed'
for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run scratch leaked: $path"
	fi
done

progress '88% proving originals and closure inputs remained immutable'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-final.sha256"
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-final.sha256"
[ "$(file_sha "$OUT_DIR/source-final.sha256")" = "$SOURCE_MANIFEST_SHA" ] ||
	die 'timing r6 source changed during closure'
[ "$(file_sha "$OUT_DIR/job-final.sha256")" = "$JOB_MANIFEST_SHA" ] ||
	die 'timing r6 job control changed during closure'
[ "$(file_sha "${BASH_SOURCE[0]}")" = "$runner_initial_sha" ] ||
	die 'closure runner changed during execution'
[ -z "$(find "$INPUT_DIR" -type f -perm -222 -print -quit)" ] ||
	die 'closure inputs contain writable files'

progress '95% sealing r6 KUnit failure without threshold or x86 credit'
jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$RESULT_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg job_manifest_sha "$JOB_MANIFEST_SHA" --arg closure_runner_sha "$runner_initial_sha" \
	--arg serial_sha "$SERIAL_SHA" --arg ktap_sha "$KTAP_SHA" \
	--argjson source_files "$SOURCE_FILES" --argjson source_bytes "$SOURCE_BYTES" \
	--argjson job_files "$JOB_FILES" --argjson job_bytes "$JOB_BYTES" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-timing-r6-kunit-failure-closure-result-v1",
  run_id:$run_id,
  status:"passed_independent_arm64_timing_r6_kunit_failure_closure",
  source_run_id:$source_run_id,
  source_result_sha256:$source_result_sha,
  source_artifacts:{files:$source_files,bytes:$source_bytes,manifest_sha256:$source_manifest_sha},
  job_control:{files:$job_files,bytes:$job_bytes,manifest_sha256:$job_manifest_sha},
  closure_runner_sha256:$closure_runner_sha,
  failure:{stage:"evidence_validation",sealed_reason:"measurement KUnit suite did not pass",recovery:{setup_return:-22,classification:"coalesced_owner_handoff_race_candidate"},offline:{integrity_errors:205120,classification:"control_oracle_compared_against_treatment_occupancy",exact_factorization:"20*(256+10000)"}},
  build:{completed:true,compiler_diagnostics:0,image_and_object_losslessly_preserved:true},
  guest:{qemu_exit_code:0,suite_pass:5,suite_fail:2,suite_skip:0,suite_total:7,complete_matrix:false,result_rows:538,summary_rows:6,family_rows:{publication:288,picker_kick:144,irq_dispatch:9,recovery:0,notifier:48,current_stop:24,offline:25},partial_values_receive_threshold_credit:false,serial_sha256:$serial_sha,ktap_sha256:$ktap_sha},
  placement:{qemu_parent_allowed_cpus:"0-5",qemu_vcpu_threads_pinned:2,distinct_singleton_host_cpus:true,qmp_started_paused:true,qmp_mapping_reverified_before_resume:true,rows_before_resume:0},
  original_snapshot_race_free:true,
  snapshot_read_only:true,
  run_owned_build_scratch_retired:true,
  run_owned_worktree_retired:true,
  valid_threshold_evidence:false,
  architecture_measurement_valid:false,
  corrected_source_and_fresh_full_regression_required:true,
  x86_64_measurement_may_start:false,
  measurement_result_accepted:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
jq 'del(.run_id)' "$OUT_DIR/result.json" > "$OUT_DIR/result.normalized.json"
file_sha "$OUT_DIR/result.normalized.json" > "$OUT_DIR/result.normalized.sha256"
progress '100% r6 failure independently closed; partial rows receive no credit'
printf 'result=%s\nsha256=%s\nnormalized_sha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")" \
	"$(cat "$OUT_DIR/result.normalized.sha256")"
