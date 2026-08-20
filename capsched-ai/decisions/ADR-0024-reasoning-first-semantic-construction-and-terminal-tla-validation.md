# ADR-0024: Reasoning-First Semantic Construction and Terminal TLA+ Validation

Status: Accepted; refines ADR-0015 for the model-completion campaign

Date: 2026-08-11

## Context

ADR-0015 already requires architecture before executable specification. The
remaining DomainLease-Linux work is dominated by semantic choices that a
bounded state-space encoding cannot make safely: authority ownership,
impossibility boundaries, lifecycle linearization, failure closure,
composition, and the exact scope of hostile behavior.

The project owner has changed the working method explicitly. The current
completion campaign uses GPT-5.6 Sol at maximum reasoning effort as the primary
architecture synthesis and hostile-critique engine. TLA+ is retained as a
terminal validation backend after the semantic contract is frozen, rather than
as the medium from which the architecture is discovered.

An LLM response is not a proof, an independent reviewer, an evidence capsule,
or an authority transition. Model branding and reasoning effort do not make a
claim true. The method therefore needs a strict boundary between deep
reasoning used to construct the model and durable artifacts that another
implementation or reviewer can falsify.

## Decision

### Primary reasoning profile

For the current Plan 0006 completion campaign, the primary reasoning profile
is:

```text
engine: GPT-5.6 Sol
reasoning effort: maximum
role: architecture synthesis, contradiction search, and minimality analysis
authority: none
```

Changing to a weaker reasoning profile for a semantic closure decision requires
an explicit record. A future stronger or independently implemented reasoner may
be added, but does not retroactively change the meaning of frozen artifacts.

### Required reasoning products

Before any backend encoding, each remaining component must materialize all of
the following:

```text
claim and non-claim boundary
threat subject and trusted computing base
typed identity, object, authority, and version algebra
owned state and every untrusted shadow
complete action and lifecycle table
linearization, conservation, cancellation, and settlement points
failure, restart, overflow, saturation, and partition semantics
impossibility and availability trade-off ledger
datacenter scale and locality bounds
assume/guarantee dependencies with no circular rely
hostile traces and minimal countermodels
refinement surfaces to Monitor, Linux, services, devices, and cluster control
machine-readable contract and independently executable consistency checks
unresolved assumptions and exact promotion prohibition
```

Free-form reasoning is working material. Only the reviewed human contract,
canonical machine-readable form, negative corpus, and validator interfaces are
project state.

### Synthesis and contradiction are distinct passes

The same reasoning engine may perform both passes, but they must be separated
by an immutable candidate digest and different instructions:

```text
synthesis:
  construct the strongest contract that satisfies the stated mission

contradiction:
  assume the contract is wrong; search for omitted state, confused authority,
  circular liveness, unsafe composition, unbounded work, and weaker substitutes

minimality:
  identify which trusted objects and actions are actually necessary and reject
  convenience state that widens the Monitor or evidence TCB
```

A critique of mutable draft bytes is advisory only. A closure record must name
the exact digest it reviewed and preserve every blocker and disposition.

### Machine-readable semantics precede backend translation

The canonical contract is backend-neutral. It fixes names, sorts, ownership,
actions, frames, event channels, relies, guarantees, claims, and non-claims
before TLA+, Alloy, a theorem prover, or executable search is permitted to
translate it. Generated backend artifacts may not:

```text
omit a declared hostile action
replace a bound with a smaller convenient population
turn adversarial Linux behavior into a fairness assumption
collapse security-visible state into an opaque aggregate
change a safety claim into a finite-search claim
invent an owner, recovery authority, or external assumption
weaken a claim to obtain a passing run
```

Backend counterexamples reopen the semantic contract. A backend pass supports
only the exact frozen claim and scope that it translated.

### TLA+ terminal role

TLA+ remains mandatory where temporal concurrency validation is useful, but it
is terminal in this order:

```text
reasoned architecture
  -> hostile contradiction/minimality closure
  -> canonical machine-readable semantics
  -> external policy and acceptance boundary where required
  -> semantic freeze
  -> mechanically checked translation
  -> decomposed TLA+ safety/liveness checks and mutants
  -> claim-specific evidence capsule and decision
```

For R11 this preserves the existing F0 -> F1 -> F2 -> F3 -> external K0 -> K1
dependency. ADR-0024 does not authorize F1 early, bypass K0, or authorize Formal
0150. It changes how the semantic source is constructed, not the assurance
authority that accepts it.

### Evidence and provenance

Reasoning artifacts record the engine/profile and exact input artifact digests
for reproducibility, but LLM transcripts are EC0 design provenance only. A
positive transition still requires ADR-0013 capture-first evidence and the
claim-specific authority defined for that transition. Independent review means
independent authority or implementation, not a second prompt in the same trust
domain.

## Consequences

- Plan 0006 remains architecture-first and now names the primary construction
  method explicitly.
- The immediate Candidate-4 capture work is designed as a backend-neutral
  authority contract and hostile mutation corpus; no TLA+ module is created.
- Remaining ENTRY/CODE, STATE/SVC/MGMT, CLUSTER-PART, COMPOSE, and GRANULARITY
  work must publish the required reasoning products before executable models.
- TLA+ is preserved as a strong falsification and temporal-validation backend
  after semantic freeze.
- GPT output cannot self-authorize F0, K0/G0, model support, implementation,
  protection, performance, cost, or deployment claims.

## Non-Claims

This decision does not complete a model, prove that GPT reasoning is sound,
replace hostile or external review, authorize a long Candidate-4 run, weaken
the existing F0-F3/K0 gates, approve Linux or Monitor behavior, or establish
any production claim.
