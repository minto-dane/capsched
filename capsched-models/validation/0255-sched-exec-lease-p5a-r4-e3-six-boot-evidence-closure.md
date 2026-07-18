# Validation 0255: SchedExecLease P5A-R4 E3 Six-Boot Evidence Closure

Date: 2026-07-18

Status: fresh r4 completed the exact six-build/six-boot virtual diagnostic
matrix. Two independent read-only closures reproduce every retained artifact
and the same normalized result. N-135 is complete for virtual synthetic
protocol evidence only; source/correctness acceptance and every bare-metal,
runtime, deployment, and production claim remain false.

## Canonical Matrix

```text
run:                         20260718T-p5a-r4-e3-six-boot-r4
candidate:                   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
runner:                      3c85c01a7b3edfd0887d7f19ca68b7ce9940859f59289b861c1c32e8b09e19b1
warning classifier:          8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
result:                      4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd
boot-results:                56cd095c1107607a0526703d63ae5e8e956715a6b0d81b9828c4162d1cb1407f
retained artifact manifest:  c0869ceb96c8387c7e5df4642b8f42d1414420999a8d178efd62f1443e9a44f0
retained files / bytes:      133 / 4,156,928
```

The fixed order was arm64 standard, x86_64 standard, arm64 hotplug/fault,
x86_64 hotplug/fault, arm64 generic KASAN, and x86_64 KCSAN. Every fresh
internal-ext4 build completed before its isolated QEMU boot and was retired
only after its evidence was sealed. All six QEMU processes exited zero. Each
exact suite passed 36 cases and emitted 36 unique receipts, giving 216/216
cases and 216/216 receipts. There were zero failures, skips, timeouts,
compiler diagnostics, final clock-skew warnings, classified kernel warnings,
or enabled network devices.

Each child retains its resolved config, compiler and QEMU identity, build and
verification logs, QEMU command, console, normalized KTAP, receipt JSONL,
case set, deterministic seed set, fault ledger, warning report, and
`exec_lease.o` ELF header. The full object and kernel image were intentionally
retired with their build output; the child result retains their hash and size.
The closure audits those records and the retained ELF header, but does not
claim that a retired object or image remains available for re-hashing.

The runner removed its run-owned `/var/tmp` build root and disposable Git
worktree. Primary Linux remained
`5e1ca3037e34823d1ba0cdd1dc04161fac170280` and the patch queue remained
`16bb080da472ffabbbafd2698073eca633fb0602`.

## Independent Closure

Closure runner SHA-256 is
`4ab3bd481d6c5ceea77d11ef73fe7c8e67b1875a56962520ce236ee6eb786aa8`.
It rejects symlinks and non-regular objects, locks the exact 133-file count and
byte count, hashes the source tree before and after copying it, compares the
private read-only copy byte-for-byte, and rechecks the canonical tree after
the audit. It independently validates:

- result, boot-results, immutable-input, candidate, and all six child hashes;
- all profile-specific config requirements and forbidden sanitizer/fault
  combinations;
- build/verification logs, compiler diagnostics, and clock skew;
- ELF class, endian, relocatable type, and arm64/x86_64 architecture records;
- isolated `-nic none` QEMU commands, exact suite/panic arguments, and exit 0;
- exact ordered 36-case KTAP suites with no failure or skip;
- console-to-JSONL identity, 36 unique well-typed receipts, five 2,048-loop
  stress receipts, three exact fault receipts, seed sets, and fault ledgers;
- fail-closed warning classification over all six retained consoles;
- retired build/worktree absence, exact Git identity, and every negative
  authorization/production claim.

The focused regression test first accepts an exact copied fixture, then proves
that a one-line KCSAN-console mutation and a newly injected symlink are both
rejected before any closure result can be published.

```text
closure r1 result:      6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89
closure r2 result:      86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea
normalized r1 / r2:    239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f
```

The only removed field in normalization is `run_id`; equality therefore
reproduces the complete claim set and all locked identities, counts, and
hashes.

## Authorization Boundary

The governing N-135 plan authorizes the disposable exact-two-file draft but
explicitly sets all of the following false even after a pass:

```text
r4_e3_source_accepted
r4_e3_concurrency_correctness_accepted
r4_e4_plan_may_be_drafted
r4_e4_source_may_be_created
r4_behavior_source_may_be_created
primary_linux_may_change
patch_queue_may_change
```

Accordingly, this closure completes N-135 only as default-off virtual
synthetic protocol evidence. It does not justify source promotion, R4-E4
planning, real scheduler attachment, bare-metal correctness, denial
correctness, bounded latency, performance, monitor enforcement, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness.
A new, separately reviewed authorization gate is required before the project
may cross any of those boundaries.
