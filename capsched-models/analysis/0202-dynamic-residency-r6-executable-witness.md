# Analysis 0202: Dynamic Residency R6 Executable Witness Draft

Status: rejected incomplete draft; retained only as R7 counterexample input

Date: 2026-08-09

Work record: `N-190`

Requirement: `RESIDENCY-DYN-001`

Machine draft:
`analysis/dynamic-residency-r6-preformal-multilane-witness-v1.json`

The draft enumerated the 16 counterexamples required by Analysis 0200 and
pinned the exact R6 v2 contract. Work stopped before a validator was written
because independent review found real dependency cycles, contradictory entry
predicates, incomplete transaction crash cuts, and non-total refinement in the
contract itself.

It is intentionally not repaired in place. Its scenario names and structured
fixtures are inputs to R7, while its expectations are non-normative. The old
20-scenario v1 witness is likewise only an unaffected-regression or negative
source where R6 replaced its semantics.

```text
witness_validator_written = false
negative_variants_executed = false
witness_accepted = false
architecture_frozen = false
tla_authorized = false
model_supported = false
```
