# Dynamic Residency Fourth Hostile Counterexample Review

Status: redesign integrated; fresh review and formal refinement pending;
original verdict remains `FREEZE_NO`

Work record: `N-183`

Requirement: `RESIDENCY-DYN-001`

## Boundary

Three independent internal reviews examined the post-0195 candidate.  They are
not authenticated external reviewers, do not satisfy the v2 assurance policy,
and cannot accept or freeze any bytes.  Their useful output is the following
counterexample inventory.

The raw independent-session transcripts were not retained as immutable signed
artifacts. This record is therefore an unauthenticated discovery transcription,
not review provenance. It cannot count as external acceptance or rejection;
future disposition requires a checkpointed signed v2.1 review reveal.

## Findings

| ID | Severity | Counterexample or ambiguity | Required response |
| --- | --- | --- | --- |
| `R4-EXEC-01` | blocker | a frame cell creates an intent, a later action arms an arbitrary positive token budget, and later cells can activate peers while the first token is still active | introduce immutable allocator-issued execution-cell leases plus single-writer one-way use cells, one active owner per context, exact budget ceiling, forced handoff, and one parent conservation equation |
| `R4-EXEC-02` | blocker | an intent waits after the physical cell that allegedly backs it has passed, then later creates a token from stale capacity | prepare intent before the cell; consume an exact due unconsumed cell only in the joint activation; expired cells cannot carry forward or be reused |
| `R4-SVC-01` | blocker | activation receipt, immediate stop, and zero Domain instruction progress can be repeated as successful recurring service | distinguish authority activation from delivered execution service; require hardware-visible entry plus a positive delivered execution quantum or authenticated voluntary yield |
| `R4-ACT-01` | high | retrying one intent can mint two `ActivationID`/RunToken pairs because generation and one-to-one receipt rules are absent | derive one ActivationID from one consumed cell and intent; one receipt and token per ID; retries return the existing terminal result |
| `R4-PLACE-01` | blocker | placement horizon 100 plus lease-only extension to 200 permits source release at 150 while a destination already supersedes after 100 | release, intent, activation, token, and residual effects stop at the minimum placement/lease/security/root horizon; extension beyond placement requires fresh globally fenced placement authority |
| `R4-PLACE-02` | blocker | after source loss, histories where ordinal q did or did not settle are indistinguishable at the destination | require fault-tolerant settlement-prefix evidence, or enter an explicit continuity-lost recovery epoch that cannot claim exactly-once or recurring-gap continuity |
| `R4-MIG-01` | blocker | measuring gap from source stop rather than the last delivered activation undercounts the service gap | source receipt seals the last delivered-service receipt and trusted tick; gap starts there, while overlap safety remains based on stop/quiescence |
| `R4-FAIL-01` | high | two incomparable sound covering ancestors both fit the bound, so "canonically least" is not a function | require a rooted tree for authority cover or a boot-fixed total tie-break over sound ancestors; bind the selected cover to topology generation |
| `R4-FAIL-02` | high | a failure arrives under one topology and is processed after repeated reparenting; old, intermediate, new, and union covers differ | freeze source generation and conservatively union source, current, and every generation still referenced by live reverse-indexed authority, or node fail-stop |
| `R4-FAIL-03` | high | failure fencing and cleanup do not define when `Current` capacity moves to `FailureEscrow`, and sibling service conflicts with ancestor/node cover | atomically transfer capacity ownership at the failure authority point; define unaffected relative to selected cover; node fail-stop is an explicit non-interference exception |
| `R4-MODE-01` | high | `RECOVERY_ONLY` is ordinary-capable before connectivity expiry in one artifact and recovery-only immediately in another | make the mode recovery-only from installation; connectivity does not reopen ordinary release or activation |
| `R4-CAP-01` | high | protected control and Domain execution frames can each conserve independently while overbooking one physical CPU | bind both to a common hardware-capacity root when they share execution hardware; separate roots require disjoint hardware identities |
| `R4-ACT-02` | high | a crash between view install, entry install, timer arm, stop arm, and valid-bit publication can expose partial authority | define a hardware-inert staging bank and one final valid-bit/entry-gate linearization; recovery discards or completes only by exact transaction generation |
| `R4-CLOCK-01` | high | upper-bound clock conversion permits `LeaseTick` to stutter forever | either make protected clock progress an explicit finite external countdown rely or withdraw every time-bounded availability claim when it fails |
| `R4-LIFE-01` | medium | human and machine opportunity lifecycle names have no total refinement map; one freeze sentence also implies two writers create pending plus transaction atomically | add an exact lifecycle abstraction map and preserve source-only pending publication followed by transaction-owner allocation |
| `R4-VAL-01` | high | regenerated local digest pins accept unvalidated nested contradictions, assertion-label witness traces, stale review provenance, and omitted NodeConfig bounds | make witness state executable, validate exact nested schemas and ledger semantics, bind source reviews to immutable digests, and retain pins only as drift detection |

## Later Boundaries

The review also reconfirmed, without closing them:

```text
ENTRY/CODE/STATE must refine the physical joint-activation linearization.
SVC must close async provenance, effect lifetime, DMA, and queue fencing.
MGMT must model management compromise and break-glass authority.
CLUSTER-PART must supply no-fork quorum, settlement-prefix, and clock evidence.
The Monitor, hardware, firmware, and cryptographic roots remain explicit TCB.
```

## Decision

No finding is closed by this record. The candidate response is now integrated
into the architecture contract and the executable finite witness. The exact
validator and hostile mutation suite must finish, and fresh review plus formal
refinement must test the revised bytes before an external freeze campaign or
TLA+ formalization may start.
