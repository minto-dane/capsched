# Implementation 0040: SchedExecLease P5A-R2 0014 Expanded Layout Probe

Date: 2026-07-13

Status: source, patch-queue replay, and arm64 three-mode targeted build
validation passed.

## Linux Delta

```text
local commit: 5e1ca3037e34823d1ba0cdd1dc04161fac170280
parent:       077c948be39432971e7273b16b728172251129aa
tree:         54f685aad94f28f0027cbba18cf5e29aadce234a
```

The delta contains 55 additions in only:

```text
kernel/sched/exec_lease_layout_probe.c
```

No Kconfig, Makefile, structure, runtime function, or call site changes.

## Patch Queue

```text
patch: linux-patches/patches/capsched-linux-l0/
       0014-sched-exec_lease-Expand-build-only-layout-probe.patch
patch sha256: d3dd3641c24892a205049cf7dc0a9f1656d016c9be5bb3dc7a5cb19512d64b2e
series sha256: 7f1ea3b3f4c7083e27e3ad9b5c28210e429e920113fd3c115cdb57a4363c2c1b
patch-queue commit: 2a022dce54679ce5ecb86581bf55199dc28c868b
replay commit: 6537a57d3d4bcf61d92b0081275081d69c5ff2fd
replay tree:   54f685aad94f28f0027cbba18cf5e29aadce234a
```

Strict checkpatch passes with 0 errors and 0 warnings. The project recreation
script reapplies 0001 through 0014 and reaches the recorded replay commit and
matching tree.

## Measurement Delta

The existing 24 symbols remain. 0014 adds 27 object-local symbols for cacheline
width, the sched_entity flag area/exec/avg boundaries, and rq hot/lock/clock/
callback boundaries. The expected probe total is 51 symbols.

Candidate summary/generation/state/callback fields remain absent. This is E1
measurement infrastructure, not the disposable E2 layout candidate.

## Arm64 Validation

Runner:

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-0014-expanded-layout-probe.sh
```

It passed exact source/replay/checkpatch gates, fresh arm64 normal-off,
normal-on, and explicit-probe targeted builds, exact 51-symbol extraction, and
a 23-field cacheline table. The 24 existing symbols were preserved, 27 were
added, and none of the existing symbols was missing. Normal off/on builds omit
the probe object; the explicit build produced a 21,288-byte probe object.

The result is:

```text
build/source-check/sched-exec-lease-p5a-r2-0014-expanded-layout-probe/
  20260713T-p5a-r2-0014-expanded-probe/result.json
```

The initial post-build check used an incorrect 49-symbol ledger. The corrected
arithmetic is one cache-width symbol plus 13 offset/size pairs, or 27 added
symbols and 51 total. The correction did not change the Linux commit, replay
tree, patch, or series hashes.

## Non-Claims

0014 adds no hot field or behavior. Runtime denial correctness, coverage,
monitor enforcement, production protection, performance, cost, deployment,
and datacenter readiness remain false.
