# Validation 0245: SchedExecLease P5A-R4 E3 Corrected Source Gate r2 Launch

Date: 2026-07-17

Status: corrected r2 passed and was independently closed by validation/0246.

## Frozen Boundary

```text
candidate: f9c737c93ecff48c6f512048b05b1b49f4a54ca5
parent:    a429fc30252ac6af94c51d96cd4ac24e72d9f83b
tree:      274f7b5d6969dc68e158819191fe598f9587e0ad
diff SHA: c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781
r1 provisional result SHA:
  fb2bc59d01cda4110a2022fc5e810d0b0b445bfb80498f25558476e74667369a
corrected runner SHA:
  61d0a4968b21bf595b710947e11369ca7dfe9316fec91767bedd21f760055cde
```

All source identities and semantic gates are unchanged. r2 adds only build-
log integrity: W=1 diagnostics are fatal, initial shared-filesystem skew
requires a same-target verification build, and final compiler/skew warning
counts must be zero.

Corrected-runner preflight
`20260717T-p5a-r4-e3-source-preflight-r7` passed the N-133 seals, repository
identity, exact two-file/additive/byte-preservation boundary, strict style,
36 cases, six faults, configuration, protocol, and forbidden-surface checks.
It intentionally did not start the build matrix, publish a result, or authorize
diagnostic boots, and its temporary worktrees and output were removed.

## Launch

```text
run id:   20260717T-p5a-r4-e3-source-gate-r2
job name: p5a-r4-e3-source-gate-r2
machine:  domainlease-dev
monitor:  ./tools/long-job.sh watch p5a-r4-e3-source-gate-r2 30
```

The run uses fresh output, immutable plan/r13/r14/runner/helper snapshots,
isolated E2/E3 Git-object worktrees, atomic result publication, and cleanup of
temporary source/build trees on every exit.

Run r2 passed all eight modes with zero W=1 compiler diagnostics, zero clock-
skew retries, and zero final skew warnings. Its result SHA-256 is
`7c24c35506345550353a3c9f9b4d986fbccdccfbdbb884a4497df6c89e55cf27`.
Validation/0246 independently snapshots and closes the result; this record is
not itself the closure authority.

## Decision Boundary

Only an r2 result with zero W=1 diagnostics, zero final clock-skew warnings,
all eight build modes, 58/51 preservation, and zero disabled artifacts may
complete N-134 and authorize preparation of the fixed six-boot diagnostic
matrix. No runtime or production claim follows from a source-gate pass.
