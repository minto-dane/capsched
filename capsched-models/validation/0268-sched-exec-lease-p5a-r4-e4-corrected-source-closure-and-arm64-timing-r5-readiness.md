# SchedExecLease P5A-R4 E4 Corrected Source Closure and Arm64 Timing R5 Readiness

Date: 2026-07-22

## Decision

The coalesced-owner corrected source is accepted for the exact virtual
synthetic R4-E4 timing experiment. Fresh run
`20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5` passed all six
source objects and all six preserved E3 profiles with 216/216 cases and
216/216 receipts. No compiler, clock-skew, or kernel diagnostic was accepted.

The combined result SHA-256 is
`6a77daf360696e012abd239d489cb55900c005946c053a7163297b12dc8b3777`.
Its independently sealed source, configuration, regression, and boot-results
roots are respectively:

- `24be737d935dbd4f7ecca7ccbf1dd2f6cea678c9dd3cc76146af5b2a32418989`;
- `6c0be87fa2390affc44c51b9e059e98228ead1055990cd1bfd4bda90090a267a`;
- `fd55860285824aa4fe946f35cea30f50493b908be1e9ee2f85eaedf735369a00`;
- `1749d60e17bf59baa1906a684efea7868e5a339eadd5335de40972ce18059c7f`.

This closes only the source/E3 prerequisite reopened by validation/0267. It
does not retrospectively validate timing r4 and it makes no performance,
live-scheduler, or production claim.

## Independent Source/E3 Closure

Closure runner
`run-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh` at SHA-256
`dddc11a3d5fe791b4427a4df72d27f776c332d778b16192fca2d046b575280f8`
binds the exact corrected source commit
`82d91805f8e145d2403057f656e590e4bcae12f1`, tree
`44d9a2125eac6eac4c8c25f38fb6a5eae3a5bd4f`, and two-file diff
`a7cb42fe5fc6f346ba8ea009097fa15433050e79e3255d64467d7b8ad636aeb9`.
It independently checks all three helpers whose post-false-return diagnostic
re-observation was removed.

Two serial read-only closures audit exactly 270 artifacts totaling 10,871,386
bytes: 2 combined artifacts/2,033 bytes, 82 source artifacts/5,070,721 bytes,
53 configuration artifacts/1,665,227 bytes, and 133 regression artifacts/
4,133,405 bytes. Results are:

- r1 `20260722T-p5a-r4-e4-coalesced-owner-source-e3-closure-r1`:
  `313651a8eaf26daf8d29eb7634c82222f44bdd2d1b6cee840702324bbad2c57c`;
- r2 `20260722T-p5a-r4-e4-coalesced-owner-source-e3-closure-r2`:
  `10dd9320e102d452d57e08002e1d930537e669f28add02ef8e851d3ec7577d4a`.

Deleting only `run_id` produces byte-identical normalized SHA-256
`7536970108657a6cba06debc895ecc3f088818bc6aa19a4f1fdbfdbe50adb449`.
The focused closure test accepts the exact fixture and rejects combined-result
mutation, source symlink substitution, hard-IRQ source mutation,
configuration enablement, receipt mutation, and artifact removal. VM
ShellCheck also passes.

## Timing Harness R5 Readiness

The timing runner is rebound to the corrected source and the new source/E3
closure at SHA-256
`cd2f210304fae4be4586bb9bcf750e959513ff59e96796ad2a6b64a8a1a727db`.
It retains the exact 682-cell/6,820,000-pair matrix, fixed gates, fail-closed
diagnostic parsing, paused-QMP two-vCPU placement, per-progress 8 GiB host
floor, 64 MiB failure-seal reserve, 32 GiB launch host floor, and 16 GiB
VM-internal floor. The parser remains
`dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1`
and the QMP helper remains
`e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e`.

Configuration-only smoke
`20260722T-p5a-r4-e4-arm64-timing-config-smoke-r9` resolves the exact
configuration at SHA-256
`2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b`
with zero builds and boots. Forced-capacity run
`20260722T-p5a-r4-e4-host-capacity-negative-r3` fails before build, seals
result SHA-256
`5000e8ef3a628a8d6a22e6dba45ca72654f4c060911a4b1fb0027da6a170bb39`,
releases the reserve, and retires both scratch roots. Exact-positive,
valid-negative, and tamper parser tests pass. The paused-QMP mapping,
singleton-affinity, negative-fixture, and resume integration test also passes.

Apple Container machine `domainlease-dev` is configured and read back at six
vCPUs and 10,240 MiB, with `nproc=6`. The runner now defaults build jobs to
`nproc`; this accelerates only compilation. The measurement topology remains
the exact two guest vCPUs mapped and singleton-pinned before resume, so build
parallelism does not change the timing matrix or justify a performance claim.

Before launch, the sparsebundle was detached cleanly, compacted from 14 GiB to
12 GiB, reattached at the same path, and checked for exact clean primary and
candidate identities. Readback after compaction showed 52,127,908 KiB host
and 526,289,848 KiB VM-internal available space.

## Authorization Boundary

Only one fresh arm64 timing attempt, r5, is authorized. A complete clean arm64
result may authorize exact same-source x86_64 work only after independent
timing closure. A valid fixed-threshold arm64 rejection stops x86_64. Any
harness failure receives no partial evidence and requires exact root-cause
closure before another run.

No live scheduler correctness, CPU-hotplug integration, real stop/revocation,
monitor delivery, bare-metal latency, performance, cost, N-136 runtime charge,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness claim is accepted.
