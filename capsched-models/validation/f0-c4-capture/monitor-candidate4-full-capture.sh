#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || {
	printf 'usage: %s RUN_ID [REFRESH_SECONDS]\n' "$0" >&2
	exit 64
}
run_id=$1
interval=${2:-30}
[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ && \
	$interval =~ ^[1-9][0-9]*$ ]] || {
	printf 'usage: %s RUN_ID [REFRESH_SECONDS]\n' "$0" >&2
	exit 64
}
readonly run_id interval
readonly launcher_unit=domainlease-f0-c4-host-launch-$run_id
readonly capture_unit=domainlease-f0-c4-$run_id
readonly progress=/run/domainlease-f0-c4/progress/$run_id
readonly evidence=/var/lib/domainlease-f0-c4/evidence/$run_id
readonly commit=$evidence/RAW_COMMIT.json

while :; do
	printf '\033[2J\033[H'
	printf 'updated_at: %s\nrefresh_interval: %ss\nrun_id: %s\n\n' \
		"$(date '+%Y-%m-%d %H:%M:%S %Z')" "$interval" "$run_id"
	for unit in "$launcher_unit" "$capture_unit"; do
		printf '%s\n' "$unit"
		container machine run --root -n domainlease-dev -- \
			/usr/bin/systemctl show "$unit" \
			--property ActiveState --property SubState --property Result \
			--property ExecMainStatus --no-pager 2>/dev/null || \
			printf 'ActiveState=not-loaded\n'
	done

	progress_text=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/cat "$progress" 2>/dev/null || true)
	printf '\n--- progress ---\n%s\n' \
		"${progress_text:-0% waiting for first progress receipt}"
	printf '\n--- evidence ---\n'
	container machine run --root -n domainlease-dev -- \
		/usr/bin/du -sh "$evidence" 2>/dev/null || \
		printf 'final evidence not published yet\n'
	container machine run --root -n domainlease-dev -- \
		/usr/bin/cat "$commit" 2>/dev/null || true
	printf '\n--- journal tail ---\n'
	container machine run --root -n domainlease-dev -- \
		/usr/bin/journalctl -u "$capture_unit" -u "$launcher_unit" \
		-n 16 --no-pager 2>/dev/null || true

	if container machine run --root -n domainlease-dev -- \
		/usr/bin/jq -e '.capture_status=="RAW_CAPTURE_COMPLETE"' \
		"$commit" >/dev/null 2>&1; then
		printf '\nfull raw capture is complete; monitor finished.\n'
		exit 0
	fi
	if container machine run --root -n domainlease-dev -- \
		/usr/bin/test -f "$commit"; then
		printf '\na non-complete commit was published; inspect the record above.\n'
		exit 1
	fi
	launcher_active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$launcher_unit" 2>/dev/null || true)
	capture_active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$capture_unit" 2>/dev/null || true)
	if [[ $launcher_active != active && $launcher_active != activating && \
		$capture_active != active && $capture_active != activating ]]; then
		printf '\ncapture is no longer running and no commit exists; inspect the journal.\n'
		exit 1
	fi
	printf '\nPress Ctrl-C to stop monitoring; the VM job will keep running.\n'
	sleep "$interval"
done
