# Validation 0089: Direct-Call Receipt Consumer Placement TLC

Status: safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

## Model

```text
formal/0057-direct-call-receipt-consumer-placement-model/
```

The model checks N-118 placement and exclusion constraints derived from the
N-117 receipt-consumer source map.

Safe order:

```text
AcceptSourceMap
BindMonitorReceipts
DeriveLinuxShadow
BoundHotPathCheck
SeparatePolicyLifecycle
ExcludeGenericAsync
MonitorRevoke
AcceptPlacementDesign
```

## Commands

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config DirectCallReceiptConsumerPlacementSafe.cfg \
  DirectCallReceiptConsumerPlacement.tla
```

The unsafe configs were executed with the same command shape.

Logs:

```text
build/tlc/direct-call-receipt-consumer-placement-20260701T023000Z
```

## Safe Result

```text
Model checking completed. No error has been found.
10 states generated, 9 distinct states found, 0 states left on queue.
```

## Unsafe Results

All unsafe configs produced expected invariant violations:

```text
DirectCallReceiptConsumerPlacementUnsafeAbiApproval                 -> NoAbiApproval
DirectCallReceiptConsumerPlacementUnsafeBehaviorChange              -> NoBehaviorChange
DirectCallReceiptConsumerPlacementUnsafeConsumeAfterRevoke          -> NoConsumeAfterRevoke
DirectCallReceiptConsumerPlacementUnsafeFutureGapImplemented        -> FutureGapsNotImplemented
DirectCallReceiptConsumerPlacementUnsafeGenericAsyncConsume         -> GenericAsyncExcluded
DirectCallReceiptConsumerPlacementUnsafeHotPathDirectCall           -> HotPathOnlyBoundedCheck
DirectCallReceiptConsumerPlacementUnsafeLinuxMintedReceipt          -> NoLinuxMintedReceipt
DirectCallReceiptConsumerPlacementUnsafeMonitorVerified             -> NoMonitorVerifiedClaim
DirectCallReceiptConsumerPlacementUnsafePolicySchemaAuthority       -> PolicyLifecycleNotSchemaAuthority
DirectCallReceiptConsumerPlacementUnsafeProtectionClaim             -> NoProtectionClaim
DirectCallReceiptConsumerPlacementUnsafeShadowAuthority             -> LinuxShadowIsNotAuthority
DirectCallReceiptConsumerPlacementUnsafeTracePlanCoverage           -> NoTraceCoverageClaim
```

TLC exit codes:

```text
DirectCallReceiptConsumerPlacementSafe 0
DirectCallReceiptConsumerPlacementUnsafeAbiApproval 12
DirectCallReceiptConsumerPlacementUnsafeBehaviorChange 12
DirectCallReceiptConsumerPlacementUnsafeConsumeAfterRevoke 12
DirectCallReceiptConsumerPlacementUnsafeFutureGapImplemented 12
DirectCallReceiptConsumerPlacementUnsafeGenericAsyncConsume 12
DirectCallReceiptConsumerPlacementUnsafeHotPathDirectCall 12
DirectCallReceiptConsumerPlacementUnsafeLinuxMintedReceipt 12
DirectCallReceiptConsumerPlacementUnsafeMonitorVerified 12
DirectCallReceiptConsumerPlacementUnsafePolicySchemaAuthority 12
DirectCallReceiptConsumerPlacementUnsafeProtectionClaim 12
DirectCallReceiptConsumerPlacementUnsafeShadowAuthority 12
DirectCallReceiptConsumerPlacementUnsafeTracePlanCoverage 12
```

## Meaning

The checked placement rule is:

```text
hot path:
  may only consume pre-frozen monitor-owned shadow state through bounded
  generation/epoch-style checks

policy/lifecycle:
  may shape requests and invalidate stale state, but cannot become schema or
  receipt authority

generic async:
  must remain excluded as a generic receipt consumer; Domain-originated async
  work needs typed carriers and service/caller authority intersection

future gaps:
  remain gaps until separately modeled and patched
```

## Non-Claims

This is a placement/exclusion model only. It does not approve:

```text
Linux direct-call stubs
direct-call ABI
public tracepoints
runtime coverage
monitor verification
behavior-changing Linux patches
production protection
```

