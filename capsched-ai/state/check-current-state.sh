#!/usr/bin/env bash
set -euo pipefail

usage()
{
	printf 'usage: %s [--allow-draft]\n' "$0" >&2
}

allow_draft=false
if [[ ${1:-} == "--allow-draft" ]]; then
	allow_draft=true
elif [[ $# -ne 0 ]]; then
	usage
	exit 2
fi

command -v git >/dev/null 2>&1 || {
	printf 'error: git is required\n' >&2
	exit 1
}
command -v jq >/dev/null 2>&1 || {
	printf 'error: jq is required\n' >&2
	exit 1
}
command -v python3 >/dev/null 2>&1 || {
	printf 'error: python3 is required\n' >&2
	exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
	printf 'error: sha256sum is required\n' >&2
	exit 1
}
command -v awk >/dev/null 2>&1 || {
	printf 'error: awk is required\n' >&2
	exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
state_rel=capsched-ai/state/state.json
schema_rel=capsched-ai/state/schemas/state.schema.json
handoff_rel=capsched-ai/handoff.md
events_rel=capsched-ai/state/events.jsonl
claims_rel=capsched-models/assurance/claims.json
ledger_rel=capsched-models/analysis/final-model-completeness-ledger-v1.json
assurance_head_rels=(
	capsched-ai/decisions/ADR-0018-split-foundation-candidate-freeze-and-proof-gates.md
	capsched-ai/decisions/ADR-0024-reasoning-first-semantic-construction-and-terminal-tla-validation.md
	capsched-ai/state/schemas/state.schema.json
	capsched-ai/state/check-current-state.sh
	capsched-models/analysis/0226-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md
	capsched-models/analysis/dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure-v1.json
	capsched-models/analysis/0227-dynamic-residency-f0-c4-authority-disjoint-capture-contract.md
	capsched-models/analysis/f0-c4-authority-disjoint-capture-contract-v1.json
	capsched-models/assurance/claims.json
	capsched-models/validation/0313-dynamic-residency-f0-v5-supervisor-v3-candidate4-pre-full-local-closure.md
	capsched-models/validation/f0-supervisor-c4-claim-registry-v1.json
	capsched-models/validation/f0_supervisor_lts_v3.py
	capsched-models/validation/f0_supervisor_orchestrator_v3.py
	capsched-models/validation/test-f0-supervisor-lts-v3-mutations.py
	capsched-models/validation/test-f0-supervisor-orchestrator-v3-mutations.py
	capsched-models/validation/test-run-f0-supervisor-v3-full.sh
	capsched-models/validation/validate-f0-supervisor-lts-v3.py
	capsched-models/validation/run-f0-supervisor-v3-full.sh
	capsched-models/validation/0314-dynamic-residency-f0-c4-authority-disjoint-capture-contract.md
	capsched-models/validation/validate-f0-c4-authority-disjoint-capture-contract.py
	capsched-models/validation/test-f0-c4-authority-disjoint-capture-contract.py
)

state="$repo_root/$state_rel"
schema="$repo_root/$schema_rel"
handoff="$repo_root/$handoff_rel"
events="$repo_root/$events_rel"
claims="$repo_root/$claims_rel"
ledger="$repo_root/$ledger_rel"

for required in "$state" "$schema" "$handoff" "$events" "$claims" "$ledger"; do
	[[ -f $required ]] || {
		printf 'error: required state artifact missing: %s\n' "$required" >&2
		exit 1
	}
done

jq empty "$state" "$schema" "$claims" "$ledger" "$events"

PYTHONDONTWRITEBYTECODE=1 python3 - "$schema" "$state" <<'PY'
import json
import sys

try:
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError as error:
    raise SystemExit(
        "error: python3 jsonschema support is required for state validation"
    ) from error

with open(sys.argv[1], encoding="utf-8") as handle:
    schema = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    state = json.load(handle)

Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())
errors = sorted(validator.iter_errors(state), key=lambda item: list(item.path))
if errors:
    for error in errors:
        path = ".".join(str(part) for part in error.absolute_path) or "<root>"
        print(f"error: state schema violation at {path}: {error.message}", file=sys.stderr)
    raise SystemExit(1)
PY

jq -e '
	.schema_version == 2 and
	.project.name == "DomainLease-Linux" and
	.project.current_phase ==
	 "f0_v5_c4_authority_capture_g1_g5_closed" and
	.project.publication.github_visibility == "public_intentional" and
	.project.publication.secrets_allowed == false and
	.completion.v1_claim_inventory_complete == true and
	.completion.final_compositional_model_complete == false and
	.completion.linux_implementation_complete == false and
	.completion.monitor_implementation_complete == false and
	.completion.protection_evidenced == false and
	.completion.cost_efficiency_evidenced == false and
	.completion.deployment_ready == false and
	.evidence.contract_status == "defined" and
	.evidence.reviewed_positive_promotion_credit == "needs_revalidation" and
	.evidence.codex_security_scan_required == false and
	.evidence.local_candidate_checkpoint.full_validator_status == "NOT_RUN" and
	.evidence.local_candidate_checkpoint.authority_disjoint_capture == false and
	.evidence.authority_capture_contract.canonical_sha256 ==
	 "14ca4b5424f448462ff0868689f278f412ee43fe2d32d8372a8cacc78d4fd075" and
	.evidence.authority_capture_contract.closed_gates ==
	 ["C4CAP-G1-CONTRACT", "C4CAP-G2-HOSTILE",
	  "C4CAP-G3-SUPERVISOR", "C4CAP-G4-PLATFORM",
	  "C4CAP-G5-FAULTS"] and
	.evidence.authority_capture_contract.remaining_gates ==
	 ["C4CAP-G6-CAPTURE", "C4CAP-G7-REDUCTION"] and
	.evidence.authority_capture_contract.hostile_mutation_cases == 153 and
	.evidence.authority_capture_contract.derived_semantic_cases == 13 and
	.evidence.authority_capture_contract.root_supervisor_implemented == true and
	.evidence.authority_capture_contract.target_platform_probe_passed == true and
	.evidence.authority_capture_contract.hostile_fault_fixtures_passed == true and
	.evidence.authority_capture_contract.reduction_boundary_implemented == true and
	.evidence.authority_capture_contract.immutable_toolchain.format == "erofs" and
	.evidence.authority_capture_contract.immutable_toolchain.mounted_read_only == true and
	.evidence.authority_capture_contract.full_capture_run == false and
	.evidence.authority_capture_contract.real_reduction_run == false and
	(.evidence.local_candidate_checkpoint.hostile_case_counts |
	 .total == (.child + .parent + .runner)) and
	([.accepted_invariants[].id] | length == (unique | length)) and
	([.planned_tracks[].order] == ([.planned_tracks[].order] | sort)) and
	([.next_actions[].order] == ([.next_actions[].order] | sort))
' "$state" >/dev/null

patch_queue_rel=$(jq -er '.project.linux_patch_queue.repository' "$state")
patch_queue_root=$(CDPATH= cd -- "$repo_root/$patch_queue_rel" 2>/dev/null &&
	pwd -P || true)
if [[ -n $patch_queue_root && -f $patch_queue_root/upstream/base.txt ]]; then
	recorded_replay_base=$(jq -er \
		'.project.linux_patch_queue.replay_base_revision' "$state")
	recorded_replay_work=$(jq -er \
		'.project.linux_patch_queue.replay_work_revision' "$state")
	metadata_replay_base=$(awk -F= '$1 == "base_commit" { print $2 }' \
		"$patch_queue_root/upstream/base.txt")
	metadata_replay_work=$(awk -F= '$1 == "work_commit" { print $2 }' \
		"$patch_queue_root/upstream/base.txt")
	[[ $recorded_replay_base == "$metadata_replay_base" &&
	   $recorded_replay_work == "$metadata_replay_work" ]] || {
		printf 'error: Linux patch-queue replay identity mismatch\n' >&2
		exit 1
	}
fi

jq -e '
	([.claims[].id] | length == (unique | length)) and
	([.evidence[].id] | length == (unique | length)) and
	([.gates[].id] | length == (unique | length)) and
	([.gates[] | select(.id == "G0")] | length == 0) and
	(.gate_identifier_policy.bare_G0_semantics ==
	 "K0 foundation adoption only, as fixed by ADR-0018") and
	([.gates[] | select(.id == "K0-G0" and .status == "open" and
	 .current_authorization == false)] | length == 1) and
	([.gates[] | select(.id == "LINUX-L0-G0" and
	 .historical_alias == "G0" and
	 .historical_alias_is_authority == false and
	 .status == "completed")] | length == 1) and
	(.claims[] | select(.id == "TOP-001") | .status) == "open" and
	([.claims[].id] as $ids |
	 ["ROOTSCHED-001", "RESIDENCY-001", "RESIDENCY-DYN-001",
	  "ENTRY-001", "CODE-001",
	  "STATE-001", "SVC-001", "MGMT-001", "CLUSTER-PART-001",
	  "COMPOSE-001", "GRANULARITY-001", "EVIDENCE-001"] |
	 all(. as $id | $ids | index($id) != null))
' "$claims" >/dev/null

registry_rel=$(jq -er '
	.local_validation_claim_registries[] |
	select(.id == "F0-C4-CLAIM-REGISTRY-v1") |
	.path
' "$claims")
[[ $registry_rel == \
	capsched-models/validation/f0-supervisor-c4-claim-registry-v1.json ]] || {
	printf 'error: unexpected F0 C4 claim registry path: %s\n' \
		"$registry_rel" >&2
	exit 1
}
registry="$repo_root/$registry_rel"
[[ -f $registry ]] || {
	printf 'error: F0 C4 claim registry missing: %s\n' "$registry" >&2
	exit 1
}
registry_digest=$(sha256sum -- "$registry" | awk '{print $1}')
recorded_registry_digest=$(jq -er '
	.local_validation_claim_registries[] |
	select(.id == "F0-C4-CLAIM-REGISTRY-v1") |
	.sha256
' "$claims")
[[ $registry_digest == "$recorded_registry_digest" ]] || {
	printf 'error: F0 C4 claim registry digest mismatch\n' >&2
	exit 1
}

jq -e '
	.artifact_id ==
	 "dynamic-residency-f0-v5-supervisor-v3-candidate4-claim-registry" and
	([.claims[].id] | length == 11 and length == (unique | length)) and
	.authorization.F0_local_acceptance == false and
	.authorization.external_R11_review == false and
	.authorization.G0_authorized == false and
	.authorization.self_authorization == false and
	.authorization.protection_claim == false
' "$registry" >/dev/null

jq -e --slurpfile registry "$registry" '
	(.local_validation_claim_registries[] |
	 select(.id == "F0-C4-CLAIM-REGISTRY-v1")) as $link |
	($link.claim_ids | sort) ==
	 ($registry[0].claims | map(.id) | sort) and
	$link.authorization.F0_local_acceptance == false and
	$link.authorization.external_R11_review == false and
	$link.authorization.G0_authorized == false and
	$link.authorization.self_authorization == false and
	$link.authorization.protection_claim == false
' "$claims" >/dev/null

c4_contract_rel=$(jq -er '.canonical_files.f0_c4_pre_full_contract' "$state")
c4_contract="$repo_root/$c4_contract_rel"
[[ -f $c4_contract ]] || {
	printf 'error: F0 C4 pre-full contract missing: %s\n' "$c4_contract" >&2
	exit 1
}
jq empty "$c4_contract"
while IFS=$'\t' read -r input_name expected_digest; do
	input_path="$repo_root/capsched-models/validation/$input_name"
	[[ -f $input_path ]] || {
		printf 'error: F0 C4 exact input missing: %s\n' "$input_path" >&2
		exit 1
	}
	actual_digest=$(sha256sum -- "$input_path" | awk '{print $1}')
	[[ $actual_digest == "$expected_digest" ]] || {
		printf 'error: F0 C4 exact input digest mismatch: %s\n' \
			"$input_name" >&2
		exit 1
	}
done < <(jq -r '.exact_inputs | to_entries[] | [.key, .value] | @tsv' \
	"$c4_contract")

jq -e --slurpfile state "$state" '
	.local_regression.full_validator_status == "NOT_RUN" and
	.local_regression.fast_validator_status ==
	 "COMPLETE_LOCAL_C4_FAST_REGRESSION_ONLY" and
	.local_regression.child_hostile_cases ==
	 $state[0].evidence.local_candidate_checkpoint.hostile_case_counts.child and
	.local_regression.parent_hostile_cases ==
	 $state[0].evidence.local_candidate_checkpoint.hostile_case_counts.parent and
	.local_regression.runner_hostile_cases ==
	 $state[0].evidence.local_candidate_checkpoint.hostile_case_counts.runner and
	.local_regression.total_hostile_cases ==
	 $state[0].evidence.local_candidate_checkpoint.hostile_case_counts.total and
	.authorization.F0_local_acceptance == false and
	.authorization.external_R11_review == false and
	.authorization.G0_authorized == false and
	.authorization.self_authorization == false and
	.authorization.protection_claim == false
' "$c4_contract" >/dev/null

capture_contract_rel=$(jq -er '.canonical_files.f0_c4_capture_contract' "$state")
capture_validator_rel=$(jq -er '.canonical_files.f0_c4_capture_validator' "$state")
capture_hostile_rel=$(jq -er '.canonical_files.f0_c4_capture_hostile_test' "$state")
capture_contract="$repo_root/$capture_contract_rel"
capture_validator="$repo_root/$capture_validator_rel"
capture_hostile="$repo_root/$capture_hostile_rel"
[[ -f $capture_contract && -f $capture_validator && -f $capture_hostile ]] || {
	printf 'error: F0 C4 authority-disjoint contract or validator missing\n' >&2
	exit 1
}
capture_result=$(PYTHONDONTWRITEBYTECODE=1 python3 \
	"$capture_validator" "$capture_contract")
recorded_capture_digest=$(jq -er \
	'.evidence.authority_capture_contract.canonical_sha256' "$state")
[[ $capture_result == *"F0_C4_AUTHORITY_CAPTURE_CONTRACT_PASS"* &&
   $capture_result == *"sha256=$recorded_capture_digest"* ]] || {
	printf 'error: F0 C4 authority-disjoint contract validation failed\n' >&2
	exit 1
}
capture_hostile_result=$(PYTHONDONTWRITEBYTECODE=1 python3 \
	"$capture_hostile")
[[ $capture_hostile_result == *"hostile_cases=153 derived_cases=13"* ]] || {
	printf 'error: F0 C4 authority-disjoint hostile regression failed\n' >&2
	exit 1
}

jq -e '
	.status == "historical_v1_inventory_complete_final_composition_reopened" and
	.scope_correction.historical_result_retained == true and
	.scope_correction.final_compositional_model_complete == false and
	.scope_correction.final_compositional_model_reopened == true
' "$ledger" >/dev/null

while IFS= read -r canonical; do
	[[ -f "$repo_root/$canonical" ]] || {
		printf 'error: canonical file missing: %s\n' "$canonical" >&2
		exit 1
	}
done < <(jq -r '.canonical_files[]' "$state")

head=$(git -C "$repo_root" rev-parse HEAD^{commit})
branch=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD || true)
recorded_branch=$(jq -r '.project.control_repository.branch' "$state")
baseline=$(jq -r '.project.control_repository.semantic_baseline_revision' "$state")
reviewed=$(jq -r '.project.control_repository.reviewed_lineage_revision' "$state")
stable_main=$(jq -r '.project.control_repository.stable_main_revision' "$state")

if [[ -n $branch ]]; then
	[[ $branch == "$recorded_branch" ]] || {
		printf 'error: state branch %s does not match current branch %s\n' \
			"$recorded_branch" "$branch" >&2
		exit 1
	}
else
	superproject=$(git -C "$repo_root" rev-parse \
		--show-superproject-working-tree)
	[[ -n $superproject ]] || {
		printf 'error: detached HEAD is allowed only at a superproject gitlink\n' >&2
		exit 1
	}
	case $repo_root in
	"$superproject"/*)
		submodule_path=${repo_root#"$superproject"/}
		;;
	*)
		printf 'error: detached repository is outside its superproject\n' >&2
		exit 1
		;;
	esac
	gitlink=$(git -C "$superproject" ls-files -s -- "$submodule_path" |
		awk '$1 == "160000" { print $2 }')
	[[ -n $gitlink && $gitlink == "$head" ]] || {
		printf 'error: detached HEAD does not match its superproject gitlink\n' >&2
		exit 1
	}
fi

for commit in "$baseline" "$reviewed" "$stable_main"; do
	git -C "$repo_root" cat-file -e "$commit^{commit}"
done

git -C "$repo_root" merge-base --is-ancestor "$reviewed" "$baseline"
git -C "$repo_root" merge-base --is-ancestor "$baseline" "$head"

state_commit=$(git -C "$repo_root" log -1 --format=%H -- "$state_rel")
handoff_commit=$(git -C "$repo_root" log -1 --format=%H -- "$handoff_rel")
events_commit=$(git -C "$repo_root" log -1 --format=%H -- "$events_rel")

if ! $allow_draft; then
	[[ -n $state_commit && $state_commit == "$head" ]] || {
		printf 'error: state is not committed at HEAD (%s != %s)\n' \
			"${state_commit:-UNCOMMITTED}" "$head" >&2
		exit 1
	}
	[[ $handoff_commit == "$state_commit" ]] || {
		printf 'error: handoff and state were not updated in the same commit\n' >&2
		exit 1
	}
	[[ $events_commit == "$state_commit" ]] || {
		printf 'error: event log and state were not updated in the same commit\n' >&2
		exit 1
	}
	for assurance_rel in "${assurance_head_rels[@]}"; do
		git -C "$repo_root" ls-files --error-unmatch -- \
			"$assurance_rel" >/dev/null || {
			printf 'error: assurance artifact is not tracked: %s\n' \
				"$assurance_rel" >&2
			exit 1
		}
	done
	while IFS= read -r canonical; do
		git -C "$repo_root" ls-files --error-unmatch -- \
			"$canonical" >/dev/null || {
			printf 'error: canonical file is not tracked: %s\n' \
				"$canonical" >&2
			exit 1
		}
	done < <(jq -r '.canonical_files[]' "$state")
	if [[ -n $(git -C "$repo_root" status --porcelain \
		--untracked-files=all) ]]; then
		printf 'error: checkpoint worktree is not completely clean\n' >&2
		exit 1
	fi
fi

jq -cn \
	--arg status pass \
	--arg mode "$($allow_draft && printf draft || printf committed)" \
	--arg head "$head" \
	--arg branch "$branch" \
	--arg baseline "$baseline" \
	--arg state_commit "${state_commit:-uncommitted}" \
	--arg handoff_commit "${handoff_commit:-uncommitted}" \
	--arg events_commit "${events_commit:-uncommitted}" \
	'{
		status: $status,
		mode: $mode,
		head: $head,
		branch: $branch,
		semantic_baseline_revision: $baseline,
		state_commit: $state_commit,
		handoff_commit: $handoff_commit,
		events_commit: $events_commit,
		final_compositional_model_complete: false,
		protection_evidenced: false
	}'
