# N-Series Overlay Traceability Policy

Updated: 2026-06-30

## Fixed Policy

The N-series is a chronological work ledger.

The N-series is not:

- a requirement namespace
- a threat namespace
- an invariant namespace
- a Linux source-anchor namespace
- a validation namespace
- a patch namespace
- an assurance-claim namespace

Those meanings live in overlay indexes.

This rule applies equally to:

```text
N-001 through N-105:
  historical work that will be indexed by overlay rows

N-106 and later:
  future work that will also be indexed by overlay rows
```

Future N records should not grow a new embedded schema. They remain readable as
plain chronological work items. The overlay row is the place for semantic
classification, source anchors, validation class, drift status, and claim
limits.

## Why Not Rewrite Old N Items

Rewriting N-001 through N-105 would create false continuity. It would make the
old records look as if the current vocabulary existed from the beginning.

Instead, the project records vocabulary maturation explicitly:

```text
ADR-0006:
  invariant-driven design with tag-indexed evidence

ADR-0007:
  overlay traceability for N-series and Linux anchors
```

The historical record remains honest, and the overlay makes it searchable.

## Why Future N Items Still Use The Overlay

If N-106 and later embedded the new vocabulary directly, readers would see two
different N formats. That is also confusing.

Therefore the same overlay style is used for all N items. The only operational
difference is timing:

```text
historical N item:
  overlay row may be added later

future N item:
  overlay row should be added during the work or before completion
```

This is one model, not two.

## Minimal Overlay Row

A useful overlay row should include:

```text
row id
N ids
artifact paths
relation
evidence class
semantic ids touched
Linux anchors and checked commits
drift status
supported claim ids
explicitly unsupported claim ids
safety flags
next action
```

## Relationship Rules

Allowed relation vocabulary:

```text
documents
observes
anchors
checks
models
refines
blocks
falsifies
supersedes
forbidden_upgrade
```

`N-* supports CLAIM-*` is not allowed as a direct relationship.

Use:

```text
N-* -> artifact -> VAL/MODEL/LINUX/PATCH -> CLAIM-*
```

and only when the evidence class permits the claim.

## Linux Anchor Rules

Every Linux source anchor must carry a commit.

Useful fields:

```text
upstream_base_commit
work_commit
last_checked_commit
source_path
symbol_or_pattern
anchor_class
anchor_kind
blob_oid
drift_status
```

Drift status values:

```text
ok
path_changed
symbol_missing
pattern_missing
semantic_recheck_required
gap
deprecated
unknown
```

When upstream changes:

- unchanged source blob can remain `ok`
- changed source blob should become `semantic_recheck_required`
- missing path should become `path_changed`
- missing symbol or pattern should become `symbol_missing` or
  `pattern_missing`
- missing anchor remains a gap, not an obligation removal

## Safety Defaults

Every source-only or observation-only row defaults to:

```text
authority_claim=false
monitor_verified=false
protection_claim=false
behavior_change=false
public_abi=false
```

Any row that changes these defaults must explain the non-forgeable root,
threat-model link, invariant link, validation evidence, and assurance approval.

## Existing Linux-Kernel Correspondence

The project already has many Linux-kernel correspondence artifacts, including:

- `analysis/0001-source-map.md`
- scheduler authority and budget maps
- fork/clone/exec/exit identity maps
- workqueue and io_uring provenance maps
- modern NIC, IOMMU, VFIO, DMA, IRQ, page-pool, representor, and service-work
  source maps
- direct-call attachment and source-only inventory maps

These are topic-local maps. They are not yet a central drift-aware ledger.

## Next Traceability Work

The next traceability work should not change Linux.

It should:

1. Create an initial overlay ledger from `state.json` and `events.jsonl`.
2. Seed rows for N-103 through N-106 because they are the current active
   direct-call/Linux-anchor area.
3. Add rows for older high-value source-map families incrementally.
4. Add an anchor drift checker that compares path, symbol/pattern, and blob
   state after upstream updates.
5. Keep all source-only rows non-authoritative unless a separate monitor-backed
   proof and assurance gate exists.
