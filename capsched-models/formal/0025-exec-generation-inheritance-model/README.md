# Exec Generation and Inheritance Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0042-exec-generation-inheritance-semantics.md
```

## Purpose

This model captures the exec generation rule:

```text
exec does not automatically change CapSched Domain, but successful exec is a
new program-generation boundary for endpoint, async, mmap, notification, and
process-image-scoped authority.
```

## Modeled Hazards

```text
exec changing Domain without explicit monitor-backed transition token
post-exec run without same-domain ExecContinuation and live SchedContext
old FrozenEndpointUse authorizing post-exec endpoint effects
surviving non-CLOEXEC fd reachability treated as post-exec authority
CLOEXEC endpoint leaking into the new program image
credential or LSM domain change amplifying inherited endpoint authority
execfd handoff to interpreter without derived endpoint authority
old program-generation async work producing effects after exec
old mmap/page-fault authority surviving into the new mm
AT_EXECVE_CHECK mutating generation or deriving post-exec authority
```

## Checked Invariants

```text
NoExecDomainChangeWithoutToken
NoRunAfterExecWithoutContinuation
NoOldEndpointUseAfterExec
NoSurvivingFdWithoutDerivation
NoCloseOnExecLeak
NoCredChangeEndpointAmplification
NoExecfdWithoutDerivation
NoOldAsyncUseAfterExec
NoOldMmapAcrossExec
NoCheckOnlyMutation
```

## Scope Limit

This is not a full Linux exec, binfmt, LSM, VFS, io_uring, or MM model. It
abstracts the successful exec commit boundary and the post-exec authority
inheritance hazards into a design filter.

The model intentionally separates:

```text
DomainGeneration:
  stable across ordinary exec

ProgramGeneration:
  incremented on successful exec and used to invalidate old program-scoped
  endpoint, async, mmap, and notification authority

ExecContinuation:
  the reason the current task can keep running after its ProgramGeneration
  changes
```
