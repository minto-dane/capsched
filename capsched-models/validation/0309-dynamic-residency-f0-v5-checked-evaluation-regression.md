# Dynamic Residency F0 v5 Checked Evaluation Regression

## Result

The local construction validates source-derived checked occurrences, immutable
request/context identities, finite Eval/DynDeps/MayDeps behavior, and exact
non-authorizing result classification. It does not validate the complete F0
semantics or a hostile-input-ready validator.

```text
42 evaluator constructors:                         covered locally
eval-rule hostile mutations:                       380/380 expected rejection
checked-occurrence hostile cases:                  15/15 expected rejection
checked-request/context cases:                     22/22 expected classification
captured implementation executed directly:         false
whole-pipeline resource envelope:                  incomplete
external worker supervisor:                        absent
result taxonomy closed:                            false
F0 local acceptance:                               false
```

## Reproduction

```bash
python3 capsched-models/validation/validate-f0-eval-dependency-rules-v5.py
python3 capsched-models/validation/test-f0-eval-dependency-rules-v5-mutations.py
python3 capsched-models/validation/test-f0-eval-v5.py
python3 capsched-models/validation/test-f0-checked-term-occurrences-v5.py
python3 capsched-models/validation/test-f0-checked-eval-v5.py
```

The final command is intentionally heavier because hostile external-artifact
cases reexecute wire, static, link, and occurrence construction. A future
immutable session capsule may amortize that work only if its context and source
identities remain exact.

## Negative Boundary

The campaign includes a rehashed provenance forgery, caller term injection,
missing/extra parameter or views, linked substitution, unknown occurrence,
request/context ID substitution, duplicate keys, profile/model mismatch,
requester and operator resource exhaustion, module-graph replacement, forbidden
post-context filesystem reads, generic host failures, and result self-promotion.

An injected Unsupported exception checks dispatch only. There is no genuine
end-to-end unsupported finite feature in the current support domain, so the
unsupported branch and overall taxonomy remain unclosed. No test pass supplies
metatheory, external review, F0 acceptance, G0, or protection evidence.
