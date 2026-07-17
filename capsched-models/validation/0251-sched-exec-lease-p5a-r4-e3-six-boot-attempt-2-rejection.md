# Validation 0251: SchedExecLease P5A-R4 E3 Six-Boot Attempt 2 Rejection

Date: 2026-07-17

Status: rejected before the first boot result was sealed. The arm64 kernel,
KUnit suite, and receipts passed their pre-ledger checks, but the evidence
runner applied an invalid jq traversal to JSONL loaded by `--slurpfile`.
No boot is credited and the complete six-boot matrix must restart fresh.

## Locked Attempt

```text
run:       20260717T-p5a-r4-e3-six-boot-r2
job:       p5a-r4-e3-six-boot-r2
runner:    184d8a0f898466474f1dc11fae7b4fa6f90b33decce78549f76173201e4d2964
job log:   37dee6c25252f0f9a51f5855eca8274fb29b11a51bf7ec95617f0af6e95514cb
exit code: 5
```

The candidate, source-gate result, both independent closures, plan, primary
Linux, and patch queue matched their frozen identities. One fresh arm64
standard-debug kernel was built and booted. The remaining five configurations
did not start.

## Preserved Negative Evidence

The first boot had QEMU exit 0, the exact smoke-matched configuration, 36/36
required KUnit cases, no failures or skips, 36 machine-readable receipts, no
specified kernel warning report, no compiler diagnostic, and no clock-skew
warning. Key SHA-256 values are:

```text
config:    4e9ae559b9de405119794a3cce84324170986c556e77064a58138db2ad361fd2
build log: 9795ebf26f68b6e3f4b8013f80e24aa633a902161683651721b4df4cf84c9a8b
console:   4e270dd844621d094f2cd73792a7e6bfa4bee9f570b7878d3859b9a47d41adbb
KTAP:      962ed6ed95158df96196ae1837c85cb3874defa08fa12eccedb2fbeb70eff259
receipts:  fe906eaa1bfccd7fc195a77c535e571ac5a55d694a7a2f793c9c3b671bdf378b
```

This is diagnostic evidence, not a sealed boot pass. The runner never wrote
`arm64-standard-debug-result.json`, `boot-results.json`, `result.json`, or
`result.sha256`. Cleanup removed the run-owned internal build root and
disposable worktree; the retained 1.2 MiB output contains only failure
evidence.

## Root Cause and Correction Contract

For a JSONL file, jq `--slurpfile receipts` binds `$receipts` directly to an
array of objects. The old expression iterated `$receipts[0][]`, producing the
first object's scalar values and then attempted `.fault_site` on a string.
The correct traversal is `$receipts[]`.

A read-only replay over the preserved receipts validates the correction and
finds exactly three non-`none` records: both all-six allocation/cleanup cases
and the migration capacity case. The corrected runner must additionally:

1. require those three objects, case names, and string fault-site types;
2. run the same serializer against a synthetic JSONL fixture before any build;
3. bind this rejection record as an immutable input;
4. repeat the six-configuration no-build/no-boot smoke under its new hash;
5. rerun all six builds and boots from fresh output without partial credit.

Corrected runner SHA-256
`0fd64ef6aa75330b18a87934fde4ad32978ff077ef9189891bb6ae45920ddb06`
implements those serializer and self-test gates and binds the machine record
SHA-256
`eb02c397ce25e522eab88f346913b4284649f83201805cdd14b1afbc1a9d0564`.
Noncanonical regression preflight
`20260717T-p5a-r4-e3-receipt-ledger-preflight-r1` passed the synthetic JSONL
self-test and resolved all six exact configurations with zero builds and
boots. Its result SHA-256 is
`796f07d2fd60670f00f871b6e036809613689c001689cb86f9d1f3761448d2a1`.
This pre-commit run proves the fix path but does not replace the required
post-commit, hash-locked configuration smoke.

## Claim Boundary

Attempt 2 does not accept R4-E3 source or concurrency correctness. It makes no
live scheduler, runtime denial, performance, protection, deployment,
multi-node, multi-cluster, or datacenter claim.
