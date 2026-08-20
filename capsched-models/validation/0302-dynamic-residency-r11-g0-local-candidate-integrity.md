# Dynamic Residency R11 G0 Local Candidate Integrity

## Scope

This record covers only the local R11 G0 candidate bundle and its exact
development mutation campaign. It does not record an external review,
promotion decision, semantic freeze, proof, or model-supported claim.

## Exact Candidate

```text
manifest path    capsched-models/policy/r11/g0-candidate-bundle-v1.json
manifest bytes   7073
manifest sha256  bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
artifact count   17
authority        role_separated_local_candidate_not_external_approval
```
The candidate contains exact semantic policy, rule registry, scenario profile,
review contract, mutation catalog, claim catalog, schemas, mechanical checker,
mutation runner, and candidate verifier bytes. The manifest excludes its own
digest, so reviews bind the raw manifest digest without a self-reference.

## Mechanical Result

The snapshot verifier passed with:

```text
semantic rules                 73
simultaneous invariants        27
progress obligations            8
provider contracts             10
finite profiles                19
witness IDs                    13
G0 checks                      11
review roles                    3
exact G0 mutations             12
future IR mutation templates   24
```

It copied the 17 captured artifacts to an isolated temporary tree and ran the
captured exact campaign from that tree. The nested checker validated the
policy, registry, profile, review contract, and claim references.

## Exact Mutation Result

All 12 cataloged mutations rejected at the fixed result:

| Mutation | Exact reject |
| --- | --- |
| `MUT-G0-UNKNOWN-FIELD` | `CAT-G0-SCHEMA` |
| `MUT-G0-DUPLICATE-KEY` | `CAT-G0-DUPLICATE-KEY` |
| `MUT-G0-SELF-AUTHORIZE` | `CAT-G0-SELF-AUTHORIZATION` |
| `MUT-G0-DELETE-CATALOG-ITEM` | `CAT-G0-CATALOG-COVERAGE` |
| `MUT-G0-REFERENCE-UNKNOWN` | `CAT-G0-REFERENCE` |
| `MUT-G0-LINUX-AUTHORITY` | `CAT-G0-TRUST` |
| `MUT-G0-PROVIDER-GENESIS` | `CAT-G0-PROVIDER` |
| `MUT-G0-PROFILE-COLLAPSE` | `CAT-G0-PROFILE` |
| `MUT-G0-PROFILE-SKIP` | `CAT-G0-PROFILE-COVERAGE` |
| `MUT-G0-ORACLE-FORGERY` | `HM-G0-ORACLE-DIGEST` |
| `MUT-G0-CHECKER-SKIP` | `HM-G0-CHECK-COVERAGE` |
| `MUT-G0-STALE-REVIEW` | `HM-G0-REVIEW-DIGEST` |

The first ten mutate exact policy/profile bytes. Duplicate-key uses an exact
canonical-byte splice because RFC 6902 cannot represent duplicate object keys.
The last two mutate exact protocol fixtures for check coverage and review
freshness. They do not authenticate a real review chain.

## Reproduction

```bash
python3 capsched-models/validation/validate-r11-g0-policy-profile.py
python3 capsched-models/validation/run-r11-g0-exact-campaign.py
python3 capsched-models/validation/verify-r11-g0-candidate-bundle.py
```

Two independent local executions in the recorded Python 3.12.3/jsonschema
4.10.3 runtime produced byte-identical output:

```text
exact campaign output sha256
  387ef9e0a9d84f56186e3b68c41c267b908e5429b414b313591b67e3e940d32e

candidate verifier output sha256
  5d62504163f0313acd87bb157974aba0e46107c604176d19b0b4c8651f923dd8
```

## Evidence Boundary

The result authority is `local_candidate_integrity_only`. The policy,
catalog, checker, runner, and manifest are still writable by one local change
authority. The checker-skip and stale-review cases validate protocol logic over
fixtures, not independent principals or attestations.

No external authority registry, final-digest review receipt, promotion runtime,
promotion verifier, or gate decision exists. Therefore:

```text
G0                              false
R11 machine-source construction false
semantic freeze                 false
TLA+ translation                false
model support                   false
Linux behavior change           false
protection claim                false
```
