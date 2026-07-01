# Validation 0111: Server Epoch Relation TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0094-server-epoch-relation.md
analysis/server-epoch-relation-v1.json
formal/0072-server-epoch-relation-model/
```

## Purpose

Validate the server epoch relation gate:

```text
Linux server lifecycle changes cannot extend or reinterpret stale
ServerBorrowTicket authority.
```

Server-picked lower-class execution requires:

```text
ticket_live
ticket.server_kind == current_server_kind
ticket.server_epoch == current_server_epoch
server_active
lower task authority
monitor root budget
```

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/server-epoch-relation-20260701T204438Z
```

## Results

Safe configuration:

```text
config: ServerEpochRelationSafe.cfg
result: PASS
states_generated: 107
distinct_states: 32
states_left_on_queue: 0
depth: 6
```

Unsafe configurations produced expected counterexamples:

```text
config: ServerEpochRelationUnsafeStaleAfterReplenish.cfg
target invariant: NoRunWithStaleServerEpoch
result: expected FAIL
states_generated_before_violation: 34
distinct_states_before_violation: 23
states_left_on_queue: 16
depth: 5

config: ServerEpochRelationUnsafeSwapKeepsTicket.cfg
target invariant: NoLiveTicketAcrossEpochChange
result: expected FAIL
states_generated_before_violation: 34
distinct_states_before_violation: 23
states_left_on_queue: 16
depth: 5

config: ServerEpochRelationUnsafeSwapKindMismatch.cfg
target invariant: NoTicketKindMismatch
result: expected FAIL
states_generated_before_violation: 34
distinct_states_before_violation: 23
states_left_on_queue: 16
depth: 5

config: ServerEpochRelationUnsafeStopKeepsTicket.cfg
target invariant: NoStoppedServerWithLiveTicket
result: expected FAIL
states_generated_before_violation: 34
distinct_states_before_violation: 23
states_left_on_queue: 16
depth: 5

config: ServerEpochRelationUnsafePickNoTicket.cfg
target invariant: NoPickWithoutFreshTicket
result: expected FAIL
states_generated_before_violation: 13
distinct_states_before_violation: 11
states_left_on_queue: 7
depth: 4

config: ServerEpochRelationUnsafeLowerTask.cfg
target invariant: NoRunWithoutLowerTaskAuthority
result: expected FAIL
states_generated_before_violation: 13
distinct_states_before_violation: 11
states_left_on_queue: 7
depth: 4

config: ServerEpochRelationUnsafeLinuxRuntimeAuthority.cfg
target invariant: NoLinuxRuntimeAsAuthority
result: expected FAIL
states_generated_before_violation: 13
distinct_states_before_violation: 11
states_left_on_queue: 7
depth: 4

config: ServerEpochRelationUnsafeParamChangeKeepsTicket.cfg
target invariant: NoRunWithStaleServerEpoch
result: expected FAIL
states_generated_before_violation: 34
distinct_states_before_violation: 23
states_left_on_queue: 16
depth: 5

config: ServerEpochRelationUnsafeCpuTeardownKeepsRun.cfg
target invariant: NoStoppedServerWithLiveTicket
result: expected FAIL
states_generated_before_violation: 64
distinct_states_before_violation: 31
states_left_on_queue: 12
depth: 6

config: ServerEpochRelationUnsafeProtectionClaim.cfg
target invariant: NoProtectionClaim
result: expected FAIL
states_generated_before_violation: 94
distinct_states_before_violation: 33
states_left_on_queue: 2
depth: 7
```

## JSON Contract Check

Observed:

```text
source_anchors=44
server_epoch_boundaries=13
fresh_ticket_requirements=8
unsafe_cases=10
safety_flags_false=13
safety_flags_total=13
```

## Meaning

This validation strengthens `EXEC-001` and `BUDGET-001` model evidence by
separating:

```text
server kind
server epoch
server lifecycle
lower-task authority
monitor root budget
Linux server runtime/accounting
```

It preserves Linux scheduler compatibility by treating existing server
lifecycle as policy/accounting substrate while rejecting stale authority
interpretation.

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, budget hooks,
task fields, tracepoint ABI, runtime coverage, monitor verification, behavior
change, or production protection.
