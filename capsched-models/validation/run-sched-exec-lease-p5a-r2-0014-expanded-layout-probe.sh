#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
PATCHES_DIR="$WORKSPACE_DIR/linux-patches"
REPLAY_DIR=${DOMAINLEASE_P5AR2_0014_REPLAY_DIR:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/replays/0014"}
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-0014-expanded-layout-probe-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-0014-expanded-layout-probe/$RUN_ID"
BASELINE_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/20260713T140445Z"
BUILD_ROOT=${DOMAINLEASE_P5AR2_0014_BUILD_ROOT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/20260713T-p5a-r2-0014-expanded-probe"}
OFF_O="$BUILD_ROOT/off"
ON_O="$BUILD_ROOT/on"
PROBE_O="$BUILD_ROOT/probe"
PROGRESS_FILE=${PROGRESS_FILE:-}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress() { [ -z "$PROGRESS_FILE" ] || printf '%s\n' "$*" > "$PROGRESS_FILE"; printf '[progress] %s\n' "$*"; }

for cmd in awk comm cp diff git grep jq make nm nproc sed sha256sum sort stat wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR" "$BUILD_ROOT"
jq empty "$CONFIG"
progress '5% source and metadata gates'

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_local=$(jq -r '.source.local_commit' "$CONFIG")
expected_tree=$(jq -r '.source.tree' "$CONFIG")
expected_replay=$(jq -r '.patch_queue.replay_commit' "$CONFIG")
expected_patch_sha=$(jq -r '.patch_queue.patch_sha256' "$CONFIG")
expected_series_sha=$(jq -r '.patch_queue.series_sha256' "$CONFIG")
expected_symbols=$(jq -r '.probe.expected_total_symbols' "$CONFIG")
expected_table_fields=$(jq -r '.probe.expected_cacheline_table_fields' "$CONFIG")

actual_local=$(git -C "$LINUX_DIR" rev-parse HEAD)
actual_parent=$(git -C "$LINUX_DIR" rev-parse HEAD^)
actual_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^{tree})
[ "$actual_local" = "$expected_local" ] || die "Linux HEAD mismatch: $actual_local"
[ "$actual_parent" = "$expected_parent" ] || die "Linux parent mismatch: $actual_parent"
[ "$actual_tree" = "$expected_tree" ] || die "Linux tree mismatch: $actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'Linux tracked tree dirty'

patch_file="$WORKSPACE_DIR/$(jq -r '.patch_queue.file' "$CONFIG")"
series="$PATCHES_DIR/patches/capsched-linux-l0/series"
patch_sha=$(sha256sum "$patch_file" | awk '{print $1}')
series_sha=$(sha256sum "$series" | awk '{print $1}')
[ "$patch_sha" = "$expected_patch_sha" ] || die 'patch hash mismatch'
[ "$series_sha" = "$expected_series_sha" ] || die 'series hash mismatch'
[ "$(tail -n 1 "$series")" = "$(basename "$patch_file")" ] || die '0014 is not series tail'

git -C "$LINUX_DIR" diff --name-only "$expected_parent..$actual_local" > "$OUT_DIR/delta-files.txt"
[ "$(cat "$OUT_DIR/delta-files.txt")" = 'kernel/sched/exec_lease_layout_probe.c' ] || die '0014 delta escaped one-file boundary'
git -C "$LINUX_DIR" diff --check "$expected_parent..$actual_local" > "$OUT_DIR/diff-check.txt"
"$LINUX_DIR/scripts/checkpatch.pl" --strict --no-tree "$patch_file" > "$OUT_DIR/checkpatch.txt"
grep -q 'total: 0 errors, 0 warnings' "$OUT_DIR/checkpatch.txt" || die 'strict checkpatch not clean'

probe_source="$LINUX_DIR/kernel/sched/exec_lease_layout_probe.c"
for symbol in \
	sched_exec_lp_smp_cache_bytes \
	sched_exec_lp_sched_entity_group_node \
	sched_exec_lp_sched_entity_on_rq \
	sched_exec_lp_sched_entity_sched_delayed \
	sched_exec_lp_sched_entity_rel_deadline \
	sched_exec_lp_sched_entity_custom_slice \
	sched_exec_lp_sched_entity_exec_start \
	sched_exec_lp_sched_entity_avg \
	sched_exec_lp_rq_ttwu_pending \
	sched_exec_lp_rq_cpu_capacity \
	sched_exec_lp_rq_nr_switches \
	sched_exec_lp_rq_lock \
	sched_exec_lp_rq_clock_task \
	sched_exec_lp_rq_balance_callback
do
	grep -Fq "$symbol" "$probe_source" || die "missing source probe: $symbol"
done
if grep -E 'EXPORT_SYMBOL|sched_exec_built_generation|sched_exec_summary_state|sched_exec_min_fresh_vruntime' "$probe_source" > "$OUT_DIR/forbidden-source.txt"; then
	die 'forbidden API or candidate field in 0014'
fi
if git -C "$LINUX_DIR" diff "$expected_parent..$actual_local" -- init/Kconfig kernel/sched/Makefile include/linux/sched.h kernel/sched/sched.h | grep -q .; then
	die 'frozen Kconfig/Makefile/structure changed'
fi

progress '12% deterministic patch queue replay'
DOMAINLEASE_RECREATE_FETCH=0 DOMAINLEASE_RECREATE_FORCE=1 \
	"$PATCHES_DIR/scripts/recreate-capsched-linux-l0.sh" "$REPLAY_DIR" > "$OUT_DIR/replay.log" 2>&1
actual_replay=$(git -C "$REPLAY_DIR" rev-parse HEAD)
replay_tree=$(git -C "$REPLAY_DIR" rev-parse HEAD^{tree})
[ "$actual_replay" = "$expected_replay" ] || die "replay commit mismatch: $actual_replay"
[ "$replay_tree" = "$expected_tree" ] || die "replay tree mismatch: $replay_tree"

prepare_config()
{
	local mode=$1 out=$2 baseline=$3
	mkdir -p "$out"
	if [ ! -f "$out/.config" ]; then cp "$baseline/.config" "$out/.config"; fi
	case "$mode" in
		off) "$LINUX_DIR/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE ;;
		on) "$LINUX_DIR/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE ;;
		probe) "$LINUX_DIR/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE ;;
		*) die "unknown mode: $mode" ;;
	esac
}

progress '20% preparing normal CONFIG off build'
prepare_config off "$OFF_O" "$BASELINE_ROOT/off"
make -C "$LINUX_DIR" O="$OFF_O" olddefconfig > "$OUT_DIR/off-olddefconfig.log" 2>&1
progress '30% building normal CONFIG off scheduler objects'
make -C "$LINUX_DIR" O="$OFF_O" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o > "$OUT_DIR/off-build.log" 2>&1
[ ! -e "$OFF_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'off build emitted probe object'

progress '45% preparing normal CONFIG on build'
prepare_config on "$ON_O" "$BASELINE_ROOT/on"
make -C "$LINUX_DIR" O="$ON_O" olddefconfig > "$OUT_DIR/on-olddefconfig.log" 2>&1
progress '55% building normal CONFIG on scheduler objects'
make -C "$LINUX_DIR" O="$ON_O" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o kernel/sched/exec_lease.o > "$OUT_DIR/on-build.log" 2>&1
[ ! -e "$ON_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'on build emitted probe object'

progress '70% preparing explicit probe build'
prepare_config probe "$PROBE_O" "$BASELINE_ROOT/probe"
make -C "$LINUX_DIR" O="$PROBE_O" olddefconfig > "$OUT_DIR/probe-olddefconfig.log" 2>&1
progress '80% building explicit 0014 probe object'
make -C "$LINUX_DIR" O="$PROBE_O" -j"$(nproc)" kernel/sched/exec_lease_layout_probe.o > "$OUT_DIR/probe-build.log" 2>&1

progress '90% extracting 49 symbols and cacheline table'
probe_obj="$PROBE_O/kernel/sched/exec_lease_layout_probe.o"
[ -s "$probe_obj" ] || die 'probe object missing'
nm -S "$probe_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $1 "\t" $2 "\t" $3 "\t" $4}' | sort -k4 > "$OUT_DIR/probe-symbols.tsv"
symbol_count=$(wc -l < "$OUT_DIR/probe-symbols.tsv")
[ "$symbol_count" = "$expected_symbols" ] || die "symbol count: expected=$expected_symbols actual=$symbol_count"

baseline_probe_obj="$BASELINE_ROOT/probe/kernel/sched/exec_lease_layout_probe.o"
[ -s "$baseline_probe_obj" ] || die 'baseline 0013 probe object missing'
nm -S "$baseline_probe_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $4}' | sort -u > "$OUT_DIR/baseline-symbol-names.txt"
awk '{print $4}' "$OUT_DIR/probe-symbols.tsv" | sort -u > "$OUT_DIR/expanded-symbol-names.txt"
comm -23 "$OUT_DIR/baseline-symbol-names.txt" "$OUT_DIR/expanded-symbol-names.txt" > "$OUT_DIR/missing-existing-symbols.txt"
comm -13 "$OUT_DIR/baseline-symbol-names.txt" "$OUT_DIR/expanded-symbol-names.txt" > "$OUT_DIR/added-symbols.txt"
existing_symbol_count=$(wc -l < "$OUT_DIR/baseline-symbol-names.txt")
missing_existing_count=$(wc -l < "$OUT_DIR/missing-existing-symbols.txt")
added_symbol_count=$(wc -l < "$OUT_DIR/added-symbols.txt")
[ "$existing_symbol_count" = 24 ] || die "baseline symbol count: $existing_symbol_count"
[ "$missing_existing_count" = 0 ] || die "existing symbols missing: $missing_existing_count"
[ "$added_symbol_count" = 27 ] || die "added symbol count: $added_symbol_count"

symbol_size()
{
	local hex
	hex=$(awk -v sym="$1" '$4 == sym {print $2}' "$OUT_DIR/probe-symbols.tsv")
	[ -n "$hex" ] || die "missing symbol: $1"
	printf '%d' "$((16#$hex))"
}
field_offset() { local n; n=$(symbol_size "${1}_offset_plus_one"); printf '%d' "$((n - 1))"; }
field_size() { symbol_size "${1}_size"; }

cache_bytes=$(symbol_size sched_exec_lp_smp_cache_bytes_size)
[ "$cache_bytes" -gt 0 ] || die 'invalid cacheline width'
table="$OUT_DIR/cacheline-table.tsv"
printf 'name\toffset\tsize\tstart_cacheline\tend_cacheline\n' > "$table"
emit_field()
{
	local name=$1 sym=$2 offset size start end
	offset=$(field_offset "$sym"); size=$(field_size "$sym")
	start=$((offset / cache_bytes)); end=$(((offset + size - 1) / cache_bytes))
	printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$offset" "$size" "$start" "$end" >> "$table"
}
emit_field sched_entity.run_node sched_exec_lp_sched_entity_run_node
emit_field sched_entity.min_vruntime sched_exec_lp_sched_entity_min_vruntime
emit_field sched_entity.vruntime sched_exec_lp_sched_entity_vruntime
emit_field sched_entity.group_node sched_exec_lp_sched_entity_group_node
emit_field sched_entity.on_rq sched_exec_lp_sched_entity_on_rq
emit_field sched_entity.sched_delayed sched_exec_lp_sched_entity_sched_delayed
emit_field sched_entity.rel_deadline sched_exec_lp_sched_entity_rel_deadline
emit_field sched_entity.custom_slice sched_exec_lp_sched_entity_custom_slice
emit_field sched_entity.exec_start sched_exec_lp_sched_entity_exec_start
emit_field sched_entity.avg sched_exec_lp_sched_entity_avg
emit_field cfs_rq.tasks_timeline sched_exec_lp_cfs_rq_tasks_timeline
emit_field cfs_rq.curr sched_exec_lp_cfs_rq_curr
emit_field cfs_rq.next sched_exec_lp_cfs_rq_next
emit_field rq.nr_running sched_exec_lp_rq_nr_running
emit_field rq.curr sched_exec_lp_rq_curr
emit_field rq.cfs sched_exec_lp_rq_cfs
emit_field rq.ttwu_pending sched_exec_lp_rq_ttwu_pending
emit_field rq.cpu_capacity sched_exec_lp_rq_cpu_capacity
emit_field rq.nr_switches sched_exec_lp_rq_nr_switches
emit_field rq.__lock sched_exec_lp_rq_lock
emit_field rq.clock_task sched_exec_lp_rq_clock_task
emit_field rq.balance_callback sched_exec_lp_rq_balance_callback
emit_field task_struct.sched_exec sched_exec_lp_task_struct_sched_exec
table_fields=$(awk 'NR > 1 {c++} END {print c+0}' "$table")
[ "$table_fields" = "$expected_table_fields" ] || die "cacheline table count: $table_fields"

sched_entity_size=$(symbol_size sched_exec_lp_sched_entity_size)
cfs_rq_size=$(symbol_size sched_exec_lp_cfs_rq_size)
rq_size=$(symbol_size sched_exec_lp_rq_size)
task_struct_size=$(symbol_size sched_exec_lp_task_struct_size)
[ "$sched_entity_size" = 320 ] && [ "$cfs_rq_size" = 384 ] && [ "$rq_size" = 3520 ] && [ "$task_struct_size" = 4160 ] || die 'arm64 structure baseline changed'
[ "$(field_offset sched_exec_lp_sched_entity_run_node)" = 16 ] || die 'run_node offset changed'
[ "$(field_offset sched_exec_lp_sched_entity_min_vruntime)" = 48 ] || die 'min_vruntime offset changed'
[ "$(field_offset sched_exec_lp_rq_nr_running)" = 0 ] || die 'nr_running offset changed'
[ "$(field_offset sched_exec_lp_rq_curr)" = 24 ] || die 'rq.curr offset changed'
[ "$(field_offset sched_exec_lp_rq_cfs)" = 128 ] || die 'rq.cfs offset changed'
[ "$(field_offset sched_exec_lp_task_struct_sched_exec)" = 1232 ] || die 'task sched_exec offset changed'

probe_sha=$(sha256sum "$probe_obj" | awk '{print $1}')
probe_size=$(stat -c '%s' "$probe_obj")
table_sha=$(sha256sum "$table" | awk '{print $1}')

jq -n --arg run_id "$RUN_ID" --arg linux_commit "$actual_local" --arg replay_commit "$actual_replay" \
	--arg linux_tree "$actual_tree" --arg patch_sha "$patch_sha" --arg series_sha "$series_sha" \
	--arg probe_object "$probe_obj" --arg probe_sha "$probe_sha" --arg table "$table" --arg table_sha "$table_sha" \
	--argjson probe_size "$probe_size" --argjson symbol_count "$symbol_count" \
	--argjson existing_symbol_count "$existing_symbol_count" --argjson added_symbol_count "$added_symbol_count" \
	--argjson cache_bytes "$cache_bytes" \
	--argjson table_fields "$table_fields" --argjson sched_entity_size "$sched_entity_size" \
	--argjson cfs_rq_size "$cfs_rq_size" --argjson rq_size "$rq_size" --argjson task_struct_size "$task_struct_size" \
	'{schema_version:1,run_id:$run_id,status:"passed",architecture:"arm64",linux_commit:$linux_commit,patch_queue_replay_commit:$replay_commit,linux_tree:$linux_tree,patch_sha256:$patch_sha,series_sha256:$series_sha,strict_checkpatch_errors:0,strict_checkpatch_warnings:0,normal_config_off_build:true,normal_config_on_build:true,normal_off_probe_object_absent:true,normal_on_probe_object_absent:true,explicit_probe_build:true,probe_object:$probe_object,probe_object_size:$probe_size,probe_object_sha256:$probe_sha,probe_symbol_count:$symbol_count,existing_probe_symbol_count:$existing_symbol_count,added_probe_symbol_count:$added_symbol_count,missing_existing_probe_symbol_count:0,smp_cache_bytes:$cache_bytes,cacheline_table:$table,cacheline_table_sha256:$table_sha,cacheline_table_field_count:$table_fields,layout:{sched_entity_size:$sched_entity_size,cfs_rq_size:$cfs_rq_size,rq_size:$rq_size,task_struct_size:$task_struct_size},runtime_behavior_change:false,hot_field_added:false,runtime_denial_correctness:false,production_protection:false,performance_claim:false,cost_claim:false}' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
progress '100% passed; result.json and cacheline table complete'
cat "$OUT_DIR/result.json"
