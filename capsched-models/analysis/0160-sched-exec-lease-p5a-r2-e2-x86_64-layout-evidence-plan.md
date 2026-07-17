# Analysis 0160: SchedExecLease P5A-R2 E2 x86_64 Layout Evidence Plan

Date: 2026-07-14

Status: pre-build gate for architecture-local x86_64 E2 layout evidence. No
candidate field, primary Linux patch, E3 prototype, or behavior is approved.

## Decision

Validation/0208 passed the disposable candidate on arm64, but those byte
offsets are not x86_64 evidence. The next required stage is an independent
x86_64 cross-build inside the Apple Container Linux machine.

The build uses:

```text
build host:       arm64 Linux
target:           x86_64 Linux
ARCH:             x86_64
CROSS_COMPILE:    x86_64-linux-gnu-
compiler package: gcc-x86-64-linux-gnu
```

Cross-building is sufficient for compiler layout and object evidence. It is
not x86_64 boot, runtime, latency, bare-metal, or production evidence.

## Exact Source Boundary

The E1 baseline is rebuilt from primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`. The candidate is rebuilt from
disposable commit `162d16640634637a6f7604b90bf2275bea47ec63`, parented by
that exact E1 commit. The primary patch queue remains at 0014.

The candidate delta remains exactly the four layout-only files and must retain
diff SHA-256
`645ef21d82ff3abbe64177a624846e730c30400897cd011190e9abb579aa56ee`.
No source change is authorized by this plan.

## Controlled Build Matrix

Every output directory begins from x86_64 `defconfig`, then explicitly enables
`EXPERT`, the declared dependency of `SCHED_EXEC_LEASE`. The same compiler and
configuration procedure are used for:

```text
E1 primary:       SCHED_EXEC_LEASE=y, expanded layout probe=y
candidate off:    SCHED_EXEC_LEASE=n, probe/candidate=n
candidate on:     SCHED_EXEC_LEASE=y, probe/candidate=n
candidate probe:  SCHED_EXEC_LEASE=y, probe/candidate=y
```

Normal candidate builds must omit the probe object and candidate symbols. The
E1 probe must contain exactly 51 object-local measurement symbols. The
candidate probe must preserve every E1 symbol name and value and add exactly
the expected eight candidate offset/size symbols, for 59 total and 27 table
fields.

## x86_64 Layout Gate

Validation/0198 supplies the architecture-local 0013 size baseline:

```text
sched_entity: 320 bytes
cfs_rq:        384 bytes
rq:            3392 bytes
task_struct:   3328 bytes
```

Patch 0014 changes only build-only measurement, so the freshly rebuilt E1
probe must reproduce these four sizes. The candidate must then satisfy:

```text
sched_entity delta: 0..8 bytes
cfs_rq delta:       exactly 0
rq delta:           0..32 bytes
task_struct delta:  exactly 0
```

Preserving all 51 E1 symbol values is the stronger protected-offset gate. It
mechanically covers the expanded flag, vruntime, average, cfs_rq, rq hot-field,
cache-width, and task shadow measurements without assuming arm64 offsets. All
four candidate fields must fit their containing x86_64 structures.

## Rejection Boundary

Reject the x86_64 result if the cross compiler is absent, the target
architecture/config is wrong, source identities drift, E1 is not rebuilt,
toolchains/config procedures differ, a normal build exposes candidate state,
any E1 value changes, symbol/table counts differ, a size envelope is exceeded,
or a field exceeds its containing structure.

The result must explicitly keep these false:

```text
cross-architecture byte identity
layout candidate accepted
production hot field approved
E3 rebuild approved
runtime or denial correctness
production protection
performance or cost
deployment or datacenter readiness
```

## Next

Run validation/0209. If it passes, install only the required x86_64 cross
compiler in the Linux machine and launch the detached validation/0210 build
under the generic 30-second monitor.
