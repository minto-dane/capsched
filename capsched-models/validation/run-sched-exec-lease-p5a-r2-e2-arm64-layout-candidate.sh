#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_LINUX_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR=${DOMAINLEASE_P5AR2_E2_CANDIDATE_DIR:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"}
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-v1.json"
PLAN_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-plan/20260713T-p5a-r2-e2-layout-plan/result.json"
E1_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-0014-expanded-layout-probe/20260713T-p5a-r2-0014-expanded-probe/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-arm64-layout-candidate/$RUN_ID"
E1_BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/20260713T-p5a-r2-0014-expanded-probe"
BUILD_ROOT=${DOMAINLEASE_P5AR2_E2_BUILD_ROOT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/20260713T-p5a-r2-e2-layout"}
OFF_O="$BUILD_ROOT/off"
ON_O="$BUILD_ROOT/on"
CANDIDATE_O="$BUILD_ROOT/candidate"
PROGRESS_FILE=${PROGRESS_FILE:-}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress() { [ -z "$PROGRESS_FILE" ] || printf '%s\n' "$*" > "$PROGRESS_FILE"; printf '[progress] %s\n' "$*"; }

for cmd in awk comm diff git grep join jq make nm nproc sed sha256sum sort stat wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR" "$BUILD_ROOT"
jq empty "$CONFIG"
jq -e '.status == "passed_plan_only" and .disposable_worktree_may_be_created == true and .primary_linux_change_approved == false and .patch_queue_change_approved == false' "$PLAN_RESULT" >/dev/null
jq -e '.status == "passed" and .architecture == "arm64" and .probe_symbol_count == 51 and .cacheline_table_field_count == 23' "$E1_RESULT" >/dev/null
progress '5% exact source, primary-boundary, and metadata gates'

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff_sha=$(jq -r '.source.diff_sha256' "$CONFIG")
actual_candidate=$(git -C "$CANDIDATE_DIR" rev-parse HEAD)
actual_parent=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)
actual_tree=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^{tree})
[ "$actual_candidate" = "$expected_candidate" ] || die "candidate commit mismatch: $actual_candidate"
[ "$actual_parent" = "$expected_parent" ] || die "candidate parent mismatch: $actual_parent"
[ "$actual_tree" = "$expected_tree" ] || die "candidate tree mismatch: $actual_tree"
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] || die 'candidate tree dirty'

primary_commit=$(git -C "$PRIMARY_LINUX_DIR" rev-parse HEAD)
[ "$primary_commit" = "$expected_parent" ] || die "primary Linux moved: $primary_commit"
[ -z "$(git -C "$PRIMARY_LINUX_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux tree dirty'
series="$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series"
series_tail=$(tail -n 1 "$series")
[ "$series_tail" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die "primary patch queue moved: $series_tail"

git -C "$CANDIDATE_DIR" diff --name-only "$expected_parent..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' \
	'include/linux/sched.h' \
	'init/Kconfig' \
	'kernel/sched/exec_lease_layout_probe.c' \
	'kernel/sched/sched.h' > "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" > "$OUT_DIR/delta-files.diff" || die 'candidate escaped exact four-file scope'
git -C "$CANDIDATE_DIR" diff --check "$expected_parent..$expected_candidate" > "$OUT_DIR/diff-check.txt"
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" > "$OUT_DIR/candidate.diff"
diff_sha=$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')
[ "$diff_sha" = "$expected_diff_sha" ] || die "candidate diff hash mismatch: $diff_sha"
"$CANDIDATE_DIR/scripts/checkpatch.pl" --strict --no-tree "$OUT_DIR/candidate.diff" > "$OUT_DIR/checkpatch.txt"
grep -q 'total: 0 errors, 0 warnings' "$OUT_DIR/checkpatch.txt" || die 'strict checkpatch not clean'

kconfig="$CANDIDATE_DIR/init/Kconfig"
grep -A12 '^config SCHED_EXEC_LEASE_LAYOUT_CANDIDATE$' "$kconfig" > "$OUT_DIR/candidate-kconfig.txt"
grep -q '^[[:space:]]*depends on SCHED_EXEC_LEASE_LAYOUT_PROBE$' "$OUT_DIR/candidate-kconfig.txt" || die 'candidate dependency mismatch'
grep -q '^[[:space:]]*default n$' "$OUT_DIR/candidate-kconfig.txt" || die 'candidate is not default off'
for field in sched_exec_summary_valid sched_exec_min_fresh_vruntime sched_exec_summary_state sched_exec_built_generation; do
	count=$(git -C "$CANDIDATE_DIR" grep -l "$field" -- include/linux/sched.h kernel/sched/sched.h kernel/sched/exec_lease_layout_probe.c | wc -l | tr -d ' ')
	[ "$count" -ge 2 ] || die "candidate field/probe missing: $field"
done
if git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" -- kernel/sched/Makefile kernel/sched/core.c kernel/sched/fair.c kernel/sched/exec_lease.c | grep -q .; then
	die 'candidate modified build graph or runtime scheduler source'
fi
if grep -E 'EXPORT_SYMBOL|sched_exec_rebuild|sched_exec_publish|sched_exec_fanout' "$OUT_DIR/candidate.diff" > "$OUT_DIR/forbidden-source.txt"; then
	die 'candidate added exported or runtime rebuild source'
fi

prepare_config()
{
	local mode=$1 out=$2 baseline=$3
	mkdir -p "$out"
	cp "$baseline/.config" "$out/.config"
	case "$mode" in
		off) "$CANDIDATE_DIR/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		on) "$CANDIDATE_DIR/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		candidate) "$CANDIDATE_DIR/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		*) die "unknown mode: $mode" ;;
	esac
}

progress '15% preparing normal CONFIG off build'
prepare_config off "$OFF_O" "$E1_BUILD_ROOT/off"
make -C "$CANDIDATE_DIR" O="$OFF_O" olddefconfig > "$OUT_DIR/off-olddefconfig.log" 2>&1
grep -q '^# CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE is not set$' "$OFF_O/.config" || die 'off config candidate state wrong'
progress '25% building normal CONFIG off scheduler objects'
make -C "$CANDIDATE_DIR" O="$OFF_O" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o > "$OUT_DIR/off-build.log" 2>&1
[ ! -e "$OFF_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'off build emitted probe object'

progress '40% preparing normal CONFIG on, candidate disabled build'
prepare_config on "$ON_O" "$E1_BUILD_ROOT/on"
make -C "$CANDIDATE_DIR" O="$ON_O" olddefconfig > "$OUT_DIR/on-olddefconfig.log" 2>&1
grep -q '^# CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE is not set$' "$ON_O/.config" || die 'on config candidate state wrong'
progress '50% building normal CONFIG on scheduler objects'
make -C "$CANDIDATE_DIR" O="$ON_O" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o kernel/sched/exec_lease.o > "$OUT_DIR/on-build.log" 2>&1
[ ! -e "$ON_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'on build emitted probe object'
for obj in "$OFF_O/kernel/sched/fair.o" "$OFF_O/kernel/sched/core.o" "$ON_O/kernel/sched/fair.o" "$ON_O/kernel/sched/core.o" "$ON_O/kernel/sched/exec_lease.o"; do
	if nm "$obj" | grep -E 'sched_exec_(summary|min_fresh|built_generation)' >> "$OUT_DIR/forbidden-normal-symbols.txt"; then
		die "normal object contains candidate symbol: $obj"
	fi
done

progress '65% preparing explicit E2 candidate probe build'
prepare_config candidate "$CANDIDATE_O" "$E1_BUILD_ROOT/probe"
make -C "$CANDIDATE_DIR" O="$CANDIDATE_O" olddefconfig > "$OUT_DIR/candidate-olddefconfig.log" 2>&1
grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE=y$' "$CANDIDATE_O/.config" || die 'candidate config not enabled'
progress '75% building explicit E2 candidate probe object'
make -C "$CANDIDATE_DIR" O="$CANDIDATE_O" -j"$(nproc)" kernel/sched/exec_lease_layout_probe.o > "$OUT_DIR/candidate-build.log" 2>&1

progress '88% comparing 51 baseline plus 8 candidate symbols'
probe_obj="$CANDIDATE_O/kernel/sched/exec_lease_layout_probe.o"
[ -s "$probe_obj" ] || die 'candidate probe object missing'
baseline_probe_obj=$(jq -r '.probe_object' "$E1_RESULT")
baseline_probe_sha=$(jq -r '.probe_object_sha256' "$E1_RESULT")
[ -s "$baseline_probe_obj" ] || die 'E1 probe object missing'
[ "$(sha256sum "$baseline_probe_obj" | awk '{print $1}')" = "$baseline_probe_sha" ] || die 'E1 probe object hash mismatch'

nm -S "$baseline_probe_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $4 "\t" $2}' | sort -k1 > "$OUT_DIR/e1-symbol-values.tsv"
nm -S "$probe_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $4 "\t" $2}' | sort -k1 > "$OUT_DIR/candidate-symbol-values.tsv"
awk '{print $1}' "$OUT_DIR/e1-symbol-values.tsv" > "$OUT_DIR/e1-symbol-names.txt"
awk '{print $1}' "$OUT_DIR/candidate-symbol-values.tsv" > "$OUT_DIR/candidate-symbol-names.txt"
comm -23 "$OUT_DIR/e1-symbol-names.txt" "$OUT_DIR/candidate-symbol-names.txt" > "$OUT_DIR/missing-e1-symbols.txt"
comm -13 "$OUT_DIR/e1-symbol-names.txt" "$OUT_DIR/candidate-symbol-names.txt" > "$OUT_DIR/added-candidate-symbols.txt"
join "$OUT_DIR/e1-symbol-values.tsv" "$OUT_DIR/candidate-symbol-values.tsv" | awk '$2 != $3 {print}' > "$OUT_DIR/changed-e1-symbol-values.txt"
baseline_count=$(wc -l < "$OUT_DIR/e1-symbol-names.txt")
candidate_count=$(wc -l < "$OUT_DIR/candidate-symbol-names.txt")
missing_count=$(wc -l < "$OUT_DIR/missing-e1-symbols.txt")
added_count=$(wc -l < "$OUT_DIR/added-candidate-symbols.txt")
changed_e1_count=$(wc -l < "$OUT_DIR/changed-e1-symbol-values.txt")
[ "$baseline_count" = 51 ] || die "E1 symbol count: $baseline_count"
[ "$candidate_count" = 59 ] || die "candidate symbol count: $candidate_count"
[ "$missing_count" = 0 ] || die "missing E1 symbols: $missing_count"
[ "$added_count" = 8 ] || die "candidate added symbols: $added_count"
[ "$changed_e1_count" = 0 ] || die "E1 symbol values changed: $changed_e1_count"
jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort > "$OUT_DIR/expected-added-candidate-symbols.txt"
diff -u "$OUT_DIR/expected-added-candidate-symbols.txt" "$OUT_DIR/added-candidate-symbols.txt" > "$OUT_DIR/added-symbols.diff" || die 'candidate symbol set mismatch'

symbol_size()
{
	local hex
	hex=$(awk -v sym="$1" '$1 == sym {print $2}' "$OUT_DIR/candidate-symbol-values.tsv")
	[ -n "$hex" ] || die "missing symbol: $1"
	printf '%d' "$((16#$hex))"
}
field_offset() { local n; n=$(symbol_size "${1}_offset_plus_one"); printf '%d' "$((n - 1))"; }
field_size() { symbol_size "${1}_size"; }

cache_bytes=$(symbol_size sched_exec_lp_smp_cache_bytes_size)
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
emit_field sched_entity.sched_exec_summary_valid sched_exec_lp_sched_entity_summary_valid
emit_field sched_entity.sched_exec_min_fresh_vruntime sched_exec_lp_sched_entity_summary_min
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
emit_field rq.sched_exec_summary_state sched_exec_lp_rq_summary_state
emit_field rq.sched_exec_built_generation sched_exec_lp_rq_built_generation
emit_field task_struct.sched_exec sched_exec_lp_task_struct_sched_exec
table_fields=$(awk 'NR > 1 {c++} END {print c+0}' "$table")
[ "$table_fields" = 27 ] || die "cacheline table count: $table_fields"

sched_entity_size=$(symbol_size sched_exec_lp_sched_entity_size)
cfs_rq_size=$(symbol_size sched_exec_lp_cfs_rq_size)
rq_size=$(symbol_size sched_exec_lp_rq_size)
task_struct_size=$(symbol_size sched_exec_lp_task_struct_size)
sched_entity_delta=$((sched_entity_size - 320))
cfs_rq_delta=$((cfs_rq_size - 384))
rq_delta=$((rq_size - 3520))
task_struct_delta=$((task_struct_size - 4160))
[ "$sched_entity_delta" -ge 0 ] && [ "$sched_entity_delta" -le 8 ] || die "sched_entity delta: $sched_entity_delta"
[ "$cfs_rq_delta" = 0 ] || die "cfs_rq delta: $cfs_rq_delta"
[ "$rq_delta" -ge 0 ] && [ "$rq_delta" -le 32 ] || die "rq delta: $rq_delta"
[ "$task_struct_delta" = 0 ] || die "task_struct delta: $task_struct_delta"

[ "$(field_offset sched_exec_lp_sched_entity_run_node)" = 16 ] || die 'run_node offset shifted'
[ "$(field_offset sched_exec_lp_sched_entity_min_vruntime)" = 48 ] || die 'min_vruntime offset shifted'
[ "$(field_offset sched_exec_lp_rq_nr_running)" = 0 ] || die 'nr_running offset shifted'
[ "$(field_offset sched_exec_lp_rq_curr)" = 24 ] || die 'rq.curr offset shifted'
[ "$(field_offset sched_exec_lp_rq_cfs)" = 128 ] || die 'rq.cfs offset shifted'
[ "$(field_offset sched_exec_lp_rq_clock_task)" = 2752 ] || die 'rq.clock_task offset shifted'
[ "$(field_offset sched_exec_lp_task_struct_sched_exec)" = 1232 ] || die 'task sched_exec offset shifted'
[ "$(field_offset sched_exec_lp_sched_entity_summary_valid)" = 92 ] && [ "$(field_size sched_exec_lp_sched_entity_summary_valid)" = 1 ] || die 'summary valid layout mismatch'
[ "$(field_offset sched_exec_lp_sched_entity_summary_min)" = 200 ] && [ "$(field_size sched_exec_lp_sched_entity_summary_min)" = 8 ] || die 'summary min layout mismatch'
[ "$(field_offset sched_exec_lp_rq_summary_state)" = 3508 ] && [ "$(field_size sched_exec_lp_rq_summary_state)" = 1 ] || die 'rq summary state layout mismatch'
[ "$(field_offset sched_exec_lp_rq_built_generation)" = 3512 ] && [ "$(field_size sched_exec_lp_rq_built_generation)" = 8 ] || die 'rq generation layout mismatch'

probe_sha=$(sha256sum "$probe_obj" | awk '{print $1}')
probe_size=$(stat -c '%s' "$probe_obj")
table_sha=$(sha256sum "$table" | awk '{print $1}')
off_fair_sha=$(sha256sum "$OFF_O/kernel/sched/fair.o" | awk '{print $1}')
off_core_sha=$(sha256sum "$OFF_O/kernel/sched/core.o" | awk '{print $1}')
on_fair_sha=$(sha256sum "$ON_O/kernel/sched/fair.o" | awk '{print $1}')
on_core_sha=$(sha256sum "$ON_O/kernel/sched/core.o" | awk '{print $1}')
on_exec_sha=$(sha256sum "$ON_O/kernel/sched/exec_lease.o" | awk '{print $1}')

jq -n \
	--arg run_id "$RUN_ID" --arg candidate_commit "$actual_candidate" --arg candidate_tree "$actual_tree" \
	--arg primary_commit "$primary_commit" --arg series_tail "$series_tail" --arg diff_sha "$diff_sha" \
	--arg probe_object "$probe_obj" --arg probe_sha "$probe_sha" --arg table "$table" --arg table_sha "$table_sha" \
	--arg off_fair_sha "$off_fair_sha" --arg off_core_sha "$off_core_sha" --arg on_fair_sha "$on_fair_sha" \
	--arg on_core_sha "$on_core_sha" --arg on_exec_sha "$on_exec_sha" \
	--argjson probe_size "$probe_size" --argjson baseline_count "$baseline_count" --argjson candidate_count "$candidate_count" \
	--argjson added_count "$added_count" --argjson missing_count "$missing_count" --argjson changed_e1_count "$changed_e1_count" \
	--argjson cache_bytes "$cache_bytes" --argjson table_fields "$table_fields" \
	--argjson sched_entity_size "$sched_entity_size" --argjson cfs_rq_size "$cfs_rq_size" \
	--argjson rq_size "$rq_size" --argjson task_struct_size "$task_struct_size" \
	--argjson sched_entity_delta "$sched_entity_delta" --argjson cfs_rq_delta "$cfs_rq_delta" \
	--argjson rq_delta "$rq_delta" --argjson task_struct_delta "$task_struct_delta" \
	'{schema_version:1,run_id:$run_id,status:"passed",architecture:"arm64",candidate_commit:$candidate_commit,candidate_tree:$candidate_tree,primary_linux_commit:$primary_commit,primary_patch_queue_tail:$series_tail,candidate_diff_sha256:$diff_sha,strict_checkpatch_errors:0,strict_checkpatch_warnings:0,normal_config_off_build:true,normal_config_on_candidate_disabled_build:true,normal_off_probe_object_absent:true,normal_on_probe_object_absent:true,normal_candidate_symbols_absent:true,explicit_candidate_probe_build:true,probe_object:$probe_object,probe_object_size:$probe_size,probe_object_sha256:$probe_sha,e1_probe_symbol_count:$baseline_count,candidate_probe_symbol_count:$candidate_count,added_candidate_symbol_count:$added_count,missing_e1_symbol_count:$missing_count,changed_e1_symbol_value_count:$changed_e1_count,smp_cache_bytes:$cache_bytes,cacheline_table:$table,cacheline_table_sha256:$table_sha,cacheline_table_field_count:$table_fields,layout:{sched_entity_size:$sched_entity_size,cfs_rq_size:$cfs_rq_size,rq_size:$rq_size,task_struct_size:$task_struct_size},layout_delta:{sched_entity:$sched_entity_delta,cfs_rq:$cfs_rq_delta,rq:$rq_delta,task_struct:$task_struct_delta},candidate_layout:{sched_entity_summary_valid:{offset:92,size:1},sched_entity_summary_min:{offset:200,size:8},rq_summary_state:{offset:3508,size:1},rq_built_generation:{offset:3512,size:8}},protected_offsets_unchanged:true,candidate_fields_within_containing_structures:true,arm64_layout_envelope_passed:true,objects:{off_fair_sha256:$off_fair_sha,off_core_sha256:$off_core_sha,on_fair_sha256:$on_fair_sha,on_core_sha256:$on_core_sha,on_exec_lease_sha256:$on_exec_sha},primary_linux_changed:false,patch_queue_changed:false,x86_64_e2_complete:false,layout_candidate_accepted:false,e3_rebuild_approved:false,runtime_behavior_change:false,runtime_denial_correctness:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
progress '100% passed; arm64 E2 layout envelope and 59-symbol comparison complete'
cat "$OUT_DIR/result.json"
