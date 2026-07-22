# SchedExecLease P5A-R4 E4 Arm64 Timing R5 Host-Restart Rejection and R6 Readiness

Date: 2026-07-22

## Decision

Arm64 timing r5 is rejected as an external harness interruption. Host reboot
stopped QEMU after 166 of 682 result rows and before every summary. No runner
result existed after restart. The incomplete rows receive no threshold,
architecture, performance, or x86_64 credit.

Idempotent recovery tool
`tools/seal-p5a-r4-e4-arm64-timing-r5-restart-interruption.sh` at SHA-256
`55ed64fb218fa5739e2b921fa37714e4e1d5719158756e2bc7ef3bc3d39916ed`
sealed `harness_failed/host_restart` result SHA-256
`d7fb9ec3343c18485a9bd03adbc1e7200c5c3404ec517464c3770b3924b268d3`.

## Restart Proof and Artifact Preservation

The run started at `2026-07-22T07:26:35Z`. Both the serial log and detached
job log have final mtime epoch `1784710956`; the new host boot epoch is
`1784710983`, 27 seconds later. No timing runner, QEMU, compiler, or make
process existed after Apple Container recovery. The serial contains exactly
166 typed `R4_E4_RESULT` rows and zero `R4_E4_SUMMARY` rows.

Before retiring VM-internal scratch, recovery independently verified source
commit `82d91805f8e145d2403057f656e590e4bcae12f1` and preserved:

- Image SHA-256
  `21b6ed89a0c48063771ec8988f34731c196265c5ea173967e274fdcc4e7ee6fe`;
- `exec_lease.o` SHA-256
  `e8b8148246e031ad45df45de26cec2e6027bcb5c710c4ce5aef70c7353ec7818`;
- arm64 configuration SHA-256
  `2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b`.

The read-only 55-file interrupted-input manifest has SHA-256
`ad49a9c157c8d0126c8eddfb6d9f127f09b5189622c297f343f15cfce3937b70`.
Both the 3.9 GiB run-owned build root and 1.8 GiB run-owned worktree were
removed only after archive verification; the stale Git worktree record was
pruned, the 64 MiB failure-seal reserve was released, and VM free space
returned to approximately 502 GiB.

## Recovered Execution Environment

The existing 13 GiB sparsebundle was reattached at its exact managed path as
case-sensitive APFS. Primary Linux remained clean at
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`. Apple Container services were
restarted and `domainlease-dev` read back at six vCPUs, 10 GiB RAM, and
`nproc=6`.

The source, runner, matrix, thresholds, QMP placement contract, parser,
capacity gates, and corrected source/E3 closures are unchanged. A fresh full
arm64 timing r6 may therefore start only after binding this exact r5 restart
result and rerunning every normal preflight. R5 rows cannot be resumed or
combined with r6.

## Claim Boundary

Only fresh complete arm64 timing r6 is authorized. A clean result still needs
independent timing closure before exact same-source x86_64 work. A valid fixed
threshold rejection stops x86_64; another harness interruption receives no
partial credit. No live scheduler correctness, bare-metal latency,
performance, production protection, deployment, multi-node, multi-cluster,
or datacenter-readiness claim is accepted.
