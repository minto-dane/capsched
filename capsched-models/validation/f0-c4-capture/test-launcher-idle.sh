#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	printf 'error: root is required\n' >&2
	exit 77
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
launcher=${F0_C4_LAUNCHER:-$script_dir/f0-c4-capture-launcher}
run_root=/run/f0-c4-launcher-idle-$$
cgroup_root=/sys/fs/cgroup/f0-c4-launcher-idle-$$
component_cgroup=$cgroup_root/component
launcher_pid=

cleanup()
{
	if [[ -n $launcher_pid ]] && kill -0 "$launcher_pid" 2>/dev/null; then
		kill "$launcher_pid" 2>/dev/null || true
		wait "$launcher_pid" 2>/dev/null || true
	fi
	if [[ -e $component_cgroup/cgroup.kill ]]; then
		printf '1' > "$component_cgroup/cgroup.kill" 2>/dev/null || true
	fi
	rmdir "$component_cgroup" "$cgroup_root" 2>/dev/null || true
	rm -rf -- "$run_root"
}
trap cleanup EXIT HUP INT TERM

[[ -x $launcher ]] || {
	printf 'error: launcher missing or not executable: %s\n' "$launcher" >&2
	exit 1
}
mkdir -m 0700 -- "$run_root"
mkdir -- "$cgroup_root"
printf '+memory +pids' > "$cgroup_root/cgroup.subtree_control"
mkdir -- "$component_cgroup"
printf '32' > "$component_cgroup/pids.max"
printf '268435456' > "$component_cgroup/memory.max"
printf '0' > "$component_cgroup/memory.swap.max"
printf '1' > "$component_cgroup/memory.oom.group"
mkdir -m 0755 -- "$run_root/sandbox"
mkdir -m 0700 -- "$run_root/scratch"
chown 200003:200003 "$run_root/scratch"

"$launcher" \
	--cgroup "$component_cgroup" \
	--sandbox-root "$run_root/sandbox" \
	--scratch "$run_root/scratch" \
	--input "$script_dir/fixtures" \
	--toolchain-root /usr \
	--stdout-file "$run_root/stdout.raw" \
	--stderr-file "$run_root/stderr.raw" \
	--preexec-file "$run_root/preexec.raw" \
	--component idle-wait \
	--candidate-uid 200003 \
	--candidate-gid 200003 \
	--deadline-seconds 3 \
	--stdout-limit 1048576 \
	--stderr-limit 1048576 \
	--preexec-limit 1048576 \
	-- /usr/bin/python3 -S -B /INPUT/sleep.py \
	>"$run_root/meta.json" 2>"$run_root/launcher.stderr" &
launcher_pid=$!

component_pids=
for _ in {1..100}; do
	component_pids=$(<"$component_cgroup/cgroup.procs")
	[[ -n $component_pids ]] && break
	sleep 0.02
done
[[ -n $component_pids ]] || {
	printf 'error: candidate did not enter component cgroup\n' >&2
	exit 1
}
sleep 0.25
[[ -r /proc/$launcher_pid/stat ]] || {
	printf 'error: launcher exited before idle CPU sample\n' >&2
	cat "$run_root/launcher.stderr" >&2
	exit 1
}
ticks_before=$(awk '{print $14 + $15}' "/proc/$launcher_pid/stat")
sleep 1
ticks_after=$(awk '{print $14 + $15}' "/proc/$launcher_pid/stat")
clock_ticks=$(getconf CLK_TCK)
idle_ticks=$((ticks_after - ticks_before))

set +e
wait "$launcher_pid"
launcher_rc=$?
set -e
launcher_pid=
if [[ $launcher_rc -ne 1 ]]; then
	printf 'error: idle launcher returned %d, expected deadline status 1\n' \
		"$launcher_rc" >&2
	cat "$run_root/launcher.stderr" >&2
	cat "$run_root/meta.json" >&2
	exit 1
fi
if ((idle_ticks * 2 > clock_ticks)); then
	printf 'error: launcher consumed %d/%d CPU ticks while candidate slept\n' \
		"$idle_ticks" "$clock_ticks" >&2
	exit 1
fi
jq -e '
	.component_id == "idle-wait" and
	.termination == "DEADLINE_EXCEEDED" and
	.deadline_exceeded == true and
	.capture_error == false and
	.populated_zero_observed == true
' "$run_root/meta.json" >/dev/null

printf 'F0_C4_CAPTURE_LAUNCHER_IDLE_PASS idle_cpu_ticks=%d clock_ticks=%d\n' \
	"$idle_ticks" "$clock_ticks"
