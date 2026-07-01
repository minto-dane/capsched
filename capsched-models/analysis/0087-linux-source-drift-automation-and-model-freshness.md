# Analysis 0087: Linux Source-Drift Automation and Model-Freshness Gate

Status: automation contract drafted and executed

Date: 2026-07-01

Related artifacts:

```text
analysis/0086-linux-upstream-drift-maintenance-review.md
analysis/linux-upstream-drift-maintenance-review-v1.json
analysis/linux-source-drift-model-freshness-gate-v1.json
validation/run-linux-source-drift-gate.sh
formal/0065-linux-source-drift-freshness-gate-model/
validation/0103-linux-source-drift-freshness-gate.md
```

## Purpose

N-131 established that upstream-following must be part of the design, not an
occasional manual chore. This note turns that into a reusable source-drift and
model-freshness gate.

The goal is not to make rebasing easy by ignoring semantic risk. The goal is to
detect when upstream has moved code that CapSched models rely on, then block
patch movement until the affected source maps, TLA models, and validation
records are refreshed.

## Rule

Git cleanliness is not semantic freshness.

```text
clean merge-tree
  means: current patch queue may apply mechanically

clean merge-tree
  does not mean: scheduler authority model is still valid
  does not mean: workqueue or io_uring assumptions are still valid
  does not mean: Linux patch approval
  does not mean: protection evidence
```

The gate therefore records both:

```text
1. mechanical rebase signal
2. model freshness signal
```

## Automation Contract

The runner:

```text
validation/run-linux-source-drift-gate.sh
```

is source-only. It does not modify Linux source, attach tracepoints, run BPF,
write tracefs, build kernels, or approve patches.

It reads:

```text
linux source Git state
analysis/linux-source-drift-model-freshness-gate-v1.json
```

It writes a run directory under:

```text
build/source-drift/linux-source-drift-gate/<timestamp>/
```

with:

```text
metadata.txt
watched-paths.txt
patch-footprint.name-status
watched-drift.name-status
watched-drift.stat
group-results.tsv
group-results.json
merge-tree.txt
summary.env
result.json
```

## Watch Groups

The machine-readable contract defines watch groups, not one undifferentiated
file list.

Important groups:

```text
l0_footprint
scheduler_authority_core
task_lifecycle_identity
async_workqueue
async_io_uring
policy_frontend_security
memory_and_mm_state
device_queue_iommu
scheduler_nearby_non_intersecting
```

Each group carries:

```text
paths
drift_class_if_changed
stale_if_changed
affected_artifacts
blocked_until_refresh
```

This is intentionally conservative. A changed watched path can make a model
stale even if our Linux patch queue still merges.

## Current Observation Meaning

For the current fetched upstream state, the runner observes the same shape as
N-131:

```text
watched drift: kernel/sched/cpufreq_schedutil.c
classification: D1 nearby non-intersecting drift
direct L0 footprint drift: false
model refresh required: false
merge-tree clean: true
```

The conclusion remains:

```text
no new Linux async-carrier patch
no no-behavior async-carrier names
continue model/source work
```

## Model-Freshness Classes

### Fresh

No watched group requiring refresh changed.

Allowed:

```text
continue analysis/model work
consider patch proposals only through their own gate
```

Not allowed:

```text
claim protection
claim runtime coverage
skip future review
```

### Stale

At least one watched group with `stale_if_changed=true` changed.

Required:

```text
refresh affected source maps
rerun affected TLA/source gates
record validation
only then reconsider patch movement
```

Blocked:

```text
new Linux behavior patch
new async carrier Linux names
ABI
tracepoint ABI
monitor verification claim
protection claim
```

### Unknown

The watch map, Git state, or merge-tree check could not be completed.

Required:

```text
fix observation first
```

Blocked:

```text
all Linux patch movement
```

## Safety Invariants

The gate enforces:

```text
source observation must run before freshness decision
watch map must be present
clean merge-tree is not enough for semantic freshness
stale model blocks Linux patch movement
no concrete consumer means no async-carrier Linux names
no behavior change
no ABI
no protection claim
non-claims must be recorded
```

## Non-Claims

This automation does not approve Linux code, async carrier implementation,
workqueue integration, io_uring integration, direct-call ABI, public
tracepoints, runtime coverage, monitor verification, behavior change, or
production protection.
