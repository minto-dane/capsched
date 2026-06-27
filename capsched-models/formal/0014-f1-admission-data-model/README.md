# Formal 0014: F1 Admission Data Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-27

## Purpose

This model refines the F1 pre-`TASK_WAKING` admission boundary.

It checks the design rule:

```text
F1 may freeze only from already-local data.
If required data is missing, reject before TASK_WAKING.
Do not allocate, sleep, call monitor, or perform remote/policy lookup under
p->pi_lock.
```

It supports:

```text
analysis/0031-f1-admission-freeze-data-dependencies.md
```

## Required Data

The model treats these fields as required before F1 can freeze:

```text
RunCap
SchedCtx
Domain
Generation
FrozenSlot
Placement
Budget
```

`Placement` stands for a precomputed placement envelope proving that later Linux
CPU selection cannot escape the FrozenRunUse CPU authority.

`FrozenSlot` stands for embedded or preallocated storage for the frozen use.

## Configurations

Safe:

```text
F1AdmissionDataSafe.cfg
```

Expected result:

```text
TLC passes.
```

Unsafe:

```text
F1AdmissionDataUnsafeSlow.cfg
F1AdmissionDataUnsafeAllocation.cfg
F1AdmissionDataUnsafeMonitor.cfg
F1AdmissionDataUnsafeMissing.cfg
F1AdmissionDataUnsafePlacement.cfg
```

Expected result:

```text
TLC produces counterexamples.
```

Validation record:

```text
validation/0026-f1-admission-data-tlc.md
```

## Interpretation

The model is intentionally small. It does not prove Linux wakeups. It is a
design filter:

```text
Any F1 design that needs missing data to be acquired while p->pi_lock is held
is rejected.
```

The first admissible shape is:

```text
precompute or pre-pin authority before F1
freeze a preallocated local record at F1
assert at enqueue
revalidate at pick/switch
```
