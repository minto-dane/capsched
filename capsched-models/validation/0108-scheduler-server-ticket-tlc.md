# Validation 0108: Scheduler Server Ticket TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0091-scheduler-server-ticket-map.md
analysis/scheduler-server-ticket-v1.json
formal/0069-scheduler-server-ticket-model/
```

## Purpose

Validate the scheduler server-ticket gate:

```text
fair/ext/DL server runtime, RT bandwidth, and sched_ext slice state do not
create CapSched execution authority.
```

Server-picked lower-class execution requires:

```text
lower task authority
server-borrow ticket
fresh server epoch
monitor root budget
live server state
```

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/scheduler-server-ticket-20260701T200435Z
```

## Results

Safe configuration:

```text
config: SchedulerServerTicketSafe.cfg
result: PASS
states_generated: 39
distinct_states: 24
states_left_on_queue: 0
depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: SchedulerServerTicketUnsafePickNoTicket.cfg
target invariant: NoServerBorrowWithoutTicket
result: expected FAIL
states_generated_before_violation: 10
distinct_states_before_violation: 10
states_left_on_queue: 6
depth: 4

config: SchedulerServerTicketUnsafeServerRuntime.cfg
target invariant: NoServerRuntimeAsRootAuthority
result: expected FAIL
states_generated_before_violation: 10
distinct_states_before_violation: 10
states_left_on_queue: 6
depth: 4

config: SchedulerServerTicketUnsafeRtBandwidth.cfg
target invariant: NoRtBandwidthAsRootAuthority
result: expected FAIL
states_generated_before_violation: 15
distinct_states_before_violation: 15
states_left_on_queue: 8
depth: 4

config: SchedulerServerTicketUnsafeScxSlice.cfg
target invariant: NoScxSliceAsRootAuthority
result: expected FAIL
states_generated_before_violation: 16
distinct_states_before_violation: 16
states_left_on_queue: 8
depth: 4

config: SchedulerServerTicketUnsafeReplenish.cfg
target invariant: NoRunWithStaleServerEpoch
result: expected FAIL
states_generated_before_violation: 28
distinct_states_before_violation: 23
states_left_on_queue: 6
depth: 6

config: SchedulerServerTicketUnsafeStop.cfg
target invariant: NoStoppedServerWithLiveRun
result: expected FAIL
states_generated_before_violation: 28
distinct_states_before_violation: 23
states_left_on_queue: 6
depth: 6

config: SchedulerServerTicketUnsafeLowerTask.cfg
target invariant: NoRunWithoutTaskAuthority
result: expected FAIL
states_generated_before_violation: 19
distinct_states_before_violation: 18
states_left_on_queue: 9
depth: 5
```

## JSON Contract Check

Expected:

```text
source_anchors=17
unsafe_cases=7
safety_flags_false=12
safety_flags_total=12
```

## Meaning

This validation strengthens `EXEC-001` and `BUDGET-001` model evidence by
separating server runtime, class bandwidth, task authority, server tickets,
server epoch, and monitor root budget.

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, budget hooks,
task fields, tracepoint ABI, runtime coverage, monitor verification, behavior
change, or production protection.

