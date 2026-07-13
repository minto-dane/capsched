# Formal 0122: P5A-R2 Summary Update Closure

Date: 2026-07-13

Status: contract model. No Linux patch or runtime/protection claim is approved.

This model checks that every event family which can invalidate a future
Fresh/pickable summary closes the child summary and its parent group projection
under runqueue-lock ownership before the state is released to the picker.

The modeled event families are:

```text
rb mutation
current transition
group projection
lifecycle/generation
budget transition
placement/migration
throttle/refill
domain/grant epoch
monitor revoke
outer selector generation
```

Placement additionally requires old-rq invalidation before unlock and
destination publication only after locked activation. The model also rejects
using PELT propagation as Fresh propagation, picker repair scans, monitor calls
from the picker, unkeyed selector summaries, omitted final entity revalidation,
and premature implementation or assurance claims.

`P5AR2SummaryUpdateClosureSafe.cfg` uses `Fault = "None"`. Each of the 24
unsafe configurations injects one missing closure or forbidden claim and must
produce a `Safety` counterexample.
