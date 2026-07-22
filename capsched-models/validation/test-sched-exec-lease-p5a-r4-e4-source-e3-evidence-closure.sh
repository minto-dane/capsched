#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CAPSCHED_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR=$(cd "$CAPSCHED_DIR/.." && pwd)
RUNNER="$SCRIPT_DIR/run-sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure.sh"
SOURCE_RUN_ID=20260721T-p5a-r4-e4-coalesced-owner-source-e3-regression-r5
COMBINED_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-and-e3-regression/$SOURCE_RUN_ID"
SOURCE_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-local-quantum-source-gate/$SOURCE_RUN_ID-source"
CONFIG_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$SOURCE_RUN_ID-config-smoke"
REGRESSION_DIR="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-e3-six-profile-regression/$SOURCE_RUN_ID-e3-regression"
OUT_ROOT="$WORKSPACE_DIR/build/source-check/sched-exec-lease-p5a-r4-e4-source-e3-evidence-closure-test"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/r4-e4-closure-test.XXXXXX")

cleanup()
{
	local out

	for out in "$OUT_ROOT"/closure-test-*-"$$"; do
		[ -e "$out" ] || [ -L "$out" ] || continue
		chmod -R u+w "$out" 2>/dev/null || true
		rm -rf -- "$out"
	done
	chmod -R u+w "$TMP_ROOT" 2>/dev/null || true
	rm -rf -- "$TMP_ROOT"
}

trap cleanup EXIT INT TERM

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

for command in cp find ln mkdir mv rm sed; do
	command -v "$command" >/dev/null 2>&1 || die "missing command: $command"
done
[ -x "$RUNNER" ] || die 'closure runner is not executable'
for root in "$COMBINED_DIR" "$SOURCE_DIR" "$CONFIG_DIR" "$REGRESSION_DIR"; do
	[ -d "$root" ] || die "canonical evidence is not complete: $root"
	done

prepare_bundle()
{
	local name=$1 bundle="$TMP_ROOT/$1"

	mkdir "$bundle"
	cp -a -- "$COMBINED_DIR" "$bundle/combined"
	cp -a -- "$SOURCE_DIR" "$bundle/source"
	cp -a -- "$CONFIG_DIR" "$bundle/config"
	cp -a -- "$REGRESSION_DIR" "$bundle/regression"
	printf '%s\n' "$bundle"
}

retire_case()
{
	local bundle=$1 run_id=$2
	local out="$OUT_ROOT/$run_id"

	chmod -R u+w "$bundle" "$out" 2>/dev/null || true
	rm -rf -- "$bundle" "$out"
}

run_pass()
{
	local name=$1 bundle run_id="closure-test-$1-$$"

	bundle=$(prepare_bundle "$name")
	CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 SOURCE_BUNDLE_OVERRIDE="$bundle" \
		RUN_ID="$run_id" "$RUNNER" >/dev/null
	retire_case "$bundle" "$run_id"
	printf 'ok: %s\n' "$name"
}

run_reject()
{
	local name=$1 mutation=$2 bundle run_id="closure-test-$1-$$"

	bundle=$(prepare_bundle "$name")
	case "$mutation" in
		combined-result)
			printf '\n' >> "$bundle/combined/result.json"
			;;
		source-symlink)
			ln -s e4-source.diff "$bundle/source/injected-link"
			;;
		hard-irq-observation)
			sed 's/rq->measure_irq_cpu = raw_smp_processor_id();/rq->measure_irq_cpu = -1;/' \
				"$bundle/source/hard-irq-dispatch.c" > "$bundle/source/hard-irq-dispatch.c.tmp"
			mv "$bundle/source/hard-irq-dispatch.c.tmp" "$bundle/source/hard-irq-dispatch.c"
			;;
		config-enable-e4)
			sed 's/# CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST is not set/CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST=y/' \
				"$bundle/config/arm64-standard-debug.config" > "$bundle/config/arm64-standard-debug.config.tmp"
			mv "$bundle/config/arm64-standard-debug.config.tmp" "$bundle/config/arm64-standard-debug.config"
			;;
		receipt-tamper)
			printf '{}\n' >> "$bundle/regression/arm64-standard-debug-receipts.jsonl"
			;;
		artifact-removal)
			rm -- "$bundle/regression/x86_64-kcsan-ktap.log"
			;;
		*) die "unknown mutation: $mutation" ;;
	esac
	if CLOSURE_TEST_MODE=1 PREFLIGHT_ONLY=1 SOURCE_BUNDLE_OVERRIDE="$bundle" \
		RUN_ID="$run_id" "$RUNNER" >/dev/null 2>&1; then
		die "$name unexpectedly passed"
	fi
	retire_case "$bundle" "$run_id"
	printf 'ok: %s rejected\n' "$name"
}

run_pass exact
run_reject combined-result-tamper combined-result
run_reject source-symlink source-symlink
run_reject hard-irq-observation-tamper hard-irq-observation
run_reject config-e4-enable config-enable-e4
run_reject receipt-tamper receipt-tamper
run_reject artifact-removal artifact-removal

printf 'all R4-E4 source/E3 closure tests passed\n'
