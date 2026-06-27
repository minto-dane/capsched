# Formal 0015: Wake Authority Preparation Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-06-27

## Purpose

This model refines:

```text
analysis/0032-block-wait-register-authority-preparation.md
```

It checks the rule:

```text
Wake authority must be prepared before wake_q_add(), wake_up_q(), or F1.
F1 may observe revocation and reject before TASK_WAKING, but it must not
discover missing authority.
```

## Configurations

Safe:

```text
WakeAuthorityPreparationSafe.cfg
```

Expected result:

```text
TLC passes.
```

Unsafe:

```text
WakeAuthorityPreparationUnsafeWakeQ.cfg
WakeAuthorityPreparationUnsafeLazy.cfg
WakeAuthorityPreparationUnsafeRevoke.cfg
```

Expected result:

```text
TLC produces counterexamples.
```

Validation record:

```text
validation/0027-wake-authority-preparation-tlc.md
```

## Interpretation

This is a tiny design-filter model. It does not prove Linux waitqueues or
futexes. It rejects three bad implementation families:

```text
wake_q_add before authority is prepared
F1 lazy authority discovery
execution after authority was revoked between wake_q_add and F1
```
