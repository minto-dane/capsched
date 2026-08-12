#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
contract=$script_dir/../../analysis/f0-c4-authority-disjoint-capture-contract-v1.json
readonly contract_sha256=0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d
readonly state_root=/var/lib/domainlease-f0-c4
readonly install_root=/usr/local
readonly reducer_user=domainlease-reducer
readonly reducer_uid=200011
readonly reducer_gid=200011
readonly gcc=/usr/bin/gcc
readonly git=/usr/bin/git
readonly install=/usr/bin/install
readonly mktemp=/usr/bin/mktemp
readonly sha256sum=/usr/bin/sha256sum
readonly awk=/usr/bin/awk
readonly sync=/bin/sync

usage()
{
	printf 'usage: %s [--build-only | --install]\n' "$0" >&2
}

mode=${1:---build-only}
if [[ $mode != --build-only && $mode != --install ]] || [[ $# -gt 1 ]]; then
	usage
	exit 64
fi
if [[ $mode == --install && ${EUID:-$(/usr/bin/id -u)} -ne 0 ]]; then
	printf 'error: --install requires root\n' >&2
	exit 77
fi

for command in "$gcc" "$git" "$install" "$mktemp" "$sha256sum" \
	"$awk" "$sync" /usr/bin/python3 /usr/bin/systemctl /usr/bin/getent \
	/usr/bin/id /usr/sbin/groupadd /usr/sbin/useradd; do
	[[ -x $command ]] || {
		printf 'error: pinned tool missing: %s\n' "$command" >&2
		exit 1
	}
done
[[ -f $contract && ! -L $contract ]] || {
	printf 'error: capture contract missing: %s\n' "$contract" >&2
	exit 1
}

cleanup_build=false
source_commit=DEVELOPER_BUILD_ONLY
if [[ $mode == --install ]]; then
	if [[ -n ${BUILD_DIR+x}${INSTALL_ROOT+x}${CONTRACT_PATH+x}${CC+x}${CFLAGS+x}${LDFLAGS+x} ]]; then
		printf 'error: build/install environment overrides are forbidden for root install\n' >&2
		exit 1
	fi
	repository=$($git -C "$script_dir" rev-parse --show-toplevel)
	[[ -z $($git -C "$repository" status --porcelain=v1 --untracked-files=all) ]] || {
		printf 'error: root install requires a clean reviewed commit\n' >&2
		exit 1
	}
	source_commit=$($git -C "$repository" rev-parse --verify HEAD^{commit})
	for source in f0_c4_capture_launcher.c f0_c4_capture_supervisor.py \
		f0_c4_guardian_finalize.py f0_c4_reduction_supervisor.py \
		f0_c4_post_run_reducer.py run-capture-systemd.sh \
		run-reduction-systemd.sh \
		seal-toolchain-image.sh domainlease-f0-c4-reconcile.service; do
		$git -C "$repository" ls-files --error-unmatch \
			"${script_dir#"$repository"/}/$source" >/dev/null
	done
	group_record=$(/usr/bin/getent group "$reducer_user" || true)
	group_by_gid=$(/usr/bin/getent group "$reducer_gid" || true)
	if [[ -z $group_record && -z $group_by_gid ]]; then
		/usr/sbin/groupadd --system --gid "$reducer_gid" "$reducer_user"
		group_record=$(/usr/bin/getent group "$reducer_user")
		group_by_gid=$(/usr/bin/getent group "$reducer_gid")
	fi
	[[ $group_record == "$group_by_gid" ]] || {
		printf 'error: reducer group name/GID collision\n' >&2
		exit 1
	}
	IFS=: read -r group_name _ group_id group_members <<<"$group_record"
	[[ $group_name == "$reducer_user" && $group_id == "$reducer_gid" && -z $group_members ]] || {
		printf 'error: reducer group identity differs\n' >&2
		exit 1
	}
	passwd_record=$(/usr/bin/getent passwd "$reducer_user" || true)
	passwd_by_uid=$(/usr/bin/getent passwd "$reducer_uid" || true)
	if [[ -z $passwd_record && -z $passwd_by_uid ]]; then
		/usr/sbin/useradd --system --uid "$reducer_uid" --gid "$reducer_gid" \
			--no-create-home --home-dir /nonexistent \
			--shell /usr/sbin/nologin "$reducer_user"
		passwd_record=$(/usr/bin/getent passwd "$reducer_user")
		passwd_by_uid=$(/usr/bin/getent passwd "$reducer_uid")
	fi
	[[ $passwd_record == "$passwd_by_uid" ]] || {
		printf 'error: reducer user name/UID collision\n' >&2
		exit 1
	}
	IFS=: read -r user_name _ user_id user_group _ user_home user_shell <<<"$passwd_record"
	[[ $user_name == "$reducer_user" && $user_id == "$reducer_uid" \
		&& $user_group == "$reducer_gid" && $user_home == /nonexistent \
		&& $user_shell == /usr/sbin/nologin ]] || {
		printf 'error: reducer passwd identity differs\n' >&2
		exit 1
	}
	[[ $(/usr/bin/id -G "$reducer_user") == "$reducer_gid" ]] || {
		printf 'error: reducer has supplementary groups\n' >&2
		exit 1
	}
	for ranges in /etc/subuid /etc/subgid; do
		if [[ -f $ranges ]] && "$awk" -F: -v identity="$reducer_uid" '
			NF == 3 && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ &&
			$2 <= identity && identity < $2 + $3 { found=1 }
			END { exit(found ? 0 : 1) }
		' "$ranges"; then
			printf 'error: reducer UID/GID is allocatable through %s\n' "$ranges" >&2
			exit 1
		fi
	done
	$install -d -o root -g root -m 0700 \
		"$state_root" "$state_root/install-staging" "$state_root/evidence" \
		"$state_root/intents" "$state_root/toolchain"
	build_dir=$($mktemp -d "$state_root/install-staging/build.XXXXXX")
	chmod 0700 "$build_dir"
	cleanup_build=true
else
	build_dir=${BUILD_DIR:-/tmp/domainlease-f0-c4-build-${UID:-$(/usr/bin/id -u)}}
	/bin/mkdir -p -m 0700 -- "$build_dir"
fi
binary=$build_dir/f0-c4-capture-launcher

cleanup()
{
	if [[ $cleanup_build == true ]]; then
		/bin/rm -rf -- "$build_dir"
	fi
}
trap cleanup EXIT HUP INT TERM

$gcc \
	-std=c17 -O2 -g \
	-Wall -Wextra -Werror -Wconversion -Wshadow -Wformat=2 \
	-fstack-protector-strong -D_FORTIFY_SOURCE=3 \
	-fPIE -pie -Wl,-z,relro,-z,now \
	-o "$binary" \
	"$script_dir/f0_c4_capture_launcher.c"

if [[ $mode == --install ]]; then
	libexec=$install_root/libexec/domainlease-f0-c4
	share=$install_root/share/domainlease-f0-c4
	unit=/etc/systemd/system/domainlease-f0-c4-reconcile.service
	canonical_contract=$build_dir/f0-c4-capture-contract-v1.json
	/usr/bin/python3 -I -S -B -c \
		'import json,sys; source=json.load(open(sys.argv[1],"r",encoding="utf-8")); open(sys.argv[2],"w",encoding="utf-8").write(json.dumps(source,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n")' \
		"$contract" "$canonical_contract"
	[[ $($sha256sum "$canonical_contract" | $awk '{print $1}') == "$contract_sha256" ]] || {
		printf 'error: canonical capture contract digest differs\n' >&2
		exit 1
	}
	chmod 0400 "$canonical_contract"
	$install -d -o root -g root -m 0755 "$libexec" "$share"
	$install -o root -g root -m 0755 "$binary" \
		"$libexec/f0-c4-capture-launcher"
	$install -o root -g root -m 0755 \
		"$script_dir/f0_c4_capture_supervisor.py" \
		"$libexec/f0-c4-capture-supervisor.py"
	$install -o root -g root -m 0755 \
		"$script_dir/f0_c4_guardian_finalize.py" \
		"$libexec/f0-c4-guardian-finalize.py"
	$install -o root -g root -m 0755 \
		"$script_dir/f0_c4_reduction_supervisor.py" \
		"$libexec/f0-c4-reduction-supervisor.py"
	$install -o root -g root -m 0755 \
		"$script_dir/f0_c4_post_run_reducer.py" \
		"$libexec/f0-c4-post-run-reducer.py"
	$install -o root -g root -m 0755 \
		"$script_dir/run-capture-systemd.sh" \
		"$libexec/run-capture-systemd.sh"
	$install -o root -g root -m 0755 \
		"$script_dir/run-reduction-systemd.sh" \
		"$libexec/run-reduction-systemd.sh"
	$install -o root -g root -m 0755 \
		"$script_dir/seal-toolchain-image.sh" \
		"$libexec/seal-toolchain-image.sh"
	$install -o root -g root -m 0444 "$canonical_contract" \
		"$share/f0-c4-capture-contract-v1.json"
	$install -o root -g root -m 0444 \
		"$script_dir/domainlease-f0-c4-reconcile.service" "$unit"

	manifest=$build_dir/installed-artifact-manifest-v1.txt
	{
		printf 'artifact_id=f0-c4-installed-artifact-manifest-v1\n'
		printf 'source_commit=%s\n' "$source_commit"
		for artifact in \
			"$libexec/f0-c4-capture-launcher" \
			"$libexec/f0-c4-capture-supervisor.py" \
			"$libexec/f0-c4-guardian-finalize.py" \
			"$libexec/f0-c4-reduction-supervisor.py" \
			"$libexec/f0-c4-post-run-reducer.py" \
			"$libexec/run-capture-systemd.sh" \
			"$libexec/run-reduction-systemd.sh" \
			"$libexec/seal-toolchain-image.sh" \
			"$share/f0-c4-capture-contract-v1.json" \
			"$unit"; do
			printf 'sha256=%s path=%s\n' \
				"$($sha256sum "$artifact" | $awk '{print $1}')" "$artifact"
		done
	} > "$manifest"
	chmod 0400 "$manifest"
	$sync -f "$manifest"
	$install -o root -g root -m 0444 "$manifest" \
		"$share/installed-artifact-manifest-v1.txt"
	for artifact in "$libexec/f0-c4-capture-launcher" \
		"$libexec/f0-c4-capture-supervisor.py" \
		"$libexec/f0-c4-guardian-finalize.py" \
		"$libexec/f0-c4-reduction-supervisor.py" \
		"$libexec/f0-c4-post-run-reducer.py" \
		"$libexec/run-capture-systemd.sh" \
		"$libexec/run-reduction-systemd.sh" \
		"$libexec/seal-toolchain-image.sh" \
		"$share/f0-c4-capture-contract-v1.json" \
		"$share/installed-artifact-manifest-v1.txt" "$unit" \
		"$libexec" "$share" /etc/systemd/system; do
		$sync -f "$artifact"
	done
	/usr/bin/systemctl daemon-reload
	/usr/bin/systemctl enable domainlease-f0-c4-reconcile.service >/dev/null
fi

printf 'F0_C4_CAPTURE_BUILD_PASS launcher_sha256=%s mode=%s source_commit=%s\n' \
	"$($sha256sum "$binary" | $awk '{print $1}')" \
	"$mode" "$source_commit"
