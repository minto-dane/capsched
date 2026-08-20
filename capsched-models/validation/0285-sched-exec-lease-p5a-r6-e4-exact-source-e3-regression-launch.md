# P5A-R6-E4 exact-source E3 regression launch

Status: launch-ready; no regression pass claimed

Date: 2026-07-30

## Decision

The exact R6-E4 candidate is rebound to a fail-closed four-profile R6-E3
regression runner. Static preflight, validator regression, warning-classifier
self-test, and all four configuration-only smoke checks pass. No kernel image
was built or booted by these checks.

After this record and its launch helpers are committed and pushed, only the
exact detached regression run named
`p5a-r6-e4-exact-source-e3-regression` may start. Passing that run will still
require an independent read-only evidence closure before R6-E4 source
acceptance or measurement authorization.

## Frozen inputs

```text
R6-E4 candidate:
  branch  codex/p5a-r6-e4-local-quantum-measurement
  commit  d51ebdc657a1040e423735584775e66399f321f9
  parent  99287291f1c8e0d6c1b3ea86d121508c5547f424
  tree    0847c408be82e6c9077c2edd2d00f44ccfbe18fc
  diff    fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9

R6-E4 source/build gate:
  result  ab5b33650dafb275ffc281ca7f0828aa3db11d8ca301f82c06980399bc3404e6

exact-source E3 regression:
  contract ade8e74b7f7488e49a0a656b379ed5179e77509dcc68b7c7f6cac014d07dbd30
  runner   670c314a6e66bcb6e88176765920f97ba9c9807a13ffbb98e2bf6a6bcc613364
  tests    fbfb221040f26ead0d3eb403cfaf70153c52a739ebc37cc844c4ba144fe14f56
```

The source/build result explicitly reports that shared R6-E3 helpers changed,
the four-profile regression is required, the regression has not passed, and
R6-E4 source acceptance and measurement authorization remain false.

## Exact regression boundary

The runner builds and boots these profiles sequentially:

1. arm64 standard debug, lockdep, RCU, hotplug, and allocation faults;
2. x86_64 standard debug, lockdep, RCU, hotplug, and allocation faults;
3. arm64 generic KASAN plus lockdep; and
4. x86_64 strict KCSAN plus lockdep.

Every fresh configuration must enable the exact 55-case
`sched_exec_lease_r6_correctness` suite and must contain:

```text
# CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST is not set
```

Each built `exec_lease.o` is independently scanned for R6-E4 measurement
symbols and strings. Any measurement artifact, missing case, missing or
malformed receipt, failure, skip, timeout, compiler diagnostic, classified
kernel warning, nonzero QEMU exit, changed input, insufficient internal
storage, or incomplete build retirement rejects the run.

The run uses all six guest CPUs, sequentially retires each build from internal
ext storage, retains only lossless evidence on the shared host path, and emits
progress suitable for 30-second monitoring.

## Completed preflight

The canonical static preflight passed against the exact candidate, pushed
fork branch, two-file diff, R6-E3 plan, R6-E4 source/build result, contract,
and immutable helper hashes.

The validator harness accepted the exact contract and rejected:

1. candidate identity substitution;
2. broadened source scope;
3. enabling R6-E4 measurement;
4. reducing the four-profile matrix;
5. reducing build parallelism;
6. removing the source-gate regression requirement;
7. pre-accepting R6-E4 source;
8. pre-authorizing measurement; and
9. a symlinked contract.

The configuration smoke result has SHA-256
`4b8e9e4ca61f7b35bb3e664f75d6e3e767db109355ffe80a5bc70fbd47b15d7a`.
It resolved all four configurations with R6-E4 measurement disabled,
passed the warning-classifier self-test, started zero builds and zero boots,
retired all scratch, and preserved every acceptance and deployment claim as
false.

Both new validators and all three host launch helpers pass Bash syntax and
ShellCheck at style severity.

## Claim boundary

This launch readiness does not establish that any build or boot passed. A
future matrix result may establish only exact-source virtual synthetic R6-E3
regression evidence pending independent closure.

R6-E4 source acceptance, measurement authorization, live scheduler
attachment, runtime denial correctness, monitor verification, bare-metal
validation, performance or cost claims, production protection, deployment,
multi-node, multi-cluster, and datacenter readiness remain false.
