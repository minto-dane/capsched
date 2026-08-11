#!/usr/bin/env bash
set -euo pipefail

[[ ${EUID:-$(/usr/bin/id -u)} -eq 0 ]] || {
	printf 'error: root is required\n' >&2
	exit 77
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
state_root=/var/lib/domainlease-f0-c4
evidence_root=$state_root/evidence
intent_root=$state_root/intents
trusted_root=/run/f0-c4-guardian-test-trusted-$$
guardian=$trusted_root/f0-c4-guardian-finalize.py
prefix=guardian-test-$$
crash_id=$prefix-crash
success_id=$prefix-success
boot_id=$prefix-boot

cleanup()
{
	rm -rf -- "$evidence_root/$crash_id" \
		"$evidence_root/$crash_id.guardian-incomplete" \
		"$evidence_root/$success_id" \
		"$evidence_root/$success_id.guardian-incomplete" \
		"$evidence_root/$boot_id" \
		"$evidence_root/$boot_id.guardian-incomplete" \
		"$intent_root/$crash_id.json" \
		"$intent_root/$success_id.json" \
		"$intent_root/$boot_id.json" "$trusted_root"
}
trap cleanup EXIT HUP INT TERM

install -d -o root -g root -m 0700 \
	"$state_root" "$evidence_root" "$intent_root" "$trusted_root"
install -o root -g root -m 0755 "$script_dir/f0_c4_guardian_finalize.py" \
	"$guardian"
contract_sha=$(
	/usr/bin/python3 -I -S -B -c \
		'import runpy,sys; print(runpy.run_path(sys.argv[1])["CONTRACT_SHA256"])' \
		"$guardian"
)

register()
{
	/usr/bin/python3 -I -S -B "$guardian" register \
		--run-id "$1" --evidence-root "$evidence_root" >/dev/null
}

finalize_in_unit()
{
	systemd-run --quiet --wait --pipe --collect \
		--unit "domainlease-f0-c4-guardian-test-$1" \
		--service-type exec \
		--property StandardInput=null \
		-- /usr/bin/python3 -I -S -B "$guardian" finalize --run-id "$1"
}

register "$crash_id"
finalize_in_unit "$crash_id" >/dev/null
jq -e --arg run_id "$crash_id" '
	.run_id == $run_id and
	.capture_status == "GUARDIAN_INCOMPLETE_PUBLISHED" and
	.failure_class == "SUPERVISOR_DIED" and
	.candidate_bytes_positive_eligible == false and
	.drain_receipt.populated_zero_observed == true
' "$evidence_root/$crash_id/guardian-incomplete.json" >/dev/null
jq -e '.artifact_id == "f0-c4-guardian-incomplete-commit-v1"' \
	"$evidence_root/$crash_id/RAW_COMMIT.json" >/dev/null

register "$success_id"
success_path=$evidence_root/$success_id
mkdir -m 0700 -- "$success_path"
printf '{"fixture":true}\n' > "$success_path/capture-manifest.json"
chmod 0444 "$success_path/capture-manifest.json"
manifest_sha=$(/usr/bin/sha256sum "$success_path/capture-manifest.json" | /usr/bin/awk '{print $1}')
/usr/bin/python3 -I -S -B -c \
	'import json,sys; value={"schema_version":1,"artifact_id":"f0-c4-raw-capture-commit-v1","run_id":sys.argv[1],"capture_status":"RAW_CAPTURE_COMPLETE","contract_sha256":sys.argv[2],"manifest_sha256":sys.argv[3],"commit_authority":"CAPTURE_SUPERVISOR","candidate_bytes_positive_eligible":False,"reduction_performed":False}; print(json.dumps(value,sort_keys=True,separators=(",",":")))' \
	"$success_id" "$contract_sha" "$manifest_sha" \
	> "$success_path/RAW_COMMIT.json"
chmod 0444 "$success_path/RAW_COMMIT.json"
chmod 0555 "$success_path"
finalize_in_unit "$success_id" >/dev/null
[[ ! -e $intent_root/$success_id.json ]]
[[ ! -e $evidence_root/$success_id.guardian-incomplete ]]

register "$boot_id"
/usr/bin/python3 -I -S -B -c \
	'import json,os,sys; path=sys.argv[1]; value=json.load(open(path,"r",encoding="utf-8")); value["boot_id"]="00000000-0000-0000-0000-000000000000"; temporary=path+".tmp"; handle=open(temporary,"w",encoding="utf-8"); handle.write(json.dumps(value,sort_keys=True,separators=(",",":"))+"\n"); handle.flush(); os.fsync(handle.fileno()); handle.close(); os.chmod(temporary,0o600); os.replace(temporary,path); directory=os.open(os.path.dirname(path),os.O_RDONLY|os.O_DIRECTORY); os.fsync(directory); os.close(directory)' \
	"$intent_root/$boot_id.json"
/usr/bin/python3 -I -S -B "$guardian" reconcile >/dev/null
jq -e --arg run_id "$boot_id" '
	.run_id == $run_id and
	.failure_class == "BOOT_INTERRUPTED" and
	.drain_receipt.prior_boot_process_survival_possible == false and
	.candidate_bytes_positive_eligible == false
' "$evidence_root/$boot_id/guardian-incomplete.json" >/dev/null
[[ ! -e $intent_root/$boot_id.json ]]

printf 'F0_C4_GUARDIAN_RECOVERY_PASS cases=3\n'
