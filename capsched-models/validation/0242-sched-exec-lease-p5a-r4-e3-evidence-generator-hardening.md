# Validation 0242: SchedExecLease P5A-R4 E3 Evidence Generator Hardening

Date: 2026-07-17

Status: passed. The three validated N-133 evidence-generator robustness
defects are fixed and independently reproduced. This restores the plan-only
N-133 seal; it does not promote R4-E3 source or runtime behavior.

## Trigger and Boundary

An exhaustive security diff review of exact capsched range
`268a17c182da80a127f7376c42f992dc8f822bc6..73494baaba20931d7638ffb1ded33122304dbb1f`
reviewed all 14 changed files and validated three defects in the N-133 runner:

1. `RUN_ID=..` passed the old character-class guard, and an existing run
   directory or symlink was reusable whenever `result.json` was absent.
2. The 76-element unsafe-fault array and several other plan arrays were
   count-checked but were not bound to exact bytes before use.
3. mutable E2 JSON evidence was hashed and then reopened for semantic parsing,
   allowing the parsed bytes to differ from the bytes named by the result hash.

All three required the same trusted developer identity in the current manual
workflow, so none crossed the scan threat model's reportability boundary.
They were nevertheless merge blockers because N-133 claims deterministic,
immutable evidence generation.

## Fix

The runner now:

- accepts only nonempty, alphanumeric-leading `[A-Za-z0-9._-]` run IDs and
  rejects `.`, `..`, leading punctuation, separators, whitespace, and shell
  option-shaped values;
- atomically creates a fresh run directory and rejects every pre-existing
  file, directory, or symlink at that run ID;
- snapshots and exact-hash verifies the hardening helper before sourcing it,
  then pins the exact plan, model, safe TLC configuration, and TLA jar SHA-256
  values before first use;
- snapshots those files and all five E2 evidence inputs into the fresh private
  run directory, rejects symlink sources, makes every snapshot mode `0444`,
  uses only snapshot bytes thereafter, and rehashes them after validation;
- reads the patch series from the immutable Git object rather than reopening
  mutable working-tree bytes;
- requires 36 unique safe-token case families, four unique safe-token
  liveness properties, and 76 unique safe-token fault names in addition to the
  exact plan digest;
- verifies that the runner and pinned helper did not change during the run;
- writes `result.json.pending`, validates it with `jq`, and atomically renames
  it to `result.json` only after every gate succeeds.

Pinned implementation identities:

```text
runner SHA-256
  450114f0ca6004869630a827369b454fe2f0c0b86459c4e1212fd50d25b7ea9b
hardening helper SHA-256
  4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
focused regression test SHA-256
  f955a90553fbc9c8c5f544c46de1b702b3c8746c412bacb77ce326f4046d82fe
```

## Focused Regression

Command:

```bash
container machine run -n domainlease-dev \
  --workdir /Users/niania/Documents/linux-cap/capsched \
  ./capsched-models/validation/\
test-sched-exec-lease-p5a-r4-e3-evidence-runner-hardening.sh
```

Result:

```text
PASS: RUN_ID, fresh-output, exact-plan, and immutable-snapshot controls
```

The test uses the production helper and real runner entry boundary. It proves:

- positive run IDs remain accepted;
- `.`, `..`, leading punctuation, slash, and whitespace are rejected;
- duplicate and symlink output directories are rejected before validation;
- a 76-entry duplicate-fault plan is rejected by the exact pre-use digest;
- a verified snapshot retains the expected bytes after its source changes;
- wrong-hash and symlink evidence sources are rejected.

## Canonical and Independent Reproduction

Canonical r13:

```text
run
  20260717T-p5a-r4-e3-concurrency-plan-r13
result SHA-256
  79a9c62edc8dfa58645028c9ab43af9554f7672bbae267f8b5c7ab0c9157c912
```

Independent r14:

```text
run
  20260717T-p5a-r4-e3-concurrency-plan-r14
result SHA-256
  2be94265244a7cde6ff5f4d353133fa6315b692b65ad762b743ac0a89d309537
```

After removing only `run_id` and the run-specific
`source_object_manifest` pathname, every field is identical:

```text
normalized SHA-256
  bea904bf500ab43f768364f72d45f73ea843434ad5d3a0f9f86b22583e9a7f26
source-object manifest SHA-256
  d820f285d5486b5b7ddf287302ff41379d3718389ac3e9f0d648e494b59820c2
```

Both full runs passed:

```text
source anchors                  48/48
future absence checks           10/10
safe states generated           30
safe distinct states            29
complete graph depth            29
temporal properties checked      4
unsafe counterexamples          76/76
input snapshots             all 0444
pending result after pass         none
```

## Decision

```text
three generator defects: fixed
original malicious cases: no longer reproduce
legitimate N-133 plan run: preserved and reproduced twice
N-133 plan-only seal: restored on r13/r14
R4-E3 disposable exact two-file draft: allowed
R4-E3 source/correctness/runtime acceptance: still blocked
R4-E4, primary/patch promotion, protection, latency, performance,
deployment, multi-node, multi-cluster, datacenter claims: still blocked
```
