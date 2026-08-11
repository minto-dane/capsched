#!/usr/bin/env python3
"""Reject blocking and aliased Candidate-4 source objects before reading."""

from __future__ import annotations

import importlib.util
import os
import socket
import tempfile
import time
from pathlib import Path
from typing import Any, Callable


HERE = Path(__file__).resolve().parent
SUPERVISOR = HERE / "f0_c4_capture_supervisor.py"


def load_supervisor() -> Any:
    spec = importlib.util.spec_from_file_location("f0_c4_capture_supervisor", SUPERVISOR)
    if spec is None or spec.loader is None:
        raise SystemExit("cannot load capture supervisor")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_regular_inputs(root: Path, names: tuple[str, ...]) -> None:
    for name in names:
        (root / name).write_bytes(f"fixture:{name}\n".encode("utf-8"))


def expect_fast_reject(
    supervisor: Any,
    name: str,
    replace: Callable[[Path, str], Callable[[], None]],
) -> None:
    with tempfile.TemporaryDirectory(prefix="c4src-", dir="/tmp") as directory:
        root = Path(directory)
        source = root / "source"
        destination = root / "destination"
        source.mkdir()
        make_regular_inputs(source, supervisor.REQUIRED_INPUTS)
        target_name = supervisor.REQUIRED_INPUTS[0]
        (source / target_name).unlink()
        cleanup = replace(source, target_name)
        started = time.monotonic()
        rejected = False
        try:
            supervisor.copy_exact_snapshot(source, destination)
        except (supervisor.CaptureError, OSError):
            rejected = True
        finally:
            cleanup()
        elapsed = time.monotonic() - started
        if not rejected:
            raise SystemExit(f"hostile snapshot object accepted: {name}")
        if elapsed >= 1.0:
            raise SystemExit(f"hostile snapshot object blocked for {elapsed:.3f}s: {name}")


def fifo(root: Path, name: str) -> Callable[[], None]:
    os.mkfifo(root / name, 0o600)
    return lambda: None


def unix_socket(root: Path, name: str) -> Callable[[], None]:
    handle = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    handle.bind(os.fspath(root / name))
    return handle.close


def directory(root: Path, name: str) -> Callable[[], None]:
    (root / name).mkdir()
    return lambda: None


def device_symlink(root: Path, name: str) -> Callable[[], None]:
    (root / name).symlink_to("/dev/null")
    return lambda: None


def hardlink(root: Path, name: str) -> Callable[[], None]:
    backing = root / "hardlink-backing"
    backing.write_bytes(b"alias\n")
    os.link(backing, root / name)
    return lambda: None


def main() -> int:
    supervisor = load_supervisor()
    cases = (
        ("fifo", fifo),
        ("unix-socket", unix_socket),
        ("directory", directory),
        ("device-symlink", device_symlink),
        ("hardlink", hardlink),
    )
    for name, replace in cases:
        expect_fast_reject(supervisor, name, replace)
    print(f"F0_C4_CAPTURE_SNAPSHOT_HOSTILE_PASS hostile_cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
