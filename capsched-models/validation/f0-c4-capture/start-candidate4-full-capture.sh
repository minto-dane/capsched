#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
sync_script=$script_dir/sync-candidate-inputs-to-apple-container-machine.sh
readonly runner=/usr/local/libexec/domainlease-f0-c4/run-capture-systemd.sh
readonly evidence_root=/var/lib/domainlease-f0-c4/evidence

run_id=${1:-candidate4-full-$(date -u '+%Y%m%dT%H%M%SZ')}
[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
	printf 'usage: %s [SAFE_RUN_ID]\n' "$0" >&2
	exit 64
}
readonly run_id
readonly launcher_unit=domainlease-f0-c4-host-launch-$run_id
readonly capture_unit=domainlease-f0-c4-$run_id

source_dir=$("$sync_script")
readonly source_dir
container machine run --root -n domainlease-dev -- \
	/usr/bin/test -x "$runner"

for unit in "$launcher_unit" "$capture_unit"; do
	active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$unit" 2>/dev/null || true)
	[[ $active != active && $active != activating ]] || {
		printf 'error: %s is already active\n' "$unit" >&2
		exit 1
	}
done
if container machine run --root -n domainlease-dev -- \
	/usr/bin/test -e "$evidence_root/$run_id"; then
	printf 'error: evidence already exists for run ID: %s\n' "$run_id" >&2
	exit 1
fi

container machine run --root -n domainlease-dev -- \
	/usr/bin/systemd-run \
	--quiet --no-block \
	--unit "$launcher_unit" \
	--service-type exec \
	--property StandardInput=null \
	--property KillMode=control-group \
	--property RuntimeMaxSec=137100s \
	--property TimeoutStopSec=40s \
	--property OOMPolicy=kill \
	-- "$runner" "$run_id" "$source_dir"

ready=false
for _ in {1..20}; do
	capture_active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$capture_unit" 2>/dev/null || true)
	if [[ $capture_active == active || $capture_active == activating ]] || \
		container machine run --root -n domainlease-dev -- \
		/usr/bin/test -f "/run/domainlease-f0-c4/progress/$run_id"; then
		ready=true
		break
	fi
	launcher_failed=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-failed "$launcher_unit" 2>/dev/null || true)
	if [[ $launcher_failed == failed ]]; then
		break
	fi
	sleep 1
done
if [[ $ready != true ]]; then
	printf 'error: detached capture did not reach its first durable progress receipt\n' >&2
	container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl show "$launcher_unit" \
		--property ActiveState --property SubState --property Result \
		--property ExecMainStatus --no-pager >&2 || true
	container machine run --root -n domainlease-dev -- \
		/usr/bin/journalctl -u "$launcher_unit" -u "$capture_unit" \
		-n 24 --no-pager >&2 || true
	exit 1
fi

printf 'F0_C4_FULL_CAPTURE_STARTED run_id=%s unit=%s\n' \
	"$run_id" "$capture_unit"
printf 'monitor: %s/monitor-candidate4-full-capture.sh %s 30\n' \
	"$script_dir" "$run_id"
