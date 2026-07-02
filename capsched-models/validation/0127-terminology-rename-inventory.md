# Validation 0127: Terminology Rename Inventory

Status: Source-only inventory executed; no model or protection claim

Date: 2026-07-02

## Scope

This validation records the mechanical inventory used by N-156.

It scanned old vocabulary across:

```text
docs
JSON/JSONL
TLA
TLC cfg
AI state and handoff memory
assurance records
Linux scaffold
file names
```

## Counts

| Area | CapSched | CAPSCHED | capsched | RunCap | FrozenRunUse | SchedContext | DomainTag | HyperTag |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Markdown docs | 971 | 194 | 1459 | 247 | 226 | 237 | 122 | 153 |
| JSON/JSONL | 108 | 39 | 5880 | 54 | 37 | 32 | 19 | 27 |
| TLA modules | 5 | 0 | 27 | 137 | 51 | 9 | 0 | 0 |
| TLC cfg files | 4 | 0 | 0 | 19 | 2 | 4 | 0 | 0 |
| AI state/memory | 106 | 42 | 5987 | 61 | 46 | 48 | 25 | 40 |
| Assurance subset | 37 | 5 | 129 | 17 | 19 | 10 | 1 | 21 |
| Linux scaffold | 4 | 8 | 28 | 3 | 1 | 1 | 1 | 0 |
| File names | 2 | 2 | 2 | 5 | 2 | 2 | 0 | 29 |

## Interpretation

The inventory supports this rename strategy:

```text
do not mechanically rewrite all historical artifacts
do freeze a new public vocabulary
do keep legacy aliases for traceability
do rename the inert Linux scaffold to mainline-facing names
```

## Non-Claims

This inventory is not semantic validation, model revalidation, Linux behavior
validation, runtime coverage, monitor verification, or production protection
evidence.
