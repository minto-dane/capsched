# Implementation Index

Updated: 2026-06-25

No implementation plan is accepted yet.

Known future branch names:

- `capsched-linux-l0`: Linux-only prototype branch.
- `capsched-linux-h`: monitor-backed research branch.

No patch points are accepted until upstream Linux source is fetched and relevant
code paths are investigated.

Likely investigation targets, not decisions:

- `include/linux/sched.h`
- `kernel/sched/core.c`
- `kernel/sched/sched.h`
- `kernel/fork.c`
- `fs/exec.c`
- `kernel/exit.c`
- `kernel/workqueue.c`
- `io_uring/`
- cgroup CPU and cpuset code
- core scheduling code
- LSM/security hooks

