#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
sync_script=$script_dir/sync-to-apple-container-home.sh
readonly vm_cache=/Users/niania/Library/Caches/domainlease-linux-cap-vm/capsched
readonly vm_script=$vm_cache/capsched-models/validation/f0-c4-capture/seal-toolchain-image.sh
readonly staged_script=/run/domainlease-f0-c4/seal-toolchain-image.sh
readonly unit=domainlease-f0-c4-toolchain-seal

"$sync_script"
container machine run --root -n domainlease-dev -- \
	/usr/bin/install -D -o root -g root -m 0755 \
	"$vm_script" "$staged_script"

active=$(container machine run --root -n domainlease-dev -- \
	/usr/bin/systemctl is-active "$unit" 2>/dev/null || true)
[[ $active != active && $active != activating ]] || {
	printf 'error: %s is already active\n' "$unit" >&2
	exit 1
}

container machine run --root -n domainlease-dev -- \
	/usr/bin/systemd-run \
	--quiet --no-block --collect \
	--unit "$unit" \
	--service-type exec \
	--property StandardInput=null \
	--property KillMode=control-group \
	--property RuntimeMaxSec=3600s \
	--property TimeoutStopSec=30s \
	--property OOMPolicy=kill \
	-- "$staged_script"

printf 'F0_C4_TOOLCHAIN_SEAL_STARTED unit=%s\n' "$unit"
printf 'monitor: %s/monitor-toolchain-seal.sh 30\n' "$script_dir"
