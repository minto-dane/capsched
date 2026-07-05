# P5A-R2 Layout Probe Patch Plan Model

This model gates the future no-behavior `0013` layout probe patch plan.

The safe path reaches `PatchPlanReady` only when the patch remains a
build-only probe, stays absent from normal CONFIG off/on builds, does not add
runtime call sites or public ABI, and preserves the claim boundary that layout
evidence is not runtime/protection/cost evidence.

The unsafe configs each remove one required evidence class or introduce one
forbidden claim.
