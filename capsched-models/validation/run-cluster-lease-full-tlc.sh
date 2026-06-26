#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Run the full ClusterLease integration TLC model outside the chat session.
# Intended to be launched by systemd --user because the full state space is
# large and should not require interactive supervision.

set -euo pipefail

ROOT=/media/nia/scsiusb/dev/linux-cap
MODEL_DIR="$ROOT/capsched/capsched-models/formal/0006-cluster-lease-compilation-model"
BUILD="$ROOT/build"
LOG_DIR="$BUILD/logs"
TLC_ROOT="$BUILD/tlc"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="cluster-lease-full-$STAMP"
META_DIR="$TLC_ROOT/$RUN_ID"
LOG="$LOG_DIR/$RUN_ID.log"
TLA_JAR="${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}"
WORKERS="${WORKERS:-8}"
FP_INDEX="${FP_INDEX:-0}"

mkdir -p "$LOG_DIR" "$META_DIR"
exec > >(tee -a "$LOG") 2>&1

say()
{
	printf '\n[%s] %s\n' "$(date -Is)" "$*"
}

say "ClusterLease full integration TLC run started"
say "model dir: $MODEL_DIR"
say "metadir: $META_DIR"
say "log: $LOG"
say "workers: $WORKERS"
say "fingerprint index: $FP_INDEX"

cd "$MODEL_DIR"

java -XX:+UseParallelGC \
	-cp "$TLA_JAR" \
	tlc2.TLC \
	-workers "$WORKERS" \
	-fp "$FP_INDEX" \
	-metadir "$META_DIR" \
	ClusterLease.tla

say "ClusterLease full integration TLC run completed"
