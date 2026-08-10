# ADR-0016: Reject Self-Attested R10 and Build Policy-Derived R11

Status: Accepted

Date: 2026-08-09

## Context

Dynamic Residency R10 introduced a useful typed AST, exact locations, bounded
transactions, deterministic materialization, a witness interpreter, and hostile
structural mutations. The exact retained candidate nevertheless permits the
candidate to choose the meaning of claims, proof support, provider contracts,
partition axes, scenario cardinality, atomicity bounds, authority roles, and
mutation expectations.

Thirteen locally reproduced semantic-vacuity mutants and nineteen independent
review probes were accepted. Twenty-six of the forty-two R10 blockers still
resolve only to `PENDING-*` markers. The candidate also starts management,
tenant, opportunity, ready, root-frame, and root-slot state as active, while a
referenced authority object does not exist in the object store.

Repairing those properties in place would make one R10 name refer to two
different trust models and would obscure the negative evidence.

## Decision

Retain Formal 0149/R10 as a rejected machine-IR experiment. Start a clean R11
successor whose candidate bytes cannot define their own promotion policy.

R11 uses four failure namespaces:

```text
IR-*   candidate structural or derived-semantics mismatch
CAT-*  external semantic-policy or scenario-catalog mismatch
PO-*   undischarged or failed formal proof obligation
HM-*   assurance harness or evidence-chain failure
```

R11 separates:

```text
candidate semantic modules:
  exact types, objects, state, actions, recovery, and typed obligations

external semantic policy:
  claims, trust roles, resource algebra, required partitions, provider classes,
  obligation inventory, architectural bounds, and blocker meanings

external scenario profile:
  minimum finite cardinalities, distinct and aliased authority cases,
  exhaustion, crash cuts, two lanes, two nodes, and two-cluster composition

formal receipts:
  Init-conformance, inductiveness, conservation, refinement, rank, liveness,
  and noninterference results generated after semantic freeze

promotion attestation:
  externally pinned candidate, policy, profile, tools, runtime, mutations,
  results, review decisions, and anti-rollback epoch
```

Candidate `proof_nodes` are replaced by proof-obligation nodes. They never
claim success. Core conservation, nonnegativity, identity, writer, partition,
and coverage formulas are generated from typed declarations where possible.
Free formulas remain reviewable obligations and cannot promote without formal
receipts.

Init contains no executable subject, activation, opportunity, ready claim,
root claim, or entry receipt. A non-executable sealed BootRoot and finite boot
work start a protected bootstrap transaction. Management then reaches physical
entry through the same authority, activation, root-claim, provider-entry,
budget, stop, and settlement DAG used by tenants. Tenant admission remains
closed until that path is established.

Async caller/service aliasing is explicit. R11 permits distinct authorities or
an aliased authority with two distinct role-use ordinals. The aliased form
performs one aggregate account update equal to both role reservations; it does
not issue duplicate writes. Single-use role fusion is forbidden unless a later
policy variant explicitly introduces and proves it.

The external policy owns resource algebra, writer classes, consistency-domain
axes, genesis constraints, provider templates, and obligation meaning. R11
candidate modules bind concrete types, state, and actions to those rules; they
do not redefine them. R11 architecture is decomposed into modules for core/bootstrap, authority and
subject lifecycle, activation/dispatch, runtime/settlement, residency/closure,
failure/transfer, GC, and bounded composition. One exact manifest lists every
module; no glob or repository discovery supplies semantics.

Initial physical entry consumes a one-use `EntryPermit`. Only a successful
provider entry commit emits an `EnteredReceipt` and any continuation token.
This avoids requiring a token whose own issuance depends on the entry being
authorized. Cross-consistency-domain authority movement uses source-owned
export/reservation receipts and destination-owned idempotent consume/apply;
remote mutable state is never updated atomically.

## Consequences

- R10 structural tests remain regression inputs but cannot support promotion.
- R11 must complete the reviewed D0-D17 semantic DAG before architecture
  freeze; completing an early module is not model completion.
- Retry and recurrence use fresh monotonic ordinals and induction, never a
  dependency-cycle edge.
- `ReadyConsumed` is derived only from a matching provider Entered receipt.
- Only the provider atomic entry product may make `CurrentExecutable` true.
- Linux remains an untrusted proposer and semantic actor, never a protected or
  provider-state writer.
- Multi-cluster state enters a node only through finite-horizon typed receipts;
  network silence is never quiescence.
- No behavior-changing Linux patch, Domain Monitor implementation, or TLA+
  translation is authorized by this ADR.

## Non-Claims

This decision does not complete R11, prove a property, authenticate a runtime,
or establish hypervisor-level protection, cost efficiency, Linux compatibility,
multi-cluster correctness, or deployment readiness.
