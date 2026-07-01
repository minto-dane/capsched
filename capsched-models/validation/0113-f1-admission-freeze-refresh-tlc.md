# Validation 0113: F1 Admission-Freeze Refresh TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0096-f1-admission-freeze-refresh.md
analysis/f1-admission-freeze-refresh-v1.json
formal/0074-f1-admission-freeze-refresh-model/
```

## Purpose

Validate the refreshed F1 admission-freeze boundary:

```text
Fail-capable runnable authority resolution must finish before TASK_WAKING,
remote wake-list publication, or enqueue-visible publication.
```

After publication, CapSched may only perform cheap freshness validation of an
already-frozen tuple or fail closed without losing the Linux wakeup.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/f1-admission-freeze-refresh-20260701T211426Z
```

## Results

Safe configuration:

```text
config: F1AdmissionFreezeRefreshSafe.cfg
result: PASS
states_generated: 44
distinct_states: 24
states_left_on_queue: 0
depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
config: F1AdmissionFreezeRefreshUnsafeTaskWaking.cfg
target invariant: NoTaskWakingWithoutFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeWakeList.cfg
target invariant: NoWakeListWithoutFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeEnqueue.cfg
target invariant: NoEnqueueWithoutFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRunMissingGeneration.cfg
target invariant: NoRunWithIncompleteFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRunMissingDomainEpoch.cfg
target invariant: NoRunWithIncompleteFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRunMissingSchedCtx.cfg
target invariant: NoRunWithIncompleteFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRunMissingPlacement.cfg
target invariant: NoRunWithIncompleteFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRunMissingBudget.cfg
target invariant: NoRunWithIncompleteFrozenUse
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeRawCap.cfg
target invariant: NoRawCapHandleAfterPublication
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeHeavyLookup.cfg
target invariant: NoHeavyLookupAfterPublication
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeLateDenyLostWake.cfg
target invariant: NoLateDenyLostWake
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafePlacementAuthority.cfg
target invariant: NoPlacementAsAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeCurrentMint.cfg
target invariant: NoCurrentContinuationMint
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeForkAmbient.cfg
target invariant: NoForkAmbientAuthority
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2

config: F1AdmissionFreezeRefreshUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
depth: 2
```

## JSON Contract Check

Observed:

```text
source_anchors=20
frozen_tuple_requirements=11
publication_boundaries=5
path_classification=8
authority_rejections=15
unsafe_cases=15
safety_flags_false=14
safety_flags_total=14
```

## Meaning

This validation strengthens `EXEC-001`, `BUDGET-001`, and `COMPAT-001` model
evidence by making wake publication an explicit failability boundary:

```text
TASK_WAKING requires FrozenRunUse.
wake_list publication requires FrozenRunUse.
enqueue-visible state requires FrozenRunUse.
running requires complete frozen task/generation/Domain/SchedContext/placement
  and root-budget fields plus cheap validation.
raw cap handles and heavy authority lookup cannot cross publication.
late denial cannot lose the Linux wakeup.
placement, current-self wake, and fork initial runnable state are not authority.
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, task fields,
public ABI, monitor ABI, tracepoint ABI, runtime coverage, monitor
verification, behavior change, or production protection.
