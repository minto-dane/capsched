# Analysis 0118: Implementation Claim Ledger Gate

Status: Design-only claim gate; no implementation approved

Date: 2026-07-02

## Purpose

Close the B4 implementation claim-ledger blocker from analysis/0113.

The gate prevents an implementation proposal from silently upgrading narrow
evidence into broader claims. It is especially important after P5, because a
test-only denial path can look like security enforcement while still lacking
runtime coverage, monitor validation, exploit-containment evidence, and
datacenter cost evidence.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Related gates:

```text
analysis/0113 implementation-ready completion audit
analysis/0116 negative denial validation plan
analysis/0117 scheduler path classification for P5
formal/0088 final deny source shape gate
formal/0089 scheduler path classification gate
assurance/claims.json
```

## Claim Ledger Row Requirement

Every future implementation proposal must carry a machine-readable claim ledger
row before patch review.

Required fields:

```text
proposal_id
slice_id
linux_base_commit
linux_work_commit_or_expected_parent
patch_scope
behavior_mode
evidence_classes_present
supported_claims
forbidden_claims
open_gaps
required_validation_before_review
required_validation_before_acceptance
upstream_drift_freshness
safety_flags
```

Missing ledger row means the implementation proposal is not reviewable.

## Evidence Classes

The ledger distinguishes evidence classes:

| Evidence Class | May Support | Must Not Support |
| --- | --- | --- |
| `model_checked` | model-supported semantics | implementation, runtime coverage, production protection |
| `linux_no_behavior_build` | build compatibility | runtime denial, runtime coverage, protection |
| `qemu_no_behavior_smoke` | no-behavior boot/workload compatibility | runtime denial, protection |
| `patch_queue_replay` | reproducibility against recorded base | semantic protection |
| `source_drift_fresh` | implementation review freshness | authority or protection |
| `negative_denial_tests` | test-only denial behavior for supported paths | full scheduler coverage |
| `runtime_trace_coverage` | runtime coverage for exactly observed paths | monitor verification or production protection |
| `monitor_validation` | monitor-backed enforcement evidence for specified roots | cost-efficiency |
| `exploit_containment_evaluation` | production protection evidence if monitor roots are present | cost-efficiency by itself |
| `cost_evaluation` | datacenter cost-efficiency evidence if protection basis exists | protection by itself |

## Current Claim Ledger State

The current project state supports:

```text
model-supported design claims for checked models
Linux no-behavior compatibility claims for P1/P2 scaffolding
patch-queue replay claims for the current private Linux delta
QEMU no-behavior smoke compatibility for P2
```

It does not support:

```text
implementation-ready completion
new Linux implementation scope
runtime denial
runtime coverage
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
public ABI
monitor ABI
```

## Claim Rules

### Implementation Approval

An implementation proposal may not claim reviewability or approval unless:

```text
claim ledger row is present
implementation scope is explicitly reopened
upstream drift freshness is recorded for the touched paths
required gate artifacts are named
safety flags are false for unsupported claims
```

### Behavior Change and Runtime Denial

A behavior-changing or runtime-denial claim requires:

```text
implementation approval gate
P5 path classification reflected
negative denial tests
trace evidence that denied candidates do not reach rq->curr/context_switch
bounded retry evidence
fail-closed evidence or explicit unavailable note
```

This supports only test-only denial evidence for the classified paths. It does
not imply all scheduler runtime coverage.

### Runtime Coverage

A runtime coverage claim requires:

```text
runtime trace coverage
exact path set stated
current/donor/proxy/server relation evidence when applicable
unsupported paths excluded from the claim
```

Model evidence, build success, QEMU smoke, or negative tests alone cannot
support runtime coverage.

### Monitor Verification

A monitor-verification claim requires monitor-backed evidence for:

```text
non-forgeable Domain epoch / token root
MemoryView or equivalent stage-2/EPT ownership
monitor root CPU budget
IOMMU / queue ownership when device claims are in scope
revoke / epoch freshness ordering
```

Linux-local SchedExecLease state is not monitor verification.

### Production Protection and Hypervisor-Grade Claim

Production protection requires:

```text
monitor verification
runtime coverage for the claimed boundary
exploit-containment evaluation
TCB boundary review
side-channel/co-tenancy policy review
explicit residual-risk ledger
```

A hypervisor-grade claim is stricter: it must name the monitor/typed endpoint
escape boundary and cannot be derived from Linux-only denial behavior.

### Cost-Efficiency Claim

Cost-efficiency requires:

```text
evaluation contract executed
benchmark methodology and workloads recorded
baseline comparison recorded
protection basis already established for the compared boundary
```

Performance data without protection evidence is only performance evidence.

## Mandatory Non-Claims for Future Patch Proposals

Every future implementation proposal must explicitly state false unless proven:

```text
runtime_denial_approved
runtime_coverage
monitor_verified
production_protection
hypervisor_grade
cost_efficiency
public_abi
monitor_abi
```

## Implementation-Ready Consequence

B4 is closed only as a design gate. It does not approve implementation. It
means future implementation reopening must include a claim-ledger row and must
fail review if any claim exceeds its evidence class.

## Non-Claims

This note does not approve Linux code, P3/P4/P5 implementation, behavior
change, runtime denial, runtime coverage, ABI, monitor ABI, monitor
implementation, monitor verification, exploit containment, production
protection, hypervisor-grade isolation, cost-efficiency, or deployment
readiness.
