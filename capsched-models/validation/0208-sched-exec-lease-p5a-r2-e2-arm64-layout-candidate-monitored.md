# Validation 0208: SchedExecLease P5A-R2 E2 arm64 Layout Candidate

Date: 2026-07-14

Status: passed for arm64 E2 layout evidence only. The candidate remains
disposable and unaccepted.

## Completed Before Launch

```text
validation/0207 E2 plan: passed
disposable case-sensitive worktree: clean and committed
exact four-file delta: passed
git diff --check: passed
strict checkpatch: 0 errors, 0 warnings
primary Linux branch: unchanged at E1
primary patch queue: unchanged at 0014
```

## Monitored Job

```text
name: p5a-r2-e2-build
refresh interval: 30 seconds
```

The job runs fresh arm64 targeted builds for normal CONFIG off, normal CONFIG
on with the candidate disabled, and explicit layout-probe plus candidate. It
then requires all 51 E1 symbol names and values unchanged, exactly eight new
candidate symbols, 59 total symbols, and a 27-field cacheline table.

Authoritative output:

```text
build/source-check/sched-exec-lease-p5a-r2-e2-arm64-layout-candidate/
  20260713T-p5a-r2-e2-layout/result.json
```

Monitor from the project root:

```text
./tools/long-job.sh watch p5a-r2-e2-build 30
```

## Attempt History

The first authoritative attempt started at `2026-07-14T02:14:58Z` and exited
at `2026-07-14T02:16:33Z`, before any target object build. Its CONFIG-off
`olddefconfig` correctly omitted the dependency-hidden candidate symbol, but
the validation harness accepted only the alternative
`# CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE is not set` spelling. The harness
has been corrected to reject only an unexpected
`CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE=y`; both valid disabled encodings are
now accepted. The failed attempt makes no layout or build claim, and the exact
candidate source, primary Linux tree, and patch queue were unchanged.

The corrected retry started at `2026-07-14T04:23:08Z` and completed with exit
code 0. The generated result has SHA-256
`360f98bd71ed641ba410205925cdec00d55cfbaa990e2dee361798e6afb945f1`.

## Passed Result

```text
normal CONFIG off targeted build:                 passed
normal CONFIG on, candidate disabled build:       passed
normal builds omit candidate probe and symbols:   passed
explicit candidate probe build:                   passed
E1 symbols preserved:                             51/51
E1 symbol values changed:                         0
candidate symbols added:                          8
candidate probe symbols total:                    59
cacheline table fields:                           27
protected offsets unchanged:                      yes

structure                 E1 bytes   candidate bytes   delta
sched_entity              320        320               0
cfs_rq                    384        384               0
rq                        3520       3520              0
task_struct               4160       4160              0
```

All four measured deltas are zero.

Candidate field layout:

```text
sched_entity.sched_exec_summary_valid       offset 92,   size 1
sched_entity.sched_exec_min_fresh_vruntime  offset 200,  size 8
rq.sched_exec_summary_state                 offset 3508, size 1
rq.sched_exec_built_generation              offset 3512, size 8
```

The 27-field table SHA-256 is
`5d1a88d774b1de4e26ccee36dd3bafb94e97abbc2ac599832f639ee4fe2186b0`.
Primary Linux remained at `5e1ca3037e34823d1ba0cdd1dc04161fac170280`,
the disposable candidate remained at `162d16640634637a6f7604b90bf2275bea47ec63`,
and the primary patch queue remained at 0014.

## Claim Boundary

This result accepts only the arm64 layout envelope. The candidate remains
disposable and unaccepted. x86_64 E2, production hot-field acceptance, E3
rebuild, runtime behavior, denial correctness, protection, performance, cost,
deployment, and datacenter readiness remain unclaimed.
