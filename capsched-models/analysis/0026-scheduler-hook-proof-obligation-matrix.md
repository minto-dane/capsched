# Analysis 0026: Scheduler Hook Proof Obligation Matrix

Status: Draft obligation matrix, no implementation approved

Date: 2026-06-27

## Purpose

This matrix turns the scheduler authority state machine into proof obligations
for future hook candidates.

It is not a patch plan. It is a gate: any future patch touching runnable
authority must satisfy or explicitly defer these obligations.

## Candidate Roles

The current candidate roles are:

```text
admission_freeze
enqueue_assertion
placement_refresh
pick_validation
switch_activation
budget_charge
revoke_propagation
spawn_initialization
```

These are roles, not necessarily single functions. A correct implementation may
require multiple source locations for one role.

## Matrix

| Role | Main transition | Likely Linux area | May fail? | Primary invariant | Required evidence |
| --- | --- | --- | --- | --- | --- |
| admission_freeze | Blocked -> FrozenRunnable | wake admission before non-rollback mutation | yes, before mutation only | NoRunCapNoFrozenRunnable | source map, model, negative tests |
| enqueue_assertion | FrozenRunnable -> Queued | `enqueue_task()` / `activate_task()` | nofail preferred | NoQueuedWithoutFrozenUse | QEMU/kprobe coverage, lock context |
| placement_refresh | Queued -> MigratingQueued -> Queued | migration, affinity, hotplug | only with rollback/model | NoMigrationMintAuthority | source map, hotplug/cpuset tests |
| pick_validation | Queued -> Selected | `pick_next_task()` / class pick paths | dangerous | NoPickWithoutLiveFrozenUse | class model, retry semantics |
| switch_activation | Selected -> Running | `__schedule()` / `context_switch()` | no ordinary failure | NoSwitchWithoutDomainActivation | monitor model, fail-closed model |
| budget_charge | Running -> Running/preempt | tick/runtime accounting | no ordinary slow path | NoBudgetNoExecution | runtime model, perf/tick tests |
| revoke_propagation | live states -> invalid/quarantine | epoch revoke paths | must be bounded | RevocationStopsAllUses | model, adversarial tests |
| spawn_initialization | Spawned -> FrozenRunnable | fork/wake_up_new_task | yes before child runs | NoInheritedAmbientRunAuthority | fork/clone/exec model |

## Role Details

### Admission Freeze

Goal:

```text
convert RunCap + SchedContext + task identity into FrozenRunUse
before Linux receives executable runqueue custody
```

Must bind:

```text
task generation
process generation
domain id and domain epoch
run cap epoch
sched context id and epoch
allowed CPUs
budget authority
co-tenancy policy placeholder
claim scope
trust root
```

Hard rejection conditions:

```text
freezes Linux mutable shadow as production authority
does slow capability lookup under rq lock or p->pi_lock
can fail after TASK_WAKING without a lost-wakeup model
allocates or sleeps in wake hot path
uses remote cluster lease directly
```

Required models:

```text
RunnableLease with wake admission
RemotePendingWake revoke extension
failure before/after TASK_WAKING split
```

### Enqueue Assertion

Goal:

```text
assert that a task entering runqueue custody already has valid FrozenRunUse
```

Why nofail:

`enqueue_task()` returns `void` and mutates scheduler accounting and class
state. Treat this as an assertion point until a full rollback model exists.

Hard rejection conditions:

```text
returns error from enqueue_task without class rollback
silently allows missing FrozenRunUse in enforcement mode
allocates, sleeps, or takes external locks under rq lock
claims production security from Linux-only assertion
```

Required evidence:

```text
kprobe/function coverage for enqueue flags
source coverage for delayed enqueue
config coverage for core scheduling and sched_ext
lockdep/KCSAN plan before behavior change
```

### Placement Refresh

Goal:

```text
ensure migration changes CPU placement only within existing authority
```

Must cover:

```text
queued migration
wake CPU selection
cpuset shrink/grow
affinity changes
hotplug fallback
migrate-disabled task exceptions
per-CPU kthread exceptions
```

Hard rejection conditions:

```text
migration mints a new RunCap
CapSched cpumask bypasses Linux cpu_active/cpu_online rules
hotplug fallback runs outside frozen placement without an explicit exception
cluster placement intent is used directly in hot path
```

Required evidence:

```text
source map for set_cpus_allowed and migration_cpu_stop
QEMU affinity/hotplug workload plan
state model for placement refresh vs authority mint
```

### Pick Validation

Goal:

```text
prevent selected execution when queued authority became stale
```

Must validate:

```text
FrozenRunUse exists
task and process generations match
domain epoch matches
sched context epoch matches
CPU is allowed
budget remains
co-tenancy policy is not violated or claim is not made
```

Hard rejection conditions:

```text
pick failure after class state mutation without model
only fair fast path covered
sched_ext fallback not considered
core scheduling cached pick not considered
RT/DL class state not considered
unknown treated as low risk
```

Required models:

```text
SelectedUse state
pick retry/failure action
class accounting preservation
core/sched_ext/proxy placeholders
```

### Switch Activation

Goal:

```text
activate DomainTag and MemoryView before a selected task becomes active
```

Monitor-backed production requires:

```text
monitor-sealed RunToken or equivalent
domain epoch validation
CPU and co-tenancy validation
root budget validation
MemoryView activation
failure action that does not continue under wrong Domain
```

Hard rejection conditions:

```text
Linux shadow DomainTag is used as production authority
monitor activation failure returns as ordinary scheduler error
rq->curr is committed before fail-closed semantics exist
same-Domain fast path skips epoch/budget freshness without proof
```

Required models:

```text
DomainMonitor activation refinement
Selected -> Running fail-closed state
stale active Domain revocation
same-Domain fast path freshness
```

### Budget Charge

Goal:

```text
ensure CPU execution cannot exceed SchedContext/root Domain budget
```

L0 may prototype:

```text
Linux accounting
timer preemption
debug assertions
trace counters
```

CapSched-H requires:

```text
monitor/root budget independent of Linux compromise
bounded overrun
preemption or CPU isolation on exhaustion
```

Hard rejection conditions:

```text
Linux-only accounting claimed as production budget root
tickless/nohz behavior ignored
RT/DL runtime semantics ignored
budget refill/revoke race unmodeled
```

Required next analysis:

```text
tick and runtime accounting source map
budget overrun bound model
NO_HZ and high-resolution timer impact
```

### Revoke Propagation

Goal:

```text
ensure revoked authority cannot later reach execution or endpoint/device use
```

Must cover:

```text
remote pending wake
queued
delayed queued
selected
running
async work
service tickets
device queue
IOMMU map
TLB and MemoryView
```

Hard rejection conditions:

```text
revocation only updates Linux mutable state
remote pending state not invalidated before activation
selected task can switch after epoch mismatch
running Domain can exceed revoke latency without a bound
```

Required models:

```text
epoch revoke over scheduler states
selected/running revoke action
remote pending wake revoke
async and endpoint revoke linkage
```

### Spawn Initialization

Goal:

```text
create child identity and initial execution authority without ambient expansion
```

Must cover:

```text
fork
clone thread
new process
kernel threads
exec does not change Domain
exit invalidates live grants
```

Hard rejection conditions:

```text
child inherits all parent authority implicitly
new task wake uses ordinary RunCap without SpawnCap
exec changes DomainTag as a side effect
kernel thread path bypass is not classified
```

Required next analysis:

```text
copy_process source map against SpawnCap
exec Domain invariance map
kernel thread/service Domain exception model
```

## Immediate Decision

Do not implement schema v2 as a bare tag ledger yet.

First derive schema v2 fields from this matrix:

```text
role
transition
invariant
authority object
trust root
failure action
mutation phase
revocation scope
Linux source anchors
required model
required runtime evidence
claim scope
assurance claim id
```

Then retag Slice 0C behavior paths.

Only after retagging should hook candidates be mechanically filtered.
