# Validation 0264: SchedExecLease P5A-R4 E4 Replacement Source Closure and Arm64 Timing R2 Readiness

Date: 2026-07-20

Status: the stack-fixed replacement source has passed a fresh six-object and
six-profile regression and two independent read-only closures. Exact arm64
timing r2 is launch-ready. No timing result, x86_64 timing authorization,
live-scheduler behavior, or production claim is accepted.

## Replacement Source Identity

```text
branch:     codex/p5a-r4-e4-local-quantum-measurement
parent:     da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:     5857720dedc49f89d2367442f8fdb1a806ffa1cc
tree:       ee6e329106327a302bf63c78f2ed4fe3ddea7865
diff SHA:   d3f56505379bdb08b36e265424aa886fc4f79d2a5a1e9426c2e52c3db0912a93
files:      init/Kconfig, kernel/sched/exec_lease.c
```

Timing r1 failed closed before boot because GCC reported one 2,064-byte
notifier-test frame against the unchanged 2,048-byte `W=1` boundary. The
repair moves only the measurement cell to KUnit-managed memory. It changes no
threshold, parser rule, warning classifier, fixture lifetime, sample order,
synchronization, matrix cell, or source boundary. Strict checkpatch and focused
arm64/x86_64 E4-on `W=1` objects remain diagnostic-free.

## Fresh Replacement Regression

Detached job `p5a-r4-e4-source-e3-regression-r4`, run
`20260719T-p5a-r4-e4-source-e3-regression-r4`, exited zero. It performed all
six fresh arm64/x86_64 E3-parent, E4-off, and E4-on object builds followed by
all six standard, hotplug/fault, arm64 KASAN, and x86_64 KCSAN profiles.

```text
combined result:  2b90c47e69c4c190029bc0fb2b25e66db68f87ec16f0a4d4034f4741caf5d7ea
source result:    00789ead0416102b1eba78b570337ccf49ad0c01beee9a1b8811fb857aa09a1e
config result:    452b32f0487d8faf647cd3e7e552fde7bfd757946ed0a5f7dc4f0e4bee6826d3
regression result:9333640ccde66c32ca0fabdcbd43abdf84684c0ba70b8e45e826a5c6b555f944
boot results:     2dc157c325a4fa7042b3deab6b0db82eda2d371da1a66b7d3b453af2e567a857

source objects:   6/6
profiles:         6/6
cases:            216/216
typed receipts:   216/216
compiler/skew/kernel warnings: 0/0/0
failures/skips/timeouts/QEMU nonzero exits: 0/0/0/0
```

The active source, regression, and combined runner SHA-256 values are
`7914d20aba6e37ba977409ed8c6b9c25601583613e8a304be78f824dc7982093`,
`7557c46bab856074511c3dbe9fa6212f07fdf0d723dc0a77352896b29168b23d`,
and `69ad5a507213c7f277b2dd42426b0ae698d61a7a926c4280b7dc145e08071b00`.
The source gate re-audits the shared hard-IRQ helper separately and enforces
per-cell migration pinning, all seven family CPU comparisons, IRQ-disabled and
preemption-depth observations, emitted state, and fail-closed drift.

## Exact Retained Artifact Seal

The four producer roots were enumerated only after the detached wrapper exited
zero. GNU `find`, byte summation, sorted relative-path SHA-256 manifests, and
the producer result seals establish:

| Root | Files | Bytes | Manifest SHA-256 |
| --- | ---: | ---: | --- |
| combined | 2 | 1,953 | `04affeb785a4adf79321c4f514c236fcc26abc90c9445f374280b4a2b62211be` |
| source | 79 | 5,085,392 | `1a08a0a3a013f22fbc8399fefbc9f04416c72a9692e2aed183d95d206959254a` |
| config | 53 | 1,663,741 | `cce4cc258d5033c98570fa87b7b8861339f35bd9a3638bb21e692cf3760df3b6` |
| regression | 133 | 4,129,488 | `b8e5069468c63b76ce7224a407e80465761a29e68645220c970438e95d6dbdf1` |
| total | 267 | 10,880,574 | four roots above |

The source-internal 76-artifact manifest file is sealed at
`b69a2ea1ed45eef445d519bcf282aebd380fb36f9d9e420e66390c7e73a3482d`.

## Independent Double Closure

Closure runner SHA-256
`271fd7a0d7ab5c62f630e52a3b20c584e9233769760d6b25b586af8182995fba`
snapshots every retained regular file, rejects symlinks and non-regular
objects, compares original before/after manifests to detect races, compares
snapshot manifests, and makes all 536 copied input files read-only.

```text
r1 run:        20260720T-p5a-r4-e4-source-e3-final-closure-r1
r1 result:     5e3ff71d2fea01b29e20b23a9bb8e1a8479d70cc847fa49aa3d33295c8040f3f
r2 run:        20260720T-p5a-r4-e4-source-e3-final-closure-r2
r2 result:     bac2aca6649c40fdf21665a0f801be1f0751ef03c437d1b506f78ba77f04f720
normalized:    767d2f9ab1bfb6e0c918c2ba0b51147ba79f236085e6985097b14e5a8da43d21
```

The normalized results are byte-identical after deleting only `run_id`.
Independent readback verifies both result seals, semantic contracts, 267-file
and 10,880,574-byte totals, 6/6 objects, 6/6 profiles, 216/216 cases and
receipts, zero diagnostics, four race checks, read-only inputs, and false
runtime/production claims. Focused controls accept the exact fixture and
reject combined-result mutation, source symlink, hard-IRQ observation
mutation, E4-enabled preserved config, receipt mutation, and artifact removal.

## Timing R2 Harness Revalidation

```text
arm64 timing runner: a3ee78f5ae1bc32a89bfb0b765a9e87da3888536c0bdb658b2f88acf71ddf392
682-cell parser:     dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
parser tests:        b057af2a23d1bbd95eff6bb165eadd81511ca8549ce609a9a5a7411f4a206db0
warning classifier:  8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
config smoke:        20260720T-p5a-r4-e4-arm64-timing-config-smoke-r6
```

Host `bash -n`, VM ShellCheck, and all parser clean/valid-negative/tamper
fixtures pass. Config smoke r6 revalidates the exact new closures and source,
resolves the two-vCPU arm64 diagnostic configuration, starts zero builds and
boots, and proves both VM-internal build scratch and worktree retired.

The runner preserves the strict build diagnostic gate that rejected r1. It
requires exactly 682 unique cells and 6,820,000 measured pairs, singleton-pins
both QEMU TCG vCPU threads before any row, fail-closes guest migration and
IRQ/preemption drift, distinguishes a complete threshold rejection from a
harness failure, disables QEMU networking, losslessly restore-verifies Image
and object archives, seals raw and derived evidence, and retires all run-owned
scratch.

## Detached Launch Boundary

Only this fresh run is authorized:

```text
job:     p5a-r4-e4-arm64-timing-r2
run:     20260720T-p5a-r4-e4-arm64-timing-r2
monitor: ./tools/long-job.sh watch p5a-r4-e4-arm64-timing-r2 30
```

The launcher must recheck the exact pushed root/capsched/Linux identities,
runner/parser/test/classifier/closure hashes, clean tracked repositories,
absence of competing build/QEMU processes and all r2-owned paths, running VM,
internal-ext4 storage, and free-space floors immediately before detach.

The exact preflight passed and the authorized run was detached at
`2026-07-20T06:12:10Z`. Immediate independent status and probe readback found
the job running in the full arm64 Image build stage on VM-internal ext4. The
30-second monitor rendered a live progress update and was then interrupted
without stopping the detached runner. The operational launcher, VM wrapper,
and fail-closed result probe are retained as
`tools/start-p5a-r4-e4-arm64-timing-r2.sh`,
`tools/run-p5a-r4-e4-arm64-timing-r2-in-machine.sh`, and
`tools/probe-p5a-r4-e4-arm64-timing-r2.sh` in the superproject.

A clean arm64 result may authorize only same-source x86_64 timing. A complete
arm64 threshold or diagnostic rejection stops x86_64. A harness failure
authorizes only root-cause analysis and another newly closed arm64 candidate.
Every completed timing result still requires independent read-only timing
evidence closure before measurement acceptance.

## Claim Boundary

This record accepts only the exact replacement source for disposable virtual
synthetic arm64 timing. It does not accept a timing result, live scheduler
attachment, CPUHP integration, real stop/revocation or monitor delivery,
N-136 charging, bare-metal latency, performance, cost, production protection,
deployment, multi-node, multi-cluster, or datacenter readiness.
