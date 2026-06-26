# Implementation Index

Updated: 2026-06-25

No implementation patch points are accepted yet.

Candidate implementation plans:

- `0001-l0-runnable-lease-implementation-plan.md`
  - Status: candidate plan, not accepted patch points.
  - Purpose: derive Linux L0 scaffolding and validation sequence from the
    checked Runnable Lease TLA+ model and upstream source maps.
- `0002-l0-slice0-scaffolding-plan.md`
  - Status: applied to Linux as commit
    `0b685979f27b3d42ee620ced5f707ee391a2a27f`.
  - Purpose: narrow the first patch to inert `CONFIG_CAPSCHED` build
    scaffolding with no task layout or scheduler behavior changes.

Known future branch names:

- `capsched-linux-l0`: Linux-only prototype branch.
- `capsched-linux-h`: monitor-backed research branch.

The first selected slice is Slice 0A: inert build scaffolding. Linux source has
been patched and committed. Build validation is pending because host dependency
`flex` is missing.

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
