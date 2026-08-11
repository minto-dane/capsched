# Dynamic Residency F0 Candidate-4 Authority-Disjoint Capture Contract

## Status

The Candidate-4 full-run boundary now has a versioned, machine-readable
architecture contract. Its strict local contract validator and hostile mutation
corpus pass. The root capture supervisor, target-host authority probe, guardian,
fault fixtures, immutable EROFS toolchain, and authority-separated post-run
reducer now pass their bounded mechanism regressions. Gates
`C4CAP-G1-CONTRACT` through `C4CAP-G5-FAULTS` are locally closed at EC0.
At this contract record's publication point, the exact long Candidate-4
capture (`G6`) and reduction of those real finalized bytes (`G7`) had not run.
Validation 0316 records the later incomplete attempt; Analysis 0228 records its
counterexample repair. G6 and G7 remain required.

The machine-readable companion is
`f0-c4-authority-disjoint-capture-contract-v1.json`. Its canonical JSON digest
is:

```text
14ca4b5424f448462ff0868689f278f412ee43fe2d32d8372a8cacc78d4fd075
```

## Reasoning-First Construction Policy

ADR-0024 makes architecture synthesis, hostile contradiction search, and
minimality analysis the primary construction stages. The selected reasoning
profile is GPT-5.6 Sol at maximum effort. It has no approval, evidence,
promotion, or claim authority. Every conclusion that matters is materialized as
typed state, authority, invariant, failure, gate, or nonclaim data and is then
checked independently of natural-language confidence.

TLA+ is deliberately terminal, not foundational, for this stage. Translating an
unsettled trust boundary into TLA+ would make an incomplete abstraction precise
without making it sound. TLA+ becomes eligible only after G1 through G7,
external K0 review, and semantic freeze. The terminal translation must preserve
the frozen types, transitions, failure semantics, fairness assumptions, and
claim boundary; it may find counterexamples but may not invent or weaken the
architecture.

## Three Distinct Reasoning Passes

The architecture was constructed in three non-authoritative passes over one
candidate boundary:

1. Synthesis fixed the actors, exact input set, five-component execution plan,
   lifecycle states, raw observations, failure classes, finite resource policy,
   and maximum local claim.
2. Contradiction search treated candidate code, descendants, output, aggregate
   receipts, workspace, network, and wall clock as hostile. It tested the
   architecture against fork/session escape, attach races, supervisor death,
   UID reuse, writable aliases, output forgery, partial publication, and
   authorization laundering.
3. Minimality removed mechanisms that did not carry a required invariant. The
   retained trusted base is the Linux capture-host kernel, root guardian, small
   root supervisor and policy, cgroup v2/pidfd mechanisms, root-owned evidence
   filesystem, and canonical hash/JSON implementations. Root, kernel, firmware,
   physical-storage, and external-review compromise are explicit nonclaims.

These passes do not constitute independent review. They define a reproducible
object for later implementation and review.

## Contradictions Resolved in the Contract

The following tempting constructions are explicitly rejected:

- A process group or session cannot contain descendants because a candidate can
  fork, daemonize, and create a new session. Each leader must instead be born in
  its final nondelegated cgroup with `clone3(CLONE_INTO_CGROUP | CLONE_PIDFD)`;
  cleanup uses `cgroup.kill`, and completion requires `cgroup.events` to report
  `populated 0`.
- Fork-then-attach has an execution race. Attach-after-exec has no fallback
  status; absence of the required `clone3` features is a fail-closed platform
  rejection.
- Same-UID read-only modes do not prevent replacement or writable aliases. A
  locked, dedicated non-root UID, empty capabilities, private namespaces,
  read-only input mount, root-owned non-traversable evidence path, and
  descriptor-relative no-follow capture are all required.
- Candidate-generated component receipts cannot authenticate candidate
  execution. The root supervisor owns the pipes, pidfds, cgroups, deadlines,
  raw bytes, and lifecycle receipts. Candidate summaries remain untrusted data.
- A supervisor can die while descendants live. A root service-manager guardian
  owns the containing subtree, kills it on supervisor loss, and publishes only
  an incomplete disposition after drain.
- Leader exit, network silence, timeout return codes, and unchanged pre/post
  hashes are not drain, containment, deadline, or continuous-integrity proofs.
- Reopening the producer workspace during reduction destroys evidence closure.
  The reducer reads only root-finalized, content-bound bytes and cannot mutate
  the capture.
- File mode `0444` is not immutability against root or physical storage. The
  contract claims only candidate non-modifiability and atomic, fsynced,
  no-replace publication.
- A validator cannot grant external authority to its own result. The four
  bounded Candidate-4 claims are the maximum possible local disposition; seven
  refinement and acceptance claims remain open.

## Typed Authority Boundary

Eight roles are disjoint:

- `CANDIDATE_SOURCE` may produce the exact source objects but has no capture,
  evidence, reduction, or claim authority.
- `CAPTURE_INSTALLER` alone materializes the reviewed trusted capture tools and
  immutable toolchain image from a clean commit.
- `ROOT_GUARDIAN` owns supervisor-subtree death handling but cannot launch the
  candidate, write candidate raw streams, or decide claims; it may publish only
  its typed incomplete record and commit marker.
- `CAPTURE_SUPERVISOR` is the only candidate launch, input capture, raw evidence,
  and cgroup authority. It cannot decide claims.
- `CANDIDATE_COMPONENT` is an untrusted dedicated non-root UID with no snapshot,
  evidence, cgroup, launch, or claim authority.
- `REDUCTION_SUPERVISOR` alone creates the read-only reducer view and finalizes a
  separate reduction namespace without mutating raw capture bytes.
- `POST_RUN_REDUCER` reads finalized evidence under a distinct service identity.
  It cannot launch the candidate, rewrite raw evidence, or grant acceptance.
- `EXTERNAL_APPROVER` is outside the local capture system. Its future identity
  and signature root are not forged into this local contract.

The exact eight Candidate-4 objects are captured once before launch. The root
plan executes exactly five components, sequentially, with fixed argv,
environment, deadlines, output limits, and strict one-record result protocol.
The candidate may not add, remove, reorder, or parallelize them.

## Lifecycle and Fail-Closed Semantics

The contract separates three authority-owned machines: an 11-state/13-transition
raw-capture lifecycle, a 5-state/4-transition guardian-recovery lifecycle, and a
9-state/11-transition reduction lifecycle. The capture supervisor can publish
only `RAW_CAPTURE_COMPLETE` or `RAW_CAPTURE_INCOMPLETE`; the later reducer can
publish only a reduction disposition. No candidate process can remain live when
a UID is reused or a final raw disposition is published.

Raw capture is never positive-eligible. Only a later `COMPLETE_REDUCTION` over a
durably committed complete capture can derive the bounded local disposition.
Launch failure, nonzero exit, deadline, output limit, supervisor death, drain
failure, source instability, toolchain-identity failure, and finalization
failure are incomplete. Reducer rejection is a complete negative result.
Resource exhaustion is never positive.

Seventeen platform requirements, 30 invariants, 13 typed object classes, finite
per-component and total resource limits, nine pre-exec observation fields, and
19 lifecycle receipt fields make this boundary executable rather than
aspirational. Every missing platform primitive is fail-closed.

## Claim Boundary

A complete future capture may support only these four registered local claims:

```text
F0-C4-FAST-MUTATION-AND-STATIC-v1
F0-C4-REACH-CHILD-EXACT-FIXTURE-BOUNDED-v1
F0-C4-REACH-PARENT-EXACT-REPETITION-BOUNDED-v1
F0-C4-DECLARED-LOCAL-EFFECT-COMMUTATION-v1
```

It cannot close independence completeness, external authentication,
attack-context-key refinement, unbounded attack history, durable-store
linearization, parent/child independence refinement, or F0 local acceptance.
R11, K0/G0, Linux and Monitor refinement, protection, performance, cost,
multi-cluster, and deployment claims remain false or open.

## Implementation Order

The gate order is binding; live status is owned by `capsched-ai/state/state.json`:

1. From a clean reviewed commit, install the already regression-tested trusted
   tools into the dedicated VM and verify the installed artifact manifest.
2. Freeze the exact eight-object snapshot and launch the detached full capture
   only after G3 through G5 pass (`C4CAP-G6-CAPTURE`).
3. In a later session and identity, reduce only finalized bytes
   (`C4CAP-G7-REDUCTION`).

The mechanism tests do not substitute for the long exact campaign.

## Nonclaims

This implementation is not a full Candidate-4 result, an F0 result, an
externally reviewed R11 artifact, a K0/G0 decision, a semantic freeze, a TLA+
model, a Linux patch, a Monitor implementation, or datacenter protection
evidence. No production behavior changed.
