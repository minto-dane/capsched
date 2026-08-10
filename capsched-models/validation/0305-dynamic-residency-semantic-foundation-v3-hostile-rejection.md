# Dynamic Residency Semantic Foundation v3 Hostile Rejection

## Scope

This validation records the exact local rejection of `DL-SemFoundation-3`.
It validates provenance, deterministic structural checking, and the negative
review disposition. It is not external K0 evidence and does not validate a
successor model.

## Exact Candidate

```text
semantic-foundation-v3.md
  9fbb5fd5c5e2d4da8246114b2eb136b8795bb3c20a44801d5947cb8cf1fe1734

semantic-foundation-schema-v3.json
  4880f50071f4299bc0e88b9cf1072e551bd36a9a9894e17a33e8e945fa2585ae

semantic-foundation-v3.json
  d38891c32bd9449df60777f2e421c98549b01e56409d1bff92a6cef37fda93b4
```

The local structural validator is
`c64ce526c11ecf3beb2ea6061449e14d94045c03b30d68af535efccbf4e12615`.
It read the exact v3 files plus the retained rejected v2 schema/contract and
reported:

```text
18 denotation-clause IDs
10 sort forms
6 term judgments
32 base expression-form IDs
10 model-entity IDs
5 extension IDs
16 obligation-family IDs
K0_G0_complete = false
candidate_IR = false
semantic_freeze = false
TLA_translation = false
model_supported = false
```

Two executions produced the identical output SHA-256, including newline:

```text
4ee41dd00b62bc6e0121cd1978f171844d2d540433b72d7c06d04fdaa5913c12
```

This establishes deterministic local shape checking only. The schema and
validator do not establish mathematical soundness or external authority.

## Four-Axis Result

Every read-only local review confirmed the same three candidate hashes and
returned `LOCAL_ADVISORY_REJECT`:

```text
denotation/type:
  no complete Model/WF relation; dependent Label/Location absent; action and
  frame construction open; phase laundering; incomplete AST and claim judgment

concurrency/liveness/distribution:
  request starvation; empty fair trace; invalid rank argument; remote mutable
  oracle; repeat-visible-effect crash; unsafe refund; missing lane composition

security/refinement:
  candidate-narrowable compromise action; omitted physical state; vacuous
  noninterference; weak robust integrity; platform concurrency/raw ABI gaps

assurance/backend:
  incomplete K0 source set; prose-only extensions; schema is an index rather
  than semantic IR; proof/certificate path and K0-specific trust closure absent
```

The review sessions are listed in Analysis 0216 and its machine-readable
disposition. They are local advice, not the external roles required by F3.

## Counterexample Sufficiency

Any one of these counterexamples is enough to reject K0 adoption:

1. A required `HostileLinux` name denotes only a harmless self-loop.
2. A post-state value is bound to an effect-free variable and used in `Init`.
3. `Serve(r0)` repeats forever while family fairness masks starvation of `r1`.
4. Fairness assumptions admit no trace, making response claims vacuous.
5. A visible install crashes before durable deduplication and repeats.
6. A source refunds from a mutable remote observation, then a delayed export
   installs at the destination.
7. Two locally safe lanes each consume one replicated global credit.
8. Noninterference uses an empty initial relation or constant observation.
9. DMA, IRQ, translation, or microarchitectural state is omitted from State.

These are semantic failures. More schema checks or backend agreement cannot
repair them.

## Disposition

```text
strict local structural inventory     PASS
deterministic structural output       PASS
complete typed transition calculus    FAIL
claim-extension denotation            FAIL
platform/threat refinement            ABSENT
complete K0 source set                ABSENT
external review authority             ABSENT
K0/G0                                 false
candidate IR                          unauthorized
semantic freeze                       false
TLA+/solver work                      unauthorized
model support                         false
```

ADR-0019 authorizes only F0 v4 design. The exact v3 files remain unchanged and
rejected. No Linux behavior, Monitor implementation, protection, performance,
cost, scalability, cluster, or deployment claim follows from this validation.
