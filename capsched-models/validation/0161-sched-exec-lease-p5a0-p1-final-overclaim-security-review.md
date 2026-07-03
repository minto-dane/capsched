# Validation 0161: SchedExecLease P5A0.P1 Final Overclaim and Security Review

Date: 2026-07-03

Status: passed for final overclaim/security review. P5A0.P1 is accepted as a
no-behavior source-contract slice only.

## Scope

This is the final acceptance review for the concrete P5A0.P1 `0008` Linux
patch:

```text
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_subject=sched/exec_lease: Document P5A0.P1 no-behavior boundary
patch=linux-patches/patches/capsched-linux-l0/0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch
```

It reviews whether the collected evidence supports the accepted claim and
whether any artifact overclaims runtime denial, runtime coverage, monitor
verification, protection, cost-efficiency, deployment readiness, or datacenter
readiness.

## Evidence Reviewed

P5A0.P1 acceptance evidence:

```text
validation/0156:
  source checker, patch queue replay, and formal source gate passed

validation/0157:
  full vmlinux CONFIG_SCHED_EXEC_LEASE=off/on builds passed

validation/0158:
  object/symbol/section-size, hot scheduler function-size, and task layout
  evidence passed

validation/0159:
  candidate-scoped upstream drift, merge-tree, strict checkpatch, and
  get_maintainer evidence passed

validation/0160:
  QEMU off/on boot/workload smoke passed with workload_mode=all
```

Codex Security diff scan:

```text
scan_dir=/tmp/codex-security-scans/linux/d812f83c033a_20260703T-security-diff
report=/tmp/codex-security-scans/linux/d812f83c033a_20260703T-security-diff/report.md
target=a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8..d812f83c033a9f9b3d533e667e7106a5734eb30b
changed_files=2
reportable_findings=0
coverage=complete
```

The scan reviewed:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Delegated file-review receipts:

```text
artifacts/02_discovery/work_ledger.jsonl
```

Security scan result:

```text
No reportable findings.
No plausible candidate findings.
Both diff-scoped files have completed full-file review receipts.
Validation and attack-path phases were skipped because discovery produced no
candidate findings.
```

## Accepted Claim

The accepted claim is intentionally narrow:

```text
P5A0.P1 accepts Linux patch 0008 as a no-behavior source-contract patch.
```

This means:

```text
The patch only adds source comments.
The patch changes no executable behavior.
The patch changes no object layout.
The patch changes no helper body.
The patch adds no ABI, trace ABI, exported symbol, monitor call, allocation,
locking, refcount transfer, scheduler branch, runtime denial, retry,
ineligibility, quarantine, budget charging, or protection mechanism.
The patch documents that future behavior-changing non-ALLOW statuses, denied
receipts, monitor roots, lifecycle changes, and status plumbing need separate
proof.
```

## Overclaim Review

The following claims remain explicitly not accepted:

```text
runtime denial
CFS deny-and-repick
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

QEMU validation/0160 is boot/workload compatibility evidence only. It is not
runtime coverage because `pick_next_task` and `__schedule` remain
function-missing and `dlease_pick_next_task` kprobe insertion failed.

Object/layout validation/0158 is static generated-object evidence only. It is
not behavior equivalence for future enforcement.

Upstream validation/0159 is candidate-scoped maintenance evidence only. It does
not refresh broad device, async, MM, monitor, IOMMU, QueueLease, production, or
datacenter claims.

## Security Decision

No security regression was found for P5A0.P1 `0008`.

The patch is accepted as P5A0.P1 full acceptance because every required
no-behavior acceptance gate has passed:

```text
source/replay/formal gate: passed
full vmlinux off/on builds: passed
object/layout checks: passed
candidate-scoped upstream maintenance checks: passed
QEMU off/on compatibility smoke: passed
Codex Security diff scan: no findings, complete diff-scoped coverage
overclaim review: passed
```

## Remaining Project Work

P5A0.P1 is closed only as a no-behavior source-contract slice.

The first behavior-changing work remains split:

```text
P5A-R:
  deny one CFS task and pick the next CFS task; still requires fair-picker
  eligibility integration and bounded retry design before code.

P5A-M:
  broad move denial; still requires move-result/status settlement across
  migration, affinity, swap/push/pull, hotplug, core-cookie-steal, and fair
  direct load-balance bypass before code.
```

## Non-Claims

This validation does not approve:

```text
runtime denial
CFS deny-and-repick
broad move denial
runtime coverage
budget enforcement
public ABI or trace ABI
monitor calls or monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```
