# Validation 0258: SchedExecLease P5A-R4 E4 Source and Regression Launch

Date: 2026-07-18

Status: launch-ready, not passed. Source-only smoke passed; the complete fresh
source/object and six-profile E3 regression has not yet produced canonical
evidence.

## Locked Candidate

```text
parent:   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
commit:   1dac9953b1b5c326a27285b1f2a6e4fac9960a1d
tree:     7d7f14800c9696b131ef7363cd8fb4cdd33a05b7
diff sha: f8aa2ea40ef4041d3c1fcf6d9503f814aecf2e16b384688af6d196fc70009393
```

The source runner validates the exact plan/result hashes, direct-child and
two-file scope, strict checkpatch, default-off config, byte-identical E3
case/oracle/receipt region, exact seven-family matrix, fixed gates, shared
helpers, and synthetic non-attachment boundary. Fresh object mode is:

```text
arm64:  exact E3 parent, E4 off, E4 on
x86_64: exact E3 parent, E4 off, E4 on
```

All builds use W=1; compiler diagnostics and persistent clock skew fail closed.
E3-parent and E4-off objects must contain zero E4 symbol, relocation, string,
initcall, result-row, or suite artifacts.

The regression runner derives from the already closed N-135 runner and keeps
its immutable-input snapshots, receipt serializer, warning classifier, fresh
VM-internal ext4 build per profile, sequential retirement, timeouts, QEMU/KTAP
parsing, and complete warning rejection. It changes only the candidate identity
to `1dac9953...`, requires the new source-gate result, and explicitly disables
the E4 measurement config. Required profiles remain arm64/x86_64 standard,
arm64/x86_64 hotplug plus fault injection, arm64 generic KASAN, and x86_64
KCSAN.

The combined runner first completes the six-object source gate, then resolves
all six configs without build/boot, then requires fresh 216/216 E3 cases and
216/216 typed receipts with zero failure, skip, timeout, compiler diagnostic,
final skew warning, kernel warning, or QEMU failure.

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r4-e4-local-quantum-source-gate.sh
  run-sched-exec-lease-p5a-r4-e4-e3-six-profile-regression.sh
  run-sched-exec-lease-p5a-r4-e4-source-and-e3-regression.sh
```

`bash -n`, ShellCheck, JSON parsing, strict source style, and source-only run
`20260718T-p5a-r4-e4-source-smoke-r4` pass. The r4 smoke also verifies complete
run-owned worktree retirement across the Apple Container shared-directory
boundary. The smoke created no build or boot result and grants no acceptance.

After the combined run passes, an independent read-only artifact closure is
still required before timing. This launch record establishes no E4 source
acceptance, measurement result, live scheduler/CPUHP behavior, N-136 charge,
bare-metal latency, performance/cost, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness.
