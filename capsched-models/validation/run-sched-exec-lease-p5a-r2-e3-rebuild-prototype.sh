#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E2_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r2-e3-rebuild-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CONFIG="$CAPSCHED_DIR/capsched-models/implementation/sched-exec-lease-p5a-r2-e3-disposable-rebuild-kunit-prototype-v1.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/arm64-current/$RUN_ID"
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r2-e3-rebuild-prototype/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-"$OUT_DIR/progress"}
JOBS=${JOBS:-4}
QEMU_TIMEOUT=${QEMU_TIMEOUT:-420}

PARENT_OUT="$BUILD_ROOT/parent"
OFF_OUT="$BUILD_ROOT/e3-off"
LAYOUT_OUT="$BUILD_ROOT/e3-layout-test-off"
KUNIT_OUT="$BUILD_ROOT/e3-kunit-on"
SERIAL_LOG="$OUT_DIR/qemu-serial.log"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
progress()
{
	printf '%s\n' "$*" > "$PROGRESS_FILE"
	printf '[progress] %s\n' "$*"
}

for cmd in awk cmp find git grep jq make nm perl qemu-system-aarch64 sed sha256sum size timeout wc; do
	command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done

rm -rf "$BUILD_ROOT" "$OUT_DIR"
mkdir -p "$BUILD_ROOT" "$OUT_DIR"
progress '5% exact source, primary-boundary, and metadata gates'
jq empty "$CONFIG"

expected_parent=$(jq -r '.source.parent_commit' "$CONFIG")
expected_commit=$(jq -r '.source.candidate_commit' "$CONFIG")
expected_tree=$(jq -r '.source.candidate_tree' "$CONFIG")
expected_diff=$(jq -r '.source.diff_sha256' "$CONFIG")
expected_primary=$(jq -r '.frozen_boundary.primary_linux_commit' "$CONFIG")

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$expected_primary" ] || die 'primary Linux moved'
[ "$(git -C "$E2_DIR" rev-parse HEAD)" = "$expected_parent" ] || die 'E2 parent moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$expected_commit" ] || die 'E3 source moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$expected_parent" ] || die 'E3 parent mismatch'
[ "$(git -C "$E3_DIR" rev-parse HEAD^{tree})" = "$expected_tree" ] || die 'E3 tree mismatch'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux dirty'
[ -z "$(git -C "$E2_DIR" status --porcelain --untracked-files=no)" ] || die 'E2 parent dirty'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 source dirty'
[ "$(tail -n 1 "$PATCH_QUEUE_DIR/patches/capsched-linux-l0/series")" = \
	'0014-sched-exec_lease-Expand-build-only-layout-probe.patch' ] || die 'patch queue moved'

git -C "$E3_DIR" diff "$expected_parent..$expected_commit" > "$OUT_DIR/e3-source.diff"
diff_hash=$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')
[ "$diff_hash" = "$expected_diff" ] || die 'E3 diff hash mismatch'
git -C "$E3_DIR" diff --name-only "$expected_parent..$expected_commit" > "$OUT_DIR/changed-files.txt"
[ "$(sed -n '1p' "$OUT_DIR/changed-files.txt")" = 'init/Kconfig' ] || die 'first changed file mismatch'
[ "$(sed -n '2p' "$OUT_DIR/changed-files.txt")" = 'kernel/sched/fair.c' ] || die 'second changed file mismatch'
[ "$(wc -l < "$OUT_DIR/changed-files.txt" | tr -d ' ')" = 2 ] || die 'E3 changed more than two files'

for frozen in include/linux/sched.h kernel/sched/sched.h kernel/sched/exec_lease_layout_probe.c kernel/sched/Makefile; do
	cmp "$E2_DIR/$frozen" "$E3_DIR/$frozen" >/dev/null || die "frozen file changed: $frozen"
done

jq -e '
  .status == "disposable_source_draft_targeted_compile_passed_unaccepted" and
  .source.allowed_files == ["init/Kconfig","kernel/sched/fair.c"] and
  .source.insertions == 947 and .source.deletions == 0 and
  .source.strict_checkpatch_errors == 0 and
  .source.strict_checkpatch_warnings == 0 and
  .source.strict_checkpatch_checks == 0 and
  .configuration.name == "SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.same_translation_unit == "kernel/sched/fair.c" and
  .configuration.suite_name == "sched_exec_lease_rebuild" and
  (.prototype | [.two_pass_clear_then_rebuild,.rq_lock_assertion,.rb_postorder,.cfs_rq_bottom_up,.current_separate,.tagged_wrap_aware_minimum,.generation_acquire_before_and_after,.generation_saturation_blocked] | all(. == true)) and
  .prototype.recursive_group_walk == false and
  .prototype.numeric_sentinel == false and
  .prototype.partial_or_raced_fresh == false and
  .prototype.topology_mutation == false and
  .prototype.allocation_in_locked_helper == false and
  .prototype.sleep_in_locked_helper == false and
  .prototype.monitor_or_policy_call == false and
  (.oracle | [.independent_fixture_arrays,.direct_signed_delta_comparison,.flat_per_node_check,.exact_leaf_visit_check] | all(. == true)) and
  .oracle.shares_combine_helper == false and
  .oracle.shares_postorder_helper == false and
  .oracle.calls_min_vruntime == false and
  .oracle.exhaustive_leaf_limit == 6 and
  .kunit.test_case_count == 12 and
  .kunit.required_case_family_count == 14 and
  (.kunit.test_cases | length == 12) and
  (.safety_flags | all(.[]; . == false))
' "$CONFIG" >/dev/null

progress '10% source isolation, forbidden-operation, and strict style gates'
kconfig_block="$OUT_DIR/kconfig-block.txt"
awk '
  /^config SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST$/ { active=1 }
  active && /^config / && $2 != "SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST" { exit }
  active { print }
' "$E3_DIR/init/Kconfig" > "$kconfig_block"
grep -Fxq 'config SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST' "$kconfig_block" || die 'missing E3 config'
grep -Fq $'\tdepends on SCHED_EXEC_LEASE_LAYOUT_CANDIDATE && KUNIT=y' "$kconfig_block" || die 'wrong E3 dependency'
grep -Fq $'\tdefault n' "$kconfig_block" || die 'E3 config is not default n'
if grep -Fq 'default KUNIT_ALL_TESTS' "$kconfig_block"; then die 'KUNIT_ALL_TESTS selects E3'; fi

[ "$(grep -c '^#ifdef CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST$' "$E3_DIR/kernel/sched/fair.c")" = 2 ] || die 'unexpected E3 source boundaries'
[ "$(grep -c 'KUNIT_CASE(sched_exec_rebuild_' "$E3_DIR/kernel/sched/fair.c")" = 12 ] || die 'KUnit case count mismatch'
grep -Fq '.name = "sched_exec_lease_rebuild"' "$E3_DIR/kernel/sched/fair.c" || die 'suite name mismatch'

if git -C "$E3_DIR" grep -l 'sched_exec_rebuild' HEAD -- \
	':(exclude)init/Kconfig' ':(exclude)kernel/sched/fair.c' | grep -q .; then
	die 'E3 symbol escaped the two-file boundary'
fi
if git -C "$E3_DIR" grep -Eq 'EXPORT_SYMBOL.*sched_exec_rebuild|sched_exec_publish_generation|sched_exec_rebuild_fanout' HEAD -- .; then
	die 'export, real publisher, or fanout found'
fi

sed -n '/Disposable E3 correctness prototype/,/^#define SCHED_EXEC_TEST_MAX_LEAVES/p' \
	"$E3_DIR/kernel/sched/fair.c" > "$OUT_DIR/locked-prototype.txt"
if grep -Eq '\b(kmalloc|kzalloc|kfree|schedule|cond_resched|msleep|usleep|wait_event|printk|pr_info|trace_)\b|rb_(add|erase)|__enqueue_entity|__dequeue_entity' \
	"$OUT_DIR/locked-prototype.txt"; then
	die 'forbidden operation in locked prototype'
fi

set +e
git -C "$E3_DIR" diff "$expected_parent..$expected_commit" | \
	"$E3_DIR/scripts/checkpatch.pl" --strict --no-tree - > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -Fq 'total: 0 errors, 0 warnings, 0 checks' "$OUT_DIR/checkpatch.log" || die 'strict checkpatch summary mismatch'

configure_parent()
{
	progress '12% configuring exact E2 parent baseline'
	make -C "$E2_DIR" O="$PARENT_OUT" ARCH=arm64 defconfig
	"$E2_DIR/scripts/config" --file "$PARENT_OUT/.config" --enable EXPERT --enable DEBUG_KERNEL
	"$E2_DIR/scripts/config" --file "$PARENT_OUT/.config" --enable SCHED_EXEC_LEASE
	"$E2_DIR/scripts/config" --file "$PARENT_OUT/.config" --enable SCHED_EXEC_LEASE_LAYOUT_PROBE
	"$E2_DIR/scripts/config" --file "$PARENT_OUT/.config" --enable SCHED_EXEC_LEASE_LAYOUT_CANDIDATE
	make -C "$E2_DIR" O="$PARENT_OUT" ARCH=arm64 olddefconfig
}

configure_e3()
{
	local out=$1 mode=$2

	make -C "$E3_DIR" O="$out" ARCH=arm64 defconfig
	"$E3_DIR/scripts/config" --file "$out/.config" --enable EXPERT --enable DEBUG_KERNEL
	case "$mode" in
	off)
		"$E3_DIR/scripts/config" --file "$out/.config" --disable SCHED_EXEC_LEASE
		"$E3_DIR/scripts/config" --file "$out/.config" --disable KUNIT
		"$E3_DIR/scripts/config" --file "$out/.config" --disable SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST
		;;
	layout)
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE_LAYOUT_PROBE
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE_LAYOUT_CANDIDATE
		"$E3_DIR/scripts/config" --file "$out/.config" --disable KUNIT
		"$E3_DIR/scripts/config" --file "$out/.config" --disable SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST
		;;
	kunit)
		"$E3_DIR/scripts/config" --file "$out/.config" --enable CGROUPS
		"$E3_DIR/scripts/config" --file "$out/.config" --enable CGROUP_SCHED
		"$E3_DIR/scripts/config" --file "$out/.config" --enable FAIR_GROUP_SCHED
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE_LAYOUT_PROBE
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE_LAYOUT_CANDIDATE
		"$E3_DIR/scripts/config" --file "$out/.config" --enable KUNIT
		"$E3_DIR/scripts/config" --file "$out/.config" --disable KUNIT_ALL_TESTS
		"$E3_DIR/scripts/config" --file "$out/.config" --enable KUNIT_AUTORUN_ENABLED
		"$E3_DIR/scripts/config" --file "$out/.config" --set-str KUNIT_DEFAULT_FILTER_GLOB sched_exec_lease_rebuild
		"$E3_DIR/scripts/config" --file "$out/.config" --enable SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST
		;;
	*) die "unknown config mode: $mode" ;;
	esac
	make -C "$E3_DIR" O="$out" ARCH=arm64 olddefconfig
}

configure_parent
progress '15% building exact E2 parent fair.o baseline'
make -C "$E2_DIR" O="$PARENT_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o

progress '22% configuring E3 with ordinary lease disabled'
configure_e3 "$OFF_OUT" off
progress '25% building E3 ordinary-off fair.o'
make -C "$E3_DIR" O="$OFF_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o

progress '32% configuring E3 layout-on with rebuild KUnit disabled'
configure_e3 "$LAYOUT_OUT" layout
progress '35% building E3 layout-on/test-off fair.o'
make -C "$E3_DIR" O="$LAYOUT_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o

progress '40% configuring E3 KUnit-enabled arm64 kernel'
configure_e3 "$KUNIT_OUT" kunit
grep -Fxq 'CONFIG_FAIR_GROUP_SCHED=y' "$KUNIT_OUT/.config" || die 'FAIR_GROUP_SCHED missing'
grep -Fxq 'CONFIG_KUNIT=y' "$KUNIT_OUT/.config" || die 'KUNIT missing'
grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_REBUILD_KUNIT_TEST=y' "$KUNIT_OUT/.config" || die 'E3 KUnit config missing'
progress '42% building E3 KUnit-enabled fair.o'
make -C "$E3_DIR" O="$KUNIT_OUT" ARCH=arm64 -j"$JOBS" kernel/sched/fair.o

for mode in parent off layout; do
	case "$mode" in
	parent) object="$PARENT_OUT/kernel/sched/fair.o" ;;
	off) object="$OFF_OUT/kernel/sched/fair.o" ;;
	layout) object="$LAYOUT_OUT/kernel/sched/fair.o" ;;
	esac
	nm --defined-only "$object" > "$OUT_DIR/$mode-fair-symbols.txt"
	if grep -q 'sched_exec_rebuild_' "$OUT_DIR/$mode-fair-symbols.txt"; then
		die "E3 symbols present in $mode fair.o"
	fi
done
nm --defined-only "$KUNIT_OUT/kernel/sched/fair.o" > "$OUT_DIR/kunit-fair-symbols.txt"
grep -q 'sched_exec_rebuild_test_suite' "$OUT_DIR/kunit-fair-symbols.txt" || die 'KUnit suite symbol absent'
for test_name in $(jq -r '.kunit.test_cases[]' "$CONFIG"); do
	grep -q "$test_name" "$OUT_DIR/kunit-fair-symbols.txt" || die "KUnit case symbol absent: $test_name"
done

progress '45% building full arm64 KUnit Image (compiler steps will update this percentage)'
set +e
make -C "$E3_DIR" O="$KUNIT_OUT" ARCH=arm64 -j"$JOBS" Image 2>&1 | {
	steps=0
	while IFS= read -r line; do
		printf '%s\n' "$line"
		case "$line" in
		*'  CC  '*|*'  AS  '*|*'  LD  '*|*'  AR  '*|*'  HOSTCC  '*|*'  HOSTLD  '*)
			steps=$((steps + 1))
			if [ $((steps % 25)) -eq 0 ]; then
				percent=$((45 + steps / 50))
				[ "$percent" -le 83 ] || percent=83
				progress "$percent% building full arm64 KUnit Image ($steps compiler/link steps observed)"
			fi
			;;
		esac
	done
}
make_rc=${PIPESTATUS[0]}
set -e
[ "$make_rc" = 0 ] || die "full Image build failed: $make_rc"
IMAGE="$KUNIT_OUT/arch/arm64/boot/Image"
[ -s "$IMAGE" ] || die 'arm64 Image missing'

progress '88% booting arm64 Image in QEMU and running filtered KUnit suite'
set +e
timeout --signal=TERM "$QEMU_TIMEOUT" qemu-system-aarch64 \
	-machine virt,gic-version=3 -cpu max -smp 2 -m 1024 \
	-nographic -no-reboot -kernel "$IMAGE" \
	-append 'console=ttyAMA0 earlycon=pl011,0x09000000 kunit.enable=1 kunit.autorun=1 kunit.filter_glob=sched_exec_lease_rebuild panic=1' \
	> "$SERIAL_LOG" 2>&1
qemu_rc=$?
set -e

progress '96% validating KTAP, object/config hashes, and non-claims'
grep -Fq '# Subtest: sched_exec_lease_rebuild' "$SERIAL_LOG" || die 'KUnit suite did not start'
grep -Eq '^ok [0-9]+ - sched_exec_lease_rebuild([[:space:]]|$)' "$SERIAL_LOG" || die 'KUnit suite did not pass'
if grep -Eq '(^|[[:space:]])not ok [0-9]+' "$SERIAL_LOG"; then die 'KUnit reported failure'; fi
if grep -Fq '# SKIP' "$SERIAL_LOG"; then die 'KUnit reported skipped required case'; fi
kunit_case_count=$(grep -Ec '^[[:space:]]+ok [0-9]+ - sched_exec_rebuild_.*_test([[:space:]]|$)' "$SERIAL_LOG" || true)
[ "$kunit_case_count" = 12 ] || die "KUnit case count mismatch: $kunit_case_count"
for test_name in $(jq -r '.kunit.test_cases[]' "$CONFIG"); do
	grep -Eq "^[[:space:]]+ok [0-9]+ - $test_name([[:space:]]|$)" "$SERIAL_LOG" || die "KUnit case missing: $test_name"
done

parent_object="$PARENT_OUT/kernel/sched/fair.o"
off_object="$OFF_OUT/kernel/sched/fair.o"
layout_object="$LAYOUT_OUT/kernel/sched/fair.o"
kunit_object="$KUNIT_OUT/kernel/sched/fair.o"
parent_sha=$(sha256sum "$parent_object" | awk '{print $1}')
off_sha=$(sha256sum "$off_object" | awk '{print $1}')
layout_sha=$(sha256sum "$layout_object" | awk '{print $1}')
kunit_sha=$(sha256sum "$kunit_object" | awk '{print $1}')
image_sha=$(sha256sum "$IMAGE" | awk '{print $1}')
serial_sha=$(sha256sum "$SERIAL_LOG" | awk '{print $1}')
parent_size=$(size -A "$parent_object" | awk 'NR > 1 && $1 != "Total" {s += $2} END {print s+0}')
off_size=$(size -A "$off_object" | awk 'NR > 1 && $1 != "Total" {s += $2} END {print s+0}')
layout_size=$(size -A "$layout_object" | awk 'NR > 1 && $1 != "Total" {s += $2} END {print s+0}')
kunit_size=$(size -A "$kunit_object" | awk 'NR > 1 && $1 != "Total" {s += $2} END {print s+0}')

jq -n \
	--arg run_id "$RUN_ID" --arg source_commit "$expected_commit" --arg source_tree "$expected_tree" \
	--arg source_diff_sha256 "$diff_hash" --arg parent_commit "$expected_parent" --arg primary_commit "$expected_primary" \
	--arg parent_fair_sha256 "$parent_sha" --arg off_fair_sha256 "$off_sha" --arg layout_fair_sha256 "$layout_sha" --arg kunit_fair_sha256 "$kunit_sha" \
	--arg image "$IMAGE" --arg image_sha256 "$image_sha" --arg serial_log "$SERIAL_LOG" --arg serial_sha256 "$serial_sha" \
	--argjson parent_fair_size "$parent_size" --argjson off_fair_size "$off_size" --argjson layout_fair_size "$layout_size" --argjson kunit_fair_size "$kunit_size" \
	--argjson qemu_exit_code "$qemu_rc" --argjson kunit_case_count "$kunit_case_count" \
	'{schema_version:1,run_id:$run_id,status:"passed_e3_rebuild_prototype",architecture:"arm64",source_commit:$source_commit,source_tree:$source_tree,source_diff_sha256:$source_diff_sha256,parent_commit:$parent_commit,primary_linux_commit:$primary_commit,patch_queue_tail:"0014-sched-exec_lease-Expand-build-only-layout-probe.patch",changed_files:["init/Kconfig","kernel/sched/fair.c"],strict_checkpatch:{errors:0,warnings:0,checks:0},source_isolation_passed:true,forbidden_locked_operations_absent:true,frozen_e2_fields_and_probe_unchanged:true,build_matrix:{exact_parent_fair:true,e3_lease_off_fair:true,e3_layout_on_test_off_fair:true,e3_kunit_on_fair:true,e3_kunit_on_image:true},disabled_helper_and_suite_symbols_absent:true,enabled_suite_and_case_symbols_present:true,objects:{parent_fair:{size:$parent_fair_size,sha256:$parent_fair_sha256},e3_off_fair:{size:$off_fair_size,sha256:$off_fair_sha256},e3_layout_test_off_fair:{size:$layout_fair_size,sha256:$layout_fair_sha256},e3_kunit_fair:{size:$kunit_fair_size,sha256:$kunit_fair_sha256}},image:{path:$image,sha256:$image_sha256},qemu:{exit_code:$qemu_exit_code,serial_log:$serial_log,serial_sha256:$serial_sha256,suite:"sched_exec_lease_rebuild",suite_passed:true,case_count:$kunit_case_count,failed_cases:0,skipped_required_cases:0},required_case_family_count:14,exhaustive_leaf_limit:6,exhaustive_wrap_base_count:3,e3_source_accepted_for_disposable_correctness_evidence:true,e3_rebuild_correctness_accepted_for_synthetic_fixtures:true,e4_measurement_may_be_planned:true,production_layout_accepted:false,hot_field_approved:false,primary_linux_change_approved:false,patch_queue_change_approved:false,real_picker_fence_approved:false,real_publisher_approved:false,real_fanout_approved:false,incremental_update_closure_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,e4_measurement_passed:false,performance_claim:false,cost_claim:false,deployment_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json"

progress '100% passed; controlled object matrix, arm64 Image, and KUnit KTAP complete'
cat "$OUT_DIR/result.json"
