# Validation 0256: SchedExecLease P5A-R4 Post-N135 Authorization Gate

Date: 2026-07-18

Status: passed twice with identical normalized results. The exact disposable
R4-E3 source and its synthetic concurrency semantics are accepted only for the
default-off virtual test boundary. Drafting an R4-E4 measurement plan is
authorized; R4-E4 source and all live/runtime/production boundaries remain
false.

## Scope

This validation checks:

```text
analysis/0175-sched-exec-lease-p5a-r4-post-n135-authorization-gate.md
analysis/sched-exec-lease-p5a-r4-post-n135-authorization-gate-v1.json
formal/0138-p5a-r4-post-n135-authorization-gate-model/
implementation/sched-exec-lease-p5a-r4-e3-concurrency-prototype-v1.json
validation/run-sched-exec-lease-p5a-r4-post-n135-authorization-gate.sh
```

The gate is source-free. It reads immutable evidence and Git objects, refreshes
no working tree, creates no Linux commit, performs no build or boot, and writes
only ignored validation output.

## Locked Inputs

```text
authorization config: 99d055aa02429c510f564fd02bb8f864f42a0603fc7e0a73e09fc13fc9532203
runner:               4e723d48dd4e38a09fa95de180892c9050f8f0f2eda33df1a651b7f931da4c64
formal manifest:      96ce0df751c04180ac7b10ea71b07de808e8f0fc140e99a6d08c12ec95618129
N-135 matrix:         4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd
N-135 closure r1:     6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89
N-135 closure r2:     86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea
N-135 normalized:     239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f
```

The runner independently rechecks the plan's pre-gate false authorizations,
the corrected implementation identity, six builds/boots, 216/216 cases and
receipts, both closures, zero diagnostic classes, and every retained negative
claim. It requires the global claim-ledger's exact 14 fields and keeps the
N-136 runtime-charge-subject gate separate.

## Upstream Freshness

The gate fetched the exact current Torvalds commit through a tree-filtered
observation and verified the remote tip at each canonical run:

```text
previous upstream:    a13c140cc289c0b7b3770bce5b3ad42ab35074aa
current upstream:     1229e2e57a5c2980ccd457b9b53ea0eed5a22ab3
advance:              495 commits
previous is ancestor: true
touched-path changes: 0
candidate merge base: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
candidate merge tree: 00025acf3c082bec136467cc51c5254eb7c52089
merge-tree clean:     true
```

The touched paths are exactly `init/Kconfig` and private
`kernel/sched/exec_lease.c`; the latter remains absent upstream. This proves
freshness only for the exact candidate review, not global Linux freshness.

## Formal Result

```text
safe states generated:           5
safe distinct states:            4
safe depth:                      4
unsafe expected counterexamples: 15/15
```

The unsafe configurations reject missing plan/source gate/matrix/closure,
missing claim ledger or drift observation, touched-path drift, merge conflict,
premature R4-E4 source, primary/patch mutation, runtime, bare-metal,
production, multi-cluster/datacenter, and N-136 conflation.

An exploratory parallel invocation was not credited after two TLC processes
contended in the shared VM parser scratch and one failed closed. The two
canonical repetitions below were therefore run serially with separate output
and state directories.

## Independent Results

```text
r7 result SHA-256: 160efd76ed083df880747685a861a1b920e5fa9a265a4946749f87da44e09d37
r8 result SHA-256: d736b698cc056bea41d671c61b5c5a9a98024327642ff79c19f6dfb42f60f905
normalized r7/r8:  541d72676f97741c40ed3a50b4f524c63a9530fc9984bfc88ed6675415d1fb4f
```

Normalization removes only `run_id`. The complete claim set, Git identities,
upstream identity, formal counts, runner/config/model hashes, and negative
flags are otherwise byte-identical.

Focused regression first accepts the exact config, then rejects a changed
closure hash, a premature `r4_e4_source_may_be_created=true`, and a symlinked
config. ShellCheck passes for both runner and regression test.

## Authorization Boundary

This gate accepts:

```text
the exact disposable default-off R4-E3 source identity for virtual synthetic
  evidence only
the modeled/tested R4-E3 synthetic concurrency protocol under the exact six
  virtual boots only
drafting a source-free R4-E4 measurement plan
```

It does not accept an R4-E4 plan or source, behavior source, primary Linux or
patch-queue changes, real scheduler attachment, runtime behavior, denial or
coverage, N-136 completion, bare-metal correctness or latency, monitor
enforcement, performance, cost, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness.
