# Validation 0208: SchedExecLease P5A-R2 E2 arm64 Layout Candidate

Date: 2026-07-13

Status: monitored build prepared; no passed arm64 layout claim is recorded
until the generated result reports `status: passed`.

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

Expected output:

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

## Claim Boundary

Until the result passes, even the arm64 envelope is pending. Regardless of the
result, the candidate remains disposable and unaccepted. x86_64 E2, E3 rebuild,
runtime behavior, denial correctness, protection, performance, cost,
deployment, and datacenter readiness remain unclaimed.
