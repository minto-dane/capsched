# Analysis 0077: Direct-Call Trace/Source Inventory Contract

Status: Draft no-code inventory contract with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0076-direct-call-attachment-readiness.md
analysis/direct-call-attachment-readiness-v1.json
analysis/direct-call-trace-source-inventory-contract-v1.json
implementation/0008-direct-call-attachment-readiness-gate.md
formal/0054-direct-call-inventory-contract-model/
validation/0076-direct-call-inventory-contract-tlc.md
```

## Purpose

N-104 defines the contract for a future direct-call trace/source inventory
runner. It does not implement the runner and does not patch Linux.

The contract answers:

```text
Which current Linux source anchors, existing trace surfaces, and future
candidate gaps correspond to the N-103 direct-call attachment rows?
```

It must not answer:

```text
Does direct-call admission exist?
Did a monitor verify anything?
Does a Linux timeout mean a monitor decision?
Does a source anchor provide authority?
Is any production protection present?
```

## Runner Class Split

N-104 separates two future runner classes.

### Source-only inventory

This is the default and does not require privilege.

Allowed inputs:

```text
local Linux source tree
git metadata
read-only source search
existing source files
existing trace event declarations in source
optional local build metadata if already present
N-103 attachment-readiness rows
```

Forbidden inputs or effects:

```text
Linux source modification
kernel build
module loading
tracefs writes
BPF attachment
kprobe/fprobe attachment
QEMU execution
runtime workload execution
root requirement
public tracepoint creation
```

### Optional tracefs plan

This is a plan artifact only. It may name existing trace events or dynamic
probe candidates for a later privileged validation, but it does not execute
them.

Allowed meaning:

```text
The inventory found an existing trace surface or symbol candidate that a future
operator-approved run might observe.
```

Forbidden meaning:

```text
Tracefs was executed, a public tracepoint ABI was created, or the trace
surface provides authority.
```

## Output Contract

A future runner should emit:

```text
inventory-ledger.tsv
inventory-ledger.json
tracefs-plan.txt
semantic-gaps.tsv
summary.txt
```

`inventory-ledger.tsv` and `.json` rows must contain:

```text
row_id
source_row_ref
row_class
inventory_class
linux_anchor
anchor_kind
anchor_available
anchor_confidence
source_path
symbol_or_pattern
trace_event
dynamic_probe_candidate
requires_privilege
runtime_observation_required
observed_now
missing_reason
gap_severity
observation_only
authority_claim
monitor_verified
behavior_change
user_abi
public_tracepoint_abi
protection_claim
forbidden_upgrade
next_step
```

Required safety flags:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
user_abi=false
public_tracepoint_abi=false
protection_claim=false
```

Required default runtime fields for source-only inventory:

```text
requires_privilege=false
runtime_observation_required=false
observed_now=false
```

## Seed Inventory Rows

The first inventory contract contains ten seed rows, one per N-103 attachment
class.

```text
direct-call-inventory-001:
  source_row_ref: direct-call-attach-001
  row_class: capsched_type_namespace
  linux_anchor: include/linux/capsched.h
  anchor_kind: current_source_file
  anchor_available: true
  forbidden_upgrade: capsched opaque ids are not monitor receipts

direct-call-inventory-002:
  source_row_ref: direct-call-attach-002
  row_class: capsched_internal_translation_unit
  linux_anchor: kernel/sched/capsched.c
  anchor_kind: current_source_file
  anchor_available: true
  forbidden_upgrade: inert translation unit is not direct-call authority

direct-call-inventory-003:
  source_row_ref: direct-call-attach-003
  row_class: capsched_build_gate
  linux_anchor: kernel/sched/Makefile
  anchor_kind: current_source_file
  anchor_available: true
  forbidden_upgrade: build visibility is not behavior approval

direct-call-inventory-004:
  source_row_ref: direct-call-attach-004
  row_class: request_envelope_builder
  linux_anchor: future_internal_helper_not_user_abi
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: Linux-built envelope is not canonical monitor image

direct-call-inventory-005:
  source_row_ref: direct-call-attach-005
  row_class: direct_call_entry_shape
  linux_anchor: future_arch_independent_wrapper_plus_arch_backend
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: wrapper return is not monitor approval

direct-call-inventory-006:
  source_row_ref: direct-call-attach-006
  row_class: schema_negotiation_probe
  linux_anchor: future_internal_query_path
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: Linux cannot decide schema acceptance

direct-call-inventory-007:
  source_row_ref: direct-call-attach-007
  row_class: response_handle_shadow_refresh
  linux_anchor: future_internal_query_cache_path
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: timeout or return code cannot refresh shadow authority

direct-call-inventory-008:
  source_row_ref: direct-call-attach-008
  row_class: control_revoke_lane
  linux_anchor: future_internal_control_path
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: control priority cannot bypass replay/budget/epoch checks

direct-call-inventory-009:
  source_row_ref: direct-call-attach-009
  row_class: failure_injection_surface
  linux_anchor: future_test_only_fault_injection_or_kunit_style_surface
  anchor_kind: future_gap
  anchor_available: false
  forbidden_upgrade: fault injection cannot change live decisions

direct-call-inventory-010:
  source_row_ref: direct-call-attach-010
  row_class: trace_only_observation_surface
  linux_anchor: existing_ftrace_kprobe_tracefs_where_possible
  anchor_kind: existing_trace_catalog_plan
  anchor_available: partial_plan_only
  forbidden_upgrade: trace observation or new tracepoint ABI is not authority
```

## Semantic Gap Rules

Missing future anchors are expected. They must become gap rows, not authority
or negative proof.

```text
missing request_envelope_builder:
  gap, not proof that no direct-call design is needed

missing direct_call_entry_shape:
  gap, not permission to use syscall return values as monitor approval

missing schema_negotiation_probe:
  gap, not permission for Linux to accept schemas

missing response_handle_shadow_refresh:
  gap, not permission to refresh shadows from timeout or return code

missing control_revoke_lane:
  gap, not permission to bypass replay, budget, or epoch checks

missing failure_injection_surface:
  gap, not permission to test through production behavior
```

## Validation Plan

The future source-only runner should pass only if:

```text
it does not modify the Linux source tree
it does not require root
it does not write tracefs
it emits all required output files
it emits all required fields
it preserves required safety flags
it marks current anchors as source observations only
it marks future anchors as gaps
it treats tracefs entries as future-plan suggestions only
it emits zero authority/protection/monitor-verification claims
```

The optional later tracefs run requires a separate validation record and
operator privilege. It must still preserve:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
user_abi=false
public_tracepoint_abi=false
protection_claim=false
```

## Stop Conditions

Stop and do not accept an inventory result if it:

```text
modifies Linux
requires root for source-only mode
writes tracefs in source-only mode
creates or proposes a new public tracepoint ABI as part of the run
loads BPF or attaches probes
uses runtime success/failure as authority
treats a missing anchor as proof the semantic obligation is unnecessary
reports monitor verification
reports production protection
exposes raw monitor, task, fd, scheduler, IOMMU, MSI, PF, VF, or devlink handles
```

## Non-Goals

N-104 does not:

```text
implement the runner
execute tracefs
run QEMU
patch Linux
choose direct-call C struct layout
choose syscall, VM-call, SMC, or HVC mechanism
create public tracepoint ABI
create user ABI
create monitor implementation
claim protection
```
