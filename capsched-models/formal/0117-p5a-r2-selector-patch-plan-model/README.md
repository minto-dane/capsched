# P5A-R2 Selector Patch Plan Model

This model gates the next P5A-R2 Linux-facing selector direction before any new
behavior patch is approved.

The safe path reaches `PatchPlanReady` only if the future patch is constrained
to an EEVDF-compatible fresh-summary design, rejects the experimental `0012`
post-filter fallback as a production direction, preserves the outer
Domain/SchedContext selector, and records acceptance validation requirements.

The unsafe configs each remove one required precondition or add a forbidden
claim.
