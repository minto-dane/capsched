# ADR-0013: Validator-Owned Immutable Evidence Capsules

Status: Accepted

Date: 2026-08-08

## Context

DomainLease-Linux uses generated source gates, build matrices, QEMU/KUnit
tests, model checkers, independent closures, and performance experiments. The
volume of evidence is useful, but a positive result is not independent merely
because a second script reads a summary written by the first script.

Review of the current validation lineage identified recurring assurance risks:

```text
producer-authored pass/fail summaries used as validator inputs
hash-then-reopen races on mutable files
source/config checks performed before a later copy or build
count-only validation where exact case identity is required
derived performance summaries without retained raw sample pairs
warning classifiers that accept unenumerated diagnostic forms
host placement observations without supervisor-owned continuity
AI recovery records that are older than the Git lineage they describe
```

These are assurance-pipeline risks, not evidence that the scheduler mechanism
is exploitable. They matter because an unsound evidence pipeline can promote a
mechanism that does not satisfy its stated gate.

## Decision

All future positive promotion decisions use a validator-owned immutable
Evidence Capsule.

The ordering rule is:

```text
capture exact bytes
  -> seal and identify the capsule
  -> validate only captured bytes
  -> derive summaries from retained raw evidence
  -> issue a decision bound to the capsule id
```

The validator must not hash a producer path and later reopen that path for the
decision. It copies or otherwise snapshots every mutable input first and then
reads only the captured object.

## Role Split

```text
Producer:
  creates candidate source, build output, runtime output, or measurement rows

Collector:
  creates a fresh validator-owned capsule, captures bytes, records provenance,
  rejects aliases/symlinks/unsafe paths, and seals the input manifest

Validator:
  parses captured inputs, recomputes expected values and summaries, executes
  named checks, and emits a decision

Approver:
  maps a valid decision to an allowed assurance or implementation claim
```

One program may perform Collector and Validator roles for low-risk local work,
but Producer and positive Validator authority must remain distinct. A producer
self-check is diagnostic evidence, not promotion evidence.

## Capsule Identity

The capsule has a canonical core manifest whose byte representation is hashed:

```text
capsule_id = sha256(canonical_core_manifest_bytes)
```

The core manifest lists every captured object by relative path, size, media
type, role, and digest. The decision envelope references `capsule_id`; it is not
part of the self-hashed core.

Required transitive provenance:

```text
Git commit, tree, parent, and relevant blob ids
dirty/untracked state decision
patch or binary diff identity where relevant
configuration bytes
tool and helper bytes plus versions
complete command and declared environment
architecture and execution substrate
kernel image, initramfs, module, and firmware identities
QEMU/VM/container image identity
host CPU/cpuset/affinity facts required by the experiment
raw stdout/stderr/serial/QMP/test records
raw measurement rows
derived summaries
validator implementation identity
```

An unrecorded transitive input makes the positive gate incomplete.

## Evidence Levels

```text
EC0 producer self-check:
  useful diagnostics; no promotion authority

EC1 validator-owned capture and recomputation:
  minimum positive local gate

EC2 independent validator implementation or independently implemented oracle:
  required for security-critical source/correctness promotion

EC3 external reproduction on independently provisioned execution substrate:
  required where a production protection or cost claim depends on the result
```

Running the same parser twice is not EC2. Different run IDs are not independent
if both trust the same producer summary or mutable source path.

## Migration Rule

Existing evidence is not deleted. It is classified asymmetrically:

```text
positive promotion credit with incomplete capsule provenance:
  needs_revalidation

negative result or counterexample with incomplete capsule provenance:
  blocking_signal_pending_reproduction

exact Git source/model object:
  retained_reproducible_input

pure historical narrative:
  retained_history_no_promotion_credit
```

Questionable positive evidence cannot authorize progress. Questionable negative
evidence may safely stop promotion, but must be reproduced before permanently
rejecting an architecture.

For the reviewed R4/R5/R6 lineage through
`75e34749b94af52338085caced75c44c70f0a1b4`, exact Git objects and useful
counterexamples remain. Positive source/build/test promotion credit is
`needs_revalidation` before future Linux or assurance promotion. R6 E4
measurement is already paused by ADR-0012.

## Storage and Immutability

Read-only mode bits under the same mutable account are not a security boundary.
At the research stage, content addressing, fresh output creation, exact Git
objects, complete manifests, and independent recomputation provide the minimum
discipline. Production-grade evidence should additionally use an append-only or
remote object store, signatures, and a transparency/audit log.

Partial, timed-out, interrupted, or capacity-failed runs receive a sealed
failure capsule. Their rows cannot be resumed into a later positive capsule
unless the experiment contract explicitly defines resumable shards and the
validator proves exact non-overlap and completeness.

## Specialized Rules

### Metrics

Retain every raw treatment/control pair needed by the accepted statistic.
Recompute cell membership, sample count, quantiles, thresholds, and aggregate
decisions inside the validator. A CSV/JSON summary alone is insufficient.

### Warning and Sanitizer Classification

Use a fail-closed taxonomy. Unknown diagnostic forms are failures requiring
human classification and a versioned classifier update. Preserve raw logs.

### QEMU and CPU Placement

The launcher/supervisor owns the cpuset and process lifetime. Capture vCPU
identity and affinity before execution, at contract-defined continuity points,
and after execution. A single observation before `cont` does not prove
placement continuity.

### Fault and Case Matrices

Validate exact case/fault identifiers, semantics, expected outcome, and witness,
not only counts. Duplicate or substituted rows fail the gate.

### AI State

The current-state file is not validation evidence, but stale recovery state can
cause unsafe decisions. A freshness check must bind semantic project changes to
an updated compact state/handoff record at the same Git commit.

## Consequences

- New validators require a capture phase before parsing.
- Producer summaries become untrusted inputs or convenience views.
- Some historical positive gates need revalidation before promotion.
- Existing negative findings remain conservative blockers until reproduced.
- Raw evidence storage grows, so retention and content-addressed deduplication
  become engineering requirements.
- Evidence validity becomes separable from whether a particular scanning or CI
  plugin completes successfully.

## Non-Claims

This ADR does not prove any existing result false, validate any R6 mechanism,
select a storage product, provide cryptographic attestation, implement a remote
transparency service, or establish production protection.
