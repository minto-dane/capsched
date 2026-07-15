# Validation 0221: SchedExecLease P5A-R3 E2 Source Gate

Date: 2026-07-15

Status: passed for the exact dual-architecture layout build only. Runtime
source, primary Linux, and patch-queue changes remain unauthorized.

## Fixed Input

```text
primary:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
candidate: 63313b329e1d44901acfce30698613c38615c8d5
tree:      8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb
diff sha:  fe8b75cb31bb5612d2f32f95b9988c4e7796ae5b919ecd8f5dacc2e0c12ffe09
```

The candidate is a direct child of the primary and changes exactly
`init/Kconfig` and `kernel/sched/exec_lease.c`. The primary branch remains at
the parent and the patch queue remains at `0014`.

## Result

Validation command:

```text
RUN_ID=20260715T-p5a-r3-e2-source-gate \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a-r3-e2-source-gate.sh
```

Authoritative result:

```text
build/source-check/sched-exec-lease-p5a-r3-e2-source-gate/
  20260715T-p5a-r3-e2-source-gate/result.json
sha256: 09d7eec60edd5d335cfe30eb43e7440b866504282f2ffa11b7d56ce073ada457
```

The gate passed the exact two-file boundary and diff hash, strict checkpatch
at 0/0/0, 13/13 private-layout anchors, zero prohibited runtime callsites,
zero exported/static-key/trace/userspace surfaces, and a 43-name unique
private symbol manifest. It also bound the run to the passed R3-E1 result and
its SHA-256.

This authorizes only fresh arm64 and x86_64 build/layout measurement. E3 source
does not start until dual-architecture E2 evidence closes separately.
