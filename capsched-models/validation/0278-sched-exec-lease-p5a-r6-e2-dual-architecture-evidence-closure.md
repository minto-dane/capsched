# SchedExecLease P5A-R6 E2 Dual-Architecture Evidence Closure

Date: 2026-07-26

## Decision

The exact disposable R6-E2 private layout passes its arm64/x86_64 layout gate
and a separate read-only evidence closure. R6-E2 is accepted only as bounded
layout evidence for starting a source-free R6-E3 correctness and concurrency
plan.

No R6-E3 source, runtime selector, scheduler or cgroup attachment, task
binding, behavior, denial, monitor verification, protection, performance,
cost, deployment, multi-node, multi-cluster, or datacenter claim is accepted.

## Frozen Inputs

```text
primary Linux:
  commit  5e1ca3037e34823d1ba0cdd1dc04161fac170280
  tree    54f685aad94f28f0027cbba18cf5e29aadce234a

disposable R6-E2:
  commit  66e2fd20fc85012d7dc03649fcf4c7af583cbb94
  tree    603762b7a36d7b57e2456b90538c3ba77a1aba16
  diff    1ae8a83fd083c9c96412da2db98298cc708b743fc8b6266a49e16e29c16058ed

source gate:
  18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f

dual-architecture result:
  6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4

independent closure:
  e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8
```

The candidate remains a signed-off direct primary child with 208 insertions
and no deletions in exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`. Primary Linux and patch queue
`16bb080da472ffabbbafd2698073eca633fb0602` remain unchanged.

## Completed Matrix

Run `20260725T-p5a-r6-e2-dual-arch-r1` completed all eight fresh modes:

```text
architecture  primary baseline  candidate off  candidate on  candidate normal
arm64         passed            passed         passed        passed
x86_64        passed            passed         passed        passed
```

The arm64 result is
`f7a96dc37deafee8d14cbd93c8bb8b6385e3054258dab3aef169dc94fed85759`.
The x86_64 result is
`0406cc690826211761f88001222b5ad615140201ef7942b2d6eeccc8c3818d2f`.

Each architecture preserves the 51 existing expanded-probe symbols and their
values across primary baseline, candidate-off, and candidate-on. Exactly 49
R6 private symbols exist in candidate-on. R6 symbols, relocations, and strings
are absent from primary baseline, candidate-off, and candidate-normal.

## Layout Results

```text
value                         arm64     x86_64    gate
sched_entity                    320         320  zero delta
cfs_rq                          384         384  zero delta
rq                            3,520       3,392  zero local-baseline delta
task_struct                   4,160       3,328  zero local-baseline delta
private slot state              768       1,024  <= 1,024
private top node                 64          64  <= 64
private rq control               48          48  <= 1,024
concrete private rq state    57,344      73,728  <= 74,688
conservative private total   74,688      74,688  <= 98,304
maximum alignment                64          64  <= 64
```

The x86_64 slot is exactly at its 1,024-byte ceiling. That is a pass at the
frozen inclusive bound, not spare capacity and not a performance or
production-layout claim. Cross-architecture byte equality is neither expected
nor required; comparisons use fresh architecture-local primary baselines.

## Independent Closure

Canonical closure run `20260726T-p5a-r6-e2-closure-r2` uses only the frozen
source, configs, objects, logs, and prior result as input. It does not compile
or modify Linux. It independently:

- revalidates the source gate and dual-result hashes and semantics;
- rederives the direct-child, exact two-file, diff, source-blob, clean-tree,
  and patch-queue identities;
- checks all eight resolved configs;
- hashes and requires all 14 expected ELF objects;
- re-extracts the 51 existing values and proves zero changes;
- re-extracts the exact 49-name R6 manifest;
- checks disabled symbol, relocation, and string absence in three disabled
  modes per architecture;
- rederives member ordering, alignments, fixed counts, layout values, and the
  `64 * 1024 + 127 * 64 + 1024 = 74688` conservative bound;
- independently binds every re-extracted value to each recorded
  architecture result; and
- scans all 24 build/config logs with zero warning, error, fatal, undefined
  reference, internal-compiler, or failed diagnostics.

Its manifests contain eight config hashes, 14 object hashes, 16 source blob
bindings, and a two-row architecture summary. The result directory is sealed
read-only after result hashing.

The first calibration invocation, `20260726T-p5a-r6-e2-closure-r1`, stopped
before producing a result because the validator required an explicit R6
`not set` line in candidate-normal. Kconfig correctly omits that child symbol
when its layout-probe parent is disabled. Commit `f1cc0f4` changed the gate to
the correct semantic requirement—R6 must not resolve to `y`—and the complete
r2 closure then passed. The incomplete r1 invocation receives no evidence
credit.

## R6-E3 Boundary

R6-E3 may now create a source-free, reviewable correctness and concurrency
evidence plan bound to the exact R6-E2 result and closure. At minimum it must
define:

- an independent 64-leaf selection oracle for empty, singleton, alternating,
  all-64, current-only, and revoked-current masks;
- separate aggregate and candidate visit ceilings of 127 and a complete
  ceiling of 254;
- one-leaf plus at-most-six-ancestor update and 0/1/63/64-bit reconcile
  bounds;
- no negative lag or catch-up credit after reallow;
- explicit equal-domain fairness before ordinary within-domain EEVDF
  fairness;
- fail-closed mixed hierarchy, autogroup, stale receipt, task-authority,
  migration, cgroup-move, offline, current, reference, RCU, saturation, and
  allocation-fault cases; and
- later architecture profiles for ordinary debug builds, arm64 KASAN, and
  x86_64 KCSAN/lockdep.

R6-E3 source remains forbidden until that separate plan, model, controls, and
claim ledger pass. The disposable R6-E2 commit is not promoted to primary
Linux or the patch queue.
