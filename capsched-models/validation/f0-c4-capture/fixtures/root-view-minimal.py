#!/usr/bin/python3
from pathlib import Path


for forbidden in ("/Users", "/Volumes", "/home", "/sys"):
    if Path(forbidden).exists():
        raise SystemExit(f"host path visible in minimal root: {forbidden}")
print("FIXTURE_ROOT_VIEW_MINIMAL")
