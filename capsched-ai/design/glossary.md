# Glossary

Updated: 2026-06-25

`CapSched-Linux`
: Domain-aware Linux scheduler/kernel architecture with capability-oriented
  execution and resource authority.

`CapSched-H`
: Monitor-backed production architecture for non-forgeable Domain isolation.

`Domain`
: Schedulable protection/resource/audit context. It may be as small as a process
  or as large as a container, tenant, service, or cluster cell.

`DomainTag`
: Active protection context selected on context switch.

`RunCap`
: Authority to enqueue or re-enqueue a specific thread/task. It should only mean
  runnable submission authority.

`SchedContext`
: CPU-time resource object with budget, period, remaining time, placement, and
  co-tenancy constraints.

`FrozenRunUse`
: Enqueue-time frozen execution lease derived from RunCap and SchedContext.

`SchedControlCap`
: Authority to change scheduling parameters such as budget, period, priority,
  affinity, and co-tenancy constraints.

`ThreadControlCap`
: Authority to suspend, resume, terminate, join, or inspect a thread.

`SpawnCap`
: Authority to create thread/process/domain with bounded inherited authority.

`BudgetTicket`
: Bounded time/operation budget passed to broker or service execution.

`Endpoint`
: Resource boundary that checks resource-specific capabilities.

`HyperTag Monitor`
: Small lower layer enforcing roots Linux must not forge.

`MemoryView`
: Domain-specific physical/second-stage memory view enforced by the monitor in
  production.

