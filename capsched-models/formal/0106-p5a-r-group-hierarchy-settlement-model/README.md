# P5A-R Group Hierarchy Settlement Model

This model backs the pre-code group hierarchy settlement gate for P5A-R.

It separates leaf-task denial from parent group skipping. A parent group entity
may be skipped only after the child cfs_rq has an explicit exhaustion proof for
the current attempt. The model rejects parent over-denial, task_of() on group
entities, accounting aliases as child exhaustion, path evidence as positive
authority, and behavior/protection/cost overclaims.
