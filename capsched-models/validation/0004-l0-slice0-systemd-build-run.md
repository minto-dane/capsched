# Validation 0004: L0 Slice 0 Systemd User Build Run

Status: Passed

Date: 2026-06-26

## Purpose

Run the Slice 0A build validation outside the chat session so long kernel
builds do not need active supervision.

This executes Validation 0002 against:

```text
base commit:
  4edcdefd4083ae04b1a5656f4be6cd83ae919ef4

Linux commit under test:
  0b685979f27b3d42ee620ced5f707ee391a2a27f
  sched/capsched: Add inert scaffolding
```

## Runner

Script:

```text
/media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-l0-slice0-build-validation.sh
```

Systemd user unit:

```text
capsched-linux-n010-build.service
```

Launch command:

```sh
systemd-run --user \
  --unit=capsched-linux-n010-build \
  --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap \
  /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-l0-slice0-build-validation.sh
```

Current known log:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260626T011458Z.log
```

Useful inspection commands:

```sh
systemctl --user status capsched-linux-n010-build --no-pager
journalctl --user -u capsched-linux-n010-build -f
tail -f /media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260626T011458Z.log
```

## Rootless Build Tools

Because host package installation was not available non-interactively, the
runner uses locally extracted packages under:

```text
/media/nia/scsiusb/dev/linux-cap/tools/apt-local/root
```

The runner exports:

```text
PATH
BISON_PKGDATADIR
PKG_CONFIG_PATH
HOSTCFLAGS
HOSTLDFLAGS
LD_LIBRARY_PATH
```

This provides local `flex`, local `bison`, and libelf development headers and
linker metadata without changing the host system.

## Git Hygiene

The earlier Git author identity warning was handled by setting repo-local
identity in both repositories:

```sh
git -C /media/nia/scsiusb/dev/linux-cap/linux config user.name Codex
git -C /media/nia/scsiusb/dev/linux-cap/linux config user.email codex@local
git -C /media/nia/scsiusb/dev/linux-cap/capsched config user.name Codex
git -C /media/nia/scsiusb/dev/linux-cap/capsched config user.email codex@local
```

After this, `git status --short --branch` in `linux/` showed no warning.

## Initial Failed Invocation

The first transient service invocation wrote:

```text
/media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260626T011423Z.log
```

It failed before building because the runner checked for `$BASE_TREE/.git` as a
directory. A Git worktree may store `.git` as a file, so the runner attempted to
create an already-existing worktree:

```text
fatal: '/media/nia/scsiusb/dev/linux-cap/linux-upstream-base' already exists
```

The runner was fixed to use:

```sh
git -C "$BASE_TREE" rev-parse --is-inside-work-tree
```

## Current Run Snapshot

The second invocation started successfully:

```text
Running as unit: capsched-linux-n010-build.service
invocation ID: af07d41ea3ec486282bf3d91042d7081
```

Initial status showed the unit active and building the upstream baseline
`x86_64_defconfig`.

The journal included non-fatal systemd user inotify watch warnings:

```text
Failed to add control inotify watch descriptor ... No space left on device
Failed to add memory inotify watch descriptor ... No space left on device
```

The service still entered `active (running)`. Treat those warnings as host
environment noise unless the unit fails later with a related error.

## Final Result

The service completed:

```text
[2026-06-25T21:41:49-04:00] CapSched L0 Slice 0 build validation completed
```

Run phases:

```text
21:14:58 EDT  validation started
21:15:05 EDT  upstream baseline vmlinux build started
21:18:31 EDT  Slice 0A CONFIG_CAPSCHED=n config started
21:18:42 EDT  Slice 0A CONFIG_CAPSCHED=n vmlinux build started
21:29:38 EDT  Slice 0A CONFIG_CAPSCHED=y config started
21:29:47 EDT  Slice 0A CONFIG_CAPSCHED=y vmlinux build started
21:41:49 EDT  validation completed
```

Built vmlinux outputs:

```text
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-baseline-base-x86_64/vmlinux
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-off-x86_64/vmlinux
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-x86_64/vmlinux
```

CONFIG evidence:

```text
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-x86_64/.config:177:CONFIG_CAPSCHED=y
```

`grep CONFIG_CAPSCHED` found no matching line in the
`linux-l0-capsched-off-x86_64/.config` file, meaning the symbol is absent or
disabled in that generated config.

Object evidence:

```text
CONFIG_CAPSCHED=n:
  no capsched object file found

CONFIG_CAPSCHED=y:
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-x86_64/kernel/sched/.capsched.o.cmd
  /media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-on-x86_64/kernel/sched/capsched.o
```

Repository cleanliness after the run:

```text
linux:    ## capsched-linux-l0
capsched: ## main
```

## Interpretation

This validation passes for Slice 0A. It still does not prove any scheduler
security invariant. It only checks that the no-behavior-change Slice 0A
scaffolding is build-compatible when disabled and enabled.
