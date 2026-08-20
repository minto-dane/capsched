#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
WORKTREE_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)
RESULTS_ROOT=${CAPSCHED_RESULTS_ROOT:-/media/nia/scsiusb/dev/linux-cap/build/results/f0-supervisor-v3}
STAMP=${CAPSCHED_RUN_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}
RUN_DIR=${RESULTS_ROOT}/${STAMP}
SNAPSHOT_DIR=${RUN_DIR}/input
LOG=${RUN_DIR}/run.log
RESULT=${RUN_DIR}/result.json
EXPECTED_MANIFEST=${CAPSCHED_EXPECTED_MANIFEST:-}

if [[ -z "${EXPECTED_MANIFEST}" || ! -f "${EXPECTED_MANIFEST}" ]]; then
    printf 'CAPSCHED_EXPECTED_MANIFEST must name a reviewed SHA-256 manifest\n' >&2
    exit 64
fi

mkdir -p "${SNAPSHOT_DIR}"
printf 'RUNNING\n' > "${RUN_DIR}/status"

record_failure() {
    local rc=$?
    case "${rc}" in
        124|130|137|143)
            printf 'INCOMPLETE rc=%s\n' "${rc}" > "${RUN_DIR}/status"
            ;;
        *)
            printf 'FAIL rc=%s\n' "${rc}" > "${RUN_DIR}/status"
            ;;
    esac
    exit "${rc}"
}
trap record_failure ERR

INPUTS=(
    f0_supervisor_lts_v3.py
    f0_supervisor_orchestrator_v3.py
    test-f0-supervisor-lts-v3-mutations.py
    test-f0-supervisor-orchestrator-v3-mutations.py
    validate-f0-supervisor-lts-v3.py
    run-f0-supervisor-v3-full.sh
)

for input in "${INPUTS[@]}"; do
    cp --reflink=auto -- "${SCRIPT_DIR}/${input}" "${SNAPSHOT_DIR}/${input}"
done
cp -- "${EXPECTED_MANIFEST}" "${RUN_DIR}/input-manifest.expected.sha256"

(
    cd "${SNAPSHOT_DIR}"
    sha256sum -- "${INPUTS[@]}" > "${RUN_DIR}/input-manifest.before.sha256"
)

cmp --silent \
    "${RUN_DIR}/input-manifest.expected.sha256" \
    "${RUN_DIR}/input-manifest.before.sha256"

{
    printf '[%s] supervisor v3 full local campaign\n' "$(date --iso-8601=seconds)"
    printf 'worktree=%s\n' "${WORKTREE_ROOT}"
    printf 'snapshot=%s\n' "${SNAPSHOT_DIR}"
    printf 'result=%s\n' "${RESULT}"
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH="${SNAPSHOT_DIR}" \
        python3 "${SNAPSHOT_DIR}/validate-f0-supervisor-lts-v3.py" \
        --full \
        --output "${RESULT}"
} 2>&1 | tee "${LOG}"

(
    cd "${SNAPSHOT_DIR}"
    sha256sum -- "${INPUTS[@]}" > "${RUN_DIR}/input-manifest.after.sha256"
)

cmp --silent \
    "${RUN_DIR}/input-manifest.before.sha256" \
    "${RUN_DIR}/input-manifest.after.sha256"

sha256sum -- "${RESULT}" > "${RUN_DIR}/result.sha256"
printf 'PASS\n' > "${RUN_DIR}/status"
trap - ERR
printf '%s\n' "${RUN_DIR}"
