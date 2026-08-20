# linux-cap Repository Threat Model

## Overview

`linux-cap` is the private DomainLease-Linux superproject. It coordinates:

- the `capsched/` project-control repository, which contains architecture,
  formal models, evidence contracts, validation runners, assurance claims,
  decisions, and machine-readable state;
- the `linux-patches/` private Linux patch queue and its recreation tooling;
  and
- ignored local Linux worktrees, build outputs, virtual-machine evidence, and
  host-side monitoring tools.

The intended long-term product is a single-image, multi-context datacenter OS
substrate. It aims to give process-, service-, container-, tenant-, and
cluster-cell-scale Domains VM-like separation through a small monitor below
Linux. The monitor-backed architecture is called DomainLease-H. The scheduler
core is SchedExecLease.

The long-term protection claim is stronger than ordinary container isolation:
an attacker controlling a Domain's userspace, and potentially obtaining
Domain-scoped Linux kernel-context execution, should not cross into another
Domain's memory, execution authority, device/DMA state, or control authority
without breaking the monitor or an explicitly exposed typed service endpoint.
That claim is open, not established.

The repository must be interpreted as three different security surfaces:

1. **Future production runtime.** Linux scheduler/resource changes plus a
   monitor, service Domains, control plane, MemoryViews, IOMMU roots, root CPU
   budgets, and typed authority. Most of these production roots are not yet
   implemented here.
2. **Private Linux prototypes.** The patch queue contains inert scaffolding,
   build-only probes, default-off tests, and experimental scheduler drafts.
   These can affect a locally recreated kernel when enabled but do not
   establish monitor-backed or production protection.
3. **Developer and evidence tooling.** Shell runners, TLA+ models, QEMU boots,
   patch replay, Apple Container integration, generated evidence, and claim
   ledgers. These execute with developer/operator privileges and protect the
   integrity of engineering decisions, not tenant runtime isolation.

The principal grounding documents are
`capsched/capsched-ai/design/architecture.md`,
`capsched/capsched-ai/design/compact.md`,
`capsched/capsched-models/assurance/0001-hypervisor-grade-domain-separation-case.md`,
`capsched/capsched-models/analysis/0018-protection-claim-evidence-map.md`,
`capsched/capsched-models/analysis/implementation-claim-ledger-gate-v1.json`,
and `linux-patches/patches/capsched-linux-l0/series`.

## Threat Model, Trust Boundaries, and Assumptions

### Security-relevant assets and privileges

The highest-value runtime assets are:

- Domain identity, non-reused generation, epoch, and sealed authorization
  receipts;
- CPU activation authority, frozen runnable authority, scheduler placement,
  and root CPU/service budgets;
- task binding, cgroup/domain membership interpretation, and scheduler
  selected/current state;
- MemoryViews, page ownership, direct-map and TLB isolation, mutable kernel
  state, page-cache overlays, and shared-buffer policy;
- QueueLease, DMA/IOMMU mappings, descriptor publication, interrupt routes,
  device/VF generations, and revoke/drain state;
- typed endpoint and service authority, caller provenance, and asynchronous
  budget settlement;
- cluster-to-node authority compilation, local admission, and revoke epochs;
- monitor keys, token validation state, audit roots, and control-plane
  authorization; and
- the integrity of Linux patches, source identities, formal contracts,
  validation evidence, negative-claim ledgers, and promotion decisions.

### Runtime trust boundaries

1. **Domain userspace to Linux kernel.** Syscalls, ioctls, filesystems,
   sockets, cgroups, scheduling policy, BPF, io_uring, device interfaces, and
   task lifecycle events cross this boundary. Domain userspace is untrusted.
2. **One Domain to another within shared Linux.** Scheduler queues, global
   allocators, page cache, kernel objects, network/block state, and global
   metadata are shared-kernel hazards. A Linux pointer or tag alone is not a
   protection boundary.
3. **Domain-local Linux context to the monitor.** The future production model
   assumes Linux-visible shadow state can be forged. Only monitor-validated
   epoch/token, placement, root budget, MemoryView, IOMMU, and queue roots may
   create authority.
4. **Linux to hardware translation and interrupt state.** CPU stage-2/EPT,
   direct-map/TLB state, IOMMU translations, interrupt remapping, DMA, and
   device doorbells must not remain usable after revoke or reassignment.
5. **Scheduler policy state to sealed authority.** Cgroup topology,
   task-group membership, weights, vruntime, deadlines, masks, and queue state
   are mutable policy/mechanism, not authority. Sealed receipts may constrain
   them but must not be silently rewritten from them.
6. **Caller Domain to service Domain.** Filesystem, network, device, broker,
   or other service work must consume typed caller-derived authority and a
   bounded caller budget. Service ambient privilege is not caller authority.
7. **Synchronous caller to asynchronous execution.** Workqueues, task_work,
   io_uring workers, kthreads, timers, softirq, RCU callbacks, and completions
   must carry caller Domain, epoch, frozen authority, lifetime, and budget.
8. **Cluster control plane to node-local authority.** Cluster intent must be
   authenticated, scoped, epoch-fresh, and compiled into local authority
   before use. Cluster objects must not be executable authority on their own.

### Engineering and supply-chain trust boundaries

1. **Upstream Linux to the private patch queue.** Upstream movement, merge
   conflicts, semantic drift, or a changed base can invalidate source maps,
   models, and test evidence.
2. **Project-control records to Linux source promotion.** Models and QEMU
   evidence can authorize only the claim classes they actually establish.
   A successful local test must not silently promote production claims.
3. **Repository content to developer/operator execution.** Patch recreation,
   validation runners, build scripts, TLA tooling, QEMU, and container scripts
   run with local privileges. A malicious repository change can become code
   execution when an operator invokes these tools.
4. **Mutable local outputs to accepted evidence.** `build/`, local worktrees,
   logs, JSON results, and long-job metadata are ignored and mutable.
   Evidence acceptance requires immutable input hashes, regular-file and
   symlink checks, race checks, exact Git identities, independent closure, and
   explicit negative claims.
5. **Private Git remotes to local state.** Pushed branch identities,
   submodule commits, patch-series order, and recreated Linux commits must
   remain consistent. A clean worktree is not enough if the remote or
   submodule identity differs.

### Actors and controlled inputs

**Attacker-controlled runtime inputs**

- all data and concurrency generated by Domain userspace;
- task creation, exit, exec, cgroup movement, affinity, migration pressure,
  wakeups, scheduling-class requests, and deliberate race timing;
- malformed endpoint requests, packet/block/file payloads, io_uring chains,
  BPF programs where permitted, and device/VF traffic;
- resource exhaustion, allocation failure pressure, slot exhaustion,
  generation saturation, hotplug/revoke races, and stale references; and
- compromised Domain-local kernel-context execution in the intended
  production threat model.

**Operator-controlled inputs**

- Kconfig, kernel command line, scheduler/cgroup policy, Domain admission,
  placement, co-tenancy, cluster intent, service selection, monitor policy,
  device assignment, and keys;
- the selected Linux base, patch series, build toolchain, QEMU/VM profile,
  deployment manifests, and evidence-retention policy; and
- authorization to promote experimental branches or evidence classes.

Operators are privileged but can make mistakes. Unsafe combinations should
fail closed and should not make unsupported protection claims.

**Developer-controlled inputs**

- architecture documents, TLA+ models/configurations, analysis JSON, Linux
  patches, source gates, validation scripts, expected hashes, fixtures, and
  claim ledgers.

These inputs are trusted only after review and reproducible validation. Test
fixtures, generated logs, commit messages, documentation, and model success
are not runtime authority.

### Required security invariants

- Linux-visible Domain, cgroup, task, scheduler, or device metadata never
  mints monitor authority.
- No task enters or remains executable without a live, frozen, epoch-correct
  runnable use, valid binding, allowed placement, and remaining root budget.
- Revocation is generation/epoch based, non-reusing, and ordered before
  visibility, execution, DMA, IRQ, or resource reuse.
- Admission, enqueue, final selection, current-task continuation, migration,
  fork/exec, cgroup move, CPU online/offline, and teardown each revalidate the
  exact state they consume.
- Failure is neutral and fail closed: no partial queue contribution, stale
  fallback, catch-up burst, residual reference, alias, ambient service use, or
  unauthorized execution.
- Scheduler and cgroup mutable state remain separate from sealed authority.
  Denied branches cannot regain visibility through stale summaries.
- Async execution preserves caller identity, epoch, frozen authority,
  lifetime, and charge subject across queueing, retry, callback, cancel,
  flush, and teardown.
- Memory, page-cache, direct-map/TLB, IOMMU, device queue, descriptor,
  interrupt, and DMA ownership cannot survive revoke or cross reassignment.
- Cluster intent compiles into node-local authority and cannot bypass local
  admission or epoch freshness.
- Evidence and promotion are fail closed: exact source identity, input hashes,
  evidence class, limitations, and unsupported claims remain machine-readable
  and independently reproducible.
- Default-off prototypes, test-only code, source maps, traces, or virtual
  synthetic tests cannot be described as monitor verification, bare-metal
  validation, production protection, cost efficiency, or deployment
  readiness.

### Assumptions and current limitations

- The future monitor, its keys, token validation, stage-2/EPT ownership, root
  budget timer, IOMMU roots, and immutable audit root are intended trusted
  computing-base components. They are not implemented or validated as a
  production boundary in the current repository.
- Hardware virtualization, IOMMU, interrupt-remapping, and cache/TLB behavior
  are assumed correct only after future architecture-specific validation.
- Operators, build hosts, compilers, private Git hosting, and signing keys are
  trusted administrative dependencies. The repository does not currently
  prove a hermetic or reproducible production supply chain.
- The current private patch queue includes experimental/default-off/test-only
  work. Existing QEMU and model evidence is prototype evidence, not a
  production isolation guarantee.
- Side-channel containment, speculative-execution policy, shared-resource
  interference, service-Domain TCB size, and control-plane authentication are
  open design areas.
- Denial of service by a Domain against itself is generally lower priority.
  Cross-Domain starvation, root-budget bypass, monitor starvation, or global
  kernel resource exhaustion remains in scope.

## Attack Surface, Mitigations, and Attacker Stories

### Scheduler, task lifecycle, and cgroup state

Relevant surfaces include enqueue/pick/tick, wakeup and remote wake, task
selection/current settlement, CFS/RT/deadline/sched_ext/core/proxy/server
interactions, affinity, migration, hotplug, fork/clone/exec/exit, cgroup moves,
and task-group topology.

Realistic attacker stories include racing a generation change with enqueue,
moving a task between cgroups after validation, retaining a stale binding
through exec, provoking current-task continuation after revoke, exhausting
slot identities, or reaching a fallback path that runs a denied task.

Existing mitigations include source-free state-machine modeling, exact source
maps, default-off Kconfig boundaries, generation saturation and non-reuse
requirements, rq-lock/RCU/refcount designs, deterministic negative cases, and
strictly scoped claim ledgers. Current synthetic R6 evidence does not establish
live scheduler coverage.

### Async and service execution

Relevant surfaces include workqueue, task_work, io_uring workers/reissue,
kthreads, timers, softirq, RCU, network/block completion, driver reset and
maintenance work, rescuer paths, cancel/flush, and callback teardown.

The central attacker story is a confused deputy: a caller causes privileged
service or asynchronous work to execute after caller authority expired, under
the wrong Domain, or against a service's ambient authority/budget. Another is
a lifetime race where cancellation or RCU teardown releases the frozen use
while a callback can still consume it.

The repository has extensive model and source-map evidence for carrier shape,
but no complete production carrier implementation or runtime coverage.

### Memory and shared mutable Linux state

Relevant surfaces include allocator/slab metadata, task/mm/VMA/fd/cred state,
direct map, page tables and TLBs, page cache/writeback/reclaim, pipe/socket
buffers, BPF maps, shared services, and per-CPU/global caches.

The production attacker is assumed capable of Domain-local kernel-context
memory corruption. Linux-only tags therefore cannot prevent cross-Domain
writes. Monitor-backed page ownership, MemoryViews, direct-map removal,
translation invalidation, and smaller service-mediated shared state are
required. Current formal models identify ordering obligations but are not
implementation evidence.

### Device, DMA, IRQ, and network control

Relevant surfaces include queue assignment, VF/VSI generation, descriptor
write and doorbell publication, page-pool/XDP/AF_XDP memory, NAPI, IRQ routes,
IOMMU mappings/TLBs, resets, representors, offloads, firmware work, and queue
revoke/drain/quarantine.

Attacker stories include DMA continuing after a Domain epoch is revoked,
reusing a VF identifier while stale descriptors or IRQ routes survive,
submitting through a stale queue token, or using service reset work to act
with broader authority. Netdev down or Linux ring cleanup is not itself a
monitor-owned revoke proof.

Existing QueueLease and modern-NIC models are model-supported only. No
monitor-backed QueueLease, IOMMU ownership, or DMA attack validation exists.

### Monitor, control plane, and cluster authority

Future exposed surfaces include token/receipt parsing, key and epoch
management, Domain registry, local lease compilation, placement/co-tenancy,
root budgets, MemoryView/IOMMU programming, audit logging, and control-plane
recovery.

Critical attacker stories include forging or replaying a sealed token,
accepting a cluster lease directly as local execution authority, confusing
tenant/node identity, rollback to an old epoch, budget overflow, or a monitor
interface that trusts mutable Linux shadows.

These surfaces are design targets rather than deployed code in this
repository. Authentication, key rotation, rollback protection, distributed
consensus, recovery, and monitor ABI hardening remain open.

### Patch, build, validation, and evidence tooling

The recreation script clones upstream Linux and applies the recorded patch
series. Validation scripts invoke compilers, Git, TLA+, QEMU, container
commands, and local cleanup. Generated evidence is stored outside Git.

Realistic engineering attacks include changing a runner and reusing an old
result, substituting a symlink for a trusted artifact, racing evidence while
it is copied, changing a submodule or remote branch after local validation,
smuggling behavior into a claimed no-behavior patch, or making a broad claim
from a narrow synthetic test.

Existing mitigations include exact SHA-256 binding, immutable snapshots,
regular-file/symlink checks, before/after manifests, clean-tree and remote-ref
checks, strict patch scope, checkpatch/build/QEMU gates, expected unsafe model
counterexamples, independent closure, and explicit false safety flags.
These controls protect decision integrity but do not make an untrusted build
host safe.

### Repository-context vulnerability classes

The most important classes are:

- stale/replayed authority and generation confusion;
- authorization bypass and fail-open fallback;
- cross-Domain memory, DMA, IRQ, queue, or service confused-deputy access;
- use-after-free, refcount/RCU/locking errors, and partial teardown;
- race conditions across lifecycle, migration, hotplug, revoke, and async
  completion;
- integer overflow, saturation, slot aliasing, or budget-accounting errors;
- unsafe parsing or cryptographic misuse in future monitor/control-plane
  receipts and keys;
- supply-chain or evidence-integrity bypass in patch/build/promotion tooling;
- denial of service that crosses Domain or monitor budget boundaries; and
- claim inflation that promotes prototype evidence into production
  deployment without the required protection roots.

Traditional web classes such as XSS, CSRF, browser session management, and SQL
injection are not primary for the current repository because it has no
deployed web application. They become relevant if a future management API or
dashboard is added. Secrets leakage is currently most relevant to private Git,
signing, monitor keys, build logs, and future cluster-control credentials.

### Out-of-scope or reduced-priority stories

- A malicious user who already has unrestricted host root/operator authority
  can replace the kernel, monitor, or evidence. Protecting against that actor
  requires a separate secure-boot, measured-build, key-custody, and operational
  threat model.
- Bugs confined to documentation, dead model fixtures, or default-off tests
  are lower severity unless they cause an unsafe promotion decision or are
  invoked with developer privileges on untrusted input.
- QEMU/TCG synthetic success is not a bare-metal, side-channel, performance, or
  production-isolation claim.
- Domain self-denial is lower priority unless it consumes global resources or
  violates another Domain's budget or availability.

## Severity Calibration (Critical, High, Medium, Low)

### Critical

Use Critical for a realistic path in an implemented/deployed protection
boundary that directly enables cross-Domain or monitor compromise with
little additional privilege. Examples include:

- forging/replaying a monitor RunToken or epoch to activate another Domain;
- reading or writing another Domain's memory through stale stage-2/EPT,
  direct-map/TLB, or IOMMU state;
- retaining DMA/IRQ/queue authority after revoke or reassignment;
- bypassing root CPU budgets to execute indefinitely across tenant isolation;
  or
- a production supply-chain/promotion bypass that ships attacker-controlled
  kernel or monitor code as trusted release output.

The same defect in an unreachable default-off synthetic prototype is not
automatically Critical; severity depends on whether it can enter a real build
or materially authorize promotion.

### High

Use High for a strong cross-boundary primitive, serious privileged code
execution path, or evidence bypass likely to cause unsafe implementation
promotion. Examples include:

- a live scheduler path that runs a denied Domain after revoke;
- an async/service confused deputy that uses another Domain's endpoint or
  budget;
- a use-after-free in frozen authority, task binding, queue lease, or teardown
  reachable from untrusted Domain actions;
- generation/slot aliasing that restores stale authority;
- a patch recreation or validation runner injection reachable when an
  operator processes an attacker-controlled repository; or
- closure/promotion logic that accepts changed source or tampered evidence and
  enables a behavior-changing stage.

### Medium

Use Medium for bounded cross-Domain availability impact, incomplete
fail-closed behavior without direct unauthorized execution, meaningful local
developer-tooling compromise requiring unusual preconditions, or controls
whose failure weakens assurance without independently creating runtime
authority. Examples include:

- a Domain causing global scheduler work amplification or starvation within a
  bounded but operationally significant window;
- validation that misses one warning class but remains blocked from
  production promotion by independent controls;
- unsafe cleanup confined to disposable build outputs; or
- misleading evidence metadata that does not pass the independent
  authorization gate.

### Low

Use Low for issues with minor impact, strong trusted-operator prerequisites,
or no plausible path to runtime or promotion boundaries. Examples include:

- cosmetic inconsistency in historical documentation with machine-readable
  false claims still intact;
- a non-sensitive local path disclosure in ignored developer logs;
- inefficiency in a test-only runner that cannot affect accepted results; or
- a default-off fixture bug rejected by source, build, and authorization
  gates.

Severity must be calibrated against the repository's actual current state.
The absence of a production monitor and deployment path lowers exploitability
for future-runtime stories, but it does not lower the architectural importance
of flaws that would become protection roots. Findings should state whether
they affect current developer/supply-chain execution, an experimental kernel,
or a future production boundary.

Repository: target_sha256_00f33333870097e986c36684a58470fe51e779600219938b209ca597ae663190
Version: 25e925f5364b967e4a7a9d44787e9c0a9ca6cf5b
