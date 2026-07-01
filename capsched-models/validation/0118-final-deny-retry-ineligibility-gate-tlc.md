# Validation 0118: Final Deny Retry and Ineligibility Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0101-final-deny-retry-ineligibility-gate.md
analysis/final-deny-retry-ineligibility-gate-v1.json
formal/0079-final-deny-retry-ineligibility-gate-model/
```

## Purpose

Validate the N-147 gate for a future final CapSched run-validation denial. The
model checks that denial is explicit, before `rq->curr` publication,
progress-making, bounded, and fail-closed without treating Linux retry
machinery as CapSched authority.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/final-deny-retry-ineligibility-gate-20260701T225643Z
```

Safe configuration:

```text
config: FinalDenyRetryIneligibilityGateSafe.cfg
result: PASS
states_generated: 11
distinct_states: 9
states_left_on_queue: 0
depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
FinalDenyRetryIneligibilityGateUnsafeBehaviorChangeClaim.cfg
FinalDenyRetryIneligibilityGateUnsafeClassStateAuthority.cfg
FinalDenyRetryIneligibilityGateUnsafeCoreCachedPickAuthority.cfg
FinalDenyRetryIneligibilityGateUnsafeDenyAfterRqCurrCommit.cfg
FinalDenyRetryIneligibilityGateUnsafeDenyWithoutIneligible.cfg
FinalDenyRetryIneligibilityGateUnsafeFailClosedWithEligibleCandidate.cfg
FinalDenyRetryIneligibilityGateUnsafeIdleFallbackAuthority.cfg
FinalDenyRetryIneligibilityGateUnsafeMonitorVerifiedClaim.cfg
FinalDenyRetryIneligibilityGateUnsafeProtectionClaim.cfg
FinalDenyRetryIneligibilityGateUnsafeRetryBudgetIgnored.cfg
FinalDenyRetryIneligibilityGateUnsafeRetrySameCandidate.cfg
FinalDenyRetryIneligibilityGateUnsafeRetryTaskAuthority.cfg
FinalDenyRetryIneligibilityGateUnsafeRetryWithoutProgress.cfg
FinalDenyRetryIneligibilityGateUnsafeRunDeniedCandidate.cfg
FinalDenyRetryIneligibilityGateUnsafeRunWithoutFreshTupleAfterRetry.cfg
FinalDenyRetryIneligibilityGateUnsafeSchedExtFallbackAuthority.cfg
FinalDenyRetryIneligibilityGateUnsafeSilentDropWithoutRetryOrFailClosed.cfg
```

Summary:

```text
expected_fails: 17
unexpected_passes: 0
other_failures: 0
```

## JSON Contract Check

Observed:

```text
source_anchors=21
state_subjects=12
safe_paths=2
requirements=10
forbidden_substitutions=12
unsafe_cases=17
safety_flags_false=14
safety_flags_total=14
```

## Meaning

This validation strengthens `EXEC-001` and `COMPAT-001` model evidence by
requiring any future final run denial to be visible, bounded, and
progress-making.

It rejects authority replacement from:

```text
scheduler class settled state
RETRY_TASK
idle fallback
sched_ext fallback
core cached pick
clear_need_resched or silent drop behavior
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, task fields, scheduler hooks,
retry implementation, class-state rollback, task dequeue semantics, public ABI,
monitor ABI, runtime coverage, monitor implementation, monitor verification,
behavior change, or production protection.
