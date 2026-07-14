# Validation 0213: SchedExecLease P5A-R2 E3 Rebuild Prototype

Date: 2026-07-14

Status: passed for disposable synthetic-fixture rebuild correctness only. E4
measurement planning may begin; production layout, live scheduler integration,
bounded lock hold, runtime denial, and protection remain unapproved.

## Scope

Validate implementation/0042 against analysis/0162 and validation/0212 using
the exact E2 parent, exact two-file E3 descendant, frozen primary Linux and
0014 patch queue, strict source isolation, a fresh four-mode arm64 build
matrix, symbol/config/object evidence, and filtered QEMU KUnit execution.

## Exact Identities

```text
primary Linux:  5e1ca3037e34823d1ba0cdd1dc04161fac170280
E2 parent:      162d16640634637a6f7604b90bf2275bea47ec63
E3 commit:      d1d5e78da8484c91eae70f22399c6901da680ea0
E3 tree:        aa6a5a3848415643f3b67434964b056e30421bb2
E3 diff SHA:    a5351bbdd7a6617382bdea5ca9a7546e3defd97bd4a08c9c6ccf53390a88b4ed
patch queue:    0014-sched-exec_lease-Expand-build-only-layout-probe.patch
changed files:  init/Kconfig, kernel/sched/fair.c
```

Strict checkpatch reported zero errors, warnings, and checks. The source gate
proved the frozen E2 field/probe boundary, absence of forbidden locked
operations and production call sites, and the expected enabled/disabled symbol
boundary.

## Controlled Build Matrix

Fresh arm64 outputs passed for:

```text
exact E2 parent fair.o
E3 with CONFIG_SCHED_EXEC_LEASE=n fair.o
E3 with layout candidate on and rebuild KUnit off fair.o
E3 with layout candidate/KUnit/rebuild KUnit on fair.o and Image
```

Evidence:

```text
parent fair.o:              526852 bytes, 1c099b5a578f91c264644ab4b8c0a2ac03259a643217cf22ababb6b62fa52c44
E3 lease-off fair.o:        518706 bytes, 5600863337ed5bc7cb75d7b80661d50c5147b4f2915f6a2432ead22a8dd51b92
E3 test-off fair.o:         526999 bytes, de4d93c053c7b7a4248016218b164b44d17e1c0e6365c12d3a8634b3ac098319
E3 KUnit-on fair.o:         629549 bytes, 5649fd4d2e98de516135d0cd7a14a2b994bd4e470048c96d4b6ab85263ff6885
arm64 Image SHA-256:        5b729a86b06669b72d6ffec79d073d47a00e390ee504f8bfdc4a8cbc77fa544c
parent/test-off config SHA: b75ba55592429e917e630b543496d2ad551ec6229f6b21df978df1cd80231a6f
lease-off config SHA:       0da1cc09cfe0f239dc432717fc603cbf6a1b59ddf411b91f4688175e9c996fde
KUnit-on config SHA:        1562de1f021436f27b86da63b86659ded2e7cafb3fbbfc9a0212a8a425e840e8
compiler/linker:            GCC 13.3.0 / GNU binutils 2.42
```

The first three modes contain no rebuild suite/helper symbols. The enabled
mode contains the suite and all required case symbols.

## QEMU KUnit Result

The corrected complete run used QEMU 8.2.2 with the portable `cortex-a57`
model and no emulated NIC. Run `20260714T-p5a-r2-e3-rebuild` passed:

```text
suite:                    sched_exec_lease_rebuild
required cases:           12/12 passed
failed cases:             0
skipped required cases:   0
required case families:   14
exhaustive leaf limit:    6
wrap bases:               3
QEMU exit:                0
```

Raw serial SHA-256:
`bee1013c3c9db1dea424f60669245b6a5eb34214cfeb6ef9975a300cdd2bb7a8`.

Normalized KTAP SHA-256:
`f1ec72888ab6a4cc5c30fd192355bc33a0082f4375811c57b0710c60db1a3d05`.

Result:
`build/source-check/sched-exec-lease-p5a-r2-e3-rebuild-prototype/20260714T-p5a-r2-e3-rebuild/result.json`.

Result SHA-256:
`fd4ea3fdf283d3d6251c7ac3a685a9d602a1b3dc50ba53779348ac3886d236cc`.

## Recorded Environmental Correction

The first complete compilation reached QEMU but the minimal package lacked
`efi-virtio.rom`, so the default NIC prevented Linux from starting. Disabling
the unused NIC exposed a QEMU 8.2.2 internal assertion in the broad `max` CPU
model during new SME/SVE initialization. The runner now uses `-nic none` and
`-cpu cortex-a57`. A short reuse of the already-built Image then produced all
12 passing KTAP cases before the full clean rerun was accepted.

The runner also normalizes printk timestamps and carriage returns and accepts
the kernel's current KTAP spelling with or without a separator hyphen. These
are harness portability corrections; the E3 source commit did not change.

## Acceptance and Rejection Boundary

This pass accepts only:

```text
the exact E3 two-file source as disposable correctness evidence
full rebuild correctness for the tested synthetic fixtures
E4 lock-hold measurement plan drafting
```

It does not accept the four fields for production, a primary Linux or patch
queue change, real runqueue integration, publisher/fanout/worker/picker hooks,
incremental update closure, bounded lock hold, latency/performance/cost claims,
runtime denial correctness, monitor enforcement, production protection,
deployment, or datacenter readiness.

E4 must independently define live irq-disabled rq-lock measurement, controls,
the complete size/depth matrix, sampling/statistics, architecture and
virtualization metadata, warning rejection, and the fixed 25/50 microsecond
limits before any E4 source is created.
