# Notes: Page Cache Overlay Conflicts

Date: 2026-06-26

## Why This Exists

The ordinary Linux page cache is a shared mutable performance structure. For
CapSched-H, it must not become a cross-Domain authority channel.

This model isolates three concepts:

```text
sealed base:
  shared, immutable, versioned file/cache content

Domain overlay:
  mutable per-Domain dirty state

service commit:
  writeback/merge action requiring caller provenance and service authority
```

## Conflict Rule

An overlay records the base version it was created from. If another overlay
commits first and advances the sealed base version, the stale overlay cannot
commit silently.

```text
overlay base version == current base version:
  commit may start

overlay base version != current base version:
  commit cannot start; queued work may be marked conflict
```

This is not a full filesystem merge protocol. It only records the security
rule: stale mutable Domain state must not overwrite a newer sealed base through
ambient Linux page-cache authority.

## First Counterexample

The first TLC run found a real conflict bug:

```text
two overlays are dirty against the same sealed base version
both enter committing
one finishes and advances the base version
the other remains a stale committing overlay
```

The model fix is base-level commit serialization:

```text
Only one overlay may be committing for a given sealed base.
```

Production implementations can realize this with a service-Domain merge lock,
address_space/inode-level commit serialization, or monitor-backed commit token.
The exact mechanism is undecided, but the invariant is not: a stale overlay
must not be able to commit after another overlay has advanced the base.

## Final TLC Result

After the serialization fix, TLC completed the finite model:

```text
Model checking completed. No error has been found.
7370677 states generated
524808 distinct states found
0 states left on queue
depth: 26
fingerprint collision estimate:
  calculated optimistic: 1.9E-7
  actual fingerprints: 1.3E-8
```

## Non-Goals

This model does not prove:

```text
filesystem consistency
POSIX write semantics
mmap coherence
direct I/O invalidation
truncate/hole-punch behavior
writeback error propagation
real XArray locking
real address_space implementation
```

Those are later implementation-specific gates. This model is only the semantic
security skeleton for Domain page-cache overlays.
