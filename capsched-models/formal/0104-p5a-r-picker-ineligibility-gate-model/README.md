# P5A-R Picker Ineligibility Gate Model

This model captures the minimum safety shape for a future CFS-only
deny-one-and-pick-next implementation.

It is not Linux implementation approval. It requires a denied candidate to
become picker-visible ineligible before retry, rejects late denial after
`rq->curr` publication, and rejects replacing SchedExecLease authority with
Linux retry, delayed dequeue, class state, idle fallback, core cached picks,
DL server state, proxy executor state, or sched_ext dispatch.

The model also rejects design families that would be too expensive or too
brittle for a datacenter kernel: unbounded or linear candidate search,
persistent hot-struct denial bits, wakeup-preempt bleed, stale task/exec/domain
generations, hierarchy mutation without settlement, uncovered EEVDF return
paths, DL-server retry leakage, delayed-dequeue pointer lifetime reuse,
throttling limbo aliasing, core sequence or hotplug leakage, Linux-local
authority forgery, and unsupported core/proxy/SCX/DL-server production claims.
