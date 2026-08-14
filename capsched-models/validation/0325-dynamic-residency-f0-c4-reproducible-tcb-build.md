# 0325 — Candidate-4 reproducible TCB build

## Finding

The clean behavioral-quotient commit `d0ddc00094b48289137d0e70ae35b820f6876a89`
was reconstructed under two different root-owned VM paths.  The unmodified
`-g` build produced launcher SHA-256 values `8f9a0967...` and `dd811af9...`.
Source, compiler, flags, architecture, and commit were otherwise identical.
The differing absolute checkout path in debug metadata made the installed TCB
non-reproducible and could cause false installed-identity drift.

## Repair

`build-install.sh` now maps the complete source root to the fixed logical path
`/usr/src/domainlease-f0-c4` for file, macro, and debug metadata.  `-Wdate-time`
under `-Werror` rejects accidental compilation-time macros.  Symbols remain
available for postmortem analysis; no runtime instruction or control-flow
check is added.

`test-build-reproducibility.sh` archives one exact commit into two distinct
source roots, builds both in distinct output roots and from distinct caller
working directories, requires byte-for-byte identity, and rejects leakage of
its temporary path.  The pre-install repair probe produced the same launcher
digest `339458c9573ceed04c460be15e80c41f6472c412ee1a31155c6da2390569db2f`
across all three path dimensions.

## Boundary

This closes only build-path reproducibility for the capture launcher.  A clean
reviewed commit, bundle reconstruction, reinstall, and complete post-install
suite remain required before G6 retry.  It grants no F0, R11, K0/G0,
protection, performance, cost, deployment, or model-completion authority.
