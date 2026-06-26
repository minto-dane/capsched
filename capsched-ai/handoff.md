# AI Handoff

Updated: 2026-06-26

Read this first when resuming the project.

## Current State

The workspace is `/media/nia/scsiusb/dev/linux-cap`.
The project-control Git repository is `/media/nia/scsiusb/dev/linux-cap/capsched`.

Upstream Linux has been fetched into sibling repository `linux/`. Slice 0A has
been committed in that Linux repository as inert `CONFIG_CAPSCHED` scaffolding.
No behavior-changing scheduler patch points are accepted yet.
The source-analysis pass has been expanded through policy front-ends, mutable
kernel state, dangerous surfaces, network/socket endpoints, io_uring registered
resources, BPF programmable policy boundaries, scheduler topology/cluster
partitions, and the first formal model selection. The first Runnable Lease TLA+
model and the Endpoint Async Provenance model have both been written and checked
with TLC in tiny finite models. A candidate Linux L0 Runnable Lease
implementation plan now exists, derived from the first model and the upstream
scheduler maps. The first Linux patch slice has been narrowed to Slice 0A:
inert `CONFIG_CAPSCHED` build scaffolding with no task layout or scheduler
behavior changes. Slice 0A is now committed in the Linux repository. Build
validation passed under a systemd user service using rootless local build tools
extracted under `tools/apt-local/root`.
The Endpoint Async model has been mapped back to concrete Linux attachment
points. Key result: `io_kiocb` and `io_rsrc_node` are natural io_uring carriers,
generic workqueue/task_work need CapSched wrappers, and socket endpoint
enforcement must not rely only on LSM hooks because some sendmmsg paths can
reuse `sock_sendmsg_nosec()`.

## Recovery Path

Read in this order:

1. `capsched/capsched-ai/state/state.json`
2. `capsched/capsched-ai/handoff.md`
3. `capsched/capsched-ai/design/compact.md`
4. `capsched/capsched-ai/decisions/index.md`
5. `capsched/capsched-models/analysis/index.md`
6. Any referenced ADRs or current plans

Only read longer files when the current task requires them.

## Project Essence

CapSched-Linux is a Linux scheduler and kernel architecture project. The
long-term goal is not merely better containers. It is process-to-container-scale
Domain isolation with VM-like protection strength and datacenter OS efficiency.

The final architecture is:

```text
Domain-aware Linux kernel
+ typed capability/resource endpoints
+ per-Domain mutable kernel state
+ small HyperTag Monitor enforcing non-forgeable roots
```

The Linux-only L0 prototype is for integration, semantics, and performance. It
must not claim hypervisor-grade isolation.

## Design Memory

Use this as the mental model:

```text
Capability = scheduled authority
```

Execution activates an authority context. The scheduler should activate
`DomainTag + SchedContext + Thread` under a frozen execution lease.

Implementation must keep capability types separated:

- `RunCap`: enqueue/runnable submission only
- `SchedContext`: CPU time/budget/period/placement/co-tenancy
- `FrozenRunUse`: enqueue-time frozen execution lease
- `DomainTag`: active protection context
- `SpawnCap`: bounded creation authority
- `ThreadControlCap`: suspend/resume/terminate/inspect
- `SchedControlCap`: scheduling parameter changes
- `EndpointCap`, `QueueCap`, `MemoryCap`: resource-specific endpoint authority
- `BudgetTicket`: donated caller budget for broker/service execution

## Do Not Do Yet

- Do not choose exact Linux patch points before reading current upstream code.
- Do not implement before writing investigation notes and a semantic model.
- Do not merge Linux source and project state into one repository.
- Do not claim security properties for Linux-only prototypes.
- Do not treat BPF, sched_ext, cpuset, or sched domains as the production
  security root. They are compatibility and policy substrates.

## Next Likely Action

The first two formal semantic models have been selected and checked. Runnable
lease semantics are modeled in:

```text
capsched/capsched-models/formal/0002-runnable-lease-model/
```

TLC result:

```text
capsched/capsched-models/validation/0001-runnable-lease-tlc.md
```

Endpoint async provenance semantics are modeled in:

```text
capsched/capsched-models/formal/0003-endpoint-async-provenance-model/
```

TLC result:

```text
capsched/capsched-models/validation/0005-endpoint-async-tlc.md
```

Do not jump to scheduler behavior patches. Slice 0A is validated, the first
async endpoint model is checked, and the Linux attachment map exists. The next
decision is whether to choose Slice 0B type-only endpoint authority scaffolding
or model broker `BudgetTicket` donation more deeply.

Endpoint attachment records:

```text
capsched/capsched-models/analysis/0015-endpoint-async-linux-attachment-map.md
capsched/capsched-models/implementation/0003-endpoint-async-attachment-plan.md
```

Current validation runner:

```text
script: /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-l0-slice0-build-validation.sh
log: /media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260626T011458Z.log
result: passed
```

Validation evidence:

```text
baseline vmlinux built
CONFIG_CAPSCHED=n vmlinux built with no capsched.o
CONFIG_CAPSCHED=y vmlinux built with kernel/sched/capsched.o
```

Candidate implementation plan:

```text
capsched/capsched-models/implementation/0001-l0-runnable-lease-implementation-plan.md
capsched/capsched-models/implementation/0002-l0-slice0-scaffolding-plan.md
capsched/capsched-models/implementation/0003-endpoint-async-attachment-plan.md
capsched/capsched-models/validation/0002-l0-slice0-build-validation-plan.md
```

Additional source-analysis anchors:

```text
capsched/capsched-models/analysis/0013-bpf-programmable-policy-boundary.md
capsched/capsched-models/analysis/0014-scheduler-topology-cluster-partition-map.md
capsched/capsched-models/analysis/0015-endpoint-async-linux-attachment-map.md
```

Current Linux source state:

```text
repo: ../linux
remote: upstream = https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
branch: capsched-linux-l0
base: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
current commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
current subject: sched/capsched: Add inert scaffolding
```
