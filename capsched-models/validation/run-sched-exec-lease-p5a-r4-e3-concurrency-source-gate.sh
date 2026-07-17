#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
E3_SOURCE_DIR="$PRIMARY_DIR"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan-v1.json"
PLAN_R13_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan/20260717T-p5a-r4-e3-concurrency-plan-r13/result.json"
PLAN_R14_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-diagnostic-evidence-plan/20260717T-p5a-r4-e3-concurrency-plan-r14/result.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e3-concurrency-source-gate"
OUT_DIR="$RUN_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r4-e3-source-gate/$RUN_ID"
E2_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e3-source-gate-e2-$RUN_ID"
E3_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r4-e3-source-gate-e3-$RUN_ID"
PROGRESS_FILE=${PROGRESS_FILE:-}

PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PRIMARY_TREE=54f685aad94f28f0027cbba18cf5e29aadce234a
E2_COMMIT=a429fc30252ac6af94c51d96cd4ac24e72d9f83b
E2_TREE=fffd419bbc05bab87ad304c1e4a3213439d62bab
E3_COMMIT=f9c737c93ecff48c6f512048b05b1b49f4a54ca5
E3_TREE=274f7b5d6969dc68e158819191fe598f9587e0ad
E3_DIFF_SHA=c35299bead06a874a21f116b15f4aabfd27c9ca945e9541dfb6dc8c31fa5b781
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
PLAN_R13_SHA=79a9c62edc8dfa58645028c9ab43af9554f7672bbae267f8b5c7ab0c9157c912
PLAN_R14_SHA=2be94265244a7cde6ff5f4d353133fa6315b692b65ad762b743ac0a89d309537
PLAN_SHA=f9c9103b4eae2177309dd8e0134601fe3cf1eb08061986265627dcd9d8fd6677
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
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

	trap - EXIT INT TERM
	for worktree in "$E2_DIR" "$E3_DIR"; do
		if git -C "$E3_SOURCE_DIR" worktree list --porcelain 2>/dev/null |
			grep -Fxq "worktree $worktree"; then
			git -C "$E3_SOURCE_DIR" worktree remove --force "$worktree" >/dev/null 2>&1 ||
				printf 'warning: could not retire temporary worktree: %s\n' "$worktree" >&2
		fi
	done
	rm -rf -- "$BUILD_ROOT"
	if [ "${PREFLIGHT_ONLY:-0}" = 1 ]; then
		rm -rf -- "$OUT_DIR"
	fi
	exit "$rc"
}

case "$RUN_ID" in
	[A-Za-z0-9]* ) ;;
	* ) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac

for command in awk cp diff git grep jq make mkdir mv nm nproc readelf sed \
	sha256sum sort strings wc x86_64-linux-gnu-gcc \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
if [ -e "$BUILD_ROOT" ] || [ -L "$BUILD_ROOT" ]; then
	die "build root already exists: $BUILD_ROOT"
fi
for worktree in "$E2_DIR" "$E3_DIR"; do
	if [ -e "$worktree" ] || [ -L "$worktree" ]; then
		die "temporary worktree exists: $worktree"
	fi
done
mkdir -p "$RUN_ROOT" "$(dirname "$BUILD_ROOT")" "$(dirname "$E2_DIR")"
mkdir "$OUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR"
trap cleanup EXIT INT TERM

mkdir "$INPUT_DIR"
if [ ! -f "$HARDENING_LIB_SOURCE" ] || [ -L "$HARDENING_LIB_SOURCE" ]; then
	die 'hardening helper is not a regular file'
fi
[ "$(sha256sum "$HARDENING_LIB_SOURCE" | awk '{print $1}')" = "$HARDENING_LIB_SHA" ] || die 'hardening helper changed'
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# The verified snapshot path is run-specific and therefore not statically resolvable.
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"
capsched_verify_file_sha256 "$INPUT_DIR/immutable-evidence-inputs.sh" "$HARDENING_LIB_SHA" || die 'hardening helper snapshot mismatch'
runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" "$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$PLAN_SOURCE" "$PLAN_SHA" "$INPUT_DIR/plan.json" || die 'could not snapshot plan'
capsched_snapshot_verified_file "$PLAN_R13_SOURCE" "$PLAN_R13_SHA" "$INPUT_DIR/n133-r13-result.json" || die 'could not snapshot N-133 r13 result'
capsched_snapshot_verified_file "$PLAN_R14_SOURCE" "$PLAN_R14_SHA" "$INPUT_DIR/n133-r14-result.json" || die 'could not snapshot N-133 r14 result'
PLAN="$INPUT_DIR/plan.json"
PLAN_R13="$INPUT_DIR/n133-r13-result.json"
PLAN_R14="$INPUT_DIR/n133-r14-result.json"

progress '2% locking N-133 seal and exact repository identities'
[ "$(sha256sum "$PLAN_R13" | awk '{print $1}')" = "$PLAN_R13_SHA" ] || die 'N-133 r13 result changed'
[ "$(sha256sum "$PLAN_R14" | awk '{print $1}')" = "$PLAN_R14_SHA" ] || die 'N-133 r14 result changed'
for result in "$PLAN_R13" "$PLAN_R14"; do
	jq -e '
	  .status == "passed_r4_e3_concurrency_diagnostic_plan_only" and
	  .e2_candidate_commit == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
	  .r4_e3_disposable_worktree_may_be_created == true and
	  .r4_e3_exact_two_file_source_draft_may_be_created == true and
	  .r4_e3_source_accepted == false and
	  .safe_passed == true and
	  .safe_states_generated == 30 and
	  .safe_distinct_states == 29 and
	  .safe_depth == 29 and
	  .liveness_properties_checked == 4 and
	  .unsafe_expected_counterexamples == 76
	' "$result" >/dev/null
done
jq -e '
  .status == "r4_e3_concurrency_diagnostic_pre_source_plan" and
  .source_boundary.future_parent == "a429fc30252ac6af94c51d96cd4ac24e72d9f83b" and
  .source_boundary.direct_child_required == true and
  .source_boundary.allowed_files == ["init/Kconfig", "kernel/sched/exec_lease.c"] and
  .configuration.name == "SCHED_EXEC_LEASE_R4_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.same_translation_unit == "kernel/sched/exec_lease.c" and
  .configuration.suite_name == "sched_exec_lease_r4_concurrency" and
  (.required_case_families | length) == 36 and
  (.capacity_and_allocation.allocation_fault_sites | length) == 6 and
  .race_control.hard_timeout_seconds == 15 and
  .race_control.stress_iterations_per_diagnostic_boot == 2048 and
  (.build_and_boot_matrix.qemu_boots | length) == 6
' "$PLAN" >/dev/null

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] || die 'primary Linux commit moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')" = "$PRIMARY_TREE" ] || die 'primary Linux tree moved'
[ -z "$(git -C "$PRIMARY_DIR" status --porcelain --untracked-files=no)" ] || die 'primary Linux checkout is dirty'
[ "$(git -C "$E3_SOURCE_DIR" rev-parse "$E3_COMMIT")" = "$E3_COMMIT" ] || die 'R4-E3 candidate object missing'
[ "$(git -C "$E3_SOURCE_DIR" rev-parse "$E3_COMMIT^")" = "$E2_COMMIT" ] || die 'R4-E3 is not a direct E2 child'
[ "$(git -C "$E3_SOURCE_DIR" rev-parse "$E3_COMMIT^{tree}")" = "$E3_TREE" ] || die 'R4-E3 candidate tree moved'
[ "$(git -C "$E3_SOURCE_DIR" rev-parse refs/heads/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'local R4-E3 branch moved'
[ "$(git -C "$E3_SOURCE_DIR" rev-parse refs/remotes/fork/codex/p5a-r4-e3-concurrency-prototype)" = "$E3_COMMIT" ] || die 'fork-tracking R4-E3 branch moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] || die 'patch queue moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse 'HEAD:patches/capsched-linux-l0/series')" = "$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch series moved'

git -C "$E3_SOURCE_DIR" worktree add --detach "$E2_DIR" "$E2_COMMIT" > "$OUT_DIR/e2-worktree-add.log" 2>&1
git -C "$E3_SOURCE_DIR" worktree add --detach "$E3_DIR" "$E3_COMMIT" > "$OUT_DIR/e3-worktree-add.log" 2>&1
[ "$(git -C "$E2_DIR" rev-parse HEAD)" = "$E2_COMMIT" ] || die 'temporary E2 checkout mismatch'
[ "$(git -C "$E2_DIR" rev-parse 'HEAD^{tree}')" = "$E2_TREE" ] || die 'temporary E2 tree mismatch'
[ "$(git -C "$E3_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] || die 'temporary E3 checkout mismatch'
[ "$(git -C "$E3_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] || die 'temporary E3 tree mismatch'

progress '7% checking direct-child, two-file, byte-preservation, and style boundary'
git -C "$E3_DIR" diff --check "$E2_COMMIT..$E3_COMMIT"
git -C "$E3_DIR" diff --name-only "$E2_COMMIT..$E3_COMMIT" | sort > "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" > "$OUT_DIR/changed-files.diff" || die 'source escaped two-file boundary'
[ "$(git -C "$E3_DIR" diff --numstat "$E2_COMMIT..$E3_COMMIT" | awk '{a += $1; d += $2} END {print a+0, d+0}')" = '2758 0' ] || die 'candidate is not the exact additive source'
git -C "$E3_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" > "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = "$E3_DIFF_SHA" ] || die 'candidate diff hash changed'
git -C "$E2_DIR" show "$E2_COMMIT:kernel/sched/exec_lease.c" |
	sed -n '/^#define SCHED_EXEC_R4_B_MAX/,/^#endif \/\* CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE \*\//p' > "$OUT_DIR/e2-private-block.c"
git -C "$E3_DIR" show "$E3_COMMIT:kernel/sched/exec_lease.c" |
	sed -n '/^#define SCHED_EXEC_R4_B_MAX/,/^#endif \/\* CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE \*\//p' > "$OUT_DIR/e3-private-block.c"
diff -u "$OUT_DIR/e2-private-block.c" "$OUT_DIR/e3-private-block.c" > "$OUT_DIR/e2-private-block.diff" || die 'E2 private layout/probe block changed'
set +e
"$E3_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types "$OUT_DIR/e3-source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
checkpatch_rc=$?
set -e
[ "$checkpatch_rc" = 0 ] || die 'strict checkpatch failed'
grep -q '^total: 0 errors, 0 warnings, 0 checks,' "$OUT_DIR/checkpatch.log" || die 'strict checkpatch totals changed'

progress '12% checking exact config, 36 cases, six faults, receipts, and source protocol'
SOURCE="$E3_DIR/kernel/sched/exec_lease.c"
KCONFIG="$E3_DIR/init/Kconfig"
sed -n '/^config SCHED_EXEC_LEASE_R4_KUNIT_TEST$/,/^config /p' "$KCONFIG" > "$OUT_DIR/e3-kconfig.txt"
[ "$(grep -c '^config SCHED_EXEC_LEASE_R4_KUNIT_TEST$' "$KCONFIG")" = 1 ] || die 'R4 KUnit config count mismatch'
grep -qx $'\tbool "KUnit test for R4 scheduler execution lease concurrency"' "$OUT_DIR/e3-kconfig.txt" || die 'R4 KUnit bool declaration changed'
grep -qx $'\tdepends on SCHED_EXEC_LEASE_R4_LAYOUT_PROBE && KUNIT=y' "$OUT_DIR/e3-kconfig.txt" || die 'R4 KUnit dependencies changed'
grep -qx $'\tdefault n' "$OUT_DIR/e3-kconfig.txt" || die 'R4 KUnit config is not default off'
! grep -Eq 'default y|select KUNIT|KUNIT_ALL_TESTS' "$OUT_DIR/e3-kconfig.txt" || die 'R4 KUnit config has an implicit enable path'
grep -q '^kunit_test_suites(&sched_exec_r4_test_suite);$' "$SOURCE" || die 'same-TU suite registration missing'
grep -q $'^\t.name = "sched_exec_lease_r4_concurrency",$' "$SOURCE" || die 'suite name changed'

jq -r '.required_case_families[] | "sched_exec_r4_test_" + .' "$PLAN" > "$OUT_DIR/expected-cases.txt"
sed -n '/^static struct kunit_case sched_exec_r4_test_cases\[\]/,/^};/p' "$SOURCE" |
	sed -n 's/^[[:space:]]*KUNIT_CASE(\([^)]*\)).*/\1/p' > "$OUT_DIR/actual-cases.txt"
diff -u "$OUT_DIR/expected-cases.txt" "$OUT_DIR/actual-cases.txt" > "$OUT_DIR/cases.diff" || die '36-case set or order changed'
[ "$(wc -l < "$OUT_DIR/actual-cases.txt" | tr -d ' ')" = 36 ] || die 'case count is not 36'
jq -r '.capacity_and_allocation.allocation_fault_sites[] | ascii_upcase' "$PLAN" > "$OUT_DIR/expected-fault-sites.txt"
sed -n '/^enum sched_exec_r4_test_fault_site {/,/^};/p' "$SOURCE" |
	sed -n 's/^[[:space:]]*SCHED_EXEC_R4_TEST_FAULT_\([A-Z_]*\),$/\1/p' |
	grep -v '^NONE$' > "$OUT_DIR/actual-fault-sites.txt"
diff -u "$OUT_DIR/expected-fault-sites.txt" "$OUT_DIR/actual-fault-sites.txt" > "$OUT_DIR/fault-sites.diff" || die 'six-fault set changed'
grep -q '^#define SCHED_EXEC_R4_TEST_TIMEOUT[[:space:]]*(15 \* HZ)$' "$SOURCE" || die '15-second timeout changed'
grep -q '^#define SCHED_EXEC_R4_TEST_STRESS_ITERATIONS[[:space:]]*2048$' "$SOURCE" || die '2048 stress count changed'
grep -q '^struct sched_exec_r4_case_receipt {' "$SOURCE" || die 'machine-readable receipt type missing'
grep -q 'R4_RECEIPT {' "$SOURCE" || die 'machine-readable receipt emission missing'
grep -q 'alloc_workqueue("sched_exec_r4_kunit_wq"' "$SOURCE" || die 'dedicated workqueue missing'
grep -q 'WQ_UNBOUND | WQ_HIGHPRI | WQ_MEM_RECLAIM, 1)' "$SOURCE" || die 'workqueue flags changed'
grep -q 'IRQ_WORK_INIT_HARD(sched_exec_r4_dispatch_irq)' "$SOURCE" || die 'hard irq-work initialization missing'
grep -q 'cpumask_next(bucket->layout.next_cpu_cursor,' "$SOURCE" || die 'cursor notifier missing'
grep -q 'refcount_inc_not_zero(&projection->layout.refs)' "$SOURCE" || die 'notifier projection reference missing'
grep -q 'xa_reserve(&bucket->layout.projections, rq->id, GFP_KERNEL)' "$SOURCE" || die 'pre-runnable XArray reservation missing'
grep -q 'synchronize_rcu();' "$SOURCE" || die 'RCU grace period missing'
grep -q 'call_rcu(&bucket->layout.rcu,' "$SOURCE" || die 'RCU callback missing'

sed -n '/^static void sched_exec_r4_dispatch_irq(struct irq_work \*work)$/,/^}/p' "$SOURCE" > "$OUT_DIR/dispatch-irq.c"
grep -q 'queue_work(environment->workqueue,' "$OUT_DIR/dispatch-irq.c" || die 'dispatch does not queue recovery work'
! grep -Eq 'raw_spin_lock|mutex_lock|xa_|(k|v|kv|devm_)[a-z_]*alloc\(|kfree\(|cancel_[a-z_]*\(|flush_[a-z_]*\(|synchronize_[a-z_]*\(|sched_exec_r4_test_(add|remove|publish|retire)\(' "$OUT_DIR/dispatch-irq.c" || die 'hard irq callback is not dispatch-only'
sed -n '/^static int sched_exec_r4_test_publish(/,/^}/p' "$SOURCE" > "$OUT_DIR/publish-function.c"
! grep -Eq 'cpumask_(next|first)|xa_for_each|rq->lock|raw_spin_lock.*rq' "$OUT_DIR/publish-function.c" || die 'publisher escaped O(1) bucket-only boundary'
publish_unlock=$(grep -n 'raw_spin_unlock(&bucket->layout.membership_lock)' "$OUT_DIR/publish-function.c" | tail -1 | cut -d: -f1)
publish_queue=$(grep -n 'sched_exec_r4_test_queue_notifier(bucket)' "$OUT_DIR/publish-function.c" | cut -d: -f1)
[ "$publish_unlock" -lt "$publish_queue" ] || die 'publisher queues notifier before unlock'
sed -n '/^static int sched_exec_r4_test_rq_offline(/,/^}/p' "$SOURCE" > "$OUT_DIR/offline-function.c"
offline_irq=$(grep -n 'irq_work_sync' "$OUT_DIR/offline-function.c" | head -1 | cut -d: -f1)
offline_cancel=$(grep -n 'cancel_work_sync' "$OUT_DIR/offline-function.c" | head -1 | cut -d: -f1)
[ "$offline_irq" -lt "$offline_cancel" ] || die 'offline drain order changed'
if sed -n '/^+[^+]/p' "$OUT_DIR/e3-source.diff" |
	grep -nE 'EXPORT_SYMBOL|cpuhp_setup_state|debugfs_create|proc_create|sysfs_create|tracepoint_probe_register|resched_curr\(' > "$OUT_DIR/forbidden-runtime-surfaces.txt"; then
	die 'runtime/export surface added'
fi

source_manifest="$OUT_DIR/source-file-hashes.tsv"
printf 'tree\tpath\texpected_blob\tworking_blob\n' > "$source_manifest"
for spec in "primary:$PRIMARY_DIR" "e2:$E2_DIR" "e3:$E3_DIR"; do
	label=${spec%%:*}
	tree=${spec#*:}
	for path in init/Kconfig kernel/sched/Makefile kernel/sched/exec_lease.c kernel/sched/exec_lease_layout_probe.c; do
		expected_blob=$(git -C "$tree" rev-parse "HEAD:$path")
		working_blob=$(git -C "$tree" hash-object "$path")
		printf '%s\t%s\t%s\t%s\n' "$label" "$path" "$expected_blob" "$working_blob" >> "$source_manifest"
		[ "$expected_blob" = "$working_blob" ] || die "$label working source differs from HEAD: $path"
	done
done

if [ "${PREFLIGHT_ONLY:-0}" = 1 ]; then
	progress '100% preflight passed; build matrix intentionally not started'
	exit 0
fi

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6

	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" defconfig > "$OUT_DIR/$label-defconfig.log" 2>&1
	case "$mode" in
		e2-parent)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -e DEBUG_INFO_NONE
			;;
		e3-all-off)
			"$source/scripts/config" --file "$out/.config" -d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE -d SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -d SCHED_EXEC_LEASE_R4_KUNIT_TEST -d KUNIT_ALL_TESTS -e DEBUG_INFO_NONE
			;;
		e3-layout-on-test-off)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -d SCHED_EXEC_LEASE_R4_KUNIT_TEST -d KUNIT_ALL_TESTS -e DEBUG_INFO_NONE
			;;
		e3-test-on)
			"$source/scripts/config" --file "$out/.config" -e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED -e FAIR_GROUP_SCHED -e SCHED_EXEC_LEASE -e DEBUG_KERNEL -e SCHED_EXEC_LEASE_LAYOUT_PROBE -e SCHED_EXEC_LEASE_R4_LAYOUT_PROBE -e KUNIT -d KUNIT_ALL_TESTS -e SCHED_EXEC_LEASE_R4_KUNIT_TEST -e DEBUG_INFO_NONE
			;;
		*) die "unknown config mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" olddefconfig > "$OUT_DIR/$label-olddefconfig.log" 2>&1
	case "$mode" in
		e3-all-off)
			! grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$out/.config" || die "$label ordinary lease unexpectedly enabled"
			;;
		e3-layout-on-test-off)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_R4_LAYOUT_PROBE=y$' "$out/.config" || die "$label R4 layout missing"
			! grep -q '^CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y$' "$out/.config" || die "$label E3 unexpectedly enabled"
			;;
		e3-test-on)
			grep -q '^CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST=y$' "$out/.config" || die "$label E3 test missing"
			grep -q '^# CONFIG_KUNIT_ALL_TESTS is not set$' "$out/.config" || die "$label KUNIT_ALL_TESTS enabled"
			;;
	esac
	cp "$out/.config" "$OUT_DIR/$label.config"
}

build_mode()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6
	local build_log="$OUT_DIR/$label-build.log"
	local verification_log="$OUT_DIR/$label-clock-skew-verification.log"
	local target

	if [ "$mode" = e3-all-off ]; then
		target=kernel/sched/
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
			W=1 -j"$(nproc)" "$target" > "$build_log" 2>&1
		test ! -e "$out/kernel/sched/exec_lease.o" || die "$label all-off emitted exec_lease.o"
	else
		target='kernel/sched/exec_lease.o kernel/sched/exec_lease_layout_probe.o'
		# shellcheck disable=SC2086
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
			W=1 -j"$(nproc)" $target > "$build_log" 2>&1
		test -s "$out/kernel/sched/exec_lease.o" || die "$label exec_lease.o missing"
		test -s "$out/kernel/sched/exec_lease_layout_probe.o" || die "$label expanded probe object missing"
	fi
	! grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$build_log" || die "$label compiler diagnostic"
	: > "$verification_log"
	if grep -Eiq 'Clock skew detected|modification time .* in the future' "$build_log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		progress "verifying $label after shared-filesystem clock skew"
		if [ "$mode" = e3-all-off ]; then
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
				W=1 -j"$(nproc)" "$target" > "$verification_log" 2>&1
		else
			# shellcheck disable=SC2086
			make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
				W=1 -j"$(nproc)" $target > "$verification_log" 2>&1
		fi
		! grep -Eiq 'Clock skew detected|modification time .* in the future' "$verification_log" || die "$label persistent clock skew"
		! grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$verification_log" || die "$label verification compiler diagnostic"
		if [ "$mode" = e3-all-off ]; then
			test ! -e "$out/kernel/sched/exec_lease.o" || die "$label verification all-off emitted exec_lease.o"
		else
			test -s "$out/kernel/sched/exec_lease.o" || die "$label verification exec_lease.o missing"
			test -s "$out/kernel/sched/exec_lease_layout_probe.o" || die "$label verification expanded probe object missing"
		fi
	fi
}

extract_symbols()
{
	local nm_cmd=$1 object=$2 prefix=$3 output=$4

	"$nm_cmd" -S "$object" | awk -v prefix="$prefix" '$4 ~ ("^" prefix) {print $4 "\t" $2}' | sort -k1 > "$output"
}

validate_arch()
{
	local label=$1 arch=$2 cross=$3 nm_cmd=$4 readelf_cmd=$5 compiler=$6
	local root="$BUILD_ROOT/$label" arch_out="$OUT_DIR/$label"
	local e2="$root/e2-parent"
	local layout_off="$root/e3-layout-on-test-off" test_on="$root/e3-test-on"
	local e2_exec="$e2/kernel/sched/exec_lease.o"
	local layout_exec="$layout_off/kernel/sched/exec_lease.o"
	local test_exec="$test_on/kernel/sched/exec_lease.o"
	local mode source out

	mkdir -p "$arch_out"
	for mode in e2-parent e3-all-off e3-layout-on-test-off e3-test-on; do
		case "$mode" in
			e2-parent) source=$E2_DIR ;;
			*) source=$E3_DIR ;;
		esac
		out="$root/$mode"
		progress "$7 $label $mode configuration"
		prepare_config "$source" "$arch" "$cross" "$mode" "$out" "$label-$mode"
		build_mode "$source" "$arch" "$cross" "$mode" "$out" "$label-$mode"
	done

	extract_symbols "$nm_cmd" "$e2_exec" sched_exec_r4l_ "$arch_out/e2-private.tsv"
	extract_symbols "$nm_cmd" "$layout_exec" sched_exec_r4l_ "$arch_out/layout-off-private.tsv"
	extract_symbols "$nm_cmd" "$test_exec" sched_exec_r4l_ "$arch_out/test-on-private.tsv"
	[ "$(wc -l < "$arch_out/e2-private.tsv" | tr -d ' ')" = 58 ] || die "$label E2 private count changed"
	diff -u "$arch_out/e2-private.tsv" "$arch_out/layout-off-private.tsv" > "$arch_out/e2-vs-layout-private.diff" || die "$label layout-off changed E2 private values"
	diff -u "$arch_out/e2-private.tsv" "$arch_out/test-on-private.tsv" > "$arch_out/e2-vs-test-private.diff" || die "$label test-on changed E2 private values"
	extract_symbols "$nm_cmd" "$e2/kernel/sched/exec_lease_layout_probe.o" sched_exec_lp_ "$arch_out/e2-expanded.tsv"
	extract_symbols "$nm_cmd" "$layout_off/kernel/sched/exec_lease_layout_probe.o" sched_exec_lp_ "$arch_out/layout-off-expanded.tsv"
	extract_symbols "$nm_cmd" "$test_on/kernel/sched/exec_lease_layout_probe.o" sched_exec_lp_ "$arch_out/test-on-expanded.tsv"
	[ "$(wc -l < "$arch_out/e2-expanded.tsv" | tr -d ' ')" = 51 ] || die "$label expanded count changed"
	diff -u "$arch_out/e2-expanded.tsv" "$arch_out/layout-off-expanded.tsv" > "$arch_out/e2-vs-layout-expanded.diff" || die "$label layout-off changed expanded values"
	diff -u "$arch_out/e2-expanded.tsv" "$arch_out/test-on-expanded.tsv" > "$arch_out/e2-vs-test-expanded.diff" || die "$label test-on changed expanded values"

	"$nm_cmd" -a "$layout_exec" > "$arch_out/layout-off-nm.txt"
	"$readelf_cmd" -rW "$layout_exec" > "$arch_out/layout-off-relocations.txt"
	"$readelf_cmd" -SW "$layout_exec" > "$arch_out/layout-off-sections.txt"
	strings -a "$layout_exec" > "$arch_out/layout-off-strings.txt"
	! grep -Eq 'sched_exec_r4_test_|sched_exec_r4_(dispatch_irq|recovery_worker|notifier_worker)|sched_exec_r4_kunit_wq|sched_exec_lease_r4_concurrency|R4_RECEIPT' "$arch_out/layout-off-nm.txt" || die "$label disabled object has E3 symbol"
	! grep -Eq 'sched_exec_r4_test_|sched_exec_r4_(dispatch_irq|recovery_worker|notifier_worker)|sched_exec_r4_kunit_wq|sched_exec_lease_r4_concurrency|R4_RECEIPT' "$arch_out/layout-off-relocations.txt" || die "$label disabled object has E3 relocation"
	! grep -Eq 'kunit_test_suites|initcall' "$arch_out/layout-off-sections.txt" || die "$label disabled object has E3 test/initcall section"
	! grep -Eq 'sched_exec_r4_kunit_wq|sched_exec_lease_r4_concurrency|R4_RECEIPT' "$arch_out/layout-off-strings.txt" || die "$label disabled object has E3 string"
	"$nm_cmd" -a "$test_exec" > "$arch_out/test-on-nm.txt"
	"$readelf_cmd" -SW "$test_exec" > "$arch_out/test-on-sections.txt"
	strings -a "$test_exec" > "$arch_out/test-on-strings.txt"
	grep -q 'sched_exec_r4_test_suite' "$arch_out/test-on-nm.txt" || die "$label enabled suite symbol missing"
	grep -q 'sched_exec_r4_dispatch_irq' "$arch_out/test-on-nm.txt" || die "$label irq bridge missing"
	grep -q 'sched_exec_r4_recovery_worker' "$arch_out/test-on-nm.txt" || die "$label recovery worker missing"
	grep -q 'sched_exec_r4_notifier_worker' "$arch_out/test-on-nm.txt" || die "$label notifier worker missing"
	grep -Eq 'kunit_test_suites|initcall' "$arch_out/test-on-sections.txt" || die "$label enabled KUnit registration section missing"
	grep -qx 'sched_exec_lease_r4_concurrency' "$arch_out/test-on-strings.txt" || die "$label suite string missing"
	grep -q 'R4_RECEIPT {' "$arch_out/test-on-strings.txt" || die "$label receipt string missing"

	compiler_machine=$("$compiler" -dumpmachine)
	compiler_version=$("$compiler" -dumpfullversion -dumpversion)
	e2_exec_sha=$(sha256sum "$e2_exec" | awk '{print $1}')
	layout_exec_sha=$(sha256sum "$layout_exec" | awk '{print $1}')
	test_exec_sha=$(sha256sum "$test_exec" | awk '{print $1}')
	private_table_sha=$(sha256sum "$arch_out/e2-private.tsv" | awk '{print $1}')
	expanded_table_sha=$(sha256sum "$arch_out/e2-expanded.tsv" | awk '{print $1}')
	jq -n --arg architecture "$label" --arg compiler_machine "$compiler_machine" --arg compiler_version "$compiler_version" \
		--arg e2_object_sha "$e2_exec_sha" --arg layout_object_sha "$layout_exec_sha" --arg test_object_sha "$test_exec_sha" \
		--arg private_table_sha "$private_table_sha" --arg expanded_table_sha "$expanded_table_sha" \
		'{status:"passed",architecture:$architecture,compiler:{machine:$compiler_machine,version:$compiler_version},fresh_modes:["exact_e2_parent","e3_all_r4_options_off","e3_r4_layout_on_test_off","e3_r4_kunit_test_on"],e2_object_sha256:$e2_object_sha,layout_on_test_off_object_sha256:$layout_object_sha,test_on_object_sha256:$test_object_sha,private_table_sha256:$private_table_sha,expanded_table_sha256:$expanded_table_sha,existing_expanded_values_preserved:51,r4_private_values_preserved:58,disabled_e3_symbols_relocations_strings_initcalls:0,enabled_suite_and_bridge_symbols_present:true,ordinary_scheduler_structure_delta_zero:true}' > "$arch_out/result.json"
}

validate_arch arm64 arm64 '' nm readelf gcc '18%'
validate_arch x86_64 x86_64 x86_64-linux-gnu- x86_64-linux-gnu-nm x86_64-linux-gnu-readelf x86_64-linux-gnu-gcc '55%'

progress '92% sealing independent machine-readable source-gate result'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" || die 'runner changed during execution'
capsched_verify_file_sha256 "$INPUT_DIR/runner.sh" "$runner_initial_sha" || die 'runner snapshot changed'
capsched_verify_file_sha256 "$INPUT_DIR/immutable-evidence-inputs.sh" "$HARDENING_LIB_SHA" || die 'hardening helper snapshot changed'
capsched_verify_file_sha256 "$PLAN" "$PLAN_SHA" || die 'plan snapshot changed'
capsched_verify_file_sha256 "$PLAN_R13" "$PLAN_R13_SHA" || die 'N-133 r13 snapshot changed'
capsched_verify_file_sha256 "$PLAN_R14" "$PLAN_R14_SHA" || die 'N-133 r14 snapshot changed'
for tree in "$E2_DIR" "$E3_DIR"; do
	[ -z "$(git -C "$tree" status --porcelain --untracked-files=no)" ] || die "source worktree changed during build: $tree"
done
arm_sha=$(sha256sum "$OUT_DIR/arm64/result.json" | awk '{print $1}')
x86_sha=$(sha256sum "$OUT_DIR/x86_64/result.json" | awk '{print $1}')
plan_sha=$(sha256sum "$PLAN" | awk '{print $1}')
runner_sha=$(sha256sum "$INPUT_DIR/runner.sh" | awk '{print $1}')
source_manifest_sha=$(sha256sum "$source_manifest" | awk '{print $1}')
diff_sha=$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')
jq -n --arg run_id "$RUN_ID" --arg candidate "$E3_COMMIT" --arg parent "$E2_COMMIT" --arg tree "$E3_TREE" \
	--arg diff_sha "$diff_sha" --arg primary "$PRIMARY_COMMIT" --arg patch_queue "$PATCH_QUEUE_COMMIT" \
	--arg plan "$PLAN" --arg plan_sha "$plan_sha" --arg plan_r13_sha "$PLAN_R13_SHA" --arg plan_r14_sha "$PLAN_R14_SHA" \
	--arg runner "$INPUT_DIR/runner.sh" --arg runner_sha "$runner_sha" --arg hardening_lib "$INPUT_DIR/immutable-evidence-inputs.sh" --arg hardening_lib_sha "$HARDENING_LIB_SHA" --arg source_manifest "$source_manifest" --arg source_manifest_sha "$source_manifest_sha" \
	--arg arm_result "$OUT_DIR/arm64/result.json" --arg arm_sha "$arm_sha" --arg x86_result "$OUT_DIR/x86_64/result.json" --arg x86_sha "$x86_sha" \
	--slurpfile arm64 "$OUT_DIR/arm64/result.json" --slurpfile x86_64 "$OUT_DIR/x86_64/result.json" \
	--argjson clock_skew_retries "$clock_skew_retries" \
	'{schema_version:1,id:"sched-exec-lease-p5a-r4-e3-concurrency-source-gate-result-v1",run_id:$run_id,status:"passed_source_gate_awaiting_six_boot_diagnostic_matrix",candidate_commit:$candidate,candidate_parent:$parent,candidate_tree:$tree,candidate_diff_sha256:$diff_sha,primary_commit:$primary,patch_queue_commit:$patch_queue,plan:$plan,plan_sha256:$plan_sha,n133_sealed_results_sha256:[$plan_r13_sha,$plan_r14_sha],runner:$runner,runner_sha256:$runner_sha,hardening_helper:$hardening_lib,hardening_helper_sha256:$hardening_lib_sha,immutable_input_snapshots_verified:true,isolated_git_object_worktrees:true,source_manifest:$source_manifest,source_manifest_sha256:$source_manifest_sha,exact_direct_e2_child:true,exact_two_file_boundary:true,insertions:2758,deletions:0,e2_private_layout_and_58_probes_preserved:true,existing_expanded_51_values_preserved:true,config_default_off:true,same_translation_unit:true,suite_name:"sched_exec_lease_r4_concurrency",deterministic_case_families:36,allocation_fault_sites:6,hard_timeout_seconds:15,stress_iterations:2048,real_hard_irq_to_unbound_work_bridge:true,independent_plain_oracle_and_receipts:true,strict_checkpatch:{errors:0,warnings:0,checks:0},w1_compiler_diagnostics:0,clock_skew_retries:$clock_skew_retries,final_clock_skew_warnings:0,architectures:["arm64","x86_64"],fresh_modes_per_architecture:["exact_e2_parent","e3_all_r4_options_off","e3_r4_layout_on_test_off","e3_r4_kunit_test_on"],disabled_e3_symbols_relocations_strings_initcalls:0,results:{arm64:$arm64[0],x86_64:$x86_64[0]},arm64_result:$arm_result,arm64_result_sha256:$arm_sha,x86_64_result:$x86_result,x86_64_result_sha256:$x86_sha,diagnostic_matrix_may_start:true,r4_e3_source_accepted:false,r4_e3_concurrency_correctness_accepted:false,primary_linux_changed:false,patch_queue_changed:false,runtime_scheduler_hook_approved:false,runtime_behavior_approved:false,runtime_denial_correctness:false,production_protection:false,deployment_ready:false,multi_node_ready:false,multi_cluster_ready:false,datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
jq -e '.status == "passed_source_gate_awaiting_six_boot_diagnostic_matrix" and .candidate_commit == "f9c737c93ecff48c6f512048b05b1b49f4a54ca5" and .immutable_input_snapshots_verified == true and .isolated_git_object_worktrees == true and .insertions == 2758 and .deletions == 0 and .deterministic_case_families == 36 and .allocation_fault_sites == 6 and .w1_compiler_diagnostics == 0 and (.clock_skew_retries | type) == "number" and .final_clock_skew_warnings == 0 and .disabled_e3_symbols_relocations_strings_initcalls == 0 and .diagnostic_matrix_may_start == true and .r4_e3_source_accepted == false and .production_protection == false' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% passed; exact R4-E3 source and dual-architecture disabled/build gate complete'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
