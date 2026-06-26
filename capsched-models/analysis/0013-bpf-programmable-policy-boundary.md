# Analysis 0013: BPF Programmable Policy Boundary

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps BPF, BPF tokens, BPF links, LSM hooks, cgroup/net attachments,
struct_ops, and sched_ext to CapSched. BPF is both useful and dangerous for
CapSched:

```text
useful:
  policy experimentation, observability, admission rules, cluster policy input

dangerous:
  programmable kernel execution, persistent links, global attach points,
  verifier/JIT attack surface, and sched_ext fallback semantics
```

The key conclusion is that BPF can feed policy, but it cannot be the root of
CapSched security enforcement.

## Existing Linux Shape

Evidence:

- `kernel/bpf/syscall.c` around lines 6400-6531 dispatches the `bpf()` command
  surface, including map update/delete/freeze, program load, object pin/get,
  program attach/detach/query, fd-by-id operations, raw tracepoints, BTF load,
  link create/update/detach, token create, and struct_ops association.
- `security/security.c` around lines 5283-5441 provides BPF LSM hooks for BPF
  syscall checks, map fd access, program fd access, map creation, program load,
  token creation, delegated command checks, and delegated capability checks.
- `kernel/bpf/syscall.c` around lines 1370-1688 creates maps, checks BPF token
  permissions, checks capability requirements, calls `security_bpf_map_create`,
  allocates a public ID, and returns an fd.
- `kernel/bpf/syscall.c` around lines 2972-3248 loads programs, checks token
  permissions, checks capability requirements, calls `security_bpf_prog_load`,
  runs the verifier, allocates a public ID, audits the load, and returns an fd.
- `kernel/bpf/syscall.c` around lines 3285-3623 defines BPF link lifetime:
  refcounting, deferred release, anon inode fd exposure, public ID exposure,
  `bpf_link_prime()`, `bpf_link_settle()`, and fd lookup.
- `kernel/bpf/syscall.c` around lines 4529-4699 validates attach type and
  attaches programs to cgroups, sockets/maps, netns flow dissector, TCX/netkit,
  and related targets.
- `kernel/bpf/syscall.c` around lines 5843-5925 creates BPF links for cgroup,
  tracing, LSM, netns, sockmap, XDP, SCHED_CLS, netfilter, and struct_ops.
- `kernel/bpf/token.c` around lines 112-195 creates a BPF token from a bpffs
  instance and records delegated command, map, program, and attach masks.
- `kernel/bpf/token.c` around lines 220-262 obtains a token from fd and checks
  delegated command, map type, program type, and attach type.

CapSched reading:

BPF already contains many capability-like ingredients:

```text
fd-backed objects
public IDs
delegation tokens
attach rights
LSM-controlled object creation
verifier-mediated program admission
link lifetime and detach/update operations
```

But these are not Domain capabilities. They are tied to Linux credentials,
namespaces, bpffs mounts, cgroups, net namespaces, and subsystem-specific attach
points.

## What Linux Already Does Well

Useful existing pieces:

```text
BPF token:
  constrained delegation of command/map/prog/attach authority

BPF link:
  explicit persistent attachment object with fd/id lifetime

BPF LSM hooks:
  central policy front-end for syscall, object creation, token delegation,
  program access, and map access

Verifier:
  admission control for program behavior before execution

bpffs:
  persistence and delegation through filesystem namespace

sched_ext:
  fast scheduler policy experimentation with DSQs and BPF callbacks
```

CapSched should reuse these as policy and experimentation surfaces rather than
duplicate them blindly.

## Why BPF Cannot Be the Security Root

BPF is inside the Linux trust boundary. In the final threat model, a Domain may
gain arbitrary Linux kernel context execution. If BPF policy is the only root,
then the attacker can target:

```text
verifier or JIT bugs
BPF maps containing mutable policy state
BPF links attached to global hooks
bpffs-pinned objects
struct_ops registrations
sched_ext policy fallback
LSM hook state
```

This is not enough for hypervisor-grade separation. CapSched-H needs the
HyperTag Monitor to own non-forgeable DomainTag, epoch, MemoryView, root budget,
and queue/IOMMU state.

## BPF Token Lessons

Evidence:

- `bpf_token_capable()` in `kernel/bpf/token.c` checks capability in the
  token's user namespace and calls `security_bpf_token_capable()`.
- Token creation requires current user namespace to equal the bpffs user
  namespace and requires `CAP_BPF` in that namespace.
- Tokens carry masks for allowed commands, maps, programs, and attach types.

CapSched reading:

BPF token is a useful analogy for CapSched:

```text
BPF token:
  delegated authority for a programmable kernel subsystem

CapSched capability:
  delegated, typed authority for execution and resource use
```

But the differences matter:

```text
BPF token is namespace/capability scoped.
CapSched authority must be DomainTag/epoch/resource-generation scoped.

BPF token grants admission to create/load/attach BPF objects.
CapSched authority must also constrain runtime execution, budgets,
MemoryViews, async provenance, and monitor-enforced ownership.
```

## BPF Object and Link Lifetime

Evidence:

- Maps and programs become public through ID allocation and fd return.
- BPF links are anon inode files and may be looked up by fd.
- BPF links may detach asynchronously through RCU or workqueue-based release.
- bpffs pin/get operations can persist BPF objects beyond the creating task.

CapSched reading:

Every BPF object that can outlive the current syscall needs a Domain-scoped
lifetime model:

```text
BpfObject = { map, prog, link, token, btf, struct_ops_map }
BpfObjectOwner = Domain + epoch + object generation
BpfAttachScope = cgroup | netns | tracing | LSM | XDP | TCX | struct_ops | sched_ext
BpfLinkControlCap = attach | update | detach | inspect
```

If a Domain is revoked, attached BPF links and pinned objects owned by that
Domain must not continue to mutate shared policy state unless explicitly
transferred to a service Domain or management Domain.

## sched_ext Position

Evidence:

- `include/linux/sched/ext.h` defines dispatch queues and task state for BPF
  scheduler operation.
- `kernel/sched/ext/ext.c` has watchdog timeout paths around lines 3428-3503.
- `kernel/sched/ext/ext.c` around lines 8199-8215 registers SysRq reset that
  disables sched_ext and reverts tasks to CFS.
- `kernel/sched/ext/ext.c` around lines 9678-9728 exposes BPF kfuncs for
  graceful exit and fatal error exit from the BPF scheduler.

CapSched reading:

sched_ext is excellent for:

```text
Domain clustering experiments
view-switch cost heuristics
batch scheduling policy
placement policy prototypes
observability of scheduling behavior
```

It is not suitable as the production root for:

```text
No RunCap, no run
No budget, no execution
No DomainTag activation, no cross-Domain switch
```

because sched_ext intentionally preserves forward progress through bypass,
watchdog, error exit, SysRq reset, and CFS fallback. That is right for system
recoverability, but wrong as the only security boundary.

## Capability Mapping

| Linux BPF object/path | CapSched concept | Notes |
| --- | --- | --- |
| BPF token | `BpfDelegationCap` analogy | Useful pattern, not Domain root |
| map fd/id | `BpfMapEndpoint` | Must be Domain/epoch owned if security-sensitive |
| prog fd/id | `BpfProgramObject` | Load-time policy is not runtime authority |
| link fd/id | `BpfLinkControlCap` | Attach/update/detach need explicit rights |
| bpffs pin | persistent object endpoint | Must not bypass Domain revocation |
| cgroup attach | policy front-end | cgroup remains compatibility/policy input |
| netns attach | network policy input | not Domain isolation root |
| LSM BPF | policy hook | must not mint monitor roots |
| struct_ops | subsystem control endpoint | high-risk, service-domain candidate |
| sched_ext | policy prototype | not production enforcement root |

## Preliminary Design Rules

1. BPF may propose policy; CapSched kernel-native checks enforce RunCap,
   SchedContext, FrozenRunUse, and DomainTag invariants.
2. BPF must not mint DomainTag, DomainEpoch, MemoryView, QueueTag, or root
   CPU budget.
3. BPF maps and links that influence CapSched policy must be owned by a
   management or policy service Domain with explicit epochs.
4. BPF object persistence through bpffs must participate in Domain revocation.
5. sched_ext can evaluate placement heuristics and clustering policy, but
   security checks must remain on kernel-native paths.
6. struct_ops, tracing, LSM, and device-facing BPF must be treated as dangerous
   programmable endpoints.

## Formal Implication

The first Runnable Lease model should not depend on BPF. BPF appears as an
untrusted or semi-trusted policy input:

```text
PolicyAllowsRun(domain, task, sched_ctx)
PolicySuggestsCpu(domain, cpu)
PolicySuggestsCluster(domain, cluster_cell)
```

The safety properties must still be enforced without trusting those suggestions:

```text
PolicyAllowsRun does not imply MonitorAllowsRun.
PolicySuggestsCpu must be intersected with SchedContext.allowed_cpus,
cpuset-effective CPUs, and monitor root budget.
BPF link lifetime cannot keep a revoked Domain authority alive.
```

## Preliminary Conclusion

BPF is valuable for CapSched as a programmable policy, observability, and
experimentation layer. It is also too broad and too mutable to be the security
root. CapSched should integrate with BPF through typed policy endpoints,
Domain-scoped ownership of BPF objects, and explicit management-Domain authority,
while keeping execution and monitor invariants outside BPF.
