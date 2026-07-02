# TCB Boundary Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This N-152 model closes the model-only blocker for `TCB-001`.

It does not count implementation lines. Instead, it defines the semantic TCB
boundary that future implementation and evaluation must respect:

```text
HyperTag Monitor:
  owns roots only
  exposes typed/sealed interfaces only
  excludes drivers, parsers, policy engines, and Linux mutable state

service Domains:
  receive authority only through typed endpoints
  use least authority
  do not gain ambient access to caller or target Domains

comparison envelope:
  TCB budget is declared
  VM/VMM comparison dimensions are explicit
```

## Non-Claims

This model supports the TCB boundary as a model artifact. It is not monitor
implementation, line-count evidence, runtime validation, production protection,
or cost-efficiency evidence.
