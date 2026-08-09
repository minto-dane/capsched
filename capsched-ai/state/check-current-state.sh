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

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
state_rel=capsched-ai/state/state.json
schema_rel=capsched-ai/state/schemas/state.schema.json
handoff_rel=capsched-ai/handoff.md
events_rel=capsched-ai/state/events.jsonl
claims_rel=capsched-models/assurance/claims.json
ledger_rel=capsched-models/analysis/final-model-completeness-ledger-v1.json

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

jq empty "$state" "$schema" "$claims" "$ledger"

jq -e '
	.schema_version == 2 and
	.project.name == "DomainLease-Linux" and
	.project.current_phase == "final_compositional_model_reopened" and
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
	([.accepted_invariants[].id] | length == (unique | length)) and
	([.planned_tracks[].order] == ([.planned_tracks[].order] | sort)) and
	([.next_actions[].order] == ([.next_actions[].order] | sort))
' "$state" >/dev/null

jq -e '
	([.claims[].id] | length == (unique | length)) and
	([.evidence[].id] | length == (unique | length)) and
	(.claims[] | select(.id == "TOP-001") | .status) == "open" and
	([.claims[].id] as $ids |
	 ["ROOTSCHED-001", "RESIDENCY-001", "RESIDENCY-DYN-001",
	  "ENTRY-001", "CODE-001",
	  "STATE-001", "SVC-001", "MGMT-001", "CLUSTER-PART-001",
	  "COMPOSE-001", "GRANULARITY-001", "EVIDENCE-001"] |
	 all(. as $id | $ids | index($id) != null))
' "$claims" >/dev/null

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

[[ $branch == "$recorded_branch" ]] || {
	printf 'error: state branch %s does not match current branch %s\n' \
		"$recorded_branch" "${branch:-DETACHED}" >&2
	exit 1
}

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
	if [[ -n $(git -C "$repo_root" status --porcelain -- \
		"$state_rel" "$schema_rel" "$handoff_rel" "$events_rel") ]]; then
		printf 'error: current-state artifacts have uncommitted changes\n' >&2
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
