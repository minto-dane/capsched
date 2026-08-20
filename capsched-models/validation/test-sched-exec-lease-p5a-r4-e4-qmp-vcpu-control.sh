#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QMP_CONTROL="$SCRIPT_DIR/qmp-sched-exec-lease-vcpu-control.py"
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement.sh"
QMP_CONTROL_SHA=e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e
EXPECTED_VCPUS=2
TEMP_ROOT=$(mktemp -d /var/tmp/p5a-r4-e4-qmp-vcpu-control.XXXXXX)
QMP_SOCKET="$TEMP_ROOT/qmp.sock"
QEMU_PID_FILE="$TEMP_ROOT/qemu.pid"
MAPPING="$TEMP_ROOT/qmp-vcpus.txt"
AFFINITY="$TEMP_ROOT/qmp-vcpu-affinity.txt"
QEMU_PID=

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

cleanup()
{
	local pid=${QEMU_PID:-} attempts=0
	trap - EXIT INT TERM
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		while kill -0 "$pid" 2>/dev/null && [ "$attempts" -lt 30 ]; do
			sleep 0.1
			attempts=$((attempts + 1))
		done
		kill -KILL "$pid" 2>/dev/null || true
	fi
	case "$TEMP_ROOT" in
		/var/tmp/p5a-r4-e4-qmp-vcpu-control.*) find "$TEMP_ROOT" -depth -delete ;;
		*) printf 'error: unsafe QMP test cleanup path: %s\n' "$TEMP_ROOT" >&2; exit 1 ;;
	esac
}
trap cleanup EXIT
trap 'exit 130' INT TERM

for command in awk cat find grep kill mktemp python3 qemu-system-aarch64 \
	sha256sum sleep taskset; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for input in "$QMP_CONTROL" "$RUNNER"; do
	if [ ! -f "$input" ] || [ -L "$input" ]; then
		die "unsafe input: $input"
	fi
done
[ "$(sha256sum "$QMP_CONTROL" | awk '{print $1}')" = "$QMP_CONTROL_SHA" ] \
	|| die 'QMP vCPU control hash changed'
grep -Fxq "QMP_CONTROL_SHA=$QMP_CONTROL_SHA" "$RUNNER" \
	|| die 'measurement runner does not bind the QMP control helper'
grep -Fq -- "-S -name \"guest=\$RUN_ID,debug-threads=on\"" "$RUNNER" \
	|| die 'measurement runner does not start the guest paused with debug thread names'
grep -Fq -- "--affinity \"\$QMP_AFFINITY\" --qemu-pid \"\$qemu_pid\"" "$RUNNER" \
	|| die 'measurement runner does not reverify singleton affinity before resume'
grep -Fq 'measurement emitted rows while QEMU was paused before resume' "$RUNNER" \
	|| die 'measurement runner does not reject pre-resume rows'
if grep -Fq 'CPU\ */TCG)' "$RUNNER"; then
	die 'measurement runner still relies on /proc thread-name discovery'
fi

python3 "$QMP_CONTROL" self-test > "$TEMP_ROOT/self-test.txt"
grep -Eq '^qmp_vcpu_control_self_test=passed negative_fixtures=[1-9][0-9]*$' \
	"$TEMP_ROOT/self-test.txt" || die 'QMP helper self-test did not pass'

host_allowed_list=$(awk '/^Cpus_allowed_list:/ {print $2}' /proc/self/status)
mapfile -t host_cpus < <(awk -v cpus="$host_allowed_list" 'BEGIN {
  n=split(cpus,part,",");
  for(i=1;i<=n;i++) {
    if(part[i] ~ /^[0-9]+$/) print part[i];
    else {split(part[i],range,"-"); for(cpu=range[1];cpu<=range[2];cpu++) print cpu}
  }
}')
[ "${#host_cpus[@]}" -ge "$EXPECTED_VCPUS" ] \
	|| die 'test environment cannot assign distinct host CPUs'

taskset -c "$host_allowed_list" qemu-system-aarch64 -daemonize -S \
	-name guest=r4-e4-qmp-vcpu-control-test,debug-threads=on \
	-qmp "unix:$QMP_SOCKET,server=on,wait=off" \
	-machine virt,gic-version=3 -cpu cortex-a57 -accel tcg,thread=multi \
	-smp "$EXPECTED_VCPUS",maxcpus="$EXPECTED_VCPUS" -m 256 -nic none \
	-display none -monitor none -serial none -pidfile "$QEMU_PID_FILE"
QEMU_PID=$(cat "$QEMU_PID_FILE")
case "$QEMU_PID" in ''|*[!0-9]*) die 'QEMU pid is malformed' ;; esac
kill -0 "$QEMU_PID" 2>/dev/null || die 'paused QEMU did not remain active'

python3 "$QMP_CONTROL" query --socket "$QMP_SOCKET" \
	--expected-vcpus "$EXPECTED_VCPUS" --timeout 30 > "$MAPPING"
grep -Eq '^qmp_status=(prelaunch|paused)$' "$MAPPING" \
	|| die 'QMP query did not prove a paused guest'
[ "$(grep -Ec '^vcpu=[0-9]+ tid=[0-9]+$' "$MAPPING")" = "$EXPECTED_VCPUS" ] \
	|| die 'QMP query did not return the exact vCPU mapping'

first_tid=$(awk '/^vcpu=0 / {sub(/^.*tid=/, ""); print}' "$MAPPING")
awk -v first_tid="$first_tid" '
  /^vcpu=1 / { print "vcpu=1 tid=" first_tid; next }
  { print }
' "$MAPPING" > "$TEMP_ROOT/duplicate-tid-mapping.txt"
if python3 "$QMP_CONTROL" resume --socket "$QMP_SOCKET" \
	--expected-vcpus "$EXPECTED_VCPUS" --mapping "$TEMP_ROOT/duplicate-tid-mapping.txt" \
	--affinity "$AFFINITY" --qemu-pid "$QEMU_PID" --timeout 5 \
	> "$TEMP_ROOT/duplicate-tid.stdout" 2> "$TEMP_ROOT/duplicate-tid.stderr"; then
	die 'duplicate QMP thread mapping was accepted'
fi

: > "$AFFINITY"
declare -A pinned_vcpu
pinned_vcpu=()
while IFS=' ' read -r vcpu_field tid_field extra; do
	case "$vcpu_field" in qmp_status=*) continue ;; vcpu=*) ;; *) die 'unknown mapping line' ;; esac
	[ -z "$extra" ] || die 'mapping has extra fields'
	vcpu=${vcpu_field#vcpu=}
	tid=${tid_field#tid=}
	[ -r "/proc/$QEMU_PID/task/$tid/status" ] \
		|| die "vCPU $vcpu is not owned by the test QEMU"
	host_cpu=${host_cpus[$vcpu]}
	taskset -pc "$host_cpu" "$tid" > "$TEMP_ROOT/taskset-$vcpu.txt"
	actual=$(awk '/^Cpus_allowed_list:/ {print $2}' "/proc/$QEMU_PID/task/$tid/status")
	[ "$actual" = "$host_cpu" ] || die "vCPU $vcpu did not become singleton-pinned"
	printf 'vcpu=%s tid=%s host_cpu=%s\n' "$vcpu" "$tid" "$host_cpu" >> "$AFFINITY"
	pinned_vcpu[$vcpu]=1
done < "$MAPPING"
[ "${#pinned_vcpu[@]}" = "$EXPECTED_VCPUS" ] || die 'not all test vCPUs were pinned'

awk 'NR == 2 {$0 = "vcpu=1 tid=999999 host_cpu=" $3} {print}' "$AFFINITY" \
	> "$TEMP_ROOT/tampered-affinity.txt"
if python3 "$QMP_CONTROL" resume --socket "$QMP_SOCKET" \
	--expected-vcpus "$EXPECTED_VCPUS" --mapping "$MAPPING" \
	--affinity "$TEMP_ROOT/tampered-affinity.txt" --qemu-pid "$QEMU_PID" --timeout 5 \
	> "$TEMP_ROOT/tampered-affinity.stdout" 2> "$TEMP_ROOT/tampered-affinity.stderr"; then
	die 'tampered affinity mapping was accepted'
fi

: > "$TEMP_ROOT/serial.log"
rows_before_resume=$(awk '/R4_E4_RESULT / { count++ } END { print count + 0 }' \
	"$TEMP_ROOT/serial.log")
[ "$rows_before_resume" = 0 ] || die 'empty paused serial fixture was rejected'
printf 'R4_E4_RESULT invalid-before-resume\n' > "$TEMP_ROOT/serial.log"
rows_before_resume=$(awk '/R4_E4_RESULT / { count++ } END { print count + 0 }' \
	"$TEMP_ROOT/serial.log")
[ "$rows_before_resume" = 1 ] || die 'pre-resume row fixture was not detected'

python3 "$QMP_CONTROL" resume --socket "$QMP_SOCKET" \
	--expected-vcpus "$EXPECTED_VCPUS" --mapping "$MAPPING" \
	--affinity "$AFFINITY" --qemu-pid "$QEMU_PID" --timeout 30 \
	> "$TEMP_ROOT/resume.txt"
grep -Fxq 'qmp_mapping_reverified=true' "$TEMP_ROOT/resume.txt" \
	|| die 'QMP mapping was not reverified'
grep -Fxq 'singleton_affinity_reverified=true' "$TEMP_ROOT/resume.txt" \
	|| die 'singleton affinity was not reverified'
grep -Fxq 'qmp_status_after_resume=running' "$TEMP_ROOT/resume.txt" \
	|| die 'QEMU did not resume'
for vcpu in 0 1; do
	tid=$(awk -v vcpu="$vcpu" '$1 == "vcpu=" vcpu {sub(/^tid=/, "", $2); print $2}' "$AFFINITY")
	host_cpu=${host_cpus[$vcpu]}
	actual=$(awk '/^Cpus_allowed_list:/ {print $2}' "/proc/$QEMU_PID/task/$tid/status")
	[ "$actual" = "$host_cpu" ] || die "vCPU $vcpu affinity drifted after resume"
done

printf '100%% QMP paused-start, exact mapping, singleton affinity, negative fixtures, and resume passed\n'
