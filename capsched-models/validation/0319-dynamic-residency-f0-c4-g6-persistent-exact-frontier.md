# 0319 — Dynamic Residency F0 Candidate-4 G6 Persistent Exact Frontier

## Scope

This validation binds the second G6 OOM observation to the persistent exact
frontier repair.  It does not inherit full-run credit from any predecessor and
does not reduce incomplete bytes.

## Reproduced evidence

- Run: `candidate4-full-20260812T134610Z`
- Root commit: `c10c7a5a1a58523f766484970173bb9391a1d68380289978543f6b796714e0fd`
- Capture manifest: `9b0e13f03e00d700368004b2e74d5906b6547ef9ea53bd012fc346fff19239b2`
- Failed component receipt: `25b4d256601c7a44144f0d9b05f1d9632b8922ac31ef5ec7b11e6e8290b81030`
- Terminal status: `RAW_CAPTURE_INCOMPLETE`
- Failed component: `child-bundle-producer`
- Component memory peak: 8,053,063,680 bytes
- Trusted supervisor survived and committed the incomplete lifecycle receipt
- Positive eligibility: false
- Reduction performed: false

## Successor checks

The current exact inputs have root SHA-256
`6b2f130d59be97c28f73cceebd13b6d7d4f0d23967b3c8c1b6787ff6e5e5351e`.
On Linux/Python 3.12 the fast component passes:

- child hostile regression: 275 cases;
- parent hostile regression: 715 cases;
- runner lifecycle regression: 44 cases;
- memory-policy regression: 19 cases; and
- static registry: pass, with unchanged semantic-registry SHA-256
  `be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789`.

The forced-collision memory tests demonstrate that equal hashes still invoke
full sequence/state equality.  Source-shape checks reject a return of either
predecessor `dict[...State, int]` frontier index.  Existing child and parent
hostile suites exercise prefix slicing, mutation rejection, deterministic
state fingerprints, and exact transition effects with persistent histories.

The current reducer and boundary fixture are rebound to the two successor
model hashes.  The independent current-input binding test must continue to
derive those hashes from the canonical current-input artifact and the live
static validator.

## Clean-install qualification

Clean reviewed commit
`1fccacab7a94248fba443adc6b2de746a3565701` was transferred as a digest-checked
Git bundle into VM-native root-owned storage and installed under artifact
manifest SHA-256
`bd86819aa15de7f40540c63ae7fbc2fd32777a2d799438ed22e06c32988aa911`.
The installed launcher SHA-256 is
`7d83e68f8781d5fc6c9051b8d65a94aeb909b88485ce7e500c3acc16edf6a6e6`.

Post-install checks pass: launcher basic 1, launcher hostile 10, snapshot
hostile 5, capture-resource 7, model-memory 19, current reducer binding 3,
immutable-toolchain reuse 1, supervisor smoke 5 components, guardian recovery
3, and reduction boundary 3.  The EROFS toolchain image remains read-only at
SHA-256 `b3ed1553c9b40a48a27ce8ad792a0add387f82f49afc0edec7563234f2e78cce`.

## Gate result

G1-G5 remain locally closed at EC0.  The exact persistent-frontier TCB is now
clean-installed and a fresh G6 retry is eligible.  This does not close G6:
G7 remains blocked by `NO_COMPLETE_G6_CAPTURE`, and the full child/parent
reachability and declared-commutation run remains
`NOT_RUN_FOR_FRONTIER_REPAIRED_INPUTS` until that new run completes.

No F0/R11/G0, Linux behavior, Monitor implementation, protection,
performance/cost, cluster, datacenter, or deployment claim is granted.
