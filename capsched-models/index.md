# DomainLease Models and Engineering Work

Updated: 2026-08-10

This directory contains the modeling and engineering work products for
DomainLease-Linux, formerly CapSched-Linux during the private modeling phase.

Current critical path: `plans/0006-final-compositional-model-completion-plan.md`.
N-155 is historical v1 inventory/local-contract coverage; Analysis 0185 and
ADR-0012 reopen final system composition without discarding prior models.
ADR-0019 and Analysis 0216 require the R11 epoch-2 K0 foundation to close as F0
typed calculus, F1 claim semantics, F2 platform/threat refinement, and F3
external policy/assurance before any candidate IR or final TLA+ translation.
ADR-0020 and Analysis 0217 retain the first F0 v4 as rejected and make the
three-part F0 v5 machine/proof package the current work item. Analysis 0218
retains the first F0 v5 machine draft as a parity rejection. Analysis 0219 and
Validation 0308 locally close only canonical source static checking and
immutable link construction. Analysis 0220 through 0225 then advance checked
evaluation and supervisor semantics through several locally rejected designs.
Analysis 0226 and Validation 0313 are the current Candidate-4 pre-full
checkpoint: 274 child, 715 parent, and 43 runner hostile regressions plus the
fast validator pass, but full reachability/commutation is `NOT_RUN` and the
same-UID receipt path is not authority-disjoint. External assurance, F0, R11,
K0/G0, protection, and final-model completion remain open.

## Subdirectories

`formal/`
: Formal and semi-formal semantic models, including TLA+, Alloy, state machines,
  and invariants.

`analysis/`
: Upstream Linux code analysis, prior-art investigations, and reading notes.

`validation/`
: Validation plans, validation results, counterexamples, and evidence.

`plans/`
: Roadmaps, sequencing plans, and work breakdowns.

`implementation/`
: Implementation plans, patch maps, branch plans, and prototype notes.

`assurance/`
: Claim trees, evidence registers, forbidden-claim lists, and gate criteria
  that tie models and patches to the final security and efficiency goals.

`policy/`
: Candidate-external semantic policies, finite scenario profiles, mutation
  oracles, review contracts, and gate schemas. These artifacts constrain model
  sources and cannot self-authorize their acceptance.

`traceability/`
: Cross-reference policy, schemas, and future ledgers tying N-series work
  items to artifacts, semantic ids, Linux source anchors, validation classes,
  drift status, and assurance claim limits.

## Boundary

AI handoff, state ledger, compact design memory, decisions, and templates live
under `../capsched-ai/`.
