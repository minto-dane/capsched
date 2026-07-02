# P5A Scope Gate

This model records the first post-P4 P5A scope proposal.

Safe state:

```text
P5A scope recorded.
P5A is decomposed into P5A0, P5A-R, P5A-M, and P5A-V.
P5A0 is no-behavior only.
Linux implementation is not approved.
Runtime denial is not approved.
```

It rejects:

- no decomposition;
- Linux implementation approval from a scope proposal;
- behavior change in P5A0;
- using the current P4 run hook as a denial hook;
- deny-one-CFS-and-pick-next without fair-picker eligibility;
- broad move denial without status and caller settlement;
- unsupported path coverage/protection claims;
- missing negative tests;
- monitor, protection, hypervisor-grade, cost, or deployment claims.
