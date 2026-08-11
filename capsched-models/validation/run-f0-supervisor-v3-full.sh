#!/usr/bin/env -S -u BASH_ENV -u ENV /bin/bash --noprofile --norc -p
set -Eeuo pipefail

CAPSCHED_PRIVILEGED_ARG_PRESENT=$(
    LD_PRELOAD= LD_LIBRARY_PATH= /usr/bin/env -i PATH=/usr/bin:/bin \
        /usr/bin/python3 -I -S -B -c '
import os
from pathlib import Path
import sys

pid = sys.argv[1]
script = os.path.realpath(sys.argv[2])
argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
argv = [os.fsdecode(item) for item in argv if item]
try:
    script_index = next(
        index
        for index, item in enumerate(argv[1:], start=1)
        if os.path.realpath(item) == script
    )
except StopIteration:
    raise SystemExit(1)
option_prefix = argv[1:script_index]
valid = bool(
    "-p" in option_prefix
    and "-c" not in option_prefix
    and all(item.startswith("-") for item in option_prefix)
)
print("true" if valid else "false")
' "$$" "${BASH_SOURCE[0]}"
) || CAPSCHED_PRIVILEGED_ARG_PRESENT=false
readonly CAPSCHED_PRIVILEGED_ARG_PRESENT

if [[ ${BASH_SOURCE[0]} != "$0" ||
      $- != *p* ||
      ${CAPSCHED_PRIVILEGED_ARG_PRESENT} != true ]]; then
    printf '%s\n' \
        'runner requires a direct top-level Bash -p script launch' >&2
    while [[ 1 == 1 ]]; do
        LD_PRELOAD= LD_LIBRARY_PATH= /bin/kill -KILL "$$"
    done
fi

umask 077
PATH=/usr/bin:/bin
export PATH
readonly PATH

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORKTREE_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)
RESULTS_ROOT=${CAPSCHED_RESULTS_ROOT:-${WORKTREE_ROOT}/build/results/f0-supervisor-v3}
STAMP=${CAPSCHED_RUN_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_DIR=${RESULTS_ROOT}/${STAMP}
SNAPSHOT_DIR=${RUN_DIR}/input
LOG=${RUN_DIR}/run.log
RESULT=${RUN_DIR}/result.json
STATUS_FILE=${RUN_DIR}/status
RUNNER_EVIDENCE=${RUN_DIR}/runner-evidence.json
EXPECTED_MANIFEST=${CAPSCHED_EXPECTED_MANIFEST:-}
TIMEOUT_SECONDS=${CAPSCHED_TIMEOUT_SECONDS:-}
TIMEOUT_KILL_AFTER_SECONDS=${CAPSCHED_TIMEOUT_KILL_AFTER_SECONDS:-30}
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PYTHON_BIN=/usr/bin/python3

FINALIZED=0
FINAL_STATUS=""
SNAPSHOT_CAPTURED=0
VALIDATOR_RESULT_STATUS=""
VALIDATOR_PID=""
VALIDATOR_RC=""
TIMEOUT_WATCHDOG_PID=""
VALIDATOR_STARTED_NS=""
VALIDATOR_FINISHED_NS=""
TIMEOUT_OCCURRED=0
VALIDATOR_GROUP_EMPTY_AFTER_CLEANUP=0
CAPTURED_RESULT_SHA256=""
CAPTURED_EXPECTED_MANIFEST_SHA256=""
CAPTURED_BEFORE_MANIFEST_SHA256=""

INPUTS=(
    f0-supervisor-c4-claim-registry-v1.json
    f0_supervisor_lts_v3.py
    f0_supervisor_orchestrator_v3.py
    test-f0-supervisor-lts-v3-mutations.py
    test-f0-supervisor-orchestrator-v3-mutations.py
    test-run-f0-supervisor-v3-full.sh
    validate-f0-supervisor-lts-v3.py
    run-f0-supervisor-v3-full.sh
)

atomic_status() {
    local status=$1
    local temporary

    temporary=$(new_run_temp status) || return 1
    if ! printf '%s\n' "${status}" > "${temporary}" ||
       ! mv -f -- "${temporary}" "${STATUS_FILE}"; then
        rm -f -- "${temporary}"
        return 1
    fi
}

new_run_temp() {
    local label=$1

    /usr/bin/mktemp --tmpdir="${RUN_DIR}" ".${label}.XXXXXX"
}

file_sha256() {
    local output

    output=$(sha256sum -- "$1") || return 1
    printf '%s' "${output%% *}"
}

monotonic_ns() {
    env -i PATH=/usr/bin:/bin "${PYTHON_BIN}" -I -S -B -c \
        'import time; print(time.monotonic_ns())'
}

write_runner_evidence() {
    local terminal_status=$1
    local requested_status=$2
    local returncode=$3
    local detail=$4
    local hashes_equal_before_after=$5
    local result_present=$6
    local result_sha256=$7
    local expected_manifest_sha256=$8
    local before_manifest_sha256=$9
    local after_manifest_sha256=${10}
    local expected_manifest_match=${11}
    local manifest_files_unchanged=${12}
    local parsed_result_sha256=${13}
    local parsed_final_result_match=${14}
    local temporary
    local finalized_at

    finalized_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    temporary=$(new_run_temp runner-evidence) || return 1
    if ! env -i PATH=/usr/bin:/bin "${PYTHON_BIN}" -I -S -B - \
        "${temporary}" \
        "${terminal_status}" \
        "${requested_status}" \
        "${returncode}" \
        "${detail}" \
        "${STARTED_AT}" \
        "${finalized_at}" \
        "${WORKTREE_ROOT}" \
        "${RUN_DIR}" \
        "${SNAPSHOT_DIR}" \
        "${hashes_equal_before_after}" \
        "${result_present}" \
        "${result_sha256}" \
        "${expected_manifest_sha256}" \
        "${before_manifest_sha256}" \
        "${after_manifest_sha256}" \
        "${expected_manifest_match}" \
        "${manifest_files_unchanged}" \
        "${CAPTURED_EXPECTED_MANIFEST_SHA256}" \
        "${CAPTURED_BEFORE_MANIFEST_SHA256}" \
        "${VALIDATOR_RESULT_STATUS}" \
        "${parsed_result_sha256}" \
        "${parsed_final_result_match}" \
        "${VALIDATOR_RC}" \
        "${TIMEOUT_SECONDS}" \
        "${TIMEOUT_KILL_AFTER_SECONDS}" \
        "${VALIDATOR_STARTED_NS}" \
        "${VALIDATOR_FINISHED_NS}" \
        "${TIMEOUT_OCCURRED}" \
        "${VALIDATOR_GROUP_EMPTY_AFTER_CLEANUP}" \
        "${PYTHON_BIN}" <<'PY'
import base64
import json
import hashlib
import os
import stat
import sys

(
    output,
    terminal_status,
    requested_status,
    returncode,
    detail,
    started_at,
    finalized_at,
    worktree_root,
    run_dir,
    snapshot_dir,
    hashes_equal_before_after,
    result_present,
    result_sha256,
    expected_manifest_sha256,
    before_manifest_sha256,
    after_manifest_sha256,
    expected_manifest_match,
    manifest_files_unchanged,
    captured_expected_manifest_sha256,
    captured_before_manifest_sha256,
    validator_result_status,
    parsed_result_sha256,
    parsed_final_result_match,
    validator_returncode,
    timeout_seconds,
    timeout_kill_after_seconds,
    validator_started_ns,
    validator_finished_ns,
    timeout_occurred,
    validator_group_empty_after_cleanup,
    python_bin,
) = sys.argv[1:]


def digest_file(path):
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def optional_int(value):
    return int(value) if value else None


document = {
    "schema_version": 1,
    "artifact_id": "f0-supervisor-v3-candidate4-runner-evidence",
    "terminal_status": terminal_status,
    "requested_terminal_status": requested_status,
    "returncode": int(returncode),
    "detail": detail,
    "started_at_utc": started_at,
    "finalized_at_utc": finalized_at,
    "source_worktree": worktree_root,
    "run_directory": run_dir,
    "captured_snapshot_directory": snapshot_dir,
    "input_hashes_equal_before_after": hashes_equal_before_after == "true",
    "caller_expected_manifest_match": expected_manifest_match == "true",
    "manifest_files_unchanged_since_capture": (
        manifest_files_unchanged == "true"
    ),
    "caller_expected_capture_and_final_hash_match": bool(
        hashes_equal_before_after == "true"
        and expected_manifest_match == "true"
        and manifest_files_unchanged == "true"
    ),
    "runtime_input_write_prevention_enforced": False,
    "input_stability_during_execution_proved": False,
    "captured_expected_manifest_sha256": (
        captured_expected_manifest_sha256 or None
    ),
    "captured_before_manifest_sha256": (
        captured_before_manifest_sha256 or None
    ),
    "expected_manifest_sha256": expected_manifest_sha256 or None,
    "input_manifest_before_sha256": before_manifest_sha256 or None,
    "input_manifest_after_sha256": after_manifest_sha256 or None,
    "validator_result_present": result_present == "true",
    "validator_result_sha256": result_sha256 or None,
    "parsed_validator_result_sha256": parsed_result_sha256 or None,
    "parsed_and_final_result_bytes_match": (
        parsed_final_result_match == "true"
    ),
    "validator_result_status": validator_result_status or None,
    "validator_returncode": optional_int(validator_returncode),
    "configured_timeout_seconds": optional_int(timeout_seconds),
    "timeout_kill_after_seconds": int(timeout_kill_after_seconds),
    "validator_started_monotonic_ns": optional_int(validator_started_ns),
    "validator_finished_monotonic_ns": optional_int(validator_finished_ns),
    "validator_elapsed_monotonic_ns": (
        int(validator_finished_ns) - int(validator_started_ns)
        if validator_started_ns and validator_finished_ns
        else None
    ),
    "configured_deadline_reached": timeout_occurred == "1",
    "term_to_kill_process_group_escalation_bounded": True,
    "validator_process_group_empty_after_cleanup": (
        validator_group_empty_after_cleanup == "1"
    ),
    "post_finalization_storage_immutability_proved": False,
    "toolchain_runtime_closure_proved": False,
    "python_interpreter": python_bin,
    "toolchain_sha256_at_finalization": {
        path: digest_file(path)
        for path in (
            "/bin/bash",
            "/usr/bin/python3",
            "/usr/bin/sha256sum",
            "/usr/bin/cmp",
            "/usr/bin/setsid",
        )
    },
    "toolchain_authenticated_by_external_root": False,
    "validator_descendant_containment_proved": False,
    "authorization": {
        "external_R11_review": False,
        "G0_authorized": False,
        "self_authorization": False,
        "F0_local_acceptance": False,
        "protection_claim": False,
    },
}

flags = os.O_WRONLY | os.O_TRUNC | os.O_CLOEXEC
if hasattr(os, "O_NOFOLLOW"):
    flags |= os.O_NOFOLLOW
descriptor = os.open(output, flags)
metadata = os.fstat(descriptor)
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
    os.close(descriptor)
    raise RuntimeError("runner evidence temporary is not a private regular file")
with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
    json.dump(document, handle, indent=2, sort_keys=True)
    handle.write("\n")
    handle.flush()
    os.fsync(handle.fileno())
PY
    then
        rm -f -- "${temporary}"
        return 1
    fi
    if ! mv -f -- "${temporary}" "${RUNNER_EVIDENCE}"; then
        rm -f -- "${temporary}"
        return 1
    fi
}

finalize_run() {
    local requested_status=$1
    local returncode=$2
    local detail=$3
    local terminal_status=${requested_status}
    local hashes_equal_before_after=false
    local result_present=false
    local result_sha256=""
    local expected_manifest_sha256=""
    local before_manifest_sha256=""
    local after_manifest_sha256=""
    local expected_manifest_match=false
    local manifest_files_unchanged=false
    local parsed_final_result_match=false
    local evidence_complete=true
    local temporary=""

    if (( FINALIZED )); then
        return 0
    fi
    trap - HUP INT QUIT TERM

    if [[ -f "${RUN_DIR}/input-manifest.expected.sha256" ]]; then
        expected_manifest_sha256=$(file_sha256 \
            "${RUN_DIR}/input-manifest.expected.sha256") || evidence_complete=false
    fi

    if (( SNAPSHOT_CAPTURED )); then
        if temporary=$(new_run_temp input-manifest-after) && (
            cd "${SNAPSHOT_DIR}" &&
                sha256sum -- "${INPUTS[@]}"
        ) > "${temporary}"; then
            mv -f -- "${temporary}" "${RUN_DIR}/input-manifest.after.sha256"
        else
            [[ -z "${temporary}" ]] || rm -f -- "${temporary}"
            evidence_complete=false
        fi
    fi

    if [[ -f "${RUN_DIR}/input-manifest.before.sha256" ]]; then
        before_manifest_sha256=$(file_sha256 \
            "${RUN_DIR}/input-manifest.before.sha256") || evidence_complete=false
    fi
    if [[ -f "${RUN_DIR}/input-manifest.after.sha256" ]]; then
        after_manifest_sha256=$(file_sha256 \
            "${RUN_DIR}/input-manifest.after.sha256") || evidence_complete=false
    fi
    if [[ -f "${RUN_DIR}/input-manifest.before.sha256" ]] &&
        [[ -f "${RUN_DIR}/input-manifest.after.sha256" ]] &&
        cmp --silent \
            "${RUN_DIR}/input-manifest.before.sha256" \
            "${RUN_DIR}/input-manifest.after.sha256"; then
        hashes_equal_before_after=true
    fi
    if [[ -f "${RUN_DIR}/input-manifest.expected.sha256" ]] &&
        [[ -f "${RUN_DIR}/input-manifest.before.sha256" ]] &&
        cmp --silent \
            "${RUN_DIR}/input-manifest.expected.sha256" \
            "${RUN_DIR}/input-manifest.before.sha256"; then
        expected_manifest_match=true
    fi
    if [[ -n "${CAPTURED_EXPECTED_MANIFEST_SHA256}" ]] &&
        [[ -n "${CAPTURED_BEFORE_MANIFEST_SHA256}" ]] &&
        [[ "${expected_manifest_sha256}" == \
           "${CAPTURED_EXPECTED_MANIFEST_SHA256}" ]] &&
        [[ "${before_manifest_sha256}" == \
           "${CAPTURED_BEFORE_MANIFEST_SHA256}" ]]; then
        manifest_files_unchanged=true
    fi

    if [[ -f "${RESULT}" && ! -L "${RESULT}" ]]; then
        result_present=true
        temporary=$(new_run_temp result-sha256) || evidence_complete=false
        if result_sha256=$(file_sha256 "${RESULT}"); then
            if [[ -n "${CAPTURED_RESULT_SHA256}" &&
                  "${result_sha256}" == "${CAPTURED_RESULT_SHA256}" ]]; then
                parsed_final_result_match=true
            fi
            if [[ -n "${temporary}" ]] &&
               printf '%s  result.json\n' "${result_sha256}" > "${temporary}"; then
                mv -f -- "${temporary}" "${RUN_DIR}/result.sha256"
            else
                [[ -z "${temporary}" ]] || rm -f -- "${temporary}"
                evidence_complete=false
            fi
        else
            evidence_complete=false
        fi
    fi

    if (( SNAPSHOT_CAPTURED )) &&
       [[ "${hashes_equal_before_after}" != true ||
          "${manifest_files_unchanged}" != true ]]; then
        terminal_status=EVIDENCE_FINALIZATION_ERROR
        detail="${detail}; captured input or manifest endpoints changed"
    fi
    if [[ "${requested_status}" == COMPLETE_LOCAL_C4_CANDIDATE_ONLY ||
          "${requested_status}" == COMPLETE_LOCAL_C4_REJECTED ]]; then
        if [[ "${hashes_equal_before_after}" != true ||
              "${expected_manifest_match}" != true ||
              "${manifest_files_unchanged}" != true ||
              "${result_present}" != true ||
              "${parsed_final_result_match}" != true ]]; then
            terminal_status=EVIDENCE_FINALIZATION_ERROR
            detail="${detail}; complete result lacks hash-stable finalized evidence"
        fi
    fi
    if [[ "${evidence_complete}" != true ]]; then
        terminal_status=EVIDENCE_FINALIZATION_ERROR
        detail="${detail}; evidence hashing or finalization failed"
    fi

    if ! write_runner_evidence \
        "${terminal_status}" \
        "${requested_status}" \
        "${returncode}" \
        "${detail}" \
        "${hashes_equal_before_after}" \
        "${result_present}" \
        "${result_sha256}" \
        "${expected_manifest_sha256}" \
        "${before_manifest_sha256}" \
        "${after_manifest_sha256}" \
        "${expected_manifest_match}" \
        "${manifest_files_unchanged}" \
        "${CAPTURED_RESULT_SHA256}" \
        "${parsed_final_result_match}"; then
        terminal_status=EVIDENCE_FINALIZATION_ERROR
        printf '%s\n' \
            'runner evidence JSON finalization failed' >&2
    fi

    FINAL_STATUS=${terminal_status}
    if ! atomic_status "${FINAL_STATUS}"; then
        FINAL_STATUS=EVIDENCE_FINALIZATION_ERROR
        printf '%s\n' 'runner terminal status publication failed' >&2
    fi
    FINALIZED=1
}

reject_precondition() {
    local detail=$1

    printf '%s\n' "${detail}" >&2
    finalize_run PRECONDITION_REJECTED 64 "${detail}"
    exit 64
}

validator_group_live() {
    local group_id=$1

    kill -0 -- "-${group_id}" 2>/dev/null
}

terminate_validator_group() {
    local pid=$1
    local attempts=$((TIMEOUT_KILL_AFTER_SECONDS * 10))
    local attempt

    kill -TERM -- "-${pid}" 2>/dev/null ||
        kill -TERM -- "${pid}" 2>/dev/null || true
    for ((attempt = 0; attempt < attempts; attempt++)); do
        validator_group_live "${pid}" || return 0
        /bin/sleep 0.1
    done
    kill -KILL -- "-${pid}" 2>/dev/null ||
        kill -KILL -- "${pid}" 2>/dev/null || true
    for ((attempt = 0; attempt < 10; attempt++)); do
        validator_group_live "${pid}" || return 0
        /bin/sleep 0.1
    done
}

stop_timeout_watchdog() {
    if [[ -n "${TIMEOUT_WATCHDOG_PID}" ]]; then
        kill -TERM -- "${TIMEOUT_WATCHDOG_PID}" 2>/dev/null || true
        if wait "${TIMEOUT_WATCHDOG_PID}" 2>/dev/null; then
            :
        fi
        TIMEOUT_WATCHDOG_PID=""
    fi
}

timeout_watchdog() {
    local pid=$1
    local sleeper=""

    trap '
        if [[ -n "${sleeper}" ]]; then
            kill -TERM -- "${sleeper}" 2>/dev/null || true
            wait "${sleeper}" 2>/dev/null || true
        fi
        exit 0
    ' HUP INT QUIT TERM

    /bin/sleep "${TIMEOUT_SECONDS}" &
    sleeper=$!
    wait "${sleeper}" || return 0
    sleeper=""
    validator_group_live "${pid}" || return 0
    terminate_validator_group "${pid}"
}

on_signal() {
    local signal_name=$1
    local returncode=$2

    trap - HUP INT QUIT TERM
    stop_timeout_watchdog
    if [[ -n "${VALIDATOR_PID}" ]]; then
        terminate_validator_group "${VALIDATOR_PID}"
        if wait "${VALIDATOR_PID}" 2>/dev/null; then
            :
        fi
        if ! validator_group_live "${VALIDATOR_PID}"; then
            VALIDATOR_GROUP_EMPTY_AFTER_CLEANUP=1
        fi
        VALIDATOR_PID=""
    fi
    finalize_run INCOMPLETE_SIGNAL "${returncode}" \
        "runner received ${signal_name}"
    printf '%s\n' "${RUN_DIR}"
    exit "${returncode}"
}

on_exit() {
    local returncode=$?

    if (( ! FINALIZED )); then
        finalize_run TOOL_ERROR "${returncode}" \
            "runner exited before explicit terminal classification"
    fi
}

mkdir -p -- "${RESULTS_ROOT}"
if ! mkdir -- "${RUN_DIR}"; then
    printf 'run directory already exists or cannot be created: %s\n' \
        "${RUN_DIR}" >&2
    exit 73
fi
atomic_status RUNNING

trap on_exit EXIT
trap 'on_signal HUP 129' HUP
trap 'on_signal INT 130' INT
trap 'on_signal QUIT 131' QUIT
trap 'on_signal TERM 143' TERM

if ! mkdir -- "${SNAPSHOT_DIR}"; then
    reject_precondition 'failed to create captured snapshot directory'
fi

if [[ -z "${PYTHON_BIN}" || ! -x "${PYTHON_BIN}" ]]; then
    reject_precondition 'python3 is required'
fi
for command_name in sha256sum cmp cp chmod mv env setsid mktemp; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        reject_precondition "required command is missing: ${command_name}"
    fi
done
if [[ -z "${EXPECTED_MANIFEST}" || ! -f "${EXPECTED_MANIFEST}" ||
      -L "${EXPECTED_MANIFEST}" ]]; then
    reject_precondition \
        'CAPSCHED_EXPECTED_MANIFEST must name a caller-supplied regular SHA-256 manifest'
fi
if [[ -n "${TIMEOUT_SECONDS}" &&
      ! "${TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
    reject_precondition 'CAPSCHED_TIMEOUT_SECONDS must be a positive integer'
fi
if [[ ! "${TIMEOUT_KILL_AFTER_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
    reject_precondition \
        'CAPSCHED_TIMEOUT_KILL_AFTER_SECONDS must be a positive integer'
fi

for input in "${INPUTS[@]}"; do
    if [[ ! -f "${SCRIPT_DIR}/${input}" || -L "${SCRIPT_DIR}/${input}" ]]; then
        reject_precondition "model input is not a regular file: ${input}"
    fi
    if ! cp --reflink=auto -- \
        "${SCRIPT_DIR}/${input}" "${SNAPSHOT_DIR}/${input}"; then
        reject_precondition "failed to snapshot model input: ${input}"
    fi
done
if ! cp -- "${EXPECTED_MANIFEST}" \
    "${RUN_DIR}/input-manifest.expected.sha256"; then
    reject_precondition 'failed to snapshot caller expected manifest'
fi
if ! (
    cd "${SNAPSHOT_DIR}" &&
        sha256sum -- "${INPUTS[@]}"
) > "${RUN_DIR}/input-manifest.before.sha256"; then
    reject_precondition 'failed to hash captured input snapshot'
fi
SNAPSHOT_CAPTURED=1
CAPTURED_EXPECTED_MANIFEST_SHA256=$(file_sha256 \
    "${RUN_DIR}/input-manifest.expected.sha256") ||
    reject_precondition 'failed to hash captured expected manifest'
CAPTURED_BEFORE_MANIFEST_SHA256=$(file_sha256 \
    "${RUN_DIR}/input-manifest.before.sha256") ||
    reject_precondition 'failed to hash captured before manifest'

if ! cmp --silent \
    "${RUN_DIR}/input-manifest.expected.sha256" \
    "${RUN_DIR}/input-manifest.before.sha256"; then
    reject_precondition 'caller expected manifest does not match input snapshot'
fi
if ! chmod 0444 "${SNAPSHOT_DIR}"/* \
    "${RUN_DIR}/input-manifest.expected.sha256" \
    "${RUN_DIR}/input-manifest.before.sha256" ||
   ! chmod 0555 "${SNAPSHOT_DIR}"; then
    reject_precondition 'failed to make captured inputs read-only'
fi

{
    printf '[%s] supervisor v3 candidate-4 full local campaign\n' \
        "$(date --iso-8601=seconds)"
    printf 'worktree=%s\n' "${WORKTREE_ROOT}"
    printf 'snapshot=%s\n' "${SNAPSHOT_DIR}"
    printf 'result=%s\n' "${RESULT}"
    printf 'external_R11_review=false\n'
    printf 'G0_authorized=false\n'
    printf 'self_authorization=false\n'
    printf 'protection_claim=false\n'
} > "${LOG}"

VALIDATOR_COMMAND=(
    env -i
    PATH=/usr/bin:/bin
    PYTHONDONTWRITEBYTECODE=1
    PYTHONHASHSEED=0
    PYTHONPATH="${SNAPSHOT_DIR}"
    "${PYTHON_BIN}"
    -I
    -S
    -B
    "${SNAPSHOT_DIR}/validate-f0-supervisor-lts-v3.py"
    --full
    --output
    "${RESULT}"
)

VALIDATOR_STARTED_NS=$(monotonic_ns)
setsid --wait "${VALIDATOR_COMMAND[@]}" >> "${LOG}" 2>&1 &
VALIDATOR_PID=$!
if [[ -n "${TIMEOUT_SECONDS}" ]]; then
    timeout_watchdog "${VALIDATOR_PID}" &
    TIMEOUT_WATCHDOG_PID=$!
fi
if wait "${VALIDATOR_PID}"; then
    VALIDATOR_RC=0
else
    VALIDATOR_RC=$?
fi
VALIDATOR_FINISHED_NS=$(monotonic_ns)
stop_timeout_watchdog
if validator_group_live "${VALIDATOR_PID}"; then
    terminate_validator_group "${VALIDATOR_PID}"
fi
if ! validator_group_live "${VALIDATOR_PID}"; then
    VALIDATOR_GROUP_EMPTY_AFTER_CLEANUP=1
fi
if [[ -n "${TIMEOUT_SECONDS}" ]] &&
   (( VALIDATOR_FINISHED_NS - VALIDATOR_STARTED_NS >=
      TIMEOUT_SECONDS * 1000000000 )); then
    TIMEOUT_OCCURRED=1
fi
VALIDATOR_PID=""

if [[ -f "${RESULT}" && ! -L "${RESULT}" ]]; then
    VALIDATOR_RESULT_METADATA=$(
        env -i PATH=/usr/bin:/bin "${PYTHON_BIN}" -I -S -B -c '
import base64
import json
import hashlib
import os
import re
import stat
import sys

def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_nonfinite_constant(value):
    raise ValueError(f"non-standard JSON constant: {value}")


def canonical_json_bytes(value):
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        allow_nan=False,
    ).encode("ascii")


def is_plain_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def read_regular_once(path, limit):
    flags = os.O_RDONLY | os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise ValueError(f"not a regular file: {path}")
        if metadata.st_size > limit:
            raise ValueError(f"file exceeds size limit: {path}")
        chunks = []
        total = 0
        while True:
            chunk = os.read(descriptor, min(1024 * 1024, limit + 1 - total))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > limit:
                raise ValueError(f"file exceeds size limit: {path}")
        return b"".join(chunks)
    finally:
        os.close(descriptor)


result_payload = read_regular_once(sys.argv[1], 256 * 1024 * 1024)
registry_payload = read_regular_once(sys.argv[2], 1024 * 1024)
manifest_payload = read_regular_once(sys.argv[3], 1024 * 1024)
result_sha256 = hashlib.sha256(result_payload).hexdigest()
result = json.loads(
    result_payload.decode("utf-8"),
    object_pairs_hook=reject_duplicate_keys,
    parse_constant=reject_nonfinite_constant,
)
claim_registry = json.loads(
    registry_payload.decode("utf-8"),
    object_pairs_hook=reject_duplicate_keys,
    parse_constant=reject_nonfinite_constant,
)

expected_result_fields = {
    "schema_version",
    "artifact_id",
    "claim_registry",
    "status",
    "input_hashes_before",
    "input_hashes_after",
    "bootstrap_input_hashes",
    "post_model_load_input_hashes",
    "executed_model_source_hashes",
    "bootstrap_source_execution_check",
    "input_hashes_equal_before_after",
    "components",
    "component_execution_receipts",
    "child_action_registry",
    "claims",
    "open_refinement_obligations",
    "authorization",
    "provenance_boundary",
}
if set(result) != expected_result_fields:
    raise SystemExit("validator result top-level fields differ")

if not is_plain_int(result.get("schema_version")) or result["schema_version"] != 4:
    raise SystemExit("unexpected result schema")
if result.get("artifact_id") != (
    "dynamic-residency-f0-v5-supervisor-v3-candidate4-full-local-result"
):
    raise SystemExit("unexpected validator artifact")
status = result.get("status")
if status not in {
    "COMPLETE_LOCAL_C4_CANDIDATE_ONLY",
    "COMPLETE_LOCAL_C4_REJECTED",
}:
    raise SystemExit("unexpected validator result status")
authorization = result.get("authorization", {})
expected_authorization_fields = {
    "local_executable_candidate",
    "external_R11_review",
    "G0_authorized",
    "self_authorization",
    "standalone_child_bounded_exact_ordered_history_graph_exhaustive",
    "standalone_child_bounds",
    "declared_local_effect_commutation_checked",
    "independence_relation_complete",
    "commutation_projection_congruence",
    "global_semantic_confluence",
    "unbounded_ordered_history_state_space_exhaustive",
    "unbounded_repeated_store_attack_history_exhaustive",
    "attack_context_key_refinement",
    "parent_child_product_exhaustive",
    "external_authentication_assumption_discharged",
    "linux_refinement",
    "monitor_refinement",
    "resource_causality_implemented",
    "durable_store_refinement",
    "checker_soundness",
    "external_review",
    "semantic_verdict_issued",
    "F0_local_acceptance",
    "K0_G0_complete",
    "candidate_IR",
    "TLA_translation",
    "model_supported",
    "linux_behavior_change",
    "protection_claim",
}
if set(authorization) != expected_authorization_fields:
    raise SystemExit("validator authorization fields differ")
for field in (
    "external_R11_review",
    "G0_authorized",
    "self_authorization",
    "independence_relation_complete",
    "commutation_projection_congruence",
    "global_semantic_confluence",
    "unbounded_ordered_history_state_space_exhaustive",
    "unbounded_repeated_store_attack_history_exhaustive",
    "attack_context_key_refinement",
    "parent_child_product_exhaustive",
    "external_authentication_assumption_discharged",
    "linux_refinement",
    "monitor_refinement",
    "resource_causality_implemented",
    "durable_store_refinement",
    "checker_soundness",
    "external_review",
    "semantic_verdict_issued",
    "F0_local_acceptance",
    "K0_G0_complete",
    "candidate_IR",
    "TLA_translation",
    "model_supported",
    "linux_behavior_change",
    "protection_claim",
):
    if authorization.get(field) is not False:
        raise SystemExit(f"authorization field is not false: {field}")
expected_local_candidate = status == "COMPLETE_LOCAL_C4_CANDIDATE_ONLY"
if authorization.get("local_executable_candidate") is not expected_local_candidate:
    raise SystemExit("local candidate authorization does not match status")
if authorization.get("standalone_child_bounds") != {
    "hostile_attempts": 2,
    "reacquisitions": 2,
}:
    raise SystemExit("standalone child bounds differ")
if not all(
    is_plain_int(value) and value == 2
    for value in authorization["standalone_child_bounds"].values()
):
    raise SystemExit("standalone child bounds have invalid types")
for field in (
    "standalone_child_bounded_exact_ordered_history_graph_exhaustive",
    "declared_local_effect_commutation_checked",
):
    if authorization.get(field) not in {True, False}:
        raise SystemExit(f"local bounded authorization is not Boolean: {field}")
    if expected_local_candidate and authorization[field] is not True:
        raise SystemExit(f"candidate lacks required local bounded fact: {field}")
if result.get("input_hashes_equal_before_after") is not True:
    raise SystemExit("validator input hashes changed between checks")
expected_inputs = {
    "f0-supervisor-c4-claim-registry-v1.json",
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
    "test-f0-supervisor-lts-v3-mutations.py",
    "test-f0-supervisor-orchestrator-v3-mutations.py",
    "test-run-f0-supervisor-v3-full.sh",
    "validate-f0-supervisor-lts-v3.py",
    "run-f0-supervisor-v3-full.sh",
}
manifest_lines = manifest_payload.decode("ascii").splitlines()
snapshot_hashes = {}
for line in manifest_lines:
    match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
    if match is None:
        raise SystemExit("captured input manifest has an invalid line")
    digest, name = match.groups()
    if name in snapshot_hashes:
        raise SystemExit("captured input manifest has a duplicate name")
    snapshot_hashes[name] = digest
if set(snapshot_hashes) != expected_inputs:
    raise SystemExit("captured input manifest fields differ")
hash_maps = (
    result.get("bootstrap_input_hashes"),
    result.get("post_model_load_input_hashes"),
    result.get("input_hashes_before"),
    result.get("input_hashes_after"),
)
if any(not isinstance(item, dict) or set(item) != expected_inputs for item in hash_maps):
    raise SystemExit("validator input hash-map fields differ")
if any(
    not isinstance(digest, str)
    or re.fullmatch(r"[0-9a-f]{64}", digest) is None
    for item in hash_maps
    for digest in item.values()
):
    raise SystemExit("validator input hash map contains an invalid digest")
if not all(item == hash_maps[0] for item in hash_maps[1:]):
    raise SystemExit("validator input hash maps differ")
if hash_maps[0] != snapshot_hashes:
    raise SystemExit("validator input hashes differ from captured snapshot")
executed_hashes = result.get("executed_model_source_hashes")
if set(executed_hashes or {}) != {
    "f0_supervisor_lts_v3.py",
    "f0_supervisor_orchestrator_v3.py",
}:
    raise SystemExit("executed model source hash fields differ")
for name, digest in executed_hashes.items():
    if digest != hash_maps[0][name]:
        raise SystemExit(f"executed model source hash differs: {name}")
provenance = result.get("provenance_boundary", {})
if set(provenance) != {
    "symbolic_model_workload_input",
    "symbolic_model_workload_input_is_source_manifest",
    "source_files_bound_by_input_hashes",
    "source_file_bytes_hashed_before_and_after_local_checks",
    "model_modules_compiled_from_bootstrap_hashed_source_bytes",
    "validator_source_execution_bound_by_external_launcher",
    "raw_component_stdout_receipts_bound_to_components",
    "component_execution_receipts_externally_attested",
    "runtime_input_write_prevention_enforced",
    "input_stability_during_execution_proved",
    "external_R11_evidence_present",
    "G0_evidence_present",
}:
    raise SystemExit("validator provenance fields differ")
if provenance.get("symbolic_model_workload_input") != "input-root-a":
    raise SystemExit("validator symbolic workload identity differs")
if provenance.get("symbolic_model_workload_input_is_source_manifest") is not False:
    raise SystemExit("validator overclaims symbolic workload provenance")
if provenance.get("source_files_bound_by_input_hashes") is not False:
    raise SystemExit("validator overclaims direct source execution binding")
if provenance.get(
    "source_file_bytes_hashed_before_and_after_local_checks"
) is not True:
    raise SystemExit("validator did not report before/after source hashing")
if provenance.get(
    "model_modules_compiled_from_bootstrap_hashed_source_bytes"
) is not True:
    raise SystemExit("validator did not bind model compilation to source bytes")
if provenance.get(
    "validator_source_execution_bound_by_external_launcher"
) is not False:
    raise SystemExit("validator self-claimed launcher execution binding")
if provenance.get(
    "raw_component_stdout_receipts_bound_to_components"
) is not True:
    raise SystemExit("validator omitted raw component stdout binding")
if provenance.get(
    "component_execution_receipts_externally_attested"
) is not False:
    raise SystemExit("validator overclaimed component receipt attestation")
if provenance.get("runtime_input_write_prevention_enforced") is not False:
    raise SystemExit("validator overclaimed runtime input write prevention")
if provenance.get("input_stability_during_execution_proved") is not False:
    raise SystemExit("validator overclaimed continuous input stability")
if provenance.get("external_R11_evidence_present") is not False:
    raise SystemExit("validator overclaimed external R11 evidence")
if provenance.get("G0_evidence_present") is not False:
    raise SystemExit("validator overclaimed G0 evidence")
if result.get("bootstrap_source_execution_check") is not True:
    raise SystemExit("validator bootstrap source execution check failed")
if set(result.get("components", {})) != {
    "static-registries",
    "tests",
    "child-bundle-producer",
    "child-bundle-checker",
    "orchestrator",
}:
    raise SystemExit("validator component set differs")
components = result["components"]
component_receipts = result.get("component_execution_receipts")
if not isinstance(component_receipts, dict) or set(component_receipts) != set(
    components
):
    raise SystemExit("validator component receipt set differs")
input_root_sha256 = hashlib.sha256(
    json.dumps(
        snapshot_hashes,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
expected_model_hashes = {
    "f0_supervisor_lts_v3.py": snapshot_hashes["f0_supervisor_lts_v3.py"],
    "f0_supervisor_orchestrator_v3.py": snapshot_hashes[
        "f0_supervisor_orchestrator_v3.py"
    ],
}
expected_validator_path = os.path.join(
    os.path.realpath(sys.argv[4]),
    "validate-f0-supervisor-lts-v3.py",
)
receipt_fields = {
    "schema_version",
    "component",
    "argv",
    "returncode",
    "termination",
    "input_root_sha256",
    "stdout_base64",
    "stdout_sha256",
    "stderr_base64",
    "stderr_sha256",
    "result_payload_sha256",
    "capture_authority",
    "externally_attested",
    "descendant_containment_proved",
}
worker_provenance_fields = {
    "bootstrap_input_hashes",
    "post_model_load_input_hashes",
    "input_hashes_before",
    "input_hashes_after",
    "input_root_sha256",
    "executed_model_source_hashes",
    "bootstrap_source_execution_check",
    "runtime_input_write_prevention_enforced",
    "input_stability_during_execution_proved",
}
for component_name, receipt in component_receipts.items():
    if not isinstance(receipt, dict) or set(receipt) != receipt_fields:
        raise SystemExit(f"component receipt fields differ: {component_name}")
    expected_argv = [
        "/usr/bin/python3",
        "-S",
        "-B",
        expected_validator_path,
        "--component",
        component_name,
    ]
    if (
        not is_plain_int(receipt["schema_version"])
        or receipt["schema_version"] != 1
        or receipt["component"] != component_name
        or receipt["argv"] != expected_argv
        or not is_plain_int(receipt["returncode"])
        or receipt["returncode"] != 0
        or receipt["termination"] != "EXITED_ZERO"
        or receipt["input_root_sha256"] != input_root_sha256
        or receipt["capture_authority"]
        != "candidate_validator_local_process"
        or receipt["externally_attested"] is not False
        or receipt["descendant_containment_proved"] is not False
    ):
        raise SystemExit(f"component receipt identity differs: {component_name}")
    try:
        stdout_payload = base64.b64decode(
            receipt["stdout_base64"], validate=True
        )
        stderr_payload = base64.b64decode(
            receipt["stderr_base64"], validate=True
        )
    except (ValueError, TypeError) as error:
        raise SystemExit(
            f"component receipt base64 differs: {component_name}"
        ) from error
    if (
        hashlib.sha256(stdout_payload).hexdigest() != receipt["stdout_sha256"]
        or hashlib.sha256(stderr_payload).hexdigest() != receipt["stderr_sha256"]
        or stderr_payload != b""
    ):
        raise SystemExit(f"component receipt byte hashes differ: {component_name}")
    stdout_lines = stdout_payload.splitlines()
    marker = b"RESULT_JSON="
    if len(stdout_lines) != 1 or not stdout_lines[0].startswith(marker):
        raise SystemExit(f"component receipt stdout shape differs: {component_name}")
    component_payload = stdout_lines[0][len(marker) :]
    if hashlib.sha256(component_payload).hexdigest() != receipt[
        "result_payload_sha256"
    ]:
        raise SystemExit(f"component result payload hash differs: {component_name}")
    raw_component = json.loads(
        component_payload.decode("utf-8"),
        object_pairs_hook=reject_duplicate_keys,
        parse_constant=reject_nonfinite_constant,
    )
    if canonical_json_bytes(raw_component) != canonical_json_bytes(
        components[component_name]
    ):
        raise SystemExit(f"component raw result differs: {component_name}")
    worker = raw_component.get("worker_provenance")
    if not isinstance(worker, dict) or set(worker) != worker_provenance_fields:
        raise SystemExit(f"component worker provenance differs: {component_name}")
    worker_hash_maps = (
        worker["bootstrap_input_hashes"],
        worker["post_model_load_input_hashes"],
        worker["input_hashes_before"],
        worker["input_hashes_after"],
    )
    if not all(item == snapshot_hashes for item in worker_hash_maps):
        raise SystemExit(f"component worker hashes differ: {component_name}")
    if (
        worker["input_root_sha256"] != input_root_sha256
        or worker["executed_model_source_hashes"] != expected_model_hashes
        or worker["bootstrap_source_execution_check"] is not True
        or worker["runtime_input_write_prevention_enforced"] is not False
        or worker["input_stability_during_execution_proved"] is not False
    ):
        raise SystemExit(f"component worker boundary differs: {component_name}")
component_receipts_bound = True


def require_exact_keys(value, expected, label):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise SystemExit(f"nested component fields differ: {label}")


require_exact_keys(
    components["static-registries"],
    {
        "component",
        "claim_registry",
        "child",
        "orchestrator",
        "declared_independence_ids",
        "declared_independence_ids_unique",
        "semantic_registry_sha256",
        "typed_store_attack_registry_exact",
        "reachability_checked",
        "passed",
        "worker_provenance",
    },
    "static-registries",
)
require_exact_keys(
    components["static-registries"]["claim_registry"],
    {"artifact_id", "claim_count", "sha256", "candidate_authority_all_false"},
    "static-registries.claim_registry",
)
static_side_fields = {
    "declared_action_count",
    "write_policy_count",
    "write_policy_exact_registry_coverage",
    "required_write_policy_count",
    "required_write_policy_exact_registry_coverage",
    "required_writes_are_allowed",
}
require_exact_keys(
    components["static-registries"]["child"],
    static_side_fields,
    "static-registries.child",
)
require_exact_keys(
    components["static-registries"]["orchestrator"],
    static_side_fields,
    "static-registries.orchestrator",
)
static_result = components["static-registries"]
static_claim_registry = static_result["claim_registry"]
if (
    static_result["component"] != "static-registries"
    or static_claim_registry["artifact_id"] != claim_registry["artifact_id"]
    or static_claim_registry["claim_count"] != len(claim_registry["claims"])
    or static_claim_registry["sha256"]
    != hashlib.sha256(registry_payload).hexdigest()
    or static_claim_registry["candidate_authority_all_false"] is not True
    or not isinstance(static_result["declared_independence_ids"], list)
    or not static_result["declared_independence_ids"]
    or not all(
        isinstance(item, str) and item
        for item in static_result["declared_independence_ids"]
    )
    or len(static_result["declared_independence_ids"])
    != len(set(static_result["declared_independence_ids"]))
    or static_result["declared_independence_ids_unique"] is not True
    or not isinstance(static_result["semantic_registry_sha256"], str)
    or re.fullmatch(
        r"[0-9a-f]{64}", static_result["semantic_registry_sha256"]
    )
    is None
    or static_result["typed_store_attack_registry_exact"] is not True
    or static_result["reachability_checked"] is not False
    or static_result["passed"] not in {True, False}
):
    raise SystemExit("nested static registry values differ")
for side_name in ("child", "orchestrator"):
    side = static_result[side_name]
    if (
        not all(
            isinstance(side[field], int)
            and not isinstance(side[field], bool)
            and side[field] > 0
            for field in (
                "declared_action_count",
                "write_policy_count",
                "required_write_policy_count",
            )
        )
        or side["write_policy_count"] != side["declared_action_count"]
        or side["required_write_policy_count"] != side["declared_action_count"]
        or side["write_policy_exact_registry_coverage"] is not True
        or side["required_write_policy_exact_registry_coverage"] is not True
        or side["required_writes_are_allowed"] is not True
    ):
        raise SystemExit(f"nested static registry side values differ: {side_name}")
require_exact_keys(
    components["tests"],
    {"component", "tests", "passed", "worker_provenance"},
    "tests",
)
if not isinstance(components["tests"]["tests"], list) or len(
    components["tests"]["tests"]
) != 3:
    raise SystemExit("nested component test cardinality differs")
for index, test_result in enumerate(components["tests"]["tests"]):
    require_exact_keys(
        test_result,
        {
            "path",
            "returncode",
            "stdout",
            "stderr",
            "expected_prefix",
            "exact_success_marker",
            "passed",
        },
        f"tests.tests[{index}]",
    )
expected_test_specs = (
    (
        "test-f0-supervisor-lts-v3-mutations.py",
        "LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=",
    ),
    (
        "test-f0-supervisor-orchestrator-v3-mutations.py",
        "LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=",
    ),
    (
        "test-run-f0-supervisor-v3-full.sh",
        "LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=",
    ),
)
for test_result, (expected_path, expected_prefix) in zip(
    components["tests"]["tests"], expected_test_specs
):
    marker_suffix = (
        test_result["stdout"][len(expected_prefix) :]
        if isinstance(test_result["stdout"], str)
        and test_result["stdout"].startswith(expected_prefix)
        else ""
    )
    derived_test_pass = bool(
        test_result["path"] == expected_path
        and is_plain_int(test_result["returncode"])
        and test_result["returncode"] == 0
        and test_result["stderr"] == ""
        and test_result["expected_prefix"] == expected_prefix
        and marker_suffix.isdigit()
        and int(marker_suffix) > 0
        and test_result["exact_success_marker"] is True
    )
    if test_result["passed"] is not derived_test_pass:
        raise SystemExit(f"nested component test values differ: {expected_path}")
if (
    components["tests"]["component"] != "tests"
    or components["tests"]["passed"]
    is not all(row["passed"] for row in components["tests"]["tests"])
):
    raise SystemExit("nested tests component disposition differs")

child_bundle_fields = {
    "component",
    "role",
    "exploration",
    "commutation",
    "single_graph_reused",
    "worker_provenance",
}
child_exploration_fields = {
    "role",
    "reachable_exact_state_count",
    "edge_count",
    "terminal_state_count",
    "nonterminal_deadlock_count",
    "states_without_terminal_path",
    "unique_ordered_evidence_history_count",
    "reachable_action_count",
    "reachable_action_ids",
    "winner_overwrite_count",
    "decision_counts",
    "protection_breach_terminal_count",
    "hostile_bypass_explicit",
    "coaccessibility_only",
    "universal_termination_proved",
    "infinite_stutter_counterexample_present",
    "management_domain_refinement_proved",
    "monitor_protection_refinement_proved",
    "external_assumptions_discharged",
    "linux_refinement_proved",
    "semantic_verdict_issued",
    "hostile_attempt_bound",
    "reacquisition_bound",
    "multiple_pending_arrival_state_count",
    "exact_ordered_history_state_identity",
    "bounded_exact_ordered_history_graph_exhaustive",
    "frontier_empty",
    "all_reachable_states_wf",
    "all_edges_target_reachable",
    "exact_state_key_collision_count",
}
commutation_fields = {
    "role",
    "reachable_exact_state_count",
    "declared_independence_pair_count",
    "declared_pair_results",
    "declared_pair_occurrences_exhaustive_over_reachable_states",
    "independence_relation_claimed_complete",
    "undeclared_pairs_assumed_independent",
    "reachability_uses_exact_state_identity",
    "ordered_history_quotiented_for_reachability",
    "check_scope",
    "outcome_projection_scope",
    "outcome_projection_retains_receipt_semantics_and_multiplicity",
    "outcome_projection_retains_causal_and_recovery_pointers",
    "outcome_projection_congruence_proved",
    "global_semantic_confluence_proved",
    "sealed_evidence_root_identity_proved",
    "passed",
}
pair_fields = {
    "independence_id",
    "actions",
    "source_predicate_id",
    "minimum_source_count",
    "expected_history_relation",
    "source_state_count",
    "coenabled_state_count",
    "both_orders_enabled_count",
    "outcome_equal_count",
    "exact_equal_count",
    "ordered_history_distinct_count",
    "preservation_failure_count",
    "prefix_preservation_failure_count",
    "audit_delta_failure_count",
    "outcome_failure_count",
    "history_relation_failure_count",
    "preservation_counterexample_fingerprints",
    "prefix_counterexample_fingerprints",
    "audit_delta_counterexample_fingerprints",
    "outcome_counterexample_fingerprints",
    "history_counterexample_fingerprints",
    "passed",
}
child_count_fields = {
    "reachable_exact_state_count",
    "edge_count",
    "terminal_state_count",
    "nonterminal_deadlock_count",
    "states_without_terminal_path",
    "unique_ordered_evidence_history_count",
    "reachable_action_count",
    "winner_overwrite_count",
    "protection_breach_terminal_count",
    "hostile_attempt_bound",
    "reacquisition_bound",
    "multiple_pending_arrival_state_count",
    "exact_state_key_collision_count",
}
child_boolean_fields = {
    "hostile_bypass_explicit",
    "coaccessibility_only",
    "universal_termination_proved",
    "infinite_stutter_counterexample_present",
    "management_domain_refinement_proved",
    "monitor_protection_refinement_proved",
    "external_assumptions_discharged",
    "linux_refinement_proved",
    "semantic_verdict_issued",
    "exact_ordered_history_state_identity",
    "bounded_exact_ordered_history_graph_exhaustive",
    "frontier_empty",
    "all_reachable_states_wf",
    "all_edges_target_reachable",
}
role_pair_ids = {}
for role_name in ("child-bundle-producer", "child-bundle-checker"):
    bundle = components[role_name]
    expected_role = "PRODUCER" if role_name.endswith("producer") else "CHECKER"
    require_exact_keys(bundle, child_bundle_fields, role_name)
    require_exact_keys(
        bundle["exploration"],
        child_exploration_fields,
        f"{role_name}.exploration",
    )
    require_exact_keys(
        bundle["commutation"],
        commutation_fields,
        f"{role_name}.commutation",
    )
    if not isinstance(bundle["commutation"]["declared_pair_results"], list):
        raise SystemExit(f"nested commutation pairs differ: {role_name}")
    commutation_reachable_count = bundle["commutation"][
        "reachable_exact_state_count"
    ]
    if not is_plain_int(commutation_reachable_count) or commutation_reachable_count <= 0:
        raise SystemExit(f"nested commutation reachability differs: {role_name}")
    exploration_reachable_count = bundle["exploration"][
        "reachable_exact_state_count"
    ]
    exploration_terminal_count = bundle["exploration"]["terminal_state_count"]
    exploration_edge_count = bundle["exploration"]["edge_count"]
    if (
        not is_plain_int(exploration_reachable_count)
        or not is_plain_int(exploration_terminal_count)
        or not is_plain_int(exploration_edge_count)
        or exploration_edge_count < 0
        or not 0 < exploration_terminal_count < exploration_reachable_count
    ):
        raise SystemExit(f"nested exploration cardinality differs: {role_name}")
    exploration_nonterminal_count = (
        exploration_reachable_count - exploration_terminal_count
    )
    reachable_action_ids = bundle["exploration"]["reachable_action_ids"]
    reachable_action_id_set = (
        set(reachable_action_ids)
        if isinstance(reachable_action_ids, list)
        and all(isinstance(item, str) for item in reachable_action_ids)
        else set()
    )
    seen_independence_ids = set()
    for index, pair in enumerate(bundle["commutation"]["declared_pair_results"]):
        require_exact_keys(
            pair,
            pair_fields,
            f"{role_name}.commutation.declared_pair_results[{index}]",
        )
        count_fields = (
            "source_state_count",
            "coenabled_state_count",
            "both_orders_enabled_count",
            "outcome_equal_count",
            "exact_equal_count",
            "ordered_history_distinct_count",
            "preservation_failure_count",
            "prefix_preservation_failure_count",
            "audit_delta_failure_count",
            "outcome_failure_count",
            "history_relation_failure_count",
        )
        counterexample_fields = (
            "preservation_counterexample_fingerprints",
            "prefix_counterexample_fingerprints",
            "audit_delta_counterexample_fingerprints",
            "outcome_counterexample_fingerprints",
            "history_counterexample_fingerprints",
        )
        if (
            not isinstance(pair["independence_id"], str)
            or not pair["independence_id"]
            or pair["independence_id"] in seen_independence_ids
            or not isinstance(pair["actions"], list)
            or len(pair["actions"]) != 2
            or not all(isinstance(action, str) and action for action in pair["actions"])
            or pair["actions"][0] == pair["actions"][1]
            or not set(pair["actions"]).issubset(reachable_action_id_set)
            or not isinstance(pair["source_predicate_id"], str)
            or not pair["source_predicate_id"]
            or not isinstance(pair["minimum_source_count"], int)
            or isinstance(pair["minimum_source_count"], bool)
            or pair["minimum_source_count"] <= 0
            or pair["expected_history_relation"] not in {"EXACT", "ORDER_DISTINCT"}
            or not all(
                isinstance(pair[field], int)
                and not isinstance(pair[field], bool)
                and pair[field] >= 0
                for field in count_fields
            )
            or pair["source_state_count"] < pair["minimum_source_count"]
            or pair["source_state_count"] > commutation_reachable_count
            or not (
                pair["source_state_count"]
                == pair["coenabled_state_count"]
                == pair["both_orders_enabled_count"]
                == pair["outcome_equal_count"]
            )
            or pair["coenabled_state_count"] > exploration_nonterminal_count
            or pair["both_orders_enabled_count"] <= 0
            or (
                pair["expected_history_relation"] == "ORDER_DISTINCT"
                and exploration_nonterminal_count < 2
            )
            or pair["preservation_failure_count"] != 0
            or pair["prefix_preservation_failure_count"] != 0
            or pair["audit_delta_failure_count"] != 0
            or pair["outcome_failure_count"] != 0
            or pair["history_relation_failure_count"] != 0
            or not all(pair[field] == [] for field in counterexample_fields)
            or pair["passed"] is not True
        ):
            raise SystemExit(
                f"nested commutation pair values differ: {role_name}:{index}"
            )
        if pair["expected_history_relation"] == "EXACT":
            history_counts_match = bool(
                pair["exact_equal_count"] == pair["both_orders_enabled_count"]
                and pair["ordered_history_distinct_count"] == 0
            )
        else:
            history_counts_match = bool(
                pair["ordered_history_distinct_count"]
                == pair["both_orders_enabled_count"]
                and pair["exact_equal_count"] == 0
            )
        if not history_counts_match:
            raise SystemExit(
                f"nested commutation history values differ: {role_name}:{index}"
            )
        pair_edge_lower_bound = (
            2 * pair["coenabled_state_count"]
            + len(reachable_action_id_set - set(pair["actions"]))
        )
        if exploration_edge_count < pair_edge_lower_bound:
            raise SystemExit(
                f"nested commutation edge lower bound differs: {role_name}:{index}"
            )
        seen_independence_ids.add(pair["independence_id"])
    role_pair_ids[role_name] = frozenset(seen_independence_ids)
    if (
        bundle["component"] != role_name
        or bundle["role"] != expected_role
        or bundle["exploration"]["role"] != expected_role
        or bundle["commutation"]["role"] != expected_role
        or bundle["single_graph_reused"] is not True
        or not isinstance(bundle["exploration"]["reachable_action_ids"], list)
        or len(bundle["exploration"]["reachable_action_ids"])
        != len(set(bundle["exploration"]["reachable_action_ids"]))
        or not all(
            isinstance(item, str) and item
            for item in bundle["exploration"]["reachable_action_ids"]
        )
        or bundle["exploration"]["reachable_action_count"]
        != len(bundle["exploration"]["reachable_action_ids"])
        or bundle["commutation"]["declared_independence_pair_count"]
        != len(bundle["commutation"]["declared_pair_results"])
        or not all(
            is_plain_int(bundle["exploration"][field])
            and bundle["exploration"][field] >= 0
            for field in child_count_fields
        )
        or not all(
            isinstance(bundle["exploration"][field], bool)
            for field in child_boolean_fields
        )
        or not isinstance(bundle["exploration"]["decision_counts"], list)
        or not all(
            isinstance(row, list)
            and len(row) == 2
            and isinstance(row[0], str)
            and row[0]
            and is_plain_int(row[1])
            and row[1] > 0
            for row in bundle["exploration"]["decision_counts"]
        )
        or len(
            [row[0] for row in bundle["exploration"]["decision_counts"]]
        )
        != len(
            {row[0] for row in bundle["exploration"]["decision_counts"]}
        )
        or not is_plain_int(
            bundle["commutation"]["reachable_exact_state_count"]
        )
        or bundle["commutation"]["reachable_exact_state_count"] <= 0
        or bundle["commutation"]["reachable_exact_state_count"]
        != bundle["exploration"]["reachable_exact_state_count"]
        or not is_plain_int(
            bundle["commutation"]["declared_independence_pair_count"]
        )
    ):
        raise SystemExit(f"nested child bundle values differ: {role_name}")

require_exact_keys(
    components["orchestrator"],
    {"component", "result", "worker_provenance"},
    "orchestrator",
)
require_exact_keys(
    components["orchestrator"]["result"],
    {
        "exploration_semantics",
        "reachable_repetition_bounded_state_count",
        "edge_count",
        "terminal_counts",
        "nonterminal_deadlock_count",
        "states_without_terminal_path",
        "declared_action_count",
        "reachable_action_count",
        "missing_actions",
        "undeclared_actions",
        "semantic_verdict_always_absent",
        "published_artifact_type",
        "external_assumptions_discharged",
        "durable_store_refinement_proved",
        "issuance_registry_refinement_proved",
        "global_nonce_uniqueness_proved",
        "symbolic_authentication_discharged",
        "exact_state_identity_within_repetition_bound",
        "attached_fixture_terminal_trace_replay_checked",
        "attached_fixture_scenarios",
        "all_child_terminal_traces_composed",
        "parent_child_product_exhaustive",
        "store_attack_repetition_policy",
        "max_store_attack_attempts_per_typed_context",
        "repetition_bounded_state_space_exhaustive",
        "unbounded_attack_history_frontier_empty",
        "partial_order_reduction_applied",
        "partial_order_equivalence_proved",
        "unbounded_repeated_store_attack_history_exhaustive",
        "attack_context_key_refinement_proved",
        "multiple_store_attack_context_state_count",
        "owner_failure_with_pending_attack_state_count",
        "post_owner_publish_attack_state_count",
        "guardian_generation_capsule_state_count",
        "abandoned_terminal_requires_matching_ack",
        "typed_abandonment_conflict_withholds_assurance",
        "abandonment_conflict_breach_terminal_count",
        "publication_fence_reauthorization_encoded",
        "publication_fence_store_refinement_proved",
        "coaccessibility_only",
        "universal_termination_proved",
        "infinite_stutter_counterexample_present",
        "assurance_breach_explicit",
        "assurance_breach_terminal_count",
        "guardian_survivability_proved",
        "external_semantic_verdict_issued",
    },
    "orchestrator.result",
)
if components["orchestrator"]["component"] != "orchestrator":
    raise SystemExit("nested orchestrator identity differs")
if set(result.get("child_action_registry", {})) != {
    "declared_action_count",
    "combined_reachable_action_count",
    "missing_actions",
    "undeclared_actions",
    "exact",
}:
    raise SystemExit("validator child action registry fields differ")
producer_action_ids = set(
    components["child-bundle-producer"]["exploration"]["reachable_action_ids"]
)
checker_action_ids = set(
    components["child-bundle-checker"]["exploration"]["reachable_action_ids"]
)
producer_pair_ids = role_pair_ids["child-bundle-producer"]
checker_pair_ids = role_pair_ids["child-bundle-checker"]
producer_exploration = dict(components["child-bundle-producer"]["exploration"])
checker_exploration = dict(components["child-bundle-checker"]["exploration"])
producer_commutation = dict(components["child-bundle-producer"]["commutation"])
checker_commutation = dict(components["child-bundle-checker"]["commutation"])
producer_exploration.pop("role")
checker_exploration.pop("role")
producer_commutation.pop("role")
checker_commutation.pop("role")
child_action_registry = result["child_action_registry"]
if (
    producer_action_ids != checker_action_ids
    or producer_pair_ids != checker_pair_ids
    or producer_exploration != checker_exploration
    or producer_commutation != checker_commutation
    or not is_plain_int(child_action_registry["declared_action_count"])
    or not is_plain_int(
        child_action_registry["combined_reachable_action_count"]
    )
    or child_action_registry["declared_action_count"]
    != static_result["child"]["declared_action_count"]
    or child_action_registry["combined_reachable_action_count"]
    != len(producer_action_ids)
    or child_action_registry["missing_actions"] != []
    or child_action_registry["undeclared_actions"] != []
    or child_action_registry["exact"] is not True
    or child_action_registry["declared_action_count"] != len(producer_action_ids)
    or producer_pair_ids != set(static_result["declared_independence_ids"])
):
    raise SystemExit("validator child action registry values differ")
parent_result = components["orchestrator"]["result"]
parent_count_fields = {
    "reachable_repetition_bounded_state_count",
    "edge_count",
    "nonterminal_deadlock_count",
    "states_without_terminal_path",
    "declared_action_count",
    "reachable_action_count",
    "max_store_attack_attempts_per_typed_context",
    "multiple_store_attack_context_state_count",
    "owner_failure_with_pending_attack_state_count",
    "post_owner_publish_attack_state_count",
    "guardian_generation_capsule_state_count",
    "abandonment_conflict_breach_terminal_count",
    "assurance_breach_terminal_count",
}
if (
    parent_result["declared_action_count"]
    != static_result["orchestrator"]["declared_action_count"]
    or parent_result["reachable_action_count"]
    != parent_result["declared_action_count"]
    or parent_result["missing_actions"] != []
    or parent_result["undeclared_actions"] != []
    or not all(
        is_plain_int(parent_result[field]) and parent_result[field] >= 0
        for field in parent_count_fields
    )
    or not isinstance(parent_result["attached_fixture_scenarios"], list)
    or not parent_result["attached_fixture_scenarios"]
    or len(parent_result["attached_fixture_scenarios"])
    != len(set(parent_result["attached_fixture_scenarios"]))
    or not all(
        isinstance(item, str) and item
        for item in parent_result["attached_fixture_scenarios"]
    )
    or not isinstance(parent_result["terminal_counts"], dict)
    or not parent_result["terminal_counts"]
    or not all(
        isinstance(name, str)
        and name
        and isinstance(count, int)
        and not isinstance(count, bool)
        and count > 0
        for name, count in parent_result["terminal_counts"].items()
    )
):
    raise SystemExit("validator parent action registry values differ")
parent_reachable_count = parent_result[
    "reachable_repetition_bounded_state_count"
]
parent_terminal_count = sum(parent_result["terminal_counts"].values())
parent_subset_counts = (
    parent_result["multiple_store_attack_context_state_count"],
    parent_result["owner_failure_with_pending_attack_state_count"],
    parent_result["post_owner_publish_attack_state_count"],
    parent_result["guardian_generation_capsule_state_count"],
)
if (
    parent_reachable_count <= 0
    or not 0 < parent_terminal_count < parent_reachable_count
    or parent_result["edge_count"] < parent_reachable_count - 1
    or parent_result["edge_count"]
    > (
        (parent_reachable_count - parent_terminal_count)
        * parent_result["declared_action_count"]
    )
    or parent_result["reachable_action_count"] > parent_result["edge_count"]
    or parent_result["nonterminal_deadlock_count"] + parent_terminal_count
    > parent_reachable_count
    or parent_result["states_without_terminal_path"] > parent_reachable_count
    or any(count > parent_reachable_count for count in parent_subset_counts)
    or parent_result["abandonment_conflict_breach_terminal_count"]
    > parent_result["assurance_breach_terminal_count"]
    or parent_result["assurance_breach_terminal_count"]
    > parent_terminal_count
    or parent_result["assurance_breach_terminal_count"]
    != parent_result["terminal_counts"].get("ASSURANCE_BREACHED", 0)
):
    raise SystemExit("validator parent cardinality relations differ")
open_obligations = result.get("open_refinement_obligations")
if set(open_obligations or {}) != {"child", "orchestrator"}:
    raise SystemExit("validator open-refinement fields differ")
if any(
    not isinstance(open_obligations[role], list)
    or not open_obligations[role]
    or not all(isinstance(item, str) and item for item in open_obligations[role])
    for role in ("child", "orchestrator")
):
    raise SystemExit("validator open-refinement obligations are invalid")
obligation_ids_by_path = {}
for role in ("child", "orchestrator"):
    identifiers = [row.split(" ", 1)[0] for row in open_obligations[role]]
    if len(identifiers) != len(set(identifiers)) or any(
        not identifier or " " in identifier for identifier in identifiers
    ):
        raise SystemExit(f"validator open-refinement obligation IDs differ: {role}")
    obligation_ids_by_path[
        f"open_refinement_obligations.{role}"
    ] = frozenset(identifiers)


def child_result_ok(item):
    decision_total = sum(row[1] for row in item["decision_counts"])
    return bool(
        item["reachable_exact_state_count"] > 0
        and 0 < item["terminal_state_count"]
        < item["reachable_exact_state_count"]
        and item["edge_count"] >= item["reachable_exact_state_count"] - 1
        and item["edge_count"]
        <= (
            (item["reachable_exact_state_count"] - item["terminal_state_count"])
            * item["reachable_action_count"]
        )
        and item["reachable_action_count"] <= item["edge_count"]
        and 0 < item["unique_ordered_evidence_history_count"]
        <= item["reachable_exact_state_count"]
        and item["nonterminal_deadlock_count"] == 0
        and item["states_without_terminal_path"] == 0
        and item["winner_overwrite_count"] == 0
        and 0 < item["protection_breach_terminal_count"]
        <= item["terminal_state_count"]
        and decision_total > 0
        and decision_total + item["protection_breach_terminal_count"]
        == item["terminal_state_count"]
        and item["hostile_bypass_explicit"] is True
        and item["coaccessibility_only"] is True
        and item["universal_termination_proved"] is False
        and item["infinite_stutter_counterexample_present"] is True
        and item["management_domain_refinement_proved"] is False
        and item["monitor_protection_refinement_proved"] is False
        and item["external_assumptions_discharged"] is False
        and item["linux_refinement_proved"] is False
        and item["semantic_verdict_issued"] is False
        and item["hostile_attempt_bound"] == 2
        and item["reacquisition_bound"] == 2
        and 0 < item["multiple_pending_arrival_state_count"]
        <= item["reachable_exact_state_count"]
        and item["exact_ordered_history_state_identity"] is True
        and item["bounded_exact_ordered_history_graph_exhaustive"] is True
        and item["frontier_empty"] is True
        and item["all_reachable_states_wf"] is True
        and item["all_edges_target_reachable"] is True
        and item["exact_state_key_collision_count"] == 0
    )


def commutation_result_ok(item):
    return bool(
        item["passed"] is True
        and item["declared_independence_pair_count"] > 0
        and item[
            "declared_pair_occurrences_exhaustive_over_reachable_states"
        ]
        is True
        and item["independence_relation_claimed_complete"] is False
        and item["undeclared_pairs_assumed_independent"] is False
        and item["reachability_uses_exact_state_identity"] is True
        and item["ordered_history_quotiented_for_reachability"] is False
        and item["check_scope"] == "LOCAL_TWO_STEP_EFFECT_COMMUTATION_ONLY"
        and item[
            "outcome_projection_retains_receipt_semantics_and_multiplicity"
        ]
        is True
        and item[
            "outcome_projection_retains_causal_and_recovery_pointers"
        ]
        is True
        and item["outcome_projection_congruence_proved"] is False
        and item["global_semantic_confluence_proved"] is False
        and item["sealed_evidence_root_identity_proved"] is False
    )


def parent_result_ok(item):
    return bool(
        item["nonterminal_deadlock_count"] == 0
        and item["states_without_terminal_path"] == 0
        and item["missing_actions"] == []
        and item["undeclared_actions"] == []
        and item["semantic_verdict_always_absent"] is True
        and item["published_artifact_type"] == "LOCAL_DISPOSITION_CAPSULE"
        and item["external_assumptions_discharged"] is False
        and item["durable_store_refinement_proved"] is False
        and item["issuance_registry_refinement_proved"] is False
        and item["global_nonce_uniqueness_proved"] is False
        and item["symbolic_authentication_discharged"] is False
        and item["exploration_semantics"]
        == "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL"
        and item["exact_state_identity_within_repetition_bound"] is True
        and item["attached_fixture_terminal_trace_replay_checked"] is True
        and item["all_child_terminal_traces_composed"] is False
        and item["parent_child_product_exhaustive"] is False
        and item["store_attack_repetition_policy"]
        == "FIRST_ATTEMPT_PER_TYPED_CONTEXT_REPETITION_BOUND"
        and item["max_store_attack_attempts_per_typed_context"] == 1
        and item["repetition_bounded_state_space_exhaustive"] is True
        and item["unbounded_attack_history_frontier_empty"] is False
        and item["partial_order_reduction_applied"] is False
        and item["partial_order_equivalence_proved"] is False
        and item["unbounded_repeated_store_attack_history_exhaustive"] is False
        and item["attack_context_key_refinement_proved"] is False
        and item["multiple_store_attack_context_state_count"] > 0
        and item["owner_failure_with_pending_attack_state_count"] > 0
        and item["post_owner_publish_attack_state_count"] > 0
        and item["guardian_generation_capsule_state_count"] > 0
        and item["abandoned_terminal_requires_matching_ack"] is True
        and item["typed_abandonment_conflict_withholds_assurance"] is True
        and item["abandonment_conflict_breach_terminal_count"] > 0
        and item["publication_fence_reauthorization_encoded"] is True
        and item["publication_fence_store_refinement_proved"] is False
        and item["coaccessibility_only"] is True
        and item["universal_termination_proved"] is False
        and item["infinite_stutter_counterexample_present"] is True
        and item["assurance_breach_explicit"] is True
        and item["assurance_breach_terminal_count"] > 0
        and item["guardian_survivability_proved"] is False
        and item["external_semantic_verdict_issued"] is False
    )


producer_bundle = components["child-bundle-producer"]
checker_bundle = components["child-bundle-checker"]
predicates = {
    "FAST_MUTATION_STATIC": bool(
        result["bootstrap_source_execution_check"] is True
        and result["input_hashes_equal_before_after"] is True
        and components["static-registries"].get("passed") is True
        and components["tests"].get("passed") is True
        and component_receipts_bound
    ),
    "CHILD_EXACT_FIXTURE_BOUNDED": bool(
        child_result_ok(producer_bundle["exploration"])
        and child_result_ok(checker_bundle["exploration"])
        and component_receipts_bound
    ),
    "PARENT_EXACT_REPETITION_BOUNDED": bool(
        parent_result_ok(components["orchestrator"]["result"])
        and component_receipts_bound
    ),
    "DECLARED_LOCAL_EFFECT_COMMUTATION": bool(
        commutation_result_ok(producer_bundle["commutation"])
        and commutation_result_ok(checker_bundle["commutation"])
        and component_receipts_bound
    ),
}
derived_local_candidate = bool(
    all(predicates.values())
    and producer_bundle.get("single_graph_reused") is True
    and checker_bundle.get("single_graph_reused") is True
    and result["child_action_registry"]["exact"] is True
    and result["child_action_registry"]["missing_actions"] == []
    and result["child_action_registry"]["undeclared_actions"] == []
)
if expected_local_candidate is not derived_local_candidate:
    raise SystemExit("validator local candidate status differs from evidence")

claim_registry_hash = hashlib.sha256(registry_payload).hexdigest()
if claim_registry_hash != snapshot_hashes[
    "f0-supervisor-c4-claim-registry-v1.json"
]:
    raise SystemExit("claim registry differs from captured snapshot manifest")
if set(claim_registry) != {
    "schema_version",
    "artifact_id",
    "authority",
    "claims",
    "authorization",
}:
    raise SystemExit("claim registry top-level fields differ")
if claim_registry.get("schema_version") != 1 or claim_registry.get("authority") != (
    "repository_claim_catalog_not_candidate_result"
):
    raise SystemExit("claim registry identity fields differ")
registry_authorization = claim_registry.get("authorization")
if set(registry_authorization or {}) != {
    "F0_local_acceptance",
    "external_R11_review",
    "G0_authorized",
    "self_authorization",
    "protection_claim",
} or any(registry_authorization.values()):
    raise SystemExit("claim registry grants forbidden authority")
if result.get("claim_registry") != {
    "artifact_id": claim_registry.get("artifact_id"),
    "sha256": claim_registry_hash,
}:
    raise SystemExit("validator result claim registry identity mismatch")
claim_rows = claim_registry.get("claims")
if not isinstance(claim_rows, list) or len(claim_rows) != 11:
    raise SystemExit("claim registry cardinality mismatch")
for row in claim_rows:
    if set(row) != {"id", "class", "fast", "full"}:
        raise SystemExit("claim registry row fields differ")
    if not isinstance(row.get("class"), str) or not row["class"]:
        raise SystemExit("claim registry class is invalid")
    for mode in ("fast", "full"):
        mode_spec = row.get(mode, {})
        if set(mode_spec) != {"allowed_statuses", "evidence", "status_rule"}:
            raise SystemExit(f"claim registry {mode}-mode fields differ")
        rule = mode_spec["status_rule"]
        if rule.get("kind") == "fixed":
            if set(rule) != {"kind", "status"} or mode_spec[
                "allowed_statuses"
            ] != [rule["status"]]:
                raise SystemExit(f"claim registry fixed rule differs: {mode}")
        elif rule.get("kind") == "boolean":
            if (
                set(rule)
                != {"kind", "predicate_id", "true_status", "false_status"}
                or rule["predicate_id"] not in predicates
                or set(mode_spec["allowed_statuses"])
                != {rule["true_status"], rule["false_status"]}
                or rule["true_status"] == rule["false_status"]
            ):
                raise SystemExit(f"claim registry Boolean rule differs: {mode}")
        else:
            raise SystemExit(f"claim registry rule kind differs: {mode}")
claim_specs = {row.get("id"): row.get("full") for row in claim_rows}
if None in claim_specs or len(claim_specs) != len(claim_rows):
    raise SystemExit("claim registry IDs are invalid or duplicated")
claims = result.get("claims")
if not isinstance(claims, dict) or set(claims) != set(claim_specs):
    raise SystemExit("validator result claim set mismatch")
for claim_id, claim in claims.items():
    specification = claim_specs[claim_id]
    if set(claim) != {"status", "evidence"}:
        raise SystemExit(f"claim fields differ: {claim_id}")
    if claim.get("status") not in specification.get("allowed_statuses", []):
        raise SystemExit(f"claim status differs: {claim_id}")
    if claim.get("evidence") != specification.get("evidence"):
        raise SystemExit(f"claim evidence differs: {claim_id}")
    if claim.get("status") == "OPEN_REFINEMENT":
        if not claim["evidence"]:
            raise SystemExit(f"open claim lacks evidence references: {claim_id}")
        for reference in claim["evidence"]:
            if reference == "authorization.F0_local_acceptance=false":
                if authorization["F0_local_acceptance"] is not False:
                    raise SystemExit(
                        f"open claim false authorization differs: {claim_id}"
                    )
                continue
            path, separator, obligation_id = reference.partition("#")
            if (
                separator != "#"
                or path not in obligation_ids_by_path
                or obligation_id not in obligation_ids_by_path[path]
            ):
                raise SystemExit(
                    f"open claim obligation reference is unresolved: "
                    f"{claim_id}:{reference}"
                )
    rule = specification["status_rule"]
    expected_claim_status = (
        rule["status"]
        if rule["kind"] == "fixed"
        else (
            rule["true_status"]
            if predicates[rule["predicate_id"]]
            else rule["false_status"]
        )
    )
    if claim.get("status") != expected_claim_status:
        raise SystemExit(f"claim predicate differs: {claim_id}")
print(status + "\t" + result_sha256)
	' "${RESULT}" \
        "${SNAPSHOT_DIR}/f0-supervisor-c4-claim-registry-v1.json" \
        "${RUN_DIR}/input-manifest.before.sha256" \
        "${SNAPSHOT_DIR}" \
        2>> "${LOG}"
    ) || VALIDATOR_RESULT_METADATA=""
    if [[ -n "${VALIDATOR_RESULT_METADATA}" ]]; then
        IFS=$'\t' read -r VALIDATOR_RESULT_STATUS \
            CAPTURED_RESULT_SHA256 VALIDATOR_RESULT_EXTRA \
            <<< "${VALIDATOR_RESULT_METADATA}"
        if [[ -n "${VALIDATOR_RESULT_EXTRA:-}" ||
              ! "${CAPTURED_RESULT_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
            VALIDATOR_RESULT_STATUS=""
            CAPTURED_RESULT_SHA256=""
        fi
    fi
fi

if (( ! VALIDATOR_GROUP_EMPTY_AFTER_CLEANUP )); then
    finalize_run EVIDENCE_FINALIZATION_ERROR 74 \
        'validator process group did not become empty after bounded cleanup'
elif (( TIMEOUT_OCCURRED )); then
    finalize_run INCOMPLETE_TIMEOUT 124 \
        'validator elapsed time reached the configured campaign deadline'
else
    case "${VALIDATOR_RC}:${VALIDATOR_RESULT_STATUS}" in
        0:COMPLETE_LOCAL_C4_CANDIDATE_ONLY)
            finalize_run COMPLETE_LOCAL_C4_CANDIDATE_ONLY 0 \
                'validator completed the local candidate campaign'
            ;;
        1:COMPLETE_LOCAL_C4_REJECTED)
            finalize_run COMPLETE_LOCAL_C4_REJECTED 1 \
                'validator completed and rejected the local candidate'
            ;;
        *)
            finalize_run TOOL_ERROR "${VALIDATOR_RC}" \
                'validator exit code and complete result status are inconsistent'
            ;;
    esac
fi

printf '%s\n' "${RUN_DIR}"
case "${FINAL_STATUS}" in
    COMPLETE_LOCAL_C4_CANDIDATE_ONLY)
        exit 0
        ;;
    COMPLETE_LOCAL_C4_REJECTED)
        exit 1
        ;;
    INCOMPLETE_TIMEOUT)
        exit 124
        ;;
    INCOMPLETE_SIGNAL)
        exit "${VALIDATOR_RC:-143}"
        ;;
    EVIDENCE_FINALIZATION_ERROR)
        exit 74
        ;;
    *)
        exit 70
        ;;
esac
