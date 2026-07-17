# Formal 0123: P5A-R2 Versioned Global Invalidation Fence

Date: 2026-07-13

Status: shared-invalidation contract model. No Linux patch or runtime/protection
claim is approved.

The model checks a conservative global generation fence:

```text
shared state is written before release-publishing a new generation
picker trust requires an acquire-observed matching per-rq built generation
old summaries are untrusted before asynchronous fanout arrives
every online rq is rebuilt under its rq lock
only a complete rebuild can publish Fresh
generation is rechecked before Fresh publication
a publication racing rebuild leaves the rq Stale
```

It also rejects generation wrap reuse, picker scans/rebuilds, picker monitor
calls, per-pick selector generations, targeted fanout without an index proof,
shared events bypassing the fence, missing queue-mutation integration, and
premature runtime/protection/cost claims.

The safe model includes both a stable rebuild and a publication racing the
rebuild. The latter must not publish an old target generation as Fresh.
Twenty-four unsafe configurations inject one missing fence property or
forbidden claim and must produce a `Safety` counterexample.
