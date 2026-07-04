# Validation 0187: SchedExecLease P5A-R 0012 Security and Overclaim Review

Date: 2026-07-04

Status: review complete. The 0186 synthetic ordinary-CFS negative result is
accepted only as narrow test-path evidence. `0009` through `0012` remain
unaccepted for production runtime denial, complete CFS deny-and-repick
correctness, runtime coverage, protection, cost, deployment, or datacenter
claims.

## Scope

Reviewed Linux patch range:

```text
base=d812f83c033a9f9b3d533e667e7106a5734eb30b
head=bd71af5daeae808ac948cbd12af2663151936f22
patches=0009..0012
```

Focused corrective diff:

```text
base=9f2b3996688849eb0ddc13531f735cc4eb16b63d
head=bd71af5daeae808ac948cbd12af2663151936f22
patches=0011..0012
```

Primary validation input:

```text
validation/0186:
  qemu_status=0
  NEGATIVE_ALLOWED_NEXT 770
  NEGATIVE_DENIED_NEXT 0
  NEGATIVE_RESULT PASS
  WORKLOAD_RET 0
```

## Local Checks

Whitespace/diff checks:

```text
git -C linux diff --check d812f83c033a9f9b3d533e667e7106a5734eb30b..HEAD
git -C linux diff --check 9f2b399668884..HEAD
result: no output
```

Patch queue strict checkpatch:

```text
0009:
  0 errors, 0 warnings, 1 check
  CHECK: extern prototypes should be avoided in .h files
  source: kernel/sched/sched.h:2860

0010:
  1 error, 1 warning
  ERROR: Missing Signed-off-by: line(s)
  WARNING: unwrapped commit description line

0011:
  0 errors, 0 warnings, 0 checks

0012:
  0 errors, 0 warnings, 0 checks
```

The `0009` check is an upstream-style issue rather than a direct runtime
security finding. The `0010` missing Signed-off-by is a patch-queue
submission/readiness blocker. It is not fixed in this review because rewriting
patch metadata would change patch hashes and possibly recreated commit IDs.

## Security Review

No immediate memory-safety finding was identified in the reviewed diff:

```text
no new syscall/ioctl/sysfs/proc/debugfs/public tracepoint ABI
no usercopy path
no new exported symbol
no heap allocation in the new CFS picker logic
no sleep path in the new CFS picker logic
no new refcount transfer
test harness remains CONFIG-gated and default-off
```

The attempt-local CFS denial state is stack-scoped during picking:

```text
linux/kernel/sched/fair.c:989
linux/kernel/sched/fair.c:10320
```

The draft path is explicitly disabled when sched_ext, core scheduling, or proxy
execution is active:

```text
linux/kernel/sched/fair.c:1025
```

The test-only denial predicate is synthetic and not authority:

```text
linux/kernel/sched/fair.c:959
linux/kernel/sched/fair.c:962
linux/kernel/sched/fair.c:1091
```

It reads `task->comm`, which can race with task-name changes. This is not a
use-after-free risk in the current locked pick-attempt context, but it is
another reason the harness cannot stand in for frozen authority.

## Production Blockers

`0012` introduces a fallback that can scan the CFS rb-tree after denial
blockage:

```text
linux/kernel/sched/fair.c:1343
linux/kernel/sched/fair.c:1351
linux/kernel/sched/fair.c:1369
```

This is acceptable only as a corrective test-path draft. It violates the
production direction from the P5A-R overhead gate unless replaced by
picker-visible eligibility, a bounded candidate structure, or another
source-proved cost model.

`0012` also prefers allowed runnable progress over idle after denial hides the
eligible entity:

```text
linux/kernel/sched/fair.c:1382
linux/kernel/sched/fair.c:1386
```

That resolves the synthetic forward-progress bug, but it is a fairness and
latency policy decision. It requires a future fairness/cost model and workload
benchmark before production acceptance.

The denied identity carrier is intentionally bounded:

```text
linux/kernel/sched/fair.c:954
linux/kernel/sched/fair.c:955
linux/kernel/sched/fair.c:1108
```

That bound is useful for safety and cost, but it means a second denied
candidate or deeper blocked-group shape can fail local repick and settle toward
idle/newidle behavior. This is not complete CFS deny-and-repick semantics.

The ordinary-CFS fast path is not complete scheduler coverage:

```text
linux/kernel/sched/core.c:6149
linux/kernel/sched/core.c:6164
linux/kernel/sched/fair.c:10310
linux/kernel/sched/fair.c:10317
linux/kernel/sched/fair.c:10330
linux/kernel/sched/fair.c:15733
```

Core scheduling, proxy execution, sched_ext, DL fair-server nesting, RT,
deadline, idle, and non-fast class-loop paths are not covered by 0186.

The fail-closed behavior is not a complete policy:

```text
linux/kernel/sched/fair.c:10295
linux/kernel/sched/fair.c:10299
```

If only denied candidates remain, production still needs explicit settlement
semantics: quarantine, dequeue, revoke, control-plane notification, or another
modeled outcome.

## Overclaim Review

Allowed claim:

```text
Under CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y, the synthetic ordinary-CFS
negative QEMU workload in validation/0186 completed: the allowed sibling ran
and the synthetic denied sibling was not observed as next_comm.
```

Forbidden claims:

```text
production runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage across scheduler paths
real ExecutionGrant/RunCap semantics
budget enforcement
monitor enforcement
hypervisor-grade isolation
process/domain protection
cost efficiency
deployment readiness
datacenter readiness
```

## Decision

`0012` may remain in the private patch queue as an experimental corrective
draft and as evidence for the next production design discussion.

It must not be described as an accepted production P5A-R implementation. Before
acceptance, the project needs:

```text
patch queue metadata cleanup or history rewrite plan
production picker-visible eligibility design
no-unbounded-scan cost proof
fairness/latency model
broader path classification or explicit exclusion enforcement
negative tests beyond the single synthetic workload
full build/QEMU/object/layout evidence for the final chosen series
```
