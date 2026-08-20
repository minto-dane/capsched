# Validation 0247: SchedExecLease P5A-R4 E3 Six-Boot Diagnostic Matrix Launch

Date: 2026-07-17

Status: launch-ready after exact six-configuration smoke. No kernel image was
built and no diagnostic boot or matrix pass is claimed by this document.

## Closed Input Boundary

The runner accepts only candidate
`f9c737c93ecff48c6f512048b05b1b49f4a54ca5`, parent
`a429fc30252ac6af94c51d96cd4ac24e72d9f83b`, tree
`274f7b5d6969dc68e158819191fe598f9587e0ad`, and diff SHA-256
`c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781`.
It snapshots and exact-hash verifies the N-133 plan, corrected source-gate r2,
both N-134 closures, its hardening helper, and itself before using them.
Primary Linux and the patch queue remain fixed at
`5e1ca3037e34823d1ba0cdd1dc04161fac170280` and
`16bb080da472ffabbbafd2698073eca633fb0602`.

The exact runner SHA-256 is
`cff384cb01a82a446b811ec90d988ddd062f08946633d78511441599f793a809`.
Shell syntax and ShellCheck pass with no finding. The runner uses a detached
candidate Git worktree, one fresh internal-ext4 build output per boot, and
retires that output only after sealing its config, compiler, image/object
hashes and sizes, build log, QEMU command/version, console, KTAP, receipts,
seed set, and fault ledger. An interrupt returns a nonzero signal status,
terminates the active make/QEMU child, and removes only run-scoped scratch.

## Exact Matrix

The matrix is fixed and cannot reduce after a failure:

1. arm64 standard debug
2. x86_64 standard debug
3. arm64 hotplug and allocation-fault diagnostics
4. x86_64 hotplug and allocation-fault diagnostics
5. arm64 generic KASAN
6. x86_64 KCSAN strict

Each fresh boot filters exactly `sched_exec_lease_r4_concurrency`, requires all
36 cases and 36 machine-readable receipts, and rejects any failure, skip,
timeout, compiler diagnostic, final clock-skew warning, or configured kernel
warning report. Five named race families must each record 2,048 independent-
oracle checkpoints. The exact six pre-runnable allocation sites and clean
retry receipts are recorded. Standard/fault configs enable KUnit, CPU hotplug,
lockdep, work/RCU debug objects, PROVE_RCU, IRQ flag checks, workqueue watchdog,
FAULT_INJECTION, FAILSLAB, and FAIL_PAGE_ALLOC. Global early-boot fault
probability stays unarmed; deterministic KUnit control supplies the exact
fault schedule.

## Configuration Smoke

Attempt `20260717T-p5a-r4-e3-six-boot-config-smoke-r1` stopped before any
build because the preflight required the literal disabled Kconfig comment for
KCSAN in the arm64 KASAN config. Kconfig correctly omitted the mutually
exclusive symbol instead. The check was narrowed to the semantic condition
that neither `y` nor `m` may be present. This was a harness-only false
rejection; r1 emitted no result and started zero builds and zero boots.

Fresh run `20260717T-p5a-r4-e3-six-boot-config-smoke-r2` resolved all six
configs with zero clock-skew retries and explicitly records zero builds and
zero boots. Result SHA-256 is
`3e49336b8de70a27eddf3f9b64579d836e60614e633e34faf2fee759ca23e467`.
The sorted six-config hash manifest SHA-256 is
`09b500cc0e7ed793673b1e1ec5478dca9679197b544295cbda49331f4163a673`.
All run-scoped internal build outputs and the temporary worktree were removed.

## Monitored Launch Contract

```text
run id:   20260717T-p5a-r4-e3-six-boot-r1
job name: p5a-r4-e3-six-boot
machine:  domainlease-dev
scratch:  /var/tmp/linux-cap-builds/p5a-r4-e3-six-boot/20260717T-p5a-r4-e3-six-boot-r1
monitor:  ./tools/long-job.sh watch p5a-r4-e3-six-boot 30
```

The external probe can report complete only from an exact result containing
the fixed six-boot order, 216 passed cases, 216 receipts, zero failures,
skips, timeouts, and warnings, fresh sequential build retirement, and every
negative claim still false. A passing matrix still requires a separate
read-only artifact closure before R4-E3 source or concurrency correctness may
be considered. It cannot establish live scheduler behavior, runtime denial,
monitor enforcement, performance, protection, deployment, multi-node,
multi-cluster, or datacenter readiness.
