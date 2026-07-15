#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r3-e2-private-layout-candidate-v1.json"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e2-source-gate/20260715T-p5a-r3-e2-source-gate/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e2-dual-arch-layout/$RUN_ID"
BUILD_ROOT=${DOMAINLEASE_P5AR3_E2_BUILD_ROOT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r3-e2-dual-arch/$RUN_ID"}
PROGRESS_FILE=${PROGRESS_FILE:-}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress() { [ -z "$PROGRESS_FILE" ] || printf '%s\n' "$*" > "$PROGRESS_FILE"; printf '[progress] %s\n' "$*"; }

for cmd in awk comm diff gcc git grep join jq make nm nproc readelf sed sha256sum sort stat strings wc x86_64-linux-gnu-gcc x86_64-linux-gnu-nm x86_64-linux-gnu-readelf; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR" "$BUILD_ROOT"
jq empty "$CONFIG"
jq -e '
  .status == "passed" and
  .candidate_commit == "63313b329e1d44901acfce30698613c38615c8d5" and
  .exact_two_file_boundary == true and
  .strict_checkpatch_errors == 0 and
  .strict_checkpatch_warnings == 0 and
  .strict_checkpatch_checks == 0 and
  .expected_private_symbol_count == 43 and
  .existing_expanded_probe_values_required == 51 and
  .dual_arch_layout_build_may_start == true and
  .e3_source_may_start == false
' "$SOURCE_GATE" >/dev/null

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_parent" ] || die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] || die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$expected_parent" ] || die 'candidate parent moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] || die 'candidate tree moved'
source_manifest="$OUT_DIR/source-file-hashes.tsv"
printf 'tree\tpath\texpected_blob\tworking_blob\n' > "$source_manifest"
verify_source_file()
{
	local label=$1 tree=$2 path=$3 expected_blob working_blob
	expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
	working_blob=$(git -C "$tree" hash-object "$path")
	printf '%s\t%s\t%s\t%s\n' "$label" "$path" "$expected_blob" "$working_blob" >> "$source_manifest"
	[ "$working_blob" = "$expected_blob" ] || die "$label source content differs from HEAD: $path"
}
for tree_spec in "primary:$PRIMARY_DIR" "candidate:$CANDIDATE_DIR"; do
	label=${tree_spec%%:*}
	tree=${tree_spec#*:}
	for path in \
		init/Kconfig \
		include/linux/sched.h \
		include/linux/sched_exec_lease.h \
		include/linux/cpumask.h \
		include/linux/refcount.h \
		include/linux/stddef.h \
		include/linux/workqueue.h \
		include/linux/xarray.h \
		kernel/sched/Makefile \
		kernel/sched/sched.h \
		kernel/sched/core.c \
		kernel/sched/fair.c \
		kernel/sched/exec_lease.c \
		kernel/sched/exec_lease_layout_probe.c; do
		verify_source_file "$label" "$tree" "$path"
	done
done
jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort > "$OUT_DIR/expected-private-symbols.txt"
source_gate_sha=$(sha256sum "$SOURCE_GATE" | awk '{print $1}')
source_manifest_sha=$(sha256sum "$source_manifest" | awk '{print $1}')
progress '5% exact source gate, compiler, and architecture matrix'

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 log_prefix=$6
	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig > "$OUT_DIR/$log_prefix-defconfig.log" 2>&1
	"$source/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e DEBUG_INFO_NONE
	case "$mode" in
		baseline)
			"$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE_LAYOUT_PROBE
			;;
		private-off)
			"$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE
			;;
		private-on)
			"$source/scripts/config" --file "$out/.config" -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE
			;;
		normal)
			"$source/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE
			;;
		*) die "unknown mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig > "$OUT_DIR/$log_prefix-olddefconfig.log" 2>&1
	grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$out/.config" || die "$log_prefix lease config missing"
	grep -q '^CONFIG_FAIR_GROUP_SCHED=y$' "$out/.config" || die "$log_prefix fair-group config missing"
	case "$mode" in
		baseline|private-off)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix existing probe missing"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix private probe unexpectedly enabled"
			;;
		private-on)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix existing probe missing"
			grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix private probe missing"
			;;
		normal)
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix existing probe enabled"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$out/.config" || die "$log_prefix private probe enabled"
			;;
	esac
}

build_mode()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 log_prefix=$6
	case "$mode" in
		baseline|private-off|private-on)
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$(nproc)" \
				kernel/sched/exec_lease.o kernel/sched/exec_lease_layout_probe.o \
				> "$OUT_DIR/$log_prefix-build.log" 2>&1
			;;
		normal)
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$(nproc)" \
				kernel/sched/exec_lease.o > "$OUT_DIR/$log_prefix-build.log" 2>&1
			test ! -e "$out/kernel/sched/exec_lease_layout_probe.o" || die "$log_prefix normal build emitted existing probe object"
			;;
	esac
}

extract_symbols()
{
	local nm_cmd=$1 object=$2 prefix=$3 output=$4
	"$nm_cmd" -S "$object" | awk -v prefix="$prefix" '$4 ~ ("^" prefix) {print $4 "\t" $2}' | sort -k1 > "$output"
}

symbol_value()
{
	local file=$1 symbol=$2 hex
	hex=$(awk -v symbol="$symbol" '$1 == symbol {print $2}' "$file")
	[ -n "$hex" ] || die "missing symbol: $symbol"
	printf '%d' "$((16#$hex))"
}

validate_arch()
{
	local label=$1 arch=$2 cross=$3 nm_cmd=$4 readelf_cmd=$5 compiler=$6 arch_root=$7 arch_out=$8
	local baseline="$arch_root/baseline" private_off="$arch_root/private-off" private_on="$arch_root/private-on" normal="$arch_root/normal"
	local baseline_lp="$baseline/kernel/sched/exec_lease_layout_probe.o"
	local off_lp="$private_off/kernel/sched/exec_lease_layout_probe.o"
	local on_lp="$private_on/kernel/sched/exec_lease_layout_probe.o"
	local baseline_exec="$baseline/kernel/sched/exec_lease.o"
	local off_exec="$private_off/kernel/sched/exec_lease.o"
	local on_exec="$private_on/kernel/sched/exec_lease.o"
	local normal_exec="$normal/kernel/sched/exec_lease.o"
	mkdir -p "$arch_out"
	for object in "$baseline_lp" "$off_lp" "$on_lp" "$baseline_exec" "$off_exec" "$on_exec" "$normal_exec"; do
		[ -s "$object" ] || die "$label object missing: $object"
	done

	extract_symbols "$nm_cmd" "$baseline_lp" sched_exec_lp_ "$arch_out/baseline-expanded.tsv"
	extract_symbols "$nm_cmd" "$off_lp" sched_exec_lp_ "$arch_out/private-off-expanded.tsv"
	extract_symbols "$nm_cmd" "$on_lp" sched_exec_lp_ "$arch_out/private-on-expanded.tsv"
	baseline_count=$(wc -l < "$arch_out/baseline-expanded.tsv" | tr -d ' ')
	off_count=$(wc -l < "$arch_out/private-off-expanded.tsv" | tr -d ' ')
	on_count=$(wc -l < "$arch_out/private-on-expanded.tsv" | tr -d ' ')
	[ "$baseline_count" = 51 ] && [ "$off_count" = 51 ] && [ "$on_count" = 51 ] || die "$label expanded probe count mismatch"
	diff -u "$arch_out/baseline-expanded.tsv" "$arch_out/private-off-expanded.tsv" > "$arch_out/baseline-vs-private-off.diff" || die "$label private-off changed existing probe values"
	diff -u "$arch_out/baseline-expanded.tsv" "$arch_out/private-on-expanded.tsv" > "$arch_out/baseline-vs-private-on.diff" || die "$label private-on changed existing probe values"

	extract_symbols "$nm_cmd" "$baseline_exec" sched_exec_bl_ "$arch_out/baseline-private.tsv"
	extract_symbols "$nm_cmd" "$off_exec" sched_exec_bl_ "$arch_out/private-off-private.tsv"
	extract_symbols "$nm_cmd" "$on_exec" sched_exec_bl_ "$arch_out/private-on-private.tsv"
	extract_symbols "$nm_cmd" "$normal_exec" sched_exec_bl_ "$arch_out/normal-private.tsv"
	[ "$(wc -l < "$arch_out/baseline-private.tsv" | tr -d ' ')" = 0 ] || die "$label primary baseline contains private symbols"
	[ "$(wc -l < "$arch_out/private-off-private.tsv" | tr -d ' ')" = 0 ] || die "$label private-off contains private symbols"
	[ "$(wc -l < "$arch_out/normal-private.tsv" | tr -d ' ')" = 0 ] || die "$label normal contains private symbols"
	private_count=$(wc -l < "$arch_out/private-on-private.tsv" | tr -d ' ')
	[ "$private_count" = 43 ] || die "$label private symbol count: $private_count"
	awk '{print $1}' "$arch_out/private-on-private.tsv" > "$arch_out/private-on-symbol-names.txt"
	diff -u "$OUT_DIR/expected-private-symbols.txt" "$arch_out/private-on-symbol-names.txt" > "$arch_out/private-symbol-set.diff" || die "$label private symbol set mismatch"

	"$readelf_cmd" -rW "$off_exec" > "$arch_out/private-off-relocations.txt"
	"$readelf_cmd" -rW "$normal_exec" > "$arch_out/normal-relocations.txt"
	for relocation_file in "$arch_out/private-off-relocations.txt" "$arch_out/normal-relocations.txt"; do
		if grep -F sched_exec_bl_ "$relocation_file" >> "$arch_out/forbidden-disabled-relocations.txt"; then
			die "$label disabled object contains private relocation"
		fi
	done
	: > "$arch_out/forbidden-disabled-relocations.txt"

	key_size=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_key_size)
	bucket_size=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_bucket_size)
	projection_size=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_projection_size)
	rq_state_size=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_rq_state_size)
	b_max=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_b_max_value)
	key_alignment=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_key_alignment_value)
	bucket_alignment=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_bucket_alignment_value)
	projection_alignment=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_projection_alignment_value)
	rq_state_alignment=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_rq_state_alignment_value)
	worst_private=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_worst_private_bytes_per_rq_value)
	cfs_rq_size=$(symbol_value "$arch_out/baseline-expanded.tsv" sched_exec_lp_cfs_rq_size)
	sched_entity_size=$(symbol_value "$arch_out/baseline-expanded.tsv" sched_exec_lp_sched_entity_size)
	rq_size=$(symbol_value "$arch_out/baseline-expanded.tsv" sched_exec_lp_rq_size)
	task_size=$(symbol_value "$arch_out/baseline-expanded.tsv" sched_exec_lp_task_struct_size)

	[ "$key_size" -le 64 ] || die "$label key exceeds 64 bytes: $key_size"
	[ "$bucket_size" -le 256 ] || die "$label bucket exceeds 256 bytes: $bucket_size"
	[ "$projection_size" -le 896 ] || die "$label projection exceeds 896 bytes: $projection_size"
	[ "$rq_state_size" -le 448 ] || die "$label rq state exceeds 448 bytes: $rq_state_size"
	[ "$b_max" = 64 ] || die "$label B_max mismatch: $b_max"
	[ "$worst_private" = "$((b_max * projection_size + rq_state_size))" ] || die "$label private-memory arithmetic mismatch"
	[ "$worst_private" -le 65536 ] || die "$label private-memory envelope exceeded: $worst_private"
	for alignment in "$key_alignment" "$bucket_alignment" "$projection_alignment" "$rq_state_alignment"; do
		[ "$alignment" -le 64 ] || die "$label private alignment exceeded: $alignment"
	done

	key_offsets='domain_id:0 domain_epoch:8 sched_context_id:16 budget_root_id:24 grant_generation_class:32 memory_view_generation:40 placement_class:48 selector_generation:56'
	for pair in $key_offsets; do
		field=${pair%%:*}; expected=${pair##*:}
		actual=$(symbol_value "$arch_out/private-on-private.tsv" "sched_exec_bl_key_${field}_offset_plus_one")
		actual=$((actual - 1))
		[ "$actual" = "$expected" ] || die "$label key.$field offset: $actual"
	done
	inner_offset=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_projection_inner_cfs_rq_offset_plus_one); inner_offset=$((inner_offset - 1))
	outer_offset=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_projection_outer_entity_offset_plus_one); outer_offset=$((outer_offset - 1))
	rq_outer_offset=$(symbol_value "$arch_out/private-on-private.tsv" sched_exec_bl_rq_state_outer_cfs_rq_offset_plus_one); rq_outer_offset=$((rq_outer_offset - 1))
	[ "$inner_offset" = 0 ] || die "$label inner cfs_rq is not first"
	[ "$outer_offset" -ge "$cfs_rq_size" ] || die "$label outer entity overlaps inner cfs_rq"
	[ "$((outer_offset + sched_entity_size))" -le "$projection_size" ] || die "$label embedded outer entity exceeds projection"
	[ "$rq_outer_offset" = 0 ] && [ "$cfs_rq_size" -le "$rq_state_size" ] || die "$label private outer cfs_rq does not fit"

	compiler_machine=$("$compiler" -dumpmachine)
	compiler_version=$("$compiler" -dumpfullversion -dumpversion)
	baseline_sha=$(sha256sum "$baseline_lp" | awk '{print $1}')
	on_lp_sha=$(sha256sum "$on_lp" | awk '{print $1}')
	on_exec_sha=$(sha256sum "$on_exec" | awk '{print $1}')
	private_table_sha=$(sha256sum "$arch_out/private-on-private.tsv" | awk '{print $1}')
	expanded_table_sha=$(sha256sum "$arch_out/baseline-expanded.tsv" | awk '{print $1}')

	jq -n \
		--arg architecture "$label" --arg compiler_machine "$compiler_machine" --arg compiler_version "$compiler_version" \
		--arg baseline_object "$baseline_lp" --arg baseline_sha "$baseline_sha" --arg candidate_probe_object "$on_lp" \
		--arg candidate_probe_sha "$on_lp_sha" --arg private_object "$on_exec" --arg private_object_sha "$on_exec_sha" \
		--arg private_table "$arch_out/private-on-private.tsv" --arg private_table_sha "$private_table_sha" \
		--arg expanded_table "$arch_out/baseline-expanded.tsv" --arg expanded_table_sha "$expanded_table_sha" \
		--argjson baseline_count "$baseline_count" --argjson private_count "$private_count" \
		--argjson key_size "$key_size" --argjson bucket_size "$bucket_size" --argjson projection_size "$projection_size" \
		--argjson rq_state_size "$rq_state_size" --argjson worst_private "$worst_private" --argjson b_max "$b_max" \
		--argjson key_alignment "$key_alignment" --argjson bucket_alignment "$bucket_alignment" \
		--argjson projection_alignment "$projection_alignment" --argjson rq_state_alignment "$rq_state_alignment" \
		--argjson sched_entity_size "$sched_entity_size" --argjson cfs_rq_size "$cfs_rq_size" \
		--argjson rq_size "$rq_size" --argjson task_size "$task_size" \
		'{status:"passed",architecture:$architecture,compiler:{machine:$compiler_machine,version:$compiler_version},fresh_architecture_local_baseline:true,baseline_probe_object:$baseline_object,baseline_probe_object_sha256:$baseline_sha,candidate_probe_object:$candidate_probe_object,candidate_probe_object_sha256:$candidate_probe_sha,private_probe_object:$private_object,private_probe_object_sha256:$private_object_sha,existing_probe_value_table:$expanded_table,existing_probe_value_table_sha256:$expanded_table_sha,private_probe_value_table:$private_table,private_probe_value_table_sha256:$private_table_sha,existing_probe_symbol_count:$baseline_count,existing_probe_values_changed:0,private_probe_symbol_count:$private_count,private_symbols_absent_baseline:true,private_symbols_absent_private_off:true,private_symbols_absent_normal:true,private_relocations_absent_private_off:true,private_relocations_absent_normal:true,ordinary_layout:{sched_entity:$sched_entity_size,cfs_rq:$cfs_rq_size,rq:$rq_size,task_struct:$task_size},ordinary_layout_delta:{sched_entity:0,cfs_rq:0,rq:0,task_struct:0},private_layout:{b_max:$b_max,key_size:$key_size,bucket_size:$bucket_size,projection_size:$projection_size,rq_state_size:$rq_state_size,worst_active_bytes_per_rq:$worst_private,key_alignment:$key_alignment,bucket_alignment:$bucket_alignment,projection_alignment:$projection_alignment,rq_state_alignment:$rq_state_alignment},private_layout_envelope_passed:true,runtime_behavior_approved:false,production_protection:false}' \
		> "$arch_out/result.json"
	jq empty "$arch_out/result.json"
}

ARM_ROOT="$BUILD_ROOT/arm64"
ARM_OUT="$OUT_DIR/arm64"
progress '10% preparing fresh arm64 primary baseline'
prepare_config "$PRIMARY_DIR" arm64 '' baseline "$ARM_ROOT/baseline" arm64-baseline
progress '18% building arm64 primary baseline objects'
build_mode "$PRIMARY_DIR" arm64 '' baseline "$ARM_ROOT/baseline" arm64-baseline
progress '25% preparing and building arm64 candidate private-off'
prepare_config "$CANDIDATE_DIR" arm64 '' private-off "$ARM_ROOT/private-off" arm64-private-off
build_mode "$CANDIDATE_DIR" arm64 '' private-off "$ARM_ROOT/private-off" arm64-private-off
progress '33% preparing and building arm64 candidate private-on'
prepare_config "$CANDIDATE_DIR" arm64 '' private-on "$ARM_ROOT/private-on" arm64-private-on
build_mode "$CANDIDATE_DIR" arm64 '' private-on "$ARM_ROOT/private-on" arm64-private-on
progress '40% preparing and building arm64 normal probes-off object'
prepare_config "$CANDIDATE_DIR" arm64 '' normal "$ARM_ROOT/normal" arm64-normal
build_mode "$CANDIDATE_DIR" arm64 '' normal "$ARM_ROOT/normal" arm64-normal
progress '47% validating arm64 51-value invariance and private envelope'
validate_arch arm64 arm64 '' nm readelf gcc "$ARM_ROOT" "$ARM_OUT"

X86_ROOT="$BUILD_ROOT/x86_64"
X86_OUT="$OUT_DIR/x86_64"
progress '52% preparing fresh x86_64 primary baseline'
prepare_config "$PRIMARY_DIR" x86_64 x86_64-linux-gnu- baseline "$X86_ROOT/baseline" x86_64-baseline
progress '60% building x86_64 primary baseline objects'
build_mode "$PRIMARY_DIR" x86_64 x86_64-linux-gnu- baseline "$X86_ROOT/baseline" x86_64-baseline
progress '67% preparing and building x86_64 candidate private-off'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-off "$X86_ROOT/private-off" x86_64-private-off
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-off "$X86_ROOT/private-off" x86_64-private-off
progress '75% preparing and building x86_64 candidate private-on'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-on "$X86_ROOT/private-on" x86_64-private-on
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-on "$X86_ROOT/private-on" x86_64-private-on
progress '83% preparing and building x86_64 normal probes-off object'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- normal "$X86_ROOT/normal" x86_64-normal
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- normal "$X86_ROOT/normal" x86_64-normal
progress '90% validating x86_64 51-value invariance and private envelope'
validate_arch x86_64 x86_64 x86_64-linux-gnu- x86_64-linux-gnu-nm x86_64-linux-gnu-readelf x86_64-linux-gnu-gcc "$X86_ROOT" "$X86_OUT"

jq -e '.status == "passed" and .architecture == "arm64" and .existing_probe_symbol_count == 51 and .existing_probe_values_changed == 0 and .private_probe_symbol_count == 43 and .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and .private_layout_envelope_passed == true' "$ARM_OUT/result.json" >/dev/null
jq -e '.status == "passed" and .architecture == "x86_64" and .existing_probe_symbol_count == 51 and .existing_probe_values_changed == 0 and .private_probe_symbol_count == 43 and .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and .private_layout_envelope_passed == true' "$X86_OUT/result.json" >/dev/null
arm_sha=$(sha256sum "$ARM_OUT/result.json" | awk '{print $1}')
x86_sha=$(sha256sum "$X86_OUT/result.json" | awk '{print $1}')
config_sha=$(sha256sum "$CONFIG" | awk '{print $1}')

jq -n \
	--arg run_id "$RUN_ID" --arg primary_commit "$expected_parent" --arg candidate_commit "$expected_candidate" \
	--arg candidate_tree "$expected_tree" --arg config "$CONFIG" --arg config_sha "$config_sha" \
	--arg source_gate "$SOURCE_GATE" --arg source_gate_sha "$source_gate_sha" \
	--arg source_manifest "$source_manifest" --arg source_manifest_sha "$source_manifest_sha" \
	--arg arm_result "$ARM_OUT/result.json" --arg arm_sha "$arm_sha" \
	--arg x86_result "$X86_OUT/result.json" --arg x86_sha "$x86_sha" \
	--slurpfile arm64 "$ARM_OUT/result.json" --slurpfile x86_64 "$X86_OUT/result.json" \
	'{schema_version:1,run_id:$run_id,status:"passed",primary_linux_commit:$primary_commit,candidate_commit:$candidate_commit,candidate_tree:$candidate_tree,config:$config,config_sha256:$config_sha,source_gate:$source_gate,source_gate_sha256:$source_gate_sha,source_file_hash_manifest:$source_manifest,source_file_hash_manifest_sha256:$source_manifest_sha,source_files_match_head:true,architectures:["arm64","x86_64"],fresh_architecture_local_baselines:true,cross_architecture_byte_identity_required:false,arm64_result:$arm_result,arm64_result_sha256:$arm_sha,x86_64_result:$x86_result,x86_64_result_sha256:$x86_sha,results:{arm64:$arm64[0],x86_64:$x86_64[0]},existing_expanded_probe_values_preserved:51,private_probe_symbols_enabled:43,private_symbols_and_relocations_absent_when_disabled:true,ordinary_scheduler_layout_delta_zero:true,private_memory_envelope_passed:true,dual_arch_e2_complete:true,e3_plan_may_start:true,e3_source_may_start:false,primary_linux_changed:false,patch_queue_changed:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
progress '100% passed; arm64/x86_64 E2 layout evidence complete'
cat "$OUT_DIR/result.json"
