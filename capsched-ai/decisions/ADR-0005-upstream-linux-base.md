# ADR-0005: Use git.kernel.org torvalds/linux as Upstream Linux Base

Status: Accepted

Date: 2026-06-25

## Context

CapSched will patch Linux scheduler and adjacent kernel subsystems. The Linux
source repository needs a clean relationship to official upstream history while
also allowing later publication to a private repository.

The user asked whether to pull from an upstream repository or from a pre-created
GitHub fork.

## Decision

Use the canonical Linux upstream from kernel.org as the initial source:

```text
https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
```

Clone it into sibling repository `../linux` with remote name `upstream`.

Create the initial work branch:

```text
capsched-linux-l0
```

The recorded initial upstream commit is:

```text
4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Rationale

Using kernel.org as `upstream` keeps official Linux history distinct from later
private publication remotes. A future private repository can be added as
`origin` without confusing source-of-truth tracking.

This supports the intended remote model:

```text
linux/.git remotes:
  upstream = official Linux
  origin   = future private repository
```

## Consequences

The project now has two sibling Git repositories:

```text
capsched/  project-control history
linux/     Linux source and CapSched patch history
```

Linux implementation commits belong in `linux/`. Design, analysis, validation,
and state commits belong in `capsched/`.

