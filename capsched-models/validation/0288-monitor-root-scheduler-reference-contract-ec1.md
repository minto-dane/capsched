# Validation 0288: Monitor Root Scheduler Reference Contract EC1

Status: Passed; `ROOTSCHED-001` may move from Open to Model-supported only

Date: 2026-08-09

Work record: N-175

## Scope

This validation checks the Monitor-owned root-scheduling reference contract in
Analysis 0187 and Formal 0147. It is the first claim-specific consumer of
Evidence Capsule v1.

The accepted claim is narrow:

```text
Under the modeled finite frame and explicit Monitor/hardware weak-fairness
assumptions, adversarial Linux cannot mint or extend root execution authority,
and admitted guaranteed Domains receive recurring Monitor activation
opportunities with reserved management/recovery service.
```

It does not accept a Monitor implementation, Linux behavior, wall-clock bound,
multi-CPU or residency refinement, protection, performance, cost, cluster, or
datacenter claim.

## Exact Model Identity

```text
model commit: 345efd04052d2d78c135914a7fd62ebbb3b0904f
model tree:   89131d49fe4e553801dc1e908a0748f7b4cb085d
model SHA-256:
  491d02fb75317fec31868c7a7e57a7f85512f10d7a1ba12eba8f48fab565a3b1

pipeline commit:  f6dac43
hardening commit: 69bea12
TLC jar SHA-256:
  936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
contract SHA-256:
  dfd6bdb95a3bab6d8b154d6caf11d560ac173f4112f5773e6c05cdec2c9fef63
```

The contract independently fixes all 12 configuration hashes, the exact run
set, expected outcome class, two safe state-space counts, tool identity,
resource limits, claim boundary, and 43 producer-declared objects.

## Evidence Capsule

Canonical run:

```text
run id:
  20260809T043801Z-rootsched-ec1
capsule id:
  d805b92acee2bca93a965e63925f7f48b8bf8d518043b0c55edf9ca3a3210abe
core-manifest SHA-256:
  f56fd009808708eec7254e4737c74f9ac6fccc0bbb910b5cca7726279683d164
capture-request SHA-256:
  eefb631230015125b3acaeb41548bc8bb56b28d615657eb8bd7333f0f4e5049e
collector SHA-256:
  73835e1b3a80f4116e08b36047ca129072eaebc9dd8d32ae624c3610657e9665
captured claim-validator SHA-256:
  1e29a5702defc480a431e2ba0aa745096dedc9acaa3c08a637c4ba0013b470f7
```

The producer package is itself a clean, initial Git commit:

```text
commit: 40fc1b47b3ca354faa4cde2337910f280229c09b
tree:   f7127e1da1f9c53ed27ffc9134f75764da80a16c
parents: []
dirty: false
```

The Collector captured 45 objects: 43 declared objects plus the exact request
and Collector implementation. The manifest expects 46 files including the
manifest itself. No optional object is missing.

Validator-owned limits sealed into the capsule are:

```text
request:      1 MiB
objects:      64
per object:   4 MiB
total bytes: 32 MiB
per TLC run: 120 seconds
TLC workers: 2
```

## Safe Results

Both producer execution and validator re-execution from the captured model,
configs, and TLC jar reproduced:

| Configuration | Exit | Generated | Distinct | Depth | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `SafeSteady` | 0 | 155817 | 1920 | 21 | all safety and four liveness properties pass |
| `SafeRevoke` | 0 | 853049 | 10400 | 21 | all safety and revoke-qualified liveness properties pass |

No fairness is assigned to Linux. Weak fairness is limited to Monitor reserved
dispatch, Monitor close/advance, and hardware lease progress.

## Negative Discrimination

Producer and validator runs independently reproduced every intended failure:

| Configuration | Exit | Detected failure |
| --- | ---: | --- |
| `WaitForLinuxHint` | 13 | temporal recurring-service failure |
| `SkipReserved` | 12 | `BoundedGuaranteedWait` |
| `StealReserved` | 12 | `ReservedSlotIntegrity` |
| `StaleEpoch` | 12 | `CurrentEpochOnly` |
| `LinuxExtend` | 12 | `LinuxCannotExtendRootLease` |
| `ExpiryStillRunning` | 12 | `NoRootBudgetOverrun` |
| `StopAfterExpiry` | 13 | temporal trusted-handoff failure |
| `RevokeManagement` | 12 | `ManagementAlwaysAdmitted` |
| `NoTimer` | 12 | `NoRootRunWithoutLease` |
| `LinuxMint` | 12 | `LinuxCannotMintRootAuthority` |

This includes the key distinction missing from the older timer-only model:
stopping an expired attacker and then stuttering forever is rejected.

## Claim-Specific Validation

The validator performed 13 successful checks:

```text
structural verification before validation
exact ROOTSCHED claim and contract scope
hard-coded independent contract oracle
exact 43-object declaration with no producer summary
model/config/tool/validator/collector identity
exact command manifest
declared environment binding
raw log and status recomputation
exact safe state-space counts and depths
ten negative discriminators
validator-side replay of all twelve TLC runs
structural verification after validation
```

Result and decision:

```text
validator-result SHA-256:
  99b63b6cf050b972ae1a218e2ff7adf4de9e66f490b56f83b5d55508f301ba87
decision SHA-256:
  3617a503b103a76e1e4a7b5e90905041f221c94d73b658ba2af901e24a261958
decision id:
  ROOTSCHED-001-EC1-decision-20260809T043801Z
allowed transition:
  ROOTSCHED-001.open_to_model_supported
```

Both objects validate against the Evidence Capsule v1 Draft 2020-12 schemas.
The hardened decision supersedes the earlier same-day diagnostic decision.

## Mutation Validation

The focused regression script checks two distinct boundaries:

1. A direct raw-log byte append is rejected by structural verification.
2. A same-account attacker may rewrite a raw status and recompute the
   structural manifest/capsule ID. Structural verification alone then passes,
   as expected at EC1, but the claim-specific validator rejects the semantic
   mismatch and skips all captured-code/tool re-execution.

Observed result:

```text
direct-mutation: rejected
resealed-semantic-mutation: rejected-without-reexecution
```

This validates why capsule structure is necessary but insufficient. Promotion
depends on the claim-specific oracle and the separate decision binding.

## Evidence Level and Residual Trust

This is EC1, not EC2 or EC3. The workstation kernel, filesystem, Java runtime,
Python runtime, Git, SHA-256 implementation, Collector account, validator
account, TLC implementation, TLA semantics, and model abstraction remain in
the trusted evidence base. The validator is a separate captured/recomputed
program and does not trust producer summaries, but it is not an independently
implemented oracle on an independent host.

The capsule currently resides under:

```text
build/evidence-capsules/monitor-root-scheduler/
  20260809T043801Z-rootsched-ec1/
```

The exact hashes make later copying or remote append-only publication
verifiable. This record alone is not a substitute for retaining the capsule.

## Decision

`ROOTSCHED-001` is now Model-supported. The production assurance claim remains
blocked by Monitor implementation and verification, architecture timer and
interrupt bounds, multi-CPU/refinement work, `RESIDENCY-001`, and final
cross-component composition.

The next compositional model is `RESIDENCY-001`: stable global Domain identity
with more global Domains than bounded per-CPU resident slots.

