#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR=${DOMAINLEASE_LINUX_DIR:-"$WORKSPACE_DIR/linux"}
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r-0009-ordinary-cfs-draft-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r-0009-targeted-build/$RUN_ID"

OFF_O=${DOMAINLEASE_P5AR_0009_OFF_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-off-p5a0-p1-0008-qemu-x86_64"}
ON_O=${DOMAINLEASE_P5AR_0009_ON_O:-"$WORKSPACE_DIR/build/linux-l0-sched-exec-lease-on-p5a0-p1-0008-qemu-x86_64"}

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd()
{
	command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_cmd git
require_cmd jq
require_cmd make
require_cmd sha256sum
require_cmd stat

mkdir -p "$OUT_DIR"
jq empty "$CONFIG"

expected_commit=$(jq -r '.source_basis.linux_commit' "$CONFIG")
actual_commit=$(git -C "$LINUX_DIR" rev-parse HEAD)
[ "$actual_commit" = "$expected_commit" ] || \
	die "linux HEAD mismatch: expected=$expected_commit actual=$actual_commit"

if [ -n "$(git -C "$LINUX_DIR" status --porcelain)" ]; then
	git -C "$LINUX_DIR" status --short > "$OUT_DIR/linux-dirty-status.txt"
	die "Linux tree is dirty"
fi

[ -f /usr/include/gelf.h ] || die "missing /usr/include/gelf.h"
[ -f "$OFF_O/.config" ] || die "missing off .config: $OFF_O/.config"
[ -f "$ON_O/.config" ] || die "missing on .config: $ON_O/.config"

if grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$OFF_O/.config"; then
	die "off build tree unexpectedly has CONFIG_SCHED_EXEC_LEASE=y"
fi
if ! grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$ON_O/.config"; then
	die "on build tree lacks CONFIG_SCHED_EXEC_LEASE=y"
fi

make -C "$LINUX_DIR" O="$OFF_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o \
	> "$OUT_DIR/off-targeted-build.log" 2>&1

make -C "$LINUX_DIR" O="$ON_O" -j"$(nproc)" \
	kernel/sched/fair.o kernel/sched/core.o \
	> "$OUT_DIR/on-targeted-build.log" 2>&1

for obj in \
	"$OFF_O/kernel/sched/fair.o" \
	"$OFF_O/kernel/sched/core.o" \
	"$ON_O/kernel/sched/fair.o" \
	"$ON_O/kernel/sched/core.o"
do
	[ -s "$obj" ] || die "missing object: $obj"
done

sha256sum \
	"$OFF_O/kernel/sched/fair.o" \
	"$OFF_O/kernel/sched/core.o" \
	"$ON_O/kernel/sched/fair.o" \
	"$ON_O/kernel/sched/core.o" \
	> "$OUT_DIR/object-sha256.txt"

stat -c '%n	%s' \
	"$OFF_O/kernel/sched/fair.o" \
	"$OFF_O/kernel/sched/core.o" \
	"$ON_O/kernel/sched/fair.o" \
	"$ON_O/kernel/sched/core.o" \
	> "$OUT_DIR/object-sizes.tsv"

off_fair_size=$(stat -c '%s' "$OFF_O/kernel/sched/fair.o")
off_core_size=$(stat -c '%s' "$OFF_O/kernel/sched/core.o")
on_fair_size=$(stat -c '%s' "$ON_O/kernel/sched/fair.o")
on_core_size=$(stat -c '%s' "$ON_O/kernel/sched/core.o")

off_fair_sha=$(sha256sum "$OFF_O/kernel/sched/fair.o" | awk '{ print $1 }')
off_core_sha=$(sha256sum "$OFF_O/kernel/sched/core.o" | awk '{ print $1 }')
on_fair_sha=$(sha256sum "$ON_O/kernel/sched/fair.o" | awk '{ print $1 }')
on_core_sha=$(sha256sum "$ON_O/kernel/sched/core.o" | awk '{ print $1 }')

jq -n \
	--arg run_id "$RUN_ID" \
	--arg out_dir "$OUT_DIR" \
	--arg linux_commit "$actual_commit" \
	--arg off_o "$OFF_O" \
	--arg on_o "$ON_O" \
	--arg off_fair_sha "$off_fair_sha" \
	--arg off_core_sha "$off_core_sha" \
	--arg on_fair_sha "$on_fair_sha" \
	--arg on_core_sha "$on_core_sha" \
	--argjson off_fair_size "$off_fair_size" \
	--argjson off_core_size "$off_core_size" \
	--argjson on_fair_size "$on_fair_size" \
	--argjson on_core_size "$on_core_size" \
	'{
	  schema_version: 1,
	  run_id: $run_id,
	  out_dir: $out_dir,
	  status: "passed",
	  linux_commit: $linux_commit,
	  gelf_h_present: true,
	  targeted_build_passed: true,
	  config_off: {
	    output_dir: $off_o,
	    sched_exec_lease_enabled: false,
	    fair_o_sha256: $off_fair_sha,
	    core_o_sha256: $off_core_sha,
	    fair_o_size: $off_fair_size,
	    core_o_size: $off_core_size
	  },
	  config_on: {
	    output_dir: $on_o,
	    sched_exec_lease_enabled: true,
	    fair_o_sha256: $on_fair_sha,
	    core_o_sha256: $on_core_sha,
	    fair_o_size: $on_fair_size,
	    core_o_size: $on_core_size
	  },
	  linux_0009_accepted: false,
	  runtime_denial_correctness: false,
	  cfs_deny_and_repick_correctness: false,
	  production_protection: false,
	  cost_efficiency_claim: false
	}' > "$OUT_DIR/result.json"

jq empty "$OUT_DIR/result.json"
cat "$OUT_DIR/result.json"
