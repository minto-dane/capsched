# Validation 0135: Final Deny Source Shape Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples; no
implementation or protection claim

Date: 2026-07-02

## Scope

This validation checks:

```text
formal/0088-final-deny-source-shape-gate-model/
```

It refreshes the final-deny model after analysis/0115 showed that current Linux
`pick_next_task()` may already have called `put_prev_set_next_task()` before
returning to `__schedule()`.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/final-deny-source-shape-gate-20260702T055119Z/safe \
  -config FinalDenySourceShapeGateSafe.cfg \
  FinalDenySourceShapeGate.tla
```

Unsafe configs:

```text
FinalDenySourceShapeGateUnsafe*.cfg
```

Unsafe run base:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/final-deny-source-shape-gate-20260702T055130Z
```

## Result

Safe TLC:

```text
10 generated states
8 distinct states
0 states left on queue
depth 5
```

Unsafe TLC:

```text
expected_fails=15
unexpected_passes=0
other_failures=0
```

Rejected hazards:

```text
post-settle denial without rollback
class picker cannot see ineligibility
same denied candidate is repicked
sched_ext local DSQ head livelock
core cached pick bypass
proxy donor/executor subject mismatch
fail closed while an eligible candidate exists
RETRY_TASK as authority
idle fallback as authority
sched_ext fallback as authority
behavior-change claim
runtime-coverage claim
monitor-verification claim
protection claim
cost-efficiency claim
```

## Meaning

This validation strengthens analysis/0115 by making the source-specific final
denial shape explicit:

```text
P5 denial must be pre-settle, or must carry a source-proved rollback.
P4 allow-all final observation is not enough to approve runtime denial.
```

It supports future negative-test planning for P5. It is not Linux runtime
evidence.

## Non-Claims

This is not Linux implementation, hook approval, task-field approval, rq-field
approval, scheduler behavior change, runtime denial approval, ABI approval,
runtime coverage, monitor verification, production protection, or
cost-efficiency evidence.
