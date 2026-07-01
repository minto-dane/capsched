# Direct-Call Async Carrier API Sketch Model

This model checks the N-125 no-behavior `capsched_async_carrier` API sketch.

It refines the sketch into a small transition-ordering model for two adapter
surfaces:

```text
workqueue
io_uring
```

Safe design pressure:

```text
create empty carrier
freeze immutable caller tuple
bind immutable service/resource tuple
publish through a typed adapter
handle workqueue coalescing or io_uring request/reissue mechanics
revoke_check before validation
validate effective authority as service/resource intersect caller authority
perform side effects only after validation
settle BudgetTicket and receipt exactly once
release CapSched refs without owning Linux object cleanup
```

Unsafe configurations reject:

```text
side effects before validate
immutable tuple overwrite
second caller leak
pending carrier overwrite
double settlement
release coupled to Linux refs/free/completion
CQE as settlement proof
REQ_F_REISSUE as receipt refresh
authority intersection not modeled as subset of both inputs
Linux object identity as authority
ABI approval
behavior change
monitor verification claim
production protection claim
```

This is still not Linux implementation, runtime coverage, monitor
verification, ABI approval, behavior change, or production protection.
