# Validation 0239: SchedExecLease P5A-R4 E2 Dual-Architecture Layout Launch

Date: 2026-07-17

Status: arm64/x86_64 build running under an independently observable detached
Apple Container process. This records launch integrity, not a passing layout
result.

## Frozen Inputs

```text
primary Linux:   5e1ca3037e34823d1ba0cdd1dc04161fac170280
candidate:       a429fc30252ac6af94c51d96cd4ac24e72d9f83b
candidate tree:  fffd419bbc05bab87ad304c1e4a3213439d62bab
source gate SHA: 9e79d3e58151960b397a715116eb545de4c1ecc1988e619b88139022f6395a82
run ID:          20260717T-p5a-r4-e2-dual-arch-r1
job:             p5a-r4-e2-dual-arch-build
```

The candidate branch is pushed to `minto-dane/linux` and reviewable as draft
PR 2. Capsched and the superproject source-gate commits were pushed before the
build started.

## Matrix

The detached runner builds independent arm64 and x86_64 configurations for:

```text
fresh primary with the existing 51-symbol probe
candidate with R4 disabled
candidate with R4 enabled
candidate with all layout probes disabled
```

It rejects any existing-probe value change, missing or extra 58-symbol R4
manifest entry, disabled R4 symbol/relocation/string, ordinary scheduler-object
growth, field-order defect, alignment above 64, or envelope breach.

## Durable Launch

The wrapper runs inside `domainlease-dev` with `machine run --detach`, writes
its exit code and progress to the host-mounted workspace, and is probed by
process identity plus the final result contract. Initial inspection observed
the VM running, the detached wrapper alive, output growth, and progress moving
from 5% source binding to 10% arm64 baseline preparation.

One command provides continuously refreshed 30-second monitoring:

```bash
cd /Users/niania/Documents/linux-cap
./tools/long-job.sh watch p5a-r4-e2-dual-arch-build 30
```

Stopping the monitor with `Ctrl-C` does not stop the VM build. A passing final
result is required before N-132 or R4-E2 may complete; failure is retained and
investigated rather than reclassified.

## Claim Boundary

No arm64/x86_64 result, measured byte size, E2 completion, E3 authorization,
runtime behavior, protection, bounded latency, performance/cost, deployment,
or datacenter claim is made by this launch record.
