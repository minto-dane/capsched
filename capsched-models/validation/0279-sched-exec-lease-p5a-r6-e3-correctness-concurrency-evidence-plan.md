# SchedExecLease P5A-R6 E3 Correctness and Concurrency Evidence Plan

Date: 2026-07-26

## Decision

The source-free R6-E3 correctness and concurrency plan passes. One exact
disposable, signed-off, default-off, same-translation-unit KUnit source draft
may now be created as a direct child of R6-E2.

This does not accept E3 source or correctness. It does not authorize live
scheduler/cgroup attachment, runtime behavior or denial, E4, primary Linux or
patch-queue promotion, monitor verification, protection, performance, cost,
deployment, multi-node, multi-cluster, or datacenter claims.

## Exact Input Closure

Both complete runs bind:

```text
primary Linux:
  5e1ca3037e34823d1ba0cdd1dc04161fac170280
  tree 54f685aad94f28f0027cbba18cf5e29aadce234a

R6-E2 candidate:
  66e2fd20fc85012d7dc03649fcf4c7af583cbb94
  tree 603762b7a36d7b57e2456b90538c3ba77a1aba16
  diff 1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed

R6-E2 source gate:
  18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f

R6-E2 dual-architecture result:
  6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4

R6-E2 independent closure:
  e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8

patch queue:
  commit 16bb080da472ffabbbafd2698073eca633fb0602
  series 298567f8e0bd18168222da4e64da32750b9ea818
  tail   0014-sched-exec_lease-Expand-build-only-layout-probe.patch
```

The runner snapshots and rehashes seven tracked/build evidence inputs before
use, rechecks hashes before and after each copy, and rejects symlink inputs.
It also binds six unique primary/candidate source objects, clean tracked
trees, exact direct-child/two-file identity, 24 current source anchors, and 12
future-source absences.

## Reproduced Results

Canonical run:

```text
run:
  20260726T-p5a-r6-e3-correctness-plan-r3
result:
  7a1c6bc4079ab24b34cce54efa3817f210b07502b077e5a8bed4f0944c5eebe2
```

Independent reproduction:

```text
run:
  20260726T-p5a-r6-e3-correctness-plan-r4
result:
  6f989baf4b90f3647948d496863ef7d5024fa4d58774968cf5b7a17b15787917
```

After removing only `run_id` and the two run-specific manifest path strings,
both results are byte-identical at normalized SHA-256:

```text
604f16ab767cb209b11d59934e4e50c1c24af2187abcdda4e31fc508d4f1e516
```

Both independently reproduce:

```text
source anchors                 24/24
future absences                12/12
source object manifest          6 objects
required future case families  55
independent oracle leaves       64
mask families                    6
safe states generated          14
safe distinct states           14
complete graph depth           14
liveness properties             3
safety counterexamples         79/79
liveness counterexamples        3/3
TLC parallel workers             6
```

Both bind runner
`abc9a6d58ef85628b79ee2a93230528a2cca24026af213a9f2ff0df2b8c572ac`,
contract
`36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22`,
model
`333ff8286250efa12a65c5fb393e6ae1652ae1bca76f0629bd2bf44a330f7828`,
safe config
`f95cbabd68cdabba0ff08e78532dc56770492cdcf761119ca69f3e91d5b5b56c`,
and TLA tool
`936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`.
Their input and source-object manifest hashes also match exactly.

## Harness Corrections

Two incomplete attempts are retained as generator evidence and receive no plan
credit:

```text
r1  serially launched 79 separate TLC processes; the chat execution window
    ended after 64 safety faults and before result generation

r2  six-way parallel execution exposed TLC JVMs racing on shared extracted
    /tmp standard modules; five parser processes failed and no result formed
```

Commit `b10f0cc` parallelized independent fault runs with per-fault logs and
status files. Commit `f3e305d` then gave every parallel JVM a unique
`java.io.tmpdir`, heap, state directory, config, log, and status. Complete r3
and r4 prove 79/79 after that isolation. Neither correction changes the plan,
model, E2 source, or E2 evidence.

VM ShellCheck and 16 focused contract mutations pass. The mutations cover
closure substitution, wrong parent/scope, default-on config, oracle coupling
or shortcut, wrong query bound, logarithmic overclaim, catch-up credit, cgroup
authority, migration duplication, current conflation, invalid offline order,
reduced cases/diagnostics, and premature runtime claims.

## Exact Future Source Boundary

```text
parent:
  66e2fd20fc85012d7dc03649fcf4c7af583cbb94
branch:
  codex/p5a-r6-e3-correctness-prototype
worktree:
  build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype
files:
  init/Kconfig
  kernel/sched/exec_lease.c
config:
  CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST, default n
suite:
  sched_exec_lease_r6_correctness
```

The config depends on `SCHED_EXEC_LEASE_R6_LAYOUT_PROBE && KUNIT=y` and is not
selected normally. The draft must preserve the E2 type block, all 49 R6
layout values, all 51 existing expanded values, zero ordinary hot-object
growth, strict checkpatch 0/0/0, disabled artifact absence, and the complete
55-case independent-oracle contract.

The source gate must precede four fresh diagnostic profiles:

```text
arm64 standard debug + lockdep + RCU + hotplug + faults
x86_64 standard debug + lockdep + RCU + hotplug + faults
arm64 generic KASAN + lockdep
x86_64 KCSAN + lockdep
```

Every required case and receipt must pass with zero failure, skip, timeout, or
diagnostic warning. Complete results still require a separate evidence closure
before any source acceptance or E4 plan.

## Claim Boundary

The formal result verifies the plan's ordering and rejection obligations, not
all Linux EEVDF states. The future suite is synthetic and cannot establish
live integration correctness, current-stop latency, monitor delivery,
N-136 charging, flat-CFS equivalence, cross-class coverage, bare-metal
behavior, production protection, performance, cost, or deployment readiness.
