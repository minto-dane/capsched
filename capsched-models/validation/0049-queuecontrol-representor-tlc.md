# Validation 0049: QueueControl and RepresentorForward TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0030-queuecontrol-representor-model/QueueControlRepresentor.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0052-ice-modern-nic-queuelease-source-map.md
capsched/capsched-models/validation/0047-ice-modern-nic-readiness-result.md
capsched/capsched-models/formal/0028-modern-nic-queuelease-model/README.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeControlAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeDevlinkViaNetdev.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeDevlinkViaRunCap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeForwardAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeForwardNoServiceBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeRepresentorNoCap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeRepresentorNoLowerLease.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeRepresentorStaleLower.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/queuecontrol-representor-20260627T114912Z/QueueControlRepresentorUnsafeRepresentorViaNetdev.log
```

## Result Summary

Safe configuration:

```text
config: QueueControlRepresentorSafe.cfg
result: PASS
generated states: 7
distinct states: 7
search depth: 3
```

Unsafe configurations produced expected counterexamples:

```text
config: QueueControlRepresentorUnsafeDevlinkViaRunCap.cfg
target invariant: NoQueueControlWithoutCap
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: QueueControlRepresentorUnsafeDevlinkViaNetdev.cfg
target invariant: NoQueueControlWithoutCap
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: QueueControlRepresentorUnsafeRepresentorNoCap.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: QueueControlRepresentorUnsafeRepresentorNoLowerLease.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: QueueControlRepresentorUnsafeRepresentorStaleLower.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: QueueControlRepresentorUnsafeRepresentorViaNetdev.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: QueueControlRepresentorUnsafeForwardNoServiceBudget.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8

config: QueueControlRepresentorUnsafeControlAfterRevoke.cfg
target invariant: NoQueueControlWithoutCap
result: expected FAIL
generated states before violation: 6
distinct states before violation: 6

config: QueueControlRepresentorUnsafeForwardAfterRevoke.cfg
target invariant: NoRepresentorForwardWithoutDerivation
result: expected FAIL
generated states before violation: 8
distinct states before violation: 8
```

## Validated Claims

This validation supports these local constraints:

```text
1. Devlink queue/rate/scheduler control requires QueueControlCap and live queue
   epoch. RunCap cannot authorize it.

2. Plain netdev reachability cannot authorize queue/rate/scheduler control.

3. VF/SF/representor control-plane reshaping is QueueControl authority, not
   execution authority.

4. Representor forwarding requires RepresentorForwardCap plus a live lower
   QueueLease with a fresh lower queue epoch.

5. Plain representor netdev reachability cannot authorize lower queue submit.

6. Representor forwarding requires service budget.

7. Queue control and representor forwarding must fail after revoke.
```

## Unsafe Counterexample Meaning

`QueueControlRepresentorUnsafeDevlinkViaRunCap.cfg` demonstrates devlink
queue-control authorized by RunCap.

`QueueControlRepresentorUnsafeDevlinkViaNetdev.cfg` demonstrates devlink
queue-control authorized by plain netdev reachability.

`QueueControlRepresentorUnsafeRepresentorNoCap.cfg` demonstrates representor
forwarding without RepresentorForwardCap.

`QueueControlRepresentorUnsafeRepresentorNoLowerLease.cfg` demonstrates
representor forwarding without a lower QueueLease.

`QueueControlRepresentorUnsafeRepresentorStaleLower.cfg` demonstrates
representor forwarding with a stale lower queue epoch.

`QueueControlRepresentorUnsafeRepresentorViaNetdev.cfg` demonstrates
representor forwarding through plain netdev reachability.

`QueueControlRepresentorUnsafeForwardNoServiceBudget.cfg` demonstrates
representor forwarding without service budget.

`QueueControlRepresentorUnsafeControlAfterRevoke.cfg` demonstrates queue
control after revoke.

`QueueControlRepresentorUnsafeForwardAfterRevoke.cfg` demonstrates representor
forwarding after revoke.

## Evidence Limits

This validation does not prove:

```text
real devlink policy correctness
real VF/SF lifecycle safety
bridge FDB/VLAN correctness
TC flower or hardware eswitch correctness
monitor-backed QueueControlCap implementation
```

Those remain future proof obligations.

## Design Consequence

Modern NIC control and representor paths need distinct authority:

```text
QueueControl:
  devlink/rate/scheduler/VF/SF/representor lifecycle authority

RepresentorForward:
  representor ingress authority plus derived lower QueueLease authority
```

Neither may be authorized by RunCap, plain netdev reachability, or the fact that
Linux can call `dev_queue_xmit()`.
