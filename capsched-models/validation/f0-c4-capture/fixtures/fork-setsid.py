#!/usr/bin/python3
import os
import time


child = os.fork()
if child == 0:
    os.setsid()
    grandchild = os.fork()
    if grandchild == 0:
        time.sleep(300)
    time.sleep(300)
print("FIXTURE_FORK_SETSID_PARENT_EXIT")
