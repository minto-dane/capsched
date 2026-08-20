#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_RUN_ID=20260721T-p5a-r4-e4-arm64-timing-r3
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$SOURCE_RUN_ID"
CANONICAL_JOB_DIR="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r3"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
SOURCE_OVERRIDE=${SOURCE_OVERRIDE:-}
JOB_OVERRIDE=${JOB_OVERRIDE:-}

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ "$PREFLIGHT_ONLY" = 1 ] || { printf 'error: test mode requires PREFLIGHT_ONLY=1\n' >&2; exit 1; }
	[ -n "$SOURCE_OVERRIDE" ] || { printf 'error: test mode requires SOURCE_OVERRIDE\n' >&2; exit 1; }
	[ -n "$JOB_OVERRIDE" ] || { printf 'error: test mode requires JOB_OVERRIDE\n' >&2; exit 1; }
	SOURCE_DIR=$SOURCE_OVERRIDE
	JOB_DIR=$JOB_OVERRIDE
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r3-storage-failure-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] || { printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2; exit 1; }
	[ -z "$SOURCE_OVERRIDE$JOB_OVERRIDE" ] || { printf 'error: overrides are restricted to test mode\n' >&2; exit 1; }
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	JOB_DIR=$CANONICAL_JOB_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r3-storage-failure-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/timing-r3"
JOB_EVIDENCE_DIR="$INPUT_DIR/job-control"
RESULT_SHA=a35076dc95800d34c39bf3cc38f6e6a7c429aac69a8c1bb88278b48f4669a689
SOURCE_MANIFEST_SHA=8cbb4b23f48d715bd8a6ae617accf2af52cc1505611588c76411900a6dbc1521
SOURCE_FILES=38
SOURCE_BYTES=33701110
JOB_MANIFEST_SHA=f943abaf9518840eb427ed0c6b1d002d6c10f765aff537c77156698d6383c1f1
JOB_FILES=5
JOB_BYTES=26396
RUNNER_SNAPSHOT_SHA=8b7ae0d18636f5027fd741527b0b5d1b8b5c5323fb62272c3a47cb5d17942fb2
PARSER_SHA=dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
QMP_CONTROL_SHA=e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e
PLAN_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
CONFIG_SHA=2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b
BUILD_LOG_SHA=38739810e1a75be5270b7c29e63acc359d545d3921c6d04afb18d9b8e5a4d61c
SERIAL_SHA=720cc56e40d3d8110f8fe5ef2ec5f1f9a72a4e76547a453633b76647327c50cb
PINNING_SHA=88be44cda8d6a358510ec4736d13905db1704534e59ff264cbdfbaa6fc821330
QMP_MAPPING_SHA=f6eb33c4718d052a48e7dc06eddd31681e6f7b593767abc3c10dff689f74638c
QMP_AFFINITY_SHA=a0bb0bc5e8ca27069b05594a843b6b32c105981d20991fd38d4e95cd45438464
BOOT_MANIFEST_SHA=d406fa66ec3cd2c2bb7fc8918a10c397a3c899b1479daed045c1ed7babf31335
IMAGE_SOURCE_SHA=6da56c6fff27a885589b84343fe6e049e31e3dba639a8a8b8acc175f222ee0a2
IMAGE_ARCHIVE_SHA=2a71464e0fd78844f421bcb210d87365721f7811c7390e31d5349c61f3ea51cc
OBJECT_SOURCE_SHA=3a3097dd7d36456498273e5e27e8e8e33173288c791380d44517293f24a2440c
OBJECT_ARCHIVE_SHA=eddd242cfb6038283c30928439238796a76257e57c1842c100576065cbae6c88
JOB_LOG_SHA=2126474e77bc1849a800953e8ce8517bf196cee29083d23fda2215799d6c3e22
VM_EXIT_SHA=4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865
VM_TRIM_EXIT_SHA=9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa
VM_TRIM_LOG_SHA=c07809f1514b7e03ba017b8f7322e0cc3c973f4676e227407d49f894f17939e4
VM_FINISHED_SHA=fa1e9c10ca642975d6e623d9f574d19dbc76fb48f0114c8116d28f64461a87bf
BUILD_ROOT=/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
WORKTREE=/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
JOB_INPUTS=(job.log vm-trim.log vm_exit_code vm_finished_at vm_trim_exit_code)

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
	find "$1" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}'
}

job_manifest()
{
	(
		cd "$1"
		printf '%s\0' "${JOB_INPUTS[@]}" | sort -z | xargs -0 sha256sum
	)
}

job_bytes()
{
	local file sum=0
	for file in "${JOB_INPUTS[@]}"; do
		sum=$((sum + $(stat -c %s "$1/$file")))
	done
	printf '%s\n' "$sum"
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
case "$CLOSURE_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid closure mode' ;;
esac
for command in awk chmod cmp cp diff find grep jq mkdir sed sha256sum sort \
	stat tr wc xargs zstd; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
for source_root in "$SOURCE_DIR" "$JOB_DIR"; do
	if [ ! -d "$source_root" ] || [ -L "$source_root" ]; then
		die "unsafe source root: $source_root"
	fi
done
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'timing r3 evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] \
	|| die 'timing r3 evidence contains a non-regular object'
for file in "${JOB_INPUTS[@]}"; do
	if [ ! -f "$JOB_DIR/$file" ] || [ -L "$JOB_DIR/$file" ]; then
		die "job-control input is unsafe: $file"
	fi
done

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '10% snapshotting exact timing r3 storage-failure evidence with race checks'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r3 artifact count changed'
[ "$(tree_bytes "$SOURCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r3 artifact byte count changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-before.sha256"
[ "$(file_sha "$OUT_DIR/source-before.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r3 artifact manifest changed'
[ "$(job_bytes "$JOB_DIR")" = "$JOB_BYTES" ] || die 'timing r3 job-control byte count changed'
job_manifest "$JOB_DIR" > "$OUT_DIR/job-before.sha256"
[ "$(file_sha "$OUT_DIR/job-before.sha256")" = "$JOB_MANIFEST_SHA" ] \
	|| die 'timing r3 job-control manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
for file in "${JOB_INPUTS[@]}"; do
	cp -a -- "$JOB_DIR/$file" "$JOB_EVIDENCE_DIR/$file"
done
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot.sha256"
job_manifest "$JOB_DIR" > "$OUT_DIR/job-after.sha256"
job_manifest "$JOB_EVIDENCE_DIR" > "$OUT_DIR/job-snapshot.sha256"
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-after.sha256" >/dev/null \
	|| die 'timing r3 evidence changed while snapshotting'
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/snapshot.sha256" >/dev/null \
	|| die 'timing r3 evidence snapshot differs'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-after.sha256" >/dev/null \
	|| die 'timing r3 job control changed while snapshotting'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-snapshot.sha256" >/dev/null \
	|| die 'timing r3 job-control snapshot differs'
[ "$(find "$EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r3 snapshot count changed'
[ "$(tree_bytes "$EVIDENCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r3 snapshot bytes changed'
[ "$(find "$JOB_EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$JOB_FILES" ] \
	|| die 'timing r3 job snapshot count changed'
chmod -R a-w "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"

progress '35% auditing sealed failure, exact ENOSPC root cause, and QMP placement'
RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$RESULT_SHA" 'timing r3 failure result'
[ "$(awk 'NF {print $1; exit}' "$EVIDENCE_DIR/result.sha256")" = "$RESULT_SHA" ] \
	|| die 'timing r3 result seal changed'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1" and
  .run_id == "20260721T-p5a-r4-e4-arm64-timing-r3" and
  .status == "harness_failed" and .architecture == "arm64" and
  .failure.stage == "qemu_boot" and
  .failure.reason == "runner exited unexpectedly with code 1" and
  .source_commit == "5857720dedc49f89d2367442f8fdb1a806ffa1cc" and
  .architecture_measurement_valid == false and
  .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true and
  .x86_64_measurement_may_start == false and .measurement_result_accepted == false and
  .real_scheduler_attachment == false and .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null || die 'timing r3 failure semantic contract changed'
verify_hash "$EVIDENCE_DIR/raw/measurement-runner.sh" "$RUNNER_SNAPSHOT_SHA" 'timing r3 runner snapshot'
verify_hash "$EVIDENCE_DIR/raw/measurement-parser.sh" "$PARSER_SHA" 'timing r3 parser snapshot'
verify_hash "$EVIDENCE_DIR/raw/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'timing r3 warning classifier'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpu-control.py" "$QMP_CONTROL_SHA" 'timing r3 QMP helper'
verify_hash "$EVIDENCE_DIR/raw/measurement-plan.json" "$PLAN_SHA" 'timing r3 plan snapshot'
verify_hash "$EVIDENCE_DIR/raw/arm64.config" "$CONFIG_SHA" 'timing r3 config'
verify_hash "$EVIDENCE_DIR/raw/build.log" "$BUILD_LOG_SHA" 'timing r3 build log'
verify_hash "$EVIDENCE_DIR/raw/qemu-serial.log" "$SERIAL_SHA" 'timing r3 serial log'
verify_hash "$EVIDENCE_DIR/raw/vcpu-pinning.txt" "$PINNING_SHA" 'timing r3 pinning record'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpus.txt" "$QMP_MAPPING_SHA" 'timing r3 QMP mapping'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" "$QMP_AFFINITY_SHA" 'timing r3 QMP affinity'
verify_hash "$JOB_EVIDENCE_DIR/job.log" "$JOB_LOG_SHA" 'timing r3 job log'
verify_hash "$JOB_EVIDENCE_DIR/vm_exit_code" "$VM_EXIT_SHA" 'timing r3 VM exit code'
verify_hash "$JOB_EVIDENCE_DIR/vm_trim_exit_code" "$VM_TRIM_EXIT_SHA" 'timing r3 trim exit code'
verify_hash "$JOB_EVIDENCE_DIR/vm-trim.log" "$VM_TRIM_LOG_SHA" 'timing r3 trim log'
verify_hash "$JOB_EVIDENCE_DIR/vm_finished_at" "$VM_FINISHED_SHA" 'timing r3 finish time'
[ "$(grep -c 'No space left on device' "$JOB_EVIDENCE_DIR/job.log")" = 1 ] \
	|| die 'timing r3 ENOSPC cardinality changed'
grep -Fq 'progress: No space left on device' "$JOB_EVIDENCE_DIR/job.log" \
	|| die 'timing r3 ENOSPC did not originate at progress record'
grep -Fxq '[progress] 88% arm64 QEMU measurement rows 397/682' "$JOB_EVIDENCE_DIR/job.log" \
	|| die 'timing r3 last durable progress changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_exit_code")" = 1 ] || die 'timing r3 VM runner exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_trim_exit_code")" = 0 ] || die 'timing r3 trim exit changed'
grep -Fxq '/: 317.1 GiB (340478111744 bytes) trimmed on /dev/vdb' "$JOB_EVIDENCE_DIR/vm-trim.log" \
	|| die 'timing r3 trim evidence changed'
[ ! -s "$EVIDENCE_DIR/raw/compiler-diagnostics.txt" ] || die 'timing r3 compiler diagnostics are nonempty'
grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y' "$EVIDENCE_DIR/raw/arm64.config" \
	|| die 'timing r3 measurement config is disabled'
grep -Fxq 'CONFIG_NR_CPUS=2' "$EVIDENCE_DIR/raw/arm64.config" || die 'timing r3 guest topology changed'
grep -Fxq 'qmp_status=prelaunch' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r3 QMP was not paused'
grep -Fxq 'vcpu=0 tid=578597' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r3 vCPU 0 mapping changed'
grep -Fxq 'vcpu=1 tid=578598' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r3 vCPU 1 mapping changed'
grep -Fxq 'vcpu=0 tid=578597 host_cpu=0' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" || die 'timing r3 vCPU 0 affinity changed'
grep -Fxq 'vcpu=1 tid=578598 host_cpu=1' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" || die 'timing r3 vCPU 1 affinity changed'
for anchor in qmp_status_before_resume=prelaunch qmp_mapping_reverified=true \
	singleton_affinity_reverified=true qmp_status_after_resume=running \
	rows_before_all_vcpus_pinned=0 pinned_vcpu_threads=2 \
	qmp_pause_before_affinity=true qmp_mapping_reverified_before_resume=true; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/vcpu-pinning.txt" \
		|| die "timing r3 placement proof changed: $anchor"
done
grep -Fq ' -S -name guest=20260721T-p5a-r4-e4-arm64-timing-r3,debug-threads=on ' "$EVIDENCE_DIR/raw/qemu-command.txt" \
	|| die 'timing r3 paused QEMU command changed'
grep -Fq ' -qmp unix:[run-owned qmp.sock],server=on,wait=off ' "$EVIDENCE_DIR/raw/qemu-command.txt" \
	|| die 'timing r3 QMP command changed'
[ "$(grep -c 'R4_E4_RESULT ' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 399 ] \
	|| die 'timing r3 partial result-row cardinality changed'
[ "$(grep -c 'R4_E4_SUMMARY ' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 1 ] \
	|| die 'timing r3 partial summary cardinality changed'
grep -Fq 'R4_E4_SUMMARY family=publication rows=288 rejected_cells=240 harness_errors=0' \
	"$EVIDENCE_DIR/raw/qemu-serial.log" || die 'timing r3 publication summary changed'
grep -Fq '# Subtest: sched_exec_lease_r4_measure' "$EVIDENCE_DIR/raw/qemu-serial.log" \
	|| die 'timing r3 measurement suite did not start'
grep -Fq 'terminating on signal 15' "$EVIDENCE_DIR/raw/qemu-serial.log" \
	|| die 'timing r3 QEMU termination record missing'

progress '65% losslessly verifying preserved Image and object archives'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" "$BOOT_MANIFEST_SHA" 'timing r3 boot manifest'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" "$IMAGE_ARCHIVE_SHA" 'timing r3 Image archive'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" "$OBJECT_ARCHIVE_SHA" 'timing r3 object archive'
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst"
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst"
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" | sha256sum | awk '{print $1}')" = "$IMAGE_SOURCE_SHA" ] \
	|| die 'timing r3 Image restore hash changed'
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" | sha256sum | awk '{print $1}')" = "$OBJECT_SOURCE_SHA" ] \
	|| die 'timing r3 object restore hash changed'
for anchor in \
	"image_source_sha256=$IMAGE_SOURCE_SHA" "image_archive_sha256=$IMAGE_ARCHIVE_SHA" \
	"object_source_sha256=$OBJECT_SOURCE_SHA" "object_archive_sha256=$OBJECT_ARCHIVE_SHA" \
	'compression=zstd-level-9-lossless' 'restore_verified=true'; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" \
		|| die "timing r3 boot manifest changed: $anchor"
done

progress '82% proving original stability, retired scratch, and closure immutability'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-final.sha256"
[ "$(file_sha "$OUT_DIR/source-final.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r3 original changed during closure'
job_manifest "$JOB_DIR" > "$OUT_DIR/job-final.sha256"
[ "$(file_sha "$OUT_DIR/job-final.sha256")" = "$JOB_MANIFEST_SHA" ] \
	|| die 'timing r3 job control changed during closure'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] \
	|| die 'closure runner snapshot changed'
[ -z "$(find "$INPUT_DIR" -type f -perm -222 -print -quit)" ] \
	|| die 'timing r3 closure inputs contain writable files'
for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "timing r3 run-owned scratch leaked: $path"
	fi
done

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% exact timing r3 storage-failure closure fixture passed; no result published'
	exit 0
fi

progress '94% sealing timing r3 host-storage failure without partial measurement credit'
jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$RESULT_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg job_manifest_sha "$JOB_MANIFEST_SHA" --arg closure_runner_sha "$runner_initial_sha" \
	--arg runner_snapshot_sha "$RUNNER_SNAPSHOT_SHA" --arg serial_sha "$SERIAL_SHA" \
	--arg pinning_sha "$PINNING_SHA" --arg trim_log_sha "$VM_TRIM_LOG_SHA" \
	--argjson source_files "$SOURCE_FILES" --argjson source_bytes "$SOURCE_BYTES" \
	--argjson job_files "$JOB_FILES" --argjson job_bytes "$JOB_BYTES" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-timing-storage-failure-closure-result-v1",
  run_id:$run_id,
  status:"passed_independent_arm64_timing_host_storage_failure_closure",
  source_run_id:$source_run_id,
  source_result_sha256:$source_result_sha,
  source_artifacts:{files:$source_files,bytes:$source_bytes,manifest_sha256:$source_manifest_sha},
  job_control:{files:$job_files,bytes:$job_bytes,manifest_sha256:$job_manifest_sha},
  closure_runner_sha256:$closure_runner_sha,
  timing_runner_snapshot_sha256:$runner_snapshot_sha,
  failure:{stage:"qemu_boot",sealed_reason:"runner exited unexpectedly with code 1",root_cause:"host progress record write returned ENOSPC",last_durable_progress_rows:397,serial_result_rows:399,serial_summary_rows:1},
  build:{completed:true,compiler_diagnostics:0,image_and_object_losslessly_preserved:true},
  guest:{suite_started:true,complete_matrix:false,publication_summary_rows:288,publication_rejected_cells_observed:240,partial_values_receive_threshold_credit:false,qemu_terminated_by_harness:true,serial_sha256:$serial_sha},
  placement:{qemu_parent_allowed_cpus:"0-1",qemu_vcpu_threads_pinned:2,distinct_singleton_host_cpus:true,qmp_started_paused:true,qmp_mapping_reverified_before_resume:true,rows_before_resume:0,pinning_record_sha256:$pinning_sha},
  storage_recovery:{vm_trim_exit_code:0,vm_trimmed_bytes:340478111744,vm_trim_log_sha256:$trim_log_sha},
  original_snapshot_race_free:true,
  snapshot_read_only:true,
  run_owned_build_scratch_retired:true,
  run_owned_worktree_retired:true,
  valid_threshold_evidence:false,
  architecture_measurement_valid:false,
  host_capacity_harness_and_fresh_arm64_retry_required:true,
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
progress '100% timing r3 host-storage failure independently closed; partial rows have no measurement or x86 credit'
printf 'result=%s\nsha256=%s\nnormalized_sha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")" \
	"$(cat "$OUT_DIR/result.normalized.sha256")"
