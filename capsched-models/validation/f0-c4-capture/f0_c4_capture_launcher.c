#define _GNU_SOURCE

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <linux/audit.h>
#include <linux/capability.h>
#include <linux/filter.h>
#include <linux/if_alg.h>
#include <linux/mount.h>
#include <linux/sched.h>
#include <linux/seccomp.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysmacros.h>
#include <sys/timerfd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <net/if.h>

#ifndef CLONE_INTO_CGROUP
#define CLONE_INTO_CGROUP 0x200000000ULL
#endif
#ifndef CLOSE_RANGE_UNSHARE
#define CLOSE_RANGE_UNSHARE (1U << 1)
#endif
#ifndef P_PIDFD
#define P_PIDFD 3
#endif
#ifndef MOVE_MOUNT_F_EMPTY_PATH
#define MOVE_MOUNT_F_EMPTY_PATH 0x00000004
#endif

#define PREEXEC_MAGIC 0x43344350U
#define PREEXEC_OK 0U
#define PREEXEC_SETUP 1U
#define PREEXEC_EXEC 2U
#define PREEXEC_ENTERED 3U
#define ARRAY_LEN(value) (sizeof(value) / sizeof((value)[0]))

struct preexec_message {
	uint32_t magic;
	uint32_t stage;
	int32_t error_number;
	int32_t detail;
};

struct options {
	const char *cgroup_path;
	const char *sandbox_root;
	const char *scratch_path;
	const char *input_path;
	const char *toolchain_path;
	const char *stdout_path;
	const char *stderr_path;
	const char *preexec_path;
	const char *component;
	uid_t uid;
	gid_t gid;
	uint64_t deadline_seconds;
	uint64_t stdout_limit;
	uint64_t stderr_limit;
	uint64_t preexec_limit;
	char **command;
};

struct stream_capture {
	int read_fd;
	int output_fd;
	int hash_fd;
	uint64_t size;
	uint64_t limit;
	bool eof;
	bool exceeded;
	unsigned char digest[32];
};

static void usage(const char *program)
{
	fprintf(stderr,
		"usage: %s --cgroup PATH --sandbox-root PATH --input PATH "
		"--scratch PATH "
		"--toolchain-root PATH --stdout-file PATH --stderr-file PATH "
		"--preexec-file PATH --component ID "
		"--candidate-uid UID --candidate-gid GID --deadline-seconds N "
		"--stdout-limit N --stderr-limit N --preexec-limit N "
		"-- COMMAND [ARG ...]\n",
		program);
}

static void fail_errno(const char *operation)
{
	fprintf(stderr, "error: %s: %s\n", operation, strerror(errno));
	exit(70);
}

static bool safe_absolute_path(const char *value)
{
	size_t length;

	if (value == NULL)
		return false;
	length = strlen(value);
	return value != NULL && value[0] == '/' && strstr(value, "/../") == NULL &&
		strcmp(value, "/..") != 0 &&
		!(length >= 3 && strcmp(value + length - 3, "/..") == 0) &&
		strchr(value, '\n') == NULL &&
		strchr(value, '\r') == NULL;
}

static bool safe_identifier(const char *value)
{
	const unsigned char *cursor = (const unsigned char *)value;

	if (value == NULL || value[0] == '\0' || strlen(value) > 64)
		return false;
	for (; *cursor != '\0'; cursor++) {
		if (!((*cursor >= 'a' && *cursor <= 'z') ||
		      (*cursor >= 'A' && *cursor <= 'Z') ||
		      (*cursor >= '0' && *cursor <= '9') ||
		      *cursor == '-' || *cursor == '_'))
			return false;
	}
	return true;
}

static uint64_t parse_u64(const char *text, const char *label)
{
	char *end = NULL;
	unsigned long long value;

	errno = 0;
	value = strtoull(text, &end, 10);
	if (errno != 0 || end == text || *end != '\0') {
		fprintf(stderr, "error: invalid %s: %s\n", label, text);
		exit(64);
	}
	return (uint64_t)value;
}

static void parse_options(int argc, char **argv, struct options *options)
{
	int index;

	memset(options, 0, sizeof(*options));
	for (index = 1; index < argc; index++) {
		const char *argument = argv[index];
		const char *value;

		if (strcmp(argument, "--") == 0) {
			index++;
			break;
		}
		if (index + 1 >= argc) {
			usage(argv[0]);
			exit(64);
		}
		value = argv[++index];
		if (strcmp(argument, "--cgroup") == 0)
			options->cgroup_path = value;
		else if (strcmp(argument, "--sandbox-root") == 0)
			options->sandbox_root = value;
		else if (strcmp(argument, "--scratch") == 0)
			options->scratch_path = value;
		else if (strcmp(argument, "--input") == 0)
			options->input_path = value;
		else if (strcmp(argument, "--toolchain-root") == 0)
			options->toolchain_path = value;
		else if (strcmp(argument, "--stdout-file") == 0)
			options->stdout_path = value;
		else if (strcmp(argument, "--stderr-file") == 0)
			options->stderr_path = value;
		else if (strcmp(argument, "--preexec-file") == 0)
			options->preexec_path = value;
		else if (strcmp(argument, "--component") == 0)
			options->component = value;
		else if (strcmp(argument, "--candidate-uid") == 0)
			options->uid = (uid_t)parse_u64(value, "candidate UID");
		else if (strcmp(argument, "--candidate-gid") == 0)
			options->gid = (gid_t)parse_u64(value, "candidate GID");
		else if (strcmp(argument, "--deadline-seconds") == 0)
			options->deadline_seconds = parse_u64(value, "deadline");
		else if (strcmp(argument, "--stdout-limit") == 0)
			options->stdout_limit = parse_u64(value, "stdout limit");
		else if (strcmp(argument, "--stderr-limit") == 0)
			options->stderr_limit = parse_u64(value, "stderr limit");
		else if (strcmp(argument, "--preexec-limit") == 0)
			options->preexec_limit = parse_u64(value, "pre-exec limit");
		else {
			fprintf(stderr, "error: unknown option: %s\n", argument);
			exit(64);
		}
	}
	if (index >= argc)
		options->command = NULL;
	else
		options->command = &argv[index];
	if (!safe_absolute_path(options->cgroup_path) ||
	    !safe_absolute_path(options->sandbox_root) ||
	    !safe_absolute_path(options->scratch_path) ||
	    !safe_absolute_path(options->input_path) ||
	    !safe_absolute_path(options->toolchain_path) ||
	    !safe_absolute_path(options->stdout_path) ||
	    !safe_absolute_path(options->stderr_path) ||
	    !safe_absolute_path(options->preexec_path) ||
	    !safe_identifier(options->component) || options->uid == 0 ||
	    options->gid == 0 || options->deadline_seconds == 0 ||
	    options->deadline_seconds > 172800 || options->stdout_limit == 0 ||
	    options->stderr_limit == 0 || options->preexec_limit == 0 ||
	    options->preexec_limit > 16U * 1024U * 1024U ||
	    options->command == NULL ||
	    !safe_absolute_path(options->command[0])) {
		usage(argv[0]);
		exit(64);
	}
}

static uint64_t monotonic_ns(void)
{
	struct timespec now;

	if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
		fail_errno("clock_gettime");
	return (uint64_t)now.tv_sec * 1000000000ULL + (uint64_t)now.tv_nsec;
}

static int sys_open_tree(int dfd, const char *path, unsigned int flags)
{
	return (int)syscall(SYS_open_tree, dfd, path, flags);
}

static int sys_move_mount(int from_dfd, const char *from_path, int to_dfd,
			  const char *to_path, unsigned int flags)
{
	return (int)syscall(SYS_move_mount, from_dfd, from_path, to_dfd, to_path,
			    flags);
}

static int sys_mount_setattr(int dfd, const char *path, unsigned int flags,
			     struct mount_attr *attr, size_t size)
{
	return (int)syscall(SYS_mount_setattr, dfd, path, flags, attr, size);
}

static int sys_close_range(unsigned int first, unsigned int last,
			   unsigned int flags)
{
	return (int)syscall(SYS_close_range, first, last, flags);
}

static int make_hash_fd(void)
{
	struct sockaddr_alg address;
	int transform;
	int operation;

	transform = socket(AF_ALG, SOCK_SEQPACKET | SOCK_CLOEXEC, 0);
	if (transform < 0)
		return -1;
	memset(&address, 0, sizeof(address));
	address.salg_family = AF_ALG;
	strncpy((char *)address.salg_type, "hash", sizeof(address.salg_type) - 1);
	strncpy((char *)address.salg_name, "sha256", sizeof(address.salg_name) - 1);
	if (bind(transform, (struct sockaddr *)&address, sizeof(address)) != 0) {
		close(transform);
		return -1;
	}
	operation = accept4(transform, NULL, NULL, SOCK_CLOEXEC);
	close(transform);
	return operation;
}

static int write_all(int fd, const void *buffer, size_t length)
{
	const unsigned char *cursor = buffer;

	while (length > 0) {
		ssize_t written = write(fd, cursor, length);
		if (written < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		cursor += (size_t)written;
		length -= (size_t)written;
	}
	return 0;
}

static int read_exact(int fd, void *buffer, size_t length)
{
	unsigned char *cursor = buffer;

	while (length > 0) {
		ssize_t received = read(fd, cursor, length);
		if (received < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		if (received == 0) {
			errno = EPIPE;
			return -1;
		}
		cursor += (size_t)received;
		length -= (size_t)received;
	}
	return 0;
}

static void child_report(int fd, uint32_t stage, int error_number, int detail)
{
	struct preexec_message message = {
		.magic = PREEXEC_MAGIC,
		.stage = stage,
		.error_number = error_number,
		.detail = detail,
	};
	(void)write_all(fd, &message, sizeof(message));
}

static int ensure_directory(const char *path, mode_t mode)
{
	if (mkdir(path, mode) == 0)
		return 0;
	if (errno != EEXIST)
		return -1;
	struct stat status;
	if (lstat(path, &status) != 0 || !S_ISDIR(status.st_mode)) {
		errno = ENOTDIR;
		return -1;
	}
	return 0;
}

static int join_path(char *result, size_t result_size, const char *left,
		     const char *right)
{
	int count = snprintf(result, result_size, "%s/%s", left, right);
	if (count < 0 || (size_t)count >= result_size) {
		errno = ENAMETOOLONG;
		return -1;
	}
	return 0;
}

static int attach_read_only_tree(const char *source, const char *target)
{
	struct mount_attr attributes = {
		.attr_set = MOUNT_ATTR_RDONLY | MOUNT_ATTR_NOSUID | MOUNT_ATTR_NODEV,
	};
	int tree = sys_open_tree(AT_FDCWD, source,
				 OPEN_TREE_CLONE | OPEN_TREE_CLOEXEC | AT_RECURSIVE);

	if (tree < 0)
		return -1;
	if (sys_mount_setattr(tree, "", AT_EMPTY_PATH | AT_RECURSIVE,
			      &attributes, sizeof(attributes)) != 0 ||
	    sys_move_mount(tree, "", AT_FDCWD, target,
			   MOVE_MOUNT_F_EMPTY_PATH) != 0) {
		int saved = errno;
		close(tree);
		errno = saved;
		return -1;
	}
	close(tree);
	return 0;
}

static int attach_external_memory_tree(const char *source, const char *target)
{
	struct mount_attr attributes = {
		.attr_set = MOUNT_ATTR_NOSUID | MOUNT_ATTR_NODEV | MOUNT_ATTR_NOEXEC,
	};
	int tree = sys_open_tree(AT_FDCWD, source,
				 OPEN_TREE_CLONE | OPEN_TREE_CLOEXEC | AT_RECURSIVE);

	if (tree < 0)
		return -1;
	if (sys_mount_setattr(tree, "", AT_EMPTY_PATH | AT_RECURSIVE,
			      &attributes, sizeof(attributes)) != 0 ||
	    sys_move_mount(tree, "", AT_FDCWD, target,
			   MOVE_MOUNT_F_EMPTY_PATH) != 0) {
		int saved = errno;
		close(tree);
		errno = saved;
		return -1;
	}
	close(tree);
	return 0;
}

static int make_minimal_devices(const char *root)
{
	char path[4096];

	if (join_path(path, sizeof(path), root, "dev") != 0 ||
	    mount("tmpfs", path, "tmpfs", MS_NOSUID | MS_NOEXEC,
		  "mode=0755,size=1M,nr_inodes=32") != 0)
		return -1;
#define MAKE_DEVICE(name, major_number, minor_number, permissions)             \
	do {                                                                       \
		if (join_path(path, sizeof(path), root, "dev/" name) != 0 ||       \
		    mknod(path, S_IFCHR | (permissions),                            \
			  makedev((major_number), (minor_number))) != 0)             \
			return -1;                                                   \
	} while (0)
	MAKE_DEVICE("null", 1, 3, 0666);
	MAKE_DEVICE("zero", 1, 5, 0666);
	MAKE_DEVICE("random", 1, 8, 0666);
	MAKE_DEVICE("urandom", 1, 9, 0666);
#undef MAKE_DEVICE
	return 0;
}

static int prepare_sandbox(const struct options *options, int *detail)
{
	char path[4096];
	const char *directories[] = {
		"usr", "etc", "INPUT", "WORK", "proc", "tmp", "run", "dev",
	};

	*detail = 101;
	if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL) != 0)
		return -1;
	*detail = 102;
	if (mount("tmpfs", options->sandbox_root, "tmpfs", MS_NOSUID | MS_NODEV,
		  "mode=0755,size=32M,nr_inodes=4096") != 0)
		return -1;
	for (size_t index = 0; index < ARRAY_LEN(directories); index++) {
		*detail = 110 + (int)index;
		if (join_path(path, sizeof(path), options->sandbox_root,
			      directories[index]) != 0 ||
		    ensure_directory(path, 0755) != 0)
			return -1;
	}
	*detail = 120;
	if (join_path(path, sizeof(path), options->sandbox_root, "usr") != 0 ||
	    attach_read_only_tree(options->toolchain_path, path) != 0)
		return -1;
	*detail = 121;
	/* Keep /etc present but empty: host configuration is not captured input. */
	*detail = 122;
	if (join_path(path, sizeof(path), options->sandbox_root, "INPUT") != 0 ||
	    attach_read_only_tree(options->input_path, path) != 0)
		return -1;
	*detail = 123;
	if (join_path(path, sizeof(path), options->sandbox_root, "WORK") != 0 ||
	    attach_external_memory_tree(options->scratch_path, path) != 0)
		return -1;
	*detail = 124;
	if (join_path(path, sizeof(path), options->sandbox_root, "bin") != 0 ||
	    symlink("usr/bin", path) != 0)
		return -1;
	*detail = 125;
	if (join_path(path, sizeof(path), options->sandbox_root, "sbin") != 0 ||
	    symlink("usr/sbin", path) != 0)
		return -1;
	*detail = 126;
	if (join_path(path, sizeof(path), options->sandbox_root, "lib") != 0 ||
	    symlink("usr/lib", path) != 0)
		return -1;
	*detail = 127;
	if (join_path(path, sizeof(path), options->sandbox_root, "lib64") != 0 ||
	    symlink("usr/lib64", path) != 0)
		return -1;
	*detail = 128;
	if (join_path(path, sizeof(path), options->sandbox_root, "tmp") != 0 ||
	    mount("tmpfs", path, "tmpfs", MS_NOSUID | MS_NODEV,
		  "mode=1777,size=1G,nr_inodes=262144") != 0)
		return -1;
	*detail = 129;
	if (join_path(path, sizeof(path), options->sandbox_root, "run") != 0 ||
	    mount("tmpfs", path, "tmpfs", MS_NOSUID | MS_NODEV | MS_NOEXEC,
		  "mode=0755,size=16M,nr_inodes=4096") != 0)
		return -1;
	*detail = 130;
	if (make_minimal_devices(options->sandbox_root) != 0)
		return -1;
	*detail = 131;
	if (join_path(path, sizeof(path), options->sandbox_root, "proc") != 0 ||
	    mount("proc", path, "proc", MS_NOSUID | MS_NODEV | MS_NOEXEC,
		  "hidepid=2") != 0)
		return -1;
	*detail = 132;
	if (chroot(options->sandbox_root) != 0 || chdir("/") != 0)
		return -1;
	*detail = 0;
	return 0;
}

static int drop_privileges(uid_t uid, gid_t gid)
{
	struct __user_cap_header_struct header;
	struct __user_cap_data_struct data[2];
	struct rlimit limit;

	for (int capability = 0; capability <= CAP_LAST_CAP; capability++) {
		if (prctl(PR_CAPBSET_DROP, capability, 0, 0, 0) != 0 &&
		    errno != EINVAL)
			return -1;
	}
	if (setgroups(0, NULL) != 0 || setresgid(gid, gid, gid) != 0 ||
	    setresuid(uid, uid, uid) != 0)
		return -1;
	memset(&header, 0, sizeof(header));
	memset(data, 0, sizeof(data));
	header.version = _LINUX_CAPABILITY_VERSION_3;
	header.pid = 0;
	if (syscall(SYS_capset, &header, data) != 0)
		return -1;
	limit.rlim_cur = limit.rlim_max = 256;
	if (setrlimit(RLIMIT_NOFILE, &limit) != 0)
		return -1;
	limit.rlim_cur = limit.rlim_max = 0;
	if (setrlimit(RLIMIT_CORE, &limit) != 0)
		return -1;
	if (prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0) != 0 ||
	    prctl(PR_SET_DUMPABLE, 0, 0, 0, 0) != 0 ||
	    prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0)
		return -1;
	return 0;
}

static int install_seccomp_policy(void)
{
	int denied[64];
	size_t denied_count = 0;
	struct sock_filter filter[5 + 2 * 64];
	size_t cursor = 0;

#define DENY_SYSCALL(name) denied[denied_count++] = __NR_##name
	DENY_SYSCALL(mount);
	DENY_SYSCALL(umount2);
	DENY_SYSCALL(pivot_root);
	DENY_SYSCALL(chroot);
	DENY_SYSCALL(unshare);
	DENY_SYSCALL(setns);
	DENY_SYSCALL(ptrace);
	DENY_SYSCALL(bpf);
	DENY_SYSCALL(perf_event_open);
	DENY_SYSCALL(userfaultfd);
	DENY_SYSCALL(kexec_load);
#ifdef __NR_kexec_file_load
	DENY_SYSCALL(kexec_file_load);
#endif
	DENY_SYSCALL(init_module);
	DENY_SYSCALL(finit_module);
	DENY_SYSCALL(delete_module);
	DENY_SYSCALL(reboot);
	DENY_SYSCALL(swapon);
	DENY_SYSCALL(swapoff);
	DENY_SYSCALL(keyctl);
	DENY_SYSCALL(add_key);
	DENY_SYSCALL(request_key);
#ifdef __NR_open_tree
	DENY_SYSCALL(open_tree);
#endif
#ifdef __NR_move_mount
	DENY_SYSCALL(move_mount);
#endif
#ifdef __NR_fsopen
	DENY_SYSCALL(fsopen);
#endif
#ifdef __NR_fsconfig
	DENY_SYSCALL(fsconfig);
#endif
#ifdef __NR_fsmount
	DENY_SYSCALL(fsmount);
#endif
#ifdef __NR_fspick
	DENY_SYSCALL(fspick);
#endif
#ifdef __NR_mount_setattr
	DENY_SYSCALL(mount_setattr);
#endif
#undef DENY_SYSCALL

	filter[cursor++] = (struct sock_filter)BPF_STMT(
		BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch));
#if defined(__aarch64__)
	filter[cursor++] = (struct sock_filter)BPF_JUMP(
		BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_AARCH64, 1, 0);
#elif defined(__x86_64__)
	filter[cursor++] = (struct sock_filter)BPF_JUMP(
		BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_X86_64, 1, 0);
#else
#error unsupported architecture
#endif
	filter[cursor++] = (struct sock_filter)BPF_STMT(
		BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS);
	filter[cursor++] = (struct sock_filter)BPF_STMT(
		BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr));
	for (size_t index = 0; index < denied_count; index++) {
		filter[cursor++] = (struct sock_filter)BPF_JUMP(
			BPF_JMP | BPF_JEQ | BPF_K, (uint32_t)denied[index], 0, 1);
		filter[cursor++] = (struct sock_filter)BPF_STMT(
			BPF_RET | BPF_K, SECCOMP_RET_ERRNO | (EPERM & SECCOMP_RET_DATA));
	}
	filter[cursor++] = (struct sock_filter)BPF_STMT(
		BPF_RET | BPF_K, SECCOMP_RET_ALLOW);
	struct sock_fprog program = {
		.len = (unsigned short)cursor,
		.filter = filter,
	};
	return prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &program);
}

static void close_fd_interval(unsigned int first, unsigned int last)
{
	if (first > last)
		return;
	if (sys_close_range(first, last, 0) == 0)
		return;
	for (unsigned int fd = first; fd <= last && fd < 1048576U; fd++)
		close((int)fd);
}

static int close_untrusted_fds_except(int first_keep, int second_keep,
				      int third_keep)
{
	int keep[] = {first_keep, second_keep, third_keep};

	for (size_t left = 0; left < ARRAY_LEN(keep); left++) {
		if (keep[left] < 3)
			return -1;
		for (size_t right = left + 1; right < ARRAY_LEN(keep); right++) {
			if (keep[left] == keep[right])
				return -1;
			if (keep[left] > keep[right]) {
				int temporary = keep[left];
				keep[left] = keep[right];
				keep[right] = temporary;
			}
		}
	}
	close_fd_interval(3, (unsigned int)keep[0] - 1);
	close_fd_interval((unsigned int)keep[0] + 1,
			  (unsigned int)keep[1] - 1);
	close_fd_interval((unsigned int)keep[1] + 1,
			  (unsigned int)keep[2] - 1);
	close_fd_interval((unsigned int)keep[2] + 1, ~0U);
	return 0;
}

struct bounded_writer {
	int fd;
	uint64_t size;
	uint64_t limit;
};

static int bounded_write(struct bounded_writer *writer, const void *raw,
			 size_t size)
{
	if ((uint64_t)size > writer->limit - writer->size) {
		errno = EFBIG;
		return -1;
	}
	if (write_all(writer->fd, raw, size) != 0)
		return -1;
	writer->size += (uint64_t)size;
	return 0;
}

static int bounded_text(struct bounded_writer *writer, const char *text)
{
	return bounded_write(writer, text, strlen(text));
}

static int copy_attestation_file(struct bounded_writer *writer,
				 const char *section, const char *path)
{
	unsigned char buffer[16384];
	int fd;

	if (bounded_text(writer, section) != 0)
		return -1;
	fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
	if (fd < 0)
		return -1;
	for (;;) {
		ssize_t count = read(fd, buffer, sizeof(buffer));
		if (count > 0) {
			if (bounded_write(writer, buffer, (size_t)count) != 0) {
				int saved = errno;
				close(fd);
				errno = saved;
				return -1;
			}
			continue;
		}
		if (count == 0)
			break;
		if (errno == EINTR)
			continue;
		int saved = errno;
		close(fd);
		errno = saved;
		return -1;
	}
	if (close(fd) != 0 || bounded_text(writer, "\n") != 0)
		return -1;
	return 0;
}

static int attest_namespaces(struct bounded_writer *writer)
{
	const char *names[] = {"mnt", "pid", "ipc", "uts", "net", "cgroup"};
	char line[512];

	if (bounded_text(writer, "[namespace_ids]\n") != 0)
		return -1;
	for (size_t index = 0; index < ARRAY_LEN(names); index++) {
		char path[128];
		char target[256];
		ssize_t count;
		int printed;

		if (snprintf(path, sizeof(path), "/proc/self/ns/%s", names[index]) < 0)
			return -1;
		count = readlink(path, target, sizeof(target) - 1);
		if (count < 0)
			return -1;
		target[count] = '\0';
		printed = snprintf(line, sizeof(line), "%s=%s\n", names[index], target);
		if (printed < 0 || (size_t)printed >= sizeof(line) ||
		    bounded_write(writer, line, (size_t)printed) != 0)
			return -1;
	}
	return 0;
}

static int attest_fd_table(struct bounded_writer *writer)
{
	char line[4608];

	if (bounded_text(writer, "[fd_table]\n") != 0)
		return -1;
	for (int fd = 0; fd < 256; fd++) {
		char path[64];
		char target[4096];
		ssize_t count;
		int descriptor_flags;
		int printed;

		if (snprintf(path, sizeof(path), "/proc/self/fd/%d", fd) < 0)
			return -1;
		count = readlink(path, target, sizeof(target) - 1);
		if (count < 0) {
			if (errno == ENOENT)
				continue;
			return -1;
		}
		target[count] = '\0';
		descriptor_flags = fcntl(fd, F_GETFD);
		if (descriptor_flags < 0)
			return -1;
		printed = snprintf(line, sizeof(line),
				   "fd=%d cloexec=%d target=%s\n", fd,
				   (descriptor_flags & FD_CLOEXEC) != 0, target);
		if (printed < 0 || (size_t)printed >= sizeof(line) ||
		    bounded_write(writer, line, (size_t)printed) != 0)
			return -1;
	}
	return 0;
}

static int attest_interfaces(struct bounded_writer *writer)
{
	struct if_nameindex *interfaces;
	int socket_fd;
	char line[256];

	if (bounded_text(writer, "[interface_inventory]\n") != 0)
		return -1;
	interfaces = if_nameindex();
	if (interfaces == NULL)
		return -1;
	socket_fd = socket(AF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	if (socket_fd < 0) {
		if_freenameindex(interfaces);
		return -1;
	}
	for (struct if_nameindex *item = interfaces; item->if_index != 0; item++) {
		struct ifreq request;
		int printed;

		memset(&request, 0, sizeof(request));
		if (strlen(item->if_name) >= sizeof(request.ifr_name)) {
			errno = ENAMETOOLONG;
			close(socket_fd);
			if_freenameindex(interfaces);
			return -1;
		}
		strcpy(request.ifr_name, item->if_name);
		if (ioctl(socket_fd, SIOCGIFFLAGS, &request) != 0) {
			int saved = errno;
			close(socket_fd);
			if_freenameindex(interfaces);
			errno = saved;
			return -1;
		}
		printed = snprintf(line, sizeof(line),
				   "index=%u name=%s flags=0x%x up=%d loopback=%d\n",
				   item->if_index, item->if_name,
				   (unsigned int)(unsigned short)request.ifr_flags,
				   (request.ifr_flags & IFF_UP) != 0,
				   (request.ifr_flags & IFF_LOOPBACK) != 0);
		if (printed < 0 || (size_t)printed >= sizeof(line) ||
		    bounded_write(writer, line, (size_t)printed) != 0) {
			close(socket_fd);
			if_freenameindex(interfaces);
			return -1;
		}
	}
	if (close(socket_fd) != 0) {
		if_freenameindex(interfaces);
		return -1;
	}
	if_freenameindex(interfaces);
	return 0;
}

static int write_preexec_attestation(int fd, uint64_t limit)
{
	struct bounded_writer writer = {.fd = fd, .size = 0, .limit = limit};

	if (bounded_text(&writer, "F0_C4_PREEXEC_ATTESTATION_V1\n") != 0 ||
	    copy_attestation_file(&writer, "[status]\n", "/proc/self/status") != 0 ||
	    copy_attestation_file(&writer, "[mountinfo]\n", "/proc/self/mountinfo") != 0 ||
	    copy_attestation_file(&writer, "[cgroup_identity]\n", "/proc/self/cgroup") != 0 ||
	    attest_namespaces(&writer) != 0 || attest_fd_table(&writer) != 0 ||
	    attest_interfaces(&writer) != 0 ||
	    bounded_text(&writer, "F0_C4_PREEXEC_ATTESTATION_END\n") != 0)
		return -1;
	return 0;
}

static void child_main(const struct options *options, int stdout_write,
		       int stderr_write, int status_write, int release_read,
		       int attestation_write)
{
	char *environment[] = {
		"F0_C4_EXACT_STORE_DIR=/WORK",
		"PATH=/usr/bin:/bin",
		"PYTHONPATH=INPUT",
		"PYTHONDONTWRITEBYTECODE=1",
		"PYTHONHASHSEED=0",
		NULL,
	};
	char hostname[80];
	unsigned char release;
	int null_fd;
	int setup_detail = 0;

	child_report(status_write, PREEXEC_ENTERED, 0, 0);
	null_fd = open("/dev/null", O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
	if (null_fd < 0 || dup2(null_fd, STDIN_FILENO) < 0 ||
	    (null_fd > STDERR_FILENO && close(null_fd) != 0) ||
	    dup2(stdout_write, STDOUT_FILENO) < 0 ||
	    dup2(stderr_write, STDERR_FILENO) < 0 ||
	    fcntl(status_write, F_SETFD, FD_CLOEXEC) != 0 ||
	    fcntl(release_read, F_SETFD, FD_CLOEXEC) != 0 ||
	    fcntl(attestation_write, F_SETFD, FD_CLOEXEC) != 0 ||
	    close_untrusted_fds_except(status_write, release_read,
				       attestation_write) != 0) {
		child_report(status_write, PREEXEC_SETUP, errno, 90);
		_exit(127);
	}
	umask(0077);
	setup_detail = 100;
	if (snprintf(hostname, sizeof(hostname), "f0-c4-%s", options->component) < 0 ||
	    sethostname(hostname, strlen(hostname)) != 0 ||
	    prepare_sandbox(options, &setup_detail) != 0) {
		child_report(status_write, PREEXEC_SETUP, errno, setup_detail);
		_exit(126);
	}
	setup_detail = 140;
	if (drop_privileges(options->uid, options->gid) != 0) {
		child_report(status_write, PREEXEC_SETUP, errno, setup_detail);
		_exit(126);
	}
	setup_detail = 150;
	if (install_seccomp_policy() != 0) {
		child_report(status_write, PREEXEC_SETUP, errno, setup_detail);
		_exit(126);
	}
	setup_detail = 151;
	if (write_preexec_attestation(attestation_write,
				      options->preexec_limit) != 0 ||
	    close(attestation_write) != 0) {
		child_report(status_write, PREEXEC_SETUP, errno, setup_detail);
		_exit(126);
	}
	child_report(status_write, PREEXEC_OK, 0, 0);
	if (read_exact(release_read, &release, 1) != 0 || release != 0x47)
		_exit(125);
	close(release_read);
	execve(options->command[0], options->command, environment);
	child_report(status_write, PREEXEC_EXEC, errno, 160);
	_exit(127);
}

static int set_nonblocking(int fd)
{
	int flags = fcntl(fd, F_GETFL);
	if (flags < 0)
		return -1;
	return fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

static int open_output(const char *path)
{
	return open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
		    0400);
}

static int capture_attestation(int read_fd, const char *path, uint64_t limit,
			       uint64_t *captured_size,
			       unsigned char digest[32], bool *exceeded)
{
	unsigned char buffer[16384];
	int output_fd = -1;
	int hash_fd = -1;
	int result = -1;

	*captured_size = 0;
	*exceeded = false;
	output_fd = open(path, O_WRONLY | O_APPEND | O_CLOEXEC | O_NOFOLLOW);
	hash_fd = make_hash_fd();
	if (output_fd < 0 || hash_fd < 0)
		goto out;
	for (;;) {
		ssize_t count = read(read_fd, buffer, sizeof(buffer));
		if (count > 0) {
			uint64_t next = *captured_size + (uint64_t)count;
			if (*exceeded || next > limit) {
				*exceeded = true;
				continue;
			}
			if (write_all(output_fd, buffer, (size_t)count) != 0 ||
			    send(hash_fd, buffer, (size_t)count, MSG_MORE) != count)
				goto out;
			*captured_size = next;
			continue;
		}
		if (count == 0)
			break;
		if (errno == EINTR)
			continue;
		goto out;
	}
	if (send(hash_fd, "", 0, 0) != 0 ||
	    read_exact(hash_fd, digest, 32) != 0 || fchmod(output_fd, 0444) != 0 ||
	    fsync(output_fd) != 0)
		goto out;
	result = *exceeded ? -1 : 0;
	if (*exceeded)
		errno = EFBIG;
out:
	{
		int saved = errno;
		if (output_fd >= 0)
			close(output_fd);
		if (hash_fd >= 0)
			close(hash_fd);
		errno = saved;
	}
	return result;
}

static int stream_read_available(struct stream_capture *stream)
{
	unsigned char buffer[65536];

	for (;;) {
		ssize_t count = read(stream->read_fd, buffer, sizeof(buffer));
		if (count > 0) {
			uint64_t next = stream->size + (uint64_t)count;
			if (next > stream->limit) {
				stream->exceeded = true;
				return 0;
			}
			if (write_all(stream->output_fd, buffer, (size_t)count) != 0 ||
			    send(stream->hash_fd, buffer, (size_t)count, MSG_MORE) != count)
				return -1;
			stream->size = next;
			continue;
		}
		if (count == 0) {
			stream->eof = true;
			return 0;
		}
		if (errno == EINTR)
			continue;
		if (errno == EAGAIN || errno == EWOULDBLOCK)
			return 0;
		return -1;
	}
}

static int finish_stream(struct stream_capture *stream)
{
	if (send(stream->hash_fd, "", 0, 0) != 0)
		return -1;
	if (read_exact(stream->hash_fd, stream->digest, sizeof(stream->digest)) != 0)
		return -1;
	if (fchmod(stream->output_fd, 0444) != 0 || fsync(stream->output_fd) != 0)
		return -1;
	return 0;
}

static void digest_hex(const unsigned char digest[32], char output[65])
{
	static const char digits[] = "0123456789abcdef";
	for (size_t index = 0; index < 32; index++) {
		output[index * 2] = digits[digest[index] >> 4];
		output[index * 2 + 1] = digits[digest[index] & 0x0f];
	}
	output[64] = '\0';
}

static int write_cgroup_kill(int cgroup_fd)
{
	int fd;

	fd = openat(cgroup_fd, "cgroup.kill", O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
	if (fd < 0)
		return -1;
	int result = write_all(fd, "1", 1);
	int saved = errno;
	close(fd);
	errno = saved;
	return result;
}

static int cgroup_populated(int cgroup_fd, bool *populated)
{
	char buffer[1024];
	ssize_t count;
	int fd;

	fd = openat(cgroup_fd, "cgroup.events",
		    O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
	if (fd < 0)
		return -1;
	count = read(fd, buffer, sizeof(buffer) - 1);
	int saved = errno;
	close(fd);
	if (count < 0) {
		errno = saved;
		return -1;
	}
	buffer[count] = '\0';
	char *line = strstr(buffer, "populated ");
	if (line == NULL || (line[10] != '0' && line[10] != '1')) {
		errno = EPROTO;
		return -1;
	}
	*populated = line[10] == '1';
	return 0;
}

static bool drain_cgroup(int cgroup_fd, uint64_t max_seconds)
{
	uint64_t deadline = monotonic_ns() + max_seconds * 1000000000ULL;
	struct timespec pause = {.tv_sec = 0, .tv_nsec = 10000000};

	for (;;) {
		bool populated;
		if (cgroup_populated(cgroup_fd, &populated) != 0)
			return false;
		if (!populated)
			return true;
		if (monotonic_ns() >= deadline)
			return false;
		nanosleep(&pause, NULL);
	}
}

static void json_boolean(bool value)
{
	fputs(value ? "true" : "false", stdout);
}

int main(int argc, char **argv)
{
	struct options options;
	struct clone_args clone_arguments;
	struct preexec_message preexec;
	struct stream_capture stdout_capture;
	struct stream_capture stderr_capture;
	struct itimerspec timer_spec;
	struct stat cgroup_status;
	siginfo_t wait_info;
	int stdout_pipe[2];
	int stderr_pipe[2];
	int status_pipe[2];
	int release_pipe[2];
	int attestation_pipe[2];
	int cgroup_fd;
	int timer_fd;
	int initial_stdout_fd;
	int initial_stderr_fd;
	int initial_preexec_fd;
	int pidfd = -1;
	pid_t child;
	uint64_t started;
	uint64_t finished;
	bool deadline_exceeded = false;
	bool cgroup_kill_used = false;
	bool populated_zero = false;
	bool setup_ok = false;
	bool leader_reaped = false;
	bool capture_error = false;
	bool preexec_limit_exceeded = false;
	uint64_t preexec_size = 0;
	char stdout_digest[65];
	char stderr_digest[65];
	char preexec_digest[65];
	unsigned char preexec_digest_raw[32] = {0};

	parse_options(argc, argv, &options);
	memset(&preexec, 0, sizeof(preexec));
	if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
		fail_errno("ignore SIGPIPE");
	if (geteuid() != 0) {
		fprintf(stderr, "error: launcher requires effective UID 0\n");
		return 77;
	}
	cgroup_fd = open(options.cgroup_path,
			 O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
	if (cgroup_fd < 0 || fstat(cgroup_fd, &cgroup_status) != 0)
		fail_errno("open component cgroup");
	initial_stdout_fd = open_output(options.stdout_path);
	initial_stderr_fd = open_output(options.stderr_path);
	initial_preexec_fd = open_output(options.preexec_path);
	if (initial_stdout_fd < 0 || initial_stderr_fd < 0 ||
	    initial_preexec_fd < 0)
		fail_errno("create capture output");
	if (close(initial_stdout_fd) != 0 || close(initial_stderr_fd) != 0 ||
	    close(initial_preexec_fd) != 0)
		fail_errno("close initial capture output");
	if (pipe2(stdout_pipe, O_CLOEXEC) != 0 ||
	    pipe2(stderr_pipe, O_CLOEXEC) != 0 ||
	    pipe2(status_pipe, O_CLOEXEC) != 0 ||
	    pipe2(release_pipe, O_CLOEXEC) != 0 ||
	    pipe2(attestation_pipe, O_CLOEXEC) != 0)
		fail_errno("pipe2");
	timer_fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC | TFD_NONBLOCK);
	if (timer_fd < 0)
		fail_errno("timerfd_create");
	memset(&timer_spec, 0, sizeof(timer_spec));
	timer_spec.it_value.tv_sec = (time_t)options.deadline_seconds;
	if (timerfd_settime(timer_fd, 0, &timer_spec, NULL) != 0)
		fail_errno("timerfd_settime");

	memset(&clone_arguments, 0, sizeof(clone_arguments));
	clone_arguments.flags = CLONE_PIDFD | CLONE_INTO_CGROUP | CLONE_NEWNS |
		CLONE_NEWPID | CLONE_NEWIPC | CLONE_NEWUTS | CLONE_NEWNET |
		CLONE_NEWCGROUP;
	clone_arguments.pidfd = (uintptr_t)&pidfd;
	clone_arguments.cgroup = (__u64)(unsigned int)cgroup_fd;
	clone_arguments.exit_signal = SIGCHLD;
	started = monotonic_ns();
	child = (pid_t)syscall(SYS_clone3, &clone_arguments, sizeof(clone_arguments));
	if (child < 0)
		fail_errno("clone3(CLONE_INTO_CGROUP|CLONE_PIDFD|namespaces)");
	if (child == 0) {
		close(stdout_pipe[0]);
		close(stderr_pipe[0]);
		close(status_pipe[0]);
		close(release_pipe[1]);
		close(attestation_pipe[0]);
		child_main(&options, stdout_pipe[1], stderr_pipe[1], status_pipe[1],
			   release_pipe[0], attestation_pipe[1]);
		_exit(127);
	}
	close(stdout_pipe[1]);
	close(stderr_pipe[1]);
	close(status_pipe[1]);
	close(release_pipe[0]);
	close(attestation_pipe[1]);
	if (pidfd < 0)
		fail_errno("clone3 pidfd result");
	bool entered_ok =
		read_exact(status_pipe[0], &preexec, sizeof(preexec)) == 0 &&
		preexec.magic == PREEXEC_MAGIC && preexec.stage == PREEXEC_ENTERED;
	bool attestation_ok =
		capture_attestation(attestation_pipe[0], options.preexec_path,
				    options.preexec_limit, &preexec_size,
				    preexec_digest_raw,
				    &preexec_limit_exceeded) == 0;
	close(attestation_pipe[0]);
	bool ready_ok =
		read_exact(status_pipe[0], &preexec, sizeof(preexec)) == 0 &&
		preexec.magic == PREEXEC_MAGIC && preexec.stage == PREEXEC_OK;
	if (entered_ok && attestation_ok && ready_ok && preexec_size > 0 &&
	    write_all(release_pipe[1], "G", 1) == 0)
		setup_ok = true;
	else
		capture_error = true;
	close(release_pipe[1]);
	if (set_nonblocking(stdout_pipe[0]) != 0 ||
	    set_nonblocking(stderr_pipe[0]) != 0 ||
	    set_nonblocking(status_pipe[0]) != 0)
		capture_error = true;
	memset(&stdout_capture, 0, sizeof(stdout_capture));
	memset(&stderr_capture, 0, sizeof(stderr_capture));
	stdout_capture.read_fd = stdout_pipe[0];
	stderr_capture.read_fd = stderr_pipe[0];
	stdout_capture.output_fd = open(options.stdout_path,
					O_WRONLY | O_APPEND | O_CLOEXEC | O_NOFOLLOW);
	stderr_capture.output_fd = open(options.stderr_path,
					O_WRONLY | O_APPEND | O_CLOEXEC | O_NOFOLLOW);
	stdout_capture.hash_fd = make_hash_fd();
	stderr_capture.hash_fd = make_hash_fd();
	stdout_capture.limit = options.stdout_limit;
	stderr_capture.limit = options.stderr_limit;
	if (stdout_capture.output_fd < 0 || stderr_capture.output_fd < 0 ||
	    stdout_capture.hash_fd < 0 || stderr_capture.hash_fd < 0)
		capture_error = true;

	while (!leader_reaped || !stdout_capture.eof || !stderr_capture.eof) {
		struct pollfd poll_fds[] = {
			{.fd = stdout_capture.read_fd, .events = POLLIN | POLLHUP},
			{.fd = stderr_capture.read_fd, .events = POLLIN | POLLHUP},
			{.fd = pidfd, .events = POLLIN},
			{.fd = timer_fd, .events = POLLIN},
			{.fd = status_pipe[0], .events = POLLIN | POLLHUP},
		};
		int poll_result = poll(poll_fds, ARRAY_LEN(poll_fds), 250);
		if (poll_result < 0 && errno != EINTR) {
			capture_error = true;
			break;
		}
		if (!stdout_capture.eof && stream_read_available(&stdout_capture) != 0)
			capture_error = true;
		if (!stderr_capture.eof && stream_read_available(&stderr_capture) != 0)
			capture_error = true;
		if (status_pipe[0] >= 0 &&
		    (poll_fds[4].revents & (POLLIN | POLLHUP | POLLERR | POLLNVAL))) {
			if (poll_fds[4].revents & POLLIN) {
				struct preexec_message exec_status;
				ssize_t count;

				do {
					count = read(status_pipe[0], &exec_status,
						     sizeof(exec_status));
				} while (count < 0 && errno == EINTR);

				if (count == (ssize_t)sizeof(exec_status)) {
					if (exec_status.magic == PREEXEC_MAGIC &&
					    exec_status.stage == PREEXEC_EXEC) {
						preexec = exec_status;
						setup_ok = false;
					}
					capture_error = true;
				} else if (count != 0 && !(count < 0 && errno == EAGAIN)) {
					capture_error = true;
				}
			}
			if (poll_fds[4].revents & (POLLHUP | POLLERR | POLLNVAL)) {
				if (close(status_pipe[0]) != 0)
					capture_error = true;
				status_pipe[0] = -1;
			}
		}
		if (poll_fds[3].revents & POLLIN) {
			uint64_t expirations;
			ssize_t timer_count = read(timer_fd, &expirations,
					   sizeof(expirations));
			if (timer_count != (ssize_t)sizeof(expirations))
				capture_error = true;
			deadline_exceeded = true;
		}
		if ((stdout_capture.exceeded || stderr_capture.exceeded ||
		     deadline_exceeded || capture_error) && !cgroup_kill_used) {
			if (write_cgroup_kill(cgroup_fd) != 0)
				capture_error = true;
			cgroup_kill_used = true;
		}
		if (!leader_reaped && (poll_fds[2].revents & POLLIN)) {
			memset(&wait_info, 0, sizeof(wait_info));
			if (waitid(P_PIDFD, (id_t)pidfd, &wait_info, WEXITED) != 0)
				capture_error = true;
			leader_reaped = true;
			if (!cgroup_kill_used) {
				if (write_cgroup_kill(cgroup_fd) != 0)
					capture_error = true;
				cgroup_kill_used = true;
			}
		}
		if (leader_reaped && !cgroup_kill_used) {
			(void)write_cgroup_kill(cgroup_fd);
			cgroup_kill_used = true;
		}
	}
	if (!leader_reaped) {
		(void)write_cgroup_kill(cgroup_fd);
		cgroup_kill_used = true;
		memset(&wait_info, 0, sizeof(wait_info));
		if (waitid(P_PIDFD, (id_t)pidfd, &wait_info, WEXITED) == 0)
			leader_reaped = true;
		else
			capture_error = true;
	}
	populated_zero = drain_cgroup(cgroup_fd, 30);
	if (!populated_zero)
		capture_error = true;
	if (finish_stream(&stdout_capture) != 0 ||
	    finish_stream(&stderr_capture) != 0)
		capture_error = true;
	finished = monotonic_ns();
	digest_hex(stdout_capture.digest, stdout_digest);
	digest_hex(stderr_capture.digest, stderr_digest);
	digest_hex(preexec_digest_raw, preexec_digest);

	const char *termination = "CAPTURE_ERROR";
	int exit_code = -1;
	int signal_number = 0;
	if (!setup_ok)
		termination = "SETUP_FAILED";
	else if (deadline_exceeded)
		termination = "DEADLINE_EXCEEDED";
	else if (stdout_capture.exceeded || stderr_capture.exceeded)
		termination = "OUTPUT_LIMIT_EXCEEDED";
	else if (!capture_error && leader_reaped && wait_info.si_code == CLD_EXITED) {
		exit_code = wait_info.si_status;
		termination = exit_code == 0 ? "EXITED_ZERO" : "EXITED_NONZERO";
	} else if (!capture_error && leader_reaped) {
		signal_number = wait_info.si_status;
		termination = "EXITED_SIGNAL";
	}

	printf("{\"schema_version\":1,\"component_id\":\"%s\","
	       "\"leader_pid\":%ld,\"pidfd_observed\":true,"
	       "\"cgroup_inode\":%llu,"
	       "\"preexec_observation_size\":%llu,"
	       "\"preexec_observation_sha256\":\"%s\","
	       "\"preexec_limit_exceeded\":",
	       options.component, (long)child,
	       (unsigned long long)cgroup_status.st_ino,
	       (unsigned long long)preexec_size, preexec_digest);
	json_boolean(preexec_limit_exceeded);
	printf(","
	       "\"started_monotonic_ns\":%llu,"
	       "\"finished_monotonic_ns\":%llu,"
	       "\"termination\":\"%s\",\"exit_code\":%d,"
	       "\"signal\":%d,\"waitid_code\":%d,\"waitid_status\":%d,"
	       "\"deadline_exceeded\":",
	       (unsigned long long)started, (unsigned long long)finished,
	       termination, exit_code, signal_number, wait_info.si_code,
	       wait_info.si_status);
	json_boolean(deadline_exceeded);
	printf(",\"stdout_size\":%llu,\"stdout_sha256\":\"%s\","
	       "\"stdout_limit_exceeded\":",
	       (unsigned long long)stdout_capture.size, stdout_digest);
	json_boolean(stdout_capture.exceeded);
	printf(",\"stderr_size\":%llu,\"stderr_sha256\":\"%s\","
	       "\"stderr_limit_exceeded\":",
	       (unsigned long long)stderr_capture.size, stderr_digest);
	json_boolean(stderr_capture.exceeded);
	printf(",\"preexec_stage\":%u,\"preexec_errno\":%d,"
	       "\"preexec_detail\":%d,"
	       "\"cgroup_kill_used\":",
	       preexec.stage, preexec.error_number, preexec.detail);
	json_boolean(cgroup_kill_used);
	printf(",\"populated_zero_observed\":");
	json_boolean(populated_zero);
	printf(",\"setup_ok\":");
	json_boolean(setup_ok);
	printf(",\"capture_error\":");
	json_boolean(capture_error);
	printf("}\n");
	if (fflush(stdout) != 0)
		return 70;

	return strcmp(termination, "EXITED_ZERO") == 0 &&
		stderr_capture.size == 0 && populated_zero && !capture_error
		? 0
		: 1;
}
