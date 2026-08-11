# Dynamic Residency F0 Candidate-4 Authority-Disjoint Capture Mechanism

## Result

The bounded Linux mechanism suite passes on the dedicated Apple Container VM
(`arm64`, Linux `6.18.15`, cgroup v2, systemd, native ext4 evidence storage).
This locally closes implementation gates `C4CAP-G3-SUPERVISOR`,
`C4CAP-G4-PLATFORM`, and `C4CAP-G5-FAULTS` for the exact source in this
checkpoint:

```text
F0_C4_CAPTURE_BUILD_PASS launcher_sha256=63db0523f7d688761632be61be431898dfa5c4e6b48f8659533867673e92ef93 mode=--build-only source_commit=DEVELOPER_BUILD_ONLY
F0_C4_CAPTURE_LAUNCHER_BASIC_PASS
F0_C4_CAPTURE_LAUNCHER_HOSTILE_PASS hostile_cases=10
F0_C4_CAPTURE_SNAPSHOT_HOSTILE_PASS hostile_cases=5
F0_C4_CAPTURE_SUPERVISOR_SMOKE_PASS components=5
F0_C4_GUARDIAN_RECOVERY_PASS cases=3
F0_C4_REDUCTION_BOUNDARY_PASS cases=3
```

The immutable toolchain is a read-only EROFS image on the VM-native evidence
filesystem. The currently verified image digest is:

```text
4fadeb77fe5019e0a9ea22ea43b79f07923f587fa90b9636164ab9e396de34ac
```

That digest is a capture input, not a general Ubuntu or supply-chain
attestation.

## Implemented Boundary

- A small C launcher uses `clone3(CLONE_INTO_CGROUP | CLONE_PIDFD)`, pidfd
  waiting, descriptor-anchored cgroup control, `cgroup.kill`, and observed
  `populated 0` before UID reuse or component completion.
- Each component receives a fixed non-root UID/GID, `/dev/null` stdin, private
  mount/PID/network namespaces, an exact read-only input view, a sealed
  read-only toolchain, no new privileges, bounded seccomp, empty capabilities,
  bounded pids/memory/output/time, and no evidence path.
- The root supervisor snapshots exactly eight single-link regular files with
  no-follow/nonblocking opens, seals the exact five-component plan, captures
  stdout/stderr/pre-exec observations and lifecycle receipts, and publishes raw
  evidence with no-replace rename, parent fsync, and a final commit marker.
- A distinct guardian persists run intent before launch, owns incomplete
  publication after supervisor death, and reconciles unfinished intents across
  VM reboot without treating mixed-boot bytes as complete.
- A distinct reduction supervisor gives the fixed `domainlease-reducer`
  identity only a read-only view of a committed capture and the EROFS
  toolchain. The reducer has UID/GID `200011`, no additional group authority,
  empty capability sets and bounding set, NNP/seccomp, and descriptors
  `{0,1,2}`. Reduction output is finalized in a separate namespace.
- The installer refuses dirty source for root installation, uses pinned tool
  paths and root-private staging, canonicalizes the contract, validates fixed
  identities outside subordinate-ID ranges, and emits an installed-artifact
  manifest.

## Negative Fixtures

The launcher suite covers fork/setsid escape, fork pressure, input mutation,
mount denial, network absence, minimal root view, deadline, output flood,
nonzero exit, and nonempty stderr. Snapshot fixtures reject FIFO, Unix socket,
directory, device symlink, and hardlink inputs without blocking. Guardian
fixtures cover supervisor death, successful commit preservation, and prior-boot
reconciliation. Reducer fixtures cover a bounded semantic pass, semantic
rejection, and duplicate-key JSON rejection while proving that malformed or
incomplete data cannot become positive.

## Reproduction

After syncing `capsched` into the VM-visible cache:

```sh
container machine run --root -n domainlease-dev \
  --workdir /Users/niania/Library/Caches/domainlease-linux-cap-vm/capsched \
  ./capsched-models/validation/f0-c4-capture/build-install.sh --build-only

F0_C4_LAUNCHER=/tmp/domainlease-f0-c4-build-0/f0-c4-capture-launcher \
  ./capsched-models/validation/f0-c4-capture/test-launcher-basic.sh
```

The remaining scripts are in `validation/f0-c4-capture/` and were executed as
independent VM processes so one failure could not be hidden by shell sequencing.

## Disposition

This is EC0 mechanism evidence, not Candidate-4 semantic evidence. The exact
long campaign is still `NOT_RUN`; therefore G6 and G7 remain open. The three
reducer fixtures prove the authority and parser boundary only and are not a
substitute for reduction of real G6 bytes. F0, R11, K0/G0, semantic freeze,
TLA+, Linux/Monitor refinement, protection, performance, cost, cluster, and
deployment claims remain false or open. No Linux behavior changed.
