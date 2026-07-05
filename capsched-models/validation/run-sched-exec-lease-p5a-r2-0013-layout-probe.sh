#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCHES_DIR=${DOMAINLEASE_LINUX_PATCHES_DIR:-"$WORKSPACE_DIR/linux-patches"}
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-0013-layout-probe-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-0013-layout-probe/$RUN_ID"

OFF_O=${DOMAINLEASE_P5AR2_0013_OFF_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64"}
ON_O=${DOMAINLEASE_P5AR2_0013_ON_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64"}
PROBE_O=${DOMAINLEASE_P5AR2_0013_PROBE_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-p5a-r2-0013-probe-x86_64"}
REPLAY_DIR=${DOMAINLEASE_P5AR2_0013_REPLAY_DIR:-"$WORKSPACE_DIR/linux-replay-0013"}

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
require_cmd cp
require_cmd git
require_cmd grep
require_cmd jq
require_cmd make
require_cmd nm
require_cmd rm
require_cmd sed
require_cmd sha256sum
require_cmd sort
require_cmd stat
require_cmd wc

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_parent=$(jq -r '.source_basis.parent_linux_commit' "$CONFIG")
expected_local=$(jq -r '.source_basis.local_linux_commit' "$CONFIG")
expected_replay=$(jq -r '.source_basis.patch_queue_replay_commit' "$CONFIG")
expected_tree=$(jq -r '.source_basis.linux_tree' "$CONFIG")
expected_patch_sha=$(jq -r '.source_basis.patch_sha256' "$CONFIG")
expected_series_sha=$(jq -r '.source_basis.series_sha256' "$CONFIG")
expected_probe_sha=$(jq -r '.probe_build.object_sha256' "$CONFIG")
expected_probe_size=$(jq -r '.probe_build.object_size' "$CONFIG")
expected_symbol_count=$(jq -r '.probe_build.symbol_count' "$CONFIG")

actual_local=$(git -C "$LINUX_DIR" rev-parse HEAD)
actual_parent=$(git -C "$LINUX_DIR" rev-parse HEAD^)
actual_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^{tree})

[ "$actual_local" = "$expected_local" ] || \
	die "linux HEAD mismatch: expected=$expected_local actual=$actual_local"
[ "$actual_parent" = "$expected_parent" ] || \
	die "linux parent mismatch: expected=$expected_parent actual=$actual_parent"
[ "$actual_tree" = "$expected_tree" ] || \
	die "linux tree mismatch: expected=$expected_tree actual=$actual_tree"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty"
fi

patch_file="$WORKSPACE_DIR/$(jq -r '.source_basis.patch_file' "$CONFIG")"
series="$PATCHES_DIR/patches/capsched-linux-l0/series"
[ -f "$patch_file" ] || die "missing patch file: $patch_file"
[ -f "$series" ] || die "missing series: $series"

patch_sha=$(sha256sum "$patch_file" | awk '{ print $1 }')
series_sha=$(sha256sum "$series" | awk '{ print $1 }')
[ "$patch_sha" = "$expected_patch_sha" ] || \
	die "patch sha mismatch: expected=$expected_patch_sha actual=$patch_sha"
[ "$series_sha" = "$expected_series_sha" ] || \
	die "series sha mismatch: expected=$expected_series_sha actual=$series_sha"

[ "$(tail -n 1 "$series")" = "$(basename "$patch_file")" ] || \
	die "0013 patch is not the final series entry"

head_from_patch=$(sed -n '1s/^From \([0-9a-f]*\) .*/\1/p' "$patch_file")
[ "$head_from_patch" = "$actual_local" ] || \
	die "patch From hash $head_from_patch does not match local $actual_local"

DOMAINLEASE_RECREATE_FETCH=0 DOMAINLEASE_RECREATE_FORCE=1 \
	"$PATCHES_DIR/scripts/recreate-capsched-linux-l0.sh" "$REPLAY_DIR" \
	> "$OUT_DIR/replay.log" 2>&1
actual_replay=$(git -C "$REPLAY_DIR" rev-parse HEAD)
actual_replay_tree=$(git -C "$REPLAY_DIR" rev-parse HEAD^{tree})
[ "$actual_replay" = "$expected_replay" ] || \
	die "replay mismatch: expected=$expected_replay actual=$actual_replay"
[ "$actual_replay_tree" = "$expected_tree" ] || \
	die "replay tree mismatch: expected=$expected_tree actual=$actual_replay_tree"

checkpatch_rc=0
"$LINUX_DIR/scripts/checkpatch.pl" --no-tree "$patch_file" \
	> "$OUT_DIR/checkpatch.txt" 2>&1 || checkpatch_rc=$?
checkpatch_errors=$(sed -n 's/^total: \([0-9][0-9]*\) errors, \([0-9][0-9]*\) warnings.*/\1/p' "$OUT_DIR/checkpatch.txt")
checkpatch_warnings=$(sed -n 's/^total: \([0-9][0-9]*\) errors, \([0-9][0-9]*\) warnings.*/\2/p' "$OUT_DIR/checkpatch.txt")
checkpatch_errors=${checkpatch_errors:-0}
checkpatch_warnings=${checkpatch_warnings:-0}
if [ "$checkpatch_errors" -ne 0 ]; then
	cat "$OUT_DIR/checkpatch.txt" >&2
	die "checkpatch errors present"
fi
if [ "$checkpatch_warnings" -ne 1 ] ||
   ! grep -q 'MAINTAINERS need updating' "$OUT_DIR/checkpatch.txt"; then
	cat "$OUT_DIR/checkpatch.txt" >&2
	die "unexpected checkpatch warnings: warnings=$checkpatch_warnings rc=$checkpatch_rc"
fi

git -C "$LINUX_DIR" diff --name-only "$expected_parent..$actual_local" | sort \
	> "$OUT_DIR/0013-delta-files.txt"
{
	printf 'init/Kconfig\n'
	printf 'kernel/sched/Makefile\n'
	printf 'kernel/sched/exec_lease_layout_probe.c\n'
} | sort > "$OUT_DIR/0013-expected-files.txt"
diff -u "$OUT_DIR/0013-expected-files.txt" "$OUT_DIR/0013-delta-files.txt" \
	> "$OUT_DIR/0013-file-diff.txt" || die "0013 changed files are not allowlist"

git -C "$LINUX_DIR" diff --check "$expected_parent..$actual_local" \
	> "$OUT_DIR/diff-check.txt" 2>&1 || die "git diff --check failed"

grep -q '^config SCHED_EXEC_LEASE_LAYOUT_PROBE$' "$LINUX_DIR/init/Kconfig" || \
	die "missing layout probe Kconfig"
grep -q '^	default n$' "$LINUX_DIR/init/Kconfig" || \
	die "missing default n"
if grep -n 'select SCHED_EXEC_LEASE_LAYOUT_PROBE' "$LINUX_DIR/init/Kconfig" \
	> "$OUT_DIR/bad-select.txt"; then
	die "main config selects layout probe"
fi
grep -Fq 'obj-$(CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE) += exec_lease_layout_probe.o' \
	"$LINUX_DIR/kernel/sched/Makefile" || die "missing Makefile object rule"

probe_source="$LINUX_DIR/kernel/sched/exec_lease_layout_probe.c"
grep -q 'CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE is explicitly enabled' "$probe_source" || \
	die "probe nonclaim comment missing"
grep -q 'SCHED_EXEC_SIZE_PROBE(sched_exec_lp_sched_entity,' "$probe_source" || \
	die "sched_entity size probe missing"
grep -q 'SCHED_EXEC_SIZE_PROBE(sched_exec_lp_cfs_rq, struct cfs_rq);' "$probe_source" || \
	die "cfs_rq size probe missing"
grep -q 'SCHED_EXEC_SIZE_PROBE(sched_exec_lp_rq, struct rq);' "$probe_source" || \
	die "rq size probe missing"
grep -q 'SCHED_EXEC_SIZE_PROBE(sched_exec_lp_task_struct,' "$probe_source" || \
	die "task_struct size probe missing"
if grep -nE 'EXPORT_SYMBOL|trace_|static_branch_enable|sched_exec_lease_validate|monitor_[A-Za-z0-9_]*[[:space:]]*\(|policy_[A-Za-z0-9_]*[[:space:]]*\(' \
	"$probe_source" > "$OUT_DIR/bad-probe-source.txt"; then
	die "probe source has forbidden runtime/API surface"
fi

[ -f "$OFF_O/.config" ] || die "missing off .config: $OFF_O/.config"
[ -f "$ON_O/.config" ] || die "missing on .config: $ON_O/.config"
if grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$OFF_O/.config"; then
	die "off build tree unexpectedly has CONFIG_SCHED_EXEC_LEASE=y"
fi
if ! grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$ON_O/.config"; then
	die "on build tree lacks CONFIG_SCHED_EXEC_LEASE=y"
fi

make -C "$LINUX_DIR" O="$OFF_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o \
	> "$OUT_DIR/off-normal-build.log" 2>&1
make -C "$LINUX_DIR" O="$ON_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o kernel/sched/exec_lease.o \
	> "$OUT_DIR/on-normal-build.log" 2>&1
test ! -e "$OFF_O/kernel/sched/exec_lease_layout_probe.o" || \
	die "off normal build emitted layout probe object"
test ! -e "$ON_O/kernel/sched/exec_lease_layout_probe.o" || \
	die "on normal build emitted layout probe object"

rm -rf "$PROBE_O"
mkdir -p "$PROBE_O"
cp "$ON_O/.config" "$PROBE_O/.config"
"$LINUX_DIR/scripts/config" --file "$PROBE_O/.config" \
	-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE
make -C "$LINUX_DIR" O="$PROBE_O" olddefconfig \
	> "$OUT_DIR/probe-olddefconfig.log" 2>&1
make -C "$LINUX_DIR" O="$PROBE_O" -j"$(nproc)" \
	kernel/sched/exec_lease_layout_probe.o \
	> "$OUT_DIR/probe-build.log" 2>&1

probe_obj="$PROBE_O/kernel/sched/exec_lease_layout_probe.o"
[ -s "$probe_obj" ] || die "missing probe object: $probe_obj"
probe_size=$(stat -c '%s' "$probe_obj")
probe_sha=$(sha256sum "$probe_obj" | awk '{ print $1 }')
nm -S --size-sort "$probe_obj" | grep 'sched_exec_lp_' > "$OUT_DIR/probe-symbols.tsv"
symbol_count=$(wc -l < "$OUT_DIR/probe-symbols.tsv")
[ "$probe_size" = "$expected_probe_size" ] || \
	die "probe size mismatch: expected=$expected_probe_size actual=$probe_size"
[ "$probe_sha" = "$expected_probe_sha" ] || \
	die "probe sha mismatch: expected=$expected_probe_sha actual=$probe_sha"
[ "$symbol_count" = "$expected_symbol_count" ] || \
	die "probe symbol count mismatch: expected=$expected_symbol_count actual=$symbol_count"

for symbol in \
	sched_exec_lp_sched_entity_size \
	sched_exec_lp_sched_entity_run_node_offset_plus_one \
	sched_exec_lp_sched_entity_min_vruntime_offset_plus_one \
	sched_exec_lp_sched_entity_vruntime_offset_plus_one \
	sched_exec_lp_cfs_rq_size \
	sched_exec_lp_cfs_rq_tasks_timeline_offset_plus_one \
	sched_exec_lp_cfs_rq_curr_offset_plus_one \
	sched_exec_lp_cfs_rq_next_offset_plus_one \
	sched_exec_lp_rq_size \
	sched_exec_lp_rq_nr_running_offset_plus_one \
	sched_exec_lp_rq_curr_offset_plus_one \
	sched_exec_lp_rq_cfs_offset_plus_one \
	sched_exec_lp_task_struct_size \
	sched_exec_lp_task_struct_sched_exec_offset_plus_one
do
	grep -q "$symbol" "$OUT_DIR/probe-symbols.tsv" || \
		die "missing probe symbol: $symbol"
done

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_local" \
	--arg replay_commit "$actual_replay" \
	--arg linux_tree "$actual_tree" \
	--arg patch_sha "$patch_sha" \
	--arg series_sha "$series_sha" \
	--arg probe_o "$PROBE_O" \
	--arg probe_sha "$probe_sha" \
	--argjson checkpatch_errors "$checkpatch_errors" \
	--argjson checkpatch_warnings "$checkpatch_warnings" \
	--argjson probe_size "$probe_size" \
	--argjson symbol_count "$symbol_count" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  status: "passed",
	  linux_commit: $linux_commit,
	  patch_queue_replay_commit: $replay_commit,
	  linux_tree: $linux_tree,
	  patch_sha256: $patch_sha,
	  series_sha256: $series_sha,
	  checkpatch_errors: $checkpatch_errors,
	  checkpatch_warnings: $checkpatch_warnings,
	  checkpatch_warning_exception: "MAINTAINERS new-file warning only",
	  normal_config_off_probe_object_absent: true,
	  normal_config_on_probe_object_absent: true,
	  probe_build_passed: true,
	  probe_output_dir: $probe_o,
	  probe_object_size: $probe_size,
	  probe_object_sha256: $probe_sha,
	  probe_symbol_count: $symbol_count,
	  runtime_behavior_change: false,
	  runtime_denial_correctness: false,
	  production_protection: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
