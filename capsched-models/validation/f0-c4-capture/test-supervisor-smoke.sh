#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	printf 'error: root is required\n' >&2
	exit 77
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
source_dir=$script_dir/fixtures/supervisor-smoke
source_launcher=${F0_C4_LAUNCHER:-$script_dir/f0-c4-capture-launcher}
source_contract=$script_dir/../../analysis/f0-c4-authority-disjoint-capture-contract-v1.json
run_id=mechanism-smoke-$$
unit=domainlease-f0-c4-$run_id
evidence_root=/var/lib/domainlease-f0-c4/evidence
final_path=$evidence_root/$run_id
trusted_stage=/run/f0-c4-supervisor-smoke-trusted-$$
supervisor=$trusted_stage/f0-c4-capture-supervisor.py
launcher=$trusted_stage/f0-c4-capture-launcher
contract=$trusted_stage/f0-c4-capture-contract-v1.json
guardian=$trusted_stage/f0-c4-guardian-finalize.py
intent_root=/var/lib/domainlease-f0-c4/intents

cleanup()
{
	rm -rf -- "$final_path" "$evidence_root/.staging-$run_id-"* 2>/dev/null || true
	rm -rf -- "$trusted_stage"
	rm -f -- "$intent_root/$run_id.json"
}
trap cleanup EXIT HUP INT TERM

for required in "$script_dir/f0_c4_capture_supervisor.py" \
	"$script_dir/f0_c4_guardian_finalize.py" "$source_launcher" \
	"$source_contract"; do
	[[ -f $required && ! -L $required ]] || {
		printf 'error: installed capture artifact missing: %s\n' "$required" >&2
		exit 1
	}
done
install -d -o root -g root -m 0700 "$trusted_stage"
install -o root -g root -m 0755 "$script_dir/f0_c4_capture_supervisor.py" \
	"$supervisor"
install -o root -g root -m 0755 "$script_dir/f0_c4_guardian_finalize.py" \
	"$guardian"
install -o root -g root -m 0755 "$source_launcher" "$launcher"
install -o root -g root -m 0444 "$source_contract" "$contract"
mkdir -p -m 0700 -- "$evidence_root" "$intent_root" /run/domainlease-f0-c4
chown root:root "$evidence_root" "$intent_root" /run/domainlease-f0-c4
chown root:root "$(dirname "$evidence_root")"
chmod 0700 "$evidence_root" "$intent_root" "$(dirname "$evidence_root")" \
	/run/domainlease-f0-c4

set +e
output=$(
	systemd-run \
		--quiet --wait --pipe --collect \
		--unit "$unit" \
		--service-type exec \
		--setenv F0_C4_GUARDIAN=systemd-v1 \
		--property User=root \
		--property Group=root \
		--property UMask=0077 \
		--property Delegate=yes \
		--property KillMode=control-group \
		--property RuntimeMaxSec=136800s \
		--property TimeoutStopSec=35s \
		--property StandardInput=null \
		--property MemoryLow=536870912 \
		--property OOMPolicy=continue \
		--property SendSIGKILL=yes \
		--property NoNewPrivileges=no \
		--property ProtectSystem=strict \
		--property ProtectHome=read-only \
		--property PrivateTmp=yes \
		--property PrivateDevices=no \
		--property ProtectControlGroups=no \
		--property ProtectKernelTunables=yes \
		--property ProtectKernelModules=yes \
		--property ProtectKernelLogs=yes \
		--property ProtectClock=yes \
		--property LockPersonality=yes \
		--property RestrictSUIDSGID=yes \
		--property RestrictRealtime=yes \
		--property RestrictAddressFamilies='AF_UNIX AF_NETLINK AF_ALG' \
		--property SystemCallArchitectures=native \
		--property CapabilityBoundingSet='CAP_SYS_ADMIN CAP_SYS_CHROOT CAP_SETUID CAP_SETGID CAP_SETPCAP CAP_MKNOD CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE CAP_FOWNER CAP_CHOWN CAP_KILL' \
		--property ReadWritePaths="$evidence_root $intent_root /run/domainlease-f0-c4" \
		--property "ExecStartPre=/usr/bin/python3 -I -S -B $guardian register --run-id $run_id --evidence-root $evidence_root" \
		--property "ExecStopPost=/usr/bin/python3 -I -S -B $guardian finalize --run-id $run_id" \
		-- /usr/bin/python3 -I -S -B "$supervisor" \
		--run-id "$run_id" \
		--campaign-class mechanism-fixture \
		--source-dir "$source_dir" \
		--evidence-root "$evidence_root" \
		--contract "$contract" \
		--launcher "$launcher" \
		--toolchain-root /usr \
		--candidate-uid 200010 \
		--candidate-gid 200010 \
		2>&1
)
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
	printf 'error: supervisor smoke unit failed rc=%d\n%s\n' "$rc" "$output" >&2
	exit 1
fi
mapfile -t capture_summaries < <(
	printf '%s\n' "$output" | sed -n 's/^CAPTURE_JSON=//p'
)
if [[ ${#capture_summaries[@]} -ne 1 ]]; then
	printf 'error: expected exactly one CAPTURE_JSON frame, got %d\n%s\n' \
		"${#capture_summaries[@]}" "$output" >&2
	exit 1
fi
summary=${capture_summaries[0]}
jq -e --arg run_id "$run_id" '
	.run_id == $run_id and
	.capture_status == "RAW_CAPTURE_COMPLETE" and
	.component_count == 5 and
	.reduction_performed == false and
	.authorization_changed == false
' <<<"$summary" >/dev/null
jq -e --arg run_id "$run_id" '
	.schema_version == 1 and
	.artifact_id == "f0-c4-authority-disjoint-root-capture-v1" and
	.run_id == $run_id and
	.campaign_class == "mechanism-fixture" and
	.capture_status == "RAW_CAPTURE_COMPLETE" and
	.component_order == [
		"static-registries",
		"tests",
		"child-bundle-producer",
		"child-bundle-checker",
		"orchestrator"
	] and
	(.component_receipt_sha256 | length) == 5 and
	.candidate_summary_is_an_oracle == false and
	.external_attestation == false and
	([.authorization[]] | all(. == false))
' "$final_path/capture-manifest.json" >/dev/null
[[ $(stat -c '%a:%u:%g' "$final_path") == 555:0:0 ]]
[[ $(stat -c '%a:%u:%g' "$final_path/raw") == 555:0:0 ]]
[[ $(find "$final_path/raw" -type f | wc -l) -eq 20 ]]
[[ $(find "$final_path/raw" -type f ! -perm 0444 | wc -l) -eq 0 ]]
[[ $(stat -c '%a:%u:%g' "$final_path/RAW_COMMIT.json") == 444:0:0 ]]
[[ ! -e $intent_root/$run_id.json ]]

printf 'F0_C4_CAPTURE_SUPERVISOR_SMOKE_PASS components=5\n'
