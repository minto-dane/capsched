# Validation 0105: Linux Scheduler Authority Core Refresh

Status: source-only refresh checked; existing authority model rechecked; JSON
contract checked

Date: 2026-07-01

## Inputs

```text
analysis/0025-linux-scheduler-authority-state-machine.md
analysis/0026-scheduler-hook-proof-obligation-matrix.md
analysis/0028-tick-runtime-budget-source-map.md
analysis/linux-scheduler-authority-core-refresh-v1.json
formal/0012-linux-scheduler-authority-model/
validation/0104-linux-source-map-refresh-target-selection.md
```

## Source Refresh Summary

The refresh updates scheduler authority source anchors against:

```text
upstream/master=665159e246749578d4e4bfe106ee3b74edcdab18
work_commit=7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Updated artifacts:

```text
analysis/0025-linux-scheduler-authority-state-machine.md
analysis/0026-scheduler-hook-proof-obligation-matrix.md
analysis/0028-tick-runtime-budget-source-map.md
formal/0012-linux-scheduler-authority-model/README.md
```

Machine-readable contract:

```text
analysis/linux-scheduler-authority-core-refresh-v1.json
```

JSON check:

```text
anchor_count=25
anchors_length=25
safety_flags_false=12
safety_flags_total=12
refreshed_rules=8
updated_artifacts=4
```

## Refreshed Rules

The refresh records these scheduler authority constraints:

```text
enqueue_task_is_assertion_not_fail_capable_hook
task_waking_after_state_write_requires_lost_wakeup_model
current_wake_is_continuation_not_new_runcap
delayed_reenqueue_is_not_authority_mint
placement_refines_linux_hotplug_and_kthread_exceptions
sched_tick_charges_donor_not_blind_current
pick_validation_must_cover_fast_path_retry_class_iteration_sched_ext
switch_activation_requires_fail_closed_domain_activation_model
```

## TLC Recheck

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/linux-scheduler-authority-refresh-20260701T193728Z
```

Command shape:

```sh
timeout 120 java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config LinuxSchedulerAuthority.cfg \
  LinuxSchedulerAuthority.tla
```

Result:

```text
exit_code=0
states_generated=126113
distinct_states=17344
states_left_on_queue=0
search_depth=21
```

Checked invariants remain:

```text
TypeOK
NoCustodyWithoutValidGrant
NoRemotePendingRuns
NoRunningWithoutToken
NoRunningWithoutBudget
NoStaleActiveEpoch
NoDeadAuthority
NoTaskSelectedTwice
NoTaskRunsTwice
NoSelectedAndRunningSameTask
NoSelectedOnBusyCpu
CpuIdleShape
```

## Meaning

The existing tiny finite `LinuxSchedulerAuthority` model still has no
counterexample for the listed invariants after the source-map refresh.

The refresh also makes a stronger source-map rule explicit:

```text
sched_tick() charges/accounting work through rq->donor, so future budget models
must not charge blindly to rq->curr.
```

## Limits

This validation is source-map and finite-model evidence. It does not prove
Linux runtime behavior and does not approve scheduler hooks.

## Non-Claims

This validation does not approve Linux code, task_struct fields, enqueue hooks,
pick hooks, switch hooks, budget hooks, direct-call stubs, ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
