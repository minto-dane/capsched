# Analysis 0191: Dynamic Residency Second Hostile Review and Redesign

Status: all second-round blockers recorded and candidate architecture redesigned;
fresh third-round review required; architecture is not frozen

Date: 2026-08-09

Work record: N-178

Requirement: `RESIDENCY-DYN-001`

Machine record:
`analysis/dynamic-admission-recurring-residency-second-hostile-review-disposition-v1.json`

## Purpose

Four independent hostile readings of Analysis 0189 all returned `FREEZE=NO`.
This is useful evidence against premature formalization: the first redesign
closed many local contradictions, but authority identity, asynchronous apply,
clock arithmetic, failure replay, migration, audit renewal, and review
attestation still had cross-cutting gaps.

The findings are not deduplicated away. Security, formal, scale, and integration
reviewers sometimes reached the same defect independently. Each original
finding keeps its own ID and disposition; shared repairs are referenced rather
than used to erase review provenance.

## Review Provenance

| Reviewer ID | Role | Verdict | Findings |
| --- | --- | --- | ---: |
| `harvey-security-r2` | security and authority | `FREEZE_NO` | 8 |
| `herschel-formal-r2` | formal and temporal semantics | `FREEZE_NO` | 11 |
| `boyle-scale-r2` | datacenter scale and locality | `FREEZE_NO` | 5 |
| `archimedes-integration-r2` | artifact and refinement consistency | `FREEZE_NO` | 12 |

These reviewer identities describe the completed second-round sessions. They
are not reusable attestations for the next candidate. Freeze requires fresh,
distinct review records bound to the final artifact hashes.

## Security Findings

| ID | Blocker | Candidate redesign | Still required |
| --- | --- | --- | --- |
| `SEC-R2-01` | failure replay identity was allocated from the event it was meant to deduplicate | source-owned `SourceFailureReceiptID` is authenticated and fenced before a permanent one-to-one internal event mapping | replay before allocation, after GC, and after recovery in `DYN-CHURN` |
| `SEC-R2-02` | delegated future effects had no exact authorization horizon | delegation binds `LeaseClockEpoch`, not-before, commit-not-after, effect-not-after ticks, and bridge proof | delayed-apply horizon model |
| `SEC-R2-03` | an opportunity required the old fence generation even though cutover must advance it | release-observed generation is history; activation checks the live monotonic fence and the token binds the current generation | cutover/activation/token races |
| `SEC-R2-04` | scoped operation IDs omitted their complete owner root | every scoped ID binds full `ScopedNamespaceRoot`, epoch, and sequence | cross-owner alias mutations |
| `SEC-R2-05` | restart omitted authoritative incident/log crash state | exact snapshot includes incident summary, cells, shard heads, source high-water roots, phases, and log faults | every incident/log/checkpoint crash cut |
| `SEC-R2-06` | a review record could self-assert acceptance or omit findings/hashes | freeze requires distinct reviewer identities, complete dispositions, and a complete hashed Evidence Capsule | strengthened validator and fresh reviews |
| `SEC-R2-07` | a separate latch generation was outside the namespace algebra | the independent latch generation is removed; bounded per-scope cells use registered scope/log namespaces | capacity and quarantine model |
| `SEC-R2-08` | executable `DYN-SHARD` was required both before and after the TLA gate | a pre-formal two-lane witness precedes freeze; executable `DYN-SHARD` follows freeze but precedes requirement closure | witness, review, then model in that order |

## Formal Findings

| ID | Blocker | Candidate redesign | Still required |
| --- | --- | --- | --- |
| `FORM-R2-01` | lease-clock epoch ABA was absent from frozen use and token identity | exact `LeaseClockEpoch` is bound throughout; replacement waits for quiescence or permanent fence | epoch replacement model |
| `FORM-R2-02` | migration could fence a source with an open opportunity | source receipt requires no current opportunity after settlement or a precommitted skip | open-opportunity migration negatives |
| `FORM-R2-03` | asynchronous apply failure had no total result | every entry ends `Applied` or `FailedFenced`; cleanup retains capacity ownership | every failure/apply order |
| `FORM-R2-04` | committed-pending root capacity had no owner | explicit `CommittedPendingPlanRootReservation` participates in exact transfers and conservation | commit/reject/failure conservation |
| `FORM-R2-05` | source replay identity was circular | same source-first repair as `SEC-R2-01` | same replay model |
| `FORM-R2-06` | first release could occur at its effective boundary | first release is at least `effectiveTurn + 1`, plus preparation lead | boundary-order mutation |
| `FORM-R2-07` | clock fields did not define arithmetic | exact nonnegative deltas, lease upper bound, control quota, validity, overflow rejection, and stop transition are specified | numeric model and mutations |
| `FORM-R2-08` | progress rank had no relation to control and lease clocks | total monotone `ControlTurnsFor`, `RankToLaneTurns`, and `LeaseTicksForRank` operators are required | rank conversion proof |
| `FORM-R2-09` | cancel had no total result during revoke, expiry, failure, cleanup, or settlement | one `TerminationOwner` CAS and a phase-total response table order all causes | all race pairs |
| `FORM-R2-10` | one-lane composition hid cross-lane protected-work interference | `DYN-MULTILANE-COMPOSE` is mandatory | executable composition after freeze |
| `FORM-R2-11` | JSON weakened nonconflicting progress to mere terminality | a selected authorized feasible nonconflicting operation must commit | peer churn and recurrence model |

## Scalability Findings

| ID | Blocker | Candidate redesign | Still required |
| --- | --- | --- | --- |
| `SCALE-R2-01` | use and membership identity omitted enclosing scope consistency | full `FailureScopeIdentity` and one canonical `PlanMembershipID` are used everywhere | alias and parity mutations |
| `SCALE-R2-02` | proving every apply prefix by enumeration is exponential | `MaxTransitionShards` plus per-shard, pairwise-commutation, and aggregate-capacity certificates give `O(k + depth)` verification | small-model exhaustive conformance to the certificate grammar |
| `SCALE-R2-03` | namespace wear was not sponsor-conserved | nonrefundable `NamespacePublicationReservation` isolates management, guaranteed, renewal, and best-effort headroom | hostile publication/renewal traces |
| `SCALE-R2-04` | failure fencing materialized dependent Domains and touched a shared authority latch | authority touches at most `MaxFailureScopesPerEvent` preallocated cells; contract population is never enumerated | locality and noninterference model |
| `SCALE-R2-05` | authorized conflicting peers could perpetually overtake control work | selected guaranteed work obtains a bounded logical `ConflictIntentReservation`, never a physical lock held across waits | adversarial overlap model |

## Integration Findings

| ID | Blocker | Candidate redesign | Still required |
| --- | --- | --- | --- |
| `INT-R2-01` | clock schemas and arithmetic differed across artifacts | one exact three-clock certificate and inequality set is canonical | parity validation and numeric model |
| `INT-R2-02` | failure replay was not source-owned | same repair as `SEC-R2-01` | same replay model |
| `INT-R2-03` | best-effort authority use had no unambiguous identity | `BestEffortAuthorityUseID` binds sponsor/request roots, request, digest, and frozen lease | alias and retirement model |
| `INT-R2-04` | machine parent graph omitted issuer incarnation | `ClusterIssuerIncarnation` parents global authority and node lease lineages | old-issuer replay model |
| `INT-R2-05` | issuer epochs and local revoke generations had conflicting owners | issuer `DomainEpoch`/`NodeLeaseEpoch` are separate from Monitor-only narrowing generations | refinement and no-local-mint proof |
| `INT-R2-06` | partial apply was incomplete | same total outcome repair as `FORM-R2-03` | same apply model |
| `INT-R2-07` | migration froze a calendar before final source quiescence | prevalidation only bounds; the source receipt seals boundary-final calendar/debt and destination derives only from it | source race and debt model |
| `INT-R2-08` | finite global audit state was assumed to sustain unbounded failures | independent audit shards, `AuditHeadroomWindow`, and authenticated checkpoint-renewal induction separate finite safety from long liveness | restart and liveness proof |
| `INT-R2-09` | review validation was incomplete | same strict evidence/reviewer repair as `SEC-R2-06` | mutation suite and fresh record |
| `INT-R2-10` | machine progress semantics were weaker than prose | safety and negative inventories now have exact Markdown/JSON parity | later model manifest parity |
| `INT-R2-11` | Formal 0147 restriction omitted failure, lease, and clock premises | the restriction names operational state, valid bridge, timely renewal, no target fault/revoke/maintenance, and no outer exhaustion | explicit implication theorem |
| `INT-R2-12` | formalization order was cyclic | same two-stage witness/freeze/model order as `SEC-R2-08` | phase-order validation |

## Additional Self-Audit

| ID | Defect found while integrating reviews | Candidate redesign |
| --- | --- | --- |
| `SELF-R2-01` | live security vectors lacked an immutable admitted dependency closure | `SecurityDependencyCertificate` freezes exact topology/ownership closure; closure changes fence predecessors first |
| `SELF-R2-02` | cutover could preserve an opportunity but remove the service needed to finish it | `RetiringOpportunityReservation` preserves exact old root service until terminal |
| `SELF-R2-03` | service-only update wording could mint binding authority | service-only successors preserve the binding projection and mint no new authority use |
| `SELF-R2-04` | exact equality on the hot ledger would stale every normal control operation | typed `ExactGuard`, `MonotoneSuffix`, and `RecomputeAtCommit` dependencies replace caller-selected equality |
| `SELF-R2-05` | transition shard count was not admitted | `MaxTransitionShards` and its proof/storage capacity are feasibility inputs |
| `SELF-R2-06` | an unrelated security audit checkpoint could stale a commit | audit high-water is outside the exact guard unless its certified scope intersects the footprint |
| `SELF-R2-07` | source evidence and per-shard log ownership were incomplete | source receipt mapping, cells, summary, shards, and reconciliation roots are explicit |
| `SELF-R2-08` | recurring liveness ignored eventual audit exhaustion | the stable interval carries audit headroom; infinite recurrence requires checkpoint-renewal induction |

## Resulting Architecture Changes

The redesign is not a larger all-purpose capability. It sharpens ownership and
linearization boundaries:

```text
issuer authority
  ClusterIssuerIncarnation -> GlobalAuthorityEpoch/DomainEpoch
  ClusterIssuerIncarnation -> NodeLeaseID/NodeLeaseEpoch/term

local narrowing only
  MonitorBootEpoch + issuer identity -> LocalAuthorityGeneration
  MonitorBootEpoch + lease identity  -> LocalLeaseFenceGeneration

control publication
  immutable CommitDeltaTemplate
  -> selected logical ConflictIntentReservation
  -> atomic commit with live RecomputeAtCommit values
  -> independently total local apply outcomes

failure authority
  authenticated SourceFailureReceiptID replay fence
  -> bounded per-scope cell/fence authority transition
  -> independent audit-shard append/checkpoint observation

recurring service
  CurrentOpportunity keeps release history
  -> activation checks live fences and exact clocks
  -> token binds current fence generation
  -> retiring reservation remains until terminal
```

The total namespace registry now has 66 semantic spaces. This count is not a
quality metric; it is a completeness claim that every finite replay-sensitive
generation has an owner, parent graph, allocator, and terminal exhaustion
behavior. Packing several semantic versions into one machine word remains a
future refinement requiring an injectivity and freshness proof.

## Freeze Order

The corrected order is:

```text
1. architecture contract and machine parity
2. pre-formal two-lane trace/witness
3. strengthened validator and mutation suite
4. fresh independent third-round review
5. hash-bound architecture-freeze Evidence Capsule
6. semantic freeze
7. decomposed TLA+ including DYN-SHARD and DYN-MULTILANE-COMPOSE
8. negative models, infinite recurrence proof, and claim-specific EC1 decision
```

The witness in step 2 is not an executable proof. It is a finite, inspectable
architecture argument that exposes ownership, commutation, partial-apply,
failure, retirement, and migration interactions before formal syntax freezes
them. Conversely, no TLA+ result may retroactively legitimize an architecture
that fresh reviewers still reject.

## Non-Claims

No second-round finding is closed by this document. The candidate has an
explicit redesign for all 36 reviewer findings and 8 self-audit findings, but
only fresh reviewers may accept or reopen them. This is not semantic freeze,
TLA+ evidence, model completion, implementation approval, Linux behavior,
Monitor isolation, performance evidence, or a hypervisor-equivalent protection
claim.
