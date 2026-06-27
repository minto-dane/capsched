# Analysis 0022: Behavior Tagging Methodology for Mechanical Design Selection

Status: Draft methodology, revised after critical review

Date: 2026-06-27

## Purpose

Before using tags to choose CapSched scheduler hooks, this note defines what
the tags mean and how they should be used.

The aim is not to decorate source paths with labels. The aim is to turn Linux
scheduler behavior into a constrained design-selection problem:

```text
source behavior
  -> typed behavior tags
  -> hard safety/compatibility constraints
  -> soft performance/cost/scalability objectives
  -> candidate hook sets
  -> formal model and validation plan
```

This is especially important because CapSched is not only a local scheduler
extension. The long-term goal is a datacenter OS substrate: a single Linux ABI
and mostly shared kernel code, split into monitor-backed Domains and eventually
composable across multiple cluster cells.

## Core Rule

Safety is not a weighted score.

```text
safety/security/compatibility hard constraints:
  pass or fail

performance/cost/scalability/multi-cluster execution:
  optimize only among candidates that pass hard constraints
```

This prevents an apparently low-overhead hook from winning while silently
missing a revocation, authority, or compatibility obligation.

Unknown values are not zero.

```text
unknown safety value:
  unsafe for enforcement

unknown performance value:
  keep as unknown until measured or bounded

unknown scalability value:
  do not use as a positive argument
```

## Tagging Layers

Use three layers.

### Behavior Path Tags

These describe what Linux is doing.

Examples:

```text
try_to_wake_up current self-wake
already-runnable wake
remote wakelist enqueue
remote pending wake activation
new task initial enqueue
queued migration
fair fast pick
core scheduling forced idle
context switch
```

Behavior path tags must be grounded in source lines and, when possible, runtime
evidence.

### Hook Candidate Tags

These describe what a future CapSched hook would do at or near that behavior.

Examples:

```text
admission_freeze
enqueue_assertion
placement_refresh
pick_validation
switch_activation
budget_charge
observation_only
```

Hook candidate tags must say whether the hook may fail, must not fail, or needs
a modeled rollback path.

### Architecture Objective Tags

These describe whether the local hook helps or hurts the larger architecture.

Examples:

```text
monitor_activation_ready
same_domain_fast_path
memory_view_switch_minimizing
cluster_lease_compilable
service_domain_compatible
root_budget_enforceable
node_local_failure_contained
```

These are what stop the design from becoming a local Linux patch that cannot
scale into the intended datacenter OS.

## Required Tag Families

### 1. Safety and Security

Safety/security tags answer:

```text
Can this behavior create, preserve, select, or activate execution authority?
Can stale authority survive revocation?
Can Linux mutable state forge the security root?
Can a confused deputy execute work with the wrong provenance?
Can this path bypass RunCap, SchedContext, DomainTag, or budget?
```

Recommended tags:

```text
authority_event:
  creates_authority
  freezes_authority
  preserves_authority
  refreshes_authority
  selects_authority
  activates_authority
  consumes_budget
  observes_only

authority_risk:
  stale_epoch
  stale_generation
  stale_cpu_mask
  stale_budget
  stale_domain_tag
  ambient_authority
  confused_deputy
  remote_pending_escape
  migration_mints_authority
  current_self_wake_bypass

security_root:
  linux_shadow_only
  monitor_required
  monitor_enforced
  policy_frontend_only
  endpoint_authority_required
```

Hard obligations:

```text
NoQueuedWithoutFrozenUse
NoPickWithoutLiveFrozenUse
MigrationDoesNotMintAuthority
SelfWakeDoesNotMintRunCap
RevocationInvalidatesPendingAndQueued
CrossDomainSwitchRequiresActivation
NoBudgetNoExecution
LinuxShadowIsNotAuthority
```

### 2. Correctness and Compatibility

Correctness/compatibility tags answer:

```text
Does this preserve Linux scheduler semantics?
Does this path hold locks or rely on memory-barrier ordering?
Does this path change state before any possible failure point?
Does this affect scheduler class contracts, sched_ext, core scheduling, or RT/DL?
```

Recommended tags:

```text
mutation_phase:
  pre_mutation
  mid_mutation
  post_mutation
  final_selection
  context_activation

failability:
  fail_capable_before_state_change
  nofail_assert_only
  must_not_fail
  failure_semantics_unknown

lock_context:
  none
  preempt_disabled
  p_pi_lock
  rq_lock
  rq_lock_irq
  raw_irq_disabled
  scheduler_class_callback
  notrace_function

compat_surface:
  generic_scheduler
  fair
  rt
  deadline
  idle
  sched_ext
  core_sched
  proxy_exec
  hotplug
  cpuset_affinity
```

Hard obligations:

```text
No sleeping under scheduler locks.
No allocation under rq locks or p->pi_lock.
No slow capability lookup in wake/pick hot paths.
CONFIG_CAPSCHED=n preserves upstream behavior.
No public ABI from observation slices.
No scheduler class contract change without a separate gate.
```

### 3. Performance

Performance must be a vector, not one score.

Recommended tags:

```text
frequency:
  wake_hot_path_frequency
  enqueue_hot_path_frequency
  pick_hot_path_frequency
  switch_hot_path_frequency
  tick_frequency
  async_completion_frequency

local_cost:
  branch_cost
  static_key_compatibility
  cacheline_touch_cost
  atomic_cost
  rcu_cost
  lock_hold_cost
  allocation_cost
  trace_or_observation_cost

system_cost:
  ipi_cost
  numa_cost
  tlb_or_memory_view_cost
  domain_switch_cost
  monitor_transition_cost
  iommu_or_queue_update_cost

performance_benefit:
  same_domain_fast_path_benefit
  batching_potential
  domain_affinity_benefit
  memory_view_switch_reduction
  direct_queue_datapath_benefit
```

This distinction matters. A hook may add a small branch on every wakeup but
save large monitor transitions by enabling Domain batching. Another hook may be
cheap locally but force frequent MemoryView switches and lose globally.

For L0, prioritize:

```text
disabled_config_zero_cost
lock_hold_cost
wake_hot_path_frequency
pick_hot_path_frequency
switch_hot_path_frequency
cacheline_touch_cost
rollback_cost
trace_or_observation_cost
```

For monitor-backed CapSched-H, additionally prioritize:

```text
domain_switch_cost
monitor_transition_cost
tlb_or_memory_view_cost
same_domain_fast_path_benefit
batching_potential
domain_affinity_benefit
memory_view_switch_reduction
```

### 4. Engineering Cost and Upstreamability

Engineering cost tags answer:

```text
How many source regions are touched?
How invasive is the type/layout change?
Does this add ABI?
Does this require refactoring scheduler contracts?
Can it be reviewed upstream as a small, understandable step?
```

Recommended tags:

```text
code_churn
hot_struct_layout_change
public_abi_change
tracepoint_abi_change
test_surface_size
rollback_complexity
review_complexity
upstream_intrusiveness
maintenance_burden
config_matrix_growth
```

Hard obligations:

```text
No task_struct authority fields before an explicit gate.
No user ABI before the object model is justified.
No monitor ABI inside Linux-only L0.
No behavior-changing scheduler hook without a model and validation plan.
```

### 5. Scalability

Scalability tags answer:

```text
Does this design scale with CPUs, tasks, domains, cgroups, queues, devices,
nodes, and revocation frequency?
```

Recommended tags:

```text
cpu_scalability:
  per_cpu_local
  cross_cpu_shared
  global_lock_pressure
  rq_local_only
  smt_core_coupled
  hotplug_sensitive

domain_scalability:
  per_domain_state_size
  per_task_state_size
  per_cpu_domain_cache
  domain_count_sensitive
  epoch_revoke_fanout
  grant_lifetime_pressure

resource_scalability:
  per_fd_endpoint_state
  per_io_request_state
  per_queue_state
  per_page_or_folio_state
  per_slab_object_state

revocation_scalability:
  local_epoch_check
  remote_pending_scan_required
  queue_drain_required
  tlb_shootdown_required
  iommu_invalidation_required
```

The worst design for CapSched is one that is locally correct but requires a
global scan or global lock on every revoke, wake, or Domain switch.

### 6. Multi-Cluster Single-OS Feasibility

This is a separate architecture vector.

The target is not a single mutable distributed kernel. It is a single OS image
and Linux ABI with capability/resource leases compiled into node-local
execution contexts.

Tags should answer:

```text
Can this behavior be represented as node-local authority compiled from a
cluster lease?
Does revocation require synchronous global consensus?
Can a node continue safe local scheduling during network partition?
Can resource ownership move between cluster cells without creating stale local
authority?
Can service Domains be placed, migrated, or replicated across nodes?
```

Recommended tags:

```text
cluster_authority:
  cluster_lease_compilable
  node_local_context_required
  cluster_shadow_not_authority
  lease_epoch_required
  remote_attestation_required

cluster_execution:
  node_local_schedcontext
  cross_node_endpoint
  service_domain_remote
  broker_budget_remote
  cluster_cell_affinity
  locality_preferred

cluster_revocation:
  local_epoch_revoke
  remote_epoch_revoke
  async_revoke_propagation
  partition_safe_degrade
  global_consensus_required
  stale_remote_lease_risk

cluster_cost:
  cross_node_rpc_cost
  lease_renewal_cost
  revocation_fanout_cost
  placement_rebalance_cost
  remote_audit_cost
```

Hard rule:

```text
No runtime CPU pick may depend on synchronous cluster consensus.
```

Cluster leases must compile into local SchedContexts, EndpointCaps, Budget
Tickets, and Memory/Queue leases ahead of the hot path. The scheduler hot path
should validate local compiled authority, not query a cluster coordinator.

## Evidence and Confidence Tags

Every tag should have evidence metadata.

Recommended evidence fields:

```text
source_line:
  exact file and line or function anchor

runtime_evidence:
  qemu run directory, tracepoint, ftrace, kprobe, count, sample

confidence:
  source_confirmed
  runtime_observed
  runtime_not_observed
  optimized_away
  config_not_enabled
  inferred
  unknown

claim_boundary:
  observation_only
  prototype_semantic
  production_security
```

This is important because an optimized-away helper is not nonexistent. It is a
source-confirmed behavior with poor no-code runtime observability.

## Mechanical Selection Process

The selection algorithm should be staged.

### Stage 1: Hard Filter

Reject any candidate set that violates:

```text
safety/security hard obligations
Linux compatibility hard obligations
lock/no-sleep/no-allocation rules
CONFIG_CAPSCHED=n preservation
```

### Stage 2: Coverage

Require coverage of all required behavior classes:

```text
queued authority
selected authority
switch activation
budget consumption
revocation of pending/queued/selected authority
migration placement refresh
self-wake exception
new-task initial authority
```

### Stage 3: Optimization

Only among hard-valid candidate sets, optimize vectors:

```text
performance
engineering cost
scalability
multi-cluster feasibility
upstreamability
observability
```

Candidate solver forms:

```text
weighted set cover:
  good first pass for coverage vs cost

MaxSAT:
  good for hard constraints, soft preferences, and forbidden combinations

ILP/MILP:
  good when vectors become numeric and weighted

Pareto frontier:
  useful when security-equivalent designs trade performance vs upstreamability

TLA+:
  validates chosen semantic candidate, not cost optimum itself
```

### Stage 4: Model Generation

The chosen tag set should generate or guide the next model:

```text
formal/0012-linux-runnable-hook-placement-model/
```

That model should include at least:

```text
path tags
hook candidates
failure semantics
revocation
migration
remote pending wake
pick/switch validation
Domain switch activation
performance-relevant same-Domain fast path as an abstract cost metric
```

## Initial Consequence for Slice 0C

The current evidence suggests:

```text
enqueue_task-only:
  insufficient for selected/running authority and self-wake semantics

pick/switch-only:
  insufficient for NoQueuedWithoutFrozenUse

pre-enqueue-only:
  dangerous without failure/rollback modeling

enqueue assertion + pick validation + switch activation:
  likely necessary as separate roles

remote pending wake:
  needs explicit revoke/epoch modeling before enforcement

multi-cluster:
  hot path must use node-local compiled authority, not cluster consensus
```

This is not an implementation decision. It is a tag-methodology result: the
next step should make these dimensions machine-readable and then choose model
variables from them.

## Decision

Adopt behavior tagging as a first-class analysis layer.

The tag ledger must represent:

```text
safety/security hard constraints
correctness/compatibility constraints
performance vectors
engineering cost vectors
scalability vectors
multi-cluster single-OS feasibility vectors
evidence/confidence metadata
```

Do not use a single scalar score to choose hooks.

Do not let performance or code cost weaken safety constraints.

Do not treat lack of trace observability as proof that a source path is
irrelevant.

## Critical Review Update

After independent review from security/formal-methods, performance,
multi-cluster, and Linux scheduler/upstream perspectives, the first draft tag
ledger is not solver-eligible.

The v1 ledger remains useful as an exploratory map only:

```text
analysis/behavior-tags/slice0c-scheduler-behavior-tags.json
```

It must not be used for:

```text
mechanical hook selection
enforcement evidence
production security evidence
```

The next required artifact is schema v2, driven by:

```text
analysis/0023-behavior-tagging-critical-review.md
analysis/behavior-tags/schema-v2-requirements.json
```

Schema v2 must make these fields mandatory before any solver use:

```text
claim_scope
enforcement_strength
trust_root
attacker_mutability
authority_event
authority_lifetime
failure_action
revocation_scope
ordering_context
lock_context
class_semantics
config_scope
cost_vector with polarity
benefit_vector with polarity
scalability_vector
cluster_vector
evidence/confidence
proof_status
```

The most important corrections are:

```text
observation is not enforcement
Linux-only L0 is not CapSched-H production evidence
Linux-mutable state is not a production trust root
cluster leases compile into node-local authority; they are not executable
costs and benefits are distinct vectors
scheduler ordering and failure actions are first-class tags
```
