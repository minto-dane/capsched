# Validation 0120: Lifecycle Identity Propagation Integration Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0081-lifecycle-identity-propagation-integration-gate-model/
```

The model is a semantic design gate for fork/clone, exec, and exit identity
propagation across scheduler runnable authority.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/lifecycle-identity-propagation-integration-gate-20260701T232504Z/safe \
  -config LifecycleIdentityPropagationIntegrationGateSafe.cfg \
  LifecycleIdentityPropagationIntegrationGate.tla
```

Unsafe configs:

```text
LifecycleIdentityPropagationIntegrationGateUnsafe*.cfg
```

## Result

Safe TLC:

```text
19 generated states
13 distinct states
0 states left on queue
depth 4
```

Unsafe TLC:

```text
20 expected counterexamples
```

JSON contract:

```text
40 source anchors
20 state subjects
6 safe paths
18 requirements
15 forbidden substitutions
20 unsafe cases
16/16 safety flags false
```

Rejected hazards:

```text
child run without SpawnCap
child run without fresh task generation
process clone without fresh process generation
ambient RunCap inheritance
FrozenRunUse inheritance
RunToken inheritance
unbound child SchedContext
wake before identity preparation
new Domain clone without monitor token
clone flags as Domain authority
exec Domain change without token
post-exec run without ExecContinuation
check-only exec mutating generation
old FrozenRunUse after exec
run after exit invalidation
PID/TGID reuse as authority
release state as authority
behavior-change overclaim
monitor-verification overclaim
protection overclaim
```

## Evidence

This validation adds:

```text
E-SCHED-LIFECYCLE-IDENTITY-001
```

It supports:

```text
EXEC-001
COMPAT-001
```

only as model evidence.

## Non-Claims

This is not Linux implementation, fork hook approval, exec hook approval, exit
hook approval, scheduler hook approval, task-field approval, ABI approval,
runtime coverage, monitor verification, behavior change, budget enforcement
evidence, or production protection.
