# Analysis 0200: Dynamic Residency R6 Successor Semantic Architecture

Status: rejected successor candidate; exact R6 v2 snapshot is a regression target

Date: 2026-08-09

Work record: `N-188`

Requirement: `RESIDENCY-DYN-001`

Post-review disposition: four independent hostile reviews returned
`FREEZE_NO`. The reviewed machine contract
`24887ac27772dc131b91a7f87ff57203ab71cf883ff2769fc0df40bb941fa62d`
and overlay
`468cd739f64a44b1887c6f40eebb6bf8f466542d498e72457254e8dbe753bda1`
are preserved without rehabilitation. Analysis 0203 records the blockers.

## Lineage And Scope

This document is the architecture-first response to Analysis 0199. It does not
edit or reinterpret the rejected candidate:

```text
rejected candidate object set:
  24bb1320d3f50a10195d18e899d7101d7f422ca6ed18c5bedfb088ff4bdc174f

base machine contract raw SHA-256:
  015838a03f7967522d4998bf05b93fa70153bc14c3800a0fd300804574e5901f

base human contract raw SHA-256:
  6dc76cefa80e138c8815f9269790b0ac58dfb6c5c3cafd442a6b09f3fc857382
```

The rejected bytes remain a regression target. A successor machine contract
will inherit all unaffected v1 clauses and explicitly replace every semantic
locus named here. Until that materialized contract, its executable witness,
and fresh reviews agree, this document is a design candidate only.

The threat model is unchanged. Domain-local Linux, its scheduler, its mutable
kernel state, and all transport it controls are adversarial. Only protected
Monitor/hardware state and explicitly named external cryptographic, cluster,
time, ENTRY, CODE, STATE, and device interfaces may contribute authority.

## Non-Negotiable Design Rules

1. Authority construction is acyclic. No object authenticates a final object
   that is required to construct the first object.
2. Every mutable decision has one complete key, one protected writer, and one
   monotonic state owner. Retry creates an attempt, never another decision.
3. Linux-visible labels, booleans, object addresses, strings, and transport
   success are observations only. They cannot become authority evidence.
4. A valid due action has deterministic priority. The Monitor cannot choose a
   harmless-looking expiry branch to avoid a liveness obligation.
5. Internal fail-stop preserves safety but is not successful service and does
   not discharge liveness unless a named external rely was objectively broken.
6. Every scan, retry, log, proof, dependency set, calendar horizon, and cleanup
   path is boot-bounded or admission-charged. Overflow before authority
   publication rejects; overflow after publication consumes a pre-reserved
   fail-stop path.
7. Process-granular and container-granular Domains use the same object algebra.
   Granularity changes counts and cost, never the security meaning of a tag.

## Canonical Identity Algebra

String concatenation is not an identity function. The successor uses an
injective typed term algebra in formal models, a reversible canonical key at
storage/transport boundaries, and a separate payload digest:

```text
CanonicalKeyBytesV1 =
  deterministic-CBOR([
    schema-version,
    object-type-tag,
    [[field-tag, field-type-tag, field-value], ... in schema order]
  ])

CID =
  "lcid1:" + base64url-no-pad(CanonicalKeyBytesV1)

PayloadDigest =
  SHA-256(
    "DomainLease-Linux/PayloadDigest/v1" ||
    u64be(byte-length(NFC-UTF8(object-type-tag))) ||
    NFC-UTF8(object-type-tag) ||
    u64be(byte-length(CanonicalPayloadBytesV1)) ||
    CanonicalPayloadBytesV1)

digest text grammar =
  "sha256:" followed by exactly 64 lowercase hexadecimal digits
```

Definite-length arrays, bounded unsigned integers, booleans, byte strings, and
NFC UTF-8 text are permitted. Floats, indefinite encodings, integer wrap,
unknown, duplicate, reordered, missing, or extra fields reject. A CID must
decode and re-encode byte-identically. Authority equality compares the decoded
structural key and the recomputed payload digest; a hash is never claimed to be
mathematically injective. Same CID with different payload digest is
equivocation. Same digest with different CID is a cryptographic fault, never
identity equality. Formal models use the structural key constructor rather
than either text form. Cryptographic collision resistance and correct canonical
encoding remain explicit external relies.

Every key field is encoded as the exact triple `[field-tag, type-tag, value]`;
the closed type-tag vocabulary is `uint`, `bool`, `bytes`, `text`, and
schema-declared definite `array`. `CanonicalPayloadBytesV1` uses the same
schema-ordered triples for payload fields. Both 64-bit length prefixes reject
overflow, and the boot-fixed object-size bound rejects before hashing or
authority publication. These transcript bytes are part of the semantic
interoperability contract, not an implementation convenience.

`CurrentOpportunityID` is the reversible CID of the complete opportunity
tuple, including cluster/issuer lineage, NodeConfig and Monitor boot roots,
Domain hierarchy and epoch, admission snapshot, plan/shard/lane membership,
service stream and incarnation, opportunity sequence, parent calendar
reservation, and boot-fixed activation-shard-map generation. An indirect parent
reference is accepted only when its CID, schema, payload digest, and transitive
object are present in the sealed candidate or protected registry.

Attempt-local identities are subordinate:

```text
ActivationAttemptID = CID(
  CurrentOpportunityID,
  AttemptOrdinal)

ActivationID = CID(
  CurrentOpportunityID,
  successful ActivationAttemptID,
  ExecutionCellLeaseCoreID,
  ExecutionCellLeaseID,
  ActivationIntentID,
  ExecutionContextKeyID,
  EntryCommitRecordID,
  exact hardware context incarnation,
  protected entry generation)
```

Neither identity is a key for a second opportunity decision cell.

## Acyclic Authority Construction

The exact construction order is:

| Stage | Object | May bind | Must not bind |
| --- | --- | --- | --- |
| 0 | `OpportunityReservation` and `ActivationDecisionCell` | complete opportunity key, stable activation shard, attempt/work bounds | attempt-local CPU, lease, intent, permit, receipt, token |
| 1 | `ActivationAttemptID` and `ExecutionCellLeaseCore` | opportunity, ordinal, exact parent capacity occurrence, physical context, cell interval, budget ceiling | authority vector, intent, permit, receipt, token |
| 2 | source authority cores | exact issuer/owner object and protected generation | final execution lease or activation artifacts |
| 3 | `NormalizedAuthorityHorizonVector` | the lease core and every other required source-core projection | final `ExecutionCellLease`, future receipt, token |
| 4 | `ExecutionCellLease` and use cell | exact lease core and complete vector | intent, decision result, permit, receipt, token |
| 5 | `ActivationIntent` and `ExecutionContextCore` | opportunity, held binding, final lease, expected context and receipt profile | receipt-derived context key, executable state, token |
| 6 | ENTRY/CODE/STATE/device receipts | exact context core and protected physical observations | final context key or later entry result |
| 7 | `ExecutionContextKey` | exact context core plus the complete receipt ID/digest set | permit, commit receipt, token |
| 8 | `ActivationAttemptRecord` and `PreEntryPermit` | prepared attempt, final context key, current horizons, one cell and gate generation | future commit receipt or RunToken |
| 9 | protected entry transaction | consumes permit and installs the exact active context | Linux-selected post-entry state |
| 10 | `EntryCommitRecord` and `ActivationCommitReceipt` | completed hardware gate, context, budget/stop state, receipt-set root | RunToken digest |
| 11 | `DeliverySettlementCell` | receipt, active owner, resume and budget state | RunToken digest |
| 12 | `RunToken` | exact commit receipt, settlement cell, and all active-context authority | future delivery receipt |
| 13 | `ExecutionDeliveryReceipt` and terminal cell | exact receipt, token, measured execution interval and settlement | a later opportunity |

The opportunity reservation and its sole decision cell are allocated in the
same protected publication transaction before `CurrentOpportunity` becomes
visible. The stable activation shard is derived from the complete opportunity
key and a boot-fixed shard-map generation. A retry on another CPU does not
change that writer. Cross-shard ownership transfer is forbidden until a
separate transfer protocol is modeled.

`ExecutionCellLeaseCore` is immutable and has this minimum schema:

```text
LeaseCoreID and LeaseCoreGeneration
CurrentOpportunityID
HardwareCapacityRootCertificateID and RootExecutionAllocationCertificateID
PhysicalOccurrenceID and exact physical-context/CpuIncarnation
RootExecutionClockEpoch, turn, frame ordinal, and cell ordinal
half-open cell start and end
positive maximum entry/exit guard and execution budget
allocator identity, issuance sequence, and seal
```

The horizon vector authenticates a projection of that core. It explicitly
excludes the final lease ID/digest. The final lease seals `(LeaseCoreID,
LeaseCoreDigest, HorizonVectorID, HorizonVectorDigest, policy profile)`. This
removes the former lease/vector recursion.

## One Opportunity, One Decision

There is exactly one `ActivationDecisionCell` indexed by the complete
`CurrentOpportunityID`. Its physical lookup namespace also includes the
enclosing Monitor boot and opportunity namespace roots, but these are already
members of the canonical identity. Intent, lease, slot, and attempt values are
fields inside the cell and can never select another cell.

Minimum fields are:

```text
CurrentOpportunityID and exact opportunity digest
single protected ActivationShard writer and boot-fixed shard-map generation
phase
MaxActivationAttempts and nextAttemptOrdinal
immutable AttemptResult log root and activeAttemptID or None
successfulAttemptID or None
PreEntryPermitID or None
ActivationID, ActivationCommitReceiptID, and RunTokenID or None
DeliverySettlementCellID
monotonic activated and served bits
first terminal or stop cause
MonitorBootEpoch, due interval, and recovery rank
```

The phase lattice is:

```text
Open
  -> PreparedInert
  -> SuppressedBeforeEntry
  -> ExternalExpiredBeforeEntry
  -> InternalGuaranteeViolation

PreparedInert
  -> EnteredUnserved
  -> StopPending

EnteredUnserved
  -> StopPending
  -> Settling

StopPending
  -> Settling

Settling
  -> ServedTerminal
  -> UnservedTerminal
```

`Open -> Open` is allowed only as a monotonic append of one exact failed
attempt result with `nextAttemptOrdinal + 1`; it is not a state rollback.
Attempt ordinals never repeat. A failed attempt consumes or expires only its
own execution cell. It cannot erase a cancel/withdraw/revoke winner, change the
opportunity key, or mint an activation identity.

The high-level opportunity lifecycle is total over this cell:

| Opportunity state | Decision/settlement interpretation |
| --- | --- |
| `Released`, `Preparing`, `HeldReady`, `ActivationPending` | decision `Open`; residency and attempt substate select the exact refinement |
| `PreparedInert` | decision `PreparedInert`; no execution and no service |
| `EnteredUnserved` | decision `EnteredUnserved` plus valid commit receipt and active/stop-pending delivery cell |
| `StopPending` | decision `StopPending` |
| `Settling` | decision `Settling` |
| `Served` | one qualifying delivery receipt exists, before or at `ServedTerminal` |
| `SuppressedBeforeEntry` | same named terminal decision |
| `ExternalExpiredBeforeEntry` | same named terminal decision with typed external cause |
| `Terminal` | exactly one served or unserved terminal settlement |

Every lower state maps to exactly one high state. Recovery steps that only
materialize a committed record stutter at the high level. There is no lower
`PreparedInert` state hidden beneath high-level `ActivationPending`.

The total abstraction function applies a disjoint priority over contradictory
or partially materialized products: invalid product, terminal cell, cleanup,
stop, qualifying delivery, entry bundle, prepared permit, suppression,
attempt-pending, held, preparing, released. An invalid combination maps to
`InternalGuaranteeViolation` and forces stop if active; it never maps to
service or an external withdrawal. `served` is orthogonal and monotonic, so a
later stop cannot erase service and a pre-service stop cannot manufacture it.

## Attempt And Due-Cell Determinism

`MaxActivationAttempts` is a positive NodeConfig-bounded natural charged by
admission. Each attempt reserves its own future physical cell and protected
prepare/recovery work before it can become active. The lexicographic activation
rank includes:

```text
remaining attempt budget
distance to the active attempt's reserved cell
remaining protected prepare/recovery work
entry-guard steps
stop/settlement steps
```

The protected due-cell action is a total ordered function:

1. If the opportunity is already terminal, settle the cell unused.
2. If the exact prepared permit is current and every entry predicate is true,
   enter. Expiry is not an alternative enabled action.
3. Otherwise select the first false predicate from a fixed reason order and
   emit a typed `DueCellRejectionReceipt`.
4. Retry only when the reason is classified recoverable, the opportunity
   deadline and authority horizon cover another pre-reserved cell, and attempt
   budget remains.
5. An authenticated external invalidation may terminally expire the
   opportunity. Exhaustion caused only by internal failure enters
   `InternalGuaranteeViolation`; it preserves safety but falsifies the service
   theorem.

The fixed rejection order begins with stale Monitor boot/namespace, cancelled
or fenced opportunity, invalid cell identity, expired normalized horizon,
invalid ENTRY/CODE/STATE/device receipt, unavailable hardware context, and
insufficient guard budget. A caller cannot select a more convenient reason.

## Pre-Entry And Post-Entry Authority

`PreEntryPermit` is a one-use protected gate permit, not a RunToken. It binds:

```text
permit schema, generation, issuer, and seal epoch
CurrentOpportunityID and ActivationAttemptID
ActivationDecisionCell and exact PreparedInert generation
ActivationIntent, ExecutionCellLease, and ExecutionCellUseCell
complete ExecutionContextKey
RequiredActivationReceiptSet root
NormalizedAuthorityHorizonVector and half-open permit expiry
physical context/CpuIncarnation, due cell, budget, and stop-enforcement identity
expected protected entry generation
```

It authorizes only the atomic gate operation and cannot authorize ordinary
execution, interrupt return, resume, or migration. Linux may carry an opaque
reference but cannot inspect, alter, duplicate, or consume the protected permit
state.

The hardware gate atomically:

```text
revalidates and consumes the PreEntryPermit
confirms exact inert context and no active conflicting owner
installs MemoryView, code, stack/per-CPU state, translation, and device context
arms independent budget and stop enforcement
publishes the active hardware-owner generation
moves the decision to EnteredUnserved
creates one EntryCommitRecord and ActivationCommitReceipt
creates one active DeliverySettlementCell binding that receipt
creates one RunToken binding both already-derived objects
```

These objects become visible under one protected commit bit, but their internal
derivation remains ordered. Neither the commit receipt nor settlement cell
binds the future token. The token binds both already-created objects, so the
construction is acyclic. Initial entry uses the permit and protected hardware
state, never a RunToken that predates the gate.

The post-entry `RunToken` is an immutable sealed active-context authority root.
It is usable only with `ActiveContextExecutable`, which requires the exact
commit receipt, active hardware owner, current monotonic resume sequence,
positive remaining budget, unexpired cell/vector, and current hierarchy,
placement, security, retirement, failure, entry, code, state, translation, and
device generations. Interrupt return or resume increments a protected sequence;
replaying the token alone cannot reenter. Settlement or stop makes the token
permanently non-executable.

## Concrete Abstract Receipt Contract

`ExecutionContextCore` fixes the intended Domain, physical context, MemoryView,
code, entry stacks, mutable state, device profile, budget/stop profile, and
expected receipt inventory without containing a receipt or final context-key
digest. `RequiredActivationReceiptSet` then contains receipts over that core,
and `ExecutionContextKey` is derived from the core plus their exact IDs and
payload digests. This prevents a receipt/context-key construction cycle.

The receipt set has a fixed profile-selected class inventory. ENTRY, CODE,
STATE, MemoryView, and stop enforcement are never optional. Device isolation is
a protected tagged `PRESENT` or `ABSENT` receipt. A `NotApplicableReceipt` is
permitted only for policy-enumerated extension classes, never for those core
security classes. Common receipt envelope fields are:

```text
schema and class
protected issuer root, issuer identity/incarnation, key/seal epoch
CurrentOpportunityID, ActivationAttemptID, DomainKey/DomainEpoch
ExecutionContextCore and physical context/CpuIncarnation
exact source object IDs, generations, rights/projection digests
observed protected-state predicate and commit position
source clock epoch, observation interval, expiry, and clock relation
anti-rollback checkpoint/root and monotonic sequence
one-use or fence generation binding
canonical payload digest and authentication
```

Required classes and minimum semantics are:

| Receipt | Required protected assertion |
| --- | --- |
| `MemoryViewInstallReceipt` | target stage-2/EPT view, ownership-root, View/Backing/translation epochs, target hardware register state, and no executable predecessor translation |
| `CodeIntegrityReceipt` | exact executable root and CodeEpoch, W^X, no Domain-writable executable alias, and module/JIT policy identity |
| `EntryStateInstallReceipt` | Domain-owned stack, entry/exception/return and nested-entry generations, per-CPU state view, and predecessor context quiescence |
| `MutableStateBindingReceipt` | exact Domain-private mutable-state ownership set/epoch and explicitly shared typed buffers/endpoints |
| `DeviceIsolationReceipt` | `PRESENT` binds queue, firmware, IOMMU, PASID/ATS, IRQ-route, DMA MemoryView/reset generations, old-queue disable, and no live predecessor DMA reference; `ABSENT` binds a protected inventory snapshot proving no binding, mapping, or queue exists |
| `StopEnforcementReceipt` | independent timer/watchdog source, budget, cell/vector expiry, physical stop target, and pre-reserved fail-closed action |
| `NotApplicableReceipt` | only for an optional profile-enumerated extension class, with protected proof that its dependency set is empty for this exact core and an enumerated reason |

Nonempty strings, Linux-generated booleans, omitted classes, unknown reasons,
and stale receipts reject. The later ENTRY/CODE/STATE/device models must refine
these predicates to physical mechanisms. Until then, dynamic residency is an
interface-conditional scheduling result, not hypervisor-grade protection.

## Holder-Bound Delegation

`DelegationScope` is replaced by `DelegationGrant`. Its exact fields include:

```text
grant and parent-grant identity
issuer principal/key/epoch and grant generation
grantee DomainKey/principal and protected proof key or nontransferable handle
audience ControlEndpointID and channel-binding mode
capability mode: holder-bound transferable-chain or protected nontransferable
attenuation depth and complete parent-chain digest
authorized targets, operations, fields, resource delta, shards, and effects
not-before, commit-not-after, effect-not-after, and clock relation
revocation-root identity and per-grant revocation generation
operation-sequence namespace, challenge policy, and seal
```

Every delegated `ControlOp` carries a `HolderAuthorizationProof` over the exact
operation digest, grant, channel/audience, challenge, monotonic sequence, and
current revocation generation. The Monitor verifies the proof against a key or
handle protected by the grantee Domain's MemoryView. Linux forwarding a grant
or an old proof cannot authorize another Domain, audience, operation, sequence,
or generation. Child grants can only attenuate rights, horizons, targets,
resource delta, and depth.

Compromise of the grantee Domain permits use of authority deliberately held by
that Domain. It does not permit crossing to another Domain or amplifying the
grant. Protecting two principals inside one compromised Domain from one another
requires making them separate Domains; ordinary Linux credentials are not a
Monitor boundary.

## Publication-Fenced Failure Closure

Every executable authority use has one exact NodeConfig-bounded
`DependencyScopeSet`. Publication is a protected transaction, not independent
log appends:

1. Allocate a bounded `AuthorityPublicationTxn` and prepare a reservation in
   every dependency scope in canonical scope order.
2. A scope in `Closing` or `Closed` rejects the transaction before authority.
3. Persist the identical use ID/digest and reverse link in every scope.
4. Publish the transaction commit bit only after all links are durable.
5. Only a committed, completely linked use may become executable.
6. Crash before commit aborts or is completed from protected records; it never
   creates partially indexed authority.

Each `ScopePublicationGate` has one owner and states:

```text
Open
Closing(failureID, prepared-publication set)
Closed(failureID, drained high-water)
```

Failure closure starts with authenticated seed scopes and iterates:

1. CAS each frontier gate `Open -> Closing`.
2. Resolve every pre-close prepared publication: abort uncommitted
   transactions; include committed complete transactions.
3. After the prepared set drains, seal the scope's reverse-log high-water and
   move it to `Closed`.
4. Scan all entries through that high-water, fence each authority use, and add
   every dependency/topology scope named by those uses to the frontier.
5. Repeat until the frontier is empty and every discovered scope is closed.

Closure is complete only after a full pass adds no use, scope, or referenced
topology generation. Overlapping failures serialize at their first common
scope gate; disjoint closures commute. Recovery installs a successor scope
generation before reopening publication and can never reopen an old use.

This closes the race in which an A-to-B use reveals B only after an earlier
snapshot while a B-to-C use is published concurrently. Closing B drains or
includes that publication and therefore discovers C. No global publication
fence is required; a disjoint scope remains open.

`KFailureClosureScopes`, `KFailureClosureEdges`, per-scope prepared-publication
count, topology depth, reverse-log width, and cleanup cost are NodeConfig-bounded
and charged at admission to every potential cover ancestor. Bound exhaustion
after authority exists consumes a pre-reserved node fail-stop transition.
Truncation, reject-and-continue, population scan, and disjoint-lane stop are
forbidden.

## Placement, Connectivity, And Calendar Transfer

### Connectivity evidence

`CONNECTED_ONLY` consumes a one-use `ConnectivityFreshnessCertificate`, never
a boolean. It binds:

```text
protected channel/quorum issuer, key, incarnation, and anti-rollback root
NodeLease, GlobalPlacementUse, predecessor/successor nodes and resources
channel/session identity, challenge nonce, request/response transcript digest
monotonic channel sequence and issuer checkpoint
source observation interval and authenticated relation to LeaseClockEpoch
valid-not-after tick and maximum stale-authority horizon
exact ControlOp, placement transition, or activation use cell
```

The sequence and use cell make replay fail. Its conservative expiry is an entry
in the normalized authority horizon. It proves connectivity only for its
observation interval; a later partition remains safe because authority ends at
the pre-issued horizon. Indefinite disconnected authority is not claimed.

### Boundary certificate

`ServiceCalendar` has an issuer-owned `CalendarTimeDomainID/CalendarEpoch`. It
is not either node's lane clock or LeaseClock. Identity mapping is permitted
only for an exact same time-domain/epoch. Otherwise v2 requires one direct
authenticated `ClockRelationCertificate<source,destination>` bound to this
transfer; inferred transitive chains are rejected.

For source tick `x`, the relation returns a conservative target interval
`MapR(x) = [L(x), U(x))`. Expiry uses `L(expiry)`, safe destination not-before
uses `U(predecessorStop)`, and the worst-case gap uses
`U(firstSuccessorDelivery) - L(lastPredecessorDelivery)`. The relation binds
both complete clock identities, valid source and target intervals, monotonic
interval equations, uncertainty, producer/no-fork epoch, certificate expiry,
and exact transfer identity.

`CalendarBoundaryCertificateV2` is a tagged union normalized before destination
selection:

```text
SourceQuiesced(
  SourcePlacementQuiescenceReceipt,
  CalendarBoundaryState,
  ClockRelationCertificate)

QuorumSupersededStrongContinuity(
  predecessor write-close fence,
  QuorumSupersessionFence,
  later quorum checkpoint,
  replicated activation/settlement closure certificate,
  SettlementPrefixCertificate,
  CalendarBoundaryState,
  ClockRelationCertificate)

QuorumSupersededSafeGap(
  predecessor write-close fence,
  QuorumSupersessionFence,
  later quorum checkpoint,
  SettlementPrefixCertificate,
  bounded uncertain-suffix disposition,
  CalendarBoundaryState,
  ClockRelationCertificate)

ContinuityLost(
  QuorumSupersessionFence,
  ContinuityLossRecord,
  new ServiceStreamIncarnation)
```

The normalized `CalendarBoundaryState` fixes source stream/incarnation,
calendar, last committed and last delivered ordinals, next safe ordinal, debt,
last qualifying delivery and trusted-time interval, source stop/residual-effect
upper bound, write-close and settlement checkpoint, uncertain suffix, and
continuity class.

Its ownership cut is explicit: predecessor owns ordinals below `qCut` and the
successor may own ordinals at or above `qCut`. Strong continuity requires no
unresolved predecessor ordinal at or above that cut. Safe-gap transfer advances
`qCut` beyond every bounded ambiguous ordinal and records each non-service
disposition; it cannot skip to an unrecorded convenient destination ordinal.

Strong continuity is unavailable merely because a settlement prefix exists.
It additionally requires protected evidence that no activation or delivery is
unrepresented beyond the prefix. Without that evidence, the protocol advances
past the bounded uncertain suffix and records a service gap, or starts a new
stream incarnation. It never reuses an ambiguous ordinal. This deliberately
chooses no-overlap and no-duplicate authority over pretending that an
unreachable source's final state is known.

`CalendarTransferV2` accepts either same-epoch identity mapping or an
authenticated interval-valued `ClockRelationCertificate`. Cross-epoch numeric
subtraction is forbidden. It chooses the unique earliest destination reserved
cell satisfying all of:

```text
strictly after converted predecessor stop and every residual-effect upper bound
at or after the normalized next release interval and preparation lead
before the earliest destination authority/calendar expiry
within the admitted activation, delivery, terminal, and maximum-gap ranks
exact ordinal/debt/settlement/uncertain-suffix preservation
```

Missing or expired clock relation rejects continuity. It may lead only to an
explicit continuity-loss transition, never a naked conversion. Destination
activation binds the normalized boundary certificate and cannot occur before
its `activationNotBefore` upper-safety bound.

Exact service continuity across an unreachable source is impossible without
protected replicated activation/settlement closure. The architecture records
this as an interface/cost choice, not a fairness assumption.

## Collision-Free Guaranteed Calendars

A nominal release time is not itself a physical service cell. Admission and
renewal allocate an exact rolling finite calendar:

```text
GuaranteedOccurrenceReservation:
  ServiceOccurrenceID
  CurrentOpportunityID parent or future opportunity constructor
  nominal release interval and service deadline
  unique ReservedReleaseCellID
  unique RootExecution PhysicalOccurrenceID
  protected prepare, activation, delivery, and terminal work reservations
```

For guaranteed work, the maps from occurrences to release cells and from
activation attempts to root execution cells are injective within every parent
capacity certificate. Two streams may have the same nominal release tick only
when admission assigns distinct cells whose bounds both fit. Two occurrences
cannot own the same `(LaneClockEpoch, LaneTurn, CellOrdinal)`.

The finite calendar covers an exact `FreshnessHorizon`. Renewal atomically
proves and reserves the next horizon before the old one can release past its
boundary. Collision, insufficient cell capacity, insufficient retry work, or
insufficient terminal headroom rejects admission/renewal. Best-effort work may
use revocable slack but receives no guaranteed reservation or recurrence
claim.

This avoids an unbounded hyperperiod table. Calendar storage and checking are
bounded by admitted horizon entries and affected streams, while conditional
omega recurrence requires an explicit infinite sequence of successful finite
renewals and fresh namespace/authority supply.

## Canonical Protected Work Frame

The successor uses one structured nine-slot frame with two guaranteed-residency
service points. It intentionally places the second point at `PW6`, rather than
copying the rejected prose ordering, to minimize the maximum cyclic gap:

| Slot ID | Class |
| --- | --- |
| `PW0` | `SafetyCleanup` |
| `PW1` | `ManagementRecovery` |
| `PW2` | `GuaranteedResidency` |
| `PW3` | `GuaranteedCleanup` |
| `PW4` | `ProjectionRenewal` |
| `PW5` | `AdmissionControl` |
| `PW6` | `GuaranteedResidency` |
| `PW7` | `BestEffortCleanup` |
| `PW8` | `Slack` |

Each occurrence is identified by `(HardwareCapacityRootCertificate,
ServiceAllocationCertificate, FrameGeneration, FrameOrdinal, SlotID)` and is a
member of one exact parent physical-occurrence partition. The class sequence is
machine data; Markdown is generated or structurally compared against it.

Guaranteed-residency service has two cells per frame and a maximum cyclic gap
of five protected service opportunities. Every other single-slot protected
class has maximum cyclic gap nine. Bounds are computed from exact reserved slot
distances and per-item work counts, not from a free frequency scalar. An empty
protected slot becomes only revocable slack under a hardware reclaim-before-
next-slot rule; it cannot create future debt or satisfy another class's
reservation.

Admission maps every protected work unit, including retry, failure-publication
drain, transfer, receipt renewal, and settlement, to an exact class and finite
reservation. A generic queue length or strict priority is never a progress
proof.

## Nonvacuous Liveness

`ExogenousStableWindow` contains only environmental conditions:

```text
declared hardware contexts and independent clock/watchdog sources function
cryptographic and issuer/quorum fault bounds hold
no authenticated revoke, partition-mode transition, or planned maintenance
invalidates the target before its deadline
typed ENTRY/CODE/STATE/device interface actions satisfy their finite contracts
admitted external receipt and replication channels meet their exact bounds
fresh authority/namespace/calendar supply exists only for the horizon claimed
```

It does not contain `ContractOperationalState = Operational`, successful
failure processing, Monitor fairness, Linux fairness, or the theorem's own
conclusion.

`AuthorizedExternalWithdrawal` is a typed event with a protected receipt and
cause start time. Only a cause explicitly excluded by the claim and beginning
before the affected deadline can withdraw that opportunity's service promise.
An internal assertion, capacity overflow that admission should have prevented,
unexplained fail-stop, exhausted retry budget, or protocol deadlock is not such
a cause.

The proof order is:

```text
external rely admissibility
  -> identity and authority acyclicity
  -> hierarchy, physical occurrence, work, and namespace conservation
  -> bounded publication/failure/renewal closure
  -> OperationalPreservation
  -> deterministic due-cell and finite recovery rank
  -> qualifying delivery for one opportunity
  -> finite-horizon recurring induction
  -> conditional omega induction under InfiniteFreshnessSupply
```

`OperationalPreservation` states that, under the exogenous window and from a
valid admitted state, internal Monitor transitions do not create
`InternalGuaranteeViolation`, unexplained fail-stop, owner loss, capacity
overdraft, or permanent protected-work suppression. It is a predecessor theorem,
not an assumption of the per-opportunity theorem.

The finite service theorem is:

```text
for every admitted guaranteed CurrentOpportunity released in a qualifying
ExogenousStableWindow, exactly one qualifying ExecutionDeliveryReceipt is
accounted by its deadline, unless an AuthorizedExternalWithdrawal excluded by
the claim began before that deadline.
```

“Service or declared fail-stop” is not the theorem. Safety-only fail-stop
behavior remains modeled, but an internally caused fail-stop is a liveness
counterexample.

## Proof Dependency Contract

The successor proof DAG adds two missing roots and one mandatory theorem:

```text
ENV_CRYPTO_CANONICAL_SEAL
ENV_HARDWARE_TIME_ROOT
ENV_CLUSTER_ISSUER_QUORUM_TIME
ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE
  -> RESOURCE_HIERARCHY_SET_ALGEBRA
  -> DYN_ADMIT
  -> DYN_REQUEST
  -> DYN_CHURN
  -> DYN_RENEW_RESTART
  -> DYN_SHARD
  -> DYN_COMPOSE
  -> DYN_MULTILANE_COMPOSE
  -> OPERATIONAL_PRESERVATION_THEOREM
  -> PER_OPPORTUNITY_RANK_THEOREM
  -> DYN_LIVENESS_THEOREM
  -> DYN_REGRESSION
```

`DYN_ADMIT` depends on both the hardware/time root and exact set algebra because
admission reserves literal future physical and protected-work occurrences.
`OPERATIONAL_PRESERVATION_THEOREM` depends on every internal protocol capable
of causing fail-stop or suppressing the target. The rank theorem depends on it,
not vice versa.

Before TLA+ translation, every node must provide machine-readable:

```text
state variable IDs and owner
action IDs and read/write sets
external assume formula IDs
internal predecessor guarantee formula IDs
guarantee formula IDs
provider/refinement mapping
stuttering and failure actions
finite rank and bound units where applicable
claim and non-claim IDs
```

A prose-only provider name is not a discharged edge. The graph must be
mechanically acyclic and every internal assumption must resolve to an earlier
guarantee.

## R6 Counterexample Obligations

The successor executable witness must add at least these cases:

```text
WIT-R6-PREENTRY-TOKEN-CYCLE
WIT-R6-DECISION-SHADOW-RETRY-CANCEL
WIT-R6-DELEGATION-REPLAY-WRONG-HOLDER
WIT-R6-LEASE-VECTOR-ACYCLICITY
WIT-R6-RECEIPT-STALE-OR-FAKE-NOT-APPLICABLE
WIT-R6-CROSS-EPOCH-TOTAL-TRANSFER
WIT-R6-QUORUM-BOUNDARY-STRONG-SAFE-GAP-LOSS
WIT-R6-FAILURE-FRONTIER-CONCURRENT-PUBLICATION
WIT-R6-INTERNAL-FAILSTOP-NONDISCHARGE
WIT-R6-VALID-DUE-ENTRY-PRIORITY-AND-RETRY-RANK
WIT-R6-SAME-LANE-COLLISION-REJECT
WIT-R6-CONNECTIVITY-REPLAY-AND-EXPIRY
WIT-R6-PROTECTED-FRAME-PARITY-AND-CAPACITY
WIT-R6-TOTAL-LIFECYCLE-REFINEMENT
WIT-R6-CANONICAL-ID-ALIAS-REJECT
WIT-R6-PROOF-DAG-PROVIDER-CLOSURE
```

Assurance-protocol counterexamples are tracked separately because review
acceptance is not runtime scheduling semantics.

## Impossibility And Claim Boundaries

- A partitioned node cannot receive indefinite authority while preserving
  strict single-owner safety. The design permits only pre-issued bounded
  offline authority.
- Exact service continuity after an unreachable source is impossible without
  protected replicated activation and settlement closure. Otherwise a safe
  gap or explicit continuity loss is required.
- A process boundary is hypervisor-strength only when its private mutable
  kernel/user pages, entry state, translations, devices, and keys are in a
  separately enforced MemoryView. A Linux task label is insufficient.
- A formal model cannot establish physical stage-2/EPT, IOMMU, timer, or seal
  correctness. Those are later refinement and evidence obligations.
- Conditional omega recurrence does not imply finite namespace, storage,
  hardware, issuer, or clock resources are literally infinite.
- None of these semantics selects a production data structure, Linux hook,
  monitor ABI, cryptographic implementation, or scheduler policy.

## Current Decision

This architecture closes no finding yet. It proposes one coherent response to
all runtime-semantic R6 findings and exposes the assurance work as a separate
protocol revision. The next steps are to encode these rules in a strict
machine-readable successor overlay, materialize the effective v2 contract,
construct executable counterexamples, and perform fresh hostile review.

TLA+ remains deliberately last.

```text
successor_architecture_draft = true
r6_findings_closed = false
architecture_frozen = false
tla_authorized = false
tla_written = false
model_supported = false
protection_evidenced = false
performance_supported = false
cost_efficiency_supported = false
deployment_supported = false
```

## Machine Parity Capsule

The following JSON is a human-document anchor, not a second authority source.
The successor validator must parse it and compare every value with the
materialized v2 contract.

<!-- R6-MACHINE-PARITY:BEGIN -->
```json
{
  "contract_id": "dynamic-admission-recurring-residency-architecture-contract-v2",
  "authority_dag_nodes": [
    "OpportunityReservation",
    "ActivationDecisionCell",
    "CurrentOpportunity",
    "ActivationAttemptID",
    "ExecutionCellLeaseCore",
    "AuthoritySourceCores",
    "NormalizedAuthorityHorizonVector",
    "ExecutionCellLease",
    "ExecutionCellUseCell",
    "ActivationIntent",
    "ExecutionContextCore",
    "RequiredActivationReceiptSet",
    "ExecutionContextKey",
    "ActivationAttemptRecord",
    "PreEntryPermit",
    "EntryCommitRecord",
    "ActivationID",
    "ActivationCommitReceipt",
    "DeliverySettlementCell",
    "RunToken",
    "ExecutionDeliveryReceipt",
    "OpportunityTerminalCell"
  ],
  "activation_decision_key": "exact_complete_CurrentOpportunityID_only",
  "activation_attempt_id_fields": [
    "CurrentOpportunityID",
    "AttemptOrdinal"
  ],
  "receipt_subject": "ExecutionContextCore_physical_context_and_CpuIncarnation",
  "execution_context_key_derivation": "exact_ExecutionContextCore_CID_and_payload_digest_plus_complete_schema_ordered_receipt_CID_and_payload_digest_set",
  "protected_work_slots": [
    ["PW0", "SafetyCleanup"],
    ["PW1", "ManagementRecovery"],
    ["PW2", "GuaranteedResidency"],
    ["PW3", "GuaranteedCleanup"],
    ["PW4", "ProjectionRenewal"],
    ["PW5", "AdmissionControl"],
    ["PW6", "GuaranteedResidency"],
    ["PW7", "BestEffortCleanup"],
    ["PW8", "Slack"]
  ],
  "calendar_boundary_variants": [
    "SourceQuiesced",
    "QuorumSupersededStrongContinuity",
    "QuorumSupersededSafeGap",
    "ContinuityLost"
  ],
  "proof_dependency_order": [
    "ENV_CRYPTO_CANONICAL_SEAL",
    "ENV_HARDWARE_TIME_ROOT",
    "ENV_CLUSTER_ISSUER_QUORUM_TIME",
    "ENV_ENTRY_CODE_STATE_DEVICE_INTERFACE",
    "RESOURCE_HIERARCHY_SET_ALGEBRA",
    "DYN_ADMIT",
    "DYN_REQUEST",
    "DYN_CHURN",
    "DYN_RENEW_RESTART",
    "DYN_SHARD",
    "DYN_COMPOSE",
    "DYN_MULTILANE_COMPOSE",
    "OPERATIONAL_PRESERVATION_THEOREM",
    "PER_OPPORTUNITY_RANK_THEOREM",
    "DYN_LIVENESS_THEOREM",
    "DYN_REGRESSION"
  ],
  "architecture_frozen": false,
  "tla_authorized": false,
  "model_supported": false,
  "protection_evidenced": false
}
```
<!-- R6-MACHINE-PARITY:END -->
