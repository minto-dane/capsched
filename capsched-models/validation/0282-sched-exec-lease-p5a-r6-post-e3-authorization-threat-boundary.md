# P5A-R6 post-E3 authorization and threat-boundary closure

Status: passed twice; scoped R6-E3 acceptance recorded

Date: 2026-07-26

## Outcome

The source-free post-E3 gate passed twice against the same immutable inputs.
The two results differ only in `run_id`; their normalized SHA-256 is:

```text
4104da3da3ad8f76b160d45f3ffe371aa70d2c2c0d06663194989d77999e3920
```

The gate accepts only:

- exact disposable R6-E3 source commit
  `99287291f1c8e0d6c1b3ea86d121508c5547f424`;
- exact four-profile virtual synthetic correctness evidence; and
- drafting a separate source-free R6-E4 plan.

It does not accept an R6-E4 plan and does not authorize R6-E4 source.

## Canonical runs

| Run | Result SHA-256 |
| --- | --- |
| `20260726T-p5a-r6-post-e3-authorization-r1` | `7fe89e294603a5fc1b33b03d55087b8f0619db862d5a24ec5f0fa3b201119fb6` |
| `20260726T-p5a-r6-post-e3-authorization-r2` | `d8b420d729ae75243328eae183210b410daf812780cfd420a7b0f43a0f481c4b` |

Runner SHA-256:

```text
d600f1c4242a46d0619d21777100b342990f078e129d01d9b40b3280ac6fbc89
```

Authorization contract SHA-256:

```text
2d9bad93604051f6d6bbf90f0cec619cc237e311235ce3fa1e2ffbab56d10e03
```

Formal source manifest SHA-256:

```text
6ea9e39bb2f0cf041ea3f8904671ecefe0811778a311a5e5a10a8244b0579c18
```

## Evidence reclosure

Each run independently verified:

- source gate result SHA-256
  `88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25`;
- four-profile result SHA-256
  `bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be`;
- profile-results SHA-256
  `9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71`;
- two closure results with normalized SHA-256
  `3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7`;
- four fresh builds and virtual boots, 220 passed cases, 220 receipts, and
  zero failures, skips, timeouts, compiler diagnostics, clock-skew warnings,
  or kernel warning reports;
- primary Linux, patch queue, candidate parent, candidate tree, exact
  two-file diff, candidate worktree, local fork tracking ref, and remote fork
  branch identities; and
- the exact fourteen-field global claim-ledger row plus the separate runtime
  charge boundary.

## Upstream drift

The online canonical runs independently confirmed upstream
`3dab139d4795f688e4f243e40c7474df00d329d9`, 543 commits after the prior
observation.

Only `init/Kconfig` changed within the candidate path set. Its diff SHA-256 is
`2bf818b0a62bcb092a7a15c302a43bf6def37eb56f00d956aacd72de6a72e952`.
The candidate and clean-merge private `SCHED_EXEC_LEASE` Kconfig blocks are
byte-identical with SHA-256
`93bd31e2477cd4c0ac499ffc50fbd2000b79918ec7047a02b57cd19eea6b089a`.
The private `kernel/sched/exec_lease.c` remains absent upstream.

This is exact touched-path drift classification, not global upstream
freshness.

## Formal and negative validation

The safe TLA+ model generated five states, found four distinct states at depth
four, and reported no invariant violation. All 24 unsafe configurations
produced the expected `Safety` invariant counterexample.

The regression harness accepted the exact contract and rejected:

1. source-gate evidence hash tampering;
2. threat-model repository-version tampering;
3. threat-model hash tampering;
4. unclassified touched-path drift;
5. broadened source scope;
6. live scheduler authorization;
7. monitor verification overclaim;
8. production-protection overclaim; and
9. a symlinked contract.

## Remaining false claims

Both canonical results keep false every runtime scheduler, runtime denial,
runtime coverage, runtime budget, async/service, MemoryView/TLB,
device/DMA/IOMMU, monitor, cluster, bare-metal, latency, performance, cost,
production, deployment, multi-node, multi-cluster, and datacenter claim.
Primary Linux and the patch queue remain immutable.

The next permitted activity is a separately reviewed source-free R6-E4 plan.
