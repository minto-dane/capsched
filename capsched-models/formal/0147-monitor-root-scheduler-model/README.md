# Monitor Root Scheduler Model

This model supplies the first `ROOTSCHED-001` reference contract. It composes
an adversarial Linux policy plane with the minimum root scheduling state that
must remain Monitor-owned.

The safe reference policy is a four-slot cyclic frame:

```text
management/recovery -> guaranteed 1 -> guaranteed 2 -> best-effort slack
```

Reserved slots create Monitor-known service opportunities. They do not depend
on a Linux runnable hint: a compromised current Domain could otherwise hide a
different Domain forever. A service opportunity means that the Monitor
activates a fresh Domain lease and view. It does not promise that compromised
or idle Domain-local Linux will run a useful task.

Linux may mutate candidate hints, a shadow cursor, and extension requests.
Those fields cannot mint, extend, retime, or suppress Monitor authority.
Monitor/hardware weak fairness is explicit; no fairness is assumed for Linux.

The model checks:

```text
NoRootRunWithoutLease
NoRootBudgetOverrun
LinuxCannotExtendRootLease
CurrentEpochOnly
ReservedSlotIntegrity
GuaranteedOnlyUsesReservedSlot
BestEffortOnlyUsesSlack
ExpiredOrRevokedAuthorityCleared
BoundedGuaranteedWait
ManagementAlwaysAdmitted
LinuxCannotMintRootAuthority
AdmittedGuaranteedEventuallyRuns
GuaranteedRecurringService
ManagementRecurringService
TrustedHandoffProgress
```

Two safe configurations separate steady-state recurring service from dynamic
revocation safety. Negative configurations demonstrate failures caused by
Linux-gated reserved dispatch, skipped or stolen reserved slots, stale epochs,
Linux lease extension, running after expiry, terminal stop after expiry,
management revocation, missing Monitor timers, and Linux-minted authority.

The fixed frame is an executable lower-bound contract, not a final Monitor
implementation choice. Dynamic admission, variable reservations, multi-CPU
servers, global Domain cardinality, resident-slot eviction, migration, and
cost optimization remain for `RESIDENCY-001` and later refinement models.

This model supports semantic design only. It does not implement a Monitor,
modify Linux, prove architecture timer delivery, establish WCET, or provide
hypervisor-grade protection evidence.
