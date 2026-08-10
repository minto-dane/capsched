# Analysis 0195: Dynamic Residency Datacenter and Composition Boundary Review

Status: eight semantic blockers recorded and redesign integrated; executable
validator, fresh review, and formal refinement pending; architecture not frozen

Date: 2026-08-09

Work record: N-182

Requirement: `RESIDENCY-DYN-001`

Machine record:
`analysis/dynamic-residency-datacenter-composition-boundary-review-v1.json`

## Verdict

An independent datacenter/scale review returned `FREEZE=NO`. It reviewed a
pre-integration candidate on 2026-08-09 and found eight places where TLA+ would
have had to invent semantics. The review identity is session provenance, not a
cryptographically authenticated reviewer. Its report is discovery evidence,
not acceptance of the revised bytes. The raw review output is not retained as
an immutable signed artifact, so this is an unattested transcription and may
not count as external freeze evidence.

The candidate now carries an explicit redesign for every item below. That does
not close any finding: the machine contract, witness, validator, mutation set,
and a fresh Assurance Protocol v2 campaign must agree on the revised immutable
candidate first.

## Findings

| ID | Blocker | Integrated redesign | Remaining gate |
| --- | --- | --- | --- |
| `DC-R3X-01` | process-scale hierarchy and metadata widths were optional or per-admission | boot-sealed `NodeConfig`, exact `DomainHierarchyCertificate`, ancestor capacity equation, typed `TooWide`/`NoParentCapacity`, old-path fence before reparent | exact schema/mutations and DYN-ADMIT induction |
| `DC-R3X-02` | independent lanes could certify the same physical CPU opportunity | common `HardwareCapacityRootCertificate`, parent-conserved allocation, immutable allocator-issued lease, and single-writer one-use cell | two-lane physical-capacity witness and DYN-SHARD |
| `DC-R3X-03` | one shard `ControlTurn` could pay several target ranks | exact `TargetControlTurn`, immutable target reservations, and `sum delta target <= delta shard <= 1` | simultaneous target witness and arithmetic model |
| `DC-R3X-04` | partition behavior was an untyped deferred rely | `NodeLeaseImportCertificate` with no-fork lineage, clock interval/uncertainty, offline bound, and exact immutable partition modes | CLUSTER-PART producer refinement and import mutations |
| `DC-R3X-05` | cross-node exclusive placement lacked global fencing identity | `GlobalPlacementUse` in every artifact; minimum authority horizon; exact quiescence or residual-effect-safe quorum supersession with prefix or continuity loss | transfer witness and DYN-REGRESSION |
| `DC-R3X-06` | oversized failure closure and dependent cleanup had no total bound | boot-fixed cover tree; union of source/current/live-referenced topology generations; exact closure, unique LCA, or node fail-stop; precharged cleanup | failure-cover/overflow/crash mutations and DYN-CHURN |
| `DC-R3X-07` | residency marked service before ENTRY/CODE/STATE physical installation | non-executable intent, activation decision, complete context and receipts; commit gives `ActivatedUnserved`, only qualifying delivery gives `Served` | ENTRY/CODE/STATE refinement and DYN-COMPOSE |
| `DC-R3X-08` | management/recovery availability was an oracle | boot-root `ManagementRecoveryBootstrapContract` with independently conserved execution/control/clock/namespace/audit/failure resources; failure is node fail-stop | MGMT/ENTRY/CODE/STATE refinement and bootstrap mutations |

## Cross-Cutting Consequences

The corrections change five earlier abstractions:

```text
lane independence
  now includes conserved physical execution cells, not merely separate clocks

control progress
  now spends an exact target microstep, not a reusable shard turn

cluster input
  now has a typed local consumption contract, not "valid lease" prose

activation
  now linearizes at a joint physical context commit, not residency readiness

failure boundedness
  now covers every real event and every charged dependent use, not only the
  authority hot path for events that already fit a vector
```

These are semantic requirements. Scheduler algorithms, hierarchy data
structures, certificate encodings, and production policy thresholds
remain deliberately unselected.

## Fresh Review Rule

The source review predates these edits and cannot be reused as approval. A
fresh reviewer must inspect one immutable capsule containing at least the human
contract, machine contract, this disposition, the complete witness, the exact
validator, and its hostile mutations. Assurance Protocol v2 must authenticate
the reviewer and decision chain. Until then every `DC-R3X-*` status is open.

## Non-Claims

This record does not freeze the architecture, authenticate the source reviewer,
validate the redesign, complete TLA+, prove recurring service, implement a
Monitor, change Linux, or evidence isolation, performance, cost, scalability,
multi-cluster operation, or deployment readiness.
