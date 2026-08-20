#!/usr/bin/env python3
"""Fail-closed placeholder for real architecture-freeze assurance v2.1.

This program deliberately has no argument parser and reads no evidence.  A
future real verifier must replace this file as a separately reviewed artifact;
fixture verification code must never be promoted into this boundary.
"""

from __future__ import annotations

import sys


EXIT_UNIMPLEMENTED = 78
REJECTION = (
    "AFV2_REAL_UNIMPLEMENTED: real architecture-freeze assurance v2.1 "
    "verification is unavailable; no evidence was parsed and no claim was "
    "authorized\n"
)


def main(_argv: list[str] | None = None) -> int:
    sys.stderr.write(REJECTION)
    return EXIT_UNIMPLEMENTED


if __name__ == "__main__":
    raise SystemExit(main())
