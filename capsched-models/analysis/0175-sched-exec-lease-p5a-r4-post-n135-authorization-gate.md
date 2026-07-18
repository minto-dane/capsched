# Analysis 0175: SchedExecLease P5A-R4 Post-N135 Authorization Gate

Date: 2026-07-18

Status: exact R4-E3 source and synthetic concurrency semantics accepted only
for the default-off disposable virtual test boundary; drafting a separate
R4-E4 measurement plan is authorized. No R4-E4 source or live Linux boundary
is authorized.

## Purpose

N-135 closed the six-build/six-boot evidence contract but deliberately left
all post-evidence authorization bits false. This gate performs the separate
review required by validation/0255. It answers three distinct questions:

```text
Is the exact disposable R4-E3 source identity reviewable and accepted?
What correctness claim does the closed virtual evidence actually support?
Which next action is authorized without changing Linux source?
```

The answers are scope-qualified. Candidate `da9ce915...` is accepted only as
the exact, default-off, same-translation-unit KUnit source that generated the
closed synthetic evidence. Its concurrency semantics are accepted only for
the modeled and tested synthetic protocol under the recorded six virtual
boots. The next authorized action is drafting a separate R4-E4 measurement
plan. Nothing here accepts a live scheduler attachment or production code.

## Locked Evidence

The gate binds the N-133 plan, corrected N-134 source identity, canonical
N-135 result, both independent N-135 closures, implementation record, and the
project-wide claim ledger. The authoritative N-135 identity is:

```text
candidate commit:       da9ce9159b3450c28c8faf8dceac671fb7bfeba2
candidate parent:       a429fc30252ac6af94c51d96cd4ac24e72d9f83b
candidate tree:         58c6510c6f517004e37107786d006bb8333b79b8
candidate diff SHA-256: 096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
matrix result SHA-256:  4717052e2f546cf5faa13bfd24d90e43626e9b66f4f6d24ad07b2ed5bc7fbedd
closure r1 SHA-256:     6d9a54ed85d742d77aeef98f53deab2634ead63d41ef1c551ca6720b4a098f89
closure r2 SHA-256:     86fd0cf06ddbcfd7fd88210eec196cec1650d31ca929791bf9e3bc7e7cfb26ea
normalized closure:     239bafaa191598443a2d004bd68edd949c3030849d79a5ad756a670980607e8f
```

Both closure results reproduce six architectures/profiles, 216/216 cases,
216/216 receipts, and zero failure, skip, timeout, compiler diagnostic,
clock-skew warning, kernel-warning report, QEMU failure, or network device.

## Freshness and Claim Ledger

The review refreshed Torvalds Linux from prior observation
`a13c140cc289...` to `1229e2e57a5...`. The prior observation is an ancestor
and the tip advanced by 495 commits. Neither `init/Kconfig` nor
`kernel/sched/exec_lease.c` changed upstream; the latter remains private and
absent upstream. A merge-tree of the exact candidate and refreshed upstream
completed without conflict at tree `00025acf3c08...`.

The machine record supplies the mandatory claim-ledger row that was absent
from the pre-source plan. It names the exact patch scope, evidence classes,
supported claims, forbidden claims, open gaps, review and acceptance gates,
upstream freshness, and false safety flags. The added local evidence class,
`virtual_synthetic_protocol_diagnostics`, may support only correctness of the
exact synthetic protocol under the recorded matrix. It may not support real
scheduler, runtime, bare-metal, monitor, production, or deployment claims.

## Authorization Decision

After validation/0256 passes, the following are true only with the stated
scope:

```text
R4-E3 exact source accepted:
  exact candidate identity, disposable branch, default-off virtual synthetic
  KUnit evidence only

R4-E3 concurrency correctness accepted:
  modeled/tested synthetic protocol and exact six-boot matrix only

R4-E4 plan may be drafted:
  source-free measurement-plan design only
```

The following remain false:

```text
R4-E4 plan accepted
R4-E4 source creation
R4 behavior source creation
primary Linux change
patch-queue change
real scheduler attachment or hook
runtime behavior, denial, or coverage
bare-metal validation or bounded latency
monitor delivery or enforcement
performance or cost claim
production protection or deployment
multi-node, multi-cluster, or datacenter readiness
```

## Separate N-136 Boundary

The checked runtime-charge-subject model remains an independent blocker. It
requires explicit current/donor/cgroup/class/monitor/proxy charge subjects and
still sets every hook, runtime-coverage, denial, monitor, and protection flag
false. R4-E3 synthetic acceptance cannot be reused as N-136 evidence, and an
R4-E4 measurement plan must not introduce a runtime-budget hook.

## Next

Draft an exact, source-free R4-E4 measurement plan. That plan must bind this
gate, preserve the candidate identity and default-off boundary, define its
measurement matrix and rejection thresholds, carry its own claim ledger and
formal unsafe cases, and keep source creation false until a separate plan gate
passes.
