# Dynamic Residency Fifth Hostile Architecture and Proof Review

Status: redesign integrated and strict validator/mutations complete; fresh
review and formal refinement pending; source verdict remains `FREEZE_NO`

Work record: `N-185`

Requirement: `RESIDENCY-DYN-001`

## Boundary

Three independent internal passes attacked the post-R4 architecture from
architecture-security, distributed-formal, and validator-assurance positions.
They were not authenticated reviewers and their raw sessions were not sealed
as external artifacts. This document is a discovery synthesis. It cannot
freeze the candidate or authorize TLA+.

## Findings

| ID | Severity | Counterexample | Integrated response |
| --- | --- | --- | --- |
| `R5-EXEC-01` | blocker | partial token checks permit stale entry or replay | total `TokenExecutable` and `ActiveContextExecutable`, one-use entry, protected monotonic resume, terminal replay denial |
| `R5-CLOCK-01` | blocker | raw deadlines from unrelated clocks are minimized | complete normalized horizon vector in one exact `LeaseClockEpoch` |
| `R5-ID-01` | high | activation identity omits enclosing logical or physical parents | full Domain/plan/lane/opportunity/CPU/allocation/slot/lease/intent parent vector |
| `R5-SLOT-01` | blocker | immutable lease points to a future intent | allocator-issued slot in lease; later digest binding only in the one-writer use cell |
| `R5-ACT-01` | blocker | cancel and activation win different cells | one canonical `ActivationDecisionCell` per `CurrentOpportunity` |
| `R5-ACT-02` | high | prepare/entry/stop crash cuts are implicit | durable one-way prepare-inert, entered, stop-pending, and settled phases |
| `R5-FAIL-01` | blocker | one closure scan misses newly reached generations | publication-fenced bounded least fixed point or reserved node fail-stop |
| `R5-SVC-01` | blocker | delivery retry recounts budget or service | one-writer `DeliverySettlementCell` with deterministic receipt and accounting keys |
| `R5-VAL-01` | blocker | malformed witness values passed weak checks | exact schemas, typed sets, cross-references, state edges, natural bounds, and targeted mutations |
| `R5-LIVE-01` | high | activation receipt was called service in one artifact | only qualifying idempotently accounted delivery is service |
| `R5-FORMAL-01` | blocker | proof obligations can assume their own descendants | acyclic proof DAG and component assume/guarantee ledger before TLA+ |
| `R5-CLOCK-02` | high | LeaseTick can stutter without an independent stop source | distinct watchdog source, epoch, turn, and autonomous fence/fail-stop path |
| `R5-LIVE-02` | high | finite freshness implies unbounded recurrence | finite claims separated from conditional omega theorem and freshness exhaustion |
| `R5-FAIL-02` | blocker | leaf cleanup charges underfund an LCA cover | aggregate precharge at every potential selected ancestor |
| `R5-PLACE-01` | blocker | prefix can predate predecessor write-close | write-close, no-later-delivery fence, later quorum checkpoint, then prefix |
| `R5-MIG-01` | blocker | cross-node gap subtracts unrelated ticks | interval-valued authenticated clock relation or continuity withdrawal |
| `R5-BOUNDARY-01` | high | external oracle assumptions look like B2b closure | interface-conditional claims with explicit CLUSTER/ISSUER/TIME/ENTRY/CODE/STATE refinements |
| `R5-CAP-01` | blocker | scalar sums permit physical occurrence double spend | exact disjoint parent/child `PhysicalOccurrenceID` set partitions |
| `R5-PLAN-01` | medium | plan says 17 scenarios while the machine has 20 | one exact 20-scenario inventory across plan, witness, index, and validator |

## Decision

All nineteen responses are represented in the candidate architecture or its
executable witness. The strict validator passes, 322 targeted hostile
mutations are rejected at their intended gates, and 8,119 malformed
scalar/container replacements across every executable-witness input node are
rejected without an unhandled executor exception. This is not closure: fresh
independent review must inspect the resulting exact bytes. External v2.1.2
assurance remains a separate prerequisite to semantic freeze and TLA+
authorization.

No implementation, protection, performance, deployment, architecture freeze,
or model-supported claim follows from this review.
