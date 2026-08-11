#!/usr/bin/env bash
set -euo pipefail

usage()
{
	printf 'usage: %s RUN_ID\n' "$0" >&2
}

[[ $# -eq 1 ]] || {
	usage
	exit 64
}
[[ ${EUID:-$(/usr/bin/id -u)} -eq 0 ]] || {
	printf 'error: root is required\n' >&2
	exit 77
}

run_id=$1
[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
	printf 'error: unsafe run ID\n' >&2
	exit 64
}

readonly state_root=/var/lib/domainlease-f0-c4
readonly evidence_root=$state_root/evidence
readonly reduction_root=$state_root/reductions
readonly toolchain_root=$state_root/toolchain/root
readonly libexec=/usr/local/libexec/domainlease-f0-c4
readonly share=/usr/local/share/domainlease-f0-c4
readonly supervisor=$libexec/f0-c4-reduction-supervisor.py
readonly reducer=$libexec/f0-c4-post-run-reducer.py
readonly contract=$share/f0-c4-capture-contract-v1.json
readonly unit=domainlease-f0-c4-reduction-$run_id

for required in "$supervisor" "$reducer" "$contract"; do
	[[ -f $required && ! -L $required ]] || {
		printf 'error: installed reduction artifact missing: %s\n' "$required" >&2
		exit 1
	}
done
for directory in "$state_root" "$evidence_root" "$toolchain_root"; do
	[[ -d $directory && ! -L $directory ]] || {
		printf 'error: fixed reduction prerequisite missing: %s\n' "$directory" >&2
		exit 1
	}
done
/usr/bin/install -d -o root -g root -m 0700 "$reduction_root"

exec /usr/bin/systemd-run \
	--quiet --wait --pipe --collect \
	--unit "$unit" \
	--service-type exec \
	--setenv F0_C4_REDUCTION_SUPERVISOR=systemd-v1 \
	--setenv F0_C4_REDUCTION_UNIT=$unit.service \
	--property User=root \
	--property Group=root \
	--property UMask=0077 \
	--property StandardInput=null \
	--property KillMode=control-group \
	--property RuntimeMaxSec=1200s \
	--property TimeoutStopSec=35s \
	--property SendSIGKILL=yes \
	--property OOMPolicy=kill \
	--property MemoryMax=5368709120 \
	--property MemorySwapMax=0 \
	--property TasksMax=128 \
	--property NoNewPrivileges=yes \
	--property CapabilityBoundingSet= \
	--property AmbientCapabilities= \
	--property ProtectSystem=strict \
	--property ProtectHome=yes \
	--property PrivateTmp=yes \
	--property PrivateDevices=yes \
	--property PrivateNetwork=yes \
	--property ProtectControlGroups=yes \
	--property ProtectKernelTunables=yes \
	--property ProtectKernelModules=yes \
	--property ProtectKernelLogs=yes \
	--property ProtectClock=yes \
	--property LockPersonality=yes \
	--property RestrictSUIDSGID=yes \
	--property RestrictRealtime=yes \
	--property RestrictNamespaces=yes \
	--property RestrictAddressFamilies=AF_UNIX \
	--property SystemCallArchitectures=native \
	--property SystemCallFilter=@system-service \
	--property 'SystemCallFilter=~@privileged @resources' \
	--property ReadWritePaths="$reduction_root" \
	--property ReadOnlyPaths="$evidence_root $toolchain_root $libexec $share" \
	-- /usr/bin/python3 -I -S -B "$supervisor" \
	--run-id "$run_id" \
	--reducer "$reducer" \
	--contract "$contract"
