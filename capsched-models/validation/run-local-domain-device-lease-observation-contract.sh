#!/usr/bin/env bash
set -euo pipefail

ROOT="${CAPSCHED_WORKSPACE:-/media/nia/scsiusb/dev/linux-cap}"
OUT_ROOT="${CAPSCHED_LDDL_OBS_OUT_ROOT:-$ROOT/build/local-domain-device-lease-observation-contract}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$OUT_ROOT/$STAMP"
CONTRACT="$ROOT/capsched/capsched-models/analysis/local-domain-device-lease-observation-contract-v1.json"
ROWS="$RUN_DIR/contract-rows.tsv"
GAPS="$RUN_DIR/semantic-gaps.tsv"
SUMMARY="$RUN_DIR/summary.txt"

mkdir -p "$RUN_DIR"

if ! command -v python3 >/dev/null 2>&1; then
	echo "error: missing required command: python3" >&2
	exit 1
fi

python3 - "$CONTRACT" "$ROWS" "$GAPS" "$SUMMARY" <<'PY'
import json
import sys
from pathlib import Path

contract_path = Path(sys.argv[1])
rows_path = Path(sys.argv[2])
gaps_path = Path(sys.argv[3])
summary_path = Path(sys.argv[4])

data = json.loads(contract_path.read_text())
required = list(data["required_row_fields"])
constraints = data["global_constraints"]
rows = list(data["rows"])
ids = [row["row_id"] for row in rows]
id_set = set(ids)

errors = []
gap_rows = []

if len(ids) != len(id_set):
    errors.append("duplicate row_id")

for row in rows:
    missing = [field for field in required if field not in row]
    if missing:
        errors.append(f"{row.get('row_id', '<unknown>')}: missing {','.join(missing)}")
    for key, expected in constraints.items():
        if row.get(key) is not expected:
            errors.append(f"{row.get('row_id', '<unknown>')}: {key}={row.get(key)!r}, expected {expected!r}")
    for pred in row.get("predecessors", []):
        if pred not in id_set:
            errors.append(f"{row['row_id']}: unknown predecessor {pred}")
    if row.get("compiled_local_lease_id") not in ("unset", "opaque:local-domain-device-lease"):
        errors.append(f"{row['row_id']}: unexpected compiled_local_lease_id")
    if row.get("expected_pre_monitor_status") != "planned_contract_only":
        errors.append(f"{row['row_id']}: expected_pre_monitor_status must remain planned_contract_only")
    gap_rows.append((row["row_id"], row["authority_object"], row["forbidden_shortcut"]))

for rule in data["dependency_rules"]:
    target = rule["target_row"]
    target_row = next((row for row in rows if row["row_id"] == target), None)
    if target_row is None:
        errors.append(f"{rule['id']}: target row missing: {target}")
        continue
    predecessors = set(target_row.get("predecessors", []))
    for required_pred in rule["requires"]:
        if required_pred not in predecessors:
            errors.append(f"{rule['id']}: {target} missing predecessor {required_pred}")

compile_index = ids.index("LDDL-070-COMPILE-LOCAL-LEASE")
for receipt_row in [
    "LDDL-080-SERVICE-REQUEST-RECEIPTS",
    "LDDL-090-TARGET-RECEIVE-ENDPOINTS",
]:
    if ids.index(receipt_row) < compile_index:
        errors.append(f"{receipt_row}: appears before local lease compile")

with rows_path.open("w") as out:
    out.write("\t".join([
        "row_id",
        "phase",
        "authority_object",
        "cluster_lease_id",
        "node_id",
        "local_monitor_epoch",
        "service_domain_id",
        "target_domain_id",
        "device_root_id",
        "compiled_local_lease_id",
        "compile_result",
        "revocation_status",
        "predecessor_count",
        "evidence_surface",
        "forbidden_shortcut",
        "observation_only",
        "authority_claim",
        "monitor_verified",
        "behavior_change",
        "protection_claim",
    ]) + "\n")
    for row in rows:
        out.write("\t".join([
            str(row["row_id"]),
            str(row["phase"]),
            str(row["authority_object"]),
            str(row["cluster_lease_id"]),
            str(row["node_id"]),
            str(row["local_monitor_epoch"]),
            str(row["service_domain_id"]),
            str(row["target_domain_id"]),
            str(row["device_root_id"]),
            str(row["compiled_local_lease_id"]),
            str(row["compile_result"]),
            str(row["revocation_status"]),
            str(len(row["predecessors"])),
            str(row["evidence_surface"]),
            str(row["forbidden_shortcut"]),
            str(row["observation_only"]).lower(),
            str(row["authority_claim"]).lower(),
            str(row["monitor_verified"]).lower(),
            str(row["behavior_change"]).lower(),
            str(row["protection_claim"]).lower(),
        ]) + "\n")

with gaps_path.open("w") as out:
    out.write("row_id\tauthority_object\tforbidden_shortcut\n")
    for row_id, authority_object, shortcut in gap_rows:
        out.write(f"{row_id}\t{authority_object}\t{shortcut}\n")

safety_flag_violations = sum(
    1
    for row in rows
    for key, expected in constraints.items()
    if row.get(key) is not expected
)

summary = {
    "contract": str(contract_path),
    "row_count": len(rows),
    "dependency_rule_count": len(data["dependency_rules"]),
    "dependency_errors": len(errors),
    "safety_flag_violations": safety_flag_violations,
    "forbidden_authority_collapse_count": len(data["forbidden_authority_collapses"]),
    "observation_only": constraints["observation_only"],
    "authority_claim": constraints["authority_claim"],
    "monitor_verified": constraints["monitor_verified"],
    "behavior_change": constraints["behavior_change"],
    "protection_claim": constraints["protection_claim"],
}

with summary_path.open("w") as out:
    for key, value in summary.items():
        out.write(f"{key}={str(value).lower() if isinstance(value, bool) else value}\n")
    if errors:
        out.write("errors:\n")
        for error in errors:
            out.write(f"- {error}\n")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY

printf '[capsched] LocalDomainDeviceLease observation contract validated\n'
printf '[capsched] run_dir=%s\n' "$RUN_DIR"
cat "$SUMMARY"
