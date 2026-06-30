#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Source-only direct-call overlay drift checker.
#
# This checker consumes the N-106 overlay seed and classifies Linux source
# anchor drift without modifying Linux, requiring root, writing tracefs,
# attaching probes, creating ABI, or making authority/protection claims.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
LINUX_DIR=${CAPSCHED_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
OUT_ROOT=${CAPSCHED_DRIFT_OUT:-"$WORKSPACE_DIR/build/traceability-drift"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

SEED_JSON=${CAPSCHED_OVERLAY_SEED:-}
DRIFT_TSV="$OUT_DIR/drift-ledger.tsv"
DRIFT_JSON="$OUT_DIR/drift-ledger.json"
STALE_TSV="$OUT_DIR/stale-or-gap.tsv"
SUMMARY="$OUT_DIR/summary.txt"
METADATA="$OUT_DIR/metadata.txt"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_linux_tree()
{
	[ -d "$LINUX_DIR" ] || die "Linux tree not found: $LINUX_DIR"
	[ -d "$LINUX_DIR/.git" ] || die "Linux tree is not a Git repository: $LINUX_DIR"
}

find_latest_seed()
{
	local root="$WORKSPACE_DIR/build/direct-call-inventory"
	[ -d "$root" ] || die "no direct-call inventory build directory found"
	find "$root" -mindepth 2 -maxdepth 2 -name overlay-seed.json | sort | tail -n 1
}

write_metadata()
{
	local head
	local branch
	head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	branch=$(git -C "$LINUX_DIR" branch --show-current)

	{
		printf 'checker=check-direct-call-overlay-drift.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'seed_json=%s\n' "$SEED_JSON"
		printf 'linux_dir=%s\n' "$LINUX_DIR"
		printf 'linux_branch=%s\n' "$branch"
		printf 'linux_head=%s\n' "$head"
		printf 'source_only=true\n'
		printf 'requires_privilege=false\n'
		printf 'writes_tracefs=false\n'
		printf 'attaches_probes=false\n'
		printf 'modifies_linux=false\n'
		printf 'public_tracepoint_abi=false\n'
		printf 'authority_claim=false\n'
		printf 'monitor_verified=false\n'
		printf 'protection_claim=false\n'
	} > "$METADATA"
}

run_checker()
{
	SEED_JSON="$SEED_JSON" LINUX_DIR="$LINUX_DIR" DRIFT_TSV="$DRIFT_TSV" DRIFT_JSON="$DRIFT_JSON" STALE_TSV="$STALE_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
import subprocess
from pathlib import Path

seed_path = Path(os.environ["SEED_JSON"])
linux_dir = Path(os.environ["LINUX_DIR"])
drift_tsv = Path(os.environ["DRIFT_TSV"])
drift_json = Path(os.environ["DRIFT_JSON"])
stale_tsv = Path(os.environ["STALE_TSV"])
summary_path = Path(os.environ["SUMMARY"])

seed_rows = json.loads(seed_path.read_text())

def git_output(args):
    return subprocess.check_output(["git", "-C", str(linux_dir)] + args, text=True).strip()

linux_head = git_output(["rev-parse", "HEAD"])

def file_blob(path):
    try:
        return git_output(["rev-parse", f"HEAD:{path}"])
    except subprocess.CalledProcessError:
        return None

def path_exists(path):
    return path != "none" and (linux_dir / path).is_file()

def pattern_present(path, pattern):
    if path == "none" or pattern == "none":
        return False
    p = linux_dir / path
    if not p.is_file():
        return False
    return pattern in p.read_text(errors="replace")

safe_defaults = {
    "authority_claim": False,
    "monitor_verified": False,
    "protection_claim": False,
    "behavior_change": False,
    "public_abi": False,
}

drift_rows = []
safety_violations = []

for row in seed_rows:
    for key, expected in safe_defaults.items():
        if row.get("safety_flags", {}).get(key) is not expected:
            safety_violations.append({
                "row_id": row.get("row_id"),
                "key": key,
                "actual": row.get("safety_flags", {}).get(key),
                "expected": expected,
            })

    for anchor in row.get("linux_anchors", []):
        source_path = anchor.get("source_path", "none")
        pattern = anchor.get("symbol_or_pattern", "none")
        anchor_class = anchor.get("anchor_class", "unknown")
        previous = anchor.get("drift_status", "unknown")
        exists = path_exists(source_path)
        present = pattern_present(source_path, pattern)
        current_blob = file_blob(source_path) if exists else None
        recorded_blob = anchor.get("blob_oid")

        if anchor_class in {"future_gap", "trace_catalog_plan"} or source_path == "none":
            drift = "gap"
            reason = "gap_or_plan_anchor"
        elif not exists:
            drift = "path_changed"
            reason = "source_path_missing"
        elif not present:
            drift = "pattern_missing"
            reason = "symbol_or_pattern_missing"
        elif recorded_blob and current_blob and recorded_blob != current_blob:
            drift = "semantic_recheck_required"
            reason = "source_blob_changed_since_recorded_anchor"
        else:
            drift = "ok"
            reason = "path_pattern_and_blob_match_or_no_recorded_blob"

        drift_rows.append({
            "row_id": row.get("row_id"),
            "n_ids": ",".join(row.get("n_ids", [])),
            "linux_id": anchor.get("linux_id"),
            "source_path": source_path,
            "symbol_or_pattern": pattern,
            "anchor_class": anchor_class,
            "anchor_kind": anchor.get("anchor_kind"),
            "recorded_commit": anchor.get("last_checked_commit"),
            "current_commit": linux_head,
            "recorded_blob_oid": recorded_blob,
            "current_blob_oid": current_blob,
            "path_exists": str(exists).lower(),
            "pattern_present": str(present).lower(),
            "previous_drift_status": previous,
            "drift_status": drift,
            "reason": reason,
            "semantic_recheck_required": str(drift == "semantic_recheck_required").lower(),
            "source_only": "true",
            "authority_claim": "false",
            "monitor_verified": "false",
            "protection_claim": "false",
        })

fieldnames = [
    "row_id",
    "n_ids",
    "linux_id",
    "source_path",
    "symbol_or_pattern",
    "anchor_class",
    "anchor_kind",
    "recorded_commit",
    "current_commit",
    "recorded_blob_oid",
    "current_blob_oid",
    "path_exists",
    "pattern_present",
    "previous_drift_status",
    "drift_status",
    "reason",
    "semantic_recheck_required",
    "source_only",
    "authority_claim",
    "monitor_verified",
    "protection_claim",
]

with drift_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
    writer.writeheader()
    writer.writerows(drift_rows)

drift_json.write_text(json.dumps(drift_rows, indent=2, sort_keys=True) + "\n")

stale_rows = [
    row for row in drift_rows
    if row["drift_status"] != "ok"
]
with stale_tsv.open("w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["row_id", "linux_id", "source_path", "drift_status", "reason"])
    for row in stale_rows:
        writer.writerow([
            row["row_id"],
            row["linux_id"],
            row["source_path"],
            row["drift_status"],
            row["reason"],
        ])

counts = {}
for row in drift_rows:
    counts[row["drift_status"]] = counts.get(row["drift_status"], 0) + 1

summary_path.write_text(
    "\n".join([
        f"seed_rows={len(seed_rows)}",
        f"anchor_rows={len(drift_rows)}",
        f"ok_rows={counts.get('ok', 0)}",
        f"gap_rows={counts.get('gap', 0)}",
        f"path_changed_rows={counts.get('path_changed', 0)}",
        f"pattern_missing_rows={counts.get('pattern_missing', 0)}",
        f"semantic_recheck_required_rows={counts.get('semantic_recheck_required', 0)}",
        f"safety_flag_violations={len(safety_violations)}",
        "source_only=true",
        "requires_privilege=false",
        "writes_tracefs=false",
        "attaches_probes=false",
        "modifies_linux=false",
        "public_tracepoint_abi=false",
        "authority_claim=false",
        "monitor_verified=false",
        "protection_claim=false",
    ]) + "\n"
)

if safety_violations:
    for violation in safety_violations:
        print("safety violation:", violation, flush=True)
    raise SystemExit(2)
PY
}

main()
{
	require_linux_tree
	[ -n "$SEED_JSON" ] || SEED_JSON=$(find_latest_seed)
	[ -f "$SEED_JSON" ] || die "overlay seed not found: $SEED_JSON"

	mkdir -p "$OUT_DIR"

	local before_head
	local after_head
	local before_status
	local after_status
	before_head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	before_status=$(git -C "$LINUX_DIR" status --short)

	write_metadata
	run_checker

	after_head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	after_status=$(git -C "$LINUX_DIR" status --short)
	[ "$before_head" = "$after_head" ] || die "Linux HEAD changed"
	[ "$before_status" = "$after_status" ] || die "Linux working tree status changed"

	printf 'Direct-call overlay drift check written to %s\n' "$OUT_DIR"
}

main "$@"
