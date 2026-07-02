#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Validate the N-156 no-behavior Linux scaffold rename.
#
# This is a targeted scheduler-subtree build validation. A full vmlinux build is
# useful later, but rename safety is decided by Kconfig resolution, Kbuild object
# selection, and the renamed scheduler scaffold compiling in both disabled and
# enabled configurations.

set -euo pipefail

ROOT=/media/nia/scsiusb/dev/linux-cap
LINUX="$ROOT/linux"
BUILD="$ROOT/build"
TOOLS="$ROOT/tools/apt-local/root"
LOG_DIR="$BUILD/logs"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/sched-exec-lease-rename-build-$STAMP.log"
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
	local out=$1
	shift

	mkdir -p "$out"
	make -C "$LINUX" O="$out" "$@"
}

build_off()
{
	local out="$BUILD/linux-l0-sched-exec-lease-off-targeted-x86_64"

	say "building CONFIG_SCHED_EXEC_LEASE=n x86_64_defconfig"
	run_make "$out" x86_64_defconfig
	"$LINUX/scripts/config" --file "$out/.config" --disable SCHED_EXEC_LEASE
	run_make "$out" olddefconfig

	say "checking CONFIG_SCHED_EXEC_LEASE=n evidence"
	grep -n "CONFIG_SCHED_EXEC_LEASE" "$out/.config" || true
	find "$out/kernel/sched" -name '*exec_lease*' -print 2>/dev/null || true

	say "building CONFIG_SCHED_EXEC_LEASE=n kernel/sched/built-in.a"
	run_make "$out" -j"$JOBS" kernel/sched/built-in.a
	test ! -e "$out/kernel/sched/exec_lease.o"
	test -f "$out/kernel/sched/built-in.a"
}

build_on()
{
	local out="$BUILD/linux-l0-sched-exec-lease-on-targeted-x86_64"

	say "building CONFIG_SCHED_EXEC_LEASE=y x86_64_defconfig"
	run_make "$out" x86_64_defconfig
	"$LINUX/scripts/config" --file "$out/.config" --enable EXPERT
	"$LINUX/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE
	run_make "$out" olddefconfig

	say "checking CONFIG_SCHED_EXEC_LEASE=y evidence"
	grep -n "CONFIG_SCHED_EXEC_LEASE" "$out/.config"
	find "$out/kernel/sched" -name '*exec_lease*' -print 2>/dev/null || true

	say "building CONFIG_SCHED_EXEC_LEASE=y kernel/sched/built-in.a"
	run_make "$out" -j"$JOBS" kernel/sched/built-in.a
	test -f "$out/kernel/sched/exec_lease.o"
	test -f "$out/kernel/sched/built-in.a"
}

check_source_terms()
{
	say "checking renamed Linux scaffold source terms"
	test ! -e "$LINUX/include/linux/capsched.h"
	test ! -e "$LINUX/kernel/sched/capsched.c"
	test -f "$LINUX/include/linux/sched_exec_lease.h"
	test -f "$LINUX/kernel/sched/exec_lease.c"
	! grep -RIn --exclude-dir=.git \
		-E "CONFIG_CAPSCHED|CapSched|CAPSCHED|capsched|RunCap|FrozenRunUse|SchedContext|DomainTag|HyperTag" \
		"$LINUX/init" "$LINUX/include/linux/sched_exec_lease.h" "$LINUX/kernel/sched"
	grep -RIn --exclude-dir=.git \
		-E "SCHED_EXEC_LEASE|sched_exec_lease|sched_exec_domain|sched_budget_ctx|sched_sealed_exec_token" \
		"$LINUX/init" "$LINUX/include/linux/sched_exec_lease.h" "$LINUX/kernel/sched"
}

say "SchedExecLease scaffold rename build validation started"
say "log: $LOG"
flex --version
bison --version | sed -n '1p'
test -f "$TOOLS/usr/include/gelf.h"
test -e "$TOOLS/usr/lib/x86_64-linux-gnu/libelf.so"
build_off
build_on
check_source_terms
say "SchedExecLease scaffold rename build validation completed"
