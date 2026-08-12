#!/usr/bin/python3
"""Reduce one finalized Candidate-4 root capture without reopening source.

This process is deliberately non-root.  Its only input is the read-only
capture view mounted at /INPUT by the reduction supervisor, and its only
output is one bounded canonical JSON frame on stdout.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import stat
from pathlib import Path
from typing import Any, Iterable


CONTRACT_SHA256 = "0a695417dcb6161d6f049431dea8755821e0c4600bf990f4822b274a1f924c6d"
REDUCER_UID = 200011
REDUCER_GID = 200011
CAPTURE_ROOT = Path("/INPUT")
COMPONENTS = (
    ("static-registries", "FAST_REGISTRY_CHECK", 1800),
    ("tests", "FAST_HOSTILE_REGRESSION", 3600),
    ("child-bundle-producer", "FULL_CHILD_PRODUCER", 43200),
    ("child-bundle-checker", "FULL_CHILD_CHECKER", 43200),
    ("orchestrator", "FULL_PARENT_ORCHESTRATOR", 43200),
)
COMPONENT_ORDER = tuple(row[0] for row in COMPONENTS)
INPUT_DIGESTS = {
    "f0-supervisor-c4-claim-registry-v1.json": "c5496505a337c7c305115531b6a9169cb19f972024f8b3bd0805d4e2a7d2df7e",
    "f0_supervisor_lts_v3.py": "ba44ff0250318baad8f7476d9a1a1c7fb619f4cfb035fdb762aa5def851d387a",
    "f0_supervisor_orchestrator_v3.py": "2bb8a285fe96db084c76ca58fbe405dcf4b89ea0b82593d4dfe2d43c277bdba5",
    "run-f0-supervisor-v3-full.sh": "2f27d0b6f57927f08186cf4635ed0474de084656385b2e0c1ae7a092cadd06ba",
    "test-f0-supervisor-lts-v3-mutations.py": "354cd28449490ab3740afec8c258877090f2251ae217c74366d69e98aff76a8c",
    "test-f0-supervisor-orchestrator-v3-mutations.py": "bdd7b736603f670cee18296c73cd89fb58151159405a37d219cbf86ac0a57a0f",
    "test-run-f0-supervisor-v3-full.sh": "124947b2622811b60a20f753e6cfa6eae0a704afb11c95bb0fe1b80a11e78ec9",
    "validate-f0-supervisor-lts-v3.py": "83408bbcc7e1bf3abcf7165e7e32d2c34a1be55a8ddd78d212c77d6d95452e5c",
}
INPUT_ROOT_SHA256 = hashlib.sha256(
    json.dumps(INPUT_DIGESTS, sort_keys=True, separators=(",", ":")).encode()
).hexdigest()
SEMANTIC_REGISTRY_SHA256 = "be5e95640d31ad19ff81f4fe313a7ab29d44fae18c0fff56cfdb99bd86d8b789"
INDEPENDENCE_IDS = [
    "IND-001-PRODUCER-A-NORMAL-EXIT",
    "IND-002-PRODUCER-B-NORMAL-EXIT",
    "IND-003-CHECKER-ACCEPT-NORMAL-EXIT",
    "IND-004-CHECKER-REJECT-NORMAL-EXIT",
    "IND-005-VALID-EOF-NORMAL-EXIT",
    "IND-006-FORK-ASYNC-ACQUIRE",
]
TEST_MARKERS = {
    "test-f0-supervisor-lts-v3-mutations.py": (
        "LOCAL_C4_CHILD_REGRESSION_PASS hostile_cases=275"
    ),
    "test-f0-supervisor-orchestrator-v3-mutations.py": (
        "LOCAL_C4_PARENT_REGRESSION_PASS hostile_cases=715"
    ),
    "test-run-f0-supervisor-v3-full.sh": (
        "LOCAL_C4_RUNNER_REGRESSION_PASS hostile_cases=44"
    ),
}
LOCAL_PREDICATES = {
    "FAST_MUTATION_STATIC",
    "CHILD_EXACT_FIXTURE_BOUNDED",
    "PARENT_EXACT_REPETITION_BOUNDED",
    "DECLARED_LOCAL_EFFECT_COMMUTATION",
}
AUTHORIZATION = {
    "F0_local_acceptance": False,
    "external_R11_review": False,
    "G0_authorized": False,
    "self_authorization": False,
    "protection_claim": False,
    "linux_behavior_change": False,
    "monitor_implementation": False,
    "performance_or_cost_claim": False,
    "deployment_claim": False,
}
HEX64_RE = re.compile(r"[0-9a-f]{64}")
MAX_JSON_BYTES = 268435456
MAX_METADATA_BYTES = 16777216


class ReductionIncomplete(RuntimeError):
    """Finalized raw capture cannot be trusted as a complete reducer input."""


class StrictResultInvalid(RuntimeError):
    """Candidate result framing, JSON, schema, or fixed semantics is invalid."""


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON constant: {value}")


def unique_object(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_json(raw: bytes, label: str, error_type: type[RuntimeError]) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except (UnicodeError, ValueError, json.JSONDecodeError) as exc:
        raise error_type(f"{label}: strict JSON rejected") from exc


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require_hex(value: Any, label: str, error_type: type[RuntimeError]) -> str:
    if not isinstance(value, str) or HEX64_RE.fullmatch(value) is None:
        raise error_type(f"{label}: digest is malformed")
    return value


def require_object(
    value: Any,
    keys: set[str],
    label: str,
    error_type: type[RuntimeError],
) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise error_type(f"{label}: object fields differ")
    return value


def require_bool(value: Any, label: str, error_type: type[RuntimeError]) -> bool:
    if type(value) is not bool:
        raise error_type(f"{label}: Boolean required")
    return value


def require_int(
    value: Any,
    label: str,
    error_type: type[RuntimeError],
    minimum: int = 0,
) -> int:
    if type(value) is not int or value < minimum:
        raise error_type(f"{label}: bounded integer required")
    return value


def file_metadata(path: Path, label: str, maximum: int) -> os.stat_result:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise ReductionIncomplete(f"{label}: stat failed") from exc
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != 0
        or metadata.st_gid != 0
        or stat.S_IMODE(metadata.st_mode) != 0o444
        or metadata.st_size < 0
        or metadata.st_size > maximum
    ):
        raise ReductionIncomplete(f"{label}: metadata differs")
    return metadata


def read_file(path: Path, label: str, maximum: int) -> bytes:
    metadata = file_metadata(path, label, maximum)
    flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        raise ReductionIncomplete(f"{label}: open failed") from exc
    try:
        before = os.fstat(fd)
        if (
            before.st_dev != metadata.st_dev
            or before.st_ino != metadata.st_ino
            or before.st_size != metadata.st_size
        ):
            raise ReductionIncomplete(f"{label}: identity changed before read")
        blocks: list[bytes] = []
        remaining = metadata.st_size
        while remaining:
            block = os.read(fd, min(1024 * 1024, remaining))
            if not block:
                raise ReductionIncomplete(f"{label}: unexpected EOF")
            blocks.append(block)
            remaining -= len(block)
        if os.read(fd, 1):
            raise ReductionIncomplete(f"{label}: grew while read")
        after = os.fstat(fd)
        if (
            after.st_dev != before.st_dev
            or after.st_ino != before.st_ino
            or after.st_size != before.st_size
            or after.st_mtime_ns != before.st_mtime_ns
            or after.st_ctime_ns != before.st_ctime_ns
        ):
            raise ReductionIncomplete(f"{label}: changed while read")
        return b"".join(blocks)
    finally:
        os.close(fd)


def require_directory(path: Path, label: str, mode: int) -> None:
    try:
        metadata = path.stat(follow_symlinks=False)
    except OSError as exc:
        raise ReductionIncomplete(f"{label}: stat failed") from exc
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != 0
        or metadata.st_gid != 0
        or stat.S_IMODE(metadata.st_mode) != mode
    ):
        raise ReductionIncomplete(f"{label}: directory metadata differs")


def require_exact_names(path: Path, expected: set[str], label: str) -> None:
    try:
        actual = {entry.name for entry in os.scandir(path)}
    except OSError as exc:
        raise ReductionIncomplete(f"{label}: directory read failed") from exc
    if actual != expected:
        raise ReductionIncomplete(f"{label}: directory members differ")


def mount_identity(path: Path) -> dict[str, str]:
    metadata = path.stat(follow_symlinks=False)
    device = f"{os.major(metadata.st_dev)}:{os.minor(metadata.st_dev)}"
    selected: tuple[str, str, str, str] | None = None
    for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
        left, separator, right = line.partition(" - ")
        left_fields = left.split()
        right_fields = right.split()
        if not separator or len(left_fields) < 6 or len(right_fields) < 3:
            raise ReductionIncomplete("runtime mountinfo is malformed")
        mount_point = left_fields[4].replace("\\040", " ")
        path_text = str(path)
        if left_fields[2] != device or not (
            path_text == mount_point
            or (mount_point != "/" and path_text.startswith(mount_point + "/"))
            or mount_point == "/"
        ):
            continue
        candidate = (
            mount_point,
            left_fields[5],
            right_fields[0],
            right_fields[1],
        )
        if selected is None or len(candidate[0]) > len(selected[0]):
            selected = candidate
    if selected is None:
        raise ReductionIncomplete(f"cannot identify mount for {path}")
    mount_point, options, filesystem, source = selected
    return {
        "device": device,
        "mount_point": mount_point,
        "mount_options": options,
        "filesystem_type": filesystem,
        "source": source,
    }


def runtime_identity() -> dict[str, Any]:
    status: dict[str, str] = {}
    for line in Path("/proc/self/status").read_text(encoding="ascii").splitlines():
        key, separator, value = line.partition(":")
        if separator:
            status[key] = " ".join(value.split())
    fd_rows: list[dict[str, Any]] = []
    for name in sorted(os.listdir("/proc/self/fd"), key=int):
        descriptor = int(name)
        try:
            target = os.readlink(f"/proc/self/fd/{name}")
            flags = fcntl.fcntl(descriptor, fcntl.F_GETFD)
        except OSError:
            continue
        fd_rows.append(
            {
                "fd": descriptor,
                "cloexec": bool(flags & fcntl.FD_CLOEXEC),
                "target": target,
            }
        )
    return {
        "uid": os.getuid(),
        "euid": os.geteuid(),
        "gid": os.getgid(),
        "egid": os.getegid(),
        "groups": os.getgroups(),
        "status": {
            key: status.get(key, "")
            for key in (
                "Uid",
                "Gid",
                "Groups",
                "CapInh",
                "CapPrm",
                "CapEff",
                "CapBnd",
                "CapAmb",
                "NoNewPrivs",
                "Seccomp",
            )
        },
        "fd_table": fd_rows,
        "input_mount": mount_identity(CAPTURE_ROOT),
        "usr_mount": mount_identity(Path("/usr")),
    }


def normalize_stdin() -> None:
    descriptor = os.open("/dev/null", os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        if descriptor != 0:
            os.dup2(descriptor, 0, inheritable=True)
        else:
            os.set_inheritable(0, True)
    finally:
        if descriptor != 0:
            os.close(descriptor)


def validate_runtime_identity(identity: dict[str, Any]) -> None:
    if (
        identity["uid"] != REDUCER_UID
        or identity["euid"] != REDUCER_UID
        or identity["gid"] != REDUCER_GID
        or identity["egid"] != REDUCER_GID
        or identity["groups"] != [REDUCER_GID]
    ):
        raise ReductionIncomplete("reducer UID/GID separation differs")
    status = identity["status"]
    expected_id = " ".join([str(REDUCER_UID)] * 4)
    expected_gid = " ".join([str(REDUCER_GID)] * 4)
    if status["Uid"] != expected_id or status["Gid"] != expected_gid:
        raise ReductionIncomplete("reducer status identity differs")
    if status["Groups"] != str(REDUCER_GID):
        raise ReductionIncomplete("reducer runtime group set differs")
    for key in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb"):
        if status[key] != "0000000000000000":
            raise ReductionIncomplete(f"reducer capability set is nonempty: {key}")
    if status["NoNewPrivs"] != "1" or status["Seccomp"] != "2":
        raise ReductionIncomplete("reducer NNP/seccomp boundary differs")
    descriptors = {row["fd"] for row in identity["fd_table"]}
    if descriptors != {0, 1, 2}:
        raise ReductionIncomplete(f"reducer inherited fd set differs: {sorted(descriptors)}")
    fd0 = next(row for row in identity["fd_table"] if row["fd"] == 0)
    if fd0["cloexec"] or fd0["target"] != "/dev/null":
        raise ReductionIncomplete("reducer stdin is not read-only /dev/null")
    if "ro" not in identity["input_mount"]["mount_options"].split(","):
        raise ReductionIncomplete("reducer capture view is not read-only")
    if (
        identity["usr_mount"]["filesystem_type"] != "erofs"
        or "ro" not in identity["usr_mount"]["mount_options"].split(",")
    ):
        raise ReductionIncomplete("reducer toolchain is not the sealed EROFS mount")


def validate_claim_registry(raw: bytes) -> dict[str, Any]:
    if sha256_bytes(raw) != INPUT_DIGESTS["f0-supervisor-c4-claim-registry-v1.json"]:
        raise ReductionIncomplete("claim registry digest differs from reducer policy")
    registry = strict_json(raw, "claim registry", ReductionIncomplete)
    require_object(
        registry,
        {"schema_version", "artifact_id", "authority", "claims", "authorization"},
        "claim registry",
        ReductionIncomplete,
    )
    if (
        registry["schema_version"] != 1
        or registry["artifact_id"]
        != "dynamic-residency-f0-v5-supervisor-v3-candidate4-claim-registry"
        or registry["authority"] != "repository_claim_catalog_not_candidate_result"
    ):
        raise ReductionIncomplete("claim registry identity differs")
    expected_authorization = {
        "F0_local_acceptance",
        "external_R11_review",
        "G0_authorized",
        "self_authorization",
        "protection_claim",
    }
    if (
        not isinstance(registry["authorization"], dict)
        or set(registry["authorization"]) != expected_authorization
        or any(value is not False for value in registry["authorization"].values())
    ):
        raise ReductionIncomplete("claim registry authorization differs")
    if not isinstance(registry["claims"], list) or len(registry["claims"]) != 11:
        raise ReductionIncomplete("claim registry cardinality differs")
    identifiers: set[str] = set()
    predicates: set[str] = set()
    for row in registry["claims"]:
        require_object(row, {"id", "class", "fast", "full"}, "claim row", ReductionIncomplete)
        identifier = row["id"]
        if not isinstance(identifier, str) or not identifier or identifier in identifiers:
            raise ReductionIncomplete("claim registry identifier differs")
        identifiers.add(identifier)
        full = require_object(
            row["full"],
            {"allowed_statuses", "evidence", "status_rule"},
            f"claim full policy {identifier}",
            ReductionIncomplete,
        )
        rule = full["status_rule"]
        if not isinstance(rule, dict) or rule.get("kind") not in {"boolean", "fixed"}:
            raise ReductionIncomplete("claim status rule differs")
        if rule["kind"] == "boolean":
            if set(rule) != {"kind", "predicate_id", "true_status", "false_status"}:
                raise ReductionIncomplete("Boolean claim rule fields differ")
            predicates.add(rule["predicate_id"])
        elif set(rule) != {"kind", "status"}:
            raise ReductionIncomplete("fixed claim rule fields differ")
    if predicates != LOCAL_PREDICATES:
        raise ReductionIncomplete("local claim predicate registry differs")
    return registry


def validate_worker_provenance(value: Any, component: str) -> None:
    provenance = require_object(
        value,
        {
            "bootstrap_input_hashes",
            "post_model_load_input_hashes",
            "input_hashes_before",
            "input_hashes_after",
            "input_root_sha256",
            "executed_model_source_hashes",
            "bootstrap_source_execution_check",
            "runtime_input_write_prevention_enforced",
            "input_stability_during_execution_proved",
        },
        f"worker provenance {component}",
        StrictResultInvalid,
    )
    for key in (
        "bootstrap_input_hashes",
        "post_model_load_input_hashes",
        "input_hashes_before",
        "input_hashes_after",
    ):
        if provenance[key] != INPUT_DIGESTS:
            raise StrictResultInvalid(f"worker provenance input hashes differ: {component}")
    if (
        provenance["input_root_sha256"] != INPUT_ROOT_SHA256
        or provenance["executed_model_source_hashes"]
        != {
            "f0_supervisor_lts_v3.py": INPUT_DIGESTS["f0_supervisor_lts_v3.py"],
            "f0_supervisor_orchestrator_v3.py": INPUT_DIGESTS[
                "f0_supervisor_orchestrator_v3.py"
            ],
        }
        or provenance["bootstrap_source_execution_check"] is not True
        or provenance["runtime_input_write_prevention_enforced"] is not False
        or provenance["input_stability_during_execution_proved"] is not False
    ):
        raise StrictResultInvalid(f"worker provenance semantics differ: {component}")


def validate_static_result(result: Any) -> bool:
    value = require_object(
        result,
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
        "static result",
        StrictResultInvalid,
    )
    if value["component"] != "static-registries":
        raise StrictResultInvalid("static result component differs")
    validate_worker_provenance(value["worker_provenance"], "static-registries")
    claim = require_object(
        value["claim_registry"],
        {"artifact_id", "claim_count", "sha256", "candidate_authority_all_false"},
        "static claim registry receipt",
        StrictResultInvalid,
    )
    if claim != {
        "artifact_id": "dynamic-residency-f0-v5-supervisor-v3-candidate4-claim-registry",
        "claim_count": 11,
        "sha256": INPUT_DIGESTS["f0-supervisor-c4-claim-registry-v1.json"],
        "candidate_authority_all_false": True,
    }:
        raise StrictResultInvalid("static claim registry receipt differs")
    for label, expected_count in (("child", 56), ("orchestrator", 46)):
        row = require_object(
            value[label],
            {
                "declared_action_count",
                "write_policy_count",
                "write_policy_exact_registry_coverage",
                "required_write_policy_count",
                "required_write_policy_exact_registry_coverage",
                "required_writes_are_allowed",
            },
            f"static {label} registry",
            StrictResultInvalid,
        )
        if row != {
            "declared_action_count": expected_count,
            "write_policy_count": expected_count,
            "write_policy_exact_registry_coverage": True,
            "required_write_policy_count": expected_count,
            "required_write_policy_exact_registry_coverage": True,
            "required_writes_are_allowed": True,
        }:
            raise StrictResultInvalid(f"static {label} registry differs")
    if (
        value["declared_independence_ids"] != INDEPENDENCE_IDS
        or value["declared_independence_ids_unique"] is not True
        or value["semantic_registry_sha256"] != SEMANTIC_REGISTRY_SHA256
        or value["typed_store_attack_registry_exact"] is not True
        or value["reachability_checked"] is not False
    ):
        raise StrictResultInvalid("static semantic registry differs")
    require_bool(value["passed"], "static passed", StrictResultInvalid)
    return value["passed"]


def validate_tests_result(result: Any) -> bool:
    value = require_object(
        result,
        {"component", "tests", "passed", "worker_provenance"},
        "tests result",
        StrictResultInvalid,
    )
    if value["component"] != "tests":
        raise StrictResultInvalid("tests component differs")
    validate_worker_provenance(value["worker_provenance"], "tests")
    if not isinstance(value["tests"], list) or len(value["tests"]) != len(TEST_MARKERS):
        raise StrictResultInvalid("tests receipt cardinality differs")
    for row, (path, marker) in zip(value["tests"], TEST_MARKERS.items(), strict=True):
        receipt = require_object(
            row,
            {
                "path",
                "returncode",
                "stdout",
                "stderr",
                "expected_prefix",
                "exact_success_marker",
                "passed",
            },
            f"test receipt {path}",
            StrictResultInvalid,
        )
        prefix = marker.rsplit("=", 1)[0] + "="
        if receipt != {
            "path": path,
            "returncode": 0,
            "stdout": marker,
            "stderr": "",
            "expected_prefix": prefix,
            "exact_success_marker": True,
            "passed": True,
        }:
            raise StrictResultInvalid(f"hostile regression receipt differs: {path}")
    require_bool(value["passed"], "tests passed", StrictResultInvalid)
    return value["passed"]


EXPLORATION_KEYS = {
    "role",
    "reachable_exact_state_count",
    "unique_ordered_evidence_history_count",
    "edge_count",
    "reachable_action_count",
    "reachable_action_ids",
    "terminal_state_count",
    "decision_counts",
    "nonterminal_deadlock_count",
    "states_without_terminal_path",
    "winner_overwrite_count",
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


def validate_exploration(value: Any, role: str) -> tuple[bool, set[str]]:
    row = require_object(
        value, EXPLORATION_KEYS, f"{role} exploration", StrictResultInvalid
    )
    if row["role"] != role:
        raise StrictResultInvalid(f"{role} exploration role differs")
    integer_fields = (
        "reachable_exact_state_count",
        "unique_ordered_evidence_history_count",
        "edge_count",
        "reachable_action_count",
        "terminal_state_count",
        "nonterminal_deadlock_count",
        "states_without_terminal_path",
        "winner_overwrite_count",
        "protection_breach_terminal_count",
        "hostile_attempt_bound",
        "reacquisition_bound",
        "multiple_pending_arrival_state_count",
        "exact_state_key_collision_count",
    )
    for field in integer_fields:
        require_int(row[field], f"{role} {field}", StrictResultInvalid)
    actions = row["reachable_action_ids"]
    if (
        not isinstance(actions, list)
        or not actions
        or not all(isinstance(item, str) and item for item in actions)
        or actions != sorted(set(actions))
        or row["reachable_action_count"] != len(actions)
    ):
        raise StrictResultInvalid(f"{role} reachable action registry differs")
    decisions = row["decision_counts"]
    if (
        not isinstance(decisions, list)
        or not all(
            isinstance(item, list)
            and len(item) == 2
            and isinstance(item[0], str)
            and type(item[1]) is int
            and item[1] >= 0
            for item in decisions
        )
    ):
        raise StrictResultInvalid(f"{role} decision counts differ")
    required_true = (
        "hostile_bypass_explicit",
        "coaccessibility_only",
        "infinite_stutter_counterexample_present",
        "exact_ordered_history_state_identity",
        "bounded_exact_ordered_history_graph_exhaustive",
        "frontier_empty",
        "all_reachable_states_wf",
        "all_edges_target_reachable",
    )
    required_false = (
        "universal_termination_proved",
        "management_domain_refinement_proved",
        "monitor_protection_refinement_proved",
        "external_assumptions_discharged",
        "linux_refinement_proved",
        "semantic_verdict_issued",
    )
    for field in required_true + required_false:
        require_bool(row[field], f"{role} {field}", StrictResultInvalid)
    passed = bool(
        row["reachable_exact_state_count"] > 0
        and 0
        < row["unique_ordered_evidence_history_count"]
        <= row["reachable_exact_state_count"]
        and row["edge_count"] > 0
        and row["terminal_state_count"] > 0
        and row["nonterminal_deadlock_count"] == 0
        and row["states_without_terminal_path"] == 0
        and row["winner_overwrite_count"] == 0
        and row["protection_breach_terminal_count"] > 0
        and all(row[field] is True for field in required_true)
        and all(row[field] is False for field in required_false)
        and row["hostile_attempt_bound"] == 2
        and row["reacquisition_bound"] == 2
        and row["multiple_pending_arrival_state_count"] > 0
        and row["exact_state_key_collision_count"] == 0
    )
    return passed, set(actions)


PAIR_KEYS = {
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


def validate_commutation(value: Any, role: str, reachable_count: int) -> bool:
    row = require_object(
        value,
        {
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
        },
        f"{role} commutation",
        StrictResultInvalid,
    )
    pair_results = row["declared_pair_results"]
    if (
        row["role"] != role
        or row["reachable_exact_state_count"] != reachable_count
        or not isinstance(pair_results, list)
        or not pair_results
        or row["declared_independence_pair_count"] != len(pair_results)
    ):
        raise StrictResultInvalid(f"{role} commutation identity differs")
    pair_ids: list[str] = []
    for item in pair_results:
        pair = require_object(item, PAIR_KEYS, "commutation pair", StrictResultInvalid)
        if (
            not isinstance(pair["independence_id"], str)
            or not pair["independence_id"]
            or not isinstance(pair["source_predicate_id"], str)
            or not pair["source_predicate_id"]
        ):
            raise StrictResultInvalid("commutation pair identity differs")
        pair_ids.append(pair["independence_id"])
        for field in (
            "minimum_source_count",
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
        ):
            require_int(pair[field], f"commutation pair {field}", StrictResultInvalid)
        source = pair["source_state_count"]
        if (
            not isinstance(pair["actions"], list)
            or len(pair["actions"]) != 2
            or len(set(pair["actions"])) != 2
            or not all(isinstance(action, str) and action for action in pair["actions"])
            or pair["minimum_source_count"] <= 0
            or source < pair["minimum_source_count"]
            or pair["coenabled_state_count"] != source
            or pair["both_orders_enabled_count"] != source
            or pair["outcome_equal_count"] != source
            or pair["exact_equal_count"] + pair["ordered_history_distinct_count"] != source
            or pair["expected_history_relation"] not in {"EXACT", "ORDER_DISTINCT"}
            or any(
                pair[field] != 0
                for field in (
                    "preservation_failure_count",
                    "prefix_preservation_failure_count",
                    "audit_delta_failure_count",
                    "outcome_failure_count",
                    "history_relation_failure_count",
                )
            )
            or any(
                pair[field] != []
                for field in (
                    "preservation_counterexample_fingerprints",
                    "prefix_counterexample_fingerprints",
                    "audit_delta_counterexample_fingerprints",
                    "outcome_counterexample_fingerprints",
                    "history_counterexample_fingerprints",
                )
            )
            or pair["passed"] is not True
        ):
            raise StrictResultInvalid("commutation pair semantics differ")
    required = {
        "declared_pair_occurrences_exhaustive_over_reachable_states": True,
        "independence_relation_claimed_complete": False,
        "undeclared_pairs_assumed_independent": False,
        "reachability_uses_exact_state_identity": True,
        "ordered_history_quotiented_for_reachability": False,
        "check_scope": "LOCAL_TWO_STEP_EFFECT_COMMUTATION_ONLY",
        "outcome_projection_scope": "RECEIPT_CHAIN_ORDERING_METADATA_ONLY",
        "outcome_projection_retains_receipt_semantics_and_multiplicity": True,
        "outcome_projection_retains_causal_and_recovery_pointers": True,
        "outcome_projection_congruence_proved": False,
        "global_semantic_confluence_proved": False,
        "sealed_evidence_root_identity_proved": False,
        "passed": True,
    }
    if any(row[key] != expected for key, expected in required.items()):
        raise StrictResultInvalid(f"{role} commutation boundary differs")
    if len(pair_ids) != len(set(pair_ids)) or not set(pair_ids) <= set(INDEPENDENCE_IDS):
        raise StrictResultInvalid(f"{role} commutation registry differs")
    return True


def validate_child_result(result: Any, component: str, role: str) -> tuple[bool, bool, set[str]]:
    value = require_object(
        result,
        {"component", "role", "exploration", "commutation", "single_graph_reused", "worker_provenance"},
        f"{component} result",
        StrictResultInvalid,
    )
    if value["component"] != component or value["role"] != role:
        raise StrictResultInvalid(f"{component} identity differs")
    validate_worker_provenance(value["worker_provenance"], component)
    exploration_ok, actions = validate_exploration(value["exploration"], role)
    commutation_ok = validate_commutation(
        value["commutation"], role, value["exploration"]["reachable_exact_state_count"]
    )
    if value["single_graph_reused"] is not True:
        raise StrictResultInvalid(f"{component} did not reuse one graph")
    return exploration_ok, commutation_ok, actions


ORCHESTRATOR_KEYS = {
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
}


def validate_orchestrator_result(result: Any) -> bool:
    value = require_object(
        result,
        {"component", "result", "worker_provenance"},
        "orchestrator component",
        StrictResultInvalid,
    )
    if value["component"] != "orchestrator":
        raise StrictResultInvalid("orchestrator component identity differs")
    validate_worker_provenance(value["worker_provenance"], "orchestrator")
    row = require_object(
        value["result"], ORCHESTRATOR_KEYS, "orchestrator result", StrictResultInvalid
    )
    for field in (
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
    ):
        require_int(row[field], f"orchestrator {field}", StrictResultInvalid)
    if (
        not isinstance(row["terminal_counts"], dict)
        or not row["terminal_counts"]
        or not all(
            isinstance(key, str) and key and type(count) is int and count >= 0
            for key, count in row["terminal_counts"].items()
        )
    ):
        raise StrictResultInvalid("orchestrator terminal counts differ")
    required = {
        "exploration_semantics": "EXACT_REACHABILITY_OF_REPETITION_BOUNDED_MODEL",
        "nonterminal_deadlock_count": 0,
        "states_without_terminal_path": 0,
        "declared_action_count": 46,
        "reachable_action_count": 46,
        "missing_actions": [],
        "undeclared_actions": [],
        "semantic_verdict_always_absent": True,
        "published_artifact_type": "LOCAL_DISPOSITION_CAPSULE",
        "external_assumptions_discharged": False,
        "durable_store_refinement_proved": False,
        "issuance_registry_refinement_proved": False,
        "global_nonce_uniqueness_proved": False,
        "symbolic_authentication_discharged": False,
        "exact_state_identity_within_repetition_bound": True,
        "attached_fixture_terminal_trace_replay_checked": True,
        "attached_fixture_scenarios": [
            "CANDIDATE",
            "CANDIDATE_B_PRODUCER_ONLY",
            "CHECKER_REJECT_CHECKER_ONLY",
            "RESOURCE",
            "INTERNAL",
            "ABANDONED",
        ],
        "all_child_terminal_traces_composed": False,
        "parent_child_product_exhaustive": False,
        "store_attack_repetition_policy": "FIRST_ATTEMPT_PER_TYPED_CONTEXT_REPETITION_BOUND",
        "max_store_attack_attempts_per_typed_context": 1,
        "repetition_bounded_state_space_exhaustive": True,
        "unbounded_attack_history_frontier_empty": False,
        "partial_order_reduction_applied": False,
        "partial_order_equivalence_proved": False,
        "unbounded_repeated_store_attack_history_exhaustive": False,
        "attack_context_key_refinement_proved": False,
        "abandoned_terminal_requires_matching_ack": True,
        "typed_abandonment_conflict_withholds_assurance": True,
        "publication_fence_reauthorization_encoded": True,
        "publication_fence_store_refinement_proved": False,
        "coaccessibility_only": True,
        "universal_termination_proved": False,
        "infinite_stutter_counterexample_present": True,
        "assurance_breach_explicit": True,
        "guardian_survivability_proved": False,
        "external_semantic_verdict_issued": False,
    }
    if any(row[key] != expected for key, expected in required.items()):
        raise StrictResultInvalid("orchestrator fixed boundary differs")
    return bool(
        row["reachable_repetition_bounded_state_count"] > 0
        and row["edge_count"] > 0
        and row["multiple_store_attack_context_state_count"] > 0
        and row["owner_failure_with_pending_attack_state_count"] > 0
        and row["post_owner_publish_attack_state_count"] > 0
        and row["guardian_generation_capsule_state_count"] > 0
        and row["abandonment_conflict_breach_terminal_count"] > 0
        and row["assurance_breach_terminal_count"] > 0
    )


def validate_receipt(
    receipt: Any,
    component: str,
    role: str,
    deadline: int,
    manifest: dict[str, Any],
    plan_sha256: str,
    toolchain_sha256: str,
) -> tuple[bytes, str]:
    keys = {
        "schema_version",
        "component_id",
        "role",
        "sealed_plan_sha256",
        "input_root_sha256",
        "argv",
        "environment_sha256",
        "preexec_observation_size_sha256_and_bytes",
        "cgroup_path_and_id",
        "leader_pid_and_pidfd_identity",
        "started_monotonic_ns",
        "finished_monotonic_ns",
        "waitid_status",
        "deadline_classification",
        "stdout_size_sha256_and_bytes",
        "stderr_size_sha256_and_bytes",
        "result_payload_sha256",
        "result_protocol_framing_valid",
        "result_protocol_semantics_validated",
        "resource_counters",
        "cgroup_kill_used",
        "populated_zero_observed",
        "toolchain_identity",
        "launcher_returncode",
        "complete_capture_component",
        "candidate_receipts_authoritative",
        "externally_attested",
    }
    row = require_object(receipt, keys, f"receipt {component}", ReductionIncomplete)
    expected_argv = [
        "/usr/bin/python3",
        "-S",
        "-B",
        "INPUT/validate-f0-supervisor-lts-v3.py",
        "--component",
        component,
    ]
    environment_sha = sha256_bytes(
        canonical_bytes(
            {
                "PATH": "/usr/bin:/bin",
                "PYTHONPATH": "INPUT",
                "PYTHONDONTWRITEBYTECODE": "1",
                "PYTHONHASHSEED": "0",
            }
        )
    )
    if (
        row["schema_version"] != 1
        or row["component_id"] != component
        or row["role"] != role
        or row["sealed_plan_sha256"] != plan_sha256
        or row["input_root_sha256"] != INPUT_ROOT_SHA256
        or row["argv"] != expected_argv
        or row["environment_sha256"] != environment_sha
        or row["launcher_returncode"] != 0
        or row["result_protocol_framing_valid"] is not True
        or row["result_protocol_semantics_validated"] is not False
        or row["cgroup_kill_used"] is not True
        or row["populated_zero_observed"] is not True
        or row["complete_capture_component"] is not True
        or row["candidate_receipts_authoritative"] is not False
        or row["externally_attested"] is not False
    ):
        raise ReductionIncomplete(f"receipt fixed fields differ: {component}")
    if row["toolchain_identity"] != {
        "sha256": toolchain_sha256,
        "candidate4_admissible": True,
    }:
        raise ReductionIncomplete(f"receipt toolchain differs: {component}")
    deadline_row = row["deadline_classification"]
    if deadline_row != {
        "deadline_seconds": deadline,
        "exceeded": False,
        "clock": "CLOCK_MONOTONIC",
    }:
        raise ReductionIncomplete(f"receipt deadline differs: {component}")
    waitid = row["waitid_status"]
    require_object(
        waitid,
        {"code", "status", "termination", "exit_code", "signal"},
        f"waitid {component}",
        ReductionIncomplete,
    )
    if (
        waitid["termination"] != "EXITED_ZERO"
        or waitid["exit_code"] != 0
        or waitid["signal"] != 0
    ):
        raise ReductionIncomplete(f"receipt termination differs: {component}")
    preexec = require_object(
        row["preexec_observation_size_sha256_and_bytes"],
        {"path", "size", "sha256", "validated_fields", "candidate_release_after_validation"},
        f"preexec receipt {component}",
        ReductionIncomplete,
    )
    expected_preexec = f"{component}.preexec.raw"
    if (
        preexec["path"] != expected_preexec
        or preexec["candidate_release_after_validation"] is not True
        or preexec["validated_fields"]
        != [
            "fd_table",
            "uid_gid_groups",
            "capability_sets",
            "no_new_privileges",
            "seccomp_mode",
            "mountinfo",
            "namespace_ids",
            "cgroup_identity",
            "interface_inventory",
        ]
    ):
        raise ReductionIncomplete(f"preexec receipt semantics differ: {component}")
    for stream, maximum in (("stdout", MAX_JSON_BYTES), ("stderr", 16777216)):
        binding = require_object(
            row[f"{stream}_size_sha256_and_bytes"],
            {"path", "size", "sha256"},
            f"{stream} binding {component}",
            ReductionIncomplete,
        )
        path = CAPTURE_ROOT / "raw" / f"{component}.{stream}.raw"
        raw = read_file(path, f"{stream} {component}", maximum)
        if (
            binding["path"] != path.name
            or binding["size"] != len(raw)
            or binding["sha256"] != sha256_bytes(raw)
        ):
            raise ReductionIncomplete(f"{stream} binding differs: {component}")
        if stream == "stderr" and raw:
            raise ReductionIncomplete(f"stderr is nonempty: {component}")
        if stream == "stdout":
            stdout = raw
    preexec_raw = read_file(
        CAPTURE_ROOT / "raw" / expected_preexec,
        f"preexec {component}",
        1048576,
    )
    if preexec["size"] != len(preexec_raw) or preexec["sha256"] != sha256_bytes(preexec_raw):
        raise ReductionIncomplete(f"preexec bytes differ: {component}")
    marker = b"RESULT_JSON="
    ending = b""
    if stdout.endswith(b"\r\n"):
        ending = b"\r\n"
    elif stdout.endswith((b"\n", b"\r")):
        ending = stdout[-1:]
    payload = stdout[len(marker) : len(stdout) - len(ending) if ending else None]
    if (
        not stdout.startswith(marker)
        or not payload
        or b"\n" in payload
        or b"\r" in payload
        or row["result_payload_sha256"] != sha256_bytes(payload)
    ):
        raise ReductionIncomplete(f"result framing receipt differs: {component}")
    return payload, sha256_bytes(payload)


def validate_capture() -> tuple[dict[str, Any], dict[str, bytes], dict[str, str], dict[str, Any], str, str]:
    require_directory(CAPTURE_ROOT, "capture root", 0o555)
    require_directory(CAPTURE_ROOT / "raw", "capture raw", 0o555)
    require_directory(CAPTURE_ROOT / "INPUT", "capture input", 0o555)
    expected_top = {
        "INPUT",
        "raw",
        "sealed-plan.json",
        "capture-contract.json",
        "toolchain-identity.json",
        "capture-manifest.json",
        "RAW_COMMIT.json",
    }
    require_exact_names(CAPTURE_ROOT, expected_top, "capture root")
    require_exact_names(CAPTURE_ROOT / "INPUT", set(INPUT_DIGESTS), "capture input")
    expected_raw = {
        f"{component}.{suffix}"
        for component in COMPONENT_ORDER
        for suffix in ("stdout.raw", "stderr.raw", "preexec.raw", "receipt.json")
    }
    require_exact_names(CAPTURE_ROOT / "raw", expected_raw, "capture raw")

    commit_raw = read_file(CAPTURE_ROOT / "RAW_COMMIT.json", "raw commit", MAX_METADATA_BYTES)
    commit = strict_json(commit_raw, "raw commit", ReductionIncomplete)
    require_object(
        commit,
        {
            "schema_version",
            "artifact_id",
            "run_id",
            "capture_status",
            "contract_sha256",
            "manifest_sha256",
            "publication",
            "commit_authority",
            "candidate_bytes_positive_eligible",
            "reduction_performed",
        },
        "raw commit",
        ReductionIncomplete,
    )
    if canonical_bytes(commit) != commit_raw:
        raise ReductionIncomplete("raw commit is not canonical")
    if (
        commit["schema_version"] != 1
        or commit["artifact_id"] != "f0-c4-raw-capture-commit-v1"
        or commit["capture_status"] != "RAW_CAPTURE_COMPLETE"
        or commit["contract_sha256"] != CONTRACT_SHA256
        or commit["publication"] != "renameat2_RENAME_NOREPLACE_then_parent_fsync"
        or commit["commit_authority"] != "CAPTURE_SUPERVISOR"
        or commit["candidate_bytes_positive_eligible"] is not False
        or commit["reduction_performed"] is not False
    ):
        raise ReductionIncomplete("raw commit identity differs")

    manifest_raw = read_file(
        CAPTURE_ROOT / "capture-manifest.json", "capture manifest", MAX_METADATA_BYTES
    )
    manifest = strict_json(manifest_raw, "capture manifest", ReductionIncomplete)
    require_object(
        manifest,
        {
            "schema_version",
            "artifact_id",
            "run_id",
            "campaign_class",
            "capture_status",
            "contract_sha256",
            "sealed_plan_sha256",
            "input_digests",
            "input_root_sha256",
            "toolchain_identity_sha256",
            "platform_capacity",
            "evidence_storage",
            "systemd_guardian",
            "candidate_identity",
            "component_order",
            "component_receipt_sha256",
            "raw_total_bytes",
            "started_and_finished_clock",
            "finished_monotonic_ns",
            "candidate_summary_is_an_oracle",
            "external_attestation",
            "authorization",
        },
        "capture manifest",
        ReductionIncomplete,
    )
    manifest_sha = sha256_bytes(manifest_raw)
    if canonical_bytes(manifest) != manifest_raw or commit["manifest_sha256"] != manifest_sha:
        raise ReductionIncomplete("capture manifest canonical digest differs")
    if (
        manifest["schema_version"] != 1
        or manifest["artifact_id"] != "f0-c4-authority-disjoint-root-capture-v1"
        or manifest["run_id"] != commit["run_id"]
        or manifest["campaign_class"] != "candidate4-exact"
        or manifest["capture_status"] != "RAW_CAPTURE_COMPLETE"
        or manifest["contract_sha256"] != CONTRACT_SHA256
        or manifest["input_digests"] != INPUT_DIGESTS
        or manifest["input_root_sha256"] != INPUT_ROOT_SHA256
        or manifest["component_order"] != list(COMPONENT_ORDER)
        or set(manifest["component_receipt_sha256"]) != set(COMPONENT_ORDER)
        or manifest["started_and_finished_clock"] != "CLOCK_MONOTONIC"
        or manifest["candidate_summary_is_an_oracle"] is not False
        or manifest["external_attestation"] is not False
        or not isinstance(manifest["authorization"], dict)
        or any(value is not False for value in manifest["authorization"].values())
    ):
        raise ReductionIncomplete("capture manifest fixed fields differ")
    require_int(manifest["raw_total_bytes"], "raw total", ReductionIncomplete)
    require_int(manifest["finished_monotonic_ns"], "finish monotonic", ReductionIncomplete, 1)
    for name, expected_digest in INPUT_DIGESTS.items():
        snapshot_raw = read_file(
            CAPTURE_ROOT / "INPUT" / name,
            f"snapshot input {name}",
            268435456,
        )
        if sha256_bytes(snapshot_raw) != expected_digest:
            raise ReductionIncomplete(f"snapshot input digest differs: {name}")

    contract_raw = read_file(
        CAPTURE_ROOT / "capture-contract.json", "captured contract", MAX_METADATA_BYTES
    )
    if sha256_bytes(contract_raw) != CONTRACT_SHA256:
        raise ReductionIncomplete("captured contract digest differs")
    plan_raw = read_file(CAPTURE_ROOT / "sealed-plan.json", "sealed plan", MAX_METADATA_BYTES)
    plan_sha = sha256_bytes(plan_raw)
    if plan_sha != manifest["sealed_plan_sha256"]:
        raise ReductionIncomplete("sealed plan digest differs")
    plan = strict_json(plan_raw, "sealed plan", ReductionIncomplete)
    require_object(
        plan,
        {
            "schema_version",
            "contract_sha256",
            "input_root_sha256",
            "parallel_execution",
            "environment",
            "components",
            "resource_policy",
        },
        "sealed plan",
        ReductionIncomplete,
    )
    if (
        plan["schema_version"] != 1
        or plan["contract_sha256"] != CONTRACT_SHA256
        or plan["input_root_sha256"] != INPUT_ROOT_SHA256
        or plan["parallel_execution"] is not False
        or not isinstance(plan["components"], list)
        or [row.get("id") for row in plan["components"]] != list(COMPONENT_ORDER)
    ):
        raise ReductionIncomplete("sealed plan fixed fields differ")

    toolchain_raw = read_file(
        CAPTURE_ROOT / "toolchain-identity.json", "toolchain identity", MAX_METADATA_BYTES
    )
    toolchain_sha = sha256_bytes(toolchain_raw)
    toolchain = strict_json(toolchain_raw, "toolchain identity", ReductionIncomplete)
    if (
        toolchain_sha != manifest["toolchain_identity_sha256"]
        or canonical_bytes(toolchain) != toolchain_raw
        or not isinstance(toolchain, dict)
        or toolchain.get("mode") != "content_addressed_immutable_image"
        or toolchain.get("candidate4_admissible") is not True
        or toolchain.get("externally_authenticated") is not False
        or toolchain.get("manifest", {}).get("image_format") != "erofs"
        or toolchain.get("mount_identity", {}).get("filesystem_type") != "erofs"
        or "ro"
        not in str(toolchain.get("mount_identity", {}).get("mount_options", "")).split(",")
    ):
        raise ReductionIncomplete("toolchain identity differs")

    payloads: dict[str, bytes] = {}
    payload_digests: dict[str, str] = {}
    raw_sum = 0
    for component, role, deadline in COMPONENTS:
        receipt_raw = read_file(
            CAPTURE_ROOT / "raw" / f"{component}.receipt.json",
            f"receipt {component}",
            1048576,
        )
        if sha256_bytes(receipt_raw) != manifest["component_receipt_sha256"][component]:
            raise ReductionIncomplete(f"receipt manifest binding differs: {component}")
        receipt = strict_json(receipt_raw, f"receipt {component}", ReductionIncomplete)
        if canonical_bytes(receipt) != receipt_raw:
            raise ReductionIncomplete(f"receipt is not canonical: {component}")
        payload, payload_sha = validate_receipt(
            receipt, component, role, deadline, manifest, plan_sha, toolchain_sha
        )
        payloads[component] = payload
        payload_digests[component] = payload_sha
        raw_sum += sum(
            (CAPTURE_ROOT / "raw" / f"{component}.{suffix}").stat().st_size
            for suffix in ("stdout.raw", "stderr.raw", "preexec.raw", "receipt.json")
        )
    if raw_sum != manifest["raw_total_bytes"]:
        raise ReductionIncomplete("raw total receipt differs")
    registry_raw = read_file(
        CAPTURE_ROOT / "INPUT" / "f0-supervisor-c4-claim-registry-v1.json",
        "claim registry snapshot",
        MAX_METADATA_BYTES,
    )
    registry = validate_claim_registry(registry_raw)
    return manifest, payloads, payload_digests, registry, sha256_bytes(commit_raw), manifest_sha


def claims_from_registry(registry: dict[str, Any], predicates: dict[str, bool]) -> dict[str, Any]:
    claims: dict[str, Any] = {}
    for row in registry["claims"]:
        policy = row["full"]
        rule = policy["status_rule"]
        if rule["kind"] == "fixed":
            status_value = rule["status"]
        else:
            predicate = predicates[rule["predicate_id"]]
            status_value = rule["true_status"] if predicate else rule["false_status"]
        if status_value not in policy["allowed_statuses"]:
            raise ReductionIncomplete("derived claim status violates fixed registry")
        claims[row["id"]] = {"status": status_value, "evidence": policy["evidence"]}
    return claims


def result_frame(
    run_id: str,
    status_value: str,
    failure_class: str | None,
    raw_commit_sha256: str | None,
    raw_manifest_sha256: str | None,
    payload_digests: dict[str, str],
    predicates: dict[str, bool],
    claims: dict[str, Any],
    identity: dict[str, Any],
) -> dict[str, Any]:
    passed = status_value == "REDUCTION_PASS"
    return {
        "schema_version": 1,
        "artifact_id": "f0-c4-post-run-reduction-v1",
        "run_id": run_id,
        "reduction_status": status_value,
        "failure_class": failure_class,
        "contract_sha256": CONTRACT_SHA256,
        "raw_commit_sha256": raw_commit_sha256,
        "raw_manifest_sha256": raw_manifest_sha256,
        "component_result_sha256": payload_digests,
        "predicates": predicates,
        "claims": claims,
        "maximum_local_disposition": (
            "AUTHORITY_DISJOINT_CAPTURED_LOCAL_CANDIDATE_ONLY"
            if passed
            else "NO_POSITIVE_LOCAL_DISPOSITION"
        ),
        "candidate_summary_is_an_oracle": False,
        "reducer_uses_only_finalized_capture": True,
        "strict_result_json_parsed_after_capture": bool(payload_digests),
        "positive_eligible": passed,
        "authorization": {**AUTHORIZATION, "local_bounded_candidate": passed},
        "runtime_identity": identity,
    }


def reduce_capture(run_id: str) -> dict[str, Any]:
    identity = runtime_identity()
    validate_runtime_identity(identity)
    try:
        manifest, payloads, payload_digests, registry, commit_sha, manifest_sha = (
            validate_capture()
        )
    except ReductionIncomplete:
        return result_frame(
            run_id,
            "REDUCTION_INCOMPLETE",
            "PRECONDITION_REJECTED",
            None,
            None,
            {},
            {},
            {},
            identity,
        )
    if manifest["run_id"] != run_id:
        return result_frame(
            run_id,
            "REDUCTION_INCOMPLETE",
            "PRECONDITION_REJECTED",
            commit_sha,
            manifest_sha,
            {},
            {},
            {},
            identity,
        )
    try:
        parsed = {
            component: strict_json(payload, component, StrictResultInvalid)
            for component, payload in payloads.items()
        }
        static_ok = validate_static_result(parsed["static-registries"])
        tests_ok = validate_tests_result(parsed["tests"])
        producer_ok, producer_commutation, producer_actions = validate_child_result(
            parsed["child-bundle-producer"], "child-bundle-producer", "PRODUCER"
        )
        checker_ok, checker_commutation, checker_actions = validate_child_result(
            parsed["child-bundle-checker"], "child-bundle-checker", "CHECKER"
        )
        parent_ok = validate_orchestrator_result(parsed["orchestrator"])
    except StrictResultInvalid:
        return result_frame(
            run_id,
            "REDUCTION_REJECT",
            "STRICT_RESULT_INVALID",
            commit_sha,
            manifest_sha,
            payload_digests,
            {},
            {},
            identity,
        )
    child_registry_exact = len(producer_actions | checker_actions) == 56
    predicates = {
        "FAST_MUTATION_STATIC": static_ok and tests_ok,
        "CHILD_EXACT_FIXTURE_BOUNDED": producer_ok and checker_ok and child_registry_exact,
        "PARENT_EXACT_REPETITION_BOUNDED": parent_ok,
        "DECLARED_LOCAL_EFFECT_COMMUTATION": (
            producer_commutation and checker_commutation
        ),
    }
    claims = claims_from_registry(registry, predicates)
    passed = all(predicates.values())
    return result_frame(
        run_id,
        "REDUCTION_PASS" if passed else "REDUCTION_REJECT",
        None if passed else "REDUCER_REJECTED",
        commit_sha,
        manifest_sha,
        payload_digests,
        predicates,
        claims,
        identity,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", args.run_id) is None:
        raise SystemExit("unsafe run ID")
    normalize_stdin()
    result = reduce_capture(args.run_id)
    encoded = canonical_bytes(result).rstrip(b"\n")
    if len(encoded) > 1048576:
        raise SystemExit("reducer result exceeds output bound")
    os.write(1, b"REDUCTION_JSON=" + encoded + b"\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
