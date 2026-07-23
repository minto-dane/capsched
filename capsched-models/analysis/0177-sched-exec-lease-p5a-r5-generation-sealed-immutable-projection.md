# Analysis 0177: SchedExecLease P5A-R5 Generation-Sealed Immutable Projection

Date: 2026-07-24

Status: source-free successor architecture gate. This analysis may authorize
only an R5-E1 source/locking/lifetime evidence plan after independent
validation. It does not authorize Linux source, an R5 layout, runtime behavior,
or any protection, latency, performance, production, or datacenter claim.

## Trigger

Validation/0272 closes the exact R4 arm64 timing result as complete valid
negative evidence. Run `20260723T-p5a-r4-e4-arm64-timing-r7`, result SHA-256
`edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951`,
contains all 682 cells and 6,820,000 paired samples with KUnit 7/0/0, QEMU
zero, exact paused-QMP placement, zero diagnostics, byte-exact parser
regeneration, and complete artifact integrity.

Fixed gates reject 362 cells with 692 breaches. Two independent closures
produce
`b5279add6127b35472cc15d2345c37c3bd1a3a4b2030fe4f87d30abe7a4297af`
and
`75e734bc61e239db868b426c8cf37d40677ff3a04567da72437bcdafa41a2719`,
normalized to
`8ebacd3c03dee0519a978cd21a7537b729fb61267d2491b70f76f54219fa84b5`.

The distribution rules out a cosmetic retry:

| Family | Rejected | p99 | p99.9 | max | max-only |
| --- | ---: | ---: | ---: | ---: | ---: |
| publication | 184/288 | 0 | 0 | 184 | 183 |
| picker/kick | 3/144 | 0 | 0 | 3 | 3 |
| IRQ dispatch | 4/9 | 4 | 1 | 1 | 0 |
| recovery | 105/144 | 97 | 96 | 104 | 8 |
| notifier | 48/48 | 48 | 48 | 48 | 0 |
| current stop | 0/24 | 0 | 0 | 0 | 0 |
| offline | 18/25 | 15 | 15 | 18 | 3 |

Publication and picker contain primarily isolated maximum tails under virtual
TCG. Recovery, notifier, offline, and IRQ dispatch contain sustained
percentile failures. R5 therefore must remove mutable projection repair and
notifier-driven repair from rq-lock quanta; it may not merely tune queueing,
relax gates, or retry the same implementation.

## Selected Architecture

R5 is **Generation-Sealed Immutable Projection Install**.

An authority publication release-publishes one frozen descriptor:

```text
generation
eligibility state
selector key
authority digest
membership sequence
```

The descriptor is immutable for that generation. Generation reuse is
forbidden; saturation transitions to Blocked.

A preallocated, coalescing compile owner builds an immutable projection view
outside the rq lock. A view is not eligible for installation until it carries
a sealed receipt containing the exact generation, selector key, membership
sequence, authority digest, content digest, and build start/end observations.
Any change during compilation discards the view and retries the newest desired
generation. An incomplete, raced, unsealed, or allocation-failed build leaves
the local projection Blocked.

The rq-lock phase performs only a constant-work install:

```text
take one owning rq lock
acquire-read the current frozen descriptor
verify the sealed receipt and exact generation/membership/selector/digest
swap one RCU-protected immutable-view pointer
record one installed generation/state
drop the rq lock
retire the old view after references and an RCU grace period
```

It does not walk tasks, entities, leaves, buckets, projections, cpumasks, or
membership; allocate; hash variable input; compile; queue work; wait; flush; or
cancel. The compiled view carries any finite selector summary needed by the
later picker proof. This analysis does not assume that the summary can be
implemented correctly; R5-E1 must prove the representation and update
boundary before layout drafting.

## Picker Trust Boundary

The picker may trust an installed view only when all of these hold:

```text
view state is Sealed
view generation equals an acquire-read published generation
view membership sequence equals the current membership sequence
view selector key and authority digest match the frozen descriptor
the selected entity has a view membership proof
the final task-local lease check passes
```

Failure is locally ineligible/Blocked. The picker may set one preallocated
`compile_needed` edge but cannot build, install, scan, allocate, wait, invoke
policy or the monitor, or mint fallback authority. Queue/work pending state,
receipt presence without field equality, and an old view pointer are never
authority.

This preserves the project essence: mutable Linux cache state cannot create
execution authority. The installed view is still Linux-side proof material,
not a monitor RunToken or production authority.

## Demand Compilation and Current Execution

R4's projection-repair notifier is removed. Publication does not enumerate all
rqs or wait for any projection. A picker mismatch, enqueue handshake, or other
source-mapped local demand coalesces one compile owner to the newest desired
generation. Duplicate publications cannot add queue depth or owners.

Current execution remains a separate obligation. Publication may coalesce one
current-stop distributor over the bounded current-contributor index, but that
distributor may only request scheduler observation. It cannot compile, install,
repair, or make a view trusted. R4 evidence that the isolated current-request
family passed 24/24 is historical input, not R5 acceptance.

Linux `resched_curr()` remains a request rather than completion. Production
revocation still requires a monitor-owned interrupt/timer and receipt. R5-E1
must map the current-contributor index, restart rule, later distinct scheduler
observation, and hotplug drain without reinstating projection repair.

## Stable-Window Liveness

Safety is unconditional: an old or raced view stays untrusted under continuous
publication. Availability is conditional.

A stable window requires:

- generation, frozen descriptor, selector key, and membership sequence stop
  changing;
- compile owners and current-stop distribution are weakly fair;
- finite admitted membership and memory bounds hold;
- allocation for one bounded view eventually succeeds; and
- hotplug or retirement is not concurrently draining the owner.

Under those assumptions, one exact-generation view can be built, sealed, and
installed per demanded rq. No global last-settlement deadline exists. A
non-demanded stale rq may remain Blocked indefinitely without weakening
safety. A demanded rq must either install the stable view or retain an explicit
failure/Blocked state; it may never fall back to stale execution.

These are logical conditions, not a wall-clock, performance, cost, or
availability SLO.

## Enqueue, Migration, Offline, and Lifetime

- Enqueue performs a current-descriptor handshake. It contributes only to a
  matching sealed view or records one compile demand and remains untrusted.
- Migration removes the source contribution before source unlock. Destination
  trust begins only after destination placement and its exact view handshake;
  there is no simultaneous source/destination contribution.
- Offline clears accepting and swaps the installed pointer to a Blocked
  sentinel in O(1) under the rq lock. Compile cancellation, work flush, view
  destruction, and RCU waiting occur after scheduler locks are released.
- Each view has explicit builder, installed, picker-reader, and retirement
  lifetime states. Free requires zero references and the required RCU grace
  period.
- An allocation or compile failure cannot preserve an old view as trusted
  merely for availability.

## Current Linux Mechanism Anchors

The source basis is primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`.

Current Linux provides mechanisms, not an R5 implementation:

- `rcu_assign_pointer()` and `rcu_replace_pointer()` publish RCU pointers;
- `call_rcu()` supplies deferred retirement;
- `refcount_t` provides saturating reference accounting;
- seqcount APIs expose retryable sequence observations;
- `resched_curr()` requires the rq lock; and
- workqueue pending state coalesces queue ownership but is not authority.

R5-E1 must determine whether seqcount, a membership lock, or another existing
sequence source can provide the exact build receipt. The architecture does not
approve lockless traversal of mutable scheduler structures and does not assume
RCU alone makes a multi-object snapshot consistent.

## Rejected Alternatives

- Relaxing, environment-scaling, or deleting R4 thresholds is rejected.
- Reusing R4's notifier/recovery repair quanta with smaller batches is
  rejected.
- Installing a partially compiled view and repairing it in the picker is
  rejected.
- Treating RCU pointer publication alone as a consistency receipt is rejected.
- Building or validating variable-size membership while holding an rq lock is
  rejected.
- Falling back to the previous generation after allocation/build failure is
  rejected.
- Synchronously compiling every rq at publication is rejected.
- Conflating current stop request with projection repair or monitor completion
  is rejected.
- Claiming virtual TCG timing as bare-metal performance is rejected.

## Next Gate

After formal and evidence validation, only R5-E1 may be drafted. It must
source-map:

1. descriptor publication and non-wrapping generation;
2. membership sequence ownership and retry semantics;
3. bounded immutable-view representation and admission limit;
4. compile owner, latest-generation coalescing, and allocation failure;
5. exact receipt fields and final seal;
6. O(1) rq-lock install and RCU retirement;
7. picker membership proof and EEVDF-compatible selection summary;
8. enqueue/migration/current/offline handshakes;
9. lock order, references, RCU, hotplug, and teardown; and
10. deterministic races plus later timing gates.

No R5 source, layout, configuration, primary-Linux or patch-queue change,
runtime denial, N-136 runtime charge, monitor integration, protection,
bare-metal latency, performance, cost, deployment, multi-node, multi-cluster,
or datacenter readiness is authorized.
