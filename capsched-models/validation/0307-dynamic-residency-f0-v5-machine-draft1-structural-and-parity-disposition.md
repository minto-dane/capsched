# Dynamic Residency F0 v5 Machine Draft-1 Structural and Parity Disposition

## Result

```text
structural baseline: PASS
hostile structural mutations: 38/38 expected rejection
Markdown/AST parity review: REJECT
F0 local acceptance: false
K0/G0: false
```

The baseline checker result is
`construction_draft_shape_passed/local_structural_consistency_only`. It does
not claim semantic, proof, or parity validation.

## Reproduction

```bash
python3 capsched-models/validation/validate-f0-machine-grammar-v5.py
python3 capsched-models/validation/test-f0-machine-grammar-v5-mutations.py
```

At disposition time the exact identities were:

```text
grammar e8a8436845a6a0c97fae9be37883babaf565a8ecde4a94f5c7be61247d4899b6
meta-schema 8bcf8f2d9361c7a90cced188756c0b3fc6aae0ed20e63e83a0290b56b9999508
checker bb1975251c1329f786275da22e697e4655919f0a6044127df1fdca71611d0373
mutation runner 99e06a9294a939ae59f06b88b7dbc89831d79d9a7a8f57601b7fb3fa32f99402
```

The working construction may now differ because ADR-0021 authorizes a
successor. The hashes above identify the rejected draft and are not rolling
aliases.

## Why Structural PASS Did Not Promote

The checker established parser, meta-schema, path, heading, symbol, kind,
union, binding, forbidden-tag, completion, and authorization consistency. It
did not establish that the AST represented every normative constructor or
judgment. Independent review produced concrete counterexamples, including an
unbound action parameter and exact scope narrowed to finite profiles.

Therefore the only valid transition is to a distinct successor construction.
No claim, candidate IR, backend translation, Linux behavior, or protection
state is authorized.
