# Validation 0227: SchedExecLease P5A-R3 E3 arm64 Standard-Debug Attempt 1

Date: 2026-07-16

Status: failed as designed; immutable negative evidence. No runtime-correctness,
E4, real-scheduler, or production claim is authorized by this attempt.

## Frozen identity and result

The first boot used disposable direct-E2-child commit
`60e148fa0476c742b13a743345d1383db04fc843`. Its first fresh arm64
standard-debug image built successfully and QEMU exited zero, but the exact
suite passed only 19 of 20 cases. Case 7,
`sched_exec_bucket_test_queue_work_false_running`, failed because the first
queue while work was running legitimately installed a next invocation and
returned true; the model neither recorded that queued-next state nor made the
second queue needed to exercise the false-running branch.

The complete console additionally reported three independent implementation
defect families:

- one invalid wait-context report from `xa_store()` taking the ordinary XArray
  lock while rq and membership raw spinlocks were held;
- five ODEBUG reports because test gate `work_struct` objects lived on KUnit
  thread stacks;
- one refcount-zero report because a worker released the single work-owner
  reference while another invocation of the same work item was already queued.

The failed result directory is:

```text
build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix/
  20260716T-p5a-r3-e3-diagnostic-matrix/
```

Artifact SHA-256 values:

```text
serial.log       aa6d8007c19aca1aae93f0cb30b7623435e84e9c5bcff33229a31bc3f03601c3
ktap.log         3705e87af9f996e6c869eb763bc9ab3624ef3866a8922cc9af77c0b3db50a478
config           8dad8ed36e89d455076ea33ae2c4bdf4f310fdd3e44b90a77344e2bf20d47ad0
build.log        3f2d66b84a92ba8496b357cfadd18b6d337d67fcb3136f64160d2cef5d148d5e
qemu-command     4b9a6501db344756ae7ad6a00a18b6b93acece0369f9045dcdf0d78548b4c904
qemu-exit-code   9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa
vmlinux          c7814df0d3abdd01943e50413a2c5be111f417d76433cf8be5e66297c306eae5
Image            162edb10853d9c7c03382dd769a55e0f82c0cb10993246cdafae93460e769c12
```

## Corrective boundary

The corrected candidate is direct-E2-child commit
`be9339363a99fb31a5b7d03f3d70430d64a45593`. It keeps the same exact two-file,
default-off, same-translation-unit boundary. XArray mutation now occurs outside
the raw locks; gate work uses KUnit-managed heap lifetime with synchronous
cleanup; queue attempts are classified against a worker-start epoch; and an
already-queued next invocation retains the single work-owner reference. The
corrected source gate passed independently before any matrix rerun was allowed.
