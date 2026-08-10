# Dynamic Residency F0 v5 Supervisor v1 Hostile Rejection

## Status

The exact v1 supervisor candidate reviewed below is locally rejected as a
normative protocol. This is negative architecture evidence. It does not issue a
validation context, close the result taxonomy, implement a supervisor, accept
F0, complete G0, or support a protection claim.

The machine-readable disposition is
`dynamic-residency-f0-v5-supervisor-v1-hostile-rejection-v1.json`.

## Reviewed Snapshot

```text
0221-dynamic-residency-f0-v5-supervised-evaluation-protocol.md
  c90bf32d32a3128e9f9d4cf7248fd9d830ac1d8abca692e9458aa6fc0b0d9fd4

dynamic-residency-f0-v5-supervised-evaluation-protocol-v1.json
  35d2f6c711a54a96841076882d97177b78a81e90dc16ff6e852e83d568d6f5f5
```

The reviewed bytes remain unchanged. Review conclusions are recorded here so
that a post-review edit cannot silently become the reviewed candidate.

## Review Provenance

| Axis | Session | Result |
| --- | --- | --- |
| asynchronous LTS and classification | `019feb5a-b381-7722-9e1e-2ce396cc003c` | local advisory reject |
| Linux supervision, accounting, and authority closure | `019feb5a-7790-7383-8d25-550c55106625` | local advisory reject |

Both reviews were read-only and independently biased. Neither reviewer has an
F3 external role, and agreement between them is not external assurance.

## Decisive Counterexamples

1. `SPV-018` can commit Internal while a buffered frame or exit observation is
   still in flight. Reversing the observation order changes the result.
2. A partial ordinary read can mark a stream invalid and a later read can
   overwrite it with complete. Conversely, a complete frame can commit before
   EOF reveals trailing bytes.
3. A corrupt or duplicate frame followed by a quota event can take `SPV-017`,
   laundering a protocol defect into Resource.
4. The same `(WORKER_RUNNING, COMPLETE, NORMAL)` product state can commit either
   Success or Reject because frame tag and receipt are hidden state.
5. Receipts omit a fresh run identity and complete context tuple, so a frame
   from one execution can be combined with exit or quota evidence from another.
6. `SPV-003` parses requester-controlled bytes outside the worker envelope, so
   parent OOM, recursion failure, or crash bypasses the claimed supervision.
7. A leader can exit normally while a descendant retains the output writer or
   consumes resources. A pidfd names the leader, not an empty execution scope.
8. A correct fixed header can carry deeply nested maximum-size JSON that attacks
   an unsupervised parent parser.

## Structural Rejection

The declared product omits worker lifecycle, EOF, frame outcome, receipt ledger,
quota arbitration, scope emptiness, final counters, cleanup, and publication.
`ANY_PRE_TERMINAL` is not a state. There is no `Init`, `Next`, `TypeOK`, reachable
state predicate, or executable classification function. Exit status and quota
cause occupy one overwriteable coordinate, and terminal guards overlap.

The protocol also overstates its launch invariant. A stopped child or cgroup
freezer does not establish that no child instruction ran. The enforceable
requirement is instead:

```text
every child instruction is charged to the fresh execution scope
and no requester-controlled byte is interpreted before sandbox-ready
```

## Classification Boundary

The successor must classify only after a quiescence barrier. Frame, wait status,
quota evidence, faults, scope state, and counters are monotone observations.
Terminal classification is one pure function over the closed evidence ledger,
not an event transition with a fallback guard.

```text
independent protocol, identity, containment, or attribution fault -> Internal
exact attributed semantic-budget exhaustion                     -> Resource
clean EOF + normal exit + empty scope + verified typed result   -> typed result
everything else                                                 -> Internal
```

An incomplete stream caused by an exact supervisor quota may support Resource.
Malformed, duplicate, trailing, cross-run, or containment evidence cannot be
hidden by a later quota. Output-body construction may have a named semantic
meter; violation of the transport frame maximum is a containment fault.

## Trust Correction

The supervisor handles fixed-format metadata and bounded opaque byte streams.
Requester parsing, schema/static/link/occurrence work, evaluation, result JSON
parsing, and serialization must remain inside supervised execution scopes. A
pinned bounded outcome checker, not the transport supervisor, interprets result
payloads.

Even then, a reference evaluator remains an untrusted producer under
F05-02-009. A normally exited evaluator can fabricate a well-framed Success.
The supervisor can establish execution provenance and containment, but positive
semantic credit still requires an independently checked proof or certificate.

## Linux Refinement Obligations

The model may list Linux mechanisms as candidates, but it must not equate their
names with the abstract guarantees:

- `cpu.max` is a bandwidth controller, not a cumulative CPU receipt;
- `memory.max` covers memcg charges, not an exact RSS limit, and OOM attribution
  needs a fresh exclusive scope and unambiguous cause;
- pidfd identity does not establish descendant termination or cgroup emptiness;
- freezer or post-create migration does not remove first-instruction races;
- denying `open` and `socket` does not remove inherited FDs, capabilities,
  keyrings, ptrace, BPF, io_uring, exec, or other ambient authority;
- supervisor death requires an outer guardian that owns cleanup and refuses to
  publish an incomplete result.

The host kernel and exact mechanism versions are part of the supervisor TCB.
This protocol cannot serve as evidence against a compromised host kernel and is
not evidence for the eventual HyperTag Monitor boundary.

## Successor Gate

A v2 candidate must provide a fresh `RunId`, complete receipt binding,
append-only evidence, first-instruction accounting, sandbox-ready release,
nonblocking bounded drain through EOF, leader and scope cleanup, final counters,
quiescence, deterministic classification, guardian abort semantics, and atomic
publication. It must then survive a machine exploration and new hostile review.
