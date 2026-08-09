# Evidence Capsule v1

This directory contains the bootstrap Collector and structural Verifier for
ADR-0013. It establishes the input boundary required before a future validator
may issue positive evidence.

The required order is:

~~~text
capture exact producer bytes into a fresh directory
  -> bind them to a canonical core manifest and capsule id
  -> structurally verify only the captured files
  -> run a claim-specific validator over the capsule
  -> bind a separate approval decision to the capsule id
~~~

## Components

~~~text
capture-request.schema.json
  producer-to-Collector request contract

core-manifest.schema.json
  content-addressed captured-input manifest

validator-result.schema.json
  future claim-specific validator result envelope

decision.schema.json
  future approver decision envelope

evidence_capsule_v1.py
  fresh-directory Collector and structural Verifier

test_evidence_capsule_v1.sh
  positive, mutation, alias, path, Git-identity, and malformed-input fixtures
~~~

The core capsule contains captured "inputs/" and "raw/" objects. Derived
results and approval decisions are separate objects that reference the sealed
"capsule_id"; they do not mutate the captured-input core.

## Collect

~~~bash
capsched-models/validation/evidence-capsule-v1/evidence_capsule_v1.py collect \
  --request /absolute/path/request.json \
  --source-root /absolute/path/producer-output \
  --source-root-id run-identity \
  --output /absolute/path/new-capsule \
  --collector-id validator-owned-collector
~~~

Validator-owned optional limits are:

~~~text
--max-request-bytes  8388608
--max-objects        4096
--max-object-bytes   4294967296
--max-total-bytes    17179869184
~~~

The effective values are sealed in "core.capture_limits". A run should lower
them when its experiment contract has a smaller finite envelope.

The output path must not exist. The Collector:

- requires the output directory to be outside the producer source root;
- opens request and source path components without following symlinks;
- parses strict JSON, rejecting duplicate keys and non-finite numbers;
- validates an exact request shape and safe relative paths;
- rejects two declared source objects that alias the same device/inode;
- captures each object from one already-open file descriptor;
- checks source metadata before and after each copy;
- checks declared Git object format, commit, tree, parent list, and dirty state
  before and after capture through the already-open source-root descriptor;
- for a declared clean Git source, independently hashes the commit-tree blob
  bytes and records mode, blob id, size, and SHA-256 beside the captured object;
- captures its own implementation and the exact request;
- enforces request, object-count, per-object, and total-byte limits;
- rejects missing required objects and contract-digest substitution; and
- writes a content-addressed canonical core manifest only after capture.

A failure after output creation leaves "capture-failure.json" and no valid
core manifest. Such a directory is "Incomplete" and cannot be promoted by
appending files.

## Verify

~~~bash
capsched-models/validation/evidence-capsule-v1/evidence_capsule_v1.py verify \
  --capsule /absolute/path/capsule
~~~

The structural Verifier recomputes the capsule id and every object digest,
walks the capsule through directory descriptors without following aliases,
rejects missing, extra, non-regular, or symlinked objects, and checks that the
manifest is exactly bound to its captured request and Collector object.

## Bootstrap Test

~~~bash
PYTHONDONTWRITEBYTECODE=1 \
  capsched-models/validation/evidence-capsule-v1/test_evidence_capsule_v1.sh
~~~

"jq", Git, Python 3, and the Python "jsonschema" module are test dependencies.
The Collector itself uses only Python's standard library and Git when the
request declares a Git source identity.

## Assurance Boundary

This is minimal structural tooling, not a complete evidence system.

It does not implement a TLC, Linux build, QEMU/KUnit, fault-matrix,
performance, or source-drift Validator. It does not issue approval decisions,
migrate historical gates, provide EC2 independence or EC3 reproduction, make
same-account files physically immutable, attest the host, or provide an
append-only signed transparency store.

At EC1 the workstation kernel, filesystem, Python runtime, Git implementation,
SHA-256 implementation, Collector, and Validator account remain trusted.
Captured bytes and their hashes are authoritative; a dirty Git identity does
not claim that those bytes belong to the named commit tree.

The first intended claim-specific consumer is "ROOTSCHED-001".
