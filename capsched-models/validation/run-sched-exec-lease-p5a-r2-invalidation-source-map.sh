#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/linux"
CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r2-invalidation-source-map-v1.json"
MODEL_DIR="$CAPSCHED_DIR/capsched-models/formal/0115-p5a-r2-invalidation-source-map-model"
MODEL="P5AR2InvalidationSourceMap.tla"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-invalidation-source-map/$RUN_ID"

mkdir -p "$OUT_DIR"

for cmd in git jq awk java grep sed find wc basename; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "missing command: $cmd" >&2
		exit 1
	fi
done

if [ ! -f "$TLA_JAR" ]; then
	echo "missing TLA jar: $TLA_JAR" >&2
	exit 1
fi

jq empty "$CONFIG"

expected_linux_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_linux_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
if [ "$actual_linux_commit" != "$expected_linux_commit" ]; then
	echo "linux commit mismatch: expected=$expected_linux_commit actual=$actual_linux_commit" >&2
	exit 1
fi

jq -e '
	.status == "source_map_defined_no_linux_patch_approved" and
	(.source_anchors | length == 41) and
	(.mapped_event_families | all(.[]; . == true)) and
	.formal.safe_expected_states_generated == 7 and
	.formal.safe_expected_distinct_states == 6 and
	.formal.safe_expected_depth == 6 and
	.formal.unsafe_cfg_count == 17 and
	.formal.unsafe_expected_counterexamples == 17 and
	(.safety_flags | all(.[]; . == false)) and
	.next.linux_patch_allowed_after_this_map == false
' "$CONFIG" >/dev/null

anchors="$OUT_DIR/source-anchors.tsv"
printf 'id\tfamily\tpath\texpected_line\tactual_line\tstatus\n' > "$anchors"
anchor_count=0
anchor_fail=0

while IFS=$'\t' read -r id family path expected_line pattern; do
	anchor_count=$((anchor_count + 1))
	file="$WORKSPACE_DIR/$path"
	actual_line=""
	if [ -f "$file" ]; then
		actual_line=$(awk -v pat="$pattern" 'index($0, pat) { print NR; found=1; exit } END { if (!found) exit 1 }' "$file" || true)
	fi
	if [ -n "$actual_line" ] && [ "$actual_line" = "$expected_line" ]; then
		status=ok
	else
		status=fail
		anchor_fail=$((anchor_fail + 1))
	fi
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$family" "$path" "$expected_line" "${actual_line:-missing}" "$status" >> "$anchors"
done < <(jq -r '.source_anchors[] | [.id, .family, .path, (.expected_line | tostring), .pattern] | @tsv' "$CONFIG")

if [ "$anchor_fail" -ne 0 ]; then
	echo "source anchor failures: $anchor_fail" >&2
	cat "$anchors" >&2
	exit 1
fi

(
	cd "$MODEL_DIR"
	java -cp "$TLA_JAR" tlc2.TLC -deadlock \
		-metadir "$OUT_DIR/tlc-safe-states" \
		-config P5AR2InvalidationSourceMapSafe.cfg "$MODEL"
) > "$OUT_DIR/tlc-safe.log" 2>&1

if ! grep -q 'Model checking completed. No error has been found.' "$OUT_DIR/tlc-safe.log"; then
	echo "safe TLC model did not pass" >&2
	tail -80 "$OUT_DIR/tlc-safe.log" >&2
	exit 1
fi

state_line=$(sed -n 's/^\([0-9][0-9]*\) states generated, \([0-9][0-9]*\) distinct states found.*/\1 \2/p' "$OUT_DIR/tlc-safe.log" | tail -1)
safe_states=$(printf '%s\n' "$state_line" | awk '{print $1}')
safe_distinct=$(printf '%s\n' "$state_line" | awk '{print $2}')
safe_depth=$(sed -n 's/^The depth of the complete state graph search is \([0-9][0-9]*\).*/\1/p' "$OUT_DIR/tlc-safe.log" | tail -1)

if [ "${safe_states:-0}" -ne 7 ] ||
   [ "${safe_distinct:-0}" -ne 6 ] ||
   [ "${safe_depth:-0}" -ne 6 ]; then
	echo "safe TLC size mismatch: states=${safe_states:-0} distinct=${safe_distinct:-0} depth=${safe_depth:-0}" >&2
	exit 1
fi

unsafe_expected=0
unsafe_fail=0
for cfg in "$MODEL_DIR"/P5AR2InvalidationSourceMapUnsafe*.cfg; do
	name=$(basename "$cfg" .cfg)
	log="$OUT_DIR/tlc-$name.log"
	if (
		cd "$MODEL_DIR"
		java -cp "$TLA_JAR" tlc2.TLC -deadlock \
			-metadir "$OUT_DIR/states-$name" \
			-config "$(basename "$cfg")" "$MODEL"
	) > "$log" 2>&1; then
		echo "unsafe config unexpectedly passed: $(basename "$cfg")" >&2
		unsafe_fail=$((unsafe_fail + 1))
	elif grep -q 'Invariant Safety is violated' "$log"; then
		unsafe_expected=$((unsafe_expected + 1))
	else
		echo "unsafe config failed for unexpected reason: $(basename "$cfg")" >&2
		tail -80 "$log" >&2
		unsafe_fail=$((unsafe_fail + 1))
	fi
done

if [ "$unsafe_fail" -ne 0 ]; then
	exit 1
fi

cfg_count=$(find "$MODEL_DIR" -maxdepth 1 -name 'P5AR2InvalidationSourceMapUnsafe*.cfg' | wc -l)
if [ "$unsafe_expected" -ne 17 ] || [ "$cfg_count" -ne 17 ]; then
	echo "unsafe counterexample count mismatch: expected=17 actual=$unsafe_expected cfg_count=$cfg_count" >&2
	exit 1
fi

cat > "$OUT_DIR/result.json" <<EOF
{
  "run_id": "$RUN_ID",
  "status": "passed",
  "config": "$CONFIG",
  "model_dir": "$MODEL_DIR",
  "linux_commit": "$actual_linux_commit",
  "anchor_count": $anchor_count,
  "anchor_failures": $anchor_fail,
  "safe_passed": true,
  "safe_states_generated": ${safe_states:-0},
  "safe_distinct_states": ${safe_distinct:-0},
  "safe_depth": ${safe_depth:-0},
  "unsafe_expected_counterexamples": $unsafe_expected
}
EOF

cat "$OUT_DIR/result.json"
