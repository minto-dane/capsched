#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLASSIFIER="$SCRIPT_DIR/lib/kernel-warning-classifier.sh"
TMP=$(mktemp -d)

cleanup()
{
	rm -rf -- "$TMP"
}

fail()
{
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

trap cleanup EXIT
# shellcheck disable=SC1090
source "$CLASSIFIER"

printf '%s\n' \
	'[    3.106630] kcsan: enabled early' \
	'[    3.107595] kcsan: strict mode configured' \
	'[    3.835736] kcsan: selftest: 3/3 tests passed' \
	> "$TMP/benign.log"
capsched_collect_kernel_warning_reports "$TMP/benign.log" "$TMP/benign.report"
[ ! -s "$TMP/benign.report" ] || fail 'normal KCSAN lifecycle lines were rejected'

printf '%s\n' \
	'BUG: KCSAN: data-race in test_kernel_read / test_kernel_write' \
	'race at unknown origin, with read to 0x1 of 8 bytes by task 1 on cpu 0:' \
	'value changed: 0x0000000000000001 -> 0x0000000000000002' \
	'Reported by Kernel Concurrency Sanitizer on:' \
	> "$TMP/race.log"
capsched_collect_kernel_warning_reports "$TMP/race.log" "$TMP/race.report"
[ "$(wc -l < "$TMP/race.report" | tr -d ' ')" = 4 ] || fail 'KCSAN report fixture was not completely classified'
grep -Fq 'BUG: KCSAN: data-race' "$TMP/race.report" || fail 'KCSAN report header was missed'
grep -Fq 'Reported by Kernel Concurrency Sanitizer on:' "$TMP/race.report" || fail 'KCSAN report footer was missed'

printf '%s\n' \
	'WARNING: suspicious state' \
	'kcsan: report lost' \
	> "$TMP/fail-closed.log"
capsched_collect_kernel_warning_reports "$TMP/fail-closed.log" "$TMP/fail-closed.report"
[ "$(wc -l < "$TMP/fail-closed.report" | tr -d ' ')" = 2 ] || fail 'generic or unknown KCSAN diagnostics were not fail-closed'

printf 'PASS: kernel warning classifier\n'
