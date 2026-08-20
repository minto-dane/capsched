# 0235 — Candidate-4 behavioral audit-representation quotient

## Decision

The ninth authority-disjoint G6 attempt,
`candidate4-full-20260813T223812Z`, reached the exact 43,200-second producer
deadline after 43,191,793,050 microseconds of CPU.  It did not OOM:
`oom=0`, `oom_kill=0`, and the component-local 7.5-GiB peak remained isolated.
Its private ext4 backing allocated 13,816,688,640 bytes and was fully removed.
The capture supervisor drained the cgroup and durably committed
`RAW_CAPTURE_INCOMPLETE`.  The failure is therefore state-representation
explosion, not a memory-spill, guardian, or semantic failure.

The child reachability graph now uses a behavioral quotient that removes only
audit-chain representation from state identity.  It retains:

- every non-audit operational field;
- every evidence-receipt semantic fact and its multiplicity, including kind,
  payload, issuer, channel, run, scope, and subject bindings;
- decision, recovery phase, recovery reason, controller, fence, and issuer
  semantics; and
- all hostile-attempt, authority, protection, recovery, winner, resource,
  counter, and local-decision state.

It erases evidence-receipt order, sequence positions, previous hashes and
authentication tags, the sealed evidence root, representation-only winner and
fault receipt pointers, decision root/tag, and recovery prefix/tag.  Recovery
receipt ordering and sequence remain conservatively retained.  Hash matches
never establish equivalence: the compact store resolves every match using full
projected equality, including receipt multiplicity.

## Rejected weaker projection

A diagnostic projection that retained operational fields but omitted the
evidence-receipt semantic multiset merged incompatible authority histories.
Within 10,000 expanded sources it produced 68 conflicts, including
`TERMINATION_REQUESTED` issued by `PRIMARY_SUPERVISOR` versus
`RECOVERY_GUARDIAN`.  That projection is rejected.  Receipt semantics and
issuer multiplicity are mandatory even though they cost additional states.

Increasing the deadline alone is also rejected.  It preserves factorial audit
permutations and merely spends more CPU.  Removing receipts wholesale is
rejected because it hides precisely the authority and failure distinctions the
model exists to analyze.

## Assurance boundary

The deterministic exact prefix expands 2,000 states, discovers 20,510 exact
states and 24,920 edges, and checks all 669 encountered representation-equivalent
expanded states for identical action/projected-successor signatures.  Separate
boundary tests prove that receipt payload, issuer-bearing facts, multiplicity,
operational state, recovery semantics, and decision semantics cannot be erased.
Forced projection-hash collisions are resolved by full equality.

This is local bounded evidence, not an unbounded proof that the abstract
receipt multiset refines the ordered authenticated implementation ledger.
`AUDIT-REP-001` and claim
`F0-C4-AUDIT-CHAIN-REPRESENTATION-REFINEMENT-v1` remain open.  Exact ordered
reachability remains callable for bounded regression, but is not capacity-safe
for the full fixture.  No external acceptance, protection, Linux refinement,
performance, cost, deployment, or model-completion authority is created.

## Performance boundary

The change is confined to the offline Python enumerator and its evidence
reducer.  It adds no Linux scheduler or Monitor hot-path operation.  A 50,000
source diagnostic retained 219,696 quotient states at approximately 157 MiB
resident memory and completed in 157.4 seconds.  RAM and direct-I/O ext4-spill
enumeration produce identical exact and quotient prefixes.
