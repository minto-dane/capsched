# Validation 0087: Direct-Call Receipt Schema TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Model:

```text
capsched-models/formal/0056-direct-call-receipt-schema-model/DirectCallReceiptSchema.tla
```

TLC logs:

```text
build/tlc/direct-call-receipt-schema-20260701T003345Z
```

## Safe Result

```text
config: DirectCallReceiptSchemaSafe.cfg
result: no invariant errors
states_generated=10
distinct_states=9
depth=9
```

## Unsafe Results

Each unsafe configuration produced the expected invariant violation:

```text
DirectCallReceiptSchemaUnsafeLinuxMintedReceipt:
  NoLinuxMintedReceipt

DirectCallReceiptSchemaUnsafeLinuxSchemaAccept:
  NoLinuxSchemaAccept

DirectCallReceiptSchemaUnsafeWrapperReturnReceipt:
  NoWrapperReturnReceipt

DirectCallReceiptSchemaUnsafeTimeoutShadowRefresh:
  NoTimeoutShadowRefresh

DirectCallReceiptSchemaUnsafeShadowAuthority:
  LinuxShadowIsNotAuthority

DirectCallReceiptSchemaUnsafeResponseDuringRevoke:
  NoResponseDuringRevoke

DirectCallReceiptSchemaUnsafeRevokeWithInFlight:
  NoRevokeCompleteWithInFlight

DirectCallReceiptSchemaUnsafeTracePlanCoverage:
  NoTraceCoverageClaim

DirectCallReceiptSchemaUnsafeAbiApproval:
  NoAbiApproval

DirectCallReceiptSchemaUnsafeBehaviorChange:
  NoBehaviorChange

DirectCallReceiptSchemaUnsafeMonitorVerified:
  NoMonitorVerifiedClaim

DirectCallReceiptSchemaUnsafeProtectionClaim:
  NoProtectionClaim
```

## Meaning

The model supports the N-116 receipt-schema rule:

```text
Linux-visible shadows are derived cache records only.
Monitor-owned receipts are required for request image, schema acceptance,
entry result, response handle, and revoke completion.
```

It rejects Linux-minted receipts, Linux schema acceptance, wrapper return as
receipt, timeout refresh authority, Linux shadow authority, response during
revoke, revoke completion with in-flight response, trace-plan runtime coverage,
ABI approval, behavior change, monitor verification claim, and protection claim.

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

Future direct-call Linux-facing surfaces must consume opaque monitor receipts
and derived shadows. They must not mint request, schema, entry, response, or
revoke authority in Linux.
