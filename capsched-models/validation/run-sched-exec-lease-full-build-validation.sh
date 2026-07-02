#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Full vmlinux build validation for the DomainLease-Linux SchedExecLease L0
# scaffold. This is intentionally stronger than the targeted scheduler-subtree
# rename validation, but it still makes no runtime-enforcement claim.

set -euo pipefail

ROOT=/media/nia/scsiusb/dev/linux-cap
LINUX="${LINUX:-$ROOT/linux}"
BUILD="$ROOT/build"
TOOLS="$ROOT/tools/apt-local/root"
LOG_DIR="$BUILD/logs"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/sched-exec-lease-full-build-$STAMP.log"
JOBS="${JOBS:-8}"
BUILD_TAG="${BUILD_TAG:-full}"

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
	local out=$1
	shift

	mkdir -p "$out"
	make -C "$LINUX" O="$out" "$@"
}

build_mode()
{
	local mode=$1
	local out="$BUILD/linux-l0-sched-exec-lease-$mode-$BUILD_TAG-x86_64"

	say "building CONFIG_SCHED_EXEC_LEASE=$mode x86_64_defconfig"
	run_make "$out" x86_64_defconfig
	if [ "$mode" = "on" ]; then
		"$LINUX/scripts/config" --file "$out/.config" --enable EXPERT
		"$LINUX/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE
	else
		"$LINUX/scripts/config" --file "$out/.config" --disable SCHED_EXEC_LEASE
	fi
	run_make "$out" olddefconfig

	say "checking CONFIG_SCHED_EXEC_LEASE=$mode evidence"
	"$LINUX/scripts/config" --file "$out/.config" --state SCHED_EXEC_LEASE

	say "building CONFIG_SCHED_EXEC_LEASE=$mode vmlinux"
	run_make "$out" -j"$JOBS" vmlinux
	test -f "$out/vmlinux"

	if [ "$mode" = "on" ]; then
		test -f "$out/kernel/sched/exec_lease.o"
	else
		test ! -e "$out/kernel/sched/exec_lease.o"
	fi

	say "completed CONFIG_SCHED_EXEC_LEASE=$mode vmlinux"
}

say "SchedExecLease full vmlinux build validation started"
say "log: $LOG"
say "linux: $LINUX"
flex --version
bison --version | sed -n '1p'
test -f "$TOOLS/usr/include/gelf.h"
test -e "$TOOLS/usr/lib/x86_64-linux-gnu/libelf.so"
build_mode off
build_mode on
say "SchedExecLease full vmlinux build validation completed"
