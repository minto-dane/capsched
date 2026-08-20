#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
PRIMARY_DIR="$WORKSPACE_DIR/linux"
CANDIDATE_DIR="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/worktrees/p5a-r6-e4-local-quantum-measurement"
PATCH_QUEUE_DIR="$WORKSPACE_DIR/linux-patches"
CANONICAL_CONFIG="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-v1.json"
IMPLEMENTATION="$CAPSCHED_DIR/capsched-models/analysis/0184-sched-exec-lease-p5a-r6-e4-local-quantum-measurement-source.md"
PLAN="$CAPSCHED_DIR/capsched-models/analysis/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan-v1.json"
PLAN_NOTE="$CAPSCHED_DIR/capsched-models/validation/0283-sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan.md"
THREAT_MODEL="$CAPSCHED_DIR/capsched-models/assurance/linux-cap-repository-threat-model.md"
PLAN_R2="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan/20260727T-p5a-r6-e4-measurement-plan-r2/result.json"
PLAN_R3="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-measurement-plan/20260727T-p5a-r6-e4-measurement-plan-r3/result.json"
HARDENING_LIB_SOURCE="$SCRIPT_DIR/lib/immutable-evidence-inputs.sh"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
JOBS=${JOBS:-$(nproc)}
SOURCE_GATE_TEST_MODE=${SOURCE_GATE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
OFFLINE_TEST_MODE=${OFFLINE_TEST_MODE:-0}
CONFIG_OVERRIDE=${CONFIG_OVERRIDE:-}
TEST_CONFIG_SHA=${TEST_CONFIG_SHA:-}

CONFIG_SHA=cb06279b6b3fa8b975fac85d521b57672e14928c7f9738d9723f3d336f6e3ef4
IMPLEMENTATION_SHA=8a7d33bedd4c22c95dcad2c99dfb3270829a999e4f9bc675770ecf4aa0f73375
PLAN_SHA=8c3838e38568c780fb1e02c6ffc839de66b121af564bea47d45c289858667dc3
PLAN_NOTE_SHA=d93b5b8308baf00250014ec87a21eb44ebf6e94d32fd52e1d5c856ca3da93f1c
THREAT_MODEL_SHA=262f609a04b1da7b87562b48e42e9674e91151ed8ccdaaef3bc88596795e997d
PLAN_R2_SHA=b2a689abc6e936b06c65958c775e7d1b3bcfee8fb0768d7d5b03abcb6de0d1e6
PLAN_R3_SHA=58984d7f4c9c58ee6dbde90abdd5c4de35b4422f0f36c9fafe7c7677646e092a
PLAN_NORMALIZED_SHA=4490f9cc3898bb1a662c537cd99706675cbcb07b2fc2a52cb95898cdc0784f3d
HARDENING_LIB_SHA=4548753bc2acaa7497aef9e9ff070d9952f9b5ee20631c6116590067eab9ccc6
PRIMARY_COMMIT=5e1ca3037e34823d1ba0cdd1dc04161fac170280
PATCH_QUEUE_COMMIT=16bb080da472ffabbbafd2698073eca633fb0602
CANDIDATE_COMMIT=d51ebdc657a1040e423735584775e66399f321f9
CANDIDATE_PARENT=99287291f1c8e0d6c1b3ea86d121508c5547f424
CANDIDATE_TREE=0847c408be82e6c9077c2edd2d00f44ccfbe18fc
CANDIDATE_DIFF_SHA=fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9
CANDIDATE_SOURCE_SHA=688248428ca550bc1c56e8547fa5f601a46f5e031222b89c715be72150a4ab3c
CANDIDATE_KCONFIG_SHA=33da3e2cf8ddd79112cc42ef426828eb40c05f63892e6e71bc97a65f45f182ac
PREVIOUS_UPSTREAM=f5098b6bae761e346ebcd9da7f95622c04733cff
CURRENT_UPSTREAM=fc02acf6ac0ccde0c805c2daa9148683cdd01ba8
CANDIDATE_BRANCH=codex/p5a-r6-e4-local-quantum-measurement

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

case "$SOURCE_GATE_TEST_MODE:$PREFLIGHT_ONLY:$OFFLINE_TEST_MODE" in
	0:0:0|1:1:1) ;;
	*) die 'test, preflight, and offline modes must be enabled together' ;;
esac

if [ "$SOURCE_GATE_TEST_MODE" = 1 ]; then
	[ -n "$CONFIG_OVERRIDE" ] || die 'test mode requires CONFIG_OVERRIDE'
	[ -n "$TEST_CONFIG_SHA" ] || die 'test mode requires TEST_CONFIG_SHA'
	CONFIG_SOURCE=$CONFIG_OVERRIDE
	EXPECTED_CONFIG_SHA=$TEST_CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-test"
else
	[ -z "$CONFIG_OVERRIDE" ] || die 'CONFIG_OVERRIDE is test-only'
	[ -z "$TEST_CONFIG_SHA" ] || die 'TEST_CONFIG_SHA is test-only'
	CONFIG_SOURCE=$CANONICAL_CONFIG
	EXPECTED_CONFIG_SHA=$CONFIG_SHA
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r6-e4-local-quantum-source-gate"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
BUILD_ROOT="$WORKSPACE_DIR/build/DomainLeaseLinux.volume/builds/p5a-r6-e4-source-gate/$RUN_ID"

cleanup()
{
	local rc=$?

	trap - EXIT INT TERM
	rm -rf -- "$BUILD_ROOT"
	if [ "$SOURCE_GATE_TEST_MODE" = 1 ]; then
		rm -rf -- "$OUT_DIR"
	fi
	exit "$rc"
}

for command_name in awk chmod cmp cp diff find git grep jq make mkdir \
	nm nproc readelf sed sha256sum sort strings tr wc \
	x86_64-linux-gnu-gcc x86_64-linux-gnu-nm \
	x86_64-linux-gnu-readelf; do
	command -v "$command_name" >/dev/null 2>&1 ||
		die "missing command: $command_name"
done

capsched_run_id_pattern='^[A-Za-z0-9][A-Za-z0-9._-]*$'
printf '%s\n' "$RUN_ID" | grep -Eq "$capsched_run_id_pattern" ||
	die 'invalid RUN_ID'
case "$JOBS" in
	''|*[!0-9]*) die 'JOBS must be a positive integer' ;;
esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be greater than zero'
for path in "$OUT_DIR" "$BUILD_ROOT"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run path already exists: $path"
	fi
done
for path in "$CONFIG_SOURCE" "$IMPLEMENTATION" "$PLAN" "$PLAN_NOTE" \
	"$THREAT_MODEL" "$PLAN_R2" "$PLAN_R3" "$HARDENING_LIB_SOURCE"; do
	if [ ! -f "$path" ] || [ -L "$path" ]; then
		die "missing or unsafe input: $path"
	fi
done
if [ ! -d "$CANDIDATE_DIR" ] || [ -L "$CANDIDATE_DIR" ]; then
	die 'candidate worktree is missing or unsafe'
fi

mkdir -p "$OUT_ROOT" "$(dirname "$BUILD_ROOT")"
mkdir "$OUT_DIR" "$INPUT_DIR" "$BUILD_ROOT" "$OUT_DIR/artifacts"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
trap cleanup EXIT INT TERM

[ "$(sha256sum "$HARDENING_LIB_SOURCE" | awk '{print $1}')" = \
	"$HARDENING_LIB_SHA" ] || die 'hardening helper changed'
cp -- "$HARDENING_LIB_SOURCE" "$INPUT_DIR/immutable-evidence-inputs.sh"
chmod 0444 "$INPUT_DIR/immutable-evidence-inputs.sh"
# shellcheck disable=SC1091
source "$INPUT_DIR/immutable-evidence-inputs.sh"

runner_initial_sha=$(capsched_sha256_file "$RUNNER_SOURCE")
capsched_snapshot_verified_file "$RUNNER_SOURCE" "$runner_initial_sha" \
	"$INPUT_DIR/runner.sh" || die 'could not snapshot runner'
capsched_snapshot_verified_file "$CONFIG_SOURCE" "$EXPECTED_CONFIG_SHA" \
	"$INPUT_DIR/config.json" || die 'could not snapshot gate config'
capsched_snapshot_verified_file "$IMPLEMENTATION" "$IMPLEMENTATION_SHA" \
	"$INPUT_DIR/implementation.md" || die 'could not snapshot implementation'
capsched_snapshot_verified_file "$PLAN" "$PLAN_SHA" \
	"$INPUT_DIR/plan.json" || die 'could not snapshot plan'
capsched_snapshot_verified_file "$PLAN_NOTE" "$PLAN_NOTE_SHA" \
	"$INPUT_DIR/plan-validation.md" || die 'could not snapshot plan note'
capsched_snapshot_verified_file "$THREAT_MODEL" "$THREAT_MODEL_SHA" \
	"$INPUT_DIR/threat-model.md" || die 'could not snapshot threat model'
capsched_snapshot_verified_file "$PLAN_R2" "$PLAN_R2_SHA" \
	"$INPUT_DIR/plan-r2-result.json" || die 'could not snapshot plan r2'
capsched_snapshot_verified_file "$PLAN_R3" "$PLAN_R3_SHA" \
	"$INPUT_DIR/plan-r3-result.json" || die 'could not snapshot plan r3'
CONFIG="$INPUT_DIR/config.json"

progress '4% validating exact source-gate and claim contract'
jq -e '
  .id == "sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-v1" and
  .schema_version == 1 and
  .status == "r6_e4_pre_measurement_source_build_gate" and
  .plan.contract_sha256 ==
    "8c3838e38568c780fb1e02c6ffc839de66b121af564bea47d45c289858667dc3" and
  .plan.canonical_normalized_sha256 ==
    "4490f9cc3898bb1a662c537cd99706675cbcb07b2fc2a52cb95898cdc0784f3d" and
  .plan.exact_disposable_source_draft_authorized == true and
  .plan.measurement_already_authorized == false and
  .candidate.parent_commit ==
    "99287291f1c8e0d6c1b3ea86d121508c5547f424" and
  .candidate.commit == "d51ebdc657a1040e423735584775e66399f321f9" and
  .candidate.tree == "0847c408be82e6c9077c2edd2d00f44ccfbe18fc" and
  .candidate.direct_child_required == true and
  .candidate.allowed_files == ["init/Kconfig","kernel/sched/exec_lease.c"] and
  .candidate.additions == 1994 and .candidate.deletions == 38 and
  .candidate.primary_linux_change_allowed == false and
  .candidate.patch_queue_change_allowed == false and
  .configuration.name == "SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST" and
  .configuration.default_enabled == false and
  .configuration.depends_on ==
    ["SCHED_EXEC_LEASE_R6_KUNIT_TEST","KUNIT=y"] and
  .configuration.suite == "sched_exec_lease_r6_measure" and
  .configuration.selected_by_kunit_all_tests == false and
  .configuration.disabled_artifacts == 0 and
  ([.matrix.families[]] | add) == 855 and
  .matrix.total_cells == 855 and
  .matrix.warmup_pairs_per_cell == 256 and
  .matrix.measured_pairs_per_cell == 10000 and
  .matrix.total_measured_pairs == 8550000 and
  .matrix.exact_raw_rows_required == true and
  .matrix.additional_formula == "max(treatment_ns-control_ns,0)" and
  .operation_boundary.shared_e3_helpers_required == true and
  .operation_boundary.shared_e3_helpers_changed == true and
  .operation_boundary.full_e3_four_profile_regression_required == true and
  .operation_boundary.e3_cases_required == 55 and
  .operation_boundary.e3_receipts_required == 220 and
  .operation_boundary.e3_stress_repetitions == 4096 and
  .operation_boundary.ordinary_eevdf_inside_additional_interval == false and
  .operation_boundary.cheaper_timing_substitute_allowed == false and
  .build_matrix.architectures == ["arm64","x86_64"] and
  .build_matrix.modes ==
    ["e3_on_e4_off","e4_on","release_normal"] and
  .build_matrix.fresh_builds == 6 and
  .build_matrix.w1_diagnostics_allowed == 0 and
  .upstream.current_commit ==
    "fc02acf6ac0ccde0c805c2daa9148683cdd01ba8" and
  .upstream.advance_commits == 48 and
  .upstream.candidate_path_changes == [] and
  .upstream.global_freshness_claim == false and
  (.forbidden_added_patterns | length) == 10 and
  ([.claims[]] | all(. == false))
' "$CONFIG" >/dev/null || die 'source-gate contract changed'

for result in "$INPUT_DIR/plan-r2-result.json" \
	"$INPUT_DIR/plan-r3-result.json"; do
	jq -e '
	  .status == "passed_r6_e4_local_quantum_measurement_plan" and
	  .r6_e4_plan_accepted == true and
	  .exact_disposable_e4_source_draft_may_start == true and
	  .e4_source_or_measurement_accepted == false and
	  .matrix_cells == 855 and .total_measured_pairs == 8550000 and
	  .unsafe_safety_counterexamples == 82 and
	  .unsafe_liveness_counterexamples == 2 and
	  .runtime_behavior_approved == false and
	  .monitor_verified == false and .datacenter_ready == false
	' "$result" >/dev/null || die 'canonical plan semantics changed'
done
jq -S 'del(.run_id)' "$INPUT_DIR/plan-r2-result.json" \
	> "$OUT_DIR/plan-r2-normalized.json"
jq -S 'del(.run_id)' "$INPUT_DIR/plan-r3-result.json" \
	> "$OUT_DIR/plan-r3-normalized.json"
cmp "$OUT_DIR/plan-r2-normalized.json" "$OUT_DIR/plan-r3-normalized.json" ||
	die 'canonical plan results no longer normalize identically'
[ "$(sha256sum "$OUT_DIR/plan-r2-normalized.json" | awk '{print $1}')" = \
	"$PLAN_NORMALIZED_SHA" ] || die 'canonical plan normalization moved'

progress '12% validating immutable Git identity and upstream drift'
[ "$(git -C "$PRIMARY_DIR" rev-parse HEAD)" = "$PRIMARY_COMMIT" ] ||
	die 'primary Linux moved'
[ "$(git -C "$PATCH_QUEUE_DIR" rev-parse HEAD)" = "$PATCH_QUEUE_COMMIT" ] ||
	die 'patch queue moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD)" = "$CANDIDATE_COMMIT" ] ||
	die 'candidate commit moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse HEAD^)" = "$CANDIDATE_PARENT" ] ||
	die 'candidate is not a direct E3 child'
[ "$(git -C "$CANDIDATE_DIR" rev-parse 'HEAD^{tree}')" = \
	"$CANDIDATE_TREE" ] || die 'candidate tree moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse "$CANDIDATE_BRANCH")" = \
	"$CANDIDATE_COMMIT" ] || die 'local candidate branch moved'
[ "$(git -C "$CANDIDATE_DIR" rev-parse \
	"refs/remotes/fork/$CANDIDATE_BRANCH")" = "$CANDIDATE_COMMIT" ] ||
	die 'fork-tracking candidate branch moved'
[ -z "$(git -C "$CANDIDATE_DIR" status --porcelain)" ] ||
	die 'candidate worktree is dirty'
git -C "$CANDIDATE_DIR" log -1 --format=%B |
	grep -Eq '^Signed-off-by: .+ <.+>$' ||
	die 'candidate lacks sign-off'
[ "$(git -C "$PRIMARY_DIR" rev-parse upstream/master)" = \
	"$CURRENT_UPSTREAM" ] || die 'local upstream observation moved'
if [ "$OFFLINE_TEST_MODE" = 0 ]; then
	remote_tip=$(git -C "$PRIMARY_DIR" ls-remote upstream \
		refs/heads/master | awk 'NR == 1 {print $1}')
	[ "$remote_tip" = "$CURRENT_UPSTREAM" ] ||
		die 'upstream advanced after source contract'
fi
[ "$(git -C "$PRIMARY_DIR" rev-list --count \
	"$PREVIOUS_UPSTREAM..$CURRENT_UPSTREAM")" = 48 ] ||
	die 'upstream advance count moved'
git -C "$PRIMARY_DIR" diff --name-only \
	"$PREVIOUS_UPSTREAM..$CURRENT_UPSTREAM" -- \
	init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/upstream-candidate-paths.txt"
[ ! -s "$OUT_DIR/upstream-candidate-paths.txt" ] ||
	die 'candidate path changed upstream'
[ "$(git -C "$PRIMARY_DIR" merge-base "$CANDIDATE_COMMIT" \
	"$CURRENT_UPSTREAM")" = \
	"4edcdefd4083ae04b1a5656f4be6cd83ae919ef4" ] ||
	die 'candidate/upstream merge base moved'

progress '22% checking exact two-file source, configuration, and style'
git -C "$CANDIDATE_DIR" diff --check \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT"
git -C "$CANDIDATE_DIR" diff --name-only \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" |
	sort > "$OUT_DIR/changed-files.txt"
printf '%s\n' init/Kconfig kernel/sched/exec_lease.c \
	> "$OUT_DIR/expected-files.txt"
diff -u "$OUT_DIR/expected-files.txt" "$OUT_DIR/changed-files.txt" ||
	die 'candidate escaped the exact two-file boundary'
[ "$(git -C "$CANDIDATE_DIR" diff --numstat \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" |
	awk '{a += $1; d += $2} END {print a+0, d+0}')" = '1994 38' ] ||
	die 'candidate line delta moved'
git -C "$CANDIDATE_DIR" diff --binary \
	"$CANDIDATE_PARENT..$CANDIDATE_COMMIT" -- \
	init/Kconfig kernel/sched/exec_lease.c > "$OUT_DIR/source.diff"
[ "$(sha256sum "$OUT_DIR/source.diff" | awk '{print $1}')" = \
	"$CANDIDATE_DIFF_SHA" ] || die 'candidate diff hash moved'
git -C "$CANDIDATE_DIR" show \
	"$CANDIDATE_COMMIT:kernel/sched/exec_lease.c" \
	> "$OUT_DIR/exec_lease.c"
[ "$(sha256sum "$OUT_DIR/exec_lease.c" | awk '{print $1}')" = \
	"$CANDIDATE_SOURCE_SHA" ] || die 'candidate source hash moved'
git -C "$CANDIDATE_DIR" show "$CANDIDATE_COMMIT:init/Kconfig" |
	sed -n \
	'/^config SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST$/,/^config /p' \
	> "$OUT_DIR/e4-kconfig.txt"
[ "$(sha256sum "$OUT_DIR/e4-kconfig.txt" | awk '{print $1}')" = \
	"$CANDIDATE_KCONFIG_SHA" ] || die 'candidate Kconfig block moved'
"$CANDIDATE_DIR/scripts/checkpatch.pl" --strict --no-tree --show-types \
	"$OUT_DIR/source.diff" > "$OUT_DIR/checkpatch.log" 2>&1
grep -q '^total: 0 errors, 0 warnings, 0 checks,' \
	"$OUT_DIR/checkpatch.log" || die 'strict checkpatch is not 0/0/0'

SOURCE="$OUT_DIR/exec_lease.c"
grep -qx $'\tdepends on SCHED_EXEC_LEASE_R6_KUNIT_TEST && KUNIT=y' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 dependency changed'
grep -qx $'\tdefault n' "$OUT_DIR/e4-kconfig.txt" ||
	die 'E4 is not default-off'
! grep -Eq 'default y|select SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST' \
	"$OUT_DIR/e4-kconfig.txt" || die 'E4 has an implicit enable path'
grep -q '^#define SCHED_EXEC_R6_MEASURE_WARMUP_PAIRS[[:space:]]*256$' \
	"$SOURCE" || die 'warm-up count changed'
grep -q '^#define SCHED_EXEC_R6_MEASURE_PAIRS[[:space:]]*10000$' \
	"$SOURCE" || die 'pair count changed'
grep -q '^#define SCHED_EXEC_R6_MEASURE_BASE_SLICE_NS[[:space:]]*700000ULL$' \
	"$SOURCE" || die 'base-slice rejection marker changed'
grep -q $'^\t.name = "sched_exec_lease_r6_measure",$' "$SOURCE" ||
	die 'measurement suite name changed'
grep -q '^kunit_test_suite(sched_exec_r6_measure_test_suite);$' "$SOURCE" ||
	die 'measurement suite registration missing'
[ "$(sed -n \
	'/static struct kunit_case sched_exec_r6_measure_test_cases/,/^};/p' \
	"$SOURCE" | grep -c 'KUNIT_CASE(sched_exec_r6_measure_')" = 9 ] ||
	die 'measurement family case count changed'
for row in \
	'rows, 135U' 'rows, 80U' 'rows, 120U' 'rows, 96U' \
	'rows, 54U' 'rows, 100U'; do
	grep -Fq "$row" "$SOURCE" || die "missing exact family row: $row"
done
grep -Fq '? 180U : 45U' "$SOURCE" ||
	die 'aggregate/candidate/complete row contract changed'
grep -Fq 'R6_E4_RAW family=%s %s pair=%u control_ns=%llu treatment_ns=%llu additional_ns=%llu availability_ns=%llu' \
	"$SOURCE" || die 'exact raw row format missing'
grep -Fq 'arrays->treatment[i] > arrays->control[i] ?' "$SOURCE" ||
	die 'non-negative additional formula changed'
grep -Fq 'sched_exec_r6_test_aggregate(core, mask)' "$SOURCE" ||
	die 'shared aggregate helper missing'
grep -Fq 'sched_exec_r6_test_pick_domain(core, mask)' "$SOURCE" ||
	die 'shared candidate helper missing'
grep -Fq 'sched_exec_r6_reconcile_locked(core' "$SOURCE" ||
	die 'shared reconciliation helper missing'
grep -Fq 'sched_exec_r6_test_task_valid_counted' "$SOURCE" ||
	die 'counted final-task helper missing'
grep -Fq 'eevdf_inside_interval=0' "$SOURCE" ||
	die 'truthful EEVDF exclusion marker missing'
grep -Fq 'local_clock()' "$SOURCE" || die 'local_clock measurement missing'
grep -Fq 'raw_spin_lock_irqsave(&fixture->core.lock' "$SOURCE" ||
	die 'raw-lock measurement shell missing'
grep -Fq 'control.logical_operations' "$SOURCE" ||
	die 'zero-operation control check missing'
while IFS= read -r pattern; do
	if sed -n '/^+[^+]/p' "$OUT_DIR/source.diff" |
		grep -F "$pattern" > "$OUT_DIR/forbidden-hit.txt"; then
		die "forbidden added surface: $pattern"
	fi
done < <(jq -r '.forbidden_added_patterns[]' "$CONFIG")

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	progress '100% exact source-gate preflight passed'
	exit 0
fi

prepare_config()
{
	local arch=$1 cross=$2 mode=$3 out=$4 label=$5

	mkdir -p "$out"
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" defconfig \
		> "$OUT_DIR/$label-defconfig.log" 2>&1
	case "$mode" in
	e3_on_e4_off|e4_on)
		"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
			-e EXPERT -e SMP -e CGROUPS -e CGROUP_SCHED \
			-e FAIR_GROUP_SCHED -d SCHED_AUTOGROUP \
			-e SCHED_EXEC_LEASE -e DEBUG_KERNEL \
			-e SCHED_EXEC_LEASE_LAYOUT_PROBE \
			-e SCHED_EXEC_LEASE_R6_LAYOUT_PROBE \
			-e KUNIT -d KUNIT_ALL_TESTS \
			-e SCHED_EXEC_LEASE_R6_KUNIT_TEST \
			-e DEBUG_INFO_NONE
		if [ "$mode" = e4_on ]; then
			"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
				-e SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST
		else
			"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
				-d SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST
		fi
		;;
	release_normal)
		"$CANDIDATE_DIR/scripts/config" --file "$out/.config" \
			-d SCHED_EXEC_LEASE \
			-d SCHED_EXEC_LEASE_LAYOUT_PROBE \
			-d SCHED_EXEC_LEASE_R6_LAYOUT_PROBE \
			-d SCHED_EXEC_LEASE_R6_KUNIT_TEST \
			-d SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST \
			-d KUNIT_ALL_TESTS -e DEBUG_INFO_NONE
		;;
	*) die "unknown build mode: $mode" ;;
	esac
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" olddefconfig \
		> "$OUT_DIR/$label-olddefconfig.log" 2>&1
	cp -- "$out/.config" "$OUT_DIR/$label.config"
}

build_mode()
{
	local arch=$1 cross=$2 mode=$3 out=$4 label=$5
	local target log="$OUT_DIR/$label-build.log"

	if [ "$mode" = release_normal ]; then
		target=kernel/sched/
	else
		target='kernel/sched/exec_lease.o kernel/sched/exec_lease_layout_probe.o'
	fi
	# shellcheck disable=SC2086
	make -C "$CANDIDATE_DIR" O="$out" ARCH="$arch" \
		CROSS_COMPILE="$cross" W=1 -j"$JOBS" $target \
		> "$log" 2>&1
	! grep -Eq ':[0-9]+(:[0-9]+)?: (fatal )?(warning|error):' "$log" ||
		die "$label compiler diagnostic"
	if [ "$mode" = release_normal ]; then
		[ ! -e "$out/kernel/sched/exec_lease.o" ] ||
			die "$label emitted release exec_lease.o"
	else
		[ -s "$out/kernel/sched/exec_lease.o" ] ||
			die "$label missing exec_lease.o"
		[ -s "$out/kernel/sched/exec_lease_layout_probe.o" ] ||
			die "$label missing layout probe object"
	fi
}

extract_symbols()
{
	local nm_command=$1 object=$2 prefix=$3 output=$4

	"$nm_command" -S "$object" |
		awk -v prefix="$prefix" \
			'$4 ~ ("^" prefix) {print $4 "\t" $2}' |
		sort -k1 > "$output"
}

validate_arch()
{
	local label=$1 arch=$2 cross=$3 nm_command=$4
	local readelf_command=$5 compiler=$6 percent=$7
	local arch_dir="$OUT_DIR/$label" root="$BUILD_ROOT/$label"
	local mode out
	local off_object="$root/e3_on_e4_off/kernel/sched/exec_lease.o"
	local on_object="$root/e4_on/kernel/sched/exec_lease.o"

	mkdir "$arch_dir"
	for mode in e3_on_e4_off e4_on release_normal; do
		out="$root/$mode"
		progress "$percent% $label $mode fresh W=1 build"
		prepare_config "$arch" "$cross" "$mode" "$out" "$label-$mode"
		build_mode "$arch" "$cross" "$mode" "$out" "$label-$mode"
	done

	extract_symbols "$nm_command" "$off_object" sched_exec_r6l_ \
		"$arch_dir/off-private.tsv"
	extract_symbols "$nm_command" "$on_object" sched_exec_r6l_ \
		"$arch_dir/on-private.tsv"
	[ "$(wc -l < "$arch_dir/off-private.tsv" | tr -d ' ')" = 49 ] ||
		die "$label private layout count changed"
	cmp "$arch_dir/off-private.tsv" "$arch_dir/on-private.tsv" ||
		die "$label E4 changed private layout values"
	extract_symbols "$nm_command" \
		"$root/e3_on_e4_off/kernel/sched/exec_lease_layout_probe.o" \
		sched_exec_lp_ "$arch_dir/off-expanded.tsv"
	extract_symbols "$nm_command" \
		"$root/e4_on/kernel/sched/exec_lease_layout_probe.o" \
		sched_exec_lp_ "$arch_dir/on-expanded.tsv"
	[ "$(wc -l < "$arch_dir/off-expanded.tsv" | tr -d ' ')" = 51 ] ||
		die "$label expanded layout count changed"
	cmp "$arch_dir/off-expanded.tsv" "$arch_dir/on-expanded.tsv" ||
		die "$label E4 changed expanded layout values"

	"$nm_command" -a "$off_object" > "$arch_dir/off-nm.txt"
	"$readelf_command" -rW "$off_object" > "$arch_dir/off-relocations.txt"
	"$readelf_command" -SW "$off_object" > "$arch_dir/off-sections.txt"
	strings -a "$off_object" > "$arch_dir/off-strings.txt"
	for pattern in sched_exec_r6_measure_ sched_exec_lease_r6_measure \
		R6_E4_RAW R6_E4_RESULT R6_E4_SUMMARY; do
		! grep -Fq "$pattern" "$arch_dir/off-nm.txt" ||
			die "$label disabled object has E4 symbol: $pattern"
		! grep -Fq "$pattern" "$arch_dir/off-relocations.txt" ||
			die "$label disabled object has E4 relocation: $pattern"
		! grep -Fq "$pattern" "$arch_dir/off-strings.txt" ||
			die "$label disabled object has E4 string: $pattern"
	done

	"$nm_command" -a "$on_object" > "$arch_dir/on-nm.txt"
	"$readelf_command" -SW "$on_object" > "$arch_dir/on-sections.txt"
	strings -a "$on_object" > "$arch_dir/on-strings.txt"
	grep -q 'sched_exec_r6_measure_test_suite' "$arch_dir/on-nm.txt" ||
		die "$label enabled suite symbol missing"
	grep -qx 'sched_exec_lease_r6_measure' "$arch_dir/on-strings.txt" ||
		die "$label enabled suite string missing"
	for family in publication leaf aggregate candidate complete reconcile \
		handoff current offline; do
		grep -q "sched_exec_r6_measure_${family}_case" \
			"$arch_dir/on-nm.txt" ||
			die "$label missing enabled family: $family"
	done
	grep -Fq 'R6_E4_RAW family=' "$arch_dir/on-strings.txt" ||
		die "$label raw format missing"
	grep -Fq 'R6_E4_RESULT family=' "$arch_dir/on-strings.txt" ||
		die "$label result format missing"
	grep -Fq 'eevdf_inside_interval=0' "$arch_dir/on-strings.txt" ||
		die "$label EEVDF exclusion string missing"
	grep -q 'sched_exec_r6_correctness_test_suite' "$arch_dir/on-nm.txt" ||
		die "$label E3 suite missing from E4 object"

	cp -- "$off_object" "$OUT_DIR/artifacts/$label-e3-on-e4-off.o"
	cp -- "$on_object" "$OUT_DIR/artifacts/$label-e4-on.o"
	chmod 0444 "$OUT_DIR/artifacts/$label-e3-on-e4-off.o" \
		"$OUT_DIR/artifacts/$label-e4-on.o"

	jq -n \
		--arg architecture "$label" \
		--arg compiler_machine "$("$compiler" -dumpmachine)" \
		--arg compiler_version \
			"$("$compiler" -dumpfullversion -dumpversion)" \
		--arg off_sha "$(sha256sum "$off_object" | awk '{print $1}')" \
		--arg on_sha "$(sha256sum "$on_object" | awk '{print $1}')" \
		'{
		  status:"passed",
		  architecture:$architecture,
		  compiler:{
		    machine:$compiler_machine,
		    version:$compiler_version
		  },
		  fresh_modes:[
		    "e3_on_e4_off",
		    "e4_on",
		    "release_normal"
		  ],
		  e3_on_e4_off_object_sha256:$off_sha,
		  e4_on_object_sha256:$on_sha,
		  private_layout_values_preserved:49,
		  expanded_layout_values_preserved:51,
		  disabled_e4_artifacts:0,
		  enabled_measurement_families:9,
		  w1_diagnostics:0
		}' > "$arch_dir/result.json"
}

validate_arch arm64 arm64 '' nm readelf gcc 34
validate_arch x86_64 x86_64 x86_64-linux-gnu- \
	x86_64-linux-gnu-nm x86_64-linux-gnu-readelf \
	x86_64-linux-gnu-gcc 62

progress '92% sealing scoped source/build-gate result'
capsched_verify_file_sha256 "$RUNNER_SOURCE" "$runner_initial_sha" ||
	die 'runner changed during execution'
capsched_verify_file_sha256 "$INPUT_DIR/runner.sh" "$runner_initial_sha" ||
	die 'runner snapshot changed'
capsched_verify_file_sha256 "$CONFIG" "$EXPECTED_CONFIG_SHA" ||
	die 'config snapshot changed'
capsched_verify_file_sha256 "$IMPLEMENTATION" "$IMPLEMENTATION_SHA" ||
	die 'implementation record changed'

jq -n \
	--arg run_id "$RUN_ID" \
	--arg runner_sha "$runner_initial_sha" \
	--arg config_sha "$EXPECTED_CONFIG_SHA" \
	--arg candidate "$CANDIDATE_COMMIT" \
	--arg tree "$CANDIDATE_TREE" \
	--arg diff_sha "$CANDIDATE_DIFF_SHA" \
	--arg upstream "$CURRENT_UPSTREAM" \
	--slurpfile arm64 "$OUT_DIR/arm64/result.json" \
	--slurpfile x86 "$OUT_DIR/x86_64/result.json" \
	'{
	  id:"sched-exec-lease-p5a-r6-e4-local-quantum-source-gate-result-v1",
	  schema_version:1,
	  run_id:$run_id,
	  status:"passed_r6_e4_source_build_gate",
	  runner_sha256:$runner_sha,
	  contract_sha256:$config_sha,
	  candidate_commit:$candidate,
	  candidate_tree:$tree,
	  candidate_diff_sha256:$diff_sha,
	  current_upstream_commit:$upstream,
	  upstream_advance_commits:48,
	  upstream_candidate_path_changes:[],
	  changed_files:["init/Kconfig","kernel/sched/exec_lease.c"],
	  direct_e3_child:true,
	  signed_off:true,
	  strict_checkpatch:{errors:0,warnings:0,checks:0},
	  fresh_builds:6,
	  architectures:{
	    arm64:$arm64[0],
	    x86_64:$x86[0]
	  },
	  matrix_cells:855,
	  total_measured_pairs:8550000,
	  exact_raw_rows_implemented:true,
	  disabled_e4_artifacts:0,
	  e3_shared_helpers_changed:true,
	  source_build_gate_passed:true,
	  e3_four_profile_regression_required:true,
	  e3_four_profile_regression_passed:false,
	  r6_e4_source_accepted:false,
	  measurement_authorized:false,
	  runtime_scheduler_attachment:false,
	  monitor_verified:false,
	  bare_metal_validated:false,
	  performance_claim:false,
	  cost_claim:false,
	  production_protection:false,
	  deployment_ready:false,
	  multi_node_ready:false,
	  multi_cluster_ready:false,
	  datacenter_ready:false
	}' > "$OUT_DIR/result.json"

chmod -R a-w "$OUT_DIR"
progress '100% R6-E4 source/build gate passed; E3 regression only is next'
