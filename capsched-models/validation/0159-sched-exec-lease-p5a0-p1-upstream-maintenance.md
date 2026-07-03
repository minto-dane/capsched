# Validation 0159: SchedExecLease P5A0.P1 Upstream Maintenance Evidence

Date: 2026-07-03

Status: passed for candidate-scoped upstream drift, merge-tree, strict
checkpatch, and get_maintainer evidence. QEMU denial-disabled smoke and final
overclaim/security acceptance remain pending.

## Scope

This validates the concrete P5A0.P1 `0008` no-behavior source-contract patch
against the current fetched upstream and mainline-style maintenance checks.

It remains maintenance/reviewability evidence only. It is not runtime coverage,
runtime denial, monitor verification, production protection, cost-efficiency,
deployment readiness, or datacenter readiness evidence.

## Source State

```text
linux_branch=capsched-linux-l0
linux_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_subject=sched/exec_lease: Document P5A0.P1 no-behavior boundary
upstream_ref=upstream/master
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
upstream_subject=Merge tag 'net-7.2-rc2' of git://git.kernel.org/pub/scm/linux/kernel/git/netdev/net
```

## Runner

Runner:

```text
capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-upstream-check.sh
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260703T-p5a0-p1-0008-upstream \
  capsched/capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-upstream-check.sh
```

Output:

```text
/media/nia/scsiusb/dev/linux-cap/build/source-check/sched-exec-lease-p5a0-p1-0008-upstream-check/20260703T-p5a0-p1-0008-upstream
```

Key results:

```text
work_commit_matches=true
patch_sha_matches=true
candidate_delta_exact_allowlist=true
strict_checkpatch_clean=true
get_maintainer_rows=12
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=87320be9f0d24fce67631b7eef919f0b79c3e45c
base_to_upstream_commit_count=422
merge_tree_clean=true
candidate_anchor_drift_count=0
```

Strict checkpatch:

```text
total: 0 errors, 0 warnings, 0 checks, 45 lines checked
```

get_maintainer output:

```text
Ingo Molnar <mingo@redhat.com>
Peter Zijlstra <peterz@infradead.org>
Juri Lelli <juri.lelli@redhat.com>
Vincent Guittot <vincent.guittot@linaro.org>
Dietmar Eggemann <dietmar.eggemann@arm.com>
Steven Rostedt <rostedt@goodmis.org>
Ben Segall <bsegall@google.com>
Mel Gorman <mgorman@suse.de>
Valentin Schneider <vschneid@redhat.com>
K Prateek Nayak <kprateek.nayak@amd.com>
Codex <codex@local>
linux-kernel@vger.kernel.org
```

The `Codex <codex@local>` row reflects the local patch author metadata and is
not an upstream-ready author or Signed-off-by decision. Before public RFC or
mainline submission, author identity and signoff policy must be reviewed.

## Candidate Anchor Drift

The runner checked upstream drift from the merge-base to `upstream/master`
against the P5A0.P1 candidate anchor set:

```text
fs/exec.c
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/exit.c
kernel/fork.c
kernel/sched/core.c
kernel/sched/exec_lease.c
kernel/sched/sched.h
```

Result:

```text
candidate_anchor_drift_count=0
merge_tree_clean=true
```

This is candidate-scoped freshness evidence only. It does not make broad
device, async, MM, monitor, IOMMU, QueueLease, production, or datacenter
claims fresh.

## Remaining P5A0.P1 Acceptance Work

Still required before final P5A0.P1 acceptance:

```text
QEMU denial-disabled boot/workload smoke
final overclaim/security review
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
