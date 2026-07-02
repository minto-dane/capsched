# Candidate Scoped Drift Closure Gate

This model separates two facts that must not collapse:

```text
global model freshness:
  every watched model family is fresh.

candidate scoped drift closure:
  the watched groups touched or claimed by one candidate slice are fresh,
  while unrelated stale groups remain recorded and cannot support broad claims.
```

The safe configuration represents the current P4 state after N-167:

```text
candidate: P4SchedulerAllowAll
globalModelFresh: false
staleGroupsExist: true
staleGroupsInCandidateScope: false
candidateScopeDriftClosed: true
p4ImplementationApproved: false
```

The gate intentionally does not approve P4 implementation. P4 still requires a
final-run anchor manifest, queued-move anchor manifest, and runtime or static
anchor observability. It also does not approve runtime denial, runtime coverage,
monitor verification, production protection, hypervisor-grade isolation,
cost-efficiency, or deployment readiness.
