#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export KBUILD_BUILD_TIMESTAMP='1970-01-01 00:00:00 +0000'
export KBUILD_BUILD_USER=capsched
export KBUILD_BUILD_HOST=r6-e3-diagnostic
export KBUILD_BUILD_VERSION=1

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
WARNING_CLASSIFIER_SOURCE="$SCRIPT_DIR/lib/kernel-warning-classifier.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
SOURCE_GATE_RESULT=${SOURCE_GATE_RESULT:-}
SOURCE_GATE_SHA256=${SOURCE_GATE_SHA256:-}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix"
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r6-e3-four-profile/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-$(nproc)}
BUILD_STORAGE_MIN_KIB=${BUILD_STORAGE_MIN_KIB:-8388608}
QEMU_TIMEOUT_STANDARD=${QEMU_TIMEOUT_STANDARD:-1800}
QEMU_TIMEOUT_SANITIZER=${QEMU_TIMEOUT_SANITIZER:-3600}

E2_COMMIT=66e2fd20fc85012d7dc03649fcf4c7af583cbb94
E3_COMMIT=99287291f1c8e0d6c1b3ea86d121508c5547f424
E3_TREE=2b863b57dfe3f03609ad1a73c965874f71056e8f
E3_DIFF_SHA=2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
SUITE=sched_exec_lease_r6_correctness
REQUIRED_CASES=55
REQUIRED_RECEIPTS=55
clock_skew_retries=0
warning_classifier_selftest_passed=0
current_build=
active_child_pid=

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

retire_build()
{
	local build=$1

	case "$build" in
	"$BUILD_ROOT"/*) ;;
	*) die "refusing to retire build outside run root: $build" ;;
	esac
	rm -rf -- "$build"
	if [ "$current_build" = "$build" ]; then
		current_build=
	fi
}

cleanup()
{
	local rc=$?

	trap - EXIT INT TERM
	if [ -n "$active_child_pid" ] &&
		kill -0 "$active_child_pid" 2>/dev/null; then
		kill -TERM "$active_child_pid" 2>/dev/null || true
		wait "$active_child_pid" 2>/dev/null || true
	fi
	if [ -n "$current_build" ]; then
		case "$current_build" in
		"$BUILD_ROOT"/*) rm -rf -- "$current_build" ;;
		esac
	fi
	rm -rf -- "$BUILD_ROOT"
	exit "$rc"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$JOBS" in
	''|*[!0-9]*) die 'JOBS must be a positive integer' ;;
esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be greater than zero'
case "$BUILD_STORAGE_MIN_KIB" in
	''|*[!0-9]*) die 'BUILD_STORAGE_MIN_KIB must be a positive integer' ;;
esac
[ "$BUILD_STORAGE_MIN_KIB" -gt 0 ] ||
	die 'BUILD_STORAGE_MIN_KIB must be greater than zero'
[ -n "$SOURCE_GATE_RESULT" ] ||
	die 'SOURCE_GATE_RESULT is required'
[ -n "$SOURCE_GATE_SHA256" ] ||
	die 'SOURCE_GATE_SHA256 is required'
case "$SOURCE_GATE_SHA256" in
	????????????????????????????????????????????????????????????????) ;;
	*) die 'SOURCE_GATE_SHA256 must be a 64-character digest' ;;
esac

for command in awk cp df diff find gcc git grep jq make mkfifo mkdir mv \
	qemu-system-aarch64 qemu-system-x86_64 readelf sed sha256sum sort \
	stat strings timeout tr uname wc x86_64-linux-gnu-gcc; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
for path in "$OUT_DIR" "$BUILD_ROOT"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run path already exists: $path"
	fi
done
if [ ! -f "$SOURCE_GATE_RESULT" ] ||
	[ -L "$SOURCE_GATE_RESULT" ]; then
	die 'source-gate result is not a regular non-symlink file'
fi
[ "$(sha256sum "$SOURCE_GATE_RESULT" | awk '{print $1}')" = \
	"$SOURCE_GATE_SHA256" ] || die 'source-gate result digest mismatch'

mkdir -p "$OUT_ROOT" "$(dirname "$BUILD_ROOT")"
mkdir "$OUT_DIR" "$INPUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
trap cleanup EXIT INT TERM

build_storage_type=$(stat -f -c %T "$BUILD_ROOT")
[ "$build_storage_type" = ext2/ext3 ] ||
	die "build root is not internal ext storage: $build_storage_type"
build_storage_available_kib=$(df -Pk "$BUILD_ROOT" |
	awk 'NR == 2 {print $4}')
[ "$build_storage_available_kib" -ge "$BUILD_STORAGE_MIN_KIB" ] ||
	die "internal storage below ${BUILD_STORAGE_MIN_KIB}KiB"

for helper in "$HARDENING_LIB_SOURCE:$HARDENING_LIB_SHA" \
	"$WARNING_CLASSIFIER_SOURCE:$WARNING_CLASSIFIER_SHA"; do
	file=${helper%%:*}
	digest=${helper#*:}
	if [ ! -f "$file" ] || [ -L "$file" ]; then
		die "helper is not a regular file: $file"
	fi
	[ "$(sha256sum "$file" | awk '{print $1}')" = "$digest" ] ||
		die "helper changed: $file"
done
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"
capsched_verify_file_sha256 "$INPUT_DIR/immutable-evidence-inputs.sh" \
	"$HARDENING_LIB_SHA" || die 'hardening helper snapshot mismatch'
capsched_snapshot_verified_file "$WARNING_CLASSIFIER_SOURCE" \
	"$WARNING_CLASSIFIER_SHA" "$INPUT_DIR/kernel-warning-classifier.sh" ||
	die 'could not snapshot warning classifier'
# shellcheck disable=SC1091
source "$INPUT_DIR/kernel-warning-classifier.sh"
runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" \
	"$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$PLAN_SOURCE" "$PLAN_SHA" \
	"$INPUT_DIR/plan.json" || die 'could not snapshot plan'
capsched_snapshot_verified_file "$SOURCE_GATE_RESULT" \
	"$SOURCE_GATE_SHA256" "$INPUT_DIR/source-gate-result.json" ||
	die 'could not snapshot source-gate result'
PLAN="$INPUT_DIR/plan.json"
SOURCE_GATE="$INPUT_DIR/source-gate-result.json"

progress '2% locking exact source gate, plan, and candidate identities'
jq -e --arg sha "$E3_COMMIT" '
  .status == "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
  .candidate_commit == $sha and
  .deterministic_case_families == 55 and
  .allocation_fault_sites == 3 and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .w1_compiler_diagnostics == 0 and
  .diagnostic_matrix_may_start == true and
  .r6_e3_source_accepted == false and
  .production_protection == false
' "$SOURCE_GATE" >/dev/null || die 'source-gate semantics changed'
jq -e '
  .status == "r6_e3_source_free_pre_source_plan" and
  .configuration.suite == "sched_exec_lease_r6_correctness" and
  (.required_case_families | length) == 55 and
  .race_control.hard_case_timeout_seconds == 15 and
  .race_control.stress_repetitions_per_diagnostic_profile == 4096 and
  .build_and_boot_matrix.diagnostic_boots == [
    "arm64_standard_debug_lockdep_hotplug_faults",
    "x86_64_standard_debug_lockdep_hotplug_faults",
    "arm64_generic_kasan_lockdep",
    "x86_64_kcsan_lockdep"
  ]
' "$PLAN" >/dev/null || die 'diagnostic plan changed'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] ||
	die 'candidate worktree moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$E2_COMMIT" ] ||
	die 'candidate parent moved'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] ||
	die 'candidate tree moved'
[ "$(git -C "$E3_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	"$E3_COMMIT" ] || die 'fork candidate moved'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'candidate worktree is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'patch queue moved'
git -C "$E3_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" \
	> "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = \
	"$E3_DIFF_SHA" ] || die 'candidate diff changed'

jq -r '.required_case_families[]' "$PLAN" > "$OUT_DIR/expected-cases.txt"
jq -R -s 'split("\n") | map(select(length > 0)) | sort' \
	"$OUT_DIR/expected-cases.txt" > "$OUT_DIR/expected-receipt-cases.json"
gcc --version > "$OUT_DIR/arm64-compiler.txt"
x86_64-linux-gnu-gcc --version > "$OUT_DIR/x86_64-compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-aarch64-version.txt"
qemu-system-x86_64 --version > "$OUT_DIR/qemu-x86_64-version.txt"
uname -a > "$OUT_DIR/build-host.txt"

warning_classifier_selftest()
{
	local root="$OUT_DIR/kernel-warning-classifier-selftest"
	local benign="$root/benign.log" race="$root/race.log"
	local benign_report="$root/benign.report" race_report="$root/race.report"

	mkdir "$root"
	printf '%s\n' 'kcsan: enabled early' \
		'kcsan: strict mode configured' \
		'kcsan: selftest: 3/3 tests passed' > "$benign"
	capsched_collect_kernel_warning_reports "$benign" "$benign_report" ||
		die 'warning classifier benign fixture failed'
	[ ! -s "$benign_report" ] ||
		die 'warning classifier rejected benign KCSAN lifecycle'
	printf '%s\n' \
		'BUG: KCSAN: data-race in test_read / test_write' \
		'Reported by Kernel Concurrency Sanitizer on:' > "$race"
	capsched_collect_kernel_warning_reports "$race" "$race_report" ||
		die 'warning classifier race fixture failed'
	[ "$(wc -l < "$race_report" | tr -d ' ')" = 2 ] ||
		die 'warning classifier missed KCSAN report'
	rm -rf -- "$root"
	warning_classifier_selftest_passed=1
}

has_compiler_diagnostic()
{
	grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$1"
}

has_clock_skew()
{
	grep -Eiq 'Clock skew detected|modification time .* in the future' "$1"
}

configure_boot()
{
	local arch=$1 cross=$2 profile=$3 out=$4 label=$5 required

	mkdir "$out"
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		defconfig > "$OUT_DIR/$label-defconfig.log" 2>&1
	"$E3_DIR/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e SYSFS -e DEBUG_FS \
		-e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-d SCHED_AUTOGROUP -e SCHED_EXEC_LEASE -e DEBUG_KERNEL \
		-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_R6_LAYOUT_PROBE -e KUNIT \
		-d KUNIT_ALL_TESTS -e KUNIT_AUTORUN_ENABLED \
		-e SCHED_EXEC_LEASE_R6_KUNIT_TEST \
		--set-str KUNIT_DEFAULT_FILTER_GLOB "$SUITE" \
		--set-val KUNIT_DEFAULT_TIMEOUT 15 \
		-e HOTPLUG_CPU -e PROVE_LOCKING -e DEBUG_OBJECTS \
		-e DEBUG_OBJECTS_WORK -e DEBUG_OBJECTS_RCU_HEAD -e PROVE_RCU \
		-e DEBUG_IRQFLAGS -e WQ_WATCHDOG -e DEBUG_INFO_NONE -d MODULES
	case "$profile" in
	standard)
		"$E3_DIR/scripts/config" --file "$out/.config" \
			-e FAULT_INJECTION -e FAULT_INJECTION_DEBUG_FS \
			-e FAILSLAB -e FAIL_PAGE_ALLOC -d KASAN -d KCSAN
		;;
	kasan)
		"$E3_DIR/scripts/config" --file "$out/.config" \
			-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
			-e KASAN -e KASAN_GENERIC -e KASAN_INLINE -d KCSAN
		;;
	kcsan)
		"$E3_DIR/scripts/config" --file "$out/.config" \
			-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
			-d KASAN -e KCSAN -e KCSAN_STRICT
		;;
	*) die "unknown diagnostic profile: $profile" ;;
	esac
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		olddefconfig > "$OUT_DIR/$label-olddefconfig.log" 2>&1
	for required in \
		CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y \
		CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST=y \
		CONFIG_KUNIT=y CONFIG_KUNIT_AUTORUN_ENABLED=y \
		CONFIG_HOTPLUG_CPU=y CONFIG_PROVE_LOCKING=y \
		CONFIG_DEBUG_OBJECTS_WORK=y CONFIG_DEBUG_OBJECTS_RCU_HEAD=y \
		CONFIG_PROVE_RCU=y CONFIG_DEBUG_IRQFLAGS=y \
		CONFIG_WQ_WATCHDOG=y; do
		grep -Fxq "$required" "$out/.config" ||
			die "$label missing $required"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$out/.config" ||
		die "$label KUNIT_ALL_TESTS enabled"
	grep -Fxq '# CONFIG_MODULES is not set' "$out/.config" ||
		die "$label modules enabled"
	grep -Fxq "CONFIG_KUNIT_DEFAULT_FILTER_GLOB=\"$SUITE\"" \
		"$out/.config" || die "$label suite filter changed"
	case "$profile" in
	standard)
		for required in CONFIG_FAULT_INJECTION=y \
			CONFIG_FAULT_INJECTION_DEBUG_FS=y CONFIG_FAILSLAB=y \
			CONFIG_FAIL_PAGE_ALLOC=y; do
			grep -Fxq "$required" "$out/.config" ||
				die "$label missing $required"
		done
		;;
	kasan)
		grep -Fxq 'CONFIG_KASAN=y' "$out/.config" ||
			die "$label KASAN missing"
		grep -Fxq 'CONFIG_KASAN_GENERIC=y' "$out/.config" ||
			die "$label generic KASAN missing"
		;;
	kcsan)
		grep -Fxq 'CONFIG_KCSAN=y' "$out/.config" ||
			die "$label KCSAN missing"
		grep -Fxq 'CONFIG_KCSAN_STRICT=y' "$out/.config" ||
			die "$label strict KCSAN missing"
		;;
	esac
	cp "$out/.config" "$OUT_DIR/$label.config"
}

build_image()
{
	local arch=$1 cross=$2 target=$3 out=$4 label=$5 base=$6 span=$7
	local log="$OUT_DIR/$label-build.log" fifo="$OUT_DIR/$label-build.fifo"
	local steps=0 percent make_pid make_rc

	mkfifo "$fifo"
	set +e
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		-j"$JOBS" "$target" > "$fifo" 2>&1 &
	make_pid=$!
	active_child_pid=$make_pid
	set -e
	: > "$log"
	while IFS= read -r line; do
		printf '%s\n' "$line" >> "$log"
		case "$line" in
		*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*)
			steps=$((steps + 1))
			if [ $((steps % 100)) -eq 0 ]; then
				percent=$((base + steps / 300))
				[ "$percent" -lt $((base + span)) ] ||
					percent=$((base + span - 1))
				progress "$percent% building $label ($steps steps)"
			fi
			;;
		esac
	done < "$fifo"
	set +e
	wait "$make_pid"
	make_rc=$?
	set -e
	active_child_pid=
	rm -f "$fifo"
	[ "$make_rc" = 0 ] || die "$label image build failed: $make_rc"
	! has_compiler_diagnostic "$log" ||
		die "$label compiler diagnostic"
	if has_clock_skew "$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		make -C "$E3_DIR" O="$out" ARCH="$arch" \
			CROSS_COMPILE="$cross" -j"$JOBS" "$target" \
			> "$OUT_DIR/$label-clock-skew-verification.log" 2>&1
		! has_clock_skew \
			"$OUT_DIR/$label-clock-skew-verification.log" ||
			die "$label persistent clock skew"
	fi
}

normalize_and_validate()
{
	local label=$1 serial=$2
	local ktap="$OUT_DIR/$label-ktap.log"
	local receipts="$OUT_DIR/$label-receipts.jsonl"
	local case_count

	tr -d '\r' < "$serial" |
		sed -E 's/^\[[^]]+\][[:space:]]*//' > "$ktap"
	grep -Fq '# Subtest: sched_exec_lease_r6_correctness' "$ktap" ||
		die "$label suite did not start"
	grep -Eq \
		"^[[:space:]]*ok [0-9]+( -)? $SUITE([[:space:]]|$)" "$ktap" ||
		die "$label suite did not pass"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" ||
		die "$label KUnit failure"
	! grep -Fq '# SKIP' "$ktap" || die "$label required case skipped"
	case_count=$(grep -Ec \
		'^[[:space:]]*ok [0-9]+( -)? [a-z0-9_]+([[:space:]]|$)' \
		"$ktap" || true)
	[ "$case_count" -ge "$REQUIRED_CASES" ] ||
		die "$label KUnit parameter count: $case_count"
	while IFS= read -r case_name; do
		grep -Eq \
			"^[[:space:]]*ok [0-9]+( -)? ${case_name}([[:space:]]|$)" \
			"$ktap" || die "$label missing case: $case_name"
	done < "$OUT_DIR/expected-cases.txt"
	grep -o 'R6_RECEIPT {.*}' "$serial" |
		sed 's/^R6_RECEIPT //' > "$receipts"
	[ "$(wc -l < "$receipts" | tr -d ' ')" = "$REQUIRED_RECEIPTS" ] ||
		die "$label receipt count changed"
	while IFS= read -r receipt; do
		printf '%s\n' "$receipt" | jq -e '
		  (.case | type == "string" and length > 0) and
		  (.scenario | type == "number") and
		  .oracle_leaves == 64 and .cleanup == "drained"
		' >/dev/null || die "$label malformed receipt"
	done < "$receipts"
	jq -s 'map(.case) | sort' "$receipts" \
		> "$OUT_DIR/$label-receipt-cases.json"
	cmp "$OUT_DIR/expected-receipt-cases.json" \
		"$OUT_DIR/$label-receipt-cases.json" ||
		die "$label receipt case set changed"
	capsched_collect_kernel_warning_reports "$serial" \
		"$OUT_DIR/$label-warning-reports.txt" ||
		die "$label warning classifier failed"
	[ ! -s "$OUT_DIR/$label-warning-reports.txt" ] ||
		die "$label diagnostic warning report"
}

run_qemu()
{
	local arch=$1 label=$2 out=$3 timeout_seconds=$4 memory=$5 percent=$6
	local image serial="$OUT_DIR/$label-console.log" pid rc elapsed=0
	local append="kunit.enable=1 kunit.autorun=1 kunit.filter_glob=$SUITE kunit.timeout=15 kunit_shutdown=poweroff panic=1 oops=panic panic_on_warn=1"

	case "$arch" in
	arm64)
		image="$out/arch/arm64/boot/Image"
		set +e
		timeout --signal=TERM "$timeout_seconds" qemu-system-aarch64 \
			-machine virt,gic-version=3 -cpu cortex-a57 \
			-accel tcg,thread=multi -smp 2 -m "$memory" \
			-nic none -nographic -no-reboot -kernel "$image" \
			-append \
			"console=ttyAMA0 earlycon=pl011,0x09000000 $append" \
			> "$serial" 2>&1 &
		pid=$!
		set -e
		;;
	x86_64)
		image="$out/arch/x86/boot/bzImage"
		set +e
		timeout --signal=TERM "$timeout_seconds" qemu-system-x86_64 \
			-machine q35,accel=tcg -cpu qemu64 -smp 2 -m "$memory" \
			-nic none -nographic -no-reboot -kernel "$image" \
			-append "console=ttyS0 earlyprintk=serial $append" \
			> "$serial" 2>&1 &
		pid=$!
		set -e
		;;
	*) die "unknown QEMU architecture: $arch" ;;
	esac
	active_child_pid=$pid
	while kill -0 "$pid" 2>/dev/null; do
		sleep 15
		elapsed=$((elapsed + 15))
		if kill -0 "$pid" 2>/dev/null; then
			progress "$percent% booting $label (${elapsed}s elapsed)"
		fi
	done
	set +e
	wait "$pid"
	rc=$?
	set -e
	active_child_pid=
	[ "$rc" = 0 ] || die "$label QEMU exit: $rc"
	normalize_and_validate "$label" "$serial"
}

seal_boot_result()
{
	local label=$1 arch=$2 profile=$3 out=$4 image

	case "$arch" in
	arm64) image="$out/arch/arm64/boot/Image" ;;
	x86_64) image="$out/arch/x86/boot/bzImage" ;;
	esac
	readelf -h "$out/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-exec-lease-readelf.txt"
	jq -n --arg boot "$label" --arg arch "$arch" --arg profile "$profile" \
		--arg config_sha "$(sha256sum "$out/.config" | awk '{print $1}')" \
		--arg object_sha "$(sha256sum "$out/kernel/sched/exec_lease.o" |
			awk '{print $1}')" \
		--arg image_sha "$(sha256sum "$image" | awk '{print $1}')" \
		--arg console_sha "$(sha256sum "$OUT_DIR/$label-console.log" |
			awk '{print $1}')" \
		--arg ktap_sha "$(sha256sum "$OUT_DIR/$label-ktap.log" |
			awk '{print $1}')" \
		--arg receipts_sha \
			"$(sha256sum "$OUT_DIR/$label-receipts.jsonl" |
				awk '{print $1}')" \
		'{schema_version:1,status:"passed",boot:$boot,
		  architecture:$arch,profile:$profile,cases_passed:55,
		  case_failures:0,case_skips:0,case_timeouts:0,receipts:55,
		  warning_reports:0,config_sha256:$config_sha,
		  exec_lease_object_sha256:$object_sha,
		  kernel_image_sha256:$image_sha,console_sha256:$console_sha,
		  ktap_sha256:$ktap_sha,receipts_sha256:$receipts_sha,
		  fresh_build_output:true,
		  build_output_retired_after_seal:true,
		  virtual_synthetic_protocol_only:true}' \
		> "$OUT_DIR/$label-result.json"
}

run_boot()
{
	local label=$1 arch=$2 cross=$3 profile=$4 target=$5
	local timeout_seconds=$6 memory=$7 base=$8 span=$9 boot_percent=${10}
	local out="$BUILD_ROOT/$label"

	current_build=$out
	progress "$base% configuring $label"
	configure_boot "$arch" "$cross" "$profile" "$out" "$label"
	progress "$base% building $label fresh kernel image"
	build_image "$arch" "$cross" "$target" "$out" "$label" "$base" "$span"
	progress "$boot_percent% booting $label exact KUnit suite"
	run_qemu "$arch" "$label" "$out" "$timeout_seconds" "$memory" \
		"$boot_percent"
	seal_boot_result "$label" "$arch" "$profile" "$out"
	retire_build "$out"
	progress "$boot_percent% sealed $label and retired build output"
}

progress '3% validating fail-closed kernel warning classification'
warning_classifier_selftest

if [ "${CONFIG_SMOKE_ONLY:-0}" = 1 ]; then
	for spec in \
		'arm64-standard:arm64::standard' \
		'x86_64-standard:x86_64:x86_64-linux-gnu-:standard' \
		'arm64-kasan:arm64::kasan' \
		'x86_64-kcsan:x86_64:x86_64-linux-gnu-:kcsan'; do
		IFS=: read -r label arch cross profile <<< "$spec"
		current_build="$BUILD_ROOT/$label"
		progress '25% resolving next diagnostic config'
		configure_boot "$arch" "$cross" "$profile" "$current_build" \
			"$label"
		retire_build "$current_build"
	done
	jq -n --arg run_id "$RUN_ID" --arg candidate "$E3_COMMIT" \
		--arg source_gate_sha "$SOURCE_GATE_SHA256" \
		--argjson classifier "$warning_classifier_selftest_passed" \
		'{schema_version:1,
		  status:"passed_four_profile_config_smoke_without_build_or_boot",
		  run_id:$run_id,candidate_commit:$candidate,
		  source_gate_sha256:$source_gate_sha,
		  warning_classifier_selftest_passed:($classifier == 1),
		  configs:["arm64_standard_debug_lockdep_hotplug_faults",
		    "x86_64_standard_debug_lockdep_hotplug_faults",
		    "arm64_generic_kasan_lockdep","x86_64_kcsan_lockdep"],
		  builds_started:0,boots_started:0,matrix_passed:false,
		  r6_e3_source_accepted:false,production_protection:false}' \
		> "$OUT_DIR/config-smoke-result.json"
	progress '100% all four diagnostic configs resolved; no build started'
	exit 0
fi

run_boot arm64-standard-debug arm64 '' standard Image \
	"$QEMU_TIMEOUT_STANDARD" 2048 5 18 24
run_boot x86_64-standard-debug x86_64 x86_64-linux-gnu- standard bzImage \
	"$QEMU_TIMEOUT_STANDARD" 2048 27 18 46
run_boot arm64-generic-kasan arm64 '' kasan Image \
	"$QEMU_TIMEOUT_SANITIZER" 4096 49 20 70
run_boot x86_64-kcsan x86_64 x86_64-linux-gnu- kcsan bzImage \
	"$QEMU_TIMEOUT_SANITIZER" 4096 73 20 94

progress '97% sealing complete four-profile diagnostic result'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" ||
	die 'runner changed during matrix'
capsched_verify_file_sha256 "$INPUT_DIR/source-gate-result.json" \
	"$SOURCE_GATE_SHA256" || die 'source-gate snapshot changed'
[ -z "$(find "$BUILD_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ] ||
	die 'fresh build output was not retired'
jq -s '.' "$OUT_DIR/arm64-standard-debug-result.json" \
	"$OUT_DIR/x86_64-standard-debug-result.json" \
	"$OUT_DIR/arm64-generic-kasan-result.json" \
	"$OUT_DIR/x86_64-kcsan-result.json" > "$OUT_DIR/profile-results.json"
jq -e '
  length == 4 and all(.status == "passed") and
  all(.cases_passed == 55) and all(.receipts == 55) and
  all(.case_failures == 0) and all(.case_skips == 0) and
  all(.case_timeouts == 0) and all(.warning_reports == 0)
' "$OUT_DIR/profile-results.json" >/dev/null
jq -n --arg run_id "$RUN_ID" --arg candidate "$E3_COMMIT" \
	--arg parent "$E2_COMMIT" --arg tree "$E3_TREE" \
	--arg diff_sha "$E3_DIFF_SHA" \
	--arg source_gate_sha "$SOURCE_GATE_SHA256" \
	--arg plan_sha "$PLAN_SHA" --arg runner_sha "$runner_initial_sha" \
	--arg results_sha "$(sha256sum "$OUT_DIR/profile-results.json" |
		awk '{print $1}')" \
	--slurpfile results "$OUT_DIR/profile-results.json" \
	--argjson skew "$clock_skew_retries" \
	--argjson classifier "$warning_classifier_selftest_passed" \
	'{schema_version:1,
	  id:"sched-exec-lease-p5a-r6-e3-four-profile-diagnostic-matrix-result-v1",
	  run_id:$run_id,
	  status:"passed_four_profile_matrix_awaiting_independent_closure",
	  candidate_commit:$candidate,candidate_parent:$parent,
	  candidate_tree:$tree,candidate_diff_sha256:$diff_sha,
	  source_gate_sha256:$source_gate_sha,plan_sha256:$plan_sha,
	  runner_sha256:$runner_sha,
	  architectures:["arm64","x86_64"],
	  diagnostic_profiles:["arm64_standard_debug_lockdep_hotplug_faults",
	    "x86_64_standard_debug_lockdep_hotplug_faults",
	    "arm64_generic_kasan_lockdep","x86_64_kcsan_lockdep"],
	  passed_cases_per_profile:55,total_passed_cases:220,
	  receipts_per_profile:55,total_receipts:220,
	  case_failures:0,case_skips:0,case_timeouts:0,warning_reports:0,
	  warning_classifier_selftest_passed:($classifier == 1),
	  build_clock_skew_retries:$skew,
	  fresh_build_output_per_profile:true,
	  sequential_build_retirement:true,
	  virtual_synthetic_protocol_only:true,
	  profile_results_sha256:$results_sha,results:$results[0],
	  four_profile_matrix_passed:true,
	  independent_matrix_closure_pending:true,
	  r6_e3_source_accepted:false,r6_e3_correctness_accepted:false,
	  live_scheduler_attachment:false,runtime_behavior_approved:false,
	  production_protection:false,deployment_ready:false,
	  multi_node_ready:false,multi_cluster_ready:false,
	  datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
jq -e '
  .status == "passed_four_profile_matrix_awaiting_independent_closure" and
  .total_passed_cases == 220 and .total_receipts == 220 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
  .warning_reports == 0 and .four_profile_matrix_passed == true and
  .independent_matrix_closure_pending == true and
  .r6_e3_source_accepted == false and .production_protection == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% four-profile diagnostic matrix passed; closure still required'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
