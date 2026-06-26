# Validation 0003: L0 Slice 0 Validation Attempt

Status: Partially blocked by missing host dependency

Date: 2026-06-25

Linux base before patch:

```text
4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

Linux commit under test:

```text
0b685979f27b3d42ee620ced5f707ee391a2a27f
sched/capsched: Add inert scaffolding
```

## Scope

This validation attempt covers the first selected Linux patch slice:

```text
Slice 0A: inert CONFIG_CAPSCHED build scaffolding
```

The patch adds:

```text
include/linux/capsched.h
kernel/sched/capsched.c
CONFIG_CAPSCHED in init/Kconfig
kernel/sched/Makefile wiring
```

It does not modify:

```text
include/linux/sched.h
kernel/sched/core.c
kernel/fork.c
fs/exec.c
kernel/exit.c
```

## Completed Checks

Static whitespace check:

```text
git diff --cached --check
passed
```

Critical-path diff check:

```text
git diff --cached -- include/linux/sched.h kernel/sched/core.c \
  kernel/fork.c fs/exec.c kernel/exit.c
```

Result:

```text
empty diff
```

checkpatch:

```text
git diff --cached | perl scripts/checkpatch.pl --no-tree -
```

Result:

```text
0 errors
1 warning: added, moved or deleted file(s), does MAINTAINERS need updating?
```

Interpretation:

```text
The MAINTAINERS warning is expected for new files. We did not add a fake
maintainer entry at this stage.
```

Linux repository state after commit:

```text
git status --short --branch
## capsched-linux-l0
```

## Build Attempt

Baseline command:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
mkdir -p ../build/linux-l0-baseline-x86_64
make O=../build/linux-l0-baseline-x86_64 x86_64_defconfig
```

Result:

```text
/bin/sh: 1: flex: not found
make[3]: *** [scripts/Makefile.host:9: scripts/kconfig/lexer.lex.c] Error 127
make: *** [Makefile:248: __sub-make] Error 2
```

Post-patch CONFIG_CAPSCHED=n config command:

```sh
cd /media/nia/scsiusb/dev/linux-cap/linux
mkdir -p ../build/linux-l0-capsched-off-x86_64
make O=../build/linux-l0-capsched-off-x86_64 x86_64_defconfig
```

Result:

```text
/bin/sh: 1: flex: not found
make[3]: *** [scripts/Makefile.host:9: scripts/kconfig/lexer.lex.c] Error 127
make: *** [Makefile:248: __sub-make] Error 2
```

Build directories created:

```text
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-baseline-x86_64
/media/nia/scsiusb/dev/linux-cap/build/linux-l0-capsched-off-x86_64
```

These contain only early generated build files such as `Makefile` and
`.gitignore`.

## Host Dependency Status

Available:

```text
gcc
make
bc
openssl
```

Missing in PATH during this run:

```text
flex
bison
pahole
```

Privilege check:

```text
sudo -n true
sudo: a password is required
```

The agent could not install missing host build dependencies non-interactively.

## Not Completed

The following validation steps remain open:

```text
baseline x86_64_defconfig completion
baseline vmlinux build
CONFIG_CAPSCHED=n olddefconfig and vmlinux build
CONFIG_CAPSCHED=y olddefconfig and vmlinux build
evidence that capsched.o is absent when disabled
evidence that capsched.o is built when enabled
```

## Required Next Action

Install the missing Linux build dependency `flex` at minimum, and likely the
normal kernel build dependencies for this host:

```text
flex
bison
libelf development headers
OpenSSL development headers
pahole / dwarves
```

Then rerun Validation 0002.

## Interpretation

The Slice 0A Linux patch is committed and statically clean, and it does not
touch scheduler behavior paths or `task_struct`. Build validation is not
complete because the host cannot generate Kconfig lexer sources without `flex`.

No runtime, security, or compatibility claim beyond static patch scope is
validated by this attempt.
