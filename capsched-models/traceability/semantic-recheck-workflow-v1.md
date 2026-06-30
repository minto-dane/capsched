# Semantic Recheck Workflow v1

Status: Draft workflow, source-only

Date: 2026-06-30

## Purpose

This workflow handles central overlay rows whose source drift state cannot be
used directly for implementation decisions:

```text
line_only anchors
symbol_missing anchors
pattern_missing anchors
preserved gap or plan rows
```

It does not validate production protection. It only prevents weak source anchors
from being accidentally treated as semantic evidence.

## Recheck Classes

| Class | Meaning | Required action |
| --- | --- | --- |
| `line_only_anchor` | The old artifact recorded a line without a symbol or literal pattern. | Replace with a symbol/pattern anchor or mark as intentionally path-only. |
| `symbol_missing` | A declared symbol no longer appears in the declared source path. | Find rename/move/removal and decide whether the semantic obligation changed. |
| `pattern_missing` | A declared literal or descriptive pattern does not match. | Replace descriptive phrases with machine-checkable predicates or downgrade to path-only. |
| `gap_or_plan` | The row records a future gap, external monitor responsibility, or trace plan. | Preserve as a gap until a separate artifact supplies authority or observation evidence. |

## Required Output

Each recheck item must produce one of:

```text
rechecked_anchor:
  updated path/symbol/pattern/line and evidence class

intentional_gap:
  preserved obligation and explicit future owner

deprecated_anchor:
  old anchor no longer maps to useful source evidence

needs_model_update:
  source movement changes the semantic model or proof obligation
```

## Hard Rules

```text
No recheck row may claim authority.
No recheck row may claim monitor verification.
No recheck row may claim runtime coverage.
No recheck row may claim production protection.
No line-only row may become ok without a symbol, pattern, or explicit path-only downgrade.
No gap row may be removed merely because source does not exist.
```
