# Validation 0116: Placement, Affinity, and Hotplug Integration Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0099-placement-affinity-hotplug-integration-gate.md
analysis/placement-affinity-hotplug-integration-gate-v1.json
formal/0077-placement-affinity-hotplug-integration-gate-model/
```

## Purpose

Validate the N-145 gate for Linux placement, affinity, cpuset, hotplug,
scheduler-class selection, sched_ext, core scheduling, and Linux exception
integration.

This validation checks that ordinary Domain execution requires grant
provenance plus a fresh frozen CPU set derived from:

```text
capEnvelope ∩ linuxMask ∩ activeMask ∩ monitorCpuSet ∩ memoryViewCpuSet
```

and that Linux placement/fallback mechanisms cannot mint, refresh, or widen
CapSched authority.

## Critical Review Incorporated

The first draft was rejected during subagent review. It used booleans for CPU
membership, created run authority in the same action as placement freeze,
treated running as terminal, and let refresh repair placement by fiat.

The checked model fixes those weaknesses by using finite CPU sets, explicit
grant provenance, a derived frozenAllowed intersection, invalidation from
`Running`, fail-closed empty-intersection behavior, and an ordinary
Domain-versus-Linux-exception split.

## TLC Runs

Safe run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-affinity-hotplug-integration-gate-20260701T221444Z
```

Unsafe run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/placement-affinity-hotplug-integration-gate-unsafe-20260701T221509Z
```

## Results

Safe configuration:

```text
config: PlacementAffinityHotplugIntegrationGateSafe.cfg
result: PASS
states_generated: 81
distinct_states: 39
states_left_on_queue: 0
depth: 7
```

Unsafe configurations produced expected counterexamples:

```text
PlacementAffinityHotplugIntegrationGateUnsafeClassSelectionAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeCoreStealAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeCpusetFallbackAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeFallbackExpansionAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeForceAffinityAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeMigrateDisableAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeNoIntersectionRuns.cfg
PlacementAffinityHotplugIntegrationGateUnsafePerCpuKthreadAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafePlacementMintedAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeProtectionClaim.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunInactiveCpu.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunOutsideLinuxMask.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunWhileMigrationPending.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunWithStalePlacement.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunWithoutFrozenPlacement.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunWithoutMemoryViewBinding.cfg
PlacementAffinityHotplugIntegrationGateUnsafeRunWithoutMonitorCpuBinding.cfg
PlacementAffinityHotplugIntegrationGateUnsafeSchedExecAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeScxSelectionAuthority.cfg
PlacementAffinityHotplugIntegrationGateUnsafeSelectedCpuAuthority.cfg
```

Summary:

```text
expected_fails: 20
unexpected_passes: 0
other_failures: 0
```

## JSON Contract Check

Observed:

```text
source_anchors=41
subjects=15
execution_requirements=16
invalidation_sources=8
forbidden_substitutions=20
unsafe_cases=20
safety_flags_false=15
safety_flags_total=15
```

## Meaning

This validation strengthens `ACT-001`, `EXEC-001`, and `COMPAT-001` model
evidence by requiring placement and execution to compose Linux masks, active
CPU policy, monitor CPU binding, and MemoryView CPU binding without letting
Linux placement mechanisms become authority roots.

It rejects authority replacement from:

```text
selected_cpu
class select_task_rq
sched_ext selected_cpu or DSQ dispatch
core scheduling pick/steal
sched_exec placement
cpuset fallback
force affinity
fallback rq
migrate_disable
per-cpu kthread exception
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, task fields, scheduler hooks,
budget hooks, public ABI, monitor ABI, runtime coverage, monitor
implementation, monitor verification, behavior change, or production
protection.
