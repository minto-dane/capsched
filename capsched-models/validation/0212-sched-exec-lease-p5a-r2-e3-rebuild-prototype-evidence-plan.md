# Validation 0212: SchedExecLease P5A-R2 E3 Rebuild Prototype Evidence Plan

Date: 2026-07-14

Status: passed for creating the exact disposable E3 two-file source draft
only. E3 rebuild correctness and every production claim remain unaccepted.

## Scope

Validate analysis/0162 and formal/0129 against the hashed E2 evidence closure,
exact primary and E2 candidate identities, frozen 0014 patch queue, actual CFS
traversal and KUnit primitives, and absence of any existing E3 implementation.

## Result

Run `20260714T-p5a-r2-e3-rebuild-plan` passed:

```text
source anchors:                  26, failures 0
future/source absence checks:   6, failures 0
safe TLC:                       6 generated, 5 distinct, depth 5
unsafe expected counterexamples: 24/24
allowed E3 source files:        init/Kconfig, kernel/sched/fair.c
required KUnit case families:   14
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e3-rebuild-prototype-evidence-plan/20260714T-p5a-r2-e3-rebuild-plan/result.json`

Result SHA-256:
`b80f5fdadbc035f49304338923fed641faff2c00b9380128599b8b7ae99caf30`.

The safe model requires the E2 closure, exact candidate and two-file scope,
default-off built-in KUnit dependency, same-translation-unit access to actual
CFS primitives, rb postorder plus bottom-up nonrecursive hierarchy traversal,
current outside the tree, an independent exhaustive oracle, generation
recheck and saturation blocking, rq-lock ownership, controlled build/QEMU
KUnit evidence, forbidden-operation absence, and explicit non-claims.

Each of the 24 unsafe configurations removed one requirement and produced the
expected `Safety` counterexample.

## Authorization Boundary

This pass changes only these two planning decisions to true:

```text
e3_disposable_worktree_may_be_created
e3_two_file_source_draft_may_be_created
```

The new worktree must descend directly from
`162d16640634637a6f7604b90bf2275bea47ec63`, use branch
`codex/p5a-r2-e3-rebuild-prototype`, and change only `init/Kconfig` and
`kernel/sched/fair.c`.

It does not accept the draft, its rebuild correctness, the E2 layout for
production, a real publisher/fanout/worker/picker connection, incremental
update closure, runtime behavior, protection, performance, cost, deployment,
or datacenter readiness.

## Next

Create the exact disposable worktree, implement the isolated prototype and
independent KUnit oracle, then run source/build/arm64-QEMU validation. E4
lock-hold measurement remains unauthorized until E3 correctness passes.
