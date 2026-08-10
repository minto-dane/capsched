# Analysis 0207: Dynamic Residency R9 Pre-IR Hostile Review Rejection

Status: R8 architecture rejected; `FREEZE_NO`; clean R9 redesign required

Date: 2026-08-09

Work record: `N-195`

Requirement: `RESIDENCY-DYN-001`

Machine disposition:
`analysis/dynamic-residency-r9-pre-ir-hostile-review-rejection-v1.json`

## Exact Target And Verdict

```text
Analysis 0206 reviewed raw SHA-256:
  4f30f2b85b67c3209661461f6cc82bff44575e1e00ca8b3ec0833f4f41837b5b
```

Four fresh read-only reviews independently returned both
`IR_ENCODING_READY=NO` and `FREEZE_NO`. Their 54 raw findings normalize to 40
distinct R8-local blockers. None is discharged by calling it an implementation
detail: each would force a faithful encoder to choose an identity, owner,
linearization point, transaction recovery rule, temporal rely, or cost
mechanism absent from the reviewed bytes.

The current file digest of Analysis 0206 changes when its rejection notice is
added. The digest above identifies the immutable reviewed bytes and remains the
negative-evidence target.

## Canonical Blockers

### Closed formal boundary

| ID | Required R9 closure |
| --- | --- |
| `R9-IMPORT-01` | Pin every imported guarantee by artifact hash, formula ID or formula hash, variable map, fault bound, and exact guarantee formula. |
| `R9-SCHEMA-OWNER-01` | Make the type, variable, identity-edge, allocator, mutable-field, and owner registries exact equal sets, including reverse slots, cursors, accumulators, physical owner, fences, and checkpoint state. |
| `R9-RECOVERY-01` | Give every crashable transaction a durable commit-or-abort decision and one deterministic recovery function; prose choices such as “abort or complete” are forbidden. |
| `R9-RANK-FORMULA-01` | State numeric phase orders, action deltas, finite credits, and weak/strong fairness formulas rather than naming ranks informally. |
| `R9-PROOF-CYCLE-01` | Split request/failure identity theorems from runtime/terminal theorems so the proof dependency graph is acyclic or declares an explicit simultaneous invariant component. |
| `R9-MUTATION-01` | Assign stable obligation IDs to exact mutated fields/actions and expected rejecting obligation IDs, including mutations of the validator and proof ledger. |

### Authority, identity, and ready state

| ID | Required R9 closure |
| --- | --- |
| `R9-ISSUANCE-01` | Model capability issuance and delegation from an existing parent, with target, subset, attenuation, non-amplification, parent reservation, and registry CAS. |
| `R9-RUNUSE-ALLOC-01` | Allocate each frozen run use from a conserved parent-owned use ordinal or counter; a reusable authorization may not mint unbounded uses. |
| `R9-SPAWN-LEAF-01` | Model SpawnAuthorization consumption and creation of a leaf protection Domain separately from container or tenant administrative parents. |
| `R9-EXEC-EXIT-01` | Fix exec/exit ordering across old-ready blocking, generation advance, runtime stop/ack, async drain or explicit transfer, program commit, and new-ready publication. |
| `R9-READY-01` | Allocate DispatchUseID before publication and define generation-bound Ready, Claim, Entry, and Cancel states tied to the exact activation input. |
| `R9-ROOT-READY-REFINE-01` | Refine a root scheduler slot through release, opportunity, committed ready state, and an exact ReadyID claim; absent ready work closes the slot without inventing service. |

### Portal, physical entry, and execution truth

| ID | Required R9 closure |
| --- | --- |
| `R9-PORTAL-01` | Add a provider-visible PortalCell and exact Active, Quiescing, ownerless fenced, context-installed, quantum-prepared, and Active transition sequence. |
| `R9-ENTRY-TIMER-01` | Make quantum preparation inert and let one provider-owned physical-entry primitive commit EntryOutcome, active CpuOwner, and timer enable together. |
| `R9-ENTRY-PROJECTION-01` | Make EntryOutcome the sole semantic source for consumed permit, run use, execution cell, and reserved budget, or define a complete idempotent projection protocol. |
| `R9-EXEC-PREDICATE-01` | Define current executability as an exact predicate over owner, activation, armed quantum, stop generation, gates, horizons, budget, and aggregate generation. |
| `R9-QUANTUM-01` | Use a nonwrapping repeated-quantum generation cycle; one accumulator instance cannot remain terminal after the first interval. |
| `R9-ATTEMPT-TERMINAL-01` | Order permit death, reservation settlement, AttemptTerminal CAS, and active-attempt clearing; an entered attempt cannot be cleared and retried. |
| `R9-OCCURRENCE-HANDSHAKE-01` | Separate provider occurrence grants from exact typed Monitor consumption, with bounded grant expiry/fail-stop and explicit temporal relies. |

### Release, budget, settlement, and closure

| ID | Required R9 closure |
| --- | --- |
| `R9-RELEASE-OUTCOME-01` | Allocate recurring ordinals through a durable ReleaseOutcome root so crash recovery burns or reconstructs exactly one same-ID opportunity. |
| `R9-BUDGET-EQUATION-01` | Fix units and the conservation equation among root debit, SchedContext debit, execution bound, required service, and entry/stop overhead before reservation. |
| `R9-INTERVAL-SETTLEMENT-01` | Consume each physical interval once while atomically recording charge and service-threshold accumulation. |
| `R9-BUDGET-SETTLEMENT-01` | Use one SettlementOutcome root plus idempotent per-ledger application cursors so crash/replay cannot double-refund or leak escrow. |
| `R9-TERMINAL-CLOSE-01` | Quiesce runtime and accounting before terminal outcome, then publish reverse-slot terminality and advance closure prefix without requiring that prefix in its own terminal guard. |

### Publication, failure, transfer, and migration

| ID | Required R9 closure |
| --- | --- |
| `R9-ENROLL-CLOSE-01` | Linearize enrollment ordinal, reverse slot, and gate generation in one local ordering domain; sealing and closure use exact prefix/cursor owners. |
| `R9-MERGE-OUTCOME-01` | Limit failure merge to one consistency domain and use a MergeOutcomeCell as the root from which component roots are projections. |
| `R9-COVER-RANK-01` | Allocate cover-reservation cells and finite discovery/merge credits whose consumption gives a strict outer closure rank. |
| `R9-SOURCE-FENCE-01` | Place source issuance fence and recurring stream cursor in the same ordering domain; the fence CAS forbids every ordinal at or above `qCut`. |
| `R9-NOREISSUE-ENTRY-01` | Bind a quorum no-reissue receipt, quorum configuration epoch, commit position, ordinal, activation core, and entry generation into permit and physical-entry guards. |
| `R9-SUCCESSOR-AUTH-01` | Derive successor authority only after source fence and finalized transfer outcome, through a distinct SuccessorTransferAuthorizationCore. |
| `R9-FENCED-REJECTION-01` | Preserve fence payload after mint fencing; post-fence failure is FinalizedContinuityLost, not an ordinary rejection that forgets ownership. |
| `R9-CLOSE-RESUME-01` | Make scope close atomically revoke the active aggregate/use generation or require resume to recheck that generation before every CPU enable. |
| `R9-OFFLINE-ACTOR-01` | Separate provider physical fail-stop/incarnation invalidation from protected crash charging and stop settlement. |
| `R9-MIGRATION-01` | Allow pre-entry retarget as a new attempt, but represent entered migration as terminal old opportunity plus a newly identified opportunity. |
| `R9-REFERENCE-REGISTRY-01` | Close the full GC reference-class registry, cursor ownership, authorization horizon, vector component, and tombstone predicate. |

### Systems composition and cost shape

| ID | Required R9 closure |
| --- | --- |
| `R9-ASYNC-CARRIER-01` | Define caller-frozen authority, service authority, operation core, validated intersection, immutable carrier generation/use, and activation request actions. |
| `R9-COALESCING-01` | Prohibit authority-level coalescing; only non-authoritative computation descriptors may be shared while each member retains an independent authority DAG and result. |
| `R9-RESIDENCY-AGGREGATE-01` | Validate variable-size residency dependencies off the dispatch path and publish one generation-fenced aggregate; dispatch binds a constant-size snapshot. |
| `R9-CONSISTENCY-DOMAIN-01` | Bind every action claimed atomic to one ConsistencyDomainID; remote dependencies enter only as typed certificate facts. |
| `R9-MGMT-BOOTSTRAP-01` | Define the boot-root-to-management-admission sequence and crash cuts before tenant admission becomes enabled. |

## Fixed R9 Architecture Choices

The review does more than reject R8. It fixes the following choices so R9 does
not reopen them silently:

```text
authority:
  issuance and every executable use are conserved allocations from parents

validation granularity:
  variable-size K-dependency validation occurs at ResidencyActivation
  each dispatch checks one current aggregate generation plus a fixed field set

physical entry:
  Monitor prepares a request
  the trusted physical-entry provider alone commits EntryOutcome, CpuOwner,
  and timer enable as one primitive

execution truth:
  EntryOutcome is the immutable semantic root
  consumed authority predicates are derived from it, not separately writable

runtime:
  repeated quanta use nonwrapping generations
  boundary commit disables execution before settlement or re-arm

recovery:
  every crashable transaction persists CommitIntent or AbortIntent
  recovery completes only the selected outcome

failure merge:
  one local MergeOutcomeCell linearizes the union

transfer:
  source issuance fencing precedes finalized transfer and successor authority
  post-fence failure retains the fence and becomes ContinuityLost
  successor entry requires a quorum no-reissue receipt in strong mode

migration:
  entered work never changes identity in place

coalescing:
  authority is never coalesced

protected occurrences:
  provider grants one typed occurrence; Monitor consumes it for one named action
```

## Deferred System Obligations

The following are valid but do not replace the 40 local closures. R9 must pin
the formulas it assumes; later components must implement and validate them:

```text
physical MemoryView/stage-2, code, stack, and mutable-state isolation
IOMMU, DMA, queue, IRQ, and device reset isolation
physical watchdog, stop, and fail-stop refinement
quorum implementation, cryptography, clocks, and Byzantine strengthening
typed endpoint exactly-once or explicitly weaker effect semantics
concrete Linux hook, scheduler-class, process, and async carrier refinement
measured TCB size, hot-path cost, scale, and multi-cluster deployment behavior
```

## Decision

R8 is retained as a rejected design and regression source. It is not a
normative semantic IR, architecture freeze candidate, TLA+ input, proof, or
protection result. R9 must be a clean self-contained architecture whose schema,
owner ledger, action contracts, failure recovery, proof graph, and import
formulas close every canonical blocker. Only then may an executable IR and
witness be encoded and reviewed.

```text
R8_candidate_rejected = true
R8_IR_encoding_ready = false
R8_architecture_frozen = false
R9_architecture_written = false
tla_authorized = false
model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
Linux_compatibility_evidenced = false
deployment_ready = false
```
