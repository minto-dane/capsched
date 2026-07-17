# Validation 0230: SchedExecLease P5A-R3 E4 Source Gate Attempt 1

Date: 2026-07-16

Status: harness false rejection. No candidate result was produced and no E4
measurement is authorized. Corrected source-gate rerun only is allowed.

## Attempt

Long job `p5a-r3-e4-source-gate`, run
`20260716T-p5a-r3-e4-source-gate`, completed these gates:

```text
identity, direct-child, and exact two-file boundary
strict checkpatch 0 errors / 0 warnings / 0 checks
Kconfig, E3 20-case manifest, E4 42-cell source shape
arm64 E3-parent, E4-disabled, and E4-enabled fresh W=1 objects
x86_64 E3-parent and E4-disabled fresh W=1 objects
x86_64 E4-enabled object compilation
```

The runner then rejected the x86_64 E4-enabled log as a compiler warning.
Inspection showed no compiler diagnostic. GNU make reported that two generated
objtool command files were 6.9-7ms in the future and emitted `Clock skew
detected` on the Apple Container shared filesystem. The original predicate
matched every lowercase `warning:` line and therefore conflated a make
environment warning with a C compiler warning.

## Correction

The corrected runner still rejects compiler diagnostics matching
`file:line[:column]: warning:`. If an initial build reports clock skew, it
immediately reruns the same target from the completed output, requires the
verification log to have zero clock-skew warnings, rechecks compiler warnings,
and rechecks the object. It records the retry count and requires final skew
warnings to be zero in the machine-readable result.

This is not a warning suppression and does not accept a persistently skewed or
possibly incomplete build. Run r1 remains invalid evidence. The exact Linux
candidate and all fixed source/matrix/threshold identities are unchanged.

## Non-Claims

Attempt 1 does not pass validation/0229, authorize E3 regression diagnostics,
authorize E4 measurement, or establish runtime, latency, performance,
production, deployment, or datacenter claims.
