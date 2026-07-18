# Validation 0253: SchedExecLease P5A-R4 E3 Six-Boot Attempt 3 Rejection

Date: 2026-07-17

Status: rejected before the final matrix seal because the evidence runner
misclassified three normal KCSAN lifecycle notices. This is a runner false
positive, not evidence of a kernel data race. The incomplete matrix receives
no credit and a complete fresh six-build/six-boot retry remains mandatory.

## Complete Run Boundary

Run `20260717T-p5a-r4-e3-six-boot-r3`, job
`p5a-r4-e3-six-boot-r3`, used candidate
`da9ce9159b3450c28c8faf8dceac671fb7bfeba2` and runner SHA-256
`0fd64ef6aa75330b18a87934fde4ad32978ff077ef9189891bb6ae45920ddb06`.
It started at `2026-07-17T17:50:08Z`; the runner exited one at
`2026-07-17T20:42:37Z`. Job-log SHA-256 is
`e48aaaf8fc04bc8354622781550da178612626e7da6eaef24127688479ec3af6`.

All six fresh kernels built with empty diagnostic-verification logs and all
six QEMU boots exited zero. The first five boot results were atomically
sealed: each contains 36 passed cases, 36 receipts, and zero failures, skips,
timeouts, or warning reports. Their result SHA-256 values are fixed in
`sched-exec-lease-p5a-r4-e3-six-boot-attempt-3-rejection-v1.json`.

The final x86_64 KCSAN boot also reported exact suite summary
`pass:36 fail:0 skip:0 total:36`, 36 unique well-typed receipts, the exact
three fault receipts, and QEMU exit zero. It was deliberately not sealed after
the warning classifier failed, so neither that boot nor the prior five boots
count toward a matrix pass.

## False-Positive Proof

The rejected warning file contains exactly these three serial lines:

```text
kcsan: enabled early
kcsan: strict mode configured
kcsan: selftest: 3/3 tests passed
```

The runner used case-insensitive `grep -Eihn` with a bare `KCSAN:`
alternative. It therefore matched lowercase lifecycle notices. The retained
console contains zero `BUG: KCSAN: data-race`, `BUG: KCSAN: assert: race`,
`race at unknown origin`, `value changed`, or `Reported by Kernel Concurrency
Sanitizer on:` report signatures.

This classification is independently grounded in primary Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`: `kernel/kcsan/report.c` emits
the `BUG: KCSAN:` header and report footer, and
`Documentation/dev-tools/kcsan.rst` documents both known- and unknown-origin
formats. Their SHA-256 values are locked in the machine rejection record.

## Required Hardening

The replacement classifier must allow only the three exact normal lifecycle
forms above. It must reject every other KCSAN-tagged line and retain the
generic BUG, WARNING, oops, panic, sanitizer, lockdep, RCU, lockup, hotplug,
irq-work, refcount, kmemleak, and unreferenced-object gates. Before any kernel
configuration or build it must prove with fixtures that:

1. the three benign KCSAN lifecycle forms produce an empty report;
2. a realistic KCSAN data-race report is detected from header through footer;
3. a generic warning and an unknown lowercase KCSAN message both fail closed.

The runner must bind this attempt-3 rejection by exact SHA-256 and record the
classifier self-test in config-smoke and final results.

## Cleanup and Claim Boundary

The run-owned internal-ext4 build root and disposable candidate worktree are
absent. The primary Linux, patch queue, capsched, and superproject worktrees
remain clean. The 4.5 MiB diagnostic record is retained.

Attempt 3 is not a matrix pass. It does not accept R4-E3 source correctness,
concurrency correctness, runtime behavior, production protection, deployment,
multi-node, multi-cluster, or datacenter readiness.
