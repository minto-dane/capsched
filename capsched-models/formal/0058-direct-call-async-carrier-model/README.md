# Direct-Call Async Carrier Model

This model checks the N-120 typed async carrier rule for Domain-originated
direct-call work.

Safe design order:

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

Unsafe configurations reject:

```text
generic work as authority
pending work overwrite
pending carrier replacement without a bad flag
worker identity as authority
service-only authority
missing caller frozen authority
service-only budget charge
Linux-minted receipt
consume after revoke
stale revoked carrier execution
trace coverage claim
ABI approval
behavior change
monitor verification claim
protection claim
```

The safe model also includes a revoked-pending-carrier path:

```text
PendingProtected
RejectRevokedPendingCarrier
RevokedPendingCarrierRejected
```

That path is terminal and must not reach worker execution.
