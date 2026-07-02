# P5 Readiness After P4 Gate

This model records the post-P4 state:

```text
P4 allow-only compatibility is closed.
The current P4 run hook is before rq->curr/context_switch, but not pre-class-settle.
Move hooks are before local mutation, but lack denial-status plumbing.
P5 remains blocked.
```

It rejects:

- approving P5 without source evidence;
- treating the current P4 run hook as a denial hook;
- approving P5 while the run hook is post-settle and no rollback is proved;
- approving move denial without status plumbing;
- approving P5 without negative tests or path classification;
- runtime coverage, monitor, production protection, hypervisor-grade,
  cost-efficiency, or deployment-readiness claims.
