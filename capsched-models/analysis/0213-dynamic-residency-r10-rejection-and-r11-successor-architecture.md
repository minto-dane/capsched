# Dynamic Residency R10 Rejection and R11 Successor Architecture

## Status

R10 is rejected as a semantic-closure and promotion candidate. R11 architecture
construction is authorized; semantic freeze, TLA+, model support, and every
protection claim remain unauthorized.

The machine-readable contract is
`dynamic-residency-r11-successor-architecture-v1.json`.

## Exact R10 Boundary

The retained R10 structural snapshot is:

```text
schema       9764d711c14f41de07185a359814522ddca563b0e52593f3c6b4334e75fcfadf
source       ad463ae92004e962cbe8719073453aba4f60345e0c8099683a2b858268ef6f97
validator    a6c5a541259ef6eb29f0f16da222d065f126f6311de22edae9f4c6577c836e7e
local test   887b4d6e0ad3475b7086c9d1f1f0b2fe841fc8ba10b4ea88489dfc91920c8293
local result 7905414efd1592e8d4d86ae75415630748566d74ff11da3c0d1decac6b8ad31d
expanded     1c8b4d5910db0354e049f21428384963d0d45fbe133d5e35a03993661f70dc6f
lock         8955e8d0b0fe5137c9a0d78ab3aa5c30463e9d9dea6575baaee8ef503e00878a
```

It materializes 77 types, 22 variables, 5 objects, 4 transaction kinds, 49
concrete actions, 2 invariants, 1 provider formula, 1 progress property, 2
proof-name nodes, and 1 positive witness. Local and external structural suites
kill 29 mutants. Those are useful regression facts only.

R10 is rejected because:

- 26 of 42 canonical blockers are still explicit `PENDING-*` references;
- all 13 locally executed semantic-vacuity variants were accepted;
- independent review accepted a broader 19-variant semantic weakening set;
- a modified validator can identify visible case names and counterfeit all
  expected rejects;
- candidate formula, claim, blocker, profile, role, bound, and mutation meaning
  remains self-authored;
- the evidence harness is not a separately authenticated promotion authority;
- current Init bypasses management bootstrap and creates ambient runnable
  objects; and
- the only positive witness cannot reach context install, eligibility, root
  claim, physical entry, runtime, settlement, failure, or transfer.

## R11 Trust Layers

R11 uses four separately reviewed layers:

| Layer | Owns | Reject namespace |
| --- | --- | --- |
| Candidate IR | typed modules, exact state/actions/frames/recovery and obligation declarations | `IR-*` |
| External policy/catalog | claims, trust/resource/partition roles, profile minima, blockers, mutation oracle | `CAT-*` |
| Formal backends | Init-conformance, inductiveness, conservation, refinement, rank, liveness, noninterference | `PO-*` |
| Assurance boundary | captured bytes, runtime/tool identity, subprocess isolation, complete results, review attestation | `HM-*` |

No layer may treat another layer's self-description as evidence. Candidate
status remains `draft`; publication status is always derived externally.

## Modular Artifact Boundary

The planned successor is Formal 0150 with an exact source manifest:

```text
policy-ref.json                 external policy id and expected digest only
profile-ref.json                external scenario-profile id and digest only
source-manifest.json            exact module paths and roles, no globbing
source/00-core.json             concrete types and bindings to policy-owned resource/writer/partition rules
source/10-bootstrap.json        empty executable Init and management bootstrap
source/20-authority.json        issue, use, async, spawn, exec, exit, revoke
source/30-dispatch.json         activation through post-claim entry binding
source/40-runtime.json          CPU product, time, stop, budget, settlement
source/50-residency.json        admission, publication, recurring opportunity
source/60-failure-transfer.json failure epochs, merge, fencing, successor
source/70-gc.json               references, horizons, tombstones, exhaustion
source/80-composition.json      two-lane and two-cluster bounded composition
materialize-r11.py              structural/derived-semantics compiler
generated/expanded.json         exact finite locations and action instances
generated/obligations.json      backend-neutral proof-obligation manifest
generated/lock.json             manifest-last digest projection
```

The external policy and profile are captured with the candidate but are not
discovered or authored as candidate fields. The materializer receives their
digests from the assurance launcher.

The policy owns genesis constraints; candidate modules supply a concrete
`Init`; formal backends check conformance and `Init => Inv`. A prover never
authors initial-state meaning. Cross-consistency-domain movement is never one
remote atomic update: the source owner emits a one-use export/reservation
receipt, an in-transit conservation bucket holds the authority, and the
destination owner performs an idempotent consume/apply.

## Acyclic Semantic DAG

```text
D0  finite types, policy bounds, resource algebra, writer/CD partitions,
    object store, identity and work allocators
D1  sealed non-executable BootRoot and protected bootstrap work
D2  management identity, attenuated authority, context, admission, residency;
    tenant gate remains closed
D3  authority issue, role-use reservation, return/burn, and revocation
D4  ActivationRequest from sync use, async distinct use, or async alias use
D5  stream release -> Opportunity -> Ready Available, in parallel with
    root-calendar release -> RootFrame/RootSlot Open
D6  fresh Attempt, one-use authority/escrow reservation, pre-claim snapshot
D7  inert provider context install and write-once ContextInstalled receipt
D8  EligibilitySeal publication and Ready Eligible
D9  atomic protected Ready/RootSlot claim
D10 post-claim PhysicalEntryBinding with fresh entry/stop/quantum identities
D11 provider PrepareEntry -> atomic CommitEntry or NeverEntered
D12 protected observation and derived ReadyConsumed; observation grants nothing
D13 provider boundary/stop/offline -> settlement root -> idempotent ledger apply
D14 terminal result -> fresh retry after NeverEntered or next stream ordinal
D15 revoke/close/offline/failure least fixed point and late-fact successor epoch
D16 source fence -> no-reissue/quiescence receipt -> one-use destination install
D17 checkpoint -> reference horizon -> tombstone -> bounded GC/rekey/quarantine
```

Retry and recurrence are not graph back-edges. They allocate a strictly newer
attempt or stream ordinal and are justified by induction over admitted finite
work per ordinal.

## Authority Semantics

Every resource component obeys:

```text
genesis/imported supply
  = available authority balances
  + delegated child balances
  + reserved role uses and runtime escrow
  + settled consumption
  + explicit policy-authorized burn
  + fenced export awaiting destination installation
```

Issue transfers quota; it never copies quota. Constraints are component-wise
attenuated. A normal parent revoke does not retroactively revoke a transferred
child unless an explicit generation-fenced revocation scope was included.

Async authority has explicit role semantics:

```text
distinct caller/service:
  reserve one role-use ordinal from each authority

aliased caller/service:
  reserve two role-use ordinals from one authority
  perform one account write with the sum of both role reservations

single-use role fusion:
  forbidden in R11
```

Budget debits are determined independently by the fixed ledger plan; two role
uses do not imply accidental double charging of every resource component.

## Physical Entry Root

`CurrentExecutable` becomes true only in the atomic provider `CommitEntry`
product. That product binds CPU and incarnation, Domain activation/MemoryView
composition receipt, subject/program/aggregate generations, run/scheduling/
charge authorities, complete revocation path, context receipt, root claim,
partition/time receipt, escrow and quantum generation, stop residual, timer,
execution gate, and immutable Entered receipt.

The first entry consumes a fresh one-use `EntryPermit`, not a continuation
token. Only a successful `CommitEntry` may emit the `EnteredReceipt` and a
continuation token for the same bounded entry generation. This removes the
cycle in which first entry would require a token produced only after entry.

`ReadyConsumed` is an existential projection over a matching provider Entered
receipt. Monitor-owned `AttemptState` may cache observation but can never be its
truth source. Root claim and protected observation cannot make instructions
executable.

Revocation request blocks new entries. Existing bounded entry authority ends at
provider stop/fail-stop or its already armed hard boundary; only then is the
revocation scope `RevokedEffective`. CPU offline atomically disables gate/timer,
changes incarnation, publishes a terminal receipt, and forces protected
reconciliation.

## Provider Contracts

Each provider contract is structured, not a free `always TRUE` clause:

```text
owned state and exact writer
trigger and admissible pre-state
success receipt and state relation
fault partition and fail-closed successor
finite time/work/overrun bound with units
trusted fairness class
consumer obligation IDs
```

Runtime receipts begin `Vacant`. Static NodeConfig and BootRoot facts use a
separate sealed-genesis policy; they cannot masquerade as action-produced
receipts.

## Required Simultaneous Invariants

R11 generates or declares at least these obligation families:

```text
WellFormedAndBounded
NoExecutableInit
ExactWriterAndPartition
IdentityGenerationNonAlias
ResourceVectorConservation
AuthorityAttenuation
NoAmbientActivation
AsyncRoleUseConservation
PublicationSealBeforeVisibility
AdmissionSealBeforeUse
EntryReceiptCausalChain
ReadyConsumedOnlyByEnteredReceipt
CurrentExecutableComplete
OnePhysicalOwnerPerCPU
OneEnteredAttemptPerOccurrence
ArmedUpperWithinAllEscrowsAndHorizons
OneReceiptOneSettlementOneLedgerApply
RevocationEffectiveAfterStop
OfflineIncarnationInvalidatesAllOldEntry
CloseAndFailureActiveUseCut
CompletedFailureEpochImmutable
TransferSourceDestinationDisjoint
PartitionAndTimeConservative
TwoLaneNoDisjointWaitOrInvalidation
ManagementBeforeTenantAdmission
NoReclaimWithAuthenticatingReference
LinuxCannotWriteOrMintAuthority
```

All safety obligations are checked as one simultaneous invariant. A source
`preserved_by` list is not proof. The compiler generates `Init => Inv` and one
`Inv /\ Action => Inv'` obligation per concrete action, plus resource-specific
equations. Proof receipts live outside the candidate.

## Required Witness Set

Before freeze, a concrete bounded interpreter must execute:

```text
W0  empty executable Init -> ordinary management entry and settlement
W1  authority issue commit, abort, and each durable crash cut
W2  async distinct reservation -> carrier -> activation -> terminal
W3  async aliased two-role reservation without duplicate write
W4  sync and async full context/eligibility/claim/entry chains
W5  cancellation racing preparation and root claim
W6  NeverEntered -> fresh retry, plus Entered/global-no-reissue rejection
W7  multiple quantum generations with budget, overhead, stop, settlement
W8  revoke and CPU-offline at every physical-entry cut
W9  two live lanes with disjoint progress and shared-root conservation
W10 failure closure, overlapping merge, rebase/subsume, and late fact
W11 strong transfer, safe-gap transfer, and continuity-loss terminal outcome
W12 two nodes/clusters under partition, restart, namespace exhaustion, and GC
```

Every witness evaluates all state invariants at Init and after each step,
records exact pre/post hashes and deltas, and names only generated action
instances. Witnesses establish reachability and nonvacuity, not generic proof.

## Multi-Cluster Boundary

One logical DomainLease-Linux OS is a common authority namespace and ABI over
node-local enforcement. It is not a synchronous global runqueue or shared
mutable kernel heap. Remote mutable state is never treated as locally atomic.
Finite-horizon signed/quorum receipts are imported into one local consistency
domain.

Destination execution for a transferred ordinal requires either authenticated
source quiescence or a conservative horizon strictly beyond source maximum
execution, clock uncertainty, and stop bound. Network silence cannot satisfy
that guard. Failure, partition, and namespace work is precharged so a hostile
tenant cannot force unbounded global scans or disjoint-lane stops.

## Scheduler Capability Boundary

The scheduler-facing capability slice remains narrow:

```text
ExecutionGrant:
  authority to submit one execution use

ExecutionLease:
  frozen subject, generations, authority, placement, priority ceiling,
  co-tenancy, budget context, and horizon for one attempt

CPU Budget Context:
  independently delegated CPU-time and placement envelope

ThreadControlGrant / SpawnGrant:
  separate control and creation authority
```

Linux may choose policy among eligible leases and batch same-Domain work. It
cannot create the root frame, provider entry receipt, hard timer budget,
Domain activation, MemoryView, or partition authority. The final protection
claim additionally depends on ENTRY/CODE/STATE/SVC/MGMT composition; scheduler
semantics alone remain a Linux-only prototype boundary.

## Completion Gates

```text
G0 external policy and scenario profile independently reviewed
G1 all D0-D17 modules structurally materialize with no pending blocker
G2 all W0-W12 witnesses and hostile architecture mutations execute
G3 fresh exact security/formal/scale/integration reviews have zero blocker
G4 architecture and machine semantics freeze as one captured bundle
G5 every mandatory generated local proof obligation is discharged; any
   counterexample or failure reopens the semantic freeze
G6 frozen IR translates to decomposed TLA+ without semantic invention
G7 safe models and targeted unsafe mutants produce the required results
G8 claim-specific Evidence Capsule and external decision bind all bytes
```

Only G8 can change `RESIDENCY-DYN-001` from Open to Model-supported. Later
ENTRY/CODE/STATE/SVC/MGMT/CLUSTER composition is still required for the full
DomainLease-H protection claim.
