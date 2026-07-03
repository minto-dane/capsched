# Validation 0172: SchedExecLease P5A-R 0009 Source Gate

Date: 2026-07-03

Status: passed for source-gated draft only. Linux patch `0009` remains
unaccepted.

## Scope

This validation checks:

```text
implementation/0034-sched-exec-lease-p5a-r-0009-ordinary-cfs-draft.md
implementation/sched-exec-lease-p5a-r-0009-ordinary-cfs-draft-v1.json
formal/0113-p5a-r-0009-source-gate-model/P5AR0009SourceGate.tla
linux-patches/patches/capsched-linux-l0/0009-sched-fair-Draft-ordinary-CFS-exec-lease-candidate.patch
```

It validates only the source shape and claim boundary for the dormant ordinary
CFS candidate.

## Runner

```text
validation/run-sched-exec-lease-p5a-r-0009-source-gate.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-0009-source-gate/20260703T-p5ar-0009-source/
```

Patch queue replay was also run directly:

```text
DOMAINLEASE_RECREATE_FETCH=0 \
DOMAINLEASE_LINUX_REFERENCE=/media/nia/scsiusb/dev/linux-cap/linux \
./linux-patches/scripts/recreate-capsched-linux-l0.sh \
  /media/nia/scsiusb/dev/linux-cap/build/replay/capsched-linux-l0-0009-20260703T231733Z
```

Replay result:

```text
final HEAD: 7a402107fd63faf7063c2dea05e88e7f8a23f4bf
```

## Checks

Source checks:

```text
linux_commit=7a402107fd63faf7063c2dea05e88e7f8a23f4bf
parent_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
upstream_commit=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5
patch_name=0009-sched-fair-Draft-ordinary-CFS-exec-lease-candidate.patch
patch_sha256=21dd92416d8309b82a2da7ead8fa9998661cff645f845dcdd0066b6393cd2d25
series_sha256=7508a9c8e3759a72b9dec0851d03e9d52c99cd1a96795e7e951248f4c0c8ae6d
checkpatch_clean=true
diff_check_clean=true
delta_files_exact_allowlist=true
ordinary_cfs_wrapper_before_settlement=true
static_key_dormant=true
cross_path_predicate_present=true
attempt_local_carrier_present=true
pick_eevdf_pickable_checks=6
no_forbidden_added_tokens=true
```

Formal checks:

```text
safe_tlc_passed=true
safe_states_generated=5
safe_distinct_states=4
safe_depth=4
unsafe_expected_counterexamples=10
```

Build evidence:

```text
targeted_build_attempted=true
targeted_build_passed=false
targeted_build_blocked_missing_gelf=true
```

The failed targeted build is a host dependency limitation:

```text
tools/objtool/include/objtool/elf.h:10:10: fatal error: gelf.h: No such file or directory
```

This validation does not treat the build as passed.

## Result

The source-gated draft requirements are satisfied:

```text
0009 patch exists in patch queue
series records 0009
base.txt work_commit matches Linux HEAD
ordinary CFS fast path uses a dedicated wrapper
normal class picker and DL fair-server picker remain on pick_task_fair
candidate path is dormant because the static key has no enable site
SCX/core/proxy are excluded by the active predicate
denied task and blocked group receipts are attempt-local and bounded
no public ABI, trace ABI, exported symbol, monitor call, allocation, sleep,
lock, or unbounded scan token is added by the delta
```

## Non-Claims

This validation does not approve:

```text
accepting 0009
runtime denial correctness
CFS deny-and-repick correctness
broad move denial
runtime coverage
CONFIG off/on build compatibility
object/layout overhead
QEMU compatibility
negative runtime denial behavior
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next acceptance stage must collect build, object/layout, QEMU
denial-disabled, negative denial, security diff, and final overclaim evidence
before `0009` can be accepted.
