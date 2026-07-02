# P4 Allow-All Helper Gate

This model captures the P4 rule:

```text
P4 production helper return set == { ALLOW }
```

Non-allow enum values may exist as type vocabulary, comments, model text, or
future P5 test-only code after separate approval. They must not be reachable
from P4 scheduler control flow.

The safe state also keeps P4 implementation unapproved. This gate closes the
pre-implementation allow-all/no-denial proof contract only; the actual P4 patch
still requires generated-code review, build validation, QEMU validation, and
overclaim/security review.
