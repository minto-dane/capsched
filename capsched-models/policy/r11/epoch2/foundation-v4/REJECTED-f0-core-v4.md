# F0 Core Calculus v4 Rejected

The exact local F0 review target is retained unchanged:

```text
f0-core-calculus-v4.md
  177ae3e0a860b808fd49a5bd93d03adc74d5b56f9950d1d257fa63e8fb6c7d9c
  24915 bytes

f0-review-target-v4.json
  a2b56d0a2d1f80ac1d45ad4e6612d6005bf7191781d3a7cb5dbf084e6daaef12
```

Its local identity/shape checker and mutation runner are:

```text
validate-f0-review-target-v4.py
  06f3871b9f4744f5d811700e5d13060f5e1e1063f2ab168b93144ac36a43aa6c
  deterministic output SHA-256 058c0612362f9e20a789bf25b4b8e0f802e208b9a8504b0b5650c36c26559199

test-f0-review-target-v4-mutations.py
  723ac1af83a7db89cc346d532837e8029d772982f228cca23a0e66fd029fd67d
  21/21 mutations rejected at the expected ID
  deterministic output SHA-256 eff57e1bd77d3e2d9bd5aba670ca48ab1d07da2d8b9ed9ab05bf31356c56d09c
```

Four exact-hash, read-only local reviews returned `LOCAL_ADVISORY_REJECT`.
They are not external authority. The principal blockers are an unconstructible
event term, unbound parameter provenance in state invariants, candidate-owned
action omission, undefined read instrumentation, coarse nested-map locations,
empty admissible model classes, claim-unbound nonvacuity, false event inversion,
and undefined extension/platform morphisms.

See ADR-0020, Analysis 0217, and Validation 0306. v4 cannot authorize F0 local
acceptance, F1, F2, F3, K0/G0, candidate IR, semantic freeze, TLA+, model
support, Linux behavior changes, or protection claims.
