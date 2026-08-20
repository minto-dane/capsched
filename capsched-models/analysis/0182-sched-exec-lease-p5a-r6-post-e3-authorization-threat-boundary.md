# P5A-R6 post-E3 authorization and threat boundary

Status: source-free contract awaiting canonical double execution

Date: 2026-07-26

## Decision

The completed R6-E3 evidence may support only the following three statements
after this gate passes:

1. The exact existing commit
   `99287291f1c8e0d6c1b3ea86d121508c5547f424` is accepted as a disposable,
   default-off, same-translation-unit, synthetic correctness prototype.
2. Its exact four-profile virtual protocol result is accepted as synthetic
   correctness evidence: four fresh builds, four virtual boots, 220 passed
   cases, 220 receipts, and no failure, skip, timeout, compiler diagnostic,
   clock-skew warning, or kernel warning report.
3. A separate source-free R6-E4 plan may be drafted.

This decision does not accept an R6-E4 plan or authorize R6-E4 source.

## Threat-boundary basis

The repository threat model is bound by target identifier, repository commit,
and SHA-256 in the machine contract. It separates:

- runtime Linux source from private disposable prototypes and evidence tools;
- userspace/kernel, task/domain, Linux/monitor, monitor/hardware,
  synchronous/async, node/cluster, and supply-chain trust boundaries;
- scheduler, async/service, MemoryView/TLB, device/DMA/IOMMU, monitor,
  cluster, and supply-chain claim classes.

The current repository has no implemented monitor. Synthetic scheduler
evidence therefore cannot be promoted into monitor-backed protection,
memory-ownership, device-isolation, cluster-authority, or production claims.

## Closed input evidence

The gate binds the R6-E3 plan, implementation record, source-gate result,
four-profile result, profile-result manifest, two independent closure results,
and the closure runner by exact SHA-256.

The two closure results differ only in `run_id`; their normalized digest is:

```text
3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7
```

The claim-ledger row has exactly the fourteen global mandatory fields. Runtime
budget authority remains governed by the separate runtime-charge subject and
is not satisfied by R6-E3.

## Refreshed upstream observation

The local upstream observation advanced 543 commits from
`f2ec6312bf711369561bdcb22f8a63c0b118c479` to
`3dab139d4795f688e4f243e40c7474df00d329d9`.

Within the two candidate paths, only `init/Kconfig` changed. The drift adds an
unrelated Rust compiler capability probe outside the private
`SCHED_EXEC_LEASE` block. The gate independently recomputes the path list,
diff hash, merge base, clean merge tree, and byte-identical private Kconfig
block. `kernel/sched/exec_lease.c` remains absent upstream.

This is touched-path freshness for the recorded candidate, not a claim that
all upstream Linux behavior is fresh or reviewed.

## Formal fail-closed rule

Formal model 0145 permits the transition:

```text
Start -> EvidenceRecorded -> ReviewRecorded -> Authorized
```

only when all evidence, threat-model, claim-ledger, upstream-drift,
clean-merge, and exact-source-scope predicates hold. The safe model has four
distinct reachable states. Twenty-four unsafe configurations each remove one
prerequisite or introduce one forbidden mutation or claim, and each must
produce an invariant counterexample.

## Explicitly forbidden conclusions

The gate leaves false:

- live scheduler attachment, runtime scheduling, runtime denial, and runtime
  coverage;
- runtime budget authority or conflation;
- async/service, MemoryView/TLB, and device/DMA/IOMMU validation;
- monitor delivery or verified protection;
- cluster authority, bare-metal timing, performance, and cost claims;
- production protection, deployment readiness, and multi-node,
  multi-cluster, or datacenter readiness;
- mutation of primary Linux or the patch queue.

R6-E4 must begin with a new source-free plan and a separately reviewed
authorization boundary.
