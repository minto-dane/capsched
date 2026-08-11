#!/usr/bin/env bash
set -euo pipefail

readonly state_root=/var/lib/domainlease-f0-c4
readonly toolchain_root=$state_root/toolchain
readonly image=$toolchain_root/candidate.erofs
readonly manifest=$toolchain_root/manifest.json
readonly mount_root=$toolchain_root/root
readonly progress=$toolchain_root/seal.progress
readonly mkfs_erofs=/usr/bin/mkfs.erofs
readonly fsck_erofs=/usr/bin/fsck.erofs
readonly tar=/usr/bin/tar

[[ $# -eq 0 ]] || {
	printf 'usage: %s\n' "$0" >&2
	exit 64
}
[[ ${EUID:-$(/usr/bin/id -u)} -eq 0 ]] || {
	printf 'error: root is required\n' >&2
	exit 77
}
for command in "$mkfs_erofs" "$fsck_erofs" "$tar" /usr/bin/flock \
	/usr/bin/find /usr/bin/sort /usr/bin/sha256sum /usr/bin/awk \
	/usr/bin/python3 /usr/bin/mount /usr/bin/mountpoint /usr/bin/findmnt \
	/usr/bin/umount /usr/bin/mktemp /bin/sync; do
	[[ -x $command ]] || {
		printf 'error: pinned tool missing: %s\n' "$command" >&2
		exit 1
	}
done

/usr/bin/install -d -o root -g root -m 0700 \
	"$state_root" "$toolchain_root" "$mount_root"

write_progress()
{
	local value=$1
	local text=$2
	local temporary=$toolchain_root/.seal-progress.$$
	printf '%s%% %s\n' "$value" "$text" > "$temporary"
	chmod 0600 "$temporary"
	/bin/sync -f "$temporary"
	mv -f -- "$temporary" "$progress"
	/bin/sync -f "$toolchain_root"
	printf '[progress] %s%% %s\n' "$value" "$text"
}

tree_manifest_sha256()
{
	local root=$1
	"$tar" \
		--sort=name \
		--format=posix \
		--pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
		--mtime=@0 \
		--numeric-owner \
		--acls --xattrs --selinux \
		-C "$root" -cf - . |
		/usr/bin/sha256sum | /usr/bin/awk '{print $1}'
}

exec 9>/var/lib/dpkg/lock-frontend
exec 8>/var/lib/dpkg/lock
exec 7>/var/cache/apt/archives/lock
/usr/bin/flock -n 9
/usr/bin/flock -n 8
/usr/bin/flock -n 7

if [[ -e $image || -e $manifest ]]; then
	[[ -f $image && ! -L $image && -f $manifest && ! -L $manifest ]] || {
		printf 'error: partial or aliased sealed toolchain state exists\n' >&2
		exit 1
	}
	write_progress 85 'reusing existing no-replace toolchain image'
else
	staging=$(/usr/bin/mktemp -d "$toolchain_root/.seal.XXXXXX")
	chmod 0700 "$staging"
	verification_mount=$staging/verified-root
	/usr/bin/install -d -o root -g root -m 0700 "$verification_mount"
	cleanup()
	{
		if /usr/bin/mountpoint -q "$verification_mount"; then
			/usr/bin/umount "$verification_mount" || true
		fi
		/bin/rm -rf -- "$staging"
	}
	trap cleanup EXIT HUP INT TERM
	image_staging=$staging/candidate.erofs
	manifest_staging=$staging/manifest.json
	write_progress 5 'package-manager locks acquired; recording source tree'
	before=$(tree_manifest_sha256 /usr)
	write_progress 15 'building deterministic EROFS image from /usr'
	"$mkfs_erofs" \
		-T 0 \
		-U 00000000-0000-0000-0000-000000000000 \
		-L F0C4TOOLCHAIN \
		-z lz4hc,12 \
		"$image_staging" /usr
	write_progress 60 'checking source stability and EROFS integrity'
	after=$(tree_manifest_sha256 /usr)
	[[ $before == "$after" ]] || {
		printf 'error: /usr changed while the toolchain image was built\n' >&2
		exit 1
	}
	"$fsck_erofs" "$image_staging"
	/usr/bin/mount -t erofs -o loop,ro,nodev,nosuid \
		"$image_staging" "$verification_mount"
	mounted_manifest_sha=$(tree_manifest_sha256 "$verification_mount")
	[[ $mounted_manifest_sha == "$before" ]] || {
		printf 'error: mounted EROFS tree differs from the complete source manifest\n' >&2
		exit 1
	}
	/usr/bin/umount "$verification_mount"
	image_sha=$(/usr/bin/sha256sum "$image_staging" | /usr/bin/awk '{print $1}')
	machine_sha=$(/usr/bin/sha256sum /etc/machine-id | /usr/bin/awk '{print $1}')
	os_sha=$(/usr/bin/sha256sum /etc/os-release | /usr/bin/awk '{print $1}')
	/usr/bin/python3 -I -S -B -c \
		'import json,sys; value={"schema_version":1,"artifact_id":"f0-c4-candidate-toolchain-image-v1","image_format":"erofs","image_sha256":sys.argv[1],"file_manifest_sha256":sys.argv[2],"source_machine_id_sha256":sys.argv[3],"source_os_release_sha256":sys.argv[4],"externally_authenticated":False}; sys.stdout.write(json.dumps(value,sort_keys=True,separators=(",",":"))+"\n")' \
		"$image_sha" "$mounted_manifest_sha" "$machine_sha" "$os_sha" \
		> "$manifest_staging"
	chown root:root "$image_staging" "$manifest_staging"
	chmod 0444 "$image_staging" "$manifest_staging"
	/bin/sync -f "$image_staging"
	/bin/sync -f "$manifest_staging"
	mv -n -- "$image_staging" "$image"
	mv -n -- "$manifest_staging" "$manifest"
	/bin/sync -f "$toolchain_root"
	trap - EXIT HUP INT TERM
	/bin/rm -rf -- "$staging"
	write_progress 85 'EROFS image and canonical manifest published'
fi

expected_sha=$(
	/usr/bin/python3 -I -S -B -c \
		'import json,sys; print(json.load(open(sys.argv[1],"r",encoding="utf-8"))["image_sha256"])' \
		"$manifest"
)
actual_sha=$(/usr/bin/sha256sum "$image" | /usr/bin/awk '{print $1}')
[[ $actual_sha == "$expected_sha" ]] || {
	printf 'error: sealed toolchain image digest differs from manifest\n' >&2
	exit 1
}
if /usr/bin/mountpoint -q "$mount_root"; then
	filesystem=$(/usr/bin/findmnt -n -o FSTYPE --target "$mount_root")
	[[ $filesystem == erofs ]] || {
		printf 'error: toolchain root is mounted with unexpected type: %s\n' \
			"$filesystem" >&2
		exit 1
	}
else
	/usr/bin/mount -t erofs -o loop,ro,nodev,nosuid "$image" "$mount_root"
fi
mounted_manifest_sha=$(tree_manifest_sha256 "$mount_root")
expected_manifest_sha=$(
	/usr/bin/python3 -I -S -B -c \
		'import json,sys; print(json.load(open(sys.argv[1],"r",encoding="utf-8"))["file_manifest_sha256"])' \
		"$manifest"
)
[[ $mounted_manifest_sha == "$expected_manifest_sha" ]] || {
	printf 'error: mounted EROFS tree differs from the sealed manifest\n' >&2
	exit 1
}
write_progress 100 'immutable EROFS toolchain mounted and digest-verified'
printf 'F0_C4_TOOLCHAIN_SEAL_PASS sha256=%s root=%s\n' \
	"$actual_sha" "$mount_root"
