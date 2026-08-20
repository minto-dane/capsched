# 0230 — Dynamic Residency F0 Candidate-4 G6 Persistent Exact Frontier

## Result

The resource-isolated G6 retry `candidate4-full-20260812T134610Z` did not
complete.  `child-bundle-producer` reached its sealed 7.5-GiB `memory.max`
after 1,086.809 seconds and was killed as one component cgroup.  Unlike the
predecessor attempt, `OOMPolicy=continue` kept the trusted supervisor alive;
it drained the cgroup and durably committed `RAW_CAPTURE_INCOMPLETE`.  No raw
candidate bytes are positive-eligible and G7 remains blocked.

This separates two facts that were previously conflated:

- component-OOM containment and fail-closed finalization are now effective;
- the predecessor exact graph representation still retained too much resident
  Python metadata to complete inside the component bound.

The immutable observation is
`validation/f0-c4-g6-second-oom-incomplete-observation-v1.json` at SHA-256
`2985c4ec870b156c075b9c8d3b273264067a17d3c376aacfa93990d76be6a76e`.

## Retention diagnosis

Fixed-width CSR removed per-edge `Edge` objects, but two large exact structures
remained:

1. every evidence append allocated a new tuple containing the entire ordered
   receipt prefix; and
2. Python `dict` retained a variable-width hash-table entry for every exact
   state in addition to the canonical state vector.

Neither structure was a semantic requirement.  The exact ordered receipt
sequence and full state equality are requirements; repeated pointer arrays and
general-purpose dictionary entries are representations.

## Repair

Child and parent receipt ledgers now use typed views over one shared immutable
persistent-sequence implementation, preventing two competing mechanisms from
drifting.  Each
append stores one receipt and its predecessor, and caches a structural Python
hash.  A hash match is never accepted as equality: the complete ordered chain
is compared receipt by receipt.  Prefix slicing returns an exact persistent
prefix, while non-prefix slices materialize only the bounded temporary tuple
needed by existing local checks.

Reachability now uses an open-addressed fixed-width exact-state index:

- one unsigned 64-bit cached Python hash per occupied slot;
- one unsigned 32-bit canonical-state index per occupied slot;
- a load factor below two thirds and deterministic power-of-two growth; and
- mandatory full `EnvelopeState` or `OrchestratorState` equality on every hash
  match.

Thus unequal hash collisions cannot merge states.  The canonical state vector,
fixed-width CSR edges, exact ordered-history identity, transition relation, and
reachable-state set are unchanged.  No quotient, digest-only identity, state
pruning, reduced hostile bound, or swap allowance was introduced.

## Performance and security boundary

This repair affects only offline Candidate-4 enumeration.  It adds no Linux
scheduler or Monitor dispatch hot-path work.  The custom index moves probing
from CPython's C dictionary implementation into Python, so some CPU-time
increase is possible; the 12-hour component deadline remains unchanged and
the memory reduction is preferred over weakening exactness or raising the
resident limit into the VM/guardian reserve.  The zero-swap policy also
remains sealed.

The 19-case memory-policy regression now covers persistent child and parent
histories, immutability, ordered-sequence preservation, forced hash collisions,
index resize correctness, fixed-width storage, CSR retention, finite caches,
and the absence of the predecessor full-state dictionary declarations.

## Disposition

The fast Linux regression passes child 275, parent 715, and runner 44 hostile
cases.  The static semantic-registry digest remains
`be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`;
the successor exact input root is
`6b2f130d59be97c28f73cceebd13b6d7d4f0d23967b3c8c1b6787ff6e5e5351e`.

These results authorize only a clean reviewed TCB reinstall and a fresh G6
attempt.  They do not complete G6 or G7, accept F0/R11/G0, prove a Linux or
Monitor refinement, or support protection, performance, cost, cluster, or
deployment claims.
