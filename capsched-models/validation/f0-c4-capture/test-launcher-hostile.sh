#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	printf 'error: root is required\n' >&2
	exit 77
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
launcher=${F0_C4_LAUNCHER:-$script_dir/f0-c4-capture-launcher}
run_root=/run/f0-c4-launcher-hostile-$$
cgroup_root=/sys/fs/cgroup/f0-c4-launcher-hostile-$$
case_count=0

cleanup()
{
	if [[ -e $cgroup_root/cgroup.kill ]]; then
		printf '1' > "$cgroup_root/cgroup.kill" 2>/dev/null || true
	fi
	find "$cgroup_root" -depth -type d -exec rmdir {} + 2>/dev/null || true
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

run_case()
{
	local name=$1
	local fixture=$2
	local expected_rc=$3
	local expected_termination=$4
	local deadline=$5
	local stdout_limit=$6
	local expected_stdout_prefix=${7:-}
	local component_cgroup=$cgroup_root/$name
	local case_root=$run_root/$name
	local meta rc

	mkdir -- "$component_cgroup"
	printf '32' > "$component_cgroup/pids.max"
	printf '268435456' > "$component_cgroup/memory.max"
	printf '0' > "$component_cgroup/memory.swap.max"
	printf '1' > "$component_cgroup/memory.oom.group"
	mkdir -m 0700 -- "$case_root"
	mkdir -m 0755 -- "$case_root/sandbox"
	mkdir -m 0700 -- "$case_root/scratch"
	chown 200002:200002 "$case_root/scratch"
	set +e
	meta=$(
		"$launcher" \
			--cgroup "$component_cgroup" \
			--sandbox-root "$case_root/sandbox" \
			--scratch "$case_root/scratch" \
			--input "$script_dir/fixtures" \
			--toolchain-root /usr \
			--stdout-file "$case_root/stdout.raw" \
			--stderr-file "$case_root/stderr.raw" \
			--preexec-file "$case_root/preexec.raw" \
			--component "$name" \
			--candidate-uid 200002 \
			--candidate-gid 200002 \
			--deadline-seconds "$deadline" \
			--stdout-limit "$stdout_limit" \
			--stderr-limit 1048576 \
			--preexec-limit 1048576 \
			-- /usr/bin/python3 -S -B "/INPUT/$fixture" \
			2>"$case_root/launcher.stderr"
	)
	rc=$?
	set -e
	if [[ $rc -ne $expected_rc ]]; then
		printf 'error: %s rc=%d expected=%d\n' "$name" "$rc" "$expected_rc" >&2
		cat "$case_root/launcher.stderr" >&2
		printf '%s\n' "$meta" >&2
		exit 1
	fi
	jq -e --arg name "$name" --arg termination "$expected_termination" '
		.schema_version == 1 and
		.component_id == $name and
		.pidfd_observed == true and
		.termination == $termination and
		.cgroup_kill_used == true and
		.populated_zero_observed == true and
		.setup_ok == true and
		.capture_error == false and
		.preexec_limit_exceeded == false and
		.preexec_observation_size > 0 and
		(.preexec_observation_sha256 | test("^[0-9a-f]{64}$"))
	' <<<"$meta" >/dev/null
	grep -Fq '[namespace_ids]' "$case_root/preexec.raw"
	grep -Fq 'fd=0 cloexec=0 target=/dev/null' "$case_root/preexec.raw"
	grep -Fq 'name=lo ' "$case_root/preexec.raw"
	[[ $(<"$component_cgroup/cgroup.events") == *'populated 0'* ]]
	if [[ -n $expected_stdout_prefix ]]; then
		[[ $(head -c "${#expected_stdout_prefix}" "$case_root/stdout.raw") == "$expected_stdout_prefix" ]]
	fi
	case_count=$((case_count + 1))
	rmdir "$component_cgroup"
}

run_case fork-setsid fork-setsid.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_FORK_SETSID_PARENT_EXIT
run_case fork-pressure fork-pressure.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_FORK_PRESSURE_BLOCKED
run_case input-readonly input-readonly.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_INPUT_READONLY
run_case mount-denied mount-denied.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_MOUNT_DENIED
run_case network-down network-down.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_NETWORK_DOWN
run_case root-view-minimal root-view-minimal.py 0 EXITED_ZERO 20 1048576 \
	FIXTURE_ROOT_VIEW_MINIMAL
run_case deadline sleep.py 1 DEADLINE_EXCEEDED 1 1048576
run_case output-limit output-flood.py 1 OUTPUT_LIMIT_EXCEEDED 20 4096
run_case nonzero nonzero.py 1 EXITED_NONZERO 20 1048576
run_case stderr stderr.py 1 EXITED_ZERO 20 1048576

printf 'F0_C4_CAPTURE_LAUNCHER_HOSTILE_PASS hostile_cases=%d\n' "$case_count"
