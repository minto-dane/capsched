# Validation 0002: L0 Slice 0 Build Validation Plan

Status: Draft plan, not yet executed

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This plan defines the validation gate for the first no-behavior-change
CapSched Linux patch slice:

```text
Implementation 0002: L0 Slice 0 Scaffolding Plan
```

The goal is not to prove scheduler security. The goal is to prove that the
first scaffold patch does not disturb normal Linux behavior when disabled and
builds cleanly when enabled.

## Workspace Rule

Do not build inside the Linux source tree. Use an external `O=` directory so
the Linux Git tree stays clean.

Suggested build root:

```text
/media/nia/scsiusb/dev/linux-cap/build/
```

This directory is not part of the project-control Git repository and should not
be committed.

## Baseline Before Patch

Before applying any Linux patch, create a baseline build from the upstream base:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
mkdir -p ../build/linux-l0-baseline-x86_64
make O=../build/linux-l0-baseline-x86_64 x86_64_defconfig
make O=../build/linux-l0-baseline-x86_64 -j8 vmlinux
git status --short --branch
```

Expected:

```text
build succeeds
Linux source tree remains clean
no .config appears in the source tree
```

## Slice 0A: CONFIG_CAPSCHED=n

After the Slice 0A patch, first prove disabled behavior:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
mkdir -p ../build/linux-l0-capsched-off-x86_64
make O=../build/linux-l0-capsched-off-x86_64 x86_64_defconfig
scripts/config --file ../build/linux-l0-capsched-off-x86_64/.config --disable CAPSCHED
make O=../build/linux-l0-capsched-off-x86_64 olddefconfig
make O=../build/linux-l0-capsched-off-x86_64 -j8 vmlinux
git status --short --branch
```

Expected:

```text
build succeeds
CONFIG_CAPSCHED is absent or disabled
capsched.o is not built
task_struct layout is unchanged by CONFIG_CAPSCHED=n
Linux source tree remains clean except for intentional patch files
```

Evidence to collect:

```sh
grep -n "CONFIG_CAPSCHED" ../build/linux-l0-capsched-off-x86_64/.config
find ../build/linux-l0-capsched-off-x86_64 -name '*capsched*' -print
```

## Slice 0A: CONFIG_CAPSCHED=y

Then prove enabled scaffold build:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
mkdir -p ../build/linux-l0-capsched-on-x86_64
make O=../build/linux-l0-capsched-on-x86_64 x86_64_defconfig
scripts/config --file ../build/linux-l0-capsched-on-x86_64/.config --enable EXPERT
scripts/config --file ../build/linux-l0-capsched-on-x86_64/.config --enable CAPSCHED
make O=../build/linux-l0-capsched-on-x86_64 olddefconfig
make O=../build/linux-l0-capsched-on-x86_64 -j8 vmlinux
git status --short --branch
```

Expected:

```text
build succeeds
CONFIG_EXPERT=y
CONFIG_CAPSCHED=y
capsched.o is built
no scheduler behavior changes are introduced by the patch
no user ABI appears
no runtime enforcement exists
```

Evidence to collect:

```sh
grep -n "CONFIG_CAPSCHED" ../build/linux-l0-capsched-on-x86_64/.config
find ../build/linux-l0-capsched-on-x86_64 -name '*capsched*' -print
```

## Optional Config Variants

The first required build target is `x86_64_defconfig`. Additional variants
should be added before any scheduler-path patch:

```text
SCHED_CORE=y:
  validates that CapSched scaffolding coexists with core scheduling builds.

SCHED_CLASS_EXT=y:
  validates coexistence with sched_ext build dependencies where available.

NO_HZ_FULL=y:
  validates future tick-accounting assumptions where practical.

tiny.config:
  validates minimal config pressure and missing dependency assumptions.
```

Do not block Slice 0A on every optional variant. Do block the first scheduler
semantic patch on at least one scheduler-heavy variant.

## Static Source Checks

Before committing the first Linux patch:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
git diff --check
git status --short --branch
```

Manual review checks:

```text
No changes to enqueue/pick/switch/tick/fork/exec/exit paths in Slice 0A.
No changes to include/linux/sched.h in Slice 0A.
No new UAPI header.
No new syscall, prctl, debugfs, sysfs, or procfs surface.
Kconfig help text explicitly says L0 is not a security boundary.
CONFIG_CAPSCHED defaults to n.
```

## What This Validation Does Not Prove

This plan does not prove:

```text
No RunCap, no enqueue.
No SchedContext, no execution.
No DomainTag activation, no cross-Domain context switch.
No async provenance loss.
Hypervisor-grade isolation.
Monitor-backed non-forgeability.
```

Those claims require later semantic patches, TLA model updates, runtime tests,
and eventually monitor-backed enforcement.

## Follow-On Validation Gates

After Slice 0A:

```text
Slice 0B:
  verify task_struct layout impact and init_task/idle/fork defaults.

Slice 0C:
  verify default Domain/SchedContext initialization for init, idle, kthreads,
  user tasks, io workers, and fork paths.

Slice 0D:
  verify trace-only lifecycle and context-switch instrumentation.

Slice 1:
  verify frozen-use preparation coverage for normal wake, new-task wake,
  delayed wake, migration, and pick fast paths.
```

## Preliminary Conclusion

The first Linux patch should be validated like a kernel plumbing patch, not a
security feature:

```text
disabled config is inert
enabled config builds
source tree stays clean under O= builds
no scheduler behavior changes
no security claims
```

That gives CapSched a disciplined entry point without creating a false sense of
protection.
