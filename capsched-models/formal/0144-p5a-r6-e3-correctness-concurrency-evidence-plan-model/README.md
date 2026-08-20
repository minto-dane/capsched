# P5A-R6 E3 Correctness and Concurrency Evidence Plan Model

This small ordering model validates the source-free R6-E3 evidence boundary.
The safe trace covers exact descriptor observation, bounded masked selection,
accounting, revocation and reconciliation, zero-catch-up reallow, migration
through a neutral state, separate current-stop request/observation, offline
visibility removal, reference drain, RCU grace, and free.

`EvidenceSafety` checks generation monotonicity, 127/127/254 query bounds,
64-slot reconciliation, six-ancestor mutation, tree-version coherence,
allowed-only selection/service, no negative lag or catch-up credit, migration
single-contribution, offline invisibility, and free-after-drain ordering.

The three temporal properties require an allowed pick, a later revoked-current
observation, and eventual offline reader/ref/grace drain. Generated unsafe
configs cover every safety and liveness fault named by the tracked R6-E3 plan.
This is plan/order evidence only; it is not a model of all Linux EEVDF states
and does not prove production scheduler behavior.
