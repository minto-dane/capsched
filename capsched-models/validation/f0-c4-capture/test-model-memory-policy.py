#!/usr/bin/env python3
"""Bounded-memory regression for exact Candidate-4 graph enumeration."""

from __future__ import annotations

from array import array
from dataclasses import dataclass, is_dataclass
import errno
import os
from pathlib import Path
import sys
import tempfile
from types import ModuleType
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
VALIDATION = HERE.parent
sys.path.insert(0, str(VALIDATION))

import f0_supervisor_lts_v3 as child  # noqa: E402
import f0_supervisor_orchestrator_v3 as parent  # noqa: E402


ABSOLUTE_CACHE_MAX_ENTRIES = 32768
EXPECTED_CACHE_CONSTANTS = {
    child: {
        "SMALL_CACHE_MAX_ENTRIES": 256,
        "DIGEST_CACHE_MAX_ENTRIES": 32768,
        "STATE_CACHE_MAX_ENTRIES": 16384,
        "PREFIX_CACHE_MAX_ENTRIES": 8192,
        "PACKED_RECORD_DECODE_CACHE_ENTRIES": 8192,
        "PACKED_EXACT_INTERN_CACHE_ENTRIES": 8192,
        "ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE": 4096,
        "ADAPTIVE_REFERENCE_DIRECT_RATIO_DENOMINATOR": 4,
        "EXACT_INDEX_MAX_LOAD_NUMERATOR": 4,
        "EXACT_INDEX_MAX_LOAD_DENOMINATOR": 5,
    },
    parent: {
        "SMALL_CACHE_MAX_ENTRIES": 256,
        "STATE_CACHE_MAX_ENTRIES": 16384,
    },
}
EXPECTED_CACHED_FUNCTIONS = {
    child: {
        "_grant_auth_tag",
        "_phase_after_evidence_prefix",
        "_receipt_auth_tag",
        "digest",
        "evidence_wf",
        "genesis_hash",
        "grant_binding_digest",
        "grant_wf",
        "instance_wf",
        "receipt_hash",
        "receipt_wf",
        "recovery_wf",
    },
    parent: {
        "_replay_child_terminal",
        "fixture_child_certificate",
        "orchestrator_wf",
    },
}


def require_module_cache_policy(module: ModuleType) -> None:
    for name, expected in EXPECTED_CACHE_CONSTANTS[module].items():
        actual = getattr(module, name, None)
        if actual != expected:
            raise AssertionError(f"{module.__name__}.{name} drifted: {actual!r}")
    cached = {
        name: value
        for name, value in vars(module).items()
        if callable(value) and hasattr(value, "cache_parameters")
    }
    if set(cached) != EXPECTED_CACHED_FUNCTIONS[module]:
        raise AssertionError(
            f"{module.__name__} cached-function inventory drifted: {sorted(cached)}"
        )
    for name, function in cached.items():
        maximum = function.cache_parameters()["maxsize"]
        if (
            not isinstance(maximum, int)
            or maximum <= 0
            or maximum > ABSOLUTE_CACHE_MAX_ENTRIES
        ):
            raise AssertionError(
                f"{module.__name__}.{name} cache is not independently bounded: "
                f"{maximum!r}"
            )


def require_module_dataclasses_slotted(module: ModuleType) -> None:
    classes = {
        name: value
        for name, value in vars(module).items()
        if isinstance(value, type)
        and value.__module__ == module.__name__
        and is_dataclass(value)
    }
    if not classes:
        raise AssertionError(f"{module.__name__} has no state dataclasses")
    missing = sorted(name for name, value in classes.items() if "__slots__" not in value.__dict__)
    if missing:
        raise AssertionError(f"{module.__name__} dataclasses lack slots: {missing}")


def main() -> None:
    cases = 0
    child_start = child.initial_state(child.fixture_external_grant("PRODUCER"))
    parent_start = parent.initial_state()
    if hasattr(child_start, "__dict__") or hasattr(parent_start, "__dict__"):
        raise AssertionError("reachable state dataclasses must use slots")
    cases += 2

    if (
        not isinstance(child_start.evidence_receipts, child.ReceiptHistory)
        or child_start.evidence_receipts
        or hasattr(child_start.evidence_receipts, "__dict__")
    ):
        raise AssertionError("child state does not use the empty persistent history")
    cases += 1

    if (
        not isinstance(parent_start.parent_receipts, parent.ParentReceiptHistory)
        or parent_start.parent_receipts
        or hasattr(parent_start.parent_receipts, "__dict__")
    ):
        raise AssertionError("parent state does not use the empty persistent history")
    cases += 1

    left = child_start
    right = child.initial_state(child.fixture_external_grant("PRODUCER"))
    left_receipts = []
    for _ in range(10):
        left = child.next_states(left)[0].state
        right = child.next_states(right)[0].state
        left_receipts.append(left.evidence_receipts[-1])
    if (
        tuple(left.evidence_receipts) != tuple(left_receipts)
        or left.evidence_receipts != right.evidence_receipts
        or hash(left.evidence_receipts) != hash(right.evidence_receipts)
        or left.evidence_receipts[:-1] != right.evidence_receipts[:-1]
        or left.evidence_receipts[1:] != tuple(left_receipts[1:])
    ):
        raise AssertionError("persistent history changed exact ordered sequence semantics")
    cases += 1

    try:
        left.evidence_receipts._length = 0
    except AttributeError:
        pass
    else:
        raise AssertionError("persistent receipt history is mutable")
    cases += 1

    parent_left = parent_start
    parent_right = parent.initial_state()
    parent_receipts = []
    for _ in range(8):
        left_edges = parent.next_states(parent_left)
        right_edges = parent.next_states(parent_right)
        if not left_edges or not right_edges:
            break
        parent_left = left_edges[0].state
        parent_right = right_edges[0].state
        if parent_left.parent_receipts:
            parent_receipts = list(parent_left.parent_receipts)
    if (
        tuple(parent_left.parent_receipts) != tuple(parent_receipts)
        or parent_left.parent_receipts != parent_right.parent_receipts
        or hash(parent_left.parent_receipts) != hash(parent_right.parent_receipts)
    ):
        raise AssertionError("persistent parent history changed exact sequence semantics")
    cases += 1

    class CollisionState:
        __slots__ = ("value",)

        def __init__(self, value: int) -> None:
            self.value = value

        def __hash__(self) -> int:
            return 7

        def __eq__(self, other: object) -> bool:
            return isinstance(other, CollisionState) and self.value == other.value

    collision_states = []
    exact_index = child.ExactStateIndex(collision_states, initial_capacity=8)
    for value in range(40):
        state_index, is_new = exact_index.intern(CollisionState(value))
        if state_index != value or not is_new:
            raise AssertionError("exact state index insertion drifted")
    for value in reversed(range(40)):
        state_index, is_new = exact_index.intern(CollisionState(value))
        if state_index != value or is_new:
            raise AssertionError("hash collision merged or duplicated an exact state")
    if (
        len(exact_index) != 40
        or exact_index.capacity < 64
        or exact_index._indices.typecode != "I"
        or exact_index._hashes.typecode != "Q"
    ):
        raise AssertionError("exact state index is not fixed-width and resize-safe")
    cases += 1

    dense_states = []
    dense_index = child.ExactStateIndex(dense_states, initial_capacity=64)
    for value in range(51):
        dense_index.intern(CollisionState(10_000 + value))
    if dense_index.capacity != 64 or len(dense_index) != 51:
        raise AssertionError("exact state index regressed from its sealed 80% load bound")
    cases += 1

    if child.semantic_projection(child_start) is not child_start:
        raise AssertionError("exact child projection allocated a wrapper identity")
    if parent.semantic_projection(parent_start) is not parent_start:
        raise AssertionError("exact parent projection allocated a wrapper identity")
    cases += 2

    for module in (child, parent):
        require_module_cache_policy(module)
        cases += 1

    if hasattr(child.next_states, "cache_info") or hasattr(parent.next_states, "cache_info"):
        raise AssertionError("transition expansion must not retain an unbounded graph cache")
    cases += 1

    with patch.object(child, "next_states", return_value=()):
        child_graph = child.reachable_states(child.fixture_external_grant("PRODUCER"))
    if (
        not isinstance(child_graph, child.ReachabilityGraph)
        or not isinstance(child_graph.states, child.CompactExactStateStore)
        or not child_graph.states.frozen
        or child_graph.states.fixed_column_bytes_per_state_upper_bound > 112
        or child_graph.states != (child_start,)
        or child_graph.edge_offsets != array("I", (0, 0))
        or child_graph.target_indices.typecode != "I"
        or child_graph.action_indices.typecode != "B"
    ):
        raise AssertionError("child reachable_states did not return compact exact CSR")
    cases += 1

    with patch.object(parent, "next_states", return_value=()):
        parent_graph = parent.reachable_states()
    if (
        not isinstance(parent_graph, parent.OrchestratorReachabilityGraph)
        or not isinstance(parent_graph.states, child.CompactExactStateStore)
        or not parent_graph.states.frozen
        or parent_graph.states.fixed_column_bytes_per_state_upper_bound > 320
        or parent_graph.states != (parent_start,)
        or parent_graph.edge_offsets != array("I", (0, 0))
        or parent_graph.target_indices.typecode != "I"
        or parent_graph.action_indices.typecode != "B"
    ):
        raise AssertionError("parent reachable_states did not return compact exact CSR")
    cases += 1

    child_store = child.CompactExactStateStore(
        child.EnvelopeState,
        child.CHILD_STATE_REFERENCE_FIELDS,
    )
    child_store.append(child_start)
    if (
        child_store[0] != child_start
        or not child_store.equals_at(0, child_start)
        or child_store.equals_at(0, child.replace(child_start, phase="READY"))
    ):
        raise AssertionError("compact child state reconstruction or equality drifted")
    cases += 1

    packed_child = child_store[0]
    packed_receipts = []
    for _ in range(10):
        packed_child = child.next_states(packed_child)[0].state
        packed_receipts.append(packed_child.evidence_receipts[-1])
        child_store.append(packed_child)
        packed_child = child_store[-1]
    evidence_index = child_store._field_names.index("evidence_receipts")
    evidence_column = child_store._columns[evidence_index].implementation
    if (
        not isinstance(evidence_column, child._PackedPersistentSequenceColumn)
        or len(evidence_column.arena) != 11
        or len(evidence_column.arena._records) != 10
        or evidence_column.arena.fixed_column_bytes_per_node_upper_bound != 17
        or evidence_column.arena.fixed_column_bytes_per_record_upper_bound > 64
        or len(evidence_column.arena._records._cache_ids)
        != child.PACKED_RECORD_DECODE_CACHE_ENTRIES
        or len(evidence_column.arena._records._cache_values)
        != child.PACKED_RECORD_DECODE_CACHE_ENTRIES
        or tuple(packed_child.evidence_receipts) != tuple(packed_receipts)
        or packed_child.evidence_receipts != left.evidence_receipts
        or hash(packed_child.evidence_receipts) != hash(left.evidence_receipts)
    ):
        raise AssertionError("accepted child histories are not exact packed arena values")
    cases += 1

    hostile_receipt = child.Receipt(
        schema="hostile-schema",
        run_id="hostile-run",
        binding_digest="A" * 64,
        scope_id="hostile-scope",
        subject_id="hostile-subject",
        sequence=1,
        kind="hostile-kind",
        payload="hostile-\ud800-payload",
        payload_digest="not-a-digest",
        issuer="hostile-issuer",
        channel="hostile-channel",
        previous_hash="",
        auth_tag="F" * 64,
    )
    hostile_history = child.ReceiptHistory().append(hostile_receipt)
    hostile_column = child._PackedPersistentSequenceColumn(child.ReceiptHistory)
    hostile_column.append(hostile_history)
    hostile_rebuilt = hostile_column.value(0)
    if (
        hostile_rebuilt != hostile_history
        or hostile_rebuilt[0] != hostile_receipt
        or hostile_rebuilt[0].payload != hostile_receipt.payload
        or not hostile_column.arena._records._columns[2].matches(
            0, hostile_receipt.binding_digest
        )
        or not hostile_column.arena._records._columns[7].matches(
            0, hostile_receipt.payload
        )
        or hostile_column.arena._records._columns[12]._tags[0] != 1
    ):
        raise AssertionError("noncanonical exact receipt values changed while packing")
    cases += 1

    @dataclass(frozen=True, slots=True)
    class CollisionRecord:
        value: int

        def __hash__(self) -> int:
            return 17

    class CollisionHistory(child.PersistentSequence):
        __slots__ = ()
        _record_type = CollisionRecord

        def append(self, value: object):
            if not isinstance(value, CollisionRecord):
                raise TypeError("collision history accepts CollisionRecord only")
            return CollisionHistory(self, value)

    collision_left = CollisionHistory().append(CollisionRecord(1))
    collision_right = CollisionHistory().append(CollisionRecord(2))
    if hash(collision_left) != hash(collision_right):
        raise AssertionError("collision fixture did not collide")
    collision_column = child._PackedPersistentSequenceColumn(CollisionHistory)
    collision_column.append(collision_left)
    collision_column.append(collision_left)
    collision_column.append(collision_right)
    if (
        collision_column.matches(0, collision_right)
        or collision_column.matches(2, collision_left)
        or collision_column.value(0) == collision_column.value(2)
        or collision_column._row_tags[0] != 0
        or collision_column._row_tags[1] != 0
        or collision_column._row_codes[0] != collision_column._row_codes[1]
        or len(collision_column.arena) != 3
        or len(collision_column.arena._records) != 2
        or len(collision_column.arena._index_ids)
        != child.PACKED_EXACT_INTERN_CACHE_ENTRIES
        or len(collision_column.arena._records._index_ids)
        != child.PACKED_EXACT_INTERN_CACHE_ENTRIES
    ):
        raise AssertionError(
            "packed history merged collisions or duplicated an exact history"
        )
    cases += 1

    child_store.freeze()
    try:
        child_store.append(child_start)
    except RuntimeError:
        pass
    else:
        raise AssertionError("frozen compact state store accepted an append")
    cases += 1

    parent_store = child.CompactExactStateStore(
        parent.OrchestratorState,
        parent.PARENT_STATE_REFERENCE_FIELDS,
    )
    parent_store.append(parent_start)
    if (
        parent_store[0] != parent_start
        or not parent_store.equals_at(0, parent_start)
        or parent_store.equals_at(
            0,
            parent.replace(parent_start, phase="GRANT_AVAILABLE"),
        )
    ):
        raise AssertionError("compact parent state reconstruction or equality drifted")
    cases += 1

    adaptive_column = child._CompactCodeColumn()
    for value in range(257):
        adaptive_column.append(value)
    if (
        adaptive_column.itemsize != 2
        or adaptive_column.value(256) != 256
        or not adaptive_column.matches(256, 256)
        or adaptive_column.matches(256, 255)
    ):
        raise AssertionError("adaptive exact code column failed width promotion")
    cases += 1

    reused_reference_column = child._AdaptiveExactReferenceColumn()
    for _ in range(child.ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE + 1):
        reused_reference_column.append(("shared",))
    if (
        not isinstance(
            reused_reference_column.implementation,
            child._CompactCodeColumn,
        )
        or reused_reference_column.itemsize != 1
        or not reused_reference_column.matches(0, ("shared",))
    ):
        raise AssertionError("reused exact references abandoned compact interning")
    cases += 1

    unique_reference_column = child._AdaptiveExactReferenceColumn()
    for value in range(child.ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE + 2):
        unique_reference_column.append(("unique", value))
    if (
        not isinstance(
            unique_reference_column.implementation,
            child._DirectExactReferenceColumn,
        )
        or unique_reference_column.itemsize != child.calcsize("P")
        or unique_reference_column.value(-1) != (
            "unique",
            child.ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE + 1,
        )
        or not unique_reference_column.matches(
            child.ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE,
            ("unique", child.ADAPTIVE_REFERENCE_DIRECT_MIN_UNIQUE),
        )
    ):
        raise AssertionError("mostly unique exact references did not become direct")
    cases += 1

    @dataclass(frozen=True, slots=True)
    class CompactCollisionState:
        value: int
        label: str

        def __hash__(self) -> int:
            return 11

    compact_collision_store = child.CompactExactStateStore(
        CompactCollisionState,
        frozenset(),
    )
    compact_collision_index = child.ExactStateIndex(
        compact_collision_store,
        initial_capacity=8,
    )
    for value in range(40):
        index, is_new = compact_collision_index.intern(
            CompactCollisionState(value, f"state-{value}")
        )
        if index != value or not is_new:
            raise AssertionError("compact collision insertion drifted")
    for value in reversed(range(40)):
        index, is_new = compact_collision_index.intern(
            CompactCollisionState(value, f"state-{value}")
        )
        if index != value or is_new:
            raise AssertionError("compact collision merged or duplicated a state")
    cases += 1

    for module in (child, parent):
        require_module_dataclasses_slotted(module)
        cases += 1

    for source in (child.__file__, parent.__file__):
        if "@lru_cache(maxsize=None)" in Path(source).read_text(encoding="utf-8"):
            raise AssertionError(f"unbounded cache returned: {source}")
    cases += 1

    with tempfile.TemporaryDirectory(prefix="f0-c4-exact-spill-") as raw_spill:
        spill_path = Path(raw_spill)
        os.chmod(spill_path, 0o700)
        with patch.dict(
            os.environ,
            {child.EXACT_STORE_DIRECTORY_ENV: str(spill_path)},
            clear=False,
        ):
            spilled = child._new_array("I", range(20_000))
            zeros = child._new_zero_array("Q", 20_000)
            if (
                not isinstance(spilled, child._SpillArray)
                or not isinstance(zeros, child._SpillArray)
                or len(spilled) != 20_000
                or spilled[0] != 0
                or spilled[-1] != 19_999
                or spilled[1024:1032] != array("I", range(1024, 1032))
                or zeros.count(0) != 20_000
                or list(spill_path.iterdir())
            ):
                raise AssertionError("disk-backed exact arrays changed fixed-width semantics")
            zeros[-1] = 7
            if zeros[-1] != 7 or zeros.count(0) != 19_999:
                raise AssertionError("disk-backed zero array changed assignment semantics")
            spilled.close()
            zeros.close()

            descriptors_before = len(os.listdir("/proc/self/fd"))
            with patch.object(
                child.os,
                "ftruncate",
                side_effect=OSError(errno.ENOSPC, "fixture disk full"),
            ):
                try:
                    child._new_array("I")
                except OSError as exc:
                    if exc.errno != errno.ENOSPC:
                        raise
                else:
                    raise AssertionError("spill allocation did not fail closed on ENOSPC")
            if (
                len(os.listdir("/proc/self/fd")) != descriptors_before
                or list(spill_path.iterdir())
            ):
                raise AssertionError("failed spill allocation leaked a file or descriptor")
        if child._spill_directory_fd is not None:
            os.close(child._spill_directory_fd)
        child._spill_directory_fd = None
        child._spill_directory_path = None
    cases += 1

    child_source = Path(child.__file__).read_text(encoding="utf-8")
    parent_source = Path(parent.__file__).read_text(encoding="utf-8")
    if (
        "class PersistentSequence:" not in child_source
        or "class ReceiptHistory(PersistentSequence):" not in child_source
        or "class _PackedRecordArena:" not in child_source
        or "class _PackedPersistentSequenceArena:" not in child_source
        or "class _PackedPersistentSequenceColumn:" not in child_source
        or "class ExactStateIndex:" not in child_source
        or "class CompactExactStateStore:" not in child_source
        or 'frontier_indices = _new_array("I"' not in child_source
        or "representatives: dict[EnvelopeState, int]" in child_source
        or "state_vector = tuple(states)" in child_source
        or "evidence_histories: set[tuple[Receipt, ...]]" in child_source
        or "evidence_history_index = ExactStateIndex" not in child_source
        or "class ParentReceiptHistory(child.PersistentSequence):" not in parent_source
        or 'frontier_indices = child._new_array("I"' not in parent_source
        or "representatives: dict[OrchestratorState, int]" in parent_source
        or "state_vector = tuple(states)" in parent_source
    ):
        raise AssertionError("compact persistent exact frontier policy drifted")
    cases += 1

    print(f"F0_C4_MODEL_MEMORY_POLICY_PASS cases={cases}")


if __name__ == "__main__":
    main()
