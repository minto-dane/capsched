#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e4-bucket-measurement"
CONTRACT="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r3-e4-bucket-measurement-v1.json"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement-source-gate/20260716T-p5a-r3-e4-source-gate-r2/result.json"
REGRESSION="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-e3-regression-diagnostic/20260716T-p5a-r3-e4-e3-regression-r2/result.json"
SOURCE_GATE_SHA=8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c
REGRESSION_SHA=3d02a2b6c52a856e6bde5417665bfc41e1fa547c774f9274f1f85d53167b5707
E4_COMMIT=f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
E4_TREE=61541cb0c8aedef941e534c73effdea1f6b3d938
E3_COMMIT=be9339363a99fb31a5b7d03f3d70430d64a45593
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
BUILD_ROOT=${BUILD_ROOT:-"/var/tmp/linux-cap-builds/p5a-r3-e4-measurement/$RUN_ID"}
BUILD_OUT="$BUILD_ROOT/arm64"
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
HOST_ENV_FILE=${HOST_ENV_FILE:-}
JOBS=${JOBS:-2}
QEMU_TIMEOUT=${QEMU_TIMEOUT:-7200}
BUILD_STORAGE_MIN_KIB=${BUILD_STORAGE_MIN_KIB:-16777216}
POSTPROCESS_ONLY=${POSTPROCESS_ONLY:-0}
POSTPROCESS_RECOVERY=${POSTPROCESS_RECOVERY:-0}
IMAGE="$BUILD_OUT/arch/arm64/boot/Image"
OBJECT="$BUILD_OUT/kernel/sched/exec_lease.o"
SERIAL="$OUT_DIR/qemu-serial.log"
KTAP="$OUT_DIR/qemu-ktap.log"
ROWS_RAW="$OUT_DIR/e4-result-rows.txt"
TABLE="$OUT_DIR/e4-measurements.tsv"
FAILURES="$OUT_DIR/threshold-failures.tsv"
ARTIFACT_DIR="$OUT_DIR/boot-artifacts/arm64"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	mkdir -p "$(dirname "$PROGRESS_FILE")"
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

for command in awk cmp cp cut df find gcc git grep jq lscpu make mkdir mkfifo \
	nm qemu-system-aarch64 readelf rm sed sha256sum sleep sort stat strings tail \
	timeout tr uname wc zstd; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
case "$POSTPROCESS_ONLY:$POSTPROCESS_RECOVERY" in
	0:0|1:0|1:1) ;;
	*) die 'POSTPROCESS_ONLY and POSTPROCESS_RECOVERY must be 0/1, and recovery requires postprocess-only mode' ;;
esac
postprocess_only_json=false
if [ "$POSTPROCESS_ONLY" = 1 ]; then
	postprocess_only_json=true
fi

if [ "$POSTPROCESS_ONLY" = 0 ]; then
	if [ -z "$HOST_ENV_FILE" ] || [ ! -s "$HOST_ENV_FILE" ]; then
		die 'host environment record is unavailable'
	fi
	case "$BUILD_ROOT" in
		/var/tmp/linux-cap-builds/p5a-r3-e4-measurement/*) ;;
		*) die "unsafe or non-internal build root: $BUILD_ROOT" ;;
	esac

	rm -rf "$BUILD_ROOT" "$OUT_DIR"
	mkdir -p "$BUILD_OUT" "$OUT_DIR" "$ARTIFACT_DIR"
	build_storage_type=$(stat -f -c %T "$BUILD_ROOT")
	[ "$build_storage_type" = ext2/ext3 ] \
		|| die "build root is not internal ext4-compatible storage: $build_storage_type"
	build_storage_available_kib=$(df -Pk "$BUILD_ROOT" | awk 'NR == 2 {print $4}')
	[ "$build_storage_available_kib" -ge "$BUILD_STORAGE_MIN_KIB" ] \
		|| die "internal build storage below ${BUILD_STORAGE_MIN_KIB}KiB"
	{
		printf 'build_root=%s\n' "$BUILD_ROOT"
		printf 'filesystem=%s\n' "$build_storage_type"
		printf 'available_kib_at_start=%s\n' "$build_storage_available_kib"
		printf 'shared_host_build_output=false\n'
		df -Pk "$BUILD_ROOT" "$OUT_DIR"
	} > "$OUT_DIR/build-storage.txt"
else
	[ -d "$OUT_DIR" ] || die "postprocess evidence directory missing: $OUT_DIR"
	[ -d "$ARTIFACT_DIR" ] || die 'postprocess artifact directory missing'
fi

progress '3% locking exact source, prerequisite results, and immutable measurement contract'
[ "$(sha256sum "$SOURCE_GATE" | awk '{print $1}')" = "$SOURCE_GATE_SHA" ] \
	|| die 'source-gate result hash changed'
[ "$(sha256sum "$REGRESSION" | awk '{print $1}')" = "$REGRESSION_SHA" ] \
	|| die 'exact-source regression result hash changed'
jq -e --argjson postprocess_only "$postprocess_only_json" '
  (
    ($postprocess_only == false and
     .status == "source_and_exact_source_regression_passed_measurement_authorized" and
     .authorization.e4_measurement_may_start == true) or
    ($postprocess_only == true and
     .status == "rejected_r3_bucket_measurement" and
     .authorization.e4_measurement_complete == true and
     .authorization.e4_measurement_may_start == false)
  ) and
  .source.candidate_commit == "f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1" and
  .matrix.one_projection_cells == 32 and .matrix.hotplug_cells == 5 and
  .matrix.fanout_cells == 5 and .matrix.total_cells == 42 and
  .matrix.warmup_pairs_per_cell == 256 and
  .matrix.measured_pairs_per_cell == 10000 and
  .matrix.normalized_base_slice_ns == 700000 and
  .authorization.e4_measurement_accepted == false
' "$CONTRACT" >/dev/null
jq -e '
  .status == "passed_static_source_gate_awaiting_e3_regression_diagnostic" and
  .candidate_commit == "f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1" and
  .candidate_tree == "61541cb0c8aedef941e534c73effdea1f6b3d938" and
  .architectures == ["arm64","x86_64"] and
  .matrix.total_cells == 42 and .w1_compiler_warnings == 0 and
  .disabled_e4_symbols_relocations_strings == 0
' "$SOURCE_GATE" >/dev/null
jq -e '
  .status == "passed_exact_e4_source_e3_four_boot_regression" and
  .candidate_commit == "f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1" and
  .candidate_tree == "61541cb0c8aedef941e534c73effdea1f6b3d938" and
  .passed_cases_per_boot == 20 and .failed_cases == 0 and
  .skipped_cases == 0 and .warning_reports == 0 and
  .internal_ext4_build_storage_verified == true and
  .e4_measurement_may_start == true and .e4_measurement_accepted == false
' "$REGRESSION" >/dev/null
if git -C "$E4_DIR" rev-parse --git-dir >/dev/null 2>&1; then
	source_repo="$E4_DIR"
	source_ref=HEAD
	[ "$(git -C "$source_repo" rev-parse HEAD)" = "$E4_COMMIT" ] \
		|| die 'E4 worktree commit moved'
elif [ "$POSTPROCESS_ONLY" = 1 ]; then
	source_repo="$WORKSPACE_DIR/linux"
	source_ref="$E4_COMMIT"
	git -C "$source_repo" cat-file -e "$E4_COMMIT^{commit}" \
		|| die 'preserved E4 commit object is unavailable'
else
	die "E4 measurement worktree is unavailable: $E4_DIR"
fi
[ "$(git -C "$source_repo" rev-parse "$source_ref^{tree}")" = "$E4_TREE" ] \
	|| die 'E4 tree moved'
[ "$(git -C "$source_repo" rev-parse "$source_ref^")" = "$E3_COMMIT" ] \
	|| die 'E4 parent moved'
[ "$(git -C "$WORKSPACE_DIR/linux" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] \
	|| die 'primary Linux moved'
if [ "$source_ref" = HEAD ]; then
	git -C "$source_repo" diff --quiet HEAD -- init/Kconfig \
		kernel/sched/exec_lease.c include/linux/sched.h \
		include/linux/sched_exec_lease.h kernel/sched/Makefile \
		kernel/sched/sched.h kernel/sched/fair.c kernel/sched/core.c \
		|| die 'E4 source boundary is dirty'
fi

if [ "$POSTPROCESS_ONLY" = 0 ]; then
cp "$HOST_ENV_FILE" "$OUT_DIR/host-environment.txt"
uname -a > "$OUT_DIR/container-uname.txt"
lscpu > "$OUT_DIR/container-lscpu.txt"
gcc --version > "$OUT_DIR/compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-version.txt"
if [ -d /sys/devices/system/cpu/cpufreq ]; then
	find /sys/devices/system/cpu/cpufreq -maxdepth 2 -type f \
		\( -name scaling_governor -o -name scaling_cur_freq \
		-o -name cpuinfo_cur_freq \) -print -exec sed -n '1p' {} \; \
		> "$OUT_DIR/container-frequency-governor.txt" 2>/dev/null || true
else
	printf '%s\n' 'unavailable in Apple Container machine' \
		> "$OUT_DIR/container-frequency-governor.txt"
fi
if [ ! -s "$OUT_DIR/container-frequency-governor.txt" ]; then
	printf '%s\n' 'unavailable: no cpufreq governor or frequency files exposed' \
		> "$OUT_DIR/container-frequency-governor.txt"
fi

progress '7% configuring arm64 measurement Image on internal ext4'
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 defconfig \
	> "$OUT_DIR/defconfig.log" 2>&1
"$E4_DIR/scripts/config" --file "$BUILD_OUT/.config" \
	-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
	-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
	-e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS \
	-e KUNIT_AUTORUN_ENABLED -e SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST \
	-e SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST \
	--set-str KUNIT_DEFAULT_FILTER_GLOB sched_exec_lease_bucket_measure \
	--set-val KUNIT_DEFAULT_TIMEOUT 7200 \
	-e PROVE_LOCKING -e DEBUG_OBJECTS -e DEBUG_OBJECTS_WORK -e PROVE_RCU \
	-e FTRACE -e IRQSOFF_TRACER -e DEBUG_INFO_NONE -d MODULES \
	--set-val NR_CPUS 64
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 olddefconfig \
	> "$OUT_DIR/olddefconfig.log" 2>&1
for required in \
	CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y \
	CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST=y \
	CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
	'CONFIG_KUNIT_DEFAULT_FILTER_GLOB="sched_exec_lease_bucket_measure"' \
	CONFIG_PROVE_LOCKING=y CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_PROVE_RCU=y \
	CONFIG_FTRACE=y CONFIG_IRQSOFF_TRACER=y; do
	grep -Fxq "$required" "$BUILD_OUT/.config" \
		|| die "measurement config missing: $required"
done
grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$BUILD_OUT/.config" \
	|| die 'KUNIT_ALL_TESTS enabled'
cp "$BUILD_OUT/.config" "$OUT_DIR/arm64.config"
grep -E '^CONFIG_(PROVE_LOCKING|LOCKDEP|DEBUG_OBJECTS_WORK|PROVE_RCU|FTRACE|IRQSOFF_TRACER|RCU_STALL_COMMON|SOFTLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR_[A-Z_]+)=' \
	"$BUILD_OUT/.config" > "$OUT_DIR/warning-config.txt" || true
grep -E '^CONFIG_(MITIGATION|ARM64_PTR_AUTH|ARM64_BTI|RANDOMIZE_BASE|STACKPROTECTOR|HARDENED_USERCOPY|FORTIFY_SOURCE)' \
	"$BUILD_OUT/.config" > "$OUT_DIR/mitigation-config.txt" || true
if [ "${CONFIG_SMOKE_ONLY:-0}" = 1 ]; then
	rm -rf "$BUILD_ROOT"
	progress '100% arm64 64-vCPU measurement config smoke passed; no build launched'
	exit 0
fi

progress '10% building full arm64 measurement Image (compiler steps update progress)'
fifo="$OUT_DIR/build.fifo"
rm -f "$fifo"
mkfifo "$fifo"
set +e
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 -j"$JOBS" Image \
	> "$fifo" 2>&1 &
make_pid=$!
set -e
: > "$OUT_DIR/build.log"
steps=0
while IFS= read -r line; do
	printf '%s\n' "$line" >> "$OUT_DIR/build.log"
	case "$line" in
	*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
		steps=$((steps + 1))
		if [ $((steps % 50)) -eq 0 ]; then
			percent=$((10 + steps / 145))
			[ "$percent" -le 77 ] || percent=77
			progress "$percent% building arm64 measurement Image ($steps compiler/link steps)"
		fi
		;;
	esac
done < "$fifo"
set +e
wait "$make_pid"
make_rc=$?
set -e
rm -f "$fifo"
[ "$make_rc" = 0 ] || die "arm64 Image build failed: $make_rc"
test -s "$IMAGE" || die 'arm64 measurement Image missing'
test -s "$OBJECT" || die 'arm64 exec_lease.o missing'
readelf -h "$OBJECT" > "$OUT_DIR/exec-lease-readelf.txt"
! grep -Eq ':[0-9]+(:[0-9]+)?: warning:' "$OUT_DIR/build.log" \
	|| die 'compiler warning found'
nm -a "$OBJECT" > "$OUT_DIR/exec-lease-nm.txt"
strings -a "$OBJECT" > "$OUT_DIR/exec-lease-strings.txt"
grep -q 'sched_exec_bucket_measure_test_suite' "$OUT_DIR/exec-lease-nm.txt" \
	|| die 'measurement suite symbol missing'
grep -qx 'sched_exec_lease_bucket_measure' "$OUT_DIR/exec-lease-strings.txt" \
	|| die 'measurement suite string missing'

progress '78% preserving exact boot Image and object before QEMU'
image_archive="$ARTIFACT_DIR/Image.zst"
object_archive="$ARTIFACT_DIR/exec_lease.o.zst"
zstd -T0 -9 -q -f "$IMAGE" -o "$image_archive"
zstd -T0 -9 -q -f "$OBJECT" -o "$object_archive"
zstd -q -t "$image_archive"
zstd -q -t "$object_archive"
image_sha=$(sha256sum "$IMAGE" | awk '{print $1}')
object_sha=$(sha256sum "$OBJECT" | awk '{print $1}')
image_archive_sha=$(sha256sum "$image_archive" | awk '{print $1}')
object_archive_sha=$(sha256sum "$object_archive" | awk '{print $1}')
image_restored_sha=$(zstd -q -dc "$image_archive" | sha256sum | awk '{print $1}')
object_restored_sha=$(zstd -q -dc "$object_archive" | sha256sum | awk '{print $1}')
[ "$image_sha" = "$image_restored_sha" ] \
	|| die 'Image archive restore hash mismatch'
[ "$object_sha" = "$object_restored_sha" ] \
	|| die 'object archive restore hash mismatch'
{
	printf 'build_storage_filesystem=%s\n' "$build_storage_type"
	printf 'image_source_sha256=%s\n' "$image_sha"
	printf 'image_archive_sha256=%s\n' "$image_archive_sha"
	printf 'image_restored_sha256=%s\n' "$image_restored_sha"
	printf 'object_source_sha256=%s\n' "$object_sha"
	printf 'object_archive_sha256=%s\n' "$object_archive_sha"
	printf 'object_restored_sha256=%s\n' "$object_restored_sha"
	printf 'compression=zstd-level-9-lossless\n'
} > "$ARTIFACT_DIR/manifest.txt"

printf '%s\n' "qemu-system-aarch64 -machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi -smp 64,maxcpus=64 -m 4096 -nic none -nographic -no-reboot -kernel [verified Image] -append [recorded below]" \
	> "$OUT_DIR/qemu-command.txt"
printf '%s\n' 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket_measure kunit_shutdown=poweroff ftrace=irqsoff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0' \
	>> "$OUT_DIR/qemu-command.txt"
progress '80% booting 64-vCPU arm64 QEMU; waiting for 42 immutable measurement rows'
set +e
timeout --signal=TERM "$QEMU_TIMEOUT" qemu-system-aarch64 \
	-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
	-smp 64,maxcpus=64 -m 4096 -nic none -nographic -no-reboot \
	-kernel "$IMAGE" \
	-append 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket_measure kunit_shutdown=poweroff ftrace=irqsoff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0' \
	> "$SERIAL" 2>&1 &
qemu_pid=$!
set -e
last_rows=-1
while kill -0 "$qemu_pid" 2>/dev/null; do
	rows=$(grep -c 'E4_RESULT ' "$SERIAL" 2>/dev/null || true)
	if [ "$rows" != "$last_rows" ]; then
		percent=$((80 + rows * 15 / 42))
		[ "$percent" -le 95 ] || percent=95
		progress "$percent% arm64 QEMU measurement rows $rows/42"
		last_rows=$rows
	fi
	sleep 10
done
set +e
wait "$qemu_pid"
qemu_rc=$?
set -e
printf '%s\n' "$qemu_rc" > "$OUT_DIR/qemu-exit-code.txt"
rm -rf "$BUILD_OUT"
printf 'successful_or_failed_qemu_build_output_pruned=true\n' \
	>> "$ARTIFACT_DIR/manifest.txt"
[ "$qemu_rc" = 0 ] || die "QEMU measurement did not power off cleanly: $qemu_rc"
else
	progress '95% resuming deterministic postprocessing from preserved QEMU evidence'
	for required_file in \
		"$SERIAL" "$OUT_DIR/qemu-exit-code.txt" "$OUT_DIR/arm64.config" \
		"$OUT_DIR/host-environment.txt" "$OUT_DIR/container-uname.txt" \
		"$OUT_DIR/compiler.txt" "$OUT_DIR/qemu-version.txt" \
		"$OUT_DIR/warning-config.txt" "$OUT_DIR/mitigation-config.txt" \
		"$OUT_DIR/build.log" "$OUT_DIR/build-storage.txt" \
		"$OUT_DIR/exec-lease-nm.txt" "$OUT_DIR/exec-lease-strings.txt" \
		"$OUT_DIR/qemu-command.txt" "$ARTIFACT_DIR/manifest.txt" \
		"$ARTIFACT_DIR/Image.zst" "$ARTIFACT_DIR/exec_lease.o.zst"; do
		[ -s "$required_file" ] || die "preserved postprocess input missing or empty: $required_file"
	done
	[ -e "$OUT_DIR/container-frequency-governor.txt" ] \
		|| die 'preserved frequency/governor availability record is missing'
	qemu_rc=$(sed -n '1p' "$OUT_DIR/qemu-exit-code.txt")
	[ "$qemu_rc" = 0 ] || die "preserved QEMU exit code is not clean: $qemu_rc"
	grep -Fxq 'filesystem=ext2/ext3' "$OUT_DIR/build-storage.txt" \
		|| die 'preserved build did not use internal ext4-compatible storage'
	grep -Fxq 'shared_host_build_output=false' "$OUT_DIR/build-storage.txt" \
		|| die 'preserved build-storage record permits shared-host output'
	! grep -Eq ':[0-9]+(:[0-9]+)?: warning:' "$OUT_DIR/build.log" \
		|| die 'preserved build log contains a compiler warning'
	grep -q 'sched_exec_bucket_measure_test_suite' "$OUT_DIR/exec-lease-nm.txt" \
		|| die 'preserved object symbol record lacks the measurement suite'
	grep -qx 'sched_exec_lease_bucket_measure' "$OUT_DIR/exec-lease-strings.txt" \
		|| die 'preserved object string record lacks the measurement suite'
	for required_config in \
		CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y \
		CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
		'CONFIG_KUNIT_DEFAULT_FILTER_GLOB="sched_exec_lease_bucket_measure"' \
		CONFIG_PROVE_LOCKING=y CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_PROVE_RCU=y \
		CONFIG_FTRACE=y CONFIG_IRQSOFF_TRACER=y; do
		grep -Fxq "$required_config" "$OUT_DIR/arm64.config" \
			|| die "preserved measurement config missing: $required_config"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$OUT_DIR/arm64.config" \
		|| die 'preserved measurement config enabled KUNIT_ALL_TESTS'

	manifest="$ARTIFACT_DIR/manifest.txt"
	awk -F= '
	BEGIN {
	  required="build_storage_filesystem image_source_sha256 image_archive_sha256 image_restored_sha256 object_source_sha256 object_archive_sha256 object_restored_sha256 compression successful_or_failed_qemu_build_output_pruned";
	}
	NF != 2 || $1 == "" || $2 == "" || seen[$1]++ {exit 2}
	{value[$1]=$2}
	END {
	  if (NR != 9) exit 3;
	  n=split(required,key," ");
	  for (i=1;i<=n;i++) if (!(key[i] in value)) exit 4;
	}
	' "$manifest" || die 'preserved artifact manifest is malformed or incomplete'
	manifest_value()
	{
		awk -F= -v key="$1" '$1 == key {print $2}' "$manifest"
	}
	build_storage_type=$(manifest_value build_storage_filesystem)
	image_sha=$(manifest_value image_source_sha256)
	image_archive_sha=$(manifest_value image_archive_sha256)
	image_restored_sha=$(manifest_value image_restored_sha256)
	object_sha=$(manifest_value object_source_sha256)
	object_archive_sha=$(manifest_value object_archive_sha256)
	object_restored_sha=$(manifest_value object_restored_sha256)
	[ "$build_storage_type" = ext2/ext3 ] \
		|| die 'preserved artifact manifest storage type changed'
	[ "$(manifest_value compression)" = zstd-level-9-lossless ] \
		|| die 'preserved artifact manifest compression changed'
	[ "$(manifest_value successful_or_failed_qemu_build_output_pruned)" = true ] \
		|| die 'preserved build output was not recorded as pruned'
	for digest in "$image_sha" "$image_archive_sha" "$image_restored_sha" \
		"$object_sha" "$object_archive_sha" "$object_restored_sha"; do
		printf '%s\n' "$digest" | grep -Eq '^[0-9a-f]{64}$' \
			|| die "invalid preserved artifact digest: $digest"
	done
	image_archive="$ARTIFACT_DIR/Image.zst"
	object_archive="$ARTIFACT_DIR/exec_lease.o.zst"
	zstd -q -t "$image_archive"
	zstd -q -t "$object_archive"
	[ "$(sha256sum "$image_archive" | awk '{print $1}')" = "$image_archive_sha" ] \
		|| die 'preserved Image archive hash mismatch'
	[ "$(sha256sum "$object_archive" | awk '{print $1}')" = "$object_archive_sha" ] \
		|| die 'preserved object archive hash mismatch'
	[ "$(zstd -q -dc "$image_archive" | sha256sum | awk '{print $1}')" = "$image_sha" ] \
		|| die 'preserved Image restore hash mismatch'
	[ "$(zstd -q -dc "$object_archive" | sha256sum | awk '{print $1}')" = "$object_sha" ] \
		|| die 'preserved object restore hash mismatch'
	[ "$image_sha" = "$image_restored_sha" ] \
		|| die 'preserved Image manifest restore hash mismatch'
	[ "$object_sha" = "$object_restored_sha" ] \
		|| die 'preserved object manifest restore hash mismatch'
fi

frequency_governor_source_empty=false
frequency_governor_available=true
if [ ! -s "$OUT_DIR/container-frequency-governor.txt" ]; then
	frequency_governor_source_empty=true
	frequency_governor_available=false
elif grep -Eq '^unavailable([ :]|$)' "$OUT_DIR/container-frequency-governor.txt"; then
	frequency_governor_available=false
fi
{
	printf 'availability_recorded=true\n'
	printf 'available=%s\n' "$frequency_governor_available"
	printf 'source_record_empty=%s\n' "$frequency_governor_source_empty"
	printf 'context=Apple Container guest running QEMU TCG\n'
} > "$OUT_DIR/frequency-governor-availability.txt"

progress '96% validating KTAP, exact cells, statistics, warnings, and fixed gates'
tr -d '\r' < "$SERIAL" | sed -E 's/^\[[^]]+\][[:space:]]*//' > "$KTAP"
! grep -Fq 'Unknown kernel command line parameters' "$SERIAL" \
	|| die 'guest reported unknown kernel command-line parameters'
grep -Fq "Starting tracer 'irqsoff'" "$SERIAL" \
	|| die 'irqsoff tracer did not start'
grep -Fq '# Subtest: sched_exec_lease_bucket_measure' "$KTAP" \
	|| die 'measurement KUnit suite did not start'
grep -Eq '^ok [0-9]+( -)? sched_exec_lease_bucket_measure([[:space:]]|$)' "$KTAP" \
	|| die 'measurement KUnit suite did not pass'
! grep -Eq '^[[:space:]]*not ok [0-9]+' "$KTAP" \
	|| die 'KUnit reported failure'
! grep -Fq '# SKIP' "$KTAP" || die 'KUnit reported a required skip'
kunit_cases=$(grep -Ec '^[[:space:]]*ok [0-9]+( -)? sched_exec_bucket_measure_(projection|hotplug|fanout)_case([[:space:]]|$)' "$KTAP" || true)
[ "$kunit_cases" = 3 ] || die "measurement KUnit case count: $kunit_cases"

grep -F 'E4_RESULT ' "$KTAP" | sed 's/^.*E4_RESULT /E4_RESULT /' > "$ROWS_RAW"
[ "$(wc -l < "$ROWS_RAW" | tr -d ' ')" = 42 ] \
	|| die 'E4 result row count mismatch'
awk '
function fail(code) { parser_status=code; exit code }
BEGIN {
  OFS="\t";
  metrics="control_min control_p50 control_p95 control_p99 control_p999 control_max treatment_min treatment_p50 treatment_p95 treatment_p99 treatment_p999 treatment_max additional_min additional_p50 additional_p95 additional_p99 additional_p999 additional_max";
  print "family","key","occupancy","inner","generation","active_rqs","samples","control_min","control_p50","control_p95","control_p99","control_p999","control_max","treatment_min","treatment_p50","treatment_p95","treatment_p99","treatment_p999","treatment_max","additional_min","additional_p50","additional_p95","additional_p99","additional_p999","additional_max","gate","recomputed_gate";
}
{
  if ($1 != "E4_RESULT") fail(2);
  delete value; delete seen; delete number;
  for (i = 2; i <= NF; i++) {
    at = index($i, "=");
    if (!at) fail(3);
    key = substr($i, 1, at - 1); val = substr($i, at + 1);
    if (key == "" || val == "" || seen[key]++) fail(4);
    value[key] = val;
  }
  if (!("family" in value) || !("samples" in value) || !("gate" in value)) fail(5);
  if (value["samples"] != "10000" || value["gate"] !~ /^(pass|reject)$/) fail(6);
  n = split(metrics, required, " ");
  for (i = 1; i <= n; i++) {
    if (!(required[i] in value) || value[required[i]] !~ /^[0-9]+$/) fail(7);
    number[required[i]] = value[required[i]] + 0;
  }
  if (!(number["control_min"] <= number["control_p50"] && number["control_p50"] <= number["control_p95"] && number["control_p95"] <= number["control_p99"] && number["control_p99"] <= number["control_p999"] && number["control_p999"] <= number["control_max"])) fail(8);
  if (!(number["treatment_min"] <= number["treatment_p50"] && number["treatment_p50"] <= number["treatment_p95"] && number["treatment_p95"] <= number["treatment_p99"] && number["treatment_p99"] <= number["treatment_p999"] && number["treatment_p999"] <= number["treatment_max"])) fail(9);
  if (!(number["additional_min"] <= number["additional_p50"] && number["additional_p50"] <= number["additional_p95"] && number["additional_p95"] <= number["additional_p99"] && number["additional_p99"] <= number["additional_p999"] && number["additional_p999"] <= number["additional_max"])) fail(10);
  occupancy=inner=generation=active="-";
  if (value["family"] == "one_projection") {
    if (value["occupancy"] !~ /^(1|8|32|64)$/ || value["inner"] !~ /^(0|1|64|4096)$/ || value["generation"] !~ /^(stable|raced)$/) fail(11);
    occupancy=value["occupancy"]; inner=value["inner"]; generation=value["generation"];
    cell="one_projection:" occupancy ":" inner ":" generation;
    rejected=(number["additional_p99"] > 5000 || number["additional_p999"] > 25000 || number["additional_max"] > 50000 || number["additional_max"] >= 700000);
    family_count["one_projection"]++;
  } else if (value["family"] == "hotplug") {
    if (value["occupancy"] !~ /^(0|1|8|32|64)$/) fail(12);
    occupancy=value["occupancy"]; cell="hotplug:" occupancy;
    rejected=(number["additional_p99"] > 25000 || number["additional_max"] > 50000 || number["additional_max"] >= 700000);
    family_count["hotplug"]++;
  } else if (value["family"] == "fanout") {
    if (value["active_rqs"] !~ /^(1|2|8|32|64)$/) fail(13);
    active=value["active_rqs"]; cell="fanout:" active;
    rejected=(number["treatment_p99"] > 10000000 || number["treatment_max"] > 100000000);
    family_count["fanout"]++;
  } else fail(14);
  if (cell_seen[cell]++) fail(15);
  recomputed=rejected ? "reject" : "pass";
  if (value["gate"] != recomputed) fail(16);
  print value["family"],cell,occupancy,inner,generation,active,value["samples"],value["control_min"],value["control_p50"],value["control_p95"],value["control_p99"],value["control_p999"],value["control_max"],value["treatment_min"],value["treatment_p50"],value["treatment_p95"],value["treatment_p99"],value["treatment_p999"],value["treatment_max"],value["additional_min"],value["additional_p50"],value["additional_p95"],value["additional_p99"],value["additional_p999"],value["additional_max"],value["gate"],recomputed;
}
END {
  if (parser_status) exit parser_status;
  if (NR != 42 || family_count["one_projection"] != 32 || family_count["hotplug"] != 5 || family_count["fanout"] != 5) exit 17;
}
' "$ROWS_RAW" > "$TABLE" || {
	parser_rc=$?
	die "malformed, incomplete, or self-inconsistent E4 rows (parser exit $parser_rc)"
}

{
	for occupancy in 1 8 32 64; do
		for inner in 0 1 64 4096; do
			for generation in stable raced; do
				printf 'one_projection:%s:%s:%s\n' "$occupancy" "$inner" "$generation"
			done
		done
	done
	for occupancy in 0 1 8 32 64; do printf 'hotplug:%s\n' "$occupancy"; done
	for active in 1 2 8 32 64; do printf 'fanout:%s\n' "$active"; done
} | sort > "$OUT_DIR/expected-cells.txt"
tail -n +2 "$TABLE" | cut -f2 | sort > "$OUT_DIR/actual-cells.txt"
cmp "$OUT_DIR/expected-cells.txt" "$OUT_DIR/actual-cells.txt" >/dev/null \
	|| die 'missing, duplicate, or unexpected measurement cell'

grep -F 'E4_SUMMARY ' "$KTAP" | sed 's/^.*E4_SUMMARY /E4_SUMMARY /' \
	> "$OUT_DIR/e4-summary-rows.txt"
[ "$(wc -l < "$OUT_DIR/e4-summary-rows.txt" | tr -d ' ')" = 3 ] \
	|| die 'E4 summary row count mismatch'
awk '
BEGIN {OFS="\t"; print "family","rows","rejected_cells","harness_errors"}
{
  delete value;
  for (i=2;i<=NF;i++) {split($i,p,"="); value[p[1]]=p[2]}
  if (value["family"] !~ /^(one_projection|hotplug|fanout)$/ || value["rows"] !~ /^[0-9]+$/ || value["rejected_cells"] !~ /^[0-9]+$/ || value["harness_errors"] != 0) exit 2;
  print value["family"],value["rows"],value["rejected_cells"],value["harness_errors"];
}
' "$OUT_DIR/e4-summary-rows.txt" | sort > "$OUT_DIR/e4-summaries.tsv" \
	|| die 'malformed E4 summary'
{
	printf 'family\trows\trejected_cells\tharness_errors\n'
	for family in fanout hotplug one_projection; do
		awk -F '\t' -v family="$family" 'NR>1 && $1==family {rows++; if ($27=="reject") rejected++} END {print family "\t" rows+0 "\t" rejected+0 "\t0"}' "$TABLE"
	done
} | sort > "$OUT_DIR/derived-summaries.tsv"
cmp "$OUT_DIR/e4-summaries.tsv" "$OUT_DIR/derived-summaries.tsv" >/dev/null \
	|| die 'E4 summaries disagree with recomputed rows'

printf 'family\tkey\treason\tobserved_ns\tlimit_ns\n' > "$FAILURES"
awk -F '\t' 'BEGIN{OFS="\t"} NR>1 {
  if ($1=="one_projection") {
    if (($23+0)>5000) print $1,$2,"additional_p99",$23,5000;
    if (($24+0)>25000) print $1,$2,"additional_p999",$24,25000;
    if (($25+0)>50000) print $1,$2,"additional_max",$25,50000;
    if (($25+0)>=700000) print $1,$2,"additional_reached_base_slice",$25,699999;
  } else if ($1=="hotplug") {
    if (($23+0)>25000) print $1,$2,"additional_p99",$23,25000;
    if (($25+0)>50000) print $1,$2,"additional_max",$25,50000;
    if (($25+0)>=700000) print $1,$2,"additional_reached_base_slice",$25,699999;
  } else if ($1=="fanout") {
    if (($17+0)>10000000) print $1,$2,"treatment_p99",$17,10000000;
    if (($19+0)>100000000) print $1,$2,"treatment_max",$19,100000000;
  }
}' "$TABLE" >> "$FAILURES"
threshold_breaches=$(($(wc -l < "$FAILURES") - 1))
rejected_cells=$(awk -F '\t' 'NR>1 && $27=="reject" {n++} END{print n+0}' "$TABLE")

lockdep_warnings=$(grep -Eic 'possible circular locking dependency|inconsistent lock state|bad unlock balance|held lock freed|WARNING:.*(lockdep|locking)' "$SERIAL" || true)
irqsoff_warnings=$(grep -Eic 'irqsoff.*(WARNING|BUG|latency exceeded)|(WARNING|BUG).*irqsoff' "$SERIAL" || true)
rcu_warnings=$(grep -Eic 'rcu: INFO: rcu_.*detected stalls|RCU Stall|rcu.*stall.*detected' "$SERIAL" || true)
workqueue_warnings=$(grep -Eic 'workqueue lockup|ODEBUG:.*work|workqueue.*(WARNING|BUG)' "$SERIAL" || true)
kasan_warnings=$(grep -Eic 'KASAN:' "$SERIAL" || true)
kcsan_warnings=$(grep -Eic 'BUG: KCSAN:' "$SERIAL" || true)
warning_reports=$(grep -Eic 'WARNING:' "$SERIAL" || true)
bug_reports=$(grep -Eic 'BUG:' "$SERIAL" || true)
softlockup_warnings=$(grep -Eic 'watchdog: BUG: soft lockup|soft lockup - CPU' "$SERIAL" || true)
hardlockup_warnings=$(grep -Eic 'NMI watchdog: Watchdog detected hard LOCKUP|hard LOCKUP' "$SERIAL" || true)
warning_count=$((lockdep_warnings + irqsoff_warnings + rcu_warnings + workqueue_warnings + kasan_warnings + kcsan_warnings + warning_reports + bug_reports + softlockup_warnings + hardlockup_warnings))
printf 'class\tcount\nlockdep\t%s\nirqsoff\t%s\nrcu_stall\t%s\nworkqueue\t%s\nkasan\t%s\nkcsan\t%s\nwarning\t%s\nbug\t%s\nsoft_lockup\t%s\nhard_lockup\t%s\n' \
	"$lockdep_warnings" "$irqsoff_warnings" "$rcu_warnings" \
	"$workqueue_warnings" "$kasan_warnings" "$kcsan_warnings" \
	"$warning_reports" "$bug_reports" "$softlockup_warnings" \
	"$hardlockup_warnings" > "$OUT_DIR/warnings.tsv"

if [ "$rejected_cells" -gt 0 ] || [ "$warning_count" -gt 0 ]; then
	classification=rejected_r3_bucket_measurement
	x86_may_start=false
else
	classification=passed_r3_e4_architecture_measurement
	x86_may_start=true
fi

tail -n +2 "$TABLE" | jq -Rn '[inputs | split("\t") | {
  family:.[0],key:.[1],occupancy:.[2],inner:.[3],generation:.[4],active_rqs:.[5],samples:(.[6]|tonumber),
  control:{minimum:(.[7]|tonumber),p50:(.[8]|tonumber),p95:(.[9]|tonumber),p99:(.[10]|tonumber),p999:(.[11]|tonumber),maximum:(.[12]|tonumber)},
  treatment:{minimum:(.[13]|tonumber),p50:(.[14]|tonumber),p95:(.[15]|tonumber),p99:(.[16]|tonumber),p999:(.[17]|tonumber),maximum:(.[18]|tonumber)},
  additional:{minimum:(.[19]|tonumber),p50:(.[20]|tonumber),p95:(.[21]|tonumber),p99:(.[22]|tonumber),p999:(.[23]|tonumber),maximum:(.[24]|tonumber)},gate:.[25]
}]' > "$OUT_DIR/measurement-rows.json"
tail -n +2 "$FAILURES" | jq -Rn '[inputs | split("\t") | {family:.[0],key:.[1],reason:.[2],observed_ns:(.[3]|tonumber),limit_ns:(.[4]|tonumber)}]' \
	> "$OUT_DIR/threshold-failures.json"

config_sha=$(sha256sum "$OUT_DIR/arm64.config" | awk '{print $1}')
serial_sha=$(sha256sum "$SERIAL" | awk '{print $1}')
ktap_sha=$(sha256sum "$KTAP" | awk '{print $1}')
table_sha=$(sha256sum "$TABLE" | awk '{print $1}')
host_env_sha=$(sha256sum "$OUT_DIR/host-environment.txt" | awk '{print $1}')
warning_config_sha=$(sha256sum "$OUT_DIR/warning-config.txt" | awk '{print $1}')
frequency_governor_source_sha=$(sha256sum "$OUT_DIR/container-frequency-governor.txt" | awk '{print $1}')
frequency_governor_availability_sha=$(sha256sum "$OUT_DIR/frequency-governor-availability.txt" | awk '{print $1}')
compiler=$(sed -n '1p' "$OUT_DIR/compiler.txt")
qemu_version=$(sed -n '1p' "$OUT_DIR/qemu-version.txt")
container_uname=$(sed -n '1p' "$OUT_DIR/container-uname.txt")
clocksource_detail=$(grep -Ei 'clocksource|arch_sys_counter' "$SERIAL" | tail -n 1 || true)
postprocess_recovery_json=false
if [ "$POSTPROCESS_RECOVERY" = 1 ]; then
	postprocess_recovery_json=true
	printf '%s\n' \
		'build_reused=true' \
		'qemu_evidence_reused=true' \
		'raw_inputs_modified=false' \
		'reason=post-QEMU parser defect fixed after complete clean measurement' \
		> "$OUT_DIR/postprocess-recovery.txt"
fi

jq -n \
	--arg run_id "$RUN_ID" --arg status "$classification" \
	--arg compiler "$compiler" --arg qemu_version "$qemu_version" \
	--arg container_uname "$container_uname" --arg clocksource_detail "$clocksource_detail" \
	--arg config_sha "$config_sha" --arg image_sha "$image_sha" \
	--arg image_archive_sha "$image_archive_sha" --arg object_sha "$object_sha" \
	--arg object_archive_sha "$object_archive_sha" --arg serial_sha "$serial_sha" \
	--arg ktap_sha "$ktap_sha" --arg table_sha "$table_sha" \
	--arg host_env_sha "$host_env_sha" --arg warning_config_sha "$warning_config_sha" \
	--arg frequency_governor_source_sha "$frequency_governor_source_sha" \
	--arg frequency_governor_availability_sha "$frequency_governor_availability_sha" \
	--argjson qemu_rc "$qemu_rc" --argjson threshold_breaches "$threshold_breaches" \
	--argjson rejected_cells "$rejected_cells" --argjson warning_count "$warning_count" \
	--argjson x86_may_start "$x86_may_start" \
	--argjson postprocess_only "$postprocess_only_json" \
	--argjson postprocess_recovery "$postprocess_recovery_json" \
	--argjson frequency_governor_available "$frequency_governor_available" \
	--argjson frequency_governor_source_empty "$frequency_governor_source_empty" \
	--argjson lockdep "$lockdep_warnings" --argjson irqsoff "$irqsoff_warnings" \
	--argjson rcu "$rcu_warnings" --argjson workqueue "$workqueue_warnings" \
	--argjson kasan "$kasan_warnings" --argjson kcsan "$kcsan_warnings" \
	--argjson warning "$warning_reports" --argjson bug "$bug_reports" \
	--argjson softlockup "$softlockup_warnings" --argjson hardlockup "$hardlockup_warnings" \
	--slurpfile rows "$OUT_DIR/measurement-rows.json" \
	--slurpfile failures "$OUT_DIR/threshold-failures.json" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r3-e4-arm64-bucket-measurement-result-v1",
  run_id:$run_id,
  status:$status,
  architecture:"arm64",
  source_commit:"f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1",
  source_tree:"61541cb0c8aedef941e534c73effdea1f6b3d938",
  source_parent:"be9339363a99fb31a5b7d03f3d70430d64a45593",
  source_gate_sha256:"8529ceac4f5018be0878507e6fce7c7d8a9dda1f9f586e551f09c64bd14b2e7c",
  exact_source_e3_regression_sha256:"3d02a2b6c52a856e6bde5417665bfc41e1fa547c774f9274f1f85d53167b5707",
  evidence_processing:{postprocess_only:$postprocess_only,postprocess_recovery:$postprocess_recovery,build_reused:$postprocess_recovery,qemu_evidence_reused:$postprocess_recovery,raw_inputs_modified:false},
  matrix:{one_projection_cells:32,hotplug_cells:5,fanout_cells:5,total_cells:42,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000,result_rows:($rows[0]|length)},
  gates_ns:{one_projection:{additional_p99:5000,additional_p999:25000,additional_max:50000},hotplug:{additional_p99:25000,additional_max:50000},fanout:{absolute_treatment_p99:10000000,absolute_treatment_max:100000000},normalized_base_slice:700000},
  measurement_rows:$rows[0],threshold_failures:$failures[0],threshold_breach_count:$threshold_breaches,rejected_cell_count:$rejected_cells,
  warnings:{evidence_available:true,configuration_sha256:$warning_config_sha,lockdep:$lockdep,irqsoff:$irqsoff,rcu_stall:$rcu,workqueue:$workqueue,kasan:$kasan,kcsan:$kcsan,warning:$warning,bug:$bug,soft_lockup:$softlockup,hard_lockup:$hardlockup,total:$warning_count},
  environment:{outer_host_record_sha256:$host_env_sha,outer_virtualization:"Apple Container machine domainlease-dev",container_uname:$container_uname,compiler:$compiler,qemu_version:$qemu_version,qemu_accelerator:"tcg,thread=multi",qemu_machine:"virt,gic-version=3",qemu_cpu:"cortex-a57",qemu_vcpus:64,qemu_memory_mib:4096,qemu_network_disabled:true,sample_clock:"local_clock",clocksource_detail:$clocksource_detail,frequency_governor_availability_recorded:true,frequency_governor_available:$frequency_governor_available,frequency_governor_source_record_empty:$frequency_governor_source_empty,frequency_governor_source_sha256:$frequency_governor_source_sha,frequency_governor_availability_sha256:$frequency_governor_availability_sha,mitigation_config_recorded:true,virtualized_result_supports_bare_metal_claim:false},
  artifacts:{config_sha256:$config_sha,image:{archive:"boot-artifacts/arm64/Image.zst",source_sha256:$image_sha,archive_sha256:$image_archive_sha,restore_verified:true},exec_lease_object:{archive:"boot-artifacts/arm64/exec_lease.o.zst",source_sha256:$object_sha,archive_sha256:$object_archive_sha,restore_verified:true},serial_sha256:$serial_sha,normalized_ktap_sha256:$ktap_sha,measurement_table_sha256:$table_sha,build_output_pruned:true},
  qemu_exit_code:$qemu_rc,
  kunit:{suite:"sched_exec_lease_bucket_measure",suite_passed:true,case_count:3,failed_cases:0,skipped_required_cases:0},
  architecture_measurement_valid:true,
  threshold_failure_is_valid_negative_evidence:true,
  x86_64_measurement_may_start:$x86_may_start,
  e4_measurement_accepted:false,
  e5_plan_may_start:false,
  e5_source_may_start:false,
  real_scheduler_attachment:false,
  primary_linux_change_approved:false,
  patch_queue_change_approved:false,
  runtime_behavior_approved:false,
  production_protection:false,
  bare_metal_latency_claim:false,
  performance_claim:false,
  cost_claim:false,
  deployment_ready:false,
  datacenter_ready:false
}
' > "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
if [ "$classification" = rejected_r3_bucket_measurement ]; then
	progress "100% complete valid negative evidence; arm64 rejected ($rejected_cells cells, $threshold_breaches breaches, $warning_count warnings)"
else
	progress '100% arm64 architecture passed; same-source x86_64 measurement may start'
fi
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
