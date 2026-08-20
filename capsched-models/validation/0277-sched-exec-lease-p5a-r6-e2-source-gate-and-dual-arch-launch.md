# SchedExecLease P5A-R6 E2 Source Gate and Dual-Architecture Launch

Date: 2026-07-25

## Decision

The exact disposable R6-E2 source candidate passes its source gate. A fresh
arm64/x86_64 four-mode-per-architecture layout matrix may be launched under
the detached 30-second monitor.

This does not accept R6-E2 layout evidence yet. E3 planning remains blocked
until the complete matrix and a separate evidence closure pass.

## Exact Source

```text
branch:      codex/p5a-r6-e2-layout
parent:      5e1ca3037e34823d1ba0cdd1dc04161fac170280
commit:      66e2fd20fc85012d7dc03649fcf4c7af583cbb94
tree:        603762b7a36d7b57e2456b90538c3ba77a1aba16
diff SHA:    1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed
remote:      fork/codex/p5a-r6-e2-layout
line delta:  208 insertions, 0 deletions
```

The signed-off commit is a direct primary child and changes exactly
`init/Kconfig` and `kernel/sched/exec_lease.c`. Primary Linux remains clean;
the patch queue remains at `16bb080da472`.

## Source Gate

Canonical run `20260725T-p5a-r6-e2-source-gate-r1` produces result SHA-256
`18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f`.

It revalidates R6-E1 result
`364c1c21b0bcb33ccda1e7dd95eb99542cf3dd4f40fcc754aee9c93b89211f62`
and passes:

- direct-parent, clean-tree, exact remote, and two-file identity;
- forward and reverse patch application;
- strict checkpatch with 0 errors, 0 warnings, and 0 checks;
- exact default-off config and explicit autogroup exclusion;
- 24/24 private type, fixed-array, digest, and mask anchors;
- one unique 49-symbol layout manifest;
- zero added function definitions or runtime callsites; and
- zero exports, static keys, tracepoints, syscalls, or file/user surfaces.

Nine focused contract mutations and VM ShellCheck pass.

## Preflight Layout

The arm64 source-only preflight compiles the candidate and existing expanded
probe objects. It measures:

```text
slot state                 768 bytes
top node                    64 bytes
rq control                  48 bytes
concrete rq state       57,344 bytes
conservative formula    74,688 bytes/rq
hard limit              98,304 bytes/rq
maximum alignment           64 bytes
```

These values are not dual-architecture credit.

## Detached Matrix

Run `20260725T-p5a-r6-e2-dual-arch-r1` is frozen to four fresh modes on each
architecture:

```text
primary baseline with existing 51-value probe
candidate with existing probe on and R6 off
candidate with existing probe and R6 on
candidate normal with both probes off
```

It must preserve all 51 existing values, emit exactly 49 R6 symbols only when
enabled, exclude disabled R6 symbols/relocations/strings, preserve zero
ordinary `sched_entity`/`cfs_rq`/`rq`/`task_struct` growth, and enforce the
private envelopes independently on arm64 and x86_64. Cross-architecture byte
identity is not required; each architecture uses its own clean baseline.

The user-visible monitor is:

```bash
cd /Users/niania/Documents/linux-cap
./tools/long-job.sh watch p5a-r6-e2-dual-arch-build 30
```

The detached VM probe survives terminal/chat closure and reports complete only
after the full result contract passes. A failed or partial matrix receives no
credit.

## Claim Boundary

No R6-E2 layout pass, E3 plan/source, selector, scheduler/cgroup attachment,
runtime behavior or denial, monitor verification, flat-CFS equivalence,
protection, bare-metal validation, performance, cost, deployment,
multi-node, multi-cluster, or datacenter readiness is claimed.
