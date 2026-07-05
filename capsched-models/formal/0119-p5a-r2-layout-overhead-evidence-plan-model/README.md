# P5A-R2 Layout and Overhead Evidence Plan Model

This model gates the evidence contract before a future P5A-R2 selector patch
can add hot scheduler fields or alter picker/update paths.

The safe path reaches `EvidencePlanReady` only when the plan separates CONFIG
off, CONFIG on but selector disabled, CONFIG on candidate enabled, and runtime
evidence. It also requires layout probes, object/function/symbol diffs, zero
CONFIG-off delta rules, explicit non-zero hot delta review, runtime tests for
runtime claims, and non-claim guards.

The unsafe configs each remove a required evidence class or add a forbidden
claim.
