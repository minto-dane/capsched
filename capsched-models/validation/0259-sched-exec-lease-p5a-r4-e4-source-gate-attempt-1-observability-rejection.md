# Validation 0259: SchedExecLease P5A-R4 E4 Source-Gate Attempt 1 Observability Rejection

Date: 2026-07-19

Status: rejected before source acceptance or timing. The complete build and
R4-E3 regression evidence is retained, but the old source gate and its two
closure attempts omitted plan-required CPU-migration and interrupt/preemption
observability. No result from this attempt authorizes timing.

## Frozen Attempt

```text
candidate:       1dac9953b1b5c326a27285b1f2a6e4fac9960a1d
tree:            7d7f14800c9696b131ef7363cd8fb4cdd33a05b7
combined run:    20260719T-p5a-r4-e4-source-e3-regression-r1
combined result: 857688c8f689425664686207a56089b5d3d41c9d1d7286952d3abdc9ac00e555
source result:   2eb7f230da2f0b99f67f58fad1f342396c827f7fe2d467dd311187c7a3bc5d02
config result:   72c4eea25311657a8d1bf40927446ae732119f6a0672e9165cb4e8355e6f1b6e
E3 result:       b30f1b4029dfb776ca1047213e3d6ecfc966de25614807671ff2c9620de4e3e2
closure r1:      b9e7a4a61bd9b6de8b7aba78f238ef00fc91c0f2c6b5cd8d6007037e247fb82d
closure r2:      73f58b103a06c304d3bab7060c2a80a4fe1d40815c4cc7db2d109a9bad0f934f
normalized:      2553e753be0b39b6c7db13ec5940c9d2597fbdf9f632acb0425b250d3e002ed5
```

The run did complete six fresh source objects, six fresh arm64/x86_64 E3
profiles, 216/216 cases, and 216/216 receipts with zero compiler or kernel
diagnostics. Those facts remain useful predecessor-regression evidence. They
do not cure an incomplete source contract.

## Rejection

Analysis/0176 requires the runner to record vCPU pinning/migration
observations and local interrupt/preemption state, and classifies any observed
vCPU migration as a harness failure. Attempt 1 recorded clock regressions and
operation counts but did not:

- hold the measurement task on one guest CPU across a cell;
- compare every family sample, including the hard-IRQ callback, with that CPU;
- fail the cell on an observed CPU change; or
- emit CPU, migration, IRQ-state, and preemption-depth fields in every result
  row.

The two closure runs reproduced the incomplete gate rather than independently
checking this plan-to-source obligation. Their byte stability is therefore not
acceptance evidence. This is a validation-specification omission, not a
threshold rejection and not an E3 regression failure.

## Corrective Boundary

The direct-child candidate was amended to:

```text
commit:   9e4cb44fd1a1f998fcc288df87dad60505e8bf18
tree:     e6feb28a29fc8c37bc46af0fbf37de30f3401a4f
diff sha: bb115b371cd18551b93c09ae9b3d0cf458e70c9964927ff08d1bd3f586dd4cd2
line diff: +1743 -82
```

The corrected E4-only harness uses `migrate_disable()` for each complete cell,
records the selected guest CPU, compares all seven family samples against it,
records hard-IRQ CPU/IRQ/preemption state, emits the observations, and counts
any migration or state drift as a harness error. Strict checkpatch remains
0/0/0 and short arm64/x86_64 E4-enabled W=1 object builds pass.

The source gate now fail-closes on those exact anchors and records explicit
`measurement_task_migration_disabled`,
`vcpu_migration_observation_enforced`, and `irq_preempt_state_recorded`
claims. A complete fresh six-object and six-profile regression plus a new
independent closure is required. Attempt-1 artifacts cannot be promoted or
partially credited toward that corrected source identity.

## Claim Boundary

R4-E4 source acceptance and timing remain false. This result establishes no
live scheduler attachment, runtime correctness, bare-metal latency,
performance, monitor enforcement, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness claim.
