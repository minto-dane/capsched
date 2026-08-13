#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	printf 'error: root is required\n' >&2
	exit 77
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
launcher=${F0_C4_LAUNCHER:-$script_dir/f0-c4-capture-launcher}
run_root=/run/f0-c4-launcher-basic-$$
cgroup_root=/sys/fs/cgroup/f0-c4-launcher-basic-$$
component_cgroup=$cgroup_root/component

cleanup()
{
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
printf '64' > "$component_cgroup/pids.max"
printf '268435456' > "$component_cgroup/memory.max"
printf '0' > "$component_cgroup/memory.swap.max"
printf '1' > "$component_cgroup/memory.oom.group"
mkdir -m 0755 -- "$run_root/sandbox"
mkdir -m 0700 -- "$run_root/scratch"
chown 200001:200001 "$run_root/scratch"

set +e
meta=$(
	"$launcher" \
		--cgroup "$component_cgroup" \
		--sandbox-root "$run_root/sandbox" \
		--scratch "$run_root/scratch" \
		--input "$script_dir/fixtures" \
		--toolchain-root /usr \
		--stdout-file "$run_root/stdout.raw" \
		--stderr-file "$run_root/stderr.raw" \
		--preexec-file "$run_root/preexec.raw" \
		--component exit-zero \
		--candidate-uid 200001 \
		--candidate-gid 200001 \
		--deadline-seconds 30 \
		--stdout-limit 1048576 \
		--stderr-limit 1048576 \
		--preexec-limit 1048576 \
		-- /usr/bin/python3 -S -B /INPUT/exit-zero.py \
		2>"$run_root/launcher.stderr"
)
launcher_rc=$?
set -e
if [[ $launcher_rc -ne 0 ]]; then
	printf 'error: launcher returned %d\n' "$launcher_rc" >&2
	cat "$run_root/launcher.stderr" >&2
	printf '%s\n' "$meta" >&2
	exit 1
fi

jq -e '
	.schema_version == 1 and
	.component_id == "exit-zero" and
	.pidfd_observed == true and
	.termination == "EXITED_ZERO" and
	.exit_code == 0 and
	.signal == 0 and
	.deadline_exceeded == false and
	.stdout_limit_exceeded == false and
	.stderr_size == 0 and
	.stderr_limit_exceeded == false and
	.preexec_limit_exceeded == false and
	.preexec_observation_size > 0 and
	(.preexec_observation_sha256 | test("^[0-9a-f]{64}$")) and
	.cgroup_kill_used == true and
	.populated_zero_observed == true and
	.setup_ok == true and
	.capture_error == false
' <<<"$meta" >/dev/null
[[ $(cat "$run_root/stdout.raw") == FIXTURE_EXIT_ZERO ]]
[[ ! -s $run_root/stderr.raw ]]
grep -Fq 'F0_C4_PREEXEC_ATTESTATION_V1' "$run_root/preexec.raw"
grep -Fq 'fd=0 cloexec=0 target=/dev/null' "$run_root/preexec.raw"
grep -Fq 'NoNewPrivs:' "$run_root/preexec.raw"
grep -Fq 'Seccomp:' "$run_root/preexec.raw"
[[ $(stat -c '%a:%u:%g' "$run_root/stdout.raw") == 444:0:0 ]]
[[ $(stat -c '%a:%u:%g' "$run_root/stderr.raw") == 444:0:0 ]]
[[ $(stat -c '%a:%u:%g' "$run_root/preexec.raw") == 444:0:0 ]]

printf 'F0_C4_CAPTURE_LAUNCHER_BASIC_PASS\n'
