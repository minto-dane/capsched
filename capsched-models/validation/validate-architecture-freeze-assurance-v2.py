#!/usr/bin/env python3
"""Fixture-only verifier for architecture-freeze assurance protocol v2.

This verifier can establish the mechanics and byte/signature bindings of a
campaign.  It cannot establish that identity metadata is truthful, that a
human review was competent, or that independent principals did not collude.
Fixture evidence is cryptographically separated and can never produce an
architecture-freeze or TLA-authorization claim.  Real verification is a
separate, unconditionally rejecting CLI until protocol v2.1 is implemented and
independently reviewed.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
from json.encoder import encode_basestring
import os
from pathlib import Path, PurePosixPath
import re
import resource
import signal
import stat
import subprocess
import sys
import tempfile
import unicodedata
from typing import Any, Iterable


MAX_SAFE_INTEGER = (1 << 53) - 1
MAX_EXTERNAL_JSON_BYTES = 4 * 1024 * 1024
MAX_TOOL_BYTES = 16 * 1024 * 1024
MAX_ARTIFACT_BYTES_HARD = 64 * 1024 * 1024
MAX_TOTAL_ARTIFACT_BYTES_HARD = 512 * 1024 * 1024
MAX_MANIFEST_ENTRIES_HARD = 4096
MAX_CANDIDATE_HISTORY = 64
MAX_SEMANTIC_OUTPUT_BYTES = 64 * 1024
READ_CHUNK = 1024 * 1024

DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}\Z")
KEY_ID_RE = re.compile(r"ed25519:[0-9a-f]{64}\Z")
ID_RE = re.compile(r"[a-z][a-z0-9._-]{1,127}\Z")
REQUIREMENT_RE = re.compile(r"[A-Z][A-Z0-9._-]{1,127}\Z")
FINDING_ID_RE = re.compile(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+\Z")
ROLE_RE = re.compile(r"[a-z][a-z0-9._-]{1,63}\Z")
MEDIA_RE = re.compile(r"[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*\Z")

REVIEW_ROLES = ["formal", "integration", "scalability", "security"]
ROLE_CLASSES = [
    "assignment_authority",
    "candidate_author",
    "custodian",
    "decision_authority",
    "reviewer",
]
DIMENSIONS = ["independence_group", "key", "organization", "person"]
FIXTURE_ACCEPT_GRANTS = ["mechanics_valid_only"]
FIXTURE_ALWAYS_DENIED = [
    "architecture_frozen",
    "architecture_frozen_pre_formal",
    "implementation_complete",
    "model_checked",
    "protection_evidenced",
    "tla_authorized",
    "tla_proved",
]
FIXTURE_PREFIX = "linux-cap.archfreeze.fixture.v2"
FIXTURE_SIGNATURE_CONTEXT = b"LINUX-CAP-ARCHFREEZE-FIXTURE-V2\0"
FIXTURE_MECHANICS_PROFILE = {
    "campaign_decisions": ["accept", "reject"],
    "claim_grant_ceiling": FIXTURE_ACCEPT_GRANTS,
    "claim_hard_denials": FIXTURE_ALWAYS_DENIED,
    "evidence_class": "fixture",
    "freeze_authorized": False,
    "prefix": FIXTURE_PREFIX,
    "profile": "fixture-local-signature-and-byte-binding-mechanics-v2",
    "real_assurance": False,
    "schema": f"{FIXTURE_PREFIX}.mechanics-profile",
    "semantic_execution": "fixture_only_bounded_host_process_not_hermetic",
    "tla_authorized": False,
}
CANDIDATE_CLAIM_KEYS = [
    "architecture_frozen",
    "architecture_frozen_pre_formal",
    "implementation_complete",
    "model_checked",
    "protection_evidenced",
    "tla_authorized",
    "tla_proved",
]
CANDIDATE_CAPSULE_KEYS = [
    "artifact_manifest",
    "campaign_id",
    "candidate_authors",
    "candidate_id",
    "candidate_sequence",
    "claims",
    "evidence_class",
    "finding_catalog_digest",
    "phase",
    "policy_digest",
    "previous_capsule_digest",
    "project",
    "requirement",
    "schema",
    "state",
]


class VerificationError(Exception):
    """A fail-closed protocol validation error."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def semantic_fixture_child_limits() -> None:
    """Bound fixture-only validator execution before exec on Linux."""
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE,
                       (MAX_SEMANTIC_OUTPUT_BYTES, MAX_SEMANTIC_OUTPUT_BYTES))
    resource.setrlimit(resource.RLIMIT_NOFILE, (32, 32))
    resource.setrlimit(resource.RLIMIT_NPROC, (16, 16))
    address_space = 512 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_AS, (address_space, address_space))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 31))


ERROR_CODE_MARKERS = [
    ("CAS", "AFV2F_CAS"),
    ("TrustRoot", "AFV2F_TRUST_ROOT"),
    ("CampaignPolicy", "AFV2F_POLICY"),
    ("CandidateCapsule", "AFV2F_CAPSULE"),
    ("CandidateSeal", "AFV2F_SEAL"),
    ("ReviewRoster", "AFV2F_ROSTER"),
    ("SignedReview", "AFV2F_REVIEW"),
    ("AggregateDecision", "AFV2F_AGGREGATE"),
    ("DecisionAuthorization", "AFV2F_DECISION"),
    ("FreezeRecord", "AFV2F_FREEZE_RECORD"),
    ("Semantic validator", "AFV2F_SEMANTIC"),
    ("semantic validator", "AFV2F_SEMANTIC"),
    ("CLI --", "AFV2F_CLI_PIN"),
    ("JSON", "AFV2F_CANONICAL_JSON"),
    ("JCS", "AFV2F_CANONICAL_JSON"),
]


def error_code_for(message: str) -> str:
    for marker, code in ERROR_CODE_MARKERS:
        if marker in message:
            return code
    return "AFV2F_INVALID_EVIDENCE"


def fail(message: str, *, code: str | None = None) -> None:
    raise VerificationError(code or error_code_for(message), message)


def sha256_digest(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def require_digest(value: Any, context: str) -> str:
    if not isinstance(value, str) or DIGEST_RE.fullmatch(value) is None:
        fail(f"{context}: expected sha256 digest")
    return value


def require_key_id(value: Any, context: str) -> str:
    if not isinstance(value, str) or KEY_ID_RE.fullmatch(value) is None:
        fail(f"{context}: expected Ed25519 key ID")
    return value


def require_id(value: Any, context: str) -> str:
    if not isinstance(value, str) or ID_RE.fullmatch(value) is None:
        fail(f"{context}: invalid identifier")
    return value


def require_role(value: Any, context: str) -> str:
    if not isinstance(value, str) or ROLE_RE.fullmatch(value) is None:
        fail(f"{context}: invalid role")
    return value


def require_requirement(value: Any, context: str) -> str:
    if not isinstance(value, str) or REQUIREMENT_RE.fullmatch(value) is None:
        fail(f"{context}: invalid requirement identifier")
    return value


def require_finding_id(value: Any, context: str) -> str:
    if not isinstance(value, str) or FINDING_ID_RE.fullmatch(value) is None:
        fail(f"{context}: invalid finding identifier")
    return value


def require_text(value: Any, context: str, *, maximum: int = 4096) -> str:
    if not isinstance(value, str) or not value or len(value) > maximum:
        fail(f"{context}: expected bounded non-empty string")
    if unicodedata.normalize("NFC", value) != value:
        fail(f"{context}: string is not NFC")
    if any(0xD800 <= ord(char) <= 0xDFFF for char in value):
        fail(f"{context}: surrogate code point is forbidden")
    return value


def require_bool(value: Any, context: str) -> bool:
    if type(value) is not bool:
        fail(f"{context}: expected boolean")
    return value


def require_int(
    value: Any,
    context: str,
    *,
    minimum: int = 0,
    maximum: int = MAX_SAFE_INTEGER,
) -> int:
    if type(value) is not int or value < minimum or value > maximum:
        fail(f"{context}: expected bounded integer")
    return value


def require_object(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{context}: expected object")
    return value


def require_array(value: Any, context: str) -> list[Any]:
    if not isinstance(value, list):
        fail(f"{context}: expected array")
    return value


def exact_keys(value: dict[str, Any], expected: Iterable[str], context: str) -> None:
    expected_set = set(expected)
    actual_set = set(value)
    missing = sorted(expected_set - actual_set)
    unknown = sorted(actual_set - expected_set)
    if missing or unknown:
        fail(f"{context}: key mismatch; missing={missing}, unknown={unknown}")


def strict_equal(left: Any, right: Any) -> bool:
    """Compare JSON values without Python's bool/int equality aliasing."""
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return set(left) == set(right) and all(
            strict_equal(left[key], right[key]) for key in left
        )
    if isinstance(left, list):
        return len(left) == len(right) and all(
            strict_equal(a, b) for a, b in zip(left, right)
        )
    return left == right


def require_sorted_unique_strings(
    value: Any,
    context: str,
    *,
    validator=require_text,
) -> list[str]:
    rows = require_array(value, context)
    result = [validator(row, f"{context}[{index}]") for index, row in enumerate(rows)]
    if result != sorted(result) or len(result) != len(set(result)):
        fail(f"{context}: values must be sorted and unique")
    return result


def _reject_float(_: str) -> Any:
    fail("JSON floating-point values are forbidden")


def _reject_constant(_: str) -> Any:
    fail("non-finite JSON values are forbidden")


def _parse_integer(raw: str) -> int:
    value = int(raw)
    if abs(value) > MAX_SAFE_INTEGER:
        fail("JSON integer exceeds the interoperable JCS range")
    return value


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _validate_json_strings(value: Any, context: str = "JSON") -> None:
    if isinstance(value, str):
        require_text(value, context, maximum=MAX_EXTERNAL_JSON_BYTES * 2)
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            _validate_json_strings(item, f"{context}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            require_text(key, f"{context}.key", maximum=1024)
            _validate_json_strings(item, f"{context}.{key}")


def _jcs_key(key: str) -> bytes:
    return key.encode("utf-16be")


def jcs_bytes(value: Any) -> bytes:
    """Serialize the integer-only I-JSON subset using RFC 8785 ordering."""

    def encode(item: Any) -> str:
        if item is None:
            return "null"
        if item is True:
            return "true"
        if item is False:
            return "false"
        if type(item) is int:
            if abs(item) > MAX_SAFE_INTEGER:
                fail("integer exceeds the interoperable JCS range")
            return str(item)
        if isinstance(item, str):
            require_text(item, "JCS string", maximum=1 << 20)
            return encode_basestring(item)
        if isinstance(item, list):
            return "[" + ",".join(encode(child) for child in item) + "]"
        if isinstance(item, dict):
            for key in item:
                if not isinstance(key, str):
                    fail("JCS object key is not a string")
            return "{" + ",".join(
                encode_basestring(key) + ":" + encode(item[key])
                for key in sorted(item, key=_jcs_key)
            ) + "}"
        fail(f"unsupported JCS value type: {type(item).__name__}")

    return encode(value).encode("utf-8")


def fixture_mechanics_profile_digest() -> str:
    return sha256_digest(jcs_bytes(FIXTURE_MECHANICS_PROFILE))


def parse_canonical_json(data: bytes, context: str) -> Any:
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        fail(f"{context}: invalid UTF-8: {exc}")
    if text.startswith("\ufeff"):
        fail(f"{context}: UTF-8 BOM is forbidden")
    if unicodedata.normalize("NFC", text) != text:
        fail(f"{context}: input text is not NFC")
    try:
        value = json.loads(
            text,
            object_pairs_hook=_unique_object,
            parse_float=_reject_float,
            parse_int=_parse_integer,
            parse_constant=_reject_constant,
        )
    except VerificationError:
        raise
    except (json.JSONDecodeError, ValueError) as exc:
        fail(f"{context}: invalid JSON: {exc}")
    _validate_json_strings(value, context)
    if jcs_bytes(value) != data:
        fail(f"{context}: bytes are not canonical RFC 8785 JCS")
    return value


def decode_base64(value: Any, context: str, expected_length: int | None = None) -> bytes:
    if not isinstance(value, str) or len(value) > (MAX_EXTERNAL_JSON_BYTES * 2):
        fail(f"{context}: invalid base64 field")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        fail(f"{context}: invalid base64: {exc}")
    if base64.b64encode(decoded).decode("ascii") != value:
        fail(f"{context}: base64 is not canonical RFC 4648 form")
    if expected_length is not None and len(decoded) != expected_length:
        fail(f"{context}: decoded length mismatch")
    return decoded


def read_regular_once(path: Path, limit: int, context: str) -> bytes:
    try:
        before_path = path.lstat()
    except OSError as exc:
        fail(f"{context}: cannot stat {path}: {exc}")
    if not stat.S_ISREG(before_path.st_mode) or stat.S_ISLNK(before_path.st_mode):
        fail(f"{context}: path must be a non-symlink regular file")
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        fail(f"{context}: cannot open {path}: {exc}")
    try:
        before = os.fstat(fd)
        if not stat.S_ISREG(before.st_mode):
            fail(f"{context}: opened object is not regular")
        if before.st_size > limit:
            fail(f"{context}: input exceeds {limit} bytes")
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(fd, min(READ_CHUNK, limit + 1 - total))
            if not chunk:
                break
            chunks.append(chunk)
            total += len(chunk)
            if total > limit:
                fail(f"{context}: input exceeds {limit} bytes")
        after = os.fstat(fd)
        identity_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
        identity_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
        if identity_before != identity_after:
            fail(f"{context}: file changed while being read")
        return b"".join(chunks)
    finally:
        os.close(fd)


def require_read_only_mode(mode: int, context: str) -> None:
    if mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
        fail(f"{context}: CAS object or directory is writable")


class CasReader:
    """Read sha256-addressed regular files once through pinned directory FDs."""

    def __init__(self, root: Path) -> None:
        self.root_path = root
        try:
            root_lstat = root.lstat()
        except OSError as exc:
            fail(f"CAS: cannot stat root: {exc}")
        if not stat.S_ISDIR(root_lstat.st_mode) or stat.S_ISLNK(root_lstat.st_mode):
            fail("CAS: root must be a non-symlink directory")
        require_read_only_mode(root_lstat.st_mode, "CAS root")
        flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            self.root_fd = os.open(root, flags)
            self.sha_fd = os.open("sha256", flags, dir_fd=self.root_fd)
        except OSError as exc:
            if hasattr(self, "root_fd"):
                os.close(self.root_fd)
            fail(f"CAS: cannot open content-addressed directories: {exc}")
        require_read_only_mode(os.fstat(self.root_fd).st_mode, "CAS root")
        require_read_only_mode(os.fstat(self.sha_fd).st_mode, "CAS sha256 directory")
        self.cache: dict[str, bytes] = {}

    def close(self) -> None:
        os.close(self.sha_fd)
        os.close(self.root_fd)

    def read(self, digest: str, limit: int, context: str) -> bytes:
        require_digest(digest, context)
        if digest in self.cache:
            data = self.cache[digest]
            if len(data) > limit:
                fail(f"{context}: cached object exceeds limit")
            return data
        name = digest.removeprefix("sha256:")
        flags = os.O_RDONLY
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            fd = os.open(name, flags, dir_fd=self.sha_fd)
        except OSError as exc:
            fail(f"{context}: CAS object unavailable: {exc}")
        try:
            before = os.fstat(fd)
            if not stat.S_ISREG(before.st_mode):
                fail(f"{context}: CAS object is not regular")
            require_read_only_mode(before.st_mode, context)
            if before.st_size > limit:
                fail(f"{context}: CAS object exceeds {limit} bytes")
            chunks: list[bytes] = []
            total = 0
            while True:
                chunk = os.read(fd, min(READ_CHUNK, limit + 1 - total))
                if not chunk:
                    break
                chunks.append(chunk)
                total += len(chunk)
                if total > limit:
                    fail(f"{context}: CAS object exceeds {limit} bytes")
            after = os.fstat(fd)
            identity_before = (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns)
            identity_after = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
            if identity_before != identity_after:
                fail(f"{context}: CAS object changed while being read")
            data = b"".join(chunks)
            if sha256_digest(data) != digest:
                fail(f"{context}: CAS name/content digest mismatch")
            self.cache[digest] = data
            return data
        finally:
            os.close(fd)


class Ed25519Verifier:
    def __init__(self) -> None:
        self.name: str
        self._invalid_signature: type[BaseException] | tuple[type[BaseException], ...]
        try:
            from cryptography.exceptions import InvalidSignature
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

            self.name = "cryptography.Ed25519PublicKey"
            self._public_key = Ed25519PublicKey.from_public_bytes
            self._invalid_signature = InvalidSignature
            self._nacl = False
            return
        except ImportError:
            pass
        try:
            from nacl.exceptions import BadSignatureError
            from nacl.signing import VerifyKey

            self.name = "PyNaCl.VerifyKey"
            self._public_key = VerifyKey
            self._invalid_signature = BadSignatureError
            self._nacl = True
            return
        except ImportError:
            fail(
                "no Ed25519 verification implementation is available; install "
                "cryptography or PyNaCl"
            )

    def verify(self, public_key: bytes, signature: bytes, message: bytes, context: str) -> None:
        try:
            key = self._public_key(public_key)
            if self._nacl:
                key.verify(message, signature)
            else:
                key.verify(signature, message)
        except self._invalid_signature:
            fail(f"{context}: invalid Ed25519 signature")
        except (TypeError, ValueError) as exc:
            fail(f"{context}: invalid Ed25519 key or signature encoding: {exc}")


def key_id_for(public_key: bytes) -> str:
    return "ed25519:" + hashlib.sha256(public_key).hexdigest()


def validate_public_key(value: Any, context: str, key_class: str) -> dict[str, Any]:
    row = require_object(value, context)
    exact_keys(row, ["algorithm", "key_class", "key_id", "public_key_b64"], context)
    if row["algorithm"] != "ed25519":
        fail(f"{context}: algorithm substitution")
    if row["key_class"] != key_class:
        fail(f"{context}: key class does not match verification mode")
    raw = decode_base64(row["public_key_b64"], f"{context}.public_key_b64", 32)
    key_id = require_key_id(row["key_id"], f"{context}.key_id")
    if key_id_for(raw) != key_id:
        fail(f"{context}: key ID is not derived from the raw public key")
    return {"key_id": key_id, "public_key": raw, "record": row}


def signed_message(context_prefix: bytes, payload_type: str, payload_bytes: bytes) -> bytes:
    payload_type_bytes = payload_type.encode("utf-8")
    return (
        context_prefix
        + len(payload_type_bytes).to_bytes(8, "big")
        + payload_type_bytes
        + len(payload_bytes).to_bytes(8, "big")
        + payload_bytes
    )


def validate_envelope(
    data: bytes,
    context: str,
    *,
    prefix: str,
    context_prefix: bytes,
    payload_type: str,
    key_map: dict[str, dict[str, Any]],
    backend: Ed25519Verifier,
) -> tuple[dict[str, Any], str, list[str]]:
    envelope = require_object(parse_canonical_json(data, context), context)
    exact_keys(envelope, ["payload_b64", "payload_type", "schema", "signatures"], context)
    if envelope["schema"] != f"{prefix}.signed-envelope":
        fail(f"{context}: wrong signed-envelope schema")
    if envelope["payload_type"] != payload_type:
        fail(f"{context}: unexpected payload type")
    payload_bytes = decode_base64(envelope["payload_b64"], f"{context}.payload_b64")
    if len(payload_bytes) > MAX_EXTERNAL_JSON_BYTES:
        fail(f"{context}: signed payload is oversized")
    payload = require_object(
        parse_canonical_json(payload_bytes, f"{context}.payload"),
        f"{context}.payload",
    )
    signatures = require_array(envelope["signatures"], f"{context}.signatures")
    signer_ids: list[str] = []
    message = signed_message(context_prefix, payload_type, payload_bytes)
    for index, item in enumerate(signatures):
        signature_context = f"{context}.signatures[{index}]"
        signature = require_object(item, signature_context)
        exact_keys(signature, ["algorithm", "key_id", "signature_b64"], signature_context)
        if signature["algorithm"] != "ed25519":
            fail(f"{signature_context}: algorithm substitution")
        key_id = require_key_id(signature["key_id"], f"{signature_context}.key_id")
        if key_id not in key_map:
            fail(f"{signature_context}: signer is not authorized by the pinned trust data")
        raw_signature = decode_base64(
            signature["signature_b64"],
            f"{signature_context}.signature_b64",
            64,
        )
        backend.verify(
            key_map[key_id]["public_key"],
            raw_signature,
            message,
            signature_context,
        )
        signer_ids.append(key_id)
    if not signer_ids:
        fail(f"{context}: unsigned envelope")
    if signer_ids != sorted(signer_ids) or len(signer_ids) != len(set(signer_ids)):
        fail(f"{context}: signatures must be sorted and unique")
    return payload, sha256_digest(data), signer_ids


def safe_artifact_path(value: Any, context: str) -> str:
    path = require_text(value, context, maximum=240)
    try:
        path.encode("ascii")
    except UnicodeEncodeError:
        fail(f"{context}: artifact paths must be ASCII")
    if "\\" in path or path.startswith("/") or "\x00" in path:
        fail(f"{context}: unsafe artifact path")
    pure = PurePosixPath(path)
    if str(pure) != path or any(part in ("", ".", "..") for part in pure.parts):
        fail(f"{context}: non-canonical or traversing artifact path")
    return path


class FixtureAssuranceVerifier:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.prefix = FIXTURE_PREFIX
        self.evidence_class = "fixture"
        self.key_class = "fixture-test"
        self.signature_context = FIXTURE_SIGNATURE_CONTEXT
        self.accept_grants = FIXTURE_ACCEPT_GRANTS
        self.always_denied = FIXTURE_ALWAYS_DENIED
        self.backend = Ed25519Verifier()
        self.policy: dict[str, Any]
        self.principals: dict[str, dict[str, Any]]
        self.principal_keys: dict[str, dict[str, Any]]
        self.policy_digest: str
        self.trust_root_digest: str
        self.cas: CasReader | None = None

    def verify(self) -> dict[str, Any]:
        self._validate_cli_pins()
        root_bytes = read_regular_once(
            self.args.trust_root,
            MAX_EXTERNAL_JSON_BYTES,
            "TrustRoot",
        )
        self.trust_root_digest = sha256_digest(root_bytes)
        if self.trust_root_digest != self.args.expected_trust_root_digest:
            fail("TrustRoot: external digest pin mismatch")
        trust_root, root_keys = self._validate_trust_root(root_bytes)

        policy_bytes = read_regular_once(
            self.args.policy_envelope,
            MAX_EXTERNAL_JSON_BYTES,
            "CampaignPolicy envelope",
        )
        if sha256_digest(policy_bytes) != self.args.expected_policy_digest:
            fail("CampaignPolicy: external envelope digest pin mismatch")
        policy, self.policy_digest, policy_signers = validate_envelope(
            policy_bytes,
            "CampaignPolicy envelope",
            prefix=self.prefix,
            context_prefix=self.signature_context,
            payload_type=f"{self.prefix}.campaign-policy",
            key_map=root_keys,
            backend=self.backend,
        )
        if len(policy_signers) < trust_root["policy_signature_threshold"]:
            fail("CampaignPolicy: root signature threshold is not met")
        self._validate_policy(policy)
        self.policy = policy
        if set(root_keys) & set(self.principal_keys):
            fail("CampaignPolicy: trust-root policy key is reused by a campaign principal")

        self._validate_local_tool_pins()
        freeze_record_bytes = read_regular_once(
            self.args.freeze_record,
            MAX_EXTERNAL_JSON_BYTES,
            "FreezeRecord",
        )
        supplied_freeze_record = self._validate_freeze_record_shape(freeze_record_bytes)

        self.cas = CasReader(self.args.cas_root)
        try:
            capsule, manifest_bytes = self._validate_capsule(supplied_freeze_record)
            seal_digest = self._validate_candidate_seal(
                supplied_freeze_record,
                capsule,
            )
            self._run_semantic_validator(capsule, manifest_bytes)
            roster, roster_digest, assignments = self._validate_roster(
                supplied_freeze_record,
                capsule,
                seal_digest,
            )
            reviews = self._validate_reviews(
                supplied_freeze_record,
                capsule,
                seal_digest,
                roster_digest,
                assignments,
                manifest_bytes,
            )
            aggregate, aggregate_digest = self._validate_aggregate(
                supplied_freeze_record,
                capsule,
                seal_digest,
                roster_digest,
                reviews,
            )
            decision_digest = self._validate_decision(
                supplied_freeze_record,
                capsule,
                aggregate,
                aggregate_digest,
            )
            expected_freeze_record = self._derive_freeze_record(
                capsule,
                seal_digest,
                roster_digest,
                reviews,
                aggregate,
                aggregate_digest,
                decision_digest,
            )
            if not strict_equal(supplied_freeze_record, expected_freeze_record):
                fail("FreezeRecord: object is not the exact deterministic derivation")
        finally:
            self.cas.close()

        return {
            "architecture_frozen": False,
            "campaign_decision": aggregate["decision"],
            "evidence_class": "fixture",
            "evidence_valid": True,
            "freeze_authorized": False,
            "mechanics_profile_digest": fixture_mechanics_profile_digest(),
            "tla_authorized": False,
        }

    def _validate_cli_pins(self) -> None:
        for name in (
            "expected_trust_root_digest",
            "expected_policy_digest",
            "expected_semantic_validator_digest",
        ):
            require_digest(getattr(self.args, name), f"CLI --{name.replace('_', '-')}")
        require_int(
            self.args.expected_trust_root_epoch,
            "CLI --expected-trust-root-epoch",
            minimum=1,
        )
        require_int(
            self.args.expected_policy_epoch,
            "CLI --expected-policy-epoch",
            minimum=1,
        )
        require_id(self.args.expected_policy_id, "CLI --expected-policy-id")
        require_id(self.args.expected_project, "CLI --expected-project")
        require_requirement(
            self.args.expected_requirement,
            "CLI --expected-requirement",
        )
        require_id(self.args.expected_cas_store_id, "CLI --expected-cas-store-id")

    def _validate_trust_root(
        self,
        data: bytes,
    ) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
        root = require_object(parse_canonical_json(data, "TrustRoot"), "TrustRoot")
        exact_keys(
            root,
            [
                "active_policy_keys",
                "phase",
                "policy_signature_threshold",
                "project",
                "revoked_key_ids",
                "root_epoch",
                "schema",
            ],
            "TrustRoot",
        )
        if root["schema"] != f"{self.prefix}.trust-root":
            fail("TrustRoot: wrong schema or phase")
        require_int(root["phase"], "TrustRoot.phase", minimum=1, maximum=1)
        if root["project"] != self.args.expected_project:
            fail("TrustRoot: project does not match explicit expectation")
        root_epoch = require_int(root["root_epoch"], "TrustRoot.root_epoch", minimum=1)
        if root_epoch != self.args.expected_trust_root_epoch:
            fail("TrustRoot: epoch does not match explicit expectation")
        rows = require_array(root["active_policy_keys"], "TrustRoot.active_policy_keys")
        keys: dict[str, dict[str, Any]] = {}
        ordered: list[str] = []
        for index, row in enumerate(rows):
            parsed = validate_public_key(
                row,
                f"TrustRoot.active_policy_keys[{index}]",
                self.key_class,
            )
            if parsed["key_id"] in keys:
                fail("TrustRoot: duplicate active policy key")
            keys[parsed["key_id"]] = parsed
            ordered.append(parsed["key_id"])
        if ordered != sorted(ordered):
            fail("TrustRoot: active policy keys are not sorted")
        threshold = require_int(
            root["policy_signature_threshold"],
            "TrustRoot.policy_signature_threshold",
            minimum=1,
        )
        if threshold > len(keys):
            fail("TrustRoot: impossible policy signature threshold")
        revoked = require_sorted_unique_strings(
            root["revoked_key_ids"],
            "TrustRoot.revoked_key_ids",
            validator=require_key_id,
        )
        if set(revoked) & set(keys):
            fail("TrustRoot: an active policy key is also revoked")
        return root, keys

    def _validate_policy(self, policy: dict[str, Any]) -> None:
        exact_keys(
            policy,
            [
                "assignment_authorities",
                "campaign_id",
                "candidate_authors",
                "candidate_digest_commitment",
                "candidate_profile",
                "cas_store_id",
                "claim_ceiling",
                "custodians",
                "decision_authorities",
                "decision_rules",
                "evidence_class",
                "finding_catalog_digest",
                "independence_rules",
                "max_artifact_bytes",
                "max_capsule_bytes",
                "max_manifest_entries",
                "max_total_artifact_bytes",
                "phase",
                "policy_epoch",
                "policy_id",
                "policy_precedes_candidate",
                "principals",
                "project",
                "required_manifest",
                "requirement",
                "review_rules",
                "reviewer_principals",
                "schema",
                "semantic_schema_digest",
                "semantic_validator_timeout_seconds",
                "trusted_assurance_verifier_digest",
                "trusted_semantic_validator_digest",
            ],
            "CampaignPolicy",
        )
        if policy["schema"] != f"{self.prefix}.campaign-policy":
            fail("CampaignPolicy: wrong schema or phase")
        require_int(policy["phase"], "CampaignPolicy.phase", minimum=2, maximum=2)
        if policy["policy_id"] != self.args.expected_policy_id:
            fail("CampaignPolicy: policy ID expectation mismatch")
        policy_epoch = require_int(
            policy["policy_epoch"],
            "CampaignPolicy.policy_epoch",
            minimum=1,
        )
        if policy_epoch != self.args.expected_policy_epoch:
            fail("CampaignPolicy: policy epoch expectation mismatch")
        if policy["project"] != self.args.expected_project:
            fail("CampaignPolicy: project expectation mismatch")
        if policy["requirement"] != self.args.expected_requirement:
            fail("CampaignPolicy: requirement expectation mismatch")
        require_id(policy["campaign_id"], "CampaignPolicy.campaign_id")
        if policy["evidence_class"] != self.evidence_class:
            fail("CampaignPolicy: evidence class crosses the real/fixture boundary")
        if policy["candidate_digest_commitment"] is not None:
            fail("CampaignPolicy: policy must not contain a candidate digest commitment")
        if policy["policy_precedes_candidate"] is not True:
            fail("CampaignPolicy: pre-candidate issuance invariant is absent")
        if policy["cas_store_id"] != self.args.expected_cas_store_id:
            fail("CampaignPolicy: CAS store ID expectation mismatch")
        require_id(policy["cas_store_id"], "CampaignPolicy.cas_store_id")
        require_digest(policy["finding_catalog_digest"], "CampaignPolicy.finding_catalog_digest")
        require_digest(policy["semantic_schema_digest"], "CampaignPolicy.semantic_schema_digest")
        require_digest(
            policy["trusted_assurance_verifier_digest"],
            "CampaignPolicy.trusted_assurance_verifier_digest",
        )
        require_digest(
            policy["trusted_semantic_validator_digest"],
            "CampaignPolicy.trusted_semantic_validator_digest",
        )
        require_int(
            policy["semantic_validator_timeout_seconds"],
            "CampaignPolicy.semantic_validator_timeout_seconds",
            minimum=1,
            maximum=60,
        )

        profile = require_object(policy["candidate_profile"], "CampaignPolicy.candidate_profile")
        exact_keys(profile, ["capsule_schema", "profile_id"], "CampaignPolicy.candidate_profile")
        require_id(profile["profile_id"], "CampaignPolicy.candidate_profile.profile_id")
        if profile["capsule_schema"] != f"{self.prefix}.candidate-capsule":
            fail("CampaignPolicy: candidate profile crosses schema namespace")

        max_manifest = require_int(
            policy["max_manifest_entries"],
            "CampaignPolicy.max_manifest_entries",
            minimum=1,
            maximum=MAX_MANIFEST_ENTRIES_HARD,
        )
        require_int(
            policy["max_artifact_bytes"],
            "CampaignPolicy.max_artifact_bytes",
            minimum=1,
            maximum=MAX_ARTIFACT_BYTES_HARD,
        )
        require_int(
            policy["max_total_artifact_bytes"],
            "CampaignPolicy.max_total_artifact_bytes",
            minimum=1,
            maximum=MAX_TOTAL_ARTIFACT_BYTES_HARD,
        )
        require_int(
            policy["max_capsule_bytes"],
            "CampaignPolicy.max_capsule_bytes",
            minimum=1,
            maximum=MAX_EXTERNAL_JSON_BYTES,
        )
        manifest = require_array(policy["required_manifest"], "CampaignPolicy.required_manifest")
        if not manifest or len(manifest) > max_manifest:
            fail("CampaignPolicy: required manifest size is outside policy bounds")
        manifest_paths: list[str] = []
        manifest_roles: list[str] = []
        for index, item in enumerate(manifest):
            context = f"CampaignPolicy.required_manifest[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["media_type", "path", "role"], context)
            path = safe_artifact_path(row["path"], f"{context}.path")
            role = require_role(row["role"], f"{context}.role")
            if not isinstance(row["media_type"], str) or MEDIA_RE.fullmatch(row["media_type"]) is None:
                fail(f"{context}.media_type: invalid media type")
            manifest_paths.append(path)
            manifest_roles.append(role)
        if manifest_paths != sorted(manifest_paths) or len(manifest_paths) != len(set(manifest_paths)):
            fail("CampaignPolicy: required manifest paths must be sorted and unique")
        for special in ("finding_catalog", "semantic_schema"):
            if manifest_roles.count(special) != 1:
                fail(f"CampaignPolicy: exactly one {special} role is required")
        if "architecture_contract" not in manifest_roles:
            fail("CampaignPolicy: architecture_contract role is required")

        independence = require_object(
            policy["independence_rules"],
            "CampaignPolicy.independence_rules",
        )
        exact_keys(
            independence,
            ["dimensions", "disjoint_role_classes", "enforced"],
            "CampaignPolicy.independence_rules",
        )
        if not strict_equal(independence, {
            "dimensions": DIMENSIONS,
            "disjoint_role_classes": ROLE_CLASSES,
            "enforced": True,
        }):
            fail("CampaignPolicy: independence rules are weaker than v2")

        review_rules = require_object(policy["review_rules"], "CampaignPolicy.review_rules")
        exact_keys(
            review_rules,
            [
                "accepting_review_all_known_findings_closed",
                "accepting_review_no_freeze_blocking_limitation",
                "accepting_review_no_new_blocker",
                "blind_until_all_submitted",
                "complete_finding_coverage",
                "exactly_one_per_role",
                "other_review_digests_must_be_empty",
                "required_roles",
            ],
            "CampaignPolicy.review_rules",
        )
        expected_review_rules = {
            "accepting_review_all_known_findings_closed": True,
            "accepting_review_no_freeze_blocking_limitation": True,
            "accepting_review_no_new_blocker": True,
            "blind_until_all_submitted": True,
            "complete_finding_coverage": True,
            "exactly_one_per_role": True,
            "other_review_digests_must_be_empty": True,
            "required_roles": REVIEW_ROLES,
        }
        if not strict_equal(review_rules, expected_review_rules):
            fail("CampaignPolicy: review rules are weaker than v2")

        decision_rules = require_object(
            policy["decision_rules"],
            "CampaignPolicy.decision_rules",
        )
        exact_keys(
            decision_rules,
            [
                "aggregate_algorithm",
                "decision_authority_count",
                "every_assignment_must_appear",
                "signature_threshold",
            ],
            "CampaignPolicy.decision_rules",
        )
        if not strict_equal(decision_rules, {
            "aggregate_algorithm": "archfreeze-v2-deterministic-aggregate",
            "decision_authority_count": 3,
            "every_assignment_must_appear": True,
            "signature_threshold": 2,
        }):
            fail("CampaignPolicy: decision rules are not exact v2 2-of-3 rules")

        ceiling = require_object(policy["claim_ceiling"], "CampaignPolicy.claim_ceiling")
        exact_keys(ceiling, ["accept_grants", "always_denied"], "CampaignPolicy.claim_ceiling")
        if not strict_equal(ceiling, {
            "accept_grants": self.accept_grants,
            "always_denied": self.always_denied,
        }):
            fail("CampaignPolicy: claim ceiling exceeds the mode-specific v2 ceiling")

        self._validate_principals(policy)

    def _validate_principals(self, policy: dict[str, Any]) -> None:
        role_lists: dict[str, list[str]] = {}
        for field in (
            "candidate_authors",
            "custodians",
            "assignment_authorities",
            "decision_authorities",
            "reviewer_principals",
        ):
            role_lists[field] = require_sorted_unique_strings(
                policy[field],
                f"CampaignPolicy.{field}",
                validator=require_id,
            )
        if not role_lists["candidate_authors"]:
            fail("CampaignPolicy: at least one candidate author is required")
        if len(role_lists["custodians"]) != 1:
            fail("CampaignPolicy: v2 requires exactly one capsule custodian")
        if len(role_lists["assignment_authorities"]) != 1:
            fail("CampaignPolicy: v2 requires exactly one assignment authority")
        if len(role_lists["decision_authorities"]) != 3:
            fail("CampaignPolicy: v2 requires exactly three decision authorities")
        if len(role_lists["reviewer_principals"]) != 4:
            fail("CampaignPolicy: v2 requires exactly four reviewer principals")
        all_role_ids = [item for rows in role_lists.values() for item in rows]
        if len(all_role_ids) != len(set(all_role_ids)):
            fail("CampaignPolicy: principal overlaps role classes")

        principal_rows = require_array(policy["principals"], "CampaignPolicy.principals")
        principals: dict[str, dict[str, Any]] = {}
        key_map: dict[str, dict[str, Any]] = {}
        ordered_principal_ids: list[str] = []
        for index, item in enumerate(principal_rows):
            context = f"CampaignPolicy.principals[{index}]"
            row = require_object(item, context)
            exact_keys(
                row,
                [
                    "active_keys",
                    "eligible_roles",
                    "independence_group",
                    "organization_id",
                    "person_id",
                    "principal_id",
                ],
                context,
            )
            principal_id = require_id(row["principal_id"], f"{context}.principal_id")
            require_id(row["person_id"], f"{context}.person_id")
            require_id(row["organization_id"], f"{context}.organization_id")
            require_id(row["independence_group"], f"{context}.independence_group")
            roles = require_sorted_unique_strings(
                row["eligible_roles"],
                f"{context}.eligible_roles",
                validator=require_role,
            )
            if len(roles) != 1:
                fail(f"{context}: each v2 principal has one eligible role")
            keys = require_array(row["active_keys"], f"{context}.active_keys")
            if len(keys) != 1:
                fail(f"{context}: each v2 campaign principal has one active key")
            key = validate_public_key(keys[0], f"{context}.active_keys[0]", self.key_class)
            if key["key_id"] in key_map:
                fail("CampaignPolicy: active key reused by multiple principals")
            key["principal_id"] = principal_id
            key_map[key["key_id"]] = key
            if principal_id in principals:
                fail("CampaignPolicy: duplicate principal ID")
            principals[principal_id] = row
            ordered_principal_ids.append(principal_id)
        if ordered_principal_ids != sorted(ordered_principal_ids):
            fail("CampaignPolicy: principals must be sorted by principal_id")
        if set(principals) != set(all_role_ids):
            fail("CampaignPolicy: principal table and role sets are not exact")

        expected_roles: dict[str, str] = {}
        for principal_id in role_lists["candidate_authors"]:
            expected_roles[principal_id] = "candidate_author"
        for principal_id in role_lists["custodians"]:
            expected_roles[principal_id] = "custodian"
        for principal_id in role_lists["assignment_authorities"]:
            expected_roles[principal_id] = "assignment_authority"
        for principal_id in role_lists["decision_authorities"]:
            expected_roles[principal_id] = "decision_authority"
        reviewer_roles: list[str] = []
        for principal_id in role_lists["reviewer_principals"]:
            role = principals[principal_id]["eligible_roles"][0]
            if role not in REVIEW_ROLES:
                fail("CampaignPolicy: reviewer is not eligible for one exact required role")
            reviewer_roles.append(role)
            expected_roles[principal_id] = role
        if sorted(reviewer_roles) != REVIEW_ROLES or len(set(reviewer_roles)) != 4:
            fail("CampaignPolicy: reviewer role eligibility is not one-to-one")
        for principal_id, role in expected_roles.items():
            if principals[principal_id]["eligible_roles"] != [role]:
                fail(f"CampaignPolicy: wrong eligible role for {principal_id}")

        categories = {
            "candidate_author": role_lists["candidate_authors"],
            "custodian": role_lists["custodians"],
            "assignment_authority": role_lists["assignment_authorities"],
            "decision_authority": role_lists["decision_authorities"],
            "reviewer": role_lists["reviewer_principals"],
        }
        self._enforce_declared_independence(principals, key_map, categories)
        self.principals = principals
        self.principal_keys = key_map

    @staticmethod
    def _enforce_declared_independence(
        principals: dict[str, dict[str, Any]],
        key_map: dict[str, dict[str, Any]],
        categories: dict[str, list[str]],
    ) -> None:
        principal_key = {
            key["principal_id"]: key_id for key_id, key in key_map.items()
        }

        def dimensions(principal_id: str) -> tuple[str, str, str, str]:
            row = principals[principal_id]
            return (
                principal_key[principal_id],
                row["person_id"],
                row["organization_id"],
                row["independence_group"],
            )

        for category in ("reviewer", "decision_authority"):
            values = [dimensions(item) for item in categories[category]]
            for dimension_index in range(4):
                projected = [value[dimension_index] for value in values]
                if len(projected) != len(set(projected)):
                    fail(f"CampaignPolicy: {category} independence dimension overlaps")

        category_names = sorted(categories)
        for left_index, left_name in enumerate(category_names):
            for right_name in category_names[left_index + 1 :]:
                for left in categories[left_name]:
                    for right in categories[right_name]:
                        left_dimensions = dimensions(left)
                        right_dimensions = dimensions(right)
                        if any(a == b for a, b in zip(left_dimensions, right_dimensions)):
                            fail(
                                "CampaignPolicy: role classes overlap a key/person/"
                                "organization/independence-group dimension"
                            )

    def _validate_local_tool_pins(self) -> None:
        verifier_path = Path(__file__).resolve()
        verifier_bytes = read_regular_once(verifier_path, MAX_TOOL_BYTES, "assurance verifier")
        if sha256_digest(verifier_bytes) != self.policy["trusted_assurance_verifier_digest"]:
            fail("CampaignPolicy: running assurance verifier is not the pinned byte image")

        semantic_path = self.args.semantic_validator.resolve()
        semantic_bytes = read_regular_once(semantic_path, MAX_TOOL_BYTES, "semantic validator")
        semantic_digest = sha256_digest(semantic_bytes)
        if semantic_digest != self.args.expected_semantic_validator_digest:
            fail("semantic validator: external digest pin mismatch")
        if semantic_digest != self.policy["trusted_semantic_validator_digest"]:
            fail("semantic validator: policy digest pin mismatch")
        try:
            semantic_path.relative_to(self.args.cas_root.resolve())
        except ValueError:
            pass
        else:
            fail("semantic validator: candidate CAS may not supply the trusted tool")
        self.semantic_validator_bytes = semantic_bytes

    def _validate_freeze_record_shape(self, data: bytes) -> dict[str, Any]:
        record = require_object(parse_canonical_json(data, "FreezeRecord"), "FreezeRecord")
        exact_keys(
            record,
            [
                "aggregate_decision_digest",
                "architecture_frozen",
                "architecture_frozen_pre_formal",
                "campaign_decision",
                "campaign_id",
                "candidate_id",
                "capsule_digest",
                "claims_denied",
                "claims_granted",
                "decision_envelope_digest",
                "derivation_algorithm",
                "derived_status",
                "evidence_class",
                "phase",
                "policy_envelope_digest",
                "project",
                "requirement",
                "review_envelope_digests",
                "roster_envelope_digest",
                "schema",
                "seal_envelope_digest",
                "tla_authorized",
                "trust_root_digest",
            ],
            "FreezeRecord",
        )
        if record["schema"] != f"{self.prefix}.freeze-record":
            fail("FreezeRecord: wrong schema or phase")
        require_int(record["phase"], "FreezeRecord.phase", minimum=9, maximum=9)
        if record["evidence_class"] != self.evidence_class:
            fail("FreezeRecord: evidence class crosses mode boundary")
        for field in (
            "aggregate_decision_digest",
            "capsule_digest",
            "decision_envelope_digest",
            "policy_envelope_digest",
            "roster_envelope_digest",
            "seal_envelope_digest",
            "trust_root_digest",
        ):
            require_digest(record[field], f"FreezeRecord.{field}")
        review_rows = require_array(
            record["review_envelope_digests"],
            "FreezeRecord.review_envelope_digests",
        )
        roles: list[str] = []
        for index, item in enumerate(review_rows):
            context = f"FreezeRecord.review_envelope_digests[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["digest", "role"], context)
            roles.append(require_role(row["role"], f"{context}.role"))
            require_digest(row["digest"], f"{context}.digest")
        if roles != REVIEW_ROLES:
            fail("FreezeRecord: review references must contain the exact sorted four roles")
        require_sorted_unique_strings(
            record["claims_granted"],
            "FreezeRecord.claims_granted",
            validator=require_role,
        )
        require_sorted_unique_strings(
            record["claims_denied"],
            "FreezeRecord.claims_denied",
            validator=require_role,
        )
        require_bool(record["architecture_frozen"], "FreezeRecord.architecture_frozen")
        require_bool(
            record["architecture_frozen_pre_formal"],
            "FreezeRecord.architecture_frozen_pre_formal",
        )
        require_bool(record["tla_authorized"],
                     "FreezeRecord.tla_authorized")
        if record["campaign_decision"] not in ("accept", "reject"):
            fail("FreezeRecord: campaign_decision must be accept or reject")
        return record

    def _validate_capsule(
        self,
        freeze_record: dict[str, Any],
    ) -> tuple[dict[str, Any], dict[str, bytes]]:
        assert self.cas is not None
        capsule_digest = freeze_record["capsule_digest"]
        capsule_bytes = self.cas.read(
            capsule_digest,
            self.policy["max_capsule_bytes"],
            "CandidateCapsule",
        )
        capsule = require_object(
            parse_canonical_json(capsule_bytes, "CandidateCapsule"),
            "CandidateCapsule",
        )
        exact_keys(capsule, CANDIDATE_CAPSULE_KEYS, "CandidateCapsule")
        if capsule["schema"] != f"{self.prefix}.candidate-capsule":
            fail("CandidateCapsule: wrong schema or phase")
        require_int(capsule["phase"], "CandidateCapsule.phase", minimum=3, maximum=3)
        for field, expected in (
            ("campaign_id", self.policy["campaign_id"]),
            ("evidence_class", self.evidence_class),
            ("finding_catalog_digest", self.policy["finding_catalog_digest"]),
            ("policy_digest", self.policy_digest),
            ("project", self.args.expected_project),
            ("requirement", self.args.expected_requirement),
            ("state", "sealedCandidate"),
        ):
            if capsule[field] != expected:
                fail(f"CandidateCapsule: {field} binding mismatch")
        require_id(capsule["candidate_id"], "CandidateCapsule.candidate_id")
        sequence = require_int(
            capsule["candidate_sequence"],
            "CandidateCapsule.candidate_sequence",
            minimum=1,
            maximum=MAX_CANDIDATE_HISTORY,
        )
        if sequence == 1:
            if capsule["previous_capsule_digest"] is not None:
                fail("CandidateCapsule: first sequence must have no predecessor")
        else:
            require_digest(
                capsule["previous_capsule_digest"],
                "CandidateCapsule.previous_capsule_digest",
            )
        authors = require_sorted_unique_strings(
            capsule["candidate_authors"],
            "CandidateCapsule.candidate_authors",
            validator=require_id,
        )
        if authors != self.policy["candidate_authors"]:
            fail("CandidateCapsule: author set does not match policy")
        claims = require_object(capsule["claims"], "CandidateCapsule.claims")
        exact_keys(claims, CANDIDATE_CLAIM_KEYS, "CandidateCapsule.claims")
        if any(claims[key] is not False for key in CANDIDATE_CLAIM_KEYS):
            fail("CandidateCapsule: candidate may not contain a freeze or later claim")
        self._validate_capsule_history(capsule, capsule_digest)

        manifest = require_array(capsule["artifact_manifest"], "CandidateCapsule.artifact_manifest")
        if len(manifest) != len(self.policy["required_manifest"]):
            fail("CandidateCapsule: manifest is not the exact policy manifest")
        paths: list[str] = []
        digests: list[str] = []
        manifest_bytes: dict[str, bytes] = {}
        total = 0
        for index, (item, requirement) in enumerate(
            zip(manifest, self.policy["required_manifest"])
        ):
            context = f"CandidateCapsule.artifact_manifest[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["digest", "media_type", "path", "role", "size"], context)
            path = safe_artifact_path(row["path"], f"{context}.path")
            if {
                "path": path,
                "role": row["role"],
                "media_type": row["media_type"],
            } != requirement:
                fail("CandidateCapsule: manifest role/path/media does not match policy")
            digest = require_digest(row["digest"], f"{context}.digest")
            size = require_int(
                row["size"],
                f"{context}.size",
                maximum=self.policy["max_artifact_bytes"],
            )
            data = self.cas.read(digest, self.policy["max_artifact_bytes"], context)
            if len(data) != size:
                fail(f"{context}: declared size differs from raw bytes")
            total += size
            if total > self.policy["max_total_artifact_bytes"]:
                fail("CandidateCapsule: total artifact bytes exceed policy")
            paths.append(path)
            digests.append(digest)
            manifest_bytes[path] = data
        if paths != sorted(paths) or len(paths) != len(set(paths)):
            fail("CandidateCapsule: artifact paths must be sorted and unique")
        if len(digests) != len(set(digests)):
            fail("CandidateCapsule: artifact digests must be unique")

        finding_rows = [row for row in manifest if row["role"] == "finding_catalog"]
        schema_rows = [row for row in manifest if row["role"] == "semantic_schema"]
        if finding_rows[0]["digest"] != self.policy["finding_catalog_digest"]:
            fail("CandidateCapsule: finding catalog is not policy-pinned")
        if schema_rows[0]["digest"] != self.policy["semantic_schema_digest"]:
            fail("CandidateCapsule: semantic schema is not policy-pinned")
        finding_data = manifest_bytes[finding_rows[0]["path"]]
        self.finding_ids = self._validate_finding_catalog(finding_data)
        self.manifest_digests = sorted(digests)
        self.capsule_digest = capsule_digest
        return capsule, manifest_bytes

    def _validate_capsule_history(
        self,
        current: dict[str, Any],
        current_digest: str,
    ) -> None:
        assert self.cas is not None
        expected_sequence = current["candidate_sequence"] - 1
        predecessor_digest = current["previous_capsule_digest"]
        seen = {current_digest}
        while expected_sequence > 0:
            if predecessor_digest is None:
                fail("CandidateCapsule: predecessor chain terminates before sequence one")
            require_digest(predecessor_digest, "CandidateCapsule predecessor digest")
            if predecessor_digest in seen:
                fail("CandidateCapsule: predecessor chain contains a cycle")
            seen.add(predecessor_digest)
            data = self.cas.read(
                predecessor_digest,
                self.policy["max_capsule_bytes"],
                f"CandidateCapsule predecessor sequence {expected_sequence}",
            )
            predecessor = require_object(
                parse_canonical_json(
                    data,
                    f"CandidateCapsule predecessor sequence {expected_sequence}",
                ),
                f"CandidateCapsule predecessor sequence {expected_sequence}",
            )
            context = f"CandidateCapsule predecessor sequence {expected_sequence}"
            exact_keys(predecessor, CANDIDATE_CAPSULE_KEYS, context)
            if predecessor["schema"] != f"{self.prefix}.candidate-capsule":
                fail(f"{context}: wrong schema")
            require_int(predecessor["phase"], f"{context}.phase", minimum=3, maximum=3)
            sequence = require_int(
                predecessor["candidate_sequence"],
                f"{context}.candidate_sequence",
                minimum=1,
                maximum=MAX_CANDIDATE_HISTORY,
            )
            if sequence != expected_sequence:
                fail(f"{context}: predecessor sequence is not exactly n-1")
            for field in (
                "campaign_id",
                "candidate_authors",
                "candidate_id",
                "evidence_class",
                "finding_catalog_digest",
                "policy_digest",
                "project",
                "requirement",
                "state",
            ):
                if not strict_equal(predecessor[field], current[field]):
                    fail(f"{context}: {field} differs from the current candidate series")
            claims = require_object(predecessor["claims"], f"{context}.claims")
            exact_keys(claims, CANDIDATE_CLAIM_KEYS, f"{context}.claims")
            if any(claims[key] is not False for key in CANDIDATE_CLAIM_KEYS):
                fail(f"{context}: historical candidate contains a forbidden claim")
            self._validate_historical_manifest(predecessor["artifact_manifest"], context)
            predecessor_digest = predecessor["previous_capsule_digest"]
            if sequence == 1:
                if predecessor_digest is not None:
                    fail(f"{context}: sequence one has a predecessor")
            else:
                require_digest(predecessor_digest, f"{context}.previous_capsule_digest")
            expected_sequence -= 1

    def _validate_historical_manifest(self, value: Any, context: str) -> None:
        manifest = require_array(value, f"{context}.artifact_manifest")
        if len(manifest) != len(self.policy["required_manifest"]):
            fail(f"{context}: historical manifest does not match policy size")
        paths: list[str] = []
        digests: list[str] = []
        role_digests: dict[str, str] = {}
        total = 0
        for index, (item, requirement) in enumerate(
            zip(manifest, self.policy["required_manifest"])
        ):
            row_context = f"{context}.artifact_manifest[{index}]"
            row = require_object(item, row_context)
            exact_keys(row, ["digest", "media_type", "path", "role", "size"], row_context)
            path = safe_artifact_path(row["path"], f"{row_context}.path")
            if not strict_equal(
                {
                    "media_type": row["media_type"],
                    "path": path,
                    "role": row["role"],
                },
                requirement,
            ):
                fail(f"{row_context}: historical manifest identity differs from policy")
            digest = require_digest(row["digest"], f"{row_context}.digest")
            digests.append(digest)
            role_digests[row["role"]] = digest
            total += require_int(
                row["size"],
                f"{row_context}.size",
                maximum=self.policy["max_artifact_bytes"],
            )
            paths.append(path)
        if paths != sorted(paths) or len(paths) != len(set(paths)):
            fail(f"{context}: historical manifest paths are not sorted and unique")
        if len(digests) != len(set(digests)):
            fail(f"{context}: historical manifest digests are not unique")
        if total > self.policy["max_total_artifact_bytes"]:
            fail(f"{context}: historical manifest exceeds total byte policy")
        if role_digests.get("finding_catalog") != self.policy["finding_catalog_digest"]:
            fail(f"{context}: historical finding catalog is not policy-pinned")
        if role_digests.get("semantic_schema") != self.policy["semantic_schema_digest"]:
            fail(f"{context}: historical semantic schema is not policy-pinned")

    def _validate_finding_catalog(self, data: bytes) -> list[str]:
        catalog = require_object(
            parse_canonical_json(data, "finding catalog"),
            "finding catalog",
        )
        exact_keys(catalog, ["catalog_id", "findings", "schema"], "finding catalog")
        if catalog["schema"] != f"{self.prefix}.finding-catalog":
            fail("finding catalog: wrong schema namespace")
        require_id(catalog["catalog_id"], "finding catalog.catalog_id")
        rows = require_array(catalog["findings"], "finding catalog.findings")
        if not rows:
            fail("finding catalog: empty catalog cannot support a freeze campaign")
        ids: list[str] = []
        for index, item in enumerate(rows):
            context = f"finding catalog.findings[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["finding_id", "severity", "title"], context)
            ids.append(require_finding_id(
                row["finding_id"], f"{context}.finding_id"))
            if row["severity"] not in ("critical", "high", "low", "medium"):
                fail(f"{context}: invalid severity")
            require_text(row["title"], f"{context}.title", maximum=1024)
        if ids != sorted(ids) or len(ids) != len(set(ids)):
            fail("finding catalog: findings must be sorted and unique")
        return ids

    def _keys_for_principals(self, principal_ids: list[str]) -> list[str]:
        result = []
        for principal_id in principal_ids:
            matches = [
                key_id
                for key_id, key in self.principal_keys.items()
                if key["principal_id"] == principal_id
            ]
            if len(matches) != 1:
                fail(f"principal {principal_id}: active signer key is not unique")
            result.append(matches[0])
        return sorted(result)

    def _read_envelope_from_cas(
        self,
        digest: str,
        context: str,
        payload_type: str,
    ) -> tuple[dict[str, Any], str, list[str]]:
        assert self.cas is not None
        data = self.cas.read(digest, MAX_EXTERNAL_JSON_BYTES, context)
        return validate_envelope(
            data,
            context,
            prefix=self.prefix,
            context_prefix=self.signature_context,
            payload_type=f"{self.prefix}.{payload_type}",
            key_map=self.principal_keys,
            backend=self.backend,
        )

    def _validate_candidate_seal(
        self,
        freeze_record: dict[str, Any],
        capsule: dict[str, Any],
    ) -> str:
        payload, digest, signers = self._read_envelope_from_cas(
            freeze_record["seal_envelope_digest"],
            "CandidateSeal envelope",
            "candidate-seal",
        )
        exact_keys(
            payload,
            [
                "campaign_id",
                "candidate_authors",
                "candidate_id",
                "capsule_digest",
                "custodian_id",
                "custody_sequence",
                "manifest_count",
                "phase",
                "policy_digest",
                "purpose",
                "schema",
                "storage_anchor",
                "total_bytes",
            ],
            "CandidateSeal",
        )
        if payload["schema"] != f"{self.prefix}.candidate-seal":
            fail("CandidateSeal: wrong schema or phase")
        require_int(payload["phase"], "CandidateSeal.phase", minimum=4, maximum=4)
        expected_bindings = {
            "campaign_id": self.policy["campaign_id"],
            "candidate_id": capsule["candidate_id"],
            "capsule_digest": self.capsule_digest,
            "policy_digest": self.policy_digest,
            "purpose": "architectureFreezeReview",
        }
        for field, expected in expected_bindings.items():
            if payload[field] != expected:
                fail(f"CandidateSeal: {field} binding mismatch")
        if payload["candidate_authors"] != self.policy["candidate_authors"]:
            fail("CandidateSeal: exact author set mismatch")
        custodian = require_id(payload["custodian_id"], "CandidateSeal.custodian_id")
        if [custodian] != self.policy["custodians"]:
            fail("CandidateSeal: custodian is not the policy-bound independent custodian")
        require_int(
            payload["custody_sequence"],
            "CandidateSeal.custody_sequence",
            minimum=capsule["candidate_sequence"],
        )
        if payload["manifest_count"] != len(capsule["artifact_manifest"]):
            fail("CandidateSeal: manifest count mismatch")
        total_bytes = sum(row["size"] for row in capsule["artifact_manifest"])
        if payload["total_bytes"] != total_bytes:
            fail("CandidateSeal: total artifact byte count mismatch")
        anchor = require_object(payload["storage_anchor"], "CandidateSeal.storage_anchor")
        exact_keys(
            anchor,
            ["capsule_digest", "read_only", "scheme", "store_id"],
            "CandidateSeal.storage_anchor",
        )
        if not strict_equal(anchor, {
            "capsule_digest": self.capsule_digest,
            "read_only": True,
            "scheme": "cas-sha256-v1",
            "store_id": self.args.expected_cas_store_id,
        }):
            fail("CandidateSeal: storage anchor is not the exact policy-bound read-only CAS")
        expected_signers = self._keys_for_principals(
            self.policy["candidate_authors"] + [custodian]
        )
        if signers != expected_signers:
            fail("CandidateSeal: exact author-plus-custodian signer set mismatch")
        return digest

    def _run_semantic_validator(
        self,
        capsule: dict[str, Any],
        manifest_bytes: dict[str, bytes],
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="archfreeze-v2-sealed-") as temporary:
            base = Path(temporary)
            sealed_root = base / "sealed"
            sealed_root.mkdir(mode=0o700)
            expected_paths: set[str] = set()
            for row in capsule["artifact_manifest"]:
                path = sealed_root / row["path"]
                path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                path.write_bytes(manifest_bytes[row["path"]])
                path.chmod(0o444)
                expected_paths.add(row["path"])
            directories = sorted(
                [item for item in sealed_root.rglob("*") if item.is_dir()],
                key=lambda item: len(item.parts),
                reverse=True,
            )
            for directory in directories:
                directory.chmod(0o555)
            sealed_root.chmod(0o555)

            tool_path = base / "trusted-semantic-validator"
            tool_path.write_bytes(self.semantic_validator_bytes)
            tool_path.chmod(0o500)
            descriptor = {
                "artifact_manifest": capsule["artifact_manifest"],
                "capsule_digest": self.capsule_digest,
                "policy_digest": self.policy_digest,
                "schema": f"{self.prefix}.sealed-candidate-descriptor",
                "sealed_root": str(sealed_root),
                "semantic_schema_digest": self.policy["semantic_schema_digest"],
            }
            stdout_path = base / "semantic.stdout"
            stderr_path = base / "semantic.stderr"
            process: subprocess.Popen[bytes] | None = None
            try:
                with stdout_path.open("wb") as stdout_file, \
                        stderr_path.open("wb") as stderr_file:
                    process = subprocess.Popen(
                        [str(tool_path), "validate-sealed-capsule-v2"],
                        stdin=subprocess.PIPE,
                        stdout=stdout_file,
                        stderr=stderr_file,
                        cwd=base,
                        env={"LANG": "C", "LC_ALL": "C",
                             "PATH": "/usr/bin:/bin"},
                        start_new_session=True,
                        preexec_fn=semantic_fixture_child_limits,
                    )
                    process.communicate(
                        input=jcs_bytes(descriptor),
                        timeout=self.policy["semantic_validator_timeout_seconds"],
                    )
            except subprocess.TimeoutExpired:
                if process is not None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait()
                fail("semantic validator: bounded execution timed out")
            except OSError as exc:
                fail(f"semantic validator: execution failed: {exc}")
            finally:
                if process is not None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            assert process is not None
            stdout = read_regular_once(
                stdout_path, MAX_SEMANTIC_OUTPUT_BYTES,
                "semantic validator stdout")
            read_regular_once(
                stderr_path, MAX_SEMANTIC_OUTPUT_BYTES,
                "semantic validator stderr")
            if process.returncode != 0:
                fail("semantic validator: pinned validator rejected the sealed candidate")
            result = require_object(
                parse_canonical_json(stdout, "semantic validator result"),
                "semantic validator result",
            )
            expected_result = {
                "capsule_digest": self.capsule_digest,
                "schema": f"{self.prefix}.semantic-validation-result",
                "semantic_schema_digest": self.policy["semantic_schema_digest"],
                "valid": True,
            }
            if not strict_equal(result, expected_result):
                fail("semantic validator: result is not the exact success attestation")

            observed_paths: set[str] = set()
            for item in sealed_root.rglob("*"):
                relative = item.relative_to(sealed_root).as_posix()
                if item.is_symlink():
                    fail("semantic validator: sealed byte set gained a symlink")
                if item.is_file():
                    observed_paths.add(relative)
                    data = read_regular_once(item, self.policy["max_artifact_bytes"], "sealed artifact")
                    if data != manifest_bytes.get(relative):
                        fail("semantic validator: sealed artifact bytes changed during validation")
                elif not item.is_dir():
                    fail("semantic validator: sealed byte set gained a special object")
            if observed_paths != expected_paths:
                fail("semantic validator: sealed artifact set changed during validation")

    def _validate_roster(
        self,
        freeze_record: dict[str, Any],
        capsule: dict[str, Any],
        seal_digest: str,
    ) -> tuple[dict[str, Any], str, dict[str, dict[str, Any]]]:
        payload, digest, signers = self._read_envelope_from_cas(
            freeze_record["roster_envelope_digest"],
            "ReviewRoster envelope",
            "review-roster",
        )
        exact_keys(
            payload,
            [
                "assignment_authority_id",
                "assignments",
                "campaign_id",
                "candidate_id",
                "capsule_digest",
                "disclosure_rule",
                "phase",
                "policy_digest",
                "roster_id",
                "schema",
                "seal_digest",
            ],
            "ReviewRoster",
        )
        if payload["schema"] != f"{self.prefix}.review-roster":
            fail("ReviewRoster: wrong schema or phase")
        require_int(payload["phase"], "ReviewRoster.phase", minimum=5, maximum=5)
        expected = {
            "campaign_id": self.policy["campaign_id"],
            "candidate_id": capsule["candidate_id"],
            "capsule_digest": self.capsule_digest,
            "disclosure_rule": "blindUntilAllSubmitted",
            "policy_digest": self.policy_digest,
            "seal_digest": seal_digest,
        }
        for field, value in expected.items():
            if payload[field] != value:
                fail(f"ReviewRoster: {field} binding mismatch")
        require_id(payload["roster_id"], "ReviewRoster.roster_id")
        authority = require_id(
            payload["assignment_authority_id"],
            "ReviewRoster.assignment_authority_id",
        )
        if [authority] != self.policy["assignment_authorities"]:
            fail("ReviewRoster: wrong assignment authority")
        if signers != self._keys_for_principals([authority]):
            fail("ReviewRoster: exact assignment-authority signature required")
        rows = require_array(payload["assignments"], "ReviewRoster.assignments")
        assignments: dict[str, dict[str, Any]] = {}
        roles: list[str] = []
        reviewer_ids: list[str] = []
        assignment_ids: list[str] = []
        for index, item in enumerate(rows):
            context = f"ReviewRoster.assignments[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["assignment_id", "reviewer_principal_id", "role"], context)
            assignment_id = require_id(row["assignment_id"], f"{context}.assignment_id")
            role = require_role(row["role"], f"{context}.role")
            reviewer = require_id(
                row["reviewer_principal_id"],
                f"{context}.reviewer_principal_id",
            )
            if reviewer not in self.policy["reviewer_principals"]:
                fail(f"{context}: reviewer not fixed by policy")
            if self.principals[reviewer]["eligible_roles"] != [role]:
                fail(f"{context}: reviewer is not eligible for assigned role")
            roles.append(role)
            reviewer_ids.append(reviewer)
            assignment_ids.append(assignment_id)
            assignments[role] = row
        if roles != REVIEW_ROLES or len(rows) != 4:
            fail("ReviewRoster: exact sorted four assignments required")
        if len(set(reviewer_ids)) != 4 or len(set(assignment_ids)) != 4:
            fail("ReviewRoster: reviewers and assignments must be unique")
        expected_reviewers = sorted(self.policy["reviewer_principals"])
        if sorted(reviewer_ids) != expected_reviewers:
            fail("ReviewRoster: roster is not the exact policy reviewer set")
        return payload, digest, assignments

    def _validate_reviews(
        self,
        freeze_record: dict[str, Any],
        capsule: dict[str, Any],
        seal_digest: str,
        roster_digest: str,
        assignments: dict[str, dict[str, Any]],
        manifest_bytes: dict[str, bytes],
    ) -> list[dict[str, Any]]:
        del manifest_bytes
        freeze_reviews = {
            row["role"]: row["digest"] for row in freeze_record["review_envelope_digests"]
        }
        results: list[dict[str, Any]] = []
        for role in REVIEW_ROLES:
            digest_ref = freeze_reviews[role]
            payload, digest, signers = self._read_envelope_from_cas(
                digest_ref,
                f"SignedReview[{role}] envelope",
                "signed-review",
            )
            assignment = assignments[role]
            reviewer = assignment["reviewer_principal_id"]
            if signers != self._keys_for_principals([reviewer]):
                fail(f"SignedReview[{role}]: exact assigned reviewer signature required")
            exact_keys(
                payload,
                [
                    "assignment_id",
                    "campaign_id",
                    "candidate_id",
                    "capsule_digest",
                    "finding_catalog_digest",
                    "known_finding_dispositions",
                    "limitations",
                    "new_findings",
                    "other_review_digests_consulted",
                    "phase",
                    "policy_digest",
                    "reviewed_artifact_digests",
                    "reviewer_principal_id",
                    "role",
                    "roster_digest",
                    "schema",
                    "seal_digest",
                    "verdict",
                ],
                f"SignedReview[{role}]",
            )
            if payload["schema"] != f"{self.prefix}.signed-review":
                fail(f"SignedReview[{role}]: wrong schema or phase")
            require_int(
                payload["phase"],
                f"SignedReview[{role}].phase",
                minimum=6,
                maximum=6,
            )
            expected_bindings = {
                "assignment_id": assignment["assignment_id"],
                "campaign_id": self.policy["campaign_id"],
                "candidate_id": capsule["candidate_id"],
                "capsule_digest": self.capsule_digest,
                "finding_catalog_digest": self.policy["finding_catalog_digest"],
                "policy_digest": self.policy_digest,
                "reviewer_principal_id": reviewer,
                "role": role,
                "roster_digest": roster_digest,
                "seal_digest": seal_digest,
            }
            for field, expected in expected_bindings.items():
                if payload[field] != expected:
                    fail(f"SignedReview[{role}]: {field} binding mismatch")
            if payload["other_review_digests_consulted"] != []:
                fail(f"SignedReview[{role}]: blind review consulted another review digest")
            reviewed = require_sorted_unique_strings(
                payload["reviewed_artifact_digests"],
                f"SignedReview[{role}].reviewed_artifact_digests",
                validator=require_digest,
            )
            if reviewed != self.manifest_digests:
                fail(f"SignedReview[{role}]: reviewed artifact set is incomplete")
            dispositions = self._validate_finding_dispositions(payload, role)
            new_findings = self._validate_new_findings(payload, role)
            limitations = self._validate_limitations(payload, role)
            computed_verdict = (
                "accept"
                if all(row["disposition"] == "closed" for row in dispositions)
                and not any(row["blocking"] for row in new_findings)
                and not any(row["freeze_blocking"] for row in limitations)
                else "reject"
            )
            if payload["verdict"] not in ("accept", "reject"):
                fail(f"SignedReview[{role}]: invalid verdict")
            if payload["verdict"] != computed_verdict:
                fail(f"SignedReview[{role}]: declared verdict differs from recomputation")
            results.append(
                {
                    "assignment_id": assignment["assignment_id"],
                    "digest": digest,
                    "dispositions": dispositions,
                    "limitations": limitations,
                    "new_findings": new_findings,
                    "reviewer_principal_id": reviewer,
                    "role": role,
                    "verdict": computed_verdict,
                }
            )
        return results

    def _validate_finding_dispositions(
        self,
        payload: dict[str, Any],
        role: str,
    ) -> list[dict[str, Any]]:
        rows = require_array(
            payload["known_finding_dispositions"],
            f"SignedReview[{role}].known_finding_dispositions",
        )
        result: list[dict[str, Any]] = []
        ids: list[str] = []
        for index, item in enumerate(rows):
            context = f"SignedReview[{role}].known_finding_dispositions[{index}]"
            row = require_object(item, context)
            exact_keys(
                row,
                ["disposition", "evidence_digests", "finding_id", "rationale"],
                context,
            )
            finding_id = require_finding_id(
                row["finding_id"], f"{context}.finding_id")
            if row["disposition"] not in ("closed", "open"):
                fail(f"{context}: invalid disposition")
            evidence = require_sorted_unique_strings(
                row["evidence_digests"],
                f"{context}.evidence_digests",
                validator=require_digest,
            )
            if not evidence or not set(evidence).issubset(set(self.manifest_digests)):
                fail(f"{context}: evidence must be a non-empty candidate artifact subset")
            require_text(row["rationale"], f"{context}.rationale", maximum=4096)
            ids.append(finding_id)
            result.append(row)
        if ids != self.finding_ids:
            fail(f"SignedReview[{role}]: known finding coverage is not exact")
        return result

    def _validate_new_findings(
        self,
        payload: dict[str, Any],
        role: str,
    ) -> list[dict[str, Any]]:
        rows = require_array(payload["new_findings"], f"SignedReview[{role}].new_findings")
        ids: list[str] = []
        result: list[dict[str, Any]] = []
        for index, item in enumerate(rows):
            context = f"SignedReview[{role}].new_findings[{index}]"
            row = require_object(item, context)
            exact_keys(
                row,
                ["blocking", "evidence_digests", "finding_id", "severity", "summary"],
                context,
            )
            finding_id = require_finding_id(
                row["finding_id"], f"{context}.finding_id")
            if finding_id in self.finding_ids:
                fail(f"{context}: new finding collides with known catalog")
            if row["severity"] not in ("critical", "high", "low", "medium"):
                fail(f"{context}: invalid severity")
            require_bool(row["blocking"], f"{context}.blocking")
            evidence = require_sorted_unique_strings(
                row["evidence_digests"],
                f"{context}.evidence_digests",
                validator=require_digest,
            )
            if not evidence or not set(evidence).issubset(set(self.manifest_digests)):
                fail(f"{context}: evidence must be a non-empty candidate artifact subset")
            require_text(row["summary"], f"{context}.summary", maximum=4096)
            ids.append(finding_id)
            result.append(row)
        if ids != sorted(ids) or len(ids) != len(set(ids)):
            fail(f"SignedReview[{role}]: new findings must be sorted and unique")
        return result

    def _validate_limitations(
        self,
        payload: dict[str, Any],
        role: str,
    ) -> list[dict[str, Any]]:
        rows = require_array(payload["limitations"], f"SignedReview[{role}].limitations")
        ids: list[str] = []
        result: list[dict[str, Any]] = []
        for index, item in enumerate(rows):
            context = f"SignedReview[{role}].limitations[{index}]"
            row = require_object(item, context)
            exact_keys(row, ["freeze_blocking", "limitation_id", "statement"], context)
            ids.append(require_id(row["limitation_id"], f"{context}.limitation_id"))
            require_bool(row["freeze_blocking"], f"{context}.freeze_blocking")
            require_text(row["statement"], f"{context}.statement", maximum=4096)
            result.append(row)
        if ids != sorted(ids) or len(ids) != len(set(ids)):
            fail(f"SignedReview[{role}]: limitations must be sorted and unique")
        return result

    def _compute_aggregate(
        self,
        capsule: dict[str, Any],
        seal_digest: str,
        roster_digest: str,
        reviews: list[dict[str, Any]],
    ) -> dict[str, Any]:
        decision = "accept" if all(row["verdict"] == "accept" for row in reviews) else "reject"
        grants = self.accept_grants if decision == "accept" else []
        denied = (
            self.always_denied
            if decision == "accept"
            else sorted(set(self.accept_grants + self.always_denied))
        )
        finding_evaluation = []
        for finding_id in self.finding_ids:
            role_dispositions = [
                {
                    "disposition": next(
                        item["disposition"]
                        for item in review["dispositions"]
                        if item["finding_id"] == finding_id
                    ),
                    "role": review["role"],
                }
                for review in reviews
            ]
            finding_evaluation.append(
                {
                    "all_roles_closed": all(
                        item["disposition"] == "closed" for item in role_dispositions
                    ),
                    "finding_id": finding_id,
                    "role_dispositions": role_dispositions,
                }
            )
        new_findings = []
        limitations = []
        for review in reviews:
            for item in review["new_findings"]:
                new_findings.append({"role": review["role"], **item})
            for item in review["limitations"]:
                limitations.append({"role": review["role"], **item})
        new_findings.sort(key=lambda item: (item["role"], item["finding_id"]))
        limitations.sort(key=lambda item: (item["role"], item["limitation_id"]))
        return {
            "campaign_id": self.policy["campaign_id"],
            "candidate_id": capsule["candidate_id"],
            "capsule_digest": self.capsule_digest,
            "claims_denied": denied,
            "claims_granted": grants,
            "decision": decision,
            "evidence_class": self.evidence_class,
            "finding_evaluation": finding_evaluation,
            "independence_evaluation": {
                "reviewer_independence_groups_distinct": True,
                "reviewer_keys_distinct": True,
                "reviewer_organizations_distinct": True,
                "reviewer_persons_distinct": True,
                "role_classes_disjoint": True,
            },
            "limitations": limitations,
            "new_findings": new_findings,
            "ordered_reviews": [
                {
                    "assignment_id": review["assignment_id"],
                    "computed_verdict": review["verdict"],
                    "review_digest": review["digest"],
                    "reviewer_principal_id": review["reviewer_principal_id"],
                    "role": review["role"],
                }
                for review in reviews
            ],
            "phase": 7,
            "policy_digest": self.policy_digest,
            "roster_digest": roster_digest,
            "schema": f"{self.prefix}.aggregate-decision",
            "seal_digest": seal_digest,
        }

    def _validate_aggregate(
        self,
        freeze_record: dict[str, Any],
        capsule: dict[str, Any],
        seal_digest: str,
        roster_digest: str,
        reviews: list[dict[str, Any]],
    ) -> tuple[dict[str, Any], str]:
        assert self.cas is not None
        digest = freeze_record["aggregate_decision_digest"]
        data = self.cas.read(digest, MAX_EXTERNAL_JSON_BYTES, "AggregateDecision")
        supplied = require_object(
            parse_canonical_json(data, "AggregateDecision"),
            "AggregateDecision",
        )
        expected = self._compute_aggregate(
            capsule,
            seal_digest,
            roster_digest,
            reviews,
        )
        if not strict_equal(supplied, expected):
            fail("AggregateDecision: object differs from deterministic recomputation")
        return expected, digest

    def _validate_decision(
        self,
        freeze_record: dict[str, Any],
        capsule: dict[str, Any],
        aggregate: dict[str, Any],
        aggregate_digest: str,
    ) -> str:
        payload, digest, signers = self._read_envelope_from_cas(
            freeze_record["decision_envelope_digest"],
            "DecisionAuthorization envelope",
            "decision-authorization",
        )
        expected_payload = {
            "aggregate_decision_digest": aggregate_digest,
            "campaign_id": self.policy["campaign_id"],
            "candidate_id": capsule["candidate_id"],
            "claims_denied": aggregate["claims_denied"],
            "claims_granted": aggregate["claims_granted"],
            "decision": aggregate["decision"],
            "decision_authority_ids": self.policy["decision_authorities"],
            "evidence_class": self.evidence_class,
            "phase": 8,
            "policy_digest": self.policy_digest,
            "schema": f"{self.prefix}.decision-authorization",
        }
        if not strict_equal(payload, expected_payload):
            fail("DecisionAuthorization: payload differs from deterministic aggregate")
        authorized_keys = set(self._keys_for_principals(self.policy["decision_authorities"]))
        if len(signers) != 2 or not set(signers).issubset(authorized_keys):
            fail("DecisionAuthorization: exact 2-of-3 decision authority signatures required")
        return digest

    def _derive_freeze_record(
        self,
        capsule: dict[str, Any],
        seal_digest: str,
        roster_digest: str,
        reviews: list[dict[str, Any]],
        aggregate: dict[str, Any],
        aggregate_digest: str,
        decision_digest: str,
    ) -> dict[str, Any]:
        accepted = aggregate["decision"] == "accept"
        derived_status = (
            "mechanicsAcceptValidOnly" if accepted else "mechanicsRejectValidOnly"
        )
        return {
            "aggregate_decision_digest": aggregate_digest,
            "architecture_frozen": False,
            "architecture_frozen_pre_formal": False,
            "campaign_decision": aggregate["decision"],
            "tla_authorized": False,
            "campaign_id": self.policy["campaign_id"],
            "candidate_id": capsule["candidate_id"],
            "capsule_digest": self.capsule_digest,
            "claims_denied": aggregate["claims_denied"],
            "claims_granted": aggregate["claims_granted"],
            "decision_envelope_digest": decision_digest,
            "derivation_algorithm": "archfreeze-v2",
            "derived_status": derived_status,
            "evidence_class": self.evidence_class,
            "phase": 9,
            "policy_envelope_digest": self.policy_digest,
            "project": self.args.expected_project,
            "requirement": self.args.expected_requirement,
            "review_envelope_digests": [
                {"digest": review["digest"], "role": review["role"]}
                for review in reviews
            ],
            "roster_envelope_digest": roster_digest,
            "schema": f"{self.prefix}.freeze-record",
            "seal_envelope_digest": seal_digest,
            "trust_root_digest": self.trust_root_digest,
        }


def add_verification_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--trust-root", type=Path, required=True)
    parser.add_argument("--expected-trust-root-digest", required=True)
    parser.add_argument("--expected-trust-root-epoch", type=int, required=True)
    parser.add_argument("--policy-envelope", type=Path, required=True)
    parser.add_argument("--expected-policy-digest", required=True)
    parser.add_argument("--expected-policy-id", required=True)
    parser.add_argument("--expected-policy-epoch", type=int, required=True)
    parser.add_argument("--expected-project", required=True)
    parser.add_argument("--expected-requirement", required=True)
    parser.add_argument("--cas-root", type=Path, required=True)
    parser.add_argument("--expected-cas-store-id", required=True)
    parser.add_argument("--freeze-record", type=Path, required=True)
    parser.add_argument("--semantic-validator", type=Path, required=True)
    parser.add_argument("--expected-semantic-validator-digest", required=True)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify non-freezing architecture-assurance fixture mechanics",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    fixture = subparsers.add_parser(
        "verify-fixture",
        help="verify test mechanics; successful output is always non-freezing",
    )
    add_verification_arguments(fixture)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        result = FixtureAssuranceVerifier(args).verify()
    except VerificationError as exc:
        print(
            f"architecture-freeze-v2-fixture: REJECT[{exc.code}]: {exc.message}",
            file=sys.stderr,
        )
        return 1
    print(jcs_bytes(result).decode("utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
