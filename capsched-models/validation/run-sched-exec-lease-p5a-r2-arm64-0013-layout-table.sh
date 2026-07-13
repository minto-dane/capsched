#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-arm64-0013-layout-table/$RUN_ID"
SOURCE_RESULT=${DOMAINLEASE_ARM64_LAYOUT_SOURCE_RESULT:-"$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/20260713T140445Z/result.json"}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command_name in awk git jq nm sha256sum sort wc; do
	command -v "$command_name" >/dev/null 2>&1 \
		|| die "missing command: $command_name"
done

mkdir -p "$OUT_DIR"
jq empty "$SOURCE_RESULT"
jq -e '
  .status == "passed" and
  .architecture == "arm64" and
  .config_off_targeted_build == true and
  .config_on_targeted_build == true and
  .normal_off_probe_object_absent == true and
  .normal_on_probe_object_absent == true and
  .explicit_probe_build == true and
  .probe_symbol_count == 24 and
  .runtime_behavior_claim == false and
  .runtime_coverage_claim == false and
  .protection_claim == false and
  .performance_claim == false
' "$SOURCE_RESULT" >/dev/null

expected_commit=$(jq -r '.linux_head' "$SOURCE_RESULT")
expected_tree=$(jq -r '.linux_tree' "$SOURCE_RESULT")
actual_commit=$(git -C "$LINUX_DIR" rev-parse --verify HEAD)
actual_tree=$(git -C "$LINUX_DIR" rev-parse --verify HEAD^{tree})
[ "$actual_commit" = "$expected_commit" ] \
	|| die "Linux commit mismatch: expected=$expected_commit actual=$actual_commit"
[ "$actual_tree" = "$expected_tree" ] \
	|| die "Linux tree mismatch: expected=$expected_tree actual=$actual_tree"
[ -z "$(git -C "$LINUX_DIR" status --porcelain --untracked-files=no)" ] \
	|| die 'Linux tracked working tree is dirty'

probe_obj=$(jq -r '.probe_object' "$SOURCE_RESULT")
probe_sha_expected=$(jq -r '.probe_object_sha256' "$SOURCE_RESULT")
probe_symbol_count_expected=$(jq -r '.probe_symbol_count' "$SOURCE_RESULT")
[ -s "$probe_obj" ] || die "missing probe object: $probe_obj"

probe_sha_actual=$(sha256sum "$probe_obj" | awk '{ print $1 }')
[ "$probe_sha_actual" = "$probe_sha_expected" ] \
	|| die "probe object sha mismatch: expected=$probe_sha_expected actual=$probe_sha_actual"

nm -S "$probe_obj" |
	awk '$4 ~ /^sched_exec_lp_/ { print $1 "\t" $2 "\t" $3 "\t" $4 }' |
	sort -k4 > "$OUT_DIR/probe-symbols.tsv"

probe_symbol_count_actual=$(wc -l < "$OUT_DIR/probe-symbols.tsv")
[ "$probe_symbol_count_actual" = "$probe_symbol_count_expected" ] \
	|| die "probe symbol count mismatch: expected=$probe_symbol_count_expected actual=$probe_symbol_count_actual"

symbol_size_dec()
{
	local sym=$1
	local hex

	hex=$(awk -v sym="$sym" '$4 == sym { print $2 }' "$OUT_DIR/probe-symbols.tsv")
	[ -n "$hex" ] || die "missing symbol: $sym"
	printf '%d' "$((16#$hex))"
}

offset_dec()
{
	local sym=$1
	local plus_one

	plus_one=$(symbol_size_dec "${sym}_offset_plus_one")
	[ "$plus_one" -gt 0 ] || die "invalid zero offset-plus-one symbol: $sym"
	printf '%d' "$((plus_one - 1))"
}

field_size_dec()
{
	symbol_size_dec "${1}_size"
}

emit_struct()
{
	local name=$1
	local sym=$2
	local size

	size=$(symbol_size_dec "${sym}_size")
	printf '%s\tstruct\t-\t%s\t%s_size\n' "$name" "$size" "$sym"
}

emit_field()
{
	local name=$1
	local sym=$2
	local offset
	local size

	offset=$(offset_dec "$sym")
	size=$(field_size_dec "$sym")
	printf '%s\tfield\t%s\t%s\t%s_offset_plus_one,%s_size\n' \
		"$name" "$offset" "$size" "$sym" "$sym"
}

check_within()
{
	local field_name=$1
	local field_sym=$2
	local struct_sym=$3
	local offset
	local size
	local struct_size

	offset=$(offset_dec "$field_sym")
	size=$(field_size_dec "$field_sym")
	struct_size=$(symbol_size_dec "${struct_sym}_size")
	[ "$((offset + size))" -le "$struct_size" ] \
		|| die "$field_name exceeds containing structure"
}

{
	emit_struct "sched_entity" "sched_exec_lp_sched_entity"
	emit_field "sched_entity.run_node" "sched_exec_lp_sched_entity_run_node"
	emit_field "sched_entity.min_vruntime" "sched_exec_lp_sched_entity_min_vruntime"
	emit_field "sched_entity.vruntime" "sched_exec_lp_sched_entity_vruntime"
	emit_struct "cfs_rq" "sched_exec_lp_cfs_rq"
	emit_field "cfs_rq.tasks_timeline" "sched_exec_lp_cfs_rq_tasks_timeline"
	emit_field "cfs_rq.curr" "sched_exec_lp_cfs_rq_curr"
	emit_field "cfs_rq.next" "sched_exec_lp_cfs_rq_next"
	emit_struct "rq" "sched_exec_lp_rq"
	emit_field "rq.nr_running" "sched_exec_lp_rq_nr_running"
	emit_field "rq.curr" "sched_exec_lp_rq_curr"
	emit_field "rq.cfs" "sched_exec_lp_rq_cfs"
	emit_struct "task_struct" "sched_exec_lp_task_struct"
	emit_field "task_struct.sched_exec" "sched_exec_lp_task_struct_sched_exec"
} > "$OUT_DIR/layout-table.tsv"

check_within "sched_entity.run_node" "sched_exec_lp_sched_entity_run_node" "sched_exec_lp_sched_entity"
check_within "sched_entity.min_vruntime" "sched_exec_lp_sched_entity_min_vruntime" "sched_exec_lp_sched_entity"
check_within "sched_entity.vruntime" "sched_exec_lp_sched_entity_vruntime" "sched_exec_lp_sched_entity"
check_within "cfs_rq.tasks_timeline" "sched_exec_lp_cfs_rq_tasks_timeline" "sched_exec_lp_cfs_rq"
check_within "cfs_rq.curr" "sched_exec_lp_cfs_rq_curr" "sched_exec_lp_cfs_rq"
check_within "cfs_rq.next" "sched_exec_lp_cfs_rq_next" "sched_exec_lp_cfs_rq"
check_within "rq.nr_running" "sched_exec_lp_rq_nr_running" "sched_exec_lp_rq"
check_within "rq.curr" "sched_exec_lp_rq_curr" "sched_exec_lp_rq"
check_within "rq.cfs" "sched_exec_lp_rq_cfs" "sched_exec_lp_rq"
check_within "task_struct.sched_exec" "sched_exec_lp_task_struct_sched_exec" "sched_exec_lp_task_struct"

jq -R -s '
  split("\n")
  | map(select(length > 0))
  | map(split("\t") | {
      name: .[0],
      kind: .[1],
      offset: (if .[2] == "-" then null else (.[2] | tonumber) end),
      size: (.[3] | tonumber),
      symbols: (.[4] | split(","))
    })
' "$OUT_DIR/layout-table.tsv" > "$OUT_DIR/layout-table.json"

jq -e '
  (map(select(.name == "sched_entity"))[0].size == 320) and
  (map(select(.name == "cfs_rq"))[0].size == 384) and
  (map(select(.name == "rq"))[0].size == 3520) and
  (map(select(.name == "task_struct"))[0].size == 4160) and
  (map(select(.name == "task_struct.sched_exec"))[0].offset == 1232) and
  (map(select(.name == "task_struct.sched_exec"))[0].size == 40)
' "$OUT_DIR/layout-table.json" >/dev/null

entry_count=$(wc -l < "$OUT_DIR/layout-table.tsv")
struct_count=$(awk '$2 == "struct" { c++ } END { print c + 0 }' "$OUT_DIR/layout-table.tsv")
field_count=$(awk '$2 == "field" { c++ } END { print c + 0 }' "$OUT_DIR/layout-table.tsv")
layout_tsv_sha=$(sha256sum "$OUT_DIR/layout-table.tsv" | awk '{ print $1 }')
layout_json_sha=$(sha256sum "$OUT_DIR/layout-table.json" | awk '{ print $1 }')
compiler=$(jq -r '.compiler' "$SOURCE_RESULT")
kernel_release=$(jq -r '.kernel_release' "$SOURCE_RESULT")

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$actual_commit" \
	--arg linux_tree "$actual_tree" \
	--arg source_result "$SOURCE_RESULT" \
	--arg probe_object "$probe_obj" \
	--arg probe_sha "$probe_sha_actual" \
	--arg compiler "$compiler" \
	--arg kernel_release "$kernel_release" \
	--arg layout_tsv "$OUT_DIR/layout-table.tsv" \
	--arg layout_json "$OUT_DIR/layout-table.json" \
	--arg layout_tsv_sha "$layout_tsv_sha" \
	--arg layout_json_sha "$layout_json_sha" \
	--argjson entry_count "$entry_count" \
	--argjson struct_count "$struct_count" \
	--argjson field_count "$field_count" \
	--slurpfile layout "$OUT_DIR/layout-table.json" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  status: "passed",
	  architecture: "arm64",
	  compiler: $compiler,
	  kernel_release: $kernel_release,
	  linux_commit: $linux_commit,
	  linux_tree: $linux_tree,
	  source_result: $source_result,
	  probe_object: $probe_object,
	  probe_object_sha256: $probe_sha,
	  layout_tsv: $layout_tsv,
	  layout_tsv_sha256: $layout_tsv_sha,
	  layout_json: $layout_json,
	  layout_json_sha256: $layout_json_sha,
	  layout_entry_count: $entry_count,
	  layout_struct_count: $struct_count,
	  layout_field_count: $field_count,
	  fields_within_containing_structures: true,
	  layout: $layout[0],
	  x86_64_byte_identity_claim: false,
	  runtime_behavior_change: false,
	  runtime_denial_correctness: false,
	  production_protection: false,
	  performance_claim: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
