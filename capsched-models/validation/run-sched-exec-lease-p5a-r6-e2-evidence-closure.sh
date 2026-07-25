#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r6-e2-domain-forest-layout-candidate-v1.json"
SOURCE_GATE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-source-gate/20260725T-p5a-r6-e2-source-gate-r1/result.json"
E2_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-dual-arch-layout/20260725T-p5a-r6-e2-dual-arch-r1"
E2_RESULT="$E2_ROOT/result.json"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r6-e2-dual-arch/20260725T-p5a-r6-e2-dual-arch-r1"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-evidence-closure/$RUN_ID"

EXPECTED_CONFIG_SHA=451704317503cf9453e1f3cb5b1de9d687209ba3a61f852bcbb3000e94af4dc6
EXPECTED_SOURCE_GATE_SHA=18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f
EXPECTED_E2_SHA=6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4
EXPECTED_SOURCE_MANIFEST_SHA=f4deea52cd10a4b89e300c568bdabfb4b2660abab1fa4205e3e96cc08eca1942
EXPECTED_ARM_RESULT_SHA=f7a96dc37deafee8d14cbd93c8bb8b6385e3054258dab3aef169dc94fed85759
EXPECTED_X86_RESULT_SHA=0406cc690826211761f88001222b5ad615140201ef7942b2d6eeccc8c3818d2f

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
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

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
for command in awk diff git grep jq nm readelf sha256sum sort strings wc \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
[ ! -e "$OUT_DIR" ] || die "output already exists: $OUT_DIR"
mkdir -p "$OUT_DIR"
chmod 0700 "$OUT_DIR"

[ "$(file_sha "$CONFIG")" = "$EXPECTED_CONFIG_SHA" ] ||
	die 'R6-E2 input contract hash changed'
[ "$(file_sha "$SOURCE_GATE")" = "$EXPECTED_SOURCE_GATE_SHA" ] ||
	die 'R6-E2 source-gate hash changed'
[ "$(file_sha "$E2_RESULT")" = "$EXPECTED_E2_SHA" ] ||
	die 'R6-E2 dual-architecture result hash changed'
[ "$(file_sha "$E2_ROOT/source-file-hashes.tsv")" = \
	"$EXPECTED_SOURCE_MANIFEST_SHA" ] ||
	die 'R6-E2 source manifest hash changed'
[ "$(file_sha "$E2_ROOT/arm64/result.json")" = \
	"$EXPECTED_ARM_RESULT_SHA" ] ||
	die 'R6-E2 arm64 result hash changed'
[ "$(file_sha "$E2_ROOT/x86_64/result.json")" = \
	"$EXPECTED_X86_RESULT_SHA" ] ||
	die 'R6-E2 x86_64 result hash changed'

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
  .strict_checkpatch_errors == 0 and .strict_checkpatch_warnings == 0 and
  .strict_checkpatch_checks == 0 and .source_anchor_failures == 0 and
  .private_symbol_count == 49 and .forbidden_runtime_calls == 0 and
  .forbidden_function_definitions == 0 and .forbidden_surfaces == 0 and
  .config_default_off == true and .sched_autogroup_excluded == true and
  .r6_e3_source_may_start == false and
  .runtime_behavior_approved == false
' "$SOURCE_GATE" >/dev/null || die 'R6-E2 source-gate semantics changed'

jq -e '
  .status == "passed_r6_e2_dual_arch_layout" and
  .primary_linux_commit ==
    "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .candidate_commit ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .candidate_tree ==
    "603762b7a36d7b57e2456b90538c3ba77a1aba16" and
  .architectures == ["arm64","x86_64"] and
  .modes_per_architecture == 4 and
  .fresh_architecture_local_baselines == true and
  .cross_architecture_byte_identity_required == false and
  .existing_expanded_probe_values_preserved == 51 and
  .private_probe_symbols_enabled == 49 and
  .private_symbols_relocations_and_strings_absent_when_disabled == true and
  .ordinary_scheduler_layout_delta_zero == true and
  .conservative_private_bytes_per_rq == 74688 and
  .hard_private_bytes_limit_per_rq == 98304 and
  .private_memory_envelope_passed == true and
  .dual_arch_r6_e2_complete == true and
  .r6_e3_plan_may_start == true and .r6_e3_source_may_start == false and
  .primary_linux_changed == false and .patch_queue_changed == false and
  .runtime_behavior_approved == false and
  .runtime_denial_correctness == false and .monitor_verified == false and
  .performance_claim == false and .production_protection == false and
  .deployment_ready == false and .datacenter_ready == false
' "$E2_RESULT" >/dev/null ||
	die 'R6-E2 dual-architecture result semantics changed'

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff_sha=$(jq -r '.source.candidate_diff_sha256' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_parent" ] ||
	die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] ||
	die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$expected_parent" ] ||
	die 'candidate is not the direct primary child'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] ||
	die 'candidate tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'primary Linux tracked tree is dirty'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'candidate tracked tree is dirty'

git -C "$CANDIDATE_DIR" diff --name-only \
	"$expected_parent..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" \
	> "$OUT_DIR/delta-files.diff" ||
	die 'candidate escaped the exact two-file boundary'
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" \
	> "$OUT_DIR/candidate.diff"
[ "$(file_sha "$OUT_DIR/candidate.diff")" = "$expected_diff_sha" ] ||
	die 'candidate diff hash changed'

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = 16bb080da472ffabbbafd2698073eca633fb0602 ] ||
	die 'patch queue commit changed'
series=patches/capsched-linux-l0/series
series_head_blob=$(git -C "$PATCH_QUEUE_DIR" rev-parse "HEAD:$series")
series_working_blob=$(git -C "$PATCH_QUEUE_DIR" hash-object \
	"$PATCH_QUEUE_DIR/$series")
[ "$series_working_blob" = "$series_head_blob" ] ||
	die 'patch queue series has working-tree changes'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/$series")" = \
	0014-sched-exec_lease-Expand-build-only-layout-probe.patch ] ||
	die 'patch queue tail changed'

fresh_source_manifest="$OUT_DIR/source-file-hashes.tsv"
printf 'tree\tpath\texpected_blob\tworking_blob\n' > "$fresh_source_manifest"
for spec in "primary:$PRIMARY_DIR" "candidate:$CANDIDATE_DIR"; do
	label=${spec%%:*}
	tree=${spec#*:}
	for path in init/Kconfig include/linux/sched.h \
		include/linux/sched_exec_lease.h include/linux/stddef.h \
		kernel/sched/Makefile kernel/sched/sched.h \
		kernel/sched/exec_lease.c \
		kernel/sched/exec_lease_layout_probe.c; do
		expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
		working_blob=$(git -C "$tree" hash-object "$tree/$path")
		[ "$expected_blob" = "$working_blob" ] ||
			die "$label source differs from HEAD: $path"
		printf '%s\t%s\t%s\t%s\n' "$label" "$path" \
			"$expected_blob" "$working_blob" >> "$fresh_source_manifest"
	done
done
diff -u "$E2_ROOT/source-file-hashes.tsv" "$fresh_source_manifest" \
	> "$OUT_DIR/source-file-hashes.diff" ||
	die 'independent source manifest differs from build evidence'
[ "$(file_sha "$fresh_source_manifest")" = \
	"$EXPECTED_SOURCE_MANIFEST_SHA" ] ||
	die 'independent source manifest hash differs'

jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort \
	> "$OUT_DIR/expected-private-symbols.txt"
[ "$(wc -l < "$OUT_DIR/expected-private-symbols.txt" | tr -d ' ')" = 49 ] ||
	die 'private-symbol manifest is not 49 names'

printf 'architecture\tmode\tconfig_sha256\n' > "$OUT_DIR/config-hashes.tsv"
printf 'architecture\tmode\tobject\tsha256\n' > "$OUT_DIR/object-hashes.tsv"
printf 'architecture\texisting_symbols\tchanged_existing\tprivate_symbols\tdisabled_symbols\tdisabled_relocations\tdisabled_strings\tsched_entity\tcfs_rq\trq\ttask_struct\tslot\ttop\tcontrol\trq_state\tconservative\thard_limit\tenvelope\n' \
	> "$OUT_DIR/architecture-summary.tsv"

validate_config()
{
	local architecture=$1 mode=$2 config=$3
	grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$config" ||
		die "$architecture/$mode lease config missing"
	grep -q '^CONFIG_CGROUP_SCHED=y$' "$config" ||
		die "$architecture/$mode cgroup scheduler config missing"
	grep -q '^CONFIG_FAIR_GROUP_SCHED=y$' "$config" ||
		die "$architecture/$mode fair-group config missing"
	grep -q '^# CONFIG_SCHED_AUTOGROUP is not set$' "$config" ||
		die "$architecture/$mode autogroup is enabled"
	case "$mode" in
		baseline)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$config" ||
				die "$architecture/$mode existing probe missing"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' "$config" ||
				die "$architecture/$mode R6 probe enabled"
			;;
		private-off)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$config" ||
				die "$architecture/$mode existing probe missing"
			grep -q '^# CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE is not set$' \
				"$config" ||
				die "$architecture/$mode R6 probe is not resolved off"
			;;
		private-on)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$config" ||
				die "$architecture/$mode existing probe missing"
			grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' "$config" ||
				die "$architecture/$mode R6 probe missing"
			;;
		normal)
			grep -q '^# CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE is not set$' \
				"$config" ||
				die "$architecture/$mode existing probe is not off"
			grep -q '^# CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE is not set$' \
				"$config" ||
				die "$architecture/$mode R6 probe is not off"
			;;
		*) die "unknown mode: $mode" ;;
	esac
	printf '%s\t%s\t%s\n' "$architecture" "$mode" "$(file_sha "$config")" \
		>> "$OUT_DIR/config-hashes.tsv"
}

validate_architecture()
{
	local architecture=$1 nm_cmd=$2 readelf_cmd=$3
	local root="$BUILD_ROOT/$architecture"
	local recorded="$E2_ROOT/$architecture"
	local out="$OUT_DIR/$architecture"
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
	for mode in baseline private-off private-on normal; do
		validate_config "$architecture" "$mode" "$root/$mode/.config"
	done
	[ ! -e "$normal/kernel/sched/exec_lease_layout_probe.o" ] ||
		die "$architecture normal mode emitted disabled layout probe"
	for spec in \
		"baseline:exec_lease.o:$baseline_exec" \
		"baseline:exec_lease_layout_probe.o:$baseline_lp" \
		"private-off:exec_lease.o:$off_exec" \
		"private-off:exec_lease_layout_probe.o:$off_lp" \
		"private-on:exec_lease.o:$on_exec" \
		"private-on:exec_lease_layout_probe.o:$on_lp" \
		"normal:exec_lease.o:$normal_exec"; do
		mode=${spec%%:*}
		rest=${spec#*:}
		name=${rest%%:*}
		object=${rest#*:}
		[ -s "$object" ] ||
			die "$architecture/$mode object missing: $name"
		printf '%s\t%s\t%s\t%s\n' "$architecture" "$mode" "$name" \
			"$(file_sha "$object")" >> "$OUT_DIR/object-hashes.tsv"
	done

	extract_symbols "$nm_cmd" "$baseline_lp" sched_exec_lp_ \
		"$out/baseline-expanded.tsv"
	extract_symbols "$nm_cmd" "$off_lp" sched_exec_lp_ \
		"$out/private-off-expanded.tsv"
	extract_symbols "$nm_cmd" "$on_lp" sched_exec_lp_ \
		"$out/private-on-expanded.tsv"
	for mode in baseline private-off private-on; do
		[ "$(wc -l < "$out/$mode-expanded.tsv" | tr -d ' ')" = 51 ] ||
			die "$architecture/$mode existing symbol count changed"
	done
	diff -u "$out/baseline-expanded.tsv" "$out/private-off-expanded.tsv" \
		> "$out/baseline-vs-private-off.diff" ||
		die "$architecture private-off changed existing values"
	diff -u "$out/baseline-expanded.tsv" "$out/private-on-expanded.tsv" \
		> "$out/baseline-vs-private-on.diff" ||
		die "$architecture private-on changed existing values"
	for mode in baseline private-off private-on; do
		diff -u "$recorded/$mode-expanded.tsv" "$out/$mode-expanded.tsv" \
			> "$out/recorded-vs-fresh-$mode-expanded.diff" ||
			die "$architecture/$mode existing evidence is not reproducible"
	done

	extract_symbols "$nm_cmd" "$baseline_exec" sched_exec_r6l_ \
		"$out/baseline-private.tsv"
	extract_symbols "$nm_cmd" "$off_exec" sched_exec_r6l_ \
		"$out/private-off-private.tsv"
	extract_symbols "$nm_cmd" "$on_exec" sched_exec_r6l_ \
		"$out/private-on-private.tsv"
	extract_symbols "$nm_cmd" "$normal_exec" sched_exec_r6l_ \
		"$out/normal-private.tsv"
	disabled_symbols=0
	for mode in baseline private-off normal; do
		count=$(wc -l < "$out/$mode-private.tsv" | tr -d ' ')
		disabled_symbols=$((disabled_symbols + count))
	done
	[ "$disabled_symbols" = 0 ] ||
		die "$architecture disabled objects contain R6 symbols"
	private_symbols=$(wc -l < "$out/private-on-private.tsv" | tr -d ' ')
	[ "$private_symbols" = 49 ] ||
		die "$architecture enabled R6 symbol count changed"
	awk '{print $1}' "$out/private-on-private.tsv" \
		> "$out/private-on-symbol-names.txt"
	diff -u "$OUT_DIR/expected-private-symbols.txt" \
		"$out/private-on-symbol-names.txt" \
		> "$out/private-symbol-set.diff" ||
		die "$architecture enabled R6 symbol set changed"
	for mode in baseline private-off private-on normal; do
		diff -u "$recorded/$mode-private.tsv" "$out/$mode-private.tsv" \
			> "$out/recorded-vs-fresh-$mode-private.diff" ||
			die "$architecture/$mode private evidence is not reproducible"
	done

	disabled_relocations=0
	disabled_strings=0
	for spec in "baseline:$baseline_exec" "private-off:$off_exec" \
		"normal:$normal_exec"; do
		mode=${spec%%:*}
		object=${spec#*:}
		"$readelf_cmd" -rW "$object" > "$out/$mode-relocations.txt"
		strings "$object" > "$out/$mode-strings.txt"
		if grep -F sched_exec_r6l_ "$out/$mode-relocations.txt" \
			> "$out/$mode-forbidden-relocations.txt"; then
			disabled_relocations=$((disabled_relocations + 1))
		fi
		if grep -F sched_exec_r6l_ "$out/$mode-strings.txt" \
			> "$out/$mode-forbidden-strings.txt"; then
			disabled_strings=$((disabled_strings + 1))
		fi
		: > "$out/$mode-forbidden-relocations.txt"
		: > "$out/$mode-forbidden-strings.txt"
	done
	[ "$disabled_relocations" = 0 ] ||
		die "$architecture disabled objects contain R6 relocations"
	[ "$disabled_strings" = 0 ] ||
		die "$architecture disabled objects contain R6 strings"

	existing="$out/baseline-expanded.tsv"
	private="$out/private-on-private.tsv"
	sched_entity=$(symbol_value "$existing" sched_exec_lp_sched_entity_size)
	cfs_rq=$(symbol_value "$existing" sched_exec_lp_cfs_rq_size)
	rq=$(symbol_value "$existing" sched_exec_lp_rq_size)
	task=$(symbol_value "$existing" sched_exec_lp_task_struct_size)
	slot=$(symbol_value "$private" sched_exec_r6l_slot_size)
	top=$(symbol_value "$private" sched_exec_r6l_top_size)
	control=$(symbol_value "$private" sched_exec_r6l_control_size)
	rq_state=$(symbol_value "$private" sched_exec_r6l_rq_state_size)
	b_max=$(symbol_value "$private" sched_exec_r6l_b_max_value)
	top_count=$(symbol_value "$private" sched_exec_r6l_top_node_count_value)
	slot_max=$(symbol_value "$private" sched_exec_r6l_slot_state_max_value)
	top_max=$(symbol_value "$private" sched_exec_r6l_top_node_max_value)
	control_max=$(symbol_value "$private" sched_exec_r6l_rq_control_max_value)
	conservative=$(symbol_value "$private" \
		sched_exec_r6l_worst_private_bytes_per_rq_value)
	hard_limit=$(symbol_value "$private" \
		sched_exec_r6l_private_rq_limit_value)

	[ "$b_max" = 64 ] && [ "$top_count" = 127 ] ||
		die "$architecture fixed forest counts changed"
	[ "$slot_max" = 1024 ] && [ "$top_max" = 64 ] &&
		[ "$control_max" = 1024 ] ||
		die "$architecture conservative component limits changed"
	[ "$conservative" = \
		"$((b_max * slot_max + top_count * top_max + control_max))" ] ||
		die "$architecture conservative arithmetic changed"
	[ "$conservative" = 74688 ] && [ "$hard_limit" = 98304 ] ||
		die "$architecture private memory limits changed"
	[ "$slot" -le "$slot_max" ] && [ "$top" -le "$top_max" ] &&
		[ "$control" -le "$control_max" ] ||
		die "$architecture concrete private component exceeds limit"
	[ "$rq_state" -le "$conservative" ] &&
		[ "$conservative" -le "$hard_limit" ] ||
		die "$architecture private rq envelope failed"
	for symbol in sched_exec_r6l_slot_alignment_value \
		sched_exec_r6l_top_alignment_value \
		sched_exec_r6l_control_alignment_value \
		sched_exec_r6l_rq_state_alignment_value; do
		[ "$(symbol_value "$private" "$symbol")" -le 64 ] ||
			die "$architecture alignment exceeds 64: $symbol"
	done
	slot_inner=$(symbol_value "$private" \
		sched_exec_r6l_slot_inner_cfs_rq_offset_plus_one)
	slot_top=$(symbol_value "$private" \
		sched_exec_r6l_slot_top_entity_offset_plus_one)
	slot_stats=$(symbol_value "$private" \
		sched_exec_r6l_slot_top_stats_offset_plus_one)
	rq_slots=$(symbol_value "$private" \
		sched_exec_r6l_rq_state_slots_offset_plus_one)
	rq_top=$(symbol_value "$private" \
		sched_exec_r6l_rq_state_top_offset_plus_one)
	rq_control=$(symbol_value "$private" \
		sched_exec_r6l_rq_state_control_offset_plus_one)
	[ "$slot_inner" = 1 ] && [ "$slot_top" -gt "$slot_inner" ] &&
		[ "$slot_stats" -gt "$slot_top" ] ||
		die "$architecture private slot member order changed"
	[ "$rq_slots" = 1 ] && [ "$rq_top" -gt "$rq_slots" ] &&
		[ "$rq_control" -gt "$rq_top" ] ||
		die "$architecture rq-state member order changed"

	case "$architecture" in
		arm64)
			[ "$sched_entity" = 320 ] && [ "$cfs_rq" = 384 ] &&
				[ "$rq" = 3520 ] && [ "$task" = 4160 ] &&
				[ "$slot" = 768 ] && [ "$top" = 64 ] &&
				[ "$control" = 48 ] && [ "$rq_state" = 57344 ] ||
				die 'arm64 frozen layout values changed'
			;;
		x86_64)
			[ "$sched_entity" = 320 ] && [ "$cfs_rq" = 384 ] &&
				[ "$rq" = 3392 ] && [ "$task" = 3328 ] &&
				[ "$slot" = 1024 ] && [ "$top" = 64 ] &&
				[ "$control" = 48 ] && [ "$rq_state" = 73728 ] ||
				die 'x86_64 frozen layout values changed'
			;;
	esac

	jq -e --argjson sched_entity "$sched_entity" \
		--argjson cfs_rq "$cfs_rq" --argjson rq "$rq" \
		--argjson task "$task" --argjson slot "$slot" \
		--argjson top "$top" --argjson control "$control" \
		--argjson rq_state "$rq_state" '
	  .status == "passed" and
	  .existing_probe_symbol_count == 51 and
	  .existing_probe_values_changed == 0 and
	  .private_probe_symbol_count == 49 and
	  .ordinary_layout == {
	    sched_entity:$sched_entity,cfs_rq:$cfs_rq,rq:$rq,task_struct:$task
	  } and
	  .ordinary_layout_delta == {
	    sched_entity:0,cfs_rq:0,rq:0,task_struct:0
	  } and
	  .private_layout.slot_state_size == $slot and
	  .private_layout.top_node_size == $top and
	  .private_layout.rq_control_size == $control and
	  .private_layout.rq_state_size == $rq_state and
	  .private_layout.conservative_bytes_per_rq == 74688 and
	  .private_layout.hard_limit_per_rq == 98304 and
	  .private_layout_envelope_passed == true and
	  .runtime_behavior_approved == false and
	  .production_protection == false
	' "$recorded/result.json" >/dev/null ||
		die "$architecture recorded result differs from ELF"

	printf '%s\t51\t0\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tpassed\n' \
		"$architecture" "$private_symbols" "$disabled_symbols" \
		"$disabled_relocations" "$disabled_strings" "$sched_entity" \
		"$cfs_rq" "$rq" "$task" "$slot" "$top" "$control" "$rq_state" \
		"$conservative" "$hard_limit" \
		>> "$OUT_DIR/architecture-summary.tsv"
}

validate_architecture arm64 nm readelf
validate_architecture x86_64 x86_64-linux-gnu-nm \
	x86_64-linux-gnu-readelf

find "$E2_ROOT" -maxdepth 1 -type f -name '*.log' -print | sort \
	> "$OUT_DIR/build-logs.txt"
log_count=$(wc -l < "$OUT_DIR/build-logs.txt" | tr -d ' ')
[ "$log_count" = 24 ] || die "expected 24 build logs, found $log_count"
: > "$OUT_DIR/build-diagnostics.txt"
while IFS= read -r log; do
	if grep -Ein 'warning:|error:|fatal:|undefined reference|internal compiler|failed' \
		"$log" >> "$OUT_DIR/build-diagnostics.txt"; then
		die "build diagnostic found: $log"
	fi
done < "$OUT_DIR/build-logs.txt"

config_manifest_sha=$(file_sha "$OUT_DIR/config-hashes.tsv")
object_manifest_sha=$(file_sha "$OUT_DIR/object-hashes.tsv")
summary_sha=$(file_sha "$OUT_DIR/architecture-summary.tsv")
source_manifest_sha=$(file_sha "$fresh_source_manifest")
candidate_diff_sha=$(file_sha "$OUT_DIR/candidate.diff")

jq -S -n \
	--arg run_id "$RUN_ID" \
	--arg input_contract "$CONFIG" \
	--arg input_contract_sha "$EXPECTED_CONFIG_SHA" \
	--arg source_gate "$SOURCE_GATE" \
	--arg source_gate_sha "$EXPECTED_SOURCE_GATE_SHA" \
	--arg e2_result "$E2_RESULT" --arg e2_sha "$EXPECTED_E2_SHA" \
	--arg source_manifest "$fresh_source_manifest" \
	--arg source_manifest_sha "$source_manifest_sha" \
	--arg config_manifest "$OUT_DIR/config-hashes.tsv" \
	--arg config_manifest_sha "$config_manifest_sha" \
	--arg object_manifest "$OUT_DIR/object-hashes.tsv" \
	--arg object_manifest_sha "$object_manifest_sha" \
	--arg summary "$OUT_DIR/architecture-summary.tsv" \
	--arg summary_sha "$summary_sha" \
	--arg diagnostics "$OUT_DIR/build-diagnostics.txt" \
	--arg primary_commit "$expected_parent" \
	--arg candidate_commit "$expected_candidate" \
	--arg candidate_tree "$expected_tree" \
	--arg candidate_diff_sha "$candidate_diff_sha" \
	--arg patch_queue_commit "$patch_queue_commit" \
	--arg patch_queue_series_blob "$series_working_blob" \
	--argjson build_log_count "$log_count" '
{
  schema_version:1,
  run_id:$run_id,
  status:"passed_r6_e2_evidence_closure",
  input_contract:$input_contract,
  input_contract_sha256:$input_contract_sha,
  source_gate:$source_gate,
  source_gate_sha256:$source_gate_sha,
  dual_arch_result:$e2_result,
  dual_arch_result_sha256:$e2_sha,
  primary_linux_commit:$primary_commit,
  candidate_commit:$candidate_commit,
  candidate_tree:$candidate_tree,
  candidate_diff_sha256:$candidate_diff_sha,
  exact_direct_child:true,
  exact_two_file_scope:true,
  source_file_hash_manifest:$source_manifest,
  source_file_hash_manifest_sha256:$source_manifest_sha,
  source_file_hash_count:16,
  source_files_match_head:true,
  patch_queue_commit:$patch_queue_commit,
  patch_queue_series_blob:$patch_queue_series_blob,
  patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",
  config_hash_manifest:$config_manifest,
  config_hash_manifest_sha256:$config_manifest_sha,
  configurations_revalidated:8,
  object_hash_manifest:$object_manifest,
  object_hash_manifest_sha256:$object_manifest_sha,
  objects_revalidated:14,
  architecture_summary:$summary,
  architecture_summary_sha256:$summary_sha,
  architectures:["arm64","x86_64"],
  modes_per_architecture:4,
  build_log_count:$build_log_count,
  build_diagnostics:$diagnostics,
  build_diagnostic_count:0,
  existing_probe_symbol_count_per_architecture:51,
  existing_probe_value_changes_per_architecture:0,
  private_probe_symbol_count_per_architecture:49,
  private_disabled_symbol_count:0,
  private_disabled_relocation_count:0,
  private_disabled_string_count:0,
  ordinary_scheduler_layout_delta:{
    sched_entity:0,cfs_rq:0,rq:0,task_struct:0
  },
  private_layout:{
    b_max:64,
    top_node_count:127,
    slot_state_max_bytes:1024,
    top_node_max_bytes:64,
    rq_control_max_bytes:1024,
    conservative_bytes_per_rq:74688,
    hard_limit_bytes_per_rq:98304
  },
  x86_64_slot_at_exact_1024_byte_ceiling:true,
  private_memory_envelope_passed:true,
  dual_arch_r6_e2_complete:true,
  r6_e2_evidence_closed:true,
  r6_e3_plan_may_start:true,
  r6_e3_source_may_start:false,
  separate_r6_e3_plan_required:true,
  primary_linux_changed:false,
  patch_queue_changed:false,
  runtime_behavior_approved:false,
  runtime_denial_correctness:false,
  monitor_verified:false,
  flat_cfs_equivalence:false,
  bare_metal_validated:false,
  performance_claim:false,
  cost_claim:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
chmod -R a-w "$OUT_DIR"
printf 'result=%s\nsha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")"
