# Validation 0001: Runnable Lease TLC Check

Status: Passed for tiny finite model

Date: 2026-06-25

Model:

```text
capsched/capsched-models/formal/0002-runnable-lease-model/RunnableLease.tla
capsched/capsched-models/formal/0002-runnable-lease-model/RunnableLease.cfg
```

Tool:

```text
TLC2 Version 2.19 of 08 August 2024
java: /usr/bin/java
tla2tools.jar: /home/nia/tools/tla/tla2tools.jar
```

Command:

```text
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC RunnableLease.tla
```

Working directory:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0002-runnable-lease-model
```

## Result

TLC completed without invariant errors.

Summary:

```text
227201 states generated
28450 distinct states found
0 states left on queue
complete graph depth: 31
no error found
```

Fingerprint risk estimate reported by TLC:

```text
optimistic: 3.1E-10
actual fingerprints: 1.0E-11
```

## Checked Invariants

The run checked:

```text
TypeOK
NoQueuedWithoutFrozenUse
NoSelectedWithoutSchedContext
NoSelectedWithExhaustedBudget
NoSelectedWithMismatchedTaskGeneration
NoSelectedWithMismatchedDomainEpoch
NoRunningWithoutDomainActivation
NoGrantReuseAfterRevocation
NoBudgetUnderflow
NoCpuOutsidePlacement
NoTaskOnTwoCpus
StateMatchesCpuMaps
```

## Deadlock Handling

`CHECK_DEADLOCK FALSE` is set in `RunnableLease.cfg`.

Reason: the model has intentional terminal states where all Domain epochs and
task generations are exhausted or all tasks are dead/referenced. Those states
are valid for a safety model. The objective of this run is invariant checking,
not liveness proof.

## Scope

Tiny finite configuration:

```text
2 tasks
2 domains
2 CPUs
2 sched contexts
budget values: 0..2
epochs: 0..1
task/process generations: 0..1
all placement sets allow both CPUs in this first model
MonitorAllowsRun is a placeholder that accepts valid domain/epoch/CPU tuples
```

## Interpretation

This validates only the first execution-authority story under the stated
abstractions:

```text
policy approval alone does not run a task
RunCap must be frozen into FrozenRunUse before enqueue
pick/activation re-check generation, Domain epoch, budget, and CPU placement
Domain epoch revocation clears active runnable state in this strict model
budget exhaustion stops CPU execution
exec does not change Domain and refreshes process generation for current grant
```

This is not evidence of Linux implementation correctness and not evidence of
hypervisor-grade isolation.

## Design Pressure Found

The model currently chooses eager revocation:

```text
RevokeDomainEpoch clears affected caps, grants, queued/selected/running state.
```

If the Linux L0 implementation chooses lazy revocation instead, the invariant
`NoQueuedWithoutFrozenUse` must be deliberately weakened, or the implementation
must guarantee that stale queued grants cannot survive as queue authority.

The next design step is to derive the L0 patch plan from this state machine,
especially:

```text
where FrozenRunUse lives
which wake/enqueue paths must prepare or validate it
what budget exhaustion means for scheduler classes
how epoch revocation synchronizes with queued/selected/running tasks
how cpuset/affinity changes refresh allowed CPU sets
```
