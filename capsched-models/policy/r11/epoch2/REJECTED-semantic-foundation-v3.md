# Semantic Foundation v3 Rejected

The exact local K0 draft is retained unchanged:

```text
semantic-foundation-v3.md
  9fbb5fd5c5e2d4da8246114b2eb136b8795bb3c20a44801d5947cb8cf1fe1734

semantic-foundation-schema-v3.json
  4880f50071f4299bc0e88b9cf1072e551bd36a9a9894e17a33e8e945fa2585ae

semantic-foundation-v3.json
  d38891c32bd9449df60777f2e421c98549b01e56409d1bff92a6cef37fda93b4
```

Its local structural validator is:

```text
validate-semantic-foundation-v3.py
  c64ce526c11ecf3beb2ea6061449e14d94045c03b30d68af535efccbf4e12615

deterministic output SHA-256, including trailing newline
  4ee41dd00b62bc6e0121cd1978f171844d2d540433b72d7c06d04fdaa5913c12
```

The validator passes only exact structural inventories and explicitly emits
`K0_G0_complete=false`. Four read-only local reviews of the three exact v3
artifacts all returned `LOCAL_ADVISORY_REJECT`. They are not external K0
authority.

The rejection is semantic. The draft lacks a complete model body and
well-formedness relation, typed dependent `Label` and `Location` carriers,
phase provenance for variables, a unique action-body-to-closed-relation
construction, and a non-circular frame derivation. Its progress, time,
durability, distribution, composition, and two-trace sections are requirements
rather than complete satisfaction relations. It also lacks a physical-state
refinement, candidate-independent compromised-step over-approximation, and the
complete externally owned K0 source set.

See ADR-0019, Analysis 0216, and Validation 0305. Successor work is decomposed
into F0 typed calculus, F1 claim semantics, F2 platform/threat refinement, and
F3 external policy/assurance. v3 cannot authorize K0/G0, candidate IR, semantic
freeze, TLA+, model support, Linux behavior changes, or protection claims.
