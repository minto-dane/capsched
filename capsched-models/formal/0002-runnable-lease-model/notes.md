# Runnable Lease Model Notes

Status: Draft

Date: 2026-06-25

## Tooling

Discovered on this machine:

```text
java: /usr/bin/java
tla2tools.jar: /home/nia/tools/tla/tla2tools.jar
tlc command: not found during initial probe
```

Primary validation command:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC RunnableLease.tla
```

## Validation Result

Run completed on 2026-06-25:

```text
TLC2 Version 2.19 of 08 August 2024
227201 states generated
28450 distinct states found
complete graph depth: 31
no invariant error found
```

Recorded validation artifact:

```text
capsched/capsched-models/validation/0001-runnable-lease-tlc.md
```

`CHECK_DEADLOCK FALSE` is set because the model has intentional terminal states
where all epochs/generations are exhausted or all tasks are dead/referenced.
The first run is a safety/invariant check, not a liveness proof.

## Current Modeling Choices

### FrozenRunUse is attached to the task abstraction

The model stores `grant[t]` per task, matching the current Linux intuition that
the runqueue contains task/scheduler-entity state rather than an independent
user-visible handle.

This does not yet decide the exact Linux implementation. It only says the
authority snapshot must be reachable at pick/activate time without redoing
heavy capability lookup.

### Revocation clears affected runnable state

`RevokeDomainEpoch` increments the Domain epoch, clears cap/grant for affected
tasks, removes selected/running CPU state, and returns active affected tasks to
`blocked`.

This is stricter than a purely lazy model where stale queued entries remain and
pick-time checks reject them. The stricter model is useful because it exposes an
implementation pressure:

```text
If CapSched wants "no queued entry without a valid FrozenRunUse",
epoch revocation must synchronize with runnable/selected/running state.
```

If Linux implementation later prefers lazy revocation, this model should be
forked or weakened deliberately, not by accident.

### Exec preserves Domain and refreshes process generation

`ExecTask` is allowed only for a running task. It increments
`ProcessGeneration`, does not change `TaskDomain`, invalidates the raw RunCap,
and updates the current FrozenRunUse's process generation.

This encodes the design position:

```text
exec changes code/mm/credentials policy,
but not DomainTag or SchedContext ownership.
```

Endpoint/resource models may treat process generation differently later.

### BPF and sched_ext are policy inputs, not execution roots

`PolicyAllowsRun[t]` can gate `IssueRunCap`, but it is not sufficient for
enqueue, pick, activation, or budget consumption.

This reflects the BPF analysis: BPF is useful for policy and experimentation,
but cannot be the production root for `No RunCap, no run`.

### CPU placement refines Linux constraints

The model uses:

```text
AllowedSet =
  CtxAllowed
  intersect AffinityAllowed
  intersect CpusetAllowed
  intersect DomainAllowed
```

and activation also checks `MonitorAllowed(domain, epoch, cpu)`.

This models the compatibility constraint that CapSched must refine existing
Linux affinity/cpuset/topology restrictions rather than bypass them.

## Known Abstractions

The model currently abstracts away:

```text
per-class CFS/RT/deadline runqueue internals
sched_ext DSQs
core scheduling cookies
priority and vruntime
remote wake locking
RCU and task lifetime details
real cpuset hierarchy and hotplug races
io_uring/workqueue async provenance
endpoint capabilities
monitor memory view switching
cluster lease signing and migration
```

These are intentional omissions for the first model.

## Expected Counterexample Classes

Useful counterexamples would include:

```text
queued task with stale Domain epoch
selected task with zero budget
running task without Domain activation
task selected on two CPUs
task running outside cpuset/affinity/SchedContext/Domain/Monitor CPU sets
exec invalidating grant without refresh
revocation leaving selected/running stale state
```

If TLC finds none in the tiny model, that is only evidence that the first
authority story is internally coherent under these abstractions.

## Linux L0 Pressure

Before patching Linux, derive answers for:

```text
Where exactly is FrozenRunUse stored?
Which wake paths must freeze or validate it?
Does epoch revocation eagerly dequeue, lazily invalidate, or both?
How is budget exhaustion represented for CFS, RT, deadline, and sched_ext?
How is Domain activation represented in Linux-only L0 without a real monitor?
How do cpuset/affinity changes invalidate or refresh allowed CPU sets?
```
