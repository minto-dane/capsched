# Bounded Domain Residency Model

This model is the first executable reference for `RESIDENCY-001`. It asks how
a Monitor-owned global Domain identity can be projected into fewer local
scheduler slots without turning a slot, Linux hint, or stale generation into
execution authority.

The modeled population is deliberately larger than the resident capacity:

```text
ordinary global Domains:       5
guaranteed Domains:            3
authoritative CPUs:            2
replaceable slots per CPU:     1
total replaceable slots:       2
```

The model separates a current global `DomainEpoch`, a CPU-local
`SlotGeneration`, a `CpuIncarnation`, and the exact active binding. A resident
binding is only a Monitor-owned translation cache. Activation still requires
an exact Monitor source and a trusted active reference.

## Scenarios

Four safe configurations isolate different obligations:

| Configuration | Obligation |
| --- | --- |
| `SafeAdmission` | three guaranteed Domains receive activation through two replaceable slots despite arbitrary Linux hint churn |
| `SafeMigration` | an exclusive binding drains at the source before destination installation and activation |
| `SafeHotplug` | CPU authority and resident state drain before offline, then return with a fresh `CpuIncarnation` |
| `SafeRevoke` | all replicas and active references drain before the Domain epoch commits |

The management/recovery identity is independently sealed and does not consume
a replaceable general slot. Ordinary same-Domain residency on several CPUs is
allowed; uniqueness is checked only for the explicitly exclusive Domain.

## Fairness Boundary

`LinuxHintNoise` has no fairness assumption. It can continuously replace CPU,
Domain, and generation proposals and it never becomes authoritative.

Weak fairness is attached to Monitor protocol actions and separately to
`HardwareRelease(c)` for each CPU. This represents eventual completion of an
already bounded trusted lease/reference. It does not assume a cooperative
Linux scheduler, a useful task inside a compromised Domain, or a wall-clock
latency bound.

The one-shot admission scenario starts with every Domain already admitted and
uses one request per guaranteed Domain. It proves finite reference-protocol
progress under the stated assumptions, not dynamic admission/rejection,
recurring production service, unbounded admission, slot-generation rekey, or
request-ID semantics.

## EC1 TLC Result

Validation 0289 captured and replayed TLC 2.19 with one worker, fingerprint
index 0, and seed 20260809014235:

| Configuration | Generated | Distinct | Depth | Result |
| --- | ---: | ---: | ---: | --- |
| `SafeAdmission` | 190,271 | 2,660 | 21 | pass |
| `SafeMigration` | 39,761 | 560 | 8 | pass |
| `SafeHotplug` | 34,791 | 490 | 7 | pass |
| `SafeRevoke` | 70,071 | 980 | 8 | pass |

All 22 negative configurations produced the expected counterexample. Three
are temporal failures: Linux-gated admission, skipped guaranteed admission,
and absent hardware quiescence. Fourteen transition mutants violate their
target safety property after a valid initial state. Five boundary mutants are
rejected directly in the initial state:

```text
LinuxOwnsBinding
ResidentSlotIsAuthority
LinuxMintsActivation
ManagementBindingLost
LinuxWritesRegistry
```

Initial-state rejection is recorded separately because it checks admissible
state ownership, not a protocol transition. The claim-specific EC1 capsule
replayed every safe and unsafe configuration, bound exact model/config/tool
hashes, and verified every expected property name. Its capsule id is
`efecb20ac9132caf6e20e6a8faac47704fad6429a48416910be62615163e5314`.

An earlier parallel run was rejected because its search depth did not match
the frozen oracle even though generated and distinct counts matched. That
diagnostic result is retained, but only the deterministic capsule supports the
claim.

Example safe invocation:

```sh
java -XX:+UseParallelGC \
  -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC -workers 1 -fp 0 -seed 20260809014235 \
  -config BoundedDomainResidencySafeAdmission.cfg \
  BoundedDomainResidency.tla
```

## Composition Boundary

The protocol refines the `ROOTSCHED-001` handoff as:

```text
NeedResident(DomainID, DomainEpoch, eligible CPUs)
  -> ResidentReady(exact CPU/incarnation/slot/generation held)
    -> Activate(exact held binding, root budget, bounded lease)
      -> ExpireOrStop
        -> TrustedReferenceRelease
```

It does not yet compose dynamic admission/rejection, recurring request
identity/cancellation, bounded churn/overflow work, or generation rekey. Those
are the immediate `RESIDENCY-DYN-001` refinement. Physical slot backing,
kernel entry, `MemoryView`, TLB fences, root-budget conservation across
migration, and cross-node fencing remain `ENTRY-001 + CODE-001`, later
memory/state composition, and `CLUSTER-PART-001` obligations.

R6's fixed-depth forest can only refine the bounded Linux policy projection.
It cannot be the global Domain registry, own slot generations, mint active
authority, or use Linux task lifetime as a trusted eviction veto.

## Non-Claims

This model does not select a production cache or replacement algorithm,
modify Linux, implement a Monitor, establish timer WCET, prove memory or DMA
isolation, or provide protection, performance, cost-efficiency, multi-cluster,
or datacenter deployment evidence.
