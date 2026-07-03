# Analysis 0141: SchedExecLease P5A-R Negative Validation Plan

Date: 2026-07-03

Status: design/formal validation-plan gate. No Linux behavior patch is approved.

## Purpose

P5A-R needs negative validation before any behavior patch can be considered
implementation-ready. The goal is not to show that happy-path scheduling works.
The goal is to make unsafe designs fail loudly.

This plan supersedes the older broad P5 negative plan for the narrowed
ordinary-CFS-only P5A-R slice.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
prior_gates:
  validation/0163 P5A-R picker ineligibility
  validation/0164 P5A-R EEVDF return dominance
  validation/0165 P5A-R group hierarchy settlement
  validation/0166 P5A-R cross-path exclusion/settlement
  validation/0167 P5A-R overhead/layout
```

## Required Negative Test Families

```text
ND-P5AR-001 post-settlement denial:
  denial after put_prev_set_next_task(), set_next_task_fair(), set_next_entity(),
  rq->curr publication, or sched_switch must fail unless rollback proof exists.

ND-P5AR-002 denied reaches execution:
  a denied task/generation must not reach rq->curr or sched_switch.

ND-P5AR-003 same candidate repick:
  the same task/generation must not be selected again in the same attempt.

ND-P5AR-004 retry without picker-visible ineligibility:
  RETRY_TASK-only denial must fail.

ND-P5AR-005 idle fallback with allowed candidate:
  idle/fail-closed is rejected while a supported allowed ordinary CFS candidate
  remains.

ND-P5AR-006 EEVDF return family bypass:
  denial must be tested against singleton, next buddy, protected current,
  leftmost eligible, heap search, and final current override families.

ND-P5AR-007 parent over-denial:
  denying one leaf must not skip a parent group while an allowed sibling
  descendant remains.

ND-P5AR-008 child exhaustion alias:
  nr_queued, sleep, throttle, delayed dequeue, yield, and EEVDF lag must not be
  accepted as child exhaustion proof.

ND-P5AR-009 cross-path enabled:
  core, DL server, proxy, sched_ext, and class-loop non-fair paths must either
  be excluded by configuration/runtime predicate or have separate settlement
  tests before P5A-R claims apply.

ND-P5AR-010 stale identity:
  stale task_generation, exec_generation, domain epoch, or grant epoch must
  reject or invalidate the attempt.

ND-P5AR-011 wakeup/preempt bleed:
  denial state must not affect check_preempt_wakeup_fair() or non-schedule
  picker users unless explicitly scoped.

ND-P5AR-012 newidle/lock-drop leak:
  lock-drop/newidle paths must clear, version, or reject attempt-local carrier
  reuse.

ND-P5AR-013 O(n) or hot layout regression:
  linear scans, unbounded retry, picker allocation, persistent hot denial
  fields, disabled branch growth, or hot function/layout growth without object
  evidence must fail validation.

ND-P5AR-014 claim overreach:
  runtime coverage, benchmark, production protection, hypervisor-grade
  isolation, cost-efficiency, deployment, and datacenter claims must remain
  false.
```

## Required Observables

Future P5A-R negative tests must provide:

```text
task stable identifier
task_generation
exec_generation
domain_epoch
grant_epoch
attempt_epoch
candidate_cpu
candidate_path
denial_result
retry_count
denied_receipt_count
settlement_point
rq_curr_observation
sched_switch_observation
group_path_observation
eevdf_return_family
cross_path_exclusion_or_settlement_state
overhead_layout_checker_result
claim_flags
```

These may be internal test observables. They are not public ABI or trace ABI.

## Required Validation Layers

```text
static/source layer:
  patch delta stays inside approved files and hooks
  unsupported cross paths are visibly excluded or settled
  no public ABI or trace ABI
  no non-ALLOW behavior enabled when denial-disabled
  no unbounded scan or persistent hot denial layout

build/object/layout layer:
  CONFIG_SCHED_EXEC_LEASE=off build passes
  CONFIG_SCHED_EXEC_LEASE=on denial-disabled build passes
  object/function-size and task/rq/sched_entity/cfs_rq layout evidence is
  recorded for any changed hot surface

runtime negative layer:
  denial-disabled QEMU smoke remains compatible
  denial-enabled ordinary-CFS workload denies A and schedules B
  denied A does not reach rq->curr or sched_switch
  same task/generation is not repicked in the same attempt
  allowed sibling group descendant remains schedulable
  fail-closed/quarantine happens only when no supported allowed candidate exists

claim layer:
  all runtime/protection/cost/datacenter claims remain false unless separate
  evidence gates are passed
```

## Non-Claims

This plan does not approve:

```text
Linux code changes
test instrumentation
runtime denial
CFS deny-and-repick implementation
runtime coverage
benchmark evidence
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next gate is the P5A-R implementation patch plan.
