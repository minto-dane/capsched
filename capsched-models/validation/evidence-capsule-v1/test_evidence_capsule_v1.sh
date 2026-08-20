#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
tool="$script_dir/evidence_capsule_v1.py"
request_schema="$script_dir/capture-request.schema.json"
manifest_schema="$script_dir/core-manifest.schema.json"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

source_root="$work/source"
mkdir -p "$source_root/logs"
printf '{"contract":"fixture-v1"}\n' >"$source_root/contract.json"
printf '%s\n' '---- MODULE Fixture ----' 'Safety == TRUE' '====' >"$source_root/model.tla"
printf 'producer summary is untrusted\n' >"$source_root/summary.txt"
printf 'raw line 1\nraw line 2\n' >"$source_root/logs/run.log"
contract_sha=$(sha256sum "$source_root/contract.json" | awk '{print $1}')

base_request="$work/request.json"
jq -n \
	--arg contract_sha "$contract_sha" \
	'{
		schema_version: 1,
		capsule_kind: "formal_validation",
		producer_identity: "fixture-producer",
		experiment_contract: {
			id: "fixture-contract-v1",
			object_path: "inputs/contract.json",
			sha256: $contract_sha
		},
		target_claims: ["EVIDENCE-001"],
		source_identity: {kind: "fixture", id: "capsule-v1-test"},
		declared_environment: {architecture: "fixture", execution: "local-test"},
		completeness_rule: {
			allow_extra_files: false,
			required_capsule_paths: [
				"inputs/contract.json",
				"inputs/model.tla",
				"inputs/producer-summary.txt",
				"raw/tests/run.log"
			]
		},
		objects: [
			{
				source_path: "contract.json",
				capsule_path: "inputs/contract.json",
				role: "experiment_contract",
				media_type: "application/json",
				required: true
			},
			{
				source_path: "model.tla",
				capsule_path: "inputs/model.tla",
				role: "formal_model",
				media_type: "text/plain",
				required: true
			},
			{
				source_path: "summary.txt",
				capsule_path: "inputs/producer-summary.txt",
				role: "producer_summary",
				media_type: "text/plain",
				required: true
			},
			{
				source_path: "logs/run.log",
				capsule_path: "raw/tests/run.log",
				role: "test_record",
				media_type: "text/plain",
				required: true
			},
			{
				source_path: "optional-missing.txt",
				capsule_path: "raw/tests/optional-missing.txt",
				role: "optional_diagnostic",
				media_type: "text/plain",
				required: false
			}
		]
	}' >"$base_request"

python3 -m jsonschema -i "$base_request" "$request_schema"

pass_count=0
fail_count=0

pass_case()
{
	pass_count=$((pass_count + 1))
	printf 'ok %02d - %s\n' "$pass_count" "$1"
}

expect_fail()
{
	local name=$1
	shift
	if "$@" >"$work/expected-fail.out" 2>"$work/expected-fail.err"; then
		printf 'not ok - expected failure: %s\n' "$name" >&2
		exit 1
	fi
	fail_count=$((fail_count + 1))
	printf 'ok F%02d - rejects %s\n' "$fail_count" "$name"
}

reseal_manifest()
{
	local capsule_dir=$1
	local canonical_core capsule_id
	canonical_core=$(jq -cS '.core' "$capsule_dir/core-manifest.json")
	capsule_id=$(printf '%s' "$canonical_core" | sha256sum | awk '{print $1}')
	jq --arg capsule_id "$capsule_id" \
		'.capsule_id = $capsule_id' \
		"$capsule_dir/core-manifest.json" >"$work/resealed-manifest.json"
	mv "$work/resealed-manifest.json" "$capsule_dir/core-manifest.json"
}

printf '{"schema_version":1,"schema_version":1}\n' \
	>"$work/request-duplicate-key.json"
expect_fail "duplicate JSON keys" "$tool" collect \
	--request "$work/request-duplicate-key.json" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-duplicate-key" \
	--collector-id fixture-collector

printf '{"schema_version":NaN}\n' >"$work/request-non-finite.json"
expect_fail "non-finite JSON numbers" "$tool" collect \
	--request "$work/request-non-finite.json" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-non-finite" \
	--collector-id fixture-collector

printf '\377\n' >"$work/request-invalid-utf8.json"
expect_fail "invalid UTF-8 JSON" "$tool" collect \
	--request "$work/request-invalid-utf8.json" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-invalid-utf8" \
	--collector-id fixture-collector

expect_fail "capture request byte limit" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-request-limit" \
	--collector-id fixture-collector \
	--max-request-bytes 16

expect_fail "capture object-count limit" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-object-count-limit" \
	--collector-id fixture-collector \
	--max-objects 4

expect_fail "capture object byte limit" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-object-byte-limit" \
	--collector-id fixture-collector \
	--max-object-bytes 32

expect_fail "capture total byte limit" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-total-byte-limit" \
	--collector-id fixture-collector \
	--max-total-bytes 1024

unsafe_index=0
for unsafe_path in . .. a/. a/..; do
	unsafe_index=$((unsafe_index + 1))
	unsafe_schema_request="$work/request-schema-unsafe-$unsafe_index.json"
	jq --arg unsafe_path "$unsafe_path" \
		'.objects[1].source_path = $unsafe_path' \
		"$base_request" >"$unsafe_schema_request"
	expect_fail "terminal path component $unsafe_path in request schema" \
		python3 -m jsonschema \
			-i "$unsafe_schema_request" \
			"$request_schema"
done

capsule="$work/capsule-valid"
capture_result=$(
	"$tool" collect \
		--request "$base_request" \
		--source-root "$source_root" \
		--source-root-id fixture-source-root \
		--output "$capsule" \
		--collector-id fixture-collector
)
jq -e '
	.status == "Captured" and
	.captured_object_count == 6 and
	.missing_optional_count == 1
' <<<"$capture_result" >/dev/null
pass_case "captures required bytes and records one missing optional object"

verify_result=$("$tool" verify --capsule "$capsule")
jq -e '
	.status == "Valid" and
	.captured_object_count == 6 and
	.missing_optional_count == 1 and
	.file_count == 7
' <<<"$verify_result" >/dev/null
pass_case "verifies the sealed capsule from captured bytes"

python3 -m jsonschema \
	-i "$capsule/core-manifest.json" \
	"$manifest_schema"
pass_case "generated core manifest satisfies the JSON Schema"

printf '%s\n' '---- MODULE MutatedProducerSource ----' 'Safety == FALSE' '====' \
	>"$source_root/model.tla"
"$tool" verify --capsule "$capsule" >/dev/null
grep -q 'MODULE Fixture' "$capsule/inputs/model.tla"
pass_case "producer source mutation after capture does not change capsule bytes"

mutated="$work/capsule-mutated-byte"
cp -a "$capsule" "$mutated"
printf 'tampered\n' >"$mutated/inputs/model.tla"
expect_fail "captured object mutation" "$tool" verify --capsule "$mutated"

missing="$work/capsule-missing-object"
cp -a "$capsule" "$missing"
rm "$missing/raw/tests/run.log"
expect_fail "missing required object" "$tool" verify --capsule "$missing"

extra="$work/capsule-extra-object"
cp -a "$capsule" "$extra"
printf 'unexpected\n' >"$extra/raw/tests/extra.log"
expect_fail "unlisted extra object" "$tool" verify --capsule "$extra"

capsule_symlink="$work/capsule-symlink-object"
cp -a "$capsule" "$capsule_symlink"
ln -s run.log "$capsule_symlink/raw/tests/run-alias.log"
expect_fail "symlink object inside a capsule" \
	"$tool" verify --capsule "$capsule_symlink"

manifest_tamper="$work/capsule-manifest-tamper"
cp -a "$capsule" "$manifest_tamper"
jq '.core.producer_identity = "substituted-producer"' \
	"$manifest_tamper/core-manifest.json" >"$work/manifest-tamper.json"
mv "$work/manifest-tamper.json" "$manifest_tamper/core-manifest.json"
expect_fail "core manifest mutation without a new capsule id" \
	"$tool" verify --capsule "$manifest_tamper"

request_binding_tamper="$work/capsule-request-binding-tamper"
cp -a "$capsule" "$request_binding_tamper"
jq '.core.producer_identity = "substituted-producer"' \
	"$request_binding_tamper/core-manifest.json" >"$work/request-binding-tamper.json"
mv "$work/request-binding-tamper.json" \
	"$request_binding_tamper/core-manifest.json"
reseal_manifest "$request_binding_tamper"
expect_fail "resealed core that disagrees with its captured request" \
	"$tool" verify --capsule "$request_binding_tamper"

collector_binding_tamper="$work/capsule-collector-binding-tamper"
cp -a "$capsule" "$collector_binding_tamper"
jq '.core.collector_implementation_sha256 = ("0" * 64)' \
	"$collector_binding_tamper/core-manifest.json" \
	>"$work/collector-binding-tamper.json"
mv "$work/collector-binding-tamper.json" \
	"$collector_binding_tamper/core-manifest.json"
reseal_manifest "$collector_binding_tamper"
expect_fail "resealed collector digest substitution" \
	"$tool" verify --capsule "$collector_binding_tamper"

limit_binding_tamper="$work/capsule-limit-binding-tamper"
cp -a "$capsule" "$limit_binding_tamper"
jq '.core.capture_limits.max_total_bytes = 1' \
	"$limit_binding_tamper/core-manifest.json" >"$work/limit-binding-tamper.json"
mv "$work/limit-binding-tamper.json" \
	"$limit_binding_tamper/core-manifest.json"
reseal_manifest "$limit_binding_tamper"
expect_fail "resealed capture-limit underflow" \
	"$tool" verify --capsule "$limit_binding_tamper"

modeled_extra_tamper="$work/capsule-modeled-extra-tamper"
cp -a "$capsule" "$modeled_extra_tamper"
printf 'not an object row\n' >"$modeled_extra_tamper/raw/tests/unmodeled.log"
jq '.core.completeness_rule.expected_files += ["raw/tests/unmodeled.log"] |
	.core.completeness_rule.expected_files |= sort' \
	"$modeled_extra_tamper/core-manifest.json" >"$work/modeled-extra-tamper.json"
mv "$work/modeled-extra-tamper.json" \
	"$modeled_extra_tamper/core-manifest.json"
reseal_manifest "$modeled_extra_tamper"
expect_fail "resealed expected file without an object row" \
	"$tool" verify --capsule "$modeled_extra_tamper"

hardlink_request="$work/request-hardlink-alias.json"
ln "$source_root/contract.json" "$source_root/contract-hardlink.json"
jq '.objects[1].source_path = "contract-hardlink.json"' \
	"$base_request" >"$hardlink_request"
expect_fail "source hardlink alias" "$tool" collect \
	--request "$hardlink_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-hardlink-alias" \
	--collector-id fixture-collector

symlink_request="$work/request-symlink.json"
ln -s contract.json "$source_root/contract-link.json"
jq '
	.experiment_contract.object_path = "inputs/contract-link.json" |
	.objects[0].source_path = "contract-link.json" |
	.objects[0].capsule_path = "inputs/contract-link.json" |
	.completeness_rule.required_capsule_paths[0] = "inputs/contract-link.json"
' "$base_request" >"$symlink_request"
expect_fail "source symlink" "$tool" collect \
	--request "$symlink_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-symlink" \
	--collector-id fixture-collector

mkdir "$source_root/real-parent"
printf 'nested\n' >"$source_root/real-parent/nested.txt"
ln -s real-parent "$source_root/linked-parent"
parent_symlink_request="$work/request-parent-symlink.json"
jq '
	.objects += [{
		source_path: "linked-parent/nested.txt",
		capsule_path: "inputs/nested.txt",
		role: "source",
		media_type: "text/plain",
		required: true
	}] |
	.completeness_rule.required_capsule_paths += ["inputs/nested.txt"]
' "$base_request" >"$parent_symlink_request"
expect_fail "source parent-directory symlink" "$tool" collect \
	--request "$parent_symlink_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-parent-symlink" \
	--collector-id fixture-collector

traversal_request="$work/request-traversal.json"
jq '.objects[1].source_path = "../outside"' \
	"$base_request" >"$traversal_request"
expect_fail "source path traversal" "$tool" collect \
	--request "$traversal_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-traversal" \
	--collector-id fixture-collector

duplicate_request="$work/request-duplicate.json"
jq '.objects[1].capsule_path = "inputs/contract.json"' \
	"$base_request" >"$duplicate_request"
expect_fail "duplicate capsule path" "$tool" collect \
	--request "$duplicate_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-duplicate" \
	--collector-id fixture-collector

digest_request="$work/request-bad-contract-digest.json"
jq '.experiment_contract.sha256 = ("0" * 64)' \
	"$base_request" >"$digest_request"
expect_fail "experiment contract digest substitution" "$tool" collect \
	--request "$digest_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-contract-digest" \
	--collector-id fixture-collector
test -f "$work/capsule-contract-digest/capture-failure.json"
pass_case "failed post-capture attempt retains an Incomplete receipt"

missing_request="$work/request-required-missing.json"
jq '
	.objects += [{
		source_path: "required-missing.txt",
		capsule_path: "inputs/required-missing.txt",
		role: "source",
		media_type: "text/plain",
		required: true
	}] |
	.completeness_rule.required_capsule_paths += ["inputs/required-missing.txt"]
' "$base_request" >"$missing_request"
expect_fail "missing required producer object" "$tool" collect \
	--request "$missing_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$work/capsule-required-missing" \
	--collector-id fixture-collector

git_source="$work/git-source"
mkdir "$git_source"
cp -a "$source_root/." "$git_source/"
git -C "$git_source" init -q
git -C "$git_source" config user.name "Evidence Fixture"
git -C "$git_source" config user.email "evidence-fixture.invalid"
git -C "$git_source" add -A
git -C "$git_source" commit -q -m fixture
git_commit=$(git -C "$git_source" rev-parse 'HEAD^{commit}')
git_tree=$(git -C "$git_source" rev-parse 'HEAD^{tree}')
git_object_format=$(git -C "$git_source" rev-parse --show-object-format)
git_parents_json=$(
	git -C "$git_source" show -s --format=%P HEAD |
		jq -R 'if length == 0 then [] else split(" ") end'
)
git_linked_source="$work/git-linked-source"
git -C "$git_source" worktree add -q --detach "$git_linked_source" HEAD
git_request="$work/request-git.json"
jq \
	--arg commit "$git_commit" \
	--arg tree "$git_tree" \
	--arg object_format "$git_object_format" \
	--argjson parents "$git_parents_json" \
	'.source_identity = {
		kind: "git",
		repository: "fixture-git",
		object_format: $object_format,
		commit: $commit,
		tree: $tree,
		parents: $parents,
		dirty: false
	}' "$base_request" >"$git_request"
"$tool" collect \
	--request "$git_request" \
	--source-root "$git_linked_source" \
	--source-root-id fixture-git-source-root \
	--output "$work/capsule-git" \
	--collector-id fixture-collector >/dev/null
"$tool" verify --capsule "$work/capsule-git" >/dev/null
python3 -m jsonschema \
	-i "$work/capsule-git/core-manifest.json" \
	"$manifest_schema"
jq -e '
	[
		.core.objects[] |
		select(
			.capsule_path == "inputs/contract.json" or
			.capsule_path == "inputs/model.tla" or
			.capsule_path == "inputs/producer-summary.txt" or
			.capsule_path == "raw/tests/run.log"
		)
	] |
	length == 4 and
	all(
		.source_git.size_bytes == .size_bytes and
		.source_git.sha256 == .sha256
	)
' "$work/capsule-git/core-manifest.json" >/dev/null
pass_case "binds a clean linked Git worktree through its open directory descriptor"

git_parent_request="$work/request-git-parent-substitution.json"
jq --arg substituted_parent "$git_commit" \
	'.source_identity.parents = [$substituted_parent]' \
	"$git_request" >"$git_parent_request"
expect_fail "Git parent substitution" "$tool" collect \
	--request "$git_parent_request" \
	--source-root "$git_linked_source" \
	--source-root-id fixture-git-source-root \
	--output "$work/capsule-git-parent-mismatch" \
	--collector-id fixture-collector

git -C "$git_linked_source" update-index --assume-unchanged summary.txt
printf 'status-hidden working-tree substitution\n' \
	>"$git_linked_source/summary.txt"
test -z "$(git -C "$git_linked_source" status --porcelain=v1 --untracked-files=all)"
expect_fail "clean Git working bytes that differ from the commit blob" \
	"$tool" collect \
	--request "$git_request" \
	--source-root "$git_linked_source" \
	--source-root-id fixture-git-source-root \
	--output "$work/capsule-git-blob-mismatch" \
	--collector-id fixture-collector

printf 'dirty after identity declaration\n' >>"$git_source/summary.txt"
expect_fail "Git dirty-state substitution" "$tool" collect \
	--request "$git_request" \
	--source-root "$git_source" \
	--source-root-id fixture-git-source-root \
	--output "$work/capsule-git-dirty-mismatch" \
	--collector-id fixture-collector

expect_fail "output nested inside producer source root" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$source_root/capsule-inside-source" \
	--collector-id fixture-collector
test ! -e "$source_root/capsule-inside-source"

expect_fail "output directory reuse" "$tool" collect \
	--request "$base_request" \
	--source-root "$source_root" \
	--source-root-id fixture-source-root \
	--output "$capsule" \
	--collector-id fixture-collector

printf 'PASS evidence-capsule-v1 positive=%d negative=%d\n' \
	"$pass_count" "$fail_count"
