# P5A-R2 Invalidation Semantics Gate

This model checks the semantic contract that follows the P5A-R2 invalidation
source map.

The gate does not approve a Linux patch. It only allows the semantics to become
ready when the summary state machine has explicit `Fresh`, `Stale`,
`Refreshing`, and `Blocked` states; invalidation propagates to leaf, current,
group, and future monitor receipt summaries; refresh requires frozen authority
and fresh generation/epoch/budget/affinity checks; and the picker trusts only
fresh summaries.

The unsafe configurations reject stale picker trust, in-place stale-to-fresh
transition without refresh, enqueue-only refresh, group-summary false positives
or silent false negatives, current/tree collapse, policy or monitor calls in
the picker, missing outer Domain/SchedContext constraint, Linux patch approval,
and runtime/protection/cost/datacenter claims.
