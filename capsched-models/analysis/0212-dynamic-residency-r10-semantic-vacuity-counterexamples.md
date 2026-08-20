# Dynamic Residency R10 Semantic-Vacuity Counterexamples

## Status

R10 remains `draft`. Thirteen formula, proof, provider, coverage, model-profile,
and authority-metadata mutations were accepted by the exact validator snapshot.
This rejects semantic closure, architecture freeze, TLA+ authorization, and all
model-supported claims.

Exact dispositions are in
`dynamic-residency-r10-semantic-vacuity-counterexamples-v1.json`.

## Exact Baseline

- Source: `ad463ae92004e962cbe8719073453aba4f60345e0c8099683a2b858268ef6f97`
- Schema: `9764d711c14f41de07185a359814522ddca563b0e52593f3c6b4334e75fcfadf`
- Validator: `a6c5a541259ef6eb29f0f16da222d065f126f6311de22edae9f4c6577c836e7e`
- R9 disposition: `509378203b8dc4009054487585da1ae82a38bde713f3bd539545120e8a4b8d5c`

## Accepted Counterexamples

The validator accepted each of the following as a valid baseline:

1. replace authority conservation with literal `TRUE`;
2. remove every formula and action from a claim-bearing proof node;
3. add a fabricated claim and attach it to an otherwise valid proof node;
4. initialize a write-once CPU provider receipt as already published;
5. replace every provider contract field with a true state/temporal formula;
6. replace transaction progress with `always TRUE`;
7. cover a canonical blocker with a fabricated identifier;
8. remove all blocker links from a concrete action;
9. replace mutation prose with a false description;
10. shrink `ShardID` from two values to one;
11. inflate `MaxTxnLocations` to one million;
12. collapse CPU writer consistency-domain metadata into node-shard metadata;
13. demote the authority account from authoritative state to a derived index.

## Layered Resolution

A structural validator cannot decide arbitrary semantic truth. Closure therefore
uses three distinct layers:

```text
machine IR:
  exact schemas, derived read/write/dependency footprints, nonempty obligation
  support, fixed authority/provider roles, generated bounds, nonvacuity shape

external review policy:
  minimum finite model profile, required obligation/claim catalog, exact
  reviewed formulas and interfaces, independent mutation expectations

formal validation:
  invariant preservation, refinement, temporal progress, rank decrease, and
  counterexamples under the frozen semantics
```

Literal-vacuity checks are defense in depth, not proofs. An equivalent tautology
must still fail because it cannot discharge the external obligation and formal
campaign. Similarly, candidate mutation prose becomes informational and cannot
define expected evidence.

## Required Redesign

- Rename the semantic role of `proof_nodes` to obligation nodes in the forward
  R10 format; a node is not a proof until a prover receipt discharges it.
- Derive claim support from obligation formulas, action coverage, imports, and
  external proof receipts. A claim string plus a graph edge has no authority.
- Give provider facts an explicit initialization policy. Runtime receipts must
  be `Vacant` in Init; boot facts require a separate sealed boot-manifest class.
- Derive actual action/blocker coverage from semantic nodes. Arbitrary strings
  and `PENDING-*` markers cannot close a finding.
- Move finite-domain minima and architectural writer/CD roles into an external
  model profile. Candidate bytes may instantiate but not weaken that profile.
- Compute actual maximum write footprint and compare it with a policy cap;
  candidate `MaxTxnLocations` cannot enlarge atomicity authority.
