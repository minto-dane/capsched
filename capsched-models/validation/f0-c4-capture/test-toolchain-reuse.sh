#!/usr/bin/env bash
set -euo pipefail

[[ ${EUID:-$(/usr/bin/id -u)} -eq 0 ]] || {
	printf 'error: root is required\n' >&2
	exit 77
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
sealer=$script_dir/seal-toolchain-image.sh
image=/var/lib/domainlease-f0-c4/toolchain/candidate.erofs
manifest=/var/lib/domainlease-f0-c4/toolchain/manifest.json
mount_root=/var/lib/domainlease-f0-c4/toolchain/root
progress=/var/lib/domainlease-f0-c4/toolchain/seal.progress

[[ -x $sealer && -f $image && ! -L $image && -f $manifest && ! -L $manifest ]] || {
	printf 'error: reusable toolchain fixture is absent\n' >&2
	exit 1
}
before=$(/usr/bin/sha256sum "$image" | /usr/bin/awk '{print $1}')
"$sealer" >/dev/null
after=$(/usr/bin/sha256sum "$image" | /usr/bin/awk '{print $1}')
[[ $before == "$after" ]]
[[ $(/usr/bin/findmnt -n -o FSTYPE --target "$mount_root") == erofs ]]
[[ $(/usr/bin/findmnt -n -o OPTIONS --target "$mount_root") == *ro* ]]
[[ $(/usr/bin/cat "$progress") == 100%* ]]

printf 'F0_C4_TOOLCHAIN_REUSE_PASS cases=1 sha256=%s\n' "$after"
