# Dynamic Residency F0 v5 Supervised Evaluation Protocol v2

## Status

This is a pre-normative successor candidate to the locally rejected supervisor
v1. Its local strict validator explores the finite classifier and its hostile
mutation campaign rejects the current weakening set. It defines an abstract
execution, evidence, cleanup, and classification contract. It does not select a
Linux implementation, execute the captured evaluator, close the taxonomy,
issue `ValidationContextDigest`, accept F0, complete G0, or support a security
claim.

The machine-readable candidate is
`dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.json`.

## Separation of Responsibilities

The protocol has three distinct roles:

```text
guardian
  owns RunId issuance, aggregate admission, execution-scope lifetime,
  supervisor-death cleanup, and atomic publication

transport supervisor
  handles fixed-format metadata, bounded opaque byte streams, live kernel
  object handles, quota arbitration, cleanup, and the evidence ledger

pinned bounded checker/evaluator
  interprets requester and result payloads under the supervised envelope
```

The transport supervisor does not parse the model, request JSON, linked model,
occurrence index, finite values, or result JSON. It hashes and seals bounded
opaque bytes and validates only a fixed-size frame header. Parsing, schema,
static checking, linking, occurrence construction, evaluation, result-body
construction, and result-payload validation execute inside charged scopes.

A transport-valid result remains a candidate result. Under F05-02-009, the
reference evaluator is an untrusted producer. Positive semantic credit requires
an independently pinned small checker and a proof or certificate accepted by
an externally owned policy. Normal exit and valid framing alone never prove the
payload's semantics.

## Run Identity and Ledger

The guardian issues one fresh non-reusable `RunId` and supervisor epoch. Every
descriptor, timer, live worker handle, execution-scope handle, counter snapshot,
frame, receipt, classification, and publication binds the complete tuple:

```text
RunId
supervisor epoch and guardian identity
request raw-byte digest and optional parsed request ID
validation-context candidate ID
producer and outcome-checker executable-closure IDs
operator-envelope and supervisor-policy IDs
support-matrix and taxonomy IDs
```

Trusted receipts form one append-only ledger. Each receipt adds issuer role,
strictly increasing sequence, previous-receipt digest, event kind, and event
payload. Missing evidence is not failure evidence, and evidence from another run
cannot be merged. The ledger is sealed before classification.

These bindings are construction identities until an external owner pins the
guardian, policy, executables, and acceptance role. A hash is not an attestation.

## Launch Boundary

Before any requester byte is interpreted, the guardian and supervisor establish
a fresh exclusive execution scope, aggregate admission lease, counter baseline,
all semantic and containment limits, exact FD manifest, output channel, timer,
and worker identity. Every child instruction is charged to that scope. A small
sterile launcher may run before sandbox-ready, but it cannot access requester
bytes.

Release requires an exact authority-closure readback. The strict single-task
profile has one worker task, no fork/clone/vfork/exec, no inherited path or
socket authority, empty capability and keyring state, `no_new_privs`,
non-dumpable state, and an architecture-specific syscall allowlist. A future
multi-task profile needs a separate refinement and cannot inherit this result.

No Linux mechanism is selected here. In particular, stop signals, freezer, or
post-create migration do not by themselves establish the launch property.

## Stream and Observation Semantics

Reads are incremental. `OPEN_PARTIAL` is ordinary progress, not a fault. One
complete frame becomes `CANDIDATE_AWAIT_EOF`; it is not valid until EOF proves
there is no second frame or trailing byte. The supervisor continuously drains a
nonblocking channel up to a fixed transport limit plus one detection byte.

Frame, leader wait status, quota arbitration, scope state, counter capture, and
fault observations are independent monotone coordinates. Their arrival order
does not classify the run. A protocol, identity, containment, or ambiguous
attribution fault is sticky and cannot be overwritten by a later quota event.

## Resource Roles

Every limit has exactly one classification role:

```text
semantic_budget
  named requester/operator ledger, ingress byte meter, total CPU contract,
  wall deadline, exact memory-charge contract, result-body construction meter
  -> may issue InconclusiveResource with an exact causal receipt

containment
  frame transport overflow, duplicate/trailing frame, FD/clone/exec/seccomp
  violation, core dump, scope escape
  -> InternalFailure

environment
  host OOM ambiguity, external signal, missing kernel observation,
  supervisor or guardian failure
  -> InternalFailure or guardian Abandoned; never Resource
```

`cpu.max`, `memory.max`, an OOM counter, or a signal name is not automatically a
semantic-budget receipt. Each Linux refinement must prove fresh-scope ownership,
linearization, counter interpretation, causal termination, and bounded overshoot.

## Quiescence Barrier

No terminal taxonomy result is computed until `Quiescent` holds:

```text
the leader is reaped, or a recorded no-worker admission path applies
the execution scope is empty and cannot acquire new tasks
all output writers are gone and stream EOF has been classified
quota/deadline arbitration is final
final counters are captured against the bound baseline
all identity and policy generations still match
cleanup succeeded and the evidence ledger is sealed
```

If cleanup cannot establish these facts, the run does not receive Success,
Reject, Unsupported, or Resource. A live supervisor records Internal only after
safe cleanup. If the supervisor dies, the outer guardian kills the fresh scope,
waits for emptiness, discards the uncommitted capsule, and records `Abandoned`
outside the five-way result taxonomy. A dead supervisor cannot attest its own
failure.

## Pure Classification

Classification is one deterministic pure function over the sealed quiescent
evidence. Event handlers never commit a result.

```text
binding/fault/scope/counter/attribution inconsistency        -> Internal
exact attributed semantic quota with no independent fault    -> Resource
clean EOF + normal exit + validated typed candidate receipt  -> candidate tag
all remaining quiescent states                               -> Internal
```

The positive candidate tags are exact Success, deterministic Reject, named
in-process Resource meter, and well-formed Support miss. Their receipt checker
and support checkpoint are pinned by the validation context. A worker-reported
tag without that checker remains Internal or an uncredited candidate.

An exact supervisor quota may explain an absent or truncated frame. It cannot
explain malformed, duplicate, trailing, cross-run, containment, or identity
evidence. A complete valid candidate frame followed by an attributed quota stop
is Resource because normal completion never occurred; the frame receives no
positive credit.

## Publication

Classification changes `decision=NONE` exactly once. The guardian publishes one
immutable terminal capsule by atomic create-and-seal under a fresh RunId. A
partial file, temp path, supervisor-local log, or unsealed result is not a
published result. Publication records the exact classification rule and sealed
ledger digest. Replaying or replacing any receipt invalidates the capsule.

## Machine Obligations

Before this candidate can become normative, a strict validator and hostile
mutations must establish:

- `Init`, `TypeOK`, reachable-state well-formedness, and monotone coordinates;
- no requester interpretation before charged sandbox-ready release;
- no decision before quiescence and no publication before decision;
- pairwise disjoint positive classification guards and total Internal fallback
  over quiescent evidence;
- frame/exit/quota observation-order commutativity;
- receipt freshness, append-only sequence, single-use, and cross-run isolation;
- protocol/containment fault precedence over Resource;
- leader reap, scope emptiness, writer closure, EOF, and final-counter safety;
- conditional liveness under explicit drain, timer, kill, reap, and kernel-report
  fairness assumptions;
- guardian abort safety and absence of a forged terminal result;
- refinement obligations for each selected Linux mechanism.

Machine exploration of this finite protocol can find contradictions in the
protocol. It cannot prove Linux implements the abstract operations, prove the
checker sound, create external ownership, or provide Domain isolation.

The local exploration covers 82,944 final evidence products, including 41,472
quiescent products, and three observation-order pairs. This count is regression
evidence for the exact v2 classifier only; it is not model completion.

## Open Decisions

- exact guardian and supervisor executable closure;
- exact race-free charged launch mechanism;
- cumulative CPU and exact memory-cause enforcement;
- fixed binary frame and receipt encodings;
- static evaluator/checker versus captured interpreter closure;
- independent result and proof-checker composition;
- durable atomic publication and crash recovery;
- kernel-version-specific Linux refinement proof.
