# P5A-R6-E4 exact-source E3 regression closure

Status: passed twice; post-regression authorization remains separate

Date: 2026-08-08

## Decision

The exact R6-E4 candidate completed the mandatory R6-E3 four-profile
regression with measurement disabled, and two independent read-only closures
reproduced one normalized decision.

This completes the virtual synthetic E3 regression evidence required for the
R6-E4 source. It does not itself accept the R6-E4 source or authorize timing.
A separate post-regression authorization gate must consume these two closure
results before measurement may start.

## Frozen source and regression

```text
candidate commit:
  d51ebdc657a1040e423735584775e66399f321f9
candidate parent:
  99287291f1c8e0d6c1b3ea86d121508c5547f424
candidate tree:
  0847c408be82e6c9077c2edd2d00f44ccfbe18fc
candidate diff:
  fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9

source/build gate:
  ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6
regression result:
  d4644979f3c2d186a60b21fe77e5db3fd63b9ce9b7612e971043b1adfea89f3d
profile-results array:
  0acd6dc6ae7130c58c099fe36ff94cb5ffc308c9fa01b3b5ec323a58a19bd660
artifact manifest:
  f11d08d0a4783056a27fb79a3636add0cbd1ce98871d3ee2c688cfb226b3e681
```

The retained evidence contains 72 regular files totaling 2,942,131 bytes.
The source directory is read-only, contains no symlinks or non-regular
objects, and remained byte-identical before, during, and after both closures.
Fresh kernel build trees and kernel binaries were retired after each profile.

## Canonical closures

| Run | Result SHA-256 |
| --- | --- |
| `20260808T-p5a-r6-e4-e3-regression-closure-r2` | `900674a23d0dc2065fa7aa5c718531adc958dd1163a9cd8a3cc21d518e0b52fb` |
| `20260808T-p5a-r6-e4-e3-regression-closure-r3` | `d693101362012c9ff3ea63c70dc2383c724ef71d3a24020c99b89b05c63d6eb1` |

The results differ only in `run_id`. Their byte-identical normalized
SHA-256 is:

```text
b46550c612cce7c59c033305653bff7b2c5e32a60306a4857bc45ba44a1d8e5c
```

Closure runner SHA-256:

```text
b27a5816e58cf96f1b6f6867586af66b44e7bab3242c30d59c9fd5d9eb8550c4
```

Focused closure test SHA-256:

```text
59f46355def4aba6fc5d244728486ece1661b3d9a02b5bfc6d603f57ca8026b3
```

## Independent audit

Each closure independently verified:

- four fresh configurations and build logs;
- four QEMU boots across arm64/x86_64 standard, arm64 KASAN, and x86_64
  KCSAN profiles;
- 55 ordered KTAP cases and 55 unique JSON receipts per profile, totaling
  220 cases and 220 receipts;
- zero failure, skip, timeout, compiler diagnostic, clock-skew warning, or
  classified kernel warning;
- exact config, console, KTAP, receipt, ELF-record, symbol-scan, and
  string-scan hashes;
- explicit disablement of
  `CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST` in all four configs;
- zero R6-E4 measurement symbols, strings, or console output;
- exact pushed GitHub candidate commit, parent, tree, source, and two-file
  binary diff reconstructed from a fresh shallow partial fetch;
- exact pushed patch-queue identity; and
- complete retirement of the run-owned internal-ext build scratch.

The focused harness accepted the exact fixture and rejected a modified KCSAN
console, a result pre-authorizing measurement, and a symlinked artifact. Both
closure scripts pass Bash syntax and ShellCheck at style severity.

## Validator-only first attempt

The first closure attempt stopped before producing a result because the
temporary Git 2.43 repository abbreviated diff index object names to seven
hex digits, while the retained Git 2.55 diff used twelve. Full commit, parent,
and tree identities matched and the only byte differences were the index
abbreviation length. The corrected runner fixes `--abbrev=12`, reproduces the
retained binary diff byte-for-byte, and was then used unchanged for both
canonical closures. The incomplete attempt receives no evidence credit.

## Claim boundary

The two closure results set
`e3_regression_evidence_complete_for_e4_source=true` and retain
`post_regression_authorization_required=true`.

R6-E4 source acceptance, measurement authorization, live scheduler
attachment, runtime denial correctness, monitor verification, bare-metal
validation, performance or cost claims, production protection, deployment,
multi-node, multi-cluster, and datacenter readiness remain false.
