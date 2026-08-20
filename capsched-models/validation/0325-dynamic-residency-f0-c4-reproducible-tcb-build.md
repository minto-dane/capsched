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

The repair was committed as
`536e3e736f1540184616f8e4e87f6e8f57fe6d1a`, reconstructed in the VM from
complete-history Git bundle
`6c6c436ae3005c52787ec581054dbf7c7af2cfb4bcc7475cf7a5af1cb88772e5`,
and installed from the clean root-owned VM-native checkout.  The installed
artifact manifest is
`1045d361017550965423b301c424f4a4a32ea2223261d355de03d4dc33b8e70e`;
the installed launcher is
`339458c9573ceed04c460be15e80c41f6472c412ee1a31155c6da2390569db2f`.

The post-install suite passes the launcher basic case, 10 hostile launcher
cases, zero-tick idle case, five hostile snapshot cases, 17 resource-policy
cases, one two-root reproducible-build case, five-component supervisor smoke
run, three guardian cases, one external-memory recovery case, one immutable
toolchain reuse case, and three reduction-boundary cases.  The installed
inputs are therefore eligible for a fresh G6 capture.

This closes only build-path reproducibility and the clean-install prerequisite
for that retry.  It grants no G6 completion, G7 reduction, F0, R11, K0/G0,
protection, performance, cost, deployment, or model-completion authority.
