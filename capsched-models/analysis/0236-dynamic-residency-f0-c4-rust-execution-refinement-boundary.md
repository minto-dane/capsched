# 0236 — Candidate-4 Rust execution-refinement boundary

## Disposition

The tenth authority-disjoint G6 attempt,
`candidate4-full-20260814T130141Z`, durably finalized
`RAW_CAPTURE_INCOMPLETE`.  The behavioral audit-representation quotient was
active and materially reduced retained resources, but the child producer still
reached its sealed 43,200-second deadline before emitting a result.  G6 remains
open, G7 remains blocked, and none of the captured bytes are positive-eligible.

This run is not an OOM recurrence and not a semantic counterexample.  The
candidate used one PID, accumulated 43,198,293,123 CPU microseconds during
43,200,353,944,303 monotonic nanoseconds, peaked at 4,659,470,336 bytes rather
than its 8,053,063,680-byte limit, allocated 3,963,437,056 external-memory
bytes, and recorded zero `memory.max`, OOM, OOM-kill, or group-kill events.
Stdout and stderr were empty.  The trusted supervisor killed and drained the
component, observed `populated 0`, removed the loop-backed ext4 store, and
published an immutable incomplete commit.

## Root cause

The remaining limit is execution throughput in the CPython enumerator.  The
full child producer is one process and the observed CPU-to-wall ratio is
0.999952.  The bounded profile localizes most time below successor generation,
edge construction, and repeated whole-state well-formedness checks.  Additional
representation-only compression cannot make six VM CPUs available to that
single interpreter, and replaying the same bytes has no rational completion
argument.

## Refinement decision

Candidate-4 will retain the Python executable model as the readable normative
reference and add a Rust implementation as an accelerated refinement.  Rust is
not allowed to become an independent model, silently repair behavior, weaken a
predicate, or establish claim credit by itself.  A fresh G6 run is prohibited
until all of these gates pass:

1. the child and parent transition relations are unchanged;
2. exact state fields and the behavioral audit projection have typed,
   lossless encodings;
3. hash matches are always resolved by full equality;
4. bounded deterministic prefixes match Python state-for-state and
   transition-for-transition, including action identifiers and projected
   receipt multiplicities;
5. every hostile Python fixture has an equivalent Rust/differential outcome;
6. scheduling and frontier partitioning are deterministic across thread
   counts and repeated executions;
7. the Rust toolchain, source, binary, and build command are digest-bound and
   the binary is reproducible from two distinct root-owned build roots;
8. the reviewed accelerator is installed into the immutable capture
   toolchain and exercised through the existing authority-disjoint boundary.

The initial implementation should use fixed-width discriminants, packed state
columns, deterministic layer or batch partitioning, thread-local successor
buffers, and a canonical merge.  External memory remains available for the
exact state/index/graph store.  Parallel workers may accelerate pure offline
enumeration, but must not write raw capture evidence directly and must not
change the order-independent mathematical result.

## Minimality and production boundary

The Python reference remains because it is independently readable and already
owns the reviewed hostile corpus.  The differential gate remains because a
manual port can preserve types while changing semantics.  Collision equality,
deterministic merge, pinned builds, and authority-disjoint capture remain
because each closes a different false-positive path.

This work is entirely in the offline Candidate-4 validation path.  It changes
neither the Linux scheduler hot path nor the future Domain Monitor dispatch hot
path, and grants no performance, cost, protection, F0, R11, K0/G0, cluster, or
deployment claim.

## Bound evidence

- public observation:
  `f0-c4-g6-behavioral-quotient-timeout-observation-v1.json`, SHA-256
  `c53841cc27b0a62db7fa081e08bd5cf71f71ba85833485a209413056e86e69b2`;
- raw commit SHA-256:
  `23a3c1a64f082171cc0827c1296549a7f44fad4d65e1bfce506f0bac56d98eec`;
- capture manifest SHA-256:
  `91b0921a38da532e93e3f8cd9aa2b38d74cb6adb202a83cc19f40e716c16bd61`;
- failed component receipt SHA-256:
  `890700e7ecd80d8492e78ffddc37c258695c00fd55b3ff576c205abc9326ebe0`;
- fail-closed refinement readiness SHA-256:
  `41034db8cd6f0915cb1ea39285bd11e4395b197209568eeacb3436d6a201018e`.
