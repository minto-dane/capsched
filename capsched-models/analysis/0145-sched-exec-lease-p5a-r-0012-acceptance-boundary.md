# Analysis 0145: SchedExecLease P5A-R 0012 Acceptance Boundary

Date: 2026-07-04

Status: review complete. `0012` is useful corrective evidence for the
synthetic ordinary-CFS negative test path, but it is not accepted as production
denial policy, complete CFS deny-and-repick correctness, cost evidence, or
protection.

## Purpose

Validation/0186 proves that corrective patch `0012` can complete the current
synthetic negative workload:

```text
allowed task runs
denied task is not observed as next_comm
workload returns success
```

The same result also exposes a design boundary. A post-EEVDF deny-and-repick
filter can make progress only by adding a fallback search after a denied
candidate has already shaped the ordinary CFS choice. In `0012`, that fallback
can intentionally prefer an allowed runnable entity over idle even when the
entity is not CFS-eligible.

That is acceptable as a narrow test-path repair. It is not acceptable as the
final production scheduler capability model without a stronger selection
structure and fairness/cost proof.

## Source Facts

The test-only harness remains synthetic and default-off:

```text
linux/init/Kconfig:896
linux/kernel/sched/fair.c:959
linux/kernel/sched/fair.c:962
linux/kernel/sched/fair.c:967
```

The draft ordinary-CFS path is disabled for sched_ext, core scheduling, and
proxy execution:

```text
linux/kernel/sched/fair.c:1025
```

The denial predicate is still not authority:

```text
linux/kernel/sched/fair.c:1091
```

The test predicate reads `task->comm`, so it is intentionally unsuitable as
real authority even aside from being synthetic:

```text
linux/kernel/sched/fair.c:962
```

The attempt-local denial carrier is bounded to one denied identity and one
retry:

```text
linux/kernel/sched/fair.c:954
linux/kernel/sched/fair.c:955
linux/kernel/sched/fair.c:1108
```

The corrective fallback is an rb-tree scan:

```text
linux/kernel/sched/fair.c:1343
linux/kernel/sched/fair.c:1369
linux/kernel/sched/fair.c:1378
linux/kernel/sched/fair.c:1386
```

The fast ordinary-CFS class path calls the draft picker, but the broader class
loop and DL fair-server path are not covered by this claim:

```text
linux/kernel/sched/core.c:6149
linux/kernel/sched/core.c:6164
linux/kernel/sched/fair.c:10310
linux/kernel/sched/fair.c:10317
linux/kernel/sched/fair.c:10330
linux/kernel/sched/fair.c:15733
```

## Design Meaning

The `0010` and `0011` failures were not merely slow-host artifacts. They showed
that "deny the selected candidate and retry" has an authority/progress problem
inside CFS:

```text
CFS can select an entity because it is eligible.
SchedExecLease can deny that entity after selection.
The remaining allowed entity may be runnable but not CFS-eligible.
Returning NULL can idle.
Retrying can revisit the same denied shape.
```

Patch `0012` resolves the test by choosing progress over idle after denial has
already been observed. That is a useful experiment, but it is semantically
louder than a pure capability check. It changes the local fairness/latency
tradeoff of the picker in the enabled test path.

## Production Direction

The production direction should avoid making post-filter fallback the root
mechanism. Candidate designs to analyze next:

```text
picker-visible lease eligibility:
  make pickability part of the data structure or subtree metadata so denied
  entities are not selected first.

domain/lease partition before CFS pick:
  choose an eligible execution-lease bucket first, then run normal CFS inside
  that bucket.

bounded candidate window:
  define a small, source-proved window of candidate alternates with explicit
  fairness and starvation bounds.

fail-closed plus settlement:
  if only denied candidates are runnable, settle that state explicitly through
  quarantine/control/revoke semantics rather than letting idle/newidle behavior
  become implicit authority.
```

Any production design must satisfy:

```text
no unbounded O(n) hot-path scan
no hidden fallback authority
no single-denial-capacity completeness claim
no unsupported core/proxy/sched_ext/DL-server claim
explicit group-hierarchy semantics
explicit fairness and latency model
explicit cost model
negative tests for denied execution, same-candidate repick, idle fallback,
stale identity, wakeup/newidle behavior, and cross-path leakage
```

## Acceptance Boundary

Accepted from `0012`:

```text
synthetic ordinary-CFS test-only denial path can make allowed progress in the
0186 QEMU workload.
```

Not accepted from `0012`:

```text
production execution lease denial
complete CFS deny-and-repick correctness
runtime coverage
fairness correctness
cost efficiency
capability semantics
monitor enforcement
protection
deployment readiness
datacenter readiness
```

## Next

Record validation/0187 as the final security/overclaim boundary review for
`0012`. Then either:

```text
1. keep 0009-0012 as a private experimental patch stack and design a
   production-quality picker-visible structure; or
2. rewrite the P5A-R queue into a cleaner next patch series after the
   production selection model is chosen.
```

Do not normalize patch-queue metadata or rewrite Linux history in the same step
as this semantic review. Metadata cleanup is a separate no-behavior maintenance
operation because it changes patch hashes and possibly recreated commit IDs.
