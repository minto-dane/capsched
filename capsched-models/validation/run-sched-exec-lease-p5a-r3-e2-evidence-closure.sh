#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r3-e2-private-layout-candidate-v1.json"
E2_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e2-dual-arch-layout/20260715T-p5a-r3-e2-dual-arch"
E2_RESULT="$E2_ROOT/result.json"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r3-e2-dual-arch/20260715T-p5a-r3-e2-dual-arch"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e2-evidence-closure/$RUN_ID"
EXPECTED_E2_SHA=48a4a0f358896f0e552173f5e308970ef14dc83a58beef62caaed03e360e7038

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for cmd in awk diff git grep jq nm readelf sha256sum sort strings wc x86_64-linux-gnu-nm x86_64-linux-gnu-readelf x86_64-linux-gnu-strings; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done
mkdir -p "$OUT_DIR"

e2_sha=$(sha256sum "$E2_RESULT" | awk '{print $1}')
[ "$e2_sha" = "$EXPECTED_E2_SHA" ] || die "E2 result hash moved: $e2_sha"
config_sha=$(sha256sum "$CONFIG" | awk '{print $1}')
[ "$config_sha" = "$(jq -r '.config_sha256' "$E2_RESULT")" ] || die "E2 input contract hash moved: $config_sha"
jq -e '
  .status == "passed" and
  .primary_linux_commit == "5e1ca3037e34823d1ba0cdd1dc04161fac170280" and
  .candidate_commit == "63313b329e1d44901acfce30698613c38615c8d5" and
  .candidate_tree == "8d51c596d3d73a6c6dc507b84fdcd4ac8aa7f8eb" and
  .source_files_match_head == true and
  .architectures == ["arm64", "x86_64"] and
  .fresh_architecture_local_baselines == true and
  .cross_architecture_byte_identity_required == false and
  .existing_expanded_probe_values_preserved == 51 and
  .private_probe_symbols_enabled == 43 and
  .private_symbols_and_relocations_absent_when_disabled == true and
  .ordinary_scheduler_layout_delta_zero == true and
  .private_memory_envelope_passed == true and
  .dual_arch_e2_complete == true and
  .e3_plan_may_start == true and
  .e3_source_may_start == false and
  .primary_linux_changed == false and
  .patch_queue_changed == false and
  .runtime_behavior_approved == false and
  .production_protection == false and
  .deployment_ready == false and
  .datacenter_ready == false
' "$E2_RESULT" >/dev/null

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_candidate=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff_sha=$(jq -r '.source.diff_sha256' "$CONFIG")
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_parent" ] || die 'primary Linux moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$expected_candidate" ] || die 'candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$expected_parent" ] || die 'candidate is not a direct child'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$expected_tree" ] || die 'candidate tree moved'
git -C "$CANDIDATE_DIR" diff --name-only "$expected_parent..$expected_candidate" > "$OUT_DIR/delta-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-delta-files.txt"
diff -u "$OUT_DIR/expected-delta-files.txt" "$OUT_DIR/delta-files.txt" > "$OUT_DIR/delta-files.diff" || die 'candidate escaped exact two-file scope'
git -C "$CANDIDATE_DIR" diff "$expected_parent..$expected_candidate" > "$OUT_DIR/candidate.diff"
candidate_diff_sha=$(sha256sum "$OUT_DIR/candidate.diff" | awk '{print $1}')
[ "$candidate_diff_sha" = "$expected_diff_sha" ] || die 'candidate diff hash moved'

patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
[ "$patch_queue_commit" = 2a022dce54679ce5ecb86581bf55199dc28c868b ] || die 'patch queue commit moved'
series=patches/capsched-linux-l0/series
series_head_blob=$(git -C "$PATCH_QUEUE_DIR" rev-parse "HEAD:$series")
series_working_blob=$(git -C "$PATCH_QUEUE_DIR" hash-object "$series")
[ "$series_working_blob" = "$series_head_blob" ] || die 'patch queue series has working-tree changes'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/$series")" = 0014-sched-exec_lease-Expand-build-only-layout-probe.patch ] || die 'patch queue tail moved'

manifest=$(jq -r '.source_file_hash_manifest' "$E2_RESULT")
manifest_sha=$(sha256sum "$manifest" | awk '{print $1}')
[ "$manifest_sha" = "$(jq -r '.source_file_hash_manifest_sha256' "$E2_RESULT")" ] || die 'source manifest hash moved'
manifest_count=0
while IFS=$'\t' read -r label path recorded_expected recorded_working; do
	[ "$label" != tree ] || continue
	case "$label" in
		primary) tree=$PRIMARY_DIR ;;
		candidate) tree=$CANDIDATE_DIR ;;
		*) die "unknown source manifest label: $label" ;;
	esac
	expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
	working_blob=$(git -C "$tree" hash-object "$path")
	[ "$recorded_expected" = "$expected_blob" ] || die "$label recorded expected blob moved: $path"
	[ "$recorded_working" = "$working_blob" ] || die "$label recorded working blob moved: $path"
	[ "$working_blob" = "$expected_blob" ] || die "$label source differs from HEAD: $path"
	manifest_count=$((manifest_count + 1))
done < "$manifest"
[ "$manifest_count" = 28 ] || die "source manifest entry count: $manifest_count"

jq -r '.probe.expected_added_symbol_names[]' "$CONFIG" | sort > "$OUT_DIR/expected-private-symbols.txt"
printf 'architecture\texisting_symbols\tchanged_existing\tprivate_symbols\tdisabled_symbols\tdisabled_relocations\tdisabled_strings\tsched_entity_delta\tcfs_rq_delta\trq_delta\ttask_struct_delta\tkey\tbucket\tprojection\trq_state\tworst_private\tenvelope\n' > "$OUT_DIR/architecture-summary.tsv"

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

for architecture in arm64 x86_64; do
	case "$architecture" in
		arm64)
			nm_cmd=nm; readelf_cmd=readelf; strings_cmd=strings
			expected_sched_entity=320; expected_cfs_rq=384; expected_rq=3520; expected_task=4160
			;;
		x86_64)
			nm_cmd=x86_64-linux-gnu-nm; readelf_cmd=x86_64-linux-gnu-readelf; strings_cmd=x86_64-linux-gnu-strings
			expected_sched_entity=320; expected_cfs_rq=384; expected_rq=3392; expected_task=3328
			;;
	esac
	arch_result="$E2_ROOT/$architecture/result.json"
	arch_result_sha=$(sha256sum "$arch_result" | awk '{print $1}')
	[ "$arch_result_sha" = "$(jq -r --arg architecture "$architecture" '.[$architecture + "_result_sha256"]' "$E2_RESULT")" ] || die "$architecture result hash moved"
	jq -e --arg architecture "$architecture" '
	  .status == "passed" and
	  .architecture == $architecture and
	  .fresh_architecture_local_baseline == true and
	  .existing_probe_symbol_count == 51 and
	  .existing_probe_values_changed == 0 and
	  .private_probe_symbol_count == 43 and
	  .private_symbols_absent_baseline == true and
	  .private_symbols_absent_private_off == true and
	  .private_symbols_absent_normal == true and
	  .private_relocations_absent_private_off == true and
	  .private_relocations_absent_normal == true and
	  .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
	  .private_layout_envelope_passed == true and
	  .runtime_behavior_approved == false and
	  .production_protection == false
	' "$arch_result" >/dev/null

	arch_build="$BUILD_ROOT/$architecture"
	baseline_lp="$arch_build/baseline/kernel/sched/exec_lease_layout_probe.o"
	off_lp="$arch_build/private-off/kernel/sched/exec_lease_layout_probe.o"
	on_lp="$arch_build/private-on/kernel/sched/exec_lease_layout_probe.o"
	baseline_exec="$arch_build/baseline/kernel/sched/exec_lease.o"
	off_exec="$arch_build/private-off/kernel/sched/exec_lease.o"
	on_exec="$arch_build/private-on/kernel/sched/exec_lease.o"
	normal_exec="$arch_build/normal/kernel/sched/exec_lease.o"
	for object in "$baseline_lp" "$off_lp" "$on_lp" "$baseline_exec" "$off_exec" "$on_exec" "$normal_exec"; do
		[ -s "$object" ] || die "$architecture object missing: $object"
	done

	[ "$(sha256sum "$baseline_lp" | awk '{print $1}')" = "$(jq -r '.baseline_probe_object_sha256' "$arch_result")" ] || die "$architecture baseline object hash moved"
	[ "$(sha256sum "$on_lp" | awk '{print $1}')" = "$(jq -r '.candidate_probe_object_sha256' "$arch_result")" ] || die "$architecture candidate probe object hash moved"
	[ "$(sha256sum "$on_exec" | awk '{print $1}')" = "$(jq -r '.private_probe_object_sha256' "$arch_result")" ] || die "$architecture private probe object hash moved"

	extract_symbols "$nm_cmd" "$baseline_lp" sched_exec_lp_ "$OUT_DIR/$architecture-baseline-expanded.tsv"
	extract_symbols "$nm_cmd" "$off_lp" sched_exec_lp_ "$OUT_DIR/$architecture-private-off-expanded.tsv"
	extract_symbols "$nm_cmd" "$on_lp" sched_exec_lp_ "$OUT_DIR/$architecture-private-on-expanded.tsv"
	diff -u "$OUT_DIR/$architecture-baseline-expanded.tsv" "$OUT_DIR/$architecture-private-off-expanded.tsv" > "$OUT_DIR/$architecture-baseline-vs-off.diff" || die "$architecture private-off changed existing values"
	diff -u "$OUT_DIR/$architecture-baseline-expanded.tsv" "$OUT_DIR/$architecture-private-on-expanded.tsv" > "$OUT_DIR/$architecture-baseline-vs-on.diff" || die "$architecture private-on changed existing values"
	diff -u "$(jq -r '.existing_probe_value_table' "$arch_result")" "$OUT_DIR/$architecture-baseline-expanded.tsv" > "$OUT_DIR/$architecture-recorded-existing.diff" || die "$architecture recorded existing values moved"
	existing_count=$(wc -l < "$OUT_DIR/$architecture-baseline-expanded.tsv" | tr -d ' ')
	[ "$existing_count" = 51 ] || die "$architecture existing symbol count: $existing_count"

	extract_symbols "$nm_cmd" "$baseline_exec" sched_exec_bl_ "$OUT_DIR/$architecture-baseline-private.tsv"
	extract_symbols "$nm_cmd" "$off_exec" sched_exec_bl_ "$OUT_DIR/$architecture-private-off-private.tsv"
	extract_symbols "$nm_cmd" "$on_exec" sched_exec_bl_ "$OUT_DIR/$architecture-private-on-private.tsv"
	extract_symbols "$nm_cmd" "$normal_exec" sched_exec_bl_ "$OUT_DIR/$architecture-normal-private.tsv"
	disabled_symbol_count=$(awk 'FNR == 1 {files++} {rows++} END {print rows+0}' "$OUT_DIR/$architecture-baseline-private.tsv" "$OUT_DIR/$architecture-private-off-private.tsv" "$OUT_DIR/$architecture-normal-private.tsv")
	[ "$disabled_symbol_count" = 0 ] || die "$architecture disabled private symbols: $disabled_symbol_count"
	private_count=$(wc -l < "$OUT_DIR/$architecture-private-on-private.tsv" | tr -d ' ')
	[ "$private_count" = 43 ] || die "$architecture private symbol count: $private_count"
	awk '{print $1}' "$OUT_DIR/$architecture-private-on-private.tsv" > "$OUT_DIR/$architecture-private-symbol-names.txt"
	diff -u "$OUT_DIR/expected-private-symbols.txt" "$OUT_DIR/$architecture-private-symbol-names.txt" > "$OUT_DIR/$architecture-private-symbol-set.diff" || die "$architecture private symbol set moved"
	diff -u "$(jq -r '.private_probe_value_table' "$arch_result")" "$OUT_DIR/$architecture-private-on-private.tsv" > "$OUT_DIR/$architecture-recorded-private.diff" || die "$architecture recorded private values moved"

	disabled_relocations=0
	disabled_strings=0
	for mode in private-off normal; do
		case "$mode" in private-off) object=$off_exec ;; normal) object=$normal_exec ;; esac
		"$readelf_cmd" -rW "$object" > "$OUT_DIR/$architecture-$mode-relocations.txt"
		if grep -F sched_exec_bl_ "$OUT_DIR/$architecture-$mode-relocations.txt" >> "$OUT_DIR/$architecture-forbidden-disabled-relocations.txt"; then
			disabled_relocations=$((disabled_relocations + 1))
		fi
		if "$strings_cmd" "$object" | grep -E 'sched_exec_bucket|sched_exec_bl_' >> "$OUT_DIR/$architecture-forbidden-disabled-strings.txt"; then
			disabled_strings=$((disabled_strings + 1))
		fi
	done
	[ "$disabled_relocations" = 0 ] || die "$architecture disabled private relocations found"
	[ "$disabled_strings" = 0 ] || die "$architecture disabled private strings found"
	: > "$OUT_DIR/$architecture-forbidden-disabled-relocations.txt"
	: > "$OUT_DIR/$architecture-forbidden-disabled-strings.txt"

	grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$arch_build/baseline/.config" || die "$architecture baseline existing probe config missing"
	! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$arch_build/baseline/.config" || die "$architecture baseline private probe enabled"
	grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$arch_build/private-off/.config" || die "$architecture private-off existing probe missing"
	! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$arch_build/private-off/.config" || die "$architecture private-off private probe enabled"
	grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$arch_build/private-on/.config" || die "$architecture private-on existing probe missing"
	grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$arch_build/private-on/.config" || die "$architecture private-on private probe missing"
	! grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$arch_build/normal/.config" || die "$architecture normal existing probe enabled"
	! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE=y$' "$arch_build/normal/.config" || die "$architecture normal private probe enabled"

	existing="$OUT_DIR/$architecture-baseline-expanded.tsv"
	private="$OUT_DIR/$architecture-private-on-private.tsv"
	sched_entity=$(symbol_value "$existing" sched_exec_lp_sched_entity_size)
	cfs_rq=$(symbol_value "$existing" sched_exec_lp_cfs_rq_size)
	rq=$(symbol_value "$existing" sched_exec_lp_rq_size)
	task=$(symbol_value "$existing" sched_exec_lp_task_struct_size)
	[ "$sched_entity" = "$expected_sched_entity" ] || die "$architecture sched_entity baseline moved"
	[ "$cfs_rq" = "$expected_cfs_rq" ] || die "$architecture cfs_rq baseline moved"
	[ "$rq" = "$expected_rq" ] || die "$architecture rq baseline moved"
	[ "$task" = "$expected_task" ] || die "$architecture task_struct baseline moved"
	key=$(symbol_value "$private" sched_exec_bl_key_size)
	bucket=$(symbol_value "$private" sched_exec_bl_bucket_size)
	projection=$(symbol_value "$private" sched_exec_bl_projection_size)
	rq_state=$(symbol_value "$private" sched_exec_bl_rq_state_size)
	b_max=$(symbol_value "$private" sched_exec_bl_b_max_value)
	worst_private=$(symbol_value "$private" sched_exec_bl_worst_private_bytes_per_rq_value)
	[ "$b_max" = 64 ] || die "$architecture B_max moved"
	[ "$key" -le 64 ] && [ "$bucket" -le 256 ] && [ "$projection" -le 896 ] && [ "$rq_state" -le 448 ] || die "$architecture private object envelope failed"
	[ "$worst_private" = "$((b_max * projection + rq_state))" ] || die "$architecture private arithmetic failed"
	[ "$worst_private" -le 65536 ] || die "$architecture private rq envelope failed"
	for symbol in sched_exec_bl_key_alignment_value sched_exec_bl_bucket_alignment_value sched_exec_bl_projection_alignment_value sched_exec_bl_rq_state_alignment_value; do
		[ "$(symbol_value "$private" "$symbol")" -le 64 ] || die "$architecture private alignment failed: $symbol"
	done

	jq -e \
		--argjson sched_entity "$sched_entity" --argjson cfs_rq "$cfs_rq" --argjson rq "$rq" --argjson task "$task" \
		--argjson key "$key" --argjson bucket "$bucket" --argjson projection "$projection" --argjson rq_state "$rq_state" \
		--argjson b_max "$b_max" --argjson worst_private "$worst_private" '
	  .ordinary_layout == {sched_entity:$sched_entity,cfs_rq:$cfs_rq,rq:$rq,task_struct:$task} and
	  .ordinary_layout_delta == {sched_entity:0,cfs_rq:0,rq:0,task_struct:0} and
	  .private_layout.b_max == $b_max and
	  .private_layout.key_size == $key and
	  .private_layout.bucket_size == $bucket and
	  .private_layout.projection_size == $projection and
	  .private_layout.rq_state_size == $rq_state and
	  .private_layout.worst_active_bytes_per_rq == $worst_private
	' "$arch_result" >/dev/null || die "$architecture result values do not match ELF"

	printf '%s\t%s\t0\t%s\t%s\t%s\t%s\t0\t0\t0\t0\t%s\t%s\t%s\t%s\t%s\tpassed\n' \
		"$architecture" "$existing_count" "$private_count" "$disabled_symbol_count" "$disabled_relocations" "$disabled_strings" \
		"$key" "$bucket" "$projection" "$rq_state" "$worst_private" >> "$OUT_DIR/architecture-summary.tsv"
done

arm_result_sha=$(sha256sum "$E2_ROOT/arm64/result.json" | awk '{print $1}')
x86_result_sha=$(sha256sum "$E2_ROOT/x86_64/result.json" | awk '{print $1}')
summary_sha=$(sha256sum "$OUT_DIR/architecture-summary.tsv" | awk '{print $1}')
manifest_sha=$(sha256sum "$manifest" | awk '{print $1}')

jq -n \
	--arg run_id "$RUN_ID" --arg e2_result "$E2_RESULT" --arg e2_sha "$e2_sha" \
	--arg config "$CONFIG" --arg config_sha "$config_sha" \
	--arg arm_result "$E2_ROOT/arm64/result.json" --arg arm_result_sha "$arm_result_sha" \
	--arg x86_result "$E2_ROOT/x86_64/result.json" --arg x86_result_sha "$x86_result_sha" \
	--arg source_manifest "$manifest" --arg source_manifest_sha "$manifest_sha" --argjson source_manifest_count "$manifest_count" \
	--arg summary "$OUT_DIR/architecture-summary.tsv" --arg summary_sha "$summary_sha" \
	--arg primary_commit "$expected_parent" --arg candidate_commit "$expected_candidate" --arg candidate_tree "$expected_tree" \
	--arg candidate_diff_sha "$candidate_diff_sha" --arg patch_queue_commit "$patch_queue_commit" --arg series_blob "$series_working_blob" \
	'{schema_version:1,run_id:$run_id,status:"passed_for_e3_planning_only",input_contract:$config,input_contract_sha256:$config_sha,primary_linux_commit:$primary_commit,candidate_commit:$candidate_commit,candidate_tree:$candidate_tree,candidate_diff_sha256:$candidate_diff_sha,exact_direct_child:true,exact_two_file_scope:true,source_file_hash_manifest:$source_manifest,source_file_hash_manifest_sha256:$source_manifest_sha,source_file_hash_count:$source_manifest_count,source_files_match_head:true,patch_queue_commit:$patch_queue_commit,patch_queue_series_blob:$series_blob,patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",e2_result:$e2_result,e2_result_sha256:$e2_sha,arm64_result:$arm_result,arm64_result_sha256:$arm_result_sha,x86_64_result:$x86_result,x86_64_result_sha256:$x86_result_sha,architecture_summary:$summary,architecture_summary_sha256:$summary_sha,architectures:["arm64","x86_64"],fresh_architecture_local_baselines:true,existing_probe_symbol_count_per_architecture:51,existing_probe_value_changes_per_architecture:0,private_probe_symbol_count_per_architecture:43,private_disabled_symbol_count:0,private_disabled_relocation_count:0,private_disabled_string_count:0,ordinary_scheduler_layout_delta:{sched_entity:0,cfs_rq:0,rq:0,task_struct:0},private_layout:{key_bytes:64,bucket_bytes:128,projection_bytes:832,rq_state_bytes:448,b_max:64,worst_active_bytes_per_rq:53696,limit_bytes_per_rq:65536},private_memory_envelope_passed:true,dual_arch_e2_complete:true,e3_plan_may_start:true,e3_source_may_start:false,separate_e3_plan_required:true,primary_linux_changed:false,patch_queue_changed:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_layout_accepted:false,production_protection:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"
jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
