# Validation 0250: SchedExecLease P5A-R4 E3 Corrected Six-Boot Retry Readiness

Date: 2026-07-17

Status: the exact corrected six-boot runner and all six configurations pass a
no-build/no-boot smoke. Launch is intentionally blocked until lossless
sparsebundle compaction restores the 12 GiB host-free storage gate.

## Locked Inputs

```text
candidate:          da9ce9159b3450c28c8faf8dceac671fb7bfeba2
source gate:        f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
closure r3:         f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
closure r4:         92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
attempt-1 rejection:c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871
runner:             184d8a0f898466474f1dc11fae7b4fa6f90b33decce78549f76173201e4d2964
```

The runner snapshots every input read-only, requires both independent
closures to agree on the same 105-artifact manifest, binds the prior 34/36
rejection, and requires the complete matrix without reduction. Each boot uses
fresh VM-internal ext4 output and is retired only after its evidence is
sealed. An interruption terminates the active child and removes only the
run-owned scratch/worktree.

## Corrected Configuration Smoke

Run `20260717T-p5a-r4-e3-six-boot-config-smoke-r3` resolved exactly:

1. arm64 standard debug
2. x86_64 standard debug
3. arm64 hotplug/fault injection
4. x86_64 hotplug/fault injection
5. arm64 generic KASAN
6. x86_64 KCSAN

The smoke result SHA-256 is
`95ab9341035cea1f389b528126f5a63f10f8528f9f3fc15f09b34a490fdbcb37`;
the six-config manifest SHA-256 is
`09b500cc0e7ed793673b1e1ec5478dca9679197b544295cbda49331f4163a673`.
It started zero builds and zero boots, emitted no kernel image or object, and
removed its internal build root plus disposable worktree.

## Storage Gate

Source-gate checkouts expanded the lossless APFS sparsebundle to 19 GiB while
only 5.8 GiB remains live inside it. Host free space fell to 1.9 GiB. The
runner requires at least 12 GiB host free and therefore cannot launch. The
existing compaction workflow verifies retained archives and Git objects,
stops the idle Apple Container machine, verifies APFS, detaches without
force, compacts unused bands, remounts, re-verifies, and restarts the machine.

No evidence is deleted or recompressed. A full retry may start only after the
compaction result and storage thresholds are read back successfully.

## Claim Boundary

Configuration smoke is not a build or boot pass. The prior arm64 success is
not credited toward the retry. All six fresh boots and an independent matrix
closure remain required. Source correctness, concurrency correctness,
runtime behavior, production protection, deployment, multi-node,
multi-cluster, and datacenter readiness remain false.
