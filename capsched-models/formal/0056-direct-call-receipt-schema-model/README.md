# Direct-Call Receipt Schema Model

This model checks the N-116 monitor-owned direct-call receipt schema.

It models the safe order:

```text
MonitorCopyRequest
MonitorAcceptSchema
MonitorIssueEntryResult
MonitorMintResponse
LinuxDeriveShadow
MonitorStartRevoke
MonitorCompleteRevoke
AcceptSchemaDesign
```

Unsafe configurations reject:

```text
Linux-minted receipt
Linux schema acceptance
wrapper return as receipt
timeout shadow refresh
Linux shadow as authority
response during revoke
revoke complete with in-flight response
trace plan as runtime coverage
ABI approval
behavior change
monitor verification claim
protection claim
```
