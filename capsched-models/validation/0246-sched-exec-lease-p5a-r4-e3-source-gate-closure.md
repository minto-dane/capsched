# Validation 0246: SchedExecLease P5A-R4 E3 Source Gate Closure

Date: 2026-07-17

Status: passed. Canonical r1 and independent r2 closure runs agree on every
stable field and on the complete artifact manifest.

## Input Boundary

The only eligible positive source-gate input is corrected run
`20260717T-p5a-r4-e3-source-gate-r2`, result SHA-256
`7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27`.
Attempt 1 remains immutable invalid evidence at SHA-256
`fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a`.

The closure runner copies all 105 corrected artifacts into a private read-only
snapshot. It requires identical full-file manifests before, during, and after
the copy and again after audit. It then independently recomputes the candidate
Git parent/tree/two-file additive diff, every source blob, all immutable input
hashes, all eight build and verification logs, W=1/skew counts, strict style,
36 cases, six faults, 58/51 tables, disabled artifacts, child results, scratch
cleanup, and every negative claim.

## Decision Boundary

A valid canonical closure completes N-134 and authorizes only the exact fixed
six-boot diagnostic matrix. It does not accept R4-E3 source or concurrency
correctness. Those remain pending on all six boots and a separate artifact
closure. Live scheduler behavior, primary or patch-queue promotion, runtime
denial, monitor enforcement, performance, protection, deployment, multi-node,
multi-cluster, and datacenter claims remain false.

## Results

```text
source-gate r2 result:
  7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27
closure r1 result:
  4daf672d70cdead4bdd7d00f40381d99b4b6f1e9807fced16f9d68ee9578df91
closure r2 result:
  4d2dae97f059ab73ad233e4232ce26fc27e5667cf99de5540719d62965c4af10
normalized closure result:
  4471b71c85762ce75b609f84649335f300029b223524795bab7f86bb4f51fd8d
artifact snapshot manifest:
  59c42bafeb7be79310aa01095b9c98b8a20280d0fef9da5f88fccfc2feb8d80b
```

Both closures passed 105/105 artifact snapshots, eight W=1 build logs, zero
compiler diagnostics, zero initial or final skew warnings, all exact source and
Git identities, 58/51 preservation, zero disabled artifacts, and all negative
claims. N-134 is complete. Only the exact six-boot matrix may proceed.
