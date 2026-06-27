#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/io_uring.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/timerfd.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef O_PATH
#define O_PATH 010000000
#endif

#ifndef __NR_io_uring_setup
#if defined(__x86_64__)
#define __NR_io_uring_setup 425
#define __NR_io_uring_enter 426
#define __NR_io_uring_register 427
#endif
#endif

struct fdset {
	int regular;
	int opath;
	int cloexec;
	int sock_a;
	int sock_b;
	int listen_fd;
	int event_fd;
	int timer_fd;
	int epoll_fd;
	int ring_fd;
};

static void marker(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	putchar('\n');
	fflush(stdout);
}

static void result_errno(const char *class, const char *op, long ret,
			 int err, const char *status)
{
	marker("CAPSCHED_POSTEXEC_RESULT %s %s ret=%ld errno=%d status=%s",
	       class, op, ret, err, status);
}

static void result_now(const char *class, const char *op, long ret,
		       const char *status)
{
	result_errno(class, op, ret, ret < 0 ? errno : 0, status);
}

static long parse_long(const char *s, long fallback)
{
	char *end = NULL;
	long v;

	if (!s)
		return fallback;
	errno = 0;
	v = strtol(s, &end, 10);
	if (errno || !end || *end)
		return fallback;
	return v;
}

static int set_cloexec(int fd, int enabled)
{
	int flags;

	flags = fcntl(fd, F_GETFD);
	if (flags < 0)
		return -1;
	if (enabled)
		flags |= FD_CLOEXEC;
	else
		flags &= ~FD_CLOEXEC;
	return fcntl(fd, F_SETFD, flags);
}

static int write_full(int fd, const void *buf, size_t len)
{
	const char *p = buf;

	while (len) {
		ssize_t n = write(fd, p, len);

		if (n < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		p += n;
		len -= (size_t)n;
	}
	return 0;
}

static int setup_regular(void)
{
	int fd;
	char buf[4096];

	memset(buf, 'R', sizeof(buf));
	fd = open("/tmp/capsched-postexec-regular", O_CREAT | O_RDWR | O_TRUNC,
		  0600);
	if (fd < 0)
		return -1;
	if (write_full(fd, buf, sizeof(buf)) < 0) {
		close(fd);
		return -1;
	}
	if (lseek(fd, 0, SEEK_SET) < 0) {
		close(fd);
		return -1;
	}
	return fd;
}

static int setup_listen_socket(void)
{
	struct sockaddr_un addr;
	int fd;

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	snprintf(addr.sun_path, sizeof(addr.sun_path),
		 "/tmp/capsched-postexec-listen.sock");
	unlink(addr.sun_path);

	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0)
		return -1;
	if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		close(fd);
		return -1;
	}
	if (listen(fd, 4) < 0) {
		close(fd);
		return -1;
	}
	return fd;
}

static int setup_timerfd(void)
{
	struct itimerspec its;
	int fd;

	fd = timerfd_create(CLOCK_MONOTONIC, 0);
	if (fd < 0)
		return -1;
	memset(&its, 0, sizeof(its));
	its.it_value.tv_nsec = 10000000L;
	if (timerfd_settime(fd, 0, &its, NULL) < 0) {
		close(fd);
		return -1;
	}
	return fd;
}

static int setup_io_uring(int regular_fd)
{
#ifdef __NR_io_uring_setup
	struct io_uring_params params;
	int ring;
	int reg_fd = regular_fd;
	long ret;

	memset(&params, 0, sizeof(params));
	ring = (int)syscall(__NR_io_uring_setup, 8, &params);
	if (ring < 0)
		return -1;
	set_cloexec(ring, 0);
	ret = syscall(__NR_io_uring_register, ring, IORING_REGISTER_FILES,
		      &reg_fd, 1);
	if (ret < 0) {
		close(ring);
		return -1;
	}
	return ring;
#else
	(void)regular_fd;
	errno = ENOSYS;
	return -1;
#endif
}

static void setup_or_die(struct fdset *fds)
{
	int sv[2];
	struct epoll_event ev;

	memset(fds, -1, sizeof(*fds));

	fds->regular = setup_regular();
	if (fds->regular < 0) {
		perror("regular setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP regular fd=%d status=ok",
	       fds->regular);

	fds->opath = open("/tmp/capsched-postexec-regular", O_PATH);
	if (fds->opath < 0) {
		perror("opath setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP opath fd=%d status=ok", fds->opath);

	fds->cloexec = open("/tmp/capsched-postexec-regular", O_RDONLY);
	if (fds->cloexec < 0 || set_cloexec(fds->cloexec, 1) < 0) {
		perror("cloexec setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP cloexec fd=%d status=ok",
	       fds->cloexec);

	if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) < 0) {
		perror("socketpair setup");
		exit(1);
	}
	fds->sock_a = sv[0];
	fds->sock_b = sv[1];
	if (write_full(fds->sock_b, "pre", 3) < 0) {
		perror("socket prewrite");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP socket fd_a=%d fd_b=%d status=ok",
	       fds->sock_a, fds->sock_b);

	fds->listen_fd = setup_listen_socket();
	if (fds->listen_fd < 0) {
		perror("listen setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP listen fd=%d status=ok",
	       fds->listen_fd);

	fds->event_fd = eventfd(5, 0);
	if (fds->event_fd < 0) {
		perror("eventfd setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP eventfd fd=%d status=ok",
	       fds->event_fd);

	fds->timer_fd = setup_timerfd();
	if (fds->timer_fd < 0) {
		perror("timerfd setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP timerfd fd=%d status=ok",
	       fds->timer_fd);

	fds->epoll_fd = epoll_create1(0);
	if (fds->epoll_fd < 0) {
		perror("epoll setup");
		exit(1);
	}
	memset(&ev, 0, sizeof(ev));
	ev.events = EPOLLIN;
	ev.data.u64 = 0xC0DEC0DEULL;
	if (epoll_ctl(fds->epoll_fd, EPOLL_CTL_ADD, fds->event_fd, &ev) < 0) {
		perror("epoll_ctl setup");
		exit(1);
	}
	marker("CAPSCHED_POSTEXEC_SETUP epoll fd=%d watched=%d status=ok",
	       fds->epoll_fd, fds->event_fd);

	fds->ring_fd = setup_io_uring(fds->regular);
	if (fds->ring_fd < 0) {
		marker("CAPSCHED_POSTEXEC_SETUP io_uring fd=-1 status=skip errno=%d",
		       errno);
	} else {
		marker("CAPSCHED_POSTEXEC_SETUP io_uring fd=%d status=ok",
		       fds->ring_fd);
	}
}

static void do_regular(int fd)
{
	char buf[16];
	void *map;
	long ret;
	int available = 0;

	lseek(fd, 0, SEEK_SET);
	ret = read(fd, buf, sizeof(buf));
	result_now("regular", "read", ret, ret > 0 ? "ok" : "fail");

	ret = write(fd, "x", 1);
	result_now("regular", "write", ret, ret == 1 ? "ok" : "fail");

	map = mmap(NULL, 4096, PROT_READ, MAP_PRIVATE, fd, 0);
	if (map == MAP_FAILED) {
		result_errno("regular", "mmap", -1, errno, "fail");
	} else {
		result_errno("regular", "mmap", 0, 0, "ok");
		munmap(map, 4096);
	}

	ret = ioctl(fd, FIONREAD, &available);
	result_errno("regular", "ioctl", ret, ret < 0 ? errno : 0,
		     ret < 0 && errno == ENOTTY ? "expected_fail" : "ok");
}

static void do_opath(int fd)
{
	char c;
	long ret;

	ret = read(fd, &c, 1);
	result_errno("opath", "read", ret, ret < 0 ? errno : 0,
		     ret < 0 && errno == EBADF ? "expected_fail" : "unexpected");
}

static void do_cloexec(int fd)
{
	char c;
	long ret;

	ret = read(fd, &c, 1);
	result_errno("cloexec", "read", ret, ret < 0 ? errno : 0,
		     ret < 0 && errno == EBADF ? "expected_fail" : "unexpected");
}

static void do_socketpair(int a, int b)
{
	char buf[16];
	long ret;

	ret = read(a, buf, sizeof(buf));
	result_now("socket", "recv_preexec", ret, ret > 0 ? "ok" : "fail");

	ret = write(a, "post", 4);
	result_now("socket", "send_postexec", ret, ret == 4 ? "ok" : "fail");

	ret = read(b, buf, sizeof(buf));
	result_now("socket", "recv_postexec", ret, ret > 0 ? "ok" : "fail");
}

static void do_accept_socket(int listen_fd)
{
	struct sockaddr_storage addr;
	socklen_t len = sizeof(addr);
	pid_t pid;
	int fd;
	int accepted;
	char buf[16];
	long ret;

	if (getsockname(listen_fd, (struct sockaddr *)&addr, &len) < 0) {
		result_now("socket", "accept", -1, "fail");
		return;
	}

	pid = fork();
	if (pid < 0) {
		result_now("socket", "accept_fork", -1, "fail");
		return;
	}
	if (pid == 0) {
		fd = socket(addr.ss_family, SOCK_STREAM, 0);
		if (fd >= 0 && connect(fd, (struct sockaddr *)&addr, len) == 0)
			(void)write_full(fd, "acc", 3);
		_exit(fd >= 0 ? 0 : 1);
	}

	accepted = accept(listen_fd, NULL, NULL);
	if (accepted < 0) {
		result_now("socket", "accept", -1, "fail");
		waitpid(pid, NULL, 0);
		return;
	}
	ret = read(accepted, buf, sizeof(buf));
	result_now("socket", "accept", ret, ret > 0 ? "ok" : "fail");
	close(accepted);
	waitpid(pid, NULL, 0);
}

static void do_epoll(int epoll_fd)
{
	struct epoll_event ev;
	int ret;

	memset(&ev, 0, sizeof(ev));
	ret = epoll_wait(epoll_fd, &ev, 1, 100);
	result_errno("epoll", "wait", ret, ret < 0 ? errno : 0,
		     ret > 0 ? "ok" : "fail");
}

static void do_eventfd(int fd)
{
	uint64_t value = 0;
	long ret;

	ret = read(fd, &value, sizeof(value));
	result_errno("eventfd", "read", ret, ret < 0 ? errno : 0,
		     ret == (long)sizeof(value) ? "ok" : "fail");

	value = 2;
	ret = write(fd, &value, sizeof(value));
	result_errno("eventfd", "write", ret, ret < 0 ? errno : 0,
		     ret == (long)sizeof(value) ? "ok" : "fail");
}

static void do_timerfd(int fd)
{
	struct itimerspec its;
	uint64_t ticks = 0;
	long ret;

	usleep(25000);
	ret = read(fd, &ticks, sizeof(ticks));
	result_errno("timerfd", "read", ret, ret < 0 ? errno : 0,
		     ret == (long)sizeof(ticks) ? "ok" : "fail");

	memset(&its, 0, sizeof(its));
	its.it_value.tv_nsec = 1000000L;
	ret = timerfd_settime(fd, 0, &its, NULL);
	result_errno("timerfd", "settime", ret, ret < 0 ? errno : 0,
		     ret == 0 ? "ok" : "fail");
}

static void do_io_uring(int fd)
{
#ifdef __NR_io_uring_register
	long ret;

	if (fd < 0) {
		result_errno("io_uring", "unregister_files", -1, ENODEV, "skip");
		result_errno("io_uring", "enter", -1, ENODEV, "skip");
		return;
	}

	ret = syscall(__NR_io_uring_register, fd, IORING_UNREGISTER_FILES,
		      NULL, 0);
	result_errno("io_uring", "unregister_files", ret,
		     ret < 0 ? errno : 0, ret == 0 ? "ok" : "fail");

#ifdef __NR_io_uring_enter
	ret = syscall(__NR_io_uring_enter, fd, 0, 0, 0, NULL, 0);
	result_errno("io_uring", "enter", ret, ret < 0 ? errno : 0,
		     ret >= 0 ? "ok" : "fail");
#endif
#else
	(void)fd;
	result_errno("io_uring", "unregister_files", -1, ENOSYS, "skip");
	result_errno("io_uring", "enter", -1, ENOSYS, "skip");
#endif
}

static int child_main(int argc, char **argv)
{
	struct fdset fds;

	if (argc < 12)
		return 2;

	fds.regular = (int)parse_long(argv[2], -1);
	fds.opath = (int)parse_long(argv[3], -1);
	fds.cloexec = (int)parse_long(argv[4], -1);
	fds.sock_a = (int)parse_long(argv[5], -1);
	fds.sock_b = (int)parse_long(argv[6], -1);
	fds.listen_fd = (int)parse_long(argv[7], -1);
	fds.event_fd = (int)parse_long(argv[8], -1);
	fds.timer_fd = (int)parse_long(argv[9], -1);
	fds.epoll_fd = (int)parse_long(argv[10], -1);
	fds.ring_fd = (int)parse_long(argv[11], -1);

	marker("CAPSCHED_POSTEXEC_BEGIN");
	do_epoll(fds.epoll_fd);
	do_regular(fds.regular);
	do_opath(fds.opath);
	do_cloexec(fds.cloexec);
	do_socketpair(fds.sock_a, fds.sock_b);
	do_accept_socket(fds.listen_fd);
	do_eventfd(fds.event_fd);
	do_timerfd(fds.timer_fd);
	do_io_uring(fds.ring_fd);
	result_errno("execfd", "binfmt_misc", -1, ENOSYS, "not_observed");
	marker("CAPSCHED_POSTEXEC_END");
	return 0;
}

static int parent_main(const char *self)
{
	struct fdset fds;
	char regular[16];
	char opath[16];
	char cloexec[16];
	char sock_a[16];
	char sock_b[16];
	char listen_fd[16];
	char event_fd[16];
	char timer_fd[16];
	char epoll_fd[16];
	char ring_fd[16];

	setvbuf(stdout, NULL, _IOLBF, 0);
	marker("CAPSCHED_POSTEXEC_PARENT_BEGIN");
	setup_or_die(&fds);

	snprintf(regular, sizeof(regular), "%d", fds.regular);
	snprintf(opath, sizeof(opath), "%d", fds.opath);
	snprintf(cloexec, sizeof(cloexec), "%d", fds.cloexec);
	snprintf(sock_a, sizeof(sock_a), "%d", fds.sock_a);
	snprintf(sock_b, sizeof(sock_b), "%d", fds.sock_b);
	snprintf(listen_fd, sizeof(listen_fd), "%d", fds.listen_fd);
	snprintf(event_fd, sizeof(event_fd), "%d", fds.event_fd);
	snprintf(timer_fd, sizeof(timer_fd), "%d", fds.timer_fd);
	snprintf(epoll_fd, sizeof(epoll_fd), "%d", fds.epoll_fd);
	snprintf(ring_fd, sizeof(ring_fd), "%d", fds.ring_fd);

	marker("CAPSCHED_POSTEXEC_PARENT_EXEC");
	execl(self, self, "child", regular, opath, cloexec, sock_a, sock_b,
	      listen_fd, event_fd, timer_fd, epoll_fd, ring_fd, NULL);
	perror("exec self");
	return 127;
}

int main(int argc, char **argv)
{
	setvbuf(stdout, NULL, _IOLBF, 0);

	if (argc > 1 && !strcmp(argv[1], "child"))
		return child_main(argc, argv);
	return parent_main(argv[0]);
}
