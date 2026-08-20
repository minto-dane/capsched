# Analysis 0194: Architecture Freeze External Assurance Protocol v2

Status: v2.1.2 noncyclic terminal-map architecture selected; fixture verifier
implemented; real verifier and externally attested campaign pending; no
architecture freeze claim

Date: 2026-08-09

Work record: N-181

Requirement: `RESIDENCY-DYN-001`

Machine record:
`analysis/architecture-freeze-external-assurance-protocol-v2.json`

## Purpose And Claim Ceiling

Repository-local names, hashes, reviews, and decisions cannot establish review
identity, publication order, completeness, retention, or non-equivocation. An
author who controls the worktree can fabricate those records. Protocol v2.1.2
therefore treats repository bytes only as candidate content. Real assurance
requires externally pinned keys, externally witnessed checkpoints, immutable
storage attestation, hermetic validation receipts, and independently signed
human decisions.

Cryptography proves possession of authorized keys and exact byte binding. It
does not prove that identity metadata is truthful, that a human review is
competent, or that authorized principals did not collude.

No real verifier is implemented. The fixture verifier can validate only local
byte, schema, signature, and deterministic aggregation mechanics. It can never
authorize freeze or TLA+ work.

## Noncyclic State Order

The only potentially accepting real order is:

```text
externally pinned TrustRoot
  -> threshold-signed CampaignPolicy
  -> 3-of-4 witnessed policy checkpoint
  -> retained CandidateCapsule and checkpointed predecessor chain
  -> RetentionAttestation and CandidateSeal
  -> matching 2-of-3 hermetic SemanticValidationReceipts
  -> signed four-role ReviewRoster
  -> one ReviewCommitment for each assignment
  -> 3-of-4 witnessed commitment checkpoint containing four commitments
     and zero reveals
  -> one SignedReviewReveal for each assignment
  -> replay every campaign event into the authenticated terminal map
  -> 3-of-4 witnessed terminal checkpoint containing every reveal
  -> deterministic AggregateDecision
  -> 2-of-3 DecisionAuthorization signing the terminal checkpoint digest
  -> derived exact-capsule pre-formal FreezeRecord
```

The reveal does not and cannot bind a future terminal checkpoint. It signs the
exact campaign, capsule, assignment, already existing commitment checkpoint,
preallocated terminal-map key, commitment, canonical review bytes, and nonce.
The later terminal checkpoint includes the reveal. The later still
`DecisionAuthorization` signs that terminal checkpoint. This three-stage order
removes the former self-reference.

Candidate artifacts remain `architecture_frozen = false`. A future, fully
validated real campaign may derive a separate record with
`architecture_frozen_pre_formal = true` and `tla_authorized = true` for one
exact capsule. It must still say `tla_written = false`,
`model_checked = false`, and `tla_proved = false`.

## Canonical Bytes And Transcripts

Real objects use strict UTF-8 NFC and the integer-only interoperable subset of
RFC 8785 JCS. Duplicate or unknown keys, floats, noncanonical numbers, path
traversal, symlinks, special files, unsorted keyed sets, algorithm
substitution, and oversized inputs are rejected. Artifact hashes cover raw
bytes.

Protocol object IDs use lowercase identifiers. Finding IDs use a separate
uppercase hyphenated grammar.

```text
Digest = "sha256:" + 64 lowercase hexadecimal characters
KeyID  = "ed25519:" + SHA256(raw 32-byte public key)

LD(x) = u64be(length(x)) || x

SignedMessage(payloadType, payload) =
  "LINUX-CAP-ARCHFREEZE-V2\0"
  || LD(UTF8(payloadType))
  || LD(JCS(payload))

TerminalMapKey(campaign, assignment) =
  SHA256(
    "LINUX-CAP-ARCHFREEZE-V2/terminal-map-key\0"
    || LD(UTF8(campaign))
    || LD(UTF8(assignment)))

ReviewCommitmentValue =
  SHA256(
    "LINUX-CAP-ARCHFREEZE-V2/review-commitment\0"
    || LD(UTF8(campaign))
    || LD(ASCII(capsuleDigest))
    || LD(UTF8(assignment))
    || LD(ASCII(terminalMapKey))
    || LD(JCS(reviewPayload))
    || LD(raw32ByteNonce))
```

The machine record contains exact key inventories for `SignedEnvelope`,
`ReviewCommitment`, `SignedReviewReveal`, `CommitmentCheckpoint`, terminal-map
entries, `CampaignTerminalMap`, `TerminalCheckpoint`, and
`DecisionAuthorization`. Unknown keys are forbidden.

## Reveal Schema

The signed reveal payload has exactly these keys:

```text
assignment_id
campaign_id
capsule_digest
commitment_checkpoint_digest
commitment_digest
nonce_b64
review_payload_b64
schema
terminal_map_key
```

`terminal_checkpoint_digest` and every other future-checkpoint field are
forbidden. The opening must reproduce the prior commitment value, use the same
reviewer assignment key, and name the exact commitment checkpoint in which all
four commitments and zero reveals were witnessed.

## Checkpoint Witness Quorum

Checkpoint witnesses use fixed parameters:

```text
N = 4 policy-pinned independent witnesses
t = 3 signatures required for every accepted checkpoint
f = 1 maximum Byzantine witness in the safety claim

minimum intersection of two t-quorums = 2t - N = 2
required condition                   = 2t - N > f
instantiation                        = 2 > 1
```

An honest witness signs at most one checkpoint for a campaign checkpoint kind
and sequence, and only after deterministic replay of every campaign event.
The non-equivocation claim is conditional on at most one Byzantine witness and
unbroken hash and signature assumptions. Metadata alone does not establish
that condition.

## Event Log And Authenticated Terminal Map

A Merkle root by itself cannot prove that no rejecting sibling was omitted.
Protocol v2.1.2 therefore requires both a campaign-specific append-only event
log and a deterministic four-key terminal map.

Reviewer signature alone does not make an object a valid campaign submission.
Each commitment and reveal also needs a `CampaignSubmissionAdmission` signed by
three of four checkpoint witnesses after append. It binds the object digest,
assignment, exact event index, post-append tree size, and prior and post
assignment-state digests, and the post-append event-log root. An honest witness
tracks its highest admitted event index and refuses a terminal checkpoint that
does not extend it.

Any admission quorum and terminal quorum intersect in at least two witnesses.
With at most one Byzantine witness, at least one honest witness belongs to the
intersection. Therefore a valid terminal checkpoint cannot omit an admitted
reject sibling under the stated assumptions. A raw reviewer-signed object with
no 3-of-4 admission is not a protocol submission.

The verifier receives every event at index `0` through
`terminalTreeSize - 1`, recomputes the event root, verifies the commitment
checkpoint prefix, and replays every event. The assignment universe is exactly
the four checkpointed roster assignments. Unknown assignments are invalid.

Each terminal-map key is derived from campaign and assignment IDs. Its state
machine is:

```text
UNSET + first valid commitment        -> COMMITTED
COMMITTED + matching ACCEPT reveal    -> ACCEPTED
COMMITTED + matching REJECT reveal    -> REJECTED
incomplete assignment at close        -> REJECTED_INCOMPLETE
duplicate/conflicting/extra submission -> REJECTED_CONFLICT
ACCEPTED + later pre-close submission -> REJECTED_CONFLICT
any rejected state                     -> same rejected state forever
submission after CLOSED                -> invalid campaign object
```

Acceptance requires exactly four unique roster keys, each `ACCEPTED`, each
with one commitment and one reveal, no conflict, and an accept verdict. Any
missing key, duplicate, sibling, conflict, rejection, or count other than one
forces aggregate rejection. Thus an admitted pre-close hidden sibling must
appear in every valid terminal extension, enters full replay, and becomes
rejection. A purported post-close sibling is not a valid object for the closed
campaign.

The terminal-map leaves are sorted by map key:

```text
leaf(entry) = SHA256(0x00 || u64be(length(JCS(entry))) || JCS(entry))
node(L, R)  = SHA256(0x01 || raw32(L) || raw32(R))
root        = node(node(leaf0, leaf1), node(leaf2, leaf3))
```

Campaign-event Merkle leaves use a separate domain:

```text
eventLeaf(i, event) =
  SHA256(0x02 || u64be(i) || u64be(length(JCS(event))) || JCS(event))
eventNode(L, R) = SHA256(0x03 || raw32(L) || raw32(R))
emptyEventRoot  = SHA256(0x04)
```

For more than one leaf, the tree recursively splits at the largest power of
two strictly smaller than the leaf count. Event indices are contiguous,
zero-based, and equal their leaf positions.

The terminal checkpoint binds the event root, full-replay digest, map root,
exact assignment-set digest, commitment checkpoint, policy checkpoint, capsule,
tree size, entry count four, and closed state. Exactly three of four checkpoint
witnesses sign it.

## Decision Authorization

`DecisionAuthorization` is after terminal finalization. Its exact payload binds:

```text
campaign and capsule
policy digest
terminal checkpoint digest
terminal map root
aggregate decision digest and decision
exact claims granted and denied
```

Exactly two of three independent decision authorities sign it. It cannot
select an accept reveal while ignoring a rejected terminal-map entry because
the aggregate is recomputed from the map committed by the signed terminal
checkpoint.

## Candidate Storage And History

The candidate manifest contains sorted safe relative paths, raw digest, size,
media type, and role. Each artifact is opened without following links, read
once through its descriptor, and rechecked. Local read-only mode bits are not
WORM or durable publication evidence.

`RetentionAttestation` comes from an external immutable-storage authority and
is checkpointed. It binds the capsule, manifest, object set, store incarnation,
immutable versions, lock mode, attestation sequence, and minimum retention
horizon.

A predecessor digest alone is only a present-time content commitment. It is
publication history only when every predecessor is bound to its prior terminal
checkpoint with inclusion and consistency proofs. The real chain is bounded
to 64 links.

## Semantic Validation

The future real verifier must not execute repository or candidate supplied
programs. A policy checkpoint predating the candidate fixes either a measured
static native image in a no-network sandbox or a deterministic WebAssembly
component in a pinned runtime. The exact retained capsule is the only input.

Real mode requires matching deterministic receipts from two of three
independently administered hermetic runners. Receipts bind runner identity and
measurement, all trust and capsule digests, runtime and sandbox digests,
resource limits, exit status, result/stdout/stderr digests and sizes, executed
check inventory, and per-run nonce. This receipt protocol is specified but not
implemented.

## Machine Test Vectors

The machine protocol carries executable vectors for:

```text
N=4, t=3, f=1 quorum intersection
TerminalMapKey derivation
ReviewCommitmentValue opening
campaign-event leaf and empty-tree hashes
SignedReviewReveal JCS and signature-message digests
four-leaf authenticated terminal-map root
```

The fixture suite independently recomputes every vector. These vectors test
encoding agreement only; they are not real campaign evidence.

## Fixture And Real Stub

The fixture verifier is fixture-only. It has no `verify-real` branch, no real
accept grants, and no reachable or unreachable real-success implementation.
Its result distinguishes a mechanically valid accept chain from a mechanically
valid rejection chain:

```json
{"architecture_frozen":false,"campaign_decision":"accept","evidence_class":"fixture","evidence_valid":true,"freeze_authorized":false,"mechanics_profile_digest":"sha256:07fab4a40996788aa7cf225a679ba02f1bd4aff7ded287febc6212c7aee32a3f","tla_authorized":false}
```

The rejection form changes only `campaign_decision` to `reject`. Neither form
authorizes freeze or TLA+.

The separate real CLI
`validation/verify-architecture-freeze-assurance-v2-real.py` has no argument
parser and reads no evidence. It unconditionally exits `78` with stable code
`AFV2_REAL_UNIMPLEMENTED`. A future real verifier must replace that file as a
new, separately reviewed implementation.

Fixture mutations assert both nonzero rejection and the intended stable error
class and reason marker. The fixture process sandbox remains a bounded host
process, not a hermetic security boundary.

## Residual Trust And Decision

Residual risks include checkpoint-witness threshold compromise, reviewer,
runner, or decision threshold collusion, stolen keys, dishonest identity
metadata, superficial review, false retention attestation, measured-runtime
compromise, host hardware or firmware outside the runner boundary, trust-root
compromise, and SHA-256 or Ed25519 failure.

No current artifact satisfies real mode. `protocol_implemented`,
`real_verifier_implemented`, `architecture_frozen`, `tla_authorized`, and
`protection_evidenced` remain false. Architecture freeze and TLA+ remain
blocked until a real implementation and a fresh externally authenticated
campaign validate one immutable capsule.
