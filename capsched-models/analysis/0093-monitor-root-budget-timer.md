# Analysis 0093: Monitor Root Budget Timer

Status: Draft monitor-root budget event model with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

This note defines the next budget boundary after N-136, N-137, and N-138.

The rule is:

```text
Linux timer/accounting is not the root CPU budget.
```

Linux `sched_tick`, hrtick, hrtimer, NO_HZ remote tick, class runtime, and
tracepoints can provide compatibility, early preemption, and observation. They
cannot be the final root budget source under the project threat model because a
Domain-local Linux kernel-context compromise may disable, delay, forge, or
misreport them.

Production CapSched-H needs a Monitor-owned timer/deadline event tied to:

```text
sealed RunToken
Domain epoch
active MemoryView
root Domain budget
CPU id
activation generation
```

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Key source anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| Scheduler hrtick callback | `kernel/sched/core.c:907 hrtick()` | Linux hardirq timer callback, not root budget |
| hrtick donor tick | `kernel/sched/core.c:916` | hrtick dispatches donor class tick |
| hrtick start | `kernel/sched/core.c:960 hrtick_start()` | class/requested hrtimer start |
| hrtick hrtimer arm | `kernel/sched/core.c:984` | Linux hrtimer arm, not non-forgeable root |
| task runtime read | `kernel/sched/core.c:5674 task_sched_runtime()` | read-side freshness, not enforcement |
| sched_tick | `kernel/sched/core.c:5762 sched_tick()` | Linux periodic tick surface |
| sched_tick donor | `kernel/sched/core.c:5778` and `kernel/sched/core.c:5789` | local tick uses donor class callback |
| sched_tick_remote | `kernel/sched/core.c:5849 sched_tick_remote()` | NO_HZ remote accounting surface |
| remote no-proxy assumption | `kernel/sched/core.c:5874` | remote tick warns if current/donor differ |
| schedule entry | `kernel/sched/core.c:7061 __schedule()` | activation/switch-commit region |
| hrtick schedule enter | `kernel/sched/core.c:7111` | Linux hrtick deferral during schedule |
| donor update during pick | `kernel/sched/core.c:7152` and `kernel/sched/core.c:7154` | proxy donor may change at pick |
| rq current switch commit | `kernel/sched/core.c:7201` and `kernel/sched/core.c:7234` | Linux switch commit, not monitor activation |
| generic hrtimer start | `kernel/time/hrtimer.c:1493 hrtimer_start_range_ns()` | Linux hrtimer substrate |
| hrtimer interrupt | `kernel/time/hrtimer.c:2185 hrtimer_interrupt()` | Linux hrtimer interrupt handling |
| hrtimer run queues | `kernel/time/hrtimer.c:2215` | Linux timer callback dispatch |
| NO_HZ stop tick | `kernel/time/tick-sched.c:898 tick_nohz_stop_tick()` | Linux may stop periodic tick |
| NO_HZ max stop | `kernel/time/tick-sched.c:984` | tick can be canceled/programmed to max |
| NO_HZ restart | `kernel/time/tick-sched.c:1016 tick_nohz_restart_sched_tick()` | Linux tick restart path |
| KVM VMX timer update | `arch/x86/kvm/vmx/vmx.c:7395 vmx_update_hv_timer()` | reference shape for VMX timer programming, not CapSched Monitor |
| KVM VMX timer write | `arch/x86/kvm/vmx/vmx.c:7413` | writes VMX preemption timer value |
| KVM set hv timer | `arch/x86/kvm/vmx/vmx.c:8315 vmx_set_hv_timer()` | reference deadline conversion path |
| KVM timer expiration | `arch/x86/kvm/vmx/vmx.c:6218 handle_preemption_timer()` | reference VM-exit/expiration handling |

## Required Monitor Event Semantics

A future Monitor root-budget event must provide:

```text
Monitor-owned budget counter
Monitor-owned deadline/timer state
activation-bound timer arm
sealed RunToken validation before activation
Domain epoch check before activation
CPU-local or CPU-targeted deadline
fail-closed stop/trap/revoke when deadline expires
bounded overrun independent of Linux scheduler cooperation
immutable or monitor-owned audit receipt
```

Linux may still provide:

```text
early budget warning
class-local preemption
compatibility runtime accounting
trace-only coverage
performance measurement
```

## Gate Rule

A future CapSched budget implementation is blocked unless:

```text
Domain execution is activated only after the Monitor arms a root-budget timer.
Running requires a live monitor timer and remaining monitor root budget.
Linux hrtick/sched_tick/hrtimer/NO_HZ state is never root authority.
Linux runtime charge reports cannot replace monitor budget depletion.
NO_HZ tick stopping cannot stop or defer the monitor root timer.
Epoch revoke or timer expiry terminates the active run use fail-closed.
Protection claims remain forbidden until a real Monitor implementation and
attack evaluation exist.
```

## Model

New model:

```text
formal/0071-monitor-root-budget-timer-model/
```

Checked invariants:

```text
NoRunWithoutMonitorTimer
NoRunWithoutRootBudget
NoLinuxTimerAsRootAuthority
NoOverrunAfterExpiry
NoLinuxChargeAsMonitorCharge
NoActivationWithoutSealedToken
NoEpochRevokedRunning
NoRunAfterMonitorInterrupt
NoNoHzStopsMonitorTimer
NoProtectionClaim
NoFailClosedAccepted
```

## Hard Rejections

Reject:

```text
hrtick as root budget
sched_tick as root budget
task_sched_runtime as enforcement
Linux hrtimer as non-forgeable budget root
NO_HZ remote tick as proof of budget enforcement
Linux runtime charge report as monitor budget depletion
activation before monitor timer arm
run after monitor timer expiry
run after Domain epoch revoke
protection claim without monitor implementation
```

## Non-Claims

This note does not implement a monitor timer, add Linux hooks, approve a budget
hook, approve a scheduler hook, add ABI, execute runtime tests, verify
production protection, or select an x86/arm64 monitor implementation.
