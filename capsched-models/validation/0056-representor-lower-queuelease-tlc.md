# Validation 0056: Representor Lower QueueLease TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-29

Model:

```text
capsched/capsched-models/formal/0036-representor-lower-queuelease-model/RepresentorLowerQueueLease.tla
```

Related artifacts:

```text
capsched/capsched-models/analysis/0057-representor-lower-queuelease-source-map.md
capsched/capsched-models/analysis/representor-lower-queuelease-source-map-v1.json
capsched/capsched-models/formal/0030-queuecontrol-representor-model/README.md
capsched/capsched-models/validation/0049-queuecontrol-representor-tlc.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeBridgeFdbAsLease.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeForwardAfterRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeLagStaleLower.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeNetdevOnlyForward.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeReprStopOnlyRevoke.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeTcNoControl.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeTcStaleDest.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/representor-lower-queuelease-20260630T014001Z/RepresentorLowerQueueLeaseUnsafeVlanAsLease.log
```

## Result Summary

Safe configuration:

```text
config: RepresentorLowerQueueLeaseSafe.cfg
result: PASS
generated states: 14
distinct states: 8
search depth: 4
```

Unsafe configurations produced expected counterexamples:

```text
config: RepresentorLowerQueueLeaseUnsafeNetdevOnlyForward.cfg
target invariant: NoNetdevOnlyLowerForward
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: RepresentorLowerQueueLeaseUnsafeBridgeFdbAsLease.cfg
target invariant: NoBridgeFdbAsLowerLease
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: RepresentorLowerQueueLeaseUnsafeVlanAsLease.cfg
target invariant: NoVlanAsLowerLease
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: RepresentorLowerQueueLeaseUnsafeTcNoControl.cfg
target invariant: NoTcOffloadWithoutControlAndLowerLease
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7

config: RepresentorLowerQueueLeaseUnsafeTcStaleDest.cfg
target invariant: NoTcOffloadWithoutControlAndLowerLease
result: expected FAIL
generated states before violation: 13
distinct states before violation: 9

config: RepresentorLowerQueueLeaseUnsafeLagStaleLower.cfg
target invariant: NoLagForwardWithStaleLowerDev
result: expected FAIL
generated states before violation: 13
distinct states before violation: 9

config: RepresentorLowerQueueLeaseUnsafeForwardAfterRevoke.cfg
target invariant: NoLowerEffectAfterRevoke
result: expected FAIL
generated states before violation: 13
distinct states before violation: 9

config: RepresentorLowerQueueLeaseUnsafeReprStopOnlyRevoke.cfg
target invariant: NoRepresentorStopOnlyRevoke
result: expected FAIL
generated states before violation: 7
distinct states before violation: 7
```

## Validated Claims

This validation supports these local constraints:

```text
1. Representor netdev reachability is not lower QueueLease authority.

2. Bridge FDB hit and VLAN allow decisions are policy inputs only. They do not
   mint lower queue submit authority.

3. Software representor forwarding requires a frozen carrier that binds
   RepresentorForward authority, metadata generation, lower_dev identity, lower
   QueueLease epoch, and queue budget.

4. TC/switchdev hardware forwarding rule installation requires
   QueueControl/Offload authority plus a fresh lower QueueLease binding.

5. LAG lower_dev change invalidates the metadata-to-lower-lease binding until a
   fresh rebind occurs.

6. Revoke must invalidate software forwarding, hardware rule forwarding, and
   lower queue authority.

7. Stopping representor netdev Tx queues is not lower QueueLease revoke.
```

## Unsafe Counterexample Meaning

`RepresentorLowerQueueLeaseUnsafeNetdevOnlyForward.cfg` demonstrates lower
queue submit by plain representor netdev reachability.

`RepresentorLowerQueueLeaseUnsafeBridgeFdbAsLease.cfg` demonstrates a bridge
FDB decision being treated as lower QueueLease authority.

`RepresentorLowerQueueLeaseUnsafeVlanAsLease.cfg` demonstrates a VLAN allow
decision being treated as lower QueueLease authority.

`RepresentorLowerQueueLeaseUnsafeTcNoControl.cfg` demonstrates TC/switchdev
hardware rule installation without QueueControl/Offload authority.

`RepresentorLowerQueueLeaseUnsafeTcStaleDest.cfg` demonstrates TC/switchdev
rule installation after the lower_dev binding became stale.

`RepresentorLowerQueueLeaseUnsafeLagStaleLower.cfg` demonstrates forwarding
after LAG lower_dev change without metadata and lower QueueLease rebind.

`RepresentorLowerQueueLeaseUnsafeForwardAfterRevoke.cfg` demonstrates software
and hardware forwarding effects after revoke.

`RepresentorLowerQueueLeaseUnsafeReprStopOnlyRevoke.cfg` demonstrates treating
representor netdev queue stop as lower QueueLease revoke.

## Evidence Limits

This validation does not prove:

```text
real Linux bridge correctness
real TC flower or BPF redirect safety
real ice switchdev rule correctness
real LAG failover correctness
real lower QueueLease implementation
real HyperTag Monitor enforcement
```

Those remain implementation and monitor proof obligations.

## Design Consequence

The safe CapSched-H rule is:

```text
lower queue submit =
  RepresentorForwardCap
  + representor epoch
  + fresh metadata_dst generation
  + lower_dev identity bound to lower QueueLease
  + fresh lower QueueLease epoch
  + lower queue budget
  + bridge/FDB/VLAN policy admission as input only

hardware/offloaded forwarding =
  QueueControl/OffloadCap
  + rule generation
  + source/destination VSI binding
  + lower QueueLease epoch
  + revoke-time rule invalidation receipt
```

Any future implementation plan must name how it obtains or verifies this before
`ice_eswitch_port_start_xmit()`, `dev_queue_xmit()`, bridge switchdev
offloads, TC redirect/offload setup, LAG lower_dev updates, or representor
detach/stop are treated as security-relevant events.
