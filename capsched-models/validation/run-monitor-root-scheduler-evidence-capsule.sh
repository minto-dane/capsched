#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
umask 077

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
COMMON_GIT_DIR=$(git -C "$PROJECT_DIR" rev-parse --path-format=absolute --git-common-dir)
CONTROL_REPOSITORY=$(dirname "$COMMON_GIT_DIR")
WORKSPACE_DIR=${WORKSPACE_DIR:-$(dirname "$CONTROL_REPOSITORY")}

CONTRACT="$SCRIPT_DIR/monitor-root-scheduler-evidence-contract-v1.json"
VALIDATOR="$SCRIPT_DIR/validate-monitor-root-scheduler-capsule.py"
COLLECTOR="$SCRIPT_DIR/evidence-capsule-v1/evidence_capsule_v1.py"
TLA_JAR=${TLA_JAR:-/home/nia/tools/tla/tla2tools.jar}
RUN_ID=${ROOTSCHED_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-rootsched-ec1}

case "$RUN_ID" in
	""|[!A-Za-z0-9]*|*[!A-Za-z0-9._+-]*)
		echo "invalid ROOTSCHED_RUN_ID: $RUN_ID" >&2
		exit 2
		;;
esac

RUN_PARENT="$WORKSPACE_DIR/build/evidence-producer/monitor-root-scheduler/$RUN_ID"
SOURCE_ROOT="$RUN_PARENT/source"
REQUEST="$RUN_PARENT/capture-request.json"
CAPSULE="$WORKSPACE_DIR/build/evidence-capsules/monitor-root-scheduler/$RUN_ID"
VALIDATOR_RESULT="$RUN_PARENT/validator-result.json"

for path in "$RUN_PARENT" "$CAPSULE"; do
	if [[ -e "$path" ]]; then
		echo "refusing to reuse existing path: $path" >&2
		exit 2
	fi
done

for command in git jq java timeout sha256sum python3; do
	command -v "$command" >/dev/null
done

if [[ -n $(git -C "$PROJECT_DIR" status --porcelain=v1) ]]; then
	echo "control repository must be clean before evidence production" >&2
	exit 2
fi

MODEL_COMMIT=$(jq -er '.origin_model.commit' "$CONTRACT")
MODEL_TREE=$(jq -er '.origin_model.tree' "$CONTRACT")
ACTUAL_MODEL_TREE=$(git -C "$PROJECT_DIR" rev-parse "$MODEL_COMMIT^{tree}")
if [[ "$ACTUAL_MODEL_TREE" != "$MODEL_TREE" ]]; then
	echo "origin model tree mismatch" >&2
	exit 2
fi

TOOL_SHA=$(jq -er '.tool.sha256' "$CONTRACT")
if [[ $(sha256sum "$TLA_JAR" | awk '{print $1}') != "$TOOL_SHA" ]]; then
	echo "TLC tool digest mismatch" >&2
	exit 2
fi

mkdir -p "$SOURCE_ROOT/inputs/model" "$SOURCE_ROOT/inputs/tools"
mkdir -p "$SOURCE_ROOT/raw/tlc" "$SOURCE_ROOT/work"

install -m 0444 "$CONTRACT" "$SOURCE_ROOT/inputs/contract.json"
install -m 0555 "$0" "$SOURCE_ROOT/inputs/producer-runner.sh"
install -m 0555 "$VALIDATOR" "$SOURCE_ROOT/inputs/claim-validator.py"
install -m 0444 "$TLA_JAR" "$SOURCE_ROOT/inputs/tools/tla2tools.jar"

while IFS=$'\t' read -r repository_path run_path expected_sha; do
	destination="$SOURCE_ROOT/$run_path"
	mkdir -p "$(dirname "$destination")"
	git -C "$PROJECT_DIR" show "$MODEL_COMMIT:$repository_path" >"$destination"
	chmod 0444 "$destination"
	actual_sha=$(sha256sum "$destination" | awk '{print $1}')
	if [[ "$actual_sha" != "$expected_sha" ]]; then
		echo "static input digest mismatch: $run_path" >&2
		exit 2
	fi
done < <(jq -r '.static_inputs[] | [.repository_path, .run_path, .sha256] | @tsv' "$CONTRACT")

jq '{
  schema_version: 1,
  runs: [.expected_runs[] | {
    id: .id,
    cwd: "inputs/model",
    argv: [
      "java",
      "-XX:+UseParallelGC",
      "-cp",
      "../tools/tla2tools.jar",
      "tlc2.TLC",
      "-workers",
      "2",
      "-metadir",
      ("../../work/states-" + .id),
      "-config",
      .config,
      "MonitorRootScheduler.tla"
    ]
  }]
}' "$CONTRACT" >"$SOURCE_ROOT/inputs/commands.json"

JAVA_VERSION=$(java -version 2>&1 | head -n 1)
HOST_UNAME=$(uname -a)
VALIDATION_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)
jq -n \
	--arg java_version "$JAVA_VERSION" \
	--arg host_uname "$HOST_UNAME" \
	--arg tool_sha256 "$TOOL_SHA" \
	--arg origin_model_commit "$MODEL_COMMIT" \
	--arg origin_model_tree "$MODEL_TREE" \
	--arg validation_tool_commit "$VALIDATION_COMMIT" \
	'{
          schema_version: 1,
          java_version: $java_version,
          host_uname: $host_uname,
          tool_sha256: $tool_sha256,
          origin_model_commit: $origin_model_commit,
          origin_model_tree: $origin_model_tree,
          validation_tool_commit: $validation_tool_commit,
          locale: "C"
        }' >"$SOURCE_ROOT/inputs/environment.json"

MAX_SECONDS=$(jq -er '.tool.maximum_run_seconds' "$CONTRACT")
mapfile -t RUN_ROWS < <(jq -r '.expected_runs[] | [.id, .config] | @tsv' "$CONTRACT")
if [[ ${#RUN_ROWS[@]} -ne 12 ]]; then
	echo "contract must declare exactly 12 TLC runs" >&2
	exit 2
fi

for row in "${RUN_ROWS[@]}"; do
	IFS=$'\t' read -r run_name config_name <<<"$row"
	log="$SOURCE_ROOT/raw/tlc/$run_name.log"
	status_file="$SOURCE_ROOT/raw/tlc/$run_name.status"
	set +e
	(
		cd "$SOURCE_ROOT/inputs/model"
		timeout "$MAX_SECONDS" java -XX:+UseParallelGC \
			-cp ../tools/tla2tools.jar tlc2.TLC \
			-workers 2 \
			-metadir "../../work/states-$run_name" \
			-config "$config_name" \
			MonitorRootScheduler.tla
	) >"$log" 2>&1
	status=$?
	set -e
	printf '%s\n' "$status" >"$status_file"
done

find "$SOURCE_ROOT/work" -depth -delete
chmod 0444 "$SOURCE_ROOT/inputs/commands.json" \
	"$SOURCE_ROOT/inputs/environment.json" \
	"$SOURCE_ROOT"/raw/tlc/*

git -C "$SOURCE_ROOT" init -q
git -C "$SOURCE_ROOT" config user.name "DomainLease Evidence Producer"
git -C "$SOURCE_ROOT" config user.email "evidence@domainlease.invalid"
git -C "$SOURCE_ROOT" add inputs raw
git -C "$SOURCE_ROOT" commit -q -m "ROOTSCHED-001 captured TLC producer output"

if [[ -n $(git -C "$SOURCE_ROOT" status --porcelain=v1) ]]; then
	echo "producer source Git repository is not clean" >&2
	exit 2
fi

SOURCE_COMMIT=$(git -C "$SOURCE_ROOT" rev-parse HEAD)
SOURCE_TREE=$(git -C "$SOURCE_ROOT" rev-parse HEAD^{tree})
OBJECT_FORMAT=$(git -C "$SOURCE_ROOT" rev-parse --show-object-format)
CONTRACT_SHA=$(sha256sum "$SOURCE_ROOT/inputs/contract.json" | awk '{print $1}')

jq -n \
	--arg producer_identity "ROOTSCHED-001-TLC-producer-v1" \
	--arg contract_id "ROOTSCHED-001-TLC-v1" \
	--arg contract_sha "$CONTRACT_SHA" \
	--arg object_format "$OBJECT_FORMAT" \
	--arg source_commit "$SOURCE_COMMIT" \
	--arg source_tree "$SOURCE_TREE" \
	--slurpfile contract "$CONTRACT" \
	--slurpfile environment "$SOURCE_ROOT/inputs/environment.json" \
	'{
          schema_version: 1,
          capsule_kind: "formal_validation",
          producer_identity: $producer_identity,
          experiment_contract: {
            id: $contract_id,
            object_path: "inputs/contract.json",
            sha256: $contract_sha
          },
          target_claims: ["ROOTSCHED-001"],
          source_identity: {
            kind: "git",
            repository: "ROOTSCHED-001-EC1-run",
            object_format: $object_format,
            commit: $source_commit,
            tree: $source_tree,
            parents: [],
            dirty: false
          },
          declared_environment: $environment[0],
          completeness_rule: {
            allow_extra_files: false,
            required_capsule_paths: [$contract[0].capture_objects[].capsule_path]
          },
          objects: $contract[0].capture_objects
        }' >"$REQUEST"
chmod 0444 "$REQUEST"

mkdir -p "$(dirname "$CAPSULE")"
python3 "$COLLECTOR" collect \
	--request "$REQUEST" \
	--source-root "$SOURCE_ROOT" \
	--source-root-id "$RUN_ID" \
	--output "$CAPSULE" \
	--collector-id "ROOTSCHED-001-EC1-collector-v1" \
	--max-request-bytes 1048576 \
	--max-objects 64 \
	--max-object-bytes 4194304 \
	--max-total-bytes 33554432 >"$RUN_PARENT/collector-result.json"

python3 "$COLLECTOR" verify --capsule "$CAPSULE" \
	>"$RUN_PARENT/structural-result.json"

python3 "$VALIDATOR" \
	--capsule "$CAPSULE" \
	--output "$VALIDATOR_RESULT" \
	>"$RUN_PARENT/validator-console.json"

jq -n \
	--slurpfile collector "$RUN_PARENT/collector-result.json" \
	--slurpfile validator "$VALIDATOR_RESULT" \
	--arg run_id "$RUN_ID" \
	--arg capsule "$CAPSULE" \
	--arg validator_result "$VALIDATOR_RESULT" \
	'{
          status: $validator[0].status,
          run_id: $run_id,
          capsule_id: $collector[0].capsule_id,
          capsule: $capsule,
          validator_result: $validator_result
        }'
