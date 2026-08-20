#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_RUN_ID=20260720T-p5a-r4-e4-arm64-timing-r2
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$SOURCE_RUN_ID"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
SOURCE_OVERRIDE=${SOURCE_OVERRIDE:-}

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ "$PREFLIGHT_ONLY" = 1 ] || { printf 'error: test mode requires PREFLIGHT_ONLY=1\n' >&2; exit 1; }
	[ -n "$SOURCE_OVERRIDE" ] || { printf 'error: test mode requires SOURCE_OVERRIDE\n' >&2; exit 1; }
	SOURCE_DIR=$SOURCE_OVERRIDE
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-failure-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] || { printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2; exit 1; }
	[ -z "$SOURCE_OVERRIDE" ] || { printf 'error: SOURCE_OVERRIDE is restricted to test mode\n' >&2; exit 1; }
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-failure-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/timing-r2"
RESULT_SHA=171df609d8f8dc272a20f585cea3b419a0ae487c6a0feda1367e880afec12a22
SOURCE_MANIFEST_SHA=056949c807a88b48187c822e56144ab864453743cd2e01e303678444a1780efd
SOURCE_FILES=34
SOURCE_BYTES=33365585
RUNNER_SNAPSHOT_SHA=a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392
PARSER_SHA=dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
PLAN_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
CONFIG_SHA=2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b
BUILD_LOG_SHA=2c269ceede4aba394b6702f402685ac0bae4ec4994a4174db37bba388d7150af
SERIAL_SHA=ec346c4c4e67f61d17620238ec1c383214ae7f0646113eaa9e4edeb73986aba3
PINNING_SHA=c1efdd657853c4aadfceb05aa4c6e1e9a684f1afe68fab422fc23aa79687f1ad
BOOT_MANIFEST_SHA=1a693f42054626a9ff4fb303aac63e7c118f2f395d723820886fd4444a8c1975
IMAGE_SOURCE_SHA=717d3139fde9fda555486a80062abfc77a759986789842a93fa8916b4404fa9d
IMAGE_ARCHIVE_SHA=fefc7dd42c1826f01b8ff5d8d8a165e5d028312b0bf7ef63068fe86fd165b850
OBJECT_SOURCE_SHA=2f31ecc6bf89440768c1d7eedb375c4973e233c1fc577f0a3428229375a37943
OBJECT_ARCHIVE_SHA=6a66654edb27c1c52893d84337a65c24813067c86bb8cdaf2a1610e2520ecc5b
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
	find "$1" -type f -printf '%s\n' | awk '{sum += $1} END {printf "%.0f\n", sum}'
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
if [ ! -d "$SOURCE_DIR" ] || [ -L "$SOURCE_DIR" ]; then
	die 'timing r2 evidence root is unsafe'
fi
[ -z "$(find "$SOURCE_DIR" -type l -print -quit)" ] || die 'timing r2 evidence contains a symlink'
[ -z "$(find "$SOURCE_DIR" ! -type f ! -type d -print -quit)" ] \
	|| die 'timing r2 evidence contains a non-regular object'

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '10% snapshotting exact timing r2 failure evidence with race checks'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r2 artifact count changed'
[ "$(tree_bytes "$SOURCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r2 artifact byte count changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-before.sha256"
[ "$(file_sha "$OUT_DIR/source-before.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r2 artifact manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/snapshot.sha256"
diff -u "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-after.sha256" \
	> "$OUT_DIR/source-race.diff" || die 'timing r2 evidence changed while snapshotting'
diff -u "$OUT_DIR/source-before.sha256" "$OUT_DIR/snapshot.sha256" \
	> "$OUT_DIR/snapshot.diff" || die 'timing r2 evidence snapshot differs'
[ "$(find "$EVIDENCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] \
	|| die 'timing r2 snapshot count changed'
[ "$(tree_bytes "$EVIDENCE_DIR")" = "$SOURCE_BYTES" ] || die 'timing r2 snapshot bytes changed'
chmod -R a-w "$EVIDENCE_DIR"

progress '35% auditing exact sealed failure, build, guest, and placement evidence'
RESULT="$EVIDENCE_DIR/result.json"
verify_hash "$RESULT" "$RESULT_SHA" 'timing r2 failure result'
[ "$(awk 'NF {print $1; exit}' "$EVIDENCE_DIR/result.sha256")" = "$RESULT_SHA" ] \
	|| die 'timing r2 result seal changed'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1" and
  .run_id == "20260720T-p5a-r4-e4-arm64-timing-r2" and
  .status == "harness_failed" and .architecture == "arm64" and
  .failure.stage == "qemu_boot" and
  .failure.reason == "measurement emitted rows before all QEMU vCPU threads were pinned" and
  .source_commit == "5857720dedc49f89d2367442f8fdb1a806ffa1cc" and
  .architecture_measurement_valid == false and
  .run_owned_build_scratch_retired == true and .run_owned_worktree_retired == true and
  .x86_64_measurement_may_start == false and .measurement_result_accepted == false and
  .real_scheduler_attachment == false and .runtime_behavior_approved == false and
  .production_protection == false and .deployment_ready == false and
  .multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null || die 'timing r2 failure semantic contract changed'
verify_hash "$EVIDENCE_DIR/raw/measurement-runner.sh" "$RUNNER_SNAPSHOT_SHA" 'timing r2 runner snapshot'
verify_hash "$EVIDENCE_DIR/raw/measurement-parser.sh" "$PARSER_SHA" 'timing r2 parser snapshot'
verify_hash "$EVIDENCE_DIR/raw/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" 'timing r2 warning classifier'
verify_hash "$EVIDENCE_DIR/raw/measurement-plan.json" "$PLAN_SHA" 'timing r2 plan snapshot'
verify_hash "$EVIDENCE_DIR/raw/arm64.config" "$CONFIG_SHA" 'timing r2 config'
verify_hash "$EVIDENCE_DIR/raw/build.log" "$BUILD_LOG_SHA" 'timing r2 build log'
verify_hash "$EVIDENCE_DIR/raw/qemu-serial.log" "$SERIAL_SHA" 'timing r2 serial log'
verify_hash "$EVIDENCE_DIR/raw/vcpu-pinning.txt" "$PINNING_SHA" 'timing r2 pinning record'
[ ! -s "$EVIDENCE_DIR/raw/compiler-diagnostics.txt" ] || die 'timing r2 compiler diagnostics are nonempty'
grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y' "$EVIDENCE_DIR/raw/arm64.config" \
	|| die 'timing r2 measurement config is disabled'
grep -Fxq 'CONFIG_NR_CPUS=2' "$EVIDENCE_DIR/raw/arm64.config" || die 'timing r2 guest topology changed'
grep -Fxq '# CONFIG_KASAN is not set' "$EVIDENCE_DIR/raw/arm64.config" || die 'timing r2 enabled KASAN'
grep -Fxq '# CONFIG_KCSAN is not set' "$EVIDENCE_DIR/raw/arm64.config" || die 'timing r2 enabled KCSAN'
[ "$(wc -l < "$EVIDENCE_DIR/raw/vcpu-pinning.txt" | tr -d ' ')" = 2 ] \
	|| die 'timing r2 unexpectedly recorded a pinned vCPU'
grep -Eq '^qemu_pid=[0-9]+$' "$EVIDENCE_DIR/raw/vcpu-pinning.txt" \
	|| die 'timing r2 QEMU pid record changed'
grep -Fxq 'parent_allowed_cpus=0-1' "$EVIDENCE_DIR/raw/vcpu-pinning.txt" \
	|| die 'timing r2 parent CPU allowance changed'
if grep -Eq '^vcpu=' "$EVIDENCE_DIR/raw/vcpu-pinning.txt"; then
	die 'timing r2 contains a false vCPU pin claim'
fi
grep -Fq ' -accel tcg,thread=multi -smp 2,maxcpus=2 ' "$EVIDENCE_DIR/raw/qemu-command.txt" \
	|| die 'timing r2 QEMU topology changed'
if grep -Eq '(^|[[:space:]])-S([[:space:]]|$)|-qmp[[:space:]]' "$EVIDENCE_DIR/raw/qemu-command.txt"; then
	die 'timing r2 unexpectedly used paused QMP startup'
fi
[ "$(grep -c 'R4_E4_RESULT ' "$EVIDENCE_DIR/raw/qemu-serial.log")" = 1 ] \
	|| die 'timing r2 first-row cardinality changed'
grep -Fq '# Subtest: sched_exec_lease_r4_measure' "$EVIDENCE_DIR/raw/qemu-serial.log" \
	|| die 'timing r2 measurement suite did not start'
grep -Fq 'terminating on signal 15' "$EVIDENCE_DIR/raw/qemu-serial.log" \
	|| die 'timing r2 QEMU termination record missing'

progress '65% losslessly verifying preserved Image and object archives'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" "$BOOT_MANIFEST_SHA" 'timing r2 boot manifest'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" "$IMAGE_ARCHIVE_SHA" 'timing r2 Image archive'
verify_hash "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" "$OBJECT_ARCHIVE_SHA" 'timing r2 object archive'
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst"
zstd -q -t "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst"
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/Image.zst" | sha256sum | awk '{print $1}')" = "$IMAGE_SOURCE_SHA" ] \
	|| die 'timing r2 Image restore hash changed'
[ "$(zstd -q -dc "$EVIDENCE_DIR/raw/boot-artifacts/arm64/exec_lease.o.zst" | sha256sum | awk '{print $1}')" = "$OBJECT_SOURCE_SHA" ] \
	|| die 'timing r2 object restore hash changed'
for anchor in \
	"image_source_sha256=$IMAGE_SOURCE_SHA" "image_archive_sha256=$IMAGE_ARCHIVE_SHA" \
	"object_source_sha256=$OBJECT_SOURCE_SHA" "object_archive_sha256=$OBJECT_ARCHIVE_SHA" \
	'compression=zstd-level-9-lossless' 'restore_verified=true'; do
	grep -Fxq "$anchor" "$EVIDENCE_DIR/raw/boot-artifacts/arm64/manifest.txt" \
		|| die "timing r2 boot manifest changed: $anchor"
done

progress '82% proving original stability, retired scratch, and closure immutability'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-final.sha256"
[ "$(file_sha "$OUT_DIR/source-final.sha256")" = "$SOURCE_MANIFEST_SHA" ] \
	|| die 'timing r2 original changed during closure'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] || die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] \
	|| die 'closure runner snapshot changed'
[ -z "$(find "$EVIDENCE_DIR" -type f -perm -222 -print -quit)" ] \
	|| die 'timing r2 snapshot contains writable files'
for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "timing r2 run-owned scratch leaked: $path"
	fi
done

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	progress '100% exact timing r2 failure closure fixture passed; no result published'
	exit 0
fi

progress '94% sealing timing r2 harness-failure decision without measurement credit'
jq -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$RESULT_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg closure_runner_sha "$runner_initial_sha" --arg runner_snapshot_sha "$RUNNER_SNAPSHOT_SHA" \
	--arg serial_sha "$SERIAL_SHA" --arg pinning_sha "$PINNING_SHA" \
	--argjson source_files "$SOURCE_FILES" --argjson source_bytes "$SOURCE_BYTES" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-timing-failure-closure-result-v1",
  run_id:$run_id,
  status:"passed_independent_arm64_timing_harness_failure_closure",
  source_run_id:$source_run_id,
  source_result_sha256:$source_result_sha,
  source_artifacts:{files:$source_files,bytes:$source_bytes,manifest_sha256:$source_manifest_sha},
  closure_runner_sha256:$closure_runner_sha,
  timing_runner_snapshot_sha256:$runner_snapshot_sha,
  failure:{stage:"qemu_boot",reason:"measurement emitted rows before all QEMU vCPU threads were pinned"},
  build:{completed:true,compiler_diagnostics:0,image_and_object_losslessly_preserved:true},
  guest:{suite_started:true,result_rows_before_termination:1,qemu_terminated_by_harness:true,serial_sha256:$serial_sha},
  placement:{qemu_parent_allowed_cpus:"0-1",qemu_vcpu_threads_pinned:0,pinning_record_sha256:$pinning_sha},
  original_snapshot_race_free:true,
  snapshot_read_only:true,
  run_owned_build_scratch_retired:true,
  run_owned_worktree_retired:true,
  valid_threshold_evidence:false,
  architecture_measurement_valid:false,
  corrected_harness_and_fresh_arm64_retry_required:true,
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
progress '100% timing r2 harness failure independently closed; no measurement or x86 credit'
printf 'result=%s\nsha256=%s\nnormalized_sha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")" \
	"$(cat "$OUT_DIR/result.normalized.sha256")"
