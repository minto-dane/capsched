#!/usr/bin/python3
from pathlib import Path


try:
    Path("/INPUT/forged-evidence").write_text("forged", encoding="utf-8")
except OSError:
    print("FIXTURE_INPUT_READONLY")
else:
    raise SystemExit("candidate wrote to the sealed input mount")
