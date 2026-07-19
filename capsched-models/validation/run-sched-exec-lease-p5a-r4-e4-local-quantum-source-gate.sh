#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export KBUILD_BUILD_TIMESTAMP='1970-01-01 00:00:00 +0000'
export KBUILD_BUILD_USER=capsched
export KBUILD_BUILD_HOST=r4-e4-source-gate
export KBUILD_BUILD_VERSION=1

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
LINUX_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/linux"
PRIMARY_DIR="$WORKSPACE_DIR/linux"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan-v1.json"
PLAN_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan/20260718T-p5a-r4-e4-local-quantum-plan-r3/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate"
OUT_DIR="$OUT_ROOT/$RUN_ID"
BUILD_ROOT="/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/$RUN_ID"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e3-$RUN_ID"
E4_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e4-source-gate-e4-$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-2}

PLAN_SHA=63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
PLAN_RESULT_SHA=8f74506caec82d4984b91fdf066a4fe69253b189c20eecb749aa9b583bdfbe21
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
E3_COMMIT=da9ce9159b3450c28c8faf8dceac671fb7bfeba2
E3_TREE=58c6510c6f517004e37107786d006bb8333b79b8
E4_COMMIT=1dac9953b1b5c326a27285b1f2a6e4fac9960a1d
E4_TREE=7d7f14800c9696b131ef7363cd8fb4cdd33a05b7
E4_DIFF_SHA=f8aa2ea40ef4041d3c1fcf6d9503f814aecf2e16b384688af6d196fc70009393
REQUIRED_E3_CASES=36
REQUIRED_E4_CELLS=682
clock_skew_retries=0

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

cleanup()
{
	local rc=$?
	local path
	local cleanup_failed=0

	trap - EXIT INT TERM
	rm -rf -- "$BUILD_ROOT"
	for path in "$E3_DIR" "$E4_DIR"; do
		if git -C "$LINUX_DIR" worktree list --porcelain 2>/dev/null |
			grep -Fxq "worktree $path"; then
			git -C "$LINUX_DIR" worktree remove --force "$path" \
				>/dev/null 2>&1 || true
		fi
		# Apple Container shared-directory removal can unregister the worktree
		# before returning ENOTEMPTY. Remove only this run-owned path, then
		# prune and verify both the directory and administrative record.
		if [ -e "$path" ] || [ -L "$path" ]; then
			rm -rf -- "$path"
		fi
	done
	git -C "$LINUX_DIR" worktree prune >/dev/null 2>&1 || true
	for path in "$E3_DIR" "$E4_DIR"; do
		if [ -e "$path" ] || [ -L "$path" ] ||
			git -C "$LINUX_DIR" worktree list --porcelain 2>/dev/null |
			grep -Fxq "worktree $path"; then
			printf 'error: could not retire source-gate worktree: %s\n' "$path" >&2
			cleanup_failed=1
		fi
	done
	if [ "$rc" -eq 0 ] && [ "$cleanup_failed" -ne 0 ]; then
		rc=1
	fi
	exit "$rc"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$JOBS" in
	''|*[!0-9]*) die 'JOBS must be a positive integer' ;;
esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be greater than zero'
case "$BUILD_ROOT" in
	/var/tmp/linux-cap-builds/p5a-r4-e4-source-gate/"$RUN_ID") ;;
	*) die "unsafe build root: $BUILD_ROOT" ;;
esac

for command in awk cmp diff find git grep jq make nm readelf sed sha256sum \
	sort stat strings wc x86_64-linux-gnu-gcc; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
for path in "$OUT_DIR" "$BUILD_ROOT" "$E3_DIR" "$E4_DIR"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "output already exists: $path"
	fi
done
mkdir -p "$OUT_ROOT" "$(dirname "$BUILD_ROOT")" "$(dirname "$E3_DIR")"
mkdir "$OUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR"
trap cleanup EXIT INT TERM

progress '3% locking plan, candidate, primary, and patch-queue identities'
[ "$(sha256sum "$PLAN" | awk '{print $1}')" = "$PLAN_SHA" ] || die 'plan hash changed'
[ "$(sha256sum "$PLAN_RESULT" | awk '{print $1}')" = "$PLAN_RESULT_SHA" ] ||
	die 'plan result hash changed'
jq -e '
  .status == "r4_e4_source_free_local_quantum_measurement_pre_source_plan" and
  .source.candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .source.direct_child_required == true and
  .source.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .source.e3_case_families_preserved == 36 and
  .configuration.name == "SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.suite_name == "sched_exec_lease_r4_measure" and
  .common_measurement.minimum_warmup_pairs_per_cell == 256 and
  .common_measurement.measured_pairs_per_cell == 10000 and
  .matrix.total_cells == 682 and
  .diagnostics.e3_six_profile_regression_after_helper_change_required == true and
  .authorization_after_plan_pass.e4_measurement_may_start_before_source_gate == false and
  .safety_flags.datacenter_ready == false
' "$PLAN" >/dev/null
jq -e '
  .status == "passed_r4_e4_plan_only_source_draft_authorized" and
  .candidate_commit == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .matrix.total_cells == 682 and
  .e4_exact_two_file_source_draft_may_be_created == true and
  .e4_measurement_may_start_before_source_gate == false and
  .production_protection == false and
  .datacenter_ready == false
' "$PLAN_RESULT" >/dev/null

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'primary Linux is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'patch queue moved'
[ -z "$(git -C "$PATCH_QUEUE_DIR" status --porcelain)" ] || die 'patch queue is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" hash-object patches/capsched-linux-l0/series)" = \
	"$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch queue series moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$E4_COMMIT^")" = "$E3_COMMIT" ] ||
	die 'E4 is not the exact direct E3 child'
[ "$(git -C "$LINUX_DIR" rev-parse "$E3_COMMIT^{tree}")" = "$E3_TREE" ] ||
	die 'E3 tree moved'
[ "$(git -C "$LINUX_DIR" rev-parse "$E4_COMMIT^{tree}")" = "$E4_TREE" ] ||
	die 'E4 tree moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/heads/codex/p5a-r4-e4-local-quantum-measurement)" = \
	"$E4_COMMIT" ] || die 'local E4 ref moved'
[ "$(git -C "$LINUX_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e4-local-quantum-measurement)" = \
	"$E4_COMMIT" ] || die 'fork E4 ref moved'

git -C "$LINUX_DIR" worktree add --detach "$E3_DIR" "$E3_COMMIT" \
	> "$OUT_DIR/e3-worktree-add.log" 2>&1
git -C "$LINUX_DIR" worktree add --detach "$E4_DIR" "$E4_COMMIT" \
	> "$OUT_DIR/e4-worktree-add.log" 2>&1

progress '10% checking exact two-file source boundary and strict style'
git -C "$E4_DIR" diff --check "$E3_COMMIT..$E4_COMMIT"
git -C "$E4_DIR" diff --name-only "$E3_COMMIT..$E4_COMMIT" | sort \
	> "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" \
	> "$OUT_DIR/changed-files.diff" || die 'source escaped two-file boundary'
[ "$(git -C "$E4_DIR" diff --numstat "$E3_COMMIT..$E4_COMMIT" |
	awk '{a += $1; d += $2} END {print a+0, d+0}')" = '1663 82' ] ||
	die 'source line totals changed'
git -C "$E4_DIR" diff --binary "$E3_COMMIT..$E4_COMMIT" > "$OUT_DIR/e4-source.diff"
[ "$(sha256sum "$OUT_DIR/e4-source.diff" | awk '{print $1}')" = "$E4_DIFF_SHA" ] ||
	die 'E4 diff hash changed'
set +e
"$E4_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types \
	--ignore FILE_PATH_CHANGES,SPDX_LICENSE_TAG --max-line-length=100 \
	< "$OUT_DIR/e4-source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -q '^total: 0 errors, 0 warnings, 0 checks,' "$OUT_DIR/checkpatch.log" ||
	die 'strict checkpatch totals changed'

progress '18% checking default-off configuration and byte-preserved E3 cases'
SOURCE="$E4_DIR/kernel/sched/exec_lease.c"
KCONFIG="$E4_DIR/init/Kconfig"
awk '
  /^config SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST$/ { emit=1 }
  emit && /^config / && $2 != "SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST" { exit }
  emit { print }
' "$KCONFIG" > "$OUT_DIR/e4-kconfig.txt"
grep -qx $'\tdepends on SCHED_EXEC_LEASE_R4_KUNIT_TEST && KUNIT=y' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 dependencies changed'
grep -qx $'\tdefault n' "$OUT_DIR/e4-kconfig.txt" || die 'E4 is not default off'
! grep -Eq 'default y|default KUNIT_ALL_TESTS|select KUNIT|imply KUNIT' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 has an implicit enable path'
sed -n '/^sched_exec_r4_test_bmax_0_1_63_64_and_65_reject(/,/^kunit_test_suites(&sched_exec_r4_test_suite);$/p' \
	"$E3_DIR/kernel/sched/exec_lease.c" > "$OUT_DIR/e3-parent-cases.c"
sed -n '/^sched_exec_r4_test_bmax_0_1_63_64_and_65_reject(/,/^kunit_test_suites(&sched_exec_r4_test_suite);$/p' \
	"$SOURCE" > "$OUT_DIR/e4-e3-cases.c"
cmp -s "$OUT_DIR/e3-parent-cases.c" "$OUT_DIR/e4-e3-cases.c" ||
	die 'E3 cases, oracles, or receipts changed'
[ "$(grep -c 'KUNIT_CASE(' "$OUT_DIR/e4-e3-cases.c")" = "$REQUIRED_E3_CASES" ] ||
	die 'E3 case count changed'
grep -q '^#define SCHED_EXEC_R4_TEST_STRESS_ITERATIONS[[:space:]]*2048$' "$SOURCE" ||
	die 'E3 stress iterations changed'
grep -q '^#define SCHED_EXEC_R4_TEST_TIMEOUT[[:space:]]*(15 \* HZ)$' "$SOURCE" ||
	die 'E3 hard timeout changed'
[ "$(sed -n '/^enum sched_exec_r4_test_fault_site {$/,/^};$/p' "$SOURCE" |
	grep -c 'SCHED_EXEC_R4_TEST_FAULT_' )" = 7 ] || die 'E3 fault manifest changed'

progress '28% checking exact seven-family matrix, gates, controls, and helper reuse'
awk '
  /^kunit_test_suites\(&sched_exec_r4_test_suite\);$/ { after_e3=1 }
  after_e3 && /^#ifdef CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST$/ { emit=1 }
  emit { print }
  emit && /^#endif \/\* CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST \*\/$/ { exit }
' "$SOURCE" > "$OUT_DIR/e4-block.c"
sed -n '/^static struct kunit_case sched_exec_r4_measure_test_cases\[\]/,/^};/p' \
	"$SOURCE" > "$OUT_DIR/e4-cases.c"
printf '%s\n' \
	sched_exec_r4_measure_publication_case \
	sched_exec_r4_measure_picker_case \
	sched_exec_r4_measure_irq_case \
	sched_exec_r4_measure_recovery_case \
	sched_exec_r4_measure_notifier_case \
	sched_exec_r4_measure_current_case \
	sched_exec_r4_measure_offline_case > "$OUT_DIR/expected-e4-cases.txt"
sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' "$OUT_DIR/e4-cases.c" \
	> "$OUT_DIR/actual-e4-cases.txt"
diff -u "$OUT_DIR/expected-e4-cases.txt" "$OUT_DIR/actual-e4-cases.txt" \
	> "$OUT_DIR/e4-cases.diff" || die 'E4 case manifest changed'
grep -q $'^\t.name = "sched_exec_lease_r4_measure",$' "$SOURCE" || die 'suite name changed'
grep -q '^#define SCHED_EXEC_R4_MEASURE_WARMUP_PAIRS[[:space:]]*256$' "$SOURCE" ||
	die 'warmup count changed'
grep -q '^#define SCHED_EXEC_R4_MEASURE_PAIRS[[:space:]]*10000$' "$SOURCE" ||
	die 'pair count changed'
grep -q '^#define SCHED_EXEC_R4_MEASURE_BASE_SLICE_NS[[:space:]]*700000ULL$' "$SOURCE" ||
	die 'base-slice marker changed'
grep -q '^#define SCHED_EXEC_R4_MEASURE_ASYNC_P99_NS[[:space:]]*10000000ULL$' "$SOURCE" ||
	die 'async p99 changed'
grep -q '^#define SCHED_EXEC_R4_MEASURE_ASYNC_MAX_NS[[:space:]]*100000000ULL$' "$SOURCE" ||
	die 'async max changed'
for row in 288 144 9 48 24 25; do
	grep -q "KUNIT_EXPECT_EQ(test, rows, ${row}U);" "$SOURCE" ||
		die "missing exact row assertion: $row"
done
[ "$(grep -c 'KUNIT_EXPECT_EQ(test, rows, 144U);' "$SOURCE")" = 2 ] ||
	die 'the two 144-cell matrices are not both exact'
[ "$REQUIRED_E4_CELLS" = 682 ] || die 'internal E4 cell total changed'
[ "$(grep -c 'SCHED_EXEC_R4_MEASURE_PAIRS' "$OUT_DIR/e4-block.c")" -ge 8 ] ||
	die 'pair-count binding is incomplete'
grep -q 'arrays->treatment\[i\] > arrays->control\[i\]' "$SOURCE" ||
	die 'saturating paired subtraction changed'
grep -q 'index & 1' "$SOURCE" || die 'alternating pair order missing'
grep -q 'additional->p99 > p99_limit' "$SOURCE" || die 'local p99 gate missing'
grep -q 'additional->p999 > p999_limit' "$SOURCE" || die 'local p999 gate missing'
grep -q 'additional->maximum > 50000' "$SOURCE" || die 'local max gate missing'
grep -q 'additional->maximum >= SCHED_EXEC_R4_MEASURE_BASE_SLICE_NS' "$SOURCE" ||
	die 'base-slice rejection missing'
grep -q 'asynchronous->p99 > SCHED_EXEC_R4_MEASURE_ASYNC_P99_NS' "$SOURCE" ||
	die 'async p99 gate missing'
for helper in publish_locked recover_one_locked notifier_quantum \
	rq_offline_locked request_current_locked dispatch_one; do
	[ "$(grep -c "sched_exec_r4_test_${helper}(" "$SOURCE")" -ge 2 ] ||
		die "measurement does not reuse E3 helper: $helper"
done
! grep -Eq 'for_each_(online|possible|present)_cpu|cpu_online_mask|cpuhp_setup|task_group|cgroup_attach|EXPORT_SYMBOL|syscall|proc_create|debugfs_create' \
	"$OUT_DIR/e4-block.c" || die 'E4 escaped synthetic non-attachment boundary'

if [ "${SOURCE_ONLY:-0}" = 1 ]; then
	progress '100% source-only gate passed; fresh dual-architecture objects not built'
	exit 0
fi

has_compiler_diagnostic()
{
	grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$1"
}

has_clock_skew()
{
	grep -Eiq 'Clock skew detected|modification time .* in the future' "$1"
}

run_make()
{
	local label=$1 log=$2 verify_log=$3
	shift 3

	"$@" > "$log" 2>&1
	! has_compiler_diagnostic "$log" || die "$label compiler diagnostic"
	: > "$verify_log"
	if has_clock_skew "$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		"$@" > "$verify_log" 2>&1
		! has_compiler_diagnostic "$verify_log" || die "$label verification diagnostic"
		! has_clock_skew "$verify_log" || die "$label persistent clock skew"
	fi
}

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6

	mkdir "$out"
	run_make "$label defconfig" "$OUT_DIR/$label-defconfig.log" \
		"$OUT_DIR/$label-defconfig-verify.log" \
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig
	"$source/scripts/config" --file "$out/.config" \
		-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED \
		-e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE \
		-e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS \
		-e SCHED_EXEC_LEASE_R4_KUNIT_TEST -e DEBUG_INFO_NONE
	case "$mode" in
		e3-parent) ;;
		e4-off) "$source/scripts/config" --file "$out/.config" \
			-d SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST ;;
		e4-on) "$source/scripts/config" --file "$out/.config" \
			-e SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST ;;
		*) die "unknown mode: $mode" ;;
	esac
	run_make "$label olddefconfig" "$OUT_DIR/$label-olddefconfig.log" \
		"$OUT_DIR/$label-olddefconfig-verify.log" \
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig
	grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y' "$out/.config" ||
		die "$label did not enable E3"
	case "$mode" in
		e4-off) grep -Fxq '# CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST is not set' \
			"$out/.config" || die "$label unexpectedly enabled E4" ;;
		e4-on) grep -Fxq 'CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y' \
			"$out/.config" || die "$label did not enable E4" ;;
	esac
}

build_mode()
{
	local source=$1 arch=$2 cross=$3 mode=$4 label=$5
	local out="$BUILD_ROOT/$label"
	local object

	prepare_config "$source" "$arch" "$cross" "$mode" "$out" "$label"
	run_make "$label object" "$OUT_DIR/$label-build.log" \
		"$OUT_DIR/$label-build-verify.log" \
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		W=1 -j"$JOBS" kernel/sched/exec_lease.o
	object="$out/kernel/sched/exec_lease.o"
	[ -s "$object" ] || die "$label object missing"
	sha256sum "$object" > "$OUT_DIR/$label-object.sha256"
	nm -a "$object" > "$OUT_DIR/$label-nm.txt"
	readelf -rW "$object" > "$OUT_DIR/$label-relocations.txt"
	strings -a "$object" > "$OUT_DIR/$label-strings.txt"
	case "$mode" in
		e3-parent|e4-off)
			! grep -Eq 'sched_exec_r4_measure|sched_exec_lease_r4_measure|R4_E4_(RESULT|SUMMARY)' \
				"$OUT_DIR/$label-nm.txt" "$OUT_DIR/$label-strings.txt" \
				"$OUT_DIR/$label-relocations.txt" || die "$label contains disabled E4 artifact"
			;;
		e4-on)
			grep -q 'sched_exec_lease_r4_measure' "$OUT_DIR/$label-strings.txt" ||
				die "$label suite string missing"
			grep -q 'R4_E4_RESULT' "$OUT_DIR/$label-strings.txt" ||
				die "$label result rows missing"
			;;
	esac
}

progress '40% building fresh arm64 E3-parent, E4-off, and E4-on objects'
build_mode "$E3_DIR" arm64 '' e3-parent arm64-e3-parent
progress '50% arm64 E3 parent passed; building E4 disabled'
build_mode "$E4_DIR" arm64 '' e4-off arm64-e4-off
progress '60% arm64 E4 disabled passed; building E4 enabled'
build_mode "$E4_DIR" arm64 '' e4-on arm64-e4-on

progress '70% building fresh x86_64 E3-parent, E4-off, and E4-on objects'
build_mode "$E3_DIR" x86_64 x86_64-linux-gnu- e3-parent x86_64-e3-parent
progress '80% x86_64 E3 parent passed; building E4 disabled'
build_mode "$E4_DIR" x86_64 x86_64-linux-gnu- e4-off x86_64-e4-off
progress '90% x86_64 E4 disabled passed; building E4 enabled'
build_mode "$E4_DIR" x86_64 x86_64-linux-gnu- e4-on x86_64-e4-on

find "$OUT_DIR" -type f ! -name artifact-manifest.sha256 \
	! -name result.json ! -name result.sha256 -print0 |
	sort -z | xargs -0 sha256sum > "$OUT_DIR/artifact-manifest.sha256"
artifact_count=$(wc -l < "$OUT_DIR/artifact-manifest.sha256" | tr -d ' ')
jq -n \
	--arg run_id "$RUN_ID" --arg candidate "$E4_COMMIT" --arg parent "$E3_COMMIT" \
	--arg tree "$E4_TREE" --arg diff_sha "$E4_DIFF_SHA" \
	--arg primary "$PRIMARY_COMMIT" --arg patch_queue "$PATCH_QUEUE_COMMIT" \
	--arg plan_sha "$PLAN_SHA" --arg plan_result_sha "$PLAN_RESULT_SHA" \
	--argjson artifacts "$artifact_count" --argjson retries "$clock_skew_retries" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e4-local-quantum-source-gate-result-v1",run_id:$run_id,status:"passed_source_and_object_gate_awaiting_six_profile_e3_regression",candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,primary_commit:$primary,patch_queue_commit:$patch_queue,plan_sha256:$plan_sha,plan_result_sha256:$plan_result_sha,allowed_files:["init/Kconfig","kernel/sched/exec_lease.c"],strict_checkpatch:{errors:0,warnings:0,checks:0},architectures:["arm64","x86_64"],fresh_modes_per_architecture:["exact_e3_parent","e4_measure_off","e4_measure_on"],fresh_objects:6,w1_compiler_diagnostics:0,clock_skew_retries:$retries,final_clock_skew_warnings:0,disabled_e4_artifacts:0,e3_cases_byte_preserved:36,e4_measurement_cells:682,artifact_count:$artifacts,six_profile_e3_regression_required:true,timing_measurement_may_start:false,r4_e4_source_accepted:false,real_scheduler_attachment:false,runtime_behavior_approved:false,production_protection:false,deployment_ready:false,multi_cluster_ready:false,datacenter_ready:false}' \
	> "$OUT_DIR/result.json.pending"
jq -e '.status == "passed_source_and_object_gate_awaiting_six_profile_e3_regression" and .fresh_objects == 6 and .w1_compiler_diagnostics == 0 and .disabled_e4_artifacts == 0 and .e3_cases_byte_preserved == 36 and .e4_measurement_cells == 682 and .six_profile_e3_regression_required == true and .timing_measurement_may_start == false and .production_protection == false and .datacenter_ready == false' \
	"$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% source/object gate passed; six-profile E3 regression remains required'
printf 'result=%s\n' "$OUT_DIR/result.json"
