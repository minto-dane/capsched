# Analysis 0192: Dynamic Residency Pre-Formal Two-Lane Witness

Status: structured executable architecture witness candidate; strict validator
with 322 targeted hostile mutations and 8,119 malformed type/container
replacements passes; fresh independent review pending; not a proof or semantic
freeze

Date: 2026-08-09

Work record: N-179

Requirement: `RESIDENCY-DYN-001`

Machine witness:
`analysis/dynamic-residency-preformal-two-lane-witness-v1.json`

## Question

Can the candidate architecture explain two live recurring lanes, disjoint and
intersecting control work, partial local apply, plan retirement, scoped failure,
exclusive transfer, and hostile namespace wear without silently introducing a
global barrier, ownerless capacity, Linux authority, or an unbounded operation?

This witness is deliberately earlier than TLA+. Its job is to make state
ownership, arithmetic, and action order executable before formal syntax
hardens them. Every scenario carries structured machine input and an exact set
of checks that the validator must actually evaluate; narrative labels are not
evidence. It still does not explore a state graph, establish induction, prove
fairness, authenticate a reviewer, or close a single review finding.

## Topology

```text
stream A -> plan A -> lane A -> control A -> scope/audit A
stream B -> plan B -> lane B -> control B -> scope/audit B

shared but partitioned Monitor facilities:
  one physical CPU execution parent with separately owned A/B cells
  one physical protected service parent with separately owned A/B slots
  one boot-sealed NodeConfig and bounded Domain hierarchy
  namespace publication ledger
  normalized lease timebase and independent watchdog timebase
  management/recovery root
```

The witness fixes one root-execution and protected-service opportunity epoch,
two lane, control, and target-control epochs, one lease epoch, `KDepth=3`,
`KTransitionShards=2`, `KFailureScopesPerEvent=1`, two security scopes per use,
two live reverse edges per scope, four failure-closure iterations, six closure
scopes, eight closure edges, six cover-ancestor cleanup units, and at most two
replicas per Domain. These are boot-sealed witness bounds, not proposed
production limits.
The serialized witness also fixes `KProofBytes=4096`, `KVectorBytes=2048`, and
`KMutationFootprintEntries=16`, so boundedness cannot disappear between prose
and machine input.

## Ownership Test

Each mutable object has one writer:

| Object | Sole writer | Important prohibition |
| --- | --- | --- |
| lane state and ApplyCell | exact lane apply owner | Linux, failure owner, audit, and the other lane do not write it |
| transition record | control commit | local apply cannot mutate or roll it back |
| EntryFailClosedFence | exact lane apply owner | failure owner may publish SecurityScopeFence but cannot settle apply |
| SecurityScopeFence | exact failure-scope owner | apply may reference but never advance it |
| apply escrow reclaim | exact capacity owner | local apply and preterminal cleanup cannot release it |
| retiring reservation | root reservation component | new-plan apply cannot reclaim it early |
| SourceReplayCell | exact source owner | transaction, scope, and audit owners cannot write replay/high-water |
| ScopeTransitionTxn/outbox/retire receipt | transaction owner | source, scope, and audit owners cannot write its decision |
| ScopeAuthorityCell | exact scope owner | transaction commit is read through EffectiveScope, not written into current |
| audit state/receipt | exact audit-shard owner | root service and failure authority never wait on or write it |
| CheckpointAggregate | derived observation | no authority action writes or gates on it |
| source placement receipt | source quiescence component | destination cannot manufacture it |
| CalendarTransferRecord/StoppedFailed | transfer owner | source/destination lane cannot rewrite the result |
| namespace ledger | namespace allocator | settlement cannot refund finite publication wear |
| NodeConfig | protected boot root | admission and ordinary management cannot enlarge it |
| hierarchy certificate | exact hierarchy commit owner | parent/child Linux cannot reparent or alter ancestor capacity |
| hardware schedule and immutable ExecutionCellLease | root execution capacity owner | lanes cannot mint, mutate, double-spend, or insert a future intent into a parent cell |
| ExecutionCellUseCell | exact physical-context activation shard | only this cell can bind the later intent digest and advance the one-use state |
| TargetControlTurn | exact target microstep dispatch | shard or peer target cannot advance it |
| imported lease/global placement | authenticated issuer/quorum | node-local narrowing and Linux cannot mint it |
| normalized authority horizon vector | protected deadline normalizer | raw values from unrelated clocks cannot be minimized |
| independent watchdog | independent hardware watchdog | Linux and the lease-clock owner cannot reset its epoch or turn |
| failure closure snapshot and cover | protected ownership-graph owner | source and Linux cannot choose, truncate, or stop the closure before its least fixed point |
| ActivationIntent | exact lane preparation owner | execution-cell state machine, residency worker, and Linux cannot make it executable |
| ActivationDecisionCell | exact physical-context activation shard | cancel, retry, entry component, and Linux cannot create a shadow winner |
| DeliverySettlementCell | exact physical-context activation shard | Domain and stream accounting cannot recount budget, resume, receipt, or service |
| context/activation receipt | exact physical-context activation shard | no component alone can mark service |
| management bootstrap | protected boot root | ordinary authority cannot debit or replace it |

The shared execution and protected-control frames are conserved mechanisms, not shared
authority state. A component may read another component's sealed result, but
that does not grant it write ownership.

## Witness 1: Hierarchy Bounds (`WIT-HIERARCHY-BOUNDS`)

`NodeConfig` fixes `KDepth=3`. A process leaf and a container leaf bind exact
node/tenant/leaf paths. Tenant A preserves:

```text
reservation 6 = current 3 + pending 1 + retiring 1 + failure escrow 1
```

Publishing A then B or B then A preserves every ancestor equation. A fourth
parent is `TooWide`; demand 7 is `NoParentCapacity`, both before publication.
Reparenting requires an old-path fence and zero-use receipts. A flat Domain is
the same rule with path depth one.

## Witness 2: Root Execution Capacity (`WIT-ROOT-EXECUTION-CAPACITY`)

One shared hardware root and its Domain-execution subframe are:

```text
Hardware 16 = protected control 4 + Domain execution 8
            + management 1 + emergency 1 + slack 2
Execution 8 = management 1 + emergency 1 + A 3 + B 2 + slack 1
```

The allocator issues immutable leases and allocator-created `ActivationSlotID`s
only for occurrences already charged to the lane through this root. A lease
contains no future intent identity. For example, `lease_A1=[100,110)` has guard
2, token budget 7, and unused budget 1. The exact physical-context activation
shard later reserves the separate use cell and binds the prepared intent digest
before tick 100, but cannot consume the occurrence early. That same shard alone
moves the use cell through
`Unbound -> Reserved -> Consumed -> Settled`, or to `Expired`. Token intervals
on the same physical context do not overlap. An expired occurrence at
`[120,130)` cannot fund a retry; the retry uses a fresh allocator slot and
distinct physical occurrence in `[130,140)`.
The executable checks recompute both partition sums, every cell budget,
issuance/preparation order, one-way state, unique occurrence, active-owner
exclusion, authority horizon, and no-carry rule.

## Witness 3: Target Control Conservation (`WIT-TARGET-CONTROL-CONSERVATION`)

From `ControlTurn=10`, `TargetA=4`, and `TargetB=7`, one A microstep yields
`11,5,7`; the next B microstep yields `12,5,8`. Every step satisfies:

```text
sum delta TargetControlTurn <= delta ControlTurn <= 1
```

A terminal or failed A microstep releases its schedule cell without advancing
B. Neither a pre-anchor shard turn nor A's target turn pays B's quota.

## Witness 4: Partition Import (`WIT-PARTITION-IMPORT`)

The imported issuer interval maps to earliest safe local expiry 180 and latest
possible predecessor horizon 188. Disconnection occurs at 160 with offline
limit 20. `CONNECTED_ONLY` blocks release/activation immediately and stops;
`CONTINUE_TO_CONSERVATIVE_EXPIRY` stops at `min(180,160+20)=180`;
`RECOVERY_ONLY` permits only bootstrap-listed recovery actions. No path changes
mode, resets offline time, or extends the term. Reconnection imports a fresh
generation and never reopens an old frozen use.

## Witness 5: Global Placement Supersession (`WIT-GLOBAL-PLACEMENT-SUPERSESSION`)

Source use `(epoch 7, fence 41, node A)` may be replaced by `(8,42,node B)` in
two ways. Exact source quiescence at 204 authorizes the successor directly.
For new authority, each of frozen lease, imported lease, global placement,
security use, retirement fence, execution cell, and root budget carries its
own source clock, source epoch, conversion certificate, and conservative
`not_after` in target `LeaseClockEpoch=1`. Only after that conversion does the
witness minimize 260, 250, 220, 240, 230, 225, and 224, yielding 220. Raw
cross-clock integer minimum is forbidden. Extending only the lease to 300 still
rejects release at 221; a fresh globally fenced placement is required.

If the source is unreachable, bounded residual effects end at CPU 220, queue
226, and DMA 228. Uncertainty 5 and independent stop bound 3 require
`activationNotBefore=237`, strictly after 236. An unbounded firmware effect
cannot be superseded by time at all and requires exact source quiescence.
Network silence and local `PlacementGeneration` authorize nothing.
Reconnection rejects the predecessor use.

## Witness 6: Failure Cover and Cleanup (`WIT-FAILURE-COVER-AND-CLEANUP`)

The boot-fixed cover tree has unique parents. A publication fence captures
reverse-index high-water 9. The seed `{child_A1}` under source generation 7 and
current generation 10 reaches use U8 and `child_A2`, then U9 and `child_A3`,
then a repeated stable state. The executable trace must equal this monotonic
least fixed point exactly; a use published after the fence is excluded and
cannot race into the snapshot. With `KFailureScopesPerEvent=1`, the three-scope
result selects unique LCA `tenant_A`; a union spanning A and B has root LCA and
therefore consumes the pre-reserved node fail-stop path.

At semantic commit, capacity
`current 3 + pending 2 + retiring 1 + escrow 0` becomes
`0 + 0 + 0 + escrow 6` before the fence takes effect. Only terminal cleanup
releases those six units. Each affected leaf charges two reverse edges, and
both `tenant_A` and `node_root` hold the exact aggregate cleanup reservation 6.
The checks reject early fixed-point termination, post-fence publication,
omitted topology generations, duplicated current/escrow capacity, ancestor
undercharge, truncation, reject-and-continue, and population scans.

## Witness 7: Joint Activation (`WIT-JOINT-ACTIVATION`)

A held binding plus allocator-issued slot/lease creates non-executable intent I;
only the use cell binds I's digest after lease issuance.
View, code, entry, translation, backing, mutable-state, and device classes are
all accounted for; a truly unused device class has typed `NotApplicable`.
At the due cell, one canonical `ActivationDecisionCell` serializes cancel,
prepare, entry, stop, and settlement. The action consumes the use cell, installs
inert context E, and derives an ID over the complete Domain/plan/lane/stream
opportunity root plus boot, projection, CPU incarnation, physical context,
root allocation, slot, lease issuance, activation generation, and intent
generation/digest. The one-use valid entry gate then activates the context. A
pre-gate crash remains `PreparedInert`, consumes no entry permit, executes
nothing, and can only recover that same ID in the same cell and boot epoch.

The activation receipt maps the lifecycle only to `ActivatedUnserved`.
`DeliverySettlementCell` alone records the monotonic resume sequence, checked
execution segments, remaining budget, deterministic delivery receipt, and
idempotent service key. Positive delivered ticks move it to `Served`; zero ticks without authenticated
post-entry yield do not. A monitor-authenticated post-entry voluntary yield
does count as an offered opportunity relinquished by the Domain. Removing the
code receipt expires the due use cell, leaves no executable state or token, and
requires a fresh activation slot for retry while the canonical decision remains
`Undecided`. Settled, expired, and cell-ended tokens cannot re-enter. The
validator recomputes full-parent ID derivation,
receipt completeness, budget/cell/horizon limits, retry bijection, crash cuts,
and both service branches.

## Witness 8: Management Bootstrap (`WIT-MANAGEMENT-BOOTSTRAP`)

Boot reserves management execution, control, namespace, audit, failure, and
cleanup resources before ordinary admission. An ordinary borrower is rejected;
the management cell performs reconciliation using the same complete joint
activation rule. Failure of its clock or immutable code root commits node
fail-stop and withdraws recovery liveness. It never falls back to Linux.

## Witness 9: Disjoint Commit Diamond (`WIT-DISJOINT-COMMIT`)

Precondition: operations A and B have disjoint full mutation/read/resource
footprints, both are selected and feasible, and both local successors are
independently applicable.

```text
left:   reserve A -> commit A -> reserve B -> commit B -> apply A -> apply B
right:  reserve B -> commit B -> reserve A -> commit A -> apply B -> apply A
```

Both paths must have the same authority projection, capacity owners, and
per-lane membership. A normal ledger suffix or unrelated audit checkpoint may
occur between prepare and commit without staling the other operation. This
witness fails if either path needs node-wide snapshot equality, a cross-lane
lock wait, or lets an overlapping peer overtake an already selected logical
intent.

## Witness 10: Parent Service Capacity (`WIT-PARENT-SERVICE-CAPACITY`)

Both control shards are live below one physical service parent:

```text
FrameLength 8
  = Emergency 1 + Management 1 + LocalProtected 1
  + A child slots 2 + B child slots 2 + Slack 1
```

The immutable schedule contains exactly two A and two B occurrences. Four
physical opportunities advance `A, B, A, B`; no opportunity advances two
children, and each resulting shard turn advances at most one exact
`TargetControlTurn`. Both leaf certificates debit this same parent equation
simultaneously. Lane A may be held while B's owned occurrences continue. Each
target's lane/control quota starts from its own fresh anchor, so turns before
selection provide no credit. This rejects independent leaf-rate certificates,
nominal-rate-only proofs, reusable shard-turn credit, and any hardware
certificate that assumes Monitor control fairness.

## Witness 11: Independent Recurring Progress (`WIT-INDEPENDENT-PROGRESS`)

Lane A begins with an active token or trusted cleanup countdown. Lane B has a
stable due opportunity and a valid clock/control quota.

```text
hold A boundary
  -> B target-control turn
  -> B opportunity
  -> B exact held binding
  -> non-executable ActivationIntent(B)
  -> joint ActivateHeld(B) and ActivationCommitReceipt(B)
  -> qualifying ExecutionDeliveryReceipt(B)
  -> B terminal settlement
  -> eventually finish A countdown
```

B's rank contains no A token, reference, cleanup, audit, or boundary state.
The parent schedule already reserves B root service and all safety cleanup.
This rejects a global lane barrier, one strict FIFO, and any Linux callback as
an activation gate. Its finite rank is executed, but induction over arbitrary
recurrence remains a later formal obligation.

## Witness 12: Mixed Apply Failure (`WIT-MIXED-APPLY-FAILURE`)

One committed transition has entries A and B. Its exact component escrow is:

```text
Capacity 16 = Base 5 + Escrow A 4 + Escrow B 6 + Slack 1

left:
  ApplyOwner A -> Applied
  ScopeOwner B -> SecurityScopeFence B
  ApplyOwner B -> EntryFailClosedFence B + FailedFenced

right:
  ScopeOwner B -> SecurityScopeFence B
  ApplyOwner B -> EntryFailClosedFence B + FailedFenced
  ApplyOwner A -> Applied

therefore:
  A successor authority is exact
  B successor authority never appears
  A demand 3 + residual 1; B cleanup demand 6
  total capacity remains 16 until capacity-owner reclaim
```

The certificate uses owner-partitioned writes, typed mutable reads, component-
wise maximum escrow, and a sparse aggregate fold. It has no pairwise
commutation or `2^k` subset proof. The failure owner never writes apply status;
the apply owner never advances `SecurityScopeFence`. The executable model must
later establish the single-entry induction for every mixed status vector.

## Witness 13: Retiring Opportunity (`WIT-RETIRING-OPPORTUNITY`)

An old opportunity is released before cutover. Cutover advances its live
retirement fence and names that one opportunity as preserved.

Two legal orders exist:

```text
cutover -> validate live preservation -> activate old -> settle old
intent and joint activation -> cutover constrains existing token -> settle old
```

The opportunity's release-observed fence generation is historical evidence,
not an equality guard. Any newly issued token binds the then-current fence.
`RetiringOpportunityReservation` keeps exact root service until terminal and
is only then released. The old membership cannot release another opportunity.

## Witness 14: Scoped Failure Crash Matrix (`WIT-SCOPED-FAILURE-CRASH`)

A fresh authenticated source-A event first lets the source owner persist a
self-contained `DurablePending` naming a precharged slot; only afterward does
the distinct transaction owner allocate and link the transaction. Crash before
that link enters `RecoveryOnly` and reconstructs it without source
retransmission. Reservation
and preparation leave `EffectiveScope(A)` at its predecessor. One transaction-
owner decision makes every prepared successor effective at once; crash before
materialization cannot reopen it.

```text
PersistPending A
  -> [crash/recover] BuildTxn A
  -> Reserve/Seal/Prepare scope A
  -> [crash] CommitTxn A
  -> EffectiveScope A is fenced before materialization
  -> B release/ActivationCommitReceipt/ExecutionDeliveryReceipt/terminal remains unchanged
  -> Materialize A -> FinalizeSource A
  -> AuditReserve A -> [crash/retry same position] AuditCommit A
```

Source high-water advances only after commit. Every authority consumer reads
`EffectiveScope`; audit append, checkpoint, and derived summary are observation
only. Lane B excludes scope A and its source-health scope, so B keeps the same
bound. Ordinary restart is forbidden while pending ingress or an unmapped old-
boot fence remains.

## Witness 15: Source Exhaustion (`WIT-SOURCE-EXHAUSTION`)

Stream A's immutable dependency certificate includes `source_health_A`.
Sequence exhaustion or same-identity/different-digest equivocation consumes a
pre-reserved emergency transaction whose identity is outside the exhausted
namespace and commits permanent `SourceUnavailableFence(A)`. A's old token is
non-executable. Stream B continues only because its independently authenticated
coverage alternative was selected before its live use. Neither stream may
choose a new alternative after observing failure.

## Witness 16: Exclusive Transfer (`WIT-EXCLUSIVE-TRANSFER`)

Prevalidation reserves destination capacity and proves a maximum-gap envelope,
but cannot freeze the live source calendar. If the source has an open current
opportunity, it must first settle, or a maintenance skip must have been committed
before its due boundary.

```text
CurrentOpportunity(source) = None
  -> source release gate and monotonic retirement fence
  -> trusted source stop and drain
  -> boundary-final source quiescence receipt
  -> destination calendar derived only from receipt
  -> fresh future destination commit
  -> destination authority publication
```

The source write-close receipt proves zero active tokens, zero active contexts,
zero unsettled delivery cells, and terminal prior settlements. Source epoch 3
and destination epoch 5 are not numerically comparable. An authenticated
`ClockRelationCertificate` maps source last-delivery and stop events to bounded
destination-clock intervals. There is an explicit safe stopped gap and never
authority overlap. A destination lane boundary never waits for the source.
Workloads that cannot tolerate the stopped interval require a separately
admitted alternate-service contract.

The exact arithmetic instance is:

```text
ServiceCalendar(baseOrdinal=40, baseTick=1000, period=20)
precommitted skip: ordinal 43, debt 7 -> nextOrdinal 44, debt 11
DueTick(44)=1080, DueEndTick(44)=1100
source tick: last delivery=1040, stop=1052, LeaseClockEpoch=3
destination intervals: last delivery=[1038,1042], stop=[1050,1054]
destination LeaseClockEpoch=5
destination current turn=70, preparation lead=1, Cell(44)=74
releaseU=1082, activateU=1084, firstDeliveryU=1086, terminalU=1092
authorized envelope=[1055,1090), authority expiry=1120
worstGapU=1086-1038=48 <= 50, rankUpper=6 <= 8
```

Thus the destination cannot choose an arbitrary cell, activate before due tick,
compare source and destination ticks or lane turns directly, or create a skip
after quiescence. Activation is strictly after the latest converted source stop
1054. The service gap uses the earliest possible converted last delivery 1038,
never source stop or a naked cross-epoch subtraction. Every rejection after
source fencing leaves a safe stopped state.

## Witness 17: Namespace Wear and Conflict Churn (`WIT-NAMESPACE-WEAR-AND-SPARSE-CONTROL`)

Best-effort sponsor headroom is exhausted while a guaranteed control operation
is selected. Its exact footprint receives a logical conflict-intent
reservation. Many admitted principal slots are empty, but only occupied slots
are linked in the protected sparse ring.

```text
best-effort publications
  -> consume only sponsor wear
  -> bounded reject at sponsor limit

selected guaranteed operation
  -> O(1) cursor successor among occupied principals
  -> cannot be overtaken by overlap
  -> commits from guaranteed headroom
```

Publication wear never returns on settlement. Best-effort cannot consume
management, guaranteed, or renewal headroom, force another sponsor's namespace
rotation, or trigger a fresh boot. Shared renewal affecting a peer requires a
precommitted peer maintenance/failover witness. Empty principal IDs are never
scanned, and a new insertion cannot move the cursor behind an older
continuously occupied member.

## Witness 18: Clock Progress or Fail-Stop (`WIT-CLOCK-PROGRESS-OR-FAILSTOP`)

The progress branch advances lease ticks `100 -> 101 -> 102` and independent
watchdog turns `500 -> 501 -> 502`, then fires expiry at the half-open boundary.
The hostile branch holds lease tick at `200,200,200` while the distinct watchdog
source advances `700 -> 701 -> 702`. At delta 2 it commits the time-scope fence
and node fail-stop, then withdraws time-bounded liveness. Linux and the
lease-clock owner cannot reset the watchdog epoch or turn. There is no branch
where both clocks stutter while an expiry, maximum-gap, or stop claim remains.

## Witness 19: Prefix or Continuity Loss (`WIT-SETTLEMENT-PREFIX-OR-CONTINUITY-LOSS`)

After source loss, a quorum may preserve stream incarnation 9 only after
predecessor write-close position 90 and its no-later-delivery fence, a strictly
later quorum checkpoint at 95, and prefix publication at 96. The exact prefix
seals settled ordinal 43, next ordinal 44, debt 11, last delivery receipt/tick,
and every open-ordinal disposition. An authenticated interval relation converts
predecessor clock epoch 31 into successor epoch 44; the worst-case gap is
checked from the interval's earliest possible converted delivery, never by
subtracting unrelated raw ticks. Without the certificate, recovery publishes
`ContinuityLossRecord(9 -> 10)`, makes the uncertain old range nonservice, and
withdraws exactly-once and maximum-gap claims. Placement quorum or a prefix
predating write-close cannot reconstruct volatile settlement state.

## Witness 20: Lifecycle and Writer Refinement (`WIT-LIFECYCLE-WRITER-REFINEMENT`)

The service path executes:

```text
Released -> Preparing -> HeldReady -> ActivationIntentPending
  -> ActivatedUnserved -> Served -> StopPending -> Settling -> Terminal
```

The pre-activation suppression path goes from `ActivationIntentPending` to
`SuppressedBeforeActivation`, then settles. Human `Activated` maps to exactly
`ActivatedUnserved` or `Served`; it cannot erase their service distinction.
Every machine state has a human image, terminal is absorbing, and all executed
edges belong to the declared graph. A separate writer trace requires
source-owned `DurablePending` before transaction-owner allocation and linking;
neither owner writes the other's object.

## Rely/Guarantee Boundary

External relies are limited to the exact hardware-progress certificate, typed
`NodeLeaseImportCertificate`/`GlobalPlacementUse` producer contracts, target
`StableWindow`, finite external countdown/receipt contracts, the boot-root
bootstrap import or its fail-stop result, protected `LeaseTick` progress or an
independent watchdog fail-stop, quorum no-fork/prefix authenticity, and audit
headroom for this finite interval.

Parent service allocation, parent physical execution allocation, target
microstep scheduling, target quota, lane boundary, joint activation, failure
cover, cleanup, and management reservation are Monitor-internal obligations.
This witness executes one bounded instance of their arithmetic and ranks. The
later TLA+ models must establish invariants and temporal refinement over all
reachable bounded states; neither layer assumes their fairness by label.

It does not rely on Linux fairness, target-picker fairness, network silence as
quiescence, simultaneous lane boundaries, a global barrier, or infinite audit
storage. Those omissions are essential: assuming any one would describe a less
hostile system than the project requires.

## Coverage and Limits

The machine witness retains the complete second-round partition, names all 33
third-round reviewer/self-audit findings, and maps all eight datacenter/
composition findings to concrete scenarios. It also maps all 16 fourth-round
architecture findings to executable checks across 20 scenarios. The validator
must enumerate every executed check and reject a missing machine payload;
labels alone cannot pass. Assurance findings remain owned by the revised
external protocol. No scenario may authenticate its own reviewer, close a
finding, or freeze the candidate.

The witness still cannot establish:

```text
inductive safety for arbitrary interleavings
general numeric activation or terminal bounds beyond these finite instances
infinite recurring liveness
namespace non-aliasing across every renewal
crash consistency at every persisted machine instruction
physical memory-view, entry, code, DMA, or device isolation
Linux or Monitor implementation refinement
performance, cost, or multi-cluster behavior
```

Those are later formal, architecture-component, implementation, and evidence
obligations. A fresh hostile review may reject or alter this witness; it is not
allowed to mark its own architecture consistent.
