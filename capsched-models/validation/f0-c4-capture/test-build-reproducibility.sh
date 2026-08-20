#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(/usr/bin/git -C "$script_dir" rev-parse --show-toplevel)
commit=$(/usr/bin/git -C "$repo_root" rev-parse --verify HEAD^{commit})
tmp=$(/usr/bin/mktemp -d /tmp/f0-c4-reproducible-build.XXXXXX)

cleanup()
{
	/bin/rm -rf -- "$tmp"
}
trap cleanup EXIT HUP INT TERM

/bin/mkdir -m 0700 -- "$tmp/source-a" "$tmp/source-b"
/usr/bin/git -C "$repo_root" archive --format=tar \
	--output="$tmp/source.tar" "$commit"
/bin/tar -C "$tmp/source-a" -xf "$tmp/source.tar"
/bin/tar -C "$tmp/source-b" -xf "$tmp/source.tar"

tree=$tmp/source-a
build=$tmp/build-a
/bin/mkdir -m 0700 -- "$build"
(
	cd "$tree"
	BUILD_DIR=$build \
		./capsched-models/validation/f0-c4-capture/build-install.sh \
		--build-only >/dev/null
)

tree=$tmp/source-b
build=$tmp/build-b
/bin/mkdir -m 0700 -- "$build"
(
	cd /
	BUILD_DIR=$build \
		"$tree/capsched-models/validation/f0-c4-capture/build-install.sh" \
		--build-only >/dev/null
)

binary_a=$tmp/build-a/f0-c4-capture-launcher
binary_b=$tmp/build-b/f0-c4-capture-launcher
/usr/bin/cmp --silent "$binary_a" "$binary_b"
if /usr/bin/strings "$binary_a" | /usr/bin/grep -Fq -- "$tmp"; then
	printf 'error: build path leaked into launcher bytes\n' >&2
	exit 1
fi

printf 'F0_C4_REPRODUCIBLE_BUILD_PASS cases=1 sha256=%s\n' \
	"$(/usr/bin/sha256sum "$binary_a" | /usr/bin/awk '{print $1}')"
