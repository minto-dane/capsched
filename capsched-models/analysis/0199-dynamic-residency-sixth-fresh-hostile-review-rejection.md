# Analysis 0199: Dynamic Residency Sixth Fresh Hostile Review Rejection

Status: exact candidate rejected; successor semantic architecture required

Date: 2026-08-09

Work record: `N-187`

Requirement: `RESIDENCY-DYN-001`

## Reviewed Candidate

Four independent read-only hostile-review passes inspected the exact object set:

```text
candidate_object_set_sha256:
  24bb1320d3f50a10195d18e899d7101d7f422ca6ed18c5bedfb088ff4bdc174f

architecture:
  dynamic-admission-recurring-residency-architecture-contract-v1.json

witness:
  dynamic-residency-preformal-two-lane-witness-v1.json
```

Validation 0291 remains an accurate statement about finite internal checks on
those exact bytes. It is not an architecture-acceptance result. All four fresh
passes returned `FREEZE_NO`, so this digest is rejected as a semantic-freeze
candidate and may not authorize TLA+ translation.

The reviewer identities and raw session transcripts are not authenticated
external evidence. The reviews are retained only as independent internal
counterexample discovery. They cannot satisfy the external assurance protocol.

## Canonical Findings

| ID | Severity | Defect | Required semantic response |
| --- | --- | --- | --- |
| `R6-AUTH-01` | blocker | The initial RunToken is prepared before the ActivationCommitReceipt to which its authority is said to bind | Separate a one-use `PreEntryPermit` from the post-entry `RunToken`; create the receipt and RunToken atomically at the protected entry gate |
| `R6-AUTH-02` | blocker | `ExecutionCellLease` and its complete authority vector recursively authenticate one another | Seal a lease core first, authenticate only that pinned projection, then seal the final lease without a self-dependent digest |
| `R6-ACT-01` | blocker | Machine and prose use incompatible `ActivationDecisionCell` keys, allowing retry or cancel to create a shadow winner | Key exactly one decision cell by the full `CurrentOpportunityID`; keep attempt identities inside that cell |
| `R6-ACT-02` | blocker | The high-level lifecycle lacks `PreparedInert`, so cancellation/crash prefixes do not have a total refinement mapping | Define one canonical activation lifecycle and a total high-to-low simulation relation for prepare, entry, stop, recovery, and settlement |
| `R6-DELEG-01` | blocker | `DelegationScope` is observable/replayable bearer authority without a grantee or proof-of-possession binding | Bind grantee key, audience/channel, attenuation chain, grant generation, mode, and holder proof, or use a protected nontransferable reference |
| `R6-ID-01` | blocker | Delimiter-concatenated identities can alias and symbolic `sha256:` strings are accepted as real digests | Use typed canonical serialization and exact digest computation; include all enclosing authority parents in opportunity and activation identities |
| `R6-BOUNDARY-01` | blocker | ENTRY/CODE/STATE/device receipts are largely nonempty strings, not security contracts | Define exact protected issuers, subjects, epochs, physical state, quiescence, DMA closure, install/entry atomicity, expiry, and autonomous-stop predicates |
| `R6-XFER-01` | blocker | Prose rejects every cross-epoch calendar transfer while machine/witness accept a clock-relation certificate | Select one deterministic cross-epoch rule and make prose, machine, witness, and bounds identical |
| `R6-XFER-02` | blocker | Quorum supersession can authorize placement but cannot construct the source receipt required by `CalendarTransferV1` | Normalize ordinary quiescence and quorum supersession into a typed calendar-boundary certificate with exact ordinal, debt, clock, and horizon semantics |
| `R6-FAIL-01` | blocker | Failure closure can miss a later publication through a scope discovered after the first high-water snapshot | Fence and drain publication per discovered scope, atomically index every dependency before executability, and iterate to a bounded closed fixed point |
| `R6-LIVE-01` | blocker | `StableWindow` assumes internal `Operational`, and generic fail-stop can discharge service after an internal failure | State only exogenous relies, prove operational preservation separately, and treat unexplained internal fail-stop as a violated guarantee |
| `R6-LIVE-02` | blocker | A due activation may expire despite valid guards, and fresh retries can repeat forever | Give valid due entry deterministic priority, enumerate exact expiry causes, and include an admission-charged bounded attempt rank |
| `R6-CALENDAR-01` | blocker | Two streams may own the same lane turn; serving one advances the lane and can lose the other | Make guaranteed calendar ownership collision-free at admission/renewal or define a bounded deterministic multi-release cell with conserved capacity |
| `R6-CONN-01` | high | `CONNECTED_ONLY` relies on a replayable boolean-like observation | Require protected, current, sequence/challenge-bound connectivity evidence tied to lease, placement, channel, clock epoch, interval, and expiry |
| `R6-SVC-01` | blocker | JSON defines an eight-cell protected-work frame while prose defines nine cells and two guaranteed-residency positions | Freeze one structured slot-ID frame, validate human/machine parity, and recompute admission, capacity, deadlines, and ranks |
| `R6-REFINE-01` | blocker | Lifecycle views, decision cells, use cells, and settlement cells lack one total abstraction relation | Define canonical state ownership, derived views, stuttering rules, and a total simulation map before formal decomposition |
| `R6-FORMAL-01` | blocker | The proof DAG omits the hardware/time root for dynamic admission and has no predecessor theorem for operational preservation | Add exact formula/action/provider dependencies and an acyclic `OperationalPreservation` predecessor before recurrence |
| `R6-ASSURE-01` | blocker | No real verifier, trust root, runtime/policy pin, signed campaign, or external evidence exists; the candidate digest does not bind the validator | Keep freeze false, define non-self-referential tool/policy manifests, then implement and externally pin the real campaign only after semantic repair |
| `R6-ASSURE-02` | blocker | `ReviewPayload`, finding catalog, limitations, dispositions, and final decision are underspecified or absent from exact schemas | Freeze exact schemas and cross-object relations for all trust objects and forbid vacuous `accept` payloads |
| `R6-ASSURE-03` | blocker | Witness signers need not prove extension from their exact persisted prior tree root, allowing an admitted-event fork to be hidden | Require each signature to bind the prior size/root/event digest and a verified consistency extension to the new root |
| `R6-ASSURE-04` | blocker | A matching semantic-validation receipt can represent failure, timeout, signal termination, truncation, or an incomplete check set | Bind success exit/result, exact required-check inventory, complete logs, no timeout/signal/truncation, tool/runtime identity, and candidate capsule |

All twenty-one findings block semantic freeze. Severity distinguishes immediate
authority defects from supporting evidence defects; it does not permit any
finding to be deferred past freeze.

## Cross-Finding Architecture Consequences

The successor cannot be produced by adding validator predicates around the
existing witness. It must change the object-construction graph and the temporal
contract:

```text
immutable authority cores
  -> normalized authority evidence
  -> one-use pre-entry permit
  -> protected entry linearization
  -> ActivationCommitReceipt + post-entry RunToken
  -> active-context execution and idempotent delivery settlement
```

The failure path must similarly become a protocol, rather than a set scan:

```text
per-scope publication gate
  -> drain pre-fence publishers
  -> high-water snapshot
  -> reverse-edge scan
  -> newly discovered scope fence
  -> bounded fixed-point closure or pre-reserved node fail-stop
```

Liveness must no longer use an internal mode bit as an environmental rely.
The successor proof order is:

```text
external rely admissibility
  -> authority and physical conservation
  -> operational preservation
  -> due-cell determinism and bounded recovery rank
  -> per-opportunity qualifying delivery
  -> recurring-service induction
```

## Decision

The exact `24bb...174f` candidate is preserved as a rejected review target.
Its internal validator and mutation results remain useful regression evidence,
but its architecture is not frozen and TLA+ translation remains unauthorized.

The next admissible candidate must:

1. disposition every `R6-*` finding in both human and machine-readable form;
2. add executable counterexamples for every repaired defect;
3. re-establish exact human/machine parity and immutable object pins;
4. pass strict type, mutation, and cross-object validation; and
5. receive fresh review over the successor digest.

External assurance is deliberately later. A real verifier must not turn an
unstable architecture into an apparently authoritative artifact.

## Claim Ceiling

```text
candidate_24bb_rejected = true
successor_architecture_defined = false
architecture_frozen = false
tla_authorized = false
tla_written = false
model_supported = false
protection_evidenced = false
performance_supported = false
cost_efficiency_supported = false
deployment_supported = false
```
