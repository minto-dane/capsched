#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# QEMU negative runtime harness for the test-only P5A-R 0010 ordinary-CFS
# denial overlay. This validates synthetic picker mechanics only; it is not a
# production execution lease or protection claim.

set -euo pipefail

ROOT="${DOMAINLEASE_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"

export SCHED_EXEC_LEASE_QEMU_MODE="${SCHED_EXEC_LEASE_QEMU_MODE:-on}"
export SCHED_EXEC_LEASE_QEMU_ENABLE_CFS_DENY_TEST=1
export SCHED_EXEC_LEASE_QEMU_EXPECT_NEGATIVE=1
export SCHED_EXEC_LEASE_QEMU_WORKLOAD_MODE=negative
export SCHED_EXEC_LEASE_QEMU_WORKLOAD_SRC="$ROOT/capsched/capsched-models/validation/workloads/sched_exec_lease_negative_workload.c"
export SCHED_EXEC_LEASE_QEMU_BUILD="${SCHED_EXEC_LEASE_QEMU_BUILD:-$ROOT/build/linux-l0-sched-exec-lease-on-p5a-r-0010-negative-qemu-x86_64}"
export SCHED_EXEC_LEASE_QEMU_OUT_ROOT="${SCHED_EXEC_LEASE_QEMU_OUT_ROOT:-$ROOT/build/qemu/sched-exec-lease-p5a-r-0010-negative}"
export SCHED_EXEC_LEASE_QEMU_TIMEOUT="${SCHED_EXEC_LEASE_QEMU_TIMEOUT:-240}"
export SCHED_EXEC_LEASE_QEMU_SMP="${SCHED_EXEC_LEASE_QEMU_SMP:-2}"
export SCHED_EXEC_LEASE_QEMU_ENABLE_FUNCTION_TRACER=0

exec "$ROOT/capsched/capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh"
