#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-x86_64-layout-evidence-plan/20260714T-p5a-r2-e2-x86_64-layout-plan/result.json"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e2-disposable-layout-candidate-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e2-x86_64-layout-candidate/$RUN_ID"
BUILD_ROOT=${DOMAINLEASE_P5AR2_E2_X86_BUILD_ROOT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/x86_64-cross-current/20260714T-p5a-r2-e2-x86_64-layout"}
E1_O="$BUILD_ROOT/e1"
OFF_O="$BUILD_ROOT/off"
ON_O="$BUILD_ROOT/on"
CANDIDATE_O="$BUILD_ROOT/candidate"
ARCH=x86_64
CROSS_COMPILE=x86_64-linux-gnu-
NM=${CROSS_COMPILE}nm
PROGRESS_FILE=${PROGRESS_FILE:-}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress() { [ -z "$PROGRESS_FILE" ] || printf '%s\n' "$*" > "$PROGRESS_FILE"; printf '[progress] %s\n' "$*"; }

for cmd in awk comm diff git grep join jq make "$NM" nproc sed sha256sum sort stat wc "${CROSS_COMPILE}gcc"; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR" "$BUILD_ROOT"
jq -e '.status == "passed_plan_only" and .target_architecture == "x86_64" and .e1_symbols == 51 and .candidate_total_symbols == 59 and .source_change_approved == false' "$PLAN_RESULT" >/dev/null
jq empty "$CONFIG"
progress '5% exact source, plan, patch-queue, and cross-toolchain gates'

expected_primary=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff_sha=$(jq -r '.source.diff_sha256' "$CONFIG")
actual_primary=$(git -C "$PRIMARY_DIR" rev-parse HEAD)
actual_candidate=$(git -C "$CANDIDATE_DIR" rev-parse HEAD)
actual_parent=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)
actual_tree=$(git -C "$CANDIDATE_DIR" rev-parse HEAD^{tree})
[ "$actual_primary" = "$expected_primary" ] || die "primary commit mismatch: $actual_primary"
[ "$actual_candidate" = "$expected_candidate" ] || die "candidate commit mismatch: $actual_candidate"
[ "$actual_parent" = "$expected_primary" ] || die "candidate parent mismatch: $actual_parent"
[ "$actual_tree" = "$expected_tree" ] || die "candidate tree mismatch: $actual_tree"
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] || die 'candidate dirty'
series_tail=$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")
[ "$series_tail" = '0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die "patch queue moved: $series_tail"

git -C "$CANDIDATE_DIR" diff "$expected_primary..$expected_candidate" > "$OUT_DIR/candidate.diff"
diff_sha=$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')
[ "$diff_sha" = "$expected_diff_sha" ] || die "candidate diff hash mismatch: $diff_sha"
git -C "$CANDIDATE_DIR" diff --name-only "$expected_primary..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' include/linux/sched.h init/Kconfig kernel/sched/exec_lease_layout_probe.c kernel/sched/sched.h > "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" > "$OUT_DIR/delta-files.diff" || die 'candidate escaped four-file scope'

compiler_version=$("${CROSS_COMPILE}gcc" -dumpfullversion -dumpversion)
compiler_machine=$("${CROSS_COMPILE}gcc" -dumpmachine)
[ "$compiler_machine" = x86_64-linux-gnu ] || die "wrong compiler target: $compiler_machine"
printf '%s\n' "$compiler_version" > "$OUT_DIR/compiler-version.txt"
printf '%s\n' "$compiler_machine" > "$OUT_DIR/compiler-machine.txt"

prepare_config()
{
	local source=$1 mode=$2 out=$3
	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" defconfig > "$OUT_DIR/$mode-defconfig.log" 2>&1
	case "$mode" in
		e1) "$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE ;;
		off) "$source/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		on) "$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		candidate) "$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_LAYOUT_CANDIDATE ;;
		*) die "unknown mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig > "$OUT_DIR/$mode-olddefconfig.log" 2>&1
	grep -q '^CONFIG_X86_64=y$' "$out/.config" || die "$mode config is not x86_64"
}

progress '12% preparing fresh x86_64 E1 expanded-probe baseline'
prepare_config "$PRIMARY_DIR" e1 "$E1_O"
grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$E1_O/.config" || die 'E1 probe config not enabled'
progress '22% building fresh x86_64 E1 probe object'
make -C "$PRIMARY_DIR" O="$E1_O" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" kernel/sched/exec_lease_layout_probe.o > "$OUT_DIR/e1-build.log" 2>&1

progress '35% preparing and building x86_64 normal CONFIG off objects'
prepare_config "$CANDIDATE_DIR" off "$OFF_O"
if grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE=y$' "$OFF_O/.config"; then die 'off config enabled candidate'; fi
make -C "$CANDIDATE_DIR" O="$OFF_O" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o > "$OUT_DIR/off-build.log" 2>&1
[ ! -e "$OFF_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'off build emitted probe object'

progress '50% preparing and building x86_64 normal CONFIG on candidate-disabled objects'
prepare_config "$CANDIDATE_DIR" on "$ON_O"
if grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE=y$' "$ON_O/.config"; then die 'on config enabled candidate'; fi
make -C "$CANDIDATE_DIR" O="$ON_O" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" kernel/sched/fair.o kernel/sched/core.o kernel/sched/exec_lease.o > "$OUT_DIR/on-build.log" 2>&1
[ ! -e "$ON_O/kernel/sched/exec_lease_layout_probe.o" ] || die 'on build emitted probe object'
for obj in "$OFF_O/kernel/sched/fair.o" "$OFF_O/kernel/sched/core.o" "$ON_O/kernel/sched/fair.o" "$ON_O/kernel/sched/core.o" "$ON_O/kernel/sched/exec_lease.o"; do
	if "$NM" "$obj" | grep -E 'sched_exec_(summary|min_fresh|built_generation)' >> "$OUT_DIR/forbidden-normal-symbols.txt"; then die "normal object contains candidate symbol: $obj"; fi
done

progress '65% preparing explicit x86_64 candidate probe'
prepare_config "$CANDIDATE_DIR" candidate "$CANDIDATE_O"
grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_CANDIDATE=y$' "$CANDIDATE_O/.config" || die 'candidate config not enabled'
progress '75% building explicit x86_64 candidate probe object'
make -C "$CANDIDATE_DIR" O="$CANDIDATE_O" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" kernel/sched/exec_lease_layout_probe.o > "$OUT_DIR/candidate-build.log" 2>&1

progress '88% comparing x86_64 E1 and candidate symbol/layout evidence'
e1_obj="$E1_O/kernel/sched/exec_lease_layout_probe.o"
candidate_obj="$CANDIDATE_O/kernel/sched/exec_lease_layout_probe.o"
[ -s "$e1_obj" ] && [ -s "$candidate_obj" ] || die 'probe object missing'
"$NM" -S "$e1_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $4 "\t" $2}' | sort -k1 > "$OUT_DIR/e1-symbol-values.tsv"
"$NM" -S "$candidate_obj" | awk '$4 ~ /^sched_exec_lp_/ {print $4 "\t" $2}' | sort -k1 > "$OUT_DIR/candidate-symbol-values.tsv"
awk '{print $1}' "$OUT_DIR/e1-symbol-values.tsv" > "$OUT_DIR/e1-symbol-names.txt"
awk '{print $1}' "$OUT_DIR/candidate-symbol-values.tsv" > "$OUT_DIR/candidate-symbol-names.txt"
comm -23 "$OUT_DIR/e1-symbol-names.txt" "$OUT_DIR/candidate-symbol-names.txt" > "$OUT_DIR/missing-e1-symbols.txt"
comm -13 "$OUT_DIR/e1-symbol-names.txt" "$OUT_DIR/candidate-symbol-names.txt" > "$OUT_DIR/added-candidate-symbols.txt"
join "$OUT_DIR/e1-symbol-values.tsv" "$OUT_DIR/candidate-symbol-values.tsv" | awk '$2 != $3 {print}' > "$OUT_DIR/changed-e1-symbol-values.txt"
e1_count=$(wc -l < "$OUT_DIR/e1-symbol-names.txt")
candidate_count=$(wc -l < "$OUT_DIR/candidate-symbol-names.txt")
missing_count=$(wc -l < "$OUT_DIR/missing-e1-symbols.txt")
added_count=$(wc -l < "$OUT_DIR/added-candidate-symbols.txt")
changed_count=$(wc -l < "$OUT_DIR/changed-e1-symbol-values.txt")
[ "$e1_count" = 51 ] || die "E1 symbol count: $e1_count"
[ "$candidate_count" = 59 ] || die "candidate symbol count: $candidate_count"
[ "$missing_count" = 0 ] || die "missing E1 symbols: $missing_count"
[ "$added_count" = 8 ] || die "added candidate symbols: $added_count"
[ "$changed_count" = 0 ] || die "changed E1 values: $changed_count"
jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort > "$OUT_DIR/expected-added-symbols.txt"
diff -u "$OUT_DIR/expected-added-symbols.txt" "$OUT_DIR/added-candidate-symbols.txt" > "$OUT_DIR/added-symbols.diff" || die 'candidate symbol set mismatch'

symbol_value()
{
	local file=$1 sym=$2 hex
	hex=$(awk -v sym="$sym" '$1 == sym {print $2}' "$file")
	[ -n "$hex" ] || die "missing symbol: $sym"
	printf '%d' "$((16#$hex))"
}
e1_value() { symbol_value "$OUT_DIR/e1-symbol-values.tsv" "$1"; }
candidate_value() { symbol_value "$OUT_DIR/candidate-symbol-values.tsv" "$1"; }
candidate_offset() { local n; n=$(candidate_value "${1}_offset_plus_one"); printf '%d' "$((n - 1))"; }
candidate_size() { candidate_value "${1}_size"; }

e1_sched_entity=$(e1_value sched_exec_lp_sched_entity_size)
e1_cfs_rq=$(e1_value sched_exec_lp_cfs_rq_size)
e1_rq=$(e1_value sched_exec_lp_rq_size)
e1_task=$(e1_value sched_exec_lp_task_struct_size)
[ "$e1_sched_entity" = 320 ] || die "x86_64 E1 sched_entity baseline: $e1_sched_entity"
[ "$e1_cfs_rq" = 384 ] || die "x86_64 E1 cfs_rq baseline: $e1_cfs_rq"
[ "$e1_rq" = 3392 ] || die "x86_64 E1 rq baseline: $e1_rq"
[ "$e1_task" = 3328 ] || die "x86_64 E1 task_struct baseline: $e1_task"

sched_entity_size=$(candidate_value sched_exec_lp_sched_entity_size)
cfs_rq_size=$(candidate_value sched_exec_lp_cfs_rq_size)
rq_size=$(candidate_value sched_exec_lp_rq_size)
task_size=$(candidate_value sched_exec_lp_task_struct_size)
sched_entity_delta=$((sched_entity_size - e1_sched_entity))
cfs_rq_delta=$((cfs_rq_size - e1_cfs_rq))
rq_delta=$((rq_size - e1_rq))
task_delta=$((task_size - e1_task))
[ "$sched_entity_delta" -ge 0 ] && [ "$sched_entity_delta" -le 8 ] || die "sched_entity delta: $sched_entity_delta"
[ "$cfs_rq_delta" = 0 ] || die "cfs_rq delta: $cfs_rq_delta"
[ "$rq_delta" -ge 0 ] && [ "$rq_delta" -le 32 ] || die "rq delta: $rq_delta"
[ "$task_delta" = 0 ] || die "task_struct delta: $task_delta"

summary_valid_offset=$(candidate_offset sched_exec_lp_sched_entity_summary_valid)
summary_valid_size=$(candidate_size sched_exec_lp_sched_entity_summary_valid)
summary_min_offset=$(candidate_offset sched_exec_lp_sched_entity_summary_min)
summary_min_size=$(candidate_size sched_exec_lp_sched_entity_summary_min)
rq_state_offset=$(candidate_offset sched_exec_lp_rq_summary_state)
rq_state_size=$(candidate_size sched_exec_lp_rq_summary_state)
rq_generation_offset=$(candidate_offset sched_exec_lp_rq_built_generation)
rq_generation_size=$(candidate_size sched_exec_lp_rq_built_generation)
[ "$((summary_valid_offset + summary_valid_size))" -le "$sched_entity_size" ] || die 'summary validity exceeds sched_entity'
[ "$((summary_min_offset + summary_min_size))" -le "$sched_entity_size" ] || die 'summary minimum exceeds sched_entity'
[ "$((rq_state_offset + rq_state_size))" -le "$rq_size" ] || die 'rq state exceeds rq'
[ "$((rq_generation_offset + rq_generation_size))" -le "$rq_size" ] || die 'rq generation exceeds rq'

cache_bytes=$(candidate_value sched_exec_lp_smp_cache_bytes_size)
table="$OUT_DIR/cacheline-table.tsv"
printf 'name\toffset\tsize\tstart_cacheline\tend_cacheline\n' > "$table"
emit_field()
{
	local name=$1 sym=$2 offset size start end
	offset=$(candidate_offset "$sym"); size=$(candidate_size "$sym")
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

e1_sha=$(sha256sum "$e1_obj" | awk '{print $1}')
candidate_sha=$(sha256sum "$candidate_obj" | awk '{print $1}')
table_sha=$(sha256sum "$table" | awk '{print $1}')
e1_size=$(stat -c '%s' "$e1_obj")
candidate_object_size=$(stat -c '%s' "$candidate_obj")

jq -n \
	--arg run_id "$RUN_ID" --arg compiler_version "$compiler_version" --arg compiler_machine "$compiler_machine" \
	--arg primary_commit "$actual_primary" --arg candidate_commit "$actual_candidate" --arg candidate_tree "$actual_tree" \
	--arg series_tail "$series_tail" --arg diff_sha "$diff_sha" --arg e1_obj "$e1_obj" --arg e1_sha "$e1_sha" \
	--arg candidate_obj "$candidate_obj" --arg candidate_sha "$candidate_sha" --arg table "$table" --arg table_sha "$table_sha" \
	--argjson e1_size "$e1_size" --argjson candidate_object_size "$candidate_object_size" \
	--argjson e1_count "$e1_count" --argjson candidate_count "$candidate_count" --argjson missing_count "$missing_count" \
	--argjson added_count "$added_count" --argjson changed_count "$changed_count" --argjson cache_bytes "$cache_bytes" \
	--argjson table_fields "$table_fields" --argjson sched_entity_size "$sched_entity_size" --argjson cfs_rq_size "$cfs_rq_size" \
	--argjson rq_size "$rq_size" --argjson task_size "$task_size" --argjson sched_entity_delta "$sched_entity_delta" \
	--argjson cfs_rq_delta "$cfs_rq_delta" --argjson rq_delta "$rq_delta" --argjson task_delta "$task_delta" \
	--argjson summary_valid_offset "$summary_valid_offset" --argjson summary_valid_size "$summary_valid_size" \
	--argjson summary_min_offset "$summary_min_offset" --argjson summary_min_size "$summary_min_size" \
	--argjson rq_state_offset "$rq_state_offset" --argjson rq_state_size "$rq_state_size" \
	--argjson rq_generation_offset "$rq_generation_offset" --argjson rq_generation_size "$rq_generation_size" \
	'{schema_version:1,run_id:$run_id,status:"passed",architecture:"x86_64",build_host_architecture:"arm64",cross_compiled:true,compiler:{machine:$compiler_machine,version:$compiler_version},primary_linux_commit:$primary_commit,candidate_commit:$candidate_commit,candidate_tree:$candidate_tree,primary_patch_queue_tail:$series_tail,candidate_diff_sha256:$diff_sha,fresh_e1_probe_build:true,normal_config_off_build:true,normal_config_on_candidate_disabled_build:true,normal_probe_object_absent:true,normal_candidate_symbols_absent:true,explicit_candidate_probe_build:true,e1_probe_object:$e1_obj,e1_probe_object_size:$e1_size,e1_probe_object_sha256:$e1_sha,candidate_probe_object:$candidate_obj,candidate_probe_object_size:$candidate_object_size,candidate_probe_object_sha256:$candidate_sha,e1_probe_symbol_count:$e1_count,candidate_probe_symbol_count:$candidate_count,added_candidate_symbol_count:$added_count,missing_e1_symbol_count:$missing_count,changed_e1_symbol_value_count:$changed_count,smp_cache_bytes:$cache_bytes,cacheline_table:$table,cacheline_table_sha256:$table_sha,cacheline_table_field_count:$table_fields,layout:{sched_entity_size:$sched_entity_size,cfs_rq_size:$cfs_rq_size,rq_size:$rq_size,task_struct_size:$task_size},layout_delta:{sched_entity:$sched_entity_delta,cfs_rq:$cfs_rq_delta,rq:$rq_delta,task_struct:$task_delta},candidate_layout:{sched_entity_summary_valid:{offset:$summary_valid_offset,size:$summary_valid_size},sched_entity_summary_min:{offset:$summary_min_offset,size:$summary_min_size},rq_summary_state:{offset:$rq_state_offset,size:$rq_state_size},rq_built_generation:{offset:$rq_generation_offset,size:$rq_generation_size}},baseline_reproduced:true,protected_e1_values_unchanged:true,candidate_fields_within_containing_structures:true,x86_64_layout_envelope_passed:true,arm64_runtime_inferred:false,x86_64_runtime_evidence:false,primary_linux_changed:false,patch_queue_changed:false,layout_candidate_accepted:false,e3_rebuild_approved:false,runtime_behavior_change:false,runtime_denial_correctness:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
progress '100% passed; x86_64 E2 layout envelope and 59-symbol comparison complete'
cat "$OUT_DIR/result.json"
