# Validation 0086: Direct-Call Gap Closure TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched-models/formal/0055-direct-call-gap-closure-model/DirectCallGapClosure.tla
```

TLC logs:

```text
build/tlc/direct-call-gap-closure-20260701T001620Z
```

## Safe Result

```text
config: DirectCallGapClosureSafe.cfg
result: no invariant errors
states_generated=6
distinct_states=5
depth=5
```

## Unsafe Results

Each unsafe configuration produced the expected invariant violation:

```text
DirectCallGapClosureUnsafeStubBeforeGapsClosed:
  NoStubBeforeGapClosure

DirectCallGapClosureUnsafeLinuxCanonicalEnvelope:
  NoLinuxCanonicalEnvelope

DirectCallGapClosureUnsafeEntryWithoutMonitorSchema:
  NoEntryWithoutMonitorSchema

DirectCallGapClosureUnsafeLinuxSchemaDecision:
  NoLinuxSchemaDecision

DirectCallGapClosureUnsafeTimeoutShadowRefresh:
  NoTimeoutShadowRefresh

DirectCallGapClosureUnsafeControlRevokeBypass:
  NoControlRevokeBypass

DirectCallGapClosureUnsafeTracePlanAsCoverage:
  NoTraceCoverageClaim

DirectCallGapClosureUnsafeTestHookLiveEffect:
  NoTestHookLiveEffect

DirectCallGapClosureUnsafeAbiApproval:
  NoAbiApproval

DirectCallGapClosureUnsafeBehaviorChange:
  NoBehaviorChange

DirectCallGapClosureUnsafeMonitorVerified:
  NoMonitorVerifiedClaim

DirectCallGapClosureUnsafeProtectionClaim:
  NoProtectionClaim
```

## Meaning

The model supports the N-114 gate:

```text
classified gaps
  -> monitor-owned semantics modeled
  -> five high-severity direct-call gaps closed
  -> design accepted
```

It rejects treating Linux helpers, wrapper returns, schema queries, timeout
refreshes, control priority, trace plans, or test hooks as direct-call authority
or implementation approval.

## Non-Claims

This validation does not support:

```text
Linux direct-call stubs are implemented
direct-call ABI is approved
tracefs runtime coverage occurred
monitor verification occurred
behavior-changing Linux patches are approved
production protection exists
```

## Design Consequence

The next safe step is an implementation-facing direct-call closure gate: map the
five high-severity groups to concrete future Linux/monitor source anchors,
required receipts, forbidden fallbacks, and validation evidence before any
direct-call stub or ABI patch.
