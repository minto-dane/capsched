#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e3-bucket-concurrency-prototype"
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e4-bucket-measurement"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-e4-bucket-measurement-plan-v1.json"
PLAN_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement-plan/20260716T-p5a-r3-e4-bucket-measurement-plan/result.json"
E3_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-diagnostic-matrix/20260716T-p5a-r3-e3-diagnostic-matrix-r2/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e4-bucket-measurement-source-gate/$RUN_ID"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r3-e4-source-gate/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}

E3_COMMIT=be9339363a99fb31a5b7d03f3d70430d64a45593
E4_COMMIT=f20c62a2ad5aec4347dc7c8c4d81e3f7fa1f3da1
E4_TREE=61541cb0c8aedef941e534c73effdea1f6b3d938
E4_DIFF_SHA=ec369f6b40b427f1297b9ef5061d91bebb2e26c25d9f145a54b995b4b4a73205
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PLAN_PATCH_QUEUE_COMMIT=2a022dce54679ce5ecb86581bf55199dc28c868b
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
PLAN_RESULT_SHA=107cf025ccb3030cafe6a142a994fdf5d5e7a6d4cf8b8fc07f5b49bb8e878cab
E3_RESULT_SHA=3ec1cd9b54b326d889c5ef3d6398e70530f3f50e5fd7cd89e3f3aa0c2f45c756

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

progress()
{
	printf '[progress] %s\n' "$*"
	if [ -n "$PROGRESS_FILE" ]; then
		printf '%s\n' "$*" > "$PROGRESS_FILE"
	fi
}

for command in awk diff git grep jq make nm readelf sed sha256sum sort strings wc; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
command -v x86_64-linux-gnu-gcc >/dev/null 2>&1 \
	|| die 'missing x86_64 cross compiler'

rm -rf "$OUT_DIR" "$BUILD_ROOT"
mkdir -p "$OUT_DIR" "$BUILD_ROOT"

progress '3% locking plan, predecessor, candidate, primary, and patch-queue identities'
[ "$(sha256sum "$PLAN_RESULT" | awk '{print $1}')" = "$PLAN_RESULT_SHA" ] \
	|| die 'E4 plan result hash changed'
[ "$(sha256sum "$E3_RESULT" | awk '{print $1}')" = "$E3_RESULT_SHA" ] \
	|| die 'E3 diagnostic result hash changed'
jq -e '
  .status == "r3_e4_bucket_measurement_pre_source_plan" and
  .source.e3_candidate_commit == "be9339363a99fb31a5b7d03f3d70430d64a45593" and
  .source.direct_child_required == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .configuration.name == "SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_bucket_measure" and
  .matrix.total_cell_count == 42 and
  .matrix.result_row_per_cell_required == true and
  .classification.e5_source_authorized == false
' "$PLAN" >/dev/null
jq -e '
  .status == "passed_r3_e4_plan_only" and
  .e3_candidate_commit == "be9339363a99fb31a5b7d03f3d70430d64a45593" and
  .allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .matrix.total_cells == 42 and
  .e4_source_draft_may_be_created == true and
  .e4_measurement_may_start_before_source_gate == false
' "$PLAN_RESULT" >/dev/null
jq -e '
  .status == "passed_four_boot_diagnostic_matrix" and
  .candidate_commit == "be9339363a99fb31a5b7d03f3d70430d64a45593" and
  .architectures == ["arm64","x86_64"] and
  .required_cases == 20 and .passed_cases_per_boot == 20 and
  .failed_cases == 0 and .skipped_cases == 0 and
  .timeouts == 0 and .warning_reports == 0
' "$E3_RESULT" >/dev/null

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] \
	|| die 'primary Linux moved'
git -C "$PRIMARY_DIR" diff --quiet HEAD -- init/Kconfig kernel/sched/exec_lease.c \
	include/linux/sched.h include/linux/sched_exec_lease.h kernel/sched/Makefile \
	kernel/sched/sched.h kernel/sched/fair.c kernel/sched/core.c \
	|| die 'primary source boundary is dirty'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] || die 'E3 moved'
git -C "$E3_DIR" diff --quiet HEAD -- init/Kconfig kernel/sched/exec_lease.c \
	include/linux/sched.h include/linux/sched_exec_lease.h kernel/sched/Makefile \
	kernel/sched/sched.h kernel/sched/fair.c kernel/sched/core.c \
	|| die 'E3 source boundary is dirty'
[ "$(git -C "$E4_DIR" rev-parse HEAD)" = "$E4_COMMIT" ] || die 'E4 moved'
[ "$(git -C "$E4_DIR" rev-parse HEAD^)" = "$E3_COMMIT" ] \
	|| die 'E4 is not a direct E3 child'
[ "$(git -C "$E4_DIR" rev-parse 'HEAD^{tree}')" = "$E4_TREE" ] \
	|| die 'E4 tree moved'
git -C "$E4_DIR" diff --quiet HEAD -- init/Kconfig kernel/sched/exec_lease.c \
	include/linux/sched.h include/linux/sched_exec_lease.h kernel/sched/Makefile \
	kernel/sched/sched.h kernel/sched/fair.c kernel/sched/core.c \
	|| die 'E4 source boundary is dirty'
patch_queue_commit=$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)
git -C "$PATCH_QUEUE_DIR" merge-base --is-ancestor \
	"$PLAN_PATCH_QUEUE_COMMIT" "$patch_queue_commit" \
	|| die 'patch queue no longer descends from planned commit'
[ "$(git -C "$PATCH_QUEUE_DIR" hash-object patches/capsched-linux-l0/series)" = \
	"$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch queue series moved'

progress '8% checking exact direct-child two-file source boundary and strict style'
git -C "$E4_DIR" diff --check "$E3_COMMIT..$E4_COMMIT"
git -C "$E4_DIR" diff --name-only "$E3_COMMIT..$E4_COMMIT" | sort \
	> "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" \
	> "$OUT_DIR/changed-files.diff" || die 'source escaped two-file boundary'
[ "$(git -C "$E4_DIR" diff --numstat "$E3_COMMIT..$E4_COMMIT" |
	awk '{a += $1; d += $2} END {print a+0, d+0}')" = '1006 10' ] \
	|| die 'unexpected source line totals'
git -C "$E4_DIR" diff --binary "$E3_COMMIT..$E4_COMMIT" \
	> "$OUT_DIR/e4-source.diff"
[ "$(sha256sum "$OUT_DIR/e4-source.diff" | awk '{print $1}')" = "$E4_DIFF_SHA" ] \
	|| die 'E4 diff hash changed'
set +e
"$E4_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types \
	"$OUT_DIR/e4-source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -q '^total: 0 errors, 0 warnings, 0 checks,' "$OUT_DIR/checkpatch.log" \
	|| die 'strict checkpatch totals changed'

progress '14% checking default-off same-TU configuration and frozen E3 case manifest'
SOURCE="$E4_DIR/kernel/sched/exec_lease.c"
KCONFIG="$E4_DIR/init/Kconfig"
[ "$(grep -c '^config SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST$' "$KCONFIG")" = 1 ] \
	|| die 'E4 Kconfig count mismatch'
sed -n '/^config SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST$/,/^config /p' \
	"$KCONFIG" > "$OUT_DIR/e4-kconfig.txt"
grep -qx $'\tbool "KUnit measurement of scheduler execution bucket bounds"' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 bool declaration changed'
grep -qx $'\tdepends on SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST && KUNIT=y' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 dependencies changed'
grep -qx $'\tdefault n' "$OUT_DIR/e4-kconfig.txt" || die 'E4 is not default off'
! grep -Eq 'default y|default KUNIT_ALL_TESTS|select KUNIT|imply KUNIT' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 has an implicit enable path'
sed -n '/^static struct kunit_case sched_exec_bucket_test_cases\[\]/,/^};/p' \
	"$E3_DIR/kernel/sched/exec_lease.c" > "$OUT_DIR/e3-parent-cases.c"
sed -n '/^static struct kunit_case sched_exec_bucket_test_cases\[\]/,/^};/p' \
	"$SOURCE" > "$OUT_DIR/e4-e3-cases.c"
diff -u "$OUT_DIR/e3-parent-cases.c" "$OUT_DIR/e4-e3-cases.c" \
	> "$OUT_DIR/e3-cases.diff" || die 'E3 case manifest changed'
[ "$(grep -c 'KUNIT_CASE(' "$OUT_DIR/e4-e3-cases.c")" = 20 ] \
	|| die 'E3 case count changed'

progress '20% checking measurement matrices, intervals, helper reuse, and non-attachment'
grep -q '^#ifdef CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST$' "$SOURCE" \
	|| die 'E4 source guard missing'
grep -q '^#define SCHED_EXEC_BUCKET_MEASURE_WARMUP_PAIRS[[:space:]]*256$' "$SOURCE" \
	|| die 'warmup count changed'
grep -q '^#define SCHED_EXEC_BUCKET_MEASURE_PAIRS[[:space:]]*10000$' "$SOURCE" \
	|| die 'sample count changed'
grep -q '^#define SCHED_EXEC_BUCKET_MEASURE_MAX[[:space:]]*SCHED_EXEC_BUCKET_B_MAX$' "$SOURCE" \
	|| die 'B_max binding changed'
grep -q '^#define SCHED_EXEC_BUCKET_MEASURE_BASE_SLICE_NS[[:space:]]*700000ULL$' "$SOURCE" \
	|| die 'base-slice threshold changed'
grep -Fq 'static const unsigned int occupancies[] = { 1, 8, 32, 64 };' "$SOURCE" \
	|| die 'one-projection occupancy matrix changed'
grep -Fq 'static const unsigned int inner_counts[] = { 0, 1, 64, 4096 };' "$SOURCE" \
	|| die 'inner-runnable matrix changed'
[ "$(grep -Fc 'static const unsigned int occupancies[] = { 0, 1, 8, 32, 64 };' "$SOURCE")" = 1 ] \
	|| die 'hotplug matrix changed'
grep -Fq 'static const unsigned int active_rqs[] = { 1, 2, 8, 32, 64 };' "$SOURCE" \
	|| die 'fanout matrix changed'
sed -n '/^static struct kunit_case sched_exec_bucket_measure_test_cases\[\]/,/^};/p' \
	"$SOURCE" > "$OUT_DIR/e4-cases.c"
printf '%s\n' \
	sched_exec_bucket_measure_projection_case \
	sched_exec_bucket_measure_hotplug_case \
	sched_exec_bucket_measure_fanout_case > "$OUT_DIR/expected-e4-cases.txt"
sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' "$OUT_DIR/e4-cases.c" \
	> "$OUT_DIR/actual-e4-cases.txt"
diff -u "$OUT_DIR/expected-e4-cases.txt" "$OUT_DIR/actual-e4-cases.txt" \
	> "$OUT_DIR/e4-cases.diff" || die 'E4 case manifest changed'
grep -q $'^\t.name = "sched_exec_lease_bucket_measure",$' "$SOURCE" \
	|| die 'E4 suite name changed'
grep -q '^kunit_test_suites(&sched_exec_bucket_measure_test_suite);$' "$SOURCE" \
	|| die 'E4 same-TU suite registration missing'
[ "$(grep -c 'sched_exec_bucket_test_update_one_locked(' "$SOURCE")" -ge 3 ] \
	|| die 'E3 worker and E4 paths do not share one-projection helper'
[ "$(grep -c 'sched_exec_bucket_test_settle_one_locked(' "$SOURCE")" -ge 3 ] \
	|| die 'E3 and E4 hotplug paths do not share settle helper'

awk '
  /^#ifdef CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST$/ { section++ }
  section == 2 { print }
  section == 2 && /^#endif \/\* CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST \*\// { exit }
' "$SOURCE" > "$OUT_DIR/e4-block.c"
for function in projection_sample hotplug_sample fanout_sample; do
	sed -n "/^sched_exec_bucket_measure_${function}(/,/^}/p" "$SOURCE" \
		> "$OUT_DIR/$function.c"
	[ -s "$OUT_DIR/$function.c" ] || die "missing sample function: $function"
	! grep -Eq 'kunit_|printk|pr_|kmalloc|kzalloc|kcalloc|kvmalloc|kvfree|sort\(|cond_resched|schedule\(' \
		"$OUT_DIR/$function.c" || die "$function has forbidden timed work"
done
grep -q 'local_irq_save(flags);' "$OUT_DIR/projection_sample.c" \
	|| die 'projection irq boundary missing'
grep -q 'raw_spin_rq_lock(fixture->real_rq);' "$OUT_DIR/projection_sample.c" \
	|| die 'projection rq lock missing'
grep -q 'sched_exec_bucket_test_update_one_locked' "$OUT_DIR/projection_sample.c" \
	|| die 'projection exact operation missing'
grep -q 'sched_exec_bucket_test_settle_one_locked' "$OUT_DIR/hotplug_sample.c" \
	|| die 'hotplug bounded settle missing'
grep -q 'cpumask_copy(&snapshot, fixture->bucket.layout.active_rqs);' \
	"$OUT_DIR/fanout_sample.c" || die 'fanout active-rq snapshot missing'
grep -q 'queue_work(fixture->workqueue' "$OUT_DIR/fanout_sample.c" \
	|| die 'fanout queue missing'
! grep -Eq 'for_each_(online|possible|present)_cpu|cpu_online_mask|sched_exec_bl_|attach|task_group|cgroup' \
	"$OUT_DIR/e4-block.c" || die 'E4 block escaped synthetic non-attachment boundary'

if [ "${SOURCE_ONLY:-0}" = 1 ]; then
	progress '100% source-only smoke passed; fresh dual-architecture builds not run'
	exit 0
fi

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6
	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig \
		> "$OUT_DIR/$label-defconfig.log" 2>&1
	"$source/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS \
		-e SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST -e DEBUG_INFO_NONE
	case "$mode" in
		e3-parent) ;;
		e4-off)
			"$source/scripts/config" --file "$out/.config" \
				-d SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST
			;;
		e4-on)
			"$source/scripts/config" --file "$out/.config" \
				-e SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST
			;;
		*) die "unknown build mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig \
		> "$OUT_DIR/$label-olddefconfig.log" 2>&1
	grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y' "$out/.config" \
		|| die "$label did not enable E3"
	grep -Fxq '# CONFIG_KUNIT_ALL_TESTS is not set' "$out/.config" \
		|| die "$label enabled KUNIT_ALL_TESTS"
	case "$mode" in
		e4-off)
			grep -Fxq '# CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST is not set' \
				"$out/.config" || die "$label unexpectedly enabled E4"
			;;
		e4-on)
			grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_BUCKET_MEASURE_KUNIT_TEST=y' \
				"$out/.config" || die "$label did not enable E4"
			;;
	esac
}

build_and_check_arch()
{
	local arch=$1 cross=$2 nm_command=$3 readelf_command=$4 label=$5
	local root="$BUILD_ROOT/$label"
	local parent="$root/e3-parent" off="$root/e4-off" on="$root/e4-on"
	local entry source out mode object

	prepare_config "$E3_DIR" "$arch" "$cross" e3-parent "$parent" "$label-e3-parent"
	prepare_config "$E4_DIR" "$arch" "$cross" e4-off "$off" "$label-e4-off"
	prepare_config "$E4_DIR" "$arch" "$cross" e4-on "$on" "$label-e4-on"
	for entry in "$E3_DIR:$parent:e3-parent" "$E4_DIR:$off:e4-off" "$E4_DIR:$on:e4-on"; do
		source=${entry%%:*}
		out=${entry#*:}
		mode=${out##*:}
		out=${out%%:*}
		case "$label:$mode" in
			arm64:e3-parent) progress '33% building fresh arm64 exact E3 parent object' ;;
			arm64:e4-off) progress '41% building fresh arm64 E4-disabled object' ;;
			arm64:e4-on) progress '49% building fresh arm64 E4-enabled object' ;;
			x86_64:e3-parent) progress '63% building fresh x86_64 exact E3 parent object' ;;
			x86_64:e4-off) progress '71% building fresh x86_64 E4-disabled object' ;;
			x86_64:e4-on) progress '79% building fresh x86_64 E4-enabled object' ;;
		esac
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
			W=1 -j"$(nproc)" kernel/sched/exec_lease.o \
			> "$OUT_DIR/$label-$mode-build.log" 2>&1
		test -s "$out/kernel/sched/exec_lease.o" \
			|| die "$label $mode object missing"
		! grep -Eq '(^|[[:space:]])warning:' "$OUT_DIR/$label-$mode-build.log" \
			|| die "$label $mode compiler warning"
	done

	for mode in e3-parent e4-off e4-on; do
		case "$mode" in
			e3-parent) object="$parent/kernel/sched/exec_lease.o" ;;
			e4-off) object="$off/kernel/sched/exec_lease.o" ;;
			e4-on) object="$on/kernel/sched/exec_lease.o" ;;
		esac
		"$nm_command" -S "$object" |
			awk '$4 ~ /^sched_exec_bl_/ {print $4 "\t" $2}' | sort \
			> "$OUT_DIR/$label-$mode-private.tsv"
		[ "$(wc -l < "$OUT_DIR/$label-$mode-private.tsv" | tr -d ' ')" = 43 ] \
			|| die "$label $mode private probe count changed"
	done
	diff -u "$OUT_DIR/$label-e3-parent-private.tsv" \
		"$OUT_DIR/$label-e4-off-private.tsv" \
		> "$OUT_DIR/$label-parent-off-private.diff" \
		|| die "$label E4-off changed E2 private values"
	diff -u "$OUT_DIR/$label-e3-parent-private.tsv" \
		"$OUT_DIR/$label-e4-on-private.tsv" \
		> "$OUT_DIR/$label-parent-on-private.diff" \
		|| die "$label E4-on changed E2 private values"

	"$nm_command" -a "$off/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-e4-off-nm.txt"
	"$readelf_command" -rW "$off/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-e4-off-relocations.txt"
	strings -a "$off/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-e4-off-strings.txt"
	! grep -Eq 'sched_exec_bucket_measure_|sched_exec_lease_bucket_measure' \
		"$OUT_DIR/$label-e4-off-nm.txt" \
		"$OUT_DIR/$label-e4-off-relocations.txt" \
		"$OUT_DIR/$label-e4-off-strings.txt" \
		|| die "$label E4-off artifact contains E4 material"
	"$nm_command" -a "$on/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-e4-on-nm.txt"
	strings -a "$on/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-e4-on-strings.txt"
	grep -q 'sched_exec_bucket_measure_test_suite' "$OUT_DIR/$label-e4-on-nm.txt" \
		|| die "$label E4 suite symbol missing"
	grep -qx 'sched_exec_lease_bucket_measure' "$OUT_DIR/$label-e4-on-strings.txt" \
		|| die "$label E4 suite string missing"
	sha256sum "$parent/.config" "$parent/kernel/sched/exec_lease.o" \
		"$off/.config" "$off/kernel/sched/exec_lease.o" \
		"$on/.config" "$on/kernel/sched/exec_lease.o" \
		> "$OUT_DIR/$label-artifact-sha256.txt"
	case "$label" in
		arm64) progress '55% arm64 three-mode build and artifact isolation passed' ;;
		x86_64) progress '88% x86_64 three-mode build and artifact isolation passed' ;;
	esac
}

progress '30% building fresh arm64 E3-parent, E4-off, and E4-on objects'
build_and_check_arch arm64 '' nm readelf arm64
progress '60% building fresh x86_64 E3-parent, E4-off, and E4-on objects'
build_and_check_arch x86_64 x86_64-linux-gnu- \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf x86_64

progress '92% writing machine-readable static source-gate result'
jq -n \
	--arg run_id "$RUN_ID" --arg candidate "$E4_COMMIT" \
	--arg parent "$E3_COMMIT" --arg tree "$E4_TREE" \
	--arg diff_sha256 "$E4_DIFF_SHA" --arg primary "$PRIMARY_COMMIT" \
	--arg plan_result_sha256 "$PLAN_RESULT_SHA" \
	--arg e3_result_sha256 "$E3_RESULT_SHA" \
	--arg plan_patch_queue_commit "$PLAN_PATCH_QUEUE_COMMIT" \
	--arg observed_patch_queue_commit "$patch_queue_commit" \
'
{
  schema_version: 1,
  id: "sched-exec-lease-p5a-r3-e4-bucket-measurement-source-gate-result-v1",
  run_id: $run_id,
  status: "passed_static_source_gate_awaiting_e3_regression_diagnostic",
  candidate_commit: $candidate,
  candidate_parent: $parent,
  candidate_tree: $tree,
  candidate_diff_sha256: $diff_sha256,
  primary_commit: $primary,
  plan_result_sha256: $plan_result_sha256,
  e3_diagnostic_result_sha256: $e3_result_sha256,
  plan_patch_queue_commit: $plan_patch_queue_commit,
  observed_patch_queue_commit: $observed_patch_queue_commit,
  patch_queue_series_unchanged: true,
  exact_direct_e3_child: true,
  exact_two_file_boundary: true,
  insertions: 1006,
  deletions: 10,
  config_default_off: true,
  selected_by_kunit_all_tests: false,
  same_translation_unit: true,
  e3_case_manifest_preserved: true,
  e3_case_count: 20,
  e4_suite: "sched_exec_lease_bucket_measure",
  e4_case_count: 3,
  matrix: {one_projection_cells:32,hotplug_cells:5,fanout_cells:5,total_cells:42,warmup_pairs_per_cell:256,measured_pairs_per_cell:10000},
  strict_checkpatch: {errors:0,warnings:0,checks:0},
  architectures: ["arm64","x86_64"],
  fresh_modes_per_architecture: ["exact_e3_parent","e4_disabled","e4_enabled"],
  w1_compiler_warnings: 0,
  e2_private_probe_count: 43,
  e2_private_probe_values_changed: 0,
  disabled_e4_symbols_relocations_strings: 0,
  synthetic_non_attachment_boundary: true,
  e3_regression_diagnostic_may_start: true,
  e3_regression_diagnostic_passed: false,
  e4_measurement_may_start: false,
  e4_measurement_accepted: false,
  e5_plan_may_start: false,
  e5_source_may_start: false,
  real_scheduler_attachment: false,
  runtime_behavior_approved: false,
  production_protection: false,
  bare_metal_latency_claim: false,
  performance_claim: false,
  cost_claim: false,
  deployment_ready: false,
  datacenter_ready: false
}
' > "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% static source gate passed; E3 regression diagnostic is required before measurement'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
