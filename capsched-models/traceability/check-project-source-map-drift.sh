#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Project-level source-map drift checker.
#
# This checker scans existing machine-readable source-map artifacts and the
# latest direct-call overlay seed, extracts mechanically recognizable Linux
# source anchors, and classifies path/pattern/blob drift. It is source-only and
# does not infer authority, monitor verification, runtime coverage, or
# production protection from source observations.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)
LINUX_DIR=${CAPSCHED_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
ANALYSIS_DIR=${CAPSCHED_ANALYSIS_DIR:-"$REPO_DIR/capsched-models/analysis"}
OUT_ROOT=${CAPSCHED_PROJECT_DRIFT_OUT:-"$WORKSPACE_DIR/build/traceability-project-drift"}
RUN_ID=${CAPSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

PROJECT_LEDGER_TSV="$OUT_DIR/project-anchor-ledger.tsv"
PROJECT_LEDGER_JSON="$OUT_DIR/project-anchor-ledger.json"
STALE_TSV="$OUT_DIR/stale-or-gap.tsv"
UNSUPPORTED_TSV="$OUT_DIR/unsupported-extractions.tsv"
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
	[ -d "$ANALYSIS_DIR" ] || die "analysis dir not found: $ANALYSIS_DIR"
}

write_metadata()
{
	local head
	local branch
	local status
	head=$(git -C "$LINUX_DIR" rev-parse HEAD)
	branch=$(git -C "$LINUX_DIR" branch --show-current)
	status=$(git -C "$LINUX_DIR" status --short)

	{
		printf 'checker=check-project-source-map-drift.sh\n'
		printf 'run_id=%s\n' "$RUN_ID"
		printf 'analysis_dir=%s\n' "$ANALYSIS_DIR"
		printf 'linux_dir=%s\n' "$LINUX_DIR"
		printf 'linux_branch=%s\n' "$branch"
		printf 'linux_head=%s\n' "$head"
		printf 'content_source=git_HEAD_objects\n'
		if [ -n "$status" ]; then
			printf 'linux_worktree_dirty=true\n'
		else
			printf 'linux_worktree_dirty=false\n'
		fi
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
	LINUX_DIR="$LINUX_DIR" ANALYSIS_DIR="$ANALYSIS_DIR" WORKSPACE_DIR="$WORKSPACE_DIR" PROJECT_LEDGER_TSV="$PROJECT_LEDGER_TSV" PROJECT_LEDGER_JSON="$PROJECT_LEDGER_JSON" STALE_TSV="$STALE_TSV" UNSUPPORTED_TSV="$UNSUPPORTED_TSV" SUMMARY="$SUMMARY" python3 - <<'PY'
import csv
import json
import os
import re
import subprocess
from pathlib import Path

linux_dir = Path(os.environ["LINUX_DIR"])
analysis_dir = Path(os.environ["ANALYSIS_DIR"])
workspace_dir = Path(os.environ["WORKSPACE_DIR"])
ledger_tsv = Path(os.environ["PROJECT_LEDGER_TSV"])
ledger_json = Path(os.environ["PROJECT_LEDGER_JSON"])
stale_tsv = Path(os.environ["STALE_TSV"])
unsupported_tsv = Path(os.environ["UNSUPPORTED_TSV"])
summary_path = Path(os.environ["SUMMARY"])

PATH_RE = re.compile(r"(?P<path>(?:Documentation|arch|block|drivers|fs|include|io_uring|kernel|mm|net|security|virt)/[A-Za-z0-9_./+-]+)(?::(?:(?P<line>[0-9][0-9A-Za-z_.-]*)|(?P<colon_symbol>[A-Za-z_][A-Za-z0-9_.$>:-]*)))?(?:\s+(?P<symbol>[A-Za-z_][A-Za-z0-9_.$>:-]*))?")

def git_output(args):
    return subprocess.check_output(["git", "-C", str(linux_dir)] + args, text=True).strip()

linux_head = git_output(["rev-parse", "HEAD"])

def git_maybe_output(args):
    try:
        return subprocess.check_output(["git", "-C", str(linux_dir)] + args, text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return None

def file_blob(path):
    if not path or path == "none":
        return None
    return git_maybe_output(["rev-parse", f"HEAD:{path}"])

def path_exists(path):
    if not path or path == "none":
        return False
    return git_maybe_output(["cat-file", "-e", f"HEAD:{path}"]) == ""

def object_type(path):
    if not path or path == "none":
        return None
    return git_maybe_output(["cat-file", "-t", f"HEAD:{path}"])

def head_text(path):
    if object_type(path) != "blob":
        return None
    return git_maybe_output(["show", f"HEAD:{path}"])

def pattern_present(path, pattern):
    if not pattern or pattern == "none":
        return None
    text = head_text(path)
    if text is None:
        return False
    return pattern in text

def candidate_files_with_pattern(files, pattern):
    found = []
    for f in files:
        if isinstance(f, str) and pattern_present(f, pattern) is True:
            found.append(f)
    return found

def classify(path, pattern=None, line_or_range=None, match_kind="path", recorded_commit=None, recorded_blob=None):
    if match_kind == "gap":
        return "gap", "gap_or_future_anchor_preserved", None, None
    if not path or path == "none":
        return "gap", "gap_or_future_anchor_preserved", None, None

    exists = path_exists(path)
    current_blob = file_blob(path) if exists else None
    present = pattern_present(path, pattern)
    if not exists:
        return "path_changed", "source_path_missing", current_blob, present
    if present is False and match_kind == "symbol":
        return "symbol_missing", "symbol_missing_in_declared_source_path", current_blob, present
    if present is False:
        return "pattern_missing", "pattern_missing_in_declared_source_path", current_blob, present
    if line_or_range and not pattern:
        return "semantic_recheck_required", "line_only_anchor_requires_semantic_recheck", current_blob, present
    if recorded_blob and current_blob and recorded_blob != current_blob:
        return "semantic_recheck_required", "source_blob_changed_since_recorded_anchor", current_blob, present
    if recorded_commit and recorded_commit != linux_head:
        return "semantic_recheck_required", "source_commit_changed_since_artifact", current_blob, present
    return "ok", "path_exists_and_pattern_matches_or_not_applicable", current_blob, present

def add_row(rows, source_artifact, anchor_id, path, pattern, anchor_kind, extraction_kind, forbidden, context, recorded_commit=None, recorded_blob=None, line_or_range=None, match_kind=None):
    if match_kind is None:
        if path == "none":
            match_kind = "gap"
        elif pattern and pattern != "none":
            match_kind = "symbol" if anchor_kind in {"file_symbol", "string_anchor_symbol"} else "pattern"
        elif line_or_range:
            match_kind = "line_only"
        else:
            match_kind = "path_only"
    drift, reason, current_blob, present = classify(path, pattern, line_or_range, match_kind, recorded_commit, recorded_blob)
    rows.append({
        "row_id": f"project-anchor-{len(rows)+1:04d}",
        "source_artifact": source_artifact,
        "anchor_id": anchor_id,
        "source_path": path,
        "symbol_or_pattern": pattern or "none",
        "line_or_range": line_or_range or "none",
        "anchor_kind": anchor_kind,
        "extraction_kind": extraction_kind,
        "match_kind": match_kind,
        "recorded_commit": recorded_commit,
        "current_commit": linux_head,
        "recorded_blob_oid": recorded_blob,
        "current_blob_oid": current_blob,
        "git_object_type": object_type(path) or "none",
        "path_exists": str(path_exists(path)).lower(),
        "pattern_present": "not_applicable" if present is None else str(present).lower(),
        "drift_status": drift,
        "reason": reason,
        "semantic_recheck_required": str(drift == "semantic_recheck_required").lower(),
        "context": context,
        "forbidden_upgrade": forbidden,
        "source_only": "true",
        "authority_claim": "false",
        "monitor_verified": "false",
        "protection_claim": "false",
    })

def maybe_anchor_from_string(rows, source_artifact, anchor_id, text, extraction_kind, forbidden, context, recorded_commit=None, recorded_blob=None):
    m = PATH_RE.search(text)
    if not m:
        return False
    path = m.group("path")
    symbol = m.group("symbol") or m.group("colon_symbol")
    line_or_range = m.group("line")
    if symbol and symbol.isdigit():
        symbol = None
    add_row(
        rows,
        source_artifact,
        anchor_id,
        path,
        symbol,
        "string_anchor_symbol" if symbol else "string_anchor",
        extraction_kind,
        forbidden,
        context,
        recorded_commit,
        recorded_blob,
        line_or_range,
    )
    return True

def artifact_recorded_commit(obj):
    if not isinstance(obj, dict):
        return None
    if isinstance(obj.get("linux"), dict) and isinstance(obj["linux"].get("commit"), str):
        return obj["linux"]["commit"]
    if isinstance(obj.get("linux_source"), dict) and isinstance(obj["linux_source"].get("commit"), str):
        return obj["linux_source"]["commit"]
    for key in ("linux_commit", "source_commit", "current_commit"):
        if isinstance(obj.get(key), str):
            return obj[key]
    return None

SAFETY_FALSE_KEYS = {
    "authority_claim",
    "monitor_verified",
    "implementation_approved",
    "behavior_change",
    "public_tracepoint_abi",
    "protection_claim",
}

def scan_safety_flags(source_artifact, obj, safety_violations, path_stack=()):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in SAFETY_FALSE_KEYS and value is True:
                safety_violations.append({
                    "source_artifact": source_artifact,
                    "key": key,
                    "context": "/".join(path_stack + (str(key),)),
                    "actual": True,
                    "expected": False,
                })
            scan_safety_flags(source_artifact, value, safety_violations, path_stack + (str(key),))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            scan_safety_flags(source_artifact, item, safety_violations, path_stack + (f"[{i}]",))

def dict_represents_gap_or_plan(obj):
    return (
        obj.get("inventory_class") in {"future_gap", "trace_catalog_plan"} or
        obj.get("anchor_class") in {"future_gap", "trace_catalog_plan"} or
        obj.get("anchor_confidence") in {"gap_recorded", "plan_only"} or
        obj.get("anchor_available") is False
    )

def walk_for_strings(rows, unsupported, source_artifact, obj, recorded_commit=None, path_stack=()):
    if isinstance(obj, dict):
        if "source_path" in obj and isinstance(obj["source_path"], str):
            source_path = "none" if dict_represents_gap_or_plan(obj) else obj["source_path"]
            add_row(
                rows,
                source_artifact,
                obj.get("row_id") or obj.get("id") or "/".join(path_stack) or "dict-source-path",
                source_path,
                obj.get("symbol_or_pattern") if isinstance(obj.get("symbol_or_pattern"), str) else None,
                obj.get("anchor_kind") if isinstance(obj.get("anchor_kind"), str) else "source_path_pattern",
                "dict_source_path_symbol_or_pattern",
                obj.get("forbidden_upgrade") or obj.get("forbidden_shortcut") or obj.get("gap") or "source_anchor_is_not_authority",
                "/".join(path_stack),
                recorded_commit,
                obj.get("blob_oid") if isinstance(obj.get("blob_oid"), str) else None,
                obj.get("line") if isinstance(obj.get("line"), str) else None,
                "gap" if source_path == "none" else None,
            )
        elif "linux_anchor" in obj and isinstance(obj["linux_anchor"], str):
            maybe_anchor_from_string(
                rows,
                source_artifact,
                obj.get("row_id") or obj.get("id") or "/".join(path_stack) or "dict-linux-anchor",
                obj["linux_anchor"],
                "dict_linux_anchor",
                obj.get("forbidden_upgrade") or obj.get("forbidden_shortcut") or "source_anchor_is_not_authority",
                "/".join(path_stack),
                recorded_commit,
            )
        if "file" in obj and isinstance(obj["file"], str):
            funcs = obj.get("functions") or obj.get("symbols") or []
            if isinstance(funcs, list) and funcs:
                for sym in funcs:
                    if isinstance(sym, str):
                        add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-file-functions"), obj["file"], sym, "file_symbol", "dict_file_functions", obj.get("capsched_rule") or obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
            else:
                add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-file"), obj["file"], None, "file", "dict_file", obj.get("capsched_rule") or obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
        if "files" in obj and isinstance(obj["files"], list):
            symbols = obj.get("symbols") if isinstance(obj.get("symbols"), list) else []
            files = [f for f in obj["files"] if isinstance(f, str)]
            if symbols and len(files) == 1:
                for sym in symbols:
                    if isinstance(sym, str):
                        add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-files-symbols"), files[0], sym, "file_symbol", "dict_files_symbols_single_file", obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
            elif symbols:
                for f in files:
                    add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-files"), f, None, "file", "dict_files_candidate_set", obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
                for sym in symbols:
                    if not isinstance(sym, str):
                        continue
                    matched_files = candidate_files_with_pattern(files, sym)
                    if matched_files:
                        for f in matched_files:
                            add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-files-symbols"), f, sym, "file_symbol", "dict_files_symbols_resolved_by_scan", obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
                    else:
                        unsupported.append({
                            "source_artifact": source_artifact,
                            "context": "/".join(path_stack),
                            "value": sym,
                            "reason": "symbol_not_found_in_candidate_files",
                        })
            else:
                for f in files:
                    add_row(rows, source_artifact, obj.get("id", "/".join(path_stack) or "dict-files"), f, None, "file", "dict_files", obj.get("limitation") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit)
        for key, value in obj.items():
            if key in {"current_linux_anchors", "source_anchors", "minimal_anchors"} and isinstance(value, list):
                for i, item in enumerate(value):
                    if isinstance(item, str):
                        if not maybe_anchor_from_string(rows, source_artifact, f"{'/'.join(path_stack)}/{key}[{i}]", item, key, obj.get("forbidden_shortcut") or obj.get("gap") or "source_anchor_is_not_authority", "/".join(path_stack), recorded_commit):
                            unsupported.append({
                                "source_artifact": source_artifact,
                                "context": f"{'/'.join(path_stack)}/{key}[{i}]",
                                "value": item,
                                "reason": "no_linux_path_pattern_found",
                            })
            elif key in {"source_files"} and isinstance(value, list):
                for i, item in enumerate(value):
                    if isinstance(item, str):
                        if not maybe_anchor_from_string(rows, source_artifact, f"{'/'.join(path_stack)}/{key}[{i}]", item, key, "source_file_is_not_authority", "/".join(path_stack), recorded_commit):
                            unsupported.append({
                                "source_artifact": source_artifact,
                                "context": f"{'/'.join(path_stack)}/{key}[{i}]",
                                "value": item,
                                "reason": "no_linux_path_pattern_found",
                            })
            elif key in {"definition", "entry", "netdev_op", "doorbell", "completion_accounting"} and isinstance(value, str):
                maybe_anchor_from_string(rows, source_artifact, f"{'/'.join(path_stack)}/{key}", value, key, "source_position_is_not_authority", "/".join(path_stack), recorded_commit)
            walk_for_strings(rows, unsupported, source_artifact, value, recorded_commit, path_stack + (str(key),))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            walk_for_strings(rows, unsupported, source_artifact, item, recorded_commit, path_stack + (f"[{i}]",))

rows = []
unsupported = []
safety_violations = []

json_files = sorted(analysis_dir.glob("*source-map-v1.json")) + sorted(analysis_dir.glob("*ledger-v1.json")) + [
    p for p in [
        analysis_dir / "direct-call-attachment-readiness-v1.json",
        analysis_dir / "direct-call-trace-source-inventory-contract-v1.json",
        analysis_dir / "workqueue-origin-taxonomy-v1.json",
    ] if p.exists()
]

latest_overlay = None
overlay_root = workspace_dir / "build" / "direct-call-inventory"
if overlay_root.exists():
    seeds = sorted(overlay_root.glob("*/overlay-seed.json"))
    latest_overlay = seeds[-1] if seeds else None

for path in json_files:
    data = json.loads(path.read_text())
    source_artifact = str(path.relative_to(workspace_dir / "capsched"))
    scan_safety_flags(source_artifact, data, safety_violations)
    walk_for_strings(rows, unsupported, source_artifact, data, artifact_recorded_commit(data))

if latest_overlay:
    seed_rows = json.loads(latest_overlay.read_text())
    for seed in seed_rows:
        for anchor in seed.get("linux_anchors", []):
            source_path = anchor.get("source_path", "none")
            add_row(
                rows,
                str(latest_overlay),
                anchor.get("linux_id", seed.get("row_id", "overlay")),
                source_path,
                anchor.get("symbol_or_pattern"),
                anchor.get("anchor_kind", "overlay_anchor"),
                "direct_call_overlay_seed",
                ";".join(seed.get("not_supported_claims", [])) or "source_anchor_is_not_authority",
                seed.get("row_id", "overlay"),
                anchor.get("last_checked_commit"),
                anchor.get("blob_oid"),
                None,
                "gap" if source_path == "none" or anchor.get("anchor_class") in {"future_gap", "trace_catalog_plan"} else None,
            )

fieldnames = [
    "row_id",
    "source_artifact",
    "anchor_id",
    "source_path",
    "symbol_or_pattern",
    "line_or_range",
    "anchor_kind",
    "extraction_kind",
    "match_kind",
    "recorded_commit",
    "current_commit",
    "recorded_blob_oid",
    "current_blob_oid",
    "git_object_type",
    "path_exists",
    "pattern_present",
    "drift_status",
    "reason",
    "semantic_recheck_required",
    "context",
    "forbidden_upgrade",
    "source_only",
    "authority_claim",
    "monitor_verified",
    "protection_claim",
]

with ledger_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
    writer.writeheader()
    writer.writerows(rows)

ledger_json.write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")

stale_rows = [row for row in rows if row["drift_status"] != "ok"]
with stale_tsv.open("w", newline="") as f:
    writer = csv.writer(f, delimiter="\t")
    writer.writerow(["row_id", "source_artifact", "source_path", "symbol_or_pattern", "line_or_range", "match_kind", "drift_status", "reason"])
    for row in stale_rows:
        writer.writerow([row["row_id"], row["source_artifact"], row["source_path"], row["symbol_or_pattern"], row["line_or_range"], row["match_kind"], row["drift_status"], row["reason"]])

with unsupported_tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["source_artifact", "context", "value", "reason"], delimiter="\t")
    writer.writeheader()
    writer.writerows(unsupported)

counts = {}
for row in rows:
    counts[row["drift_status"]] = counts.get(row["drift_status"], 0) + 1

summary_path.write_text(
    "\n".join([
        f"json_artifacts_scanned={len(json_files)}",
        f"anchor_rows={len(rows)}",
        f"ok_rows={counts.get('ok', 0)}",
        f"gap_rows={counts.get('gap', 0)}",
        f"path_changed_rows={counts.get('path_changed', 0)}",
        f"symbol_missing_rows={counts.get('symbol_missing', 0)}",
        f"pattern_missing_rows={counts.get('pattern_missing', 0)}",
        f"semantic_recheck_required_rows={counts.get('semantic_recheck_required', 0)}",
        f"unsupported_extraction_rows={len(unsupported)}",
        f"safety_flag_violations={len(safety_violations)}",
        "safety_scan_scope=recursive_boolean_safety_fields_in_scanned_json",
        "content_source=git_HEAD_objects",
        "source_path_pattern_only=true",
        "semantic_validation=false",
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

	printf 'Project source-map drift check written to %s\n' "$OUT_DIR"
}

main "$@"
