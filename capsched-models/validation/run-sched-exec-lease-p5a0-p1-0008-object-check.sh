#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Object/symbol/layout evidence collector for the P5A0.P1 0008 no-behavior
# source-contract patch.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd -- "$REPO_DIR/.." && pwd)

LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG=${DOMAINLEASE_P5A0_P1_CONFIG:-"$REPO_DIR/capsched-models/implementation/sched-exec-lease-p5a0-p1-no-behavior-implementation-v1.json"}
BUILD_TAG=${DOMAINLEASE_BUILD_TAG:-p5a0-p1-0008}
OUT_ROOT=${DOMAINLEASE_P5A0_P1_OBJECT_OUT_ROOT:-"$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a0-p1-0008-object-check"}
RUN_ID=${DOMAINLEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$OUT_ROOT/$RUN_ID"

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_cmd awk
require_cmd cmp
require_cmd git
require_cmd jq
require_cmd nm
require_cmd objdump
require_cmd sha256sum
require_cmd size
require_cmd sort
require_cmd stat

git -C "$LINUX_DIR" rev-parse --git-dir >/dev/null 2>&1 || \
	die "Linux Git tree not found: $LINUX_DIR"
[ -f "$CONFIG" ] || die "implementation contract not found: $CONFIG"

mkdir -p "$OUT_DIR"

expected_commit=$(jq -r '.linux.future_commit' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_commit" = "$expected_commit" ] || \
	die "Linux HEAD $actual_commit does not match contract $expected_commit"

off_build="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-$BUILD_TAG-x86_64"
on_build="$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-$BUILD_TAG-x86_64"
off_core="$off_build/kernel/sched/core.o"
on_core="$on_build/kernel/sched/core.o"
off_exec="$off_build/kernel/sched/exec_lease.o"
on_exec="$on_build/kernel/sched/exec_lease.o"

test -f "$off_build/vmlinux" || die "missing off vmlinux: $off_build"
test -f "$on_build/vmlinux" || die "missing on vmlinux: $on_build"
test -f "$off_core" || die "missing off core.o: $off_core"
test -f "$on_core" || die "missing on core.o: $on_core"
test ! -e "$off_exec" || die "off exec_lease.o unexpectedly present: $off_exec"
test -f "$on_exec" || die "missing on exec_lease.o: $on_exec"

"$LINUX_DIR/scripts/config" --file "$off_build/.config" --state SCHED_EXEC_LEASE > "$OUT_DIR/off-config-state.txt" || true
"$LINUX_DIR/scripts/config" --file "$on_build/.config" --state SCHED_EXEC_LEASE > "$OUT_DIR/on-config-state.txt" || true
grep -qx 'undef' "$OUT_DIR/off-config-state.txt" || die "off config is not undef"
grep -qx 'y' "$OUT_DIR/on-config-state.txt" || die "on config is not y"

size "$off_core" "$on_core" "$on_exec" > "$OUT_DIR/object-size.txt"
objdump -h "$off_core" > "$OUT_DIR/off-core-sections.txt"
objdump -h "$on_core" > "$OUT_DIR/on-core-sections.txt"
objdump -h "$on_exec" > "$OUT_DIR/on-exec-lease-sections.txt"
objdump -dr "$on_exec" > "$OUT_DIR/on-exec-lease-disassembly.txt"
sha256sum "$off_core" "$on_core" "$on_exec" > "$OUT_DIR/object-sha256.txt"

make_function_table()
{
	local obj="$1"
	nm -S --defined-only "$obj" | awk '
		$2 ~ /^[0-9a-fA-F]+$/ && $3 ~ /^[TtWw]$/ {
			print $4 "\t" $2 "\t" $3
		}
	' | sort
}

make_function_table "$off_core" > "$OUT_DIR/off-core-function-sizes.tsv"
make_function_table "$on_core" > "$OUT_DIR/on-core-function-sizes.tsv"
cmp -s "$OUT_DIR/off-core-function-sizes.tsv" "$OUT_DIR/on-core-function-sizes.tsv" || \
	die "off/on core.o function-size tables differ"

off_core_file_size=$(stat -c '%s' "$off_core")
on_core_file_size=$(stat -c '%s' "$on_core")
[ "$off_core_file_size" = "$on_core_file_size" ] || \
	die "off/on core.o file sizes differ: $off_core_file_size/$on_core_file_size"

off_core_fn_count=$(wc -l < "$OUT_DIR/off-core-function-sizes.tsv")
on_core_fn_count=$(wc -l < "$OUT_DIR/on-core-function-sizes.tsv")
off_core_fn_hash=$(sha256sum "$OUT_DIR/off-core-function-sizes.tsv" | awk '{ print $1 }')
on_core_fn_hash=$(sha256sum "$OUT_DIR/on-core-function-sizes.tsv" | awk '{ print $1 }')

if nm "$off_core" "$on_core" "$on_exec" | \
	grep -E 'sched_exec_lease_validate|sched_exec_allow_all_validation' \
	> "$OUT_DIR/forbidden-validation-symbols.txt"; then
	die "found emitted validation helper symbol"
fi
: > "$OUT_DIR/forbidden-validation-symbols.txt"

nm -S --size-sort "$on_exec" | awk '
	$4 ~ /^sched_exec_task_/ {
		print $4 "\t0x" $2
	}
' > "$OUT_DIR/on-exec-lease-task-symbols.tsv"

expected_symbols="$OUT_DIR/expected-on-exec-lease-task-symbols.tsv"
cat > "$expected_symbols" <<'EOF'
sched_exec_task_exit	0x0000000000000011
sched_exec_task_commit_exec	0x0000000000000023
sched_exec_task_prepare_fork	0x0000000000000040
sched_exec_task_reset	0x0000000000000040
EOF
cmp -s "$expected_symbols" "$OUT_DIR/on-exec-lease-task-symbols.tsv" || \
	die "unexpected exec_lease.o task symbol set or sizes"

on_exec_text=$(awk '$NF == "'"$on_exec"'" { print $1 }' "$OUT_DIR/object-size.txt")
on_exec_data=$(awk '$NF == "'"$on_exec"'" { print $2 }' "$OUT_DIR/object-size.txt")
on_exec_bss=$(awk '$NF == "'"$on_exec"'" { print $3 }' "$OUT_DIR/object-size.txt")
on_exec_dec=$(awk '$NF == "'"$on_exec"'" { print $4 }' "$OUT_DIR/object-size.txt")

if [ "$on_exec_text" != "289" ] || [ "$on_exec_data" != "32" ] || \
	[ "$on_exec_bss" != "0" ] || [ "$on_exec_dec" != "321" ]; then
	die "unexpected exec_lease.o size tuple: text=$on_exec_text data=$on_exec_data bss=$on_exec_bss dec=$on_exec_dec"
fi

{
	printf 'property\tvalue\tevidence\n'
	printf 'work_commit_matches\ttrue\t%s\n' "$actual_commit"
	printf 'build_tag\t%s\tinput\n' "$BUILD_TAG"
	printf 'config_off_undef\ttrue\t%s\n' "$OUT_DIR/off-config-state.txt"
	printf 'config_on_y\ttrue\t%s\n' "$OUT_DIR/on-config-state.txt"
	printf 'off_vmlinux_present\ttrue\t%s\n' "$off_build/vmlinux"
	printf 'on_vmlinux_present\ttrue\t%s\n' "$on_build/vmlinux"
	printf 'off_exec_lease_object_absent\ttrue\t%s\n' "$off_exec"
	printf 'on_exec_lease_object_present\ttrue\t%s\n' "$on_exec"
	printf 'core_o_file_size_equal\ttrue\t%s/%s\n' "$off_core_file_size" "$on_core_file_size"
	printf 'core_function_size_table_equal\ttrue\t%s\n' "$OUT_DIR/off-core-function-sizes.tsv"
	printf 'core_function_count\t%s\t%s\n' "$off_core_fn_count" "$OUT_DIR/off-core-function-sizes.tsv"
	printf 'core_function_hash_equal\ttrue\t%s\n' "$off_core_fn_hash"
	printf 'validation_symbols_emitted\tfalse\t%s\n' "$OUT_DIR/forbidden-validation-symbols.txt"
	printf 'exec_lease_task_symbols_expected\ttrue\t%s\n' "$OUT_DIR/on-exec-lease-task-symbols.tsv"
	printf 'exec_lease_o_text\t%s\t%s\n' "$on_exec_text" "$OUT_DIR/object-size.txt"
	printf 'exec_lease_o_data\t%s\t%s\n' "$on_exec_data" "$OUT_DIR/object-size.txt"
	printf 'exec_lease_o_bss\t%s\t%s\n' "$on_exec_bss" "$OUT_DIR/object-size.txt"
	printf 'exec_lease_o_dec\t%s\t%s\n' "$on_exec_dec" "$OUT_DIR/object-size.txt"
	printf 'runtime_denial\tfalse\tnon-claim\n'
	printf 'runtime_coverage\tfalse\tnon-claim\n'
	printf 'production_protection\tfalse\tnon-claim\n'
} > "$OUT_DIR/p5a0-p1-object-proof.tsv"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg work_commit "$actual_commit" \
	--arg build_tag "$BUILD_TAG" \
	--arg core_function_hash "$off_core_fn_hash" \
	--argjson core_function_count "$off_core_fn_count" \
	--argjson core_o_file_size "$off_core_file_size" \
	--argjson exec_lease_o_text "$on_exec_text" \
	--argjson exec_lease_o_data "$on_exec_data" \
	--argjson exec_lease_o_bss "$on_exec_bss" \
	--argjson exec_lease_o_dec "$on_exec_dec" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  work_commit: $work_commit,
	  build_tag: $build_tag,
	  config_off_undef: true,
	  config_on_y: true,
	  off_exec_lease_object_absent: true,
	  on_exec_lease_object_present: true,
	  core_o_file_size_equal: true,
	  core_function_size_table_equal: true,
	  core_function_count: $core_function_count,
	  core_function_hash: $core_function_hash,
	  validation_symbols_emitted: false,
	  exec_lease_task_symbols_expected: true,
	  exec_lease_o_size: {
	    text: $exec_lease_o_text,
	    data: $exec_lease_o_data,
	    bss: $exec_lease_o_bss,
	    dec: $exec_lease_o_dec
	  },
	  runtime_denial: false,
	  runtime_coverage: false,
	  monitor_verified: false,
	  production_protection: false
	}' > "$OUT_DIR/result.json"

printf '[domainlease] P5A0.P1 0008 object check completed\n'
printf '[domainlease] run_dir=%s\n' "$OUT_DIR"
cat "$OUT_DIR/p5a0-p1-object-proof.tsv"
