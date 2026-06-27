#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
LINUX="$ROOT/linux"
BUILD="${CAPSCHED_QEMU_BUILD:-$ROOT/build/linux-l0-capsched-on-qemu-x86_64}"
OUT_ROOT="${CAPSCHED_POSTEXEC_QEMU_OUT_ROOT:-$ROOT/build/qemu/post-exec-resource-trace}"
TOOLS="$ROOT/tools/apt-local/root"
WORKLOAD_SRC="$ROOT/capsched/capsched-models/validation/workloads/post_exec_resource_workload.c"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
INITRD_DIR="$RUN_DIR/initramfs"
INITRD="$RUN_DIR/initramfs.cpio.gz"
WORKLOAD_BIN="$RUN_DIR/post_exec_resource_workload"
SERIAL_LOG="$RUN_DIR/serial.log"
COUNTS="$RUN_DIR/counts.tsv"
CLASSIFICATION="$RUN_DIR/classification.tsv"
SUMMARY="$RUN_DIR/run-summary.txt"
JOBS="${JOBS:-8}"
QEMU_TIMEOUT="${CAPSCHED_QEMU_TIMEOUT:-180}"
QEMU_MEM="${CAPSCHED_QEMU_MEM:-1024M}"
QEMU_SMP="${CAPSCHED_QEMU_SMP:-2}"
REBUILD_KERNEL="${CAPSCHED_POSTEXEC_QEMU_REBUILD:-0}"

EVENTS="
raw_syscalls/sys_enter
raw_syscalls/sys_exit
sched/sched_prepare_exec
sched/sched_process_exec
io_uring/io_uring_create
io_uring/io_uring_register
io_uring/io_uring_file_get
io_uring/io_uring_submit_req
io_uring/io_uring_queue_async_work
io_uring/io_uring_task_work_run
io_uring/io_uring_complete
workqueue/workqueue_queue_work
workqueue/workqueue_execute_start
workqueue/workqueue_execute_end
sock/inet_sock_set_state
sock/sock_send_length
sock/sock_recv_length
sock/sk_data_ready
"

KPROBES="
cs_pe_do_close_on_exec do_close_on_exec
cs_pe_file_close_fd_locked file_close_fd_locked
cs_pe_filp_close filp_close
cs_pe_fd_install fd_install
cs_pe_do_dentry_open do_dentry_open
cs_pe_vfs_read vfs_read
cs_pe_vfs_write vfs_write
cs_pe_do_vfs_ioctl do_vfs_ioctl
cs_pe_security_mmap_file security_mmap_file
cs_pe_sock_alloc_file sock_alloc_file
cs_pe_do_accept do_accept
cs_pe_sock_recvmsg sock_recvmsg
cs_pe_anon_inode_getfile anon_inode_getfile
cs_pe_anon_inode_getfile_fmode anon_inode_getfile_fmode
cs_pe_anon_inode_create_getfile anon_inode_create_getfile
cs_pe___anon_inode_getfd __anon_inode_getfd
cs_pe_eventfd_signal_mask eventfd_signal_mask
cs_pe_eventfd_read eventfd_read
cs_pe_eventfd_write eventfd_write
cs_pe_timerfd_read_iter timerfd_read_iter
cs_pe_do_timerfd_settime do_timerfd_settime
cs_pe_do_epoll_ctl_file do_epoll_ctl_file
cs_pe_ep_insert ep_insert
cs_pe_ep_poll ep_poll
cs_pe_io_sqe_files_register io_sqe_files_register
cs_pe_io_file_get_fixed io_file_get_fixed
cs_pe_load_misc_binary load_misc_binary
"

EVENT_LIST="$(printf '%s\n' "$EVENTS" | xargs)"
KPROBE_NAME_LIST="$(printf '%s\n' "$KPROBES" | awk 'NF { print $1 }' | xargs)"

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
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable KPROBES
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable KPROBE_EVENTS
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable EPOLL
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable EVENTFD
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable IO_URING
	"$LINUX/scripts/config" --file "$BUILD/.config" --enable BINFMT_MISC
	make -C "$LINUX" O="$BUILD" olddefconfig

	say "building bzImage"
	make -C "$LINUX" O="$BUILD" -j"$JOBS" bzImage
}

ensure_kernel()
{
	if [[ "$REBUILD_KERNEL" == "1" || ! -s "$BUILD/arch/x86/boot/bzImage" ]]; then
		build_kernel
	fi
	test -s "$BUILD/arch/x86/boot/bzImage"
}

build_workload()
{
	say "building post-exec resource workload"
	gcc -O2 -Wall -Wextra "$WORKLOAD_SRC" -o "$WORKLOAD_BIN"
}

make_initramfs()
{
	local app

	say "creating initramfs"
	rm -rf "$INITRD_DIR"
	mkdir -p "$INITRD_DIR"/{bin,sbin,proc,sys,dev,tmp,run,etc}

	cp /usr/bin/busybox "$INITRD_DIR/bin/busybox"
	chmod 0755 "$INITRD_DIR/bin/busybox"
	for app in sh mount mkdir cat echo grep uname sed awk wc true sleep seq poweroff reboot sync dmesg cut tr sort uniq head tail; do
		ln -sf busybox "$INITRD_DIR/bin/$app"
	done

	cp "$WORKLOAD_BIN" "$INITRD_DIR/bin/post_exec_resource_workload"
	chmod 0755 "$INITRD_DIR/bin/post_exec_resource_workload"
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

echo "CAPSCHED_POSTEXEC_QEMU_BEGIN"
echo "KERNEL_UNAME \$(uname -a)"
echo "KERNEL_VERSION \$(cat /proc/version)"
grep '^CONFIG_CAPSCHED=' /etc/kernel.config || true
grep '^CONFIG_KPROBE_EVENTS=' /etc/kernel.config || true
grep '^CONFIG_IO_URING=' /etc/kernel.config || true
grep '^CONFIG_EVENTFD=' /etc/kernel.config || true
grep '^CONFIG_EPOLL=' /etc/kernel.config || true
echo "TRACEFS \$TRACEFS"

if [ ! -w "\$TRACEFS/tracing_on" ]; then
	echo "TRACEFS_UNAVAILABLE"
	echo "CAPSCHED_POSTEXEC_QEMU_END workload_ret=125"
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

if [ -w "\$TRACEFS/kprobe_events" ]; then
	: > "\$TRACEFS/kprobe_events" 2>/dev/null || true

	add_kprobe()
	{
		name="\$1"
		func="\$2"
		spec="p:capsched_pe/\$name \$func"
		if echo "\$spec" >> "\$TRACEFS/kprobe_events"; then
			echo "KPROBE_ADDED \$name \$func"
		else
			echo "KPROBE_ADD_FAILED \$name \$func"
		fi
	}

EOF
	while read -r name func; do
		[[ -n "$name" ]] || continue
		printf "\tadd_kprobe '%s' '%s'\n" "$name" "$func" >> "$INITRD_DIR/init"
	done <<< "$KPROBES"
	cat >> "$INITRD_DIR/init" <<EOF

	for event in $KPROBE_NAME_LIST; do
		if [ -e "\$TRACEFS/events/capsched_pe/\$event/enable" ]; then
			echo "KPROBE_ENABLED \$event"
			echo 1 > "\$TRACEFS/events/capsched_pe/\$event/enable"
		else
			echo "KPROBE_MISSING \$event"
		fi
	done
else
	echo "KPROBE_EVENTS_UNAVAILABLE"
fi

echo 1 > "\$TRACEFS/tracing_on"
/bin/post_exec_resource_workload
ret=\$?
echo 0 > "\$TRACEFS/tracing_on"

count_event()
{
	event="\$1"
	base="\${event##*/}"
	count=\$(grep -c "\$base:" "\$TRACEFS/trace" 2>/dev/null || true)
	echo "EVENT_COUNT \$event \$count"
}

for event in $EVENT_LIST; do
	count_event "\$event"
done

for event in $KPROBE_NAME_LIST; do
	count=\$(grep -c "\$event:" "\$TRACEFS/trace" 2>/dev/null || true)
	echo "KPROBE_COUNT \$event \$count"
done

grep '^CAPSCHED_POSTEXEC_' "\$TRACEFS/trace" 2>/dev/null | head -n 80 | sed 's/^/TRACE_MARKER_SAMPLE /' || true
grep 'capsched_pe:' "\$TRACEFS/trace" 2>/dev/null | head -n 80 | sed 's/^/KPROBE_SAMPLE /' || true

echo "WORKLOAD_RET \$ret"
echo "CAPSCHED_POSTEXEC_QEMU_END workload_ret=\$ret"
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

	{
		grep '^EVENT_COUNT ' "$SERIAL_LOG" | awk '{ print "event:" $2 "\t" $3 }'
		grep '^KPROBE_COUNT ' "$SERIAL_LOG" | awk '{ print "kprobe:" $2 "\t" $3 }'
		grep '^CAPSCHED_POSTEXEC_RESULT ' "$SERIAL_LOG" |
			awk '{ print "result:" $2 "/" $3 "\t" $0 }'
	} > "$COUNTS" || true

	{
		echo "timestamp_utc=$STAMP"
		echo "linux_commit=$(git -C "$LINUX" rev-parse HEAD)"
		echo "linux_subject=$(git -C "$LINUX" log -1 --format=%s)"
		echo "build_dir=$BUILD"
		echo "kernel=$kernel"
		echo "initrd=$INITRD"
		echo "serial_log=$SERIAL_LOG"
		echo "counts=$COUNTS"
		echo "classification=$CLASSIFICATION"
		echo "qemu_status=$status"
		echo "qemu_timeout_seconds=$QEMU_TIMEOUT"
		echo "rebuild_kernel=$REBUILD_KERNEL"
		if [[ -w /dev/kvm ]]; then
			echo "kvm=enabled"
		else
			echo "kvm=not_available"
		fi
	} > "$SUMMARY"

	if ! grep -q '^CAPSCHED_POSTEXEC_QEMU_BEGIN' "$SERIAL_LOG"; then
		echo "error: guest begin marker missing" >&2
		return 1
	fi
	if ! grep -q '^CAPSCHED_POSTEXEC_QEMU_END workload_ret=0' "$SERIAL_LOG"; then
		echo "error: guest end marker with workload_ret=0 missing" >&2
		return 1
	fi
	if ! grep -q '^CAPSCHED_POSTEXEC_END' "$SERIAL_LOG"; then
		echo "error: workload post-exec end marker missing" >&2
		return 1
	fi
	if [[ "$status" != "0" ]]; then
		echo "error: qemu exited with status $status" >&2
		return 1
	fi
}

count_for()
{
	local key="$1"
	awk -F '\t' -v key="$key" '$1 == key { print $2 + 0; found = 1 } END { if (!found) print 0 }' "$COUNTS"
}

has_result()
{
	local class="$1"
	grep -q "^CAPSCHED_POSTEXEC_RESULT $class " "$SERIAL_LOG"
}

has_non_skip_result()
{
	local class="$1"
	grep "^CAPSCHED_POSTEXEC_RESULT $class " "$SERIAL_LOG" | grep -vq 'status=skip'
}

classify_one()
{
	local class="$1"
	local evidence="$2"
	local probe="$3"
	local event="$4"
	local result_status="not_observed"
	local probe_count=0
	local event_count=0

	if has_result "$class"; then
		if has_non_skip_result "$class"; then
			result_status="partially_observed"
		fi
	fi

	if [[ -n "$probe" ]]; then
		probe_count="$(count_for "kprobe:$probe")"
	fi
	if [[ -n "$event" ]]; then
		event_count="$(count_for "event:$event")"
	fi

	if [[ "$result_status" == "partially_observed" ]]; then
		if [[ "$probe_count" -gt 0 || "$event_count" -gt 0 ]]; then
			result_status="observed"
		fi
	fi

	printf '%s\t%s\t%s\tprobe=%s:%s\tevent=%s:%s\n' \
		"$class" "$result_status" "$evidence" \
		"${probe:-none}" "$probe_count" "${event:-none}" "$event_count" \
		>> "$CLASSIFICATION"
}

classify_fixed()
{
	local class="$1"
	local status="$2"
	local evidence="$3"
	local probe="$4"
	local event="$5"

	printf '%s\t%s\t%s\tprobe=%s\tevent=%s\n' \
		"$class" "$status" "$evidence" "$probe" "$event" \
		>> "$CLASSIFICATION"
}

classify_results()
{
	{
		printf 'class\tclassification\tevidence\tprobe\tevent\n'
	} > "$CLASSIFICATION"

	classify_one "cloexec" "post-exec EBADF plus do_close_on_exec" \
		"cs_pe_do_close_on_exec" "sched/sched_process_exec"
	classify_one "regular" "read/write/mmap/ioctl post-exec effects" \
		"cs_pe_vfs_read" "raw_syscalls/sys_enter"
	classify_one "opath" "O_PATH inherited fd rejects read" \
		"cs_pe_do_dentry_open" "raw_syscalls/sys_enter"
	classify_one "socket" "socketpair send/recv and listening accept" \
		"cs_pe_do_accept" "sock/sock_send_length"
	if [[ "$(count_for "kprobe:cs_pe_anon_inode_getfile")" -gt 0 ||
	      "$(count_for "kprobe:cs_pe_anon_inode_getfile_fmode")" -gt 0 ||
	      "$(count_for "kprobe:cs_pe_anon_inode_create_getfile")" -gt 0 ]]; then
		classify_fixed "anonfd" "observed" \
			"anonymous fd creation observed for eventfd/timerfd/epoll/io_uring classes" \
			"cs_pe_anon_inode_getfile:$(count_for "kprobe:cs_pe_anon_inode_getfile"),cs_pe_anon_inode_getfile_fmode:$(count_for "kprobe:cs_pe_anon_inode_getfile_fmode"),cs_pe_anon_inode_create_getfile:$(count_for "kprobe:cs_pe_anon_inode_create_getfile")" \
			"none:0"
	else
		classify_fixed "anonfd" "not_observed" \
			"anonymous fd creation probes did not fire" \
			"cs_pe_anon_inode_getfile:0,cs_pe_anon_inode_getfile_fmode:0,cs_pe_anon_inode_create_getfile:0" \
			"none:0"
	fi
	if has_non_skip_result "eventfd"; then
		classify_fixed "eventfd" "partially_observed" \
			"read/write observed; kernel-held eventfd_signal_mask not observed" \
			"cs_pe_eventfd_read:$(count_for "kprobe:cs_pe_eventfd_read"),cs_pe_eventfd_signal_mask:$(count_for "kprobe:cs_pe_eventfd_signal_mask")" \
			"raw_syscalls/sys_enter:$(count_for "event:raw_syscalls/sys_enter")"
	else
		classify_one "eventfd" "post-exec read/write on inherited eventfd" \
			"cs_pe_eventfd_read" "raw_syscalls/sys_enter"
	fi
	classify_one "timerfd" "post-exec read and settime on inherited timerfd" \
		"cs_pe_timerfd_read_iter" "raw_syscalls/sys_enter"
	if has_non_skip_result "epoll"; then
		classify_fixed "epoll" "partially_observed" \
			"epoll_wait returned readiness; ep_insert/ep_poll probes missing or not kprobeable" \
			"cs_pe_do_epoll_ctl_file:$(count_for "kprobe:cs_pe_do_epoll_ctl_file"),cs_pe_ep_insert:$(count_for "kprobe:cs_pe_ep_insert"),cs_pe_ep_poll:$(count_for "kprobe:cs_pe_ep_poll")" \
			"raw_syscalls/sys_enter:$(count_for "event:raw_syscalls/sys_enter")"
	else
		classify_one "epoll" "pre-exec watched endpoint readiness delivered post-exec" \
			"cs_pe_do_epoll_ctl_file" "raw_syscalls/sys_enter"
	fi
	if has_non_skip_result "io_uring"; then
		classify_fixed "io_uring" "partially_observed" \
			"ring create/register/unregister/enter observed; fixed-file request consumption not observed" \
			"cs_pe_io_sqe_files_register:$(count_for "kprobe:cs_pe_io_sqe_files_register"),cs_pe_io_file_get_fixed:$(count_for "kprobe:cs_pe_io_file_get_fixed")" \
			"io_uring/io_uring_register:$(count_for "event:io_uring/io_uring_register"),io_uring/io_uring_file_get:$(count_for "event:io_uring/io_uring_file_get")"
	else
		classify_one "io_uring" "pre-exec ring and registered file, post-exec unregister/enter" \
			"cs_pe_io_sqe_files_register" "io_uring/io_uring_register"
	fi

	if grep -q '^CAPSCHED_POSTEXEC_RESULT execfd .*status=not_observed' "$SERIAL_LOG"; then
		printf 'execfd\tnot_observed\tbinfmt_misc execfd workload not included\tprobe=cs_pe_load_misc_binary:%s\tevent=none:0\n' \
			"$(count_for "kprobe:cs_pe_load_misc_binary")" >> "$CLASSIFICATION"
	else
		classify_one "execfd" "binfmt_misc execfd handoff" \
			"cs_pe_load_misc_binary" ""
	fi
}

require qemu-system-x86_64
require busybox
require cpio
require gzip
require gcc
require ldd

say "Post-exec resource QEMU trace started"
say "run directory: $RUN_DIR"
ensure_kernel
build_workload
make_initramfs
run_qemu
classify_results
say "Post-exec resource QEMU trace completed"
say "serial log: $SERIAL_LOG"
say "classification: $CLASSIFICATION"
