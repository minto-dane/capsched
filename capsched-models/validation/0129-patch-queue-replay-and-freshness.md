# Validation 0129: Patch Queue Replay and Freshness

Status: Passed for hash-level replay, source-drift freshness, and targeted
SchedExecLease build; no behavior or protection claim

Date: 2026-07-02

## Purpose

N-157 verifies that the private Linux patch queue can be trusted before the
project moves toward implementation design.

This validation covers:

```text
fresh replay of linux-patches series 0001..0003
expected work_commit hash reproduction
N-156 footprint freshness after the rename
targeted scheduler-subtree build in disabled and enabled states
```

## Replay Fixes

The first replay attempt exposed a real reproducibility hole: fresh clones did
not have a Git committer identity, so `git am` failed.

The replay script was strengthened to:

```text
provide deterministic replay committer defaults
use --committer-date-is-author-date
check missing patch files before applying
support local reference clones
support non-origin upstream remotes
reject dirty targets
reject branch rewrite unless DOMAINLEASE_RECREATE_FORCE=1
check final HEAD against upstream/base.txt work_commit
```

## Replay Evidence

Command shape:

```sh
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux \
  linux-patches/scripts/recreate-capsched-linux-l0.sh \
  build/replay/n157-capsched-linux-l0-20260702T024618Z
```

Result:

```text
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
work_commit=3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
replayed_head=3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
series=0001,0002,0003
```

The replayed tree status was clean.

## Freshness Evidence

Command shape:

```sh
DOMAINLEASE_RUN_ID=20260702T024618Z \
DOMAINLEASE_LINUX_DIR=/media/nia/scsiusb/dev/linux-cap/build/replay/n157-capsched-linux-l0-20260702T024618Z \
DOMAINLEASE_DRIFT_WORK_REF=capsched-linux-l0 \
DOMAINLEASE_DRIFT_UPSTREAM_REF=origin/master \
DOMAINLEASE_DRIFT_FETCH=0 \
  capsched/capsched-models/validation/run-linux-source-drift-gate.sh
```

Run directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/source-drift/linux-source-drift-gate/20260702T024618Z
```

Observed result:

```text
base_commit=4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
upstream_commit=4a50a141f05a8d1737661b19ee22ff8455b94409
work_commit=3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
base_to_upstream_commit_count=342
watched_changed_count=1
model_refresh_required_count=0
direct_footprint_drift=false
future_attachment_drift=false
semantic_drift_requires_refresh=false
merge_tree_exit=0
merge_tree_clean=true
model_freshness=fresh
candidate_no_behavior_patch_reviewable=false
linux_patch_approved=false
behavior_change=false
runtime_coverage=false
abi=false
public_tracepoint_abi=false
monitor_verified=false
production_protection=false
```

Patch footprint for the replayed work commit:

```text
A include/linux/sched_exec_lease.h
M init/Kconfig
M kernel/sched/Makefile
A kernel/sched/exec_lease.c
```

## Targeted Build Evidence

Command shape:

```sh
LINUX=/media/nia/scsiusb/dev/linux-cap/build/replay/n157-capsched-linux-l0-20260702T024618Z \
BUILD_TAG=n157-replay-final \
JOBS=8 \
  capsched/capsched-models/validation/run-sched-exec-lease-rename-build-validation.sh
```

Log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-rename-build-20260702T024654Z.log
```

Build outputs:

```text
OFF: /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-off-n157-replay-final-x86_64
ON:  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-sched-exec-lease-on-n157-replay-final-x86_64
```

Checks:

```text
OFF:
  SCHED_EXEC_LEASE = undef
  kernel/sched/built-in.a built
  kernel/sched/exec_lease.o absent

ON:
  SCHED_EXEC_LEASE = y
  kernel/sched/built-in.a built
  kernel/sched/exec_lease.o present

Renamed source surface:
  old scaffold terms absent
  CONFIG_SCHED_EXEC_LEASE and exec_lease anchors present
```

## Meaning

The N-156 patch queue is now replayable and fresh enough to support
implementation design work. This does not approve a behavior-changing Linux
patch by itself.

## Non-Claims

This validation is not full `vmlinux` validation, QEMU boot validation, runtime
coverage, scheduler enforcement, ABI approval, monitor verification,
production protection, or cost-efficiency evidence.
