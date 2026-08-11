#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
readonly installed_script=/usr/local/libexec/domainlease-f0-c4/seal-toolchain-image.sh
readonly unit=domainlease-f0-c4-toolchain-seal

container machine run --root -n domainlease-dev -- \
	/usr/bin/test -x "$installed_script"

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
	-- "$installed_script"

printf 'F0_C4_TOOLCHAIN_SEAL_STARTED unit=%s\n' "$unit"
printf 'monitor: %s/monitor-toolchain-seal.sh 30\n' "$script_dir"
