#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-v1.json"
PARSER="$SCRIPT_DIR/parse-sched-exec-lease-p5a-r4-e4-measurement-evidence.sh"
WARNING_CLASSIFIER="$SCRIPT_DIR/lib/kernel-warning-classifier.sh"
CLOSURE_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure"
CLOSURE_R1="$CLOSURE_ROOT/20260719T-p5a-r4-e4-source-e3-corrected-closure-r1"
CLOSURE_R2="$CLOSURE_ROOT/20260719T-p5a-r4-e4-source-e3-corrected-closure-r2"
CANDIDATE_PARENT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
CANDIDATE_COMMIT=9e4cb44fd1a1f998fcc288df87dad60505e8bf18
CANDIDATE_TREE=e6feb28a29fc8c37bc46af0fbf37de30f3401a4f
CANDIDATE_DIFF_SHA=bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PLAN_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
CLOSURE_R1_SHA=c1d9afa02f516e893e0dd0f910b7d1a60a56f2c1389b9426878545ef6a691325
CLOSURE_R2_SHA=9c19029ca7c18d44ec873374c9e85327a7a81d94221b1e10538f19cd16e8633e
CLOSURE_NORMALIZED_SHA=ff91f2517b460b4d60322ea1670aab94058a8db4246bf2e2b63b7454250f528f
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
BUILD_ROOT=${BUILD_ROOT:-"/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$RUN_ID"}
BUILD_OUT="$BUILD_ROOT/build"
WORKTREE=${WORKTREE:-"/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$RUN_ID"}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$RUN_ID"
RAW_DIR="$OUT_DIR/raw"
DERIVED_DIR="$OUT_DIR/derived"
ARTIFACT_DIR="$RAW_DIR/boot-artifacts/arm64"
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
HOST_ENV_FILE=${HOST_ENV_FILE:-}
JOBS=${JOBS:-2}
QEMU_TIMEOUT=${QEMU_TIMEOUT:-86400}
BUILD_STORAGE_MIN_KIB=${BUILD_STORAGE_MIN_KIB:-16777216}
GUEST_VCPUS=2
IMAGE="$BUILD_OUT/arch/arm64/boot/Image"
OBJECT="$BUILD_OUT/kernel/sched/exec_lease.o"
SERIAL="$RAW_DIR/qemu-serial.log"
KTAP="$RAW_DIR/qemu-ktap.log"
ROWS="$RAW_DIR/r4-e4-result-rows.txt"
SUMMARIES="$RAW_DIR/r4-e4-summary-rows.txt"
FAILURE_REASON=
CURRENT_STAGE=initialization
ACTIVE_PID=
WORKTREE_CREATED=0
BUILD_RETIRED=0
WORKTREE_RETIRED=0

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

progress()
{
	mkdir -p "$(dirname "$PROGRESS_FILE")"
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

die()
{
	FAILURE_REASON=$*
	printf 'error: %s\n' "$*" >&2
	exit 1
}

safe_remove_tree()
{
	local path=$1 prefix=$2
	case "$path" in
		"$prefix"/*) ;;
		*) return 1 ;;
	esac
	[ ! -L "$path" ] || return 1
	if [ -d "$path" ]; then
		find "$path" -depth -delete
	fi
	[ ! -e "$path" ] && [ ! -L "$path" ]
}

terminate_active()
{
	local pid=${ACTIVE_PID:-} attempts=0
	[ -n "$pid" ] || return 0
	if kill -0 "$pid" 2>/dev/null; then
		kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
		while kill -0 "$pid" 2>/dev/null && [ "$attempts" -lt 30 ]; do
			sleep 1
			attempts=$((attempts + 1))
		done
		if kill -0 "$pid" 2>/dev/null; then
			kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
		fi
	fi
	wait "$pid" 2>/dev/null || true
	ACTIVE_PID=
}

retire_owned_paths()
{
	terminate_active
	if [ -e "$BUILD_ROOT" ] || [ -L "$BUILD_ROOT" ]; then
		if safe_remove_tree "$BUILD_ROOT" /var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement; then
			BUILD_RETIRED=1
		fi
	else
		BUILD_RETIRED=1
	fi
	if [ "$WORKTREE_CREATED" = 1 ]; then
		if git -C "$LINUX_DIR" worktree remove --force "$WORKTREE" >/dev/null 2>&1; then
			WORKTREE_CREATED=0
			WORKTREE_RETIRED=1
		fi
	elif [ ! -e "$WORKTREE" ] && [ ! -L "$WORKTREE" ]; then
		WORKTREE_RETIRED=1
	fi
}

write_failure_result()
{
	local reason=${FAILURE_REASON:-"runner exited unexpectedly with code $1"}
	local build_retired_json=false worktree_retired_json=false
	[ -d "$OUT_DIR" ] || return 0
	[ ! -e "$OUT_DIR/result.json" ] || return 0
	command -v jq >/dev/null 2>&1 || return 0
	[ "$BUILD_RETIRED" = 0 ] || build_retired_json=true
	[ "$WORKTREE_RETIRED" = 0 ] || worktree_retired_json=true
	jq -n \
		--arg run_id "$RUN_ID" --arg reason "$reason" --arg stage "$CURRENT_STAGE" \
		--argjson build_retired "$build_retired_json" --argjson worktree_retired "$worktree_retired_json" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1",
  run_id:$run_id,
  status:"harness_failed",
  architecture:"arm64",
  failure:{stage:$stage,reason:$reason},
  source_commit:"9e4cb44fd1a1f998fcc288df87dad60505e8bf18",
  architecture_measurement_valid:false,
  run_owned_build_scratch_retired:$build_retired,
  run_owned_worktree_retired:$worktree_retired,
  x86_64_measurement_may_start:false,
  measurement_result_accepted:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
  production_protection:false,
  deployment_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
	file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
	printf 'failed (%s); inspect %s/result.json\n' "$reason" "$OUT_DIR" > "$PROGRESS_FILE"
}

finish()
{
	local rc=$?
	trap - EXIT INT TERM
	retire_owned_paths
	if [ "$rc" -ne 0 ]; then
		write_failure_result "$rc"
	fi
	exit "$rc"
}
trap finish EXIT
trap 'FAILURE_REASON=interrupted; exit 130' INT TERM

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$BUILD_ROOT" in
	/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/*) ;;
	*) die "unsafe build root: $BUILD_ROOT" ;;
esac
case "$WORKTREE" in
	/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/*) ;;
	*) die "unsafe worktree: $WORKTREE" ;;
esac
case "$JOBS:$QEMU_TIMEOUT:$BUILD_STORAGE_MIN_KIB" in
	*[!0-9:]*|0:*|*:0:*|*:*:0) die 'numeric runner limits must be positive integers' ;;
esac
case "${CONFIG_SMOKE_ONLY:-0}" in
	0|1) ;;
	*) die 'CONFIG_SMOKE_ONLY must be 0 or 1' ;;
esac

for command in awk cat chmod cmp cp cut date df find gcc git grep jq lscpu make \
	mkdir mkfifo nm qemu-system-aarch64 readelf sed sha256sum sleep sort stat \
	strings tail taskset tr uname wc xargs zstd setsid; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for input in "$PLAN" "$PARSER" "$WARNING_CLASSIFIER" \
	"$CLOSURE_R1/result.json" "$CLOSURE_R2/result.json" \
	"$CLOSURE_R1/result.normalized.json" "$CLOSURE_R2/result.normalized.json"; do
	[ -f "$input" ] || die "required input missing: $input"
	[ ! -L "$input" ] || die "required input is a symlink: $input"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi

CURRENT_STAGE=prerequisite_closure
progress '2% verifying exact source, plan, and independent double closure'
[ "$(file_sha "$PLAN")" = "$PLAN_SHA" ] || die 'measurement plan hash changed'
[ "$(file_sha "$WARNING_CLASSIFIER")" = "$WARNING_CLASSIFIER_SHA" ] || die 'warning classifier hash changed'
[ "$(file_sha "$CLOSURE_R1/result.json")" = "$CLOSURE_R1_SHA" ] || die 'closure r1 result hash changed'
[ "$(file_sha "$CLOSURE_R2/result.json")" = "$CLOSURE_R2_SHA" ] || die 'closure r2 result hash changed'
for closure in "$CLOSURE_R1" "$CLOSURE_R2"; do
	[ "$(file_sha "$closure/result.normalized.json")" = "$CLOSURE_NORMALIZED_SHA" ] \
		|| die 'closure normalized decision changed'
	jq -e '
	  .schema_version == 2 and
	  .status == "passed_independent_r4_e4_source_e3_evidence_closure" and
	  .source_run_id == "20260719T-p5a-r4-e4-source-e3-regression-r3" and
	  .combined_result_sha256 == "9896e12b2882ac88c7b4d57f53c59f7d245b5d3b78717df7d39097af64de8b72" and
	  .candidate_commit == "9e4cb44fd1a1f998fcc288df87dad60505e8bf18" and
	  .candidate_parent == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
	  .candidate_tree == "e6feb28a29fc8c37bc46af0fbf37de30f3401a4f" and
	  .candidate_diff_sha256 == "bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2" and
	  .artifact_counts.total == 267 and .artifact_bytes.total == 10876145 and
	  .fresh_source_objects_audited == 6 and .e3_profiles_audited == 6 and
	  .total_e3_cases == 216 and .total_e3_receipts == 216 and
	  .measurement_task_migration_disabled == true and
	  .vcpu_migration_observation_enforced == true and
	  .irq_preempt_state_recorded == true and
	  .plan_to_source_observability_audited == true and
	  .compiler_diagnostics == 0 and .clock_skew_warnings == 0 and
	  .kernel_warning_reports == 0 and .case_failures == 0 and
	  .case_skips == 0 and .case_timeouts == 0 and .qemu_nonzero_exits == 0 and
	  .all_artifacts_snapshotted_read_only == true and
	  .independent_artifact_closure_passed == true and
	  .exact_virtual_synthetic_r4_e4_source_accepted == true and
	  .r4_e4_virtual_synthetic_timing_may_start == true and
	  .measurement_result_accepted == false and .real_scheduler_attachment == false and
	  .runtime_behavior_approved == false and .production_protection == false and
	  .deployment_ready == false and .multi_cluster_ready == false and .datacenter_ready == false
	' "$closure/result.json" >/dev/null || die 'closure semantic contract changed'
	[ -z "$(find "$closure/inputs" -type f -perm -222 -print -quit)" ] \
		|| die 'closure input snapshot became writable'
done
cmp "$CLOSURE_R1/result.normalized.json" "$CLOSURE_R2/result.normalized.json" >/dev/null \
	|| die 'independent closures do not reproduce one decision'
jq -e '
  .status == "r4_e4_source_free_local_quantum_measurement_pre_source_plan" and
  .configuration.suite_name == "sched_exec_lease_r4_measure" and
  .common_measurement.minimum_warmup_pairs_per_cell == 256 and
  .common_measurement.measured_pairs_per_cell == 10000 and
  .common_measurement.observed_vcpu_migration_allowed == false and
  .matrix.total_cells == 682 and .matrix.total_measured_pairs == 6820000 and
  .diagnostics.arm64_runs_first == true and
  .diagnostics.x86_64_runs_only_after_arm64_pass == true and
  .diagnostics.warning_reports_allowed == 0
' "$PLAN" >/dev/null || die 'measurement plan semantic contract changed'

CURRENT_STAGE=source_identity
[ "$(git -C "$LINUX_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$CANDIDATE_COMMIT^")" = "$CANDIDATE_PARENT" ] || die 'candidate parent changed'
[ "$(git -C "$LINUX_DIR" rev-parse "$CANDIDATE_COMMIT^{tree}")" = "$CANDIDATE_TREE" ] || die 'candidate tree changed'
git -C "$LINUX_DIR" diff-tree --no-commit-id --name-only -r "$CANDIDATE_COMMIT" \
	| cmp - <(printf 'init/Kconfig\nkernel/sched/exec_lease.c\n') >/dev/null \
	|| die 'candidate file boundary changed'
candidate_diff_sha=$(git -C "$LINUX_DIR" diff --binary "$CANDIDATE_PARENT" "$CANDIDATE_COMMIT" -- init/Kconfig kernel/sched/exec_lease.c | sha256sum | awk '{print $1}')
[ "$candidate_diff_sha" = "$CANDIDATE_DIFF_SHA" ] || die 'candidate diff hash changed'

for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run-owned path already exists: $path"
	fi
done
if [ -z "$HOST_ENV_FILE" ] || [ ! -s "$HOST_ENV_FILE" ] || [ -L "$HOST_ENV_FILE" ]; then
	die 'outer host environment record is unavailable'
fi
mkdir -p "$RAW_DIR" "$ARTIFACT_DIR" "$(dirname "$BUILD_ROOT")" "$(dirname "$WORKTREE")"
runner_initial_sha=$(file_sha "${BASH_SOURCE[0]}")
parser_initial_sha=$(file_sha "$PARSER")
cp -- "${BASH_SOURCE[0]}" "$RAW_DIR/measurement-runner.sh"
cp -- "$PARSER" "$RAW_DIR/measurement-parser.sh"
cp -- "$WARNING_CLASSIFIER" "$RAW_DIR/kernel-warning-classifier.sh"
cp -- "$PLAN" "$RAW_DIR/measurement-plan.json"
cp -- "$CLOSURE_R1/result.json" "$RAW_DIR/closure-r1-result.json"
cp -- "$CLOSURE_R2/result.json" "$RAW_DIR/closure-r2-result.json"
cp -- "$CLOSURE_R1/result.normalized.json" "$RAW_DIR/closure-normalized.json"
cp -- "$HOST_ENV_FILE" "$RAW_DIR/outer-host-environment.txt"

CURRENT_STAGE=worktree
progress '4% creating exact disposable candidate worktree on VM-internal ext4'
git -C "$LINUX_DIR" worktree add --detach "$WORKTREE" "$CANDIDATE_COMMIT" \
	> "$RAW_DIR/worktree-add.log" 2>&1
WORKTREE_CREATED=1
[ "$(git -C "$WORKTREE" rev-parse HEAD)" = "$CANDIDATE_COMMIT" ] || die 'measurement worktree commit changed'
[ -z "$(git -C "$WORKTREE" status --porcelain)" ] || die 'measurement worktree is dirty'
mkdir -p "$BUILD_OUT"
build_storage_type=$(stat -f -c %T "$BUILD_ROOT")
[ "$build_storage_type" = ext2/ext3 ] || die "build root is not internal ext4: $build_storage_type"
build_storage_available_kib=$(df -Pk "$BUILD_ROOT" | awk 'NR==2 {print $4}')
[ "$build_storage_available_kib" -ge "$BUILD_STORAGE_MIN_KIB" ] \
	|| die "internal build storage below ${BUILD_STORAGE_MIN_KIB}KiB"
{
	printf 'build_root=%s\nfilesystem=%s\navailable_kib_at_start=%s\nshared_host_build_output=false\n' \
		"$BUILD_ROOT" "$build_storage_type" "$build_storage_available_kib"
	df -Pk "$BUILD_ROOT" "$OUT_DIR"
} > "$RAW_DIR/build-storage.txt"
uname -a > "$RAW_DIR/container-uname.txt"
lscpu > "$RAW_DIR/container-lscpu.txt"
gcc --version > "$RAW_DIR/compiler.txt"
qemu-system-aarch64 --version > "$RAW_DIR/qemu-version.txt"
awk '/^Cpus_allowed_list:/ {print $2}' /proc/self/status > "$RAW_DIR/container-allowed-cpus.txt"
host_allowed_list=$(cat "$RAW_DIR/container-allowed-cpus.txt")
[ -n "$host_allowed_list" ] || die 'container allowed CPU list is empty'
if [ -d /sys/devices/system/cpu/cpufreq ]; then
	find /sys/devices/system/cpu/cpufreq -maxdepth 2 -type f \
		\( -name scaling_governor -o -name scaling_cur_freq -o -name cpuinfo_cur_freq \) \
		-print -exec sed -n '1p' {} \; > "$RAW_DIR/container-frequency-governor.txt" 2>/dev/null || true
fi
if [ ! -s "$RAW_DIR/container-frequency-governor.txt" ]; then
	printf 'unavailable: no cpufreq files exposed by Apple Container machine\n' > "$RAW_DIR/container-frequency-governor.txt"
fi

CURRENT_STAGE=config
progress '7% resolving exact arm64 timing config; no build has started'
make -C "$WORKTREE" O="$BUILD_OUT" ARCH=arm64 defconfig > "$RAW_DIR/defconfig.log" 2>&1
"$WORKTREE/scripts/config" --file "$BUILD_OUT/.config" \
	-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
	-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
	-e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -e SCHED_EXEC_LEASE_R4_KUNIT_TEST \
	-e SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST -e KUNIT -d KUNIT_ALL_TESTS \
	-e KUNIT_AUTORUN_ENABLED --set-str KUNIT_DEFAULT_FILTER_GLOB sched_exec_lease_r4_measure \
	--set-val KUNIT_DEFAULT_TIMEOUT 86400 -e PROVE_LOCKING -e DEBUG_OBJECTS \
	-e DEBUG_OBJECTS_WORK -e PROVE_RCU -e DEBUG_IRQFLAGS -e HOTPLUG_CPU \
	-e FTRACE -e IRQSOFF_TRACER -e DEBUG_INFO_NONE -d KASAN -d KCSAN \
	-d MODULES --set-val NR_CPUS "$GUEST_VCPUS"
make -C "$WORKTREE" O="$BUILD_OUT" ARCH=arm64 olddefconfig > "$RAW_DIR/olddefconfig.log" 2>&1
for required in \
	CONFIG_SCHED_EXEC_LEASE=y CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE=y \
	CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y \
	CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
	'CONFIG_KUNIT_DEFAULT_FILTER_GLOB="sched_exec_lease_r4_measure"' \
	CONFIG_PROVE_LOCKING=y CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_PROVE_RCU=y \
	CONFIG_DEBUG_IRQFLAGS=y CONFIG_HOTPLUG_CPU=y CONFIG_FTRACE=y CONFIG_IRQSOFF_TRACER=y; do
	grep -Fxq "$required" "$BUILD_OUT/.config" || die "measurement config missing: $required"
done
grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$BUILD_OUT/.config" || die 'KUNIT_ALL_TESTS enabled'
grep -Fxq '# CONFIG_KASAN is not set' "$BUILD_OUT/.config" || die 'KASAN belongs to separate diagnostics'
grep -Fxq '# CONFIG_KCSAN is not set' "$BUILD_OUT/.config" || die 'KCSAN belongs to separate diagnostics'
grep -Fxq "CONFIG_NR_CPUS=$GUEST_VCPUS" "$BUILD_OUT/.config" || die 'guest CPU count changed'
cp -- "$BUILD_OUT/.config" "$RAW_DIR/arm64.config"
grep -E '^CONFIG_(PROVE_LOCKING|LOCKDEP|DEBUG_IRQFLAGS|DEBUG_OBJECTS_WORK|PROVE_RCU|FTRACE|IRQSOFF_TRACER|RCU_STALL_COMMON|SOFTLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR|HOTPLUG_CPU)=' "$BUILD_OUT/.config" > "$RAW_DIR/diagnostic-config.txt" || true
grep -E '^CONFIG_(MITIGATION|ARM64_PTR_AUTH|ARM64_BTI|RANDOMIZE_BASE|STACKPROTECTOR|HARDENED_USERCOPY|FORTIFY_SOURCE)' "$BUILD_OUT/.config" > "$RAW_DIR/mitigation-config.txt" || true
if [ "${CONFIG_SMOKE_ONLY:-0}" = 1 ]; then
	retire_owned_paths
	[ "$BUILD_RETIRED:$WORKTREE_RETIRED" = 1:1 ] || die 'config-smoke cleanup failed'
	progress '100% exact arm64 timing config smoke passed; builds=0 boots=0 scratch retired'
	exit 0
fi

CURRENT_STAGE=build
progress '10% building full arm64 timing Image on VM-internal ext4'
fifo="$OUT_DIR/build.fifo"
mkfifo "$fifo"
set +e
setsid make -C "$WORKTREE" O="$BUILD_OUT" ARCH=arm64 -j"$JOBS" Image > "$fifo" 2>&1 &
ACTIVE_PID=$!
set -e
: > "$RAW_DIR/build.log"
steps=0
while IFS= read -r line; do
	printf '%s\n' "$line" >> "$RAW_DIR/build.log"
	case "$line" in
		*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
			steps=$((steps + 1))
			if [ $((steps % 50)) -eq 0 ]; then
				percent=$((10 + steps / 150))
				[ "$percent" -le 76 ] || percent=76
				progress "$percent% building arm64 timing Image ($steps compiler/link steps)"
			fi
			;;
	esac
done < "$fifo"
set +e
wait "$ACTIVE_PID"
make_rc=$?
set -e
ACTIVE_PID=
find "$fifo" -delete
[ "$make_rc" = 0 ] || die "arm64 Image build failed: $make_rc"
[ -s "$IMAGE" ] || die 'arm64 timing Image missing'
[ -s "$OBJECT" ] || die 'arm64 exec_lease.o missing'
grep -Ein '(^|[[:space:]])(warning|error):|Clock skew detected|clock skew' "$RAW_DIR/build.log" > "$RAW_DIR/compiler-diagnostics.txt" || true
[ ! -s "$RAW_DIR/compiler-diagnostics.txt" ] || die 'compiler or build clock-skew diagnostic found'
readelf -h "$OBJECT" > "$RAW_DIR/exec-lease-readelf.txt"
nm -a "$OBJECT" > "$RAW_DIR/exec-lease-nm.txt"
strings -a "$OBJECT" > "$RAW_DIR/exec-lease-strings.txt"
grep -q 'sched_exec_r4_measure_test_suite' "$RAW_DIR/exec-lease-nm.txt" || die 'measurement suite symbol missing'
grep -qx 'sched_exec_lease_r4_measure' "$RAW_DIR/exec-lease-strings.txt" || die 'measurement suite string missing'

CURRENT_STAGE=artifact_preservation
progress '77% losslessly preserving exact Image and object before QEMU'
image_archive="$ARTIFACT_DIR/Image.zst"
object_archive="$ARTIFACT_DIR/exec_lease.o.zst"
zstd -T0 -9 -q -f "$IMAGE" -o "$image_archive"
zstd -T0 -9 -q -f "$OBJECT" -o "$object_archive"
zstd -q -t "$image_archive"
zstd -q -t "$object_archive"
image_sha=$(file_sha "$IMAGE")
object_sha=$(file_sha "$OBJECT")
image_archive_sha=$(file_sha "$image_archive")
object_archive_sha=$(file_sha "$object_archive")
[ "$(zstd -q -dc "$image_archive" | sha256sum | awk '{print $1}')" = "$image_sha" ] || die 'Image archive restore mismatch'
[ "$(zstd -q -dc "$object_archive" | sha256sum | awk '{print $1}')" = "$object_sha" ] || die 'object archive restore mismatch'
{
	printf 'build_storage_filesystem=%s\n' "$build_storage_type"
	printf 'image_source_sha256=%s\nimage_archive_sha256=%s\n' "$image_sha" "$image_archive_sha"
	printf 'object_source_sha256=%s\nobject_archive_sha256=%s\n' "$object_sha" "$object_archive_sha"
	printf 'compression=zstd-level-9-lossless\nrestore_verified=true\n'
} > "$ARTIFACT_DIR/manifest.txt"

append='console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_r4_measure kunit_shutdown=poweroff ftrace=irqsoff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0'
{
	printf 'taskset -c %s qemu-system-aarch64 -machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi -smp %s,maxcpus=%s -m 4096 -nic none -nographic -no-reboot -kernel [verified Image] -append [recorded next line]\n' "$host_allowed_list" "$GUEST_VCPUS" "$GUEST_VCPUS"
	printf '%s\n' "$append"
} > "$RAW_DIR/qemu-command.txt"

expand_cpulist()
{
	awk -v cpus="$1" 'BEGIN {
	  n=split(cpus,part,",");
	  for(i=1;i<=n;i++) {
	    if(part[i] ~ /^[0-9]+$/) print part[i];
	    else {split(part[i],range,"-"); for(cpu=range[1];cpu<=range[2];cpu++) print cpu}
	  }
	}'
}
mapfile -t host_cpus < <(expand_cpulist "$host_allowed_list")
[ "${#host_cpus[@]}" -gt 0 ] || die 'could not expand container CPU allowance'

CURRENT_STAGE=qemu_boot
progress '80% booting pinned 2-vCPU arm64 QEMU; waiting for 682 immutable rows'
set +e
setsid taskset -c "$host_allowed_list" qemu-system-aarch64 \
	-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
	-smp "$GUEST_VCPUS",maxcpus="$GUEST_VCPUS" -m 4096 -nic none -nographic -no-reboot \
	-kernel "$IMAGE" -append "$append" > "$SERIAL" 2>&1 &
ACTIVE_PID=$!
set -e
qemu_pid=$ACTIVE_PID
printf 'qemu_pid=%s\nparent_allowed_cpus=%s\n' "$qemu_pid" "$host_allowed_list" > "$RAW_DIR/vcpu-pinning.txt"
declare -A pinned_vcpu
pinned_vcpu=()
pin_deadline=$((SECONDS + 300))
while kill -0 "$qemu_pid" 2>/dev/null && [ "${#pinned_vcpu[@]}" -lt "$GUEST_VCPUS" ]; do
	rows_before_pin=$(grep -c 'R4_E4_RESULT ' "$SERIAL" 2>/dev/null || true)
	[ "$rows_before_pin" = 0 ] || die 'measurement emitted rows before all QEMU vCPU threads were pinned'
	for task_dir in /proc/"$qemu_pid"/task/*; do
		[ -r "$task_dir/comm" ] || continue
		comm=$(cat "$task_dir/comm")
		case "$comm" in
			CPU\ */TCG)
				vcpu=${comm#CPU }
				vcpu=${vcpu%/TCG}
				case "$vcpu" in ''|*[!0-9]*) continue ;; esac
				[ "$vcpu" -lt "$GUEST_VCPUS" ] || continue
				if [ -z "${pinned_vcpu[$vcpu]+set}" ]; then
					tid=${task_dir##*/}
					host_cpu=${host_cpus[$((vcpu % ${#host_cpus[@]}))]}
					taskset -pc "$host_cpu" "$tid" >> "$RAW_DIR/vcpu-pinning.txt" 2>&1 || die "failed to pin QEMU vCPU $vcpu"
					actual=$(awk '/^Cpus_allowed_list:/ {print $2}' "$task_dir/status")
					[ "$actual" = "$host_cpu" ] || die "QEMU vCPU $vcpu affinity did not become singleton $host_cpu"
					printf 'vcpu=%s tid=%s host_cpu=%s verified_allowed_list=%s\n' "$vcpu" "$tid" "$host_cpu" "$actual" >> "$RAW_DIR/vcpu-pinning.txt"
					pinned_vcpu[$vcpu]=1
				fi
				;;
		esac
	done
	[ "$SECONDS" -lt "$pin_deadline" ] || die 'timed out pinning all QEMU vCPU threads'
	sleep 1
done
[ "${#pinned_vcpu[@]}" = "$GUEST_VCPUS" ] || die 'QEMU exited before all vCPU threads were pinned'
printf 'rows_before_all_vcpus_pinned=0\npinned_vcpu_threads=%s\n' "$GUEST_VCPUS" >> "$RAW_DIR/vcpu-pinning.txt"

deadline=$((SECONDS + QEMU_TIMEOUT))
last_rows=-1
qemu_timed_out=0
while kill -0 "$qemu_pid" 2>/dev/null; do
	rows_now=$(grep -c 'R4_E4_RESULT ' "$SERIAL" 2>/dev/null || true)
	if [ "$rows_now" != "$last_rows" ]; then
		percent=$((80 + rows_now * 15 / 682))
		[ "$percent" -le 95 ] || percent=95
		progress "$percent% arm64 QEMU measurement rows $rows_now/682"
		last_rows=$rows_now
	fi
	if [ "$SECONDS" -ge "$deadline" ]; then
		qemu_timed_out=1
		break
	fi
	sleep 10
done
if [ "$qemu_timed_out" = 1 ]; then
	printf '124\n' > "$RAW_DIR/qemu-exit-code.txt"
	terminate_active
	die "QEMU measurement exceeded ${QEMU_TIMEOUT}s"
fi
set +e
wait "$qemu_pid"
qemu_rc=$?
set -e
ACTIVE_PID=
printf '%s\n' "$qemu_rc" > "$RAW_DIR/qemu-exit-code.txt"
[ "$qemu_rc" = 0 ] || die "QEMU measurement did not power off cleanly: $qemu_rc"

CURRENT_STAGE=evidence_validation
progress '96% validating KTAP, exact 682-cell matrix, diagnostics, and fixed gates'
tr -d '\r' < "$SERIAL" | sed -E 's/^\[[^]]+\][[:space:]]*//' > "$KTAP"
! grep -Fq 'Unknown kernel command line parameters' "$SERIAL" || die 'guest reported unknown kernel command-line parameters'
grep -Fq "Starting tracer 'irqsoff'" "$SERIAL" || die 'irqsoff tracer did not start'
grep -Fq '# Subtest: sched_exec_lease_r4_measure' "$KTAP" || die 'measurement KUnit suite did not start'
grep -Eq '^ok [0-9]+( -)? sched_exec_lease_r4_measure([[:space:]]|$)' "$KTAP" || die 'measurement KUnit suite did not pass'
! grep -Eq '^[[:space:]]*not ok [0-9]+' "$KTAP" || die 'KUnit reported failure'
! grep -Fq '# SKIP' "$KTAP" || die 'KUnit reported a required skip'
kunit_cases=$(grep -Ec '^[[:space:]]*ok [0-9]+( -)? sched_exec_r4_measure_(publication|picker|irq|recovery|notifier|current|offline)_case([[:space:]]|$)' "$KTAP" || true)
[ "$kunit_cases" = 7 ] || die "measurement KUnit case count changed: $kunit_cases"
grep -F 'R4_E4_RESULT ' "$KTAP" | sed 's/^.*R4_E4_RESULT /R4_E4_RESULT /' > "$ROWS"
grep -F 'R4_E4_SUMMARY ' "$KTAP" | sed 's/^.*R4_E4_SUMMARY /R4_E4_SUMMARY /' > "$SUMMARIES"
GUEST_VCPUS="$GUEST_VCPUS" "$PARSER" "$ROWS" "$SUMMARIES" "$DERIVED_DIR" > "$RAW_DIR/parser.log"
jq -e '.status == "passed_exact_682_cell_parser" and .result_rows == 682 and .measured_pairs == 6820000 and .harness_observation_failures == 0 and .summary_mismatches == 0' "$DERIVED_DIR/result.json" >/dev/null || die 'measurement parser result contract failed'

# The path and content hash are checked above before this dynamic source.
# shellcheck disable=SC1090,SC1091
. "$WARNING_CLASSIFIER"
capsched_collect_kernel_warning_reports "$SERIAL" "$RAW_DIR/kernel-warning-reports.txt" || die 'kernel warning classifier failed'
grep -Ein 'Clock skew detected|clock skew|timekeeping watchdog.*skew|clocksource.*unstable' "$SERIAL" > "$RAW_DIR/clock-skew-reports.txt" || true
warning_count=$(wc -l < "$RAW_DIR/kernel-warning-reports.txt" | tr -d ' ')
clock_skew_count=$(wc -l < "$RAW_DIR/clock-skew-reports.txt" | tr -d ' ')
rejected_cells=$(jq -r '.rejected_cells' "$DERIVED_DIR/result.json")
threshold_breaches=$(jq -r '.threshold_breaches' "$DERIVED_DIR/result.json")
if [ "$warning_count" -gt 0 ] || [ "$clock_skew_count" -gt 0 ] || [ "$rejected_cells" -gt 0 ]; then
	classification=rejected_r4_local_quantum_measurement
	x86_may_start=false
else
	classification=passed_r4_local_quantum_measurement
	x86_may_start=true
fi

CURRENT_STAGE=sealing
[ "$(file_sha "${BASH_SOURCE[0]}")" = "$runner_initial_sha" ] || die 'measurement runner changed during execution'
[ "$(file_sha "$PARSER")" = "$parser_initial_sha" ] || die 'measurement parser changed during execution'
[ "$(file_sha "$WARNING_CLASSIFIER")" = "$WARNING_CLASSIFIER_SHA" ] || die 'warning classifier changed during execution'
retire_owned_paths
[ "$BUILD_RETIRED:$WORKTREE_RETIRED" = 1:1 ] || die 'run-owned scratch retirement failed'
printf 'build_output_retired=true\nworktree_retired=true\n' >> "$ARTIFACT_DIR/manifest.txt"

config_sha=$(file_sha "$RAW_DIR/arm64.config")
serial_sha=$(file_sha "$SERIAL")
ktap_sha=$(file_sha "$KTAP")
table_sha=$(file_sha "$DERIVED_DIR/measurements.tsv")
pinning_sha=$(file_sha "$RAW_DIR/vcpu-pinning.txt")
host_env_sha=$(file_sha "$RAW_DIR/outer-host-environment.txt")
parser_result_sha=$(file_sha "$DERIVED_DIR/result.json")
{
	cd "$DERIVED_DIR"
	find . -type f -print0 | sort -z | xargs -0 sha256sum
} > "$OUT_DIR/derived-manifest.sha256"
derived_manifest_sha=$(file_sha "$OUT_DIR/derived-manifest.sha256")
derived_artifact_count=$(find "$DERIVED_DIR" -type f | wc -l | tr -d ' ')
chmod -R a-w "$DERIVED_DIR"
{
	cd "$RAW_DIR"
	find . -type f ! -name raw-manifest.sha256 -print0 | sort -z | xargs -0 sha256sum
} > "$RAW_DIR/raw-manifest.sha256"
raw_manifest_sha=$(file_sha "$RAW_DIR/raw-manifest.sha256")
raw_artifact_count=$(find "$RAW_DIR" -type f | wc -l | tr -d ' ')
chmod -R a-w "$RAW_DIR"

container_uname=$(sed -n '1p' "$RAW_DIR/container-uname.txt")
compiler=$(sed -n '1p' "$RAW_DIR/compiler.txt")
qemu_version=$(sed -n '1p' "$RAW_DIR/qemu-version.txt")
clocksource_detail=$(grep -Ei 'clocksource|arch_sys_counter' "$SERIAL" | tail -n 1 || true)
jq -n \
	--arg run_id "$RUN_ID" --arg status "$classification" \
	--arg runner_sha "$runner_initial_sha" --arg parser_sha "$parser_initial_sha" \
	--arg compiler "$compiler" --arg qemu_version "$qemu_version" \
	--arg container_uname "$container_uname" --arg clocksource_detail "$clocksource_detail" \
	--arg host_allowed "$host_allowed_list" --arg host_env_sha "$host_env_sha" \
	--arg config_sha "$config_sha" --arg image_sha "$image_sha" --arg image_archive_sha "$image_archive_sha" \
	--arg object_sha "$object_sha" --arg object_archive_sha "$object_archive_sha" \
	--arg serial_sha "$serial_sha" --arg ktap_sha "$ktap_sha" --arg table_sha "$table_sha" \
	--arg pinning_sha "$pinning_sha" --arg parser_result_sha "$parser_result_sha" \
	--arg raw_manifest_sha "$raw_manifest_sha" --arg derived_manifest_sha "$derived_manifest_sha" \
	--argjson raw_artifact_count "$raw_artifact_count" --argjson warning_count "$warning_count" \
	--argjson derived_artifact_count "$derived_artifact_count" \
	--argjson clock_skew_count "$clock_skew_count" --argjson rejected_cells "$rejected_cells" \
	--argjson threshold_breaches "$threshold_breaches" --argjson x86_may_start "$x86_may_start" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1",
  run_id:$run_id,
  status:$status,
  architecture:"arm64",
  source:{parent:"da9ce9159b3450c28c8faf8dceac671fb7bfeba2",commit:"9e4cb44fd1a1f998fcc288df87dad60505e8bf18",tree:"e6feb28a29fc8c37bc46af0fbf37de30f3401a4f",diff_sha256:"bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2"},
  prerequisites:{combined_run:"20260719T-p5a-r4-e4-source-e3-regression-r3",closure_r1_sha256:"c1d9afa02f516e893e0dd0f910b7d1a60a56f2c1389b9426878545ef6a691325",closure_r2_sha256:"9c19029ca7c18d44ec873374c9e85327a7a81d94221b1e10538f19cd16e8633e",closure_normalized_sha256:"ff91f2517b460b4d60322ea1670aab94058a8db4246bf2e2b63b7454250f528f",independent_double_closure_passed:true},
  runner:{sha256:$runner_sha,parser_sha256:$parser_sha,warning_classifier_sha256:"8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a"},
  matrix:{publication:288,picker_kick:144,irq_dispatch:9,recovery:144,notifier:48,current_stop:24,offline:25,total_cells:682,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000,total_measured_pairs:6820000,result_rows:682},
  gates_ns:{ordinary_local:{additional_p99:5000,additional_p999:25000,additional_max:50000},offline_local:{additional_p99:25000,additional_p999:40000,additional_max:50000},asynchronous_availability:{p99:10000000,max:100000000},normalized_base_slice:700000},
  parser:{result_sha256:$parser_result_sha,rejected_cells:$rejected_cells,threshold_breaches:$threshold_breaches,malformed_or_missing_rows:0,duplicate_or_unexpected_cells:0,harness_observation_failures:0,summary_mismatches:0},
  diagnostics:{compiler_diagnostics:0,clock_skew_reports:$clock_skew_count,kernel_warning_reports:$warning_count,kunit_suite_passed:true,kunit_cases_passed:7,kunit_cases_failed:0,kunit_cases_skipped:0,qemu_exit_code:0},
  placement:{guest_vcpus:2,host_container_allowed_cpus:$host_allowed,qemu_vcpu_threads_pinned:2,rows_before_all_vcpus_pinned:0,pinning_record_sha256:$pinning_sha,per_cell_guest_measurement_cpu_recorded:true,per_sample_guest_cpu_migration_rejected:true,irq_preempt_state_recorded:true},
  environment:{outer_host_record_sha256:$host_env_sha,outer_virtualization:"Apple Container machine domainlease-dev",container_uname:$container_uname,compiler:$compiler,qemu_version:$qemu_version,qemu_accelerator:"tcg,thread=multi",qemu_machine:"virt,gic-version=3",qemu_cpu:"cortex-a57",qemu_memory_mib:4096,qemu_network_disabled:true,sample_clock:"local_clock",clocksource_detail:$clocksource_detail,virtualized_result_supports_bare_metal_claim:false},
  artifacts:{raw_artifact_count:$raw_artifact_count,raw_manifest_sha256:$raw_manifest_sha,derived_artifact_count:$derived_artifact_count,derived_manifest_sha256:$derived_manifest_sha,config_sha256:$config_sha,image:{archive:"raw/boot-artifacts/arm64/Image.zst",source_sha256:$image_sha,archive_sha256:$image_archive_sha,restore_verified:true},exec_lease_object:{archive:"raw/boot-artifacts/arm64/exec_lease.o.zst",source_sha256:$object_sha,archive_sha256:$object_archive_sha,restore_verified:true},serial_sha256:$serial_sha,normalized_ktap_sha256:$ktap_sha,measurement_table_sha256:$table_sha,raw_inputs_read_only:true,derived_outputs_read_only:true,build_output_retired:true,worktree_retired:true},
  architecture_measurement_valid:true,
  threshold_failure_is_valid_negative_evidence:true,
  x86_64_measurement_may_start:$x86_may_start,
  measurement_result_accepted:false,
  e5_plan_may_start:false,
  e5_source_may_start:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
  n136_complete:false,
  bare_metal_validated:false,
  performance_claim:false,
  cost_claim:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"

if [ "$classification" = rejected_r4_local_quantum_measurement ]; then
	progress "100% complete valid negative arm64 evidence; rejected cells=$rejected_cells breaches=$threshold_breaches warnings=$warning_count skew=$clock_skew_count; x86 stopped"
else
	progress '100% arm64 local-quantum measurement passed; same-source x86_64 timing may start'
fi
printf 'result=%s\nsha256=%s\n' "$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
