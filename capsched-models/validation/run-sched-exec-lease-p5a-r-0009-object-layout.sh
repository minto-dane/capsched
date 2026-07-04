#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r-0009-ordinary-cfs-draft-v1.json"
BUILD_TAG=${DOMAINLEASE_BUILD_TAG:-p5a-r-0009}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-0009-object-layout/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_cmd awk
require_cmd git
require_cmd jq
require_cmd make
require_cmd nm
require_cmd objdump
require_cmd sha256sum
require_cmd size
require_cmd sort
require_cmd stat
require_cmd wc

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_commit" = "$expected_commit" ] || \
	die "linux HEAD mismatch: expected=$expected_commit actual=$actual_commit"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty"
fi

off_build="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-$BUILD_TAG-x86_64"
on_build="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-$BUILD_TAG-x86_64"

off_fair="$off_build/kernel/sched/fair.o"
on_fair="$on_build/kernel/sched/fair.o"
off_core="$off_build/kernel/sched/core.o"
on_core="$on_build/kernel/sched/core.o"
off_exec="$off_build/kernel/sched/exec_lease.o"
on_exec="$on_build/kernel/sched/exec_lease.o"

for path in "$off_build/vmlinux" "$on_build/vmlinux" "$off_fair" "$on_fair" \
	    "$off_core" "$on_core" "$on_exec"; do
	[ -f "$path" ] || die "missing build output: $path"
done
[ ! -e "$off_exec" ] || die "off exec_lease.o unexpectedly present: $off_exec"

"$LINUX_DIR/scripts/config" --file "$off_build/.config" --state SCHED_EXEC_LEASE \
	> "$OUT_DIR/off-config-state.txt" || true
"$LINUX_DIR/scripts/config" --file "$on_build/.config" --state SCHED_EXEC_LEASE \
	> "$OUT_DIR/on-config-state.txt" || true
grep -qx 'undef' "$OUT_DIR/off-config-state.txt" || die "off config is not undef"
grep -qx 'y' "$OUT_DIR/on-config-state.txt" || die "on config is not y"

size "$off_fair" "$on_fair" "$off_core" "$on_core" "$on_exec" \
	> "$OUT_DIR/object-size.txt"
sha256sum "$off_fair" "$on_fair" "$off_core" "$on_core" "$on_exec" \
	> "$OUT_DIR/object-sha256.txt"

objdump -h "$off_fair" > "$OUT_DIR/off-fair-sections.txt"
objdump -h "$on_fair" > "$OUT_DIR/on-fair-sections.txt"
objdump -h "$off_core" > "$OUT_DIR/off-core-sections.txt"
objdump -h "$on_core" > "$OUT_DIR/on-core-sections.txt"
objdump -h "$on_exec" > "$OUT_DIR/on-exec-lease-sections.txt"

make_function_table()
{
	local obj=$1
	nm -S --defined-only "$obj" | awk '
		$2 ~ /^[0-9a-fA-F]+$/ && $3 ~ /^[TtWw]$/ {
			print $4 "\t" $2 "\t" $3
		}
	' | sort
}

make_function_table "$off_fair" > "$OUT_DIR/off-fair-function-sizes.tsv"
make_function_table "$on_fair" > "$OUT_DIR/on-fair-function-sizes.tsv"
make_function_table "$off_core" > "$OUT_DIR/off-core-function-sizes.tsv"
make_function_table "$on_core" > "$OUT_DIR/on-core-function-sizes.tsv"

nm -S --defined-only "$off_fair" | grep -E 'pick_task_fair|pick_eevdf|sched_exec_cfs|candidate_key' \
	> "$OUT_DIR/off-fair-relevant-symbols.tsv" || true
nm -S --defined-only "$on_fair" | grep -E 'pick_task_fair|pick_eevdf|sched_exec_cfs|candidate_key' \
	> "$OUT_DIR/on-fair-relevant-symbols.tsv" || true
nm -S --defined-only "$off_core" | grep -E 'pick_task_fair|pick_eevdf|sched_exec_cfs|candidate_key' \
	> "$OUT_DIR/off-core-relevant-symbols.tsv" || true
nm -S --defined-only "$on_core" | grep -E 'pick_task_fair|pick_eevdf|sched_exec_cfs|candidate_key' \
	> "$OUT_DIR/on-core-relevant-symbols.tsv" || true

grep -q ' T pick_task_fair_sched_exec_lease$' "$OUT_DIR/off-fair-relevant-symbols.tsv" || \
	die "off fair.o lacks pick_task_fair_sched_exec_lease"
grep -q ' T pick_task_fair_sched_exec_lease$' "$OUT_DIR/on-fair-relevant-symbols.tsv" || \
	die "on fair.o lacks pick_task_fair_sched_exec_lease"
grep -q ' b sched_exec_cfs_candidate_key$' "$OUT_DIR/on-fair-relevant-symbols.tsv" || \
	die "on fair.o lacks dormant static key storage"
if grep -q 'sched_exec_cfs_candidate_key' "$OUT_DIR/off-fair-relevant-symbols.tsv"; then
	die "off fair.o unexpectedly has sched_exec_cfs_candidate_key"
fi

git -C "$LINUX_DIR" diff --name-only HEAD^..HEAD | sort \
	> "$OUT_DIR/0009-delta-files.txt"
if grep -qx 'include/linux/sched.h' "$OUT_DIR/0009-delta-files.txt"; then
	die "0009 unexpectedly changes include/linux/sched.h"
fi
if git -C "$LINUX_DIR" diff --unified=0 HEAD^..HEAD -- kernel/sched/sched.h | \
	grep -E '^[+].*(struct rq \{|struct cfs_rq \{|struct sched_entity \{)' \
	> "$OUT_DIR/forbidden-sched-h-layout-diff.txt"; then
	die "0009 changes scheduler persistent layout in sched.h"
fi
: > "$OUT_DIR/forbidden-sched-h-layout-diff.txt"

BUILD_TAG="$BUILD_TAG" "$CAPSCHED_DIR/capsched-models/validation/run-sched-exec-lease-task-layout-probe.sh" \
	> "$OUT_DIR/task-layout-probe.log" 2>&1
layout_root=$(sed -n 's/.*output root: //p' "$OUT_DIR/task-layout-probe.log" | tail -1)
[ -n "$layout_root" ] || die "could not find task layout output root"
[ -f "$layout_root/off/symbols.tsv" ] || die "missing off task layout symbols"
[ -f "$layout_root/on/symbols.tsv" ] || die "missing on task layout symbols"

grep -qx $'sched_exec_no_config_probe\t0x0000000000000001' "$layout_root/off/symbols.tsv" || \
	die "off task layout lacks no-config probe"
grep -qx $'sched_exec_task_struct_size_probe\t0x0000000000000cc0' "$layout_root/off/symbols.tsv" || \
	die "off task_struct size changed"
grep -qx $'sched_exec_field_size_probe\t0x0000000000000028' "$layout_root/on/symbols.tsv" || \
	die "on sched_exec field size changed"
grep -qx $'sched_exec_field_offset_plus_one_probe\t0x0000000000000591' "$layout_root/on/symbols.tsv" || \
	die "on sched_exec field offset changed"
grep -qx $'sched_exec_task_struct_size_probe\t0x0000000000000d00' "$layout_root/on/symbols.tsv" || \
	die "on task_struct size changed"

off_fair_size=$(stat -c '%s' "$off_fair")
on_fair_size=$(stat -c '%s' "$on_fair")
off_core_size=$(stat -c '%s' "$off_core")
on_core_size=$(stat -c '%s' "$on_core")
on_exec_size=$(stat -c '%s' "$on_exec")

off_fair_fn_count=$(wc -l < "$OUT_DIR/off-fair-function-sizes.tsv")
on_fair_fn_count=$(wc -l < "$OUT_DIR/on-fair-function-sizes.tsv")
off_core_fn_count=$(wc -l < "$OUT_DIR/off-core-function-sizes.tsv")
on_core_fn_count=$(wc -l < "$OUT_DIR/on-core-function-sizes.tsv")

off_fair_fn_hash=$(sha256sum "$OUT_DIR/off-fair-function-sizes.tsv" | awk '{ print $1 }')
on_fair_fn_hash=$(sha256sum "$OUT_DIR/on-fair-function-sizes.tsv" | awk '{ print $1 }')
off_core_fn_hash=$(sha256sum "$OUT_DIR/off-core-function-sizes.tsv" | awk '{ print $1 }')
on_core_fn_hash=$(sha256sum "$OUT_DIR/on-core-function-sizes.tsv" | awk '{ print $1 }')

off_fair_sha=$(sha256sum "$off_fair" | awk '{ print $1 }')
on_fair_sha=$(sha256sum "$on_fair" | awk '{ print $1 }')
off_core_sha=$(sha256sum "$off_core" | awk '{ print $1 }')
on_core_sha=$(sha256sum "$on_core" | awk '{ print $1 }')
on_exec_sha=$(sha256sum "$on_exec" | awk '{ print $1 }')

cat > "$OUT_DIR/object-layout.tsv" <<EOF_TSV
property	value	evidence
linux_commit	$actual_commit	git
build_tag	$BUILD_TAG	input
config_off_undef	true	$OUT_DIR/off-config-state.txt
config_on_y	true	$OUT_DIR/on-config-state.txt
off_exec_lease_object_absent	true	$off_exec
on_exec_lease_object_present	true	$on_exec
off_fair_o_size	$off_fair_size	$off_fair
on_fair_o_size	$on_fair_size	$on_fair
off_core_o_size	$off_core_size	$off_core
on_core_o_size	$on_core_size	$on_core
on_exec_lease_o_size	$on_exec_size	$on_exec
off_fair_o_sha256	$off_fair_sha	$off_fair
on_fair_o_sha256	$on_fair_sha	$on_fair
off_core_o_sha256	$off_core_sha	$off_core
on_core_o_sha256	$on_core_sha	$on_core
on_exec_lease_o_sha256	$on_exec_sha	$on_exec
off_fair_function_count	$off_fair_fn_count	$OUT_DIR/off-fair-function-sizes.tsv
on_fair_function_count	$on_fair_fn_count	$OUT_DIR/on-fair-function-sizes.tsv
off_core_function_count	$off_core_fn_count	$OUT_DIR/off-core-function-sizes.tsv
on_core_function_count	$on_core_fn_count	$OUT_DIR/on-core-function-sizes.tsv
off_fair_function_hash	$off_fair_fn_hash	$OUT_DIR/off-fair-function-sizes.tsv
on_fair_function_hash	$on_fair_fn_hash	$OUT_DIR/on-fair-function-sizes.tsv
off_core_function_hash	$off_core_fn_hash	$OUT_DIR/off-core-function-sizes.tsv
on_core_function_hash	$on_core_fn_hash	$OUT_DIR/on-core-function-sizes.tsv
off_wrapper_symbol_present	true	$OUT_DIR/off-fair-relevant-symbols.tsv
on_wrapper_symbol_present	true	$OUT_DIR/on-fair-relevant-symbols.tsv
on_static_key_storage_present	true	$OUT_DIR/on-fair-relevant-symbols.tsv
off_static_key_storage_present	false	$OUT_DIR/off-fair-relevant-symbols.tsv
task_layout_probe_passed	true	$layout_root
runtime_denial_correctness	false	non_claim
production_protection	false	non_claim
EOF_TSV

jq -n \
	--arg run_id "$RUN_ID" \
	--arg out_dir "$OUT_DIR" \
	--arg linux_commit "$actual_commit" \
	--arg build_tag "$BUILD_TAG" \
	--arg layout_root "$layout_root" \
	--arg off_fair_sha "$off_fair_sha" \
	--arg on_fair_sha "$on_fair_sha" \
	--arg off_core_sha "$off_core_sha" \
	--arg on_core_sha "$on_core_sha" \
	--arg on_exec_sha "$on_exec_sha" \
	--argjson off_fair_size "$off_fair_size" \
	--argjson on_fair_size "$on_fair_size" \
	--argjson off_core_size "$off_core_size" \
	--argjson on_core_size "$on_core_size" \
	--argjson on_exec_size "$on_exec_size" \
	--argjson off_fair_fn_count "$off_fair_fn_count" \
	--argjson on_fair_fn_count "$on_fair_fn_count" \
	--argjson off_core_fn_count "$off_core_fn_count" \
	--argjson on_core_fn_count "$on_core_fn_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  out_dir: $out_dir,
	  status: "passed",
	  linux_commit: $linux_commit,
	  build_tag: $build_tag,
	  config_off_undef: true,
	  config_on_y: true,
	  off_exec_lease_object_absent: true,
	  on_exec_lease_object_present: true,
	  objects: {
	    off_fair_o: { size: $off_fair_size, sha256: $off_fair_sha },
	    on_fair_o: { size: $on_fair_size, sha256: $on_fair_sha },
	    off_core_o: { size: $off_core_size, sha256: $off_core_sha },
	    on_core_o: { size: $on_core_size, sha256: $on_core_sha },
	    on_exec_lease_o: { size: $on_exec_size, sha256: $on_exec_sha }
	  },
	  function_counts: {
	    off_fair_o: $off_fair_fn_count,
	    on_fair_o: $on_fair_fn_count,
	    off_core_o: $off_core_fn_count,
	    on_core_o: $on_core_fn_count
	  },
	  wrapper_symbol_present: { off: true, on: true },
	  static_key_storage_present: { off: false, on: true },
	  persistent_task_layout_changed_by_0009: false,
	  task_layout_probe_passed: true,
	  task_layout_root: $layout_root,
	  linux_0009_accepted: false,
	  runtime_denial_correctness: false,
	  cfs_deny_and_repick_correctness: false,
	  production_protection: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
