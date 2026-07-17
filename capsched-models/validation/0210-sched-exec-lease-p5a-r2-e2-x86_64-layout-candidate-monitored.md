# Validation 0210: SchedExecLease P5A-R2 E2 x86_64 Layout Candidate

Date: 2026-07-14

Status: passed for x86_64 compiler/object layout evidence only. The layout
candidate remains disposable and unaccepted.

## Contract

Validation/0209 passed the build-launch plan. This validation installs only
the x86_64 GNU cross compiler in the existing Apple Container Linux machine,
then performs fresh same-toolchain builds of:

```text
primary E1 expanded probe
candidate normal CONFIG off scheduler objects
candidate normal CONFIG on, layout candidate disabled scheduler objects
candidate explicit layout-probe plus candidate object
```

The result must reproduce the x86_64 320/384/3392/3328 E1 size baseline,
preserve all 51 E1 symbol values, add exactly eight symbols for 59 total, emit
27 table fields, satisfy the architecture-local growth envelope, and keep all
candidate fields within their structures.

## Monitored Job

```text
name: p5a-r2-e2-x86_64-build
refresh interval: 30 seconds
result: build/source-check/sched-exec-lease-p5a-r2-e2-x86_64-layout-candidate/
        20260714T-p5a-r2-e2-x86_64-layout/result.json
```

Monitor from the project root:

```text
./tools/long-job.sh watch p5a-r2-e2-x86_64-build 30
```

## Claim Boundary

A pass is compiler/object layout evidence only. Cross-compilation is not
x86_64 boot, runtime, bare-metal, latency, protection, performance, or cost
evidence. The layout remains disposable and unaccepted; E3 remains blocked
until this result passes and a separate acceptance gate is completed.

## Attempt History

The first attempt installed the cross compiler successfully and stopped at
12%, before compiling any target object. x86_64 `defconfig` leaves `EXPERT`
disabled; because `SCHED_EXEC_LEASE` depends on `EXPERT`, `olddefconfig`
correctly removed the requested E1 probe. The common configuration procedure
now enables `EXPERT` before applying each mode. This is a harness prerequisite
correction, not a Linux or candidate source change.

The corrected retry completed with exit code 0.

## Passed Result

```text
cross compiler target/version:                      x86_64-linux-gnu / 13.3.0
fresh E1 expanded-probe build:                      passed
normal CONFIG off targeted build:                   passed
normal CONFIG on, candidate disabled build:         passed
normal builds omit candidate probe and symbols:     passed
explicit candidate-probe build:                     passed
E1 symbols preserved:                               51/51
E1 symbol values changed:                           0
candidate symbols added:                            8
candidate probe symbols total:                      59
cacheline table fields:                             27

structure                 E1 bytes   candidate bytes   delta
sched_entity              320        320               0
cfs_rq                    384        384               0
rq                        3392       3392              0
task_struct               3328       3328              0
```

All four measured deltas are zero. The candidate fields fit their containing
structures:

```text
sched_entity.sched_exec_summary_valid       offset 92,   size 1
sched_entity.sched_exec_min_fresh_vruntime  offset 200,  size 8
rq.sched_exec_summary_state                 offset 3380, size 1
rq.sched_exec_built_generation              offset 3384, size 8
```

The authoritative result SHA-256 is
`6c7f53da489b2644a2e04ea8f424fdc990e8f1c9b59a9a60089a0251c049bd21`.
The 27-field table SHA-256 is
`db45be6a5695300a4521b0d86a446311907c3290b7439eb0f2d7e2a798976c00`.
Primary Linux, disposable candidate, and patch queue identities did not move.

## Result Boundary

This completes architecture-local x86_64 E2 layout evidence and, together
with validation/0208, supplies both required architecture comparisons. It does
not itself accept the candidate, approve production hot fields, or authorize
E3. A separate cross-architecture evidence acceptance gate is next. Runtime,
boot, bare-metal, protection, performance, cost, deployment, and datacenter
claims remain false.
