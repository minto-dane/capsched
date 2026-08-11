#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
sync_script=$script_dir/sync-to-apple-container-home.sh
readonly vm_cache=/Users/niania/Library/Caches/domainlease-linux-cap-vm/capsched
readonly source_dir=$vm_cache/capsched-models/validation
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

"$sync_script"
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
	--quiet --no-block --collect \
	--unit "$launcher_unit" \
	--service-type exec \
	--property StandardInput=null \
	--property KillMode=control-group \
	--property RuntimeMaxSec=137100s \
	--property TimeoutStopSec=40s \
	--property OOMPolicy=kill \
	-- "$runner" "$run_id" "$source_dir"

printf 'F0_C4_FULL_CAPTURE_STARTED run_id=%s unit=%s\n' \
	"$run_id" "$capture_unit"
printf 'monitor: %s/monitor-candidate4-full-capture.sh %s 30\n' \
	"$script_dir" "$run_id"
