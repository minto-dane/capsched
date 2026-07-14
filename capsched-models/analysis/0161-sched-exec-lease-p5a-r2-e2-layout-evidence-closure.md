# Analysis 0161: SchedExecLease P5A-R2 E2 Layout Evidence Closure

Date: 2026-07-14

Status: pre-acceptance gate for freezing one exact disposable layout as E3
planning input. No production layout, Linux promotion, or E3 source is approved.

## Decision Scope

Validations/0208 and 0210 independently passed the exact candidate on arm64
and x86_64. This gate decides only whether candidate commit
`162d16640634637a6f7604b90bf2275bea47ec63` may become the immutable layout
basis for a future default-off disposable E3 plan.

The decision deliberately distinguishes:

```text
allowed if this gate passes:
  freeze exact E2 candidate identity for E3 planning
  reference its four field names/types/placements in an E3 plan
  create a new disposable descendant only after a separate E3 plan passes

still forbidden:
  modify primary Linux or patch queue
  call the fields production-approved hot state
  enable the layout in ordinary CONFIG_SCHED_EXEC_LEASE
  implement rebuild, publication, fanout, picker, or runtime behavior
  infer runtime, protection, performance, or cost from object layout
```

## Evidence Closure

Both architecture-local results must retain their exact hashes:

```text
arm64 result:
  360f98bd71ed641ba410205925cdec00d55cfbaa990e2dee361798e6afb945f1
x86_64 result:
  6c7f53da489b2644a2e04ea8f424fdc990e8f1c9b59a9a60089a0251c049bd21
```

Each must show normal off/on candidate absence, 51 E1 values preserved, eight
exact additions, 59 total symbols, 27 fields, protected measurements intact,
candidate fields within their structures, and zero growth in all four
structures. Cross-architecture byte identity remains false: sched_entity
candidate offsets are 92/200 on both measured builds, while rq tail offsets
are arm64 3508/3512 and x86_64 3380/3384.

## Frozen E3 Planning Input

Only these four fields may be referenced by the next plan:

```text
sched_entity.sched_exec_summary_valid       unsigned char
sched_entity.sched_exec_min_fresh_vruntime  u64
rq.sched_exec_summary_state                 unsigned char
rq.sched_exec_built_generation              u64
```

The source remains default-off and probe-dependent in exactly four files with
diff SHA-256
`645ef21d82ff3abbe64177a624846e730c30400897cd011190e9abb579aa56ee`.
Any rename, type, placement, config, file, or source-identity change reopens E2.

## Acceptance Vocabulary

A passing result may set only:

```text
e2_layout_evidence_complete = true
exact_disposable_layout_frozen_for_e3_planning = true
```

It must keep these false:

```text
production_layout_accepted
hot_field_approved
primary_linux_change_approved
patch_queue_change_approved
e3_source_approved
e3_rebuild_approved
runtime_behavior_approved
runtime_denial_correctness
production_protection
performance_claim
cost_claim
deployment_ready
datacenter_ready
```

## Next

Run validation/0211. A pass authorizes drafting only the E3 evidence plan,
not an E3 worktree or source implementation.
