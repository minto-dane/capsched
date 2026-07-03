# P5A-R EEVDF Return Dominance Model

This model backs the source-shape checker for current `pick_eevdf()` return
dominance. It does not approve a Linux behavior patch.

The model requires every selected EEVDF candidate path to be dominated by a
future ineligibility predicate or return funnel before any deny-and-repick
behavior can be claimed. It also rejects wakeup-preempt semantic bleed, hot-path
cost breakage, line-only drift claims, hierarchy-settlement overclaims, and
behavior approvals from this source-shape evidence alone.
