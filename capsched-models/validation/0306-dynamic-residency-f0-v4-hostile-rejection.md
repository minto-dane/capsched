# Dynamic Residency F0 v4 Hostile Rejection

## Scope

This validation records exact local negative evidence for the first F0 v4
typed-calculus draft. It does not validate F0 v5 and has no external K0
authority.

## Identity and Structural Checks

```text
source
  177ae3e0a860b808fd49a5bd93d03adc74d5b56f9950d1d257fa63e8fb6c7d9c
  24915 bytes

review manifest
  a2b56d0a2d1f80ac1d45ad4e6612d6005bf7191781d3a7cb5dbf084e6daaef12

identity/shape checker
  06f3871b9f4744f5d811700e5d13060f5e1e1063f2ab168b93144ac36a43aa6c
  repeated output 058c0612362f9e20a789bf25b4b8e0f802e208b9a8504b0b5650c36c26559199

mutation runner
  723ac1af83a7db89cc346d532837e8029d772982f228cca23a0e66fd029fd67d
  21/21 rejected at exact expected IDs
  repeated output eff57e1bd77d3e2d9bd5aba670ca48ab1d07da2d8b9ed9ab05bf31356c56d09c
```

The 21 mutations cover duplicate/unknown keys, null/float values, source and
predecessor drift, clause loss/duplication, review identity/authority forgery,
and local/K0/candidate-IR promotion forgery. This is structural fail-closed
evidence only.

## Semantic Review

Four read-only local reviews confirmed the exact source hash and independently
returned `LOCAL_ADVISORY_REJECT`.

Blocking counterexamples include:

1. No grammar production can construct the mandatory `EventTerm`.
2. A Boolean action parameter type-checks as a state invariant but has no value
   when the invariant is evaluated on a state.
3. An instrumenter returning the right value and an empty read set satisfies
   the only displayed instrumentation law.
4. Infinite unordered quantification cannot produce the required ordered read
   trace.
5. A declared compromise action can be omitted from candidate-owned
   `RequiredActionSet` or guarded by false.
6. A whole authority map nested in one value becomes one coarse write location.
7. Two actions or parameters can emit the same event, refuting event inversion.
8. Inconsistent constant constraints make the admissible interpretation class
   empty and all universal claims vacuous.
9. A dangerous branch can be reachable only in an unrelated profile while the
   claimed profile never exercises it.
10. An empty assumption-filtered execution set can satisfy every later response.
11. One-way extension projection can suppress every base behavior while still
    being called conservative.
12. A single event cannot carry independent base, timing, durability, receipt,
    and lane observations compositionally.

The finite point-write fold and outer-cell frame theorem themselves survive,
but only at the declared granularity and after the typing/evaluation repairs.

## Disposition

```text
exact target identity                  PASS
structural/authority mutation campaign PASS 21/21
constructible closed term grammar      FAIL
state/action parameter typing          FAIL
all-action closure                     FAIL
footprint denotation                   FAIL
security state granularity             FAIL
inhabited claim scopes/nonvacuity       FAIL
extension/refinement morphisms          FAIL
F0 proof-object/checker boundary        ABSENT
F0 local acceptance                    false
F1/F2/F3                               unauthorized
K0/G0                                  false
candidate IR/TLA+                      unauthorized
model support                          false
```

ADR-0020 and Analysis 0217 authorize only an F0 v5 successor. No Linux behavior,
Monitor implementation, protection, performance, cost, scale, cluster, or
deployment claim follows.
