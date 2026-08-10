# Dynamic Residency Epoch-2 Kernel v2 Hostile Rejection

## Scope

This validation records the pre-implementation rejection of the first
epoch-2 semantic-kernel contract. It is local negative design evidence, not an
external K0 decision.

## Exact Candidate

```text
semantic-kernel-contract-schema-v2.json
  f30bf42e28a527904d0663feec7e34dc3494c7708169d0f3741fa2d0b4ae13ad

semantic-kernel-contract-v2.json
  a70489bf816569f382268d69e23e147a0319b7c0370717cc1367f3b1834f8c8a
```

The schema and contract parse as strict JSON. Draft 2020-12 schema validation
passes. IDs are unique for all 8 contexts, 10 sort kinds, 38 operator entries,
7 structured obligations, and 21 reject classes.

## Review Result

Three read-only local reviews returned `LOCAL_ADVISORY_REJECT`:

```text
language/formal:
  no independent denotation; circular gates; unsafe phase/partiality;
  finite/general claim confusion; incomplete fairness, relational isolation,
  and translation preservation

assurance:
  circular trust root; schema-valid accept; missing high-water, canonical
  signature payload, exact assignment and real-runner semantics

scenario/composition:
  0/8 required interaction families represented as reachable typed execution;
  label-union coverage; missing hostile actors, process/container lifecycle,
  network protocol, generated durable cuts and re-crash
```

The reviews are advisory and carry no external authority. Their value is that
all three reject before implementation, avoiding investment in a larger but
still self-defining TCB.

## Disposition

```text
strict JSON/schema shape             PASS
operator-name inventory              PASS
mathematical denotation              FAIL/ABSENT
acyclic foundation/candidate gate    FAIL
phase-safe total semantics           FAIL/INCOMPLETE
scenario/composition executability   FAIL
external assurance root              ABSENT
reference interpreter                deliberately not built
K0/G0                                false
candidate IR                         unauthorized
semantic freeze                      false
TLA+                                 unauthorized
```

ADR-0018 and Analysis 0215 authorize only a new v3 denotational foundation.
The exact v2 files are retained unchanged. No model, Linux, Monitor,
protection, performance, cost, cluster, or deployment claim is authorized.
