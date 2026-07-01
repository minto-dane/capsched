# Validation 0101: Linux Async Carrier Patch Scope TLC

Status: safe model passed; unsafe models produced expected counterexamples;
plan JSON checked

Date: 2026-07-01

## Inputs

```text
implementation/0014-linux-async-carrier-candidate-patch-plan.md
implementation/linux-async-carrier-candidate-patch-plan-v1.json
formal/0063-linux-async-carrier-patch-scope-model/
implementation/0013-combined-async-adapter-precondition-gate.md
validation/0100-combined-async-adapter-precondition-tlc.md
```

## Run Directory

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/linux-async-carrier-patch-scope-20260701T185824Z
```

## Safe Run

Command shape:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -config LinuxAsyncCarrierPatchScopeSafe.cfg \
  LinuxAsyncCarrierPatchScope.tla
```

Result:

```text
exit_code=0
states_generated=9
distinct_states=8
states_left_on_queue=0
search_depth=8
```

The safe model covers:

```text
combined gate read -> patch classified -> behavior hooks blocked ->
no-behavior scope recorded -> review preconditions recorded ->
candidate patch plan accepted -> accept
```

## Expected Unsafe Counterexamples

All unsafe configurations exited with code `12` and violated the intended
invariant:

| Config | Violated invariant |
| --- | --- |
| `LinuxAsyncCarrierPatchScopeUnsafeBehaviorChange` | `NoBehaviorChange` |
| `LinuxAsyncCarrierPatchScopeUnsafeCallablePrototype` | `NoCallablePrototype` |
| `LinuxAsyncCarrierPatchScopeUnsafeDirectCallAbi` | `NoDirectCallAbi` |
| `LinuxAsyncCarrierPatchScopeUnsafeIoUringHook` | `NoIoUringHook` |
| `LinuxAsyncCarrierPatchScopeUnsafeLinuxPatchApproval` | `NoLinuxPatchApproval` |
| `LinuxAsyncCarrierPatchScopeUnsafeMonitorVerified` | `NoMonitorVerifiedClaim` |
| `LinuxAsyncCarrierPatchScopeUnsafeObjectLayout` | `NoObjectLayout` |
| `LinuxAsyncCarrierPatchScopeUnsafeProtectionClaim` | `NoProtectionClaim` |
| `LinuxAsyncCarrierPatchScopeUnsafePublicTracepointAbi` | `NoPublicTracepointAbi` |
| `LinuxAsyncCarrierPatchScopeUnsafeRuntimeState` | `NoRuntimeState` |
| `LinuxAsyncCarrierPatchScopeUnsafeWorkqueueHook` | `NoWorkqueueHook` |
| `LinuxAsyncCarrierPatchScopeUnsafeWorkqueueIoUringInclude` | `NoWorkqueueIoUringInclude` |

Each unsafe run reached:

```text
exit_code=12
states_generated=3
distinct_states=3
states_left_on_queue=1
search_depth=2
```

## JSON Plan Check

Command shape:

```sh
jq empty \
  capsched/capsched-models/implementation/linux-async-carrier-candidate-patch-plan-v1.json

jq -r '[ ... ] | @tsv' \
  capsched/capsched-models/implementation/linux-async-carrier-candidate-patch-plan-v1.json
```

Result:

```text
allowed_patch_classes=3
allowed_patch_classes_with_behavior_change_false=3
blocked_patch_classes=4
blocked_patch_classes_true=4
required_review_before_no_behavior_patch=7
safety_flags_false=9
safety_flags_total=9
workqueue_blocker_requirements=10
io_uring_blocker_requirements=13
```

## Meaning

The plan admits only a future candidate patch proposal, not a Linux patch:

```text
No Linux async-carrier patch is approved.
No behavior-changing workqueue or io_uring hook is approved.
No callable prototype, object layout, runtime state, ABI, tracepoint, monitor
verification, or protection claim is approved.
```

The only potentially admissible future Linux patch class is tiny no-behavior
opaque type scaffolding, and even that requires a separate patch proposal and
review.

## Limits

This is a patch-scope model and plan. It is not Linux implementation, runtime
coverage, ABI approval, monitor verification, behavior change, or production
protection.

## Non-Claims

This validation does not approve Linux code, workqueue integration, io_uring
integration, direct-call ABI, public tracepoints, runtime coverage, monitor
verification, behavior change, or production protection.
