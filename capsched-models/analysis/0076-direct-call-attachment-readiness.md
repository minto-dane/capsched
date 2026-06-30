# Analysis 0076: Direct-Call Attachment Readiness Map

Status: Draft no-code attachment/readiness map with model gate

Date: 2026-06-30

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
current commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

Current Linux CapSched anchors:

```text
include/linux/capsched.h
kernel/sched/capsched.c
kernel/sched/Makefile
```

Related artifacts:

```text
analysis/0074-direct-call-carrier-requirements.md
analysis/0075-direct-call-schema-compatibility.md
analysis/direct-call-attachment-readiness-v1.json
implementation/0008-direct-call-attachment-readiness-gate.md
formal/0053-direct-call-attachment-readiness-model/
validation/0075-direct-call-attachment-readiness-tlc.md
```

## Purpose

N-103 maps the no-code Linux/monitor attachment and readiness boundary for the
schema-compatible direct-call carrier.

This is still not a Linux stub, monitor implementation, binary ABI layout,
syscall, VM-call, SMC/HVC mechanism, public tracepoint ABI, user ABI, or
production protection claim.

The safe claim is:

```text
We know which Linux-side and monitor-side attachment rows must exist before a
direct-call carrier can be implemented, and every row remains observation-only
or inert until a real monitor-backed implementation is separately approved.
```

The forbidden claim is:

```text
The direct-call carrier is implemented or provides authority.
```

## Current Source Facts

The current Linux branch has only type-only/inert scaffolding:

```text
include/linux/capsched.h:
  opaque type names and comments
  no object layouts
  no lifetime rules
  no validation
  no revocation
  no monitor ABI

kernel/sched/capsched.c:
  inert translation unit
  no scheduler hook
  no endpoint hook
  no monitor activation
  no task layout change
  no user ABI

kernel/sched/Makefile:
  obj-$(CONFIG_CAPSCHED) += capsched.o
```

N-103 must not convert any of these into behavior-changing authority.

## Candidate Linux Attachment Rows

Rows are candidates for later no-code observation or inert stubs. They are not
approved patch points.

```text
capsched_type_namespace:
  current anchor:
    include/linux/capsched.h
  allowed readiness:
    opaque ids, enums, forward declarations, comments
  forbidden shortcut:
    values derived from Linux mutable state treated as monitor receipts

capsched_internal_translation_unit:
  current anchor:
    kernel/sched/capsched.c
  allowed readiness:
    compile-only helper shapes returning not-implemented without caller effect
  forbidden shortcut:
    helper return value changes scheduler, device, or endpoint behavior

capsched_build_gate:
  current anchor:
    kernel/sched/Makefile
  allowed readiness:
    CONFIG_CAPSCHED-gated build visibility only
  forbidden shortcut:
    CONFIG_CAPSCHED changes behavior without a separate gate

request_envelope_builder:
  candidate anchor:
    future internal helper, not user ABI
  allowed readiness:
    construct synthetic/request-shape rows for analysis
  forbidden shortcut:
    Linux-built envelope treated as canonical monitor request image

direct_call_entry_shape:
  candidate anchor:
    future arch-independent wrapper plus arch-specific backend
  allowed readiness:
    no-code signature sketch and failure taxonomy
  forbidden shortcut:
    wrapper success means monitor approval

schema_negotiation_probe:
  candidate anchor:
    future internal query path
  allowed readiness:
    trace or dry-run rows for schema id and feature-set coverage
  forbidden shortcut:
    Linux decides schema acceptance

response_handle_shadow_refresh:
  candidate anchor:
    future internal query/cache path
  allowed readiness:
    observe whether a monitor-backed handle would be required
  forbidden shortcut:
    Linux-visible shadow refresh from return code or timeout

control_revoke_lane:
  candidate anchor:
    future internal control path
  allowed readiness:
    name query/revoke/cancel/supersede needs
  forbidden shortcut:
    priority control path bypasses replay, budget, or epoch checks

failure_injection_surface:
  candidate anchor:
    future test-only fault injection or KUnit-style seam
  allowed readiness:
    inject unsupported schema, stale epoch, replay, timeout, and malformed
    request outcomes in non-production tests
  forbidden shortcut:
    fault injection changes live scheduler/device decisions

trace_only_observation_surface:
  candidate anchor:
    existing ftrace/kprobe/tracefs where possible
  allowed readiness:
    observe call shape without adding public ABI
  forbidden shortcut:
    new public tracepoint ABI or trace observation treated as authority
```

## Monitor-Side Boundary Responsibilities

The monitor side, not Linux, must eventually own:

```text
bounded request copy/freeze
schema acceptance
canonical digest
shared replay consume
receipt ledger write
response handle minting
shared shadow generation
terminal failure recording
timeout/query resolution
revoke state
ring-compatible carrier-neutral namespaces
```

In N-103 these are readiness rows only. There is no monitor implementation.

## Required Readiness Row Fields

Any N-103-derived machine-readable row must include:

```text
row_id
row_class
linux_anchor
monitor_responsibility
observation_surface
stub_shape
failure_injection_surface
schema_reference
ledger_reference
shadow_reference
ring_compatibility_requirement
observation_only
authority_claim
monitor_verified
behavior_change
user_abi
public_tracepoint_abi
protection_claim
forbidden_shortcut
validation_hook
```

The required safety flags are:

```text
observation_only=true
authority_claim=false
monitor_verified=false
behavior_change=false
user_abi=false
public_tracepoint_abi=false
protection_claim=false
```

Rows missing any flag cannot justify a Linux patch.

## Allowed Readiness Work

Allowed after this gate, with separate review:

```text
no-code trace runner using existing tracing
source-anchor inventory
machine-readable readiness ledger
inert type-only declarations
compile-only internal helper shapes returning not-implemented
test-only failure-injection plan with no production behavior effect
KUnit-style semantic tests once stubs exist
```

## Forbidden Patch Effects

No N-103-derived work may:

```text
change scheduler behavior
change device, DMA, IRQ, endpoint, cgroup, namespace, or LSM decisions
create user ABI
create public tracepoint ABI without a separate gate
embed authority fields in hot objects
validate requests from Linux mutable memory
mint response handles in Linux
write monitor ledger state in Linux
refresh shadow state from timeout or return code
claim monitor verification
claim production protection
expose raw monitor, PF/VF, IOMMU, MSI, devlink, task, fd, or scheduler handles
```

## Failure Injection Readiness

The readiness map must preserve named failure classes for later tests:

```text
unsupported_schema
monitor_minimum_downgrade
caller_minimum_downgrade
missing_mandatory_field
unknown_critical_optional
same_nonce_digest_mismatch
replay_rejected
stale_monitor_epoch
stale_local_lease_epoch
policy_denied
budget_denied
linux_timeout_observed
transport_unavailable
response_without_ledger
shadow_without_shared_generation
unknown_success_code
direct_only_namespace
```

These may be test outcomes. They are not runtime authority.

## Acceptance Checks

This readiness map is acceptable only if:

```text
every required row is present
every row has all required safety flags
no row claims authority or monitor verification
no row changes behavior
no row creates user ABI or public tracepoint ABI
no stub return value can authorize a caller
no observation surface is authority
no failure injection changes production behavior
no raw handle is exposed to Domains
ring compatibility remains listed for schema, replay, ledger, shadow, and error namespaces
```

## Non-Goals

This note does not select:

```text
binary ABI layout
numeric schema ids
syscall or monitor-call mechanism
arch backend
Linux source file for a future stub
monitor source tree
public tracepoint ABI
user ABI
Kconfig prompt
runtime policy
performance budget
production protection claim
```

## Consequence

Passing this gate means it is reasonable to design a no-code trace runner,
source-anchor inventory, or inert compile-only stub proposal for direct-call
carrier readiness.

It does not mean direct-call admission exists, Linux can mint receipts, a
monitor verifies anything, or CapSched-H provides protection.
