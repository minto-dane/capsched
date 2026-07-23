# SchedExecLease P5A-R4 E4 Arm64 Timing R7 Valid-Negative Closure

Date: 2026-07-24

## Decision

Arm64 timing r7 is complete, internally consistent, and rejected by the fixed
R4-E4 local-quantum gates. This is valid negative architecture evidence, not a
build, boot, KUnit, parser, placement, storage, or host-restart failure.

P5A-R4 E4 terminates at this boundary. The same-source x86_64 timing run,
R4-E5 planning, R4 behavior source, primary Linux promotion, and patch-queue
promotion are not authorized. The next reviewable work is a source-free
successor analysis bound to this rejection and its two independent closures.

## Complete Arm64 Result

Detached job `p5a-r4-e4-arm64-timing-r7`, run
`20260723T-p5a-r4-e4-arm64-timing-r7`, started at
`2026-07-22T21:09:41Z` and sealed complete with exit zero. Result SHA-256 is
`edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951`.

The run binds disposable R7 source commit
`4077ba840f713979c29af64f405dbde39f845d93`, parent
`da9ce9159b3450c28c8faf8dceac671fb7bfeba2`, tree
`6ce127d738618fd356ed3533ac32e5796fa72d55`, and full-diff SHA-256
`a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255`.
It also binds the two R7 source closures normalized to
`f8e184c16c4fa5315532cb067d3b66dea3a21b277942d9728a2132384a3d4ba2`
and the two R6 failure closures normalized to
`1ed1c74331eb818ea355a6c8c3d7daa03362cc8d79c8e43a236d3b49757a3c3f`.

The valid matrix contains:

```text
result rows:                    682 / 682
paired measurements:     6,820,000 / 6,820,000
KUnit cases:                       7 pass, 0 fail, 0 skip
QEMU exit:                          0
compiler diagnostics:              0
kernel warning reports:             0
clock-skew reports:                 0
malformed or missing rows:          0
duplicate or unexpected cells:      0
summary mismatches:                 0
harness observation failures:       0
rejected cells:                   362
threshold breaches:               692
```

QEMU started paused. QMP identified exactly two distinct vCPU threads, pinned
them to distinct singleton host CPUs 0 and 1, reverified mapping and affinity,
and observed zero rows before resume. The raw pinning record SHA-256 is
`854a528af21f421d843f9ae86b58bb1c5d5058257dbf45e349a6e8973f63ffd0`.

## Fixed-Gate Rejection

Independent aggregation of the 682-cell measurement table gives:

| Family | Rows | Rejected |
| --- | ---: | ---: |
| publication | 288 | 184 |
| picker/kick | 144 | 3 |
| IRQ dispatch | 9 | 4 |
| recovery | 144 | 105 |
| notifier | 48 | 48 |
| current stop | 24 | 0 |
| offline | 25 | 18 |

The 692 breach records decompose exactly as:

```text
additional_max:                 358
additional_p99:                 164
additional_p999:                160
additional_reached_base_slice:   10
```

All 184 publication rejections include a maximum breach, while no publication
cell breaches p99 or p99.9. In contrast, all 48 notifier cells breach p99,
p99.9, and maximum; recovery contributes 97 p99, 96 p99.9, and 104 maximum
breaches; offline contributes 15 p99, 15 p99.9, and 18 maximum breaches. The
result therefore contains both rare-tail failures and sustained percentile
failures. The current-stop availability family passes all 24 cells, and no
asynchronous-availability threshold appears in the failure ledger.

These are rejection facts for this exact virtual TCG environment and
disposable synthetic candidate. They are not bare-metal performance estimates
or production latency measurements.

## Artifact Integrity

The timing tree contains 58 files and 35,356,293 bytes with manifest SHA-256
`1e9a8548d5bc34bd472ff074c1661de0532e46573ed3879376d1de6d1a2e5721`.
Its 47-file raw directory is sealed by internal manifest SHA-256
`dac6a9cd4ce6e196f0ecc98f5577c54a9113ab5705ef9641e23195b8bcc42c8e`.
The eight derived files are sealed by manifest SHA-256
`5939541da45d45fcd66758952715f6b35cd5a95b7ef2e7fd4d8210c2b93f10d1`.
The complete 27-file job-control tree contains 40,130 bytes with manifest
SHA-256
`dcb05d277ec22ec30f005e757ce5c379f2661ed10793eee77b0126ed8779e12e`.

The snapshotted parser SHA-256
`dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1`
reproduces all eight derived artifacts byte-for-byte from the retained raw
rows and summaries. The measurement table, threshold JSON, and threshold TSV
SHA-256 values are respectively
`f5b9f528cbaa452b40a8b773a3fbb150eb75797c278dc232acfb69d185f2a969`,
`d6568d4f8b623b5a5631fb0a85a30fb568d4e474155c6c5ce31f124ffc94408b`,
and
`50182dc03e439cacbece2ae168d57124f22364a817bc2498931a365f43d697f3`.

The retained Image and `exec_lease.o` zstd archives verify and decompress to
source SHA-256 values
`8366912940797e067b7ad48d59561b20af1a7900c09eec389de21777b31daf74`
and
`b138644d067a317b78ca1ca70591ad272346490821cfee67ec4b1d7734365125`.
Both run-owned VM-internal scratch roots are absent.

## Independent Double Closure

Closure runner SHA-256
`8df9f1751bf8c2eed4d36882e4375c0c0007ca1f4acd83b739597098cbfb14e1`
race-checks immutable copies of both complete trees, verifies their nested
manifests, reruns the captured parser, independently aggregates family and
reason counts, checks exact KUnit/QMP/job terminals, losslessly restores the
preserved binaries, and rejects broader claims.

- closure r1 result SHA-256:
  `b5279add6127b35472cc15d2345c37c3bd1a3a4b2030fe4f87d30abe7a4297af`;
- closure r2 result SHA-256:
  `75e734bc61e239db868b426c8cf37d40677ff3a04567da72437bcdafa41a2719`;
- byte-identical normalized SHA-256 after deleting only `run_id`:
  `8ebacd3c03dee0519a978cd21a7537b729fb61267d2491b70f76f54219fa84b5`.

Focused controls accept the exact fixture and reject mutations to the top
result, raw rows, summaries, threshold table, pinning proof, compressed
object, job exit, and source-root object type.

## Successor Boundary

R4's generation fence and correctness evidence remain useful historical input,
but the measured R4 recovery/notifier implementation is not eligible for
promotion. A successor may not relax the fixed thresholds, discard failing
cells, replace the measured operation with a cheaper surrogate, or relabel
virtual TCG evidence as bare-metal performance.

The successor analysis must distinguish rare maximum-tail failures from the
notifier/recovery/offline percentile failures, preserve fail-closed generation
semantics and bounded local ownership, and define new pre-source proof
obligations before any source draft. No R5 source is authorized by this record.

## Claim Boundary

No real scheduler attachment, runtime denial, monitor delivery, N-136 runtime
charge, bare-metal latency, performance, cost, production protection,
deployment, multi-node, multi-cluster, or datacenter readiness is accepted.
