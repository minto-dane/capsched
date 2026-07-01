# Implementation 0014: Linux Async Carrier Candidate Patch Plan

Status: candidate patch plan only, no Linux patch approved yet

Date: 2026-07-01

Related artifacts:

```text
implementation/0013-combined-async-adapter-precondition-gate.md
implementation/combined-async-adapter-precondition-gate-v1.json
formal/0062-combined-async-adapter-precondition-model/
validation/0100-combined-async-adapter-precondition-tlc.md
analysis/0084-direct-call-workqueue-adapter-refinement.md
analysis/0085-direct-call-io-uring-adapter-refinement.md
validation/0098-direct-call-workqueue-adapter-tlc.md
validation/0099-direct-call-io-uring-adapter-tlc.md
linux/include/linux/capsched.h
linux/kernel/sched/capsched.c
```

## Purpose

This plan translates the combined async-adapter precondition gate into the only
Linux work that may be considered next.

The result is not an implementation approval. It is a plan for a future
candidate patch proposal.

## Current Linux State

The local Linux branch `capsched-linux-l0` currently has only inert/type-only
CapSched scaffolding:

```text
include/linux/capsched.h
kernel/sched/capsched.c
kernel/sched/Makefile
CONFIG_CAPSCHED
```

No task layout change, workqueue hook, io_uring hook, direct-call ABI, public
tracepoint ABI, monitor call, or behavior change is accepted.

## Allowed Next Patch Classes

### Class A: No Linux Patch

Allowed:

```text
continue source maps, models, traceability, and implementation planning only
```

Meaning:

```text
no Linux behavior changes
no compile impact
no ABI
no runtime coverage claim
```

### Class B: No-Behavior Opaque Type Scaffolding

Potentially allowed only after a separate patch proposal:

```text
forward declare struct capsched_async_carrier
optionally forward declare adapter-specific opaque names
add comments preserving the N-129 non-claims
```

Strict limits:

```text
no object layout
no allocation
no refcounting
no function prototypes with callable semantics
no workqueue include or hook
no io_uring include or hook
no tracepoint
no UAPI
no module parameter
no static key
no behavior change
```

This class may be useful only if it improves traceability or future patch
review. It does not make async carriers real.

### Class C: No-Behavior Internal Stub Translation Unit

Potentially allowed only after a separate patch proposal:

```text
add inert documentation comments to kernel/sched/capsched.c
or add a private, uncalled, compile-only placeholder section
```

Strict limits:

```text
no exported symbols
no callable hooks
no scheduler path references
no workqueue references
no io_uring references
no direct-call monitor entry
no runtime state
```

This class is lower priority than Class B because even inert code can create
maintenance noise.

## Blocked Patch Classes

### Workqueue Adapter Hook

Blocked until a future proposal supplies:

```text
typed wrapper lifetime and ownership
queue_work false first-carrier preservation path
second-caller reject/settle/release path
delayed retime and self-requeue rules
rescuer execution handling
cancel/flush/pending-clear non-authority proof
caller BudgetTicket settlement table
locking and memory-ordering review
KUnit/fault-injection plan
source-drift update
```

### io_uring Adapter Hook

Blocked until a future proposal supplies:

```text
request carrier storage and lifetime
SQE consume before freeze rule
fixed file/buffer resource generation snapshot
io-wq punt and worker issue ordering
REQ_F_REISSUE non-refresh rule
cancel/CQE/free non-authority proof
linked request carrier relation
resource update/unregister ordering
uring_cmd typed endpoint classification
SQPOLL and credential non-authority proof
locking and memory-ordering review
KUnit/fault-injection plan
source-drift update
```

### Direct-Call or Monitor ABI

Blocked until monitor-owned request/receipt/revoke semantics move beyond model
and source-only evidence.

Forbidden:

```text
binary ABI
UAPI
public tracepoint ABI
debugfs control surface
sysfs control surface
ioctl
syscall
module parameter
```

### Behavior-Changing Enforcement

Blocked. The current evidence is model/source/gate evidence only.

Forbidden:

```text
rejecting workqueue submissions
changing io_uring request execution
charging runtime budgets
changing scheduler decisions
activating monitor calls
claiming protection
```

## Candidate Patch Recommendation

Do not patch Linux yet for async carriers.

The safest next Linux-facing artifact is a candidate patch proposal document
only. If a Linux patch is later desired, the first acceptable patch should be a
tiny no-behavior opaque-name patch, likely limited to:

```text
include/linux/capsched.h
```

Candidate addition, not approved code:

```c
struct capsched_async_carrier;
struct capsched_workqueue_adapter;
struct capsched_io_uring_adapter;
```

with comments stating that these are not object layouts, not APIs, not hooks,
not authority, and not protection.

## Required Review Before Any Patch

Before even a no-behavior async-carrier Linux patch:

```text
1. Confirm the patch touches no behavior path.
2. Confirm it introduces no callable function prototype.
3. Confirm it introduces no public or private ABI.
4. Confirm it does not include workqueue or io_uring headers.
5. Confirm `CONFIG_CAPSCHED=n` and `CONFIG_CAPSCHED=y` build expectations are
   documented.
6. Confirm patch queue export/recreate steps are planned.
7. Confirm non-claims are present in commit message and validation record.
```

Before any behavior-changing async-carrier Linux patch:

```text
1. N-129 must remain satisfied.
2. Workqueue or io_uring adapter-specific blockers must be closed for the
   touched surface.
3. A new behavior-specific formal model must be checked.
4. KUnit/fault-injection/runtime tracing plans must exist.
5. Monitor receipt semantics must be implemented or the patch must remain
   Linux-only and non-security-claiming.
6. The assurance case must explicitly reject production protection claims.
```

## Non-Claims

This plan does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
