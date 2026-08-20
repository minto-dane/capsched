# Evidence Capsule v1 Bootstrap Structural Validation

Status: passed; minimal Collector/structural Verifier only

Date: 2026-08-08

## Purpose

Validate the bootstrap implementation of ADR-0013 before it is used to capture
the first ROOTSCHED-001 formal-model run.

This validation tests the evidence container. It is not itself an EC1
claim-promotion decision because the Collector cannot independently bootstrap
trust in its own initial implementation.

## Artifacts

~~~text
validation/evidence-capsule-v1/evidence_capsule_v1.py
validation/evidence-capsule-v1/capture-request.schema.json
validation/evidence-capsule-v1/core-manifest.schema.json
validation/evidence-capsule-v1/validator-result.schema.json
validation/evidence-capsule-v1/decision.schema.json
validation/evidence-capsule-v1/test_evidence_capsule_v1.sh
~~~

## Checks

The positive fixtures establish:

- capture of exact required bytes and explicit absent optional objects;
- recomputation of the canonical capsule id and all object hashes;
- generated core-manifest conformance to its JSON Schema;
- independence of captured bytes from later producer-path mutation;
- clean Git object-format/commit/tree/parent/dirty binding through an
  already-open directory FD;
  and
- exact request, Collector, object-row, and file-set cross-binding.

The 32 negative fixtures reject:

- duplicate JSON keys, non-finite JSON numbers, and invalid UTF-8;
- request bytes, object count, per-object bytes, and total captured bytes above
  validator-owned limits;
- terminal "." and ".." path components;
- mutation or deletion of captured objects;
- unlisted files and symlink objects inside a capsule;
- an altered manifest without a new capsule id;
- resealed request, Collector-digest, capture-limit, and expected-file
  substitutions;
- source hardlink aliases;
- source-file and source-parent symlinks;
- path traversal and duplicate capsule destinations;
- experiment-contract digest substitution;
- missing required producer objects;
- substituted Git parent identity;
- status-hidden working-tree bytes that differ from the declared clean Git
  blob;
- declared clean Git state after a tracked-file mutation;
- output nested inside the producer source root; and
- output-directory reuse.

## Commands And Result

~~~text
bash -n validation/evidence-capsule-v1/test_evidence_capsule_v1.sh
  pass

Python compile() of evidence_capsule_v1.py
  pass

jq parse of all four JSON Schemas
  pass

PYTHONDONTWRITEBYTECODE=1 \
  validation/evidence-capsule-v1/test_evidence_capsule_v1.sh
  PASS evidence-capsule-v1 positive=6 negative=32
~~~

## Corrections Made During Validation

The first draft reopened the Git source root by pathname and walked the capsule
through "/proc/self/fd" pathname traversal. Both were replaced with operations
rooted in already-open directory descriptors. Git identity is checked before
and after capture, and the FD is explicitly inherited only by the Git child.

The Verifier was also strengthened so a newly hashed but semantically
inconsistent core manifest cannot pass merely because its self-hash is valid.
It now binds the exact captured request, automatic Collector object,
experiment contract, requested object metadata, and derived complete file set.

Strict JSON parsing and terminal path-component rejection remove parser and
schema interpretation ambiguity.

## Remaining Gaps

- No claim-specific Validator consumes a capsule yet.
- No approval-decision implementation exists.
- Historical positive evidence remains "needs_revalidation".
- No EC2 independent implementation or EC3 external reproduction exists.
- Same-account mode bits are not an immutability boundary.
- There is no append-only object store, signature, transparency log, or host
  attestation.
- The tool assumes a trusted EC1 workstation kernel, filesystem, runtime, Git,
  hash implementation, Collector, and Validator account.

## Decision

The minimal capture-first structural layer is suitable for use as the
container for the next root-scheduler model and its raw validator output.

EVIDENCE-001 remains contract-defined rather than discharged. Positive
assurance promotion still requires a claim-specific validator, a result bound
to the capsule id, and the evidence level required by ADR-0013.

No Linux, Monitor, scheduler correctness, protection, performance, cost,
cluster, deployment, or production claim is authorized.
