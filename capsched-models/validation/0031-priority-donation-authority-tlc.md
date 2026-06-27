# Validation 0031: Priority Donation Authority TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0019-priority-donation-authority-model/PriorityDonationAuthority.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0036-pi-rt-wwmutex-priority-donation-authority.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthoritySafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeNoDependency.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeNoDonationCap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeCrossDomain.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeRunNoRunCap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeRunNoBudget.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeAfterRelease.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeWoundThreadControl.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/priority-donation-authority-20260627T082736Z/PriorityDonationAuthorityUnsafeProxyCycle.log
```

## Result Summary

Safe configuration:

```text
config: PriorityDonationAuthoritySafe.cfg
result: PASS
generated states: 18
distinct states: 13
search depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: PriorityDonationAuthorityUnsafeNoDependency.cfg
target invariant: NoDonationWithoutBlockedDependency
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
depth: 2

config: PriorityDonationAuthorityUnsafeNoDonationCap.cfg
target invariant: NoDonationWithoutDonationCap
result: expected FAIL
generated states before violation: 9
distinct states before violation: 8
depth: 4

config: PriorityDonationAuthorityUnsafeCrossDomain.cfg
target invariant: NoCrossDomainDonationWithoutEndpoint
result: expected FAIL
generated states before violation: 3
distinct states before violation: 3
depth: 2

config: PriorityDonationAuthorityUnsafeRunNoRunCap.cfg
target invariant: NoDonationCreatesRunAuthority
result: expected FAIL
generated states before violation: 12
distinct states before violation: 9
depth: 5

config: PriorityDonationAuthorityUnsafeRunNoBudget.cfg
target invariant: NoDonationCreatesBudget
result: expected FAIL
generated states before violation: 12
distinct states before violation: 9
depth: 5

config: PriorityDonationAuthorityUnsafeAfterRelease.cfg
target invariant: NoDonationAfterUnlockOrRevoke
result: expected FAIL
generated states before violation: 12
distinct states before violation: 9
depth: 5

config: PriorityDonationAuthorityUnsafeWoundThreadControl.cfg
target invariant: NoWoundAsThreadControl
result: expected FAIL
generated states before violation: 9
distinct states before violation: 8
depth: 4

config: PriorityDonationAuthorityUnsafeProxyCycle.cfg
target invariant: NoProxyChainCycle
result: expected FAIL
generated states before violation: 12
distinct states before violation: 9
depth: 5
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Priority donation requires a real blocked waiter -> owner-held dependency.

2. Donation requires explicit endpoint donation authority.

3. Cross-Domain donation requires live typed endpoint authority, not just a
   shared futex key or kernel lock pointer.

4. Donation cannot create RunCap or FrozenRunUse for the owner.

5. Donation cannot create free CPU budget; proxy execution needs an explicit
   owner budget or ProxyExecutionTicket policy.

6. Unlock/release/revoke clears donation authority.

7. ww_mutex wound/wait is endpoint deadlock-resolution authority, not
   ThreadControlCap.

8. Proxy execution cannot rely on circular blocked_on/blocked_donor authority
   chains.
```

## Unsafe Counterexample Meaning

`PriorityDonationAuthorityUnsafeNoDependency.cfg` demonstrates effective boost
without an actual lock dependency:

```text
Start -> BadDonationNoDependency
```

`PriorityDonationAuthorityUnsafeNoDonationCap.cfg` demonstrates donation after
blocking without donation authority:

```text
Start -> EndpointPrepared -> WaiterBlocked -> BadDonationNoCap
```

`PriorityDonationAuthorityUnsafeCrossDomain.cfg` demonstrates cross-Domain
donation without a live typed endpoint:

```text
Start -> BadCrossDomainNoEndpoint
```

`PriorityDonationAuthorityUnsafeRunNoRunCap.cfg` demonstrates the main
responsibility confusion:

```text
Start -> EndpointPrepared -> WaiterBlocked -> DonationActive -> BadRunNoRunCap
```

The owner runs because it was boosted, but no owner execution authority was
frozen.

`PriorityDonationAuthorityUnsafeRunNoBudget.cfg` demonstrates free CPU time
created by donation:

```text
Start -> EndpointPrepared -> WaiterBlocked -> DonationActive -> BadRunNoBudget
```

`PriorityDonationAuthorityUnsafeAfterRelease.cfg` demonstrates donation
surviving lock release:

```text
Start -> EndpointPrepared -> WaiterBlocked -> DonationActive
  -> BadDonationAfterRelease
```

`PriorityDonationAuthorityUnsafeWoundThreadControl.cfg` demonstrates ww_mutex
wound/wait becoming arbitrary thread control:

```text
Start -> EndpointPrepared -> WaiterBlocked -> BadWoundThreadControl
```

`PriorityDonationAuthorityUnsafeProxyCycle.cfg` demonstrates circular proxy
authority:

```text
Start -> EndpointPrepared -> WaiterBlocked -> DonationActive -> BadProxyCycle
```

## Evidence Limits

This validation does not prove:

```text
full rt_mutex rb-tree ordering
all futex PI timeout, signal, and cleanup paths
exact priority comparison across CFS/RT/DL classes
complete scheduler proxy-execution loop behavior
core scheduling cookie interactions
PREEMPT_RT-specific lock substitution behavior
monitor-backed cross-Domain donation enforcement
```

Those remain separate proof obligations.

## Design Consequence

Future CapSched implementation must keep these capabilities separate:

```text
RunCap:
  may make a task runnable

PriorityDonationCap:
  may derive temporary ordering/effective priority from a real lock dependency

ProxyExecutionTicket:
  may fund bounded dependency-resolution execution

WoundWaitCap:
  may request lock-protocol backoff

ThreadControlCap:
  may explicitly control another thread
```

This means L0 should not treat rt_mutex PI, futex PI, scheduler proxy
execution, or ww_mutex wound/wait as proof that generic wake, enqueue, or run
authority has been granted.
