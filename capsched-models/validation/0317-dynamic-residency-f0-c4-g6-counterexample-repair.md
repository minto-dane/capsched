# Dynamic Residency F0 Candidate-4 G6 Counterexample Repair Validation

## Result

The `OBS-032-DESCENDANTS-EXIT:hidden_work` counterexample is repaired without
changing the transition semantics.  The current exact-input record is
`dynamic-residency-f0-v5-supervisor-v3-candidate4-effect-repair-v1.json`.

Validated local results:

```text
LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=275
LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=715
LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44
COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY
F0_C4_AUTHORITY_CAPTURE_CONTRACT_PASS platform_requirements=17 invariants=30 gates=7
F0_C4_AUTHORITY_CAPTURE_CONTRACT_MUTATIONS_PASS hostile_cases=153 derived_cases=13
CURRENT_STATE_CONSISTENCY_PASS hostile_self_test_cases=8 mode=draft
```

The dedicated regression recreates post-leader-exit hidden-work reacquisition
by a surviving descendant and proves that descendant drain changes
`hidden_work` from `ACTIVE` to `PENDING` under an explicitly declared action
effect.  A 20-second bounded prefix of `child-bundle-producer` produced no
immediate `ProtocolReject`; the timeout is not full-run credit.

The child, parent, runner, fast validator, contract validator, hostile contract
mutations, JSON schema, exact-input hashes, durable G6 observation, handoff
projection, and semantic state consistency all pass against the same repaired
bytes in a fresh Linux VM.  The integrated checker rejects eight independent
state-drift mutations in addition to the capture contract's 153 hostile and 13
derived mutations.

The fresh VM intentionally has no installed toolchain yet.  The reducer
boundary recheck therefore fails closed before reduction with
`cannot stat toolchain root`; it must pass after the reviewed clean install and
cannot be replaced by a synthetic toolchain fixture.

```text
PENDING_CLEAN_INSTALL_AND_REDUCER_BOUNDARY_RECHECK
```

## Claim Boundary

This validation can make a clean G6 retry eligible after a reviewed install.
It does not close G6 or G7, decide any full-only local claim, accept F0, enable
R11/K0/G0, authorize TLA+, change Linux/Monitor behavior, or support protection,
performance, cost, cluster, or deployment claims.
