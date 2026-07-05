#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-0013-disabled-overhead/$RUN_ID"

OFF_O=${DOMAINLEASE_P5AR2_0013_OFF_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64"}
ON_O=${DOMAINLEASE_P5AR2_0013_ON_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64"}

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
require_cmd git
require_cmd grep
require_cmd jq
require_cmd make
require_cmd nm
require_cmd sha256sum
require_cmd sort
require_cmd stat
require_cmd wc

mkdir -p "$OUT_DIR"

linux_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
parent_commit=$(git -C "$LINUX_DIR" rev-parse HEAD^)
linux_tree=$(git -C "$LINUX_DIR" rev-parse HEAD^{tree})

[ "$linux_commit" = "0b79e307dc9536d38557141cfd650f2be9a2af57" ] || \
	die "unexpected Linux HEAD for 0013 disabled-overhead check: $linux_commit"

git -C "$LINUX_DIR" diff --name-only "$parent_commit..$linux_commit" | sort \
	> "$OUT_DIR/0013-delta-files.txt"
{
	printf 'init/Kconfig\n'
	printf 'kernel/sched/Makefile\n'
	printf 'kernel/sched/exec_lease_layout_probe.c\n'
} | sort > "$OUT_DIR/0013-expected-files.txt"
diff -u "$OUT_DIR/0013-expected-files.txt" "$OUT_DIR/0013-delta-files.txt" \
	> "$OUT_DIR/0013-file-diff.txt" || die "0013 delta touches files outside the probe boundary"

if git -C "$LINUX_DIR" diff --name-only "$parent_commit..$linux_commit" |
	grep -E '^(kernel/sched/(core|fair|sched|exec_lease)\.(c|h)|include/linux/sched(_exec_lease)?\.h|kernel/fork\.c|fs/exec\.c|kernel/exit\.c)$' \
	> "$OUT_DIR/bad-hot-delta.txt"; then
	die "0013 touches an existing hot/lifecycle scheduler file"
fi

grep -q '^config SCHED_EXEC_LEASE_LAYOUT_PROBE$' "$LINUX_DIR/init/Kconfig" || \
	die "missing layout probe Kconfig"
grep -q '^	default n$' "$LINUX_DIR/init/Kconfig" || \
	die "layout probe Kconfig is not default n"
if grep -n 'select SCHED_EXEC_LEASE_LAYOUT_PROBE' "$LINUX_DIR/init/Kconfig" \
	> "$OUT_DIR/bad-select.txt"; then
	die "normal config can select the layout probe"
fi
grep -Fq 'obj-$(CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE) += exec_lease_layout_probe.o' \
	"$LINUX_DIR/kernel/sched/Makefile" || die "missing layout probe Makefile rule"

[ -f "$OFF_O/.config" ] || die "missing off config: $OFF_O/.config"
[ -f "$ON_O/.config" ] || die "missing on config: $ON_O/.config"

if grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$OFF_O/.config"; then
	die "off normal config enables layout probe"
fi
if grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$ON_O/.config"; then
	die "on normal config enables layout probe"
fi

make -C "$LINUX_DIR" O="$OFF_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o \
	> "$OUT_DIR/off-normal-build.log" 2>&1
make -C "$LINUX_DIR" O="$ON_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o kernel/sched/exec_lease.o \
	> "$OUT_DIR/on-normal-build.log" 2>&1

test ! -e "$OFF_O/kernel/sched/exec_lease_layout_probe.o" || \
	die "off normal build emitted exec_lease_layout_probe.o"
test ! -e "$ON_O/kernel/sched/exec_lease_layout_probe.o" || \
	die "on normal build emitted exec_lease_layout_probe.o"

if [ -f "$OFF_O/include/config/auto.conf" ] &&
	grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$OFF_O/include/config/auto.conf"; then
	die "off auto.conf enables layout probe"
fi
if [ -f "$ON_O/include/config/auto.conf" ] &&
	grep -q '^CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE=y$' "$ON_O/include/config/auto.conf"; then
	die "on auto.conf enables layout probe"
fi

objects=(
	"$OFF_O/kernel/sched/fair.o"
	"$OFF_O/kernel/sched/core.o"
	"$ON_O/kernel/sched/fair.o"
	"$ON_O/kernel/sched/core.o"
	"$ON_O/kernel/sched/exec_lease.o"
)

for obj in "${objects[@]}"; do
	[ -s "$obj" ] || die "missing normal object: $obj"
	if nm "$obj" | grep 'sched_exec_lp_' > "$OUT_DIR/bad-symbols-$(basename "$obj").txt"; then
		die "normal object contains layout probe symbols: $obj"
	fi
done

{
	printf 'config\tobject\tsize\tsha256\n'
	for obj in "${objects[@]}"; do
		case "$obj" in
		"$OFF_O"/*)
			cfg=off
			;;
		"$ON_O"/*)
			cfg=on
			;;
		*)
			cfg=unknown
			;;
		esac
		printf '%s\t%s\t%s\t%s\n' \
			"$cfg" \
			"${obj#"$WORKSPACE_DIR/"}" \
			"$(stat -c '%s' "$obj")" \
			"$(sha256sum "$obj" | awk '{ print $1 }')"
	done
} > "$OUT_DIR/normal-object-ledger.tsv"

object_count=$(awk 'NR > 1 { c++ } END { print c + 0 }' "$OUT_DIR/normal-object-ledger.tsv")
ledger_sha=$(sha256sum "$OUT_DIR/normal-object-ledger.tsv" | awk '{ print $1 }')
off_log_sha=$(sha256sum "$OUT_DIR/off-normal-build.log" | awk '{ print $1 }')
on_log_sha=$(sha256sum "$OUT_DIR/on-normal-build.log" | awk '{ print $1 }')

jq -R -s '
  split("\n")
  | .[1:]
  | map(select(length > 0))
  | map(split("\t") | {
      config: .[0],
      object: .[1],
      size: (.[2] | tonumber),
      sha256: .[3]
    })
' "$OUT_DIR/normal-object-ledger.tsv" > "$OUT_DIR/normal-object-ledger.json"

jq -n \
	--arg run_id "$RUN_ID" \
	--arg linux_commit "$linux_commit" \
	--arg parent_commit "$parent_commit" \
	--arg linux_tree "$linux_tree" \
	--arg off_o "$OFF_O" \
	--arg on_o "$ON_O" \
	--arg ledger "$OUT_DIR/normal-object-ledger.tsv" \
	--arg ledger_sha "$ledger_sha" \
	--arg off_log_sha "$off_log_sha" \
	--arg on_log_sha "$on_log_sha" \
	--argjson object_count "$object_count" \
	--slurpfile objects "$OUT_DIR/normal-object-ledger.json" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  status: "passed",
	  linux_commit: $linux_commit,
	  parent_commit: $parent_commit,
	  linux_tree: $linux_tree,
	  changed_files_only_probe_boundary: true,
	  touched_existing_hot_or_lifecycle_file: false,
	  layout_probe_default_n: true,
	  layout_probe_selected_by_normal_config: false,
	  normal_config_off_probe_object_absent: true,
	  normal_config_on_probe_object_absent: true,
	  normal_objects_with_probe_symbols: false,
	  normal_object_count: $object_count,
	  normal_object_ledger: $ledger,
	  normal_object_ledger_sha256: $ledger_sha,
	  off_build_output_dir: $off_o,
	  on_build_output_dir: $on_o,
	  off_build_log_sha256: $off_log_sha,
	  on_build_log_sha256: $on_log_sha,
	  objects: $objects[0],
	  object_byte_identity_claim: false,
	  runtime_behavior_change: false,
	  runtime_denial_correctness: false,
	  production_protection: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
