# F0 Candidate-4 G6 OOM isolation and bounded exact enumeration

Date: 2026-08-12

## Disposition

`candidate4-full-20260811T223707Z` is a durable, fail-closed
`GUARDIAN_INCOMPLETE_PUBLISHED` result.  It grants no G6, G7, F0, R11, K0,
G0, protection, performance, or deployment credit.  The failure happened while
capturing `child-bundle-producer`: the nested candidate reached the sealed
7.5-GiB `memory.max`, systemd reported `oom-kill`, and the then-installed
`OOMPolicy=kill` terminated the trusted supervisor as well.  The root guardian
removed the uncommitted staging tree, observed drain, and committed a distinct
non-positive record.

This is a control-plane resource-retention defect, not a new transition-system
counterexample.  The exact transition relation, exact state identity, ordered
evidence histories, declared commutation predicates, and claim registry remain
unchanged.

## Repair

The child and parent enumerators now retain canonical states plus fixed-width
CSR adjacency indexes.  They no longer retain a Python `(source, Edge)` object
pair for every transition.  Reachable-state dataclasses use slots, exact
projection returns the state itself instead of allocating one-element wrapper
tuples, transition expansion is no longer held in an unbounded cache, and every
remaining pure memoization cache has a positive finite bound.  Cache eviction
only causes recomputation of pure functions and therefore cannot change the
reachable graph.

Coaccessibility is still computed exactly.  The reverse graph is constructed as
fixed-width CSR arrays, and every stored target is an index into the canonical
exact-state tuple.  No probabilistic fingerprint, quotient, partial-order
reduction, disk approximation, or dropped edge is introduced.

The capture unit changes from `OOMPolicy=kill` to `OOMPolicy=continue` while
each candidate cgroup retains `memory.max`, zero swap, and
`memory.oom.group=1`.  Consequently a component-local OOM kills and drains the
untrusted component, allowing the trusted supervisor to publish its ordinary
root-owned incomplete lifecycle evidence.  An actual supervisor death still
invokes the separate guardian.  The capacity inequality and 2-GiB guardian/OS
reserve remain sealed; neither the VM nor the candidate allowance is enlarged.

## Integrated prevention

The canonical capture contract now makes component-local OOM isolation an
explicit policy predicate and binds it to the supervisor-guardian and capacity
invariants.  The hostile contract suite aligns the duplicated policy constants
and still rejects the flipped predicate through an independently derived check.
`test-capture-resource-policy.sh` binds the contract, systemd runner, component
cgroup OOM grouping, and capacity inequalities.  `test-model-memory-policy.py`
rejects returned unbounded caches, non-slot reachable states, projection wrapper
allocation, or loss of the compact graph representation.  Both are called by
the single current-state checker, avoiding a competing validation path.

The first post-repair reducer fixture then exposed three predecessor input
digests and the static semantic-registry digest still sealed into the reduction
policy.  Both reducer and fixture now bind the current eight-object input root
and current static-registry result.  The independent three-case
`test-reducer-current-input-binding.py` derives those values from the canonical
current-input record and live static validator and is also called by the single
current-state checker.  Future input changes therefore fail before install
unless capture and reduction policy move together.

## Performance boundary

The repair affects only offline finite-model validation.  It removes allocator
and hash-table overhead rather than adding enforcement to Linux scheduling or
Monitor dispatch.  No production hot path changes and no zero-overhead claim is
made.  Clean commit `a956de28...` is installed under manifest
`dc3a7b23...`; a fresh authority-disjoint G6 run is still required before G7
can start.
