#!/usr/bin/python3
import os


block = b"X" * 65536
while True:
    os.write(1, block)
