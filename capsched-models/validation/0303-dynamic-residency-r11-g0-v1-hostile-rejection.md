# Dynamic Residency R11 G0 v1 Hostile Rejection

## Scope

This validation records a local pre-external-review rejection of the exact R11
G0 v1 candidate. It validates negative counterexamples and preserves the prior
local integrity result. It is not an external review, promotion receipt,
semantic proof, or model-supported result.

## Exact Input

```text
manifest
  capsched-models/policy/r11/g0-candidate-bundle-v1.json
bytes
  7073
sha256
  bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
artifacts
  17
```

The v1 candidate verifier and exact 12-case mutation campaign still pass. The
new tests ask the stronger question: can semantically weakened policy/profile
documents or logically impossible positive review decisions still satisfy the
current checker/schema?

## Commands

```bash
python3 capsched-models/validation/test-r11-g0-semantic-vacuity.py
python3 capsched-models/validation/test-r11-g0-review-gate-schema-vacuity.py
```

Each command was executed twice and its canonical one-line output hashed.

## Semantic-Vacuity Result

All 12 hostile variants were accepted by
`validate-r11-g0-policy-profile.py`:

```text
undefined binding/template meaning
opaque provider contracts
vacuous progress strings
arbitrary resource unit and consistency-domain axis
zero semantically used profile dimensions
renamed actions and outcomes
swapped witness labels
opaque relation meanings
opaque cut generation
forged weakening-oracle identifiers
collapsed rule-to-claim mappings
rotated profile-to-action mappings
```

```text
script sha256
  dc8935f4b6a59229a65f60c68d9d444f0a484731a219b68b3aa52e5f9218f3d7
repeated output sha256
  d5f6900e21aaab2175aaed34a2b6e41cf2a928907a6dc0fd53ff737bd9068042
```

## Review/Gate Forgery Result

The current JSON Schemas accepted all five hostile-positive conditions:

```text
accept receipt with a failed duplicate check
accept receipt with an open blocking finding and count zero
accept gate with eleven duplicate failed checks
accept gate with three duplicate review roles
accept gate with the same principal and authority in every review slot
```

```text
review schema sha256
  01cf4532da2cc1af7631ae14f37f6893a36e9d29a209e4ee0ae92ddb1bfc274a
gate schema sha256
  2cf700ca3b5ad11c6150dcd40f307171f784984b99f5df927910fe63861d2554
test script sha256
  2592662a01c7bf82da273b6f09773ca97d044e1639b003cf9d58d8847787733f
repeated output sha256
  0e6c61b1a62252f3c38e1d9167d84c651030bc0002a5ea06cb03c097aba7ec69
```

Schema acceptance is not a valid receipt. It demonstrates that an executable
promotion verifier and externally rooted identity policy are mandatory.

## Hostile Review Result

Three read-only reviews independently verified the exact manifest digest and
returned `LOCAL_ADVISORY_REJECT` on security/trust, formal encodability, and
scenario/composition axes. Their normalized blockers are recorded in Analysis
0214. They are deliberately not labeled external reviews or attestations.

## Disposition

```text
local snapshot integrity                    retained PASS
declared structural/protocol mutations      retained 12/12 reject
semantic-vacuity resistance                 FAIL: 12/12 hostile variants accepted
review/gate logical consistency             FAIL: 5/5 forged positives accepted
external authority                          absent
G0                                           false
R11 machine-source construction              false
semantic freeze                              false
TLA+                                         unauthorized
model support                                false
```

The exact v1 bundle is rejected and retained. ADR-0017 authorizes only a new
R11 G0 epoch-2 semantic-kernel draft. No Linux or Monitor implementation and no
protection, compatibility, performance, cost, cluster, or deployment claim is
authorized.
