#!/usr/bin/env python3
"""Require byte-identical Rust binaries from two distinct source roots."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
INPUTS = ("Cargo.toml", "Cargo.lock", "src")


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def tool_identity(name: str) -> dict[str, str]:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"error: required tool absent: {name}")
    binary = Path(path).resolve()
    version = subprocess.run(
        [str(binary), "--version"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.strip()
    return {
        "path": str(binary),
        "version": version,
        "sha256": sha256(binary.read_bytes()),
    }


def copy_inputs(destination: Path) -> None:
    destination.mkdir(mode=0o700)
    for name in INPUTS:
        source = HERE / name
        target = destination / name
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def build(source: Path) -> bytes:
    environment = {
        **os.environ,
        "CARGO_INCREMENTAL": "0",
        "LC_ALL": "C",
        "SOURCE_DATE_EPOCH": "0",
        "TZ": "UTC",
    }
    subprocess.run(
        ["cargo", "build", "--release", "--locked", "--offline"],
        cwd=source,
        env=environment,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    return (source / "target/release/f0-c4-rust-engine").read_bytes()


def main() -> int:
    rustc = tool_identity("rustc")
    cargo = tool_identity("cargo")
    with tempfile.TemporaryDirectory(prefix="f0-c4-rust-repro-") as temporary:
        root = Path(temporary)
        first_root = root / "source-root-a"
        second_root = root / "different-source-root-b"
        copy_inputs(first_root)
        copy_inputs(second_root)
        first = build(first_root)
        second = build(second_root)
        if first != second:
            raise SystemExit(
                "error: Rust release binary depends on source/build root: "
                f"first={sha256(first)} second={sha256(second)}"
            )
        for forbidden in (str(first_root).encode(), str(second_root).encode()):
            if forbidden in first:
                raise SystemExit("error: Rust binary leaks temporary build root")

    print(
        json.dumps(
            {
                "artifact_id": "f0-c4-rust-reproducible-build-v1",
                "binary_bytes": len(first),
                "binary_sha256": sha256(first),
                "cargo": cargo,
                "claim_credit": False,
                "dependencies": 0,
                "distinct_source_roots": 2,
                "rustc": rustc,
                "status": "pass",
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
