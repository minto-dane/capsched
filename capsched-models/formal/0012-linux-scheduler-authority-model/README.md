# Formal 0012: Linux Scheduler Authority Model

Status: Checked for tiny finite model

Date: 2026-06-27

## Purpose

This model refines the earlier Runnable Lease model toward the Linux scheduler
authority states recorded in `analysis/0025` and the proof obligations in
`analysis/0026`.

It is not an implementation approval. Its job is to make unsafe authority
transitions explicit before any behavior-changing scheduler hook is selected.

## Modeled Boundary

The model covers these authority states:

```text
Blocked
Spawned
RemotePendingWake
FrozenRunnable
Queued
DelayedQueued
MigratingQueued
Selected
Running
CurrentContinuation
Throttled
Dead
```

It models:

```text
spawn initialization without ambient runnable authority
normal wake freeze before enqueue
remote pending wake before activation
already-runnable delayed requeue
queued migration
pick into SelectedUse
fail-closed selected budget failure
monitor-style switch activation into Running
current self-wake as CurrentContinuation
tick budget decrement and exhaustion
domain epoch revocation across queued, selected, running, and pending states
exit invalidation
```

## Security Meaning

The core safety invariants are:

```text
No runnable custody without a live FrozenRunUse
No remote pending wake can run
No active execution without a run token
No active execution without remaining budget
No active execution under a stale domain epoch
No dead task keeps grant, selected, or running authority
No task is selected or running on more than one CPU
```

In production, the `runToken` field stands for monitor-owned activation
authority. In Linux-only L0 it is only a semantic placeholder and must not be
claimed as hypervisor-grade enforcement.

## Intentional Simplifications

This model deliberately keeps the finite state space small:

```text
two tasks, two domains, two CPUs, two sched contexts
static task-to-domain mapping
static sched-context ownership
all valid sched contexts allow both CPUs
small bounded epoch, generation, and budget domains
no class-specific CFS/RT/DL/sched_ext data structures
no real Linux lock ordering
no NO_HZ or hrtick overrun bound
```

These are not design conclusions. They are a controlled abstraction for the
next proof step.

## Relationship to Source Maps

The companion source maps are:

```text
analysis/0028-tick-runtime-budget-source-map.md
analysis/0029-fork-exec-exit-identity-propagation-map.md
```

Those maps identify the Linux code paths that this model is abstracting over.
Any future implementation candidate must refine both the model and the source
maps before changing scheduler behavior.

## Run

From this directory:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC LinuxSchedulerAuthority.tla
```

If the state space grows, prefer decomposing the model rather than weakening
the hostile assumptions.
