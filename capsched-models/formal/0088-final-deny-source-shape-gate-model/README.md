# Final Deny Source Shape Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-02

## Purpose

This model refreshes the abstract final-deny retry/ineligibility gate after
analysis/0115 showed that current Linux `pick_next_task()` often returns after
`put_prev_set_next_task()` has already settled scheduler-class state.

The model distinguishes:

```text
pre-settle denial:
  allowed if the denied candidate is visible to the next picker, retry is
  bounded, selected-state caches are invalidated, and fail-closed happens only
  when the supported eligible set is exhausted.

post-settle denial:
  rejected unless a source-proved rollback exists.
```

## Safe Paths

```text
pre-settle pick A -> deny A -> mark A ineligible -> retry -> pick B -> run B
pre-settle pick only A -> deny A -> mark A ineligible -> fail closed
```

## Rejected Behaviors

Unsafe configs reject:

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
behavior, runtime-coverage, monitor-verification, protection, or
  cost-efficiency overclaims
```

## Non-Claims

This model does not approve Linux code, hook placement, task fields, rq fields,
class picker changes, scheduler behavior change, runtime denial, runtime
coverage, public ABI, monitor ABI, monitor verification, production
protection, or cost-efficiency claims.

## TLC Result

Safe TLC passed with:

```text
10 generated states
8 distinct states
depth 5
```

Unsafe configs produced 15 expected invariant violations.
