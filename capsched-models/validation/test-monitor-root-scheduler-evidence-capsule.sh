#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
umask 077

if [[ $# -ne 1 ]]; then
	echo "usage: $0 /absolute/path/to/capsule" >&2
	exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTOR="$SCRIPT_DIR/evidence-capsule-v1/evidence_capsule_v1.py"
VALIDATOR="$SCRIPT_DIR/validate-monitor-root-scheduler-capsule.py"
CAPSULE=$(realpath "$1")
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rootsched-evidence-test.XXXXXX")

cleanup()
{
	find "$TMP_DIR" -depth -delete
}
trap cleanup EXIT INT TERM

python3 "$COLLECTOR" verify --capsule "$CAPSULE" >/dev/null

cp -a "$CAPSULE" "$TMP_DIR/direct"
printf 'tamper\n' >>"$TMP_DIR/direct/raw/tlc/safe-steady.log"
if python3 "$COLLECTOR" verify --capsule "$TMP_DIR/direct" >/dev/null 2>&1; then
	echo "direct byte mutation unexpectedly passed structural verification" >&2
	exit 1
fi

cp -a "$CAPSULE" "$TMP_DIR/resealed"
python3 - "$TMP_DIR/resealed" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
target = root / "raw/tlc/safe-steady.status"
mutated = b"12\n"
target.write_bytes(mutated)

manifest_path = root / "core-manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
row = next(
    item for item in manifest["core"]["objects"]
    if item["capsule_path"] == "raw/tlc/safe-steady.status"
)
row["size_bytes"] = len(mutated)
row["sha256"] = hashlib.sha256(mutated).hexdigest()
row["source_git"]["size_bytes"] = len(mutated)
row["source_git"]["sha256"] = row["sha256"]
canonical_core = json.dumps(
    manifest["core"],
    sort_keys=True,
    separators=(",", ":"),
    ensure_ascii=True,
    allow_nan=False,
).encode("ascii")
manifest["capsule_id"] = hashlib.sha256(canonical_core).hexdigest()
manifest_path.write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

python3 "$COLLECTOR" verify --capsule "$TMP_DIR/resealed" >/dev/null
if python3 "$VALIDATOR" \
	--capsule "$TMP_DIR/resealed" \
	--output "$TMP_DIR/resealed-result.json" >/dev/null 2>&1; then
	echo "semantically re-sealed status mutation unexpectedly validated" >&2
	exit 1
fi

jq -e '
  .status == "Invalid"
  and any(.checks[];
    .id == "captured_raw_outcomes" and .status == "fail")
  and any(.checks[];
    .id == "validator_reexecution"
    and .status == "fail"
    and (.witness | contains("skipped")))
' "$TMP_DIR/resealed-result.json" >/dev/null

printf '%s\n' \
	'direct-mutation: rejected' \
	'resealed-semantic-mutation: rejected-without-reexecution'
