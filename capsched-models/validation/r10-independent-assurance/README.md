# R10 Independent Hostile Assurance

Status: development assurance only; no promotion authority

This directory is outside the candidate model directory. Its catalog, runner,
and results are not imported by `materialize-r10.py` and do not use the
materializer's Python API, parser, canonicalizer, hashing, or publication
helpers.

`run-independent-hostile.py` captures every input byte once, creates a private
snapshot, re-executes the captured runner, and invokes a captured materializer
in a fresh subprocess for the baseline and every mutant. The catalog pins the
exact candidate inputs and owns expected outcomes. Candidate-side
`mutation_obligations` are informational only.

The suite remains local engineering evidence. It does not become promotion
evidence until a separately pinned promotion verifier authenticates the
runner, catalog, result, runtime, imports, and independent review decisions.

Run the exact v1 campaign:

```text
python3 capsched-models/validation/r10-independent-assurance/run-independent-hostile.py
```
Write or check the generated result only after the exact catalog inputs match:

```text
python3 capsched-models/validation/r10-independent-assurance/run-independent-hostile.py --write-evidence
python3 capsched-models/validation/r10-independent-assurance/run-independent-hostile.py --check
```
