# Dynamic Residency F0 Candidate-4 Authority-Disjoint Capture Contract

## Result

The version-1 architecture contract passes strict local validation. All 153
hostile contract mutations and 13 independently derived semantic checks pass:

```text
F0_C4_AUTHORITY_CAPTURE_CONTRACT_PASS
sha256=14ca4b5424f448462ff0868689f278f412ee43fe2d32d8372a8cacc78d4fd075
platform_requirements=17
invariants=30
gates=7

F0_C4_AUTHORITY_CAPTURE_CONTRACT_MUTATIONS_PASS hostile_cases=153 derived_cases=13
```

This is EC0 contract-shape and semantic-anchor evidence. It completes local
implementation gates G1 and G2 only. It is not capture evidence.

## Commands

```sh
python3 -m py_compile \
  capsched-models/validation/validate-f0-c4-authority-disjoint-capture-contract.py \
  capsched-models/validation/test-f0-c4-authority-disjoint-capture-contract.py
python3 capsched-models/validation/validate-f0-c4-authority-disjoint-capture-contract.py
python3 capsched-models/validation/test-f0-c4-authority-disjoint-capture-contract.py
```

## Validator Coverage

The strict validator rejects duplicate JSON keys, non-finite numbers, unknown or
missing fields, Boolean-as-integer substitution, altered role authority,
expanded claims, removed open claims, fail-open platform requirements, modified
input or component plans, relaxed result protocols, altered containment and
drain semantics, incomplete receipts, unsafe finalization, state-machine
bypasses, positive failure classes, unbounded resources, missing invariants,
self-completed implementation gates, forged authorization, and weakened
nonclaims.

It also mechanically checks:

- exact GPT-5.6 Sol maximum-effort reasoning profile with no approval authority
  and terminal-only TLA+ use;
- exactly four supportable local claims and seven claims that must remain open;
- exact eight-role separation, 13 typed object classes, and zero candidate
  evidence/cgroup/claim authority;
- all 17 fail-closed Linux platform requirements;
- the exact eight-object snapshot and sequential five-component root plan;
- pre-exec `clone3` placement, pidfd lifecycle, nondelegated cgroup v2,
  `cgroup.kill`, and `populated 0` drain;
- root-owned pipe capture, nine pre-exec fields, and the exact 19-field
  lifecycle receipt set;
- atomic, fsynced, no-replace publication and finalized-byte-only reduction;
- separate exact raw-capture (11/13), guardian (5/4), and reduction (9/11)
  state/transition machines, terminal closure, reachability, and mandatory
  launched-path drain/capture/finalization;
- exact failure and finite resource policies;
- 30 ordered, nonempty, mechanically anchored invariants;
- seven ordered gates and an all-false authorization map.

## Hostile Corpus

The mutation corpus includes authority forgery, TLA-primary drift, same-UID
boundary claims, candidate trust/write/cgroup/decision grants, missing platform
evidence, symlink and hardlink weakening, writable snapshots, plan narrowing,
shell and environment substitution, fork-then-attach, process-group containment,
leader-only kill, lost `no_new_privileges`, UID reuse before drain, guardian
failure, candidate-authored evidence, missing drain receipts, mutable publication,
reducer workspace reopening, direct terminal transitions, timeout-as-success,
supervisor-death drain omission, resource-exhaustion success, invariant removal,
semantic-freeze forgery, deployment forgery, duplicate keys, and NaN.

Every mutant was required to raise the validator's fail-closed contract error.
The derived checks independently enforce resource arithmetic, role/action
compatibility, failure-writer authority, emitted receipt coverage, strict
payload eligibility, and total raw bounds instead of copying contract constants.
No mutant-specific expected result is read from the candidate contract.

## Disposition

`C4CAP-G1-CONTRACT` and `C4CAP-G2-HOSTILE` are locally satisfied for this exact
contract digest. The separate mechanism regression record closes G3 through G5
locally; the long exact capture G6 and reduction of its finalized bytes G7
remain required.

Candidate-4 full child reachability, parent reachability, and commutation remain
`NOT_RUN`. No F0, R11, K0/G0, semantic-freeze, TLA+, Linux, Monitor, protection,
performance, cost, cluster, or deployment credit follows. No Linux behavior
changed.
