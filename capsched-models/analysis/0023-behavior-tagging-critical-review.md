# Analysis 0023: Critical Review of Behavior Tagging Before Schema Finalization

Status: Review complete, schema v2 required

Date: 2026-06-27

## Purpose

This note records the pre-tagging critical review requested before using
behavior tags for mechanical hook selection.

The review used four independent perspectives:

```text
security / formal methods / hostile threat model
performance / scalability / cost modeling
multi-cluster single-OS feasibility
Linux scheduler implementation / compatibility / upstreamability
```

No reviewer approved using the current draft tag ledger as a solver input.

## Overall Result

Behavior tagging is a good direction, but the current draft schema is not yet
safe for mechanical optimization.

The main reason is that a solver could confuse:

```text
observation coverage
Linux-only prototype behavior
monitor-backed production enforcement
performance benefit
security obligation coverage
```

These must be distinct typed fields before any automated selection.

## Security Review Findings

### Observation Is Not Enforcement

`observation_only` must never satisfy a security hard obligation.

The schema must separate:

```text
observation_only
debug_assert
default_permissive
fail_closed_linux
fail_closed_monitor
hardware_enforced
```

Without this separation, a solver could choose cheap traceable hooks and report
false security coverage.

### Claim Scope Must Be Mandatory

Every tag record and hook candidate must declare scope:

```text
l0_observation
l0_linux_enforcement
caph_monitor_enforced
caph_hardware_enforced
```

Linux-only L0 evidence must not satisfy monitor-backed production claims.

### Trust Root And Attacker Mutability Must Be Explicit

The hostile model allows arbitrary Domain-local Linux kernel-context execution.
Therefore any Linux-mutable state is not a production authority root.

Schema v2 must include:

```text
trust_root:
  linux_mutable_shadow
  monitor_sealed_token
  monitor_epoch
  hardware_memory_view
  iommu_irq_root
  service_endpoint

attacker_mutability:
  writable_by_domain_kernel_compromise
  linux_global_mutable
  monitor_only
  hardware_only
```

### Failure Action Must Be Modeled

`failure_semantics_unknown` cannot be a placeholder in an enforcement candidate.

Required failure actions:

```text
not_modeled_invalid
reject_before_mutation
dequeue_quarantine
select_idle
force_resched
monitor_fail_closed
panic_or_isolate_cpu
```

Late pick/switch failures are especially dangerous and cannot be hand-waved.

### Revocation Scope Is Too Shallow

Production claims need revocation tags for:

```text
active
selected
queued
delayed
remote_pending
async
cached
service_ticket
device_queue
tlb
iommu
memory_view
```

Lazy revocation must say where it is guaranteed to stop:

```text
before enqueue
before pick
before switch
before monitor activation
before endpoint/device submission
```

### Co-Tenancy And Side Channels Are Security-Relevant

Core scheduling and co-tenancy are not only performance details.

Required tags:

```text
co_tenancy_policy:
  smt_forbidden
  core_cookie_required
  llc_partition_required
  numa_memory_policy
  device_queue_cotenancy
  side_channel_not_claimed
```

## Performance Review Findings

### One Performance Vector Is Unsafe

The draft vector mixes:

```text
frequency
local cost
system cost
benefit
implementation strategy
```

Some values are bad when high, while others are good when high. A solver cannot
consume this safely.

Schema v2 must split:

```text
event_frequency
local_cost_vector
system_cost_vector
benefit_vector
implementation_strategy
measurement_evidence
```

Every numeric dimension must carry:

```text
direction: minimize | maximize | informational
unit
unknown_policy
measurement_source
```

### Frequency And Cost Must Not Be Added Directly

The right cost shape is:

```text
total_cost(path, hook)
  = event_rate(path)
  * enabled_probability(hook)
  * per_event_cost(hook, path)
  + amortized_system_cost
```

For monitor-backed CapSched-H:

```text
system_cost
  = cross_domain_switch_rate * monitor_transition_cost
  + memory_view_switch_rate * tlb_cost
  + revoke_rate * invalidation_fanout_cost
  + service_ipc_rate * ipc_cost
```

### Minimum Performance Dimensions

Schema v2 should include:

```text
per_call_cycles_estimate
hot_path_event_rate
cacheline_read_set
cacheline_write_set
false_sharing_risk
rq_lock_extension_ns
pi_lock_extension_ns
static_branch_state
layout_cost
branch_predictability
monitor_transition_rate
domain_switch_ratio
same_domain_run_length
remote_wake_ratio
migration_rate
revocation_rate
ipi_rate_delta
tlb_flush_rate_delta
numa_remote_state_access
service_domain_ipc_rate
queue_lease_rebind_rate
```

### Use Pareto First, Scenario Weights Later

Do not collapse to one score early.

Use:

```text
hard safety filter
coverage filter
Pareto frontier
scenario-specific weighting
```

Scenarios include:

```text
cloud multi-tenant
latency-sensitive service
storage node
GPU node
HPC/batch
edge/partition-prone cluster cell
```

## Multi-Cluster Review Findings

### Cluster Lease Is Not Executable Authority

This must be a hard rule:

```text
No raw cluster lease may be used as scheduler hot-path authority.
```

Cluster leases are compile inputs only. Hot paths may validate only node-local
compiled authority sealed by the local monitor or trusted compiler path.

Required hard constraints:

```text
NoClusterConsensusInWakePickSwitch
NoRemoteRPCInSchedulerHotPath
NoRawClusterLeaseAsExecutableAuthority
OnlyLocalCompiledAuthorityMayRun
PartitionCannotMintAuthority
RemoteRevocationIsNotInstantUnlessLocallySealed
```

### Local Compiled Authority Must Be Central

Required tags:

```text
authority_locality:
  monitor_sealed_local
  linux_shadow_only
  cluster_shadow_only
  service_brokered
  remote_untrusted_hint

cluster_lease_role:
  non_executable_policy_token
  compile_input_only
  local_schedcontext_output
  local_endpointcap_output
  local_queuelease_output
  local_memoryview_output

lease_compile_site:
  admission_control_plane
  node_local_compiler
  monitor_seal
  scheduler_hot_path_forbidden
```

### Partition Behavior Needs First-Class Tags

Partition is not just delayed revocation.

Required tags:

```text
partition_mode:
  healthy
  control_plane_unreachable
  remote_service_unreachable
  split_brain_suspected
  node_quarantined

partition_semantics:
  continue_existing_local_budget
  deny_new_remote_authority
  deny_remote_endpoint_use
  expire_without_renewal
  fail_closed_on_epoch_uncertainty
  audit_buffer_locally
```

During partition, existing monitor-sealed local budget may continue until its
local expiry. New cross-cell authority must not be minted.

### Hot Path Distributed Operations Must Be Forbidden

Forbidden in wake/pick/switch hot paths:

```text
synchronous cluster consensus
remote coordinator RPC
lease signature verification
lease renewal
distributed lock acquisition
global runqueue or global task scan
remote service discovery
blocking audit flush
filesystem or network I/O
sleeping allocation
large capability-table lookup
IOMMU remap
MemoryView construction
page ownership transfer
BPF/policy program compilation
cross-node migration negotiation
```

## Linux Scheduler Review Findings

### Ordering And Barriers Need Tags

`try_to_wake_up()` relies on strict ordering of:

```text
p->__state
p->on_rq
p->on_cpu
task_cpu(p)
rq->curr
```

Schema v2 needs ordering tags:

```text
state_checked_before_on_rq
on_cpu_acquire_required
finish_task_release_pair
rq_curr_rcu_publish
membarrier_sensitive
control_dependency_required
smp_mb_after_spinlock_required
```

### Lock Context Needs More Precision

Current `rq_lock` style tags are too coarse.

Required tags:

```text
rq_lock
rq_lock_irq
p_pi_lock
double_rq_lock
preempt_disabled
raw_irq_disabled
rq_pinned
lock_dropped_reacquired
may_sleep
may_allocate
scheduler_class_callback_lock_contract
```

### Scheduler Class And Config Semantics Need First-Class Tags

`CONFIG_*` is not enough. The behavior differs by class and feature.

Required tags:

```text
class_semantics:
  fair
  rt_throttling
  rt_pushable
  deadline_cbs
  deadline_replenish
  deadline_server
  idle
  stop_class
  sched_ext_dsq
  sched_ext_direct_dispatch
  sched_ext_bypass
  sched_ext_fallback

config_scope:
  SMP
  UP
  PREEMPT_DYNAMIC
  PREEMPT_RT
  SCHED_CORE
  SCHED_CLASS_EXT
  SCHED_PROXY_EXEC
  CPUSETS
  HOTPLUG_CPU
  FAIR_GROUP_SCHED
  CFS_BANDWIDTH
  RT_GROUP_SCHED
  UCLAMP
```

### Failability Traps Must Be Explicit

Bad tags to prevent:

```text
enqueue_task as fail-capable
TASK_WAKING write followed by rejection
pick validation that mutates class state and then retries unsafely
switch activation failure without modeled idle/panic/isolate behavior
```

Required tag:

```text
failability_after_mutation:
  no_mutation_yet
  state_written
  class_state_mutated
  rq_curr_mutated
  context_switch_committed
  rollback_not_available
```

## Schema v2 Mandatory Fields

Every behavior path and hook candidate should have:

```text
claim_scope
enforcement_strength
trust_root
attacker_mutability
authority_event
authority_lifetime
failure_action
revocation_scope
bypass_surface
ordering_context
lock_context
class_semantics
config_scope
cost_vector
benefit_vector
scalability_vector
cluster_vector
evidence
proof_status
```

## Solver Eligibility Rules

Do not use an entry for security hook selection unless:

```text
claim_scope is explicit
enforcement_strength is not observation_only
trust_root is not linux_mutable_shadow for production claims
attacker_mutability is compatible with the claim
failure_action is modeled
revocation_scope is explicit
unknown safety fields are absent
ordering_context is known or conservatively modeled
cost and benefit vectors have polarity metadata
```

## Decision

Adopt tagging, but do not finalize the current schema.

Create schema v2 before tag-driven hook selection.

The current draft JSON may remain as an exploratory ledger only if it is marked:

```text
not solver eligible
not enforcement evidence
not production security evidence
```

Next work should produce a schema v2 requirements document or JSON schema, then
retag Slice 0C behavior under that stricter shape.
