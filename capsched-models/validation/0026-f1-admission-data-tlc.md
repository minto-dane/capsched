# Validation 0026: F1 Admission Data TLC Check

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

## Target

```text
formal/0014-f1-admission-data-model/F1AdmissionData.tla
formal/0014-f1-admission-data-model/F1AdmissionDataSafe.cfg
formal/0014-f1-admission-data-model/F1AdmissionDataUnsafeSlow.cfg
formal/0014-f1-admission-data-model/F1AdmissionDataUnsafeAllocation.cfg
formal/0014-f1-admission-data-model/F1AdmissionDataUnsafeMonitor.cfg
formal/0014-f1-admission-data-model/F1AdmissionDataUnsafeMissing.cfg
formal/0014-f1-admission-data-model/F1AdmissionDataUnsafePlacement.cfg
```

## Purpose

Validate the F1 pre-`TASK_WAKING` data-readiness rule from:

```text
analysis/0031-f1-admission-freeze-data-dependencies.md
```

The question is whether a future CapSched runnable-admission freeze may depend
on allocation, slow authority discovery, monitor calls, or missing placement
data while `p->pi_lock` is held.

## Commands

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0014-f1-admission-data-model
```

Safe model:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-safe \
  -config F1AdmissionDataSafe.cfg \
  F1AdmissionData.tla
```

Unsafe models:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-unsafe-slow \
  -config F1AdmissionDataUnsafeSlow.cfg \
  F1AdmissionData.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-unsafe-allocation \
  -config F1AdmissionDataUnsafeAllocation.cfg \
  F1AdmissionData.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-unsafe-monitor \
  -config F1AdmissionDataUnsafeMonitor.cfg \
  F1AdmissionData.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-unsafe-missing \
  -config F1AdmissionDataUnsafeMissing.cfg \
  F1AdmissionData.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/f1-data-unsafe-placement \
  -config F1AdmissionDataUnsafePlacement.cfg \
  F1AdmissionData.tla
```

## Results

### Safe Model

TLC completed with no invariant errors.

Summary:

```text
259 states generated
259 distinct states found
0 states left on queue
depth 5
```

Checked:

```text
TypeOK
NoSlowOperationUnderPiLock
NoAllocationUnderPiLock
NoMonitorCallUnderPiLock
NoTaskWakingWithoutFrozenUse
NoFreezeWithoutAllRequiredLocalData
NoQueuedWithoutPlacementEnvelope
NoMissingDataAfterTaskWaking
RejectBeforeTaskWakingOnly
```

### Unsafe Slow Lookup Counterexample

TLC found the expected violation:

```text
Invariant NoSlowOperationUnderPiLock is violated.
```

Counterexample shape:

```text
F1, piLock = TRUE, required data missing
  -> UnsafeSlowLookupUnderPiLock
BadSlowOp, piLock = TRUE, slowOp = TRUE
```

This rejects F1 designs that discover authority through slow policy walks,
global mutable endpoint tables, remote cluster calls, or sleepable paths.

### Unsafe Allocation Counterexample

TLC found the expected violation:

```text
Invariant NoAllocationUnderPiLock is violated.
```

Counterexample shape:

```text
F1, piLock = TRUE, FrozenSlot missing
  -> UnsafeAllocateFrozenSlotUnderPiLock
BadAllocation, piLock = TRUE, allocation = TRUE
```

This rejects on-demand `FrozenRunUse` allocation from `try_to_wake_up()`.

### Unsafe Monitor Call Counterexample

TLC found the expected violation:

```text
Invariant NoMonitorCallUnderPiLock is violated.
```

Counterexample shape:

```text
F1, piLock = TRUE, required data missing
  -> UnsafeMonitorCallUnderPiLock
BadMonitorCall, piLock = TRUE, monitorCall = TRUE
```

This rejects designs that mint or validate authority by entering the monitor
while holding `p->pi_lock`.

### Unsafe Missing Data Counterexample

TLC found the expected violation:

```text
Invariant NoFreezeWithoutAllRequiredLocalData is violated.
```

Counterexample shape:

```text
F1, required data missing
  -> UnsafeFreezeWithMissingData
BadMissingData, frozen = TRUE
```

This rejects freezing an incomplete runnable lease.

### Unsafe Placement Counterexample

TLC found the expected violation:

```text
Invariant NoQueuedWithoutPlacementEnvelope is violated.
```

Counterexample shape:

```text
F1, all data except Placement ready
  -> UnsafeFreezeWithoutPlacementEnvelope
Frozen, placement missing
  -> SetTaskWaking
TaskWaking, frozen = TRUE
  -> UnsafeSelectCpuOutsideEnvelope
BadPlacement, queued = TRUE, selectedCpuAllowed = FALSE
```

This rejects a design where CPU placement authority is first discovered after
`TASK_WAKING`.

## Claim Boundary

Allowed claim:

```text
The tiny model supports a conservative design filter: F1 is validation and
freeze, not authority discovery. Required authority, generation, epoch,
budget, placement, and storage data must be local, stable, and ready before
F1 can freeze. If data is missing, reject before TASK_WAKING.
```

Forbidden claim:

```text
The real Linux wakeup implementation has been fully proven.
A concrete CapSched hook point is approved.
Linux L0 now enforces runnable authority.
The placement rule is final or performance-optimal.
```

## Next Work

Refine the data-preparation side:

```text
block/wait/register authority preparation
wake_q_add readiness and revoke-before-wake_up_q behavior
placement refresh across affinity, cpuset, and CPU hotplug
embedded vs preallocated FrozenRunUse storage cost
```
