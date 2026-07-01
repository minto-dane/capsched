# Formal 0074: F1 Admission-Freeze Refresh Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model checks the refreshed F1 admission-freeze boundary in
`analysis/0096`.

The core rule is:

```text
Fail-capable runnable authority resolution must finish before TASK_WAKING,
remote wake-list publication, or enqueue-visible publication.
```

After publication, CapSched may only cheaply validate the frozen tuple or
fail-closed without losing the Linux wakeup.

## Required Meaning

```text
TASK_WAKING requires FrozenRunUse.
wake_list publication requires FrozenRunUse.
enqueue-visible state requires FrozenRunUse.
running requires a complete frozen tuple and cheap validation.
raw mutable cap handles never cross publication.
heavy authority lookup never occurs after publication.
late denial must not lose the Linux wakeup.
placement/current/fork paths do not mint runnable authority.
```

## Forbidden

```text
TASK_WAKING before freeze
wake_list before freeze
enqueue before freeze
run with missing generation, Domain epoch, SchedContext, placement, or budget
raw capability handle after wake publication
heavy lookup after wake publication
late denial that loses a wakeup
placement result as authority
current/self-wake continuation as authority mint
fork initial runnable state as ambient authority
protection claim without implementation
```

## Validation

Recorded in:

```text
validation/0113-f1-admission-freeze-refresh-tlc.md
```
