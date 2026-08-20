#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export KBUILD_BUILD_TIMESTAMP='1970-01-01 00:00:00 +0000'
export KBUILD_BUILD_USER=capsched
export KBUILD_BUILD_HOST=r6-e4-e3-regression
export KBUILD_BUILD_VERSION=1

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e4-local-quantum-measurement"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONTRACT_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-v1.json"
PLAN_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
SOURCE_GATE_RESULT_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate/20260729T-p5a-r6-e4-source-gate/result.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
WARNING_CLASSIFIER_SOURCE="$SCRIPT_DIR/lib/kernel-warning-classifier.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-6}
BUILD_STORAGE_MIN_KIB=${BUILD_STORAGE_MIN_KIB:-8388608}
QEMU_TIMEOUT_STANDARD=${QEMU_TIMEOUT_STANDARD:-1800}
QEMU_TIMEOUT_SANITIZER=${QEMU_TIMEOUT_SANITIZER:-3600}
CONFIG_SMOKE_ONLY=${CONFIG_SMOKE_ONLY:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
REGRESSION_TEST_MODE=${REGRESSION_TEST_MODE:-0}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
CONTRACT_OVERRIDE=${CONTRACT_OVERRIDE:-}
TEST_CONTRACT_SHA=${TEST_CONTRACT_SHA:-}

CONTRACT_SHA=ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
SOURCE_GATE_SHA=ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
CANDIDATE_COMMIT=d51ebdc657a1040e423735584775e66399f321f9
CANDIDATE_PARENT=99287291f1c8e0d6c1b3ea86d121508c5547f424
CANDIDATE_TREE=0847c408be82e6c9077c2edd2d00f44ccfbe18fc
CANDIDATE_DIFF_SHA=fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9
CANDIDATE_SOURCE_SHA=688248428ca550bc1c56e8547fa5f601a46f5e031222b89c715be72150a4ab3c
CANDIDATE_BRANCH=codex/p5a-r6-e4-local-quantum-measurement
SUITE=sched_exec_lease_r6_correctness
MEASUREMENT_CONFIG=CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST
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
	if [ "$REGRESSION_TEST_MODE" = 1 ]; then
		rm -rf -- "$OUT_DIR"
	fi
	exit "$rc"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
for value in "$JOBS" "$BUILD_STORAGE_MIN_KIB" "$QEMU_TIMEOUT_STANDARD" \
	"$QEMU_TIMEOUT_SANITIZER"; do
	case "$value" in
	''|*[!0-9]*) die 'resource values must be positive integers' ;;
	esac
	[ "$value" -gt 0 ] || die 'resource values must be greater than zero'
done
[ "$JOBS" = 6 ] || die 'JOBS must remain exactly 6'
[ "$BUILD_STORAGE_MIN_KIB" = 8388608 ] ||
	die 'internal storage floor changed'
[ "$QEMU_TIMEOUT_STANDARD" = 1800 ] ||
	die 'standard timeout changed'
[ "$QEMU_TIMEOUT_SANITIZER" = 3600 ] ||
	die 'sanitizer timeout changed'
for flag in "$CONFIG_SMOKE_ONLY" "$PREFLIGHT_ONLY" \
	"$REGRESSION_TEST_MODE" "$OFFLINE_TEST_MODE"; do
	case "$flag" in
	0|1) ;;
	*) die 'mode flags must be 0 or 1' ;;
	esac
done
case "$REGRESSION_TEST_MODE:$PREFLIGHT_ONLY:$OFFLINE_TEST_MODE:$CONFIG_SMOKE_ONLY" in
	0:0:0:0|0:0:0:1|0:1:0:0|1:1:1:0) ;;
	*) die 'invalid regression execution mode' ;;
esac

if [ "$REGRESSION_TEST_MODE" = 1 ]; then
	[ -n "$CONTRACT_OVERRIDE" ] ||
		die 'test mode requires CONTRACT_OVERRIDE'
	[ -n "$TEST_CONTRACT_SHA" ] ||
		die 'test mode requires TEST_CONTRACT_SHA'
	CONTRACT_INPUT=$CONTRACT_OVERRIDE
	EXPECTED_CONTRACT_SHA=$TEST_CONTRACT_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-test"
else
	[ -z "$CONTRACT_OVERRIDE" ] || die 'CONTRACT_OVERRIDE is test-only'
	[ -z "$TEST_CONTRACT_SHA" ] || die 'TEST_CONTRACT_SHA is test-only'
	CONTRACT_INPUT=$CONTRACT_SOURCE
	EXPECTED_CONTRACT_SHA=$CONTRACT_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-exact-source-e3-regression"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r6-e4-exact-source-e3-regression/$RUN_ID"

for command_name in awk chmod cmp cp df diff find gcc git grep jq make \
	mkfifo mkdir mv nm nproc qemu-system-aarch64 qemu-system-x86_64 \
	readelf sed sha256sum sort stat strings timeout tr uname wc \
	x86_64-linux-gnu-gcc; do
	command -v "$command_name" >/dev/null 2>&1 ||
		die "missing command: $command_name"
done
for path in "$OUT_DIR" "$BUILD_ROOT"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run path already exists: $path"
	fi
done
for path in "$CONTRACT_INPUT" "$PLAN_SOURCE" "$SOURCE_GATE_RESULT_SOURCE" \
	"$HARDENING_LIB_SOURCE" "$WARNING_CLASSIFIER_SOURCE"; do
	if [ ! -f "$path" ] || [ -L "$path" ]; then
		die "missing or unsafe immutable input: $path"
	fi
done
if [ ! -d "$CANDIDATE_DIR" ] || [ -L "$CANDIDATE_DIR" ]; then
	die 'candidate worktree is missing or unsafe'
fi

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
[ "$(nproc)" -ge "$JOBS" ] ||
	die "guest exposes fewer than $JOBS build CPUs"

[ "$(sha256sum "$HARDENING_LIB_SOURCE" | awk '{print $1}')" = \
	"$HARDENING_LIB_SHA" ] || die 'hardening helper changed'
[ "$(sha256sum "$WARNING_CLASSIFIER_SOURCE" | awk '{print $1}')" = \
	"$WARNING_CLASSIFIER_SHA" ] || die 'warning classifier changed'
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"
capsched_snapshot_verified_file "$WARNING_CLASSIFIER_SOURCE" \
	"$WARNING_CLASSIFIER_SHA" "$INPUT_DIR/kernel-warning-classifier.sh" ||
	die 'could not snapshot warning classifier'
# shellcheck disable=SC1091
source "$INPUT_DIR/kernel-warning-classifier.sh"
runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" \
	"$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$CONTRACT_INPUT" \
	"$EXPECTED_CONTRACT_SHA" "$INPUT_DIR/contract.json" ||
	die 'could not snapshot regression contract'
capsched_snapshot_verified_file "$PLAN_SOURCE" "$PLAN_SHA" \
	"$INPUT_DIR/e3-plan.json" || die 'could not snapshot E3 plan'
capsched_snapshot_verified_file "$SOURCE_GATE_RESULT_SOURCE" \
	"$SOURCE_GATE_SHA" "$INPUT_DIR/source-gate-result.json" ||
	die 'could not snapshot R6-E4 source-gate result'
CONTRACT="$INPUT_DIR/contract.json"
PLAN="$INPUT_DIR/e3-plan.json"
SOURCE_GATE="$INPUT_DIR/source-gate-result.json"

progress '2% locking exact R6-E4 source, source gate, and E3 regression contract'
jq -e --arg candidate "$CANDIDATE_COMMIT" \
	--arg parent "$CANDIDATE_PARENT" --arg tree "$CANDIDATE_TREE" \
	--arg diff "$CANDIDATE_DIFF_SHA" --arg source "$CANDIDATE_SOURCE_SHA" '
  .id == "sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-v1" and
  .schema_version == 1 and
  .candidate.commit == $candidate and .candidate.parent == $parent and
  .candidate.tree == $tree and .candidate.diff_sha256 == $diff and
  .candidate.source_sha256 == $source and
  .candidate.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source_gate.result_sha256 ==
    "ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6" and
  .source_gate.status == "passed_r6_e4_source_build_gate" and
  .source_gate.e3_shared_helpers_changed == true and
  .source_gate.e3_four_profile_regression_required == true and
  .regression.suite == "sched_exec_lease_r6_correctness" and
  .regression.measurement_config ==
    "CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST" and
  .regression.measurement_must_be_disabled == true and
  .regression.cases_per_profile == 55 and
  .regression.receipts_per_profile == 55 and
  .regression.profiles == [
    "arm64_standard_debug_lockdep_hotplug_faults",
    "x86_64_standard_debug_lockdep_hotplug_faults",
    "arm64_generic_kasan_lockdep",
    "x86_64_kcsan_lockdep"
  ] and
  .regression.sequential_fresh_builds == true and
  .regression.internal_ext_storage == true and
  .regression.retire_build_after_each_profile == true and
  .regression.reject_failure_skip_timeout_warning == true and
  .regression.independent_read_only_closure_required == true and
  .resource_policy == {
    jobs:6,minimum_internal_storage_kib:8388608,
    standard_timeout_seconds:1800,sanitizer_timeout_seconds:3600,
    progress_refresh_seconds:30
  } and
  ([.claims[]] | all(. == false))
' "$CONTRACT" >/dev/null || die 'exact-source E3 regression contract changed'
jq -e '
  .status == "passed_r6_e4_source_build_gate" and
  .candidate_commit ==
    "d51ebdc657a1040e423735584775e66399f321f9" and
  .candidate_tree == "0847c408be82e6c9077c2edd2d00f44ccfbe18fc" and
  .candidate_diff_sha256 ==
    "fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9" and
  .changed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .fresh_builds == 6 and
  .matrix_cells == 855 and .total_measured_pairs == 8550000 and
  .e3_shared_helpers_changed == true and
  .e3_four_profile_regression_required == true and
  .e3_four_profile_regression_passed == false and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false and
  .runtime_scheduler_attachment == false and
  .production_protection == false and .deployment_ready == false
' "$SOURCE_GATE" >/dev/null || die 'R6-E4 source-gate semantics changed'
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
' "$PLAN" >/dev/null || die 'R6-E3 diagnostic plan changed'

[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$CANDIDATE_COMMIT" ] ||
	die 'candidate worktree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$CANDIDATE_PARENT" ] ||
	die 'candidate parent moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = \
	"$CANDIDATE_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	"refs/remotes/fork/$CANDIDATE_BRANCH")" = "$CANDIDATE_COMMIT" ] ||
	die 'pushed candidate moved'
[ -z "$(git -C "$CANDIDATE_DIR" status \
	--porcelain --untracked-files=no)" ] || die 'candidate worktree is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = \
	"$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
git -C "$CANDIDATE_DIR" diff --check \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT"
git -C "$CANDIDATE_DIR" diff --name-only \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" |
	sort > "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" ||
	die 'candidate escaped exact two-file boundary'
git -C "$CANDIDATE_DIR" diff --binary \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" -- \
	init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/candidate.diff"
[ "$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')" = \
	"$CANDIDATE_DIFF_SHA" ] || die 'candidate diff changed'
git -C "$CANDIDATE_DIR" show \
	"$CANDIDATE_COMMIT:kernel/sched/exec_lease.c" \
	> "$OUT_DIR/exec_lease.c"
[ "$(sha256sum "$OUT_DIR/exec_lease.c" | awk '{print $1}')" = \
	"$CANDIDATE_SOURCE_SHA" ] || die 'candidate source changed'
grep -q '^kunit_test_suite(sched_exec_r6_correctness_test_suite);$' \
	"$OUT_DIR/exec_lease.c" || die 'R6-E3 suite registration missing'
grep -q '^kunit_test_suite(sched_exec_r6_measure_test_suite);$' \
	"$OUT_DIR/exec_lease.c" || die 'R6-E4 suite registration missing'

jq -r '.required_case_families[]' "$PLAN" > "$OUT_DIR/expected-cases.txt"
[ "$(wc -l < "$OUT_DIR/expected-cases.txt" | tr -d ' ')" = 55 ] ||
	die 'expected R6-E3 case count changed'
jq -R -s 'split("\n") | map(select(length > 0)) | sort' \
	"$OUT_DIR/expected-cases.txt" > "$OUT_DIR/expected-receipt-cases.json"
gcc --version > "$OUT_DIR/arm64-compiler.txt"
x86_64-linux-gnu-gcc --version > "$OUT_DIR/x86_64-compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-aarch64-version.txt"
qemu-system-x86_64 --version > "$OUT_DIR/qemu-x86_64-version.txt"
uname -a > "$OUT_DIR/build-host.txt"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	progress '100% exact-source E3 regression preflight passed; no config, build, or boot'
	exit 0
fi

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
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" defconfig \
		> "$OUT_DIR/$label-defconfig.log" 2>&1
	"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e SYSFS -e DEBUG_FS \
		-e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-d SCHED_AUTOGROUP -e SCHED_EXEC_LEASE -e DEBUG_KERNEL \
		-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_R6_LAYOUT_PROBE -e KUNIT \
		-d KUNIT_ALL_TESTS -e KUNIT_AUTORUN_ENABLED \
		-e SCHED_EXEC_LEASE_R6_KUNIT_TEST \
		-d SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST \
		--set-str KUNIT_DEFAULT_FILTER_GLOB "$SUITE" \
		--set-val KUNIT_DEFAULT_TIMEOUT 15 \
		-e HOTPLUG_CPU -e PROVE_LOCKING -e DEBUG_OBJECTS \
		-e DEBUG_OBJECTS_WORK -e DEBUG_OBJECTS_RCU_HEAD -e PROVE_RCU \
		-e DEBUG_IRQFLAGS -e WQ_WATCHDOG -e DEBUG_INFO_NONE -d MODULES
	case "$profile" in
	standard)
		"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
			-e FAULT_INJECTION -e FAULT_INJECTION_DEBUG_FS \
			-e FAILSLAB -e FAIL_PAGE_ALLOC -d KASAN -d KCSAN
		;;
	kasan)
		"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
			-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
			-e KASAN -e KASAN_GENERIC -e KASAN_INLINE -d KCSAN
		;;
	kcsan)
		"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
			-d FAULT_INJECTION -d FAILSLAB -d FAIL_PAGE_ALLOC \
			-d KASAN -e KCSAN -e KCSAN_STRICT
		;;
	*) die "unknown diagnostic profile: $profile" ;;
	esac
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" olddefconfig \
		> "$OUT_DIR/$label-olddefconfig.log" 2>&1
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
	grep -Fxq "# $MEASUREMENT_CONFIG is not set" "$out/.config" ||
		die "$label enabled R6-E4 measurement"
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
	cp -- "$out/.config" "$OUT_DIR/$label.config"
}

build_image()
{
	local arch=$1 cross=$2 target=$3 out=$4 label=$5 base=$6 span=$7
	local log="$OUT_DIR/$label-build.log" fifo="$OUT_DIR/$label-build.fifo"
	local steps=0 percent make_pid make_rc object

	mkfifo "$fifo"
	set +e
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" -j"$JOBS" "$target" > "$fifo" 2>&1 &
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
				progress "$percent% building $label ($steps steps, $JOBS jobs)"
			fi
			;;
		esac
	done < "$fifo"
	set +e
	wait "$make_pid"
	make_rc=$?
	set -e
	active_child_pid=
	rm -f -- "$fifo"
	[ "$make_rc" = 0 ] || die "$label image build failed: $make_rc"
	! has_compiler_diagnostic "$log" ||
		die "$label compiler diagnostic"
	if has_clock_skew "$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
			CROSS_COMPILE="$cross" -j"$JOBS" "$target" \
			> "$OUT_DIR/$label-clock-skew-verification.log" 2>&1
		! has_clock_skew \
			"$OUT_DIR/$label-clock-skew-verification.log" ||
			die "$label persistent clock skew"
	fi
	object="$out/kernel/sched/exec_lease.o"
	[ -s "$object" ] || die "$label missing exec_lease.o"
	nm -a "$object" > "$OUT_DIR/$label-exec-lease-nm.txt"
	strings -a "$object" > "$OUT_DIR/$label-exec-lease-strings.txt"
	for pattern in sched_exec_r6_measure_ sched_exec_lease_r6_measure \
		R6_E4_RAW R6_E4_RESULT R6_E4_SUMMARY; do
		! grep -Fq "$pattern" "$OUT_DIR/$label-exec-lease-nm.txt" ||
			die "$label disabled E4 symbol present: $pattern"
		! grep -Fq "$pattern" "$OUT_DIR/$label-exec-lease-strings.txt" ||
			die "$label disabled E4 string present: $pattern"
	done
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
		  warning_reports:0,measurement_config_enabled:false,
		  disabled_measurement_artifacts:0,config_sha256:$config_sha,
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
	progress "$base% configuring $label with R6-E4 measurement disabled"
	configure_boot "$arch" "$cross" "$profile" "$out" "$label"
	progress "$base% building $label fresh kernel image with $JOBS jobs"
	build_image "$arch" "$cross" "$target" "$out" "$label" "$base" "$span"
	progress "$boot_percent% booting $label exact R6-E3 suite"
	run_qemu "$arch" "$label" "$out" "$timeout_seconds" "$memory" \
		"$boot_percent"
	seal_boot_result "$label" "$arch" "$profile" "$out"
	retire_build "$out"
	progress "$boot_percent% sealed $label and retired build output"
}

progress '3% validating fail-closed kernel warning classification'
warning_classifier_selftest

if [ "$CONFIG_SMOKE_ONLY" = 1 ]; then
	for spec in \
		'arm64-standard:arm64::standard' \
		'x86_64-standard:x86_64:x86_64-linux-gnu-:standard' \
		'arm64-kasan:arm64::kasan' \
		'x86_64-kcsan:x86_64:x86_64-linux-gnu-:kcsan'; do
		IFS=: read -r label arch cross profile <<< "$spec"
		current_build="$BUILD_ROOT/$label"
		progress '25% resolving exact-source E3 regression config'
		configure_boot "$arch" "$cross" "$profile" "$current_build" \
			"$label"
		retire_build "$current_build"
	done
	jq -n --arg run_id "$RUN_ID" --arg candidate "$CANDIDATE_COMMIT" \
		--arg source_gate_sha "$SOURCE_GATE_SHA" \
		--arg contract_sha "$CONTRACT_SHA" \
		--argjson classifier "$warning_classifier_selftest_passed" \
		'{schema_version:1,
		  status:"passed_exact_source_e3_regression_config_smoke",
		  run_id:$run_id,candidate_commit:$candidate,
		  source_gate_sha256:$source_gate_sha,
		  contract_sha256:$contract_sha,
		  measurement_config_enabled:false,
		  warning_classifier_selftest_passed:($classifier == 1),
		  configs:["arm64_standard_debug_lockdep_hotplug_faults",
		    "x86_64_standard_debug_lockdep_hotplug_faults",
		    "arm64_generic_kasan_lockdep","x86_64_kcsan_lockdep"],
		  builds_started:0,boots_started:0,regression_passed:false,
		  independent_closure_passed:false,r6_e4_source_accepted:false,
		  measurement_authorized:false,production_protection:false}' \
		> "$OUT_DIR/config-smoke-result.json"
	progress '100% all four E4-off configs resolved; no build or boot started'
	chmod -R a-w "$OUT_DIR"
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

progress '97% sealing exact-source four-profile E3 regression result'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" ||
	die 'runner changed during regression'
capsched_verify_file_sha256 "$INPUT_DIR/contract.json" \
	"$CONTRACT_SHA" || die 'regression contract snapshot changed'
capsched_verify_file_sha256 "$INPUT_DIR/source-gate-result.json" \
	"$SOURCE_GATE_SHA" || die 'source-gate snapshot changed'
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
  all(.case_timeouts == 0) and all(.warning_reports == 0) and
  all(.measurement_config_enabled == false) and
  all(.disabled_measurement_artifacts == 0)
' "$OUT_DIR/profile-results.json" >/dev/null
jq -n --arg run_id "$RUN_ID" --arg candidate "$CANDIDATE_COMMIT" \
	--arg parent "$CANDIDATE_PARENT" --arg tree "$CANDIDATE_TREE" \
	--arg diff_sha "$CANDIDATE_DIFF_SHA" \
	--arg source_gate_sha "$SOURCE_GATE_SHA" \
	--arg contract_sha "$CONTRACT_SHA" --arg plan_sha "$PLAN_SHA" \
	--arg runner_sha "$runner_initial_sha" \
	--arg results_sha "$(sha256sum "$OUT_DIR/profile-results.json" |
		awk '{print $1}')" \
	--slurpfile results "$OUT_DIR/profile-results.json" \
	--argjson skew "$clock_skew_retries" \
	--argjson classifier "$warning_classifier_selftest_passed" \
	'{schema_version:1,
	  id:"sched-exec-lease-p5a-r6-e4-exact-source-e3-regression-result-v1",
	  run_id:$run_id,
	  status:"passed_exact_source_e3_regression_awaiting_independent_closure",
	  candidate_commit:$candidate,candidate_parent:$parent,
	  candidate_tree:$tree,candidate_diff_sha256:$diff_sha,
	  source_gate_sha256:$source_gate_sha,
	  contract_sha256:$contract_sha,plan_sha256:$plan_sha,
	  runner_sha256:$runner_sha,architectures:["arm64","x86_64"],
	  diagnostic_profiles:["arm64_standard_debug_lockdep_hotplug_faults",
	    "x86_64_standard_debug_lockdep_hotplug_faults",
	    "arm64_generic_kasan_lockdep","x86_64_kcsan_lockdep"],
	  passed_cases_per_profile:55,total_passed_cases:220,
	  receipts_per_profile:55,total_receipts:220,
	  case_failures:0,case_skips:0,case_timeouts:0,warning_reports:0,
	  measurement_config_enabled:false,disabled_measurement_artifacts:0,
	  warning_classifier_selftest_passed:($classifier == 1),
	  build_clock_skew_retries:$skew,
	  fresh_build_output_per_profile:true,
	  sequential_build_retirement:true,
	  virtual_synthetic_protocol_only:true,
	  profile_results_sha256:$results_sha,results:$results[0],
	  e3_regression_passed_for_e4_source:true,
	  independent_matrix_closure_pending:true,
	  independent_closure_passed:false,r6_e4_source_accepted:false,
	  measurement_authorized:false,live_scheduler_attachment:false,
	  runtime_behavior_approved:false,production_protection:false,
	  deployment_ready:false,multi_node_ready:false,
	  multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e '
  .status ==
    "passed_exact_source_e3_regression_awaiting_independent_closure" and
  .total_passed_cases == 220 and .total_receipts == 220 and
  .case_failures == 0 and .case_skips == 0 and .case_timeouts == 0 and
  .warning_reports == 0 and .measurement_config_enabled == false and
  .disabled_measurement_artifacts == 0 and
  .e3_regression_passed_for_e4_source == true and
  .independent_matrix_closure_pending == true and
  .independent_closure_passed == false and
  .r6_e4_source_accepted == false and
  .measurement_authorized == false and
  .production_protection == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% exact-source E3 regression passed; independent closure required'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
