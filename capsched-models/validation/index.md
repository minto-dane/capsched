# Validation Index

Updated: 2026-06-27

## Current Validation Records

| ID | Status | Title |
| --- | --- | --- |
| 0001 | Passed for tiny finite model | Runnable Lease TLC Check |
| 0002 | Executed by systemd user runner | L0 Slice 0 Build Validation Plan |
| 0003 | Partially blocked by missing host dependency | L0 Slice 0 Validation Attempt |
| 0004 | Passed | L0 Slice 0 Systemd User Build Run |
| 0005 | Passed for tiny finite model | Endpoint Async Provenance TLC Check |
| 0006 | Passed for tiny finite model | Broker BudgetTicket TLC Check |
| 0007 | Passed for tiny finite model | Domain Monitor Activation TLC Check |
| 0008 | Stopped before completion | Cluster Lease Full Integration Systemd TLC Run |
| 0009 | Passed for decomposed finite models | Cluster Authority Decomposition TLC Check |
| 0010 | Passed for decomposed finite models | Memory Ownership TLC Check |
| 0011 | Passed after counterexample-driven fix | Direct Map and TLB Revocation TLC Check |
| 0012 | Passed after counterexample-driven fix | Page Cache Overlay Conflict TLC Check |
| 0013 | Passed with two finite TLC runs | Queue Lease and IOMMU Boundary TLC Check |
| 0014 | Passed | L0 Slice 0B Build Run |
| 0015 | Planned | Slice 0C No-Code Trace Plan |
| 0016 | Not executed | Slice 0C Trace Readiness Check |
| 0017 | Planned | Slice 0C Trace Analysis and Workload Plan |
| 0018 | Added, build-tested, and smoke-tested | Slice 0C Synthetic Workload Helper |
| 0019 | Ready for operator execution | Slice 0C Trace Execution Runbook |
| 0020 | Executed | Slice 0C QEMU Boot Validation Plan |
| 0021 | Passed for QEMU boot smoke; trace coverage incomplete | Slice 0C QEMU Boot Smoke Result |
| 0022 | Passed for broader QEMU workload execution; trace coverage still incomplete | Slice 0C QEMU Broader Workload Result |
| 0023 | Passed for guest-side kprobe observation; still observation-only | Slice 0C QEMU Kprobe Observation Result |
| 0024 | Passed for tiny finite model | Linux Scheduler Authority TLC Check |
| 0025 | Safe model passed; unsafe models produced expected counterexamples | Scheduler Admission Failure TLC Check |
| 0026 | Safe model passed; unsafe models produced expected counterexamples | F1 Admission Data TLC Check |
| 0027 | Safe model passed; unsafe models produced expected counterexamples | Wake Authority Preparation TLC Check |
| 0028 | Safe model passed; unsafe models produced expected counterexamples | Task-Local Run State TLC Check |
| 0029 | Safe model passed; unsafe models produced expected counterexamples | Workqueue BudgetTicket Carrier TLC Check |
| 0030 | Safe model passed; unsafe models produced expected counterexamples | Shared Futex Endpoint TLC Check |
| 0031 | Safe model passed; unsafe models produced expected counterexamples | Priority Donation Authority TLC Check |
| 0032 | Safe model passed; unsafe models produced expected counterexamples | Placement Refresh Authority TLC Check |
| 0033 | Safe model passed; unsafe models produced expected counterexamples | Same-Domain Fast Path Freshness TLC Check |
| 0034 | Safe model passed; unsafe models produced expected counterexamples | Budget Split and NO_HZ Overrun TLC Check |
| 0035 | Safe model passed; unsafe models produced expected counterexamples | Class Selected-State TLC Check |
| 0036 | Safe model passed; unsafe models produced expected counterexamples | Wider Endpoint Capability TLC Check |
| 0037 | Safe model passed; unsafe models produced expected counterexamples | Exec Generation and Inheritance TLC Check |
| 0038 | Safe model passed; unsafe models produced expected counterexamples | Post-Exec Resource Inheritance TLC Check |
| 0039 | Planned | Post-Exec Resource Trace-Only Plan |
| 0040 | Executed; observation-only gaps remain | Post-Exec Resource QEMU Trace Result |
| 0041 | Planned | Workqueue Origin Observation Plan |

## Principles

Validation principles:

- Validate semantic claims, not only whether tests pass.
- Treat TLC as supporting evidence, not as the project objective.
- Separate Linux-only prototype claims from monitor-backed protection claims.
- Treat security invariants as explicit properties.
- Record negative results and counterexamples.
- Prefer small models before broad prototypes.

Candidate validators/verifiers:

- TLA+ for state-machine safety and liveness properties.
- Alloy for relational capability/object invariants.
- KUnit for kernel-local unit properties once implementation exists.
- LKDTM or targeted fault-injection style tests for boundary behavior.
- syzkaller-style fuzzing after a minimal prototype exists.
- perf/trace/bpftrace/ftrace for overhead and scheduling behavior evidence.
