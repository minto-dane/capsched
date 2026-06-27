# Analysis 0020: QEMU ftrace and Symbol Eligibility for Slice 0C

Status: Completed

Date: 2026-06-27

## Purpose

Explain why several Slice 0C observation targets remain missing after the QEMU
forkexec, futex cross, affinity, pressure, and combined workloads.

This note decides whether the next step should be more workload pressure,
dynamic kprobe events, or a minimal `CONFIG_CAPSCHED` internal observation
patch.

## Inputs

QEMU validation records:

```text
validation/0021-slice0c-qemu-boot-smoke-result.md
validation/0022-slice0c-qemu-broader-workload-result.md
```

QEMU kernel:

```text
build/linux-l0-capsched-on-qemu-x86_64/vmlinux
build/linux-l0-capsched-on-qemu-x86_64/System.map
```

Source:

```text
linux/kernel/sched/core.c
```

Config facts:

```text
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_KPROBE_EVENTS_ON_NOTRACE=n
CONFIG_SCHED_CORE=n
CONFIG_LTO_NONE=y
CONFIG_DEBUG_INFO_NONE=y
```

## Symbol Findings

Present in `System.map` / `nm`:

| Symbol | Type | Observation |
| --- | --- | --- |
| `try_to_wake_up` | global text | ftrace target available and observed |
| `ttwu_do_activate` | local text | ftrace target available and observed |
| `sched_ttwu_pending` | global text | ftrace target available and observed |
| `wake_up_new_task` | global text | ftrace target available and observed |
| `move_queued_task` | local text | ftrace target available and observed |
| `enqueue_task` | global text | ftrace target available and observed |
| `__schedule` | local text | present but declared `notrace`; not ftrace target |

Absent from `System.map` / `nm` in this QEMU build:

```text
ttwu_runnable
__ttwu_queue_wakelist
ttwu_queue
__pick_next_task
pick_next_task
```

These are not merely unobserved workload paths. In this build, the named
function symbols are not available as ftrace targets.

## Source Findings

`ttwu_runnable()`:

```text
static int ttwu_runnable(struct task_struct *p, int wake_flags)
```

It is source-visible and semantically important, but absent from the optimized
QEMU `vmlinux` symbol table. No-code ftrace cannot observe it by name in this
build.

`__ttwu_queue_wakelist()`:

```text
static void __ttwu_queue_wakelist(struct task_struct *p, int cpu, int wake_flags)
```

Also source-visible but absent from the optimized symbol table. The broader
futex cross workload strongly exercised remote wake behavior through
`sched_ttwu_pending`, but did not make this helper visible as a function target.

`ttwu_queue()`:

```text
static void ttwu_queue(struct task_struct *p, int cpu, int wake_flags)
```

Absent from the symbol table. It likely needs either an internal observation
point or observation of surrounding callable functions and arguments.

`__pick_next_task()`:

```text
static inline struct task_struct *
__pick_next_task(struct rq *rq, struct rq_flags *rf)
```

The `inline` shape explains why no ftrace symbol exists. A no-code function
trace target is not reliable for this category.

`pick_next_task()`:

With `CONFIG_SCHED_CORE=n`, the source has a simple wrapper:

```text
static struct task_struct *
pick_next_task(struct rq *rq, struct rq_flags *rf)
{
        return __pick_next_task(rq, rf);
}
```

In this QEMU config, the wrapper disappears from `System.map`. This is expected
under optimization and means no-code ftrace cannot distinguish fair fast path,
class iteration, or core scheduling branches from this symbol.

`__schedule()`:

```text
static void __sched notrace __schedule(int sched_mode)
```

The symbol exists, but `notrace` deliberately excludes it from ftrace. The QEMU
config also has:

```text
CONFIG_KPROBE_EVENTS_ON_NOTRACE=n
```

So treating `__schedule` as a dynamic ftrace/kprobe target is not the right
next move. Use `sched_switch` for no-code switch observation, or add a carefully
gated internal observation point later if branch-level detail is required.

## Classification

| Category | Current state | Best next method |
| --- | --- | --- |
| already-runnable wake | unresolved | internal observation or source-local kprobe only if a stable symbol exists; current symbol does not |
| delayed fair requeue | unresolved | kprobe `enqueue_task` arguments or internal observation |
| remote wakelist enqueue | partially inferred via `sched_ttwu_pending`; helper missing | kprobe surrounding visible functions or internal observation |
| pick fair fast path | unresolved | internal observation likely needed |
| pick class iteration | unresolved | internal observation likely needed |
| core scheduling branches | not applicable to current QEMU config because `CONFIG_SCHED_CORE=n`; future config-specific run needed | enable config in validation kernel or internal observation |
| final switch | observed via `sched_switch`; `__schedule` entry unavailable by design | tracepoint sufficient unless branch-level schedule mode needed |

## Recommended Next Step

Do not add enforcement.

The next low-risk validation step was a guest-side kprobe experiment for
argument-visible targets that already exist:

```text
enqueue_task
ttwu_do_activate
try_to_wake_up
wake_up_new_task
move_queued_task
```

Priority kprobe question:

```text
Can we distinguish ENQUEUE_DELAYED and other enqueue flags at enqueue_task?
```

This was executed in:

```text
validation/0023-slice0c-qemu-kprobe-observation-result.md
```

The answer for this QEMU build is yes, with one caveat: kprobe argument capture
distinguished wake enqueue, migration-related enqueue, initial enqueue, and
rq-selected wake enqueue in clean reruns, and one earlier successful affinity
serial log observed `ENQUEUE_DELAYED | ENQUEUE_NOCLOCK`. Treat delayed enqueue
as observed but workload-nondeterministic in this harness.

If kprobe argument capture cannot answer the critical branch/flag questions,
then a minimal `CONFIG_CAPSCHED` internal observation patch may be justified.
That patch must remain observation-only, must not add user ABI, and must not
reject wakeup, enqueue, pick, or switch.

## Security Claim Boundary

This analysis supports only trace coverage planning. It does not support
RunCap, DomainTag, monitor, or hypervisor-grade isolation claims.
