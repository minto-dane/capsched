# Analysis 0201: Architecture Freeze External Assurance Protocol v3

Status: semantic protocol candidate; real verifier, campaign, and freeze absent

Date: 2026-08-09

Work record: `N-189`

Requirements: `RESIDENCY-DYN-001`, `EVIDENCE-001`

## Purpose

Protocol v3 replaces the incomplete v2.1.2 assurance semantics identified by
Analysis 0199. It does not rehabilitate the rejected `24bb...174f` candidate
and does not freeze the R6 successor. Its purpose is to define exactly what a
later externally authenticated freeze decision must consume and prove.

The protocol separates four identities that must never collapse:

```text
candidate identity:
  exact retained architecture/witness/object bytes

semantic-tool identity:
  the validator/check catalog and measured runtime used to evaluate them

assurance-tool identity:
  the externally pinned verifier that validates the campaign

decision identity:
  the terminal log head, aggregate result, and authorization signatures
```

The candidate does not pin the verifier by embedding a self-hash. An external
policy checkpoint pins tool and runtime manifests. A measured launcher verifies
those bytes before execution from an immutable captured image. The final
decision binds candidate, policy, tools, runtimes, receipts, log head, reviews,
and retention evidence as one tuple.

## Canonicalization And Schemas

Every signed/hashable payload uses strict exact-key JSON under a policy-pinned
canonicalization profile:

```text
NFC UTF-8 strings
integers only; no floating point
RFC 8785 JCS serialization
sorted unique bounded arrays wherever order has no semantic meaning
discriminated unions; no ambiguous null-or-object fields
domain-separated hashes
unknown, duplicate, missing, extra, malformed, or oversized fields reject
```

No object contains its own digest. The machine contract defines exact schemas
for every trust object and nested security-relevant value. A schema name without
an exact key set and cross-object relations is not a schema.

## Externally Pinned Roots

The real verifier receives these as command-line or measured-launch inputs,
never by repository discovery or trust on first use:

```text
TrustRoot digest
CampaignPolicy digest
policy TransparencyCheckpoint digest
assurance verifier ToolManifest digest
assurance RuntimeProfile digest
terminal TransparencyCheckpoint digest
```

The policy binds principal registry, schema bundle, semantic validator tool,
assurance tool, runtimes, sandboxes, required checks, required findings,
review roles, runner/witness/decision thresholds, resource bounds, retention,
predecessor depth, and allowed claim transition.

The candidate may retain validator source for review and reproducibility. Those
bytes grant no execution authority. The launcher measures the policy-pinned
tool image and runtime from outside that image, avoiding an impossible
self-referential source constant.

## Complete Trust Chain

The machine contract defines exact schemas for:

```text
root and policy:
  TrustRoot, Principal, PrincipalRegistry, SchemaBundle, ToolManifest,
  RuntimeProfile, RequiredCheckCatalog, RequiredFindingCatalog, CampaignPolicy

append-only evidence:
  WitnessPersistentState, WitnessPersistenceReceipt, ConsistencyProof,
  InclusionProof, TransparencyCheckpoint

candidate retention:
  ArtifactEntry, CandidateManifest, CandidateCapsule,
  PredecessorPublicationProof, RetentionAttestation, CandidateSeal

semantic execution:
  SemanticCheckResult, SemanticValidationReceipt

review:
  ReviewAssignment, ReviewRoster, Finding, FindingDisposition, Limitation,
  CoverageAnswer, ReviewPayload, ReviewCommitment, SignedReviewReveal

campaign log and decision:
  CampaignEvent, AdmissionVote, CampaignSubmissionAdmission,
  CommitmentCheckpoint, CampaignEventReplay, CampaignTerminalMapEntry,
  CampaignTerminalMap, TerminalCheckpoint, AggregateDecision,
  DecisionAuthorization, FreezeRecord, SignedEnvelope
```

Every nested type has an exact key set, bounded cardinality, enum grammar, and
parent relation. Digest-only placeholders cannot substitute for omitted review
or evidence content.

## Fork-Resistant Witness Persistence

Each checkpoint witness persists the exact campaign head:

```text
campaign and policy checkpoint
witness identity, incarnation, key epoch, and state sequence
event tree size and root
last event digest
highest admitted event reference
assignment-state root
checkpoint heads and closed bit
anti-rollback counter and previous state reference
```

For every event, the proposed `AdmissionVote` binds:

```text
exact prior witness-state digest
prior tree size, root, and last-event digest
event digest and index
exact successor witness-state digest
successor tree size, root, and last-event digest
consistency proof
durable WitnessPersistenceReceipt
```

An honest witness verifies extension from its own persisted exact prior state,
durably commits the successor plus an external persistence anchor, and only then
signs. Signing before persistence is invalid. On restart, missing, rolled-back,
or inconsistent state permanently quarantines that witness key for the
campaign; key rotation cannot resume the old campaign.

With four witnesses, threshold three, and at most one Byzantine witness, two
conflicting quorums intersect in at least two witnesses and therefore at least
one honest persisted state. That witness cannot sign both branches. The same
extension rule applies to commitment and terminal checkpoints. This conclusion
still relies on durable honest state, uncompromised cryptography, and the stated
fault threshold; threshold collusion defeats it.

## Semantic Validation Success

A `SemanticValidationReceipt` is successful only when all are true:

```text
signature, runner identity, key epoch, candidate, policy, and pin tuple valid
loaded semantic tool and runtime/sandbox measurements equal policy manifests
normal process-group exit with exit code zero
result status exactly pass
no signal, timeout, resource-limit termination, prohibited I/O, or live child
stdout, stderr, and result are complete and untruncated within policy bounds
required check catalog equals executed check catalog exactly
every mandatory SemanticCheckResult is present once and says pass
input manifest and candidate capsule match exactly
```

Two policy-pinned independent runner authorities must produce matching success
projections. Matching failures are failures. A timeout, signal, truncated log,
partial check inventory, or `accept` string can never become a successful
receipt.

## Review Payload And Finding Closure

Each role receives a policy-pinned assignment, scope, checklist, required
finding catalog, and terminal-map key before commitment. `ReviewPayload`
contains the reviewed manifest, semantic receipt set, complete required-finding
dispositions, all newly discovered findings, limitations, coverage answers,
claims/nonclaims assessed, and evidence references.

A role review derives `accept` only when:

```text
assignment, role, candidate, policy, and manifests match
semantic success receipt quorum is valid
every mandatory coverage question is answered with evidence
every required prior finding has exactly one disposition
every new finding is included in the reviewer catalog
no disposition or limitation remains decision-blocking
no claimed scope was omitted
the declared verdict equals the derived verdict
```

`{schema, finding_catalog_digest, verdict: accept}` is therefore insufficient.
Finding IDs are assignment-scoped canonical identities; differing content under
one ID is equivocation. The aggregate retains every reviewer finding rather
than using semantic deduplication as an acceptance shortcut.

## Commit, Reveal, And Terminal Closure

The policy fixes four roles: security, formal/refinement, scalability/liveness,
and integration/evidence. All four commitment events must reach a fork-resistant
commitment checkpoint before any reveal. Each reveal opens the exact commitment
and is signed by the same assignment key.

Every admitted event is replayed into an absorbing four-key terminal map:

```text
UNSET -> COMMITTED -> ACCEPTED or REJECTED
missing at close -> REJECTED_INCOMPLETE
duplicate/conflicting/extra -> REJECTED_CONFLICT
every rejection state is absorbing
```

Terminal acceptance requires exactly one commitment and one accepted reveal
for each roster key, no conflict, complete replay through the terminal head,
successful semantic receipts, valid retention and candidate seals, and no open
aggregate blocker. Any admitted rejection or omitted admitted event forces
rejection. Decision authorities sign the recomputed aggregate and exact
terminal checkpoint; they cannot override it.

## Candidate Seal And Retention

`CandidateManifest` records every artifact path, role, media type, raw-byte
digest, and size. Candidate capsule identity covers the manifest, object-set
digest, contract, witness, source identity, predecessor, and policy checkpoint.
The author and an independent custodian each seal the same retained capsule.

Retention attestation binds immutable storage principal, object-version IDs,
lock mode, sequence, external checkpoint, and policy retention interval. A Git
commit or mutable repository URL is useful provenance but not immutable
retention by itself.

## Freeze Record Meaning

`FreezeRecord` is derived only after full-chain validation. It may set:

```text
architecture_frozen_pre_formal = true
tla_authorized = true
```

It must still set:

```text
tla_written = false
model_checked = false
tla_proved = false
protection_evidenced = false
```

Architecture freeze authorizes faithful formal translation; it does not prove
the model or implementation. A later formal counterexample reopens the
architecture and requires a new capsule and campaign.

## Bounds

Campaign policy fixes positive finite maxima for artifacts, artifact bytes,
capsule bytes, schema nodes, events, findings, review bytes, checks, log bytes,
predecessor links, signatures, and execution resources. Exceeding a bound
rejects or leaves the campaign incomplete. Sampling, truncation, carry-forward
review credit, and unbounded retry are forbidden.

Verifier cost is bounded by:

```text
O(capsule bytes + schema nodes + events + findings + checks + signatures)
```

The four-entry terminal map is constant-size. Each witness keeps one
constant-size current head plus externally retained append history. These are
structural bounds, not latency, cost-efficiency, or availability evidence.

## Required Counterexamples

The future v3 verifier and fixtures must reject at the named semantic gate:

```text
repository-discovered or candidate-supplied trust root
modified verifier or runtime with locally regenerated pins
missing schema for any trust object or nested value
unknown or extra exact-key field
matching timeout, signal, truncation, failed, or incomplete-check receipts
vacuous accept ReviewPayload
omitted, open, or conflicting finding disposition
blocking limitation with accept verdict
reveal bound to the wrong commitment/checkpoint/assignment
witness signing before persistence
witness rollback or same-index fork
terminal checkpoint omitting an admitted rejection
predecessor publication fork
candidate bytes changed after seal
retention object unlocked or version replaced
decision authority attempting to override recomputed reject
every policy-bound overflow
fixture result used as real freeze evidence
```

Mutations must fail for the intended semantic reason, not only a later generic
hash mismatch.

## Current Decision

Protocol v3 is a semantic design candidate. The real verifier, measured
launcher, durable witness service, external identities, retention service,
signed reviews, terminal checkpoint, and authorization do not exist. It closes
no R6 finding until its exact machine schema is validated and independently
reviewed.

```text
protocol_v3_semantics_written = true
real_verifier_implemented = false
external_campaign_started = false
architecture_frozen = false
tla_authorized = false
model_supported = false
protection_evidenced = false
```
