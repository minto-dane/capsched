#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Run CapSched L0 Slice 0 build validation outside the Linux source tree.
# Intended to be launched by systemd --user so the chat session does not need
# to supervise the long kernel build.

set -euo pipefail

ROOT=/media/nia/scsiusb/dev/linux-cap
BASE_COMMIT=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
LINUX="$ROOT/linux"
BASE_TREE="$ROOT/linux-upstream-base"
BUILD="$ROOT/build"
TOOLS="$ROOT/tools/apt-local/root"
LOG_DIR="$BUILD/logs"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/l0-slice0-build-$STAMP.log"
JOBS="${JOBS:-8}"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1

export PATH="$TOOLS/usr/bin:$PATH"
export BISON_PKGDATADIR="$TOOLS/usr/share/bison"
export PKG_CONFIG_PATH="$TOOLS/usr/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export HOSTCFLAGS="-I$TOOLS/usr/include ${HOSTCFLAGS:-}"
export HOSTLDFLAGS="-L$TOOLS/usr/lib/x86_64-linux-gnu ${HOSTLDFLAGS:-}"
export LD_LIBRARY_PATH="$TOOLS/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

say()
{
	printf '\n[%s] %s\n' "$(date -Is)" "$*"
}

run_make()
{
	local tree=$1
	local out=$2
	shift 2

	mkdir -p "$out"
	make -C "$tree" O="$out" "$@"
}

ensure_local_tools()
{
	say "checking local build tools"
	flex --version
	bison --version | sed -n '1p'
	test -f "$TOOLS/usr/include/gelf.h"
	test -e "$TOOLS/usr/lib/x86_64-linux-gnu/libelf.so"
}

ensure_base_worktree()
{
	if ! git -C "$BASE_TREE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		say "creating upstream base worktree"
		git -C "$LINUX" worktree add --detach "$BASE_TREE" "$BASE_COMMIT"
	fi
}

build_baseline()
{
	local out="$BUILD/linux-l0-baseline-base-x86_64"

	say "building upstream baseline x86_64_defconfig"
	run_make "$BASE_TREE" "$out" x86_64_defconfig

	say "building upstream baseline vmlinux"
	run_make "$BASE_TREE" "$out" -j"$JOBS" vmlinux
}

build_capsched_off()
{
	local out="$BUILD/linux-l0-capsched-off-x86_64"

	say "building Slice 0A CONFIG_CAPSCHED=n x86_64_defconfig"
	run_make "$LINUX" "$out" x86_64_defconfig
	"$LINUX/scripts/config" --file "$out/.config" --disable CAPSCHED
	run_make "$LINUX" "$out" olddefconfig

	say "checking CONFIG_CAPSCHED=n evidence"
	grep -n "CONFIG_CAPSCHED" "$out/.config" || true
	find "$out" -name '*capsched*' -print

	say "building Slice 0A CONFIG_CAPSCHED=n vmlinux"
	run_make "$LINUX" "$out" -j"$JOBS" vmlinux
}

build_capsched_on()
{
	local out="$BUILD/linux-l0-capsched-on-x86_64"

	say "building Slice 0A CONFIG_CAPSCHED=y x86_64_defconfig"
	run_make "$LINUX" "$out" x86_64_defconfig
	"$LINUX/scripts/config" --file "$out/.config" --enable EXPERT
	"$LINUX/scripts/config" --file "$out/.config" --enable CAPSCHED
	run_make "$LINUX" "$out" olddefconfig

	say "checking CONFIG_CAPSCHED=y evidence"
	grep -n "CONFIG_CAPSCHED" "$out/.config"
	find "$out" -name '*capsched*' -print

	say "building Slice 0A CONFIG_CAPSCHED=y vmlinux"
	run_make "$LINUX" "$out" -j"$JOBS" vmlinux
}

say "CapSched L0 Slice 0 build validation started"
say "log: $LOG"
ensure_local_tools
ensure_base_worktree
build_baseline
build_capsched_off
build_capsched_on
say "CapSched L0 Slice 0 build validation completed"
