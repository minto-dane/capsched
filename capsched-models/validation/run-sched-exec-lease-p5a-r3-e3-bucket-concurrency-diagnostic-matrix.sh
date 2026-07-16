#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e3-bucket-concurrency-prototype"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-source-gate/20260716T-p5a-r3-e3-source-gate/result.json"
SOURCE_GATE_SHA=a1dc71e32dbacfad8479a167417c8a2e425b1b0ef169cc9f6cf05d95762272a1
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r3-e3-diagnostic-matrix/$RUN_ID"
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
JOBS=${JOBS:-2}
QEMU_TIMEOUT_STANDARD=${QEMU_TIMEOUT_STANDARD:-900}
QEMU_TIMEOUT_SANITIZER=${QEMU_TIMEOUT_SANITIZER:-1800}

E3_COMMIT=60e148fa0476c742b13a743345d1383db04fc843
E3_TREE=326da04e5b11e8036a4074b1d363410b21033ef8
E2_COMMIT=63313b329e1d44901acfce30698613c38615c8d5
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=2a022dce54679ce5ecb86581bf55199dc28c868b

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

for command in awk git grep jq make qemu-system-aarch64 qemu-system-x86_64 sed sha256sum strings timeout tr uname wc; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
command -v x86_64-linux-gnu-gcc >/dev/null 2>&1 || die 'missing x86_64 cross compiler'

rm -rf "$BUILD_ROOT" "$OUT_DIR"
mkdir -p "$BUILD_ROOT" "$OUT_DIR"
progress '2% locking source-gate and repository identities'
[ "$(sha256sum "$SOURCE_GATE" | awk '{print $1}')" = "$SOURCE_GATE_SHA" ] || die 'source-gate result hash changed'
jq -e '
  .status == "passed_source_gate_awaiting_diagnostic_matrix" and
  .candidate_commit == "60e148fa0476c742b13a743345d1383db04fc843" and
  .exact_direct_e2_child == true and
  .exact_two_file_boundary == true and
  .deterministic_case_families == 20 and
  .allocation_fault_sites == 6 and
  .disabled_e3_symbols_relocations_strings == 0 and
  .diagnostic_matrix_may_start == true
' "$SOURCE_GATE" >/dev/null
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] || die 'E3 commit moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$E2_COMMIT" ] || die 'E3 parent moved'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] || die 'E3 tree moved'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 working tree is dirty'
[ "$(git -C "$WORKSPACE_DIR/linux" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ "$(git -C "$WORKSPACE_DIR/linux-patches" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'

gcc --version > "$OUT_DIR/arm64-compiler.txt"
x86_64-linux-gnu-gcc --version > "$OUT_DIR/x86_64-compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-aarch64-version.txt"
qemu-system-x86_64 --version > "$OUT_DIR/qemu-x86_64-version.txt"
uname -a > "$OUT_DIR/build-host.txt"

configure_boot()
{
	local arch=$1 cross=$2 diagnostic=$3 out=$4 label=$5
	mkdir -p "$out"
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig > "$OUT_DIR/$label-defconfig.log" 2>&1
	"$E3_DIR/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS \
		-e KUNIT_AUTORUN_ENABLED -e SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST \
		--set-str KUNIT_DEFAULT_FILTER_GLOB sched_exec_lease_bucket \
		--set-val KUNIT_DEFAULT_TIMEOUT 1800 \
		-e PROVE_LOCKING -e DEBUG_OBJECTS -e DEBUG_OBJECTS_WORK -e PROVE_RCU \
		-e DEBUG_INFO_NONE -d MODULES
	case "$diagnostic" in
		standard) ;;
		kasan)
			"$E3_DIR/scripts/config" --file "$out/.config" -e KASAN -e KASAN_GENERIC -e KASAN_INLINE -d KCSAN
			;;
		kcsan)
			"$E3_DIR/scripts/config" --file "$out/.config" -d KASAN -e KCSAN -e KCSAN_STRICT
			;;
		*) die "unknown diagnostic: $diagnostic" ;;
	esac
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig > "$OUT_DIR/$label-olddefconfig.log" 2>&1
	for required in \
		CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y \
		CONFIG_KUNIT=y \
		CONFIG_PROVE_LOCKING=y \
		CONFIG_DEBUG_OBJECTS_WORK=y \
		CONFIG_PROVE_RCU=y; do
		grep -Fxq "$required" "$out/.config" || die "$label missing $required"
	done
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$out/.config" || die "$label KUNIT_ALL_TESTS enabled"
	grep -Fxq 'CONFIG_KUNIT_DEFAULT_FILTER_GLOB="sched_exec_lease_bucket"' "$out/.config" || die "$label default filter changed"
	case "$diagnostic" in
		kasan)
			grep -Fxq 'CONFIG_KASAN=y' "$out/.config" || die "$label KASAN missing"
			grep -Fxq 'CONFIG_KASAN_GENERIC=y' "$out/.config" || die "$label generic KASAN missing"
			;;
		kcsan)
			grep -Fxq 'CONFIG_KCSAN=y' "$out/.config" || die "$label KCSAN missing"
			;;
	esac
	cp "$out/.config" "$OUT_DIR/$label.config"
}

build_image()
{
	local arch=$1 cross=$2 target=$3 out=$4 label=$5 base=$6 span=$7
	local log="$OUT_DIR/$label-build.log" fifo="$OUT_DIR/$label-build.fifo" steps=0 percent
	rm -f "$fifo"
	mkfifo "$fifo"
	set +e
	make -C "$E3_DIR" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$JOBS" "$target" > "$fifo" 2>&1 &
	make_pid=$!
	set -e
	: > "$log"
	while IFS= read -r line; do
		printf '%s\n' "$line" >> "$log"
		case "$line" in
		*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
			steps=$((steps + 1))
			if [ $((steps % 50)) -eq 0 ]; then
				percent=$((base + steps / 45))
				[ "$percent" -le $((base + span - 1)) ] || percent=$((base + span - 1))
				progress "$percent% building $label ($steps compiler/link steps)"
			fi
			;;
		esac
	done < "$fifo"
	set +e
	wait "$make_pid"
	make_rc=$?
	set -e
	rm -f "$fifo"
	[ "$make_rc" = 0 ] || die "$label image build failed: $make_rc"
}

normalize_and_validate()
{
	local label=$1 serial=$2 ktap=$3
	tr -d '\r' < "$serial" | sed -E 's/^\[[^]]+\][[:space:]]*//' > "$ktap"
	grep -Fq '# Subtest: sched_exec_lease_bucket' "$ktap" || die "$label suite did not start"
	grep -Eq '^ok [0-9]+( -)? sched_exec_lease_bucket([[:space:]]|$)' "$ktap" || die "$label suite did not pass"
	! grep -Eq '^[[:space:]]*not ok [0-9]+' "$ktap" || die "$label KUnit failure"
	! grep -Fq '# SKIP' "$ktap" || die "$label required case skipped"
	case_count=$(grep -Ec '^[[:space:]]*ok [0-9]+( -)? sched_exec_bucket_test_.*([[:space:]]|$)' "$ktap" || true)
	[ "$case_count" = 20 ] || die "$label KUnit case count: $case_count"
	sed -n '/^static struct kunit_case sched_exec_bucket_test_cases\[\]/,/^};/p' "$E3_DIR/kernel/sched/exec_lease.c" |
		sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' > "$OUT_DIR/expected-cases.txt"
	while IFS= read -r case_name; do
		grep -Eq "^[[:space:]]*ok [0-9]+( -)? ${case_name}([[:space:]]|$)" "$ktap" || die "$label missing case: $case_name"
	done < "$OUT_DIR/expected-cases.txt"
	if grep -Eiq 'KASAN:|BUG: KCSAN:|possible circular locking dependency|refcount_t: underflow|ODEBUG:|RCU Stall|WARNING:|BUG:|soft lockup|hard LOCKUP|workqueue lockup' "$serial"; then
		grep -Ein 'KASAN:|BUG: KCSAN:|possible circular locking dependency|refcount_t: underflow|ODEBUG:|RCU Stall|WARNING:|BUG:|soft lockup|hard LOCKUP|workqueue lockup' "$serial" > "$OUT_DIR/$label-warning-reports.txt" || true
		die "$label diagnostic warning report"
	fi
	: > "$OUT_DIR/$label-warning-reports.txt"
}

run_arm64()
{
	local label=$1 diagnostic=$2 out=$3 timeout_seconds=$4 memory=$5
	local image="$out/arch/arm64/boot/Image" serial="$OUT_DIR/$label-serial.log" ktap="$OUT_DIR/$label-ktap.log"
	printf '%s\n' "qemu-system-aarch64 -machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi -smp 2 -m $memory -nic none -nographic -no-reboot -kernel $image -append 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket kunit_shutdown=poweroff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0'" > "$OUT_DIR/$label-qemu-command.txt"
	set +e
	timeout --signal=TERM "$timeout_seconds" qemu-system-aarch64 \
		-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
		-smp 2 -m "$memory" -nic none -nographic -no-reboot -kernel "$image" \
		-append 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket kunit_shutdown=poweroff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0' \
		> "$serial" 2>&1
	qemu_rc=$?
	set -e
	printf '%s\n' "$qemu_rc" > "$OUT_DIR/$label-qemu-exit-code.txt"
	[ "$qemu_rc" = 0 ] || die "$label QEMU exit: $qemu_rc"
	normalize_and_validate "$label" "$serial" "$ktap"
	sha256sum "$out/.config" "$out/kernel/sched/exec_lease.o" "$image" "$serial" "$ktap" > "$OUT_DIR/$label-sha256.txt"
}

run_x86_64()
{
	local label=$1 diagnostic=$2 out=$3 timeout_seconds=$4 memory=$5
	local image="$out/arch/x86/boot/bzImage" serial="$OUT_DIR/$label-serial.log" ktap="$OUT_DIR/$label-ktap.log"
	printf '%s\n' "qemu-system-x86_64 -machine q35,accel=tcg -cpu qemu64 -smp 2 -m $memory -nic none -nographic -no-reboot -kernel $image -append 'console=ttyS0 earlyprintk=serial kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket kunit_shutdown=poweroff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0'" > "$OUT_DIR/$label-qemu-command.txt"
	set +e
	timeout --signal=TERM "$timeout_seconds" qemu-system-x86_64 \
		-machine q35,accel=tcg -cpu qemu64 -smp 2 -m "$memory" \
		-nic none -nographic -no-reboot -kernel "$image" \
		-append 'console=ttyS0 earlyprintk=serial kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_bucket kunit_shutdown=poweroff panic=1 oops=panic rcupdate.rcu_cpu_stall_suppress=0' \
		> "$serial" 2>&1
	qemu_rc=$?
	set -e
	printf '%s\n' "$qemu_rc" > "$OUT_DIR/$label-qemu-exit-code.txt"
	[ "$qemu_rc" = 0 ] || die "$label QEMU exit: $qemu_rc"
	normalize_and_validate "$label" "$serial" "$ktap"
	sha256sum "$out/.config" "$out/kernel/sched/exec_lease.o" "$image" "$serial" "$ktap" > "$OUT_DIR/$label-sha256.txt"
}

ARM_STD="$BUILD_ROOT/arm64-standard-debug"
X86_STD="$BUILD_ROOT/x86_64-standard-debug"
ARM_KASAN="$BUILD_ROOT/arm64-generic-kasan"
X86_KCSAN="$BUILD_ROOT/x86_64-kcsan"

if [ "${CONFIG_SMOKE_ONLY:-0}" = 1 ]; then
	progress '20% config-smoke arm64 standard debug'
	configure_boot arm64 '' standard "$ARM_STD" arm64-standard-debug
	progress '40% config-smoke x86_64 standard debug'
	configure_boot x86_64 x86_64-linux-gnu- standard "$X86_STD" x86_64-standard-debug
	progress '60% config-smoke arm64 generic KASAN'
	configure_boot arm64 '' kasan "$ARM_KASAN" arm64-generic-kasan
	progress '80% config-smoke x86_64 KCSAN'
	configure_boot x86_64 x86_64-linux-gnu- kcsan "$X86_KCSAN" x86_64-kcsan
	progress '100% four diagnostic configs resolved'
	exit 0
fi

progress '4% configuring arm64 standard debug'
configure_boot arm64 '' standard "$ARM_STD" arm64-standard-debug
progress '6% building arm64 standard debug Image'
build_image arm64 '' Image "$ARM_STD" arm64-standard-debug 6 15
progress '21% booting arm64 standard debug KUnit'
run_arm64 arm64-standard-debug standard "$ARM_STD" "$QEMU_TIMEOUT_STANDARD" 2048

progress '25% configuring x86_64 standard debug'
configure_boot x86_64 x86_64-linux-gnu- standard "$X86_STD" x86_64-standard-debug
progress '27% building x86_64 standard debug bzImage'
build_image x86_64 x86_64-linux-gnu- bzImage "$X86_STD" x86_64-standard-debug 27 15
progress '42% booting x86_64 standard debug KUnit'
run_x86_64 x86_64-standard-debug standard "$X86_STD" "$QEMU_TIMEOUT_STANDARD" 2048

progress '46% configuring arm64 generic KASAN'
configure_boot arm64 '' kasan "$ARM_KASAN" arm64-generic-kasan
progress '48% building arm64 generic KASAN Image'
build_image arm64 '' Image "$ARM_KASAN" arm64-generic-kasan 48 18
progress '66% booting arm64 generic KASAN KUnit'
run_arm64 arm64-generic-kasan kasan "$ARM_KASAN" "$QEMU_TIMEOUT_SANITIZER" 4096

progress '72% configuring x86_64 KCSAN'
configure_boot x86_64 x86_64-linux-gnu- kcsan "$X86_KCSAN" x86_64-kcsan
progress '74% building x86_64 KCSAN bzImage'
build_image x86_64 x86_64-linux-gnu- bzImage "$X86_KCSAN" x86_64-kcsan 74 18
progress '92% booting x86_64 KCSAN KUnit'
run_x86_64 x86_64-kcsan kcsan "$X86_KCSAN" "$QEMU_TIMEOUT_SANITIZER" 4096

progress '97% writing complete four-boot matrix result'
jq -n \
	--arg run_id "$RUN_ID" \
	--arg candidate "$E3_COMMIT" \
	--arg tree "$E3_TREE" \
	--arg parent "$E2_COMMIT" \
	--arg primary "$PRIMARY_COMMIT" \
	--arg source_gate_sha "$SOURCE_GATE_SHA" \
'
{
  schema_version: 1,
  id: "sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix-result-v1",
  run_id: $run_id,
  status: "passed_four_boot_diagnostic_matrix",
  candidate_commit: $candidate,
  candidate_tree: $tree,
  candidate_parent: $parent,
  primary_commit: $primary,
  source_gate_sha256: $source_gate_sha,
  architectures: ["arm64", "x86_64"],
  source_modes_per_architecture: ["exact_e2_parent_baseline", "e3_all_off", "e3_layout_on_test_off", "e3_test_on"],
  qemu_boots: ["arm64_standard_debug", "x86_64_standard_debug", "arm64_generic_kasan", "x86_64_kcsan"],
  suite: "sched_exec_lease_bucket",
  required_cases: 20,
  passed_cases_per_boot: 20,
  failed_cases: 0,
  skipped_cases: 0,
  timeouts: 0,
  warning_reports: 0,
  diagnostics: ["KUnit", "PROVE_LOCKING", "DEBUG_OBJECTS_WORK", "PROVE_RCU", "generic KASAN", "KCSAN"],
  fresh_build_output_per_boot: true,
  compiler_config_image_object_qemu_ktap_console_recorded: true,
  primary_linux_changed: false,
  patch_queue_changed: false,
  synthetic_protocol_diagnostic_matrix_passed: true,
  real_scheduler_attachment: false,
  production_ready: false
}
' > "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% four-boot diagnostic matrix passed'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
