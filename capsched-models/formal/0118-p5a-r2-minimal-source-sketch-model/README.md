# P5A-R2 Minimal Source Sketch Model

This model gates the source-facing sketch for a future P5A-R2 selector patch.

The safe path reaches `SketchReady` only when the sketch:

- piggybacks the existing EEVDF augmented rb-tree,
- uses a `min_pickable_vruntime`-style sentinel summary,
- keeps current and group entities semantically separate,
- rejects the experimental `0012` fallback as production structure,
- requires invalidation, layout, overhead, runtime, replay, and security
  evidence before any Linux behavior patch.

The unsafe configs each remove one required condition or add a forbidden claim.
