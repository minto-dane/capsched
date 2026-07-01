# ADR-0010: Private Superproject and Linux Patch Queue

Status: Accepted

Date: 2026-07-01

## Context

The project now needs private GitHub backup and collaboration state.

There are three distinct things to preserve:

```text
project state and models
Linux patch work
local heavyweight build/source working trees
```

The control repository `capsched/` is small and should be pushed directly.

The Linux source repository is different. It contains public upstream Linux
history and a very large `.git` directory. Pushing the full Linux history from
the local machine to a new private GitHub repository failed repeatedly with
GitHub HTTP 500 errors. More importantly, vendoring full upstream Linux history
is not necessary to preserve our private work.

The current private Linux change is a small patch series on top of upstream
Linux:

```text
base:
  torvalds/linux master
  4edcdefd4083ae04b1a5656f4be6cd83ae919ef4

work branch:
  capsched-linux-l0
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462

private delta:
  2 commits
  4 files
  inert CONFIG_CAPSCHED and type-only authority scaffolding
```

## Decision

Use a private GitHub superproject plus private submodules:

```text
minto-dane/linux-cap
  private superproject

minto-dane/capsched
  private project-control repository
  AI state, decisions, models, validation, assurance, and design records

minto-dane/capsched-linux
  private Linux patch queue repository
  upstream base metadata, patch series, and recreate script
```

Do not use `minto-dane/capsched-linux` as a full Linux history mirror for now.
Use it as a patch queue.

The local full Linux working tree remains:

```text
/media/nia/scsiusb/dev/linux-cap/linux
```

but it is not committed into the superproject and should not have a GitHub
`origin` remote pointing at the patch queue.

## Rationale

Patch queue is the right boundary for this stage:

- it preserves private Linux changes without pushing gigabytes of public
  upstream history
- it makes the private delta reviewable as patch files
- it keeps upstream rebasing and drift review explicit
- it avoids confusing the private patch repository with an upstream Linux fork
- it lets the superproject clone quickly and recreate the Linux tree when
  needed

The full local Linux tree is still useful for builds, source reading, and
future patches. It is just not the private publication artifact.

## Recreate Rule

The active Linux tree is reconstructed from the patch queue:

```sh
./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux
```

That script clones upstream Linux if needed, checks out the recorded base, and
applies the private patch series.

## Guardrails

- Do not push local `linux/` full history to the patch queue remote.
- Do not treat the patch queue as a full Linux fork.
- Do not treat patch queue presence as upstream compatibility proof.
- Do not treat a recreate script as build validation.
- Keep upstream base commit, work branch, and work commit recorded.
- When Linux patches change, regenerate the patch queue and update the
  superproject submodule pointer.
- If a real full private Linux fork becomes necessary later, make a separate
  decision and document the storage, cost, and synchronization policy.

## Consequences

The private GitHub source of truth is:

```text
superproject:
  https://github.com/minto-dane/linux-cap

project state:
  https://github.com/minto-dane/capsched

Linux patch queue:
  https://github.com/minto-dane/capsched-linux
```

This is a repository-management decision only. It does not approve Linux code,
behavior changes, ABI, monitor verification, runtime coverage, or production
protection.

