# Implementation 0048: SchedExecLease P5A-R4 E3 Concurrency Prototype

Date: 2026-07-18

Status: the corrected direct-E2-child candidate passed the fresh N-134 source
gate and the complete r4 six-build/six-boot virtual diagnostic matrix. Two
independent read-only closures reproduce the same normalized result, completing
N-135 virtual synthetic protocol evidence. No R4-E3 source/correctness,
bare-metal, runtime, or production claim is accepted.

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

## N-135 Attempt 2 Evidence-Runner Rejection

Run `20260717T-p5a-r4-e3-six-boot-r2` built and booted the first arm64
standard-debug configuration. QEMU exited zero and the suite produced 36/36
passes, zero failures/skips, 36 receipts, and no specified warning. The
evidence runner nevertheless failed before sealing the boot because it
treated JSONL loaded with jq `--slurpfile` as a nested array. The invalid
`$receipts[0][]` traversal yielded scalar values and failed on `.fault_site`.
Validation/0251 freezes the failure and gives this boot no credit; no result
JSON was sealed and the remaining five configurations did not start.

Corrected runner SHA-256
`0fd64ef6aa75330b18a87934fde4ad32978ff077ef9189891bb6ae45920ddb06`
uses `$receipts[]`, requires the exact three non-`none` fault records with
object/string type checks, runs a synthetic JSONL serializer self-test before
any build, and binds the attempt-2 rejection record. A noncanonical
pre-commit regression smoke passed the self-test and all six configurations
with zero builds/boots. A fresh post-commit configuration smoke remains
required before a complete r3 retry may launch.

Validation/0252 records post-commit smoke
`20260717T-p5a-r4-e3-six-boot-config-smoke-r4`. It passed at result SHA-256
`b31a089f0fe04c0c604be0be1a5b34f83f143263a2a09b916c0fbe647d11571d`;
the six-config manifest SHA-256 is
`bbe1eadbdbf0ac5cd1f9403bc34dc89a96a15e6ede00d6d4a25f9b018599f210`.
The serializer self-test passed, all six configs are byte-identical to r3,
and no build, boot, object, image, console, KTAP, or boot result was produced.
Run `20260717T-p5a-r4-e3-six-boot-r3` is now authorized under the repeated
identity, cleanliness, VM, scratch, and host-storage gates.

## N-135 Attempt 3 Warning-Classifier Rejection

Run `20260717T-p5a-r4-e3-six-boot-r3` completed all six fresh builds and
boots. Five boot results were sealed at 36/36 cases, 36 receipts, and zero
failure, skip, timeout, or warning. The final x86_64 KCSAN boot also exited
QEMU zero and produced 36/36, 36 unique well-typed receipts, and the exact
three fault receipts, but the runner failed before sealing it.

Validation/0253 and machine record SHA-256
`06c9f228d66a7440b6c4404e131eeef2ba31ecf94a03fa8356fa81d5ba8d815b`
prove that case-insensitive matching of a bare `KCSAN:` alternative rejected
only `kcsan: enabled early`, `kcsan: strict mode configured`, and
`kcsan: selftest: 3/3 tests passed`. The retained console has no actual KCSAN
report header, unknown-origin line, value-change line, or report footer. This
is an evidence-runner false positive, but the incomplete matrix receives no
partial credit and all six configurations must be repeated.

## Warning-Classifier-Hardened Retry

Runner SHA-256
`3c85c01a7b3edfd0887d7f19ca68b7ce9940859f59289b861c1c32e8b09e19b1`
snapshots classifier SHA-256
`8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a`.
Only the three exact normal KCSAN lifecycle forms are allowed; every other
KCSAN-tagged line and all prior generic kernel diagnostics fail closed. A
pre-build self-test proves benign lifecycle acceptance, complete real-report
detection, generic-warning rejection, and unknown-lowercase-KCSAN rejection.
The receipt-ledger serializer self-test remains mandatory.

Validation/0254 records post-commit config smoke
`20260718T-p5a-r4-e3-six-boot-config-smoke-r5`. It passed at result SHA-256
`af847090d61710f6d8c77c61242911ae10a6a5240073ce710014a391919109eb`;
all six configs are byte-identical to prior smoke and no build or boot started.
Only complete fresh run `20260718T-p5a-r4-e3-six-boot-r4`, job
`p5a-r4-e3-six-boot-r4`, is authorized after the repeated repository, VM,
scratch, and host-storage preflight.

That exact preflight passed on 2026-07-18 with all four repositories clean,
the VM running, 30,272,456 KiB host free, and 526,349,356 KiB available on the
VM-internal ext4 path. The detached launcher still repeats every gate at
launch.

## N-135 r4 Matrix and Independent Closure

Fresh run `20260718T-p5a-r4-e3-six-boot-r4` completed all six sequential
builds and QEMU boots with exit zero. Result SHA-256 is
`4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd`;
its exact six-child `boot-results.json` SHA-256 is
`56cd095c1107607a0526703d63ae5e8e956715a6b0d81b9828c4162d1cb1407f`.
Every boot passed the exact 36-case suite and emitted 36 unique, well-typed
receipts: 216 cases and 216 receipts total, with zero failure, skip, timeout,
compiler diagnostic, final clock-skew warning, kernel-warning report, or
nonzero QEMU exit. The runner retired each fresh internal-ext4 build after
sealing its config/object/image hashes and sizes, retained ELF-header audit,
QEMU/console/KTAP/receipt/seed/fault evidence, and removed its disposable
worktree and run-owned scratch.

Validation/0255 freezes all 133 retained files (4,156,928 bytes) at manifest
SHA-256
`c0869ceb96c8387c7e5df4642b8f42d1414420999a8d178efd62f1443e9a44f0`.
Closure runner SHA-256
`4ab3bd481d6c5ceea77d11ef73fe7c8e67b1875a56962520ce236ee6eb786aa8`
copies the complete tree read-only, checks pre/copy/post manifests, then
independently revalidates every child hash and semantic contract. Closure r1
and r2 result SHA-256 values are
`6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89`
and `86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea`;
after removing only `run_id`, both results have normalized SHA-256
`239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f`.
The regression test accepts the exact fixture and rejects both a one-line
console mutation and a symlink injection.

N-135 is complete only for the default-off, virtual, synthetic protocol
evidence named by the plan. The plan still sets R4-E3 source acceptance and
concurrency-correctness acceptance false, and explicitly forbids drafting an
R4-E4 plan, creating R4-E4/behavior source, changing primary Linux, or changing
the patch queue. A new separately reviewed authorization gate is required
before any of those actions.

## Non-Claims

The six-boot virtual diagnostic matrix and its independent artifact closure are
accepted as N-135 synthetic evidence only. They do not accept R4-E3 source
correctness, concurrency correctness, bare-metal behavior, runtime behavior,
denial correctness, primary/patch promotion, bounded latency, performance,
monitor enforcement, production protection, deployment, multi-node,
multi-cluster, or datacenter readiness.
