# Validation 0019: Slice 0C Trace Execution Runbook

Status: Ready for operator execution

Date: 2026-06-26

## Purpose

Provide exact operator steps for a future Slice 0C no-code trace run.

This runbook exists so the trace run can be executed with root/tracefs access
without changing the design boundary or turning observation into a security
claim.

## Preconditions

Required:

```text
root or tracefs write access
writable /sys/kernel/tracing or /sys/kernel/debug/tracing
gcc if rebuilding the synthetic workload helper
```

Preferred:

```text
running kernel built from the CapSched Linux worktree
or explicit record that the running kernel is a distro kernel
```

Current blocker recorded in `validation/0016`:

```text
current user lacks tracefs write access
running kernel is Ubuntu 6.17.0-35-generic
runner not executed
```

## Step 1: Build Workload Helper

```sh
cd /media/nia/scsiusb/dev/linux-cap
./capsched/capsched-models/validation/build-slice0c-workload.sh
```

Expected output:

```text
/media/nia/scsiusb/dev/linux-cap/build/workloads/slice0c_sched_workload
```

## Step 2: Run a Small Trace Smoke

```sh
cd /media/nia/scsiusb/dev/linux-cap
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload forkexec 100
```

The runner should print an output directory:

```text
/media/nia/scsiusb/dev/linux-cap/build/traces/slice0c-no-code-<timestamp>
```

## Step 3: Analyze the Trace

```sh
cd /media/nia/scsiusb/dev/linux-cap
./capsched/capsched-models/validation/analyze-slice0c-trace.sh \
  ./build/traces/slice0c-no-code-<timestamp>
```

Expected output file:

```text
./build/traces/slice0c-no-code-<timestamp>/coverage-summary.md
```

## Step 4: Run Broader Synthetic Workloads

Run futex cross-CPU wake pressure:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload futex 50000 cross
```

Run affinity migration pressure:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload affinity 40
```

Run scheduler pressure:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload pressure 8 500000
```

Run combined moderate workload:

```sh
sudo ./capsched/capsched-models/validation/run-slice0c-no-code-trace.sh \
  ./build/workloads/slice0c_sched_workload all
```

Analyze each trace directory separately.

## Step 5: Create Result Record

Do not edit the plans in place. Create a new validation result file using the
next unused validation ID. Since `0020` and `0021` are now used for QEMU boot
validation, a future host no-code trace result should use a later ID.

```text
capsched-models/validation/00NN-slice0c-no-code-trace-result.md
```

Use this template:

````markdown
# Validation 00NN: Slice 0C No-Code Trace Result

Status: Passed for observation | Incomplete | Blocked

Date: YYYY-MM-DD

## Boundary

This run observed scheduler paths. It does not validate RunCap enforcement,
FrozenRunUse enforcement, DomainTag activation, monitor-backed authority, or
hypervisor-grade isolation.

## Kernel

```text
uname:
config:
matches CapSched worktree:
linux worktree commit:
```

## Commands

```sh
build command:
runner command:
analyzer command:
```

## Artifacts

```text
trace directory:
metadata:
trace:
coverage summary:
```

## Observed Categories

Paste or summarize the category table from `coverage-summary.md`.

## Ambiguous or Not Inferable

List every `ambiguous` and `not_inferable` category and explain what would be
needed to resolve it.

## Unobserved Categories

List every `not_observed` category and whether a synthetic workload, dynamic
kprobe, or later CONFIG_CAPSCHED internal observation patch is needed.

## Decision

```text
no-code tracing sufficient for now
or more synthetic workloads needed
or dynamic kprobes needed
or minimal CONFIG_CAPSCHED internal observation patch justified
or return to source analysis
```
````

## Stop Conditions

Do not claim the run is valid if:

```text
tracefs settings were not restored
trace output was not saved
the kernel/config were not recorded
the running kernel mismatch was hidden
coverage-summary.md was not generated
the result text claims enforcement or isolation
```

## Interpretation Rules

Use these rules when writing the result:

```text
observed:
  useful trace evidence, not security evidence

ambiguous:
  visible target but branch or flag not proven

not_observed:
  workload or trace-method gap, not proof of irrelevance

not_inferable:
  current no-code method cannot answer this category
```

## Next Gate After Result

Depending on the result, choose one:

```text
G2 repeat with better workload
G2 add dynamic kprobe plan
G2 justify minimal CONFIG_CAPSCHED internal observation patch
G3 refine RunnableLease model with expanded Linux runnable states
```

Do not proceed to enforcement from this run alone.
