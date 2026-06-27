# Validation 0025: Scheduler Admission Failure TLC Check

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

## Target

```text
formal/0013-scheduler-admission-failure-model/SchedulerAdmissionFailure.tla
formal/0013-scheduler-admission-failure-model/SchedulerAdmissionFailureSafe.cfg
formal/0013-scheduler-admission-failure-model/SchedulerAdmissionFailureUnsafeWaking.cfg
formal/0013-scheduler-admission-failure-model/SchedulerAdmissionFailureUnsafeRollback.cfg
```

## Purpose

Validate the TASK_WAKING failability boundary from:

```text
analysis/0030-task-waking-failability-boundary-map.md
```

The question is whether a future CapSched runnable-admission check may be
fail-capable after Linux writes `TASK_WAKING`.

## Commands

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0013-scheduler-admission-failure-model
```

Safe model:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/admission-failure-safe \
  -config SchedulerAdmissionFailureSafe.cfg \
  SchedulerAdmissionFailure.tla
```

Unsafe delayed-freeze model:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/admission-failure-unsafe-waking \
  -config SchedulerAdmissionFailureUnsafeWaking.cfg \
  SchedulerAdmissionFailure.tla
```

Unsafe rollback model:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/admission-failure-unsafe-rollback \
  -config SchedulerAdmissionFailureUnsafeRollback.cfg \
  SchedulerAdmissionFailure.tla
```

## Results

### Safe Model

TLC completed with no invariant errors.

Summary:

```text
8 states generated
7 distinct states found
0 states left on queue
depth 5
```

Checked:

```text
TypeOK
NoTaskWakingWithoutFrozenUse
NoRunqueueCustodyWithoutFrozenUse
NoLostWakeAfterCondition
PreRejectDoesNotMutateLinuxWakeState
```

### Unsafe Delayed-Freeze Counterexample

TLC found the expected violation:

```text
Invariant NoTaskWakingWithoutFrozenUse is violated.
```

Counterexample shape:

```text
Idle, frozen = FALSE, linuxState = Blocked
  -> UnsafeSetTaskWakingWithoutFreeze
TaskWakingSet, frozen = FALSE, linuxState = TaskWaking
```

This rejects the design where CapSched writes or allows `TASK_WAKING` before
freezing runnable authority.

### Unsafe Rollback Counterexample

TLC found the expected violation:

```text
Invariant NoLostWakeAfterCondition is violated.
```

Counterexample shape:

```text
Idle, conditionDelivered = FALSE
  -> UnsafeSetTaskWakingWithoutFreeze
TaskWakingSet, conditionDelivered = TRUE, linuxState = TaskWaking
  -> UnsafeRollbackAfterTaskWaking
LostWake, conditionDelivered = TRUE, linuxState = Blocked
```

This rejects the simple rollback idea:

```text
set TASK_WAKING
check authority
if denied, put the task back to blocked
```

Without a stronger rollback/quarantine proof, that can lose the wake.

## Claim Boundary

Allowed claim:

```text
The tiny model supports a conservative hook-selection rule: fail-capable
admission freeze must happen before TASK_WAKING; post-TASK_WAKING checks must
be nofail assertions, fail-closed stops, or separately proven rollback paths.
```

Forbidden claim:

```text
The real Linux wakeup implementation has been fully proven.
A concrete hook point is approved for implementation.
Linux L0 now enforces runnable authority.
```

## Next Work

Before implementation, refine:

```text
F1 data dependencies under p->pi_lock
RT/freezer saved_state interactions
wake_up_new_task() SpawnCap boundary
CONFIG_CAPSCHED assertion behavior at activate_task()/enqueue_task()
```
