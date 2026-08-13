#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd -P)
sync_script=$script_dir/sync-candidate-inputs-to-apple-container-machine.sh
readonly runner=/usr/local/libexec/domainlease-f0-c4/run-capture-systemd.sh
readonly evidence_root=/var/lib/domainlease-f0-c4/evidence
readonly installed_manifest=/usr/local/share/domainlease-f0-c4/installed-artifact-manifest-v1.txt
readonly installed_contract=/usr/local/share/domainlease-f0-c4/f0-c4-capture-contract-v1.json
readonly state=$repo_root/capsched-ai/state/state.json
readonly handoff=$repo_root/capsched-ai/handoff.md
readonly events=$repo_root/capsched-ai/state/events.jsonl
readonly git=/usr/bin/git
readonly jq=/usr/bin/jq
readonly awk=/usr/bin/awk
readonly sed=/usr/bin/sed

run_id=${1:-candidate4-full-$(date -u '+%Y%m%dT%H%M%SZ')}
[[ $run_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
	printf 'usage: %s [SAFE_RUN_ID]\n' "$0" >&2
	exit 64
}
readonly run_id
readonly launcher_unit=domainlease-f0-c4-host-launch-$run_id
readonly capture_unit=domainlease-f0-c4-$run_id

for tool in "$git" "$jq" "$awk" "$sed"; do
	[[ -x $tool ]] || {
		printf 'error: pinned host preflight tool missing: %s\n' "$tool" >&2
		exit 1
	}
done
head=$($git -C "$repo_root" rev-parse --verify HEAD^{commit})
[[ -z $($git -C "$repo_root" status --porcelain=v1 --untracked-files=all) ]] || {
	printf 'error: full capture requires a clean committed source tree\n' >&2
	exit 1
}
for checkpoint in "${state#"$repo_root"/}" "${handoff#"$repo_root"/}" \
	"${events#"$repo_root"/}"; do
	[[ $($git -C "$repo_root" log -1 --format=%H -- "$checkpoint") == "$head" ]] || {
		printf 'error: capture checkpoint is not fresh at HEAD: %s\n' \
			"$checkpoint" >&2
		exit 1
	}
done
$jq -e '
	.project.current_phase == "f0_v5_c4_g6_open_retry_eligible" and
	.evidence.current_candidate_inputs.status ==
		"disk_backed_exact_store_repaired_clean_installed_g6_retry_eligible" and
	.evidence.authority_capture_contract.clean_install.status ==
		"PASSED_FOR_EXTERNAL_MEMORY_REPAIRED_INPUTS" and
	.evidence.authority_capture_contract.clean_install.current_inputs_installed == true and
	.evidence.authority_capture_contract.g6.gate_status == "OPEN" and
	.evidence.authority_capture_contract.g6.retry_eligible == true and
	.evidence.authority_capture_contract.g6.active_attempt == null and
	.evidence.authority_capture_contract.g6.complete_capture_available == false and
	.evidence.authority_capture_contract.g7.gate_status == "BLOCKED"
' "$state" >/dev/null || {
	printf 'error: current state does not authorize a fresh G6 retry\n' >&2
	exit 1
}
recorded_source=$($jq -er \
	'.evidence.authority_capture_contract.clean_install.installed_source_commit' \
	"$state")
recorded_manifest=$($jq -er \
	'.evidence.authority_capture_contract.clean_install.installed_manifest_sha256' \
	"$state")
recorded_contract=$($jq -er \
	'.evidence.authority_capture_contract.canonical_sha256' "$state")
manifest_hash=$(container machine run --root -n domainlease-dev -- \
	/usr/bin/sha256sum "$installed_manifest" | "$awk" '{print $1}')
contract_hash=$(container machine run --root -n domainlease-dev -- \
	/usr/bin/sha256sum "$installed_contract" | "$awk" '{print $1}')
manifest_text=$(container machine run --root -n domainlease-dev -- \
	/usr/bin/cat "$installed_manifest")
installed_source=$(printf '%s\n' "$manifest_text" | \
	"$sed" -n 's/^source_commit=//p')
[[ $installed_source == "$recorded_source" \
	&& $manifest_hash == "$recorded_manifest" \
	&& $contract_hash == "$recorded_contract" ]] || {
	printf 'error: installed TCB identity differs from retry readiness\n' >&2
	exit 1
}
printf 'F0_C4_FULL_CAPTURE_PREFLIGHT_PASS head=%s installed_source=%s manifest=%s contract=%s\n' \
	"$head" "$installed_source" "$manifest_hash" "$contract_hash" >&2

source_dir=$("$sync_script")
readonly source_dir
container machine run --root -n domainlease-dev -- \
	/usr/bin/test -x "$runner"

for unit in "$launcher_unit" "$capture_unit"; do
	active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$unit" 2>/dev/null || true)
	[[ $active != active && $active != activating ]] || {
		printf 'error: %s is already active\n' "$unit" >&2
		exit 1
	}
done
if container machine run --root -n domainlease-dev -- \
	/usr/bin/test -e "$evidence_root/$run_id"; then
	printf 'error: evidence already exists for run ID: %s\n' "$run_id" >&2
	exit 1
fi

container machine run --root -n domainlease-dev -- \
	/usr/bin/systemd-run \
	--quiet --no-block \
	--unit "$launcher_unit" \
	--service-type exec \
	--property StandardInput=null \
	--property KillMode=control-group \
	--property RuntimeMaxSec=137100s \
	--property TimeoutStopSec=40s \
	--property OOMPolicy=kill \
	-- "$runner" "$run_id" "$source_dir"

ready=false
for _ in {1..20}; do
	capture_active=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-active "$capture_unit" 2>/dev/null || true)
	if [[ $capture_active == active || $capture_active == activating ]] || \
		container machine run --root -n domainlease-dev -- \
		/usr/bin/test -f "/run/domainlease-f0-c4/progress/$run_id"; then
		ready=true
		break
	fi
	launcher_failed=$(container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl is-failed "$launcher_unit" 2>/dev/null || true)
	if [[ $launcher_failed == failed ]]; then
		break
	fi
	sleep 1
done
if [[ $ready != true ]]; then
	printf 'error: detached capture did not reach its first durable progress receipt\n' >&2
	container machine run --root -n domainlease-dev -- \
		/usr/bin/systemctl show "$launcher_unit" \
		--property ActiveState --property SubState --property Result \
		--property ExecMainStatus --no-pager >&2 || true
	container machine run --root -n domainlease-dev -- \
		/usr/bin/journalctl -u "$launcher_unit" -u "$capture_unit" \
		-n 24 --no-pager >&2 || true
	exit 1
fi

printf 'F0_C4_FULL_CAPTURE_STARTED run_id=%s unit=%s\n' \
	"$run_id" "$capture_unit"
printf 'monitor: %s/monitor-candidate4-full-capture.sh %s 30\n' \
	"$script_dir" "$run_id"
