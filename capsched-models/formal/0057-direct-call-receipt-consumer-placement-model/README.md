# Direct-Call Receipt Consumer Placement Model

This model checks the N-118 placement and exclusion constraints derived from
the N-117 receipt-consumer source map.

Safe design order:

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

Unsafe configurations reject:

```text
Linux-minted receipt
Linux shadow as authority
hot path direct monitor call / receipt mint
policy lifecycle path as schema authority
generic async worker as receipt consumer
future gap treated as implemented
stale consume after revoke
trace plan as runtime coverage
ABI approval
behavior change
monitor verification claim
protection claim
```

