# P5A-R4 E3 Concurrency and Diagnostic Evidence Plan Model

This finite model checks the pre-source R4-E3 boundary from analysis/0174. Its
safe trace forces a duplicate rq-locked kick, publication while irq-work is
pending, dispatch-only irq-to-unbound-work handoff, newest-generation recovery,
an insertion racing the worker's final-empty check, self-requeue, a partial old
notifier pass followed by generation and membership restart, late admission,
separate current request/observation, remove-neutral-add migration, and ordered
offline/retirement/RCU drain.

The safe configuration checks safety plus four weakly fair liveness
properties: the bridge eventually repairs the newest generation, a stable
notifier pass covers membership including late admission, a current request
receives a later scheduler observation, and offline eventually drains before
free.

The validation runner generates one unsafe configuration for every fault in
the JSON contract. Protocol faults are injected into the relevant transition;
scope, evidence, diagnostic, and claim faults violate the plan contract. Every
unsafe configuration must produce an invariant counterexample. The model is a
finite plan check, not evidence of Linux runtime behavior, wall-clock latency,
protection, or deployment readiness.
