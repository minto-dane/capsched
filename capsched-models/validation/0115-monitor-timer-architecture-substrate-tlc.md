# Validation 0115: Monitor Timer Architecture Substrate TLC

Status: Safe model passed; unsafe models produced expected counterexamples;
JSON contract checked

Date: 2026-07-01

## Target

```text
analysis/0098-monitor-timer-architecture-substrate.md
analysis/monitor-timer-architecture-substrate-v1.json
formal/0076-monitor-timer-architecture-substrate-model/
```

## Purpose

Validate the N-144 architecture-substrate gate for the monitor root budget
timer.

This validation checks that CapSched cannot treat Linux timers, KVM guest
timers, KVM hrtimer fallbacks, or pKVM stage-2 memory isolation as the
non-forgeable CPU root budget authority.

## TLC Run

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/monitor-timer-architecture-substrate-20260701T214913Z
```

## Results

Safe configuration:

```text
config: MonitorTimerArchitectureSubstrateSafe.cfg
result: PASS
states_generated: 11
distinct_states: 9
states_left_on_queue: 0
depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
MonitorTimerArchitectureSubstrateUnsafeArm64KvmArchTimerRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeArm64KvmSoftHrtimerRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeArmHostHrtimerRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeDeadlineRetimedByLinux.cfg
MonitorTimerArchitectureSubstrateUnsafeExpiryStillRunning.cfg
MonitorTimerArchitectureSubstrateUnsafeKvmGuestTimerRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeKvmHrtimerFallbackRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeLinuxHrtimerRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeLinuxMintedReceipt.cfg
MonitorTimerArchitectureSubstrateUnsafeLinuxSchedTickRoot.cfg
MonitorTimerArchitectureSubstrateUnsafeNoHzControlsMonitor.cfg
MonitorTimerArchitectureSubstrateUnsafePkvmStage2AsTimer.cfg
MonitorTimerArchitectureSubstrateUnsafePkvmStage2PlusLinuxTimer.cfg
MonitorTimerArchitectureSubstrateUnsafeProtectionClaim.cfg
MonitorTimerArchitectureSubstrateUnsafeReceiptWithoutExpiry.cfg
MonitorTimerArchitectureSubstrateUnsafeRunMissingBindingTuple.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithStaleEpoch.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithUnprotectedMonitorState.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithoutMonitorTimer.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithoutRootBudget.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithoutSubstrate.cfg
MonitorTimerArchitectureSubstrateUnsafeRunWithoutToken.cfg
MonitorTimerArchitectureSubstrateUnsafeUnboundedOverrun.cfg
MonitorTimerArchitectureSubstrateUnsafeWrongArchSubstrate.cfg
```

Each unsafe configuration failed at depth 2 with:

```text
states_generated_before_violation: 2
distinct_states_before_violation: 2
states_left_on_queue: 0
```

## JSON Contract Check

Observed:

```text
source_anchors=31
substrates=9
requirements=16
forbidden_substitutions=18
unsafe_cases=24
safety_flags_false=16
safety_flags_total=16
```

## Meaning

This validation strengthens `ACT-001` and `BUDGET-001` model evidence by
requiring the root budget timer to be an architecture-matched, monitor-owned
substrate with token, epoch, MemoryView, CPU, activation generation, budget,
bounded-overrun, and monitor-receipt binding.

It rejects authority replacement from:

```text
Linux hrtimer/sched_tick/hrtick/NO_HZ/runtime accounting
KVM VMX guest timer and hrtimer fallback
arm64 KVM arch timer and soft hrtimer
pKVM stage-2 memory isolation alone
Linux/KVM/guest deadline retiming after activation
Linux-minted audit receipts
```

It is not implementation or protection evidence.

## Non-Claims

This validation does not approve Linux code, scheduler hooks, budget hooks,
task fields, public ABI, monitor ABI, x86 VMX-root implementation, arm64 EL2
implementation, KVM modification, pKVM modification, runtime coverage, monitor
verification, behavior change, or production protection.
