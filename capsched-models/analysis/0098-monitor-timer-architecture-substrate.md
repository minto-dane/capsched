# Analysis 0098: Monitor Timer Architecture Substrate

Status: Draft architecture-substrate model gate with TLC-backed design filter;
no implementation approved

Date: 2026-07-01

## Purpose

This note refines the N-139 monitor-root budget timer from an abstract
requirement into architecture-substrate requirements.

The rule is:

```text
A root budget timer is authority only if the Monitor owns the timer,
the root budget ledger, the expiry path, and the activation binding.
```

Existing Linux and KVM timer paths are useful reference mechanisms. They are
not CapSched authority as they stand. A production HyperTag Monitor may use
similar hardware mechanisms, but it must not inherit mutable Linux/KVM guest
timer state as the root of Domain CPU enforcement.

This is a necessary boundary for the datacenter OS goal:

```text
Linux scheduler:
  cheap policy, compatibility, packing, latency, advisory preemption

HyperTag Monitor timer:
  non-forgeable final temporal authority for root Domain budget
```

The monitor timer must be narrow enough to preserve cost efficiency. It should
not trap for every Linux scheduling event. Its role is the final budget
backstop that lets Linux remain the fast policy plane without trusting Linux as
the enforcement root.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

Key x86 anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| VMX timer exit handling | `arch/x86/kvm/vmx/vmx.c:6218 handle_preemption_timer()` | reference expiry/exit shape, not CapSched authority |
| KVM LAPIC timer expiry | `arch/x86/kvm/vmx/vmx.c:6214`, `:6226` | guest LAPIC handling must not become root budget expiry |
| VMX timer programming | `arch/x86/kvm/vmx/vmx.c:7395 vmx_update_hv_timer()` | reference VMCS timer programming shape |
| VMX timer value write | `arch/x86/kvm/vmx/vmx.c:7413` | writes `VMX_PREEMPTION_TIMER_VALUE`; the field alone is not a trust boundary |
| KVM set hv timer | `arch/x86/kvm/vmx/vmx.c:8315 vmx_set_hv_timer()` | deadline conversion, range, scaling, and fallback reference |
| KVM disables preemption timer | `arch/x86/kvm/vmx/vmx.c:8735` through `:8745` | unavailable/disabled substrate must fail closed or use another monitor-owned timer |
| VMX preemption timer control | `arch/x86/include/asm/vmx.h:103` | hardware control reference |
| VMX preemption timer value field | `arch/x86/include/asm/vmx.h:356` | hardware field reference |
| KVM hv deadline field | `arch/x86/kvm/vmx/vmx.h:268` | APIC deadline in host TSC, not monitor root deadline |
| KVM soft-disabled bit | `arch/x86/kvm/vmx/vmcs.h:65` | VMCS bookkeeping, not budget state |

Key arm64 and pKVM anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| EL2 CNTVOFF write | `arch/arm64/kvm/hyp/nvhe/timer-sr.c:14` | EL2 timer/counter control reference |
| non-VHE/hVHE timer traps | `arch/arm64/kvm/hyp/nvhe/timer-sr.c:23`, `:41` | trap programming reference |
| disallow physical timer access | `arch/arm64/kvm/hyp/nvhe/timer-sr.c:46` | guest timer access control is not root budget authority |
| VHE direct timer reload | `arch/arm64/kvm/hyp/vhe/switch.c:119` through `:137` | guest timer reload around entry |
| VHE timer save/offset | `arch/arm64/kvm/hyp/vhe/switch.c:145` through `:175` | guest timer save around exit |
| hyp timer trap handler | `arch/arm64/kvm/hyp/vhe/switch.c:261` | guest timer sysreg fast path, not scheduler budget enforcement |
| KVM timer map | `arch/arm64/kvm/arch_timer.c:165` | direct/emulated vCPU timers are guest timer state |
| Linux soft hrtimer start | `arch/arm64/kvm/arch_timer.c:199`, `:502`, `:617` | fallback/wakeup aid, not root authority |
| KVM hrtimer expiry | `arch/arm64/kvm/arch_timer.c:340` | guest timer IRQ emulation path |
| timer save/restore | `arch/arm64/kvm/arch_timer.c:516`, `:627` | vCPU timer state management, not monitor budget ledger |
| vCPU timer load/put | `arch/arm64/kvm/arch_timer.c:883`, `:918` | KVM vCPU lifecycle integration |
| pKVM experimental status | `Documentation/virt/kvm/arm/pkvm.rst:7` | reference only, not complete CapSched substrate |
| pKVM host stage-2 identity map | `Documentation/virt/kvm/arm/pkvm.rst:15` through `:24` | memory ownership reference for protecting monitor state |
| pKVM CPU state isolation | `Documentation/virt/kvm/arm/pkvm.rst:72` through `:75` | currently documented as unimplemented |
| pKVM DMA isolation | `Documentation/virt/kvm/arm/pkvm.rst:77` through `:80` | currently documented as unimplemented |
| pKVM current VM pointer | `arch/arm64/kvm/hyp/nvhe/mem_protect.c:31` | hyp-owned context reference, not ambient authority |
| pKVM component lock current_vm | `arch/arm64/kvm/hyp/nvhe/mem_protect.c:47` through `:56` | context is scoped to locked stage-2 operations |
| pKVM guest stage-2 init | `arch/arm64/kvm/hyp/nvhe/mem_protect.c:272` through `:303` | memory-view construction reference |

## Required Semantics

Production CapSched-H requires an architecture substrate with all of:

```text
monitor-owned timer/deadline state
monitor-owned root budget ledger
monitor-owned expiry/trap path
architecture match: x86 VMX-root substrate for x86, EL2 substrate for arm64
sealed RunToken binding
fresh Domain epoch binding
active MemoryView binding
CPU id binding
activation generation binding
remaining root budget before activation
immutable deadline after activation except by monitor reauthorization
bounded overrun independent of Linux cooperation
NO_HZ independence
fail-closed expiry below Linux scheduler cooperation
monitor-minted audit receipt
explicit arbiter if hardware timer resources are multiplexed
```

Cluster authority should compile into node-local SchedContext/root budget
authority before this timer is armed. The monitor timer is not a distributed
global runqueue or cross-node oracle.

## Architecture Distinctions

x86 VMX:

```text
Useful:
  VMX preemption timer shows a hardware VM-exit mechanism with bounded
  TSC-derived intervals.

Forbidden:
  KVM vcpu, LAPIC deadline, hv_deadline_tsc, guest_deadline_tsc,
  hv_timer_soft_disabled, and kvm_lapic_expired_hv_timer() cannot become
  CapSched root budget state.
```

arm64 EL2:

```text
Useful:
  EL2 timer/counter/trap control shows where a monitor-owned expiry path could
  live.

Forbidden:
  KVM arch_timer_context, timer_map direct/emulated guest timers, Linux
  hrtimer fallback, VGIC timer injection, and vCPU timer save/restore cannot
  become CapSched root budget state.
```

pKVM:

```text
Useful:
  stage-2 host/hyp/pVM memory ownership is a reference for protecting monitor
  state from Linux.

Forbidden:
  stage-2 memory isolation alone is not timer expiry, CPU budget enforcement,
  CPU state isolation, or DMA isolation.
```

## Gate Rule

A future monitor-timer implementation is blocked unless:

```text
1. Running requires a monitor-owned x86 VMX-root or arm64 EL2 timer substrate.
2. The chosen substrate matches the active architecture.
3. Linux hrtimer, sched_tick, hrtick, NO_HZ, and runtime accounting are not
   root budget authority.
4. KVM guest timer machinery and hrtimer fallbacks are not root budget
   authority.
5. pKVM stage-2 memory protection may protect monitor state but cannot stand in
   for timer/budget expiry.
6. Running requires sealed token, fresh epoch, active MemoryView, CPU binding,
   activation generation, and remaining root budget.
7. Linux, KVM, or guest state cannot retime or cancel the monitor deadline
   after activation.
8. Expiry, budget exhaustion, or epoch revoke leads to fail-closed non-running
   state.
9. Audit receipts are monitor-minted and tied to expiry or revoke.
10. No implementation, ABI, monitor-verification, or production-protection
    claim is made by this model.
```

## Model

New model:

```text
formal/0076-monitor-timer-architecture-substrate-model/
```

Checked invariants:

```text
NoRunWithoutMonitorArchSubstrate
NoArchitectureAlias
NoRunWithoutMonitorOwnedTimer
NoLinuxTimerAsRoot
NoKvmGuestTimerAsRoot
NoArm64KvmTimerAsRoot
NoPkvmStage2AsTimerRoot
NoRunWithoutProtectedMonitorState
NoRunWithoutBindingTuple
NoMutableDeadlineAfterActivation
NoExpiredOrRevokedRunning
NoNoHzControlsMonitorTimer
NoUnboundedOverrun
NoLinuxMintedReceipt
NoReceiptWithoutMonitorExpiry
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
running without monitor architecture substrate
x86 execution using arm64 EL2 substrate or arm64 execution using x86 VMX-root
Linux hrtimer as root budget
Linux sched_tick/hrtick/NO_HZ as root budget
KVM VMX guest timer as root budget
KVM VMX hrtimer fallback as root budget
arm64 KVM arch_timer_context/timer_map as root budget
arm64 KVM soft hrtimer as root budget
pKVM stage-2 memory isolation as timer root
pKVM stage-2 plus Linux timer as root budget
running without monitor-owned timer arm
running without sealed RunToken
running with stale Domain epoch
running with unprotected monitor state
running without root budget
running without MemoryView, CPU id, or activation generation binding
Linux/KVM/guest retiming or canceling the monitor deadline after activation
running after expiry trap
NO_HZ controlling the monitor timer
unbounded overrun accepted
Linux-minted audit receipt
audit receipt without monitor expiry/revoke
protection claim without implementation and attack evidence
```

## Non-Claims

This note does not implement a monitor timer, choose an x86 VMX-root design,
choose an arm64 EL2 design, modify KVM or pKVM, add Linux hooks, approve a
budget hook, approve a scheduler hook, add public ABI, execute runtime
coverage, verify the monitor, change scheduler behavior, or provide production
protection evidence.
