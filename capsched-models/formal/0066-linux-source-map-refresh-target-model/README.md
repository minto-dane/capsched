# Formal 0066: Linux Source-Map Refresh Target Model

Status: checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

Related artifacts:

```text
analysis/0088-linux-source-map-refresh-target-selection.md
analysis/linux-source-map-refresh-target-selection-v1.json
validation/0104-linux-source-map-refresh-target-selection.md
```

## Purpose

This model checks the N-133 target-selection rule:

```text
freshness gate result -> candidate comparison -> select scheduler_authority_core
as a source-map refresh target -> keep Linux patch movement blocked
```

The safe model intentionally selects a source-map refresh target, not a patch
target.

## Non-Claims

This model does not approve Linux code, runtime coverage, ABI, monitor
verification, behavior change, or production protection.
