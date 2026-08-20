#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
SOURCE_RUN_ID=20260723T-p5a-r4-e4-arm64-timing-r7
CANONICAL_SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement/$SOURCE_RUN_ID"
CANONICAL_JOB_DIR="$WORKSPACE_DIR/build/long-jobs/p5a-r4-e4-arm64-timing-r7"
RUNNER_SOURCE=${BASH_SOURCE[0]}
RUN_ID=${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
PROGRESS_FILE=${PROGRESS_FILE:-}
CLOSURE_TEST_MODE=${CLOSURE_TEST_MODE:-0}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
SOURCE_OVERRIDE=${SOURCE_OVERRIDE:-}
JOB_OVERRIDE=${JOB_OVERRIDE:-}

if [ "$CLOSURE_TEST_MODE" = 1 ]; then
	[ "$PREFLIGHT_ONLY" = 1 ] ||
		{ printf 'error: test mode requires PREFLIGHT_ONLY=1\n' >&2; exit 1; }
	[ -n "$SOURCE_OVERRIDE" ] ||
		{ printf 'error: test mode requires SOURCE_OVERRIDE\n' >&2; exit 1; }
	[ -n "$JOB_OVERRIDE" ] ||
		{ printf 'error: test mode requires JOB_OVERRIDE\n' >&2; exit 1; }
	SOURCE_DIR=$SOURCE_OVERRIDE
	JOB_DIR=$JOB_OVERRIDE
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r7-valid-negative-closure-test"
else
	[ "$PREFLIGHT_ONLY" = 0 ] ||
		{ printf 'error: PREFLIGHT_ONLY is restricted to test mode\n' >&2; exit 1; }
	[ -z "$SOURCE_OVERRIDE$JOB_OVERRIDE" ] ||
		{ printf 'error: overrides are restricted to test mode\n' >&2; exit 1; }
	SOURCE_DIR=$CANONICAL_SOURCE_DIR
	JOB_DIR=$CANONICAL_JOB_DIR
	OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-arm64-timing-r7-valid-negative-closure"
fi

OUT_DIR="$OUT_ROOT/$RUN_ID"
INPUT_DIR="$OUT_DIR/inputs"
EVIDENCE_DIR="$INPUT_DIR/timing-r7"
JOB_EVIDENCE_DIR="$INPUT_DIR/job-control"
RECOMPUTED_DIR="$OUT_DIR/recomputed"

RESULT_SHA=edb07251794914381433d4ff221753c4b038afe6b02e969f2ad93d67860a0951
SOURCE_MANIFEST_SHA=1e9a8548d5bc34bd472ff074c1661de0532e46573ed3879376d1de6d1a2e5721
SOURCE_FILES=58
SOURCE_BYTES=35356293
JOB_MANIFEST_SHA=dcb05d277ec22ec30f005e757ce5c379f2661ed10793eee77b0126ed8779e12e
JOB_FILES=27
JOB_BYTES=40130
RAW_MANIFEST_SHA=dac6a9cd4ce6e196f0ecc98f5577c54a9113ab5705ef9641e23195b8bcc42c8e
DERIVED_MANIFEST_SHA=5939541da45d45fcd66758952715f6b35cd5a95b7ef2e7fd4d8210c2b93f10d1
RUNNER_SHA=54e1ee16fdd55c57e306ecb582420455c6e088ac150c39b3f66c8432439a8a50
PARSER_SHA=dd0372d385bbc0a84c6faedf67ee3596f4766205a125c44e33b9a91652bc2cd1
WARNING_CLASSIFIER_SHA=8adcff74f0395f5ec219343c0cb5b1f179efee2292ab853d4fc7e410467dc23a
QMP_CONTROL_SHA=e59bc8ad5adb50ddf66652b28a424afd1efbd28a9501e786771d5fb1f8da147e
CONFIG_SHA=2cbf3e910322ee65f39074a551fd61a14cbe457608358e6a76608ae6d25cf07b
SERIAL_SHA=d775a9f67d310d84b0ffe4519aee99b375c72841629327f4f75f39c2441eb378
KTAP_SHA=e78c1f9a29632a43809048b39666e1af39197dd169b6adc65e28ce55a7fa8ad3
ROWS_SHA=a2e08f36c88107e07fa0ac051ab32f5dca52afed273ac7c3c7aed2caf525d7f7
SUMMARIES_SHA=1c77588a35eb5a19895a41ffcfd04d5eb822b6e280988c37ceec2fd3ba712faf
MEASUREMENTS_SHA=f5b9f528cbaa452b40a8b773a3fbb150eb75797c278dc232acfb69d185f2a969
DERIVED_RESULT_SHA=db6554cf9e136ebb7511f120abab7944e2ff99df5dfab6d51b93eff9c1ef53de
THRESHOLD_JSON_SHA=d6568d4f8b623b5a5631fb0a85a30fb568d4e474155c6c5ce31f124ffc94408b
THRESHOLD_TSV_SHA=50182dc03e439cacbece2ae168d57124f22364a817bc2498931a365f43d697f3
PINNING_SHA=854a528af21f421d843f9ae86b58bb1c5d5058257dbf45e349a6e8973f63ffd0
QMP_MAPPING_SHA=6bbb781e4cdf5c60fb786419e506413caab2d0ed1fc38e551b33e5954c1a2870
QMP_AFFINITY_SHA=f221bbc99fefb02cc3b0cc8435d9e30b5374836fb3e3ae73cbf6e55fe19f51b5
IMAGE_SOURCE_SHA=8366912940797e067b7ad48d59561b20af1a7900c09eec389de21777b31daf74
IMAGE_ARCHIVE_SHA=4616a486848f69cd261b8add145bd600caa7020b9122609f85808e01215b0415
OBJECT_SOURCE_SHA=b138644d067a317b78ca1ca70591ad272346490821cfee67ec4b1d7734365125
OBJECT_ARCHIVE_SHA=ff9bb864330a41d707f310a853deb352f9f041e5fac44caea1c6021e3ede4484
BUILD_ROOT=/var/tmp/linux-cap-builds/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID
WORKTREE=/var/tmp/linux-cap-worktrees/p5a-r4-e4-arm64-measurement/$SOURCE_RUN_ID

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

file_sha()
{
	sha256sum "$1" | awk '{print $1}'
}

tree_manifest()
{
	(
		cd "$1"
		find . -type f -print0 | sort -z | xargs -0 sha256sum
	)
}

tree_bytes()
{
	find "$1" -type f -printf '%s\n' |
		awk '{sum += $1} END {printf "%.0f\n", sum}'
}

verify_hash()
{
	local file=$1 expected=$2 label=$3

	[ -f "$file" ] || die "$label missing"
	[ ! -L "$file" ] || die "$label is a symlink"
	[ "$(file_sha "$file")" = "$expected" ] || die "$label hash changed"
}

case "$RUN_ID" in
	[A-Za-z0-9]*) ;;
	*) die 'RUN_ID must begin with an alphanumeric character' ;;
esac
case "$RUN_ID" in
	*[!A-Za-z0-9._-]*|.|..) die 'RUN_ID contains an unsafe component' ;;
esac
case "$CLOSURE_TEST_MODE:$PREFLIGHT_ONLY" in
	0:0|1:1) ;;
	*) die 'invalid closure mode' ;;
esac
for command in awk bash chmod cmp cp find grep jq mkdir sha256sum sort \
	stat tr wc xargs zstd; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
if [ -e "$OUT_DIR" ] || [ -L "$OUT_DIR" ]; then
	die "run output already exists: $OUT_DIR"
fi
for source_root in "$SOURCE_DIR" "$JOB_DIR"; do
	if [ ! -d "$source_root" ] || [ -L "$source_root" ]; then
		die "unsafe source root: $source_root"
	fi
	[ -z "$(find "$source_root" -type l -print -quit)" ] ||
		die "source root contains a symlink: $source_root"
	[ -z "$(find "$source_root" ! -type f ! -type d -print -quit)" ] ||
		die "source root contains a non-regular object: $source_root"
done

mkdir -p "$OUT_ROOT"
mkdir "$OUT_DIR" "$INPUT_DIR" "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"
chmod 0700 "$OUT_DIR" "$INPUT_DIR"
runner_initial_sha=$(file_sha "$RUNNER_SOURCE")
cp -- "$RUNNER_SOURCE" "$INPUT_DIR/closure-runner.sh"
chmod 0444 "$INPUT_DIR/closure-runner.sh"

progress '8% snapshotting exact timing r7 and job-control evidence with race checks'
[ "$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')" = "$SOURCE_FILES" ] ||
	die 'timing r7 artifact count changed'
[ "$(tree_bytes "$SOURCE_DIR")" = "$SOURCE_BYTES" ] ||
	die 'timing r7 artifact byte count changed'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-before.sha256"
[ "$(file_sha "$OUT_DIR/source-before.sha256")" = "$SOURCE_MANIFEST_SHA" ] ||
	die 'timing r7 artifact manifest changed'
[ "$(find "$JOB_DIR" -type f | wc -l | tr -d ' ')" = "$JOB_FILES" ] ||
	die 'timing r7 job file count changed'
[ "$(tree_bytes "$JOB_DIR")" = "$JOB_BYTES" ] ||
	die 'timing r7 job byte count changed'
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-before.sha256"
[ "$(file_sha "$OUT_DIR/job-before.sha256")" = "$JOB_MANIFEST_SHA" ] ||
	die 'timing r7 job manifest changed'
cp -a -- "$SOURCE_DIR/." "$EVIDENCE_DIR/"
cp -a -- "$JOB_DIR/." "$JOB_EVIDENCE_DIR/"
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-after.sha256"
tree_manifest "$EVIDENCE_DIR" > "$OUT_DIR/source-snapshot.sha256"
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-after.sha256"
tree_manifest "$JOB_EVIDENCE_DIR" > "$OUT_DIR/job-snapshot.sha256"
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-after.sha256" >/dev/null ||
	die 'timing r7 source changed while snapshotting'
cmp "$OUT_DIR/source-before.sha256" "$OUT_DIR/source-snapshot.sha256" >/dev/null ||
	die 'timing r7 source snapshot differs'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-after.sha256" >/dev/null ||
	die 'timing r7 job control changed while snapshotting'
cmp "$OUT_DIR/job-before.sha256" "$OUT_DIR/job-snapshot.sha256" >/dev/null ||
	die 'timing r7 job-control snapshot differs'
chmod -R a-w "$EVIDENCE_DIR" "$JOB_EVIDENCE_DIR"

progress '25% validating nested manifests, source identity, and terminal semantics'
RESULT="$EVIDENCE_DIR/result.json"
RAW="$EVIDENCE_DIR/raw"
DERIVED="$EVIDENCE_DIR/derived"
verify_hash "$RESULT" "$RESULT_SHA" 'timing r7 result'
[ "$(awk 'NF {print $1; exit}' "$EVIDENCE_DIR/result.sha256")" = "$RESULT_SHA" ] ||
	die 'timing r7 result seal changed'
verify_hash "$RAW/raw-manifest.sha256" "$RAW_MANIFEST_SHA" 'raw manifest'
[ "$(wc -l < "$RAW/raw-manifest.sha256" | tr -d ' ')" = 46 ] ||
	die 'raw manifest cardinality changed'
(cd "$RAW" && sha256sum -c raw-manifest.sha256 >/dev/null) ||
	die 'raw internal manifest verification failed'
verify_hash "$EVIDENCE_DIR/derived-manifest.sha256" "$DERIVED_MANIFEST_SHA" \
	'derived manifest'
[ "$(wc -l < "$EVIDENCE_DIR/derived-manifest.sha256" | tr -d ' ')" = 8 ] ||
	die 'derived manifest cardinality changed'
(cd "$DERIVED" && sha256sum -c ../derived-manifest.sha256 >/dev/null) ||
	die 'derived internal manifest verification failed'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-arm64-local-quantum-measurement-result-v1" and
  .run_id == "20260723T-p5a-r4-e4-arm64-timing-r7" and
  .status == "rejected_r4_local_quantum_measurement" and
  .architecture == "arm64" and .architecture_measurement_valid == true and
  .source.commit == "4077ba840f713979c29af64f405dbde39f845d93" and
  .source.parent == "da9ce9159b3450c28c8faf8dceac671fb7bfeba2" and
  .source.tree == "6ce127d738618fd356ed3533ac32e5796fa72d55" and
  .source.diff_sha256 == "a4886479f001ea3ef0dbc069ef44040f89df69cc9114421933a5592075bfe255" and
  .prerequisites.independent_double_closure_passed == true and
  .prerequisites.closure_normalized_sha256 == "f8e184c16c4fa5315532cb067d3b66dea3a21b277942d9728a2132384a3d4ba2" and
  .prerequisites.r6_failure_independently_closed == true and
  .prerequisites.r6_failure_closure_normalized_sha256 == "1ed1c74331eb818ea355a6c8c3d7daa03362cc8d79c8e43a236d3b49757a3c3f" and
  .matrix.result_rows == 682 and .matrix.total_cells == 682 and
  .matrix.total_measured_pairs == 6820000 and .matrix.measured_pairs_per_cell == 10000 and
  .parser.rejected_cells == 362 and .parser.threshold_breaches == 692 and
  .parser.malformed_or_missing_rows == 0 and
  .parser.duplicate_or_unexpected_cells == 0 and
  .parser.summary_mismatches == 0 and .parser.harness_observation_failures == 0 and
  .diagnostics.kunit_suite_passed == true and
  .diagnostics.kunit_cases_passed == 7 and .diagnostics.kunit_cases_failed == 0 and
  .diagnostics.kunit_cases_skipped == 0 and .diagnostics.qemu_exit_code == 0 and
  .diagnostics.compiler_diagnostics == 0 and
  .diagnostics.kernel_warning_reports == 0 and .diagnostics.clock_skew_reports == 0 and
  .placement.qemu_vcpu_threads_pinned == 2 and
  .placement.qmp_pause_before_affinity == true and
  .placement.qmp_mapping_reverified_before_resume == true and
  .placement.rows_before_all_vcpus_pinned == 0 and
  .artifacts.raw_artifact_count == 47 and .artifacts.derived_artifact_count == 8 and
  .artifacts.raw_manifest_sha256 == "dac6a9cd4ce6e196f0ecc98f5577c54a9113ab5705ef9641e23195b8bcc42c8e" and
  .artifacts.derived_manifest_sha256 == "5939541da45d45fcd66758952715f6b35cd5a95b7ef2e7fd4d8210c2b93f10d1" and
  .artifacts.raw_inputs_read_only == true and .artifacts.derived_outputs_read_only == true and
  .artifacts.build_output_retired == true and .artifacts.worktree_retired == true and
  .threshold_failure_is_valid_negative_evidence == true and
  .x86_64_measurement_may_start == false and .e5_plan_may_start == false and
  .e5_source_may_start == false and .measurement_result_accepted == false and
  .real_scheduler_attachment == false and .runtime_behavior_approved == false and
  .performance_claim == false and .cost_claim == false and
  .bare_metal_validated == false and .production_protection == false and
  .deployment_ready == false and .multi_node_ready == false and
  .multi_cluster_ready == false and .datacenter_ready == false
' "$RESULT" >/dev/null || die 'timing r7 terminal semantic contract changed'

progress '43% independently rerunning the snapshotted parser and exact comparisons'
verify_hash "$RAW/measurement-runner.sh" "$RUNNER_SHA" 'timing runner'
verify_hash "$RAW/measurement-parser.sh" "$PARSER_SHA" 'measurement parser'
verify_hash "$RAW/kernel-warning-classifier.sh" "$WARNING_CLASSIFIER_SHA" \
	'warning classifier'
verify_hash "$RAW/qmp-vcpu-control.py" "$QMP_CONTROL_SHA" 'QMP helper'
verify_hash "$RAW/arm64.config" "$CONFIG_SHA" 'arm64 config'
verify_hash "$RAW/qemu-serial.log" "$SERIAL_SHA" 'serial log'
verify_hash "$RAW/qemu-ktap.log" "$KTAP_SHA" 'KTAP log'
verify_hash "$RAW/r4-e4-result-rows.txt" "$ROWS_SHA" 'result rows'
verify_hash "$RAW/r4-e4-summary-rows.txt" "$SUMMARIES_SHA" 'summary rows'
verify_hash "$DERIVED/measurements.tsv" "$MEASUREMENTS_SHA" 'measurement table'
verify_hash "$DERIVED/result.json" "$DERIVED_RESULT_SHA" 'parser result'
verify_hash "$DERIVED/threshold-failures.json" "$THRESHOLD_JSON_SHA" \
	'threshold failures JSON'
verify_hash "$DERIVED/threshold-failures.tsv" "$THRESHOLD_TSV_SHA" \
	'threshold failures TSV'
bash "$RAW/measurement-parser.sh" "$RAW/r4-e4-result-rows.txt" \
	"$RAW/r4-e4-summary-rows.txt" "$RECOMPUTED_DIR" > "$OUT_DIR/parser-recompute.log"
[ "$(find "$RECOMPUTED_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')" = 8 ] ||
	die 'recomputed parser artifact cardinality changed'
while read -r _ relative; do
	relative=${relative#./}
	cmp "$DERIVED/$relative" "$RECOMPUTED_DIR/$relative" >/dev/null ||
		die "parser recomputation differs: $relative"
done < "$EVIDENCE_DIR/derived-manifest.sha256"

progress '61% independently aggregating matrix rejection and threshold distribution'
[ "$(($(wc -l < "$DERIVED/measurements.tsv") - 1))" = 682 ] ||
	die 'measurement table cardinality changed'
[ "$(($(wc -l < "$DERIVED/threshold-failures.tsv") - 1))" = 692 ] ||
	die 'threshold TSV cardinality changed'
[ "$(jq 'length' "$DERIVED/threshold-failures.json")" = 692 ] ||
	die 'threshold JSON cardinality changed'
cmp "$DERIVED/expected-cells.txt" "$DERIVED/actual-cells.txt" >/dev/null ||
	die 'expected and actual cell sets differ'
awk -F '\t' '
	NR == 1 {
		if ($1 != "family" || $NF != "rejected")
			exit 2
		next
	}
	{
		rows[$1]++
		total++
		if ($NF == "reject")
			rejected[$1]++
		else if ($NF != "pass")
			exit 3
	}
	END {
		if (total != 682)
			exit 4
		for (family in rows)
			printf "%s\t%d\t%d\n", family, rows[family], rejected[family] + 0
	}
' "$DERIVED/measurements.tsv" | sort > "$OUT_DIR/family-aggregate.tsv"
cat > "$OUT_DIR/family-expected.tsv" <<'EOF'
current_stop	24	0
irq_dispatch	9	4
notifier	48	48
offline	25	18
picker_kick	144	3
publication	288	184
recovery	144	105
EOF
cmp "$OUT_DIR/family-expected.tsv" "$OUT_DIR/family-aggregate.tsv" >/dev/null ||
	die 'independent family aggregation changed'
jq -r 'group_by(.reason)[] | [.[0].reason,length] | @tsv' \
	"$DERIVED/threshold-failures.json" > "$OUT_DIR/reason-aggregate.tsv"
cat > "$OUT_DIR/reason-expected.tsv" <<'EOF'
additional_max	358
additional_p99	164
additional_p999	160
additional_reached_base_slice	10
EOF
cmp "$OUT_DIR/reason-expected.tsv" "$OUT_DIR/reason-aggregate.tsv" >/dev/null ||
	die 'independent threshold-reason aggregation changed'
jq -e '
  .schema_version == 1 and
  .id == "sched-exec-lease-p5a-r4-e4-measurement-parser-result-v1" and
  .status == "passed_exact_682_cell_parser" and
  .result_rows == 682 and .measured_pairs == 6820000 and
  .rejected_cells == 362 and .threshold_breaches == 692 and
  .malformed_or_missing_rows == 0 and .duplicate_or_unexpected_cells == 0 and
  .summary_mismatches == 0 and .harness_observation_failures == 0 and
  .family_rows == {
    "publication":288,"picker_kick":144,"irq_dispatch":9,"recovery":144,
    "notifier":48,"current_stop":24,"offline":25
  }
' "$DERIVED/result.json" >/dev/null || die 'derived parser contract changed'

progress '76% validating KUnit, diagnostics, QMP placement, and job completion'
[ ! -s "$RAW/compiler-diagnostics.txt" ] || die 'compiler diagnostics are nonempty'
[ ! -s "$RAW/kernel-warning-reports.txt" ] || die 'kernel warning reports are nonempty'
[ ! -s "$RAW/clock-skew-reports.txt" ] || die 'clock-skew reports are nonempty'
[ "$(cat "$RAW/qemu-exit-code.txt")" = 0 ] || die 'QEMU exit changed'
[ "$(grep -c '^not ok ' "$RAW/qemu-ktap.log" || true)" = 0 ] ||
	die 'KTAP contains a failure'
[ "$(grep -c '^ok [1-7] sched_exec_r4_measure_.*_case$' "$RAW/qemu-ktap.log")" = 7 ] ||
	die 'KTAP case cardinality changed'
grep -Fxq '# sched_exec_lease_r4_measure: pass:7 fail:0 skip:0 total:7' \
	"$RAW/qemu-ktap.log" || die 'KTAP suite totals changed'
grep -Fxq 'ok 1 sched_exec_lease_r4_measure' "$RAW/qemu-ktap.log" ||
	die 'KTAP suite terminal changed'
verify_hash "$RAW/vcpu-pinning.txt" "$PINNING_SHA" 'pinning record'
verify_hash "$RAW/qmp-vcpus.txt" "$QMP_MAPPING_SHA" 'QMP mapping'
verify_hash "$RAW/qmp-vcpu-affinity.txt" "$QMP_AFFINITY_SHA" 'QMP affinity'
for anchor in qmp_status_before_resume=prelaunch qmp_mapping_reverified=true \
	singleton_affinity_reverified=true qmp_status_after_resume=running \
	rows_before_all_vcpus_pinned=0 pinned_vcpu_threads=2 \
	qmp_pause_before_affinity=true qmp_mapping_reverified_before_resume=true; do
	grep -Fxq "$anchor" "$RAW/vcpu-pinning.txt" ||
		die "placement proof changed: $anchor"
done
grep -Fxq 'vcpu=0 tid=523660 host_cpu=0' "$RAW/qmp-vcpu-affinity.txt" ||
	die 'vCPU 0 affinity changed'
grep -Fxq 'vcpu=1 tid=523661 host_cpu=1' "$RAW/qmp-vcpu-affinity.txt" ||
	die 'vCPU 1 affinity changed'
[ "$(cat "$JOB_EVIDENCE_DIR/state")" = complete ] || die 'job state changed'
[ "$(cat "$JOB_EVIDENCE_DIR/exit_code")" = 0 ] || die 'job exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_exit_code")" = 0 ] || die 'VM runner exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_pre_run_trim_exit_code")" = 0 ] ||
	die 'pre-run trim exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_preflight_trim_exit_code")" = 0 ] ||
	die 'preflight trim exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/vm_trim_exit_code")" = 0 ] ||
	die 'post-run trim exit changed'
[ "$(cat "$JOB_EVIDENCE_DIR/mode")" = external ] || die 'job mode changed'
[ "$(cat "$JOB_EVIDENCE_DIR/started_at")" = 2026-07-22T21:09:41Z ] ||
	die 'job start changed'
[ "$(cat "$JOB_EVIDENCE_DIR/finished_at")" = 2026-07-23T20:18:17Z ] ||
	die 'job finish changed'
grep -Fxq '100% complete valid negative arm64 evidence; rejected cells=362 breaches=692 warnings=0 skew=0; x86 stopped' \
	"$JOB_EVIDENCE_DIR/progress" || die 'job progress terminal changed'
grep -Fxq 'container machine run --detach -n domainlease-dev --workdir /Users/niania/Documents/linux-cap /Users/niania/Documents/linux-cap/tools/run-p5a-r4-e4-arm64-timing-r7-in-machine.sh' \
	"$JOB_EVIDENCE_DIR/command.txt" || die 'job command changed'

progress '88% losslessly verifying preserved binaries and retired scratch'
verify_hash "$RAW/boot-artifacts/arm64/Image.zst" "$IMAGE_ARCHIVE_SHA" 'Image archive'
verify_hash "$RAW/boot-artifacts/arm64/exec_lease.o.zst" "$OBJECT_ARCHIVE_SHA" \
	'object archive'
zstd -q -t "$RAW/boot-artifacts/arm64/Image.zst"
zstd -q -t "$RAW/boot-artifacts/arm64/exec_lease.o.zst"
[ "$(zstd -q -dc "$RAW/boot-artifacts/arm64/Image.zst" |
	sha256sum | awk '{print $1}')" = "$IMAGE_SOURCE_SHA" ] ||
	die 'Image restore hash changed'
[ "$(zstd -q -dc "$RAW/boot-artifacts/arm64/exec_lease.o.zst" |
	sha256sum | awk '{print $1}')" = "$OBJECT_SOURCE_SHA" ] ||
	die 'object restore hash changed'
for path in "$BUILD_ROOT" "$WORKTREE"; do
	if [ -e "$path" ] || [ -L "$path" ]; then
		die "run-owned scratch leaked: $path"
	fi
done

progress '94% proving original stability and immutable closure inputs'
tree_manifest "$SOURCE_DIR" > "$OUT_DIR/source-final.sha256"
tree_manifest "$JOB_DIR" > "$OUT_DIR/job-final.sha256"
[ "$(file_sha "$OUT_DIR/source-final.sha256")" = "$SOURCE_MANIFEST_SHA" ] ||
	die 'timing r7 source changed during closure'
[ "$(file_sha "$OUT_DIR/job-final.sha256")" = "$JOB_MANIFEST_SHA" ] ||
	die 'timing r7 job control changed during closure'
[ "$(file_sha "$RUNNER_SOURCE")" = "$runner_initial_sha" ] ||
	die 'closure runner changed during audit'
[ "$(file_sha "$INPUT_DIR/closure-runner.sh")" = "$runner_initial_sha" ] ||
	die 'closure runner snapshot changed'
[ -z "$(find "$INPUT_DIR" -type f -perm -222 -print -quit)" ] ||
	die 'closure inputs contain writable files'
chmod -R a-w "$RECOMPUTED_DIR"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
	progress '100% exact fixture accepted in closure test mode'
	exit 0
fi

progress '97% sealing valid negative evidence without performance or x86 credit'
jq -S -n \
	--arg run_id "$RUN_ID" --arg source_run_id "$SOURCE_RUN_ID" \
	--arg source_result_sha "$RESULT_SHA" --arg source_manifest_sha "$SOURCE_MANIFEST_SHA" \
	--arg job_manifest_sha "$JOB_MANIFEST_SHA" --arg closure_runner_sha "$runner_initial_sha" \
	--arg parser_sha "$PARSER_SHA" --arg normalized_source_sha "$DERIVED_RESULT_SHA" \
	--argjson source_files "$SOURCE_FILES" --argjson source_bytes "$SOURCE_BYTES" \
	--argjson job_files "$JOB_FILES" --argjson job_bytes "$JOB_BYTES" '
{
  schema_version:1,
  id:"sched-exec-lease-p5a-r4-e4-arm64-timing-r7-valid-negative-closure-result-v1",
  run_id:$run_id,
  status:"passed_independent_arm64_timing_r7_valid_negative_closure",
  source_run_id:$source_run_id,
  source_result_sha256:$source_result_sha,
  source_artifacts:{files:$source_files,bytes:$source_bytes,manifest_sha256:$source_manifest_sha},
  job_control:{files:$job_files,bytes:$job_bytes,manifest_sha256:$job_manifest_sha,complete:true,exit_code:0,vm_exit_code:0},
  closure_runner_sha256:$closure_runner_sha,
  parser:{snapshot_sha256:$parser_sha,recomputed_outputs_exact:true,result_sha256:$normalized_source_sha},
  matrix:{cells:682,pairs:6820000,rejected_cells:362,threshold_breaches:692,family_rows:{publication:288,picker_kick:144,irq_dispatch:9,recovery:144,notifier:48,current_stop:24,offline:25},family_rejected:{publication:184,picker_kick:3,irq_dispatch:4,recovery:105,notifier:48,current_stop:0,offline:18}},
  threshold_reasons:{additional_max:358,additional_p99:164,additional_p999:160,additional_reached_base_slice:10},
  evidence:{kunit_pass:7,kunit_fail:0,kunit_skip:0,qemu_exit_code:0,compiler_diagnostics:0,kernel_warning_reports:0,clock_skew_reports:0,exact_qmp_placement:true,image_and_object_losslessly_preserved:true},
  original_snapshot_race_free:true,
  snapshot_read_only:true,
  run_owned_build_scratch_retired:true,
  run_owned_worktree_retired:true,
  architecture_measurement_valid:true,
  threshold_failure_is_valid_negative_evidence:true,
  r4_local_quantum_measurement_rejected:true,
  successor_design_required:true,
  x86_64_measurement_may_start:false,
  e5_plan_may_start:false,
  e5_source_may_start:false,
  measurement_result_accepted:false,
  real_scheduler_attachment:false,
  runtime_behavior_approved:false,
  performance_claim:false,
  cost_claim:false,
  bare_metal_validated:false,
  production_protection:false,
  deployment_ready:false,
  multi_node_ready:false,
  multi_cluster_ready:false,
  datacenter_ready:false
}' > "$OUT_DIR/result.json"
file_sha "$OUT_DIR/result.json" > "$OUT_DIR/result.sha256"
jq -S 'del(.run_id)' "$OUT_DIR/result.json" > "$OUT_DIR/result.normalized.json"
file_sha "$OUT_DIR/result.normalized.json" > "$OUT_DIR/result.normalized.sha256"
progress '100% r7 valid negative independently closed; successor redesign required'
printf 'result=%s\nsha256=%s\nnormalized_sha256=%s\n' \
	"$OUT_DIR/result.json" "$(cat "$OUT_DIR/result.sha256")" \
	"$(cat "$OUT_DIR/result.normalized.sha256")"
