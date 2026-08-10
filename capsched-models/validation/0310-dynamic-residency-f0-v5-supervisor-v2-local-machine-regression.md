# Dynamic Residency F0 v5 Supervisor v2 Local Machine Regression

## Result

The pre-normative supervisor v2 passes its local strict shape validator, finite
classification exploration, required scenario checks, observation-order checks,
and hostile mutation campaign. This validates only the exact abstract candidate
and local checker contract.

```text
protocol product states:                   82,944
nonquiescent states with decision NONE:    41,472
quiescent states classified exactly once: 41,472
positive guard overlaps:                   0
transitions:                               21
receipt types:                             18
required adversarial scenarios:            16/16
observation-order pairs:                    3/3
hostile mutations:                         97/97 expected rejection
```

The quiescent outcome distribution is:

```text
Success                                      1
Reject                                       1
InconclusiveUnsupported                      1
InconclusiveResource                        32
InternalFailure                         41,437
```

The small positive surface is intentional. Binding mismatch, sticky fault,
ambiguous quota, invalid/trailing stream, abnormal wait, nonempty scope, missing
counters, unverified receipt, or inconsistent checkpoint falls to Internal.

## Exact Snapshot

```text
0223-dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.md
  992e9877b3a0f63025017041e95b82cd3d593510f07d11abacfa704d70b5583b

dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.json
  b92b3bb1794555366f5e89283a54fd33611dff742de095c14f861a360e90d695

validate-f0-supervisor-protocol-v2.py
  5d689ad5711f423d2c47136ed833f407a9c2ba0cdb8aed55bcca83ab093f9e9d

test-f0-supervisor-protocol-v2-mutations.py
  fd4ce236acb2c1140dc1bb8e3c462eee48aecc3cc753d3d2e4179b2e16625209
```

## Reproduction

```bash
python3 capsched-models/validation/validate-f0-supervisor-protocol-v2.py
python3 capsched-models/validation/test-f0-supervisor-protocol-v2-mutations.py
```

The validator uses strict ASCII JSON decoding, duplicate-key rejection, bounded
depth/nodes/collections/integer digits, exact predecessor and contract fields,
and full Cartesian classifier enumeration. It also reduces each paired event
order into one monotone evidence set and compares the final result.

## Mutation Boundary

The campaign rejects role/trust conflation, RunId and ledger weakening, EOF and
scope removal, observation overwrite, containment-to-Resource relabeling,
release before sandbox-ready, classification before quiescence, publication
before decision, missing guardian abort, weakened Success/Resource/Reject/
Unsupported guards, overlapping commits, scenario/oracle drift, Linux mechanism
self-selection, authorization flips, duplicate keys, unsafe scalar forms, and
parser resource inputs.

## Nonclaims

The 82,944-state exploration is not a proof that the operational LTS reaches
only well-formed products, that the Linux kernel refines an abstract receipt,
that cgroup/pidfd/seccomp mechanisms close their races, or that a checker is
sound. No supervisor or guardian executable exists. Captured implementation
bytes are still not the directly executed artifact. There is no external policy
owner, fresh v2 hostile-review disposition, issued `ValidationContextDigest`,
closed result taxonomy, F0 acceptance, G0, Linux behavior change, or protection
claim.
