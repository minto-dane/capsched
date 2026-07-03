# P5A-R Cross-Path Exclusion/Settlement Model

This model backs the pre-code cross-path gate for P5A-R.

It permits an ordinary-CFS-only implementation direction only when non-ordinary
CFS paths are excluded or separately settled. It rejects core scheduling cached
picks, sibling picks, cookie replacement/steal, deadline server borrowing,
proxy donor/executor collapse, sched_ext/switched-all bypass, unsupported class
fallback, RETRY_TASK-as-denial, and behavior/protection/cost overclaims.
