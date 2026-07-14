#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e4-lock-hold"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e4-disposable-lock-hold-measurement-v1.json"
SOURCE_GATE_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-source-gate-r2/20260714T-p5a-r2-e4-source-gate-r2/result.json"
SOURCE_GATE_SHA256=956007be42687193c9d3eeb29e5e0be80dcaeba16d22436c71e06a017a870adc
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
BUILD_OUT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/$RUN_ID"
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e4-arm64-lock-hold-measurement/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
HOST_ENV_FILE=${HOST_ENV_FILE:-}
JOBS=${JOBS:-4}
QEMU_TIMEOUT=${QEMU_TIMEOUT:-6000}
IMAGE="$BUILD_OUT/arch/arm64/boot/Image"
SERIAL_LOG="$OUT_DIR/qemu-serial.log"
KTAP_LOG="$OUT_DIR/qemu-ktap.log"
ROWS_RAW="$OUT_DIR/e4-result-rows.txt"
TABLE="$OUT_DIR/e4-measurements.tsv"
FAILURES="$OUT_DIR/threshold-failures.tsv"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress()
{
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

for cmd in awk cmp cp cut find gcc git grep jq lscpu make nm qemu-system-aarch64 sed sha256sum sleep sort tail tee timeout tr uname wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
if [ -z "$HOST_ENV_FILE" ] || [ ! -s "$HOST_ENV_FILE" ]; then
	die 'host environment record is unavailable'
fi

rm -rf "$BUILD_OUT" "$OUT_DIR"
mkdir -p "$BUILD_OUT" "$OUT_DIR"
progress '5% exact E4 identity and passed source-gate evidence'

jq empty "$CONFIG"
[ "$(git -C "$E4_DIR" rev-parse HEAD)" = f6ad4e454778c52bcdaaecf684c148a3a8dae857 ] || die 'E4 source moved'
[ "$(git -C "$E4_DIR" rev-parse 'HEAD^{tree}')" = 265e6357627490e51084979382ef34b2cfcc0cb8 ] || die 'E4 tree moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD^)" = d1d5e78da8484c91eae70f22399c6901da680ea0 ] || die 'E4 parent moved'
[ -z "$(git -C "$E4_DIR" status --porcelain --untracked-files=no)" ] || die 'E4 source dirty'
[ "$(sha256sum "$SOURCE_GATE_RESULT" | awk '{print $1}')" = "$SOURCE_GATE_SHA256" ] || die 'source-gate result hash mismatch'
jq -e '
  .status == "passed_e4_corrected_source_gate" and
  .source_commit == "f6ad4e454778c52bcdaaecf684c148a3a8dae857" and
  .source_tree == "265e6357627490e51084979382ef34b2cfcc0cb8" and
  .source_diff_sha256 == "3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3" and
  .arm64_measurement_may_be_relaunched == true and
  .x86_64_measurement_may_be_launched == false and
  .e4_measurement_accepted == false and
  .full_locked_rebuild_approved == false
' "$SOURCE_GATE_RESULT" >/dev/null
jq -e '
  .authorization_after_source_gate.arm64_measurement_may_be_launched == true and
  .matrix.runnable_entities == [0,1,8,64,256,1024,4096] and
  .matrix.hierarchy_depths == [0,1,4,16,64] and
  .matrix.cell_count == 35 and .matrix.warmup_pairs_per_cell == 256 and
  .matrix.measured_pairs_per_cell == 10000 and
  .gate.base_slice_ns == 700000 and .gate.additional_p99_limit_ns == 25000 and
  .gate.additional_max_limit_ns == 50000 and .gate.warning_count_allowed == 0
' "$CONFIG" >/dev/null

cp "$HOST_ENV_FILE" "$OUT_DIR/host-environment.txt"
uname -a > "$OUT_DIR/container-uname.txt"
lscpu > "$OUT_DIR/container-lscpu.txt"
gcc --version > "$OUT_DIR/compiler.txt"
qemu-system-aarch64 --version > "$OUT_DIR/qemu-version.txt"
if [ -d /sys/devices/system/cpu/cpufreq ]; then
	find /sys/devices/system/cpu/cpufreq -maxdepth 2 -type f \
		\( -name scaling_governor -o -name scaling_cur_freq -o -name cpuinfo_cur_freq \) \
		-print -exec sed -n '1p' {} \; > "$OUT_DIR/container-frequency-governor.txt" 2>/dev/null || true
else
	printf '%s\n' 'unavailable: outer Apple Container machine exposes no cpufreq directory' > "$OUT_DIR/container-frequency-governor.txt"
fi

progress '10% configuring measurement kernel and warning instrumentation'
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 defconfig > "$OUT_DIR/configure.log" 2>&1
"$E4_DIR/scripts/config" --file "$BUILD_OUT/.config" \
	--enable EXPERT \
	--enable DEBUG_KERNEL \
	--enable CGROUPS \
	--enable CGROUP_SCHED \
	--enable FAIR_GROUP_SCHED \
	--enable SCHED_EXEC_LEASE \
	--enable SCHED_EXEC_LEASE_LAYOUT_PROBE \
	--enable SCHED_EXEC_LEASE_LAYOUT_CANDIDATE \
	--enable KUNIT \
	--disable KUNIT_ALL_TESTS \
	--enable KUNIT_AUTORUN_ENABLED \
	--set-str KUNIT_DEFAULT_FILTER_GLOB sched_exec_lease_rebuild_measure \
	--set-val KUNIT_DEFAULT_TIMEOUT 1800 \
	--enable SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST \
	--enable SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST \
	--enable PROVE_LOCKING \
	--enable DEBUG_LOCK_ALLOC \
	--enable SOFTLOCKUP_DETECTOR \
	--enable HARDLOCKUP_DETECTOR \
	--enable FTRACE \
	--enable IRQSOFF_TRACER
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 olddefconfig >> "$OUT_DIR/configure.log" 2>&1

for config_line in \
	'CONFIG_FAIR_GROUP_SCHED=y' \
	'CONFIG_KUNIT=y' \
	'CONFIG_KUNIT_AUTORUN_ENABLED=y' \
	'CONFIG_KUNIT_DEFAULT_FILTER_GLOB="sched_exec_lease_rebuild_measure"' \
	'CONFIG_KUNIT_DEFAULT_TIMEOUT=1800' \
	'CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST=y' \
	'CONFIG_SCHED_EXEC_LEASE_REBUILD_MEASURE_KUNIT_TEST=y' \
	'CONFIG_PROVE_LOCKING=y' \
	'CONFIG_LOCKDEP=y' \
	'CONFIG_DEBUG_LOCK_ALLOC=y' \
	'CONFIG_FTRACE=y' \
	'CONFIG_IRQSOFF_TRACER=y' \
	'CONFIG_RCU_STALL_COMMON=y' \
	'CONFIG_SOFTLOCKUP_DETECTOR=y' \
	'CONFIG_HARDLOCKUP_DETECTOR=y'; do
	grep -Fxq "$config_line" "$BUILD_OUT/.config" || die "measurement config missing: $config_line"
done
grep -E '^CONFIG_(PROVE_LOCKING|LOCKDEP|DEBUG_LOCK_ALLOC|FTRACE|IRQSOFF_TRACER|RCU_STALL_COMMON|SOFTLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR_[A-Z_]+)=' \
	"$BUILD_OUT/.config" > "$OUT_DIR/warning-config.txt"
grep -E '^CONFIG_(MITIGATION|ARM64_PTR_AUTH|ARM64_BTI|RANDOMIZE_BASE|STACKPROTECTOR|HARDENED_USERCOPY|FORTIFY_SOURCE)' \
	"$BUILD_OUT/.config" > "$OUT_DIR/mitigation-config.txt" || true

progress '15% building full arm64 measurement Image (compiler steps will advance this value)'
set +e
make -C "$E4_DIR" O="$BUILD_OUT" ARCH=arm64 -j"$JOBS" Image 2>&1 | tee "$OUT_DIR/build.log" | {
	steps=0
	while IFS= read -r line; do
		printf '%s\n' "$line"
		case "$line" in
		*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
			steps=$((steps + 1))
			if [ $((steps % 25)) -eq 0 ]; then
				percent=$((15 + steps / 65))
				[ "$percent" -le 82 ] || percent=82
				progress "$percent% building full arm64 measurement Image ($steps compiler/link steps observed)"
			fi
			;;
		esac
	done
}
make_rc=${PIPESTATUS[0]}
set -e
[ "$make_rc" = 0 ] || die "full arm64 Image build failed: $make_rc"
[ -s "$IMAGE" ] || die 'arm64 Image missing'
if grep -Eqi '(^|[^[:alpha:]])(warning|error):' "$OUT_DIR/build.log"; then die 'compiler warning or error found'; fi

nm --defined-only "$BUILD_OUT/kernel/sched/fair.o" > "$OUT_DIR/fair-symbols.txt"
for symbol in sched_exec_measure_once sched_exec_measure_cell sched_exec_rebuild_measure_matrix_test sched_exec_rebuild_measure_test_suite; do
	grep -Fq " $symbol" "$OUT_DIR/fair-symbols.txt" || die "measurement symbol missing: $symbol"
done

progress '84% booting QEMU; waiting for 35 measurement rows'
set +e
timeout --signal=TERM "$QEMU_TIMEOUT" qemu-system-aarch64 \
	-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
	-smp 2 -m 2048 -nic none -nographic -no-reboot -kernel "$IMAGE" \
	-append 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_rebuild_measure kunit_shutdown=poweroff ftrace=irqsoff nmi_watchdog=nopanic,1 softlockup_panic=0 rcupdate.rcu_cpu_stall_suppress=0 panic=1' \
	> "$SERIAL_LOG" 2>&1 &
qemu_timeout_pid=$!
set -e

last_rows=-1
while kill -0 "$qemu_timeout_pid" 2>/dev/null; do
	rows=$(grep -c 'E4_RESULT ' "$SERIAL_LOG" 2>/dev/null || true)
	if [ "$rows" != "$last_rows" ]; then
		percent=$((84 + rows * 12 / 35))
		[ "$percent" -le 96 ] || percent=96
		progress "$percent% QEMU measurement rows $rows/35"
		last_rows=$rows
	fi
	sleep 10
done
set +e
wait "$qemu_timeout_pid"
qemu_rc=$?
set -e

progress '96% validating KTAP, all cells, warning evidence, and fixed rejection gates'
tr -d '\r' < "$SERIAL_LOG" | sed -E 's/^\[[^]]+\][[:space:]]*//' > "$KTAP_LOG"
if grep -Fq 'Unknown kernel command line parameters' "$SERIAL_LOG"; then
	die 'guest reported unknown kernel command-line parameters'
fi
grep -Fq "Starting tracer 'irqsoff'" "$SERIAL_LOG" || die 'irqsoff tracer did not start'
grep -Fq '# Subtest: sched_exec_lease_rebuild_measure' "$KTAP_LOG" || die 'measurement KUnit suite did not start'
grep -Eq '^ok [0-9]+( -)? sched_exec_lease_rebuild_measure([[:space:]]|$)' "$KTAP_LOG" || die 'measurement KUnit suite did not pass'
if grep -Eq '^[[:space:]]*not ok [0-9]+' "$KTAP_LOG"; then die 'KUnit reported failure'; fi
if grep -Fq '# SKIP' "$KTAP_LOG"; then die 'KUnit reported a required skip'; fi
kunit_case_count=$(grep -Ec '^[[:space:]]*ok [0-9]+( -)? sched_exec_rebuild_measure_matrix_test([[:space:]]|$)' "$KTAP_LOG" || true)
[ "$kunit_case_count" = 1 ] || die "measurement KUnit case count mismatch: $kunit_case_count"
grep -F 'E4_META ' "$KTAP_LOG" | sed 's/^.*E4_META /E4_META /' > "$OUT_DIR/e4-meta.txt"
[ "$(wc -l < "$OUT_DIR/e4-meta.txt" | tr -d ' ')" = 1 ] || die 'E4 metadata row count mismatch'
grep -Eq '^E4_META cells=35 samples=10000 warmups=256 base_slice_ns=700000 runtime_base_slice_ns=[0-9]+ tunable_scaling=[0-9]+ online_cpus=2 p99_limit_ns=25000 max_limit_ns=50000 clock=local_clock$' "$OUT_DIR/e4-meta.txt" || die 'E4 metadata contract mismatch'
meta_value()
{
	awk -v key="$1" '{
		for (i = 2; i <= NF; i++) {
			split($i, pair, "=");
			if (pair[1] == key) print pair[2];
		}
	}' "$OUT_DIR/e4-meta.txt"
}
runtime_base_slice_ns=$(meta_value runtime_base_slice_ns)
tunable_scaling=$(meta_value tunable_scaling)
online_cpus=$(meta_value online_cpus)
[[ "$runtime_base_slice_ns" =~ ^[0-9]+$ ]] || die 'runtime base slice is not numeric'
[[ "$tunable_scaling" =~ ^[0-9]+$ ]] || die 'tunable scaling is not numeric'
[[ "$online_cpus" =~ ^[0-9]+$ ]] || die 'online CPU count is not numeric'
[ "$runtime_base_slice_ns" -ge 700000 ] || die 'runtime base slice is below its normalized basis'
[ "$online_cpus" = 2 ] || die 'guest online CPU count moved'

grep -F 'E4_RESULT ' "$KTAP_LOG" | sed 's/^.*E4_RESULT /E4_RESULT /' > "$ROWS_RAW"
[ "$(wc -l < "$ROWS_RAW" | tr -d ' ')" = 35 ] || die 'E4 result row count mismatch'
awk '
BEGIN {
  OFS="\t";
  keys="q d n w race_ppm c_min c_p50 c_p95 c_p99 c_p999 c_max r_min r_p50 r_p95 r_p99 r_p999 r_max a_min a_p50 a_p95 a_p99 a_p999 a_max";
  print "q","d","n","w","race_ppm","c_min","c_p50","c_p95","c_p99","c_p999","c_max","r_min","r_p50","r_p95","r_p99","r_p999","r_max","a_min","a_p50","a_p95","a_p99","a_p999","a_max";
}
{
  if ($1 != "E4_RESULT") exit 2;
  delete value; delete seen;
  for (i = 2; i <= NF; i++) {
    count = split($i, pair, "=");
    if (count != 2 || pair[1] == "" || pair[2] !~ /^[0-9]+$/ || seen[pair[1]]++) exit 3;
    value[pair[1]] = pair[2];
  }
  key_count = split(keys, required, " ");
  for (i = 1; i <= key_count; i++) if (!(required[i] in value)) exit 4;
  print value["q"],value["d"],value["n"],value["w"],value["race_ppm"],value["c_min"],value["c_p50"],value["c_p95"],value["c_p99"],value["c_p999"],value["c_max"],value["r_min"],value["r_p50"],value["r_p95"],value["r_p99"],value["r_p999"],value["r_max"],value["a_min"],value["a_p50"],value["a_p95"],value["a_p99"],value["a_p999"],value["a_max"];
}
' "$ROWS_RAW" > "$TABLE" || die 'malformed E4 result row'
[ "$(($(wc -l < "$TABLE") - 1))" = 35 ] || die 'parsed measurement row count mismatch'

printf 'q\td\n' > "$OUT_DIR/expected-cells.tsv"
for q in 0 1 8 64 256 1024 4096; do
	for d in 0 1 4 16 64; do printf '%s\t%s\n' "$q" "$d"; done
done
tail -n +2 "$OUT_DIR/expected-cells.tsv" | sort -n -k1,1 -k2,2 > "$OUT_DIR/expected-cells.sorted"
tail -n +2 "$TABLE" | cut -f1,2 | sort -n -k1,1 -k2,2 > "$OUT_DIR/actual-cells.sorted"
cmp "$OUT_DIR/expected-cells.sorted" "$OUT_DIR/actual-cells.sorted" >/dev/null || die 'missing, duplicate, or unexpected measurement cell'

awk -F '\t' '
NR == 1 { next }
$3 != 10000 || $4 < 256 || $5 != 0 { exit 2 }
!($6 <= $7 && $7 <= $8 && $8 <= $9 && $9 <= $10 && $10 <= $11) { exit 3 }
!($12 <= $13 && $13 <= $14 && $14 <= $15 && $15 <= $16 && $16 <= $17) { exit 4 }
!($18 <= $19 && $19 <= $20 && $20 <= $21 && $21 <= $22 && $22 <= $23) { exit 5 }
' "$TABLE" || die 'sample count, race rate, or statistic ordering mismatch'

printf 'q\td\treason\tobserved_ns\tlimit_ns\n' > "$FAILURES"
awk -F '\t' 'BEGIN {OFS="\t"} NR > 1 {
  if ($21 > 25000) print $1,$2,"additional_p99",$21,25000;
  if ($23 > 50000) print $1,$2,"additional_max",$23,50000;
  if ($23 >= 700000) print $1,$2,"additional_reached_base_slice",$23,699999;
}' "$TABLE" >> "$FAILURES"
threshold_breaches=$(($(wc -l < "$FAILURES") - 1))

lockdep_warnings=$(grep -Eic 'possible circular locking dependency|inconsistent lock state|bad unlock balance|held lock freed|WARNING:.*(lockdep|locking)' "$SERIAL_LOG" || true)
irqsoff_warnings=$(grep -Eic 'irqsoff.*(WARNING|BUG|latency exceeded)|(WARNING|BUG).*irqsoff' "$SERIAL_LOG" || true)
rcu_warnings=$(grep -Eic 'rcu: INFO: rcu_.*detected stalls|RCU Stall|rcu.*stall.*detected' "$SERIAL_LOG" || true)
softlockup_warnings=$(grep -Eic 'watchdog: BUG: soft lockup|soft lockup - CPU' "$SERIAL_LOG" || true)
hardlockup_warnings=$(grep -Eic 'NMI watchdog: Watchdog detected hard LOCKUP|hard LOCKUP' "$SERIAL_LOG" || true)
warning_count=$((lockdep_warnings + irqsoff_warnings + rcu_warnings + softlockup_warnings + hardlockup_warnings))
printf 'class\tcount\nlockdep\t%s\nirqsoff\t%s\nrcu_stall\t%s\nsoft_lockup\t%s\nhard_lockup\t%s\n' \
	"$lockdep_warnings" "$irqsoff_warnings" "$rcu_warnings" "$softlockup_warnings" "$hardlockup_warnings" > "$OUT_DIR/warnings.tsv"

if grep -Eqi 'Kernel panic|Oops:|Unable to handle kernel paging request|Internal error:|KASAN:|UBSAN:' "$SERIAL_LOG"; then
	die 'kernel integrity failure outside the valid rejection classes'
fi

if [ "$threshold_breaches" -gt 0 ] || [ "$warning_count" -gt 0 ]; then
	classification=rejected_full_locked_rebuild
	x86_may_launch=false
else
	classification=passed_e4_architecture_measurement
	x86_may_launch=true
fi

tail -n +2 "$TABLE" | jq -Rn '[inputs | split("\t") | {
  q:(.[0]|tonumber),d:(.[1]|tonumber),n:(.[2]|tonumber),w:(.[3]|tonumber),race_ppm:(.[4]|tonumber),
  control:{minimum:(.[5]|tonumber),p50:(.[6]|tonumber),p95:(.[7]|tonumber),p99:(.[8]|tonumber),p999:(.[9]|tonumber),maximum:(.[10]|tonumber)},
  rebuild:{minimum:(.[11]|tonumber),p50:(.[12]|tonumber),p95:(.[13]|tonumber),p99:(.[14]|tonumber),p999:(.[15]|tonumber),maximum:(.[16]|tonumber)},
  additional:{minimum:(.[17]|tonumber),p50:(.[18]|tonumber),p95:(.[19]|tonumber),p99:(.[20]|tonumber),p999:(.[21]|tonumber),maximum:(.[22]|tonumber)}
}]' > "$OUT_DIR/measurement-rows.json"
tail -n +2 "$FAILURES" | jq -Rn '[inputs | split("\t") | {q:(.[0]|tonumber),d:(.[1]|tonumber),reason:.[2],observed_ns:(.[3]|tonumber),limit_ns:(.[4]|tonumber)}]' > "$OUT_DIR/threshold-failures.json"

source_gate_sha=$(sha256sum "$SOURCE_GATE_RESULT" | awk '{print $1}')
config_sha=$(sha256sum "$BUILD_OUT/.config" | awk '{print $1}')
image_sha=$(sha256sum "$IMAGE" | awk '{print $1}')
object_sha=$(sha256sum "$BUILD_OUT/kernel/sched/fair.o" | awk '{print $1}')
serial_sha=$(sha256sum "$SERIAL_LOG" | awk '{print $1}')
ktap_sha=$(sha256sum "$KTAP_LOG" | awk '{print $1}')
table_sha=$(sha256sum "$TABLE" | awk '{print $1}')
host_env_sha=$(sha256sum "$OUT_DIR/host-environment.txt" | awk '{print $1}')
warning_config_sha=$(sha256sum "$OUT_DIR/warning-config.txt" | awk '{print $1}')
compiler=$(sed -n '1p' "$OUT_DIR/compiler.txt")
qemu_version=$(sed -n '1p' "$OUT_DIR/qemu-version.txt")
container_uname=$(sed -n '1p' "$OUT_DIR/container-uname.txt")
clocksource_detail=$(grep -Ei 'clocksource|arch_sys_counter' "$SERIAL_LOG" | tail -n 1 || true)

jq -n \
	--arg run_id "$RUN_ID" --arg status "$classification" \
	--arg source_gate_sha256 "$source_gate_sha" --arg config "$BUILD_OUT/.config" --arg config_sha256 "$config_sha" \
	--arg image "$IMAGE" --arg image_sha256 "$image_sha" --arg fair_object_sha256 "$object_sha" \
	--arg serial "$SERIAL_LOG" --arg serial_sha256 "$serial_sha" --arg ktap "$KTAP_LOG" --arg ktap_sha256 "$ktap_sha" \
	--arg table "$TABLE" --arg table_sha256 "$table_sha" --arg host_environment_sha256 "$host_env_sha" --arg warning_config_sha256 "$warning_config_sha" \
	--arg compiler "$compiler" --arg qemu_version "$qemu_version" --arg container_uname "$container_uname" --arg clocksource_detail "$clocksource_detail" \
	--argjson qemu_exit_code "$qemu_rc" --argjson threshold_breach_count "$threshold_breaches" --argjson warning_count "$warning_count" \
	--argjson runtime_base_slice_ns "$runtime_base_slice_ns" --argjson tunable_scaling "$tunable_scaling" --argjson online_cpus "$online_cpus" \
	--argjson lockdep_warnings "$lockdep_warnings" --argjson irqsoff_warnings "$irqsoff_warnings" --argjson rcu_warnings "$rcu_warnings" \
	--argjson softlockup_warnings "$softlockup_warnings" --argjson hardlockup_warnings "$hardlockup_warnings" --argjson x86_may_launch "$x86_may_launch" \
	--slurpfile rows "$OUT_DIR/measurement-rows.json" --slurpfile failures "$OUT_DIR/threshold-failures.json" \
	'{schema_version:1,run_id:$run_id,status:$status,architecture:"arm64",source_commit:"f6ad4e454778c52bcdaaecf684c148a3a8dae857",source_tree:"265e6357627490e51084979382ef34b2cfcc0cb8",source_diff_sha256:"3f52a2b2724bd795466ab1f344bf3d02fde7ee6a39bfde0945f7f8cf6ab8e3a3",source_gate_result_sha256:$source_gate_sha256,matrix:{queue_sizes:[0,1,8,64,256,1024,4096],depths:[0,1,4,16,64],cells:35,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000,race_ppm:0,result_rows:($rows[0]|length)},gate:{base_slice_ns:700000,base_slice_semantics:"normalized_sysctl_sched_base_slice_fixed_threshold_basis",runtime_base_slice_ns:$runtime_base_slice_ns,tunable_scaling:$tunable_scaling,runtime_scaling_may_not_relax_thresholds:true,additional_p99_limit_ns:25000,additional_max_limit_ns:50000,sample_may_reach_base_slice:false,threshold_breach_count:$threshold_breach_count,warning_count:$warning_count},measurement_rows:$rows[0],threshold_failures:$failures[0],warnings:{evidence_available:true,configuration_sha256:$warning_config_sha256,irqsoff_tracer_active:true,lockdep:$lockdep_warnings,irqsoff:$irqsoff_warnings,rcu_stall:$rcu_warnings,soft_lockup:$softlockup_warnings,hard_lockup:$hardlockup_warnings,total:$warning_count},environment:{outer_host_record_sha256:$host_environment_sha256,outer_virtualization:"Apple Container machine domainlease-dev",container_uname:$container_uname,qemu_version:$qemu_version,qemu_accelerator:"tcg,thread=multi",qemu_machine:"virt,gic-version=3",qemu_cpu:"cortex-a57",qemu_cpus:2,qemu_memory_mib:2048,qemu_network_disabled:true,guest_architecture:"arm64",guest_online_cpus:$online_cpus,guest_sched_tunable_scaling:$tunable_scaling,guest_runtime_base_slice_ns:$runtime_base_slice_ns,guest_frequency_governor_available:false,guest_frequency_governor_note:"fixed virtual cortex-a57 under TCG; no guest userspace cpufreq probe",compiler:$compiler,sample_clock:"local_clock",clocksource_detail:$clocksource_detail,kernel_command_line_parameters_recognized:true,virtualized_result_supports_bare_metal_claim:false},artifacts:{config:{path:$config,sha256:$config_sha256},image:{path:$image,sha256:$image_sha256},fair_object_sha256:$fair_object_sha256,serial:{path:$serial,sha256:$serial_sha256},normalized_ktap:{path:$ktap,sha256:$ktap_sha256},measurement_table:{path:$table,sha256:$table_sha256}},qemu_exit_code:$qemu_exit_code,kunit:{suite:"sched_exec_lease_rebuild_measure",suite_passed:true,case_count:1,failed_cases:0,skipped_required_cases:0},architecture_measurement_valid:true,threshold_failure_is_valid_negative_evidence:true,x86_64_measurement_may_be_launched:$x86_may_launch,e4_measurement_accepted:false,full_locked_rebuild_approved:false,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,real_picker_fence_approved:false,real_publisher_approved:false,real_fanout_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,bare_metal_latency_claim:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"

if [ "$classification" = rejected_full_locked_rebuild ]; then
	progress "100% complete negative evidence; full locked rebuild rejected ($threshold_breaches threshold breaches, $warning_count warnings)"
else
	progress '100% passed arm64 architecture measurement; E4 remains pending same-source x86_64 evidence'
fi
cat "$OUT_DIR/result.json"
