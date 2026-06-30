# Validation 0075: Direct-Call Attachment Readiness TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-30

Related artifacts:

```text
analysis/0076-direct-call-attachment-readiness.md
analysis/direct-call-attachment-readiness-v1.json
implementation/0008-direct-call-attachment-readiness-gate.md
formal/0053-direct-call-attachment-readiness-model/
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-attachment-readiness-20260630T213615Z
```

## Purpose

This validation checks the N-103 no-code direct-call attachment/readiness gate.

The model separates:

```text
source-anchor coverage
required attachment rows and row fields
observation-only status
inert stub constraints
failure-injection containment
schema, ledger, shadow, and ring-compatibility references
direct-call readiness from direct-call authority
monitor-side responsibility from Linux-side mutable state
```

## Safe Result

```text
DirectCallAttachmentReadinessSafe:
  Model checking completed. No error has been found.
  11 states generated
  10 distinct states found
  depth 10
```

## Expected Unsafe Counterexamples

```text
DirectCallAttachmentReadinessUnsafeAuthorityClaim:
  Error: Invariant NoAuthorityClaim is violated.

DirectCallAttachmentReadinessUnsafeBehaviorChange:
  Error: Invariant NoBehaviorChange is violated.

DirectCallAttachmentReadinessUnsafeDirectOnlyRingIncompatible:
  Error: Invariant RingCompatibilityRequired is violated.

DirectCallAttachmentReadinessUnsafeFailureInjectionLiveEffect:
  Error: Invariant FailureInjectionIsNotLiveBehavior is violated.

DirectCallAttachmentReadinessUnsafeLinuxLedgerWrite:
  Error: Invariant NoLinuxLedgerOrResponseMint is violated.

DirectCallAttachmentReadinessUnsafeLinuxShadowFromTimeout:
  Error: Invariant NoLinuxShadowFromTimeout is violated.

DirectCallAttachmentReadinessUnsafeMissingRowCoverage:
  Error: Invariant ReadinessRequiresCoverage is violated.

DirectCallAttachmentReadinessUnsafeMonitorVerified:
  Error: Invariant NoMonitorVerifiedClaim is violated.

DirectCallAttachmentReadinessUnsafeProbeAsAuthority:
  Error: Invariant ObservationIsNotAuthority is violated.

DirectCallAttachmentReadinessUnsafeProtectionClaim:
  Error: Invariant NoProtectionClaim is violated.

DirectCallAttachmentReadinessUnsafePublicTracepointAbi:
  Error: Invariant NoPublicTracepointAbi is violated.

DirectCallAttachmentReadinessUnsafeRawHandleExposure:
  Error: Invariant NoRawHandleExposure is violated.

DirectCallAttachmentReadinessUnsafeStubAuthorizes:
  Error: Invariant NoStubAuthorization is violated.

DirectCallAttachmentReadinessUnsafeStubChangesCallerBehavior:
  Error: Invariant NoStubAuthorization is violated.

DirectCallAttachmentReadinessUnsafeUserAbi:
  Error: Invariant NoUserAbi is violated.
```

## Interpretation

This supports the N-103 direct-call attachment/readiness gate:

```text
readiness requires source-anchor and row coverage
readiness remains observation-only
readiness cannot claim direct-call authority
readiness cannot claim monitor verification or production protection
readiness cannot change scheduler, device, endpoint, ABI, or caller behavior
Linux cannot mint monitor ledger rows or response handles
Linux cannot refresh shadow state from timeout or return code
trace or probe observations cannot become receipts
failure injection cannot have live production effects
raw monitor, device, task, fd, scheduler, IOMMU, MSI, PF, or VF handles cannot be exposed
direct-call attachment names must remain compatible with a future monitor-owned ring
```

This is semantic evidence only. It is not a Linux patch, direct-call trap
mechanism, monitor implementation, binary ABI, public tracepoint ABI, user ABI,
performance benchmark, liveness proof, or production protection evidence.
