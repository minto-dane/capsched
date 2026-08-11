#!/usr/bin/python3
import fcntl
import socket
import struct


SIOCGIFFLAGS = 0x8913
IFF_UP = 0x1
request = struct.pack("16sH14x", b"lo", 0)
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as handle:
    response = fcntl.ioctl(handle.fileno(), SIOCGIFFLAGS, request)
flags = struct.unpack("16sH14x", response)[1]
if flags & IFF_UP:
    raise SystemExit("loopback is unexpectedly up in the private network namespace")
print("FIXTURE_NETWORK_DOWN")
