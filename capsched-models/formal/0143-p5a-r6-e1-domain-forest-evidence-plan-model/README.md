# P5A-R6 E1 Domain-Forest Evidence Plan Model

This bounded model turns the source-free R6-E1 contract into an executable
rejection gate. The safe trace updates a mutable selector leaf, performs the
two bounded masked-query phases, migrates one contribution through a neutral
state, publishes revocation, separately observes current-task stop, removes
CPU visibility, drains references, waits for RCU, and frees the private state.

Safety binds the immutable descriptor generation, live leaf/summary version,
127/127/254 query bounds, 64-slot reconcile bound, allowed-domain selection,
single-rq contribution, offline admission order, and reference/RCU lifetime.
The complete safety-fault set additionally represents the exact hierarchy,
allocation, layout-only E2 boundary, diagnostic gates, and non-claim ledger
that cannot be usefully expanded into this finite transition trace.

Two liveness properties cover allowed-domain selection and separately
observed stop of a revoked current task. This model authorizes neither R6
source nor runtime behavior; a passing validation may authorize only the
disposable default-off R6-E2 layout candidate.
