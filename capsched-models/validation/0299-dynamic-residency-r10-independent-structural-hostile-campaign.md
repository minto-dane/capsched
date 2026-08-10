# Dynamic Residency R10 Independent Structural Hostile Campaign

## Exact Inputs

- Candidate source: `ad463ae92004e962cbe8719073453aba4f60345e0c8099683a2b858268ef6f97`
- Schema: `9764d711c14f41de07185a359814522ddca563b0e52593f3c6b4334e75fcfadf`
- Validator: `a6c5a541259ef6eb29f0f16da222d065f126f6311de22edae9f4c6577c836e7e`
- R9 disposition: `509378203b8dc4009054487585da1ae82a38bde713f3bd539545120e8a4b8d5c`
- External catalog: `d78b1b5c560e967ca1fae5a9395956fa96039a342a2c4d3aa888bf92d3bed6d9`
- Independent runner: `1396587dde76e0fea1e28c6ef1cdafbbbefed0d0957db818185cd71b74c8b19a`
- Result: `afaeea3b2bdf30f01f8962bdb42df5a6e7ed488b5d6ae10ddb27c29d07352db1`

## Result

The runner captured each input once, re-executed the captured runner, and used
a fresh captured-validator subprocess for every baseline and mutant. Two fixed
shuffled repetitions accepted both baselines and rejected all 58 executions of
29 structural mutants at the exact external-catalog reject ID.

Six aggregation meta-mutants were also rejected: skipped case, duplicate
result, forged deterministic result, nondeterministic repetition, constant
source hash, and stale source hash.

## Authority Boundary

Result authority is exactly `development_regression_only`. This campaign does
not cover semantic-vacuity mutants, independently parsed imports, runtime or
sandbox attestation, reviewer signatures, or an external promotion decision.
It does not authorize semantic closure, architecture freeze, TLA+, model
support, Linux refinement, or a protection claim.
