# P5A0 No-Behavior Gate Model

Status: checked gate model for the P5A0 proposal.

This model deliberately does not model CFS runnable selection, migration,
affinity, swap, push, or core scheduling behavior. P5A0 is a no-behavior
proposal gate.

The safe configuration accepts only this state:

- P5A scope is recorded.
- P5A0 proposal is recorded.
- No Linux patch is approved by this proposal.
- No behavior change, runtime denial, retry, fail-closed, quarantine, public
  ABI, or monitor call is approved.
- No config-off object impact, task/rq/sched_entity/cfs_rq layout change,
  exported symbol, public tracepoint ABI, runtime coverage claim, monitor
  verification claim, hypervisor-grade claim, or datacenter-readiness claim is
  approved.
- Move status plumbing and setup-time path disabling are only planned shapes.
- Test observability is internal-only.
- Required prepatch and acceptance validation plans are recorded.
- Protection, cost-efficiency, and deployment-readiness claims are not made.

The unsafe configurations are expected to fail `Safety`. They encode the
mistakes this gate is meant to prevent before P5A0.1 is even reviewable.
