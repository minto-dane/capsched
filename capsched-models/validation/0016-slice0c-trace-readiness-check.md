# Validation 0016: Slice 0C Trace Readiness Check

Status: Not executed; blocked by tracefs write access

Date: 2026-06-26

## Purpose

Record whether the Slice 0C no-code trace runner can be executed from the
current chat/session environment.

This is not a trace validation run. It only checks immediate execution
readiness.

## Commands Checked

```sh
id -u
id -un
uname -a
test -w /sys/kernel/tracing/tracing_on
test -w /sys/kernel/debug/tracing/tracing_on
```

## Result

Current user:

```text
uid: 1000
user: nia
```

Running kernel:

```text
Linux nianopc 6.17.0-35-generic #35~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Tue May 26 19:30:42 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

Tracefs write readiness:

```text
tracefs_writable=no
```

## Interpretation

The no-code trace runner was not executed because the current session does not
have tracefs write access.

The running kernel is also not recorded as the current CapSched Linux worktree
kernel:

```text
linux worktree commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462
  sched/capsched: Add type-only authority scaffolding
```

For preliminary Linux-shape observation, a distro kernel run may still be
useful if the source paths are close enough. For evidence attached to the
CapSched branch, prefer booting a kernel built from the CapSched worktree or
recording the mismatch explicitly.

## Next

To execute the runner later:

```text
1. Run with sudo/root or otherwise grant tracefs write access.
2. Record the running kernel and config.
3. Prefer a booted kernel matching the CapSched Linux worktree for stronger
   evidence.
4. Store the runner output under build/traces/.
5. Create a separate validation result record after execution.
```
