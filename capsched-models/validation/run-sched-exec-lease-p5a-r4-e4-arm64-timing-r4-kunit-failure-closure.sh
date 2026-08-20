#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_RUN_ID=20260721T-p5a-r4-e4-arm64-timing-r4
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$SOURCE_RUN_ID"
CANONICAL_JOB_DIR="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r4"
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
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r4-kunit-failure-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] || { printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2; exit 1; }
	[ -z "$SOURCE_OVERRIDE$JOB_OVERRIDE" ] || { printf 'error: overrides are restricted to test mode\n' >&2; exit 1; }
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	JOB_DIR=$CANONICAL_JOB_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r4-kunit-failure-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/timing-r4"
JOB_EVIDENCE_DIR="$INPUT_DIR/job-control"
RESULT_SHA=f5f06d933700f74b96f13397fa3b84a7a7a2875e1fcbb19e33b37d825a0132d4
SOURCE_MANIFEST_SHA=8bc9818722eea33262db2851145b256b0a63027588a9d66266a210184489bcb8
SOURCE_FILES=40
SOURCE_BYTES=34231272
JOB_MANIFEST_SHA=8bc7853e05321905767696d36b3b9e198ea84485bf5bc065fce8637bcddedb29
JOB_FILES=8
JOB_BYTES=29738
RUNNER_SNAPSHOT_SHA=2fe52b6e9bfbc57ccca43c6e45fc3c18b15e196967822c34743b202480385e69
PARSER_SHA=dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
QMP_CONTROL_SHA=e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e
PLAN_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
CONFIG_SHA=2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b
BUILD_LOG_SHA=c0fcb6c012fe3ee656852a12a270827799bfde0c141855f09b56ae805810df95
SERIAL_SHA=b84ad85b925053b6fbc77634fecb1ce750e458807983273214bdb9a99a62f2b4
KTAP_SHA=cdaef7bf58399052bf859240c30c62cd82c90814b2b925f816377dbb9f2d9494
PINNING_SHA=b69b7ac1ddfd39faa791b38c27b7e6bd0c9bd7e208ea705eca7f6c553e674a92
QMP_MAPPING_SHA=f28a2332166aa2429aaa90974621c6a271887d8d59473f7898e3fc495c2c2bef
QMP_AFFINITY_SHA=e252250afc29f148c287534d901607965bdaffac5c789b66e29a0cc3a9fbdc39
BOOT_MANIFEST_SHA=4f042906b07931039e2fa6b08cca519eceb8fa5b491c41e7324b2dbd48b2a7aa
IMAGE_SOURCE_SHA=187277b995e89da579e18c6fc8e408e3f48b35aaaf7b4c156b71142a39e3fa1e
IMAGE_ARCHIVE_SHA=cc6e2a604a8065b1106d46f1b37c2d7a57094da7372ec60a717e470ee913859f
OBJECT_SOURCE_SHA=a9eabecade00fc36750c28d7c6bcf088bfc0c276e390a370daccb0e257338fa4
OBJECT_ARCHIVE_SHA=cb952e3e23999278ab0eb77a7cbefdb89280f6feb9ee7aa4a03939a25b8fba56
JOB_LOG_SHA=bc2ef105bb6e52dde15ca5ab73aeaa6246a9e086ac6e4f6ae38e7e9283fe8904
PRE_RUN_STORAGE_SHA=2c7fac4930b449e71c15be306d245b3d329ca526a60dfd7e172a599603c86a4a
PRE_RUN_TRIM_SHA=c7e92ab3483eced536d8b7e070904d37f0d22b02b9544c4ea12b1b8f86f7fa6c
POST_RUN_TRIM_SHA=1edbb5ccc974cb2f0377350fbf4e5ef9f3748f0f30c7fbdc56a9e6d2d46cdd33
VM_FINISHED_SHA=e561041637d586b2ea092b88ea2746cd45e1d0b7274857d11e5a17f0aecc0f5f
BUILD_ROOT=/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
WORKTREE=/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
JOB_INPUTS=(job.log vm-pre-run-storage.txt vm-pre-run-trim.log vm_pre_run_trim_exit_code vm-trim.log vm_trim_exit_code vm_exit_code vm_finished_at)

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
for command in awk chmod cmp cp find grep jq mkdir sed sha256sum sort stat tr wc xargs zstd; do
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
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'timing r4 evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] \
	|| die 'timing r4 evidence contains a non-regular object'
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

progress '10% snapshotting exact timing r4 KUnit-failure evidence with race checks'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r4 artifact count changed'
[ "$(tree_bytes "$SOURCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r4 artifact byte count changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-before.sha256"
[ "$(file_sha "$OUT_DIR/source-before.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r4 artifact manifest changed'
[ "$(job_bytes "$JOB_DIR")" = "$JOB_BYTES" ] || die 'timing r4 job-control byte count changed'
job_manifest "$JOB_DIR" > "$OUT_DIR/job-before.sha256"
[ "$(file_sha "$OUT_DIR/job-before.sha256")" = "$JOB_MANIFEST_SHA" ] \
	|| die 'timing r4 job-control manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
for file in "${JOB_INPUTS[@]}"; do
	cp -a -- "$JOB_DIR/$file" "$JOB_EVIDENCE_DIR/$file"
done
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot.sha256"
job_manifest "$JOB_DIR" > "$OUT_DIR/job-after.sha256"
job_manifest "$JOB_EVIDENCE_DIR" > "$OUT_DIR/job-snapshot.sha256"
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-after.sha256" >/dev/null \
	|| die 'timing r4 evidence changed while snapshotting'
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/snapshot.sha256" >/dev/null \
	|| die 'timing r4 evidence snapshot differs'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-after.sha256" >/dev/null \
	|| die 'timing r4 job control changed while snapshotting'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-snapshot.sha256" >/dev/null \
	|| die 'timing r4 job-control snapshot differs'
[ "$(find "$EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r4 snapshot count changed'
[ "$(tree_bytes "$EVIDENCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r4 snapshot bytes changed'
[ "$(find "$JOB_EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$JOB_FILES" ] \
	|| die 'timing r4 job snapshot count changed'
chmod -R a-w "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"

progress '35% auditing sealed failure, exact KUnit terminals, rows, and placement'
RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$RESULT_SHA" 'timing r4 failure result'
[ "$(awk 'NF {print $1; exit}' "$EVIDENCE_DIR/result.sha256")" = "$RESULT_SHA" ] \
	|| die 'timing r4 result seal changed'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1" and
  .run_id == "20260721T-p5a-r4-e4-arm64-timing-r4" and
  .status == "harness_failed" and .architecture == "arm64" and
  .failure.stage == "evidence_validation" and
  .failure.reason == "measurement KUnit suite did not pass" and
  .source_commit == "5857720dedc49f89d2367442f8fdb1a806ffa1cc" and
  .architecture_measurement_valid == false and
  .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true and
  .x86_64_measurement_may_start == false and .measurement_result_accepted == false and
  .real_scheduler_attachment == false and .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null || die 'timing r4 failure semantic contract changed'
verify_hash "$EVIDENCE_DIR/raw/measurement-runner.sh" "$RUNNER_SNAPSHOT_SHA" 'timing r4 runner snapshot'
verify_hash "$EVIDENCE_DIR/raw/measurement-parser.sh" "$PARSER_SHA" 'timing r4 parser snapshot'
verify_hash "$EVIDENCE_DIR/raw/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'timing r4 warning classifier'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpu-control.py" "$QMP_CONTROL_SHA" 'timing r4 QMP helper'
verify_hash "$EVIDENCE_DIR/raw/measurement-plan.json" "$PLAN_SHA" 'timing r4 plan snapshot'
verify_hash "$EVIDENCE_DIR/raw/arm64.config" "$CONFIG_SHA" 'timing r4 config'
verify_hash "$EVIDENCE_DIR/raw/build.log" "$BUILD_LOG_SHA" 'timing r4 build log'
verify_hash "$EVIDENCE_DIR/raw/qemu-serial.log" "$SERIAL_SHA" 'timing r4 serial log'
verify_hash "$EVIDENCE_DIR/raw/qemu-ktap.log" "$KTAP_SHA" 'timing r4 KTAP log'
verify_hash "$EVIDENCE_DIR/raw/vcpu-pinning.txt" "$PINNING_SHA" 'timing r4 pinning record'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpus.txt" "$QMP_MAPPING_SHA" 'timing r4 QMP mapping'
verify_hash "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" "$QMP_AFFINITY_SHA" 'timing r4 QMP affinity'
verify_hash "$JOB_EVIDENCE_DIR/job.log" "$JOB_LOG_SHA" 'timing r4 job log'
verify_hash "$JOB_EVIDENCE_DIR/vm-pre-run-storage.txt" "$PRE_RUN_STORAGE_SHA" 'timing r4 pre-run storage'
verify_hash "$JOB_EVIDENCE_DIR/vm-pre-run-trim.log" "$PRE_RUN_TRIM_SHA" 'timing r4 pre-run trim'
verify_hash "$JOB_EVIDENCE_DIR/vm-trim.log" "$POST_RUN_TRIM_SHA" 'timing r4 post-run trim'
verify_hash "$JOB_EVIDENCE_DIR/vm_finished_at" "$VM_FINISHED_SHA" 'timing r4 finish time'
[ "$(cat "$EVIDENCE_DIR/raw/qemu-exit-code.txt")" = 0 ] || die 'timing r4 QEMU exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_exit_code")" = 1 ] || die 'timing r4 runner exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_pre_run_trim_exit_code")" = 0 ] || die 'timing r4 pre-run trim exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_trim_exit_code")" = 0 ] || die 'timing r4 post-run trim exit changed'
grep -Fxq 'host_available_kib=53959464' "$JOB_EVIDENCE_DIR/vm-pre-run-storage.txt" \
	|| die 'timing r4 pre-run host storage changed'
grep -Fxq '/: 930.4 MiB (975572992 bytes) trimmed on /dev/vdb' "$JOB_EVIDENCE_DIR/vm-pre-run-trim.log" \
	|| die 'timing r4 pre-run trim changed'
grep -Fxq '/: 229.1 GiB (245980114944 bytes) trimmed on /dev/vdb' "$JOB_EVIDENCE_DIR/vm-trim.log" \
	|| die 'timing r4 post-run trim changed'
[ ! -s "$EVIDENCE_DIR/raw/compiler-diagnostics.txt" ] || die 'timing r4 compiler diagnostics are nonempty'
grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y' "$EVIDENCE_DIR/raw/arm64.config" \
	|| die 'timing r4 measurement config is disabled'
grep -Fxq 'CONFIG_NR_CPUS=2' "$EVIDENCE_DIR/raw/arm64.config" || die 'timing r4 guest topology changed'
[ "$(grep -c 'R4_E4_RESULT ' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 523 ] \
	|| die 'timing r4 partial result-row cardinality changed'
[ "$(grep -c 'R4_E4_SUMMARY ' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 5 ] \
	|| die 'timing r4 partial summary cardinality changed'
for family_count in publication:288 picker_kick:144 irq_dispatch:9 recovery:0 notifier:48 current_stop:24 offline:10; do
	family=${family_count%:*}
	expected=${family_count#*:}
	actual=$(grep -c "R4_E4_RESULT family=$family " "$EVIDENCE_DIR/raw/qemu-serial.log" || true)
	[ "$actual" = "$expected" ] || die "timing r4 $family row cardinality changed"
done
for summary in \
	'family=publication rows=288 rejected_cells=203 harness_errors=0' \
	'family=picker_kick rows=144 rejected_cells=16 harness_errors=0' \
	'family=irq_dispatch rows=9 rejected_cells=6 harness_errors=0' \
	'family=notifier rows=48 rejected_cells=48 harness_errors=0 logical_final_bound=2*A' \
	'family=current_stop rows=24 rejected_cells=1 harness_errors=0 availability_only=1'; do
	grep -Fq "R4_E4_SUMMARY $summary" "$EVIDENCE_DIR/raw/qemu-serial.log" \
		|| die "timing r4 summary changed: $summary"
done
[ "$(grep -c 'ASSERTION FAILED at kernel/sched/exec_lease.c:4160' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 1 ] \
	|| die 'timing r4 recovery fixture failure changed'
[ "$(grep -c 'ASSERTION FAILED at kernel/sched/exec_lease.c:4727' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 1 ] \
	|| die 'timing r4 offline fixture failure changed'
[ "$(grep -c 'ret == -22 (0xffffffffffffffea)' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 2 ] \
	|| die 'timing r4 fixture -EINVAL cardinality changed'
grep -Fxq 'not ok 4 sched_exec_r4_measure_recovery_case' "$EVIDENCE_DIR/raw/qemu-ktap.log" \
	|| die 'timing r4 recovery KTAP terminal changed'
grep -Fxq 'not ok 7 sched_exec_r4_measure_offline_case' "$EVIDENCE_DIR/raw/qemu-ktap.log" \
	|| die 'timing r4 offline KTAP terminal changed'
grep -Fxq '# sched_exec_lease_r4_measure: pass:5 fail:2 skip:0 total:7' "$EVIDENCE_DIR/raw/qemu-ktap.log" \
	|| die 'timing r4 suite totals changed'
grep -Fxq 'not ok 1 sched_exec_lease_r4_measure' "$EVIDENCE_DIR/raw/qemu-ktap.log" \
	|| die 'timing r4 suite terminal changed'
grep -Fxq 'qmp_status=prelaunch' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r4 QMP was not paused'
grep -Fxq 'vcpu=0 tid=665559' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r4 vCPU 0 mapping changed'
grep -Fxq 'vcpu=1 tid=665560' "$EVIDENCE_DIR/raw/qmp-vcpus.txt" || die 'timing r4 vCPU 1 mapping changed'
grep -Fxq 'vcpu=0 tid=665559 host_cpu=0' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" || die 'timing r4 vCPU 0 affinity changed'
grep -Fxq 'vcpu=1 tid=665560 host_cpu=1' "$EVIDENCE_DIR/raw/qmp-vcpu-affinity.txt" || die 'timing r4 vCPU 1 affinity changed'
for anchor in qmp_status_before_resume=prelaunch qmp_mapping_reverified=true \
	singleton_affinity_reverified=true qmp_status_after_resume=running \
	rows_before_all_vcpus_pinned=0 pinned_vcpu_threads=2 \
	qmp_pause_before_affinity=true qmp_mapping_reverified_before_resume=true; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/vcpu-pinning.txt" \
		|| die "timing r4 placement proof changed: $anchor"
done

progress '65% losslessly verifying preserved Image and object archives'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" "$BOOT_MANIFEST_SHA" 'timing r4 boot manifest'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" "$IMAGE_ARCHIVE_SHA" 'timing r4 Image archive'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" "$OBJECT_ARCHIVE_SHA" 'timing r4 object archive'
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst"
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst"
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" | sha256sum | awk '{print $1}')" = "$IMAGE_SOURCE_SHA" ] \
	|| die 'timing r4 Image restore hash changed'
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" | sha256sum | awk '{print $1}')" = "$OBJECT_SOURCE_SHA" ] \
	|| die 'timing r4 object restore hash changed'
for anchor in \
	"image_source_sha256=$IMAGE_SOURCE_SHA" "image_archive_sha256=$IMAGE_ARCHIVE_SHA" \
	"object_source_sha256=$OBJECT_SOURCE_SHA" "object_archive_sha256=$OBJECT_ARCHIVE_SHA" \
	'compression=zstd-level-9-lossless' 'restore_verified=true'; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" \
		|| die "timing r4 boot manifest changed: $anchor"
done

progress '82% proving original stability, retired scratch, and closure immutability'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-final.sha256"
[ "$(file_sha "$OUT_DIR/source-final.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r4 original changed during closure'
job_manifest "$JOB_DIR" > "$OUT_DIR/job-final.sha256"
[ "$(file_sha "$OUT_DIR/job-final.sha256")" = "$JOB_MANIFEST_SHA" ] \
	|| die 'timing r4 job control changed during closure'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] \
	|| die 'closure runner snapshot changed'
[ -z "$(find "$INPUT_DIR" -type f -perm -222 -print -quit)" ] \
	|| die 'timing r4 closure inputs contain writable files'
for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "timing r4 run-owned scratch leaked: $path"
	fi
done

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% exact timing r4 KUnit-failure closure fixture passed; no result published'
	exit 0
fi

progress '94% sealing timing r4 synthetic-fixture failure without partial measurement credit'
jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$RESULT_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg job_manifest_sha "$JOB_MANIFEST_SHA" --arg closure_runner_sha "$runner_initial_sha" \
	--arg runner_snapshot_sha "$RUNNER_SNAPSHOT_SHA" --arg serial_sha "$SERIAL_SHA" \
	--arg ktap_sha "$KTAP_SHA" --arg pinning_sha "$PINNING_SHA" \
	--argjson source_files "$SOURCE_FILES" --argjson source_bytes "$SOURCE_BYTES" \
	--argjson job_files "$JOB_FILES" --argjson job_bytes "$JOB_BYTES" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-timing-kunit-failure-closure-result-v1",
  run_id:$run_id,
  status:"passed_independent_arm64_timing_kunit_failure_closure",
  source_run_id:$source_run_id,
  source_result_sha256:$source_result_sha,
  source_artifacts:{files:$source_files,bytes:$source_bytes,manifest_sha256:$source_manifest_sha},
  job_control:{files:$job_files,bytes:$job_bytes,manifest_sha256:$job_manifest_sha},
  closure_runner_sha256:$closure_runner_sha,
  timing_runner_snapshot_sha256:$runner_snapshot_sha,
  failure:{stage:"evidence_validation",sealed_reason:"measurement KUnit suite did not pass",root_boundary:"synthetic fixture setup returned -EINVAL",recovery_assertion_line:4160,offline_assertion_line:4727},
  build:{completed:true,compiler_diagnostics:0,image_and_object_losslessly_preserved:true},
  guest:{qemu_exit_code:0,suite_pass:5,suite_fail:2,suite_skip:0,suite_total:7,complete_matrix:false,result_rows:523,summary_rows:5,family_rows:{publication:288,picker_kick:144,irq_dispatch:9,recovery:0,notifier:48,current_stop:24,offline:10},partial_values_receive_threshold_credit:false,serial_sha256:$serial_sha,ktap_sha256:$ktap_sha},
  placement:{qemu_parent_allowed_cpus:"0-1",qemu_vcpu_threads_pinned:2,distinct_singleton_host_cpus:true,qmp_started_paused:true,qmp_mapping_reverified_before_resume:true,rows_before_resume:0,pinning_record_sha256:$pinning_sha},
  storage:{pre_run_host_available_kib:53959464,pre_run_trimmed_bytes:975572992,post_run_trimmed_bytes:245980114944},
  original_snapshot_race_free:true,
  snapshot_read_only:true,
  run_owned_build_scratch_retired:true,
  run_owned_worktree_retired:true,
  valid_threshold_evidence:false,
  architecture_measurement_valid:false,
  corrected_source_or_harness_and_fresh_regression_required:true,
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
progress '100% timing r4 KUnit failure independently closed; partial rows have no measurement or x86 credit'
printf 'result=%s\nsha256=%s\nnormalized_sha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")" \
	"$(cat "$OUT_DIR/result.normalized.sha256")"
