# Validation 0223: SchedExecLease P5A-R3 E2 Evidence Closure

Date: 2026-07-15

Status: passed for E3 planning only. E3 source remains unauthorized until a
separate evidence plan passes.

## Immutable Identity

```text
primary:       5e1ca3037e34823d1ba0cdd1dc04161fac170280
candidate:     63313b329e1d44901acfce30698613c38615c8d5
candidate tree:8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb
candidate diff:fe8b75cb31bb5612d2f32f95b9988c4e7796ae5b919ecd8f5dacc2e0c12ffe09
patch queue:   2a022dce54679ce5ecb86581bf55199dc28c868b
series blob:   298567f8e0bd18168222da4e64da32750b9ea818
```

The candidate is an exact direct child and changes only `init/Kconfig` and
`kernel/sched/exec_lease.c`. Twenty-eight goal-relevant primary/candidate
working files were re-hashed against their HEAD blobs; all matched.

## Independent ELF Recheck

Closure command:

```text
RUN_ID=20260715T-p5a-r3-e2-closure \
  capsched/capsched-models/validation/
    run-sched-exec-lease-p5a-r3-e2-evidence-closure.sh
```

The closure re-extracted every stored ELF table rather than trusting the build
result booleans. For each of arm64 and x86_64 it confirmed:

```text
existing expanded symbols              51
existing value changes                   0
private-on symbols                       43
baseline/private-off/normal private       0
private-off/normal private relocations    0
private-off/normal private strings        0
ordinary scheduler structure deltas       0/0/0/0
```

Architecture-local ordinary sizes are arm64 `320/384/3520/4160` and x86_64
`320/384/3392/3328` for `sched_entity/cfs_rq/rq/task_struct`. Candidate C's
dominant private storage is measured, not inferred:

```text
key                         64 bytes
bucket                     128 bytes
projection                 832 bytes
private rq state           448 bytes
B_max                       64
worst active bytes per rq 53696 bytes
limit                     65536 bytes
```

## Authoritative Evidence

```text
dual-arch result SHA-256:
  48a4a0f358896f0e552173f5e308970ef14dc83a58beef62caaed03e360e7038
closure result SHA-256:
  d9b63a3efd0fd6b60223190418b3baacc3c0ac2d275fd99aa594d1fe6c18efba
architecture summary SHA-256:
  5fbf2a266b5aa14567d4a3dcc6ee4fa0320b71d64a9c1cd85842fdb32877c64e
source manifest SHA-256:
  a8bfc9d63b74809b125c8262d60c22e12ad6ebfe30ce976c2a6b69b2ef77b41a
```

## Authorization

R3-E2 is complete. The exact candidate may be used only as evidence input to
a new E3 plan. E3 plan drafting may start; E3 worktree or source creation may
not start until that plan fixes and validates the same-translation-unit
synthetic prototype, B_max boundary cases, publication/work/hotplug/retirement
races, allocation faults, KUnit, KASAN, KCSAN, lockdep, work-debug, and RCU
diagnostics required by E1.

No runtime behavior, denial correctness, production layout, primary Linux or
patch-queue promotion, protection, performance, cost, deployment, or
datacenter claim is approved.
