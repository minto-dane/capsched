# Validation 0023: Slice 0C QEMU Kprobe Observation Result

Status: Passed for guest-side kprobe observation; still observation-only

Date: 2026-06-27

## Boundary

This run extends the Slice 0C QEMU harness with optional guest-side kprobe
events for scheduler functions that exist as symbols in the QEMU build.

It validates:

```text
guest tracefs kprobe_events is available
kprobe events can attach to selected scheduler functions
enqueue_task flags are observable
try_to_wake_up wake_flags are observable at function entry
ttwu_do_activate wake_flags are observable after wake path processing
move_queued_task new_cpu is observable on affinity migration workload
```

It does not validate:

```text
RunCap enforcement
FrozenRunUse enforcement
SchedContext budget enforcement
DomainTag activation
monitor-backed authority
cross-Domain isolation
hypervisor-grade protection
```

## Runner Change

The QEMU runner now accepts:

```text
CAPSCHED_QEMU_ENABLE_KPROBES=1
```

When enabled, the guest registers kprobe events:

```text
capsched/cs_enqueue_task      enqueue_task flags=$arg3:x32
capsched/cs_ttwu_do_activate  ttwu_do_activate wake_flags=$arg3:x32
capsched/cs_try_to_wake_up    try_to_wake_up state=$arg2:x32 wake_flags=$arg3:x32
capsched/cs_wake_up_new_task  wake_up_new_task
capsched/cs_move_queued_task  move_queued_task new_cpu=$arg4:x32
```

The runner records `KPROBE_COUNT` values and simple argument distributions on
serial output. The normal non-kprobe QEMU validation path remains unchanged.

## Kernel

Both runs used:

```text
linux commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462

linux subject:
  sched/capsched: Add type-only authority scaffolding

guest config:
  CONFIG_CAPSCHED=y
  CONFIG_FUNCTION_TRACER=y
  CONFIG_KPROBES=y
  CONFIG_KPROBE_EVENTS=y
```

## Runs

| Workload | Args | Run directory | Status |
| --- | --- | --- | --- |
| `futex` | `futex 5000 cross` | `build/qemu/slice0c-boot-smoke/20260627T055620Z` | Passed |
| `affinity` | `affinity 40` | `build/qemu/slice0c-boot-smoke/20260627T060342Z` | Passed |

Additional successful affinity run retained for a rare flag observation:

```text
build/qemu/slice0c-boot-smoke/20260627T055746Z
```

That run observed one `enqueue_task()` event with `flags=0x28`
(`ENQUEUE_DELAYED | ENQUEUE_NOCLOCK`). The later runner was hardened to
sanitize serial count parsing after kernel printk interleaving affected a
generated `counts.tsv`; the serial evidence itself remained usable.

For each run:

```text
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
TRACEFS /sys/kernel/tracing
TRACER function
WORKLOAD_RET 0
CAPSCHED_QEMU_END workload_ret=0
qemu_status=0
kprobes_enabled=1
```

## Kprobe Counts

Use `KPROBE_COUNT` for kprobe event counts. The generic `COUNT` lines in kprobe
runs can include both function-tracer and event-name substring matches.

| Kprobe event | futex cross | affinity |
| --- | ---: | ---: |
| `cs_enqueue_task` | 7073 | 214 |
| `cs_ttwu_do_activate` | 7073 | 132 |
| `cs_try_to_wake_up` | 7075 | 136 |
| `cs_wake_up_new_task` | 0 | 2 |
| `cs_move_queued_task` | 0 | 40 |

## Argument Findings

`enqueue_task` flags for futex cross:

| Flags | Count | Notes |
| --- | ---: | --- |
| `0x9` | 7072 | `ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |
| `0x100009` | 1 | `ENQUEUE_RQ_SELECTED | ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |

`enqueue_task` flags for affinity:

| Flags | Count | Notes |
| --- | ---: | --- |
| `0x9` | 44 | `ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |
| `0xa` | 40 | `ENQUEUE_RESTORE | ENQUEUE_NOCLOCK` |
| `0x40000` | 40 | `ENQUEUE_MIGRATED` |
| `0x40009` | 5 | `ENQUEUE_MIGRATED | ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |
| `0x80008` | 2 | `ENQUEUE_INITIAL | ENQUEUE_NOCLOCK` |
| `0x100009` | 43 | `ENQUEUE_RQ_SELECTED | ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |
| `0x140009` | 40 | `ENQUEUE_RQ_SELECTED | ENQUEUE_MIGRATED | ENQUEUE_WAKEUP | ENQUEUE_NOCLOCK` |

Additional affinity flag observed in the earlier successful run
`20260627T055746Z`:

| Flags | Count | Notes |
| --- | ---: | --- |
| `0x28` | 1 | `ENQUEUE_DELAYED | ENQUEUE_NOCLOCK` |

`try_to_wake_up` entry `wake_flags`:

| Workload | Flags | Count | Notes |
| --- | ---: | ---: | --- |
| futex cross | `0x0` | 7074 | caller passed no extra wake flags |
| futex cross | `0x10` | 1 | `WF_SYNC` |
| affinity | `0x0` | 134 | caller passed no extra wake flags |
| affinity | `0x10` | 2 | `WF_SYNC` |

`ttwu_do_activate` downstream `wake_flags` for affinity:

| Flags | Count | Notes |
| --- | ---: | --- |
| `0x0` | 1 | no TTWU-selected flag observed at this point |
| `0x20` | 5 | `WF_MIGRATED` |
| `0x8` | 43 | `WF_TTWU` |
| `0x88` | 43 | `WF_TTWU | WF_RQ_SELECTED` |
| `0xa8` | 40 | `WF_TTWU | WF_MIGRATED | WF_RQ_SELECTED` |

`move_queued_task` target CPU for affinity:

| `new_cpu` | Count |
| ---: | ---: |
| `0x0` | 20 |
| `0x1` | 20 |

## Interpretation

This confirms that the QEMU trace harness can observe argument-level scheduler
semantics without adding a Linux patch. In particular, `enqueue_task()` can
distinguish ordinary wake enqueue, migration-related enqueue, initial enqueue,
and rq-selected wake enqueue in the clean rerun. A prior successful affinity
run also observed delayed enqueue. Treat delayed enqueue as observed but
workload-nondeterministic in this harness.

For CapSched, this is useful because the future `capsched_prepare_enqueue()`
placement must preserve Linux's existing enqueue flag semantics instead of
flattening all enqueue operations into a single authority check.

## Remaining Gaps

Kprobes did not solve all Slice 0C questions:

```text
ttwu_runnable remains absent as a symbol in this build
__ttwu_queue_wakelist and ttwu_queue remain absent as symbols
__pick_next_task and pick_next_task remain absent or optimized away
__schedule is intentionally notrace in source
core scheduling branches are not exercised because CONFIG_SCHED_CORE=n
```

The currently justified next step is not enforcement. It is a narrow internal
observation design decision:

```text
If existing tracepoints plus kprobe-visible arguments are enough to choose the
first RunCap hook, proceed to a design note.

If already-runnable wake, remote wakelist, or pick-branch detail is still
security-relevant, add a minimal CONFIG_CAPSCHED observation-only patch before
any enforcement patch.
```

## Decision

Keep the kprobe mode in the QEMU harness.

Do not add enforcement from this result alone.

The next gate is a Slice 0C observation synthesis note mapping:

```text
wakeup paths
enqueue flags
migration paths
pick/switch evidence
missing internal branches
which paths require a CapSched hook
which paths require only post-hook revalidation
```

That synthesis should determine whether the first implementation slice can be a
small type/observation patch or must first add internal trace-only hooks.
