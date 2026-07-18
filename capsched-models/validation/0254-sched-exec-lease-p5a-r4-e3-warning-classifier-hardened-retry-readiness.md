# Validation 0254: SchedExecLease P5A-R4 E3 Warning-Classifier-Hardened Retry Readiness

Date: 2026-07-18

Status: the attempt-3 KCSAN lifecycle false positive is corrected and bound as
an immutable rejection input. The post-commit runner passed both pre-build
self-tests and all six exact configuration gates with zero builds and boots.
Only a complete fresh r4 six-build/six-boot retry is authorized; this record is
not a matrix pass.

## Locked Inputs

```text
candidate:             da9ce9159b3450c28c8faf8dceac671fb7bfeba2
source gate:           f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
closure r3:            f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
closure r4:            92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
attempt-1 rejection:  c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871
attempt-2 rejection:  eb02c397ce25e522eab88f346913b4284649f83201805cdd14b1afbc1a9d0564
attempt-3 rejection:  06c9f228d66a7440b6c4404e131eeef2ba31ecf94a03fa8356fa81d5ba8d815b
warning classifier:   8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
runner:                3c85c01a7b3edfd0887d7f19ca68b7ce9940859f59289b861c1c32e8b09e19b1
```

The runner snapshots the classifier into its private read-only input directory
before sourcing it. The classifier allows only exact lowercase KCSAN enabled,
strict-mode, and successful-self-test lifecycle forms. Every other
KCSAN-tagged line fails closed. Independent patterns retain real KCSAN header,
unknown-origin, value-change, and report-footer detection in addition to all
prior generic kernel diagnostic gates.

Before configuring a kernel, the runner proves that benign lifecycle fixtures
produce no report, a realistic four-line KCSAN race fixture is completely
detected, and both a generic warning and an unknown lowercase KCSAN message
are rejected. The prior receipt-ledger JSONL serializer self-test also remains
mandatory. Focused unit tests, runner syntax, immutable-input regression, and
read-only reclassification of the retained r3 KCSAN console all pass.

## Canonical Configuration Smoke

Run `20260718T-p5a-r4-e3-six-boot-config-smoke-r5` completed with exit zero.
Result SHA-256 is
`af847090d61710f6d8c77c61242911ae10a6a5240073ce710014a391919109eb`.
It binds all three rejection records, reports both self-tests passed, requires
unknown KCSAN messages to fail closed, and records zero builds, zero boots,
zero clock-skew retries, no matrix pass, and no production claim.

All six generated config files are byte-identical to the receipt-hardened r4
smoke; its deterministic six-config manifest SHA-256 remains
`bbe1eadbdbf0ac5cd1f9403bc34dc89a96a15e6ede00d6d4a25f9b018599f210`.
No object, kernel image, console, KTAP, receipt, or boot result exists in the
smoke output. Its internal build root, disposable worktree, receipt fixture,
and warning-classifier fixture were removed.

## Launch Contract

Run `20260718T-p5a-r4-e3-six-boot-r4`, job
`p5a-r4-e3-six-boot-r4`, must repeat all six fresh sequential builds and boots
without credit from attempts 1, 2, or 3. The launcher must require exact
runner/classifier/rejection hashes, clean root/capsched/Linux/patch-queue
repositories, a running VM, absent run-owned paths, at least 6 GiB
VM-internal ext4 scratch, and at least 12 GiB host free immediately before
detached launch. It must expose the existing 30-second monitor.

## Claim Boundary

Classifier and serializer self-tests plus config smoke do not accept R4-E3
source correctness, concurrency correctness, runtime behavior, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness.
All six fresh boots and an independent read-only matrix closure remain
required.
