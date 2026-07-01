# Direct-Call Workqueue Adapter Refinement Model

This model checks the N-127 workqueue side of the async-carrier adapter split.

It refines the broad N-126 API sketch into a workqueue-specific transition
model for Domain-originated async work carried by a future typed wrapper around
Linux workqueue publication.

Safe design pressure:

```text
create empty carrier storage
freeze caller tuple before queue_work publication
bind service/resource authority
publish typed wrapper
handle queue_work false without overwriting the first carrier
settle and release rejected second-caller candidates
handle delayed-work retiming without receipt refresh
handle self-requeue without receipt refresh
enter callback without worker identity authority
revoke_check before validate
side effects only after validate
settle exactly once
release only CapSched refs, not Linux work object lifetime
reject service-only budget accounting
reject rescuer or pending-clear authority shortcuts
```

Unsafe configurations reject:

```text
side effect before validate
pending overwrite
second-caller leak
delayed retime receipt refresh
self-requeue receipt refresh
worker identity authority
cancel/flush as monitor revoke receipt
release freeing or dropping Linux work refs
double settlement
freeze after publication
service-only budget
rescuer bypass
pending clear as monitor revoke receipt
ABI approval
behavior change
monitor verification claim
production protection claim
```

This is not Linux implementation, runtime coverage, ABI approval, monitor
verification, behavior change, or production protection.
