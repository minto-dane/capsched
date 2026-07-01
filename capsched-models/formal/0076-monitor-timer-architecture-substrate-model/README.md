# Monitor Timer Architecture Substrate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model refines the monitor-root budget timer into architecture-substrate
requirements.

It checks that running requires:

```text
monitor-owned x86 VMX-root or arm64 EL2 timer substrate
matching architecture
monitor-owned timer/deadline state
protected monitor state
sealed RunToken
fresh Domain epoch
active MemoryView
CPU binding
activation generation binding
remaining root budget
bounded overrun
```

It rejects Linux/KVM/pKVM substitutions that are mechanically similar but do
not provide CapSched authority.

## Files

```text
MonitorTimerArchitectureSubstrate.tla
MonitorTimerArchitectureSubstrateSafe.cfg
MonitorTimerArchitectureSubstrateUnsafe*.cfg
```

## Safe Path

The safe path is intentionally small:

```text
ChooseX86VmxMonitorSubstrate or ChooseArm64El2MonitorSubstrate
  -> ActivateMonitorRootTimer
  -> RunWithMonitorRoot
  -> ExpireFailClosed
```

## Rejected Substitutions

Unsafe configs reject:

```text
Linux hrtimer
Linux sched_tick/hrtick
KVM VMX guest timer
KVM VMX hrtimer fallback
arm64 KVM arch timer
arm64 KVM soft hrtimer
pKVM stage-2 memory isolation as timer
pKVM stage-2 plus Linux timer
missing token/epoch/MemoryView/CPU/generation/budget binding
Linux/KVM/guest retiming the monitor deadline
NO_HZ controlling monitor time
Linux-minted audit receipt
protection overclaim
```

## Run

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config MonitorTimerArchitectureSubstrateSafe.cfg \
  MonitorTimerArchitectureSubstrate.tla
```

Use a distinct `-metadir` for bulk unsafe runs to avoid TLC state-directory
collisions.

## Non-Claims

This model does not implement a monitor timer, choose an x86 VMX-root design,
choose an arm64 EL2 design, modify KVM or pKVM, add Linux hooks, approve an
ABI, prove runtime coverage, verify the monitor, change behavior, or provide
production protection evidence.
