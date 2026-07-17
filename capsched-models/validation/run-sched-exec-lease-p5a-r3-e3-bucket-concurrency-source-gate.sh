#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E2_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e2-layout"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r3-e3-bucket-concurrency-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan-v1.json"
PLAN_RESULT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-evidence-plan/20260715T-p5a-r3-e3-plan/result.json"
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r3-e3-bucket-concurrency-source-gate/$RUN_ID"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r3-e3-source-gate/$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}

E2_COMMIT=63313b329e1d44901acfce30698613c38615c8d5
E3_COMMIT=be9339363a99fb31a5b7d03f3d70430d64a45593
E3_TREE=a92d096ef4779f20c5e652de3c21b8f85b2476c7
E3_DIFF_SHA=c6ce0d8f4e1bac985ad2141d60d0928b501d38d3610a13e4f7a5e63f343f1d25
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PRIMARY_TREE=54f685aad94f28f0027cbba18cf5e29aadce234a
PATCH_QUEUE_COMMIT=2a022dce54679ce5ecb86581bf55199dc28c868b
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818

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
command -v x86_64-linux-gnu-gcc >/dev/null 2>&1 || die 'missing x86_64 cross compiler'
rm -rf "$BUILD_ROOT"
mkdir -p "$OUT_DIR" "$BUILD_ROOT"

progress '3% locking source, plan, primary, and patch-queue identities'
jq -e '
  .status == "r3_e3_bucket_concurrency_pre_source_plan" and
  .source_boundary.future_parent == "63313b329e1d44901acfce30698613c38615c8d5" and
  .source_boundary.allowed_files == ["init/Kconfig", "kernel/sched/exec_lease.c"] and
  .configuration.default_enabled == false and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_bucket" and
  (.required_case_families | length) == 20 and
  (.capacity_and_allocation.allocation_fault_sites | length) == 6 and
  .race_control.hard_timeout_seconds == 5 and
  .race_control.stress_iterations_per_diagnostic_boot == 1024
' "$PLAN" >/dev/null
[ "$(sha256sum "$PLAN_RESULT" | awk '{print $1}')" = 438496a960e566a3cfc2972c226072099b501de0b000378eef130aaca73aa24d ] || die 'E3 plan result hash changed'
jq -e '.status == "passed_r3_e3_plan_only" and .r3_e3_disposable_worktree_may_be_created == true and .r3_e3_exact_two_file_source_draft_may_be_created == true and .r3_e3_source_accepted == false' "$PLAN_RESULT" >/dev/null

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary commit moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')" = "$PRIMARY_TREE" ] || die 'primary tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary working tree is dirty'
[ "$(git -C "$E2_DIR" rev-parse HEAD)" = "$E2_COMMIT" ] || die 'E2 commit moved'
[ -z "$(git -C "$E2_DIR" status --porcelain --untracked-files=no)" ] || die 'E2 working tree is dirty'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] || die 'E3 commit moved'
[ "$(git -C "$E3_DIR" rev-parse HEAD^)" = "$E2_COMMIT" ] || die 'E3 is not a direct E2 child'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] || die 'E3 tree moved'
[ -z "$(git -C "$E3_DIR" status --porcelain --untracked-files=no)" ] || die 'E3 working tree is dirty'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue commit moved'
[ "$(git -C "$PATCH_QUEUE_DIR" hash-object patches/capsched-linux-l0/series)" = "$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch queue series moved'

progress '8% checking exact two-file, additive, direct-child source boundary'
git -C "$E3_DIR" diff --check "$E2_COMMIT..$E3_COMMIT"
git -C "$E3_DIR" diff --name-only "$E2_COMMIT..$E3_COMMIT" | sort > "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" > "$OUT_DIR/changed-files.diff" || die 'source escaped two-file boundary'
[ "$(git -C "$E3_DIR" diff --numstat "$E2_COMMIT..$E3_COMMIT" | awk '{a += $1; d += $2} END {print a+0, d+0}')" = '2044 0' ] || die 'unexpected source line totals'
git -C "$E3_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" > "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = "$E3_DIFF_SHA" ] || die 'E3 diff hash changed'

git -C "$E2_DIR" show "$E2_COMMIT:kernel/sched/exec_lease.c" |
	sed -n '/^#define SCHED_EXEC_BUCKET_B_MAX/,/^#endif \/\* CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE \*\//p' > "$OUT_DIR/e2-private-block.c"
git -C "$E3_DIR" show "$E3_COMMIT:kernel/sched/exec_lease.c" |
	sed -n '/^#define SCHED_EXEC_BUCKET_B_MAX/,/^#endif \/\* CONFIG_SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE \*\//p' > "$OUT_DIR/e3-private-block.c"
diff -u "$OUT_DIR/e2-private-block.c" "$OUT_DIR/e3-private-block.c" > "$OUT_DIR/e2-private-block.diff" || die 'E2 private layout/probe block changed'

progress '14% checking default-off same-TU Kconfig and strict style'
SOURCE="$E3_DIR/kernel/sched/exec_lease.c"
KCONFIG="$E3_DIR/init/Kconfig"
[ "$(grep -c '^config SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST$' "$KCONFIG")" = 1 ] || die 'KUnit config count mismatch'
sed -n '/^config SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST$/,/^config /p' "$KCONFIG" > "$OUT_DIR/e3-kconfig.txt"
grep -qx $'\tbool "KUnit test for scheduler execution bucket concurrency"' "$OUT_DIR/e3-kconfig.txt" || die 'KUnit bool declaration changed'
grep -qx $'\tdepends on SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE && KUNIT=y' "$OUT_DIR/e3-kconfig.txt" || die 'KUnit dependencies changed'
grep -qx $'\tdefault n' "$OUT_DIR/e3-kconfig.txt" || die 'KUnit config is not default off'
! grep -Eq 'default y|select KUNIT|KUNIT_ALL_TESTS' "$OUT_DIR/e3-kconfig.txt" || die 'KUnit config has an implicit enable path'
grep -q '^kunit_test_suites(&sched_exec_bucket_test_suite);$' "$SOURCE" || die 'same-TU suite registration missing'
grep -q $'^\t.name = "sched_exec_lease_bucket",$' "$SOURCE" || die 'suite name changed'
set +e
"$E3_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types "$OUT_DIR/e3-source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -q '^total: 0 errors, 0 warnings, 0 checks,' "$OUT_DIR/checkpatch.log" || die 'strict checkpatch totals changed'

progress '20% checking 20 deterministic families, six fault sites, and independent oracle'
jq -r '.required_case_families[]' "$PLAN" | sed 's/^/sched_exec_bucket_test_/' > "$OUT_DIR/expected-cases.txt"
sed -n '/^static struct kunit_case sched_exec_bucket_test_cases\[\]/,/^};/p' "$SOURCE" |
	sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' > "$OUT_DIR/actual-cases.txt"
diff -u "$OUT_DIR/expected-cases.txt" "$OUT_DIR/actual-cases.txt" > "$OUT_DIR/cases.diff" || die 'KUnit case set or order changed'
[ "$(wc -l < "$OUT_DIR/actual-cases.txt" | tr -d ' ')" = 20 ] || die 'KUnit case count is not exactly 20'

sed -n '/^enum sched_exec_bucket_test_alloc_site {/,/^};/p' "$SOURCE" |
	sed -n 's/^[[:space:]]*SCHED_EXEC_BUCKET_TEST_ALLOC_\([A-Z_]*\),$/\1/p' |
	grep -v '^NONE$' > "$OUT_DIR/actual-fault-sites.txt"
printf '%s\n' WORKQUEUE_CREATE BUCKET_CONTROL ACTIVE_RQ_CPUMASK RQ_STATE PROJECTION XARRAY_RESERVE > "$OUT_DIR/expected-fault-sites.txt"
diff -u "$OUT_DIR/expected-fault-sites.txt" "$OUT_DIR/actual-fault-sites.txt" > "$OUT_DIR/fault-sites.diff" || die 'allocation-fault set changed'
grep -q '^#define SCHED_EXEC_BUCKET_TEST_TIMEOUT (5 \* HZ)$' "$SOURCE" || die 'five-second timeout changed'
grep -q '^#define SCHED_EXEC_BUCKET_TEST_STRESS_ITERATIONS 1024$' "$SOURCE" || die 'stress count changed'
[ "$(grep -c 'SCHED_EXEC_BUCKET_TEST_STRESS_ITERATIONS; i++)' "$SOURCE")" -ge 4 ] || die 'four required stress families are not repeated'

sed -n '/^struct sched_exec_bucket_test_oracle {/,/^};/p' "$SOURCE" > "$OUT_DIR/oracle-struct.c"
! grep -Eq 'struct sched_exec_bucket[[:space:]*]|struct sched_exec_bucket_rq_(projection|state)[[:space:]*]' "$OUT_DIR/oracle-struct.c" || die 'oracle contains E2 private representation'
sed -n '/^sched_exec_bucket_test_oracle_assert(/,/^}/p' "$SOURCE" > "$OUT_DIR/oracle-assert.c"
! grep -Eq 'sched_exec_bucket_test_(add|remove|publish|prepare|queue|retire|settle)' "$OUT_DIR/oracle-assert.c" || die 'oracle shares a prototype transition helper'
grep -q 'actual->generation' "$OUT_DIR/oracle-assert.c" || die 'oracle generation assertion missing'
grep -q 'actual->projection_refs' "$OUT_DIR/oracle-assert.c" || die 'oracle reference assertion missing'
grep -q 'actual->active_bit' "$OUT_DIR/oracle-assert.c" || die 'oracle mask assertion missing'
grep -q 'actual->work_owned' "$OUT_DIR/oracle-assert.c" || die 'oracle work assertion missing'

progress '27% checking bounded protocol, lock order, work ownership, and retirement drain'
grep -q '^#define SCHED_EXEC_BUCKET_TEST_MAX_BUCKETS 65$' "$SOURCE" || die 'B_max rejection fixture changed'
grep -q 'rq->slots >= SCHED_EXEC_BUCKET_B_MAX' "$SOURCE" || die 'B_max capacity guard missing'
grep -q 'xa_reserve(&bucket->layout.projections, rq->id, GFP_KERNEL)' "$SOURCE" || die 'pre-runnable XArray reservation missing'
grep -q 'xa_store(&bucket->layout.projections, rq->id, projection,' "$SOURCE" || die 'reserved XArray publish missing'
grep -q 'alloc_workqueue("sched_exec_bucket_kunit_wq"' "$SOURCE" || die 'dedicated workqueue missing'
grep -q 'WQ_UNBOUND | WQ_HIGHPRI | WQ_MEM_RECLAIM, 1)' "$SOURCE" || die 'dedicated workqueue flags changed'
grep -q 'rcu_assign_pointer(environment->registry, NULL)' "$SOURCE" || die 'RCU unpublish missing'
grep -q 'cancel_work_sync(&projection\[cpu\]->layout.work)' "$SOURCE" || die 'work drain missing'
grep -q 'synchronize_rcu();' "$SOURCE" || die 'reader grace period missing'
grep -q 'call_rcu(&bucket->layout.rcu,' "$SOURCE" || die 'RCU callback missing'
grep -q 'destroy_workqueue(environment->workqueue)' "$SOURCE" || die 'workqueue destruction missing'

awk '
  /raw_spin_lock\(/ { depth++ }
  /queue_work\(|cancel_work_sync\(|kzalloc_obj\(|zalloc_cpumask_var\(|xa_reserve\(|xa_store\(|xa_erase\(|kfree\(/ {
    if (depth > 0) { print NR ":" $0; bad=1 }
  }
  /raw_spin_unlock\(/ { depth-- }
  END { exit bad }
' "$SOURCE" > "$OUT_DIR/blocking-under-lock.txt" || die 'queue/cancel/allocation/free appears under a test lock'

sed -n '/^sched_exec_bucket_test_publish(/,/^}/p' "$SOURCE" > "$OUT_DIR/publish-function.c"
! grep -q 'rq->lock' "$OUT_DIR/publish-function.c" || die 'publisher takes an rq lock'
publish_unlock=$(grep -n 'raw_spin_unlock(&bucket->layout.membership_lock)' "$OUT_DIR/publish-function.c" | tail -1 | cut -d: -f1)
publish_queue=$(grep -n 'sched_exec_bucket_test_queue(queue\[cpu\])' "$OUT_DIR/publish-function.c" | cut -d: -f1)
[ "$publish_unlock" -lt "$publish_queue" ] || die 'publisher queues work before unlocking membership'

sed -n '/^sched_exec_bucket_test_retire(/,/^}/p' "$SOURCE" > "$OUT_DIR/retire-function.c"
retire_unpublish=$(grep -n 'rcu_assign_pointer(environment->registry, NULL)' "$OUT_DIR/retire-function.c" | cut -d: -f1)
retire_cancel=$(grep -n 'cancel_work_sync' "$OUT_DIR/retire-function.c" | tail -1 | cut -d: -f1)
retire_free=$(grep -n 'kfree(bucket)' "$OUT_DIR/retire-function.c" | cut -d: -f1)
if [ "$retire_unpublish" -ge "$retire_cancel" ] || [ "$retire_cancel" -ge "$retire_free" ]; then
	die 'retirement ordering changed'
fi

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6
	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig > "$OUT_DIR/$label-defconfig.log" 2>&1
	case "$mode" in
		e2-baseline)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -e DEBUG_INFO_NONE
			;;
		e3-all-off)
			"$source/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -d SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST -d KUNIT_ALL_TESTS -e DEBUG_INFO_NONE
			;;
		e3-layout-on-test-off)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -d SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST -d KUNIT_ALL_TESTS -e DEBUG_INFO_NONE
			;;
		e3-test-on)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_BUCKET_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS -e SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST -e DEBUG_INFO_NONE
			;;
		*) die "unknown mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig > "$OUT_DIR/$label-olddefconfig.log" 2>&1
	case "$mode" in
		e3-all-off|e3-layout-on-test-off)
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y$' "$out/.config" || die "$label unexpectedly enabled E3"
			;;
		e3-test-on)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_BUCKET_KUNIT_TEST=y$' "$out/.config" || die "$label did not enable E3"
			grep -q '^# CONFIG_KUNIT_ALL_TESTS is not set$' "$out/.config" || die "$label enabled KUNIT_ALL_TESTS"
			;;
	esac
}

build_and_check_arch()
{
	local arch=$1 cross=$2 nm_command=$3 readelf_command=$4 label=$5
	local root="$BUILD_ROOT/$label"
	local e2="$root/e2-baseline" all_off="$root/e3-all-off" layout_off="$root/e3-layout-on-test-off" test_on="$root/e3-test-on"
	prepare_config "$E2_DIR" "$arch" "$cross" e2-baseline "$e2" "$label-e2"
	prepare_config "$E3_DIR" "$arch" "$cross" e3-all-off "$all_off" "$label-all-off"
	prepare_config "$E3_DIR" "$arch" "$cross" e3-layout-on-test-off "$layout_off" "$label-layout-off"
	prepare_config "$E3_DIR" "$arch" "$cross" e3-test-on "$test_on" "$label-test-on"
	for entry in "$E2_DIR:$e2:e2" "$E3_DIR:$all_off:all-off" "$E3_DIR:$layout_off:layout-off" "$E3_DIR:$test_on:test-on"; do
		local source rest out mode
		source=${entry%%:*}
		rest=${entry#*:}
		out=${rest%%:*}
		mode=${rest##*:}
		if [ "$mode" = all-off ]; then
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$(nproc)" kernel/sched/ > "$OUT_DIR/$label-$mode-build.log" 2>&1
			test ! -e "$out/kernel/sched/exec_lease.o" || die "$label all-off unexpectedly built exec_lease.o"
		else
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" -j"$(nproc)" kernel/sched/exec_lease.o > "$OUT_DIR/$label-$mode-build.log" 2>&1
			test -s "$out/kernel/sched/exec_lease.o" || die "$label $mode object missing"
		fi
	done

	"$nm_command" -S "$e2/kernel/sched/exec_lease.o" | awk '$4 ~ /^sched_exec_bl_/ {print $4 "\t" $2}' | sort > "$OUT_DIR/$label-e2-private.tsv"
	"$nm_command" -S "$layout_off/kernel/sched/exec_lease.o" | awk '$4 ~ /^sched_exec_bl_/ {print $4 "\t" $2}' | sort > "$OUT_DIR/$label-layout-off-private.tsv"
	diff -u "$OUT_DIR/$label-e2-private.tsv" "$OUT_DIR/$label-layout-off-private.tsv" > "$OUT_DIR/$label-e2-private.diff" || die "$label changed E2 private probe values"
	[ "$(wc -l < "$OUT_DIR/$label-layout-off-private.tsv" | tr -d ' ')" = 43 ] || die "$label E2 private probe count changed"

	test ! -e "$all_off/kernel/sched/exec_lease.o" || die "$label all-off emitted E3 translation unit"
	object="$layout_off/kernel/sched/exec_lease.o"
	"$nm_command" -a "$object" > "$OUT_DIR/$label-layout-off-nm.txt"
	"$readelf_command" -rW "$object" > "$OUT_DIR/$label-layout-off-relocations.txt"
	strings -a "$object" > "$OUT_DIR/$label-layout-off-strings.txt"
	! grep -Eq 'sched_exec_bucket_test_|sched_exec_bucket_kunit_wq|sched_exec_lease_bucket' "$OUT_DIR/$label-layout-off-nm.txt" || die "$label disabled object has E3 symbol"
	! grep -Eq 'sched_exec_bucket_test_|sched_exec_bucket_kunit_wq|sched_exec_lease_bucket' "$OUT_DIR/$label-layout-off-relocations.txt" || die "$label disabled object has E3 relocation"
	! grep -Eq 'sched_exec_bucket_kunit_wq|sched_exec_lease_bucket' "$OUT_DIR/$label-layout-off-strings.txt" || die "$label disabled object has E3 string"
	"$nm_command" -a "$test_on/kernel/sched/exec_lease.o" > "$OUT_DIR/$label-test-on-nm.txt"
	strings -a "$test_on/kernel/sched/exec_lease.o" > "$OUT_DIR/$label-test-on-strings.txt"
	grep -q 'sched_exec_bucket_test_suite' "$OUT_DIR/$label-test-on-nm.txt" || die "$label enabled suite symbol missing"
	grep -qx 'sched_exec_lease_bucket' "$OUT_DIR/$label-test-on-strings.txt" || die "$label enabled suite string missing"
	sha256sum "$e2/kernel/sched/exec_lease.o" "$layout_off/kernel/sched/exec_lease.o" "$test_on/kernel/sched/exec_lease.o" > "$OUT_DIR/$label-object-sha256.txt"
	sha256sum "$all_off/.config" "$all_off/kernel/sched/built-in.a" > "$OUT_DIR/$label-all-off-sha256.txt"
}

progress '36% building fresh arm64 E2/off/layout-off/test-on objects'
build_and_check_arch arm64 '' nm readelf arm64
progress '63% building fresh x86_64 E2/off/layout-off/test-on objects'
build_and_check_arch x86_64 x86_64-linux-gnu- x86_64-linux-gnu-nm x86_64-linux-gnu-readelf x86_64

progress '91% writing machine-readable source-gate result'
jq -n \
	--arg run_id "$RUN_ID" \
	--arg candidate "$E3_COMMIT" \
	--arg parent "$E2_COMMIT" \
	--arg tree "$E3_TREE" \
	--arg diff_sha256 "$E3_DIFF_SHA" \
	--arg primary "$PRIMARY_COMMIT" \
	--arg patch_queue "$PATCH_QUEUE_COMMIT" \
'
{
  schema_version: 1,
  id: "sched-exec-lease-p5a-r3-e3-bucket-concurrency-source-gate-result-v1",
  run_id: $run_id,
  status: "passed_source_gate_awaiting_diagnostic_matrix",
  candidate_commit: $candidate,
  candidate_parent: $parent,
  candidate_tree: $tree,
  candidate_diff_sha256: $diff_sha256,
  primary_commit: $primary,
  patch_queue_commit: $patch_queue,
  exact_direct_e2_child: true,
  exact_two_file_boundary: true,
  insertions: 2044,
  deletions: 0,
  e2_private_layout_and_43_probes_preserved: true,
  config_default_off: true,
  same_translation_unit: true,
  suite_name: "sched_exec_lease_bucket",
  deterministic_case_families: 20,
  allocation_fault_sites: 6,
  b_max: 64,
  hard_timeout_seconds: 5,
  stress_iterations: 1024,
  independent_plain_oracle: true,
  retirement_drain_order_checked: true,
  strict_checkpatch: {errors:0, warnings:0, checks:0},
  architectures: ["arm64", "x86_64"],
  fresh_modes_per_architecture: ["exact_e2_parent_baseline", "e3_all_off", "e3_layout_on_test_off", "e3_test_on"],
  disabled_e3_symbols_relocations_strings: 0,
  diagnostic_matrix_may_start: true,
  e3_runtime_correctness_proven: false,
  primary_linux_changed: false,
  patch_queue_changed: false,
  production_ready: false
}
' > "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% source gate passed; diagnostic matrix may start'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
