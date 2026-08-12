#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
contract=$script_dir/../../analysis/f0-c4-authority-disjoint-capture-contract-v1.json
validator=$script_dir/../validate-f0-c4-authority-disjoint-capture-contract.py
runner=$script_dir/run-capture-systemd.sh
supervisor=$script_dir/f0_c4_capture_supervisor.py

command -v python3 >/dev/null 2>&1 || {
	printf 'error: python3 is required\n' >&2
	exit 1
}
command -v jq >/dev/null 2>&1 || {
	printf 'error: jq is required\n' >&2
	exit 1
}

for required in "$contract" "$validator" "$runner" "$supervisor"; do
	[[ -f $required && ! -L $required ]] || {
		printf 'error: resource-policy input missing: %s\n' "$required" >&2
		exit 1
	}
done

PYTHONDONTWRITEBYTECODE=1 python3 "$validator" "$contract" >/dev/null
jq -e '
	.resource_policy.candidate_component_oom_isolated_from_supervisor == true and
	(.resource_policy.memory_max_bytes_per_component +
	 .resource_policy.guardian_and_host_reserve_min_bytes <=
	 .resource_policy.required_vm_memory_min_bytes) and
	(.resource_policy.supervisor_memory_low_bytes <=
	 .resource_policy.guardian_and_host_reserve_min_bytes)
' "$contract" >/dev/null

PYTHONDONTWRITEBYTECODE=1 python3 -I -S -B - \
	"$runner" "$supervisor" <<'PY'
from pathlib import Path
import sys

runner = Path(sys.argv[1]).read_text(encoding="utf-8")
supervisor = Path(sys.argv[2]).read_text(encoding="utf-8")

if runner.count("--property OOMPolicy=continue") != 1:
    raise SystemExit("capture unit must have exactly one OOMPolicy=continue")
if "--property OOMPolicy=kill" in runner:
    raise SystemExit("candidate-local OOM must not trigger unit-wide supervisor kill")
if 'write_cgroup(path / "memory.oom.group", "1")' not in supervisor:
    raise SystemExit("component OOM group isolation is absent")
if '"candidate_component_oom_isolated_from_supervisor": True' not in supervisor:
    raise SystemExit("supervisor resource policy is not bound to OOM isolation")
PY

printf 'F0_C4_CAPTURE_RESOURCE_POLICY_PASS cases=7\n'
