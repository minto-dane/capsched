# Analysis 0092: Runtime Coverage Gate

Status: Draft trace-only coverage gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

This note converts the N-136 runtime charge subject model and N-137 scheduler
server-ticket model into a trace-only coverage gate.

The core rule is:

```text
Runtime observation is not runtime authority.
```

A future trace run may support source coverage only if each observed runtime
delta can be classified by subject and evidence class:

```text
current executor
donor/accounting subject
proxy relation when current and donor can differ
server relation when fair/ext work is run through a DL server
class-local runtime or bandwidth surface
trace-only evidence class
```

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source anchors:

| Surface | Current upstream anchor | Coverage meaning |
| --- | --- | --- |
| Hrtick donor tick | `kernel/sched/core.c:916` | hrtick calls donor class tick, not blindly current |
| Runtime read | `kernel/sched/core.c:5674 task_sched_runtime()` | read-side freshness path, not enforcement |
| Runtime read donor check | `kernel/sched/core.c:5702 task_current_donor()` | update only when queried task is current donor |
| Local tick | `kernel/sched/core.c:5762 sched_tick()` | local tick runtime surface |
| Local tick donor | `kernel/sched/core.c:5778` and `kernel/sched/core.c:5789` | tick charges/dispatches through `rq->donor` |
| Remote tick | `kernel/sched/core.c:5849 sched_tick_remote()` | NO_HZ remote observation path |
| Remote tick no-proxy assumption | `kernel/sched/core.c:5874` | remote tick warns if `rq->curr != rq->donor` |
| Remote tick current class callback | `kernel/sched/core.c:5885` | remote tick uses `curr->sched_class->task_tick()` |
| CFS update_se | `kernel/sched/fair.c:1355 update_se()` | source of runtime delta |
| CFS running/current account | `kernel/sched/fair.c:1367` and `kernel/sched/fair.c:1375` | `rq->curr` gets runtime/stat trace |
| CFS donor cgroup account | `kernel/sched/fair.c:1379` and `kernel/sched/fair.c:1380` | cgroup time is accounted against donor |
| Common runtime update | `kernel/sched/fair.c:1977 update_curr_common()` | classes delegate to donor entity |
| CFS current note | `kernel/sched/fair.c:1988` | `cfs_rq->curr` may be donor, not actual running task |
| Fair server runtime | `kernel/sched/fair.c:2019 dl_server_update(&rq->fair_server)` | fair runtime may charge server state |
| RT runtime | `kernel/sched/rt.c:974 update_curr_rt()` | RT runtime/throttling compatibility surface |
| RT bandwidth time | `kernel/sched/rt.c:998` and `kernel/sched/rt.c:1004` | class-local RT bandwidth, not root budget |
| DL server idle update | `kernel/sched/deadline.c:1578 dl_server_update_idle()` | server idle accounting, not authority |
| DL server update | `kernel/sched/deadline.c:1584 dl_server_update()` | server runtime accounting, not authority |
| DL server start/stop | `kernel/sched/deadline.c:1795` and `kernel/sched/deadline.c:1819` | lifecycle trace is necessary but insufficient |
| DL server lower pick | `kernel/sched/deadline.c:2814` and `kernel/sched/deadline.c:2828` | server can call lower-class pick |
| sched_ext update | `kernel/sched/ext/ext.c:1321 update_curr_scx()` | SCX runtime surface |
| sched_ext slice/server update | `kernel/sched/ext/ext.c:1330` and `kernel/sched/ext/ext.c:1336` | slice/server runtime is not authority |
| sched_ext slice refill | `kernel/sched/ext/ext.c:3198` and `kernel/sched/ext/ext.c:3207` | refill is not authority |
| sched_ext server pick | `kernel/sched/ext/ext.c:3235 ext_server_pick_task()` | ext server lower-class pick surface |
| Runtime tracepoint | `include/trace/events/sched.h:553` and `include/trace/events/sched.h:576` | `sched_stat_runtime` lacks donor/proxy/server fields |
| Switch tracepoint | `include/trace/events/sched.h:220` | switch gives prev/next, not runtime subject proof |
| DL server trace declarations | `include/trace/events/sched.h:917` and `include/trace/events/sched.h:921` | start/stop lifecycle only, not full runtime relation |

## Coverage Requirements

A runtime coverage row is not acceptable unless it records:

```text
surface id
source anchor id
cpu
runtime delta or event type
executor/current identity when applicable
donor identity when applicable
proxy relation evidence when executor and donor may differ
server kind and server epoch/lifecycle relation when a DL server is involved
class-local runtime surface
evidence class
trace-only non-claim flags
```

Existing tracepoints can seed observations, but the current source basis shows
that several semantic fields are missing from the public trace data. Those
missing fields remain gaps; they are not silently inferred.

## Gate Rule

Trace-only runtime coverage is blocked unless:

```text
current executor observed
donor/accounting subject observed
proxy relation observed when current and donor may differ
server lifecycle, server runtime, and server epoch relation observed when a
  server path is in scope
each row has an explicit evidence class
the evidence class is trace-only
no row claims authority, enforcement, monitor verification, behavior change, or
  production protection
```

## Model

New model:

```text
formal/0070-runtime-coverage-gate-model/
```

Checked invariants:

```text
NoAcceptWithoutCurrent
NoAcceptWithoutDonor
NoAcceptProxyWithoutRelation
NoAcceptServerWithoutFullCoverage
NoAcceptWithoutEvidenceClass
NoSchedStatOnlyAuthority
NoRemoteTickOnlyProxyCoverage
NoTraceOnlyProtectionClaim
NoServerLifecycleOnlyCoverage
NoClassRuntimeAsRootEvidence
NoFailClosedAccepted
```

## Hard Rejections

Reject:

```text
runtime coverage that records only current
runtime coverage that records only donor
proxy runtime coverage without a proxy relation
server runtime coverage from start/stop only
sched_stat_runtime treated as authority
remote tick treated as proxy-safe coverage
class runtime or RT bandwidth treated as root budget evidence
trace-only runtime coverage treated as enforcement, monitor verification,
  behavior change, or protection evidence
```

## Non-Claims

This note does not execute tracefs, add tracepoints, approve public ABI, approve
Linux hooks, approve budget hooks, implement monitor timers, provide runtime
coverage, or provide production protection.
