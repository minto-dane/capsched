#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
BUILD="${CAPSCHED_QEMU_BUILD:-$ROOT/build/linux-l0-capsched-on-qemu-x86_64}"
OUT_ROOT="${CAPSCHED_QEMU_OUT_ROOT:-$ROOT/build/qemu/slice0c-boot-smoke}"
TOOLS="$ROOT/tools/apt-local/root"
WORKLOAD_SRC="$ROOT/capsched/capsched-models/validation/workloads/slice0c_sched_workload.c"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
INITRD_DIR="$RUN_DIR/initramfs"
INITRD="$RUN_DIR/initramfs.cpio.gz"
WORKLOAD_BIN="$RUN_DIR/slice0c_sched_workload"
SERIAL_LOG="$RUN_DIR/serial.log"
COUNTS="$RUN_DIR/counts.tsv"
SUMMARY="$RUN_DIR/run-summary.txt"
JOBS="${JOBS:-8}"
QEMU_TIMEOUT="${CAPSCHED_QEMU_TIMEOUT:-180}"
QEMU_MEM="${CAPSCHED_QEMU_MEM:-1024M}"
QEMU_SMP="${CAPSCHED_QEMU_SMP:-2}"
WORKLOAD_MODE="${CAPSCHED_QEMU_WORKLOAD_MODE:-forkexec}"
WORKLOAD_ITERS="${CAPSCHED_QEMU_WORKLOAD_ITERS:-100}"

EVENTS="
sched/sched_waking
sched/sched_wakeup
sched/sched_wakeup_new
sched/sched_switch
sched/sched_migrate_task
sched/sched_process_fork
sched/sched_process_exec
sched/sched_process_exit
"

FUNCTIONS="
try_to_wake_up
ttwu_runnable
ttwu_do_activate
sched_ttwu_pending
__ttwu_queue_wakelist
ttwu_queue
wake_up_new_task
move_queued_task
enqueue_task
__pick_next_task
pick_next_task
__schedule
"
EVENT_LIST="$(printf '%s\n' "$EVENTS" | xargs)"
FUNCTION_LIST="$(printf '%s\n' "$FUNCTIONS" | xargs)"

mkdir -p "$RUN_DIR"

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

require()
{
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: missing required command: $1" >&2
		exit 1
	fi
}

copy_path()
{
	local src="$1"
	local dst="$INITRD_DIR$src"

	mkdir -p "$(dirname "$dst")"
	cp -L "$src" "$dst"
}

copy_elf_deps()
{
	local elf="$1"
	local dep

	while IFS= read -r dep; do
		[[ -n "$dep" ]] || continue
		[[ -e "$dep" ]] || continue
		copy_path "$dep"
	done < <(ldd "$elf" 2>/dev/null | awk '
		/=>[[:space:]]*\/.*\(/ { print $3 }
		/^[[:space:]]*\/.*\(/ { print $1 }
	')
}

build_kernel()
{
	say "preparing QEMU validation kernel config"
	mkdir -p "$BUILD"
	make -C "$LINUX" O="$BUILD" x86_64_defconfig
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable EXPERT
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable CAPSCHED
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable FUNCTION_TRACER
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable DYNAMIC_FTRACE
	make -C "$LINUX" O="$BUILD" olddefconfig

	say "building bzImage"
	make -C "$LINUX" O="$BUILD" -j"$JOBS" bzImage

	test -s "$BUILD/arch/x86/boot/bzImage"
}

build_workload()
{
	say "building guest workload"
	gcc -O2 -Wall -Wextra -pthread "$WORKLOAD_SRC" -o "$WORKLOAD_BIN"
}

make_initramfs()
{
	local app

	say "creating initramfs"
	rm -rf "$INITRD_DIR"
	mkdir -p "$INITRD_DIR"/{bin,sbin,proc,sys,dev,tmp,run,etc}

	cp /usr/bin/busybox "$INITRD_DIR/bin/busybox"
	chmod 0755 "$INITRD_DIR/bin/busybox"
	for app in sh mount mkdir cat echo grep uname sed awk wc true sleep seq poweroff reboot sync dmesg cut tr sort head tail; do
		ln -sf busybox "$INITRD_DIR/bin/$app"
	done

	cp "$WORKLOAD_BIN" "$INITRD_DIR/bin/slice0c_sched_workload"
	chmod 0755 "$INITRD_DIR/bin/slice0c_sched_workload"
	copy_elf_deps "$WORKLOAD_BIN"

	cp "$BUILD/.config" "$INITRD_DIR/etc/kernel.config"

	cat > "$INITRD_DIR/init" <<EOF
#!/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || mount -t tmpfs tmpfs /dev
mkdir -p /sys/kernel/tracing /sys/kernel/debug
mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null || true

TRACEFS=/sys/kernel/tracing
if [ ! -e "\$TRACEFS/tracing_on" ]; then
	mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true
	TRACEFS=/sys/kernel/debug/tracing
fi

echo "CAPSCHED_QEMU_BEGIN"
echo "KERNEL_UNAME \$(uname -a)"
echo "KERNEL_VERSION \$(cat /proc/version)"
grep '^CONFIG_CAPSCHED=' /etc/kernel.config || true
grep '^CONFIG_FUNCTION_TRACER=' /etc/kernel.config || true
echo "TRACEFS \$TRACEFS"

if [ ! -w "\$TRACEFS/tracing_on" ]; then
	echo "TRACEFS_UNAVAILABLE"
	echo "CAPSCHED_QEMU_END workload_ret=125"
	sync
	poweroff -f
fi

echo 0 > "\$TRACEFS/tracing_on"
[ -w "\$TRACEFS/current_tracer" ] && echo nop > "\$TRACEFS/current_tracer"
: > "\$TRACEFS/trace"
[ -w "\$TRACEFS/set_ftrace_filter" ] && : > "\$TRACEFS/set_ftrace_filter"

for event in $EVENT_LIST; do
	if [ -e "\$TRACEFS/events/\$event/enable" ]; then
		echo "EVENT_ENABLED \$event"
		echo 1 > "\$TRACEFS/events/\$event/enable"
	else
		echo "EVENT_MISSING \$event"
	fi
done

if [ -r "\$TRACEFS/available_filter_functions" ] && [ -w "\$TRACEFS/set_ftrace_filter" ]; then
	for func in $FUNCTION_LIST; do
		if grep -qw "\$func" "\$TRACEFS/available_filter_functions"; then
			echo "FUNCTION_ENABLED \$func"
			echo "\$func" >> "\$TRACEFS/set_ftrace_filter"
		else
			echo "FUNCTION_MISSING \$func"
		fi
	done
else
	echo "FUNCTION_FILTER_UNAVAILABLE"
	for func in $FUNCTION_LIST; do
		echo "FUNCTION_MISSING \$func"
	done
fi

if [ -r "\$TRACEFS/available_tracers" ] && grep -qw function "\$TRACEFS/available_tracers"; then
	echo function > "\$TRACEFS/current_tracer"
	echo "TRACER function"
else
	echo "TRACER event_only"
fi

echo 1 > "\$TRACEFS/tracing_on"
/bin/slice0c_sched_workload "$WORKLOAD_MODE" "$WORKLOAD_ITERS"
ret=\$?
echo 0 > "\$TRACEFS/tracing_on"

for target in $FUNCTION_LIST sched_waking sched_wakeup sched_wakeup_new sched_switch sched_migrate_task sched_process_fork sched_process_exec sched_process_exit; do
	count=\$(grep -c "\$target" "\$TRACEFS/trace" 2>/dev/null || true)
	echo "COUNT \$target \$count"
done

echo "WORKLOAD_RET \$ret"
echo "CAPSCHED_QEMU_END workload_ret=\$ret"
sync
poweroff -f
reboot -f
EOF
	chmod 0755 "$INITRD_DIR/init"
	busybox sh -n "$INITRD_DIR/init"

	(
		cd "$INITRD_DIR"
		find . -print0 | cpio --null -ov --format=newc 2>"$RUN_DIR/initramfs-cpio.log" | gzip -9 > "$INITRD"
	)
}

run_qemu()
{
	local kernel="$BUILD/arch/x86/boot/bzImage"
	local qemu=(qemu-system-x86_64)
	local status

	if [[ -w /dev/kvm ]]; then
		qemu+=(-enable-kvm -cpu host)
	else
		qemu+=(-cpu max)
	fi

	qemu+=(
		-m "$QEMU_MEM"
		-smp "$QEMU_SMP"
		-kernel "$kernel"
		-initrd "$INITRD"
		-append "console=ttyS0 panic=1 oops=panic nokaslr"
		-display none
		-serial stdio
		-monitor none
		-no-reboot
	)

	say "running QEMU"
	set +e
	timeout --foreground "$QEMU_TIMEOUT" "${qemu[@]}" | tee "$SERIAL_LOG"
	status=${PIPESTATUS[0]}
	set -e

	grep '^COUNT ' "$SERIAL_LOG" | awk '{ print $2 "\t" $3 }' > "$COUNTS" || true

	{
		echo "timestamp_utc=$STAMP"
		echo "linux_commit=$(git -C "$LINUX" rev-parse HEAD)"
		echo "linux_subject=$(git -C "$LINUX" log -1 --format=%s)"
		echo "build_dir=$BUILD"
		echo "kernel=$kernel"
		echo "initrd=$INITRD"
		echo "serial_log=$SERIAL_LOG"
		echo "counts=$COUNTS"
		echo "qemu_status=$status"
		echo "qemu_timeout_seconds=$QEMU_TIMEOUT"
		echo "workload_mode=$WORKLOAD_MODE"
		echo "workload_iters=$WORKLOAD_ITERS"
		if [[ -w /dev/kvm ]]; then
			echo "kvm=enabled"
		else
			echo "kvm=not_available"
		fi
	} > "$SUMMARY"

	if ! grep -q '^CAPSCHED_QEMU_BEGIN' "$SERIAL_LOG"; then
		echo "error: guest begin marker missing" >&2
		return 1
	fi
	if ! grep -q '^CAPSCHED_QEMU_END workload_ret=0' "$SERIAL_LOG"; then
		echo "error: guest end marker with workload_ret=0 missing" >&2
		return 1
	fi
	if ! grep -q '^CONFIG_CAPSCHED=y' "$SERIAL_LOG"; then
		echo "error: guest did not report CONFIG_CAPSCHED=y" >&2
		return 1
	fi
	if [[ "$status" != "0" ]]; then
		echo "error: qemu exited with status $status" >&2
		return 1
	fi
}

require qemu-system-x86_64
require busybox
require cpio
require gzip
require gcc
require ldd

say "Slice 0C QEMU boot smoke started"
say "run directory: $RUN_DIR"
build_kernel
build_workload
make_initramfs
run_qemu
say "Slice 0C QEMU boot smoke completed"
say "serial log: $SERIAL_LOG"
say "counts: $COUNTS"
