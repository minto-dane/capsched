# Validation 0027: Wake Authority Preparation TLC Check

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-06-27

## Target

```text
formal/0015-wake-authority-preparation-model/WakeAuthorityPreparation.tla
formal/0015-wake-authority-preparation-model/WakeAuthorityPreparationSafe.cfg
formal/0015-wake-authority-preparation-model/WakeAuthorityPreparationUnsafeWakeQ.cfg
formal/0015-wake-authority-preparation-model/WakeAuthorityPreparationUnsafeLazy.cfg
formal/0015-wake-authority-preparation-model/WakeAuthorityPreparationUnsafeRevoke.cfg
```

## Purpose

Validate the wake authority preparation rule from:

```text
analysis/0032-block-wait-register-authority-preparation.md
```

The question is whether a future CapSched wake path can safely discover
authority at `wake_q_add()`, `wake_up_q()`, or F1, or whether it must already
be prepared before those hot-path wake boundaries.

## Commands

Run from:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/formal/0015-wake-authority-preparation-model
```

Safe model:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/wake-authority-safe \
  -config WakeAuthorityPreparationSafe.cfg \
  WakeAuthorityPreparation.tla
```

Unsafe models:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/wake-authority-unsafe-wakeq \
  -config WakeAuthorityPreparationUnsafeWakeQ.cfg \
  WakeAuthorityPreparation.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/wake-authority-unsafe-lazy \
  -config WakeAuthorityPreparationUnsafeLazy.cfg \
  WakeAuthorityPreparation.tla

java -cp /home/nia/tools/tla/tla2tools.jar tlc2.TLC \
  -metadir /media/nia/scsiusb/dev/linux-cap/build/tlc/wake-authority-unsafe-revoke \
  -config WakeAuthorityPreparationUnsafeRevoke.cfg \
  WakeAuthorityPreparation.tla
```

## Results

### Safe Model

TLC completed with no invariant errors.

Summary:

```text
18 states generated
17 distinct states found
0 states left on queue
depth 8
```

Checked:

```text
TypeOK
NoWakeQWithoutPreparedAuthority
NoF1LazyDiscovery
NoTaskWakingWithoutPreparedFrozenUse
NoEnqueueWithoutPreparedFrozenUse
NoExecutionAfterRevocation
RejectRevokedBeforeTaskWaking
```

### Unsafe WakeQ Counterexample

TLC found the expected violation:

```text
Invariant NoWakeQWithoutPreparedAuthority is violated.
```

Counterexample shape:

```text
Start, prepared = FALSE
  -> UnsafeWakeQAddWithoutPrepared
BadWakeQNoAuthority, wakeQueued = TRUE
```

This rejects a design where `wake_q_add()` is used before the target task or
waiter has prepared runnable authority.

### Unsafe Lazy F1 Discovery Counterexample

TLC found the expected violation:

```text
Invariant NoF1LazyDiscovery is violated.
```

Counterexample shape:

```text
Start, prepared = FALSE
  -> UnsafeLazyDiscoveryAtF1
BadLazyDiscovery, frozen = TRUE, taskWaking = TRUE
```

This rejects a design where F1 tries to discover missing authority when wake
delivery reaches the scheduler hot path.

### Unsafe Revoke Counterexample

TLC found the expected violation:

```text
Invariant NoExecutionAfterRevocation is violated.
```

Counterexample shape:

```text
PrepareAuthority
  -> RegisterAndBlock
  -> WakeQAddPrepared
  -> RevokeBeforeWake
  -> UnsafeIgnoreRevokeAfterWakeQ
BadRevokedExecution, revoked = TRUE, running = TRUE
```

This rejects a design where authority was valid at `wake_q_add()` but revoked
before actual wake delivery, and the later F1/selected/switch checks ignore it.

## Claim Boundary

Allowed claim:

```text
The tiny model supports a conservative design rule: authority must be prepared
before wake_q_add()/wake_up_q()/F1; F1 may reject revoked/stale authority before
TASK_WAKING, but it must not discover missing authority.
```

Forbidden claim:

```text
The real Linux waitqueue/futex/workqueue/locking implementation is proven.
Task-local storage shape is approved.
Shared futex cross-Domain behavior is safe.
Priority inheritance semantics are modeled.
Workqueue caller BudgetTicket semantics are modeled.
```

## Next Work

Refine:

```text
ordinary task-local resumable-run storage lifecycle
shared futex endpoint semantics
workqueue/kthread_work caller BudgetTicket carrier
PI/RT/ww_mutex priority donation authority
```
