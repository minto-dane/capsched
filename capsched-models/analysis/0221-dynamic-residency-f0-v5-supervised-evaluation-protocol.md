# Dynamic Residency F0 v5 Supervised Evaluation Protocol

## Status

This is a pre-normative architecture candidate for the external execution
boundary required by F05-00-009 and F05-02-007. It is not implemented, hostile
reviewed, frozen, or authorized. The machine-readable candidate is
`dynamic-residency-f0-v5-supervised-evaluation-protocol-v1.json`.

## Why a Wrapper Is Insufficient

A timeout process around the current evaluator cannot distinguish an identified
quota from a checker crash, cannot prove the worker was charged before it ran,
and cannot prevent a partial success frame from being consumed. The parent must
own worker identity, immutable inputs, quotas, framing, termination, and final
classification.

The protocol therefore has three independent coordinates:

```text
stage       = capture/context/request/support/worker/terminal
frame_state = none/complete/invalid
exit_state  = none/normal/attributed_resource/unknown
```

Frame receipt and exit observation may occur in either order. No terminal
Success exists until both are complete and mutually bound.

## Captured Inputs

The parent captures and seals:

- RuleBundleSnapshot and local ValidationContext construction;
- source, linked-model, checked-occurrence, and request bytes;
- requester profile, OperatorHardEnvelope, support matrix, and taxonomy version;
- worker executable artifact and implementation identity;
- result-frame format and supervisor policy.

All input descriptors are immutable and sealed against write, grow, shrink, and
future seal changes. The worker receives no path authority. After launch it has
no filesystem or network access and cannot load another module generation.

## Worker Binding

The worker is created directly in its dedicated cgroup or remains stopped until
membership and limits are verified. A PID integer is insufficient; the parent
uses a pidfd-bound worker identity and a dedicated cgroup identity with baseline
resource counters. CPU, wall time, memory/swap, process count, fd count, core
dump, and result bytes have parent-owned limits. No instruction executes before
that ownership is established.

## Result Framing

The result channel has one fixed-size header containing protocol magic/version,
request ID, validation-context ID, payload length, and payload digest. The
payload is bounded canonical ASCII JSON. A second frame, trailing bytes,
truncation, digest mismatch, unknown tag, oversized length, or close without a
complete frame is InternalFailure unless a separately identified supervisor
quota receipt explains termination.

Worker-reported Resource or Unsupported is not self-authenticating. Resource
requires a parent-verifiable meter/supervisor receipt. Unsupported requires the
versioned support-matrix receipt after the well-formed checkpoint. Reject
requires a deterministic validator receipt. Unknown signals, plain
`MemoryError`, assertion failure, and unexplained nonzero exit are Internal.

## Commit Rules

```text
Success = complete validated Success frame
          and matching request/context/executable identities
          and normal worker exit
          and no trailing bytes
          and no quota/identity/module drift

Reject = deterministic reject receipt and committed validated frame/path

Resource = named meter or parent supervisor receipt, worker killed/reaped when
           applicable, and exact worker/cgroup/quota identity

Unsupported = request well formed and versioned support matrix misses feature

Internal = every remaining failure
```

Terminal classification is single-assignment. A killed worker is reaped before
Resource commits. A Success frame followed by abnormal exit is Internal, never
Success. A normal exit with no complete frame is Internal. A quota event for a
different cgroup or stale baseline cannot classify this request.

## Open Review Questions

- exact Linux substrate: `clone3(CLONE_INTO_CGROUP)` versus a pre-created frozen
  worker scope;
- whether seccomp, Landlock, namespaces, or a dedicated tiny launcher provides
  the smallest no-path/no-network worker TCB;
- fixed result-frame maximum and emergency receipt channel;
- deterministic CPU-time attribution across worker threads;
- cgroup OOM counter and pidfd signal race closure;
- output pipe backpressure and parent death semantics;
- captured-Python execution versus a smaller compiled verifier;
- reproducible worker executable and dependency closure;
- whether any positive F0 proof checker may share this reference-evaluator
  supervisor or needs a smaller separate boundary.
