#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="$ROOT/capsched-models/validation/validate-architecture-freeze-assurance-v2.py"
REAL_STUB="$ROOT/capsched-models/validation/verify-architecture-freeze-assurance-v2-real.py"
PROTOCOL="$ROOT/capsched-models/analysis/architecture-freeze-external-assurance-protocol-v2.json"
HOSTILE_REVIEW="$ROOT/capsched-models/analysis/architecture-freeze-assurance-v2-hostile-review-v1.json"
TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1

python3 - "$VALIDATOR" "$REAL_STUB" "$PROTOCOL" "$HOSTILE_REVIEW" <<'PY'
import ast
import base64
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import sys

path = Path(sys.argv[1]).resolve()
real_stub_path = Path(sys.argv[2]).resolve()
protocol_path = Path(sys.argv[3]).resolve()
hostile_review_path = Path(sys.argv[4]).resolve()
source = path.read_text(encoding="utf-8")
if any(token in source for token in ("os.environ", "os.getenv", "Ed25519PrivateKey")):
    raise SystemExit("verifier contains an environment trust path or private-key API")
if any(token in source for token in ("REAL_ACCEPT_GRANTS", "verify-real", '"real-external"')):
    raise SystemExit("fixture verifier contains a real-mode or real-grant path")
tree = ast.parse(source)
architecture_frozen_fields = 0
for node in ast.walk(tree):
    if not isinstance(node, ast.Dict):
        continue
    for key, value_node in zip(node.keys, node.values):
        if isinstance(key, ast.Constant) and key.value == "architecture_frozen":
            architecture_frozen_fields += 1
            if not isinstance(value_node, ast.Constant) or value_node.value is not False:
                raise SystemExit("verifier has a path to architecture_frozen=true")
if architecture_frozen_fields < 1:
    raise SystemExit("verifier architecture_frozen claim ceiling is not explicit")
stub_source = real_stub_path.read_text(encoding="utf-8")
stub_tree = ast.parse(stub_source)
for node in ast.walk(stub_tree):
    if isinstance(node, (ast.Call, ast.With)):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id in {"open", "exec", "eval", "compile", "input"}:
                raise SystemExit("real stub contains an evidence-I/O or execution path")
if any(token in stub_source for token in ("argparse", "pathlib", "json", "subprocess")):
    raise SystemExit("real stub parses or executes evidence")
spec = importlib.util.spec_from_file_location("archfreeze_jcs_vectors", path)
if spec is None or spec.loader is None:
    raise SystemExit("cannot import verifier")
af = importlib.util.module_from_spec(spec)
spec.loader.exec_module(af)

value = {
    "\r": "cr",
    "1": "one",
    "\u0080": "control",
    "\u00f6": "latin",
    "\u20ac": "euro",
    "\U0001f600": "emoji",
    "\ue000": "private-use",
}
expected = (
    '{"\\r":"cr","1":"one","\u0080":"control","\u00f6":"latin",'
    '"\u20ac":"euro","\U0001f600":"emoji","\ue000":"private-use"}'
).encode("utf-8")
if af.jcs_bytes(value) != expected:
    raise SystemExit("RFC 8785 UTF-16 property ordering vector failed")
af.parse_canonical_json(expected, "known-good JCS vector")

bad_vectors = [
    b'{"n":-0}',
    b'{"n":1.0}',
    b'{"n":9007199254740992}',
    b'{"x":1,"x":2}',
    b'{"e\\u0301":1}',
]
for raw in bad_vectors:
    try:
        af.parse_canonical_json(raw, "hostile JCS vector")
    except af.VerificationError:
        continue
    raise SystemExit("hostile JCS vector was accepted: " + repr(raw))

protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
if protocol["claims"]["protocol_implemented"] is not False:
    raise SystemExit("protocol overclaims real implementation")
if protocol["claims"]["real_verifier_implemented"] is not False:
    raise SystemExit("protocol overclaims real verifier implementation")
if protocol["claims"]["architecture_frozen"] is not False:
    raise SystemExit("protocol overclaims architecture freeze")

quorum = protocol["campaign_log"]["checkpoint_witness_parameters"]
if quorum != {
    "N": 4,
    "t": 3,
    "f": 1,
    "minimum_two_quorum_intersection": 2,
    "intersection_formula": "2*t-N",
    "required_safety_inequality": "2*t-N>f",
    "instantiated_safety_inequality": "2>1",
    "honest_witness_rule": "one_checkpoint_per_campaign_checkpoint_kind_and_sequence_after_full_deterministic_replay",
    "claim_boundary": "safety_requires_at_most_f_byzantine_witnesses_and_unbroken_hash_and_signature_assumptions",
}:
    raise SystemExit("checkpoint witness N/t/f contract drifted")
if 2 * quorum["t"] - quorum["N"] <= quorum["f"]:
    raise SystemExit("checkpoint witness quorums do not intersect beyond f")
quorums = [set(rows) for rows in itertools.combinations(range(quorum["N"]), quorum["t"])]
if min(len(left & right) for left in quorums for right in quorums) != 2:
    raise SystemExit("checkpoint quorum intersection enumeration failed")
for byzantine in ({index} for index in range(quorum["N"])):
    if any(not ((left & right) - byzantine) for left in quorums for right in quorums):
        raise SystemExit("an admission and terminal quorum can intersect only in Byzantine witnesses")

schemas = protocol["exact_object_schemas"]
admission_schema = schemas["CampaignSubmissionAdmissionPayload"]
if set(admission_schema["exact_keys"]) != {
    "assignment_id", "campaign_id", "capsule_digest", "event_index",
    "event_log_root_digest_after_append", "event_tree_size_after_append",
    "object_class", "object_digest", "post_assignment_state_digest",
    "prior_assignment_state_digest", "schema",
}:
    raise SystemExit("submission-admission exact schema drifted")
if admission_schema["checkpoint_signatures"] != (
    "exact_3_of_4_checkpoint_witnesses_after_append_and_assignment_state_transition"
):
    raise SystemExit("submission admission is not fixed to 3-of-4 witnesses")
if protocol["campaign_log"]["valid_campaign_submission_requires_object_signature_and_3_of_4_event_index_admission"] is not True:
    raise SystemExit("raw signed objects can bypass campaign admission")
replay_relations = set(schemas["CampaignEventReplay"]["exact_relations"])
if "each_admission_matches_same_position_event_object_and_post_append_root" not in replay_relations:
    raise SystemExit("event replay does not bind admissions to exact appended roots")
if "replaying_all_events_produces_exact_terminal_map_digest_and_root" not in replay_relations:
    raise SystemExit("event replay does not derive the authenticated terminal map")
reveal_schema = schemas["SignedReviewRevealPayload"]
if "terminal_checkpoint_digest" in reveal_schema["exact_keys"]:
    raise SystemExit("reveal schema cyclically binds its future terminal checkpoint")
if set(reveal_schema["forbidden_keys"]) != {
    "future_checkpoint_digest", "terminal_checkpoint_digest"
}:
    raise SystemExit("reveal future-checkpoint prohibition drifted")
decision_keys = set(schemas["DecisionAuthorizationPayload"]["exact_keys"])
if "terminal_checkpoint_digest" not in decision_keys:
    raise SystemExit("DecisionAuthorization does not bind terminal checkpoint")
if protocol["review_commit_reveal"]["terminal_checkpoint_later_includes_every_reveal"] is not True:
    raise SystemExit("terminal checkpoint does not follow and include reveals")

def length_delimited_transcript(name: str, fields: list[bytes]) -> bytes:
    domain = b"LINUX-CAP-ARCHFREEZE-V2/" + name.encode("ascii") + b"\0"
    return domain + b"".join(len(field).to_bytes(8, "big") + field for field in fields)

def terminal_map_key(campaign_id: str, assignment_id: str) -> str:
    raw = length_delimited_transcript(
        "terminal-map-key", [campaign_id.encode(), assignment_id.encode()]
    )
    return af.sha256_digest(raw)

vectors = protocol["machine_test_vectors"]
key_vector = vectors["terminal_map_key_v1"]
computed_key = terminal_map_key(
    key_vector["campaign_id"], key_vector["assignment_id"]
)
if computed_key != key_vector["expected_digest"]:
    raise SystemExit("terminal-map key vector failed")

commitment = vectors["review_commitment_v1"]
commitment_raw = length_delimited_transcript(
    "review-commitment",
    [
        commitment["campaign_id"].encode(),
        commitment["capsule_digest"].encode("ascii"),
        commitment["assignment_id"].encode(),
        commitment["terminal_map_key"].encode("ascii"),
        af.jcs_bytes(commitment["review_payload"]),
        base64.b64decode(commitment["nonce_b64"], validate=True),
    ],
)
if af.sha256_digest(commitment_raw) != commitment["expected_digest"]:
    raise SystemExit("review commitment vector failed")

event_vector = vectors["campaign_event_leaf_v1"]
event = event_vector["event"]
if set(event) != set(schemas["CampaignEvent"]["exact_keys"]):
    raise SystemExit("campaign event vector and exact schema disagree")
event_bytes = af.jcs_bytes(event)
event_leaf = hashlib.sha256(
    b"\x02"
    + event["event_index"].to_bytes(8, "big")
    + len(event_bytes).to_bytes(8, "big")
    + event_bytes
).digest()
if "sha256:" + event_leaf.hex() != event_vector["expected_leaf_digest"]:
    raise SystemExit("campaign event leaf vector failed")
if af.sha256_digest(b"\x04") != event_vector["expected_empty_tree_digest"]:
    raise SystemExit("campaign empty-tree vector failed")

reveal = vectors["signed_reveal_v1"]
if set(reveal["payload"]) != set(reveal_schema["exact_keys"]):
    raise SystemExit("signed reveal vector and exact schema disagree")
reveal_bytes = af.jcs_bytes(reveal["payload"])
if af.sha256_digest(reveal_bytes) != reveal["expected_payload_digest"]:
    raise SystemExit("signed reveal payload vector failed")
signature_message = af.signed_message(
    b"LINUX-CAP-ARCHFREEZE-V2\0",
    "linux-cap.archfreeze.v2.signed-review-reveal",
    reveal_bytes,
)
if af.sha256_digest(signature_message) != reveal["expected_signature_message_digest"]:
    raise SystemExit("signed reveal transcript vector failed")

map_vector = vectors["terminal_map_root_v1"]
entries = map_vector["entries"]
if entries != sorted(entries, key=lambda row: row["terminal_map_key"]):
    raise SystemExit("terminal-map test entries are not key sorted")
if len(entries) != 4 or len({row["terminal_map_key"] for row in entries}) != 4:
    raise SystemExit("terminal-map test vector is not an exact four-key map")
leaf_hashes = []
for entry in entries:
    if terminal_map_key(entry["campaign_id"], entry["assignment_id"]) != entry["terminal_map_key"]:
        raise SystemExit("terminal-map entry key derivation failed")
    raw = af.jcs_bytes(entry)
    leaf_hashes.append(hashlib.sha256(b"\x00" + len(raw).to_bytes(8, "big") + raw).digest())
if ["sha256:" + row.hex() for row in leaf_hashes] != map_vector["expected_leaf_digests"]:
    raise SystemExit("terminal-map leaf vector failed")
left = hashlib.sha256(b"\x01" + leaf_hashes[0] + leaf_hashes[1]).digest()
right = hashlib.sha256(b"\x01" + leaf_hashes[2] + leaf_hashes[3]).digest()
root = hashlib.sha256(b"\x01" + left + right).digest()
if "sha256:" + root.hex() != map_vector["expected_root_digest"]:
    raise SystemExit("terminal-map root vector failed")

if protocol["fixture"]["mechanics_profile_digest"] != af.fixture_mechanics_profile_digest():
    raise SystemExit("fixture mechanics profile digest drifted from protocol")

assignments = [row["assignment_id"] for row in entries]

def replay(events: list[tuple[str, str, str | None]]) -> dict[str, str]:
    states = {assignment: "UNSET" for assignment in assignments}
    closed = False
    for kind, assignment, verdict in events:
        if assignment not in states or closed:
            raise ValueError("invalid event outside open roster map")
        state = states[assignment]
        if state.startswith("REJECTED"):
            continue
        if kind == "commit" and state == "UNSET":
            states[assignment] = "COMMITTED"
        elif kind == "reveal" and state == "COMMITTED" and verdict == "accept":
            states[assignment] = "ACCEPTED"
        elif kind == "reveal" and state == "COMMITTED" and verdict == "reject":
            states[assignment] = "REJECTED"
        else:
            states[assignment] = "REJECTED_CONFLICT"
    for assignment, state in states.items():
        if state in {"UNSET", "COMMITTED"}:
            states[assignment] = "REJECTED_INCOMPLETE"
    closed = True
    return states

clean_events = []
for assignment in assignments:
    clean_events.extend((("commit", assignment, None), ("reveal", assignment, "accept")))
if set(replay(clean_events).values()) != {"ACCEPTED"}:
    raise SystemExit("clean terminal-map replay does not accept")
hidden_reject = clean_events + [("reveal", assignments[0], "reject")]
if replay(hidden_reject)[assignments[0]] != "REJECTED_CONFLICT":
    raise SystemExit("hidden reject sibling is not absorbing rejection")
reject_then_accept = [
    ("commit", assignments[0], None),
    ("reveal", assignments[0], "reject"),
    ("reveal", assignments[0], "accept"),
]
if replay(reject_then_accept)[assignments[0]] != "REJECTED":
    raise SystemExit("signed rejection is not absorbing")
duplicate_commit = [("commit", assignments[0], None), ("commit", assignments[0], None)]
if replay(duplicate_commit)[assignments[0]] != "REJECTED_CONFLICT":
    raise SystemExit("duplicate commitment does not force rejection")
if replay([])[assignments[0]] != "REJECTED_INCOMPLETE":
    raise SystemExit("missing terminal assignment does not force rejection")

hostile_review = json.loads(hostile_review_path.read_text(encoding="utf-8"))
provenance = hostile_review["review_provenance"]
if provenance["usable_as_external_freeze_evidence"] is not False:
    raise SystemExit("internal discovery review is mislabeled as freeze evidence")
if provenance["reviewer_identity_authenticated"] is not False:
    raise SystemExit("internal discovery reviewer identity is overclaimed")
if hostile_review["source_verdict"] != "FREEZE_NO":
    raise SystemExit("hostile review source verdict is not FREEZE_NO")
if hostile_review["finding_count"] != len(hostile_review["findings"]):
    raise SystemExit("hostile review finding count drifted")
if any(not row["status"].startswith("open_") for row in hostile_review["findings"]):
    raise SystemExit("hostile review prematurely closed a finding")
if hostile_review["claims"]["findings_closed"] is not False:
    raise SystemExit("hostile review overclaims finding closure")
PY

generate_fixture() {
        local output=$1 mutation=${2:-none}
        rm -rf "$output"
        mkdir -p "$output"
        python3 - "$VALIDATOR" "$output" "$mutation" <<'PY'
from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


validator_path = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
mutation = sys.argv[3]
spec = importlib.util.spec_from_file_location("archfreeze_v2", validator_path)
if spec is None or spec.loader is None:
    raise SystemExit("cannot import verifier")
af = importlib.util.module_from_spec(spec)
spec.loader.exec_module(af)

prefix = "linux-cap.archfreeze.fixture.v2"
signature_context = b"LINUX-CAP-ARCHFREEZE-FIXTURE-V2\0"
project = "linux-cap"
requirement = "RESIDENCY-DYN-001"
policy_id = "fixture-policy-v2"
campaign_id = "fixture-campaign"
candidate_id = "fixture-candidate"
cas_store_id = "fixture-cas-v2"


def raw_public(private: Ed25519PrivateKey) -> bytes:
    return private.public_key().public_bytes(
        serialization.Encoding.Raw,
        serialization.PublicFormat.Raw,
    )


def key_record(private: Ed25519PrivateKey) -> dict[str, object]:
    public = raw_public(private)
    return {
        "algorithm": "ed25519",
        "key_class": "fixture-test",
        "key_id": af.key_id_for(public),
        "public_key_b64": base64.b64encode(public).decode("ascii"),
    }


def envelope(
    payload_type: str,
    payload: dict[str, object],
    private_keys: list[Ed25519PrivateKey],
) -> bytes:
    payload_bytes = af.jcs_bytes(payload)
    return envelope_from_payload_bytes(payload_type, payload_bytes, private_keys)


def envelope_from_payload_bytes(
    payload_type: str,
    payload_bytes: bytes,
    private_keys: list[Ed25519PrivateKey],
) -> bytes:
    message = af.signed_message(signature_context, payload_type, payload_bytes)
    signatures = []
    for private in private_keys:
        record = key_record(private)
        signatures.append(
            {
                "algorithm": "ed25519",
                "key_id": record["key_id"],
                "signature_b64": base64.b64encode(private.sign(message)).decode("ascii"),
            }
        )
    signatures.sort(key=lambda row: row["key_id"])
    return af.jcs_bytes(
        {
            "payload_b64": base64.b64encode(payload_bytes).decode("ascii"),
            "payload_type": payload_type,
            "schema": f"{prefix}.signed-envelope",
            "signatures": signatures,
        }
    )


def alter_signature(data: bytes) -> bytes:
    value = json.loads(data)
    raw = bytearray(base64.b64decode(value["signatures"][0]["signature_b64"]))
    raw[0] ^= 1
    value["signatures"][0]["signature_b64"] = base64.b64encode(raw).decode("ascii")
    return af.jcs_bytes(value)


cas_objects: dict[str, bytes] = {}


def put_cas(data: bytes) -> str:
    digest = af.sha256_digest(data)
    cas_objects[digest] = data
    return digest


semantic_reject = mutation == "semantic_reject"
semantic_valid_literal = "1" if mutation == "semantic_valid_integer" else str(not semantic_reject)
semantic_validator = f'''#!/usr/bin/python3
import hashlib
import json
from pathlib import Path
import sys

PREFIX = {prefix!r}

def digest(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()

try:
    descriptor = json.loads(sys.stdin.buffer.read().decode("utf-8"))
    expected_keys = {{
        "artifact_manifest", "capsule_digest", "policy_digest", "schema",
        "sealed_root", "semantic_schema_digest"
    }}
    if set(descriptor) != expected_keys:
        raise ValueError("descriptor schema")
    if descriptor["schema"] != PREFIX + ".sealed-candidate-descriptor":
        raise ValueError("descriptor namespace")
    root = Path(descriptor["sealed_root"])
    for row in descriptor["artifact_manifest"]:
        data = (root / row["path"]).read_bytes()
        if len(data) != row["size"] or digest(data) != row["digest"]:
            raise ValueError("artifact mismatch")
    result = {{
        "capsule_digest": descriptor["capsule_digest"],
        "schema": PREFIX + ".semantic-validation-result",
        "semantic_schema_digest": descriptor["semantic_schema_digest"],
        "valid": {semantic_valid_literal},
    }}
    sys.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True,
                                separators=(",", ":")))
except Exception:
    raise SystemExit(2)
'''.encode("utf-8")
semantic_digest_for_policy = af.sha256_digest(semantic_validator)
assurance_verifier_digest = af.sha256_digest(validator_path.read_bytes())

contract_bytes = af.jcs_bytes(
    {
        "candidate": "fixture-only",
        "schema": f"{prefix}.architecture-contract-fixture",
        "status": "preformal-candidate",
    }
)
finding_catalog_bytes = af.jcs_bytes(
    {
        "catalog_id": "fixture-finding-catalog",
        "findings": [
            {
                "finding_id": "FIXTURE-001",
                "severity": "high",
                "title": "Fixture authority invariant",
            },
            {
                "finding_id": "FIXTURE-002",
                "severity": "medium",
                "title": "Fixture progress invariant",
            },
        ],
        "schema": f"{prefix}.finding-catalog",
    }
)
semantic_schema_bytes = af.jcs_bytes(
    {
        "required_status": "preformal-candidate",
        "schema": f"{prefix}.semantic-schema",
    }
)
artifact_data = {
    "architecture/contract.json": contract_bytes,
    "assurance/findings.json": finding_catalog_bytes,
    "assurance/schema.json": semantic_schema_bytes,
}
artifact_role = {
    "architecture/contract.json": "architecture_contract",
    "assurance/findings.json": "finding_catalog",
    "assurance/schema.json": "semantic_schema",
}
artifact_digest = {path: put_cas(data) for path, data in artifact_data.items()}

root_private = [Ed25519PrivateKey.generate() for _ in range(3)]
principal_specs = [
    ("fixture-assigner", "assignment_authority"),
    ("fixture-author", "candidate_author"),
    ("fixture-custodian", "custodian"),
    ("fixture-decider-a", "decision_authority"),
    ("fixture-decider-b", "decision_authority"),
    ("fixture-decider-c", "decision_authority"),
    ("fixture-reviewer-formal", "formal"),
    ("fixture-reviewer-integration", "integration"),
    ("fixture-reviewer-scalability", "scalability"),
    ("fixture-reviewer-security", "security"),
]
principal_private = {
    principal_id: Ed25519PrivateKey.generate()
    for principal_id, _ in principal_specs
}
if mutation == "root_campaign_key_overlap":
    root_private[0] = principal_private["fixture-author"]
principals = []
for principal_id, role in principal_specs:
    suffix = principal_id.removeprefix("fixture-")
    organization = "fixture-org-" + suffix
    person = "fixture-person-" + suffix
    independence_group = "fixture-group-" + suffix
    active_private = principal_private[principal_id]
    if mutation == "independence_overlap" and principal_id == "fixture-reviewer-security":
        organization = "fixture-org-author"
    if mutation == "reviewer_org_overlap" and principal_id == "fixture-reviewer-security":
        organization = "fixture-org-reviewer-formal"
    if mutation == "reviewer_person_overlap" and principal_id == "fixture-reviewer-security":
        person = "fixture-person-reviewer-formal"
    if mutation == "reviewer_group_overlap" and principal_id == "fixture-reviewer-security":
        independence_group = "fixture-group-reviewer-formal"
    if mutation == "reviewer_key_overlap" and principal_id == "fixture-reviewer-security":
        active_private = principal_private["fixture-reviewer-formal"]
    principals.append(
        {
            "active_keys": [key_record(active_private)],
            "eligible_roles": [role],
            "independence_group": independence_group,
            "organization_id": organization,
            "person_id": person,
            "principal_id": principal_id,
        }
    )
principals.sort(key=lambda row: row["principal_id"])

root = {
    "active_policy_keys": sorted(
        [key_record(private) for private in root_private],
        key=lambda row: row["key_id"],
    ),
    "phase": 1,
    "policy_signature_threshold": 2,
    "project": project,
    "revoked_key_ids": [],
    "root_epoch": 1,
    "schema": f"{prefix}.trust-root",
}
if mutation == "root_phase_boolean":
    root["phase"] = True
if mutation == "root_unknown":
    root["unknown"] = False
root_bytes = af.jcs_bytes(root)
if mutation == "root_duplicate_key":
    needle = b'"project":"linux-cap"'
    root_bytes = root_bytes.replace(needle, needle + b',"project":"linux-cap"', 1)
if mutation == "root_noncanonical":
    root_bytes = json.dumps(root, ensure_ascii=False, indent=2, sort_keys=True).encode("utf-8")
root_digest = af.sha256_digest(root_bytes)

required_manifest = [
    {
        "media_type": "application/json",
        "path": path,
        "role": artifact_role[path],
    }
    for path in sorted(artifact_data)
]
if mutation == "policy_path_traversal":
    required_manifest[0]["path"] = "../escape.json"

policy = {
    "assignment_authorities": ["fixture-assigner"],
    "campaign_id": campaign_id,
    "candidate_authors": ["fixture-author"],
    "candidate_digest_commitment": None,
    "candidate_profile": {
        "capsule_schema": f"{prefix}.candidate-capsule",
        "profile_id": "residency-dyn-preformal-v2",
    },
    "cas_store_id": cas_store_id,
    "claim_ceiling": {
        "accept_grants": af.FIXTURE_ACCEPT_GRANTS,
        "always_denied": af.FIXTURE_ALWAYS_DENIED,
    },
    "custodians": ["fixture-custodian"],
    "decision_authorities": [
        "fixture-decider-a",
        "fixture-decider-b",
        "fixture-decider-c",
    ],
    "decision_rules": {
        "aggregate_algorithm": "archfreeze-v2-deterministic-aggregate",
        "decision_authority_count": 3,
        "every_assignment_must_appear": True,
        "signature_threshold": 2,
    },
    "evidence_class": "fixture",
    "finding_catalog_digest": artifact_digest["assurance/findings.json"],
    "independence_rules": {
        "dimensions": af.DIMENSIONS,
        "disjoint_role_classes": af.ROLE_CLASSES,
        "enforced": True,
    },
    "max_artifact_bytes": 1048576,
    "max_capsule_bytes": 1048576,
    "max_manifest_entries": 16,
    "max_total_artifact_bytes": 4194304,
    "phase": 2,
    "policy_epoch": 1,
    "policy_id": policy_id,
    "policy_precedes_candidate": True,
    "principals": principals,
    "project": project,
    "required_manifest": required_manifest,
    "requirement": requirement,
    "review_rules": {
        "accepting_review_all_known_findings_closed": True,
        "accepting_review_no_freeze_blocking_limitation": True,
        "accepting_review_no_new_blocker": True,
        "blind_until_all_submitted": True,
        "complete_finding_coverage": True,
        "exactly_one_per_role": True,
        "other_review_digests_must_be_empty": True,
        "required_roles": af.REVIEW_ROLES,
    },
    "reviewer_principals": [
        "fixture-reviewer-formal",
        "fixture-reviewer-integration",
        "fixture-reviewer-scalability",
        "fixture-reviewer-security",
    ],
    "schema": f"{prefix}.campaign-policy",
    "semantic_schema_digest": artifact_digest["assurance/schema.json"],
    "semantic_validator_timeout_seconds": 10,
    "trusted_assurance_verifier_digest": assurance_verifier_digest,
    "trusted_semantic_validator_digest": semantic_digest_for_policy,
}
if mutation == "policy_unknown":
    policy["unknown"] = False
if mutation == "policy_candidate_commitment":
    policy["candidate_digest_commitment"] = "sha256:" + "0" * 64
if mutation == "policy_unsafe_claim":
    policy["claim_ceiling"]["accept_grants"] = ["architecture_frozen_pre_formal"]
if mutation == "policy_rule_integer":
    policy["independence_rules"]["enforced"] = 1

policy_signers = root_private[:1] if mutation == "policy_threshold" else root_private[:2]
unknown_root_private = Ed25519PrivateKey.generate()
if mutation == "policy_unknown_signer":
    policy_signers = [unknown_root_private, root_private[0]]
if mutation == "policy_non_nfc":
    for principal in policy["principals"]:
        if principal["principal_id"] == "fixture-reviewer-integration":
            principal["organization_id"] = "fixture-org-e\u0301"
    non_nfc_payload = json.dumps(
        policy, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    policy_bytes = envelope_from_payload_bytes(
        f"{prefix}.campaign-policy", non_nfc_payload, policy_signers
    )
else:
    policy_bytes = envelope(f"{prefix}.campaign-policy", policy, policy_signers)
if mutation == "policy_bad_signature":
    policy_bytes = alter_signature(policy_bytes)
if mutation == "policy_algorithm_substitution":
    policy_envelope = json.loads(policy_bytes)
    policy_envelope["signatures"][0]["algorithm"] = "ed448"
    policy_bytes = af.jcs_bytes(policy_envelope)
if mutation == "policy_envelope_unknown":
    policy_envelope = json.loads(policy_bytes)
    policy_envelope["unknown"] = False
    policy_bytes = af.jcs_bytes(policy_envelope)
if mutation == "policy_noncanonical":
    policy_bytes = json.dumps(
        json.loads(policy_bytes), ensure_ascii=False, indent=2, sort_keys=True
    ).encode("utf-8")
policy_digest = af.sha256_digest(policy_bytes)

manifest = []
for requirement_row in required_manifest:
    source_path = requirement_row["path"]
    if source_path == "../escape.json":
        data_path = "architecture/contract.json"
    else:
        data_path = source_path
    manifest.append(
        {
            "digest": artifact_digest[data_path],
            "media_type": requirement_row["media_type"],
            "path": source_path,
            "role": requirement_row["role"],
            "size": len(artifact_data[data_path]),
        }
    )
if mutation == "candidate_path_traversal":
    manifest[0]["path"] = "../candidate-escape.json"
if mutation == "manifest_duplicate_digest":
    manifest[0]["digest"] = manifest[1]["digest"]
    manifest[0]["size"] = manifest[1]["size"]

candidate = {
    "artifact_manifest": manifest,
    "campaign_id": campaign_id,
    "candidate_authors": ["fixture-author"],
    "candidate_id": candidate_id,
    "candidate_sequence": 1,
    "claims": {key: False for key in af.CANDIDATE_CLAIM_KEYS},
    "evidence_class": "fixture",
    "finding_catalog_digest": artifact_digest["assurance/findings.json"],
    "phase": 3,
    "policy_digest": policy_digest,
    "previous_capsule_digest": None,
    "project": project,
    "requirement": requirement,
    "schema": f"{prefix}.candidate-capsule",
    "state": "sealedCandidate",
}
if mutation == "candidate_unknown":
    candidate["unknown"] = False
if mutation == "candidate_claim":
    candidate["claims"]["architecture_frozen_pre_formal"] = True
if mutation == "candidate_phase":
    candidate["phase"] = 4
if mutation == "valid_sequence_two":
    predecessor = json.loads(af.jcs_bytes(candidate))
    predecessor_digest = put_cas(af.jcs_bytes(predecessor))
    candidate["candidate_sequence"] = 2
    candidate["previous_capsule_digest"] = predecessor_digest
if mutation == "candidate_sequence_wrong_predecessor":
    predecessor = json.loads(af.jcs_bytes(candidate))
    predecessor_digest = put_cas(af.jcs_bytes(predecessor))
    candidate["candidate_sequence"] = 3
    candidate["previous_capsule_digest"] = predecessor_digest
if mutation == "candidate_history_claim":
    predecessor = json.loads(af.jcs_bytes(candidate))
    predecessor["claims"]["architecture_frozen_pre_formal"] = True
    predecessor_digest = put_cas(af.jcs_bytes(predecessor))
    candidate["candidate_sequence"] = 2
    candidate["previous_capsule_digest"] = predecessor_digest
if mutation == "candidate_sequence_gap":
    candidate["candidate_sequence"] = 2
    candidate["previous_capsule_digest"] = "sha256:" + "3" * 64
candidate_bytes = af.jcs_bytes(candidate)
capsule_digest = put_cas(candidate_bytes)

seal = {
    "campaign_id": campaign_id,
    "candidate_authors": ["fixture-author"],
    "candidate_id": candidate_id,
    "capsule_digest": capsule_digest,
    "custodian_id": "fixture-custodian",
    "custody_sequence": candidate["candidate_sequence"],
    "manifest_count": len(manifest),
    "phase": 4,
    "policy_digest": policy_digest,
    "purpose": "architectureFreezeReview",
    "schema": f"{prefix}.candidate-seal",
    "storage_anchor": {
        "capsule_digest": capsule_digest,
        "read_only": mutation != "seal_anchor_writable",
        "scheme": "cas-sha256-v1",
        "store_id": cas_store_id,
    },
    "total_bytes": sum(row["size"] for row in manifest),
}
if mutation == "seal_phase":
    seal["phase"] = 5
if mutation == "seal_readonly_integer":
    seal["storage_anchor"]["read_only"] = 1
seal_signers = [principal_private["fixture-author"]]
if mutation != "seal_missing_custodian":
    seal_signers.append(principal_private["fixture-custodian"])
seal_bytes = envelope(f"{prefix}.candidate-seal", seal, seal_signers)
seal_digest = put_cas(seal_bytes)

reviewer_for_role = {
    "formal": "fixture-reviewer-formal",
    "integration": "fixture-reviewer-integration",
    "scalability": "fixture-reviewer-scalability",
    "security": "fixture-reviewer-security",
}
assignments = [
    {
        "assignment_id": "fixture-assignment-" + role,
        "reviewer_principal_id": reviewer_for_role[role],
        "role": role,
    }
    for role in af.REVIEW_ROLES
]
if mutation == "roster_duplicate_reviewer":
    assignments[-1]["reviewer_principal_id"] = "fixture-reviewer-formal"
roster = {
    "assignment_authority_id": "fixture-assigner",
    "assignments": assignments,
    "campaign_id": campaign_id,
    "candidate_id": candidate_id,
    "capsule_digest": capsule_digest,
    "disclosure_rule": "blindUntilAllSubmitted",
    "phase": 5,
    "policy_digest": policy_digest,
    "roster_id": "fixture-roster",
    "schema": f"{prefix}.review-roster",
    "seal_digest": "sha256:" + "0" * 64 if mutation == "roster_wrong_seal" else seal_digest,
}
if mutation == "roster_phase":
    roster["phase"] = 6
roster_signer = (
    "fixture-custodian" if mutation == "roster_wrong_signer" else "fixture-assigner"
)
roster_bytes = envelope(
    f"{prefix}.review-roster",
    roster,
    [principal_private[roster_signer]],
)
roster_digest = put_cas(roster_bytes)

review_records = []
for assignment in assignments:
    role = assignment["role"]
    reviewer = assignment["reviewer_principal_id"]
    dispositions = [
        {
            "disposition": "closed",
            "evidence_digests": [artifact_digest["architecture/contract.json"]],
            "finding_id": finding_id,
            "rationale": "Fixture evidence closes this mechanics-only finding.",
        }
        for finding_id in ("FIXTURE-001", "FIXTURE-002")
    ]
    limitations = []
    consulted = []
    review_roster_digest = roster_digest
    if role == "security" and mutation == "review_incomplete":
        dispositions = dispositions[:1]
    if role == "security" and mutation == "valid_rejection":
        dispositions[-1]["disposition"] = "open"
    if role == "security" and mutation == "review_blocking_limitation":
        limitations = [
            {
                "freeze_blocking": True,
                "limitation_id": "fixture-blocking-limitation",
                "statement": "A blocking limitation cannot accompany acceptance.",
            }
        ]
    if role == "security" and mutation == "review_consulted":
        consulted = [seal_digest]
    if role == "security" and mutation == "review_wrong_binding":
        review_roster_digest = "sha256:" + "1" * 64
    declared_verdict = "reject" if role == "security" and mutation == "valid_rejection" else "accept"
    review = {
        "assignment_id": assignment["assignment_id"],
        "campaign_id": campaign_id,
        "candidate_id": candidate_id,
        "capsule_digest": capsule_digest,
        "finding_catalog_digest": artifact_digest["assurance/findings.json"],
        "known_finding_dispositions": dispositions,
        "limitations": limitations,
        "new_findings": [],
        "other_review_digests_consulted": consulted,
        "phase": 6,
        "policy_digest": policy_digest,
        "reviewed_artifact_digests": sorted(artifact_digest.values()),
        "reviewer_principal_id": reviewer,
        "role": role,
        "roster_digest": review_roster_digest,
        "schema": f"{prefix}.signed-review",
        "seal_digest": seal_digest,
        "verdict": declared_verdict,
    }
    if role == "security" and mutation == "review_phase":
        review["phase"] = 7
    if role == "security" and mutation == "review_unknown":
        review["unknown"] = False
    signer_id = reviewer
    if role == "security" and mutation == "review_wrong_signer":
        signer_id = "fixture-reviewer-formal"
    review_bytes = envelope(
        f"{prefix}.signed-review",
        review,
        [principal_private[signer_id]],
    )
    if role == "security" and mutation == "review_bad_signature":
        review_bytes = alter_signature(review_bytes)
    review_digest = put_cas(review_bytes)
    review_records.append(
        {
            "assignment_id": assignment["assignment_id"],
            "digest": review_digest,
            "dispositions": dispositions,
            "limitations": limitations,
            "new_findings": [],
            "reviewer_principal_id": reviewer,
            "role": role,
            "verdict": declared_verdict,
        }
    )

finding_evaluation = []
for finding_id in ("FIXTURE-001", "FIXTURE-002"):
    role_dispositions = []
    for review_record in review_records:
        matches = [
            row["disposition"]
            for row in review_record["dispositions"]
            if row["finding_id"] == finding_id
        ]
        role_dispositions.append(
            {
                "disposition": matches[0] if matches else "closed",
                "role": review_record["role"],
            }
        )
    finding_evaluation.append(
        {
            "all_roles_closed": all(
                row["disposition"] == "closed" for row in role_dispositions
            ),
            "finding_id": finding_id,
            "role_dispositions": role_dispositions,
        }
    )
aggregate_decision = (
    "accept" if all(row["verdict"] == "accept" for row in review_records) else "reject"
)
aggregate_grants = af.FIXTURE_ACCEPT_GRANTS if aggregate_decision == "accept" else []
aggregate_denied = (
    af.FIXTURE_ALWAYS_DENIED
    if aggregate_decision == "accept"
    else sorted(set(af.FIXTURE_ACCEPT_GRANTS + af.FIXTURE_ALWAYS_DENIED))
)
aggregate = {
    "campaign_id": campaign_id,
    "candidate_id": candidate_id,
    "capsule_digest": capsule_digest,
    "claims_denied": aggregate_denied,
    "claims_granted": aggregate_grants,
    "decision": aggregate_decision,
    "evidence_class": "fixture",
    "finding_evaluation": finding_evaluation,
    "independence_evaluation": {
        "reviewer_independence_groups_distinct": True,
        "reviewer_keys_distinct": True,
        "reviewer_organizations_distinct": True,
        "reviewer_persons_distinct": True,
        "role_classes_disjoint": True,
    },
    "limitations": [],
    "new_findings": [],
    "ordered_reviews": [
        {
            "assignment_id": row["assignment_id"],
            "computed_verdict": row["verdict"],
            "review_digest": row["digest"],
            "reviewer_principal_id": row["reviewer_principal_id"],
            "role": row["role"],
        }
        for row in review_records
    ],
    "phase": 7,
    "policy_digest": policy_digest,
    "roster_digest": roster_digest,
    "schema": f"{prefix}.aggregate-decision",
    "seal_digest": seal_digest,
}
if mutation == "aggregate_tamper":
    aggregate["finding_evaluation"][0]["all_roles_closed"] = False
if mutation == "aggregate_bool_integer":
    aggregate["finding_evaluation"][0]["all_roles_closed"] = 1
if mutation == "aggregate_unknown":
    aggregate["unknown"] = False
aggregate_bytes = af.jcs_bytes(aggregate)
aggregate_digest = put_cas(aggregate_bytes)

decision = {
    "aggregate_decision_digest": aggregate_digest,
    "campaign_id": campaign_id,
    "candidate_id": candidate_id,
    "claims_denied": aggregate["claims_denied"],
    "claims_granted": aggregate["claims_granted"],
    "decision": aggregate["decision"],
    "decision_authority_ids": [
        "fixture-decider-a",
        "fixture-decider-b",
        "fixture-decider-c",
    ],
    "evidence_class": "fixture",
    "phase": 8,
    "policy_digest": policy_digest,
    "schema": f"{prefix}.decision-authorization",
}
if mutation == "decision_phase":
    decision["phase"] = 7
if mutation == "decision_claim_escalation":
    decision["claims_granted"] = ["architecture_frozen"]
decision_signers = [
    principal_private["fixture-decider-a"],
    principal_private["fixture-decider-b"],
]
if mutation == "decision_one_signer":
    decision_signers = decision_signers[:1]
if mutation == "decision_wrong_signer":
    decision_signers = [
        principal_private["fixture-decider-a"],
        principal_private["fixture-reviewer-security"],
    ]
decision_bytes = envelope(
    f"{prefix}.decision-authorization",
    decision,
    decision_signers,
)
if mutation == "decision_bad_signature":
    decision_bytes = alter_signature(decision_bytes)
decision_digest = put_cas(decision_bytes)

freeze_record = {
    "aggregate_decision_digest": aggregate_digest,
    "architecture_frozen": False,
    "architecture_frozen_pre_formal": False,
    "campaign_decision": aggregate_decision,
    "campaign_id": campaign_id,
    "candidate_id": candidate_id,
    "capsule_digest": capsule_digest,
    "claims_denied": aggregate["claims_denied"],
    "claims_granted": aggregate["claims_granted"],
    "decision_envelope_digest": decision_digest,
    "derivation_algorithm": "archfreeze-v2",
    "derived_status": (
        "mechanicsAcceptValidOnly"
        if aggregate_decision == "accept"
        else "mechanicsRejectValidOnly"
    ),
    "evidence_class": "fixture",
    "phase": 9,
    "policy_envelope_digest": policy_digest,
    "project": project,
    "requirement": requirement,
    "review_envelope_digests": [
        {"digest": row["digest"], "role": row["role"]}
        for row in review_records
    ],
    "roster_envelope_digest": roster_digest,
    "schema": f"{prefix}.freeze-record",
    "seal_envelope_digest": seal_digest,
    "tla_authorized": False,
    "trust_root_digest": root_digest,
}
if mutation == "freeze_preformal_true":
    freeze_record["architecture_frozen_pre_formal"] = True
if mutation == "freeze_architecture_true":
    freeze_record["architecture_frozen"] = True
if mutation == "freeze_bool_integer":
    freeze_record["architecture_frozen"] = 0
if mutation == "freeze_digest_mismatch":
    freeze_record["roster_envelope_digest"] = "sha256:" + "2" * 64
if mutation == "freeze_unknown":
    freeze_record["unknown"] = False
if mutation == "freeze_phase":
    freeze_record["phase"] = 8

cas_sha = output / "cas" / "sha256"
cas_sha.mkdir(parents=True)
for digest, data in cas_objects.items():
    path = cas_sha / digest.removeprefix("sha256:")
    path.write_bytes(data)
    path.chmod(0o444)
(output / "trust-root.json").write_bytes(root_bytes)
(output / "policy-envelope.json").write_bytes(policy_bytes)
(output / "freeze-record.json").write_bytes(af.jcs_bytes(freeze_record))
(output / "semantic-validator.py").write_bytes(semantic_validator)
(output / "semantic-validator.py").chmod(0o555)

cas_sha.chmod(0o555)
(output / "cas").chmod(0o555)
if mutation == "cas_writable":
    (output / "cas").chmod(0o755)
if mutation == "cas_blob_writable":
    (cas_sha / capsule_digest.removeprefix("sha256:")).chmod(0o644)
if mutation == "cas_digest_mismatch":
    target = cas_sha / capsule_digest.removeprefix("sha256:")
    target.chmod(0o644)
    target.write_bytes(target.read_bytes() + b"x")
    target.chmod(0o444)
if mutation == "cas_symlink":
    target = cas_sha / capsule_digest.removeprefix("sha256:")
    replacement = artifact_digest["architecture/contract.json"].removeprefix("sha256:")
    cas_sha.chmod(0o755)
    target.unlink()
    target.symlink_to(replacement)
    cas_sha.chmod(0o555)
if mutation == "semantic_substitution":
    tool = output / "semantic-validator.py"
    tool.chmod(0o755)
    tool.write_bytes(tool.read_bytes() + b"\n# substituted\n")
    tool.chmod(0o555)

semantic_digest_for_cli = af.sha256_digest((output / "semantic-validator.py").read_bytes())
(output / "pins.env").write_text(
    "EXPECTED_TRUST_ROOT_DIGEST='" + root_digest + "'\n"
    "EXPECTED_POLICY_DIGEST='" + policy_digest + "'\n"
    "EXPECTED_SEMANTIC_VALIDATOR_DIGEST='" + semantic_digest_for_cli + "'\n",
    encoding="ascii",
)
PY
}

run_verifier() {
        local mode=$1 fixture=$2
        # shellcheck disable=SC1090
        source "$fixture/pins.env"
        "$VALIDATOR" "$mode" \
                --trust-root "$fixture/trust-root.json" \
                --expected-trust-root-digest "$EXPECTED_TRUST_ROOT_DIGEST" \
                --expected-trust-root-epoch 1 \
                --policy-envelope "$fixture/policy-envelope.json" \
                --expected-policy-digest "$EXPECTED_POLICY_DIGEST" \
                --expected-policy-id fixture-policy-v2 \
                --expected-policy-epoch 1 \
                --expected-project linux-cap \
                --expected-requirement RESIDENCY-DYN-001 \
                --cas-root "$fixture/cas" \
                --expected-cas-store-id fixture-cas-v2 \
                --freeze-record "$fixture/freeze-record.json" \
                --semantic-validator "$fixture/semantic-validator.py" \
                --expected-semantic-validator-digest \
                        "$EXPECTED_SEMANTIC_VALIDATOR_DIGEST"
}

BASE="$TMP/base"
generate_fixture "$BASE"
MECHANICS_PROFILE_DIGEST=$(python3 - "$VALIDATOR" <<'PY'
import importlib.util
from pathlib import Path
import sys

path = Path(sys.argv[1]).resolve()
spec = importlib.util.spec_from_file_location("archfreeze_fixture_profile", path)
if spec is None or spec.loader is None:
    raise SystemExit("cannot import fixture verifier")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.fixture_mechanics_profile_digest())
PY
)
EXPECTED_ACCEPT='{"architecture_frozen":false,"campaign_decision":"accept","evidence_class":"fixture","evidence_valid":true,"freeze_authorized":false,"mechanics_profile_digest":"'"$MECHANICS_PROFILE_DIGEST"'","tla_authorized":false}'
EXPECTED_REJECT='{"architecture_frozen":false,"campaign_decision":"reject","evidence_class":"fixture","evidence_valid":true,"freeze_authorized":false,"mechanics_profile_digest":"'"$MECHANICS_PROFILE_DIGEST"'","tla_authorized":false}'
ACTUAL=$(run_verifier verify-fixture "$BASE")
if [[ $ACTUAL != "$EXPECTED_ACCEPT" ]]; then
        printf 'FAIL: fixture success result is not the exact non-freezing result\n' >&2
        printf 'expected: %s\nactual:   %s\n' "$EXPECTED_ACCEPT" "$ACTUAL" >&2
        exit 1
fi

REJECTED="$TMP/valid-rejection"
generate_fixture "$REJECTED" valid_rejection
REJECTED_ACTUAL=$(run_verifier verify-fixture "$REJECTED")
if [[ $REJECTED_ACTUAL != "$EXPECTED_REJECT" ]]; then
        printf 'FAIL: valid signed rejection was not distinguished without authorization\n' >&2
        exit 1
fi

SEQUENCE_TWO="$TMP/valid-sequence-two"
generate_fixture "$SEQUENCE_TWO" valid_sequence_two
SEQUENCE_TWO_ACTUAL=$(run_verifier verify-fixture "$SEQUENCE_TWO")
if [[ $SEQUENCE_TWO_ACTUAL != "$EXPECTED_ACCEPT" ]]; then
        printf 'FAIL: valid monotonic two-capsule chain was rejected\n' >&2
        exit 1
fi

if run_verifier verify-real "$BASE" >/dev/null 2>&1; then
        printf 'FAIL: fixture verifier unexpectedly exposes verify-real\n' >&2
        exit 1
fi

REAL_STDERR="$TMP/real-stub.stderr"
set +e
"$REAL_STUB" verify-real --trust-root /does/not/exist --candidate /does/not/exist \
        >/dev/null 2>"$REAL_STDERR"
REAL_STATUS=$?
set -e
if [[ $REAL_STATUS -ne 78 ]]; then
        printf 'FAIL: real stub did not return EX_CONFIG-style fail-closed status 78\n' >&2
        exit 1
fi
EXPECTED_REAL_REJECTION='AFV2_REAL_UNIMPLEMENTED: real architecture-freeze assurance v2.1 verification is unavailable; no evidence was parsed and no claim was authorized'
if [[ $(<"$REAL_STDERR") != "$EXPECTED_REAL_REJECTION" ]]; then
        printf 'FAIL: real stub rejection is not exact and stable\n' >&2
        exit 1
fi

MUTATIONS=(
        root_unknown
        root_duplicate_key
        root_noncanonical
        root_phase_boolean
        root_campaign_key_overlap
        policy_unknown
        policy_envelope_unknown
        policy_noncanonical
        policy_threshold
        policy_bad_signature
        policy_algorithm_substitution
        policy_unknown_signer
        policy_candidate_commitment
        policy_unsafe_claim
        policy_rule_integer
        policy_non_nfc
        independence_overlap
        reviewer_org_overlap
        reviewer_person_overlap
        reviewer_group_overlap
        reviewer_key_overlap
        policy_path_traversal
        candidate_unknown
        candidate_claim
        candidate_phase
        candidate_sequence_gap
        candidate_sequence_wrong_predecessor
        candidate_history_claim
        candidate_path_traversal
        manifest_duplicate_digest
        cas_writable
        cas_blob_writable
        cas_digest_mismatch
        cas_symlink
        seal_missing_custodian
        seal_anchor_writable
        seal_readonly_integer
        seal_phase
        roster_duplicate_reviewer
        roster_wrong_seal
        roster_wrong_signer
        roster_phase
        review_consulted
        review_incomplete
        review_blocking_limitation
        review_wrong_binding
        review_unknown
        review_wrong_signer
        review_bad_signature
        review_phase
        aggregate_tamper
        aggregate_bool_integer
        aggregate_unknown
        decision_one_signer
        decision_wrong_signer
        decision_claim_escalation
        decision_bad_signature
        decision_phase
        freeze_preformal_true
        freeze_architecture_true
        freeze_bool_integer
        freeze_digest_mismatch
        freeze_unknown
        freeze_phase
        semantic_reject
        semantic_valid_integer
        semantic_substitution
)

expected_failure() {
        case $1 in
                root_duplicate_key)
                        printf '%s|%s\n' AFV2F_CANONICAL_JSON 'duplicate JSON key'
                        ;;
                root_campaign_key_overlap)
                        printf '%s|%s\n' AFV2F_POLICY 'CampaignPolicy'
                        ;;
                root_*)
                        printf '%s|%s\n' AFV2F_TRUST_ROOT 'TrustRoot'
                        ;;
                policy_*|independence_overlap|reviewer_org_overlap|reviewer_person_overlap|reviewer_group_overlap|reviewer_key_overlap)
                        printf '%s|%s\n' AFV2F_POLICY 'CampaignPolicy'
                        ;;
                candidate_sequence_gap)
                        printf '%s|%s\n' AFV2F_CAS 'CAS object unavailable'
                        ;;
                candidate_*|manifest_duplicate_digest)
                        printf '%s|%s\n' AFV2F_CAPSULE 'CandidateCapsule'
                        ;;
                cas_*)
                        printf '%s|%s\n' AFV2F_CAS 'CAS'
                        ;;
                seal_anchor_writable|seal_readonly_integer)
                        printf '%s|%s\n' AFV2F_CAS 'storage anchor is not the exact policy-bound read-only CAS'
                        ;;
                seal_*)
                        printf '%s|%s\n' AFV2F_SEAL 'CandidateSeal'
                        ;;
                roster_*)
                        printf '%s|%s\n' AFV2F_ROSTER 'ReviewRoster'
                        ;;
                review_*)
                        printf '%s|%s\n' AFV2F_REVIEW 'SignedReview'
                        ;;
                aggregate_*)
                        printf '%s|%s\n' AFV2F_AGGREGATE 'AggregateDecision'
                        ;;
                decision_*)
                        printf '%s|%s\n' AFV2F_DECISION 'DecisionAuthorization'
                        ;;
                freeze_digest_mismatch)
                        printf '%s|%s\n' AFV2F_CAS 'ReviewRoster envelope: CAS object unavailable'
                        ;;
                freeze_*)
                        printf '%s|%s\n' AFV2F_FREEZE_RECORD 'FreezeRecord'
                        ;;
                semantic_*)
                        printf '%s|%s\n' AFV2F_SEMANTIC 'semantic validator'
                        ;;
                *)
                        printf 'FAIL: mutation has no intended rejection contract: %s\n' "$1" >&2
                        return 1
                        ;;
        esac
}

count=0
for mutation in "${MUTATIONS[@]}"; do
        fixture="$TMP/mutation-$mutation"
        generate_fixture "$fixture" "$mutation"
        stderr_file="$TMP/mutation-$mutation.stderr"
        set +e
        run_verifier verify-fixture "$fixture" >/dev/null 2>"$stderr_file"
        status=$?
        set -e
        if [[ $status -eq 0 ]]; then
                printf 'FAIL: hostile mutation accepted: %s\n' "$mutation" >&2
                exit 1
        fi
        expectation=$(expected_failure "$mutation")
        expected_code=${expectation%%|*}
        expected_reason=${expectation#*|}
        if ! grep -Fq "REJECT[$expected_code]" "$stderr_file"; then
                printf 'FAIL: mutation rejected by unintended control: %s\n' "$mutation" >&2
                printf 'expected code: %s\nactual: %s\n' \
                        "$expected_code" "$(<"$stderr_file")" >&2
                exit 1
        fi
        if ! grep -Fq "$expected_reason" "$stderr_file"; then
                printf 'FAIL: mutation rejection reason drifted: %s\n' "$mutation" >&2
                printf 'expected marker: %s\nactual: %s\n' \
                        "$expected_reason" "$(<"$stderr_file")" >&2
                exit 1
        fi
        count=$((count + 1))
done

printf 'architecture-freeze-v2 fixture mechanics: PASS\n'
printf 'architecture-freeze-v2 hostile mutations rejected: %d\n' "$count"
printf 'architecture_frozen=false (fixture evidence only)\n'
