# Validation 0074: Direct-Call Schema Compatibility TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0075-direct-call-schema-compatibility.md
analysis/direct-call-schema-compatibility-v1.json
formal/0052-direct-call-schema-compatibility-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-schema-compatibility-20260630T205154Z
```

## Purpose

This validation checks the N-102 direct-call semantic schema compatibility
candidate for `LocalMonitorAdmissionABI-v0`.

The model separates:

```text
supported semantic schema negotiation
monitor and caller minimum schema checks
mandatory field handling
critical optional field handling
ignored noncritical optional fields as non-authority
required feature coverage
downgrade rejection for required safety features
compatible response, ledger, and error namespace requirements
shadow refresh only from supported response interpretation
unknown success code rejection
transport observation as non-authority
carrier-neutral schema namespace for future ring refinement
```

## Safe Result

```text
DirectCallSchemaCompatibilitySafe:
  Model checking completed. No error has been found.
  37 states generated
  28 distinct states found
  depth 14
```

## Expected Unsafe Counterexamples

```text
DirectCallSchemaCompatibilityUnsafeCallerMinDowngrade:
  Error: Invariant AcceptRequiresMinimums is violated.

DirectCallSchemaCompatibilityUnsafeCriticalOptionalIgnore:
  Error: Invariant AcceptRejectsCriticalUnknownOptional is violated.

DirectCallSchemaCompatibilityUnsafeDirectOnlySchemaNamespace:
  Error: Invariant SchemaNamespaceRemainsCarrierNeutral is violated.

DirectCallSchemaCompatibilityUnsafeIgnoredOptionalAuthority:
  Error: Invariant IgnoredOptionalIsNotAuthority is violated.

DirectCallSchemaCompatibilityUnsafeMissingRequiredFeature:
  Error: Invariant AcceptRequiresRequiredFeatures is violated.

DirectCallSchemaCompatibilityUnsafeMonitorMinDowngrade:
  Error: Invariant AcceptRequiresMinimums is violated.

DirectCallSchemaCompatibilityUnsafeRequiredSafetyStripped:
  Error: Invariant NoRequiredSafetyFeatureDowngrade is violated.

DirectCallSchemaCompatibilityUnsafeResponseLedgerIncompatible:
  Error: Invariant SuccessRequiresCompatibleResponseLedger is violated.

DirectCallSchemaCompatibilityUnsafeShadowFromUnsupportedResponse:
  Error: Invariant ShadowRequiresSupportedResponse is violated.

DirectCallSchemaCompatibilityUnsafeTransportObservationReceipt:
  Error: Invariant TransportObservationIsNotReceipt is violated.

DirectCallSchemaCompatibilityUnsafeUnknownMandatoryAccept:
  Error: Invariant AcceptRequiresKnownMandatoryFields is violated.

DirectCallSchemaCompatibilityUnsafeUnknownSuccessCode:
  Error: Invariant UnknownSuccessCodeIsNotAuthority is violated.

DirectCallSchemaCompatibilityUnsafeUnsupportedSchemaAccept:
  Error: Invariant AcceptRequiresSupportedSchemas is violated.
```

## Interpretation

This supports the N-102 direct-call schema compatibility gate:

```text
unsupported semantic schemas fail closed
monitor and caller minimum schemas cannot be downgraded away
missing or unknown mandatory fields fail closed
unknown critical optional fields fail closed
ignored noncritical optional fields cannot become authority
required feature sets must be covered
required safety features cannot be stripped by downgrade
success requires compatible response, ledger, and error schemas
shadow refresh requires supported response interpretation
unknown success codes are not authority
transport observations cannot mint receipts
schema namespaces remain carrier-neutral for future ring refinement
```

This is semantic evidence only. It is not a numeric schema-id assignment,
binary field encoding, C struct layout, direct-call trap mechanism, Linux stub,
monitor implementation, performance benchmark, liveness proof, or production
protection evidence.
