#!/usr/bin/env bash
set -euo pipefail

usage()
{
	printf 'usage: %s RUN_ID SOURCE_DIR\n' "$0" >&2
}

[[ $# -eq 2 ]] || {
	usage
	exit 64
}
[[ ${EUID:-$(id -u)} -eq 0 ]] || {
	printf 'error: root is required\n' >&2
	exit 77
}

run_id=$1
source_dir=$2
readonly state_root=/var/lib/domainlease-f0-c4
readonly evidence_root=$state_root/evidence
readonly candidate_uid=200010
readonly progress_root=/run/domainlease-f0-c4/progress
readonly progress_file=$progress_root/$run_id
readonly toolchain_root=$state_root/toolchain/root
readonly toolchain_image=$state_root/toolchain/candidate.erofs
readonly toolchain_manifest=$state_root/toolchain/manifest.json
supervisor=/usr/local/libexec/domainlease-f0-c4/f0-c4-capture-supervisor.py
launcher=/usr/local/libexec/domainlease-f0-c4/f0-c4-capture-launcher
guardian=/usr/local/libexec/domainlease-f0-c4/f0-c4-guardian-finalize.py
sealer=/usr/local/libexec/domainlease-f0-c4/seal-toolchain-image.sh
contract=/usr/local/share/domainlease-f0-c4/f0-c4-capture-contract-v1.json

[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
	printf 'error: unsafe run ID\n' >&2
	exit 64
}
[[ $source_dir == /* ]] || {
	printf 'error: source path must be absolute\n' >&2
	exit 64
}
for required in "$supervisor" "$launcher" "$guardian" "$sealer" "$contract"; do
	[[ -f $required && ! -L $required ]] || {
		printf 'error: installed capture artifact missing: %s\n' "$required" >&2
		exit 1
	}
done
"$sealer"
for required in "$toolchain_image" "$toolchain_manifest"; do
	[[ -f $required && ! -L $required ]] || {
		printf 'error: sealed toolchain artifact missing: %s\n' "$required" >&2
		exit 1
	}
done
[[ -d $toolchain_root && ! -L $toolchain_root ]] || {
	printf 'error: immutable toolchain root is not mounted: %s\n' "$toolchain_root" >&2
	exit 1
}
for directory in "$state_root" "$evidence_root" "$state_root/intents" \
	/run/domainlease-f0-c4 "$progress_root"; do
	[[ ! -L $directory ]] || {
		printf 'error: fixed state path is a symlink: %s\n' "$directory" >&2
		exit 1
	}
	mkdir -p -m 0700 -- "$directory"
	chown root:root "$directory"
	chmod 0700 "$directory"
done

/usr/bin/python3 -I -S -B "$guardian" reconcile

command=(
	/usr/bin/python3 -I -S -B "$supervisor"
	--run-id "$run_id"
	--campaign-class candidate4-exact
	--source-dir "$source_dir"
	--evidence-root "$evidence_root"
	--contract "$contract"
	--launcher "$launcher"
	--toolchain-root "$toolchain_root"
	--toolchain-image "$toolchain_image"
	--toolchain-manifest "$toolchain_manifest"
	--candidate-uid "$candidate_uid"
	--candidate-gid "$candidate_uid"
	--progress "$progress_file"
)

exec systemd-run \
	--quiet --wait --pipe --collect \
	--unit "domainlease-f0-c4-$run_id" \
	--service-type exec \
	--setenv F0_C4_GUARDIAN=systemd-v1 \
	--property User=root \
	--property Group=root \
	--property UMask=0077 \
	--property Delegate=yes \
	--property KillMode=control-group \
	--property RuntimeMaxSec=136800s \
	--property TimeoutStopSec=35s \
	--property SendSIGKILL=yes \
	--property StandardInput=null \
	--property MemoryLow=536870912 \
	--property OOMPolicy=kill \
	--property NoNewPrivileges=no \
	--property ProtectSystem=strict \
	--property ProtectHome=read-only \
	--property PrivateTmp=yes \
	--property PrivateDevices=no \
	--property ProtectControlGroups=no \
	--property ProtectKernelTunables=yes \
	--property ProtectKernelModules=yes \
	--property ProtectKernelLogs=yes \
	--property ProtectClock=yes \
	--property LockPersonality=yes \
	--property RestrictSUIDSGID=yes \
	--property RestrictRealtime=yes \
	--property RestrictAddressFamilies='AF_UNIX AF_NETLINK AF_ALG' \
	--property SystemCallArchitectures=native \
	--property CapabilityBoundingSet='CAP_SYS_ADMIN CAP_SYS_CHROOT CAP_SETUID CAP_SETGID CAP_SETPCAP CAP_MKNOD CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE CAP_FOWNER CAP_CHOWN CAP_KILL' \
	--property ReadWritePaths="$evidence_root $state_root/intents /run/domainlease-f0-c4" \
	--property "ExecStartPre=/usr/bin/python3 -I -S -B $guardian register --run-id $run_id --evidence-root $evidence_root" \
	--property "ExecStopPost=/usr/bin/python3 -I -S -B $guardian finalize --run-id $run_id" \
	-- "${command[@]}"
