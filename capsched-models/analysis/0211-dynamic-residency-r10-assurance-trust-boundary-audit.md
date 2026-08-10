# Dynamic Residency R10 Assurance Trust-Boundary Audit

## Status

R10 remains `draft`. This audit rejects machine-IR promotion, semantic freeze,
TLA+ translation, and every model-supported protection claim.

The audit was concurrent with repairs and is therefore negative-only evidence.
It cannot authorize any later snapshot. Its lossless disposition is recorded in
`dynamic-residency-r10-assurance-trust-boundary-audit-v1.json`.

## Essential Result

The in-tree hostile test is useful as a structural regression suite, but it is
not an independent promotion authority. It imports the validator under test,
uses that validator's parser, hashing, canonicalization, and publication
helpers, and obtains its expected outcomes from the candidate source. The
materializer then validates that evidence with the same implementation. A
coordinated defect or edit can therefore self-certify.

The test also loaded the candidate before re-reading paths for evidence hashes.
Those two reads need not observe the same bytes. A reported digest could name a
file version that was not the version tested.

## Fixed Trust Boundary

1. Read every candidate input exactly once and hash those consumed bytes with a
   standard-library implementation independent of the materializer.
2. Place those exact bytes in an immutable temporary bundle before validation.
3. Run the baseline and every mutant in a fresh subprocess; never import the
   validator into the assurance process.
4. Store case identity, expected reject stage and ID, mutation precondition,
   and exact allowed JSON-pointer diff in an external catalog. Candidate
   `mutation_obligations` are informational only.
5. A crash, timeout, signal, malformed result, wrong rejection, accepted mutant,
   duplicate case, changed input, skipped case, or order-dependent result is an
   assurance-harness failure, not a model result.
6. Repeat cases in independently shuffled orders and require deterministic
   outcomes.
7. Exercise meta-mutants that disable expectations, replace hashes with
   constants, skip cases, forge results, or substitute stale input bytes.
8. Promotion is derived only from an external manifest that pins candidate,
   schema, validator, independent harness, external case catalog, imported
   parsers and sources, complete results, and independent review decisions.

## Semantic Kill Set

The structural suite now kills 29 variants, including status promotion,
transitive hidden reads, identity aliasing, action-temporal confusion,
cross-state variant-field projection, concrete duplicate writes, mismatched
linearization and recovery, fabricated edge policy, undercharged object
publication, incomplete instance scope, proof/invariant/witness holes, and a
false terminal witness.

That does not establish semantic completeness. The independent catalog must
also include variants that preserve syntax while emptying meaning: replace a
conservation invariant with `TRUE`, retain proof claim names while removing
proof obligations, initialize immutable provider facts as already published,
make progress/provider contracts vacuous, fabricate blocker references, reduce
finite domains, inflate atomicity bounds, collapse shard/CD metadata, or demote
authority storage.

## Promotion Boundary

The candidate remains `draft` even when all local regressions pass. Promotion
status must not be stored in candidate-controlled bytes. An external verifier
derives an attested decision from an immutable bundle and an externally pinned
policy. Until that path exists and all semantic-vacuity mutants are rejected,
R10 is neither closed nor ready for TLA+.
