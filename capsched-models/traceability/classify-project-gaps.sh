#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Classify preserved project overlay gap rows into semantic groups. This is a
# source-only traceability step. It does not resolve gaps, modify Linux, attach
# probes, write tracefs, approve ABI, create authority, verify the monitor, or
# claim protection.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
OUT_ROOT=${CAPSCHED_GAP_CLASSIFICATION_OUT:-"$WORKSPACE_DIR/build/traceability-gap-classification"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

OVERLAY_JSON=${CAPSCHED_PROJECT_OVERLAY_JSON:-}
GAP_TSV=${CAPSCHED_GAP_PRESERVATION_TSV:-}
ROW_JSON="$OUT_DIR/gap-classification-rows.json"
ROW_TSV="$OUT_DIR/gap-classification-rows.tsv"
GROUP_JSON="$OUT_DIR/gap-classification-groups.json"
GROUP_TSV="$OUT_DIR/gap-classification-groups.tsv"
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

find_latest_gap_tsv()
{
	local root="$WORKSPACE_DIR/build/semantic-recheck"
	[ -d "$root" ] || die "no semantic recheck build directory found"
	find "$root" -mindepth 2 -maxdepth 2 -name gap-preservation.tsv | sort | tail -n 1
}

write_metadata()
{
	{
		printf 'builder=classify-project-gaps.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'overlay_json=%s\n' "$OVERLAY_JSON"
		printf 'gap_tsv=%s\n' "$GAP_TSV"
		printf 'schema=capsched-models/traceability/project-gap-classification-schema-v1.json\n'
		printf 'workflow=capsched-models/traceability/gap-classification-workflow-v1.md\n'
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

classify_gaps()
{
	OVERLAY_JSON="$OVERLAY_JSON" GAP_TSV="$GAP_TSV" ROW_JSON="$ROW_JSON" ROW_TSV="$ROW_TSV" GROUP_JSON="$GROUP_JSON" GROUP_TSV="$GROUP_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
import re
from collections import OrderedDict
from pathlib import Path

overlay_json = Path(os.environ["OVERLAY_JSON"])
gap_tsv = Path(os.environ["GAP_TSV"])
row_json = Path(os.environ["ROW_JSON"])
row_tsv = Path(os.environ["ROW_TSV"])
group_json = Path(os.environ["GROUP_JSON"])
group_tsv = Path(os.environ["GROUP_TSV"])
summary_path = Path(os.environ["SUMMARY"])

overlay_rows = json.loads(overlay_json.read_text())
overlay_by_id = {row["row_id"]: row for row in overlay_rows}

with gap_tsv.open(newline="") as f:
    gap_items = list(csv.DictReader(f, delimiter="\t"))

GAPS = {
    "004": {
        "semantic_gap_id": "DCGAP-004-REQUEST-ENVELOPE",
        "semantic_gap_name": "direct-call request envelope builder",
        "gap_class": "future_linux_anchor",
        "source_layer": "direct_call_linux_placeholder",
        "severity": "high",
        "required_resolution": "Define and anchor a Linux internal request-envelope builder only after monitor-owned request schema, bounded copy, replay key, and canonical monitor-image rules are fixed.",
        "blocked_claims": ["direct-call admission exists", "Linux-built envelope is canonical authority", "monitor verification occurred", "production protection exists"],
        "external_monitor_dependency": True,
    },
    "005": {
        "semantic_gap_id": "DCGAP-005-DIRECT-CALL-ENTRY",
        "semantic_gap_name": "direct-call wrapper and arch backend",
        "gap_class": "future_linux_anchor",
        "source_layer": "direct_call_linux_placeholder",
        "severity": "high",
        "required_resolution": "Define arch-independent wrapper plus arch backend only after monitor entry semantics, register/memory clobber rules, failure ordering, and replay handling are fixed.",
        "blocked_claims": ["direct-call ABI exists", "wrapper return is monitor approval", "monitor verification occurred", "production protection exists"],
        "external_monitor_dependency": True,
    },
    "006": {
        "semantic_gap_id": "DCGAP-006-SCHEMA-NEGOTIATION",
        "semantic_gap_name": "schema negotiation query path",
        "gap_class": "future_linux_anchor",
        "source_layer": "direct_call_linux_placeholder",
        "severity": "high",
        "required_resolution": "Define a Linux query path only after monitor-owned schema negotiation, critical-field downgrade rejection, and compatibility rules are fixed.",
        "blocked_claims": ["Linux can decide schema acceptance", "schema coverage is ABI approval", "monitor verification occurred", "production protection exists"],
        "external_monitor_dependency": True,
    },
    "007": {
        "semantic_gap_id": "DCGAP-007-RESPONSE-SHADOW",
        "semantic_gap_name": "response-handle shadow refresh",
        "gap_class": "future_linux_anchor",
        "source_layer": "direct_call_linux_placeholder",
        "severity": "high",
        "required_resolution": "Define a monitor-backed response-handle shadow refresh path only after response handle lifetime, epoch, revoke, and timeout semantics are fixed.",
        "blocked_claims": ["timeout refreshes authority", "Linux-visible shadow is authority", "monitor verification occurred", "production protection exists"],
        "external_monitor_dependency": True,
    },
    "008": {
        "semantic_gap_id": "DCGAP-008-CONTROL-REVOKE",
        "semantic_gap_name": "control revoke lane",
        "gap_class": "future_linux_anchor",
        "source_layer": "direct_call_linux_placeholder",
        "severity": "high",
        "required_resolution": "Define a control/revoke lane only after priority, replay budget, Domain epoch, and revoke completion ordering are fixed.",
        "blocked_claims": ["control priority bypasses replay budget", "Linux control lane mints revoke authority", "monitor verification occurred", "production protection exists"],
        "external_monitor_dependency": True,
    },
    "009": {
        "semantic_gap_id": "DCGAP-009-FAILURE-INJECTION",
        "semantic_gap_name": "test-only failure-injection surface",
        "gap_class": "future_test_anchor",
        "source_layer": "direct_call_test_surface",
        "severity": "medium",
        "required_resolution": "Define a KUnit or test-only fault-injection surface that cannot affect live monitor or Linux decisions.",
        "blocked_claims": ["fault injection changes live decisions", "test hook is production control path", "runtime coverage occurred", "production protection exists"],
        "external_monitor_dependency": False,
    },
    "010": {
        "semantic_gap_id": "DCGAP-010-TRACE-OBSERVATION",
        "semantic_gap_name": "trace-only observation surface",
        "gap_class": "trace_plan_row",
        "source_layer": "trace_observation_plan",
        "severity": "medium",
        "required_resolution": "Keep trace observation as existing-event or dynamic-probe plan until a separate privileged runbook executes it; do not add public tracepoint ABI by default.",
        "blocked_claims": ["tracefs plan is runtime coverage", "new tracepoint ABI is approved", "trace observation is authority", "production protection exists"],
        "external_monitor_dependency": True,
    },
}

def suffix_from(value):
    if not value:
        return None
    for pattern in (r"direct-call-inventory-(\d{3})", r"LINUX-DIRECTCALL-(\d{3})", r"overlay-direct-call-inventory-(\d{3})"):
        m = re.search(pattern, value)
        if m:
            return m.group(1)
    return None

def classify(row):
    context = row.get("source_context", {})
    anchor = row["linux_anchors"][0]
    candidates = [
        context.get("input_anchor_id"),
        context.get("source_context"),
        anchor.get("linux_id"),
        anchor.get("symbol_or_pattern"),
    ]
    suffix = None
    for candidate in candidates:
        suffix = suffix_from(candidate)
        if suffix:
            break
    if suffix in GAPS:
        return suffix, GAPS[suffix]
    return "UNKNOWN", {
        "semantic_gap_id": "UNKNOWN-GAP",
        "semantic_gap_name": "unknown preserved gap",
        "gap_class": "unknown_gap",
        "source_layer": "unknown",
        "severity": "high",
        "required_resolution": "Manually inspect this row and repair the source-map or classifier before implementation use.",
        "blocked_claims": ["missing anchors remove semantic obligations", "production protection exists"],
        "external_monitor_dependency": False,
    }

classified_rows = []
safety_violations = []

for idx, item in enumerate(gap_items, start=1):
    overlay_id = item["overlay_row_id"]
    row = overlay_by_id.get(overlay_id)
    if row is None:
        raise SystemExit(f"gap row {overlay_id} not found in overlay ledger")

    flags = row.get("safety_flags", {})
    for key in ("authority_claim", "monitor_verified", "protection_claim", "behavior_change", "public_abi"):
        if flags.get(key) is not False:
            safety_violations.append({"row_id": overlay_id, "key": key, "actual": flags.get(key)})

    anchor = row["linux_anchors"][0]
    suffix, gap = classify(row)
    classified_rows.append({
        "gap_row_id": f"GAPROW-{idx:04d}",
        "overlay_row_id": overlay_id,
        "linux_id": anchor["linux_id"],
        "artifact_path": row["artifact_paths"][0],
        "semantic_gap_id": gap["semantic_gap_id"],
        "semantic_gap_name": gap["semantic_gap_name"],
        "gap_class": gap["gap_class"],
        "source_layer": gap["source_layer"],
        "anchor_kind": anchor["anchor_kind"],
        "source_path": anchor["source_path"],
        "symbol_or_pattern": anchor["symbol_or_pattern"],
        "required_resolution": gap["required_resolution"],
        "blocked_claims": gap["blocked_claims"],
        "external_monitor_dependency": gap["external_monitor_dependency"],
        "duplicate_group_key": suffix,
        "severity": gap["severity"],
        "source_only": True,
        "semantic_validation": False,
        "authority_claim": False,
        "monitor_verified": False,
        "protection_claim": False,
    })

groups = OrderedDict()
for row in classified_rows:
    key = row["semantic_gap_id"]
    groups.setdefault(key, {
        "semantic_gap_id": key,
        "semantic_gap_name": row["semantic_gap_name"],
        "gap_class": row["gap_class"],
        "source_layer": row["source_layer"],
        "severity": row["severity"],
        "required_resolution": row["required_resolution"],
        "blocked_claims": row["blocked_claims"],
        "external_monitor_dependency": row["external_monitor_dependency"],
        "row_count": 0,
        "representative_rows": [],
        "source_only": True,
        "semantic_validation": False,
        "authority_claim": False,
        "monitor_verified": False,
        "protection_claim": False,
    })
    groups[key]["row_count"] += 1
    groups[key]["representative_rows"].append(row["overlay_row_id"])

group_rows = list(groups.values())

row_json.write_text(json.dumps({
    "schema_version": 1,
    "source_overlay": str(overlay_json),
    "source_gap_tsv": str(gap_tsv),
    "rows": classified_rows,
}, indent=2, sort_keys=True) + "\n")

group_json.write_text(json.dumps({
    "schema_version": 1,
    "source_overlay": str(overlay_json),
    "source_gap_tsv": str(gap_tsv),
    "groups": group_rows,
}, indent=2, sort_keys=True) + "\n")

row_fields = [
    "gap_row_id", "overlay_row_id", "linux_id", "semantic_gap_id",
    "gap_class", "source_layer", "anchor_kind", "source_path",
    "symbol_or_pattern", "duplicate_group_key", "severity",
    "external_monitor_dependency",
]
with row_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=row_fields, delimiter="\t")
    writer.writeheader()
    for row in classified_rows:
        writer.writerow({key: row[key] for key in row_fields})

group_fields = [
    "semantic_gap_id", "semantic_gap_name", "gap_class", "source_layer",
    "severity", "row_count", "external_monitor_dependency",
]
with group_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=group_fields, delimiter="\t")
    writer.writeheader()
    for row in group_rows:
        writer.writerow({key: row[key] for key in group_fields})

group_class_counts = {}
for group in group_rows:
    group_class_counts[group["gap_class"]] = group_class_counts.get(group["gap_class"], 0) + 1

row_class_counts = {}
for row in classified_rows:
    row_class_counts[row["gap_class"]] = row_class_counts.get(row["gap_class"], 0) + 1

duplicate_groups = sum(1 for group in group_rows if group["row_count"] > 1)
unknown_rows = row_class_counts.get("unknown_gap", 0)

summary_path.write_text(
    "\n".join([
        f"gap_rows={len(classified_rows)}",
        f"semantic_gap_groups={len(group_rows)}",
        f"duplicate_groups={duplicate_groups}",
        f"future_linux_anchor_rows={row_class_counts.get('future_linux_anchor', 0)}",
        f"future_linux_anchor_groups={group_class_counts.get('future_linux_anchor', 0)}",
        f"future_test_anchor_rows={row_class_counts.get('future_test_anchor', 0)}",
        f"future_test_anchor_groups={group_class_counts.get('future_test_anchor', 0)}",
        f"trace_plan_rows={row_class_counts.get('trace_plan_row', 0)}",
        f"trace_plan_groups={group_class_counts.get('trace_plan_row', 0)}",
        f"external_monitor_anchor_rows={row_class_counts.get('external_monitor_anchor', 0)}",
        f"external_monitor_anchor_groups={group_class_counts.get('external_monitor_anchor', 0)}",
        f"unsupported_extraction_rows={row_class_counts.get('unsupported_extraction', 0)}",
        f"unsupported_extraction_groups={group_class_counts.get('unsupported_extraction', 0)}",
        f"unknown_gap_rows={unknown_rows}",
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
        "implementation_approval=false",
    ]) + "\n"
)

if safety_violations or unknown_rows:
    for violation in safety_violations:
        print("safety violation:", violation, flush=True)
    if unknown_rows:
        print(f"unknown gap rows: {unknown_rows}", flush=True)
    raise SystemExit(2)
PY
}

main()
{
	[ -n "$OVERLAY_JSON" ] || OVERLAY_JSON=$(find_latest_overlay_json)
	[ -n "$GAP_TSV" ] || GAP_TSV=$(find_latest_gap_tsv)
	[ -f "$OVERLAY_JSON" ] || die "project overlay JSON not found: $OVERLAY_JSON"
	[ -f "$GAP_TSV" ] || die "gap preservation TSV not found: $GAP_TSV"

	mkdir -p "$OUT_DIR"
	write_metadata
	classify_gaps

	printf 'Project gap classification written to %s\n' "$OUT_DIR"
}

main "$@"
