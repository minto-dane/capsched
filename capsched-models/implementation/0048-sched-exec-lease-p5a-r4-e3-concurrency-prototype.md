# Implementation 0048: SchedExecLease P5A-R4 E3 Concurrency Prototype

Date: 2026-07-17

Status: six-boot attempt 1 rejected the prior candidate at 34/36 in the first
arm64 boot. The corrected direct-E2-child candidate passed a fresh N-134
source gate and two independent closures. Only a complete, unreduced six-boot
retry is authorized. No R4-E3 source/correctness or runtime claim is accepted.

## Disposable Source Identity

```text
worktree: build/DomainLeaseLinux.volume/worktrees/p5a-r4-e3-concurrency-prototype
branch:   codex/p5a-r4-e3-concurrency-prototype
parent:   a429fc30252ac6af94c51d96cd4ac24e72d9f83b
commit:   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
tree:     58c6510c6f517004e37107786d006bb8333b79b8
diff sha: 096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
```

After the clean candidate, local branch, fork branch, commit, tree, and diff
were independently fixed, the 1.7 GiB disposable checkout may be retired to
reclaim space. The canonical Git objects remain in the primary repository and
on the fork; the gate recreates isolated E2/E3 checkouts from those objects.

The candidate is one direct child of the closed R4-E2 layout commit. It adds
2,821 lines and deletes none in exactly:

```text
init/Kconfig
kernel/sched/exec_lease.c
```

Primary Linux remains `5e1ca3037e34823d1ba0cdd1dc04161fac170280`,
and the patch queue remains `16bb080da472ffabbbafd2698073eca633fb0602`.

## Synthetic Boundary

`CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST` defaults to off, depends on the R4
layout probe and built-in KUnit, and registers only suite
`sched_exec_lease_r4_concurrency` in the existing translation unit. The suite
instantiates the private E2 layouts using hard IRQ work, one unbound high-
priority reclaim-capable workqueue, raw locks, refcounts, XArray/cpumask state,
and RCU. All rq/current/contribution inputs are synthetic; there is no live
scheduler hook, exported ABI, CPUHP registration, userspace surface, or
production object creation.

The hard IRQ callback is dispatch-only and takes no rq or membership lock. A
plain-record oracle independent from the private layout checks the protocol,
and each case emits a machine-readable `R4_RECEIPT`.

## Fixed Diagnostic Contract

The source implements the exact plan order of 36 deterministic cases, all six
pre-runnable allocation fault sites with clean retry, a 15-second hard wait,
and 2,048 stress iterations. It includes notifier generation/membership
restart and late admission, one-projection recovery, queue false-return paths,
publication races, current observation, migration, hotplug drain, saturation,
and RCU retirement/reference cleanup.

Strict source and commit checkpatch both report `0 errors, 0 warnings, 0
checks`. Preflight run `20260717T-p5a-r4-e3-source-preflight-r6` independently
verified the N-133 r13/r14 seals, direct-child and exact two-file identity,
additive diff and byte-preserved E2 private block, exact cases/faults/config,
dispatch/publisher/offline protocol, forbidden-surface absence, and source
object identity. Inputs were verified read-only snapshots and the source came
from isolated Git-object E2/E3 worktrees. Preflight intentionally produced no
build result and removed its temporary worktrees and scratch.

## Prior Candidate Source Gate

Source-gate attempt 1 `20260717T-p5a-r4-e3-source-gate-r1` completed all eight
fresh objects and emitted result SHA-256
`fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a`.
Independent closure then found 2.1--2.8ms future mtimes and GNU make `Clock
skew detected. Your build may be incomplete.` warnings in the x86_64 layout-
off and test-on logs. Because the old runner did not scan build warnings, its
result is invalid evidence even though the object, table, and disabled-artifact
checks passed.

Corrected run `20260717T-p5a-r4-e3-source-gate-r2` adds W=1 compiler-diagnostic
rejection. A clock-skewed initial output triggers an immediate same-target
verification build; the verification must contain zero compiler diagnostics,
future-mtime notices, or clock-skew warnings. Corrected-runner preflight
`20260717T-p5a-r4-e3-source-preflight-r7` passed the full non-build boundary
and intentionally created no source-gate result. Canonical r2 passed with zero
diagnostics/retries/skew at result SHA-256
`7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27`.

Validation/0246 copied and independently audited all 105 artifacts twice.
Closure r1/r2 result SHA-256 values are
`4daf672d70cdead4bdd7d00f40381d99b4b6f1e9807fced16f9d68ee9578df91`
and `4d2dae97f059ab73ad233e4232ce26fc27e5667cf99de5540719d62965c4af10`;
their normalized SHA-256 is
`4471b71c85762ce75b609f84649335f300029b223524795bab7f86bb4f51fd8d`.
That N-134 closure remains valid only for rejected candidate
`f9c737c93ecff48c6f512048b05b1b49f4a54ca5`.

## N-135 Attempt 1 Rejection

Validation/0247 freezes runner SHA-256
`cff384cb01a82a446b811ec90d988ddd062f08946633d78511441599f793a809`.
It binds the exact source-gate and closure inputs, uses one fresh internal-ext4
build per boot, records complete diagnostic evidence, rejects all specified
warnings, and retires each successful build only after sealing its evidence.
Configuration-smoke r2 resolved the exact arm64/x86_64 standard,
hotplug/fault, arm64 generic KASAN, and x86_64 KCSAN configs with no build or
boot. Its result SHA-256 is
`3e49336b8de70a27eddf3f9b64579d836e60614e633e34faf2fee759ca23e467`.
Run `20260717T-p5a-r4-e3-six-boot-r1` built and booted the arm64 standard-debug
configuration, then failed closed at `pass:34 fail:2 skip:0 total:36`. The
dirty-node case exposed the fixed two-round drain against a one-node-per-work
recovery protocol with 64 dirty nodes. The cancellation case exposed a
running-state counter that observed only notifier execution after releasing
the forced recovery schedule. Validation/0248 freezes the complete negative
evidence and its hashes. The remaining five boots did not start, and the
successful build scratch was removed.

The corrected candidate uses a 136-round bounded fixed-point drain with
explicit IRQ/recovery/dirty/notifier quiescence and protocol-error exhaustion.
Retire snapshots pending notifier and running/requeued recovery cancellation
state under their respective locks before releasing the forced-schedule gate.
The correction remains inside the default-off synthetic KUnit harness and
passes strict checkpatch 0/0/0.

## Corrected Source Gate and Closure

Source-gate r3 passed all eight fresh arm64/x86_64 modes at result SHA-256
`f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24`.
It preserved the 58/51 value tables, emitted zero disabled E3 artifacts, and
reported zero W=1 diagnostics. Two x86_64 initial builds detected sub-3ms
future mtimes; exact same-target verification builds were clean, so the
result retains two retries and zero final clock-skew warnings.

Validation/0249 independently copied and audited all 105 artifacts twice.
Closure r3/r4 SHA-256 values are
`f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613`
and `92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e`.
Their normalized SHA-256 is
`01ca034cf59238314882bce35eeffb617b093ca9d4e99b2bbefe48096f3c04a6`,
and both bind the prior rejection rather than treating it as a partial pass.
N-134 is complete for corrected candidate `da9ce915...`; all six boots must
now be resolved and rerun from fresh output.

## Corrected Retry Readiness

Validation/0250 freezes corrected six-boot runner SHA-256
`184d8a0f898466474f1dc11fae7b4fa6f90b33decce78549f76173201e4d2964`.
Configuration-smoke r3 resolved all six exact configs, started zero builds and
zero boots, and passed at result SHA-256
`95ab9341035cea1f389b528126f5a63f10f8528f9f3fc15f09b34a490fdbcb37`.
Its config manifest remains
`09b500cc0e7ed793673b1e1ec5478dca9679197b544295cbda49331f4163a673`.

The full retry is launch-ready but is not credited as started or passed by
this record. Lossless job `compact-r4-e3-r5` verified the three retained
archives, APFS, and Git objects, reclaimed 6.2 GB of unused sparsebundle bands,
and reduced the image from 19 GiB to 13 GiB. Seven process-free, lock-free
`tmp_pack_*` files in the unrelated `vrchat-on-mac` repository were separately
confirmed by `git count-objects -vH` as 53.40 GiB of garbage and removed; its
garbage count is now zero. No Linux-cap source, archive, or evidence was
deleted or recompressed.

After another APFS verification and VM restart, exact r2 preflight passed with
53,436,640 KiB host free against the 12,582,912 KiB requirement and sufficient
VM-internal ext4 scratch. The detached launcher repeats every identity,
cleanliness, absence, VM, and storage gate before starting job
`p5a-r4-e3-six-boot-r2`.

## Non-Claims

The committed correction does not accept R4-E3 source correctness,
concurrency correctness, runtime behavior, denial correctness, the six-boot
diagnostic matrix, primary/patch promotion, bounded latency, performance,
monitor enforcement, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness.
