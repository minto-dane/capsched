# Validation 0244: SchedExecLease P5A-R4 E3 Source Gate Attempt 1 Warning Audit

Date: 2026-07-17

Status: harness false pass. Attempt 1 is immutable invalid evidence. No
diagnostic boot or R4-E3 source/correctness acceptance is authorized.

## Attempt 1

Detached job `p5a-r4-e3-source-gate`, run
`20260717T-p5a-r4-e3-source-gate-r1`, exited zero after 9,902 seconds. It
completed exact identity, direct-child, two-file, byte-preservation, strict
checkpatch, 36-case/six-fault protocol, arm64/x86_64 four-mode object, 58/51
value-preservation, disabled-artifact, and enabled-suite checks. Its provisional
result SHA-256 is:

```text
fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a
```

## Independent Warning Audit

The retained 97-file, 2.6 MiB evidence directory was scanned independently.
Arm64 logs and two x86_64 modes were clean, but these initial logs were not:

```text
x86_64-e3-layout-on-test-off-build.log
  future mtime: 2.1ms and 2.8ms
  Clock skew detected. Your build may be incomplete.
x86_64-e3-test-on-build.log
  future mtime: 2.2ms and 2.5ms
  Clock skew detected. Your build may be incomplete.
```

No C compiler diagnostic was found. This is the Apple Container shared-
filesystem millisecond clock-skew condition previously classified in
validation/0230. Nevertheless, a log explicitly stating that a build may be
incomplete cannot support a source-gate pass. The attempt-1 runner inspected
make exit status and resulting objects but did not scan build logs, so its
machine-readable `final_clock_skew_warnings` field did not exist.

## Correction

The corrected runner:

- builds every mode with `W=1`;
- rejects `file:line[:column]: warning:` and `error:` compiler diagnostics;
- detects either a future-mtime notice or `Clock skew detected`;
- immediately reruns the exact completed target when initial skew occurs;
- rejects persistent skew, future-mtime notices, or compiler diagnostics in
  the verification build;
- records the retry count and requires both W=1 diagnostics and final skew
  warnings to be zero in the atomic result.

This is verification, not warning suppression. Attempt 1 remains invalid even
if its objects appear correct. Only fresh r2 may pass the source gate.

## Non-Claims

Attempt 1 does not complete N-134, authorize any of the six QEMU boots, accept
R4-E3 source or concurrency correctness, or establish live scheduler behavior,
primary/patch promotion, monitor enforcement, performance, protection,
deployment, multi-node, multi-cluster, or datacenter readiness.
