# Validation 0250: SchedExecLease P5A-R4 E3 Corrected Six-Boot Retry Readiness

Date: 2026-07-17

Status: the exact corrected six-boot runner and all six configurations pass a
no-build/no-boot smoke. Lossless sparsebundle compaction, unrelated orphaned
Git-temporary cleanup, APFS verification, VM restart, and the exact launch
preflight restored and proved the 12 GiB host-free storage gate. Run r2 is
launch-ready; no build or boot is credited by this readiness record.

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

Source-gate checkouts had expanded the lossless APFS sparsebundle to 19 GiB
while only 5.8 GiB remained live inside it. Job `compact-r4-e3-r5` verified
all three retained archives, APFS, and Git objects; stopped the idle Apple
Container machine; detached without force; reclaimed 6.2 GB of unused bands;
and remounted a 13 GiB sparsebundle. Host free space increased from 1.9 GiB
to 9.2 GiB without deleting or recompressing project evidence.

A separate `vrchat-on-mac` repository was concurrently consuming the host
with seven interrupted `tmp_pack_*` files. No process held them, no Git lock
existed, and `git count-objects -vH` classified all seven as 53.40 GiB of
garbage. Deleting only those named Git temporaries changed its garbage count
from seven to zero and recovered host free space to 54 GiB. This did not
modify Linux-cap source, archives, or evidence. The case-sensitive volume
then passed another read-only APFS verification, the VM restarted cleanly,
and the exact r2 preflight passed with 53,436,640 KiB host free, above the
12,582,912 KiB requirement. The VM-internal ext4 scratch gate also passed.

Run `20260717T-p5a-r4-e3-six-boot-r2`, job
`p5a-r4-e3-six-boot-r2`, may now start. Its launcher still repeats all exact
input, repository-cleanliness, VM, absence, and storage gates immediately
before detached execution.

## Claim Boundary

Configuration smoke, storage recovery, and launch preflight are not build or
boot passes. The prior arm64 success is not credited toward the retry. All six
fresh boots and an independent matrix closure remain required. Source
correctness, concurrency correctness, runtime behavior, production
protection, deployment, multi-node, multi-cluster, and datacenter readiness
remain false.
