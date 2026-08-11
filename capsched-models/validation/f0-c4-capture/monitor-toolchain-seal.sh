#!/usr/bin/env bash
set -euo pipefail

interval=${1:-30}
[[ $interval =~ ^[1-9][0-9]*$ ]] || {
	printf 'usage: %s [REFRESH_SECONDS]\n' "$0" >&2
	exit 64
}
readonly unit=domainlease-f0-c4-toolchain-seal
readonly progress=/var/lib/domainlease-f0-c4/toolchain/seal.progress
readonly image=/var/lib/domainlease-f0-c4/toolchain/candidate.erofs
readonly manifest=/var/lib/domainlease-f0-c4/toolchain/manifest.json

while :; do
	printf '\033[2J\033[H'
	printf 'updated_at: %s\nrefresh_interval: %ss\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$interval"
	state=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl show "$unit" \
		--property ActiveState --property SubState --property Result \
		--property ExecMainStatus --value 2>/dev/null || true)
	printf 'unit: %s\n%s\n' "$unit" "${state:-state=not-loaded}"
	printf '\n--- progress ---\n'
	container machine run --root -n domainlease-dev -- /usr/bin/cat "$progress" \
		2>/dev/null || printf '0%% waiting for first progress receipt\n'
	printf '\n--- artifacts ---\n'
	container machine run --root -n domainlease-dev -- /bin/ls -lh \
		"$image" "$manifest" 2>/dev/null || printf 'not published yet\n'
	printf '\n--- journal tail ---\n'
	container machine run --root -n domainlease-dev -- \
		/usr/bin/journalctl -u "$unit" -n 12 --no-pager 2>/dev/null || true

	progress_text=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/cat "$progress" 2>/dev/null || true)
	if [[ $progress_text == 100%* ]]; then
		printf '\ntoolchain seal is complete; monitor finished.\n'
		exit 0
	fi
	active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$unit" 2>/dev/null || true)
	if [[ $active != active && $active != activating ]]; then
		printf '\ntoolchain seal is no longer running before 100%%; inspect the journal above.\n'
		exit 1
	fi
	printf '\nPress Ctrl-C to stop monitoring; the VM job will keep running.\n'
	sleep "$interval"
done
