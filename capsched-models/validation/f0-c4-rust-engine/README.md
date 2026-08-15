# Candidate-4 Rust refinement engine

This directory contains the accelerated implementation-refinement work for the
Candidate-4 executable model.  `f0_supervisor_lts_v3.py` remains the normative,
readable executable specification.  Rust receives no model or claim authority
and cannot make G6 eligible by itself.

The first implementation slice now contains the complete child transition
relation, including setup, hostile activity, stream framing, arbitration,
cleanup, evidence sealing, and local decision.  This is still an implementation
refinement, not a replacement specification.  `python_oracle.py` serializes the
Python behavioral graph with a typed, length-framed, hash-independent encoding.
The exact-prefix and trace tests require byte-for-byte equality of states,
actions, actors, and successor edges.

The exact differential reaches 1,000 expanded representatives, 6,410 retained
states, and 12,212 edges for each role.  A separate all-action witness corpus
checks every one of the 56 declared child actions, including the late cleanup,
seal, and decision chain, with two deterministic Rust runs per trace.  The
wider 10,000-source diagnostic matches Python at 52,764 retained states and
118,552 edges per role, including exact action multiplicities.  It is compact
diagnostic evidence and does not substitute for exhaustive equality.

`src/model/wf.rs` independently implements the normative grant, receipt,
ordered evidence-chain, recovery, decision, and complete `InstanceWF`
predicates.  It contains no Python invocation or generated truth table.  The
WF-prefix differential checks the initial state and every one of 12,212
successor candidates per role through 1,000 BFS sources (12,213 checks per
role).  The all-action trace emitter also applies the independent predicates to
every intermediate and outgoing state, including the terminal cleanup and
decision paths.  Focused Rust mutations reject forged grant/receipt, duplicate
receipt, phase rollback, receipt-free candidate/winner, and premature release
states.  This closes only the independent-predicate implementation subgate;
the full 295-case hostile parity gate remains open.

The first named hostile-fixture slice transports the complete exact grant or
child state—including chronological receipts, recovery, seal, and decision
objects—through a strict length-framed decoder.  Python and Rust independently
agree on grant, evidence, and InstanceWF results for 59 mapped case credits;
236 original case credits, especially edge/effect rejection, commutation, and
representation checks, remain open.  Eleven malformed transport fixtures fail
closed.  Input bytes, case count, atom sizes, nesting, and tuple cardinalities
are bounded; the fixture-only atom lifetime does not alter the compact BFS
state representation.

Receipt histories use immutable shared nodes.  The wider index stores only a
SHA-256 bucket head and collision links; every digest match is resolved by
rebuilding and comparing the complete canonical behavioral bytes.  A forced
same-digest regression requires distinct states to remain distinct.  On the
current six-core validation VM, the 10,000-source Rust diagnostic used about
107 MB peak RSS versus about 105 MB for the compact Python oracle; the earlier
naive Rust representation used about 1.27 GB and is rejected.

`test_build_reproducibility.py` copies only the locked crate inputs into two
distinct private source roots, builds both offline with fixed build
environment values, requires byte-identical stripped release binaries, and
rejects temporary-root leakage.  Tool executable hashes are reported but do
not become capture authority until a reviewed toolchain image is resealed.

The crate intentionally has no third-party dependencies.  Its eventual full
engine must retain full collision equality, deterministic output across worker
counts, pinned and reproducible builds, the complete hostile-fixture corpus,
the parent/orchestrator relation, exhaustive child graph and commutation
analysis, bounded external-memory behavior, result integration, and the current
authority-disjoint capture boundary.  Until those gates and a clean immutable
installation are closed, G6 retry stays disabled.
