# Analysis 0171: SchedExecLease P5A-R3 E4 Arm64 Bucket Measurement Rejection

Date: 2026-07-16

Status: complete negative evidence. R3 is rejected; x86_64 and E5 are not
authorized. A separately gated successor architecture is required.

## Evidence boundary

The canonical result is run
`20260716T-p5a-r3-e4-arm64-measurement-r1` over exact candidate
`f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1`, tree
`61541cb0c8aedef941e534c73effdea1f6b3d938`, direct parent
`be9339363a99fb31a5b7d03f3d70430d64a45593`.

```text
result: build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement/
        20260716T-p5a-r3-e4-arm64-measurement-r1/result.json
SHA-256: edba124b804beeaa7a2d723027fa3a6345f2d546fb0ab861428c6a4727b5cb7b
status: rejected_r3_bucket_measurement
```

QEMU exited zero. The three KUnit cases passed, all 42 unique cells emitted
10,000 paired measurements, all source summaries had zero harness errors, the
independent parser reproduced every gate, and gated warning count was zero.
Image and object archives passed compressed-stream and restored-hash checks.
This is valid negative measurement evidence, not a build, boot, KUnit, warning,
row-completeness, or artifact-integrity failure.

## Harness recovery boundary

The original job stopped only after the clean QEMU poweroff. Its AWK parser
treated dictionary values returned by `substr()` as strings, so a valid
`1792 <= 2128` monotonic comparison took the lexical path and failed with exit
8. The `END` block overwrote it with exit 17. Explicit numeric coercion fixes
the defect; the corrected `END` block preserves the first diagnostic.

Postprocess-only recovery did not rebuild the kernel or rerun QEMU. It
revalidated the exact candidate and prerequisite result hashes, config, build
log, object records, QEMU exit, lossless artifacts and restored hashes, serial,
KUnit, rows, summaries, warnings, and gates before generating `result.json`.
The result records build and QEMU evidence reuse and `raw_inputs_modified=false`.
Two recoveries produced identical result SHA-256 values.

The original cpufreq discovery output was empty because no governor/frequency
file was exposed to the Apple Container guest. A derived availability record
now states that unavailability explicitly. This does not create a bare-metal
frequency claim.

## Rejection structure

| Family | Rejected cells | Breaches | Principal failure |
| --- | ---: | ---: | --- |
| one projection | 12/32 | 16 | 12 maximum and 4 base-slice breaches |
| hotplug | 3/5 | 4 | 3 maximum and 1 base-slice breach |
| fanout | 4/5 | 6 | 4 p99 and 2 maximum breaches |

The local projection distribution is informative but not sufficient for
acceptance. Its worst additional p99 and p999 remained 784ns and 13,696ns,
inside 5,000ns and 25,000ns, while the worst maximum reached 849,584ns. The
fixed plan rejects a single maximum over 50,000ns and any additional sample at
or above 700,000ns; those conditions fired in 12 cells.

Hotplug's worst additional maximum was 1,277,904ns. Targeted fanout passed at
one active rq, failed by two, and at 64 active rqs measured 494,241,840ns p99
and 1,660,608,240ns maximum versus 10,000,000ns and 100,000,000ns limits.
These values are TCG architecture evidence only, but the fixed virtual plan
made them terminal rejection criteria.

## Design conclusion

R3 combined two ideas whose evidence must remain separately classified:

1. generation mismatch makes a projection untrusted; and
2. the E4 availability gate requires targeted fanout to reach last settlement
   inside fixed limits.

The first remains a viable correctness primitive and already made fanout
availability-only, not authority. The second failed its fixed global
availability acceptance condition. A successor must not reintroduce
synchronous all-target settlement as that condition. Simply raising limits,
weakening maximum checks, chunking the same synchronous wait, or rerunning
another architecture would discard the immutable contract.

A successor design gate may evaluate an asynchronous settlement architecture
only if it fixes all of the following before source drafting:

- the authority-publication critical section is O(1), release-publishes a
  non-wrapping generation, and never trusts a mismatched projection;
- notification/fanout is an availability accelerator rather than authority;
- every affected rq has a bounded, coalescing recovery path with a precise
  liveness deadline or deterministic work bound;
- the picker remains O(1) and never performs allocation, unbounded traversal,
  synchronous cross-rq waiting, or implicit stale fallback;
- enqueue, dequeue, current, migration, affinity, hotplug, budget, group, and
  retirement races cannot lose the newest generation or leak work/ref state;
- repeated publication cannot starve settlement indefinitely; and
- future latency evidence separates deterministic work bounds, virtualized
  diagnostics, and eventual bare-metal claims without relabeling one as
  another.

No specific successor implementation is approved here. R3 fields and source
remain disposable. Primary Linux, patch queue, live behavior, E5, denial
correctness, monitor/cross-path coverage, protection, bare-metal latency,
performance, cost, deployment, and datacenter claims remain false.
