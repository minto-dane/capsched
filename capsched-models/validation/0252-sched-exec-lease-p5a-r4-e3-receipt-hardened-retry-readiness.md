# Validation 0252: SchedExecLease P5A-R4 E3 Receipt-Hardened Retry Readiness

Date: 2026-07-17

Status: the attempt-2 evidence-runner defect is corrected and bound as an
immutable rejection input. The post-commit runner passed its pre-build JSONL
serializer self-test and all six exact configuration gates with zero builds
and boots. A complete fresh r3 six-boot retry is authorized; nothing in this
record is a matrix pass.

## Locked Inputs

```text
candidate:           da9ce9159b3450c28c8faf8dceac671fb7bfeba2
source gate:         f76ea8d4aef69a89cf93be4f20dfb3ce6bfa9f25ede61cfa9b92048d775f9b24
closure r3:          f6763fbb940c42d67390cae46c20e148f86020a3c2af4431e12562c198fcf613
closure r4:          92e9918d0c04147a9b78c66744081cf165564458204a18c43501d82617318e6e
attempt-1 rejection:c67648292f091d79e752c174f4360deee6b0a22ae696d7cbf76d5fd13cc22871
attempt-2 rejection:eb02c397ce25e522eab88f346913b4284649f83201805cdd14b1afbc1a9d0564
runner:              0fd64ef6aa75330b18a87934fde4ad32978ff077ef9189891bb6ae45920ddb06
```

The runner snapshots and makes read-only the plan, source gate, both source
closures, its own source, hardening helper, and attempt-2 machine rejection.
Before configuring or building a kernel, it runs the exact JSONL slurp path
against a synthetic fixture. The generated ledger must contain three object
receipts with string fault sites and the exact allocation, migration-capacity,
and cleanup case set. The fixture and generated self-test ledgers are removed
after the check.

## Canonical Configuration Smoke

Run `20260717T-p5a-r4-e3-six-boot-config-smoke-r4`, job
`p5a-r4-e3-six-boot-config-smoke-r4`, completed with exit zero. Result
SHA-256 is
`b31a089f0fe04c0c604be0be1a5b34f83f143263a2a09b916c0fbe647d11571d`;
the deterministic six-config manifest SHA-256 is
`bbe1eadbdbf0ac5cd1f9403bc34dc89a96a15e6ede00d6d4a25f9b018599f210`.
All six config bytes are identical to corrected smoke r3.

The result binds both rejection records, reports the receipt-ledger self-test
passed, and records zero builds, zero boots, zero clock-skew retries, and no
matrix pass. Independent negative checks found no object, kernel image,
console, KTAP, or boot-result artifact. The internal build root, disposable
worktree, and self-test fixture are absent after cleanup.

## Launch Contract

Run `20260717T-p5a-r4-e3-six-boot-r3`, job
`p5a-r4-e3-six-boot-r3`, must repeat all six fresh sequential builds and boots
without credit from attempts 1 or 2. The launcher requires the exact hashes,
clean root/capsched/Linux/patch-queue repositories, a running VM, absent
run-owned paths, at least 6 GiB VM-internal ext4 scratch, and at least 12 GiB
host free immediately before detached launch. Host free was 45 GiB at this
readiness check.

## Claim Boundary

Serializer self-test and config smoke do not accept source correctness,
concurrency correctness, runtime behavior, production protection,
deployment, multi-node, multi-cluster, or datacenter readiness. All six
boots plus independent matrix closure remain required.
