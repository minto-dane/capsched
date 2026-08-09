# Analysis 0186: Evidence Capsule Trust Boundary and Migration

Status: Accepted assurance contract; minimal structural tooling implemented;
claim-specific validation and historical revalidation remain open

Date: 2026-08-08

Work record: N-174

## Purpose

Translate ADR-0013 into a concrete, tool-independent evidence contract for
future models, builds, QEMU tests, fault matrices, and measurements.

## Threat Model

For positive gate acceptance, assume the Producer can accidentally or
maliciously provide:

```text
stale source
changed bytes after hashing
symlinks or path aliases
substituted config/tool/helper
partial output described as complete
duplicate or missing case rows
fabricated summaries
raw rows inconsistent with summaries
unknown warnings hidden by a permissive classifier
host placement observations from the wrong process or time
```

The research workstation, Git implementation, hash algorithm, kernel, and
Collector/Validator process are trusted at EC1. Later protection claims require
stronger provisioning and attestation assumptions.

## Evidence Capsule v1 Logical Layout

```text
capsule/
  core-manifest.json
  inputs/
    source/
    config/
    tools/
    images/
    environment/
  raw/
    stdout/
    stderr/
    serial/
    qmp/
    tests/
    measurements/
  derived/
    normalized/
    summaries/
  validator/
    contract.json
    result.json
    decision.json
  attestations/
```

Physical storage may deduplicate objects. The logical relative paths and core
manifest remain stable.

## Core Manifest Contract

Required top-level fields:

```text
schema_version
capsule_kind
created_at
collector_identity
collector_implementation_sha256
producer_identity
capture_source_root_id
capture_limits
target_claims
experiment_contract
source_identity
objects[]
declared_environment
completeness_rule
```

Each object row requires:

```text
path
role
media_type
size_bytes
sha256
producer_path_or_source
capture_method
required
```

For a captured object from a declared clean Git source, the row additionally
records commit-tree mode, blob object id, blob size, and SHA-256 of bytes read
independently through Git. A pre/post clean status observation alone is not a
source-byte binding.

`capsule_id` is computed from canonical core-manifest bytes after every required
object is captured and hashed. The stored manifest may carry the id in a
non-core envelope, or the id may be the enclosing object-store key. It must not
create a self-hash ambiguity.

## Capture State Machine

```text
Empty
  -> Capturing
  -> Captured
  -> Sealed
  -> Validating
  -> Valid | Invalid | Incomplete
```

Forbidden transitions:

```text
Empty -> Validating
Capturing -> Valid
Sealed -> Capturing
Validating -> Capturing
Invalid -> Valid without a new capsule id
Incomplete -> Valid by appending unmodeled rows
```

Required invariants:

```text
ValidateOnlyCapturedBytes
NoRequiredObjectMissingAtSeal
NoObjectDigestChangeAfterSeal
DecisionBindsExactCapsule
DerivedOutputNamesExactRawInputs
NoProducerSummaryAsOracle
NoPositiveDecisionFromIncompleteCapsule
```

## Validator Result Contract

`result.json` contains observations, not approval. It records:

```text
capsule_id
validator_id and implementation digest
contract_id and digest
checks[] with exact ids
raw objects consumed
derived objects produced
unknown classifications
failure and incompleteness reasons
```

`decision.json` is separate and contains:

```text
capsule_id
decision_id
evidence_level
allowed claim transitions
explicitly forbidden claim transitions
approver identity
superseded decision ids
```

This prevents a technically passing parser from silently expanding assurance
scope.

## Experiment-Specific Minimums

| Experiment | Required captured objects | Required recomputation |
| --- | --- | --- |
| TLA/TLC | module/config bytes, TLC/tool version, command, complete log, exit status, generated/distinct/depth counts | invariant/property set and expected safe/unsafe outcome from captured config |
| Linux build | commit/tree/blob ids, diff, config bytes, compiler/binutils, command, complete logs, produced objects/images | config identity, touched paths, diagnostics, object/symbol/layout properties |
| QEMU/KUnit | kernel/initramfs/config/QEMU/helper bytes, command, serial/QMP/raw case receipts, exit status | exact case set, pass/fail/skip/timeout, warning taxonomy, image and placement binding |
| Fault matrix | exact fault taxonomy and witness contract, raw per-case receipts | exact id set, no duplicates/substitution, expected counterexample/witness per fault |
| Performance | exact source/build/image, placement records, raw treatment/control rows, interruption/capacity state | cell identity, row count, quantiles, thresholds, aggregate decision |
| Source drift | base/current commit and blob ids, watch map, semantic anchor rules, raw diff | exact changed set and semantic-recheck classification |

## Historical Migration

Migration does not rewrite old validation notes. Create a migration ledger with
one row per decision family:

```text
decision id
source revision
input availability
raw evidence availability
producer/validator separation
capture-before-read status
exact taxonomy status
current classification
required revalidation level
replacement capsule id
```

Initial classification for the reviewed lineage:

```text
R4/R5/R6 exact Git source and model objects:
  retained_reproducible_input

positive source/build/KUnit/QEMU closure credit that may influence promotion:
  needs_revalidation

negative performance or semantic results:
  blocking_signal_pending_reproduction

historical status prose and AI state:
  retained_history_no_promotion_credit
```

This classification is deliberately conservative and does not assert that every
historical result is wrong.

## Rollout Order

1. Define JSON schemas for core manifest, result, and decision. Complete.
2. Implement a small Collector that creates fresh capsules and rejects unsafe
   paths before any validator reads inputs. Complete for v1 bootstrap.
3. Implement structural validation and mutation fixtures. Complete for v1
   bootstrap; see Validation 0287.
4. Migrate the next root-scheduler formal run first.
5. Migrate R6 source/build/E3 positive gates only if R6 remains a candidate
   after residency and composition modeling.
6. Add append-only/remote storage and signatures before production evidence.

Do not spend time migrating obsolete positive gates whose mechanisms have
already been rejected, unless their result is used by a successor decision.

## Current Decision

```text
EVIDENCE-001 status:
  contract_defined

minimal capture and structural verification:
  true

claim-specific validator and approver:
  false

historical positive promotion credit migrated:
  false

new positive gate permitted without capsule:
  false
```

The implementation is in "validation/evidence-capsule-v1/". Validation 0287
passes six positive and 32 fail-closed fixtures. This closes only the
capture-first structural layer. It does not discharge EVIDENCE-001 or grant
promotion authority to a producer self-check.

## Non-Claims

This analysis plus Validation 0287 now has a minimal capsule implementation and
bootstrap structural result. It is not a claim-specific validator, migration
completion, cryptographic attestation, independent reproduction, or approval
of any Linux, Monitor, R6, performance, protection, or deployment claim.
