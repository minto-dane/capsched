#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Build a source-only semantic recheck queue from the central project overlay
# ledger. This queues rows for review; it does not perform the semantic review
# and does not create authority, monitor verification, runtime coverage, ABI
# approval, behavior changes, or production protection evidence.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
OUT_ROOT=${CAPSCHED_SEMANTIC_RECHECK_OUT:-"$WORKSPACE_DIR/build/semantic-recheck"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

OVERLAY_JSON=${CAPSCHED_PROJECT_OVERLAY_JSON:-}
QUEUE_JSON="$OUT_DIR/recheck-queue.json"
QUEUE_TSV="$OUT_DIR/recheck-queue.tsv"
GAP_TSV="$OUT_DIR/gap-preservation.tsv"
SUMMARY="$OUT_DIR/summary.txt"
METADATA="$OUT_DIR/metadata.txt"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

find_latest_overlay_json()
{
	local root="$WORKSPACE_DIR/build/traceability-overlay"
	[ -d "$root" ] || die "no project overlay build directory found"
	find "$root" -mindepth 2 -maxdepth 2 -name project-overlay-ledger.json | sort | tail -n 1
}

write_metadata()
{
	{
		printf 'builder=build-semantic-recheck-queue.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'overlay_json=%s\n' "$OVERLAY_JSON"
		printf 'workflow=capsched-models/traceability/semantic-recheck-workflow-v1.md\n'
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

build_queue()
{
	OVERLAY_JSON="$OVERLAY_JSON" QUEUE_JSON="$QUEUE_JSON" QUEUE_TSV="$QUEUE_TSV" GAP_TSV="$GAP_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
from pathlib import Path

overlay_json = Path(os.environ["OVERLAY_JSON"])
queue_json = Path(os.environ["QUEUE_JSON"])
queue_tsv = Path(os.environ["QUEUE_TSV"])
gap_tsv = Path(os.environ["GAP_TSV"])
summary_path = Path(os.environ["SUMMARY"])

overlay_rows = json.loads(overlay_json.read_text())

def classify(anchor):
    if anchor["drift_status"] == "gap":
        return "gap_or_plan", "preserve_gap", "low"
    if anchor["match_kind"] == "line_only":
        return "line_only_anchor", "replace_with_symbol_or_literal_pattern", "medium"
    if anchor["drift_status"] == "symbol_missing":
        return "symbol_missing", "find_rename_move_or_semantic_removal", "high"
    if anchor["drift_status"] == "pattern_missing":
        return "pattern_missing", "replace_descriptive_phrase_or_literal_predicate", "high"
    if anchor["drift_status"] == "semantic_recheck_required":
        return "semantic_recheck_required", "manual_semantic_review", "medium"
    return "unknown_recheck", "manual_triage", "medium"

queue = []
gaps = []
safety_violations = []

for row in overlay_rows:
    flags = row.get("safety_flags", {})
    for key in ("authority_claim", "monitor_verified", "protection_claim", "behavior_change", "public_abi"):
        if flags.get(key) is not False:
            safety_violations.append({
                "row_id": row.get("row_id"),
                "key": key,
                "actual": flags.get(key),
                "expected": False,
            })

    anchor = row["linux_anchors"][0]
    if row["status"] == "active":
        continue
    recheck_class, recommended_action, priority = classify(anchor)
    item = {
        "recheck_id": f"RECHECK-{len(queue)+len(gaps)+1:04d}",
        "overlay_row_id": row["row_id"],
        "linux_id": anchor["linux_id"],
        "artifact_path": row["artifact_paths"][0],
        "source_context": row["source_context"]["source_context"],
        "source_path": anchor["source_path"],
        "symbol_or_pattern": anchor["symbol_or_pattern"],
        "line_or_range": anchor["line_or_range"],
        "match_kind": anchor["match_kind"],
        "drift_status": anchor["drift_status"],
        "reason": anchor["reason"],
        "recheck_class": recheck_class,
        "recommended_action": recommended_action,
        "priority": priority,
        "allowed_outcomes": [
            "rechecked_anchor",
            "intentional_gap",
            "deprecated_anchor",
            "needs_model_update",
        ],
        "forbidden_claims": [
            "authority",
            "monitor_verification",
            "runtime_coverage",
            "production_protection",
        ],
        "source_only": True,
        "semantic_validation": False,
        "authority_claim": False,
        "monitor_verified": False,
        "protection_claim": False,
    }
    if row["status"] == "gap":
        gaps.append(item)
    else:
        queue.append(item)

queue_json.write_text(json.dumps({
    "schema_version": 1,
    "source_overlay": str(overlay_json),
    "workflow": "capsched-models/traceability/semantic-recheck-workflow-v1.md",
    "semantic_recheck_items": queue,
    "gap_items": gaps,
}, indent=2, sort_keys=True) + "\n")

fields = [
    "recheck_id",
    "overlay_row_id",
    "linux_id",
    "artifact_path",
    "source_path",
    "symbol_or_pattern",
    "line_or_range",
    "match_kind",
    "drift_status",
    "recheck_class",
    "recommended_action",
    "priority",
]

def write_tsv(path, items):
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        for item in items:
            writer.writerow({key: item[key] for key in fields})

write_tsv(queue_tsv, queue)
write_tsv(gap_tsv, gaps)

class_counts = {}
for item in queue + gaps:
    class_counts[item["recheck_class"]] = class_counts.get(item["recheck_class"], 0) + 1

summary_path.write_text(
    "\n".join([
        f"overlay_rows={len(overlay_rows)}",
        f"semantic_recheck_items={len(queue)}",
        f"gap_items={len(gaps)}",
        f"line_only_anchor_items={class_counts.get('line_only_anchor', 0)}",
        f"symbol_missing_items={class_counts.get('symbol_missing', 0)}",
        f"pattern_missing_items={class_counts.get('pattern_missing', 0)}",
        f"gap_or_plan_items={class_counts.get('gap_or_plan', 0)}",
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
	[ -n "$OVERLAY_JSON" ] || OVERLAY_JSON=$(find_latest_overlay_json)
	[ -f "$OVERLAY_JSON" ] || die "project overlay JSON not found: $OVERLAY_JSON"

	mkdir -p "$OUT_DIR"
	write_metadata
	build_queue

	printf 'Semantic recheck queue written to %s\n' "$OUT_DIR"
}

main "$@"
