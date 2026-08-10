# Validation 0293: Dynamic Residency R6 Successor Hostile Rejection

Status: exact R6 v2 successor rejected; strict baseline fails; no freeze credit

Date: 2026-08-09

Work record: `N-191`

Requirement: `RESIDENCY-DYN-001`

## Exact Inputs

```text
human R6 review snapshot:
  fef2d146331e549ab052a57710fae207eba456b2c2d346092df3dc0155c89449
semantic overlay:
  468cd739f64a44b1887c6f40eebb6bf8f466542d498e72457254e8dbe753bda1
materialized R6 v2 contract:
  24887ac27772dc131b91a7f87ff57203ab71cf883ff2769fc0df40bb941fa62d
assurance v3:
  702b6cf2d69a1c61586ae298362d79fc794a8bf48ae57dd60f059a1185aa75f6
```

The materializer reproduces v2 bytes. Four independent hostile reviews all
return `FREEZE_NO`; Analysis 0203 normalizes 40 findings, 32 for the local R7
semantic IR and 8 for later system-completion models.

## Mechanical Result

After the reviewed proof-node rename exposed recursive-merge retention, both
the strict validator and the mutation runner exit 1 at the same baseline gate:

```text
R6 successor architecture candidate: FAIL:
  component ledger node absent from proof order:
  ENV_ENTRY_CODE_STATE_INTERFACE

R6 successor hostile mutations: FAIL:
  component ledger node absent from proof order:
  ENV_ENTRY_CODE_STATE_INTERFACE
```

This is truthful negative evidence. The earlier 89-mutant PASS applied to an
earlier draft and did not execute schema-derived dependency edges, state-machine
interleavings, or validator-gate mutants. It cannot be carried forward.

## Decision

The exact v2 digest, overlay, R6 human snapshot, and incomplete 16-scenario
witness are regression inputs only. R7 must replace the relevant semantics with
an executable preformal IR, then pass trace, representation, behavioral, and
validator meta-mutation gates before another fresh review.

```text
R6_v2_accepted = false
R6_witness_accepted = false
architecture_frozen = false
tla_authorized = false
model_supported = false
protection_evidenced = false
```
