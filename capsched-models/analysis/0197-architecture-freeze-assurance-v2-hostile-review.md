# Architecture Freeze Assurance v2 Hostile Review

Status: v2.1.2 protocol redesign and fixture hardening integrated; all findings
remain open; real implementation and fresh external review pending

Work record: `N-184`

## Evidence Boundary

This record combines two unauthenticated internal discovery passes. The latest
pass is identified locally as
`internal_subagent_notification_019fe7a8-4003-7f40-b775-fa9bb7a82955`.
The reviewer identity is not externally authenticated, its complete source
snapshot digests are not retained as reproducible external evidence, and the
review is not in the protocol transparency log.

It is useful finding-discovery input only. It is not an external review, a
campaign submission, freeze evidence, or TLA+ authorization. The source verdict
remains `FREEZE_NO`.

## Prior Findings

| ID | Severity | Finding | Candidate response | State |
| --- | --- | --- | --- | --- |
| `ASSURE-R4-01` | high | semantic validator path execution lacks immutable runtime and sandbox binding | real verifier consumes matching policy-pinned hermetic receipts and executes no candidate program | open; real receipt verifier absent |
| `ASSURE-R4-02` | high | equivocation can hide a rejecting sibling | 3-of-4 event-index admission, full event replay, authenticated four-key terminal map, absorbing rejection, and witnessed terminal checkpoint | open; real implementation absent |
| `ASSURE-R4-03` | medium | blind review is only an assertion | checkpoint all four commitments before any reveal | open; real implementation absent |
| `ASSURE-R4-04` | medium | predecessor metadata can be invented later | require checkpointed predecessor terminal heads and consistency proofs | open; real implementation absent |
| `ASSURE-R4-05` | medium | semantic execution resources and descendants were not bounded | real hermetic runners; fixture remains explicitly nonhermetic but bounded | open; real runner absent |
| `ASSURE-R4-06` | medium | local read-only CAS is not WORM | require checkpointed external retention attestation | open; real implementation absent |
| `ASSURE-R4-07` | medium | result omits complete provenance | require the complete trust, capsule, runner, review, terminal, and decision digest tuple | open; real output absent |
| `ASSURE-R4-08` | low | pre-formal freeze and TLA authorization were inconsistent | one exact-capsule real pre-formal grant may authorize only TLA start | open; real claim derivation absent |
| `ASSURE-R4-09` | low | fixture namespace drift | one exact fixture prefix and mechanics-profile digest | candidate fix implemented; fresh review pending |
| `ASSURE-R4-10` | medium | signed precedence boolean is not temporal evidence | require witnessed policy checkpoint and consistency proofs | open; real implementation absent |
| `ASSURE-R4-11` | medium | protocol ID grammar excluded existing finding IDs | separate protocol-object and uppercase finding-ID grammars | open; real verifier absent |

## Fresh Discovery Findings

| ID | Severity | Finding | Candidate response | State |
| --- | --- | --- | --- | --- |
| `ASSURE-R5-01` | blocker | reveal appeared to bind the terminal checkpoint that must later contain that reveal | reveal now binds only campaign, capsule, assignment, prior commitment checkpoint, preallocated map key, commitment opening, and review; terminal checkpoint follows; decision authorization then signs terminal digest | open; protocol redesigned, real implementation absent |
| `ASSURE-R5-02` | blocker | an append-only Merkle root alone cannot prove no hidden reject sibling or unique terminal assignment state | require 3-of-4 event-index admission, replay every event index into an exact four-key authenticated map, make rejection and conflicts absorbing, and fix witnesses at `N=4,t=3,f=1` | open; protocol redesigned, real implementation absent |
| `ASSURE-R5-03` | high | a one-line real guard hid obsolete reachable-if-unguarded real success code | fixture verifier has no real branch or real grants; separate real CLI rejects unconditionally before evidence parsing | candidate fix implemented; fresh review pending |
| `ASSURE-R5-04` | high | dynamic architecture witness interpreter accepts malformed states | recorded and forwarded to the dynamic-model owner; this assurance-scoped change does not edit that validator | open cross-component dependency |
| `ASSURE-R5-05` | high | semantic receipt and complete result provenance are not yet machine-verifiable | claims remain false and real stub remains fail-closed | open; real implementation absent |
| `ASSURE-R5-06` | medium | fixture process-group limits are not a hermetic sandbox | fixture profile now states this explicitly and is forbidden as real evidence | open boundary; real runner absent |
| `ASSURE-R5-07` | medium | valid fixture accept and reject produced the same output | output now contains `campaign_decision`, `evidence_valid`, `freeze_authorized=false`, mechanics-profile digest, and `tla_authorized=false` | candidate fix implemented; fresh review pending |
| `ASSURE-R5-08` | medium | dynamic validator can parse and hash different file reads | recorded and forwarded to the dynamic-validator owner; not changed in this scoped patch | open cross-component dependency |
| `ASSURE-R5-09` | medium | mutation tests accepted any nonzero failure and dead paths could mask controls | each assurance fixture mutation now requires its intended stable error class and reason marker; fixture real dead code is removed | assurance candidate fix implemented; dynamic dependency remains |

## Noncyclic Redesign

The corrected signing order is:

```text
ReviewCommitment
  -> witnessed CommitmentCheckpoint
  -> SignedReviewReveal(commitment checkpoint, terminal map key)
  -> full event replay and CampaignTerminalMap
  -> witnessed TerminalCheckpoint(all reveals, map root)
  -> DecisionAuthorization(terminal checkpoint digest)
```

`SignedReviewReveal` explicitly forbids `terminal_checkpoint_digest` and every
future-checkpoint field. Exact schemas and transcript vectors are in the
machine protocol and are recomputed by the fixture suite.

## Completeness And Quorum

The terminal map is not accepted from four selected objects alone. Every valid
commitment or reveal needs a 3-of-4 `CampaignSubmissionAdmission` binding its
event index and state transition. A future real verifier must consume every
campaign event at every index before the terminal tree size, recompute the
event root, and replay all events. Duplicate, conflicting, extra, rejecting,
and incomplete submissions become absorbing rejection states.

Checkpoint witnesses are fixed to:

```text
N=4, t=3, f=1
minimum quorum intersection = 2t-N = 2 > f
```

An admission quorum and a terminal quorum intersect in two witnesses, so under
`f=1` at least one honest terminal signer knows every admitted event and refuses
an omitting head. This only establishes the intended non-equivocation argument
under the stated Byzantine bound and honest-witness admission/replay rule. It
does not prove witness independence or prevent threshold collusion.

## Fixture And Real Separation

`validate-architecture-freeze-assurance-v2.py` is fixture-only. It contains no
`verify-real` command, `REAL_ACCEPT_GRANTS`, real key class, or real success
return. Valid fixture accept and reject chains remain evidence-valid mechanics,
but both state:

```text
architecture_frozen=false
freeze_authorized=false
tla_authorized=false
```

`verify-architecture-freeze-assurance-v2-real.py` has no evidence parser and
unconditionally returns status 78 with `AFV2_REAL_UNIMPLEMENTED`. Any future
real implementation is a new security-sensitive artifact requiring its own
review; it must not be obtained by enabling fixture code.

The fixture mutation harness now checks a stable rejection class and a reason
marker for every mutation, not merely a nonzero status. The fixture runner is
still a bounded host process and is not a hermetic security boundary.

## Decision

The protocol architecture is more precise, and the fixture boundary is
structurally safer, but no finding is closed by this internal review.
`protocol_implemented`, `real_mode_assurance_implemented`,
`real_mode_assurance_validated`, `architecture_frozen`, and `tla_authorized`
remain false. Real assurance, architecture freeze, and TLA+ authorization remain
blocked on a separate implementation and a fresh externally authenticated
campaign.
