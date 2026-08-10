# Dynamic Residency F0 v5 Checked Evaluation Trust Boundary

## Status

DL-F0-5 now has a source-derived checked-term-occurrence construction and an
atomic finite-evaluation request construction. This closes caller selection of
the evaluated term, root `Gamma`, origin `Delta`, static provenance, parameter
slot, and PRE/POST/EVENT presence domain for the local reference evaluator.

It does not close F0. The implementation is not yet hostile-input-ready because
captured implementation bytes are identified but not directly executed from the
snapshot, the whole-pipeline hard meter is incomplete, and no external worker
supervisor owns CPU, memory, wall-clock, process, file-descriptor, or result-frame
limits. `CoreSyntaxWF`, `InstanceWF`, F0 acceptance, G0, model support, and every
protection claim remain false.

The machine-readable disposition is
`dynamic-residency-f0-v5-checked-evaluation-trust-boundary-v1.json`.

## Source-Derived Root

Each executable root is materialized only after static checking and linking. A
checked occurrence binds:

```text
LinkedModel construction and exact path
owner, role, locator, component, and origin
term bytes and result sort
ClosedRoot or exact ActionParamRoot
Gamma and Delta
static provenance R
```

A digest alone is insufficient. The standalone occurrence parser can detect an
unchanged-ID mutation, but a hostile producer can change metadata and recompute
both occurrence and index IDs. The positive adapter therefore reparses the
canonical source model, reruns wire/static/link construction, rematerializes the
entire occurrence index, and requires byte-for-byte equality before evaluation.
The evaluator consumes the rematerialized object, not a caller-selected term or
metadata object.

## Complete Request

One canonical request binds the validation-context ID, exact source/linked/
occurrence byte digests, checked occurrence ID, finite profile, explicit
parameter/PRE/POST/EVENT presence wrappers and values, and requester resource
profile. Its ID is a domain-separated content identity, not authority.

Runtime environment, `Gamma`, `Delta`, provenance, and required views are
derived from the occurrence. Closed roots admit no parameter. Action roots
admit exactly one value of the checked parameter sort and exact slot. Present
state/event views equal the static provenance domain. The same one-shot resource
ledger is used from profile/input decode through carrier enumeration, Eval,
DynDeps, AccessTrace, InterpretationRefs, and MayDeps.

## Validation Context

The process captures one immutable context generation containing grammar,
meta-schema, Parts 00-02, static and evaluation rules, generated schemas and
manifest, and the runtime implementation-source manifest. Semantic source,
generated, and implementation files are double-read and byte-compared. Contracts
are built from captured bytes, cross-hashes must agree, and later request
execution cannot call path-based rule or schema loaders. One module/class graph
is pinned and checked at request entry.

The context still records:

```text
captured_implementation_executed_directly = false
whole_pipeline_resource_envelope_complete = false
external_process_supervisor_bound = false
```

Those are blockers, not optional hardening.

## Resource and Taxonomy Boundary

The requester profile and operator envelope are distinct:

```text
effective(c) = min(requested(c), operator(c))
```

Ingress bytes, parser limits, static term limits, branch-by-global-channel link
expansion, checked occurrence count, finite evaluation coordinates, and result
body bytes now have named operator ceilings. Link expansion is checked before
allocation in both producer and local cross verifier. The result preserves both
requested and effective profiles and binds validation context in a separate
result-construction ID.

The five result tags are not interchangeable. Only deterministic malformed or
ill-formed input is `REJECT`. Only an identified meter or supervisor quota is
`INCONCLUSIVE_RESOURCE`. Unsupported requires a well-formed checkpoint and an
explicit support-matrix miss. Generic exceptions, host memory/recursion failure,
module replacement, corrupt output, and unknown worker death are
`INTERNAL_FAILURE` and never evidence. `SUCCESS` will not be closed until bounded
serialization and normal supervised worker exit are both established.

## Open Obligations

- move capture and execution into a snapshot-loaded worker with no filesystem or
  network reads;
- add parent-owned CPU, RSS, wall-clock, process, fd, and result-frame controls;
- meter wire/schema work, all link/deep-copy/sort allocations, occurrence term
  copies, profile rows, and final serialization before allocation;
- add a versioned support matrix with a genuine end-to-end unsupported fixture;
- add checked relation/observer roots before claiming POST/EVENT executable
  source coverage;
- independently reimplement occurrence reconstruction and finite evaluation;
- prove finite evaluator refinement, dependency containment, trace projection,
  and one-sided stability rather than inferring them from tests;
- continue to transition semantics and `InstanceWF` only after this boundary is
  fail-closed.
