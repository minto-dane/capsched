# P5A-R4 E1 Dispatch and Lifetime Evidence Plan Model

This finite model checks the no-source R4-E1 engineering boundary selected by
analysis/0173. Its safe trace exercises a duplicate rq-locked kick, publication
while irq-work is pending, post-lock irq-to-work dispatch, one-projection
recovery of the newest generation, an old partial notifier pass followed by a
final-generation restart, current stop requests, and ordered offline
irq/work/RCU drain.

`P5AR4E1DispatchLifetimeEvidencePlanSafe.cfg` checks safety plus three weakly
fair liveness properties: the bridge eventually repairs the newest generation,
the stable notifier pass eventually visits every active rq and requests current
stop, and offline eventually drains and frees only after synchronization.

The validation runner generates one unsafe configuration for every fault in
the JSON contract. Each must violate `TypeOK` or `Safety`; none is evidence of
Linux runtime behavior, protection, or latency.
