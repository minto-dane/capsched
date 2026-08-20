# ADR-0023: Intentionally Public Repositories and Secret-Free Checkpoints

Status: Accepted; supersedes only the private-visibility part of ADR-0010

Date: 2026-08-10

## Context

ADR-0010 selected a superproject, project-control/model repository, and Linux
patch queue while assuming private GitHub visibility. The owner has since made
all three repositories public intentionally. Treating that visibility as an
error would make recovery state contradict the publication decision.

The repository topology and patch-queue rationale remain useful. Only the
visibility and disclosure policy change.

## Decision

The following repositories are intentionally public:

```text
minto-dane/linux-cap
minto-dane/capsched
minto-dane/capsched-linux
```

The superproject continues to pin the other two repositories as submodules.
The patch queue continues to record an upstream base and a reviewable delta
instead of vendoring the full upstream Linux history.

Every published checkpoint must be secret-free. Credentials, access tokens,
private keys, signing keys, private operational data, and machine-local secret
configuration are forbidden. Historical local paths and public source/build
provenance may remain when they are evidence, but they are not portable command
defaults for the current recovery path.

## Guardrails

- Public visibility is not a model, implementation, or protection gate.
- Do not infer F0, R11, K0/G0, Monitor, Linux, cost, or deployment authority
  from publication.
- Scan the pending checkpoint for common credential/key forms before push.
- Keep generated build output and heavyweight Linux trees outside Git.
- Preserve rejected artifacts and historical terminology as evidence; do not
  rewrite history merely to remove the old private-repository description.
- Current front-door documentation and machine state must describe public
  visibility accurately and point to secret-free recovery commands.

## Consequences

A fresh machine may clone the public superproject recursively without GitHub
credentials. Private collaboration controls are no longer part of the recovery
assumption. If visibility changes again, record a successor decision and update
machine state; do not silently reinterpret ADR-0023.

This decision changes repository publication only. It changes no Linux code,
model semantics, evidence authority, or security claim.
