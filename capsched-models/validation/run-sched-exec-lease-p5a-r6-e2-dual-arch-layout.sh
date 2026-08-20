#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e2-domain-forest-layout-candidate-v1.json"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-source-gate/20260725T-p5a-r6-e2-source-gate-r1/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-dual-arch-layout/$RUN_ID"
BUILD_ROOT=${DOMAINLEASE_P5AR6_E2_BUILD_ROOT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r6-e2-dual-arch/$RUN_ID"}
PROGRESS_FILE=${PROGRESS_FILE:-}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	[ -z "$PROGRESS_FILE" ] || printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
for command in awk diff gcc git grep jq make nm nproc readelf sed \
	sha256sum sort strings wc x86_64-linux-gnu-gcc \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
[ ! -e "$BUILD_ROOT" ] || die "build root already exists: $BUILD_ROOT"
mkdir -p "$OUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR"

[ "$(file_sha "$SOURCE_GATE")" = \
	"18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f" ] ||
	die 'R6-E2 source-gate hash changed'
jq -e '
  .status == "passed_r6_e2_source_gate" and
  .primary_linux_commit ==
    "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .candidate_commit ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .candidate_parent == .primary_linux_commit and
  .exact_two_file_boundary == true and .direct_primary_child == true and
  .remote_candidate_exact == true and .signed_off == true and
  .forward_replay_check_passed == true and
  .reverse_replay_check_passed == true and
  .strict_checkpatch_errors == 0 and
  .strict_checkpatch_warnings == 0 and
  .strict_checkpatch_checks == 0 and
  .source_anchor_count == 24 and .source_anchor_failures == 0 and
  .private_symbol_count == 49 and
  .forbidden_runtime_calls == 0 and
  .forbidden_function_definitions == 0 and
  .forbidden_surfaces == 0 and
  .config_default_off == true and .sched_autogroup_excluded == true and
  .dual_arch_layout_build_may_start == true and
  .r6_e3_source_may_start == false and
  .runtime_behavior_approved == false
' "$SOURCE_GATE" >/dev/null || die 'R6-E2 source-gate semantics changed'

jq -e '
  .source.candidate_commit ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .source.candidate_tree ==
    "603762b7a36d7b57e2456b90538c3ba77a1aba16" and
  .probe.existing_expanded_symbols_required == 51 and
  .probe.added_private_symbols == 49 and
  .architecture_matrix.architectures == ["arm64","x86_64"] and
  .architecture_matrix.modes_per_architecture == [
    "primary-baseline","candidate-private-off",
    "candidate-private-on","candidate-normal"
  ]
' "$CONFIG" >/dev/null || die 'R6-E2 build contract changed'

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_parent" ] ||
	die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] ||
	die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$expected_parent" ] ||
	die 'candidate parent moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] ||
	die 'candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'primary Linux tracked tree is dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'candidate tracked tree is dirty'

jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort \
	> "$OUT_DIR/expected-private-symbols.txt"
[ "$(wc -l < "$OUT_DIR/expected-private-symbols.txt" | tr -d ' ')" = 49 ] ||
	die 'private-symbol manifest is not 49 names'

source_manifest="$OUT_DIR/source-file-hashes.tsv"
printf 'tree\tpath\texpected_blob\tworking_blob\n' > "$source_manifest"
verify_source_file()
{
	local label=$1 tree=$2 path=$3 expected_blob working_blob
	expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
	working_blob=$(git -C "$tree" hash-object "$tree/$path")
	printf '%s\t%s\t%s\t%s\n' \
		"$label" "$path" "$expected_blob" "$working_blob" >> "$source_manifest"
	[ "$working_blob" = "$expected_blob" ] ||
		die "$label source differs from HEAD: $path"
}
for spec in "primary:$PRIMARY_DIR" "candidate:$CANDIDATE_DIR"; do
	label=${spec%%:*}
	tree=${spec#*:}
	for path in init/Kconfig include/linux/sched.h \
		include/linux/sched_exec_lease.h include/linux/stddef.h \
		kernel/sched/Makefile kernel/sched/sched.h \
		kernel/sched/exec_lease.c \
		kernel/sched/exec_lease_layout_probe.c; do
		verify_source_file "$label" "$tree" "$path"
	done
done
source_manifest_sha=$(file_sha "$source_manifest")

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 prefix=$6
	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		defconfig > "$OUT_DIR/$prefix-defconfig.log" 2>&1
	"$source/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED \
		-e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE \
		-e DEBUG_KERNEL -e DEBUG_INFO_NONE -d SCHED_AUTOGROUP
	case "$mode" in
		baseline)
			"$source/scripts/config" --file "$out/.config" \
				-e SCHED_EXEC_LEASE_LAYOUT_PROBE
			;;
		private-off)
			"$source/scripts/config" --file "$out/.config" \
				-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
				-d SCHED_EXEC_LEASE_R6_LAYOUT_PROBE
			;;
		private-on)
			"$source/scripts/config" --file "$out/.config" \
				-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
				-e SCHED_EXEC_LEASE_R6_LAYOUT_PROBE
			;;
		normal)
			"$source/scripts/config" --file "$out/.config" \
				-d SCHED_EXEC_LEASE_LAYOUT_PROBE \
				-d SCHED_EXEC_LEASE_R6_LAYOUT_PROBE
			;;
		*) die "unknown build mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		olddefconfig > "$OUT_DIR/$prefix-olddefconfig.log" 2>&1
	grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$out/.config" ||
		die "$prefix lease config missing"
	grep -q '^CONFIG_CGROUP_SCHED=y$' "$out/.config" ||
		die "$prefix cgroup scheduler config missing"
	grep -q '^CONFIG_FAIR_GROUP_SCHED=y$' "$out/.config" ||
		die "$prefix fair-group config missing"
	grep -q '^# CONFIG_SCHED_AUTOGROUP is not set$' "$out/.config" ||
		die "$prefix autogroup is enabled"
	case "$mode" in
		baseline|private-off)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix existing probe missing"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix R6 probe unexpectedly on"
			;;
		private-on)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix existing probe missing"
			grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix R6 probe missing"
			;;
		normal)
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix existing probe is on"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' \
				"$out/.config" || die "$prefix R6 probe is on"
			;;
	esac
}

build_mode()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 prefix=$6
	case "$mode" in
		baseline|private-off|private-on)
			make -C "$source" O="$out" ARCH="$arch" \
				CROSS_COMPILE="$cross" -j"$(nproc)" \
				kernel/sched/exec_lease.o \
				kernel/sched/exec_lease_layout_probe.o \
				> "$OUT_DIR/$prefix-build.log" 2>&1
			;;
		normal)
			make -C "$source" O="$out" ARCH="$arch" \
				CROSS_COMPILE="$cross" -j"$(nproc)" \
				kernel/sched/exec_lease.o \
				> "$OUT_DIR/$prefix-build.log" 2>&1
			[ ! -e "$out/kernel/sched/exec_lease_layout_probe.o" ] ||
				die "$prefix emitted disabled existing probe object"
			;;
	esac
}

extract_symbols()
{
	local nm_cmd=$1 object=$2 prefix=$3 output=$4
	"$nm_cmd" -S "$object" |
		awk -v prefix="$prefix" '$4 ~ ("^" prefix) {print $4 "\t" $2}' |
		sort -k1 > "$output"
}

symbol_value()
{
	local table=$1 symbol=$2 hex
	hex=$(awk -v symbol="$symbol" '$1 == symbol {print $2}' "$table")
	[ -n "$hex" ] || die "missing symbol: $symbol"
	printf '%d' "$((16#$hex))"
}

validate_arch()
{
	local label=$1 nm_cmd=$2 readelf_cmd=$3 compiler=$4 root=$5 out=$6
	local baseline="$root/baseline"
	local private_off="$root/private-off"
	local private_on="$root/private-on"
	local normal="$root/normal"
	local baseline_lp="$baseline/kernel/sched/exec_lease_layout_probe.o"
	local off_lp="$private_off/kernel/sched/exec_lease_layout_probe.o"
	local on_lp="$private_on/kernel/sched/exec_lease_layout_probe.o"
	local baseline_exec="$baseline/kernel/sched/exec_lease.o"
	local off_exec="$private_off/kernel/sched/exec_lease.o"
	local on_exec="$private_on/kernel/sched/exec_lease.o"
	local normal_exec="$normal/kernel/sched/exec_lease.o"

	mkdir -p "$out"
	for object in "$baseline_lp" "$off_lp" "$on_lp" "$baseline_exec" \
		"$off_exec" "$on_exec" "$normal_exec"; do
		[ -s "$object" ] || die "$label object missing: $object"
	done
	extract_symbols "$nm_cmd" "$baseline_lp" sched_exec_lp_ \
		"$out/baseline-expanded.tsv"
	extract_symbols "$nm_cmd" "$off_lp" sched_exec_lp_ \
		"$out/private-off-expanded.tsv"
	extract_symbols "$nm_cmd" "$on_lp" sched_exec_lp_ \
		"$out/private-on-expanded.tsv"
	for table in "$out/baseline-expanded.tsv" \
		"$out/private-off-expanded.tsv" "$out/private-on-expanded.tsv"; do
		[ "$(wc -l < "$table" | tr -d ' ')" = 51 ] ||
			die "$label existing probe count changed"
	done
	diff -u "$out/baseline-expanded.tsv" "$out/private-off-expanded.tsv" \
		> "$out/baseline-vs-private-off.diff" ||
		die "$label private-off changed existing values"
	diff -u "$out/baseline-expanded.tsv" "$out/private-on-expanded.tsv" \
		> "$out/baseline-vs-private-on.diff" ||
		die "$label private-on changed existing values"

	extract_symbols "$nm_cmd" "$baseline_exec" sched_exec_r6l_ \
		"$out/baseline-private.tsv"
	extract_symbols "$nm_cmd" "$off_exec" sched_exec_r6l_ \
		"$out/private-off-private.tsv"
	extract_symbols "$nm_cmd" "$on_exec" sched_exec_r6l_ \
		"$out/private-on-private.tsv"
	extract_symbols "$nm_cmd" "$normal_exec" sched_exec_r6l_ \
		"$out/normal-private.tsv"
	[ ! -s "$out/baseline-private.tsv" ] ||
		die "$label primary baseline contains R6 symbols"
	[ ! -s "$out/private-off-private.tsv" ] ||
		die "$label private-off contains R6 symbols"
	[ ! -s "$out/normal-private.tsv" ] ||
		die "$label normal contains R6 symbols"
	[ "$(wc -l < "$out/private-on-private.tsv" | tr -d ' ')" = 49 ] ||
		die "$label enabled R6 symbol count changed"
	awk '{print $1}' "$out/private-on-private.tsv" \
		> "$out/private-on-symbol-names.txt"
	diff -u "$OUT_DIR/expected-private-symbols.txt" \
		"$out/private-on-symbol-names.txt" \
		> "$out/private-symbol-set.diff" ||
		die "$label private symbol set changed"

	: > "$out/forbidden-disabled-artifacts.txt"
	for object in "$off_exec" "$normal_exec"; do
		"$readelf_cmd" -rW "$object" > "$out/disabled-relocations.tmp"
		strings "$object" > "$out/disabled-strings.tmp"
		if grep -F sched_exec_r6l_ "$out/disabled-relocations.tmp" \
			>> "$out/forbidden-disabled-artifacts.txt" ||
		   grep -F sched_exec_r6l_ "$out/disabled-strings.tmp" \
			>> "$out/forbidden-disabled-artifacts.txt"; then
			die "$label disabled object contains R6 artifacts"
		fi
	done

	slot_size=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_size)
	top_size=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_top_size)
	control_size=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_control_size)
	rq_state_size=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_state_size)
	b_max=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_b_max_value)
	top_count=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_top_node_count_value)
	slot_max=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_state_max_value)
	top_max=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_top_node_max_value)
	control_max=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_control_max_value)
	worst_private=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_worst_private_bytes_per_rq_value)
	private_limit=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_private_rq_limit_value)
	slot_alignment=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_alignment_value)
	top_alignment=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_top_alignment_value)
	control_alignment=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_control_alignment_value)
	rq_state_alignment=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_state_alignment_value)

	[ "$slot_size" -le 1024 ] || die "$label slot exceeds 1024"
	[ "$top_size" -le 64 ] || die "$label top node exceeds 64"
	[ "$control_size" -le 1024 ] || die "$label control exceeds 1024"
	if [ "$b_max" != 64 ] || [ "$top_count" != 127 ]; then
		die "$label fixed counts changed"
	fi
	if [ "$slot_max" != 1024 ] || [ "$top_max" != 64 ] ||
	   [ "$control_max" != 1024 ]; then
		die "$label envelope values changed"
	fi
	[ "$worst_private" = \
		"$((b_max * slot_max + top_count * top_max + control_max))" ] ||
		die "$label conservative arithmetic changed"
	[ "$worst_private" = 74688 ] || die "$label conservative total changed"
	[ "$private_limit" = 98304 ] || die "$label hard limit changed"
	[ "$rq_state_size" -le "$worst_private" ] ||
		die "$label concrete rq state exceeds conservative total"
	[ "$worst_private" -le "$private_limit" ] ||
		die "$label conservative total exceeds hard limit"
	for alignment in "$slot_alignment" "$top_alignment" \
		"$control_alignment" "$rq_state_alignment"; do
		[ "$alignment" -le 64 ] ||
			die "$label private alignment exceeds 64"
	done

	slot_inner=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_inner_cfs_rq_offset_plus_one)
	slot_top=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_top_entity_offset_plus_one)
	slot_stats=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_slot_top_stats_offset_plus_one)
	rq_slots=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_state_slots_offset_plus_one)
	rq_top=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_state_top_offset_plus_one)
	rq_control=$(symbol_value "$out/private-on-private.tsv" \
		sched_exec_r6l_rq_state_control_offset_plus_one)
	[ "$slot_inner" = 1 ] || die "$label inner cfs_rq is not first"
	if [ "$slot_top" -le "$slot_inner" ] ||
	   [ "$slot_stats" -le "$slot_top" ]; then
		die "$label slot member order changed"
	fi
	if [ "$rq_slots" != 1 ] || [ "$rq_top" -le "$rq_slots" ] ||
	   [ "$rq_control" -le "$rq_top" ]; then
		die "$label rq member order changed"
	fi

	cfs_rq_size=$(symbol_value "$out/baseline-expanded.tsv" \
		sched_exec_lp_cfs_rq_size)
	sched_entity_size=$(symbol_value "$out/baseline-expanded.tsv" \
		sched_exec_lp_sched_entity_size)
	rq_size=$(symbol_value "$out/baseline-expanded.tsv" \
		sched_exec_lp_rq_size)
	task_size=$(symbol_value "$out/baseline-expanded.tsv" \
		sched_exec_lp_task_struct_size)
	compiler_machine=$("$compiler" -dumpmachine)
	compiler_version=$("$compiler" -dumpfullversion -dumpversion)

	jq -S -n \
		--arg architecture "$label" \
		--arg compiler_machine "$compiler_machine" \
		--arg compiler_version "$compiler_version" \
		--argjson slot_size "$slot_size" --argjson top_size "$top_size" \
		--argjson control_size "$control_size" \
		--argjson rq_state_size "$rq_state_size" \
		--argjson worst_private "$worst_private" \
		--argjson private_limit "$private_limit" \
		--argjson slot_alignment "$slot_alignment" \
		--argjson top_alignment "$top_alignment" \
		--argjson control_alignment "$control_alignment" \
		--argjson rq_state_alignment "$rq_state_alignment" \
		--argjson cfs_rq_size "$cfs_rq_size" \
		--argjson sched_entity_size "$sched_entity_size" \
		--argjson rq_size "$rq_size" --argjson task_size "$task_size" '
{
  status:"passed",
  architecture:$architecture,
  compiler:{machine:$compiler_machine,version:$compiler_version},
  fresh_architecture_local_baseline:true,
  existing_probe_symbol_count:51,
  existing_probe_values_changed:0,
  private_probe_symbol_count:49,
  private_symbols_absent_baseline:true,
  private_symbols_absent_private_off:true,
  private_symbols_absent_normal:true,
  private_relocations_and_strings_absent_when_disabled:true,
  ordinary_layout:{
    sched_entity:$sched_entity_size,cfs_rq:$cfs_rq_size,
    rq:$rq_size,task_struct:$task_size
  },
  ordinary_layout_delta:{sched_entity:0,cfs_rq:0,rq:0,task_struct:0},
  private_layout:{
    slot_state_size:$slot_size,top_node_size:$top_size,
    rq_control_size:$control_size,rq_state_size:$rq_state_size,
    conservative_bytes_per_rq:$worst_private,
    hard_limit_per_rq:$private_limit,
    slot_alignment:$slot_alignment,top_alignment:$top_alignment,
    control_alignment:$control_alignment,rq_state_alignment:$rq_state_alignment
  },
  private_layout_envelope_passed:true,
  runtime_behavior_approved:false,
  production_protection:false
}' > "$out/result.json"
	jq empty "$out/result.json"
}

ARM_ROOT="$BUILD_ROOT/arm64"
ARM_OUT="$OUT_DIR/arm64"
progress '6% preparing fresh arm64 primary baseline'
prepare_config "$PRIMARY_DIR" arm64 '' baseline \
	"$ARM_ROOT/baseline" arm64-baseline
progress '14% building arm64 primary baseline objects'
build_mode "$PRIMARY_DIR" arm64 '' baseline \
	"$ARM_ROOT/baseline" arm64-baseline
progress '22% building arm64 candidate with R6 off'
prepare_config "$CANDIDATE_DIR" arm64 '' private-off \
	"$ARM_ROOT/private-off" arm64-private-off
build_mode "$CANDIDATE_DIR" arm64 '' private-off \
	"$ARM_ROOT/private-off" arm64-private-off
progress '30% building arm64 candidate with R6 on'
prepare_config "$CANDIDATE_DIR" arm64 '' private-on \
	"$ARM_ROOT/private-on" arm64-private-on
build_mode "$CANDIDATE_DIR" arm64 '' private-on \
	"$ARM_ROOT/private-on" arm64-private-on
progress '38% building arm64 normal probes-off object'
prepare_config "$CANDIDATE_DIR" arm64 '' normal \
	"$ARM_ROOT/normal" arm64-normal
build_mode "$CANDIDATE_DIR" arm64 '' normal \
	"$ARM_ROOT/normal" arm64-normal
progress '46% validating arm64 51 values, disabled absence, and envelope'
validate_arch arm64 nm readelf gcc "$ARM_ROOT" "$ARM_OUT"

X86_ROOT="$BUILD_ROOT/x86_64"
X86_OUT="$OUT_DIR/x86_64"
progress '52% preparing fresh x86_64 primary baseline'
prepare_config "$PRIMARY_DIR" x86_64 x86_64-linux-gnu- baseline \
	"$X86_ROOT/baseline" x86_64-baseline
progress '60% building x86_64 primary baseline objects'
build_mode "$PRIMARY_DIR" x86_64 x86_64-linux-gnu- baseline \
	"$X86_ROOT/baseline" x86_64-baseline
progress '68% building x86_64 candidate with R6 off'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-off \
	"$X86_ROOT/private-off" x86_64-private-off
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-off \
	"$X86_ROOT/private-off" x86_64-private-off
progress '76% building x86_64 candidate with R6 on'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-on \
	"$X86_ROOT/private-on" x86_64-private-on
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- private-on \
	"$X86_ROOT/private-on" x86_64-private-on
progress '84% building x86_64 normal probes-off object'
prepare_config "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- normal \
	"$X86_ROOT/normal" x86_64-normal
build_mode "$CANDIDATE_DIR" x86_64 x86_64-linux-gnu- normal \
	"$X86_ROOT/normal" x86_64-normal
progress '92% validating x86_64 51 values, disabled absence, and envelope'
validate_arch x86_64 x86_64-linux-gnu-nm x86_64-linux-gnu-readelf \
	x86_64-linux-gnu-gcc "$X86_ROOT" "$X86_OUT"

jq -e '.status == "passed" and .existing_probe_symbol_count == 51 and
  .existing_probe_values_changed == 0 and .private_probe_symbol_count == 49 and
  .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .private_layout.conservative_bytes_per_rq == 74688 and
  .private_layout.hard_limit_per_rq == 98304 and
  .private_layout_envelope_passed == true' "$ARM_OUT/result.json" >/dev/null
jq -e '.status == "passed" and .existing_probe_symbol_count == 51 and
  .existing_probe_values_changed == 0 and .private_probe_symbol_count == 49 and
  .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
  .private_layout.conservative_bytes_per_rq == 74688 and
  .private_layout.hard_limit_per_rq == 98304 and
  .private_layout_envelope_passed == true' "$X86_OUT/result.json" >/dev/null

arm_sha=$(file_sha "$ARM_OUT/result.json")
x86_sha=$(file_sha "$X86_OUT/result.json")
jq -S -n \
	--arg run_id "$RUN_ID" --arg primary_commit "$expected_parent" \
	--arg candidate_commit "$expected_candidate" --arg candidate_tree "$expected_tree" \
	--arg source_gate "$SOURCE_GATE" \
	--arg source_gate_sha "$(file_sha "$SOURCE_GATE")" \
	--arg source_manifest "$source_manifest" \
	--arg source_manifest_sha "$source_manifest_sha" \
	--arg arm_result "$ARM_OUT/result.json" --arg arm_sha "$arm_sha" \
	--arg x86_result "$X86_OUT/result.json" --arg x86_sha "$x86_sha" \
	--slurpfile arm64 "$ARM_OUT/result.json" \
	--slurpfile x86_64 "$X86_OUT/result.json" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r6_e2_dual_arch_layout",
  primary_linux_commit:$primary_commit,
  candidate_commit:$candidate_commit,
  candidate_tree:$candidate_tree,
  source_gate:$source_gate,
  source_gate_sha256:$source_gate_sha,
  source_file_hash_manifest:$source_manifest,
  source_file_hash_manifest_sha256:$source_manifest_sha,
  source_files_match_head:true,
  architectures:["arm64","x86_64"],
  modes_per_architecture:4,
  fresh_architecture_local_baselines:true,
  cross_architecture_byte_identity_required:false,
  arm64_result:$arm_result,
  arm64_result_sha256:$arm_sha,
  x86_64_result:$x86_result,
  x86_64_result_sha256:$x86_sha,
  results:{arm64:$arm64[0],x86_64:$x86_64[0]},
  existing_expanded_probe_values_preserved:51,
  private_probe_symbols_enabled:49,
  private_symbols_relocations_and_strings_absent_when_disabled:true,
  ordinary_scheduler_layout_delta_zero:true,
  conservative_private_bytes_per_rq:74688,
  hard_private_bytes_limit_per_rq:98304,
  private_memory_envelope_passed:true,
  dual_arch_r6_e2_complete:true,
  r6_e3_plan_may_start:true,
  r6_e3_source_may_start:false,
  primary_linux_changed:false,
  patch_queue_changed:false,
  runtime_behavior_approved:false,
  runtime_denial_correctness:false,
  monitor_verified:false,
  performance_claim:false,
  production_protection:false,
  deployment_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
progress '100% passed; arm64/x86_64 R6-E2 layout evidence complete'
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
