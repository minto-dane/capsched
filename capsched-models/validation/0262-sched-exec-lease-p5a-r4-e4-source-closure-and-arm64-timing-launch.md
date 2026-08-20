# Validation 0262: SchedExecLease P5A-R4 E4 Source Closure and Arm64 Timing Launch

Date: 2026-07-19

Status: corrected source and preserved E3 regression are independently closed.
The exact arm64 timing harness is launch-ready under detached 30-second
monitoring. No timing pass, x86_64 launch, live scheduler behavior, or
production claim is accepted.

## Corrected Combined Evidence

Canonical attempt 3 is:

```text
run:       20260719T-p5a-r4-e4-source-e3-regression-r3
candidate: 9e4cb44fd1a1f998fcc288df87dad60505e8bf18
tree:      e6feb28a29fc8c37bc46af0fbf37de30f3401a4f
diff sha:  bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2
result:    9896e12b2882ac88c7b4d57f53c59f7d245b5d3b78717df7d39097af64de8b72
```

It passed six fresh arm64/x86_64 E3-parent, E4-off, and E4-on objects and all
six standard, hotplug/fault, arm64 KASAN, and x86_64 KCSAN preserved E3
profiles. Totals are 216/216 cases and 216/216 typed receipts, with zero
compiler diagnostic, final clock-skew warning, kernel-warning report, case
failure, skip, timeout, nonzero QEMU exit, or enabled network device. The source
gate independently proves per-cell `migrate_disable()` coverage, all seven
family CPU comparisons, hard-IRQ and ordinary IRQ/preemption observations,
emitted state fields, and fail-closed migration/state drift.

## Independent Double Closure

The closure runner is sealed at SHA-256
`1f14fe997788f00209e900fe1868622f1975ae6f3c57d4001d66361c8d8d0b6b`.
Two isolated invocations snapshot and make read-only all four producer roots,
verify before/after/snapshot manifests, and audit 267 artifacts totaling
10,876,145 bytes:

```text
r1 result: c1d9afa02f516e893e0dd0f910b7d1a60a56f2c1389b9426878545ef6a691325
r2 result: 9c19029ca7c18d44ec873374c9e85327a7a81d94221b1e10538f19cd16e8633e
normalized: ff91f2517b460b4d60322ea1670aab94058a8db4246bf2e2b63b7454250f528f
```

The normalized results are byte-identical after deleting only `run_id`.
Focused controls reject a combined-result mutation, source symlink, missing
hard-IRQ observation, E4-enabled preserved config, receipt mutation, and
artifact removal. The closure accepts only the exact virtual synthetic R4-E4
source and authorizes arm64 timing. It does not accept a timing result.

## Timing Harness Seal

```text
arm64 runner:
  76ccdfd8c041e6d2b7ca7f0f19551f1c550136886bcd725cf21cd84018aea55d
682-cell parser:
  dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
parser tests:
  b057af2a23d1bbd95eff6bb165eadd81511ca8549ce609a9a5a7411f4a206db0
warning classifier:
  8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
```

The runner revalidates both closures and their normalized identity before
creating a detached candidate worktree. Source and build output live only on
VM-internal ext4. It requires the exact default-off source, builds the arm64
Image, losslessly compresses and restore-verifies the Image and
`exec_lease.o`, disables QEMU networking, and records compiler/config/build,
QEMU command, console, normalized KTAP, clock, environment, placement,
diagnostic, raw-row, parser, and artifact-manifest evidence.

The Apple Container VM exposes two allowed CPUs. The timing guest therefore
uses exactly two vCPUs, sufficient for the plan's maximum two active synthetic
rqs. Each QEMU TCG vCPU thread is pinned to a distinct allowed host CPU before
the first result row. A row before complete pinning, an unpinned thread, or any
guest migration is a harness failure. This avoids the unrelated 64-vCPU-on-two-
CPU oversubscription used by the predecessor R3 experiment while preserving
the complete R4 matrix; bucket/projection occupancy 64 remains synthetic data,
not a vCPU-count requirement.

The independent parser requires all 682 unique matrix keys, 6,820,000 recorded
pairs, seven summaries, exact per-family operation counts, 256 warmups and
10,000 measured pairs per cell, guest CPU range, zero migration/state/harness
errors, hard-IRQ state proof, monotonic statistics, and exact agreement between
source-reported and independently recomputed local/asynchronous gates. It emits
a valid completed negative decision for threshold breaches and a harness
failure for malformed or reduced evidence.

## Short Validation

```text
bash -n:                         passed
VM ShellCheck:                   passed with zero findings
exact 682-row parser fixture:    passed
valid threshold rejection:      passed as negative evidence
missing row:                     rejected
observed migration:              rejected
gate mismatch:                   rejected
unknown row key:                 rejected
summary mismatch:                rejected
final config smoke r5:           passed; builds=0 boots=0
config-smoke build scratch:      retired
config-smoke candidate worktree: retired
forced insufficient-space test: harness_failed as required
forced-failure build scratch:    retired
forced-failure worktree:         retired
```

Config smoke r1 exposed a pre-build ordering defect: the progress writer
created the output directory before the freshness check, so the runner rejected
its own path. That run started no build or boot and is immutable failed harness
evidence. The check now precedes all output creation; r2 passed the corrected
boundary and final hash-stable r5 reproduced the full configuration and cleanup
decision.

## Detached Launch Boundary

The only authorized next run is:

```text
job:     p5a-r4-e4-arm64-timing-r1
run:     20260719T-p5a-r4-e4-arm64-timing-r1
monitor: ./tools/long-job.sh watch p5a-r4-e4-arm64-timing-r1 30
```

The external launcher must recheck clean and pushed root/capsched state, exact
Linux candidate/local/fork identity, primary and patch-queue identities,
runner/parser/classifier hashes, both closure result and normalized hashes,
absence of every run-owned output/worktree/build path, running VM state,
internal-ext4 storage, host/VM free-space floors, and absence of a competing
R4-E4 build or QEMU process immediately before detach.

A clean arm64 pass may authorize only a same-source x86_64 timing run. A valid
arm64 threshold or diagnostic rejection stops x86_64. A harness failure
authorizes only failure analysis and a corrected fresh arm64 run. In every
case, an independent read-only timing-evidence closure is required before any
measurement acceptance decision.

## Claim Boundary

This gate accepts the exact R4-E4 source only for disposable virtual synthetic
timing and prepares an arm64 measurement launch. It does not prove live
scheduler attachment, CPUHP integration, real stop/revocation or monitor
delivery, N-136 runtime charging, bare-metal latency, performance, cost,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness. Primary Linux and the patch queue remain unchanged.
