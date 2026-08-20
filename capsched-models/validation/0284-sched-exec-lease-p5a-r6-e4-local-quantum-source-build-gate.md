# P5A-R6-E4 local-quantum source/build gate

Status: source/build gate passed; E3 regression remains mandatory

Date: 2026-07-29

## Decision

The exact disposable R6-E4 candidate passed its fail-closed source gate and
six fresh W=1 build modes. This result freezes the source for an exact
R6-E3 four-profile regression with R6-E4 measurement disabled.

It does not yet accept the R6-E4 source for measurement. Measurement remains
blocked until that regression passes and its evidence is independently
closed. No timing sample was collected.

## Frozen candidate

```text
R6-E3 parent:
  commit  99287291f1c8e0d6c1b3ea86d121508c5547f424

R6-E4 candidate:
  branch  codex/p5a-r6-e4-local-quantum-measurement
  commit  d51ebdc657a1040e423735584775e66399f321f9
  tree    0847c408be82e6c9077c2edd2d00f44ccfbe18fc
  diff    fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9
  source  688248428ca550bc1c56e8547fa5f601a46f5e031222b89c715be72150a4ab3c
  Kconfig 33da3e2cf8ddd79112cc42ef426828eb40c05f63892e6e71bc97a65f45f182ac
  files   init/Kconfig
          kernel/sched/exec_lease.c
```

The candidate is a signed, pushed, direct child of the accepted R6-E3 source.
Its only added configuration is
`CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST`: default off, dependent on
the R6 correctness suite and built-in KUnit, and confined to the existing
same-translation-unit synthetic test boundary.

## Canonical result

```text
run:
  20260729T-p5a-r6-e4-source-gate
result:
  ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6
runner:
  4dcb62e3f0a29b62573a29a88c0a7196de2c181543c5cc0564dd9cd8c6eeb965
contract:
  cb06279b6b3fa8b975fac85d521b57672e14928c7f9738d9723f3d336f6e3ef4
implementation:
  8a7d33bedd4c22c95dcad2c99dfb3270829a999e4f9bc675770ecf4aa0f73375
```

The runner verified exact local and pushed branch identity, direct-parent
ancestry, the two-file boundary, signed-off commit identity, source and
Kconfig hashes, strict checkpatch 0 errors/0 warnings/0 checks, and immutable
plan, threat-model, and prior-plan-result inputs.

Torvalds upstream was refreshed from
`f5098b6bae761e346ebcd9da7f95622c04733cff` to
`fc02acf6ac0ccde0c805c2daa9148683cdd01ba8`, an advance of 48 commits.
Neither candidate path changed in that interval.

## Exact measurement source boundary

The implementation contains the nine planned families, 855 matrix cells,
256 warm-up pairs per cell, and 10,000 recorded alternating pairs per cell:
8,550,000 pairs in total. It emits the exact control, treatment, additional,
and availability values before sorting and computes nearest-rank statistics.

The treatment and control calls share the same lock, interrupt, timestamp,
compiler-barrier, and loop shell. Ordinary `pick_eevdf()` remains outside the
additional-time interval and the result markers state that exclusion
explicitly. The source adds no live scheduler attachment, ABI, syscall,
sysctl, tracepoint, debugfs surface, monitor path, or runtime enforcement.

Because the measurement cells call refactored R6-E3 helpers rather than
private copies, the complete four-profile R6-E3 regression is required before
source acceptance.

## Fresh dual-architecture build matrix

Each architecture used fresh output directories and W=1:

| Architecture | Modes | Existing values | Disabled artifacts | Diagnostics |
| --- | ---: | ---: | ---: | ---: |
| arm64 GCC 13.3.0 | 3/3 | 49 private + 51 expanded | 0 | 0 |
| x86_64 GCC 13.3.0 | 3/3 | 49 private + 51 expanded | 0 | 0 |

The three modes were:

1. R6-E3 enabled and R6-E4 disabled;
2. R6-E3 and R6-E4 enabled; and
3. ordinary release configuration with SchedExecLease and KUnit disabled.

Enabled objects contain all nine measurement families, raw-row markers, the
truthful EEVDF-exclusion marker, and the preserved R6-E3 suite. Disabled
objects contain no R6-E4 symbol, relocation, or string. The release build
emits no `exec_lease.o`.

## Validator integrity

Both validator scripts pass Bash syntax and ShellCheck at style severity. The
focused regression harness accepted the exact contract and rejected changes
to:

1. candidate commit identity;
2. the exact two-file scope;
3. default-off configuration;
4. `KUNIT_ALL_TESTS` exclusion;
5. matrix size;
6. raw-row preservation;
7. EEVDF exclusion;
8. the preserved R6-E3 suite;
9. current upstream identity;
10. the monitor claim;
11. measurement authorization;
12. bare-metal validation; and
13. a symlinked contract.

The Apple Container client returned exit 125 to the host-side managed
launcher before the guest process ended. The immutable guest result, progress
file, complete six-build logs, per-architecture results, archived objects,
and removal of all scratch build directories show that the runner itself
continued to its explicit 100% passed terminal state. The managed-launcher
status is therefore not used as evidence.

## Remaining false claims

The canonical result keeps false R6-E4 source acceptance, E3-regression
completion, measurement authorization, live scheduler attachment,
monitor verification, bare-metal validation, performance and cost claims,
production protection, deployment readiness, multi-node, multi-cluster, and
datacenter readiness.

The only next permitted activity is the exact-source R6-E3 four-profile
regression with R6-E4 measurement disabled, followed by an independent
read-only closure. No R6-E4 measurement may start before both pass.
