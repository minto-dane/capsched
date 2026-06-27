# Validation 0037: Exec Generation and Inheritance TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0025-exec-generation-inheritance-model/ExecGeneration.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0042-exec-generation-inheritance-semantics.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeDomain.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeRunNoContinuation.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeOldEndpoint.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeFdNoDerive.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeCloseOnExec.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeCredAmplify.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeExecfd.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeOldAsync.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeOldMmap.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/exec-generation-20260627T092917Z/ExecGenerationUnsafeCheckOnly.log
```

## Result Summary

Safe configuration:

```text
config: ExecGenerationSafe.cfg
result: PASS
generated states: 11
distinct states: 11
search depth: 5
```

Unsafe configurations produced expected counterexamples:

```text
config: ExecGenerationUnsafeDomain.cfg
target invariant: NoExecDomainChangeWithoutToken
result: expected FAIL
generated states before violation: 12
distinct states before violation: 12
depth: 5

config: ExecGenerationUnsafeRunNoContinuation.cfg
target invariant: NoRunAfterExecWithoutContinuation
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeOldEndpoint.cfg
target invariant: NoOldEndpointUseAfterExec
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeFdNoDerive.cfg
target invariant: NoSurvivingFdWithoutDerivation
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeCloseOnExec.cfg
target invariant: NoCloseOnExecLeak
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeCredAmplify.cfg
target invariant: NoCredChangeEndpointAmplification
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeExecfd.cfg
target invariant: NoExecfdWithoutDerivation
result: expected FAIL
generated states before violation: 13
distinct states before violation: 12
depth: 5

config: ExecGenerationUnsafeOldAsync.cfg
target invariant: NoOldAsyncUseAfterExec
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeOldMmap.cfg
target invariant: NoOldMmapAcrossExec
result: expected FAIL
generated states before violation: 13
distinct states before violation: 13
depth: 5

config: ExecGenerationUnsafeCheckOnly.cfg
target invariant: NoCheckOnlyMutation
result: expected FAIL
generated states before violation: 12
distinct states before violation: 12
depth: 5
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Exec cannot change CapSched Domain identity unless an explicit
   monitor-backed DomainTransitionCap/token exists.

2. A task may continue after successful exec only through a same-Domain
   ExecContinuation with live SchedContext and fresh ProgramGeneration.

3. Old FrozenEndpointUse cannot authorize post-exec endpoint effects.

4. Surviving non-CLOEXEC fd reachability must be derived or attenuated for the
   new ProgramGeneration before endpoint effects.

5. CLOEXEC endpoints must not leak usable authority into the new program image.

6. Linux credential or LSM-domain changes cannot amplify inherited endpoint
   authority; post-exec endpoints must be attenuated, closed, or explicitly
   derived.

7. execfd handoff to an interpreter is a derived endpoint handoff, not ordinary
   ambient fd inheritance.

8. Old program-generation async work cannot perform post-exec endpoint effects.

9. Old mmap/page-fault authority cannot survive into the new mm.

10. AT_EXECVE_CHECK is a policy check only and must not mutate generation or
    derive post-exec authority.
```

## Unsafe Counterexample Meaning

`ExecGenerationUnsafeDomain.cfg` demonstrates automatic Domain change during
exec without a monitor-backed transition token.

`ExecGenerationUnsafeRunNoContinuation.cfg` demonstrates the continuing current
task running after exec without an explicit ExecContinuation.

`ExecGenerationUnsafeOldEndpoint.cfg` demonstrates old program-generation
FrozenEndpointUse authorizing a post-exec endpoint effect.

`ExecGenerationUnsafeFdNoDerive.cfg` demonstrates a surviving fd being treated
as authority without post-exec derivation.

`ExecGenerationUnsafeCloseOnExec.cfg` demonstrates CLOEXEC endpoint authority
leaking into the new program image.

`ExecGenerationUnsafeCredAmplify.cfg` demonstrates credential or LSM-domain
change amplifying inherited endpoint authority.

`ExecGenerationUnsafeExecfd.cfg` demonstrates interpreter-visible execfd use
without derived endpoint authority.

`ExecGenerationUnsafeOldAsync.cfg` demonstrates old async work producing a
post-exec endpoint effect.

`ExecGenerationUnsafeOldMmap.cfg` demonstrates old mmap authority surviving
into the new program image.

`ExecGenerationUnsafeCheckOnly.cfg` demonstrates `AT_EXECVE_CHECK` mutating
generation or deriving post-exec authority.

## Evidence Limits

This validation does not prove:

```text
complete binfmt interpreter-chain behavior
complete LSM credential-transition policy
all fd/object inheritance cases
all io_uring/task_work cancellation behavior
all mmap/page-fault/writeback revocation semantics
real monitor-backed DomainTransitionCap implementation
compatibility cost of endpoint derivation on exec
```

Those remain separate proof obligations.

## Design Consequence

The future implementation shape should distinguish:

```text
ExecCap:
  permission to execute a file/interpreter chain

ExecContinuation:
  permission for the current task to continue in the same Domain with the same
  or revalidated SchedContext after ProgramGeneration changes

ProgramGeneration:
  exec-sensitive generation for endpoint, async, mmap, notification, and
  process-image-scoped authority

ExecEndpointInherit:
  per-surviving-fd derivation or attenuation after successful exec

ExecfdGrant:
  derived endpoint authority for interpreter-visible executable fd handoff
```

The immediate Linux code should not enforce this yet. The next trace-only or
type-only slice should first prove that the selected attachment points can
observe point-of-no-return, `self_exec_id` increment, close-on-exec, LSM cred
commit, execfd insertion, and async cancellation without changing behavior.
