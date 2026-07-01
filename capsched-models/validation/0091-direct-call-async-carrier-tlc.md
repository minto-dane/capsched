# Direct-Call Async Carrier TLC

Date: 2026-06-30

Status: safe model passed; unsafe models produced expected counterexamples.

## Scope

This validates `formal/0058-direct-call-async-carrier-model/`.

The model is a pre-implementation gate for Domain-originated async work that
would carry direct-call monitor receipts through workqueue or io_uring style
worker execution. It is not a generic workqueue rewrite, Linux patch approval,
ABI approval, runtime coverage claim, monitor verification, behavior-change
approval, or production protection evidence.

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config DirectCallAsyncCarrierSafe.cfg \
  DirectCallAsyncCarrier.tla
```

Log directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-async-carrier-20260701T023413Z
/media/nia/scsiusb/dev/linux-cap/build/tlc/direct-call-async-carrier-20260701T023933Z
```

The `20260701T023413Z` run was superseded before commit after subagent review
found that pending coalescing and revoke handling were too flag-like. The final
N-120 run is `20260701T023933Z`.

Safe result:

```text
exit code: 0
states generated: 15
distinct states: 13
states left on queue: 0
search depth: 12
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
guard invariant:

| Config | Violated invariant |
| --- | --- |
| `DirectCallAsyncCarrierUnsafeAbiApproval` | `NoAbiApproval` |
| `DirectCallAsyncCarrierUnsafeBehaviorChange` | `NoBehaviorChange` |
| `DirectCallAsyncCarrierUnsafeBudgetServiceOnly` | `BudgetTicketChargedToCaller` |
| `DirectCallAsyncCarrierUnsafeConsumeAfterRevoke` | `NoConsumeAfterRevoke` |
| `DirectCallAsyncCarrierUnsafeGenericWorkAuthority` | `NoGenericWorkAuthority` |
| `DirectCallAsyncCarrierUnsafeLinuxMintedReceipt` | `NoLinuxMintedReceipt` |
| `DirectCallAsyncCarrierUnsafeMissingCallerFrozen` | `CallerFrozenRequired` |
| `DirectCallAsyncCarrierUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `DirectCallAsyncCarrierUnsafePendingCarrierReplacement` | `PendingCarrierPreserved` |
| `DirectCallAsyncCarrierUnsafePendingOverwrite` | `NoPendingOverwrite` |
| `DirectCallAsyncCarrierUnsafeProtectionClaim` | `NoProtectionClaim` |
| `DirectCallAsyncCarrierUnsafeServiceOnlyAuthority` | `NoServiceOnlyAuthority` |
| `DirectCallAsyncCarrierUnsafeStaleRevokedExecution` | `NoStaleCarrierExecution` |
| `DirectCallAsyncCarrierUnsafeTracePlanCoverage` | `NoTraceCoverageClaim` |
| `DirectCallAsyncCarrierUnsafeWorkerIdentityAuthority` | `WorkerIdentityIsNotAuthority` |

## Meaning

The checked safe path requires this ordering:

```text
FreezeCallerAuthority
BindServiceAuthority
MonitorMintReceipt
AllocateTypedCarrier
QueueTypedCarrier
RejectCoalescedSecondCaller
ProtectPendingCarrier
ModelRevokeHandling
WorkerReceivesCarrier
ExecuteWithIntersection
AcceptAsyncCarrierDesign
```

The accepted design state therefore requires:

- caller authority is frozen before async submission;
- service authority is bound but never sufficient alone;
- the receipt is monitor-minted, not Linux-minted;
- the typed carrier carries caller frozen authority, service authority, caller
  budget ticket, monitor receipt, caller identity, receipt identity, and carrier
  generation;
- pending work cannot be represented by overwriting caller-specific authority
  on a reused `work_struct`;
- a second caller coalesced onto already-pending work is recorded separately and
  cannot replace the saved first caller, first caller budget ticket, first
  monitor receipt, or first carrier generation;
- worker/kthread identity is not execution authority;
- effective authority is the intersection of service authority and caller
  frozen authority;
- budget is charged to the caller ticket rather than service-only ambient
  authority;
- revoke handling is modeled before consumption, and a revoked pending carrier
  has an explicit terminal rejection path that never reaches worker execution;
- trace plans, ABI approval, behavior change, monitor verification, and
  protection claims remain false.

## Limits

This is a tiny finite model. It does not prove Linux implementation coverage,
does not validate real workqueue or io_uring behavior, does not implement a
typed carrier, and does not show that the HyperTag Monitor exists. Its value is
as a semantic gate: any future async direct-call receipt carrier patch must not
collapse back into generic workqueue authority, pending-work overwrite,
worker-identity authority, service-only authority, or Linux-minted receipt
semantics.
