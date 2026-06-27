#define _GNU_SOURCE

#include <errno.h>
#include <linux/futex.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static atomic_int futex_turn = 0;

static void usage(const char *argv0)
{
	fprintf(stderr,
		"usage: %s MODE [ARGS]\n"
		"\n"
		"modes:\n"
		"  forkexec [iters]\n"
		"  futex [iters] [same|cross]\n"
		"  affinity [iters]\n"
		"  pressure [threads] [iters]\n"
		"  all\n",
		argv0);
}

static long parse_long(const char *s, long fallback)
{
	char *end = NULL;
	long v;

	if (!s)
		return fallback;
	errno = 0;
	v = strtol(s, &end, 10);
	if (errno || !end || *end || v < 0)
		return fallback;
	return v;
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

static int futex_wait_int(atomic_int *addr, int expected)
{
	return syscall(SYS_futex, (int *)addr, FUTEX_WAIT_PRIVATE, expected,
		       NULL, NULL, 0);
}

static int futex_wake_int(atomic_int *addr)
{
	return syscall(SYS_futex, (int *)addr, FUTEX_WAKE_PRIVATE, 1,
		       NULL, NULL, 0);
}

static int pin_this_thread(long cpu)
{
	cpu_set_t set;

	if (cpu < 0)
		return 0;

	CPU_ZERO(&set);
	CPU_SET((int)cpu, &set);
	return pthread_setaffinity_np(pthread_self(), sizeof(set), &set);
}

struct futex_arg {
	long iters;
	int self;
	int peer;
	long cpu;
};

static void *futex_worker(void *data)
{
	struct futex_arg *arg = data;
	long i;

	if (pin_this_thread(arg->cpu))
		perror("pthread_setaffinity_np");

	for (i = 0; i < arg->iters; i++) {
		while (atomic_load_explicit(&futex_turn, memory_order_acquire) != arg->self) {
			if (futex_wait_int(&futex_turn, arg->peer) && errno != EAGAIN)
				perror("futex_wait");
		}

		atomic_store_explicit(&futex_turn, arg->peer, memory_order_release);
		if (futex_wake_int(&futex_turn) < 0)
			perror("futex_wake");
	}

	return NULL;
}

static int mode_futex(long iters, int cross)
{
	long cpus = sysconf(_SC_NPROCESSORS_ONLN);
	pthread_t t0, t1;
	struct futex_arg a0 = {
		.iters = iters,
		.self = 0,
		.peer = 1,
		.cpu = cross && cpus > 1 ? 0 : -1,
	};
	struct futex_arg a1 = {
		.iters = iters,
		.self = 1,
		.peer = 0,
		.cpu = cross && cpus > 1 ? 1 : -1,
	};

	atomic_store(&futex_turn, 0);

	if (pthread_create(&t0, NULL, futex_worker, &a0))
		return 1;
	if (pthread_create(&t1, NULL, futex_worker, &a1))
		return 1;

	pthread_join(t0, NULL);
	pthread_join(t1, NULL);
	return 0;
}

static int mode_forkexec(long iters)
{
	long i;

	for (i = 0; i < iters; i++) {
		pid_t pid = fork();
		int status;

		if (pid < 0) {
			perror("fork");
			return 1;
		}
		if (pid == 0) {
			execl("/bin/true", "true", NULL);
			_exit(127);
		}
		if (waitpid(pid, &status, 0) < 0) {
			perror("waitpid");
			return 1;
		}
	}

	return 0;
}

static void busy_forever(void)
{
	volatile unsigned long x = 0;

	for (;;) {
		x++;
		if ((x & 0xfffffUL) == 0)
			sched_yield();
	}
}

static int set_pid_cpu(pid_t pid, int cpu)
{
	cpu_set_t set;

	CPU_ZERO(&set);
	CPU_SET(cpu, &set);
	return sched_setaffinity(pid, sizeof(set), &set);
}

static int mode_affinity(long iters)
{
	long cpus = sysconf(_SC_NPROCESSORS_ONLN);
	pid_t pid;
	long i;

	if (cpus < 2) {
		fprintf(stderr, "affinity mode skipped: need at least 2 CPUs\n");
		return 0;
	}

	pid = fork();
	if (pid < 0) {
		perror("fork");
		return 1;
	}
	if (pid == 0)
		busy_forever();

	tiny_sleep_ns(50000000L);

	for (i = 0; i < iters; i++) {
		if (set_pid_cpu(pid, (int)(i % 2))) {
			perror("sched_setaffinity");
			kill(pid, SIGKILL);
			waitpid(pid, NULL, 0);
			return 1;
		}
		tiny_sleep_ns(20000000L);
	}

	kill(pid, SIGKILL);
	waitpid(pid, NULL, 0);
	return 0;
}

struct pressure_arg {
	long iters;
};

static void *pressure_worker(void *data)
{
	struct pressure_arg *arg = data;
	volatile unsigned long x = 0;
	long i;

	for (i = 0; i < arg->iters; i++) {
		x += (unsigned long)i;
		if ((i & 0x3fffL) == 0)
			sched_yield();
	}

	return NULL;
}

static int mode_pressure(long threads, long iters)
{
	pthread_t *t;
	struct pressure_arg arg = { .iters = iters };
	long i;

	if (threads <= 0)
		threads = 1;
	if (threads > 256)
		threads = 256;

	t = calloc((size_t)threads, sizeof(*t));
	if (!t)
		return 1;

	for (i = 0; i < threads; i++) {
		if (pthread_create(&t[i], NULL, pressure_worker, &arg)) {
			perror("pthread_create");
			free(t);
			return 1;
		}
	}
	for (i = 0; i < threads; i++)
		pthread_join(t[i], NULL);

	free(t);
	return 0;
}

int main(int argc, char **argv)
{
	const char *mode;

	if (argc < 2) {
		usage(argv[0]);
		return 2;
	}

	mode = argv[1];

	if (!strcmp(mode, "forkexec"))
		return mode_forkexec(parse_long(argc > 2 ? argv[2] : NULL, 300));
	if (!strcmp(mode, "futex"))
		return mode_futex(parse_long(argc > 2 ? argv[2] : NULL, 10000),
				  argc > 3 && !strcmp(argv[3], "cross"));
	if (!strcmp(mode, "affinity"))
		return mode_affinity(parse_long(argc > 2 ? argv[2] : NULL, 20));
	if (!strcmp(mode, "pressure"))
		return mode_pressure(parse_long(argc > 2 ? argv[2] : NULL, 8),
				     parse_long(argc > 3 ? argv[3] : NULL, 500000));
	if (!strcmp(mode, "all")) {
		int ret;

		ret = mode_forkexec(100);
		if (ret)
			return ret;
		ret = mode_futex(20000, 1);
		if (ret)
			return ret;
		ret = mode_affinity(20);
		if (ret)
			return ret;
		return mode_pressure(8, 500000);
	}

	usage(argv[0]);
	return 2;
}
