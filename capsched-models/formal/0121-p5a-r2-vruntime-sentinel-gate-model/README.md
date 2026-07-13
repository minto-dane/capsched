# P5A-R2 Vruntime Sentinel Gate Model

This model checks the representation gate for a future EEVDF-compatible
SchedExecLease pickable summary.

The safe configuration rejects literal `U64_MAX` as vruntime infinity,
requires an explicit validity tag paired with a wrap-aware minimum, ignores
the numeric member when invalid, keeps `curr` separate from the rb-tree
aggregate, projects child `cfs_rq` validity through group entities, and keeps
Linux behavior and protection claims unapproved.

Each unsafe configuration changes one representation, propagation, or claim
condition and is expected to violate `Safety`.
