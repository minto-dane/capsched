# Analysis 0142: SchedExecLease P5A-R Implementation-Ready Audit

Date: 2026-07-03

Status: final audit for P5A-R ordinary-CFS-only behavior patch drafting.

## Verdict

P5A-R is ready to draft the next Linux patch slot, `0009`, under the
ordinary-CFS-only patch plan.

This verdict is deliberately narrow:

```text
draft 0009: allowed
accept 0009: not allowed yet
runtime denial correctness: not approved
CFS deny-and-repick correctness: not approved
production protection: not approved
cost/datacenter claim: not approved
```

## Evidence Checked

The audit requires the following chain:

```text
0163 picker-visible ineligibility gate
0164 EEVDF return dominance gate
0165 group hierarchy settlement gate
0166 cross-path exclusion/settlement gate
0167 overhead/layout gate
0168 negative validation plan
0169 ordinary-CFS patch plan
```

All are present and validated at pre-code/source/formal level.

## Linux Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_ref=upstream/master
upstream_commit=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5
next_patch_slot=0009
```

The patch queue currently ends at `0008`; no `0009` patch exists yet.

The upstream/source-shape refresh is recorded in analysis/0143 and
validation/0171. It found no direct P5A-R scheduler source-shape drift, while
recording fork/exec lifecycle drift as nonblocking for the ordinary-CFS-only
`0009` draft and blocking for broader lifecycle/global freshness claims.

## Readiness Meaning

Ready means:

```text
the next patch can be drafted
the patch must be ordinary-CFS-only
the patch must keep denial pre-settle and picker-visible
the patch must use an attempt-local bounded carrier
the patch must preserve hierarchy settlement obligations
the patch must exclude or separately settle cross paths
the patch must avoid O(n) scans and persistent hot denial layout
the patch must remain scheduler-private
the patch must carry a complete validation plan before acceptance
```

Ready does not mean:

```text
the patch is accepted
runtime behavior is correct
runtime coverage exists
negative QEMU tests have passed
performance is acceptable
monitor-backed protection exists
hypervisor-grade isolation exists
datacenter cost-efficiency is proven
```

## Acceptance Still Required

The future `0009` patch must still pass:

```text
patch queue replay
upstream replay or merge-tree
strict checkpatch and get_maintainer
source allowlist and source-anchor checks
pre-settle denial dominance checks
cross-path exclusion predicate checks
no public ABI / no trace ABI / no monitor call checks
no O(n), no unbounded retry, and no persistent hot layout checks
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on denial-disabled full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on denial-test-mode build if present
object/function-size evidence
task_struct/rq/sched_entity/cfs_rq layout evidence
QEMU denial-disabled boot/workload smoke
QEMU negative denial tests
upstream/source-shape refresh if upstream moves before acceptance
security diff review
final overclaim review
```

## Completion Statement

The pre-code implementation-ready goal for P5A-R ordinary-CFS-only patch
drafting is satisfied. The next project step may be the Linux `0009` draft.

All runtime/protection/cost claims remain false until the future patch and its
acceptance validation provide direct evidence.
