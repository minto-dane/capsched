#!/usr/bin/env python3
"""Exercise guardian cleanup of one interrupted external-memory lease."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
from types import ModuleType


HERE = Path(__file__).resolve().parent


def load_module(name: str, path: Path) -> ModuleType:
    specification = importlib.util.spec_from_file_location(name, path)
    if specification is None or specification.loader is None:
        raise AssertionError(f"cannot load module: {path}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def main() -> None:
    if os.geteuid() != 0 or os.getegid() != 0:
        raise SystemExit("root is required")
    capture = load_module("f0_c4_capture_supervisor", HERE / "f0_c4_capture_supervisor.py")
    guardian = load_module("f0_c4_guardian_finalize", HERE / "f0_c4_guardian_finalize.py")
    if capture.FIXED_WORK_ROOT != guardian.WORK_ROOT:
        raise AssertionError("capture and guardian external-memory roots differ")
    capture.FIXED_WORK_ROOT.mkdir(parents=True, mode=0o700, exist_ok=True)
    os.chown(capture.FIXED_WORK_ROOT, 0, 0)
    os.chmod(capture.FIXED_WORK_ROOT, 0o700)
    capture.require_fixed_native_work_root(capture.FIXED_WORK_ROOT)

    run_id = f"external-memory-recovery-{os.getpid()}"
    run_path = capture.FIXED_WORK_ROOT / run_id
    run_path.mkdir(mode=0o700)
    storage = None
    cleanup_complete = False
    try:
        storage = capture.prepare_external_memory(
            run_path,
            "tests",
            capture.CANDIDATE_UID,
            capture.CANDIDATE_GID,
        )
        loop_device = storage["loop_device"]
        loop_metadata = (
            Path("/sys/class/block") / Path(loop_device).name / "loop"
        )
        if not capture.exact_mount_at(storage["mountpoint"]) or not loop_metadata.exists():
            raise AssertionError("external-memory recovery fixture was not live")
        receipt = guardian.cleanup_external_memory_run(run_id)
        if receipt != {
            "run_root_present": True,
            "components_removed": 1,
            "complete": True,
        }:
            raise AssertionError(f"guardian cleanup receipt differs: {receipt!r}")
        if run_path.exists() or loop_metadata.exists():
            raise AssertionError("guardian left external-memory state attached")
        cleanup_complete = True
    finally:
        if not cleanup_complete and storage is not None:
            capture.cleanup_external_memory(storage, remove_component_root=True)
            run_path.rmdir()
    print("F0_C4_EXTERNAL_MEMORY_RECOVERY_PASS cases=1")


if __name__ == "__main__":
    main()
