#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e3-correctness-prototype"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
PLAN_SOURCE="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan-v1.json"
PLAN_R3_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan/20260726T-p5a-r6-e3-correctness-plan-r3/result.json"
PLAN_R4_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-concurrency-evidence-plan/20260726T-p5a-r6-e3-correctness-plan-r4/result.json"
E2_SOURCE_GATE_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-source-gate/20260725T-p5a-r6-e2-source-gate-r1/result.json"
E2_DUAL_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-dual-arch-layout/20260725T-p5a-r6-e2-dual-arch-r1/result.json"
E2_CLOSURE_SOURCE="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e2-evidence-closure/20260726T-p5a-r6-e2-closure-r2/result.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e3-correctness-source-gate"
OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r6-e3-source-gate/$RUN_ID"
E2_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e2-layout"
E3_DIR="$CANDIDATE_DIR"
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-$(nproc)}

PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PRIMARY_TREE=54f685aad94f28f0027cbba18cf5e29aadce234a
E2_COMMIT=66e2fd20fc85012d7dc03649fcf4c7af583cbb94
E2_TREE=603762b7a36d7b57e2456b90538c3ba77a1aba16
E3_COMMIT=99287291f1c8e0d6c1b3ea86d121508c5547f424
E3_TREE=2b863b57dfe3f03609ad1a73c965874f71056e8f
E3_DIFF_SHA=2ed265756c1cee52252bedc6cbfb3d651eed136be9dca98992496ee80ebfb715
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
PATCH_QUEUE_SERIES_BLOB=298567f8e0bd18168222da4e64da32750b9ea818
PLAN_SHA=36f5d2b0423d1a4f6de05e08ac4166e098bb7e7680ce81758b361187dc0e8d22
PLAN_R3_SHA=7a1c6bc4079ab24b34cce54efa3817f210b07502b077e5a8bed4f0944c5eebe2
PLAN_R4_SHA=6f989baf4b90f3647948d496863ef7d5024fa4d58774968cf5b7a17b15787917
E2_SOURCE_GATE_SHA=18c329d9f10a34559056f8ef00007f9d6644b82b5d4be5f8227a4d7f8f9d452f
E2_DUAL_SHA=6164a7a9913e9cf6da96a7f09944c3a18225ddddb8d1ccc690350d339b2890a4
E2_CLOSURE_SHA=e937c252819d0e79b8815b540641002f9f9bb22b6f432f3ab1e18992d6b0c7b8
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
	rm -rf -- "$BUILD_ROOT"
	if [ "${PREFLIGHT_ONLY:-0}" = 1 ]; then
		rm -rf -- "$OUT_DIR"
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

for command in awk cmp cp diff gcc git grep jq make mkdir mv nm nproc \
	readelf sed sha256sum sort strings wc x86_64-linux-gnu-gcc \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf; do
	command -v "$command" >/dev/null 2>&1 ||
		die "missing command: $command"
done
for path in "$OUT_DIR" "$BUILD_ROOT"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run path already exists: $path"
	fi
done

for path in "$E2_DIR" "$E3_DIR"; do
	[ -d "$path" ] || die "missing source worktree: $path"
done
mkdir -p "$OUT_ROOT" "$(dirname "$BUILD_ROOT")"
mkdir "$OUT_DIR" "$INPUT_DIR" "$BUILD_ROOT"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
trap cleanup EXIT INT TERM

if [ ! -f "$HARDENING_LIB_SOURCE" ] ||
	[ -L "$HARDENING_LIB_SOURCE" ]; then
	die 'hardening helper is not a regular file'
fi
[ "$(sha256sum "$HARDENING_LIB_SOURCE" | awk '{print $1}')" = \
	"$HARDENING_LIB_SHA" ] || die 'hardening helper changed'
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"
capsched_verify_file_sha256 "$INPUT_DIR/immutable-evidence-inputs.sh" \
	"$HARDENING_LIB_SHA" || die 'hardening helper snapshot mismatch'
runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" \
	"$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$PLAN_SOURCE" "$PLAN_SHA" \
	"$INPUT_DIR/plan.json" || die 'could not snapshot plan'
capsched_snapshot_verified_file "$PLAN_R3_SOURCE" "$PLAN_R3_SHA" \
	"$INPUT_DIR/plan-r3-result.json" || die 'could not snapshot plan r3'
capsched_snapshot_verified_file "$PLAN_R4_SOURCE" "$PLAN_R4_SHA" \
	"$INPUT_DIR/plan-r4-result.json" || die 'could not snapshot plan r4'
capsched_snapshot_verified_file "$E2_SOURCE_GATE_SOURCE" \
	"$E2_SOURCE_GATE_SHA" "$INPUT_DIR/e2-source-gate-result.json" ||
	die 'could not snapshot E2 source gate'
capsched_snapshot_verified_file "$E2_DUAL_SOURCE" "$E2_DUAL_SHA" \
	"$INPUT_DIR/e2-dual-result.json" ||
	die 'could not snapshot E2 dual result'
capsched_snapshot_verified_file "$E2_CLOSURE_SOURCE" "$E2_CLOSURE_SHA" \
	"$INPUT_DIR/e2-closure-result.json" ||
	die 'could not snapshot E2 closure'

PLAN="$INPUT_DIR/plan.json"
progress '2% locking exact E2 closure, E3 plan, and repository identities'
for result in "$INPUT_DIR/plan-r3-result.json" \
	"$INPUT_DIR/plan-r4-result.json"; do
	jq -e '
	  .status == "passed_r6_e3_correctness_concurrency_evidence_plan" and
	  .required_case_families == 55 and
	  .independent_oracle_leaves == 64 and
	  .safe_passed == true and
	  .unsafe_safety_counterexamples == 79 and
	  .unsafe_liveness_counterexamples == 3 and
	  .disposable_e3_source_draft_may_start == true and
	  .r6_e3_source_accepted == false
	' "$result" >/dev/null || die 'R6-E3 plan result semantics changed'
done
jq -e '
  .status == "r6_e3_source_free_pre_source_plan" and
  .source_boundary.future_parent ==
    "66e2fd20fc85012d7dc03649fcf4c7af583cbb94" and
  .source_boundary.direct_child_required == true and
  .source_boundary.allowed_files ==
    ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .configuration.name == "SCHED_EXEC_LEASE_R6_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.suite == "sched_exec_lease_r6_correctness" and
  (.required_case_families | length) == 55 and
  (.allocation_faults.sites | length) == 3 and
  .race_control.stress_repetitions_per_diagnostic_profile == 4096 and
  (.build_and_boot_matrix.diagnostic_boots | length) == 4
' "$PLAN" >/dev/null || die 'R6-E3 plan contract changed'
jq -e '
  .status == "passed_r6_e2_evidence_closure" and
  .r6_e2_evidence_closed == true and
  .r6_e3_plan_may_start == true
' "$INPUT_DIR/e2-closure-result.json" >/dev/null ||
	die 'R6-E2 closure semantics changed'

[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] ||
	die 'primary Linux commit moved'
[ "$(git -C "$PRIMARY_DIR" rev-parse 'HEAD^{tree}')" = "$PRIMARY_TREE" ] ||
	die 'primary Linux tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$E3_COMMIT" ] ||
	die 'R6-E3 candidate moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$E2_COMMIT" ] ||
	die 'R6-E3 is not a direct R6-E2 child'
[ "$(git -C "$CANDIDATE_DIR" rev-parse "$E2_COMMIT^{tree}")" = \
	"$E2_TREE" ] || die 'R6-E2 tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = "$E3_TREE" ] ||
	die 'R6-E3 candidate tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	refs/remotes/fork/codex/p5a-r6-e3-correctness-prototype)" = \
	"$E3_COMMIT" ] || die 'fork-tracking R6-E3 branch moved'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'R6-E3 candidate tracked tree is dirty'
[ "$(git -C "$E2_DIR" rev-parse HEAD)" = "$E2_COMMIT" ] ||
	die 'R6-E2 worktree moved'
[ -z "$(git -C "$E2_DIR" status --porcelain --untracked-files=no)" ] ||
	die 'R6-E2 tracked tree is dirty'
git -C "$CANDIDATE_DIR" log -1 --format=%B |
	grep -Eq '^Signed-off-by: .+ <.+>$' ||
	die 'R6-E3 candidate lacks sign-off'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'patch queue moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse \
	'HEAD:patches/capsched-linux-l0/series')" = \
	"$PATCH_QUEUE_SERIES_BLOB" ] || die 'patch series moved'

progress '7% checking direct-child, two-file, frozen-layout, and style boundary'
git -C "$E3_DIR" diff --check "$E2_COMMIT..$E3_COMMIT"
git -C "$E3_DIR" diff --name-only "$E2_COMMIT..$E3_COMMIT" |
	sort > "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" \
	> "$OUT_DIR/changed-files.diff" ||
	die 'source escaped exact two-file boundary'
[ "$(git -C "$E3_DIR" diff --numstat "$E2_COMMIT..$E3_COMMIT" |
	awk '{a += $1; d += $2} END {print a+0, d+0}')" = '1516 0' ] ||
	die 'candidate is not the exact additive source'
git -C "$E3_DIR" diff --binary "$E2_COMMIT..$E3_COMMIT" \
	> "$OUT_DIR/e3-source.diff"
[ "$(sha256sum "$OUT_DIR/e3-source.diff" | awk '{print $1}')" = \
	"$E3_DIFF_SHA" ] || die 'candidate diff hash changed'
git -C "$E3_DIR" diff --exit-code "$E2_COMMIT..$E3_COMMIT" -- \
	include/linux/sched.h include/linux/sched_exec_lease.h \
	kernel/sched/Makefile kernel/sched/sched.h kernel/sched/fair.c \
	kernel/sched/core.c kernel/sched/exec_lease_layout_probe.c
sed -n '/^#define SCHED_EXEC_R6_B_MAX/,/SCHED_EXEC_R6_PRIVATE_RQ_LIMIT);/p' \
	"$E2_DIR/kernel/sched/exec_lease.c" > "$OUT_DIR/e2-private-block.c"
sed -n '/^#define SCHED_EXEC_R6_B_MAX/,/SCHED_EXEC_R6_PRIVATE_RQ_LIMIT);/p' \
	"$E3_DIR/kernel/sched/exec_lease.c" > "$OUT_DIR/e3-private-block.c"
cmp "$OUT_DIR/e2-private-block.c" "$OUT_DIR/e3-private-block.c" ||
	die 'R6-E2 private layout/probe block changed'
"$E3_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types \
	"$OUT_DIR/e3-source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
grep -q '^total: 0 errors, 0 warnings, 0 checks,' \
	"$OUT_DIR/checkpatch.log" || die 'strict checkpatch totals changed'

progress '12% checking exact config, 55 cases, three faults, and receipts'
SOURCE="$E3_DIR/kernel/sched/exec_lease.c"
KCONFIG="$E3_DIR/init/Kconfig"
sed -n '/^config SCHED_EXEC_LEASE_R6_KUNIT_TEST$/,/^config /p' \
	"$KCONFIG" > "$OUT_DIR/e3-kconfig.txt"
[ "$(grep -c '^config SCHED_EXEC_LEASE_R6_KUNIT_TEST$' "$KCONFIG")" = 1 ] ||
	die 'R6 KUnit config count mismatch'
grep -qx $'\tdepends on SCHED_EXEC_LEASE_R6_LAYOUT_PROBE && KUNIT=y' \
	"$OUT_DIR/e3-kconfig.txt" || die 'R6 KUnit dependencies changed'
grep -qx $'\tdefault n' "$OUT_DIR/e3-kconfig.txt" ||
	die 'R6 KUnit config is not default off'
! grep -Eq 'default y|select KUNIT|KUNIT_ALL_TESTS' \
	"$OUT_DIR/e3-kconfig.txt" || die 'R6 KUnit has an implicit enable path'
grep -q '^kunit_test_suite(sched_exec_r6_correctness_test_suite);$' \
	"$SOURCE" || die 'same-TU suite registration missing'
grep -q $'^\t.name = "sched_exec_lease_r6_correctness",$' "$SOURCE" ||
	die 'suite name changed'

jq -r '.required_case_families[]' "$PLAN" > "$OUT_DIR/expected-cases.txt"
sed -n \
	'/static const struct sched_exec_r6_test_case sched_exec_r6_cases\[\]/,/^};/p' \
	"$SOURCE" | tr '\n' ' ' | grep -o 'R6_CASE([^,]*' |
	sed 's/R6_CASE(//;s/^[[:space:]]*//;s/[[:space:]]*$//' \
	> "$OUT_DIR/actual-cases.txt"
diff -u "$OUT_DIR/expected-cases.txt" "$OUT_DIR/actual-cases.txt" \
	> "$OUT_DIR/cases.diff" || die '55-case set or order changed'
[ "$(sort -u "$OUT_DIR/actual-cases.txt" | wc -l | tr -d ' ')" = 55 ] ||
	die '55 cases are not unique'
printf '%s\n' SEALED_DESCRIPTOR PER_CPU_RQ_STATE TASK_BINDING \
	> "$OUT_DIR/expected-fault-sites.txt"
sed -n '/^enum sched_exec_r6_test_alloc_site {/,/^};/p' "$SOURCE" |
	sed -n \
	's/^[[:space:]]*SCHED_EXEC_R6_TEST_ALLOC_\([A-Z_]*\),$/\1/p' |
	grep -v '^NONE$' > "$OUT_DIR/actual-fault-sites.txt"
diff -u "$OUT_DIR/expected-fault-sites.txt" \
	"$OUT_DIR/actual-fault-sites.txt" > "$OUT_DIR/fault-sites.diff" ||
	die 'three allocation fault sites changed'
grep -q '^#define SCHED_EXEC_R6_TEST_STRESS_ITERATIONS[[:space:]]*4096$' \
	"$SOURCE" || die '4096 stress count changed'
grep -Fq 'R6_RECEIPT {\"case\":\"%s\"' "$SOURCE" ||
	die 'machine-readable receipt emission missing'
grep -q 'raw_spin_lock_irqsave(&fixture->lock' "$SOURCE" ||
	die 'real raw spinlock path missing'
grep -q 'cpumask_test_cpu(' "$SOURCE" || die 'real cpumask path missing'
grep -q 'refcount_inc_not_zero(' "$SOURCE" ||
	die 'real refcount acquisition missing'
grep -q 'synchronize_rcu();' "$SOURCE" || die 'RCU grace period missing'
grep -q 'sched_exec_r6_test_oracle_aggregate' "$SOURCE" ||
	die 'independent aggregate oracle missing'
grep -q 'sched_exec_r6_test_oracle_pick' "$SOURCE" ||
	die 'independent picker oracle missing'
! grep -Eq 'msleep|ssleep|schedule_timeout' "$SOURCE" ||
	die 'timing sleep added as proof'
if sed -n '/^+[^+]/p' "$OUT_DIR/e3-source.diff" |
	grep -nE 'EXPORT_SYMBOL|cpuhp_setup_state|debugfs_create|proc_create|sysfs_create|tracepoint_probe_register|resched_curr\(' \
		> "$OUT_DIR/forbidden-runtime-surfaces.txt"; then
	die 'runtime or export surface added'
fi

if [ "${PREFLIGHT_ONLY:-0}" = 1 ]; then
	progress '100% preflight passed; dual-architecture builds not started'
	exit 0
fi

prepare_config()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6

	mkdir -p "$out"
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		defconfig > "$OUT_DIR/$label-defconfig.log" 2>&1
	case "$mode" in
	e2-parent|e3-layout-on-test-off|e3-test-on)
		"$source/scripts/config" --file "$out/.config" \
			-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED \
			-e FAIR_GROUP_SCHED -d SCHED_AUTOGROUP \
			-e SCHED_EXEC_LEASE -e DEBUG_KERNEL \
			-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
			-e SCHED_EXEC_LEASE_R6_LAYOUT_PROBE -e DEBUG_INFO_NONE
		if [ "$mode" = e3-test-on ]; then
			"$source/scripts/config" --file "$out/.config" \
				-e KUNIT -d KUNIT_ALL_TESTS \
				-e SCHED_EXEC_LEASE_R6_KUNIT_TEST
		else
			"$source/scripts/config" --file "$out/.config" \
				-d SCHED_EXEC_LEASE_R6_KUNIT_TEST
		fi
		;;
	e3-release-normal)
		"$source/scripts/config" --file "$out/.config" \
			-d SCHED_EXEC_LEASE -d SCHED_EXEC_LEASE_LAYOUT_PROBE \
			-d SCHED_EXEC_LEASE_R6_LAYOUT_PROBE \
			-d SCHED_EXEC_LEASE_R6_KUNIT_TEST -d KUNIT_ALL_TESTS \
			-e DEBUG_INFO_NONE
		;;
	*) die "unknown config mode: $mode" ;;
	esac
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		olddefconfig > "$OUT_DIR/$label-olddefconfig.log" 2>&1
	cp "$out/.config" "$OUT_DIR/$label.config"
	case "$mode" in
	e3-test-on)
		grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST=y$' \
			"$out/.config" || die "$label R6 test missing"
		;;
	e3-layout-on-test-off)
		grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE=y$' \
			"$out/.config" || die "$label R6 layout missing"
		! grep -q '^CONFIG_SCHED_EXEC_LEASE_R6_KUNIT_TEST=y$' \
			"$out/.config" || die "$label R6 test unexpectedly on"
		;;
	e3-release-normal)
		! grep -q '^CONFIG_SCHED_EXEC_LEASE=y$' "$out/.config" ||
			die "$label lease unexpectedly on"
		;;
	esac
}

build_mode()
{
	local source=$1 arch=$2 cross=$3 mode=$4 out=$5 label=$6
	local log="$OUT_DIR/$label-build.log"
	local target

	if [ "$mode" = e3-release-normal ]; then
		target=kernel/sched/
	else
		target='kernel/sched/exec_lease.o kernel/sched/exec_lease_layout_probe.o'
	fi
	# shellcheck disable=SC2086
	make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
		W=1 -j"$JOBS" $target > "$log" 2>&1
	! grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$log" ||
		die "$label compiler diagnostic"
	if grep -Eiq 'Clock skew detected|modification time .* in the future' \
		"$log"; then
		clock_skew_retries=$((clock_skew_retries + 1))
		# shellcheck disable=SC2086
		make -C "$source" O="$out" ARCH="$arch" CROSS_COMPILE="$cross" \
			W=1 -j"$JOBS" $target \
			> "$OUT_DIR/$label-clock-skew-verification.log" 2>&1
		! grep -Eiq \
			'Clock skew detected|modification time .* in the future' \
			"$OUT_DIR/$label-clock-skew-verification.log" ||
			die "$label persistent clock skew"
	fi
	if [ "$mode" = e3-release-normal ]; then
		test ! -e "$out/kernel/sched/exec_lease.o" ||
			die "$label release emitted exec_lease.o"
	else
		test -s "$out/kernel/sched/exec_lease.o" ||
			die "$label exec_lease.o missing"
		test -s "$out/kernel/sched/exec_lease_layout_probe.o" ||
			die "$label layout probe object missing"
	fi
}

extract_symbols()
{
	local nm_cmd=$1 object=$2 prefix=$3 output=$4

	"$nm_cmd" -S "$object" |
		awk -v prefix="$prefix" \
			'$4 ~ ("^" prefix) {print $4 "\t" $2}' |
		sort -k1 > "$output"
}

validate_arch()
{
	local label=$1 arch=$2 cross=$3 nm_cmd=$4 readelf_cmd=$5 compiler=$6
	local percent=$7 root="$BUILD_ROOT/$label" arch_out="$OUT_DIR/$label"
	local mode source out
	local e2_exec="$root/e2-parent/kernel/sched/exec_lease.o"
	local off_exec="$root/e3-layout-on-test-off/kernel/sched/exec_lease.o"
	local on_exec="$root/e3-test-on/kernel/sched/exec_lease.o"

	mkdir -p "$arch_out"
	for mode in e2-parent e3-layout-on-test-off e3-test-on \
		e3-release-normal; do
		if [ "$mode" = e2-parent ]; then source=$E2_DIR; else source=$E3_DIR; fi
		out="$root/$mode"
		progress "$percent% $label $mode configuration and W=1 build"
		prepare_config "$source" "$arch" "$cross" "$mode" "$out" \
			"$label-$mode"
		build_mode "$source" "$arch" "$cross" "$mode" "$out" \
			"$label-$mode"
	done

	extract_symbols "$nm_cmd" "$e2_exec" sched_exec_r6l_ \
		"$arch_out/e2-private.tsv"
	extract_symbols "$nm_cmd" "$off_exec" sched_exec_r6l_ \
		"$arch_out/test-off-private.tsv"
	extract_symbols "$nm_cmd" "$on_exec" sched_exec_r6l_ \
		"$arch_out/test-on-private.tsv"
	[ "$(wc -l < "$arch_out/e2-private.tsv" | tr -d ' ')" = 49 ] ||
		die "$label R6 private count changed"
	cmp "$arch_out/e2-private.tsv" "$arch_out/test-off-private.tsv" ||
		die "$label test-off changed R6 private values"
	cmp "$arch_out/e2-private.tsv" "$arch_out/test-on-private.tsv" ||
		die "$label test-on changed R6 private values"
	extract_symbols "$nm_cmd" \
		"$root/e2-parent/kernel/sched/exec_lease_layout_probe.o" \
		sched_exec_lp_ "$arch_out/e2-expanded.tsv"
	extract_symbols "$nm_cmd" \
		"$root/e3-layout-on-test-off/kernel/sched/exec_lease_layout_probe.o" \
		sched_exec_lp_ "$arch_out/test-off-expanded.tsv"
	extract_symbols "$nm_cmd" \
		"$root/e3-test-on/kernel/sched/exec_lease_layout_probe.o" \
		sched_exec_lp_ "$arch_out/test-on-expanded.tsv"
	[ "$(wc -l < "$arch_out/e2-expanded.tsv" | tr -d ' ')" = 51 ] ||
		die "$label expanded count changed"
	cmp "$arch_out/e2-expanded.tsv" "$arch_out/test-off-expanded.tsv" ||
		die "$label test-off changed expanded values"
	cmp "$arch_out/e2-expanded.tsv" "$arch_out/test-on-expanded.tsv" ||
		die "$label test-on changed expanded values"

	"$nm_cmd" -a "$off_exec" > "$arch_out/test-off-nm.txt"
	"$readelf_cmd" -rW "$off_exec" > "$arch_out/test-off-relocations.txt"
	"$readelf_cmd" -SW "$off_exec" > "$arch_out/test-off-sections.txt"
	strings -a "$off_exec" > "$arch_out/test-off-strings.txt"
	! grep -Eq \
		'sched_exec_r6_test_|sched_exec_lease_r6_correctness|R6_RECEIPT' \
		"$arch_out/test-off-nm.txt" ||
		die "$label disabled object has R6-E3 symbol"
	! grep -Eq \
		'sched_exec_r6_test_|sched_exec_lease_r6_correctness|R6_RECEIPT' \
		"$arch_out/test-off-relocations.txt" ||
		die "$label disabled object has R6-E3 relocation"
	! grep -Eq 'kunit_test_suites|initcall' \
		"$arch_out/test-off-sections.txt" ||
		die "$label disabled object has KUnit/initcall section"
	! grep -Eq 'sched_exec_lease_r6_correctness|R6_RECEIPT' \
		"$arch_out/test-off-strings.txt" ||
		die "$label disabled object has R6-E3 string"

	"$nm_cmd" -a "$on_exec" > "$arch_out/test-on-nm.txt"
	"$readelf_cmd" -SW "$on_exec" > "$arch_out/test-on-sections.txt"
	strings -a "$on_exec" > "$arch_out/test-on-strings.txt"
	grep -q 'sched_exec_r6_correctness_test_suite' \
		"$arch_out/test-on-nm.txt" || die "$label suite symbol missing"
	grep -Eq 'kunit_test_suites|initcall' \
		"$arch_out/test-on-sections.txt" ||
		die "$label KUnit registration section missing"
	grep -qx 'sched_exec_lease_r6_correctness' \
		"$arch_out/test-on-strings.txt" || die "$label suite string missing"
	grep -Fq 'R6_RECEIPT {' "$arch_out/test-on-strings.txt" ||
		die "$label receipt string missing"
	while IFS= read -r case_name; do
		grep -qx "$case_name" "$arch_out/test-on-strings.txt" ||
			die "$label object missing case: $case_name"
	done < "$OUT_DIR/expected-cases.txt"

	jq -n --arg architecture "$label" \
		--arg compiler_machine "$("$compiler" -dumpmachine)" \
		--arg compiler_version "$("$compiler" -dumpfullversion -dumpversion)" \
		--arg e2_object_sha "$(sha256sum "$e2_exec" | awk '{print $1}')" \
		--arg off_object_sha "$(sha256sum "$off_exec" | awk '{print $1}')" \
		--arg on_object_sha "$(sha256sum "$on_exec" | awk '{print $1}')" \
		'{status:"passed",architecture:$architecture,
		  compiler:{machine:$compiler_machine,version:$compiler_version},
		  fresh_modes:["exact_e2_parent_layout_on",
		    "e3_candidate_layout_on_test_off",
		    "e3_candidate_layout_on_test_on",
		    "e3_candidate_release_normal"],
		  e2_object_sha256:$e2_object_sha,
		  test_off_object_sha256:$off_object_sha,
		  test_on_object_sha256:$on_object_sha,
		  r6_private_values_preserved:49,
		  existing_expanded_values_preserved:51,
		  disabled_e3_artifacts:0,
		  enabled_case_strings:55,
		  ordinary_structure_growth_bytes:0}' \
		> "$arch_out/result.json"
}

validate_arch arm64 arm64 '' nm readelf gcc 18
validate_arch x86_64 x86_64 x86_64-linux-gnu- \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf \
	x86_64-linux-gnu-gcc 55

progress '94% sealing machine-readable source-gate result'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" ||
	die 'runner changed during execution'
capsched_verify_file_sha256 "$INPUT_DIR/runner.sh" "$runner_initial_sha" ||
	die 'runner snapshot changed'
capsched_verify_file_sha256 "$PLAN" "$PLAN_SHA" ||
	die 'plan snapshot changed'
for tree in "$E2_DIR" "$E3_DIR"; do
	git -C "$tree" diff --quiet HEAD -- init/Kconfig \
		kernel/sched/exec_lease.c \
		kernel/sched/exec_lease_layout_probe.c ||
		die "bound source files changed during build: $tree"
done
arm_sha=$(sha256sum "$OUT_DIR/arm64/result.json" | awk '{print $1}')
x86_sha=$(sha256sum "$OUT_DIR/x86_64/result.json" | awk '{print $1}')
jq -n --arg run_id "$RUN_ID" --arg candidate "$E3_COMMIT" \
	--arg parent "$E2_COMMIT" --arg tree "$E3_TREE" \
	--arg diff_sha "$E3_DIFF_SHA" --arg primary "$PRIMARY_COMMIT" \
	--arg patch_queue "$PATCH_QUEUE_COMMIT" \
	--arg plan_sha "$PLAN_SHA" --arg plan_r3_sha "$PLAN_R3_SHA" \
	--arg plan_r4_sha "$PLAN_R4_SHA" \
	--arg e2_source_gate_sha "$E2_SOURCE_GATE_SHA" \
	--arg e2_dual_sha "$E2_DUAL_SHA" \
	--arg e2_closure_sha "$E2_CLOSURE_SHA" \
	--arg runner_sha "$runner_initial_sha" \
	--arg arm_result "$OUT_DIR/arm64/result.json" --arg arm_sha "$arm_sha" \
	--arg x86_result "$OUT_DIR/x86_64/result.json" --arg x86_sha "$x86_sha" \
	--slurpfile arm64 "$OUT_DIR/arm64/result.json" \
	--slurpfile x86_64 "$OUT_DIR/x86_64/result.json" \
	--argjson clock_skew_retries "$clock_skew_retries" \
	'{schema_version:1,
	  id:"sched-exec-lease-p5a-r6-e3-correctness-source-gate-result-v1",
	  run_id:$run_id,
	  status:"passed_source_gate_awaiting_four_profile_diagnostic_matrix",
	  candidate_commit:$candidate,candidate_parent:$parent,
	  candidate_tree:$tree,candidate_diff_sha256:$diff_sha,
	  primary_commit:$primary,patch_queue_commit:$patch_queue,
	  plan_sha256:$plan_sha,
	  reproduced_plan_result_sha256:[$plan_r3_sha,$plan_r4_sha],
	  e2_source_gate_sha256:$e2_source_gate_sha,
	  e2_dual_arch_sha256:$e2_dual_sha,
	  e2_closure_sha256:$e2_closure_sha,
	  runner_sha256:$runner_sha,
	  immutable_input_snapshots_verified:true,
	  exact_direct_e2_child:true,exact_two_file_boundary:true,
	  insertions:1516,deletions:0,
	  e2_private_layout_block_preserved:true,
	  r6_private_values_preserved:49,
	  existing_expanded_values_preserved:51,
	  config_default_off:true,same_translation_unit:true,
	  suite_name:"sched_exec_lease_r6_correctness",
	  deterministic_case_families:55,allocation_fault_sites:3,
	  stress_repetitions:4096,independent_oracle_leaves:64,
	  real_raw_spinlock_cpumask_refcount_rcu:true,
	  strict_checkpatch:{errors:0,warnings:0,checks:0},
	  w1_compiler_diagnostics:0,
	  clock_skew_retries:$clock_skew_retries,
	  architectures:["arm64","x86_64"],
	  fresh_modes_per_architecture:["exact_e2_parent_layout_on",
	    "e3_candidate_layout_on_test_off",
	    "e3_candidate_layout_on_test_on",
	    "e3_candidate_release_normal"],
	  disabled_e3_artifacts:0,ordinary_structure_growth_bytes:0,
	  results:{arm64:$arm64[0],x86_64:$x86_64[0]},
	  arm64_result:$arm_result,arm64_result_sha256:$arm_sha,
	  x86_64_result:$x86_result,x86_64_result_sha256:$x86_sha,
	  diagnostic_matrix_may_start:true,
	  r6_e3_source_accepted:false,
	  r6_e3_correctness_accepted:false,
	  primary_linux_changed:false,patch_queue_changed:false,
	  live_scheduler_attachment:false,runtime_behavior_approved:false,
	  production_protection:false,deployment_ready:false,
	  multi_node_ready:false,multi_cluster_ready:false,
	  datacenter_ready:false}' > "$OUT_DIR/result.json.pending"
jq -e '
  .status == "passed_source_gate_awaiting_four_profile_diagnostic_matrix" and
  .candidate_commit ==
    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .deterministic_case_families == 55 and
  .allocation_fault_sites == 3 and
  .strict_checkpatch == {errors:0,warnings:0,checks:0} and
  .w1_compiler_diagnostics == 0 and
  .disabled_e3_artifacts == 0 and
  .ordinary_structure_growth_bytes == 0 and
  .diagnostic_matrix_may_start == true and
  .r6_e3_source_accepted == false and
  .production_protection == false
' "$OUT_DIR/result.json.pending" >/dev/null
mv "$OUT_DIR/result.json.pending" "$OUT_DIR/result.json"
sha256sum "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
progress '100% passed; exact R6-E3 source and dual-architecture gate complete'
printf 'result=%s\n' "$OUT_DIR/result.json"
printf 'sha256=%s\n' "$(awk '{print $1}' "$OUT_DIR/result.sha256")"
