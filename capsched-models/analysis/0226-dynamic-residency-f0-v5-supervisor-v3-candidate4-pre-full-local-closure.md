# Dynamic Residency F0 v5 Supervisor v3 Candidate-4 Pre-Full Local Closure

## Status

Candidate-4 has reached a bounded pre-full local checkpoint. Its static
registries, mutation suites, claim catalog, raw component-receipt format, and
runner lifecycle now agree mechanically. This authorizes capture for a later
detached full local campaign. It does not authorize F0, R11, G0, a semantic
freeze, Linux implementation, or any protection claim.

The machine-readable companion is
`dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure-v1.json`.

## What Candidate-4 Repairs

The child LTS now gives every declared action an exact guarded successor and
canonical effect. Evidence order is part of exact state identity. Arrival
chronology is receipt-backed, the earliest fault is sticky, phase is reconstructed
from the evidence prefix, and final over-limit resource observations cannot be
lower than the final counter.

The parent orchestrator now reconstructs exact attach successors, rejects forged
sealed or abandoning states, rejects an old-generation head after an EMPTY
publication fence, orders grant acceptance before retirement, reconstructs
failure phase from receipts, and binds typed store attacks to registry, phase,
generation, capsule, commitment, acknowledgment, head, fence, and failure state.

These are finite executable semantics. They are not a Linux or Monitor
refinement.

## Claim Boundary

The immutable claim registry contains 11 claims:

```text
fast local mutation/static claim:                         PASS
child exact fixture-bounded reachability:                 NOT_RUN
parent exact repetition-bounded reachability:             NOT_RUN
declared local effect commutation:                        NOT_RUN
independence completeness:                                OPEN_REFINEMENT
external authentication:                                 OPEN_REFINEMENT
attack-context-key refinement:                            OPEN_REFINEMENT
unbounded repeated attack history:                        OPEN_REFINEMENT
durable-store linearization refinement:                   OPEN_REFINEMENT
parent/child independence refinement:                     OPEN_REFINEMENT
F0 local acceptance:                                      OPEN_REFINEMENT
```

The candidate cannot issue or mutate this catalog into authority. Every positive
full-mode claim must be derived from its registered Boolean predicate. Open
claims resolve exact obligation IDs rather than a generic list path.

## Local Evidence Architecture

Each full-mode component is a separate subprocess. The candidate validator
retains its argv, exit classification, raw stdout and stderr bytes, byte hashes,
input-root hash, and exact parsed result. The outer runner checks the candidate
validator's aggregate for internal consistency:

```text
one strict RESULT_JSON record
duplicate-key rejection
raw receipt bytes equal the aggregated component value
exact top-level and nested component schemas
worker input maps equal the captured snapshot manifest
component and role identities
test marker and exit-code relations
action-registry count relations
producer/checker exact result agreement
commutation actions belong to each role's reachable action registry
source/co-enabled/both-orders/equal-outcome count equality and nonterminal bounds
per-pair edge lower bounds from co-enabled sources and reachable action labels
child/parent subset, terminal, breach, edge, and reachable cardinality relations
declared commutation pair count and outcome relations
claim status and exact evidence references
```

The runner's direct shebang starts Bash with `-p` and removes `BASH_ENV`/`ENV`.
A Linux `/proc` argv check requires `-p` in the option prefix, rejects
sourced/`-c` execution, and fail-stops invalid launches with `SIGKILL` rather
than trusting an overridable shell `exit`. This is defense in depth, not the
external capture root. The runner also uses unpredictable private temporary
names, treats voluntary exits 124 and 143 as tool errors, classifies timeout
from the parent's monotonic elapsed time, and performs bounded TERM-to-KILL
process-group cleanup even when the validator leader exits first.

This consistency check is not an independent observation of component
execution. The candidate validator still captures the component receipts and
supplies the aggregate being checked.

## Deliberately Unclosed Trust

This remains same-UID local evidence. Read-only modes do not prevent the same
UID from replacing captured inputs. A child can escape a process group with a
new session. Toolchain bytes are measured but are not authenticated by an
external root. Final status and evidence storage remain mutable after
publication. Component receipts are captured by the candidate validator and
are not externally attested.

Accordingly, all of the following remain false:

```text
runtime input write prevention
continuous input stability
descendant containment
post-finalization storage immutability
toolchain runtime closure and external authentication
checker soundness
external R11 review
G0 authorization
F0 local acceptance
Linux or Monitor refinement
protection and cost-efficiency evidence
```

Closing those properties requires an authority-disjoint execution layer, not
more self-attestation. The intended next assurance stage is a root-owned,
dedicated-UID service with a root-owned read-only snapshot, nondelegated cgroup
v2 containment, pidfd/waitid lifecycle observation, cgroup kill and populated=0
drain, and externally retained immutable output. External R11 review and the K0
G0 decision remain a separate later stage.

## Overhead Meaning

Candidate-4 is offline model and evidence tooling. It changes no Linux hot path
and therefore adds zero production scheduler overhead. Its hashing, strict JSON
validation, process supervision, and future containment service are validation
costs only.

The eventual implementation still has a strict performance obligation: common
run eligibility and budget checks must be bounded constant-time operations;
cryptographic sealing, global issuance, and expensive evidence work belong off
the scheduler hot path; Monitor transitions should occur only when the active
Domain or root authority changes. None of those production costs is evidenced
by this checkpoint.

## Next Gate

1. Finish fresh read-only audit of these exact pre-full bytes.
2. Commit and publish this restartable checkpoint.
3. Design and review the authority-disjoint full-run launcher contract.
4. Capture an exact manifest and launch the long full local campaign detached.
5. Independently reduce the retained raw receipts and disposition the four local
   claims without changing any external claim.

## Nonclaims

Candidate-4 is not a completed model, an F0 result, an externally reviewed R11
artifact, a G0 decision, a TLA+ model, a Linux patch, a Monitor implementation,
or evidence of hypervisor-grade separation. No Linux behavior changed.
