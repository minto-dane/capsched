# Static Final-Run Observability Gate

This model separates static final-run anchor observability from runtime
coverage.

The safe state records:

```text
static anchor exists before rq->curr publication
existing P3 note_switch marker exists after rq->curr publication
runtime final-run coverage is not proven
P4 implementation is not approved
```

The unsafe configurations reject using static source proof as runtime coverage,
using the P3 post-publication marker as the precommit anchor, approving P4
implementation, approving runtime denial, or making protection/cost claims.
