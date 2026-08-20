# F0 Candidate-4 G6 resource repair validation

Date: 2026-08-12

## Preserved negative evidence

The public-safe observation
`f0-c4-g6-oom-incomplete-observation-v1.json` binds run
`candidate4-full-20260811T223707Z` to root commit SHA-256
`49ab8585ce760fc7e95e58a0b176e850869d2d7f7707e9afdcd6cd6a4fcfa7af`
and guardian disposition SHA-256
`fde29de961690c53fabe0ad046ef1551b5b6650153473791d4b4d45d108823d5`.
The record is non-authoritative, publishes no raw evidence, and preserves the
root-owned VM evidence location.

## Local regression

The resource-repaired exact inputs pass:

```text
F0_C4_MODEL_MEMORY_POLICY_PASS cases=12
LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=275
LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=715
LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44
status=COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY
F0_C4_AUTHORITY_CAPTURE_CONTRACT_PASS sha256=0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d platform_requirements=17 invariants=30 gates=7
F0_C4_AUTHORITY_CAPTURE_CONTRACT_MUTATIONS_PASS hostile_cases=155 derived_cases=14
F0_C4_CAPTURE_RESOURCE_POLICY_PASS cases=7
F0_C4_REDUCER_CURRENT_INPUT_BINDING_PASS cases=3
```

These are short local/VM development regressions.  They do not inherit the
failed run's authority and are not G6 or G7 evidence.

The initial reduction-boundary recheck rejected three stale predecessor input
digests before any retry was enabled.  The reducer now seals the current input
root and `be5e9564...b789` static semantic-registry digest, while the new
three-case binding regression independently derives both from current canonical
artifacts.  Clean commit
`a956de28e9d07d84b9e9f8ab2c31bb988a1d70e9` was then installed under
artifact manifest
`dc3a7b23ed3de978dfae5e17bb943a31afe04694c202613ec24f72b62345c6df`.
Launcher basic, 10 hostile, five snapshot, five-component smoke, three
guardian, one toolchain reuse, and three reducer cases all pass after install.

## Gate state

G1-G5 remain locally closed for the successor contract.  G6 is open and a fresh
retry is eligible; no complete capture exists yet.  G7 remains blocked by
absence of a complete committed G6 capture.  All external and production claims
remain false or open.
