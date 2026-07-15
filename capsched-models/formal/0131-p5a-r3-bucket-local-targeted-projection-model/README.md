# Formal 0131: P5A-R3 Bucket-Local Targeted Projection

Date: 2026-07-15

Status: successor architecture model. No Linux source or runtime/protection
claim is approved.

The model replaces the rejected P5A-R2 full locked rebuild with one
authority-equivalent bucket projection per affected rq. It exercises:

```text
an existing runnable contribution before publication
release publication of a bucket revoke
pre-fanout picker generation fencing
an enqueue after the publisher's active-rq snapshot
one-bucket targeted work under one rq lock
a stable worker commit
a publication racing an in-flight worker with a fresh active-rq snapshot
final picker revalidation
old-rq neutral destination-rq migration settlement
lifetime behavior with or without pending work
```

The insertion handshake proves the no-missed-rq split:

```text
enqueue before snapshot -> selected by targeted fanout
enqueue after snapshot  -> observes the new generation and cannot publish old Fresh
```

The dynamic invariants require:

```text
every active rq is snapshotted/queued or already observes current generation
trusted projection is Fresh, current-generation, eligible, and final-rechecked
worker holds rq lock
at most one bucket update and no leaf scan per lock interval
raced old-generation work never commits Fresh
migration never contributes to both old and destination rq
bucket is not freed with active membership or pending work
```

Thirty-four generated unsafe configurations inject a missing E4 boundary,
bucket-key/index/handshake/locking/lifetime property, forbidden work shape,
cross-path gap, premature Linux approval, or overclaim. Every unsafe
configuration must violate `Safety`.
