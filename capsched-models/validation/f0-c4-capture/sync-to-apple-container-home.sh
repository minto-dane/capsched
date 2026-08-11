#!/usr/bin/env bash
set -euo pipefail

# Apple Container shares the physical macOS home directory. It does not follow
# a home-directory symlink onto an external volume into that host volume. Keep
# the large repository on the SSD and mirror only the small capsched source tree
# into a fixed, disposable home cache for VM-side builds and tests.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
capsched_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd -P)
readonly cache_base=${HOME}/Library/Caches/domainlease-linux-cap-vm
readonly destination=$cache_base/capsched

[[ -d $capsched_root/capsched-models && -d $capsched_root/capsched-ai ]] || {
	printf 'error: cannot locate the capsched source root: %s\n' "$capsched_root" >&2
	exit 1
}
command -v /usr/bin/rsync >/dev/null 2>&1 || {
	printf 'error: /usr/bin/rsync is required\n' >&2
	exit 1
}

/bin/mkdir -p -m 0700 -- "$cache_base"
/usr/bin/rsync -a --delete \
	--exclude .git \
	--exclude __pycache__ \
	--exclude '*.pyc' \
	--exclude build \
	-- "$capsched_root/" "$destination/"

printf 'F0_C4_APPLE_CONTAINER_SOURCE_SYNC_PASS path=%s bytes=' "$destination"
/usr/bin/du -sk "$destination" | /usr/bin/awk '{print $1 * 1024}'
