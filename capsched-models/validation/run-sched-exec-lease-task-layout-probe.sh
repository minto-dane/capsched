#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Build-only task_struct layout probe for SchedExecLease P2.
#
# This does not load a module and does not exercise runtime behavior. It asks
# the kernel build system to compile a tiny external object against the already
# prepared off/on build directories, then reads symbol sizes from the object:
#
#   sched_exec_task_struct_size_probe      sizeof(struct task_struct)
#   sched_exec_field_offset_plus_one_probe offsetof(task_struct, sched_exec)+1
#   sched_exec_field_size_probe            sizeof(task_struct.sched_exec)
#
# The off configuration must not emit the sched_exec field symbols.

set -euo pipefail

ROOT="${DOMAINLEASE_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="${LINUX:-$ROOT/linux}"
BUILD="$ROOT/build"
TOOLS="$ROOT/tools/apt-local/root"
LOG_DIR="$BUILD/logs"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$LOG_DIR/sched-exec-lease-task-layout-probe-$STAMP.log"
BUILD_TAG="${BUILD_TAG:-p2-n164-current}"
OUT_ROOT="$BUILD/task-layout/sched-exec-lease-$BUILD_TAG-$STAMP"

mkdir -p "$LOG_DIR" "$OUT_ROOT"
exec > >(tee -a "$LOG") 2>&1

export PATH="$TOOLS/usr/bin:$PATH"
export BISON_PKGDATADIR="$TOOLS/usr/share/bison"
export PKG_CONFIG_PATH="$TOOLS/usr/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export HOSTCFLAGS="-I$TOOLS/usr/include ${HOSTCFLAGS:-}"
export HOSTLDFLAGS="-L$TOOLS/usr/lib/x86_64-linux-gnu ${HOSTLDFLAGS:-}"
export LD_LIBRARY_PATH="$TOOLS/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

say()
{
	printf '[%s] %s\n' "$(date -Is)" "$*"
}

write_probe()
{
	local dir="$1"

	cat > "$dir/Makefile" <<'EOF'
obj-m += sched_exec_layout_probe.o
EOF

	cat > "$dir/sched_exec_layout_probe.c" <<'EOF'
#include <linux/sched.h>
#include <linux/module.h>
#include <linux/stddef.h>

char sched_exec_task_struct_size_probe[sizeof(struct task_struct)];

#ifdef CONFIG_SCHED_EXEC_LEASE
char sched_exec_field_offset_plus_one_probe[
	offsetof(struct task_struct, sched_exec) + 1
];
char sched_exec_field_size_probe[
	sizeof(((struct task_struct *)0)->sched_exec)
];
#else
char sched_exec_no_config_probe[1];
#endif

MODULE_LICENSE("GPL");
EOF
}

probe_mode()
{
	local mode="$1"
	local kbuild="$BUILD/linux-l0-sched-exec-lease-$mode-$BUILD_TAG-x86_64"
	local probe="$OUT_ROOT/$mode"
	local obj="$probe/sched_exec_layout_probe.o"
	local symbols="$probe/symbols.tsv"
	local config_state

	case "$mode" in
		off|on) ;;
		*) echo "bad mode: $mode" >&2; exit 2 ;;
	esac

	test -f "$kbuild/.config"
	test -f "$kbuild/vmlinux"

	mkdir -p "$probe"
	write_probe "$probe"

	say "building task layout probe object mode=$mode"
	make -C "$LINUX" O="$kbuild" M="$probe" sched_exec_layout_probe.o
	test -f "$obj"

	nm -S --size-sort "$obj" | awk '
		$4 ~ /sched_exec_/ {
			print $4 "\t0x" $2
		}
	' > "$symbols"

	config_state=$("$LINUX/scripts/config" --file "$kbuild/.config" --state SCHED_EXEC_LEASE || true)

	say "mode=$mode config=$config_state object=$obj symbols=$symbols"
	cat "$symbols"

	if [ "$mode" = "off" ]; then
		test "$config_state" = "undef"
		grep -q '^sched_exec_task_struct_size_probe	' "$symbols"
		grep -q '^sched_exec_no_config_probe	' "$symbols"
		! grep -q '^sched_exec_field_offset_plus_one_probe	' "$symbols"
		! grep -q '^sched_exec_field_size_probe	' "$symbols"
	else
		test "$config_state" = "y"
		grep -q '^sched_exec_task_struct_size_probe	' "$symbols"
		grep -q '^sched_exec_field_offset_plus_one_probe	' "$symbols"
		grep -q '^sched_exec_field_size_probe	' "$symbols"
		! grep -q '^sched_exec_no_config_probe	' "$symbols"
	fi
}

say "SchedExecLease task layout probe started"
say "log: $LOG"
say "output root: $OUT_ROOT"
probe_mode off
probe_mode on
say "SchedExecLease task layout probe completed"
