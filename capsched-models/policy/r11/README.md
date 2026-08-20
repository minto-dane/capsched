# DomainLease R11 Policy and G0 Bundle

Updated: 2026-08-09

## Current Disposition

`g0-candidate-bundle-v1.json` is the exact rejected local snapshot:

```text
byte length  7073
sha256       bcdd6c26c5a651f7630df5d218cbd6fb2f20922e2e03cdf109b68b69a7250037
authority    role_separated_local_candidate_not_external_approval
G0           false
```

The manifest captures 17 artifacts by path, role, media type, byte length, and
raw-byte SHA-256. It does not contain its own digest; reviewers bind the raw
manifest digest shown above.

Three local hostile reviews rejected the snapshot. Deterministic negative
tests then showed that 12 semantic weakenings pass the checker and five forged
positive review/gate documents pass their schemas. The snapshot was therefore
rejected before external review. See `REJECTED-v1.md`, ADR-0017, Analysis 0214,
and Validation 0303.

## Evidence Layers

Evidence is acyclic:

```text
L0 candidate bundle
  -> L1 three authority-disjoint review receipts
  -> L2 independent exact campaign and gate decision
  -> L3 evidence capsule
```

Each layer binds only predecessor bytes. A gate decision never hashes a capsule
that already contains that same decision.

## Semantic Inputs

- `semantic-policy-v1.json`: trust, writer, authority, resource, entry,
  revocation, async, settlement, provider, invariant, progress, and mutation
  meaning.
- `semantic-rule-registry-v1.json`: 73 stable `SEM-*` rules and candidate
  binding requirements.
- `scenario-profile-v1.json`: 19 fixed finite profiles covering W0-W12,
  including distinct/aliased async, three transfer outcomes, three partition
  policies, namespace reclaim, and restart reconciliation.
- `g0-review-contract-v1.json`: exact G0 checks, reviewer assignments,
  externality rule, evidence-layer DAG, and the narrow allowed output.

## Local Mechanical Evidence

Run:

```bash
python3 capsched-models/validation/validate-r11-g0-policy-profile.py
python3 capsched-models/validation/run-r11-g0-exact-campaign.py
python3 capsched-models/validation/verify-r11-g0-candidate-bundle.py
```

The exact campaign executes all 12 G0 mutations, including checker-coverage and
stale-review protocol mutants. The candidate verifier snapshots all 17
artifacts and reruns that campaign. Repeated output is byte-identical in the
recorded local runtime.

## External Review Boundary

The v1 schemas for external review receipts and the gate decision are present,
but they are insufficient. They permit failed or duplicate check results, open
blockers with a zero count, duplicate roles, and self-asserted independence.
Schema validation is only a shape prefilter; acceptance requires an executable
verifier over an externally rooted authority registry and canonical signed
payloads.

A separate directory, a separate AI context, or a local validator does not
satisfy externality. Local hostile reviews are advisory only.

## Current Authorization

```text
local byte integrity and regression evidence  yes
external policy/profile adoption              no
G0                                             no
R11 machine-source construction               no
semantic freeze                               no
TLA+ translation                              no
model-supported claim                         no
Linux behavior or protection claim            no
```

Successor work uses a new `epoch2/` namespace and must provide executable
external semantic templates, typed candidate bindings, exact writer and
branch products, generated scenario/cut semantics, exhaustive semantic
mutations, and a real promotion verifier. The captured v1 files are not
modified in place.
