# SchedExecLease P5A-R6 E3 Four-Profile Evidence Closure

Date: 2026-07-26

## Decision

The exact disposable R6-E3 candidate completed its four-profile virtual
diagnostic matrix and two independent read-only evidence closures. The
R6-E3 diagnostic evidence is complete only for the default-off synthetic
KUnit protocol represented by this candidate.

R6-E3 source or correctness acceptance, live scheduler attachment, runtime
behavior or denial correctness, bare-metal behavior, protection,
performance, deployment, multi-node, multi-cluster, and datacenter claims
remain false.

## Frozen Inputs

```text
primary Linux:
  commit  5e1ca3037e34823d1ba0cdd1dc04161fac170280

R6-E2 parent:
  commit  66e2fd20fc85012d7dc03649fcf4c7af583cbb94

disposable R6-E3:
  commit  99287291f1c8e0d6c1b3ea86d121508c5547f424
  tree    2b863b57dfe3f03609ad1a73c965874f71056e8f
  diff    2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715

patch queue:
  commit  16bb080da472ffabbbafd2698073eca633fb0602

source gate:
  result  88376403879ecc2b0a059791ba59a5bd71addd493e9c8052c2742f877f9e7f25

four-profile matrix:
  runner  4b27719906ac0078ffed06af1931eff590bd05024bfbc736b3ddc0f860a4119d
  result  bede4cbf4c5021eba080d0bd557f9e97529153e21da731ee729340ca8c2691be
  profile results
          9142a2a0ff800efbf2e9f5b5231575b6c6c47d26e14ca535265f81221e802b71

independent closure:
  runner  5b4176a7b71b246f270a95db520ea7f5410dc25551adb75dfad9b873c387481b
  r1      0dce94b2ddf3448727bf936611704e33637f9114e8668cf1311aa1274775239a
  r2      964a16b0636d7f02850b851dd1530e9c08cc6c9e0c495c6b6a3ba78a1856a514
  normalized r1/r2
          3aebe14122f4b678c56351ee07f6a0ad475f708156c3657032232b9a76c761f7
```

The candidate remains a pushed direct R6-E2 child with 1,516 insertions and
no deletions in exactly `init/Kconfig` and
`kernel/sched/exec_lease.c`. Its R6-E2 parent remains a direct child of the
unchanged primary Linux commit.

## Matrix Result

The fixed profile order was:

1. arm64 standard debug, lockdep, RCU, hotplug, and fault injection;
2. x86_64 standard debug, lockdep, RCU, hotplug, and fault injection;
3. arm64 generic KASAN with lockdep and RCU diagnostics;
4. x86_64 strict KCSAN with lockdep and RCU diagnostics.

Each profile used a fresh internal-ext build, booted only the exact
`sched_exec_lease_r6_correctness` suite in isolated QEMU, sealed its retained
evidence, and retired the build output before the next profile. Every profile
passed all 55 required cases and emitted all 55 typed receipts. The aggregate
result is 220/220 cases and 220/220 receipts, with zero failures, skips,
timeouts, compiler diagnostics, final clock-skew warnings, or classified
kernel warnings.

The retained evidence contains resolved configs, compiler and QEMU
identities, build/configuration logs, console and normalized KTAP logs,
receipt ledgers, warning reports, child results, and retained ELF header
records. Kernel images, objects, and the run-owned build tree were
intentionally deleted after sealing their hashes.

## Independent Closure

The closure locks the exact retained tree at 60 regular files and 2,659,341
bytes with manifest SHA-256
`151c877301d3f59d171fc30bf449044990e46892860c8f9d2eb4f3467b0b4ecc`.
It rejects symlinks and non-regular objects, hashes the source before and
after snapshotting, compares a private read-only copy byte-for-byte, and
rechecks the canonical tree after the audit.

Independently of the matrix result summary, it verifies:

- source-gate, plan, runner, helper, candidate, and all four child hashes;
- the exact standard, KASAN, and KCSAN configuration requirements and
  incompatible-option exclusions;
- compiler diagnostics and clock-skew scans over all retained build logs;
- ELF64, little-endian, relocatable, and architecture records;
- exact candidate kernel identity and panic-on-warning KUnit command line;
- four ordered 55-case KTAP suites with no failures or skips;
- console-to-JSONL identity, 55 unique well-typed receipts per profile, and
  the exact case set;
- fail-closed warning classification over all four retained consoles;
- retired object, image, build-scratch boundaries and exact Git identities;
- every negative authorization, runtime, production, and deployment claim.

The focused regression test accepts an exact copied fixture, then proves that
a one-line KCSAN console mutation and an injected symlink are rejected before
any closure result is published.

Two canonical closures produced the same normalized result. The only removed
field is `run_id`, so the matching normalized SHA reproduces the complete
claim set, all identities, all counts, and all retained-evidence hashes.

## Authorization Boundary

This closes the R6-E3 virtual synthetic diagnostic evidence. It does not
promote the disposable candidate and does not authorize an R6-E4 plan or
source. The governing plan still fixes these fields false:

```text
r6_e3_source_accepted
r6_e3_correctness_accepted
e4_plan_or_source_may_start
primary_linux_may_change
patch_queue_may_change
live_scheduler_attachment
runtime_behavior_approved
runtime_denial_correctness
bare_metal_validated
production_protection
deployment_ready
multi_node_ready
multi_cluster_ready
datacenter_ready
```

A new source-free authorization and threat-boundary plan must be reviewed
before any later stage may attach the protocol to live scheduler state,
promote source, or make runtime and production claims.
