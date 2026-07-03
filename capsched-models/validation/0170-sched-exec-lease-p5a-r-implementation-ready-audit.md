# Validation 0170: SchedExecLease P5A-R Implementation-Ready Audit

Date: 2026-07-03

Status: final implementation-ready audit passed for P5A-R ordinary-CFS-only
patch drafting. No Linux behavior patch is accepted by this record.

## Scope

This validation checks:

```text
analysis/0142-sched-exec-lease-p5a-r-implementation-ready-audit.md
analysis/sched-exec-lease-p5a-r-implementation-ready-audit-v1.json
formal/0111-p5a-r-implementation-ready-audit-model/P5ARImplementationReadyAudit.tla
```

## Expected Result

The runner must prove:

```text
all required gates 0163..0169 are present
Linux HEAD matches the audited source basis
patch queue has not yet created 0009
0009 may be drafted only under ordinary-CFS-only constraints
acceptance validation remains required
runtime/protection/cost claims remain false
```

## Runner

```text
validation/run-sched-exec-lease-p5a-r-implementation-ready-audit.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-implementation-ready-audit/20260703T231125Z/
```

## Checks

Audit checks:

```text
required_validation_count=7
missing_validation_count=0
required_model_count=7
missing_model_count=0
linux_0009_may_be_drafted=true
linux_0009_exists=false
linux_0009_accepted=false
runtime_denial_approved=false
cfs_deny_and_repick_approved=false
```

Formal checks:

```text
safe_passed=true
safe_states_generated=5
safe_distinct_states=4
safe_depth=4
unsafe_expected_counterexamples=10
```

The runner also re-runs the P5A-R ordinary-CFS patch-plan validator as a nested
check, using:

```text
RUN_ID=20260703T231125Z-patch-plan
```

## Result

The P5A-R pre-code implementation-ready goal is satisfied for patch drafting
only:

```text
future Linux patch 0009 may be drafted
future Linux patch 0009 is not accepted
runtime denial correctness is not approved
CFS deny-and-repick correctness is not approved
runtime/protection/cost/datacenter claims remain false
```

## Next

The next project step may draft Linux patch `0009` under
implementation/0033. The patch must be treated as untrusted until the complete
acceptance validation matrix passes.
