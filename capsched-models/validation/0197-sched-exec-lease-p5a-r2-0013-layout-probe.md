# Validation 0197: SchedExecLease P5A-R2 0013 Layout Probe

Date: 2026-07-05

Status: passed. No runtime behavior or protection claim is approved.

## Scope

This validates Linux patch `0013` as a no-behavior build-only layout probe
patch.

Validated artifacts:

```text
implementation/0039-sched-exec-lease-p5a-r2-0013-layout-probe.md
implementation/sched-exec-lease-p5a-r2-0013-layout-probe-v1.json
validation/run-sched-exec-lease-p5a-r2-0013-layout-probe.sh
```

Run:

```text
RUN_ID=20260705T-p5a-r2-0013-layout-probe-r2
```

Result:

```text
local_linux_commit: 0b79e307dc9536d38557141cfd650f2be9a2af57
patch_queue_replay_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
patch_sha256: cc1fe1754e64bfaa23e8214445b748d0287e7961500d0aa2a7d6f995a295fb38
series_sha256: 8f7c96605f816f9ec34015d7c6d8d1e1dbbe2936e60b86f8bc70dc4e1727270e
checkpatch_errors: 0
checkpatch_warnings: 1
checkpatch_warning_exception: MAINTAINERS new-file warning only
normal_config_off_probe_object_absent: true
normal_config_on_probe_object_absent: true
probe_build_passed: true
probe_object_size: 2464
probe_object_sha256: d688b67c55e9cfb0fdd8d5c0e6978be548d69edaa7d7b6c738baba8c6ae6d4cc
probe_symbol_count: 24
```

## Interpretation

Patch `0013` satisfies the P5A-R2 layout probe patch-plan scope:

```text
allowed files only
default-off probe config
no normal CONFIG off/on probe object
probe-on build emits measurement object
patch queue replay reaches expected replay commit
local and replay trees match
```

The checkpatch warning is the expected new-file MAINTAINERS review warning. It
is accepted for the private patch queue, but should be revisited before RFC or
upstream-style publication.

## Non-Claims

This validation does not approve:

```text
runtime behavior changes
new hot scheduler runtime fields
future min-pickable summary fields
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

The next work should extract and compare layout probe symbols into a structured
layout table, then add disabled-overhead/object evidence before any P5A-R2
behavior patch.
