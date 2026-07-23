# Validation 0248: SchedExecLease P5A-R4 E3 Six-Boot Attempt 1 Rejection

Date: 2026-07-17

Status: rejected after the first arm64 standard-debug boot. The retained
failure authorizes a test-harness correction and a fresh source gate only. It
does not authorize reuse of the prior N-134 closure or any reduced boot
matrix.

## Frozen Attempt

Run `20260717T-p5a-r4-e3-six-boot-r1` used candidate
`f9c737c93ecff48c6f512048b05b1b49f4a54ca5`, runner SHA-256
`cff384cb01a82a446b811ec90d988ddd062f08946633d78511441599f793a809`,
and the two independently closed N-134 results. The arm64 build completed,
the build-verification log was empty, QEMU exited zero, and the exact suite
reported `pass:34 fail:2 skip:0 total:36`. The runner then failed closed and
did not start the remaining five configurations.

Retained evidence:

```text
console sha256: 3e7179423702f445a83b41af975e6ae32b37a60bbbd02941a831f3bce2bb2e78
KTAP sha256:    4cec066170889e95f8bc90f28e3976cfcc972787ca6fefa8e1642a4d57075c90
build sha256:   257f238b6f77ccae221f4e27aac6f7d0a55b5598c8182616fa65ceeb6d4c5218
config sha256:  4e9ae559b9de405119794a3cce84324170986c556e77064a58138db2ad361fd2
job-log sha256: b39b47f6f70973ee093d3d3ef9f6f4c4fd15ecf4a95bcbc1b7dabbb7f51aa413
```

The run-specific internal-ext4 build and disposable worktree were removed by
the runner. The 1.1 MiB diagnostic record and the rejected Git object remain.
No result JSON exists because an incomplete matrix cannot be sealed as a
matrix result.

## Exact Failures

`sched_exec_r4_test_dirty_node_unique_and_bounded` failed because the old
test drain performed only two IRQ sync/workqueue flush pairs. The synthetic
recovery worker intentionally removes one dirty projection per invocation,
while the case installs all `B_MAX=64` unique nodes. Two fixed rounds cannot
establish quiescence and left the dirty list nonempty.

`sched_exec_r4_test_cancel_pending_running_and_requeued` observed
`cancel_work_running == 0`. Retire counted a running notifier, but the forced
schedule deliberately held the rq recovery worker and queued the notifier
behind it on a max-active-one workqueue. Retire also signalled
`retire_blocked` before observing recovery cancellation state, allowing the
test thread to release the worker first. The required running state was
therefore neither the state being counted nor deterministically sampled.

All other 34 cases passed, including the five 2,048-iteration stress
families. That does not weaken either failure or accept concurrency
correctness.

## Corrected Candidate

The corrected candidate remains one direct E2 child and changes only the
default-off same-translation-unit KUnit harness:

```text
parent:   a429fc30252ac6af94c51d96cd4ac24e72d9f83b
commit:   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
tree:     58c6510c6f517004e37107786d006bb8333b79b8
diff sha: 096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
boundary: init/Kconfig, kernel/sched/exec_lease.c; 2,821 additions, 0 deletions
```

Drain is now a bounded fixed-point operation. Its 136-round bound covers two
complete `B_MAX` recovery passes, one notifier restart over both test rqs,
and terminal dispatch/owner-clear rounds. It returns only when IRQ work,
recovery work, dirty ownership, notifier work, and notifier ownership are all
quiescent; exhaustion increments `protocol_errors` so a liveness defect is
not hidden.

Retire now snapshots pending notifier state under the membership lock and
running/requeued recovery state under the rq lock before releasing
`retire_blocked`. Later cleanup consumes that frozen cancellation boundary.
The final source delta passes `git diff --check` and strict checkpatch with
zero errors, warnings, and checks.

## Authorization Boundary

The prior source gate and closures remain valid evidence for the rejected
candidate only. The corrected commit must pass a fresh dual-architecture
four-mode source gate and fresh independent closure before any new six-boot
matrix may start. R4-E3 source correctness, concurrency correctness, runtime
behavior, production protection, deployment, multi-node, multi-cluster, and
datacenter readiness remain false.
