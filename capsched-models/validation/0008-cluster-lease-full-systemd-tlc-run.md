# Validation 0008: Cluster Lease Full Integration Systemd TLC Run

Status: Running under systemd user service

Date: 2026-06-26

## Purpose

Run the full `ClusterLease.tla` integration model outside the chat session. The
model intentionally includes lease issuance, local compilation, local execution,
endpoint use, forged local shadow claims, revocation, and budget conservation.
It is large enough that it should be supervised by systemd rather than the chat.

This does not weaken the model. The split `ClusterBudget` and
`ClusterEndpoint` models exist as auxiliary models, but this run is for the full
integration model:

```text
capsched/capsched-models/formal/0006-cluster-lease-compilation-model/ClusterLease.tla
```

## Runner

Script:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-cluster-lease-full-tlc.sh
```

Systemd user unit:

```text
capsched-cluster-lease-full-tlc.service
```

Launch command:

```sh
systemd-run --user \
  --unit=capsched-cluster-lease-full-tlc \
  --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap \
  --setenv=WORKERS=8 \
  --setenv=FP_INDEX=0 \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-cluster-lease-full-tlc.sh
```

Useful inspection commands:

```sh
systemctl --user status capsched-cluster-lease-full-tlc --no-pager
journalctl --user -u capsched-cluster-lease-full-tlc -f
ls -t /media/nia/scsiusb/dev/linux-cap/build/logs/cluster-lease-full-*.log | head
tail -f $(ls -t /media/nia/scsiusb/dev/linux-cap/build/logs/cluster-lease-full-*.log | head -n 1)
du -sh /media/nia/scsiusb/dev/linux-cap/build/tlc/cluster-lease-full-*
```

## Earlier Interactive Attempts

An interactive full `ClusterLease.tla` run was stopped because it was too large
for a chat-supervised session:

```text
449578459 states generated
48975803 distinct states found
48030591 states left on queue
depth: 6
no invariant error observed before interruption
```

An interactive `ClusterBudget.tla` auxiliary run was also stopped after the
user suggested moving long TLC work to systemd:

```text
860521030 states generated
33644842 distinct states found
26327569 states left on queue
depth: 8
no invariant error observed before interruption
```

These interrupted runs are not pass results.

## Current Result

Pending. Update this record after the systemd service completes.
