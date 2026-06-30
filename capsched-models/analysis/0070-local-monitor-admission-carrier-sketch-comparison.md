# Analysis 0070: Local Monitor Admission Carrier Sketch Comparison

Status: Draft implementation-facing sketch comparison with model gate

Date: 2026-06-30

Related artifacts:

```text
analysis/0069-local-monitor-admission-abi-semantics.md
analysis/local-monitor-admission-carrier-sketch-comparison-v1.json
formal/0047-monitor-admission-carrier-sketch-model/
validation/0069-monitor-admission-carrier-sketch-tlc.md
```

## Purpose

N-097 compares two implementation-facing carrier sketches for
`LocalMonitorAdmissionABI-v0` without choosing code layout or implementing
either one:

```text
direct-call-first sketch
monitor-owned-ring-first sketch
```

The comparison is not "secure but slow" versus "fast but weaker". Weakening is
not allowed. The ring path is a throughput refinement of the same monitor-owned
authority semantics, not a different trust model.

## Candidate A: Direct-Call-First Sketch

Semantic shape:

```text
Linux service Domain builds typed request
  -> synchronous monitor entry
  -> monitor validates request class, epochs, replay window
  -> monitor writes receipt ledger
  -> monitor returns response/receipt handle
  -> Linux updates non-authoritative shadow
```

Strengths:

```text
smallest state machine
lowest replay ambiguity
simple failure terminality
simple revoke ordering
easy to compare against TLA model
good reference semantics for later ring refinement
```

Costs:

```text
monitor transition per admission/revoke/query
poor batching
poor high-churn queue-lease scaling
weaker fit for cluster-scale admission bursts
```

Direct-call-first is a good reference semantics candidate. It is not enough for
the eventual data-center performance target unless admission volume is low or
ring batching is added later.

## Candidate B: Monitor-Owned-Ring-First Sketch

Semantic shape:

```text
Linux service Domain writes request payload into a request carrier slot
  -> monitor claims slot using monitor-owned slot epoch/generation
  -> monitor validates request class, epochs, replay window
  -> monitor writes receipt ledger
  -> monitor publishes response with monitor-owned response epoch
  -> Linux consumes response and updates non-authoritative shadow
```

Strengths:

```text
batching
lower transition amortization
better multi-queue admission scaling
better fit for high-rate queue lease churn
natural place for per-node admission queues
```

Additional obligations:

```text
monitor-owned slot claim
monitor-owned head/tail or equivalent ownership
per-slot generation
replay-window ownership below Linux
response publication after monitor claim
batch epoch stability
pending response drain before revoke complete
DoS accounting for full rings and dropped requests
```

Ring-first is closer to the data-center performance goal, but it has a larger
semantic surface. It must refine the direct-call reference semantics rather
than replacing monitor authority with ring state.

## Shared Invariants

Both sketches must preserve:

```text
monitor response requires a monitor entry/claim
replay check occurs before ledger write or success response
receipt ledger write is monitor-owned
Linux-visible shadows derive from monitor ledger state
failure is terminal for the request attempt
revoke complete requires pending response drain and shadow invalidation
performance cost metrics never authorize security decisions
```

## Ring-Specific Invariants

The ring sketch additionally requires:

```text
Linux ring slot is not authority
monitor claim precedes response publication
ring slot generation cannot be Linux-only replay protection
batch reordering cannot cross monitor/local lease epoch boundaries
revoke complete requires pending ring responses drained or invalidated
```

## Direct-Call-Specific Invariants

The direct-call sketch additionally requires:

```text
monitor entry is not bypassable by a Linux-owned response store
success response requires replay-window consumption
failure/stale/replay response cannot be retried as success under same nonce
```

## Staging Recommendation

The current staging recommendation is:

```text
reference semantic sketch:
  direct-call-first

production throughput refinement:
  monitor-owned-ring-first

compatibility rule:
  ring behavior must refine the direct-call semantic model
```

This is not a binary ABI selection. It is a modeling and implementation-order
recommendation: use direct-call semantics as the small reference, then require
ring refinement for the data-center throughput target.

## Rejected Designs

Rejected:

```text
Linux-owned response store for direct calls
Linux ring slot as request or response authority
ring response before monitor slot claim
Linux-only slot generation as replay protection
batch reorder across epoch boundary
shadow refresh from carrier state instead of receipt ledger
revoke complete while ring responses are pending
performance cost metric as security authority
```

## Consequence

The next step can define a direct-call reference ABI sketch or a ring refinement
sketch, but either must cite `LocalMonitorAdmissionABI-v0` and this comparison.
No Linux behavior change, monitor code, or binary ABI layout is authorized by
this note.
