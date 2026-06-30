#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Build a central source-only project overlay ledger from the project source-map
# drift checker output. This normalizes heterogeneous source-map rows into an
# overlay shape; it does not create authority, monitor verification, runtime
# coverage, ABI approval, behavior changes, or production protection evidence.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
OUT_ROOT=${CAPSCHED_PROJECT_OVERLAY_OUT:-"$WORKSPACE_DIR/build/traceability-overlay"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

DRIFT_JSON=${CAPSCHED_PROJECT_DRIFT_JSON:-}
OVERLAY_JSON="$OUT_DIR/project-overlay-ledger.json"
OVERLAY_TSV="$OUT_DIR/project-overlay-ledger.tsv"
RECHECK_TSV="$OUT_DIR/semantic-recheck.tsv"
GAP_TSV="$OUT_DIR/gaps.tsv"
SUMMARY="$OUT_DIR/summary.txt"
METADATA="$OUT_DIR/metadata.txt"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

find_latest_project_drift_json()
{
	local root="$WORKSPACE_DIR/build/traceability-project-drift"
	[ -d "$root" ] || die "no project drift build directory found"
	find "$root" -mindepth 2 -maxdepth 2 -name project-anchor-ledger.json | sort | tail -n 1
}

write_metadata()
{
	{
		printf 'builder=build-project-overlay-ledger.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'drift_json=%s\n' "$DRIFT_JSON"
		printf 'schema=capsched-models/traceability/project-overlay-ledger-row-schema-v1.json\n'
		printf 'source_only=true\n'
		printf 'requires_privilege=false\n'
		printf 'writes_tracefs=false\n'
		printf 'attaches_probes=false\n'
		printf 'modifies_linux=false\n'
		printf 'public_tracepoint_abi=false\n'
		printf 'authority_claim=false\n'
		printf 'monitor_verified=false\n'
		printf 'protection_claim=false\n'
		printf 'semantic_validation=false\n'
	} > "$METADATA"
}

build_overlay()
{
	DRIFT_JSON="$DRIFT_JSON" OVERLAY_JSON="$OVERLAY_JSON" OVERLAY_TSV="$OVERLAY_TSV" RECHECK_TSV="$RECHECK_TSV" GAP_TSV="$GAP_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
from pathlib import Path

drift_json = Path(os.environ["DRIFT_JSON"])
overlay_json = Path(os.environ["OVERLAY_JSON"])
overlay_tsv = Path(os.environ["OVERLAY_TSV"])
recheck_tsv = Path(os.environ["RECHECK_TSV"])
gap_tsv = Path(os.environ["GAP_TSV"])
summary_path = Path(os.environ["SUMMARY"])

rows = json.loads(drift_json.read_text())

def boolish_false(value):
    return value is False or value == "false"

def confidence_for(row):
    if row["drift_status"] == "ok" and row["match_kind"] in {"symbol", "pattern"}:
        return "high"
    if row["drift_status"] == "ok":
        return "medium"
    return "low"

def status_for(row):
    if row["drift_status"] == "gap":
        return "gap"
    if row["drift_status"] == "ok":
        return "active"
    return "needs_semantic_recheck"

def next_action_for(row):
    if row["drift_status"] == "gap":
        return "preserve_gap"
    if row["drift_status"] == "ok":
        return "normalize_only"
    return "semantic_recheck"

def linux_id_for(i):
    return f"LINUX-PROJECT-{i:04d}"

safety_violations = []
overlay_rows = []

for i, row in enumerate(rows, start=1):
    for key in ("source_only", "authority_claim", "monitor_verified", "protection_claim"):
        expected = "true" if key == "source_only" else "false"
        if str(row.get(key)).lower() != expected:
            safety_violations.append({
                "row_id": row.get("row_id"),
                "key": key,
                "actual": row.get(key),
                "expected": expected,
            })

    linux_id = linux_id_for(i)
    overlay_rows.append({
        "row_id": f"overlay-project-source-map-{i:04d}",
        "map_version": "v1",
        "mapped_on": "2026-06-30",
        "n_ids": ["N-109"],
        "artifact_paths": [row["source_artifact"]],
        "relation": "anchors",
        "evidence_class": "source_only",
        "source_context": {
            "input_row_id": row["row_id"],
            "input_anchor_id": row["anchor_id"],
            "source_context": row["context"],
            "extraction_kind": row["extraction_kind"],
            "forbidden_upgrade": row["forbidden_upgrade"],
        },
        "semantic_ids": {
            "req": [],
            "thr": [],
            "inv": [],
            "des": ["ADR-0007", "ADR-0008"],
            "model": [],
            "val": ["capsched-models/validation/0080-project-source-map-drift-checker-result.md"],
            "linux": [linux_id],
            "patch": [],
            "claim": [],
        },
        "long_horizon": {
            "target_layer": "unspecified_by_normalizer",
            "long_horizon_invariant": "source anchors are traceability, not authority",
            "future_monitor_responsibility": "must be supplied by layer-specific design, not inferred from source maps",
            "linux_placeholder_status": "source_only",
            "forbidden_shortcuts": [
                "source_anchor_as_authority",
                "ok_row_as_semantic_validation",
                "missing_anchor_as_obligation_removal",
            ],
        },
        "linux_anchors": [{
            "linux_id": linux_id,
            "source_path": row["source_path"],
            "symbol_or_pattern": row["symbol_or_pattern"],
            "line_or_range": row["line_or_range"],
            "match_kind": row["match_kind"],
            "anchor_kind": row["anchor_kind"],
            "extraction_kind": row["extraction_kind"],
            "recorded_commit": row["recorded_commit"],
            "current_commit": row["current_commit"],
            "recorded_blob_oid": row["recorded_blob_oid"],
            "current_blob_oid": row["current_blob_oid"],
            "git_object_type": row["git_object_type"],
            "path_exists": row["path_exists"],
            "pattern_present": row["pattern_present"],
            "drift_status": row["drift_status"],
            "reason": row["reason"],
            "semantic_recheck_required": row["semantic_recheck_required"],
        }],
        "supported_claims": [],
        "not_supported_claims": [
            "source anchors provide authority",
            "path/pattern ok implies semantic validation",
            "monitor verification occurred",
            "runtime coverage occurred",
            "production protection exists",
        ],
        "safety_flags": {
            "authority_claim": False,
            "monitor_verified": False,
            "protection_claim": False,
            "behavior_change": False,
            "public_abi": False,
        },
        "confidence": confidence_for(row),
        "status": status_for(row),
        "next_action": next_action_for(row),
    })

overlay_json.write_text(json.dumps(overlay_rows, indent=2, sort_keys=True) + "\n")

tsv_fields = [
    "row_id",
    "artifact_path",
    "linux_id",
    "source_path",
    "symbol_or_pattern",
    "line_or_range",
    "match_kind",
    "drift_status",
    "status",
    "next_action",
    "confidence",
]

with overlay_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=tsv_fields, delimiter="\t")
    writer.writeheader()
    for row in overlay_rows:
        anchor = row["linux_anchors"][0]
        writer.writerow({
            "row_id": row["row_id"],
            "artifact_path": row["artifact_paths"][0],
            "linux_id": anchor["linux_id"],
            "source_path": anchor["source_path"],
            "symbol_or_pattern": anchor["symbol_or_pattern"],
            "line_or_range": anchor["line_or_range"],
            "match_kind": anchor["match_kind"],
            "drift_status": anchor["drift_status"],
            "status": row["status"],
            "next_action": row["next_action"],
            "confidence": row["confidence"],
        })

def write_subset(path, selected):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=tsv_fields, delimiter="\t")
        writer.writeheader()
        for row in selected:
            anchor = row["linux_anchors"][0]
            writer.writerow({
                "row_id": row["row_id"],
                "artifact_path": row["artifact_paths"][0],
                "linux_id": anchor["linux_id"],
                "source_path": anchor["source_path"],
                "symbol_or_pattern": anchor["symbol_or_pattern"],
                "line_or_range": anchor["line_or_range"],
                "match_kind": anchor["match_kind"],
                "drift_status": anchor["drift_status"],
                "status": row["status"],
                "next_action": row["next_action"],
                "confidence": row["confidence"],
            })

write_subset(recheck_tsv, [row for row in overlay_rows if row["status"] == "needs_semantic_recheck"])
write_subset(gap_tsv, [row for row in overlay_rows if row["status"] == "gap"])

counts = {}
match_counts = {}
for row in overlay_rows:
    anchor = row["linux_anchors"][0]
    counts[anchor["drift_status"]] = counts.get(anchor["drift_status"], 0) + 1
    match_counts[anchor["match_kind"]] = match_counts.get(anchor["match_kind"], 0) + 1

summary_path.write_text(
    "\n".join([
        f"input_rows={len(rows)}",
        f"overlay_rows={len(overlay_rows)}",
        f"ok_rows={counts.get('ok', 0)}",
        f"gap_rows={counts.get('gap', 0)}",
        f"path_changed_rows={counts.get('path_changed', 0)}",
        f"symbol_missing_rows={counts.get('symbol_missing', 0)}",
        f"pattern_missing_rows={counts.get('pattern_missing', 0)}",
        f"semantic_recheck_required_rows={counts.get('semantic_recheck_required', 0)}",
        f"needs_semantic_recheck_rows={sum(1 for row in overlay_rows if row['status'] == 'needs_semantic_recheck')}",
        f"path_only_rows={match_counts.get('path_only', 0)}",
        f"line_only_rows={match_counts.get('line_only', 0)}",
        f"symbol_rows={match_counts.get('symbol', 0)}",
        f"pattern_rows={match_counts.get('pattern', 0)}",
        f"gap_match_rows={match_counts.get('gap', 0)}",
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
        "semantic_validation=false",
        "n_series_rewrite=false",
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
	[ -n "$DRIFT_JSON" ] || DRIFT_JSON=$(find_latest_project_drift_json)
	[ -f "$DRIFT_JSON" ] || die "project drift JSON not found: $DRIFT_JSON"

	mkdir -p "$OUT_DIR"
	write_metadata
	build_overlay

	printf 'Project overlay ledger written to %s\n' "$OUT_DIR"
}

main "$@"
