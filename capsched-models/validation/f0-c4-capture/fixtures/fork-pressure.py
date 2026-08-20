#!/usr/bin/python3
import os
import time


children = []
blocked = False
for _ in range(256):
    try:
        child = os.fork()
    except OSError:
        blocked = True
        break
    if child == 0:
        time.sleep(300)
        raise SystemExit(0)
    children.append(child)
if not blocked:
    raise SystemExit("pids.max did not stop the fork-pressure fixture")
print(f"FIXTURE_FORK_PRESSURE_BLOCKED children={len(children)}")
