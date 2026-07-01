# Final Deny Retry and Ineligibility Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks what a future final CapSched run-validation hook must do when
it denies a selected ordinary Domain candidate.

The key rule is:

```text
deny -> mark candidate ineligible -> neutralize class state -> retry with progress
or fail closed if no eligible candidate remains
```

## Safe Paths

The safe model has two paths:

```text
PickBad
  -> DenyCandidate
  -> RetryAfterDeny
  -> PickGoodAfterRetry
  -> CommitGood
```

and:

```text
PickOnlyBad
  -> DenyCandidate
  -> FailClosedAfterDeny
```

## Rejected Behaviors

Unsafe configs reject:

```text
running a denied candidate
retrying the same denied candidate
denying after rq->curr publication
denying without ineligibility
retrying without progress
failing closed with an eligible candidate present
running after retry without a fresh tuple
silent candidate drop
retry budget bypass
class state as authority
RETRY_TASK as authority
idle fallback as authority
sched_ext fallback as authority
core cached pick as authority
behavior, monitor-verification, or protection overclaims
```

## Run

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config FinalDenyRetryIneligibilityGateSafe.cfg \
  FinalDenyRetryIneligibilityGate.tla
```

Use a distinct `-metadir` for bulk unsafe runs.

## Non-Claims

This model does not approve Linux hooks, retry implementation, task fields,
class-state rollback, task dequeue semantics, public ABI, monitor ABI, runtime
coverage, behavior change, monitor verification, or production protection.
