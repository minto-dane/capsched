# Analysis 0193: Dynamic Residency Third Hostile Review and Redesign

Status: third-round redesign integrated; fresh review and formal refinement
pending; architecture is not frozen

Date: 2026-08-09

Work record: N-180

Requirement: `RESIDENCY-DYN-001`

Machine record:
`analysis/dynamic-residency-third-hostile-review-disposition-v1.json`

## Verdict

All four fresh third-round reviews returned `FREEZE=NO`. The pre-formal
witness and 100-mutation consistency gate exposed useful structure, but they
did not close authority ownership, clock conversion, crash recovery,
scalability, or review-authenticity semantics. TLA+ remains deliberately
blocked: formal syntax must not invent any missing rule.

## Review Provenance

| Reviewer ID | Role | Verdict | New blockers |
| --- | --- | --- | ---: |
| `curie-security-r3` | security | `FREEZE_NO` | 4 |
| `noether-formal-r3` | formal | `FREEZE_NO` | 7 |
| `hopper-scale-r3` | scalability | `FREEZE_NO` | 3 |
| `turing-integration-r3` | integration | `FREEZE_NO` | 6 |

These identities are session labels, not cryptographic identities. The raw
review outputs were not retained as immutable signed artifacts, so this record
is an unattested discovery transcription. It cannot serve as external freeze
evidence, and no third-round output may be reused as acceptance of revised
bytes. Fresh disposition requires v2.1 checkpointed commitments and reveals.

## Security Findings

| ID | Source ID | Blocker | Required redesign direction |
| --- | --- | --- | --- |
| `SEC-R3-01` | `CURIE-R3-SEC-01` | persisting a source replay high-water before its fence permits a crash to make a real failure permanently stale but unfenced | recoverable `Unseen -> DurablePending -> Fenced` ingress, with pending replay resumption and restart execution blocked until every pending record fences or fails closed |
| `SEC-R3-02` | `CURIE-R3-SEC-02` | source sequence/freshness exhaustion quarantines input but leaves resources that depend on that source executable | an exact source-availability scope must be fenced unless an already-authorized independent coverage set remains valid |
| `SEC-R3-03` | `CURIE-R3-SEC-03` | Formal 0148 erases `NodeLeaseID/NodeLeaseEpoch` from the abstract authority epoch | the abstraction must include the complete lease lineage or explicitly freeze and prove its erasure |
| `SEC-R3-04` | `CURIE-R3-SEC-04` | candidate-local files and hashes can fabricate all reviewer identities and an accepting decision | sealed candidate, externally anchored reviewer policy/attestations, and a later decision envelope must be distinct phases |

## Formal Findings

| ID | Blocker | Required redesign direction |
| --- | --- | --- |
| `FORM-R3-01` | Formal 0148 omits `NodeLeaseEpoch` | same complete lease-lineage abstraction repair as `SEC-R3-03` |
| `FORM-R3-02` | failure cells/audit phases and apply status each have multiple declared writers | split authority cell from audit detail state; make lane apply owner the sole apply-ledger writer while failure only publishes a fence |
| `FORM-R3-03` | one one-shot `TerminationOwner` cannot represent activation followed by later revoke/stop/terminal settlement | separate monotonic activation decision from post-activation stop and terminal settlement ownership |
| `FORM-R3-04` | conflict intent covers writes but not noncommuting reads, and dependency relations are not assigned per path | derive one full conflict footprint from writes, resources, and relation-typed reads with exact successor predicates |
| `FORM-R3-05` | the clock bridge treats a Monitor-maintained control quota as an external rely and does not define positive service/rank conversion arithmetic | separate hardware clock envelope, internal service invariant, aggregate reservation, positive rate, and total conversion formulae |
| `FORM-R3-06` | migration has no unique total mapping from a boundary-final source calendar to an independent destination lane | define exact inputs, common logical unit, arithmetic, rounding, gap/debt rules, output, and rejection conditions |
| `FORM-R3-07` | checkpointed incident detail has no owner/guard for safe slot retirement and reuse | define checkpoint, authority-retire receipt, replay tombstone/watermark, recycle generation, and every crash cut |

## Scalability Findings

| ID | Source ID | Blocker | Required redesign direction |
| --- | --- | --- | --- |
| `SCALE-R3-01` | `SCALE-R3-01_CONTROL_SERVICE_RATE_NOT_GLOBALLY_CONSERVED` | independent shard certificates can overbook one physical Monitor control executor | parent physical service capacity and child shard rate reservations must be conserved and bound into every clock certificate |
| `SCALE-R3-02` | `SCALE-R3-02_SECURITY_INCIDENT_SUMMARY_REINTRODUCES_GLOBAL_UPDATE_POINT` | one current root over all cells/audit heads is a global authority write and has an undefined crash cost | separate shard-local authority roots, audit roots, and asynchronous checkpoint aggregation; no global authority write on failure |
| `SCALE-R3-03` | `SCALE-R3-03_PAIRWISE_CERTIFICATE_CANNOT_JUSTIFY_LINEAR_BOUND` | pairwise commutation evidence is quadratic but the contract claims `O(k + depth)` | use owner-disjoint local writes plus aggregate conserved contributions, or state and reserve the honest higher bound |

## Integration Findings

| ID | Blocker | Required redesign direction |
| --- | --- | --- |
| `INT-R3-01` | review acceptance is self-attestable | require an external trust-policy digest and verifiable attestations; local synthetic identities test mechanics only |
| `INT-R3-02` | the documented review-before-capsule order contradicts reviews binding a capsule digest | seal candidate capsule first, review that exact digest second, aggregate a decision third, and derive freeze without mutating sealed candidate bytes |
| `INT-R3-03` | validator accepts hostile owner rewrites, no-op witness traces, missing identity fields, Linux fairness, and unknown contradictory keys | exact schemas, canonical critical projections, unknown-key rejection, semantic witness checks, and matching mutations are required |
| `INT-R3-04` | Formal 0148 lease lineage mismatch exists across prose, JSON, and validator | repair and validate exact parity everywhere |
| `INT-R3-05` | `FailureSourceEvidence` and structured `FailureScopeIdentity` are missing from machine object/type parity | add exact machine objects and field schemas |
| `INT-R3-06` | review roles, public/model identifiers, root-plan vocabulary, and removed latch terminology are inconsistent | publish an explicit canonical vocabulary/alias map and remove undeclared obsolete terms |

## Additional Self-Audit

| ID | Finding | Required redesign direction |
| --- | --- | --- |
| `SELF-R3-01` | pure lease extension mixed O(1) mutation work with memory retained by live frozen uses | state O(1) update/no traversal separately from O(live frozen uses) retained memory |
| `SELF-R3-02` | clock-bridge extension mixes O(1) record publication with memory retained by live certificate users | state update/no-traversal cost separately from retained-certificate memory and bound both by admitted users |
| `SELF-R3-03` | round-robin control selection can scan all admitted but empty principal slots | require a protected sparse nonempty-principal index with a hierarchy-depth bound without selecting its concrete data structure |
| `SELF-R3-04` | failure authority is local, but recovery cleanup can still scale with all dependent live artifacts | admission must bound/charge live uses per failure scope; authority fencing stays local while cleanup has an explicit actual-affected bound and protected quota |
| `SELF-R3-05` | the original failure ingress implied one atomic source/transaction write despite distinct writers | persist a self-contained source-owned pending record first; a transaction owner later builds only the exact precharged slot |
| `SELF-R3-06` | partial-apply escrow covered one intended status rather than the maximum of every terminal status | immutable per-component escrow is the component-wise maximum of Pending, Applied, and FailedFenced demand and remains until capacity-owner reclaim |
| `SELF-R3-07` | migration preserved debt but did not bind one exact ordinal/due phase across lanes | use one immutable trusted `ServiceCalendar`, exact next ordinal, checked due tick, and one unique destination cell |
| `SELF-R3-08` | a stored migration phase could be rewritten or recovered inconsistently | derive progress only from a prefix-closed chain of independently owned monotonic receipts |
| `SELF-R3-09` | failure and apply paths could both settle `FailedFenced`/scope state | failure owner writes only `SecurityScopeFence`; the exact apply owner writes `EntryFailClosedFence` and apply status |
| `SELF-R3-10` | source health was duplicated in replay state and effective scope state | derive source health only from `EffectiveScope(SourceHealthScope)` |
| `SELF-R3-11` | stale predecessor or partial preparation could occupy failure capacity indefinitely | require bounded resume, neutral abort, covered abort, or pre-reserved emergency permanent-fence terminal path |
| `SELF-R3-12` | audit retry had no unique durable position and could duplicate chain entries | reserve exactly one recoverable audit position and make every retry reuse it |
| `SELF-R3-13` | ordinary restart did not explicitly exclude unresolved ingress and unmapped old-boot fences | gate ordinary mode on closed pending ingress, consistent effective authority, reconciliation, dirty arm, fresh lease, and explicit old-fence mapping |

## Integrated Redesign Boundary

The next candidate must contain, at minimum:

```text
typed full conflict footprint and per-path successor relations
parent-conserved physical control service and exact clock/rank arithmetic
total boundary-final migration calendar function
separate activation decision and terminal/stop lifecycle
durable pending failure ingress and source-unavailable fencing
single-writer authority cell, audit detail, apply ledger, and recycle protocol
shard-local authority/audit roots with asynchronous checkpoint aggregation
complete lease-lineage refinement and failure identity machine parity
exact semantic validator projections and hostile-owner/no-op mutations
external review trust anchor and corrected capsule -> review -> decision order
source-owned self-contained pending ingress with no hidden cross-writer write
component-wise maximum apply escrow and exact single status/fence writers
common trusted migration calendar and prefix-closed receipt-chain recovery
derived source health, total transaction terminal paths, one audit position,
and complete ordinary-restart gate
```

The two specialist redesign studies for clock/migration and incident/audit
state are inputs to this work. They are not reviewer acceptance.

Analysis 0195 records a later datacenter/composition boundary review. Its
NodeConfig, physical execution, target-turn, partition import, global placement,
total failure cover, joint activation, and management-bootstrap blockers are an
additional open gate and are not retroactively counted as an R3 acceptance.

## Next Gate

```text
1. validate the integrated human and machine redesign against executable
   finite witness arithmetic and exact schemas
2. finish semantic hostile mutations and v2.1 assurance implementation
3. obtain fresh internal counterexample review of the revised bytes
4. build and externally publish the v2.1 campaign policy
5. seal one candidate capsule
6. obtain fresh externally attested R4 reviews of that exact capsule
7. aggregate the decision without changing candidate bytes
8. only then begin decomposed TLA+/TLAPS
```

## Non-Claims

No R3 finding is closed by this record. It does not freeze the architecture,
authenticate the four review sessions, complete TLA+, support the dynamic
residency requirement, select an implementation, change Linux behavior, prove
isolation, or provide performance, cost, multi-cluster, or deployment
evidence.
