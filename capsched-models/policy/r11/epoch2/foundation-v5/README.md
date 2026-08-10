# R11 Epoch-2 F0 Foundation v5

Status: local F0 successor under construction; no F0 or K0 acceptance

Predecessor: exact F0 v4
`177ae3e0a860b808fd49a5bd93d03adc74d5b56f9950d1d257fa63e8fb6c7d9c`
is rejected by ADR-0020, Analysis 0217, and Validation 0306.

The normative F0 v5 design is split into:

```text
f0-00-core-language-v5.md
  declarations, carriers, core terms, provenance, evaluation, footprints

f0-01-model-transition-claims-v5.md
  model/instance/claim WF, actions, patches, events, runs, safety, scope

f0-02-morphisms-proof-boundary-v5.md
  extension/refinement morphisms, metatheory, proof/checker trust order

f0-machine-grammar-v5.json
  strict closed-AST grammar and canonical collection contract

f0-static-semantics-rules-v5.json
  source static and link-construction rule inventory, including typed ID
  preimages and invalidation policies

generated/
  reproducible strict Model, FiniteProfile, and FiniteRun wire schemas
```

Analysis 0218 and Validation 0307 retain the first machine draft as rejected
parity evidence. Analysis 0219 and Validation 0308 locally close only canonical
wire, byte-only source snapshot, source static checking, deterministic link
construction, and local cross-implementation reconstruction. Analysis 0220
through 0225 then advance checked evaluation and supervisor semantics through
rejected predecessors. Analysis 0226 and Validation 0313 fix the current
Candidate-4 pre-full checkpoint: child 274, parent 715, and runner 44 hostile
regressions plus the fast validator pass. Full child/parent reachability and
declared commutation are `NOT_RUN`.

Candidate-4 component receipts are emitted by the candidate validator and
checked for internal consistency by the same-UID runner. They are not
authority-disjoint execution observations. The next stage is therefore a
root-owned dedicated-UID containment/capture contract and only then a detached
full campaign, not F0 acceptance.

`CoreSyntaxWF`, F0 acceptance, F1, F2, F3, external K0, K1 candidate IR,
semantic freeze, TLA+, Linux behavior, Monitor implementation, and every
model/protection/performance/cost claim remain unauthorized.
