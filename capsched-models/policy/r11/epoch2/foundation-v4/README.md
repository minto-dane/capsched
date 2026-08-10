# R11 Epoch-2 Foundation v4

Status: first F0 v4 draft rejected; F0 v5 successor required

ADR-0019 decomposes the successor to rejected `DL-SemFoundation-3` into:

```text
F0  typed transition calculus and metatheory
F1  claim-specific semantics and composition
F2  platform refinement and threat over-approximation
F3  external policy, coverage, mutation, proof, and assurance package
```

The exact first F0 v4 draft is retained unchanged after four local exact-hash
reviews returned `LOCAL_ADVISORY_REJECT`. Its identity checker and 21 structural
mutations pass, but the semantic calculus does not. See
`REJECTED-f0-core-v4.md`, ADR-0020, Analysis 0217, and Validation 0306.

Only F0 v5 design is currently authorized. Files in this directory are not K1
candidate architecture IR and cannot promote themselves. F1 starts only after
an exact F0 interface survives hostile review; F2 and F3 follow their
predecessor interfaces. A complete F0-F3 source set still requires a real
external K0 decision before candidate construction.

Rejected F0 target:

```text
f0-core-calculus-v4.md
f0-review-target-v4.json
```

No interpreter, translator, TLA+ model, Linux behavior patch, Monitor code, or
protection claim is authorized by this directory.
