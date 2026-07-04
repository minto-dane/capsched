#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define DENIED_COMM	"seldenyA"
#define ALLOWED_COMM	"selallowB"
#define TEST_CPU	0

static int write_full(int fd, const void *buf, size_t len)
{
	const char *p = buf;

	while (len) {
		ssize_t ret = write(fd, p, len);

		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		p += ret;
		len -= (size_t)ret;
	}
	return 0;
}

static int read_full(int fd, void *buf, size_t len)
{
	char *p = buf;

	while (len) {
		ssize_t ret = read(fd, p, len);

		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		if (!ret)
			return -1;
		p += ret;
		len -= (size_t)ret;
	}
	return 0;
}

static void tiny_sleep_ns(long ns)
{
	struct timespec ts = {
		.tv_sec = ns / 1000000000L,
		.tv_nsec = ns % 1000000000L,
	};

	while (nanosleep(&ts, &ts) && errno == EINTR)
		;
}

static int pin_this_process(void)
{
	cpu_set_t set;

	CPU_ZERO(&set);
	CPU_SET(TEST_CPU, &set);
	return sched_setaffinity(0, sizeof(set), &set);
}

static void set_comm_or_die(const char *name)
{
	if (prctl(PR_SET_NAME, name, 0, 0, 0) < 0) {
		perror("prctl(PR_SET_NAME)");
		_exit(111);
	}
}

static const char *tracefs_root(void)
{
	if (!access("/sys/kernel/tracing/tracing_on", W_OK))
		return "/sys/kernel/tracing";
	if (!access("/sys/kernel/debug/tracing/tracing_on", W_OK))
		return "/sys/kernel/debug/tracing";
	return NULL;
}

static int write_tracefs_file(const char *root, const char *name,
			      const char *value)
{
	char path[256];
	int fd;
	int ret;

	snprintf(path, sizeof(path), "%s/%s", root, name);
	fd = open(path, O_WRONLY | O_CLOEXEC);
	if (fd < 0)
		return -1;
	ret = write_full(fd, value, strlen(value));
	close(fd);
	return ret;
}

static int clear_trace(const char *root)
{
	char path[256];
	int fd;

	snprintf(path, sizeof(path), "%s/trace", root);
	fd = open(path, O_WRONLY | O_TRUNC | O_CLOEXEC);
	if (fd < 0)
		return -1;
	close(fd);
	return 0;
}

static int reset_trace_window(const char *root)
{
	if (write_tracefs_file(root, "tracing_on", "0\n") < 0) {
		perror("tracefs tracing_off");
		return -1;
	}
	if (clear_trace(root) < 0) {
		perror("tracefs clear");
		return -1;
	}
	if (write_tracefs_file(root, "trace_marker",
			       "DOMAINLEASE_NEGATIVE_START\n") < 0) {
		printf("NEGATIVE_TRACE_MARKER_SKIPPED errno=%d\n", errno);
		fflush(stdout);
	}
	if (write_tracefs_file(root, "tracing_on", "1\n") < 0) {
		perror("tracefs tracing_on");
		return -1;
	}
	return 0;
}

static int count_trace_lines(const char *root, const char *needle)
{
	char path[256];
	char *line = NULL;
	size_t cap = 0;
	ssize_t n;
	FILE *f;
	int count = 0;

	snprintf(path, sizeof(path), "%s/trace", root);
	f = fopen(path, "re");
	if (!f)
		return -1;

	while ((n = getline(&line, &cap, f)) >= 0) {
		(void)n;
		if (strstr(line, needle))
			count++;
	}

	free(line);
	fclose(f);
	return count;
}

static void cpu_work(unsigned long loops)
{
	volatile unsigned long x = 0;
	unsigned long i;

	for (i = 0; i < loops; i++) {
		x += i;
		if ((i & 0xffffUL) == 0)
			sched_yield();
	}
}

static void denied_forever(void)
{
	volatile unsigned long x = 0;

	printf("NEGATIVE_DENIED_STARTED\n");
	fflush(stdout);
	for (;;) {
		x++;
		if ((x & 0xfffffUL) == 0)
			sched_yield();
	}
}

static void child_main(const char *name, int ready_fd, int start_fd,
		       int denied)
{
	char byte = 'R';

	set_comm_or_die(name);
	if (pin_this_process())
		perror("sched_setaffinity");
	if (setpriority(PRIO_PROCESS, 0, -20))
		perror("setpriority");

	if (write_full(ready_fd, &byte, sizeof(byte)) < 0)
		_exit(112);
	close(ready_fd);

	if (read_full(start_fd, &byte, sizeof(byte)) < 0)
		_exit(113);
	close(start_fd);

	if (denied)
		denied_forever();

	printf("NEGATIVE_ALLOWED_STARTED\n");
	fflush(stdout);
	cpu_work(50000000UL);
	printf("NEGATIVE_ALLOWED_DONE\n");
	fflush(stdout);
	_exit(0);
}

static int wait_child_timeout(pid_t pid, int *status, long timeout_ms)
{
	long waited = 0;

	for (;;) {
		pid_t ret = waitpid(pid, status, WNOHANG);

		if (ret == pid)
			return 0;
		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		if (waited >= timeout_ms)
			return 1;
		tiny_sleep_ns(10000000L);
		waited += 10;
	}
}

static pid_t spawn_child(const char *name, int ready_fd, int start_fd,
			 int denied)
{
	pid_t pid = fork();

	if (pid < 0)
		return -1;
	if (!pid)
		child_main(name, ready_fd, start_fd, denied);
	return pid;
}

static int mode_negative(void)
{
	const char *tracefs;
	int ready[2];
	int denied_start[2];
	int allowed_start[2];
	pid_t denied;
	pid_t allowed;
	char byte = 'S';
	int status = 0;
	int allowed_next;
	int denied_next;
	int denied_wait;
	int pass = 1;

	tracefs = tracefs_root();
	if (!tracefs) {
		printf("NEGATIVE_RESULT FAIL reason=tracefs_unavailable\n");
		return 125;
	}

	if (pin_this_process())
		perror("sched_setaffinity");

	if (pipe(ready) || pipe(denied_start) || pipe(allowed_start)) {
		perror("pipe");
		return 1;
	}

	denied = spawn_child(DENIED_COMM, ready[1], denied_start[0], 1);
	if (denied < 0) {
		perror("fork denied");
		return 1;
	}
	allowed = spawn_child(ALLOWED_COMM, ready[1], allowed_start[0], 0);
	if (allowed < 0) {
		perror("fork allowed");
		kill(denied, SIGKILL);
		return 1;
	}

	close(ready[1]);
	close(denied_start[0]);
	close(allowed_start[0]);

	if (read_full(ready[0], &byte, sizeof(byte)) ||
	    read_full(ready[0], &byte, sizeof(byte))) {
		perror("ready read");
		kill(denied, SIGKILL);
		kill(allowed, SIGKILL);
		return 1;
	}
	close(ready[0]);

	if (reset_trace_window(tracefs)) {
		perror("tracefs reset");
		close(denied_start[1]);
		close(allowed_start[1]);
		kill(denied, SIGKILL);
		kill(allowed, SIGKILL);
		return 1;
	}

	printf("NEGATIVE_CHILDREN_READY denied_pid=%d allowed_pid=%d tracefs=%s\n",
	       denied, allowed, tracefs);
	fflush(stdout);

	if (write_full(allowed_start[1], &byte, sizeof(byte)) < 0) {
		perror("start allowed");
		pass = 0;
	}
	close(allowed_start[1]);
	printf("NEGATIVE_ALLOWED_RELEASED\n");
	fflush(stdout);

	if (write_full(denied_start[1], &byte, sizeof(byte)) < 0) {
		perror("start denied");
		pass = 0;
	}
	close(denied_start[1]);
	printf("NEGATIVE_CHILDREN_RELEASED\n");
	fflush(stdout);
	sched_yield();

	if (wait_child_timeout(allowed, &status, 5000)) {
		printf("NEGATIVE_ALLOWED_STATUS timeout\n");
		kill(allowed, SIGKILL);
		pass = 0;
	} else if (!WIFEXITED(status) || WEXITSTATUS(status)) {
		printf("NEGATIVE_ALLOWED_STATUS bad status=%d\n", status);
		pass = 0;
	} else {
		printf("NEGATIVE_ALLOWED_STATUS exit=0\n");
	}

	tiny_sleep_ns(50000000L);
	write_tracefs_file(tracefs, "tracing_on", "0\n");

	denied_wait = waitpid(denied, &status, WNOHANG);
	if (denied_wait == denied) {
		printf("NEGATIVE_DENIED_STATUS exited status=%d\n", status);
		pass = 0;
	} else if (denied_wait < 0 && errno != ECHILD) {
		perror("waitpid denied");
		pass = 0;
	} else {
		printf("NEGATIVE_DENIED_STATUS still_present\n");
	}

	allowed_next = count_trace_lines(tracefs, "next_comm=" ALLOWED_COMM);
	denied_next = count_trace_lines(tracefs, "next_comm=" DENIED_COMM);
	printf("NEGATIVE_ALLOWED_NEXT %d\n", allowed_next);
	printf("NEGATIVE_DENIED_NEXT %d\n", denied_next);
	if (allowed_next <= 0 || denied_next != 0)
		pass = 0;

	kill(denied, SIGKILL);
	wait_child_timeout(denied, &status, 100);

	printf("NEGATIVE_RESULT %s\n", pass ? "PASS" : "FAIL");
	fflush(stdout);
	return pass ? 0 : 1;
}

int main(int argc, char **argv)
{
	if (argc == 1 || (argc == 2 && !strcmp(argv[1], "negative")))
		return mode_negative();

	fprintf(stderr, "usage: %s [negative]\n", argv[0]);
	return 2;
}
