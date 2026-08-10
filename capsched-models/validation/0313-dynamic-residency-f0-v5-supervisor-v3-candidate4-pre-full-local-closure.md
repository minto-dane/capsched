# Dynamic Residency F0 v5 Supervisor v3 Candidate-4 Pre-Full Local Closure

## Result

Candidate-4 passes its bounded fast and hostile regression layer:

```text
child semantic hostile cases:     274 PASS
parent semantic hostile cases:    715 PASS
runner/receipt hostile cases:      44 PASS
total:                           1,033 PASS
fast validator: COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY
full validator: NOT_RUN
```

The fast result leaves the three full-only local claims `NOT_RUN`, all seven
external/refinement claims `OPEN_REFINEMENT`, and every F0/R11/G0/protection
authorization false.

## Commands

```sh
python3 -S -B capsched-models/validation/test-f0-supervisor-lts-v3-mutations.py
python3 -S -B capsched-models/validation/test-f0-supervisor-orchestrator-v3-mutations.py
bash capsched-models/validation/test-run-f0-supervisor-v3-full.sh
python3 -I -S -B capsched-models/validation/validate-f0-supervisor-lts-v3.py
bash -n capsched-models/validation/run-f0-supervisor-v3-full.sh
bash -n capsched-models/validation/test-run-f0-supervisor-v3-full.sh
git diff --check
```

`shellcheck` was unavailable on this host, so no ShellCheck result is claimed.

## Runner Rejection Coverage

The 44 runner cases include candidate and rejected dispositions; forged
authorization, evidence, predicate, and obligation values; unknown top-level
and nested fields; duplicate JSON keys; raw receipt/result disagreement;
receipt digest and argv mutation; worker-provenance mutation; Boolean return
codes; producer/checker union-only action coverage; unreachable commutation
actions; negative state counts; impossible source/co-enabled/both-orders count
relations; impossible commutation edge lower bounds; impossible child/parent
cardinalities; integer-like floats in the
action registry; voluntary 124 and 143 exits; deadline timeout; TERM-resistant
descendants; validator-leader-first exit; input and manifest mutation;
post-parse result mutation; missing and mismatched manifests; external signal
cleanup; and `BASH_ENV` injection including startup `set -p`, trailing script
arguments, a forged `mapfile` function, sourced/`-c` execution, and an
overridden `exit` function.

The runner validates internal agreement among the captured input manifest,
exact result schema, raw component stdout bytes, worker provenance, component
identities, test marker relations, producer/checker child action sets, parent
action counts, reachable commutation pair relations, exact witness-count
equality and nonterminal-state bounds, the immutable claim registry, and exact
obligation references. It does not
independently observe component execution; those receipts are produced by the
candidate validator.

## Disposition

The exact source set is suitable for a restartable pre-full Git checkpoint and,
after fresh review, capture by a later detached full-run mechanism. It is not a
full result. The current same-UID runner does not prove runtime write prevention,
continuous input stability, descendant containment outside its process group,
post-publication immutability, external toolchain authentication, or external
receipt attestation.

No full bounded child/parent exploration was launched in this session. No F0,
R11, G0, semantic-freeze, Linux-refinement, Monitor-refinement, performance,
cost, or protection credit follows. No Linux behavior changed.
