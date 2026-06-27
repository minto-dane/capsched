#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
SRC="$ROOT/capsched/capsched-models/validation/workloads/slice0c_sched_workload.c"
OUT_DIR="${CAPSCHED_WORKLOAD_OUT_DIR:-$ROOT/build/workloads}"
OUT="$OUT_DIR/slice0c_sched_workload"

mkdir -p "$OUT_DIR"

gcc -O2 -Wall -Wextra -pthread "$SRC" -o "$OUT"

printf '%s\n' "$OUT"
