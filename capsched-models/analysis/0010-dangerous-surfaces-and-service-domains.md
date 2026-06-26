# Analysis 0010: Dangerous Surfaces and Service Domains

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note identifies Linux surfaces that are too powerful or too semantic to be
treatable as simple scheduler authority. They should become typed endpoints,
service Domains, or monitor-backed leases in later tracks.

## Principle

The scheduler should not learn every filesystem, driver, BPF, network, GPU, or
storage semantic. It should activate an execution authority context. Subsystems
with rich semantics must expose typed endpoints and validate operation-specific
capabilities.

## ioctl

Evidence:

- `fs/ioctl.c` around lines 483-605 implements `do_vfs_ioctl()` and the
  `ioctl` syscall.
- `security_file_ioctl()` is called before generic VFS ioctl handling.
- Unknown commands can fall through to `vfs_ioctl()` and then file operation
  implementations.
- `security/security.c` around lines 2498-2532 defines LSM hooks for ioctl and
  compat ioctl.
- Landlock checks device ioctl rights using access captured at file open in
  `security/landlock/fs.c` around lines 1840-1870.

CapSched interpretation:

ioctl is not one operation. It is an operation multiplexor. A single
`EndpointCap(file, ioctl)` is probably too coarse for dangerous devices.

Candidate rule:

```text
regular benign ioctl:
  endpoint policy may allow a broad class

device/control-plane ioctl:
  typed sub-operation capability or service Domain required

DMA or queue-affecting ioctl:
  Monitor lease or IOMMU ownership validation required
```

## BPF

Evidence:

- `kernel/bpf/syscall.c` around lines 1372-1530 implements BPF map creation
  checks, including `bpf_token`, `CAP_BPF`, `CAP_NET_ADMIN`, and
  `sysctl_unprivileged_bpf_disabled`.
- `kernel/bpf/syscall.c` around lines 2972-3225 implements program load checks,
  token use, capability checks, BTF/attach validation, security hook, verifier,
  id allocation, audit, and fd creation.
- `kernel/bpf/token.c` around lines 1-80 implements `bpf_token_capable()` using
  a token user namespace and LSM token checks, with deferred free through work.

CapSched interpretation:

BPF has a modern delegated-authority pattern through `bpf_token`. This is useful
prior art for CapSched because it separates "token allows command/type" from
normal global capability checks.

But BPF also increases risk:

- programs may attach to kernel, networking, tracing, cgroup, or device paths
- verifier security is subtle
- BPF objects are refcounted and exposed by fd/id
- token free uses async work
- privileged BPF can observe or affect broad kernel state

Candidate placement:

```text
L0:
  treat BPF as existing Linux policy, no CapSched security claim

L1/L2:
  tag BPF objects with Domain provenance and endpoint authority

production:
  only allow privileged BPF in management or service Domains unless a typed
  verifier and monitor policy can confine its effects
```

## pKVM Reference Point

Evidence:

- `Documentation/virt/kvm/arm/pkvm.rst` around lines 15-24 describes pKVM
  installing a host stage-2 identity map and isolating protected VMs by
  unmapping pages from the host view.
- Around lines 34-64, it describes donated metadata and anonymous pages being
  unmapped from the host stage-2 identity map.
- Around lines 77-78, CPU state isolation and DMA isolation are marked
  unimplemented.

CapSched interpretation:

pKVM is not a ready substrate for CapSched, but it demonstrates the kind of root
CapSched needs:

```text
Linux cannot access pages after ownership donation.
Shared communication must be explicit.
Host-visible behavior changes when pages are protected.
```

CapSched-H needs a similar rule for Domain-private pages:

```text
Domain-private user and kernel-state pages are unmapped from other Domain views.
Linux cannot forge ownership by changing ordinary kernel metadata.
```

## VFIO and IOMMU

Evidence:

- `Documentation/driver-api/vfio.rst` around lines 5-12 describes VFIO as a
  framework for direct device access in an IOMMU-protected environment.
- Around lines 35-75, it explains DMA risk, IOMMU isolation, and IOMMU groups as
  the ownership unit.
- Around lines 80-113, it describes VFIO containers, groups, and device fds.
- Around lines 166-212, the example maps DMA memory through VFIO ioctls.

CapSched interpretation:

VFIO's key lesson is that device isolation granularity is hardware-dependent.
CapSched cannot promise per-queue or per-device isolation if the IOMMU topology
only gives a larger group.

Candidate rule:

```text
QueueCap or DeviceQueueLease must include:
  hardware isolation unit
  IOMMU domain or group
  DMA MemoryView
  interrupt ownership
  epoch
  budget/rate
```

## Service Domain Candidates

The following should not remain raw shared mutable host services in the final
security architecture:

| Surface | Why dangerous | Likely target |
| --- | --- | --- |
| filesystem parsers | parse attacker-controlled data and touch page cache/inodes | storage service Domain |
| block layer control plane | global queues, writeback, DMA | storage service plus queue leases |
| network stack control plane | sockets, namespaces, packet paths, BPF hooks | network service Domain |
| device drivers | ioctls, MMIO, DMA, firmware, reset | driver service Domain |
| GPU management | huge ioctl/API surface, DMA, shared memory | GPU service Domain and queue lease |
| BPF privileged load/attach | programmable kernel behavior | management/service Domain with typed attach caps |
| generic workqueue | provenance loss | per-Domain wrapper or service-domain work queues |
| io_uring | registered resources consumed later | frozen resource registration and worker provenance |

## L0 Boundary

For L0, do not try to service-domain all of this. L0 should state:

```text
Measured:
  scheduler integration, overhead, runnable lease semantics, DomainTag tracing

Not claimed:
  protection against malicious kernel code
  memory isolation
  device isolation
  async provenance completeness
  BPF/ioctl confinement
```

## Preliminary Conclusion

CapSched's scheduler model must be narrow on purpose. The broader project wins
only if dangerous kernel surfaces are moved behind typed endpoint authority and
service Domains. BPF token, Landlock open-time access capture, pKVM page
donation, and VFIO IOMMU groups are all useful design references, but none is a
drop-in solution.
